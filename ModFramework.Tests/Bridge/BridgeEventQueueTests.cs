//----------------------------------------------------------------
//  BridgeEventQueueTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//                            - Took the framework's topics as the examples
//      Paulinchen  2026-11-04: Checked the order, the status topics, the overflow and a refused payload in one flow
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Tests.Bridge;

/// <summary>
/// Covers the event queue and the drain: order, status topics, the overflow, and a drain parked
/// when it does not fit the caller's buffer.
/// </summary>
public sealed class BridgeEventQueueTests
{
    /// <summary>
    /// The log the context under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The context under test, keeping at most 3 message events, with "mods.installing" a status topic.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// Creates the context under test.
    /// </summary>
    public BridgeEventQueueTests()
    {
        _context = new BridgeContext(1, _log, eventLimit: 3);
        _context.Events.Coalesce("mods.installing");
    }

    /// <summary>
    /// Asserts that events come in order and a status topic only with its latest event, at its
    /// place, that past the limit the oldest message events are dropped while status events are kept
    /// and the overflow is logged once, and that a payload that cannot cross is refused when posted.
    /// </summary>
    [Fact]
    public void Post_KeepsTheOrderTheLatestStatusAndTheNewestMessages()
    {
        _context.Events.Post("mods.installing", "started");
        _context.Events.Post("ui.edit", "typed");
        _context.Events.Post("mods.installing", "done");

        Assert.Equal(["ui.edit typed", "mods.installing done"], Drain());
        Assert.Empty(Drain());

        _context.Events.Post("mods.installing", "done");
        foreach (string text in new[] { "a", "b", "c", "d", "e" })
        {
            _context.Events.Post("ui.edit", text);
        }

        Assert.Equal(2, _context.Events.Dropped);
        Assert.Single(_log.Lines, line => line.Contains("drops the oldest", StringComparison.Ordinal));
        Assert.Equal(["mods.installing done", "ui.edit c", "ui.edit d", "ui.edit e"], Drain());
        Assert.Throws<ArgumentException>(() => _context.Events.Post("ui.edit", new RubyHash { { new RubyArray { 1 }, "one" } }));
    }

    /// <summary>
    /// Asserts that a drain too large for the buffer is parked and handed out by the next drain, which
    /// runs the frame steps no second time and keeps newer events for the drain after.
    /// </summary>
    [Fact]
    public void Drain_ParksEventsThatDoNotFitAndRunsTheFrameStepsOnce()
    {
        int steps = 0;
        _context.EveryFrame(context =>
        {
            steps++;
            context.Events.Post("ui.input", context.Frame);
        });
        _context.Events.Post("ui.edit", new string('x', 500));

        int needed = -_context.Drain(60, new byte[16]);
        _context.Events.Post("ui.edit", "later");
        byte[] buffer = new byte[needed];
        int written = _context.Drain(60, buffer);

        Assert.Equal(needed, written);
        Assert.Equal(new[] { "ui.edit", "ui.input" }, RubyMarshal.Read(buffer).AsArray().Select(pair => pair.AsArray()[0].AsText()));
        Assert.Equal(1, steps);
        Assert.Equal(60, _context.Frame);
        Assert.Equal(new[] { "ui.edit later", "ui.input 61" }, Drain(61));
    }

    /// <summary>
    /// Drains with a large buffer.
    /// </summary>
    /// <param name="frame">The frame passed.</param>
    /// <returns>Each event as "topic payload".</returns>
    private string[] Drain(long frame = 0)
    {
        byte[] buffer = new byte[4096];
        int written = _context.Drain(frame, buffer);
        return written == 0
            ? []
            : RubyMarshal.Read(buffer.AsSpan(0, written)).AsArray()
                .Select(pair => pair.AsArray()[0].AsText() + " " + Text(pair.AsArray()[1]))
                .ToArray();
    }

    /// <summary>
    /// Shows a payload in a test's expectation.
    /// </summary>
    /// <param name="payload">A String or Integer.</param>
    /// <returns>Its text.</returns>
    private static string Text(RubyValue payload) => payload is RubyString ? payload.AsText() : payload.ToString()!;
}
