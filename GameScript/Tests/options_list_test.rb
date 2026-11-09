#----------------------------------------------------------------
#  options_list_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Expected the hotkey rows last under the Hotkeys caption
#                            - Added the options list without the removed builder
#      Paulinchen  2026-11-06: Checked that the rows ask for the room of all of them and give back what their window lacks
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Named the hotkey that has a refused key as the step 8 spec words it
#                            - Checked that a refused key is logged with its row and owner
#                            - Bound a key row through the wait C#'s tree runs
#      Paulinchen  2026-11-04: Kept a few flows of the Mod Config's rows and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the Mod Config's rows, their values and their key rows
#      Paulinchen  2026-11-01: Bound the sample key rows to L, clear of the framework's Move Mod Down
#      Paulinchen  2026-10-31: Took a bound key named a hotkey
#      Paulinchen  2026-10-30: Covered Left and Right taken only on the rows with a value
#                            - Covered rows of a source of its own
#                            - Kept to the mods' rows beside the framework's own
#                            - Created
#
#----------------------------------------------------------------

# Covers options_list.rbx in a booted game against FakeTree: the rows of Options > Mods under a
# heading per mod with the help line, asking for the room of every row; a value stepped, a button
# row, and a key row that refuses taken keys, binds a free one and keeps its key on Esc.

require_relative "tree_support"

$sounds = []

# Windows' codes of the keys the test presses.
ENTER = 0x0D
ESCAPE = 0x1B
KEY_T = 0x54
KEY_L = 0x4C

# The game's options with a few mods' rows in Options > Mods.
GAME = lambda do
  Object.send(:remove_const, :NWConst) if Object.const_defined?(:NWConst)
  Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; MOD_CONTENTS = [{ :key => :return }]; end; end")
end

# Answers the DLL's topics of the rows as C# does for these names and keys.
#
# @param fake [FakeBridge] The DLL's side.
# @return [FakeBridge] It.
def with_options_topics(fake)
  fake.answer("options.groups") do |names|
    groups = []
    current = "Global"
    names.each_with_index do |name, place|
      current = name =~ /\A\[([^\]]+)\]\s*/ ? $1 : (name =~ /\A(\s|->)/ ? current : "Global")
      group = groups.find { |each| each[0] == current } || (groups << [current, []]).last
      group[1] << [place, name.sub(/\A\[[^\]]+\]\s*/, "")]
    end
    groups
  end
  fake.answer("keys.names") { |codes| codes.map { |code| { ENTER => "Enter", ESCAPE => "Esc", KEY_T => "T", KEY_L => "L" }[code] || "F5" } }
  fake.answer("keys.bindable") { |_request| [ENTER, ESCAPE, KEY_T, KEY_L] }
  fake.answer("keys.judge") { |code| { ENTER => "game", ESCAPE => "keep" }[code] || "bind" }
  fake
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(with_options_topics(tree_dll(tree)), :game => GAME) do
    ui = Mod_Framework::UI
    config = NWConst::Config
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    changes = []
    $chat_key = 0x74
    config::DATA[:mod_cap] = [1, 0]
    config::DATA_TEXT[:mod_cap] = { 1 => { :name => "On", :help => "Caps the level." }, 0 => { :name => "Off", :help => "No cap." } }
    config::DEFAULT[:mod_cap] = 1
    config::DATA[:mod_speed] = [1, 2]
    config::DEFAULT[:mod_speed] = 1
    menu = config::MOD_CONTENTS
    menu.insert(-2, { :key => :mod_cap, :name => "[Level Cap] Level Cap", :sub => true, :help => "The cap.", :on_change => lambda { |value| changes << value } })
    menu.insert(-2, { :key => :mod_write, :name => "     -> Write Now", :sub => false, :help => "Writes it." })
    menu.insert(-2, { :key => :mod_speed, :name => "[Online] Speed", :sub => true, :help => "How fast." })
    menu.insert(-2, { :key => :mod_chat, :name => "[Online] Chat", :keybind => true, :help => "Opens the chat.",
                      :value => lambda { $chat_key }, :on_change => lambda { |code| $chat_key = code } })
    menu.insert(-2, { :key => :mod_open, :name => "[Online] Open", :keybind => true, :help => "Opens it.", :value => lambda { KEY_L } })
    frame

    # The player opens the mods' rows, steps a value and presses a button row.
    pressed = []
    window = ui::Engine::Window.new(:size => [400, 300])
    options = window.add(ui::Engine::OptionsList.new(:only => lambda { |row| row[:key].to_s.start_with?("mod_") }, :handler => lambda { |key| pressed << key; key == :mod_write }))
    window.open
    frame
    list = options.list
    check("the mods' rows show under a heading per mod with their values, the hotkey rows last under the Hotkeys caption", list.rows.map { |row| row[:heading] || [row[:text], row[:value]] },
          ["Level Cap", ["Level Cap", "On"], ["     -> Write Now", nil], "Online", ["Speed", "1"], "Hotkeys", ["Chat", "F5"], ["Open", "L"]])
    props = tree.nodes[list.node][:props]
    check("the rows ask for the room of all eight and give back what the window lacks [height, gives back]", [props["measured"][1], props["shrink"]],
          [8 * props["row_height"], true])
    tree.post("events", [[list.node, "side", 1, 1]])
    frame
    check("Right steps the value into the save", $game_system.conf[:mod_cap], 0)
    tree.post("events", [[list.node, "submit", 2]])
    frame
    check("confirm on a button row has the handler press it", pressed, [:mod_write])

    # The player binds a key row: C#'s tree waits with the other rows' keys taken; a key of the
    # game and a taken one are refused, a free one binds, and once it is let go the wait ends; Esc
    # keeps the key.
    list.index = 6
    tree.post("events", [[list.node, "submit", 6]])
    frame
    Graphics.update
    taken = tree.nodes[list.node][:props]["capture"]
    check("the wait C#'s tree runs, with the keys the other rows have [Open's, Chat's own]", [taken[KEY_L], taken[0x74]], ["[Online] Open", nil])
    refused = logged_lines do
      tree.post("events", [[list.node, "refused", ENTER, "game", nil]])
      frame
    end
    check("a key of the game is refused", options.help.text, "Enter is one of the game's own keys.\r\nPress another key, or Esc to keep F5.")
    check("the refusal is logged with the row, the key and its owner", refused.grep(/key capture/),
          ["key capture: :mod_chat refused Enter (key code 13): one of the game's keys"])
    tree.post("events", [[list.node, "refused", KEY_L, "hotkey", "[Online] Open"]])
    frame
    check("a key another row has is refused", options.help.text, "L is already the key of [Online] Open.\r\nPress another key, or Esc to keep F5.")
    tree.post("events", [[list.node, "captured", KEY_T]])
    frame
    check("a free key binds", [$chat_key, list.row_at(6)[:value]], [KEY_T, "T"])
    tree.post("events", [[list.node, "released"]])
    frame
    Graphics.update
    check("the wait ends once the key is let go", [ui::Engine::OptionsList.waiting?, tree.nodes[list.node][:props]["capture"]], [false, nil])
    tree.post("events", [[list.node, "submit", 6]])
    frame
    tree.post("events", [[list.node, "kept", ESCAPE, "key"], [list.node, "released"]])
    frame
    check("Esc keeps the key", [$chat_key, list.row_at(6)[:value], ui::Engine::OptionsList.waiting?], [KEY_T, "T", false])
    window.close
  end
end
