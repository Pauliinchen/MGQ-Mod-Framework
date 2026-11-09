//----------------------------------------------------------------
//  GameExe.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Left the program as it is while Smart App Control is on
//                            - Logged the flag as set when noting it in Install.ini fails
//                            - Tried the second rename again while a virus scanner holds the copy
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Windows;

/// <summary>
/// Lets the game's own Game.exe use up to 4 GB of address space instead of 2 GB, by setting the
/// large address aware flag in its header once: a changed copy takes the program's name, and the
/// program before stays beside it as <c>Game.exe.before-4gb</c>. It takes effect at the next start.
/// </summary>
/// <remarks>
/// The header's checksum stays as it is, since Windows checks it only for drivers and system DLLs.
/// </remarks>
internal static partial class GameExe
{
    /// <summary>
    /// What the program before is kept as, after its own name.
    /// </summary>
    public const string BackupSuffix = ".before-4gb";

    /// <summary>
    /// What the changed copy is written as first, after the program's name.
    /// </summary>
    public const string NewSuffix = ".new";

    /// <summary>
    /// IMAGE_FILE_LARGE_ADDRESS_AWARE among the characteristics of the file header.
    /// </summary>
    private const ushort LargeAddressAware = 0x0020;

    /// <summary>
    /// IMAGE_FILE_MACHINE_I386, the machine of a 32-bit program.
    /// </summary>
    private const ushort MachineI386 = 0x014C;

    /// <summary>
    /// Where the DOS header names the offset of the PE header.
    /// </summary>
    private const int PeOffsetAt = 0x3C;

    /// <summary>
    /// The offset of the machine from the PE header's start.
    /// </summary>
    private const int MachineAt = 4;

    /// <summary>
    /// The offset of the characteristics from the PE header's start.
    /// </summary>
    private const int CharacteristicsAt = 22;

    /// <summary>
    /// The text the line of an RGSS3 game's ini names its library with, such as System\RGSS301.dll.
    /// </summary>
    private const string Rgss3 = "RGSS3";

    /// <summary>
    /// How often the copy is renamed to the program's name before the try fails.
    /// </summary>
    private const int RenameTries = 3;

    /// <summary>
    /// The milliseconds between two renames of the copy, while a virus scanner may hold it.
    /// </summary>
    private const int RenameGapMs = 200;

    /// <summary>
    /// The registry key under HKEY_LOCAL_MACHINE that holds the state of Smart App Control.
    /// </summary>
    private const string PolicyKey = @"SYSTEM\CurrentControlSet\Control\CI\Policy";

    /// <summary>
    /// The value that holds the state of Smart App Control: 0 off, 1 on, 2 evaluating.
    /// </summary>
    private const string PolicyValue = "VerifiedAndReputablePolicyState";

    /// <summary>
    /// RRF_RT_REG_DWORD, which reads a value only as a 32-bit number.
    /// </summary>
    private const int DwordOnly = 0x00000010;

    /// <summary>
    /// The state of Smart App Control while it is off for good.
    /// </summary>
    private const int SmartAppControlOff = 0;

    /// <summary>
    /// HKEY_LOCAL_MACHINE, where Windows keeps the state of Smart App Control.
    /// </summary>
    private static readonly nint LocalMachine = unchecked((nint)(int)0x80000002);

    /// <summary>
    /// 1 once the game's start tried, so a second call in the same start does nothing.
    /// </summary>
    private static int _tried;

    /// <summary>
    /// How a try ended.
    /// </summary>
    internal enum Outcome
    {
        /// <summary>The flag is set from the next start on.</summary>
        Set,

        /// <summary>The program has the flag already.</summary>
        AlreadySet,

        /// <summary>The framework set the flag once and the player took it back, which stays so.</summary>
        TakenBack,

        /// <summary>Smart App Control is on or evaluating, and would block the changed program.</summary>
        SmartAppControl,

        /// <summary>The file is no 32-bit Windows program.</summary>
        NotProgram,

        /// <summary>A program kept from before lies beside it, which nothing replaces.</summary>
        BackupExists,

        /// <summary>A step failed and the program stays as it was.</summary>
        Failed,
    }

    /// <summary>
    /// Sets the flag of the game's own program as the game starts, once per start, never on JoiPlay,
    /// and logs how it ended.
    /// </summary>
    /// <param name="gameFolder">The game's folder, where the running program must lie.</param>
    public static void AtBoot(string gameFolder)
    {
        if (Interlocked.Exchange(ref _tried, 1) == 1 || Platforms.Current == GamePlatform.JoiPlay)
        {
            return;
        }

        try
        {
            var exe = Environment.ProcessPath;

            if (exe == null || !string.Equals(Path.GetDirectoryName(Path.GetFullPath(exe)), Path.GetFullPath(gameFolder), StringComparison.OrdinalIgnoreCase))
            {
                Log.Write($"the game's program {exe ?? "?"} lies outside the game's folder, so it keeps using up to 2 GB");
                return;
            }

            if (!IsRgss3(exe))
            {
                Log.Write($"{Path.GetFileName(exe)} names no RGSS3 library in its ini, so it stays as it is");
                return;
            }

            var (outcome, error) = Apply(exe, gameFolder, SmartAppControlOn());
            Log.Write(Describe(Path.GetFileName(exe), outcome, error));
        }
        catch (Exception ex)
        {
            Log.Write($"could not let the game's program use up to 4 GB, so it stays as it was: {ex.GetType().Name}: {ex.Message}");
        }
    }

    /// <summary>
    /// Sets the flag of a program: writes a changed copy beside it, moves the program to its backup
    /// name and the copy to its name, and puts the program back when a step fails.
    /// </summary>
    /// <param name="exe">The program's full path.</param>
    /// <param name="gameFolder">The game's folder, whose Install.ini notes that the flag was set.</param>
    /// <param name="smartAppControl">Whether Smart App Control is on or evaluating, which leaves the program as it is.</param>
    /// <param name="move">Renames a file; <see cref="File.Move(string, string)"/> when none is given.</param>
    /// <returns>How it ended, and why it failed or what failed after the flag was set.</returns>
    internal static (Outcome Outcome, string? Error) Apply(string exe, string gameFolder, bool smartAppControl = false, Action<string, string>? move = null)
    {
        move ??= File.Move;
        var bytes = File.ReadAllBytes(exe);

        if (CharacteristicsOf(bytes) is not { } at)
        {
            return (Outcome.NotProgram, null);
        }

        var characteristics = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(at));

        if ((characteristics & LargeAddressAware) != 0)
        {
            return (Outcome.AlreadySet, null);
        }

        if (InstallKey.LargeAddressSetOnce(gameFolder))
        {
            return (Outcome.TakenBack, null);
        }

        if (smartAppControl)
        {
            return (Outcome.SmartAppControl, null);
        }

        var backup = exe + BackupSuffix;
        var fresh = exe + NewSuffix;

        if (File.Exists(backup))
        {
            return (Outcome.BackupExists, null);
        }

        BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(at), (ushort)(characteristics | LargeAddressAware));
        var movedAside = false;

        try
        {
            using (var file = new FileStream(fresh, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                file.Write(bytes);
                file.Flush(true);
            }

            move(exe, backup);
            movedAside = true;
            MoveRetrying(fresh, exe, move);
        }
        catch (Exception ex)
        {
            if (movedAside)
            {
                PutBack(exe, backup, move);
            }

            TryDelete(fresh);
            return (Outcome.Failed, $"{ex.GetType().Name}: {ex.Message}");
        }

        try
        {
            InstallKey.NoteLargeAddressSet(gameFolder);
        }
        catch (Exception ex)
        {
            return (Outcome.Set, $"{ex.GetType().Name}: {ex.Message}");
        }

        return (Outcome.Set, null);
    }

    /// <summary>
    /// Renames a file, again after a short wait while another program holds it.
    /// </summary>
    /// <remarks>A virus scanner holds a program it just saw written for a moment.</remarks>
    /// <param name="from">The file.</param>
    /// <param name="to">Its new name.</param>
    /// <param name="move">Renames a file.</param>
    private static void MoveRetrying(string from, string to, Action<string, string> move)
    {
        for (var tries = 1; ; tries++)
        {
            try
            {
                move(from, to);
                return;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException && tries < RenameTries)
            {
                Thread.Sleep(RenameGapMs);
            }
        }
    }

    /// <summary>
    /// Tells whether Windows' Smart App Control is on or evaluating, which blocks a changed program
    /// that Windows does not know.
    /// </summary>
    /// <remarks>While evaluating, Windows may turn it on by itself later.</remarks>
    /// <returns>Whether it is; <see langword="false"/> where the state cannot be read, such as under Wine.</returns>
    private static bool SmartAppControlOn()
    {
        try
        {
            var state = new byte[4];
            var size = state.Length;
            return RegGetValueW(LocalMachine, PolicyKey, PolicyValue, DwordOnly, 0, state, ref size) == 0 &&
                BitConverter.ToInt32(state) != SmartAppControlOff;
        }
        catch (Exception)
        {
            return false;
        }
    }

    /// <summary>
    /// Finds the characteristics of a 32-bit Windows program's file header.
    /// </summary>
    /// <param name="exe">The file's bytes.</param>
    /// <returns>Their offset; <see langword="null"/> for a file without the MZ and PE headers of an i386 program.</returns>
    internal static int? CharacteristicsOf(ReadOnlySpan<byte> exe)
    {
        if (exe.Length < PeOffsetAt + 4 || exe[0] != (byte)'M' || exe[1] != (byte)'Z')
        {
            return null;
        }

        var pe = BinaryPrimitives.ReadInt32LittleEndian(exe[PeOffsetAt..]);

        if (pe < PeOffsetAt + 4 || pe > exe.Length - CharacteristicsAt - 2 || !exe.Slice(pe, 4).SequenceEqual("PE\0\0"u8))
        {
            return null;
        }

        return BinaryPrimitives.ReadUInt16LittleEndian(exe[(pe + MachineAt)..]) == MachineI386 ? pe + CharacteristicsAt : null;
    }

    /// <summary>
    /// Tells whether a program is an RGSS3 game: its ini, of the program's name, names an RGSS3 library.
    /// </summary>
    /// <param name="exe">The program's full path.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsRgss3(string exe) =>
        IniFile.Load(Path.ChangeExtension(exe, ".ini"), "the game's ini", false) is { } values &&
        values.TryGetValue("Library", out var library) && library.Contains(Rgss3, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Puts the program back under its name after a step failed, copying the backup when it cannot be renamed.
    /// </summary>
    /// <param name="exe">The program's full path.</param>
    /// <param name="backup">The backup's full path.</param>
    /// <param name="move">Renames a file.</param>
    private static void PutBack(string exe, string backup, Action<string, string> move)
    {
        if (File.Exists(exe))
        {
            return;
        }

        try
        {
            move(backup, exe);
        }
        catch (Exception)
        {
            try
            {
                File.Copy(backup, exe);
            }
            catch (Exception ex)
            {
                Log.Write($"could not put {Path.GetFileName(exe)} back: rename {Path.GetFileName(backup)} to {Path.GetFileName(exe)} by hand ({ex.Message})");
            }
        }
    }

    /// <summary>
    /// Deletes a file that may not be there.
    /// </summary>
    /// <param name="path">The file.</param>
    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch (Exception)
        {
        }
    }

    /// <summary>
    /// Writes the log line of how a try ended.
    /// </summary>
    /// <param name="name">The program's file name, such as Game.exe.</param>
    /// <param name="outcome">How it ended.</param>
    /// <param name="error">Why it failed.</param>
    /// <returns>The line.</returns>
    private static string Describe(string name, Outcome outcome, string? error) => outcome switch
    {
        Outcome.Set when error != null => $"{name} now uses up to 4 GB from its next start; the program before is kept as {name}{BackupSuffix}; " +
            $"noting this in Install.ini failed, so if the program before is put back, the next start sets 4 GB again: {error}",
        Outcome.Set => $"{name} now uses up to 4 GB from its next start; the program before is kept as {name}{BackupSuffix}",
        Outcome.AlreadySet => $"{name} uses up to 4 GB",
        Outcome.TakenBack => $"{name} uses up to 2 GB, since the player put back the program from before the framework set it to 4 GB",
        Outcome.SmartAppControl => $"skipped letting {name} use up to 4 GB, since Windows' Smart App Control is on and would block the changed program; it keeps using up to 2 GB",
        Outcome.NotProgram => $"{name} is no 32-bit Windows program, so it stays as it is",
        Outcome.BackupExists => $"{name} keeps using up to 2 GB, since {name}{BackupSuffix} lies beside it already",
        _ => $"could not let {name} use up to 4 GB, so it stays as it was: {error}",
    };

    /// <summary>
    /// Reads a value of the registry.
    /// </summary>
    /// <param name="key">The open key it lies under, such as <see cref="LocalMachine"/>.</param>
    /// <param name="subKey">The path below it.</param>
    /// <param name="value">The value's name.</param>
    /// <param name="flags">The types it may have, such as <see cref="DwordOnly"/>.</param>
    /// <param name="type">Where its type would go, 0 for nowhere.</param>
    /// <param name="data">The bytes read.</param>
    /// <param name="size">The room in <paramref name="data"/>, then the bytes read.</param>
    /// <returns>0 when it was read, else Windows' error.</returns>
    [LibraryImport("advapi32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int RegGetValueW(nint key, string subKey, string value, int flags, nint type, byte[] data, ref int size);
}
