//----------------------------------------------------------------
//  GameWindowFinder.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.InteropServices;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// Finds the window of the game this DLL runs in.
/// </summary>
public static partial class GameWindowFinder
{
    /// <summary>
    /// The class RGSS registers its window under.
    /// </summary>
    private const string ClassName = "RGSS Player";

    /// <summary>
    /// Finds the window of this game, not of another game running next to it.
    /// </summary>
    /// <returns>The window, or 0 when there is none.</returns>
    public static nint Find()
    {
        var process = (uint)Environment.ProcessId;
        nint window = 0;

        while ((window = FindWindowExW(0, window, ClassName, null)) != 0)
        {
            GetWindowThreadProcessId(window, out var owner);

            if (owner == process)
            {
                return window;
            }
        }

        return 0;
    }

    /// <summary>
    /// Finds a top-level window by its class.
    /// </summary>
    /// <param name="parent">0 for top-level windows.</param>
    /// <param name="after">The window to continue after, 0 to start with the first.</param>
    /// <param name="className">The window class.</param>
    /// <param name="title">The window title, <see langword="null"/> for any.</param>
    /// <returns>The window, or 0 when no more match.</returns>
    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint FindWindowExW(nint parent, nint after, string className, string? title);

    /// <summary>
    /// Finds the process that owns a window.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="process">The id of the process.</param>
    /// <returns>The id of the thread that created the window.</returns>
    [LibraryImport("user32.dll")]
    private static partial uint GetWindowThreadProcessId(nint window, out uint process);
}
