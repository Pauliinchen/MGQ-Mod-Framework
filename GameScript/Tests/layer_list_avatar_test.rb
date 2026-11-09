#----------------------------------------------------------------
#  layer_list_avatar_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked that a leader's face fills its square in one stretch
#      Paulinchen  2026-11-08: Covered leaders whose sprite file the game does not have
#                            - Created
#
#----------------------------------------------------------------

# Covers the avatar in a list's cell in a booted game against FakeTree, through a mod's list of the
# players of a world: each player's leader in a square of 28 before the name, one known only by
# the map sprite the row has, one a database actor outside the party, the rows grown to 32 and the
# names after the pictures, in the middle of the rows; a leader whose sprite file this game does not
# have shows the plate alone and leaves the other rows drawn.

require_relative "layer_support"

module RPG
  # A character of the game's database, outside any party.
  class Actor
    attr_reader :id, :name, :face_name, :face_index, :character_name, :character_index

    # Makes the character.
    def initialize(id, name, face_name, face_index, character_name, character_index)
      @id = id
      @name = name
      @face_name = face_name
      @face_index = face_index
      @character_name = character_name
      @character_index = character_index
    end
  end
end

PLAYERS_PAGE = <<-RUBY
  module Players_Page
    UI = Mod_Framework::UI

    Player = Struct.new(:name, :sprite, :index, :leader, :ping)

    class Players < UI::Component
      def render
        window "World overview", width: 360 do
          list rows, id: :players, cells: [nil, 64], bind_index: :picked
        end
      end

      def rows
        Players_Page.players.map do |player|
          leader = player.leader || { sprite: player.sprite, index: player.index }
          { cells: [{ avatar: { character: leader, image: player.leader ? :face : :sprite, shape: :box, width: 28, height: 28 }, text: player.name },
                    { text: "\#{player.ping} ms", align: :end }] }
        end
      end
    end

    def self.players
      [Player.new("Ana", "Main01_cip", 0, nil, 40), Player.new("Mia", nil, 0, $data_actors[2], 85)]
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    $data_actors = [nil, nil, RPG::Actor.new(2, "Alice", "alice_fc", 1, "$Alice_the_1st_01_cip", 0)]
    $game_actors = nil
    faces = Bitmap.new(384, 384)
    walk = Bitmap.new(384, 256)
    # Only a figure of 16 by 28 pixels in Luka's standing frame is not see-through.
    def walk.get_pixel(x, y); Color.new(0, 0, 0, x >= 40 && x < 56 && y >= 2 && y < 30 ? 255 : 0); end
    Cache.define_singleton_method(:face) { |_name| faces }
    Cache.define_singleton_method(:character) { |_name| walk }
    load_mod("Patch/Players_Page.rb", PLAYERS_PAGE)
    frame

    ui.open(Players_Page::Players)
    frame
    Graphics.update
    list = ui::Engine::Tree.roots.last.find(:players)
    check("the rows grow to the avatars and their room", [list.line_height, tree.nodes[list.node][:props]["row_height"]], [32, 32])

    tree.rects[list.node] = [100, 100, 300, 64]
    list.placed([100, 100, 300, 64])
    frame
    Graphics.update
    sheet = list.inner_surface.bitmap
    left = list.rect.x - list.inner_surface.x
    top = list.rect.y - list.inner_surface.y
    drawn = lambda { |source| sheet.copies.select { |_x, _y, picture| picture.equal?(source) }.map { |x, y, _picture| [x - left, y - top] } }

    # Ana's leader is known by the sprite alone: the 28 rows of the figure, once at whole steps, in
    # the square 2 below the top of the first row; Alice from the database fills her square.
    sprite = drawn.call(walk)
    face = sheet.copies.select { |_x, _y, picture| picture.is_a?(Bitmap) && picture.copies.map { |copy| copy[2] } == [faces] }.map { |x, y, _picture| [x - left, y - top] }
    check("Ana's leader: the sprite's rows inside the first row's square [rows, top, bottom]", [sprite.size, sprite.map(&:last).min, sprite.map(&:last).max], [28, 2, 29])
    check("Alice's face: one stretch of her face alone into the square in the second row [stretches, top]", [face.size, face.map(&:last).min], [1, 34])
    check("no character joins the game's actors", $game_actors, nil)

    names = sheet.texts.select { |_x, _y, text| text == "Ana" || text == "Mia" }.map { |x, y, text| [text, x - left - face.map(&:first).first, y - top] }
    check("each name after the picture, in the middle of its row", names.map { |text, x, y| [text, x >= 28 + ui::Engine::Style::GAP, y] },
          [["Ana", true, 4], ["Mia", true, 36]])
  end
end

# Kai's and Rin's leaders have a mod's sprite this game does not have: every row still draws, their
# avatars are the plate alone, and the log names the file once.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    walk = Bitmap.new(384, 256)
    def walk.get_pixel(x, y); Color.new(0, 0, 0, x >= 40 && x < 56 && y >= 2 && y < 30 ? 255 : 0); end
    missing = 0
    Cache.define_singleton_method(:character) do |name|
      next walk unless name == "Mod_Hero_cip"

      missing += 1
      raise Errno::ENOENT, "Graphics/Characters/#{name}"
    end
    Object.send(:remove_const, :Players_Page)
    load_mod("Patch/Players_Page.rb", PLAYERS_PAGE)
    Players_Page.define_singleton_method(:players) do
      [["Ana", "Main01_cip"], ["Kai", "Mod_Hero_cip"], ["Mia", "Main01_cip"], ["Rin", "Mod_Hero_cip"]].map { |name, sprite| Players_Page::Player.new(name, sprite, 0, nil, 40) }
    end
    frame

    lines = logged_lines do
      ui.open(Players_Page::Players)
      frame
      Graphics.update
      list = ui::Engine::Tree.roots.last.find(:players)
      tree.rects[list.node] = [100, 100, 300, 128]
      list.placed([100, 100, 300, 128])
      frame
      Graphics.update
    end
    list = ui::Engine::Tree.roots.last.find(:players)
    sheet = list.inner_surface.bitmap
    top = list.rect.y - list.inner_surface.y
    rows_of = lambda { |ys| ys.map { |y| (y - top) / 32 }.uniq.sort }
    well = list.palette.drawn(list.palette.now(:well)).to_a
    plates = sheet.fills.select { |_x, _y, _width, height, color| height == 1 && color.to_a == well }
    check("every name draws", sheet.texts.map { |_x, _y, text| text }.uniq & ["Ana", "Kai", "Mia", "Rin"], ["Ana", "Kai", "Mia", "Rin"])
    check("each row draws its plate, Kai's and Rin's without a sprite over it [plate rows, sprite rows]",
          [rows_of.call(plates.map { |fill| fill[1] }), rows_of.call(sheet.copies.select { |_x, _y, picture| picture.equal?(walk) }.map { |_x, y| y })], [[0, 1, 2, 3], [0, 2]])
    check("the list looks for the missing file for both rows, and the log names it once",
          [missing, lines.count { |line| line.include?("Graphics/Characters/Mod_Hero_cip") }], [2, 1])
  end
end
