#----------------------------------------------------------------
#  layer_options_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Covered a mod's hotkey rows after its options under the Hotkeys caption
#                            - Dropped cancel_to:, which the cancel rule replaces
#      Paulinchen  2026-11-06: Covered the rows of the mod picked beside the list of the mods, a button row pressed and the
#                              focus coming onto the rows
#                            - Covered a help whose own lines take more lines than the game window has
#                            - Covered a window that renders again around a mod's rows
#      Paulinchen  2026-11-05: Covered a Hotkeys tab of the hotkeys of every mod that is on, its help in a game window
#                            - Created
#
#----------------------------------------------------------------

# Covers options_list of the UI layer (design v2 section 5.10) in a booted game against FakeTree,
# through a mod's own options window: only its rows show under its heading, Right steps a value
# into the save, on_change hears the row's key and value, and the help line tells the row picked; and
# the remembered hotkeys of the mods that are on, which ask for the new key in a game window and
# name the hotkey that has a refused key there; and the rows of the mod picked beside the list of
# the mods, without their heading, its hotkey rows last under the Hotkeys caption, whose button row
# on_press presses and whose rows tell when the focus comes onto them.

require_relative "layer_support"

# The game's options with Options > Mods holding no rows.
OPTIONS_GAME = lambda do
  Object.send(:remove_const, :NWConst) if Object.const_defined?(:NWConst)
  Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; MOD_CONTENTS = [{ :key => :return }]; end; end")
end

TRAP_OPTIONS = <<-RUBY
  module Trap_Templates
    UI = Mod_Framework::UI

    Mod_Framework::Options.add(:trap_message_time, "[Trap Templates] Message Time", "How long trap messages show.",
                               { 2 => "2 s", 3 => "3 s", 5 => "5 s" }, 3)
    Mod_Framework::Options.add(:trap_sound, "[Trap Templates] Sound", "Whether a trap plays a sound.", { 1 => "On", 0 => "Off" }, 1)
    Mod_Framework::Options.add(:other_speed, "[Other Mod] Speed", "How fast.", { 1 => "1", 2 => "2" }, 1)

    class TrapOptions < UI::Component
      state(:changes) { [] }

      def render
        window "Trap options" do
          options_list mod: "Trap Templates", on_change: ->(key, value) { self.changes = changes + [[key, value]] }
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  dll.answer("options.groups") do |names|
    names.each_with_index.map { |name, place| [name[/\A\[([^\]]+)\]/, 1], [[place, name.sub(/\A\[[^\]]+\]\s*/, "")]]] }
         .group_by { |group, _rows| group }.map { |group, entries| [group, entries.map { |_group, rows| rows }.flatten(1)] }
  end
  boot_tree(dll, :game => OPTIONS_GAME) do
    ui = Mod_Framework::UI
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    load_mod("Patch/Trap_Templates.rb", TRAP_OPTIONS)
    frame

    ui.open(Trap_Templates::TrapOptions)
    frame
    Graphics.update
    node = nodes_of(tree, "list").last
    list = ui::Engine::Tree.component(node)
    options = list.parent
    check("only the mod's rows show, under its heading, with their values", list.rows.map { |row| row[:heading] || [row[:text], row[:value]] },
          ["Trap Templates", ["Message Time", "3 s"], ["Sound", "On"]])

    # Right steps the message time into the save, which on_change hears.
    tell(tree, [[node, "change", 1], [node, "side", 1, 1]])
    window = ui::Engine::Layer.tops.last.mount.component
    check("Right stepped the message time, kept as the option's value", [Mod_Framework::Options.value(:trap_message_time), list.rows[1][:value]], [5, "5 s"])
    check("on_change hears the row's key and its value", window.changes, [[:trap_message_time, 5]])
    check("the window rendered again keeps its rows and nothing failed", [list.rows.map { |row| row[:heading] || row[:text] }, layer_lines.grep(/FAILED/)],
          [["Trap Templates", "Message Time", "Sound"], []])
    check("the help line tells the row picked", options.help.text, "How long trap messages show.")
  end
end

# The remembered hotkeys of the mods that are on, as the title's Mod Configuration adds them, the
# help in a game window of the scene.
HOTKEYS_PAGE = <<-RUBY
  module Camp_Keys
    UI = Mod_Framework::UI

    Mod_Framework::Hotkeys.define(:camp_keys_map, :key => "M", :name => "[Camp Keys] Map", :help => "Shows the map.")

    class HotkeysPage < UI::Component
      def render
        window "Hotkeys" do
          options_list hotkeys: :remembered, help_window: $help_window, empty: "A mod's hotkeys show here once it has run once."
        end
      end
    end
  end
RUBY

# The game's help window of the Options screen: two lines, its text kept.
HelpWindow = Struct.new(:text) do

  # Keeps the text it shows.
  #
  # @param text [String] The text.
  def set_text(text)
    self.text = text
  end

  # @return [Integer] Its height, two lines.
  def height
    72
  end

  # @return [Integer] The room around its text.
  def standard_padding
    12
  end

  # @return [Integer] The height of a line.
  def line_height
    24
  end
end

# The game's help window with its picture, which measures the help's words: 20 characters wide.
class MeasuredHelpWindow < HelpWindow
  # @return [Bitmap] Its picture.
  def contents
    @contents ||= Bitmap.new(244, 48)
  end

  # @return [Integer] The width of its picture, 20 characters and the room at the left.
  def contents_width
    244
  end
end

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  dll.answer("keys.names") { |codes| codes.map { |code| code.chr } }
  dll.answer("mods.state") { |_request| { "mods" => [{ "name" => "Level_Cap", "on" => true }, { "name" => "Map_Display", "on" => false }] } }
  dll.answer("options.groups") do |names|
    names.each_with_index.map { |name, place| [name[/\A\[([^\]]+)\]/, 1], [[place, name.sub(/\A\[[^\]]+\]\s*/, "")]]] }
         .group_by { |group, _rows| group }.map { |group, entries| [group, entries.map { |_group, rows| rows }.flatten(1)] }
  end
  boot_tree(dll, :game => OPTIONS_GAME) do
    ui = Mod_Framework::UI
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    $help_window = HelpWindow.new("")
    Mod_Framework::Settings.store("hotkey.level_cap_open", "Level_Cap\t75\t75\t[Level Cap] Open\tOpens the cap.")
    Mod_Framework::Settings.store("hotkey.map_display_open", "Map_Display\t78\t78\t[Map Display] Open\tShows the map.")
    load_mod("Patch/Camp_Keys.rb", HOTKEYS_PAGE)
    frame

    ui.open(Camp_Keys::HotkeysPage)
    frame
    Graphics.update
    list = ui::Engine::Tree.component(nodes_of(tree, "list").last)
    headings = list.rows.map { |row| row[:heading] }.compact
    check("the hotkeys of the mods that are on show under their mods, those of a mod that is off do not",
          [headings.include?("Camp Keys"), headings.include?("Level Cap"), headings.include?("Map Display")], [true, true, false])
    check("no help line: the help of the row picked shows in the game window", [list.parent.help, $help_window.text],
          [nil, Mod_Framework::Options.help_text(list.row_at(list.index)[:data]).gsub("\r\n", "\n")])

    place = list.rows.index { |row| row[:text] == "Open" }
    list.index = place
    tell(tree, [[list.node, "submit", place]])
    check("a row waits for its key and the game window asks for it", [list.row_at(place)[:value], $help_window.text],
          ["Press a key . . .", "Press the new key for Open.\nEsc keeps K."])
    tell(tree, [[list.node, "refused", 0x4D, "hotkey", "[Camp Keys] Map"]])
    check("a taken key is refused with the hotkey that has it", $help_window.text, "M is already the key of [Camp Keys] Map.\nPress another key, or Esc to keep K.")
    tell(tree, [[list.node, "captured", 0x50], [list.node, "released"]])
    check("a free key binds the remembered hotkey for when its mod loads", Mod_Framework::Hotkeys.remembered_entry(:level_cap_open)[:code], 0x50)

    # A help whose own lines take more lines than the window has shows as one text broken to its width.
    narrow = MeasuredHelpWindow.new("")
    ui::Engine::OptionsList.show_in(narrow, "Turns it on.\r\nThe cap rises in story.")
    check("a help whose lines take more lines than the game window has is broken as one text", narrow.text, "Turns it on. The cap\nrises in story.")
  end
end

# The rows of the mod picked beside the list of the mods, as Options > Mods shows them.
MODS_BESIDE = <<-RUBY
  module Camp_Notes
    UI = Mod_Framework::UI

    Mod_Framework::Hotkeys.define(:camp_notes_open, :key => "B", :name => "[Camp Notes] Open Notes", :help => "Opens the notes.")
    Mod_Framework::Options.add(:camp_size, "[Camp Notes] Size", "How many notes.", { 5 => "5", 9 => "9" }, 5)
    NWConst::Config::MOD_CONTENTS.insert(-2, { :key => :camp_clear, :name => "[Camp Notes] Clear Notes", :sub => false, :help => "Clears every note." })
    Mod_Framework::Options.add(:trap_sound, "[Trap Templates] Sound", "Whether a trap plays a sound.", { 1 => "On", 0 => "Off" }, 1)

    class ModOptions < UI::Component
      state(:picked) { "Camp Notes" }
      state(:heard) { [] }

      def render
        window "Options" do
          stack row: true do
            list Mod_Framework::Options.mods, bind: :picked, submit_to: :mod_rows, id: :mods, width: 200
            options_list mod: picked, headings: false, id: :mod_rows, width: :fill,
                         on_press: ->(key) { self.heard = heard + [key] }, on_enter: -> { self.heard = heard + [:enter] }
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  dll.answer("options.groups") do |names|
    names.each_with_index.map { |name, place| [name[/\A\[([^\]]+)\]/, 1], [[place, name.sub(/\A\[[^\]]+\]\s*/, "")]]] }
         .group_by { |group, _rows| group }.map { |group, entries| [group, entries.map { |_group, rows| rows }.flatten(1)] }
  end
  boot_tree(dll, :game => OPTIONS_GAME) do
    ui = Mod_Framework::UI
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    load_mod("Patch/Camp_Notes.rb", MODS_BESIDE)
    frame

    ui.open(Camp_Notes::ModOptions)
    frame
    Graphics.update
    mods, rows = nodes_of(tree, "list").map { |node| ui::Engine::Tree.component(node) }
    window = ui::Engine::Layer.tops.last.mount.component
    check("the mods list beside the rows of the mod picked, which show without their heading, its hotkey last under the Hotkeys caption",
          [mods.rows.map { |row| row.is_a?(Hash) ? row[:text] : row }.grep(/Camp|Trap/), rows.rows.map { |row| row[:heading] || row[:text] }],
          [["Camp Notes", "Trap Templates"], ["Size", "Clear Notes", "Hotkeys", "Open Notes"]])

    # The cursor on another mod shows its rows at once.
    tell(tree, [[mods.node, "change", mods.rows.index { |row| (row.is_a?(Hash) ? row[:text] : row) == "Trap Templates" }]])
    check("the cursor on another mod shows that mod's rows", rows.rows.map { |row| row[:text] }, ["Sound"])

    # Back on Camp Notes, the focus on the rows and confirm on the button row presses it.
    tell(tree, [[mods.node, "change", mods.rows.index { |row| (row.is_a?(Hash) ? row[:text] : row) == "Camp Notes" }]])
    $sounds = []
    tell(tree, [[rows.node, "focus"], [rows.node, "submit", 1]])
    check("the focus on the rows tells on_enter, and confirm on the button row tells on_press its key with the confirm sound",
          [window.heard, $sounds], [[:enter, :camp_clear], [:ok]])
  end
end
