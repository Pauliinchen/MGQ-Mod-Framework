#----------------------------------------------------------------
#  root_parts_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked that a tilemap left on a viewport the game frees is freed with it, as RGSS3 cannot move it
#                            - Checked that a plane left on a viewport the game frees moves onto a hidden one
#      Paulinchen  2026-11-08: Checked that a root that follows lies on the scene's top viewport, above the map's screen tone
#                            - Checked that a root that follows and opened hidden shows once it may
#      Paulinchen  2026-11-06: Checked that a root under the game's windows lies on the scene's top viewport, untouched by the screen's tone
#                            - Checked that a bubble draws its body see-through and what it holds whole
#                            - Kept only the viewports a scene freed, the menu scene and the roots that follow a character, which no layer test walks
#                            - Called the engine's classes by their names under UI::Engine
#                            - Dropped the bubbles given frames or a text, which a bubble no longer takes
#      Paulinchen  2026-11-05: Opened the speech bubbles without a text, which a bubble root holds as a part
#                            - Checked that a bubble draws on its picture, above the map's pictures, and stays over a CG
#                            - Checked that a bubble given a text shows it wrapped and follows a new one
#                            - Checked that the framework's pictures leave a viewport before the game frees it
#      Paulinchen  2026-11-04: Kept a few flows of the roots a mod opens and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the roots a mod opens, with the checks of
#                              marker_parts_test.rb
#                            - Checked a viewport counted as freed once RGSS refuses it
#                            - Checked a root under the game's windows tinted with the map's and the battle's screen tone, and
#                              one that keeps bright
#      Paulinchen  2026-11-01: Checked a picture whose viewport was freed, and a root fading out on or following a sprite on a
#                              viewport its scene freed
#                            - Checked a root that follows a character's sprite stacked with those on its tile, and on the
#                              character once the map rebuilds its sprites
#                            - Checked that a hidden root that follows a character leaves no room on its tile
#                            - Checked that a screen held by a name quiets the buttons under it
#                            - Checked a window that hosts its scene and a tree that takes no keys while a box outside it types
#                            - Covered a root whose menu scene another scene replaced, and an open refused telling close
#                            - Covered two roots with :menu opened in one frame
#                            - Checked a root that follows a character shown outside the scene's own map
#                            - Checked a root that follows a character at a height above its feet
#                            - Checked a root that follows hidden while it has no character to follow
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers what the roots under every window of the UI layer do that no layer test walks, in a
# booted game against FakeTree: viewports a scene freed, a menu scene of its own, and roots that
# follow a map character.

require_relative "tree_support"

# A scene of the map, which the free map asks for.
MAP_SCENE = lambda do
  Object.class_eval <<-RUBY
    class Scene_Base; def terminate; end; end
    class Scene_Map < Scene_Base; end
    class Scene_Battle < Scene_Base; end
    class Scene_MenuBase < Scene_Base; def start; end; def return_scene; $returned << self; end; end
    module SceneManager; def self.call(scene_class); $called << scene_class; end; end
    class Sprite_Character < Sprite
      attr_reader :character
      def initialize(viewport, character); super(viewport); @character = character; @src_rect = Rect.new(0, 0, 32, 32); end
    end
  RUBY
end

# The game's tilemap, which lies on a viewport and, as in RGSS3, cannot be moved onto another.
class Tilemap
  attr_reader :viewport

  # Makes a tilemap on a viewport.
  #
  # @param viewport [Viewport, nil] Its viewport, nil for the screen.
  def initialize(viewport = nil)
    @viewport = viewport
  end

  # Frees the tilemap.
  def dispose
    @disposed = true
  end

  # Tells whether the tilemap was freed.
  #
  # @return [Boolean] Whether it was.
  def disposed?
    @disposed ? true : false
  end
end

# The game's plane, which lies on a viewport and can be moved onto another.
class Plane
  attr_accessor :viewport

  # Makes a plane on a viewport.
  #
  # @param viewport [Viewport, nil] Its viewport, nil for the screen.
  def initialize(viewport = nil)
    @viewport = viewport
  end

  # Tells whether the plane was freed.
  #
  # @return [Boolean] Never, here.
  def disposed?
    false
  end
end

# A map character as the scenes' sprites show it: its place on the screen and on the map.
class FakeCharacter
  attr_accessor :screen_x, :screen_y, :x, :y, :transparent

  # Makes a character standing at a place.
  #
  # @param screen_x [Integer] Its middle on the screen.
  # @param screen_y [Integer] Its feet on the screen.
  def initialize(screen_x, screen_y)
    @screen_x, @screen_y, @x, @y = screen_x, screen_y, 5, 7
  end
end

# A character's sprite, 32 pixels high.
class FakeCharacterSprite < Sprite
  attr_reader :character

  # Makes the sprite of a character on a viewport.
  #
  # @param character [FakeCharacter] The character.
  # @param viewport [Viewport] The viewport.
  def initialize(character, viewport)
    super(viewport)
    @character = character
    @src_rect = Rect.new(0, 0, 32, 32)
  end
end

# A map scene with a spriteset of characters on a viewport the map shakes and tints, under its top
# viewport.
class CharacterScene
  # @return [Viewport] The viewport of the map and its characters.
  attr_reader :map

  # @return [Viewport] Its top viewport, which the map neither shakes nor tints.
  attr_reader :top

  # Makes the scene with the characters' sprites.
  #
  # @param characters [Array<FakeCharacter>] The characters.
  def initialize(characters)
    @map = Viewport.new
    @top = Viewport.new
    @spriteset = Object.new
    @spriteset.instance_variable_set(:@viewport1, @map)
    @spriteset.instance_variable_set(:@viewport3, @top)
    @spriteset.instance_variable_set(:@character_sprites, characters.map { |character| FakeCharacterSprite.new(character, @map) })
  end
end

# A menu scene whose spriteset shows no map character; the live map behind it lies elsewhere.
class MenuScene
end

# A scene with a spriteset whose top viewport lies over its pictures, under the game's windows.
class PictureScene
  # @return [Viewport] Its top viewport.
  attr_reader :top

  # Makes the scene and its spriteset.
  def initialize
    @top = Viewport.new
    @spriteset = Object.new
    @spriteset.instance_variable_set(:@viewport3, @top)
  end
end

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ui.edit.open") { |_request| 1 }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.view") { |_request| nil }
  boot_tree(fake, :game => MAP_SCENE) do
    ui = Mod_Framework::UI
    frame

    # Viewports a scene freed: the framework's pictures leave a viewport before the game frees it,
    # since RGSS ends the game without a word on a sprite freed after its viewport, and the frame
    # draws on (223ac085, bfe38aa9).
    after_free = []
    Sprite.class_eval do
      alias_method :test_dispose, :dispose
      define_method(:dispose) do
        after_free << self if viewport && viewport.instance_variable_get(:@disposed)
        test_dispose
      end
    end
    view = Viewport.new(0, 40)
    view.dispose
    check("a viewport counts as freed once RGSS refuses it", ui.freed?(view), true)
    view = Viewport.new(0, 40)
    picture = ui::Engine::SpriteSurface.new(nil, view)
    picture.place(0, 0, 10, 10, 0, nil)
    view.dispose
    picture.place(5, 6, 10, 10, 0, nil)
    sprite = picture.instance_variable_get(:@sprite)
    check("a picture whose viewport was freed moves onto the screen at its place", [sprite.viewport, sprite.x, sprite.y], [nil, 5, 6])
    picture.dispose
    ending = PictureScene.new
    $scene_now = ending
    fading = ui::Engine::Box.new(:at => [0, 0], :size => [100, 40], :under_windows => true, :frame => false, :fade => true, :keep => true).open
    map = $game_map
    $game_map = Struct.new(:screen).new(Struct.new(:tone).new(Tone.new(-255, -255, -255, 0)))
    frame
    10.times { Graphics.update }
    sprite = fading.base_surface.instance_variable_get(:@sprite)
    check("a root under the game's windows lies on the scene's top viewport, untouched by a dark screen tone [on it, its tone]",
          [sprite.viewport.equal?(ending.top), [sprite.tone.red, sprite.tone.green, sprite.tone.blue]], [true, [0, 0, 0]])
    $game_map = map
    fading.close
    ending.top.dispose
    Graphics.update
    check("a root fading out on the viewport its scene freed ends its fade", fading.base_surface, nil)
    check("the frame draws on", $logged.grep(/drawing the components FAILED/), [])
    $scene_now = :map

    # What the game left on a viewport it frees moves onto a hidden one, or is freed with it where it
    # cannot move, since RGSS ends the game when the collector frees it later (RGSS301.dll at
    # 0x111a1c).
    map_view = Viewport.new
    tilemap = Tilemap.new(map_view)
    parallax = Plane.new(map_view)
    map_view.dispose
    frame
    check("a plane left on a viewport the game frees moves onto a hidden viewport [moved, hidden, logged]",
          [!parallax.viewport.equal?(map_view), parallax.viewport.visible, $logged.grep(/moved 1 picture.*: Plane$/).size], [true, false, 1])
    check("a tilemap left on a viewport the game frees is freed with it [freed, logged]",
          [tilemap.disposed?, $logged.grep(/freed 1 picture.*: Tilemap$/).size], [true, 1])

    # A root with :menu opens in a menu scene of its own and goes back as it closes.
    $called = []
    $returned = []
    camp = ui::Engine::Window.new(:title => "Camp", :menu => true, :center => true, :width => 320)
    camp.open
    $scene_now = $called.last.new
    $scene_now.start
    camp.close
    check("it goes back from its scene as it closes", $returned, [$scene_now])
    $scene_now = :map
    lost = ui::Engine::Window.new(:title => "Camp", :menu => true, :width => 320)
    lost_whys = []
    lost.on(:close) { |why| lost_whys << why }
    lost.open
    $scene_now = Scene_Battle.new
    Scene_Base.new.terminate
    late = $called.last.new
    $scene_now = late
    late.start
    check("one whose menu scene another scene replaced closes with :scene", [lost_whys, lost.open?], [[:scene], false])
    refused_whys = []
    refused = ui::Engine::Window.new(:title => "Camp", :menu => true, :if => lambda { "A quest runs." })
    refused.on(:close) { |why| refused_whys << why }
    refused.open
    check("an open refused tells close with why", refused_whys, ["A quest runs."])
    $scene_now = :map

    # Roots that follow a map character stack above its head and hide while it does not show.
    baker = FakeCharacter.new(300, 200)
    $scene_now = CharacterScene.new([baker])
    $scene_now.map.ox = 2
    tag = ui::Engine::Box.new(:at => [0, 0], :size => [60, 20], :frame => false, :follow => baker)
    below = ui::Engine::Box.new(:at => [0, 0], :size => [40, 10], :frame => false, :follow => baker, :side => :below, :follow_gap => 2)
    second = ui::Engine::Box.new(:at => [0, 0], :size => [60, 20], :frame => false, :follow => baker)
    [tag, below, second].each { |root| root.keep = true; root.open }
    frame
    Graphics.update
    place = lambda { |root| sprite = root.base_surface.instance_variable_get(:@sprite); [sprite.x, sprite.y, sprite.viewport.equal?($scene_now.top)] }
    check("a root that follows lies above the character's head with the map's shake, on the top viewport above the map's screen tone",
          place.call(tag), [268, 144, true])
    bubble = ui::Engine::Bubble.new(:follow => baker, :keep => true).open
    frame
    Graphics.update
    bubble_sprite = bubble.base_surface.instance_variable_get(:@sprite)
    check("a bubble that follows draws its fill from its picture's corner", bubble.base_surface.bitmap.fills.first[0, 2], [0, 0])
    check("a bubble draws its body a little see-through and what it holds whole [its picture's opacity, its fill's alpha]",
          [bubble_sprite.opacity, bubble.base_surface.bitmap.fills.first[4][3].to_i], [255, ui::Engine::Bubble::OPACITY])
    $game_party = Struct.new(:in_novel).new(true)
    frame
    check("a bubble stays over its character while the game shows a CG", bubble.visible?, true)
    $game_party = nil
    bubble.close
    baker.transparent = true
    Graphics.update
    frame
    check("a root hides while its character does not show, here and in C#", [tag.visible?, tree.nodes[tag.node][:props]["visible"]], [false, false])
    baker.transparent = false
    Graphics.update
    [tag, below, second].each { |root| root.close }
    sprite = $scene_now.instance_variable_get(:@spriteset).instance_variable_get(:@character_sprites).first
    sprite.x = 284
    sprite.y = 168
    sprite_tag = ui::Engine::Box.new(:at => [0, 0], :size => [60, 20], :frame => false, :follow => sprite, :keep => true).open
    frame
    Graphics.update
    spriteset = $scene_now.instance_variable_get(:@spriteset)
    spriteset.instance_variable_get(:@character_sprites).each { |old| old.dispose }
    spriteset.instance_variable_set(:@character_sprites, [FakeCharacterSprite.new(baker, $scene_now.map)])
    frame
    Graphics.update
    check("a root that follows a sprite stays on the character once the map rebuilds its sprites", [sprite_tag.visible?, place.call(sprite_tag)], [true, [268, 144, true]])
    sprite_tag.close

    # A prompt that follows a character and opens while its :hide_while hides it, which C# places
    # nowhere, shows over the character once it may.
    battle_near = false
    prompt = ui::Engine::Box.new(:at => [0, 0], :size => [60, 20], :frame => false, :follow => baker, :hide_while => lambda { !battle_near }, :keep => true).open
    frame
    Graphics.update
    battle_near = true
    frame
    Graphics.update
    check("a root that follows and opened hidden by its :hide_while shows over its character once it may",
          [prompt.visible?, prompt.base_surface && place.call(prompt)], [true, [268, 144, true]])
    prompt.close

    # Following a character whose sprite lies outside the scene's map, until a scene frees it (223ac085).
    $scene_now = MenuScene.new
    live_map = Viewport.new
    stranger = FakeCharacter.new(100, 120)
    Sprite_Character.new(live_map, stranger).dispose
    Sprite_Character.new(live_map, stranger)
    behind = ui::Engine::Box.new(:at => [0, 0], :size => [60, 20], :frame => false, :follow => stranger, :keep => true).open
    frame
    Graphics.update
    sprite = behind.base_surface.instance_variable_get(:@sprite)
    check("a root follows a character shown outside the scene's map on that sprite's viewport",
          [behind.visible?, sprite.x, sprite.y, sprite.viewport.equal?(live_map)], [true, 70, 64, true])
    live_map.dispose
    frame
    Graphics.update
    check("it hides once a scene freed that viewport", behind.visible?, false)
    check("the frame draws on after the viewport was freed", $logged.grep(/drawing the components FAILED/), [])
    check("no picture of the framework is freed after its viewport, and none is left noted on a freed one",
          [after_free.size, ui::Engine::ViewportSprites.viewports], [0, 0])
    behind.close
    $scene_now = :map
  end
end
