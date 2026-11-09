//----------------------------------------------------------------
//  ModDescriptions.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Let a description be fetched again when its thread could not start
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Fetched a description without a signature
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Fetches the descriptions of the website's mods for the mod browser as the player looks at
/// them, each on a thread of its own, and keeps them as plain lines for the game session.
/// </summary>
/// <param name="fetch">Fetches a mod's description, Markdown, by its slug.</param>
/// <param name="start">Runs the work, on a thread of its own in the game, and tells whether it started.</param>
internal sealed class ModDescriptions(Func<string, string> fetch, Func<Action, bool> start)
{
    /// <summary>
    /// The most lines a description keeps.
    /// </summary>
    public const int MaxLines = 60;

    /// <summary>
    /// The most characters a line of a description keeps.
    /// </summary>
    public const int MaxLineLength = 400;

    /// <summary>
    /// Guards the fields below, which the work's threads write and the game's reads.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The lines of each description fetched, by its slug.
    /// </summary>
    private readonly Dictionary<string, IReadOnlyList<string>> _known = new(StringComparer.Ordinal);

    /// <summary>
    /// The slugs whose descriptions are being fetched.
    /// </summary>
    private readonly HashSet<string> _fetching = new(StringComparer.Ordinal);

    /// <summary>
    /// The slugs whose fetch ended since the last <see cref="TakeEnded"/>, in order.
    /// </summary>
    private readonly List<string> _ended = [];

    /// <summary>
    /// Gets the descriptions of the game session, fetched from the website.
    /// </summary>
    public static ModDescriptions Live { get; } = new(SiteFeed.FetchDescription, work => Threads.TryStart("mods description", work));

    /// <summary>
    /// Tells a description, starting its fetch when it is neither known nor being fetched; a
    /// failed fetch starts again when asked again.
    /// </summary>
    /// <param name="slug">The mod's slug on the website.</param>
    /// <param name="fetch">Whether to start the fetch; false only reads what is known.</param>
    /// <returns>Its lines, <see langword="null"/> while it is not known, and whether it is being fetched.</returns>
    public (IReadOnlyList<string>? Lines, bool Fetching) Ask(string slug, bool fetch = true)
    {
        lock (_gate)
        {
            if (_known.TryGetValue(slug, out var lines))
            {
                return (lines, false);
            }

            if (!fetch || !_fetching.Add(slug))
            {
                return (null, _fetching.Contains(slug));
            }
        }

        var started = false;

        try
        {
            started = start(() => Fetch(slug));
        }
        finally
        {
            if (!started)
            {
                lock (_gate)
                {
                    _fetching.Remove(slug);
                }
            }
        }

        lock (_gate)
        {
            return _known.TryGetValue(slug, out var lines) ? (lines, false) : (null, _fetching.Contains(slug));
        }
    }

    /// <summary>
    /// Hands out the slugs whose fetch ended since the last call, well or not.
    /// </summary>
    /// <returns>The slugs, in order.</returns>
    public IReadOnlyList<string> TakeEnded()
    {
        lock (_gate)
        {
            var ended = _ended.ToArray();
            _ended.Clear();
            return ended;
        }
    }

    /// <summary>
    /// Fetches a description and keeps its lines, or logs why it failed.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    private void Fetch(string slug)
    {
        IReadOnlyList<string>? lines = null;

        try
        {
            lines = MarkdownText.Lines(fetch(slug), MaxLines, MaxLineLength);
            Log.Write($"the description of {slug} has {lines.Count} lines");
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so whatever went wrong only leaves the description out.
            Log.Write($"could not fetch the description of {slug}: {ex.Message}");
        }

        lock (_gate)
        {
            _fetching.Remove(slug);
            _ended.Add(slug);
            if (lines != null)
            {
                _known[slug] = lines;
            }
        }
    }
}
