//----------------------------------------------------------------
//  ThemeModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Kept an animated color name as the colors it moves through, which the scripts move
//      Paulinchen  2026-11-05: Added animated color names that slide or pulse, a color name that follows another, and
//                              the basic colors and the rainbow as built-in names
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQParadox.ModFramework.Ui.Theme;

/// <summary>
/// The looks of the interface: the presets the framework and the mods add, the color names mods
/// add, plain or animated, the preset the player picked, what each preset holds once its chain of
/// presets is worked out, and the looks of a button's variants in a color.
/// </summary>
internal sealed class ThemeModel
{
    /// <summary>
    /// The palette roles every part takes as color names: MudBlazor's, the framework's and the
    /// surfaces of the boxes.
    /// </summary>
    public static readonly string[] Roles =
    [
        "primary", "secondary", "tertiary", "info", "success", "warning", "error", "default",
        "text", "text_dark", "text_light", "dim", "gold", "own", "ally", "system",
        "back", "plate", "picked", "field", "heading", "edge", "track", "rim", "title", "well", "tab",
    ];

    /// <summary>
    /// The surfaces of the boxes, which the game's own look takes from the game's window skin.
    /// </summary>
    public static readonly string[] Surfaces = ["back", "plate", "picked", "field", "heading", "edge", "track", "rim", "title", "well", "tab"];

    /// <summary>
    /// The roles the game's own look takes from the game's window unless it or a preset nearer sets
    /// them: the surfaces, and the primary and tertiary colors, which follow the heading and the
    /// edge there.
    /// </summary>
    public static readonly string[] GameGiven = [.. Surfaces, "primary", "tertiary"];

    /// <summary>
    /// The typography names a text takes as its size.
    /// </summary>
    public static readonly string[] Typos = ["h6", "subtitle1", "subtitle2", "body1", "body2", "caption", "overline"];

    /// <summary>
    /// The looks of a button.
    /// </summary>
    public static readonly string[] Variants = ["filled", "outlined", "text"];

    /// <summary>
    /// The roles that take another role's color unless a preset of their chain sets them.
    /// </summary>
    private static readonly Dictionary<string, string> Derived = new(StringComparer.Ordinal)
    {
        ["primary"] = "heading",
        ["info"] = "heading",
        ["system"] = "heading",
        ["secondary"] = "gold",
        ["tertiary"] = "edge",
        ["ally"] = "success",
        ["default"] = "text",
    };

    /// <summary>
    /// How far a filled button lightens toward white while it is lit, in percent.
    /// </summary>
    private const int LitLift = 5;

    /// <summary>
    /// The color a lit filled button lightens toward.
    /// </summary>
    private static readonly Rgba White = new(255, 255, 255, 255);

    /// <summary>
    /// The dark text on a fill where no preset of the chain sets text_dark.
    /// </summary>
    private static readonly Rgba Black = new(0, 0, 0, 255);

    /// <summary>
    /// The most edits between a wrong name and the name it is taken for.
    /// </summary>
    private const int Near = 2;

    /// <summary>
    /// Who adds the built-in color names, as the scripts name the framework.
    /// </summary>
    private const string Framework = "Mod Framework";

    /// <summary>
    /// The plain color names the framework adds, which a slide or a pulse may name.
    /// </summary>
    private static readonly (string Name, Rgba Value)[] BasicColors =
    [
        ("red", new(255, 0, 0, 255)), ("orange", new(255, 165, 0, 255)), ("yellow", new(255, 255, 0, 255)), ("green", new(0, 255, 0, 255)),
        ("cyan", new(0, 255, 255, 255)), ("blue", new(0, 0, 255, 255)), ("purple", new(128, 0, 255, 255)), ("magenta", new(255, 0, 255, 255)),
        ("pink", new(255, 128, 192, 255)), ("white", new(255, 255, 255, 255)), ("black", new(0, 0, 0, 255)), ("grey", new(128, 128, 128, 255)),
    ];

    /// <summary>
    /// The colors of the built-in slide through every hue, as MGQ Infinity's rainbow names move.
    /// </summary>
    private static readonly string[] RainbowStops = ["red", "yellow", "green", "cyan", "blue", "magenta"];

    /// <summary>
    /// The presets in the order the player's row offers them.
    /// </summary>
    private readonly List<Preset> _presets = [];

    /// <summary>
    /// The plain color names the framework and the mods added, by name, in the order added.
    /// </summary>
    private readonly Dictionary<string, AddedColor> _colors = new(StringComparer.Ordinal);

    /// <summary>
    /// The animated color names the framework and the mods added, by name, in the order added.
    /// </summary>
    private readonly Dictionary<string, AddedEffect> _effects = new(StringComparer.Ordinal);

    /// <summary>
    /// The surfaces' colors the game's window gives in its window color now, by role.
    /// </summary>
    private Dictionary<string, Rgba> _game = new(StringComparer.Ordinal);

    /// <summary>
    /// Gets the presets' names in the order the player's row offers them.
    /// </summary>
    public IReadOnlyList<string> Names => [.. _presets.Select(preset => preset.Name)];

    /// <summary>
    /// Initializes a new instance of the <see cref="ThemeModel"/> class with the built-in color
    /// names: the basic colors and the rainbow.
    /// </summary>
    public ThemeModel()
    {
        foreach ((string name, Rgba value) in BasicColors)
        {
            _colors[name] = new AddedColor(new LookColor(null, value), [], Framework);
        }

        _effects["rainbow"] = new AddedEffect([.. RainbowStops.Select(stop => new LookColor(stop, null))], Framework);
    }

    /// <summary>
    /// Gets the color names added, plain and animated, in the order they were added.
    /// </summary>
    public IReadOnlyList<string> ColorNames => [.. _colors.Keys, .. _effects.Keys];

    /// <summary>
    /// Adds a preset. Only the first preset starts from none; every other one starts from one
    /// added before it.
    /// </summary>
    /// <param name="spec">The preset.</param>
    /// <returns>Null once added, else why it was refused, as a sentence.</returns>
    public string? AddPreset(PresetSpec spec)
    {
        ArgumentNullException.ThrowIfNull(spec);
        if (string.IsNullOrWhiteSpace(spec.Name))
        {
            return "A preset needs a name.";
        }

        if (Find(spec.Name) is { } same)
        {
            return $"A preset named {same.Name} exists already, added by {same.Mod}.";
        }

        Preset? from = null;
        if (spec.From is not null)
        {
            from = Find(spec.From);
            if (from is null)
            {
                return $"{spec.Name} starts from {spec.From}, which is no preset{Hint(spec.From, Names)}";
            }
        }
        else if (_presets.Count > 0)
        {
            return $"{spec.Name} needs from:, the preset it starts from, such as {_presets[0].Name}.";
        }

        foreach (string role in spec.Palette.Keys)
        {
            if (!Roles.Contains(role))
            {
                return $"{spec.Name} sets {role}, which is no palette role{Hint(role, Roles)}";
            }
        }

        foreach (string typo in spec.Typography.Keys)
        {
            if (!Typos.Contains(typo))
            {
                return $"{spec.Name} sets the size of {typo}, which is no typography name{Hint(typo, Typos)}";
            }
        }

        _presets.Add(new Preset(spec, from));
        return null;
    }

    /// <summary>
    /// Adds a color name, with its color in some presets. Names are global: a second mod that adds
    /// the same name is refused.
    /// </summary>
    /// <param name="name">The name, such as "quest".</param>
    /// <param name="value">Its color in every preset that names none of its own: a color, or a role
    /// or a plain color name added before, which it follows in every preset.</param>
    /// <param name="byPreset">Its color in some presets, by their names.</param>
    /// <param name="mod">The mod that adds it.</param>
    /// <returns>Null once added, else why it was refused, as a sentence.</returns>
    public string? AddColor(string name, LookColor value, IReadOnlyDictionary<string, Rgba> byPreset, string mod)
    {
        ArgumentNullException.ThrowIfNull(value);
        ArgumentNullException.ThrowIfNull(byPreset);
        if (NameRefusal(name, mod) is { } refusal)
        {
            return refusal;
        }

        if (value.Name is { } follows && PlainNameRefusal(name, follows) is { } wrong)
        {
            return wrong;
        }

        foreach (string preset in byPreset.Keys)
        {
            if (Find(preset) is null)
            {
                return $"The color {name} names the preset {preset}, which is no preset{Hint(preset, Names)}";
            }
        }

        _colors[name] = new AddedColor(value, byPreset.ToDictionary(pair => Find(pair.Key)!.Name, pair => pair.Value, StringComparer.Ordinal), mod);
        return null;
    }

    /// <summary>
    /// Adds an animated color name, which the scripts move. Its colors are colors, roles or plain
    /// color names, which it takes in the preset drawn.
    /// </summary>
    /// <param name="name">The name, such as "fire".</param>
    /// <param name="stops">The colors it moves through: a slide's or a pulse's, or the samples of a
    /// mod's lambda over a cycle.</param>
    /// <param name="mod">The mod that adds it.</param>
    /// <returns>Null once added, else why it was refused, as a sentence.</returns>
    public string? AddEffect(string name, IReadOnlyList<LookColor> stops, string mod)
    {
        ArgumentNullException.ThrowIfNull(stops);
        if (NameRefusal(name, mod) is { } refusal)
        {
            return refusal;
        }

        if (stops.Count == 0)
        {
            return $"The color {name} moves through no color.";
        }

        foreach (LookColor stop in stops)
        {
            if (stop.Name is { } stopName && PlainNameRefusal(name, stopName) is { } wrong)
            {
                return wrong;
            }
        }

        _effects[name] = new AddedEffect(stops, mod);
        return null;
    }

    /// <summary>
    /// Takes the surfaces' colors the game's window gives in its window color, which the roles of
    /// the game's own look that follow a surface take.
    /// </summary>
    /// <param name="colors">The colors by surface.</param>
    /// <returns>Null once taken, else why they were refused, as a sentence.</returns>
    public string? SetGame(IReadOnlyDictionary<string, Rgba> colors)
    {
        ArgumentNullException.ThrowIfNull(colors);
        foreach (string role in colors.Keys)
        {
            if (!Surfaces.Contains(role))
            {
                return $"The game's window gives {role}, which is no surface{Hint(role, Surfaces)}";
            }
        }

        _game = new Dictionary<string, Rgba>(colors, StringComparer.Ordinal);
        return null;
    }

    /// <summary>
    /// Tells the preset in use for the player's pick: the preset of that name, else the first, as
    /// when the mod that added the picked one is off.
    /// </summary>
    /// <param name="name">The pick, null for none.</param>
    /// <returns>The preset's name, and why the pick was not taken, null when it was.</returns>
    public (string Name, string? Refusal) Pick(string? name)
    {
        if (_presets.Count == 0)
        {
            return (name ?? string.Empty, "No preset is added yet.");
        }

        if (name is null)
        {
            return (_presets[0].Name, null);
        }

        return Find(name) is { } preset
            ? (preset.Name, null)
            : (_presets[0].Name, $"{name} is no preset now, so the look is {_presets[0].Name}.");
    }

    /// <summary>
    /// Works out what a preset holds along its chain: each value from the nearest preset that sets
    /// it, a derived role from the role it follows, and each color name in this preset or the
    /// nearest one it starts from that names one, else its own color.
    /// </summary>
    /// <param name="name">The preset's name.</param>
    /// <returns>What it holds, null for no preset of that name.</returns>
    public Resolved? Resolve(string name)
    {
        if (Find(name) is not { } preset)
        {
            return null;
        }

        var chain = new List<Preset>();
        for (Preset? each = preset; each is not null; each = each.From)
        {
            chain.Add(each);
        }

        int gameAt = chain.FindIndex(each => each.Spec.Game);
        var palette = new Dictionary<string, Rgba>(StringComparer.Ordinal);
        foreach (string role in Roles)
        {
            int reach = gameAt >= 0 && GameGiven.Contains(role) ? gameAt + 1 : chain.Count;
            int at = chain.FindIndex(0, reach, each => each.Spec.Palette.ContainsKey(role));
            if (at >= 0)
            {
                palette[role] = chain[at].Spec.Palette[role];
            }
        }

        // The game's surfaces stay out of the palette, which tells the scripts to draw them in the
        // game's window skin.
        var known = new Dictionary<string, Rgba>(palette, StringComparer.Ordinal);
        if (gameAt >= 0)
        {
            foreach ((string surface, Rgba color) in _game)
            {
                known.TryAdd(surface, color);
            }
        }

        foreach ((string role, string follows) in Derived)
        {
            if (!palette.ContainsKey(role) && known.TryGetValue(follows, out Rgba value))
            {
                palette[role] = value;
            }
        }

        // A color that follows another names a role or a color added before it, which is worked out
        // by then.
        var colors = new Dictionary<string, Rgba>(StringComparer.Ordinal);
        foreach ((string color, AddedColor added) in _colors)
        {
            Rgba? own = First<Rgba>(chain, each => added.ByPreset.TryGetValue(each.Name, out Rgba value) ? value : null) ?? added.Value.Value;
            if ((own ?? (added.Value.Name is { } follows ? Named(palette, colors, follows) : null)) is { } found)
            {
                colors[color] = found;
            }
        }

        var typography = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (string typo in Typos)
        {
            if (First<int>(chain, each => each.Spec.Typography.TryGetValue(typo, out int size) ? size : null) is { } size)
            {
                typography[typo] = size;
            }
        }

        return new Resolved(
            preset.Name,
            gameAt >= 0,
            palette,
            colors,
            typography,
            First(chain, each => each.Spec.Spacing) ?? 4,
            First(chain, each => each.Spec.Rows) ?? (24, 20),
            First(chain, each => each.Spec.Motion) ?? (12, 8),
            chain.Select(each => each.Spec.Elevation).FirstOrDefault(each => each is not null) ?? []);
    }

    /// <summary>
    /// Tells the look of a button's variant in a color in a preset: its fill, its edge, its text,
    /// its fill while the pointer, a press or the focus lights it, and its edge while focused. Each
    /// is a role, which the preset's palette holds and the game's own look takes from the game's
    /// window, or a color worked out here; null for none. A text color of the button's own wins
    /// over the preset's.
    /// </summary>
    /// <param name="preset">The preset's name.</param>
    /// <param name="variant">One of <see cref="Variants"/>.</param>
    /// <param name="color">The button's color: a role or a color name, a color, or null for the default.</param>
    /// <param name="textColor">The button's own text color, null for the preset's.</param>
    /// <returns>The look, null for no preset of that name.</returns>
    public ButtonLook? Look(string preset, string variant, LookColor? color, LookColor? textColor = null)
    {
        if (Resolve(preset) is not { } resolved)
        {
            return null;
        }

        ButtonLook look = PresetLook(resolved, variant, color);
        return textColor is not null && PaintOf(resolved, textColor) is { } text ? look with { Text = text } : look;
    }

    /// <summary>
    /// Tells the look of a button's variant in a color in the preset's own text colors. A filled
    /// button without a color fills in the primary color.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="variant">One of <see cref="Variants"/>.</param>
    /// <param name="color">The button's color, null for none.</param>
    /// <returns>The look.</returns>
    private ButtonLook PresetLook(Resolved resolved, string variant, LookColor? color)
    {
        color ??= variant == "filled" ? new LookColor("primary", null) : null;
        if (color?.Name is { } animated && _effects.TryGetValue(animated, out AddedEffect? effect))
        {
            Paint moving = Paint.Of(animated);
            return variant switch
            {
                "filled" => new ButtonLook(moving, null, Paint.Of(TextOnAll(resolved, Stops(resolved, effect.Stops))), Paint.Lifted(animated, LitLift), Paint.Of("title")),
                "outlined" => new ButtonLook(null, moving, moving, Paint.Of("picked"), Paint.Of("title")),
                _ => new ButtonLook(null, null, moving, Paint.Of("picked"), Paint.Of("title")),
            };
        }

        if (color is null || PaintOf(resolved, color) is not { } own)
        {
            return variant switch
            {
                "outlined" => new ButtonLook(null, Paint.Of("edge"), Paint.Of("text"), Paint.Of("picked"), Paint.Of("title")),
                _ => new ButtonLook(null, null, Paint.Of("text"), Paint.Of("picked"), Paint.Of("title")),
            };
        }

        Rgba? value = color.Value ?? Named(resolved, color.Name!);
        return variant switch
        {
            "filled" when value is { } fill => new ButtonLook(own, null, Paint.Of(TextOn(resolved, fill)), Paint.Of(fill.Toward(White, LitLift / 100.0)), Paint.Of("title")),
            "filled" => new ButtonLook(own, null, Paint.Of("text"), Paint.Of("picked"), Paint.Of("title")),
            "outlined" => new ButtonLook(null, own, own, Paint.Of("picked"), Paint.Of("title")),
            _ => new ButtonLook(null, null, own, Paint.Of("picked"), Paint.Of("title")),
        };
    }

    /// <summary>
    /// Tells the paint of a color as the scripts give it: a surface and an animated color name stay
    /// their names, the surface taken from the game's window in the game's own look, and any other
    /// name becomes its color in the preset.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="color">The color.</param>
    /// <returns>The paint, null for a name the preset does not hold.</returns>
    private Paint? PaintOf(Resolved resolved, LookColor color)
    {
        if (color.Name is { } animated && _effects.ContainsKey(animated))
        {
            return Paint.Of(animated);
        }

        string? role = color.Name is { } named && Roles.Contains(named) ? named : null;
        Rgba? value = color.Value ?? (color.Name is { } name ? Named(resolved, name) : null);
        if (role is not null && (value is null || Surfaces.Contains(role)))
        {
            return Paint.Of(role);
        }

        return value is { } known ? Paint.Of(known) : null;
    }

    /// <summary>
    /// Tells the text on a fill: the preset's text_dark or text_light, whichever has the higher
    /// WCAG contrast ratio with the fill.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="fill">The fill.</param>
    /// <returns>The text color.</returns>
    private static Rgba TextOn(Resolved resolved, Rgba fill)
    {
        Rgba dark = resolved.Palette.TryGetValue("text_dark", out Rgba setDark) ? setDark : Black;
        Rgba light = resolved.Palette.TryGetValue("text_light", out Rgba setLight) ? setLight : White;
        return fill.ContrastWith(dark) >= fill.ContrastWith(light) ? dark : light;
    }

    /// <summary>
    /// Tells the text on a fill that moves through colors: text_dark or text_light, whichever keeps
    /// the higher contrast ratio with the color it contrasts least with.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="fills">The colors the fill moves through.</param>
    /// <returns>The text color.</returns>
    private static Rgba TextOnAll(Resolved resolved, IReadOnlyList<Rgba> fills)
    {
        Rgba dark = resolved.Palette.TryGetValue("text_dark", out Rgba setDark) ? setDark : Black;
        Rgba light = resolved.Palette.TryGetValue("text_light", out Rgba setLight) ? setLight : White;
        return fills.Min(fill => fill.ContrastWith(dark)) >= fills.Min(fill => fill.ContrastWith(light)) ? dark : light;
    }

    /// <summary>
    /// Tells the colors an animated color moves through in a preset; a name the preset does not hold
    /// takes the preset's text color.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="stops">The colors of the animated color.</param>
    /// <returns>The colors.</returns>
    private static Rgba[] Stops(Resolved resolved, IReadOnlyList<LookColor> stops) =>
        [.. stops.Select(stop => stop.Value ?? Named(resolved, stop.Name!) ?? (resolved.Palette.TryGetValue("text", out Rgba text) ? text : White))];

    /// <summary>
    /// Finds a role's or an earlier color name's color while a preset is worked out.
    /// </summary>
    /// <param name="palette">The roles worked out.</param>
    /// <param name="colors">The color names worked out so far.</param>
    /// <param name="name">The role or the color name.</param>
    /// <returns>The color, null for none.</returns>
    private static Rgba? Named(Dictionary<string, Rgba> palette, Dictionary<string, Rgba> colors, string name) =>
        palette.TryGetValue(name, out Rgba role) ? role : colors.TryGetValue(name, out Rgba color) ? color : null;

    /// <summary>
    /// Checks a new color name: a word of small letters, digits and underscores that is no role
    /// and no name added already.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <param name="mod">The mod that adds it.</param>
    /// <returns>Why it is refused, null when it is free.</returns>
    private string? NameRefusal(string name, string mod)
    {
        if (string.IsNullOrEmpty(name) || !name.All(letter => letter is (>= 'a' and <= 'z') or (>= '0' and <= '9') or '_'))
        {
            return $"A color name is a word of small letters, digits and underscores, such as quest, not {name}.";
        }

        if (Roles.Contains(name))
        {
            return $"{name} is a palette role; a preset sets it with palette:.";
        }

        string? taken = _colors.TryGetValue(name, out AddedColor? same) ? same.Mod : _effects.TryGetValue(name, out AddedEffect? moving) ? moving.Mod : null;
        return taken is null ? null : $"The color name {name} is added already, by {taken}; prefix rare names with your mod, such as {Prefixed(mod, name)}.";
    }

    /// <summary>
    /// Checks a name a new color takes its color from: a role or a plain color name added before.
    /// </summary>
    /// <param name="name">The new color's name.</param>
    /// <param name="follows">The name it takes its color from.</param>
    /// <returns>Why it is refused, null when it fits.</returns>
    private string? PlainNameRefusal(string name, string follows)
    {
        if (Roles.Contains(follows) || _colors.ContainsKey(follows))
        {
            return null;
        }

        return _effects.ContainsKey(follows)
            ? $"The color {name} names {follows}, which moves itself; name a plain color."
            : $"The color {name} names {follows}, which is no color name{Hint(follows, [.. Roles, .. _colors.Keys])}";
    }

    /// <summary>
    /// Finds a preset by its name, ignoring case.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The preset, null for none.</returns>
    private Preset? Find(string name) => _presets.Find(preset => string.Equals(preset.Name, name.Trim(), StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Finds a role's or a color name's color in a preset; a surface of the game's own look is
    /// known only to the game.
    /// </summary>
    /// <param name="resolved">The preset.</param>
    /// <param name="name">The role or the color name.</param>
    /// <returns>The color, null for none.</returns>
    private static Rgba? Named(Resolved resolved, string name) =>
        resolved.Palette.TryGetValue(name, out Rgba role) ? role : resolved.Colors.TryGetValue(name, out Rgba color) ? color : null;

    /// <summary>
    /// Finds a value along a chain: the first preset's that sets it.
    /// </summary>
    /// <typeparam name="T">The value's type.</typeparam>
    /// <param name="chain">The presets, nearest first.</param>
    /// <param name="read">Reads a preset's own value, null when it sets none.</param>
    /// <returns>The value, null when none sets it.</returns>
    private static T? First<T>(IEnumerable<Preset> chain, Func<Preset, T?> read)
        where T : struct
    {
        foreach (Preset each in chain)
        {
            if (read(each) is { } value)
            {
                return value;
            }
        }

        return null;
    }

    /// <summary>
    /// Writes a rare name with a mod's name before it, as a hint.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="name">The name.</param>
    /// <returns>Such as "gear_compare_up".</returns>
    private static string Prefixed(string mod, string name)
    {
        string prefix = new([.. mod.ToLowerInvariant().Select(letter => char.IsLetterOrDigit(letter) ? letter : '_')]);
        return $"{prefix.Trim('_')}_{name}";
    }

    /// <summary>
    /// Ends a refusal with the nearest right name, within <see cref="Near"/> edits.
    /// </summary>
    /// <param name="wrong">The wrong name.</param>
    /// <param name="names">The right names.</param>
    /// <returns>"; did you mean x?" or ".".</returns>
    private static string Hint(string wrong, IEnumerable<string> names)
    {
        string? best = null;
        int bestDistance = Near + 1;
        foreach (string name in names)
        {
            int distance = Distance(wrong.ToLowerInvariant(), name.ToLowerInvariant());
            if (distance < bestDistance)
            {
                (best, bestDistance) = (name, distance);
            }
        }

        return best is null ? "." : $"; did you mean {best}?";
    }

    /// <summary>
    /// Counts the edits between two words: letters put in, taken out or changed.
    /// </summary>
    /// <param name="from">One word.</param>
    /// <param name="to">The other word.</param>
    /// <returns>The edits.</returns>
    private static int Distance(string from, string to)
    {
        int[] row = [.. Enumerable.Range(0, to.Length + 1)];
        for (int index = 0; index < from.Length; index++)
        {
            int[] previous = (int[])row.Clone();
            row[0] = index + 1;
            for (int place = 0; place < to.Length; place++)
            {
                row[place + 1] = Math.Min(Math.Min(previous[place + 1] + 1, row[place] + 1), previous[place] + (from[index] == to[place] ? 0 : 1));
            }
        }

        return row[to.Length];
    }

    /// <summary>
    /// A preset added and the preset it starts from.
    /// </summary>
    /// <param name="Spec">What it sets.</param>
    /// <param name="From">The preset it starts from, null for the first.</param>
    private sealed record Preset(PresetSpec Spec, Preset? From)
    {
        /// <summary>
        /// Gets its name.
        /// </summary>
        public string Name => Spec.Name;

        /// <summary>
        /// Gets the mod that added it.
        /// </summary>
        public string Mod => Spec.Mod;
    }

    /// <summary>
    /// A plain color name added.
    /// </summary>
    /// <param name="Value">Its color where no preset of the chain names one: a color, or the role or
    /// the color name it follows.</param>
    /// <param name="ByPreset">Its color in some presets, by their names.</param>
    /// <param name="Mod">The mod that added it.</param>
    private sealed record AddedColor(LookColor Value, Dictionary<string, Rgba> ByPreset, string Mod);

    /// <summary>
    /// An animated color name added.
    /// </summary>
    /// <param name="Stops">The colors it moves through.</param>
    /// <param name="Mod">The mod that added it.</param>
    private sealed record AddedEffect(IReadOnlyList<LookColor> Stops, string Mod);
}

/// <summary>
/// A color as red, green, blue and alpha, each 0 to 255.
/// </summary>
/// <param name="Red">Its red.</param>
/// <param name="Green">Its green.</param>
/// <param name="Blue">Its blue.</param>
/// <param name="Alpha">Its alpha.</param>
internal readonly record struct Rgba(int Red, int Green, int Blue, int Alpha)
{
    /// <summary>
    /// Reads a color as the scripts write one: "#RRGGBB", or red, green and blue with an alpha or
    /// without.
    /// </summary>
    /// <param name="text">"#RRGGBB", or null.</param>
    /// <param name="parts">The parts, or null.</param>
    /// <returns>The color, null when it is none.</returns>
    public static Rgba? Read(string? text, IReadOnlyList<int>? parts)
    {
        if (text is not null)
        {
            return text.Length == 7 && text[0] == '#' && int.TryParse(text.AsSpan(1), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out int rgb)
                ? new Rgba((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, 255)
                : null;
        }

        if (parts is null || parts.Count is < 3 or > 4 || parts.Any(part => part is < 0 or > 255))
        {
            return null;
        }

        return new Rgba(parts[0], parts[1], parts[2], parts.Count == 4 ? parts[3] : 255);
    }

    /// <summary>
    /// Moves the color toward another, keeping its alpha.
    /// </summary>
    /// <param name="other">The other color.</param>
    /// <param name="share">How far, from 0 to 1.</param>
    /// <returns>The color between.</returns>
    public Rgba Toward(Rgba other, double share) => new(Mix(Red, other.Red, share), Mix(Green, other.Green, share), Mix(Blue, other.Blue, share), Alpha);

    /// <summary>
    /// Tells the WCAG contrast ratio between this color and another, from 1 to 21; the alphas are
    /// left out.
    /// </summary>
    /// <param name="other">The other color.</param>
    /// <returns>The ratio.</returns>
    public double ContrastWith(Rgba other)
    {
        double mine = Luminance();
        double theirs = other.Luminance();
        return (Math.Max(mine, theirs) + 0.05) / (Math.Min(mine, theirs) + 0.05);
    }

    /// <summary>
    /// Tells the color's relative luminance as WCAG defines it, from 0 for black to 1 for white.
    /// </summary>
    /// <returns>The luminance.</returns>
    private double Luminance() => 0.2126 * Linear(Red) + 0.7152 * Linear(Green) + 0.0722 * Linear(Blue);

    /// <summary>
    /// Turns one sRGB part into its linear light, as WCAG's relative luminance takes it.
    /// </summary>
    /// <param name="part">The part, 0 to 255.</param>
    /// <returns>Its linear light, 0 to 1.</returns>
    private static double Linear(int part)
    {
        double share = part / 255.0;
        return share <= 0.04045 ? share / 12.92 : Math.Pow((share + 0.055) / 1.055, 2.4);
    }

    /// <summary>
    /// Moves one part toward another.
    /// </summary>
    /// <param name="from">The part.</param>
    /// <param name="to">The other part.</param>
    /// <param name="share">How far, from 0 to 1.</param>
    /// <returns>The part between.</returns>
    private static int Mix(int from, int to, double share) => (int)Math.Round(from + (to - from) * share);
}

/// <summary>
/// What a preset sets itself; whatever it leaves out it takes from the preset it starts from.
/// </summary>
/// <param name="Name">Its name.</param>
/// <param name="From">The preset it starts from, null for the first preset.</param>
/// <param name="Palette">The roles it sets.</param>
/// <param name="Typography">The sizes of the typography names it sets, in pixels.</param>
/// <param name="Mod">The mod that adds it, or the framework.</param>
internal sealed record PresetSpec(string Name, string? From, IReadOnlyDictionary<string, Rgba> Palette, IReadOnlyDictionary<string, int> Typography, string Mod)
{
    /// <summary>
    /// Gets whether it is the game's own look, whose surfaces come from the game's window skin.
    /// </summary>
    public bool Game { get; init; }

    /// <summary>
    /// Gets the pixels of one unit of spacing, null to take the preset it starts from.
    /// </summary>
    public int? Spacing { get; init; }

    /// <summary>
    /// Gets the heights of a normal and a dense row, null to take the preset it starts from.
    /// </summary>
    public (int Normal, int Dense)? Rows { get; init; }

    /// <summary>
    /// Gets the frames of a fade and of a slide, null to take the preset it starts from.
    /// </summary>
    public (int Fade, int Slide)? Motion { get; init; }

    /// <summary>
    /// Gets the shadow's depth in pixels of each elevation from 0 up, null to take the preset it
    /// starts from.
    /// </summary>
    public int[]? Elevation { get; init; }
}

/// <summary>
/// What a preset holds along its chain.
/// </summary>
/// <param name="Name">Its name.</param>
/// <param name="Game">Whether the game's own look lies on its chain, so the surfaces it leaves out come from the game.</param>
/// <param name="Palette">Each role's color; a surface the game gives is left out.</param>
/// <param name="Colors">Each color name's color.</param>
/// <param name="Typography">Each typography name's size in pixels.</param>
/// <param name="Spacing">The pixels of one unit of spacing.</param>
/// <param name="Rows">The heights of a normal and a dense row.</param>
/// <param name="Motion">The frames of a fade and of a slide.</param>
/// <param name="Elevation">The shadow's depth of each elevation.</param>
internal sealed record Resolved(
    string Name,
    bool Game,
    IReadOnlyDictionary<string, Rgba> Palette,
    IReadOnlyDictionary<string, Rgba> Colors,
    IReadOnlyDictionary<string, int> Typography,
    int Spacing,
    (int Normal, int Dense) Rows,
    (int Fade, int Slide) Motion,
    int[] Elevation);

/// <summary>
/// A button's color as the scripts give it: a role or a color name, or a color.
/// </summary>
/// <param name="Name">The role or the color name, null for a color.</param>
/// <param name="Value">The color, null for a name.</param>
internal sealed record LookColor(string? Name, Rgba? Value);

/// <summary>
/// One color of a look: a role of the preset's palette, or a color.
/// </summary>
/// <param name="Role">The role, null for a color.</param>
/// <param name="Value">The color, null for a role.</param>
/// <param name="Lift">How far the scripts lighten each color of an animated role toward white as
/// they draw it, in percent; 0 for not at all.</param>
internal sealed record Paint(string? Role, Rgba? Value, int Lift = 0)
{
    /// <summary>
    /// Makes the paint of a role.
    /// </summary>
    /// <param name="role">The role.</param>
    /// <returns>The paint.</returns>
    public static Paint Of(string role) => new(role, null);

    /// <summary>
    /// Makes the paint of a color.
    /// </summary>
    /// <param name="value">The color.</param>
    /// <returns>The paint.</returns>
    public static Paint Of(Rgba value) => new(null, value);

    /// <summary>
    /// Makes the paint of an animated color name lightened toward white, as a lit filled part
    /// draws, since its colors are only known frame by frame in the scripts.
    /// </summary>
    /// <param name="name">The animated color name.</param>
    /// <param name="percent">How far, in percent.</param>
    /// <returns>The paint.</returns>
    public static Paint Lifted(string name, int percent) => new(name, null, percent);
}

/// <summary>
/// The look of a button: its fill, its edge and its text, its fill while lit and its edge while
/// focused; null for none.
/// </summary>
/// <param name="Fill">Its fill.</param>
/// <param name="Edge">Its edge.</param>
/// <param name="Text">Its text.</param>
/// <param name="Lit">Its fill while the pointer, a press or the focus lights it.</param>
/// <param name="Focus">Its edge while it has the focus.</param>
internal sealed record ButtonLook(Paint? Fill, Paint? Edge, Paint Text, Paint Lit, Paint Focus);
