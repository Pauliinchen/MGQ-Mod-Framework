//----------------------------------------------------------------
//  InstalledMods.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-01: Dropped the tag a mod declares in its folder
//      Paulinchen  2026-10-30: Read the tag a mod declares in its folder
//                            - Carried what the version a mod holds tells beside its files
//                            - Named a mod as its source names it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Finds the mods the game folder's Patch folder holds, each matched to a mod of the website
/// where one of that name is.
/// </summary>
internal static class InstalledMods
{
    /// <summary>
    /// Finds the mods.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="known">The mods of the website, see <see cref="ModMerge.Merge"/>.</param>
    /// <returns>The mods by their names.</returns>
    public static IReadOnlyList<InstalledMod> Scan(string gameFolder, IReadOnlyList<BrowsedMod> known)
    {
        var game = Path.GetFullPath(gameFolder);
        var states = ModScan.Detect(known, game, logged: false);

        return PatchFolder.ModNames(game).Select(name =>
        {
            var named = known.Where(mod => string.Equals(mod.Folder, name, StringComparison.OrdinalIgnoreCase)).ToList();
            var match = named.Find(mod => states[mod.Id].Installed != null) ?? named.FirstOrDefault();
            return Installed(name, match, match != null ? states[match.Id].Installed : null);
        }).ToList();
    }

    /// <summary>
    /// Makes an installed mod.
    /// </summary>
    /// <param name="name">Its name in Patch.</param>
    /// <param name="match">The mod of the website it is; <see langword="null"/> for none.</param>
    /// <param name="installed">The known version it holds whole; <see langword="null"/> for a changed copy or none.</param>
    /// <returns>The mod, needing and telling what its version does, or what the latest version does for a changed copy.</returns>
    private static InstalledMod Installed(string name, BrowsedMod? match, ModVersion? installed)
    {
        var version = installed ?? match?.Known[0];
        return new InstalledMod(name, match, installed?.Version ?? InstalledMod.Unknown, version?.Requires ?? [], version?.Notes);
    }
}

/// <summary>
/// A mod the Patch folder holds.
/// </summary>
/// <param name="Name">Its name: its script's without <c>.rb</c>, or its folder's.</param>
/// <param name="Known">The mod of the website it is; <see langword="null"/> for one it does not know.</param>
/// <param name="Version">The known version it holds; <see cref="Unknown"/> for a changed copy and a mod neither knows.</param>
/// <param name="Requires">What it needs.</param>
/// <param name="Notes">What its version tells beside its files, such as the mods it does not work with; <see langword="null"/> for a mod neither source knows.</param>
internal sealed record InstalledMod(string Name, BrowsedMod? Known, string Version, IReadOnlyList<ModRequirement> Requires, VersionNotes? Notes = null)
{
    /// <summary>
    /// The version of a changed copy and of a mod the website does not know.
    /// </summary>
    public const string Unknown = "?";

    /// <summary>
    /// Gets where it lies, relative to the game folder.
    /// </summary>
    public string Place => PatchFolder.Name;

    /// <summary>
    /// Gets its name as the player reads it: the name its source gives, else its script's or folder's.
    /// </summary>
    public string Title => Known is { Name.Length: > 0 } known ? known.Name : Name;

    /// <summary>
    /// Gets the keys a requirement names it by, see <see cref="ModRequirement.KeyOf"/>: its name's,
    /// and its slug's when the website knows it.
    /// </summary>
    public IReadOnlySet<string> Keys
    {
        get
        {
            var keys = new HashSet<string>(StringComparer.Ordinal) { ModRequirement.KeyOf(Name) };

            if (Known is { } known)
            {
                keys.Add(ModRequirement.KeyOf(known.Folder));
                keys.Add(ModRequirement.KeyOf(known.Id[(known.Id.IndexOf(':') + 1)..]));
            }

            return keys;
        }
    }
}
