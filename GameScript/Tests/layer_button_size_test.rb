#----------------------------------------------------------------
#  layer_button_size_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the sizes of a button of the UI layer in a booted game against FakeTree, through a mod's
# shop row: a small button beside a medium and a large one is lower and keeps less room around its
# text in a smaller font, the large one more in a larger font, as C#'s tree is told to lay them out.

require_relative "layer_support"

SHOP_ROW = <<-RUBY
  module Shop_Row
    UI = Mod_Framework::UI

    class Shop < UI::Component
      def render
        window "Shop" do
          stack row: true do
            button "Sell", size: :small, on_click: -> { nil }
            button "Buy", on_click: -> { nil }
            button "Leave", size: :large, on_click: -> { nil }
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
    load_mod("Patch/Shop_Row.rb", SHOP_ROW)
    frame

    ui.open(Shop_Row::Shop)
    frame
    Graphics.update
    buttons = nodes_of(tree, "button").map { |node| tree.nodes[node][:props] }
    heights = buttons.map { |props| props["row_height"] + props["padding"][0] + props["padding"][2] }
    sides = buttons.map { |props| props["padding"][3] }
    fonts = nodes_of(tree, "button").map { |node| ui::Engine::Tree.component(node).__send__(:text_px) }
    check("small, medium and large stand ever higher, with ever more room at their sides, in ever larger fonts [heights, sides, font px]",
          [heights, sides, fonts], [[22, 28, 34], [6, 8, 12], [16, 18, 20]])
  end
end
