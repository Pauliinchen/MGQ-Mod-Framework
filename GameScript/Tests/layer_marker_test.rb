#----------------------------------------------------------------
#  layer_marker_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Checked that a marker draws its triangle from the arrow of its angle, moved into its picture
#      Paulinchen  2026-11-06: Let the compass needle point right, as an arrow takes no angle
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers marker and arrow of the UI layer (design v2 sections 5.4 and 5.7) in a booted game against
# FakeTree, with C#'s geometry answered by the fake DLL, through a mod's shrine marker: an arrow at
# the screen's edge toward a shrine event off the screen with its live distance on a plate, hidden
# while the mod's wheel is open and once the shrine comes onto the screen; and a compass needle in a
# HUD.

require_relative "layer_support"

CAMP_MARKS = <<-RUBY
  module Camp_Marks
    UI = Mod_Framework::UI

    class Shrine < UI::Component
      def render
        marker target: 4, text: -> { "Shrine \#{$camp_tiles}" }, color: :gold, hide_while: -> { $camp_wheel }
      end
    end

    class Compass < UI::Component
      def render
        hud anchor: :top_right, id: :camp_compass do
          arrow color: :success, id: :camp_needle
        end
      end
    end
  end
RUBY

# A map character as its sprite shows it: its middle and feet on the screen and its tile.
class MarkCharacter
  attr_accessor :screen_x, :screen_y, :x, :y, :transparent

  # Makes a character standing at a place.
  #
  # @param screen_x [Integer] Its middle on the screen.
  # @param screen_y [Integer] Its feet on the screen.
  def initialize(screen_x, screen_y)
    @screen_x, @screen_y, @x, @y = screen_x, screen_y, 5, 7
  end
end

# The sprite of a map character, 32 pixels high.
class MarkSprite < Sprite
  attr_reader :character

  # Makes the sprite of a character on a viewport.
  #
  # @param character [MarkCharacter] The character.
  # @param viewport [Viewport] The viewport.
  def initialize(character, viewport)
    super(viewport)
    @character = character
    @src_rect = Rect.new(0, 0, 32, 32)
  end
end

# A map scene whose spriteset shows the characters on the map's viewport.
class MarkMapScene
  # Makes the scene with the characters' sprites.
  #
  # @param characters [Array<MarkCharacter>] The characters.
  def initialize(characters)
    map = Viewport.new
    @spriteset = Object.new
    @spriteset.instance_variable_set(:@viewport1, map)
    @spriteset.instance_variable_set(:@character_sprites, characters.map { |character| MarkSprite.new(character, map) })
  end
end

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  arrows = []
  fake.answer("ui.marker.arrow") { |request| arrows << request; [-5, -5, 11, 11, [[0, 0, 3, 0], [1, 0, 1, 1]]] }
  places = []
  fake.answer("ui.marker.place") { |request| places << request; [626, 224, 0, -11, -11, 23, 23, -40, 1, -10, 0] }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Marks.rb", CAMP_MARKS)
    $game_player = MarkCharacter.new(320, 240)
    shrine = MarkCharacter.new(900, 240)
    $game_map = Struct.new(:events).new({ 4 => shrine })
    $scene_now = MarkMapScene.new([$game_player, shrine])
    $camp_tiles = 12
    frame

    # The marker lies at the edge where C# placed it, along the line from the player to the shrine,
    # 14 pixels in, with room for the shrine's name and distance.
    ui.show(Camp_Marks::Shrine)
    2.times { frame }
    marker = ui::Engine::Layer.tops.last.root.engine
    check("the marker at the edge toward the shrine [shows, its place]", [marker.visible?, marker.at], [true, [615, 213]])
    check("the line it asked C# for [from, to, margin]", places.last.values_at(0, 1, 2, 3, 7), [320, 224, 900, 224, 14])
    check("its plate holds the text", places.last[8] > 0, true)
    Graphics.update
    check("its triangle drawn from the arrow C# laid out for its angle, moved to its place in the marker's picture [the arrow asked, the rows]",
          [arrows.last, marker.base_surface.bitmap.fills.first(2).map { |each| each[0, 4] }], [[0], [[6, 6, 3, 1], [7, 6, 1, 1]]])

    # The distance on its plate follows the mod's count.
    $camp_tiles = 11
    3.times { frame }
    check("the text after the shrine came a tile nearer", marker.text, "Shrine 11")

    # It hides while the mod's wheel is open, and once the shrine walks onto the screen.
    $camp_wheel = true
    frame
    check("the marker while the wheel is open", tree.nodes[marker.node][:props]["visible"], false)
    $camp_wheel = false
    frame
    shrine.screen_x = 400
    2.times { frame }
    check("the marker once the shrine is on the screen", marker.visible?, false)

    # A compass needle in a HUD asks C# for an arrow pointing right and fills its rows.
    ui.show(Camp_Marks::Compass)
    frame
    Graphics.update
    check("the arrow C# laid out [angle]", arrows.last, [0])
    hud = ui::Engine::Layer.tops.last.root.engine
    tree.rects[hud.find(:camp_needle).node] = [0, 0, 11, 11]
    frame
    Graphics.update
    check("the needle drawn in the outline color and in its own", hud.base_surface.bitmap.fills.last(2).map { |each| each[4] },
          [ui::Engine::Style::OUTLINE.to_a, ui::Engine::Theme.palette(true).named(:success).to_a])
  end
end
