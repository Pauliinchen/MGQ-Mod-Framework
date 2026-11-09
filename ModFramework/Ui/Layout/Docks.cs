//----------------------------------------------------------------
//  Docks.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Stacked the roots of a named column down from its spot, the newest first
//      Paulinchen  2026-11-05: Laid a root over the left or right edge inside a part, as high as the part, as a drawer
//                              lies over what it opens beside
//      Paulinchen  2026-11-04: Placed the roots in the nine zones of the screen and along its four edges
//                            - Lined a root beside a part up with its left or top, as a popover lines up
//                            - Took the other side of a part only where its own has no room across it
//                            - Ordered the roots of a zone by their order, then the load order of their mods
//                            - Shrank a root that gives room and then hid the roots of the highest order of a
//                              zone that runs past the screen
//                            - Placed a root alone at its zone and beside another part
//      Paulinchen  2026-11-01: Gave an empty top corner the room of the strips docked at the top
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQParadox.ModFramework.Ui.Layout;

/// <summary>
/// The default places of the roots: along an edge of the screen, stacked in one of its nine zones,
/// alone at a zone, or beside another part. Edge docks take the whole length of their edge and
/// leave the rest of the screen to the zones; the parts of a zone stack away from its edge,
/// <see cref="Margin"/> in and <see cref="Gap"/> apart, and never overlap.
/// </summary>
internal static class Docks
{
    /// <summary>
    /// Pixels between the screen's edge and the first root of a zone.
    /// </summary>
    public const int Margin = 8;

    /// <summary>
    /// Pixels between two roots of a zone.
    /// </summary>
    public const int Gap = 4;

    /// <summary>
    /// The zone at the top of the screen, whose strips push the top corners down.
    /// </summary>
    public const string Top = "top";

    /// <summary>
    /// The side that centers a root on another part instead of putting it beside it.
    /// </summary>
    public const string Over = "over";

    /// <summary>
    /// How a root beside a part lines up with it: centered along it, or with its left or top.
    /// </summary>
    public static readonly string[] LineUps = ["center", "start"];

    /// <summary>
    /// The nine zones, row by row from the top left.
    /// </summary>
    public static readonly string[] Names = ["top_left", "top", "top_right", "left", "center", "right", "bottom_left", "bottom", "bottom_right"];

    /// <summary>
    /// The edges a root docks along, in the order they take their room.
    /// </summary>
    public static readonly string[] Edges = ["top", "bottom", "left", "right"];

    /// <summary>
    /// The sides a root lies on beside another part, <see cref="Over"/>, and the left and right
    /// edges inside it, as high as it.
    /// </summary>
    public static readonly string[] Sides = ["top", "bottom", "left", "right", Over, "inside_left", "inside_right"];

    /// <summary>
    /// How the roots of a column line up with its spot across: their left edge, their middle or
    /// their right edge on it.
    /// </summary>
    public static readonly string[] ColumnAligns = ["left", "center", "right"];

    /// <summary>
    /// Tells the column and the row of a zone.
    /// </summary>
    /// <param name="zone">One of <see cref="Names"/>.</param>
    /// <returns>The column and the row, each 0, 1 or 2.</returns>
    public static (int Column, int Row) Cell(string zone)
    {
        int index = Array.IndexOf(Names, zone);
        return index < 0 ? (1, 1) : (index % 3, index / 3);
    }

    /// <summary>
    /// Tells the zone a place belongs to: the third of the screen its middle lies in, each way.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>The zone.</returns>
    public static string ZoneOf(LayoutRect rect, int width, int height)
    {
        int column = Third(rect.X + rect.Width / 2, width);
        int row = Third(rect.Y + rect.Height / 2, height);
        return Names[row * 3 + column];
    }

    /// <summary>
    /// Places a root alone at a zone, <see cref="Margin"/> in from the edges it lies at.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <param name="width">The root's width.</param>
    /// <param name="height">The root's height.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>Its left and top.</returns>
    public static (int X, int Y) Align(string zone, int width, int height, int screenWidth, int screenHeight)
    {
        (int column, int row) = Cell(zone);
        return (Along(column, width, 0, screenWidth), Along(row, height, 0, screenHeight));
    }

    /// <summary>
    /// Places a root beside a part: on its side, touching it and centered along it or lined up with
    /// its left or top, or centered on it for <see cref="Over"/>. Where that side has no room it
    /// takes the other side, if that has room, and it always stays on the screen.
    /// </summary>
    /// <param name="target">Where the part lies.</param>
    /// <param name="width">The root's width.</param>
    /// <param name="height">The root's height.</param>
    /// <param name="side">One of <see cref="Sides"/>.</param>
    /// <param name="flip">Whether it takes the other side where its own has no room.</param>
    /// <param name="start">Whether it lines up with the part's left or top instead of its middle.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>Its place.</returns>
    public static LayoutRect Beside(LayoutRect target, int width, int height, string side, bool flip, bool start, int screenWidth, int screenHeight)
    {
        LayoutRect place = SideOf(target, width, height, side, start);
        if (flip && !Fits(place, side, screenWidth, screenHeight) && Opposite(side) is { } other)
        {
            LayoutRect flipped = SideOf(target, width, height, other, start);
            if (Fits(flipped, other, screenWidth, screenHeight))
            {
                place = flipped;
            }
        }

        return LayoutModel.OnScreen(place, screenWidth, screenHeight);
    }

    /// <summary>
    /// Places the roots of the named columns: in each column the root that opened last at its spot,
    /// every older one below the one before it by that one's height and the column's gap, each lined
    /// up across by the column's align.
    /// </summary>
    /// <param name="members">The roots, each with its column and its size.</param>
    /// <returns>Each root's place in the order given.</returns>
    public static LayoutRect[] Stack(IReadOnlyList<Stacked> members)
    {
        ArgumentNullException.ThrowIfNull(members);
        var places = new LayoutRect[members.Count];
        foreach (IGrouping<string, int> column in Enumerable.Range(0, members.Count).GroupBy(index => members[index].Column.Name, StringComparer.Ordinal))
        {
            int? top = null;
            foreach (int index in column.OrderByDescending(index => members[index].Opened))
            {
                (ColumnPlace place, _, LayoutRect size) = members[index];
                int y = top ?? place.Y;
                int x = place.Align switch
                {
                    "center" => place.X - size.Width / 2,
                    "right" => place.X - size.Width,
                    _ => place.X,
                };
                places[index] = new LayoutRect(x, y, size.Width, size.Height);
                top = y + size.Height + place.Gap;
            }
        }

        return places;
    }

    /// <summary>
    /// Places the roots docked along an edge or stacked in a zone and tells the room each zone
    /// takes. A zone whose stack runs past the screen first shrinks its roots that give room to
    /// their least height, then hides its roots of the highest order until the rest fits.
    /// </summary>
    /// <param name="docked">The roots.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>Each root's place in the order given, which roots hide for want of room, and each
    /// zone's room in pixels from its edge.</returns>
    public static (LayoutRect[] Places, bool[] Crowded, Dictionary<string, int> Rooms) Place(IReadOnlyList<Docked> docked, int width, int height)
    {
        ArgumentNullException.ThrowIfNull(docked);
        var places = new LayoutRect[docked.Count];
        var crowded = new bool[docked.Count];
        var rooms = Names.ToDictionary(name => name, _ => 0, StringComparer.Ordinal);
        int[] order = [.. Enumerable.Range(0, docked.Count).OrderBy(index => docked[index].Order).ThenBy(index => docked[index].LoadOrder).ThenBy(index => docked[index].Opened)];
        LayoutRect area = DockEdges(docked, order, places, new LayoutRect(0, 0, width, height));

        int[] top = Stacked(docked, order, Top);
        Fit(docked, top, places, crowded, area.Height - 2 * Margin);
        int below = Column([.. top.Where(index => !crowded[index])], places, area.Y + Margin, false, each => area.X + (area.Width - each) / 2);
        rooms[Top] = below > area.Y + Margin ? below - Gap : area.Y;
        int cornerTop = below > area.Y + Margin ? below : area.Y + Margin;

        foreach (string zone in Names.Where(name => name != Top))
        {
            int[] stacked = Stacked(docked, order, zone);
            (int column, int row) = Cell(zone);
            int start = row switch { 0 => cornerTop, 1 => area.Y + Margin, _ => area.Y + Margin };
            Fit(docked, stacked, places, crowded, area.Y + area.Height - Margin - start);
            int[] shown = [.. stacked.Where(index => !crowded[index])];
            int length = shown.Sum(index => places[index].Height) + Gap * Math.Max(shown.Length - 1, 0);
            int y = row switch { 0 => cornerTop, 1 => area.Y + (area.Height - length) / 2, _ => area.Y + area.Height - Margin - length };
            Column(shown, places, y, row == 2, each => Along(column, each, area.X, area.Width));
            rooms[zone] = RoomOf(zone, shown, places, area, width, height, rooms[Top]);
        }

        return (places, crowded, rooms);
    }

    /// <summary>
    /// Tells where a root goes along one axis: <see cref="Margin"/> in from the start, in the
    /// middle, or <see cref="Margin"/> in from the end.
    /// </summary>
    /// <param name="cell">0 for the start, 1 for the middle, 2 for the end.</param>
    /// <param name="size">The root's length along the axis.</param>
    /// <param name="start">Where the room starts.</param>
    /// <param name="room">The room's length.</param>
    /// <returns>Where the root starts.</returns>
    private static int Along(int cell, int size, int start, int room) => cell switch
    {
        0 => start + Margin,
        1 => start + (room - size) / 2,
        _ => start + room - Margin - size,
    };

    /// <summary>
    /// Tells which third of a length a point lies in.
    /// </summary>
    /// <param name="point">The point.</param>
    /// <param name="length">The length.</param>
    /// <returns>0, 1 or 2.</returns>
    private static int Third(int point, int length) => point * 3 < length ? 0 : point * 3 < 2 * length ? 1 : 2;

    /// <summary>
    /// Places a root on a side of a part, touching it and centered on it, or inside the part along
    /// its left or right edge, as high as the part.
    /// </summary>
    /// <param name="target">Where the part lies.</param>
    /// <param name="width">The root's width.</param>
    /// <param name="height">The root's height.</param>
    /// <param name="side">The side.</param>
    /// <returns>Its place.</returns>
    private static LayoutRect SideOf(LayoutRect target, int width, int height, string side, bool start)
    {
        int middleX = start ? target.X : target.X + (target.Width - width) / 2;
        int middleY = start ? target.Y : target.Y + (target.Height - height) / 2;
        return side switch
        {
            "top" => new LayoutRect(middleX, target.Y - height, width, height),
            "bottom" => new LayoutRect(middleX, target.Y + target.Height, width, height),
            "left" => new LayoutRect(target.X - width, middleY, width, height),
            "right" => new LayoutRect(target.X + target.Width, middleY, width, height),
            "inside_left" => new LayoutRect(target.X, target.Y, Math.Min(width, target.Width), target.Height),
            "inside_right" => new LayoutRect(target.X + target.Width - Math.Min(width, target.Width), target.Y, Math.Min(width, target.Width), target.Height),
            _ => new LayoutRect(middleX, middleY, width, height),
        };
    }

    /// <summary>
    /// Tells the side across from a side.
    /// </summary>
    /// <param name="side">The side.</param>
    /// <returns>The other side, null for <see cref="Over"/>.</returns>
    private static string? Opposite(string side) => side switch
    {
        "top" => "bottom",
        "bottom" => "top",
        "left" => "right",
        "right" => "left",
        _ => null,
    };

    /// <summary>
    /// Tells whether a place beside a part lies on the screen across that side; along it the place
    /// is pushed onto the screen anyway.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <param name="side">The side of the part it lies on.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>Whether it does.</returns>
    private static bool Fits(LayoutRect rect, string side, int width, int height) => side is "left" or "right"
        ? rect.X >= 0 && rect.X + rect.Width <= width
        : rect.Y >= 0 && rect.Y + rect.Height <= height;

    /// <summary>
    /// Places the roots docked along the edges, each the whole length of the room left, and tells
    /// the room they leave.
    /// </summary>
    /// <param name="docked">The roots.</param>
    /// <param name="order">Their indices in order.</param>
    /// <param name="places">Where their places go.</param>
    /// <param name="area">The screen.</param>
    /// <returns>The room the edge docks leave.</returns>
    private static LayoutRect DockEdges(IReadOnlyList<Docked> docked, int[] order, LayoutRect[] places, LayoutRect area)
    {
        foreach (string edge in Edges)
        {
            foreach (int index in order.Where(index => docked[index].Edge == edge))
            {
                LayoutRect rect = docked[index].Rect;
                int across = edge is "top" or "bottom" ? Math.Min(rect.Height, area.Height) : Math.Min(rect.Width, area.Width);
                (places[index], area) = edge switch
                {
                    "top" => (new LayoutRect(area.X, area.Y, area.Width, across), area with { Y = area.Y + across, Height = area.Height - across }),
                    "bottom" => (new LayoutRect(area.X, area.Y + area.Height - across, area.Width, across), area with { Height = area.Height - across }),
                    "left" => (new LayoutRect(area.X, area.Y, across, area.Height), area with { X = area.X + across, Width = area.Width - across }),
                    _ => (new LayoutRect(area.X + area.Width - across, area.Y, across, area.Height), area with { Width = area.Width - across }),
                };
            }
        }

        return area;
    }

    /// <summary>
    /// Lists the roots stacked in a zone, in order.
    /// </summary>
    /// <param name="docked">The roots.</param>
    /// <param name="order">Their indices in order.</param>
    /// <param name="zone">The zone.</param>
    /// <returns>Their indices.</returns>
    private static int[] Stacked(IReadOnlyList<Docked> docked, int[] order, string zone) =>
        [.. order.Where(index => docked[index].Edge is null && docked[index].Zone == zone)];

    /// <summary>
    /// Fits a zone's stack into its room: its roots take their own size; where they run past the
    /// room, those that give room shrink to their least height, then the last in order hide.
    /// </summary>
    /// <param name="docked">The roots.</param>
    /// <param name="stacked">The zone's roots in order.</param>
    /// <param name="places">Where their places go.</param>
    /// <param name="crowded">Where the roots that hide are marked.</param>
    /// <param name="room">The zone's length.</param>
    private static void Fit(IReadOnlyList<Docked> docked, int[] stacked, LayoutRect[] places, bool[] crowded, int room)
    {
        foreach (int index in stacked)
        {
            places[index] = docked[index].Rect;
        }

        if (Length(stacked, places, crowded) <= room)
        {
            return;
        }

        foreach (int index in stacked.Where(index => docked[index].GivesRoom))
        {
            places[index] = places[index] with { Height = Math.Min(places[index].Height, docked[index].LeastHeight) };
        }

        for (int last = stacked.Length - 1; last >= 0 && Length(stacked, places, crowded) > room; last--)
        {
            crowded[stacked[last]] = true;
        }
    }

    /// <summary>
    /// Tells the length a stack takes: its roots that show and the gaps between them.
    /// </summary>
    /// <param name="stacked">The roots.</param>
    /// <param name="places">Their places.</param>
    /// <param name="crowded">Which of them hide.</param>
    /// <returns>The length.</returns>
    private static int Length(int[] stacked, LayoutRect[] places, bool[] crowded)
    {
        int[] shown = [.. stacked.Where(index => !crowded[index])];
        return shown.Sum(index => places[index].Height) + Gap * Math.Max(shown.Length - 1, 0);
    }

    /// <summary>
    /// Lays a stack's roots out under each other from a top, or upward when it stacks from the
    /// bottom, each at the left its width gives.
    /// </summary>
    /// <param name="stacked">The roots in order, the first nearest the zone's edge.</param>
    /// <param name="places">Their places, sized.</param>
    /// <param name="y">Where the stack starts: its top, or its own top when it stacks upward.</param>
    /// <param name="upward">Whether the first root lies at the bottom.</param>
    /// <param name="left">The left of a root of a width.</param>
    /// <returns>The top after the stack and a gap, or the start when it holds nothing.</returns>
    private static int Column(int[] stacked, LayoutRect[] places, int y, bool upward, Func<int, int> left)
    {
        IEnumerable<int> downward = upward ? stacked.Reverse() : stacked;
        foreach (int index in downward)
        {
            LayoutRect rect = places[index];
            places[index] = rect with { X = left(rect.Width), Y = y };
            y += rect.Height + Gap;
        }

        return y;
    }

    /// <summary>
    /// Tells the room a zone's roots take, in pixels from its edge; a top corner takes at least the
    /// room of the top zone, and an empty zone the room of the edge docks before it.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <param name="shown">Its roots that show.</param>
    /// <param name="places">Their places.</param>
    /// <param name="area">The room the edge docks leave.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <param name="top">The top zone's room.</param>
    /// <returns>The room.</returns>
    private static int RoomOf(string zone, int[] shown, LayoutRect[] places, LayoutRect area, int width, int height, int top)
    {
        (int column, int row) = Cell(zone);
        if (shown.Length == 0)
        {
            return row == 0 ? Math.Max(top, area.Y) : row == 2 ? height - area.Y - area.Height : column == 0 ? area.X : column == 2 ? width - area.X - area.Width : 0;
        }

        return (column, row) switch
        {
            (_, 0) => shown.Max(index => places[index].Y + places[index].Height),
            (_, 2) => height - shown.Min(index => places[index].Y),
            (0, _) => shown.Max(index => places[index].X + places[index].Width),
            (2, _) => width - shown.Min(index => places[index].X),
            _ => 0,
        };
    }
}

/// <summary>
/// A root docked along an edge or stacked in a zone.
/// </summary>
/// <param name="Zone">The zone it stacks in, one of <see cref="Docks.Names"/>.</param>
/// <param name="Edge">The edge it docks along, one of <see cref="Docks.Edges"/>; null to stack in its zone.</param>
/// <param name="Order">Its order in the zone, lower nearer the edge.</param>
/// <param name="LoadOrder">Its mod's place in the load order, which decides between equal orders.</param>
/// <param name="Opened">When it opened, which decides between equal load orders.</param>
/// <param name="Rect">Its size, its place unused.</param>
/// <param name="GivesRoom">Whether it shrinks to its least height before a root of its zone hides.</param>
/// <param name="LeastHeight">Its least height.</param>
internal readonly record struct Docked(string Zone, string? Edge, int Order, int LoadOrder, long Opened, LayoutRect Rect, bool GivesRoom = false, int LeastHeight = 0);

/// <summary>
/// A named column of roots: the spot its newest root lies at, the pixels between two of its roots
/// and how each lines up with the spot across.
/// </summary>
/// <param name="Name">The column's name.</param>
/// <param name="X">The spot's left, middle or right, by <paramref name="Align"/>.</param>
/// <param name="Y">The spot's top.</param>
/// <param name="Gap">The pixels between two of its roots.</param>
/// <param name="Align">One of <see cref="Docks.ColumnAligns"/>.</param>
internal readonly record struct ColumnPlace(string Name, int X, int Y, int Gap, string Align);

/// <summary>
/// A root stacked in a named column.
/// </summary>
/// <param name="Column">Its column.</param>
/// <param name="Opened">When it opened; the root that opened last lies at the column's spot.</param>
/// <param name="Rect">Its size, its place unused.</param>
internal readonly record struct Stacked(ColumnPlace Column, long Opened, LayoutRect Rect);
