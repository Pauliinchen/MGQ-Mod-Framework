#----------------------------------------------------------------
#  hotkeys_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Covered the remembered hotkeys forgotten once their mod loads without them
#      Paulinchen  2026-11-07: Typed through the framework's text box in place of a flag of another mod
#                            - Covered a kept key ignored once F1 binds cancel to it
#      Paulinchen  2026-11-06: Covered a hotkey left unbound whose default another hotkey holds
#                            - Covered a hotkey refused on a framework key and a key kept on one
#                            - Removed the answers of the old confirm model
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Kept a few flows of hotkeys defined, bound and pressed and checked each outcome on its own
#                            - Rewrote the checks as flow tests of hotkeys defined, bound and pressed
#                            - Covered a hotkey on a key of the game's extra buttons, which gives way to a screen of the
#                              game that uses the button
#                            - Expected the framework's jump hotkey's row
#      Paulinchen  2026-11-01: Covered the framework's hotkeys that move a mod in the Mods screen's list
#      Paulinchen  2026-10-31: Read the answer keys alone of a question asked
#      Paulinchen  2026-10-30: Covered the hotkeys of mods remembered and bound while their mods are not loaded
#                            - Covered the key rows in the framework's Mod Config in place of the plain rows
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# Covers hotkeys.rbx in a booted game against FakeTree: a mod defines its hotkeys as it loads, gets
# key rows in Options > Mods and its block runs on its scenes; a second definition and a taken key
# are refused and the player binds another key; the hotkeys stay quiet while a field types or a
# question box is open; a failing block; a hotkey on the game's Z gives way to a game screen that
# asks about Z; a default and a kept key on one of the framework's own keys, a hotkey whose default
# another hotkey holds and a kept key F1 binds cancel to later; the framework's own Options > Mods,
# the hotkeys of mods in Patch remembered while their mod is not loaded and forgotten once it loads
# without them, and nothing without the DLL.

require_relative "tree_support"

# The framework's ini in the standalone's folder.
INI = "Patch/Mod_Framework/Mod_Framework.ini"

# Windows' codes of K, J, L, P, D, V and Tab.
KEY_K = 0x4B
KEY_J = 0x4A
KEY_L = 0x4C
KEY_P = 0x50
KEY_D = 0x44
KEY_V = 0x56
KEY_TAB = 0x09

# A mod that defines its hotkeys as it loads: one that opens on the map, one whose block fails.
SAMPLE_MOD = <<-RUBY
  module SampleHotkeys
    @lines = []
    def self.log(line); @lines << line; end
    def self.lines; @lines; end
  end
  $opened = []
  Mod_Framework::Hotkeys.define(:sample_open, :key => 0x4B, :name => "[Sample] Open", :help => "Opens the sample.",
                                    :scenes => [Scene_Map], :log => SampleHotkeys) { $opened << :open }
  Mod_Framework::Hotkeys.define(:sample_broken, :key => 0x4C, :name => "[Sample] Broken", :log => SampleHotkeys) { raise "broken on purpose" }
RUBY

# A mod in Patch with a hotkey whose help has two lines.
CAP_MOD = <<-RUBY
  Mod_Framework::Hotkeys.define(:level_cap_open, :key => 0x4B, :name => "[Level Cap] Open", :help => "Opens the cap.\\nTwo lines.") { }
RUBY

# A mod in Patch that defines a hotkey a former game session remembered.
MAP_MOD = <<-RUBY
  Mod_Framework::Hotkeys.define(:map_display_open, :key => 0x4D, :name => "[Map Display] Open", :help => "Shows the map.") { }
RUBY

# The framework's settings an earlier game session left: two hotkeys of Sample_Hotkeys, which now
# defines only the first, one with a key bound for later, and one of Map_Display, which does not load.
EARLIER_SETTINGS = { "hotkey.sample_open" => "Sample_Hotkeys\t75\t75\t[Sample] Open\tOpens the sample.",
                     "hotkey.sample_dropped" => "Sample_Hotkeys\t71\t71\t[Sample] Dropped\t", "hotkey_bound.sample_dropped" => "80",
                     "hotkey.map_display_open" => "Map_Display\t77\t77\t[Map Display] Open\tShows the map." }

# Defines the game's scenes, its options ending with Return and the rows of Options > Mods, and puts
# the sample mod into the Patch folder.
#
# @param menu [Symbol] The menu of the mods' rows: :remake for Mod Config Remake's, :none for none,
#   so the framework makes its own.
# @return [Proc] What boot_tree runs before the mods load.
def game_with_menu(menu)
  lambda do
    [:NWConst, :ModConfigRemake, :Scene_Map, :Scene_Menu].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    Object.class_eval <<-RUBY
      class Scene_Map; end
      class Scene_Menu; end
      module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; end; end
    RUBY
    unless menu == :none
      Object.class_eval <<-RUBY
        module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
        module ModConfigRemake; def self.mod_stored?(entry); entry[:mod_stored] ? true : false; end; end
      RUBY
    end
    put_mod("Sample_Hotkeys", SAMPLE_MOD)
  end
end

# Presses a key for one frame and lets it go in the next.
#
# @param code [Integer] Windows' code of the key.
def press(code)
  $keys = { code => 3 }
  frame
  $keys = nil
  frame
end

# Finds a row of Options > Mods by its name.
#
# @param name [String] The name.
# @return [Hash, nil] The row.
def row(name)
  NWConst::Config::MOD_CONTENTS.find { |entry| entry[:name] == name }
end

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("keys.judge") do |code|
    next "framework" if code == KEY_TAB

    Mod_Framework::UI::Engine::Pad.keys(:B).include?(code) ? "keep" : "bind"
  end
  boot_tree(fake, :game => game_with_menu(:remake)) do
    hotkeys = Mod_Framework::Hotkeys
    ui = Mod_Framework::UI
    $sounds = []
    $scene_now = Scene_Map.new
    frame

    # A mod defines its hotkeys as it loads; the player presses one on its scene and on another.
    sample = row("[Sample] Open")
    check("a hotkey gets a key row before Return", [sample[:keybind], NWConst::Config::MOD_CONTENTS.last[:key]], [true, :return])
    press(KEY_K)
    frame
    $scene_now = Scene_Menu.new
    press(KEY_K)
    $scene_now = Scene_Map.new
    check("the block does not run on another scene", $opened, [:open])

    # A second definition and a taken key are refused; the player binds another key in the row.
    check("a second definition is refused", hotkeys.define(:sample_open, :key => KEY_J) { $opened << :again }, false)
    check("a key another hotkey keeps is refused", hotkeys.define(:sample_twin, :key => KEY_J, :setting => "key_accept") { $opened << :twin }, false)
    frame
    sample[:on_change].call(KEY_J)
    frame
    press(KEY_K)
    press(KEY_J)
    check("the bound key works from then on", $opened, [:open, :open])

    # The hotkeys stay quiet while a field types and while a question box is open.
    ui::Engine::TextEdit.open = :field
    press(KEY_J)
    ui::Engine::TextEdit.release(:field)
    ui::Engine::Confirm.ask("Leave?") { |_answer| }
    frame
    press(KEY_J)
    ui::Engine::Confirm.close
    2.times { frame }
    check("a hotkey stays quiet while a field types or a question box is open", $opened, [:open, :open])

    # A failing block is logged in the log of its mod.
    press(KEY_L)
    check("a failing block is logged in the log of its mod",
          SampleHotkeys.lines.grep(/the block of the hotkey sample_broken .* failed: RuntimeError: broken on purpose/).size, 1)

    # A hotkey on D, the game's Z, works until a screen of the game asks about Z (5fc6733f).
    sample[:on_change].call(KEY_D)
    frame
    press(KEY_D)
    check("a hotkey on D works while no screen uses Z", $opened.size, 3)
    2.times do
      Input.trigger?(:Z)
      press(KEY_D)
    end
    check("a hotkey on D gives way to a game screen that asks about Z", $opened.size, 3)
    check("the clash with the Z button is logged once", $logged.grep(/\[Sample\] Open\) ignored: the game's screen uses the game's Z button/).size, 1)

    # A mod hotkey never sits on a framework key: a default there is refused with the mod and the
    # hotkey named, and a key kept there gives way to the default.
    refused = hotkeys.define(:sample_tab, :key => "TAB", :name => "[Sample] Tab") { $opened << :tab }
    Mod_Framework::Settings.store("key_sample_broken", KEY_TAB.to_s)
    frame
    check("a framework key is refused as a default and ignored as a kept key",
          [refused, $logged.grep(/refused: sample_tab \(\[Sample\] Tab\) has Tab, one of the framework's own keys/).size, hotkeys.code(:sample_broken)],
          [false, 1, KEY_L])

    # A kept key refused while another hotkey holds the default leaves the hotkey unbound, so one
    # press never fires two hotkeys (the doubled F11 of 2026-11-06).
    Mod_Framework::Settings.store("key_sample_open", KEY_TAB.to_s)
    frame
    press(KEY_K)
    check("a hotkey whose kept key is refused while another hotkey holds its default stays unbound, logged once",
          [hotkeys.code(:sample_open), $opened.size,
           $logged.grep(/key_sample_open=9 is one of the framework's own keys and K, its default, is the key of \[Mod Framework Hotkeys\] Move Down, so sample_open stays unbound/).size],
          [0, 3, 1])

    # The player binds cancel to a hotkey's kept key in F1: the framework judges that key anew,
    # ignores it and the hotkey falls back to its default, logged, in the tree too.
    Mod_Framework::Settings.store("key_sample_broken", KEY_V.to_s)
    frame
    kept = hotkeys.code(:sample_broken)
    ui::Engine::Pad.assign("B" => [0x1B, 0x60, 0x2D, 0x58, KEY_V])
    frame
    fallen = [hotkeys.code(:sample_broken), hotkeys.for_tree["sample_broken"].first]
    frame
    check("a kept key F1 binds cancel to later is ignored, the hotkey falls back to its default, logged",
          [kept, fallen, $logged.grep(/key_sample_broken=86 is one of the framework's own keys, sample_broken keeps L/).size],
          [KEY_V, [KEY_L, KEY_L], 1])
  end
end

# Without Mod Config Remake the framework keeps its own Options > Mods; a hotkey of a mod in Patch
# is remembered, one the mod no longer defines is forgotten as it loads, and one whose mod is not
# loaded keeps a row whose key waits for the mod.
in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ini.read") { |(path)| $files[path] || (path == INI ? EARLIER_SETTINGS.dup : {}) }
  boot_tree(fake, :game => game_with_menu(:none)) do
    $scene_now = Scene_Map.new
    frame
    check("without Mod Config Remake the key rows go into the framework's own Mod Config", row("[Sample] Open")[:keybind], true)
    hotkeys = Mod_Framework::Hotkeys
    check("a hotkey its loaded mod no longer defines is forgotten with its key bound for later, logged, and a mod not loaded keeps its own",
          [$files[INI].keys.grep(/sample_dropped/), hotkeys.remembered_rows.map { |entry| entry[:name] },
           $logged.grep(/forgot \[Sample\] Dropped \(sample_dropped\) of Sample_Hotkeys/).size],
          [[], ["[Map Display] Open"], 1])
    eval(CAP_MOD, TOPLEVEL_BINDING, "Patch/Level_Cap.rb")
    frame
    check("a hotkey of a mod in Patch is remembered with its mod, key, default, name and help",
          $files[INI]["hotkey.level_cap_open"], "Level_Cap\t75\t75\t[Level Cap] Open\tOpens the cap.\\nTwo lines.")
    rows = hotkeys.remembered_rows { |mod| mod != "Other" }
    rows.first[:on_change].call(KEY_P)
    frame
    eval(MAP_MOD, TOPLEVEL_BINDING, "Patch/Map_Display.rb")
    frame
    check("a key bound there applies once the mod loads", hotkeys.code(:map_display_open), KEY_P)
  end
end

# Without the DLL the hotkeys are defined but fire nothing.
in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  boot_tree(fake, :dll => false, :game => game_with_menu(:remake)) do
    $scene_now = Scene_Map.new
    frame
    press(KEY_K)
    check("without the DLL a hotkey fires nothing", $opened, [])
  end
end
