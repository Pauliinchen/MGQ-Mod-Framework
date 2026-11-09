//----------------------------------------------------------------
//  TreePointerTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Checked a slider moved by its step within its bounds and a rating filled by a click
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Opened the context menu as a root of the UI layer
//      Paulinchen  2026-11-05: Checked that a disabled part lights no more and opens no context menu
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Tree;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the pointer in the component tree: what it hovers and where a part shifted from its place
/// is hit, clicks that raise a window, close a root outside them or buzz under a root that holds the
/// game's buttons, the tooltip, the context menu of the new UI layer, and the slider and the
/// rating whose numbers the arrows and the pointer pick.
/// </summary>
public sealed class TreePointerTests
{
    /// <summary>
    /// Windows' code of the right mouse button.
    /// </summary>
    private const int RightButton = 0x02;

    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts that the pointer hovers the deepest child under it that takes the mouse, and its parent
    /// once that child lets the pointer through, which lights no more once disabled; that a root with its mouse on its parts lets the
    /// pointer through to the root below but on a part that takes clicks or shows a tooltip; and that
    /// a game window a mod put a button on takes the pointer only on the button, which a click clicks
    /// without the focus, so confirm stays the game window's.
    /// </summary>
    [Fact]
    public void Hover_GoesToTheDeepestPartThatTakesTheMouse()
    {
        _tree.Point(30, 25);
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("padding", 10)),
            Node(2, 1, "box", ("padding", 10)),
            Node(3, 2, "custom", ("measured", Pair(50, 20)))));
        Assert.Equal([20, 20, 50, 20], Rect(report, 3));
        Assert.Equal((1, 1), (report["states"].AsHash()[3].AsInt(), report["over"].AsInt()));
        report = _tree.Frame(Set(3, "mouse", false));
        Assert.Equal((1, 0), (report["states"].AsHash()[2].AsInt(), report["states"].AsHash()[3].AsInt()));
        Assert.Equal(0, _tree.Frame(Set(2, "enabled", false))["states"].AsHash()[2].AsInt());

        var parts = new TreeHarness();
        parts.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(200, 200))),
            Node(2, 1, "button", ("measured", Pair(200, 200))),
            Node(5, null, "box", ("at", Pair(0, 0)), ("size", Pair(100, 100)), ("mouse_parts", true), ("z", 2000)),
            Node(6, 5, "label", ("measured", Pair(100, 20))),
            Node(7, 5, "label", ("measured", Pair(100, 20)), ("tooltip", true))));
        parts.Point(10, 5);
        Assert.Contains("2 click", Events(parts.Click()));
        parts.Point(10, 30);
        Assert.Equal(5, parts.Frame()["over"].AsInt());

        var adopted = new TreeHarness();
        adopted.Frame(Adds(
            Node(1, null, "adopted", ("at", Pair(100, 100)), ("size", Pair(200, 120)), ("padding", 12)),
            Node(2, 1, "button", ("measured", Pair(60, 24)))));
        adopted.Point(250, 200);
        Assert.True(adopted.Frame()["over"].IsNil);
        adopted.Point(130, 120);
        report = adopted.Frame();
        Assert.Equal(1, report["over"].AsInt());
        Assert.Equal(["2 hover true"], Events(report));
        Assert.Equal(["2 click"], Events(adopted.Click()));
        Assert.Empty(Events(adopted.Frame(buttons: Triggered(UiButton.Confirm))));
    }

    /// <summary>
    /// Asserts that the pointer hits a part shifted from its place where it is drawn and passes over
    /// it once it is inert, and that a root drawn shifted, as one that follows a character is, takes
    /// the pointer where it is drawn.
    /// </summary>
    [Fact]
    public void Pointer_HitsAPartWhereItIsDrawn()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 100))),
            Node(2, 1, "stack", ("offset", Pair(50, 0))),
            Node(3, 2, "button", ("measured", Pair(40, 20)))));
        _tree.Point(60, 10);
        Assert.Contains("3 click", Events(_tree.Click()));
        _tree.Point(10, 10);
        Assert.DoesNotContain("3 click", Events(_tree.Click()));
        _tree.Frame(Set(2, "inert", true));
        _tree.Point(60, 10);
        Assert.DoesNotContain("3 click", Events(_tree.Click()));

        var shifted = new TreeHarness();
        shifted.Frame(Adds(Node(1, null, "box", ("at", Pair(0, 0)), ("size", Pair(50, 50)), ("offset", Pair(100, 100)))));
        shifted.Point(110, 110);
        Assert.Equal(1, shifted.Frame()["over"].AsInt());
        shifted.Point(10, 10);
        Assert.True(shifted.Frame()["over"].IsNil);
    }

    /// <summary>
    /// Asserts that a press on the lower of two windows raises it, the report naming the new order,
    /// so the pointer then hits it where the two overlap; that a click outside a root that closes on
    /// one closes it with the cancel sound and goes no further, while a click on it or on a root above
    /// it does not and a root that guards its cancel is asked instead; and that a button of a root
    /// under another that holds the game's buttons buzzes instead of clicking until it no longer is.
    /// </summary>
    [Fact]
    public void Click_RaisesAWindowClosesARootOutsideAndBuzzesUnderAnother()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(100, 100))),
            Node(5, null, "window", ("at", Pair(50, 50)), ("size", Pair(100, 100)))));
        Assert.Equal(new RubyArray { 1, 5 }, report["order"]);
        _tree.Point(20, 20);
        _tree.Input.Down.Add(LeftButton);
        report = _tree.Frame();
        _tree.Input.Down.Remove(LeftButton);
        _tree.Frame();
        Assert.Equal(new RubyArray { 5, 1 }, report["order"]);
        _tree.Point(120, 120);
        Assert.Equal(5, _tree.Frame()["over"].AsInt());
        _tree.Point(75, 75);
        Assert.Equal(1, _tree.Frame()["over"].AsInt());

        var outside = new TreeHarness();
        outside.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(300, 300))),
            Node(2, 1, "button", ("measured", Pair(60, 24))),
            Node(5, null, "box", ("at", Pair(400, 0)), ("size", Pair(100, 100)), ("close_outside", true)),
            Node(9, null, "box", ("at", Pair(420, 20)), ("size", Pair(40, 40)), ("z", 2000))));
        outside.Point(430, 30);
        Assert.DoesNotContain("5 close outside", Events(outside.Click()));
        outside.Point(450, 80);
        Assert.DoesNotContain("5 close outside", Events(outside.Click()));
        outside.Point(10, 10);
        RubyHash closed = outside.Click();
        Assert.Contains("5 close outside", Events(closed));
        Assert.DoesNotContain("2 click", Events(closed));
        Assert.Contains("cancel", Cues(closed));
        outside.Frame(Adds(Node(6, null, "box", ("at", Pair(400, 0)), ("size", Pair(100, 100)), ("close_outside", true), ("cancel_guard", true))));
        outside.Frame();
        Assert.Contains("6 cancel outside", Events(outside.Click()));

        var under = new TreeHarness();
        under.Frame(Adds(
            Node(1, null, "box", ("at", Pair(0, 0)), ("size", Pair(100, 40)), ("held_under", true)),
            Node(2, 1, "button", ("measured", Pair(60, 24))),
            Node(3, 1, "label", ("measured", Pair(60, 24)), ("clicks", true))));
        under.Frame();
        under.Point(10, 10);
        RubyHash buzzed = under.Click();
        Assert.DoesNotContain("2 click", Events(buzzed));
        Assert.Contains("buzzer", Cues(buzzed));
        under.Frame(Set(1, "held_under", false));
        Assert.Contains("2 click", Events(under.Click()));
    }

    /// <summary>
    /// Asserts that a part a key gives the focus shows its tooltip at once under it, kept while
    /// another window is in front and gone when the focus moves on, and that a tooltip shows once the
    /// pointer rested on its part for the tooltip's frames and goes when the pointer moves.
    /// </summary>
    [Fact]
    public void Tooltip_ShowsUnderAKeyFocusOrAfterThePointerRested()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(10, 20))),
            Node(2, 1, "button", ("measured", Pair(40, 20))),
            Node(3, 1, "button", ("measured", Pair(40, 20)), ("tooltip", true))));

        Assert.Equal(new RubyArray { 3, 10, 60, true }, _tree.Repeat(UiButton.Down)["tooltip"]);
        _tree.Input.Front = false;
        Assert.False(_tree.Frame().ContainsKey("tooltip"));
        _tree.Input.Front = true;
        RubyHash moved = _tree.Repeat(UiButton.Up);
        Assert.True(moved.ContainsKey("tooltip") && moved["tooltip"].IsNil);

        var rested = new TreeHarness();
        rested.Point(10, 10);
        rested.Frame(Adds(Node(1, null, "window"), Node(2, 1, "custom", ("measured", Pair(50, 20)), ("tooltip", true))));
        for (int tick = 1; tick < ComponentTree.TooltipFrames; tick++)
        {
            Assert.True(rested.Frame()["tooltip"].IsNil);
        }

        Assert.Equal(new RubyArray { 2, 10, 10 }, rested.Frame()["tooltip"]);
        rested.Point(11, 10);
        RubyHash gone = rested.Frame();
        Assert.True(gone.ContainsKey("tooltip") && gone["tooltip"].IsNil);
    }

    /// <summary>
    /// Asserts that in the new UI layer a right click on a part with a context menu focuses it and
    /// opens the menu at the pointer while one beside it closes the window as cancel would and one on
    /// the part disabled only buzzes, that a
    /// right click outside the open menu closes the menu alone, that the Menu key opens the menu of
    /// the focused part under it, and that a gamepad's confirm held half a second opens it without
    /// pressing the part while a short press presses it as it is let go; today's other roots take no
    /// right click.
    /// </summary>
    [Fact]
    public void ContextMenu_OpensByRightClickTheMenuKeyOrAHeldConfirm()
    {
        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", ("measured", Pair(40, 20))),
            Node(3, 1, "button", ("measured", Pair(40, 20)), ("context_menu", true)),
            Node(4, 1, "label", ("measured", Pair(40, 20)))));
        int[] button = Rect(opened, 3);
        int[] label = Rect(opened, 4);
        _tree.Point(button[0] + 5, button[1] + 5);
        List<string> onButton = RightClick(_tree);
        _tree.Point(label[0] + 5, label[1] + 5);
        List<string> beside = RightClick(_tree);

        Assert.Equal(["3 focus", $"3 context {button[0] + 5} {button[1] + 5}"], onButton.FindAll(line => line.StartsWith("3 focus") || line.Contains("context") || line.Contains("close")));
        Assert.Contains("1 close", beside);

        var disabled = new TreeHarness();
        RubyHash greyed = disabled.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", ("measured", Pair(40, 20)), ("context_menu", true), ("enabled", false))));
        disabled.Point(Rect(greyed, 2)[0] + 5, Rect(greyed, 2)[1] + 5);
        disabled.Input.Down.Add(RightButton);
        RubyHash refused = disabled.Frame();
        disabled.Input.Down.Remove(RightButton);
        Assert.Equal([UiCue.Buzzer], Cues(refused));
        Assert.DoesNotContain(Events(refused).Concat(Events(disabled.Frame())), line => line.Contains("context") || line.Contains("close"));

        var open = new TreeHarness();
        open.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(200, 200))),
            Node(2, 1, "button", ("measured", Pair(40, 20)), ("context_menu", true)),
            Node(5, null, "dialog", ("at", Pair(300, 0)), ("layer", true), ("closable", true), ("close_outside", true)),
            Node(6, 5, "button", ("measured", Pair(60, 20)))));
        open.Frame();
        open.Point(10, 10);
        List<string> closedMenu = RightClick(open);
        Assert.Contains("5 close", closedMenu);
        Assert.DoesNotContain(closedMenu, line => line.StartsWith("1 close") || line.Contains("context"));

        var menu = new TreeHarness();
        RubyHash shown = menu.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("context_menu", true)),
            Node(2, 1, "button", ("measured", Pair(40, 20)))));
        int[] part = Rect(shown, 2);
        string context = $"1 context {part[0]} {part[1] + part[3]}";
        Assert.Equal([context], Events(menu.Press(key: ComponentTree.MenuKey)));
        int confirm = Triggered(UiButton.Confirm) | Repeated(UiButton.Confirm) | Held(UiButton.Confirm);
        var held = new List<string>(Events(menu.Frame(buttons: confirm)));
        for (int tick = 0; tick < 30; tick++)
        {
            held.AddRange(Events(menu.Frame(buttons: Held(UiButton.Confirm))));
        }

        held.AddRange(Events(menu.Frame()));
        Assert.Equal([context], held);
        Assert.Empty(Events(menu.Frame(buttons: confirm)));
        Assert.Equal(["2 click"], Events(menu.Frame()));

        var today = new TreeHarness();
        RubyHash todayOpened = today.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", ("measured", Pair(40, 20))),
            Node(5, null, "dialog", ("at", Pair(300, 0)), ("closable", true), ("close_outside", true)),
            Node(6, 5, "button", ("measured", Pair(60, 20)))));
        today.Frame();
        today.Point(Rect(todayOpened, 2)[0] + 5, Rect(todayOpened, 2)[1] + 5);
        Assert.DoesNotContain(RightClick(today), line => line.Contains("close") || line.Contains("context"));
    }

    /// <summary>
    /// Asserts that a slider steps by its step within its bounds by LEFT and RIGHT, staying silent at
    /// a bound, while DOWN moves on; that a click sets the number at the pointer and a drag follows
    /// the pointer until the button is let go, held within the bounds past either end of the track;
    /// and that a number the scripts give in between goes to the nearest step.
    /// </summary>
    [Fact]
    public void Slider_MovesByItsStepWithinItsBoundsByArrowsAClickAndADrag()
    {
        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(300, 100))),
            Node(2, 1, "slider", ("number", 60), ("number_min", 0), ("number_max", 100), ("number_step", 10), ("track", Pair(7, 7)),
                 ("at", Pair(0, 0)), ("size", Pair(214, 24))),
            Node(3, 1, "button", ("at", Pair(0, 40)), ("size", Pair(100, 24)))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        RubyHash right = _tree.Repeat(UiButton.Right);
        Assert.Equal(["2 number 70"], Events(right));
        Assert.Equal([UiCue.Cursor], Cues(right));
        Assert.Equal(["2 number 80", "2 number 90", "2 number 100"], [.. Enumerable.Range(0, 3).SelectMany(_ => Events(_tree.Repeat(UiButton.Right)))]);
        RubyHash atBound = _tree.Repeat(UiButton.Right);
        Assert.Equal([], Events(atBound));
        Assert.Equal([], Cues(atBound));
        Assert.Equal(["2 number 90"], Events(_tree.Repeat(UiButton.Left)));
        Assert.Equal(3, Focus(_tree.Repeat(UiButton.Down)));

        int[] slider = Rect(opened, 2);
        int left = slider[0] + 7;
        int y = slider[1] + 10;
        _tree.Point(left + 100, y);
        _tree.Frame();
        Assert.Contains("2 number 50", Events(_tree.Click()));

        _tree.Point(left + 163, y);
        _tree.Input.Down.Add(LeftButton);
        Assert.Contains("2 number 80", Events(_tree.Frame()));
        _tree.Point(left - 5, y);
        Assert.Equal(["2 number 0"], Events(_tree.Frame()));
        _tree.Point(left + 260, y);
        Assert.Equal(["2 number 100"], Events(_tree.Frame()));
        _tree.Input.Down.Remove(LeftButton);
        _tree.Frame();
        _tree.Point(left + 100, y);
        Assert.DoesNotContain(Events(_tree.Frame()), line => line.Contains("number"));

        Assert.Equal(["2 number 30"], Events(_tree.Frame(Set(2, "number", 34))));
    }

    /// <summary>
    /// Asserts that a slider shown as a rating shows the star under the pointer, fills up to the star
    /// clicked and empties on a click on its last filled star, while one that only shows its stars
    /// takes neither.
    /// </summary>
    [Fact]
    public void Rating_FillsUpToTheStarClickedAndEmptiesOnItsLastFilledStar()
    {
        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(300, 100))),
            Node(2, 1, "slider", ("number", 1), ("number_min", 0), ("number_max", 3), ("track", Pair(2, 2)), ("cells", 26),
                 ("at", Pair(0, 0)), ("size", Pair(80, 28))),
            Node(3, 1, "slider", ("number", 1), ("number_min", 0), ("number_max", 3), ("track", Pair(2, 2)), ("cells", 26), ("acts", false),
                 ("at", Pair(0, 40)), ("size", Pair(80, 28)))));
        int[] stars = Rect(opened, 2);
        _tree.Point(stars[0] + 2 + 52 + 5, stars[1] + 10);
        Assert.Contains("2 preview 3", Events(_tree.Frame()));
        Assert.Contains("2 number 3", Events(_tree.Click()));
        Assert.Contains("2 number 0", Events(_tree.Click()));

        int[] shown = Rect(opened, 3);
        _tree.Point(shown[0] + 2 + 52 + 5, shown[1] + 10);
        _tree.Frame();
        Assert.DoesNotContain(Events(_tree.Click()), line => line.StartsWith("3 ", System.StringComparison.Ordinal));
    }

    /// <summary>
    /// Clicks the right button where the pointer is: one frame down, one frame up.
    /// </summary>
    /// <param name="tree">The tree.</param>
    /// <returns>The events of both frames.</returns>
    private static List<string> RightClick(TreeHarness tree)
    {
        tree.Input.Down.Add(RightButton);
        List<string> down = Events(tree.Frame());
        tree.Input.Down.Remove(RightButton);
        return [.. down.Concat(Events(tree.Frame()))];
    }
}
