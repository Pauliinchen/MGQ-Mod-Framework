//----------------------------------------------------------------
//  ThemeTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Dropped the animated colors at a frame, which the scripts work out now
//      Paulinchen  2026-11-05: Checked a color name that follows a role, and the animated colors at a frame
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Topics;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the interface looks as the scripts call them: the framework's presets, a mod's preset
/// and color name with the refusals a modder meets, the player's pick, what a preset holds along
/// its chain, the text on a filled part, a button's look in a color and in a text color of its
/// own, and the animated colors.
/// </summary>
public sealed class ThemeTopicsTests
{
    /// <summary>
    /// Asserts that a mod's preset starts from a framework preset and a mod's color name has its own
    /// color in some presets; that a wrong preset, role or color name and a name taken already are
    /// refused with the nearest right name or the mod that took it; that a color name may follow a
    /// role in each preset; that the player's pick of a
    /// preset that is gone falls back to the first; that a preset holds its own roles, the rest from
    /// its chain, the roles that follow another, and each color name as the nearest preset names it;
    /// that the game's own look leaves its surfaces to the game; and that a button's variants draw
    /// in the preset's colors.
    /// </summary>
    [Fact]
    public void ModPreset_TakesItsChainAndThePlayerPicksIt()
    {
        var ui = new UiContext();
        ThemeTopics.Register(ui.Context);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Monarch", null, ("back", Rgb(36, 10, 14)), ("edge", Rgb(200, 164, 96)), ("heading", Rgb(240, 204, 130)),
            ("text", Rgb(255, 255, 255)), ("gold", Rgb(255, 200, 64)), ("success", Rgb(128, 255, 128)))).IsNil);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Legacy", "Monarch", ("back", Rgb(0, 0, 0)), ("edge", Rgb(140, 140, 140)), ("heading", Rgb(160, 200, 255)))).IsNil);
        RubyHash game = Preset("Game's Default", "Monarch");
        game["game"] = true;
        Assert.True(ui.Value(ThemeTopics.PresetTopic, game).IsNil);

        RubyHash moonlight = Preset("Moonlight", "Legacy", ("back", new RubyArray { 20, 16, 40, 235 }));
        ((RubyHash)moonlight["palette"]).Add("primary", "#B08CFF");
        Assert.True(ui.Value(ThemeTopics.PresetTopic, moonlight).IsNil);
        Assert.Equal("Dusk starts from Legazy, which is no preset; did you mean Legacy?", ui.Value(ThemeTopics.PresetTopic, Preset("Dusk", "Legazy")).AsText());
        Assert.Equal("Dusk sets primery, which is no palette role; did you mean primary?", ui.Value(ThemeTopics.PresetTopic, Preset("Dusk", "Monarch", ("primery", Rgb(1, 2, 3)))).AsText());
        Assert.Equal("A preset named Moonlight exists already, added by Moonlight Mod.", ui.Value(ThemeTopics.PresetTopic, Preset("moonlight", "Monarch")).AsText());

        Assert.True(ui.Value(ThemeTopics.ColorTopic, Color("quest", "#FFC040", "Quest Log", ("Legacy", "#FFD878"))).IsNil);
        Assert.Equal("The color name quest is added already, by Quest Log; prefix rare names with your mod, such as gear_compare_quest.",
            ui.Value(ThemeTopics.ColorTopic, Color("quest", "#000000", "Gear Compare")).AsText());
        Assert.Equal("primary is a palette role; a preset sets it with palette:.", ui.Value(ThemeTopics.ColorTopic, Color("primary", "#000000", "Gear Compare")).AsText());
        Assert.True(ui.Value(ThemeTopics.ColorTopic, Color("banner", "primary", "Quest Log")).IsNil);
        Assert.Equal("The color seal names primery, which is no color name; did you mean primary?", ui.Value(ThemeTopics.ColorTopic, Color("seal", "primery", "Quest Log")).AsText());
        RubyArray names = ui.Value(ThemeTopics.NamesTopic).AsArray();
        Assert.Equal(new RubyArray { "Monarch", "Legacy", "Game's Default", "Moonlight" }, names[0]);
        Assert.Equal(
            new RubyArray { "red", "orange", "yellow", "green", "cyan", "blue", "purple", "magenta", "pink", "white", "black", "grey", "quest", "banner", "rainbow" },
            names[1]);

        Assert.Equal(new RubyArray { "Moonlight", RubyNil.Value }, ui.Value(ThemeTopics.PickTopic, "moonlight"));
        Assert.Equal(new RubyArray { "Monarch", "Starlight is no preset now, so the look is Monarch." }, ui.Value(ThemeTopics.PickTopic, "Starlight"));

        RubyHash held = ui.Value(ThemeTopics.ResolveTopic, "Moonlight").AsHash();
        RubyHash palette = held["palette"].AsHash();
        Assert.Equal(new RubyArray { 20, 16, 40, 235 }, palette["back"]);
        Assert.Equal(Rgb(140, 140, 140), palette["edge"]);
        Assert.Equal(new RubyArray { 176, 140, 255, 255 }, palette["primary"]);
        Assert.Equal(Rgb(160, 200, 255), palette["info"]);
        Assert.Equal(Rgb(255, 255, 255), palette["text"]);
        Assert.Equal(Rgb(128, 255, 128), palette["ally"]);
        Assert.Equal(Rgb(255, 216, 120), held["colors"].AsHash()["quest"]);
        Assert.Equal(new RubyArray { 176, 140, 255, 255 }, held["colors"].AsHash()["banner"]);
        Assert.Equal(Rgb(255, 192, 64), ui.Value(ThemeTopics.ResolveTopic, "Monarch").AsHash()["colors"].AsHash()["quest"]);

        RubyHash gameHeld = ui.Value(ThemeTopics.ResolveTopic, "Game's Default").AsHash();
        Assert.True(gameHeld["game"].AsBool());
        Assert.False(gameHeld["palette"].AsHash().ContainsKey("back"));
        Assert.Equal(Rgb(255, 255, 255), gameHeld["palette"].AsHash()["text"]);

        RubyHash filled = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Moonlight", "filled", "primary" }).AsHash();
        Assert.Equal(new RubyArray { 176, 140, 255, 255 }, filled["fill"]);
        Assert.Equal(new RubyArray { 0, 0, 0, 255 }, filled["text"]);
        Assert.Equal(new RubyArray { 180, 146, 255, 255 }, filled["lit"]);
        RubyHash outlined = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Moonlight", "outlined", RubyNil.Value }).AsHash();
        Assert.Equal(new RubyArray { RubyNil.Value, "edge", "text", "picked", "title" }, new RubyArray { outlined["fill"], outlined["edge"], outlined["text"], outlined["lit"], outlined["focus"] });
        RubyHash quest = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Legacy", "text", "quest" }).AsHash();
        Assert.Equal(Rgb(255, 216, 120), quest["text"]);
    }

    /// <summary>
    /// Asserts that a filled button without a color fills in the primary color; that a part filled
    /// in a role or a color of its own writes text_dark or text_light, whichever contrasts more with
    /// the fill, and a mod's preset its own text_dark; and that the game's own look takes its
    /// primary and tertiary from the game's heading and edge as handed over, leaving the surfaces to
    /// the game.
    /// </summary>
    [Fact]
    public void FilledParts_WriteTheTextThatContrastsMore()
    {
        var ui = new UiContext();
        ThemeTopics.Register(ui.Context);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Monarch", null, ("heading", Rgb(240, 204, 130)), ("edge", Rgb(200, 164, 96)), ("text", Rgb(255, 255, 255)),
            ("primary", Rgb(200, 160, 80)), ("secondary", Rgb(255, 200, 64)), ("tertiary", Rgb(214, 112, 128)),
            ("text_dark", Rgb(0, 0, 0)), ("text_light", Rgb(255, 255, 255)))).IsNil);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Legacy", "Monarch", ("primary", Rgb(160, 200, 255)), ("tertiary", Rgb(96, 208, 176)))).IsNil);
        RubyHash game = Preset("Game's Default", "Monarch");
        game["game"] = true;
        Assert.True(ui.Value(ThemeTopics.PresetTopic, game).IsNil);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Moonlight", "Legacy", ("text_dark", Rgb(16, 8, 32)))).IsNil);

        RubyHash plain = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", RubyNil.Value }).AsHash();
        Assert.Equal(new RubyArray { Rgb(200, 160, 80), Rgb(0, 0, 0) }, new RubyArray { plain["fill"], plain["text"] });
        RubyHash own = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", new RubyArray { 120, 20, 30 } }).AsHash();
        Assert.Equal(new RubyArray { Rgb(120, 20, 30), Rgb(255, 255, 255) }, new RubyArray { own["fill"], own["text"] });
        RubyHash moonlight = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Moonlight", "filled", "primary" }).AsHash();
        Assert.Equal(Rgb(16, 8, 32), moonlight["text"]);

        var window = new RubyHash { { "heading", Rgb(132, 170, 255) }, { "edge", Rgb(90, 60, 140) }, { "back", new RubyArray { 60, 60, 60, 192 } } };
        Assert.True(ui.Value(ThemeTopics.GameTopic, window).IsNil);
        RubyHash gameHeld = ui.Value(ThemeTopics.ResolveTopic, "Game's Default").AsHash()["palette"].AsHash();
        Assert.Equal(new RubyArray { Rgb(132, 170, 255), Rgb(90, 60, 140) }, new RubyArray { gameHeld["primary"], gameHeld["tertiary"] });
        Assert.False(gameHeld.ContainsKey("heading"));
        RubyHash gameFilled = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Game's Default", "filled", "tertiary" }).AsHash();
        Assert.Equal(new RubyArray { Rgb(90, 60, 140), Rgb(255, 255, 255) }, new RubyArray { gameFilled["fill"], gameFilled["text"] });
    }

    /// <summary>
    /// Asserts that a button's own text color wins over the text its preset writes on its color in
    /// every variant: a color, a mod's color name, text_light, and a surface, which stays its role.
    /// </summary>
    [Fact]
    public void Button_TextColorOfItsOwnWins()
    {
        var ui = new UiContext();
        ThemeTopics.Register(ui.Context);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Monarch", null, ("heading", Rgb(240, 204, 130)), ("text", Rgb(255, 255, 255)),
            ("primary", Rgb(240, 204, 130)), ("text_dark", Rgb(0, 0, 0)), ("text_light", Rgb(255, 255, 255)))).IsNil);
        Assert.True(ui.Value(ThemeTopics.ColorTopic, Color("quest", "#FFC040", "Quest Log")).IsNil);

        RubyHash filled = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", "primary", "quest" }).AsHash();
        Assert.Equal(new RubyArray { Rgb(240, 204, 130), Rgb(255, 192, 64) }, new RubyArray { filled["fill"], filled["text"] });
        RubyHash light = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", "primary", "text_light" }).AsHash();
        Assert.Equal(Rgb(255, 255, 255), light["text"]);
        RubyHash outlined = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "outlined", "primary", new RubyArray { 16, 32, 48 } }).AsHash();
        Assert.Equal(new RubyArray { Rgb(240, 204, 130), Rgb(16, 32, 48) }, new RubyArray { outlined["edge"], outlined["text"] });
        RubyHash plain = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "text", RubyNil.Value, "heading" }).AsHash();
        Assert.Equal("heading", plain["text"].AsText());
    }

    /// <summary>
    /// Asserts that a filled button in an animated color keeps the name for its fill, lights 5 %
    /// toward white and writes the text that stays readable on all its colors, a lambda's samples
    /// over its cycle included.
    /// </summary>
    [Fact]
    public void AnimatedColors_FilledButtonKeepsItsTextReadable()
    {
        var ui = new UiContext();
        ThemeTopics.Register(ui.Context);
        Assert.True(ui.Value(ThemeTopics.PresetTopic, Preset("Monarch", null, ("text", Rgb(255, 255, 255)), ("text_dark", Rgb(0, 0, 0)), ("text_light", Rgb(255, 255, 255)))).IsNil);
        Assert.True(ui.Value(ThemeTopics.ColorTopic, new RubyHash { { "name", "fire" }, { "moves", new RubyArray { "red", "yellow" } }, { "mod", "Fire Mod" } }).IsNil);
        RubyHash filled = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", "fire" }).AsHash();
        Assert.Equal(
            new RubyArray { "fire", new RubyHash { { "name", "fire" }, { "lift", 5 } }, Rgb(0, 0, 0) },
            new RubyArray { filled["fill"], filled["lit"], filled["text"] });

        Assert.True(ui.Value(ThemeTopics.ColorTopic, new RubyHash { { "name", "blink" }, { "moves", new RubyArray { Rgb(0, 0, 0), Rgb(255, 255, 255) } }, { "mod", "Fire Mod" } }).IsNil);
        RubyHash blink = ui.Value(ThemeTopics.LookTopic, new RubyArray { "Monarch", "filled", "blink" }).AsHash();
        Assert.Equal(Rgb(0, 0, 0), blink["text"]);
    }

    /// <summary>
    /// Writes an opaque color as the scripts send one.
    /// </summary>
    /// <param name="red">Its red.</param>
    /// <param name="green">Its green.</param>
    /// <param name="blue">Its blue.</param>
    /// <returns>[r, g, b, 255].</returns>
    private static RubyArray Rgb(int red, int green, int blue) => new() { red, green, blue, 255 };

    /// <summary>
    /// Writes a preset as the scripts send one.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="from">The preset it starts from.</param>
    /// <param name="roles">The roles it sets.</param>
    /// <returns>The request.</returns>
    private static RubyHash Preset(string name, string? from, params (string Role, RubyValue Color)[] roles)
    {
        var palette = new RubyHash();
        foreach ((string role, RubyValue color) in roles)
        {
            palette.Add(role, color);
        }

        return new RubyHash { { "name", name }, { "from", from }, { "palette", palette }, { "mod", name == "Moonlight" ? "Moonlight Mod" : "Mod Framework" } };
    }

    /// <summary>
    /// Writes a color name as the scripts send one.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <param name="value">Its color.</param>
    /// <param name="mod">The mod that adds it.</param>
    /// <param name="presets">Its color in some presets.</param>
    /// <returns>The request.</returns>
    private static RubyHash Color(string name, string value, string mod, params (string Preset, string Color)[] presets)
    {
        var own = new RubyHash();
        foreach ((string preset, string color) in presets)
        {
            own.Add(preset, color);
        }

        return new RubyHash { { "name", name }, { "value", value }, { "presets", own }, { "mod", mod } };
    }
}
