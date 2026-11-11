//----------------------------------------------------------------
//  ModUpdates.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Met no need with a copy installed in part
//      Paulinchen  2026-11-08: Left the mods the player updates by hand out of the updates and told a need of one
//      Paulinchen  2026-11-07: Removed the list of mods the helper was told to update
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Dropped the order by source, which is always the website
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//      Paulinchen  2026-10-30: Downloaded a website's mod with the install key and noted it for the ratings
//                            - Put first only a version with a package for the platform the game runs on
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// An installed mod, the framework included, whose lists offer a newer version.
/// </summary>
/// <param name="Mod">The mod as the lists offer it; its latest version is the update.</param>
/// <param name="Installed">The version installed.</param>
internal sealed record ModUpdate(BrowsedMod Mod, string Installed);

/// <summary>
/// How a version a mod needs stands, as <see cref="ModUpdates.Require"/> tells it.
/// </summary>
/// <param name="State">See <see cref="RequireState"/>.</param>
/// <param name="Mod">The mod as the lists offer it; <see langword="null"/> while they know none of that name.</param>
/// <param name="Installed">The version installed; <see langword="null"/> while it is unknown.</param>
/// <param name="Offered">The version an update installs; <see langword="null"/> unless the state is <see cref="RequireState.Update"/> or <see cref="RequireState.ByHand"/>.</param>
internal sealed record RequiredVersion(string State, BrowsedMod? Mod, string? Installed, string? Offered);

/// <summary>
/// The states of a version a mod needs, as the topics name them.
/// </summary>
internal static class RequireState
{
    /// <summary>
    /// The version installed is the one needed or newer.
    /// </summary>
    public const string Current = "current";

    /// <summary>
    /// The lists offer a version that meets the need.
    /// </summary>
    public const string Update = "update";

    /// <summary>
    /// The lists offer no version that meets the need.
    /// </summary>
    public const string Unavailable = "unavailable";

    /// <summary>
    /// The lists offer a version that meets the need, and the player installs it by hand.
    /// </summary>
    public const string ByHand = "by_hand";

    /// <summary>
    /// The lists are not known yet.
    /// </summary>
    public const string Unknown = "unknown";
}

/// <summary>
/// The rules of every update: which installed mods the lists offer a newer version of, which mod
/// a name means, which version a need asks for, and where a mod downloads from.
/// </summary>
internal static class ModUpdates
{
    /// <summary>
    /// Lists the installed mods whose lists offer a newer version, the framework first, then by
    /// name, but the mods the player updates by hand.
    /// </summary>
    /// <param name="known">The mods of the lists.</param>
    /// <param name="states">How each stands in the game folder, see <see cref="ModScan.Detect"/>.</param>
    /// <returns>The updates.</returns>
    public static IReadOnlyList<ModUpdate> Find(IReadOnlyList<BrowsedMod> known, IReadOnlyDictionary<string, ModState> states) =>
        known
            .Where(mod => !mod.ByHand && states.TryGetValue(mod.Id, out var state) && state.Status == ModStatus.Update && state.Installed != null)
            .OrderBy(mod => IsFramework(mod) ? 0 : 1)
            .ThenBy(mod => mod.Name, StringComparer.OrdinalIgnoreCase)
            .Select(mod => new ModUpdate(mod, states[mod.Id].Installed!.Version))
            .ToList();

    /// <summary>
    /// Finds the mod of the lists a name means: its id, else its slug, its name in Patch or its
    /// title, whatever their case, spaces, dashes and underscores; the website's first.
    /// </summary>
    /// <param name="known">The mods of the lists.</param>
    /// <param name="name">The name, such as <c>site:level-cap</c>, <c>level-cap</c> or <c>Level_Cap</c>.</param>
    /// <returns>The mod; <see langword="null"/> for none.</returns>
    public static BrowsedMod? Named(IReadOnlyList<BrowsedMod> known, string name)
    {
        if (known.FirstOrDefault(mod => mod.Id == name) is { } exact)
        {
            return exact;
        }

        var key = ModRequirement.KeyOf(name);
        return key.Length == 0 ? null : known.FirstOrDefault(mod => KeysOf(mod).Contains(key));
    }

    /// <summary>
    /// Tells the keys a name finds a mod of the lists by: its name in Patch, its slug or key, and its title.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The keys, see <see cref="ModRequirement.KeyOf"/>.</returns>
    public static HashSet<string> KeysOf(BrowsedMod mod) =>
        [ModRequirement.KeyOf(mod.Folder), ModRequirement.KeyOf(SlugOf(mod)), ModRequirement.KeyOf(mod.Name)];

    /// <summary>
    /// Tells a mod's slug on the website.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>Its id without the source's prefix.</returns>
    public static string SlugOf(BrowsedMod mod) => mod.Id[(mod.Id.IndexOf(':') + 1)..];

    /// <summary>
    /// Tells whether a mod of the lists is the framework itself, the website's <c>mod-framework</c>.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsFramework(BrowsedMod mod) =>
        ModRequirement.KeyOf(mod.Folder) == ModRequirement.KeyOf(PatchFolder.FrameworkFolder) || ModRequirement.KeyOf(SlugOf(mod)) == ModRequirement.KeyOf(PatchFolder.FrameworkFolder);

    /// <summary>
    /// Tells how a version a mod needs stands and which version an update brings.
    /// </summary>
    /// <remarks>
    /// Only the website keeps the downloads of older versions, so an exact older version comes from its own list alone.
    /// </remarks>
    /// <param name="mod">The mod as the lists offer it; <see langword="null"/> while they know none of that name.</param>
    /// <param name="state">How it stands in the game folder; <see langword="null"/> for unknown, as a copy installed in part counts.</param>
    /// <param name="least">The version needed, such as <c>0.7.0</c>.</param>
    /// <param name="exact">Whether exactly that version is needed, an older one too.</param>
    /// <param name="have">The version the mod knows it runs, which counts before the files' version; <see langword="null"/> for none.</param>
    /// <returns>How it stands.</returns>
    public static RequiredVersion Require(BrowsedMod? mod, ModState? state, string least, bool exact, string? have)
    {
        var installed = have is { Length: > 0 } ? have : state is { Repair: false } ? state.Installed?.Version : null;

        if (installed != null && (exact ? ModMerge.CompareVersions(installed, least) == 0 : ModMerge.CompareVersions(installed, least) >= 0))
        {
            return new RequiredVersion(RequireState.Current, mod, installed, null);
        }

        var offered = mod == null ? null
            : !exact ? (ModMerge.CompareVersions(mod.Latest, least) >= 0 ? mod.Latest : null)
            : ModMerge.CompareVersions(mod.Latest, least) == 0 ? mod.Latest
            : mod.Downloads?.FirstOrDefault(version => ModMerge.CompareVersions(version, least) == 0);

        var answer = offered == null ? RequireState.Unavailable : mod!.ByHand ? RequireState.ByHand : RequireState.Update;
        return new RequiredVersion(answer, mod, installed, offered);
    }

    /// <summary>
    /// Puts a version of a website's mod first, so the merge offers it as the mod's version to install.
    /// </summary>
    /// <param name="site">The website's mods.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="version">The version, such as <c>0.6.9</c>.</param>
    /// <returns>The mods with that version first; <see langword="null"/> when the website has no such version with a package for the platform the game runs on.</returns>
    public static IReadOnlyList<SiteMod>? AtVersion(IReadOnlyList<SiteMod> site, string slug, string version)
    {
        var mod = site.FirstOrDefault(each => each.Slug == slug);
        var wanted = mod?.Versions.FirstOrDefault(each => each.Package != null && ModMerge.CompareVersions(each.Version, version) == 0);

        if (mod == null || wanted == null)
        {
            return null;
        }

        var moved = mod with { Versions = [wanted, .. mod.Versions.Where(each => each != wanted)] };
        return site.Select(each => each == mod ? moved : each).ToList();
    }

    /// <summary>
    /// Downloads a mod from where it is installed from; a website's mod with the install key, noted
    /// as downloaded so the player may rate it.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The script or the zip.</returns>
    public static byte[] Download(BrowsedMod mod)
    {
        var game = ModFolder.GameRoot;
        var key = InstallKey.Bearer(game);
        var bytes = SiteDownload.Get(mod.Install.FileUrl, mod.PackageHash, key);

        if (key != null)
        {
            InstallKey.NoteDownloaded(game, mod.Id[(mod.Id.IndexOf(':') + 1)..]);
        }

        return bytes;
    }
}
