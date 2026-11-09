#----------------------------------------------------------------
#  mods_saves_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Covered a save missing a Data mod, which the player installs by hand
#      Paulinchen  2026-11-07: Closed the game before checking that it starts again
#      Paulinchen  2026-11-06: Covered the save's mods dialog as a component of the UI layer: its rows to read, the line for
#                              the mods to get from their authors, the first button hidden, and cancel while it installs
#      Paulinchen  2026-11-04: Checked each outcome of loading a save made with other mods on its own
#                            - Rewrote the checks as flow tests of loading a save made with other mods
#      Paulinchen  2026-10-31: Took the failed install told without its cause
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Covers mods_saves.rbx in a booted game against FakeTree: a save whose mods are off or missing
# opens the dialog of the UI layer whose Back, Load anyway and first button (install, turn on and
# load, or restart and load in the game) a player picks; a save's header keeps the mods of the
# session.

require_relative "layer_support"

# The plan the DLL answers: one Regular mod.
PLAN = { "load" => [["Plain", "Regular", "Patch", "1.0"]], "warnings" => [] }

# A save made with a mod now off, one missing that the website has, one missing that nobody has
# and one in another version, as the DLL compares it.
ROWS = [
  { "kind" => "off", "name" => "Level_Cap", "title" => "Level Cap", "saved" => "1.5.2", "installed" => "1.5.2", "target" => "Level_Cap" },
  { "kind" => "install", "name" => "map-display", "title" => "Map Display", "saved" => "1.2.0", "installed" => "1.2.0", "target" => "site:map-display" },
  { "kind" => "unknown", "name" => "My_Script", "title" => "My_Script", "saved" => "?", "installed" => "", "target" => "" },
  { "kind" => "version", "name" => "Plain", "title" => "Plain", "saved" => "0.9", "installed" => "1.0", "target" => "Plain" }
]

# The mods the header of the save in slot 2 names.
SAVED_MODS = [["Level_Cap", "1.5.2", "Regular"], ["map-display", "1.2.0", "Regular"], ["My_Script", "?", "Regular"], ["Plain", "0.9", "Regular"]]

# Defines the game's DataManager and its load scene as far as the check follows them, and the
# Regular mod in Patch.
def define_saves_game
  [:Scene_Load, :DataManager].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
  Object.class_eval <<-RUBY
    module DataManager
      def self.load_database; end
      def self.setup_new_game; end
      def self.make_save_header; { :playtime_s => "00:01:00" }; end
      def self.load_header(index); $headers[index]; end
      def self.load_game(index); $loads << index; true; end
    end
    class Scene_Load
      def initialize(index); @index = index; end
      def update; end
      def on_savefile_ok; DataManager.load_game(@index); end
    end
  RUBY
  FileUtils.mkdir_p("Patch")
  File.write("Patch/Plain.rb", "$order << 'Plain'\n")
  $headers = {}
  $loads = []
  $order = []
end

# Makes the DLL: the tree's, and the mod management's topics, each request noted in $requests; the
# check answers $rows.
#
# @param tree [FakeTree] The tree.
# @return [FakeBridge] The DLL.
def saves_dll(tree)
  fake = tree_dll(tree)
  $requests = []
  fake.answer("mods.plan") { |_request| PLAN }
  fake.answer("mods.check") { |request| $requests << ["mods.check", request]; { "rows" => $rows } }
  fake.answer("mods.set") { |request| $requests << ["mods.set", request]; { "mods" => [], "written" => true, "refused" => [] } }
  fake.answer("mods.install") { |request| $requests << ["mods.install", request]; { "started" => true, "refused" => nil } }
  fake.answer("mods.restart") { |request| $requests << ["mods.restart", request]; { "started" => true, "refused" => nil } }
  fake
end

# Finds the open save's mods dialog: its component and its engine root.
#
# @return [Array] The component and the root; nils while none is open.
def save_dialog
  top = Mod_Framework::UI::Engine::Layer.tops.reverse.find { |each| !each.closed && each.mount.component.is_a?(Mod_Framework::Mods::SaveModsDialog) }
  top ? [top.mount.component, top.root.engine] : [nil, nil]
end

# Finds the parts of a kind inside an engine part, in the order they show.
#
# @param part [Mod_Framework::UI::Engine::Component] The part.
# @param klass [Class] The kind.
# @return [Array] The parts.
def parts_of(part, klass)
  (part.is_a?(klass) ? [part] : []) + part.children.map { |child| parts_of(child, klass) }.flatten
end

# Finds a button of the dialog by its text.
#
# @param root [Mod_Framework::UI::Engine::Component] The dialog's root.
# @param text [String] The text.
# @return [Mod_Framework::UI::Engine::Button, nil] The button.
def button_of(root, text)
  parts_of(root, Mod_Framework::UI::Engine::Button).find { |button| button.text == text }
end

# Tells the texts of the dialog that show, the line under its title first, then the status line.
#
# @param root [Mod_Framework::UI::Engine::Component] The dialog's root.
# @return [Array<String>] The texts.
def lines_of(root)
  parts_of(root, Mod_Framework::UI::Engine::Label).select { |label| label.visible && !label.is_a?(Mod_Framework::UI::Engine::Button) }.map { |label| label.text }
end

# Picks a save in the load scene and runs the frame, as confirm on it does.
#
# @param scene [Scene_Load] The scene.
# @return [Array] The dialog's component and root it opened.
def pick_save(scene)
  scene.on_savefile_ok
  frame
  Graphics.update
  save_dialog
end

# A save whose mods are off or missing: the dialog, its rows to read, cancel, Load anyway, a save
# whose mods nobody has, and the header of a save.
in_game_folder do
  tree = FakeTree.new
  $rows = ROWS
  $sounds = []
  boot_tree(saves_dll(tree), :game => lambda { define_saves_game }) do
    frame
    $headers[2] = { :mods => SAVED_MODS }
    scene = Scene_Load.new(2)
    _dialog, root = pick_save(scene)
    check("the dialog opens instead of loading", [root && root.id, $loads], [:mods_save_check, []])
    list = root.find(:mods_save_rows)
    check("each mod says what happens to it, the one nobody has faint with where to get it", list.rows.map { |row| row.values_at(:text, :right, :faint, :tooltip) },
          [["Level Cap 1.5.2", "turns on", nil, nil], ["Map Display 1.2.0", "installs", nil, nil],
           ["My_Script", "not on the site", true, "Get it from its author and put it into the Patch folder."], ["Plain", "the save used 0.9, you have 1.0", nil, nil]])
    check("the rows are to read: C# keeps the keys and the pointer off them", tree.nodes[list.node][:props]["acts"], false)
    check("the line under the title, then the line that names the mod to get for the keys", lines_of(root),
          ["Save 3 was made with mods that are not on now.", "Get My_Script from its author and put it into the Patch folder."])
    first = button_of(root, "Install, turn on and load")
    check("the first button does all it can, filled, the focus on it", [first && first.visible, tree.nodes[first.node][:props]["autofocus"]], [true, true])
    tell(tree, [[root.node, "cancel"]])
    scene.update
    check("cancel goes back to the save list, loading nothing", [save_dialog[1], $loads, !$logged.grep(/went back to the save list from mods_save_check/).empty?], [nil, [], true])

    _dialog, root = pick_save(scene)
    tell(tree, [[button_of(root, "Load anyway").node, "click"]])
    scene.update
    check("Load anyway loads the save in the list's next update, the mods turned on now loading", [$loads, $order], [[2], ["Plain"]])
    check("a save's header keeps the mods loaded", DataManager.make_save_header[:mods], [["Plain", "1.0", "Regular"]])

    $rows = ROWS.select { |row| row["kind"] == "unknown" }
    $headers[4] = { :mods => [["My_Script", "?", "Regular"]] }
    _dialog, root = pick_save(Scene_Load.new(4))
    anyway = button_of(root, "Load anyway")
    check("with only a mod nobody has the first button hides and the focus starts on Load anyway",
          [parts_of(root, Mod_Framework::UI::Engine::Button).select { |button| button.visible }.map { |button| button.text }, tree.nodes[anyway.node][:props]["autofocus"]],
          [["Load anyway", "Back"], true])
    tell(tree, [[root.node, "cancel"]])

    checked = $requests.size
    $headers[1] = { :playtime_s => "00:01:00" }
    Scene_Load.new(1).on_savefile_ok
    check("a save without the list loads at once, unchecked", [$loads, $requests.size], [[2, 1], checked])
  end
end

# The first button installs what is missing while every button greys and cancel waits, a failed
# install gives the buttons back, and in the game it restarts to load the save.
in_game_folder do
  tree = FakeTree.new
  $rows = ROWS.first(3)
  $sounds = []
  boot_tree(saves_dll(tree), :game => lambda { define_saves_game }) do
    frame
    $headers[2] = { :mods => SAVED_MODS.first(3) }
    scene = Scene_Load.new(2)
    dialog, root = pick_save(scene)
    tell(tree, [[button_of(root, "Install, turn on and load").node, "click"]])
    $dll.post("mods.installing", "done" => 0, "total" => 1, "mod" => "Map Display")
    frame
    Graphics.update
    tell(tree, [[root.node, "cancel"]])
    buttons = parts_of(root, Mod_Framework::UI::Engine::Button).select { |button| button.visible }
    check("while it installs: the gauge, its line, every button greyed, and cancel waits with the buzzer",
          [parts_of(root, Mod_Framework::UI::Engine::Gauge).map { |gauge| gauge.visible }, lines_of(root)[1], buttons.map { |button| button.enabled? }, save_dialog[1].equal?(root),
           $sounds.last(2)],
          [[true], "Installing Map Display . . .", [false, false, false], true, [:ok, :buzzer]])
    $dll.post("mods.installed", "installed" => [], "mod" => "Map Display", "error" => "The website could not be reached.")
    frame
    Graphics.update
    check("a failed install says so, buzzes and gives the buttons back",
          [lines_of(root)[1], dialog.status, $sounds.last, buttons.map { |button| button.enabled? }],
          ["Map Display could not be installed.", ["Map Display could not be installed.", :error], :buzzer, [true, true, true]])
    tell(tree, [[button_of(root, "Install, turn on and load").node, "click"]])
    $dll.post("mods.installed", "installed" => ["map-display"], "mod" => nil, "error" => nil)
    frame
    scene.update
    check("once installed the mods turn on", $requests.find { |name, _request| name == "mods.set" },
          ["mods.set", { "on" => { "Level_Cap" => true, "map-display" => true } }])
    check("and the save loads", [$loads, save_dialog[1]], [[2], nil])

    $headers[3] = { :mods => SAVED_MODS.first(1) }
    later = Scene_Load.new(3)
    _dialog, root = pick_save(later)
    check("in the game the first button restarts and loads, and the line under the title says so",
          [button_of(root, "Restart and load").nil?, lines_of(root)[0]], [false, "The game starts again and loads this save."])
    tell(tree, [[button_of(root, "Restart and load").node, "click"]])
    $dll.post("mods.installed", "installed" => ["map-display"], "mod" => nil, "error" => nil)
    frame
    later.update
    Mod_Framework::Run.closing(nil)
    check("it starts the game again as it closes to load the save at the title", $requests.last, ["mods.restart", { "action" => "load", "value" => "3" }])
  end
end

# A save missing a Data mod, which the player installs by hand: its row and the line say so, and
# the first button turns the other mod on and loads without installing it.
in_game_folder do
  tree = FakeTree.new
  $rows = [ROWS[0], { "kind" => "by_hand", "name" => "bigger-shops", "title" => "Bigger Shops", "saved" => "1.0", "installed" => "1.0", "target" => "site:bigger-shops" }]
  $sounds = []
  boot_tree(saves_dll(tree), :game => lambda { define_saves_game }) do
    frame
    $headers[2] = { :mods => [SAVED_MODS[0], ["bigger-shops", "1.0", "Data"]] }
    scene = Scene_Load.new(2)
    _dialog, root = pick_save(scene)
    check("the Data mod's row and the line under the list tell the player to install it by hand",
          [root.find(:mods_save_rows).rows.last.values_at(:right, :tooltip), lines_of(root).last],
          [["install by hand", "Install it by hand from its page on the website."], "Install Bigger Shops by hand from its page on the website."])
    tell(tree, [[button_of(root, "Turn on and load").node, "click"]])
    scene.update
    check("the first button turns the other mod on and loads, installing nothing",
          [$requests.map { |name, _request| name }, $loads], [["mods.check", "mods.set"], [2]])
  end
end
