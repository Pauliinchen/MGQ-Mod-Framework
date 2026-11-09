//----------------------------------------------------------------
//  ModPictures.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Let the caching start again when its thread could not start
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Caches the card images of the website's mods for the mod browser, one at a time on a thread of
/// its own, and deletes those no mod shows any more.
/// </summary>
/// <param name="download">Downloads an image by its address.</param>
/// <param name="start">Runs the work, on a thread of its own in the game, and tells whether it started.</param>
internal sealed class ModPictures(Func<string, byte[]> download, Func<Action, bool> start)
{
    /// <summary>
    /// Guards the fields below, which the work's thread writes and the game's reads.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// Whether the work runs.
    /// </summary>
    private bool _running;

    /// <summary>
    /// The addresses asked for while the work ran, which it caches once more; <see langword="null"/> for none.
    /// </summary>
    private (string Game, IReadOnlyList<string> Urls)? _again;

    /// <summary>
    /// How many runs of the work ended.
    /// </summary>
    private int _rounds;

    /// <summary>
    /// Gets the images of the game session, downloaded from the website.
    /// </summary>
    public static ModPictures Live { get; } = new(ModThumbnails.Download, work => Threads.TryStart("mods pictures", work));

    /// <summary>
    /// Gets a value indicating whether images are being cached.
    /// </summary>
    public bool Running
    {
        get
        {
            lock (_gate)
            {
                return _running;
            }
        }
    }

    /// <summary>
    /// Gets how many runs ended, so a reader tells one from the next.
    /// </summary>
    public int Rounds
    {
        get
        {
            lock (_gate)
            {
                return _rounds;
            }
        }
    }

    /// <summary>
    /// Tells where an image is cached.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="url">The image's address.</param>
    /// <returns>Its path relative to the game's folder; <see langword="null"/> while it is not cached.</returns>
    public static string? PathOf(string gameFolder, string url)
    {
        var path = ModThumbnails.PathOf(url);
        return File.Exists(Path.Combine(gameFolder, path)) ? path : null;
    }

    /// <summary>
    /// Caches the images of addresses and deletes every other, unless the work runs, which then
    /// does it once more for these addresses; work whose thread cannot start runs at the next call.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="urls">The addresses.</param>
    public void Cache(string gameFolder, IReadOnlyList<string> urls)
    {
        lock (_gate)
        {
            if (_running)
            {
                _again = (gameFolder, urls);
                return;
            }

            _running = true;
        }

        var started = false;

        try
        {
            started = start(() => Run(gameFolder, urls));
        }
        finally
        {
            if (!started)
            {
                lock (_gate)
                {
                    _running = false;
                    _again = null;
                }
            }
        }
    }

    /// <summary>
    /// Caches the images, then those asked for meanwhile.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="urls">The addresses.</param>
    private void Run(string gameFolder, IReadOnlyList<string> urls)
    {
        while (true)
        {
            try
            {
                Store(gameFolder, urls);
            }
            catch (Exception ex)
            {
                // A thread's exception would end the game, so whatever went wrong only leaves images out.
                Log.Write($"caching the mods' images failed: {ex.GetType().Name}: {ex.Message}");
            }

            lock (_gate)
            {
                _rounds++;
                if (_again is not { } again)
                {
                    _running = false;
                    return;
                }

                (gameFolder, urls) = again;
                _again = null;
            }
        }
    }

    /// <summary>
    /// Deletes the images of other addresses and downloads the missing ones; a failed download
    /// leaves its image out until the next run tries again.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="urls">The addresses.</param>
    private void Store(string gameFolder, IReadOnlyList<string> urls)
    {
        var wanted = urls.Distinct(StringComparer.Ordinal).ToList();
        ModThumbnails.Prune(gameFolder, wanted);

        foreach (var url in wanted.Where(url => PathOf(gameFolder, url) == null))
        {
            try
            {
                Log.Write($"cached the image {url} as {ModThumbnails.Store(gameFolder, url, download(url))}");
            }
            catch (Exception ex)
            {
                // One image that cannot be had leaves only itself out.
                Log.Write($"did not cache the image {url}: {ex.Message}");
            }
        }
    }
}
