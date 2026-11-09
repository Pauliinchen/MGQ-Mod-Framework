#----------------------------------------------------------------
#  mods_screen_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Expected the keys of the list in the key help while it holds the focus
#      Paulinchen  2026-11-07: Expected the Hotkeys caption only under the options of a mod
#                            - Covered the Mod List as a menu of its own without tabs
#                            - Covered the Mod Configuration with the options and hotkeys of the mods at the title
#                            - Closed the game before checking that Restart now starts it again
#                            - Took a Title mod of no name as the example
#      Paulinchen  2026-11-06: Checked that the key help takes a second line for the entries the window has no room for
#                            - Took the signature of a mod's scripts from the loader
#                            - Covered the Mods screen as a component of the UI layer: its side, the questions with the answer
#                              that keeps a mod as it was, the notice line and the restart bar as alerts, and the rows
#                              moved by the move hotkeys
#                            - Opened the screen on a tab without a title window
#      Paulinchen  2026-11-04: Kept a few flows of the Mods screen and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the Mods screen
#                            - Expected the framework's jump hotkey on the Hotkeys tab
#      Paulinchen  2026-11-03: Covered a failure of an earlier game session said as last time and forgotten once the mod's
#                              scripts change
#      Paulinchen  2026-11-01: Covered a mod moved within its tag by the framework's move hotkeys only in the list and the
#                              key help naming their keys
#                            - Covered the row of tabs as one key stop: opening on a tab, a step from it and from a page,
#                              a click on a tab and an Options tab with nothing to pick
#                            - Covered the mod's side with only its name, description and needs, no tag to set, the
#                              screen opening on the first mod, the framework's row without a box, a description that
#                              arrives later and a refused change on the notice line
#                            - Covered an order refused in an answer that wrote Mods.ini and the key help of the list and
#                              the mod's side
#      Paulinchen  2026-10-31: Covered the status line kept to its mod and a split script turned off and on again
#                            - Covered the framework's row naming the folder of its copy
#      Paulinchen  2026-10-30: Covered the scripts loaded whole moving among themselves, a plain Title script turned on at
#                              the title and a title that counts as entered
#                            - Had the broken Title mod name the title calls and read the whole state to its end
#                            - Covered a Title mod that loads whole and a used one turned off without a restart
#                            - Covered two mods on that do not work together, an order against a load order hint and a
#                              mod turned off that saves may need
#                            - Took its helpers from mods_support.rb
#                            - Covered the Options and the Hotkeys tab
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_screen.rbx, the Mod List on the UI layer, in a booted game against FakeTree, the
# DLL's mod management played by a state the test changes as C# would: a session that turns mods
# on and off and orders them; why a mod failed to load; and the move hotkeys; and
# mods_configuration.rbx, the Mod Configuration with the options and hotkeys of the mods at the title.

require_relative "mods_support"
require_relative "layer_support"

$sounds = []

# Finds the open Mod List: its component and its window's engine part.
#
# @return [Array] The component and the window.
def mods_screen
  top = Mod_Framework::UI::Engine::Layer.tops.reverse.find { |each| !each.closed && each.mount.component.is_a?(Mod_Framework::Mods::ModsScreen) }
  top ? [top.mount.component, top.root.engine] : [nil, nil]
end

# Tells the texts of an engine part and the parts inside it that show, a box of lines as its
# lines, or the dim text it shows without any.
#
# @param part [Mod_Framework::UI::Engine::Component] The part.
# @return [Array<String>] The texts.
def texts_of(part)
  return [] unless part.visible
  if part.is_a?(Mod_Framework::UI::Engine::Lines)
    return part.lines.empty? ? [part.empty_text] : part.lines.map { |line| line.is_a?(Hash) ? line[:text] : line }
  end
  return [part.text.to_s] if part.is_a?(Mod_Framework::UI::Engine::Label)

  part.children.map { |child| texts_of(child) }.flatten
end

# Tells a mod's row as the list shows it: its name, box and note.
#
# @param list [Mod_Framework::UI::Engine::List] The list.
# @param text [String] The row's name.
# @return [Array, nil] The row.
def row_of(list, text)
  shown(list).find { |row| row.is_a?(Array) && row[0] == text }
end

# Puts the list's cursor on a mod's row and picks it, as confirm on it does.
#
# @param tree [FakeTree] The tree.
# @param list [Mod_Framework::UI::Engine::List] The list.
# @param text [String] The row's name.
def choose(tree, list, text)
  place = list.rows.index { |row| row[:text] == text }
  tell(tree, [[list.node, "change", place], [list.node, "submit", place]])
end

# Puts the list's cursor on a mod's row, as the keys or a click do.
#
# @param tree [FakeTree] The tree.
# @param list [Mod_Framework::UI::Engine::List] The list.
# @param text [String] The row's name.
def point_at(tree, list, text)
  tell(tree, [[list.node, "change", list.rows.index { |row| row[:text] == text }]])
end

# A session: a mod's side, turning mods on and off with the questions of requirements and the
# answer that keeps a mod as it was, what waits for the restart, a drag, a refused change on the
# notice line and Restart now.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    frame
    mods::Screen.open
    frame
    Graphics.update
    screen, window = mods_screen
    list = window.find(:mf_mods_list)
    check("the Mod List opens without tabs, the focus on the list and its cursor on the first mod under the framework's row",
          [window.title, nodes_of(tree, "tabs"), tree.nodes[list.node][:props]["autofocus"], shown(list).first(3), list.row_at(list.index)[:text]],
          ["Mod List", [], true, ["Framework · 3", ["Mod Framework", nil, "Always on"], ["Core Lib", true, nil]], "Core Lib"])
    point_at(tree, list, "Map Display")
    check("a mod's side shows its name, version, About and needs", texts_of(window.find(:mf_mods_side)),
          ["Map Display", "1.0", "About", "Caps the levels of the party.", "Needs", "Level Cap 1.0: on"])

    choose(tree, list, "Mod Framework")
    check("the framework's row buzzes and turns nothing", [$sounds.last, $requests], [:buzzer, []])
    choose(tree, list, "Level Cap")
    answer(false)
    check("Keep it on keeps a mod others need", [$requests, row_of(list, "Level Cap")], [[], ["Level Cap", true, "Update 1.1"]])
    choose(tree, list, "Level Cap")
    answer(true)
    $mods.find { |mod| mod["name"] == "Map_Display" }.merge!("on" => false, "needs" => [["Level Cap", "1.0", "off", "1.0", "Level_Cap"]])
    screen.listed = mods.state
    choose(tree, list, "Map Display")
    answer(true)
    check("Turn both on turns both on", $requests.last, ["mods.set", { "on" => { "Map_Display" => true, "Level_Cap" => true } }])
    mods::Loader.instance_variable_get(:@used)["online_arena"] = true
    choose(tree, list, "Online Arena")
    check("a Title mod used at the title turns off at once", row_of(list, "Online Arena"), ["Online Arena", false, nil])
    choose(tree, list, "Core Lib")
    bar = window.find(:mf_restart_bar)
    check("a running Framework mod turned off is Off after restart, and the restart bar says so",
          [row_of(list, "Core Lib"), bar.visible, bar.text], [["Core Lib", false, "Off after restart"], true, "Core Lib runs until the game starts again."])

    point_at(tree, list, "Map Display")
    from = list.index
    tell(tree, [[list.node, "carry", from], [list.node, "change", from - 1], [list.node, "drop", from - 1]])
    check("a row dragged within its tag keeps the tag's new order", $requests.last, ["mods.set", { "order" => ["Map_Display", "Level_Cap", "Invasions", "Skip_Intro"] }])

    $refuse = "The game holds Mods.ini open."
    choose(tree, list, "Invasions")
    notice = window.find(:mf_mods_notice)
    check("a refused change buzzes and shows why on the notice line in the restart bar's place",
          [$sounds.last, notice.visible, notice.text, bar.visible], [:buzzer, true, "Nothing changed: the game holds Mods.ini open.", false])
    $refuse = nil
    point_at(tree, list, "Skip Intro")
    check("the notice goes as the cursor moves to another mod", [notice.visible, bar.visible], [false, true])
    tell(tree, [[bar.children.last.node, "click"]])
    Mod_Framework::Run.closing(nil)
    check("Restart now starts the game again as it closes", $requests.last, ["mods.restart", { "action" => nil, "value" => nil }])
    check("the screen is a window of the UI layer that holds the game's buttons", tree.nodes[window.node][:props].values_at("layer", "captures"), [true, true])
  end
end

# Why a mod failed to load, kept for the next session and forgotten once its script changes (0c116d9e).
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  ini = "Patch/Mod_Framework/Mod_Framework.ini"
  fake = with_mods_topics(tree_dll(tree))
  fake.answer("ini.read") { |(path)| $files[path] ||= (path == ini ? { "mod_failed.Core_Lib" => "an old failure", "mod_failed.Invasions" => "Patch/Invasions.rb: NameError: gone" } : {}) }
  boot_tree(fake, :game => lambda { define_mods_game; File.write("Patch/Discord.rb", "raise 'broken on purpose' if Mod_Framework::Mods.respond_to?(:on_enter)\n") }) do
    mods = Mod_Framework::Mods
    frame
    check("a failure is kept for the next session", $files[ini]["mod_failed.Discord"].split("|", 2)[1].start_with?("Patch/Discord.rb: RuntimeError: broken on purpose"), true)
    Mod_Framework::Settings.store("mod_failed.Invasions", "#{mods::Loader.signature(["Patch/Invasions.rb"])}|Patch/Invasions.rb: NameError: gone")
    handle = mods::Screen.open
    frame
    check("one that failed in an earlier session says last time", row_of(mods_screen[1].find(:mf_mods_list), "Invasions"), ["Invasions", false, "Failed to load last time"])
    handle.close
    frame
    File.write("Patch/Invasions.rb", "# fixed\n")
    mods::Screen.open
    frame
    check("a changed script forgets its failure", [row_of(mods_screen[1].find(:mf_mods_list), "Invasions"), $files[ini].key?("mod_failed.Invasions")], [["Invasions", false, nil], false])
  end
end

# The move hotkeys within a tag, which the list takes as the only one, and an order refused in an
# answer that wrote Mods.ini.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  fake = with_mods_topics(tree_dll(tree))
  fake.answer("keys.names") { |codes| codes.map { |code| code == 0x11 ? "Ctrl" : code.chr } }
  boot_tree(fake, :game => lambda { define_mods_game }) do
    frame
    Mod_Framework::Mods::Screen.open
    frame
    Graphics.update
    _screen, window = mods_screen
    list = window.find(:mf_mods_list)
    check("C# learns that the list moves its rows by the move hotkeys", tree.nodes[list.node][:props].values_at("reorder", "move_hotkeys"), [true, true])
    regular = lambda { list.rows.select { |row| row[:group] == "Regular" }.map { |row| row[:text] } }
    point_at(tree, list, "Map Display")
    tell(tree, [[list.node, "reorder", list.index, list.index - 1]])
    check("Move Up moves the mod within its tag, keeps the order and the cursor on it", [regular.call, $requests.last[1], list.row_at(list.index)[:text]],
          [["Map Display", "Level Cap", "Invasions", "Skip Intro"], { "order" => ["Map_Display", "Level_Cap", "Invasions", "Skip_Intro"] }, "Map Display"])
    $written_refusals = [["Invasions", "A mod moves only within its tag."]]
    point_at(tree, list, "Invasions")
    tell(tree, [[list.node, "reorder", list.index, list.index - 1]])
    check("an order refused in an answer that wrote Mods.ini puts the row back", [regular.call, list.row_at(list.index)[:text]],
          [["Map Display", "Level Cap", "Invasions", "Skip Intro"], "Invasions"])
    $written_refusals = nil
    tree.post("states", list.node => Mod_Framework::UI::Engine::Tree::FOCUSED)
    frame
    Graphics.update
    help = window.find(:mf_mods_keys)
    check("the key help names confirm, the move hotkeys and the jump keys before cancel", help.line,
          "Z: On / off  I: Move up  K: Move down  Ctrl+arrows: Leave the list  X or Numpad 0: Close")
    tree.rects[help.node] = [12, 440, 616, 18]
    frame
    Graphics.update
    check("the key help takes a second line for the entries the window has no room for", help.measure[1], 2 * Mod_Framework::UI.line_height_of(:small))
  end
end

# A Title mod whose hotkey came before its options, a row only a save keeps and a hotkey of a mod
# that is off, beside the framework's rows.
ARENA_OPTIONS = <<-RUBY
  $arena_rounds = 3
  Mod_Framework::Hotkeys.define(:arena_open, :key => "J", :name => "[Online Arena] Open Arena", :help => "Opens the arena.")
  Mod_Framework::Options.keep(:arena_rounds, "[Online Arena] Rounds", "How many rounds a fight takes.", lambda { [3, 5] },
                              lambda { $arena_rounds }, lambda { |value| $arena_rounds = value })
  Mod_Framework::Options.add(:arena_music, "[Online Arena] Music", "Plays music in the arena.", { 1 => "On", 0 => "Off" }, 1)
RUBY

# The Mod Configuration: the framework's groups first, a Title mod's options then its hotkeys under
# the caption, a Regular mod that is on with only its remembered hotkeys, none of a mod that is off;
# the help of the mod, then of the row; a value stepped and cancel closing.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  fake = with_mods_topics(tree_dll(tree))
  fake.answer("keys.names") { |codes| codes.map { |code| code.chr } }
  fake.answer("options.groups") do |names|
    names.each_with_index.map { |name, place| [name[/\A\[([^\]]+)\]/, 1] || "Global", [[place, name.sub(/\A\[[^\]]+\]\s*/, "")]]] }
         .group_by { |group, _rows| group }.map { |group, entries| [group, entries.map { |_group, rows| rows }.flatten(1)] }
  end
  game = lambda do
    define_mods_game
    Object.send(:remove_const, :NWConst) if Object.const_defined?(:NWConst)
    Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; MOD_CONTENTS = [{ :key => :return }]; end; end")
  end
  boot_tree(fake, :game => game) do
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    Mod_Framework::Settings.store("hotkey.level_cap_open", "Level_Cap\t75\t75\t[Level Cap] Open\tOpens the cap.")
    Mod_Framework::Settings.store("hotkey.invasions_start", "Invasions\t86\t86\t[Invasions] Start\tStarts an invasion.")
    load_mod("Patch/Online_Arena.rb", ARENA_OPTIONS)
    frame
    $sounds = []
    handle = Mod_Framework::Mods::Screen.open_config
    frame
    Graphics.update
    top = Mod_Framework::UI::Engine::Layer.tops.last
    window = top.root.engine
    mods = window.find(:mf_mods_config_mods)
    options = window.find(:mf_mods_options)
    names = mods.rows.map { |row| row.is_a?(Hash) ? row[:text] : row }
    check("Configuration opens on the mods with the framework's groups first, the Title mod and the Regular mod that is on, the mod's help under its rows",
          [window.title, tree.nodes[mods.node][:props]["autofocus"], names.first(2), names.last(2), names.include?("Invasions"), options.help.text],
          ["Mod Configuration", true, ["Mod Framework", "Mod Framework Hotkeys"], ["Online Arena", "Level Cap"], false,
           "The options and hotkeys of Mod Framework.\r\nConfirm to change them."])

    rows = lambda { options.list.rows.map { |row| row[:heading] || row[:text] } }
    tell(tree, [[mods.node, "change", names.index("Online Arena")]])
    arena = rows.call
    tell(tree, [[mods.node, "change", names.index("Level Cap")]])
    check("a mod's options come first and its hotkeys under the Hotkeys caption; a Regular mod shows only its hotkeys, without the caption",
          [arena, rows.call], [["Rounds", "Hotkeys", "Open Arena"], ["Open"]])

    tell(tree, [[mods.node, "change", names.index("Online Arena")], [mods.node, "submit", names.index("Online Arena")]])
    list = options.list
    check("confirm on a mod hands the focus to its rows", tree.changes.map { |change| change["focus"] }.compact.last, list.node)
    tell(tree, [[list.node, "focus"], [list.node, "change", 0], [list.node, "side", 0, 1]])
    check("on the rows the help line tells the row, and Right steps a value the mod keeps", [options.help.text, $arena_rounds],
          ["How many rounds a fight takes.", 5])
    tell(tree, [[window.node, "close", "cancel"]])
    check("cancel closes it, and the log tells the opening, the change and the close", [handle.open?, $logged.grep(/^mods screen: .*mf_mods_config/).size], [false, 3])
  end
end
