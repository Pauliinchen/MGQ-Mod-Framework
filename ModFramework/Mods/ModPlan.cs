//----------------------------------------------------------------
//  ModPlan.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Told the installed mods some mods need through the mods those need in turn
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//      Paulinchen  2026-11-01: Took a mod's tag only from its authors, never from the player
//                            - Gave a mod no source tags the tag of the copy of the website's tags in the DLL, never one
//                              the mod declares in its folder
//      Paulinchen  2026-10-30: Gave a mod no source tags the tag it declares, which the player cannot change
//                            - Ordered each tag by the requirements, then the authors' load order hints, then the name,
//                              placed a new mod after the last mod it must follow, else last, and warned of mods on
//                              together that do not work together and of a player's order against a hint
//                            - Told why two mods do not work together
//                            - Told what each mod needs, how each need stands, and the mods that are on and need it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Plans how the mods in Patch load: each mod's tag and whether it is on, the order (by tag, then
/// the player's order, a new mod after the last mod it must follow, else last), and a warning for
/// each requirement not met, each mod on that does not work with another one on, and each load
/// order hint the player's order breaks.
/// </summary>
/// <remarks>
/// The default order of a tag is by requirements, then the authors' load order hints, then the
/// name, so a manual order that breaks it is warned about, never corrected.
/// </remarks>
internal static class ModPlan
{
    /// <summary>
    /// The circles of load order hints already logged, so each is logged once.
    /// </summary>
    private static readonly HashSet<string> LoggedCircles = new(StringComparer.Ordinal);

    /// <summary>
    /// The name the framework itself is needed by, which is always loaded first.
    /// </summary>
    public const string FrameworkName = "Mod_Framework";

    /// <summary>
    /// The framework's name as the player reads it.
    /// </summary>
    public const string FrameworkTitle = "Mod Framework";

    /// <summary>
    /// Plans the mods.
    /// </summary>
    /// <param name="installed">The installed mods, see <see cref="InstalledMods.Scan"/>.</param>
    /// <param name="ini">The lines of Mods.ini by mod name, in their order.</param>
    /// <param name="frameworkVersion">The framework's version, which a mod may need at least.</param>
    /// <returns>The plan.</returns>
    public static PlanResult Build(IReadOnlyList<InstalledMod> installed, IReadOnlyList<KeyValuePair<string, ModsIniEntry>> ini, string frameworkVersion)
    {
        var lines = new Dictionary<string, (ModsIniEntry Entry, int Index)>(StringComparer.OrdinalIgnoreCase);

        for (var index = 0; index < ini.Count; index++)
        {
            lines.TryAdd(ini[index].Key, (ini[index].Value, index));
        }

        var managed = installed.Select(mod => Tagged(mod, lines.TryGetValue(mod.Name, out var line) ? line.Entry : null)).ToList();
        var ordered = new List<(InstalledMod Mod, string Tag, string From, bool On)>();

        var follows = new Dictionary<InstalledMod, Follows>();

        foreach (var tag in ModTag.All)
        {
            var mods = managed.Where(mod => mod.Tag == tag).ToList();
            var tagFollows = FollowsOf(mods.Select(mod => mod.Mod).ToList());
            var byDefault = DefaultOrder(mods.Select(mod => mod.Mod).ToList(), tagFollows);
            var stored = mods.Where(mod => lines.ContainsKey(mod.Mod.Name)).OrderBy(mod => lines[mod.Mod.Name].Index).Select(mod => mod.Mod).ToList();
            ordered.AddRange(Merged(stored, byDefault, tagFollows).Select(mod => mods.First(planned => planned.Mod == mod)));

            foreach (var (mod, after) in tagFollows)
            {
                follows[mod] = after;
            }
        }

        var sequence = ordered.Select(mod => (mod.Mod, mod.On)).ToList();
        var planned = ordered.Select(mod => new PlannedMod(mod.Mod, mod.Tag, mod.From, mod.On, mod.On ? WarningsOf(mod.Mod, sequence, frameworkVersion, follows) : [])).ToList();

        var written = ordered.Select(mod => new KeyValuePair<string, ModsIniEntry>(mod.Mod.Name, new ModsIniEntry(mod.On, mod.Tag))).ToList();
        written.AddRange(ini.Where(line => !managed.Exists(mod => string.Equals(mod.Mod.Name, line.Key, StringComparison.OrdinalIgnoreCase)) && written.TrueForAll(kept => !string.Equals(kept.Key, line.Key, StringComparison.OrdinalIgnoreCase))));
        return new PlanResult(planned, written);
    }

    /// <summary>
    /// Tells how each requirement of a mod stands, whether the mod is on or off.
    /// </summary>
    /// <param name="mod">The planned mod.</param>
    /// <param name="mods">Every planned mod.</param>
    /// <param name="frameworkVersion">The framework's version.</param>
    /// <returns>A need per requirement in its order, named by the installed mod's title where one meets it.</returns>
    public static List<ModNeed> NeedsOf(PlannedMod mod, IReadOnlyList<PlannedMod> mods, string frameworkVersion)
    {
        var needs = new List<ModNeed>();
        var framework = frameworkVersion.Split('-', '+')[0];

        foreach (var requirement in mod.Mod.Requires)
        {
            if (ModRequirement.KeyOf(requirement.Name) == ModRequirement.KeyOf(FrameworkName))
            {
                var old = requirement.Version.Length > 0 && ModMerge.CompareVersions(framework, requirement.Version) < 0;
                needs.Add(new ModNeed(FrameworkTitle, requirement.Version, old ? ModNeed.OlderVersion : ModNeed.Met, framework, string.Empty));
                continue;
            }

            var provider = Provider(mod, requirement, mods);

            if (provider == null)
            {
                needs.Add(new ModNeed(requirement.Name, requirement.Version, ModNeed.Missing, string.Empty, string.Empty));
                continue;
            }

            var older = requirement.Version.Length > 0 && provider.Mod.Version != InstalledMod.Unknown && ModMerge.CompareVersions(provider.Mod.Version, requirement.Version) < 0;
            var state = !provider.On ? ModNeed.Off : older ? ModNeed.OlderVersion : ModNeed.Met;
            needs.Add(new ModNeed(provider.Mod.Title, requirement.Version, state, provider.Mod.Version, provider.Mod.Name));
        }

        return needs;
    }

    /// <summary>
    /// Lists the mods that are on and need a mod.
    /// </summary>
    /// <param name="mod">The planned mod.</param>
    /// <param name="mods">Every planned mod.</param>
    /// <returns>The titles of those mods, in the order they load.</returns>
    public static List<string> NeededBy(PlannedMod mod, IReadOnlyList<PlannedMod> mods) =>
        mods.Where(other => other != mod && other.On && other.Mod.Requires.Any(requirement => Provider(other, requirement, mods) == mod))
            .Select(other => other.Mod.Title)
            .ToList();

    /// <summary>
    /// Lists the installed mods some mods need, directly or through the mods those need in turn.
    /// </summary>
    /// <param name="roots">The mods whose needs count.</param>
    /// <param name="mods">Every planned mod.</param>
    /// <returns>The mods that meet those needs, on or off, each once.</returns>
    public static List<PlannedMod> NeededClosure(IEnumerable<PlannedMod> roots, IReadOnlyList<PlannedMod> mods)
    {
        var needed = new List<PlannedMod>();
        var waiting = new Queue<PlannedMod>(roots);

        while (waiting.TryDequeue(out var mod))
        {
            foreach (var requirement in mod.Mod.Requires)
            {
                if (Provider(mod, requirement, mods) is { } provider && !needed.Contains(provider))
                {
                    needed.Add(provider);
                    waiting.Enqueue(provider);
                }
            }
        }

        return needed;
    }

    /// <summary>
    /// Finds the installed mod that meets a requirement.
    /// </summary>
    /// <param name="needing">The mod needing it, which never meets its own.</param>
    /// <param name="requirement">The requirement.</param>
    /// <param name="mods">Every planned mod.</param>
    /// <returns>The first mod a key of the requirement names; <see langword="null"/> for none.</returns>
    private static PlannedMod? Provider(PlannedMod needing, ModRequirement requirement, IReadOnlyList<PlannedMod> mods)
    {
        var key = ModRequirement.KeyOf(requirement.Name);
        return mods.FirstOrDefault(other => other != needing && other.Mod.Keys.Contains(key));
    }

    /// <summary>
    /// Tells whether two mods do not work together: one of them names the other among its conflicts.
    /// </summary>
    /// <param name="one">One mod.</param>
    /// <param name="other">The other mod.</param>
    /// <returns>The conflict, with its author's note: the one mod's, else the other's; <see langword="null"/> when neither names the other.</returns>
    public static SiteConflict? ConflictBetween(InstalledMod one, InstalledMod other) =>
        (one.Notes?.Conflicts ?? []).FirstOrDefault(conflict => other.Keys.Contains(ModRequirement.KeyOf(conflict.Slug)))
        ?? (other.Notes?.Conflicts ?? []).FirstOrDefault(conflict => one.Keys.Contains(ModRequirement.KeyOf(conflict.Slug)));

    /// <summary>
    /// Gives a mod its tag and tells whether it is on: a source's tag, else the tag of the copy of
    /// the website's tags in the DLL, else Regular.
    /// </summary>
    /// <remarks>
    /// Only a mod's authors tag it; a tag in its line of Mods.ini only lets the loader work without
    /// the DLL.
    /// </remarks>
    /// <param name="mod">The mod.</param>
    /// <param name="line">Its line of Mods.ini; <see langword="null"/> for a mod new to it, which is on.</param>
    /// <returns>The mod, its tag, where the tag comes from and whether it is on.</returns>
    private static (InstalledMod Mod, string Tag, string From, bool On) Tagged(InstalledMod mod, ModsIniEntry? line)
    {
        var on = line?.On ?? true;

        if (mod.Known is { Tag.Length: > 0 } known)
        {
            return (mod, known.Tag, TagSource.Site, on);
        }

        if (ShippedTags.Of(mod.Name) is { } shipped)
        {
            return (mod, shipped, TagSource.Shipped, on);
        }

        return (mod, ModTag.Regular, TagSource.Default, on);
    }

    /// <summary>
    /// Lists the load order hints of a mod toward the installed mods of its tag that are left in
    /// force: those its own author gave, each with whether the order keeps it.
    /// </summary>
    /// <param name="mod">The planned mod.</param>
    /// <param name="mods">Every planned mod, in the order they load.</param>
    /// <returns>Each hint: <see cref="ModHint.After"/> or <see cref="ModHint.Before"/>, the other mod and whether the order keeps it.</returns>
    public static List<ModHint> HintsOf(PlannedMod mod, IReadOnlyList<PlannedMod> mods)
    {
        var tagged = mods.Where(other => other.Tag == mod.Tag).ToList();
        var follows = FollowsOf(tagged.Select(other => other.Mod).ToList());
        var place = tagged.IndexOf(mod);
        var hints = new List<ModHint>();

        foreach (var other in tagged.Where(other => other != mod))
        {
            if (Names(mod.Mod.Notes?.LoadAfter, other.Mod) && follows[mod.Mod].Hinted.Contains(other.Mod))
            {
                hints.Add(new ModHint(ModHint.After, other, tagged.IndexOf(other) < place));
            }
            else if (Names(mod.Mod.Notes?.LoadBefore, other.Mod) && follows[other.Mod].Hinted.Contains(mod.Mod))
            {
                hints.Add(new ModHint(ModHint.Before, other, tagged.IndexOf(other) > place));
            }
        }

        return hints;
    }

    /// <summary>
    /// Tells which mods of one tag each mod must load after: those it needs, and those a load order
    /// hint of either mod's author puts before it, unless a requirement says otherwise. Of hints
    /// that go round in a circle, those of the mod first by name are left out, so the names order
    /// those mods.
    /// </summary>
    /// <param name="mods">The mods of the tag.</param>
    /// <returns>What each mod follows.</returns>
    private static Dictionary<InstalledMod, Follows> FollowsOf(List<InstalledMod> mods)
    {
        var needs = mods.ToDictionary(mod => mod, mod => mods.Where(other => other != mod && mod.Requires.Any(requirement => other.Keys.Contains(ModRequirement.KeyOf(requirement.Name)))).ToHashSet());
        var follows = mods.ToDictionary(mod => mod, mod => new Follows(
            needs[mod],
            mods.Where(other => other != mod && (Names(mod.Notes?.LoadAfter, other) || Names(other.Notes?.LoadBefore, mod)) && !Reaches(other, mod, each => needs[each])).ToHashSet()));
        var circling = new List<InstalledMod>();

        foreach (var mod in mods.OrderBy(mod => mod.Name, StringComparer.OrdinalIgnoreCase))
        {
            foreach (var other in follows[mod].Hinted.OrderBy(other => other.Name, StringComparer.OrdinalIgnoreCase).ToList())
            {
                if (Reaches(other, mod, each => follows[each].Needs.Concat(follows[each].Hinted)))
                {
                    follows[mod].Hinted.Remove(other);
                    circling.AddRange([mod, other]);
                }
            }
        }

        if (circling.Count > 0)
        {
            LogCircle(circling.Distinct());
        }

        return follows;
    }

    /// <summary>
    /// Tells whether a list of slugs names a mod.
    /// </summary>
    /// <param name="slugs">The slugs; <see langword="null"/> for none.</param>
    /// <param name="mod">The mod.</param>
    /// <returns>Whether one names it by a key of its, see <see cref="InstalledMod.Keys"/>.</returns>
    private static bool Names(IReadOnlyList<string>? slugs, InstalledMod mod) =>
        (slugs ?? []).Any(slug => mod.Keys.Contains(ModRequirement.KeyOf(slug)));

    /// <summary>
    /// Tells whether a mod must load after another through any chain of mods it must load after.
    /// </summary>
    /// <param name="from">The later mod.</param>
    /// <param name="to">The earlier mod.</param>
    /// <param name="after">The mods a mod must load after.</param>
    /// <returns>Whether it must.</returns>
    private static bool Reaches(InstalledMod from, InstalledMod to, Func<InstalledMod, IEnumerable<InstalledMod>> after)
    {
        var seen = new HashSet<InstalledMod>();
        var waiting = new Stack<InstalledMod>([from]);

        while (waiting.Count > 0)
        {
            foreach (var earlier in after(waiting.Pop()).Where(seen.Add))
            {
                if (earlier == to)
                {
                    return true;
                }

                waiting.Push(earlier);
            }
        }

        return false;
    }

    /// <summary>
    /// Orders the mods of one tag: each after the mods it needs, then after those the load order
    /// hints put before it, then by name; mods that need each other stay by name.
    /// </summary>
    /// <param name="mods">The mods.</param>
    /// <param name="follows">What each mod follows.</param>
    /// <returns>The mods in the default order.</returns>
    private static List<InstalledMod> DefaultOrder(List<InstalledMod> mods, Dictionary<InstalledMod, Follows> follows)
    {
        var remaining = mods.OrderBy(mod => mod.Name, StringComparer.OrdinalIgnoreCase).ToList();
        var order = new List<InstalledMod>();

        while (remaining.Count > 0)
        {
            var next = remaining.FirstOrDefault(mod => !follows[mod].Needs.Any(remaining.Contains) && !follows[mod].Hinted.Any(remaining.Contains))
                ?? remaining.FirstOrDefault(mod => !follows[mod].Needs.Any(remaining.Contains))
                ?? remaining[0];
            order.Add(next);
            remaining.Remove(next);
        }

        return order;
    }

    /// <summary>
    /// Logs once that the load order hints of some mods go round in a circle.
    /// </summary>
    /// <param name="mods">The mods whose hints are left.</param>
    private static void LogCircle(IEnumerable<InstalledMod> mods)
    {
        var names = string.Join(", ", mods.Select(mod => mod.Name).Order(StringComparer.OrdinalIgnoreCase));

        lock (LoggedCircles)
        {
            if (!LoggedCircles.Add(names))
            {
                return;
            }
        }

        Log.Write($"the load order hints of {names} go round in a circle, so their names order them");
    }

    /// <summary>
    /// Puts the mods new to the player's order in it, in the default order: each right after the
    /// last mod there it must follow, else before the first mod there that must follow it, else last,
    /// and after the new mod placed before it while no mod between must follow it.
    /// </summary>
    /// <param name="stored">The mods in the player's order.</param>
    /// <param name="byDefault">Every mod in the default order.</param>
    /// <param name="follows">What each mod follows.</param>
    /// <returns>Every mod in the player's order.</returns>
    private static List<InstalledMod> Merged(List<InstalledMod> stored, List<InstalledMod> byDefault, Dictionary<InstalledMod, Follows> follows)
    {
        var order = new List<InstalledMod>(stored);
        var lastNew = -1;

        foreach (var mod in byDefault.Where(mod => !stored.Contains(mod)))
        {
            var after = order.FindLastIndex(other => follows[mod].Precede(other));
            var before = order.FindIndex(other => follows[other].Precede(mod));
            var place = after >= 0 ? after + 1 : before >= 0 ? before : order.Count;

            if (lastNew >= place && (before < 0 || before > lastNew))
            {
                place = lastNew + 1;
            }

            order.Insert(place, mod);
            lastNew = place;
        }

        return order;
    }

    /// <summary>
    /// Tells which requirements of a mod are not met, which mods on do not work with it, and which
    /// of its author's load order hints the order breaks.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="sequence">Every installed mod in the order they load, and whether each is on.</param>
    /// <param name="frameworkVersion">The framework's version.</param>
    /// <param name="follows">What each mod follows within its tag.</param>
    /// <returns>A warning per requirement not met (missing, off, an older version, or loading later), per mod on it does not work with, and per hint broken.</returns>
    private static List<ModWarning> WarningsOf(InstalledMod mod, List<(InstalledMod Mod, bool On)> sequence, string frameworkVersion, Dictionary<InstalledMod, Follows> follows)
    {
        var warnings = RequirementWarnings(mod, sequence, frameworkVersion);
        var position = sequence.FindIndex(entry => entry.Mod == mod);

        foreach (var (other, _) in sequence.Where(entry => entry.Mod != mod && entry.On))
        {
            if (ConflictBetween(mod, other) is { } conflict)
            {
                warnings.Add(new ModWarning(ModWarning.Conflict, other.Name, string.Empty, conflict.Note));
            }

            var place = sequence.FindIndex(entry => entry.Mod == other);

            if (Names(mod.Notes?.LoadAfter, other) && follows[mod].Hinted.Contains(other) && place > position)
            {
                warnings.Add(new ModWarning(ModWarning.LoadsBeforeHint, other.Name, string.Empty));
            }
            else if (Names(mod.Notes?.LoadBefore, other) && follows[other].Hinted.Contains(mod) && place < position)
            {
                warnings.Add(new ModWarning(ModWarning.LoadsAfterHint, other.Name, string.Empty));
            }
        }

        return warnings;
    }

    /// <summary>
    /// Tells which requirements of a mod are not met.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="sequence">Every installed mod in the order they load, and whether each is on.</param>
    /// <param name="frameworkVersion">The framework's version.</param>
    /// <returns>A warning per requirement not met: missing, off, an older version, or loading later.</returns>
    private static List<ModWarning> RequirementWarnings(InstalledMod mod, List<(InstalledMod Mod, bool On)> sequence, string frameworkVersion)
    {
        var warnings = new List<ModWarning>();
        var position = sequence.FindIndex(entry => entry.Mod == mod);

        foreach (var requirement in mod.Requires)
        {
            var key = ModRequirement.KeyOf(requirement.Name);

            if (key == ModRequirement.KeyOf(FrameworkName))
            {
                if (requirement.Version.Length > 0 && ModMerge.CompareVersions(frameworkVersion.Split('-', '+')[0], requirement.Version) < 0)
                {
                    warnings.Add(new ModWarning(ModWarning.OlderVersion, FrameworkName, requirement.Version));
                }

                continue;
            }

            var index = sequence.FindIndex(entry => entry.Mod != mod && entry.Mod.Keys.Contains(key));

            if (index < 0)
            {
                warnings.Add(new ModWarning(ModWarning.Missing, requirement.Name, requirement.Version));
                continue;
            }

            var (provider, on) = sequence[index];

            if (!on)
            {
                warnings.Add(new ModWarning(ModWarning.Off, provider.Name, requirement.Version));
            }
            else if (requirement.Version.Length > 0 && provider.Version != InstalledMod.Unknown && ModMerge.CompareVersions(provider.Version, requirement.Version) < 0)
            {
                warnings.Add(new ModWarning(ModWarning.OlderVersion, provider.Name, requirement.Version));
            }
            else if (index > position)
            {
                warnings.Add(new ModWarning(ModWarning.LoadsLater, provider.Name, requirement.Version));
            }
        }

        return warnings;
    }
}

/// <summary>
/// Where a managed mod's tag comes from, as the game script reads it.
/// </summary>
internal static class TagSource
{
    /// <summary>
    /// The website's list.
    /// </summary>
    public const string Site = "site";


    /// <summary>
    /// The copy of the website's tags in the DLL, for a mod no source tags, see <see cref="ShippedTags"/>.
    /// </summary>
    public const string Shipped = "shipped";

    /// <summary>
    /// Nowhere: a mod that neither a source nor the copy of the website's tags tags is Regular.
    /// </summary>
    public const string Default = "default";
}

/// <summary>
/// What a mod that is on warns of: a requirement not met, a mod on it does not work with, or a load
/// order hint the order breaks.
/// </summary>
/// <param name="Kind">See the constants.</param>
/// <param name="Name">The other mod: the installed mod's name, else the name the requirement gives.</param>
/// <param name="Version">The lowest version needed; empty for any and for a warning of no requirement.</param>
/// <param name="Note">Why two mods do not work together, as an author says; empty for none.</param>
internal sealed record ModWarning(string Kind, string Name, string Version, string Note = "")
{
    /// <summary>
    /// The other mod is on and one of the two names the other among the mods it does not work with.
    /// </summary>
    public const string Conflict = "conflict";

    /// <summary>
    /// The mod loads before the other, though its author advises loading it after.
    /// </summary>
    public const string LoadsBeforeHint = "loads_before";

    /// <summary>
    /// The mod loads after the other, though its author advises loading it before.
    /// </summary>
    public const string LoadsAfterHint = "loads_after";

    /// <summary>
    /// The mod needed is not installed.
    /// </summary>
    public const string Missing = "missing";

    /// <summary>
    /// The mod needed is off.
    /// </summary>
    public const string Off = "off";

    /// <summary>
    /// The mod needed is older than the version needed.
    /// </summary>
    public const string OlderVersion = "version";

    /// <summary>
    /// The mod needed loads after the mod needing it.
    /// </summary>
    public const string LoadsLater = "order";
}

/// <summary>
/// How a requirement of a mod stands.
/// </summary>
/// <param name="Name">The mod needed: the installed mod's title, else the name the requirement gives.</param>
/// <param name="Version">The lowest version needed; empty for any.</param>
/// <param name="State">See the constants.</param>
/// <param name="Have">The version installed; empty for a mod missing.</param>
/// <param name="Mod">The installed mod's name, by which it turns on; empty for a mod missing and for the framework.</param>
internal sealed record ModNeed(string Name, string Version, string State, string Have, string Mod)
{
    /// <summary>
    /// The mod needed is on, in a version new enough.
    /// </summary>
    public const string Met = "on";

    /// <summary>
    /// The mod needed is off.
    /// </summary>
    public const string Off = "off";

    /// <summary>
    /// The mod needed is not installed.
    /// </summary>
    public const string Missing = "missing";

    /// <summary>
    /// The mod needed is older than the version needed.
    /// </summary>
    public const string OlderVersion = "version";
}

/// <summary>
/// The mods of its tag a mod must load after.
/// </summary>
/// <param name="Needs">The mods it needs.</param>
/// <param name="Hinted">The mods a load order hint puts before it, a hint a requirement contradicts left out.</param>
internal sealed record Follows(HashSet<InstalledMod> Needs, HashSet<InstalledMod> Hinted)
{
    /// <summary>
    /// Tells whether another mod must load before this one.
    /// </summary>
    /// <param name="other">The other mod.</param>
    /// <returns>Whether this one needs it or a hint puts it before.</returns>
    public bool Precede(InstalledMod other) => Needs.Contains(other) || Hinted.Contains(other);
}

/// <summary>
/// A load order hint of a mod's author toward another installed mod of its tag.
/// </summary>
/// <param name="Way">See the constants.</param>
/// <param name="Other">The other mod.</param>
/// <param name="Kept">Whether the order keeps the hint.</param>
internal sealed record ModHint(string Way, PlannedMod Other, bool Kept)
{
    /// <summary>
    /// The author advises loading the mod after the other.
    /// </summary>
    public const string After = "after";

    /// <summary>
    /// The author advises loading the mod before the other.
    /// </summary>
    public const string Before = "before";
}

/// <summary>
/// An installed mod as it loads.
/// </summary>
/// <param name="Mod">The mod.</param>
/// <param name="Tag">Its tag, see <see cref="ModTag"/>.</param>
/// <param name="TagFrom">Where its tag comes from, see <see cref="TagSource"/>.</param>
/// <param name="On">Whether it is on.</param>
/// <param name="Warnings">Its requirements not met; none for a mod that is off.</param>
internal sealed record PlannedMod(InstalledMod Mod, string Tag, string TagFrom, bool On, IReadOnlyList<ModWarning> Warnings);

/// <summary>
/// The plan of the installed mods.
/// </summary>
/// <param name="Mods">The mods in the order they load.</param>
/// <param name="Ini">The lines Mods.ini holds by this plan: the mods in the order they load, then the lines of mods not installed, as they were.</param>
internal sealed record PlanResult(IReadOnlyList<PlannedMod> Mods, IReadOnlyList<KeyValuePair<string, ModsIniEntry>> Ini);
