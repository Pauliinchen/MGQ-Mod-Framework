//----------------------------------------------------------------
//  SiteFeed.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Asked the website for every live version of each mod
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Took the website's address from MGQ_MODS_SITE when it is set
//                            - Read the list, the details and the answers of the website as plain JSON, without a signature
//      Paulinchen  2026-10-30: Read what each version tells beside its files
//                            - Read the categories, keywords, languages, games, platforms, times, downloads and votes of
//                              each mod
//                            - Read the package of each version for the platform the game runs on
//                            - Shared the signed fetch and read with the collections
//                            - Moved into the Mod Framework
//                            - Read each mod's tag and each version's requirements
//                            - Kept the signed list as fetched for the cache and read it back from there
//      Paulinchen  2026-10-24: Read each mod's thumbnail and fetched a mod's description
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Reads the website's list of its mods, <c>GET /api/mods</c>, and a mod's details,
/// <c>GET /api/mods/{slug}</c>, as plain JSON over HTTPS.
/// </summary>
internal static class SiteFeed
{
    /// <summary>
    /// The website: mgqonline.org, or the one the environment variable MGQ_MODS_SITE names, such as
    /// a test website on this machine.
    /// </summary>
    public static readonly string Site = Environment.GetEnvironmentVariable("MGQ_MODS_SITE") ?? "https://mgqonline.org";

    /// <summary>
    /// The address of the website's mods, before a mod's slug.
    /// </summary>
    public static readonly string Address = Site + "/api/mods";

    /// <summary>
    /// The query that asks for schema 4: each mod's tag, each version's requirements and its
    /// package of each platform, and every live version, so an older copy is recognised; without it
    /// the website answers schema 1, as older readers of the list take it.
    /// </summary>
    public const string SchemaQuery = "?schema=4";

    /// <summary>
    /// The list's address.
    /// </summary>
    public static readonly string ListAddress = Address + SchemaQuery;

    /// <summary>
    /// The largest list taken.
    /// </summary>
    public const int MaxBytes = 8 * 1024 * 1024;

    /// <summary>
    /// Why the list failed when the website could not be reached or answered with an error.
    /// </summary>
    public const string Unreachable = "The website could not be reached.";

    /// <summary>
    /// Why the list failed when it cannot be read.
    /// </summary>
    public const string Unreadable = "The mod list of the website could not be read.";

    /// <summary>
    /// Follows no redirect, since the list comes from its address alone.
    /// </summary>
    internal static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(15) };

    /// <summary>
    /// Fetches the list and reads it.
    /// </summary>
    /// <returns>The mods.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be read.</exception>
    public static IReadOnlyList<SiteMod> Fetch() => ReadList(FetchList(Http));

    /// <summary>
    /// Fetches the list and checks that it can be read, keeping it exactly as it came for the cache.
    /// </summary>
    /// <returns>The list as it came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be read.</exception>
    public static byte[] FetchList() => FetchList(Http);

    /// <summary>
    /// Fetches the list with a client of the caller's and checks that it can be read.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <returns>The list as it came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be read.</exception>
    internal static byte[] FetchList(HttpClient http)
    {
        var list = Fetched(ListAddress, "mod list", http);
        ReadList(list);
        return list;
    }

    /// <summary>
    /// Reads a list as it came, such as the cache's, with the packages for the platform the game runs on.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The mods.</returns>
    /// <exception cref="SiteFeedException">The list could not be read.</exception>
    public static IReadOnlyList<SiteMod> ReadList(byte[] list) => ReadList(list, Platforms.Package);

    /// <summary>
    /// Reads a list as it came, with the packages for a platform.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="platform">The platform whose packages are read, <see cref="Platforms.Pc"/> or <see cref="Platforms.Android"/>.</param>
    /// <returns>The mods.</returns>
    /// <exception cref="SiteFeedException">The list could not be read.</exception>
    internal static IReadOnlyList<SiteMod> ReadList(byte[] list, string platform) => Read(list, "mod list", body => Parse(body, platform));

    /// <summary>
    /// Fetches a mod's details, <c>GET /api/mods/{slug}</c>, and reads its description.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <returns>The description, Markdown; empty when the mod has none.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the details could not be read.</exception>
    public static string FetchDescription(string slug) => FetchDescription(slug, Http);

    /// <summary>
    /// Fetches a mod's details with a client of the caller's and reads its description.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="http">The client.</param>
    /// <returns>The description, Markdown; empty when the mod has none.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the details could not be read.</exception>
    internal static string FetchDescription(string slug, HttpClient http)
    {
        var what = $"details of {slug}";
        return Read(Fetched($"{Address}/{Uri.EscapeDataString(slug)}{SchemaQuery}", what, http), what, DescriptionOf);
    }

    /// <summary>
    /// Fetches an answer of the website as it comes.
    /// </summary>
    /// <param name="address">The answer's address.</param>
    /// <param name="what">What the answer is, for the log.</param>
    /// <param name="http">The client.</param>
    /// <returns>The answer.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached or answered with an error, or the answer is too large.</exception>
    internal static byte[] Fetched(string address, string what, HttpClient http)
    {
        var path = new Uri(address).AbsolutePath;

        try
        {
            using var response = http.Send(new HttpRequestMessage(HttpMethod.Get, address), HttpCompletionOption.ResponseHeadersRead);
            Log.Write($"website GET {path}: {(int)response.StatusCode}");

            if (response.StatusCode != HttpStatusCode.OK)
            {
                throw new SiteFeedException(Unreachable);
            }

            if (response.Content.Headers.ContentLength > MaxBytes)
            {
                Log.Write($"the website's {what} is larger than {MaxBytes} bytes");
                throw new SiteFeedException(Unreadable);
            }

            return response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException)
        {
            Log.Write($"website GET {path} failed: {ex.GetBaseException().Message}");
            throw new SiteFeedException(Unreachable);
        }
    }

    /// <summary>
    /// Reads an answer of the website.
    /// </summary>
    /// <typeparam name="T">What is read of it.</typeparam>
    /// <param name="body">The answer exactly as it came.</param>
    /// <param name="what">What the answer is, for the log.</param>
    /// <param name="parse">Reads it.</param>
    /// <returns>What was read.</returns>
    /// <exception cref="SiteFeedException">The answer is too large or could not be read.</exception>
    internal static T Read<T>(byte[] body, string what, Func<byte[], T> parse)
    {
        if (body.Length > MaxBytes)
        {
            Log.Write($"the website's {what} is larger than {MaxBytes} bytes");
            throw new SiteFeedException(Unreadable);
        }

        try
        {
            return parse(body);
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or KeyNotFoundException or FormatException)
        {
            Log.Write($"the website's {what} could not be read: {ex.Message}");
            throw new SiteFeedException(Unreadable);
        }
    }

    /// <summary>
    /// Reads the list.
    /// </summary>
    /// <param name="body">The list as JSON.</param>
    /// <param name="platform">The platform whose packages are read.</param>
    /// <returns>The mods, each with at least one version.</returns>
    private static List<SiteMod> Parse(byte[] body, string platform)
    {
        using var document = JsonDocument.Parse(body);
        var mods = new List<SiteMod>();

        foreach (var mod in document.RootElement.GetProperty("mods").EnumerateArray())
        {
            var versions = new List<SiteVersion>();
            var listed = mod.GetProperty("versions").EnumerateArray().ToList();

            foreach (var version in listed)
            {
                var (package, files) = PackageOf(version, platform);
                versions.Add(new SiteVersion(
                    Text(version, "version"),
                    Text(version, "changelog"),
                    DateTimeOffset.Parse(Text(version, "uploadedAt"), CultureInfo.InvariantCulture),
                    package,
                    files,
                    ModRequirement.Read(version),
                    VersionNotes.Read(version)));
            }

            if (versions.Count > 0)
            {
                var slug = Text(mod, "slug");
                mods.Add(new SiteMod(slug, Text(mod, "name"), Text(mod, "summary"), Text(mod, "author"), Text(mod, "page"), versions.OrderByDescending(version => version.UploadedAt).ToList(), ThumbnailOf(mod, slug), ModTag.Parse(Text(mod, "tag")) ?? string.Empty, SiteMeta.Read(mod, listed)));
            }
        }

        return mods;
    }

    /// <summary>
    /// Reads a version's package for a platform with its files: from its package of each platform,
    /// else from the package a list before the platforms names, which is the PC's.
    /// </summary>
    /// <param name="version">The version as JSON.</param>
    /// <param name="platform">The platform.</param>
    /// <returns>The package and each of its files' hash by its path; no package and no files when the version has none for the platform.</returns>
    private static (SitePackage? Package, Dictionary<string, string> Files) PackageOf(JsonElement version, string platform)
    {
        JsonElement package = default;
        JsonElement files = default;

        if (version.TryGetProperty("packages", out var packages) && packages.ValueKind == JsonValueKind.Array)
        {
            package = packages.EnumerateArray().FirstOrDefault(each => each.ValueKind == JsonValueKind.Object && Text(each, "platform") == platform);
            files = package.ValueKind == JsonValueKind.Object ? package.GetProperty("files") : default;
        }
        else if (platform == Platforms.Pc)
        {
            package = version.GetProperty("package");
            files = version.GetProperty("files");
        }

        var hashes = new Dictionary<string, string>(StringComparer.Ordinal);

        if (package.ValueKind != JsonValueKind.Object)
        {
            return (null, hashes);
        }

        foreach (var file in files.EnumerateArray())
        {
            hashes[Text(file, "path")] = Text(file, "sha256").ToLowerInvariant();
        }

        var size = package.TryGetProperty("size", out var bytes) && bytes.TryGetInt64(out var length) ? length : 0;
        return (new SitePackage(Text(package, "name"), size, Text(package, "sha256").ToLowerInvariant(), Text(package, "url")), hashes);
    }

    /// <summary>
    /// Reads a mod's thumbnail, taking it only on the website over HTTPS.
    /// </summary>
    /// <param name="mod">The mod as JSON.</param>
    /// <param name="slug">The mod's slug, for the log.</param>
    /// <returns>The thumbnail; <see langword="null"/> when it has none or one elsewhere.</returns>
    private static SiteThumbnail? ThumbnailOf(JsonElement mod, string slug)
    {
        if (!mod.TryGetProperty("thumbnail", out var thumbnail) || thumbnail.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var url = Text(thumbnail, "url");

        if (!Uri.TryCreate(url, UriKind.Absolute, out var address) || !SiteDownload.IsSite(address))
        {
            Log.Write($"the thumbnail of {slug} is left out: {(url.Length > 0 ? $"{url} is not on the website" : "it has no address")}");
            return null;
        }

        return new SiteThumbnail(address.AbsoluteUri, Number(thumbnail, "width"), Number(thumbnail, "height"), thumbnail.TryGetProperty("spoiler", out var spoiler) && spoiler.ValueKind == JsonValueKind.True);
    }

    /// <summary>
    /// Reads the description of a mod's details.
    /// </summary>
    /// <param name="body">The details as JSON.</param>
    /// <returns>The description; empty when it has none.</returns>
    private static string DescriptionOf(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        return Text(document.RootElement.GetProperty("mod"), "description");
    }

    /// <summary>
    /// Reads a whole number field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The number; 0 when the field is missing or no whole number.</returns>
    private static int Number(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : 0;

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The text; empty when the field is missing, null or no text.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
}

/// <summary>
/// A list of the website that could not be had, for a reason the player is told as it is.
/// </summary>
/// <param name="reason">The reason.</param>
internal sealed class SiteFeedException(string reason) : Exception(reason);

/// <summary>
/// A mod of the website's list.
/// </summary>
/// <param name="Slug">The mod's id on the website.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Summary">What it does, in a sentence.</param>
/// <param name="Author">Who made it.</param>
/// <param name="Page">The mod's page on the website.</param>
/// <param name="Versions">Its versions, the latest upload first.</param>
/// <param name="Thumbnail">The image its card shows; <see langword="null"/> for none.</param>
/// <param name="Tag">Its tag, see <see cref="ModTag"/>; empty when the list names none or one this version does not know.</param>
/// <param name="Meta">What else the list tells of it; <see langword="null"/> for <see cref="SiteMeta.None"/>.</param>
internal sealed record SiteMod(string Slug, string Name, string Summary, string Author, string Page, IReadOnlyList<SiteVersion> Versions, SiteThumbnail? Thumbnail = null, string Tag = "", SiteMeta? Meta = null);

/// <summary>
/// The PNG image the card of a mod of the website shows.
/// </summary>
/// <param name="Url">Its address, on the website.</param>
/// <param name="Width">Its width in pixels, as the list names it.</param>
/// <param name="Height">Its height in pixels, as the list names it.</param>
/// <param name="Spoiler">Whether it shows a spoiler, so a card blurs it.</param>
internal sealed record SiteThumbnail(string Url, int Width, int Height, bool Spoiler);

/// <summary>
/// A version of a mod of the website.
/// </summary>
/// <param name="Version">The version.</param>
/// <param name="Changelog">What changed, Markdown.</param>
/// <param name="UploadedAt">When it was uploaded.</param>
/// <param name="Package">What a game on the platform the list was read for downloads; <see langword="null"/> when the version has no package for it.</param>
/// <param name="Files">Each file's SHA-256 of its raw bytes by its path as the package holds it; none without a package.</param>
/// <param name="Requires">What it needs; <see langword="null"/> for nothing.</param>
/// <param name="Notes">What it tells beside its files; <see langword="null"/> for nothing.</param>
internal sealed record SiteVersion(string Version, string Changelog, DateTimeOffset UploadedAt, SitePackage? Package, IReadOnlyDictionary<string, string> Files, IReadOnlyList<ModRequirement>? Requires = null, VersionNotes? Notes = null);

/// <summary>
/// The file a version of a mod of the website is downloaded as: a script or a zip.
/// </summary>
/// <param name="Name">The file's name.</param>
/// <param name="Size">Its size in bytes.</param>
/// <param name="Sha256">The SHA-256 of its raw bytes.</param>
/// <param name="Url">Its address.</param>
internal sealed record SitePackage(string Name, long Size, string Sha256, string Url);
