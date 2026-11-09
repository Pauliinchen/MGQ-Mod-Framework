//----------------------------------------------------------------
//  LayoutModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Replaced the replay of the scripts' layout with one flow of a box moved and put back
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of the drags, the tick and the places kept
//                            - Read the places kept as their zone and offset back in pixels
//                            - Checked that a place stays in its corner at another screen size and beside its part
//                            - Checked that an older place in pixels is turned into its zone once
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Checked drags and stored places within the most size
//                            - Checked boxes that resize in height alone or do not move
//                            - Checked Alt, the button and the pointer read from the input model
//                            - Checked that an unregistered box is not dragged
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the boxes the player arranges: a box moved and put back, the limits of each box's drag,
/// the input read from the input model, the overlay and the places kept as their zone and offset.
/// </summary>
public sealed class LayoutModelTests
{
    /// <summary>
    /// Windows' code of the left mouse button.
    /// </summary>
    private const int LeftButton = 0x01;

    /// <summary>
    /// The bridge the models post on.
    /// </summary>
    private readonly UiContext _ui = new();

    /// <summary>
    /// What the input model reads.
    /// </summary>
    private readonly FakeInput _input = new();

    /// <summary>
    /// The layout under test.
    /// </summary>
    private readonly LayoutModel _layout;

    /// <summary>
    /// Adds the input model and the layout to a host on the test's bridge, in the order the scripts
    /// put them in the tick.
    /// </summary>
    public LayoutModelTests()
    {
        var host = new UiHost(_ui.Context);
        var input = new InputModel(host, _input);
        _layout = new LayoutModel(host, input);
        host.Add(input);
        host.Add(_layout);
    }

    /// <summary>
    /// Asserts that a default off the screen is pulled onto it at the box's least size, that an Alt
    /// drag moves the box and keeps its place, and that an Alt double click on it forgets the place,
    /// putting the box back where its default lies.
    /// </summary>
    [Fact]
    public void Move_KeepsThePlaceUntilADoubleClick()
    {
        Register("box", 200, 100, 0, 0, "both", true, RubyNil.Value);

        RubyArray pulled = Rect("box", 600, -50, 100, 50);
        string moved = DragFrom("box", new LayoutRect(20, 30, 300, 120), (50, 60), (100, 80));
        RubyArray kept = Rect("box", 20, 30, 300, 120);
        var at = new LayoutRect(70, 50, 300, 120);
        Next(true, true, (100, 80), Offer("box", at), true);
        Next(true, false, (100, 80), Offer("box", at));
        bool forgot = Next(true, true, (100, 80), Offer("box", at), true)
            .Any(item => item.Payload.AsHash().TryGetValue("store", out RubyValue? store) && store.AsHash().TryGetValue("box", out RubyValue? place) && place.IsNil);

        Assert.Equal([440, 0, 200, 100], pulled.Take(4).Select(value => value.AsInt()));
        Assert.Equal("70,50,300,120", moved);
        Assert.Equal([70, 50, 300, 120], kept.Take(4).Select(value => value.AsInt()));
        Assert.True(forgot);
        Assert.Equal([20, 30, 300, 120], Rect("box", 20, 30, 300, 120).Take(4).Select(value => value.AsInt()));
    }

    /// <summary>
    /// Asserts that Alt drags follow each box's limits: a corner dragged past the most size stops
    /// there, as does a left edge dragged away, and a stored place larger than the most size draws at
    /// the most size; a box that resizes in height alone keeps its default's width; a box that does
    /// not move ignores a drag inside it and resizes only by its right and bottom sides, keeping its
    /// default's corner; and a box offered without registering is not dragged and keeps no place.
    /// </summary>
    [Fact]
    public void Drag_FollowsTheLimitsOfEachBox()
    {
        Register("box", 100, 50, 200, 120, "both", true, RubyNil.Value);
        Rect("box", 20, 20, 150, 80);
        string corner = DragFrom("box", new LayoutRect(20, 20, 150, 80), (168, 98), (500, 400));
        Register("wide", 100, 50, 200, 120, "both", true, RubyNil.Value);
        Rect("wide", 300, 20, 150, 80);
        string edge = DragFrom("wide", new LayoutRect(300, 20, 150, 80), (301, 50), (0, 50));
        Register("big", 0, 0, 300, 200, "both", true, "0,0,600,400");

        Assert.Equal(["20,20,200,120", "250,20,200,80"], [corner, edge]);
        Assert.Equal([0, 0, 300, 200], Rect("big", 10, 10, 100, 100).Take(4).Select(value => value.AsInt()));

        Register("tall", 0, 40, 0, 0, "height", true, RubyNil.Value);
        Rect("tall", 10, 10, 100, 60);
        string tall = DragFrom("tall", new LayoutRect(10, 10, 100, 60), (108, 68), (300, 200));
        Register("fixed", 0, 0, 0, 0, "both", false, RubyNil.Value);
        Rect("fixed", 100, 100, 100, 100);
        _layout.Arrange(true, true, true, (150, 150), 640, 480, Offer("fixed", new LayoutRect(100, 100, 100, 100)));
        bool insideDrags = _ui.Drain().Any(item => item.Payload.AsHash().ContainsKey("dragging"));
        Next(false, false, (150, 150), Offer("fixed", new LayoutRect(100, 100, 100, 100)));
        string left = DragFrom("fixed", new LayoutRect(100, 100, 100, 100), (101, 150), (50, 150));
        string bottomRight = DragFrom("fixed", new LayoutRect(100, 100, 100, 100), (198, 198), (250, 260));
        string stray = DragFrom("stray", new LayoutRect(10, 10, 100, 100), (50, 50), (200, 200));

        Assert.Equal("10,10,100,192", tall);
        Assert.False(insideDrags);
        Assert.Equal(["", "100,100,152,162", ""], [left, bottomRight, stray]);
    }

    /// <summary>
    /// Asserts that the frame's tick reads Alt, the left button and the pointer from the input model:
    /// with the game behind another window nothing starts, Alt and a press over a box start a drag,
    /// and Alt held outlines the boxes shown with the one under the mouse, says nothing while that
    /// stays, and hides once Alt is let go.
    /// </summary>
    [Fact]
    public void Tick_ReadsTheInputModelForDragsAndTheOverlay()
    {
        Register("box", 0, 0, 0, 0, "both", true, RubyNil.Value);
        _input.Pointer = new ClientPointer(50, 50, 640, 480);
        _input.Down.UnionWith([LayoutModel.AltKey, LeftButton]);
        _input.Front = false;
        bool behind = Tick(Offer("box", new LayoutRect(10, 10, 100, 100))).Any(item => item.Topic == LayoutModel.EventTopic && item.Payload.AsHash().ContainsKey("dragging"));
        _input.Front = true;
        _input.Down.Clear();
        Tick(Offer("box", new LayoutRect(10, 10, 100, 100)));
        _input.Down.UnionWith([LayoutModel.AltKey, LeftButton]);
        RubyHash started = Layout(Tick(Offer("box", new LayoutRect(10, 10, 100, 100))));

        Assert.False(behind);
        Assert.Equal((true, "box"), (started["dragging"].AsBool(), started["hot"].AsText()));

        var overlay = new LayoutModelTests();
        overlay._input.Down.Add(LayoutModel.AltKey);
        overlay._input.Pointer = new ClientPointer(20, 20, 640, 480);
        RubyHash shown = Layout(overlay.Tick(Offer("tip", new LayoutRect(10, 10, 100, 50))));
        overlay._input.Pointer = new ClientPointer(21, 20, 640, 480);
        List<(string Topic, RubyValue Payload)> same = overlay.Tick(Offer("tip", new LayoutRect(10, 10, 100, 50)));
        overlay._input.Down.Clear();
        RubyHash hidden = Layout(overlay.Tick(Offer("tip", new LayoutRect(10, 10, 100, 50))));

        Assert.Equal((new RubyArray { "tip" }, "tip"), (shown["overlay"], shown["hot"].AsText()));
        Assert.DoesNotContain(same, item => item.Topic == LayoutModel.EventTopic);
        Assert.True(hidden["overlay"].IsNil);
    }

    /// <summary>
    /// Asserts that a box dragged near the bottom right corner keeps its distance from that corner on
    /// a larger screen, and that a box dragged beside another part keeps its offset from that part
    /// wherever the part goes.
    /// </summary>
    [Fact]
    public void StoredPlace_StaysInItsCornerAndBesideItsPart()
    {
        Register("corner", 0, 0, 0, 0, "both", true, RubyNil.Value);
        string corner = DragFrom("corner", new LayoutRect(500, 380, 100, 60), (550, 400), (570, 410), stored: true);
        Register("tip", 0, 0, 0, 0, "both", true, RubyNil.Value);
        _layout.Anchor("tip", new LayoutRect(100, 100, 50, 50));
        string tip = DragFrom("tip", new LayoutRect(150, 100, 80, 40), (160, 110), (170, 130), stored: true);
        _layout.Anchor("tip", new LayoutRect(300, 200, 50, 50));

        Assert.Equal(("bottom_right,-20,-30,100,60", "beside,60,20,80,40"), (corner, tip));
        Assert.Equal(new LayoutRect(680, 510, 100, 60), _layout.Arranged("corner", 800, 600));
        Assert.Equal(new LayoutRect(360, 220, 80, 40), _layout.Arranged("tip", 640, 480));
    }

    /// <summary>
    /// Asserts that an older place in pixels, with spaces and a comma at its end as Ruby reads it, is
    /// turned into its zone and offset once, answered for the settings, and lies where it lay; that a
    /// place already kept that way is not turned again; and that a text naming no place is not turned.
    /// </summary>
    [Fact]
    public void OlderPlace_IsTurnedIntoItsZoneOnce()
    {
        RubyArray older = _ui.Value(LayoutModel.RegisterTopic, new RubyArray { "box", "box", 0, 0, 0, 0, "both", true, " 20, 400 ,200,60,", 640, 480, true }).AsArray();
        RubyArray again = _ui.Value(LayoutModel.RegisterTopic, new RubyArray { "box", "box", 0, 0, 0, 0, "both", true, older[1], 640, 480, true }).AsArray();
        RubyArray word = _ui.Value(LayoutModel.RegisterTopic, new RubyArray { "other", "other", 0, 0, 0, 0, "both", true, "1,2,three,4", 640, 480, true }).AsArray();

        Assert.Equal((true, "bottom_left,20,-20,200,60"), (older[0].AsBool(), older[1].AsText()));
        Assert.True(again[1].IsNil);
        Assert.Equal([20, 400, 200, 60], Rect("box", 0, 0, 10, 10).Take(4).Select(value => value.AsInt()));
        Assert.True(word[1].IsNil);
        Assert.Equal([5, 5, 10, 10], Rect("other", 5, 5, 10, 10).Take(4).Select(value => value.AsInt()));
    }

    /// <summary>
    /// Writes a place the settings keep as its zone and offset in pixels on a screen, as the
    /// scripts' own layout kept it.
    /// </summary>
    /// <param name="text">The place as the settings keep it.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>Such as "70,50,300,120".</returns>
    private static string Pixels(string text, int screenWidth, int screenHeight)
    {
        LayoutRect rect = LayoutModel.Resolve(LayoutModel.ParseStored(text)!.Value, null, screenWidth, screenHeight)!.Value;
        return $"{rect.X},{rect.Y},{rect.Width},{rect.Height}";
    }

    /// <summary>
    /// Lists one box shown, as the scripts offer it.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="rect">Where it lies.</param>
    /// <returns>The boxes shown.</returns>
    private static RubyArray Offer(string id, LayoutRect rect) => [new RubyArray { id, rect.X, rect.Y, rect.Width, rect.Height, 1 }];

    /// <summary>
    /// Finds the layout's event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Layout(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == LayoutModel.EventTopic).Payload.AsHash();

    /// <summary>
    /// Registers a box as the scripts do.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="minWidth">Its least width.</param>
    /// <param name="minHeight">Its least height.</param>
    /// <param name="maxWidth">Its most width, 0 for the screen's.</param>
    /// <param name="maxHeight">Its most height, 0 for the screen's.</param>
    /// <param name="resize">"both", "width", "height" or "none".</param>
    /// <param name="movable">Whether it moves.</param>
    /// <param name="stored">Its place in the settings, nil for none.</param>
    private void Register(string id, int minWidth, int minHeight, int maxWidth, int maxHeight, string resize, bool movable, RubyValue stored) =>
        _ui.Value(LayoutModel.RegisterTopic, new RubyArray { id, id, minWidth, minHeight, maxWidth, maxHeight, resize, movable, stored });

    /// <summary>
    /// Asks where a box draws for a default, the place the layout keeps standing.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="x">The default's left.</param>
    /// <param name="y">Its top.</param>
    /// <param name="width">Its width.</param>
    /// <param name="height">Its height.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>[x, y, width, height, whether the player moved or resized it].</returns>
    private RubyArray Rect(string id, int x, int y, int width, int height, int screenWidth = 640, int screenHeight = 480) =>
        _ui.Value(LayoutModel.RectTopic, new RubyArray { id, x, y, width, height, screenWidth, screenHeight, false }).AsArray();

    /// <summary>
    /// Drags a box with Alt from one point to another and lets go.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="rect">Where it lies.</param>
    /// <param name="from">Where the press goes down.</param>
    /// <param name="to">Where the button is let go.</param>
    /// <param name="stored">Whether to answer the place as the settings keep it rather than in pixels.</param>
    /// <returns>The place the settings keep, in pixels unless asked otherwise; empty when none is kept.</returns>
    private string DragFrom(string id, LayoutRect rect, (int X, int Y) from, (int X, int Y) to, bool stored = false)
    {
        Next(true, true, from, Offer(id, rect), true);
        Next(true, true, to, Offer(id, rect));
        string kept = string.Empty;
        foreach ((string _, RubyValue payload) in Next(true, false, to, Offer(id, rect)))
        {
            if (payload.AsHash().TryGetValue("store", out RubyValue? store) && store.AsHash().TryGetValue(id, out RubyValue? text) && !text.IsNil)
            {
                kept = stored ? text.AsText() : Pixels(text.AsText(), 640, 480);
            }
        }

        // Far enough on that the next press is no double click.
        for (int frame = 0; frame <= LayoutModel.DoubleClickTicks; frame++)
        {
            Next(false, false, to, []);
        }

        return kept;
    }

    /// <summary>
    /// Runs a frame of the layout with the input given, then drains.
    /// </summary>
    /// <param name="alt">Whether Alt is held.</param>
    /// <param name="held">Whether the left button is held.</param>
    /// <param name="position">Where the mouse points.</param>
    /// <param name="offers">The boxes shown.</param>
    /// <param name="wentDown">Whether the button went down in this frame.</param>
    /// <returns>The frame's events.</returns>
    private List<(string Topic, RubyValue Payload)> Next(bool alt, bool held, (int X, int Y) position, RubyArray offers, bool wentDown = false)
    {
        _layout.Arrange(alt, held, wentDown, position, 640, 480, offers);
        return _ui.Drain();
    }

    /// <summary>
    /// Runs a frame's tick through the host, the input model first, then drains.
    /// </summary>
    /// <param name="offers">The boxes shown.</param>
    /// <returns>The frame's events.</returns>
    private List<(string Topic, RubyValue Payload)> Tick(RubyArray offers) =>
        _ui.Tick(new RubyHash { { InputModel.ModelName, new RubyHash { { "screen", new RubyArray { 640, 480 } } } }, { LayoutModel.ModelName, offers } });
}
