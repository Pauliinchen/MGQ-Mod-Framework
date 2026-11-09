//----------------------------------------------------------------
//  HitTest.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Clipped a scrolled box's parts to what is left of its padding
//      Paulinchen  2026-11-07: Took the pointer on a slider
//      Paulinchen  2026-11-05: Took the pointer on a numeric field as on a text field
//      Paulinchen  2026-10-31: Hit a container clicked as one part as a whole
//                            - Let the pointer through a root that takes it only on its parts that take clicks or show a
//                              tooltip, and hit a root drawn shifted where it is drawn
//      Paulinchen  2026-10-29: Let the pointer through a game window where none of its components lie
//                            - Hit a component shifted from its place where it is drawn and passed over inert ones
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// What lies under the pointer: the root and the deepest component in it that takes the pointer,
/// and whether the pointer is on that component's scrollbar.
/// </summary>
/// <param name="Root">The root.</param>
/// <param name="Node">The component, the root itself where none of its children lies.</param>
/// <param name="OnBar">Whether the pointer is on the component's scrollbar.</param>
internal readonly record struct Hit(Node Root, Node Node, bool OnBar);

/// <summary>
/// Finds what lies under the pointer: the topmost root shown there that takes the pointer, then in
/// it the deepest child shown there that takes it, each child clipped to its parent and a
/// scrolling box's children to the inside of the box, a shifted child where it is drawn. Inert
/// children take no pointer. A game window a mod put components on takes the pointer only on them,
/// so the game's own rows under it keep the mouse, and a root with its mouse on its parts only on
/// those that take clicks or show a tooltip.
/// </summary>
internal static class HitTest
{
    /// <summary>
    /// Finds what lies under a point.
    /// </summary>
    /// <param name="topFirst">The roots shown, topmost first.</param>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>What lies there, null for none.</returns>
    public static Hit? At(IEnumerable<Node> topFirst, int x, int y)
    {
        foreach (Node root in topFirst)
        {
            (int rx, int ry) = root.Offset;
            if (!root.Mouse || root.Rect is not { } rect || !rect.Contains(x - rx, y - ry))
            {
                continue;
            }

            Node? deepest = Deepest(root, rect, x - rx, y - ry);
            if ((deepest is null && root.Kind == NodeKind.Adopted) || (root.MouseParts && !TakesPointer(deepest, root)))
            {
                continue;
            }

            Node node = deepest ?? root;
            (int dx, int dy) = ShiftOf(node);
            return new Hit(root, node, node.Scrolls && Scroll.OnBar(node, x - dx, y - dy));
        }

        return null;
    }

    /// <summary>
    /// Tells how far a component is drawn from its place: its own shift and those of every component
    /// it lies in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The shift.</returns>
    public static (int X, int Y) ShiftOf(Node node)
    {
        int x = 0;
        int y = 0;
        for (Node? step = node; step is not null; step = step.Parent)
        {
            x += step.Offset.X;
            y += step.Offset.Y;
        }

        return (x, y);
    }

    /// <summary>
    /// Tells whether a component or one it lies in, below its root, takes clicks or shows a tooltip.
    /// </summary>
    /// <param name="node">The component, null for none.</param>
    /// <param name="root">Its root.</param>
    /// <returns>Whether one does.</returns>
    private static bool TakesPointer(Node? node, Node root)
    {
        for (Node? step = node; step is not null && step != root; step = step.Parent)
        {
            if (step.Tooltip || step.Clicks || step.TypesText || step.Kind is NodeKind.Button or NodeKind.IconButton or NodeKind.Checkbox or NodeKind.Select or NodeKind.Slider or NodeKind.List or NodeKind.Tabs)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Finds the deepest child under a point, the last drawn first, since it lies on top.
    /// </summary>
    /// <param name="node">The parent.</param>
    /// <param name="clip">Where the parent shows, in the parent's places.</param>
    /// <param name="x">The point's left, in the parent's places.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>The child, null when none lies there or the point is on the parent's scrollbar.</returns>
    private static Node? Deepest(Node node, LayoutRect clip, int x, int y)
    {
        if (node.Scrolls && Scroll.OnBar(node, x, y))
        {
            return null;
        }

        LayoutRect inside = node.Scroll ? Within(clip, node.Room.Inside(node.Rect ?? clip)) : clip;
        for (int index = node.Children.Count - 1; index >= 0; index--)
        {
            Node child = node.Children[index];
            if (!child.Visible || !child.Mouse || child.Inert || child.Rect is not { } rect)
            {
                continue;
            }

            (int dx, int dy) = child.Offset;
            LayoutRect shown = Within(new LayoutRect(inside.X - dx, inside.Y - dy, inside.Width, inside.Height), rect);
            if (shown.Contains(x - dx, y - dy))
            {
                return child.Clickable ? child : Deepest(child, shown, x - dx, y - dy) ?? child;
            }
        }

        return null;
    }

    /// <summary>
    /// Tells where two places overlap.
    /// </summary>
    /// <param name="one">One place.</param>
    /// <param name="other">The other.</param>
    /// <returns>The overlap, empty when they do not.</returns>
    private static LayoutRect Within(LayoutRect one, LayoutRect other)
    {
        int left = Math.Max(one.X, other.X);
        int top = Math.Max(one.Y, other.Y);
        int right = Math.Min(one.X + one.Width, other.X + other.Width);
        int bottom = Math.Min(one.Y + one.Height, other.Y + other.Height);
        return new LayoutRect(left, top, Math.Max(right - left, 0), Math.Max(bottom - top, 0));
    }
}
