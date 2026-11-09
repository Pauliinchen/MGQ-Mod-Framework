//----------------------------------------------------------------
//  WheelModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-31: Pointed by the boxes of a wheel of boxes and fell back to the middle as the count of choices changed
//      Paulinchen  2026-10-29: Moved into the Mod Framework
//                            - Defined the wheels by the scripts instead of two fixed ones
//                            - Pointed and took a choice with the mouse
//                            - Closed on the numpad's 0 with Num Lock off
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;

namespace MGQParadox.ModFramework.Ui.Wheels;

/// <summary>
/// A wheel of choices around a middle, a mod's Mod_Framework::UI::Wheel: its key opens and closes it, the arrows held point at a choice
/// like a joystick, which stays picked once they are let go, the pointer moving over it points too,
/// and confirm or a click takes it. Its owner reads the key and whether the scene leaves the wheel
/// free, the wheel decides the rest and posts what changed.
/// </summary>
internal sealed class WheelModel : IUiModel
{
    /// <summary>
    /// The wheels' event: {"wheel", "open", "selected", "places" when opened or the choices changed,
    /// "take" when confirm took a choice, "reason" when it closed, "cues"}.
    /// </summary>
    public const string EventTopic = "ui.wheel";

    /// <summary>
    /// Defines a wheel the scripts then put input for: [name, whether it has a middle choice,
    /// whether confirm closes it]; answers true, also for a wheel defined alike before.
    /// </summary>
    public const string DefineTopic = "ui.wheel.define";

    /// <summary>
    /// Closes a wheel from outside, as a choice taken does: [name].
    /// </summary>
    public const string CloseTopic = "ui.wheel.close";

    /// <summary>
    /// Places a count of choices: [count], answering their directions.
    /// </summary>
    public const string PlacesTopic = "ui.wheel.places";

    /// <summary>
    /// What a wheel's middle choice is selected as, a direction of none.
    /// </summary>
    public const int Center = -1;

    /// <summary>Windows' code of the numpad's 0 with Num Lock on.</summary>
    public const int NumpadZero = 0x60;

    /// <summary>Windows' code of Insert, the numpad's 0 with Num Lock off, which the game does not take as cancel.</summary>
    public const int InsertKey = 0x2D;

    /// <summary>
    /// The host the wheel posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The input model of the same host, which reads the pointer, the left button and the numpad's 0.
    /// </summary>
    private readonly InputModel _input;

    /// <summary>
    /// The pointing of the arrows.
    /// </summary>
    private readonly WheelPointer _pointer = new();

    /// <summary>
    /// Whether a direction without a choice picks the middle, rather than keeping the pick.
    /// </summary>
    private readonly bool _hasCenter;

    /// <summary>
    /// Whether confirm closes the wheel; a wheel that stays open is closed by its owner once the
    /// choice taken is done.
    /// </summary>
    private readonly bool _closesOnConfirm;

    /// <summary>
    /// The directions of the choices.
    /// </summary>
    private WheelDirection[] _places = [];

    /// <summary>
    /// Whether the wheel is open.
    /// </summary>
    private bool _open;

    /// <summary>
    /// The direction picked, <see cref="Center"/> for the middle, null for none.
    /// </summary>
    private int? _selected;

    /// <summary>
    /// Where the pointer was at the last tick, so a pointer at rest leaves the arrows' pick alone.
    /// </summary>
    private (int X, int Y)? _lastPointer;

    /// <summary>
    /// Creates a wheel.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    /// <param name="input">The input model of the same host, put before the wheel in the tick.</param>
    /// <param name="name">Its name in the tick and its events, such as "wheel".</param>
    /// <param name="hasCenter">Whether it has a middle choice, which a direction without a choice picks.</param>
    /// <param name="closesOnConfirm">Whether confirm closes it.</param>
    public WheelModel(UiHost host, InputModel input, string name, bool hasCenter, bool closesOnConfirm)
    {
        ArgumentNullException.ThrowIfNull(host);
        ArgumentNullException.ThrowIfNull(input);
        _host = host;
        _input = input;
        Name = name;
        _hasCenter = hasCenter;
        _closesOnConfirm = closesOnConfirm;
        input.Watch(NumpadZero);
        input.Watch(InsertKey);
    }

    /// <inheritdoc />
    public string Name { get; }

    /// <summary>
    /// Gets whether the wheel is open.
    /// </summary>
    public bool IsOpen => _open;

    /// <summary>
    /// Registers the topics of the wheels on a host's context: defining one by its name, closing
    /// one and placing choices.
    /// </summary>
    /// <param name="host">The host the wheels are added to.</param>
    /// <param name="input">The input model of the same host.</param>
    public static void RegisterTopics(UiHost host, InputModel input)
    {
        ArgumentNullException.ThrowIfNull(host);
        ArgumentNullException.ThrowIfNull(input);
        var wheels = new Dictionary<string, WheelModel>(StringComparer.Ordinal);
        BridgeContext context = host.Context;
        context.Register(DefineTopic, (_, request) =>
        {
            RubyArray values = request.AsArray();
            string name = values[0].AsText();
            bool hasCenter = values[1].AsBool();
            bool closesOnConfirm = values[2].AsBool();
            if (wheels.TryGetValue(name, out WheelModel? defined))
            {
                return defined._hasCenter == hasCenter && defined._closesOnConfirm == closesOnConfirm
                    ? true
                    : throw new BridgeRequestException($"The wheel {name} is defined already with other settings.");
            }

            var wheel = new WheelModel(host, input, name, hasCenter, closesOnConfirm);
            try
            {
                host.Add(wheel);
            }
            catch (ArgumentException)
            {
                throw new BridgeRequestException($"Another ui model is named {name}.");
            }

            wheels.Add(name, wheel);
            return true;
        });
        context.Register(CloseTopic, (_, request) =>
        {
            if (wheels.TryGetValue(request.AsArray()[0].AsText(), out WheelModel? wheel))
            {
                wheel.Close();
            }

            return null;
        });
        context.Register(PlacesTopic, (_, request) => Directions(WheelPlaces.Of(request.AsArray()[0].AsInt())));
    }

    /// <summary>
    /// Follows a frame: [true, or why the wheel may not show; the key went down; cancel; confirm;
    /// the arrows held; how many choices it has; where it shows, [middle's x, middle's y, the middle
    /// choice's radius, the ring's radius] or nil for a wheel the pointer does not reach; and for a
    /// wheel of boxes the boxes the pointer hits instead of the ring, [[direction or -1 for the
    /// middle, left, top, width, height], ...]]. The pick falls back to the middle, or to none, when
    /// the count of choices changes while it is open.
    /// </summary>
    /// <param name="input">The owner's input.</param>
    public void Tick(RubyValue input)
    {
        RubyArray values = input.AsArray();
        bool key = values[1].AsBool();
        if (values[0] is RubyString reason)
        {
            if (_open)
            {
                CloseWith(reason.Text);
            }

            return;
        }

        int count = values[5].AsInt();
        bool placesChanged = count != _places.Length;
        if (placesChanged)
        {
            _places = WheelPlaces.Of(count);
        }

        RubyArray? boxes = values.Count > 7 && !values[7].IsNil ? values[7].AsArray() : null;
        Ring? ring = values.Count > 6 && !values[6].IsNil ? Ring.Of(values[6].AsArray(), boxes) : null;
        (int X, int Y)? pointer = ring is null ? null : _input.Pointer;
        bool pointerMoved = pointer is not null && pointer != _lastPointer;
        _lastPointer = pointer;
        if (!_open)
        {
            if (key)
            {
                Open();
            }

            return;
        }

        bool clicked = pointer is not null && _input.LeftWentDown;
        bool clickedOutside = clicked && !ring!.Value.Holds(pointer!.Value);
        if (key || values[2].AsBool() || _input.WentDown(NumpadZero) || _input.WentDown(InsertKey) || clickedOutside)
        {
            CloseWith(key ? "its key" : clickedOutside ? "a click outside it" : "cancel", UiCue.Cancel);
            return;
        }

        if (placesChanged)
        {
            _selected = _hasCenter ? Center : null;
        }

        var arrows = (WheelArrows)values[4].AsInt();
        int? pointed = pointerMoved || clicked ? ring!.Value.Pointed(pointer!.Value, _places, _hasCenter) : null;
        Follow(arrows, pointed, values[3].AsBool() || clicked, placesChanged);
    }

    /// <summary>
    /// Writes directions as the scripts read them.
    /// </summary>
    /// <param name="places">The directions.</param>
    /// <returns>Each direction's number.</returns>
    private static RubyArray Directions(WheelDirection[] places)
    {
        var value = new RubyArray();
        foreach (WheelDirection place in places)
        {
            value.Add((long)place);
        }

        return value;
    }

    /// <summary>
    /// Writes a pick as the scripts read it.
    /// </summary>
    /// <param name="selected">The pick.</param>
    /// <returns>The direction's number, -1 for the middle, nil for none.</returns>
    private static RubyValue Value(int? selected) => selected is int direction ? direction : RubyNil.Value;

    /// <summary>
    /// Opens the wheel on its middle choice, or on none.
    /// </summary>
    private void Open()
    {
        _open = true;
        _selected = _hasCenter ? Center : null;
        _pointer.Reset();
        RubyHash state = State();
        state["places"] = Directions(_places);
        Post(state, UiCue.Cursor);
    }

    /// <summary>
    /// Points at the choice the arrows held or the pointer point to and takes it on confirm.
    /// </summary>
    /// <param name="arrows">The arrows held.</param>
    /// <param name="pointerPick">What the pointer points at, null when it rests or points at nothing.</param>
    /// <param name="confirm">Whether confirm went down or the wheel was clicked.</param>
    /// <param name="placesChanged">Whether the choices changed this tick.</param>
    private void Follow(WheelArrows arrows, int? pointerPick, bool confirm, bool placesChanged)
    {
        int? pointed = _selected;
        if (_pointer.Steady(arrows) is { } held)
        {
            bool hasChoice = Array.IndexOf(_places, held) >= 0;
            pointed = hasChoice ? (int)held : _hasCenter ? Center : _selected;
        }
        else if (pointerPick is int byPointer)
        {
            pointed = byPointer;
        }

        bool moved = pointed != _selected;
        _selected = pointed;
        if (!confirm)
        {
            if (moved || placesChanged)
            {
                RubyHash state = State();
                if (placesChanged)
                {
                    state["places"] = Directions(_places);
                }

                Post(state, moved ? UiCue.Cursor : null);
            }

            return;
        }

        if (!_closesOnConfirm)
        {
            RubyHash taken = State();
            taken["take"] = Value(_selected);
            Post(taken, moved ? UiCue.Cursor : null);
            return;
        }

        _open = false;
        RubyHash closed = State();
        closed["take"] = Value(_selected);
        closed["reason"] = _selected is null ? "confirmed with nothing pointed at" : "took a choice";
        Post(closed, _selected is null ? UiCue.Cancel : null);
    }

    /// <summary>
    /// Closes the wheel from outside, without an event, as its owner closes it itself.
    /// </summary>
    private void Close() => _open = false;

    /// <summary>
    /// Closes the wheel and posts why.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    /// <param name="cue">The sound, null for none.</param>
    private void CloseWith(string reason, string? cue = null)
    {
        _open = false;
        RubyHash state = State();
        state["reason"] = reason;
        Post(state, cue);
    }

    /// <summary>
    /// Builds the wheel's state for its event.
    /// </summary>
    /// <returns>{"wheel", "open", "selected"}.</returns>
    private RubyHash State() => new() { { "wheel", Name }, { "open", _open }, { "selected", Value(_selected) } };

    /// <summary>
    /// Posts the wheel's event with its sound.
    /// </summary>
    /// <param name="state">The event.</param>
    /// <param name="cue">The sound, null for none.</param>
    private void Post(RubyHash state, string? cue)
    {
        state[UiCue.Key] = cue is null ? new RubyArray() : new RubyArray { cue };
        _host.Post(EventTopic, state);
    }

    /// <summary>
    /// Where a wheel shows on the screen: its middle, the radius of its middle choice and the
    /// radius of its ring of choices, or the boxes of a wheel of boxes.
    /// </summary>
    /// <param name="X">The middle's left.</param>
    /// <param name="Y">The middle's top.</param>
    /// <param name="Inner">The middle choice's radius.</param>
    /// <param name="Outer">The ring's radius.</param>
    /// <param name="Boxes">The boxes the pointer hits instead of the ring, null for a ring.</param>
    private readonly record struct Ring(int X, int Y, int Inner, int Outer, WheelBox[]? Boxes)
    {
        /// <summary>
        /// Reads a ring as the scripts hand it over.
        /// </summary>
        /// <param name="values">[x, y, inner, outer].</param>
        /// <param name="boxes">The boxes, [[direction, left, top, width, height], ...], null for none.</param>
        /// <returns>The ring.</returns>
        /// <exception cref="BridgeRequestException">A radius is negative or the middle's larger than the ring's.</exception>
        public static Ring Of(RubyArray values, RubyArray? boxes)
        {
            WheelBox[]? read = null;
            if (boxes is not null)
            {
                read = new WheelBox[boxes.Count];
                for (int index = 0; index < boxes.Count; index++)
                {
                    RubyArray box = boxes[index].AsArray();
                    read[index] = new WheelBox(box[0].AsInt(), box[1].AsInt(), box[2].AsInt(), box[3].AsInt(), box[4].AsInt());
                }
            }

            var ring = new Ring(values[0].AsInt(), values[1].AsInt(), values[2].AsInt(), values[3].AsInt(), read);
            return ring.Inner >= 0 && ring.Outer >= ring.Inner ? ring : throw new BridgeRequestException($"A wheel cannot show with the radii {ring.Inner} and {ring.Outer}.");
        }

        /// <summary>
        /// Tells whether a point lies on the wheel, its middle included: within the ring, or within
        /// the rectangle around all its boxes.
        /// </summary>
        /// <param name="point">The point on the screen.</param>
        /// <returns>Whether it does.</returns>
        public bool Holds((int X, int Y) point)
        {
            if (Boxes is not { Length: > 0 } boxes)
            {
                return Distance(point) <= Outer;
            }

            int left = int.MaxValue, top = int.MaxValue, right = int.MinValue, bottom = int.MinValue;
            foreach (WheelBox box in boxes)
            {
                left = Math.Min(left, box.Left);
                top = Math.Min(top, box.Top);
                right = Math.Max(right, box.Left + box.Width);
                bottom = Math.Max(bottom, box.Top + box.Height);
            }

            return point.X >= left && point.X < right && point.Y >= top && point.Y < bottom;
        }

        /// <summary>
        /// Finds what a point on the screen points at: the middle inside the middle choice's radius,
        /// else the choice of the direction it lies in on the ring.
        /// </summary>
        /// <param name="point">The point on the screen.</param>
        /// <param name="places">The directions of the choices.</param>
        /// <param name="hasCenter">Whether the wheel has a middle choice.</param>
        /// <returns>The direction's number, <see cref="Center"/> for the middle, null for nothing.</returns>
        public int? Pointed((int X, int Y) point, WheelDirection[] places, bool hasCenter)
        {
            if (Boxes is { } boxes)
            {
                return PointedBox(point, boxes, places, hasCenter);
            }

            double distance = Distance(point);
            if (distance > Outer)
            {
                return null;
            }

            if (distance <= Inner)
            {
                return hasCenter ? Center : null;
            }

            // Clockwise from the top, with the screen's y growing downwards.
            double angle = Math.Atan2(point.X - X, Y - point.Y);
            var direction = (WheelDirection)(((int)Math.Round(angle / (Math.PI / 4)) + WheelPlaces.Directions) % WheelPlaces.Directions);
            return Array.IndexOf(places, direction) >= 0 ? (int)direction : null;
        }

        /// <summary>
        /// Finds the box a point lies in: the middle's, or a choice's.
        /// </summary>
        /// <param name="point">The point on the screen.</param>
        /// <param name="boxes">The boxes.</param>
        /// <param name="places">The directions of the choices.</param>
        /// <param name="hasCenter">Whether the wheel has a middle choice.</param>
        /// <returns>The direction's number, <see cref="Center"/> for the middle, null for nothing.</returns>
        private static int? PointedBox((int X, int Y) point, WheelBox[] boxes, WheelDirection[] places, bool hasCenter)
        {
            foreach (WheelBox box in boxes)
            {
                if (!box.Holds(point))
                {
                    continue;
                }

                if (box.Direction == Center)
                {
                    return hasCenter ? Center : null;
                }

                return Array.IndexOf(places, (WheelDirection)box.Direction) >= 0 ? box.Direction : null;
            }

            return null;
        }

        /// <summary>
        /// Measures how far a point lies from the middle.
        /// </summary>
        /// <param name="point">The point.</param>
        /// <returns>The distance in pixels.</returns>
        private double Distance((int X, int Y) point) => Math.Sqrt(Math.Pow(point.X - X, 2) + Math.Pow(point.Y - Y, 2));
    }

    /// <summary>
    /// A box of a wheel of boxes on the screen.
    /// </summary>
    /// <param name="Direction">The direction of its choice, <see cref="Center"/> for the middle.</param>
    /// <param name="Left">Its left.</param>
    /// <param name="Top">Its top.</param>
    /// <param name="Width">Its width.</param>
    /// <param name="Height">Its height.</param>
    private readonly record struct WheelBox(int Direction, int Left, int Top, int Width, int Height)
    {
        /// <summary>
        /// Tells whether a point lies in the box.
        /// </summary>
        /// <param name="point">The point on the screen.</param>
        /// <returns>Whether it does.</returns>
        public bool Holds((int X, int Y) point) => point.X >= Left && point.X < Left + Width && point.Y >= Top && point.Y < Top + Height;
    }
}
