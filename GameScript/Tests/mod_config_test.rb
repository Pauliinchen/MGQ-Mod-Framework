#----------------------------------------------------------------
#  mod_config_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Covered a row of Options > Mods greyed through UI.patch
#                            - Covered a mod made for Mod Config Remake calling its methods
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Covered Options > Mods on the UI layer, the mods on the left and the rows of the mod picked
#                              on the right, its help in the game's help window
#      Paulinchen  2026-11-04: Checked each outcome of the Mod Config window on its own
#                            - Rewrote the checks as flow tests of the Mod Config window
#      Paulinchen  2026-10-31: Covered the game's windows the Mod Config covers hidden while it is open
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Covers mod_config.rbx in a booted game against FakeTree: the Mods row of the untranslated game's
# options opens Options > Mods over the options list, the mods on the left and the rows of the mod
# picked on the right, the help in the game's help window; it presses a mod's button rows,
# refreshes the rows and gives the options back as it closes. The Mods tab of the translation's
# tabbed options opens it over the tab's list. A mod made for Mod Config Remake gets its answers.

require_relative "game_lists_support"

$sounds = []

# The options screen of the untranslated game: a list of the options and a help window, made as it
# starts; a mod's hook sets the handler of its button row after the start, as Party Sheet does.
SCENE = <<-RUBY
  class Window_Base
    def hide; self.visible = false; self; end
  end
  class HelpStandIn
    attr_reader :text
    def height; 120; end
    def standard_padding; 12; end
    def line_height; 24; end
    def set_text(text); @text = text; end
  end
  class Window_Selectable
    def call_update_help; @help_window.set_text("The options' row.") if @help_window; end
    def help_window=(window); @help_window = window; end
  end
  class Scene_Config
    attr_reader :config_window, :help_window, :mod_config_window, :item_window
    def start
      create_config_window
      @mod_config_window.set_handler(:mod_write, lambda { $written << :write }) if @mod_config_window
    end
    def create_config_window
      @help_window = HelpStandIn.new
      @config_window = Window_Selectable.new(0, 120, 640, 360)
      @config_window.help_window = @help_window
      @config_window.activate
    end
  end
RUBY

# The translation's tabbed options screen: tabs over a list of the picked tab's options.
TABS = <<-RUBY
  class Window_BetterConfigTabs < Window_Selectable
    attr_accessor :tab
    def current_tab; { :name => @tab }; end
  end
  class Window_BetterConfigItems < Window_Selectable
    def clear_items; $cleared = true; end
  end
  class Scene_Config
    def create_config_window
      @help_window = HelpStandIn.new
      @config_window = Window_BetterConfigTabs.new(0, 120, 640, 48)
      @item_window = Window_BetterConfigItems.new(0, 168, 640, 312)
    end
    def on_config_tab_ok; $opened_tabs << @config_window.current_tab[:name]; end
  end
RUBY

# Defines the game's lists, its options with a few mods' rows and its options screen.
#
# @param tabs [Boolean] Whether the options screen has the translation's tabs.
# @return [Proc] What boot_tree runs before the mods load.
def game_with(tabs)
  lambda do
    define_game_lists
    [:NWConst, :ModConfigRemake, :Scene_Config, :Window_ModConfig, :Window_BetterConfigTabs, :Window_BetterConfigItems, :HelpStandIn].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
    Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :bgm }, { :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; end; end")
    Object.class_eval(SCENE)
    Object.class_eval(TABS) if tabs
  end
end

# Sorts rows' names by mod as C#'s OptionGroups does: "[Mod] Name" starts or joins that mod's group,
# an indented name joins the group above it, any other goes to Global.
#
# @param names [Array<String>] The names.
# @return [Array<Array>] Each group's name with its rows' places and names without the group.
def grouped_names(names)
  groups = []
  current = "Global"
  names.each_with_index do |name, place|
    current = name =~ /\A\s*\[([^\]]+)\]\s*/ ? $1.strip : (name =~ /\A(\s|->)/ ? current : "Global")
    groups << [current, []] unless groups.any? { |group, _rows| group == current }
    groups.find { |group, _rows| group == current }[1] << [place, name.sub(/\A\s*\[[^\]]+\]\s*/, "").sub(/\A[\s\->]+/, "")]
  end
  groups
end

# Makes the DLL of a booted game that sorts the rows by mod.
#
# @param tree [FakeTree] The tree.
# @return [Object] The DLL.
def options_dll(tree)
  dll = tree_dll(tree)
  dll.answer("options.groups") { |names| grouped_names(names) }
  dll
end

# Adds the mods' rows to Options > Mods: Level Cap's value and its indented button row, and Party
# Sheet's value.
def add_rows
  config = NWConst::Config
  config::DATA[:mod_cap] = [1, 0]
  config::DATA_TEXT[:mod_cap] = { 1 => { :name => "On", :help => "Caps it." }, 0 => { :name => "Off", :help => "No cap." } }
  config::MOD_CONTENTS.insert(-2, { :key => :mod_cap, :name => lambda { $cap_name }, :sub => true, :help => "The cap." })
  config::MOD_CONTENTS.insert(-2, { :key => :mod_write, :name => "     -> Write Now", :sub => false, :help => "Writes it." })
  config::DATA[:mod_sheet] = [0, 1]
  config::DATA_TEXT[:mod_sheet] = { 0 => { :name => "Off" }, 1 => { :name => "On" } }
  config::MOD_CONTENTS.insert(-2, { :key => :mod_sheet, :name => "[Party Sheet] Shown", :sub => true, :help => "Shows the sheet." })
end

# Finds the two lists of the open Options > Mods: the mods and the rows of the mod picked.
#
# @param tree [FakeTree] The tree.
# @return [Array<Mod_Framework::UI::Engine::List>] The list of the mods and the list of the rows.
def both_lists(tree)
  window = tree.last("window")
  lists = tree.nodes.keys.sort.select { |node| tree.nodes[node][:kind] == "list" && node > window }
  lists.map { |node| Mod_Framework::UI::Engine::Tree.component(node) }
end

# Tells the texts of a list's rows.
#
# @param list [Mod_Framework::UI::Engine::List] The list.
# @return [Array<String>] The texts.
def texts_of(list)
  list.rows.map { |row| row.is_a?(Hash) ? row[:heading] || row[:text] : row.to_s }
end

# Posts what C# tells, then lets a frame tick and draw.
#
# @param tree [FakeTree] The tree.
# @param events [Array<Array>] The events, each [node, name, values...].
def tell(tree, events)
  tree.post("events", events)
  frame
  Graphics.update
end

# The untranslated game's options: the Mods row opens the window, pointing at a mod shows its rows,
# a button row and a value change refresh them, and closing gives the options back.
in_game_folder do
  tree = FakeTree.new
  boot_tree(options_dll(tree), :game => game_with(false)) do
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    $written = []
    $cap_name = "[Level Cap] Level Cap"
    add_rows
    frame
    scene = Scene_Config.new
    $scene_now = scene
    scene.start
    scene.config_window.call_handler(:mod_settings)
    tell(tree, [])
    window = tree.last("window")
    hidden = Mod_Framework::UI::Engine::GameWindows::Hidden
    check("the Mods row opens the framework's window exactly over the options list, which hides and waits",
          [tree.nodes[window][:props]["at"], tree.nodes[window][:props]["size"], hidden.hidden?(scene.config_window), scene.config_window.active],
          [[0, 120], [640, 360], true, false])
    check("the scene holds nothing that answers no Object method, as the game's scripts walk its windows with is_a?",
          scene.instance_variables.reject { |name| Object === scene.instance_variable_get(name) }, [])
    mods, rows = both_lists(tree)
    check("the mods with options list on the left, the framework's own first, and the help names the mod under the cursor",
          [texts_of(mods).first, texts_of(mods).grep(/Level|Party/), scene.help_window.text],
          ["Mod Framework", ["Level Cap", "Party Sheet"], "The options and hotkeys of Mod Framework.\nConfirm to change them."])

    tell(tree, [[mods.node, "change", texts_of(mods).index("Level Cap")]])
    check("pointing at a mod shows its rows on the right at once, without their heading", texts_of(rows), ["Level Cap", "Write Now"])
    tell(tree, [[mods.node, "change", texts_of(mods).index("Party Sheet")]])
    check("pointing at another mod shows its rows at once and the help names it", [texts_of(rows), scene.help_window.text],
          [["Shown"], "The options and hotkeys of Party Sheet.\nConfirm to change them."])
    tell(tree, [[mods.node, "change", texts_of(mods).index("Level Cap")], [rows.node, "focus"]])
    check("the rows with the focus show the help of the row under the cursor in the game's help window alone, no help line under them",
          [scene.help_window.text, rows.parent.help], ["The cap.", nil])

    tell(tree, [[rows.node, "submit", 1]])
    check("a button row presses the handler a mod set as the screen started", $written, [:write])
    # A mod that shows a row of its own once the window of the button rows refreshes, as Party
    # Sheet shows its Shown Theme.
    $shown_row = { :key => :mod_shown, :name => "     -> Shown Theme", :sub => false, :help => "Shown." }
    Window_ModConfig.class_eval do
      alias_method :shown_refresh, :refresh
      define_method(:refresh) do
        at = NWConst::Config::MOD_CONTENTS.index { |row| row[:key] == :mod_write }
        NWConst::Config::MOD_CONTENTS.insert(at + 1, $shown_row) unless NWConst::Config::MOD_CONTENTS.include?($shown_row)
        shown_refresh
      end
    end
    tell(tree, [[rows.node, "side", 0, 1]])
    check("a value changed refreshes the mod's window before the rows, so a row it adds shows at once",
          [Mod_Framework::Options.value(:mod_cap), texts_of(rows)], [0, ["Level Cap", "Write Now", "Shown Theme"]])
    $cap_name = "[Level Cap] Level Cap Now"
    scene.refresh_mod_config
    tell(tree, [])
    check("refresh_mod_config reads the rows anew", texts_of(rows).first, "Level Cap Now")

    # A world greys Party Sheet's row for its players through a UI.patch of the rows.
    eval("Mod_Framework::UI.patch(\"#mf_mod_options\") { |t| t.rows(\"#mf_mod_options_list\") { |rows| " \
         "rows.map { |row| row[:key] == :mod_sheet ? row.merge(:disabled => true) : row } } }", TOPLEVEL_BINDING, "Patch/World_Rules.rb", 1)
    tell(tree, [[mods.node, "change", texts_of(mods).index("Party Sheet")]])
    before = Mod_Framework::Options.value(:mod_sheet)
    tell(tree, [[rows.node, "side", 0, 1]])
    check("a row a patch greys shows greyed with its help, and a step buzzes and keeps its value",
          [rows.rows[0][:disabled], scene.help_window.text, $sounds.last, Mod_Framework::Options.value(:mod_sheet)], [true, "Shows the sheet.", :buzzer, before])
    tell(tree, [[window, "close"]])
    check("closing gives the options back the keys, shown, and their help",
          [scene.config_window.active, hidden.hidden?(scene.config_window), scene.help_window.text], [true, false, "The options' row."])
  end
end

# The translation's tabbed options: the Mods tab opens the window over the tab's list.
in_game_folder do
  tree = FakeTree.new
  boot_tree(options_dll(tree), :game => game_with(true)) do
    $game_system = Struct.new(:conf, :window_tone).new({}, Tone.new)
    $written = []
    $opened_tabs = []
    $cap_name = "[Level Cap] Level Cap"
    add_rows
    frame
    scene = Scene_Config.new
    $scene_now = scene
    scene.start
    scene.config_window.tab = "General"
    scene.on_config_tab_ok
    scene.config_window.tab = "Mods"
    scene.on_config_tab_ok
    frame
    window = tree.last("window")
    hidden = Mod_Framework::UI::Engine::GameWindows::Hidden
    check("the Mods tab opens the window over the tab's list, whose items clear and hide while the tabs stay",
          [tree.nodes[window][:props]["at"], tree.nodes[window][:props]["size"], $cleared, hidden.hidden?(scene.item_window), hidden.hidden?(scene.config_window)],
          [[0, 168], [640, 312], true, true, false])
  end
end

# A mod made for Mod Config Remake asks Remake about the rows as it did: their groups, a row's name
# for a message, values, the key row a key is bound to, a help in the help window and a key held.
in_game_folder do
  tree = FakeTree.new
  dll = options_dll(tree)
  dll.answer("keys.names") { |codes| codes.map { |code| code.chr } }
  boot_tree(dll, :game => game_with(false)) do
    $game_system = Struct.new(:conf, :window_tone).new({ :mod_cap => 0 }, Tone.new)
    $cap_name = "[Level Cap] Level Cap"
    add_rows
    camp = { :key => :mod_camp_key, :name => "[Camp Notes] Open", :keybind => true, :value => lambda { 0x4A }, :help => "Opens the notes." }
    NWConst::Config::MOD_CONTENTS.insert(-2, camp)
    frame
    remake = ModConfigRemake
    row = lambda { |key| NWConst::Config::MOD_CONTENTS.find { |each| each[:key] == key } }
    groups = remake.groups.map { |mod, rows| [mod, rows.map { |each| each[:key] }] }
    check("the rows sort by mod as Remake sorted them, an indented row under the row above it",
          groups.select { |mod, _rows| ["Level Cap", "Party Sheet", "Camp Notes"].include?(mod) },
          [["Level Cap", [:mod_cap, :mod_write]], ["Party Sheet", [:mod_sheet]], ["Camp Notes", [:mod_camp_key]]])
    check("a row named for a message carries its mod in brackets, an indented row only its name",
          [remake.option_name(camp), remake.option_name(row.call(:mod_write))], ["Open (Camp Notes)", "Write Now"])
    check("a value reads from the save, its place among the row's values, and a key row's key from the mod",
          [remake.value_of(:mod_cap), remake.index_of(remake.values_of(row.call(:mod_cap)), 0), remake.entry_value(camp)], [0, 1, 0x4A])
    check("a key bound already names the row that has it, while that row asking about its own key finds none",
          [remake.key_owner(0x4A, nil)[:key], remake.key_owner(0x4A, camp)], [:mod_camp_key, nil])
    help = HelpStandIn.new
    remake.show_help(help, "One\r\nTwo\r\nThree\r\nFour\r\nFive")
    check("a help longer than the help window joins its last lines onto the window's last line", help.text, "One\nTwo\nThree\nFour Five")
    remake::Keys.down?(0x4A)
    $keys = { 0x4A => 1 }
    frame
    held = [remake::Keys.down?(0x4A), remake::Keys.down?(0x4C)]
    $keys = {}
    check("a key is named as the framework names it, and a key held reads as held", [remake::Keys.layout_name(0x4A), *held], ["J", true, false])
  end
end
