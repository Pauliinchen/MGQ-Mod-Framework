//----------------------------------------------------------------
//  ComponentTreeDrag.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Put the carried item back once the focus leaves its container or a root above opens
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The drag and drop of the tree between the drop zones of a drop container: an item is picked up
/// by confirm or by dragging it with the pointer, moved by the arrows or the pointer to a place in
/// a zone, and put down there by confirm or by letting go; cancel puts it back. The scripts are
/// told "lift" and "unlift" on the item, "target" with the place on the zone it would go to (-1
/// for none) and "drop" with the item, the zone it came from, the zone it goes to and its place
/// there on the container. The carry ends with the item put back once the focus leaves the drop
/// container or a root above opens.
/// </summary>
internal sealed partial class ComponentTree
{
    /// <summary>
    /// Pixels the pointer moves with the left button held on an item before it picks the item up.
    /// </summary>
    private const int DragStart = 4;

    /// <summary>
    /// The item carried, the zone it would go to and its place there, null while nothing is carried.
    /// </summary>
    private (Node Item, Node Zone, int Place)? _carried;

    /// <summary>
    /// Whether the pointer carries the item, which letting go of the left button puts down.
    /// </summary>
    private bool _carriedByPointer;

    /// <summary>
    /// Where the left button went down on an item, which a drag from there picks up; null for none.
    /// </summary>
    private (Node Item, int X, int Y)? _dragFrom;

    /// <summary>
    /// Takes confirm on an item of a drop zone: picks it up, or puts down the item carried.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    /// <returns>Whether confirm went to the drag and drop.</returns>
    private bool ConfirmDrag(Node focus)
    {
        if (CarriedNow() is { } carried)
        {
            PutDown(carried);
            return true;
        }

        if (!focus.Drag || !Focus.Enabled(focus) || ZoneOf(focus) is not { } zone)
        {
            return false;
        }

        Lift(focus, zone, byPointer: false);
        return true;
    }

    /// <summary>
    /// Takes cancel while an item is carried: it goes back where it came from.
    /// </summary>
    /// <returns>Whether an item was carried.</returns>
    private bool CancelDrag()
    {
        if (CarriedNow() is not { } carried)
        {
            return false;
        }

        EndCarry(carried);
        Cue(UiCue.Cancel);
        return true;
    }

    /// <summary>
    /// Puts the item carried back where it came from once the focus goes to a component outside its
    /// drop container, so confirm and cancel act on the focused part again.
    /// </summary>
    /// <param name="node">The component getting the focus.</param>
    private void EndCarryOutside(Node node)
    {
        if (CarriedNow() is { } carried && !Inside(node, ContainerOf(carried.Zone)!))
        {
            EndCarry(carried);
        }
    }

    /// <summary>
    /// Puts the item carried back where it came from once a root opens above its root.
    /// </summary>
    private void EndCarryUnder()
    {
        if (CarriedNow() is { } carried && Blocked(Focus.RootOf(carried.Item)))
        {
            EndCarry(carried);
        }
    }

    /// <summary>
    /// Takes the arrows while an item is carried: along a zone's items they move its place, and past
    /// the zone's ends, or across, to the zone before or after in the container.
    /// </summary>
    /// <param name="vertical">-1 up, 1 down, 0 neither.</param>
    /// <param name="horizontal">-1 left, 1 right, 0 neither.</param>
    /// <returns>Whether an item was carried, which takes the arrows.</returns>
    private bool CarryArrows(int vertical, int horizontal)
    {
        if (CarriedNow() is not { } carried)
        {
            return false;
        }

        bool row = carried.Zone.Layout == FlowLayout.Row;
        int along = row ? horizontal : vertical;
        int across = row ? vertical : horizontal;
        List<Node> zones = ZonesOf(ContainerOf(carried.Zone)!);
        int zoneAt = zones.IndexOf(carried.Zone);
        (Node Zone, int Place)? next = null;
        if (along != 0)
        {
            int place = carried.Place + along;
            next = place >= 0 && place <= Places(carried.Zone, carried.Item)
                ? (carried.Zone, place)
                : ZoneAt(zones, zoneAt + along) is { } beside ? (beside, along < 0 ? Places(beside, carried.Item) : 0) : null;
        }
        else if (across != 0 && ZoneAt(zones, zoneAt + across) is { } beside)
        {
            next = (beside, Math.Min(carried.Place, Places(beside, carried.Item)));
        }

        if (along == 0 && across == 0)
        {
            return true;
        }

        if (next is { } moved)
        {
            Target(carried.Item, moved.Zone, moved.Place);
            Cue(UiCue.Cursor);
        }
        else
        {
            Cue(UiCue.Buzzer);
        }

        return true;
    }

    /// <summary>
    /// Notes a left press on an item of a drop zone, which a drag from there picks up.
    /// </summary>
    /// <param name="node">The component pressed.</param>
    /// <param name="point">Where the pointer is.</param>
    private void PressDrag(Node node, (int X, int Y) point)
    {
        _dragFrom = DragItemAround(node) is { } item ? (item, point.X, point.Y) : null;
    }

    /// <summary>
    /// Follows the pointer for the drag and drop: a drag from a pressed item picks it up, and the
    /// item carried goes to the place in the zone under the pointer.
    /// </summary>
    /// <param name="point">Where the pointer is, null for off the screen.</param>
    private void FollowDrag((int X, int Y)? point)
    {
        if (point is not { } at)
        {
            return;
        }

        if (_carried is null && _dragFrom is { } from && _input.LeftDown && _nodes.ContainsKey(from.Item.Id)
            && Math.Abs(at.X - from.X) + Math.Abs(at.Y - from.Y) >= DragStart && Focus.Enabled(from.Item) && ZoneOf(from.Item) is { } home)
        {
            _dragFrom = null;
            _pressed = null;
            Lift(from.Item, home, byPointer: true);
        }

        if (_carriedByPointer && CarriedNow() is { } carried && ZoneUnder(ContainerOf(carried.Zone)!, at) is { } zone)
        {
            int place = PlaceAt(zone, carried.Item, at);
            if (zone != carried.Zone || place != carried.Place)
            {
                Target(carried.Item, zone, place);
            }
        }
    }

    /// <summary>
    /// Takes the left button let go while the pointer carries an item: it goes down where it would
    /// go, over a zone, and back where it came from elsewhere.
    /// </summary>
    /// <param name="point">Where the pointer is.</param>
    /// <returns>Whether the pointer carried an item.</returns>
    private bool ReleaseDrag((int X, int Y)? point)
    {
        _dragFrom = null;
        if (!_carriedByPointer || CarriedNow() is not { } carried)
        {
            return false;
        }

        if (point is { } at && ZoneUnder(ContainerOf(carried.Zone)!, at) is not null)
        {
            PutDown(carried);
        }
        else
        {
            EndCarry(carried);
            Cue(UiCue.Cancel);
        }

        return true;
    }

    /// <summary>
    /// Tells the item carried while it, its zone and their container are still there; forgets one
    /// that is gone.
    /// </summary>
    /// <returns>The item carried, null for none.</returns>
    private (Node Item, Node Zone, int Place)? CarriedNow()
    {
        if (_carried is { } carried && (!_nodes.ContainsKey(carried.Item.Id) || !_nodes.ContainsKey(carried.Zone.Id) || ContainerOf(carried.Zone) is null))
        {
            _carried = null;
            _carriedByPointer = false;
        }

        return _carried;
    }

    /// <summary>
    /// Picks an item up where it lies.
    /// </summary>
    /// <param name="item">The item.</param>
    /// <param name="zone">Its zone.</param>
    /// <param name="byPointer">Whether the pointer carries it.</param>
    private void Lift(Node item, Node zone, bool byPointer)
    {
        _carriedByPointer = byPointer;
        Event(item.Id, "lift");
        Target(item, zone, DragItems(zone).IndexOf(item));
        Cue(UiCue.Ok);
    }

    /// <summary>
    /// Moves the place the item carried would go to, telling the zone it leaves and the one it goes to.
    /// </summary>
    /// <param name="item">The item.</param>
    /// <param name="zone">The zone.</param>
    /// <param name="place">Its place among the zone's items without the item.</param>
    private void Target(Node item, Node zone, int place)
    {
        if (_carried is { } before && before.Zone != zone)
        {
            Event(before.Zone.Id, "target", -1);
        }

        _carried = (item, zone, place);
        Event(zone.Id, "target", place);
    }

    /// <summary>
    /// Puts the item carried down where it would go and tells its container.
    /// </summary>
    /// <param name="carried">The item, its zone and its place.</param>
    private void PutDown((Node Item, Node Zone, int Place) carried)
    {
        Node from = ZoneOf(carried.Item)!;
        EndCarry(carried);
        _events.Add(new RubyArray { ContainerOf(from)!.Id, "drop", carried.Item.Id, from.Id, carried.Zone.Id, carried.Place });
        Cue(UiCue.Ok);
    }

    /// <summary>
    /// Ends the carry, which leaves the item where it came from unless the container is told to
    /// move it: the item is no longer lifted and its zone shows no place.
    /// </summary>
    /// <param name="carried">The item, its zone and its place.</param>
    private void EndCarry((Node Item, Node Zone, int Place) carried)
    {
        _carried = null;
        _carriedByPointer = false;
        Event(carried.Item.Id, "unlift");
        Event(carried.Zone.Id, "target", -1);
    }

    /// <summary>
    /// Finds the drop zone an item lies in.
    /// </summary>
    /// <param name="item">The item.</param>
    /// <returns>The zone, null for none.</returns>
    private static Node? ZoneOf(Node item)
    {
        for (Node? step = item.Parent; step is not null; step = step.Parent)
        {
            if (step.DropZone)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Finds the drop container a zone lies in.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <returns>The container, null for none.</returns>
    private static Node? ContainerOf(Node zone)
    {
        for (Node? step = zone.Parent; step is not null; step = step.Parent)
        {
            if (step.DropContainer)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Finds the item of a drop zone a component is or lies in.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>The item, null for none.</returns>
    private static Node? DragItemAround(Node node)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step.Drag)
            {
                return step;
            }
        }

        return null;
    }

    /// <summary>
    /// Lists the shown drop zones of a container in tree order.
    /// </summary>
    /// <param name="container">The container.</param>
    /// <returns>The zones.</returns>
    private static List<Node> ZonesOf(Node container)
    {
        var zones = new List<Node>();
        CollectZones(container, zones);
        return zones;
    }

    /// <summary>
    /// Adds the shown drop zones below a component to a list, in tree order.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="zones">Where they go.</param>
    private static void CollectZones(Node node, List<Node> zones)
    {
        foreach (Node child in node.Children)
        {
            if (!child.Visible)
            {
                continue;
            }

            if (child.DropZone)
            {
                zones.Add(child);
            }
            else
            {
                CollectZones(child, zones);
            }
        }
    }

    /// <summary>
    /// Finds a zone of a container's zones by its place.
    /// </summary>
    /// <param name="zones">The zones.</param>
    /// <param name="index">The place.</param>
    /// <returns>The zone, null past either end.</returns>
    private static Node? ZoneAt(List<Node> zones, int index) => index >= 0 && index < zones.Count ? zones[index] : null;

    /// <summary>
    /// Lists the shown items of a drop zone in order.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <returns>The items.</returns>
    private static List<Node> DragItems(Node zone) => zone.Children.FindAll(child => child.Drag && child.Visible);

    /// <summary>
    /// Tells the last place an item may go to in a zone: the count of its items without the item.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <param name="item">The item carried.</param>
    /// <returns>The place.</returns>
    private static int Places(Node zone, Node item) => DragItems(zone).FindAll(each => each != item).Count;

    /// <summary>
    /// Finds the zone of a container that lies under the pointer.
    /// </summary>
    /// <param name="container">The container.</param>
    /// <param name="at">Where the pointer is.</param>
    /// <returns>The zone, null for none.</returns>
    private static Node? ZoneUnder(Node container, (int X, int Y) at) =>
        ZonesOf(container).Find(zone => zone.Rect is { } rect && at.X >= rect.X && at.X < rect.X + rect.Width && at.Y >= rect.Y && at.Y < rect.Y + rect.Height);

    /// <summary>
    /// Tells the place in a zone under the pointer: how many of its items without the one carried
    /// have their middle before the pointer, along the zone's row or column.
    /// </summary>
    /// <param name="zone">The zone.</param>
    /// <param name="item">The item carried.</param>
    /// <param name="at">Where the pointer is.</param>
    /// <returns>The place.</returns>
    private static int PlaceAt(Node zone, Node item, (int X, int Y) at)
    {
        bool row = zone.Layout == FlowLayout.Row;
        int place = 0;
        foreach (Node each in DragItems(zone))
        {
            if (each != item && each.Rect is { } rect && (row ? rect.X + (rect.Width / 2) : rect.Y + (rect.Height / 2)) < (row ? at.X : at.Y))
            {
                place++;
            }
        }

        return place;
    }
}
