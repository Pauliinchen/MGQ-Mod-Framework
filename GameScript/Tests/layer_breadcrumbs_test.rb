#----------------------------------------------------------------
#  layer_breadcrumbs_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that the place shown keeps the room a link keeps at its sides
#                            - Created
#
#----------------------------------------------------------------

# Covers breadcrumbs of the UI layer (design v2 section 5.4) in a booted game against FakeTree,
# through a mod's gear page: the way Menu / Equip / the character, whose links tell their data as
# they are followed while the character shown takes no focus, and a way that grows as the page
# goes deeper.

require_relative "layer_support"

GEAR_PAGE = <<-RUBY
  module Gear_Page
    UI = Mod_Framework::UI

    class Page < UI::Component
      state :slot, nil
      state(:followed) { [] }

      def render
        window "Gear" do
          way = [{ text: "Menu", data: :menu }, { text: "Equip", data: :equip }, { text: "Luka" }]
          way << { text: slot } if slot
          breadcrumbs items: way, on_click: ->(place) { self.followed = followed + [place] }
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Gear_Page.rb", GEAR_PAGE)
    frame

    ui.open(Gear_Page::Page)
    frame
    Graphics.update
    page = ui::Engine::Layer.tops.last.mount.component
    way = lambda { ui::Engine::Tree.roots.last.children.last.children.map { |part| [part.class.name.split("::").last, part.text] } }
    check("the way as it opens [part, text]", way.call,
          [["Button", "Menu"], ["Label", "/"], ["Button", "Equip"], ["Label", "/"], ["Label", "Luka"]])
    parts = ui::Engine::Tree.roots.last.children.last.children
    sides = lambda { |part| part.send(:padding_sides).values_at(1, 3) }
    check("the place shown keeps the room a link keeps at its sides, so each separator stands as far from both [link, place shown]",
          [sides.call(parts.first), sides.call(parts.last)], [sides.call(parts.first)] * 2)

    # Following Equip tells its data; following Luka is no click, as Luka is the place shown.
    equip = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    tell(tree, [[equip.node, "click"]])
    check("Equip followed [told]", page.followed, [:equip])

    # Going deeper adds a place: Luka turns into a link that tells its text.
    page.slot = "Weapon"
    frame
    Graphics.update
    check("the way one place deeper [part, text]", way.call.last(3), [["Button", "Luka"], ["Label", "/"], ["Label", "Weapon"]])
    luka = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    tell(tree, [[luka.node, "click"]])
    check("Luka followed [told]", page.followed, [:equip, "Luka"])
  end
end
