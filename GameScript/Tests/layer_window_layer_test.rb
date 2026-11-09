#----------------------------------------------------------------
#  layer_window_layer_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

# Covers a window of the UI layer that rests under the game's windows while it holds no keys (design
# v2 section 6.5) in a booted game against FakeTree, through a mod's camp log: closed, its recent
# lines lie in the HUD band under the game's windows, without a frame, letting the pointer through;
# opened to type, it rises into the windows' band with its frame and takes the pointer on all of it;
# closed again, it rests under them once more.

require_relative "layer_support"

CAMP_LOG = <<-RUBY
  module Camp_Log
    UI = Mod_Framework::UI

    class CampLog < UI::Component
      state :open, false

      def render
        window nil, id: :camp_log, captures: :typing, frame: open, mouse: (open ? :all : :none), layer: (open ? :windows : :hud), width: 300 do
          text "Ana: wait at the inn", id: :camp_log_line
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Log.rb", CAMP_LOG)
    frame

    ui.open(Camp_Log::CampLog)
    frame
    Graphics.update
    log = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    look = lambda do
      props = tree.nodes[root.node][:props]
      options = root.instance_variable_get(:@options)
      [ui::BANDS[:hud].include?(props["z"]), options[:frame], props["mouse"], !options[:under_windows]]
    end

    # Closed: in the HUD band on the scene's pictures, under the game's windows, framed by nothing
    # and letting the pointer through.
    check("the log while closed [in the HUD band, framed, takes the pointer, over the game's windows]", look.call, [true, false, false, false])

    # Opened to type: in the windows' band with its frame, taking the pointer.
    log.open = true
    frame
    Graphics.update
    check("the log while open [in the HUD band, framed, takes the pointer, over the game's windows]", look.call, [false, true, true, true])
    check("the log's depth while open lies in the windows' band", ui::BANDS[:windows].include?(tree.nodes[root.node][:props]["z"]), true)

    # Closed again: back under the game's windows.
    log.open = false
    frame
    Graphics.update
    check("the log closed again", look.call, [true, false, false, false])
  end
end
