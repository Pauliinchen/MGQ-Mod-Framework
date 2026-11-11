#----------------------------------------------------------------
#  layer_game_windows_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Loaded the Mod Collection's Equipment Window from Bundled
#      Paulinchen  2026-11-09: Found the Equipment Window's parts by its ew_ ids
#                            - Checked the Equipment Window's hotkey help by the part in focus
#                            - Checked the shoulders the Equipment Window's hotkey help names on a gamepad
#      Paulinchen  2026-11-08: Checked that the formation's swapped characters keep their own looks
#                            - Covered the looks of the rows of the battle status, the menu status and the party
#                              edit, whose nested class is defined after its patch
#                            - Wrote Gear Compare into the test, since the repository no longer holds it
#                            - Read the samples from their .rb files
#      Paulinchen  2026-11-06: Checked that a title the player moved stays at their place as it updates
#                            - Covered a patch that places, moves and adds to the title, and a menu open before a patch loads
#                            - Left out the old Mods box beside the title's commands, which is gone
#      Paulinchen  2026-11-05: Checked Gear Compare against the Equipment Window of the UI layer
#                            - Checked that the menu greys out the Formation command the game disables
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers UI.patch on the game's windows, UI.replace_window and UI.replace_scene (design v2 section
# 7.6) in a booted game against FakeTree: two mods change the game's menu and its gold window, the
# second one the command the first added; a mod changes every command window and another the menu
# open before it loaded; a mod loaded as the game starts places the title, lets the player move it
# and adds commands that open nothing or fail, also without the DLL; a mod draws the map name's
# window through a component and opens a component in place of the equip screen; a mod changes the
# Equipment Window by its ids and the game's menu by its class, and the Equipment Window's hotkey
# help names the keys of the part in focus; mods give the rows of the battle
# status, the menu status and the party edit looks, the party edit's class defined after its patch,
# and the formation's swapped characters keep theirs.

require_relative "game_lists_support"
require_relative "layer_support"
require_relative "equip_support"

# A mod like Gear Compare: a Compare button on the Equipment Window by its ids, a Compare command
# after Equip and Formation renamed in the game's menu, and the gold window dimmer, by their classes.
GEAR_COMPARE = <<-'RUBY'
  module Gear_Compare
    UI = Mod_Framework::UI

    class CompareDialog < UI::Component
      param :actor

      def render
        dialog "Compare Gear", id: :gear_compare_dialog do
          list Gear_Compare.lines(actor), id: :gear_compare_lines, dense: true
          button "Close", variant: :outlined, on_click: :close
        end
      end
    end

    UI.patch "#ew_equipment_window" do |w|
      w.set "#ew_stats stat_grid", size: :small
      w.append "#ew_buttons" do
        button "Compare", variant: :outlined, on_click: -> { UI.open(CompareDialog, actor: w.read(:actor)) }
      end
    end

    UI.patch "Window_MenuCommand" do |menu|
      menu.after "#equip" do
        command "Compare", id: :gear_compare, if: -> { $game_party.members.size > 1 },
                on_click: -> { UI.open(CompareDialog, actor: $game_party.menu_actor) }
      end
      menu.set "#formation", text: "Party Order"
    end
    UI.patch("Window_Gold") { |gold| gold.set opacity: 160 }

    def self.lines(actor)
      own, others = UI::Game.members.partition { |member| member.equal?(actor) }
      (own + others).map { |member| "#{member.name}: #{UI::Game.equips(member).compact.map { |item| item.params.inject(0, :+) }.inject(0, :+)}" }
    end
  end
RUBY

# Defines the game's menu commands as Paradox lists them, Formation disabled as with one member,
# its gold window and its map name window, which fades its name in once shown.
def define_menu_windows
  [:Window_MenuCommand, :Window_Gold, :Window_MapName].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
  Object.class_eval <<-RUBY
    class Window_MenuCommand < Window_Command
      COMMANDS = [[:item, "Items"], [:equip, "Equip"], [:skill, "Skills"], [:ability, "Abilities"], [:status, "Status"],
                  [:formation, "Formation"], [:library, "Library"], [:config, "Config"], [:save, "Save"], [:game_end, "Game End"]]
      def initialize; super(0, 0); end
      def make_command_list; COMMANDS.each { |symbol, name| add_command(name, symbol, symbol != :formation) }; end
      def names; @list.map { |entry| entry[:name] }; end
    end
    class Window_Gold < Window_Base
      def initialize; super(0, 0, 160, 48); refresh; end
      def refresh; end
    end
    class Window_MapName < Window_Base
      def initialize; super(0, 0, 240, 48); self.contents_opacity = 0; end
      def refresh; contents.clear; end
    end
  RUBY
end

# Lists the texts an engine part and the parts it holds show, in order.
#
# @param part [Mod_Framework::UI::Engine::Component] The part.
# @return [Array<String>] The texts.
def texts_of(part)
  own = part.is_a?(Mod_Framework::UI::Engine::List) ? part.rows.map { |row| row.is_a?(Hash) ? row[:text] : row.to_s } : []
  own << part.text.to_s if !part.container? && part.respond_to?(:text)
  own + part.children.map { |child| texts_of(child) }.flatten
end

# Picks a row of a game command window with the confirm button, as the player does, and lets the
# frame end, which writes the log.
#
# @param window [Window_Command] The window.
# @param index [Integer] The row.
def confirm_row(window, index)
  window.activate
  window.select(index)
  frame
  frame([:C])
  window.update
  Graphics.update
end

MENU_PLUS = <<-RUBY
  module Menu_Plus
    UI = Mod_Framework::UI

    class Notes < UI::Component
      def render
        dialog "Notes", id: :menu_plus_notes do
          text "Buy herbs"
        end
      end
    end

    UI.patch "Window_MenuCommand" do |menu|
      menu.after "#equip" do
        command "Notes", id: :menu_plus_notes, if: -> { $game_party.members.size > 1 }, on_click: -> { UI.open(Notes) }
      end
      menu.set "#formation", text: "Party Order"
      menu.hide "#library"
      menu.on "#save", :click do |original|
        original.call if $save_allowed
      end
    end
    UI.patch("Window_Gold") { |gold| gold.set opacity: 160 }
  end
RUBY

MENU_WORDS = <<-RUBY
  Mod_Framework::UI.patch "Window_MenuCommand #menu_plus_notes" do |notes|
    notes.set text: "Camp Notes"
  end
RUBY

# Two mods change the game's menu and its gold window: the changes hold through the game's
# refreshes, the command the game disables is greyed out, the added command opens a window and the
# menu takes the keys back, a wrapped pick is refused, and the second mod renames the command the
# first one added.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_windows }) do
    ui = Mod_Framework::UI
    equip_party
    load_mod("Patch/Menu_Plus.rb", MENU_PLUS)
    load_mod("Patch/Menu_Words.rb", MENU_WORDS)
    frame
    menu = Window_MenuCommand.new
    saved = []
    menu.set_handler(:save, lambda { saved << :saved })
    check("the menu holds the added command after Equip with the second mod's text, Formation renamed and Library hidden, and is as tall as its commands",
          [menu.names, menu.height], [["Items", "Equip", "Camp Notes", "Skills", "Abilities", "Status", "Party Order", "Config", "Save", "Game End"], 264])
    color_of = lambda { |name| menu.drawn.reverse.find { |text, _color| text == name }[1] }
    check("the menu draws the Formation command the game disables in an opaque grey and the others as the game does",
          [color_of.call("Party Order")[0, 3].uniq.size, color_of.call("Party Order")[0] < 255, color_of.call("Party Order")[3], color_of.call("Items")], [1, true, 255, [255, 255, 255, 255]])

    confirm_row(menu, 2)
    notes = ui::Engine::Layer.tops.last
    opened = [menu.active, notes.id]
    notes.handle.close
    frame
    check("picking the added command opens its window, and the menu takes the keys again once it closed", [*opened, menu.active], [false, "menu_plus_notes", true])

    confirm_row(menu, 8)
    refused = [saved.size, menu.active, layer_lines.grep(/refused/).last]
    $save_allowed = true
    confirm_row(menu, 8)
    check("a wrapped pick that does not run the game's handler is refused and logged, the menu keeping the keys; allowed, the game's handler runs",
          [*refused, saved], [0, true, "Menu Plus refused click of command #save of Window_MenuCommand in Window_MenuCommand (Menu_Plus.rb:18)", [:saved]])

    $game_party.members.pop
    menu.select(9)
    menu.refresh
    check("the added command leaves at the game's next refresh once its if: answers false, the height and the cursor following",
          [menu.names.include?("Camp Notes"), menu.height, menu.index], [false, 240, 8])

    gold = Window_Gold.new
    first = gold.opacity
    gold.opacity = 255
    gold.update
    check("the gold window draws as dim as the patch set, also after its scene changed it", [first, gold.opacity], [160, 160])
  end
end

ANY_COMMANDS = <<-RUBY
  Mod_Framework::UI.patch("window#camp_notes") { |notes| notes.hide "#clear" }
  Mod_Framework::UI.patch "Window_Command" do |commands|
    commands.set "#first", text: "First of all"
    commands.on "#save", :click do |original|
      $save_wraps += 1
      original.call
    end
  end
RUBY

# A mod changes every command window and names a window of its own beside them; a second mod loaded
# once the game runs changes the menu. Each pick runs the wrap once, and a window that sizes itself
# keeps its height.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_windows }) do
    equip_party
    Object.class_eval <<-RUBY
      class Window_Choices < Window_Command
        def initialize; super(0, 0); end
        def make_command_list; add_command("First", :first); 19.times { |row| add_command("Choice \#{row}", :"choice_\#{row}") }; end
        def start; self.height = fitting_height(4); refresh; end
      end
    RUBY
    $save_wraps = 0
    load_mod("Patch/Any_Commands.rb", ANY_COMMANDS)
    frame
    menu = Window_MenuCommand.new
    load_mod("Patch/Menu_Order.rb", "Mod_Framework::UI.patch(\"Window_MenuCommand\") { |menu| menu.set \"#formation\", text: \"Party Order\" }")
    menu.update
    saved = []
    menu.set_handler(:save, lambda { saved << :saved })
    confirm_row(menu, 8)
    check("the patches on every command window and on the menu both reach the menu open before the second loaded, and a pick runs the wrap and the game's handler once",
          [menu.names.values_at(5, 8), $save_wraps, saved], [["Party Order", "Save"], 1, [:saved]])

    choices = Window_Choices.new
    choices.start
    check("a window that sets its own height keeps it when the patches leave its rows as many", [choices.height, choices.instance_variable_get(:@list)[0][:name]], [120, "First of all"])
  end
end

# A mod that places the title's commands, lets the player move them and adds one that opens
# nothing and one that fails.
TITLE_CREDITS = <<-RUBY
  Mod_Framework::UI.patch "Window_TitleCommand" do |title|
    title.set at: [60, 300], movable: true
    title.after "#continue" do
      command "Credits", id: :title_credits, on_click: -> { $credits += 1 }
      command "Broken", id: :title_broken, on_click: -> { raise "broken on purpose" }
    end
  end
RUBY

# A mod loading after Title_Credits that notes where the title's command list is made then.
NOTE_AT_LOAD = "$at_load = Window_TitleCommand.instance_method(:make_command_list).source_location[0]\n"

# The title's commands with the mod's.
WITH_CREDITS = [:new_game, :continue, :title_credits, :title_broken, :auto_continue, :call_library_h, :shutdown]

# Puts the title mod and the note into the current game folder's Patch, both loading as the game
# starts running.
def put_title_mods
  put_mod("Title_Credits", TITLE_CREDITS)
  put_mod("zz_Note", NOTE_AT_LOAD)
end

# A mod loaded as the game starts places the title's commands, lets the player move them and adds
# two: the class is hooked once every mod loaded, a pick takes the keys back whether the command
# opens nothing or fails, and the next title of a later scene takes the patch and the place again.
in_game_folder do
  put_title_mods
  tree = FakeTree.new
  fake = tree_dll(tree)
  boot_tree(fake, :game => lambda { define_game_lists }) do
    $credits = 0
    title = Window_TitleCommand.new
    title.openness = 255
    title.update
    frame
    check("the patch hooks the title only once every mod loaded, which sits at the patch's place with the commands after Continue",
          [$at_load.include?("hooks.rbx"), Window_TitleCommand.instance_method(:make_command_list).source_location[0].include?("hooks.rbx"),
           title.x, title.y, *title.symbols], [false, true, 60, 300, *WITH_CREDITS])

    rule = Mod_Framework::UI::Engine::Adopt.rules.find { |each| each.target == Window_TitleCommand }
    fake.post("ui.layout", "store" => { "game_Window_TitleCommand" => "100,50,160,192" })
    tree.rects[rule.node] = [100, 50, 160, 192]
    frame
    frame
    check("a place the player arranged moves the title", [title.x, title.y], [100, 50])
    title.update
    check("the title the player moved stays at their place as it updates", [title.x, title.y], [100, 50])

    picks = [2, 3].map do |row|
      confirm_row(title, row)
      title.active
    end
    check("the title takes the keys again at once after a command that opens nothing and after one that fails, which is logged",
          [*picks, $credits, $logged.grep(/broken on purpose/).size], [true, true, 1, 1])

    old_node = rule.node
    title.dispose
    frame
    again = Window_TitleCommand.new
    again.openness = 255
    again.update
    frame
    check("a disposed title leaves the tree, and the next one takes the commands and a place the player moves anew",
          [tree.nodes.key?(old_node), tree.nodes.key?(rule.node), rule.node == old_node, *again.symbols], [false, true, false, *WITH_CREDITS])
  end
end

# Without the DLL the commands and the place still apply.
in_game_folder do
  put_title_mods
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :dll => false, :game => lambda { define_game_lists }) do
    title = Window_TitleCommand.new
    title.update
    frame
    check("without the DLL the title still takes the commands and the place, and the refused move is logged once",
          [*title.symbols, title.x, title.y, own_log.count { |line| line.include?("refused") }], [*WITH_CREDITS, 60, 300, 1])
  end
end

MAP_BANNER = <<-RUBY
  module Map_Banner
    UI = Mod_Framework::UI

    class Banner < UI::Component
      param :game_window

      def render
        hud anchor: :top_left, id: :map_banner, visible: -> { game_window.shown? } do
          text "Map name, drawn \#{game_window.refreshes} times"
        end
      end
    end

    class GearWindow < UI::Component
      param :actor

      def render
        window "Gear of \#{actor}", id: :map_banner_gear do
          text "Gear"
        end
      end
    end

    UI.replace_window Window_MapName, Banner, if: -> { $banner_on }
    UI.replace_scene Scene_Equip, GearWindow, if: -> { $gear_on }, params: ->(scene) { { actor: scene.actor } }
  end
RUBY

# A mod draws the map name's window through a component while its gate holds, and opens a
# component in place of the equip screen with the stand-in scene's character.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_windows }) do
    ui = Mod_Framework::UI
    Object.class_eval <<-RUBY
      class Scene_MenuBase < Scene_Base
        def start; @actor = "Luka"; end
        def return_scene; $returned << self; end
      end
      class Scene_Equip < Scene_MenuBase; end
    RUBY
    SceneManager.define_singleton_method(:call) { |klass| $scene_now = klass.new }
    SceneManager.define_singleton_method(:goto) { |klass| $scene_now = klass.new }
    $returned = []
    load_mod("Patch/Map_Banner.rb", MAP_BANNER)
    frame

    $banner_on = true
    name_window = Window_MapName.new
    frame
    banner = ui::Engine::Layer.tops.last
    faded = [banner.id, name_window.visible, name_window.instance_variable_get(:@visible), banner.shown?]
    name_window.contents_opacity = 255
    name_window.refresh
    3.times do
      name_window.update
      frame
    end
    check("the component draws while the game's window would show and renders anew after its refresh; the window draws nothing while the game still sees it visible",
          [faded, banner.shown?, texts_of(banner.root.engine)], [["map_banner", true, false, false], true, ["Map name, drawn 1 times"]])

    $banner_on = false
    name_window.update
    frame
    shown_again = [banner.closed, name_window.instance_variable_get(:@visible)]
    $banner_on = true
    name_window.update
    again = ui::Engine::Layer.tops.last
    name_window.dispose
    frame
    check("the game's window draws again while the gate answers false, and the component goes with the window", [*shown_again, again.closed], [true, true, true])

    $gear_on = true
    SceneManager.call(Scene_Equip)
    stand_in = $scene_now
    stand_in.start
    gear = ui::Engine::Layer.tops.last
    opened = [stand_in.is_a?(Scene_Equip), gear.id, gear.root.engine.title]
    gear.handle.close
    frame
    $gear_on = false
    SceneManager.goto(Scene_Equip)
    check("a call of the scene opens the component with the params of the menu's character, returns once it closes, and the game's scene runs while the gate answers false",
          [*opened, $returned, $scene_now.class], [false, "map_banner_gear", "Gear of Luka", [stand_in], Scene_Equip])
  end
end

# Gear Compare changes the Equipment Window by its ids and the game's menu by its
# class, and both Compare parts open the comparison; the Equipment Window's hotkey help follows
# the focus.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_windows }) do
    ui = Mod_Framework::UI
    [:Scene_Map, :Scene_Equip].each { |name| Object.const_set(name, Class.new(Scene_Base)) unless Object.const_defined?(name) }
    [:call, :goto].each { |name| SceneManager.define_singleton_method(name) { |klass| $scene_now = klass.new } }
    luka = equip_party
    load_mod("Patch/Equipment_Window.rb", equipment_window_source)
    load_mod("Patch/Gear_Compare.rb", GEAR_COMPARE)
    frame
    handle = ui.open(Equipment_Window::EquipWindow, actor: luka)
    frame
    window = ui::Engine::Layer.tops.last.root.engine
    buttons = window.find(:ew_buttons)
    sizes = window.find(:ew_stats).children.select { |part| part.is_a?(ui::Engine::Stats) }.map { |part| part.font_size }
    check("the Equipment Window shows its stats small and a Compare button after Optimize and Clear",
          [sizes, buttons.children.size, buttons.children.last.text], [[:small, :small], 3, "Compare"])

    buttons.children.last.emit(:click)
    frame
    dialog = ui::Engine::Layer.tops.last
    check("Compare opens the comparison for the character the window shows, the gear of each party member added up",
          [dialog.id, texts_of(dialog.root.engine)], ["gear_compare_dialog", ["Luka: 300", "Alice: 0", "Close"]])
    dialog.handle.close
    handle.close
    frame

    $game_party.menu_actor = $game_party.members[1]
    menu = Window_MenuCommand.new
    names = menu.names
    confirm_row(menu, 2)
    compared = ui::Engine::Layer.tops.last
    check("the menu holds Compare after Equip and Party Order, and Compare opens the comparison for the menu's character, the gold window dimmer",
          [names, texts_of(compared.root.engine).first, Window_Gold.new.opacity],
          [["Items", "Equip", "Compare", "Skills", "Abilities", "Status", "Party Order", "Library", "Config", "Save", "Game End"], "Alice: 0", 160])

    # The Equipment Window's key help names the keys of the part in focus: the slot list, Optimize,
    # and the details of an item with gems and of an empty slot.
    ui.open(Equipment_Window::EquipWindow, actor: luka)
    frame
    window = ui::Engine::Layer.tops.last.root.engine
    gear = ui::Engine::Layer.tops.last.mount.component
    slots = window.find(:ew_slots)
    optimize = window.find(:ew_buttons).children[0]
    focus = lambda do |from, to|
      tree.post("states", to ? { to.node => ui::Engine::Tree::FOCUSED } : { from.node => 0 })
      tell(tree, [[from.node, "blur"]] + (to ? [[to.node, "focus"]] : []))
      frame
      window.find(:ew_keys).line
    end
    on_slots = focus.call(optimize, slots)
    on_optimize = focus.call(slots, optimize)
    on_gems = focus.call(optimize, nil)
    gear.slot = 1
    frame
    check("the key help names the keys of the slot list, of Optimize, and of the details with and without tabs",
          [on_slots, on_optimize, on_gems, window.find(:ew_keys).line],
          ["Z: Change  Q or W: Character  Ctrl+arrows: Leave the list  X or Numpad 0: Close", "Z: optimize  Q or W: Character  X or Numpad 0: Back",
           "Tab: Next tab  Q or W: Character  X or Numpad 0: Back", "Q or W: Character  X or Numpad 0: Back"])

    # With a gamepad used last and the details in view, the shoulders step the tabs of an item with
    # gems from the slot list and the details, and switch the character on an empty slot.
    $pad = true
    gear.page = 1
    gear.slot = 0
    frame
    frame
    pad_details = window.find(:ew_keys).line
    pad_slots = focus.call(optimize, slots)
    gear.slot = 1
    frame
    pad_empty = window.find(:ew_keys).line
    $pad = false
    check("with a gamepad the key help names the shoulders as the tab step while the details show two tabs, else as the character",
          [pad_details, pad_slots, pad_empty],
          ["Q or W: Tabs  X or Numpad 0: Back", "Z: Change  Q or W: Tabs  Hold A + D-pad: Leave the list  X or Numpad 0: Close",
           "Z: Change  Q or W: Character  Hold A + D-pad: Leave the list  X or Numpad 0: Close"])
  end
end

# Makes a party member who shows in the game's list windows with a face of their own.
#
# @param id [Integer] The member's id.
# @param name [String] The member's name.
# @return [FakeHero] The member.
def row_member(id, name)
  member = FakeHero.new(id, name, [nil, nil, nil])
  member.define_singleton_method(:face_name) { "Actor#{id}" }
  member
end

# Defines the text colors of the game's window skin that the row windows below draw in.
ROW_SKIN = "def text_color(n); { 0 => Color.new(255, 255, 255), 16 => Color.new(132, 170, 255) }[n]; end\n" \
           "def normal_color; text_color(0); end\ndef system_color; text_color(16); end\n"

# Defines the battle's status window as Paradox draws it: each name through draw_actor_name_ex,
# then the HP label.
def define_battle_status
  Object.send(:remove_const, :Window_BattleStatus) if Object.const_defined?(:Window_BattleStatus)
  Object.class_eval <<-RUBY
    class Window_BattleStatus < Window_Selectable
      #{ROW_SKIN}
      def initialize; super(0, 0, 416, 120); refresh; end
      def item_max; $game_party.battle_members.size; end
      def draw_item(index)
        actor = $game_party.battle_members[index]
        rect = item_rect_for_text(index)
        draw_actor_name_ex(actor, rect.x, rect.y, true)
        change_color(system_color)
        draw_text(rect.x + 120, rect.y, 30, line_height, "HP")
      end
      def draw_actor_name_ex(actor, x, y, enabled)
        change_color(normal_color, enabled)
        draw_text(x, y, 100, line_height, actor.name)
      end
    end
  RUBY
end

# Defines the menu's status window, the formation list, as the game draws it: a face, the name and
# a state icon per character.
def define_menu_status
  Object.send(:remove_const, :Window_MenuStatus) if Object.const_defined?(:Window_MenuStatus)
  $faces_drawn = []
  def Cache.face(name); ($face_sheets ||= {})[name] ||= Bitmap.new(384, 384); end
  Object.class_eval <<-RUBY
    class Window_MenuStatus < Window_Selectable
      #{ROW_SKIN}
      def initialize; super(0, 0, 400, 140); refresh; end
      def refresh; $faces_drawn = []; @icons = []; super; end
      def item_max; $game_party.members.size; end
      def draw_item(index)
        actor = $game_party.members[index]
        rect = item_rect(index)
        draw_actor_face(actor, rect.x + 1, rect.y)
        draw_actor_name(actor, rect.x + 108, rect.y)
        draw_icon(17, rect.x + 220, rect.y)
      end
      def draw_actor_face(actor, x, y, enabled = true); draw_face(actor.face_name, actor.face_index, x, y, enabled); end
      def draw_face(name, index, x, y, _enabled = true)
        $faces_drawn << name
        contents.blt(x, y, Cache.face(name), Rect.new(index % 4 * 96, index / 4 * 96, 96, 96))
      end
      def draw_actor_name(actor, x, y, width = 112)
        change_color(normal_color)
        draw_text(x, y, width, line_height, actor.name)
      end
    end
  RUBY
end

# Lists the color each text of a window was drawn in by its last drawing of its rows, by the text.
#
# @param window [Window_Base] The window.
# @param texts [Integer] How many texts its rows draw.
# @return [Hash{String => Array}] The color's values by the text.
def colors_drawn(window, texts)
  Hash[window.drawn.last(texts)]
end

# Tells whether a color is an opaque grey, darker than white.
#
# @param color [Array] The color's values.
# @return [Boolean] Whether it is.
def opaque_grey?(color)
  color[0, 3].uniq.size == 1 && color[0] < 255 && color[3] == 255
end

# A mod like MGQ Online: the names of the battle's status window in each player's color, an ally's
# without its player's name after it, and a character in crisis left in the game's color.
PLAYER_COLORS = <<-'RUBY'
  Mod_Framework::UI.patch "Window_BattleStatus" do |status|
    status.rows do |rows|
      rows.map do |row|
        actor = $game_party.battle_members[row[:index]]
        next row if $crisis.include?(actor.name)

        ally = actor.name.include?("(")
        row.merge(name_color: ally ? :success : :own, name: ally ? actor.name.sub(/ \(.*\)/, "") : nil)
      end
    end
  end
RUBY

# The battle's status window draws each name in its player's color and an ally's without its
# player, leaves a character in crisis and the other texts in the game's colors, and takes the looks
# anew as it refreshes.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_battle_status }) do
    equip_party
    $game_party = FakeMenuParty.new([row_member(1, "Luka"), row_member(2, "Alice (Mia)"), row_member(3, "Sylph")])
    $crisis = ["Sylph"]
    load_mod("Patch/Player_Colors.rb", PLAYER_COLORS)
    frame
    status = Window_BattleStatus.new
    palette = Mod_Framework::UI::Engine::Theme.palette_for(status)
    own = palette.now(:own).to_a
    ally = palette.now(:success).to_a
    white = [255.0, 255.0, 255.0, 255.0]
    blue = [132.0, 170.0, 255.0, 255.0]
    first = colors_drawn(status, 6)
    check("each name draws in its player's color, an ally's without its player, a character in crisis and the labels in the game's colors",
          [first["Luka"], first["Alice"], first.key?("Alice (Mia)"), first["Sylph"], first["HP"]], [own, ally, false, white, blue])

    $crisis = []
    status.refresh
    check("the looks are taken anew as the window refreshes", colors_drawn(status, 6)["Sylph"], own)
  end
end

# A mod like MGQ Online's squad: the characters past the player's share greyed in the formation
# list, with a line above the first of them.
SQUAD_MARKS = <<-'RUBY'
  Mod_Framework::UI.patch "Window_MenuStatus" do |formation|
    formation.rows do |rows|
      rows.map { |row| row[:index] < $share ? row : row.merge(grey: true, line_above: row[:index] == $share ? :error : nil) }
    end
  end
RUBY

# The formation list greys the texts, faces and icons of the characters past the share, draws a line
# above the first of them, and follows a share that grows as it refreshes.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_status }) do
    equip_party
    $game_party = FakeMenuParty.new([row_member(1, "Luka"), row_member(2, "Alice"), row_member(3, "Tamamo"), row_member(4, "Erubetie")])
    $share = 2
    load_mod("Patch/Squad_Marks.rb", SQUAD_MARKS)
    frame
    formation = Window_MenuStatus.new
    error = Mod_Framework::UI::Engine::Theme.palette_for(formation).now(:error).to_a
    colors = colors_drawn(formation, 4)
    icons_at = lambda { formation.icons.map { |_icon, _x, y| y } }
    lines = lambda { formation.contents.fills.select { |_x, _y, _width, height, _color| height == 2 } }
    check("the names past the share draw in an opaque grey, the others in the game's white",
          [colors["Luka"], colors["Alice"], opaque_grey?(colors["Tamamo"]), colors["Erubetie"] == colors["Tamamo"]],
          [[255.0, 255.0, 255.0, 255.0], [255.0, 255.0, 255.0, 255.0], true, true])
    check("the faces and icons past the share draw from greyed copies at their places, not through the game's drawing",
          [$faces_drawn, icons_at.call, formation.contents.copies.count { |x, y, _picture| x == 220 && [48, 72].include?(y) }],
          [["Actor1", "Actor2"], [0, 24], 2])
    check("a line in the error color runs along the top of the first row past the share", lines.call, [[0, 48, formation.item_width, 2, error]])

    $share = 3
    formation.refresh
    check("a share that grows moves the line and the grey as the list refreshes",
          [$faces_drawn, lines.call.map { |_x, y| y }, opaque_grey?(colors_drawn(formation, 4)["Tamamo"])], [["Actor1", "Actor2", "Actor3"], [72], false])
  end
end

# A mod that draws one character's name in the system color in the formation list, by who it is.
HERO_MARK = <<-'RUBY'
  Mod_Framework::UI.patch "Window_MenuStatus" do |formation|
    formation.rows { |rows| rows.map { |row| $game_party.members[row[:index]].name == "Alice" ? row.merge(name_color: 16) : row } }
  end
RUBY

# The formation swaps two characters and draws only their two rows anew, as Paradox does: each
# character keeps its own color at its new place.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists; define_menu_status }) do
    equip_party
    $game_party = FakeMenuParty.new([row_member(1, "Luka"), row_member(2, "Alice"), row_member(3, "Tamamo")])
    load_mod("Patch/Hero_Mark.rb", HERO_MARK)
    frame
    formation = Window_MenuStatus.new
    members = $game_party.members
    members[0], members[1] = members[1], members[0]
    formation.redraw_item(0)
    formation.redraw_item(1)
    colors = colors_drawn(formation, 2)
    check("the swapped characters draw in their own colors at their new places",
          [colors["Alice"], colors["Luka"]], [[132.0, 170.0, 255.0, 255.0], [255.0, 255.0, 255.0, 255.0]])
  end
end

# A mod like MGQ Online's squad on the game's party edit, a nested window class: by the characters
# the edit holds now, the squad's Frontline in the plain color, its Backline in the system color and
# the rest greyed under a line.
PARTY_EDIT_MARKS = <<-'RUBY'
  Mod_Framework::UI.patch "Foo::PTEdit::Window_PartyMember" do |members|
    members.rows do |rows|
      actors = members.read(:actors)
      places = rows.each_index.map { |index| $places[actors[index]] || :cut }
      rows.each_with_index.map do |row, index|
        next row.merge(name_color: places[index] == :front ? 0 : 16) unless places[index] == :cut

        row.merge(name_color: 16, grey: true, line_above: index > 0 && places[index - 1] != :cut ? :error : nil)
      end
    end
  end
RUBY

# A patch names the party edit's nested window class, defined only after it once the game runs:
# the class is hooked as its first window is made, which takes the rows' looks at its update and
# follows the characters the edit holds as it refreshes.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    equip_party
    $game_party = FakeMenuParty.new([row_member(1, "Luka"), row_member(2, "Alice"), row_member(3, "Tamamo"), row_member(4, "Erubetie"), row_member(5, "Granberia")])
    $places = { 1 => :front, 2 => :front, 3 => :bench }
    load_mod("Patch/Party_Edit_Marks.rb", PARTY_EDIT_MARKS)
    frame
    Object.class_eval <<-RUBY
      module Foo; module PTEdit; end; end
      class Foo::PTEdit::Window_PartyMember < Window_Command
        #{ROW_SKIN}
        attr_reader :actors
        def initialize; @actors = $game_party.members.map { |member| member.id }; super(0, 0); end
        def make_command_list; @actors.each { |id| add_command($game_party.members[id - 1].name, :ok) }; end
        def draw_item(index)
          change_color(index < 4 ? normal_color : system_color, command_enabled?(index))
          draw_text(item_rect_for_text(index), @list[index][:name], alignment)
        end
      end
    RUBY
    members = Foo::PTEdit::Window_PartyMember.new
    members.update
    error = Mod_Framework::UI::Engine::Theme.palette_for(members).now(:error).to_a
    white = [255.0, 255.0, 255.0, 255.0]
    blue = [132.0, 170.0, 255.0, 255.0]
    lines = lambda { members.contents.fills.select { |fill| fill[3] == 2 } }
    colors = colors_drawn(members, 5)
    check("the party edit draws the Frontline plain, the Backline in the system color and the rest greyed, with a line above the first of the rest",
          [colors["Luka"], colors["Alice"], colors["Tamamo"], opaque_grey?(colors["Erubetie"]), opaque_grey?(colors["Granberia"]), lines.call],
          [white, white, blue, true, true, [[0, 72, members.item_width, 2, error]]])

    members.actors.delete_at(0)
    members.refresh
    colors = colors_drawn(members, 4)
    check("the looks follow the characters the edit holds as it refreshes, read from the window",
          [colors["Alice"], colors["Tamamo"], opaque_grey?(colors["Erubetie"]), lines.call], [white, blue, true, [[0, 48, members.item_width, 2, error]]])
  end
end
