//----------------------------------------------------------------
//  ComponentTreeKeys.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Kept a numpad digit typed into a text field from stepping, scrolling or leaving it as a direction
//                            - Asked the input model whether cancel, confirm, the shoulders and the jump button came from a gamepad
//      Paulinchen  2026-11-09: Let cancel on the part a window opened on close it instead of walking a way back or sliding back
//                            - Let the keys that step tabs pass over tabs that show a single tab
//      Paulinchen  2026-11-07: Moved an item carried between drop zones by the arrows and put it back by cancel
//                            - Wrapped a grid of boxes, such as cards, on a fresh press at its edge and stopped a held arrow there
//                            - Stepped a slider by LEFT and RIGHT within its bounds
//                            - Took the key handling of the tree and split the plain keys into one method per key group
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Noted the component that handed the focus to a list
//                            - Noted an arrow or a click into a list as the way back for cancel
//                            - Asked the framework's own keys of KeyNames
//                            - Took out the hotkeys kept quiet while a box outside the tree typed
//      Paulinchen  2026-11-06: Kept LEFT and RIGHT with the jump key held reaching a part the keys reach only by it
//                            - Scrolled the box beside a list whose paging scrolls it by Page Up and Page Down and the paging
//                              the shoulders fall back to
//                            - Walked the focus out of a number field by Tab as out of a numeric field
//      Paulinchen  2026-11-05: Told a list that shows a page of its rows at a time to turn it by Page Up and Page Down
//                            - Reached a part the keys reach only by the jump key by an arrow with the jump key held
//                            - Moved the cursor's row of a list that takes the framework's Move Up and Move Down hotkeys,
//                              as the framework's own mod list does, one place within its group by them
//                            - Walked the focus out of a numeric field to the next part by Tab, or back by Shift+Tab
//      Paulinchen  2026-11-04: Kept the focus on a text field whose typing its first cancel stopped
//                            - Let a hotkey on a key of the game's extra buttons act wherever no screen uses that button,
//                              and told the clash where one does
//                            - Found the part a list's submit goes up to
//                            - Jumped out of a list or a row by an arrow with the jump key or a gamepad's A held, an A held
//                              since the root opened left out
//                            - Told the nearest part that takes one of the game's extra buttons that it went down
//                            - Wrapped a list on a fresh press at its end
//                            - Walked cancel back the way the focus came into a page, and stopped a text field's typing on
//                              its first cancel
//                            - Pressed the parts whose declared hotkey went down unless it is quiet
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Options;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The key handling of the tree: the keys of a typing text field, the plain keys outside one (cancel,
/// confirm, Tab, the shoulders and the arrows), the steps of lists and fields and the moves of the
/// focus, and the key rules of the UI layer's roots: the game's L and R split by device, the Tab
/// rule and the hotkeys parts declare.
/// </summary>
internal sealed partial class ComponentTree
{
    /// <summary>
    /// Why a hotkey stays quiet without a line in the log: something types, or its root opened in
    /// the tick its key went down.
    /// </summary>
    private const string SilentlyQuiet = "";

    /// <summary>
    /// The name of the framework's hotkey held with an arrow to jump out of a list.
    /// </summary>
    private const string JumpHotkey = "list_jump";

    /// <summary>
    /// Windows' code of Ctrl, the jump hotkey's key until the player binds another.
    /// </summary>
    private const int CtrlKey = 0x11;

    /// <summary>
    /// The name of the framework's hotkey that moves the cursor's row of a list one place up.
    /// </summary>
    private const string MoveUpHotkey = "list_move_up";

    /// <summary>
    /// The name of the framework's hotkey that moves the cursor's row of a list one place down.
    /// </summary>
    private const string MoveDownHotkey = "list_move_down";

    /// <summary>
    /// The game's extra buttons in the order a frame's presses of them are told.
    /// </summary>
    private static readonly UiExtraButton[] ExtraButtonOrder = [UiExtraButton.A, UiExtraButton.X, UiExtraButton.Y, UiExtraButton.Z];

    /// <summary>
    /// The hotkeys the scripts defined: each hotkey's name with its key and why it is off its scenes,
    /// null while it is on them.
    /// </summary>
    private Dictionary<string, (int Code, string? OffScene)> _hotkeys = [];

    /// <summary>
    /// The hotkeys pressed that stayed quiet since the last report, each [name, why].
    /// </summary>
    private RubyArray _quiet = [];

    /// <summary>
    /// The hotkeys pressed since the last report whose key a screen used as one of the game's extra
    /// buttons, each name with why.
    /// </summary>
    private RubyHash _clashes = new();

    /// <summary>
    /// The component Tab left for the first text field of a root without tabs, where Tab goes back.
    /// </summary>
    private Node? _tabLeft;

    /// <summary>
    /// Tells whether a row of tabs steps by Tab: as the scripts set it, else in a root of the new UI
    /// layer.
    /// </summary>
    /// <param name="tabs">The tabs.</param>
    /// <returns>Whether it does.</returns>
    private static bool StepsByTab(Node tabs) => tabs.TabKey ?? Focus.RootOf(tabs).Layer;

    /// <summary>
    /// Tells whether a row of tabs steps by a gamepad's shoulders: as the scripts set it, else in a
    /// root of the UI layer.
    /// </summary>
    /// <param name="tabs">The tabs.</param>
    /// <returns>Whether it does.</returns>
    private static bool StepsByPad(Node tabs) => tabs.PadShoulders ?? Focus.RootOf(tabs).Layer;

    /// <summary>
    /// Takes the hotkeys the scripts defined.
    /// </summary>
    /// <param name="value">{name => [key code, why it is off its scenes or nil]}, nil to keep those taken last.</param>
    private void TakeHotkeys(RubyValue value)
    {
        if (value.IsNil)
        {
            return;
        }

        var hotkeys = new Dictionary<string, (int, string?)>();
        foreach ((RubyValue name, RubyValue entry) in value.AsHash())
        {
            RubyArray pair = entry.AsArray();
            int code = pair[0].AsInt();
            hotkeys[name.AsText()] = (code, pair.Count > 1 && !pair[1].IsNil ? pair[1].AsText() : null);
            _input.Watch(code);
        }

        _hotkeys = hotkeys;
    }

    /// <summary>
    /// Takes Tab, the game's L and R and Page Up and Page Down in a root of the UI layer: Page
    /// Up and Page Down page the focused list or box; the keyboard's other keys of L and R step the
    /// nearest window page; a gamepad's shoulders step the tabs nearest the focus, else that page
    /// unless the root keeps them for its tabs, else page the focused list.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void SplitShoulders(Node root, UiButtons buttons)
    {
        Node from = _focus ?? root;
        int pageKey = buttons.Repeated(UiButton.L) && _input.KeyDown(PageUpKey) ? -1 : buttons.Repeated(UiButton.R) && _input.KeyDown(PageDownKey) ? 1 : 0;
        if (pageKey != 0)
        {
            PageFocused(from, pageKey);
            return;
        }

        int pad = PadShoulder(buttons);
        if (pad == 0)
        {
            int keyboard = buttons.Triggered(UiButton.L) ? -1 : buttons.Triggered(UiButton.R) ? 1 : 0;
            if (keyboard != 0)
            {
                StepPage(from, keyboard, false);
            }

            return;
        }

        if (NearestTabs(from, StepsByPad) is { } tabs)
        {
            StepTabs(tabs, pad);
        }
        else if (!root.ShouldersStepTabsOnly && !StepPage(from, pad, true))
        {
            PageFocused(from, pad);
        }
    }

    /// <summary>
    /// Takes Tab or Shift+Tab in a root of the UI layer: from a numeric or number field, whose
    /// arrows step it, the focus walks on to the next part, or back to the one before; elsewhere the tabs nearest
    /// the focus step, wrapping, and without tabs in view Tab goes into the root's first text field
    /// and from there back to the part it left.
    /// </summary>
    /// <param name="root">The root.</param>
    private void TabRule(Node root)
    {
        Node? focus = _focus is { } held && Focus.RootOf(held) == root ? held : null;
        if (focus is { TypesNumber: true })
        {
            MoveFocus(Focus.Tab(root, focus, _input.KeyDown(ShiftKey)));
            return;
        }

        if (NearestTabs(focus ?? root, StepsByTab) is { } tabs)
        {
            StepTabs(tabs, _input.KeyDown(ShiftKey) ? -1 : 1);
            return;
        }

        if (focus is { Kind: NodeKind.TextField } && _tabLeft is { } left && _nodes.ContainsKey(left.Id) && Focus.RootOf(left) == root &&
            Focus.CanHold(left) && Focus.Enabled(left))
        {
            _tabLeft = null;
            MoveFocus(left);
            return;
        }

        if (Focus.Order(root).Find(node => node.Kind == NodeKind.TextField) is { } field && field != focus)
        {
            _tabLeft = focus;
            MoveFocus(field);
        }
    }

    /// <summary>
    /// Finds the tabs nearest a component that step by a key and show tabs to step to: the nearest it
    /// lies in, else the first in view in its root.
    /// </summary>
    /// <param name="from">The component.</param>
    /// <param name="steps">Whether a row of tabs steps by the key.</param>
    /// <returns>The tabs, null when none is in view.</returns>
    private static Node? NearestTabs(Node from, System.Func<Node, bool> steps)
    {
        for (Node? step = from; step is not null; step = step.Parent)
        {
            if (step.Kind == NodeKind.Tabs && steps(step) && Focus.HasTabsToStep(step) && Focus.Shown(step) && Focus.KeysReach(step) && Focus.Enabled(step))
            {
                return step;
            }
        }

        return Focus.SteppedTabs(Focus.RootOf(from), steps);
    }

    /// <summary>
    /// Tells the nearest part from a component upward that takes the window's page step, the first
    /// handler that takes it winning.
    /// </summary>
    /// <param name="from">The component.</param>
    /// <param name="step">-1 for the page before, 1 for the next.</param>
    /// <param name="pad">Whether a gamepad's shoulder pressed it.</param>
    /// <returns>Whether a part took it.</returns>
    private bool StepPage(Node from, int step, bool pad)
    {
        for (Node? part = from; part is not null; part = part.Parent)
        {
            if (part.Pages && Focus.Shown(part))
            {
                _events.Add(new RubyArray { part.Id, "page", step, pad });
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Pages the list or the box that scrolls nearest a component, from it upward: a list moves its
    /// cursor a page, or the row it carries; a box scrolls a page; a list whose paging scrolls the
    /// box beside it scrolls that box.
    /// </summary>
    /// <param name="from">The component.</param>
    /// <param name="step">-1 for a page up, 1 for a page down.</param>
    private void PageFocused(Node from, int step)
    {
        Node? box = from;
        while (box is not null && box.Kind != NodeKind.List && !box.Scroll)
        {
            box = box.Parent;
        }

        if (box is null || !Focus.Enabled(box))
        {
            return;
        }

        if (box.Kind != NodeKind.List)
        {
            Page(box, step);
            return;
        }

        if (box.PagesBeside && box.Parent?.Children.FirstOrDefault(other => other != box && other.Scroll && Focus.Shown(other)) is { } beside)
        {
            Page(beside, step);
            return;
        }

        if (box.Moving)
        {
            StepCarried(box, step * System.Math.Max(box.ScrollShown, 1) * box.RowCells);
            return;
        }

        PageList(box, step);
    }

    /// <summary>
    /// Pages a list: its cursor moves a page, or a list that shows a page of its rows at a time
    /// hands the step to its script as page_step, which turns its page.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for a page up, 1 for a page down.</param>
    private void PageList(Node list, int step)
    {
        if (list.OwnPages)
        {
            _events.Add(new RubyArray { list.Id, "page_step", step });
            return;
        }

        Scroll.To(list, list.ScrollTop + step * System.Math.Max(list.ScrollShown, 1));
        StepCursor(list, step * System.Math.Max(list.ScrollShown, 1) * list.RowCells);
    }

    /// <summary>
    /// Tells the nearest part from the focus upward that takes one of the game's extra buttons that
    /// went down, in a root of the UI layer, and marks the button's keys taken; a button held
    /// since before its root opened acts only once pressed again.
    /// </summary>
    private void PressExtraButtons()
    {
        UiExtraButtons extra = _host.ExtraButtons;
        int held = extra.Bits >> (2 * UiExtraButtons.Count);
        foreach (Node open in _roots)
        {
            open.HeldExtraAtOpen &= held;
        }

        foreach (UiExtraButton button in ExtraButtonOrder)
        {
            if (!extra.Triggered(button) || ExtraButtonTaker(button) is not { } part || (Focus.RootOf(part).HeldExtraAtOpen & (1 << (int)button)) != 0)
            {
                continue;
            }

            Event(part.Id, "button", button.ToString());
            foreach (int code in Keys().Binding.KeysOf(button.ToString()))
            {
                _taken.Add(code);
            }
        }
    }

    /// <summary>
    /// Finds the nearest part from the focus upward that takes one of the game's extra buttons, in a
    /// root of the UI layer, shown and taking input.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>The part, null for none.</returns>
    private Node? ExtraButtonTaker(UiExtraButton button)
    {
        Node? from = _focus ?? Unblocked().Find(root => root.Layer && root.Captures);
        if (from is null || !Focus.RootOf(from).Layer)
        {
            return null;
        }

        for (Node? part = from; part is not null; part = part.Parent)
        {
            if (part.ExtraButtons.Contains(button) && Focus.Shown(part) && Focus.Enabled(part))
            {
                return part;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells why a screen uses the game's extra button a hotkey's key is bound to in F1, so the
    /// button wins over the hotkey: a part takes it with on_button, or the game's own screen asked
    /// about it in the frame before.
    /// </summary>
    /// <param name="code">Windows' code of the hotkey's key.</param>
    /// <returns>Why, null while no screen uses a button of the key.</returns>
    private string? GameButtonClash(int code)
    {
        var binding = Keys().Binding;
        foreach (UiExtraButton button in ExtraButtonOrder)
        {
            if (!binding.KeysOf(button.ToString()).Contains(code))
            {
                continue;
            }

            if (ExtraButtonTaker(button) is not null)
            {
                return $"the window in front takes the game's {button} button";
            }

            if (_host.ExtraButtons.Asked(button))
            {
                return $"the game's screen uses the game's {button} button";
            }
        }

        return null;
    }

    /// <summary>
    /// Finds the part a list's submit goes to: the list itself unless it does not take it, else the
    /// nearest part around it that does, shown and taking input; the list when none does.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The part.</returns>
    private static Node SubmitTaker(Node list)
    {
        if (list.TakesSubmit != false)
        {
            return list;
        }

        for (Node? part = list.Parent; part is not null; part = part.Parent)
        {
            if (part.TakesSubmit == true && Focus.Shown(part) && Focus.Enabled(part))
            {
                return part;
            }
        }

        return list;
    }

    /// <summary>
    /// Tells whether the jump keys are held: the framework's jump hotkey (Ctrl until the player binds
    /// another) on the keyboard, or the game's A button on a gamepad.
    /// </summary>
    /// <param name="root">The root the focus lies in.</param>
    /// <returns>Whether one is.</returns>
    private bool JumpHeld(Node root) =>
        _input.KeyDown(_hotkeys.TryGetValue(JumpHotkey, out (int Code, string? OffScene) jump) ? jump.Code : CtrlKey) || PadJumpHeld(root);

    /// <summary>
    /// Tells whether a gamepad holds the game's A button as the jump key.
    /// </summary>
    /// <remarks>
    /// The keyboard's keys of A are left out because Shift is also the game's dash and part of its
    /// message skip, and an A held since the root opened is left out until it is pressed again.
    /// </remarks>
    /// <param name="root">The root the focus lies in.</param>
    /// <returns>Whether it does.</returns>
    private bool PadJumpHeld(Node root) =>
        _host.ExtraButtons.Pressed(UiExtraButton.A) && (root.HeldExtraAtOpen & (1 << (int)UiExtraButton.A)) == 0 &&
        !_input.FromKeyboard(UiExtraButton.A);

    /// <summary>
    /// Moves the focus by an arrow with the jump keys held out of the focused part, as if a list did
    /// not wrap and a row did not use LEFT and RIGHT itself: UP and DOWN to the part above or below,
    /// LEFT and RIGHT along the row.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="vertical">-1 for UP, 1 for DOWN, 0 for neither.</param>
    /// <param name="horizontal">-1 for LEFT, 1 for RIGHT, 0 for neither.</param>
    private void Jump(Node focus, int vertical, int horizontal)
    {
        if (vertical != 0)
        {
            MoveFocusOrLeave(focus, Focus.Across(focus, vertical, jumping: true), vertical < 0 ? "up" : "down");
        }
        else
        {
            MoveAlong(focus, horizontal, jumping: true);
        }
    }

    /// <summary>
    /// Tells whether a list wraps by the rule of the UI layer: in such a root, while the scripts
    /// set neither whether it goes round nor that it hands the focus on at its ends.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Whether it does.</returns>
    private static bool LayerWraps(Node list) => list.Round is null && !list.LeaveEnds && Focus.RootOf(list).Layer;

    /// <summary>
    /// Wraps a list's cursor past its first or last line to the other end, in the same column of a
    /// list of several rows a line, as the game's lists do on a fresh press.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for UP on the first line, 1 for DOWN on the last.</param>
    private void WrapLine(Node list, int step)
    {
        int column = System.Math.Max(list.Cursor, 0) % list.RowCells;
        int target = step > 0 ? column : System.Math.Min(((list.RowLines - 1) * list.RowCells) + column, list.Rows - 1);
        if ((Scroll.StopFrom(list, target, step * list.RowCells) ?? Scroll.StopFrom(list, target, step)) is int row)
        {
            MoveCursor(list, row, true);
        }
    }

    /// <summary>
    /// Wraps the cursor of a list of several rows a line past its first or last row to the other end.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for LEFT on the first row, 1 for RIGHT on the last.</param>
    private void WrapCell(Node list, int step)
    {
        if (Scroll.StopFrom(list, step > 0 ? 0 : list.Rows - 1, step) is int row)
        {
            MoveCursor(list, row, true);
        }
    }

    /// <summary>
    /// Notes the way the focus goes in a root of the UI layer: each page it enters keeps the
    /// component it came from, unless it walks back the way it came, which forgets the way into the
    /// pages it leaves.
    /// </summary>
    /// <param name="from">The component that held the focus, null for none.</param>
    /// <param name="to">The component that gets it.</param>
    private static void NoteWayIn(Node? from, Node to)
    {
        Node root = Focus.RootOf(to);
        if (from is null || !root.Layer || Focus.RootOf(from) != root || !Focus.CanHold(from) || !Focus.Enabled(from))
        {
            return;
        }

        List<Node> left = PagesAround(from).FindAll(page => !Inside(to, page));
        List<Node> entered = PagesAround(to).FindAll(page => !Inside(from, page));
        bool back = left.Exists(page => page.CameFrom is { } came && entered.TrueForAll(each => Inside(came, each)));
        if (back)
        {
            left.ForEach(page => page.CameFrom = null);
        }
        else
        {
            entered.ForEach(page => page.CameFrom = from);
        }
    }

    /// <summary>
    /// Notes the component the focus comes from as it moves to another one beside it in a root of
    /// the UI layer, by an arrow, a click or the scripts, unless it walks back the way it came,
    /// which forgets that way.
    /// </summary>
    /// <remarks>
    /// Every component keeps it, not only lists, so a player who steps from a list to a button and
    /// back is not sent to the button by cancel.
    /// </remarks>
    /// <param name="from">The component that held the focus, null for none.</param>
    /// <param name="to">The component that gets it.</param>
    /// <param name="cancelled">Whether cancel moves it, which forgets the way but notes none.</param>
    private static void NoteHandOver(Node? from, Node to, bool cancelled)
    {
        Node root = Focus.RootOf(to);
        if (from is null || !root.Layer || Focus.RootOf(from) != root || Inside(from, to) || Inside(to, from) || !Focus.CanHold(from) ||
            !Focus.Enabled(from))
        {
            return;
        }

        if (from.HandedFrom == to)
        {
            from.HandedFrom = null;
        }
        else if (!cancelled)
        {
            to.HandedFrom = from;
        }
    }

    /// <summary>
    /// Finds where cancel walks the focus back to from a list of a root of the UI layer: the
    /// component the focus came from into it, while that is still there and lies outside the
    /// focused one.
    /// </summary>
    /// <param name="list">The component, a list or not.</param>
    /// <param name="focus">The focused component.</param>
    /// <returns>The component, null for none.</returns>
    private Node? HandedBack(Node list, Node focus) =>
        list.Kind == NodeKind.List && list.HandedFrom is { } giver && _nodes.ContainsKey(giver.Id) && !Inside(focus, giver) ? giver : null;

    /// <summary>
    /// Lists the pages a component lies in, nearest first: the pages of tabs and of slides.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The pages.</returns>
    private static List<Node> PagesAround(Node node)
    {
        var pages = new List<Node>();
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step.TabPage || step.Parent is { Kind: NodeKind.Slides })
            {
                pages.Add(step);
            }
        }

        return pages;
    }

    /// <summary>
    /// Finds where cancel walks the focus back to from a page of a root of the UI layer: the
    /// component the focus came from into it, while that lies outside it and may take the focus.
    /// </summary>
    /// <param name="page">The component, a page or not.</param>
    /// <returns>The component, null for none.</returns>
    private Node? WayBack(Node page) =>
        (page.TabPage || page.Parent is { Kind: NodeKind.Slides }) && Focus.RootOf(page).Layer && page.CameFrom is { } came && _nodes.ContainsKey(came.Id) &&
        !Inside(came, page) ? came : null;

    /// <summary>
    /// Stops the typing of a text field of a root of the UI layer on its first cancel, the focus
    /// staying on it: one typed into only once confirmed puts its text back, any other rests until
    /// confirm or a click wakes it, and the next cancel goes on down the chain.
    /// </summary>
    /// <param name="field">The text field.</param>
    private void StopTyping(Node field)
    {
        if (field.ConfirmToType)
        {
            Event(field.Id, "revert");
        }
        else
        {
            field.Rest();
            Event(field.Id, "rest");
        }

        Cue(UiCue.Cancel);
    }

    /// <summary>
    /// Presses the parts whose declared hotkey went down: a root closes, any other part is clicked.
    /// Of the parts of one hotkey the first in the topmost root that is not quiet takes it; when every
    /// one is quiet, the first one's reason is told, a clash with a game button marked as told once.
    /// Every hotkey whose key a screen uses as a game button is told as a clash too, for the hotkeys
    /// the scripts fire.
    /// </summary>
    private void FollowHotkeys()
    {
        foreach ((string name, (int code, string? offScene)) in _hotkeys)
        {
            if (!_input.WentDown(code))
            {
                continue;
            }

            string? clash = GameButtonClash(code);
            if (clash is not null)
            {
                _clashes[name] = clash;
            }

            if (name is MoveUpHotkey or MoveDownHotkey && MoveRowByHotkey(name, name == MoveUpHotkey ? -1 : 1, code, offScene ?? clash))
            {
                continue;
            }

            string? why = null;
            Node? taker = null;
            foreach (Node part in TopFirst().SelectMany(root => Declaring(root, name)))
            {
                string? quiet = QuietReason(part, code, offScene) ?? clash;
                if (quiet is null)
                {
                    taker = part;
                    break;
                }

                why ??= quiet;
            }

            if (taker is not null)
            {
                PressHotkey(taker);
                _taken.Add(code);
            }
            else if (!string.IsNullOrEmpty(why))
            {
                _quiet.Add(new RubyArray { name, why, why == clash });
            }
        }
    }

    /// <summary>
    /// Moves the cursor's row of the focused list one place up or down within its group by the
    /// framework's move hotkeys, in a root of the UI layer whose list takes them and carries no
    /// row: the row and the cursor go together, with the cursor sound; a heading, a disabled row and
    /// a row at its group's end stay, with the buzzer.
    /// </summary>
    /// <remarks>Only the framework's mod list takes them; other lists move their rows by a drag.</remarks>
    /// <param name="name">The hotkey's name.</param>
    /// <param name="step">-1 for up, 1 for down.</param>
    /// <param name="code">Windows' code of the hotkey's key.</param>
    /// <param name="offScene">Why the hotkey is off its scenes or a screen uses its key, null while neither.</param>
    /// <returns>Whether the focused list took the hotkey.</returns>
    private bool MoveRowByHotkey(string name, int step, int code, string? offScene)
    {
        if (_focus is not { Kind: NodeKind.List, Reorder: true, MoveHotkeys: true, Moving: false } list || !Focus.RootOf(list).Layer)
        {
            return false;
        }

        string? quiet = QuietReason(list, code, offScene);
        if (quiet is not null)
        {
            if (quiet.Length > 0)
            {
                _quiet.Add(new RubyArray { name, quiet, false });
            }

            return true;
        }

        _taken.Add(code);
        int from = list.Cursor;
        int to = from + step;
        if (MoveRefusal(list, from, to) is { } why)
        {
            Cue(UiCue.Buzzer);
            _events.Add(new RubyArray { list.Id, "move_refused", name, why });
            return true;
        }

        list.Cursor = to;
        Scroll.ShowCursor(list);
        _events.Add(new RubyArray { list.Id, "reorder", from, to });
        Cue(UiCue.Cursor);
        return true;
    }

    /// <summary>
    /// Tells why a move hotkey moves no row of a list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="from">The cursor's row.</param>
    /// <param name="to">The place the row would move to.</param>
    /// <returns>Why, for the log; null when the row moves.</returns>
    private static string? MoveRefusal(Node list, int from, int to)
    {
        if (!Focus.Enabled(list))
        {
            return "the list is turned off";
        }

        if (from < 0 || from >= list.Rows)
        {
            return "the cursor is on no row";
        }

        if (list.HeadingRows.Contains(from))
        {
            return "the cursor's row is a heading";
        }

        if (list.DisabledRows.Contains(from))
        {
            return "the cursor's row is turned off";
        }

        return to < 0 || to >= list.Rows || list.HeadingRows.Contains(to) || !SameGroup(list, from, to) ? "the row is at the end of its group" : null;
    }

    /// <summary>
    /// Tells whether two rows of a list lie in one group, which every row does while the list names
    /// no groups.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="one">One row.</param>
    /// <param name="other">The other row.</param>
    /// <returns>Whether they do.</returns>
    private static bool SameGroup(Node list, int one, int other) =>
        list.RowGroups.Count <= System.Math.Max(one, other) || list.RowGroups[one] == list.RowGroups[other];

    /// <summary>
    /// Lists the parts of a root that declare a hotkey, in tree order.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="name">The hotkey's name.</param>
    /// <returns>The parts.</returns>
    private static IEnumerable<Node> Declaring(Node root, string name)
    {
        if (root.Hotkey == name)
        {
            yield return root;
        }

        foreach (Node child in root.Children)
        {
            foreach (Node part in Declaring(child, name))
            {
                yield return part;
            }
        }
    }

    /// <summary>
    /// Tells why a part's hotkey does nothing now, but for a clash with a game button.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <param name="code">Windows' code of the hotkey's key.</param>
    /// <param name="offScene">Why the hotkey is off its scenes, null while it is on them.</param>
    /// <returns>Why, <see cref="SilentlyQuiet"/> for a reason not logged, null when it acts.</returns>
    private string? QuietReason(Node part, int code, string? offScene)
    {
        Node root = Focus.RootOf(part);
        if (_focus is { TypesNow: true })
        {
            return SilentlyQuiet;
        }

        if (KeyNames.IsFrameworkKey(code, _input.Assignment))
        {
            return "its key is one of the framework's own keys";
        }

        if (offScene is not null)
        {
            return offScene;
        }

        if (!Focus.Shown(part))
        {
            return "its part is hidden";
        }

        if (Fresh(root))
        {
            return SilentlyQuiet;
        }

        return root.HeldUnder ? "a window above holds the game's buttons" : null;
    }


    /// <summary>
    /// Presses a part by its hotkey: a root closes with the reason hotkey, a part that takes no input
    /// buzzes, any other is clicked.
    /// </summary>
    /// <param name="part">The part.</param>
    private void PressHotkey(Node part)
    {
        if (part.IsRoot)
        {
            Close(part, "hotkey");
        }
        else if (!Focus.Enabled(part))
        {
            Cue(UiCue.Buzzer);
        }
        else
        {
            Click(part);
        }
    }

    /// <summary>
    /// Follows the game's buttons and the keys: inside a focused text field from the keys, else from
    /// the game's buttons, Tab and the numpad's 0.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void FollowKeys(UiButtons buttons)
    {
        var keys = Keys();
        bool cancelKey = keys.Cancel.Any(_input.WentDown);
        bool confirmKey = keys.Confirm.Any(_input.WentDown);
        bool lateCancel = _cancelKeyFirst && !cancelKey && buttons.Triggered(UiButton.Cancel);
        bool lateConfirm = _confirmKeyFirst && !confirmKey && buttons.Triggered(UiButton.Confirm);

        // The game reads its buttons a moment before the keys are read, so a key that goes down in
        // between reaches the game's buttons a tick late; when the tree took that key, the late
        // button is the same press.
        int late = (lateCancel ? 1 << (int)UiButton.Cancel : 0) | (lateConfirm ? 1 << (int)UiButton.Confirm : 0);
        _late |= late;
        Node? target = _focus is { } held ? Focus.RootOf(held) : Unblocked().Find(root => root.Closable);
        if (target is not null && Fresh(target))
        {
            _cancelKeyFirst = _confirmKeyFirst = false;
            return;
        }

        var mine = new UiButtons(buttons.Bits & ~late & ~HeldSinceOpen(buttons));
        bool tookCancelKey;
        if (_focus is { TypesNow: true } field)
        {
            FieldKeys(field, mine);
            tookCancelKey = cancelKey;
            _confirmKeyFirst = confirmKey && !buttons.Triggered(UiButton.Confirm);
        }
        else
        {
            tookCancelKey = PlainKeys(mine);
            _confirmKeyFirst = false;
            PressExtraButtons();
        }

        _cancelKeyFirst = tookCancelKey && !buttons.Triggered(UiButton.Cancel);
    }

    /// <summary>
    /// Follows the keys in a focused text field: its claimed keys are told, Escape, the numpad's 0
    /// (with Num Lock off only in a field that takes only digits) and a key bound to cancel in F1 that
    /// types nothing cancel (in a root of the UI layer the first one only stops the typing), a key
    /// bound to confirm that types nothing into it acts as Enter, Tab
    /// steps the root's tabs that Tab steps, else moves the focus in a window
    /// or dialog, UP and DOWN, of the keyboard or a gamepad, step what a numeric field types unless the
    /// jump keys are held and leave any other field of one line; the game's
    /// cancel and confirm count only from a gamepad, as the input model tells it, so a letter
    /// bound to cancel types its letter. A gamepad's L
    /// and R step the root's tabs that the pad's shoulders step, and its UP and DOWN reach a field
    /// that claims the arrow keys as those keys, so they scroll what it steers or pick a completion.
    /// </summary>
    /// <param name="field">The text field.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void FieldKeys(Node field, UiButtons buttons)
    {
        var claimed = new HashSet<int>();
        bool alt = _input.KeyDown(LayoutModel.AltKey);
        foreach (int code in field.Keys)
        {
            int key = code & ~Node.AltFlag;
            if (_input.WentDown(key) && alt == ((code & Node.AltFlag) != 0) && claimed.Add(key))
            {
                Event(field.Id, "key", code);
                _taken.Add(key);
            }
        }

        bool Went(int code) => !claimed.Contains(code) && _input.WentDown(code);
        var keys = Keys();
        bool padCancel = _input.PadPressed(buttons, UiButton.Cancel);
        int? by = new[] { EscapeKey, InsertKey }.Concat(keys.CancelBound).Append(NumpadZero).FirstOrDefault(candidate => Went(candidate) && LeavesField(field, candidate)) is int found and not 0 ? found : null;
        if ((by is not null || padCancel) && field.ConfirmToType)
        {
            Event(field.Id, "revert");
            Cue(UiCue.Cancel);
            if (by is int typed)
            {
                _edit?.Drop(typed);
            }

            return;
        }

        if (by is not null || padCancel)
        {
            if (field.TellsCancelled)
            {
                Event(field.Id, "cancelled");
            }

            if (Focus.RootOf(field).Layer)
            {
                StopTyping(field);
            }
            else
            {
                Cancel();
            }

            if (by is int key)
            {
                _edit?.Drop(key);
            }

            return;
        }

        if (keys.Confirm.FirstOrDefault(code => Went(code) && LeavesField(field, code)) is int confirmBy and not 0)
        {
            Event(field.Id, "enter");
            _edit?.Drop(confirmBy);
            return;
        }

        if (_input.PadPressed(buttons, UiButton.Confirm))
        {
            Event(field.Id, "submit");
        }

        Node root = Focus.RootOf(field);
        if (PadShoulder(buttons) is int shoulder and not 0)
        {
            if ((root.Layer ? NearestTabs(field, StepsByPad) : Focus.SteppedTabs(root, StepsByPad)) is { } padTabs)
            {
                StepTabs(padTabs, shoulder);
            }
            else if (root is { Layer: true, ShouldersStepTabsOnly: false })
            {
                StepPage(field, shoulder, true);
            }
        }

        int pad = PadVertical(buttons);
        int padKey = pad < 0 ? UpKey : DownKey;
        if (Went(TabKey) && root is { Layer: true, TakesTab: true })
        {
            TabRule(root);
            _taken.Add(TabKey);
        }
        else if (Went(TabKey) && root.TakesTab)
        {
            if (Focus.SteppedTabs(root, StepsByTab) is { } tabs)
            {
                StepTabs(tabs, _input.KeyDown(ShiftKey) ? -1 : 1);
            }
            else
            {
                MoveTab(root);
            }

            _taken.Add(TabKey);
        }
        else if (field.TypesNumber && (Went(UpKey) || Went(DownKey) || pad != 0) && !(root.Layer && JumpHeld(root)))
        {
            StepTyped(field, Went(UpKey) || (!Went(DownKey) && pad < 0) ? 1 : -1);
        }
        else if (field.Rows <= 1 && (Went(UpKey) || Went(DownKey)))
        {
            MoveFocus(Focus.Across(field, Went(UpKey) ? -1 : 1));
        }
        else if (field.Rows <= 1 && field.LeaveSides && CaretSide(field, buttons) is int side and not 0)
        {
            MoveAlong(field, side);
        }
        else if (pad != 0 && field.Keys.Contains(padKey))
        {
            Event(field.Id, "key", padKey);
        }
        else if (field.Rows <= 1 && pad != 0)
        {
            MoveFocus(Focus.Across(field, pad));
        }
    }

    /// <summary>
    /// Reads the keys of the game's buttons as the player bound them in F1, once per reading of the
    /// settings, and watches them: confirm's, cancel's with the numpad's 0 either way, the shoulder
    /// buttons', and cancel's alone.
    /// </summary>
    /// <returns>The keys.</returns>
    private (ButtonAssignment Binding, int[] Confirm, int[] Cancel, int[] Shoulder, int[] CancelBound) Keys()
    {
        ButtonAssignment binding = _input.Assignment;
        if (_keys is { } kept && ReferenceEquals(kept.Binding, binding))
        {
            return kept;
        }

        int[] bound = [.. binding.KeysOf("B")];
        int[] cancel = [.. bound.Concat([NumpadZero, InsertKey]).Distinct()];
        int[] shoulder = [.. binding.KeysOf("L").Concat(binding.KeysOf("R")).Distinct()];
        int[] confirm = [.. binding.KeysOf("C")];
        foreach (int code in confirm.Concat(cancel).Concat(shoulder))
        {
            _input.Watch(code);
        }

        _keys = (binding, confirm, cancel, shoulder, bound);
        return _keys.Value;
    }

    /// <summary>
    /// Tells whether a cancel key leaves a focused text field, see <see cref="KeyNames.LeavesField"/>.
    /// </summary>
    /// <param name="field">The text field.</param>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>Whether it leaves the field.</returns>
    private static bool LeavesField(Node field, int code) => KeyNames.LeavesField(field.Takes, code);

    /// <summary>
    /// Tells the game's buttons the root that takes the keys holds since before it opened: they act on
    /// it only once let go and pressed again. Each root lets go of the buttons no longer held.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>The bits of those buttons in each of the three groups.</returns>
    private int HeldSinceOpen(UiButtons buttons)
    {
        int held = buttons.Bits >> (2 * UiButtons.Count);
        foreach (Node root in _roots)
        {
            root.HeldAtOpen &= held;
        }

        Node? target = _focus is { } focus ? Focus.RootOf(focus) : Unblocked().FirstOrDefault();
        int mask = target?.HeldAtOpen ?? 0;
        return mask | (mask << UiButtons.Count) | (mask << (2 * UiButtons.Count));
    }

    /// <summary>
    /// Tells which way LEFT or RIGHT leaves a text field of one line: LEFT that went down with its
    /// caret at the start of its text, RIGHT at its end, each unless the numpad's digit of it typed.
    /// </summary>
    /// <param name="field">The text field.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>-1 for LEFT, 1 for RIGHT, 0 for neither.</returns>
    private int CaretSide(Node field, UiButtons buttons) =>
        CaretLeaves(field.CaretEnds.Start, buttons, UiButton.Left) ? -1 : CaretLeaves(field.CaretEnds.End, buttons, UiButton.Right) ? 1 : 0;

    /// <summary>
    /// Tells whether LEFT or RIGHT leaves a text field at the end of its caret's way.
    /// </summary>
    /// <param name="atEnd">Whether the caret stands at the side the direction goes to.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="direction">LEFT or RIGHT.</param>
    /// <returns>Whether it went down and is no numpad digit typed.</returns>
    private bool CaretLeaves(bool atEnd, UiButtons buttons, UiButton direction) =>
        atEnd && buttons.Triggered(direction) && !_input.NumpadTyped(direction);

    /// <summary>
    /// Finds the text field that steers a list, where UP on its first line goes, while it can take the focus.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The field, null for none.</returns>
    private Node? SteeringField(Node list) =>
        list.UpTo is int id && _nodes.TryGetValue(id, out Node? field) && Focus.CanHold(field) && Focus.Enabled(field) ? field : null;

    /// <summary>
    /// Tells whether a component lies beside another in a step's way: wholly past its edge and level
    /// with some of its height; one not laid out yet counts as lying there.
    /// </summary>
    /// <param name="from">The component the focus leaves.</param>
    /// <param name="to">The component it may go to.</param>
    /// <param name="step">-1 for the left, 1 for the right.</param>
    /// <returns>Whether it lies there.</returns>
    private static bool Beside(Node from, Node to, int step)
    {
        if (from.Rect is not { } a || to.Rect is not { } b)
        {
            return true;
        }

        bool past = step > 0 ? b.X >= a.X + a.Width : b.X + b.Width <= a.X;
        return past && b.Y < a.Y + a.Height && b.Y + b.Height > a.Y;
    }

    /// <summary>
    /// Tells whether a list's cursor stands at the side of its line a step leaves by: no row that
    /// takes the cursor lies that way on its line.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <returns>Whether it does; a list of one row a line is always at its sides.</returns>
    private static bool AtSide(Node list, int step) =>
        list.Cursor < 0 || Scroll.StopFrom(list, list.Cursor + step, step) is not int next || next / list.RowCells != list.Cursor / list.RowCells;

    /// <summary>
    /// Tells which way a gamepad's UP or DOWN goes: the game's buttons while neither comes from the
    /// keyboard, since a field reads the arrow keys itself and a numpad digit types.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>-1 for UP, 1 for DOWN, 0 for neither.</returns>
    private int PadVertical(UiButtons buttons)
    {
        if (_input.FromKeyboard(UiButton.Up) || _input.FromKeyboard(UiButton.Down))
        {
            return 0;
        }

        return buttons.Repeated(UiButton.Up) ? -1 : buttons.Repeated(UiButton.Down) ? 1 : 0;
    }

    /// <summary>
    /// Follows the game's buttons outside a text field: cancel, confirm and the menu key, Tab, the
    /// shoulder buttons and the arrows, each group as its own method tells.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>Whether the numpad's 0 cancelled something, a key the game reads as its cancel too.</returns>
    private bool PlainKeys(UiButtons buttons)
    {
        if (CancelKeys(buttons) is { } cancelled)
        {
            return cancelled;
        }

        ConfirmKeys(buttons);

        // A list that carries a row keeps the focus and its page until the row is dropped.
        bool carrying = _focus is { Moving: true };
        Node? keysRoot = _focus is { } held ? Focus.RootOf(held) : Unblocked().Find(root => root.TakesTab);
        bool split = keysRoot is { Layer: true, TakesTab: true };

        // A root joined to a game window shares one cursor with its commands, so L, R, Page Up and
        // Page Down do nothing in it, as on the title's commands.
        bool shoulders = keysRoot is not { Joined: true };
        TabKeys(keysRoot, split, carrying);
        if (ShoulderKeys(buttons, keysRoot, split, shoulders, carrying) || _focus is not { } focus)
        {
            return false;
        }

        ArrowKeys(focus, buttons, split, shoulders, carrying);
        return false;
    }

    /// <summary>
    /// Takes cancel or the numpad's 0, which cancel.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>Null when neither went down, else whether the numpad's 0 cancelled something.</returns>
    private bool? CancelKeys(UiButtons buttons)
    {
        bool numpadZero = _input.WentDown(NumpadZero) || _input.WentDown(InsertKey);
        if (buttons.Triggered(UiButton.Cancel) || numpadZero)
        {
            _heldConfirm = null;
            _padCancel = !numpadZero && _input.PadPressed(buttons, UiButton.Cancel);
            bool cancelled = Cancel();
            _padCancel = false;
            return cancelled && numpadZero;
        }

        return null;
    }

    /// <summary>
    /// Takes confirm, which clicks the focused component or submits a list's row, and the menu key,
    /// which opens the context menu of the focused part.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void ConfirmKeys(UiButtons buttons)
    {
        if (!HoldsConfirm(buttons) && buttons.Triggered(UiButton.Confirm) && _focus is { } confirmed)
        {
            Confirm(confirmed);
        }

        if (_input.WentDown(MenuKey) && _focus is { } menuFocus && Focus.RootOf(menuFocus).Layer && ContextPart(menuFocus) is { } withMenu)
        {
            OpenContext(withMenu, menuFocus);
            _taken.Add(MenuKey);
        }
    }

    /// <summary>
    /// Takes Tab: the Tab rule in a root of the UI layer, else it steps the tabs Tab steps or moves
    /// the focus in a window or dialog.
    /// </summary>
    /// <param name="keysRoot">The root the keys go to; null for none.</param>
    /// <param name="split">Whether the root follows the key rules of the UI layer.</param>
    /// <param name="carrying">Whether the focused list carries a row.</param>
    private void TabKeys(Node? keysRoot, bool split, bool carrying)
    {
        if (split && !carrying && _input.WentDown(TabKey) && keysRoot!.TakesTab)
        {
            TabRule(keysRoot);
            _taken.Add(TabKey);
        }
        else if (!split && !carrying && _input.WentDown(TabKey) && keysRoot is { TakesTab: true } root)
        {
            if (Focus.SteppedTabs(root, StepsByTab) is { } tabs)
            {
                StepTabs(tabs, _input.KeyDown(ShiftKey) ? -1 : 1);
            }
            else
            {
                MoveTab(root);
            }

            _taken.Add(TabKey);
        }
    }

    /// <summary>
    /// Takes the game's L and R and Page Up and Page Down: split by device in a root of the UI layer,
    /// else a gamepad's shoulder buttons step the tabs they step.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="keysRoot">The root the keys go to; null for none.</param>
    /// <param name="split">Whether the root follows the key rules of the UI layer.</param>
    /// <param name="shoulders">Whether the root takes the shoulder buttons at all.</param>
    /// <param name="carrying">Whether the focused list carries a row.</param>
    /// <returns>Whether a gamepad's shoulder button stepped tabs, which ends the keys of the tick.</returns>
    private bool ShoulderKeys(UiButtons buttons, Node? keysRoot, bool split, bool shoulders, bool carrying)
    {
        if (split && shoulders && (!carrying || _input.KeyDown(PageUpKey) || _input.KeyDown(PageDownKey)))
        {
            SplitShoulders(keysRoot!, buttons);
        }

        if (_focus is { } focus && !split && shoulders && !carrying && PadShoulder(buttons) is int pad and not 0 && Focus.SteppedTabs(Focus.RootOf(focus), StepsByPad) is { } padTabs)
        {
            StepTabs(padTabs, pad);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Takes the arrows and the game's L and R left to the focused component: they move a list's
    /// cursor, step a numeric field, a slider or a select or move the focus, also away from a focused component
    /// that takes no input now. In a root of the UI layer an arrow with the jump key held moves the
    /// focus out.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="split">Whether the root follows the key rules of the UI layer.</param>
    /// <param name="shoulders">Whether the root takes the shoulder buttons at all.</param>
    /// <param name="carrying">Whether the focused list carries a row.</param>
    private void ArrowKeys(Node focus, UiButtons buttons, bool split, bool shoulders, bool carrying)
    {
        bool enabled = Focus.Enabled(focus);
        int vertical = buttons.Repeated(UiButton.Up) ? -1 : buttons.Repeated(UiButton.Down) ? 1 : 0;
        int horizontal = buttons.Repeated(UiButton.Left) ? -1 : buttons.Repeated(UiButton.Right) ? 1 : 0;
        int page = split || !shoulders ? 0 : Shoulders(focus, buttons.Repeated(UiButton.L) ? -1 : buttons.Repeated(UiButton.R) ? 1 : 0);
        if (CarryArrows(vertical, horizontal))
        {
            return;
        }

        if ((vertical != 0 || horizontal != 0) && !carrying && Focus.RootOf(focus).Layer && JumpHeld(Focus.RootOf(focus)))
        {
            Jump(focus, vertical, horizontal);
            return;
        }

        switch (focus.Kind)
        {
            case var _ when focus.Steps && enabled && horizontal != 0:
                StepAlong(focus, horizontal);
                break;
            case NodeKind.List when enabled && carrying && (vertical != 0 || (page != 0 && focus.ShoulderPages)):
                StepCarried(focus, vertical != 0 ? vertical * focus.RowCells : page * Math.Max(focus.ScrollShown, 1) * focus.RowCells);
                break;
            case NodeKind.List when enabled:
                ListArrows(focus, buttons, vertical, horizontal, page, carrying);
                break;
            case NodeKind.NumericField when enabled && (horizontal != 0 || vertical != 0):
                StepNumeric(focus, horizontal != 0 ? horizontal : -vertical);
                break;
            case NodeKind.Slider when enabled && horizontal != 0:
                StepSlider(focus, horizontal);
                break;
            case NodeKind.Select when enabled && horizontal != 0:
                Event(focus.Id, "step", horizontal);
                Cue(UiCue.Cursor);
                break;
            default:
                OtherArrows(focus, buttons, vertical, horizontal, page);
                break;
        }
    }

    /// <summary>
    /// Takes the arrows and the shoulders in a focused list. LEFT and RIGHT, which a list does not
    /// use, move the focus out of it. A list of a root of the UI layer wraps on a fresh press at its
    /// end and stops for a held arrow, and a row there that uses LEFT and RIGHT keeps the focus at its
    /// ends.
    /// </summary>
    /// <param name="focus">The focused list.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="vertical">-1 up, 1 down, 0 neither.</param>
    /// <param name="horizontal">-1 left, 1 right, 0 neither.</param>
    /// <param name="page">-1 a page back, 1 a page on, 0 neither.</param>
    /// <param name="carrying">Whether the list carries a row.</param>
    private void ListArrows(Node focus, UiButtons buttons, int vertical, int horizontal, int page, bool carrying)
    {
        if (page != 0)
        {
            if (focus.ShoulderPages)
            {
                PageList(focus, page);
            }
            else if (!carrying)
            {
                PageUnused(focus, buttons);
            }
        }
        else if (vertical != 0 && !StepLine(focus, vertical) && !carrying && (focus.Round == true || focus.LeaveEnds || LayerWraps(focus)))
        {
            if (focus.Round == true)
            {
                StepCursor(focus, vertical < 0 ? focus.Rows : -focus.Rows);
            }
            else if (focus.LeaveEnds)
            {
                MoveFocus((vertical < 0 ? SteeringField(focus) : null) ?? Focus.Across(focus, vertical));
            }
            else if (buttons.Triggered(vertical < 0 ? UiButton.Up : UiButton.Down))
            {
                WrapLine(focus, vertical);
            }
        }
        else if (horizontal != 0 && !carrying && StepToggle(focus, horizontal))
        {
        }
        else if (horizontal != 0 && Focus.RootOf(focus).Layer && focus.Cursor >= 0 && focus.ToggleRows.ContainsKey(focus.Cursor))
        {
            // A row of toggles uses LEFT and RIGHT itself, so it keeps the focus at its ends.
        }
        else if (horizontal != 0 && focus.Sides && focus.ValueRows.Contains(focus.Cursor))
        {
            if (!carrying && focus.Cursor >= 0)
            {
                _events.Add(new RubyArray { focus.Id, "side", focus.Cursor, horizontal });
            }
        }
        else if (horizontal != 0 && focus.LeaveSides && !carrying && AtSide(focus, horizontal))
        {
            if (Focus.Along(focus, horizontal) is { } beside && Beside(focus, beside, horizontal))
            {
                MoveFocus(beside);
            }
            else if (Focus.SlidesOf(focus) is { } slides)
            {
                MoveIntoPage(slides, focus, horizontal);
            }
        }
        else if (horizontal != 0 && !StepCell(focus, horizontal) && !carrying)
        {
            if (focus.RowCells == 1 || !LayerWraps(focus))
            {
                MoveAlong(focus, horizontal);
            }
            else if (buttons.Triggered(horizontal < 0 ? UiButton.Left : UiButton.Right))
            {
                WrapCell(focus, horizontal);
            }
        }
    }

    /// <summary>
    /// Takes the arrows and the shoulders on a focused component that is no list, numeric field or
    /// select: they move the focus, scroll a box that scrolls or page it.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="vertical">-1 up, 1 down, 0 neither.</param>
    /// <param name="horizontal">-1 left, 1 right, 0 neither.</param>
    /// <param name="page">-1 a page back, 1 a page on, 0 neither.</param>
    private void OtherArrows(Node focus, UiButtons buttons, int vertical, int horizontal, int page)
    {
        if (WrapGrid(focus, buttons, vertical, horizontal))
        {
        }
        else if (horizontal != 0)
        {
            MoveAlong(focus, horizontal);
        }
        else if (focus.Scroll && page != 0)
        {
            Page(focus, page);
        }
        else if (page != 0)
        {
            PageUnused(focus, buttons);
        }
        else if (vertical != 0 && !(focus.Scroll && ScrollBy(focus, vertical * Node.DefaultRowHeight)) && !focus.KeepEnds)
        {
            Node? picked = Focus.Picked(focus) ? Focus.PickAcross(focus, vertical) : null;
            MoveFocusOrLeave(focus, picked ?? Focus.Across(focus, vertical), vertical < 0 ? "up" : "down");
        }
    }

    /// <summary>
    /// Takes an arrow that would leave a grid of boxes of a root of the UI layer at its edge: a fresh
    /// press wraps the focus to the other end, as a list does, and a held arrow stops there.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <param name="vertical">-1 up, 1 down, 0 neither.</param>
    /// <param name="horizontal">-1 left, 1 right, 0 neither.</param>
    /// <returns>Whether the arrow met such an edge.</returns>
    private bool WrapGrid(Node focus, UiButtons buttons, int vertical, int horizontal)
    {
        if ((vertical == 0 && horizontal == 0) || !Focus.RootOf(focus).Layer || Focus.GridWrap(focus, vertical, horizontal) is not { } target)
        {
            return false;
        }

        UiButton arrow = vertical < 0 ? UiButton.Up : vertical > 0 ? UiButton.Down : horizontal < 0 ? UiButton.Left : UiButton.Right;
        if (buttons.Triggered(arrow))
        {
            MoveFocus(target);
        }

        return true;
    }

    /// <summary>
    /// Hands the game's L or R that the focused component did not use to its root as page, once per
    /// press, with whether a gamepad pressed it, so a root can turn it into its own step, such as
    /// to the next character.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void PageUnused(Node focus, UiButtons buttons)
    {
        int step = buttons.Triggered(UiButton.L) ? -1 : buttons.Triggered(UiButton.R) ? 1 : 0;
        if (step != 0)
        {
            _events.Add(new RubyArray { Focus.RootOf(focus).Id, "page", step, PadShoulder(buttons) != 0 });
        }
    }

    /// <summary>
    /// Takes the game's L and R: while the focused component's root has tabs that step by them, they
    /// step those and only Page Up and Page Down page.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="page">-1 for L, 1 for R, 0 for neither.</param>
    /// <returns>The pages to move a list or a box by: -1, 1 or 0.</returns>
    private int Shoulders(Node focus, int page)
    {
        if (page == 0 || Focus.SteppedTabs(Focus.RootOf(focus), tabs => tabs.Shoulder) is not { } tabs)
        {
            return page;
        }

        int keys = _input.WentDown(PageUpKey) ? -1 : _input.WentDown(PageDownKey) ? 1 : 0;
        if (keys != 0)
        {
            return keys;
        }

        StepTabs(tabs, page);
        return 0;
    }

    /// <summary>
    /// Tells which way a gamepad's shoulder button went down: the game's L or R as the input model
    /// tells it a gamepad's.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>-1 for L, 1 for R, 0 for neither.</returns>
    private int PadShoulder(UiButtons buttons)
    {
        int step = buttons.Triggered(UiButton.L) ? -1 : buttons.Triggered(UiButton.R) ? 1 : 0;
        return step != 0 && !_input.FromKeyboard(step < 0 ? UiButton.L : UiButton.R) ? step : 0;
    }

    /// <summary>
    /// Steps a row of tabs to the tab beside, round at either end, with the cursor sound.
    /// </summary>
    /// <param name="tabs">The tabs.</param>
    /// <param name="step">-1 for the one before, 1 for the one after.</param>
    private void StepTabs(Node tabs, int step)
    {
        Event(tabs.Id, "step", step);
        Cue(UiCue.Cursor);
    }

    /// <summary>
    /// Moves a focused key stop's cursor by LEFT or RIGHT to the place beside, never round, and shows
    /// its tooltip; past its first or last place the focus moves on along the row, but stays in a root
    /// of the UI layer, where the jump keys leave it.
    /// </summary>
    /// <param name="stop">The key stop.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    private void StepAlong(Node stop, int step)
    {
        int next = stop.Cursor + step;
        if (next < 0 || next >= stop.Rows)
        {
            if (!Focus.RootOf(stop).Layer)
            {
                MoveAlong(stop, step);
            }

            return;
        }

        stop.Cursor = next;
        Event(stop.Id, "move", next);
        Cue(UiCue.Cursor);
        ShowFocusTip(stop);
    }

    /// <summary>
    /// Moves the focus by LEFT or RIGHT: along its row; where that finds nothing inside a slides, to
    /// the page beside in view, else the slides is told to move a page.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <param name="jumping">Whether the jump key is held, which reaches the parts only it reaches.</param>
    private void MoveAlong(Node focus, int step, bool jumping = false)
    {
        if (Focus.Along(focus, step, jumping) is { } next)
        {
            MoveFocus(next);
        }
        else if (Focus.SlidesOf(focus) is { } slides)
        {
            MoveIntoPage(slides, focus, step);
        }
        else if (Focus.Along(focus, -step, jumping) is null && Focus.SteppedTabs(Focus.RootOf(focus), tabs => tabs.Arrows) is { } tabs)
        {
            StepTabs(tabs, step);
        }
        else
        {
            MoveFocusOrLeave(focus, null, step < 0 ? "left" : "right");
        }
    }

    /// <summary>
    /// Moves the focus out of a slides' page by LEFT or RIGHT: to the page beside in view, else the
    /// slides is told to move a page.
    /// </summary>
    /// <param name="slides">The slides.</param>
    /// <param name="focus">The focused component, inside one of its pages.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    private void MoveIntoPage(Node slides, Node focus, int step)
    {
        if (Focus.PageBeside(slides, focus, step) is { } beside)
        {
            MoveFocus(beside);
        }
        else
        {
            Event(slides.Id, "slide", step);
        }
    }

    /// <summary>
    /// Scrolls a box by pixels, as far as it goes.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="pixels">The pixels, negative up.</param>
    /// <returns>Whether it scrolled.</returns>
    private bool ScrollBy(Node box, int pixels)
    {
        bool moved = Scroll.To(box, box.ScrollTop + pixels);
        Scrolled(box, moved);
        return moved;
    }

    /// <summary>
    /// Takes cancel: a root of the UI layer above the focus that cancel closes closes first; a
    /// focused list that carries a row puts it back; else the focus goes where the focused component
    /// or one it lies in sends cancel, or a slides it lies in moves back a page; else the focused
    /// component's root closes when cancel closes it, else the focus leaves it; with no focus the
    /// topmost root taking input that cancel closes closes.
    /// </summary>
    /// <returns>Whether it put a row back, moved the focus or a slides, closed a root or took the focus off a component.</returns>
    private bool Cancel()
    {
        if (CancelDrag())
        {
            return true;
        }

        if (_focus is { } focus)
        {
            if (ClosableAbove(Focus.RootOf(focus)) is { } above)
            {
                Close(above);
                return true;
            }

            if (focus.Moving)
            {
                focus.Moving = false;
                Event(focus.Id, "uncarry");
                Cue(UiCue.Cancel);
                return true;
            }

            if (CancelStep(focus))
            {
                Cue(UiCue.Cancel);
                return true;
            }

            Node root = Focus.RootOf(focus);
            if (root.Closable)
            {
                Close(root);
                return true;
            }

            Blur(forget: true);
            Cue(UiCue.Cancel);
            Restore(root);
            return true;
        }

        if (Unblocked().Find(root => root.Closable) is { } closable)
        {
            Close(closable);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Finds the topmost root of the UI layer above a root that takes input and that cancel
    /// closes.
    /// </summary>
    /// <remarks>A popover of text alone takes no focus, so without this one cancel closed the window under it.</remarks>
    /// <param name="root">The root the focus lies in.</param>
    /// <returns>The root above, null for none.</returns>
    private Node? ClosableAbove(Node root)
    {
        foreach (Node open in Unblocked())
        {
            if (open == root)
            {
                return null;
            }

            if (open.Layer && open.Captures && open.Closable)
            {
                return open;
            }
        }

        return null;
    }

    /// <summary>
    /// Takes cancel inside a root: from the focused component out, the first that sends cancel to a
    /// component that may take the focus gives it the focus, a list of a root of the UI layer
    /// gives it back to the component it came from, a page of such a root gives it back to
    /// the component the focus came from, the first slides that cancel moves back
    /// is told to, and a box the keys entered takes it back. On the home of a root of the UI layer
    /// neither a way back nor a slides is followed, so cancel there goes on to the root.
    /// </summary>
    /// <remarks>
    /// The player returns home by any path, such as through the buttons beside it by the arrows,
    /// and expects cancel there to close the window rather than replay that path.
    /// </remarks>
    /// <param name="focus">The focused component.</param>
    /// <returns>Whether either happened.</returns>
    private bool CancelStep(Node focus)
    {
        Node root = Focus.RootOf(focus);
        bool home = root.Layer && root.Home == focus;
        for (Node? step = focus; step is not null; step = step.Parent)
        {
            if (step.CancelTo is int id && _nodes.TryGetValue(id, out Node? target) && !Inside(focus, target) && TryFocus(target, cancelled: true))
            {
                return true;
            }

            if (!home && step.CancelTo is null && HandedBack(step, focus) is { } giver && TryFocus(giver, cancelled: true))
            {
                step.HandedFrom = null;
                return true;
            }

            if (!home && step.CancelTo is null && WayBack(step) is { } back && TryFocus(back, cancelled: true))
            {
                return true;
            }

            if (!home && step.Kind == NodeKind.Slides && step.SlideBack)
            {
                Event(step.Id, "back");
                return true;
            }

            if (step != focus && step.Enter && TryFocus(step))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Moves a list's cursor by rows, within its rows, past a heading row onto the row beyond it.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="rows">The rows, negative up.</param>
    private void StepCursor(Node list, int rows)
    {
        if (list.Rows == 0 || rows == 0)
        {
            return;
        }

        int target = Math.Min(Math.Max(Math.Max(list.Cursor, 0) + rows, 0), list.Rows - 1);
        int toward = Math.Sign(rows);
        if ((Scroll.StopFrom(list, target, toward) ?? Scroll.StopFrom(list, target, -toward)) is int row)
        {
            MoveCursor(list, row, true);
        }
    }

    /// <summary>
    /// Moves the row a list carries by rows, kept among the rows of its group; at the group's first
    /// or last row it stays, with the buzzer.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="rows">The rows, negative up.</param>
    private void StepCarried(Node list, int rows)
    {
        int from = Math.Max(list.Cursor, 0);
        (int first, int last) = list.MoveSpan ?? (0, list.Rows - 1);
        int target = Math.Min(Math.Max(from + rows, first), last);
        if (target != from && Scroll.StopFrom(list, target, Math.Sign(rows)) is int row && row >= first && row <= last && row != from)
        {
            MoveCursor(list, row, true);
            return;
        }

        Cue(UiCue.Buzzer);
    }

    /// <summary>
    /// Moves a list's cursor by UP or DOWN to the line above or below, in the same column, past a
    /// heading row; on a last line too short for that column, to its last row.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for UP, 1 for DOWN.</param>
    /// <returns>Whether there was such a line; false on the first line for UP, on the last for DOWN, with only headings that way and for no rows.</returns>
    private bool StepLine(Node list, int step)
    {
        if (list.Rows == 0)
        {
            return false;
        }

        int from = Math.Max(list.Cursor, 0);
        int line = from / list.RowCells + step;
        if (line < 0 || line >= list.RowLines)
        {
            return false;
        }

        if (Scroll.StopFrom(list, Math.Min(from + step * list.RowCells, list.Rows - 1), step * list.RowCells) is not int row)
        {
            return false;
        }

        MoveCursor(list, row, true);
        return true;
    }

    /// <summary>
    /// Moves the cursor of a list of several rows a line by LEFT or RIGHT to the row beside, on to
    /// the line before or after at either end of a line, as the game's lists of columns do.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <returns>Whether it moved; false for a list of one row a line and past its first or last row.</returns>
    private bool StepCell(Node list, int step)
    {
        if (list.RowCells == 1 || list.Cursor < 0 || Scroll.StopFrom(list, list.Cursor + step, step) is not int next)
        {
            return false;
        }

        MoveCursor(list, next, true);
        return true;
    }

    /// <summary>
    /// Steps a numeric field's number by its step, kept within its bounds, with the cursor sound, or
    /// buzzes at its end.
    /// </summary>
    /// <param name="field">The numeric field.</param>
    /// <param name="by">1 for a step up, -1 for a step down.</param>
    private void StepNumeric(Node field, int by)
    {
        int next = new NumberRule(field.NumberMin, field.NumberMax).Step(string.Empty, field.Number, by, field.NumberStep);
        if (next == field.Number)
        {
            Cue(UiCue.Buzzer);
            return;
        }

        field.Number = next;
        Event(field.Id, "number", field.Number);
        Cue(UiCue.Cursor);
    }

    /// <summary>
    /// Steps a slider's number by its step with the cursor sound; at a bound it stays without a sound.
    /// </summary>
    /// <param name="slider">The slider.</param>
    /// <param name="by">1 for RIGHT, -1 for LEFT.</param>
    private void StepSlider(Node slider, int by)
    {
        if (SlideTo(slider, Fit(slider, (long)slider.Number + ((long)by * slider.NumberStep))))
        {
            Cue(UiCue.Cursor);
        }
    }

    /// <summary>
    /// Fits a number to a slider: to the nearest step counted from its least number, within its
    /// bounds.
    /// </summary>
    /// <param name="slider">The slider.</param>
    /// <param name="number">The number.</param>
    /// <returns>The number fitted.</returns>
    private static int Fit(Node slider, double number)
    {
        int least = slider.NumberMin ?? 0;
        int most = Math.Max(slider.NumberMax ?? least, least);
        double stepped = least + (Math.Round((number - least) / slider.NumberStep, MidpointRounding.AwayFromZero) * slider.NumberStep);
        return (int)Math.Clamp(stepped, least, most);
    }

    /// <summary>
    /// Gives a slider a number and tells it to the scripts, once it changed.
    /// </summary>
    /// <param name="slider">The slider.</param>
    /// <param name="number">The number, fitted already.</param>
    /// <returns>Whether it changed.</returns>
    private bool SlideTo(Node slider, int number)
    {
        if (number == slider.Number)
        {
            return false;
        }

        slider.Number = number;
        Event(slider.Id, "number", number);
        return true;
    }

    /// <summary>
    /// Steps the number a numeric field types by UP or DOWN, as MudBlazor's numeric field steps it: the
    /// text typed becomes the number it gives, stepped within the bounds, with the cursor sound, or the
    /// buzzer when it stays.
    /// </summary>
    /// <param name="field">The numeric field.</param>
    /// <param name="by">1 for a step up, -1 for a step down.</param>
    private void StepTyped(Node field, int by)
    {
        if (_edit?.Editor is not { Number: { } rule } editor)
        {
            return;
        }

        string text = rule.Step(editor.Text, field.Number, by, field.NumberStep).ToString(System.Globalization.CultureInfo.InvariantCulture);
        if (text == editor.Text)
        {
            Cue(UiCue.Buzzer);
            return;
        }

        editor.Edit(text, text.Length);
        Cue(UiCue.Cursor);
    }

    /// <summary>
    /// Tells which arrow of a numeric field lies at a spot: the arrows step it only while it does not
    /// type, and a click elsewhere starts typing.
    /// </summary>
    /// <param name="field">The numeric field.</param>
    /// <param name="x">The spot's left on the screen, as the field is laid out.</param>
    /// <returns>-1 for the left arrow, 1 for the right one, 0 for none.</returns>
    private static int ArrowAt(Node field, int x)
    {
        if (field.Typing || field.NumberArrows <= 0 || field.Rect is not { } box)
        {
            return 0;
        }

        return x < box.X + field.NumberArrows ? -1 : x >= box.X + box.Width - field.NumberArrows ? 1 : 0;
    }

    /// <summary>
    /// Moves a list's cursor by LEFT or RIGHT from its row's text onto the row's toggles, along
    /// them, and back onto the text.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <returns>Whether it moved; false on a row without toggles, LEFT on the text and RIGHT on the last toggle.</returns>
    private bool StepToggle(Node list, int step)
    {
        if (list.Cursor < 0 || !list.ToggleRows.TryGetValue(list.Cursor, out int toggles))
        {
            return false;
        }

        int next = list.ToggleCursor + step;
        if (next < -1 || next >= toggles)
        {
            return false;
        }

        SetToggle(list, next);
        Cue(UiCue.Cursor);
        return true;
    }

    /// <summary>
    /// Puts a list's cursor on a toggle of its row, or on the row's text, and tells the list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="toggle">The toggle, -1 or less for the row's text.</param>
    private void SetToggle(Node list, int toggle)
    {
        toggle = Math.Max(toggle, -1);
        if (toggle == list.ToggleCursor)
        {
            return;
        }

        list.ToggleCursor = toggle;
        Event(list.Id, "toggle_cursor", list.Cursor);
        _events[^1].AsArray().Add(toggle);
    }

    /// <summary>
    /// Moves a list's cursor to a row, scrolled into sight, and tells the list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="row">The row.</param>
    /// <param name="cue">Whether the cursor sound plays.</param>
    private void MoveCursor(Node list, int row, bool cue)
    {
        if (row == list.Cursor)
        {
            return;
        }

        list.Cursor = row;
        Scroll.ShowCursor(list);
        Event(list.Id, "change", row);
        if (list.ToggleCursor >= 0)
        {
            SetToggle(list, Math.Min(list.ToggleCursor, list.ToggleRows.GetValueOrDefault(row) - 1));
        }
        if (cue)
        {
            Cue(UiCue.Cursor);
        }
    }

    /// <summary>
    /// Moves the focus by Tab, or back by Shift+Tab, through a root.
    /// </summary>
    /// <param name="root">The root.</param>
    private void MoveTab(Node root)
    {
        Node? current = _focus is { } focus && Focus.RootOf(focus) == root ? focus : null;
        MoveFocus(Focus.Tab(root, current, _input.KeyDown(ShiftKey)));
    }

    /// <summary>
    /// Moves the focus to a component a key found, with the cursor sound, and shows its tooltip.
    /// </summary>
    /// <param name="node">The component, null for none.</param>
    private void MoveFocus(Node? node)
    {
        if (node is not null && node != _focus && TryFocus(node))
        {
            Cue(UiCue.Cursor);
            Reveal(node);
            ShowFocusTip(node);
        }
    }

    /// <summary>
    /// Moves the focus by an arrow to a component; where the arrow found none, tells the focused
    /// component's root leave with the arrow's way, when the root asks for it.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <param name="node">The component the arrow found; <see langword="null"/> for none.</param>
    /// <param name="way">The arrow's way: left, right, up or down.</param>
    private void MoveFocusOrLeave(Node focus, Node? node, string way)
    {
        if (node is not null)
        {
            MoveFocus(node);
        }
        else if (Focus.RootOf(focus) is { TellsLeave: true } root)
        {
            Event(root.Id, "leave", way);
        }
    }
}
