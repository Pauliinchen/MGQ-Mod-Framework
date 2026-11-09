//----------------------------------------------------------------
//  Flow.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Kept the proportions of a part that keeps them
//                            - Let a root's padding give way before it shows a compact form
//                            - Let a part's padding give way, where it lets it, before what it holds narrows at its most size
//                            - Kept each part's margin around it, outside its size, in every layout and at a root's place
//                            - Stood a centered part in the middle of its column at its most width, or the largest of its widths that fits
//      Paulinchen  2026-11-07: Laid out without room every part the scripts show that its root's step leaves out
//                            - Took room back through the plain columns a part that fills takes the room through
//                            - Laid a child over its parent's top right corner, out of the parent's layout
//                            - Let a child of a grid span several of its columns, a row taking children while their spans fit
//                            - Removed the rows that line their columns up, which no script sends
//                            - Showed each part the compact form its root's step picks, stepping on while the root runs short of room
//      Paulinchen  2026-11-06: Left a part of a column that keeps its newest parts without room where it does not fit whole,
//                              unless it is a label, which keeps its whole lines
//                            - Kept a root that gives room as high as what it holds when that is less than its least height
//      Paulinchen  2026-11-05: Gave a column of no height of its own the free room a part inside it fills, such as a tab's page
//      Paulinchen  2026-11-04: Placed a root alone at its zone
//      Paulinchen  2026-10-31: Counted no more lines of a wrapped text than it keeps
//                            - Laid a column out from its bottom, leaving out from its top what it does not hold, and
//                              gave a grid as many equal columns as its widest child fits
//      Paulinchen  2026-10-29: Kept a steady child of a column as high as its tallest content and a child within its
//                              share of the column, and kept the children after a list of whole rows at the
//                              column's bottom edge
//                            - Kept a child that gives room back, and one with a share, at least as high as what
//                              it holds that cannot give room back
//                            - Counted the lines of a list that shows its rows in columns
//                            - Cut a list of whole rows to the rows its place holds and lined up the rows of columns
//                            - Laid out the pages of a slides side by side and let a child give room back without growing
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// Lays out the component tree: each component's size from what it holds, its fixed sides and its
/// least and most size, and its place in its parent's column, row, grid or at its own place.
/// </summary>
/// <remarks>
/// Widths are settled before heights, since a wrapped text is only as high as the width it gets
/// lets it be. Every size a parent asks of a child is its outer size, its margin included, while
/// least and most sizes and the place it keeps count only its border box.
/// </remarks>
internal sealed class Flow
{
    /// <summary>
    /// The fonts texts are measured in, null to measure no text.
    /// </summary>
    private readonly UiText? _text;

    /// <summary>
    /// Each component's size as it would like it, kept for one layout.
    /// </summary>
    private readonly Dictionary<Node, (int Width, int Height)> _natural = [];

    /// <summary>
    /// Each component's height for a width, kept for one layout.
    /// </summary>
    private readonly Dictionary<(Node Node, int Width), int> _heights = [];

    /// <summary>
    /// Creates the layout.
    /// </summary>
    /// <param name="text">The fonts texts are measured in, null to measure no text.</param>
    public Flow(UiText? text)
    {
        _text = text;
    }

    /// <summary>
    /// Starts a layout, forgetting the sizes of the last, which may have changed since.
    /// </summary>
    public void Begin()
    {
        _natural.Clear();
        _heights.Clear();
    }

    /// <summary>
    /// Places a root on the screen: in the middle, at its place, alone at its zone, or where the
    /// player put it, sized to what it holds or as the player sized it, within its least and most
    /// size and the screen.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <param name="arranged">Where the player put it, its own place without its margin, null where it starts.</param>
    /// <returns>Its place with its margin around it.</returns>
    public LayoutRect PlaceRoot(Node root, int screenWidth, int screenHeight, LayoutRect? arranged)
    {
        if (ShowForms(root, root.FoldStep))
        {
            Begin();
        }

        bool resizesWidth = arranged is not null && root.Resizable is LayoutResize.Both or LayoutResize.Width;
        bool resizesHeight = arranged is not null && root.Resizable is LayoutResize.Both or LayoutResize.Height;
        Insets margin = root.Margin;
        int width = resizesWidth ? ClampWidth(root, arranged!.Value.Width) + margin.Horizontal : Natural(root).Width;
        width = Math.Min(width, screenWidth);
        int height = resizesHeight ? ClampHeight(root, arranged!.Value.Height) + margin.Vertical : HeightFor(root, width);
        height = Math.Min(height, screenHeight);
        (int x, int y) = root.Center ? ((screenWidth - width) / 2, (screenHeight - height) / 2)
                       : root.At ?? (root.Anchor is { } zone ? Docks.Align(zone, width, height, screenWidth, screenHeight) : (0, 0));
        if (arranged is { } place && root.Movable)
        {
            // The player's drag keeps the root's own place, so a margin taken there again would creep.
            (x, y) = (place.X - margin.Left, place.Y - margin.Top);
        }

        return LayoutModel.OnScreen(new LayoutRect(x, y, width, height), screenWidth, screenHeight);
    }

    /// <summary>
    /// Picks the step of a root's compact forms for its place: the step it kept while its size stays
    /// the same, else none, then each later step a form names while what it holds, with the tallest
    /// copy of each part that has copies, is higher than the root, so the forms come in one step after
    /// another.
    /// </summary>
    /// <remarks>
    /// Keeping the step while the size stays keeps a part from jumping between its forms as its
    /// content changes, such as a comparison that follows a list's cursor; its copies keep it from
    /// stepping on once the cursor reaches a taller item.
    /// </remarks>
    /// <param name="root">The root.</param>
    /// <param name="rect">Its place.</param>
    public void Fold(Node root, LayoutRect rect)
    {
        var steps = new SortedSet<int>();
        StepsIn(root, steps);
        int copies = CopiesIn(root);
        int step = root.FoldSize == (rect.Width, rect.Height) ? root.FoldStep : 0;
        if (ShowForms(root, step))
        {
            Begin();
        }

        foreach (int next in steps)
        {
            if (next <= step)
            {
                continue;
            }

            if (Tallest(root, rect.Width, copies) <= rect.Height)
            {
                break;
            }

            step = next;
            if (ShowForms(root, step))
            {
                Begin();
            }
        }

        (root.FoldStep, root.FoldSize) = (step, (rect.Width, rect.Height));
    }

    /// <summary>
    /// Tells how high a root's content wants to be at its tallest: with each part that has copies
    /// measured as the part itself, then as each copy.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="width">Its width.</param>
    /// <param name="copies">The most children of a part with copies, the part itself among them.</param>
    /// <returns>The pixels.</returns>
    private int Tallest(Node root, int width, int copies)
    {
        int tallest = Needed(root, width);
        for (int copy = 1; copy < copies; copy++)
        {
            MeasureCopy(root, copy);
            Begin();
            tallest = Math.Max(tallest, Needed(root, width));
        }

        if (copies > 1)
        {
            MeasureCopy(root, 0);
            Begin();
        }

        return tallest;
    }

    /// <summary>
    /// Has each part with copies in a component and what it holds stand for one of its children as it
    /// is measured, its last for a later one.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="copy">The child, 0 for the part itself.</param>
    private static void MeasureCopy(Node node, int copy)
    {
        if (node.Measures)
        {
            node.CopyMeasured = Math.Min(copy, Math.Max(node.Children.Count - 1, 0));
        }

        foreach (Node child in node.Children)
        {
            MeasureCopy(child, copy);
        }
    }

    /// <summary>
    /// Tells the most children a part with copies in a component and what it holds has.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The count, the part itself among them; 1 without copies.</returns>
    private static int CopiesIn(Node node)
    {
        int most = node.Measures ? node.Children.Count : 1;
        foreach (Node child in node.Children)
        {
            most = Math.Max(most, CopiesIn(child));
        }

        return most;
    }

    /// <summary>
    /// Shows each part's form of a step in a component and what it holds: the form of the highest
    /// step up to it.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="step">The step.</param>
    /// <returns>Whether any form came or went.</returns>
    private static bool ShowForms(Node node, int step)
    {
        bool changed = false;
        if (node.FormSteps is { } steps)
        {
            int picked = 0;
            for (int index = 0; index < steps.Length && index < node.Children.Count; index++)
            {
                picked = steps[index] <= step ? index : picked;
            }

            for (int index = 0; index < node.Children.Count; index++)
            {
                changed |= node.Children[index].FormShown != (index == picked);
                node.Children[index].FormShown = index == picked;
            }
        }

        foreach (Node child in node.Children)
        {
            changed |= ShowForms(child, step);
        }

        return changed;
    }

    /// <summary>
    /// Collects the steps the compact forms in a component and what it holds name.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="steps">Where the steps go.</param>
    private static void StepsIn(Node node, SortedSet<int> steps)
    {
        foreach (int step in node.FormSteps ?? [])
        {
            steps.Add(step);
        }

        foreach (Node child in node.Children)
        {
            StepsIn(child, steps);
        }
    }

    /// <summary>
    /// Tells how high a root's content wants to be in a width, with its margin and the padding that
    /// does not give way, whatever height the root itself is given.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="width">Its width, its margin included.</param>
    /// <returns>The pixels.</returns>
    private int Needed(Node root, int width)
    {
        List<Node> shown = Shown(root);
        int content = shown.Count == 0 ? 0 : ContentHeight(root, shown, InnerWidth(root, width));
        return content + root.Padding.Vertical - root.PaddingGives.Vertical + root.Margin.Vertical;
    }

    /// <summary>
    /// Gives a component its place inside its margin and lays out what it holds inside it.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="rect">Its place, its margin included.</param>
    public void Arrange(Node node, LayoutRect rect)
    {
        rect = node.Margin.Inside(rect);
        if (node.Kind == NodeKind.List && node.WholeRows && node.Padding.Inside(rect).Height >= node.RowHeight)
        {
            int rows = node.Padding.Inside(rect).Height / node.RowHeight;
            rect = rect with { Height = rows * node.RowHeight + node.Padding.Vertical };
        }

        node.Rect = rect;
        node.PaddingCut = PaddingCut(node, rect);
        LayoutRect inner = node.Room.Inside(rect);
        foreach (Node corner in node.Children.FindAll(child => child.Visible && child.Corner))
        {
            (int width, int height) = Natural(corner);
            Arrange(corner, new LayoutRect(rect.X + rect.Width - width, rect.Y, width, height));
        }

        // The scripts wait for every part they show to have a place before they draw the window, so a
        // part this step leaves out, such as a part's forms whose picked form is hidden, gets one too.
        foreach (Node hidden in node.Children.FindAll(child => child.ShownByScripts && !child.Visible))
        {
            hidden.Rect = new LayoutRect(inner.X, inner.Y, 0, 0);
        }

        // The scripts measure some parts, such as lines in columns, for the width they last got, so a
        // copy takes the part's place to be measured as the part would be.
        for (int index = 1; node.Measures && index < node.Children.Count; index++)
        {
            Arrange(node.Children[index], inner);
        }

        if (node.Kind == NodeKind.List)
        {
            node.ScrollShown = inner.Height / node.RowHeight;
            node.ScrollTotal = node.RowLines;
            node.ScrollTop = Scroll.Clamp(node, node.ScrollTop);
        }

        List<Node> shown = Shown(node);
        LayoutRect area = inner;
        if (node.Scroll)
        {
            int content = shown.Count == 0 ? 0 : ContentHeight(node, shown, inner.Width);
            node.ScrollShown = inner.Height;
            node.ScrollTotal = content;
            node.ScrollTop = Scroll.Clamp(node, node.ScrollTop);
            area = new LayoutRect(inner.X, inner.Y - node.ScrollTop, inner.Width, Math.Max(inner.Height, content));
        }

        if (node.Kind == NodeKind.Slides)
        {
            ArrangeSlides(node, area);
            return;
        }

        if (shown.Count == 0)
        {
            return;
        }

        switch (node.Layout)
        {
            case FlowLayout.Row when node.Wrap:
                ArrangeLines(node, shown, area);
                break;
            case FlowLayout.Row:
                ArrangeRow(node, shown, area);
                break;
            case FlowLayout.Grid:
                ArrangeGrid(node, shown, area);
                break;
            case FlowLayout.Absolute:
                foreach (Node child in shown)
                {
                    (int x, int y) = child.At ?? (0, 0);
                    int width = Natural(child).Width;
                    Arrange(child, new LayoutRect(area.X + x, area.Y + y, width, HeightFor(child, width)));
                }

                break;
            case FlowLayout.Column when node.Tail:
                ArrangeTail(node, shown, area);
                break;
            default:
                ArrangeColumn(node, shown, area);
                break;
        }
    }

    /// <summary>
    /// Tells the size a component would like: its fixed sides, else what it holds and its padding,
    /// within its least and most size, and its margin around that.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Its width and height, its margin included.</returns>
    public (int Width, int Height) Natural(Node node)
    {
        if (_natural.TryGetValue(node, out (int, int) known))
        {
            return known;
        }

        (int width, int height) = ContentSize(node);
        if (node.KeepsAspect)
        {
            (width, height) = AspectContent(node, width, height);
        }

        int own = node.FixedWidth ?? width + node.Padding.Horizontal;
        if (node.Centered && node.FixedWidth is null)
        {
            own = CenteredWidth(node, own);
        }

        var size = (ClampWidth(node, own) + node.Margin.Horizontal,
                    ClampHeight(node, node.FixedHeight ?? height + node.Padding.Vertical) + node.Margin.Vertical);
        _natural[node] = size;
        return size;
    }

    /// <summary>
    /// Tells how high a component is when it gets a width: its fixed height, else what it holds
    /// laid out in that width and its padding, within its least and most height, and its margin
    /// around that.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">Its width, its margin included.</param>
    /// <returns>Its height, its margin included.</returns>
    public int HeightFor(Node node, int width)
    {
        if (node.FixedHeight is int fixedHeight)
        {
            return ClampHeight(node, fixedHeight) + node.Margin.Vertical;
        }

        if (_heights.TryGetValue((node, width), out int known))
        {
            return known;
        }

        int content = ContentHeightIn(node, InnerWidth(node, width));
        int height = ClampHeight(node, Math.Max(content + node.Padding.Vertical, node.Steady ? node.SteadyHeight : 0)) + node.Margin.Vertical;
        _heights[(node, width)] = height;
        return height;
    }

    /// <summary>
    /// Tells the size what a component holds would like, without its padding: what the scripts
    /// measured, else its own or that of what it holds.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The width and height.</returns>
    private (int Width, int Height) ContentSize(Node node)
    {
        List<Node> shown = Shown(node);
        (int width, int height) = shown.Count == 0 ? LeafNatural(node) : ContentNatural(node, shown);
        return (node.MeasuredWidth ?? width, node.MeasuredHeight ?? height);
    }

    /// <summary>
    /// Tells how high what a component holds is in a width, without its padding.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="inner">The width inside its padding.</param>
    /// <returns>The pixels.</returns>
    private int ContentHeightIn(Node node, int inner)
    {
        if (AspectHeight(node, inner) is int kept)
        {
            return kept;
        }

        List<Node> shown = Shown(node);
        return node.MeasuredHeight ?? (shown.Count == 0 ? LeafHeight(node, inner) : ContentHeight(node, shown, inner));
    }

    /// <summary>
    /// Tells how high what a component that keeps its proportions holds is in a width: the height it
    /// measured scaled as the width scales its measured width.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="inner">The width inside its padding.</param>
    /// <returns>The pixels; null for a component that keeps no proportions or measured nothing.</returns>
    private static int? AspectHeight(Node node, int inner) =>
        node.KeepsAspect && node.MeasuredWidth is int width && width > 0 && node.MeasuredHeight is int height
            ? (int)Math.Round((double)inner * height / width, MidpointRounding.AwayFromZero)
            : null;

    /// <summary>
    /// Tells the size what a component that keeps its proportions holds would like: with only its
    /// width fixed as high as that width lets it be, with only its height fixed as wide as that
    /// height lets it be, else as measured.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">The width it measured.</param>
    /// <param name="height">The height it measured.</param>
    /// <returns>The width and height, without its padding.</returns>
    private static (int Width, int Height) AspectContent(Node node, int width, int height)
    {
        if (node.FixedWidth is int fixedWidth && node.FixedHeight is null)
        {
            return (width, AspectHeight(node, Math.Max(fixedWidth - node.Padding.Horizontal, 0)) ?? height);
        }

        if (node.FixedHeight is int fixedHeight && node.FixedWidth is null && height > 0)
        {
            return ((int)Math.Round((double)Math.Max(fixedHeight - node.Padding.Vertical, 0) * width / height, MidpointRounding.AwayFromZero), height);
        }

        return (width, height);
    }

    /// <summary>
    /// Tells the width what a component holds gets in its width: inside its margin and its padding,
    /// less what of its padding gives way.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">Its width, its margin included.</param>
    /// <returns>The pixels.</returns>
    private int InnerWidth(Node node, int width)
    {
        int own = width - node.Margin.Horizontal;
        return Math.Max(own - node.Padding.Horizontal + CutAcross(node, own), 0);
    }

    /// <summary>
    /// Tells how much of a component's padding gives way across a width: what what it holds lacks of
    /// the room inside its padding, at most what its padding lets give way.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">Its width inside its margin.</param>
    /// <returns>The pixels of its left and right together.</returns>
    private int CutAcross(Node node, int width) =>
        node.PaddingGives.Horizontal == 0 ? 0 : Math.Clamp(ContentSize(node).Width + node.Padding.Horizontal - width, 0, node.PaddingGives.Horizontal);

    /// <summary>
    /// Tells how much of each side of a component's padding gives way at its place, on each axis
    /// what what it holds lacks of the room inside its padding, shared by what each side lets give.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="rect">Its place inside its margin.</param>
    /// <returns>The pixels of each side.</returns>
    private Insets PaddingCut(Node node, LayoutRect rect)
    {
        Insets gives = node.PaddingGives;
        if (gives == default)
        {
            return default;
        }

        int across = CutAcross(node, rect.Width);
        int needed = gives.Vertical == 0 ? 0 : ContentHeightIn(node, Math.Max(rect.Width - node.Padding.Horizontal + across, 0)) + node.Padding.Vertical;
        int down = Math.Clamp(needed - rect.Height, 0, gives.Vertical);
        int left = gives.Horizontal == 0 ? 0 : across * gives.Left / gives.Horizontal;
        int top = gives.Vertical == 0 ? 0 : down * gives.Top / gives.Vertical;
        return new Insets(top, across - left, down - top, left);
    }

    /// <summary>
    /// Keeps a width within a component's least and most width, the most winning.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">The width.</param>
    /// <returns>The width kept.</returns>
    private static int ClampWidth(Node node, int width) => Math.Min(Math.Max(width, node.MinWidth), node.MaxWidth ?? int.MaxValue);

    /// <summary>
    /// Keeps a height within a component's least and most height, the most winning; a root that
    /// gives room is never raised to its least height, which is only what it shrinks to in a full zone.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="height">The height.</param>
    /// <returns>The height kept.</returns>
    private static int ClampHeight(Node node, int height) => Math.Min(node.GivesRoom ? height : Math.Max(height, node.MinHeight), node.MaxHeight ?? int.MaxValue);

    /// <summary>
    /// Tells the width a centered part would like: the narrowest of its widths that holds what it
    /// holds, else its most width; what it holds where it has neither.
    /// </summary>
    /// <param name="node">The part.</param>
    /// <param name="content">The width of what it holds, with its padding.</param>
    /// <returns>The width.</returns>
    private static int CenteredWidth(Node node, int content)
    {
        if (node.Widths is { } widths)
        {
            foreach (int each in widths)
            {
                if (each >= content)
                {
                    return each;
                }
            }

            return content;
        }

        return node.MaxWidth ?? content;
    }

    /// <summary>
    /// Tells how wide a centered part is in a room: the room up to its most width, or the largest of
    /// its widths that fits, the room itself where none does.
    /// </summary>
    /// <param name="node">The part.</param>
    /// <param name="room">The room, without its margin.</param>
    /// <returns>The width.</returns>
    private static int CenteredIn(Node node, int room)
    {
        int fitted = room;
        foreach (int each in node.Widths ?? [])
        {
            fitted = each <= room ? each : fitted;
        }

        return fitted;
    }

    /// <summary>
    /// Keeps an outer width, its margin included, within a component's least and most width.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">The width, its margin included.</param>
    /// <returns>The width kept, its margin included.</returns>
    private static int OuterWidth(Node node, int width) => ClampWidth(node, width - node.Margin.Horizontal) + node.Margin.Horizontal;

    /// <summary>
    /// Keeps an outer height, its margin included, within a component's least and most height.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="height">The height, its margin included.</param>
    /// <returns>The height kept, its margin included.</returns>
    private static int OuterHeight(Node node, int height) => ClampHeight(node, height - node.Margin.Vertical) + node.Margin.Vertical;

    /// <summary>
    /// Lists the children shown in its layout, in their order, leaving out those over its corner; for
    /// a part with copies the copy that stands for it as its root measures one, while the part itself
    /// shows.
    /// </summary>
    /// <param name="node">The parent.</param>
    /// <returns>The children shown.</returns>
    private static List<Node> Shown(Node node) =>
        node.Measures && node.CopyMeasured > 0 && node.Children[0].Visible ? [node.Children[node.CopyMeasured]] : node.Children.FindAll(child => child.Visible && !child.Corner);

    /// <summary>
    /// Tells how far a stack's children stand apart in all, with nothing at either end.
    /// </summary>
    /// <param name="node">The stack.</param>
    /// <param name="count">How many children it shows.</param>
    /// <returns>The pixels.</returns>
    private static int Gaps(Node node, int count) => node.Gap * Math.Max(count - 1, 0);

    /// <summary>
    /// Places a child across a stack.
    /// </summary>
    /// <param name="align">Where the child sits.</param>
    /// <param name="room">The stack's breadth.</param>
    /// <param name="size">The child's breadth.</param>
    /// <returns>The child's offset.</returns>
    private static int Across(FlowAlign align, int room, int size) => align switch
    {
        FlowAlign.Center => (room - size) / 2,
        FlowAlign.End => room - size,
        _ => 0,
    };

    /// <summary>
    /// Tells where a child sits across a column: in the middle when it is centered, else by its align.
    /// </summary>
    /// <param name="child">The child.</param>
    /// <returns>Where it sits.</returns>
    private static FlowAlign AlignAcross(Node child) => child.Centered ? FlowAlign.Center : child.Align;

    /// <summary>
    /// Shares out the room a stack leaves over among the children that grow, by their shares, the
    /// rest of the division going to the last of them.
    /// </summary>
    /// <param name="children">The children.</param>
    /// <param name="lengths">Their lengths along the stack, grown in place.</param>
    /// <param name="free">The room left over.</param>
    /// <param name="most">Each child's most length along the stack.</param>
    /// <param name="grow">Each child's share.</param>
    /// <returns>Whether any child grew.</returns>
    private static bool Share(List<Node> children, int[] lengths, int free, Func<Node, int, int> most, Func<Node, int> grow)
    {
        int shares = 0;
        int last = -1;
        for (int index = 0; index < children.Count; index++)
        {
            shares += grow(children[index]);
            last = grow(children[index]) > 0 ? index : last;
        }

        if (free <= 0 || shares == 0)
        {
            return false;
        }

        int given = 0;
        for (int index = 0; index < children.Count; index++)
        {
            int share = index == last ? free - given : free * grow(children[index]) / shares;
            given += share;
            lengths[index] = most(children[index], lengths[index] + share);
        }

        return true;
    }

    /// <summary>
    /// Takes the room a stack runs short of back from the children that grow or shrink and have no
    /// fixed length, each by the share of what it can give, none below its least length.
    /// </summary>
    /// <remarks>
    /// Without it a growing child as long as its content, such as a scrolling box or a wrapped text,
    /// would push the stack past its parent instead of scrolling or wrapping in the room left.
    /// </remarks>
    /// <param name="children">The children.</param>
    /// <param name="lengths">Their lengths along the stack, shrunk in place.</param>
    /// <param name="over">How far the stack runs past its room.</param>
    /// <param name="least">Each child's least length, null for one that keeps its length.</param>
    /// <param name="grow">Each child's share of the room left over.</param>
    /// <returns>The room taken back.</returns>
    private static int Shrink(List<Node> children, int[] lengths, int over, Func<Node, int?> least, Func<Node, int> grow)
    {
        var give = new int[children.Count];
        int room = 0;
        int last = -1;
        for (int index = 0; index < children.Count; index++)
        {
            if ((grow(children[index]) > 0 || children[index].Shrinks) && least(children[index]) is int floor)
            {
                give[index] = Math.Max(lengths[index] - floor, 0);
                room += give[index];
                last = give[index] > 0 ? index : last;
            }
        }

        if (over <= 0 || room == 0)
        {
            return 0;
        }

        int taken = Math.Min(over, room);
        int given = 0;
        for (int index = 0; index <= last; index++)
        {
            int share = index == last ? taken - given : (int)((long)taken * give[index] / room);
            given += share;
            lengths[index] -= share;
        }

        return taken;
    }

    /// <summary>
    /// Tells where a stack's first child starts and how much room goes between two, by its justify.
    /// </summary>
    /// <param name="node">The stack.</param>
    /// <param name="count">How many children it shows.</param>
    /// <param name="free">The room left over.</param>
    /// <returns>The first child's offset and the room between two.</returns>
    private static (int Start, int Between) Justified(Node node, int count, int free)
    {
        free = Math.Max(free, 0);
        return node.Justify switch
        {
            FlowJustify.Center => (free / 2, node.Gap),
            FlowJustify.End => (free, node.Gap),
            FlowJustify.Between when count > 1 => (0, node.Gap + free / (count - 1)),
            _ => (0, node.Gap),
        };
    }

    /// <summary>
    /// Measures what a component with no children shows: its text, or its rows.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Its content's width and height.</returns>
    private (int Width, int Height) LeafNatural(Node node)
    {
        if (node.Text is not null)
        {
            return (TextWidth(node), node.RowHeight * TextLines(node, null));
        }

        return (0, node.RowLines * node.RowHeight);
    }

    /// <summary>
    /// Measures how high what a component with no children shows is in a width.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="inner">The width inside its padding.</param>
    /// <returns>The height.</returns>
    private int LeafHeight(Node node, int inner) =>
        node.Text is not null ? node.RowHeight * TextLines(node, node.Wrap ? inner : null) : node.RowLines * node.RowHeight;

    /// <summary>
    /// Measures a component's text on one line, or its widest line when it has the game's escape codes.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The width, 0 in a font never defined.</returns>
    private int TextWidth(Node node)
    {
        if (Glyphs(node) is not { } glyphs)
        {
            return 0;
        }

        if (!node.Escapes)
        {
            return TextLayout.Width(glyphs, CodePoints.Of(node.Text!));
        }

        int widest = 0;
        foreach (TextLine line in Escapes.Lines(glyphs, node.Text!, null))
        {
            widest = Math.Max(widest, line.Width);
        }

        return widest;
    }

    /// <summary>
    /// Counts a component's text lines.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">The width its text wraps at, null for none.</param>
    /// <returns>The lines, 1 in a font never defined, no more than it keeps.</returns>
    private int TextLines(Node node, int? width)
    {
        int lines = AllTextLines(node, width);
        return node.MostLines switch
        {
            < 0 => 1,
            > 0 => Math.Min(lines, node.MostLines),
            _ => lines,
        };
    }

    /// <summary>
    /// Counts every line of a component's text.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="width">The width its text wraps at, null for none.</param>
    /// <returns>The lines, 1 in a font never defined.</returns>
    private int AllTextLines(Node node, int? width)
    {
        if (Glyphs(node) is not { } glyphs)
        {
            return 1;
        }

        if (node.Escapes)
        {
            return Escapes.Lines(glyphs, node.Text!, width).Count;
        }

        return width is int wraps ? TextLayout.Wrap(glyphs, node.Text!, wraps).Count : 1;
    }

    /// <summary>
    /// Finds the font a component's text is measured in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The font, null for none.</returns>
    private FontGlyphs? Glyphs(Node node) => node.Font is int key ? _text?.Find(key) : null;

    /// <summary>
    /// Measures what a container holds as it would like it.
    /// </summary>
    /// <param name="node">The container.</param>
    /// <param name="shown">Its children shown.</param>
    /// <returns>The content's width and height.</returns>
    private (int Width, int Height) ContentNatural(Node node, List<Node> shown)
    {
        int width = 0;
        int height = 0;
        if (node.Kind == NodeKind.Slides)
        {
            foreach (Node page in shown)
            {
                width = Math.Max(width, Natural(page).Width);
                height = Math.Max(height, Natural(page).Height);
            }

            return (width * node.PagesShown + Gaps(node, node.PagesShown), height);
        }

        switch (node.Layout)
        {
            case FlowLayout.Row:
                foreach (Node child in shown)
                {
                    width += Natural(child).Width;
                    height = Math.Max(height, Natural(child).Height);
                }

                return (width + Gaps(node, shown.Count), height);
            case FlowLayout.Grid:
                int[] columns = GridColumns(node, shown, null);
                foreach (List<Node> row in GridRows(node, shown))
                {
                    int tallest = 0;
                    foreach (Node cell in row)
                    {
                        tallest = Math.Max(tallest, Natural(cell).Height);
                    }

                    height += tallest;
                }

                foreach (int column in columns)
                {
                    width += column;
                }

                return (width + Gaps(node, columns.Length), height + Gaps(node, GridRows(node, shown).Count));
            case FlowLayout.Absolute:
                foreach (Node child in shown)
                {
                    (int x, int y) = child.At ?? (0, 0);
                    width = Math.Max(width, x + Natural(child).Width);
                    height = Math.Max(height, y + Natural(child).Height);
                }

                return (width, height);
            default:
                foreach (Node child in shown)
                {
                    width = Math.Max(width, Natural(child).Width);
                    height += Natural(child).Height;
                }

                return (width, height + Gaps(node, shown.Count));
        }
    }

    /// <summary>
    /// Measures how high what a container holds is in a width.
    /// </summary>
    /// <param name="node">The container.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="inner">The width inside its padding.</param>
    /// <returns>The content's height.</returns>
    private int ContentHeight(Node node, List<Node> shown, int inner)
    {
        int height = 0;
        if (node.Kind == NodeKind.Slides)
        {
            foreach (Node page in shown)
            {
                height = Math.Max(height, HeightFor(page, PageWidth(node, inner)));
            }

            return height;
        }

        switch (node.Layout)
        {
            case FlowLayout.Row when node.Wrap:
                List<List<Node>> lines = Lines(node, shown, inner);
                foreach (List<Node> line in lines)
                {
                    height += LineHeight(line);
                }

                return height + Gaps(node, lines.Count);
            case FlowLayout.Row:
                int[] widths = RowWidths(node, shown, inner);
                for (int index = 0; index < shown.Count; index++)
                {
                    height = Math.Max(height, HeightFor(shown[index], widths[index]));
                }

                return height;
            case FlowLayout.Grid:
                int[] columns = GridColumns(node, shown, inner);
                List<List<Node>> rows = GridRows(node, shown);
                foreach (List<Node> row in rows)
                {
                    height += GridRowHeight(node, row, columns);
                }

                return height + Gaps(node, rows.Count);
            case FlowLayout.Absolute:
                foreach (Node child in shown)
                {
                    int y = child.At?.Y ?? 0;
                    height = Math.Max(height, y + HeightFor(child, Natural(child).Width));
                }

                return height;
            default:
                foreach (Node child in shown)
                {
                    height += HeightFor(child, CrossWidth(child, inner));
                }

                return height + Gaps(node, shown.Count);
        }
    }

    /// <summary>
    /// Tells how wide a child of a column is: its fixed width, the column's width when it
    /// stretches, a centered child's width in it, else its own width up to the column's.
    /// </summary>
    /// <param name="child">The child.</param>
    /// <param name="inner">The column's width.</param>
    /// <returns>The child's width.</returns>
    private int CrossWidth(Node child, int inner)
    {
        if (child.FixedWidth is not null)
        {
            return Natural(child).Width;
        }

        if (child.Centered)
        {
            return OuterWidth(child, CenteredIn(child, inner - child.Margin.Horizontal) + child.Margin.Horizontal);
        }

        return OuterWidth(child, child.Align == FlowAlign.Stretch ? inner : Math.Min(Natural(child).Width, inner));
    }

    /// <summary>
    /// Tells how wide each child of a row is: its own width, grown by its share of the room left, or
    /// shrunk when the row runs out of room.
    /// </summary>
    /// <param name="node">The row.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="inner">The row's width.</param>
    /// <returns>The widths.</returns>
    private int[] RowWidths(Node node, List<Node> shown, int inner)
    {
        var widths = new int[shown.Count];
        int used = Gaps(node, shown.Count);
        for (int index = 0; index < shown.Count; index++)
        {
            widths[index] = Natural(shown[index]).Width;
            used += widths[index];
        }

        if (!Share(shown, widths, inner - used, OuterWidth, child => child.Grow))
        {
            Shrink(shown, widths, used - inner, child => child.FixedWidth is null ? OuterWidth(child, 0) : null, child => child.Grow);
        }

        return widths;
    }

    /// <summary>
    /// Lays out a column that keeps its newest parts: from its bottom up, each part as high as it is
    /// in the column's width; a label the room runs out at keeps the whole lines that fit, any other
    /// part there is left without room, as are the parts above it.
    /// </summary>
    /// <remarks>
    /// A row given part of its height placed its texts above the column's top.
    /// </remarks>
    /// <param name="node">The column.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeTail(Node node, List<Node> shown, LayoutRect area)
    {
        int y = area.Y + area.Height;
        for (int index = shown.Count - 1; index >= 0; index--)
        {
            Node child = shown[index];
            int width = CrossWidth(child, area.Width);
            int whole = HeightFor(child, width);
            int height = Math.Min(whole, Math.Max(y - area.Y, 0));
            if (height < whole)
            {
                int lines = child.Kind == NodeKind.Label ? Math.Max(height - child.Margin.Vertical, 0) / Math.Max(child.RowHeight, 1) : 0;
                height = lines > 0 ? lines * child.RowHeight + child.Margin.Vertical : 0;
            }

            y -= height;
            Arrange(child, new LayoutRect(area.X + Across(AlignAcross(child), area.Width, width), y, width, height));
            y -= node.Gap;
        }
    }

    /// <summary>
    /// Lays out a column: each child under the one before, a steady one as high as its tallest
    /// content so far and one with a share no higher than that share of the column, the room left
    /// shared among those that grow, or placed by the justify when none grows.
    /// </summary>
    /// <remarks>
    /// The room a list of whole rows leaves stays right under it, so the parts after it keep to the
    /// column's bottom edge, and a plain stack that ends with such a list ends where the list does.
    /// </remarks>
    /// <param name="node">The column.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeColumn(Node node, List<Node> shown, LayoutRect area)
    {
        var widths = new int[shown.Count];
        var heights = new int[shown.Count];
        int used = Gaps(node, shown.Count);
        for (int index = 0; index < shown.Count; index++)
        {
            Node child = shown[index];
            widths[index] = CrossWidth(child, area.Width);
            heights[index] = HeightFor(child, widths[index]);
            if (child.Steady)
            {
                child.SteadyHeight = Math.Max(child.SteadyHeight, heights[index] - child.Margin.Vertical);
            }

            if (child.MaxShare is int share)
            {
                heights[index] = Math.Min(heights[index], Math.Max(area.Height * share / 100, LeastHeight(child, widths[index])));
            }

            used += heights[index];
        }

        bool grew = Share(shown, heights, area.Height - used, OuterHeight, GrowInColumn);
        if (!grew)
        {
            used -= Shrink(shown, heights, used - area.Height, child => child.FixedHeight is null ? LeastHeight(child, CrossWidth(child, area.Width)) : null, GrowInColumn);
        }

        (int start, int between) = grew ? (0, node.Gap) : Justified(node, shown.Count, area.Height - used);
        int y = area.Y + start;
        int left = 0;
        for (int index = 0; index < shown.Count; index++)
        {
            Node child = shown[index];
            int x = area.X + Across(AlignAcross(child), area.Width, widths[index]);
            Arrange(child, new LayoutRect(x, y, widths[index], heights[index]));
            int kept = child.Rect is { } placed ? placed.Height + child.Margin.Vertical : heights[index];
            left = heights[index] - Math.Min(kept, heights[index]);
            y += heights[index] + between;
        }

        if (left > 0 && node.Kind == NodeKind.Stack && !node.IsRoot && node.Rect is LayoutRect own)
        {
            node.Rect = own with { Height = own.Height - left };
        }
    }

    /// <summary>
    /// Tells the share of a column's free room a child takes: its own grow, else 1 for a column of no
    /// height of its own that holds a part taking such a share, so a part that fills takes the room
    /// through the plain columns it lies in, such as the page of a tab.
    /// </summary>
    /// <param name="child">The child.</param>
    /// <returns>The share, 0 for none.</returns>
    private static int GrowInColumn(Node child)
    {
        if (child.Grow > 0)
        {
            return child.Grow;
        }

        if (child.FixedHeight is not null || child.MeasuredHeight is not null || child.Scroll || child.Tail || child.Kind == NodeKind.Slides ||
            child.Layout != FlowLayout.Column)
        {
            return 0;
        }

        foreach (Node part in child.Children)
        {
            if (part.Visible && GrowInColumn(part) > 0)
            {
                return 1;
            }
        }

        return 0;
    }

    /// <summary>
    /// Tells how high a component is at least once it gave back all the room it can: a leaf, a
    /// scrolling box, a slides or parts at places of their own down to its least height; a column or
    /// a row of parts no lower than its parts that cannot give room back, each of the others at its
    /// own least.
    /// </summary>
    /// <remarks>
    /// Shrinking a container below that would draw what it holds over the parts after it.
    /// </remarks>
    /// <param name="node">The component.</param>
    /// <param name="width">Its width, its margin included.</param>
    /// <returns>The height, its margin included.</returns>
    private int LeastHeight(Node node, int width)
    {
        if (node.FixedHeight is int fixedHeight)
        {
            return ClampHeight(node, fixedHeight) + node.Margin.Vertical;
        }

        List<Node> shown = Shown(node);
        bool stacks = node.Layout == FlowLayout.Column || (node.Layout == FlowLayout.Row && !node.Wrap);
        if (shown.Count == 0 || node.Scroll || node.Kind == NodeKind.Slides || node.MeasuredHeight is not null || !stacks)
        {
            return ClampHeight(node, 0) + node.Margin.Vertical;
        }

        int inner = InnerWidth(node, width);
        int content = 0;
        if (node.Layout == FlowLayout.Row)
        {
            int[] widths = RowWidths(node, shown, inner);
            for (int index = 0; index < shown.Count; index++)
            {
                content = Math.Max(content, PartLeast(shown[index], widths[index]));
            }
        }
        else
        {
            foreach (Node child in shown)
            {
                content += PartLeast(child, CrossWidth(child, inner));
            }

            content += Gaps(node, shown.Count);
        }

        return ClampHeight(node, content + node.Padding.Vertical - node.PaddingGives.Vertical) + node.Margin.Vertical;
    }

    /// <summary>
    /// Tells how high a part of a column or a row is at least: its own least when it gives room
    /// back, as a part that grows or shrinks does and a plain column a part that fills takes the room
    /// through, else its height.
    /// </summary>
    /// <remarks>
    /// Taking room back through the same plain columns that pass the free room on keeps a list that
    /// fills the page of a tab from pushing the parts under the tabs off its window.
    /// </remarks>
    /// <param name="part">The part.</param>
    /// <param name="width">Its width.</param>
    /// <returns>The height.</returns>
    private int PartLeast(Node part, int width) =>
        part.FixedHeight is null && (GrowInColumn(part) > 0 || part.Shrinks) ? LeastHeight(part, width) : HeightFor(part, width);

    /// <summary>
    /// Tells how wide each page of a slides is: its width shared by the pages it shows.
    /// </summary>
    /// <param name="node">The slides.</param>
    /// <param name="inner">Its width.</param>
    /// <returns>The pixels.</returns>
    private static int PageWidth(Node node, int inner) => Math.Max((inner - Gaps(node, node.PagesShown)) / node.PagesShown, 0);

    /// <summary>
    /// Lays out the pages of a slides side by side, each as wide as it shows them and as high as it,
    /// the first at its left; the scripts shift the strip to the pages in view.
    /// </summary>
    /// <remarks>
    /// A page keeps its place whichever pages show, so a slide moves what is drawn and lays out nothing.
    /// </remarks>
    /// <param name="node">The slides.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeSlides(Node node, LayoutRect area)
    {
        int width = PageWidth(node, area.Width);
        for (int index = 0; index < node.Children.Count; index++)
        {
            Node page = node.Children[index];
            if (page.Visible)
            {
                Arrange(page, new LayoutRect(area.X + index * (width + node.Gap), area.Y, width, area.Height));
            }
        }
    }

    /// <summary>
    /// Lays out a row: each child after the one before, as high as the row when it stretches.
    /// </summary>
    /// <param name="node">The row.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeRow(Node node, List<Node> shown, LayoutRect area)
    {
        int[] widths = RowWidths(node, shown, area.Width);
        int used = Gaps(node, shown.Count);
        bool grew = false;
        foreach (int width in widths)
        {
            used += width;
        }

        foreach (Node child in shown)
        {
            grew |= child.Grow > 0;
        }

        (int start, int between) = grew ? (0, node.Gap) : Justified(node, shown.Count, area.Width - used);
        int x = area.X + start;
        for (int index = 0; index < shown.Count; index++)
        {
            Node child = shown[index];
            int height = HeightIn(child, widths[index], area.Height);
            Arrange(child, new LayoutRect(x, area.Y + Across(child.Align, area.Height, height), widths[index], height));
            x += widths[index] + between;
        }
    }

    /// <summary>
    /// Tells how high a child of a row or a line is: the row's height when it stretches and has no
    /// fixed height, else its own height for its width.
    /// </summary>
    /// <param name="child">The child.</param>
    /// <param name="width">Its width.</param>
    /// <param name="room">The row's height.</param>
    /// <returns>Its height.</returns>
    private int HeightIn(Node child, int width, int room) =>
        child.Align == FlowAlign.Stretch && child.FixedHeight is null ? OuterHeight(child, room) : HeightFor(child, width);

    /// <summary>
    /// Breaks a wrapping row's children into lines that fit its width, at least one child a line.
    /// </summary>
    /// <param name="node">The row.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="inner">The row's width.</param>
    /// <returns>The lines.</returns>
    private List<List<Node>> Lines(Node node, List<Node> shown, int inner)
    {
        var lines = new List<List<Node>> { new() };
        int used = 0;
        foreach (Node child in shown)
        {
            int width = Natural(child).Width;
            List<Node> line = lines[^1];
            if (line.Count > 0 && used + node.Gap + width > inner)
            {
                lines.Add([]);
                line = lines[^1];
                used = 0;
            }

            used += (line.Count > 0 ? node.Gap : 0) + width;
            line.Add(child);
        }

        return lines;
    }

    /// <summary>
    /// Tells how high a line of a wrapping row is: its tallest child.
    /// </summary>
    /// <param name="line">The line's children.</param>
    /// <returns>The height.</returns>
    private int LineHeight(List<Node> line)
    {
        int height = 0;
        foreach (Node child in line)
        {
            height = Math.Max(height, HeightFor(child, Natural(child).Width));
        }

        return height;
    }

    /// <summary>
    /// Lays out a wrapping row line by line, each line placed by the justify.
    /// </summary>
    /// <param name="node">The row.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeLines(Node node, List<Node> shown, LayoutRect area)
    {
        int y = area.Y;
        foreach (List<Node> line in Lines(node, shown, area.Width))
        {
            int height = LineHeight(line);
            int used = Gaps(node, line.Count);
            foreach (Node child in line)
            {
                used += Natural(child).Width;
            }

            (int start, int between) = Justified(node, line.Count, area.Width - used);
            int x = area.X + start;
            foreach (Node child in line)
            {
                int width = Natural(child).Width;
                int childHeight = HeightIn(child, width, height);
                Arrange(child, new LayoutRect(x, y + Across(child.Align, height, childHeight), width, childHeight));
                x += width + between;
            }

            y += height + node.Gap;
        }
    }

    /// <summary>
    /// Splits a grid's children into its rows: each row takes children while their spans fit its
    /// columns.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="shown">Its children shown.</param>
    /// <returns>The rows.</returns>
    internal static List<List<Node>> GridRows(Node node, List<Node> shown)
    {
        int count = node.Columns.Length;
        var rows = new List<List<Node>>();
        int used = count;
        foreach (Node child in shown)
        {
            int span = SpanIn(node, child);
            if (used + span > count)
            {
                rows.Add([]);
                used = 0;
            }

            rows[^1].Add(child);
            used += span;
        }

        return rows;
    }

    /// <summary>
    /// Tells how many of a grid's columns a child spans, at most all of them.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="child">The child.</param>
    /// <returns>The columns.</returns>
    internal static int SpanIn(Node grid, Node child) => Math.Min(child.Span, grid.Columns.Length);

    /// <summary>
    /// Finds the cell of a grid's row that spans a column.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="row">The row's children.</param>
    /// <param name="column">The column, from 0.</param>
    /// <returns>The cell, null when the row ends before the column.</returns>
    internal static Node? CellAt(Node grid, List<Node> row, int column)
    {
        int end = 0;
        foreach (Node cell in row)
        {
            end += SpanIn(grid, cell);
            if (column < end)
            {
                return cell;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells the column a cell of a grid's row starts at.
    /// </summary>
    /// <param name="grid">The grid.</param>
    /// <param name="row">The row's children.</param>
    /// <param name="cell">The cell.</param>
    /// <returns>The column, from 0.</returns>
    internal static int StartOf(Node grid, List<Node> row, Node cell)
    {
        int start = 0;
        for (int index = 0; index < row.Count && row[index] != cell; index++)
        {
            start += SpanIn(grid, row[index]);
        }

        return start;
    }

    /// <summary>
    /// Tells how wide a cell of a grid is: the columns it spans and the gaps between them.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="columns">The column widths.</param>
    /// <param name="start">The first column it spans.</param>
    /// <param name="span">How many columns it spans.</param>
    /// <returns>The width.</returns>
    private static int CellWidth(Node node, int[] columns, int start, int span)
    {
        int width = Gaps(node, span);
        for (int column = start; column < start + span; column++)
        {
            width += columns[column];
        }

        return width;
    }

    /// <summary>
    /// Tells a grid's column widths: the fixed ones, and the others sharing the room left equally,
    /// or as wide as their widest child needs when the grid fits what it holds, a child spanning
    /// several sharing columns needing its width over them.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="inner">The grid's width, null while it fits what it holds.</param>
    /// <returns>The widths.</returns>
    private int[] GridColumns(Node node, List<Node> shown, int? inner)
    {
        FitGrid(node, shown, inner);
        int count = node.Columns.Length;
        int fixedWidth = 0;
        int sharing = 0;
        int widest = 0;
        for (int column = 0; column < count; column++)
        {
            fixedWidth += node.Columns[column] ?? 0;
            sharing += node.Columns[column] is null ? 1 : 0;
        }

        foreach (List<Node> row in GridRows(node, shown))
        {
            int start = 0;
            foreach (Node cell in row)
            {
                int span = SpanIn(node, cell);
                if (Array.TrueForAll(node.Columns[start..(start + span)], width => width is null))
                {
                    widest = Math.Max(widest, (Natural(cell).Width - Gaps(node, span) + span - 1) / span);
                }

                start += span;
            }
        }

        int shared = inner is int width && sharing > 0 ? Math.Max(width - fixedWidth - Gaps(node, count), 0) / sharing : widest;
        var widths = new int[count];
        for (int column = 0; column < count; column++)
        {
            widths[column] = node.Columns[column] ?? shared;
        }

        return widths;
    }

    /// <summary>
    /// Gives a grid that fits its columns as many equal columns as its widest child fits whole in
    /// its width, up to its most; while it fits what it holds, its most.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="inner">The grid's width, null while it fits what it holds.</param>
    private void FitGrid(Node node, List<Node> shown, int? inner)
    {
        if (node.FitColumns <= 0 || shown.Count == 0)
        {
            return;
        }

        int widest = 1;
        foreach (Node child in shown)
        {
            widest = Math.Max(widest, Natural(child).Width);
        }

        int count = inner is int width ? (width + node.Gap) / (widest + node.Gap) : node.FitColumns;
        node.FitTo(Math.Min(Math.Max(count, 1), Math.Min(node.FitColumns, shown.Count)));
    }

    /// <summary>
    /// Tells how high a row of a grid is: its tallest cell in the width of the columns it spans.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="row">The row's children.</param>
    /// <param name="columns">The column widths.</param>
    /// <returns>The height.</returns>
    private int GridRowHeight(Node node, List<Node> row, int[] columns)
    {
        int height = 0;
        int start = 0;
        foreach (Node cell in row)
        {
            int span = SpanIn(node, cell);
            height = Math.Max(height, HeightFor(cell, CrossWidth(cell, CellWidth(node, columns, start, span))));
            start += span;
        }

        return height;
    }

    /// <summary>
    /// Lays out a grid row by row, each child in the cell of the columns it spans.
    /// </summary>
    /// <param name="node">The grid.</param>
    /// <param name="shown">Its children shown.</param>
    /// <param name="area">Its content's place.</param>
    private void ArrangeGrid(Node node, List<Node> shown, LayoutRect area)
    {
        int[] columns = GridColumns(node, shown, area.Width);
        int y = area.Y;
        foreach (List<Node> row in GridRows(node, shown))
        {
            int height = GridRowHeight(node, row, columns);
            int x = area.X;
            int start = 0;
            foreach (Node child in row)
            {
                int span = SpanIn(node, child);
                int cell = CellWidth(node, columns, start, span);
                int width = CrossWidth(child, cell);
                int childHeight = HeightIn(child, width, height);
                Arrange(child, new LayoutRect(x + Across(child.Align, cell, width), y + Across(child.Align, height, childHeight), width, childHeight));
                x += cell + node.Gap;
                start += span;
            }

            y += height + node.Gap;
        }
    }
}
