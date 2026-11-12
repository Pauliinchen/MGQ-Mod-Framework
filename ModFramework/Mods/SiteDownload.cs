//----------------------------------------------------------------
//  SiteDownload.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Gave up on a download once the website stays silent for a minute
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Took downloads only from the website MGQ_MODS_SITE names when it is set, over its scheme
//      Paulinchen  2026-10-30: Sent the install key as the bearer value of a mod's download
//                            - Moved into the Mod Framework
//      Paulinchen  2026-10-24: Shared the download within the website with the thumbnails
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Downloads a mod of the website's list: only from the website over HTTPS, sent on only within
/// it, and only the file whose hash the list names.
/// </summary>
internal static class SiteDownload
{
    /// <summary>
    /// The website, whose host is the only one a download goes to, over its scheme.
    /// </summary>
    private static readonly Uri Website = new(SiteFeed.Site);

    /// <summary>
    /// The website's host, the only one a download goes to.
    /// </summary>
    public static readonly string Host = Website.Host;

    /// <summary>
    /// The largest file taken, as the website takes.
    /// </summary>
    public const int MaxBytes = 64 * 1024 * 1024;

    /// <summary>
    /// How many redirects a download follows at most.
    /// </summary>
    public const int MaxRedirects = 3;

    /// <summary>
    /// Follows no redirect by itself, so each one is checked, and gives up once the website stays
    /// silent for a minute, before its answer or between two parts of the file.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(1) };

    /// <summary>
    /// Tells whether an address is on the website, over its scheme, HTTPS unless MGQ_MODS_SITE names another.
    /// </summary>
    /// <param name="url">The address.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsSite(Uri url) => url.Scheme == Website.Scheme && url.Port == Website.Port && string.Equals(url.Host, Host, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Downloads a mod's file.
    /// </summary>
    /// <param name="url">The file's address, as the list names it.</param>
    /// <param name="sha256">The SHA-256 of its raw bytes, as the list names it.</param>
    /// <param name="key">The install key, sent as the bearer value so the website notes the download for the ratings; <see langword="null"/> for none.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file differs, or the download failed.</exception>
    public static byte[] Get(string url, string sha256, string? key = null) => Get(url, sha256, Http, key);

    /// <summary>
    /// Downloads a mod's file with a client of the caller's, following at most <see cref="MaxRedirects"/> redirects within the website.
    /// </summary>
    /// <param name="url">The file's address, as the list names it.</param>
    /// <param name="sha256">The SHA-256 of its raw bytes, as the list names it.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <param name="key">The install key, sent as the bearer value; <see langword="null"/> for none.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file differs, or the download failed.</exception>
    internal static byte[] Get(string url, string sha256, HttpClient http, string? key = null) => Checked(url, Fetch(url, "mod", MaxBytes, http, key), sha256);

    /// <summary>
    /// Downloads a file of the website with a client of the caller's, following at most <see cref="MaxRedirects"/> redirects within the website.
    /// </summary>
    /// <param name="url">The file's address.</param>
    /// <param name="what">What the file is, such as "mod", for the player.</param>
    /// <param name="maxBytes">The largest file taken.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <param name="key">The install key, sent as the bearer value of every request, all on the website; <see langword="null"/> for none.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the file is too large, or the download failed.</exception>
    internal static byte[] Fetch(string url, string what, int maxBytes, HttpClient http, string? key = null)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var address) || !IsSite(address))
        {
            Log.Write($"download of {url} refused: it is not on the website");
            throw new InvalidOperationException($"The {what}'s address is not on the website.");
        }

        Log.Write($"downloading {url}");

        try
        {
            for (var hop = 0; hop <= MaxRedirects; hop++)
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, address);

                if (key != null)
                {
                    request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", key);
                }

                using var response = http.Send(request, HttpCompletionOption.ResponseHeadersRead);
                Log.Write($"website GET {address.AbsolutePath}: {(int)response.StatusCode}");

                if ((int)response.StatusCode is >= 300 and < 400)
                {
                    var next = response.Headers.Location is { } location ? new Uri(address, location) : null;

                    if (next == null || !IsSite(next))
                    {
                        Log.Write($"download of {url} refused: sent on to {next?.ToString() ?? "nowhere"}");
                        throw new InvalidOperationException($"The {what} was sent on to {next?.Host ?? "nowhere"}, which is not the website.");
                    }

                    address = next;
                    continue;
                }

                if (response.StatusCode != HttpStatusCode.OK)
                {
                    throw new InvalidOperationException($"The website answered {(int)response.StatusCode}.");
                }

                if (SiteFeed.ReadBody(response, maxBytes, http) is not { } file)
                {
                    Log.Write($"download of {url} refused: more than {maxBytes} bytes");
                    throw new InvalidOperationException(TooLarge(what, maxBytes));
                }

                return file;
            }
        }
        catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or IOException)
        {
            Log.Write($"download of {url} failed: {ex.GetBaseException().Message}");
            throw new InvalidOperationException("The website could not be reached.");
        }

        throw new InvalidOperationException($"The {what} was sent on too often.");
    }

    /// <summary>
    /// Tells the player that a file is too large.
    /// </summary>
    /// <param name="what">What the file is.</param>
    /// <param name="maxBytes">The largest file taken.</param>
    /// <returns>The reason.</returns>
    private static string TooLarge(string what, int maxBytes) =>
        maxBytes == MaxBytes ? $"The {what} is larger than the website takes." : $"The {what} is larger than {maxBytes / (1024 * 1024)} MB.";

    /// <summary>
    /// Checks a downloaded file against the list's hash, and logs the outcome.
    /// </summary>
    /// <param name="url">The file's address, for the log.</param>
    /// <param name="bytes">The file.</param>
    /// <param name="sha256">The list's hash.</param>
    /// <returns>The file.</returns>
    /// <exception cref="InvalidOperationException">The file differs.</exception>
    private static byte[] Checked(string url, byte[] bytes, string sha256)
    {
        var actual = Convert.ToHexStringLower(SHA256.HashData(bytes));

        if (!string.Equals(actual, sha256, StringComparison.OrdinalIgnoreCase))
        {
            Log.Write($"{url} differs from the website's list: hash {Log.Short(actual)}, the list says {Log.Short(sha256)}");
            throw new InvalidOperationException("The mod differs from the version the website checked. It may just have been updated: refresh the list and try again.");
        }

        Log.Write($"{url} matches the website's list, {bytes.Length} bytes");
        return bytes;
    }
}
