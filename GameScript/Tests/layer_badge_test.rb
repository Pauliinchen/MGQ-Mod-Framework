#----------------------------------------------------------------
#  layer_badge_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the badge of the UI layer in a booted game against FakeTree, through a mod's letters
# button: the count of unread letters over the button's corner, which takes neither room nor the
# pointer and leaves once every letter is read, while the button stays pressable.

require_relative "layer_support"

LETTER_BADGE = <<-RUBY
  module Letter_Badge
    UI = Mod_Framework::UI

    class Letters < UI::Component
      state :unread, 2
      state :opened, 0

      def render
        window "Letters" do
          badge content: unread do
            button "Letters", on_click: -> { self.opened = opened + 1 }
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Letter_Badge.rb", LETTER_BADGE)
    frame

    ui.open(Letter_Badge::Letters)
    frame
    Graphics.update
    letters = ui::Engine::Layer.tops.last.mount.component
    button = nodes_of(tree, "button").last
    holder = tree.nodes[button][:parent]
    mark = tree.nodes[holder][:children].last
    props = tree.nodes[mark][:props]
    shown = lambda { [tree.nodes[mark][:props]["visible"], ui::Engine::Tree.component(mark).text] }
    check("the count lies over the button's corner, after it, without the pointer [corner, mouse, after the button]",
          [props["corner"], props["mouse"], tree.nodes[holder][:children].index(button) < tree.nodes[holder][:children].index(mark)], [true, false, true])
    check("two unread letters show 2", shown.call, [true, "2"])

    # The player reads every letter: the count leaves, and the button still takes its press.
    letters.unread = 0
    frame
    Graphics.update
    tell(tree, [[button, "click"]])
    check("no count once every letter is read, the button pressed [visible, opened]", [tree.nodes[mark][:props]["visible"], letters.opened], [false, 1])
  end
end
