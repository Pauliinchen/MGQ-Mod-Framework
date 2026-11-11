//----------------------------------------------------------------
//  MemoryUsageTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-10: Checked that the memory status reads the address space as the walk over its regions does
//      Paulinchen  2026-11-09: Checked that a trim that freed little doubles the gap until the free space is back at the floor
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Topics;

namespace MGQParadox.ModFramework.Tests.Runtime;

/// <summary>
/// Covers the reading of the game's memory and when it counts as low.
/// </summary>
public sealed class MemoryUsageTests
{
    /// <summary>
    /// Asserts that the reading of this 32-bit process sums its address space to at most 4 GB with
    /// some of it used and some free; that a check answers the reading with whether it is low: never
    /// at the floor, below it once, again only after a gap that a trim freeing nothing doubled, and
    /// after the first gap again once the free space was back at the floor; and that no reading
    /// answers nil.
    /// </summary>
    [Fact]
    public void Check_LowBelowTheFloorOncePerGap()
    {
        var reading = MemoryUsage.Read()!.Value;
        var guard = new MemoryGuard();
        var atFloor = new MemoryReading(1200, MemoryGuard.FloorMb, 900);
        var below = new MemoryReading(1750, MemoryGuard.FloorMb - 1, 1100);
        bool LowAt(MemoryReading checkedReading, long now) => MemoryTopics.Check(checkedReading, guard, now).AsHash()["low"].AsBool();

        Assert.InRange(reading.UsedMb + reading.FreeMb, 1024, 4096);
        Assert.True(reading.UsedMb > 0 && reading.FreeMb > 0 && reading.PrivateMb > 0);
        Assert.False(LowAt(atFloor, 1_000));
        const long Gap = MemoryGuard.ActGapMs;
        Assert.Equal([true, false, false, true], new[] { 2_000, 2_000 + Gap - 1, 2_000 + Gap, 2_000 + (2 * Gap) }.Select(now => LowAt(below, now)));
        Assert.False(LowAt(atFloor, 2_000 + (2 * Gap) + 1));
        Assert.True(LowAt(below, 2_000 + (3 * Gap)));

        var answer = MemoryTopics.Check(below, new MemoryGuard(), 0).AsHash();

        Assert.Equal([1750, 299, 1100], new[] { "used", "free", "private" }.Select(key => answer[key].AsInt()));
        Assert.True(MemoryTopics.Check(null, guard, 0).IsNil);
    }

    /// <summary>
    /// Asserts that the system's memory status reads the address space used and free as the walk
    /// over its regions does, within what the test host allocates meanwhile.
    /// </summary>
    [Fact]
    public void Status_MatchesTheWalk()
    {
        const ulong Slack = 16 * 1024 * 1024;
        var walked = MemoryUsage.Walk()!.Value;
        var status = MemoryUsage.Status()!.Value;

        Assert.InRange(status.Free, walked.Free - Slack, walked.Free + Slack);
        Assert.InRange(status.Used + status.Free, walked.Used + walked.Free - Slack, walked.Used + walked.Free + Slack);
    }
}
