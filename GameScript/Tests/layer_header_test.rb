#----------------------------------------------------------------
#  layer_header_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked a chip right after the name and its mark, also in one row
#      Paulinchen  2026-11-07: Checked that a header with a compact form sends its forms, the dense one second
#                            - Checked a star at the end of the title's row, after the line once dense
#      Paulinchen  2026-11-06: Checked that a dense header asks for the room of its name and its line whole
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers header of the UI layer in a booted game against FakeTree, through a mod's party card: a
# party member's icon, name in a game text color, an element as a mark with its tooltip, a chip of
# two elements right after them, the line under the name with a button after it, a star at the end
# of the name's row, a click on the header, and the same header in one row, as wide as its name and
# its line whole, the chip after the mark and the star after the line;
# an empty slot's header keeps its icon's room, a header without an icon has none; a header with a
# dense compact form goes to C#'s tree as its forms.

require_relative "layer_support"

CARD = <<-RUBY
  module Party_Card
    UI = Mod_Framework::UI

    class CardWindow < UI::Component
      state :dense, false
      state :clicks, 0

      def render
        window "Party" do
          header "Luka", title_color: 2, icon: 7, subtitle: "Hero", marks: [{ icon: 104, tooltip: "Holy" }], dense: dense,
                         title_after: -> { chip_set { chip icons: [96, 97], tooltip: "Fire, Ice" } }, note: -> { button "Status", on_click: -> {} },
                         trailing: -> { icon 87 }, on_click: -> { self.clicks += 1 }
          header "Nothing equipped", title_color: :dim, icon: nil
          header "Camp"
          header "Inn", subtitle: "Rest", compact: { 1 => { dense: true } }
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Party_Card.rb", CARD)
    frame

    # Luka's card: the icon, the name in its color, the mark after it and the line with Status after it.
    ui.open(Party_Card::CardWindow)
    frame
    window = ui::Engine::Layer.tops.last.mount.component
    card, empty, plain = nodes_of(tree, "stack").map { |node| ui::Engine::Tree.component(node) }.select { |part| part.is_a?(ui::Engine::Header) }
    texts = lambda { |part| part.respond_to?(:text) ? [part.text] : part.children.map { |child| texts.call(child) }.flatten }
    marks = card.title_row.children.select { |part| part.is_a?(ui::Engine::Icon) }.map { |icon| [icon.icon, icon.tooltip] }
    check("the card shows the icon, the name in its color, the mark and the line with Status after it",
          [card.icon_part.icon, card.title_label.text, card.title_label.color, marks, texts.call(card.subtitle_row)], [7, "Luka", 2, [[104, "Holy"]], ["Hero", "Status"]])

    star = lambda { |row| row.children.last.children.map { |part| part.is_a?(ui::Engine::Icon) ? part.icon : nil } }
    chip = lambda { |row| row.children[2].children.first.chip(0) }
    check("the chip of the elements follows the name and its mark, and the star ends the name's row, pushed there by room that grows",
          [chip.call(card.title_row).instance_variable_get(:@options)[:icons], star.call(card.title_row), card.title_row.children[-2].grow], [[96, 97], [87], 1])

    # A click on the card tells on_click.
    tell(tree, [[card.node, "click"]])
    check("a click on the header tells on_click", window.clicks, 1)

    # Dense, the line and Status follow the name in one row.
    window.dense = true
    frame
    card = nodes_of(tree, "stack").map { |node| ui::Engine::Tree.component(node) }.find { |part| part.is_a?(ui::Engine::Header) && part.compact }
    check("a dense header holds the chip after the mark, the line and Status in the name's row, the star right after them",
          [chip.call(card.title_row).instance_variable_get(:@options)[:icons], card.subtitle_row.parent.equal?(card.title_row), texts.call(card.subtitle_row),
           card.title_row.children[-2].equal?(card.subtitle_row), star.call(card.title_row)],
          [[96, 97], true, ["Hero", "Status"], true, [87]])
    small = ui::Engine::LabelCache.width("Hero", ui.font_px(:small))
    large = ui::Engine::LabelCache.width("Luka", ui.font_px(:large))
    check("a dense header asks for the room of its name and its line whole", tree.nodes[card.node][:props]["measured"][0] >= large + small, true)

    # The empty slot keeps the icon's room; the plain header has none.
    forms = nodes_of(tree, "stack").find { |node| tree.nodes[node][:props]["forms"] }
    inn = tree.nodes[forms][:children].map { |node| ui::Engine::Tree.component(node) }
    check("a header with a compact form goes to the tree as its forms, the dense header from step 1",
          [tree.nodes[forms][:props]["forms"], inn.map { |header| [header.title_label.text, header.compact] }], [[0, 1], [["Inn", false], ["Inn", true]]])
    check("an icon given as nil keeps its room, none given leaves it out", [!empty.icon_part.nil?, empty.icon_part && empty.icon_part.icon, plain.icon_part], [true, nil, nil])
  end
end
