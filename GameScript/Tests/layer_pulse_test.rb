#----------------------------------------------------------------
#  layer_pulse_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers pulse:, which every part of the UI layer takes (design v2 section 5.13, trade), in a booted
# game against FakeTree, through a mod's barter with Mia: her offer's box pulses once each time her
# offer changes, read from a state and from a live lambda, and never as it first shows; the box of
# the player's own offer stays still until it changes too, also when an item is added to it in place.

require_relative "layer_support"

BARTER = <<-RUBY
  module Camp_Barter
    UI = Mod_Framework::UI

    class Barter < UI::Component
      state(:theirs) { ["Herb"] }

      def render
        window "Barter with Mia" do
          stack row: true do
            paper id: :mine, pulse: -> { $mine } do
              text "You: " + $mine.join(", ")
            end
            paper id: :theirs, pulse: theirs do
              text "Mia: " + theirs.join(", ")
            end
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
    load_mod("Patch/Camp_Barter.rb", BARTER)
    $mine = ["Rope"]
    frame

    ui.open(Camp_Barter::Barter)
    frame
    Graphics.update
    barter = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    pulsed = []
    [:mine, :theirs].each do |id|
      box = root.find(id)
      box.define_singleton_method(:pulse) { |*_args| pulsed << id; super() }
    end
    4.times { frame }
    check("no pulse as the boxes first show", pulsed, [])

    # Mia adds a potion: her box pulses once, and not again while her offer stays.
    barter.theirs = ["Herb", "Potion"]
    frame
    4.times { frame }
    check("Mia's box after her offer changed", pulsed, [:theirs])

    # The player's own offer, read live, changes: their box pulses on the next read.
    $mine = ["Rope", "Torch"]
    4.times { frame }
    check("the own box after its live offer changed", pulsed, [:theirs, :mine])

    # The player adds flint to the same Array in place: their box pulses again.
    $mine << "Flint"
    4.times { frame }
    check("the own box after an item was added to its offer in place", pulsed, [:theirs, :mine, :mine])
  end
end
