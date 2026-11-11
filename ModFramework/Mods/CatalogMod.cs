//----------------------------------------------------------------
//  CatalogMod.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Named each version as the loader names it
//      Paulinchen  2026-11-07: Dropped the kind of an entry, which only the cut sources set
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//      Paulinchen  2026-10-30: Carried what a version tells beside its files
//                            - Moved into the Mod Framework
//                            - Dropped the version of the Mod Config options
//                            - Knew the tag and the requirements the catalog names
//      Paulinchen  2026-10-09: Knew whether the catalog marks the mod personal
//                            - Named the kind of an entry of a name alone
//      Paulinchen  2026-10-06: Removed VersionOf
//                            - Knew the version whose Mod Config options the relay keeps
//                            - Told a link to a zip of a release from a link to a script
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// A mod of the website as <see cref="ModInstaller"/> installs it.
/// </summary>
/// <param name="Key">The mod's key: its name in lower case, without ".rb", spaces, underscores and hyphens.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Version">The current version.</param>
/// <param name="Files">The current files' hashes by their paths inside Patch.</param>
/// <param name="Versions">The older versions the website keeps, newest first.</param>
/// <param name="FileUrl">The address of its package on the website.</param>
/// <param name="Archive">Whether its package is a zip of the mod's files, which go to their paths inside its folder, rather than a script.</param>
/// <param name="Tag">The tag the website gives the mod, see <see cref="ModTag"/>; empty when it names none.</param>
/// <param name="Requires">What the current version needs; <see langword="null"/> for nothing.</param>
internal sealed record CatalogMod(string Key, string Name, string Version, IReadOnlyDictionary<string, string> Files, IReadOnlyList<ModVersion> Versions, string FileUrl, bool Archive = false, string Tag = "", IReadOnlyList<ModRequirement>? Requires = null);

/// <summary>
/// A version of a mod as the website lists it.
/// </summary>
/// <param name="Version">The version.</param>
/// <param name="Name">Its name in Patch and Mods.ini, see <see cref="PatchFolder.NameOf"/>.</param>
/// <param name="Files">Its files' hashes by their paths inside Patch.</param>
/// <param name="Requires">What it needs; <see langword="null"/> for nothing.</param>
/// <param name="Notes">What it tells beside its files, the website's save safety, conflicts and the rest; <see langword="null"/> for nothing.</param>
internal sealed record ModVersion(string Version, string Name, IReadOnlyDictionary<string, string> Files, IReadOnlyList<ModRequirement>? Requires = null, VersionNotes? Notes = null);

/// <summary>
/// A mod another mod needs, as the website found it at the upload.
/// </summary>
/// <param name="Name">The mod needed: a website slug or a folder name, matched by <see cref="KeyOf"/>.</param>
/// <param name="Version">The lowest version that does; empty for any.</param>
internal sealed record ModRequirement(string Name, string Version)
{
    /// <summary>
    /// Reads the requirements an entry of a source lists as <c>requires</c>, each with <c>slug</c> and
    /// <c>minVersion</c>, the lowest version, null for any.
    /// </summary>
    /// <param name="owner">The entry as JSON.</param>
    /// <returns>The requirements; none when the entry lists none, as a source before them does.</returns>
    public static IReadOnlyList<ModRequirement> Read(JsonElement owner)
    {
        if (!owner.TryGetProperty("requires", out var listed) || listed.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return listed.EnumerateArray()
            .Where(entry => entry.ValueKind == JsonValueKind.Object)
            .Select(entry => new ModRequirement(TextOf(entry, "slug"), TextOf(entry, "minVersion")))
            .Where(requirement => requirement.Name.Length > 0)
            .ToList();
    }

    /// <summary>
    /// Makes the key a mod's names are matched by, so the slug <c>party-sheet</c>, the folder
    /// <c>Party_Sheet</c> and the key <c>partysheet</c> name one mod.
    /// </summary>
    /// <param name="name">A slug, a key, a folder or a script name.</param>
    /// <returns>The name in lower case without <c>.rb</c>, spaces, underscores and hyphens.</returns>
    public static string KeyOf(string name)
    {
        var bare = name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase) ? name[..^3] : name;
        return new string(bare.Where(letter => letter is not (' ' or '_' or '-')).ToArray()).ToLowerInvariant();
    }

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The text, trimmed; empty when the field is missing or no text.</returns>
    private static string TextOf(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString()?.Trim() ?? string.Empty : string.Empty;
}
