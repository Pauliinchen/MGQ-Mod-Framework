#----------------------------------------------------------------
#  layer_colors_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked a pulse through the rainbow's colors past its first two
#                            - Checked that every text on a fill is white with the black outline unless its part has contrast
#                            - Checked that texts are outlined in black unless a part asks for the contrasting outline or a color
#                            - Checked that a bar's text half over its fill draws in the texts picked for the fill and the well
#                            - Checked that the letters of an animated color keep the outline of the plain text while dark
#                            - Checked that a chip's color fills it as a pill lower than a button, its text contrasting
#      Paulinchen  2026-11-06: Checked that a grey text has the dark outline
#                            - Checked that a bar's label on its fill takes the text picked for the fill
#                            - Checked that a tab whose page hides writes its title in the text picked for its plate
#                            - Checked the slide and pulse colors the scripts work out
#                            - Checked the badges of title commands, which replace the commands an adoption added
#                            - Checked UI.color_now on a color name, a role in a game window's look, a color and a moving one
#                            - Checked that a color named before the DLL started reaches C# once it starts
#      Paulinchen  2026-11-05: Checked that a filled button's dark text has a white outline
#                            - Created
#
#----------------------------------------------------------------

# Covers the colors a mod names (design v2, "Answer on own and animated colors") in a booted game
# against FakeTree and C#'s theme topics as a stand-in answers them, through a mod's loot window: a
# plain color, a slide, a pulse through UI::RAINBOW and two lambdas named once as the mod loads, the plain color and
# the slide used as a text's color: and as text codes, the pulse as a text's color, a misspelt name in a code, a game color number past
# the window skin's, a lambda that fails, the built-in rainbow filling a button that lights, a
# chip filled in the plain color, the animated parts drawn anew every few frames while they show and no longer once the window closed,
# the plain text with the black outline on every fill (a filled button, a chip, tabs, a bar's texts),
# a mod whose UI.defaults give its buttons contrast: true, a button's own text color, an outline color
# set by hand;
# and the game's own windows: color names in their text codes, a dark text's own outline and a command's
# badge in the rainbow; UI.color_now for a mod that draws on a bitmap itself; last, a mod that names a color
# before the DLL started.

require_relative "layer_support"
require_relative "game_lists_support"

LOOT = <<-'RUBY'
  module Loot_Colors
    UI = Mod_Framework::UI

    UI.color :legendary, [181, 162, 21]
    UI.color :fire, slide: [:red, :yellow]
    UI.color :alarm, pulse: UI::RAINBOW
    UI.color :blink, ->(letter, frame) { frame % 60 < 30 ? [0, 0, 0] : [255, 255, 255] }
    UI.color :ember, ->(letter, frame) { raise ArgumentError, "no ember" if frame > 0; [255, 80, 0] }

    class Loot < UI::Component
      def render
        window "Loot", id: :loot do
          text "Sword", color: :legendary
          text "Blade", color: :fire
          text "Halt", color: :alarm
          text "\\C[legendary]Gold\\C[0] \\C[fire]Fire\\C[0] \\C[legndary]Odd\\C[0] \\C[706]Relic", escapes: true
          text "Ash", color: :ember
          text "Dusk", color: :blink
          button "Claim", variant: :filled, color: :rainbow, on_click: -> { }
          chip_set do
            chip "Rare", color: :legendary
          end
          tabs pages: false do
            tab "Items"
            tab "Spells"
          end
          progress value: 100, label: "HP"
          progress value: 50, text: "Half"
          text "Ink", color: [0, 0, 0], outline: [200, 40, 40]
        end
      end
    end
  end
RUBY

SHOP = <<-'RUBY'
  module Shop_Colors
    UI = Mod_Framework::UI

    UI.defaults :button, contrast: true

    class Shop < UI::Component
      def render
        window "Shop", id: :shop do
          button "Buy", variant: :filled, color: :legendary, on_click: -> { }
          button "Keep", variant: :filled, color: :legendary, text_color: [255, 200, 64], on_click: -> { }
        end
      end
    end
  end
RUBY

# Gives the game's lists, and the game's window what the game's text codes need: \C with a number
# as the game reads it, and the color it sets.
GAME_CODES = lambda do
  define_game_lists
  Window_Base.class_eval do
    attr_reader :color
    define_method(:obtain_escape_param) { |text| text.slice!(/^\[\d+\]/)[/\d+/].to_i rescue 0 }
    define_method(:process_escape_character) { |code, text, _pos| change_color(text_color(obtain_escape_param(text))) if code.upcase == "C" }
    private :process_escape_character
  end
end

# Gives the game's window, which a new game session makes anew, what MGQ Infinity changes: its text
# color 706 is the gold of its legendary items; and its conversion, which turns the backslashes
# into the escape character.
def infinity_window
  Window_Base.class_eval do
    define_method(:text_color) { |index| index == 706 ? Color.new(181, 162, 21) : Color.new(255, 255, 255) }
    define_method(:convert_escape_characters) { |text| text.gsub("\\", "\e") }
  end
end

# The colors of the built-in rainbow and of the mod's :fire.
RAINBOW = [[255, 0, 0], [255, 255, 0], [0, 255, 0], [0, 255, 255], [0, 0, 255], [255, 0, 255]]
FIRE = [[255, 0, 0], [255, 255, 0]]

# The colors of a slide's first letters at a frame, as the design gives them: each letter 42
# degrees further on its cycle, 3 degrees a frame back.
#
# @param stops [Array<Array<Integer>>] The colors it slides through.
# @param frame [Integer] The frame.
# @param count [Integer] How many letters.
# @return [Array<Array<Integer>>] Each letter's color.
def slide_colors(stops, frame, count)
  segment = 360.0 / stops.size
  (0...count).map do |letter|
    place = (letter * 42 - frame * 3) % 360
    from = (place / segment).floor
    share = (place - from * segment) / segment
    stops[from].zip(stops[(from + 1) % stops.size]).map { |one, other| (one + (other - one) * share).round } + [255]
  end
end

# The color of a pulse at a frame: on its way from each of its colors to the next and from the last
# back to the first, a cycle of 360 degrees at 3 a frame.
#
# @param stops [Array<Array<Integer>>] The colors it goes through.
# @param frame [Integer] The frame.
# @return [Array<Integer>] The color.
def pulse_color(stops, frame)
  segment = 360.0 / stops.size
  place = frame * 3 % 360
  from = (place / segment).floor
  share = (1 - Math.cos((place - from * segment) / segment * Math::PI)) / 2
  stops[from].zip(stops[(from + 1) % stops.size]).map { |one, other| (one + (other - one) * share).round } + [255]
end

# Adds C#'s theme topics to the DLL's side: each color name sent is noted and listed, Monarch holds
# the basic colors and the mod's plain color, a button's look in the rainbow keeps the name and
# lights 5 % toward white, the text on a tab's plate and on a bar's well is white and on every other fill black unless
# the button has a text color of its own, and an
# escaped text is laid out at 9 pixels a letter, a color code
# giving its number or its name.
#
# @param fake [FakeBridge] The DLL's side.
# @return [FakeBridge] The same.
def color_topics(fake)
  $sent = []
  $frames = []
  monarch = { "name" => "Monarch", "game" => false, "palette" => { "back" => [36, 10, 14, 235], "text" => [255, 255, 255, 255], "error" => [255, 64, 64, 255], "primary" => [200, 160, 80, 255] },
              "colors" => { "red" => [255, 0, 0, 255], "yellow" => [255, 255, 0, 255], "legendary" => [181, 162, 21, 255] }, "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] }
  fake.answer("ui.theme.preset") { |request| $sent << request; nil }
  fake.answer("ui.theme.color") { |request| $sent << request; nil }
  fake.answer("ui.theme.names") do |_request|
    added = $sent.select { |each| each.key?("value") || each.key?("moves") }
    [["Monarch"], ["red", "yellow"] + added.map { |each| each["name"] } + ["rainbow"]]
  end
  fake.answer("ui.theme.pick") { |_name| ["Monarch", nil] }
  fake.answer("ui.theme.resolve") { |_name| monarch }
  fake.answer("ui.theme.look") do |request|
    text = request[3] || (%w(tab well).include?(request[2]) ? [255, 255, 255, 255] : [0, 0, 0, 255])
    { "fill" => request[2], "edge" => nil, "text" => text, "lit" => { "name" => request[2], "lift" => 5 }, "focus" => "title" }
  end
  fake.answer("ui.glyphs") { |_request| nil }
  fake.answer("ui.text.runs") do |request|
    runs = []
    x = 0
    color = nil
    request[2].split(/(\eC\[\w+\])/).each do |piece|
      if piece =~ /\A\eC\[(\w+)\]\z/
        code = $1
        color = code =~ /\A\d+\z/ ? code.to_i : code
      elsif !piece.empty?
        runs << { "x" => x, "text" => piece, "color" => color }
        x += piece.size * 9
      end
    end
    [{ "width" => x, "runs" => runs }]
  end
  fake
end

# A picture that also notes each text drawn with its color, in order.
class Bitmap
  # Notes a text drawn with its place, its color and its outline's color, nil without one.
  def draw_text(x, y, width, _height, text, align = 0)
    @texts << [landing(x, width, text, align), y, text]
    $drawn << [text, @font.color.to_a.map { |value| value.to_i }, @font.outline ? @font.out_color.to_a.map { |value| value.to_i } : nil]
  end
end

# Lists an engine part and every part inside it.
#
# @param part [Object] The engine part.
# @return [Array] The parts.
def every_part(part)
  [part] + part.children.map { |child| every_part(child) }.flatten
end

# Tells the colors the letters of a word were drawn in last, one draw per letter.
#
# @param word [String] The word.
# @return [Array<Array<Integer>>, nil] The colors, nil when it was not drawn letter by letter.
def letter_colors(word)
  letters = word.chars.to_a
  (0..$drawn.size - letters.size).to_a.reverse.each do |start|
    found = $drawn[start, letters.size]
    return found.map { |_text, color| color } if found.map { |text, _color| text } == letters
  end
  nil
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(color_topics(tree_dll(tree)), :game => GAME_CODES) do
    ui = Mod_Framework::UI
    engine = ui::Engine
    $drawn = []
    # Notes each animated color worked out with the frame and the count, which the checks compare
    # the colors drawn with.
    class << engine::Colors
      alias_method :worked_colors_of, :colors_of
      define_method(:colors_of) do |animated, count|
        $frames << [animated.name.to_s, Mod_Framework::UI::Engine::Key.frame, count]
        worked_colors_of(animated, count)
      end
    end
    $game_system = Struct.new(:window_tone, :conf).new(Tone.new(0, 0, 0, 0), {})
    infinity_window
    load_mod("Patch/Loot_Colors.rb", LOOT)
    load_mod("Patch/Shop_Colors.rb", SHOP)
    $scene_now = Scene_Base.new
    frame

    # The mod names a plain color, a slide and two lambdas once as it loads; C# keeps each, a lambda
    # with the colors it answers over a cycle, and one that fails with the text color.
    sent = $sent.select { |each| %w(legendary fire alarm blink ember).include?(each["name"]) }
    text = engine::Style::TEXT.to_a.map { |value| value.to_i }
    check("the plain color, the slide, the pulse and the lambdas reach C# with the mod that names them, a lambda with its samples",
          sent.map { |each| each.reject { |key, _value| key == "presets" } },
          [{ "name" => "legendary", "value" => [181, 162, 21], "mod" => "Loot Colors" }, { "name" => "fire", "mod" => "Loot Colors", "moves" => ["red", "yellow"] },
           { "name" => "alarm", "mod" => "Loot Colors", "moves" => RAINBOW },
           { "name" => "blink", "mod" => "Loot Colors", "moves" => [[0, 0, 0, 255], [255, 255, 255, 255]] }, { "name" => "ember", "mod" => "Loot Colors", "moves" => [text] }])

    # A mod whose defaults give its buttons contrast: a filled button takes the dark text C# picks
    # for its gold fill with the light outline, and a button's own text color wins.
    ui.open(Shop_Colors::Shop)
    frame
    check("a mod's own buttons take contrast: true from UI.defaults, the dark text with the light outline, and text_color: wins",
          [$drawn.assoc("Buy").drop(1), $drawn.assoc("Keep").drop(1)], [[[0, 0, 0, 255], [255, 255, 255, 255]], [[255, 200, 64, 255], [0, 0, 0, 255]]])
    engine::Layer.tops.last.mount.component.close(:done)
    frame

    # The window opens: the plain color draws as a color: and as a code, the slide letter by letter
    # in its colors of the frame, as a color: and as a code.
    ui.open(Loot_Colors::Loot)
    frame
    asked = $frames.select { |name, _frame, count| name == "fire" && count == 5 }.last
    check("a text in the plain color, by color: and by its code", [$drawn.assoc("Sword")[1], $drawn.assoc("Gold")[1]], [[181, 162, 21, 255], [181, 162, 21, 255]])
    check("a text in the slide draws letter by letter in the colors of the frame, by color: and by its code",
          [letter_colors("Blade"), letter_colors("Fire")], [slide_colors(FIRE, asked[1], 5), slide_colors(FIRE, $frames.select { |name, _frame, count| name == "fire" && count == 4 }.last[1], 4)])

    dusk = $drawn.each_cons(4).to_a.reverse.find { |letters| letters.map { |each| each[0] } == %w(D u s k) }
    check("letters of an animated color while dark keep the outline of the plain text, so they stand on the plate",
          dusk.map { |_letter, color, outline| [color, outline] }.uniq, [[[0, 0, 0, 255], [0, 0, 0, 255]]])

    # The pulse runs on past its first two colors.
    45.times { frame }
    alarm = $frames.select { |name, _frame, _count| name == "alarm" }.last
    check("a text in a pulse through the rainbow draws every letter in its one color of the frame", letter_colors("Halt"), [pulse_color(RAINBOW, alarm[1])] * 4)

    # A game color number past the window skin's comes from the game's own text color.
    check("a game color number past the window skin's comes from the game's text color", $drawn.assoc("Relic")[1], [181, 162, 21, 255])

    # The filled button is a plate of the rainbow in bands of ten pixels, each in its band's color.
    claim = every_part(engine::Layer.tops.last.root.engine).find { |part| part.is_a?(engine::Button) }
    rect = claim.rect
    left = rect.x - claim.surface.x
    top = rect.y - claim.surface.y
    bands = claim.surface.bitmap.fills.select { |x, y, width, height| y == top && height == rect.height && width <= engine::Colors::BAND && x >= left && x < left + rect.width }
    rainbow = $frames.select { |name, _frame, _count| name == "rainbow" }.last
    check("a filled button in the rainbow is a plate of bands ten pixels wide, each in its band's color",
          [bands.size, bands.map { |fill| fill[4].map { |value| value.to_i } }], [(rect.width + 9) / 10, slide_colors(RAINBOW, rainbow[1], bands.size)])
    white = [[255, 255, 255, 255], [0, 0, 0, 255]]
    on_fills = %w(Claim Rare Items Spells HP).map { |shown| $drawn.assoc(shown).drop(1) }
    halves = $drawn.select { |drawn| drawn[0] == "Half" }.map { |drawn| drawn.drop(1) }.uniq
    check("every text on a fill is white with the black outline: a filled button, a chip, both tabs, a bar's label and a bar's text",
          [on_fills.uniq, halves], [[white], [white]])
    check("an outline color set by hand draws", $drawn.assoc("Ink").drop(1), [[0, 0, 0, 255], [200, 40, 40, 255]])

    # A chip's color fills it row by row with round ends, and C# lays it out lower than a button's
    # line and padding.
    rare = every_part(engine::Layer.tops.last.root.engine).find { |part| part.is_a?(engine::Chip) }
    place = rare.rect
    chip_left = place.x - rare.surface.x
    chip_top = place.y - rare.surface.y
    claim_props = tree.nodes[claim.node][:props]
    button_height = claim_props["row_height"] + claim_props["padding"][0] + claim_props["padding"][2]
    rows = rare.surface.bitmap.fills.select do |x, y, _width, height, color|
      height == 1 && y >= chip_top && y < chip_top + place.height && x >= chip_left && x < chip_left + place.width && color.map { |value| value.to_i } == [181, 162, 21, 255]
    end
    check("a chip's color fills it with round ends and it is lower than a button",
          [rows.map { |fill| fill[1] }.uniq.size, rows.first[0] > chip_left, tree.nodes[rare.node][:props]["size"][1] < button_height],
          [place.height, true, true])

    # Lit by the pointer, each band lightens 5 % toward white.
    tree.post("states", claim.node => engine::Tree::HOVERED)
    frame
    Graphics.update
    lit = claim.surface.bitmap.fills.select { |x, y, width, height| y == top && height == rect.height && width <= engine::Colors::BAND && x >= left && x < left + rect.width }.last(bands.size)
    rainbow = $frames.select { |name, _frame, _count| name == "rainbow" }.last
    check("a lit filled button in the rainbow lightens each band 5 % toward white",
          lit.map { |fill| fill[4].map { |value| value.to_i } }, slide_colors(RAINBOW, rainbow[1], bands.size).map { |rgba| rgba.map { |value| (value + (255 - value) * 0.05).to_i } })

    # The animated parts draw anew every few frames while they show, and no more once the window
    # closed.
    before = $frames.size
    3.times { frame }
    again = $frames.drop(before).map { |name, _frame, _count| name }.uniq.sort

    # A misspelt name in a code draws in the text color and is logged once with the nearest name,
    # however often it draws anew; a lambda that fails draws in the text color, logged once too.
    unknown = $logged.grep(/legndary/)
    check("a misspelt color name draws in the text color, logged once with the nearest name",
          [$drawn.assoc("Odd")[1], unknown.size, unknown.first.to_s[/did you mean :legendary\?/]], [[255, 255, 255, 255], 1, "did you mean :legendary?"])
    check("a lambda that fails draws in the text color, logged once", [letter_colors("Ash"), $logged.grep(/:ember failed/).size], [[text] * 3, 1])
    engine::Layer.tops.last.mount.component.close(:done)
    6.times { frame }
    after = $frames.size
    6.times { frame }
    check("the animated parts draw anew while they show, and stop once their window closed", [again, $frames.size - after, engine::Colors.parts], [["alarm", "blink", "ember", "fire", "rainbow"], 0, 0])

    # The game's own windows take color names in their text codes, in the window's look: a plain one,
    # the theme's, an animated one in its color now, a number as the game reads it, and a name
    # nobody gave in the normal color, logged once.
    window = Window_Base.new
    left = %w([legendary] [primary] [rainbow] [2] [legndry]).map do |code|
      text = "#{code}x"
      window.send(:process_escape_character, "C", text, {})
      [text, window.color.to_a.map { |value| value.to_i }]
    end
    frame
    now = $frames.select { |name, _frame, count| name == "rainbow" && count == 1 }.last
    check("a game window's text code takes a color name of its look, an animated one as it is now, a number as the game does",
          [left, $logged.grep(/game window's text names the color :legndry/).size],
          [[["x", [181, 162, 21, 255]], ["x", [200, 160, 80, 255]], ["x", slide_colors(RAINBOW, now[1], 1)[0]], ["x", [255, 255, 255, 255]], ["x", [255, 255, 255, 255]]], 1])

    # A dark text in a game window keeps the game's own outline.
    window.contents.font.color = Color.new(0, 0, 0)
    window.contents.font.out_color = Font.default_out_color
    window.send(:change_color, Color.new(0, 0, 0))
    check("a dark text in a game window keeps the game's own outline", window.contents.font.out_color.to_a.map { |value| value.to_i }, [0, 0, 0, 128])

    # A mod that draws on a game window's bitmap itself reads each color as the look has it now.
    read = lambda { |name, *place| Mod_Framework::UI.color_now(name, *place).to_a.map { |value| value.to_i } }
    plain = [read.call(:legendary), read.call(:primary, window), read.call("#102030")]
    rainbow = read.call(:rainbow)
    now = $frames.select { |name, _frame, count| name == "rainbow" && count == 1 }.last
    wrong = (Mod_Framework::UI.color_now(:legndary) rescue $!.message)
    check("UI.color_now answers a color name, a role in a game window's look and a color as they are now, a moving one in this frame",
          [plain, rainbow, wrong[/did you mean :\w+/]],
          [[[181, 162, 21, 255], [200, 160, 80, 255], [16, 32, 48, 255]], slide_colors(RAINBOW, now[1], 1)[0], "did you mean :legendary"])

    # A command's badge takes a color name of its window's look; one in the rainbow takes its color
    # now and its row draws anew every few frames while the window shows, no longer once it is gone.
    Mod_Framework::Mods.title_command("Mail", :symbol => :mail, :badge => lambda { 2 }, :badge_color => :legendary)
    Mod_Framework::Mods.title_command("Gift", :symbol => :gift, :badge => lambda { 3 }, :badge_color => :rainbow)
    menu = Window_TitleCommand.new
    menu.update
    menu.refresh
    gift = $frames.select { |name, _frame, count| name == "rainbow" && count == 1 }.last
    check("a command badge draws in a color name of its window's look, and in the rainbow as it is now",
          [$drawn.reverse.assoc("2")[1], $drawn.reverse.assoc("3")[1]], [[181, 162, 21, 255], slide_colors(RAINBOW, gift[1], 1)[0]])
    drawn = lambda { $drawn.count { |shown, _color| shown == "3" } }
    before = drawn.call
    3.times { frame }
    shown = drawn.call - before
    menu.dispose
    3.times { frame }
    check("a badge in the rainbow draws anew while its window shows, and no more once the window is gone", [shown, drawn.call - before], [1, 1])

    # A mod that loads before the DLL starts names a color: nothing is refused, and the name reaches
    # C# with the mod that gave it once the DLL starts.
    Mod_Framework.bridge.close
    Mod_Framework.instance_variable_set(:@available, false)
    Mod_Framework.instance_variable_set(:@started, false)
    load_mod("Patch/Early_Colors.rb", "Mod_Framework::UI.color :early_gold, [200, 170, 40]")
    early = lambda { $sent.select { |each| each["name"] == "early_gold" } }
    waiting = early.call
    Mod_Framework.start
    check("a color named before the DLL started waits and reaches C# once it starts [sent before, sent after]", [waiting, early.call],
          [[], [{ "name" => "early_gold", "value" => [200, 170, 40], "presets" => {}, "mod" => "Early Colors" }]])
  end
end
