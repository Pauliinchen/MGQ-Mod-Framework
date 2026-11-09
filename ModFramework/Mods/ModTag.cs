//----------------------------------------------------------------
//  ModTag.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Told that the player installs and updates a Data mod by hand
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// The tags that tell when a mod loads: Framework mods and the title part of Title mods at boot,
/// Regular and Data mods and the rest of Title mods once the player enters the game, in this order.
/// </summary>
internal static class ModTag
{
    /// <summary>
    /// A mod that always loads at boot, such as a framework.
    /// </summary>
    public const string Framework = "Framework";

    /// <summary>
    /// A mod that adds something to the title screen: its title part loads at boot, the rest once the player enters the game.
    /// </summary>
    public const string Title = "Title";

    /// <summary>
    /// A mod loaded once the player enters the game; every mod no source tags is one.
    /// </summary>
    public const string Regular = "Regular";

    /// <summary>
    /// A mod that changes the game's data, loaded after the Regular mods.
    /// </summary>
    public const string Data = "Data";

    /// <summary>
    /// The tags in the order their mods load.
    /// </summary>
    public static readonly string[] All = [Framework, Title, Regular, Data];

    /// <summary>
    /// Reads a tag as a source or Mods.ini names it.
    /// </summary>
    /// <param name="text">The tag, in any case.</param>
    /// <returns>The tag as spelled here; <see langword="null"/> for none or one this version does not know.</returns>
    public static string? Parse(string? text) => All.FirstOrDefault(tag => string.Equals(tag, text?.Trim(), StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Tells where a tag's mods load among the others.
    /// </summary>
    /// <param name="tag">The tag, as spelled here.</param>
    /// <returns>0 for Framework up to 3 for Data.</returns>
    public static int Rank(string tag) => Array.IndexOf(All, tag);

    /// <summary>
    /// Tells whether the player installs and updates a tag's mods by hand from their page on the
    /// website, so the framework never installs or updates them itself: the Data mods.
    /// </summary>
    /// <param name="tag">The tag, as spelled here.</param>
    /// <returns>Whether they are installed by hand.</returns>
    public static bool ByHand(string tag) => tag == Data;
}
