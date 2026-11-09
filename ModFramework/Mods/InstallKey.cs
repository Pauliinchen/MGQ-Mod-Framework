//----------------------------------------------------------------
//  InstallKey.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Noted whether the framework once let the game's program use up to 4 GB
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-30: Named its paths with forward slashes, which JoiPlay reads too
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Keeps the anonymous install key this game rates the website's mods with, made once per install,
/// whether the player rates at all, and the mods this install downloaded from the website, which
/// are the only ones the website takes its votes on; and whether the framework once let the game's
/// program use up to 4 GB.
/// </summary>
/// <remarks>
/// The key goes to the website alone, as the bearer value of downloads and votes, and is never
/// logged: whoever had it could rate as this game.
/// </remarks>
internal static class InstallKey
{
    /// <summary>
    /// The file, relative to the game's folder, beside Mods.ini and in no package, so updates keep it.
    /// </summary>
    public const string FilePath = "Patch/Mod_Framework/Install.ini";

    /// <summary>
    /// How many random bytes a key holds.
    /// </summary>
    public const int KeyBytes = 32;

    /// <summary>
    /// The line of the key, 64 hex characters.
    /// </summary>
    private const string KeyLine = "key";

    /// <summary>
    /// The line that tells whether the player rates mods: "off" while not.
    /// </summary>
    private const string RatingsLine = "ratings";

    /// <summary>
    /// The line of a key whose votes the website is still to forget.
    /// </summary>
    private const string ForgetLine = "forget";

    /// <summary>
    /// The line of the slugs of the mods this install downloaded from the website, a space apart.
    /// </summary>
    private const string DownloadedLine = "downloaded";

    /// <summary>
    /// The line that tells the framework once let the game's program use up to 4 GB: "set".
    /// </summary>
    private const string LargeAddressLine = "large_address";

    /// <summary>
    /// The value of <see cref="RatingsLine"/> while the player rates no mods.
    /// </summary>
    private const string Off = "off";

    /// <summary>
    /// The value of <see cref="LargeAddressLine"/> once the framework set the flag.
    /// </summary>
    private const string Set = "set";

    /// <summary>
    /// Keeps the file to one reader and writer at a time, for the game's threads.
    /// </summary>
    private static readonly object Gate = new();

    /// <summary>
    /// Tells whether the player rates mods.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Whether ratings are on; on until the player turns them off.</returns>
    public static bool RatingsOn(string gameFolder)
    {
        lock (Gate)
        {
            return Read(gameFolder).GetValueOrDefault(RatingsLine) != Off;
        }
    }

    /// <summary>
    /// Tells the key while the player rates mods, without making one.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The key; <see langword="null"/> while ratings are off or none was made yet.</returns>
    public static string? Current(string gameFolder)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);
            return lines.GetValueOrDefault(RatingsLine) != Off && lines.TryGetValue(KeyLine, out var key) && IsKey(key) ? key : null;
        }
    }

    /// <summary>
    /// Hands out the key for a download or a vote, making it the first time it is needed.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The key, 64 hex characters; <see langword="null"/> while ratings are off or the file cannot be written.</returns>
    public static string? Bearer(string gameFolder)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);

            if (lines.GetValueOrDefault(RatingsLine) == Off)
            {
                return null;
            }

            if (lines.TryGetValue(KeyLine, out var key) && IsKey(key))
            {
                return key;
            }

            var made = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(KeyBytes));
            lines[KeyLine] = made;
            lines.Remove(DownloadedLine);

            if (!Write(gameFolder, lines))
            {
                Log.Write("could not keep a key for the website's ratings, so none is sent");
                return null;
            }

            Log.Write("made this install's key for the website's ratings");
            return made;
        }
    }

    /// <summary>
    /// Notes a mod this install downloaded from the website with its key.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    public static void NoteDownloaded(string gameFolder, string slug) => ChangeDownloaded(gameFolder, slug, true);

    /// <summary>
    /// Forgets a mod as downloaded, once the website said its key did not download it.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    public static void ForgetDownloaded(string gameFolder, string slug) => ChangeDownloaded(gameFolder, slug, false);

    /// <summary>
    /// Tells the mods this install downloaded from the website with its key.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Their slugs.</returns>
    public static IReadOnlySet<string> Downloaded(string gameFolder)
    {
        lock (Gate)
        {
            return SlugsOf(Read(gameFolder));
        }
    }

    /// <summary>
    /// Turns the player's ratings on or off: off drops the key and the downloads noted, keeping the
    /// key only for the website to forget its votes; on makes a new key the next time one is needed.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="on">Whether the player rates mods.</param>
    /// <returns>Whether the file holds the change.</returns>
    public static bool Turn(string gameFolder, bool on)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);

            if (on)
            {
                lines.Remove(RatingsLine);
            }
            else
            {
                if (lines.TryGetValue(KeyLine, out var key) && IsKey(key))
                {
                    lines[ForgetLine] = key;
                }

                lines[RatingsLine] = Off;
                lines.Remove(KeyLine);
                lines.Remove(DownloadedLine);
            }

            return Write(gameFolder, lines);
        }
    }

    /// <summary>
    /// Tells the key whose votes the website is still to forget.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The key; <see langword="null"/> for none.</returns>
    public static string? ToForget(string gameFolder)
    {
        lock (Gate)
        {
            return Read(gameFolder).TryGetValue(ForgetLine, out var key) && IsKey(key) ? key : null;
        }
    }

    /// <summary>
    /// Drops the key the website forgot.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    public static void Forgotten(string gameFolder)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);

            if (lines.Remove(ForgetLine))
            {
                Write(gameFolder, lines);
            }
        }
    }

    /// <summary>
    /// Tells whether the framework once let the game's program use up to 4 GB, so a player who put
    /// the program from before back keeps it.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Whether it did.</returns>
    public static bool LargeAddressSetOnce(string gameFolder)
    {
        lock (Gate)
        {
            return Read(gameFolder).GetValueOrDefault(LargeAddressLine) == Set;
        }
    }

    /// <summary>
    /// Notes that the framework let the game's program use up to 4 GB.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    public static void NoteLargeAddressSet(string gameFolder)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);
            lines[LargeAddressLine] = Set;
            Write(gameFolder, lines);
        }
    }

    /// <summary>
    /// Tells whether a text is a key: 64 hex characters.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsKey(string? text) => text is { Length: KeyBytes * 2 } && text.All(Uri.IsHexDigit);

    /// <summary>
    /// Adds a slug to the mods downloaded, or takes it out.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="downloaded">Whether it was downloaded.</param>
    private static void ChangeDownloaded(string gameFolder, string slug, bool downloaded)
    {
        lock (Gate)
        {
            var lines = Read(gameFolder);
            var slugs = SlugsOf(lines);

            if ((downloaded ? slugs.Add(slug) : slugs.Remove(slug)) && lines.ContainsKey(KeyLine))
            {
                lines[DownloadedLine] = string.Join(' ', slugs.Order(StringComparer.Ordinal));
                Write(gameFolder, lines);
            }
        }
    }

    /// <summary>
    /// Reads the slugs of the mods downloaded.
    /// </summary>
    /// <param name="lines">The file's lines.</param>
    /// <returns>The slugs.</returns>
    private static HashSet<string> SlugsOf(Dictionary<string, string> lines) =>
        new(lines.GetValueOrDefault(DownloadedLine, string.Empty).Split(' ', StringSplitOptions.RemoveEmptyEntries), StringComparer.Ordinal);

    /// <summary>
    /// Reads the file's lines.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>Its values by line; none when it is missing or cannot be read.</returns>
    private static Dictionary<string, string> Read(string gameFolder) =>
        IniFile.Load(Path.Combine(gameFolder, FilePath), "Install.ini", false) is { } values ? new Dictionary<string, string>(values, StringComparer.Ordinal) : new(StringComparer.Ordinal);

    /// <summary>
    /// Writes the file's lines.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="lines">Its values by line.</param>
    /// <returns>Whether it was written.</returns>
    private static bool Write(string gameFolder, Dictionary<string, string> lines)
    {
        var full = Path.Combine(gameFolder, FilePath);

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            Log.Write($"could not write Install.ini: {ex.Message}");
            return false;
        }

        return IniFile.Write(full, "Install.ini", lines);
    }
}
