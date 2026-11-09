//----------------------------------------------------------------
//  ToastStack.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Told the scripts the direction a stack grows in, which they place its toasts by
//                            - Moved a toast up the screen as it fades out
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Notices;

/// <summary>
/// The rules of a stack of toasts: the general stack at the corner the player picks, or a stack a
/// mod defined with UI.toasts at a corner or a spot of its own. They tell where each toast lies
/// from the stack's start, the side it slides in from, the direction the stack grows in, how many
/// show at once and how long each shows.
/// </summary>
internal sealed class ToastStack
{
    /// <summary>
    /// The seconds a toast shows unless its stack or its call gives others.
    /// </summary>
    public const double DefaultSeconds = 3;

    /// <summary>
    /// The most toasts a stack shows at once unless it gives another number, MudBlazor's default.
    /// </summary>
    public const int DefaultMostShown = 5;

    /// <summary>
    /// The corner of a stack that names neither a corner nor a spot.
    /// </summary>
    public const string DefaultCorner = "top_left";

    /// <summary>
    /// Whether each corner lies at the left and at the top.
    /// </summary>
    private static readonly Dictionary<string, (bool Left, bool Top)> CornerSides = new()
    {
        ["top_left"] = (true, true),
        ["top_right"] = (false, true),
        ["bottom_left"] = (true, false),
        ["bottom_right"] = (false, false),
    };

    /// <summary>
    /// The sides a toast slides in from, by their names.
    /// </summary>
    private static readonly Dictionary<string, Side> Sides = new()
    {
        ["left"] = Side.Left,
        ["right"] = Side.Right,
        ["top"] = Side.Top,
        ["bottom"] = Side.Bottom,
    };

    /// <summary>
    /// The options a stack takes, in the order the log names them.
    /// </summary>
    private static readonly string[] Options = ["corner", "at", "slide_from", "grows", "most_shown", "seconds", "newest_on_top"];

    /// <summary>
    /// Creates the rules of a stack.
    /// </summary>
    /// <param name="name">The stack's name, null for the general stack.</param>
    private ToastStack(string? name) => Name = name;

    /// <summary>
    /// A side of the screen.
    /// </summary>
    private enum Side
    {
        /// <summary>The left side.</summary>
        Left,

        /// <summary>The right side.</summary>
        Right,

        /// <summary>The top side.</summary>
        Top,

        /// <summary>The bottom side.</summary>
        Bottom,
    }

    /// <summary>
    /// Gets the stack's name, null for the general stack.
    /// </summary>
    public string? Name { get; }

    /// <summary>
    /// Gets the most toasts it shows at once.
    /// </summary>
    public int MostShown { get; private set; } = DefaultMostShown;

    /// <summary>
    /// Gets the seconds a toast of it shows unless its call gives others.
    /// </summary>
    public double Seconds { get; private set; } = DefaultSeconds;

    /// <summary>
    /// Gets whether the newest toast lies at the stack's start, the older moving away from it,
    /// rather than after the older ones.
    /// </summary>
    public bool NewestAtStart => _newestOnTop == _growsDown;

    /// <summary>
    /// The corner it lies at, null while it lies at a spot.
    /// </summary>
    private string? _corner = DefaultCorner;

    /// <summary>
    /// The spot its start lies at, null while it lies at a corner.
    /// </summary>
    private (int X, int Y)? _at;

    /// <summary>
    /// The side its toasts slide in from.
    /// </summary>
    private Side _slideFrom = Side.Left;

    /// <summary>
    /// Whether further toasts lie below the first rather than above it.
    /// </summary>
    private bool _growsDown = true;

    /// <summary>
    /// Whether the newest toast lies at the top of the stack rather than at its bottom.
    /// </summary>
    private bool _newestOnTop = true;

    /// <summary>
    /// Reads the rules of a stack from its options as the scripts give them, each option a text key.
    /// An option of a wrong value is refused and logged, and the stack takes its default for it;
    /// an option nobody knows is logged and does nothing.
    /// </summary>
    /// <param name="name">The stack's name, null for the general stack.</param>
    /// <param name="options">The options, such as {"corner" => "top_left", "most_shown" => 3}.</param>
    /// <param name="log">Where the refusals and the rules of a named stack go.</param>
    /// <returns>The rules.</returns>
    public static ToastStack Read(string? name, RubyHash options, Action<string> log)
    {
        var stack = new ToastStack(name);
        string who = name is null ? "the general toast stack" : $"toast stack {name}";
        Dictionary<string, RubyValue> given = [];
        foreach ((RubyValue key, RubyValue value) in options)
        {
            string option = key is RubyString ? key.AsText() : $"{key}";
            if (Options.Contains(option))
            {
                given[option] = value;
            }
            else
            {
                log($"notices: {who} was given the option {option}, which no toast stack knows, so it does nothing");
            }
        }

        void Refuse(string option, string wanted) =>
            log($"notices: {who} refused {option}: {given[option]}, which is not {wanted}, so it keeps its default");

        if (given.TryGetValue("at", out RubyValue? at))
        {
            if (at is RubyArray { Count: 2 } spot && spot.All(each => each is RubyInteger))
            {
                (stack._at, stack._corner) = ((spot[0].AsInt(), spot[1].AsInt()), null);
            }
            else
            {
                Refuse("at", "a spot of two whole numbers such as [40, 60]");
            }
        }

        if (given.TryGetValue("corner", out RubyValue? corner))
        {
            if (stack._at is not null)
            {
                log($"notices: {who} was given both corner and at, so at places it");
            }
            else if (corner is RubyString && CornerSides.ContainsKey(corner.AsText()))
            {
                stack._corner = corner.AsText();
            }
            else
            {
                Refuse("corner", "top_left, top_right, bottom_left or bottom_right");
            }
        }

        (bool left, bool top) = stack._corner is string named ? CornerSides[named] : (true, true);
        stack._slideFrom = left ? Side.Left : Side.Right;
        stack._growsDown = top;
        if (given.TryGetValue("slide_from", out RubyValue? slideFrom))
        {
            if (slideFrom is RubyString && Sides.TryGetValue(slideFrom.AsText(), out Side side))
            {
                stack._slideFrom = side;
            }
            else
            {
                Refuse("slide_from", "left, right, top or bottom");
            }
        }

        if (given.TryGetValue("grows", out RubyValue? grows))
        {
            if (grows is RubyString && grows.AsText() is "up" or "down")
            {
                stack._growsDown = grows.AsText() == "down";
            }
            else
            {
                Refuse("grows", "up or down");
            }
        }

        stack._newestOnTop = stack._growsDown;
        if (given.TryGetValue("newest_on_top", out RubyValue? newestOnTop))
        {
            if (newestOnTop is RubyBool flag)
            {
                stack._newestOnTop = flag.Flag;
            }
            else
            {
                Refuse("newest_on_top", "true or false");
            }
        }

        if (given.TryGetValue("most_shown", out RubyValue? mostShown))
        {
            if (mostShown is RubyInteger && mostShown.AsLong() is >= 1 and <= NoticeQueue.Most)
            {
                stack.MostShown = mostShown.AsInt();
            }
            else
            {
                Refuse("most_shown", $"a whole number from 1 to {NoticeQueue.Most}");
            }
        }

        if (given.TryGetValue("seconds", out RubyValue? seconds))
        {
            if (SecondsOf(seconds) is double counted)
            {
                stack.Seconds = counted;
            }
            else
            {
                Refuse("seconds", "a number above 0");
            }
        }

        if (name is not null)
        {
            log($"notices: {who} defined: {stack}");
        }

        return stack;
    }

    /// <summary>
    /// Tells the scripts where the stack lies and the direction it grows in, which they place its
    /// toasts by.
    /// </summary>
    /// <returns>{"corner" => a corner's name or nil, "at" => [x, y] or nil, "grows" => "up" or "down"}.</returns>
    public RubyHash Placement() => new()
    {
        ["corner"] = _corner,
        ["at"] = _at is (int x, int y) ? new RubyArray { x, y } : RubyNil.Value,
        ["grows"] = _growsDown ? "down" : "up",
    };

    /// <summary>
    /// Tells how far a toast lies from its place at the stack's start.
    /// </summary>
    /// <param name="distance">The pixels from the start along the stack.</param>
    /// <param name="slide">The share of its slide still to come, 0 once it slid in whole.</param>
    /// <param name="rise">The share of its rise made as it fades out, 0 while it does not fade.</param>
    /// <param name="width">Its box's width.</param>
    /// <param name="height">Its box's height.</param>
    /// <returns>The pixels to the right and down.</returns>
    public (int X, int Y) Offset(double distance, double slide, double rise, int width, int height)
    {
        double sliding = slide * ((_slideFrom is Side.Left or Side.Right ? width : height) + Docks.Margin);
        double x = _slideFrom switch { Side.Left => -sliding, Side.Right => sliding, _ => 0 };
        double y = (_growsDown ? distance : -distance) + _slideFrom switch { Side.Top => -sliding, Side.Bottom => sliding, _ => 0 } - rise * (height + Docks.Gap);
        return ((int)Math.Round(x), (int)Math.Round(y));
    }

    /// <inheritdoc />
    public override string ToString()
    {
        string place = _at is (int x, int y) ? $"at {x}, {y}" : $"at the {_corner!.Replace('_', ' ')}";
        string side = _slideFrom.ToString().ToLowerInvariant();
        return $"{place}, sliding in from the {side}, growing {(_growsDown ? "down" : "up")}, {MostShown} at most, " +
               $"{Seconds.ToString(CultureInfo.InvariantCulture)} s each, the newest {(_newestOnTop ? "on top" : "at the bottom")}";
    }

    /// <summary>
    /// Reads a number of seconds as the scripts give it: a whole number, or a text of a number
    /// since a Float cannot cross the bridge.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The seconds, null for a value that is no number above 0.</returns>
    private static double? SecondsOf(RubyValue value)
    {
        double? number = value switch
        {
            RubyInteger => value.AsLong(),
            RubyString when double.TryParse(value.AsText(), NumberStyles.Float, CultureInfo.InvariantCulture, out double parsed) => parsed,
            _ => null,
        };
        return number is > 0 and < double.PositiveInfinity ? number : null;
    }
}
