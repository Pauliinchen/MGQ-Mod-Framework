//----------------------------------------------------------------
//  ModScan.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Left another mod's script that an older package carried out of the signs that a mod is installed
//                            - Read a whole copy beside files only other versions list as an update in part
//                            - Read a copy that misses files of a version or holds files of older ones as an update in part
//                            - Removed every file any known version lists while it is still that version's
//                            - Kept the hashes of each file read until its length or write time changes
//                            - Removed every file of a mod's package but the loader and the framework's files
//      Paulinchen  2026-11-09: Caught every error of the search for old DLLs
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-30: Moved into the Mod Framework as ModScan, from PatchScan
//                            - Found the files of a mod whatever the case of their names
//                            - Removed only the files of a mod's own script and folder
//                            - Left the log out for the plan, which asks often
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Reads which version of each mod of the mod browser the game's Patch folder holds, and removes an
/// installed mod's files.
/// </summary>
internal static class ModScan
{
    /// <summary>
    /// The hashes of each file read, by its full path, kept until its length or write time changes.
    /// </summary>
    /// <remarks>
    /// A file rewritten with the same length within the write time's resolution, two seconds on FAT and exFAT, keeps its
    /// old hashes; every write by an install or a removal goes through the bytes instead.
    /// </remarks>
    private static readonly ConcurrentDictionary<string, KeptHashes> Memo = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Tells how each mod stands in the Patch folder.
    /// </summary>
    /// <param name="mods">The mods.</param>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="logged">Whether each mod's state is logged, as the mod browser does.</param>
    /// <returns>Each mod's state by its id.</returns>
    public static IReadOnlyDictionary<string, ModState> Detect(IReadOnlyList<BrowsedMod> mods, string gameFolder, bool logged = true)
    {
        var patch = PatchFolder.PathOf(gameFolder);
        var read = new Dictionary<string, (bool Exists, FileHashes? Hashes)>(StringComparer.OrdinalIgnoreCase);
        var states = new Dictionary<string, ModState>(StringComparer.Ordinal);

        (bool Exists, FileHashes? Hashes) FileAt(string path)
        {
            if (!read.TryGetValue(path, out var file))
            {
                read[path] = file = HashesOf(patch, path);
            }

            return file;
        }

        foreach (var mod in mods)
        {
            var state = StateOf(mod, path => FileAt(path).Exists, (path, hash) => FileAt(path).Hashes is { } hashes && ModHash.Matches(hashes, hash));
            states[mod.Id] = state;

            if (logged)
            {
                Log.Write($"mod browser: {mod.Id} is {state.Status}{(state.Installed is { } installed ? $", {installed.Version} installed{(state.Repair ? " in part" : string.Empty)}" : string.Empty)}, latest {mod.Latest}");
            }
        }

        return states;
    }

    /// <summary>
    /// Tells how a mod stands by the files of its known versions: the newest version whose files
    /// are all there as listed is installed, in part while an own file another version lists at a
    /// path it does not is there as listed; else an own file that matches no version listing it
    /// makes a changed copy; else an own script makes an update in part, of the version with the
    /// most files there; else any own file makes a changed copy. Own files are those of
    /// <see cref="OwnFilesOf"/>.
    /// </summary>
    /// <remarks>
    /// An update in part is rewritten whole by an update, while its version counts as unknown for
    /// worlds and needs, since the game would not load what its files miss and would also run the
    /// files another version left.
    /// </remarks>
    /// <param name="mod">The mod.</param>
    /// <param name="exists">Tells whether a path inside Patch holds a file.</param>
    /// <param name="matches">Tells whether the file at a path inside Patch is the one a hash names.</param>
    /// <returns>Its state.</returns>
    public static ModState StateOf(BrowsedMod mod, Func<string, bool> exists, Func<string, string, bool> matches)
    {
        if (mod.Known.FirstOrDefault(version => version.Files.Count > 0 && version.Files.All(file => matches(file.Key, file.Value))) is { } whole)
        {
            var own = new HashSet<string>(whole.Files.Keys, StringComparer.OrdinalIgnoreCase);

            if (OwnFilesOf(mod).Any(file => !own.Contains(file.Key) && matches(file.Key, file.Value)))
            {
                return new ModState(ModStatus.Update, whole, Repair: true);
            }

            return new ModState(ModMerge.CompareVersions(mod.Latest, whole.Version) > 0 ? ModStatus.Update : ModStatus.Current, whole);
        }

        var present = OwnFilesOf(mod).GroupBy(file => file.Key, StringComparer.OrdinalIgnoreCase).Where(path => exists(path.Key)).ToList();

        if (present.Any(path => !path.Any(file => matches(file.Key, file.Value))))
        {
            return new ModState(ModStatus.Changed, null);
        }

        if (present.Any(path => path.Key.EndsWith(PatchFolder.Script, StringComparison.OrdinalIgnoreCase)))
        {
            var most = mod.Known
                .OrderByDescending(version => version.Files.Count(file => matches(file.Key, file.Value)))
                .ThenByDescending(version => version.Version, Comparer<string>.Create(ModMerge.CompareVersions))
                .First();
            return new ModState(ModStatus.Update, most, Repair: true);
        }

        return new ModState(present.Count > 0 ? ModStatus.Changed : ModStatus.Available, null);
    }

    /// <summary>
    /// Lists the files of each known version of a mod but the scripts that give the loader a mod
    /// other than that version's own.
    /// </summary>
    /// <remarks>
    /// An older package may carry another mod's script, which alone never shows that this mod is there.
    /// </remarks>
    /// <param name="mod">The mod.</param>
    /// <returns>Each such file's path inside Patch and hash, once per version listing it.</returns>
    private static IEnumerable<KeyValuePair<string, string>> OwnFilesOf(BrowsedMod mod) =>
        mod.Known.SelectMany(version => version.Files.Where(file => PatchFolder.RowsOf([file.Key]).All(row => string.Equals(row, version.Name, StringComparison.OrdinalIgnoreCase))));

    /// <summary>
    /// Deletes the DLLs an install renamed out of the way in Patch, as far as the game no longer has them loaded.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    public static void DeleteOldDlls(string gameFolder)
    {
        try
        {
            var patch = PatchFolder.PathOf(gameFolder);

            if (!Directory.Exists(patch))
            {
                return;
            }

            var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true };

            foreach (var file in Directory.EnumerateFiles(patch, "*.dll" + ModInstaller.OldDllSuffix, options).Where(file => file.EndsWith(".dll" + ModInstaller.OldDllSuffix, StringComparison.OrdinalIgnoreCase)))
            {
                try
                {
                    File.Delete(file);
                    Log.Write($"deleted {Path.GetRelativePath(patch, file)} in Patch, a DLL an install renamed out of the way");
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    // The game still has it loaded until it restarts.
                }
            }
        }
        catch (Exception ex)
        {
            Log.Write($"could not look for old DLLs in Patch: {ex.GetType().Name}: {ex.Message}");
        }
    }

    /// <summary>
    /// Removes an installed mod: every file any of its known versions lists that is still exactly a
    /// known version's file at its path, then the folders inside Patch that leaves empty.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="state">How it stands, see <see cref="Detect"/>; nothing is removed when no version is installed.</param>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The paths inside Patch removed, and those that could not be removed.</returns>
    public static (IReadOnlyList<string> Removed, IReadOnlyList<string> Failed) Remove(BrowsedMod mod, ModState state, string gameFolder)
    {
        var removed = new List<string>();
        var failed = new List<string>();

        if (state.Installed == null)
        {
            return (removed, failed);
        }

        var patch = PatchFolder.PathOf(gameFolder);
        var folders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var listed in mod.Known.SelectMany(version => version.Files).GroupBy(file => file.Key, StringComparer.OrdinalIgnoreCase))
        {
            var path = listed.Key;

            if (PatchFolder.RefusalOf(path, ModInstaller.IsFramework(mod.Install)) is { } why)
            {
                Log.Write($"kept {path} in Patch, which {why}");
                continue;
            }

            try
            {
                if (FolderGuard.Inside(patch, PatchFolder.Resolve(patch, path)) is not { } full || !File.Exists(full))
                {
                    continue;
                }

                var hashes = ModHash.Hashes(path, File.ReadAllBytes(full));

                if (!listed.Any(file => ModHash.Matches(hashes, file.Value)))
                {
                    Log.Write($"kept {path} in Patch, which differs from every version of {mod.Name} the website lists");
                    continue;
                }

                Delete(full, patch);
                removed.Add(path);
                folders.Add(Path.GetDirectoryName(full)!);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"could not remove {path} of {mod.Name} in Patch: {ex.Message}");
                failed.Add(path);
            }
        }

        foreach (var folder in folders.OrderByDescending(folder => folder.Length))
        {
            DeleteEmptyFolders(folder, patch);
        }

        return (removed, failed);
    }

    /// <summary>
    /// Deletes a mod's file, renaming a DLL the game has loaded out of the way instead.
    /// </summary>
    /// <param name="full">The file's full path.</param>
    /// <param name="patch">The full path of the Patch folder, which the log names the file from.</param>
    /// <exception cref="IOException">The file could not be deleted or renamed.</exception>
    /// <exception cref="UnauthorizedAccessException">The file may not be deleted or renamed.</exception>
    private static void Delete(string full, string patch)
    {
        try
        {
            File.Delete(full);
            Log.Write($"removed {Path.GetRelativePath(patch, full)} in Patch");
        }
        catch (Exception ex) when ((ex is IOException or UnauthorizedAccessException) && full.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
        {
            File.Move(full, full + ModInstaller.OldDllSuffix, overwrite: true);
            Log.Write($"renamed {Path.GetRelativePath(patch, full)} in Patch out of the way, which is likely loaded: {ex.Message}");
        }
    }

    /// <summary>
    /// Deletes a folder and the folders above it while they are empty, up to the Patch folder, which stays.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    private static void DeleteEmptyFolders(string folder, string patch)
    {
        try
        {
            while (FolderGuard.Inside(patch, folder) != null && Directory.Exists(folder) && !Directory.EnumerateFileSystemEntries(folder).Any())
            {
                Directory.Delete(folder);
                Log.Write($"removed the empty folder {Path.GetRelativePath(patch, folder)} in Patch");
                folder = Path.GetDirectoryName(folder)!;
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not remove the folder {Path.GetRelativePath(patch, folder)} in Patch: {ex.Message}");
        }
    }

    /// <summary>
    /// Hashes a file inside the Patch folder, found whatever the case of its name, reading it again
    /// only when it is new or its length or write time changed.
    /// </summary>
    /// <param name="patch">The Patch folder's full path.</param>
    /// <param name="path">The path inside it.</param>
    /// <returns>Whether it exists, and its hashes; none for a file missing, outside Patch or that cannot be read.</returns>
    private static (bool Exists, FileHashes? Hashes) HashesOf(string patch, string path)
    {
        if (FolderGuard.Inside(patch, PatchFolder.Resolve(patch, path)) is not { } full)
        {
            return (false, null);
        }

        try
        {
            var info = new FileInfo(full);

            if (!info.Exists)
            {
                Memo.TryRemove(full, out _);
                return (false, null);
            }

            if (Memo.TryGetValue(full, out var kept) && kept.Length == info.Length && kept.Written == info.LastWriteTimeUtc)
            {
                return (true, kept.Hashes);
            }

            var hashes = ModHash.Hashes(path, File.ReadAllBytes(full));
            Memo[full] = new KeptHashes(info.Length, info.LastWriteTimeUtc, hashes);
            return (true, hashes);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not read {path} in Patch: {ex.Message}");
            return (true, null);
        }
    }

    /// <summary>
    /// The hashes of a file as it was when it was read.
    /// </summary>
    /// <param name="Length">Its length then.</param>
    /// <param name="Written">Its write time then, in UTC.</param>
    /// <param name="Hashes">Its hashes.</param>
    private sealed record KeptHashes(long Length, DateTime Written, FileHashes Hashes);
}
