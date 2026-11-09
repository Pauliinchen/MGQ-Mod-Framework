//----------------------------------------------------------------
//  IniFileTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-11-04: Checked the reading of a file Notepad saved and a write read back in one flow each
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Runtime;

/// <summary>
/// Covers the key=value files: reading any encoding Notepad saves, writing in one step, and a file that cannot be read.
/// </summary>
public sealed class IniFileTests : IDisposable
{
    /// <summary>
    /// A folder of the test's own.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"ini test {Guid.NewGuid():N}");

    /// <summary>
    /// Creates the test's folder.
    /// </summary>
    public IniFileTests() => Directory.CreateDirectory(_folder);

    /// <inheritdoc />
    public void Dispose() => Directory.Delete(_folder, true);

    /// <summary>
    /// Asserts that a byte order mark is skipped, ANSI reads as Latin-1, UTF-16 either way round keeps an emoji and a lone surrogate reads
    /// as U+FFFD, and that the lines are taken as the scripts took them: keys and values lose the spaces around them, a line without "="
    /// is left out, and a key that comes again keeps its place and takes the last value.
    /// </summary>
    [Fact]
    public void Parse_ReadsWhatNotepadSaves()
    {
        Assert.Equal(Pairs(("id", "abc"), ("name", "X")), IniFile.Parse([0xEF, 0xBB, 0xBF, .. "id=abc\r\nname=X\r\n"u8]));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jörg")), IniFile.Parse([.. "id=abc\nname=J"u8, 0xF6, .. "rg\n"u8]));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jö😀")), IniFile.Parse([0xFF, 0xFE, .. Encoding.Unicode.GetBytes("id=abc\r\nname=Jö😀\r\n")]));
        Assert.Equal(Pairs(("id", "abc")), IniFile.Parse([0xFE, 0xFF, .. Encoding.BigEndianUnicode.GetBytes("id=abc\n")]));
        Assert.Equal(Pairs(("n", "�")), IniFile.Parse([0xFF, 0xFE, .. Encoding.Unicode.GetBytes("n="), 0x00, 0xD8]));
        Assert.Equal(Pairs(("a", "1 = 2"), ("b", "3")), IniFile.Parse(" a = 1 = 2 \nno line\nb=x\r\na=1 = 2\nb=3"u8));
    }

    /// <summary>
    /// Asserts that a write saves UTF-8 without a byte order mark, keeps each value on its line and leaves no file next to it, that the
    /// file reads back as written, that a missing file reads as empty and one that exists but cannot be read as nothing, and that a write
    /// that cannot replace its file fails and leaves no file next to it.
    /// </summary>
    [Fact]
    public void WriteThenLoad_ReplacesTheFileInOneStep()
    {
        var path = Path.Combine(_folder, "Player.ini");
        var blocked = Path.Combine(_folder, "Blocked");
        File.WriteAllText(path, "old=1\n");
        Directory.CreateDirectory(blocked);

        Assert.True(IniFile.Write(path, "Player.ini", Pairs(("id", "abc"), ("name", "Jö\r\nrg"))));
        Assert.Equal("id=abc\nname=Jö  rg\n"u8.ToArray(), File.ReadAllBytes(path));
        Assert.False(File.Exists(path + IniFile.TempSuffix));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jö  rg")), IniFile.Load(path, "Player.ini", false));

        Assert.Empty(IniFile.Load(Path.Combine(_folder, "missing.ini"), "missing.ini", false)!);
        Assert.Null(IniFile.Load(blocked, "Blocked", true));
        Assert.False(IniFile.Write(blocked, "Blocked", Pairs(("a", "1"))));
        Assert.True(Directory.Exists(blocked));
        Assert.False(File.Exists(blocked + IniFile.TempSuffix));
    }

    /// <summary>
    /// Lists pairs as a file's values.
    /// </summary>
    /// <param name="pairs">The keys and values.</param>
    /// <returns>The values in order.</returns>
    private static List<KeyValuePair<string, string>> Pairs(params (string Key, string Value)[] pairs) =>
        pairs.Select(pair => new KeyValuePair<string, string>(pair.Key, pair.Value)).ToList();
}
