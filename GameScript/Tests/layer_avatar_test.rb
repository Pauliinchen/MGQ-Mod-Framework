#----------------------------------------------------------------
#  layer_avatar_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked that a face in a square shrinks whole in one stretch
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the avatar of the UI layer in a booted game against FakeTree, through a mod's HUD box of
# the party's leader: the leader's face in a square, shrunk whole in one stretch, that follows the
# leader as the party's order changes, and the second member's map sprite in a circle, cut row by row
# to the circle and scaled by whole steps.

require_relative "layer_support"

LEADER_BOX = <<-RUBY
  module Leader_Box
    UI = Mod_Framework::UI

    class Leader < UI::Component
      def render
        hud id: :leader_box, anchor: :top_left do
          avatar character: :party_leader, image: :face, shape: :box, size: :large
          avatar character: :party_member, index: 1, image: :sprite
        end
      end
    end
  end
RUBY

# A character with a face and a map sprite.
Hero = Struct.new(:id, :name, :face_name, :face_index, :character_name, :character_index)

# The party, whose order the player changes in the game's formation.
class LeaderParty
  # @return [Array<Hero>] Its members, the leader first.
  attr_reader :members

  # Makes the party.
  #
  # @param members [Array<Hero>] Its members.
  def initialize(members)
    @members = members
  end

  # @return [Hero] Its leader.
  def leader
    @members.first
  end

  # Swaps two members, as the game's formation does.
  def swap_order(one, other)
    @members[one], @members[other] = @members[other], @members[one]
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    luka = Hero.new(1, "Luka", "Luka_face", 0, "Luka_walk", 0)
    alice = Hero.new(2, "Alice", "Alice_face", 1, "$Alice_walk", 0)
    $game_party = LeaderParty.new([luka, alice])
    faces = Bitmap.new(384, 384)
    walk = Bitmap.new(96, 128)
    # Only a figure of 12 by 30 pixels in the standing frame is not see-through.
    def walk.get_pixel(x, y); Color.new(0, 0, 0, x >= 42 && x < 54 && y >= 1 && y < 31 ? 255 : 0); end
    Cache.define_singleton_method(:face) { |_name| faces }
    Cache.define_singleton_method(:character) { |_name| walk }
    load_mod("Patch/Leader_Box.rb", LEADER_BOX)
    frame

    ui.show(Leader_Box::Leader)
    frame
    Graphics.update
    leader, member = nodes_of(tree, "picture").map { |node| ui::Engine::Tree.component(node) }
    check("the box shows the leader's face, large and square; the circle the second member's sprite",
          [leader.actor, leader.image, leader.shape, leader.measure, member.actor, member.image, member.shape, member.measure],
          [luka, :face, :box, [96, 96], alice, :sprite, :circle, [48, 48]])
    tree.rects[leader.node] = [8, 8, 96, 96]
    tree.rects[member.node] = [8, 108, 48, 48]
    frame
    Graphics.update
    rows = lambda do |avatar|
      left = avatar.rect.x - avatar.surface.x
      avatar.surface.bitmap.copies.select { |x, _y, source| source.equal?(avatar.actor == alice ? walk : faces) && x >= left && x < left + avatar.rect.width }
    end
    # The square face shrinks whole in one stretch of the face blitted alone onto a picture of its
    # own, as the game's windows shrink a face.
    corner = [leader.rect.x - leader.surface.x, leader.rect.y - leader.surface.y]
    stretched = leader.surface.bitmap.copies.select { |_x, _y, source| source.is_a?(Bitmap) && source.copies.map { |copy| copy[2] } == [faces] }
    check("the square face is one stretch of the face alone, at the square's corner [stretches, place, its picture's size, rows drawn from the sheet]",
          [stretched.size, stretched.map { |x, y, _source| [x, y] }.first, [stretched[0][2].width, stretched[0][2].height], rows.call(leader).size], [1, corner, [96, 96], 0])

    # The sprite stands in the circle at whole steps: 30 pixels high fit once, its rows inside the
    # circle's spans.
    drawn = rows.call(member)
    spans = ui::Engine::Avatar.rows(:circle, 48)
    inside = drawn.all? { |x, y| span = spans[y - (member.rect.y - member.surface.y)]; x - (member.rect.x - member.surface.x) >= span[0] }
    check("the sprite draws its 30 rows once, each inside the circle [rows, inside]", [drawn.size, inside], [30, true])

    # The player puts Alice in front: the box follows the new leader.
    $game_party.swap_order(0, 1)
    ui::Engine::Serials.bump(:party)
    frame
    Graphics.update
    leader, member = nodes_of(tree, "picture").map { |node| ui::Engine::Tree.component(node) }
    check("the box follows the new leader, the circle the new second member", [leader.actor, member.actor], [alice, luka])
  end
end
