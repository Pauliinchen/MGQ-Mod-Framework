#----------------------------------------------------------------
#  layer_picture_scale_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked that many scaled faces redraw from their copies, each draw loading a new face sheet
#                            - Created
#
#----------------------------------------------------------------

# Covers scale: :auto of the UI layer's image and avatar in a booted game against FakeTree, through a
# mod's grid of a character: the map figure and the face avatar keep their proportions in C#'s tree,
# ask C# to plan their scaling to the room they get, the figure sharp by default and the face as its
# sampling: tells, and draw the picture scaled to the plan's size. A wall of more faces than a shared
# cache would hold redraws from the copies each part keeps, though Paradox loads each face sheet anew.

require_relative "layer_support"

GRID = <<-RUBY
  module Party_Grid
    UI = Mod_Framework::UI

    class GridWindow < UI::Component
      param :hero

      def render
        window "Party", width: 300 do
          grid do
            grid_item(xs: 6) { image figure: hero, scale: :auto }
            grid_item(xs: 6) { avatar character: hero, scale: :auto, sampling: :sharp }
          end
        end
      end
    end

    class WallWindow < UI::Component
      param :members

      def render
        window "Wall" do
          members.each { |member| image face: member, scale: :auto }
        end
      end
    end
  end
RUBY

# A character with a face and a map sprite.
Pal = Struct.new(:id, :name, :face_name, :face_index, :character_name, :character_index)

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  plans = []
  fake.answer("ui.picture.scale") do |request|
    plans << request
    width, height, room_width, room_height = request
    factor = [room_width.to_f / width, room_height.to_f / height].min
    [(width * factor).round, (height * factor).round, ["stretch", []], ["stretch", []]]
  end
  boot_tree(fake) do
    ui = Mod_Framework::UI
    luka = Pal.new(1, "Luka", "Luka_face", 0, "$Luka_walk", 0)
    faces = Bitmap.new(384, 384)
    walk = Bitmap.new(96, 128)
    # Only a figure of 12 by 30 pixels in the standing frame is not see-through.
    def walk.get_pixel(x, y); Color.new(0, 0, 0, x >= 42 && x < 54 && y >= 1 && y < 31 ? 255 : 0); end
    Cache.define_singleton_method(:face) { |_name| faces }
    Cache.define_singleton_method(:character) { |_name| walk }
    load_mod("Patch/Party_Grid.rb", GRID)
    frame

    ui.open(Party_Grid::GridWindow, hero: luka)
    frame
    figure, face = nodes_of(tree, "picture").map { |node| ui::Engine::Tree.component(node) }
    check("the figure and the face keep their proportions in C#'s tree", [figure, face].map { |part| tree.nodes[part.node][:props]["aspect"] }, [true, true])

    # C# gives each the width of its grid item and the height its proportions give.
    tree.rects[figure.node] = [8, 40, 72, 180]
    tree.rects[face.node] = [86, 40, 72, 72]
    frame
    Graphics.update
    check("each asks C# to plan its scaling to its room, the figure sharp by default, the face as its sampling: tells",
          plans.last(2), [[12, 30, 72, 180, "contain", "sharp"], [96, 96, 72, 72, "contain", "sharp"]])
    scaled = lambda do |part|
      part.surface.bitmap.copies.map { |_x, _y, source| source }.select { |source| source.is_a?(Bitmap) && ![walk, faces].include?(source) }.map { |source| [source.width, source.height] }
    end
    check("the figure draws scaled to the plan's size", scaled.call(figure).include?([72, 180]), true)
    check("the face draws scaled to its square", scaled.call(face).include?([72, 72]), true)

    # Paradox frees a face sheet after each draw, so each draw loads it as a new Bitmap.
    Cache.define_singleton_method(:face) { |_name| Bitmap.new(384, 384) }
    members = Array.new(40) { |at| Pal.new(10 + at, "Member #{at}", "Face_#{at}", 0, "", 0) }
    ui.open(Party_Grid::WallWindow, members: members)
    frame
    Graphics.update
    wall = (nodes_of(tree, "picture") - [figure.node, face.node]).map { |node| ui::Engine::Tree.component(node) }
    copies = lambda do
      wall.flat_map { |part| part.surface.bitmap.copies.map { |_x, _y, source| source } }.select { |source| source.is_a?(Bitmap) && [source.width, source.height] == [24, 24] }.uniq
    end
    made = copies.call
    wall.each(&:redraw)
    frame
    Graphics.update
    check("40 scaled faces redraw from the copies their parts made, though each draw loads a new face sheet",
          [made.size, (copies.call - made).size, made.count(&:disposed?)], [40, 0, 0])
  end
end
