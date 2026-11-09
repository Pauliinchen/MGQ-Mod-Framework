#----------------------------------------------------------------
#  layer_join_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Covered a screen the box opens, which hides the box and the commands until it closes
#                            - Created
#
#----------------------------------------------------------------

# Covers a window of the UI layer joined to the game window it lies beside (design v2 sections 5.1
# and 6.4) in a booted game against FakeTree, through a mod's box beside the title's commands: Left
# hands the box the keys and hides the commands' cursor, which keeps its place; the arrow back
# hands them back; cancel does what it does on the title, nothing, and the box stays; a screen the
# box opens hides the box and the commands until it closes, and the box then takes the keys back on
# the row that opened it.

require_relative "layer_support"
require_relative "game_lists_support"

TITLE_BOX = <<-RUBY
  module Camp_Title
    UI = Mod_Framework::UI

    class ModsBox < UI::Component
      state :picked

      def render
        window "Mods", beside: "Window_TitleCommand", side: :left, join: true do
          list ["Browser", "List"], bind: :picked, on_submit: ->(_page) { $screen = UI.open(ModList) }
        end
      end
    end

    class ModList < UI::Component
      def render
        window "Mods" do
          text "Level Cap"
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Title.rb", TITLE_BOX)
    title = Window_TitleCommand.new
    title.openness = 255
    title.select(1)
    $scene_now = Struct.new(:command_window).new(title)
    $scene_now.instance_variable_set(:@command_window, title)
    frame

    handle = ui.open(Camp_Title::ModsBox)
    frame
    Graphics.update
    box = ui::Engine::Tree.roots.last
    list = box.children.first
    step = lambda do |pressed, states = nil, events = nil|
      tree.post("states", states) if states
      tree.post("events", events) if events
      frame(pressed)
      title.update
    end
    check("the joined box waits without holding the game's buttons", tree.nodes[box.node][:props]["captures"], false)

    # Left hands the box the keys; the commands wait without a cursor and keep their place.
    step.call([:LEFT])
    step.call([])
    check("Left asked C# to focus inside the box and took the commands' input", [tree.changes.reverse.find { |change| change.key?("focus_in") }["focus_in"], title.active],
          [box.node, false])
    step.call([], list.node => ui::Engine::Tree::FOCUSED)
    step.call([])
    check("the box holds the keys, the commands show no cursor and keep their place", [box.captures, title.cursor_rect.width, title.index], [true, 0, 1])

    # Cancel does what it does on the title, nothing, and the box stays open.
    tree.post("events", [[box.node, "cancel"]])
    step.call([])
    check("cancel keeps the box open", handle.open?, true)

    # Right, the arrow back, hands the keys back with the cursor where it was.
    step.call([], nil, [[box.node, "leave", "right"]])
    step.call([])
    check("Right gave the commands the input back with their cursor", [title.active, title.cursor_rect.width > 0, title.index, box.captures], [true, true, 1, false])

    # List opens a screen: the box and the commands hide until it closes, and the box then takes the
    # keys back on List.
    step.call([:LEFT])
    step.call([], list.node => ui::Engine::Tree::FOCUSED)
    step.call([], nil, [[list.node, "change", 1], [list.node, "submit", 1]])
    step.call([])
    check("the screen hides the box and the commands", [$screen.open?, title.visible, tree.nodes[box.node][:props]["visible"]], [true, false, false])
    $screen.close
    step.call([])
    step.call([])
    check("as it closes both show again and the box is asked to take the focus",
          [title.visible, tree.nodes[box.node][:props]["visible"], tree.changes.reverse.find { |change| change.key?("focus_in") }["focus_in"]], [true, true, box.node])
    step.call([], list.node => ui::Engine::Tree::FOCUSED)
    step.call([])
    check("the box holds the keys again on List, the commands waiting", [box.captures, title.active, list.index], [true, false, 1])
  end
end
