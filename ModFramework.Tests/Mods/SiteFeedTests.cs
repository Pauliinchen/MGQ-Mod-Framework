//----------------------------------------------------------------
//  SiteFeedTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Read the website's lists as plain JSON, without a signature
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of the signed list, a list of schema 3 and the refusals
//                            - Took over the check of a signature out of range and the fetch of the collections
//                            - Read the versions of a signed list in the test of the list kept as it came
//      Paulinchen  2026-11-01: Covered the upvotes of a mod alone
//      Paulinchen  2026-10-30: Covered the links, credits and license of a mod and the notes of its versions
//                            - Let the website inside the tests note each request's method, bearer value and body
//                            - Covered the categories, keywords, games, platforms, times, downloads and votes of schema 3
//                            - Covered the package of each platform of schema 3
//                            - Moved into the Mod Framework
//                            - Covered the tags, the requirements and the list kept as it came
//      Paulinchen  2026-10-24: Covered the thumbnails and a mod's description
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers reading the website's lists: the mods with their versions, packages and details, a mod's
/// description and the collections.
/// </summary>
public sealed class SiteFeedTests
{
    /// <summary>
    /// Asserts that the list gives each mod its versions, the latest upload first with its package
    /// and files, each mod's tag and each version's requirements and a thumbnail only on the website,
    /// that it is kept as it came, and that a mod's details give its description and the collections
    /// read the same way.
    /// </summary>
    [Fact]
    public void FetchList_ReadsTheListAndKeepsItAsItCame()
    {
        var feed = Encoding.UTF8.GetBytes("""
            {"schema":2,"mods":[{"slug":"level-cap","name":"Level Cap","author":"Someone","tag":"title",
              "thumbnail":{"url":"https://mgqonline.org/mods/level-cap/images/1/card.png","width":400,"height":225,"spoiler":true},"versions":[
             {"version":"1","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/level-cap/1/download"},"files":[{"path":"Level_Cap.rb","sha256":"aa"}]},
             {"version":"2","changelog":"","uploadedAt":"2026-10-22T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":2,"sha256":"bb","url":"https://mgqonline.org/mods/level-cap/2/download"},"files":[{"path":"Level_Cap.rb","sha256":"bb"}],
              "requires":[{"slug":"mod-framework","minVersion":"0.1.0"},{"slug":"","minVersion":"1"}]}]},
             {"slug":"b","name":"B","author":"Someone","thumbnail":{"url":"https://example.com/b.png","width":400,"height":225,"spoiler":false},"versions":[
             {"version":"1","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"B.rb","size":1,"sha256":"cc","url":"https://mgqonline.org/mods/b/1/download"},"files":[{"path":"B.rb","sha256":"cc"}]}]}]}
            """);
        var details = Encoding.UTF8.GetBytes("""{"schema":1,"generatedAt":"2026-10-24T08:00:00+00:00","mod":{"slug":"level-cap","name":"Level Cap","description":"Caps **levels**.","versions":[]}}""");
        var collections = Encoding.UTF8.GetBytes("""{"schema":2,"collections":[{"slug":"story-plus","name":"Story Plus","summary":"","author":"Someone","page":"https://mgqonline.org/collections/story-plus","mods":[]}]}""");
        var website = new FakeWebsite
        {
            [SiteFeed.ListAddress] = () => FakeWebsite.Json(feed),
            [$"{SiteFeed.Address}/level-cap{SiteFeed.SchemaQuery}"] = () => FakeWebsite.Json(details),
            [SiteCollections.Address] = () => FakeWebsite.Json(collections),
        };

        var list = SiteFeed.FetchList(website.Client());
        var mods = SiteFeed.ReadList(list);
        var mod = mods[0];

        Assert.Equal(feed, list);
        Assert.Equal(("level-cap", "Level Cap", "Someone", ModTag.Title), (mod.Slug, mod.Name, mod.Author, mod.Tag));
        Assert.Equal(["2", "1"], mod.Versions.Select(version => version.Version));
        Assert.Equal(new SitePackage("Level_Cap.rb", 2, "bb", "https://mgqonline.org/mods/level-cap/2/download"), mod.Versions[0].Package);
        Assert.Equal("bb", mod.Versions[0].Files["Level_Cap.rb"]);
        Assert.Equal([new ModRequirement("mod-framework", "0.1.0")], mod.Versions[0].Requires!);
        Assert.Equal(new SiteThumbnail("https://mgqonline.org/mods/level-cap/images/1/card.png", 400, 225, true), mod.Thumbnail);
        Assert.Null(mods[1].Thumbnail);

        Assert.Equal("Caps **levels**.", SiteFeed.FetchDescription("level-cap", website.Client()));
        Assert.Equal(["story-plus"], SiteCollections.ReadList(SiteCollections.FetchList(website.Client())).Select(collection => collection.Slug));
    }

    /// <summary>
    /// Asserts that a list of schema 3 gives each version the package and files of the platform it
    /// is read for and none for a version without a package for it, and tells each mod's categories,
    /// keywords, languages, games, platforms, times, downloads and upvotes, the newest upload of any
    /// platform as its update, its links without an address that is not http or https, its credits
    /// and license, and each version's save safety, conflicts, load order, known issues, options and
    /// hotkeys.
    /// </summary>
    [Fact]
    public void Parse_Schema3_ReadsThePackagesOfThePlatformAndTheDetails()
    {
        var feed = Encoding.UTF8.GetBytes("""
            {"schema":3,"mods":[{"slug":"pack","name":"Pack","author":"Someone","tag":"regular","downloads":12,"createdAt":"2026-10-01T10:00:00+00:00",
              "categories":[{"slug":"quality-of-life","name":"Quality of Life"}],"keywords":["party","menu"],"languages":["en","ru"],"worksWith":["english","russian"],
              "rating":{"up":3,"down":1,"score":0.3006},
              "links":{"source":"https://github.com/someone/pack","homepage":"javascript:alert(1)","donation":"http://example.com/give"},
              "credits":[{"name":"Ann","role":"Art"}],"license":{"name":"MIT","reuploads":"no","edits":"with-credit"},"versions":[
             {"version":"1.2","changelog":"","uploadedAt":"2026-10-22T10:00:00+00:00",
              "packages":[{"platform":"android","name":"Pack.rb","size":3,"sha256":"A3","url":"https://mgqonline.org/mods/pack/1.2/android","files":[{"path":"Pack.rb","sha256":"A3"}]}]},
             {"version":"1.1","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","saveSafety":"add-only","conflicts":[{"slug":"old-map","note":"Both draw the map."}],
              "loadBefore":["invasions"],"loadAfter":["level-cap"],"knownIssues":["Flickers on the world map."],"options":[{"name":"[Pack] Size","help":"How big."}],
              "hotkeys":[{"name":"[Pack] Open","help":"Opens it.","key":118}],
              "package":{"name":"Pack.rb","size":1,"sha256":"P1","url":"https://mgqonline.org/mods/pack/1.1/pc"},"files":[{"path":"Pack.rb","sha256":"P1"}],
              "packages":[{"platform":"pc","name":"Pack.rb","size":1,"sha256":"P1","url":"https://mgqonline.org/mods/pack/1.1/pc","files":[{"path":"Pack.rb","sha256":"P1"}]},
                          {"platform":"android","name":"Pack.rb","size":2,"sha256":"A1","url":"https://mgqonline.org/mods/pack/1.1/android","files":[{"path":"Pack.rb","sha256":"A1"}]}]}]}]}
            """);

        var pc = Assert.Single(SiteFeed.ReadList(feed, "pc"));
        var android = Assert.Single(SiteFeed.ReadList(feed, "android"));
        var meta = pc.Meta!;
        var notes = pc.Versions[1].Notes!;

        Assert.Equal([null, "https://mgqonline.org/mods/pack/1.1/pc"], pc.Versions.Select(version => version.Package?.Url));
        Assert.Equal([0, 1], pc.Versions.Select(version => version.Files.Count));
        Assert.Equal(["https://mgqonline.org/mods/pack/1.2/android", "https://mgqonline.org/mods/pack/1.1/android"], android.Versions.Select(version => version.Package?.Url));
        Assert.Equal("a1", android.Versions[1].Files["Pack.rb"]);

        Assert.Equal([new SiteCategory("quality-of-life", "Quality of Life")], meta.Categories);
        Assert.Equal(["party", "menu"], meta.Keywords);
        Assert.Equal(["en", "ru"], meta.Languages);
        Assert.Equal(["english", "russian"], meta.WorksWith);
        Assert.Equal(["android", "pc"], meta.Platforms);
        Assert.Equal((DateTimeOffset.Parse("2026-10-01T10:00:00+00:00"), DateTimeOffset.Parse("2026-10-22T10:00:00+00:00"), 12, 3), (meta.CreatedAt, meta.UpdatedAt, meta.Downloads, meta.Upvotes));
        Assert.Equal([new SiteLink("source", "https://github.com/someone/pack"), new SiteLink("donation", "http://example.com/give")], meta.Links);
        Assert.Equal([new SiteCredit("Ann", "Art")], meta.Credits);
        Assert.Equal(new SiteLicense("MIT", "no", "with-credit"), meta.License);

        Assert.Equal(VersionNotes.AddOnly, notes.SaveSafety);
        Assert.Equal([new SiteConflict("old-map", "Both draw the map.")], notes.Conflicts);
        Assert.Equal(["invasions"], notes.LoadBefore);
        Assert.Equal(["level-cap"], notes.LoadAfter);
        Assert.Equal(["Flickers on the world map."], notes.KnownIssues);
        Assert.Equal([new SiteOption("[Pack] Size", "How big.")], notes.Options);
        Assert.Equal([new SiteOption("[Pack] Open", "Opens it.", 118)], notes.Hotkeys);
    }

}

/// <summary>
/// The website inside the test: an answer made for each address, and the addresses asked for.
/// </summary>
internal sealed class FakeWebsite : HttpMessageHandler
{
    /// <summary>
    /// What makes the answer to each address, by address.
    /// </summary>
    private readonly Dictionary<string, Func<HttpResponseMessage>> _answers = new(StringComparer.Ordinal);

    /// <summary>
    /// The addresses asked for, in order.
    /// </summary>
    public List<string> Requested { get; } = [];

    /// <summary>
    /// Each request's method, address, bearer value and body, in order.
    /// </summary>
    public List<(string Method, string Url, string? Bearer, string? Body)> Calls { get; } = [];

    /// <summary>
    /// What makes the answer to an address.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>What makes the answer.</returns>
    public Func<HttpResponseMessage> this[string url]
    {
        get => _answers[url];
        set => _answers[url] = value;
    }

    /// <summary>
    /// Makes an answer that carries a list.
    /// </summary>
    /// <param name="body">The list.</param>
    /// <returns>The answer.</returns>
    public static HttpResponseMessage Json(byte[] body) => new(HttpStatusCode.OK) { Content = new ByteArrayContent(body) };

    /// <summary>
    /// Makes a client that asks this website.
    /// </summary>
    /// <returns>The client.</returns>
    public HttpClient Client() => new(this);

    /// <inheritdoc />
    protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var url = request.RequestUri!.ToString();
        Requested.Add(url);
        var bearer = request.Headers.Authorization is { Scheme: "Bearer" } authorization ? authorization.Parameter : null;
        Calls.Add((request.Method.Method, url, bearer, request.Content?.ReadAsStringAsync(cancellationToken).GetAwaiter().GetResult()));
        return _answers.TryGetValue(url, out var answer) ? answer() : new HttpResponseMessage(HttpStatusCode.NotFound);
    }

    /// <inheritdoc />
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
        Task.FromResult(Send(request, cancellationToken));
}
