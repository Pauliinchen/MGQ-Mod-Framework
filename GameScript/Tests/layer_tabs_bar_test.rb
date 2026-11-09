#----------------------------------------------------------------
#  layer_tabs_bar_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers tabs pages: false with enter: (design v2 sections 5.6 and 5.13, trade) in a booted game
# against FakeTree, through a mod's barter: a bar of kinds beside a Gold button over the bag the
# picked kind fills; a click on a kind picks it and hands the focus to the bag, which C#'s tree
# then treats as the bar's panel, so cancel there walks back to the kind (TreeCancelTests cover the
# walk back from a page).

require_relative "layer_support"

BAG_BAR = <<-RUBY
  module Camp_Bag
    UI = Mod_Framework::UI

    class Bag < UI::Component
      state :kind, :items

      def render
        window "Barter with Mia" do
          stack row: true do
            tabs pages: false, enter: true, bind: :kind do
              tab "Items", id: :items
              tab "Weapons", id: :weapons
            end
            button "Gold", on_click: -> { }
          end
          list kind == :items ? ["Herb", "Rope"] : ["Sword"], id: :bag
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Bag.rb", BAG_BAR)
    frame

    ui.open(Camp_Bag::Bag)
    frame
    Graphics.update
    bag = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    list = root.find(:bag)
    weapons = ui::Engine::Tree.component(nodes_of(tree, "tabs").last).tab(1).node
    check("the bag before a kind is picked [tab_page sent]", tree.nodes[list.node][:props].key?("tab_page"), false)

    # A click on Weapons picks it, fills the bag and hands the focus to it, marked as the bar's panel.
    tell(tree, [[weapons, "click"]])
    frame
    Graphics.update
    asked = tree.changes.map { |changes| changes["focus_in"] }.compact.last
    check("Weapons picked [state, rows, the focus asked into the bag, the bag the bar's panel]",
          [bag.kind, list.rows, asked, tree.nodes[list.node][:props]["tab_page"]], [:weapons, ["Sword"], list.node, true])
  end
end
