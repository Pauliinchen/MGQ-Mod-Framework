//----------------------------------------------------------------
//  MemoryUsage.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Waited longer between trims that free little, and logged how long the first read took
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// The game's memory: the address space it uses and has free, and its private bytes.
/// </summary>
/// <remarks>
/// The free address space is summed over every free region, since the largest free block alone
/// stays high long after the game ran short.
/// </remarks>
public static unsafe partial class MemoryUsage
{
    /// <summary>
    /// Bytes in a megabyte.
    /// </summary>
    private const ulong Megabyte = 1024 * 1024;

    /// <summary>
    /// The handle that stands for the calling process.
    /// </summary>
    private const nint CurrentProcess = -1;

    /// <summary>
    /// The state VirtualQuery gives a free region of the address space.
    /// </summary>
    private const uint MemoryFree = 0x10000;

    /// <summary>
    /// The lowest address a region of the address space may start at.
    /// </summary>
    private const ulong LowestAddress = 0x10000;

    /// <summary>
    /// 1 once the time of a walk over the address space was logged.
    /// </summary>
    private static int _walkTimed;

    /// <summary>
    /// Reads the game's memory now, which walks every region of its address space, a few
    /// milliseconds.
    /// </summary>
    /// <returns>The reading; <see langword="null"/> on JoiPlay or when the system cannot tell.</returns>
    public static MemoryReading? Read()
    {
        if (Platforms.Current == GamePlatform.JoiPlay)
        {
            return null;
        }

        try
        {
            var started = Stopwatch.GetTimestamp();

            if (Walk() is not { } space)
            {
                return null;
            }

            if (Interlocked.Exchange(ref _walkTimed, 1) == 0)
            {
                Log.Write($"reading the game's memory took {Stopwatch.GetElapsedTime(started).TotalMilliseconds:0.0} ms");
            }

            var counters = new ProcessMemoryCounters { Size = (uint)sizeof(ProcessMemoryCounters) };
            var privateBytes = K32GetProcessMemoryInfo(CurrentProcess, &counters, counters.Size) ? (ulong)counters.PrivateUsage : 0;
            return new MemoryReading((long)(space.Used / Megabyte), (long)(space.Free / Megabyte), (long)(privateBytes / Megabyte));
        }
        catch (Exception ex)
        {
            Log.Write($"could not read the game's memory: {ex.GetType().Name}: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Sums the regions of the address space that are free and those that are not.
    /// </summary>
    /// <returns>The bytes used and free; <see langword="null"/> when no region could be read.</returns>
    private static (ulong Used, ulong Free)? Walk()
    {
        var info = new MemoryBasicInformation();
        var size = (nuint)sizeof(MemoryBasicInformation);
        ulong address = LowestAddress;
        ulong used = 0;
        ulong free = 0;
        var read = false;

        while (address <= nuint.MaxValue && VirtualQuery((nuint)address, &info, size) != 0)
        {
            read = true;

            if (info.State == MemoryFree)
            {
                free += info.RegionSize;
            }
            else
            {
                used += info.RegionSize;
            }

            var next = (ulong)info.BaseAddress + info.RegionSize;

            if (next <= address)
            {
                break;
            }

            address = next;
        }

        return read ? (used, free) : null;
    }

    /// <summary>
    /// Reads the memory counters of a process.
    /// </summary>
    /// <param name="process">The process.</param>
    /// <param name="counters">Receives the counters.</param>
    /// <param name="size">The counters' size in bytes.</param>
    /// <returns><see langword="true"/> when they were read.</returns>
    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool K32GetProcessMemoryInfo(nint process, ProcessMemoryCounters* counters, uint size);

    /// <summary>
    /// Reads the region of the address space an address lies in.
    /// </summary>
    /// <param name="address">The address.</param>
    /// <param name="info">Receives the region.</param>
    /// <param name="length">The size of <paramref name="info"/> in bytes.</param>
    /// <returns>The bytes written into <paramref name="info"/>, 0 past the last region.</returns>
    [LibraryImport("kernel32.dll")]
    private static partial nuint VirtualQuery(nuint address, MemoryBasicInformation* info, nuint length);

    /// <summary>
    /// PROCESS_MEMORY_COUNTERS_EX: a process's memory.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessMemoryCounters
    {
        /// <summary>The structure's size in bytes.</summary>
        public uint Size;

        /// <summary>The page faults.</summary>
        public uint PageFaultCount;

        /// <summary>The largest working set.</summary>
        public nuint PeakWorkingSetSize;

        /// <summary>The working set.</summary>
        public nuint WorkingSetSize;

        /// <summary>The largest paged pool.</summary>
        public nuint QuotaPeakPagedPoolUsage;

        /// <summary>The paged pool.</summary>
        public nuint QuotaPagedPoolUsage;

        /// <summary>The largest nonpaged pool.</summary>
        public nuint QuotaPeakNonPagedPoolUsage;

        /// <summary>The nonpaged pool.</summary>
        public nuint QuotaNonPagedPoolUsage;

        /// <summary>The committed memory.</summary>
        public nuint PagefileUsage;

        /// <summary>The largest committed memory.</summary>
        public nuint PeakPagefileUsage;

        /// <summary>The private bytes.</summary>
        public nuint PrivateUsage;
    }

    /// <summary>
    /// MEMORY_BASIC_INFORMATION: a region of the address space.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryBasicInformation
    {
        /// <summary>Where the region starts.</summary>
        public nuint BaseAddress;

        /// <summary>Where the allocation the region belongs to starts.</summary>
        public nuint AllocationBase;

        /// <summary>The protection the allocation was made with.</summary>
        public uint AllocationProtect;

        /// <summary>The region's size in bytes.</summary>
        public nuint RegionSize;

        /// <summary>Whether the region is committed, reserved or free.</summary>
        public uint State;

        /// <summary>The region's protection.</summary>
        public uint Protect;

        /// <summary>The kind of its pages.</summary>
        public uint Type;
    }
}

/// <summary>
/// The game's memory at one moment, in megabytes.
/// </summary>
/// <param name="UsedMb">The address space in use, reserved or committed.</param>
/// <param name="FreeMb">The address space free, summed over every free region.</param>
/// <param name="PrivateMb">The private bytes committed; 0 when the system cannot tell.</param>
public readonly record struct MemoryReading(long UsedMb, long FreeMb, long PrivateMb);

/// <summary>
/// Tells when the game runs low on memory: its free address space below <see cref="FloorMb"/>,
/// at most once every <see cref="ActGapMs"/>, so a game that stays low is not collected on every
/// check; each trim that freed less than <see cref="LittleFreedMb"/> doubles that gap up to
/// <see cref="LongestGapMs"/>, until a trim frees more or the free space is back at the floor.
/// </summary>
/// <remarks>A collection of a late-game heap stalls the game for a moment, which is wasted while it frees nothing.</remarks>
public sealed class MemoryGuard
{
    /// <summary>
    /// The free address space below which the game runs low.
    /// </summary>
    /// <remarks>
    /// RGSS ends the game without a word once a picture finds no room, and a screen change makes
    /// pictures of up to a hundred megabytes at once, so the floor leaves room for a few such changes.
    /// </remarks>
    public const long FloorMb = 300;

    /// <summary>
    /// The milliseconds after a low reading in which another low reading starts nothing.
    /// </summary>
    public const long ActGapMs = 20_000;

    /// <summary>
    /// The megabytes of address space below which a trim freed little.
    /// </summary>
    public const long LittleFreedMb = 50;

    /// <summary>
    /// The longest gap between two trims, in milliseconds.
    /// </summary>
    public const long LongestGapMs = 300_000;

    /// <summary>
    /// When a low reading last started the trim, in milliseconds of <see cref="Environment.TickCount64"/>; null before the first.
    /// </summary>
    private long? _actedAt;

    /// <summary>
    /// The milliseconds after a trim in which another low reading starts nothing.
    /// </summary>
    private long _gapMs = ActGapMs;

    /// <summary>
    /// The free address space of the reading that started the last trim, until the next reading tells what it freed.
    /// </summary>
    private long? _freeBeforeTrim;

    /// <summary>
    /// Gets the guard of the game session.
    /// </summary>
    public static MemoryGuard Live { get; } = new();

    /// <summary>
    /// Tells whether a reading asks for a collection and a trim now.
    /// </summary>
    /// <param name="reading">The reading.</param>
    /// <param name="now">The time now, in milliseconds of <see cref="Environment.TickCount64"/>.</param>
    /// <returns>Whether the free address space is below the floor and no trim started within the gap.</returns>
    public bool Low(MemoryReading reading, long now)
    {
        if (_freeBeforeTrim is { } before)
        {
            _freeBeforeTrim = null;
            var freed = reading.FreeMb - before;
            SetGap(freed < LittleFreedMb ? Math.Min(_gapMs * 2, LongestGapMs) : ActGapMs, $"the last trim freed {freed} MB of address space");
        }

        if (reading.FreeMb >= FloorMb)
        {
            SetGap(ActGapMs, $"{reading.FreeMb} MB of address space are free again");
            return false;
        }

        if (_actedAt is { } acted && now - acted < _gapMs)
        {
            return false;
        }

        _actedAt = now;
        _freeBeforeTrim = reading.FreeMb;
        return true;
    }

    /// <summary>
    /// Sets the gap between two trims, logging a change.
    /// </summary>
    /// <param name="gapMs">The gap in milliseconds.</param>
    /// <param name="why">What changed it, for the log.</param>
    private void SetGap(long gapMs, string why)
    {
        if (gapMs != _gapMs)
        {
            _gapMs = gapMs;
            Log.Write($"{why}, so the next trim waits at least {gapMs / 1000} s");
        }
    }
}
