#----------------------------------------------------------------
#  options_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Covered the mods that have rows that show, the framework's own first, and the rows of one mod
#      Paulinchen  2026-11-04: Kept a few flows of the Mod Config rows and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the Mod Config rows
#      Paulinchen  2026-10-31: Covered a later row of a key in the earlier one's place and a key listed once
#      Paulinchen  2026-10-30: Covered the Mod Config the framework keeps itself, over a Mod Config Remake and
#                              without the DLL
#      Paulinchen  2026-10-29: Covered the value of a row the game keeps
#                            - Created
#
#----------------------------------------------------------------

# Covers options.rbx and the rows of mod_config.rbx in a booted game: Options > Mods the framework
# makes with the rows mods add, its rows over a Mod Config Remake, and without the DLL the rows the
# game's options can show lent to them.

require_relative "tree_support"

# A mod that sorts before the framework and puts its rows into the game's options, as mods made for
# the Mod Config Menu do while it is missing.
EARLY_MOD = <<-RUBY
  module NWConst::Config
    target = defined?(MOD_CONTENTS) ? MOD_CONTENTS : CONTENTS
    target.insert(-2, { :key => :mod_exp, :name => "[EXP] Settings", :sub => true, :help => "EXP." })
    target.insert(-2, { :key => :mod_exp_gold, :name => "     -> Gold", :sub => true, :help => "Gold." })
    DATA[:mod_exp] = [0, 1]
    DATA_TEXT[:mod_exp] = { 0 => { :name => "Off" }, 1 => { :name => "On" } }
  end
RUBY

# Mod Config Remake as far as the framework meets it: its rows unless another menu made them, its
# tab and its install.
REMAKE = <<-RUBY
  module ModConfigRemake
    TAB = "Mods"
    def self.install; $remake_installed = true; end
  end
  module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }] unless const_defined?(:MOD_CONTENTS); end; end
RUBY

# The options screen of the untranslated game, which runs a block as it starts.
SCENE = <<-RUBY
  class Scene_Config
    def start; end
  end
RUBY

# Defines the game's options, ending with Return, with the early mod in the Patch folder and a
# Mod Config Remake where asked.
#
# @param remake [Boolean] Whether Mod Config Remake is in the Patch folder.
# @return [Proc] What boot_tree runs before the mods load.
def game_with(remake)
  lambda do
    [:NWConst, :ModConfigRemake, :Scene_Config].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :bgm }, { :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; end; end")
    Object.class_eval(SCENE)
    put_mod("0_ModConfigRemake", REMAKE) if remake
    put_mod("EXP", EARLY_MOD)
  end
end

# Sorts rows' names by mod as C#'s OptionGroups does: "[Mod] Name" starts or joins that mod's group,
# an indented name joins the group above it, any other goes to Global, listed first while it has rows.
#
# @param names [Array<String>] The names.
# @return [Array<Array>] Each group's name with its rows' places and names.
def grouped_names(names)
  groups = [["Global", []]]
  current = "Global"
  names.each_with_index do |name, place|
    current = name =~ /\A\s*\[([^\]]+)\]/ ? $1.strip : (name =~ /\A(\s|->)/ ? current : "Global")
    groups << [current, []] unless groups.any? { |group, _rows| group == current }
    groups.find { |group, _rows| group == current }[1] << [place, name]
  end
  groups.reject { |_group, rows| rows.empty? }
end

# Lists the keys of rows.
#
# @param rows [Array<Hash>] The rows.
# @return [Array<Symbol>] Their keys.
def keys_of(rows)
  rows.map { |row| row[:key] }
end

# The framework makes Options > Mods and the rows mods add: one the game keeps in the save, one a
# mod keeps itself, and a later row of a key in the earlier one's place.
in_game_folder do
  dll = tree_dll(FakeTree.new)
  dll.answer("options.groups") { |names| grouped_names(names) }
  boot_tree(dll, :game => game_with(false)) do
    frame
    config = NWConst::Config
    options = Mod_Framework::Options
    check("a row of the game's options opens the Mod Config", keys_of(config::CONTENTS), [:bgm, :mod_settings, :return])
    check("rows mods put into the game's options before the framework are moved in", keys_of(config::MOD_CONTENTS).grep(/exp|return/), [:mod_exp, :mod_exp_gold, :return])
    options.add(:early_cap, "[Early] Cap", "Caps the level.", { 0 => ["Off", "No cap."], 1 => "On" }, 1)
    $kept = "Slow"
    options.keep(:early_speed, "[Early] Speed", "How fast.", lambda { ["Slow", "Fast"] }, lambda { $kept }, lambda { |value| $kept = value })
    speed = config::MOD_CONTENTS.find { |row| row[:key] == :early_speed }
    speed[:on_change].call("Fast")
    check("a row a mod keeps is written and read through the mod", speed[:value].call, "Fast")
    options.value(:early_cap)
    $game_system = Struct.new(:conf).new({ :early_cap => 0 })
    check("the player's pick in the save is the row's value", options.value(:early_cap), 0)
    $game_system = nil
    options.add(:early_cap, "[Early] Cap again", "", { 0 => "Off" }, 0)
    config::MOD_CONTENTS.insert(-2, { :key => :early_speed, :name => "[Late] Speed", :sub => true, :help => "" })
    check("a later row of a key takes the earlier one's place and a key put in twice lists once",
          options.rows.select { |row| [:early_cap, :early_speed].include?(row[:key]) }.map { |row| row[:name] }, ["[Early] Cap again", "[Late] Speed"])
    options.add(:early_debug, "[Early] Debug", "", { 0 => "Off" }, 0, :if => lambda { false })
    options.keep(:mf_test_row, "[Mod Framework] Test Row", "", lambda { ["On"] }, lambda { "On" }, lambda { |_value| })
    config::MOD_CONTENTS.insert(-2, { :key => :mf_key_test, :name => "[Mod Framework Hotkeys] Test", :keybind => true, :help => "" })
    check("the mods with rows that show list the framework and its hotkeys first, then the others in the order of their first rows",
          options.mods.select { |mod| ["Mod Framework", "Mod Framework Hotkeys", "EXP", "Early", "Late"].include?(mod) },
          ["Mod Framework", "Mod Framework Hotkeys", "EXP", "Early", "Late"])
    check("a mod's rows are those that start with its name and the indented rows under them, without one its :if hides",
          [keys_of(options.rows_of("exp")), keys_of(options.rows_of("Early"))], [[:mod_exp, :mod_exp_gold], [:early_cap]])
  end
end

# Without the DLL the game's options take the rows they can show as their screen starts, logging
# the others, and give back a row a mod hid since.
in_game_folder do
  boot_tree(tree_dll(FakeTree.new), :dll => false, :game => game_with(false)) do
    frame
    config = NWConst::Config
    Mod_Framework::Options.keep(:early_speed, "[Early] Speed", "How fast.", lambda { ["Slow"] }, lambda { "Slow" }, lambda { |_value| })
    Scene_Config.new.start
    check("without the DLL the game's options take the rows they can show", keys_of(config::CONTENTS), [:bgm, :mod_exp, :return])
    config::MOD_CONTENTS.reject! { |row| row[:key] == :mod_exp }
    Scene_Config.new.start
    check("a row a mod hid since is given back", keys_of(config::CONTENTS), [:bgm, :return])
  end
end

# Over a Mod Config Remake the framework keeps its rows and its menu gives way, while without the
# DLL the Remake keeps its menu.
[true, false].each do |dll|
  in_game_folder do
    boot_tree(tree_dll(FakeTree.new), :dll => dll, :game => game_with(true)) do
      frame
      ModConfigRemake.install
      check("over a Mod Config Remake the rows of mods loading before the framework are kept", keys_of(NWConst::Config::MOD_CONTENTS).grep(/exp/), [:mod_exp, :mod_exp_gold])
      check(dll ? "with the DLL the Remake's menu installs nothing" : "without the DLL the Remake keeps its menu", $remake_installed, dll ? nil : true)
    end
  end
end
