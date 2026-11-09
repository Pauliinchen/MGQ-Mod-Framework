//----------------------------------------------------------------
//  WindowsInput.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-31: Read the game's key settings of F1 from the registry
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.InteropServices;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Input;

/// <summary>
/// Reads the pointer, the keys and the mouse buttons from Windows, against the game's window.
/// </summary>
internal sealed partial class WindowsInput : IInputSource
{
    /// <summary>
    /// Set in GetAsyncKeyState's answer while the key is held.
    /// </summary>
    private const int Held = 0x8000;

    /// <summary>
    /// SM_SWAPBUTTON, which GetSystemMetrics answers non-zero for while the mouse buttons are swapped.
    /// </summary>
    private const int SwapButtonMetric = 23;

    /// <summary>
    /// HKEY_CURRENT_USER, where RGSS3 keeps the game's settings.
    /// </summary>
    private static readonly nint CurrentUser = unchecked((nint)(int)0x80000001);

    /// <summary>
    /// The key RGSS3 keeps its settings under.
    /// </summary>
    private const string AssignKey = @"Software\Enterbrain\RGSS3";

    /// <summary>
    /// The value that holds the key settings of F1.
    /// </summary>
    private const string AssignValue = "ButtonAssign";

    /// <summary>
    /// RRF_RT_REG_BINARY, which reads a value only as bytes.
    /// </summary>
    private const int BinaryOnly = 0x00000008;

    /// <summary>
    /// The game's window once found, 0 before.
    /// </summary>
    private nint window;

    /// <inheritdoc />
    public bool GameInFront()
    {
        var game = Window();
        return game != 0 && GetForegroundWindow() == game;
    }

    /// <inheritdoc />
    public ClientPointer? Pointer()
    {
        var game = Window();
        if (game == 0 || !GetCursorPos(out var point) || !ScreenToClient(game, ref point) || !GetClientRect(game, out var client))
        {
            return null;
        }

        return new ClientPointer(point.X, point.Y, client.Right - client.Left, client.Bottom - client.Top);
    }

    /// <inheritdoc />
    public bool KeyDown(int code) => (GetAsyncKeyState(code) & Held) != 0;

    /// <inheritdoc />
    public bool ButtonsSwapped() => GetSystemMetrics(SwapButtonMetric) != 0;

    /// <inheritdoc />
    public int TakeWheel() => GameWindow.Wheel.Take();

    /// <inheritdoc />
    public byte[]? ButtonAssign()
    {
        var bytes = new byte[ButtonAssignment.Length * 2];
        int size = bytes.Length;
        if (RegGetValueW(CurrentUser, AssignKey, AssignValue, BinaryOnly, 0, bytes, ref size) != 0)
        {
            return null;
        }

        Array.Resize(ref bytes, size);
        return bytes;
    }

    /// <summary>
    /// Finds the game's window, once it exists.
    /// </summary>
    /// <returns>The window, 0 while there is none.</returns>
    private nint Window()
    {
        if (window == 0)
        {
            window = GameWindowFinder.Find();
        }

        return window;
    }

    /// <summary>
    /// Finds the window the player works in now.
    /// </summary>
    /// <returns>The window, or 0 when none is active.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint GetForegroundWindow();

    /// <summary>
    /// Reads where the pointer is on the screen.
    /// </summary>
    /// <param name="point">The place in screen pixels.</param>
    /// <returns><see langword="true"/> when it was read.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetCursorPos(out Point point);

    /// <summary>
    /// Turns a place on the screen into one in a window's client area.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="point">The place, turned in place.</param>
    /// <returns><see langword="true"/> when it was turned.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool ScreenToClient(nint window, ref Point point);

    /// <summary>
    /// Reads a window's client area, whose left and top are always 0.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="rect">The client area.</param>
    /// <returns><see langword="true"/> when it was read.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetClientRect(nint window, out Rect rect);

    /// <summary>
    /// Reads a key's or a physical mouse button's state, whichever window has the keyboard.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>The state, <see cref="Held"/> set while held.</returns>
    [LibraryImport("user32.dll")]
    private static partial short GetAsyncKeyState(int code);

    /// <summary>
    /// Reads one of Windows' system settings.
    /// </summary>
    /// <param name="index">Which one, such as <see cref="SwapButtonMetric"/>.</param>
    /// <returns>Its value.</returns>
    [LibraryImport("user32.dll")]
    private static partial int GetSystemMetrics(int index);

    /// <summary>
    /// Reads a value of the registry.
    /// </summary>
    /// <param name="key">The open key it lies under, such as <see cref="CurrentUser"/>.</param>
    /// <param name="subKey">The path below it.</param>
    /// <param name="value">The value's name.</param>
    /// <param name="flags">The types it may have, such as <see cref="BinaryOnly"/>.</param>
    /// <param name="type">Where its type would go, 0 for nowhere.</param>
    /// <param name="data">The bytes read.</param>
    /// <param name="size">The room in <paramref name="data"/>, then the bytes read.</param>
    /// <returns>0 when it was read, else Windows' error.</returns>
    [LibraryImport("advapi32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int RegGetValueW(nint key, string subKey, string value, int flags, nint type, byte[] data, ref int size);

    /// <summary>
    /// A place in pixels, POINT.
    /// </summary>
    /// <param name="X">The left offset.</param>
    /// <param name="Y">The top offset.</param>
    [StructLayout(LayoutKind.Sequential)]
    private record struct Point(int X, int Y);

    /// <summary>
    /// A rectangle in pixels, RECT.
    /// </summary>
    /// <param name="Left">Its left edge.</param>
    /// <param name="Top">Its top edge.</param>
    /// <param name="Right">Its right edge, past its last pixel.</param>
    /// <param name="Bottom">Its bottom edge, past its last pixel.</param>
    [StructLayout(LayoutKind.Sequential)]
    private record struct Rect(int Left, int Top, int Right, int Bottom);
}
