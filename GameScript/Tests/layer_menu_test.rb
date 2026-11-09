#----------------------------------------------------------------
#  layer_menu_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that a camp closed before its menu scene starts never opens
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers window menu: of the UI layer (design v2 section 5.1) in a booted game against FakeTree,
# through a mod's camp: opened on the map, the camp waits for a menu scene of its own, opens as that
# scene starts, and the game goes back as it closes; opened inside a menu, it opens in place;
# closed before its menu scene starts, it never opens.

require_relative "layer_support"

MENU_CAMP = <<-RUBY
  module Menu_Camp
    UI = Mod_Framework::UI

    class Camp < UI::Component
      def render
        window "Camp", id: :menu_camp, menu: true, movable: false do
          text "The fire burns low."
          button "Rest", id: :rest, on_click: :close
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    Object.class_eval <<-RUBY
      class Scene_MenuBase < Scene_Base
        def start; end
        def return_scene; $returned << self; end
      end
    RUBY
    SceneManager.define_singleton_method(:call) { |klass| $scene_now = klass.new }
    $returned = []
    load_mod("Patch/Menu_Camp.rb", MENU_CAMP)
    frame

    # On the map: the game calls a menu scene, and the camp waits for it.
    told = []
    camp = ui.open(Menu_Camp::Camp) { |_value, why| told << [:camp, why] }
    menu = $scene_now
    check("the camp waiting for its menu scene [a menu scene called, handle open?, its window open?]",
          [ui.menu_screen?(menu), camp.open?, ui::Engine::Layer.tops.last.root.engine.open?], [true, true, false])

    # The scene starts and opens the camp; Rest closes it and the game goes back to the map.
    menu.start
    frame
    Graphics.update
    root = ui::Engine::Tree.roots.last
    check("the camp in its menu scene [open, title]", [root.open?, root.title], [true, "Camp"])
    tell(tree, [[root.find(:rest).node, "click"]])
    check("Rest closed the camp [why, the scene went back]", [told.last, $returned], [[:camp, :button], [menu]])

    # Inside a menu it opens in place: no other scene is called.
    $scene_now = Scene_MenuBase.new
    inside = $scene_now
    again = ui.open(Menu_Camp::Camp)
    frame
    Graphics.update
    check("the camp opened inside a menu [open?, the same scene, shown]", [again.open?, $scene_now.equal?(inside), ui::Engine::Tree.roots.last.open?], [true, true, true])

    # Closed on the map before its menu scene starts, the camp never opens and the scene goes back.
    again.close
    frame
    $scene_now = :map
    $returned = []
    cancelled = []
    early = ui.open(Menu_Camp::Camp) { |_value, why| cancelled << why }
    early.close
    late = $scene_now
    late.start
    frame
    check("a camp closed before its menu scene starts [why, handle open?, the scene went back]",
          [cancelled, early.open?, $returned], [[:script], false, [late]])
  end
end
