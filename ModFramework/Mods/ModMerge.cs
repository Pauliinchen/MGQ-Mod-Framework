//----------------------------------------------------------------
//  ModMerge.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Named the framework's own script in the log of the files left out
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Dropped the source of a mod, which is always the website
//      Paulinchen  2026-11-06: Made the mods of the website alone, without the relay's catalog to merge
//      Paulinchen  2026-10-31: Told the notes of the latest version as plain lines, as the description
//      Paulinchen  2026-10-30: Carried what the website tells of each mod beside its versions, and of each version beside
//                              its files
//                            - Offered the newest version with a package for the platform the game runs on and named the mods without one
//                            - Moved into the Mod Framework
//                            - Named each mod after its script and folder in Patch and left the rest of its package out
//                            - Carried each mod's tag and each version's requirements
//                            - Compared two versions for the plan
//                            - Carried the versions the website keeps the downloads of
//      Paulinchen  2026-10-24: Carried the website's thumbnail
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Makes the mods the mod browser offers out of the website's list.
/// </summary>
internal static partial class ModMerge
{
    /// <summary>
    /// The most changelog lines kept per mod.
    /// </summary>
    public const int MaxNotes = 40;

    /// <summary>
    /// The most characters a changelog line keeps.
    /// </summary>
    public const int MaxNoteLength = 400;

    /// <summary>
    /// Makes the mods.
    /// </summary>
    /// <param name="site">The website's mods; <see langword="null"/> when the list could not be had.</param>
    /// <returns>The mods, in no particular order.</returns>
    public static IReadOnlyList<BrowsedMod> Merge(IReadOnlyList<SiteMod>? site) =>
        (site ?? []).Select(FromSite).OfType<BrowsedMod>().Where(Offered).ToList();

    /// <summary>
    /// Finds the website's mods none of whose versions has a package for the platform the list was
    /// read for, which the mod browser names but cannot install.
    /// </summary>
    /// <param name="site">The website's mods; <see langword="null"/> when the list could not be had.</param>
    /// <returns>The mods.</returns>
    public static IReadOnlyList<SiteMod> OnOtherPlatforms(IReadOnlyList<SiteMod>? site) =>
        (site ?? []).Where(mod => mod.Versions.All(version => version.Package == null)).ToList();

    /// <summary>
    /// Makes an entry of the website's mod out of its latest version with a package for the
    /// platform the list was read for.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The entry; <see langword="null"/> for a mod without such a version, or a package that is neither a script nor a zip.</returns>
    private static BrowsedMod? FromSite(SiteMod mod)
    {
        var id = $"site:{mod.Slug}";
        var offered = mod.Versions.Where(version => version.Package != null).ToList();

        if (offered.Count == 0)
        {
            return null;
        }

        var latest = offered[0];
        var package = latest.Package!;
        var newer = mod.Versions.TakeWhile(version => version != latest).FirstOrDefault()?.Version ?? string.Empty;
        var name = PatchFolder.NameOf(mod.Slug, InsidePatch(latest.Files));
        var files = OwnFiles(id, name, InsidePatch(latest.Files), true);
        var zip = package.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase);
        var script = package.Name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase) && files.Count == 1;

        if (!zip && !script)
        {
            Log.Write($"mod browser leaves out {id}: its package {package.Name} is neither a zip nor a single script");
            return null;
        }

        var known = offered.Select(version => new ModVersion(version.Version, OwnFiles(id, name, InsidePatch(version.Files), false), version.Requires, version.Notes)).ToList();
        var install = new CatalogMod(id, mod.Name, latest.Version, files, known.Skip(1).ToList(), package.Url, Archive: zip, Tag: mod.Tag, Requires: latest.Requires);
        var notes = MarkdownText.Lines(latest.Changelog, MaxNotes, MaxNoteLength);
        return new BrowsedMod(id, mod.Name, mod.Author, mod.Page, mod.Summary, notes, package.Size, install, name, package.Sha256, known, mod.Thumbnail, mod.Tag, offered.Select(version => version.Version).ToList(), newer, mod.Meta ?? SiteMeta.None);
    }

    /// <summary>
    /// Compares two versions by their leading numbers, as the known versions are ordered.
    /// </summary>
    /// <param name="one">One version, like <c>1.5.2</c>.</param>
    /// <param name="other">The other version.</param>
    /// <returns>Below 0 when <paramref name="one"/> is older, 0 when both are the same, above 0 when it is newer.</returns>
    internal static int CompareVersions(string one, string other) => VersionComparer.Instance.Compare(VersionNumbers(one), VersionNumbers(other));

    /// <summary>
    /// Tells whether the mod browser may offer an entry, and logs why not.
    /// </summary>
    /// <param name="mod">The entry.</param>
    /// <returns>Whether it has files, none of them outside Patch in any known version, and a name a mod in Patch takes.</returns>
    private static bool Offered(BrowsedMod mod)
    {
        if (mod.Install.Files.Count == 0)
        {
            Log.Write($"mod browser leaves out {mod.Id}: it has no files");
            return false;
        }

        if (!PatchFolder.IsName(mod.Folder) && mod.Folder != PatchFolder.FrameworkFolder)
        {
            Log.Write($"mod browser leaves out {mod.Id}: \"{mod.Folder}\" is no name for a mod in Patch");
            return false;
        }

        foreach (var path in mod.Known.SelectMany(version => version.Files.Keys))
        {
            if (RefusalOf(path) is { } why)
            {
                Log.Write($"mod browser leaves out {mod.Id}: its file {path} {why}");
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells why a path inside Patch may not be written.
    /// </summary>
    /// <param name="path">The path inside Patch, with forward slashes.</param>
    /// <returns>Why not, for the log; <see langword="null"/> when it may.</returns>
    internal static string? RefusalOf(string path) =>
        path.Contains(':', StringComparison.Ordinal) || path.Split('/').Any(part => part.Length == 0 || part.Trim().Trim('.').Length == 0)
            ? "would land outside the Patch folder"
            : null;

    /// <summary>
    /// Keeps the files of a mod's own script and folder, since only those go into Patch; a path that
    /// would leave Patch stays, so the mod is refused.
    /// </summary>
    /// <remarks>
    /// A package may bring the first copy of another mod, which owns its updates, so every install,
    /// update, removal and check of the installed version sees only these files.
    /// </remarks>
    /// <param name="id">The mod's id, for the log.</param>
    /// <param name="name">The mod's name in Patch.</param>
    /// <param name="files">Each file's hash by its path inside Patch.</param>
    /// <param name="logged">Whether the files left out are logged.</param>
    /// <returns>The files kept.</returns>
    private static Dictionary<string, string> OwnFiles(string id, string name, Dictionary<string, string> files, bool logged)
    {
        var own = files.Where(file => PatchFolder.Owns(name, file.Key) || RefusalOf(file.Key) != null).ToDictionary(file => file.Key, file => file.Value, StringComparer.Ordinal);

        if (logged && own.Count < files.Count)
        {
            var script = name == PatchFolder.FrameworkFolder ? PatchFolder.FrameworkEntry : name + PatchFolder.Script;
            Log.Write($"mod browser leaves {string.Join(", ", files.Keys.Where(path => !own.ContainsKey(path)))} of {id} out: only {script} and the folder {name} are its own");
        }

        return own;
    }

    /// <summary>
    /// Reads files' paths as their paths inside Patch.
    /// </summary>
    /// <param name="files">Each file's hash by its path as a source names it.</param>
    /// <returns>Each file's hash by its path inside Patch.</returns>
    private static Dictionary<string, string> InsidePatch(IReadOnlyDictionary<string, string> files)
    {
        var inside = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var (path, hash) in files)
        {
            inside[ModInstaller.PathInsidePatch(path)] = hash;
        }

        return inside;
    }

    /// <summary>
    /// Reads a version's leading numbers, such as 1, 5 and 2 of <c>v1.5.2</c>.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <returns>The numbers; empty when it starts with none.</returns>
    private static int[] VersionNumbers(string version) =>
        LeadingNumbers().Match(version) is { Success: true } match
            ? match.Groups[1].Value.Split('.').Select(part => int.TryParse(part, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : int.MaxValue).ToArray()
            : [];

    /// <summary>
    /// A version's leading numbers, after an optional "v".
    /// </summary>
    [GeneratedRegex(@"^\s*[vV]?(\d+(?:\.\d+)*)")]
    private static partial Regex LeadingNumbers();

    /// <summary>
    /// Orders versions by their leading numbers, a missing number as 0, a version without numbers below every other.
    /// </summary>
    private sealed class VersionComparer : IComparer<int[]>
    {
        /// <summary>
        /// The comparer.
        /// </summary>
        public static VersionComparer Instance { get; } = new();

        /// <inheritdoc />
        public int Compare(int[]? x, int[]? y)
        {
            if (x is not { Length: > 0 } || y is not { Length: > 0 })
            {
                return (x?.Length > 0).CompareTo(y?.Length > 0);
            }

            for (var index = 0; index < Math.Max(x.Length, y.Length); index++)
            {
                var order = (index < x.Length ? x[index] : 0).CompareTo(index < y.Length ? y[index] : 0);

                if (order != 0)
                {
                    return order;
                }
            }

            return 0;
        }
    }
}
