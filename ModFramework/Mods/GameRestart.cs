//----------------------------------------------------------------
//  GameRestart.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Started the game's own Game.exe again right before the game ends, without the helper
//                            - Removed the update through the helper, which the install into the waiting folder does now
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-30: Had the helper update the mods named, the framework among them, and carry the action after the restart
//                            - Carried an action for after the restart to the game that starts again
//                            - Moved into the Mod Framework
//                            - Named the game folder to the helper, wherever the framework's copy lies
//                            - Dropped the parked mods' watchdog
//      Paulinchen  2026-10-23: Started Helper.exe for the update, the restart and the watchdog, under Wine too
//                            - Read the release version through ReleaseVersion
//      Paulinchen  2026-10-22: Had the updater install the release offered, an older one too
//      Paulinchen  2026-10-09: Started the parked mods' watchdog
//      Paulinchen  2026-10-08: Started the mod's updater
//                            - Started neither the updater nor the restart under Wine
//                            - Started the game again through ProcessStartInfo instead of Start-Process
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Starts the game's own Game.exe once more right before the running game ends, so mods turned off
/// unload and the updates that wait load: the game reads its scripts only as it starts, and the
/// stub moves the waiting updates into place first.
/// </summary>
internal static class GameRestart
{
    /// <summary>
    /// The environment variable that carries the action after a restart, <c>name</c> or
    /// <c>name:value</c>, to the game that starts again, which reads and removes it as it boots.
    /// </summary>
    /// <remarks>
    /// The game starts through the shell, which hands it this process's environment.
    /// </remarks>
    internal const string ActionVariable = "MOD_FRAMEWORK_AFTER_RESTART";

    /// <summary>
    /// The longest value an action may carry.
    /// </summary>
    internal const int MaxActionValue = 1024;

    /// <summary>
    /// The longest name an action may have.
    /// </summary>
    private const int MaxActionName = 64;

    /// <summary>
    /// Writes an action after a restart as <see cref="ActionVariable"/> holds it.
    /// </summary>
    /// <param name="name">The action's name: lower-case letters, digits, <c>_</c>, <c>.</c> and <c>-</c>, starting with a letter or a digit; <see langword="null"/> for none.</param>
    /// <param name="value">What the action takes; <see langword="null"/> for nothing.</param>
    /// <param name="action">The variable's text; <see langword="null"/> for no action.</param>
    /// <returns>Why the action is refused; <see langword="null"/> when it is not.</returns>
    internal static string? ActionText(string? name, string? value, out string? action)
    {
        action = null;

        if (name == null)
        {
            return value == null ? null : "A value needs an action.";
        }

        if (name.Length is 0 or > MaxActionName || !char.IsAsciiLetterLower(name[0]) && !char.IsAsciiDigit(name[0])
            || !name.All(letter => char.IsAsciiLetterLower(letter) || char.IsAsciiDigit(letter) || letter is '_' or '.' or '-'))
        {
            return $"{name} is no action name.";
        }

        if (value != null && (value.Length > MaxActionValue || value.Contains('\0', StringComparison.Ordinal)))
        {
            return $"The value of {name} is longer than {MaxActionValue} letters or holds a null.";
        }

        action = value == null ? name : $"{name}:{value}";
        return null;
    }

    /// <summary>
    /// Names the running game's own program, which the restart starts again.
    /// </summary>
    /// <param name="gameFolder">The game's folder, whose Game.exe counts when the process names none.</param>
    /// <returns>The program's full path.</returns>
    public static string GameExeOf(string gameFolder) => Environment.ProcessPath ?? Path.Combine(gameFolder, "Game.exe");

    /// <summary>
    /// Starts the game again through the shell, which hands it none of this game's handles, carrying
    /// an action in its environment.
    /// </summary>
    /// <remarks>
    /// The shell's start is the plain process start Wine and Proton run as Windows does.
    /// </remarks>
    /// <param name="gameExe">The game's program, see <see cref="GameExeOf"/>.</param>
    /// <param name="action">What the game does once it started again, see <see cref="ActionText"/>; <see langword="null"/> for nothing.</param>
    /// <returns>Whether it started.</returns>
    public static bool StartAgain(string gameExe, string? action)
    {
        if (!File.Exists(gameExe))
        {
            Log.Write($"restart failed: {gameExe} does not exist");
            return false;
        }

        Environment.SetEnvironmentVariable(ActionVariable, action);

        try
        {
            using var process = Process.Start(new ProcessStartInfo(gameExe) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(gameExe)! });
            Log.Write($"started {Path.GetFileName(gameExe)} again{(process != null ? $" as process {process.Id}" : string.Empty)}{(action == null ? string.Empty : $" to run {action}")}");
            return true;
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException or PlatformNotSupportedException)
        {
            Environment.SetEnvironmentVariable(ActionVariable, null);
            Log.Write($"restart failed: {gameExe} did not start: {ex.Message}");
            return false;
        }
    }
}
