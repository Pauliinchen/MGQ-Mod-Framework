//----------------------------------------------------------------
//  GameExeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that Smart App Control leaves the program alone and that a copy a scanner holds is renamed again
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;
using MGQParadox.ModFramework.Tests.Mods;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the 4 GB flag set in the game's own program, on a small sample of a 32-bit program's
/// headers.
/// </summary>
public sealed class GameExeTests
{
    /// <summary>
    /// Where the sample's PE header starts.
    /// </summary>
    private const int PeAt = 0x80;

    /// <summary>
    /// Where the sample's characteristics lie: 22 bytes into its PE header.
    /// </summary>
    private const int CharacteristicsAt = PeAt + 22;

    /// <summary>
    /// Asserts that Smart App Control leaves the program as it is; that otherwise the flag is set in a
    /// copy that takes the program's name, every other byte as it was, with the program before kept
    /// beside it and no copy left, though a virus scanner held the copy for a moment; that a second
    /// try finds it set; and that once the player put the program from before back, it stays so.
    /// </summary>
    [Fact]
    public void Apply_SetsTheFlagOnceAndKeepsTheProgramBefore()
    {
        using var game = new TempFolder();
        var original = SampleProgram();
        game.Put("Game.exe", original);
        var exe = Path.Combine(game.Path, "Game.exe");
        var scanned = false;

        var blocked = GameExe.Apply(exe, game.Path, smartAppControl: true);
        var unchanged = game.Read("Game.exe");
        var first = GameExe.Apply(exe, game.Path, move: (from, to) =>
        {
            if (from.EndsWith(GameExe.NewSuffix, StringComparison.Ordinal) && !scanned)
            {
                scanned = true;
                throw new IOException("held by a virus scanner");
            }

            File.Move(from, to);
        });
        var changed = game.Read("Game.exe");
        var second = GameExe.Apply(exe, game.Path);

        Assert.Equal((GameExe.Outcome.SmartAppControl, GameExe.Outcome.Set, GameExe.Outcome.AlreadySet), (blocked.Outcome, first.Outcome, second.Outcome));
        Assert.Equal(original, unchanged);
        Assert.Equal(0x0122, BitConverter.ToUInt16(changed, CharacteristicsAt));
        Assert.Equal(original.AsSpan(..CharacteristicsAt).ToArray(), changed.AsSpan(..CharacteristicsAt).ToArray());
        Assert.Equal(original.AsSpan((CharacteristicsAt + 2)..).ToArray(), changed.AsSpan((CharacteristicsAt + 2)..).ToArray());
        Assert.Equal(original, game.Read("Game.exe" + GameExe.BackupSuffix));
        Assert.False(game.Has("Game.exe" + GameExe.NewSuffix));

        // The player takes it back as the guide tells: deletes Game.exe and renames the backup.
        File.Delete(exe);
        File.Move(exe + GameExe.BackupSuffix, exe);

        Assert.Equal(GameExe.Outcome.TakenBack, GameExe.Apply(exe, game.Path).Outcome);
        Assert.Equal(original, game.Read("Game.exe"));
    }

    /// <summary>
    /// Asserts that a file that is no 32-bit Windows program stays as it is, and that a rename a
    /// virus scanner keeps failing puts the program back under its name, with neither a backup nor a
    /// copy left.
    /// </summary>
    [Fact]
    public void Apply_LeavesAProgramItCannotChangeAsItWas()
    {
        using var game = new TempFolder();
        var text = Encoding.ASCII.GetBytes("MZ is not enough to be a program.");
        game.Put("Text.exe", text);
        var original = SampleProgram();
        game.Put("Game.exe", original);
        var exe = Path.Combine(game.Path, "Game.exe");

        var notProgram = GameExe.Apply(Path.Combine(game.Path, "Text.exe"), game.Path);
        var failed = GameExe.Apply(exe, game.Path, move: (from, to) =>
        {
            if (from.EndsWith(GameExe.NewSuffix, StringComparison.Ordinal))
            {
                throw new UnauthorizedAccessException("blocked by a virus scanner");
            }

            File.Move(from, to);
        });

        Assert.Equal(GameExe.Outcome.NotProgram, notProgram.Outcome);
        Assert.Equal(text, game.Read("Text.exe"));
        Assert.Equal((GameExe.Outcome.Failed, "UnauthorizedAccessException: blocked by a virus scanner"), failed);
        Assert.Equal(original, game.Read("Game.exe"));
        Assert.False(game.Has("Game.exe" + GameExe.BackupSuffix) || game.Has("Game.exe" + GameExe.NewSuffix));
    }

    /// <summary>
    /// Makes the headers of a 32-bit program: MZ, the PE header's offset, PE, i386 and the
    /// characteristics of an executable 32-bit image without the 4 GB flag.
    /// </summary>
    /// <returns>The bytes.</returns>
    private static byte[] SampleProgram()
    {
        var bytes = new byte[0x200];
        bytes[0] = (byte)'M';
        bytes[1] = (byte)'Z';
        BitConverter.GetBytes(PeAt).CopyTo(bytes, 0x3C);
        "PE\0\0"u8.CopyTo(bytes.AsSpan(PeAt));
        BitConverter.GetBytes((ushort)0x014C).CopyTo(bytes, PeAt + 4);
        BitConverter.GetBytes((ushort)0x0102).CopyTo(bytes, CharacteristicsAt);
        bytes[^1] = 0xAB;
        return bytes;
    }
}
