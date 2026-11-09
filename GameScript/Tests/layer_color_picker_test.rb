#----------------------------------------------------------------
#  layer_color_picker_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked a picker with palette: given, a color name among its colors
#                            - Told the red slider its new number as C#'s tree tells it
#                            - Created
#
#----------------------------------------------------------------

# Covers color_picker of the UI layer (design v2 section 5.3) in a booted game against FakeTree,
# through a mod's name color box: the game's text colors as swatches, a click that picks one and
# frames it, a slider that changes its red, and the color the mod sets reaching the swatches and the
# sliders; and a mark color box whose palette: names a color of the look and a "#RRGGBB" without
# sliders.

require_relative "layer_support"

NAME_COLOR = <<-RUBY
  module Name_Color
    UI = Mod_Framework::UI

    class NameColorWindow < UI::Component
      state :color
      state(:told) { [] }

      def render
        window "Name color" do
          color_picker "Color of the leader's name", bind: :color, on_change: ->(color) { self.told = told + [color] }
        end
      end
    end

    class MarkColorWindow < UI::Component
      state :mark

      def render
        window "Mark color" do
          color_picker "Mark color", bind: :mark, palette: [:primary, "#FF0000"], sliders: false
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    # The game's window skin holds a text color of its own at each index.
    def ui.text_color(index)
      Color.new(index * 8, 255 - index * 8, 128)
    end
    load_mod("Patch/Name_Color.rb", NAME_COLOR)
    frame

    ui.open(Name_Color::NameColorWindow)
    frame
    Graphics.update
    box = ui::Engine::Layer.tops.last.mount.component
    picker = ui::Engine::Tree.component(nodes_of(tree, "stack").find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::ColorPicker) })
    swatches = picker.children.first.children
    red, green, blue = nodes_of(tree, "slider").map { |node| ui::Engine::Tree.component(node) }
    third = ui.text_color(2)
    third_hex = format("#%02X%02X%02X", third.red, third.green, third.blue)
    check("the picker as it opens [swatches, the third one's color, picked ones, sliders]",
          [swatches.size, swatches[2].hex, swatches.count { |swatch| swatch.picked }, [red, green, blue].map { |slider| slider.value }],
          [32, third_hex, 0, [0, 0, 0]])

    # A click on the third swatch picks the game's text color 2: the state, the frame and the sliders follow.
    tell(tree, [[swatches[2].node, "click"]])
    check("after a click on the third swatch [state, told, framed, red slider]",
          [box.color, box.told, swatches.index { |swatch| swatch.picked }, red.value], [third_hex, [third_hex], 2, third.red])

    # Left on the red slider takes one off its red, which no swatch holds.
    tell(tree, [[red.node, "number", third.red - 1]])
    lower = format("#%02X%02X%02X", third.red - 1, third.green, third.blue)
    check("after Left on the red slider [state, framed swatches]", [box.color, swatches.count { |swatch| swatch.picked }], [lower, 0])

    # The mod sets the color by a game text color's hex: its swatch is framed and the sliders follow.
    box.color = swatches[0].hex
    frame
    Graphics.update
    check("after the mod set the first swatch's color [framed, picker's color]", [swatches.index { |swatch| swatch.picked }, picker.value], [0, swatches[0].hex])

    # The mark color box: a swatch for the look's primary and one for the "#RRGGBB", no sliders.
    ui.open(Name_Color::MarkColorWindow)
    frame
    Graphics.update
    mark_picker = ui::Engine::Tree.component(nodes_of(tree, "stack").reverse.find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::ColorPicker) })
    marks = mark_picker.children.first.children
    check("a picker with palette: given [swatches, the first in the look's primary, the second, sliders shown]",
          [marks.size, marks[0].hex == ui::Engine::ColorPicker.hex(:primary, mark_picker.palette), marks[1].hex, mark_picker.children[1].visible],
          [2, true, "#FF0000", false])
  end
end
