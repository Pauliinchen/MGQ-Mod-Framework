#----------------------------------------------------------------
#  scenes_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Dropped the checks of the old replace_scene with a block
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Checked the outcomes of each step of a replaced scene together
#                            - Rewrote the checks as flow tests of a replaced scene
#                            - Loaded the engine script before the scenes script
#      Paulinchen  2026-11-01: Covered telling whether the menu scene of a mod's screen shows
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# Covers the menu scene of scenes.rbx: a root opened with :menu outside a menu scene opens in the
# framework's own menu scene, which UI.menu_screen? tells apart. layer_game_windows_test.rb covers
# UI.replace_scene.

require_relative "support"

$log = []

# The game's base scene, which notes that it returned.
class Scene_Base
  def return_scene; $returned << self; end
end

# The game's menu scene, which picks the menu's character as it starts.
class Scene_MenuBase < Scene_Base
  def start; @actor = $menu_actor; end
end

# The game's equip screen.
class Scene_Equip < Scene_MenuBase; end

# The game's scene manager, whose call and goto both make the scene running a new one of a class.
module SceneManager
  class << self; attr_reader :scene; end
  def self.call(scene_class); @scene = scene_class.new; end
  def self.goto(scene_class); @scene = scene_class.new; end
end

# A root as a mod's window is one: it opens and names itself for the log.
class FakeRoot
  def initialize; @open = false; end
  def open?; @open; end
  def open; @open = true; end
  def describe; "a fake root"; end
end

load_scripts "logging", "hooks", "engine", "scenes"
Mod_Framework::Log.define_singleton_method(:write) { |line| $log << line }
ui = Mod_Framework::UI

$menu_actor = :alice
$returned = []

# A mod opens its root with :menu over the equip screen.
SceneManager.call(Scene_Equip)
before_root = ui.menu_screen?
ui::Engine::Scenes.open_in_menu(FakeRoot.new)
SceneManager.scene.start
check("UI.menu_screen? tells the menu scene of a root opened with :menu", [before_root, ui.menu_screen?, ui.menu_screen?(Scene_MenuBase.new)], [false, true, false])
