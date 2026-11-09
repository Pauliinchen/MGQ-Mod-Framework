#----------------------------------------------------------------
#  mods_needed_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Expected the mods in use named to the install
#      Paulinchen  2026-11-06: Checked that a mod left out which runs already stays on
#                            - Checked that the install asks for the versions the place needs
#                            - Checked that restart: :caller hands the start of the game to the caller
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_needed.rbx in a booted game against FakeTree, through a mod that enters Galda's World:
# the world's mods compared by the DLL; a world whose mods are all on asks nothing; one with a mod to
# install, one to update, one to turn on and one that leaves the player's other mods out opens the
# dialog, whose first button turns on and installs, then enters; a mod only its author has hides
# the first button and says where to put it; Back goes back; and, once the player is in the game,
# a mod to turn on, whose start of the game again restart: :caller leaves to the caller, and a mod
# left out that runs already, which stays on.

require_relative "layer_support"

# The plan the DLL answers: the framework's own mod and a Regular one.
NEEDED_PLAN = { "load" => [["Wide_Text", "Framework", "Patch", "1.0"], ["Now_Playing", "Regular", "Patch", "1.0"]], "warnings" => [] }

# Galda's World as the DLL compares it: Level Cap to install, Party Sheet to update, Invasions to
# turn on.
NEEDED_ROWS = [
  { "kind" => "install", "name" => "Level Cap", "title" => "Level Cap", "have" => "", "want" => "1.5.2", "target" => "site:level-cap", "installed" => "" },
  { "kind" => "update", "name" => "Party Sheet", "title" => "Party Sheet", "have" => "1.5.1", "want" => "1.5.2", "target" => "site:party-sheet", "installed" => "Party_Sheet" },
  { "kind" => "off", "name" => "Invasions", "title" => "Invasions", "have" => "1.0", "want" => "", "target" => "Invasions", "installed" => "Invasions" }
]

# A mod of the world that only its author has.
AUTHOR_ROW = { "kind" => "author", "name" => "Old Script", "title" => "Old Script", "have" => "", "want" => "1.0", "target" => "", "installed" => "" }

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  $requests = []
  $rows = []
  fake.answer("mods.plan") { |_request| NEEDED_PLAN }
  fake.answer("mods.needs") { |request| $requests << ["mods.needs", request]; { "rows" => $rows } }
  fake.answer("mods.set") { |request| $requests << ["mods.set", request]; { "mods" => [], "written" => true, "refused" => [] } }
  fake.answer("mods.install") { |request| $requests << ["mods.install", request]; { "started" => true, "refused" => nil } }
  fake.answer("mods.restart") { |request| $requests << ["mods.restart", request]; { "started" => true } }
  boot_tree(fake) do
    mods = Mod_Framework::Mods
    frame
    world = [{ name: "Level Cap", version: "1.5.2" }, { name: "Party Sheet", version: "1.5.2" }, { name: "Invasions" }, { name: "Old Script", version: "1.0", differs: true }]
    heard = []
    dialog = lambda do
      top = Mod_Framework::UI::Engine::Layer.tops.reverse.find { |each| !each.closed && each.id == "mods_needed" }
      top && top.root.engine
    end
    texts = lambda do |root|
      labels = []
      walk = lambda { |part| labels << part.text if part.is_a?(Mod_Framework::UI::Engine::Label) && !part.is_a?(Mod_Framework::UI::Engine::Button) && part.visible; part.children.each { |child| walk.call(child) } }
      walk.call(root)
      labels
    end

    # Every mod is on: nothing asks, the block hears :ready at once.
    check("a world whose mods are all on [answer, heard, the DLL asked with each mod]", [mods.ask_needed("Iliasburg", world) { |result| heard << result }, heard, $requests.last[1]["mods"]],
          [:ready, [:ready], [["Level Cap", "1.5.2", false], ["Party Sheet", "1.5.2", false], ["Invasions", "", false], ["Old Script", "1.0", true]]])

    # Galda's World: each mod says what happens to it, the line names the mod it leaves out and the
    # framework's that stays on, and the first button does it all.
    $rows = NEEDED_ROWS
    heard.clear
    mods.ask_needed("Galda's World", world, leaves_out: ["Now_Playing", "Wide_Text"]) { |result| heard << result }
    frame
    Graphics.update
    root = dialog.call
    list = root.find(:mods_needed_rows)
    check("the rows [text, what happens]", list.rows.map { |row| row.values_at(:text, :right) },
          [["Level Cap", "install 1.5.2"], ["Party Sheet", "update 1.5.1 to 1.5.2"], ["Invasions", "turn on"]])
    check("the lines [title, intro, left out, framework]", [root.title, texts.call(root)],
          ["Mods for Galda's World", ["Galda's World needs these mods.", "Galda's World turns off your other mods while you play in it: Now_Playing. They stay on in your saves.",
                                      "Wide_Text is part of the framework and stays on."]])
    first = root.find(:mods_needed_first)
    check("the first button", [first.text, first.visible], ["Install, turn on and enter", true])
    tell(tree, [[first.node, "click"]])
    check("the install asked for the mods to install and update at the versions the world needs", $requests.last,
          ["mods.install", { "ids" => ["site:level-cap", "site:party-sheet"], "running" => [], "versions" => { "site:level-cap" => "1.5.2", "site:party-sheet" => "1.5.2" } }])
    $dll.post("mods.installed", "installed" => ["Level_Cap", "Party_Sheet"], "mod" => nil, "error" => nil)
    3.times { frame; Graphics.update }
    check("after the install [turned on, the dialog, heard]", [$requests.find { |request| request[0] == "mods.set" }, dialog.call, heard],
          [["mods.set", { "on" => { "Invasions" => true } }], nil, [:ready]])

    # Old Script only its author has: no first button, the line says where to put it; Back goes back.
    $rows = [AUTHOR_ROW]
    heard.clear
    mods.ask_needed("Galda's World", world) { |result| heard << result }
    frame
    Graphics.update
    root = dialog.call
    check("a mod only its author has [first button shows, the line]", [root.find(:mods_needed_first).visible, texts.call(root).last],
          [false, "Get Old Script from its author, put it into the Patch folder, then try again."])
    tell(tree, [[root.find(:mods_needed_back).node, "click"]])
    2.times { frame; Graphics.update }
    check("Back goes back", [dialog.call, heard], [nil, [:back]])

    # The player enters the game, which loads Now_Playing's script.
    File.open("Patch/Now_Playing.rb", "w") { |file| file.write("# Now Playing") }
    mods.enter("a new game")

    # In the game, Invasions turns on only as the game starts again; with restart: :caller the block
    # hears it once the mod is on, and the game is not started again.
    $rows = [NEEDED_ROWS[2]]
    heard.clear
    mods.ask_needed("Galda's World", world, restart: :caller) { |result| heard << result }
    frame
    Graphics.update
    first = dialog.call.find(:mods_needed_first)
    first_text = first.text
    tell(tree, [[first.node, "click"]])
    3.times { frame; Graphics.update }
    check("a mod to turn on in the game, with restart: :caller [first button, dialog, heard, the game asked to start again]",
          [first_text, dialog.call, heard, $requests.any? { |request| request[0] == "mods.restart" }], ["Turn on and enter", nil, [:restart_needed], false])

    # In the game, a world that leaves out Now_Playing, which loaded as the player entered, says it
    # runs already and stays on.
    $rows = []
    mods.ask_needed("Galda's World", world, leaves_out: ["Now_Playing"]) { |_result| nil }
    frame
    Graphics.update
    check("a mod left out that runs already [running, the line]", [mods.running?("Now_Playing"), texts.call(dialog.call)],
          [true, ["Now_Playing runs already and stays on."]])
  end
end
