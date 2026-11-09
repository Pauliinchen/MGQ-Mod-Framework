//----------------------------------------------------------------
//  PlacementTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked the huds of a named column stacked newest first, a leaving one holding its place
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Checked that notices lower than their least height keep their own height
//                            - Checked that a strip along the top edge counts in the room of the top, which a mod moves the
//                              game's own bars below
//      Paulinchen  2026-11-05: Checked a drawer laid over a part inside its left and its right edge, as high as the part
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of the zones, the docks, the edges, beside, a popover and a
//                              full zone, and took over the docks of RootPartsTests.cs
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the placement examples of the UI design (section 6) in the component tree: HUD parts in
/// the nine zones and docked at the corners, windows alone at a zone, at a spot or along an edge,
/// parts beside another part or a game window, a popover's cancel, a zone that runs out of room,
/// and the huds of a named column.
/// </summary>
public sealed class PlacementTests
{
    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts that HUD parts of two mods in one zone stack by their order and then the load order of
    /// their mods without overlapping, that the bottom and right zones place theirs from their edges,
    /// that windows alone at a zone or at a spot sit there without stacking with the HUD parts, and
    /// that every part keeps its place in its zone on a larger screen.
    /// </summary>
    [Fact]
    public void Zones_StackHudPartsByLoadOrderAndSeatWindowsAlone()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "box", ("size", Pair(120, 40)), ("dock", "top_right"), ("load_order", 2)),
            Node(2, null, "box", ("size", Pair(100, 30)), ("dock", "top_right"), ("load_order", 1)),
            Node(3, null, "box", ("size", Pair(200, 20)), ("dock", "bottom")),
            Node(4, null, "box", ("size", Pair(80, 80)), ("dock", "right")),
            Node(5, null, "window", ("size", Pair(200, 100)), ("anchor", "center")),
            Node(6, null, "window", ("size", Pair(150, 60)), ("anchor", "top_right")),
            Node(7, null, "window", ("size", Pair(100, 50)), ("at", Pair(40, 60)))));

        Assert.Equal([532, 8, 100, 30], Rect(report, 2));
        Assert.Equal([512, 42, 120, 40], Rect(report, 1));
        Assert.Equal([220, 452, 200, 20], Rect(report, 3));
        Assert.Equal([552, 200, 80, 80], Rect(report, 4));
        Assert.Equal([220, 190, 200, 100], Rect(report, 5));
        Assert.Equal([482, 8, 150, 60], Rect(report, 6));
        Assert.Equal([40, 60, 100, 50], Rect(report, 7));

        report = _tree.Frame(new RubyHash { { "screen", Pair(800, 600) } });
        Assert.Equal([692, 8, 100, 30], Rect(report, 2));
        Assert.Equal([300, 572, 200, 20], Rect(report, 3));
        Assert.Equal([712, 260, 80, 80], Rect(report, 4));
    }

    /// <summary>
    /// Asserts that docked roots stack from their corner 8 pixels in and 4 apart by their order, that
    /// a strip at the top pushes the top corners down, an empty one too, so what keeps clear of a
    /// corner lies below the strip, that a bottom corner stacks upward, that the room of each dock is
    /// told, and that the corners move up once the strip hides.
    /// </summary>
    [Fact]
    public void Docks_StackFromTheirCornersBelowTheTopStrip()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "box", ("size", Pair(100, 30)), ("dock", "top_left"), ("dock_order", 100)),
            Node(2, null, "box", ("size", Pair(80, 20)), ("dock", "top_left")),
            Node(3, null, "box", ("size", Pair(300, 16)), ("dock", "top")),
            Node(4, null, "box", ("size", Pair(60, 40)), ("dock", "bottom_right")),
            Node(5, null, "box", ("size", Pair(60, 20)), ("dock", "bottom_right"))));

        Assert.Equal([170, 8, 300, 16], Rect(report, 3));
        Assert.Equal([8, 28, 80, 20], Rect(report, 2));
        Assert.Equal([8, 52, 100, 30], Rect(report, 1));
        Assert.Equal([572, 432, 60, 40], Rect(report, 4));
        Assert.Equal([572, 408, 60, 20], Rect(report, 5));
        RubyHash docks = report["docks"].AsHash();
        Assert.Equal((82, 24, 72, 0, 24), (docks["top_left"].AsInt(), docks["top_right"].AsInt(), docks["bottom_right"].AsInt(), docks["bottom_left"].AsInt(), docks["top"].AsInt()));

        report = _tree.Frame(Set(3, "visible", false));
        Assert.Equal([8, 8, 80, 20], Rect(report, 2));
    }

    /// <summary>
    /// Asserts that a strip docked at the top takes the screen's whole width, a window docked at the
    /// left its whole height below the strip, a HUD part of the top left corner keeps clear of both,
    /// and the top tells the strip's room, as it tells that of a part stacked there.
    /// </summary>
    [Fact]
    public void Edges_TakeTheirWholeLengthAndTheZonesKeepClear()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(240, 100)), ("edge", "left")),
            Node(2, null, "box", ("size", Pair(300, 20)), ("edge", "top")),
            Node(3, null, "box", ("size", Pair(100, 30)), ("dock", "top_left"))));

        Assert.Equal([0, 0, 640, 20], Rect(report, 2));
        Assert.Equal([0, 20, 240, 460], Rect(report, 1));
        Assert.Equal([248, 28, 100, 30], Rect(report, 3));
        Assert.Equal((58, 20), (report["docks"].AsHash()["top_left"].AsInt(), report["docks"].AsHash()["top"].AsInt()));
    }

    /// <summary>
    /// Asserts that a root beside a game window's place lies on the other side where its own has no
    /// room, that a root beside another root's part lies centered under it and follows it as it
    /// moves, and that a dialog over the window that opened it lies centered on that window.
    /// </summary>
    [Fact]
    public void Beside_FollowsItsPartAndTakesTheOtherSideWithoutRoom()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 100)), ("at", Pair(100, 100))),
            Node(2, null, "box", ("size", Pair(80, 40)), ("beside", 1), ("side", "bottom")),
            Node(3, null, "box", ("size", Pair(100, 60)), ("beside", new RubyArray { 500, 100, 120, 200 }), ("side", "right")),
            Node(4, null, "dialog", ("size", Pair(120, 50)), ("beside", 1), ("side", "over"))));

        Assert.Equal([160, 200, 80, 40], Rect(report, 2));
        Assert.Equal([400, 170, 100, 60], Rect(report, 3));
        Assert.Equal([140, 125, 120, 50], Rect(report, 4));

        report = _tree.Frame(Set(1, "at", Pair(50, 300)));
        Assert.Equal([110, 400, 80, 40], Rect(report, 2));
    }

    /// <summary>
    /// Asserts that a popover lines up with the left of its target below it and with its top beside it,
    /// as MudPopover does, takes the other side without room, and stays on the screen at its edge.
    /// </summary>
    [Fact]
    public void Popover_LinesUpWithItsTargetStart()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 100)), ("at", Pair(100, 100))),
            Node(2, null, "box", ("size", Pair(80, 40)), ("beside", 1), ("side", "bottom"), ("line_up", "start")),
            Node(3, null, "box", ("size", Pair(60, 30)), ("beside", 1), ("side", "right"), ("line_up", "start")),
            Node(4, null, "box", ("size", Pair(160, 40)), ("beside", new RubyArray { 560, 440, 40, 20 }), ("side", "bottom"), ("line_up", "start"))));

        Assert.Equal([100, 200, 80, 40], Rect(report, 2));
        Assert.Equal([300, 100, 60, 30], Rect(report, 3));
        Assert.Equal([480, 400, 160, 40], Rect(report, 4));
    }

    /// <summary>
    /// Asserts that a drawer over the rest lies inside the left or the right edge of the row it opens
    /// in, as high as the row, and no wider than it.
    /// </summary>
    [Fact]
    public void Drawer_LiesInsideTheEdgeOfItsRow()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(300, 200)), ("at", Pair(100, 100))),
            Node(2, 1, "stack", ("grow", 1)),
            Node(3, null, "box", ("size", Pair(120, 40)), ("beside", 2), ("side", "inside_left")),
            Node(4, null, "box", ("size", Pair(120, 40)), ("beside", 2), ("side", "inside_right")),
            Node(5, null, "box", ("size", Pair(900, 40)), ("beside", 2), ("side", "inside_left"))));
        int[] row = Rect(report, 2);

        Assert.Equal([row[0], row[1], 120, row[3]], Rect(report, 3));
        Assert.Equal([row[0] + row[2] - 120, row[1], 120, row[3]], Rect(report, 4));
        Assert.Equal(row, Rect(report, 5));
    }

    /// <summary>
    /// Asserts that cancel closes a popover that shows only text, and so takes no focus, before the
    /// window whose button it lies beside, the focus staying on that button.
    /// </summary>
    [Fact]
    public void Popover_OfTextClosesOnCancelBeforeItsWindow()
    {
        _tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(100, 100))),
            Node(2, 1, "button", Measured(40, 20)),
            Node(3, null, "box", ("layer", true), ("captures", true), ("closable", true), ("beside", 2), ("side", "bottom"), ("line_up", "start")),
            Node(4, 3, "label", Measured(80, 20))));
        _tree.Frame(new RubyHash { { "focus", 2 } });

        Assert.Equal(["3 close"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));

        Assert.Equal(["1 close"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));
    }

    /// <summary>
    /// Asserts that a corner whose parts run past the screen shrinks the notices to their least
    /// height first, then hides its part of the highest order and says so, and shows it again once
    /// another part leaves room; notices lower than their least height keep their own height.
    /// </summary>
    [Fact]
    public void FullZone_ShrinksTheNoticesThenHidesTheHighestOrder()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "box", ("size", Pair(300, 200)), ("min", Pair(300, 48)), ("dock", "top_left"), ("dock_order", 100), ("gives_room", true)),
            Node(2, null, "box", ("size", Pair(100, 200)), ("dock", "top_left")),
            Node(3, null, "box", ("size", Pair(100, 150)), ("dock", "top_left"), ("dock_order", 50)),
            Node(4, null, "box", ("size", Pair(100, 100)), ("dock", "top_left"), ("dock_order", 200))));

        Assert.Equal([8, 366, 300, 48], Rect(report, 1));
        Assert.Equal([4], report["crowded"].AsArray().Select(id => id.AsInt()));

        report = _tree.Frame(Set(3, "visible", false));
        Assert.Empty(report["crowded"].AsArray());
        Assert.Equal([8, 264, 100, 100], Rect(report, 4));

        report = _tree.Frame(Set(1, "size", Pair(300, 30)));
        Assert.Equal([8, 212, 300, 30], Rect(report, 1));
    }

    /// <summary>
    /// Asserts that the huds of a column stack down from its spot by their heights and its gap, the
    /// newest on top, that a new one pushes the others down by its height and the gap, that a
    /// leaving one keeps its place and is pushed along until its fade ends, then the others close up
    /// at once, and that a centered column centers each hud on its spot.
    /// </summary>
    [Fact]
    public void Column_StacksNewestFirstAndClosesUpOnceALeavingHudIsGone()
    {
        RubyArray left = ["battle_left", 8, 88, 8, "left"];
        _tree.Frame(Adds(Node(1, null, "box", ("size", Pair(288, 40)), ("column", left))));
        RubyHash report = _tree.Frame(Adds(Node(2, null, "box", ("size", Pair(288, 64)), ("column", left))));
        Assert.Equal([8, 88, 288, 64], Rect(report, 2));
        Assert.Equal([8, 160, 288, 40], Rect(report, 1));

        report = _tree.Frame(Adds(Node(3, null, "box", ("size", Pair(288, 24)), ("column", left))));
        Assert.Equal([8, 88, 288, 24], Rect(report, 3));
        Assert.Equal([8, 120, 288, 64], Rect(report, 2));
        Assert.Equal([8, 192, 288, 40], Rect(report, 1));

        report = _tree.Frame(Set(2, ("visible", false), ("column_hold", true)));
        Assert.True(report["rects"].IsNil);

        report = _tree.Frame(Adds(Node(4, null, "box", ("size", Pair(288, 32)), ("column", left))));
        Assert.Equal([8, 88, 288, 32], Rect(report, 4));
        Assert.Equal([8, 128, 288, 24], Rect(report, 3));
        Assert.Equal([8, 160, 288, 64], Rect(report, 2));
        Assert.Equal([8, 232, 288, 40], Rect(report, 1));

        report = _tree.Frame(new RubyHash { { "remove", new RubyArray { 2 } } });
        Assert.Equal([8, 160, 288, 40], Rect(report, 1));

        RubyArray top = ["battle_top", 320, 52, 2, "center"];
        _tree.Frame(Adds(Node(5, null, "box", ("size", Pair(200, 16)), ("column", top))));
        report = _tree.Frame(Adds(Node(6, null, "box", ("size", Pair(100, 16)), ("column", top))));
        Assert.Equal([270, 52, 100, 16], Rect(report, 6));
        Assert.Equal([220, 70, 200, 16], Rect(report, 5));
    }
}
