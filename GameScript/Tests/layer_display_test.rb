#----------------------------------------------------------------
#  layer_display_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that the socket's tooltip lies at the window's left where the right has no room
#      Paulinchen  2026-11-06: Checked that the socket's tooltip at its right clears the window's frame and shows its lines whole
#                            - Called the engine's classes by their names under UI::Engine
#                            - Covered the camp's icons, one by the name the mod gave it
#      Paulinchen  2026-11-05: Covered the tooltip's see-through plate under its whole text
#      Paulinchen  2026-11-04: Covered a socket's tooltip of markup
#                            - Covered the camp's line drawn with the game's codes on a plate
#                            - Covered the rules that part a party card
#                            - Created
#
#----------------------------------------------------------------

# Covers the display parts of the UI layer (design v2 section 5.4) in a booted game against
# FakeTree, through a mod's party card: the character's art cut to fill its room from the top, a
# click on it that picks the character, the rules that part the card, the camp's icons, and a
# socket's tooltip at its right, beyond the window's frame and as wide as its lines.

require_relative "layer_support"
require_relative "equip_support"

CARD = <<-RUBY
  module Party_Card
    UI = Mod_Framework::UI
    UI.icon :party_card_camp, 191

    class CardWindow < UI::Component
      param :actor
      state :picked

      def render
        window "Party" do
          image portrait: actor, fit: :cover, anchor: :top, height: 120, on_click: -> { self.picked = actor }
          divider color: :gold, thickness: 2
          image file: "Graphics/Pictures/camp", label: -> { "Night \#{3}" }
          stack row: true do
            icon :party_card_camp, size: :large
            icon 12, size: 20
          end
          stack row: true do
            button "Rest", on_click: -> {}
            divider vertical: true
            button "Leave", on_click: -> {}
          end
          tooltip side: :right, content: -> { text "Ruby"; text "ATK +120", typo: :caption } do
            button "Socket 1", on_click: -> {}
          end
          text "\\\\C[2]Hot\\\\C[0] stew tonight", escapes: true, plate: true, align: :center, most_lines: :fill
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    luka = equip_party
    load_mod("Patch/Party_Card.rb", CARD)
    frame

    # The card shows Luka's art cut from the top; a click on it picks him.
    ui.open(Party_Card::CardWindow, actor: luka)
    frame
    card = ui::Engine::Layer.tops.last.mount.component
    art, camp = nodes_of(tree, "picture").map { |node| ui::Engine::Tree.component(node) }
    check("the art shows the character, cut to fill its room from the top",
          art.instance_variable_get(:@options).values_at(:portrait, :fit, :anchor) + camp.instance_variable_get(:@options).values_at(:file, :label), [luka, :cover, :top, "Graphics/Pictures/camp", "Night 3"])
    tell(tree, [[art.node, "click"]])
    check("a click on the art tells on_click", card.picked, luka)

    # The camp's icon by its name, large, and a small one in pixels.
    camp_icons = nodes_of(tree, "icon").map { |node| ui::Engine::Tree.component(node).instance_variable_get(:@options).values_at(:icon, :size) }
    check("the camp's icons [icon, size]", camp_icons, [[:party_card_camp, [48, 48]], [12, [20, 20]]])

    # A gold rule two pixels thick parts the pictures; an upright one parts the buttons.
    rule, upright = nodes_of(tree, "divider").map { |node| ui::Engine::Tree.component(node) }
    check("the rules take their color and thickness, the upright one its width", [rule.color, rule.measure, upright.measure], [:gold, [0, 2], [1, 0]])

    # The key focus on the socket shows the gem with what it adds, beside the pointer too.
    socket = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    ui::Engine::Tooltip.show(socket, 0, 0, true)
    box = ui::Engine::Tooltip.instance_variable_get(:@box)
    check("the socket's tooltip shows the markup it wraps, for the keys and the pointer alike",
          [box.children.first.children.map { |label| label.text }, socket.parent.tooltip.equal?(socket.tooltip)], [["Ruby", "ATK +120"], true])
    frame
    drawn = box.base_surface.bitmap
    back, rim = drawn.fills.first(2).map { |fill| fill[4][3] }
    check("the tooltip's plate and frame are slightly see-through, its text drawn on them",
          [back < ui::Engine::Style::BACK.alpha, rim < ui::Engine::Style::RIM.alpha, drawn.texts.map { |text| text[2] }], [true, true, ["Ruby", "ATK +120"]])
    ui::Engine::Tooltip.hide
    frame

    # Against the window's right edge, the socket's tooltip lies beyond the window's frame, as wide
    # as its lines, which do not wrap.
    inner = socket.root.content_rect
    tree.rects[socket.node] = [inner.x, inner.y, inner.width, 24]
    frame
    ui::Engine::Tooltip.show(socket, 0, 0, true)
    box = ui::Engine::Tooltip.instance_variable_get(:@box)
    frame
    window = socket.root.rect
    check("the tooltip at the socket's right beyond the window's frame, as wide as its lines [left, most width]",
          [tree.nodes[box.node][:props]["at"][0], tree.nodes[box.node][:props]["max"]], [window.x + window.width + ui::Engine::Tooltip::FOCUS_GAP, nil])
    ui::Engine::Tooltip.hide
    frame

    # With the window against the screen's right edge, the tooltip finds no room at the right and
    # lies at the window's left instead of covering the socket.
    tree.rects[socket.root.node] = [Graphics.width - window.width, window.y, window.width, window.height]
    frame
    inner = socket.root.content_rect
    tree.rects[socket.node] = [inner.x, inner.y, inner.width, 24]
    frame
    ui::Engine::Tooltip.show(socket, 0, 0, true)
    box = ui::Engine::Tooltip.instance_variable_get(:@box)
    frame
    check("the tooltip without room at the socket's right lies at the window's left",
          tree.nodes[box.node][:props]["at"][0] + box.rect.width, Graphics.width - window.width - ui::Engine::Tooltip::FOCUS_GAP)
    ui::Engine::Tooltip.hide
    frame

    # The camp's line draws the game's color codes on a plate, wrapped into the room it gets.
    line = ui::Engine::Tree.component(nodes_of(tree, "label").last).instance_variable_get(:@options)
    check("the line draws the game's codes on a plate as wide as its text, in as many lines as fit",
          line.values_at(:escapes, :plate, :align, :wrap, :most_lines), [true, :text, :center, true, :fill])
  end
end
