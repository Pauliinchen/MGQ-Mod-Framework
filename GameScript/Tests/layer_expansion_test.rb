#----------------------------------------------------------------
#  layer_expansion_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers expansion_panels and expansion_panel of the UI layer (design v2 section 5.2) in a booted
# game against FakeTree, through a mod's camp guide: three panels of which one is open at a time,
# one bound to a state, one opened by its owner.

require_relative "layer_support"

CAMP_GUIDE = <<-RUBY
  module Camp_Guide
    UI = Mod_Framework::UI

    class Guide < UI::Component
      state :fire_open, false
      state :tents_open, true
      state(:told) { [] }

      def render
        window "Camp guide" do
          expansion_panels multi: false do
            expansion_panel "Fire", bind: :fire_open, id: :fire do
              text "Keep it small at night."
            end
            expansion_panel "Tents", note: "2 left", open: tents_open, id: :tents, on_fold: ->(open) { self.told = told + [open] } do
              text "Pitch them upwind."
            end
            expansion_panel "Water", id: :water do
              text "Boil it first."
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
    load_mod("Patch/Camp_Guide.rb", CAMP_GUIDE)
    frame

    ui.open(Camp_Guide::Guide)
    frame
    Graphics.update
    guide = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    fire, tents, water = [:fire, :tents, :water].map { |id| root.find(id) }
    shown = lambda { [fire, tents, water].map { |panel| panel.body.visible? } }
    check("the guide as it opens [titles, Tents' note, bodies shown, Fire's text in its body]",
          [[fire, tents, water].map { |panel| panel.head.children.first.text }, tents.head.children.last.text, shown.call, fire.body.children.first.text],
          [["▸ Fire", "▾ Tents", "▸ Water"], "2 left", [false, true, false], "Keep it small at night."])

    # A click on Fire's title opens it, writes its state and shuts Tents, which tells on_fold.
    tell(tree, [[fire.head.node, "click"]])
    check("Fire opened [bodies shown, Fire's state, Tents told]", [shown.call, guide.fire_open, guide.told], [[true, false, false], true, [false]])

    # The owner opens Tents anew through open:; the player's fold stays until then.
    guide.tents_open = false
    frame
    guide.tents_open = true
    frame
    Graphics.update
    check("Tents opened by its owner [bodies shown]", shown.call, [true, true, false])
  end
end
