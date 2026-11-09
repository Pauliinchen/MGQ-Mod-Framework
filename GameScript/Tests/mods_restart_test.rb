#----------------------------------------------------------------
#  mods_restart_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that the game starts again as the last of the closing work, and a start that fails
#      Paulinchen  2026-11-04: Kept a few flows of the restart and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the restart
#      Paulinchen  2026-11-01: Wrote the lines of Mods.ini without the mark of a tag the player gave
#      Paulinchen  2026-10-30: Covered the action a mod has the restart on the way back to the title carry
#                            - Had the Title mod name the title calls, so it still loads whole
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_restart.rbx in a booted game: To Title after a Regular mod loaded starts the game
# again through the DLL as the game closes or, when it cannot start or without the DLL, asks the
# player to; and the load action a restart carried loads a save at the first title.

require_relative "game_lists_support"

# A Regular mod and a Title mod that takes an action after a restart.
MODS = {
  "Plain.rb" => "$order << 'Plain'\nMod_Framework::Run.on_close('Plain') { $order << 'Plain closed' }\n",
  "Menu.rb" => <<-RUBY
    $order << "Menu"
    Mod_Framework::Mods.after_restart("menu.open", "Menu") { |value| $opened << value }
    Mod_Framework::Mods.on_enter("Menu") { } if $menu_waits
  RUBY
}

# The order and tags of the mods, both on.
MODS_INI = "Menu=on Title\nPlain=on Regular\n"

# Shows a message box as the game's msgbox does, noting its text.
#
# @param text [String] The message.
def msgbox(text)
  $msgboxes << text
end

# Defines the game's scenes and SceneManager's ways between them as far as the restart follows
# them, and DataManager's ways into the game, counting the loads.
def define_scenes
  [:Scene_Load, :Scene_Map, :Scene_End, :Scene_Title, :Scene_Base].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
  Object.class_eval <<-RUBY
    class Scene_Base; def post_start; end; end
    class Scene_Title < Scene_Base; def command_new_game; DataManager.setup_new_game; end; end
    class Scene_Map < Scene_Base; end
    class Scene_End < Scene_Base; end
    class Scene_Load < Scene_Base; def on_load_success; SceneManager.goto(Scene_Map); end; end
    module DataManager
      def self.load_database; end
      def self.setup_new_game; end
      def self.load_game(index); $loads << index; true; end
    end
    module SceneManager
      @stack = []
      def self.scene; @scene; end
      def self.goto(scene_class); @scene = scene_class.new; end
      def self.call(scene_class); @stack.push(@scene); @scene = scene_class.new; end
      def self.return; @scene = @stack.pop; end
      def self.exit; @scene = nil; end
    end
  RUBY
  $order = []
  $opened = []
  $loads = []
  $msgboxes = []
end

# Boots a game folder holding the mods.
#
# @param dll [FakeBridge, nil] The DLL, nil for none.
# @param options [Hash] :ini (what Mods.ini holds, MODS_INI by default), :action (the action the
#   environment carries after a restart).
def boot_with_mods(dll, options = {})
  new_session
  define_game_lists
  define_scenes
  $dll = dll
  options[:action] ? ENV["MOD_FRAMEWORK_AFTER_RESTART"] = options[:action] : ENV.delete("MOD_FRAMEWORK_AFTER_RESTART")
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => !dll.nil?)
  File.write("Patch/Mod_Framework/Mods.ini", options[:ini] || MODS_INI)
  MODS.each { |path, code| File.write("Patch/#{path}", code) }
  run_patch_loader
end

# Makes the DLL, which starts the game again unless $start_fails.
#
# @return [FakeBridge] The DLL; $restarts takes each restart's request, and $order notes it.
def fake_dll
  fake = FakeBridge.new
  fake.build = "0.1.0"
  $restarts = []
  fake.answer("log.write") { |_request| nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |_request| {} }
  fake.answer("ini.write") { |_request| true }
  fake.answer("mods.restart") { |request| $restarts << request; $order << "restart"; { "started" => !$start_fails, "refused" => nil } }
  fake
end

# Enters the game by New Game from the title, has a mod carry an action, then goes back to the
# title the way To Title does.
#
# @param carry [Array, nil] The action's name and value, nil for none.
# @return [Proc] The scenes.
def to_title(carry = nil)
  lambda do
    SceneManager.goto(Scene_Title)
    SceneManager.scene.command_new_game
    Mod_Framework::Mods.carry_after_restart(*carry) if carry
    SceneManager.goto(Scene_End)
    SceneManager.goto(Scene_Title)
    $after_title = SceneManager.scene
  end
end

# To Title after a Regular mod loaded restarts the game with the action a mod has it carry.
in_game_folder do
  boot_with_mods(fake_dll)
  $scenes = to_title(["menu.open", "tab 3"])
  SceneManager.run
  check("the game starts again with the action, after the mods' closing work", [$restarts, $order.last(2), $msgboxes],
        [[{ "action" => "menu.open", "value" => "tab 3" }], ["Plain closed", "restart"], []])
  check("an action name with capitals and spaces is refused",
        begin
          Mod_Framework::Mods.restart("a mod", "Open Menu")
        rescue ArgumentError
          :refused
        end, :refused)
end

# A Game.exe that does not start leaves the start to the player.
in_game_folder do
  boot_with_mods(fake_dll)
  $start_fails = true
  $scenes = to_title
  SceneManager.run
  $start_fails = nil
  check("a game that does not start again asks for a restart by hand", $msgboxes, [Mod_Framework::Mods::Restart::BY_HAND_TEXT])
end

# Without the DLL (JoiPlay) a message asks the player to start the game again.
in_game_folder do
  boot_with_mods(nil)
  $scenes = to_title
  SceneManager.run
  check("without the DLL a message asks for a restart by hand", $msgboxes, [Mod_Framework::Mods::Restart::BY_HAND_TEXT])
end

# The load action a restart carried enters the game and loads the save.
in_game_folder do
  boot_with_mods(fake_dll, :action => "load:3")
  $scenes = lambda do
    SceneManager.goto(Scene_Title)
    SceneManager.scene.post_start
    $after_title = SceneManager.scene
  end
  SceneManager.run
  check("the load action loads the save and goes to the map", [$loads, $after_title.class], [[3], Scene_Map])
end
