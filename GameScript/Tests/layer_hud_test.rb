#----------------------------------------------------------------
#  layer_hud_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that the status line draws nothing once its column leaves it no room
#                            - Checked that a tag keeps no least size of a floating box
#                            - Let the tags keep the gap of every hud that follows a character
#                            - Called the engine's classes by their names under UI::Engine
#                            - Checked a banner that slides in from the left edge and out again as it hides
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers hud of the UI layer (design v2 sections 5.1 and 5.7) in a booted game against FakeTree,
# through a mod's camp HUD: a leader box that hides under the game's top message and whose size
# button a click presses, a status line the pointer passes through that draws nothing without room
# and hides while the mod says so, name tags that follow a map event by its id, as large as what they
# hold, and stack on its tile above the map's pictures, and a place's banner that slides in from the
# left edge and out again.

require_relative "layer_support"

CAMP_HUD = <<-RUBY
  module Camp_Hud
    UI = Mod_Framework::UI

    class Leader < UI::Component
      state :small, false

      def render
        hud anchor: :top_left, id: :camp_leader, hide_while: :top_message do
          text "Ana  Lv 30"
          button "size", id: :camp_size, on_click: -> { self.small = !small }
        end
      end
    end

    class Status < UI::Component
      def render
        hud anchor: :bottom_left, mouse: :none, hide_while: -> { $camp_quiet } do
          stack tail: true, height: 48, id: :camp_lines do
            text "The relay dropped. one two three four five six seven eight nine", wrap: true, id: :camp_line
          end
        end
      end
    end

    class Banner < UI::Component
      def render
        hud anchor: :top_left, enter: :slide, id: :camp_banner, width: 200, height: 40, hide_while: -> { $camp_banner_gone } do
          text "Harpy Village"
        end
      end
    end

    class Tag < UI::Component
      param :tag_id
      param :line

      def render
        hud id: tag_id, follow: 3, width: 120, height: 20 do
          text line
        end
      end
    end
  end
RUBY

# The game's message as far as a HUD reads it: whether it shows and where.
class CampMessage
  attr_accessor :visible, :position

  # Makes a message that does not show, at the bottom.
  def initialize
    @visible = false
    @position = 2
  end

  # Tells whether the message is busy, as the free map asks.
  #
  # @return [Boolean] Whether it shows.
  def busy?
    @visible
  end
end

# A map event as its sprite shows it: its middle and feet on the screen and its tile.
class CampEvent
  attr_accessor :screen_x, :screen_y, :x, :y, :transparent

  # Makes an event standing at a place.
  #
  # @param screen_x [Integer] Its middle on the screen.
  # @param screen_y [Integer] Its feet on the screen.
  def initialize(screen_x, screen_y)
    @screen_x, @screen_y, @x, @y = screen_x, screen_y, 5, 7
  end
end

# The sprite of a map event, 32 pixels high.
class CampEventSprite < Sprite
  attr_reader :character

  # Makes the sprite of an event on a viewport.
  #
  # @param character [CampEvent] The event.
  # @param viewport [Viewport] The viewport.
  def initialize(character, viewport)
    super(viewport)
    @character = character
    @src_rect = Rect.new(0, 0, 32, 32)
  end
end

# A map scene whose spriteset shows the events on the map's viewport.
class CampMapScene
  # @return [Viewport] The map's viewport.
  attr_reader :map

  # Makes the scene with the events' sprites.
  #
  # @param events [Array<CampEvent>] The events.
  def initialize(events)
    @map = Viewport.new
    @spriteset = Object.new
    @spriteset.instance_variable_set(:@viewport1, @map)
    @spriteset.instance_variable_set(:@character_sprites, events.map { |event| CampEventSprite.new(event, @map) })
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Hud.rb", CAMP_HUD)
    $game_message = CampMessage.new
    frame

    # The leader box docks at the top left, the pointer only on its button, which a click presses.
    ui.show(Camp_Hud::Leader)
    frame
    Graphics.update
    leader = ui::Engine::Layer.tops.last
    leader_props = lambda { tree.nodes[leader.root.engine.node][:props] }
    check("the leader box in its zone, the pointer on its parts only", leader_props.call.values_at("dock", "mouse", "mouse_parts"), ["top_left", true, true])
    tell(tree, [[leader.root.engine.find(:camp_size).node, "click"]])
    check("a click on its size button", leader.mount.component.small, true)

    # It hides while the game's message shows at the top, not while one shows at the bottom.
    $game_message.visible = true
    frame
    check("the leader box under a message at the bottom", leader_props.call["visible"], true)
    $game_message.position = 0
    frame
    check("the leader box under a message at the top", leader_props.call["visible"], false)
    $game_message.visible = false
    frame
    check("the leader box once the message closed", leader_props.call["visible"], true)

    # The status lines let the pointer through everywhere, keep the last lines of a long notice
    # and hide while the mod says so.
    ui.show(Camp_Hud::Status)
    frame
    lines = ui::Engine::Layer.tops.last.root.engine
    status = tree.nodes[lines.node][:props]
    check("the status lines take no pointer", status.values_at("mouse", "mouse_parts"), [false, false])
    tree.rects[lines.find(:camp_line).node] = [0, 0, 100, 48]
    frame
    Graphics.update
    shown = lines.base_surface.bitmap.texts.map { |text| text[2] }
    check("the status lines show the notice's last lines, not its first [its first line shown, lines shown]",
          [shown.include?("The relay"), shown.size], [false, 2])
    tree.rects[lines.find(:camp_line).node] = [0, 0, 100, 0]
    frame
    Graphics.update
    check("the status line once its column leaves it no room", lines.base_surface.bitmap.texts.map { |text| text[2] }, [])
    $camp_quiet = true
    frame
    check("the status lines while the mod keeps them quiet", status["visible"], false)

    # Two tags follow event 3 above its head on the map's viewport, the second above the first,
    # over the map's pictures; neither takes a zone's room or a stored place.
    event = CampEvent.new(300, 200)
    $game_map = Struct.new(:events).new({ 3 => event })
    $scene_now = CampMapScene.new([event])
    first = ui.show(Camp_Hud::Tag, tag_id: :camp_herbalist, line: "Herbalist")
    second = ui.show(Camp_Hud::Tag, tag_id: :camp_herbs, line: "Sells herbs")
    frame
    Graphics.update
    sprite_of = lambda do |handle|
      top = ui::Engine::Layer.tops.find { |each| each.id == handle.id }
      top.root.engine.base_surface.instance_variable_get(:@sprite)
    end
    place = lambda { |handle| sprite = sprite_of.call(handle); [sprite.x, sprite.y, sprite.viewport.equal?($scene_now.map)] }
    check("the first tag over the event's head on the map's viewport", place.call(first), [240, 144, true])
    check("the second tag stacked above it", place.call(second), [240, 120, true])
    check("the tag above the map's pictures", sprite_of.call(first).z > ui::PICTURES_TOP, true)
    tag_node = ui::Engine::Layer.tops.find { |each| each.id == first.id }.root.engine.node
    check("the tag in no zone and with no stored place", [tree.nodes[tag_node][:props]["dock"], $registered.any? { |request| request[0].to_s.include?("camp_herb") }],
          [nil, false])
    check("the tag keeps no least size of a floating box", tree.nodes[tag_node][:props]["min"], nil)
    event.transparent = true
    frame
    check("the tag while the event is see-through", tree.nodes[tag_node][:props]["visible"], false)

    # The place's banner slides in from the left edge to its place at the top left as it fades in,
    # and out to the left again as it hides.
    banner = ui.show(Camp_Hud::Banner)
    banner_root = ui::Engine::Layer.tops.find { |each| each.id == banner.id }.root.engine
    tree.rects[banner_root.node] = [8, 8, 200, 40]
    left_of = lambda { frame; Graphics.update; banner_root.base_surface.instance_variable_get(:@sprite).x }
    coming = (1..ui::Engine::Style::FADE_FRAMES).map { left_of.call }
    check("the banner slides in from the left [first frame off its place to the left, closer each frame, at its place]",
          [coming.first < -100, coming.each_cons(2).all? { |a, b| a <= b }, coming.last], [true, true, 8])
    $camp_banner_gone = true
    going = (1..ui::Engine::Style::FADE_FRAMES - 1).map { left_of.call }
    check("the banner slides out to the left as it hides", [going.first < 8, going.each_cons(2).all? { |a, b| a >= b }, going.last < -100], [true, true, true])
  end
end
