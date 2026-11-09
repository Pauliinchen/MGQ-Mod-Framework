//----------------------------------------------------------------
//  TreeDragTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Covered a carry that ends as a dialog opens or the focus leaves the container
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the drag and drop between the drop zones of a drop container in the component tree,
/// through a formation of the party: a front row and a reserve side by side, rearranged by the keys
/// and by a drag of the pointer.
/// </summary>
public sealed class TreeDragTests
{
    /// <summary>
    /// Asserts that confirm picks a member up, DOWN moves the place along the front row and past its
    /// end into the reserve, confirm puts the member down there and tells the container; that cancel
    /// puts a member carried back without a drop; and that a drag of the pointer from a member over
    /// the reserve carries it there, letting go puts it down at the place under the pointer, and
    /// letting go outside the zones puts it back.
    /// </summary>
    [Fact]
    public void Formation_IsRearrangedByTheKeysAndByADrag()
    {
        var tree = new TreeHarness();
        RubyHash report = tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(300, 200))),
            Node(2, 1, "stack", ("drop_container", true), ("layout", "row"), ("grow", 1)),
            Node(3, 2, "box", ("drop_zone", true), ("grow", 1), ("padding", 4)),
            Node(4, 3, "box", ("drag", true), ("focusable", true), ("clickable", true), Measured(80, 20)),
            Node(5, 3, "box", ("drag", true), ("focusable", true), ("clickable", true), Measured(80, 20)),
            Node(6, 2, "box", ("drop_zone", true), ("grow", 1), ("padding", 4)),
            Node(7, 6, "box", ("drag", true), ("focusable", true), ("clickable", true), Measured(80, 20))));
        int[] reserve = Rect(report, 6);
        int[] tamamo = Rect(report, 7);
        int[] alice = Rect(report, 5);
        tree.Frame(new RubyHash { { "focus", 4 } });

        Assert.Equal(["4 lift", "3 target 0"], Events(tree.Press(UiButton.Confirm)));
        Assert.Equal(["3 target 1"], Events(tree.Press(UiButton.Down)));
        Assert.Equal(["3 target -1", "6 target 0"], Events(tree.Press(UiButton.Down)));
        Assert.Equal(["4 unlift", "6 target -1", "2 drop 4 3 6 0"], Events(tree.Press(UiButton.Confirm)));

        tree.Press(UiButton.Confirm);
        Assert.Equal(["4 unlift", "3 target -1"], Events(tree.Press(UiButton.Cancel)));

        tree.Point(alice[0] + 10, alice[1] + 10);
        tree.Input.Down.Add(LeftButton);
        tree.Frame();
        tree.Point(tamamo[0] + 10, tamamo[1] + tamamo[3] - 2);
        Assert.Equal(["5 lift", "3 target 1", "3 target -1", "6 target 1"], Moves(tree.Frame()));
        tree.Input.Down.Remove(LeftButton);
        Assert.Equal(["5 unlift", "6 target -1", "2 drop 5 3 6 1"], Moves(tree.Frame()));

        tree.Input.Down.Add(LeftButton);
        tree.Frame();
        tree.Point(tamamo[0] + 20, tamamo[1] + 5);
        Assert.Contains("7 lift", Moves(tree.Frame()));
        tree.Point(reserve[0] + reserve[2] + 10, 10);
        tree.Frame();
        tree.Input.Down.Remove(LeftButton);
        Assert.Equal(["7 unlift", "6 target -1"], Moves(tree.Frame()));
    }

    /// <summary>
    /// Asserts that a member picked up by confirm goes back to its zone as a dialog opens above, so
    /// confirm clicks the dialog's button and cancel closes the dialog without a drop; and that it
    /// goes back as well once the focus moves to a button outside the container.
    /// </summary>
    [Fact]
    public void Carry_EndsWhenTheFocusLeavesTheContainer()
    {
        var tree = new TreeHarness();
        tree.Frame(Adds(
            Node(1, null, "window", ("layer", true), ("at", Pair(0, 0)), ("size", Pair(300, 200))),
            Node(2, 1, "stack", ("drop_container", true), ("layout", "row"), ("grow", 1)),
            Node(3, 2, "box", ("drop_zone", true), ("grow", 1), ("padding", 4)),
            Node(4, 3, "box", ("drag", true), ("focusable", true), ("clickable", true), Measured(80, 20)),
            Node(5, 2, "box", ("drop_zone", true), ("grow", 1), ("padding", 4)),
            Node(6, 1, "button", Measured(60, 20))));
        tree.Frame(new RubyHash { { "focus", 4 } });
        tree.Press(UiButton.Confirm);

        Assert.Equal(["4 unlift", "3 target -1"], Moves(tree.Frame(Adds(Node(7, null, "dialog"), Node(8, 7, "button", Measured(40, 20))))));
        Assert.Equal(["8 click"], Moves(tree.Press(UiButton.Confirm)));
        Assert.Equal(["7 close"], Moves(tree.Press(UiButton.Cancel)));

        tree.Press(UiButton.Confirm);
        Assert.Equal(["4 unlift", "3 target -1"], Moves(tree.Frame(new RubyHash { { "focus", 6 } })));
    }

    /// <summary>
    /// Reads the events of a report that tell the drag and drop, without those of the pointer's
    /// hover and the focus.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <returns>The events.</returns>
    private static List<string> Moves(RubyHash report) => Events(report).FindAll(text => !text.Contains(" hover ") && !text.EndsWith(" focus") && !text.EndsWith(" blur"));
}
