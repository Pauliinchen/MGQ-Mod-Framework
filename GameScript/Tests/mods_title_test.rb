#----------------------------------------------------------------
#  mods_title_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Took a Title mod of no name as the example
#                            - Checked which menu List and Configuration open instead of a tab
#      Paulinchen  2026-11-06: Told the end of a fetch without the relay's list
#                            - Called the engine's classes by their names under UI::Engine
#                            - Opened the mod browser of the UI layer from Browser
#                            - Opened the Mods screen of the UI layer from List and Configuration
#                            - Covered the title's Mods box as a window of the UI layer joined to the title's commands
#      Paulinchen  2026-11-05: Covered the mods' commands put on the title's commands and into the box's list through UI.patch,
#                              and none without the DLL
#      Paulinchen  2026-11-04: Checked each outcome of the title's Mods box on its own
#                            - Rewrote the checks as flow tests of the title's Mods box
#      Paulinchen  2026-11-01: Covered the one cursor of the Mods box and the title commands, and cancel doing nothing in
#                              the box
#                            - Covered the Mods box beside the title commands instead of the box in the corner
#                            - Covered List opening with the focus put into the Mods page and the cursor on the first
#                              mod, which a confirm then turns off
#      Paulinchen  2026-10-30: Covered the updates named in the tooltip of Mod browser
#                            - Covered Mod browser opening the mod browser
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_title.rbx in a booted game against FakeTree: the title's Mods box, a window of the UI
# layer joined to the title's commands, with Browser counting the updates once the fetch ended and
# List its dot once a mod has trouble; List, Configuration and Browser each opening their screen,
# which hides the box and the commands until it closes and the box then takes the keys back; a
# mod's own row in the box's list, which another mod patches; a Title mod's command on the title's
# commands; and neither box nor row without the DLL's list.

require_relative "mods_support"
require_relative "layer_support"

$sounds = []

# A Title mod that puts its command on the title, and one into the Mods box while $shop is true.
ARENA = "Mod_Framework::Mods.title_command(\"Arena\") { |window| window.activate }\n" \
              "Mod_Framework::Mods.title_command(\"Shop Editor\", :in => :mods, :if => lambda { $shop }) { |_window| $shop_picked = true }\n"

in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  $fetching = true
  $shop = false
  game = lambda do
    define_mods_game
    File.write("Patch/Online_Arena.rb", ARENA)
  end
  boot_tree(with_mods_topics(tree_dll(tree)), :game => game) do
    mods = Mod_Framework::Mods
    ui = Mod_Framework::UI
    title = Window_TitleCommand.new
    title.openness = 255
    $scene_now = Object.new
    $scene_now.instance_variable_set(:@command_window, title)
    step = lambda do |events|
      tree.post("events", events) unless events.empty?
      frame
      Graphics.update
      title.update
    end
    open_screen = lambda { ui::Engine::Layer.tops.reverse.find { |top| !top.closed && !top.mount.component.is_a?(mods::TitleModsBox) } }
    focus_asked = lambda { (tree.changes.reverse.find { |change| change.key?("focus_in") } || {})["focus_in"] }

    # The box as the title shows it, before and after the fetch.
    handle = mods::Title.open_box
    step.call([])
    box = ui::Engine::Layer.tops.last.root.engine
    list = nodes_of(tree, "list").last
    rows = lambda { ui::Engine::Tree.component(list).rows }
    check("the box stands beside the title's commands, joined to them, with its heading over Browser, List and Configuration",
          [handle.id, tree.nodes[box.node][:props]["captures"], box.children.first.children.first.text, rows.call.map { |row| row[:text] }],
          ["mf_title_mods", false, "Mods", ["Browser", "List", "Configuration"]])
    $fetching = false
    $dll.post("mods.fetched", "site" => true)
    step.call([])
    check("once the fetch ended Browser counts the updates, and List shows no dot while no mod has trouble",
          [rows.call[0][:badge], rows.call[1][:badge]], [1, false])

    # List opens the Mod List, which hides the box and the commands; closing it gives the
    # box the keys back and shows the dot of a mod that now misses a requirement.
    tree.post("states", list => ui::Engine::Tree::FOCUSED)
    step.call([[list, "change", 1], [list, "submit", 1]])
    screen = open_screen.call
    check("List opens the Mod List over the hidden box and commands",
          [screen.id, title.visible, tree.nodes[box.node][:props]["visible"]], ["mf_mods", false, false])
    $mods.find { |mod| mod["name"] == "Map_Display" }["needs"] = [["Level Cap", "2.0", "missing", "", ""]]
    screen.root.engine.close(:script)
    2.times { step.call([]) }
    check("closing it shows both again, asks the box to take the keys and puts the dot on List",
          [title.visible, tree.nodes[box.node][:props]["visible"], focus_asked.call, rows.call[1][:badge]], [true, true, box.node, true])

    # Configuration opens its menu; Browser opens the mod browser.
    step.call([[list, "change", 2], [list, "submit", 2]])
    check("Configuration opens the Mod Configuration", open_screen.call.id, "mf_mods_config")
    open_screen.call.root.engine.close(:script)
    2.times { step.call([]) }
    step.call([[list, "change", 0], [list, "submit", 0]])
    browser = mods::Browser.current
    check("Browser opens the mod browser on the UI layer, which hides the commands", [browser.is_a?(mods::ModBrowser), title.visible], [true, false])
    browser.close
    2.times { step.call([]) }

    # A mod's own row in the box, renamed by another mod's patch, runs its block; it leaves once its
    # :if is false.
    $shop = true
    load_mod("Patch/Shop_Names.rb", "Mod_Framework::UI.patch(\"#mf_title_mods_list\") { |t| t.rows { |rows| rows.map { |row| row[:id] == :mods_online_arena_shop_editor ? row.merge(:text => \"Shop\") : row } } }")
    mods::Title.show_badges
    step.call([])
    check("the box's list takes the mod's row at its end, renamed by another mod", rows.call.map { |row| row[:text] }, ["Browser", "List", "Configuration", "Shop"])
    step.call([[list, "change", 3], [list, "submit", 3]])
    check("its row runs the mod's block", $shop_picked, true)
    $shop = false
    mods::Title.show_badges
    step.call([])
    check("it leaves once its :if is false", rows.call.size, 3)

    # A mod's command on the title's commands comes through a patch, before Shutdown, once its mod
    # is on.
    mods::Loader.follow_changes(["Core_Lib", "Online_Arena"], [])
    title.refresh
    arena = title.symbols.index(:mods_online_arena_arena)
    check("a Title mod's command stands on the title's commands before Shutdown once its mod is on", arena && title.symbols[arena + 1], :shutdown)
    handle.close
  end
end

# Without the DLL's list of mods there is no box, and a mod's command with :in => :mods shows
# nowhere.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    title = Window_TitleCommand.new
    title.openness = 255
    Mod_Framework::Mods.title_command("Shop Editor", :in => :mods) { |window| window.activate }
    frame
    title.update
    check("without the DLL's list a mod's command with :in => :mods shows neither a box nor a command",
          [Mod_Framework::Mods::Title.open_box, Mod_Framework::UI::Engine::Layer.tops.size, title.symbols.include?(:mods_shop_editor)], [nil, 0, false])
  end
end
