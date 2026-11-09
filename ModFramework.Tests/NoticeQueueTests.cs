//----------------------------------------------------------------
//  NoticeQueueTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked the direction a stack grows in as the scripts are told it
//                            - Covered each toast's own seconds on a clock that always runs, the fade upward and the stacks
//                              mods define
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Notices;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the toasts of every mod as the player sees them: each new one of the general stack at the
/// corner with the older moving away, each toast's own seconds on a clock that always runs, the
/// fade out upward while the gap closes, at most five at once with the rest in line, a key that
/// replaces a toast in place, the cap of a stack, the stacks mods define at their own places; and
/// the clock the speech bubbles count by.
/// </summary>
public sealed class NoticeQueueTests
{
    /// <summary>
    /// The frames of a second the test runs, a power of two so the seconds add up exactly.
    /// </summary>
    private const int FramesPerSecond = 64;

    /// <summary>
    /// The height of the toasts' boxes in the test.
    /// </summary>
    private const int Height = 30;

    /// <summary>
    /// The width of the toasts' boxes in the test.
    /// </summary>
    private const int Width = 200;

    /// <summary>
    /// The pixels a toast takes in the stack: its height and the gap after it.
    /// </summary>
    private const int Step = Height + 4;

    /// <summary>
    /// The name of the stack a trap mod defines, as the scripts send it.
    /// </summary>
    private const string Traps = ":my_traps";

    /// <summary>
    /// The events the queue posted, oldest first.
    /// </summary>
    private readonly List<RubyHash> _events = [];

    /// <summary>
    /// The lines the queue logged.
    /// </summary>
    private readonly List<string> _logged = [];

    /// <summary>
    /// The seconds the test's clock tells.
    /// </summary>
    private double _now;

    /// <summary>
    /// Whether the game's window is in front.
    /// </summary>
    private bool _front = true;

    /// <summary>
    /// Asserts the toasts of finding gold, an herb and a party member joining: the first slides in at
    /// the corner and turns whole; each newer one shows at the corner and the older move away from it;
    /// once its second ends the herb's toast fades out over a whole second while it travels up and
    /// the gold's toast closes its gap step by step; a still stack posts nothing; the seconds run on
    /// while the game is in the background and through a long loading frame; and the bubbles' clock
    /// still counts only the game's time in front.
    /// </summary>
    [Fact]
    public void Toasts_StackAwayFromTheCornerAndFadeUpwardOnAClockThatAlwaysRuns()
    {
        const long Gold = 1, Herb = 2, Alice = 3;
        NoticeQueue queue = Queue();
        Tick(queue);
        queue.Add(Toast(Gold, 4000));
        Tick(queue);
        Assert.Equal([(Gold, -(Width + 8), 0, 0)], Shown());
        Run(queue, 0.5);
        Assert.Equal([(Gold, 0, 0, 255)], Shown());

        queue.Add(Toast(Herb, 1000));
        Run(queue, 0.5);
        queue.Add(Toast(Alice, 6000));
        Run(queue, 0.5);
        Assert.Equal([(Gold, 2 * Step), (Herb, Step), (Alice, 0)], Places());

        var gold = new List<int>();
        var herb = new List<int>();
        Run(queue, 0.5, () =>
        {
            gold.Add(Places().First(place => place.Id == Gold).Y);
            herb.Add(Places().First(place => place.Id == Herb).Y);
        });
        var half = Shown().Single(row => row.Id == Herb);
        Assert.True(half.Opacity is > 96 and < 160 && half.Y is > 8 and < Step - 8 && herb.SequenceEqual(herb.OrderDescending()),
                    $"half way through its fade the herb's toast shows half and travelled up: {half}, {string.Join(", ", herb)}");
        Assert.InRange(gold[^1], Step + 8, 2 * Step - 8);
        Run(queue, 0.75, () => gold.Add(Places().First(place => place.Id == Gold).Y));
        Assert.Contains(Herb, _events.SelectMany(each => each["gone"].AsArray().Select(id => id.AsLong())));
        Assert.Equal([(Gold, Step), (Alice, 0)], Places());
        List<int> closing = [.. gold.Distinct()];
        Assert.True(closing.Count > 4 && closing.First() == 2 * Step && closing.Last() == Step && closing.SequenceEqual(closing.OrderByDescending(each => each)),
                    $"the gap closes step by step: {string.Join(", ", closing)}");

        int posted = _events.Count;
        Run(queue, 0.25);
        Assert.Equal(posted, _events.Count);

        _front = false;
        Run(queue, 2.25);
        Assert.Equal([(Alice, 0)], Places());
        Assert.Contains(Gold, _events.SelectMany(each => each["gone"].AsArray().Select(id => id.AsLong())));
        _front = true;
        _now += 5;
        Tick(queue);
        Assert.Empty(Shown());
        Assert.Equal([Alice], Gone());

        long start = queue.Clock().AsLong();
        _now += 0.05;
        long next = queue.Clock().AsLong();
        Assert.Equal(50, next - start);
        _front = false;
        _now += 10;
        Assert.Equal(next, queue.Clock().AsLong());
        _front = true;
        _now += 10;
        Assert.Equal(next + 100, queue.Clock().AsLong());
    }

    /// <summary>
    /// Asserts a burst of six toasts: five show and the sixth waits in line; a newer toast with the
    /// key of a shown one takes its place at once, whole; a waiting toast ended by its key never
    /// shows; once a shown toast of a dropped group faded out, the sixth slides in at the corner,
    /// and its own second starts only then, though it waited for longer.
    /// </summary>
    [Fact]
    public void SixthToast_WaitsUntilOneEndsAndStartsItsTimeWhenItShows()
    {
        NoticeQueue queue = Queue();
        for (long id = 1; id <= 6; id++)
        {
            queue.Add(Toast(id, id == 6 ? 1000 : 60000, key: id == 3 ? ":encounter" : id == 6 ? ":saved" : null, group: id == 2 ? ":cave" : null));
        }

        Run(queue, 0.5);
        Assert.Equal([(1L, 4 * Step), (2L, 3 * Step), (3L, 2 * Step), (4L, Step), (5L, 0)], Places());

        queue.Add(Toast(7, 60000, key: ":encounter"));
        Tick(queue);
        Assert.Equal([(1L, 0, 4 * Step, 255), (2L, 0, 3 * Step, 255), (7L, 0, 2 * Step, 255), (4L, 0, Step, 255), (5L, 0, 0, 255)], Shown());
        Assert.Equal([3L], Gone());

        queue.Add(Toast(8, 60000, key: ":gems"));
        Assert.True(queue.Drop(":gems").AsBool());
        Tick(queue);
        Assert.Equal([8L], Gone());

        Assert.Equal(1, queue.DropGroup(":cave").AsInt());
        Run(queue, 0.25);
        Assert.Equal([1L, 2L, 7L, 4L, 5L], Places().Select(place => place.Id));
        Run(queue, 1.0);
        Assert.Equal([(1L, 4 * Step), (7L, 3 * Step), (4L, 2 * Step), (5L, Step), (6L, 0)], Places());
        Run(queue, 0.5);
        Assert.Equal((6L, 0, 0, 255), Shown().Single(row => row.Id == 6));
        Run(queue, 1.5);
        Assert.DoesNotContain(6L, Places().Select(place => place.Id));
    }

    /// <summary>
    /// Asserts that a stack past its 32 toasts drops the oldest waiting one and says so in the log
    /// at most once a minute, never per frame.
    /// </summary>
    [Fact]
    public void FullStack_DropsTheOldestWaitingAndLogsOnceAMinute()
    {
        NoticeQueue queue = Queue();
        for (long id = 0; id < NoticeQueue.Most + 2; id++)
        {
            queue.Add(Toast(id, 600000));
        }

        Tick(queue);
        Assert.Equal([2L, 3L, 4L, 5L, 6L], Places().Select(place => place.Id));
        Assert.Equal([0L, 1L], Gone());
        Assert.Equal(["notices: a toast stack was full, so the oldest 2 waiting toasts were dropped"], _logged);

        queue.Add(Toast(34, 600000));
        Run(queue, 30);
        Assert.Single(_logged);
        Run(queue, 31);
        Assert.Equal("notices: a toast stack was full, so the oldest 1 waiting toast was dropped", _logged[^1]);
    }

    /// <summary>
    /// Asserts a trap mod's own stack at a spot, sliding in from the top, growing up with the newest
    /// on top, two at most and 1.5 seconds each: the scripts are told it grows up, its toasts lie
    /// at its spot whatever the general stack shows, the third waits and starts its time when it
    /// shows, a call's own seconds win, and the first fades out travelling up while the second
    /// moves down into its place. The general stack moved to the bottom right slides its toasts in
    /// from the right and grows up.
    /// Bad options keep their defaults and a toast into a stack nobody defined is refused, each
    /// logged.
    /// </summary>
    [Fact]
    public void NamedStack_LiesWhereItsModPutsItWithItsOwnRules()
    {
        const long Spikes = 1, Darts = 2, Pit = 3, Gold = 9;
        NoticeQueue queue = Queue();
        RubyValue placed = queue.Define([Traps, Options(("at", new RubyArray { 200, 40 }), ("slide_from", "top"), ("grows", "up"), ("most_shown", 2), ("seconds", "1.5"),
                                                        ("newest_on_top", true))]);
        Assert.Equal(new RubyHash { ["corner"] = RubyNil.Value, ["at"] = new RubyArray { 200, 40 }, ["grows"] = "up" }, placed);
        Assert.Equal(["notices: toast stack :my_traps defined: at 200, 40, sliding in from the top, growing up, 2 at most, 1.5 s each, the newest on top"], _logged);

        Assert.Equal(500, queue.Add(Toast(Spikes, 500, stack: Traps)).AsLong());
        Assert.Equal(4000, queue.Add(Toast(Darts, 4000, stack: Traps)).AsLong());
        Assert.Equal(1500, queue.Add(Toast(Pit, null, stack: Traps)).AsLong());
        queue.Add(Toast(Gold, 60000));
        Tick(queue);
        Assert.Equal((Spikes, 0, -(Height + 8), 0), Shown().First());
        Run(queue, 0.25);
        Assert.Equal([(Spikes, 0, 0, 255), (Darts, 0, -Step, 255), (Gold, 0, 0, 255)], Shown());

        var spikes = new List<(int Y, int Opacity)>();
        var darts = new List<int>();
        Run(queue, 1.25, () =>
        {
            var row = Shown().FirstOrDefault(each => each.Id == Spikes);
            if (row.Id == Spikes)
            {
                spikes.Add((row.Y, row.Opacity));
                darts.Add(Shown().Single(each => each.Id == Darts).Y);
            }
        });
        Assert.True(spikes.Count > 20 && spikes.Last().Y < -Step / 2 && spikes.Last().Opacity < 32 && spikes.Select(each => each.Y).SequenceEqual(spikes.Select(each => each.Y).OrderDescending()),
                    $"the spikes' toast travels up as it fades: {string.Join(", ", spikes)}");
        Assert.True(darts.First() == -Step && darts.Last() > -8 && darts.SequenceEqual(darts.Order()), $"the darts' toast moves down into its place: {string.Join(", ", darts)}");

        Run(queue, 0.25);
        Assert.Equal([(Darts, 0, 0, 255), (Pit, 0, -Step, 255), (Gold, 0, 0, 255)], Shown());
        Run(queue, 1.0);
        Assert.Equal((Pit, 0, -Step, 255), Shown().Single(row => row.Id == Pit));
        Run(queue, 1.5);
        Assert.DoesNotContain(Pit, Shown().Select(row => row.Id));

        Assert.Equal(new RubyHash { ["corner"] = "bottom_right", ["at"] = RubyNil.Value, ["grows"] = "up" }, queue.Define([RubyNil.Value, Options(("corner", "bottom_right"))]));
        queue.Add(Toast(10, 60000));
        Tick(queue);
        Assert.Equal((10L, Width + 8, 0, 0), Shown().Single(row => row.Id == 10));
        Run(queue, 0.25);
        Assert.Equal((Gold, 0, -Step, 255), Shown().Single(row => row.Id == Gold));

        _logged.Clear();
        queue.Define([":my_darts", Options(("corner", "middle"), ("grows", "sideways"), ("most_shown", 0), ("seconds", "soon"), ("colour", "red"))]);
        Assert.True(queue.Add(Toast(11, 1000, stack: ":my_dart")).IsNil);
        Assert.Equal(["notices: toast stack :my_darts was given the option colour, which no toast stack knows, so it does nothing",
                      "notices: toast stack :my_darts refused corner: \"middle\", which is not top_left, top_right, bottom_left or bottom_right, so it keeps its default",
                      "notices: toast stack :my_darts refused grows: \"sideways\", which is not up or down, so it keeps its default",
                      "notices: toast stack :my_darts refused most_shown: 0, which is not a whole number from 1 to 32, so it keeps its default",
                      "notices: toast stack :my_darts refused seconds: \"soon\", which is not a number above 0, so it keeps its default",
                      "notices: toast stack :my_darts defined: at the top left, sliding in from the left, growing down, 5 at most, 3 s each, the newest on top",
                      "notices: toast 11 was refused: no mod defined the toast stack :my_dart"], _logged);
    }

    /// <summary>
    /// Makes a queue timed by the test's clock that logs and posts into the test.
    /// </summary>
    /// <returns>The queue.</returns>
    private NoticeQueue Queue() => new(() => _now, () => _front, _logged.Add, (_, payload) => _events.Add(payload.AsHash()));

    /// <summary>
    /// Writes a toast as the scripts queue it.
    /// </summary>
    /// <param name="id">The scripts' id of it.</param>
    /// <param name="milliseconds">How long it shows, null for its stack's seconds.</param>
    /// <param name="key">Its key, null for none.</param>
    /// <param name="group">Its group, null for none.</param>
    /// <param name="stack">Its stack's name, null for the general stack.</param>
    /// <returns>[id, milliseconds, key, group, width, height, stack].</returns>
    private static RubyArray Toast(long id, int? milliseconds, string? key = null, string? group = null, string? stack = null) =>
        [id, milliseconds is int some ? (RubyValue)some : RubyNil.Value, key, group, Width, Height, stack];

    /// <summary>
    /// Writes a stack's options as the scripts send them.
    /// </summary>
    /// <param name="options">Each option's name and value.</param>
    /// <returns>The options.</returns>
    private static RubyHash Options(params (string Name, RubyValue Value)[] options)
    {
        var hash = new RubyHash();
        foreach ((string name, RubyValue value) in options)
        {
            hash[name] = value;
        }

        return hash;
    }

    /// <summary>
    /// Ticks the queue once, as the scripts do every frame while it holds toasts.
    /// </summary>
    /// <param name="queue">The queue.</param>
    private static void Tick(NoticeQueue queue) => queue.Tick(RubyNil.Value);

    /// <summary>
    /// Runs the queue's ticks for some seconds.
    /// </summary>
    /// <param name="queue">The queue.</param>
    /// <param name="seconds">The seconds.</param>
    /// <param name="each">Runs after each tick, null for nothing.</param>
    private void Run(NoticeQueue queue, double seconds, Action? each = null)
    {
        for (int frame = 0; frame < (int)Math.Round(seconds * FramesPerSecond); frame++)
        {
            _now += 1.0 / FramesPerSecond;
            Tick(queue);
            each?.Invoke();
        }
    }

    /// <summary>
    /// Reads the toasts the last event showed.
    /// </summary>
    /// <returns>Each [id, x, y, opacity], oldest first.</returns>
    private List<(long Id, int X, int Y, int Opacity)> Shown() =>
        [.. _events[^1]["shown"].AsArray().Select(row => row.AsArray()).Select(row => (row[0].AsLong(), row[1].AsInt(), row[2].AsInt(), row[3].AsInt()))];

    /// <summary>
    /// Reads where the toasts the last event showed lie along a stack that grows down.
    /// </summary>
    /// <returns>Each id and its pixels below its stack's start, oldest first.</returns>
    private List<(long Id, int Y)> Places() => [.. Shown().Select(row => (row.Id, row.Y))];

    /// <summary>
    /// Reads the toasts the last event told gone.
    /// </summary>
    /// <returns>Their ids.</returns>
    private List<long> Gone() => [.. _events[^1]["gone"].AsArray().Select(id => id.AsLong())];
}
