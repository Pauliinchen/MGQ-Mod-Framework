//----------------------------------------------------------------
//  TreeLayoutTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that a window's padding gives way before it shows a compact form
//                            - Checked that a hud's padding gives way to a long text at its most width
//                            - Checked that a margin keeps room around a part in a column, a row and at a root's zone
//                            - Checked that a container stands in the middle at its width and picks the largest width that fits
//      Paulinchen  2026-11-07: Checked that a gem count of no width of its own takes only the room its header's line leaves
//                            - Checked that a part's forms whose picked form is hidden get a place at every step
//                            - Laid out the Mods screen as its script builds it and checked that the restart bar stays on the screen
//                            - Checked that a badge lies over the corner of the part it counts for
//                            - Checked that the items of a grid share its width by their spans at two widths
//                            - Dropped the check of a row that lines its columns up, which the layout no longer has
//                            - Checked that a dialog opens at the step of its comparison's tallest copy and keeps it as the cursor moves
//                            - Checked that a window that gets smaller shows the first, then the second compact form
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Checked that a column keeping its newest parts leaves a part without room that does not fit whole
//      Paulinchen  2026-11-05: Checked that a part that fills takes the room through the page of a tab
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Text;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers how the component tree lays its roots out through the frame's tick: columns, rows, grids
/// and wrapped labels, the room shared by grow and taken back when it runs out, a root laid out
/// again only once something changed, the batches the scripts send, the least and most size, and
/// the framework's screens laid out as their scripts build them.
/// </summary>
public sealed class TreeLayoutTests
{
    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// The place of every component as the tree told it last.
    /// </summary>
    private readonly RubyHash _places = [];

    /// <summary>
    /// Asserts that a column keeps its gap inside its padding and stretches its children while a row
    /// puts them side by side as high as the row; that a wrapping row and a wrapped label break into
    /// lines, a label kept to its most lines or to one line for its room, a line break starting a
    /// line; that a grid keeps its fixed columns and shares the rest, or fits as many columns as its
    /// widest child allows; that a column keeping its newest parts lays them out from its bottom,
    /// leaving a part without room that does not fit whole.
    /// </summary>
    [Fact]
    public void Stacks_PlaceTheirChildrenInColumnsRowsAndGrids()
    {
        _tree.DefineFont();
        RubyHash report = _tree.Frame(Adds(
            Node(10, null, "window", ("at", Pair(10, 20)), ("padding", 8), ("gap", 4)),
            Node(11, 10, "custom", ("measured", Pair(100, 20))),
            Node(12, 10, "custom", ("measured", Pair(60, 30))),
            Node(20, null, "box", ("at", Pair(0, 200)), ("layout", "row"), ("gap", 6), ("padding", 2)),
            Node(21, 20, "custom", ("measured", Pair(30, 10))),
            Node(22, 20, "custom", ("measured", Pair(40, 20))),
            Node(30, null, "window", ("size", new RubyArray { 100, RubyNil.Value })),
            Node(31, 30, "stack", ("layout", "row"), ("wrap", true), ("gap", 10)),
            Node(32, 31, "custom", ("measured", Pair(40, 10))),
            Node(33, 31, "custom", ("measured", Pair(40, 10))),
            Node(34, 31, "custom", ("measured", Pair(40, 10))),
            Node(35, 31, "custom", ("measured", Pair(40, 10))),
            Node(40, null, "window", ("at", Pair(0, 100)), ("size", new RubyArray { 70, RubyNil.Value })),
            Node(41, 40, "label", ("text", "aaaa bbbb cccc"), ("font", 1), ("wrap", true)),
            Node(45, null, "window", ("size", new RubyArray { 100, RubyNil.Value })),
            Node(46, 45, "label", ("text", "aaaa bbbb cccc dddd"), ("font", 1), ("wrap", true), ("most_lines", 2)),
            Node(47, 45, "label", ("text", "aaaa bbbb cccc dddd"), ("font", 1), ("wrap", true), ("most_lines", -1)),
            Node(48, 45, "label", ("text", "aa\nbb"), ("font", 1), ("wrap", true)),
            Node(50, null, "window", ("size", new RubyArray { 200, RubyNil.Value })),
            Node(51, 50, "grid", ("layout", "grid"), ("columns", new RubyArray { 50, RubyNil.Value, RubyNil.Value }), ("gap", 10)),
            Node(52, 51, "custom", ("measured", Pair(20, 10))),
            Node(53, 51, "custom", ("measured", Pair(20, 10))),
            Node(54, 51, "custom", ("measured", Pair(20, 30))),
            Node(55, 51, "custom", ("measured", Pair(20, 10))),
            Node(56, 51, "custom", ("measured", Pair(20, 10))),
            Node(60, null, "window", ("at", Pair(0, 100)), ("size", Pair(230, 100)), ("layout", "grid"), ("columns", 1), ("fit_columns", 4), ("gap", 10)),
            Node(61, 60, "custom", ("measured", Pair(60, 20))),
            Node(62, 60, "custom", ("measured", Pair(60, 20))),
            Node(63, 60, "custom", ("measured", Pair(60, 20))),
            Node(64, 60, "custom", ("measured", Pair(60, 20))),
            Node(70, null, "window", ("size", Pair(100, 60)), ("tail", true)),
            Node(73, 70, "custom", ("measured", Pair(100, 20))),
            Node(71, 70, "label", ("text", "aaaa bbbb cccc dddd"), ("font", 1), ("wrap", true)),
            Node(72, 70, "custom", ("measured", Pair(100, 20)))));

        Assert.Equal([10, 20, 116, 70], Rect(report, 10));
        Assert.Equal([18, 28, 100, 20], Rect(report, 11));
        Assert.Equal([18, 52, 100, 30], Rect(report, 12));
        Assert.Equal([0, 200, 80, 24], Rect(report, 20));
        Assert.Equal([2, 202, 30, 20], Rect(report, 21));
        Assert.Equal([38, 202, 40, 20], Rect(report, 22));

        Assert.Equal([0, 0, 100, 30], Rect(report, 30));
        Assert.Equal([50, 0, 40, 10], Rect(report, 33));
        Assert.Equal([0, 20, 40, 10], Rect(report, 34));
        Assert.Equal([50, 20, 40, 10], Rect(report, 35));
        Assert.Equal([0, 100, 70, 3 * 24], Rect(report, 40));
        Assert.Equal([2 * 24, 24, 2 * 24], new[] { Rect(report, 46)[3], Rect(report, 47)[3], Rect(report, 48)[3] });

        Assert.Equal([0, 0, 50, 30], Rect(report, 52));
        Assert.Equal([60, 0, 65, 30], Rect(report, 53));
        Assert.Equal([135, 0, 65, 30], Rect(report, 54));
        Assert.Equal([0, 40, 50, 10], Rect(report, 55));
        Assert.Equal([0, 0, 200, 50], Rect(report, 50));
        Assert.Equal(160, Rect(report, 63)[0]);
        Assert.Equal([0, 130], Rect(report, 64)[..2]);

        Assert.Equal([0, 40, 100, 20], Rect(report, 72));
        Assert.Equal([0, 16, 100, 24], Rect(report, 71));
        Assert.Equal(0, Rect(report, 73)[3]);
    }

    /// <summary>
    /// Asserts that the room a column leaves over goes to the children that grow by their shares; that
    /// a stack that runs out takes room back from its growing wrapped label, which breaks into lines,
    /// from its growing scrolling box, which scrolls, and from a child that shrinks; that a growing
    /// stack gives back no more than its part that cannot give any leaves, and a stack with a share
    /// takes more when what it holds needs it; that a steady child keeps its tallest height until the
    /// scripts set it steady again, a change that moves nothing laying nothing out anew; and that a
    /// list of whole rows takes the whole rows its room holds, fewer once a part above it grows, and
    /// keeps the part after it at the bottom edge; that a part that grows takes the free room
    /// through the plain columns it lies in, such as a table in the page of a tab; and that the gem
    /// count after a compare header's line, of no width of its own, lies right after the whole line
    /// and gets no room where the line needs all of it.
    /// </summary>
    [Fact]
    public void Room_IsSharedByGrowAndTakenBackWhenItRunsOut()
    {
        _tree.DefineFont();
        RubyHash report = _tree.Frame(Adds(
            Node(10, null, "window", ("size", Pair(200, 100))),
            Node(11, 10, "custom", ("measured", Pair(0, 10)), ("grow", 1)),
            Node(12, 10, "custom", ("measured", Pair(0, 10)), ("grow", 3)),
            Node(13, 10, "custom", ("measured", Pair(0, 10))),
            Node(20, null, "window", ("size", new RubyArray { 100, RubyNil.Value }), ("layout", "row"), ("gap", 10)),
            Node(21, 20, "custom", ("measured", Pair(40, 10))),
            Node(22, 20, "label", ("text", "aaaa bbbb cccc"), ("font", 1), ("wrap", true), ("grow", 1)),
            Node(25, null, "window", ("at", Pair(0, 100)), ("size", Pair(100, 60))),
            Node(26, 25, "custom", ("measured", Pair(100, 20))),
            Node(27, 25, "box", ("scroll", true), ("grow", 1)),
            Node(28, 27, "custom", ("measured", Pair(80, 120))),
            Node(30, null, "window", ("size", new RubyArray { 100, RubyNil.Value }), ("layout", "row")),
            Node(31, 30, "custom", ("measured", Pair(80, 10)), ("shrink", true)),
            Node(32, 30, "custom", ("measured", Pair(40, 10))),
            Node(40, null, "window", ("size", Pair(200, 60))),
            Node(41, 40, "stack", ("grow", 1)),
            Node(42, 41, "custom", ("measured", Pair(0, 50))),
            Node(43, 41, "custom", ("measured", Pair(0, 10)), ("grow", 1)),
            Node(44, 40, "custom", ("measured", Pair(0, 10))),
            Node(45, null, "window", ("at", Pair(0, 100)), ("size", Pair(200, 100))),
            Node(46, 45, "custom", ("measured", Pair(0, 10)), ("grow", 1)),
            Node(47, 45, "stack", ("max_share", 50)),
            Node(48, 47, "custom", ("measured", Pair(0, 70))),
            Node(50, null, "window", ("size", Pair(200, 200))),
            Node(51, 50, "custom", ("measured", Pair(0, 10)), ("grow", 1)),
            Node(52, 50, "custom", ("measured", Pair(0, 60)), ("steady", true)),
            Node(53, 50, "custom", ("measured", Pair(0, 150)), ("max_share", 50)),
            Node(60, null, "window", ("size", Pair(200, 110))),
            Node(61, 60, "stack", ("grow", 1)),
            Node(62, 61, "list", ("rows", 10), ("whole_rows", true), ("grow", 1), ("measured", Pair(100, 24))),
            Node(63, 60, "custom", ("measured", Pair(0, 20)))));

        Assert.Equal([0, 0, 200, 27], Rect(report, 11));
        Assert.Equal([0, 27, 200, 63], Rect(report, 12));
        Assert.Equal([0, 90, 200, 10], Rect(report, 13));
        Assert.Equal([50, 0, 50, 3 * 24], Rect(report, 22));
        Assert.Equal([0, 120, 100, 40], Rect(report, 27));
        Assert.Equal(new RubyArray { 0, 40, 120 }, report["scroll"].AsHash()[27]);
        Assert.Equal(60, Rect(report, 31)[2]);
        Assert.Equal([60, 0, 40, 10], Rect(report, 32));
        Assert.Equal([0, 0, 200, 50], Rect(report, 41));
        Assert.Equal([0, 50, 200, 10], Rect(report, 44));
        Assert.Equal([0, 130, 200, 70], Rect(report, 47));
        Assert.Equal([0, 0, 200, 40], Rect(report, 51));
        Assert.Equal([0, 40, 200, 60], Rect(report, 52));
        Assert.Equal([0, 100, 200, 100], Rect(report, 53));
        Assert.Equal([0, 0, 200, 72], Rect(report, 62));
        Assert.Equal([0, 0, 200, 72], Rect(report, 61));
        Assert.Equal([0, 90, 200, 20], Rect(report, 63));

        Assert.False(_tree.Frame(Set(52, "measured", Pair(0, 30))).ContainsKey("rects"));
        report = _tree.Frame(Set(52, "steady", true));
        Assert.Equal([0, 70, 200, 30], Rect(report, 52));
        Assert.Equal([0, 0, 200, 70], Rect(report, 51));

        report = _tree.Frame(Adds(
            Node(70, null, "window", ("size", Pair(200, 110))),
            Node(71, 70, "custom", ("measured", Pair(100, 10))),
            Node(72, 70, "list", ("rows", 20), ("index", 0), ("whole_rows", true), ("grow", 1), ("measured", Pair(100, 24)))));
        Assert.Equal([0, 10, 200, 96], Rect(report, 72));
        report = _tree.Frame(Set(71, "measured", Pair(100, 40)));
        Assert.Equal([0, 40, 200, 48], Rect(report, 72));

        report = _tree.Frame(Adds(
            Node(80, null, "window", ("size", Pair(200, 150))),
            Node(81, 80, "tabs"),
            Node(82, 81, "stack", ("layout", "row")),
            Node(83, 82, "custom", ("measured", Pair(40, 20))),
            Node(84, 81, "stack", ("tab_page", true)),
            Node(85, 84, "stack", ("grow", 1)),
            Node(86, 85, "custom", ("measured", Pair(0, 10))),
            Node(87, 85, "list", ("rows", 10), ("index", 0), ("whole_rows", true), ("grow", 1), ("measured", Pair(100, 24)))));
        Assert.Equal([0, 30, 200, 120], Rect(report, 87));

        report = _tree.Frame(Adds(
            Node(90, null, "window", ("size", new RubyArray { 300, RubyNil.Value }), ("layout", "row"), ("gap", 4)),
            Node(91, 90, "label", ("text", "equipped sword"), ("font", 1), ("grow", 1), ("shrink", true)),
            Node(92, 90, "stack", ("size", new RubyArray { 0, RubyNil.Value }), ("grow", 99)),
            Node(93, 92, "label", ("text", "three gems"), ("font", 1))));
        Assert.Equal(141, Rect(report, 91)[2]);
        Assert.Equal(145, Rect(report, 92)[0]);
        report = _tree.Frame(Set(90, "size", new RubyArray { 140, RubyNil.Value }));
        Assert.Equal(136, Rect(report, 91)[2]);
        Assert.Equal(0, Rect(report, 92)[2]);
    }

    /// <summary>
    /// Asserts that the items of a grid of twelve columns, as the markup's grid and item send it,
    /// take the share of its width their spans give at a narrow and at a wide window, an item that
    /// no longer fits a row starting the next; and that UP and DOWN move between the items that
    /// start at the same column.
    /// </summary>
    [Fact]
    public void Grid_SharesItsWidthBySpansAtEveryWidth()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(10, null, "window", ("size", new RubyArray { 306, RubyNil.Value })),
            Node(11, 10, "grid", ("layout", "grid"), ("columns", 12), ("gap", 6)),
            Node(12, 11, "stack", ("span", 4)),
            Node(13, 11, "stack", ("span", 4)),
            Node(14, 11, "stack", ("span", 4)),
            Node(15, 11, "stack", ("span", 6)),
            Node(22, 12, "button", Measured(40, 24)),
            Node(23, 13, "button", Measured(40, 24)),
            Node(24, 14, "button", Measured(40, 24)),
            Node(25, 15, "button", Measured(40, 24))));

        Assert.Equal([0, 0, 98, 24], Rect(report, 12));
        Assert.Equal([104, 0, 98, 24], Rect(report, 13));
        Assert.Equal([208, 0, 98, 24], Rect(report, 14));
        Assert.Equal([0, 30, 150, 24], Rect(report, 15));

        report = _tree.Frame(Set(10, "size", new RubyArray { 450, RubyNil.Value }));
        Assert.Equal([152, 0, 146, 24], Rect(report, 13));
        Assert.Equal([304, 0, 146, 24], Rect(report, 14));
        Assert.Equal([0, 30, 222, 24], Rect(report, 15));

        _tree.Frame(new RubyHash { { "focus", 22 } });
        Assert.Equal(25, Focus(_tree.Repeat(UiButton.Down)));
        Assert.Equal(22, Focus(_tree.Repeat(UiButton.Up)));
    }

    /// <summary>
    /// Asserts that a badge, as the markup's badge sends it, lies over the top right corner of the
    /// part it counts for, in the room its holder keeps above and right of that part, and takes no
    /// room of the holder's own.
    /// </summary>
    [Fact]
    public void Badge_LiesOverTheCornerOfThePartItCountsFor()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(10, null, "window", ("at", Pair(0, 0))),
            Node(11, 10, "stack", ("padding", new RubyArray { 8, 8, 0, 0 })),
            Node(12, 11, "button", Measured(60, 24)),
            Node(13, 11, "custom", Measured(16, 16), ("corner", true), ("mouse", false))));

        Assert.Equal([0, 0, 68, 32], Rect(report, 11));
        Assert.Equal([0, 8, 60, 24], Rect(report, 12));
        Assert.Equal([52, 0, 16, 16], Rect(report, 13));
    }

    /// <summary>
    /// Asserts that a paper with a margin, a border and a padding lies inside its margin in its
    /// column, the part after it starting after the margin, and a part in a row after its margin;
    /// that a pointer in the margin hovers the column, not the paper; that the list the paper scrolls
    /// lies inside its border and padding, which is what the paper scrolls in; and that a root's
    /// margin adds to the room its zone keeps from the screen's edge.
    /// </summary>
    [Fact]
    public void Margin_KeepsRoomAroundAPartOutsideItsSize()
    {
        _tree.Point(2, 2);
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", new RubyArray { 200, RubyNil.Value })),
            Node(2, 1, "stack", ("gap", 4)),
            Node(3, 2, "box", ("scroll", true), ("size", new RubyArray { RubyNil.Value, 80 }), ("margin", 8), ("padding", 6)),
            Node(4, 3, "list", ("rows", 10), ("row_height", 24), ("measured", Pair(100, 240))),
            Node(5, 2, "custom", Measured(100, 20)),
            Node(6, 2, "stack", ("layout", "row"), ("gap", 2)),
            Node(7, 6, "custom", Measured(30, 20), ("margin", new RubyArray { 0, 4, 0, 4 })),
            Node(8, 6, "custom", Measured(30, 20)),
            Node(9, null, "box", ("anchor", "bottom_right"), ("margin", 10)),
            Node(10, 9, "custom", Measured(50, 20))));

        Assert.Equal([8, 8, 184, 80], Rect(report, 3));
        Assert.Equal([0, 100, 200, 20], Rect(report, 5));
        Assert.Equal([4, 124, 30, 20], Rect(report, 7));
        Assert.Equal([40, 124, 30, 20], Rect(report, 8));
        Assert.Equal((1, true), (report["states"].AsHash()[2].AsInt(), report["states"].AsHash()[3].IsNil));
        Assert.Equal([14, 14, 172, 240], Rect(report, 4));
        Assert.Equal(new RubyArray { 0, 68, 240 }, report["scroll"].AsHash()[3]);
        Assert.Equal([640 - Docks.Margin - 10 - 50, 480 - Docks.Margin - 10 - 20, 50, 20], Rect(report, 9));
    }

    /// <summary>
    /// Asserts that a hud whose padding gives way keeps its whole padding around a short text, while
    /// at its most width its padding gives way so a long text gets that width, and the scripts learn
    /// how much of each side gave way.
    /// </summary>
    [Fact]
    public void PaddingThatGivesWay_LeavesItsRoomToTheTextAtTheMostWidth()
    {
        var padding = new RubyArray { 2, 8, 2, 8, 2, 8, 2, 8 };
        var most = new RubyArray { 320, RubyNil.Value };
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "box", ("at", Pair(0, 0)), ("padding", padding), ("max", most)),
            Node(2, 1, "custom", Measured(400, 24)),
            Node(3, null, "box", ("at", Pair(0, 100)), ("padding", padding), ("max", most)),
            Node(4, 3, "custom", Measured(100, 24))));

        Assert.Equal([0, 0, 320, 28], Rect(report, 1));
        Assert.Equal([0, 2, 320, 24], Rect(report, 2));
        Assert.Equal(new RubyArray { 0, 8, 0, 8 }, report["padding_cut"].AsHash()[1]);
        Assert.Equal([0, 100, 116, 28], Rect(report, 3));
        Assert.Equal([8, 102, 100, 24], Rect(report, 4));
    }

    /// <summary>
    /// Asserts that a window whose padding gives way keeps the full form of a part while what it
    /// holds fits once its padding gave way, and shows the compact form only below that.
    /// </summary>
    [Fact]
    public void PaddingThatGivesWay_GivesWayBeforeACompactForm()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 100)), ("padding", new RubyArray { 20, 0, 20, 0, 20, 0, 20, 0 })),
            Node(2, 1, "stack", ("forms", new RubyArray { 0, 1 })),
            Node(3, 2, "custom", Measured(100, 80)),
            Node(4, 2, "custom", Measured(100, 20))));
        Assert.Equal([0, 10, 200, 80], Rect(report, 3));
        Assert.Equal([0, 0], Rect(report, 4)[2..]);

        report = _tree.Frame(Set(1, "size", Pair(200, 70)));
        Assert.Equal([0, 0], Rect(report, 3)[2..]);
        Assert.Equal([0, 20, 200, 20], Rect(report, 4));
    }

    /// <summary>
    /// Asserts that a container stands in the middle of a wide window at its most width, that one of
    /// fixed widths takes the largest that fits a narrower window, and that a window sized to what it
    /// holds is as wide as the container's named width.
    /// </summary>
    [Fact]
    public void Container_StandsInTheMiddleAtItsWidth()
    {
        var widths = new RubyArray { 240, 320, 400, 480, 560, 640 };
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0)), ("size", new RubyArray { 640, RubyNil.Value })),
            Node(2, 1, "stack", ("centered", true), ("max", new RubyArray { 320, RubyNil.Value }), ("padding", new RubyArray { 0, 8, 0, 8 })),
            Node(3, 2, "custom", Measured(100, 20)),
            Node(4, null, "window", ("at", Pair(0, 100)), ("size", new RubyArray { 500, RubyNil.Value })),
            Node(5, 4, "stack", ("centered", true), ("widths", widths)),
            Node(6, 5, "custom", Measured(100, 20)),
            Node(7, null, "window", ("at", Pair(0, 200))),
            Node(8, 7, "stack", ("centered", true), ("max", new RubyArray { 480, RubyNil.Value })),
            Node(9, 8, "custom", Measured(100, 20))));

        Assert.Equal([160, 0, 320, 20], Rect(report, 2));
        Assert.Equal([168, 0, 304, 20], Rect(report, 3));
        Assert.Equal([10, 100, 480, 20], Rect(report, 5));
        Assert.Equal(480, Rect(report, 7)[2]);
    }

    /// <summary>
    /// Asserts that a window that gets smaller shows the compact form of the first step, then that of
    /// the second, each form it leaves out laid out without room; that the step stays while a form's
    /// content shrinks and the window keeps its size; and that the parts come back whole once the
    /// window is large again.
    /// </summary>
    [Fact]
    public void CompactForms_ComeInStepByStepAsTheWindowGetsSmaller()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 200))),
            Node(2, 1, "custom", ("measured", Pair(100, 40))),
            Node(3, 1, "stack", ("forms", new RubyArray { 0, 1 })),
            Node(4, 3, "custom", ("measured", Pair(100, 60))),
            Node(5, 3, "custom", ("measured", Pair(100, 20))),
            Node(6, 1, "stack", ("forms", new RubyArray { 0, 2 })),
            Node(7, 6, "custom", ("measured", Pair(100, 40))),
            Node(8, 6, "custom", ("measured", Pair(100, 10)))));
        Assert.Equal([0, 40, 200, 60], Rect(report, 4));
        Assert.Equal([0, 40, 0, 0], Rect(report, 5));
        Assert.Equal([0, 100, 200, 40], Rect(report, 7));

        report = _tree.Frame(Set(1, "size", Pair(200, 120)));
        Assert.Equal([0, 40, 0, 0], Rect(report, 4));
        Assert.Equal([0, 40, 200, 20], Rect(report, 5));
        Assert.Equal([0, 60, 200, 40], Rect(report, 7));

        report = _tree.Frame(Set(1, "size", Pair(200, 80)));
        Assert.Equal([0, 60, 0, 0], Rect(report, 7));
        Assert.Equal([0, 60, 200, 10], Rect(report, 8));

        report = _tree.Frame(Set(1, "size", Pair(200, 120)));
        report = _tree.Frame(Set(4, "measured", Pair(100, 30)));
        Assert.False(report.ContainsKey("rects"));

        report = _tree.Frame(Set(1, "size", Pair(200, 200)));
        Assert.Equal([0, 40, 200, 30], Rect(report, 4));
        Assert.Equal([0, 70, 200, 40], Rect(report, 7));
    }

    /// <summary>
    /// Asserts that, as the item dialog's comparison sends its gems, a part's forms whose picked form
    /// the scripts hide get a place without room at every step: the gem count, hidden until the gems
    /// fold, and the row of gems, which hides once they fold.
    /// </summary>
    [Fact]
    public void CompactForms_PlaceAPartWhosePickedFormIsHidden()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 200))),
            Node(2, 1, "custom", ("measured", Pair(100, 40))),
            Node(3, 1, "stack", ("forms", new RubyArray { 0, 1 })),
            Node(4, 3, "custom", ("measured", Pair(100, 10)), ("visible", false)),
            Node(5, 3, "custom", ("measured", Pair(100, 10))),
            Node(6, 1, "stack", ("forms", new RubyArray { 0, 1 })),
            Node(7, 6, "custom", ("measured", Pair(100, 60))),
            Node(8, 6, "custom", ("measured", Pair(100, 60)), ("visible", false))));
        Assert.Equal([0, 0, 0, 0], Rect(report, 3));
        Assert.Equal([0, 40, 200, 60], Rect(report, 6));

        report = _tree.Frame(Set(1, "size", Pair(200, 80)));
        Assert.Equal([0, 40, 200, 10], Rect(report, 3));
        Assert.Equal([0, 0, 0, 0], Rect(report, 6));
    }

    /// <summary>
    /// Asserts that a dialog whose comparison has a hidden copy for the list's tall item opens at the
    /// step the tall item needs while the cursor rests on a short one, the copy laid out in the
    /// comparison's place; that moving the cursor to the tall item and back keeps the step; and that
    /// a larger dialog picks its step anew.
    /// </summary>
    [Fact]
    public void CompactFor_OpensAtTheStepOfTheTallestCopyAndKeepsItAsTheCursorMoves()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(200, 120))),
            Node(2, 1, "custom", ("measured", Pair(100, 40))),
            Node(3, 1, "stack", ("measures", true)),
            Node(4, 3, "stack", ("forms", new RubyArray { 0, 1 })),
            Node(5, 4, "custom", ("measured", Pair(100, 60))),
            Node(6, 4, "custom", ("measured", Pair(100, 20))),
            Node(7, 3, "stack", ("forms", new RubyArray { 0, 1 }), ("visible", false)),
            Node(8, 7, "custom", ("measured", Pair(100, 100))),
            Node(9, 7, "custom", ("measured", Pair(100, 20)))));
        Assert.Equal([0, 40, 0, 0], Rect(report, 5));
        Assert.Equal([0, 40, 200, 20], Rect(report, 6));
        Assert.Equal([0, 40, 200, 20], Rect(report, 9));

        report = _tree.Frame(Set(5, "measured", Pair(100, 100)));
        Assert.False(report.ContainsKey("rects"));
        report = _tree.Frame(Set(5, "measured", Pair(100, 60)));
        Assert.False(report.ContainsKey("rects"));

        report = _tree.Frame(Set(1, "size", Pair(200, 200)));
        Assert.Equal([0, 40, 200, 60], Rect(report, 5));
    }

    /// <summary>
    /// Asserts that a root nothing changed in keeps its places without being told again, that a
    /// label measured before its font knew all its characters is measured anew once the widths come,
    /// and that a centered root moves to the middle of a screen that changed size.
    /// </summary>
    [Fact]
    public void Layout_RedrawsOnlyWhatLearnedWidthsOrTheScreenChanged()
    {
        _tree.Ui.Value(UiText.GlyphsTopic, new RubyHash
        {
            { "key", 1 }, { "name", "VL Gothic" }, { "size", 20 }, { "bold", false }, { "widths", new RubyHash { { 'a', 10 } } },
        });
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("at", Pair(0, 0))),
            Node(2, 1, "label", ("text", "ab"), ("font", 1)),
            Node(3, null, "window", ("center", true), ("size", Pair(100, 50)))));
        Assert.Equal(30, Rect(report, 2)[2]);
        Assert.Equal([270, 215, 100, 50], Rect(report, 3));
        Assert.True(_tree.Frame()["rects"].IsNil);

        _tree.Ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "widths", new RubyHash { { 'b', 10 } } } });
        Assert.Equal(20, Rect(_tree.Frame(), 2)[2]);

        report = _tree.Frame(new RubyHash { { "screen", Pair(800, 600) } });
        Assert.Equal([350, 275, 100, 50], Rect(report, 3));
    }

    /// <summary>
    /// Asserts that a property the tree does not know, a kind it does not know, an id taken and a bad
    /// value are each told with why while the rest of the batch is taken, the children of a component
    /// added with a bad property included, and that a batch the tree cannot read empties the tree and
    /// asks the scripts to send it again, which then goes in under the same ids.
    /// </summary>
    [Fact]
    public void Batch_TakesTheGoodChangesAndAsksAgainForOneItCannotRead()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("colour", 3), ("size", Pair(100, 50))),
            Node(2, 1, "custom", ("measured", Pair(40, 10))),
            Node(3, null, "sparkle"),
            Node(1, null, "window")));

        Assert.Equal(
            new RubyArray
            {
                new RubyArray { 1, "No component property is named colour.", false },
                new RubyArray { 3, "No component kind is named sparkle.", true },
                new RubyArray { 1, "A component with the id 1 was added already.", true },
            },
            report["refused"]);
        Assert.Equal([0, 0, 100, 50], Rect(report, 1));
        Assert.Equal([0, 0, 100, 10], Rect(report, 2));

        report = _tree.Frame(Set(1, ("gap", -4), ("size", Pair(120, 50))));
        Assert.Equal(new RubyArray { new RubyArray { 1, "The gap of a component cannot be -4.", false } }, report["refused"]);
        Assert.Equal([0, 0, 120, 50], Rect(report, 1));

        Assert.False(_tree.Frame(new RubyHash { { "add", 5 } })["resync"].IsNil);
        report = _tree.Frame(Adds(Node(1, null, "window", ("size", Pair(80, 40)))));
        Assert.True(report["refused"].IsNil);
        Assert.Equal([0, 0, 80, 40], Rect(report, 1));
    }

    /// <summary>
    /// Asserts that a root's least and most size clamp both the size it fits to and the size the
    /// player drags it to with Alt.
    /// </summary>
    [Fact]
    public void MinAndMax_ClampAFitAndADrag()
    {
        _tree.Ui.Value(LayoutModel.RegisterTopic, new RubyArray { "sample", "Sample", 0, 0, 0, 0, "both", true, RubyNil.Value });
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("layout_id", "sample"), ("movable", true), ("resizable", true), ("min", Pair(100, 50)), ("max", Pair(150, 80))),
            Node(2, 1, "custom", ("measured", Pair(300, 10)))));
        Assert.Equal([0, 0, 150, 50], Rect(report, 1));

        _tree.Input.Down.UnionWith([LayoutModel.AltKey, LeftButton]);
        _tree.Point(149, 49);
        _tree.Frame(offers: [new RubyArray { "sample", 0, 0, 150, 50, 200 }]);
        _tree.Point(349, 249);
        report = _tree.Frame(offers: [new RubyArray { "sample", 0, 0, 150, 50, 200 }]);

        Assert.Equal([0, 0, 150, 80], Rect(report, 1));
    }

    /// <summary>
    /// Asserts that the equip dialog in the game's window frame, a search bar over a list of two
    /// columns that fills, then a divider, a steady comparison kept to the share the dialog gives it
    /// and a key help line, gives the list the whole lines its room holds and docks the rest at the
    /// dialog's bottom edge with less than a line between them, as the player walks the weapons: the
    /// tallest folded leaves the list 9 rows, one a little over the share it rounds up to gives up a
    /// row on a shorter screen, one just under the room the list leaves keeps its whole height in the
    /// share rounded up from it, and the tallest unfolded keeps to its share.
    /// </summary>
    [Fact]
    public void EquipDialog_FillsTheListAndDocksTheComparisonAtTheBottom()
    {
        RubyHash placed = Placed(Adds(
            Node(1, null, "window", ("size", Pair(640, 480)), ("padding", new RubyArray { 40, 12, 12, 12 }), ("gap", 4)),
            Node(2, 1, "stack", ("grow", 1), ("gap", 4)),
            Node(3, 2, "custom", ("measured", Pair(200, 26))),
            Node(4, 2, "list", ("rows", 40), ("row_cells", 2), ("index", 0), ("whole_rows", true), ("grow", 1), ("measured", Pair(100, 24))),
            Node(5, 1, "custom", ("measured", Pair(0, 5))),
            Node(6, 1, "custom", ("measured", Pair(0, 127)), ("steady", true), ("max_share", 32)),
            Node(7, 1, "custom", ("measured", Pair(0, 24)))));
        AssertEquipDialog(placed, 480, 216, [12, 313, 616, 127]);
        Assert.False(_tree.Frame(Set(6, "measured", Pair(0, 60))).ContainsKey("rects"));

        Placed(Set(1, "size", Pair(640, 400)));
        AssertEquipDialog(Placed(Set(6, ("measured", Pair(0, 149)), ("steady", true), ("max_share", 43))), 400, 120, [12, 211, 616, 149]);
        Placed(Set(1, "size", Pair(640, 480)));
        AssertEquipDialog(Placed(Set(6, ("measured", Pair(0, 140)), ("steady", true), ("max_share", 33))), 480, 216, [12, 300, 616, 140]);
        AssertEquipDialog(Placed(Set(6, ("measured", Pair(0, 214)), ("steady", true), ("max_share", 32))), 480, 216, [12, 304, 616, 136]);
    }

    /// <summary>
    /// Asserts that an options list filling a window of the screen's size shows as many whole rows as
    /// its room holds above the line and the help line of two small lines, which stay at the
    /// window's foot.
    /// </summary>
    [Fact]
    public void OptionsList_FillsTheWindowWithWholeRowsOverTheHelp()
    {
        RubyHash tree = Adds(
            Node(1, null, "window", ("size", Pair(640, 400)), ("padding", new RubyArray { 40, 12, 12, 12 }), ("gap", 4)),
            Node(2, 1, "stack", ("grow", 1), ("gap", 4)),
            Node(3, 2, "list", ("rows", 40), ("index", 1), ("heading_rows", new RubyArray { 0 }), ("grow", 1), ("whole_rows", true), ("measured", Pair(120, 24))),
            Node(4, 2, "divider", ("padding", new RubyArray { 2, 0, 2, 0 }), ("measured", Pair(0, 1))),
            Node(5, 2, "label", ("size", new RubyArray { RubyNil.Value, 40 }), ("measured", Pair(0, 20)), ("wrap", true), ("row_height", 20)));
        tree["screen"] = Pair(640, 400);

        RubyHash report = _tree.Frame(tree);

        Assert.Equal([12, 40, 616, 12 * 24], Rect(report, 3));
        Assert.Equal([12, 348, 616, 40], Rect(report, 5));
    }

    /// <summary>
    /// Asserts that the save's mods dialog, 520 wide and as high as what it holds up to 360, with a
    /// line, a list of six rows shown, the status line, the gauge and a row of three buttons at its
    /// right end, lies in the middle of the screen and shrinks with a shorter list.
    /// </summary>
    [Fact]
    public void SaveModsDialog_FitsItsContentInTheMiddle()
    {
        RubyHash tree = Adds(
            Node(1, null, "dialog", ("size", new RubyArray { 520, RubyNil.Value }), ("max", Pair(520, 360)), ("center", true), ("padding", new RubyArray { 40, 12, 12, 12 }), ("gap", 4)),
            Node(2, 1, "custom", ("measured", Pair(368, 40))),
            Node(3, 1, "list", ("rows", 8), ("index", 0), ("leave_ends", true), ("measured", Pair(120, 144))),
            Node(4, 1, "custom", ("measured", Pair(0, 20))),
            Node(5, 1, "custom", ("measured", Pair(96, 12))),
            Node(6, 1, "stack", ("layout", "row"), ("justify", "end"), ("gap", 4)),
            Node(7, 6, "button", ("measured", Pair(225, 24))),
            Node(8, 6, "button", ("measured", Pair(110, 24))),
            Node(9, 6, "button", ("measured", Pair(60, 24))));
        tree["screen"] = Pair(640, 400);

        RubyHash report = _tree.Frame(tree);
        int top = (400 - 308) / 2;

        Assert.Equal([60, top, 520, 308], Rect(report, 1));
        Assert.Equal([72, top + 84, 496, 144], Rect(report, 3));
        Assert.Equal([508, top + 272, 60, 24], Rect(report, 9));
        Assert.Equal(165, Rect(report, 7)[0]);

        report = _tree.Frame(Set(3, "measured", Pair(120, 48)));
        Assert.Equal([60, (400 - 212) / 2, 520, 212], Rect(report, 1));
    }

    /// <summary>
    /// Asserts that the Mods screen as its script builds it, a window of the screen's size with its
    /// tabs over a page whose list of twenty mods asks for the room of all its rows, gives the list
    /// the whole rows its page holds over the key help, and once the restart bar shows keeps the
    /// window and the bar at its foot on the screen, the list giving back the room the bar takes.
    /// </summary>
    [Fact]
    public void ModsScreen_FillsTheListAboveTheRestartBar()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(640, 480)), ("min", Pair(640, 400)), ("max", Pair(640, 480)), ("resizable", "height"),
                 ("padding", new RubyArray { 40, 12, 12, 12 }), ("gap", 4)),
            Node(2, 1, "tabs", ("grow", 1), ("gap", 4)),
            Node(3, 2, "stack", ("layout", "row"), ("gap", 8)),
            Node(4, 3, "button", ("measured", Pair(60, 28))),
            Node(5, 2, "stack", ("gap", 4), ("tab_page", true)),
            Node(6, 5, "stack", ("layout", "row"), ("gap", 8), ("grow", 1)),
            Node(7, 6, "list", ("rows", 20), ("index", 1), ("heading_rows", new RubyArray { 0 }), ("whole_rows", true), ("grow", 1), ("shrink", true),
                 ("size", new RubyArray { 302, RubyNil.Value }), ("measured", Pair(336, 20 * 24))),
            Node(8, 6, "stack", ("grow", 1), ("gap", 8)),
            Node(9, 8, "custom", ("measured", Pair(240, 24))),
            Node(10, 5, "custom", ("measured", Pair(600, 24))),
            Node(11, 1, "stack", ("layout", "row"), ("gap", 4), ("padding", new RubyArray { 2, 4, 2, 8 }), ("visible", false)),
            Node(12, 11, "custom", ("measured", Pair(336, 20)), ("grow", 1)),
            Node(13, 11, "button", ("measured", Pair(99, 24)))));
        Assert.Equal([0, 0, 640, 480], Rect(report, 1));
        Assert.Equal([12, 72, 335, 15 * 24], Rect(report, 7));
        Assert.Equal([12, 444, 616, 24], Rect(report, 10));

        report = _tree.Frame(Set(11, "visible", true));
        Assert.False(report["rects"].AsHash().ContainsKey(1));
        Assert.Equal([12, 72, 335, 14 * 24], Rect(report, 7));
        Assert.Equal([12, 440, 616, 28], Rect(report, 11));
    }

    /// <summary>
    /// Asserts that the mod browser's Mods tab in the short window with the restart bar shows its
    /// search row over a list of whole rows, the filters' list beside it as many whole rows, and a
    /// pane whose picture keeps between its least and largest height and whose text box keeps at
    /// least two lines down to the bar, each page of the strip 302 wide, and that the list switched
    /// to cards shows whole lines of cards.
    /// </summary>
    [Fact]
    public void ModBrowser_FillsWholeLinesAndKeepsThePaneInItsRoom()
    {
        RubyHash report = _tree.Frame(Adds(
            Node(1, null, "window", ("size", Pair(640, 400)), ("padding", new RubyArray { 40, 12, 12, 12 }), ("gap", 4)),
            Node(2, 1, "tabs", ("grow", 1), ("gap", 4)),
            Node(3, 2, "stack", ("layout", "row"), ("gap", 8)),
            Node(4, 3, "button", ("measured", Pair(60, 28))),
            Node(5, 2, "stack", ("grow", 1), ("gap", 4)),
            Node(6, 5, "slides", ("shown", 2), ("gap", 12), ("grow", 1), ("slide_keys", true)),
            Node(30, 6, "stack", ("gap", 4)),
            Node(31, 30, "stack", ("layout", "row"), ("gap", 4)),
            Node(32, 31, "button", ("measured", Pair(48, 24))),
            Node(33, 30, "list", ("rows", 40), ("index", 1), ("whole_rows", true), ("grow", 1), ("measured", Pair(120, 24))),
            Node(7, 6, "stack", ("gap", 4)),
            Node(8, 7, "stack", ("layout", "row"), ("gap", 4)),
            Node(34, 8, "button", ("measured", Pair(84, 24))),
            Node(9, 8, "text_field", ("measured", Pair(48, 24)), ("grow", 1)),
            Node(10, 8, "button", ("measured", Pair(82, 24))),
            Node(11, 7, "list", ("rows", 40), ("index", 1), ("row_cells", 1), ("row_height", 24), ("whole_rows", true), ("grow", 1), ("measured", Pair(120, 24))),
            Node(12, 6, "stack", ("gap", 6)),
            Node(13, 12, "picture", ("measured", Pair(0, 0)), ("grow", 1), ("min", Pair(0, 96)), ("max", Pair(640, 136))),
            Node(14, 12, "custom", ("measured", Pair(0, 24))),
            Node(15, 12, "custom", ("measured", Pair(0, 54))),
            Node(16, 12, "stack", ("layout", "row"), ("gap", 4)),
            Node(17, 16, "button", ("measured", Pair(90, 24))),
            Node(18, 12, "custom", ("measured", Pair(0, 18))),
            Node(19, 12, "box", ("scroll", true), ("grow", 2), ("min", Pair(0, 36)), ("measured", Pair(0, 0))),
            Node(20, 1, "stack", ("layout", "row"), ("gap", 4), ("padding", new RubyArray { 2, 4, 2, 8 })),
            Node(21, 20, "custom", ("measured", Pair(0, 20)), ("grow", 1)),
            Node(22, 20, "button", ("measured", Pair(90, 24)))));

        Assert.Equal([326, 72, 302, 24], Rect(report, 8));
        Assert.Equal([326, 100, 302, 10 * 24], Rect(report, 11));
        Assert.Equal([12, 100, 302, 10 * 24], Rect(report, 33));
        Assert.Equal(302, Rect(report, 12)[2]);
        Assert.InRange(Rect(report, 13)[3], 96, 136);
        Assert.InRange(Rect(report, 19)[3], 36, 400);
        Assert.Equal(356, Rect(report, 19)[1] + Rect(report, 19)[3]);

        report = _tree.Frame(Set(11, ("row_cells", 2), ("row_height", 116), ("measured", Pair(120, 116))));
        Assert.Equal([326, 100, 302, 2 * 116], Rect(report, 11));
    }

    /// <summary>
    /// Runs a frame and notes the places it tells, since a frame tells only the places that moved.
    /// </summary>
    /// <param name="tree">The tree's input.</param>
    /// <returns>A report with the place of every component told so far.</returns>
    private RubyHash Placed(RubyHash tree)
    {
        RubyHash report = _tree.Frame(tree);
        if (!report["rects"].IsNil)
        {
            foreach ((RubyValue id, RubyValue rect) in report["rects"].AsHash())
            {
                _places[id] = rect;
            }
        }

        return new RubyHash { { "rects", _places } };
    }

    /// <summary>
    /// Asserts where the equip dialog's parts lie.
    /// </summary>
    /// <param name="report">The tree's report.</param>
    /// <param name="height">The dialog's height.</param>
    /// <param name="listHeight">The height the list takes.</param>
    /// <param name="compareRect">Where the comparison lies.</param>
    private static void AssertEquipDialog(RubyHash report, int height, int listHeight, int[] compareRect)
    {
        int[] list = Rect(report, 4);
        int[] help = Rect(report, 7);
        Assert.Equal(listHeight, list[3]);
        Assert.InRange(Rect(report, 5)[1] - 4 - (list[1] + list[3]), 0, 23);
        Assert.Equal(compareRect, Rect(report, 6));
        Assert.Equal(compareRect[1] + compareRect[3] + 4, help[1]);
        Assert.Equal(height - 12, help[1] + help[3]);
    }
}
