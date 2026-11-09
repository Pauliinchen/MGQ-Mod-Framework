//----------------------------------------------------------------
//  TreeKeysTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that a gamepad's shoulder passes tabs that show a single tab on to the window's page
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Checked that the tabs the arrows step pass over a reading pane only the jump key reaches
//                            - Checked that Page Down on a list scrolls the reading pane beside it, which takes the focus itself
//                            - Kept of the tabs that were one key stop only that Tab and R step tabs while nothing above holds the keys
//      Paulinchen  2026-11-05: Checked that Page Down tells a list that shows a page of its rows at a time to turn it
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Tree;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the keys of the component tree beyond the arrows: tabs stepped by Tab, the shoulders and
/// the arrows, the shoulders and page keys reaching the root's page, tabs that are one key stop, the
/// keys a text field claims and those the tree takes from the hotkeys, the hotkeys parts declare,
/// and the game's extra buttons.
/// </summary>
public sealed class TreeKeysTests
{
    /// <summary>Windows' code of the keyboard's C, the tests' hotkey.</summary>
    private const int CKey = 0x43;

    /// <summary>Windows' code of the keyboard's S, the game's Y button.</summary>
    private const int SKey = 0x53;

    /// <summary>Windows' code of Shift, the game's A button.</summary>
    private const int ShiftKey = 0x10;

    /// <summary>Windows' code of the left Alt.</summary>
    private const int LeftAlt = 0xA4;

    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts that tabs set to step by Tab step by Tab and Shift+Tab in place of moving the focus,
    /// also while a text field types, and the focus moves again once they hide; that tabs set to step
    /// by a gamepad's shoulders step by its L and R, also while a field types, but not by the
    /// keyboard's Q; that tabs taking the shoulders step by L and R while a list has the focus, which
    /// Page Down still pages; that tabs the arrows step take LEFT and RIGHT where the focus has no use
    /// for them, past a reading pane beside the list that only the jump key reaches; and that in the new UI layer Tab steps the tabs nearest the focus without the scripts
    /// asking, and in a window without tabs goes into the first text field and back.
    /// </summary>
    [Fact]
    public void Tabs_StepByTabTheShouldersOrTheArrows()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "list", ("rows", 20), ("index", 0), Measured(100, 72)),
            Node(3, 1, "tabs", ("tab_key", true), ("shoulder", true)),
            Node(4, 1, "button", Measured(40, 20)),
            Node(5, 1, "text_field", Measured(100, 24))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["3 step 1"], Events(_tree.Key(ComponentTree.TabKey)));
        _tree.Input.Down.Add(ComponentTree.ShiftKey);
        _tree.Frame();
        Assert.Equal(["3 step -1"], Events(_tree.Key(ComponentTree.TabKey)));
        _tree.Input.Down.Clear();
        List<string> stepped = Events(_tree.Repeat(UiButton.R));
        Assert.Contains("3 step 1", stepped);
        Assert.DoesNotContain(stepped, text => text.StartsWith("2 change", System.StringComparison.Ordinal));
        _tree.Input.Down.Add(ComponentTree.PageDownKey);
        List<string> paged = Events(_tree.Repeat(UiButton.R));
        _tree.Input.Down.Clear();
        Assert.Contains("2 change 3", paged);
        Assert.DoesNotContain("3 step 1", paged);
        _tree.Frame(new RubyHash { { "focus", 5 } });
        Assert.Equal(["3 step 1"], Events(_tree.Key(ComponentTree.TabKey)));
        _tree.Frame(Set(3, "visible", false));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(4, Focus(_tree.Key(ComponentTree.TabKey)));

        var pad = new TreeHarness();
        pad.Frame(Adds(
            Node(1, null, "box"),
            Node(2, 1, "tabs", ("pad_shoulders", true)),
            Node(3, 1, "text_field", Measured(100, 24)),
            Node(4, 1, "list", ("rows", 20), ("index", 0), ("shoulder_pages", false), Measured(100, 72))));
        pad.Frame(new RubyHash { { "focus", 3 } });
        Assert.Equal(["2 step 1"], Events(pad.Frame(buttons: Triggered(UiButton.R) | Repeated(UiButton.R))));
        pad.Frame(new RubyHash { { "focus", 4 } });
        Assert.Equal(["2 step -1"], Events(pad.Frame(buttons: Triggered(UiButton.L) | Repeated(UiButton.L))));
        Assert.DoesNotContain("2 step -1", Events(pad.Key(ComponentTree.QKey, Triggered(UiButton.L) | Repeated(UiButton.L))));

        var arrows = new TreeHarness();
        arrows.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "tabs", ("arrows", true)),
            Node(3, 1, "box", ("layout", "row")),
            Node(4, 3, "list", ("rows", 3), ("index", 0)),
            Node(5, 3, "box", ("scroll", true), ("focusable", true), ("jump_only", true))));
        arrows.Frame(new RubyHash { { "focus", 4 } });
        Assert.Contains("2 step 1", Events(arrows.Repeat(UiButton.Right)));
        Assert.Contains("2 step -1", Events(arrows.Repeat(UiButton.Left)));

        var layer = new TreeHarness();
        layer.Frame(Adds(Node(1, null, "window", ("layer", true)), Node(2, 1, "tabs"), Node(3, 1, "button", Measured(40, 20))));
        Assert.Equal(["2 step 1"], Events(layer.Press(key: ComponentTree.TabKey)));
        var field = new TreeHarness();
        field.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, 1, "button", Measured(40, 20)),
            Node(4, 1, "text_field", Measured(100, 24))));
        field.Frame(new RubyHash { { "focus", 3 } });
        Assert.Contains("4 focus", Events(field.Press(key: ComponentTree.TabKey)));
        Assert.Contains("3 focus", Events(field.Press(key: ComponentTree.TabKey)));
    }

    /// <summary>
    /// Asserts that the game's L and R a focused list does not page reach its root as page once per
    /// press, telling the gamepad from the keyboard's Q, while tabs a gamepad steps keep the pad's;
    /// and that in the new UI layer the keyboard's Q reaches the nearest part with a page from the
    /// focus upward without stepping the tabs or paging the list, Page Down pages the list or tells a
    /// list that shows a page of its rows at a time page_step, and a gamepad's shoulder steps the tabs
    /// in view, else the window's page, also past tabs that show a single tab, unless the window keeps
    /// the shoulders for its tabs.
    /// </summary>
    [Fact]
    public void Shoulders_PageTheRootWhereNoTabsTakeThem()
    {
        _tree.Frame(Adds(Node(1, null, "window"), Node(2, 1, "list", ("rows", 20), ("index", 0), ("shoulder_pages", false), Measured(100, 72))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Assert.Equal(["1 page 1 true"], Events(_tree.Frame(buttons: Triggered(UiButton.R) | Repeated(UiButton.R))));
        Assert.Empty(Events(_tree.Repeat(UiButton.R)));
        Assert.Equal(["1 page -1 false"], Events(_tree.Key(ComponentTree.QKey, Triggered(UiButton.L) | Repeated(UiButton.L))));
        _tree.Frame(Adds(Node(3, 1, "tabs", ("pad_shoulders", true))));
        Assert.Equal(["3 step 1"], Events(_tree.Frame(buttons: Triggered(UiButton.R) | Repeated(UiButton.R))));

        var page = new TreeHarness();
        page.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("pages", true)),
            Node(2, 1, "tabs"),
            Node(3, 1, "stack", ("pages", true)),
            Node(4, 3, "list", ("rows", 20), ("index", 0), Measured(100, 72))));
        Assert.Equal(["3 page -1 false"], Events(page.Press(UiButton.L, ComponentTree.QKey)));
        Assert.Equal(["4 change 3"], Events(page.Press(UiButton.R, ComponentTree.PageDownKey)));
        page.Frame(Set(4, "own_pages", true));
        Assert.Equal(["4 page_step 1"], Events(page.Press(UiButton.R, ComponentTree.PageDownKey)));

        var pad = new TreeHarness();
        pad.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("pages", true)),
            Node(2, 1, "tabs"),
            Node(3, 1, "button", Measured(40, 20))));
        Assert.Equal(["2 step 1"], Events(pad.Press(UiButton.R)));
        pad.Frame(Set(2, "tabs_shown", 1));
        Assert.Equal(["1 page 1 true"], Events(pad.Press(UiButton.R)));
        pad.Frame(Set(2, "tabs_shown", 2));
        Assert.Equal(["2 step 1"], Events(pad.Press(UiButton.R)));
        pad.Frame(Set(2, "visible", false));
        Assert.Equal(["1 page 1 true"], Events(pad.Press(UiButton.R)));
        pad.Frame(Set(1, "shoulders", "tabs"));
        Assert.Empty(Events(pad.Press(UiButton.R)));
    }

    /// <summary>
    /// Asserts that Tab and a gamepad's R step the tabs nearest the focus in their page, and that
    /// neither steps them while a modal cover above their window holds the keys, as a hotkey row
    /// waiting for its key does.
    /// </summary>
    [Fact]
    public void Tabs_StepOnlyWhileNothingHoldsTheKeysAboveThem()
    {
        _tree.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "tabs", ("tab_key", true), ("pad_shoulders", true)),
            Node(3, 2, "stack", ("layout", "row")),
            Node(4, 3, "button", Measured(40, 20), ("focusable", false)),
            Node(5, 3, "button", Measured(40, 20), ("focusable", false)),
            Node(6, 2, "stack", ("tab_page", true)),
            Node(7, 6, "list", ("rows", 3), ("index", 0), Measured(100, 72))));
        _tree.Frame(new RubyHash { { "focus", 7 } });
        Assert.Contains("2 step 1", Events(_tree.Key(ComponentTree.TabKey)));
        Assert.Contains("2 step 1", Events(_tree.Frame(buttons: Triggered(UiButton.R) | Repeated(UiButton.R))));

        _tree.Frame(Adds(Node(20, null, "box", ("modal", true), ("z", 500), ("size", Pair(1, 1)))));
        Assert.DoesNotContain(Events(_tree.Key(ComponentTree.TabKey)), text => text.StartsWith("2 step", System.StringComparison.Ordinal));
        Assert.DoesNotContain(Events(_tree.Frame(buttons: Triggered(UiButton.R) | Repeated(UiButton.R))), text => text.StartsWith("2 step", System.StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts the keys the tree takes from the hotkeys and those it leaves to a focused text field:
    /// Tab moves the focus in a window and counts as taken, but leaves a floating box alone; a field
    /// that claims Tab is told of it, the key still taken; Enter, which the game reads as confirm,
    /// clicks the focused button once with the confirm sound unless the button is quiet; a gamepad's
    /// DOWN reaches a field that claims the arrow keys as DOWN and leaves one that does not; and a key
    /// a field claims with Alt is told only while the left Alt is held.
    /// </summary>
    [Fact]
    public void Keys_GoToTheFocusedFieldOrMoveTheFocus()
    {
        _tree.Frame(Adds(Node(1, null, "box"), Node(2, 1, "button", Measured(40, 20)), Node(3, 1, "button", Measured(40, 20))));
        _tree.Frame(new RubyHash { { "focus", 2 } });
        RubyHash floating = _tree.Key(ComponentTree.TabKey);
        Assert.Empty(Events(floating));
        Assert.True(floating["taken"].IsNil);
        _tree.Frame(Adds(Node(4, null, "window"), Node(5, 4, "button", Measured(40, 20)), Node(6, 4, "button", Measured(40, 20), ("quiet", true))));
        RubyHash moved = _tree.Key(ComponentTree.TabKey);
        Assert.Equal(["5 blur", "6 focus"], Events(moved));
        Assert.Equal(new RubyArray { ComponentTree.TabKey }, moved["taken"]);
        RubyHash quiet = _tree.Key(ComponentTree.EnterKey, Triggered(UiButton.Confirm));
        Assert.Equal(["6 click"], Events(quiet));
        Assert.True(quiet["cues"].IsNil);
        _tree.Frame(new RubyHash { { "focus", 5 } });
        RubyHash entered = _tree.Key(ComponentTree.EnterKey, Triggered(UiButton.Confirm));
        Assert.Equal(["5 click"], Events(entered));
        Assert.Equal(["ok"], Cues(entered));

        var fields = new TreeHarness();
        fields.Frame(Adds(
            Node(1, null, "window"),
            Node(2, 1, "text_field", Measured(100, 24), ("keys", new RubyArray { ComponentTree.TabKey, ComponentTree.UpKey, ComponentTree.DownKey })),
            Node(3, 1, "text_field", Measured(100, 24), ("keys", new RubyArray { ComponentTree.UpKey | Ui.Tree.Node.AltFlag })),
            Node(4, 1, "button", Measured(40, 20))));
        fields.Frame(new RubyHash { { "focus", 2 } });
        RubyHash claimed = fields.Key(ComponentTree.TabKey);
        Assert.Equal(["2 key 9"], Events(claimed));
        Assert.Equal(new RubyArray { ComponentTree.TabKey }, claimed["taken"]);
        Assert.Equal(["2 key 40"], Events(fields.Repeat(UiButton.Down)));
        fields.Frame(new RubyHash { { "focus", 3 } });
        Assert.DoesNotContain("3 key 294", Events(fields.Key(ComponentTree.UpKey)));
        fields.Frame(new RubyHash { { "focus", 3 } });
        fields.Input.Down.Add(LeftAlt);
        fields.Frame();
        Assert.Contains("3 key 294", Events(fields.Key(ComponentTree.UpKey)));
        fields.Input.Down.Clear();
        fields.Frame();
        Assert.Equal(4, Focus(fields.Repeat(UiButton.Down)));
    }

    /// <summary>
    /// Asserts that a hotkey stays quiet while its part hides, while a text field types and while a
    /// dialog above holds the game's buttons, and that one on a key of the framework's own, such as
    /// confirm's Z, never acts, each reason told.
    /// </summary>
    [Fact]
    public void Hotkeys_StayQuietWhereTheyMustNotAct()
    {
        _tree.Frame(Hotkeys(("compare", CKey), ("confirm", ComponentTree.ZKey)));
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", Measured(40, 20), ("hotkey", "compare")),
            Node(3, 1, "button", Measured(40, 20), ("hotkey", "confirm")),
            Node(4, 1, "text_field", Measured(100, 24))));

        _tree.Frame(Set(2, "visible", false));
        RubyHash hidden = _tree.Press(key: CKey);
        Assert.Empty(Events(hidden));
        Assert.Equal(new RubyArray { new RubyArray { "compare", "its part is hidden", false } }, hidden["quiet"]);
        _tree.Frame(Set(2, "visible", true));
        RubyHash confirm = _tree.Press(key: ComponentTree.ZKey);
        Assert.DoesNotContain("3 click", Events(confirm));
        Assert.Equal(new RubyArray { new RubyArray { "confirm", "its key is one of the framework's own keys", false } }, confirm["quiet"]);
        _tree.Frame(new RubyHash { { "focus", 4 } });
        RubyHash typing = _tree.Press(key: CKey);
        Assert.Empty(Events(typing));
        Assert.True(typing["quiet"].IsNil);
        _tree.Frame(Adds(Node(9, null, "dialog", ("layer", true)), Node(10, 9, "button", Measured(40, 20))));
        _tree.Frame(Set(1, "held_under", true));
        Assert.Equal(new RubyArray { new RubyArray { "compare", "a window above holds the game's buttons", false } }, _tree.Press(key: CKey)["quiet"]);
    }

    /// <summary>
    /// Asserts that a hotkey on S, the game's Y button, presses its part while no screen uses Y, and
    /// that the button wins, told as a clash, while the window takes Y or the game's own screen asked
    /// about Y in the frame before; and that a hotkey on Shift, the game's A button, presses its part
    /// in a window of the new UI layer, whose jump keys take A only from a gamepad, and in an old one.
    /// </summary>
    [Fact]
    public void Hotkeys_OnTheGamesButtonKeys_ActWhereNoScreenUsesTheButton()
    {
        _tree.Frame(Hotkeys(("compare", SKey), ("jump", ShiftKey)));
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", Measured(40, 20), ("hotkey", "compare")),
            Node(3, 1, "button", Measured(40, 20), ("hotkey", "jump"))));

        Assert.Contains("2 click", Events(_tree.Press(key: SKey)));
        Assert.Contains("3 click", Events(_tree.Press(key: ShiftKey)));
        _tree.Frame(Set(1, "extra_buttons", new RubyArray { "Y" }));
        RubyHash taken = _tree.Press(key: SKey);
        Assert.DoesNotContain("2 click", Events(taken));
        Assert.Equal(new RubyArray { new RubyArray { "compare", "the window in front takes the game's Y button", true } }, taken["quiet"]);
        _tree.Frame(Set(1, "extra_buttons", new RubyArray()));
        _tree.Input.Down.Add(SKey);
        RubyHash asked = _tree.Frame(extra: 1 << ((3 * UiExtraButtons.Count) + (int)UiExtraButton.Y));
        _tree.Input.Down.Clear();
        _tree.Frame();
        Assert.Equal("the game's screen uses the game's Y button", asked["clashes"].AsHash()["compare"].AsText());

        var old = new TreeHarness();
        old.Frame(Hotkeys(("jump", ShiftKey)));
        old.Frame(Adds(Node(1, null, "window"), Node(2, 1, "button", Measured(40, 20), ("hotkey", "jump"))));
        old.Frame(new RubyHash { { "focus", 2 } });
        Assert.Contains("2 click", Events(old.Press(key: ShiftKey)));
    }

    /// <summary>
    /// Asserts that a game's extra button in the new UI layer goes to the nearest part from the focus
    /// upward that takes it, that one no part takes does nothing, and that today's windows take none.
    /// </summary>
    [Fact]
    public void ExtraButtons_GoToTheNearestPartThatTakesThem()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("extra_buttons", new RubyArray { "Y" })),
            Node(2, 1, "list", ("rows", 3), ("index", 0), Measured(100, 72), ("extra_buttons", new RubyArray { "Z", "Y" }))));

        Assert.Equal(["2 button Z"], Events(Extra(_tree, UiExtraButton.Z)));
        Assert.Equal(["2 button Y"], Events(Extra(_tree, UiExtraButton.Y)));
        Assert.Empty(Events(Extra(_tree, UiExtraButton.X)));
        _tree.Frame(Set(2, "extra_buttons", new RubyArray()));
        Assert.Equal(["1 button Y"], Events(Extra(_tree, UiExtraButton.Y)));

        var today = new TreeHarness();
        today.Frame(Adds(Node(1, null, "window", ("extra_buttons", new RubyArray { "X" })), Node(2, 1, "button", Measured(40, 20))));
        Assert.Empty(Events(Extra(today, UiExtraButton.X)));
    }

    /// <summary>
    /// Presses one of the game's extra buttons in a frame and lets it go in the next.
    /// </summary>
    /// <param name="tree">The tree.</param>
    /// <param name="button">The button.</param>
    /// <returns>The report of the frame it went down in.</returns>
    private static RubyHash Extra(TreeHarness tree, UiExtraButton button)
    {
        RubyHash report = tree.Frame(extra: (1 << (int)button) | (1 << ((2 * UiExtraButtons.Count) + (int)button)));
        tree.Frame();
        return report;
    }

    /// <summary>
    /// Asserts that in a root of the new UI layer Page Down on a list whose paging scrolls the box
    /// beside it scrolls that box, a reading pane of text, and that the focus asked into that box,
    /// which holds no key stop, goes onto the box itself, where Down scrolls it a line.
    /// </summary>
    [Fact]
    public void PageDown_OnAListThatPagesTheBoxBeside_ScrollsTheBox()
    {
        RubyHash first = _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(300, 100)), ("layout", "row")),
            Node(2, 1, "list", ("rows", 20), ("index", 0), ("pages_beside", true), Measured(100, 72)),
            Node(3, 1, "box", ("scroll", true), ("grow", 1), ("focusable", true), ("jump_only", true), ("keep_ends", true)),
            Node(4, 3, "custom", Measured(180, 400))));
        Assert.Equal(0, first["scroll"].AsHash()[3].AsArray()[0].AsInt());
        _tree.Frame(new RubyHash { { "focus", 2 } });
        _tree.Input.Down.Add(ComponentTree.PageDownKey);
        RubyHash paged = _tree.Repeat(UiButton.R);
        _tree.Input.Down.Clear();
        Assert.DoesNotContain("2 change 3", Events(paged));
        Assert.True(paged["scroll"].AsHash()[3].AsArray()[0].AsInt() > 0);
        Assert.Equal(3, Focus(_tree.Frame(new RubyHash { { "focus_in", 3 } })));
    }
}
