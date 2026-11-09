//----------------------------------------------------------------
//  MemoryTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the game's memory.
/// </summary>
internal static class MemoryTopics
{
    /// <summary>
    /// The topic that reads the game's memory now: {"used", "free", "private"} in megabytes, see
    /// <see cref="MemoryReading"/>; nil on JoiPlay or when the system cannot tell.
    /// </summary>
    public const string ReadTopic = "memory.read";

    /// <summary>
    /// The topic the framework's scripts check the memory with every few seconds: as
    /// <see cref="ReadTopic"/>, with "low" true when they should collect and trim now, see
    /// <see cref="MemoryGuard"/>.
    /// </summary>
    public const string CheckTopic = "memory.check";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(ReadTopic, (_, _) => MemoryUsage.Read() is { } reading ? Answer(reading) : (RubyValue)RubyNil.Value);
        context.Register(CheckTopic, (_, _) => Check(MemoryUsage.Read(), MemoryGuard.Live, Environment.TickCount64));
    }

    /// <summary>
    /// Answers a check of the memory.
    /// </summary>
    /// <param name="reading">The reading; <see langword="null"/> when there is none.</param>
    /// <param name="guard">The guard that tells whether it is low.</param>
    /// <param name="now">The time now, in milliseconds of <see cref="Environment.TickCount64"/>.</param>
    /// <returns>The reading with "low"; nil without a reading.</returns>
    internal static RubyValue Check(MemoryReading? reading, MemoryGuard guard, long now)
    {
        if (reading is not { } read)
        {
            return RubyNil.Value;
        }

        var answer = Answer(read);
        answer["low"] = guard.Low(read, now);
        return answer;
    }

    /// <summary>
    /// Writes a reading for the scripts.
    /// </summary>
    /// <param name="reading">The reading.</param>
    /// <returns>{"used", "free", "private"} in megabytes.</returns>
    private static RubyHash Answer(MemoryReading reading) => new()
    {
        { "used", reading.UsedMb },
        { "free", reading.FreeMb },
        { "private", reading.PrivateMb },
    };
}
