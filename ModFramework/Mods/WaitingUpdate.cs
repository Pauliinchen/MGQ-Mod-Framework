//----------------------------------------------------------------
//  WaitingUpdate.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Dropped the update of a mod that waits
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// The waiting folder, <c>Patch/Mod_Framework/Waiting</c>: the updates of mods that run, the
/// framework's own included, which the stub moves into place at the next start of the game, before
/// the DLL loads.
/// </summary>
/// <remarks>
/// The files are named by number, never <c>.rb</c>, since the game's loader runs every script in
/// Patch, and the list is written last, so a write cut short leaves nothing the stub acts on.
/// </remarks>
internal static class WaitingUpdate
{
    /// <summary>
    /// The waiting folder's name inside the framework's folder.
    /// </summary>
    public const string FolderName = "Waiting";

    /// <summary>
    /// The list the stub follows, inside the waiting folder: a <c>mod</c> line (name, version)
    /// before the <c>file</c> lines (number, target) and <c>remove</c> lines (target) of that mod,
    /// tab-separated, each target relative to the game folder with forward slashes.
    /// </summary>
    public const string ListName = "Waiting.txt";

    /// <summary>
    /// What starts the line of a mod.
    /// </summary>
    private const string ModLine = "mod";

    /// <summary>
    /// What starts the line of a file that waits.
    /// </summary>
    private const string FileLine = "file";

    /// <summary>
    /// What starts the line of a file that goes.
    /// </summary>
    private const string RemoveLine = "remove";

    /// <summary>
    /// Names the waiting folder of a game folder.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The waiting folder's full path.</returns>
    public static string FolderOf(string gameFolder) => Path.Combine(PatchFolder.PathOf(gameFolder), PatchFolder.FrameworkFolder, FolderName);

    /// <summary>
    /// Writes the files of mods into the waiting folder, without listing them yet.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="mods">Each mod's name and version, its checked files with their full targets, and the full paths of its older files that go.</param>
    /// <returns>The lines that list them, for <see cref="Commit"/>.</returns>
    /// <exception cref="IOException">A file could not be written.</exception>
    /// <exception cref="UnauthorizedAccessException">A file may not be written.</exception>
    public static IReadOnlyList<string> Stage(string gameFolder, IReadOnlyList<(string Name, string Version, IReadOnlyList<(byte[] Bytes, string Target)> Files, IReadOnlyList<string> Removals)> mods)
    {
        var game = Path.GetFullPath(gameFolder);
        var folder = FolderOf(game);
        Directory.CreateDirectory(folder);
        var number = NextNumber(Path.Combine(folder, ListName));
        var lines = new List<string>();

        foreach (var (name, version, files, removals) in mods)
        {
            lines.Add(Line(ModLine, name, version));

            foreach (var (bytes, target) in files)
            {
                var staged = number.ToString(CultureInfo.InvariantCulture);
                File.WriteAllBytes(Path.Combine(folder, staged), bytes);
                lines.Add(Line(FileLine, staged, Relative(game, target)));
                number++;
            }

            lines.AddRange(removals.Select(path => Line(RemoveLine, Relative(game, path))));
            Log.Write($"{name} {version} waits for the next start: {files.Count} files, {removals.Count} to remove");
        }

        return lines;
    }

    /// <summary>
    /// Adds staged lines to the list in one replace, after the updates that wait already, so a later
    /// update of the same file wins.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="lines">The lines <see cref="Stage"/> made.</param>
    /// <exception cref="IOException">The list could not be written.</exception>
    /// <exception cref="UnauthorizedAccessException">The list may not be written.</exception>
    public static void Commit(string gameFolder, IReadOnlyList<string> lines)
    {
        if (lines.Count == 0)
        {
            return;
        }

        var list = Path.Combine(FolderOf(gameFolder), ListName);
        var text = new StringBuilder(File.Exists(list) ? File.ReadAllText(list, Encoding.UTF8) : string.Empty);

        foreach (var line in lines)
        {
            text.Append(line).Append('\n');
        }

        var written = list + ".tmp";
        File.WriteAllText(written, text.ToString(), new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        File.Move(written, list, overwrite: true);
    }

    /// <summary>
    /// Drops every update of a mod that waits: its lines leave the list in one replace, then its
    /// files leave the waiting folder, so the next start moves nothing of it into place.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="name">The mod's name as its <c>mod</c> line holds it.</param>
    /// <returns>Whether an update of the mod waited.</returns>
    /// <exception cref="IOException">The list could not be written.</exception>
    /// <exception cref="UnauthorizedAccessException">The list may not be written.</exception>
    public static bool Drop(string gameFolder, string name)
    {
        var folder = FolderOf(Path.GetFullPath(gameFolder));
        var list = Path.Combine(folder, ListName);

        if (!File.Exists(list))
        {
            return false;
        }

        var kept = new StringBuilder();
        var staged = new List<string>();
        var dropped = false;
        var dropping = false;

        foreach (var line in File.ReadAllLines(list, Encoding.UTF8))
        {
            var parts = line.Split('\t');

            if (parts.Length == 3 && parts[0] == ModLine)
            {
                dropping = parts[1] == name;
                dropped |= dropping;
            }

            if (!dropping)
            {
                kept.Append(line).Append('\n');
            }
            else if (parts.Length == 3 && parts[0] == FileLine)
            {
                staged.Add(parts[1]);
            }
        }

        if (!dropped)
        {
            return false;
        }

        var written = list + ".tmp";
        File.WriteAllText(written, kept.ToString(), new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        File.Move(written, list, overwrite: true);

        foreach (var file in staged)
        {
            File.Delete(Path.Combine(folder, Path.GetFileName(file)));
        }

        Log.Write($"dropped the update of {name} that waited for the next start: {staged.Count} files");
        return true;
    }

    /// <summary>
    /// Finds the number of the next file, past every file the list names.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The number.</returns>
    private static int NextNumber(string list)
    {
        if (!File.Exists(list))
        {
            return 0;
        }

        return File.ReadAllLines(list, Encoding.UTF8)
            .Select(line => line.Split('\t'))
            .Where(parts => parts.Length == 3 && parts[0] == FileLine && int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out _))
            .Select(parts => int.Parse(parts[1], CultureInfo.InvariantCulture) + 1)
            .DefaultIfEmpty(0)
            .Max();
    }

    /// <summary>
    /// Writes a path as the list holds it.
    /// </summary>
    /// <param name="game">The game folder's full path.</param>
    /// <param name="path">The full path.</param>
    /// <returns>The path relative to the game folder with forward slashes.</returns>
    private static string Relative(string game, string path) => Path.GetRelativePath(game, path).Replace('\\', '/');

    /// <summary>
    /// Joins the parts of a line of the list.
    /// </summary>
    /// <param name="parts">The parts, none holding a tab or a line end.</param>
    /// <returns>The line.</returns>
    private static string Line(params string[] parts) =>
        string.Join('\t', parts.Select(part => part.Replace('\t', ' ').Replace('\n', ' ').Replace('\r', ' ')));
}
