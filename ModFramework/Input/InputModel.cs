//----------------------------------------------------------------
//  InputModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Told a button the keyboard's while one of its keys is held or sent a key message since the tick before
//                            - Counted a key as gone down once its key message came, also where the poll missed it
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Posted no event for a tick the same as the last one posted, so an idle frame makes the scripts no objects
//      Paulinchen  2026-11-04: Told the scripts whether the player used a gamepad last
//                            - Told the other models the right button that went down
//      Paulinchen  2026-10-31: Read the game's key settings of F1 at the first tick and each time the game comes to the front
//      Paulinchen  2026-10-30: Handed the source what the scripts read of the devices
//      Paulinchen  2026-10-28: Told the other models the pointer, the left button and the keys of the tick
//                            - Told the other models the wheel, the double click and the keys they watch
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Input;

/// <summary>
/// The operating system's input the game's own Input does not know, read once a tick: where the
/// pointer is on the game's screen, the mouse buttons with their clicks, double clicks and drags,
/// the wheel's notches and the keys the scripts watch, and the keys the player bound to the game's
/// buttons in F1, and whether the player used a gamepad last. Its event is all quiet while another
/// window is in front.
/// </summary>
/// <remarks>
/// Windows reports keys and mouse buttons whichever window is in front, so without the front check a
/// press in another application would reach the game.
/// </remarks>
internal sealed class InputModel : IUiModel
{
    /// <summary>
    /// The model's name in the tick.
    /// </summary>
    public const string ModelName = "input";

    /// <summary>
    /// The topic of the event the model posts every tick.
    /// </summary>
    public const string EventTopic = "ui.input";

    /// <summary>
    /// The most ticks between the two presses of a double click.
    /// </summary>
    public const int DoubleClickFrames = 24;

    /// <summary>
    /// The most pixels of the game's screen the pointer may move on either axis between the two
    /// presses of a double click, and while the left button is held before a drag begins.
    /// </summary>
    public const int StillPixels = 6;

    /// <summary>
    /// The ticks between two reads of whether the mouse buttons are swapped.
    /// </summary>
    public const int SwapReadFrames = 60;

    /// <summary>
    /// The bit of the event's buttons while the left button is held.
    /// </summary>
    public const int LeftHeld = 1 << 0;

    /// <summary>
    /// The bit while the right button is held.
    /// </summary>
    public const int RightHeld = 1 << 1;

    /// <summary>
    /// The bit when the left button went down at this tick.
    /// </summary>
    public const int LeftPressed = 1 << 2;

    /// <summary>
    /// The bit when the right button went down at this tick.
    /// </summary>
    public const int RightPressed = 1 << 3;

    /// <summary>
    /// The bit when the left button came up at this tick.
    /// </summary>
    public const int LeftReleased = 1 << 4;

    /// <summary>
    /// The bit when the right button came up at this tick.
    /// </summary>
    public const int RightReleased = 1 << 5;

    /// <summary>
    /// The bit while the left button is held and the pointer moved more than
    /// <see cref="StillPixels"/> since it went down.
    /// </summary>
    public const int Dragging = 1 << 6;

    /// <summary>
    /// The bit of a watched key's state while it is held.
    /// </summary>
    public const int KeyHeld = 1 << 0;

    /// <summary>
    /// The bit of a watched key's state when it went down at this tick: up at the tick before, and
    /// held now or sent a key message since.
    /// </summary>
    public const int KeyWentDown = 1 << 1;

    /// <summary>
    /// Each of the game's buttons with the keyboard's keys it has besides those F1 binds: the arrow
    /// keys of the four directions.
    /// </summary>
    private static readonly (UiButton Button, string? Bound, int[] Keys)[] ButtonKeys =
    [
        (UiButton.Confirm, "C", []), (UiButton.Cancel, "B", []), (UiButton.Up, null, [0x26]), (UiButton.Down, null, [0x28]),
        (UiButton.Left, null, [0x25]), (UiButton.Right, null, [0x27]), (UiButton.L, "L", []), (UiButton.R, "R", []),
    ];

    /// <summary>
    /// The game's extra buttons in the order of their bits.
    /// </summary>
    private static readonly UiExtraButton[] ExtraButtonsInOrder = [UiExtraButton.A, UiExtraButton.X, UiExtraButton.Y, UiExtraButton.Z];

    /// <summary>
    /// Windows' code of the physical left mouse button.
    /// </summary>
    private const int PhysicalLeft = 0x01;

    /// <summary>
    /// Windows' code of the physical right mouse button.
    /// </summary>
    private const int PhysicalRight = 0x02;

    /// <summary>
    /// The lowest key code a script may watch.
    /// </summary>
    private const int LowestCode = 0x01;

    /// <summary>
    /// The highest key code a script may watch.
    /// </summary>
    private const int HighestCode = 0xFE;

    /// <summary>
    /// Where the model posts its event.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The keys the other models watch, each with whether it was held at the last tick, whichever
    /// window was in front; the scripts' unwatch never drops them.
    /// </summary>
    private readonly Dictionary<int, bool> _modelKeys = [];

    /// <summary>
    /// The keys the other models watch that went down at the last tick while the game was in front.
    /// </summary>
    private readonly HashSet<int> _wentDown = [];

    /// <summary>
    /// The keys that sent the game's window a key message between the last tick and the one before,
    /// as a set of <see cref="KeyPresses.Words"/> words; empty while another window was in front.
    /// </summary>
    private readonly ulong[] _pressed = new ulong[KeyPresses.Words];

    /// <summary>
    /// Where it reads the input.
    /// </summary>
    private readonly IInputSource _source;

    /// <summary>
    /// Whether the key settings of F1 are read again at the next tick: at the first and after
    /// another window was in front, where the player may have changed them.
    /// </summary>
    private bool _readAssignment = true;

    /// <summary>
    /// Whether the scripts still have to be told the key settings of F1.
    /// </summary>
    private bool _tellAssignment;

    /// <summary>
    /// The last event posted, null before the first and after one that held something of a single
    /// tick, such as a key that went down.
    /// </summary>
    private RubyHash? _lastPosted;

    /// <summary>
    /// Whether the key settings of F1 were read once.
    /// </summary>
    private bool _told;

    /// <summary>
    /// The watched keys, each with whether it was held at the last tick, whichever window was in front.
    /// </summary>
    private readonly SortedDictionary<int, bool> _keys = [];

    /// <summary>
    /// The game's screen width, which the pointer is scaled to.
    /// </summary>
    private int _screenWidth = 640;

    /// <summary>
    /// The game's screen height, which the pointer is scaled to.
    /// </summary>
    private int _screenHeight = 480;

    /// <summary>
    /// The ticks counted, which the double click is timed by.
    /// </summary>
    private long _ticks;

    /// <summary>
    /// Whether the mouse buttons are swapped, as last read.
    /// </summary>
    private bool _swapped;

    /// <summary>
    /// Whether the left button was held at the last tick.
    /// </summary>
    private bool _left;

    /// <summary>
    /// Whether the right button was held at the last tick.
    /// </summary>
    private bool _right;

    /// <summary>
    /// The tick and place of the last left press that may start a double click, null for none.
    /// </summary>
    private (long Tick, int X, int Y)? _lastPress;

    /// <summary>
    /// Where the held left button went down, null while it is up or went down off the screen.
    /// </summary>
    private (int X, int Y)? _pressedAt;

    /// <summary>
    /// Whether the held left button drags.
    /// </summary>
    private bool _dragging;

    /// <summary>
    /// Creates the model.
    /// </summary>
    /// <param name="host">Where it posts its event.</param>
    /// <param name="source">Where it reads the input.</param>
    public InputModel(UiHost host, IInputSource source)
    {
        ArgumentNullException.ThrowIfNull(host);
        ArgumentNullException.ThrowIfNull(source);
        _host = host;
        _source = source;
    }

    /// <inheritdoc />
    public string Name => ModelName;

    /// <summary>
    /// Gets whether the game's window was in front at the last tick.
    /// </summary>
    public bool Front { get; private set; }

    /// <summary>
    /// Gets where the pointer was on the game's screen at the last tick, null outside it or while
    /// another window was in front.
    /// </summary>
    public (int X, int Y)? Pointer { get; private set; }

    /// <summary>
    /// Gets whether the left button was held at the last tick while the game was in front.
    /// </summary>
    public bool LeftDown { get; private set; }

    /// <summary>
    /// Gets whether the left button went down at the last tick while the game was in front.
    /// </summary>
    public bool LeftWentDown { get; private set; }

    /// <summary>
    /// Gets whether the left button came up at the last tick while the game was in front.
    /// </summary>
    public bool LeftWentUp { get; private set; }

    /// <summary>
    /// Gets whether the right button went down at the last tick while the game was in front.
    /// </summary>
    public bool RightWentDown { get; private set; }

    /// <summary>
    /// Gets whether the left press of the last tick is a double click.
    /// </summary>
    public bool DoubleClicked { get; private set; }

    /// <summary>
    /// Gets the wheel's notches of the last tick, positive away from the player, none while another
    /// window was in front.
    /// </summary>
    public int Notches { get; private set; }

    /// <summary>
    /// Gets whether the player used a gamepad last: one of the game's buttons went down and none of
    /// them comes from the keyboard, see <see cref="FromKeyboard(UiButton)"/>; a key or a mouse
    /// button going down counts as the keyboard.
    /// </summary>
    public bool PadLast { get; private set; }

    /// <summary>
    /// Gets the keyboard's keys the game reads as each of its buttons, as the player bound them in F1.
    /// </summary>
    public ButtonAssignment Assignment { get; private set; } = ButtonAssignment.Default;

    /// <summary>
    /// Gets the keyboard's keys the game reads as its cancel button, without the numpad's 0, which
    /// cancels on every root whatever F1 binds it to.
    /// </summary>
    public IReadOnlyList<int> CancelKeys => Assignment.KeysOf("B");

    /// <summary>
    /// Gets the game's screen size the pointer is scaled to.
    /// </summary>
    public (int Width, int Height) ScreenSize => (_screenWidth, _screenHeight);

    /// <summary>
    /// Tells whether a key is held now while the game's window was in front at the last tick,
    /// watched or not.
    /// </summary>
    /// <param name="code">Windows' code of the key, such as 0xA4 for the left Alt.</param>
    /// <returns>Whether it is.</returns>
    public bool KeyDown(int code) => Front && _source.KeyDown(code);

    /// <summary>
    /// Has the model read a key at every tick from the next one on for another model, which
    /// <see cref="WentDown"/> then answers; a key watched already stays as it is.
    /// </summary>
    /// <param name="code">Windows' code of the key, such as 0x09 for Tab.</param>
    /// <exception cref="ArgumentOutOfRangeException">There is no such key code.</exception>
    public void Watch(int code)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(code, LowestCode);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(code, HighestCode);
        _modelKeys.TryAdd(code, _source.KeyDown(code));
    }

    /// <summary>
    /// Tells whether a key another model watches went down at the last tick while the game's window
    /// was in front.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>Whether it did; false for a key no model watches.</returns>
    public bool WentDown(int code) => _wentDown.Contains(code);

    /// <summary>
    /// Tells whether one of the game's buttons comes from the keyboard at the last tick: one of its
    /// keys, those F1 binds to it or a direction's arrow key, is held now or sent a key message
    /// since the tick before.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it does.</returns>
    public bool FromKeyboard(UiButton button)
    {
        foreach ((UiButton each, string? bound, int[] own) in ButtonKeys)
        {
            if (each == button)
            {
                return AnyFromKeyboard(own) || (bound is not null && AnyFromKeyboard(Assignment.KeysOf(bound)));
            }
        }

        return false;
    }

    /// <summary>
    /// Tells whether one of the game's extra buttons comes from the keyboard at the last tick, see
    /// <see cref="FromKeyboard(UiButton)"/>.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it does.</returns>
    public bool FromKeyboard(UiExtraButton button) => AnyFromKeyboard(Assignment.KeysOf(button.ToString()));

    /// <summary>
    /// Tells whether one of the game's buttons went down on a gamepad at the last tick.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick, as the caller takes them.</param>
    /// <param name="button">The button.</param>
    /// <returns>Whether it went down and does not come from the keyboard.</returns>
    public bool PadPressed(UiButtons buttons, UiButton button) => buttons.Triggered(button) && !FromKeyboard(button);

    /// <summary>
    /// Takes the scripts' changes, reads the frame's input and posts it as <see cref="EventTopic"/>:
    /// {"mouse" => [x, y] or nil, "buttons" => bits, "double" => bool, "wheel" => notches,
    /// "keys" => {code => bits} for the watched keys held or gone down, "front" => bool}, while in
    /// front "pad" => whether the player used a gamepad last, and "assign" => {button => [codes]} at
    /// the first tick and after the key settings of F1 changed. A tick the same as the last one
    /// posted posts nothing, and the scripts keep what they took last.
    /// </summary>
    /// <param name="input">{"screen" => [width, height], "watch" => [codes], "unwatch" => [codes],
    /// "device" => what the scripts read, see <see cref="ScriptInput.DeviceKey"/>}, each optional.</param>
    /// <exception cref="BridgeRequestException">A screen size or a key code is out of range.</exception>
    public void Tick(RubyValue input)
    {
        RubyHash hash = input.AsHash();
        _source.Read(hash);
        Follow(hash);
        _ticks++;
        if (_ticks % SwapReadFrames == 1)
        {
            _swapped = _source.ButtonsSwapped();
        }

        var front = _source.GameInFront();
        _source.TakeKeyPresses(_pressed);
        if (!front)
        {
            Array.Clear(_pressed);
        }

        if (front && _readAssignment)
        {
            ReadAssignment();
        }

        _readAssignment |= !front;
        var notches = _source.TakeWheel();
        var (left, right) = ReadButtons();
        var keys = ReadKeys(front);
        ReadModelKeys(front);
        Front = front;
        Pointer = null;
        LeftDown = false;
        LeftWentDown = false;
        LeftWentUp = false;
        RightWentDown = false;
        DoubleClicked = false;
        Notches = 0;
        if (!front)
        {
            _lastPress = null;
            _pressedAt = null;
            _dragging = false;
            Post(Event(null, 0, false, 0, keys, false), false);
            return;
        }

        var place = Place();
        (Pointer, LeftDown, LeftWentDown, RightWentDown) = (place, left.Held, left.Pressed, right.Pressed);
        var buttons = (left.Held ? LeftHeld : 0) | (right.Held ? RightHeld : 0)
            | (left.Pressed ? LeftPressed : 0) | (right.Pressed ? RightPressed : 0)
            | (left.Released ? LeftReleased : 0) | (right.Released ? RightReleased : 0);
        var isDouble = left.Pressed && place is { } point && DoubleClick(point);
        (LeftWentUp, DoubleClicked, Notches) = (left.Released, isDouble, notches);
        if (Drags(left, place))
        {
            buttons |= Dragging;
        }

        FollowDevice(keys, left.Pressed || right.Pressed);
        var shown = Event(place, buttons, isDouble, notches, keys, true);
        shown.Add("pad", PadLast);
        var once = isDouble || notches != 0 || (buttons & (LeftPressed | RightPressed | LeftReleased | RightReleased)) != 0
            || keys.Any(pair => (pair.Value.AsInt() & KeyWentDown) != 0);
        if (_tellAssignment)
        {
            shown.Add("assign", AssignmentEvent());
            _tellAssignment = false;
            once = true;
        }

        Post(shown, once);
    }

    /// <summary>
    /// Posts a tick's event unless it is the same as the last one posted, which the scripts still
    /// hold, since every event the scripts load makes them objects.
    /// </summary>
    /// <param name="shown">The event.</param>
    /// <param name="once">Whether it holds something of this tick alone, such as a key that went
    /// down, which the scripts forget at the frame's end, so the next tick posts again.</param>
    private void Post(RubyHash shown, bool once)
    {
        if (!once && shown.Equals(_lastPosted))
        {
            return;
        }

        _lastPosted = once ? null : shown;
        _host.Post(EventTopic, shown);
    }

    /// <summary>
    /// Notes the device the player used last: a game button that went down is a gamepad's unless it
    /// comes from the keyboard, see <see cref="FromKeyboard(UiButton)"/>; without one, a watched key
    /// or a mouse button that went down counts as the keyboard.
    /// </summary>
    /// <param name="keys">The watched keys held or gone down, with their bits.</param>
    /// <param name="clicked">Whether a mouse button went down.</param>
    private void FollowDevice(RubyHash keys, bool clicked)
    {
        bool? pad = null;
        foreach ((UiButton button, _, _) in ButtonKeys)
        {
            if (_host.Buttons.Triggered(button))
            {
                pad = (pad ?? true) && !FromKeyboard(button);
            }
        }

        foreach (UiExtraButton button in ExtraButtonsInOrder)
        {
            if (_host.ExtraButtons.Triggered(button))
            {
                pad = (pad ?? true) && !FromKeyboard(button);
            }
        }

        if (pad is null && (clicked || keys.Any(pair => (pair.Value.AsInt() & KeyWentDown) != 0)))
        {
            pad = false;
        }

        PadLast = pad ?? PadLast;
    }

    /// <summary>
    /// Tells whether one of some keys is held now or sent a key message since the tick before the
    /// last.
    /// </summary>
    /// <param name="codes">Windows' codes of the keys.</param>
    /// <returns>Whether one did.</returns>
    private bool AnyFromKeyboard(IReadOnlyList<int> codes)
    {
        for (int place = 0; place < codes.Count; place++)
        {
            if (_source.KeyDown(codes[place]) || KeyPresses.Holds(_pressed, codes[place]))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Reads the key settings of F1 and logs them once they differ from the last read, or why the
    /// game's defaults stand; the scripts are told at the tick.
    /// </summary>
    private void ReadAssignment()
    {
        _readAssignment = false;
        var read = ButtonAssignment.Read(_source.ButtonAssign(), out var why);
        bool first = !_told;
        if (!first && read.SameAs(Assignment))
        {
            return;
        }

        _told = true;
        _tellAssignment = true;
        Assignment = read;
        foreach (var code in CancelKeys)
        {
            Watch(code);
        }

        _host.Context.Log.Write(why is null ? $"input: the keys of F1 are {read}" : $"input: {why}, so the game's own keys stand: {read}");
    }

    /// <summary>
    /// Builds the event's part that tells the scripts the key settings of F1.
    /// </summary>
    /// <returns>Each of the game's buttons with Windows' codes of its keys.</returns>
    private RubyHash AssignmentEvent()
    {
        var assign = new RubyHash();
        foreach (var button in ButtonAssignment.Buttons.Values)
        {
            var codes = new RubyArray();
            foreach (var code in Assignment.KeysOf(button))
            {
                codes.Add(code);
            }

            assign.Add(button, codes);
        }

        return assign;
    }

    /// <summary>
    /// Scales a place in the game window's client area to the game's screen.
    /// </summary>
    /// <remarks>
    /// The window may be larger than the game's screen, which RGSS stretches over it.
    /// </remarks>
    /// <param name="pointer">The place and the client area's size.</param>
    /// <param name="width">The game's screen width.</param>
    /// <param name="height">The game's screen height.</param>
    /// <returns>The place on the game's screen, null outside the client area.</returns>
    public static (int X, int Y)? Scale(ClientPointer pointer, int width, int height)
    {
        if (pointer.Width <= 0 || pointer.Height <= 0 || pointer.X < 0 || pointer.Y < 0 || pointer.X >= pointer.Width || pointer.Y >= pointer.Height)
        {
            return null;
        }

        return ((int)((long)pointer.X * width / pointer.Width), (int)((long)pointer.Y * height / pointer.Height));
    }

    /// <summary>
    /// Takes the screen size and the keys to watch or no longer watch, all or none of them.
    /// </summary>
    /// <param name="input">The model's input.</param>
    /// <exception cref="BridgeRequestException">A screen size or a key code is out of range.</exception>
    private void Follow(RubyHash input)
    {
        var screen = Screen(input["screen"]);
        var watch = Codes(input["watch"]);
        var unwatch = Codes(input["unwatch"]);
        (_screenWidth, _screenHeight) = screen ?? (_screenWidth, _screenHeight);
        foreach (var code in watch)
        {
            _keys.TryAdd(code, _source.KeyDown(code));
        }

        foreach (var code in unwatch)
        {
            _keys.Remove(code);
        }
    }

    /// <summary>
    /// Reads the game's screen size.
    /// </summary>
    /// <param name="value">[width, height], nil to keep the last.</param>
    /// <returns>The size, null to keep the last.</returns>
    /// <exception cref="BridgeRequestException">The size is no pair of positive numbers.</exception>
    private static (int Width, int Height)? Screen(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        var pair = value.AsArray();
        int width = pair.Count == 2 ? pair[0].AsInt() : 0, height = pair.Count == 2 ? pair[1].AsInt() : 0;
        return width > 0 && height > 0 ? (width, height) : throw new BridgeRequestException($"The screen cannot be {value}.");
    }

    /// <summary>
    /// Reads a list of key codes.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The codes.</returns>
    /// <exception cref="BridgeRequestException">A code is out of range.</exception>
    private static List<int> Codes(RubyValue value)
    {
        var codes = new List<int>();
        if (value.IsNil)
        {
            return codes;
        }

        foreach (var item in value.AsArray())
        {
            var code = item.AsInt();
            codes.Add(code is >= LowestCode and <= HighestCode ? code : throw new BridgeRequestException($"There is no key code {code}."));
        }

        return codes;
    }

    /// <summary>
    /// Reads both mouse buttons as the player's settings name them, and how each changed.
    /// </summary>
    /// <returns>The left and the right button.</returns>
    private (ButtonState Left, ButtonState Right) ReadButtons()
    {
        var first = _source.KeyDown(PhysicalLeft);
        var second = _source.KeyDown(PhysicalRight);

        // GetAsyncKeyState reads the physical buttons, so a left-handed player's left button is the
        // physical right one.
        var (left, right) = _swapped ? (second, first) : (first, second);
        var states = (new ButtonState(left, left && !_left, !left && _left), new ButtonState(right, right && !_right, !right && _right));
        (_left, _right) = (left, right);
        return states;
    }

    /// <summary>
    /// Reads the watched keys, keeping each one's state whichever window is in front, so a key held
    /// while the game comes to the front is not taken as going down; a key up at the tick before
    /// that sent a key message since went down, also where this poll misses it.
    /// </summary>
    /// <param name="front">Whether the game's window is in front, without which none is reported.</param>
    /// <returns>Each watched key held or gone down, with its bits.</returns>
    private RubyHash ReadKeys(bool front)
    {
        var keys = new RubyHash();
        foreach (var code in new List<int>(_keys.Keys))
        {
            var down = _source.KeyDown(code);
            var wentDown = !_keys[code] && (down || KeyPresses.Holds(_pressed, code));
            _keys[code] = down;
            if (front && (down || wentDown))
            {
                keys.Add(code, (down ? KeyHeld : 0) | (wentDown ? KeyWentDown : 0));
            }
        }

        return keys;
    }

    /// <summary>
    /// Reads the keys the other models watch, keeping each one's state whichever window is in front;
    /// a key goes down as in <see cref="ReadKeys"/>.
    /// </summary>
    /// <param name="front">Whether the game's window is in front, without which none went down.</param>
    private void ReadModelKeys(bool front)
    {
        _wentDown.Clear();
        foreach (var code in new List<int>(_modelKeys.Keys))
        {
            var down = _source.KeyDown(code);
            if (front && !_modelKeys[code] && (down || KeyPresses.Holds(_pressed, code)))
            {
                _wentDown.Add(code);
            }

            _modelKeys[code] = down;
        }
    }

    /// <summary>
    /// Reads where the pointer is on the game's screen.
    /// </summary>
    /// <returns>The place, null outside the client area or when it cannot be read.</returns>
    private (int X, int Y)? Place() =>
        _source.Pointer() is { } pointer ? Scale(pointer, _screenWidth, _screenHeight) : null;

    /// <summary>
    /// Tells whether a left press makes a double click with the one before, and keeps it for the
    /// next one when it does not.
    /// </summary>
    /// <param name="point">Where the press is.</param>
    /// <returns>Whether it is a double click.</returns>
    private bool DoubleClick((int X, int Y) point)
    {
        if (_lastPress is { } last && _ticks - last.Tick <= DoubleClickFrames && Still(point, (last.X, last.Y)))
        {
            // A third press starts a new double click instead of making a second one.
            _lastPress = null;
            return true;
        }

        _lastPress = (_ticks, point.X, point.Y);
        return false;
    }

    /// <summary>
    /// Follows the left button for a drag: a press on the screen starts one once the pointer moved
    /// more than <see cref="StillPixels"/>, and letting go ends it.
    /// </summary>
    /// <param name="left">The left button.</param>
    /// <param name="place">Where the pointer is, null off the screen.</param>
    /// <returns>Whether the left button drags.</returns>
    private bool Drags(ButtonState left, (int X, int Y)? place)
    {
        if (left.Pressed)
        {
            _pressedAt = place;
            _dragging = false;
        }
        else if (!left.Held)
        {
            _pressedAt = null;
            _dragging = false;
        }
        else if (!_dragging && _pressedAt is { } start && place is { } point && !Still(point, start))
        {
            _dragging = true;
        }

        return _dragging;
    }

    /// <summary>
    /// Tells whether two places lie within <see cref="StillPixels"/> of each other on either axis.
    /// </summary>
    /// <param name="point">One place.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether they do.</returns>
    private static bool Still((int X, int Y) point, (int X, int Y) other) =>
        Math.Abs(point.X - other.X) <= StillPixels && Math.Abs(point.Y - other.Y) <= StillPixels;

    /// <summary>
    /// Builds the event.
    /// </summary>
    /// <param name="place">Where the pointer is, null for nowhere.</param>
    /// <param name="buttons">The buttons' bits.</param>
    /// <param name="isDouble">Whether the left press is a double click.</param>
    /// <param name="notches">The wheel's notches.</param>
    /// <param name="keys">The watched keys held or gone down.</param>
    /// <param name="front">Whether the game's window is in front.</param>
    /// <returns>The event's payload.</returns>
    private static RubyHash Event((int X, int Y)? place, int buttons, bool isDouble, int notches, RubyHash keys, bool front) => new()
    {
        { "mouse", place is { } point ? new RubyArray { point.X, point.Y } : RubyNil.Value },
        { "buttons", buttons },
        { "double", isDouble },
        { "wheel", notches },
        { "keys", keys },
        { "front", front },
    };

    /// <summary>
    /// A mouse button at a tick.
    /// </summary>
    /// <param name="Held">Whether it is held.</param>
    /// <param name="Pressed">Whether it went down at this tick.</param>
    /// <param name="Released">Whether it came up at this tick.</param>
    private readonly record struct ButtonState(bool Held, bool Pressed, bool Released);
}
