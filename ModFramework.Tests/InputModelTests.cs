//----------------------------------------------------------------
//  InputModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Checked keys whose key message comes while the poll misses them, and late messages of held keys
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Checked that a tick the same as the last one posted posts nothing, and read such a tick as
//                              the scripts hold the last event
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of the mouse, the keys and the key settings of F1, which
//                              took over the checks of ButtonAssignmentTests.cs
//                            - Covered the gamepad told as the device used last
//      Paulinchen  2026-10-31: Covered the key settings of F1 told at the first tick and after they changed behind another window
//      Paulinchen  2026-10-28: Moved the input a test sets into FakeInput.cs
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the input the model reads once a tick: the pointer scaled to the game's screen, clicks,
/// double clicks and drags, the watched keys and the wheel, nothing while another window is in
/// front, the key settings of F1 and the device used last.
/// </summary>
public sealed class InputModelTests
{
    /// <summary>
    /// Windows' code of the numpad's 0.
    /// </summary>
    private const int NumpadZero = 0x60;

    /// <summary>
    /// Windows' code of the left mouse button.
    /// </summary>
    private const int LeftButton = 0x01;

    /// <summary>
    /// What the model reads.
    /// </summary>
    private readonly FakeInput _input = new();

    /// <summary>
    /// The bridge the model posts on.
    /// </summary>
    private readonly UiContext _ui = new();

    /// <summary>
    /// The last event a tick posted, which the scripts hold while a tick posts none.
    /// </summary>
    private RubyHash? _held;

    /// <summary>
    /// Adds the model to a host on the test's bridge.
    /// </summary>
    public InputModelTests()
    {
        var host = new UiHost(_ui.Context);
        host.Add(new InputModel(host, _input));
    }

    /// <summary>
    /// Asserts that a tick the same as the last one posted posts nothing, so an idle frame makes the
    /// scripts no objects, while the first tick with the key settings, a press, the tick after each and
    /// a move of the pointer post.
    /// </summary>
    [Fact]
    public void IdleTicks_PostNothingOnceTheirEventWasPosted()
    {
        _input.Pointer = Over(100, 100);
        Assert.Single(Posted());
        Assert.Single(Posted());
        Assert.Empty(Posted());
        _input.Down.Add(LeftButton);
        Assert.Single(Posted());
        Assert.Single(Posted());
        Assert.Empty(Posted());
        _input.Pointer = Over(101, 100);
        Assert.Single(Posted());
    }

    /// <summary>
    /// Asserts that the pointer is scaled from a window at double size to the game's screen and is
    /// nil outside the client area, that a press goes down, is held and comes up, each edge once,
    /// that the held button drags only past the still pixels, and that buttons swapped in Windows
    /// make the physical left button the right one.
    /// </summary>
    [Fact]
    public void Mouse_ScalesThePointerAndTellsPressesAndDrags()
    {
        _input.Pointer = new ClientPointer(641, 479, 1280, 960);
        Assert.Equal(new RubyArray { 320, 239 }, Tick()["mouse"]);
        _input.Pointer = new ClientPointer(-1, 10, 1280, 960);
        Assert.True(Tick()["mouse"].IsNil);
        _input.Pointer = new ClientPointer(1280, 10, 1280, 960);
        Assert.True(Tick()["mouse"].IsNil);

        _input.Pointer = Over(100, 100);
        _input.Down.Add(LeftButton);
        int pressed = Buttons(Tick());
        _input.Pointer = Over(100 + InputModel.StillPixels, 100);
        int still = Buttons(Tick());
        _input.Pointer = Over(100 + InputModel.StillPixels + 1, 100);
        int dragged = Buttons(Tick());
        _input.Down.Clear();
        int released = Buttons(Tick());
        Assert.Equal(
            [InputModel.LeftHeld | InputModel.LeftPressed, InputModel.LeftHeld, InputModel.LeftHeld | InputModel.Dragging, InputModel.LeftReleased],
            [pressed, still, dragged, released]);

        var swapped = new InputModelTests();
        swapped._input.Swapped = true;
        swapped._input.Down.Add(LeftButton);
        Assert.Equal(InputModel.RightHeld | InputModel.RightPressed, Buttons(swapped.Tick()));
    }

    /// <summary>
    /// Asserts that a second press within the double click's frames and pixels is a double click and
    /// a third right after it is not, and that a second press one frame later or one pixel further
    /// is none.
    /// </summary>
    [Fact]
    public void DoubleClick_TakesTheFramesAndPixelsOfOne()
    {
        Assert.Equal([false, true, false], [Click(0, 0), Click(InputModel.DoubleClickFrames, InputModel.StillPixels), Click(2, 0)]);

        Click(30, 0);
        Assert.False(Click(InputModel.DoubleClickFrames + 1, 0));

        Click(30, 0);
        Assert.False(Click(2, InputModel.StillPixels + 1));
    }

    /// <summary>
    /// Asserts that a watched key tells going down once and then being held, a key already held as
    /// its watch starts does not go down, a held key whose key message comes late does not go down
    /// again, a tap the poll misses goes down once by its key message, an unwatched key is left out,
    /// the wheel hands its notches out once, and a key code Windows does not have refuses the whole
    /// tick.
    /// </summary>
    [Fact]
    public void Keys_TellTheWatchedKeysAndTheWheel()
    {
        _input.Down.Add(0x41);
        var heldBefore = Tick(new RubyHash { { "watch", new RubyArray { NumpadZero, 0x41 } } })["keys"];
        _input.Down.Add(NumpadZero);
        _input.Notches = -2;
        RubyHash first = Tick();
        var second = Tick()["keys"];
        _input.Presses.Note(NumpadZero);
        var late = Tick()["keys"];
        _input.Down.Remove(NumpadZero);
        Tick();
        _input.Presses.Note(NumpadZero);
        var tapped = Tick()["keys"];
        var afterTap = Tick()["keys"];
        var unwatched = Tick(new RubyHash { { "unwatch", new RubyArray { NumpadZero, 0x41 } } });
        RubyHash? refused = _ui.Call(UiHost.TickTopic, new RubyHash { { InputModel.ModelName, new RubyHash { { "watch", new RubyArray { 0x100 } } } } });

        Assert.Equal(new RubyHash { { 0x41, InputModel.KeyHeld } }, heldBefore);
        Assert.Equal(new RubyHash { { 0x41, InputModel.KeyHeld }, { NumpadZero, InputModel.KeyHeld | InputModel.KeyWentDown } }, first["keys"]);
        Assert.Equal(new RubyHash { { 0x41, InputModel.KeyHeld }, { NumpadZero, InputModel.KeyHeld } }, second);
        Assert.Equal(second, late);
        Assert.Equal(new RubyHash { { 0x41, InputModel.KeyHeld }, { NumpadZero, InputModel.KeyWentDown } }, tapped);
        Assert.Equal(new RubyHash { { 0x41, InputModel.KeyHeld } }, afterTap);
        Assert.Equal(new RubyHash(), unwatched["keys"]);
        Assert.Equal([-2, 0], [first["wheel"].AsInt(), unwatched["wheel"].AsInt()]);
        Assert.Equal(BridgeEnvelope.BadRequest, refused!["error"].AsText());
    }

    /// <summary>
    /// Asserts that behind another window nothing is told, the wheel's turn is dropped, and a key
    /// still held as the game comes back is held without going down again.
    /// </summary>
    [Fact]
    public void Behind_AnotherWindow_IsQuiet()
    {
        _input.Pointer = Over(10, 10);
        _input.Front = false;
        _input.Notches = 1;
        _input.Down.UnionWith([LeftButton, NumpadZero]);

        var behind = Tick(new RubyHash { { "watch", new RubyArray { NumpadZero } } });
        _input.Front = true;
        var back = Tick();

        Assert.Equal(
            new RubyHash { { "mouse", RubyNil.Value }, { "buttons", 0 }, { "double", false }, { "wheel", 0 }, { "keys", new RubyHash() }, { "front", false } },
            behind);
        Assert.Equal([InputModel.LeftHeld, 0], [Buttons(back), back["wheel"].AsInt()]);
        Assert.Equal(new RubyHash { { NumpadZero, InputModel.KeyHeld } }, back["keys"]);
    }

    /// <summary>
    /// Asserts that the key settings of F1 recorded on a PC whose player never changed them bind the
    /// game's own keys, that a letter bound to cancel joins the cancel keys and leaves the button it
    /// had, and that no value or one of another length keeps the game's defaults with a reason.
    /// </summary>
    [Fact]
    public void KeySettings_BindTheKeysAsF1Says()
    {
        byte[] recorded = [11, 12, 13, 14, 15, 16, 17, 18, 0, 0, 13, 13, 12, 12, 11, 13, 12, 0, 0, 0, 14, 15, 16, 17, 18];

        var standard = ButtonAssignment.Read(recorded, out var whyStandard);
        var bound = ButtonAssignment.Read(FakeInput.Bound(ButtonAssignment.PadButtons + 10, 12), out _);
        var missing = ButtonAssignment.Read(null, out var whyMissing);
        var shortened = ButtonAssignment.Read([12, 12], out var whyShort);

        Assert.Null(whyStandard);
        Assert.Equal([0x1B, 0x60, 0x2D, 0x58], standard.KeysOf("B"));
        Assert.Equal([0x20, 0x0D, 0x5A], standard.KeysOf("C"));
        Assert.Equal([0x51, 0x21], standard.KeysOf("L"));
        Assert.True(standard.SameAs(ButtonAssignment.Default));
        Assert.Equal([0x1B, 0x60, 0x2D, 0x58, 0x41], bound.KeysOf("B"));
        Assert.Empty(bound.KeysOf("X"));
        Assert.False(bound.SameAs(ButtonAssignment.Default));
        Assert.Same(ButtonAssignment.Default, missing);
        Assert.Same(ButtonAssignment.Default, shortened);
        Assert.Equal("the game keeps no key settings of F1 on this PC", whyMissing);
        Assert.Equal("its key settings of F1 hold 2 bytes, not 25", whyShort);
    }

    /// <summary>
    /// Asserts that the key settings of F1 are told and logged at the first tick, not at the next,
    /// and again after another window was in front only when the player changed them meanwhile.
    /// </summary>
    [Fact]
    public void KeySettings_AreToldAtTheFirstTickAndAgainOnlyOnceChanged()
    {
        _input.Assign = FakeInput.Bound(ButtonAssignment.PadButtons + 10, 12);
        var first = Tick();
        var second = Tick();
        _input.Front = false;
        Tick();
        _input.Front = true;
        var unchanged = Tick();
        _input.Front = false;
        _input.Assign = null;
        Tick();
        _input.Front = true;
        var changed = Tick();

        Assert.Equal(new RubyArray { 0x1B, 0x60, 0x2D, 0x58, 0x41 }, first["assign"].AsHash()["B"]);
        Assert.Equal([true, true], new[] { second["assign"].IsNil, unchanged["assign"].IsNil });
        Assert.Equal(new RubyArray { 0x1B, 0x60, 0x2D, 0x58 }, changed["assign"].AsHash()["B"]);
        Assert.Equal(2, _ui.Log.Lines.Count(line => line.StartsWith("input: ", System.StringComparison.Ordinal)));
        Assert.StartsWith("input: the game keeps no key settings of F1 on this PC, so the game's own keys stand: ", _ui.Log.Lines.Last());
    }

    /// <summary>
    /// Asserts that a game button that goes down with none of its keys held counts as a gamepad's
    /// until a key goes down, that DOWN with its arrow key held counts as the keyboard, and that
    /// confirm with a Space the poll missed counts as the keyboard by its key message.
    /// </summary>
    [Fact]
    public void Device_IsThePadOnlyWhileNoKeyOfTheButtonIsHeldOrMessaged()
    {
        Tick(new RubyHash { { "watch", new RubyArray { 0x41 } } });
        int confirm = 1 << (int)UiButton.Confirm;

        Assert.True(Tick(buttons: confirm)["pad"].AsBool());
        Assert.True(Tick()["pad"].AsBool());
        _input.Down.Add(0x41);
        Assert.False(Tick()["pad"].AsBool());
        _input.Down.Clear();
        Assert.True(Tick(buttons: confirm)["pad"].AsBool());
        _input.Down.Add(0x28);
        Assert.False(Tick(buttons: 1 << (int)UiButton.Down)["pad"].AsBool());
        _input.Down.Clear();
        _input.Presses.Note(0x20);
        Assert.False(Tick(buttons: confirm)["pad"].AsBool());
        Assert.True(Tick(buttons: confirm)["pad"].AsBool());
    }

    /// <summary>
    /// Places the pointer on the game's screen through a client area of the screen's size.
    /// </summary>
    /// <param name="x">The left offset.</param>
    /// <param name="y">The top offset.</param>
    /// <returns>The client place.</returns>
    private static ClientPointer Over(int x, int y) => new(x, y, 640, 480);

    /// <summary>
    /// Reads the buttons' bits of an event.
    /// </summary>
    /// <param name="payload">The event's payload.</param>
    /// <returns>The bits.</returns>
    private static int Buttons(RubyHash payload) => payload["buttons"].AsInt();

    /// <summary>
    /// Waits some ticks, then clicks the left button once at a place.
    /// </summary>
    /// <param name="wait">The ticks between the last click's press and this one's.</param>
    /// <param name="x">The left offset of the click.</param>
    /// <returns>Whether the click's press is a double click.</returns>
    private bool Click(int wait, int x)
    {
        _input.Pointer = Over(x, 0);
        for (var tick = 1; tick < wait; tick++)
        {
            Tick();
        }

        _input.Down.Add(LeftButton);
        var isDouble = Tick()["double"].AsBool();
        _input.Down.Clear();
        return isDouble;
    }

    /// <summary>
    /// Runs a tick with the model's input and takes its event, or the last one posted while the tick
    /// posts none, as the scripts hold it.
    /// </summary>
    /// <param name="input">The model's input, none by default.</param>
    /// <param name="buttons">The game's buttons of the tick, none by default.</param>
    /// <returns>The event's payload.</returns>
    private RubyHash Tick(RubyHash? input = null, int buttons = 0)
    {
        List<RubyHash> posted = Posted(input, buttons);
        _held = posted.Count > 0 ? posted[0] : _held;
        return _held ?? throw new InvalidOperationException("No tick posted an event yet.");
    }

    /// <summary>
    /// Runs a tick with the model's input and lists the events it posted.
    /// </summary>
    /// <param name="input">The model's input, none by default.</param>
    /// <param name="buttons">The game's buttons of the tick, none by default.</param>
    /// <returns>The events' payloads.</returns>
    private List<RubyHash> Posted(RubyHash? input = null, int buttons = 0)
    {
        input ??= [];
        input["screen"] = new RubyArray { 640, 480 };
        List<(string Topic, RubyValue Payload)> events = _ui.Tick(new RubyHash { { UiHost.ButtonsKey, buttons }, { InputModel.ModelName, input } });
        return [.. events.Where(item => item.Topic == InputModel.EventTopic).Select(item => item.Payload.AsHash())];
    }
}
