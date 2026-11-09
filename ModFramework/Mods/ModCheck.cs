//----------------------------------------------------------------
//  ModCheck.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Told a mod the player installs or updates by hand instead of offering its install
//      Paulinchen  2026-11-06: Offered a mod a place needs from any source that installs the version needed
//                            - Compared the mods a place needs, such as a world of another mod, against the installed ones
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Compares the mods a save was made with against the installed ones, before the save loads: a mod
/// that is off now, one that is missing (which the website may have), and one
/// installed in another version.
/// </summary>
/// <remarks>
/// Another version alone asks nothing, and neither does a mod that is on now but not in the save, so
/// only a mod off or missing makes the player choose.
/// </remarks>
internal static class ModCheck
{
    /// <summary>
    /// The mod is installed but off.
    /// </summary>
    public const string Off = "off";

    /// <summary>
    /// The mod is missing, and the website has it.
    /// </summary>
    public const string Install = "install";

    /// <summary>
    /// The mod is missing, and the website does not have it.
    /// </summary>
    public const string Unknown = "unknown";

    /// <summary>
    /// The mod is on in another version than the save names.
    /// </summary>
    public const string OtherVersion = "version";

    /// <summary>
    /// The mod is installed in an older version than a place needs, and the lists offer the one needed.
    /// </summary>
    public const string Update = "update";

    /// <summary>
    /// The mod is installed in a newer version than a place needs, and the lists offer the one needed.
    /// </summary>
    public const string Change = "change";

    /// <summary>
    /// A place needs the mod in a version the lists do not offer, or its copy differs from the place's,
    /// so it comes from its author only.
    /// </summary>
    public const string Author = "author";

    /// <summary>
    /// The mod is missing or in another version, and the player installs the one needed by hand from
    /// its page on the website, see <see cref="BrowsedMod.ByHand"/>.
    /// </summary>
    public const string ByHand = "by_hand";

    /// <summary>
    /// Compares a save's mods with the installed ones.
    /// </summary>
    /// <param name="saved">The mods the save names.</param>
    /// <param name="plan">The installed mods as they load now.</param>
    /// <param name="known">The mods of the website.</param>
    /// <returns>A row per mod off or missing, in the save's order, then a row per mod in another
    /// version; none when no mod is off or missing.</returns>
    public static IReadOnlyList<CheckRow> Compare(IReadOnlyList<SavedMod> saved, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var rows = new List<CheckRow>();
        var versions = new List<CheckRow>();

        foreach (var mod in saved.DistinctBy(mod => ModRequirement.KeyOf(mod.Name)))
        {
            var key = ModRequirement.KeyOf(mod.Name);
            var installed = plan.Mods.FirstOrDefault(planned => planned.Mod.Keys.Contains(key));

            if (installed == null)
            {
                var source = known.FirstOrDefault(other => KeysOf(other).Contains(key));
                rows.Add(source == null
                    ? new CheckRow(Unknown, mod.Name, mod.Name, mod.Version, string.Empty, string.Empty)
                    : new CheckRow(source.ByHand ? ByHand : Install, mod.Name, source.Name, mod.Version, source.Latest, source.Id));
            }
            else if (!installed.On)
            {
                rows.Add(new CheckRow(Off, mod.Name, TitleOf(installed.Mod), mod.Version, installed.Mod.Version, installed.Mod.Name));
            }
            else if (Named(mod.Version) && Named(installed.Mod.Version) && !string.Equals(mod.Version, installed.Mod.Version, StringComparison.OrdinalIgnoreCase))
            {
                versions.Add(new CheckRow(OtherVersion, mod.Name, TitleOf(installed.Mod), mod.Version, installed.Mod.Version, installed.Mod.Name));
            }
        }

        return rows.Count == 0 ? [] : [.. rows, .. versions];
    }

    /// <summary>
    /// Compares the mods a place needs, such as a world of another mod, against the installed ones:
    /// a mod missing that the website has in the version needed installs; one in
    /// another version updates to it, or changes back to it when the version needed is older, while
    /// the lists offer it, unless the player installs it by hand; one that is off turns on; and one
    /// the lists do not offer in that version,
    /// or whose copy the place says differs from its own, comes from its author only.
    /// </summary>
    /// <remarks>An install writes the version a row wants, so a version no source installs cannot be offered.</remarks>
    /// <param name="needed">The mods the place needs.</param>
    /// <param name="plan">The installed mods as they load now.</param>
    /// <param name="known">The mods of the website.</param>
    /// <returns>A row per mod that is not on in the version needed, in the order given; none when every one is.</returns>
    public static IReadOnlyList<NeedRow> Needs(IReadOnlyList<NeededMod> needed, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var rows = new List<NeedRow>();

        foreach (var mod in needed.DistinctBy(mod => ModRequirement.KeyOf(mod.Name)))
        {
            var key = ModRequirement.KeyOf(mod.Name);
            var installed = plan.Mods.FirstOrDefault(planned => planned.Mod.Keys.Contains(key));
            var sources = known.Where(other => KeysOf(other).Contains(key)).ToList();
            var source = Named(mod.Version) ? sources.FirstOrDefault(other => Installs(other, mod.Version)) : sources.FirstOrDefault();
            var offered = source != null;
            source ??= sources.FirstOrDefault();
            var title = installed != null ? TitleOf(installed.Mod) : source?.Name ?? mod.Name;
            var have = installed?.Mod.Version ?? string.Empty;
            var want = Named(mod.Version) ? mod.Version : source?.Latest ?? string.Empty;
            var other = installed != null && Named(mod.Version) && !string.Equals(have, mod.Version, StringComparison.OrdinalIgnoreCase);

            if (installed == null || other || mod.Differs)
            {
                var kind = !offered ? Author
                    : source!.ByHand ? ByHand
                    : installed == null || mod.Differs ? Install
                    : Named(have) && ModMerge.CompareVersions(have, mod.Version) > 0 ? Change : Update;
                rows.Add(new NeedRow(kind, mod.Name, title, have, want, offered ? source!.Id : string.Empty, installed?.Mod.Name ?? string.Empty));
            }
            else if (!installed.On)
            {
                rows.Add(new NeedRow(Off, mod.Name, title, have, want, installed.Mod.Name, installed.Mod.Name));
            }
        }

        return rows;
    }

    /// <summary>
    /// Names an installed mod for the player: its source's name, else its own.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The name.</returns>
    private static string TitleOf(InstalledMod mod) => mod.Known?.Name is { Length: > 0 } name ? name : mod.Name;

    /// <summary>
    /// Tells whether a source installs a version: its latest, or one the website keeps the download of.
    /// </summary>
    /// <param name="mod">The source.</param>
    /// <param name="version">The version, such as <c>1.5.0</c>.</param>
    /// <returns>Whether it does.</returns>
    internal static bool Installs(BrowsedMod mod, string version) =>
        string.Equals(mod.Latest, version, StringComparison.OrdinalIgnoreCase) || mod.Downloads?.Contains(version, StringComparer.OrdinalIgnoreCase) == true;

    /// <summary>
    /// Tells whether a version names one, unlike none and the version of a changed copy.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <returns>Whether it does.</returns>
    private static bool Named(string version) => version.Length > 0 && version != InstalledMod.Unknown;

    /// <summary>
    /// Tells the keys a save names a mod of the website by: its name in Patch, its slug's and
    /// its name's.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The keys.</returns>
    private static HashSet<string> KeysOf(BrowsedMod mod) =>
        [ModRequirement.KeyOf(mod.Folder), ModRequirement.KeyOf(mod.Id[(mod.Id.IndexOf(':') + 1)..]), ModRequirement.KeyOf(mod.Name)];
}

/// <summary>
/// A mod a place needs, such as a world of another mod.
/// </summary>
/// <param name="Name">Its name, as in Patch, or on the website.</param>
/// <param name="Version">The version needed; empty for any.</param>
/// <param name="Differs">Whether the place found this game's copy differs from its own.</param>
internal sealed record NeededMod(string Name, string Version, bool Differs);

/// <summary>
/// A mod a place needs that is not on in the version needed.
/// </summary>
/// <param name="Kind">How, see the constants of <see cref="ModCheck"/>: install, update, change, by hand, off or author.</param>
/// <param name="Name">The name the place gives it.</param>
/// <param name="Title">Its name for the player.</param>
/// <param name="Have">Its version installed; empty for none.</param>
/// <param name="Want">The version needed, or the one the lists offer when any is.</param>
/// <param name="Target">The id to install, or the installed mod's name to turn on; empty for none.</param>
/// <param name="Installed">The installed mod's name; empty while it is missing.</param>
internal sealed record NeedRow(string Kind, string Name, string Title, string Have, string Want, string Target, string Installed);

/// <summary>
/// A mod a save names in its header.
/// </summary>
/// <param name="Name">Its name in Patch.</param>
/// <param name="Version">Its version then; empty when unknown.</param>
/// <param name="Tag">Its tag then; empty when unknown.</param>
internal sealed record SavedMod(string Name, string Version, string Tag);

/// <summary>
/// A mod of a save that differs now.
/// </summary>
/// <param name="Kind">How, see the constants of <see cref="ModCheck"/>.</param>
/// <param name="Name">The name the save gives it.</param>
/// <param name="Title">Its name for the player: the website's, else the save's.</param>
/// <param name="Saved">Its version in the save; empty when unknown.</param>
/// <param name="Installed">Its version installed, or the latest the website has; empty for none.</param>
/// <param name="Target">What a fix acts on: the installed mod's name, or the id to install; empty for none.</param>
internal sealed record CheckRow(string Kind, string Name, string Title, string Saved, string Installed, string Target);
