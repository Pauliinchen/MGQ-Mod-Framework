//----------------------------------------------------------------
//  TreeCancelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Covered cancel closing the Equipment Window from the slot list it opened on
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Covered cancel walking back to the list that handed the focus over
//                            - Covered an arrow or a click into a list as the way back for cancel
//                            - Took out the check of the tree kept from the keys while a box outside it typed
//      Paulinchen  2026-11-06: Checked cancel walking back from a tab's page to the part above its tabs, which are no key stop
//      Paulinchen  2026-11-05: Covered a gamepad's cancel told to a root that guards its cancel
//                            - Covered cancel walking back from the list a bar of tabs fills
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Text;
using MGQParadox.ModFramework.Ui.Tree;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers cancel in the component tree: what it leaves, closes or asks, the cancel keys read a tick
/// before the game's cancel, the cancel keys of F1 in a text field by what the field types, the way
/// back the new UI layer walks, and the presses older than a root.
/// </summary>
public sealed class TreeCancelTests
{
    /// <summary>
    /// Windows' code of the letter V, which the tests bind to cancel in F1.
    /// </summary>
    private const int VKey = 0x56;

    /// <summary>
    /// The place of V among the bytes of the key settings of F1.
    /// </summary>
    private const int VKeyByte = ButtonAssignment.PadButtons + 8;

    /// <summary>
    /// What ButtonAssign holds for the game's cancel button, B.
    /// </summary>
    private const byte CancelButton = 12;

    /// <summary>
    /// What ButtonAssign holds for the game's confirm button, C.
    /// </summary>
    private const byte ConfirmButton = 13;

    /// <summary>
    /// The tree run tick by tick, with the text box.
    /// </summary>
    private readonly TreeHarness _tree = new(new FakeTyping());

    /// <summary>
    /// Asserts that cancel only takes the focus out of a root it does not close, giving it back to
    /// the window below; that it moves the focus to the part the focused one sends it to with the
    /// cancel sound before it closes the window; that the tree leaves out what a tick adds to the
    /// closed window while it adds to a live box; and that a root that guards its cancel is only
    /// asked and stays, told whether a gamepad cancelled, so the game's letters take a letter away.
    /// </summary>
    [Fact]
    public void Cancel_LeavesClosesOrAsksTheRoot()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", Measured(40, 20)),
            Node(5, 1, "stack", ("cancel_to", 2)),
            Node(6, 5, "button", Measured(40, 20)),
            Node(3, null, "box", ("at", Pair(300, 0))),
            Node(4, 3, "text_field", Measured(100, 24)),
            Node(10, null, "box", ("at", Pair(300, 200)))));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(["4 blur", "2 focus"], Events(_tree.Key(ComponentTree.EscapeKey, Triggered(UiButton.Cancel))));
        _tree.Frame(new RubyHash { { "focus", 6 } });
        RubyHash back = _tree.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Equal(["6 blur", "2 focus"], Events(back));
        Assert.Equal(["cancel"], Cues(back));
        RubyHash closed = _tree.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Equal(["1 close"], Events(closed));
        Assert.Equal(["cancel"], Cues(closed));

        RubyHash report = _tree.Frame(Adds(Node(20, 10, "button", Measured(40, 20)), Node(7, 1, "button", Measured(40, 20)), Node(8, 7, "custom", Measured(10, 10))));
        Assert.True(report["rects"].AsHash().ContainsKey(20));
        Assert.False(report["rects"].AsHash().ContainsKey(7));

        var guarded = new TreeHarness();
        guarded.Frame(Adds(Node(1, null, "window", ("cancel_guard", true)), Node(2, 1, "button", Measured(40, 20))));
        Assert.Equal(["1 cancel"], Events(guarded.Key(ComponentTree.EscapeKey, Triggered(UiButton.Cancel))));
        Assert.Equal(["1 cancel pad"], Events(guarded.Frame(buttons: Triggered(UiButton.Cancel))));
    }

    /// <summary>
    /// Asserts that a cancel key read a tick before the game's cancel that follows it cancels once,
    /// the game's late cancel closing nothing more; that Escape read a tick early, which the tree
    /// takes only from the game's buttons, still closes the window once the game's cancel comes; and
    /// that the numpad's 0 with nothing to close or leave leaves the game's cancel to the game.
    /// </summary>
    [Fact]
    public void CancelKeys_ReadBeforeTheGamesCancel_CancelOnce()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(40, 20))));
        _tree.Frame(Adds(Node(3, null, "window"), Node(4, 3, "button", Measured(40, 20))));
        _tree.Input.Down.Add(ComponentTree.NumpadZero);
        Assert.Equal(["3 close", "2 focus"], Events(_tree.Frame()));
        RubyHash late = _tree.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Empty(Events(late));
        Assert.Equal(Triggered(UiButton.Cancel), late["late"].AsInt());
        _tree.Input.Down.Clear();
        _tree.Frame();

        _tree.Input.Down.Add(ComponentTree.EscapeKey);
        Assert.Empty(Events(_tree.Frame()));
        RubyHash escaped = _tree.Frame(buttons: Triggered(UiButton.Cancel));
        Assert.Equal(["1 close"], Events(escaped));
        Assert.True(escaped["late"].IsNil);
        _tree.Input.Down.Clear();
        _tree.Frame();

        _tree.Frame(Adds(Node(5, null, "box"), Node(6, 5, "custom", Measured(40, 20))));
        _tree.Input.Down.Add(ComponentTree.NumpadZero);
        Assert.Empty(Events(_tree.Frame()));
        Assert.True(_tree.Frame(buttons: Triggered(UiButton.Cancel))["late"].IsNil);
    }

    /// <summary>
    /// Asserts that the cancel keys leave a focused text field only where it would type nothing: a
    /// letter bound to cancel in F1 closes a window but types in a field that takes letters, and
    /// leaves one that refuses them; an x, which the game reads as cancel, types while a gamepad's
    /// cancel with no key down leaves; the numpad's 0 with Num Lock on types into a field of digits
    /// while with Num Lock off it leaves; a read-only field leaves on every cancel key; and Escape
    /// leaves a field even when F1 binds it to confirm.
    /// </summary>
    [Fact]
    public void TextField_LeavesOnlyOnACancelKeyItDoesNotType()
    {
        _tree.Input.Assign = FakeInput.Bound(VKeyByte, CancelButton);
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(40, 20))));
        Assert.Equal(["1 close"], Events(_tree.Key(VKey, Triggered(UiButton.Cancel))));

        _tree.Frame(Adds(Node(3, null, "box"), Node(4, 3, "text_field", Measured(100, 24))));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Empty(Events(_tree.Key(VKey, Triggered(UiButton.Cancel))));
        Assert.Empty(Events(_tree.Key(ComponentTree.XKey, Triggered(UiButton.Cancel))));
        Assert.Equal(["4 blur"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));

        _tree.Frame(new RubyHash { { "focus", 4 } });
        _tree.Frame(Set(4, "takes", "0"));
        Assert.Empty(Events(_tree.Key(ComponentTree.NumpadZero)));
        Assert.Equal(["4 blur"], Events(_tree.Key(ComponentTree.InsertKey)));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(["4 blur"], Events(_tree.Key(VKey, Triggered(UiButton.Cancel))));

        _tree.Frame(Set(4, "takes", string.Empty));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(["4 blur"], Events(_tree.Key(VKey, Triggered(UiButton.Cancel))));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(["4 blur"], Events(_tree.Key(ComponentTree.NumpadZero)));

        var rebound = new TreeHarness();
        rebound.Input.Assign = FakeInput.Bound(ButtonAssignment.PadButtons + 2, ConfirmButton);
        rebound.Frame(Adds(Node(1, null, "box"), Node(2, 1, "text_field", Measured(100, 24))));
        rebound.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 blur"], Events(rebound.Key(ComponentTree.EscapeKey, Triggered(UiButton.Confirm))));
    }

    /// <summary>
    /// Asserts what a cancel key that left a field does: a field that asks is told the cancel before
    /// its blur; the 0 of the numpad's 0 reaches no text box afterwards; a text field that is a root
    /// of its own closes only when closable; a field typed into only once confirmed takes cancel as
    /// putting its text back while it types; and in the new UI layer the first cancel in a field Tab
    /// went into only stops the typing with the focus kept, confirm types again, and cancel in the
    /// field that rests closes the window, while a window of today's screens closes at once.
    /// </summary>
    [Fact]
    public void TextField_TellsAndStopsWhatACancelKeyLeft()
    {
        var keyboard = new FakeTyping();
        var tree = new TreeHarness(keyboard);
        tree.Frame(Adds(Node(1, null, "box"), Node(2, 1, "text_field", ("tells_cancelled", true)), Node(3, 1, "text_field")));
        tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["2 cancelled", "2 blur"], Events(tree.Key(ComponentTree.EscapeKey)));
        tree.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(["3 blur"], Events(tree.Key(ComponentTree.NumpadZero)));
        int box = tree.Ui.Value(EditModel.OpenTopic, new RubyHash { { "text", "" } }).AsInt();
        keyboard.Typed.Enqueue(("0a", 2));
        RubyHash typed = tree.Ui.Tick(new RubyHash { { "edit", new RubyArray { box, -1, 1, 0, 0 } } }).Single(item => item.Topic == EditModel.EventTopic).Payload.AsHash();
        Assert.Equal("a", typed["text"].AsText());

        _tree.Frame(Adds(Node(1, null, "text_field", Measured(240, 24))));
        _tree.Frame(new RubyHash { { "focus", 1 } });
        Assert.Equal(["1 blur"], Events(_tree.Key(ComponentTree.NumpadZero)));
        _tree.Frame(Adds(Node(5, null, "text_field", Measured(240, 24), ("closable", true))));
        _tree.Frame(new RubyHash { { "focus", 5 } });
        Assert.Equal(["5 close"], Events(_tree.Key(ComponentTree.NumpadZero)));

        _tree.Frame(Adds(Node(10, null, "window"), Node(11, 10, "text_field", Measured(100, 24), ("confirm_to_type", true)), Node(12, 10, "button", Measured(60, 24))));
        _tree.Frame(new RubyHash { { "focus", 11 } });
        Assert.Equal(["11 click"], Events(_tree.Frame(buttons: Triggered(UiButton.Confirm))));
        _tree.Frame(Set(11, "typing", true));
        Assert.Equal(["11 revert"], Events(_tree.Key(ComponentTree.EscapeKey, Triggered(UiButton.Cancel))));
        _tree.Frame(Set(11, "typing", false));
        Assert.Contains("12 focus", Events(_tree.Repeat(UiButton.Down)));

        var layer = new TreeHarness();
        layer.Frame(Adds(Node(1, null, "window", ("layer", true)), Node(2, 1, "button", Measured(40, 20)), Node(3, 1, "text_field", Measured(100, 24))));
        Assert.Contains("3 focus", Events(layer.Press(key: ComponentTree.TabKey)));
        Assert.Equal(["3 rest"], Events(layer.Press(key: ComponentTree.EscapeKey)));
        Assert.Equal(["3 click"], Events(layer.Press(UiButton.Confirm)));
        layer.Frame(Set(3, "typing", true));
        Assert.Equal(["3 rest"], Events(layer.Press(key: ComponentTree.EscapeKey)));
        Assert.Contains("1 close", Events(layer.Press(UiButton.Cancel)));

        var today = new TreeHarness();
        today.Frame(Adds(Node(1, null, "window"), Node(3, 1, "text_field", Measured(100, 24))));
        Assert.Contains("1 close", Events(today.Press(key: ComponentTree.EscapeKey)));
    }

    /// <summary>
    /// Asserts that in the new UI layer cancel in a tab's page goes back to the part above the tabs
    /// the player entered it from before the next cancel closes the window, and that cancel on a slides' page
    /// goes back to the part on the page before that RIGHT came from, while a player who walked back
    /// by LEFT is not sent forth again: cancel then closes.
    /// </summary>
    [Fact]
    public void LayerCancel_WalksBackTheWayThePlayerCame()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, 1, "tabs"),
            Node(4, 3, "stack", Measured(100, 20)),
            Node(5, 3, "stack", ("tab_page", true)),
            Node(6, 5, "button", Measured(40, 20))));
        Assert.Contains("6 focus", Events(_tree.Press(UiButton.Down)));
        Assert.Contains("2 focus", Events(_tree.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(_tree.Press(UiButton.Cancel)));

        var slides = new TreeHarness();
        slides.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "slides", ("layout", "row"), ("shown", 2)),
            Node(3, 2, "stack"),
            Node(4, 3, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
            Node(5, 2, "stack"),
            Node(6, 5, "button", Measured(40, 20))));
        Assert.Contains("6 focus", Events(slides.Press(UiButton.Right)));
        Assert.Contains("4 focus", Events(slides.Press(UiButton.Cancel)));
        Assert.Contains("6 focus", Events(slides.Press(UiButton.Right)));
        Assert.Contains("4 focus", Events(slides.Press(UiButton.Left)));
        Assert.Contains("1 close", Events(slides.Press(UiButton.Cancel)));
    }

    /// <summary>
    /// Asserts that in the new UI layer cancel in the list a bar of tabs fills, which the scripts mark
    /// as the bar's panel and ask the focus into as a tab is picked, goes back to the tab the player
    /// came from, as a trade's bag goes back to its kind, before the next cancel reaches the window.
    /// </summary>
    [Fact]
    public void LayerCancel_WalksBackFromTheListABarOfTabsFills()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "button", ("acts", true), Measured(60, 20)),
            Node(4, 2, "button", ("acts", true), Measured(60, 20)),
            Node(5, 1, "list", ("rows", 3), ("index", 0), ("tab_page", true), Measured(120, 72))));
        _tree.Frame(new RubyHash { { "focus", 4 } });
        Assert.Contains("5 focus", Events(_tree.Frame(new RubyHash { { "focus_in", 5 } })));
        Assert.Contains("4 focus", Events(_tree.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(_tree.Press(UiButton.Cancel)));
    }

    /// <summary>
    /// Asserts that in the new UI layer cancel in a list goes back to the part the player entered it
    /// from, by a pick the scripts hand on as a list's submit_to does, by RIGHT or by a click, as from
    /// the mods of Options > Mods into their options, and that the next cancel closes the window
    /// instead of walking on; and that cancel in the filter rows of the mod browser, clicked into
    /// from the Filters button, goes back to the button.
    /// </summary>
    [Fact]
    public void LayerCancel_WalksBackToTheListThatHandedTheFocusOver()
    {
        TreeHarness picked = ModsBesideOptions(out _);
        Assert.Contains("4 focus", Events(picked.Frame(new RubyHash { { "focus", 4 } })));
        Assert.Contains("3 focus", Events(picked.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(picked.Press(UiButton.Cancel)));

        TreeHarness stepped = ModsBesideOptions(out _);
        Assert.Contains("4 focus", Events(stepped.Press(UiButton.Right)));
        Assert.Contains("3 focus", Events(stepped.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(stepped.Press(UiButton.Cancel)));

        TreeHarness clicked = ModsBesideOptions(out int[] options);
        clicked.Point(options[0] + 5, options[1] + 5);
        Assert.Contains("4 focus", Events(clicked.Click()));
        Assert.Contains("3 focus", Events(clicked.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(clicked.Press(UiButton.Cancel)));

        RubyHash opened = _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", ("acts", true), Measured(60, 20)),
            Node(3, 1, "box", ("enter", true), ("focusable", true)),
            Node(4, 3, "list", ("rows", 3), ("index", 0), Measured(100, 72))));
        int[] filters = Rect(opened, 4);
        _tree.Frame(new RubyHash { { "focus", 2 } });
        _tree.Point(filters[0] + 5, filters[1] + 5);
        Assert.Contains("4 focus", Events(_tree.Click()));
        Assert.Contains("2 focus", Events(_tree.Press(UiButton.Cancel)));
    }

    /// <summary>
    /// Asserts that in the new UI layer cancel on the part a window opened on closes the window at
    /// once, as in the Equipment Window's slot list: right after it opened, after the cursor moved,
    /// after Q, after the player stepped through Optimize and Clear and back by the arrows, and
    /// after the details slid into view beside it; while cancel on a button the player stepped to
    /// and on the details goes back to the slot list first.
    /// </summary>
    [Fact]
    public void LayerCancel_OnThePartAWindowOpenedOn_ClosesTheWindow()
    {
        TreeHarness opened = EquipmentWindow();
        Assert.Contains("1 close", Events(opened.Press(UiButton.Cancel)));

        TreeHarness moved = EquipmentWindow();
        moved.Press(UiButton.Up);
        moved.Press(UiButton.Down);
        Assert.Contains("1 close", Events(moved.Press(UiButton.Cancel)));

        TreeHarness switched = EquipmentWindow();
        Assert.Contains(Events(switched.Press(UiButton.L)), text => text.StartsWith("1 page -1", System.StringComparison.Ordinal));
        Assert.Contains("1 close", Events(switched.Press(UiButton.Cancel)));

        TreeHarness stepped = EquipmentWindow();
        Assert.Contains("5 focus", Events(stepped.Press(UiButton.Left)));
        Assert.Contains("8 focus", Events(stepped.Press(UiButton.Cancel)));
        Assert.Contains("5 focus", Events(stepped.Press(UiButton.Left)));
        Assert.Contains("6 focus", Events(stepped.Press(UiButton.Right)));
        Assert.Contains("8 focus", Events(stepped.Press(UiButton.Right)));
        Assert.Contains("1 close", Events(stepped.Press(UiButton.Cancel)));

        TreeHarness details = EquipmentWindow();
        Assert.Contains("2 slide 1", Events(details.Press(UiButton.Right)));
        details.Frame(new RubyHash
        {
            { "set", new RubyArray { new RubyArray { 2, new RubyHash { { "slide_back", true } } }, new RubyArray { 3, new RubyHash { { "visible", false } } }, new RubyArray { 9, new RubyHash { { "visible", true } } } } },
        });
        Assert.Contains("10 focus", Events(details.Press(UiButton.Right)));
        Assert.Contains("8 focus", Events(details.Press(UiButton.Cancel)));
        Assert.Contains("1 close", Events(details.Press(UiButton.Cancel)));
    }

    /// <summary>
    /// Asserts that a root added in the tick its confirm went down is not clicked by it, that a button
    /// held since before a root opened moves nothing in it until pressed again, that a hotkey pressed
    /// in the tick its root opens acts only once pressed again, and that an extra button held since
    /// before its window of the new UI layer opened, such as the held message skip, acts only once
    /// let go and pressed again.
    /// </summary>
    [Fact]
    public void PressesOlderThanARoot_WaitForTheNextPress()
    {
        RubyHash added = _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, 1, "button", Measured(40, 20))), Triggered(UiButton.Confirm) | Held(UiButton.Down));
        Assert.DoesNotContain("2 click", Events(added));
        Assert.DoesNotContain("3 focus", Events(_tree.Frame(buttons: Repeated(UiButton.Down) | Held(UiButton.Down))));
        _tree.Frame();
        Assert.Contains("3 focus", Events(_tree.Frame(buttons: Triggered(UiButton.Down) | Repeated(UiButton.Down) | Held(UiButton.Down))));

        var hotkey = new TreeHarness();
        hotkey.Frame(Hotkeys(("compare", 0x43)));
        hotkey.Input.Down.Add(0x43);
        RubyHash opening = hotkey.Frame(Adds(Node(1, null, "window", ("layer", true)), Node(2, 1, "button", Measured(40, 20), ("hotkey", "compare"))));
        hotkey.Input.Down.Clear();
        hotkey.Frame();
        Assert.DoesNotContain("2 click", Events(opening));
        Assert.Contains("2 click", Events(hotkey.Press(key: 0x43)));

        int heldX = 1 << ((2 * UiExtraButtons.Count) + (int)UiExtraButton.X);
        int downX = (1 << (int)UiExtraButton.X) | heldX;
        var skip = new TreeHarness();
        skip.Frame(extra: heldX);
        skip.Frame(Adds(Node(1, null, "window", ("layer", true), ("extra_buttons", new RubyArray { "X" })), Node(2, 1, "button", Measured(40, 20))), extra: heldX);
        Assert.Empty(Events(skip.Frame(extra: downX)));
        skip.Frame();
        Assert.Equal(["1 button X"], Events(skip.Frame(extra: downX)));
    }

    /// <summary>
    /// Opens a window of the new UI layer with the mods beside their options, as Options > Mods, the
    /// focus on the mods.
    /// </summary>
    /// <param name="options">The place of the options' list.</param>
    /// <returns>The tree.</returns>
    private static TreeHarness ModsBesideOptions(out int[] options)
    {
        var tree = new TreeHarness();
        RubyHash opened = tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "stack", ("layout", "row")),
            Node(3, 2, "list", ("rows", 3), ("index", 0), Measured(100, 72)),
            Node(4, 2, "list", ("rows", 3), ("index", 0), Measured(100, 72))));
        options = Rect(opened, 4);
        tree.Frame(new RubyHash { { "focus", 3 } });
        return tree;
    }

    /// <summary>
    /// Opens a window of the new UI layer shaped as the Equipment Window: slides with two of three
    /// pages in view, the character's page with Optimize and Clear, the gear's page with the slot
    /// list the window opens on, and the details' page out of view with its Back link.
    /// </summary>
    /// <returns>The tree.</returns>
    private static TreeHarness EquipmentWindow()
    {
        var tree = new TreeHarness();
        RubyHash opened = tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("pages", true)),
            Node(2, 1, "slides", ("layout", "row"), ("shown", 2), ("slide_keys", true), ("slide_back", false)),
            Node(3, 2, "stack"),
            Node(4, 3, "stack", ("layout", "row")),
            Node(5, 4, "button", ("acts", true), Measured(60, 20)),
            Node(6, 4, "button", ("acts", true), Measured(60, 20)),
            Node(7, 2, "stack"),
            Node(8, 7, "list", ("rows", 3), ("index", 0), ("acts", true), ("autofocus", true), Measured(100, 72)),
            Node(9, 2, "stack", ("visible", false)),
            Node(10, 9, "button", ("acts", true), Measured(60, 20))));
        Assert.Equal(["8 focus"], Events(opened));
        return tree;
    }
}
