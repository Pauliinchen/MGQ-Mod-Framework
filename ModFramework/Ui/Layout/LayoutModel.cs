//----------------------------------------------------------------
//  LayoutModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Kept a place as its zone and the offset from the zone's point, so it stays in its corner
//                              at another screen size, and turned an older place in pixels into one once
//                            - Kept the place of a box beside a part as the offset from that part
//                            - Kept the place of a box that stores nothing only while the game runs
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Kept every box within a most size as well as a least size
//                            - Added boxes that resize in height alone and boxes that only resize
//                            - Read Alt, the left button and the pointer from the input model
//                            - Left unregistered boxes out of drags
//                            - Told the component tree where the player put a box
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;

namespace MGQParadox.ModFramework.Ui.Layout;

/// <summary>
/// A place on the screen: its left, top, width and height.
/// </summary>
/// <param name="X">The left.</param>
/// <param name="Y">The top.</param>
/// <param name="Width">The width.</param>
/// <param name="Height">The height.</param>
internal readonly record struct LayoutRect(int X, int Y, int Width, int Height)
{
    /// <summary>
    /// Tells whether a point lies inside.
    /// </summary>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>Whether it does.</returns>
    public bool Contains(int x, int y) => x >= X && x < X + Width && y >= Y && y < Y + Height;

    /// <summary>
    /// Writes the place as the scripts read it.
    /// </summary>
    /// <returns>[x, y, width, height].</returns>
    public RubyArray ToValue() => [X, Y, Width, Height];
}

/// <summary>
/// Where the player left a box: the zone its middle lies in and the offset of its matching point
/// from the zone's point (its top left corner from the screen's top left corner, its middle from the
/// screen's middle, and so on), or for a box beside a part the offset of its top left corner from
/// the part's; and its size.
/// </summary>
/// <param name="Zone">One of <see cref="Docks.Names"/>, or <see cref="LayoutModel.BesideZone"/>.</param>
/// <param name="Dx">The offset to the right.</param>
/// <param name="Dy">The offset downward.</param>
/// <param name="Width">The width.</param>
/// <param name="Height">The height.</param>
internal readonly record struct StoredPlace(string Zone, int Dx, int Dy, int Width, int Height);

/// <summary>
/// How a box resizes: both ways, in width alone, in height alone, or not at all. A side that does
/// not resize follows what the box shows.
/// </summary>
internal enum LayoutResize
{
    /// <summary>Both ways.</summary>
    Both,

    /// <summary>In width alone.</summary>
    Width,

    /// <summary>In height alone.</summary>
    Height,

    /// <summary>Not at all.</summary>
    None,
}

/// <summary>
/// Where the floating boxes and windows of the mods lie and how large they are (Layout in the
/// scripts), which the player changes with the left Alt held: a drag inside a movable box moves it,
/// a drag on the edge or corner of a resizable one resizes it, a double click puts it back where it
/// starts. Each box keeps its place in the framework's settings, which the scripts read and write,
/// as its zone and the offset from it (<see cref="StoredPlace"/>), never smaller than its least size
/// and never larger than its most size or the screen.
/// </summary>
internal sealed class LayoutModel : IUiModel
{
    /// <summary>
    /// The model's name in the tick, whose input is the boxes shown in the frame before as
    /// [id, x, y, width, height, depth].
    /// </summary>
    public const string ModelName = "layout";

    /// <summary>
    /// Makes a box arrangeable: [id, name, least width, least height, most width, most height (0 for
    /// the screen), "both", "width", "height" or "none", whether it moves, its place in the settings
    /// or nil, and optionally the screen's width and height and whether its place goes into the
    /// settings], answering [whether the player moved or resized it, the place turned from pixels
    /// into its zone and offset for the settings or nil].
    /// </summary>
    public const string RegisterTopic = "ui.layout.register";

    /// <summary>
    /// Tells where a box draws: [id, x, y, width, height of its default, the screen's width and
    /// height, its place in the settings or nil, or false when handed over before], answering
    /// [x, y, width, height, whether the player moved or resized it, the place turned from pixels
    /// into its zone and offset for the settings or nil].
    /// </summary>
    public const string RectTopic = "ui.layout.rect";

    /// <summary>
    /// Puts a box back where it starts: [id], answering where it draws then.
    /// </summary>
    public const string ResetTopic = "ui.layout.reset";

    /// <summary>
    /// The zone a box beside a part keeps its place in, as the offset from the part.
    /// </summary>
    public const string BesideZone = "beside";

    /// <summary>
    /// The layout's event: {"rects" => {id => [x, y, width, height]} of the boxes whose place
    /// changed, "store" => {id => "zone,dx,dy,width,height" or nil} for the settings, "dragging", "overlay"
    /// (the ids outlined while Alt is held, nil once it is let go), "hot", "log"}.
    /// </summary>
    public const string EventTopic = "ui.layout";

    /// <summary>
    /// Windows' code of the left Alt; the right Alt is AltGr, which types characters.
    /// </summary>
    public const int AltKey = 0xA4;

    /// <summary>
    /// Pixels inside a box's border on which a drag resizes it rather than moving it.
    /// </summary>
    public const int Grab = 8;

    /// <summary>
    /// Ticks within which a second click counts as a double click.
    /// </summary>
    public const int DoubleClickTicks = 24;

    /// <summary>
    /// Pixels a double click's second click may lie from the first, along either axis.
    /// </summary>
    public const int DoubleClickReach = 6;

    /// <summary>
    /// The host the layout posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The input model, which reads Alt, the left button and the pointer of the tick.
    /// </summary>
    private readonly InputModel _input;

    /// <summary>
    /// The registered boxes by their ids.
    /// </summary>
    private readonly Dictionary<string, Box> _boxes = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the player left each box, null for one at its default, by the boxes' ids.
    /// </summary>
    private readonly Dictionary<string, StoredPlace?> _stored = new(StringComparer.Ordinal);

    /// <summary>
    /// Where the part lies that each box beside a part lies beside, by the boxes' ids.
    /// </summary>
    private readonly Dictionary<string, LayoutRect> _anchors = new(StringComparer.Ordinal);

    /// <summary>
    /// Each box's last default, which its place is fitted against.
    /// </summary>
    private readonly Dictionary<string, LayoutRect> _defaults = new(StringComparer.Ordinal);

    /// <summary>
    /// The screen's width.
    /// </summary>
    private int _screenWidth = 640;

    /// <summary>
    /// The screen's height.
    /// </summary>
    private int _screenHeight = 480;

    /// <summary>
    /// The drag under way, null for none.
    /// </summary>
    private Drag? _drag;

    /// <summary>
    /// The last click with Alt: its box, where and when, null after a double click or a drag kept.
    /// </summary>
    private (string Id, int X, int Y, long Tick)? _lastClick;

    /// <summary>
    /// What the last event said of the overlay, so an unchanged overlay posts nothing.
    /// </summary>
    private string? _overlay;

    /// <summary>
    /// Creates the layout and registers its topics.
    /// </summary>
    /// <remarks>
    /// The scripts put the input model first in each tick, so the layout reads the tick's own Alt,
    /// button and pointer.
    /// </remarks>
    /// <param name="host">The host of the interface's models.</param>
    /// <param name="input">The input model of the same host.</param>
    public LayoutModel(UiHost host, InputModel input)
    {
        ArgumentNullException.ThrowIfNull(host);
        ArgumentNullException.ThrowIfNull(input);
        _host = host;
        _input = input;
        BridgeContext context = host.Context;
        context.Register(RegisterTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            string id = args[0].AsText();
            bool stores = args.Count <= 11 || args[11].AsBool();
            _boxes[id] = new Box(args[1].AsText(), args[2].AsInt(), args[3].AsInt(), args[4].AsInt(), args[5].AsInt(), ResizeOf(args[6].AsText()), args[7].AsBool(), stores);
            if (args.Count > 10)
            {
                (_screenWidth, _screenHeight) = (args[9].AsInt(), args[10].AsInt());
            }

            RubyValue turned = Keep(id, args[8]);
            return new RubyArray { Moved(id), turned };
        });
        context.Register(RectTopic, (_, request) =>
        {
            RubyArray args = request.AsArray();
            string id = args[0].AsText();
            _defaults[id] = new LayoutRect(args[1].AsInt(), args[2].AsInt(), args[3].AsInt(), args[4].AsInt());
            _screenWidth = args[5].AsInt();
            _screenHeight = args[6].AsInt();
            RubyValue turned = args[7] is RubyBool { Flag: false } ? RubyNil.Value : Keep(id, args[7]);
            RubyArray place = Place(id).ToValue();
            place.Add(Moved(id));
            place.Add(turned);
            return place;
        });
        context.Register(ResetTopic, (_, request) =>
        {
            string id = request.AsArray()[0].AsText();
            _stored[id] = null;
            if (_drag?.Id == id)
            {
                _drag = null;
            }

            return Place(id).ToValue();
        });
    }

    /// <inheritdoc />
    public string Name => ModelName;

    /// <summary>
    /// Tells where the player put a box: where it is being dragged, else where they left it.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The place as dragged or kept, null while the box sits where it starts.</returns>
    public LayoutRect? Arranged(string id) => Arranged(id, _screenWidth, _screenHeight);

    /// <summary>
    /// Tells where the player put a box on a screen of a size: where it is being dragged, else
    /// where they left it.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The place as dragged or kept, null while the box sits where it starts or the part
    /// it was left beside does not show.</returns>
    public LayoutRect? Arranged(string id, int screenWidth, int screenHeight) =>
        _drag?.Id == id ? _drag.Rect : _stored.GetValueOrDefault(id) is { } place ? Resolve(place, Target(id), screenWidth, screenHeight) : null;

    /// <summary>
    /// Tells a box beside a part where that part lies, which its place counts from.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="target">Where the part lies, null while it does not show.</param>
    public void Anchor(string id, LayoutRect? target)
    {
        if (target is { } rect)
        {
            _anchors[id] = rect;
        }
        else
        {
            _anchors.Remove(id);
        }
    }

    /// <summary>
    /// Turns a place on the screen into the zone it lies in and the offset from the zone's point,
    /// or into the offset from the part a box lies beside.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <param name="target">Where the part lies that the box lies beside, null for none.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The stored place.</returns>
    public static StoredPlace StoredOf(LayoutRect rect, LayoutRect? target, int screenWidth, int screenHeight)
    {
        if (target is { } part)
        {
            return new StoredPlace(BesideZone, rect.X - part.X, rect.Y - part.Y, rect.Width, rect.Height);
        }

        string zone = Docks.ZoneOf(rect, screenWidth, screenHeight);
        (int column, int row) = Docks.Cell(zone);
        return new StoredPlace(zone, rect.X + column * rect.Width / 2 - column * screenWidth / 2, rect.Y + row * rect.Height / 2 - row * screenHeight / 2,
                               rect.Width, rect.Height);
    }

    /// <summary>
    /// Turns a stored place back into a place on a screen of a size.
    /// </summary>
    /// <param name="place">The stored place.</param>
    /// <param name="target">Where the part lies that the box lies beside, null for none.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The place, null for a place beside a part that does not show.</returns>
    public static LayoutRect? Resolve(StoredPlace place, LayoutRect? target, int screenWidth, int screenHeight)
    {
        if (place.Zone == BesideZone)
        {
            return target is { } part ? new LayoutRect(part.X + place.Dx, part.Y + place.Dy, place.Width, place.Height) : null;
        }

        (int column, int row) = Docks.Cell(place.Zone);
        return new LayoutRect(column * screenWidth / 2 + place.Dx - column * place.Width / 2, row * screenHeight / 2 + place.Dy - row * place.Height / 2,
                              place.Width, place.Height);
    }

    /// <summary>
    /// Writes a stored place as the settings keep it.
    /// </summary>
    /// <param name="place">The place.</param>
    /// <returns>Such as "top_right,-8,8,200,120".</returns>
    public static string TextOf(StoredPlace place) =>
        string.Create(CultureInfo.InvariantCulture, $"{place.Zone},{place.Dx},{place.Dy},{place.Width},{place.Height}");

    /// <summary>
    /// Reads the place a setting keeps as its zone and offset: a zone's name and four whole numbers
    /// split by commas.
    /// </summary>
    /// <param name="text">The text, such as "top_right,-8,8,200,120".</param>
    /// <returns>The place, null for a text that names none.</returns>
    public static StoredPlace? ParseStored(string? text)
    {
        string[] parts = Fields(text);
        if (parts.Length != 5)
        {
            return null;
        }

        string zone = parts[0].Trim();
        int[]? numbers = Wholes(parts[1..]);
        bool named = zone == BesideZone || Array.IndexOf(Docks.Names, zone) >= 0;
        return numbers is not null && named ? new StoredPlace(zone, numbers[0], numbers[1], numbers[2], numbers[3]) : null;
    }

    /// <summary>
    /// Reads the place an older setting keeps in pixels: four whole numbers split by commas.
    /// </summary>
    /// <param name="text">The text, such as "20,30,300,120".</param>
    /// <returns>The place, null for a text that names none.</returns>
    public static LayoutRect? Parse(string? text)
    {
        string[] parts = Fields(text);
        int[]? numbers = parts.Length == 4 ? Wholes(parts) : null;
        return numbers is null ? null : new LayoutRect(numbers[0], numbers[1], numbers[2], numbers[3]);
    }

    /// <summary>
    /// Splits a setting's text at its commas, dropping the empty fields at the end as Ruby's split
    /// does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The fields.</returns>
    private static string[] Fields(string? text)
    {
        string[] parts = (text ?? string.Empty).Split(',');
        int count = parts.Length;
        while (count > 0 && parts[count - 1].Length == 0)
        {
            count--;
        }

        return parts[..count];
    }

    /// <summary>
    /// Reads whole numbers, each with spaces around it allowed.
    /// </summary>
    /// <param name="parts">The fields.</param>
    /// <returns>The numbers, null when a field is no whole number.</returns>
    private static int[]? Wholes(string[] parts)
    {
        var numbers = new int[parts.Length];
        for (int index = 0; index < parts.Length; index++)
        {
            string part = parts[index].Trim(' ', '\t', '\n', '\v', '\f', '\r', '\0');
            bool whole = part.Length > 0 && part.TrimStart('-').Length > 0 && part.Skip(part[0] == '-' ? 1 : 0).All(char.IsAsciiDigit);
            if (!whole || !int.TryParse(part, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out numbers[index]))
            {
                return null;
            }
        }

        return numbers;
    }

    /// <summary>
    /// Follows a frame with the input model's Alt, left button and pointer of the same tick.
    /// </summary>
    /// <param name="input">The boxes shown, each [id, x, y, width, height, depth].</param>
    public void Tick(RubyValue input)
    {
        (int width, int height) = _input.ScreenSize;
        Arrange(_input.KeyDown(AltKey), _input.LeftDown, _input.LeftWentDown, _input.Pointer, width, height, input);
    }

    /// <summary>
    /// Follows a frame: starts a drag on Alt and a left press over a box, follows it, keeps the
    /// place once the button is let go, and outlines the boxes while Alt is held or a drag runs.
    /// </summary>
    /// <param name="alt">Whether the left Alt is held.</param>
    /// <param name="held">Whether the left button is held.</param>
    /// <param name="wentDown">Whether it went down in this frame.</param>
    /// <param name="position">Where the mouse points, null outside the game's screen.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <param name="shown">The boxes shown, each [id, x, y, width, height, depth].</param>
    internal void Arrange(bool alt, bool held, bool wentDown, (int X, int Y)? position, int screenWidth, int screenHeight, RubyValue shown)
    {
        List<Offer> offers = [.. shown.AsArray().Select(OfferOf)];
        _screenWidth = screenWidth;
        _screenHeight = screenHeight;
        var change = new RubyHash();
        if (_drag is not null)
        {
            FollowDrag(position, held, change);
        }
        else if (alt && wentDown && position is { } point)
        {
            StartDrag(offers, point, change);
        }

        ShowOverlay(alt || _drag is not null ? offers : [], position, change);
        if (change.Count > 0)
        {
            _host.Post(EventTopic, change);
        }
    }

    /// <summary>
    /// Fits a box's place: within its least and most size and the screen, wholly on the screen; a
    /// side that does not resize keeps its default's length, and a box that does not move its
    /// default's corner.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="rect">Its place.</param>
    /// <param name="fallback">Where it starts.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The fitted place.</returns>
    internal static LayoutRect Fit(Box box, LayoutRect rect, LayoutRect fallback, int screenWidth, int screenHeight)
    {
        int width = box.ResizesWidth ? rect.Width : fallback.Width;
        int height = box.ResizesHeight ? rect.Height : fallback.Height;
        width = Within(width, box.MinWidth, Most(box.MaxWidth, screenWidth));
        height = Within(height, box.MinHeight, Most(box.MaxHeight, screenHeight));
        LayoutRect corner = box.Movable ? rect : fallback;
        return OnScreen(new LayoutRect(corner.X, corner.Y, width, height), screenWidth, screenHeight);
    }

    /// <summary>
    /// Keeps a place wholly on the screen, its size as it is.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <param name="screenWidth">The screen's width.</param>
    /// <param name="screenHeight">The screen's height.</param>
    /// <returns>The place moved onto the screen.</returns>
    internal static LayoutRect OnScreen(LayoutRect rect, int screenWidth, int screenHeight)
    {
        int width = Math.Min(rect.Width, screenWidth);
        int height = Math.Min(rect.Height, screenHeight);
        return new LayoutRect(Within(rect.X, 0, screenWidth - width), Within(rect.Y, 0, screenHeight - height), width, height);
    }

    /// <summary>
    /// Keeps a value between two bounds, the upper winning, as the scripts' within does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="low">The lower bound.</param>
    /// <param name="high">The upper bound.</param>
    /// <returns>The value, or the bound it passed.</returns>
    private static int Within(int value, int low, int high) => Math.Min(Math.Max(value, low), high);

    /// <summary>
    /// Tells how long a side may get: its most length, or the screen's when it names none or a
    /// longer one.
    /// </summary>
    /// <param name="most">The most length, 0 or less for none.</param>
    /// <param name="screen">The screen's length.</param>
    /// <returns>The length.</returns>
    private static int Most(int most, int screen) => most > 0 ? Math.Min(most, screen) : screen;

    /// <summary>
    /// Reads how a box resizes.
    /// </summary>
    /// <param name="text">"both", "width", "height" or "none"; anything else is both.</param>
    /// <returns>The way.</returns>
    private static LayoutResize ResizeOf(string text) => text switch
    {
        "width" => LayoutResize.Width,
        "height" => LayoutResize.Height,
        "none" => LayoutResize.None,
        _ => LayoutResize.Both,
    };

    /// <summary>
    /// Reads a box offered in a frame.
    /// </summary>
    /// <param name="value">[id, x, y, width, height, depth].</param>
    /// <returns>The offer.</returns>
    private static Offer OfferOf(RubyValue value)
    {
        RubyArray item = value.AsArray();
        return new Offer(item[0].AsText(), new LayoutRect(item[1].AsInt(), item[2].AsInt(), item[3].AsInt(), item[4].AsInt()), item[5].AsInt());
    }

    /// <summary>
    /// Finds the topmost box under a point.
    /// </summary>
    /// <param name="offers">The boxes shown.</param>
    /// <param name="x">The point's left.</param>
    /// <param name="y">The point's top.</param>
    /// <returns>The box, null for none.</returns>
    private static Offer? TopOffer(List<Offer> offers, int x, int y)
    {
        Offer? top = null;
        foreach (Offer offer in offers)
        {
            // The first of the deepest wins, as Ruby's max_by keeps.
            if (offer.Rect.Contains(x, y) && (top is null || offer.Z > top.Z))
            {
                top = offer;
            }
        }

        return top;
    }

    /// <summary>
    /// Moves one end of a span by a drag, keeping its length between its least and most and the span
    /// within 0..limit; the other end stays put.
    /// </summary>
    /// <param name="low">Its start.</param>
    /// <param name="high">Its end.</param>
    /// <param name="lowStep">How far its start moves.</param>
    /// <param name="highStep">How far its end moves.</param>
    /// <param name="least">Its least length.</param>
    /// <param name="most">Its most length, 0 or less for the screen's.</param>
    /// <param name="limit">Where the screen ends.</param>
    /// <returns>The new start and end.</returns>
    private static (int Low, int High) Span(int low, int high, int lowStep, int highStep, int least, int most, int limit)
    {
        most = Most(most, limit);
        least = Math.Min(least, most);
        if (lowStep != 0)
        {
            low = Within(low + lowStep, Math.Max(0, high - most), high - least);
        }
        else if (highStep != 0)
        {
            high = Within(high + highStep, low + least, Math.Min(limit, low + most));
        }

        return (low, high);
    }

    /// <summary>
    /// Finds which sides of a box a drag from a point resizes: those whose border within
    /// <see cref="Grab"/> the point lies on, as the box resizes; a box that does not move resizes
    /// only by its right and bottom sides. None moves the box.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="rect">Where it lies.</param>
    /// <param name="point">The point.</param>
    /// <returns>Left, top, right and bottom.</returns>
    private static Sides SidesAt(Box box, LayoutRect rect, (int X, int Y) point)
    {
        bool left = box.Movable && box.ResizesWidth && point.X < rect.X + Grab;
        bool right = box.ResizesWidth && point.X >= rect.X + rect.Width - Grab;
        bool top = box.Movable && box.ResizesHeight && point.Y < rect.Y + Grab;
        bool bottom = box.ResizesHeight && point.Y >= rect.Y + rect.Height - Grab;
        return new Sides(left, top, right && !left, bottom && !top);
    }

    /// <summary>
    /// Keeps the place a setting names for a box; an older place in pixels is turned into its zone
    /// and offset on the screen of now.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="text">The text, nil for none.</param>
    /// <returns>The turned place's text for the settings, nil when nothing was turned.</returns>
    private RubyValue Keep(string id, RubyValue text)
    {
        string? given = text.IsNil ? null : text.AsText();
        _stored[id] = ParseStored(given);
        if (_stored[id] is not null || Parse(given) is not { } pixels)
        {
            return RubyNil.Value;
        }

        StoredPlace turned = StoredOf(pixels, null, _screenWidth, _screenHeight);
        _stored[id] = turned;
        return TextOf(turned);
    }

    /// <summary>
    /// Tells where the part lies that a box lies beside.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The part's place, null for a box beside nothing or a part that does not show.</returns>
    private LayoutRect? Target(string id) => _anchors.TryGetValue(id, out LayoutRect rect) ? rect : null;

    /// <summary>
    /// Finds the box of an id; one that never registered moves, has no least or most size and
    /// resizes as asked.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="resize">How an unregistered box resizes.</param>
    /// <returns>The box.</returns>
    private Box BoxOf(string id, LayoutResize resize) => _boxes.TryGetValue(id, out Box? box) ? box : new Box(id, 0, 0, 0, 0, resize, true, true);

    /// <summary>
    /// Tells whether the player moved or resized a box from its default.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>Whether they did.</returns>
    private bool Moved(string id) => _stored.GetValueOrDefault(id) is not null;

    /// <summary>
    /// Tells where a box draws: where it is being dragged, else where the player left it, else its
    /// default, fitted to its sizes and the screen.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The place.</returns>
    private LayoutRect Place(string id)
    {
        if (_drag?.Id == id)
        {
            return _drag.Rect;
        }

        LayoutRect fallback = _defaults.TryGetValue(id, out LayoutRect given) ? given : default;
        LayoutRect? kept = _stored.GetValueOrDefault(id) is { } stored ? Resolve(stored, Target(id), _screenWidth, _screenHeight) : null;
        return Fit(BoxOf(id, LayoutResize.Both), kept ?? fallback, fallback, _screenWidth, _screenHeight);
    }

    /// <summary>
    /// Starts a drag on the topmost box under the mouse, or puts it back on a double click; a box
    /// that never registered stays where it is.
    /// </summary>
    /// <param name="offers">The boxes shown.</param>
    /// <param name="point">Where the mouse went down.</param>
    /// <param name="change">The frame's event.</param>
    private void StartDrag(List<Offer> offers, (int X, int Y) point, RubyHash change)
    {
        if (TopOffer(offers, point.X, point.Y) is not { } offer || !_boxes.TryGetValue(offer.Id, out Box? box))
        {
            return;
        }

        if (_lastClick is { } last && last.Id == offer.Id && _host.Now - last.Tick <= DoubleClickTicks
            && Math.Abs(point.X - last.X) <= DoubleClickReach && Math.Abs(point.Y - last.Y) <= DoubleClickReach)
        {
            _lastClick = null;
            _stored[offer.Id] = null;
            Changed(change, "store", offer.Id, RubyNil.Value);
            Changed(change, "rects", offer.Id, Place(offer.Id).ToValue());
            Logged(change, $"put {NameOf(offer.Id)} back (a double click with Alt)");
            return;
        }

        _lastClick = (offer.Id, point.X, point.Y, _host.Now);
        Sides sides = SidesAt(box, offer.Rect, point);
        if (!box.Movable && !sides.Any)
        {
            return;
        }

        _drag = new Drag(offer.Id, point, offer.Rect, sides) { Rect = offer.Rect };
        change["dragging"] = true;
    }

    /// <summary>
    /// Follows the mouse while a drag runs and keeps the box's place once the button is let go.
    /// </summary>
    /// <param name="position">Where the mouse points, null outside the window.</param>
    /// <param name="held">Whether the left button is still held.</param>
    /// <param name="change">The frame's event.</param>
    private void FollowDrag((int X, int Y)? position, bool held, RubyHash change)
    {
        Drag drag = _drag!;
        if (position is { } point)
        {
            LayoutRect moved = Dragged(BoxOf(drag.Id, LayoutResize.None), drag, point);
            if (moved != drag.Rect)
            {
                drag.Rect = moved;
                Changed(change, "rects", drag.Id, moved.ToValue());
            }
        }

        if (!held)
        {
            Finish(drag, change);
        }
    }

    /// <summary>
    /// Finds a dragged box's place: moved by how far the mouse went, or its sides that follow the
    /// mouse moved, never below its least size, never above its most size and never off the screen.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="drag">The drag.</param>
    /// <param name="point">Where the mouse points.</param>
    /// <returns>The place.</returns>
    private LayoutRect Dragged(Box box, Drag drag, (int X, int Y) point)
    {
        int dx = point.X - drag.Start.X;
        int dy = point.Y - drag.Start.Y;
        LayoutRect origin = drag.Origin;
        Sides sides = drag.Sides;
        if (!sides.Any)
        {
            return OnScreen(origin with { X = origin.X + dx, Y = origin.Y + dy }, _screenWidth, _screenHeight);
        }

        (int x1, int x2) = Span(origin.X, origin.X + origin.Width, sides.Left ? dx : 0, sides.Right ? dx : 0, box.MinWidth, box.MaxWidth, _screenWidth);
        (int y1, int y2) = Span(origin.Y, origin.Y + origin.Height, sides.Top ? dy : 0, sides.Bottom ? dy : 0, box.MinHeight, box.MaxHeight, _screenHeight);
        return new LayoutRect(x1, y1, x2 - x1, y2 - y1);
    }

    /// <summary>
    /// Ends a drag, keeping the box's place for the settings unless it never changed.
    /// </summary>
    /// <param name="drag">The drag.</param>
    /// <param name="change">The frame's event.</param>
    private void Finish(Drag drag, RubyHash change)
    {
        _drag = null;
        change["dragging"] = false;
        if (drag.Rect == drag.Origin)
        {
            return;
        }

        LayoutRect rect = drag.Rect;
        StoredPlace place = StoredOf(rect, Target(drag.Id), _screenWidth, _screenHeight);
        _stored[drag.Id] = place;
        _lastClick = null;
        if (BoxOf(drag.Id, LayoutResize.None).Stores)
        {
            Changed(change, "store", drag.Id, TextOf(place));
        }

        Changed(change, "rects", drag.Id, Place(drag.Id).ToValue());
        Logged(change, string.Create(CultureInfo.InvariantCulture, $"{(drag.Sides.Any ? "resized" : "moved")} {NameOf(drag.Id)} to {rect.X},{rect.Y} at {rect.Width}x{rect.Height}"));
    }

    /// <summary>
    /// Says which boxes the overlay outlines and which one it washes, once that changed.
    /// </summary>
    /// <param name="offers">The boxes to outline, none while Alt is let go.</param>
    /// <param name="position">Where the mouse points.</param>
    /// <param name="change">The frame's event.</param>
    private void ShowOverlay(List<Offer> offers, (int X, int Y)? position, RubyHash change)
    {
        string? hot = _drag?.Id ?? (position is { } point ? TopOffer(offers, point.X, point.Y)?.Id : null);
        string? shown = offers.Count == 0 ? null : string.Join(",", offers.Select(offer => offer.Id).Order(StringComparer.Ordinal)) + "|" + hot;
        if (shown == _overlay)
        {
            return;
        }

        _overlay = shown;
        var ids = new RubyArray();
        foreach (Offer offer in offers)
        {
            ids.Add(offer.Id);
        }

        change["overlay"] = shown is null ? RubyNil.Value : ids;
        change["hot"] = hot;
    }

    /// <summary>
    /// Names a box for the log.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>Its name.</returns>
    private string NameOf(string id) => _boxes.TryGetValue(id, out Box? box) ? box.Name : id;

    /// <summary>
    /// Adds a box's change to the frame's event.
    /// </summary>
    /// <param name="change">The event.</param>
    /// <param name="kind">"rects" or "store".</param>
    /// <param name="id">The box.</param>
    /// <param name="value">What changed.</param>
    private static void Changed(RubyHash change, string kind, string id, RubyValue value)
    {
        if (!change.TryGetValue(kind, out RubyValue? group))
        {
            group = new RubyHash();
            change[kind] = group;
        }

        group.AsHash()[id] = value;
    }

    /// <summary>
    /// Adds a line for the log to the frame's event.
    /// </summary>
    /// <param name="change">The event.</param>
    /// <param name="line">The line.</param>
    private static void Logged(RubyHash change, string line)
    {
        if (!change.TryGetValue("log", out RubyValue? lines))
        {
            lines = new RubyArray();
            change["log"] = lines;
        }

        lines.AsArray().Add(line);
    }

    /// <summary>
    /// A box the player can arrange: its name, its least and most size, how it resizes, whether it
    /// moves and whether its place goes into the settings.
    /// </summary>
    /// <param name="Name">Its name for the log.</param>
    /// <param name="MinWidth">The narrowest it gets.</param>
    /// <param name="MinHeight">The lowest it gets.</param>
    /// <param name="MaxWidth">The widest it gets, 0 or less for the screen's width.</param>
    /// <param name="MaxHeight">The highest it gets, 0 or less for the screen's height.</param>
    /// <param name="Resize">How it resizes.</param>
    /// <param name="Movable">Whether a drag inside it moves it.</param>
    /// <param name="Stores">Whether its place goes into the settings rather than lasting only while the game runs.</param>
    internal sealed record Box(string Name, int MinWidth, int MinHeight, int MaxWidth, int MaxHeight, LayoutResize Resize, bool Movable, bool Stores)
    {
        /// <summary>Gets whether a drag changes its width.</summary>
        public bool ResizesWidth => Resize is LayoutResize.Both or LayoutResize.Width;

        /// <summary>Gets whether a drag changes its height.</summary>
        public bool ResizesHeight => Resize is LayoutResize.Both or LayoutResize.Height;
    }

    /// <summary>
    /// Where a box drew in a frame, its depth deciding which of two overlapping boxes a click takes.
    /// </summary>
    /// <param name="Id">The box.</param>
    /// <param name="Rect">Where.</param>
    /// <param name="Z">Its depth.</param>
    private sealed record Offer(string Id, LayoutRect Rect, int Z);

    /// <summary>
    /// The sides of a box a drag resizes.
    /// </summary>
    /// <param name="Left">Whether its left side follows the mouse.</param>
    /// <param name="Top">Whether its top side does.</param>
    /// <param name="Right">Whether its right side does.</param>
    /// <param name="Bottom">Whether its bottom side does.</param>
    private readonly record struct Sides(bool Left, bool Top, bool Right, bool Bottom)
    {
        /// <summary>Gets whether any side follows, so the drag resizes rather than moves.</summary>
        public bool Any => Left || Top || Right || Bottom;
    }

    /// <summary>
    /// A drag under way: its box, where the mouse went down, the box's place then and which sides
    /// follow the mouse (none to move it), and the place it has now.
    /// </summary>
    /// <param name="Id">The box.</param>
    /// <param name="Start">Where the mouse went down.</param>
    /// <param name="Origin">The box's place then.</param>
    /// <param name="Sides">The sides that follow the mouse.</param>
    private sealed record Drag(string Id, (int X, int Y) Start, LayoutRect Origin, Sides Sides)
    {
        /// <summary>Gets or sets the place the box has now.</summary>
        public LayoutRect Rect { get; set; }
    }
}
