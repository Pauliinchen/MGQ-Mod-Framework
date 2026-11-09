//----------------------------------------------------------------
//  Scroll.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Found rows and tracks inside what is left of a list's or a box's padding
//      Paulinchen  2026-11-01: Found where in its cell a point on a list lies
//      Paulinchen  2026-10-30: Kept a heading row in sight over the row under it and left heading rows to no point
//      Paulinchen  2026-10-29: Scrolled a list that shows its rows in columns by its lines, and found the row under a
//                              point in them
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The scrolling of lists and of boxes that scroll what they hold: where they start, the
/// scrollbar's thumb as the scripts draw it (Style.draw_scrollbar), and a list's cursor kept in sight.
/// A list scrolls by lines, a box by pixels; a list of one row a line scrolls by its rows.
/// </summary>
internal static class Scroll
{
    /// <summary>
    /// Rows of a list one notch of the wheel scrolls, as the game's lists with the mouse rule do.
    /// </summary>
    public const int WheelRows = 1;

    /// <summary>
    /// Pixels of a box one notch of the wheel scrolls, one line.
    /// </summary>
    public const int WheelPixels = Node.DefaultRowHeight;

    /// <summary>
    /// Pixels at the right of a scrolling component a press takes the scrollbar in, wider than the
    /// bar the scripts draw so it is easy to hit.
    /// </summary>
    public const int BarGrab = 8;

    /// <summary>
    /// The thumb's least length, Style::SCROLLBAR_THUMB in the scripts.
    /// </summary>
    public const int ThumbLeast = 8;

    /// <summary>
    /// Pixels at the right of a list its rows leave to the scrollbar while it scrolls,
    /// Style::SCROLLBAR_WIDTH and List::BAR_GAP in the scripts.
    /// </summary>
    public const int BarRoom = 8;

    /// <summary>
    /// Keeps where a component starts within what it holds.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="top">Where it would start.</param>
    /// <returns>Where it starts.</returns>
    public static int Clamp(Node node, int top) => Math.Max(Math.Min(top, node.ScrollTotal - node.ScrollShown), 0);

    /// <summary>
    /// Scrolls a component to a start.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="top">Where it would start.</param>
    /// <returns>Whether it moved.</returns>
    public static bool To(Node node, int top)
    {
        int kept = Clamp(node, top);
        if (kept == node.ScrollTop)
        {
            return false;
        }

        node.ScrollTop = kept;
        return true;
    }

    /// <summary>
    /// Tells where a component's scrollbar runs: a list's whole height, a box's inside its padding.
    /// </summary>
    /// <param name="node">The list or box, laid out.</param>
    /// <returns>The track.</returns>
    public static LayoutRect Track(Node node)
    {
        LayoutRect rect = node.Rect ?? default;
        return node.Kind == NodeKind.List ? rect : node.Room.Inside(rect) with { X = rect.X, Width = rect.Width };
    }

    /// <summary>
    /// Tells whether a point lies on a component's scrollbar.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>Whether it does; never while all it holds shows.</returns>
    public static bool OnBar(Node node, int x, int y)
    {
        LayoutRect track = Track(node);
        return node.Overflows && track.Contains(x, y) && x >= track.X + track.Width - BarGrab;
    }

    /// <summary>
    /// Tells where the thumb is, as the scripts draw it.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <returns>The thumb's top on the screen and its length.</returns>
    public static (int Top, int Length) Thumb(Node node)
    {
        LayoutRect track = Track(node);
        int over = node.ScrollTotal - node.ScrollShown;
        int length = Math.Min(Math.Max(track.Height * node.ScrollShown / Math.Max(node.ScrollTotal, 1), ThumbLeast), track.Height);
        int top = over > 0 ? track.Y + (track.Height - length) * Math.Min(Math.Max(node.ScrollTop, 0), over) / over : track.Y;
        return (top, length);
    }

    /// <summary>
    /// Tells where a component starts when its thumb's top is dragged to a place.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="thumbTop">Where the thumb's top is dragged to.</param>
    /// <returns>Where it starts.</returns>
    public static int TopForThumb(Node node, int thumbTop)
    {
        LayoutRect track = Track(node);
        int room = track.Height - Thumb(node).Length;
        if (room <= 0)
        {
            return 0;
        }

        int over = node.ScrollTotal - node.ScrollShown;
        return Clamp(node, (int)Math.Round((double)(thumbTop - track.Y) * over / room, MidpointRounding.AwayFromZero));
    }

    /// <summary>
    /// Scrolls a list so its cursor's line shows, with the heading row right over it in a list of
    /// one row a line.
    /// </summary>
    /// <param name="list">The list.</param>
    public static void ShowCursor(Node list)
    {
        if (list.Cursor < 0)
        {
            return;
        }

        int line = list.Cursor / list.RowCells;
        int top = list.RowCells == 1 && list.HeadingRows.Contains(list.Cursor - 1) ? line - 1 : line;
        if (top < list.ScrollTop)
        {
            To(list, top);
        }
        else if (list.ScrollShown > 0 && line >= list.ScrollTop + list.ScrollShown)
        {
            To(list, line - list.ScrollShown + 1);
        }
    }

    /// <summary>
    /// Moves a list's cursor onto the lines it shows, in the same column, after the list scrolled
    /// away from it.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The row the cursor moves to, null when it stays.</returns>
    public static int? CursorInSight(Node list)
    {
        if (list.Cursor < 0 || list.ScrollShown <= 0)
        {
            return null;
        }

        int line = Math.Min(Math.Max(list.Cursor / list.RowCells, list.ScrollTop), list.ScrollTop + list.ScrollShown - 1);
        int row = Math.Min(line * list.RowCells + list.Cursor % list.RowCells, list.Rows - 1);
        int toward = row < list.Cursor ? 1 : -1;
        row = StopFrom(list, row, toward) ?? StopFrom(list, row, -toward) ?? list.Cursor;
        return row == list.Cursor ? null : row;
    }

    /// <summary>
    /// Tells which row of a list lies under a point: its line by the point's top and, in a list of
    /// several rows a line, its column by the point's left, the room the scrollbar takes left out.
    /// </summary>
    /// <param name="list">The list, laid out.</param>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>The row, null outside the rows and on a heading row.</returns>
    public static int? RowAt(Node list, int x, int y)
    {
        LayoutRect inner = list.Room.Inside(list.Rect ?? default);
        if (y < inner.Y || y >= inner.Y + inner.Height)
        {
            return null;
        }

        int line = list.ScrollTop + (y - inner.Y) / list.RowHeight;
        int width = inner.Width - (list.Overflows ? BarRoom : 0);
        int column = list.RowCells == 1 || width <= 0 ? 0 : Math.Min(Math.Max((x - inner.X) * list.RowCells / width, 0), list.RowCells - 1);
        int row = line * list.RowCells + column;
        return row < list.Rows && !list.HeadingRows.Contains(row) ? row : null;
    }

    /// <summary>
    /// Finds where in its cell a point on a list lies, from the cell's left.
    /// </summary>
    /// <param name="list">The list, laid out.</param>
    /// <param name="x">The point's left.</param>
    /// <returns>The pixels from the left of the cell under the point.</returns>
    public static int XInCell(Node list, int x)
    {
        LayoutRect inner = list.Room.Inside(list.Rect ?? default);
        int width = inner.Width - (list.Overflows ? BarRoom : 0);
        int local = x - inner.X;
        return list.RowCells == 1 || width <= 0 ? local : local - Math.Min(Math.Max(local * list.RowCells / width, 0), list.RowCells - 1) * width / list.RowCells;
    }

    /// <summary>
    /// Finds the first row of a list that takes the cursor, from a row on by a step of rows: the row
    /// itself unless it is a heading.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="row">The row to start at.</param>
    /// <param name="step">The rows to step by, negative up; never 0.</param>
    /// <returns>The row, null when only headings or no rows lie that way.</returns>
    public static int? StopFrom(Node list, int row, int step)
    {
        for (int at = row; at >= 0 && at < list.Rows; at += step)
        {
            if (!list.HeadingRows.Contains(at))
            {
                return at;
            }
        }

        return null;
    }
}
