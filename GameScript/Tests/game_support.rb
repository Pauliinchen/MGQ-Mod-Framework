#----------------------------------------------------------------
#  game_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Let a viewport be hidden, as RGSS's is
#      Paulinchen  2026-11-07: Gave the font the default outline color of the game
#      Paulinchen  2026-11-05: Let a tone take another tone's values, as RGSS does
#                            - Let a sprite take a tone's values, as RGSS copies them
#                            - Gave the stand-in sprite its source rectangle and the rectangle set, as RGSS has them
#      Paulinchen  2026-11-04: Answered a color's values as Floats, as RGSS does
#                            - Refused every call on a freed viewport and gave it no disposed?, as RGSS's viewport has none
#                            - Noted where a text lands as it lines up in its box
#                            - Moved a text by the blanks before it, which draw nothing, and noted the room its box keeps
#                              left of its first letter
#                            - Forgot what was drawn inside a rectangle cleared, and copied only what lies in the part of
#                              a picture copied
#                            - Gave the sprite its tone
#      Paulinchen  2026-11-01: Freed a viewport, whose place RGSS then refuses to tell
#                            - Carried what a copied picture holds over onto the picture it is copied onto
#      Paulinchen  2026-10-31: Let a game window fade
#                            - Gave the sprite its origin
#      Paulinchen  2026-10-29: Stood in for the game's viewport and kept a sprite's viewport
#                            - Gave the font a name and a slant
#      Paulinchen  2026-10-28: Stood in for the place, size, depth, opening and contents of the game's windows
#                            - Noted the pictures copied onto a picture and stood in for a sprite's shown part
#                            - Stood in for the game's sprite
#                            - Created
#
#----------------------------------------------------------------

# Stand-ins for what RGSS and the game give the scripts that draw: colors, tones, rects, fonts,
# pictures that note what is drawn on them, sprites, the game's window skin in its cache, and the
# game's Window_Base and DataManager, which a new game session makes anew.

# The game's color, opaque unless told otherwise.
class Color
  attr_accessor :red, :green, :blue, :alpha

  # Makes a color.
  #
  # @param red [Numeric] Its red.
  # @param green [Numeric] Its green.
  # @param blue [Numeric] Its blue.
  # @param alpha [Numeric] Its alpha.
  def initialize(red = 0, green = 0, blue = 0, alpha = 255)
    @red, @green, @blue, @alpha = red.to_f, green.to_f, blue.to_f, alpha.to_f
  end

  # Lists its values.
  #
  # @return [Array<Numeric>] Red, green, blue and alpha.
  def to_a
    [@red, @green, @blue, @alpha]
  end
end

# The game's tone.
class Tone
  attr_reader :red, :green, :blue, :gray

  # Makes a tone.
  #
  # @param values [Array<Numeric>] Red, green, blue and gray.
  def initialize(*values)
    set(*values)
  end

  # Sets the tone.
  #
  # @param red [Numeric] Its red.
  # @param green [Numeric] Its green.
  # @param blue [Numeric] Its blue.
  # @param gray [Numeric] Its gray.
  def set(red = 0, green = 0, blue = 0, gray = 0)
    red, green, blue, gray = red.to_a if red.is_a?(Tone)
    @red, @green, @blue, @gray = red, green, blue, gray
  end

  # Lists its values.
  #
  # @return [Array<Numeric>] Red, green, blue and gray.
  def to_a
    [@red, @green, @blue, @gray]
  end
end

# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height) do
  # Sets all four at once, as RGSS's Rect does.
  #
  # @param x [Integer] The left.
  # @param y [Integer] The top.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  # @return [Rect] Itself.
  def set(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self
  end
end

# The game's font.
Font = Struct.new(:size, :color, :bold, :outline, :out_color, :name, :italic)

# Tells the outline color every font of the game starts with, half see-through black.
#
# @return [Color] The color.
def Font.default_out_color
  Color.new(0, 0, 0, 128)
end

# What draw_text does with the blanks before a text: they draw nothing and only move the text, so
# a picture notes the text without them, where its first letter lands, and the room its box keeps
# left of that letter, where an outline reaching left of the letter goes.
module LeadingBlanks
  # Draws a text without the blanks before it, moved by their width.
  def draw_text(x, y, width, height, text, align = 0)
    shown = text.to_s.sub(/\A +/, "")
    lead = text_size(text.to_s[0, text.to_s.size - shown.size]).width
    (@rooms ||= {})[shown] = landing(x + lead, width - lead, shown, align) - x
    super(x + lead, y, width - lead, height, shown, align)
  end
end

# A picture that notes the fills, texts and pictures drawn on it.
class Bitmap
  prepend LeadingBlanks

  attr_reader :width, :height, :font, :fills, :texts, :copies

  # Makes an empty picture in a white font of 24.
  #
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  def initialize(width, height)
    @width = width
    @height = height
    @font = Font.new(24, Color.new(255, 255, 255))
    @fills = []
    @texts = []
    @copies = []
  end

  # Tells the picture's whole rectangle.
  #
  # @return [Rect] The rectangle.
  def rect
    Rect.new(0, 0, @width, @height)
  end

  # Measures a text at half the font's size a character.
  #
  # @param text [String] The text.
  # @return [Rect] Its size.
  def text_size(text)
    Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size)
  end

  # Notes a text drawn with the place it lands on as it lines up in its box.
  def draw_text(x, y, width, _height, text, align = 0)
    @texts << [landing(x, width, text, align), y, text]
  end

  # Tells the room each text's box kept left of its first letter.
  #
  # @return [Hash{String => Integer}] The pixels by text.
  def rooms
    @rooms || {}
  end

  # Tells where a text drawn into a box lands as it lines up there, as draw_text puts it.
  #
  # @param x [Integer] The box's left.
  # @param width [Integer] Its width.
  # @param text [String] The text.
  # @param align [Integer] 0 for left, 1 for centered, 2 for right.
  # @return [Integer] The text's left.
  def landing(x, width, text, align)
    room = width - text_size(text).width
    x + (align == 1 ? room / 2 : (align == 2 ? room : 0))
  end

  # Notes a fill with its rectangle and its color's values.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, width, height, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, width, height, color.to_a]
  end

  # Notes a picture copied with its place; a picture something was drawn on, such as a list's cell,
  # shows here as what was drawn on it, moved by the place: its texts, fills and copies, the scaled
  # copies a test's picture notes, and the colors, sizes and widths it notes by text. Of a part of
  # a picture, only what starts inside that part shows.
  def blt(x, y, source, rect, _opacity = 255)
    drawn = source.is_a?(Bitmap) && !(source.texts.empty? && source.fills.empty? && source.copies.empty?)
    return @copies << [x, y, source] unless drawn

    whole = [rect.x, rect.y, rect.width, rect.height] == [0, 0, source.width, source.height]
    inside = lambda { |left, top| whole || (left >= rect.x && left < rect.x + rect.width && top >= rect.y && top < rect.y + rect.height) }
    x -= rect.x
    y -= rect.y
    @texts.concat(source.texts.select { |left, top, _text| inside.call(left, top) }.map { |left, top, text| [left + x, top + y, text] })
    @fills.concat(source.fills.select { |fill| inside.call(fill[0], fill[1]) }.map { |fill| [fill[0] + x, fill[1] + y] + fill[2..-1] })
    @copies.concat(source.copies.select { |left, top, _picture| inside.call(left, top) }.map { |left, top, picture| [left + x, top + y, picture] })
    stretched = source.instance_variable_get(:@stretches)
    (@stretches ||= []).concat(stretched.map { |rect, part, picture| [[rect[0] + x, rect[1] + y, rect[2], rect[3]], part, picture] }) if stretched
    [:@colors, :@sizes, :@widths, :@rooms].each do |name|
      noted = source.instance_variable_get(name)
      instance_variable_set(name, (instance_variable_get(name) || {}).merge(noted)) if noted
    end
  end

  # Notes a picture copied scaled with its place.
  def stretch_blt(rect, source, _source_rect, _opacity = 255)
    @copies << [rect.x, rect.y, source]
  end

  # Forgets what was drawn starting inside a rectangle.
  #
  # @param args [Array] A Rect, or its left, top, width and height.
  def clear_rect(*args)
    x, y, width, height = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height] : args
    inside = lambda { |left, top| left >= x && left < x + width && top >= y && top < y + height }
    @texts.reject! { |text| inside.call(text[0], text[1]) }
    @fills.reject! { |fill| inside.call(fill[0], fill[1]) }
    @copies.reject! { |copy| inside.call(copy[0], copy[1]) }
  end

  # Forgets the fills, texts and copies.
  def clear
    @fills.clear
    @texts.clear
    @copies.clear
  end

  # Frees the picture.
  def dispose
    @disposed = true
  end

  # Tells whether the picture was freed.
  #
  # @return [Boolean] Whether it was.
  def disposed?
    @disposed ? true : false
  end
end

# The game's sprite.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :visible, :src_rect, :opacity
  attr_reader :viewport

  # Makes a visible, opaque sprite at the top left.
  #
  # @param viewport [Viewport, nil] Its viewport, nil for the screen.
  def initialize(viewport = nil)
    @viewport = viewport
    @x = @y = @z = @ox = @oy = 0
    @visible = true
    @opacity = 255
    @src_rect = Rect.new(0, 0, 0, 0)
  end

  # Tells the sprite's tone, none at first.
  #
  # @return [Tone] The tone.
  def tone
    @tone ||= Tone.new(0, 0, 0, 0)
  end

  # Sets the sprite's tone to the values of another, as RGSS copies them.
  #
  # @param other [Tone] The tone.
  def tone=(other)
    tone.set(other.red, other.green, other.blue, other.gray)
  end

  # Frees the sprite.
  def dispose
    @disposed = true
  end

  # Tells whether the sprite was freed.
  #
  # @return [Boolean] Whether it was.
  def disposed?
    @disposed ? true : false
  end
end

# The error RGSS raises on a freed graphics object.
class RGSSError < StandardError
end

# The game's viewport: a part of the screen its sprites show in, scrolled by an offset. As in RGSS,
# it has no disposed?, and every call on it raises once it was freed.
class Viewport
  attr_writer :rect, :ox, :oy, :z
  attr_accessor :visible

  # Makes a viewport over a part of the screen, not scrolled.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  def initialize(x = 0, y = 0, width = 640, height = 480)
    @rect = Rect.new(x, y, width, height)
    @ox = @oy = @z = 0
  end

  # Tells the part of the screen it covers.
  #
  # @return [Rect] The part.
  def rect
    alive!
    @rect
  end

  # Tells how far it is scrolled to the right.
  #
  # @return [Integer] The pixels.
  def ox
    alive!
    @ox
  end

  # Tells how far it is scrolled down.
  #
  # @return [Integer] The pixels.
  def oy
    alive!
    @oy
  end

  # Tells its depth among the viewports.
  #
  # @return [Integer] The depth.
  def z
    alive!
    @z
  end

  # Frees the viewport, as a scene that ends frees its spriteset's.
  def dispose
    @disposed = true
  end

  private

  # Refuses a call once the viewport was freed, as RGSS does.
  #
  # @raise [RGSSError] It was freed.
  def alive!
    raise RGSSError, "disposed viewport" if @disposed
  end
end

# The game's window skin: a grey background, a frame of a black rim and a white line, a see-through
# white cursor and the palette's white normal and blue system text colors.
class GameSkin < Bitmap
  # Makes the skin.
  def initialize
    super(128, 128)
  end

  # Tells the color of a pixel.
  #
  # @param x [Integer] Its column.
  # @param y [Integer] Its row.
  # @return [Color, nil] Its color.
  def get_pixel(x, y)
    return Color.new(60, 60, 60, 255) if x < 64 && y < 64
    return [Color.new(0, 0, 0, 255), Color.new(255, 255, 255, 255), Color.new(128, 128, 128, 255)][y] || Color.new(0, 0, 0, 0) if x == 96 && y < 16

    { [80, 80] => Color.new(255, 255, 255, 32), [64, 96] => Color.new(255, 255, 255, 255), [64, 112] => Color.new(132, 170, 255, 255) }[[x, y]]
  end
end

# The game's cache of the pictures in Graphics/System.
module Cache
  # The game's window skin.
  SKIN = GameSkin.new

  # Hands out a picture of Graphics/System.
  #
  # @param name [String] The picture's name.
  # @return [Bitmap] The window skin for "Window", else an empty picture.
  def self.system(name)
    name == "Window" ? SKIN : Bitmap.new(24, 24)
  end
end

# Makes the game's Window_Base and DataManager anew, without what an earlier session hooked into
# them: a window in the game's skin, a background opacity of 192 and the tone of the game's window
# color, which its update sets again; it counts each skin it is given, and has a place, a size, a
# depth, the game's padding of 12, contents, and an opening of 48 a frame once open is called.
def define_game_windows
  Object.send(:remove_const, :Window_Base) if defined?(Window_Base)
  Object.send(:remove_const, :DataManager) if defined?(DataManager)
  Object.class_eval <<-RUBY
    class Window_Base
      attr_accessor :back_opacity, :tone, :x, :y, :z, :width, :height, :visible, :openness, :contents, :padding, :opacity, :contents_opacity
      attr_reader :windowskin, :skins_given
      def initialize(x = 0, y = 0, width = 32, height = 32)
        @x, @y, @width, @height, @z, @visible, @openness, @padding = x, y, width, height, 100, true, 255, 12
        @contents = Bitmap.new(1, 1)
        @skins_given = 0; self.windowskin = Cache.system("Window"); @back_opacity = 192; @tone = Tone.new; update_tone
      end
      def windowskin=(skin); @skins_given += 1; @windowskin = skin; end
      def move(x, y, width, height); @x, @y, @width, @height = x, y, width, height; end
      def open; @opening = true if @openness < 255; self; end
      def update; update_tone; @openness = [@openness + 48, 255].min if @opening; end
      def update_tone; tone.set(*$game_system.window_tone.to_a) if $game_system; end
      def dispose; @disposed = true; end
      def disposed?; @disposed ? true : false; end
    end
    module DataManager
      def self.create_game_objects; end
      def self.load_game_without_rescue(_index); true; end
    end
  RUBY
end
