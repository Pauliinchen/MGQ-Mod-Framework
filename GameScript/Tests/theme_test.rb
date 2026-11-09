#----------------------------------------------------------------
#  theme_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked a plugin's Options > Default that leaves the window's tone alone
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Dropped the game's windows left to an older MGQ Online
#      Paulinchen  2026-11-04: Kept a few flows of the looks a player picks and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the looks a player picks
#      Paulinchen  2026-10-28: Checked only the look rows beside MGQ Online 0.6.9
#                            - Moved into the Mod Framework from the theme part of ui_layout_test.rb
#                            - Checked each window dressed by its own theme
#                            - Checked the look kept in the framework's ini and its Mod Config rows
#                            - Checked the game's windows in Monarch without the DLL, nothing stored
#                            - Checked the game's windows left to an MGQ Online release that dresses them
#      Paulinchen  2026-10-24: Checked the Game's Default look and the game's windows wearing the look
#                            - Checked turning the look on the game's windows off
#      Paulinchen  2026-10-12: Counted the scrollbar track among the preset colors
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers theme.rbx in a booted game: the presets set in place on Style's colors and a pick kept in
# the framework's ini, the game's own look following the window color, the game's windows dressed or
# left alone, the window color kept for every save and the game's windows in Monarch without the
# DLL.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"

# The game's default window color.
GAME_TONE = [-34, 0, 68, 0]

# Boots the framework in the current game folder and runs the game's run step, with Mod Config
# Remake and a save's system in its default window color.
#
# @param fake [FakeBridge] The DLL's side.
# @param options [Hash] :dll (false for a copy without its DLL).
def boot_theme(fake, options = {})
  new_session
  Object.send(:remove_const, :NWConst) if defined?(NWConst)
  Object.class_eval <<-RUBY
    module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
  RUBY
  $dll = fake
  $game_system = Struct.new(:window_tone, :conf).new(Tone.new(*GAME_TONE), {})
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => options[:dll])
  run_patch_loader
  SceneManager.run
end

# Makes the DLL's side with an ini that $files keeps by path.
#
# @return [FakeBridge] The DLL's side.
def theme_dll
  fake = FakeBridge.new
  fake.build = "0.1.0"
  fake.answer("log.write") { |(_time, line)| $logged << line; nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |(path)| $files[path] || {} }
  fake.answer("ini.write") { |(path, values)| $files[path] = values; true }
  fake
end

# Mod Config Remake, which reads the value of a row a mod keeps.
module ModConfigRemake; def self.mod_stored?(entry); entry[:mod_stored] ? true : false; end; end

$logged = []
$files = {}
INI = "Patch/Mod_Framework/Mod_Framework.ini"

# Without the DLL the game's windows wear Monarch, and nothing is read, stored or offered.
in_game_folder do
  $files = { INI => { "ui_preset" => "Legacy", "ui_game_windows" => "0" } }
  fake = theme_dll
  boot_theme(fake, :dll => false)
  theme = Mod_Framework::UI::Engine::Theme
  window = Window_Base.new
  window.update
  check("without the DLL a game window wears Monarch untinted",
        [theme.current.name, window.windowskin.equal?(theme.skin), window.tone.to_a], ["Monarch", true, [0, 0, 0, 0]])
  $game_system.conf = { :tone_r => 10, :tone_g => -20, :tone_b => 30 }
  Graphics.update
  check("without the DLL no ini is read or written", fake.calls.map { |call| call[0] }.grep(/\Aini\./), [])
end

# The player picks the presets and the game's look, the windows each look dresses, and the window
# color kept for every save.
in_game_folder do
  $files = {}
  $logged = []
  boot_theme(theme_dll)
  theme = Mod_Framework::UI::Engine::Theme
  style = Mod_Framework::UI::Engine::Style

  # A preset sets Style's colors in place, an unknown name takes the first, and the look row keeps a
  # pick in the ini.
  back = style::BACK
  theme.apply("legacy", "a test")
  check("a preset sets Style's colors in place", [style::BACK.equal?(back), back.to_a], [true, [0, 0, 0, 170]])
  theme.apply("Nonsense", "a test")
  check("an unknown name takes the first preset", theme.current.name, "Monarch")
  look = NWConst::Config::MOD_CONTENTS.find { |row| row[:key] == theme::OPTION }
  look[:on_change].call("Legacy")
  Graphics.update
  check("a pick in the look row is kept in the ini", [look[:value].call, $files[INI]["ui_preset"]], ["Legacy", "Legacy"])

  # The game's look takes the skin's background in the window color and colors the boxes anew on the
  # frame after the window color changed.
  theme.apply("game's default", "a test")
  serial = theme.serial
  $game_system.window_tone = Tone.new(40, 0, 0, 0)
  Graphics.update
  check("a changed window color colors the boxes anew", [style::BACK.to_a, theme.serial - serial], [[100, 60, 60, 192], 1])
  $game_system.window_tone = Tone.new(*GAME_TONE)
  Graphics.update

  # A game window wears the look, until Look on Game Windows Off gives it the game's look back.
  game_window = Window_Base.new
  theme.apply("Monarch", "a test")
  game_window.update
  check("with a preset a game window wears its skin untinted, keeping its opacity",
        [game_window.windowskin.equal?(theme.skin), game_window.tone.to_a, game_window.back_opacity], [true, [0, 0, 0, 0], 192])
  theme.dress_game_windows(false)
  game_window.update
  Graphics.update
  check("Look on Game Windows Off gives a game window the game's look back",
        [game_window.windowskin.equal?(Cache::SKIN), game_window.tone.to_a], [true, GAME_TONE])
  theme.dress_game_windows(true)

  # The window color the player sets in the game's options holds for every save.
  $game_system.conf = { :tone_r => 10, :tone_g => -20, :tone_b => 30 }
  $game_system.window_tone = Tone.new(10, -20, 30, 0)
  2.times { Graphics.update }
  check("the color set in the options is kept in the ini", $files[INI]["window_color"], "10,-20,30")
  $game_system.conf = { :tone_r => -34, :tone_g => 0, :tone_b => 68 }
  $game_system.window_tone = Tone.new(*GAME_TONE)
  DataManager.load_game_without_rescue(1)
  check("another save shows the kept color", $game_system.window_tone.to_a.first(3), [10, -20, 30])

  # The translation's Options > Default sets the options' values back without putting the color on.
  { :tone_r => -34, :tone_g => 0, :tone_b => 68 }.each { |key, value| $game_system.conf[key] = value }
  2.times { Graphics.update }
  check("a plugin's Options > Default puts the default color on and keeps it",
        [$game_system.window_tone.to_a.first(3), $files[INI]["window_color"]], [GAME_TONE.first(3), "-34,0,68"])
end
