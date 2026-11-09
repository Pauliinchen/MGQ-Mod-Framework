#----------------------------------------------------------------
#  layer_paper_click_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that the box turned plain is no key stop
#                            - Created
#
#----------------------------------------------------------------

# Covers a paper of the UI layer that is one part pressed by confirm or a click (design v2 section
# 5.2) in a booted game against FakeTree, through a mod's camp page: a box of the party that opens
# the party's list, pressed as C#'s tree tells it; and the same box no longer pressed once the party
# is empty and the box turned plain, no key stop any more. C#'s tree routes confirm and the click to it (TreeFocusTests).

require_relative "layer_support"

CAMP_PAGE = <<-RUBY
  module Camp_Page
    UI = Mod_Framework::UI

    class Page < UI::Component
      state(:party) { ["Luka", "Alice"] }
      state(:opened) { [] }

      def render
        window "Camp" do
          paper clickable: !party.empty?, id: :party_box, on_click: -> { self.opened = opened + [:party] } do
            text "Party", id: :party_title
            text party.empty? ? "Nobody" : party.join(", "), id: :party_names
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
    load_mod("Patch/Camp_Page.rb", CAMP_PAGE)
    frame

    ui.open(Camp_Page::Page)
    frame
    Graphics.update
    page = ui::Engine::Layer.tops.last.mount.component
    box = ui::Engine::Tree.roots.last.find(:party_box)

    # C# learns one key stop clicked as a whole; confirm on it, as C#'s tree tells it, opens the party.
    check("C# learns the box [clickable, focusable]", tree.nodes[box.node][:props].values_at("clickable", "focusable"), [true, true])
    tell(tree, [[box.node, "click"]])
    check("the box pressed opens the party", page.opened, [:party])

    # The party leaves: the box turns plain and takes no keys.
    page.party = []
    frame
    Graphics.update
    check("the box of an empty party [clickable, focusable, names]",
          tree.nodes[box.node][:props].values_at("clickable", "focusable") + [ui::Engine::Tree.roots.last.find(:party_names).text], [false, false, "Nobody"])
  end
end
