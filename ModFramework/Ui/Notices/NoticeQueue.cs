//----------------------------------------------------------------
//  NoticeQueue.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Gave each toast its own seconds from the moment it shows on a clock that always runs
//                            - Faded an ending toast out while it travels up the screen
//                            - Kept the toasts of the stacks mods define, each by its own rules
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Notices;

/// <summary>
/// The toasts of every mod, each a small box: those of the general stack in the corner the player
/// picks, and those of the stacks mods define at a corner or a spot of their own. Queued from
/// anywhere, an event's Script command too; each stack shows at most its most toasts at once and
/// the rest wait in line. A new toast slides in, the others make room for it, and once its own
/// seconds since it showed end it fades out while it travels up the screen, the others closing its
/// gap. The seconds run on the wall clock, also while the toasts hide or the game is in the
/// background. Also the clock the speech bubbles count their seconds by.
/// </summary>
internal sealed class NoticeQueue : IUiModel
{
    /// <summary>
    /// The model's name in the tick; it ticks while the scripts hold toasts, and its input is not read.
    /// </summary>
    public const string ModelName = "notices";

    /// <summary>
    /// The topic that queues a toast: [id, milliseconds, key, group, width, height, stack]; id is
    /// the scripts' own, milliseconds nil for its stack's seconds, key, group and stack texts or
    /// nil (nil stack: the general one), width and height the toast's box in pixels. Answers the
    /// milliseconds it shows, nil when refused.
    /// </summary>
    public const string ToastTopic = "notices.toast";

    /// <summary>
    /// The topic that defines a stack: [name, options], name nil for the general stack, see
    /// <see cref="ToastStack.Read"/>. Answers where the stack lies, see <see cref="ToastStack.Placement"/>.
    /// </summary>
    public const string StackTopic = "notices.stack";

    /// <summary>
    /// The topic that ends the toast of a key before its time.
    /// </summary>
    public const string DropTopic = "notices.drop";

    /// <summary>
    /// The topic that ends every toast of a group.
    /// </summary>
    public const string DropGroupTopic = "notices.drop_group";

    /// <summary>
    /// The event of a tick in which a toast moved, faded, showed or went: {"shown" => [[id, x, y,
    /// opacity], ...] oldest first, "gone" => [id, ...]}. X and y are the pixels right and down
    /// from the toast's place at its stack's start.
    /// </summary>
    public const string EventTopic = "notices.toasts";

    /// <summary>
    /// The topic of the bubbles' clock: answers the milliseconds counted, see <see cref="Clock"/>.
    /// </summary>
    public const string ClockTopic = "notices.clock";

    /// <summary>
    /// The most toasts a stack holds; past it the stack's oldest waiting one is dropped.
    /// </summary>
    public const int Most = 32;

    /// <summary>
    /// Seconds a new toast slides in over.
    /// </summary>
    public const double SlideSeconds = 0.25;

    /// <summary>
    /// Seconds a toast fades out and travels up over once its time ended, while the others close its gap.
    /// </summary>
    public const double FadeSeconds = 1.0;

    /// <summary>
    /// Seconds the other toasts take to make room for a new one.
    /// </summary>
    public const double MoveSeconds = 0.2;

    /// <summary>
    /// Seconds between two lines in the log about dropped toasts.
    /// </summary>
    public const double DropLogSeconds = 60;

    /// <summary>
    /// The most seconds one frame counts on the bubbles' clock.
    /// </summary>
    /// <remarks>
    /// A frame the game spent loading, or in a window dragged by its title, would otherwise run a
    /// bubble out before anyone saw it.
    /// </remarks>
    public const double MostFrameSeconds = 0.1;

    /// <summary>
    /// The name the general stack goes under among the stacks, which no mod's stack has.
    /// </summary>
    private const string General = "";

    /// <summary>
    /// How opaque a toast is that neither slides in nor fades.
    /// </summary>
    private const int Opaque = 255;

    /// <summary>
    /// The toasts queued, oldest first, those shown and those waiting, of every stack.
    /// </summary>
    private readonly List<Toast> _toasts = [];

    /// <summary>
    /// The stacks by their names, the general one under <see cref="General"/>.
    /// </summary>
    private readonly Dictionary<string, ToastStack> _stacks = [];

    /// <summary>
    /// The ids of the toasts gone since the last event.
    /// </summary>
    private readonly List<long> _gone = [];

    /// <summary>
    /// What the last event told of each toast shown.
    /// </summary>
    private List<(long Id, int X, int Y, int Opacity)> _told = [];

    /// <summary>
    /// Tells the seconds passed since some fixed moment.
    /// </summary>
    private readonly Func<double> _clock;

    /// <summary>
    /// Tells whether the game's window is in front.
    /// </summary>
    private readonly Func<bool> _front;

    /// <summary>
    /// Where the lines about stacks, refusals and dropped toasts go.
    /// </summary>
    private readonly Action<string> _log;

    /// <summary>
    /// Where the events go.
    /// </summary>
    private readonly Action<string, RubyValue> _post;

    /// <summary>
    /// The moment of the last tick, null before the first tick of toasts queued into an empty queue.
    /// </summary>
    private double? _tickedAt;

    /// <summary>
    /// The moment the bubbles last read the clock, null before the first read.
    /// </summary>
    private double? _clockAt;

    /// <summary>
    /// The seconds the bubbles' clock counted.
    /// </summary>
    private double _counted;

    /// <summary>
    /// The toasts dropped since the last line about them.
    /// </summary>
    private int _dropped;

    /// <summary>
    /// The moment of the last line about dropped toasts, null before the first.
    /// </summary>
    private double? _droppedLogged;

    /// <summary>
    /// The place in line the last toast that started showing got.
    /// </summary>
    private long _lastShown;

    /// <summary>
    /// Creates the queue with the general stack at the top left.
    /// </summary>
    /// <param name="clock">Tells the seconds passed since some fixed moment.</param>
    /// <param name="front">Tells whether the game's window is in front.</param>
    /// <param name="log">Where the lines about stacks, refusals and dropped toasts go.</param>
    /// <param name="post">Where the events go, by topic.</param>
    public NoticeQueue(Func<double> clock, Func<bool> front, Action<string> log, Action<string, RubyValue> post)
    {
        _clock = clock;
        _front = front;
        _log = log;
        _post = post;
        _stacks[General] = ToastStack.Read(null, new RubyHash(), log);
    }

    /// <inheritdoc />
    public string Name => ModelName;

    /// <summary>
    /// Adds a queue to a host and registers its topics, timed by the performance counter and logged
    /// to the framework's log.
    /// </summary>
    /// <param name="host">The host of the context the handshake opened.</param>
    /// <param name="front">Tells whether the game's window is in front, as the input model last read it.</param>
    public static void Register(UiHost host, Func<bool> front)
    {
        var watch = Stopwatch.StartNew();
        var queue = new NoticeQueue(() => watch.Elapsed.TotalSeconds, front, Log.Write, host.Post);
        host.Add(queue);
        BridgeContext context = host.Context;
        context.Register(ToastTopic, (_, request) => queue.Add(request.AsArray()));
        context.Register(StackTopic, (_, request) => queue.Define(request.AsArray()));
        context.Register(DropTopic, (_, request) => queue.Drop(request.IsNil ? null : request.AsText()));
        context.Register(DropGroupTopic, (_, request) => queue.DropGroup(request.AsText()));
        context.Register(ClockTopic, (_, _) => queue.Clock());
    }

    /// <summary>
    /// Defines a stack, or defines it anew with its toasts kept; the general stack takes only its corner.
    /// </summary>
    /// <param name="request">[name, options], name nil for the general stack.</param>
    /// <returns>Where the stack lies, see <see cref="ToastStack.Placement"/>.</returns>
    public RubyValue Define(RubyArray request)
    {
        string? name = request[0].IsNil ? null : request[0].AsText();
        ToastStack stack = ToastStack.Read(name, request[1].AsHash(), _log);
        _stacks[name ?? General] = stack;
        return stack.Placement();
    }

    /// <summary>
    /// Queues a toast at the end of its stack's line. One with the key of a toast queued in the
    /// same stack takes that toast's place instead: shown, it stays where it is, whole and with its
    /// time started again. Past <see cref="Most"/> the stack's oldest waiting toast is dropped. A
    /// toast into a stack nobody defined is refused and logged.
    /// </summary>
    /// <param name="toast">[id, milliseconds, key, group, width, height, stack].</param>
    /// <returns>The milliseconds it shows, nil when refused.</returns>
    public RubyValue Add(RubyArray toast)
    {
        string? name = toast[6].IsNil ? null : toast[6].AsText();
        if (!_stacks.TryGetValue(name ?? General, out ToastStack? stack))
        {
            _log($"notices: toast {toast[0].AsLong()} was refused: no mod defined the toast stack {name}");
            return RubyNil.Value;
        }

        if (_toasts.Count == 0)
        {
            // The scripts tick the queue only while it holds toasts, so the last tick lies long ago.
            _tickedAt = null;
        }

        double seconds = toast[1].IsNil ? stack.Seconds : Math.Max(toast[1].AsLong() / 1000.0, 0);
        string? key = toast[2].IsNil ? null : toast[2].AsText();
        var added = new Toast(toast[0].AsLong(), seconds, key, toast[3].IsNil ? null : toast[3].AsText(), name ?? General, toast[4].AsInt(), toast[5].AsInt());
        int replaced = key is null ? -1 : _toasts.FindIndex(each => each.Key == key && each.Stack == added.Stack);
        if (replaced < 0)
        {
            _toasts.Add(added);
        }
        else
        {
            added.TakePlaceOf(_toasts[replaced]);
            _gone.Add(_toasts[replaced].Id);
            _toasts[replaced] = added;
        }

        while (_toasts.Count(each => each.Stack == added.Stack) > Most && _toasts.FindIndex(each => each.Stack == added.Stack && !each.Shown) is int oldest and >= 0)
        {
            _gone.Add(_toasts[oldest].Id);
            _toasts.RemoveAt(oldest);
            _dropped++;
        }

        return (long)Math.Round(seconds * 1000);
    }

    /// <summary>
    /// Ends the toasts of a key in every stack: shown, they fade out; waiting, they go at once.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Whether one ended.</returns>
    public RubyValue Drop(string? key) => key is not null && End(each => each.Key == key) > 0;

    /// <summary>
    /// Ends every toast of a group, as <see cref="Drop"/> ends one.
    /// </summary>
    /// <param name="group">The group.</param>
    /// <returns>How many ended.</returns>
    public RubyValue DropGroup(string group) => End(each => each.Group == group);

    /// <summary>
    /// Follows a tick: counts the wall-clock time since the last tick off each toast shown, lets the
    /// toasts whose fade ended go, shows waiting toasts where their stack has room, places each
    /// along its stack past the room the others before it take, and posts <see cref="EventTopic"/>
    /// when anything shown changed. A still stack posts nothing.
    /// </summary>
    /// <param name="input">Not read.</param>
    public void Tick(RubyValue input)
    {
        double now = _clock();
        double passed = _tickedAt is double before ? Math.Max(now - before, 0) : 0;
        _tickedAt = now;
        foreach (Toast toast in _toasts.Where(each => each.Shown))
        {
            toast.Count(passed);
        }

        foreach (Toast toast in _toasts.Where(each => each.Faded))
        {
            _gone.Add(toast.Id);
        }

        _toasts.RemoveAll(each => each.Faded);
        foreach ((string name, ToastStack stack) in _stacks)
        {
            int room = stack.MostShown - _toasts.Count(each => each.Stack == name && each.Shown);
            foreach (Toast toast in _toasts.Where(each => each.Stack == name && !each.Shown).Take(room).ToList())
            {
                toast.Show(++_lastShown);
            }

            Lay(name, stack);
        }

        LogDropped(now);
        Tell();
    }

    /// <summary>
    /// Reads the clock the speech bubbles count their seconds by: the real time since the last read
    /// counts while the game is in front, at most <see cref="MostFrameSeconds"/>, as the scripts
    /// read it once a frame.
    /// </summary>
    /// <returns>The milliseconds counted.</returns>
    public RubyValue Clock()
    {
        double now = _clock();
        if (_front() && _clockAt is double before)
        {
            _counted += Math.Min(now - before, MostFrameSeconds);
        }

        _clockAt = now;
        return (long)Math.Round(_counted * 1000);
    }

    /// <summary>
    /// Places each toast a stack shows along it, from its start on: the newest first where the
    /// newest lies at the start, else the oldest.
    /// </summary>
    /// <param name="name">The stack's name.</param>
    /// <param name="stack">Its rules.</param>
    private void Lay(string name, ToastStack stack)
    {
        IEnumerable<Toast> shown = _toasts.Where(each => each.Stack == name && each.Shown);
        double distance = 0;
        foreach (Toast toast in stack.NewestAtStart ? shown.OrderByDescending(each => each.Place) : shown.OrderBy(each => each.Place))
        {
            toast.MoveTo(stack, distance);
            distance += toast.Space;
        }
    }

    /// <summary>
    /// Ends the toasts that match: those shown fade out, those waiting go at once.
    /// </summary>
    /// <param name="match">Which toasts.</param>
    /// <returns>How many ended.</returns>
    private int End(Predicate<Toast> match)
    {
        int ended = 0;
        foreach (Toast toast in _toasts.Where(each => each.Shown && match(each)))
        {
            toast.End();
            ended++;
        }

        foreach (Toast toast in _toasts.Where(each => !each.Shown && match(each)))
        {
            _gone.Add(toast.Id);
            ended++;
        }

        _toasts.RemoveAll(each => !each.Shown && match(each));
        return ended;
    }

    /// <summary>
    /// Posts what shows when it differs from what the last event told, or a toast went.
    /// </summary>
    private void Tell()
    {
        List<(long Id, int X, int Y, int Opacity)> shown = [.. _toasts.Where(each => each.Shown).Select(each => (each.Id, each.X, each.Y, each.Opacity))];
        if (_gone.Count == 0 && shown.SequenceEqual(_told))
        {
            return;
        }

        var rows = new RubyArray();
        foreach ((long id, int x, int y, int opacity) in shown)
        {
            rows.Add(new RubyArray { id, x, y, opacity });
        }

        var gone = new RubyArray();
        _gone.ForEach(id => gone.Add(id));
        _post(EventTopic, new RubyHash { ["shown"] = rows, ["gone"] = gone });
        _gone.Clear();
        _told = shown;
    }

    /// <summary>
    /// Writes how many toasts the full stacks dropped, at most once in <see cref="DropLogSeconds"/>.
    /// </summary>
    /// <param name="now">The moment now.</param>
    private void LogDropped(double now)
    {
        if (_dropped == 0 || (_droppedLogged is double last && now - last < DropLogSeconds))
        {
            return;
        }

        _log($"notices: a toast stack was full, so the oldest {_dropped} waiting toast{(_dropped == 1 ? " was" : "s were")} dropped");
        _dropped = 0;
        _droppedLogged = now;
    }

    /// <summary>
    /// Eases a share of a movement out: fast at first, slowing toward its end.
    /// </summary>
    /// <param name="share">The share of its time passed, 0 to 1.</param>
    /// <returns>The share of its way made.</returns>
    private static double EaseOut(double share) => 1 - Math.Pow(1 - Math.Clamp(share, 0, 1), 3);

    /// <summary>
    /// Eases a share of a movement in and out: slow at its start and its end.
    /// </summary>
    /// <param name="share">The share of its time passed, 0 to 1.</param>
    /// <returns>The share of its way made.</returns>
    private static double EaseInOut(double share)
    {
        double clamped = Math.Clamp(share, 0, 1);
        return clamped * clamped * (3 - 2 * clamped);
    }

    /// <summary>
    /// A toast queued.
    /// </summary>
    /// <param name="id">The scripts' id of it.</param>
    /// <param name="seconds">The seconds it shows.</param>
    /// <param name="key">Its key, null for none.</param>
    /// <param name="group">Its group, null for none.</param>
    /// <param name="stack">The name of its stack.</param>
    /// <param name="width">Its box's width.</param>
    /// <param name="height">Its box's height.</param>
    private sealed class Toast(long id, double seconds, string? key, string? group, string stack, int width, int height)
    {
        /// <summary>Gets the scripts' id of it.</summary>
        public long Id { get; } = id;

        /// <summary>Gets its key, null for none.</summary>
        public string? Key { get; } = key;

        /// <summary>Gets its group, null for none.</summary>
        public string? Group { get; } = group;

        /// <summary>Gets the name of its stack.</summary>
        public string Stack { get; } = stack;

        /// <summary>Gets whether it shows, rather than waits in line.</summary>
        public bool Shown { get; private set; }

        /// <summary>Gets the place it started showing at, the newest highest.</summary>
        public long Place { get; private set; }

        /// <summary>Gets whether it faded out whole.</summary>
        public bool Faded => _left <= -FadeSeconds;

        /// <summary>Gets the pixels right of its place at the stack's start it shows at now.</summary>
        public int X { get; private set; }

        /// <summary>Gets the pixels below its place at the stack's start it shows at now.</summary>
        public int Y { get; private set; }

        /// <summary>
        /// Gets the pixels it takes in the stack with the gap after it: growing as it shows, so the
        /// others make room, and shrinking as it fades, so they close its gap.
        /// </summary>
        /// <remarks>The gap closes slowly at first, so a toast moving in covers little of one still opaque.</remarks>
        public double Space => (height + Docks.Gap) * EaseOut(_age / MoveSeconds) * (1 - Fading);

        /// <summary>Gets how opaque it shows: rising as it slides in, falling as it fades out.</summary>
        public int Opacity => (int)Math.Round(Opaque * Math.Min(Math.Min(_age / SlideSeconds, 1), Math.Clamp(1 + _left / FadeSeconds, 0, 1)));

        /// <summary>Gets the share of its fade made, eased, 0 while it does not fade.</summary>
        private double Fading => EaseInOut(-_left / FadeSeconds);

        /// <summary>Its seconds left; below zero it fades.</summary>
        private double _left = seconds;

        /// <summary>The seconds since it started showing.</summary>
        private double _age;

        /// <summary>
        /// Takes the place of a toast of the same key: shown, it shows at once where that one shows,
        /// slid in and whole.
        /// </summary>
        /// <param name="other">The toast it replaces.</param>
        public void TakePlaceOf(Toast other)
        {
            if (!other.Shown)
            {
                return;
            }

            (Shown, Place, X, Y, _age) = (true, other.Place, other.X, other.Y, SlideSeconds);
        }

        /// <summary>
        /// Starts showing it; its seconds count from now on.
        /// </summary>
        /// <param name="place">Its place among the toasts that showed.</param>
        public void Show(long place) => (Shown, Place) = (true, place);

        /// <summary>
        /// Places it along its stack: past the room the toasts before it take, still sliding in,
        /// and travelling up as it fades.
        /// </summary>
        /// <param name="rules">Its stack's rules.</param>
        /// <param name="distance">The pixels from the stack's start along it.</param>
        public void MoveTo(ToastStack rules, double distance) =>
            (X, Y) = rules.Offset(distance, 1 - EaseOut(_age / SlideSeconds), Fading, width, height);

        /// <summary>
        /// Counts the wall-clock time of a tick off it.
        /// </summary>
        /// <param name="passed">The seconds.</param>
        public void Count(double passed)
        {
            _age += passed;
            _left -= passed;
        }

        /// <summary>
        /// Ends its time now, so it fades out.
        /// </summary>
        public void End() => _left = Math.Min(_left, 0);
    }
}
