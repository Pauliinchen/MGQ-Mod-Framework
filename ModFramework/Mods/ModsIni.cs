//----------------------------------------------------------------
//  ModsIni.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-01: Read a tag the player gave as the mod's line only and stopped writing it
//      Paulinchen  2026-10-30: Named its paths with forward slashes, which JoiPlay reads too
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
/// The player's choices about the mods in Patch, <c>Patch\Mod_Framework\Mods.ini</c>: one line per
/// mod, <c>&lt;name&gt;=on Regular</c>, in the order the mods load.
/// </summary>
/// <remarks>
/// Every line names the tag the mod loads with, so the loader can follow the file without the DLL.
/// </remarks>
internal static class ModsIni
{
    /// <summary>
    /// The file, relative to the game's folder, beside the framework's settings whichever copy runs.
    /// </summary>
    public const string FilePath = "Patch/Mod_Framework/Mods.ini";

    /// <summary>
    /// The word of a mod that is on.
    /// </summary>
    public const string On = "on";

    /// <summary>
    /// The word of a mod that is off.
    /// </summary>
    public const string Off = "off";


    /// <summary>
    /// Reads the file.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Each mod's line by its name, in the file's order; empty when the file is missing, <see langword="null"/> when it cannot be read.</returns>
    public static OrderedDictionary<string, ModsIniEntry>? Load(string gameFolder)
    {
        if (IniFile.Load(Path.Combine(gameFolder, FilePath), "Mods.ini", false) is not { } values)
        {
            return null;
        }

        var entries = new OrderedDictionary<string, ModsIniEntry>(StringComparer.OrdinalIgnoreCase);

        foreach (var (name, value) in values)
        {
            entries[name] = Parse(value);
        }

        return entries;
    }

    /// <summary>
    /// Writes the file when its lines changed, in one step.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="entries">Each mod's line by its name, in the order the mods load.</param>
    /// <returns>Whether the file holds the lines now; a missing file holds no line.</returns>
    public static bool Write(string gameFolder, IEnumerable<KeyValuePair<string, ModsIniEntry>> entries)
    {
        var lines = entries.Select(entry => new KeyValuePair<string, string>(entry.Key, Format(entry.Value))).ToList();
        var full = Path.Combine(gameFolder, FilePath);

        try
        {
            if (File.Exists(full) ? IniFile.Load(full, "Mods.ini", true) is { } held && held.SequenceEqual(lines) : lines.Count == 0)
            {
                return true;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"did not write Mods.ini: {ex.Message}");
            return false;
        }

        return IniFile.Write(full, "Mods.ini", lines);
    }

    /// <summary>
    /// Tells whether a mod's name can be a key of the file.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>Whether it holds no "=", which would end the key early.</returns>
    public static bool IsKey(string name) => !name.Contains('=', StringComparison.Ordinal);

    /// <summary>
    /// Reads a line's value; words after the tag are left out.
    /// </summary>
    /// <param name="value">The value, such as <c>off Title</c>.</param>
    /// <returns>The entry: on unless it starts with <c>off</c>, the tag empty when it names none this version knows.</returns>
    internal static ModsIniEntry Parse(string value)
    {
        var words = value.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var on = words.Length == 0 || !string.Equals(words[0], Off, StringComparison.OrdinalIgnoreCase);
        var tag = words.Length > 1 ? ModTag.Parse(words[1]) ?? string.Empty : string.Empty;
        return new ModsIniEntry(on, tag);
    }

    /// <summary>
    /// Writes a line's value.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>The value, such as <c>on Regular</c>.</returns>
    internal static string Format(ModsIniEntry entry) =>
        string.Join(' ', new[] { entry.On ? On : Off, entry.Tag }.Where(word => word.Length > 0));
}

/// <summary>
/// A mod's line of Mods.ini.
/// </summary>
/// <param name="On">Whether the mod is on.</param>
/// <param name="Tag">The tag it loads with, see <see cref="ModTag"/>; empty for none.</param>
internal sealed record ModsIniEntry(bool On, string Tag);
