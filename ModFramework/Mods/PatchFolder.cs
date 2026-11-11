//----------------------------------------------------------------
//  PatchFolder.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Refused only paths that leave Patch and the loader and framework files for any mod but the
//                              framework, instead of keeping each mod to its own script and folder
//                            - Listed the loader rows a package gives
//      Paulinchen  2026-11-09: Left out a folder whose scripts lie only in a Patch folder inside it
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Refused a path that leaves Patch as a mod's own
//      Paulinchen  2026-11-06: Counted the framework's old name, which no release had, as a mod's name again
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
/// The game folder's Patch folder, which holds every mod: a script at its top with the folder of
/// the same name, or such a folder alone; the names those mods take and the paths no mod may write.
/// </summary>
/// <remarks>
/// Under Linux the folder is case-sensitive while the game finds its files whatever their case, so
/// a path inside it is spelled as the folder spells it already.
/// </remarks>
internal static class PatchFolder
{
    /// <summary>
    /// The Patch folder's name in the game folder.
    /// </summary>
    public const string Name = "Patch";

    /// <summary>
    /// The extension of the scripts the game's loader evaluates.
    /// </summary>
    public const string Script = ".rb";

    /// <summary>
    /// The framework's entry file at the top of Patch, whose name sorts before every mod's script.
    /// </summary>
    public const string FrameworkEntry = "!Mod_Framework.rb";

    /// <summary>
    /// The framework's folder in Patch, which holds its files, Mods.ini and the cache.
    /// </summary>
    public const string FrameworkFolder = "Mod_Framework";

    /// <summary>
    /// The framework's slug on the website, the only mod that may ship its files.
    /// </summary>
    public const string FrameworkSlug = "mod-framework";

    /// <summary>
    /// The game's loader at the top of Patch, which no mod may replace.
    /// </summary>
    private const string Loader = "Patch.rb";

    /// <summary>
    /// The longest name a mod takes.
    /// </summary>
    private const int MaxNameLength = 80;

    /// <summary>
    /// The names at the top of Patch that are no mod: the game's loader and the framework's entry
    /// file and folder.
    /// </summary>
    private static readonly string[] NotMods = ["Patch", "!Mod_Framework", FrameworkFolder];

    /// <summary>
    /// The names Windows keeps for devices, which no file or folder may take.
    /// </summary>
    private static readonly string[] DeviceNames = ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"];

    /// <summary>
    /// Builds the Patch folder's full path, as the game folder spells it.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>The full path.</returns>
    public static string PathOf(string gameFolder) => Resolve(Path.GetFullPath(gameFolder), Name);

    /// <summary>
    /// Builds the full path of a path inside a folder, each part spelled as the folder spells it
    /// already, ignoring case; a part not there yet keeps its own spelling.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <param name="relative">The path inside it, with either slash.</param>
    /// <returns>The full path.</returns>
    public static string Resolve(string folder, string relative)
    {
        var path = folder;

        foreach (var part in relative.Split('/', '\\').Where(part => part.Length > 0))
        {
            path = Path.Combine(path, SpelledIn(path, part));
        }

        return path;
    }

    /// <summary>
    /// Tells whether a name is one a mod takes: one file's or folder's name that Windows keeps as it
    /// is, Mods.ini can hold and no part of the framework or the game's loader takes.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Whether it is no longer than 80 characters, holds no separator, "=" or character a file name may not hold, is no device name, neither ends in a dot or a space nor starts with a space, and is none of the names that are no mod.</returns>
    public static bool IsName(string name) =>
        name.Length is > 0 and <= MaxNameLength
        && name.IndexOfAny(Path.GetInvalidFileNameChars()) < 0
        && name.IndexOfAny(['/', '\\', '=']) < 0
        && name.Trim('.').Length > 0
        && !name.EndsWith('.') && !name.EndsWith(' ') && !name.StartsWith(' ')
        && !DeviceNames.Contains(name.Split('.')[0], StringComparer.OrdinalIgnoreCase)
        && !NotMods.Contains(name, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Names a mod after its files: after its script at the top that has a folder of its name, else
    /// its only script at the top, else its first folder there, else its key. The framework's files
    /// name it after its folder, <see cref="FrameworkFolder"/>.
    /// </summary>
    /// <param name="key">The mod's slug on the website.</param>
    /// <param name="files">Its files by their paths inside Patch.</param>
    /// <returns>The name, like <c>Level_Cap</c> for <c>Level_Cap.rb</c>.</returns>
    public static string NameOf(string key, IReadOnlyDictionary<string, string> files)
    {
        var paths = files.Keys.Select(path => path.Replace('\\', '/')).Order(StringComparer.OrdinalIgnoreCase).ToList();

        if (paths.Contains(FrameworkEntry, StringComparer.OrdinalIgnoreCase))
        {
            return FrameworkFolder;
        }

        var scripts = paths.Where(path => !path.Contains('/') && path.EndsWith(Script, StringComparison.OrdinalIgnoreCase)).Select(path => path[..^Script.Length]).ToList();
        var folders = paths.Where(path => path.Contains('/')).Select(path => path[..path.IndexOf('/')]).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var name = scripts.Find(script => folders.Contains(script, StringComparer.OrdinalIgnoreCase))
            ?? (scripts.Count == 1 ? scripts[0] : null)
            ?? (scripts.Count == 0 ? folders.FirstOrDefault() : null)
            ?? key;
        return name;
    }

    /// <summary>
    /// Tells why a path inside Patch may not be written by a mod's package.
    /// </summary>
    /// <param name="path">The path inside Patch, with either slash.</param>
    /// <param name="framework">Whether the package is the framework's, which alone may write its own files.</param>
    /// <returns>Why not, after the path; <see langword="null"/> when it may.</returns>
    public static string? RefusalOf(string path, bool framework)
    {
        var parts = path.Replace('\\', '/').Split('/');

        if (path.Contains(':', StringComparison.Ordinal) || parts.Any(part => part.Length == 0 || part.Trim().Trim('.').Length == 0))
        {
            return "would land outside the Patch folder";
        }

        if (framework)
        {
            return null;
        }

        if (parts.Length == 1 && Same(parts[0], Loader))
        {
            return "is the game's loader, which no mod may replace";
        }

        return (parts.Length == 1 && Same(parts[0], FrameworkEntry)) || Same(parts[0], FrameworkFolder)
            ? "is the Mod Framework's, which only the framework itself ships"
            : null;
    }

    /// <summary>
    /// Tells whether a path inside Patch is one of the framework's own files: its entry file or a
    /// file in its folder.
    /// </summary>
    /// <param name="path">The path inside Patch, with forward slashes.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsFrameworkFile(string path) =>
        Same(path, FrameworkEntry) || path.StartsWith(FrameworkFolder + "/", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Lists the mods the loader finds in a package's files, by the rule of <see cref="ModNames"/>.
    /// </summary>
    /// <remarks>
    /// It restates <see cref="ModNames"/> over a list of paths instead of the disk, so the two change together.
    /// </remarks>
    /// <param name="paths">The files' paths inside Patch, with forward slashes.</param>
    /// <returns>Each script at the top without its extension, and each top folder holding a script outside a Patch folder right inside it, each once, sorted.</returns>
    public static List<string> RowsOf(IEnumerable<string> paths)
    {
        var rows = new List<string>();

        foreach (var parts in paths.Select(path => path.Split('/')).Where(parts => IsScript(parts[^1])))
        {
            if (parts.Length == 1)
            {
                rows.Add(parts[0][..^Script.Length]);
            }
            else if (parts.Length == 2 || !Same(parts[1], Name))
            {
                rows.Add(parts[0]);
            }
        }

        return rows.Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.OrdinalIgnoreCase).ToList();
    }

    /// <summary>
    /// Lists the mods the Patch folder holds: each script at its top, and each folder there that holds
    /// a script outside a Patch folder right inside it and has no script of its name beside it.
    /// </summary>
    /// <remarks>
    /// <see cref="RowsOf"/> restates this rule over a package's list of files, so the two change together.
    /// </remarks>
    /// <param name="gameFolder">The game folder.</param>
    /// <returns>The names, sorted; a name that is no mod's is left out, logged when it would be one.</returns>
    public static List<string> ModNames(string gameFolder)
    {
        var patch = PathOf(gameFolder);

        try
        {
            if (!Directory.Exists(patch))
            {
                return [];
            }

            var scripts = Directory.EnumerateFiles(patch).Select(Path.GetFileName).OfType<string>()
                .Where(file => file.EndsWith(Script, StringComparison.OrdinalIgnoreCase))
                .Select(file => file[..^Script.Length]);
            var folders = Directory.EnumerateDirectories(patch)
                .Where(HoldsOwnScript)
                .Select(Path.GetFileName).OfType<string>();
            var names = scripts.Concat(folders).Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.OrdinalIgnoreCase).ToList();

            foreach (var name in names.Where(name => !IsName(name) && !NotMods.Contains(name, StringComparer.OrdinalIgnoreCase)))
            {
                Log.Write($"Patch/{name} is left out of the mods: rename it without \"=\" and trailing dots or spaces");
            }

            return names.Where(IsName).ToList();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not list the mods in Patch: {ex.Message}");
            return [];
        }
    }

    /// <summary>
    /// Tells whether a folder at the top of Patch holds a script of its own: in it, or below in a
    /// folder not named Patch.
    /// </summary>
    /// <remarks>
    /// A release zip extracted into Patch leaves its scripts in such a Patch folder, where they belong
    /// to no mod and the loader names them in a message instead.
    /// </remarks>
    /// <param name="folder">The folder's full path.</param>
    /// <returns>Whether it does.</returns>
    private static bool HoldsOwnScript(string folder)
    {
        var below = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true };
        var inside = new EnumerationOptions { IgnoreInaccessible = true };

        return Directory.EnumerateFiles(folder, "*" + Script, inside).Any(IsScript)
            || Directory.EnumerateDirectories(folder, "*", inside)
                .Where(sub => !Same(Path.GetFileName(sub), Name))
                .Any(sub => Directory.EnumerateFiles(sub, "*" + Script, below).Any(IsScript));
    }

    /// <summary>
    /// Tells whether a file is a script the game's loader evaluates.
    /// </summary>
    /// <param name="file">The file's path.</param>
    /// <returns>Whether it ends in <see cref="Script"/>, whatever its case.</returns>
    private static bool IsScript(string file) => file.EndsWith(Script, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Finds how a folder spells an entry, ignoring case.
    /// </summary>
    /// <param name="folder">The folder's full path.</param>
    /// <param name="name">The entry's name.</param>
    /// <returns>The name as the folder spells it: the name itself when the folder holds it so or holds no such entry.</returns>
    private static string SpelledIn(string folder, string name)
    {
        try
        {
            if (!Directory.Exists(folder))
            {
                return name;
            }

            var found = Directory.EnumerateFileSystemEntries(folder).Select(Path.GetFileName).OfType<string>().Where(entry => Same(entry, name)).ToList();
            return found.Contains(name, StringComparer.Ordinal) ? name : found.FirstOrDefault() ?? name;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return name;
        }
    }

    /// <summary>
    /// Tells whether two names are one, as the game finds files.
    /// </summary>
    /// <param name="one">One name.</param>
    /// <param name="other">The other name.</param>
    /// <returns>Whether they are the same but for case.</returns>
    private static bool Same(string one, string other) => string.Equals(one, other, StringComparison.OrdinalIgnoreCase);
}
