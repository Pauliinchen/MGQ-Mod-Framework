#----------------------------------------------------------------
#  glyph_cache.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed the timing of both ways to draw a text, which only the probe's tuning used
#      Paulinchen  2026-11-05: Drew at most a few characters anew each frame, a text needing more drawn whole meanwhile, and
#                              drew the common characters of the common looks ahead while the title or the map shows, on up to
#                              eight sheets
#      Paulinchen  2026-11-04: Put the characters on a few shared sheets instead of two pictures each
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A few shared pictures that many small pictures lie on, so a cache holds a few pictures instead
      # of one each, since every picture holds Windows GDI handles: each small picture takes room on
      # a shelf of its height, and once the most sheets are full the least recently used one is
      # cleared and what lay on it forgotten.
      class Sheets
        # A shared picture: the picture, its shelves (each [top, height, the left of its free room]),
        # the top of its free room below them, what lies on it and the use that used it last.
        Sheet = Struct.new(:bitmap, :shelves, :bottom, :entries, :used)

        # Makes the sheets, none drawn yet.
        #
        # @param width [Integer] A sheet's width in pixels.
        # @param height [Integer] Its height.
        # @param most [Integer] The most sheets.
        # @yieldparam sheet [Sheet] A sheet about to be cleared or dropped; the block forgets the
        #   entries on it.
        def initialize(width, height, most, &forget)
          @width = width
          @height = height
          @most = most
          @forget = forget
          @sheets = []
          @stamp = 0
        end

        # Starts a use, such as a draw, whose sheets making room never clears once marked.
        def use
          @stamp += 1
        end

        # Marks a sheet used by the use going on.
        #
        # @param sheet [Sheet] The sheet.
        def mark(sheet)
          sheet.used = @stamp
        end

        # Finds room on a sheet: on a sheet with room, else on a new sheet while fewer than the most
        # exist, else on the least recently used sheet, cleared, unless the use going on marked it.
        #
        # @param width [Integer] The room's width.
        # @param height [Integer] Its height.
        # @return [Array, nil] The sheet and the room's left and top; nil where none is found.
        def place(width, height)
          return nil if width > @width || height > @height

          @sheets.each do |sheet|
            spot = spot_on(sheet, width, height)
            return [sheet] + spot if spot
          end
          sheet = spare_sheet
          sheet && [sheet] + spot_on(sheet, width, height)
        end

        # Drops a sheet something else freed, forgetting what lay on it.
        #
        # @param sheet [Sheet] The sheet.
        def drop(sheet)
          forget(sheet)
          @sheets.delete(sheet)
        end

        # Frees every sheet without forgetting what lay on them, which the cache forgets itself.
        def clear
          @sheets.each { |sheet| sheet.bitmap.dispose unless sheet.bitmap.disposed? }
          @sheets = []
        end

        # Tells how many sheets there are.
        #
        # @return [Integer] The sheets.
        def count
          @sheets.size
        end

        # Tells the bytes the sheets take.
        #
        # @return [Integer] The bytes.
        def bytes
          @sheets.size * @width * @height * 4
        end

        private

        # Takes room on a sheet from a shelf of the same height, or from a new shelf below the others.
        #
        # @param sheet [Sheet] The sheet.
        # @param width [Integer] The room's width.
        # @param height [Integer] Its height.
        # @return [Array<Integer>, nil] The room's left and top, nil where the sheet has none.
        def spot_on(sheet, width, height)
          shelf = sheet.shelves.find { |_top, tall, free| tall == height && free + width <= @width }
          unless shelf
            return nil if sheet.bottom + height > @height

            shelf = [sheet.bottom, height, 0]
            sheet.shelves << shelf
            sheet.bottom += height
          end
          left = shelf[2]
          shelf[2] += width
          [left, shelf[0]]
        end

        # Hands out an empty sheet: a new one while fewer than the most exist, else the least
        # recently used one cleared.
        #
        # @return [Sheet, nil] The sheet, nil where the use going on marked every sheet.
        def spare_sheet
          if @sheets.size < @most
            sheet = Sheet.new(Bitmap.new(@width, @height), [], 0, [], 0)
            @sheets << sheet
            return sheet
          end
          sheet = @sheets.min_by { |one| one.used }
          return nil if sheet.used == @stamp

          forget(sheet)
          sheet.bitmap.clear
          sheet.shelves = []
          sheet.bottom = 0
          sheet
        end

        # Has the cache forget what lies on a sheet.
        #
        # @param sheet [Sheet] The sheet.
        def forget(sheet)
          @forget.call(sheet)
          sheet.entries = []
        end
      end

      # Each character drawn once per font, size, color, outline and line height, and a text put
      # together from copies of its characters, since Bitmap#draw_text costs the game far more than
      # copying a small picture. Characters are drawn as a text first needs them, so a text of the
      # untranslated game in Japanese works as one in English.
      #
      # The characters lie on at most MOST_SHEETS shared sheets, so the cache holds at most nine
      # pictures (the sheets and the one that measures), since every picture holds Windows GDI
      # handles and a picture per character ran the game out of them.
      #
      # A text is put together only where the result matches draw_text: the font measures a text as
      # the sum of its characters (checked once per font and size on texts a font may kern), each
      # character stands on its own (no combining marks, no joined scripts such as Arabic or Thai,
      # nothing past U+FFFF), and the text fits its box, which draw_text would squeeze. Anything else
      # draws with draw_text, as does every text while the glyphs are off.
      module GlyphCache
        # The bytes the sheets may take at most.
        BUDGET = 4 * 1024 * 1024

        # A sheet's width and height in pixels.
        SHEET_WIDTH = 512
        SHEET_HEIGHT = 256

        # The most sheets, each taking four bytes a pixel, within BUDGET.
        MOST_SHEETS = BUDGET / (SHEET_WIDTH * SHEET_HEIGHT * 4)

        # The room beside a character in its cell, where its outline and its strokes may reach past
        # its width.
        PAD = 4

        # The pixels kept empty right of and below each character's place on a sheet, so ink that
        # reaches past a cell never lands on its neighbor.
        GAP = 2

        # The most fonts and sizes whose widths are kept; more empty them all.
        MOST_FONTS = 64

        # The most character widths kept per font and size; more empty that font's.
        MOST_WIDTHS = 4096

        # Texts a font may kern, each set closer than its characters, which the check per font measures.
        KERNED = ["AV", "To", "Wa", "LT", "y,", "r.", "fi"]

        # The text the check per font draws both ways and compares where the game can read pixels.
        SAMPLE = "AVTo Wa.y,fi 17"

        # The share of a sample's pixels that may differ between draw_text and the copies, and how far
        # a color value may differ before a pixel counts.
        PIXEL_SHARE = 0.02
        PIXEL_STEP = 64

        # The characters a text built from copies cannot hold, as ranges of code points: control
        # characters, combining marks, scripts whose letters join or reorder, zero-width and
        # direction marks, variation selectors and the specials.
        UNPLACEABLE = [[0x00, 0x1F], [0x7F, 0x9F], [0x0300, 0x036F], [0x0483, 0x0489], [0x0591, 0x08FF], [0x0900, 0x0DFF], [0x0E00, 0x0FFF],
                       [0x1000, 0x109F], [0x1100, 0x11FF], [0x1780, 0x17FF], [0x1AB0, 0x1AFF], [0x1DC0, 0x1DFF], [0x200B, 0x200F],
                       [0x202A, 0x202E], [0x2060, 0x206F], [0x20D0, 0x20FF], [0x3099, 0x309A], [0xFE00, 0xFE0F], [0xFE20, 0xFE2F],
                       [0xFFF9, 0xFFFF]]

        # The last code point a text built from copies holds.
        LAST_PLACEABLE = 0xFFFF

        # The characters that draw nothing, only take room.
        BLANKS = [0x20, 0x3000]


        # The characters drawn anew in one frame at most, the first text of a frame excepted; a text
        # that needs more draws whole with draw_text, which costs a screen's first opening far less
        # than drawing each of its characters twice, and leaves them to a later frame.
        FRAME_GLYPHS = 8

        # What the first check of a font's pixels counts against FRAME_GLYPHS.
        CHECK_GLYPHS = 8

        # The characters drawn ahead in one frame while the title shows, which waits on nothing; the
        # map draws FRAME_GLYPHS a frame.
        WARM_GLYPHS = 36

        # The characters drawn ahead while the title shows, in the looks of WARM_LOOKS.
        WARM_TEXT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,:;+-%/()'!?"

        # The looks most texts take, each [font size, color name, line height's size name], drawn
        # ahead in that order.
        WARM_LOOKS = [[Style::TEXT_SIZE, :text, nil], [Style::SMALL_SIZE, :text, :small], [Style::TEXT_SIZE, :system, nil],
                      [Style::SMALL_SIZE, :system, :small], [Style::TITLE_SIZE, :text, nil], [Style::TINY_SIZE, :text, :tiny]]

        # A character drawn: the sheet it lies on (its entries each [look, code point], see
        # face_key), its outline's place there (nil for a font without outline) and its letter's
        # place.
        Glyph = Struct.new(:sheet, :stroke, :fill)

        # A font at a size: a copy of the font that measures, the room a text gets past the widths of
        # its characters, whether texts in it may be built from copies, and the widths of its
        # characters by code point.
        Metric = Struct.new(:font, :extra, :faithful, :widths)

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "glyph cache"

        # Whether texts are built from copies; off, every text draws with draw_text.
        @on = true

        # The fonts and sizes measured, by their key, see metric_key.
        @metrics = {}

        # The characters drawn by the look they were drawn in (see face_key), each by its code point.
        @faces = {}

        # The frame whose characters were counted against FRAME_GLYPHS, and how many.
        @spent_frame = nil
        @spent = 0

        # The place in WARM_LOOKS of the look whose characters are drawn ahead next.
        @warm_place = 0

        # The sheets the characters lie on, each draw a use of them.
        @sheets = Sheets.new(SHEET_WIDTH, SHEET_HEIGHT, MOST_SHEETS) { |sheet| forget(sheet) }

        # The picture every font measures on, and the font measured it is set to.
        @measure = nil
        @measured = nil

        # Tells whether texts are built from copies.
        #
        # @return [Boolean] Whether they are.
        def self.on?
          @on
        end

        # Turns building texts from copies on or off, such as to measure draw_text against it.
        #
        # @param on [Boolean] Whether texts are built from copies.
        def self.on=(on)
          @on = on ? true : false
        end

        # Draws a text from copies of its characters as Bitmap#draw_text would draw it in the
        # picture's font.
        #
        # @param bitmap [Bitmap] The picture, its font set.
        # @param x [Integer] The box's left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String] The text.
        # @param align [Integer] 0 for left, 1 for centered, 2 for right.
        # @return [Boolean] Whether it drew the text; false leaves the text to draw_text.
        def self.draw(bitmap, x, y, width, height, text, align = 0)
          return false unless @on

          codes = placeable(text)
          return false unless codes

          font = bitmap.font
          metric = metric(font)
          return false unless metric && affordable?(metric, font, height, codes) && faithful?(metric, font, height)

          total = codes.inject(metric.extra) { |sum, code| sum + width_of(metric, code) }
          return false if total > width

          glyphs = glyphs_for(metric, font, codes, height)
          return false unless glyphs

          left = x + (align == 1 ? (width - total) / 2 : (align == 2 ? width - total : 0))
          paste(bitmap, glyphs, metric, codes, left, y, font.outline)
          true
        rescue => e
          log_once([:draw, e.class], "building a text from its characters FAILED, texts draw whole: #{Logging.failure(e)}")
          @on = false
          false
        end

        # Draws characters from copies each at its own place, as a text set narrower than it is
        # draws them: every outline first, then the letters.
        #
        # @param bitmap [Bitmap] The picture, its font set.
        # @param x [Integer] Where the places count from.
        # @param y [Integer] The line's top.
        # @param height [Integer] Its height.
        # @param places [Array<Array>] Each character's left from x and the character.
        # @return [Boolean] Whether it drew them; false leaves them to draw_text.
        def self.draw_placed(bitmap, x, y, height, places)
          return false unless @on

          codes = placeable(places.map { |_left, char| char }.join)
          return false unless codes && codes.size == places.size

          font = bitmap.font
          metric = metric(font)
          return false unless metric && affordable?(metric, font, height, codes) && faithful?(metric, font, height)

          glyphs = glyphs_for(metric, font, codes, height)
          return false unless glyphs

          (font.outline ? [:stroke, :fill] : [:fill]).each do |layer|
            places.each_with_index { |(left, _char), index| bitmap.blt(x + left - PAD, y, glyphs[index].sheet.bitmap, glyphs[index][layer]) if glyphs[index] }
          end
          true
        rescue => e
          log_once([:draw, e.class], "building a text from its characters FAILED, texts draw whole: #{Logging.failure(e)}")
          @on = false
          false
        end

        # Measures a text in a picture's font as Bitmap#text_size would, from the widths of its
        # characters.
        #
        # @param bitmap [Bitmap] A picture, its font set.
        # @param text [String] The text.
        # @return [Integer, nil] Its width, nil where the font or the text is not built from copies.
        def self.width(bitmap, text)
          return nil unless @on

          codes = placeable(text)
          metric = codes && metric(bitmap.font)
          return nil unless metric && metric.faithful

          codes.inject(metric.extra) { |sum, code| sum + width_of(metric, code) }
        end

        # Draws the characters of WARM_TEXT ahead, within a frame's budget, in the next look of
        # WARM_LOOKS that is not drawn yet. Called every frame while the title or the map shows.
        #
        # @param budget [Integer] The characters the frame may draw.
        def self.warm_frame(budget)
          return unless @on && @warm_place < WARM_LOOKS.size

          size, color, line = WARM_LOOKS[@warm_place]
          height = UI.line_height_of(line)
          bitmap = Scratch.bitmap(Graphics.width, height)
          Style.use_font(bitmap, size, Palette.live.named(color) || Style::TEXT)
          font = bitmap.font
          metric = metric(font)
          return unless metric

          codes = WARM_TEXT.unpack("U*")
          missing = []
          glyphs = @faces[face_key(font, height)]
          codes.each { |code| missing << code unless glyphs && glyphs[code] }
          return @warm_place += 1 if missing.empty?

          chunk = missing[0, metric.faithful.nil? ? 1 : budget]
          return unless affordable?(metric, font, height, chunk, budget) && faithful?(metric, font, height)

          glyphs_for(metric, font, chunk, height)
        rescue => e
          log_once([:warm, e.class], "drawing the characters ahead FAILED: #{Logging.failure(e)}")
          @warm_place = WARM_LOOKS.size
        end

        # Draws the characters ahead while the title shows, WARM_GLYPHS a frame, and while the map
        # shows, FRAME_GLYPHS a frame, once the game runs.
        def self.install
          return unless defined?(::Scene_Base) && ::Scene_Base.method_defined?(:update)

          Hooks.after(::Scene_Base, :update, "Mod Framework glyphs ahead") { Mod_Framework::UI::Engine::GlyphCache.warm_scene(self) }
        end

        # Draws characters ahead in a frame of a scene, see install.
        #
        # @param scene [Scene_Base] The scene.
        def self.warm_scene(scene)
          return if @warm_place >= WARM_LOOKS.size

          if defined?(::Scene_Title) && scene.is_a?(::Scene_Title)
            warm_frame(WARM_GLYPHS)
          elsif defined?(::Scene_Map) && scene.is_a?(::Scene_Map)
            warm_frame(FRAME_GLYPHS)
          end
        end

        # Tells whether what a text still needs may be drawn in this frame: its characters not drawn
        # yet and the first check of its font's pixels, counted against FRAME_GLYPHS when they may.
        #
        # @param metric [Metric] The font measured.
        # @param font [Font] The font, its colors as the text draws.
        # @param height [Integer] The line's height.
        # @param codes [Array<Integer>] The text's code points.
        # @param budget [Integer] The characters a frame may draw.
        # @return [Boolean] Whether they may.
        def self.affordable?(metric, font, height, codes, budget = FRAME_GLYPHS)
          glyphs = @faces[face_key(font, height)]
          needed = glyphs ? codes.count { |code| !glyphs[code] && !BLANKS.include?(code) } : codes.size
          needed += CHECK_GLYPHS if metric.faithful.nil?
          needed == 0 || spend(needed, budget)
        end
        private_class_method :affordable?

        # Counts characters to draw against this frame's FRAME_GLYPHS: those of the first text of a
        # frame always, later ones only while they fit.
        #
        # @param count [Integer] The characters.
        # @param budget [Integer] The characters a frame may draw.
        # @return [Boolean] Whether they may be drawn.
        def self.spend(count, budget = FRAME_GLYPHS)
          frame = Key.frame
          unless frame == @spent_frame
            @spent_frame = frame
            @spent = 0
          end
          return false if @spent > 0 && @spent + count > budget

          @spent += count
          true
        end
        private_class_method :spend

        # Draws a text whole with Bitmap#draw_text aligned left, starting at x, behind a space in a
        # box that starts a space further left.
        #
        # draw_text cuts what reaches left of where its text starts, such as the outline of a letter
        # reaching left of its place, and starts a centered or right aligned text a pixel left of
        # where its measure puts it.
        #
        # @param bitmap [Bitmap] The picture, its font set.
        # @param x [Integer] Where the text starts.
        # @param y [Integer] Its box's top.
        # @param width [Integer] Its box's width from x.
        # @param height [Integer] Its box's height.
        # @param text [String] The text.
        def self.draw_whole(bitmap, x, y, width, height, text)
          lead = width_of(metric(bitmap.font), BLANKS.first)
          bitmap.draw_text(x - lead, y, width + lead, height, " " + text)
        end

        # Frees every sheet and forgets every character drawn and every font measured.
        def self.clear
          @sheets.clear
          @faces = {}
          @metrics = {}
          @measure.dispose if @measure && !@measure.disposed?
          @measure = nil
          @measured = nil
        end

        # Tells how many characters are kept and the bytes their sheets take.
        #
        # @return [Array<Integer>] The characters and the bytes.
        def self.size
          [@faces.values.inject(0) { |sum, glyphs| sum + glyphs.size }, @sheets.bytes]
        end

        # Tells a text's code points where each can be built from a copy.
        #
        # @param text [String] The text.
        # @return [Array<Integer>, nil] The code points, nil for a text that draws whole.
        def self.placeable(text)
          codes = text.unpack("U*")
          codes.all? { |code| placeable_code?(code) } ? codes : nil
        rescue ArgumentError
          nil
        end

        # Tells whether a character can be built from a copy, see UNPLACEABLE.
        #
        # @param code [Integer] Its code point.
        # @return [Boolean] Whether it can.
        def self.placeable_code?(code)
          return true if (code > 0x1F && code < 0x7F) || (code > 0x9F && code < 0x0300)
          return false if code > LAST_PLACEABLE

          UNPLACEABLE.none? { |first, last| code >= first && code <= last }
        end

        # Tells the font and size of a font, measured the first time: the room past the characters'
        # widths and their first widths.
        #
        # @param font [Font] The font.
        # @return [Metric, nil] The font measured, nil when it cannot be.
        def self.metric(font)
          key = metric_key(font)
          found = @metrics[key]
          return found if found

          clear_metrics if @metrics.size >= MOST_FONTS
          copy = Font.new
          copy_font(copy, font)
          metric = Metric.new(copy, 0, nil, {})
          measure = measure(metric)
          metric.extra = 2 * measure.text_size("H").width - measure.text_size("HH").width
          @metrics[key] = metric
        end
        private_class_method :metric

        # Hands out the picture every font measures on, set to a font measured.
        #
        # @param metric [Metric] The font measured.
        # @return [Bitmap] The picture.
        def self.measure(metric)
          if @measure.nil? || @measure.disposed?
            @measure = Bitmap.new(1, 1)
            @measured = nil
          end
          unless @measured.equal?(metric)
            copy_font(@measure.font, metric.font)
            @measured = metric
          end
          @measure
        end
        private_class_method :measure

        # Tells whether texts in a font may be built from copies, checked the first time: each text a
        # font may kern measures as the sum of its characters, and where the game reads pixels, the
        # sample drawn from copies looks as draw_text draws it.
        #
        # @param metric [Metric] The font measured.
        # @param font [Font] The font, its colors as the text draws.
        # @param height [Integer] The line's height.
        # @return [Boolean] Whether they may.
        def self.faithful?(metric, font, height)
          return metric.faithful unless metric.faithful.nil?

          kerned = KERNED.find { |pair| measure(metric).text_size(pair).width != pair.unpack("U*").inject(metric.extra) { |sum, code| sum + width_of(metric, code) } }
          differing = kerned ? nil : differing_share(metric, font, height)
          metric.faithful = kerned.nil? && (differing.nil? || differing <= PIXEL_SHARE)
          why = kerned ? "it sets \"#{kerned}\" closer than its letters" : (differing ? format("%.1f%% of the sample's pixels differ", differing * 100) : "the pixels were not compared")
          log("#{describe(font)}: texts #{metric.faithful ? 'are built from their characters' : 'draw whole'}, #{why}")
          metric.faithful
        end
        private_class_method :faithful?

        # Draws the sample both ways and tells the share of its pixels that differ, where the game
        # reads pixels.
        #
        # @param metric [Metric] The font measured.
        # @param font [Font] The font.
        # @param height [Integer] The line's height.
        # @return [Float, nil] The share, nil where pixels cannot be read.
        def self.differing_share(metric, font, height)
          return nil unless Bitmap.method_defined?(:get_pixel)

          codes = SAMPLE.unpack("U*")
          glyphs = glyphs_for(metric, font, codes, height)
          return nil unless glyphs

          width = measure(metric).text_size(SAMPLE).width + 2 * PAD
          whole = Bitmap.new(width, height)
          built = Bitmap.new(width, height)
          copy_font(whole.font, font)
          draw_whole(whole, PAD, 0, width - PAD, height, SAMPLE)
          paste(built, glyphs, metric, codes, PAD, 0, font.outline)
          differing = 0
          width.times do |x|
            height.times { |y| differing += 1 if far_apart?(whole.get_pixel(x, y), built.get_pixel(x, y)) }
          end
          differing.to_f / (width * height)
        ensure
          whole.dispose if whole && !whole.disposed?
          built.dispose if built && !built.disposed?
        end
        private_class_method :differing_share

        # Tells whether two pixels differ visibly.
        #
        # @param one [Color] A pixel.
        # @param other [Color] Another.
        # @return [Boolean] Whether a color value differs by PIXEL_STEP or more.
        def self.far_apart?(one, other)
          (one.alpha - other.alpha).abs >= PIXEL_STEP || (one.alpha > 0 && other.alpha > 0 &&
            ((one.red - other.red).abs >= PIXEL_STEP || (one.green - other.green).abs >= PIXEL_STEP || (one.blue - other.blue).abs >= PIXEL_STEP))
        end
        private_class_method :far_apart?

        # Copies the characters of a text onto a picture, all outlines first and the letters over
        # them, so no letter hides under the outline of the next as with draw_text.
        #
        # @param bitmap [Bitmap] The picture.
        # @param glyphs [Array<Glyph, nil>] The text's characters drawn, nil for a blank.
        # @param metric [Metric] The font measured.
        # @param codes [Array<Integer>] The text's code points.
        # @param left [Integer] Where the text starts.
        # @param top [Integer] Its box's top.
        # @param outline [Boolean] Whether the font has an outline.
        def self.paste(bitmap, glyphs, metric, codes, left, top, outline)
          layers = outline ? [:stroke, :fill] : [:fill]
          layers.each do |layer|
            x = left
            codes.each_with_index do |code, index|
              glyph = glyphs[index]
              bitmap.blt(x - PAD, top, glyph.sheet.bitmap, glyph[layer]) if glyph
              x += width_of(metric, code)
            end
          end
        end
        private_class_method :paste

        # Hands out a text's characters drawn in its look, drawing each the first time, and marks
        # their sheets used by this draw so making room never clears them.
        #
        # @param metric [Metric] The font measured.
        # @param font [Font] The font, its colors as the text draws.
        # @param codes [Array<Integer>] The text's code points.
        # @param height [Integer] The line's height.
        # @return [Array<Glyph, nil>, nil] The characters, nil for a blank; nil when a character
        #   finds no room on the sheets.
        def self.glyphs_for(metric, font, codes, height)
          @sheets.use
          key = face_key(font, height)
          glyphs = (@faces[key] ||= {})
          codes.map do |code|
            next nil if BLANKS.include?(code)

            glyph = glyphs[code]
            if glyph && glyph.sheet.bitmap.disposed?
              @sheets.drop(glyph.sheet)
              glyph = nil
            end
            unless glyph
              glyph = draw_glyph(metric, font, code, height, key)
              return nil unless glyph

              # Making room may have cleared the last character of this look and forgotten it.
              glyphs = (@faces[key] ||= {})
              glyphs[code] = glyph
            end
            @sheets.mark(glyph.sheet)
            glyph
          end
        end
        private_class_method :glyphs_for

        # Draws one character straight onto a sheet: its outline in the outline's color, and its
        # letter with an outline that does not show, each PAD into a cell where draw_text puts them,
        # so its outline and a letter reaching left of its place keep their room in the cell.
        #
        # @param metric [Metric] The font measured.
        # @param font [Font] The font.
        # @param code [Integer] The character's code point.
        # @param height [Integer] The line's height.
        # @param key [Array] The look it is drawn in, see face_key.
        # @return [Glyph, nil] The character drawn, nil when no sheet has room.
        def self.draw_glyph(metric, font, code, height, key)
          char = [code].pack("U")
          width = measure(metric).text_size(char).width + 2 * PAD
          room = (font.outline ? 2 : 1) * (width + GAP)
          placed = @sheets.place(room, height + GAP)
          return nil unless placed

          sheet, left, top = placed
          picture = sheet.bitmap
          picture.clear_rect(left, top, room, height + GAP)
          stroke = nil
          if font.outline
            copy_font(picture.font, font)
            picture.font.color = Color.new(font.out_color.red, font.out_color.green, font.out_color.blue, font.out_color.alpha)
            draw_whole(picture, left + PAD, top, width - PAD, height, char)
            stroke = Rect.new(left, top, width, height)
            left += width + GAP
          end
          copy_font(picture.font, font)
          picture.font.out_color = Color.new(0, 0, 0, 0) if font.outline
          draw_whole(picture, left + PAD, top, width - PAD, height, char)
          sheet.entries << [key, code]
          Glyph.new(sheet, stroke, Rect.new(left, top, width, height))
        end
        private_class_method :draw_glyph

        # Tells a character's width in a font, measured the first time without the room draw_text
        # keeps past a whole text, which counts once.
        #
        # @param metric [Metric] The font measured.
        # @param code [Integer] The character's code point.
        # @return [Integer] The width.
        def self.width_of(metric, code)
          widths = metric.widths
          found = widths[code]
          return found if found

          widths.clear if widths.size >= MOST_WIDTHS
          char = [code].pack("U")
          widths[code] = measure(metric).text_size(char).width - metric.extra
        end
        private_class_method :width_of

        # Forgets the characters on a sheet about to be cleared or dropped, and each look left without
        # characters.
        #
        # @param sheet [Sheets::Sheet] The sheet.
        def self.forget(sheet)
          sheet.entries.each do |key, code|
            glyphs = @faces[key]
            next unless glyphs && glyphs[code] && glyphs[code].sheet.equal?(sheet)

            glyphs.delete(code)
            @faces.delete(key) if glyphs.empty?
          end
        end
        private_class_method :forget

        # Forgets every font measured.
        def self.clear_metrics
          @metrics = {}
          @measured = nil
        end
        private_class_method :clear_metrics

        # Sets a font as another is set: its name, size, weight, slant, outline and colors.
        #
        # @param font [Font] The font to set.
        # @param from [Font] The font it copies.
        def self.copy_font(font, from)
          font.name = from.name
          font.size = from.size
          font.bold = from.bold
          font.italic = from.italic
          font.outline = from.outline
          font.color = Color.new(from.color.red, from.color.green, from.color.blue, from.color.alpha)
          font.out_color = Color.new(from.out_color.red, from.out_color.green, from.out_color.blue, from.out_color.alpha) if from.out_color
          font.shadow = false if font.respond_to?(:shadow=)
        end
        private_class_method :copy_font

        # Tells what a font measures by: its name, size, weight, slant and outline.
        #
        # @param font [Font] The font.
        # @return [Array] The key.
        def self.metric_key(font)
          [font.name.is_a?(Array) ? font.name.join(",") : font.name.to_s, font.size, font.bold ? true : false, font.italic ? true : false, font.outline ? true : false]
        end
        private_class_method :metric_key

        # Tells what a character is drawn by: its font, its colors and its line's height.
        #
        # @param font [Font] The font.
        # @param height [Integer] The line's height.
        # @return [Array] The key.
        def self.face_key(font, height)
          out = font.out_color
          color = font.color
          metric_key(font) + [color.red, color.green, color.blue, color.alpha, out && out.red, out && out.green, out && out.blue, out && out.alpha, height]
        end
        private_class_method :face_key

        # Names a font and size for the log.
        #
        # @param font [Font] The font.
        # @return [String] Its name and size.
        def self.describe(font)
          name = font.name.is_a?(Array) ? font.name.first : font.name
          "#{name} #{font.size}#{font.bold ? ' bold' : ''}#{font.italic ? ' italic' : ''}#{font.outline ? ' outlined' : ''}"
        end
        private_class_method :describe
      end
    end

    # Once the game runs, the title draws the common characters ahead.
    Run.on_start("glyphs ahead") { Mod_Framework::UI::Engine::GlyphCache.install }
  end
end
