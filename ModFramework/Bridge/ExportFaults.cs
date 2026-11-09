//----------------------------------------------------------------
//  ExportFaults.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Counted the errors as told only once their line was written
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Threading;

namespace MGQParadox.ModFramework.Bridge;

/// <summary>
/// The errors the exports and the game window's procedure caught, noted without making objects and
/// logged later from an ordinary call, summed.
/// </summary>
/// <remarks>
/// Memory running out may be the error itself, and a catch block that then needs memory throws into
/// the game, which ends it.
/// </remarks>
public static class ExportFaults
{
    /// <summary>
    /// How long the log waits after one line on the caught errors before the next.
    /// </summary>
    private const long LogGapMs = 60_000;

    /// <summary>
    /// How many errors were noted since the DLL started.
    /// </summary>
    private static int _noted;

    /// <summary>
    /// How many of them the log told.
    /// </summary>
    private static int _told;

    /// <summary>
    /// When the log last told of them, in milliseconds of <see cref="Environment.TickCount64"/>; 0 before.
    /// </summary>
    private static long _toldAt;

    /// <summary>
    /// The last error noted.
    /// </summary>
    private static Exception? _last;

    /// <summary>
    /// Where the last error was caught.
    /// </summary>
    private static string? _lastPlace;

    /// <summary>
    /// Gets how many errors were noted since the DLL started.
    /// </summary>
    public static int Noted => Volatile.Read(ref _noted);

    /// <summary>
    /// Notes an error, keeping only the last one and the count.
    /// </summary>
    /// <param name="place">Where it was caught, a constant such as "mf_call".</param>
    /// <param name="exception">The error.</param>
    public static void Note(string place, Exception exception)
    {
        _lastPlace = place;
        _last = exception;
        Interlocked.Increment(ref _noted);
    }

    /// <summary>
    /// Logs the errors noted since the last line, unless that line is less than a minute old; a line
    /// that could not be written leaves them for the next call.
    /// </summary>
    /// <param name="log">The log.</param>
    public static void LogNoted(IBridgeLog log)
    {
        var noted = Volatile.Read(ref _noted);
        var now = Environment.TickCount64;

        if (noted == _told || (_toldAt != 0 && now - _toldAt < LogGapMs))
        {
            return;
        }

        log.Write($"caught {noted - _told} error(s) in the DLL's exports or window procedure, and the game ran on; the last, in {_lastPlace}: {_last}");
        _told = noted;
        _toldAt = now;
    }
}
