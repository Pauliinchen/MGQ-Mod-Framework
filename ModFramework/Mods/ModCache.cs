//----------------------------------------------------------------
//  ModCache.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//                            - Kept the website's lists as plain JSON, without a signature
//      Paulinchen  2026-10-30: Named its paths with forward slashes, which JoiPlay reads too
//                            - Kept this install's own votes
//                            - Kept what the filters of the website's list offer
//                            - Kept the website's collections
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Keeps the website's list and its collections as last fetched, so the title
/// sorts the mods and knows their tags and requirements without the network.
/// </summary>
internal static class ModCache
{
    /// <summary>
    /// The cache folder, relative to the game's folder, beside the framework's settings whichever copy runs.
    /// </summary>
    public const string Folder = "Patch/Mod_Framework/Cache";

    /// <summary>
    /// The website's list as it came.
    /// </summary>
    public const string SiteFile = "site.json";


    /// <summary>
    /// The website's collections as they came.
    /// </summary>
    public const string CollectionsFile = "collections.json";

    /// <summary>
    /// What the filters of the website's list offer, as it came.
    /// </summary>
    public const string FiltersFile = "filters.json";

    /// <summary>
    /// This install's own votes, as <c>GET /api/votes</c> answers them.
    /// </summary>
    public const string VotesFile = "votes.json";

    /// <summary>
    /// Keeps the website's list, replacing the one kept before.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="list">The list as it came.</param>
    /// <returns>Whether it was kept.</returns>
    public static bool StoreSite(string gameFolder, byte[] list) => Store(gameFolder, SiteFile, list);

    /// <summary>
    /// Keeps the website's collections, replacing the ones kept before.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="list">The collections as they came.</param>
    /// <returns>Whether they were kept.</returns>
    public static bool StoreCollections(string gameFolder, byte[] list) => Store(gameFolder, CollectionsFile, list);

    /// <summary>
    /// Keeps what the filters of the website's list offer, replacing what was kept before.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="filters">The filters as they came.</param>
    /// <returns>Whether they were kept.</returns>
    public static bool StoreFilters(string gameFolder, byte[] filters) => Store(gameFolder, FiltersFile, filters);

    /// <summary>
    /// Keeps this install's own votes, replacing those kept before.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="body">The votes as <c>GET /api/votes</c> answers them.</param>
    /// <returns>Whether they were kept.</returns>
    public static bool StoreVotes(string gameFolder, byte[] body) => Store(gameFolder, VotesFile, body);

    /// <summary>
    /// Reads this install's own votes kept last.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Each vote by the mod's slug; <see langword="null"/> when none are kept or they cannot be read.</returns>
    public static Dictionary<string, string>? LoadVotes(string gameFolder)
    {
        if (ReadFile(gameFolder, VotesFile) is not { } body)
        {
            return null;
        }

        try
        {
            return SiteVotes.ParseVotes(body);
        }
        catch (JsonException ex)
        {
            Log.Write($"this install's votes in the cache count as none: {ex.Message}");
            return null;
        }
    }


    /// <summary>
    /// Reads the website's list kept last.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The mods; <see langword="null"/> when none is kept or it cannot be read.</returns>
    public static IReadOnlyList<SiteMod>? LoadSite(string gameFolder) => LoadSiteFile(gameFolder, SiteFile, "the website's list", SiteFeed.ReadList);

    /// <summary>
    /// Reads the website's collections kept last.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The collections; <see langword="null"/> when none are kept or they cannot be read.</returns>
    public static IReadOnlyList<SiteCollection>? LoadCollections(string gameFolder) =>
        LoadSiteFile(gameFolder, CollectionsFile, "the website's collections", SiteCollections.ReadList);

    /// <summary>
    /// Reads what the filters of the website's list offered last.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The filters; <see langword="null"/> when none are kept or they cannot be read.</returns>
    public static SiteFilterOptions? LoadFilters(string gameFolder) =>
        LoadSiteFile(gameFolder, FiltersFile, "the website's filters", SiteFilters.ReadList);

    /// <summary>
    /// Reads an answer of the website kept last.
    /// </summary>
    /// <typeparam name="T">What is read of it.</typeparam>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="name">The file's name.</param>
    /// <param name="what">What it is, for the log.</param>
    /// <param name="parse">Reads it.</param>
    /// <returns>What was read; <see langword="null"/> when nothing is kept or it cannot be read.</returns>
    private static T? LoadSiteFile<T>(string gameFolder, string name, string what, Func<byte[], T> parse)
        where T : class
    {
        if (ReadFile(gameFolder, name) is not { } file)
        {
            return null;
        }

        try
        {
            return parse(file);
        }
        catch (SiteFeedException ex)
        {
            Log.Write($"{what} in the cache count as none: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Writes a file of the cache, to a temporary file first, so a read never finds half of one.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="name">The file's name.</param>
    /// <param name="bytes">Its bytes.</param>
    /// <returns>Whether it was written.</returns>
    private static bool Store(string gameFolder, string name, byte[] bytes)
    {
        var full = Path.Combine(gameFolder, Folder, name);
        var temporary = full + IniFile.TempSuffix;

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(full)!);
            File.WriteAllBytes(temporary, bytes);
            File.Move(temporary, full, overwrite: true);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not keep {name} in the cache: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Reads a file of the cache.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="name">The file's name.</param>
    /// <returns>Its bytes; <see langword="null"/> when it is missing or cannot be read.</returns>
    private static byte[]? ReadFile(string gameFolder, string name)
    {
        var full = Path.Combine(gameFolder, Folder, name);

        try
        {
            return File.Exists(full) ? File.ReadAllBytes(full) : null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not read {name} in the cache: {ex.Message}");
            return null;
        }
    }
}
