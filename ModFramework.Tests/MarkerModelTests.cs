//----------------------------------------------------------------
//  MarkerModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Checked the place without the triangle's rows and the arrow by its angle alone
//      Paulinchen  2026-11-09: Gave the place topic a margin for each edge of the screen
//      Paulinchen  2026-11-07: Wrote the cases of the place and the angle in the tests and dropped the replay of the pictures
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Markers;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers where a marker sits on the screen's edge and its angle, and an arrow alone and its topics.
/// </summary>
public sealed class MarkerModelTests
{
    /// <summary>
    /// The screen's width in the cases.
    /// </summary>
    private const int ScreenWidth = 640;

    /// <summary>
    /// The screen's height in the cases.
    /// </summary>
    private const int ScreenHeight = 480;

    /// <summary>
    /// Asserts that a marker sits where the line from the screen's middle to a place off screen
    /// leaves the edge, its margin inside, pointing along the line; that the room docked at the top
    /// moves the top edge down; and that two equal spots give no marker.
    /// </summary>
    [Fact]
    public void Point_PutsTheMarkerWhereTheLineLeavesTheScreen()
    {
        var open = MarkerModel.EdgeRect(ScreenWidth, ScreenHeight, 0);
        var docked = MarkerModel.EdgeRect(ScreenWidth, ScreenHeight, 40);

        Assert.Equal((626, 224, 0), MarkerModel.Point(320, 224, 900, 224, open));
        Assert.Equal((320, 14, -90), MarkerModel.Point(320, 224, 320, -50, open));
        Assert.Equal((320, 54, -90), MarkerModel.Point(320, 224, 320, -50, docked));
        Assert.Equal((563, 466, 45), MarkerModel.Point(320, 224, 1000, 900, open));
        Assert.Null(MarkerModel.Point(320, 224, 320, 224, open));
    }

    /// <summary>
    /// Asserts that an angle steps to the nearest ten degrees, halves away from zero.
    /// </summary>
    [Fact]
    public void StepAngle_RoundsToTenDegrees()
    {
        Assert.Equal([0, 10, 20, 50, -20, 180], new[] { 4, 5, 23, 45, -15, 179 }.Select(MarkerModel.StepAngle));
    }

    /// <summary>
    /// Asserts that an arrow alone fills its triangle inside its picture, the outline first, and
    /// that the topics answer the place without the triangle's rows, kept from each edge by its own
    /// margin, nil for two equal spots, and the marker's triangle by its angle alone.
    /// </summary>
    [Fact]
    public void ArrowAndTopics_AnswerThePictureAndThePlace()
    {
        (int left, int top, int width, int height, List<(int X, int Y, int Width, int Fill)> rows) = MarkerModel.ArrowRows(90, 14, 12);
        Assert.Equal((-11, -11, 23, 23), (left, top, width, height));
        Assert.All(rows, row => Assert.True(row.X >= 0 && row.X + row.Width <= width && row.Y >= 0 && row.Y < height));
        Assert.Equal(0, rows[0].Fill);
        Assert.Equal(1, rows[^1].Fill);

        var ui = new UiContext();
        MarkerModel.Register(ui.Context);
        RubyArray placed = ui.Value(MarkerModel.PlaceTopic, new RubyArray { 320, 224, 900, 224, ScreenWidth, ScreenHeight, 0, 14, 30, 14, 14, 44 }).AsArray();
        Assert.Equal([610, 224, 0], placed.Take(3).Select(value => value.AsInt()));
        Assert.Equal(11, placed.Count);
        Assert.True(ui.Value(MarkerModel.PlaceTopic, new RubyArray { 1, 1, 1, 1, ScreenWidth, ScreenHeight, 0, 14, 14, 14, 14, 44 }).IsNil);
        RubyArray arrow = ui.Value(MarkerModel.ArrowTopic, new RubyArray { 90 }).AsArray();
        Assert.Equal([-11, -11, 23, 23], arrow.Take(4).Select(value => value.AsInt()));
        Assert.Equal(rows.Count, arrow[4].AsArray().Count);
    }
}
