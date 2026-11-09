//----------------------------------------------------------------
//  ThemeTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Dropped the colors of an animated name at a frame, which the scripts work out now
//      Paulinchen  2026-11-05: Added animated color names, a color name that follows another, and the colors of an
//                              animated one at a frame
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Theme;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the interface looks, see <see cref="ThemeModel"/>.
/// </summary>
internal static class ThemeTopics
{
    /// <summary>
    /// The topic that adds a preset: {"name", "from", "palette" => {role => color}, "typography" =>
    /// {name => pixels}, "spacing", "rows" => [normal, dense], "motion" => [fade, slide],
    /// "elevation" => [pixels], "game", "mod"} answers nil once added, else why not.
    /// </summary>
    public const string PresetTopic = "ui.theme.preset";

    /// <summary>
    /// The topic that adds a color name: {"name", "mod"} with "value" => a color or the name it
    /// follows and "presets" => {preset => color}; or, for an animated name the scripts move, with
    /// "moves" => [colors], a slide's or a pulse's or what a mod's lambda answers over a cycle. It
    /// answers nil once added, else why not.
    /// </summary>
    public const string ColorTopic = "ui.theme.color";

    /// <summary>
    /// The topic that lists the presets: nil answers [names, color names].
    /// </summary>
    public const string NamesTopic = "ui.theme.names";

    /// <summary>
    /// The topic of the player's pick: the name or nil answers [the preset in use, why the pick was
    /// not taken or nil].
    /// </summary>
    public const string PickTopic = "ui.theme.pick";

    /// <summary>
    /// The topic that tells what a preset holds: its name answers {"name", "game", "palette",
    /// "colors", "typography", "spacing", "rows", "motion", "elevation"}, or nil for no preset.
    /// </summary>
    public const string ResolveTopic = "ui.theme.resolve";

    /// <summary>
    /// The topic of a button's look: [preset, variant, color, text color] (each color a name, a
    /// color or nil) answers {"fill", "edge", "text", "lit", "focus"}, each a role, a color
    /// [r, g, b, a] or nil.
    /// </summary>
    public const string LookTopic = "ui.theme.look";

    /// <summary>
    /// The topic that hands over the surfaces' colors the game's window gives in its window color:
    /// {surface => color} answers nil once taken, else why not.
    /// </summary>
    public const string GameTopic = "ui.theme.game";

    /// <summary>
    /// Registers the topics on a context, with a model of their own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        var theme = new ThemeModel();
        context.Register(PresetTopic, (_, request) => theme.AddPreset(PresetOf(request.AsHash())));
        context.Register(ColorTopic, (_, request) => AddColor(theme, request.AsHash()));
        context.Register(NamesTopic, (_, _) => new RubyArray { Texts(theme.Names), Texts(theme.ColorNames) });
        context.Register(PickTopic, (_, request) => Pick(theme, request));
        context.Register(ResolveTopic, (_, request) => theme.Resolve(request.AsText()) is { } resolved ? Write(resolved) : RubyNil.Value);
        context.Register(LookTopic, (_, request) => Look(theme, request.AsArray()));
        context.Register(GameTopic, (_, request) => SetGame(theme, request.AsHash()));
    }

    /// <summary>
    /// Reads a preset as the scripts send it.
    /// </summary>
    /// <param name="request">The preset.</param>
    /// <returns>The preset.</returns>
    /// <exception cref="BridgeRequestException">A color of its palette or a size is none.</exception>
    private static PresetSpec PresetOf(RubyHash request)
    {
        string name = request["name"].AsText();
        var palette = new Dictionary<string, Rgba>(System.StringComparer.Ordinal);
        if (request["palette"] is RubyHash colors)
        {
            foreach ((RubyValue role, RubyValue color) in colors)
            {
                palette[role.AsText()] = ColorOf(color) ?? throw new BridgeRequestException($"{name} gives {role.AsText()} {color}, which is no color.");
            }
        }

        var typography = new Dictionary<string, int>(System.StringComparer.Ordinal);
        if (request["typography"] is RubyHash sizes)
        {
            foreach ((RubyValue typo, RubyValue size) in sizes)
            {
                typography[typo.AsText()] = size.AsInt();
            }
        }

        return new PresetSpec(name, request["from"].IsNil ? null : request["from"].AsText(), palette, typography, request["mod"].AsText())
        {
            Game = !request["game"].IsNil && request["game"].AsBool(),
            Spacing = request["spacing"].IsNil ? null : request["spacing"].AsInt(),
            Rows = request["rows"] is RubyArray rows ? (rows[0].AsInt(), rows[1].AsInt()) : null,
            Motion = request["motion"] is RubyArray motion ? (motion[0].AsInt(), motion[1].AsInt()) : null,
            Elevation = request["elevation"] is RubyArray depths ? [.. Ints(depths)] : null,
        };
    }

    /// <summary>
    /// Adds a color name as the scripts send it.
    /// </summary>
    /// <param name="theme">The model.</param>
    /// <param name="request">The color name.</param>
    /// <returns>Nil once added, else why not.</returns>
    private static RubyValue AddColor(ThemeModel theme, RubyHash request)
    {
        string name = request["name"].AsText();
        if (request["moves"] is RubyArray moves)
        {
            var stops = new List<LookColor>();
            foreach (RubyValue stop in moves)
            {
                if (StopOf(stop) is not { } color)
                {
                    return $"The color {name} is given {stop}, which is no color; give \"#RRGGBB\", [r, g, b] or a color name.";
                }

                stops.Add(color);
            }

            return theme.AddEffect(name, stops, request["mod"].AsText());
        }

        if (StopOf(request["value"]) is not { } value)
        {
            return $"The color {name} is given {request["value"]}, which is no color; give \"#RRGGBB\", [r, g, b] or a color name.";
        }

        var byPreset = new Dictionary<string, Rgba>(System.StringComparer.Ordinal);
        if (request["presets"] is RubyHash presets)
        {
            foreach ((RubyValue preset, RubyValue color) in presets)
            {
                if (ColorOf(color) is not { } own)
                {
                    return $"The color {name} is given {color} in {preset.AsText()}, which is no color; give \"#RRGGBB\" or [r, g, b].";
                }

                byPreset[preset.AsText()] = own;
            }
        }

        return theme.AddColor(name, value, byPreset, request["mod"].AsText());
    }

    /// <summary>
    /// Reads a color a color name takes: "#RRGGBB" or [r, g, b(, a)], or any other text as the name
    /// of a role or a color.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The color, null for none.</returns>
    private static LookColor? StopOf(RubyValue value) => value switch
    {
        RubyArray => ColorOf(value) is { } parts ? new LookColor(null, parts) : null,
        RubyString when value.AsText().StartsWith('#') => ColorOf(value) is { } hex ? new LookColor(null, hex) : null,
        RubyString => value.AsText().Length > 0 ? new LookColor(value.AsText(), null) : null,
        _ => null,
    };

    /// <summary>
    /// Takes the player's pick.
    /// </summary>
    /// <param name="theme">The model.</param>
    /// <param name="request">The name, or nil.</param>
    /// <returns>The preset in use and why the pick was not taken, or nil.</returns>
    private static RubyValue Pick(ThemeModel theme, RubyValue request)
    {
        (string name, string? refusal) = theme.Pick(request.IsNil ? null : request.AsText());
        return new RubyArray { name, refusal };
    }

    /// <summary>
    /// Takes the surfaces' colors the game's window gives.
    /// </summary>
    /// <param name="theme">The model.</param>
    /// <param name="request">The colors by surface.</param>
    /// <returns>Nil once taken, else why not.</returns>
    private static RubyValue SetGame(ThemeModel theme, RubyHash request)
    {
        var colors = new Dictionary<string, Rgba>(System.StringComparer.Ordinal);
        foreach ((RubyValue role, RubyValue color) in request)
        {
            if (ColorOf(color) is not { } value)
            {
                return $"The game's window gives {role.AsText()} {color}, which is no color.";
            }

            colors[role.AsText()] = value;
        }

        return theme.SetGame(colors);
    }

    /// <summary>
    /// Tells a button's look.
    /// </summary>
    /// <param name="theme">The model.</param>
    /// <param name="request">[preset, variant, color, text color]; the text color may be left out.</param>
    /// <returns>The look, nil for no preset of that name.</returns>
    private static RubyValue Look(ThemeModel theme, RubyArray request)
    {
        LookColor? color = LookColorOf(request[2]);
        LookColor? textColor = request.Count > 3 ? LookColorOf(request[3]) : null;
        if (theme.Look(request[0].AsText(), request[1].AsText(), color, textColor) is not { } look)
        {
            return RubyNil.Value;
        }

        return new RubyHash
        {
            { "fill", Write(look.Fill) },
            { "edge", Write(look.Edge) },
            { "text", Write(look.Text) },
            { "lit", Write(look.Lit) },
            { "focus", Write(look.Focus) },
        };
    }

    /// <summary>
    /// Reads a button's color as the scripts give it.
    /// </summary>
    /// <param name="given">A name, [r, g, b(, a)] or nil.</param>
    /// <returns>The color, null for nil.</returns>
    private static LookColor? LookColorOf(RubyValue given) =>
        given.IsNil ? null : given is RubyArray ? new LookColor(null, ColorOf(given)) : new LookColor(given.AsText(), null);

    /// <summary>
    /// Writes what a preset holds for the scripts.
    /// </summary>
    /// <param name="resolved">What it holds.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash Write(Resolved resolved)
    {
        var palette = new RubyHash();
        foreach ((string role, Rgba color) in resolved.Palette)
        {
            palette.Add(role, Write(color));
        }

        var colors = new RubyHash();
        foreach ((string name, Rgba color) in resolved.Colors)
        {
            colors.Add(name, Write(color));
        }

        var typography = new RubyHash();
        foreach ((string typo, int size) in resolved.Typography)
        {
            typography.Add(typo, size);
        }

        var elevation = new RubyArray();
        foreach (int depth in resolved.Elevation)
        {
            elevation.Add(depth);
        }

        return new RubyHash
        {
            { "name", resolved.Name },
            { "game", resolved.Game },
            { "palette", palette },
            { "colors", colors },
            { "typography", typography },
            { "spacing", resolved.Spacing },
            { "rows", new RubyArray { resolved.Rows.Normal, resolved.Rows.Dense } },
            { "motion", new RubyArray { resolved.Motion.Fade, resolved.Motion.Slide } },
            { "elevation", elevation },
        };
    }

    /// <summary>
    /// Writes a paint: its role, its color, or a lightened animated color name.
    /// </summary>
    /// <param name="paint">The paint, null for none.</param>
    /// <returns>The role, [r, g, b, a], {"name", "lift"} or nil.</returns>
    private static RubyValue Write(Paint? paint) => paint switch
    {
        null => RubyNil.Value,
        { Role: { } name, Lift: > 0 } => new RubyHash { { "name", name }, { "lift", paint.Lift } },
        { Role: { } role } => role,
        _ => Write(paint.Value!.Value),
    };

    /// <summary>
    /// Writes a color.
    /// </summary>
    /// <param name="color">The color.</param>
    /// <returns>[r, g, b, a].</returns>
    private static RubyArray Write(Rgba color) => new() { color.Red, color.Green, color.Blue, color.Alpha };

    /// <summary>
    /// Reads a color: "#RRGGBB", or [r, g, b] with an alpha or without.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The color, null for none.</returns>
    private static Rgba? ColorOf(RubyValue value) => value switch
    {
        RubyArray parts => Rgba.Read(null, [.. Ints(parts)]),
        RubyString => Rgba.Read(value.AsText(), null),
        _ => null,
    };

    /// <summary>
    /// Reads whole numbers.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>The numbers.</returns>
    private static IEnumerable<int> Ints(RubyArray values)
    {
        foreach (RubyValue value in values)
        {
            yield return value.AsInt();
        }
    }

    /// <summary>
    /// Writes texts.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The Array.</returns>
    private static RubyArray Texts(IEnumerable<string> texts)
    {
        var array = new RubyArray();
        foreach (string text in texts)
        {
            array.Add(text);
        }

        return array;
    }
}
