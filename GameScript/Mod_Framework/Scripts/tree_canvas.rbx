#----------------------------------------------------------------
#  tree_canvas.rbx
#
#  Changelog:
#      Paulinchen  2026-11-10: Drew a color given as [r, g, b] or "#RRGGBB" wherever a color name is taken
#      Paulinchen  2026-11-09: Drew a gauge's outer edge in a color of its own, or in a shade of its fill, with :border
#                            - Drew a part's border in a color, a shade or the theme's frame at any width, along a box or a pill
#                            - Filled a part's background in a color or the theme's back, thinning to nothing toward a side with a fade
#                            - Drew a gauge's border and well by the part's border and background
#                            - Drew a box's frame alone, its edge in a color of its own where told
#      Paulinchen  2026-11-07: Drew the letters of a highlight and the outline of every text by contrast only under contrast
#                            - Drew the letters of a highlight in the text's own color with its outline
#                            - Drew a highlight on the primary color, its letters in the text that contrasts with it
#                            - Outlined a text in the outline its part asks for, black by default
#                            - Kept the plate of a highlight as high as the font in the middle of the text's box
#                            - Drew a text only within the columns :span gives
#                            - Outlined the letters of an animated color as the plain text where they lie
#                            - Drew a text's places that hold a part on the picked color behind it, with :highlight
#                            - Filled shapes given as rows of spans on a canvas
#                            - Filled round spots on a canvas
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Each text a canvas drew, drawn once into a place of its own on a few shared sheets and copied
      # from there whenever the same text draws again in the same size, color and box, since drawing
      # a text costs the game far more than copying a picture, and a picture of its own for each text
      # costs a new picture and its GDI handles the first time. A text too big for a sheet gets a
      # picture of its own. Once the sheets are full, the least recently drawn sheet is cleared, the
      # pictures of their own go least recently drawn first once all take more than BUDGET bytes, and
      # all go when the game goes back to the title or F12 starts it again.
      module LabelCache
        # The bytes the sheets and the pictures of texts too big for a sheet may take at most.
        BUDGET = 4 * 1024 * 1024

        # A sheet's width and height in pixels.
        SHEET_WIDTH = 1024
        SHEET_HEIGHT = 256

        # The most sheets, each taking four bytes a pixel, within BUDGET.
        MOST_SHEETS = BUDGET / (SHEET_WIDTH * SHEET_HEIGHT * 4)

        # The pixels kept empty right of and below each text's place on a sheet, so ink that reaches
        # past a place never lands on its neighbor.
        GAP = 2

        # The room around a text's box on its picture, where its outline and its letters may reach past
        # the box.
        MARGIN = 4

        # The most widths of texts kept, see width.
        MOST_WIDTHS = 2048

        # A text drawn: the picture it lies on, where its box starts in its place there, whether it
        # was cut, its place on the picture (the whole picture once found) and the sheet it lies on,
        # nil for a picture of its own.
        Label = Struct.new(:bitmap, :left, :top, :cut, :rect, :sheet)

        # The texts drawn by their keys, the least recently drawn first.
        @labels = {}

        # The bytes the pictures of their own take.
        @bytes = 0

        # The sheets the texts lie on, each find a use of them; a sheet's entries are the keys of
        # its texts.
        @sheets = Sheets.new(SHEET_WIDTH, SHEET_HEIGHT, MOST_SHEETS) { |sheet| forget(sheet) }

        # The widths of texts measured, by the text and the font size.
        @widths = {}

        # Hands out the text drawn of a key, drawing it with the block the first time.
        #
        # @param key [Array] What the text looks like, see Canvas#text; its first entry is the text.
        # @yield Draws the text.
        # @yieldreturn [Label] The text drawn.
        # @return [Label] The text drawn.
        def self.find(key)
          @sheets.use
          label = @labels.delete(key)
          if label && label.bitmap.disposed?
            @sheets.drop(label.sheet) if label.sheet
            label = nil
          end
          unless label
            key = key.dup
            key[0] = key[0].dup.freeze
            label = yield
            label.rect ||= label.bitmap.rect
            if label.sheet
              label.sheet.entries << key
            else
              @bytes += bytes(label)
            end
          end
          @sheets.mark(label.sheet) if label.sheet
          @labels[key] = label
          trim(label)
          label
        end

        # Draws a text into a place on a sheet, or onto a picture of its own where it is too big for a
        # sheet, cut or squeezed into its box as Canvas#text says.
        #
        # @param text [String] The text.
        # @param size [Integer] The font size in pixels.
        # @param color [Color] The color.
        # @param outline [Color, Symbol, Boolean, nil] The outline, see Canvas#outline_of.
        # @param opacity [Integer, nil] The opacity, see Canvas#text.
        # @param width [Integer] The box's width.
        # @param height [Integer] Its height.
        # @param align [Integer] How it lines up, as Bitmap#draw_text takes it.
        # @param mode [Symbol, nil] :cut, :squeeze or nil to draw it whole.
        # @return [Label] The text drawn.
        def self.draw(text, size, color, outline, opacity, width, height, align, mode)
          measure = UI.font_bitmap(size)
          measure.font.outline = !outline.equal?(false)
          shown = mode ? cut_to(measure, text, mode == :squeeze ? (width / Canvas::SQUEEZE).floor : width) : text
          natural = mode ? measured(measure, shown) : 0
          narrow = mode == :squeeze && natural + Canvas::OUTLINE_ROOM > width
          room = mode && !narrow && align == 0 ? [width, natural + Canvas::OUTLINE_ROOM].max : width
          top = MARGIN + [(size - height + 1) / 2, 0].max
          wide = [room, 1].max + 2 * MARGIN
          tall = [height, 1].max + 2 * top
          sheet, x, y = @sheets.place(wide + GAP, tall + GAP) || [nil, 0, 0]
          bitmap = sheet ? sheet.bitmap : Bitmap.new(wide, tall)
          Style.use_font(bitmap, size, color, outline)
          bitmap.font.outline = false if outline.equal?(false)
          fade(bitmap.font, opacity) if opacity
          if narrow
            narrowed(bitmap, measure, x + MARGIN, y + top, width, height, shown, natural)
          else
            GlyphCache.draw(bitmap, x + MARGIN, y + top, room, height, shown, align) || draw_lined_up(bitmap, x + MARGIN, y + top, room, height, shown, align)
          end
          Label.new(bitmap, MARGIN, top, shown != text, Rect.new(x, y, wide, tall), sheet)
        end

        # Draws a text into its box on its picture where it lines up, with room for its outline on
        # both sides where it fits (GlyphCache.draw_whole), else squeezed into the box by draw_text.
        #
        # @param bitmap [Bitmap] The picture, its font set.
        # @param left [Integer] The box's left on the picture.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String] The text.
        # @param align [Integer] How it lines up, as Bitmap#draw_text takes it.
        def self.draw_lined_up(bitmap, left, top, width, height, text, align)
          natural = measured(bitmap, text)
          return bitmap.draw_text(left, top, width, height, text, align) if natural > width

          lead = align == 1 ? (width - natural) / 2 : (align == 2 ? width - natural : 0)
          GlyphCache.draw_whole(bitmap, left + lead, top, natural + MARGIN, height, text)
        end
        private_class_method :draw_lined_up

        # Measures a text in a font size, kept for the next time.
        #
        # @param text [String] The text.
        # @param size [Integer] The font size in pixels.
        # @return [Integer] Its width in pixels.
        def self.width(text, size)
          key = [text, size]
          @widths.fetch(key) do
            @widths.clear if @widths.size >= MOST_WIDTHS
            @widths[[text.dup.freeze, size]] = measured(UI.font_bitmap(size), text)
          end
        end

        # Measures a text in a picture's font: from the widths of its characters where texts are
        # built from them, else as the game measures it.
        #
        # @param measure [Bitmap] A picture set to the font.
        # @param text [String] The text.
        # @return [Integer] Its width in pixels.
        def self.measured(measure, text)
          GlyphCache.width(measure, text) || measure.text_size(text).width
        end

        # Frees every picture, the sheets and the characters' too, and forgets every width.
        def self.clear
          @labels.each_value { |label| label.bitmap.dispose unless label.sheet || label.bitmap.disposed? }
          @labels = {}
          @bytes = 0
          @sheets.clear
          @widths = {}
          GlyphCache.clear
        end

        # Tells how many texts are kept, the bytes their sheets and pictures take and the sheets.
        #
        # @return [Array<Integer>] The texts, the bytes and the sheets.
        def self.size
          [@labels.size, @bytes + @sheets.bytes, @sheets.count]
        end

        # Frees the least recently drawn pictures of their own, but the text just found, while the
        # sheets and those pictures take more than BUDGET.
        #
        # @param found [Label] The text just found.
        def self.trim(found)
          while @bytes > 0 && @bytes + @sheets.bytes > BUDGET
            key, label = @labels.find { |_key, each| each.sheet.nil? }
            break if label.nil? || label.equal?(found)

            @labels.delete(key)
            @bytes -= bytes(label)
            label.bitmap.dispose unless label.bitmap.disposed?
          end
        end
        private_class_method :trim

        # Forgets the texts on a sheet about to be cleared or dropped.
        #
        # @param sheet [Sheets::Sheet] The sheet.
        def self.forget(sheet)
          sheet.entries.each { |key| @labels.delete(key) if @labels[key] && @labels[key].sheet.equal?(sheet) }
        end
        private_class_method :forget

        # Tells the bytes the picture of a text takes.
        #
        # @param label [Label] The text.
        # @return [Integer] The bytes.
        def self.bytes(label)
          label.bitmap.width * label.bitmap.height * 4
        end
        private_class_method :bytes

        # Cuts a text to a width with "...", measured in its font.
        #
        # The cut C# answers comes from the widths of the characters it knows, which may differ from
        # those the game draws, so the game's measure has the last word.
        #
        # @param measure [Bitmap] A picture set to the text's font.
        # @param text [String] The text.
        # @param width [Integer] The width.
        # @return [String] The text, cut when it is too wide.
        def self.cut_to(measure, text, width)
          shown = UI.cut(measure, text, width)
          measured(measure, shown) > width ? UI.cut_measured(measure, text, width) : shown
        end
        private_class_method :cut_to

        # Draws a text narrower than it is into its width: each character whole at its size, the
        # characters set closer alike, their outlines first and the letters over them, so no letter
        # loses a column or hides under the outline of the next. The characters are copies where
        # texts are built from them (GlyphCache.draw_placed).
        #
        # @param bitmap [Bitmap] The picture, its font set.
        # @param measure [Bitmap] A picture set to the same font, which measures.
        # @param left [Integer] The box's left on the picture.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String] The text.
        # @param natural [Integer] The text's width.
        def self.narrowed(bitmap, measure, left, top, width, height, text, natural)
          factor = [width - Canvas::OUTLINE_ROOM / 2, 1].max.to_f / [natural, 1].max
          places = []
          text.each_char.inject("") do |before, char|
            places << [before.empty? ? 0 : (measured(measure, before) * factor).round, char]
            before + char
          end
          return if GlyphCache.draw_placed(bitmap, left, top, height, places)

          font = bitmap.font
          outlined = font.outline
          (outlined ? [true, false] : [false]).each do |outline|
            font.outline = outline
            places.each { |place, char| GlyphCache.draw_whole(bitmap, left + place, top, measure.text_size(char).width + MARGIN, height, char) }
          end
          font.outline = outlined
        end
        private_class_method :narrowed

        # Makes a font's color and outline see-through.
        #
        # @param font [Font] The font.
        # @param opacity [Integer] From 0 to 255.
        def self.fade(font, opacity)
          share = UI.within(opacity.to_i, 0, Component::OPAQUE) / Component::OPAQUE.to_f
          font.color = Color.new(font.color.red, font.color.green, font.color.blue, (font.color.alpha * share).round)
          font.out_color = Color.new(font.out_color.red, font.out_color.green, font.out_color.blue, (font.out_color.alpha * share).round)
        end
        private_class_method :fade
      end

      # What a component draws with: its place on the picture it lies on, given as its own rect from
      # its top left corner, and the colors of its theme. A modder's own component gets one in draw.
      #
      # Every color it takes may be an animated color name, such as :rainbow: a text in it draws
      # letter by letter, an area in bands of Colors::BAND pixels from the component's left, and the
      # component draws there anew every Colors::REDRAW frames while it shows.
      class Canvas
        # The color a lit fill in an animated color lightens toward.
        WHITE = Color.new(255, 255, 255)

        # The font sizes a text takes by name.
        SIZES = { :tiny => Style::TINY_SIZE, :small => Style::SMALL_SIZE, :normal => Style::TEXT_SIZE, :large => Style::TITLE_SIZE }

        # The game's text color its windows draw their labels in, Window_Base#system_color.
        GAME_SYSTEM_COLOR = 16

        # The text colors a text takes by name, as Style names them.
        TEXT_COLORS = { :text => :TEXT, :dim => :DIM, :good => :GOOD, :warn => :WARN, :bad => :BAD, :gold => :GOLD, :own => :OWN, :ally => :GOOD }

        # The colors of a theme a text or a fill takes by name, as its palette names them.
        LOOK_COLORS = Palette::ROLES.map { |role| role.to_s.downcase.to_sym }

        # How a text lines up, as Bitmap#draw_text takes it, by name.
        ALIGNS = { :left => 0, :start => 0, :center => 1, :right => 2, :end => 2 }

        # The least share of its width a squeezed text is drawn at, which still reads easily; a text
        # wider than that is cut instead.
        SQUEEZE = 0.85

        # Room past a text's measured width that Bitmap#draw_text needs for its outline; in a box
        # narrower than that it draws the text in a smaller font, a step at a time.
        OUTLINE_ROOM = 4

        # @return [Bitmap] The picture drawn on.
        attr_reader :bitmap

        # @return [Integer] The component's width.
        attr_reader :width

        # @return [Integer] The component's height.
        attr_reader :height

        # @return [Palette] The colors of the component's theme, greyed out while it takes no input.
        attr_reader :palette

        # @return [Component] The component drawn.
        attr_reader :component

        # Makes the canvas of a component on the picture it lies on.
        #
        # @param component [Component] The component, laid out.
        # @param surface [#bitmap, #x, #y] The picture and where its top left lies on the screen.
        # @param enabled [Boolean] Whether it draws as taking input, else greyed out; as the
        #   component draws by default.
        def initialize(component, surface, enabled = component.draws_enabled?)
          rect = component.rect
          @component = component
          @bitmap = surface.bitmap
          @left = rect.x - surface.x
          @top = rect.y - surface.y
          @width = rect.width
          @height = rect.height
          @colors = component.palette
          @palette = enabled ? @colors : @colors.greyed
          @enabled = enabled
          @game_look = component.game_look?
          @plain_px = @game_look ? UI.game_font_px : nil
        end

        # Tells whether the component takes input, so it draws greyed out when it does not.
        #
        # @return [Boolean] Whether it draws as taking input.
        def enabled?
          @enabled
        end

        # Draws a text in the component.
        #
        # @param x [Integer] The text box's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String] The text.
        # @param options [Hash] :color (see text_color; the plain text color by default), :size (:tiny, :small, :normal, :large or pixels; :normal by default), :align (:left,
        #   :center or :right), :cut (true cuts the text with "..." to the width), :squeeze (true
        #   draws a text too wide narrower, down to SQUEEZE of its width, and cuts it only past that),
        #   :opacity (0 to 255, the text and its outline see-through), :outline (false draws it
        #   without its outline, else see outline_of; the component's :outline by default, else
        #   that of the nearest component around it),
        #   :highlight (a text whose places in it, found ignoring case, draw on the theme's primary
        #   color, the letters in the text's own color and outline, or under contrast in the text
        #   that contrasts with the primary color),
        #   :span ([from, to], the columns of the component it draws in, the rest of it left out; not
        #   for an animated color).
        # @return [Boolean] Whether the text was cut.
        def text(x, y, width, height, text, options = {})
          full = text.to_s
          return false if full.empty?

          marks = options[:highlight].to_s.empty? ? [] : highlight(x, y, width, height, full, options)
          moving = animated(options[:color], x, y, width, height)
          return moving_text(x, y, width, height, full, options, moving) if moving
          return marked_text(x, y, width, height, full, options, marks) unless marks.empty? || !contrast?

          color = text_color(options[:color])
          size = font_size(options[:size])
          align = ALIGNS[options[:align]] || (options[:align].is_a?(Integer) ? options[:align] : 0)
          mode = options[:squeeze] ? :squeeze : (options[:cut] ? :cut : nil)
          outline = outline_of(options[:outline])
          shade = outline.is_a?(Color) ? (outline.red.to_i << 24) | (outline.green.to_i << 16) | (outline.blue.to_i << 8) | outline.alpha.to_i : outline
          key = [full, size, color.red, color.green, color.blue, color.alpha, shade, options[:opacity], width, height, align, mode]
          label = LabelCache.find(key) { LabelCache.draw(full, size, color, outline, options[:opacity], width, height, align, mode) }
          left = @left + x - label.left
          part = label.rect
          if options[:span]
            from = [@left + options[:span][0] - left, 0].max
            to = [@left + options[:span][1] - left, part.width].min
            return label.cut if to <= from

            part = Rect.new(part.x + from, part.y, to - from, part.height)
            left += from
          end
          @bitmap.blt(left, @top + y - label.top, label.bitmap, part)
          label.cut
        end

        # Fills the places of a text that hold its :highlight on the theme's primary color, behind
        # where text draws them, as far as its box reaches, each as high as the font in the middle of
        # the box, where the line stands.
        #
        # @param x [Integer] The text box's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param full [String] The text.
        # @param options [Hash] The options of text.
        # @return [Array<Array<Integer>>] Each place's first column and the column after it, in the
        #   component.
        def highlight(x, y, width, height, full, options)
          places = TextMatch.places(full, options[:highlight])
          return [] if places.empty?

          size = font_size(options[:size])
          shown = [text_width(full, size), width].min
          align = ALIGNS[options[:align]] || (options[:align].is_a?(Integer) ? options[:align] : 0)
          start = x + { 1 => (width - shown) / 2, 2 => width - shown }.fetch(align, 0)
          high = [size, height].min
          top = y + (height - high) / 2
          marks = places.map do |first, length|
            left = start + text_width(full[0, first], size)
            [left, [left + text_width(full[first, length], size), start + shown].min]
          end
          marks = marks.select { |left, right| right > left }
          marks.each { |left, right| fill(left, top, right - left, high, :primary) }
        end
        private :highlight

        # Draws a text whose highlight is filled: its marks in the text on the primary color, the
        # rest in its own color, each only within its columns.
        #
        # @param x [Integer] The text box's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param full [String] The text.
        # @param options [Hash] The options of text.
        # @param marks [Array<Array<Integer>>] The marks' columns, see highlight.
        # @return [Boolean] Whether the text was cut.
        def marked_text(x, y, width, height, full, options, marks)
          plain = options.merge(:highlight => nil)
          on_mark = plain.merge(:color => @component.text_on(:primary))
          edges = [0] + marks.flatten + [self.width]
          cut = false
          edges.each_slice(2).each_with_index do |(from, to), index|
            cut = text(x, y, width, height, full, plain.merge(:span => [from, to])) || cut
            mark = marks[index]
            text(x, y, width, height, full, on_mark.merge(:span => mark)) if mark
          end
          cut
        end
        private :marked_text

        # Measures a text as text draws it.
        #
        # @param text [String] The text.
        # @param size [Symbol, Integer, nil] Its size, see text.
        # @return [Integer] Its width in pixels.
        def text_width(text, size = nil)
          LabelCache.width(text.to_s, font_size(size))
        end

        # Draws an icon of the game's iconset, or a picture file scaled to an icon, greyed out while
        # disabled.
        #
        # @param icon [Integer, Symbol, Hash, nil] The icon's index, a name UI.icon gave one, a
        #   picture file as { :file => path }, nil for none.
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param options [Hash] :side (its side, the iconset's by default), :opacity.
        def icon(icon, x, y, options = {})
          icon = Looks.icon_of(icon) if icon.is_a?(Symbol) && defined?(Looks)
          opacity = options[:opacity] || Motion::OPAQUE
          side = options[:side] || ICON_SIZE
          return UI.draw_icon(@bitmap, icon, @left + x, @top + y, side, opacity, @palette) unless icon.is_a?(Hash)

          picture = UI.picture(icon[:file])
          picture(picture, x, y, side, side, picture.rect, opacity) if picture
        end

        # Draws a flat box in the theme's look: its background inside its frame.
        #
        # @param x [Integer] Its left in the component, 0 by default.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width, the component's by default.
        # @param height [Integer] Its height, the component's by default.
        # @param options [Hash] :fill (a color, see color, instead of the background), :edge (a color
        #   for the frame's edge), :opacity (how opaque a background and frame not animated draw,
        #   whole by default).
        def box(x = 0, y = 0, width = @width, height = @height, options = {})
          moving_fill = animated(options[:fill], x, y, width, height)
          moving_edge = animated(options[:edge], x, y, width, height)
          edge = options[:edge] && !moving_edge ? color(options[:edge]) : nil
          opacity = options[:opacity]
          if options[:fill]
            moving_fill ? paint(x, y, width, height, moving_fill) : @bitmap.fill_rect(@left + x, @top + y, width, height, Style.see_through(color(options[:fill]), opacity))
            Style.draw_frame(@bitmap, @left + x, @top + y, width, height, edge, @palette, opacity)
          else
            Style.draw_box(@bitmap, @left + x, @top + y, width, height, @palette, opacity)
            Style.draw_frame(@bitmap, @left + x, @top + y, width, height, edge, @palette, opacity) if edge
          end
          inset = Style.frame_width(@palette) - 1
          moving_outline(x + inset, y + inset, width - 2 * inset, height - 2 * inset, moving_edge) if moving_edge
        end

        # Draws a box's frame in the theme's look without filling it, its edge in a color of its own
        # where told, as box frames a fill.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param edge [Color, Symbol, Integer, nil] The edge's color, see color; nil for the theme's.
        def frame(x, y, width, height, edge = nil)
          moving = animated(edge, x, y, width, height)
          Style.draw_frame(@bitmap, @left + x, @top + y, width, height, edge && !moving ? color(edge) : nil, @palette)
          inset = Style.frame_width(@palette) - 1
          moving_outline(x + inset, y + inset, width - 2 * inset, height - 2 * inset, moving) if moving
        end

        # Fills a background: a color, :theme for the look's own back, or a Hash with its :color and a
        # :fade, [side, pixels], over whose last pixels toward that side it thins from its alpha to
        # nothing, drawn as Bitmap#gradient_fill_rect draws it.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Color, Symbol, Integer, Hash, Boolean, nil] The background, nil or false for none.
        # @param opacity [Integer, nil] How opaque it draws, nil for whole.
        def background(x, y, width, height, look, opacity = nil)
          fade = look.is_a?(Hash) ? look[:fade] : nil
          look = look[:color] if look.is_a?(Hash)
          return if look.nil? || look == false || width <= 0 || height <= 0

          moving = look == :theme || fade ? nil : animated(look, x, y, width, height)
          return paint(x, y, width, height, moving) if moving

          drawn = Style.see_through(look == :theme ? Style.colors(@palette).back : color(look), opacity)
          return @bitmap.fill_rect(@left + x, @top + y, width, height, drawn) unless fade

          faded_fill(x, y, width, height, drawn, fade[0], fade[1].to_i)
        end

        # Draws a border along the inside of a rectangle, or of a pill with :shape => :pill: thick rings
        # of a color; with :theme the theme's frame, its rim the outer pixel where the rim shows and
        # its edge the rest, a border of one pixel its edge alone; with :shade a darker shade of the
        # color :of names.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Color, Symbol, Integer, Boolean, nil] The border, nil or false for none.
        # @param thick [Integer] Its pixels.
        # @param options [Hash] :shape (:box or :pill), :of (the color :shade darkens), :opacity (how
        #   opaque it draws, nil for whole).
        def border(x, y, width, height, look, thick = 1, options = {})
          return if look.nil? || look == false || thick <= 0 || width <= 0 || height <= 0

          look = darker(color(options[:of] || :primary)) if look == :shade
          return pill(x, y, width, height, :edge => look == :theme ? :edge : look, :thick => thick) if options[:shape] == :pill
          return theme_border(x, y, width, height, thick, options[:opacity]) if look == :theme

          thick.times do |ring|
            inner_width = width - 2 * ring
            inner_height = height - 2 * ring
            break if inner_width <= 0 || inner_height <= 0

            if options[:opacity]
              Style.draw_line_box(@bitmap, @left + x + ring, @top + y + ring, inner_width, inner_height, Style.see_through(color(look), options[:opacity]))
            else
              outline(x + ring, y + ring, inner_width, inner_height, look)
            end
          end
        end

        # Tells where a part of the component lies on the picture, for what draws on the picture
        # itself, such as TextBox.
        #
        # @param x [Integer] The part's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @return [Rect] The part on the picture.
        def area(x, y, width, height)
          Rect.new(@left + x, @top + y, width, height)
        end

        # Draws the frame of a rectangle one pixel thick, in the theme's edge color unless told
        # otherwise, without filling it.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Color, Symbol, Integer] The color, see color.
        def outline(x, y, width, height, look = :edge)
          moving = animated(look, x, y, width, height)
          return moving_outline(x, y, width, height, moving) if moving

          Style.draw_line_box(@bitmap, @left + x, @top + y, width, height, color(look))
        end

        # Draws a pill, a box whose ends are half circles, as MudBlazor draws a chip: filled, ringed
        # along its inside, or both.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param options [Hash] :fill (a color, see color), :edge (a color for the ring), :thick (the
        #   ring's pixels, 1 by default).
        def pill(x, y, width, height, options = {})
          ring = options[:edge] ? options[:thick] || 1 : 0
          pill_rows(x + ring, y + ring, width - 2 * ring, height - 2 * ring, options[:fill], 0) if options[:fill]
          pill_rows(x, y, width, height, options[:edge], ring) if options[:edge]
        end

        # Fills a rectangle.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param fill [Color, Symbol, Integer] The color, see color.
        def fill(x, y, width, height, fill)
          moving = animated(fill, x, y, width, height)
          return paint(x, y, width, height, moving) if moving

          @bitmap.fill_rect(@left + x, @top + y, width, height, color(fill))
        end

        # Fills a round spot, such as the knob of a slider.
        #
        # @param x [Integer] Its middle's left in the component.
        # @param y [Integer] Its middle's top.
        # @param radius [Integer] Its radius.
        # @param fill [Color, Symbol, Integer] The color, see color.
        def disc(x, y, radius, fill)
          drawn = color(fill)
          (-radius...radius).each do |row|
            middle = row + 0.5
            half = Math.sqrt([radius * radius - middle * middle, 0].max).round
            @bitmap.fill_rect(@left + x - half, @top + y + row, 2 * half, 1, drawn) if half > 0
          end
        end

        # Fills a shape given as its rows: each row a list of spans, each [left, width].
        #
        # @param x [Integer] The shape's left in the component.
        # @param y [Integer] Its top.
        # @param rows [Array<Array<Array<Integer>>>] The spans of each row, from its top.
        # @param fill [Color, Symbol, Integer] The color, see color.
        def spans(x, y, rows, fill)
          drawn = color(fill)
          rows.each_with_index do |row, place|
            row.each { |left, width| @bitmap.fill_rect(@left + x + left, @top + y + place, width, 1, drawn) }
          end
        end

        # Draws a line one pixel thick, in the theme's edge color unless told otherwise.
        #
        # @param x [Integer] Its start's left in the component.
        # @param y [Integer] Its start's top.
        # @param length [Integer] Its length.
        # @param options [Hash] :direction (:horizontal or :vertical), :color.
        def line(x, y, length, options = {})
          width, height = options[:direction] == :vertical ? [1, length] : [length, 1]
          moving = animated(options[:color], x, y, width, height)
          return paint(x, y, width, height, moving) if moving

          @bitmap.fill_rect(@left + x, @top + y, width, height, color(options[:color] || :edge))
        end

        # Draws a gauge: its well, the part a rate fills inside its border and its border.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param rate [Numeric] How full it is, from 0 to 1.
        # @param options [Hash] :colors (one color, the theme's primary by default, or two the fill
        #   runs between from the left to the right; with :vertical two or three from the top to the
        #   bottom; see color), :trail (a rate above the fill drawn in a darker shade of it), :border
        #   (see border, :shade a darker shade of its first color; the theme's edge by default, false
        #   for none), :border_width (its pixels, 1 by default), :well (its well as background takes
        #   it, false for none; the theme's well by default).
        def gauge(x, y, width, height, rate, options = {})
          given = Array(options[:colors] || [:primary])
          moving = given.size == 1 ? animated(given[0], x, y, width, height) : nil
          colors = given.map { |each| color(each) }
          look = options.key?(:border) ? options[:border] : :theme
          rim = look.nil? || look == false ? 0 : (options[:border_width] || 1)
          room = width - 2 * rim
          filled = (UI.within(rate.to_f, 0.0, 1.0) * room).round
          options[:well].nil? ? @bitmap.fill_rect(@left + x, @top + y, width, height, @palette.well) : background(x, y, width, height, options[:well])
          trail = options[:trail] ? (UI.within(options[:trail].to_f, 0.0, 1.0) * room).round : 0
          @bitmap.fill_rect(@left + x + rim + filled, @top + y + rim, trail - filled, height - 2 * rim, darker(colors.last)) if trail > filled
          moving ? paint(x + rim, y + rim, filled, height - 2 * rim, moving) : fill_gauge(x + rim, y + rim, filled, height - 2 * rim, colors, options[:vertical])
          border(x, y, width, height, look, rim, :of => given.first)
        end

        # Copies a picture into the component, greyed out while disabled.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param source [Bitmap] The picture.
        # @param rect [Rect] The part copied, the whole picture by default.
        # @param opacity [Integer] How opaque.
        def blt(x, y, source, rect = source.rect, opacity = Motion::OPAQUE)
          source, rect = @palette.picture_source(source, rect)
          @bitmap.blt(@left + x, @top + y, source, rect, opacity)
        end

        # Draws a picture scaled into a rectangle of the component, greyed out while disabled.
        #
        # @param source [Bitmap] The picture.
        # @param x [Integer] The rectangle's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param part [Rect] The part of the picture drawn, all of it by default.
        # @param opacity [Integer, nil] How opaque it draws, nil for whole.
        def picture(source, x, y, width, height, part = source.rect, opacity = nil)
          source, part = @palette.picture_source(source, part)
          @bitmap.stretch_blt(Rect.new(@left + x, @top + y, width, height), source, part, opacity || Motion::OPAQUE)
        end

        # Copies a picture whole as it is, at the opacity it was drawn in, such as a part drawn once on
        # a picture of its own.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param source [Bitmap] The picture.
        def copy(x, y, source)
          @bitmap.blt(@left + x, @top + y, source, source.rect)
        end

        # Draws a scrollbar in the theme's look, see Style.draw_scrollbar.
        #
        # @param x [Integer] The bar's left in the component.
        # @param y [Integer] Its top.
        # @param height [Integer] Its height.
        # @param first [Integer] The first line or pixel in sight.
        # @param shown [Integer] How many show at once.
        # @param total [Integer] How many there are.
        def scrollbar(x, y, height, first, shown, total)
          Style.draw_scrollbar(@bitmap, @left + x, @top + y, height, first, shown, total, @palette)
        end

        # Finds a color: a Color as it is, [r, g, b(, a)] or "#RRGGBB" as that color, a game text
        # color by its index, or a color name of the theme the component draws in (Palette#named): a
        # text color (:text, :dim, :success, :warning, :error, :gold, :own, and the old :good, :warn
        # and :bad), a box color (:back, :heading, :edge, :picked and the others of Palette::ROLES),
        # a palette role such as :primary (:system for :heading without the DLL) or a color name a
        # mod added; of an animated color name its color at the component's left now. While the
        # component takes no input, the color greyed out (GreyedPalette).
        #
        # @param value [Color, Array, Integer, Symbol, String, nil] The color, nil for the plain text color.
        # @return [Color] The color.
        def color(value)
          @palette.drawn(plain_color(value))
        end

        # Tells whether it drew anything in an animated color, which draws anew every few frames.
        #
        # @return [Boolean] Whether it did.
        def animated?
          @animated ? true : false
        end

        # Finds the color a text draws in: as color finds it, and while the component takes no input
        # greyed out and kept readable on the window (GreyedPalette#drawn_text).
        #
        # @param value [Color, Array, Integer, Symbol, String, nil] The color, nil for the plain text color.
        # @return [Color] The color.
        def text_color(value)
          @palette.drawn_text(plain_color(value || :text))
        end

        # Finds a font size: the normal one is the game's own in the look the game's own windows wear.
        #
        # @param size [Symbol, Integer, nil] The size, see text.
        # @return [Integer] The size in pixels.
        def font_size(size)
          return size if size.is_a?(Integer)
          return @plain_px if @plain_px && (size.nil? || size == :normal)

          UI.font_px(size)
        end

        private

        # Tells whether its component draws its texts on a fill by contrast, see Component#contrast?.
        #
        # @return [Boolean] Whether it does.
        def contrast?
          @component.is_a?(Component) && @component.contrast?
        end

        # Finds the outline of a text: unless the text names one, the :outline of its component or of
        # the nearest component around it that has one; else Style::CONTRAST_OUTLINE for the one
        # that contrasts with the text where its component has contrast, nil for the black one
        # (Style::OUTLINE); false for none, a color found as plain_color finds it.
        #
        # @param value [Color, Integer, Symbol, Boolean, nil] The text's :outline.
        # @return [Color, Symbol, Boolean, nil] The outline as Style.use_font takes it.
        def outline_of(value)
          part = @component
          while value.nil? && part.is_a?(Component)
            value = part.outline
            part = part.parent
          end
          value = Style::CONTRAST_OUTLINE if value.nil? && contrast?
          return value if value.nil? || value.equal?(false) || value.equal?(Style::CONTRAST_OUTLINE)

          plain_color(value)
        end

        # Finds a color as color does, in the theme's own colors; :system in the look of the game's
        # own windows is the color they draw their labels in.
        #
        # @param value [Color, Array, String, Integer, Symbol, Lifted, nil] The color, a color given by
        #   its values (Colors.given), nil for the plain text color.
        # @return [Color] The color.
        def plain_color(value)
          given = Colors.given(value)
          return given if given
          return plain_color(value.name) if value.is_a?(Lifted)
          return UI.text_color(value) if value.is_a?(Integer)
          return Style::TEXT if value.to_s.empty?

          name = value.is_a?(Symbol) ? value : value.to_s.to_sym
          return UI.text_color(GAME_SYSTEM_COLOR) if @game_look && name == :system

          found = @colors.named(name)
          return found if found

          name = :heading if name == :system
          return Style.const_get(TEXT_COLORS[name]) if TEXT_COLORS[name]
          return @colors.send(name) if LOOK_COLORS.include?(name)

          moving = animated(name, 0, 0, @width, @height)
          return moving.colors(1)[0] if moving

          Colors.unknown(@component, name)
          Style::TEXT
        end

        # Finds an animated color name of the component's theme and notes the place drawn in it, which
        # draws anew every few frames while the component shows.
        #
        # @param value [Object] The color.
        # @param x [Integer] The place's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @return [Animated, nil] The animated color, nil for any other color.
        def animated(value, x, y, width, height)
          lift = value.is_a?(Lifted) ? value.lift : 0
          value = value.name if value.is_a?(Lifted)
          return nil unless value.is_a?(Symbol) || value.is_a?(String)

          moving = @colors.animated(value.is_a?(Symbol) ? value : value.to_sym, lift)
          return nil unless moving

          @animated = true
          rect = @component.rect
          Colors.note(@component, Rect.new(rect.x + x, rect.y + y, width, height)) if rect
          moving
        end

        # Draws a text in an animated color letter by letter, each letter in its own color with the
        # outline of the plain text where it lies, cut or squeezed into its box as text says.
        #
        # A letter outlined by its own color took the light outline whenever its color ran dark,
        # which stood as a white box on the plate.
        #
        # @param x [Integer] The box's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String] The text.
        # @param options [Hash] See text.
        # @param moving [Animated] The color.
        # @return [Boolean] Whether the text was cut.
        def moving_text(x, y, width, height, text, options, moving)
          size = font_size(options[:size])
          shown = options[:cut] || options[:squeeze] ? UI.cut(UI.font_bitmap(size), text, options[:squeeze] ? (width / SQUEEZE).floor : width) : text
          letters = shown.scan(/./m)
          places = (0..letters.size).map { |count| LabelCache.width(letters[0, count].join, size) }
          factor = places.last > width ? width.to_f / places.last : 1.0
          room = width - (places.last * factor).round
          align = ALIGNS[options[:align]] || (options[:align].is_a?(Integer) ? options[:align] : 0)
          left = @left + x + (align == 1 ? room / 2 : (align == 2 ? room : 0))
          share = options[:opacity] ? UI.within(options[:opacity].to_i, 0, Component::OPAQUE) / Component::OPAQUE.to_f : 1.0
          outline = outline_of(options[:outline])
          Style.use_font(@bitmap, size, text_color(nil), outline)
          font = @bitmap.font
          font.outline = false if outline.equal?(false)
          font.out_color = faded(font.out_color, share)
          colors = moving.colors(letters.size)
          letters.each_with_index do |letter, index|
            next if letter.strip.empty?

            font.color = faded(@palette.drawn_text(colors[index]), share)
            step = places[index + 1] - places[index]
            @bitmap.draw_text(left + (places[index] * factor).round, @top + y, (step * factor).ceil + OUTLINE_ROOM, height, letter)
          end
          shown != text
        end

        # Fills an area in an animated color, in bands Colors::BAND pixels wide counted from the
        # component's left, each running from its color to the next band's; in one fill where every
        # band has the same color, as in a pulse. Each band lightens toward white by the color's lift.
        #
        # @param x [Integer] The area's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param moving [Animated] The color.
        def paint(x, y, width, height, moving)
          return if width <= 0 || height <= 0

          first = [x, 0].max / Colors::BAND
          last = [x + width - 1, 0].max / Colors::BAND
          colors = moving.colors(last + 2).map { |each| @palette.drawn(moving.lift > 0 ? mixed(each, WHITE, moving.lift / 100.0) : each) }
          values = colors[first..last + 1].map { |each| [each.red.to_i, each.green.to_i, each.blue.to_i, each.alpha.to_i] }
          return @bitmap.fill_rect(@left + x, @top + y, width, height, colors[first]) if values.uniq.size == 1

          (first..last).each do |band|
            start = band * Colors::BAND
            from = [start, x].max
            to = [start + Colors::BAND, x + width].min
            near = mixed(colors[band], colors[band + 1], (from - start).to_f / Colors::BAND)
            far = mixed(colors[band], colors[band + 1], (to - start).to_f / Colors::BAND)
            if @bitmap.respond_to?(:gradient_fill_rect)
              @bitmap.gradient_fill_rect(@left + from, @top + y, to - from, height, near, far)
            else
              @bitmap.fill_rect(@left + from, @top + y, to - from, height, near)
            end
          end
        end

        # Draws the frame of a rectangle one pixel thick in an animated color, see paint.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param moving [Animated] The color.
        def moving_outline(x, y, width, height, moving)
          paint(x, y, width, 1, moving)
          paint(x, y + height - 1, width, 1, moving)
          paint(x, y + 1, 1, height - 2, moving)
          paint(x + width - 1, y + 1, 1, height - 2, moving)
        end

        # Paints a pill row by row in a color, leaving out the pill a ring's pixels inside it.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Color, Symbol, Integer] The color, see color.
        # @param ring [Integer] The ring's pixels, 0 for the whole pill.
        def pill_rows(x, y, width, height, look, ring)
          return if width <= 0 || height <= 0

          moving = animated(look, x, y, width, height)
          plain = moving ? nil : color(look)
          outer = pill_insets(width, height)
          inner = ring > 0 ? pill_insets(width - 2 * ring, height - 2 * ring) : []
          height.times do |row|
            inset = outer[row]
            hole = row >= ring ? inner[row - ring] : nil
            if hole
              side = [ring + hole - inset, 1].max
              pill_span(x + inset, y + row, side, moving, plain)
              pill_span(x + width - inset - side, y + row, side, moving, plain)
            else
              pill_span(x + inset, y + row, width - 2 * inset, moving, plain)
            end
          end
        end

        # Paints one row of a pill.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param moving [Animated, nil] The color when it is animated.
        # @param plain [Color, nil] The color when it is not.
        def pill_span(x, y, width, moving, plain)
          return if width <= 0

          moving ? paint(x, y, width, 1, moving) : @bitmap.fill_rect(@left + x, @top + y, width, 1, plain)
        end

        # Tells how far each row of a pill starts in from its sides: its ends are half circles as
        # high as it, or as wide where it is narrower than high.
        #
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @return [Array<Integer>] The pixels by row from its top; none for a pill of no size.
        def pill_insets(width, height)
          return [] if width <= 0 || height <= 0

          radius = [width, height].min / 2.0
          straight = height / 2.0 - radius
          Array.new(height) do |row|
            rise = [(row + 0.5 - height / 2.0).abs - straight, 0].max
            (radius - Math.sqrt([radius * radius - rise * rise, 0].max)).round
          end
        end

        # Tells the color a share of the way from one color to another.
        #
        # @param from [Color] The one color.
        # @param to [Color] The other.
        # @param share [Float] How far, from 0 to 1.
        # @return [Color] The color between.
        def mixed(from, to, share)
          Color.new(from.red + (to.red - from.red) * share, from.green + (to.green - from.green) * share,
                    from.blue + (to.blue - from.blue) * share, from.alpha + (to.alpha - from.alpha) * share)
        end

        # Tells a color made see-through to a share of its alpha.
        #
        # @param color [Color] The color.
        # @param share [Float] The share, 1 for as it is.
        # @return [Color] The color.
        def faded(color, share)
          share < 1 ? Color.new(color.red, color.green, color.blue, color.alpha * share) : color
        end

        # Fills the part of a gauge a rate fills: one color, two from the left to the right, or with
        # vertical two or three from the top to the bottom.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param colors [Array<Color>] The colors.
        # @param vertical [Boolean] Whether they run from the top to the bottom.
        def fill_gauge(x, y, width, height, colors, vertical)
          return if width <= 0 || height <= 0
          return @bitmap.fill_rect(@left + x, @top + y, width, height, colors[0]) if colors.size < 2 || !@bitmap.respond_to?(:gradient_fill_rect)
          return @bitmap.gradient_fill_rect(@left + x, @top + y, width, height, colors[0], colors[1]) unless vertical

          if colors.size < 3
            @bitmap.gradient_fill_rect(@left + x, @top + y, width, height, colors[0], colors[1], true)
          else
            half = height / 2
            @bitmap.gradient_fill_rect(@left + x, @top + y, width, half, colors[0], colors[1], true)
            @bitmap.gradient_fill_rect(@left + x, @top + y + half, width, height - half, colors[1], colors[2], true)
          end
        end

        # Draws the theme's frame thick pixels deep along the inside of a rectangle: its rim the outer
        # pixel where the rim shows and its edge the rest, a frame of one pixel its edge alone, as
        # Style.draw_frame draws a box's frame two pixels deep.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param thick [Integer] Its pixels.
        # @param opacity [Integer, nil] How opaque it draws, nil for whole.
        def theme_border(x, y, width, height, thick, opacity)
          look = Style.colors(@palette)
          inset = 0
          if thick > 1 && look.rim.alpha.to_i > 0
            Style.draw_line_box(@bitmap, @left + x, @top + y, width, height, Style.see_through(look.rim, opacity))
            inset = 1
          end
          edge = Style.see_through(look.edge, opacity)
          [thick - 1, 1].max.times do |ring|
            deep = inset + ring
            Style.draw_line_box(@bitmap, @left + x + deep, @top + y + deep, width - 2 * deep, height - 2 * deep, edge)
          end
        end

        # Fills a rectangle in a color that thins from its alpha to nothing over its last pixels toward
        # a side, the rest of it solid.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param drawn [Color] The color.
        # @param side [Symbol] :left, :right, :top or :bottom.
        # @param pixels [Integer] How many pixels it thins over.
        def faded_fill(x, y, width, height, drawn, side, pixels)
          clear = Color.new(drawn.red, drawn.green, drawn.blue, 0)
          across = side == :left || side == :right
          pixels = UI.within(pixels, 0, across ? width : height)
          solid = (across ? width : height) - pixels
          case side
          when :left
            gradient(x, y, pixels, height, clear, drawn, false)
            @bitmap.fill_rect(@left + x + pixels, @top + y, solid, height, drawn) if solid > 0
          when :right
            @bitmap.fill_rect(@left + x, @top + y, solid, height, drawn) if solid > 0
            gradient(x + solid, y, pixels, height, drawn, clear, false)
          when :top
            gradient(x, y, width, pixels, clear, drawn, true)
            @bitmap.fill_rect(@left + x, @top + y + pixels, width, solid, drawn) if solid > 0
          else
            @bitmap.fill_rect(@left + x, @top + y, width, solid, drawn) if solid > 0
            gradient(x, y + solid, width, pixels, drawn, clear, true)
          end
        end

        # Fills a rectangle running from one color to another, with Bitmap#gradient_fill_rect where the
        # picture has it, else a line at a time.
        #
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param from [Color] The color at its left or top.
        # @param to [Color] The color at its right or bottom.
        # @param vertical [Boolean] Whether it runs from the top to the bottom.
        def gradient(x, y, width, height, from, to, vertical)
          return if width <= 0 || height <= 0
          return @bitmap.gradient_fill_rect(@left + x, @top + y, width, height, from, to, vertical) if @bitmap.respond_to?(:gradient_fill_rect)

          lines = vertical ? height : width
          lines.times do |line|
            shade = mixed(from, to, lines > 1 ? line.to_f / (lines - 1) : 0.0)
            vertical ? @bitmap.fill_rect(@left + x, @top + y + line, width, 1, shade) : @bitmap.fill_rect(@left + x + line, @top + y, 1, height, shade)
          end
        end

        # Tells a darker shade of a color, for what a gauge's rate lost and its :shade border.
        #
        # @param color [Color] The color.
        # @return [Color] Its shade at half its light.
        def darker(color)
          Color.new(color.red / 2, color.green / 2, color.blue / 2, color.alpha)
        end
      end
    end

    # Finds a text color of the game's window skin by its index, as the game's \C[n] code does; an
    # index past the skin's 32 colors from the game's own Window_Base#text_color, where mods add
    # theirs.
    #
    # @param index [Integer] The color's index.
    # @return [Color] The color; the plain text color when neither holds one there.
    def self.text_color(index)
      return game_text_color(index) unless index.between?(0, 31)

      color = Cache.system(Engine::Theme::GAME_SKIN).get_pixel(64 + (index % 8) * 8, 96 + (index / 8) * 8)
      color || Engine::Style::TEXT
    end

    # Asks the game's Window_Base#text_color for a color past the window skin's.
    #
    # @param index [Integer] The color's index.
    # @return [Color] The color; the plain text color before the game's data loaded or where the
    #   game holds none.
    def self.game_text_color(index)
      window = Engine::Escapes.converter
      color = window && window.send(:text_color, index)
      color.is_a?(Color) ? color : Engine::Style::TEXT
    rescue StandardError
      Engine::Style::TEXT
    end
  end
end
