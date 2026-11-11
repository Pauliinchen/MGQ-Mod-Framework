//----------------------------------------------------------------
//  GameWindow.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Noted every key that went down, typing or not, for the input model
//      Paulinchen  2026-11-09: Noted a failure of the window procedure without making objects
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Hooked the window as the framework starts and kept the game running only when asked
//                            - Logged the module of the window procedure it replaced
//      Paulinchen  2026-10-12: Gathered the mouse wheel's turns for the game script
//      Paulinchen  2026-10-11: Told the Alt guard which character came with Alt
//      Paulinchen  2026-10-08: Kept Alt from opening the window's menu while a text screen wants the keyboard
//                            - Kept the window's menu closed for an Alt press that began while typing
//      Paulinchen  2026-10-07: Logged why the game cannot keep running in the background
//                            - Caught and logged failures of the window procedure's own work
//                            - Let the clipboard find the game's window
//      Paulinchen  2026-09-29: Passed key presses and typed characters on to Keyboard while a text screen wants them
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Windows;

/// <summary>
/// The game's window, whose one hook the framework owns: it feeds the keyboard, the keys that went
/// down, the mouse wheel and the Alt guard, and keeps the game running while another application is active when asked to.
/// </summary>
internal static unsafe partial class GameWindow
{
    /// <summary>
    /// The index of a window's procedure among its values.
    /// </summary>
    private const int ProcedureIndex = -4;

    /// <summary>
    /// WM_ACTIVATEAPP, which tells a window that its application became active or inactive.
    /// </summary>
    private const uint ActivateApp = 0x1C;

    /// <summary>
    /// WM_KEYDOWN, a key going down.
    /// </summary>
    private const uint KeyDown = 0x0100;

    /// <summary>
    /// WM_CHAR, a character Windows made from a key press.
    /// </summary>
    private const uint Character = 0x0102;

    /// <summary>
    /// WM_SYSKEYDOWN, a key going down while Alt is held, as with AltGr.
    /// </summary>
    private const uint SystemKeyDown = 0x0104;

    /// <summary>
    /// WM_SYSCOMMAND, a command of the window's menu.
    /// </summary>
    private const uint SystemCommand = 0x0112;

    /// <summary>
    /// SC_KEYMENU, the command Alt sends to open the window's menu by keyboard.
    /// </summary>
    private const nint KeyMenu = 0xF100;

    /// <summary>
    /// WM_MOUSEWHEEL, the mouse wheel turned.
    /// </summary>
    private const uint MouseWheelTurned = 0x020A;

    /// <summary>
    /// Keeps Alt from opening the window's menu while the player types, and as Alt is released after.
    /// </summary>
    private static readonly AltMenuGuard altMenu = new();

    /// <summary>
    /// The game's window once hooked, 0 before.
    /// </summary>
    private static nint hooked;

    /// <summary>
    /// The window procedure that was in place before, which gets every message on.
    /// </summary>
    private static nint previousProcedure;

    /// <summary>
    /// Whether the game keeps running while another application is active.
    /// </summary>
    private static bool keepRunning;

    /// <summary>
    /// The mouse wheel's turns over the window, which the game script takes.
    /// </summary>
    public static MouseWheel Wheel { get; } = new();

    /// <summary>
    /// The keys that went down in the window, typing or not, which the input model takes each tick.
    /// </summary>
    public static KeyPresses KeyPresses { get; } = new();

    /// <summary>
    /// Hooks the game's window, once.
    /// </summary>
    /// <returns><see langword="true"/> when the window is hooked.</returns>
    public static bool Hook()
    {
        if (hooked != 0)
        {
            return true;
        }

        var window = GameWindowFinder.Find();
        if (window == 0)
        {
            Log.Write("game window: none of this game found, so it stays unhooked");
            return false;
        }

        var procedure = (nint)(delegate* unmanaged[Stdcall]<nint, uint, nint, nint, nint>)&Procedure;
        previousProcedure = SetWindowLongW(window, ProcedureIndex, procedure);
        if (previousProcedure == 0)
        {
            Log.Write($"game window: could not be hooked, Windows error {Marshal.GetLastPInvokeError()}");
            return false;
        }

        hooked = window;
        Log.Write($"game window: hooked, the procedure before is in {ModuleOf(previousProcedure)}");
        return true;
    }

    /// <summary>
    /// Keeps the game running while another application is active, or lets it pause there again as
    /// RGSS does on its own.
    /// </summary>
    /// <remarks>
    /// RGSS301.dll learns of it only from WM_ACTIVATEAPP, and its frame loop waits while the last
    /// one said inactive.
    /// </remarks>
    /// <param name="on">Whether the game keeps running.</param>
    /// <returns>Whether the game keeps running now; <see langword="false"/> while the window is not hooked.</returns>
    public static bool KeepRunning(bool on)
    {
        if (hooked == 0)
        {
            Log.Write("game window: the game cannot keep running in the background, its window is not hooked");
            return false;
        }

        if (Volatile.Read(ref keepRunning) == on)
        {
            return on;
        }

        Volatile.Write(ref keepRunning, on);
        Log.Write(on ? "game window: the game keeps running in the background" : "game window: the game pauses in the background again");

        // The game may have started behind another application, which RGSS remembers until told
        // otherwise; turned off, it learns where it stands now.
        PostMessageW(hooked, ActivateApp, on || GetForegroundWindow() == hooked ? 1 : 0, 0);
        return on;
    }

    /// <summary>
    /// Hands every message on, telling the game its application is active whenever Windows says
    /// either while it keeps running, passing what is typed to <see cref="Keyboard"/> while it wants
    /// it, noting each key that went down in <see cref="KeyPresses"/> and gathering the mouse wheel's
    /// turns in <see cref="Wheel"/>.
    /// </summary>
    /// <remarks>
    /// Nothing may throw out of it, since an exception crossing into the game ends it.
    /// </remarks>
    /// <param name="window">The game's window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns>What the previous procedure returned.</returns>
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static nint Procedure(nint window, uint message, nint wParam, nint lParam)
    {
        try
        {
            var typing = Keyboard.Active;
            if (message is KeyDown or SystemKeyDown)
            {
                KeyPresses.Note((int)wParam & 0xFF);
            }

            if (message == SystemKeyDown)
            {
                altMenu.SystemKeyDown(typing, (uint)wParam, lParam);
            }

            if (message == MouseWheelTurned)
            {
                Wheel.Turn((short)((uint)wParam >> 16));
            }

            if (message == ActivateApp)
            {
                if (Volatile.Read(ref keepRunning))
                {
                    wParam = 1;
                }
            }
            else if (message == SystemCommand && (wParam & 0xFFF0) == KeyMenu)
            {
                // Text fields and Alt-drags take Alt, whose release would open the window's menu, in
                // which the game waits.
                if (altMenu.SwallowsKeyMenu(typing, lParam))
                {
                    return 0;
                }
            }
            else if (typing)
            {
                if (message == Character)
                {
                    Keyboard.TakeCharacter((char)wParam);
                }
                else if (message is KeyDown or SystemKeyDown)
                {
                    Keyboard.TakeKey((uint)wParam, (uint)(lParam >> 16) & 0xFF);
                }
            }
        }
        catch (Exception ex)
        {
            ExportFaults.Note("the game window's procedure", ex);
        }

        return CallWindowProcW(previousProcedure, window, message, wParam, lParam);
    }

    /// <summary>
    /// Names the module a window procedure lies in, which tells the game's own from another mod's hook.
    /// </summary>
    /// <param name="procedure">The procedure.</param>
    /// <returns>The module's file name, such as "RGSS301.dll", or a note that it lies in none.</returns>
    private static string ModuleOf(nint procedure) =>
        NativeMethods.FileOfModuleContaining(procedure) is { } file ? Path.GetFileName(file) : $"no module (0x{procedure:X})";

    /// <summary>
    /// Replaces one of a window's values.
    /// </summary>
    /// <remarks>
    /// The 32-bit user32.dll exports no SetWindowLongPtrW, and a pointer fits a LONG in a 32-bit process.
    /// </remarks>
    /// <param name="window">The window.</param>
    /// <param name="index">Which value.</param>
    /// <param name="value">The new value.</param>
    /// <returns>The previous value, or 0 when it failed.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    private static partial nint SetWindowLongW(nint window, int index, nint value);

    /// <summary>
    /// Hands a message to a window procedure.
    /// </summary>
    /// <param name="procedure">The window procedure.</param>
    /// <param name="window">The window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns>What the procedure returned.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint CallWindowProcW(nint procedure, nint window, uint message, nint wParam, nint lParam);

    /// <summary>
    /// Queues a message for a window.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="message">The message.</param>
    /// <param name="wParam">The message's first value.</param>
    /// <param name="lParam">The message's second value.</param>
    /// <returns><see langword="true"/> when it was queued.</returns>
    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool PostMessageW(nint window, uint message, nint wParam, nint lParam);

    /// <summary>
    /// Finds the window the player works in now.
    /// </summary>
    /// <returns>The window, or 0 when none is active.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint GetForegroundWindow();
}
