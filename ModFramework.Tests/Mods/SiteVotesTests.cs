//----------------------------------------------------------------
//  SiteVotesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-04: Checked the requests of the votes in one flow
//      Paulinchen  2026-11-01: Covered upvotes alone, a vote down cast before read as none
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the requests of the votes the game casts on the website with its install key.
/// </summary>
public sealed class SiteVotesTests
{
    /// <summary>
    /// The address of Level Cap's vote.
    /// </summary>
    private const string VoteUrl = "https://mgqonline.org/api/mods/level-cap/vote";

    /// <summary>
    /// Asserts that an upvote goes as a PUT with the key as its bearer value and gives the upvotes
    /// after it, that taking it back goes as a DELETE without a body, that the key's own upvotes read
    /// by slug while a vote down cast before mods were upvoted only reads as none, and that a refusal
    /// tells the website's name for it and a website out of reach says so.
    /// </summary>
    [Fact]
    public void Vote_SendsTheKeyAndReadsTheAnswers()
    {
        var key = new string('b', 64);
        var votes = """{"votes":[{"slug":"level-cap","vote":"up"},{"slug":"invasions","vote":"down"},{"slug":"odd","vote":"sideways"}]}""";
        var website = new FakeWebsite
        {
            [VoteUrl] = () => Json(HttpStatusCode.OK, """{"slug":"level-cap","vote":"up","up":3,"down":1,"score":0.3006}"""),
            [SiteVotes.VotesAddress] = () => Json(HttpStatusCode.OK, votes),
        };

        Assert.Equal(new VoteAnswer("up", 3), SiteVotes.Vote("level-cap", SiteVotes.Up, key, website.Client()));
        SiteVotes.Vote("level-cap", null, key, website.Client());
        var mine = SiteVotes.ParseVotes(SiteVotes.FetchVotes(key, website.Client()));

        Assert.Equal([("PUT", key, """{"vote":"up"}"""), ("DELETE", key, null)], website.Calls.Take(2).Select(call => (call.Method, call.Bearer, call.Body)));
        Assert.Equal([("level-cap", "up")], mine.Select(vote => (vote.Key, vote.Value)));

        website[VoteUrl] = () => Json(HttpStatusCode.Forbidden, """{"error":"NotDownloaded"}""");

        Assert.Equal("NotDownloaded", Assert.Throws<SiteVoteException>(() => SiteVotes.Vote("level-cap", SiteVotes.Up, key, website.Client())).Error);
        Assert.Equal(SiteVotes.Unreachable, Assert.Throws<SiteVoteException>(() => SiteVotes.Vote("level-cap", SiteVotes.Up, key, new HttpClient(new Unreachable()))).Error);
    }

    /// <summary>
    /// Makes an answer of JSON.
    /// </summary>
    /// <param name="status">Its status.</param>
    /// <param name="json">Its body.</param>
    /// <returns>The answer.</returns>
    private static HttpResponseMessage Json(HttpStatusCode status, string json) =>
        new(status) { Content = new StringContent(json, Encoding.UTF8, "application/json") };

    /// <summary>
    /// A network that reaches nothing.
    /// </summary>
    private sealed class Unreachable : HttpMessageHandler
    {
        /// <inheritdoc />
        protected override System.Threading.Tasks.Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, System.Threading.CancellationToken cancellationToken) =>
            throw new HttpRequestException("No route to the website.");

        /// <inheritdoc />
        protected override HttpResponseMessage Send(HttpRequestMessage request, System.Threading.CancellationToken cancellationToken) =>
            throw new HttpRequestException("No route to the website.");
    }
}
