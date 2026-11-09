//----------------------------------------------------------------
//  ModBrowse.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Matched a search by every word typed, whatever the case
//      Paulinchen  2026-11-01: Ordered by the upvotes alone
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Decides which mods the mod browser shows for the player's picks of its filters and in which
/// order, by the website's rules, so the game and the website list alike: a mod shows when it has
/// one pick of each group that has any.
/// </summary>
internal static class ModBrowse
{
    /// <summary>
    /// The order by the newest upload of a mod's versions.
    /// </summary>
    public const string Updated = "updated";

    /// <summary>
    /// The order by when a mod was made.
    /// </summary>
    public const string Newest = "newest";

    /// <summary>
    /// The order by downloads.
    /// </summary>
    public const string Downloads = "downloads";

    /// <summary>
    /// The order by the upvotes, the most first.
    /// </summary>
    public const string Rating = "rating";

    /// <summary>
    /// The order by name.
    /// </summary>
    public const string Name = "name";

    /// <summary>
    /// The platform pick that keeps every mod.
    /// </summary>
    public const string AnyPlatform = "any";

    /// <summary>
    /// The most keywords the filters offer.
    /// </summary>
    public const int MostKeywords = 30;

    /// <summary>
    /// The English names of the language tags the website takes.
    /// </summary>
    private static readonly Dictionary<string, string> LanguageNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["en"] = "English",
        ["ja"] = "Japanese",
        ["ru"] = "Russian",
        ["zh-Hans"] = "Chinese, simplified",
        ["zh-Hant"] = "Chinese, traditional",
        ["ko"] = "Korean",
        ["es"] = "Spanish",
        ["pt"] = "Portuguese",
        ["fr"] = "French",
        ["de"] = "German",
        ["it"] = "Italian",
        ["pl"] = "Polish",
        ["uk"] = "Ukrainian",
        ["vi"] = "Vietnamese",
        ["id"] = "Indonesian",
        ["th"] = "Thai",
        ["tr"] = "Turkish",
    };

    /// <summary>
    /// Gets every order, in the order the filters offer them.
    /// </summary>
    public static IReadOnlyList<string> Orders { get; } = [Updated, Newest, Downloads, Rating, Name];

    /// <summary>
    /// Gets the kinds of the game a mod works with, in the order the filters offer them.
    /// </summary>
    public static IReadOnlyList<string> Games { get; } = ["english", "russian", "untranslated"];

    /// <summary>
    /// Gets the platform picks, in the order the filters offer them.
    /// </summary>
    public static IReadOnlyList<string> PlatformPicks { get; } = [Platforms.Pc, Platforms.Android, AnyPlatform];

    /// <summary>
    /// Names a language tag as the player reads it.
    /// </summary>
    /// <param name="tag">The tag, such as <c>ru</c>.</param>
    /// <returns>Its English name, such as "Russian"; an unknown tag as given.</returns>
    public static string LanguageName(string tag) => LanguageNames.TryGetValue(tag, out var name) ? name : tag;

    /// <summary>
    /// Tells whether a mod passes the picks: one pick of each group that has any, and a package for
    /// the platform picked.
    /// </summary>
    /// <param name="meta">What the website tells of the mod; <see langword="null"/> for none, which counts as a mod for the PC, as does a mod that names no platform.</param>
    /// <param name="picks">The picks.</param>
    /// <returns>Whether it shows.</returns>
    public static bool Passes(SiteMeta? meta, BrowsePicks picks)
    {
        IReadOnlyList<string> platforms = meta is { Platforms.Count: > 0 } ? meta.Platforms : [Platforms.Pc];
        var known = meta ?? SiteMeta.None;

        return (picks.Platform == AnyPlatform || platforms.Contains(picks.Platform, StringComparer.Ordinal))
            && (picks.Categories.Count == 0 || known.Categories.Any(category => picks.Categories.Contains(category.Slug, StringComparer.Ordinal)))
            && (picks.Keywords.Count == 0 || known.Keywords.Any(keyword => picks.Keywords.Contains(keyword, StringComparer.OrdinalIgnoreCase)))
            && (picks.Languages.Count == 0 || known.Languages.Any(language => picks.Languages.Contains(language, StringComparer.OrdinalIgnoreCase)))
            && (picks.Games.Count == 0 || known.WorksWith.Any(game => picks.Games.Contains(game, StringComparer.Ordinal)));
    }

    /// <summary>
    /// Tells whether a text holds every word of a search, whatever the case, as the browser's search
    /// narrows the mods and the collections while the player types.
    /// </summary>
    /// <param name="text">The text searched, such as a mod's name, summary, author and keywords.</param>
    /// <param name="search">What the player typed; empty for no search.</param>
    /// <returns>Whether it holds every word; true for no search.</returns>
    public static bool Matches(string text, string search) =>
        search.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).All(word => text.Contains(word, StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Makes the comparer of an order: a mod with the value first, by it as the website orders, then
    /// those without it, each by name.
    /// </summary>
    /// <param name="order">The order, see <see cref="Orders"/>; another one orders by name.</param>
    /// <returns>The comparer of a mod's name and what the website tells of it.</returns>
    public static IComparer<(string Name, SiteMeta? Meta)> Comparer(string order) => Comparer<(string Name, SiteMeta? Meta)>.Create((one, other) =>
    {
        var byValue = order switch
        {
            Updated => Latest(other.Meta?.UpdatedAt, one.Meta?.UpdatedAt),
            Newest => Latest(other.Meta?.CreatedAt, one.Meta?.CreatedAt),
            Downloads => Either(one.Meta, other.Meta, meta => meta.Downloads, meta => meta.UpdatedAt),
            Rating => Either(one.Meta, other.Meta, meta => meta.Upvotes),
            _ => 0,
        };

        return byValue != 0 ? byValue : StringComparer.OrdinalIgnoreCase.Compare(one.Name, other.Name);
    });

    /// <summary>
    /// Tells what the filters offer for the mods the browser has and the player's picks: each
    /// category, keyword and language with how many of the mods have it, leaving out one none has
    /// unless it is picked.
    /// </summary>
    /// <param name="metas">What the website tells of each mod; <see langword="null"/> for none.</param>
    /// <param name="options">What the website's filters offer; <see langword="null"/> while none are kept, which takes the categories and keywords of the mods.</param>
    /// <param name="picks">The picks.</param>
    /// <returns>The filters.</returns>
    public static BrowseFilters Filters(IReadOnlyList<SiteMeta?> metas, SiteFilterOptions? options, BrowsePicks picks)
    {
        var known = metas.OfType<SiteMeta>().ToList();
        var categories = (options?.Categories ?? [.. known.SelectMany(meta => meta.Categories).DistinctBy(category => category.Slug).OrderBy(category => category.Name, StringComparer.OrdinalIgnoreCase)])
            .Select(category => new BrowseCount(category.Slug, category.Name, known.Count(meta => meta.Categories.Any(each => each.Slug == category.Slug)), picks.Categories.Contains(category.Slug, StringComparer.Ordinal)))
            .Where(count => count.Mods > 0 || count.Picked)
            .ToList();
        var used = known.SelectMany(meta => meta.Keywords.Distinct(StringComparer.OrdinalIgnoreCase))
            .GroupBy(keyword => keyword, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.Count(), StringComparer.OrdinalIgnoreCase);
        var offered = options?.Keywords.ToList() ?? used.OrderByDescending(pair => pair.Value).ThenBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase).Select(pair => pair.Key).ToList();
        var keywords = offered.Take(MostKeywords).Concat(picks.Keywords.Where(keyword => !offered.Take(MostKeywords).Contains(keyword, StringComparer.OrdinalIgnoreCase)))
            .Select(keyword => new BrowseCount(keyword, keyword, used.GetValueOrDefault(keyword), picks.Keywords.Contains(keyword, StringComparer.OrdinalIgnoreCase)))
            .Where(count => count.Mods > 0 || count.Picked)
            .ToList();
        var languages = known.SelectMany(meta => meta.Languages.Distinct(StringComparer.OrdinalIgnoreCase)).Concat(picks.Languages)
            .GroupBy(language => language, StringComparer.OrdinalIgnoreCase)
            .Select(group => new BrowseCount(group.Key, LanguageName(group.Key), known.Count(meta => meta.Languages.Contains(group.Key, StringComparer.OrdinalIgnoreCase)), picks.Languages.Contains(group.Key, StringComparer.OrdinalIgnoreCase)))
            .OrderByDescending(count => count.Mods)
            .ThenBy(count => count.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
        var games = Games.Select(game => new BrowseCount(game, game, known.Count(meta => meta.WorksWith.Contains(game, StringComparer.Ordinal)), picks.Games.Contains(game, StringComparer.Ordinal))).ToList();
        return new BrowseFilters(categories, keywords, languages, games);
    }

    /// <summary>
    /// Compares two times so that the later comes first and a missing one last.
    /// </summary>
    /// <param name="other">The other mod's time.</param>
    /// <param name="one">The one mod's time.</param>
    /// <returns>Below 0 when the one comes first.</returns>
    private static int Latest(DateTimeOffset? other, DateTimeOffset? one) =>
        one is null || other is null ? (one is null).CompareTo(other is null) : Nullable.Compare(other, one);

    /// <summary>
    /// Compares two mods by values the larger first, a mod without them last.
    /// </summary>
    /// <param name="one">What the website tells of the one mod.</param>
    /// <param name="other">What it tells of the other.</param>
    /// <param name="values">The values, compared in their order.</param>
    /// <returns>Below 0 when the one comes first.</returns>
    private static int Either(SiteMeta? one, SiteMeta? other, params Func<SiteMeta, IComparable?>[] values)
    {
        if (one is null || other is null)
        {
            return (one is null).CompareTo(other is null);
        }

        foreach (var value in values)
        {
            var (mine, theirs) = (value(one), value(other));
            var order = mine is null || theirs is null ? (mine is null).CompareTo(theirs is null) : theirs.CompareTo(mine);

            if (order != 0)
            {
                return order;
            }
        }

        return 0;
    }
}

/// <summary>
/// The player's picks of the mod browser's filters.
/// </summary>
/// <param name="Categories">The categories picked, by slug.</param>
/// <param name="Keywords">The keywords picked.</param>
/// <param name="Languages">The language tags picked.</param>
/// <param name="Games">The kinds of the game picked, see <see cref="ModBrowse.Games"/>.</param>
/// <param name="Platform">The platform picked, see <see cref="ModBrowse.PlatformPicks"/>.</param>
internal sealed record BrowsePicks(IReadOnlyList<string> Categories, IReadOnlyList<string> Keywords, IReadOnlyList<string> Languages, IReadOnlyList<string> Games, string Platform)
{
    /// <summary>
    /// Makes the picks of no filter, on the platform the game runs on.
    /// </summary>
    /// <param name="platform">The platform the game runs on.</param>
    /// <returns>The picks.</returns>
    public static BrowsePicks None(string platform) => new([], [], [], [], platform);

    /// <summary>
    /// Counts the picks, as the filters button shows them: every box filled, and the platform while it
    /// is not the one the game runs on.
    /// </summary>
    /// <param name="platform">The platform the game runs on.</param>
    /// <returns>The number of picks.</returns>
    public int CountFor(string platform) => Categories.Count + Keywords.Count + Languages.Count + Games.Count + (Platform == platform ? 0 : 1);
}

/// <summary>
/// What the mod browser's filters offer.
/// </summary>
/// <param name="Categories">The categories, in the website's order.</param>
/// <param name="Keywords">The keywords, the most used first.</param>
/// <param name="Languages">The languages, the most used first.</param>
/// <param name="Games">The kinds of the game, see <see cref="ModBrowse.Games"/>.</param>
internal sealed record BrowseFilters(IReadOnlyList<BrowseCount> Categories, IReadOnlyList<BrowseCount> Keywords, IReadOnlyList<BrowseCount> Languages, IReadOnlyList<BrowseCount> Games);

/// <summary>
/// One choice of a filter.
/// </summary>
/// <param name="Value">What a pick names it by.</param>
/// <param name="Name">Its name as the player reads it.</param>
/// <param name="Mods">How many of the browser's mods have it.</param>
/// <param name="Picked">Whether it is picked.</param>
internal sealed record BrowseCount(string Value, string Name, int Mods, bool Picked);
