#----------------------------------------------------------------
#  layer_card_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered the game's window color staying off a window's own skin
#                            - Covered a card's padding inside its frame, a card without a frame on a fading background and a text with a border
#                            - Covered a window that wears a skin painted in its own background and border
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers cards of the UI layer in a booted game against FakeTree, through a mod's camp window: a
# card of a party member pressed as one part, whose head follows the member's level, and a card
# of the camp with two actions that the keys enter, each action pressed on its own; a note card of
# less room inside its frame, and one without a frame on a background fading to its right that
# holds a text with a border; the window wears a skin painted in its own background and border,
# which the game's window color never tints.

require_relative "layer_support"

CAMP_CARDS = <<-RUBY
  module Camp_Cards
    UI = Mod_Framework::UI

    class Camp < UI::Component
      state :level, 12
      state(:pressed) { [] }

      def render
        window "Camp", background: [20, 40, 60, 128], border: :primary do
          card clickable: true, on_click: -> { self.pressed = pressed + [:luka] } do
            card_header "Luka", subtitle: "Level \#{level}"
          end
          card enter: true do
            card_header "Inn"
            card_content { text "Rest until morning." }
            actions do
              button "Rest", on_click: -> { self.pressed = pressed + [:rest] }
              button "Leave", on_click: -> { self.pressed = pressed + [:leave] }
            end
          end
          card(padding: 0.5) { text "Notes" }
          card padding: 0.5, border: false, background: { color: [0, 0, 0, 170], fade: [:right, 48] } do
            text "Marked", border: :primary
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
    load_mod("Patch/Camp_Cards.rb", CAMP_CARDS)
    frame

    ui.open(Camp_Cards::Camp)
    frame
    Graphics.update
    camp = ui::Engine::Layer.tops.last.mount.component
    member, inn = nodes_of(tree, "box")
    check("the member card is one key stop and the inn card a box the keys enter [clickable, enter]",
          [member, inn].map { |node| [tree.nodes[node][:props]["clickable"], tree.nodes[node][:props]["enter"]] }, [[true, false], [false, true]])
    heads = lambda { nodes_of(tree, "label").map { |node| ui::Engine::Tree.component(node) }.select { |label| label.visible? }.map { |label| label.text } }
    check("the heads show their titles, the member also its level", heads.call.first(4), ["Luka", "Level 12", "Inn", "Rest until morning."])

    # A press on the member card picks it; the head follows a level up.
    tell(tree, [[member, "click"]])
    camp.level = 13
    frame
    Graphics.update
    check("the member card pressed, its head one level up [pressed, head]", [camp.pressed, heads.call[1]], [[:luka], "Level 13"])

    # The inn's actions stand in a row at its foot, each pressed on its own.
    rest, leave = nodes_of(tree, "button")
    check("the actions are the inn card's last part, in a row", [tree.nodes[inn][:children].last, tree.nodes[tree.nodes[rest][:parent]][:props]["layout"]],
          [tree.nodes[rest][:parent], "row"])
    tell(tree, [[leave, "click"]])
    check("Leave pressed", camp.pressed, [:luka, :leave])

    # The note card keeps 2 px inside its frame of 2; without a frame only the 2 px; its background
    # is solid up to its last 48 px, which thin to nothing; the text's border runs along its edge.
    notes, plain = nodes_of(tree, "box").last(2)
    check("the padding of the note card and of the card without a frame", [notes, plain].map { |node| tree.nodes[node][:props]["padding"] }, [[4, 4, 4, 4], [2, 2, 2, 2]])
    marked = ui::Engine::Tree.component(nodes_of(tree, "label").last)
    surface = ui::Engine::Layer.tops.last.root.engine.base_surface
    fills = surface.bitmap.fills
    box = ui::Engine::Tree.component(plain).rect
    left = box.x - surface.x
    solid = fills.find { |fill| fill[0] == left && fill[2] == box.width - 48 && fill[3] == box.height }
    fade = fills.select { |fill| fill[0] >= left + box.width - 48 && fill[0] < left + box.width && fill[2] == 1 && fill[3] == box.height }
    check("the background [solid alpha, fading columns, first and last alpha]", [solid && solid[4][3], fade.size, fade.first[4][3].round, fade.last[4][3].round],
          [170, 48, 170, 0])
    primary = ui::Engine::Canvas.new(marked, surface).color(:primary).to_a
    lines = fills.select { |fill| fill[2] == marked.rect.width && fill[3] == 1 && fill[4] == primary }
    check("the text's border along its top and bottom in the primary color", lines.map { |fill| fill[1] - (marked.rect.y - surface.y) }.sort, [0, marked.rect.height - 1])

    # The window's game frame wears its background opaque in the skin, its alpha as the frame's
    # opacity, and its border along the skin's frame square.
    frame
    skin = surface.frame.windowskin.fills
    check("the window's [opacity, skin's back, skin's top border]", [surface.frame.back_opacity, skin.include?([0, 0, 64, 64, [20, 40, 60, 255]]),
                                                                     skin.include?([64, 0, 64, 1, primary])], [128, true, true])

    # In the game's own look the game's window color, which the game puts back on every update,
    # never tints that skin.
    $game_system = Struct.new(:window_tone).new(Tone.new(40, 0, 0, 0))
    ui::Engine::Theme.choose("Game's Default")
    2.times { frame }
    check("the window's tone in the game's own look after further frames", surface.frame.tone.to_a, [0, 0, 0, 0])
  end
end
