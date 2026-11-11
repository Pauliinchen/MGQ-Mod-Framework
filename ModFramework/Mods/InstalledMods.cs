//----------------------------------------------------------------
//  InstalledMods.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Matched a mod in Patch by the name of any version of a website's mod and told whether it
//                              has an update, a copy installed in part too, whose version stays unknown
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
/// Finds the mods the game folder's Patch folder holds, each matched to a mod of the website one
/// of whose versions takes that name.
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
        return Of(PatchFolder.ModNames(game), known, ModScan.Detect(known, game, logged: false));
    }

    /// <summary>
    /// Makes the installed mods of the names Patch holds, each matched to a mod of the website.
    /// </summary>
    /// <param name="names">The names of the mods in Patch, see <see cref="PatchFolder.ModNames"/>.</param>
    /// <param name="known">The mods of the website.</param>
    /// <param name="states">How each stands, see <see cref="ModScan.Detect"/>.</param>
    /// <returns>The mods in the order of their names.</returns>
    public static IReadOnlyList<InstalledMod> Of(IEnumerable<string> names, IReadOnlyList<BrowsedMod> known, IReadOnlyDictionary<string, ModState> states) =>
        names.Select(name =>
        {
            var match = Match(name, known, states);
            return Installed(name, match, match != null ? states[match.Id] : null);
        }).ToList();

    /// <summary>
    /// Finds the website's mod a name in Patch is: one of whose known versions takes that name,
    /// the one whose installed version takes it first.
    /// </summary>
    /// <param name="name">The name in Patch.</param>
    /// <param name="known">The mods of the website.</param>
    /// <param name="states">How each stands, see <see cref="ModScan.Detect"/>.</param>
    /// <returns>The mod; <see langword="null"/> for none.</returns>
    private static BrowsedMod? Match(string name, IReadOnlyList<BrowsedMod> known, IReadOnlyDictionary<string, ModState> states)
    {
        var named = known.Where(mod => mod.Known.Any(version => Same(version.Name, name))).ToList();
        return named.Find(mod => states.TryGetValue(mod.Id, out var state) && state.Installed is { } installed && Same(installed.Name, name)) ?? named.FirstOrDefault();
    }

    /// <summary>
    /// Makes an installed mod.
    /// </summary>
    /// <param name="name">Its name in Patch.</param>
    /// <param name="match">The mod of the website it is; <see langword="null"/> for none.</param>
    /// <param name="state">How that mod stands; <see langword="null"/> for none.</param>
    /// <returns>The mod in the version it holds whole under this name, needing and telling what that version does, or what the latest version does for any other copy.</returns>
    private static InstalledMod Installed(string name, BrowsedMod? match, ModState? state)
    {
        var whole = state is { Installed: { } installed, Repair: false } && Same(installed.Name, name) ? installed : null;
        var version = whole ?? match?.Known[0];
        return new InstalledMod(name, match, whole?.Version ?? InstalledMod.Unknown, version?.Requires ?? [], version?.Notes, state?.Status == ModStatus.Update);
    }

    /// <summary>
    /// Tells whether two names in Patch are one, as the game finds files.
    /// </summary>
    /// <param name="one">One name.</param>
    /// <param name="other">The other name.</param>
    /// <returns>Whether they are the same but for case.</returns>
    private static bool Same(string one, string other) => string.Equals(one, other, StringComparison.OrdinalIgnoreCase);
}

/// <summary>
/// A mod the Patch folder holds.
/// </summary>
/// <param name="Name">Its name: its script's without <c>.rb</c>, or its folder's.</param>
/// <param name="Known">The mod of the website it is; <see langword="null"/> for one it does not know.</param>
/// <param name="Version">The known version it holds whole; <see cref="Unknown"/> for a changed copy, a copy in part and a mod neither knows.</param>
/// <param name="Requires">What it needs.</param>
/// <param name="Notes">What its version tells beside its files, such as the mods it does not work with; <see langword="null"/> for a mod neither source knows.</param>
/// <param name="Update">Whether the website offers an update of it, see <see cref="ModStatus.Update"/>.</param>
internal sealed record InstalledMod(string Name, BrowsedMod? Known, string Version, IReadOnlyList<ModRequirement> Requires, VersionNotes? Notes = null, bool Update = false)
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
