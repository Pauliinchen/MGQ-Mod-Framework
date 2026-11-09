//----------------------------------------------------------------
//  BrowsedMod.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Told whether the player installs and updates the mod by hand
//      Paulinchen  2026-11-07: Dropped the source of a mod, which is always the website
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//      Paulinchen  2026-10-30: Carried what the website tells of the mod beside its versions
//                            - Carried the newest version without a package for the platform the game runs on
//                            - Moved into the Mod Framework
//                            - Named the mod after its script and folder in Patch instead of a script's place there
//                            - Carried the tag its source gives it
//                            - Carried the versions the website keeps the downloads of
//      Paulinchen  2026-10-24: Carried the website's thumbnail
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// A mod of the website the mod browser offers.
/// </summary>
/// <param name="Id">The mod's id: <c>site:</c> and the website's slug.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Author">Who made it.</param>
/// <param name="Page">The mod's page on the website; empty for none.</param>
/// <param name="Summary">What it does, in a sentence.</param>
/// <param name="Notes">The lines of the latest version's changelog.</param>
/// <param name="Bytes">The size of the file it is downloaded as; 0 when unknown.</param>
/// <param name="Install">The latest version as <see cref="ModInstaller"/> installs it, every other known version among its versions.</param>
/// <param name="Folder">The mod's name in Patch, which its script and its folder take, see <see cref="PatchFolder.NameOf"/>.</param>
/// <param name="PackageHash">The SHA-256 of the file the website hands out.</param>
/// <param name="Known">Every version known of the mod, the latest first, then the newest first, each with its files by their paths inside Patch.</param>
/// <param name="Thumbnail">The image the website's card shows; <see langword="null"/> for none.</param>
/// <param name="Tag">The tag the website gives it, see <see cref="ModTag"/>; empty when it names none.</param>
/// <param name="Downloads">The versions the website keeps the downloads of for the platform the game runs on.</param>
/// <param name="NewerElsewhere">The newest version, uploaded after the latest, that has no package for the platform the game runs on; empty for none.</param>
/// <param name="Meta">What the website tells of it beside its versions.</param>
internal sealed record BrowsedMod(string Id, string Name, string Author, string Page, string Summary, IReadOnlyList<string> Notes, long Bytes, CatalogMod Install, string Folder, string PackageHash, IReadOnlyList<ModVersion> Known, SiteThumbnail? Thumbnail = null, string Tag = "", IReadOnlyList<string>? Downloads = null, string NewerElsewhere = "", SiteMeta? Meta = null)
{
    /// <summary>
    /// The latest version.
    /// </summary>
    public string Latest => Install.Version;

    /// <summary>
    /// Gets whether the player installs and updates the mod by hand from its page on the website,
    /// see <see cref="ModTag.ByHand"/>.
    /// </summary>
    public bool ByHand => ModTag.ByHand(Tag);
}

/// <summary>
/// How a mod of the mod browser stands in the game folder, as the game script reads it.
/// </summary>
internal static class ModStatus
{
    /// <summary>
    /// An older known version is installed.
    /// </summary>
    public const string Update = "update";

    /// <summary>
    /// The latest version is installed, or a newer one another list knows.
    /// </summary>
    public const string Current = "current";

    /// <summary>
    /// Some of its files are in Patch, but no known version whole.
    /// </summary>
    public const string Changed = "changed";

    /// <summary>
    /// None of its files is there.
    /// </summary>
    public const string Available = "available";

    /// <summary>
    /// A mod of the website none of whose versions has a package for the platform the game runs on.
    /// </summary>
    public const string OtherPlatform = "other_platform";
}

/// <summary>
/// How a mod of the mod browser stands in the game folder.
/// </summary>
/// <param name="Status">See <see cref="ModStatus"/>.</param>
/// <param name="Installed">The known version installed whole; <see langword="null"/> when none is.</param>
internal sealed record ModState(string Status, ModVersion? Installed);
