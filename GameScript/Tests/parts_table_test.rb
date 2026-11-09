#----------------------------------------------------------------
#  parts_table_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Named the looks the rows of a game list window take
#      Paulinchen  2026-11-07: Pointed PARTS.md at the patch page of docs/ui in place of MODDER.md
#                            - Listed the parts of the Mod List under its new name, and of the Mod Configuration
#      Paulinchen  2026-11-06: Listed the parts of the mod browser on the UI layer
#                            - Listed the parts of the save's mods dialog on the UI layer
#                            - Listed the parts of Options > Mods on the UI layer
#                            - Listed the parts of the Mods screen on the UI layer
#                            - Listed the parts of the title's Mods box on the UI layer
#      Paulinchen  2026-11-04: Listed the commands of the game's title and menu and of the title's Mods box
#                            - Created
#
#----------------------------------------------------------------

# Writes the table of the parts you can patch (design v2 section 7.9) by opening each of the
# framework's screens and its title's Mods box in a booted game against FakeTree, with the commands
# of the game's title and menu as the stand-ins of the game make them, and fails while the PARTS.md
# the framework ships differs, so the table never drifts from the screens. After a screen changed,
# write it anew:
#
#   ruby GameScript/Tests/parts_table_test.rb --write

require_relative "mods_support"

# The table the framework ships.
PARTS = File.join(FRAMEWORK_DIR, "PARTS.md")

# Each screen's name, the selector that names it and what other mods may name of it, in the order
# they were opened.
$screens = []

# The game's command windows: each one's name, selector and commands.
$game_windows = []

# The commands of the game's menu, as Paradox makes them.
MENU_COMMANDS = [:item, :equip, :stone, :skill, :ability, :status, :formation, :library, :config, :save, :game_end]

# Notes what other mods may name of an open screen.
#
# @param name [String] The screen's name for the table.
# @param root [Mod_Framework::UI::Engine::Component] Its root.
def note_screen(name, root)
  $screens << [name, "##{root.id}", Mod_Framework::UI::Engine::Patches.parts_of(root)]
end

# Notes the commands of a game command window as the game makes them, before any mod adds to them.
#
# @param name [String] The window's name for the table.
# @param klass [Class] Its class.
def note_game_window(name, klass)
  window = klass.allocate
  window.instance_variable_set(:@list, [])
  window.make_command_list
  symbols = window.instance_variable_get(:@list).map { |entry| [entry[:symbol].to_s, "command"] }
  $game_windows << [name, klass.name, { :ids => symbols, :types => ["command"], :exposes => [] }]
end

# Writes one screen's section of the table.
#
# @param name [String] The screen's name.
# @param selector [String] The selector that names it.
# @param parts [Hash] What other mods may name of it.
# @param heading [String] The heading's marks.
# @return [Array<String>] The section's lines.
def section(name, selector, parts, heading)
  lines = ["", "#{heading} #{name}", "", "`UI.patch \"#{selector}\"`", "", "| Id | Type |", "|---|---|"]
  parts[:ids].each { |part_id, type| lines << "| `##{part_id}` | #{type} |" }
  lines.concat(["", "Types: #{parts[:types].map { |type| "`#{type}`" }.join(', ')}.", "",
                "Exposed values: #{parts[:exposes].empty? ? 'none' : parts[:exposes].map { |value| "`#{value}`" }.join(', ')}."])
end

# Writes the table of every screen noted.
#
# @return [String] The table in Markdown.
def parts_text
  lines = ["# MGQ Paradox Mod Framework: the parts you can patch", "",
           "Written by `GameScript/Tests/parts_table_test.rb`, which opens each of the framework's screens in the test driver; do not edit it by hand.",
           "`docs/ui/patch.md` in the framework's repository tells how `UI.patch` names these parts: by an id, by a type inside an id, or both, such as `\"#mf_mods_side text\"`."]
  $screens.each { |name, selector, parts| lines.concat(section(name, selector, parts, "##")) }
  lines.concat(["", "## The game's windows", "",
                "A game window is named by its class, and a command of a command window by its symbol inside it, such as `\"Window_MenuCommand #equip\"`. " \
                "Any game window takes `set` with `opacity:`, `anchor:`, `at:`, `width:`, `height:`, `theme:` and `movable:`; " \
                "the rows of a list window take `name_color:`, `name:`, `grey:` and `line_above:` through `rows`."])
  $game_windows.each { |name, selector, parts| lines.concat(section(name, selector, parts, "###")) }
  lines.join("\n") + "\n"
end

in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $browsed = fresh_browsed
  $asked = 0
  game = lambda do
    define_mods_game
    Object.send(:remove_const, :Window_MenuCommand) if Object.const_defined?(:Window_MenuCommand)
    Object.const_set(:Window_MenuCommand, Class.new(Window_Command) { define_method(:make_command_list) { MENU_COMMANDS.each { |symbol| add_command(symbol.to_s, symbol) } } })
    note_game_window("The title's commands", Window_TitleCommand)
    note_game_window("The menu's commands", Window_MenuCommand)
  end
  boot_tree(with_mods_topics(tree_dll(tree)), :game => game) do
    frame
    screen = Mod_Framework::Mods::Screen.open
    frame
    note_screen("Mod List", Mod_Framework::UI::Engine::Layer.tops.last)
    screen.close
    frame
    config = Mod_Framework::Mods::Screen.open_config
    frame
    note_screen("Mod Configuration", Mod_Framework::UI::Engine::Layer.tops.last)
    config.close
    frame
    browser = Mod_Framework::Mods.open_browser
    frame
    note_screen("Mod browser", Mod_Framework::UI::Engine::Layer.tops.last)
    browser.close
    frame
    scene = Object.new
    def scene.end_mod_config; end
    options = Mod_Framework::ModConfig.open(scene, Window_Base.new(0, 120, 640, 360))
    frame
    note_screen("Options > Mods", Mod_Framework::UI::Engine::Layer.tops.last)
    options.close
    frame
    title = Window_TitleCommand.new
    title.openness = 255
    frame
    title.update
    box = Mod_Framework::Mods::Title.open_box
    frame
    note_screen("The title's Mods box", Mod_Framework::UI::Engine::Layer.tops.last)
    box.close
    frame
    rows = [{ "kind" => "off", "name" => "Level_Cap", "title" => "Level Cap", "saved" => "1.5.2", "installed" => "1.5.2", "target" => "Level_Cap" }]
    dialog = Mod_Framework::UI.open(Mod_Framework::Mods::SaveModsDialog, :save => 2, :rows => rows)
    frame
    note_screen("The save's mods dialog", Mod_Framework::UI::Engine::Layer.tops.last)
    dialog.close
  end
end

if ARGV.include?("--write")
  File.binwrite(PARTS, parts_text)
  puts "wrote #{PARTS}"
end
check("PARTS.md is the table the framework's screens give (run GameScript/Tests/parts_table_test.rb --write after a change)",
      File.exist?(PARTS) && File.binread(PARTS).gsub("\r\n", "\n") == parts_text, true)
