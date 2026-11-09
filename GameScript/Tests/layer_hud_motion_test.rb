#----------------------------------------------------------------
#  layer_hud_motion_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a box hidden while it slides in
#                            - Created
#
#----------------------------------------------------------------

# Covers the parts a battle line's box takes in a booted game against FakeTree, through a mod's box
# of what a speaker says, as Battle Dialogue shows it: a see-through plate whose last 48 px thin to
# nothing, the speaker's face from a face file in a hue, shrunk whole into its square without the
# avatar's plate, and the line in 18 px lines; the box slides in at a spot without
# fading over 15 frames, then fades out in place over 30, at the old box's place and opacity on
# every frame; a new spot moves it the next frame without motion, and only then; a box hidden as
# it slides in fades from opaque where it stands; a box on the right slides from the right;
# hide(at_once: true) takes a box off in the same frame.

require_relative "layer_support"

BATTLE_LINES = <<-RUBY
  module Battle_Lines
    UI = Mod_Framework::UI

    class Box < UI::Component
      param :line
      param :side, :left

      def render
        hud at: -> { Battle_Lines.spot(side) }, enter: :move, leave: :fade, motion_frames: [15, 30], width: 288,
            background: { color: [0, 0, 0, 170], fade: [:right, 48] }, border: false, padding: 2 do
          avatar face: ["Alice_face", 1], hue: 40, shape: :box, width: 48, height: 48, background: false, id: :speaker
          text line, typo: :body2, line_height: 18, wrap: true, id: :line
        end
      end
    end

    def self.spot(side)
      [side == :left ? 8 : 344, $box_top]
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    faces = Bitmap.new(384, 384)
    loaded = []
    Cache.define_singleton_method(:face) do |name, hue = 0|
      loaded << [name, hue]
      faces
    end
    load_mod("Patch/Battle_Lines.rb", BATTLE_LINES)
    frame

    $box_top = 88
    box = ui.show(Battle_Lines::Box, line: "You will not pass this gate while I stand", )
    root = ui::Engine::Layer.tops.last.root.engine
    tree.rects[root.node] = [8, 88, 288, 64]
    tree.rects[root.find(:speaker).node] = [8, 96, 48, 48]
    tree.rects[root.find(:line).node] = [64, 96, 224, 36]
    sprite = lambda { root.base_surface.instance_variable_get(:@sprite) }
    step = lambda { frame; [sprite.call.x, sprite.call.opacity] }

    # In: 15 frames from beyond the left edge, eased out, opaque all along, as the old box.
    coming = (1..15).map { step.call }
    check("it slides in at the old box's place on each frame, opaque", coming, (1..15).map { |n| [8 - (296 * (1 - n / 15.0)**2).round, 255] })

    picture = root.base_surface.bitmap
    stretched = picture.copies.select { |_x, _y, source| source.is_a?(Bitmap) && source.copies.map { |copy| copy[2] } == [faces] }
    check("the face loads in its hue and shrinks whole in one stretch [loaded, stretches]", [loaded.uniq, stretched.size], [[["Alice_face", 40]], 1])
    plate = picture.fills.select { |_x, _y, _width, _height, color| color[0, 3] == [0, 0, 0] }
    solid = plate.select { |_x, _y, width, _height, color| width > 1 && color[3] == 170 }
    tail = plate.select { |_x, _y, width, _height, _color| width == 1 }
    alphas = tail.sort_by { |x, _y| x }.map { |fill| fill[4][3] }
    check("the plate is solid for 240 px, then thins over its last 48 px to nothing [solid width, tail lines, falling, last alpha]",
          [solid.map { |fill| fill[2] }, tail.size, alphas.each_cons(2).all? { |a, b| a > b }, alphas.last < 170 / 48 + 1], [[240], 48, true, true])
    speaker = root.find(:speaker)
    well = speaker.palette.drawn(speaker.palette.now(:well)).to_a
    check("the face draws without the avatar's well", picture.fills.count { |fill| fill[4] == well }, 0)
    lines = picture.texts.map { |_x, y, _text| y }.uniq
    check("the line wraps into lines 18 px apart", [lines.size, lines[1] - lines[0]], [2, 18])

    # A new spot moves it the next frame without motion; the same spot sends nothing.
    sent = lambda { tree.changes.count { |change| Array(change["set"]).any? { |node, props| node == root.node && props.key?("at") } } }
    tree.changes.clear
    3.times { step.call }
    check("the same spot sends nothing", sent.call, 0)
    $box_top = 160
    tree.rects[root.node] = [8, 160, 288, 64]
    step.call
    check("a new spot reaches the tree the next frame, once, and the box stands there at once, still opaque",
          [sent.call, tree.nodes[root.node][:props]["at"], sprite.call.y, sprite.call.opacity], [1, [8, 160], 160, 255])
    $box_top = 232
    tree.rects[root.node] = [8, 232, 288, 64]
    step.call
    check("a spot that changes again on the next frame moves it on that frame too", [sent.call, sprite.call.y], [2, 232])

    # Out: 30 frames fading in place, in whole steps, gone on the last.
    box.hide
    going = (1..29).map { step.call }
    check("it fades out in place at the old box's opacity on each frame", going, (1..29).map { |n| [8, 255 - 255 * n / 30] })
    frame
    check("it is gone on the 30th frame", root.base_surface, nil)

    # A line that ends while its box slides in fades out where the box stands, from opaque.
    box = ui.show(Battle_Lines::Box, line: "Enough!")
    root = ui::Engine::Layer.tops.last.root.engine
    tree.rects[root.node] = [8, 232, 288, 64]
    stood = (1..5).map { step.call }.last[0]
    box.hide
    check("hidden on its fifth frame in, it fades from opaque where it stood", [stood, step.call, step.call],
          [8 - (296 * (1 - 5 / 15.0)**2).round, [stood, 255 - 255 / 30], [stood, 255 - 255 * 2 / 30]])

    # A box on the right at a spot slides in from the right edge.
    $box_top = 88
    right = ui.show(Battle_Lines::Box, line: "Hmph.", side: :right)
    right_root = ui::Engine::Layer.tops.last.root.engine
    tree.rects[right_root.node] = [344, 88, 288, 64]
    frame
    check("a box on the right comes from the right", right_root.base_surface.instance_variable_get(:@sprite).x, 344 + (296 * (14 / 15.0)**2).round)

    # At the battle's end the box goes in the same frame, without its fade.
    right.hide(at_once: true)
    check("hide(at_once: true) takes it off in the same frame [shown, pictures]", [right.shown?, right_root.base_surface], [false, nil])
  end
end
