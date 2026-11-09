//----------------------------------------------------------------
//  ModInstall.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Refused an install whose thread could not start, so another may start
//      Paulinchen  2026-11-08: Refused to install or update a mod the player installs by hand
//      Paulinchen  2026-11-07: Had the framework and the mods that run wait for the next start
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Dropped the source of a mod from the log, which is always the website
//      Paulinchen  2026-10-31: Refused an install while another runs in plain words
//      Paulinchen  2026-10-30: Downloaded each mod as every update downloads it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Installs mods of the website into the Patch folder, one install at a time,
/// downloading each in turn and writing them together, so the game goes on while it runs.
/// </summary>
/// <param name="download">Downloads a mod: a script, or a zip of a release or an upload.</param>
/// <param name="start">Runs the install's work, on a thread of its own in the game, and tells whether it started.</param>
internal sealed class ModInstall(Func<BrowsedMod, byte[]> download, Func<Action, bool> start)
{
    /// <summary>
    /// Guards the progress, which the install's thread writes and the game's reads.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The progress of the install last started.
    /// </summary>
    private InstallProgress _progress = InstallProgress.None;

    /// <summary>
    /// Gets the install of the game session, downloading from where each mod is installed from.
    /// </summary>
    public static ModInstall Live { get; } = new(ModUpdates.Download, work => Threads.TryStart("mods install", work));

    /// <summary>
    /// Gets the progress of the install last started.
    /// </summary>
    public InstallProgress Progress
    {
        get
        {
            lock (_gate)
            {
                return _progress;
            }
        }
    }

    /// <summary>
    /// Starts installing mods, unless an install runs or one of them is installed by hand.
    /// </summary>
    /// <param name="mods">The mods, each into its own script and folder in Patch.</param>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="running">The names in Patch of the mods that run in the game; these and the framework wait for the next start.</param>
    /// <returns>Why it did not start, for the player; <see langword="null"/> once it started.</returns>
    public string? Start(IReadOnlyList<BrowsedMod> mods, string gameFolder, IReadOnlyCollection<string> running)
    {
        InstallProgress before;

        lock (_gate)
        {
            if (_progress.Running)
            {
                return "Another install is running.";
            }

            if (mods.Count == 0)
            {
                return "No mod was named.";
            }

            if (mods.FirstOrDefault(mod => mod.ByHand) is { } byHand)
            {
                return ByHandText(byHand.Name);
            }

            before = _progress;
            _progress = new InstallProgress(_progress.Round + 1, true, 0, mods.Count, mods[0].Name, [], null);
        }

        var started = false;

        try
        {
            var waiting = mods.Where(mod => ModUpdates.IsFramework(mod) || running.Contains(mod.Folder, StringComparer.OrdinalIgnoreCase)).Select(mod => mod.Folder).ToList();
            Log.Write($"installing {string.Join(", ", mods.Select(mod => $"{mod.Id} {mod.Latest} as Patch/{mod.Folder}"))}{(waiting.Count > 0 ? $"; {string.Join(", ", waiting)} wait for the next start" : string.Empty)}");
            started = start(() => Run(mods, gameFolder, waiting));
        }
        finally
        {
            if (!started)
            {
                lock (_gate)
                {
                    _progress = before;
                }
            }
        }

        return started ? null : "The install could not start.";
    }

    /// <summary>
    /// Tells the player that a mod is installed by hand.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>The sentence.</returns>
    internal static string ByHandText(string name) => $"{name} is installed by hand from its page on the website.";

    /// <summary>
    /// Tells the player why an install failed.
    /// </summary>
    /// <param name="ex">What went wrong.</param>
    /// <returns>The reason.</returns>
    internal static string ReasonFor(Exception ex) => ex switch
    {
        InvalidDataException or InvalidOperationException or SiteFeedException => ex.Message,
        IOException or UnauthorizedAccessException => $"The files could not be written: {ex.Message}",
        _ => $"Something went wrong: {ex.GetBaseException().Message}",
    };

    /// <summary>
    /// Downloads the mods one after another, then writes them together.
    /// </summary>
    /// <param name="mods">The mods.</param>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="waiting">The names in Patch of the mods whose files wait for the next start.</param>
    private void Run(IReadOnlyList<BrowsedMod> mods, string gameFolder, IReadOnlyCollection<string> waiting)
    {
        var current = mods[0];

        try
        {
            var files = new Dictionary<CatalogMod, byte[]>(ReferenceEqualityComparer.Instance);

            for (var index = 0; index < mods.Count; index++)
            {
                current = mods[index];
                Report(index, current.Name);
                files[current.Install] = download(current);
                Log.Write($"downloaded {current.Id} {current.Latest}: {files[current.Install].Length} bytes");
            }

            Report(mods.Count, null);
            var written = ModInstaller.Install(mods.Select(mod => (mod.Install, mod.Folder)).ToList(), install => files[install], gameFolder, waiting);
            Log.Write($"installed {string.Join(", ", mods.Select(mod => $"{mod.Name} {mod.Latest}"))}: {written.Count} files");
            Finish(mods.Select(mod => mod.Folder).ToList(), null, null);
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so whatever went wrong only fails the install.
            var reason = ReasonFor(ex);
            Log.Write($"the install of {current.Name} failed: {ex.GetBaseException().Message}; the player reads: {reason}");
            Finish([], current.Name, reason);
        }
    }

    /// <summary>
    /// Notes how far the downloads came.
    /// </summary>
    /// <param name="done">How many mods were downloaded.</param>
    /// <param name="mod">The mod downloading now; <see langword="null"/> while the files are written.</param>
    private void Report(int done, string? mod)
    {
        lock (_gate)
        {
            _progress = _progress with { Done = done, Mod = mod };
        }
    }

    /// <summary>
    /// Notes the end of the install.
    /// </summary>
    /// <param name="installed">The names of the mods installed.</param>
    /// <param name="failed">The mod that failed; <see langword="null"/> for none.</param>
    /// <param name="error">Why, for the player; <see langword="null"/> for none.</param>
    private void Finish(IReadOnlyList<string> installed, string? failed, string? error)
    {
        lock (_gate)
        {
            _progress = _progress with { Running = false, Done = error == null ? _progress.Total : _progress.Done, Mod = failed, Installed = installed, Error = error };
        }
    }
}

/// <summary>
/// How far an install came.
/// </summary>
/// <param name="Round">Counts the installs started, so a reader tells one from the next.</param>
/// <param name="Running">Whether it runs.</param>
/// <param name="Done">How many mods were downloaded.</param>
/// <param name="Total">How many mods it installs.</param>
/// <param name="Mod">The mod downloading now, or the one that failed; <see langword="null"/> for none.</param>
/// <param name="Installed">The names of the mods installed, once it ended well.</param>
/// <param name="Error">Why it failed, for the player; <see langword="null"/> for none.</param>
internal sealed record InstallProgress(int Round, bool Running, int Done, int Total, string? Mod, IReadOnlyList<string> Installed, string? Error)
{
    /// <summary>
    /// Gets the progress before any install.
    /// </summary>
    public static InstallProgress None { get; } = new(0, false, 0, 0, null, [], null);
}
