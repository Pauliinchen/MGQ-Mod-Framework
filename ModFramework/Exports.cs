//----------------------------------------------------------------
//  Exports.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Noted a failed start without making objects, for the next drain to log
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Took the log name from the log
//      Paulinchen  2026-10-30: Started the framework on JoiPlay with mf_start_android
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework;

/// <summary>
/// The DLL's start exports, mf_start and mf_start_android; the four bridge exports are in
/// BridgeExports, and every other call is a topic.
/// </summary>
/// <remarks>
/// Nothing may throw out of them, since an exception crossing into the game ends it.
/// </remarks>
internal static unsafe class Exports
{
    /// <summary>
    /// Whether the log was started, which a second start leaves alone.
    /// </summary>
    private static bool started;

    /// <summary>
    /// Starts the framework (mf_start, 'v'): names the game folder after the current directory,
    /// which RGSS keeps at the game's folder, so a copy deep inside another mod's folder still logs
    /// into the game's Logs folder; starts the log and hooks the game's window. Calling it again only
    /// tries the hook again when it failed.
    /// </summary>
    /// <returns>1 when started with the window hooked, 0 when either failed; the log tells why.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mf_start", CallConvs = [typeof(CallConvStdcall)])]
    public static int Start()
    {
        try
        {
            if (!started)
            {
                StartLog();
                started = true;
            }

            return GameWindow.Hook() ? 1 : 0;
        }
        catch (Exception ex)
        {
            ExportFaults.Note("mf_start", ex);
            return 0;
        }
    }

    /// <summary>
    /// Starts the framework on JoiPlay (mf_start_android): names the game folder after the current
    /// directory and the framework's folder as the scripts name it, starts the log and readies
    /// crypto and HTTPS through the libssl stand-in. There is no window to hook. Calling it again
    /// does nothing.
    /// </summary>
    /// <remarks>
    /// The library itself runs from the app's own folder, the only place Android loads it from, so
    /// it cannot find the framework's folder on its own as the DLL does.
    /// </remarks>
    /// <param name="folder">The framework's folder, a full path in UTF-8, zero-terminated.</param>
    /// <param name="standIn">The stand-in's full path in UTF-8, zero-terminated.</param>
    /// <returns>1 when started with crypto ready, 0 when the stand-in failed; the log tells why.</returns>
    [UnmanagedCallersOnly(EntryPoint = "mf_start_android")]
    public static int StartAndroid(byte* folder, byte* standIn)
    {
        try
        {
            if (!started)
            {
                ModFolder.SetGameRoot(Environment.CurrentDirectory);
                ModFolder.SetRoot(Marshal.PtrToStringUTF8((nint)folder)!);
                WriteFirstLines();
                started = true;
                Log.Write($"crypto: {AndroidTls.Ready(Marshal.PtrToStringUTF8((nint)standIn)!)}");
            }

            return 1;
        }
        catch (Exception ex)
        {
            ExportFaults.Note("mf_start_android", ex);
            return 0;
        }
    }

    /// <summary>
    /// Names the game folder and the framework's folder and writes the first lines.
    /// </summary>
    private static void StartLog()
    {
        ModFolder.SetGameRoot(Environment.CurrentDirectory);
        if (NativeMethods.FileOfModuleContaining((nint)(delegate* unmanaged[Stdcall]<int>)&Start) is { } dll)
        {
            ModFolder.SetRoot(Path.GetDirectoryName(dll)!);
        }

        WriteFirstLines();
        if (NativeMethods.WineVersion() is { } wine)
        {
            Log.Write($"the game runs under wine {wine}");
        }
    }

    /// <summary>
    /// Writes the first line and deletes the logs of earlier days.
    /// </summary>
    private static void WriteFirstLines()
    {
        Log.Write($"--- {Log.Name} {FrameworkBridge.Build} started ---");
        Log.DeleteOtherDays();
    }
}
