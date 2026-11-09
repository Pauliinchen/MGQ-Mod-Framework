#----------------------------------------------------------------
#  layer_text_fit_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a name narrowed with fit: :narrow, which gives up its room and is cut with its whole text as its tooltip
#                            - Created
#
#----------------------------------------------------------------

# Covers a text's fit: in a booted game against FakeTree, through a mod's box of a speaker's name
# too long for its line, as Battle Dialogue draws it: with fit: :squeeze the whole name goes to the
# game's draw_text in the line's width, which draws it narrower; with fit: :narrow the name gives up
# its room in a row and is cut past 85% of its width, its whole text its tooltip; without either the
# name is cut with "...".

require_relative "layer_support"

NAME_BOX = <<-RUBY
  module Name_Box
    UI = Mod_Framework::UI

    class Box < UI::Component
      def render
        hud at: [8, 88], frame: false do
          text "Alma Elma, Queen Succubus", fit: :squeeze, id: :squeezed
          text "Alma Elma, Queen Succubus", id: :cut
          text "Alma Elma, Queen Succubus", fit: :narrow, id: :narrowed
        end
      end
    end
  end
RUBY

# The texts drawn with draw_text and the width of the box each was drawn into.
module DrawnWidths
  def draw_text(x, y, width, height, text, align = 0)
    ($drawn_widths ||= []) << [text, width]
    super
  end
end
Bitmap.prepend(DrawnWidths)

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Name_Box.rb", NAME_BOX)
    frame

    ui.show(Name_Box::Box)
    root = ui::Engine::Layer.tops.last.root.engine
    tree.rects[root.node] = [8, 88, 100, 90]
    tree.rects[root.find(:squeezed).node] = [8, 88, 100, 30]
    tree.rects[root.find(:cut).node] = [8, 118, 100, 30]
    tree.rects[root.find(:narrowed).node] = [8, 148, 40, 30]
    $drawn_widths = []
    frame

    whole = $drawn_widths.select { |text, _width| text == "Alma Elma, Queen Succubus" }
    cut = $drawn_widths.map { |text, _width| text }.grep(/\.\.\.\z/)
    check("the squeezed name goes whole to draw_text in its line's width, the other one cut [whole, cut]",
          [whole.map { |_text, width| width }, cut.size == 1 && "Alma Elma, Queen Succubus".start_with?(cut[0].strip.chomp("..."))], [[100], true])
    narrowed = root.find(:narrowed)
    check("the narrowed name gives up its room, is cut past its narrowest and keeps its whole text as its tooltip [shrinks, tooltip]",
          [tree.nodes[narrowed.node][:props]["shrink"], narrowed.tooltip], [true, "Alma Elma, Queen Succubus"])
  end
end
