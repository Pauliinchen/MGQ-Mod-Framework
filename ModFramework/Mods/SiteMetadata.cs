//----------------------------------------------------------------
//  SiteMetadata.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-01: Read only the upvotes of each mod
//      Paulinchen  2026-10-30: Read the links, credits and license of each mod, and the save safety, conflicts, load order,
//                              known issues, options and hotkeys of each version
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// What schema 3 of the website's list tells about a mod beside its versions, which the mod
/// browser filters and orders by.
/// </summary>
/// <param name="CreatedAt">When the mod was made on the website; <see langword="null"/> when the list names no time.</param>
/// <param name="UpdatedAt">When its newest version was uploaded, of any platform; <see langword="null"/> without versions.</param>
/// <param name="Downloads">How often it was downloaded.</param>
/// <param name="Categories">Its categories, in the order the list names them.</param>
/// <param name="Keywords">The keywords its uploader typed.</param>
/// <param name="Languages">The language tags of its texts, such as <c>en</c>.</param>
/// <param name="WorksWith">The kinds of the game it works with: <c>english</c>, <c>untranslated</c> or <c>russian</c>.</param>
/// <param name="Platforms">The platforms it has a package for, see <see cref="MGQParadox.ModFramework.Runtime.Platforms"/>.</param>
/// <param name="Upvotes">How many upvoted it.</param>
/// <param name="Links">Its addresses beyond its page, http or https only, in the order <see cref="LinkKinds"/> names them.</param>
/// <param name="Credits">Who made it with what, in the order the list names them.</param>
/// <param name="License">How it may be shared; <see langword="null"/> when the list names nothing.</param>
internal sealed record SiteMeta(
    DateTimeOffset? CreatedAt,
    DateTimeOffset? UpdatedAt,
    int Downloads,
    IReadOnlyList<SiteCategory> Categories,
    IReadOnlyList<string> Keywords,
    IReadOnlyList<string> Languages,
    IReadOnlyList<string> WorksWith,
    IReadOnlyList<string> Platforms,
    int Upvotes,
    IReadOnlyList<SiteLink> Links,
    IReadOnlyList<SiteCredit> Credits,
    SiteLicense? License)
{
    /// <summary>
    /// Gets the kinds of the links a mod may have, in the order they show.
    /// </summary>
    public static IReadOnlyList<string> LinkKinds { get; } = ["source", "homepage", "support", "donation"];

    /// <summary>
    /// Gets the metadata of a mod whose list tells none.
    /// </summary>
    public static SiteMeta None { get; } = new(null, null, 0, [], [], [], [], [], 0, [], [], null);

    /// <summary>
    /// Reads the metadata of a mod of the list.
    /// </summary>
    /// <param name="mod">The mod as JSON.</param>
    /// <param name="versions">Its versions as JSON.</param>
    /// <returns>The metadata; what the list leaves out is empty.</returns>
    public static SiteMeta Read(JsonElement mod, IReadOnlyList<JsonElement> versions)
    {
        var uploads = versions.Select(version => TimeOf(version, "uploadedAt")).OfType<DateTimeOffset>().ToList();
        var categories = Objects(mod, "categories")
            .Select(category => new SiteCategory(Text(category, "slug"), Text(category, "name")))
            .Where(category => category.Slug.Length > 0)
            .ToList();
        var upvotes = mod.TryGetProperty("rating", out var votes) && votes.ValueKind == JsonValueKind.Object ? Math.Max(Number(votes, "up"), 0) : 0;

        return new SiteMeta(
            TimeOf(mod, "createdAt"),
            uploads.Count > 0 ? uploads.Max() : null,
            Math.Max(Number(mod, "downloads"), 0),
            categories,
            Texts(mod, "keywords"),
            Texts(mod, "languages"),
            Texts(mod, "worksWith"),
            versions.SelectMany(PlatformsOf).Distinct(StringComparer.Ordinal).ToList(),
            upvotes,
            LinksOf(mod),
            [.. Objects(mod, "credits").Select(credit => new SiteCredit(Text(credit, "name"), Text(credit, "role"))).Where(credit => credit.Name.Length > 0)],
            LicenseOf(mod));
    }

    /// <summary>
    /// Reads a mod's links, taking only absolute http and https addresses.
    /// </summary>
    /// <param name="mod">The mod as JSON.</param>
    /// <returns>Each link's kind and address, in the order of <see cref="LinkKinds"/>.</returns>
    private static List<SiteLink> LinksOf(JsonElement mod)
    {
        if (!mod.TryGetProperty("links", out var links) || links.ValueKind != JsonValueKind.Object)
        {
            return [];
        }

        return [.. LinkKinds
            .Select(kind => new SiteLink(kind, Text(links, kind)))
            .Where(link => Uri.TryCreate(link.Url, UriKind.Absolute, out var url) && (url.Scheme == Uri.UriSchemeHttps || url.Scheme == Uri.UriSchemeHttp))];
    }

    /// <summary>
    /// Reads a mod's license.
    /// </summary>
    /// <param name="mod">The mod as JSON.</param>
    /// <returns>The license; <see langword="null"/> when the list names no license and nothing of reuploads and edits.</returns>
    private static SiteLicense? LicenseOf(JsonElement mod)
    {
        if (!mod.TryGetProperty("license", out var license) || license.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var read = new SiteLicense(Text(license, "name"), Stated(Text(license, "reuploads")), Stated(Text(license, "edits")));
        return read.Name.Length == 0 && read.Reuploads == SiteLicense.NotStated && read.Edits == SiteLicense.NotStated ? null : read;
    }

    /// <summary>
    /// Reads a rule of a license, an unknown one as not stated.
    /// </summary>
    /// <param name="rule">The rule as the list names it.</param>
    /// <returns><see cref="SiteLicense.NotStated"/>, <c>no</c>, <c>ask-first</c> or <c>with-credit</c>.</returns>
    private static string Stated(string rule) => rule is "no" or "ask-first" or "with-credit" ? rule : SiteLicense.NotStated;

    /// <summary>
    /// Tells the platforms a version has a package for: those of its packages of each platform,
    /// else the PC's for the one package a list before the platforms names.
    /// </summary>
    /// <param name="version">The version as JSON.</param>
    /// <returns>The platforms.</returns>
    private static IEnumerable<string> PlatformsOf(JsonElement version)
    {
        if (version.TryGetProperty("packages", out var packages) && packages.ValueKind == JsonValueKind.Array)
        {
            return packages.EnumerateArray().Where(package => package.ValueKind == JsonValueKind.Object).Select(package => Text(package, "platform")).Where(platform => platform.Length > 0);
        }

        return version.TryGetProperty("package", out var package) && package.ValueKind == JsonValueKind.Object ? [MGQParadox.ModFramework.Runtime.Platforms.Pc] : [];
    }

    /// <summary>
    /// Reads a list of texts, leaving out what is no text or empty.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The texts, trimmed; none when the field is missing.</returns>
    internal static List<string> Texts(JsonElement element, string name) =>
        element.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(each => each.ValueKind == JsonValueKind.String).Select(each => each.GetString()!.Trim()).Where(text => text.Length > 0).ToList()
            : [];

    /// <summary>
    /// Reads a list of objects, leaving out what is no object.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The objects; none when the field is missing.</returns>
    internal static IEnumerable<JsonElement> Objects(JsonElement element, string name) =>
        element.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(each => each.ValueKind == JsonValueKind.Object).ToList()
            : [];

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The text, trimmed; empty when the field is missing or no text.</returns>
    internal static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString()!.Trim() : string.Empty;

    /// <summary>
    /// Reads a whole number field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The number; 0 when the field is missing or no whole number.</returns>
    internal static int Number(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : 0;

    /// <summary>
    /// Reads a time field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The time; <see langword="null"/> when the field is missing or no time.</returns>
    private static DateTimeOffset? TimeOf(JsonElement element, string name) =>
        DateTimeOffset.TryParse(Text(element, name), CultureInfo.InvariantCulture, DateTimeStyles.None, out var time) ? time : null;
}

/// <summary>
/// What a version of a mod tells beside its files: whether it is safe in a running save, the mods
/// it does not work with, the mods it loads before or after, its known issues, and the options and
/// hotkeys the website's scan read from it.
/// </summary>
/// <param name="SaveSafety">See the constants; <see cref="NotStated"/> when the list names none.</param>
/// <param name="Conflicts">The mods it does not work with, by slug, each with why.</param>
/// <param name="LoadBefore">The slugs of the mods its author has it load before.</param>
/// <param name="LoadAfter">The slugs of the mods its author has it load after.</param>
/// <param name="KnownIssues">Its known issues, a line each.</param>
/// <param name="Options">Its options, each with its help.</param>
/// <param name="Hotkeys">Its hotkeys, each with its help and the key it starts on.</param>
internal sealed record VersionNotes(
    string SaveSafety,
    IReadOnlyList<SiteConflict> Conflicts,
    IReadOnlyList<string> LoadBefore,
    IReadOnlyList<string> LoadAfter,
    IReadOnlyList<string> KnownIssues,
    IReadOnlyList<SiteOption> Options,
    IReadOnlyList<SiteOption> Hotkeys)
{
    /// <summary>
    /// The save safety of a version whose author stated none.
    /// </summary>
    public const string NotStated = "not-stated";

    /// <summary>
    /// The save safety of a version safe to add to and remove from a running save.
    /// </summary>
    public const string AnyTime = "any-time";

    /// <summary>
    /// The save safety of a version safe to add to a running save, not to remove from it.
    /// </summary>
    public const string AddOnly = "add-only";

    /// <summary>
    /// The save safety of a version that needs a new game.
    /// </summary>
    public const string NewGame = "new-game";

    /// <summary>
    /// Gets the notes of a version whose list tells none.
    /// </summary>
    public static VersionNotes None { get; } = new(NotStated, [], [], [], [], [], []);

    /// <summary>
    /// Reads the notes of a version of the list.
    /// </summary>
    /// <param name="version">The version as JSON.</param>
    /// <returns>The notes; what the list leaves out is empty.</returns>
    public static VersionNotes Read(JsonElement version)
    {
        var safety = SiteMeta.Text(version, "saveSafety");
        var hotkeys = SiteMeta.Objects(version, "hotkeys")
            .Select(hotkey => new SiteOption(SiteMeta.Text(hotkey, "name"), SiteMeta.Text(hotkey, "help"), hotkey.TryGetProperty("key", out var key) && key.TryGetInt32(out var code) ? code : null));

        return new VersionNotes(
            safety is AnyTime or AddOnly or NewGame ? safety : NotStated,
            [.. SiteMeta.Objects(version, "conflicts").Select(conflict => new SiteConflict(SiteMeta.Text(conflict, "slug"), SiteMeta.Text(conflict, "note"))).Where(conflict => conflict.Slug.Length > 0)],
            SiteMeta.Texts(version, "loadBefore"),
            SiteMeta.Texts(version, "loadAfter"),
            SiteMeta.Texts(version, "knownIssues"),
            [.. SiteMeta.Objects(version, "options").Select(option => new SiteOption(SiteMeta.Text(option, "name"), SiteMeta.Text(option, "help"))).Where(option => option.Name.Length > 0)],
            [.. hotkeys.Where(hotkey => hotkey.Name.Length > 0)]);
    }
}

/// <summary>
/// A mod a version does not work with.
/// </summary>
/// <param name="Slug">The other mod's slug.</param>
/// <param name="Note">Why, as its author says; empty for nothing said.</param>
internal sealed record SiteConflict(string Slug, string Note);

/// <summary>
/// An option or a hotkey of a version.
/// </summary>
/// <param name="Name">Its name, as its row names it.</param>
/// <param name="Help">Its help.</param>
/// <param name="Key">The Windows code of the key a hotkey starts on; <see langword="null"/> for none and for an option.</param>
internal sealed record SiteOption(string Name, string Help, int? Key = null);

/// <summary>
/// A link of a mod beyond its page.
/// </summary>
/// <param name="Kind">See <see cref="SiteMeta.LinkKinds"/>.</param>
/// <param name="Url">Its address, http or https.</param>
internal sealed record SiteLink(string Kind, string Url);

/// <summary>
/// A person who made a mod with what.
/// </summary>
/// <param name="Name">Their name.</param>
/// <param name="Role">What they did; empty for nothing said.</param>
internal sealed record SiteCredit(string Name, string Role);

/// <summary>
/// How a mod may be shared.
/// </summary>
/// <param name="Name">The license's name; empty for none.</param>
/// <param name="Reuploads">Whether others may upload it again: <see cref="NotStated"/>, <c>no</c>, <c>ask-first</c> or <c>with-credit</c>.</param>
/// <param name="Edits">Whether others may share changed copies, as <paramref name="Reuploads"/>.</param>
internal sealed record SiteLicense(string Name, string Reuploads, string Edits)
{
    /// <summary>
    /// A rule the author did not state.
    /// </summary>
    public const string NotStated = "not-stated";
}

/// <summary>
/// A category of the website's mods.
/// </summary>
/// <param name="Slug">Its id, as the filters name it.</param>
/// <param name="Name">Its name as the player reads it.</param>
internal sealed record SiteCategory(string Slug, string Name);
