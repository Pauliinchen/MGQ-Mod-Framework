//----------------------------------------------------------------
//  TreeFocusTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that a grid of cards that leaves its ends hands the focus to the parts above and below
//                            - Checked that UP and DOWN into a row land on its part nearest across
//                            - Moved UP from under a list beside a button onto the list, which lies above it
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Checked that the focus asked into a reading pane lands on its part marked autofocus
//                            - Checked that the arrows pick the box that lies their way from a box picked as a whole
//                            - Checked the focus of a list whose tab page hides going into the page shown, without a row of
//                              tabs as one key stop
//                            - Checked that a dialog closing gives the focus to the part beside one that turned off under it
//                            - Checked that a window joined to a game window takes the focus only when the scripts hand it over
//      Paulinchen  2026-11-05: Checked that a box the keys enter is told as the focus goes inside and comes out
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
/// Covers where the component tree moves the focus: the arrows and Tab by where the parts lie, out
/// of lists, out of grids of cards that leave their ends and between the columns of a row, the parts that are key stops, the focus coming back
/// as roots close, hide or are made anew or the part that had it turned off, a window joined to a game window, modal roots, the old focus rules outside the new UI layer,
/// containers the keys enter, slides, and the part marked autofocus in a reading pane.
/// </summary>
public sealed class TreeFocusTests
{
    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts that LEFT and RIGHT move the focus along a row of buttons without going round, DOWN
    /// leaves the row, Tab and Shift+Tab go round the window, and the arrows move on from a focused
    /// button that was turned off; that DOWN in a grid moves to the cell below and out from its last
    /// row; that UP and DOWN pass over a part beside the one they leave; and that an arrow that finds
    /// nothing tells a root that asks for it leave with the arrow's way.
    /// </summary>
    [Fact]
    public void Arrows_MoveTheFocusByWhereThePartsLie()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "button", Measured(40, 20)),
            Node(4, 2, "button", Measured(40, 20)),
            Node(5, 2, "button", Measured(40, 20)),
            Node(6, 1, "button", Measured(40, 20))));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(5, Focus(_tree.Repeat(UiButton.Right)));
        Assert.Null(Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(6, Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(3, Focus(_tree.Press(key: ComponentTree.TabKey)));
        _tree.Input.Down.Add(ComponentTree.ShiftKey);
        _tree.Frame();
        Assert.Equal(6, Focus(_tree.Press(key: ComponentTree.TabKey)));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        _tree.Frame(Set(3, "enabled", false));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Right)));

        var grid = new TreeHarness();
        grid.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "grid", ("layout", "grid"), ("columns", new RubyArray { RubyNil.Value, RubyNil.Value })),
            Node(3, 2, "button", Measured(40, 20)),
            Node(4, 2, "button", Measured(40, 20)),
            Node(5, 2, "button", Measured(40, 20)),
            Node(6, 2, "button", Measured(40, 20)),
            Node(7, 1, "button", Measured(40, 20))));
        Assert.Equal(5, Focus(grid.Repeat(UiButton.Down)));
        Assert.Equal(7, Focus(grid.Repeat(UiButton.Down)));

        var beside = new TreeHarness();
        beside.Frame(Adds(
            Node(1, null, "window", ("size", Pair(300, 200))),
            Node(2, 1, "stack", ("layout", "row"), ("grow", 1)),
            Node(3, 2, "list", ("rows", 3), ("index", 2), ("leave_ends", true), Measured(100, 72)),
            Node(4, 2, "button", Measured(40, 24)),
            Node(5, 1, "button", Measured(40, 24))));
        beside.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(5, Focus(beside.Repeat(UiButton.Down)));
        Assert.Equal(3, Focus(beside.Repeat(UiButton.Up)));
        Assert.Equal(4, Focus(beside.Repeat(UiButton.Right)));
        Assert.Null(Focus(beside.Repeat(UiButton.Up)));

        var leave = new TreeHarness();
        leave.Frame(Adds(Node(1, null, "box", ("leave_told", true)), Node(2, 1, "button", Measured(40, 20)), Node(3, 1, "button", Measured(40, 20))));
        leave.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["1 leave left"], Events(leave.Repeat(UiButton.Left)));
        Assert.Equal(["1 leave up"], Events(leave.Repeat(UiButton.Up)));
        Assert.Equal(3, Focus(leave.Repeat(UiButton.Down)));
        Assert.Equal(["1 leave down"], Events(leave.Repeat(UiButton.Down)));
        leave.Frame(Set(1, "leave_told", false));
        Assert.Empty(Events(leave.Repeat(UiButton.Right)));
    }

    /// <summary>
    /// Asserts that UP from a list's first row lands on the first part of the row of parts above it,
    /// a row inside it too, and that DOWN from a narrow part lands on the part of a row below that
    /// lies under it, and UP back.
    /// </summary>
    [Fact]
    public void Arrows_LandOnThePartOfARowNearestAcross()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(300, 200))),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "button", Measured(80, 24)),
            Node(4, 2, "button", Measured(40, 24)),
            Node(5, 1, "stack", ("layout", "row")),
            Node(6, 5, "stack", ("layout", "row")),
            Node(7, 6, "button", Measured(40, 24)),
            Node(8, 6, "button", Measured(40, 24)),
            Node(9, 6, "button", Measured(40, 24)),
            Node(10, 5, "button", Measured(40, 24)),
            Node(11, 1, "list", ("rows", 2), ("index", 0), ("leave_ends", true), Measured(160, 48))));
        _tree.Frame(new RubyHash { { "focus", 11 } });
        Assert.Equal(7, Focus(_tree.Repeat(UiButton.Up)));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(9, Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Up)));
    }

    /// <summary>
    /// Asserts that RIGHT moves the focus out of a list to the next part of the row around it and LEFT
    /// from the first part of an inner row back to the list; that RIGHT and LEFT step between the
    /// columns of a row onto the part each column held last, inside a box the keys entered too; and
    /// that RIGHT hands the focus from a text field of one line to the button beside it only while the
    /// caret stands at the end of its text.
    /// </summary>
    [Fact]
    public void Arrows_StepBetweenTheColumnsOfARow()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layout", "row")),
            Node(2, 1, "list", ("rows", 3), ("size", Pair(100, 72)), ("index", 0)),
            Node(3, 1, "stack", ("layout", "row")),
            Node(4, 3, "button", Measured(40, 20)),
            Node(5, 3, "button", Measured(40, 20))));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(5, Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Left)));
        Assert.Equal(2, Focus(_tree.Repeat(UiButton.Left)));

        var columns = new TreeHarness();
        columns.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(400, 200)), ("layout", "row")),
            Node(2, 1, "stack"),
            Node(3, 2, "box", ("enter", true), ("focusable", true)),
            Node(4, 3, "list", ("rows", 3), ("size", Pair(100, 72)), ("index", 0)),
            Node(5, 2, "box", ("enter", true), ("focusable", true)),
            Node(6, 5, "list", ("rows", 2), ("size", Pair(100, 48)), ("index", 0)),
            Node(7, 1, "stack"),
            Node(8, 7, "stack", ("clickable", true), ("focusable", true)),
            Node(9, 8, "custom", Measured(60, 24)),
            Node(10, 7, "stack", ("clickable", true), ("focusable", true)),
            Node(11, 10, "custom", Measured(60, 24))));
        columns.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(8, Focus(columns.Repeat(UiButton.Right)));
        Assert.Equal(10, Focus(columns.Repeat(UiButton.Down)));
        Assert.Equal(4, Focus(columns.Repeat(UiButton.Left)));
        Assert.Equal(3, Focus(columns.Frame(buttons: Triggered(UiButton.Cancel))));
        Assert.Equal(10, Focus(columns.Repeat(UiButton.Right)));
        Assert.Equal(4, Focus(columns.Repeat(UiButton.Left)));

        var field = new TreeHarness();
        field.Frame(Adds(
            Node(1, null, "window", ("size", Pair(400, 100))),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "text_field", Measured(100, 24), ("leave_sides", true), ("caret_ends", new RubyArray { true, false })),
            Node(4, 2, "button", Measured(60, 24))));
        field.Frame(new RubyHash { { "focus", 3 } });
        Assert.Null(Focus(field.Frame(buttons: Triggered(UiButton.Right))));
        field.Frame(Set(3, "caret_ends", new RubyArray { false, true }));
        Assert.Equal(4, Focus(field.Frame(buttons: Triggered(UiButton.Right))));
        Assert.Equal(3, Focus(field.Repeat(UiButton.Left)));
    }

    /// <summary>
    /// Asserts that UP from a row of buttons comes into the list above it, and that DOWN steps the
    /// list's lines and leaves it on its last line when it hands the focus on, a list that does not
    /// keeping it; and that a list of cards that hands the focus on gives it to the button beside it
    /// from the last card of a line or a last card alone, steps to the card beside inside a line,
    /// passes over the field above it, which lies not beside it, and goes up to that field, which
    /// steers the list, from its first line.
    /// </summary>
    [Fact]
    public void Lists_HandTheFocusOnPastTheirEnds()
    {
        _tree.Frame(Adds(
            Node(1, null, "dialog"),
            Node(2, 1, "list", ("rows", 2), ("index", 0), ("leave_ends", true), Measured(100, 48)),
            Node(3, 1, "stack", ("layout", "row")),
            Node(4, 3, "button", Measured(40, 24)),
            Node(5, 3, "button", Measured(40, 24))));
        _tree.Frame(new RubyHash { { "focus", 5 } });
        Assert.Equal(2, Focus(_tree.Repeat(UiButton.Up)));
        Assert.Null(Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(4, Focus(_tree.Repeat(UiButton.Down)));
        _tree.Frame(Set(2, "leave_ends", false));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Null(Focus(_tree.Repeat(UiButton.Down)));

        var cards = new TreeHarness();
        cards.Frame(Adds(
            Node(1, null, "window", ("size", Pair(400, 200))),
            Node(2, 1, "stack", ("layout", "row"), ("grow", 1)),
            Node(3, 2, "stack", ("grow", 1)),
            Node(4, 3, "text_field", Measured(100, 24)),
            Node(5, 3, "list", ("rows", 5), ("index", 1), ("row_cells", 2), ("leave_sides", true), ("leave_ends", true), ("up_to", 4), Measured(200, 72)),
            Node(6, 2, "stack", ("tab_page", true)),
            Node(7, 6, "custom", Measured(60, 30)),
            Node(8, 6, "button", Measured(60, 24))));
        cards.Frame(new RubyHash { { "focus", 5 } });
        Assert.Equal(8, Focus(cards.Repeat(UiButton.Right)));
        cards.Frame(new RubyHash { { "focus", 5 } });
        cards.Frame(Set(5, "index", 4));
        Assert.Equal(8, Focus(cards.Repeat(UiButton.Right)));
        cards.Frame(new RubyHash { { "focus", 5 } });
        cards.Frame(Set(5, "index", 2));
        Assert.Null(Focus(cards.Repeat(UiButton.Left)));
        Assert.Contains("5 change 3", Events(cards.Repeat(UiButton.Right)));
        cards.Frame(Set(5, "index", 0));
        Assert.Equal(4, Focus(cards.Repeat(UiButton.Up)));
    }

    /// <summary>
    /// Asserts that a grid of cards that leaves its ends, under a search field, hands the focus up to
    /// the field from its first line and down to the button under it from its last, while LEFT on its
    /// first card still wraps to its last.
    /// </summary>
    [Fact]
    public void Grids_OfCardsHandTheFocusOnPastTheirEndsWhenTold()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "text_field", Measured(100, 24)),
            Node(3, 1, "grid", ("layout", "grid"), ("columns", new RubyArray { RubyNil.Value, RubyNil.Value }), ("leave_ends", true)),
            Node(4, 3, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(5, 3, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(6, 3, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(7, 1, "button", Measured(40, 20))));
        _tree.Frame(new RubyHash { { "focus", 5 } });
        Assert.Equal(2, Focus(_tree.Press(UiButton.Up)));
        _tree.Frame(new RubyHash { { "focus", 6 } });
        Assert.Equal(7, Focus(_tree.Press(UiButton.Down)));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(6, Focus(_tree.Press(UiButton.Left)));
    }

    /// <summary>
    /// Asserts which parts are key stops: the keys pass over a part only the pointer reaches and what
    /// it holds, which a click clicks without taking the focus; a key stop steps through its places by
    /// LEFT and RIGHT without going round before the focus moves on, and a press on one of its places
    /// focuses it; what the scripts set by hand wins over what the tree works out; a button whose
    /// press repeats a key takes a click but never the focus; and a box of the new UI layer that holds
    /// the game's buttons takes the focus as it opens while one that holds none does not.
    /// </summary>
    [Fact]
    public void KeyStops_AreThePartsTheKeysReach()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", Measured(50, 20)),
            Node(3, 1, "stack", ("pointer_only", true)),
            Node(4, 3, "button", Measured(50, 20)),
            Node(5, 1, "button", Measured(50, 20))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(5, Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(2, Focus(_tree.Press(key: ComponentTree.TabKey)));
        _tree.Point(10, 30);
        _tree.Input.Down.Add(LeftButton);
        List<string> down = Events(_tree.Frame());
        _tree.Input.Down.Remove(LeftButton);
        Assert.DoesNotContain(down, text => text.EndsWith(" focus", System.StringComparison.Ordinal) || text.EndsWith(" blur", System.StringComparison.Ordinal));
        Assert.Contains("4 click", Events(_tree.Frame()));

        var places = new TreeHarness();
        places.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "stack", ("layout", "row"), ("focusable", true), ("steps", true), ("rows", 2), ("index", 0)),
            Node(4, 3, "icon_button", Measured(24, 24), ("focusable", false)),
            Node(5, 3, "icon_button", Measured(24, 24), ("focusable", false)),
            Node(6, 2, "button", Measured(40, 24))));
        places.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(["3 move 1"], Events(places.Repeat(UiButton.Right)));
        Assert.Equal(6, Focus(places.Repeat(UiButton.Right)));
        Assert.Equal(3, Focus(places.Repeat(UiButton.Left)));
        Assert.Equal(["3 move 0"], Events(places.Repeat(UiButton.Left)));
        Assert.Empty(Events(places.Repeat(UiButton.Left)));
        places.Frame(new RubyHash { { "focus", 6 } });
        places.Point(30, 10);
        places.Input.Down.Add(LeftButton);
        Assert.Contains("3 focus", Events(places.Frame()));
        places.Input.Down.Remove(LeftButton);
        Assert.Contains("5 click", Events(places.Frame()));

        var settings = new TreeHarness();
        RubyHash opened = settings.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(200, 100))),
            Node(2, 1, "button", Measured(40, 20), ("acts", false), ("focusable", true)),
            Node(3, 1, "stack", ("aside", true), ("pointer_only", false)),
            Node(4, 3, "button", Measured(40, 20)),
            Node(5, 1, "button", Measured(40, 20), ("repeats", true))));
        Assert.Contains("2 focus", Events(opened));
        Assert.Contains("4 focus", Events(settings.Repeat(UiButton.Down)));
        Assert.Null(Focus(settings.Repeat(UiButton.Down)));
        settings.Point(20, 50);
        settings.Frame();
        Assert.Equal(["5 click"], Events(settings.Click()));

        var boxes = new TreeHarness();
        RubyHash shown = boxes.Frame(Adds(
            Node(1, null, "box", ("layer", true), ("captures", true)),
            Node(2, 1, "button", Measured(40, 20)),
            Node(5, null, "box", ("layer", true)),
            Node(6, 5, "button", Measured(40, 20))));
        Assert.Contains("2 focus", Events(shown));
        Assert.DoesNotContain("6 focus", Events(shown));
    }

    /// <summary>
    /// Asserts that a window hidden and shown again gives the focus back to the part that had it; that
    /// a removed part drops the focus to its window's first part with no blur; that closing a root
    /// gives the focus back to the part that had it in the root below, or to that root's first part
    /// once that one is gone; and that a part made anew with the same focus key while a dialog lay
    /// above takes the focus back once the dialog closes.
    /// </summary>
    [Fact]
    public void Focus_ComesBackAsRootsCloseHideOrAreMadeAnew()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, 1, "button", Measured(40, 20), ("focus_key", "slot:1")),
            Node(6, 1, "button", Measured(40, 20))));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(["3 blur"], Events(_tree.Frame(Set(1, "visible", false))));
        Assert.Equal(["3 focus"], Events(_tree.Frame(Set(1, "visible", true))));

        _tree.Frame(new RubyHash { { "focus", 6 } });
        Assert.Equal(["2 focus"], Events(_tree.Frame(new RubyHash { { "remove", new RubyArray { 6 } } })));

        RubyHash dialog = Adds(Node(4, null, "dialog"), Node(5, 4, "button", Measured(40, 20)));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        _tree.Frame(dialog);
        Assert.Equal(["4 close", "3 focus"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));

        _tree.Frame(dialog);
        RubyHash remade = Adds(Node(7, 1, "button", Measured(40, 20), ("focus_key", "slot:1")));
        remade["remove"] = new RubyArray { 4, 3 };
        Assert.Equal("7 focus", Events(_tree.Frame(remade)).Last(text => text.EndsWith(" focus", System.StringComparison.Ordinal)));

        _tree.Frame(dialog);
        _tree.Frame(new RubyHash { { "remove", new RubyArray { 7 } } });
        Assert.Equal(["4 close", "2 focus"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));
    }

    /// <summary>
    /// Asserts that a dialog closing over a window of the new UI layer gives the focus back to the key
    /// stop nearest the button that had it when that button turned off meanwhile, inside the box the
    /// keys entered, as Install of the mod browser's page turns into Installed under its change box.
    /// </summary>
    [Fact]
    public void Focus_ComesBackBesideAPartThatTurnedOffUnderADialog()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(300, 200))),
            Node(2, 1, "box", ("enter", true), ("focusable", true)),
            Node(3, 2, "button", Measured(60, 24)),
            Node(4, 1, "box", ("enter", true), ("focusable", true)),
            Node(5, 4, "button", Measured(60, 24)),
            Node(6, 4, "button", Measured(60, 24))));
        _tree.Frame(new RubyHash { { "focus", 5 } });
        _tree.Frame(Adds(Node(7, null, "dialog"), Node(8, 7, "button", Measured(40, 20))));
        RubyHash closed = Set(5, "enabled", false);
        closed["remove"] = new RubyArray { 7 };
        Assert.Equal(6, Focus(_tree.Frame(closed)));
    }

    /// <summary>
    /// Asserts that a window joined to a game window takes no focus as it opens, nor as another root
    /// closes after the focus left it, so the game window keeps the keys, and takes it on the part
    /// that held it once the scripts hand it over.
    /// </summary>
    [Fact]
    public void JoinedWindow_TakesTheFocusOnlyWhenHandedOver()
    {
        RubyHash box = Adds(
            Node(1, null, "window", ("layer", true), ("captures", false), ("joined", true)),
            Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72)));
        Assert.DoesNotContain("2 focus", Events(_tree.Frame(box)));
        Assert.Contains("2 focus", Events(_tree.Frame(new RubyHash { { "focus_in", 1 } })));

        _tree.Frame(new RubyHash { { "blur", 2 } });
        _tree.Frame(Adds(Node(3, null, "window"), Node(4, 3, "button", Measured(40, 20))));
        Assert.DoesNotContain("2 focus", Events(_tree.Frame(new RubyHash { { "remove", new RubyArray { 3 } } })));
        Assert.Contains("2 focus", Events(_tree.Frame(new RubyHash { { "focus_in", 1 } })));
    }

    /// <summary>
    /// Asserts that a modal root takes the focus and keeps the pointer and the keys from the roots
    /// below; that one with nothing to focus still takes the keys, confirm clicking nothing below and
    /// cancel closing it with the focus coming back; and that a modal box cancel does not close, as an
    /// open wheel's cover, keeps the pointer, confirm, the arrows and cancel from the window below,
    /// which gets its focus and hover back once the box goes.
    /// </summary>
    [Fact]
    public void Modal_KeepsTheKeysAndThePointerFromTheRootsBelow()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(50, 20))));
        Assert.Equal(["2 blur", "4 focus"], Events(_tree.Frame(Adds(Node(3, null, "dialog", ("at", Pair(300, 300))), Node(4, 3, "button", Measured(50, 20))))));
        _tree.Point(10, 10);
        _tree.Input.Down.Add(LeftButton);
        _tree.Frame();
        _tree.Input.Down.Remove(LeftButton);
        Assert.Equal(["4 click"], Events(_tree.Frame(buttons: Triggered(UiButton.Confirm))));

        var empty = new TreeHarness();
        empty.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(50, 20))));
        Assert.Equal(["2 blur"], Events(empty.Frame(Adds(Node(3, null, "dialog"), Node(4, 3, "custom", Measured(50, 20))))));
        Assert.Empty(Events(empty.Frame(buttons: Triggered(UiButton.Confirm))));
        Assert.Equal(["3 close", "2 focus"], Events(empty.Frame(buttons: Triggered(UiButton.Cancel))));

        var cover = new TreeHarness();
        cover.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(50, 20)), Node(3, 1, "button", Measured(50, 20))));
        Assert.Equal(["2 blur"], Events(cover.Frame(Adds(Node(4, null, "box", ("at", Pair(300, 300)), ("size", Pair(100, 100)), ("modal", true))))));
        cover.Point(20, 10);
        Assert.True(cover.Frame()["states"].IsNil);
        Assert.Empty(Events(cover.Click()));
        Assert.Empty(Events(cover.Frame(buttons: Triggered(UiButton.Confirm) | Repeated(UiButton.Down))));
        Assert.Empty(Events(cover.Frame(buttons: Triggered(UiButton.Cancel))));
        Assert.Equal(["2 focus", "2 hover true"], Events(cover.Frame(new RubyHash { { "remove", new RubyArray { 4 } } })));
    }

    /// <summary>
    /// Asserts that a plain window keeps the old focus rules: a focused button that turns off keeps
    /// the focus, the focus of one that hides goes back to the first key stop, and so does that of a
    /// list whose tab page hides, which in a window of the new UI layer goes into the page its tabs
    /// show.
    /// </summary>
    [Fact]
    public void LostFocus_KeepsTheOldRulesOutsideTheNewLayer()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, 1, "button", Measured(40, 20)),
            Node(4, 1, "button", Measured(40, 20))));
        Assert.Empty(Events(_tree.Frame(Set(2, "enabled", false))));
        _tree.Frame(Set(2, "enabled", true));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        Assert.Contains("2 focus", Events(_tree.Frame(Set(3, "visible", false))));

        foreach ((bool layer, int next) in new[] { (true, 9), (false, 10) })
        {
            var tabs = new TreeHarness();
            tabs.Frame(Adds(
                Node(1, null, "window", ("layer", layer)),
                Node(10, 1, "button", Measured(40, 20)),
                Node(2, 1, "tabs"),
                Node(3, 2, "stack", ("layout", "row")),
                Node(4, 3, "button", Measured(40, 20), ("focusable", false)),
                Node(6, 2, "stack", ("tab_page", true)),
                Node(7, 6, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
                Node(8, 2, "stack", ("tab_page", true)),
                Node(9, 8, "list", ("rows", 3), ("index", 0), Measured(100, 72))));
            tabs.Frame(new RubyHash { { "focus", 7 } });
            Assert.Contains($"{next} focus", Events(tabs.Frame(Set(6, "visible", false))));
        }
    }

    /// <summary>
    /// Asserts that a container clicked as one part is one key stop, passed over for the parts it
    /// holds and clicked by confirm and the pointer; and that a container the keys enter is one stop
    /// while the focus is outside, confirm moving the focus inside onto the part held last and cancel
    /// bringing it back to the whole container, each told to the box but for a dialog opened over it
    /// and closed again, and its window closing told too; UP and DOWN never leaving a box the keys
    /// entered, from a button or a typing text field, until cancel left it.
    /// </summary>
    [Fact]
    public void Containers_AreOneStopUntilTheKeysEnterThem()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(200, 200))),
            Node(2, 1, "stack", ("clickable", true), ("focusable", true)),
            Node(3, 2, "button", Measured(60, 24)),
            Node(4, 1, "button", Measured(60, 24))));
        Assert.Equal(["4 focus"], Events(_tree.Repeat(UiButton.Down)).FindAll(text => text.EndsWith("focus", System.StringComparison.Ordinal)));
        Assert.Contains("2 focus", Events(_tree.Repeat(UiButton.Up)));
        Assert.Equal(["2 click"], Events(_tree.Frame(buttons: Triggered(UiButton.Confirm))));
        _tree.Point(10, 10);
        Assert.Contains("2 click", Events(_tree.Click()));

        var entered = new TreeHarness();
        RubyHash opened = entered.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(200, 200))),
            Node(2, 1, "box", ("enter", true), ("focusable", true)),
            Node(3, 2, "button", Measured(60, 24)),
            Node(4, 1, "box", ("enter", true), ("focusable", true)),
            Node(5, 4, "button", Measured(60, 24)),
            Node(6, 4, "text_field", Measured(100, 24)),
            Node(7, 1, "box", ("enter", true), ("focusable", true)),
            Node(8, 7, "button", Measured(60, 24))));
        Assert.Contains("2 focus", Events(opened));
        Assert.Contains("4 focus", Events(entered.Repeat(UiButton.Down)));
        List<string> inside = Events(entered.Frame(buttons: Triggered(UiButton.Confirm)));
        Assert.Contains("5 focus", inside);
        Assert.Contains("4 went_in", inside);
        List<string> popup = Events(entered.Frame(Adds(Node(9, null, "dialog"), Node(10, 9, "button", Measured(40, 20)))));
        Assert.Contains("10 focus", popup);
        Assert.DoesNotContain("4 came_out", popup);
        List<string> popupClosed = Events(entered.Frame(new RubyHash { { "remove", new RubyArray { 9 } } }));
        Assert.Contains("5 focus", popupClosed);
        Assert.DoesNotContain("4 went_in", popupClosed);
        Assert.Null(Focus(entered.Repeat(UiButton.Up)));
        Assert.Equal(6, Focus(entered.Repeat(UiButton.Down)));
        Assert.Null(Focus(entered.Press(key: ComponentTree.DownKey)));
        entered.Input.Down.Add(ComponentTree.EscapeKey);
        RubyHash back = entered.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Equal(4, Focus(back));
        Assert.Contains("4 came_out", Events(back));
        entered.Input.Down.Clear();
        entered.Frame();
        Assert.Equal(6, Focus(entered.Frame(buttons: Triggered(UiButton.Confirm))));
        entered.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Equal(7, Focus(entered.Repeat(UiButton.Down)));
        Assert.Contains("7 went_in", Events(entered.Frame(buttons: Triggered(UiButton.Confirm))));
        Assert.Contains("7 came_out", Events(entered.Frame(new RubyHash { { "remove", new RubyArray { 1 } } })));
    }

    /// <summary>
    /// Asserts that the arrows pick boxes the keys enter whole by where they lie, as the mod browser's
    /// bar over its filter drawer and its mods: DOWN from the bar picks the box below most of it, not
    /// the drawer first in the tree; LEFT and RIGHT pick the box beside whole, never going inside, also
    /// onto a box the keys were inside before; UP picks the bar again; and confirm still goes into the
    /// box picked onto the part it had last.
    /// </summary>
    [Fact]
    public void PickedBoxes_ArrowsPickTheBoxThatLiesThatWay()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(400, 200))),
            Node(2, 1, "box", ("enter", true), ("focusable", true), ("size", Pair(400, 40))),
            Node(3, 2, "button", Measured(60, 24)),
            Node(4, 1, "stack", ("layout", "row")),
            Node(5, 4, "box", ("enter", true), ("focusable", true)),
            Node(6, 5, "list", ("rows", 3), ("index", 0), Measured(80, 72)),
            Node(7, 4, "box", ("enter", true), ("focusable", true), ("grow", 1)),
            Node(8, 7, "list", ("rows", 3), ("index", 0), Measured(200, 72))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(7, Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(5, Focus(_tree.Repeat(UiButton.Left)));
        Assert.Equal(6, Focus(_tree.Frame(buttons: Triggered(UiButton.Confirm))));
        Assert.Equal(5, Focus(_tree.Frame(buttons: Triggered(UiButton.Cancel))));
        Assert.Equal(7, Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(5, Focus(_tree.Repeat(UiButton.Left)));
        Assert.Equal(2, Focus(_tree.Repeat(UiButton.Up)));
        _tree.Repeat(UiButton.Down);
        Assert.Equal(8, Focus(_tree.Frame(buttons: Triggered(UiButton.Confirm))));
    }

    /// <summary>
    /// Asserts that slides lay their pages side by side, as many in their width as they show, each at
    /// the same place whichever are hidden; that RIGHT that finds nothing in its row focuses the page
    /// beside while it shows, else tells the slides to move, and LEFT the same the other way; that
    /// RIGHT into the page beside lands on its part level with the one it leaves, past a button above
    /// it, and LEFT from a list of cards at its side goes back; and that cancel moves slides that move
    /// back before the root closes.
    /// </summary>
    [Fact]
    public void Slides_ArrowsFocusThePageBesideOrSlide()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(640, 200))),
            Node(2, 1, "slides", ("shown", 2), ("gap", 12), ("grow", 1)),
            Node(3, 2, "stack"),
            Node(4, 2, "stack"),
            Node(5, 2, "stack")));
        Assert.Equal([0, 0, 314, 200], Rect(report, 3));
        Assert.Equal([326, 0, 314, 200], Rect(report, 4));
        Assert.Equal([652, 0, 314, 200], Rect(report, 5));
        report = _tree.Frame(Set(3, "visible", false));
        Assert.True(report["rects"].IsNil || !report["rects"].AsHash().ContainsKey(4));

        var keys = new TreeHarness();
        keys.Frame(Adds(
            Node(1, null, "window", ("size", Pair(400, 200))),
            Node(2, 1, "slides", ("shown", 2), ("slide_keys", true), ("grow", 1)),
            Node(3, 2, "stack"),
            Node(4, 2, "stack"),
            Node(5, 2, "stack", ("visible", false)),
            Node(6, 3, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
            Node(7, 4, "button", Measured(40, 20))));
        Assert.Equal(7, Focus(keys.Repeat(UiButton.Right)));
        Assert.Contains("2 slide 1", Events(keys.Repeat(UiButton.Right)));
        Assert.Equal(6, Focus(keys.Repeat(UiButton.Left)));
        Assert.Contains("2 slide -1", Events(keys.Repeat(UiButton.Left)));

        var level = new TreeHarness();
        level.Frame(Adds(
            Node(1, null, "window", ("size", Pair(400, 200))),
            Node(2, 1, "slides", ("shown", 2), ("slide_keys", true), ("grow", 1), ("slide_back", true)),
            Node(3, 2, "stack"),
            Node(4, 2, "stack"),
            Node(5, 3, "list", ("rows", 3), ("index", 0), Measured(100, 96)),
            Node(6, 4, "button", Measured(40, 24)),
            Node(7, 4, "list", ("rows", 3), ("index", 0), Measured(100, 72))));
        level.Frame(new RubyHash { { "focus", 5 } });
        level.Frame(Set(5, "index", 2));
        Assert.Equal(7, Focus(level.Repeat(UiButton.Right)));
        level.Frame(Set(7, ("row_cells", 2), ("leave_sides", true)));
        Assert.Equal(5, Focus(level.Repeat(UiButton.Left)));
        Assert.Equal(["2 back"], Events(level.Frame(buttons: Triggered(UiButton.Cancel))));
        level.Frame(Set(2, "slide_back", false));
        Assert.Equal(["1 close"], Events(level.Frame(buttons: Triggered(UiButton.Cancel))));
    }

    /// <summary>
    /// Asserts that the focus asked into a page view's reading pane lands on the pane's part marked
    /// autofocus, not on its first, also after the player was on another part of the pane; and that
    /// the window still opens on the page view's own list.
    /// </summary>
    [Fact]
    public void FocusIn_LandsOnThePartMarkedAutofocus()
    {
        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(300, 200)), ("layout", "row")),
            Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
            Node(3, 1, "box", ("scroll", true), ("grow", 1), ("focusable", true), ("jump_only", true), ("keep_ends", true)),
            Node(4, 3, "button", Measured(60, 24)),
            Node(5, 3, "list", ("rows", 2), ("index", 0), ("autofocus", true), Measured(100, 48))));
        Assert.Equal(2, Focus(opened));
        Assert.Equal(5, Focus(_tree.Frame(new RubyHash { { "focus_in", 3 } })));
        Assert.Equal(4, Focus(_tree.Frame(new RubyHash { { "focus", 4 } })));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(5, Focus(_tree.Frame(new RubyHash { { "focus_in", 3 } })));
    }
}
