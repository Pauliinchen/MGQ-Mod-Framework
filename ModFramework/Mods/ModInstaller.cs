//----------------------------------------------------------------
//  ModInstaller.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Wrote every file of a mod's package into Patch but the loader and the framework's files, and
//                              removed the files of older versions after any update, a single script's too
//      Paulinchen  2026-11-08: Logged a file of the zip left out as none of the mod's own files
//      Paulinchen  2026-11-07: Wrote the mods that run into the waiting folder instead of over their files
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Read a zip from the archive flag alone
//      Paulinchen  2026-11-06: Named the website in the messages of a file that differs
//                            - Removed the copy of the framework's replaced files kept until its new version boots
//      Paulinchen  2026-10-30: Kept the replaced files of the framework until its new version boots
//                            - Moved into the Mod Framework
//                            - Wrote a mod only into its own script and folder in Patch, spelled as Patch spells them
//      Paulinchen  2026-10-24: Matched files against the hash of their raw bytes too
//                            - Renamed a loaded DLL that cannot be overwritten out of the way
//                            - Shared how a path is read inside Patch with the mod browser
//                            - Left the files of other installed mods when removing an older version's files
//      Paulinchen  2026-10-23: Kept a file inside the Patch folder through FolderGuard
//      Paulinchen  2026-10-07: Logged hash checks, files written or put back, and zip files the catalog does not name
//      Paulinchen  2026-10-06: Put every replaced file back when one cannot be written
//                            - Deleted files that an older version of a zip mod shipped
//                            - Refused a zip that holds a file twice
//                            - Read a zip whose files sit in a Patch folder
//                            - Installed a link to a zip of a release like an upload, and read zips written with backslashes
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Installs mods into the game's Patch folder, each file to its path inside Patch.
/// </summary>
/// <remarks>
/// Every file is staged and checked against the catalog's hash before any moves into place, so a
/// download that differs changes nothing.
/// </remarks>
internal static class ModInstaller
{
    /// <summary>
    /// What a DLL renamed out of the way ends with, which the next game session deletes.
    /// </summary>
    public const string OldDllSuffix = ".old";

    /// <summary>
    /// The folder a zip for players holds its files in, read as the Patch folder itself.
    /// </summary>
    private const string ZipPatch = "Patch/";

    /// <summary>
    /// Installs mods: the files of those that run wait for the next start, see
    /// <see cref="WaitingUpdate"/>, the others go into place at once.
    /// </summary>
    /// <param name="mods">Each mod and its name in Patch, see <see cref="PatchFolder.NameOf"/>; its files go to their paths inside Patch.</param>
    /// <param name="download">Fetches a mod: a script, or a zip of a release or an upload.</param>
    /// <param name="gameFolder">The game's folder, which holds Patch.</param>
    /// <param name="waiting">The names in Patch of the mods whose files wait; <see langword="null"/> for none.</param>
    /// <returns>The files written or waiting, relative to the game's folder.</returns>
    /// <exception cref="InvalidDataException">A file differs from the catalog, is missing, or is a path no mod may write, see <see cref="PatchFolder.RefusalOf"/>.</exception>
    public static IReadOnlyList<string> Install(IReadOnlyList<(CatalogMod Mod, string Name)> mods, Func<CatalogMod, byte[]> download, string gameFolder, IReadOnlyCollection<string>? waiting = null)
    {
        var game = Path.GetFullPath(gameFolder);
        var patch = PatchFolder.PathOf(game);
        var staged = new List<(string Staged, string Target)>();
        var waits = new List<(string Name, string Version, IReadOnlyList<(byte[] Bytes, string Target)> Files, IReadOnlyList<string> Removals)>();
        var stage = Directory.CreateTempSubdirectory("mgqmf-mods-").FullName;

        try
        {
            foreach (var (mod, name) in mods)
            {
                var files = mod.Archive ? FilesOfZip(mod, download(mod), patch) : [FileOfLink(mod, download(mod), patch)];

                if (waiting != null && waiting.Contains(name, StringComparer.OrdinalIgnoreCase))
                {
                    var targets = new HashSet<string>(files.Select(file => file.Path), StringComparer.OrdinalIgnoreCase);
                    waits.Add((mod.Name, mod.Version, files, OldFiles(mod, patch, targets).Select(old => old.Path).ToList()));
                    continue;
                }

                foreach (var (bytes, path) in files)
                {
                    var file = Path.Combine(stage, staged.Count.ToString(CultureInfo.InvariantCulture));
                    File.WriteAllBytes(file, bytes);
                    staged.Add((file, path));
                }
            }

            var lines = waits.Count > 0 ? WaitingUpdate.Stage(game, waits) : [];
            MoveIntoPlace(staged, stage, game, () => WaitingUpdate.Commit(game, lines));
            var written = new HashSet<string>(staged.Select(file => file.Target), StringComparer.OrdinalIgnoreCase);

            foreach (var (mod, _) in mods.Where(mod => !(waiting != null && waiting.Contains(mod.Name, StringComparer.OrdinalIgnoreCase))))
            {
                RemoveOldFiles(mod, game, OldFiles(mod, patch, written));
            }

            return staged.Select(file => file.Target).Concat(waits.SelectMany(wait => wait.Files.Select(file => file.Target))).Select(path => Path.GetRelativePath(game, path)).ToList();
        }
        finally
        {
            try
            {
                Directory.Delete(stage, recursive: true);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // A staging folder left behind costs only disk space in the temporary folder.
            }
        }
    }

    /// <summary>
    /// Reads a path a zip or a list names as the path inside Patch it goes to.
    /// </summary>
    /// <param name="name">The path as the zip or the list names it.</param>
    /// <returns>The path with forward slashes, without a leading Patch folder.</returns>
    internal static string PathInsidePatch(string name)
    {
        var path = name.Replace('\\', '/');
        return path.StartsWith(ZipPatch, StringComparison.OrdinalIgnoreCase) ? path[ZipPatch.Length..] : path;
    }


    /// <summary>
    /// Copies the checked files into place, keeping a copy of each file it replaces first, then lists
    /// the files that wait.
    /// </summary>
    /// <param name="staged">Each checked file in the staging folder and its full target path.</param>
    /// <param name="stage">The staging folder, which also keeps the replaced files.</param>
    /// <param name="game">The game folder's full path, which the log names the files from.</param>
    /// <param name="commit">Lists the files that wait, last, so a failure leaves the whole install undone.</param>
    /// <exception cref="IOException">A file could not be written; every file written before it is put back.</exception>
    /// <exception cref="UnauthorizedAccessException">A file may not be written; every file written before it is put back.</exception>
    private static void MoveIntoPlace(IReadOnlyList<(string Staged, string Target)> staged, string stage, string game, Action commit)
    {
        var done = new List<(string Target, string? Backup)>();

        try
        {
            foreach (var (file, target) in staged)
            {
                string? backup = null;

                if (File.Exists(target))
                {
                    backup = Path.Combine(stage, $"backup-{done.Count.ToString(CultureInfo.InvariantCulture)}");
                    File.Copy(target, backup, overwrite: true);
                }

                done.Add((target, backup));
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                CopyOver(file, target, game);
                Log.Write($"wrote {Path.GetRelativePath(game, target)}{(backup != null ? ", replacing the file there" : ", a new file")}");
            }

            commit();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            PutBack(done, game);
            throw;
        }
    }

    /// <summary>
    /// Copies a file over its target, renaming a DLL the game has loaded out of the way first.
    /// </summary>
    /// <remarks>
    /// Windows refuses to overwrite a loaded DLL but lets it be renamed.
    /// </remarks>
    /// <param name="file">The checked file in the staging folder.</param>
    /// <param name="target">Its full target path.</param>
    /// <param name="game">The game folder's full path, which the log names the files from.</param>
    /// <exception cref="IOException">The file could not be written.</exception>
    private static void CopyOver(string file, string target, string game)
    {
        try
        {
            File.Copy(file, target, overwrite: true);
        }
        catch (IOException ex) when (target.EndsWith(".dll", StringComparison.OrdinalIgnoreCase) && File.Exists(target))
        {
            var old = target + OldDllSuffix;
            Log.Write($"could not overwrite {Path.GetRelativePath(game, target)}, which is likely loaded, so it is renamed to {Path.GetFileName(old)}: {ex.Message}");
            File.Move(target, old, overwrite: true);
            File.Copy(file, target, overwrite: true);
        }
    }

    /// <summary>
    /// Puts back the files an install wrote before one failed, the last written first.
    /// </summary>
    /// <param name="done">Each file written and the copy of the file it replaced, <see langword="null"/> for a new one.</param>
    /// <param name="game">The game folder's full path, which the log names the files from.</param>
    private static void PutBack(List<(string Target, string? Backup)> done, string game)
    {
        for (var index = done.Count - 1; index >= 0; index--)
        {
            var (target, backup) = done[index];

            try
            {
                if (backup != null)
                {
                    File.Copy(backup, target, overwrite: true);
                    Log.Write($"put the earlier {Path.GetRelativePath(game, target)} back");
                }
                else if (File.Exists(target))
                {
                    File.Delete(target);
                    Log.Write($"deleted the new {Path.GetRelativePath(game, target)} again");
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"could not put {Path.GetRelativePath(game, target)} back: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Finds the files an older version of a mod shipped that the version installed no longer
    /// has, each only while it is exactly that version's file.
    /// </summary>
    /// <remarks>
    /// The game's loader runs every script in a mod's folder, and every script at the top of Patch, so a script a newer
    /// version dropped or renamed would still run.
    /// </remarks>
    /// <param name="mod">The mod installed.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="written">The full paths the install writes, which stay whatever an older version named them.</param>
    /// <returns>Each file's full path and the version that shipped it.</returns>
    private static List<(string Path, string Version)> OldFiles(CatalogMod mod, string patch, IReadOnlySet<string> written)
    {
        var old = new List<(string Path, string Version)>();

        foreach (var version in mod.Versions)
        {
            foreach (var (name, hash) in version.Files)
            {
                if (mod.Files.ContainsKey(name) || PatchFolder.RefusalOf(name, IsFramework(mod)) != null || FolderGuard.Inside(patch, PatchFolder.Resolve(patch, name)) is not { } path
                    || written.Contains(path) || old.Exists(file => string.Equals(file.Path, path, StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                try
                {
                    if (File.Exists(path) && ModHash.Matches(path, File.ReadAllBytes(path), hash))
                    {
                        old.Add((path, version.Version));
                    }
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    Log.Write($"could not read {path} of an older {mod.Name}: {ex.Message}");
                }
            }
        }

        return old;
    }

    /// <summary>
    /// Deletes the files of older versions of a mod just installed.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="game">The game folder's full path, which the log names the files from.</param>
    /// <param name="old">The files, see <see cref="OldFiles"/>.</param>
    private static void RemoveOldFiles(CatalogMod mod, string game, IReadOnlyList<(string Path, string Version)> old)
    {
        foreach (var (path, version) in old)
        {
            try
            {
                File.Delete(path);
                Log.Write($"removed {Path.GetRelativePath(game, path)}, which {mod.Name} {version} shipped and {mod.Version} no longer does");
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"could not remove {Path.GetRelativePath(game, path)} of an older {mod.Name}: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Checks a link mod's script.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="bytes">The script as downloaded.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <returns>The script and its full target path.</returns>
    private static (byte[] Bytes, string Path) FileOfLink(CatalogMod mod, byte[] bytes, string patch)
    {
        var (name, hash) = mod.Files.Count == 1 ? mod.Files.First() : throw new InvalidDataException($"{mod.Name} names no single script.");
        var path = Inside(patch, PathInsidePatch(name), mod);

        if (!path.EndsWith(".rb", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException($"{mod.Name} would not be installed as a script.");
        }

        return Checked(mod, name, bytes, hash) ? (bytes, path) : throw new InvalidDataException($"{mod.Name} differs from the version the website checked. It may just have been updated: try again in a minute.");
    }

    /// <summary>
    /// Checks the files of a mod that comes as a zip, each of which the zip must hold with the catalog's hash.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="zip">The zip as downloaded.</param>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <returns>Each file and its full target path.</returns>
    private static List<(byte[] Bytes, string Path)> FilesOfZip(CatalogMod mod, byte[] zip, string patch)
    {
        using var archive = new ZipArchive(new MemoryStream(zip), ZipArchiveMode.Read);
        var entries = new Dictionary<string, ZipArchiveEntry>(StringComparer.Ordinal);

        // Some zip tools of Windows write backslashes, and a zip for players holds a Patch folder to
        // extract into the game folder; the website reads both the same way.
        foreach (var entry in archive.Entries)
        {
            var path = PathInsidePatch(entry.FullName);

            if (!entries.TryAdd(path, entry) && path.Length > 0 && !path.EndsWith('/'))
            {
                throw new InvalidDataException($"{mod.Name} holds {path} twice.");
            }
        }

        var files = new List<(byte[] Bytes, string Path)>();

        foreach (var (name, hash) in mod.Files)
        {
            var entry = entries.GetValueOrDefault(name) ?? throw new InvalidDataException($"{mod.Name} lacks {name}.");
            using var stream = entry.Open();
            using var copy = new MemoryStream();
            stream.CopyTo(copy);
            var bytes = copy.ToArray();

            if (!Checked(mod, name, bytes, hash))
            {
                throw new InvalidDataException($"{name} of {mod.Name} differs from the version the website keeps.");
            }

            files.Add((bytes, Inside(patch, name, mod)));
        }

        foreach (var path in entries.Keys.Where(path => path.Length > 0 && !path.EndsWith('/') && !mod.Files.ContainsKey(path)))
        {
            Log.Write($"left out {path} of {mod.Name}, which is none of the files the catalog names for Patch");
        }

        return files;
    }

    /// <summary>
    /// Checks a downloaded file against the catalog's hash, and logs the outcome.
    /// </summary>
    /// <param name="mod">The mod it belongs to.</param>
    /// <param name="name">The file's name or path, as the catalog names it.</param>
    /// <param name="bytes">The file as downloaded.</param>
    /// <param name="hash">The catalog's hash.</param>
    /// <returns>Whether the hashes match.</returns>
    private static bool Checked(CatalogMod mod, string name, byte[] bytes, string hash)
    {
        var actual = ModHash.Of(name, bytes);
        var matches = ModHash.Matches(name, bytes, hash);
        Log.Write(matches
            ? $"{name} of {mod.Name} {mod.Version} matches the catalog, {bytes.Length} bytes"
            : $"{name} of {mod.Name} {mod.Version} differs from the catalog: hash {Log.Short(actual)}, the catalog says {Log.Short(hash)}");
        return matches;
    }

    /// <summary>
    /// Makes sure a mod may write a path inside Patch: one that stays inside Patch and is neither
    /// the game's loader nor, but for the framework itself, the framework's.
    /// </summary>
    /// <param name="patch">The full path of the Patch folder.</param>
    /// <param name="path">The path inside Patch.</param>
    /// <param name="mod">The mod it belongs to.</param>
    /// <returns>The full path, spelled as Patch spells it.</returns>
    private static string Inside(string patch, string path, CatalogMod mod) =>
        (PatchFolder.RefusalOf(path, IsFramework(mod)) == null ? FolderGuard.Inside(patch, PatchFolder.Resolve(patch, path)) : null)
        ?? throw new InvalidDataException($"{mod.Name} would write {path}, which no mod may write in the Patch folder.");

    /// <summary>
    /// Tells whether a mod is the framework itself, the only one that may write the framework's files.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>Whether its id names the website's <see cref="PatchFolder.FrameworkSlug"/>.</returns>
    internal static bool IsFramework(CatalogMod mod) => mod.Key == $"site:{PatchFolder.FrameworkSlug}";
}
