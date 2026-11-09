//----------------------------------------------------------------
//  LogTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//                            - Checked that only the framework's logs of other days go
//                            - Took a line of the framework as the scripts' line
//      Paulinchen  2026-11-04: Checked the lines repeated in one flow and the logs of other days and a log cut down in another
//                            - Checked the lines and the scripts' line in one test and other mods' logs among the kept ones
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Checked that two mods' logs never count as each other's
//      Paulinchen  2026-10-23: Checked a flood told while it goes on, the scripts' lines and the logs of earlier days deleted
//      Paulinchen  2026-10-15: Checked the log named after the day the game started on
//      Paulinchen  2026-10-11: Checked cutting a log down to its newest lines
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Runtime;

/// <summary>
/// Covers the log: the lines written by the DLL and the scripts through the writer thread, the lines repeated, and the logs kept small:
/// only the day's log of each mod, cut down to its newest lines.
/// </summary>
public sealed class LogTests
{
    /// <summary>
    /// Asserts that a line repeated is counted and the count written once another line follows, and that a line that keeps repeating
    /// says so while it goes on, and how often in all when the game closes.
    /// </summary>
    [Fact]
    public void Repeats_CountALineRepeatedAndTellAFloodWhileItGoesOn()
    {
        var repeats = new Log.Repeats();

        Assert.Equal("10:00:00  first\r\n", repeats.Take("10:00:00", "first"));
        Assert.Null(repeats.Take("10:00:01", "first"));
        Assert.Null(repeats.Take("10:00:02", "first"));
        Assert.Equal("10:00:03  (the line above repeated 2 times in all)\r\n10:00:03  second\r\n", repeats.Take("10:00:03", "second"));
        Assert.Null(repeats.Take("10:00:04", "second"));
        Assert.Equal("10:00:05  (the line above repeated 1 time in all)\r\n10:00:05  flood\r\n", repeats.Take("10:00:05", "flood"));

        var told = Enumerable.Range(1, 11).Select(_ => repeats.Take("10:00:06", "flood")).Where(text => text is not null).ToList();

        Assert.Equal(["10:00:06  (the line above repeated 10 times so far)\r\n"], told);
        Assert.Equal("10:00:07  (the line above repeated 11 times in all)\r\n", repeats.Finish("10:00:07"));
        Assert.Null(repeats.Finish("10:00:08"));
    }

    /// <summary>
    /// Asserts that lines written and a line the scripts hand over are in the file once flushed, in the order they were written,
    /// the scripts' line marked as theirs with the time they wrote it at and its bytes read as UTF-8.
    /// </summary>
    /// <remarks>
    /// Other tests log meanwhile, so a line of theirs may land between two of these.
    /// </remarks>
    [Fact]
    public void WriteAndScriptLog_PutTheLinesInTheFileInOrder()
    {
        var mark = Guid.NewGuid().ToString("N");
        var first = $"log test {mark} first";
        var second = $"log test {mark} second";
        var bytes = Encoding.UTF8.GetBytes($"mods: loaded {mark} ルカ").Concat(new byte[] { 0xFF }).ToArray();

        Log.Write(first);
        Log.Write(second);
        ScriptLog.Write(new RubyArray([RubyString.Utf8("01:02:03"), RubyString.Binary(bytes)]));
        Log.Flush();

        var text = ReadLog();
        var atFirst = text.IndexOf(first, StringComparison.Ordinal);
        var atSecond = text.IndexOf(second, StringComparison.Ordinal);
        var atScript = text.IndexOf($"01:02:03  [script] mods: loaded {mark} ルカ�\r\n", StringComparison.Ordinal);

        Assert.True(atFirst >= 0, "the first line is missing");
        Assert.True(atSecond > atFirst, "the second line does not follow the first");
        Assert.True(atScript > atSecond, "the scripts' line does not follow the second");
        Assert.Throws<BridgeRequestException>(() => ScriptLog.Write(new RubyArray([RubyString.Utf8("01:02:03")])));
    }

    /// <summary>
    /// Asserts that every day's log of the framework but the one named after the day the game started on goes, while its boot log and
    /// other mods' logs of any day stay and a folder of a log's name counts as one that could not be deleted, and that the day's log
    /// cut down keeps its newest lines from a whole line on, behind the line that says so.
    /// </summary>
    [Fact]
    public void Logs_KeepOnlyTheDaysLogAndItsNewestLines()
    {
        var folder = Path.Combine(Path.GetTempPath(), $"log test {Guid.NewGuid():N}");
        Directory.CreateDirectory(folder);

        try
        {
            var day = Path.GetFileName(Log.FileNameOf(new DateTime(2026, 10, 7, 8, 5, 9)));
            string[] kept = [day, "Mod Framework boot.log", "Camp Notes 2026-01-01.log", "Mod Framework Extras 2026-01-01.log"];
            string[] gone = ["Mod Framework 2026-01-01.log", "Mod Framework 2026-10-06.log"];

            foreach (var name in kept.Concat(gone))
            {
                File.WriteAllText(Path.Combine(folder, name), "x");
            }

            Directory.CreateDirectory(Path.Combine(folder, "Mod Framework 2026-01-02.log"));

            Assert.Equal("Mod Framework 2026-10-07.log", day);
            Assert.Equal((gone.Length, 1), Log.DeleteOtherDays(folder, "2026-10-07"));
            Assert.Equal(kept.Append("Mod Framework 2026-01-02.log").Order(StringComparer.Ordinal), Directory.EnumerateFileSystemEntries(folder).Select(Path.GetFileName).Order(StringComparer.Ordinal));

            var path = Path.Combine(folder, day);
            File.WriteAllText(path, string.Concat(Enumerable.Range(0, 1000).Select(index => $"12:00:00.000  line {index}\r\n")));
            Log.CutToNewest(path, 100);

            var lines = File.ReadAllLines(path);
            Assert.Equal(Log.CutLine, lines[0]);
            Assert.Equal("12:00:00.000  line 999", lines[^1]);
            Assert.All(lines[1..], line => Assert.StartsWith("12:00:00.000  line ", line));
            Assert.True(lines.Length is > 2 and < 6, $"kept {lines.Length - 1} lines of about 25 bytes from 100 bytes");
        }
        finally
        {
            Directory.Delete(folder, true);
        }
    }

    /// <summary>
    /// Reads the log file while the writer thread may still append to it.
    /// </summary>
    /// <returns>The log's text.</returns>
    private static string ReadLog()
    {
        using var file = new FileStream(Log.FilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var reader = new StreamReader(file, Encoding.UTF8);
        return reader.ReadToEnd();
    }
}
