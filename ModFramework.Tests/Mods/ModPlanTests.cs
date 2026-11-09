//----------------------------------------------------------------
//  ModPlanTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//                            - Left out the retagged mark of Mods.ini lines, which no release wrote
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of a new install's order, the player's order and the warnings
//      Paulinchen  2026-11-01: Covered tags taken only from the authors, a tag the player gave before left out
//                            - Covered the copy of the website's tags in the DLL for a mod no source tags
//      Paulinchen  2026-10-30: Covered the tag a mod declares when no source tags it
//                            - Covered the order by the authors' load order hints, a new mod placed by them, a hint a
//                              requirement contradicts, hints in a circle, and the warnings of conflicts and of an order
//                              against a hint
//                            - Covered how each requirement stands and the mods that need a mod
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers planning how the installed mods load: the order of a new install, the player's order kept
/// in Mods.ini, the tags the authors give, and the warnings of requirements, conflicts and hints.
/// </summary>
public sealed class ModPlanTests
{
    /// <summary>
    /// Asserts that without Mods.ini the mods load by tag, then by name, a requirement before the
    /// mods needing it and a load order hint before the name, that a hint a requirement contradicts
    /// is left out and hints in a circle leave the order to the names, and that Mods.ini takes a line
    /// per mod in that order.
    /// </summary>
    [Fact]
    public void Build_OrdersANewInstallByTagRequirementsAndHints()
    {
        var core = Site("core", ModTag.Framework);
        var plan = ModPlan.Build(
            [Mod("Zulu"), Mod("Bravo", requires: ("zulu", "")), Mod("Alpha", requires: ("zulu", "")), Mod("Multiplayer"), Mod("core", known: core)],
            Lines(),
            "0.1.0");

        Assert.Equal(["core", "Multiplayer", "Zulu", "Alpha", "Bravo"], plan.Mods.Select(mod => mod.Mod.Name));
        Assert.Equal(
            [("core", "on Framework"), ("Multiplayer", "on Title"), ("Zulu", "on Regular"), ("Alpha", "on Regular"), ("Bravo", "on Regular")],
            plan.Ini.Select(line => (line.Key, ModsIni.Format(line.Value))));
        Assert.All(plan.Mods, mod => Assert.Empty(mod.Warnings));

        var map = Mod("Map") with { Notes = VersionNotes.None with { LoadAfter = ["zulu"] } };
        Assert.Equal(["Alpha", "Zulu", "Map"], ModPlan.Build([Mod("Alpha"), map, Mod("Zulu")], Lines(), "0.1.0").Mods.Select(mod => mod.Mod.Name));

        var first = Mod("First") with { Notes = VersionNotes.None with { LoadAfter = ["second"] } };
        var second = Mod("Second", requires: ("first", ""));
        var charlie = Mod("Charlie") with { Notes = VersionNotes.None with { LoadAfter = ["delta"] } };
        var delta = Mod("Delta") with { Notes = VersionNotes.None with { LoadAfter = ["charlie"] } };
        Assert.Equal(["Charlie", "Delta", "First", "Second"], ModPlan.Build([second, first, delta, charlie], Lines(), "0.1.0").Mods.Select(mod => mod.Mod.Name));
    }

    /// <summary>
    /// Asserts that the player's order stays, a new mod goes after the mod before it in the default
    /// order or right after the last mod its hints make it follow, the line of a mod no longer
    /// installed is kept, and a mod's tag comes from its authors only: the website's, else the copy
    /// of the website's tags in the DLL, else Regular, whatever tag the player gave it before.
    /// </summary>
    [Fact]
    public void Build_KeepsThePlayersOrderAndTakesTheTagsFromTheAuthors()
    {
        var kept = ModPlan.Build(
            [Mod("Alpha"), Mod("Bravo"), Mod("Charlie")],
            Lines(("Charlie", "on Regular"), ("Alpha", "on Regular"), ("Gone", "off Regular")),
            "0.1.0");
        var map = Mod("Map") with { Notes = VersionNotes.None with { LoadAfter = ["zulu"] } };
        var placed = ModPlan.Build([Mod("Alpha"), map, Mod("Zulu"), Mod("Other")], Lines(("Alpha", "on Regular"), ("Zulu", "on Regular"), ("Other", "on Regular")), "0.1.0");
        var tagged = ModPlan.Build(
            [Mod("Own"), Mod("Multiplayer"), Mod("Sheet", known: Site("sheet", ModTag.Regular))],
            Lines(("Own", "on Title"), ("Multiplayer", "on Regular"), ("Sheet", "on Data")),
            "0.1.0");

        Assert.Equal(["Charlie", "Alpha", "Bravo"], kept.Mods.Select(mod => mod.Mod.Name));
        Assert.Equal(["Charlie", "Alpha", "Bravo", "Gone"], kept.Ini.Select(line => line.Key));
        Assert.Equal(["Alpha", "Zulu", "Map", "Other"], placed.Mods.Select(mod => mod.Mod.Name));
        Assert.Equal(
            [("Multiplayer", ModTag.Title, TagSource.Shipped), ("Own", ModTag.Regular, TagSource.Default), ("Sheet", ModTag.Regular, TagSource.Site)],
            tagged.Mods.Select(mod => (mod.Mod.Name, mod.Tag, mod.TagFrom)));
        Assert.Equal(["on Title", "on Regular", "on Regular"], tagged.Ini.Select(line => ModsIni.Format(line.Value)));
    }

    /// <summary>
    /// Asserts a warning for a requirement missing, off, too old, loading later and a framework too
    /// old, none for a mod that is off, a warning of a conflict on both mods whichever names the
    /// other and of a player's order against an author's hint, and that each requirement tells how
    /// it stands while only mods that are on count as needing a mod.
    /// </summary>
    [Fact]
    public void Build_WarnsOfRequirementsConflictsAndHintsNotMet()
    {
        var needy = Mod("Needy", requires: [("missing-mod", "1.0"), ("off-mod", ""), ("old-mod", "2.0"), ("Later", ""), ("mod-framework", "9.0")]);
        var plan = ModPlan.Build(
            [needy, Mod("Later"), Mod("Off_Mod", requires: ("nothing-here", "")), Mod("Old_Mod", "1.5"), Mod("Quiet", requires: ("old-mod", ""))],
            Lines(("Needy", "on Regular"), ("Later", "on Regular"), ("Off_Mod", "off Regular"), ("Old_Mod", "on Regular"), ("Quiet", "off Regular")),
            "0.1.0-dev");
        var planned = plan.Mods.Single(mod => mod.Mod.Name == "Needy");

        Assert.Equal(
            [
                new ModWarning(ModWarning.Missing, "missing-mod", "1.0"),
                new ModWarning(ModWarning.Off, "Off_Mod", string.Empty),
                new ModWarning(ModWarning.OlderVersion, "Old_Mod", "2.0"),
                new ModWarning(ModWarning.LoadsLater, "Later", string.Empty),
                new ModWarning(ModWarning.OlderVersion, ModPlan.FrameworkName, "9.0"),
            ],
            planned.Warnings);
        Assert.Empty(plan.Mods.Single(mod => mod.Mod.Name == "Off_Mod").Warnings);
        Assert.Equal(
            [
                new ModNeed("missing-mod", "1.0", ModNeed.Missing, string.Empty, string.Empty),
                new ModNeed("Off_Mod", string.Empty, ModNeed.Off, InstalledMod.Unknown, "Off_Mod"),
                new ModNeed("Old_Mod", "2.0", ModNeed.OlderVersion, "1.5", "Old_Mod"),
                new ModNeed("Later", string.Empty, ModNeed.Met, InstalledMod.Unknown, "Later"),
                new ModNeed(ModPlan.FrameworkTitle, "9.0", ModNeed.OlderVersion, "0.1.0", string.Empty),
            ],
            ModPlan.NeedsOf(planned, plan.Mods, "0.1.0-dev"));
        Assert.Equal(["Needy"], ModPlan.NeededBy(plan.Mods.Single(mod => mod.Mod.Name == "Old_Mod"), plan.Mods));

        // Conflicts and hints, in an order the player chose.
        var map = Mod("Map") with { Notes = VersionNotes.None with { LoadAfter = ["level-cap"], Conflicts = [new SiteConflict("old-map", "Both draw the map.")] } };
        var conflicts = ModPlan.Build([map, Mod("Level_Cap"), Mod("Old_Map")], Lines(("Map", "on Regular"), ("Level_Cap", "on Regular"), ("Old_Map", "on Regular")), "0.1.0");
        var mapped = conflicts.Mods.Single(mod => mod.Mod.Name == "Map");

        Assert.Equal(
            [new ModWarning(ModWarning.Conflict, "Old_Map", string.Empty, "Both draw the map."), new ModWarning(ModWarning.LoadsBeforeHint, "Level_Cap", string.Empty)],
            mapped.Warnings.OrderBy(warning => warning.Kind));
        Assert.Equal([new ModWarning(ModWarning.Conflict, "Map", string.Empty, "Both draw the map.")], conflicts.Mods.Single(mod => mod.Mod.Name == "Old_Map").Warnings);
        Assert.Equal([(ModHint.After, "Level_Cap", false)], ModPlan.HintsOf(mapped, conflicts.Mods).Select(hint => (hint.Way, hint.Other.Mod.Name, hint.Kept)));
    }

    /// <summary>
    /// Makes an installed mod.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="version">Its version.</param>
    /// <param name="known">The mod of a source it is.</param>
    /// <param name="requires">What it needs, each as a name and a version.</param>
    /// <returns>The mod.</returns>
    internal static InstalledMod Mod(string name, string version = InstalledMod.Unknown, BrowsedMod? known = null, params (string Name, string Version)[] requires) =>
        new(name, known, version, requires.Select(requirement => new ModRequirement(requirement.Name, requirement.Version)).ToList());

    /// <summary>
    /// Makes a mod of the website with a tag.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="tag">Its tag.</param>
    /// <returns>The mod.</returns>
    internal static BrowsedMod Site(string slug, string tag) =>
        ModMerge.Merge([ModMergeTests.SiteScript(slug, slug, $"{slug}.rb", "1.0", ModMergeTests.Script) with { Tag = tag }])[0];

    /// <summary>
    /// Makes lines of Mods.ini.
    /// </summary>
    /// <param name="lines">Each line's name and value.</param>
    /// <returns>The lines.</returns>
    private static List<KeyValuePair<string, ModsIniEntry>> Lines(params (string Name, string Value)[] lines) =>
        lines.Select(line => new KeyValuePair<string, ModsIniEntry>(line.Name, ModsIni.Parse(line.Value))).ToList();
}
