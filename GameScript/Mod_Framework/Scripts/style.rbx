#----------------------------------------------------------------
#  style.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Calmed the green of good values to match the theme's success green
#      Paulinchen  2026-11-08: Greyed the faces of a face sheet by the sheet's name
#      Paulinchen  2026-11-07: Outlined a text in the outline that contrasts with it only under contrast
#                            - Outlined every text in black unless a mod asks for the outline that contrasts or a color
#      Paulinchen  2026-11-06: Outlined a text in text_light only where the dark outline contrasts too little with it
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Kept a value between two bounds without making lists
#                            - Outlined a text in text_light where it contrasts more with it than with text_dark, else in the dark outline
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Added the map band of the roots that follow a character
#                            - Added the band of the popups, above every window and dialog
#                            - Dropped the depth of the cover of a key row waiting for its key, which C#'s tree now holds
#                            - Let a palette find an animated color name as drawn in its preset, and the color it has now
#                            - Drew a box's background and frame at an opacity, if asked
#      Paulinchen  2026-11-04: Added the band of depths of each layer and put the notices above the dialogs
#                            - Let a palette find every color name of its preset, the old names of the text colors too
#                            - Let a tertiary color follow the edge and a button's look take a text color of its own
#                            - Told the text on a part filled in a color, as C# picks it
#                            - Greyed out the colors, icons and pictures a part that takes no input draws in, its text
#                              kept readable on the window
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-31: Left the close hint to UI.close_hint, which names the cancel key as F1 binds it
#                            - Gave the notices box its depth
#      Paulinchen  2026-10-30: Added the depth of a key row waiting for its key
#      Paulinchen  2026-10-29: Added the depth of an open Wheel
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # Side of an icon of the game's iconset, in pixels.
    ICON_SIZE = 24

    # Icons in a row of the game's iconset.
    ICONS_PER_ROW = 16

    # Pixels an icon takes in a row with the room after it.
    ICON_STEP = ICON_SIZE + 2

    # Frames the game draws in a second, which a timer counted in frames lapses by.
    FRAMES_PER_SECOND = 60

    # How seconds are written, such as a timer's rest.
    SECONDS_TEXT = "%d s"

    # What a last row says once more lines wait than a box has rows for, see capped.
    MORE_TEXT = "+%d more"

    # The depths of the sprites and windows above the game's, by layer, lowest first; :wheels also
    # holds what lies above a screen's windows, :open_wheel is a framework Wheel, which takes every
    # key while it is open, and :popups what a part opens, such as a select's menu. Each lies in its
    # band of BANDS.
    Z = { :arrows => 190, :lines => 200, :hud => 200, :labels => 250, :bubbles => 260, :wheels => 300, :over => 300, :overview => 400, :boxes => 1000,
          :windows => 1000, :open_wheel => 1045, :confirm => 1050, :dialogs => 1050, :popups => 1080, :notices => 1090, :tooltips => 1095,
          :typing => 1100, :layout => 1200 }

    # The depths each layer's roots take, lowest first: a root's z: orders it within its band only.
    # The map band and the HUD band lie on the scene's top viewport, the map band under a wheel that
    # follows and the HUD band lifted above every picture; :over lies above the game's windows.
    BANDS = { :map => 260..289, :hud => 190..299, :over => 300..399, :windows => 1000..1039, :open_wheel => 1045..1045, :dialogs => 1050..1079,
              :popups => 1080..1089,
              :notices => 1090..1090, :tooltips => 1095..1095, :typing => 1100..1100, :arranging => 1200..1200 }

    # The highest depth the game gives a picture (250 and the picture's number, up to 100), which
    # every root drawn on the pictures lies above.
    PICTURES_TOP = 350

    module Engine
      # What every flat box draws with: one background in one frame, one plate behind a line on a busy
      # picture, one picked row, one set of text colors, one set of font sizes, one padding, one solid
      # outline and the timings of the fades and slides.
      #
      # The colors from BACK to TAB are the interface preset's: Theme sets them in place, so a constant
      # elsewhere that names one of them follows the preset too, and a copy of one would not. A part
      # drawn in another preset than the player's passes that preset's Palette to the drawing methods.
      module Style
        # Background of every flat box and floating panel.
        BACK = Color.new(0, 0, 0, 170)

        # Plate behind one line of text that stands on a busy picture.
        PLATE = Color.new(0, 0, 0, 150)

        # Background of the picked row, box or choice.
        PICKED = Color.new(48, 96, 176, 220)

        # Opaque background of a text field being typed into inside a flat box.
        FIELD = Color.new(12, 16, 28)

        # Headings, places' headings and key hints.
        HEADING = Color.new(160, 200, 255)

        # Thin frame of every flat box, of tabs and of a gauge.
        EDGE = Color.new(140, 140, 140, 220)

        # A scrollbar's track, a lane a shade lighter than the box under its thumb; at least as opaque
        # as the box, since fill_rect replaces the pixels and a see-through track would cut a hole down
        # to the map.
        TRACK = Color.new(48, 48, 48, 200)

        # Line around the edge, see draw_frame; fully see-through for a preset whose frame is the edge
        # alone.
        RIM = Color.new(0, 0, 0, 0)

        # A box's title.
        TITLE = Color.new(255, 255, 255)

        # Empty part of a gauge.
        WELL = Color.new(0, 0, 0, 220)

        # Background of a tab that is not picked, the edge's color darkened.
        TAB = Color.new(64, 64, 64, 170)

        # Solid black outline of every text and gauge frame; the game's own outline is half see-through.
        OUTLINE = Color.new(0, 0, 0, 255)

        # The outline that contrasts with a dark text where the palette names no text_light.
        TEXT_LIGHT_OUTLINE = Color.new(255, 255, 255, 255)

        # The outline of a text of a part with contrast: the one that contrasts with the text, see
        # outline_for.
        CONTRAST_OUTLINE = :contrast

        # The least contrast of a text with text_dark, as WCAG measures it, for the dark outline of
        # outline_for; a grey text with the light outline blurs.
        OUTLINE_CONTRAST = 3.0

        # Pixels the outline's copies reach around a text, see draw_outlined.
        OUTLINE_REACH = 1

        # Plain text.
        TEXT = Color.new(255, 255, 255)

        # Secondary text: hints, places, system lines.
        DIM = Color.new(176, 176, 176)

        # Fine: online, confirmed, a value that got better.
        GOOD = Color.new(92, 184, 92)

        # Middling.
        WARN = Color.new(255, 224, 96)

        # Wrong: missing, failed, a value that got worse.
        BAD = Color.new(255, 96, 96)

        # Stands out: an essential mod, a featured entry.
        GOLD = Color.new(255, 200, 64)

        # The player themself: their own name and their own lines.
        OWN = Color.new(255, 225, 110)

        # A party member's name, the same color as GOOD on purpose.
        MEMBER = GOOD

        # Font size of a box's title.
        TITLE_SIZE = 20

        # Font size of text and items.
        TEXT_SIZE = 18

        # Font size of notices, small lines and hints.
        SMALL_SIZE = 16

        # Font size of column titles and places under a name.
        TINY_SIZE = 14

        # Room between a box's edge and its text, and a plate's margin on either side of its text.
        PAD = 6

        # Room between two columns or two tabs of a box.
        GAP = 4

        # What lies between two parts of a hint, such as "Up and down: move" and what closes the box.
        HINT_GAP = "   "

        # Frames a sprite takes to fade in or out.
        FADE_FRAMES = 12

        # Frames a box takes to slide from its offset to its place.
        SLIDE_FRAMES = 8

        # Frames a transient line stays, such as a notice's message: three seconds.
        LINGER_FRAMES = 180

        # Width of a scrollbar.
        SCROLLBAR_WIDTH = 4

        # Least length of a scrollbar's thumb.
        SCROLLBAR_THUMB = 8

        # Sets a bitmap's font for the next text: its size and color, never bold, which smears the
        # game's pixel font, with the solid black outline unless another is asked for.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param size [Integer] The font's size.
        # @param color [Color] The text's color.
        # @param outline [Color, Symbol, Boolean, nil] The outline's color, or CONTRAST_OUTLINE for
        #   the one that contrasts with the color; anything else outlines in OUTLINE.
        def self.use_font(bitmap, size, color, outline = nil)
          font = bitmap.font
          font.size = size
          font.bold = false
          font.color = color
          font.outline = true
          font.out_color = outline.is_a?(Color) ? outline : (outline.equal?(CONTRAST_OUTLINE) ? outline_for(color) : OUTLINE)
        end

        # Tells the outline that contrasts with a text in a color: text_light round a text near
        # text_dark, whose contrast with it stays under OUTLINE_CONTRAST, else the dark outline.
        #
        # @param color [Color] The text's color.
        # @return [Color] The outline's color.
        def self.outline_for(color)
          palette = Palette.live
          light = palette.named(:text_light) || TEXT_LIGHT_OUTLINE
          dark = palette.named(:text_dark) || OUTLINE
          unless light.equal?(@outline_light) && dark.equal?(@outline_dark)
            @outline_light = light
            @outline_dark = dark
            @dark_texts = {}
          end
          key = (color.red.to_i << 16) | (color.green.to_i << 8) | color.blue.to_i
          dark_text = @dark_texts[key]
          dark_text = @dark_texts[key] = contrast(color, dark) < OUTLINE_CONTRAST if dark_text.nil?
          dark_text ? light : OUTLINE
        end

        # Tells the WCAG contrast ratio of two colors.
        #
        # @param one [Color] A color.
        # @param other [Color] The other.
        # @return [Float] The ratio, from 1 to 21.
        def self.contrast(one, other)
          mine = luminance(one)
          theirs = luminance(other)
          ((mine > theirs ? mine : theirs) + 0.05) / ((mine > theirs ? theirs : mine) + 0.05)
        end

        # Tells a color's relative luminance as WCAG defines it, as C#'s Rgba works it out.
        #
        # @param color [Color] The color.
        # @return [Float] The luminance, from 0 for black to 1 for white.
        def self.luminance(color)
          0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        end

        # Turns one sRGB part into its linear light.
        #
        # @param part [Numeric] The part, 0 to 255.
        # @return [Float] Its linear light, 0 to 1.
        def self.linear(part)
          share = part.to_f / 255.0
          share <= 0.04045 ? share / 12.92 : ((share + 0.055) / 1.055)**2.4
        end
        private_class_method :linear

        # Draws a text in its solid outline: copies in OUTLINE straight above, below and beside it as
        # far as OUTLINE_REACH, the corners left out, then the text in the font's color, which stays
        # as it was.
        #
        # The font's own outline is off meanwhile: on each copy it would reach a pixel further, twice
        # as thick as OUTLINE_REACH.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] The box's left.
        # @param y [Integer] The box's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The box's height.
        # @param text [String] The text.
        # @param align [Integer] 0 for left, 1 for centered, 2 for right, as Bitmap#draw_text takes it.
        def self.draw_outlined(bitmap, x, y, width, height, text, align = 0)
          # Font#color returns the font's own color, which Font#color= overwrites, so only a copy keeps it.
          font_color = bitmap.font.color
          color = Color.new(font_color.red, font_color.green, font_color.blue, font_color.alpha)
          outline = bitmap.font.outline
          bitmap.font.outline = false
          reach = OUTLINE_REACH
          bitmap.font.color = OUTLINE
          (-reach..reach).each do |dx|
            (-reach..reach).each do |dy|
              next if (dx.zero? && dy.zero?) || (dx.abs == reach && dy.abs == reach)

              bitmap.draw_text(x + dx, y + dy, width, height, text, align)
            end
          end
          bitmap.font.color = color
          bitmap.draw_text(x, y, width, height, text, align)
          bitmap.font.outline = outline
        end

        # Fills the plate behind a text: as wide as the text with PAD on either side, capped by the
        # box's width, placed in the box by align. Nothing for an empty text. Measures with the
        # bitmap's font as it is set, so use_font comes first.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] The box's left.
        # @param y [Integer] The plate's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The plate's height.
        # @param text [String] The text.
        # @param align [Integer] 0 for left, 1 for centered, 2 for right.
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        # @return [Rect] The plate drawn, zero wide for an empty text.
        def self.draw_plate(bitmap, x, y, width, height, text, align = 1, palette = nil)
          return Rect.new(x, y, 0, height) if text.to_s.empty?

          plate_width = [UI.text_width(bitmap, text.to_s) + 2 * PAD, width].min
          left = align == 0 ? x : align == 2 ? x + width - plate_width : x + (width - plate_width) / 2
          plate = Rect.new(left, y, plate_width, height)
          bitmap.fill_rect(plate, colors(palette).plate)
          plate
        end

        # Draws a plated line in one call: draw_plate, then draw_outlined.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] The box's left.
        # @param y [Integer] The line's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The line's height.
        # @param text [String] The text.
        # @param align [Integer] 0 for left, 1 for centered, 2 for right.
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        # @return [Rect] The plate drawn.
        def self.draw_plated(bitmap, x, y, width, height, text, align = 1, palette = nil)
          plate = draw_plate(bitmap, x, y, width, height, text, align, palette)
          draw_outlined(bitmap, x, y, width, height, text, align)
          plate
        end

        # Draws a flat box: its background inside its frame, see draw_frame.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] The box's left.
        # @param y [Integer] The box's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The box's height.
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        # @param opacity [Integer, nil] How opaque its background and frame draw, nil for whole.
        def self.draw_box(bitmap, x, y, width, height, palette = nil, opacity = nil)
          bitmap.fill_rect(x, y, width, height, see_through(colors(palette).back, opacity))
          draw_frame(bitmap, x, y, width, height, nil, palette, opacity)
        end

        # Draws a box's frame along its inside: the rim outermost and the edge within it, or the edge
        # alone while the rim is see-through.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] The box's left.
        # @param y [Integer] The box's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The box's height.
        # @param edge [Color, nil] The edge's color, another than the palette's for a box that stands
        #   out, such as one being moved; nil for the palette's.
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        # @param opacity [Integer, nil] How opaque it draws, nil for whole.
        def self.draw_frame(bitmap, x, y, width, height, edge = nil, palette = nil, opacity = nil)
          look = colors(palette)
          inset = 0
          if look.rim.alpha.to_i > 0
            draw_line_box(bitmap, x, y, width, height, see_through(look.rim, opacity))
            inset = 1
          end
          draw_line_box(bitmap, x + inset, y + inset, width - 2 * inset, height - 2 * inset, see_through(edge || look.edge, opacity))
        end

        # Tells a color drawn at an opacity: its alpha scaled by it.
        #
        # @param color [Color] The color.
        # @param opacity [Integer, nil] From 0 to 255, nil for whole.
        # @return [Color] The color, the same object at a whole opacity.
        def self.see_through(color, opacity)
          return color if opacity.nil? || opacity >= Motion::OPAQUE

          Color.new(color.red, color.green, color.blue, (color.alpha || Motion::OPAQUE) * opacity / Motion::OPAQUE)
        end

        # Tells how many pixels a box's frame takes on each side, which its content stays inside.
        #
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        # @return [Integer] 2 with a rim, else 1.
        def self.frame_width(palette = nil)
          colors(palette).rim.alpha.to_i > 0 ? 2 : 1
        end

        # Draws a rectangle's outline, one pixel thick, inside the rectangle.
        #
        # @param bitmap [Bitmap] The bitmap.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param color [Color] The line's color.
        def self.draw_line_box(bitmap, x, y, width, height, color)
          return if width <= 0 || height <= 0

          bitmap.fill_rect(x, y, width, 1, color)
          bitmap.fill_rect(x, y + height - 1, width, 1, color)
          bitmap.fill_rect(x, y + 1, 1, height - 2, color)
          bitmap.fill_rect(x + width - 1, y + 1, 1, height - 2, color)
        end

        # Draws a scrollbar: its track, and a thumb in the edge color as long as the share of the lines
        # in sight and placed by the first of them; nothing while every line fits.
        #
        # @param bitmap [Bitmap] The picture.
        # @param x [Integer] The bar's left.
        # @param y [Integer] The bar's top.
        # @param height [Integer] The bar's height.
        # @param first [Integer] The first line in sight.
        # @param shown [Integer] How many lines show at once.
        # @param total [Integer] How many lines there are.
        # @param palette [Palette, nil] The colors, nil for the player's preset.
        def self.draw_scrollbar(bitmap, x, y, height, first, shown, total, palette = nil)
          return if total <= shown || height <= 0

          look = colors(palette)
          thumb = [[height * shown / total, SCROLLBAR_THUMB].max, height].min
          top = y + (height - thumb) * [[first, 0].max, total - shown].min / (total - shown)
          bitmap.fill_rect(x, y, SCROLLBAR_WIDTH, height, look.track)
          bitmap.fill_rect(x, top, SCROLLBAR_WIDTH, thumb, look.edge)
        end

        # Draws a hint whole, centered in its box: a hint names its keys at its end, so it is never
        # cut; one wider than the box is drawn in TINY_SIZE instead, and the game squeezes what still
        # overflows into the box.
        #
        # @param bitmap [Bitmap] The picture.
        # @param x [Integer] The box's left.
        # @param y [Integer] The box's top.
        # @param width [Integer] The box's width.
        # @param height [Integer] The box's height.
        # @param hint [String] The hint.
        # @param size [Integer] Its font's size, SMALL_SIZE on a box, TINY_SIZE under a wheel.
        # @param color [Color] Its color, DIM on a box, HEADING under a wheel.
        def self.draw_hint(bitmap, x, y, width, height, hint, size = SMALL_SIZE, color = DIM)
          use_font(bitmap, size, color)
          use_font(bitmap, TINY_SIZE, color) if size > TINY_SIZE && UI.text_width(bitmap, hint) > width
          bitmap.draw_text(x, y, width, height, hint, 1)
        end

        # Fades a text's color for a line about to go: its alpha falls over the last FADE_FRAMES frames.
        #
        # @param color [Color] The color at its full strength.
        # @param frames [Integer] Frames the line has left; FADE_FRAMES or more leave the color as it is.
        # @return [Color] The color, the same object while nothing fades.
        def self.faded(color, frames)
          return color if frames >= FADE_FRAMES

          alpha = color.alpha || Motion::OPAQUE
          Color.new(color.red, color.green, color.blue, alpha * [frames, 0].max / FADE_FRAMES)
        end

        # Picks the colors a drawing method draws in.
        #
        # @param palette [Palette, nil] The colors asked for, nil for the player's preset.
        # @return [Palette] The palette.
        def self.colors(palette)
          palette || Palette.live
        end
      end

      # The colors of one look: the box colors a preset sets, from BACK to TAB in Style, read by their
      # names in lower case, such as back and edge, and every other color name it holds (named).
      class Palette
        # The box colors a preset sets, by their names in Style.
        ROLES = [:BACK, :PLATE, :PICKED, :FIELD, :HEADING, :EDGE, :TRACK, :RIM, :TITLE, :WELL, :TAB]

        # Style's text colors a preset sets, by their color names.
        TEXTS = { :text => :TEXT, :dim => :DIM, :success => :GOOD, :warning => :WARN, :error => :BAD, :gold => :GOLD, :own => :OWN }

        # The box colors by their color names.
        BOXES = Hash[ROLES.map { |role| [role.to_s.downcase.to_sym, role] }]

        # The old names of the text colors by the names that replaced them, which the engine's parts
        # still take.
        OLD_NAMES = { :good => :success, :warn => :warning, :bad => :error }

        # The palette roles that take another color name's color where the preset holds none, as
        # ThemeModel.Derived in C#; the game's own look holds no heading of its own.
        DERIVED = { :primary => :heading, :info => :heading, :system => :heading, :secondary => :gold, :tertiary => :edge, :ally => :success,
                    :default => :text }

        # @return [Theme::Preset, nil] The preset the colors are, nil for Style's own colors, which
        #   are whichever preset the player picked.
        attr_reader :preset

        # Reads each color by its name in lower case, such as back for BACK.
        #
        # @return [Color] The color.
        ROLES.each do |role|
          define_method(role.to_s.downcase) { @colors[role] }
        end

        # Hands out the palette of Style's own colors, which Theme sets in place to the player's
        # preset, so it always shows that preset.
        #
        # @return [Palette] The palette.
        def self.live
          @live ||= new(Hash[ROLES.map { |role| [role, Style.const_get(role)] }])
        end

        # Makes the palette of a preset's colors.
        #
        # @param preset [Theme::Preset] The preset, whose colors are red, green, blue and alpha by role.
        # @param values [Hash{Symbol => Array<Integer>}] The colors by Style's names, the preset's own
        #   with the game's for the box colors of the game's own look by default.
        # @return [Palette] The palette.
        def self.of(preset, values = Theme.colors_of(preset))
          named = {}
          (preset.roles || {}).each { |name, rgba| named[name] = Color.new(*rgba) }
          TEXTS.each { |name, constant| named[name] ||= Color.new(*values[constant]) if values[constant] }
          new(Hash[ROLES.map { |role| [role, Color.new(*values[role])] }], preset, named)
        end

        # Makes a palette.
        #
        # @param colors [Hash{Symbol => Color}] The box colors by role.
        # @param preset [Theme::Preset, nil] The preset they are, nil for Style's own colors.
        # @param named [Hash{Symbol => Color}, nil] Every other color name's color, nil for the
        #   player's preset, whose colors Style and Theme keep.
        def initialize(colors, preset = nil, named = nil)
          @colors = colors
          @preset = preset
          @named = named
        end

        # Finds a color name's color: a box color, a text color, a palette role such as :primary,
        # or a color name a mod added; the old names :good, :warn and :bad too. A role the preset
        # does not hold takes the color of the name it follows (DERIVED).
        #
        # @param name [Symbol] The name.
        # @return [Color, nil] The color, nil for a name the preset does not hold.
        def named(name)
          name = OLD_NAMES[name] || name
          box = BOXES[name]
          return @colors[box] if box
          return @named[name] if @named && @named.key?(name)

          constant = TEXTS[name]
          return Style.const_get(constant) if constant

          found = @named ? nil : Theme.live_role(name)
          found || (DERIVED[name] && named(DERIVED[name]))
        end

        # Finds an animated color name, such as :rainbow, as drawn in these colors' preset.
        #
        # @param name [Symbol] The name.
        # @param lift [Integer] How far an area in it lightens toward white, in percent.
        # @return [Animated, nil] The color, nil for a name that does not move.
        def animated(name, lift = 0)
          Colors.find(name, @preset || Theme.current, lift)
        end

        # Finds the color a name has now: as named finds it, and of an animated name its first
        # letter's color in this frame.
        #
        # @param name [Symbol] The name.
        # @return [Color, nil] The color, nil for a name nobody named.
        def now(name)
          named(name) || ((moving = animated(name)) && moving.colors(1)[0])
        end

        # Tells the look of a button's variant in a color in its preset, see Theme.button_look.
        #
        # @param variant [Symbol] :filled, :outlined or :text.
        # @param color [Symbol, Color, nil] The button's color.
        # @param text_color [Symbol, Color, nil] The button's own text color, nil for the preset's.
        # @return [Hash, nil] The look, nil without the DLL.
        def button_look(variant, color, text_color = nil)
          Theme.button_look(self, variant, color, text_color)
        end

        # Tells the text on a part filled in a color: text_dark or text_light, whichever C# finds
        # contrasts more with the fill, as on a filled button.
        #
        # @param fill [Symbol, Color] The fill.
        # @return [Symbol, Color] The text color; :text_dark without the DLL.
        def text_on(fill)
          look = button_look(:filled, fill)
          look ? look[:text] : :text_dark
        end

        # Reads a color by its name in Style.
        #
        # @param role [Symbol] The name, such as :BACK.
        # @return [Color] The color.
        def [](role)
          @colors[role]
        end

        # Tells the color a fill, a line or a text draws in with these colors: the color itself.
        #
        # @param color [Color] The color.
        # @return [Color] The color drawn.
        def drawn(color)
          color
        end

        # Tells the color a text draws in with these colors: the color itself.
        #
        # @param color [Color] The text's color.
        # @return [Color] The color drawn.
        def drawn_text(color)
          color
        end

        # Tells where an icon of the game's iconset is drawn from with these colors.
        #
        # @param icon [Integer] The icon's index.
        # @return [Array(Bitmap, Rect)] The iconset and the icon's place on it.
        def icon_source(icon)
          [Cache.system("Iconset"), UI.icon_rect(icon)]
        end

        # Tells where a part of a picture is drawn from with these colors.
        #
        # @param picture [Bitmap] The picture.
        # @param part [Rect] The part.
        # @return [Array(Bitmap, Rect)] The picture and the part.
        def picture_source(picture, part)
          [picture, part]
        end

        # Hands out these colors greyed out, which a part that takes no input draws in, made anew
        # once the theme's colors changed.
        #
        # @return [GreyedPalette] The palette.
        def greyed
          serial = Theme.serial
          return @greyed if @greyed && @greyed_serial == serial

          @greyed.dispose if @greyed
          @greyed_serial = serial
          @greyed = GreyedPalette.new(self)
        end
      end

      # The colors a part that takes no input draws in: those of another palette, each turned to its
      # grey and dimmed, moved towards the grey of the window's back. A text keeps at least
      # TEXT_CONTRAST against the window's back. Icons and pictures draw from greyed copies, each made
      # once per icon and per picture.
      class GreyedPalette < Palette
        # The share of its distance from the back's grey that a grey keeps.
        DIMMED = 0.5

        # The least contrast of a greyed text against the window's back, as WCAG measures it.
        TEXT_CONTRAST = 3.0

        # The most greyed copies of pictures it keeps, the oldest let go first.
        PICTURES_KEPT = 32

        # How strongly red, green and blue count towards a color's grey.
        WEIGHTS = [0.299, 0.587, 0.114]

        # How strongly red, green and blue count towards a color's luminance, as WCAG weighs them.
        LUMINANCE_WEIGHTS = [0.2126, 0.7152, 0.0722]

        # @return [Palette] The palette it greys.
        attr_reader :source

        # Greys a palette.
        #
        # @param source [Palette] The palette.
        def initialize(source)
          @source = source
          @back = plain_grey(source.back)
          @window = luminance(source.back.red, source.back.green, source.back.blue)
          @made = {}
          @greys = {}
          @texts = {}
          @names = {}
          @icons = {}
          @faces = {}
          @pictures = {}
          super(Hash[ROLES.map { |role| [role, drawn(source[role])] }], source.preset, nil)
        end

        # Finds a color name's color, greyed.
        #
        # @param name [Symbol] The name.
        # @return [Color, nil] The color, nil for a name the palette does not hold.
        def named(name)
          return @names[name] if @names.key?(name)

          found = @source.named(name)
          @names[name] = found && drawn(found)
        end

        # Tells the color a fill, a line or a text draws in: its grey, dimmed; a color it made
        # already as it is.
        #
        # @param color [Color] The color.
        # @return [Color] The color drawn.
        def drawn(color)
          return color if @made[color.object_id]

          alpha = color.alpha.to_i
          key = ((color.red.to_i * 256 + color.green.to_i) * 256 + color.blue.to_i) * 256 + alpha
          @greys[key] ||= made(grey_of(color), alpha)
        end

        # Tells the color a text draws in: its grey, dimmed, but never closer to the window's back
        # than TEXT_CONTRAST.
        #
        # @param color [Color] The text's color.
        # @return [Color] The color drawn.
        def drawn_text(color)
          grey = drawn(color)
          @texts[grey] ||= readable(grey)
        end

        # Tells where an icon of the game's iconset is drawn from: its greyed copy.
        #
        # @param icon [Integer] The icon's index.
        # @return [Array(Bitmap, Rect)] The copy and its whole rectangle.
        def icon_source(icon)
          copy = @icons[icon]
          copy = @icons[icon] = greyed_copy(Cache.system("Iconset"), UI.icon_rect(icon)) if copy.nil? || copy.disposed?
          [copy, copy.rect]
        end

        # Tells where a part of a picture is drawn from: its greyed copy.
        #
        # @param picture [Bitmap] The picture.
        # @param part [Rect] The part.
        # @return [Array(Bitmap, Rect)] The copy and its whole rectangle.
        def picture_source(picture, part)
          key = [picture.object_id, part.x, part.y, part.width, part.height]
          kept = @pictures[key]
          return [kept[1], kept[1].rect] if kept && kept[0].equal?(picture) && !kept[1].disposed?

          forget_oldest_picture if @pictures.size >= PICTURES_KEPT
          copy = greyed_copy(picture, part)
          @pictures[key] = [picture, copy]
          [copy, copy.rect]
        end

        # Tells where a face of a face sheet is drawn from: its greyed copy, kept by the sheet's name.
        #
        # Paradox frees a face sheet after each draw, so a copy kept by the sheet's picture would be
        # made anew every time.
        #
        # @param name [String] The face sheet's name in Graphics/Faces.
        # @param part [Rect] The face in the sheet.
        # @return [Array(Bitmap, Rect)] The copy and its whole rectangle.
        def face_source(name, part)
          key = [name, part.x, part.y]
          copy = @faces[key]
          copy = @faces[key] = greyed_copy(Cache.face(name), part) if copy.nil? || copy.disposed?
          [copy, copy.rect]
        end

        # Hands out itself, already greyed.
        #
        # @return [GreyedPalette] Itself.
        def greyed
          self
        end

        # Frees its copies of icons, faces and pictures.
        def dispose
          @icons.each_value { |copy| copy.dispose unless copy.disposed? }
          @faces.each_value { |copy| copy.dispose unless copy.disposed? }
          @pictures.each_value { |_picture, copy| copy.dispose unless copy.disposed? }
          @icons.clear
          @faces.clear
          @pictures.clear
        end

        private

        # Frees the greyed copy of the picture it made first.
        def forget_oldest_picture
          _key, (_picture, copy) = @pictures.shift
          copy.dispose unless copy.disposed?
        end

        # Makes a grey it hands out, noted as its own so it is never greyed twice.
        #
        # @param value [Integer] The grey, from 0 to 255.
        # @param alpha [Integer] Its alpha.
        # @return [Color] The color.
        def made(value, alpha)
          color = Color.new(value, value, value, alpha)
          @made[color.object_id] = true
          color
        end

        # Tells a color's grey, dimmed towards the back's.
        #
        # @param color [Color] The color.
        # @return [Integer] The grey, from 0 to 255.
        def grey_of(color)
          UI.within((@back + (plain_grey(color) - @back) * DIMMED).round, 0, 255)
        end

        # Tells a color's grey as it is.
        #
        # @param color [Color] The color.
        # @return [Float] The grey, from 0 to 255.
        def plain_grey(color)
          WEIGHTS[0] * color.red + WEIGHTS[1] * color.green + WEIGHTS[2] * color.blue
        end

        # Moves a grey away from the window's back until it contrasts TEXT_CONTRAST with it, lighter
        # on a dark back and darker on a light one.
        #
        # @param grey [Color] The grey.
        # @return [Color] The grey, another where it moved.
        def readable(grey)
          value = grey.red.to_i
          step = contrast(255) > contrast(0) ? 1 : -1
          value += step while contrast(value) < TEXT_CONTRAST && (value + step).between?(0, 255)
          value == grey.red.to_i ? grey : made(value, grey.alpha.to_i)
        end

        # Tells the contrast of a grey with the window's back.
        #
        # @param value [Integer] The grey, from 0 to 255.
        # @return [Float] The contrast, from 1 to 21.
        def contrast(value)
          lighter, darker = [luminance(value, value, value), @window].sort.reverse
          (lighter + 0.05) / (darker + 0.05)
        end

        # Tells a color's relative luminance, as WCAG works it out.
        #
        # @param red [Numeric] Its red, from 0 to 255.
        # @param green [Numeric] Its green.
        # @param blue [Numeric] Its blue.
        # @return [Float] The luminance, from 0 to 1.
        def luminance(red, green, blue)
          [red, green, blue].zip(LUMINANCE_WEIGHTS).inject(0.0) do |sum, (value, weight)|
            share = value / 255.0
            sum + weight * (share <= 0.03928 ? share / 12.92 : ((share + 0.055) / 1.055)**2.4)
          end
        end

        # Copies a part of a picture with each pixel greyed as drawn greys a color.
        #
        # @param picture [Bitmap] The picture.
        # @param part [Rect] The part.
        # @return [Bitmap] The copy.
        def greyed_copy(picture, part)
          copy = Bitmap.new([part.width, 1].max, [part.height, 1].max)
          copy.blt(0, 0, picture, part)
          return copy unless copy.respond_to?(:get_pixel)

          copy.height.times do |y|
            copy.width.times do |x|
              pixel = copy.get_pixel(x, y)
              next if pixel.alpha == 0

              grey = grey_of(pixel)
              pixel.set(grey, grey, grey, pixel.alpha)
              copy.set_pixel(x, y, pixel)
            end
          end
          copy
        end
      end
    end

    # Finds an icon in the game's iconset.
    #
    # @param icon [Integer] The icon's index.
    # @return [Rect] Where the icon lies in the iconset.
    def self.icon_rect(icon)
      Rect.new(icon % ICONS_PER_ROW * ICON_SIZE, icon / ICONS_PER_ROW * ICON_SIZE, ICON_SIZE, ICON_SIZE)
    end

    # Draws an icon of the game's iconset on a bitmap, scaled to a square of any side.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param icon [Integer, nil] The icon's index, nil for none.
    # @param x [Integer] The icon's left.
    # @param y [Integer] The icon's top.
    # @param side [Integer] The square's side, the iconset's own by default.
    # @param opacity [Integer] How opaque.
    # @param palette [Engine::Palette, nil] The colors it draws in, a greyed palette for a part that
    #   takes no input; nil for its own colors.
    def self.draw_icon(bitmap, icon, x, y, side = ICON_SIZE, opacity = Engine::Motion::OPAQUE, palette = nil)
      return unless icon

      source, part = palette ? palette.icon_source(icon) : [Cache.system("Iconset"), icon_rect(icon)]
      bitmap.stretch_blt(Rect.new(x, y, side, side), source, part, opacity)
    end

    # Splits a list into the rows a box shows and how many more wait, so the box never grows past
    # its rows, the last of which then says how many more there are (MORE_TEXT).
    #
    # @param list [Array] The lines.
    # @param rows [Integer] The rows the box has.
    # @return [Array] The lines shown, and how many more there are, 0 when all fit.
    def self.capped(list, rows)
      return [list, 0] if list.size <= rows

      [list.first(rows - 1), list.size - rows + 1]
    end

    # Keeps a value between two bounds.
    #
    # @param value [Numeric] The value.
    # @param low [Numeric] The lower bound.
    # @param high [Numeric] The upper bound.
    # @return [Numeric] The value, or the bound it passed.
    def self.within(value, low, high)
      value = low if value < low
      value > high ? high : value
    end

    # Writes a whole number with its thousands grouped by commas, unlike the game's own number
    # helpers, which shorten large numbers.
    #
    # @param number [Numeric] The number.
    # @return [String] Such as "3,412,880".
    def self.grouped(number)
      whole = number.to_i
      digits = whole.abs.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      whole < 0 ? "-#{digits}" : digits
    end

    module Engine
      # The motion of one sprite: a fade in and out of its opacity over Style::FADE_FRAMES and a slide
      # to its resting place over Style::SLIDE_FRAMES, in even steps. Whoever owns the sprite owns the
      # motion, calls update once a frame where it updates the sprite, and never sets visible or
      # opacity itself.
      class Motion
        # Full opacity.
        OPAQUE = 255

        # Takes a sprite, whose x and y now are its resting place, as hidden until show.
        #
        # @param sprite [Sprite] The sprite.
        def initialize(sprite)
          @sprite = sprite
          @rest_x = sprite.x.to_i
          @rest_y = sprite.y.to_i
          @placed = false
          @offset_x = @offset_y = 0.0
          @step_x = @step_y = 0.0
          @opacity = 0.0
          @target = 0
          sprite.visible = false
          sprite.opacity = 0
        end

        # Makes a hidden sprite visible at an offset from its resting place with opacity 0, heading
        # for the place and full opacity. From a fade out it only turns the opacity back: the offset
        # and the sprite's place stay, so nothing jumps. Nothing while shown or fading in, so an owner
        # may call it every frame it has something to show.
        #
        # @param dx [Integer] Pixels left (negative) or right of the place to start from, 0 for a fade alone.
        # @param dy [Integer] Pixels above (negative) or below the place to start from.
        def show(dx = 0, dy = 0)
          return if shown? || @sprite.disposed?

          if hidden?
            @offset_x = dx.to_f
            @offset_y = dy.to_f
            @step_x = @offset_x / Style::SLIDE_FRAMES
            @step_y = @offset_y / Style::SLIDE_FRAMES
            @opacity = 0.0
            @sprite.visible = true
            write
          end
          @target = OPAQUE
        end

        # Heads for opacity 0; a slide still running keeps running. Once at 0 the sprite is made
        # invisible. Nothing while hidden or fading out. The owner keeps the sprite's last picture
        # until hidden?.
        def hide
          @target = 0
        end

        # Sets the resting place without a slide, for a box that follows something else every frame.
        # The sprite keeps whatever offset it still has.
        #
        # @param x [Integer] The place's x.
        # @param y [Integer] The place's y.
        def place(x, y)
          @rest_x = x.to_i
          @rest_y = y.to_i
          @placed = true
          write
        end

        # Sets a new resting place and slides there from where the sprite stands now. The first call
        # on a motion never placed places without a slide.
        #
        # @param x [Integer] The place's x.
        # @param y [Integer] The place's y.
        def slide_to(x, y)
          return place(x, y) unless @placed

          @offset_x = (@rest_x + @offset_x) - x.to_i
          @offset_y = (@rest_y + @offset_y) - y.to_i
          @step_x = @offset_x / Style::SLIDE_FRAMES
          @step_y = @offset_y / Style::SLIDE_FRAMES
          @rest_x = x.to_i
          @rest_y = y.to_i
          write
        end

        # Moves one frame: the opacity by OPAQUE / Style::FADE_FRAMES towards its target, the offset
        # by its start / Style::SLIDE_FRAMES towards 0, and writes them to the sprite, which turns
        # invisible once a fade out arrived. Nothing on a disposed sprite.
        #
        # @return [Boolean] Whether it still moves after this frame.
        def update
          return false if @sprite.disposed?

          @opacity = Motion.step_towards(@opacity, @target, OPAQUE.to_f / Style::FADE_FRAMES)
          @offset_x = Motion.step_towards(@offset_x, 0.0, @step_x.abs)
          @offset_y = Motion.step_towards(@offset_y, 0.0, @step_y.abs)
          write
          @sprite.visible = false if hidden?
          moving?
        end

        # Reports whether the opacity or the offset still move.
        #
        # @return [Boolean] Whether one does.
        def moving?
          @opacity != @target || @offset_x != 0.0 || @offset_y != 0.0
        end

        # Reports whether the sprite is shown or fading in.
        #
        # @return [Boolean] Whether its target opacity is full.
        def shown?
          @target == OPAQUE
        end

        # Reports whether the sprite is invisible: a fade out finished, or never shown.
        #
        # @return [Boolean] Whether it is.
        def hidden?
          @target == 0 && @opacity <= 0.0
        end

        # Moves a value one step towards a target, landing on the target within the last step, which
        # a sprite with a slide of its own shares.
        #
        # @param value [Float] The value.
        # @param target [Float] The target.
        # @param step [Float] The step's size, 0 or more.
        # @return [Float] The value moved.
        def self.step_towards(value, target, step)
          return target if (target - value).abs <= step

          value < target ? value + step : value - step
        end

        # Writes the sprite's place and opacity; nothing on a disposed sprite, which raises on a write.
        def write
          return if @sprite.disposed?

          @sprite.x = @rest_x + @offset_x.round
          @sprite.y = @rest_y + @offset_y.round
          @sprite.opacity = @opacity.round
        end
      end
    end
  end
end
