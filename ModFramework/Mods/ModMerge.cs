//----------------------------------------------------------------
//  ModMerge.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Gave a mod every file its package puts into Patch and named each version, and left out a
//                              package that writes the loader or the framework or gives the loader more than one mod
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
    /// The folder a package laid out like the game folder holds the files of Patch in.
    /// </summary>
    private const string GamePatch = "Patch/";

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
    /// <returns>The entry; <see langword="null"/> for a mod without such a version, a package that is neither a script nor a zip, or a version refused, see <see cref="FilesOf"/>.</returns>
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
        var read = offered.Select((version, index) => FilesOf(mod.Slug, version.Files, latest: index == 0)).ToList();
        var files = read[0].Files;
        var zip = package.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase);
        var script = package.Name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase) && files.Count == 1;

        if (!zip && !script)
        {
            Log.Write($"mod browser leaves out {id}: its package {package.Name} is neither a zip nor a single script");
            return null;
        }

        if (read.Select(version => version.Refusal).FirstOrDefault(refusal => refusal != null) is { } refused)
        {
            Log.Write($"mod browser leaves out {id}: {refused}");
            return null;
        }

        if (read[0].LeftOut.Count > 0)
        {
            var why = mod.Slug == PatchFolder.FrameworkSlug ? $"the framework's package installs only {PatchFolder.FrameworkEntry} and the folder {PatchFolder.FrameworkFolder}" : "they lie outside its Patch folder";
            Log.Write($"mod browser leaves {string.Join(", ", read[0].LeftOut)} of {id} out: {why}");
        }

        var known = offered.Select((version, index) => new ModVersion(version.Version, PatchFolder.NameOf(mod.Slug, read[index].Files), read[index].Files, version.Requires, version.Notes)).ToList();
        var install = new CatalogMod(id, mod.Name, latest.Version, files, known.Skip(1).ToList(), package.Url, Archive: zip, Tag: mod.Tag, Requires: latest.Requires);
        var notes = MarkdownText.Lines(latest.Changelog, MaxNotes, MaxNoteLength);
        return new BrowsedMod(id, mod.Name, mod.Author, mod.Page, mod.Summary, notes, package.Size, install, known[0].Name, package.Sha256, known, mod.Thumbnail, mod.Tag, offered.Select(version => version.Version).ToList(), newer, mod.Meta ?? SiteMeta.None);
    }

    /// <summary>
    /// Reads the files a version of a website's mod puts into Patch: every file of its package, or,
    /// when the package is laid out like the game folder, every file under its Patch folder; the
    /// framework's package puts only its own files there.
    /// </summary>
    /// <remarks>
    /// The website checks an upload with this too, so the author learns at once what the framework would leave out.
    /// </remarks>
    /// <param name="slug">The mod's slug on the website; only <see cref="PatchFolder.FrameworkSlug"/> may ship the framework's files.</param>
    /// <param name="listed">Each file's hash by its path in the package.</param>
    /// <param name="latest">Whether it is the version offered, which may give the loader no more than one mod, named as <see cref="PatchFolder.NameOf"/> names it.</param>
    /// <returns>Each file's hash by its path inside Patch, the paths of the package left out, and why the version may not be installed; <see langword="null"/> when it may.</returns>
    internal static (Dictionary<string, string> Files, List<string> LeftOut, string? Refusal) FilesOf(string slug, IReadOnlyDictionary<string, string> listed, bool latest = true)
    {
        var framework = slug == PatchFolder.FrameworkSlug;
        var laidOut = listed.Keys.Any(path => path.Replace('\\', '/').StartsWith(GamePatch, StringComparison.OrdinalIgnoreCase));
        var files = new Dictionary<string, string>(StringComparer.Ordinal);
        var leftOut = new List<string>();
        string? refusal = null;

        foreach (var (path, hash) in listed)
        {
            var slashed = path.Replace('\\', '/');
            var inside = !laidOut ? slashed : slashed.StartsWith(GamePatch, StringComparison.OrdinalIgnoreCase) ? slashed[GamePatch.Length..] : null;

            if (inside == null || (framework && !PatchFolder.IsFrameworkFile(inside)))
            {
                leftOut.Add(path);
                continue;
            }

            files[inside] = hash;
            refusal ??= PatchFolder.RefusalOf(inside, framework) is { } why ? $"the file {path} {why}" : null;
        }

        if (refusal == null && latest && !framework)
        {
            var rows = PatchFolder.RowsOf(files.Keys);

            if (rows.Count > 1 || (rows.Count == 1 && !string.Equals(rows[0], PatchFolder.NameOf(slug, files), StringComparison.OrdinalIgnoreCase)))
            {
                refusal = $"a package must be one mod, and this one gives the loader {string.Join(" and ", rows)}";
            }
        }

        return (files, leftOut, refusal);
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
    /// <returns>Whether it has files and a name a mod in Patch takes.</returns>
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

        return true;
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
