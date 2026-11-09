//----------------------------------------------------------------
//  Focus.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Found the row an arrow leaves inside what is left of a list's padding
//                            - Let UP and DOWN leave a grid that hands the focus on past its first and last lines
//                            - Moved UP and DOWN into a row onto its part nearest across
//                            - Passed over tabs that show a single tab when a key steps tabs
//      Paulinchen  2026-11-07: Found where an arrow that leaves a grid of boxes at its edge wraps the focus to
//                            - Moved UP and DOWN in a grid to the cell of the row above or below that spans the same column
//                            - Took out the text fields passed over while a box outside the tree typed
//      Paulinchen  2026-11-06: Passed over a part the keys reach only by the jump key on LEFT and RIGHT
//                            - Let the focus asked into a container land on its part marked autofocus, which a root opening
//                              passes over inside a part the keys reach only when told, such as a reading pane
//                            - Let a box that scrolls with no key stop inside take the focus asked into it itself
//                            - Picked the box beside a box picked as a whole whole, and the box below or above it by where it lies
//                            - Took out the row of tabs as one key stop, which no screen uses any more
//                            - Found the key stop nearest a component inside the boxes the keys entered around it
//      Paulinchen  2026-11-05: Started the focus and moved it by a plain arrow past a part the keys reach only by the jump key
//                            - Let a part that holds no others take the focus asked into it itself
//      Paulinchen  2026-11-04: Found where the focus starts in a root, on a component marked for it, and the key stop
//                              nearest a component that can no longer hold the focus
//      Paulinchen  2026-11-01: Found the part of a container the focus goes into and the page shown of a row of tabs, and
//                              let UP reach tabs that are one key stop by their row of tabs
//                            - Let LEFT and RIGHT step between the children of a row onto the part each held the focus on
//                              last, inside a box the keys enter
//                            - Kept UP and DOWN inside a box the keys entered
//      Paulinchen  2026-10-31: Let a text field typed into only once confirmed take the focus while another mod types
//                            - Stopped the keys on a container clicked as one part and on one they enter as a whole while
//                              the focus is outside it, and found the first component inside one
//      Paulinchen  2026-10-30: Found the component of the page beside a slides' page level with the one leaving it
//                            - Let UP and DOWN move the focus only to a component that lies above or below
//      Paulinchen  2026-10-29: Kept the focus off every component of a game window but its text fields
//                            - Kept the focus off inert components and found the page beside a slides' page and
//                              the tabs the shoulder buttons step
//                            - Let LEFT and RIGHT at the end of a row move on in the row around it
//                            - Kept the keys off components only the pointer reaches and found the key stop
//                              around a component and the tabs a key steps
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// Which components take the focus and where the keys move it: Tab through a root in tree order,
/// LEFT and RIGHT between the parts of the row a component stands in, UP and DOWN out of it or between the rows
/// of a grid.
/// </summary>
internal static class Focus
{
    /// <summary>
    /// Finds a component's root.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Its root, itself for a root.</returns>
    public static Node RootOf(Node node)
    {
        while (node.Parent is { } parent)
        {
            node = parent;
        }

        return node;
    }

    /// <summary>
    /// Tells whether a component is shown and takes input with every component it lies in: none of
    /// them hidden or inert.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it is.</returns>
    public static bool Shown(Node node)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (!step.Visible || step.Inert)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether a component takes input with every component it lies in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it does.</returns>
    public static bool Enabled(Node node)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (!step.Enabled)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether a component may hold the focus: focusable, shown and in reach of the keys, and
    /// on a game window only a text field.
    /// </summary>
    /// <remarks>
    /// The game window reads confirm and the arrows itself, so a focused button on it would take a
    /// press the game takes too.
    /// </remarks>
    /// <param name="node">The component.</param>
    /// <returns>Whether it may.</returns>
    public static bool CanHold(Node node) =>
        node.Focusable && Shown(node) && KeysReach(node) && (node.Kind == NodeKind.TextField || RootOf(node).Kind != NodeKind.Adopted);

    /// <summary>
    /// Tells whether the keys reach a component: neither it nor any component it lies in is for the
    /// pointer only.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether they do.</returns>
    public static bool KeysReach(Node node)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step.PointerOnly)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Finds the key stop a component lies in: the nearest component around it that is one key stop
    /// stepping through its places, so a press on one of its places focuses it.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The key stop, null for none.</returns>
    public static Node? StepperAround(Node node)
    {
        for (Node? step = node.Parent; step is not null; step = step.Parent)
        {
            if (step.Steps && step.Focusable)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Lists the components the keys move the focus through below a component, in tree order:
    /// focusable, shown and taking input.
    /// </summary>
    /// <param name="scope">Where to look, such as a root or a row.</param>
    /// <param name="current">The component holding the focus, listed even while it takes no input so the keys move on from it, null for none.</param>
    /// <returns>The components.</returns>
    public static List<Node> Order(Node scope, Node? current = null)
    {
        var order = new List<Node>();
        Collect(scope, current, true, order);
        return order;
    }

    /// <summary>
    /// Finds the first component of a root the focus can go to.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <returns>The component, null for none.</returns>
    public static Node? First(Node root)
    {
        List<Node> order = Order(root);
        return order.Count > 0 ? order[0] : null;
    }

    /// <summary>
    /// Finds where the focus starts as a root opens: its component marked for it, else its first
    /// that a plain arrow reaches, else its first.
    /// </summary>
    /// <remarks>
    /// A component marked inside a part the keys reach only by a jump, such as a reading pane, marks
    /// where the focus lands once asked into that part, so the root never starts there.
    /// </remarks>
    /// <param name="root">The root.</param>
    /// <returns>The component, null for none.</returns>
    public static Node? Start(Node root)
    {
        List<Node> order = Order(root);
        return order.Find(node => node.Autofocus && !InJumpOnly(node, root)) ?? order.Find(node => !node.JumpOnly) ?? (order.Count > 0 ? order[0] : null);
    }

    /// <summary>
    /// Tells whether a component lies inside a part the keys reach only by a jump, below a root.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="root">The root.</param>
    /// <returns>Whether it does.</returns>
    private static bool InJumpOnly(Node node, Node root)
    {
        for (Node? step = node.Parent; step is not null && step != root; step = step.Parent)
        {
            if (step.JumpOnly)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Finds the key stop nearest a component that can no longer hold the focus: the next one after
    /// it in its root's tree order, else the one before, inside the boxes the keys entered around it.
    /// </summary>
    /// <param name="root">The root it lies in.</param>
    /// <param name="from">The component.</param>
    /// <returns>The key stop, null when the root has no other.</returns>
    public static Node? Nearest(Node root, Node from)
    {
        List<Node> order = Order(root, from);
        order.Remove(from);
        if (order.Count == 0)
        {
            return null;
        }

        var places = new Dictionary<Node, int>();
        Number(root, places);
        int at = places.GetValueOrDefault(from, -1);
        return order.Find(node => places[node] > at) ?? order[^1];
    }

    /// <summary>
    /// Numbers a component and everything it holds in tree order, hidden ones too.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="places">Each component's number.</param>
    private static void Number(Node node, Dictionary<Node, int> places)
    {
        places[node] = places.Count;
        foreach (Node child in node.Children)
        {
            Number(child, places);
        }
    }

    /// <summary>
    /// Finds the first component inside a container the focus can go to, the container itself left
    /// out.
    /// </summary>
    /// <param name="container">The container.</param>
    /// <returns>The component, null for none.</returns>
    public static Node? FirstInside(Node container)
    {
        var order = new List<Node>();
        foreach (Node child in container.Children)
        {
            Collect(child, null, Enabled(container), order);
        }

        return order.Count > 0 ? order[0] : null;
    }

    /// <summary>
    /// Finds where the focus goes into a container: its part marked autofocus, else the part inside
    /// it that held the focus last, else its first, passing over a list with no row to pick; a part
    /// that holds no others, such as the list a bar of tabs fills, and a box that scrolls with no key
    /// stop inside, such as a reading pane of text, take the focus themselves.
    /// </summary>
    /// <param name="container">The container, such as a tab's page.</param>
    /// <returns>The component, null when the container has none the focus can go to.</returns>
    public static Node? Into(Node container)
    {
        var order = new List<Node>();
        foreach (Node child in container.Children)
        {
            Collect(child, null, Enabled(container), order);
        }

        if (order.Find(node => node.Autofocus && Picks(node)) is { } marked)
        {
            return marked;
        }

        if (Remembered(container) is { } last && Picks(last))
        {
            return last;
        }

        return order.Find(Picks) ?? ((container.Children.Count == 0 || container.Scroll) && CanHold(container) && Picks(container) ? container : null);
    }

    /// <summary>
    /// Finds the page shown of a row of tabs, passing over the other parts the tabs hold, such as
    /// their row of tabs and a part added under it.
    /// </summary>
    /// <param name="tabs">The tabs.</param>
    /// <returns>The page, null for none.</returns>
    public static Node? PageShown(Node tabs) => tabs.Children.FirstOrDefault(page => page.TabPage && page.Visible);

    /// <summary>
    /// Tells whether a component has something to pick: any but a list without a row.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it has.</returns>
    private static bool Picks(Node node) => node.Kind != NodeKind.List || node.Cursor >= 0;

    /// <summary>
    /// Finds where Tab moves the focus in a root: the next component in tree order, or the one
    /// before for Shift+Tab, round from the end to the start.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="current">The component holding the focus, null for none.</param>
    /// <param name="back">Whether to move back.</param>
    /// <returns>The component, null when the root has none.</returns>
    public static Node? Tab(Node root, Node? current, bool back)
    {
        List<Node> order = Order(root, current);
        if (order.Count == 0)
        {
            return null;
        }

        int index = current is null ? -1 : order.IndexOf(current);
        if (back)
        {
            return order[index <= 0 ? order.Count - 1 : index - 1];
        }

        return order[index < 0 || index == order.Count - 1 ? 0 : index + 1];
    }

    /// <summary>
    /// Finds where LEFT or RIGHT moves the focus: in the nearest row or grid the focused component
    /// stands in, the part of the child beside the one holding it; at its end, the same in the row or
    /// grid around that one, never round. From a box picked as a whole the box beside is picked whole.
    /// A part the keys reach only by the jump key is passed over unless it is held or the focus leaves
    /// such a part.
    /// </summary>
    /// <remarks>
    /// Stepping by the row's children, not its key order, keeps a box the keys enter below the
    /// focused one in the same column from catching the move.
    /// </remarks>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <param name="jumping">Whether the jump key is held, which reaches the parts only it reaches.</param>
    /// <returns>The component, null for none.</returns>
    public static Node? Along(Node current, int step, bool jumping = false)
    {
        bool jumpOnly = jumping || current.JumpOnly;
        for (Node? row = RowAround(current); row is not null; row = RowAround(row))
        {
            int index = row.Children.FindIndex(child => Inside(current, child));
            for (int next = index + step; index >= 0 && next >= 0 && next < row.Children.Count; next += step)
            {
                if (Onto(row.Children[next], Picked(current), jumpOnly) is { } found)
                {
                    return found;
                }
            }
        }

        return null;
    }

    /// <summary>
    /// Finds where a sideways move into a part puts the focus: the component inside it that held the
    /// focus last, else its first; a box the keys enter is entered the same way, or picked whole when
    /// the move comes from a box picked whole.
    /// </summary>
    /// <param name="part">The part reached.</param>
    /// <param name="whole">Whether the move comes from a box picked as a whole.</param>
    /// <param name="jumpOnly">Whether the parts the keys reach only by the jump key count.</param>
    /// <returns>The component, null when the part has none the focus can go to.</returns>
    private static Node? Onto(Node part, bool whole, bool jumpOnly)
    {
        Node? found = Remembered(part) is { } last && (jumpOnly || !last.JumpOnly)
            ? last
            : Order(part).Find(node => jumpOnly || !node.JumpOnly);
        if (whole)
        {
            return found is null ? null : OuterBox(found, part) ?? found;
        }

        while (found is { Enter: true, Clickable: false } box && (Remembered(box) ?? FirstInside(box)) is { } inside)
        {
            found = inside;
        }

        return found;
    }

    /// <summary>
    /// Finds the outermost box the keys enter that a component lies inside, up to a part and the part
    /// itself included.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="part">The part to look up to.</param>
    /// <returns>The box, null for none.</returns>
    private static Node? OuterBox(Node node, Node part)
    {
        Node? box = null;
        for (Node? step = node.Parent; step is not null && Inside(step, part); step = step.Parent)
        {
            if (Picked(step) && step.Focusable)
            {
                box = step;
            }
        }

        return box;
    }

    /// <summary>
    /// Finds the component inside a part that held the focus last, while the focus can still go to
    /// it.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>The component, null for none.</returns>
    private static Node? Remembered(Node part) =>
        part.LastInner is { } last && last != part && Enabled(last) && Order(part, last).Contains(last) ? last : null;

    /// <summary>
    /// Finds the nearest slides a component lies in that LEFT and RIGHT move.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The slides, null for none.</returns>
    public static Node? SlidesOf(Node node)
    {
        for (Node? step = node.Parent; step is not null; step = step.Parent)
        {
            if (step.Kind == NodeKind.Slides && step.SlideKeys)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Finds where LEFT or RIGHT moves the focus out of a slides' page: the first component of the
    /// page beside it in that way level with the one leaving, else its first, while that page shows
    /// and takes input.
    /// </summary>
    /// <param name="slides">The slides.</param>
    /// <param name="current">The component holding the focus, inside one of its pages.</param>
    /// <param name="step">-1 for LEFT, 1 for RIGHT.</param>
    /// <returns>The component, null when no page beside shows or it has none.</returns>
    public static Node? PageBeside(Node slides, Node current, int step)
    {
        int page = slides.Children.FindIndex(child => Inside(current, child));
        int next = page + step;
        if (page < 0 || next < 0 || next >= slides.Children.Count || !Shown(slides.Children[next]))
        {
            return null;
        }

        List<Node> order = Order(slides.Children[next]);
        return order.Find(node => Level(current, node)) ?? (order.Count > 0 ? order[0] : null);
    }

    /// <summary>
    /// Tells whether a component lies level with the one leaving: some of its height shares that of
    /// the leaving one, or of its cursor's line when that is a list.
    /// </summary>
    /// <param name="leaving">The component the focus leaves.</param>
    /// <param name="other">The component beside.</param>
    /// <returns>Whether both are laid out and level.</returns>
    private static bool Level(Node leaving, Node other)
    {
        if (leaving.Rect is not { } a || other.Rect is not { } b)
        {
            return false;
        }

        var (top, height) = (a.Y, a.Height);
        if (leaving.Kind == NodeKind.List && leaving.Cursor >= 0)
        {
            top = leaving.Room.Inside(a).Y + (leaving.Cursor / leaving.RowCells - leaving.ScrollTop) * leaving.RowHeight;
            height = leaving.RowHeight;
        }

        return b.Y < top + height && b.Y + b.Height > top;
    }

    /// <summary>
    /// Finds the tabs a key steps in a root: the first tabs shown, taking input, reached by the keys,
    /// set to step by that key and showing tabs to step to.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="steps">Whether a row of tabs steps by the key.</param>
    /// <returns>The tabs, null for none.</returns>
    public static Node? SteppedTabs(Node root, Func<Node, bool> steps)
    {
        foreach (Node child in root.Children)
        {
            if (!child.Visible || child.Inert || !child.Enabled || child.PointerOnly)
            {
                continue;
            }

            if (child.Kind == NodeKind.Tabs && steps(child) && HasTabsToStep(child))
            {
                return child;
            }

            if (SteppedTabs(child, steps) is { } found)
            {
                return found;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells whether stepping a row of tabs picks another tab: it shows two or more, or the scripts
    /// do not tell.
    /// </summary>
    /// <remarks>
    /// A row of one tab would catch the key and do nothing, so the key goes on, such as the
    /// shoulders to the window's page step.
    /// </remarks>
    /// <param name="tabs">The tabs.</param>
    /// <returns>Whether it does.</returns>
    public static bool HasTabsToStep(Node tabs) => tabs.TabsShown is null or >= 2;

    /// <summary>
    /// Finds the nearest row or grid a component lies in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The row or grid, null for none.</returns>
    private static Node? RowAround(Node node)
    {
        Node? row = node.Parent;
        while (row is not null && row.Layout is not (FlowLayout.Row or FlowLayout.Grid))
        {
            row = row.Parent;
        }

        return row;
    }

    /// <summary>
    /// Finds where UP or DOWN moves the focus: in a grid on within the cell, else to the cell above
    /// or below in the same column; otherwise, and out of a grid's first or last row, the component
    /// before or after in its root's tree order that does not stand in the same row or grid and lies
    /// wholly above or below it, never round and never out of a box the keys entered; in a row or grid
    /// that does not hold it, the one in the part nearest across.
    /// </summary>
    /// <remarks>
    /// A component beside it, such as the pane beside a list in a column of its own, is passed over,
    /// so DOWN on a list's last row reaches what lies under both columns.
    /// </remarks>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="step">-1 for UP, 1 for DOWN.</param>
    /// <param name="jumping">Whether the jump key is held, which reaches the parts only it reaches.</param>
    /// <returns>The component, null for none.</returns>
    public static Node? Across(Node current, int step, bool jumping = false)
    {
        Node? group = RowOf(current);
        if (GridOf(current) is { } grid)
        {
            if (InGrid(grid.Grid, grid.Cell, current, step) is { } cell)
            {
                return cell;
            }

            group = grid.Grid;
        }

        List<Node> order = Order(RootOf(current), current);
        int index = order.IndexOf(current);
        if (index < 0)
        {
            return null;
        }

        Node? entered = EnteredBox(current);
        List<Node> stops = [];
        for (index += step; index >= 0 && index < order.Count; index += step)
        {
            if ((entered is not null && !Inside(order[index], entered)) || (order[index].JumpOnly && !jumping && !current.JumpOnly))
            {
                continue;
            }

            if ((group is null || !Inside(order[index], group)) && Beyond(current, order[index], step))
            {
                stops.Add(order[index]);
            }
        }

        return stops.Count == 0 ? null : IntoRow(current, stops);
    }

    /// <summary>
    /// Finds where UP or DOWN lands in a row or grid that does not hold the focused component: the
    /// first key stop on the way, unless it lies in such a row, then the stop on the way inside the
    /// row's part nearest across, down through the rows inside that part the same way.
    /// </summary>
    /// <remarks>
    /// The first stop on the way up into a row is its last part, which lies far from a focus under the
    /// row's left end, such as a list under a row of toggles.
    /// </remarks>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="stops">The key stops the move may land on, nearest in tree order first.</param>
    /// <returns>The key stop.</returns>
    private static Node IntoRow(Node current, List<Node> stops)
    {
        Node target = stops[0];
        Node? within = null;
        while (current.Rect is { } from && OuterRow(target, current, within) is { } row)
        {
            Node part = NearestPart(row, target, from, stops);
            target = stops.Find(stop => Inside(stop, part))!;
            within = part;
        }

        return target;
    }

    /// <summary>
    /// Finds the outermost row or grid a key stop lies in, inside a part or, with none, among those
    /// that do not hold the focused component.
    /// </summary>
    /// <param name="stop">The key stop.</param>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="within">The part to look inside, the part itself included; null for the whole root.</param>
    /// <returns>The row or grid, null for none.</returns>
    private static Node? OuterRow(Node stop, Node current, Node? within)
    {
        Node? outer = null;
        for (Node? step = stop.Parent; step is not null && (within is null ? !Inside(current, step) : Inside(step, within)); step = step.Parent)
        {
            if (step.Layout is FlowLayout.Row or FlowLayout.Grid)
            {
                outer = step;
            }
        }

        return outer;
    }

    /// <summary>
    /// Finds the part of a row, or of a grid's line that holds a key stop, nearest across to a place:
    /// of the parts holding a key stop the move may land on, one sharing some of its width before one
    /// that does not, then the first in tree order, else the nearest; a part not laid out yet is
    /// passed over.
    /// </summary>
    /// <param name="row">The row or grid.</param>
    /// <param name="stop">The key stop the move lands on in tree order.</param>
    /// <param name="from">The place of the component holding the focus.</param>
    /// <param name="stops">The key stops the move may land on.</param>
    /// <returns>The part, the one holding the stop when none is laid out.</returns>
    private static Node NearestPart(Node row, Node stop, LayoutRect from, List<Node> stops)
    {
        Node part = row.Children.Find(child => Inside(stop, child))!;
        List<Node> parts = row.Children;
        if (row.Layout == FlowLayout.Grid)
        {
            parts = Flow.GridRows(row, row.Children.FindAll(child => child.Visible)).Find(line => line.Contains(part)) ?? [part];
        }

        Node best = part;
        (bool Apart, int Gap, int Index)? bestRank = null;
        foreach (Node child in parts)
        {
            if (child.Rect is not { } to || !stops.Exists(found => Inside(found, child)))
            {
                continue;
            }

            int shared = Math.Min(from.X + from.Width, to.X + to.Width) - Math.Max(from.X, to.X);
            (bool Apart, int Gap, int Index) rank = (shared <= 0, Math.Max(0, -shared), parts.IndexOf(child));
            if (bestRank is null || rank.CompareTo(bestRank.Value) < 0)
            {
                (best, bestRank) = (child, rank);
            }
        }

        return best;
    }

    /// <summary>
    /// Tells whether a component is a box the keys enter that holds the focus as a whole, picked
    /// before the keys go inside.
    /// </summary>
    /// <param name="node">The component holding the focus.</param>
    /// <returns>Whether it is.</returns>
    public static bool Picked(Node node) => node.Enter && !node.Clickable;

    /// <summary>
    /// Finds where UP or DOWN moves the focus from a box picked as a whole: of the key stops inside the
    /// boxes the keys entered around it, those lying wholly above or below it, one sharing some of its
    /// width before one that does not, then the nearest, then the one sharing more of its width, then
    /// the first in tree order; a box the keys enter is picked whole too.
    /// </summary>
    /// <remarks>
    /// Tree order alone would pick a box that comes first in the tree, such as a drawer below the left
    /// end of a bar, over the box below most of the bar.
    /// </remarks>
    /// <param name="current">The box picked.</param>
    /// <param name="step">-1 for UP, 1 for DOWN.</param>
    /// <returns>The key stop, null for none laid out that way.</returns>
    public static Node? PickAcross(Node current, int step)
    {
        if (current.Rect is not { } from)
        {
            return null;
        }

        Node? entered = EnteredBox(current);
        Node? best = null;
        (bool Apart, int Gap, int Shared) bestRank = default;
        foreach (Node node in Order(RootOf(current), current))
        {
            if (node == current || node.Rect is not { } to || (entered is not null && !Inside(node, entered)) || (node.JumpOnly && !current.JumpOnly))
            {
                continue;
            }

            int gap = step > 0 ? to.Y - (from.Y + from.Height) : from.Y - (to.Y + to.Height);
            int shared = Math.Min(from.X + from.Width, to.X + to.Width) - Math.Max(from.X, to.X);
            (bool Apart, int Gap, int Shared) rank = (shared <= 0, gap, -Math.Max(shared, 0));
            if (gap >= 0 && (best is null || rank.CompareTo(bestRank) < 0))
            {
                (best, bestRank) = (node, rank);
            }
        }

        return best;
    }

    /// <summary>
    /// Finds the nearest box the keys enter that a component lies inside, the box itself left out.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The box, null for none.</returns>
    private static Node? EnteredBox(Node node)
    {
        for (Node? step = node.Parent; step is not null; step = step.Parent)
        {
            if (step.Enter && !step.Clickable)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells whether a component lies wholly below another, or wholly above it; one not laid out yet
    /// counts as lying there.
    /// </summary>
    /// <param name="current">The component the focus leaves.</param>
    /// <param name="next">The component it may go to.</param>
    /// <param name="step">-1 for above, 1 for below.</param>
    /// <returns>Whether it lies there.</returns>
    private static bool Beyond(Node current, Node next, int step)
    {
        if (current.Rect is not { } from || next.Rect is not { } to)
        {
            return true;
        }

        return step > 0 ? to.Y >= from.Y + from.Height : to.Y + to.Height <= from.Y;
    }

    /// <summary>
    /// Finds where UP or DOWN moves the focus inside a grid: on within the cell, else to the last or
    /// first component of the nearest cell above or below that spans the column the cell starts at
    /// and has one.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="cell">The grid's child the focused component lies in.</param>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="step">-1 for UP, 1 for DOWN.</param>
    /// <returns>The component, null when the focus leaves the grid.</returns>
    private static Node? InGrid(Node grid, Node cell, Node current, int step)
    {
        List<Node> inCell = Order(cell, current);
        int index = inCell.IndexOf(current) + step;
        if (index >= 0 && index < inCell.Count)
        {
            return inCell[index];
        }

        List<List<Node>> rows = Flow.GridRows(grid, grid.Children.FindAll(child => child.Visible));
        int row = rows.FindIndex(cells => cells.Contains(cell));
        int column = row < 0 ? 0 : Flow.StartOf(grid, rows[row], cell);
        for (int next = row + step; row >= 0 && next >= 0 && next < rows.Count; next += step)
        {
            List<Node> order = Flow.CellAt(grid, rows[next], column) is { } other ? Order(other) : [];
            if (order.Count > 0)
            {
                return order[step < 0 ? order.Count - 1 : 0];
            }
        }

        return null;
    }

    /// <summary>
    /// Finds where an arrow that would leave a grid of boxes, such as cards, at its edge wraps the
    /// focus to: UP and DOWN to the cell at the other end that spans the same column, LEFT on the
    /// first cell to the last and RIGHT on the last cell to the first; a grid that leaves its ends
    /// wraps only LEFT and RIGHT.
    /// </summary>
    /// <remarks>
    /// Only a grid whose cells hold boxes wraps, so a grid that lays a window's buttons out still
    /// hands the focus on to the parts above and below it.
    /// </remarks>
    /// <param name="current">The component holding the focus.</param>
    /// <param name="vertical">-1 for UP, 1 for DOWN, 0 for neither.</param>
    /// <param name="horizontal">-1 for LEFT, 1 for RIGHT, 0 for neither.</param>
    /// <returns>The component, which may be the current one, null when the arrow does not leave such a grid.</returns>
    public static Node? GridWrap(Node current, int vertical, int horizontal)
    {
        if (GridOf(current) is not { } found || !InBox(current, found.Cell))
        {
            return null;
        }

        Node grid = found.Grid;
        if (vertical != 0)
        {
            if (grid.LeaveEnds || InGrid(grid, found.Cell, current, vertical) is not null)
            {
                return null;
            }

            List<List<Node>> rows = Flow.GridRows(grid, grid.Children.FindAll(child => child.Visible));
            int row = rows.FindIndex(cells => cells.Contains(found.Cell));
            int column = row < 0 ? 0 : Flow.StartOf(grid, rows[row], found.Cell);
            for (int next = vertical > 0 ? 0 : rows.Count - 1; next >= 0 && next < rows.Count; next += vertical)
            {
                List<Node> order = Flow.CellAt(grid, rows[next], column) is { } other ? Order(other, current) : [];
                if (order.Count > 0)
                {
                    return order[vertical < 0 ? order.Count - 1 : 0];
                }
            }

            return null;
        }

        if (horizontal == 0 || (Along(current, horizontal) is { } beside && Inside(beside, grid)))
        {
            return null;
        }

        List<Node> stops = Order(grid, current);
        return stops.Count == 0 ? null : stops[horizontal > 0 ? 0 : stops.Count - 1];
    }

    /// <summary>
    /// Tells whether a component is or lies in a box inside a grid's cell, and not inside a box the
    /// keys entered.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="cell">The grid's child it lies in.</param>
    /// <returns>Whether it does.</returns>
    private static bool InBox(Node node, Node cell)
    {
        bool box = false;
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step != node && Picked(step))
            {
                return false;
            }

            box |= step.Kind == NodeKind.Box;
            if (step == cell)
            {
                break;
            }
        }

        return box;
    }

    /// <summary>
    /// Finds the grid around a component when it is nearer than any row, with the grid's child the
    /// component lies in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The grid and the cell, null for none.</returns>
    private static (Node Grid, Node Cell)? GridOf(Node node)
    {
        for (Node cell = node; cell.Parent is { } parent; cell = parent)
        {
            if (parent.Layout == FlowLayout.Grid)
            {
                return (parent, cell);
            }

            if (parent.Layout == FlowLayout.Row)
            {
                return null;
            }
        }

        return null;
    }

    /// <summary>
    /// Finds the row a component stands in directly.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Its parent when that is a row, null otherwise.</returns>
    private static Node? RowOf(Node node) => node.Parent is { Layout: FlowLayout.Row } row ? row : null;

    /// <summary>
    /// Tells whether a component lies in another or is it.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether it does.</returns>
    private static bool Inside(Node node, Node other)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step == other)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Adds the components the focus moves through below a component, in tree order, none for the
    /// pointer only.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="current">The component holding the focus, listed even while it takes no input, null for none.</param>
    /// <param name="enabled">Whether every component above takes input.</param>
    /// <param name="order">Where they go.</param>
    private static void Collect(Node node, Node? current, bool enabled, List<Node> order)
    {
        if (!node.Visible || node.Inert || node.PointerOnly)
        {
            return;
        }

        enabled &= node.Enabled;
        bool entered = node.Enter && current is not null && current != node && Inside(current, node);
        if (node.Focusable && !entered && (enabled || node == current))
        {
            order.Add(node);
        }

        if (node.Clickable || (node.Enter && !entered))
        {
            return;
        }

        if (!enabled && (current is null || !Inside(current, node)))
        {
            return;
        }

        foreach (Node child in node.Children)
        {
            Collect(child, current, enabled, order);
        }
    }
}
