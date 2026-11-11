#----------------------------------------------------------------
#  text.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Named the topic that lays out the rows of a log
#      Paulinchen  2026-11-09: Read a width given as pixels or as texts of which the widest sets it
#      Paulinchen  2026-11-07: Found where a part occurs in a text through C#
#                            - Added the rule by which a typed text matches a word, worked out in C#
#                            - Left the typing flag to the box open, which UI.typing? reads
#      Paulinchen  2026-11-06: Kept the first lines of a wrapped text, the last one ending with the ellipsis where more follow
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Named the box in the tick by a frozen text, which the tick keeps without a copy
#                            - Opened a box that types a whole number within bounds, and kept the number it gives
#                            - Measured texts from the widths of their characters where texts are built from them
#                            - Took a color code's color name, such as \C[primary], as one code
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-31: Put back the typing flag another mod had set once a box closed
#                            - Started a new line at a line break of a wrapped text
#      Paulinchen  2026-10-30: Read and wrote the clipboard through the engine on JoiPlay
#      Paulinchen  2026-10-29: Added the clipboard's text for mods
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # What ends a text cut to fit.
    ELLIPSIS = "..."

    # Measures a text as Bitmap#text_size does in the font of what draws it: from the widths of its
    # characters where texts in that font are built from them (GlyphCache), else as the game
    # measures it, which costs the game far more.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
    # @param text [String] The text.
    # @return [Integer] Its width in pixels.
    def self.text_width(measure, text)
      text = text.to_s
      bitmap = measure.is_a?(::Bitmap) ? measure : (measure.respond_to?(:contents) ? measure.contents : nil)
      width = text.empty? || bitmap.nil? || !defined?(Engine::GlyphCache) ? nil : Engine::GlyphCache.width(bitmap, text)
      width || measure.text_size(text).width
    end

    # Reads a width given as pixels or as texts that should fit, such as captions that line up:
    # the widest of the texts in a font, with room for its outline.
    #
    # @param value [Numeric, Array, nil] The pixels, or the texts.
    # @param px [Integer] The texts' font size in pixels.
    # @return [Integer, nil] The pixels, nil for neither given.
    def self.measured_width(value, px)
      return whole(value) if value.is_a?(Numeric)
      return nil unless value.is_a?(Array)

      bitmap = font_bitmap(px)
      value.map { |text| text_width(bitmap, text.to_s) }.max.to_i + Engine::Canvas::OUTLINE_ROOM
    end

    # Cuts a text at its end until it fits a width with ELLIPSIS and what follows it: in C# by the
    # characters' widths (see Glyphs), else, while the bridge is closed or for a font whose widths do
    # not add up, by measuring here (cut_measured).
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
    # @param text [String] The text.
    # @param width [Integer] The width in pixels.
    # @param tail [String] What follows the text and stays whole, such as a count or a floor.
    # @return [String] The text with the tail when they fit, else the text's start, ELLIPSIS and the tail.
    def self.cut(measure, text, width, tail = "")
      text = text.to_s
      tail = tail.to_s
      cut = Engine::Glyphs.ask(Engine::Glyphs::CUT, measure, text + tail) { |key| [key, width, text, tail] }
      cut.is_a?(String) ? cut : cut_measured(measure, text, width, tail)
    end

    # Cuts a text as cut does, measuring each try with the measure.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
    # @param text [String] The text.
    # @param width [Integer] The width in pixels.
    # @param tail [String] What follows the text and stays whole.
    # @return [String] The text cut, see cut.
    def self.cut_measured(measure, text, width, tail = "")
      text = text.to_s
      return "#{text}#{tail}" if text_width(measure, "#{text}#{tail}") <= width

      # Halving the length keeps the measures few, which are slow in the game.
      fits = 0
      over = text.size
      while over - fits > 1
        length = (fits + over) / 2
        text_width(measure, "#{text[0, length].rstrip}#{ELLIPSIS}#{tail}") <= width ? fits = length : over = length
      end
      "#{text[0, fits].rstrip}#{ELLIPSIS}#{tail}"
    end

    # Breaks a text into lines that fit a width, at its spaces, and inside a word longer than the
    # width, a line break starting a new line: in C# by the characters' widths, else by measuring
    # here (wrap_measured), see cut.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font the lines are drawn in.
    # @param text [String] The text.
    # @param width [Integer] The width in pixels.
    # @return [Array<String>] The lines.
    def self.wrap(measure, text, width)
      text = text.to_s
      lines = Engine::Glyphs.ask(Engine::Glyphs::WRAP, measure, text) { |key| [key, width, text] }
      lines.is_a?(Array) ? lines : wrap_measured(measure, text, width)
    end

    # Keeps the first lines of a wrapped text, the last one kept ending with ELLIPSIS where more
    # follow.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font the lines are drawn in.
    # @param lines [Array<String>] The lines, as wrap breaks them.
    # @param kept [Integer] The most lines kept, at least 1.
    # @param width [Integer] The width of a line in pixels.
    # @return [Array<String>] The lines kept.
    def self.keep_lines(measure, lines, kept, width)
      return lines if lines.size <= kept

      last = cut(measure, lines[kept - 1..-1].join(" "), width)
      last = cut(measure, last + ELLIPSIS, width) unless last.end_with?(ELLIPSIS)
      lines.first(kept - 1) + [last]
    end

    # Breaks a text into lines as wrap does, measuring each try with the measure.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font the lines are drawn in.
    # @param text [String] The text.
    # @param width [Integer] The width in pixels.
    # @return [Array<String>] The lines.
    def self.wrap_measured(measure, text, width)
      return text.split("\n", -1).inject([]) { |all, part| all + wrap_measured(measure, part, width) } if text.include?("\n")

      lines = [""]
      text.split(" ").each do |word|
        candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
        if text_width(measure, candidate) <= width
          lines[-1] = candidate
          next
        end

        lines.push("") unless lines.last.empty?
        word.each_char do |char|
          lines.push("") if text_width(measure, lines.last + char) > width && !lines.last.empty?
          lines[-1] += char
        end
      end
      lines
    end

    # Breaks a text into lines that keep every character's place, as wrap_spans does: in C# by the
    # characters' widths (see Glyphs), else, while the bridge is closed or for a font whose widths do
    # not add up, measuring here.
    #
    # @param measure [Bitmap, Window_Base, nil] What measures a text with the font the lines are
    #   drawn in, nil for a box that counts characters, each one cell wide.
    # @param text [String] The text.
    # @param width [Integer] The width in pixels, or in characters without a measure.
    # @return [Array<Array<Integer>>] Each line's first character and length, one empty line for an
    #   empty text.
    def self.spans(measure, text, width)
      text = text.to_s
      spans = Engine::Glyphs.ask(Engine::Glyphs::SPANS, measure, text) { |key| [key, width, text] }
      return spans if spans.is_a?(Array)

      measure ? wrap_spans(text, width) { |part| text_width(measure, part) } : wrap_spans(text, width) { |part| part.length }
    end

    # Breaks a text into lines that fit a width without changing a character of it, so a place in
    # the text is a place in a line: each line is a stretch of the text, broken before a word, and
    # inside a word longer than the width, measuring each part with a block.
    #
    # @param text [String] The text.
    # @param width [Integer] The width in pixels.
    # @yieldparam part [String] A word, a run of spaces, or a character of a word longer than the width.
    # @yieldreturn [Integer] Its width in the font the lines are drawn in.
    # @return [Array<Array<Integer>>] Each line's first character and length, one empty line for an
    #   empty text.
    def self.wrap_spans(text, width)
      spans = []
      start = 0
      at = 0
      used = 0

      text.scan(/\S+|\s+/).each do |part|
        part_width = yield(part)

        if part =~ /\S/ && used + part_width > width && at > start
          spans.push([start, at - start])
          start = at
          used = 0
        end

        pieces = part =~ /\S/ && part_width > width ? part.each_char.to_a : [part]
        pieces.each do |piece|
          piece_width = pieces.size > 1 ? yield(piece) : part_width

          if pieces.size > 1 && used + piece_width > width && at > start
            spans.push([start, at - start])
            start = at
            used = 0
          end

          used += piece_width
          at += piece.length
        end
      end
      spans.push([start, text.length - start])
    end

    # Finds the line of wrap_spans a place in the text is on: the last one that starts at or before it.
    #
    # @param spans [Array<Array<Integer>>] The lines.
    # @param place [Integer] The characters before the place.
    # @return [Integer] The line.
    def self.span_of(spans, place)
      line = spans.rindex { |start, _length| start <= place }
      line || 0
    end

    module Engine
      # The one rule by which a typed text matches a word, anywhere and ignoring case, worked out in
      # C# (TextMatch): a text field's completions, an autocomplete's matches and a highlighted text
      # use it. Without the bridge nothing matches.
      module TextMatch
        # Narrows words to a typed text, TextTopics.MatchTopic in C#.
        MATCH_TOPIC = "text.match"

        # Finds a part in a text, TextTopics.FindTopic in C#.
        FIND_TOPIC = "text.find"

        # Narrows words to those that hold a typed text anywhere, ignoring case, leaving out the
        # typed text itself; nothing for an empty text.
        #
        # @param typed [String] The text typed.
        # @param words [Array<String>] The words, in order.
        # @return [Array<String>] The words that match, in order.
        def self.matches(typed, words)
          return [] if typed.to_s.empty? || !Mod_Framework.available?

          Array(Mod_Framework.bridge.call(MATCH_TOPIC, [typed.to_s, words.map { |word| word.to_s }]))
        end

        # Finds where a part occurs in a text, ignoring case.
        #
        # @param text [String] The text.
        # @param part [String] The part.
        # @return [Array<Array<Integer>>] Each place's start and length in characters.
        def self.places(text, part)
          return [] if part.to_s.empty? || text.to_s.empty? || !Mod_Framework.available?

          Array(Mod_Framework.bridge.call(FIND_TOPIC, [text.to_s, part.to_s]))
        end
      end

      # The widths of the characters of each font the framework draws in, by which C# cuts, breaks
      # and lays out texts (UiText in C#): RGSS measures a text in the game's font as the sum of its
      # characters' widths, so each character is measured once per font, here, where Bitmap#text_size is.
      #
      # A font measures printable ASCII as it is first used and checks that a few sample texts
      # measure as the sum of their characters; one that fails, such as an italic font or one with
      # kerning that a translation or another mod sets, is cut and broken here, as is every font while
      # the bridge is closed; a text box, a text with escape codes and a log are laid out in C# by it
      # all the same, a pixel or two off.
      module Glyphs
        # Defines a font in C#, or adds characters to one, UiText.GlyphsTopic.
        TOPIC = "ui.glyphs"

        # Cuts a text, UiText.CutTopic.
        CUT = "ui.text.cut"

        # Breaks a text at words, UiText.WrapTopic.
        WRAP = "ui.text.wrap"

        # Breaks a text keeping each character's place, UiText.SpansTopic.
        SPANS = "ui.text.spans"

        # Lays out a text with the game's escape codes, UiText.RunsTopic.
        RUNS = "ui.text.runs"

        # Lays out the rows of a log, UiText.LogTopic.
        LOG = "ui.text.log"

        # The event of characters a model met that its font never measured, UiText.WantedTopic.
        WANTED = "ui.glyphs.wanted"

        # The key of the font of cells, where every character is one cell wide, UiText.CellsKey.
        CELLS = 0

        # The encodings of a text C# lays out; any other is cut and broken here. Named, since the
        # Encoding constants are missing in the game.
        TEXT_ENCODINGS = [Encoding.find("UTF-8"), Encoding.find("US-ASCII")]

        # The characters a font measures as it is first used: printable ASCII.
        FIRST = (32..126)

        # Texts every font must measure as the sum of their characters' widths: pairs that kern in a
        # font that kerns, a sentence, names with numbers and a chat line.
        SAMPLES = ["AV To Wa Yo Te LT VA ff fi Pa", "The quick brown fox jumps over the lazy dog.", "Luka, Alice & Ilias: 1,234 / 99.5%", "[Map] <Name>: hello there!"]

        # The key of each font by its name, size, boldness and slant.
        @keys = {}

        # The keys of the fonts that failed the sum check, true by key.
        @inexact = {}

        # The widths C# has, by font key and code point.
        @widths = {}

        # Each font's name, size, boldness and slant by its key, for measuring what a model asks for.
        @fonts = {}

        # The last key handed out.
        @last = CELLS

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "text"

        # Asks C# to lay out a text in the font a measure draws in, handing over the widths of the
        # characters C# lacks.
        #
        # @param topic [String] CUT, WRAP, SPANS, RUNS or LOG.
        # @param measure [Bitmap, Window_Base, nil] What measures with the font, nil for the font of cells.
        # @param text [String] Every character the layout measures.
        # @param inexact [Boolean] Whether a font that failed the sum check is laid out in C# all the same.
        # @yieldparam key [Integer] The font's key.
        # @yieldreturn [Array] The request without the new widths.
        # @return [Object, nil] C#'s answer; nil while the bridge is closed, for a font measured here,
        #   for a text that is no UTF-8 and for an answer that failed, which the bridge logs.
        def self.ask(topic, measure, text, inexact = false)
          key = measure ? (inexact ? font_key(measure) : key_of(measure)) : cells_key
          return nil unless key && utf8?(text)

          Mod_Framework.bridge.call(topic, yield(key) + [new_widths(key, measure, text)])
        end

        # Finds the key of the font a measure draws in, defining the font in C# as it is first used.
        #
        # @param measure [Bitmap, Window_Base] What measures with the font.
        # @return [Integer, nil] The key; nil while the bridge is closed, for a measure without a font
        #   and for a font that failed the sum check.
        def self.key_of(measure)
          key = font_key(measure)
          key && !@inexact[key] ? key : nil
        end

        # Tells whether texts in the font a measure draws in are cut and broken in C#: the bridge is
        # open and the font passed the sum check. A text in any other font is measured whole here.
        #
        # @param measure [Bitmap, Window_Base] What measures with the font.
        # @return [Boolean] Whether they are.
        def self.exact?(measure)
          key_of(measure) ? true : false
        end

        # Finds the key of the font a measure draws in, as key_of does, also for a font that failed
        # the sum check, which C# lays a text box and a text with escape codes out in all the same.
        #
        # @param measure [Bitmap, Window_Base] What measures with the font.
        # @return [Integer, nil] The key; nil while the bridge is closed and for a measure without a font.
        def self.font_key(measure)
          return nil unless Mod_Framework.bridge.has?(TOPIC)

          font = font_of(measure)
          return nil unless font

          id = [text_of(Array(font.respond_to?(:name) ? font.name : nil).join(",")), font.size.to_i, font.bold ? true : false, font.italic ? true : false]
          @keys[id] ||= define(id, measure)
        end

        # Hands a font's name over as text, which C# takes, by its bytes where the game holds it as none.
        #
        # @param name [String] The name as the game holds it.
        # @return [String] The name as text.
        def self.text_of(name)
          return name if utf8?(name)

          text = name.dup.force_encoding("UTF-8")
          text.valid_encoding? ? text : name.each_byte.map { |byte| byte < 128 ? byte.chr : "?" }.join
        end

        # Hands out the key of the font of cells while the bridge is open.
        #
        # @return [Integer, nil] CELLS, nil while the bridge is closed.
        def self.cells_key
          Mod_Framework.bridge.has?(TOPIC) ? CELLS : nil
        end

        # Finds the font a measure draws in.
        #
        # @param measure [Bitmap, Window_Base] A picture, or a window, which draws on its contents.
        # @return [Font, nil] The font, nil for a measure without one.
        def self.font_of(measure)
          return measure.contents.font if measure.respond_to?(:contents) && measure.contents

          measure.respond_to?(:font) ? measure.font : nil
        end

        # Measures a font as it is first used, checks its sums and defines it in C#.
        #
        # @param id [Array] The font's name, size, boldness and slant.
        # @param measure [Bitmap, Window_Base] What measures with the font.
        # @return [Integer] The font's key.
        def self.define(id, measure)
          widths = {}
          FIRST.each { |code| widths[code] = measure.text_size(code.chr).width }
          key = @last += 1
          off = SAMPLES.find { |sample| measure.text_size(sample).width != sample.each_byte.inject(0) { |sum, code| sum + widths[code] } }
          if off
            @inexact[key] = true
            log("the font #{id.inspect} measures \"#{off}\" otherwise than its characters add up to, so its texts are measured here")
          end

          Mod_Framework.bridge.call(TOPIC, "key" => key, "name" => id[0], "size" => id[1], "bold" => id[2], "widths" => widths)
          @widths[key] = widths
          @fonts[key] = id
          key
        end

        # Measures the characters of a text whose widths C# lacks.
        #
        # @param key [Integer] The font's key.
        # @param measure [Bitmap, Window_Base, nil] What measures with the font, nil for the font of cells.
        # @param text [String] The text.
        # @return [Hash{Integer => Integer}, nil] The new widths by code point, nil for none.
        def self.new_widths(key, measure, text)
          known = @widths[key]
          return nil unless known

          found = nil
          text.each_char do |char|
            code = char.ord
            next if known.key?(code)

            found ||= {}
            known[code] = found[code] = measure.text_size(char).width
          end
          found
        end

        # Measures the characters a model asked for in the font it named, on a picture of that font,
        # and hands them to C# with the frame's batch.
        #
        # @param event [Hash] The font's "key" and the "points" asked for.
        def self.measure_wanted(event)
          key = event["key"]
          id = @fonts[key]
          return unless id

          widths = {}
          bitmap = scratch(id)
          Array(event["points"]).each { |code| widths[code] = @widths[key][code] = bitmap.text_size([code].pack("U")).width }
          Mod_Framework.bridge.stage(TOPIC, "key" => key, "widths" => widths)
        end

        # Hands out a small picture set to a font, for measuring.
        #
        # @param id [Array] The font's name, size, boldness and slant.
        # @return [Bitmap] The picture.
        def self.scratch(id)
          @scratch = Bitmap.new(1, 1) if @scratch.nil? || @scratch.disposed?
          font = @scratch.font
          font.name = id[0].split(",") unless id[0].empty?
          font.size = id[1]
          font.bold = id[2]
          font.italic = id[3]
          @scratch
        end

        # Tells whether a text crosses the bridge as text: valid UTF-8 or US-ASCII.
        #
        # @param text [String] The text.
        # @return [Boolean] Whether it does.
        def self.utf8?(text)
          TEXT_ENCODINGS.include?(text.encoding) && text.valid_encoding?
        end
      end

      # Texts with the game's escape codes, such as an item's description: converted by the game's
      # own convert_escape_characters, so every code the game and its plugins add applies, then laid
      # out in C# (Escapes in C#) into lines of colored text and icons.
      module Escapes
        # A code the conversion leaves, as the game's obtain_escape_code and obtain_escape_param read
        # it, or with a color name in its brackets, which takes no room of its own in the text.
        CODE = /\e(?:[\$\.\|\^!><\{\}\\]|[A-Z]+(?:\[(?:\d+|[A-Z_]\w*)\])?)?/i

        # The hidden window whose conversion the texts go through, made as it is first needed.
        @window = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "text"

        # Converts a text's escape codes as the game's windows do: names, variables and the game's
        # and its plugins' codes are filled in, and what draws (colors, icons) is left as \e codes.
        #
        # @param text [String] The text, such as "\\C[2]Fire\\C[0] resistance".
        # @return [String] The text converted; before the game's data loaded, only the backslashes
        #   turned into \e.
        def self.convert(text)
          window = converter
          return text.to_s.gsub("\\", "\e") unless window

          window.send(:convert_escape_characters, text.to_s)
        rescue => e
          log_once([:convert, e.class], "converting the escape codes of #{Logging.short(text.to_s.inspect)} failed, so they are taken as they are: #{Logging.failure(e)}")
          text.to_s.gsub("\\", "\e")
        end

        # Lays out a text with escape codes in the font a measure draws in.
        #
        # @param measure [Bitmap, Window_Base] What measures with the font.
        # @param text [String] The text, its codes not converted yet.
        # @param width [Integer, nil] The width the lines break at, nil to break only at line breaks.
        # @return [Array<Hash>, nil] Per line {"width", "runs"}, each run {"x", "text"} with "color"
        #   (a game text color, or a color name such as "primary") once a code changed it, or {"x", "icon"}; nil while the bridge is
        #   closed and for a text that is no UTF-8.
        def self.runs(measure, text, width = nil)
          converted = convert(text)
          Glyphs.ask(Glyphs::RUNS, measure, converted.gsub(CODE, ""), true) { |key| [key, width, converted] }
        end

        # Drops the hidden window, as F12 starts the game's scenes again.
        def self.reset
          @window.dispose if @window && !@window.disposed?
          @window = nil
        end

        # Hands out the hidden window, made once the game's data has loaded.
        #
        # @return [Window_Base, nil] The window, nil before the game's system data exists, which a
        #   game window reads as it is made.
        def self.converter
          return nil unless $game_system

          @window = nil if @window && @window.disposed?
          @window ||= begin
            window = ::Window_Base.new(0, 0, 32, 32)
            window.visible = false
            window.openness = 0
            window
          end
        end
      end

      # A text being typed into a box: what C# keeps of it (the text, the cursor, the blinking and the
      # part the box shows), mirrored from the box's events. One box is typed into at a time; opening
      # one closes the one before. While a box is open the DLL takes what the player types and
      # UI.typing? tells so, which every mod's hotkeys read to stay quiet. Its owner hands the
      # frame's keys over with follow, acts on what typing did with take a frame later, and draws it
      # through TextBox.
      class TextEdit
        # Opens a box in C#, EditModel.OpenTopic.
        OPEN = "ui.edit.open"

        # Closes a box, EditModel.CloseTopic.
        CLOSE = "ui.edit.close"

        # Changes a box, EditModel.SetTopic.
        SET = "ui.edit.set"

        # Tells a box where it is drawn, EditModel.ViewTopic.
        VIEW = "ui.edit.view"

        # Types into a box at once, EditModel.TypeTopic.
        TYPE = "ui.edit.type"

        # The box's event, EditModel.EventTopic.
        EVENT = "ui.edit"

        # The box's name in the frame's tick.
        MODEL = "edit".freeze

        # Windows' code of the Home key, which moves the cursor to the start.
        HOME_KEY = 0x24

        # Windows' code of the End key, which moves the cursor to the end.
        END_KEY = 0x23

        # Windows' code of the Delete key, which removes the character after the cursor.
        DELETE_KEY = 0x2E

        # Windows' code of the left Alt, while which a box that drops Alt codes drops what is typed;
        # the right Alt is AltGr, which types.
        ALT_KEY = 0xA4

        # The bits of the keys that type nothing, EditKeys in C#: left and right as the game's buttons
        # that repeat while held, then Home, End and Delete from Windows.
        ARROW_BITS = { :LEFT => 1, :RIGHT => 2 }

        # The bits of up and down, which only a box of several lines reads, so a box of one line
        # leaves them to its owner, such as a list of names under it.
        LINE_BITS = { :UP => 4, :DOWN => 8 }

        # The bits of every arrow, which a box of several lines reads.
        AREA_BITS = ARROW_BITS.merge(LINE_BITS)

        # The bits of Home, End and Delete, by Windows' codes.
        KEY_BITS = { HOME_KEY => 16, END_KEY => 32, DELETE_KEY => 64 }

        # The characters an :allowed pattern is tried on in Ruby and in C#, printable ASCII and a few
        # Latin letters, so a pattern the two read apart fails the open instead of refusing every key.
        ALLOWED_CHECK = ((32..126).to_a + [0xE4, 0xF6, 0xFC, 0xDF, 0xE9, 0xE8, 0xEA, 0xF1]).pack("U*")

        # What typing did, as a box's event names it.
        OUTCOMES = { "enter" => :enter, "escape" => :escape, "tab" => :tab, "typed" => :typed, "erased" => :erased, "refused" => :refused }

        # What take hands out: what typing did since the last take, in order (:enter, :escape, :tab,
        # :typed, :erased, :refused), how many keys went down and characters came, and whether the box
        # changed.
        Taken = Struct.new(:outcomes, :keys, :chars, :changed)

        # The box open now, which takes the events.
        @open = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "text"

        # The text.
        attr_reader :text

        # The characters before the cursor.
        attr_reader :cursor

        # The box's id in C#, nil while the bridge is closed.
        attr_reader :id

        # The number the text gives within its bounds in a box that types one, nil for a text that
        # gives none and in any other box.
        attr_reader :number

        # Opens a box in C#, the cursor at the text's end, and has the DLL take what is typed.
        #
        # @param text [String] The text.
        # @param options [Hash] Whichever of :max_chars (the most characters it takes), :allowed (a
        #   pattern of one character every typed character must match, in the syntax Ruby and .NET's
        #   ECMAScript mode read alike, such as \d, \w and [a-z], but no POSIX brackets, \h or /x;
        #   one they read apart fails the open and is logged), :mask (the character shown
        #   for each, such as "*"), :echo ([Windows' code of the key that opened it, frames], whose
        #   character it leaves out once), :alt_codes (frames after the left Alt in which typing is
        #   dropped) and :number ([least, largest], each nil for none: the text stays a whole number,
        #   characters that came together going in whole or not at all) apply.
        def initialize(text = "", options = {})
          @text = text.to_s
          @cursor = @text.length
          @shown = true
          @view = nil
          @drawn = nil
          @taken = Taken.new([], 0, 0, false)
          @alt_codes = !options[:alt_codes].nil?
          request = { "text" => @text }
          request["max_chars"] = options[:max_chars] if options[:max_chars]
          allow(request, options[:allowed]) if options[:allowed]
          { :mask => "mask", :echo => "echo", :alt_codes => "alt_codes", :number => "number" }.each { |option, key| request[key] = options[option] if options[option] }
          @id = Mod_Framework.bridge.call(OPEN, request)
          return unless @id

          Key.watch(HOME_KEY, END_KEY, DELETE_KEY, ALT_KEY)
          TextEdit.open = self
          # What is typed from now on reaches the box in this frame already.
          follow(false)
        end

        # Hands a box the events from now on.
        #
        # @param editor [TextEdit] The box opened.
        def self.open=(editor)
          log("typing on") unless @open
          @open = editor
        end

        # Stops handing a box the events once it closed, unless another opened since.
        #
        # @param editor [TextEdit] The box closed.
        def self.release(editor)
          return unless @open.equal?(editor)

          @open = nil
          log("typing off")
        end

        # Tells the box open now.
        #
        # @return [TextEdit, nil] The box, nil while none is open.
        def self.current
          @open
        end

        # Hands a box's event to the box open, unless it is of a box closed since.
        #
        # @param event [Hash] The event, see EditModel.EventTopic.
        def self.take_event(event)
          editor = @open
          editor.take_event(event) if editor && editor.id == event["id"]
        end

        # Closes the box open, as F12 starts the game's scenes again.
        def self.reset
          editor = @open
          return unless editor

          log("F12 closed the box being typed into")
          editor.close
        end

        # Closes the box in C#, dropping what was typed and not taken; the DLL stops taking what is
        # typed.
        def close
          Mod_Framework.bridge.call(CLOSE, @id) if @id
          TextEdit.release(self)
        end

        # Reports whether the blinking cursor shows.
        #
        # @return [Boolean] Whether it does.
        def cursor_shown?
          @shown
        end

        # Hands C# the box's input of this frame, where its owner reads the keys: what was typed
        # (taken straight from the keyboard), and the keys that type nothing unless the owner keeps
        # them, such as while Alt picks tabs.
        #
        # @param keys [Boolean] Whether the arrows, Home, End and Delete reach the box.
        # @param scroll [Integer] Lines to scroll a box of several lines, such as by the mouse wheel.
        def follow(keys = true, scroll = 0)
          return unless @id

          held = @alt_codes && Key.down?(ALT_KEY) ? 1 : 0
          Tick.put(MODEL, [@id, keys ? key_bits : -1, 1, scroll.to_i, held])
        end

        # Takes what typing did since the last take.
        #
        # @return [Taken] What typing did, the keys and characters that came, and whether the box changed.
        def take
          taken = @taken
          @taken = Taken.new([], 0, 0, false)
          taken
        end

        # Replaces the text and puts the cursor at once, as the owner sees it, and in C# with the
        # frame's batch, before what is typed next.
        #
        # @param text [String] The new text.
        # @param cursor [Integer] The cursor's new place.
        def edit(text, cursor)
          @text = text.to_s
          @cursor = [[cursor, 0].max, @text.length].min
          @shown = true
          Mod_Framework.bridge.stage(SET, "id" => @id, "text" => @text, "cursor" => @cursor) if @id
        end

        # Locks the box, which then takes no typing but Escape, or unlocks it.
        #
        # @param locked [Boolean] Whether it is locked.
        def lock(locked)
          Mod_Framework.bridge.stage(SET, "id" => @id, "locked" => locked) if @id
        end

        # Leaves out the character of a key once more, which arrives a frame or two after the key.
        #
        # @param key [Integer] Windows' code of the key.
        # @param frames [Integer] The frames its character may come in.
        def echo(key, frames)
          Mod_Framework.bridge.stage(SET, "id" => @id, "echo" => [key, frames]) if @id
        end

        # Types characters at once, for the game's letters a gamepad picks.
        #
        # @param chars [String] The characters, "\b" for Backspace.
        # @return [Array<Symbol>] What typing did, see Taken; none while the bridge is closed.
        def type_now(chars)
          answer = @id ? Mod_Framework.bridge.call(TYPE, "id" => @id, "text" => chars.to_s) : nil
          return [] unless answer

          @text = answer["text"]
          @cursor = answer["cursor"]
          answer["outcomes"].map { |outcome| OUTCOMES[outcome] }.compact
        end

        # Tells what the box shows where it is drawn, telling C# first when that changed.
        #
        # @param bitmap [Bitmap] The picture drawn on, in the font the box draws in.
        # @param width [Integer] The width its text may take.
        # @param rows [Integer] The lines a box of several lines shows, 0 for a box of one line.
        # @return [Hash, nil] {"line" => [first, count, cursor x]} or {"area" => [spans, first line,
        #   cursor's line, cursor x]}; nil while the bridge is closed or for a measure without a font.
        def view_for(bitmap, width, rows)
          font = Glyphs.font_key(bitmap)
          drawn = [font, width, rows]
          return @view if drawn == @drawn
          return nil unless @id && font

          state = Mod_Framework.bridge.call(VIEW, "id" => @id, "font" => font, "width" => width, "rows" => rows)
          return nil unless state

          apply(state)
          @drawn = drawn
          @view
        end

        # Takes the box's event: the text, the cursor and what the box shows, and what typing did.
        #
        # @param event [Hash] The event, see EditModel.EventTopic.
        def take_event(event)
          apply(event)
          taken = @taken
          Array(event["outcomes"]).each { |outcome| taken.outcomes << OUTCOMES[outcome] if OUTCOMES[outcome] }
          taken.keys += event["keys"].to_i
          taken.chars += event["chars"].to_i
          taken.changed = true
        end

        # Reads the frame's keys that type nothing.
        #
        # @return [Integer] The bits, see ARROW_BITS, AREA_BITS and KEY_BITS.
        def key_bits
          bits = 0
          arrows = @drawn && @drawn[2] > 0 ? AREA_BITS : ARROW_BITS
          arrows.each { |button, bit| bits |= bit if Capture.repeat?(button) }
          KEY_BITS.each { |code, bit| bits |= bit if Key.pressed?(code) }
          bits
        end

        private

        # Takes the box's state from C#.
        #
        # @param state [Hash] "text", "cursor", "shown" and "view", and "number" in a box that types one.
        def apply(state)
          @text = state["text"]
          @number = state["number"]
          @cursor = state["cursor"]
          @shown = state["shown"]
          @view = state["view"] if state["view"]
        end

        # Puts an :allowed pattern into the open request, with which of ALLOWED_CHECK it matches in
        # Ruby, so C# can prove it reads the pattern alike.
        #
        # @param request [Hash] The open request.
        # @param pattern [Regexp] The pattern of one character.
        def allow(request, pattern)
          request["allowed"] = [pattern.source, pattern.casefold?]
          request["allowed_check"] = [ALLOWED_CHECK, ALLOWED_CHECK.each_char.map { |char| !(pattern =~ char).nil? }]
        end
      end

      # Draws a text box being typed into: the part of the text C# picked around the cursor, and the
      # cursor, in the font and the color the picture is set to. Whoever owns the box draws its
      # background, and what it shows while nobody types into it.
      module TextBox
        # Width of the cursor.
        CURSOR_WIDTH = 2

        # Room the cursor keeps above and below it in a box of one line.
        CURSOR_INSET = 3

        # Room the cursor keeps above and below it on a line of a box of several lines.
        LINE_CURSOR_INSET = 2

        # Draws a box of one line.
        #
        # @param bitmap [Bitmap] The picture drawn on, such as a sprite's or a window's contents.
        # @param rect [Rect] Where the text goes.
        # @param editor [TextEdit] The box's editor.
        # @param display [String] What the box shows for the text, as long as it, such as stars for a
        #   password.
        def self.draw_line(bitmap, rect, editor, display = editor.text)
          view = editor.view_for(bitmap, rect.width - CURSOR_WIDTH, 0)
          line = view && view["line"]
          return bitmap.draw_text(rect.x, rect.y, rect.width, rect.height, display) unless line

          first, count, x = line
          bitmap.draw_text(rect.x, rect.y, rect.width, rect.height, display[first, count].to_s)
          draw_cursor(bitmap, rect.x + x, rect.y + CURSOR_INSET, rect.height - CURSOR_INSET * 2) if editor.cursor_shown?
        end

        # Draws a box of several lines, and a scrollbar right of the text while it has more lines than
        # the box shows; whoever owns the box leaves Style::SCROLLBAR_WIDTH free there.
        #
        # The scrollbar is Style's, so a box drawn while Style is missing draws none.
        #
        # @param bitmap [Bitmap] The picture drawn on.
        # @param rect [Rect] Where the text goes.
        # @param editor [TextEdit] The box's editor.
        # @param line_height [Integer] The height of one line.
        def self.draw_area(bitmap, rect, editor, line_height)
          rows = rect.height / line_height
          view = editor.view_for(bitmap, rect.width, rows)
          area = view && view["area"]
          return bitmap.draw_text(rect.x, rect.y, rect.width, line_height, editor.text) unless area

          spans, top, cursor_line, x = area
          spans[top, rows].each_with_index do |(start, length), row|
            y = rect.y + row * line_height
            bitmap.draw_text(rect.x, y, rect.width, line_height, editor.text[start, length].to_s)
            draw_cursor(bitmap, rect.x + x, y + LINE_CURSOR_INSET, line_height - LINE_CURSOR_INSET * 2) if top + row == cursor_line && editor.cursor_shown?
          end
          Style.draw_scrollbar(bitmap, rect.x + rect.width, rect.y, rows * line_height, top, rows, spans.size) if defined?(Style)
        end

        # Draws the cursor, in the color of the text.
        #
        # @param bitmap [Bitmap] The picture drawn on.
        # @param x [Integer] The left edge.
        # @param y [Integer] The top edge.
        # @param height [Integer] The height.
        def self.draw_cursor(bitmap, x, y, height)
          bitmap.fill_rect(x, y, CURSOR_WIDTH, height, bitmap.font.color)
        end
      end
    end

    # F12 closes the box being typed into and drops the hidden window of the conversion.
    Run.on_reset("text") do
      Mod_Framework::UI::Engine::TextEdit.reset
      Mod_Framework::UI::Engine::Escapes.reset
    end

    Mod_Framework.bridge.on(Engine::TextEdit::EVENT) { |event| Mod_Framework::UI::Engine::TextEdit.take_event(event) }
    Mod_Framework.bridge.on(Engine::Glyphs::WANTED) { |event| Mod_Framework::UI::Engine::Glyphs.measure_wanted(event) }
  end

  # The text of the clipboard: on Windows the DLL opens it with the game's window, on JoiPlay the
  # engine's Input reads Android's.
  module Clipboard
    # Reads the clipboard, ClipboardTopics.GetTopic in C#.
    GET = "clipboard.get"

    # Writes the clipboard, ClipboardTopics.SetTopic in C#.
    SET = "clipboard.set"

    # Reads the clipboard's text.
    #
    # @return [String] The text, empty while it holds none and without the DLL.
    def self.text
      return ::Input.clipboard.to_s.dup.force_encoding("UTF-8") if Mod_Framework.platform == JOIPLAY
      return "" unless Mod_Framework.available?

      Mod_Framework.bridge.call(GET).to_s.force_encoding("UTF-8")
    end

    # Puts a text on the clipboard.
    #
    # @param text [String] The text; nothing happens without the DLL.
    def self.text=(text)
      return ::Input.clipboard = text.to_s if Mod_Framework.platform == JOIPLAY

      Mod_Framework.bridge.call(SET, text.to_s) if Mod_Framework.available?
    end
  end
end
