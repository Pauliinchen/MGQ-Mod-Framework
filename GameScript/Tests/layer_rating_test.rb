#----------------------------------------------------------------
#  layer_rating_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Told the rating its stars as C#'s tree tells them, which fills them by the arrows and a click
#                            - Created
#
#----------------------------------------------------------------

# Covers rating of the UI layer (design v2 section 5.3) in a booted game against FakeTree, through
# a mod's dash box: the dash speed as three stars bound to a state, which C#'s tree fills by the
# arrows and a click and tells each new count of, and a second rating that only shows the speed,
# a part without an action the tree leaves alone.

require_relative "layer_support"

DASH_BOX = <<-RUBY
  module Dash_Box
    UI = Mod_Framework::UI

    class DashWindow < UI::Component
      state :speed, 1
      state(:told) { [] }

      def render
        window "Dash" do
          rating "Dash Speed", bind: :speed, max_value: 3, on_change: ->(stars) { self.told = told + [stars] }
          rating value: speed, max_value: 3, read_only: true, size: :small
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Dash_Box.rb", DASH_BOX)
    frame

    ui.open(Dash_Box::DashWindow)
    frame
    Graphics.update
    dash = ui::Engine::Layer.tops.last.mount.component
    speed, shown = nodes_of(tree, "slider").map { |node| ui::Engine::Tree.component(node) }
    check("the stars as they open [filled, shown filled, the stars and cell the tree picks by, the shown one acts]",
          [speed.value, shown.value, tree.nodes[speed.node][:props].values_at("number_max", "cells"), tree.nodes[shown.node][:props]["acts"]],
          [1, 1, [3, 26], false])

    # The tree tells the stars filled, as Right or a click filled them: the state, on_change and the
    # rating that only shows them follow.
    tell(tree, [[speed.node, "number", 3]])
    check("the stars after the tree told 3 [state, told, the shown one]", [dash.speed, dash.told, shown.value], [3, [3], 3])
    tell(tree, [[speed.node, "number", 0]])
    check("the stars after the tree told 0, as a click on the last filled star empties them", [dash.speed, dash.told], [0, [3, 0]])
  end
end
