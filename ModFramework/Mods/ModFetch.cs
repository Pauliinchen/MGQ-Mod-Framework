//----------------------------------------------------------------
//  ModFetch.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Caught every error of a fetch, so it never ends the game
//                            - Let a fetch start again when its thread could not start
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Deleted the old DLLs an install left behind at the first fetch of a session
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//                            - Fetched the website's lists as plain JSON, without a signature
//      Paulinchen  2026-10-30: Fetched this install's own votes after the lists
//                            - Fetched what the filters of the website's list offer
//                            - Fetched again when the last fetch ended a while ago
//                            - Fetched the website's collections, and fetched again when asked
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Threading;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Fetches the website's list, its collections and its filters into the cache, on a
/// thread, so the title never waits on the network: once per game session, and again when asked,
/// as the mod browser opens.
/// </summary>
/// <param name="site">Fetches the website's list, checked that it can be read.</param>

/// <param name="collections">Fetches the website's collections, checked that they can be read; <see langword="null"/> for none.</param>
/// <param name="filters">Fetches what the filters of the website's list offer, checked that they can be read; <see langword="null"/> for none.</param>
/// <param name="votes">Fetches this install's own votes into the cache for the game's folder, after the lists; <see langword="null"/> for none.</param>
/// <param name="start">Runs the fetch on a thread of its own and tells whether it started; <see cref="Threads.TryStart"/> when none is given.</param>
internal sealed class ModFetch(Func<byte[]> site, Func<byte[]>? collections = null, Func<byte[]>? filters = null, Action<string>? votes = null, Func<Action, bool>? start = null)
{
    /// <summary>
    /// Runs the fetch on a thread of its own and tells whether it started.
    /// </summary>
    private readonly Func<Action, bool> _start = start ?? (work => Threads.TryStart("mods fetch", work));

    /// <summary>
    /// 1 while a fetch runs.
    /// </summary>
    private int _running;

    /// <summary>
    /// Whether a fetch started in this game session.
    /// </summary>
    private volatile bool _started;

    /// <summary>
    /// How many fetches ended.
    /// </summary>
    private int _rounds;

    /// <summary>
    /// Whether the website's list was fetched and kept.
    /// </summary>
    private volatile bool _siteKept;


    /// <summary>
    /// Whether the website's collections were fetched and kept.
    /// </summary>
    private volatile bool _collectionsKept;

    /// <summary>
    /// When the last fetch ended, in milliseconds of <see cref="Environment.TickCount64"/>; 0 before the first.
    /// </summary>
    private long _endedAt;

    /// <summary>
    /// Gets the fetch of the game session, from the website.
    /// </summary>
    public static ModFetch Live { get; } = new(
        SiteFeed.FetchList, SiteCollections.FetchList, SiteFilters.FetchList, ModRatings.Live.Refresh);

    /// <summary>
    /// Gets a value indicating whether a fetch runs.
    /// </summary>
    public bool Running => Volatile.Read(ref _running) == 1;

    /// <summary>
    /// Gets a value indicating whether a fetch ended and none runs.
    /// </summary>
    public bool Done => !Running && Rounds > 0;

    /// <summary>
    /// Gets how many fetches ended, so a reader tells one from the next.
    /// </summary>
    public int Rounds => Volatile.Read(ref _rounds);

    /// <summary>
    /// Gets a value indicating whether the last fetch kept the website's list.
    /// </summary>
    public bool SiteKept => _siteKept;


    /// <summary>
    /// Gets a value indicating whether the last fetch kept the website's collections.
    /// </summary>
    public bool CollectionsKept => _collectionsKept;

    /// <summary>
    /// Starts the fetch on a thread, unless one started in this game session.
    /// </summary>
    /// <param name="gameFolder">The game's folder, whose cache takes what was fetched.</param>
    public void Start(string gameFolder)
    {
        if (!_started)
        {
            Again(gameFolder);
        }
    }

    /// <summary>
    /// Starts another fetch on a thread, unless one runs or the last one ended less than a while ago.
    /// </summary>
    /// <param name="gameFolder">The game's folder, whose cache takes what was fetched.</param>
    /// <param name="age">How long ago the last fetch must have ended.</param>
    /// <returns>Whether it started.</returns>
    public bool AgainAfter(string gameFolder, TimeSpan age)
    {
        var ended = Interlocked.Read(ref _endedAt);
        return (Rounds == 0 || Environment.TickCount64 - ended >= (long)age.TotalMilliseconds) && Again(gameFolder);
    }

    /// <summary>
    /// Starts another fetch on a thread, unless one runs; a fetch whose thread cannot start leaves
    /// none running, so it may start again.
    /// </summary>
    /// <param name="gameFolder">The game's folder, whose cache takes what was fetched.</param>
    /// <returns>Whether it started.</returns>
    public bool Again(string gameFolder)
    {
        if (Interlocked.Exchange(ref _running, 1) == 1)
        {
            return false;
        }

        var started = false;

        try
        {
            started = _start(() => Fetch(gameFolder));
        }
        finally
        {
            if (started)
            {
                _started = true;
            }
            else
            {
                Volatile.Write(ref _running, 0);
            }
        }

        return started;
    }

    /// <summary>
    /// Runs a fetch on the calling thread, unless one runs.
    /// </summary>
    /// <param name="gameFolder">The game's folder, whose cache takes what was fetched.</param>
    internal void Run(string gameFolder)
    {
        if (Interlocked.Exchange(ref _running, 1) == 0)
        {
            _started = true;
            Fetch(gameFolder);
        }
    }

    /// <summary>
    /// Fetches every source and keeps each that came; one that failed leaves the cache's copy as it was.
    /// The first fetch of the game session deletes the DLLs an install renamed out of the way before.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    private void Fetch(string gameFolder)
    {
        try
        {
            if (Rounds == 0)
            {
                ModScan.DeleteOldDlls(gameFolder);
            }

            _siteKept = Keep("the website's list", () => ModCache.StoreSite(gameFolder, site()));

            _collectionsKept = collections != null && Keep("the website's collections", () => ModCache.StoreCollections(gameFolder, collections()));

            if (filters != null)
            {
                Keep("the website's filters", () => ModCache.StoreFilters(gameFolder, filters()));
            }

            votes?.Invoke(gameFolder);
        }
        catch (Exception ex)
        {
            Log.Write($"the fetch of the mod lists ended on an error: {ex.GetType().Name}: {ex.Message}");
        }
        finally
        {
            Interlocked.Exchange(ref _endedAt, Environment.TickCount64);
            Interlocked.Increment(ref _rounds);
            Volatile.Write(ref _running, 0);
        }
    }

    /// <summary>
    /// Fetches and keeps one source.
    /// </summary>
    /// <param name="what">The source, for the log.</param>
    /// <param name="keep">Fetches and keeps it.</param>
    /// <returns>Whether it was kept.</returns>
    private static bool Keep(string what, Func<bool> keep)
    {
        try
        {
            var kept = keep();
            Log.Write(kept ? $"kept {what} in the cache" : $"fetched {what}, but could not keep it");
            return kept;
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so whatever went wrong only keeps the old copy.
            Log.Write($"could not fetch {what}, so the cache keeps its copy: {ex.GetType().Name}: {ex.Message}");
            return false;
        }
    }
}
