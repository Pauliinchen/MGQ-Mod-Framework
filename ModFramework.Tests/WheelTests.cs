//----------------------------------------------------------------
//  WheelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Wrote the cases of pointing and placing in the tests instead of reading a fixture
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Dropped the replay of the wheels' key script, which the in-game suite replaces
//      Paulinchen  2026-11-04: Rewrote the checks as one replay per golden rule and flow tests of the sounds, the scene and
//                              the pointer, and took over the definitions of WheelDefineTests.cs
//                            - Replayed the key script of the wheels' spec
//      Paulinchen  2026-10-31: Checked the boxes of a wheel of boxes and the pick dropped as the count of choices changed
//      Paulinchen  2026-10-29: Moved into the Mod Framework
//                            - Defined the two wheels through their topic
//                            - Checked the pointer pointing, the click taking and the numpad's 0
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Wheels;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the wheels: pointing with the arrows and placing the choices, defining them through
/// their topic, and their sounds, the scene and the pointer through the tick.
/// </summary>
public sealed class WheelTests
{
    /// <summary>
    /// The bridge the wheels post on.
    /// </summary>
    private readonly UiContext _ui = new();

    /// <summary>
    /// What the input model reads.
    /// </summary>
    private readonly FakeInput _input = new() { Pointer = null };

    /// <summary>
    /// Adds the input model and the wheels' topics to a host on the test's bridge and defines MGQ
    /// Online's two wheels: the action wheel with a middle that stays open for the choice, and the
    /// emote wheel without one that closes on confirm.
    /// </summary>
    public WheelTests()
    {
        var host = new UiHost(_ui.Context);
        var input = new InputModel(host, _input);
        host.Add(input);
        WheelModel.RegisterTopics(host, input);
        _ui.Value(WheelModel.DefineTopic, new RubyArray { "wheel", true, false });
        _ui.Value(WheelModel.DefineTopic, new RubyArray { "emotes", false, true });
    }

    /// <summary>
    /// Asserts that a diagonal stays pointed while its arrows are let go a few frames apart and
    /// turns to the side still held once the grace ran out, that opposite arrows point nowhere, and
    /// that a side pressed after another one points to their diagonal.
    /// </summary>
    [Fact]
    public void Steady_KeepsADiagonalForItsGrace()
    {
        var pointer = new WheelPointer();
        WheelArrows downLeft = WheelArrows.Down | WheelArrows.Left;

        string?[] letGo = [.. new[] { downLeft }.Concat(Enumerable.Repeat(WheelArrows.Left, WheelPointer.GraceTicks + 1)).Select(arrows => NameOf(pointer.Steady(arrows)))];
        string?[] opposite = [.. new[] { WheelArrows.Up | WheelArrows.Down, WheelArrows.Up | WheelArrows.Down | WheelArrows.Left, WheelArrows.None }.Select(arrows => NameOf(pointer.Steady(arrows)))];
        string?[] after = [.. new[] { WheelArrows.Up, WheelArrows.Up | WheelArrows.Right, WheelArrows.Up }.Select(arrows => NameOf(pointer.Steady(arrows)))];

        Assert.Equal([.. Enumerable.Repeat("DOWN_LEFT", WheelPointer.GraceTicks), "LEFT", "LEFT"], letGo);
        Assert.Equal([null, "LEFT", null], opposite);
        Assert.Equal(["UP", "UP_RIGHT", "UP_RIGHT"], after);
    }

    /// <summary>
    /// Asserts that the choices start at the top and spread around the wheel as evenly as its eight
    /// directions allow.
    /// </summary>
    [Fact]
    public void Places_SpreadTheChoicesFromTheTop()
    {
        Assert.Equal(["UP", "DOWN_RIGHT", "DOWN_LEFT"], WheelPlaces.Of(3).Select(place => NameOf(place)));
        Assert.Equal(["UP", "RIGHT", "DOWN_RIGHT", "DOWN_LEFT", "LEFT"], WheelPlaces.Of(5).Select(place => NameOf(place)));
        Assert.Equal(["UP", "UP_RIGHT", "RIGHT", "DOWN_RIGHT", "DOWN", "DOWN_LEFT", "LEFT", "UP_LEFT"], WheelPlaces.Of(8).Select(place => NameOf(place)));
    }

    /// <summary>
    /// Asserts that a tick naming a wheel never defined is refused, that a defined wheel opens on its
    /// key, and that defining it again alike answers true and keeps it open, while other settings for
    /// its name and the name of another model are refused.
    /// </summary>
    [Fact]
    public void Define_MakesTheWheelKnownOnceAndAlike()
    {
        RubyHash unknown = _ui.Call(UiHost.TickTopic, Input("sample"))!;
        bool defined = _ui.Value(WheelModel.DefineTopic, new RubyArray { "sample", true, false }).AsBool();
        bool opened = _ui.Tick(Input("sample")).Any(item => item.Topic == WheelModel.EventTopic && item.Payload.AsHash()["open"].AsBool());

        bool again = _ui.Value(WheelModel.DefineTopic, new RubyArray { "sample", true, false }).AsBool();
        RubyHash other = _ui.Call(WheelModel.DefineTopic, new RubyArray { "sample", false, false })!;
        RubyHash input = _ui.Call(WheelModel.DefineTopic, new RubyArray { InputModel.ModelName, true, false })!;
        RubyHash closed = Event(_ui.Tick(Input("sample")))!;

        Assert.Equal(BridgeEnvelope.BadRequest, unknown["error"].AsText());
        Assert.True(defined && opened && again);
        Assert.Equal(BridgeEnvelope.BadRequest, other["error"].AsText());
        Assert.Equal(BridgeEnvelope.BadRequest, input["error"].AsText());
        Assert.Equal(("its key", false), (closed["reason"].AsText(), closed["open"].AsBool()));
    }

    /// <summary>
    /// Asserts the wheels' sounds and the scene: the action wheel opens on its middle with its places
    /// and the cursor sound, a changed count of choices moves the places and drops the pick to the
    /// middle, and the owner closes it through its topic; its key closes it with the cancel sound and
    /// a scene that no longer leaves it free closes it silently; the emote wheel opens on nothing,
    /// takes the emote pointed at silently, drops its pick as the count changes, and closes without a
    /// choice with the cancel sound.
    /// </summary>
    [Fact]
    public void Wheel_TellsItsSoundsAndFollowsTheCountAndTheScene()
    {
        RubyHash opened = Event(Tick("wheel", key: true, count: 4))!;
        Tick("wheel", arrows: WheelArrows.Right, count: 4);
        RubyHash fewer = Event(Tick("wheel", count: 3))!;
        _ui.Value(WheelModel.CloseTopic, new RubyArray { "wheel" });
        RubyHash? closed = Event(Tick("wheel", arrows: WheelArrows.Down, count: 3));
        Tick("wheel", key: true, count: 2);
        RubyHash byKey = Event(Tick("wheel", key: true, count: 2))!;
        Tick("wheel", key: true, count: 2);
        RubyHash byScene = Event(_ui.Tick(new RubyHash { { "wheel", new RubyArray { "an event started", false, false, false, 0, 2 } } }))!;

        Assert.Equal((true, -1L, new RubyArray { 0, 2, 4, 6 }, new RubyArray { UiCue.Cursor }), (opened["open"].AsBool(), opened["selected"].AsLong(), opened["places"], opened[UiCue.Key]));
        Assert.Equal((WheelModel.Center, new RubyArray { 0, 3, 5 }), (fewer["selected"].AsInt(), fewer["places"]));
        Assert.Null(closed);
        Assert.Equal(("its key", new RubyArray { UiCue.Cancel }), (byKey["reason"].AsText(), byKey[UiCue.Key]));
        Assert.Equal(("an event started", new RubyArray()), (byScene["reason"].AsText(), byScene[UiCue.Key]));

        Tick("emotes", key: true, count: 8);
        Tick("emotes", arrows: WheelArrows.Down, count: 8);
        RubyHash taken = Event(Tick("emotes", confirm: true, count: 8))!;
        Tick("emotes", key: true, count: 4);
        Tick("emotes", arrows: WheelArrows.Right, count: 4);
        RubyHash dropped = Event(Tick("emotes", count: 2))!;
        RubyHash empty = Event(Tick("emotes", confirm: true, count: 2))!;

        Assert.Equal((false, 4, new RubyArray()), (taken["open"].AsBool(), taken["take"].AsInt(), taken[UiCue.Key]));
        Assert.True(dropped["selected"].IsNil);
        Assert.Equal((false, true, new RubyArray { UiCue.Cancel }), (empty["open"].AsBool(), empty["take"].IsNil, empty[UiCue.Key]));
    }

    /// <summary>
    /// Asserts that on a ring the pointer reaches, the pointer moving over a choice's direction
    /// points at it and over the middle at the middle, a pointer at rest leaves the arrows' pick, a
    /// click takes the pick and a click outside the ring closes the wheel; and that on a wheel of
    /// boxes the pointer points at the box it lies in, the middle of a wheel without one leaving the
    /// pick, and a click outside the boxes closes it.
    /// </summary>
    [Fact]
    public void Pointer_PointsAndAClickTakes()
    {
        RubyArray ring = [320, 240, 20, 100];
        Point(320, 240);
        Tick("wheel", key: true, count: 4, ring: ring);
        Point(380, 240);
        RubyHash right = Event(Tick("wheel", count: 4, ring: ring))!;
        RubyHash byArrow = Event(Tick("wheel", arrows: WheelArrows.Up, count: 4, ring: ring))!;
        RubyHash? resting = Event(Tick("wheel", count: 4, ring: ring));
        Point(322, 238);
        RubyHash middle = Event(Tick("wheel", count: 4, ring: ring))!;
        Point(320, 300);
        RubyHash taken = Click("wheel", 4, ring)!;
        Point(600, 40);
        RubyHash outside = Click("wheel", 4, ring)!;

        Assert.Equal([2, 0, WheelModel.Center, 4], new[] { right, byArrow, middle, taken }.Select(each => each["selected"].AsInt()));
        Assert.Null(resting);
        Assert.Equal(4, taken["take"].AsInt());
        Assert.Equal(("a click outside it", false), (outside["reason"].AsText(), outside["open"].AsBool()));

        RubyArray hub = [320, 240, 10, 100];
        RubyArray boxes = [new RubyArray { 0, 220, 100, 200, 28 }, new RubyArray { 6, 80, 226, 200, 28 }, new RubyArray { WheelModel.Center, 302, 222, 36, 36 }];
        Point(320, 240);
        Tick("emotes", key: true, count: 4, ring: hub, boxes: boxes);
        Point(300, 110);
        RubyHash up = Event(Tick("emotes", count: 4, ring: hub, boxes: boxes))!;
        Point(100, 230);
        RubyHash left = Event(Tick("emotes", count: 4, ring: hub, boxes: boxes))!;
        Point(320, 240);
        RubyHash? centre = Event(Tick("emotes", count: 4, ring: hub, boxes: boxes));
        Point(600, 40);
        RubyHash outsideBoxes = Click("emotes", 4, hub, boxes)!;

        Assert.Equal([0, 6], new[] { up, left }.Select(each => each["selected"].AsInt()));
        Assert.Null(centre);
        Assert.Equal(("a click outside it", false), (outsideBoxes["reason"].AsText(), outsideBoxes["open"].AsBool()));
    }

    /// <summary>
    /// Builds a tick whose wheel's key went down.
    /// </summary>
    /// <param name="wheel">The wheel's name.</param>
    /// <returns>The tick.</returns>
    private static RubyHash Input(string wheel) => new() { { wheel, new RubyArray { true, true, false, false, 0, 3 } } };

    /// <summary>
    /// Finds the wheels' event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event, null for none.</returns>
    private static RubyHash? Event(List<(string Topic, RubyValue Payload)> events) =>
        events.Where(item => item.Topic == WheelModel.EventTopic).Select(item => item.Payload.AsHash()).SingleOrDefault();

    /// <summary>
    /// Names a direction as the scripts name it.
    /// </summary>
    /// <param name="direction">The direction, null for none.</param>
    /// <returns>Its name, such as "UP_RIGHT", null for none.</returns>
    private static string? NameOf(WheelDirection? direction) => direction switch
    {
        null => null,
        WheelDirection.UpRight => "UP_RIGHT",
        WheelDirection.DownRight => "DOWN_RIGHT",
        WheelDirection.DownLeft => "DOWN_LEFT",
        WheelDirection.UpLeft => "UP_LEFT",
        { } plain => plain.ToString().ToUpperInvariant(),
    };

    /// <summary>
    /// Puts the pointer on the game's screen.
    /// </summary>
    /// <param name="x">Its left.</param>
    /// <param name="y">Its top.</param>
    private void Point(int x, int y) => _input.Pointer = new ClientPointer(x, y, 640, 480);

    /// <summary>
    /// Presses the left button in a wheel's frame and lets it go in the next.
    /// </summary>
    /// <param name="wheel">The wheel's name.</param>
    /// <param name="count">How many choices it has.</param>
    /// <param name="ring">Where it shows for the pointer.</param>
    /// <param name="boxes">The boxes of a wheel of boxes, null for a ring.</param>
    /// <returns>The wheel's event of the frame the button went down in, null for none.</returns>
    private RubyHash? Click(string wheel, int count, RubyArray ring, RubyArray? boxes = null)
    {
        _input.Down.Add(0x01);
        RubyHash? told = Event(Tick(wheel, count: count, ring: ring, boxes: boxes));
        _input.Down.Clear();
        Tick(wheel, count: count, ring: ring, boxes: boxes);
        return told;
    }

    /// <summary>
    /// Builds a wheel's input and runs its frame.
    /// </summary>
    /// <param name="wheel">The wheel's name.</param>
    /// <param name="key">Whether its key went down.</param>
    /// <param name="confirm">Whether confirm went down.</param>
    /// <param name="arrows">The arrows held.</param>
    /// <param name="count">How many choices it has.</param>
    /// <param name="ring">Where it shows for the pointer, null for a wheel the pointer does not reach.</param>
    /// <param name="boxes">The boxes of a wheel of boxes, null for a ring.</param>
    /// <returns>The frame's events.</returns>
    private List<(string Topic, RubyValue Payload)> Tick(string wheel, bool key = false, bool confirm = false, WheelArrows arrows = WheelArrows.None, int count = 0, RubyArray? ring = null, RubyArray? boxes = null) =>
        _ui.Tick(new RubyHash
        {
            { InputModel.ModelName, new RubyHash() },
            { wheel, new RubyArray { true, key, false, confirm, (long)arrows, count, ring ?? (RubyValue)RubyNil.Value, boxes ?? (RubyValue)RubyNil.Value } },
        });
}
