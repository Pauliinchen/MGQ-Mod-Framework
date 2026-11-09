#----------------------------------------------------------------
#  layer_hud_ease_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

# Covers a hud of the UI layer whose height changes (design v2 section 5.7) in a booted game against
# FakeTree, through a mod's boss strip: turned small, its column of rows eases from 86 to 36 pixels
# over the frames of its tween instead of jumping, keeping its newest rows, and lands there; a
# window's part takes a new height at once.

require_relative "layer_support"

BOSS_STRIP = <<-RUBY
  module Boss_Strip
    UI = Mod_Framework::UI

    class Strip < UI::Component
      state :small, false

      def render
        hud dock: :top, id: :boss_strip do
          stack tail: true, id: :boss_rows, height: small ? 36 : 86 do
            text "Black Dahlia trio"
            text "3,412,880 / 5,000,000"
          end
        end
      end
    end

    class Notes < UI::Component
      state :small, false

      def render
        window "Notes" do
          stack id: :note_rows, height: small ? 36 : 86 do
            text "Buy Herbs in Iliasburg"
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
    load_mod("Patch/Boss_Strip.rb", BOSS_STRIP)
    frame

    ui.show(Boss_Strip::Strip)
    frame
    Graphics.update
    strip = ui::Engine::Layer.tops.last.mount.component
    rows = ui::Engine::Tree.roots.last.find(:boss_rows)
    tree.rects[rows.node] = [0, 0, 640, 86]
    frame
    Graphics.update
    check("the strip's rows as it shows", tree.nodes[rows.node][:props]["size"], [nil, 86])

    # Turned small: a few frames on the height lies between, then lands on 36.
    strip.small = true
    frame
    3.times { frame; Graphics.update }
    between = tree.nodes[rows.node][:props]["size"][1]
    check("the rows' height three frames after the strip turned small lies between 86 and 36", between > 36 && between < 86, true)
    15.times { frame; Graphics.update }
    check("the rows' height once the strip eased", tree.nodes[rows.node][:props]["size"], [nil, 36])

    # A window's part takes its new height at once.
    ui.open(Boss_Strip::Notes)
    frame
    Graphics.update
    notes = ui::Engine::Layer.tops.last.mount.component
    note_rows = ui::Engine::Tree.roots.last.find(:note_rows)
    tree.rects[note_rows.node] = [0, 0, 200, 86]
    notes.small = true
    frame
    Graphics.update
    check("a window's part after its height changed", tree.nodes[note_rows.node][:props]["size"], [nil, 36])
  end
end
