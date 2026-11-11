//----------------------------------------------------------------
//  MarkerModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Left the triangle's rows out of a marker's place, which draws the arrow's rows shifted
//                            - Laid out an arrow by its angle alone at the one size of a marker's triangle
//      Paulinchen  2026-11-09: Kept a marker's own margin from each edge of the screen
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Ui.Markers;

/// <summary>
/// A marker's picture, its triangle's center at the picture's origin.
/// </summary>
/// <param name="Left">The picture's left, from the triangle's center.</param>
/// <param name="Top">The picture's top, from the triangle's center.</param>
/// <param name="Width">The picture's width.</param>
/// <param name="Height">The picture's height.</param>
/// <param name="PlateX">The plate's left in the picture.</param>
/// <param name="PlateY">The plate's top in the picture.</param>
/// <param name="SlideX">Pixels the marker slides in from as it fades in, x.</param>
/// <param name="SlideY">Pixels the marker slides in from as it fades in, y.</param>
internal sealed record MarkerPicture(int Left, int Top, int Width, int Height, int PlateX, int PlateY, int SlideX, int SlideY);

/// <summary>
/// The geometry of the markers at the screen's edge and of the arrows they draw with: where the
/// line from one spot to another off the screen crosses the screen's edge, which way it points, an
/// arrow's triangle filled row by row with its outline, and the plate beside it, clear of it.
/// </summary>
internal static class MarkerModel
{
    /// <summary>
    /// Places a marker: [from x, from y, to x, to y, screen width, screen height, room at the top,
    /// margin at the top, the right, the bottom and the left, plate width]; answers [x, y, the angle stepped, picture left, top, width, height,
    /// plate x, plate y, slide x, slide y], nil for two equal spots; the marker draws the triangle of
    /// <see cref="ArrowTopic"/> at its angle.
    /// </summary>
    public const string PlaceTopic = "ui.marker.place";

    /// <summary>
    /// Lays out an arrow of a marker's triangle, <see cref="Length"/> long and <see cref="Width"/>
    /// wide: [angle]; answers [left, top, width, height, rows].
    /// </summary>
    public const string ArrowTopic = "ui.marker.arrow";

    /// <summary>
    /// Pixels between the screen's edge and a marker's center unless a marker names its own.
    /// </summary>
    public const int Margin = 14;

    /// <summary>
    /// Pixels from a marker's triangle's base to its tip.
    /// </summary>
    public const int Length = 14;

    /// <summary>
    /// Pixels across a marker's triangle's base.
    /// </summary>
    public const int Width = 12;

    /// <summary>
    /// Degrees a marker turns by at least before it is drawn anew.
    /// </summary>
    public const int AngleStep = 10;

    /// <summary>
    /// Height of a marker's plate.
    /// </summary>
    public const int PlateHeight = 20;

    /// <summary>
    /// Pixels between the triangle and its plate.
    /// </summary>
    public const int PlateGap = 4;

    /// <summary>
    /// Pixels a marker slides in from, toward the edge, as it fades in.
    /// </summary>
    public const int SlidePixels = 10;

    /// <summary>
    /// Pixels the outline reaches around a triangle.
    /// </summary>
    public const int OutlineReach = 1;

    /// <summary>
    /// Degrees in a half turn.
    /// </summary>
    private const double HalfTurn = 180;

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(PlaceTopic, (_, request) => Place(request.AsArray()));
        context.Register(ArrowTopic, (_, request) => Arrow(request.AsArray()));
    }

    /// <summary>
    /// Tells the rect a marker's center stays in: the screen less its margin on each side, and less
    /// the room docked at the top.
    /// </summary>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <param name="topRoom">The pixels docked at the top.</param>
    /// <param name="top">The margin at the top.</param>
    /// <param name="right">The margin at the right.</param>
    /// <param name="bottom">The margin at the bottom.</param>
    /// <param name="left">The margin at the left.</param>
    /// <returns>Left, top, right and bottom.</returns>
    public static (int Left, int Top, int Right, int Bottom) EdgeRect(int width, int height, int topRoom, int top = Margin, int right = Margin, int bottom = Margin, int left = Margin) =>
        (left, top + topRoom, width - right, height - bottom);

    /// <summary>
    /// Finds where a marker sits and which way it points: where the line from one spot of the
    /// screen to another crosses the edge's rect, kept inside it, and the line's angle.
    /// </summary>
    /// <param name="fromX">Where the line starts, x.</param>
    /// <param name="fromY">Where the line starts, y.</param>
    /// <param name="toX">Where it points, x.</param>
    /// <param name="toY">Where it points, y.</param>
    /// <param name="edge">The rect, see <see cref="EdgeRect"/>.</param>
    /// <returns>The marker's x and y, and the angle in degrees, 0 to the right and 90 down;
    /// <see langword="null"/> for two equal spots.</returns>
    public static (int X, int Y, int Angle)? Point(int fromX, int fromY, int toX, int toY, (int Left, int Top, int Right, int Bottom) edge)
    {
        double dx = toX - fromX;
        double dy = toY - fromY;
        if (dx == 0 && dy == 0)
        {
            return null;
        }

        double reach = Math.Min(Math.Min(AxisReach(fromX, dx, edge.Left, edge.Right), AxisReach(fromY, dy, edge.Top, edge.Bottom)), 1.0);
        reach = reach < 0 ? 0.0 : reach;
        int x = Math.Clamp(Round(fromX + (dx * reach)), edge.Left, edge.Right);
        int y = Math.Clamp(Round(fromY + (dy * reach)), edge.Top, edge.Bottom);
        return (x, y, Round(Math.Atan2(dy, dx) * HalfTurn / Math.PI));
    }

    /// <summary>
    /// Rounds an angle to the nearest <see cref="AngleStep"/>, so a marker is drawn anew only once
    /// it turned.
    /// </summary>
    /// <param name="angle">The angle in degrees.</param>
    /// <returns>The angle rounded.</returns>
    public static int StepAngle(int angle) => Round(angle / (double)AngleStep) * AngleStep;

    /// <summary>
    /// Lays out a marker's picture: room for the triangle pointing along the angle around the
    /// picture's origin, and the plate on the side away from the edge, clear of the triangle by
    /// <see cref="PlateGap"/>.
    /// </summary>
    /// <param name="angle">The stepped angle in degrees.</param>
    /// <param name="plateWidth">The plate's width, its text measured with the padding.</param>
    /// <returns>The picture.</returns>
    public static MarkerPicture Picture(int angle, int plateWidth)
    {
        double radians = angle * Math.PI / HalfTurn;
        double ux = Math.Cos(radians);
        double uy = Math.Sin(radians);
        int reach = Reach(Length, Width);
        double halfWidth = plateWidth / 2.0;
        double halfHeight = PlateHeight / 2.0;
        double distance = PlateDistance(ux, uy, halfWidth, halfHeight, reach);
        double plateLeft = (-ux * distance) - halfWidth;
        double plateTop = (-uy * distance) - halfHeight;
        int left = (int)Math.Floor(Math.Min(-reach, plateLeft));
        int top = (int)Math.Floor(Math.Min(-reach, plateTop));
        int right = (int)Math.Ceiling(Math.Max(reach, plateLeft + plateWidth));
        int bottom = (int)Math.Ceiling(Math.Max(reach, plateTop + PlateHeight));
        return new MarkerPicture(left, top, right - left, bottom - top, Round(plateLeft - left), Round(plateTop - top),
            Round(ux * SlidePixels), Round(uy * SlidePixels));
    }

    /// <summary>
    /// Lays out an arrow alone: a triangle of a length and a base width pointing along an angle,
    /// with its outline, in a picture just large enough.
    /// </summary>
    /// <param name="angle">The angle in degrees, 0 to the right and 90 down.</param>
    /// <param name="length">Pixels from its base to its tip.</param>
    /// <param name="width">Pixels across its base.</param>
    /// <returns>The picture's left and top from the triangle's center, its size, and the rows.</returns>
    public static (int Left, int Top, int Width, int Height, List<(int X, int Y, int Width, int Fill)> Rows) ArrowRows(int angle, int length, int width)
    {
        double radians = angle * Math.PI / HalfTurn;
        int reach = Reach(length, width) + OutlineReach;
        return (-reach, -reach, 2 * reach + 1, 2 * reach + 1, TriangleRows(reach, reach, Math.Cos(radians), Math.Sin(radians), length, width));
    }

    /// <summary>
    /// Tells how far from the triangle's center, along the line and away from the edge, the plate's
    /// center lies so that the plate's nearest point clears the triangle by <see cref="PlateGap"/>:
    /// the plate's edge faces the triangle when the line meets the plate across its width or its
    /// height, else a corner does, which lies on the circle of the gap.
    /// </summary>
    /// <param name="ux">The angle's cosine.</param>
    /// <param name="uy">The angle's sine.</param>
    /// <param name="halfWidth">Half the plate's width.</param>
    /// <param name="halfHeight">Half the plate's height.</param>
    /// <param name="reach">Pixels the triangle reaches from its center.</param>
    /// <returns>The distance in pixels.</returns>
    public static double PlateDistance(double ux, double uy, double halfWidth, double halfHeight, int reach)
    {
        double clear = reach + PlateGap;
        double ax = Math.Abs(ux);
        double ay = Math.Abs(uy);
        if (ay > 0 && ax * ((clear + halfHeight) / ay) <= halfWidth)
        {
            return (clear + halfHeight) / ay;
        }

        if (ax > 0 && ay * ((clear + halfWidth) / ax) <= halfHeight)
        {
            return (clear + halfWidth) / ax;
        }

        double support = (ax * halfWidth) + (ay * halfHeight);
        return support + Math.Sqrt(Math.Max((support * support) - (halfWidth * halfWidth) - (halfHeight * halfHeight) + (clear * clear), 0));
    }

    /// <summary>
    /// Tells how far a triangle reaches from its center at most, to a corner of its base.
    /// </summary>
    /// <param name="length">Pixels from its base to its tip.</param>
    /// <param name="width">Pixels across its base.</param>
    /// <returns>The pixels, rounded up.</returns>
    public static int Reach(int length, int width) => (int)Math.Ceiling(Math.Sqrt(Math.Pow(length / 2.0, 2) + Math.Pow(width / 2.0, 2)));

    /// <summary>
    /// Answers a marker's place and picture.
    /// </summary>
    /// <param name="request">See <see cref="PlaceTopic"/>.</param>
    /// <returns>The answer, nil for two equal spots.</returns>
    private static RubyValue Place(RubyArray request)
    {
        int Int(int place) => request[place].AsInt();
        (int X, int Y, int Angle)? point = Point(Int(0), Int(1), Int(2), Int(3), EdgeRect(Int(4), Int(5), Int(6), Int(7), Int(8), Int(9), Int(10)));
        if (point is not { } at)
        {
            return RubyNil.Value;
        }

        int angle = StepAngle(at.Angle);
        MarkerPicture picture = Picture(angle, Int(11));
        return new RubyArray
        {
            at.X, at.Y, angle, picture.Left, picture.Top, picture.Width, picture.Height, picture.PlateX, picture.PlateY, picture.SlideX, picture.SlideY,
        };
    }

    /// <summary>
    /// Answers an arrow's picture.
    /// </summary>
    /// <param name="request">See <see cref="ArrowTopic"/>.</param>
    /// <returns>The answer.</returns>
    private static RubyValue Arrow(RubyArray request)
    {
        (int left, int top, int width, int height, List<(int X, int Y, int Width, int Fill)> rows) =
            ArrowRows(request[0].AsInt(), Length, Width);
        return new RubyArray { left, top, width, height, RowsOf(rows) };
    }

    /// <summary>
    /// Writes rows as the scripts read them.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>Each [x, y, width, fill].</returns>
    private static RubyArray RowsOf(IEnumerable<(int X, int Y, int Width, int Fill)> rows) =>
        new(rows.Select(row => (RubyValue)new RubyArray { row.X, row.Y, row.Width, row.Fill }));

    /// <summary>
    /// Rounds as Ruby's <c>Float#round</c> does, halves away from zero.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The whole number.</returns>
    private static int Round(double value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Tells how far along a line, 1.0 for its whole length, it reaches one axis's bound.
    /// </summary>
    /// <param name="from">Where the line starts on the axis.</param>
    /// <param name="delta">How far it goes on the axis.</param>
    /// <param name="low">The lower bound.</param>
    /// <param name="high">The upper bound.</param>
    /// <returns>The share of the line, 1.0 for a line still on the axis.</returns>
    private static double AxisReach(int from, double delta, int low, int high)
    {
        if (delta == 0)
        {
            return 1.0;
        }

        return delta > 0 ? (high - from) / delta : (low - from) / delta;
    }

    /// <summary>
    /// Lists the rows of a triangle around a center: the outline's four passes, each shifted by
    /// <see cref="OutlineReach"/>, then the fill.
    /// </summary>
    /// <param name="cx">The center's x in the picture.</param>
    /// <param name="cy">The center's y in the picture.</param>
    /// <param name="ux">The angle's cosine.</param>
    /// <param name="uy">The angle's sine.</param>
    /// <param name="length">Pixels from its base to its tip.</param>
    /// <param name="width">Pixels across its base.</param>
    /// <returns>The rows.</returns>
    private static List<(int X, int Y, int Width, int Fill)> TriangleRows(int cx, int cy, double ux, double uy, int length, int width)
    {
        double halfLength = length / 2.0;
        double halfWidth = width / 2.0;
        (double X, double Y)[] corners =
        [
            (cx + (ux * halfLength), cy + (uy * halfLength)),
            (cx - (ux * halfLength) - (uy * halfWidth), cy - (uy * halfLength) + (ux * halfWidth)),
            (cx - (ux * halfLength) + (uy * halfWidth), cy - (uy * halfLength) - (ux * halfWidth)),
        ];
        var rows = new List<(int, int, int, int)>();
        foreach ((int dx, int dy) in new[] { (-OutlineReach, 0), (OutlineReach, 0), (0, -OutlineReach), (0, OutlineReach) })
        {
            FillRows(rows, [.. corners.Select(corner => (corner.X + dx, corner.Y + dy))], 0);
        }

        FillRows(rows, corners, 1);
        return rows;
    }

    /// <summary>
    /// Fills a triangle row by row, as a picture that draws only rects must.
    /// </summary>
    /// <param name="rows">The rows, added to.</param>
    /// <param name="points">The three corners.</param>
    /// <param name="fill">1 for the fill, 0 for the outline.</param>
    private static void FillRows(List<(int, int, int, int)> rows, (double X, double Y)[] points, int fill)
    {
        double lowest = points.Min(point => point.Y);
        double highest = points.Max(point => point.Y);
        for (int y = (int)Math.Floor(lowest); y <= (int)Math.Ceiling(highest); y++)
        {
            var crossings = new List<double>();
            for (int index = 0; index < points.Length; index++)
            {
                (double X, double Y) a = points[index];
                (double X, double Y) b = points[(index + 1) % points.Length];
                if (a.Y == b.Y || y < Math.Min(a.Y, b.Y) || y > Math.Max(a.Y, b.Y))
                {
                    continue;
                }

                crossings.Add(a.X + ((b.X - a.X) * (y - a.Y) / (b.Y - a.Y)));
            }

            if (crossings.Count == 0)
            {
                continue;
            }

            int left = (int)Math.Floor(crossings.Min());
            rows.Add((left, y, (int)Math.Ceiling(crossings.Max()) - left + 1, fill));
        }
    }
}
