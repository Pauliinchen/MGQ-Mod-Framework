#----------------------------------------------------------------
#  layer_theme_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked the text C# picks for a bubble's fill on a bubble with contrast
#      Paulinchen  2026-11-06: Removed the check of an old color name
#                            - Called the engine's classes by their names under UI::Engine
#                            - Expected a paper of theme :game to keep that theme, the look of the game's own windows
#      Paulinchen  2026-11-05: Checked that the plain text a speech bubble holds takes the text C# picks for its fill
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers theming in the UI layer (design section 8) in a booted game against FakeTree and C#'s
# theme topics as a stand-in answers them: a mod's preset and color name handed to C#, the
# player's pick of an earlier session coming back once its mod adds it, the pick in the Interface
# Look row, color names drawn in the theme of the part, the primary, secondary and tertiary colors
# with the dark and light texts and the game's window colors they follow in the game's own look, a
# subtree theme, a mod's defaults for its own buttons only, a button's own text color, the text of a
# speech bubble with contrast on its fill, and the refusals a modder meets.
# ModFramework.Tests covers what C# decides.

require_relative "layer_support"

LOOKS = <<-RUBY
  module Moon_Looks
    UI = Mod_Framework::UI

    UI.preset "Moonlight", from: "Legacy", palette: { primary: "#B08CFF", back: [20, 16, 40, 235] }
    UI.color :quest, "#FFC040", "Legacy" => "#FFD878"
    UI.defaults :button, variant: :outlined

    class Board < UI::Component
      def render
        window "Board", id: :board do
          text "Quests", color: :quest
          button "Accept", color: :primary, on_click: -> { }
          button "Later", variant: :text, on_click: -> { }
          paper theme: "Legacy" do
            text "Old quests", color: :quest
          end
          paper theme: :game do
            text "Plain"
          end
        end
      end
    end

    class Tags < UI::Component
      def render
        window "Tags", id: :tags do
          text "Rare", color: :tertiary
          button "Claim", variant: :filled, color: :tertiary, text_color: "#102030", on_click: -> { }
        end
      end
    end
  end
RUBY

OTHER = <<-RUBY
  module Other_Looks
    class Shop < Mod_Framework::UI::Component
      def render
        window "Shop" do
          button "Buy", on_click: -> { }
        end
      end
    end
  end
RUBY

# What C#'s theme topics answer for the framework's presets and the mod's, as ThemeModel works
# them out.
TABLES = {
  "Monarch" => { "name" => "Monarch", "game" => false, "palette" => { "back" => [36, 10, 14, 235], "text" => [255, 255, 255, 255], "primary" => [200, 160, 80, 255] },
                 "colors" => { "quest" => [255, 192, 64, 255] }, "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] },
  "Legacy" => { "name" => "Legacy", "game" => false, "palette" => { "back" => [0, 0, 0, 170], "text" => [255, 255, 255, 255], "primary" => [160, 200, 255, 255] },
                "colors" => { "quest" => [255, 216, 120, 255] }, "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] },
  "Moonlight" => { "name" => "Moonlight", "game" => false,
                   "palette" => { "back" => [20, 16, 40, 235], "text" => [255, 255, 255, 255], "primary" => [176, 140, 255, 255], "tertiary" => [96, 208, 176, 255] },
                   "colors" => { "quest" => [255, 216, 120, 255] }, "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] },
  "Game's Default" => { "name" => "Game's Default", "game" => true, "palette" => { "text" => [255, 255, 255, 255] },
                        "colors" => { "quest" => [255, 192, 64, 255] }, "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] }
}

# The framework's settings, where an earlier session kept the player's pick of the mod's preset.
SETTINGS = "Patch/Mod_Framework/Mod_Framework.ini"

# Adds C#'s theme topics to the DLL's side: each preset and color name sent is noted, a color name
# sent twice refused, a preset not sent yet refused as a pick, the presets answered from TABLES,
# the game's own look with its primary and tertiary in the game's heading and edge C# was handed
# last, and a button's look in its own text color where it has one; the settings keep the mod's
# preset as the player's pick.
#
# @param fake [FakeBridge] The DLL's side.
# @return [FakeBridge] The same.
def theme_topics(fake)
  $sent = []
  $game_colors = []
  fake.answer("ini.read") { |(path)| $files[path] ||= (path == SETTINGS ? { "ui_preset" => "Moonlight" } : {}) }
  fake.answer("ui.theme.preset") { |request| $sent << request; nil }
  fake.answer("ui.theme.color") do |request|
    taken = $sent.find { |each| each["value"] && each["name"] == request["name"] }
    $sent << request
    taken ? "The color name #{request['name']} is added already, by #{taken['mod']}; prefix rare names with your mod, such as other_looks_quest." : nil
  end
  fake.answer("ui.theme.names") { |_request| [$sent.select { |each| each["palette"] || each["from"] || each["game"] }.map { |each| each["name"] }, ["quest"]] }
  fake.answer("ui.theme.pick") { |name| $sent.any? { |each| each["name"] == name.to_s && !each.key?("value") } ? [name, nil] : ["Monarch", "There is no preset #{name}."] }
  fake.answer("ui.theme.game") { |colors| $game_colors << colors; nil }
  fake.answer("ui.theme.resolve") do |name|
    game = $game_colors.last
    next TABLES[name] unless name == "Game's Default" && game

    table = TABLES[name]
    table.merge("palette" => table["palette"].merge("primary" => game["heading"], "tertiary" => game["edge"]))
  end
  fake.answer("ui.theme.look") do |request|
    $looks << request
    { "fill" => nil, "edge" => [176, 140, 255, 255], "text" => request[3] || [176, 140, 255, 255], "lit" => "picked", "focus" => "title" }
  end
  fake
end

# A picture that also notes the color each text was last drawn in.
class Bitmap
  # Notes a text drawn with its place and its color.
  def draw_text(x, y, width, _height, text, align = 0)
    @texts << [landing(x, width, text, align), y, text]
    $drawn[text] = @font.color.to_a
  end
end

# Lists an engine part and every part inside it.
#
# @param part [Object] The engine part.
# @return [Array] The parts.
def every_part(part)
  [part] + part.children.map { |child| every_part(child) }.flatten
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(theme_topics(tree_dll(tree))) do
    ui = Mod_Framework::UI
    engine = ui::Engine
    $looks = []
    $drawn = {}
    load_mod("Patch/Moon_Looks.rb", LOOKS)
    load_mod("Patch/Other_Looks.rb", OTHER)
    $scene_now = Scene_Base.new
    frame

    # The framework's presets reach C# before the mod's, which starts from Legacy with its palette;
    # the color name carries its color in Legacy.
    moonlight = $sent.find { |each| each["name"] == "Moonlight" }
    quest = $sent.find { |each| each["name"] == "quest" }
    check("the framework's presets reach C# first, then the mod's with its palette and its mod",
          [$sent.map { |each| each["name"] }.first(4), moonlight.values_at("from", "palette", "mod")],
          [["Monarch", "Legacy", "Game's Default", "Moonlight"], ["Legacy", { "primary" => "#B08CFF", "back" => [20, 16, 40, 235] }, "Moon Looks"]])
    check("the color name carries its own color and its color in Legacy", quest.values_at("value", "presets"), ["#FFC040", { "Legacy" => "#FFD878" }])

    # The player picked the mod's preset in an earlier session; it comes back once the mod adds it,
    # after the settings were read. The player picks another in the Interface Look row: Style's
    # colors follow it and the pick is kept.
    theme = engine::Theme
    check("the player's pick of the mod's preset comes back once the mod adds it", [theme.current.name, ui::Engine::Style::BACK.to_a], ["Moonlight", [20, 16, 40, 235]])
    check("the Interface Look row offers the mod's preset after the framework's", theme.names, ["Monarch", "Legacy", "Game's Default", "Moonlight"])
    theme.choose("Legacy")
    frame
    check("picking another sets the box colors in place and keeps the pick", [ui::Engine::Style::BACK.to_a, $files[SETTINGS]["ui_preset"]], [[0, 0, 0, 170], "Legacy"])
    theme.choose("Moonlight")

    # A text's color name draws in the preset of the part: the player's, or the subtree's.
    ui.open(Moon_Looks::Board)
    frame
    parts = every_part(engine::Layer.tops.last.root.engine)
    labels = parts.select { |part| part.is_a?(engine::Label) }
    papers = parts.select { |part| part.theme_value != true && part.children.any? }
    check("a color name draws in the player's preset, and in a subtree's preset inside it",
          [labels[0].palette.named(labels[0].color).to_a, labels[1].palette.named(labels[1].color).to_a], [[255, 216, 120, 255], [255, 216, 120, 255]])
    theme.choose("Monarch")
    check("the player's pick changes the color outside the subtree only",
          [labels[0].palette.named(:quest).to_a, labels[1].palette.named(:quest).to_a, papers.map { |paper| paper.theme }], [[255, 192, 64, 255], [255, 216, 120, 255], ["Legacy", :game]])

    # The mod's defaults give its buttons their variant, a variant given wins, and the look comes
    # from C# in the button's color.
    buttons = parts.select { |part| part.is_a?(engine::Button) }
    check("the mod's buttons take its default variant unless they give one, and C# gives each look in the player's preset",
          [buttons.map { |button| button.variant }, $looks.uniq.first(2)], [[:outlined, :text], [["Moonlight", "outlined", "primary", nil], ["Moonlight", "text", nil, nil]]])
    ui.open(Other_Looks::Shop)
    frame
    other = every_part(engine::Layer.tops.last.root.engine).find { |part| part.is_a?(engine::Button) }
    check("another mod's button keeps the built-in default", other.variant, :text)

    # The framework's presets give C# a primary, a secondary and a tertiary color, and Monarch the
    # dark and the light text a filled part picks from. A part's :tertiary draws in the player's preset as C# works it out. The game's
    # own look takes its primary and tertiary from the game's heading and edge: C# gets the box
    # colors of the game's window before it works that look out, and anew once the window color
    # changes.
    built_ins = $sent.first(2).map { |each| (%w(primary secondary tertiary text_dark text_light) & each["palette"].keys).size }
    check("the framework's presets give C# the three colors, Monarch the dark and the light text too", built_ins, [5, 3])
    theme.choose("Moonlight")
    ui.open(Moon_Looks::Tags)
    frame
    rare = every_part(engine::Layer.tops.last.root.engine).find { |part| part.is_a?(engine::Label) }
    check("a part's :tertiary draws in the player's preset", rare.palette.named(rare.color).to_a, [96, 208, 176, 255])
    $game_system = Struct.new(:window_tone, :conf).new(Tone.new(0, 0, 0, 0), {})
    theme.choose("Game's Default")
    back = ui::Engine::Style::BACK.to_a
    $game_system.window_tone = Tone.new(40, 0, 0, 0)
    frame
    check("the game's own look takes the game's heading and edge through C#, which gets the window's box colors anew as the window color changes",
          [theme.current.roles.values_at(:primary, :tertiary), $game_colors.map { |colors| colors["back"] }.uniq.last(2)],
          [[ui::Engine::Style::HEADING.to_a, ui::Engine::Style::EDGE.to_a], [back, ui::Engine::Style::BACK.to_a]])

    # A button's own text color reaches C# with its color, and its text draws in the color C# answers.
    claim = $looks.find { |request| request[2] == "tertiary" }
    check("a button's own text color reaches C# and its text draws in it", [claim, $drawn["Claim"]],
          [["Moonlight", "filled", "tertiary", [16, 32, 48, 255]], [16, 32, 48, 255]])

    # The plain text a speech bubble with contrast holds takes the text C# picks for a part filled
    # in the bubble's color.
    baker = Sprite.new
    baker.x = 300
    baker.y = 200
    bubble = ui::Engine::Bubble.new(:follow => baker, :color => Color.new(40, 40, 120), :contrast => true)
    bubble.add(ui::Engine::Label.new(:text => "Bread!", :wrap => true))
    bubble.open
    frame
    Graphics.update
    check("the plain text in a speech bubble with contrast draws in the text C# picks for its fill",
          [$looks.any? { |request| request[1, 2] == ["filled", [40, 40, 120, 255]] }, $drawn["Bread!"]], [true, [176, 140, 255, 255]])
    bubble.close

    # The refusals: a color name, an old color name and a preset that are no names, and a color
    # name another mod added first.
    refusal = lambda do |code|
      begin
        load_mod("Patch/Other_Looks.rb", code)
        nil
      rescue engine::MarkupError => e
        e.message
      end
    end
    check("a misspelt color name names the mod's color",
          refusal.call("class Other_Looks::Note < Mod_Framework::UI::Component; def render; text 'x', color: :qest; end; end; Other_Looks::Note.new.render")[/did you mean :quest\?/],
          "did you mean :quest?")

    check("a misspelt preset in theme: names the preset",
          refusal.call("class Other_Looks::Dusk < Mod_Framework::UI::Component; def render; paper(theme: 'Legazy') { }; end; end; Other_Looks::Dusk.new.render")[/did you mean "Legacy"\?/],
          "did you mean \"Legacy\"?")
    check("a color name another mod added first is refused at the call, naming that mod and the line",
          refusal.call("Mod_Framework::UI.color :quest, '#000000'"),
          "The color name quest is added already, by Moon Looks; prefix rare names with your mod, such as other_looks_quest. (Other_Looks.rb:1)")
  end
end
