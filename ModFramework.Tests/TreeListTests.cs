//----------------------------------------------------------------
//  TreeListTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Reached the first column title by Ctrl and UP from rows under all titles
//      Paulinchen  2026-11-07: Checked that a grid of cards wraps on a fresh press at its edge and stops a held arrow
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Removed the check of the number field set digit by digit
//                            - Checked that a digit starts typing a number field, which then types as a numeric field
//                            - Checked that the pointer frames no row of a list to read and a click picks none there
//      Paulinchen  2026-11-05: Checked that a list whose columns change scrolls its cursor back into sight
//                            - Checked that a table's column titles are reached only by an arrow with the jump key
//                            - Checked that a numeric field steps within its bounds by the arrows until it types as a text
//                              field, and by Up and Down while it types
//                            - Checked that Tab and cancel walk out of a numeric field
//                            - Checked that the move hotkeys move a row of the new UI layer's list that takes them within
//                              its group
//                            - Checked that a disabled part takes no wheel and a disabled row no frame, no drag and no toggle
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Text;
using MGQParadox.ModFramework.Ui.Tree;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the lists of the component tree and the boxes that scroll: scrolling, picking rows by the
/// pointer, carrying a row, the rows the scripts mark, the lists of the new UI layer at their ends,
/// the jump keys and the number field.
/// </summary>
public sealed class TreeListTests
{
    /// <summary>
    /// Windows' code of Ctrl, the jump hotkey's key until the player binds another.
    /// </summary>
    private const int CtrlKey = 0x11;

    /// <summary>
    /// Windows' code of I, the framework's Move Up hotkey until the player binds another.
    /// </summary>
    private const int MoveUpKey = 0x49;

    /// <summary>
    /// Windows' code of K, the framework's Move Down hotkey until the player binds another.
    /// </summary>
    private const int MoveDownKey = 0x4B;

    /// <summary>
    /// Windows' code of Shift, the keyboard's key of the game's A.
    /// </summary>
    private const int ShiftKey = 0x10;

    /// <summary>
    /// The extra buttons' bit of the game's A held.
    /// </summary>
    private const int HeldA = 1 << (2 * UiExtraButtons.Count);

    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts that a list scrolls by the wheel, Page Down and its dragged thumb with its cursor kept
    /// in sight, also as its columns change; that the scripts scroll a box back to its top and a box emptied of its last child
    /// scrolls nothing any more; that DOWN scrolls a focused box by a line, while one that keeps its
    /// ends keeps the focus at its top; and that a part that takes the wheel itself is told its
    /// notches, unless it is disabled.
    /// </summary>
    [Fact]
    public void Scrolling_FollowsTheWheelThePageKeysTheThumbAndTheScripts()
    {
        _tree.Point(50, 10);
        RubyHash report = _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 20), ("size", Pair(200, 120)), ("index", 0))));
        Assert.Equal(new RubyArray { 0, 5, 20 }, report["scroll"].AsHash()[2]);
        _tree.Input.Notches = -2;
        report = _tree.Frame();
        Assert.Equal(new RubyArray { 2, 5, 20 }, report["scroll"].AsHash()[2]);
        Assert.Equal(["2 change 2"], Events(report));
        report = _tree.Repeat(UiButton.R);
        Assert.Equal(new RubyArray { 7, 5, 20 }, report["scroll"].AsHash()[2]);
        Assert.Equal(["2 change 7"], Events(report));
        _tree.Point(195, 50);
        _tree.Input.Down.Add(LeftButton);
        _tree.Frame();
        _tree.Point(195, 98);
        report = _tree.Frame();
        Assert.Equal(new RubyArray { 15, 5, 20 }, report["scroll"].AsHash()[2]);
        Assert.Equal(["2 change 15"], Events(report));

        var cards = new TreeHarness();
        cards.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 9), ("size", Pair(300, 100)), ("row_height", 50), ("row_cells", 3), ("index", 8))));
        Assert.Equal(new RubyArray { 3, 2, 5 }, cards.Frame(Set(2, "row_cells", 2))["scroll"].AsHash()[2]);

        var box = new TreeHarness();
        box.Point(50, 20);
        box.Frame(Adds(
            Node(1, null, "box", ("size", Pair(100, 50)), ("scroll", true)),
            Node(2, 1, "custom", Measured(80, 120)),
            Node(5, null, "window", ("at", Pair(200, 0)), ("size", Pair(100, 80))),
            Node(8, 5, "button", Measured(100, 20)),
            Node(6, 5, "box", ("scroll", true), ("focusable", true), ("keep_ends", true), ("grow", 1)),
            Node(7, 6, "custom", Measured(80, 200)),
            Node(10, null, "window", ("at", Pair(400, 0)), ("size", Pair(200, 200))),
            Node(11, 10, "custom", Measured(200, 100), ("wheel_told", true))));
        box.Input.Notches = -1;
        Assert.Equal(new RubyArray { 24, 50, 120 }, box.Frame()["scroll"].AsHash()[1]);
        Assert.Equal(new RubyArray { 0, 50, 120 }, box.Frame(Set(1, "scroll_top", 0))["scroll"].AsHash()[1]);
        Assert.Equal(new RubyArray { 0, 50, 0 }, box.Frame(new RubyHash { { "remove", new RubyArray { 2 } } })["scroll"].AsHash()[1]);
        box.Frame(new RubyHash { { "focus", 6 } });
        RubyHash top = box.Repeat(UiButton.Up);
        Assert.Null(Focus(top));
        Assert.True(top["scroll"].IsNil);
        Assert.Equal(new RubyArray { 24, 60, 200 }, box.Repeat(UiButton.Down)["scroll"].AsHash()[6]);
        box.Point(410, 10);
        box.Frame();
        box.Input.Notches = 1;
        Assert.Equal(["11 wheel 1"], Events(box.Frame()).FindAll(text => text.Contains("wheel", System.StringComparison.Ordinal)));
        box.Frame(Set(11, "enabled", false));
        box.Input.Notches = 1;
        Assert.DoesNotContain(Events(box.Frame()), text => text.Contains("wheel", System.StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts how the pointer picks a row: a list that follows it moves its cursor under it and
    /// submits a clicked row once, not again on the second click of a double click; a list that does
    /// not follow it frames the row under it unless the row is disabled, a click moving the cursor
    /// and a second submitting, while a list to read, with neither an action nor a bind, frames no row
    /// and takes no click; a click on a row's box picks the row at once and a double click on it picks
    /// it once; a list a
    /// click picks takes a row away from the cursor in one click, its double click pressing nothing
    /// the pick brought up; a list of tall cards hits each card; and in the new UI layer the pointer
    /// only frames the row under it and lights no button, while today's windows follow it.
    /// </summary>
    [Fact]
    public void Pointer_PicksTheRowUnderIt()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 5), ("size", Pair(200, 120)), ("index", 0))));
        _tree.Point(50, 30);
        Assert.Equal(["2 hover true", "2 change 1"], Events(_tree.Frame()));
        Assert.Equal(["2 submit 1"], Events(_tree.Click()));
        Assert.Empty(Events(_tree.Click()));

        var framed = new TreeHarness();
        framed.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 5), ("size", Pair(200, 120)), ("index", 0), ("follow_pointer", false))));
        framed.Point(50, 30);
        Assert.Equal(["2 hover true", "2 hover_row 1"], Events(framed.Frame()));
        Assert.Equal(["2 change 1"], Events(framed.Click()));
        Assert.Equal(["2 submit 1"], Events(framed.Click()));
        framed.Point(300, 300);
        Assert.Equal(["2 hover false", "2 hover_row -1"], Events(framed.Frame()));
        framed.Frame(Set(2, "disabled_rows", new RubyArray { 1 }));
        framed.Point(50, 30);
        Assert.Equal(["2 hover true"], Events(framed.Frame()));

        var read = new TreeHarness();
        read.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 5), ("size", Pair(200, 120)), ("index", 0), ("follow_pointer", false), ("acts", false))));
        read.Point(50, 30);
        Assert.Equal(["2 hover true"], Events(read.Frame()));
        Assert.Empty(Events(read.Click()));
        Assert.Empty(Events(read.Click()));

        var boxes = new TreeHarness();
        boxes.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 3), ("size", Pair(200, 72)), ("index", 0), ("follow_pointer", false), ("box_ends", new RubyArray { 20, 20, 20 }))));
        boxes.Frame(new RubyHash { { "focus", 2 } });
        boxes.Point(8, 30);
        boxes.Frame();
        List<string> twice = Events(boxes.Click());
        twice.AddRange(Events(boxes.Click()));
        Assert.Equal(["2 change 1", "2 submit 1"], twice);
        boxes.Point(80, 54);
        boxes.Frame();
        Assert.Equal(["2 change 2"], Events(boxes.Click()));

        var picks = new TreeHarness();
        picks.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "list", ("rows", 5), ("size", Pair(200, 120)), ("index", 0), ("follow_pointer", false), ("click_picks", true)),
            Node(3, 1, "button", Measured(200, 120), ("visible", false))));
        picks.Point(50, 30);
        picks.Frame();
        Assert.Equal(["2 change 1", "2 submit 1"], Events(picks.Click()));
        picks.Frame(new RubyHash { { "set", new RubyArray { new RubyArray { 2, new RubyHash { { "visible", false } } }, new RubyArray { 3, new RubyHash { { "visible", true } } } } } });
        Assert.DoesNotContain("3 click", Events(picks.Click()));
        Assert.Contains("3 click", Events(picks.Click()));

        var cards = new TreeHarness();
        RubyHash shown = cards.Frame(Adds(
            Node(1, null, "window", ("size", Pair(302, 370))),
            Node(2, 1, "list", ("rows", 9), ("index", 0), ("row_cells", 2), ("row_height", 116), ("whole_rows", true), ("grow", 1), ("follow_pointer", false), Measured(120, 116))));
        cards.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal([0, 0, 302, 348], Rect(shown, 2));
        cards.Point(220, 130);
        Assert.Contains("2 change 3", Events(cards.Click()));
        Assert.Contains("2 change 5", Events(cards.Repeat(UiButton.Down)));

        foreach (bool layer in new[] { true, false })
        {
            var tree = new TreeHarness();
            RubyHash opened = tree.Frame(Adds(
                Node(1, null, "window", ("layer", layer)),
                Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
                Node(3, 1, "button", Measured(40, 20))));
            int[] list = Rect(opened, 2);
            int[] button = Rect(opened, 3);
            tree.Point(list[0] + 10, list[1] + 30);
            List<string> overList = Events(tree.Frame());
            tree.Point(button[0] + 5, button[1] + 5);
            RubyHash overButton = tree.Frame();
            bool lit = !overButton["states"].IsNil && overButton["states"].AsHash().TryGetValue(3, out RubyValue? bits) && (bits.AsInt() & ComponentTree.Hovered) != 0;
            Assert.Equal((layer, !layer, !layer), (overList.Contains("2 hover_row 1"), overList.Contains("2 change 1"), lit));
        }
    }

    /// <summary>
    /// Asserts that a list carrying a row keeps the focus from LEFT, RIGHT and Tab, drops the row on
    /// confirm, a turned off row too, puts it back on cancel without closing its root and drops it as
    /// the pointer takes the focus away; that a row of a group moves only among the rows of its group,
    /// with the buzzer at the group's edge, by the arrows and a page alike; and that a list whose rows
    /// the pointer drags carries the row pressed once the pointer leaves it, dropping it where the
    /// button comes up, while a plain click still submits and a disabled row stays in its place.
    /// </summary>
    [Fact]
    public void Carry_MovesARowByTheKeysAndThePointer()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layout", "row"), ("closable", true)),
            Node(2, 1, "list", ("rows", 4), ("size", Pair(100, 96)), ("index", 1), ("disabled_rows", new RubyArray { 2 })),
            Node(3, 1, "button", Measured(40, 20))));
        _tree.Frame(Set(2, "moving", true));
        Assert.Equal(["2 change 2"], Events(_tree.Repeat(UiButton.Down)));
        Assert.Null(Focus(_tree.Repeat(UiButton.Right)));
        Assert.Equal(["2 drop 2"], Events(_tree.Frame(buttons: Triggered(UiButton.Confirm))));
        _tree.Frame(Set(2, "moving", true));
        Assert.Equal(["2 uncarry"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));
        _tree.Frame(Set(2, "moving", true));
        Assert.Null(Focus(_tree.Press(key: ComponentTree.TabKey)));
        _tree.Point(110, 10);
        _tree.Input.Down.Add(LeftButton);
        Assert.Equal(["2 drop 2", "2 blur", "3 focus"], Events(_tree.Frame()).Where(text => !text.Contains("hover")));

        var group = new TreeHarness();
        group.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 7), ("size", Pair(200, 168)), ("index", 2), ("heading_rows", new RubyArray { 0, 4 }))));
        group.Frame(new RubyHash { { "focus", 2 } });
        group.Frame(Set(2, ("moving", true), ("move_span", new RubyArray { 1, 3 })));
        Assert.Equal(["2 change 3"], Events(group.Repeat(UiButton.Down)));
        RubyHash edge = group.Repeat(UiButton.Down);
        Assert.Empty(Events(edge));
        Assert.Equal([UiCue.Buzzer], Cues(edge));
        Assert.Equal(["2 change 1"], Events(group.Repeat(UiButton.L)));
        Assert.Equal([UiCue.Buzzer], Cues(group.Repeat(UiButton.Up)));

        var dragged = new TreeHarness();
        dragged.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 5), ("size", Pair(200, 120)), ("index", 0), ("reorder", true))));
        dragged.Point(50, 30);
        Assert.Equal(["2 hover true", "2 change 1"], Events(dragged.Frame()));
        dragged.Input.Down.Add(LeftButton);
        dragged.Frame();
        dragged.Point(50, 80);
        Assert.Equal(["2 carry 1", "2 change 3"], Events(dragged.Frame()));
        dragged.Input.Down.Remove(LeftButton);
        Assert.Equal(["2 drop 3"], Events(dragged.Frame()));
        Assert.Equal(["2 submit 3"], Events(dragged.Click()));
        dragged.Frame(Set(2, "disabled_rows", new RubyArray { 3 }));
        dragged.Input.Down.Add(LeftButton);
        dragged.Frame();
        dragged.Point(50, 30);
        Assert.DoesNotContain(Events(dragged.Frame()), text => text.Contains("carry", System.StringComparison.Ordinal));
        dragged.Input.Down.Remove(LeftButton);
        dragged.Frame();
    }

    /// <summary>
    /// Asserts that in the new UI layer the move hotkeys move the cursor's row of a focused list
    /// that takes them, as the framework's mod list does, one place within its group, the cursor going
    /// with it: Move Down and Move Up within a tag, the buzzer, told with why, past the tag's first
    /// row, on a mod alone in its tag and on a turned off mod, and nothing while a text field types;
    /// a list whose rows only a drag moves and a list in today's windows leave them alone.
    /// </summary>
    [Fact]
    public void MoveHotkeys_MoveTheRowWithinItsGroup()
    {
        RubyHash tree = Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "list", ("rows", 6), ("index", 1), ("reorder", true), ("move_hotkeys", true), ("heading_rows", new RubyArray { 0, 4 }),
                 ("row_groups", new RubyArray { 0, 1, 1, 1, 0, 2 }), ("disabled_rows", new RubyArray { 3 }), Measured(100, 144)),
            Node(3, 1, "text_field", Measured(100, 20)));
        tree["hotkeys"] = Hotkeys(("list_move_up", MoveUpKey), ("list_move_down", MoveDownKey))["hotkeys"];
        _tree.Frame(tree);
        _tree.Frame(new RubyHash { { "focus", 2 } });

        RubyHash down = _tree.Key(MoveDownKey);
        Assert.Equal(["2 reorder 1 2"], Events(down));
        Assert.Equal([UiCue.Cursor], Cues(down));
        Assert.Equal(["2 reorder 2 1"], Events(_tree.Key(MoveUpKey)));
        RubyHash top = _tree.Key(MoveUpKey);
        Assert.Equal(["2 move_refused list_move_up the row is at the end of its group"], Events(top));
        Assert.Equal([UiCue.Buzzer], Cues(top));
        _tree.Frame(Set(2, "index", 5));
        Assert.Equal([UiCue.Buzzer], Cues(_tree.Key(MoveUpKey)));
        _tree.Frame(Set(2, "index", 3));
        RubyHash off = _tree.Key(MoveUpKey);
        Assert.Equal(["2 move_refused list_move_up the cursor's row is turned off"], Events(off));
        Assert.Equal([UiCue.Buzzer], Cues(off));

        _tree.Frame(Set(3, "typing", true));
        Assert.DoesNotContain(Events(_tree.Key(MoveDownKey)), text => text.Contains("reorder", System.StringComparison.Ordinal));

        var dragged = new TreeHarness();
        RubyHash byDrag = Adds(Node(1, null, "window", ("layer", true)), Node(2, 1, "list", ("rows", 3), ("index", 0), ("reorder", true), Measured(100, 72)));
        byDrag["hotkeys"] = Hotkeys(("list_move_down", MoveDownKey))["hotkeys"];
        dragged.Frame(byDrag);
        dragged.Frame(new RubyHash { { "focus", 2 } });
        Assert.Empty(Events(dragged.Key(MoveDownKey)));

        var today = new TreeHarness();
        RubyHash old = Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 3), ("index", 0), ("reorder", true), ("move_hotkeys", true), Measured(100, 72)));
        old["hotkeys"] = Hotkeys(("list_move_down", MoveDownKey))["hotkeys"];
        today.Frame(old);
        today.Frame(new RubyHash { { "focus", 2 } });
        Assert.Empty(Events(today.Key(MoveDownKey)));
    }

    /// <summary>
    /// Asserts the rows the scripts mark: the cursor passes over heading rows by the keys and stays put
    /// on one the pointer points at, the heading over the cursor's row scrolling into sight with it; a
    /// row with a value hands LEFT and RIGHT to the scripts while RIGHT on a row without one moves the
    /// focus beside the list, and a quiet list picks without the confirm sound; a row's toggles take
    /// the cursor by RIGHT and LEFT and confirm on one tells toggle; and a turned off row is refused
    /// with the buzzer, its toggles too.
    /// </summary>
    [Fact]
    public void MarkedRows_PassHeadingsAndHandValuesAndTogglesToTheScripts()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 6), ("size", Pair(200, 72)), ("index", 1), ("heading_rows", new RubyArray { 0, 3 }))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 change 2"], Events(_tree.Repeat(UiButton.Down)));
        Assert.Equal(["2 change 4"], Events(_tree.Repeat(UiButton.Down)));
        Assert.Equal(["2 change 2"], Events(_tree.Repeat(UiButton.Up)));
        RubyHash report = _tree.Repeat(UiButton.Up);
        Assert.Equal(["2 change 1"], Events(report));
        Assert.Equal(new RubyArray { 0, 3, 6 }, report["scroll"].AsHash()[2]);
        Assert.Empty(Events(_tree.Repeat(UiButton.Up)));
        _tree.Point(50, 10);
        Assert.DoesNotContain(Events(_tree.Frame()), text => text.Contains("change"));
        Assert.DoesNotContain(Events(_tree.Click()), text => text.Contains("change") || text.Contains("submit"));

        var values = new TreeHarness();
        values.Frame(Adds(
            Node(1, null, "window", ("layout", "row")),
            Node(2, 1, "list", ("rows", 3), ("size", Pair(100, 72)), ("index", 1), ("sides", true), ("value_rows", new RubyArray { 0, 1 }), ("quiet", true)),
            Node(3, 1, "button", Measured(40, 20))));
        values.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 side 1 1"], Events(values.Repeat(UiButton.Right)));
        Assert.Equal(["2 side 1 -1"], Events(values.Repeat(UiButton.Left)));
        RubyHash quiet = values.Frame(buttons: Triggered(UiButton.Confirm));
        Assert.Equal(["2 submit 1"], Events(quiet));
        Assert.Empty(Cues(quiet));
        values.Frame(Set(2, "index", 2));
        Assert.Equal(3, Focus(values.Repeat(UiButton.Right)));

        var toggles = new TreeHarness();
        toggles.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "list", ("rows", 2), ("index", 1), ("toggle_rows", new RubyArray { 0, 2 })),
            Node(3, 1, "list", ("rows", 2), ("index", 1), ("disabled_rows", new RubyArray { 1 }))));
        toggles.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 toggle_cursor 1 0"], Events(toggles.Repeat(UiButton.Right)));
        Assert.Equal(["2 toggle_cursor 1 1"], Events(toggles.Repeat(UiButton.Right)));
        Assert.Equal(["2 toggle 1 1"], Events(toggles.Frame(buttons: Triggered(UiButton.Confirm))));
        toggles.Repeat(UiButton.Left);
        Assert.Equal(["2 toggle_cursor 1 -1"], Events(toggles.Repeat(UiButton.Left)));
        toggles.Frame(new RubyHash { { "focus", 3 } });
        RubyHash refused = toggles.Frame(buttons: Triggered(UiButton.Confirm));
        Assert.Equal(["3 refuse 1"], Events(refused));
        Assert.Equal(["buzzer"], Cues(refused));
        toggles.Frame(Set(2, "disabled_rows", new RubyArray { 1 }));
        toggles.Frame(new RubyHash { { "focus", 2 } });
        toggles.Repeat(UiButton.Right);
        Assert.Equal(["2 refuse 1"], Events(toggles.Frame(buttons: Triggered(UiButton.Confirm))));
    }

    /// <summary>
    /// Asserts how a list moves at its ends and along its cells: one that goes round picks its other
    /// end; a list of two rows a line moves along its cells, on to the next line at the end of one, by
    /// DOWN to the line below or a short last line's last row, with the pointer picking the row under
    /// it on both sides; in the new UI layer a held arrow stops at a list's end while a grid of cards
    /// wraps on a fresh press, UP and DOWN to the other end in the same column and RIGHT on its last
    /// card to its first, and a grid of card boxes wraps the same way while a held arrow stops at its edge; a list of today's screens keeps its ends unless the engine sets one to hand
    /// the focus on; a row of toggles keeps the focus at its last toggle; and the pick of a list that
    /// does not take it goes up to the nearest part around it that does, or stays with the list when
    /// none does.
    /// </summary>
    [Fact]
    public void Ends_GoRoundStopOrHandTheFocusOn()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 3), ("index", 0), ("round", true))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Contains("2 change 2", Events(_tree.Repeat(UiButton.Up)));
        Assert.Contains("2 change 0", Events(_tree.Repeat(UiButton.Down)));

        var cells = new TreeHarness();
        cells.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 5), ("row_cells", 2), ("size", Pair(200, 72)), ("index", 0))));
        Assert.Equal(["2 change 1"], Events(cells.Repeat(UiButton.Right)));
        Assert.Equal(["2 change 2"], Events(cells.Repeat(UiButton.Right)));
        Assert.Equal(["2 change 1"], Events(cells.Repeat(UiButton.Left)));
        Assert.Equal(["2 change 3"], Events(cells.Repeat(UiButton.Down)));
        Assert.Equal(["2 change 4"], Events(cells.Repeat(UiButton.Down)));
        Assert.Empty(Events(cells.Repeat(UiButton.Down)));
        cells.Point(150, 30);
        Assert.Equal(["2 hover true", "2 change 3"], Events(cells.Frame()));
        cells.Point(50, 6);
        Assert.Equal(["2 change 0"], Events(cells.Frame()));

        var layer = new TreeHarness();
        layer.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("submits", true)),
            Node(2, 1, "list", ("rows", 3), ("index", 2), ("submits", false), Measured(100, 72)),
            Node(3, 1, "button", Measured(40, 20))));
        Assert.Empty(Events(layer.Frame(buttons: Repeated(UiButton.Down) | Held(UiButton.Down))));
        layer.Frame();
        Assert.Equal(["1 submit 2 2"], Events(layer.Press(UiButton.Confirm)));
        layer.Frame(Set(1, "submits", false));
        Assert.Equal(["2 submit 2"], Events(layer.Press(UiButton.Confirm)));
        layer.Frame(Set(2, "leave_ends", true));
        Assert.Contains("3 focus", Events(layer.Press(UiButton.Down)));

        var grid = new TreeHarness();
        grid.Frame(Adds(Node(1, null, "window", ("layer", true)), Node(2, 1, "list", ("rows", 5), ("row_cells", 3), ("index", 4), Measured(300, 48))));
        Assert.Equal(["2 change 1"], Events(grid.Press(UiButton.Down)));
        Assert.Equal(["2 change 4"], Events(grid.Press(UiButton.Up)));
        Assert.Equal(["2 change 0"], Events(grid.Press(UiButton.Right)));

        var cards = new TreeHarness();
        cards.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "grid", ("layout", "grid"), ("columns", new RubyArray { RubyNil.Value, RubyNil.Value })),
            Node(3, 2, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(4, 2, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(5, 2, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(6, 2, "box", ("focusable", true), ("clickable", true), Measured(60, 40)),
            Node(7, 1, "button", Measured(40, 20))));
        cards.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(5, Focus(cards.Press(UiButton.Up)));
        Assert.Null(Focus(cards.Repeat(UiButton.Down)));
        Assert.Equal(3, Focus(cards.Press(UiButton.Down)));
        Assert.Equal(6, Focus(cards.Press(UiButton.Left)));
        Assert.Equal(3, Focus(cards.Press(UiButton.Right)));

        var today = new TreeHarness();
        today.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 3), ("index", 2), Measured(100, 72))));
        Assert.Empty(Events(today.Press(UiButton.Down)));
        Assert.Equal(["2 submit 2"], Events(today.Press(UiButton.Confirm)));

        var toggles = new TreeHarness();
        toggles.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "list", ("rows", 2), ("index", 0), ("toggle_rows", new RubyArray { 1, 0 }), Measured(100, 48)),
            Node(4, 2, "button", Measured(40, 20))));
        Assert.Equal(["3 toggle_cursor 0 0"], Events(toggles.Press(UiButton.Right)));
        Assert.Empty(Events(toggles.Press(UiButton.Right)));
    }

    /// <summary>
    /// Asserts that in the new UI layer Ctrl with an arrow, or a gamepad's A held with the d-pad,
    /// jumps from any row of a list to the part under it and out of a row that keeps LEFT and RIGHT,
    /// while Shift, the game's A on the keyboard, held with DOWN still moves the cursor and an A held
    /// since before the window opened jumps only once pressed again; today's screens take Ctrl with an
    /// arrow as the arrow alone.
    /// </summary>
    [Fact]
    public void JumpKeys_LeaveTheListAndTheRow()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "list", ("rows", 3), ("index", 0), ("toggle_rows", new RubyArray { 1, 0, 0 }), Measured(100, 72)),
            Node(4, 2, "button", Measured(40, 20)),
            Node(5, 1, "button", Measured(40, 20))));
        Assert.Contains("5 focus", Events(_tree.Press(UiButton.Down, CtrlKey)));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        Assert.Contains("5 focus", Events(_tree.Frame(buttons: Triggered(UiButton.Down) | Repeated(UiButton.Down), extra: HeldA)));
        _tree.Frame();
        _tree.Frame(new RubyHash { { "focus", 3 } });
        Assert.Contains("4 focus", Events(_tree.Press(UiButton.Right, CtrlKey)));
        _tree.Frame(new RubyHash { { "focus", 3 } });
        _tree.Input.Down.Add(ShiftKey);
        RubyHash shift = _tree.Frame(buttons: Triggered(UiButton.Down) | Repeated(UiButton.Down), extra: HeldA);
        _tree.Input.Down.Clear();
        Assert.Equal(["3 change 1"], Events(shift));

        var held = new TreeHarness();
        held.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
            Node(3, 1, "button", Measured(40, 20))), extra: HeldA);
        Assert.Equal(["2 change 1"], Events(held.Frame(buttons: Triggered(UiButton.Down) | Repeated(UiButton.Down), extra: HeldA)));
        held.Frame();
        held.Frame(extra: HeldA);
        Assert.Contains("3 focus", Events(held.Frame(buttons: Triggered(UiButton.Down) | Repeated(UiButton.Down), extra: HeldA)));

        var today = new TreeHarness();
        today.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72)), Node(3, 1, "button", Measured(40, 20))));
        Assert.Equal(["2 change 1"], Events(today.Press(UiButton.Down, CtrlKey)));
    }

    /// <summary>
    /// Asserts that a table's column titles, which only the jump key reaches, never take the focus as
    /// the window opens nor by a plain UP from the rows; Ctrl and UP reach the first title, RIGHT
    /// walks the titles and DOWN goes back to the rows.
    /// </summary>
    [Fact]
    public void ColumnTitles_AreReachedOnlyByTheJumpKey()
    {
        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "stack", ("clickable", true), ("focusable", true), ("jump_only", true), Measured(60, 20)),
            Node(4, 2, "stack", ("clickable", true), ("focusable", true), ("jump_only", true), Measured(60, 20)),
            Node(5, 1, "list", ("rows", 3), ("index", 0), ("leave_ends", true), Measured(120, 72))));
        Assert.Contains("5 focus", Events(opened));
        Assert.DoesNotContain(Events(_tree.Press(UiButton.Up)), text => text.EndsWith(" focus", System.StringComparison.Ordinal));
        Assert.Contains("3 focus", Events(_tree.Press(UiButton.Up, CtrlKey)));
        Assert.Contains("4 focus", Events(_tree.Press(UiButton.Right)));
        Assert.Contains("5 focus", Events(_tree.Press(UiButton.Down)));
    }

    /// <summary>
    /// Asserts that a numeric field that does not type steps by its step with the arrows, the wheel
    /// and a click on an arrow, buzzing at its bound, while a click between the arrows and confirm
    /// start typing; that while it types LEFT and RIGHT step nothing, Z, bound to confirm and typing
    /// nothing into it, gives Enter and cancel puts the number back; and that UP and DOWN step what it
    /// types from the number the text gives within the bounds, buzzing where it stays, while the jump
    /// key held with DOWN moves on; and that Tab walks out of it to the next part, Shift+Tab back,
    /// and cancel, once it no longer types, goes the cancel chain.
    /// </summary>
    [Fact]
    public void NumericField_StepsUntilItTypesAsATextField()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", Pair(200, 100))),
            Node(2, 1, "numeric_field", ("number", 4), ("number_min", 2), ("number_max", 40), ("number_step", 2), ("number_arrows", 20), ("confirm_to_type", true),
                 ("takes", "0"), ("rows", 1), ("at", Pair(0, 0)), ("size", Pair(100, 24))),
            Node(3, 1, "button", ("at", Pair(0, 40)), ("size", Pair(100, 24)))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 number 6"], Events(_tree.Repeat(UiButton.Up)));
        Assert.Equal(["2 number 4"], Events(_tree.Repeat(UiButton.Down)));
        Assert.Equal(["2 number 6"], Events(_tree.Repeat(UiButton.Right)));
        Assert.Equal(["2 number 4"], Events(_tree.Repeat(UiButton.Left)));
        Assert.Equal(["2 number 2"], Events(_tree.Repeat(UiButton.Left)));
        RubyHash atEnd = _tree.Repeat(UiButton.Left);
        Assert.Equal([], Events(atEnd));
        Assert.Equal(["buzzer"], Cues(atEnd));

        _tree.Point(90, 10);
        _tree.Frame();
        Assert.Equal(["2 number 4"], Events(_tree.Click()));
        _tree.Input.Notches = 1;
        Assert.Equal(["2 number 6"], Events(_tree.Frame()));
        _tree.Input.Notches = 0;
        _tree.Point(50, 10);
        _tree.Frame();
        Assert.Equal(["2 click"], Events(_tree.Click()));
        Assert.Equal(["2 click"], Events(_tree.Frame(buttons: Triggered(UiButton.Confirm))));

        _tree.Frame(Set(2, "typing", true));
        _tree.Point(90, 10);
        _tree.Frame();
        Assert.Equal(["2 click"], Events(_tree.Click()));
        Assert.Equal([], Events(_tree.Repeat(UiButton.Right)));
        Assert.Equal(["2 enter"], Events(_tree.Key(ComponentTree.ZKey)));
        Assert.Equal(["2 revert"], Events(_tree.Key(ComponentTree.EscapeKey, Triggered(UiButton.Cancel))));

        var typing = new TreeHarness(new FakeTyping());
        typing.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(200, 100))),
            Node(2, 1, "numeric_field", ("number", 4), ("number_min", 2), ("number_max", 40), ("number_step", 2), ("confirm_to_type", true), ("typing", true),
                 ("takes", "0"), ("rows", 1), ("at", Pair(0, 0)), ("size", Pair(100, 24))),
            Node(3, 1, "button", ("at", Pair(0, 40)), ("size", Pair(100, 24)))));
        typing.Frame(new RubyHash { { "focus", 2 } });
        int box = typing.Ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "70" }, { "number", new RubyArray { 2, 40 } } }).AsInt();
        string Typed() => typing.Ui.Tick(new RubyHash { { "edit", new RubyArray { box, -1, 0, 0, 0 } } }).Single(item => item.Topic == EditModel.EventTopic).Payload.AsHash()["text"].AsText();
        Assert.Equal([UiCue.Cursor], Cues(typing.Key(ComponentTree.UpKey)));
        Assert.Equal("40", Typed());
        Assert.Equal([UiCue.Buzzer], Cues(typing.Key(ComponentTree.UpKey)));
        RubyHash down = typing.Key(ComponentTree.DownKey);
        Assert.Equal("38", Typed());
        Assert.DoesNotContain("3 focus", Events(down));
        typing.Input.Down.Add(CtrlKey);
        Assert.Contains("3 focus", Events(typing.Key(ComponentTree.DownKey)));
        typing.Input.Down.Remove(CtrlKey);

        typing.Frame(new RubyHash { { "focus", 2 } });
        Assert.Contains("3 focus", Events(typing.Key(ComponentTree.TabKey)));
        typing.Frame(new RubyHash { { "focus", 2 } });
        typing.Frame(Set(2, "typing", false));
        typing.Input.Down.Add(ShiftKey);
        Assert.Contains("3 focus", Events(typing.Key(ComponentTree.TabKey)));
        typing.Input.Down.Remove(ShiftKey);
        typing.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["1 close"], Events(typing.Frame(buttons: Triggered(UiButton.Cancel))));
    }
}
