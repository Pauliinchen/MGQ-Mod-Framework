//----------------------------------------------------------------
//  ComponentTreeMouse.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Kept the rows of a list inside what is left of its padding
//      Paulinchen  2026-11-07: Dragged an item of a drop zone by the pointer into a zone
//                            - Set a slider at the pointer by a click or a drag, and filled a rating up to the cell clicked
//                              or under the pointer
//                            - Took the pointer handling of the tree
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Took a right click as cancel only in a root of the new UI layer, the context menu among them
//      Paulinchen  2026-11-05: Buzzed on a right click, the Menu key or confirm held on a disabled part or row instead of
//                              opening its context menu
//      Paulinchen  2026-11-04: Had a right click in a typing text field stop the typing with the focus kept there
//                            - Opened a part's context menu by a right click, the Menu key or a gamepad's confirm held, and
//                              took a right click elsewhere as cancel, also while the context menu is open
//                            - Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The pointer handling of the tree: the pointer, presses, releases, the scrollbar's thumb, a
/// slider's knob and the wheel, and the pointer rules of the UI layer's roots: inside a window only a list's row
/// lights up under the pointer, while menus and dropdowns follow it; a part's context menu opens
/// by a right click, the Menu key or a gamepad's confirm held, and a right click elsewhere is
/// cancel.
/// </summary>
internal sealed partial class ComponentTree
{
    /// <summary>
    /// Ticks a gamepad's confirm is held on a part with a context menu before the menu opens: half a
    /// second.
    /// </summary>
    private const int ContextHoldTicks = 30;

    /// <summary>
    /// Tells whether a component lies in a window or a dialog of the UI layer, where the pointer
    /// lights only a list's row.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it does.</returns>
    private static bool InLayerWindow(Node node) => Focus.RootOf(node) is { Layer: true, Kind: NodeKind.Window or NodeKind.Dialog };

    /// <summary>
    /// Tells whether a list's cursor follows the pointer over its rows: as the scripts set it, else
    /// everywhere but in a window of the UI layer, where the row under the pointer is framed.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Whether it does.</returns>
    private static bool FollowsPointer(Node list) => list.FollowPointer ?? !InLayerWindow(list);

    /// <summary>
    /// Finds the part whose context menu a component opens: the nearest from it upward that has one,
    /// shown and taking input.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The part, null for none.</returns>
    private static Node? ContextPart(Node node)
    {
        for (Node? part = node; part is not null; part = part.Parent)
        {
            if (part.ContextMenu)
            {
                return Focus.Shown(part) && Focus.Enabled(part) ? part : null;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells whether a component lies in a part with a context menu, whether that part takes input
    /// or not.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it does.</returns>
    private static bool InContextPart(Node node)
    {
        for (Node? part = node; part is not null; part = part.Parent)
        {
            if (part.ContextMenu)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Takes a right press: on a part with a context menu its root comes to the top, the key stop
    /// there takes the focus, a list's row the cursor, and the menu opens at the pointer; on a
    /// disabled component or row there it buzzes; anywhere else it is cancel, one step, for a root
    /// of the UI layer.
    /// </summary>
    /// <param name="target">What lies under the pointer and takes input, null for none.</param>
    /// <param name="point">Where the pointer is.</param>
    private void RightPress(Hit? target, (int X, int Y) point)
    {
        HideTip();
        int? row = target is { Node.Kind: NodeKind.List } onList ? Scroll.RowAt(onList.Node, LocalX(onList.Node, point.X), LocalY(onList.Node, point.Y)) : null;
        if (target is { } refused && !Fresh(refused.Root) && InContextPart(refused.Node)
            && (!Focus.Enabled(refused.Node) || (row is int at && refused.Node.DisabledRows.Contains(at))))
        {
            Cue(UiCue.Buzzer);
            return;
        }

        if (target is not { } on || Fresh(on.Root) || ContextPart(on.Node) is not { } part)
        {
            RightCancel();
            return;
        }

        on.Root.Raise = ++_raise;
        Rank(on.Root);
        if ((on.Node.Focusable ? on.Node : Focus.StepperAround(on.Node)) is { } stop)
        {
            TryFocus(stop);
        }

        if (row is int picked)
        {
            MoveCursor(on.Node, picked, false);
        }

        _events.Add(new RubyArray { part.Id, "context", point.X, point.Y });
    }

    /// <summary>
    /// Takes a right click without a context menu as one step of cancel in the root that takes the
    /// keys, when it is a root of the UI layer, the context menu among them: a typing field stops
    /// typing and keeps the focus, a carried row goes back, the focus walks back, else the root closes
    /// when cancel closes it. Today's other roots and the title take no right click.
    /// </summary>
    private void RightCancel()
    {
        Node? root = _focus is { } held ? Focus.RootOf(held) : Unblocked().Find(each => each.Closable);
        if (root is not { Layer: true } || Fresh(root) || Blocked(root))
        {
            return;
        }

        if (_focus is { TypesNow: true } field)
        {
            StopTyping(field);
        }
        else if (_focus is { Moving: true } carrying)
        {
            carrying.Moving = false;
            Event(carrying.Id, "uncarry");
            Cue(UiCue.Cancel);
        }
        else if (_focus is { } focus && CancelStep(focus))
        {
            Cue(UiCue.Cancel);
        }
        else if (root.Closable)
        {
            Close(root);
        }
    }

    /// <summary>
    /// Takes a gamepad's confirm on a part with a context menu: held long enough it opens the menu,
    /// let go earlier it confirms the part as a plain press would.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    /// <returns>Whether the confirm of the tick is taken here, so it confirms nothing else.</returns>
    private bool HoldsConfirm(UiButtons buttons)
    {
        if (_heldConfirm is { } hold)
        {
            _heldConfirm = null;
            if (_focus != hold.Focus)
            {
                return true;
            }

            if (!buttons.Pressed(UiButton.Confirm))
            {
                Confirm(hold.Focus);
            }
            else if (hold.Ticks + 1 < ContextHoldTicks)
            {
                _heldConfirm = (hold.Focus, hold.Ticks + 1);
            }
            else if (ContextPart(hold.Focus) is { } part)
            {
                OpenContext(part, hold.Focus);
            }

            return true;
        }

        if (buttons.Triggered(UiButton.Confirm) && !AnyDown(Keys().Confirm) && _focus is { } focus && Focus.RootOf(focus).Layer && ContextPart(focus) is not null
            && !(focus.Kind == NodeKind.List && focus.DisabledRows.Contains(focus.Cursor)))
        {
            _heldConfirm = (focus, 0);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Opens a part's context menu by a key: under the focused component, or under a list's cursor
    /// row; on a disabled row it buzzes.
    /// </summary>
    /// <param name="part">The part with the context menu.</param>
    /// <param name="focus">The focused component.</param>
    private void OpenContext(Node part, Node focus)
    {
        if (focus.Kind == NodeKind.List && focus.DisabledRows.Contains(focus.Cursor))
        {
            Cue(UiCue.Buzzer);
            return;
        }

        if (focus.Rect is not { } rect)
        {
            return;
        }

        (int dx, int dy) = HitTest.ShiftOf(focus);
        int bottom = rect.Y + rect.Height;
        if (focus.Kind == NodeKind.List && focus.Cursor >= 0)
        {
            bottom = System.Math.Min(focus.Room.Inside(rect).Y + ((focus.Cursor / focus.RowCells) - focus.ScrollTop + 1) * focus.RowHeight, bottom);
        }

        _events.Add(new RubyArray { part.Id, "context", rect.X + dx, bottom + dy });
    }

    /// <summary>
    /// Follows the pointer and the mouse: the root and the component under it, a list's row under a
    /// pointer that moved, which takes the cursor or, in a list whose cursor does not follow the
    /// pointer, a frame, and nothing in a list to read, presses and clicks, a row the pointer drags out of its place in a list that
    /// lets it, the wheel, the scrollbar's thumb, a slider's knob, the cell under the pointer on a rating and the tooltip.
    /// While the left Alt is held the player arranges the boxes, so presses go to the layout.
    /// </summary>
    private void FollowPointer()
    {
        (int X, int Y)? point = _input.Pointer;
        bool moved = point != _lastPointer;
        _lastPointer = point;
        if (_thumb is { } thumb)
        {
            FollowThumb(thumb, point);
            return;
        }

        if (_slid is { } slid)
        {
            FollowSlide(slid, point);
            return;
        }

        bool arranging = _input.KeyDown(LayoutModel.AltKey);
        Hit? hit = point is { } spot ? HitTest.At(TopFirst(), spot.X, spot.Y) : null;
        SetOver(hit?.Root.Id);
        Hit? target = hit is { } found && !Blocked(found.Root) && !arranging ? found : null;
        SetHover(target?.Node);
        FollowPreview(target?.Node, point);
        (Node List, int Row)? framed = null;
        if (target is { Node.Kind: NodeKind.List, Node.Acts: true, OnBar: false } onList && Focus.Enabled(onList.Node) && Scroll.RowAt(onList.Node, LocalX(onList.Node, point!.Value.X), LocalY(onList.Node, point!.Value.Y)) is int row)
        {
            if (moved && _pressed == onList.Node && onList.Node is { Reorder: true, Moving: false } && _pressedRow >= 0 && row != _pressedRow && _input.LeftDown
                && !onList.Node.DisabledRows.Contains(_pressedRow))
            {
                Carry(onList.Node, _pressedRow);
            }

            if (!FollowsPointer(onList.Node) && !onList.Node.Moving)
            {
                framed = onList.Node.DisabledRows.Contains(row) ? null : (onList.Node, row);
            }
            else if (moved)
            {
                MoveCursor(onList.Node, row, false);
            }
        }

        SetHoverRow(framed);

        if (arranging)
        {
            _pressed = null;
            return;
        }

        FollowDrag(point);

        // The left button also goes down on the window's title bar, outside the game's screen.
        if (_input.LeftWentDown && point is { } pressedAt)
        {
            Press(hit, target, pressedAt);
        }

        if (_input.LeftWentUp)
        {
            Release(target, point);
        }

        if (_input.RightWentDown && point is { } rightAt)
        {
            RightPress(target, rightAt);
        }

        if (_input.Notches != 0 && target is { } wheeled)
        {
            Wheel(wheeled.Node, _input.Notches);
        }

        FollowTip(target, point, moved);
    }

    /// <summary>
    /// Lets go of everything the pointer held while another window is in front; a tooltip a key's
    /// focus showed stays.
    /// </summary>
    private void Away()
    {
        SetOver(null);
        SetHover(null);
        SetHoverRow(null);
        _pressed = null;
        _thumb = null;
        _slid = null;
        _dragFrom = null;
        FollowPreview(null, null);
        _lastPointer = null;
        _tipNode = null;
        if (_tip is { ByFocus: false })
        {
            HideTip();
        }
    }

    /// <summary>
    /// Takes a left press: on a component, its root comes to the top of its depth, a disabled one
    /// buzzes, a scrollbar scrolls, a focusable one or the key stop it lies in takes the focus unless
    /// only the pointer reaches it, a list's row the cursor, and a slider without cells takes the
    /// number at the pointer and starts a drag; a press outside the focused text field takes the
    /// focus off it.
    /// </summary>
    /// <param name="hit">What lies under the pointer, blocked or not.</param>
    /// <param name="target">What lies under it and takes input, null for none.</param>
    /// <param name="point">Where the pointer is.</param>
    private void Press(Hit? hit, Hit? target, (int X, int Y) point)
    {
        _pressed = null;
        _pressedRow = -1;
        _rest = -1;
        HideTip();
        if (ClosesOutside(hit) is { } outside)
        {
            CloseOutside(outside);
            return;
        }

        if (target is not { } press)
        {
            if (hit is null && _focus is { TypesText: true })
            {
                Blur(forget: true);
            }

            return;
        }

        if (Fresh(press.Root))
        {
            return;
        }

        press.Root.Raise = ++_raise;
        Rank(press.Root);
        Node node = press.Node;
        if (press.Root.HeldUnder && Pressable(node))
        {
            Cue(UiCue.Buzzer);
            return;
        }
        if (!Focus.Enabled(node))
        {
            Cue(UiCue.Buzzer);
            return;
        }

        if (press.OnBar)
        {
            PressBar(node, LocalY(node, point.Y));
            return;
        }

        Node? stop = node.Focusable ? node : Focus.StepperAround(node);
        if (!(stop is not null && TryFocus(stop)))
        {
            if (_focus is { TypesText: true } field && field != node)
            {
                Blur(forget: true);
            }

            if ((_focus is null || Focus.RootOf(_focus) != press.Root) && press.Root.LastFocus is { } last && _nodes.ContainsKey(last.Id))
            {
                TryFocus(last);
            }
        }

        if (node is { Kind: NodeKind.Slider, Cells: 0, Acts: true })
        {
            _slid = node;
            SlideTo(node, ValueAt(node, LocalX(node, point.X)));
            return;
        }

        PressDrag(node, point);
        _pressed = node;
        _pressedTwice = _input.DoubleClicked;
        if (node is { Kind: NodeKind.List, Acts: true } && Scroll.RowAt(node, LocalX(node, point.X), LocalY(node, point.Y)) is int row)
        {
            _pressedRow = row;
            _pressedOnCursor = row == node.Cursor || node.ClickPicks;
            MoveCursor(node, row, false);
        }
    }

    /// <summary>
    /// Finds the root a press outside closes: the topmost shown root that closes on a click outside
    /// it, when the press lands neither on it nor on a root above it.
    /// </summary>
    /// <param name="hit">What lies under the pointer, blocked or not, null for nothing.</param>
    /// <returns>The root, null for none.</returns>
    private Node? ClosesOutside(Hit? hit)
    {
        foreach (Node root in TopFirst())
        {
            if (hit is { } on && (on.Root == root || Above(on.Root, root)))
            {
                return null;
            }

            if (root.CloseOutside && !Fresh(root))
            {
                return root;
            }
        }

        return null;
    }

    /// <summary>
    /// Closes a root on a click outside it as cancel does: a root that guards its cancel is asked,
    /// any other closes with the cancel sound.
    /// </summary>
    /// <param name="root">The root.</param>
    private void CloseOutside(Node root)
    {
        if (root.GuardsCancel)
        {
            Event(root.Id, "cancel", "outside");
            return;
        }

        Event(root.Id, "close", "outside");
        Cue(UiCue.Cancel);
        Remove(root);
    }

    /// <summary>
    /// Takes the left button let go: a list that carries a row drops it wherever the pointer is;
    /// over the component it went down on, a rating fills up to the cell under the pointer, or
    /// empties on its last filled cell, any other component is clicked, or a list submits the row
    /// whose box is under the pointer, else the row that held the cursor when the button went down; the
    /// second click of a double click whose first submitted a row clicks nothing else.
    /// </summary>
    /// <param name="target">What lies under the pointer and takes input, null for none.</param>
    /// <param name="point">Where the pointer is.</param>
    private void Release(Hit? target, (int X, int Y)? point)
    {
        Node? pressed = _pressed;
        _pressed = null;
        bool afterSubmit = _pressedTwice && _clickSubmitted;
        _clickSubmitted = false;
        if (ReleaseDrag(point))
        {
            return;
        }

        if (pressed is { Kind: NodeKind.List, Moving: true })
        {
            Drop(pressed, cue: true);
            return;
        }

        if (pressed is null || target?.Node != pressed)
        {
            return;
        }

        if (pressed.Kind == NodeKind.Slider)
        {
            if (pressed.Acts && point is { } onCell && CellAt(pressed, LocalX(pressed, onCell.X)) is int cell)
            {
                SlideTo(pressed, cell == pressed.Number ? Fit(pressed, pressed.NumberMin ?? 0) : cell);
            }

            return;
        }

        if (pressed.Kind == NodeKind.NumericField && point is { } stepped && ArrowAt(pressed, LocalX(pressed, stepped.X)) is int arrow and not 0)
        {
            StepNumeric(pressed, arrow);
            return;
        }

        if (pressed.Kind != NodeKind.List)
        {
            if (!afterSubmit)
            {
                Click(pressed);
            }

            return;
        }

        int row = _pressedRow;
        if (row >= 0 && point is { } onBox && Scroll.RowAt(pressed, LocalX(pressed, onBox.X), LocalY(pressed, onBox.Y)) == row
            && pressed.BoxEnds.TryGetValue(row, out int boxEnd) && Scroll.XInCell(pressed, LocalX(pressed, onBox.X)) < boxEnd)
        {
            SubmitOnce(pressed, row);
            return;
        }

        if (row >= 0 && pressed.ToggleRows.ContainsKey(row) && point is { } clicked && Scroll.RowAt(pressed, LocalX(pressed, clicked.X), LocalY(pressed, clicked.Y)) == row)
        {
            Event(pressed.Id, "row_click", row);
            _events[^1].AsArray().Add(_pressedOnCursor);
            return;
        }

        if (row < 0 || !_pressedOnCursor || point is not { } spot || Scroll.RowAt(pressed, LocalX(pressed, spot.X), LocalY(pressed, spot.Y)) != row)
        {
            return;
        }

        SubmitOnce(pressed, row);
    }

    /// <summary>
    /// Submits a list's row a click let go on, unless the click ends a double click whose first
    /// click submitted that row already.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="row">The row.</param>
    private void SubmitOnce(Node list, int row)
    {
        if (_pressedTwice && _lastSubmit == (list, row))
        {
            _lastSubmit = null;
            return;
        }

        Submit(list, row);
        _clickSubmitted = true;
    }

    /// <summary>
    /// Takes a press on a scrollbar: on the thumb it starts dragging it, beside it the component
    /// scrolls a page towards the press.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="y">Where the press is.</param>
    private void PressBar(Node node, int y)
    {
        (int top, int length) = Scroll.Thumb(node);
        if (y >= top && y < top + length)
        {
            _thumb = (node, y - top);
            return;
        }

        Page(node, y < top ? -1 : 1);
    }

    /// <summary>
    /// Follows the dragged thumb until the left button is let go.
    /// </summary>
    /// <param name="thumb">The component and where on its thumb the pointer took it.</param>
    /// <param name="point">Where the pointer is, null outside the screen.</param>
    private void FollowThumb((Node Node, int Grab) thumb, (int X, int Y)? point)
    {
        if (!_input.LeftDown)
        {
            _thumb = null;
            return;
        }

        if (point is { } spot)
        {
            Scrolled(thumb.Node, Scroll.To(thumb.Node, Scroll.TopForThumb(thumb.Node, LocalY(thumb.Node, spot.Y) - thumb.Grab)));
        }
    }

    /// <summary>
    /// Follows the dragged knob of a slider until the left button is let go or the slider turns off.
    /// </summary>
    /// <param name="slider">The slider.</param>
    /// <param name="point">Where the pointer is, null outside the screen.</param>
    private void FollowSlide(Node slider, (int X, int Y)? point)
    {
        if (!_input.LeftDown || !Focus.Enabled(slider))
        {
            _slid = null;
            return;
        }

        if (point is { } spot)
        {
            SlideTo(slider, ValueAt(slider, LocalX(slider, spot.X)));
        }
    }

    /// <summary>
    /// Tells the scripts the cell under the pointer on a rating that takes input, once it changed,
    /// so the rating shows its cells filled up to it; nil once the pointer leaves its cells.
    /// </summary>
    /// <param name="hovered">The component under the pointer that takes input, null for none.</param>
    /// <param name="point">Where the pointer is, null outside the screen.</param>
    private void FollowPreview(Node? hovered, (int X, int Y)? point)
    {
        Node? rating = hovered is { Kind: NodeKind.Slider, Cells: > 0, Acts: true } && Focus.Enabled(hovered) ? hovered : null;
        int? cell = rating is not null && point is { } spot ? CellAt(rating, LocalX(rating, spot.X)) : null;
        if (_preview.Node == rating && _preview.Cell == cell)
        {
            return;
        }

        if (_preview.Node is { } before && before != rating)
        {
            Event(before.Id, "preview", RubyNil.Value);
        }

        if (rating is not null)
        {
            Event(rating.Id, "preview", cell is int shown ? shown : RubyNil.Value);
        }

        _preview = (rating, cell);
    }

    /// <summary>
    /// Turns a left within a slider into the number there: its share of the track from the least to
    /// the largest number, fitted to the steps.
    /// </summary>
    /// <param name="slider">The slider.</param>
    /// <param name="x">The left among its places.</param>
    /// <returns>The number.</returns>
    private static int ValueAt(Node slider, int x)
    {
        if (slider.Rect is not { } box)
        {
            return slider.Number;
        }

        int length = Math.Max(box.Width - slider.Track.Left - slider.Track.Right, 1);
        double share = Math.Clamp((double)(x - box.X - slider.Track.Left) / length, 0.0, 1.0);
        int least = slider.NumberMin ?? 0;
        return Fit(slider, least + (share * ((slider.NumberMax ?? least) - least)));
    }

    /// <summary>
    /// Finds the cell of a rating under a left, counted from 1.
    /// </summary>
    /// <param name="rating">The slider shown as a rating.</param>
    /// <param name="x">The left among its places.</param>
    /// <returns>The cell, null off its cells.</returns>
    private static int? CellAt(Node rating, int x)
    {
        int inside = x - (rating.Rect?.X ?? 0) - rating.Track.Left;
        if (rating.Cells <= 0 || rating.Rect is null || inside < 0)
        {
            return null;
        }

        int cell = (inside / rating.Cells) + 1;
        return cell <= (rating.NumberMax ?? 0) ? cell : null;
    }

    /// <summary>
    /// Turns a top on the screen into the places of a component, which may be drawn shifted.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="y">The top on the screen.</param>
    /// <returns>The top among its places.</returns>
    private static int LocalY(Node node, int y) => y - HitTest.ShiftOf(node).Y;

    /// <summary>
    /// Turns a left on the screen into the places of a component, which may be drawn shifted.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="x">The left on the screen.</param>
    /// <returns>The left among its places.</returns>
    private static int LocalX(Node node, int x) => x - HitTest.ShiftOf(node).X;

    /// <summary>
    /// Scrolls the nearest list or box the pointer is in whose content outgrows it by the wheel's
    /// notches, passing over the disabled ones.
    /// </summary>
    /// <param name="node">The component under the pointer.</param>
    /// <param name="notches">The notches, positive away from the player.</param>
    private void Wheel(Node node, int notches)
    {

        if (node is { Kind: NodeKind.NumericField, Typing: false } && Focus.Enabled(node))
        {
            StepNumeric(node, Math.Sign(notches));
            return;
        }

        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (!Focus.Enabled(step))
            {
                continue;
            }

            if (step.WheelTold)
            {
                Event(step.Id, "wheel", notches);
                return;
            }

            if (step.Overflows)
            {
                int rows = step.Kind == NodeKind.List ? Scroll.WheelRows : Scroll.WheelPixels;
                Scrolled(step, Scroll.To(step, step.ScrollTop - notches * rows));
                return;
            }
        }
    }
}
