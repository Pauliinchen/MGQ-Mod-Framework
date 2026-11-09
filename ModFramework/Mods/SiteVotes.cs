//----------------------------------------------------------------
//  SiteVotes.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Asked the website MGQ_MODS_SITE names for the votes when it is set
//      Paulinchen  2026-11-01: Upvoted only, and read an earlier vote down as none
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Upvotes the website's mods from the game with the install key, as the website's "Ratings from
/// the game" takes it: an upvote, taking it back, the key's own upvotes, and forgetting the key.
/// </summary>
/// <remarks>
/// The player decided that mods are only upvoted, so a vote down is never sent, and one the key cast
/// before reads as no vote.
/// </remarks>
internal static class SiteVotes
{
    /// <summary>
    /// The address of the key's own votes, which <c>DELETE</c> forgets with the key.
    /// </summary>
    public static readonly string VotesAddress = SiteFeed.Site + "/api/votes";

    /// <summary>
    /// What an upvote is named.
    /// </summary>
    public const string Up = "up";

    /// <summary>
    /// The refusal of a vote that could not reach the website.
    /// </summary>
    public const string Unreachable = "Unreachable";

    /// <summary>
    /// The largest answer taken.
    /// </summary>
    private const int MaxBytes = 1024 * 1024;

    /// <summary>
    /// Follows no redirect, since the votes come from their address alone.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(15) };

    /// <summary>
    /// Upvotes a mod with the key, or takes the key's upvote back.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="vote"><see cref="Up"/>; <see langword="null"/> takes the upvote back.</param>
    /// <param name="key">The install key.</param>
    /// <returns>The key's vote and the mod's upvotes after it.</returns>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    public static VoteAnswer Vote(string slug, string? vote, string key) => Vote(slug, vote, key, Http);

    /// <summary>
    /// Upvotes a mod with the key, or takes the key's upvote back, with a client of the caller's.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="vote"><see cref="Up"/>; <see langword="null"/> takes the upvote back.</param>
    /// <param name="key">The install key.</param>
    /// <param name="http">The client.</param>
    /// <returns>The key's vote and the mod's upvotes after it.</returns>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    internal static VoteAnswer Vote(string slug, string? vote, string key, HttpClient http)
    {
        var request = new HttpRequestMessage(vote == null ? HttpMethod.Delete : HttpMethod.Put, $"{SiteFeed.Address}/{Uri.EscapeDataString(slug)}/vote");

        if (vote != null)
        {
            request.Content = new StringContent($$"""{"vote":"{{Up}}"}""", Encoding.UTF8, "application/json");
        }

        using var document = JsonDocument.Parse(Send(request, key, http, $"the vote on {slug}"));
        var root = document.RootElement;
        return new VoteAnswer(SiteMeta.Text(root, "vote") == Up ? Up : null, Math.Max(SiteMeta.Number(root, "up"), 0));
    }

    /// <summary>
    /// Fetches the key's own votes.
    /// </summary>
    /// <param name="key">The install key.</param>
    /// <returns>The answer as it came, see <see cref="ParseVotes"/>.</returns>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    public static byte[] FetchVotes(string key) => FetchVotes(key, Http);

    /// <summary>
    /// Fetches the key's own votes with a client of the caller's.
    /// </summary>
    /// <param name="key">The install key.</param>
    /// <param name="http">The client.</param>
    /// <returns>The answer as it came.</returns>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    internal static byte[] FetchVotes(string key, HttpClient http)
    {
        var body = Send(new HttpRequestMessage(HttpMethod.Get, VotesAddress), key, http, "this install's votes");
        ParseVotes(body);
        return body;
    }

    /// <summary>
    /// Asks the website to forget the key with its votes and downloads.
    /// </summary>
    /// <param name="key">The install key.</param>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    public static void Forget(string key) => Forget(key, Http);

    /// <summary>
    /// Asks the website to forget the key with a client of the caller's.
    /// </summary>
    /// <param name="key">The install key.</param>
    /// <param name="http">The client.</param>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    internal static void Forget(string key, HttpClient http) => Send(new HttpRequestMessage(HttpMethod.Delete, VotesAddress), key, http, "the forgetting of this install's key");

    /// <summary>
    /// Reads the key's own upvotes; any other vote reads as none.
    /// </summary>
    /// <param name="body">The answer of <c>GET /api/votes</c>.</param>
    /// <returns>Each upvote, <see cref="Up"/>, by the mod's slug.</returns>
    /// <exception cref="JsonException">The answer is no JSON.</exception>
    public static Dictionary<string, string> ParseVotes(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        var votes = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var vote in SiteMeta.Objects(document.RootElement, "votes"))
        {
            var (slug, cast) = (SiteMeta.Text(vote, "slug"), SiteMeta.Text(vote, "vote"));

            if (slug.Length > 0 && cast == Up)
            {
                votes[slug] = cast;
            }
        }

        return votes;
    }

    /// <summary>
    /// Sends a request with the key as its bearer value and reads the answer.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="key">The install key.</param>
    /// <param name="http">The client.</param>
    /// <param name="what">What it is, for the log, which never names the key.</param>
    /// <returns>The answer's body.</returns>
    /// <exception cref="SiteVoteException">The website refused it or could not be reached.</exception>
    private static byte[] Send(HttpRequestMessage request, string key, HttpClient http, string what)
    {
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);

        try
        {
            using (request)
            using (var response = http.Send(request, HttpCompletionOption.ResponseHeadersRead))
            {
                var body = response.Content.Headers.ContentLength > MaxBytes ? [] : response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
                Log.Write($"website {request.Method} {request.RequestUri!.AbsolutePath}: {(int)response.StatusCode}");

                if (response.StatusCode is HttpStatusCode.OK or HttpStatusCode.NoContent)
                {
                    return body;
                }

                var error = ErrorOf(body);
                Log.Write($"the website refused {what}: {(int)response.StatusCode} {error}");
                throw new SiteVoteException(error);
            }
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            Log.Write($"{what} could not reach the website: {ex.GetBaseException().Message}");
            throw new SiteVoteException(Unreachable);
        }
    }

    /// <summary>
    /// Reads the name of a refusal.
    /// </summary>
    /// <param name="body">The refusal's body, <c>{"error": name}</c>.</param>
    /// <returns>The name; empty when the body names none.</returns>
    private static string ErrorOf(byte[] body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.ValueKind == JsonValueKind.Object ? SiteMeta.Text(document.RootElement, "error") : string.Empty;
        }
        catch (JsonException)
        {
            return string.Empty;
        }
    }
}

/// <summary>
/// The website's answer to a vote.
/// </summary>
/// <param name="Vote">The key's vote now, <see cref="SiteVotes.Up"/>; <see langword="null"/> for none.</param>
/// <param name="Up">The mod's upvotes.</param>
internal sealed record VoteAnswer(string? Vote, int Up);

/// <summary>
/// A vote the website refused or could not take.
/// </summary>
/// <param name="error">The refusal's name, such as <c>NotDownloaded</c>, or <see cref="SiteVotes.Unreachable"/>.</param>
internal sealed class SiteVoteException(string error) : Exception(error)
{
    /// <summary>
    /// Gets the refusal's name.
    /// </summary>
    public string Error { get; } = error;
}
