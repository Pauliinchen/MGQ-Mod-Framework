#----------------------------------------------------------------
#  layer_highlight_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that the marked letters keep the text's own color and outline
#                            - Checked that a mark lies on the primary color in the text color that contrasts with it
#                            - Checked that a mark in a list row is as high as the font, not the row
#                            - Created
#
#----------------------------------------------------------------

# Covers highlight: of the UI layer in a booted game against FakeTree, through a mod's quest
# search: the text searched for drawn on the theme's primary color, its letters in their own color
# and outline, wherever it occurs, ignoring case, in a text, the rows of a list and the cells of a
# table, and nowhere once the search is empty.

require_relative "layer_support"

# A picture that notes the color and the outline each text was last drawn in.
class Bitmap
  # Notes a text drawn with its place, its color and its outline.
  def draw_text(x, y, width, _height, text, align = 0)
    @texts << [landing(x, width, text, align), y, text]
    (@colors ||= {})[text] = [@font.color.to_a, @font.outline ? @font.out_color.to_a : nil]
  end

  # @return [Hash{String => Array}] The color's and the outline's values by text, nil for no outline.
  def colors
    @colors || {}
  end
end

QUEST_LOG = <<-RUBY
  module Quest_Log
    UI = Mod_Framework::UI

    QUESTS = ["Find the herbs", "The herbalist's herb tea", "Rope bridge"]

    class Search < UI::Component
      state :search, "HERB"

      def render
        window "Quests" do
          text "Herbs grow by the river.", highlight: search
          list QUESTS, highlight: search, on_submit: ->(_quest) {}
          table QUESTS, highlight: search do
            column "Quest"
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
    load_mod("Patch/Quest_Log.rb", QUEST_LOG)
    frame

    ui.open(Quest_Log::Search)
    frame
    Graphics.update
    log = ui::Engine::Layer.tops.last.mount.component
    label = ui::Engine::Tree.component(nodes_of(tree, "label").first)
    list, table_list = nodes_of(tree, "list").map { |node| ui::Engine::Tree.component(node) }
    tree.rects[label.node] = [20, 40, 400, 24]
    tree.rects[list.node] = [20, 70, 400, 90]
    tree.rects[table_list.node] = [20, 170, 400, 90]
    frame
    Graphics.update
    primary = label.palette.named(:primary).to_a
    marks = lambda do |part|
      left = part.rect.x - part.surface.x
      top = part.rect.y - part.surface.y
      part.surface.bitmap.fills.select { |x, y, _width, _height, color| color == primary && x >= left && x < left + part.rect.width && y >= top && y < top + part.rect.height }
    end
    row_marks = lambda { |part| part.instance_variable_get(:@inner).bitmap.fills.select { |fill| fill[4] == primary } }
    herb = ui.text_width(ui.font_bitmap(label.send(:text_px)), "Herb")
    shown = marks.call(label).map { |x, _y, width| [x - (label.rect.x - label.surface.x) - label.send(:padding_sides)[3], width] }
    check("the text marks Herbs at its start, as wide as its first four letters", shown, [[0, herb]])
    check("the list marks herb in each row that holds it, twice in the tea's, each mark as high as the font, not the row [marks, heights]",
          [row_marks.call(list).size, row_marks.call(list).map { |fill| fill[3] }.uniq], [3, [ui.font_px(:normal)]])
    check("the table marks herb in its cells alike [marks]", row_marks.call(table_list).size, 3)
    white = [255, 255, 255, 255]
    black = [0, 0, 0, 255]
    texts = [label.surface.bitmap, list.instance_variable_get(:@inner).bitmap]
    check("the marked letters stay white with the black outline over the gold plate [text, row, plate apart from the picked color]",
          [texts[0].colors["Herbs grow by the river."], texts[1].colors["Find the herbs"], primary != label.palette.picked.to_a],
          [[white, black], [white, black], true])

    # The search is emptied: nothing is marked any more.
    log.search = ""
    frame
    Graphics.update
    label.surface.bitmap.clear
    list.instance_variable_get(:@inner).bitmap.clear
    label.redraw
    list.redraw_content
    frame
    Graphics.update
    drawn_again = [label.surface.bitmap, list.instance_variable_get(:@inner).bitmap].map { |bitmap| bitmap.texts.map { |text| text[2] } }
    check("an empty search marks nothing, the text and the rows drawn again [text marks, row marks, drawn again]",
          [marks.call(label).size, row_marks.call(list).size, drawn_again[0].include?("Herbs grow by the river.") && drawn_again[1].include?("Find the herbs")], [0, 0, true])
  end
end
