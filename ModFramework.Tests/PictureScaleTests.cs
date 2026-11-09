//----------------------------------------------------------------
//  PictureScaleTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Pictures;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers a picture that scales to its room: a map figure and a face in the items of a grid, each as
/// high as its item's width lets it be, and the plan of their pixels, sharp and smooth, larger and
/// smaller.
/// </summary>
public sealed class PictureScaleTests
{
    /// <summary>
    /// Asserts that a figure of 12 by 30 pixels and a face of 96 that keep their proportions take
    /// their grid item's width and the height it gives them, also as the window narrows; that the
    /// figure enlarged sharp takes each pixel's nearest pixel, in whole blocks at a whole factor and
    /// shrunk too; that the face enlarged smooth blends between two pixels and shrinks in one
    /// stretch; that cover keeps the proportions past the room and fill takes the room; and that the
    /// topic answers the plan, nil without room.
    /// </summary>
    [Fact]
    public void Picture_ScalesToItsRoomSharpOrSmooth()
    {
        var tree = new TreeHarness();
        RubyHash report = tree.Frame(Adds(
            Node(10, null, "window", ("size", new RubyArray { 150, RubyNil.Value })),
            Node(11, 10, "grid", ("layout", "grid"), ("columns", 12), ("gap", 6)),
            Node(12, 11, "stack", ("span", 6)),
            Node(13, 11, "stack", ("span", 6)),
            Node(22, 12, "picture", Measured(12, 30), ("aspect", true)),
            Node(23, 13, "picture", Measured(96, 96), ("aspect", true))));

        Assert.Equal([0, 0, 72, 180], Rect(report, 22));
        Assert.Equal([78, 0, 72, 72], Rect(report, 23));
        report = tree.Frame(Set(10, "size", new RubyArray { 102, RubyNil.Value }));
        Assert.Equal([0, 0, 48, 120], Rect(report, 22));

        PictureScalePlan figure = PictureScale.Plan(12, 30, 72, 180, PictureFit.Contain, PictureSampling.Sharp)!;
        Assert.Equal((72, 180, ScaleWay.Samples), (figure.Width, figure.Height, figure.Across.Way));
        Assert.Equal([0, 0, 0, 0, 0, 0, 1], figure.Across.Samples.Take(7).Select(sample => sample.From));
        Assert.All(figure.Down.Samples, sample => Assert.Equal((sample.From, 0), (sample.Toward, sample.Weight)));
        PictureScalePlan small = PictureScale.Plan(12, 30, 72, 20, PictureFit.Contain, PictureSampling.Sharp)!;
        Assert.Equal((8, 20), (small.Width, small.Height));
        Assert.Equal([0, 2, 3, 5, 6, 8, 9, 11], small.Across.Samples.Select(sample => sample.From));

        PictureScalePlan face = PictureScale.Plan(96, 96, 200, 192, PictureFit.Contain, PictureSampling.Smooth)!;
        Assert.Equal((192, 192), (face.Width, face.Height));
        Assert.Equal([new ScaleSample(0, 1, 0), new ScaleSample(0, 1, 64), new ScaleSample(0, 1, 191), new ScaleSample(1, 2, 64)], face.Down.Samples.Take(4));
        Assert.Equal(new ScaleSample(95, 95, 0), face.Down.Samples[^1]);
        PictureScalePlan shrunk = PictureScale.Plan(96, 96, 48, 48, PictureFit.Contain, PictureSampling.Smooth)!;
        Assert.Equal((48, ScaleWay.Stretch, ScaleWay.Stretch), (shrunk.Width, shrunk.Across.Way, shrunk.Down.Way));
        Assert.Equal(ScaleWay.Copy, PictureScale.Plan(96, 96, 96, 200, PictureFit.Contain, PictureSampling.Smooth)!.Down.Way);

        PictureScalePlan cover = PictureScale.Plan(12, 30, 72, 72, PictureFit.Cover, PictureSampling.Sharp)!;
        Assert.Equal((72, 180), (cover.Width, cover.Height));
        PictureScalePlan fill = PictureScale.Plan(12, 30, 72, 72, PictureFit.Fill, PictureSampling.Smooth)!;
        Assert.Equal((72, 72, ScaleWay.Samples, ScaleWay.Samples), (fill.Width, fill.Height, fill.Across.Way, fill.Down.Way));

        var ui = new UiContext();
        PictureScale.Register(ui.Context);
        RubyArray answer = ui.Value(PictureScale.Topic, new RubyArray { 12, 30, 72, 180, "contain", "sharp" }).AsArray();
        Assert.Equal((72, 180, "samples", 72), (answer[0].AsInt(), answer[1].AsInt(), answer[2].AsArray()[0].AsText(), answer[2].AsArray()[1].AsArray().Count));
        Assert.True(ui.Value(PictureScale.Topic, new RubyArray { 12, 30, 0, 180, "contain", "sharp" }).IsNil);
    }
}
