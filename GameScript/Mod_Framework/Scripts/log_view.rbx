#----------------------------------------------------------------
#  log_view.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Laid out all its rows in one call to C# by the rule of a text box, one layout kept per width
#                            - Removed add, the oldest rows dropping past most_rows and the word wrap of its own
#      Paulinchen  2026-11-07: Removed add_log of the old API
#      Paulinchen  2026-11-06: Wrapped a word whose outline would not fit the line instead of drawing it narrower
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Drew a part in a color given as "#RRGGBB" or [r, g, b]
#                            - Lit a part with data under the pointer by the pointer coming on, also in a window of the UI layer
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Rows of colored parts that wrap at their words, the newest at the bottom, whole lines standing
      # on the bottom edge, for chats, combat logs and feeds. A row is a String,
      # an Array of parts ({:text, :color, :data}, or Strings), or {:parts, :opacity}. It sticks to the
      # newest row while the player has not scrolled up; with :keep_place the view holds still while
      # new rows come in scrolled up. The wheel scrolls it :wheel_rows lines a notch, its scrollbar
      # shows while lines are hidden, a part with :data draws lighter under the pointer and a click
      # on it tells click. A text field's steer(log) scrolls it by Up, Down, Page Up and Page Down.
      # rows= sets its rows anew, which C# lays out in lines by the rule of a text box.
      #
      # Events: click (row, part).
      class LogView < Component
        # Its width before its parent stretches it.
        MIN_WIDTH = 96

        # Room between its lines and its scrollbar.
        BAR_GAP = 2

        # How much lighter a part with :data draws under the pointer.
        LIGHTER = 0.4

        # Tells the defaults of the options: no rows, filling its room, holding still scrolled up.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:rows => [], :rows_shown => :fill, :keep_place => true, :wheel_rows => 3, :scrollbar => true, :font_size => :small, :color => nil)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:rows_shown => ["measured"], :font_size => ["measured"])
        end

        options :rows_shown, :keep_place, :wheel_rows, :scrollbar, :font_size, :color

        # Makes a log, scrolled to its newest row.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @offset = 0
          @layouts = {}
          @options[:rows] = Array(@options[:rows]).dup
        end

        # Tells its rows.
        #
        # @return [Array] The rows.
        def rows
          @options[:rows]
        end

        # Sets all its rows anew; scrolled up with :keep_place, the view holds still while new rows
        # come in.
        #
        # @param value [Array] The rows.
        def rows=(value)
          before = drawn_lines && drawn_lines.size
          @options[:rows] = Array(value).dup
          @layouts = {}
          @grow_from = before if @offset > 0 && @options[:keep_place]
          redraw
        end

        # Scrolls to its newest row.
        #
        # @return [LogView] Itself.
        def scroll_to_end
          @offset = 0
          redraw
          self
        end

        # Scrolls it by lines, up toward the older rows for a positive count.
        #
        # @param lines [Integer] The lines.
        # @return [LogView] Itself.
        def scroll_by(lines)
          @offset = [@offset + lines.to_i, 0].max
          @offset = [@offset, hidden_lines].min if drawn_lines
          redraw
          self
        end

        # Scrolls it a page up (-1) or down (1).
        #
        # @param step [Integer] -1 or 1.
        # @return [LogView] Itself.
        def scroll_page(step)
          scroll_by(-step.to_i * [shown_lines, 1].max)
        end

        # Tells the properties C#'s tree routes the pointer by: it takes the wheel itself.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["wheel_told"] = true
          props
        end

        # Tells its size: a line, as it takes its room; else :rows_shown lines.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          count = @options[:rows_shown] == :fill ? 1 : [@options[:rows_shown].to_i, 1].max
          [MIN_WIDTH, count * line_height]
        end

        # Takes an event of C#'s tree: the wheel scrolls it, a click on a part with :data tells
        # click, the pointer coming on follows the part under it until it leaves. A window of the UI
        # layer marks no part hovered, so the pointer is followed by these events alone.
        #
        # @param name [String] The event.
        # @param values [Array] Its value.
        def receive(name, *values)
          case name
          when "wheel"
            scroll_by(values[0].to_i * [@options[:wheel_rows].to_i, 1].max)
          when "click"
            found = part_at(Mouse.position)
            emit(:click, found[0], found[1]) if found && found[1].is_a?(Hash) && !found[1][:data].nil?
          when "hover"
            @pointer_on = values[0] ? true : false
            Tree.ticking(self, true) if @pointer_on
            super
          else
            super
          end
        end

        # Follows the part under the pointer while it is on the log, drawing anew once it changed.
        #
        # @return [Boolean] Whether it still follows it.
        def frame_tick
          found = @pointer_on ? part_at(Mouse.position) : nil
          part = found && found[1].is_a?(Hash) && !found[1][:data].nil? ? found[1] : nil
          redraw unless part.equal?(@hover_part)
          @hover_part = part
          @pointer_on ? true : false
        end

        # Draws the lines in sight from its bottom edge, the parts in their colors, and its scrollbar.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, bottom, left = padding_sides
          shown = shown_lines(canvas.height - top - bottom)
          width = canvas.width - left - right - (bar?(shown, canvas.width - left - right) ? Style::SCROLLBAR_WIDTH + BAR_GAP : 0)
          lines = lines_for(width)
          @drawn_width = width
          settle_offset(lines.size, shown)
          first = [lines.size - shown - @offset, 0].max
          visible = lines[first, shown] || []
          y = canvas.height - bottom - visible.size * line_height
          size = UI.font_px(@options[:font_size])
          @drawn = []
          visible.each do |line|
            line[:segments].each do |x, text, color, part, wide|
              look = part.equal?(@hover_part) ? lighter(canvas.color(color)) : color
              canvas.text(left + x, y, width - x, line_height, text, :size => size, :color => look, :opacity => line[:opacity])
              @drawn << [left + x, y, wide, line[:row], part]
            end
            y += line_height
          end
          canvas.scrollbar(canvas.width - right - Style::SCROLLBAR_WIDTH, top, canvas.height - top - bottom, first, shown, lines.size) if bar?(shown, width) && lines.size > shown
        end

        private

        # Tells the height of a line in its font.
        #
        # @return [Integer] The pixels.
        def line_height
          UI.line_height_of(@options[:font_size])
        end

        # Tells how many whole lines its room shows.
        #
        # @param room [Integer, nil] The height its lines may take, its own place's without one.
        # @return [Integer] The lines.
        def shown_lines(room = nil)
          room ||= @rect ? @rect.height - padding_sides[0] - padding_sides[2] : line_height
          [room / [line_height, 1].max, 1].max
        end

        # Tells how many lines lie above those in sight at its newest place.
        #
        # @return [Integer] The lines.
        def hidden_lines
          [Array(drawn_lines).size - shown_lines, 0].max
        end

        # Tells whether it draws its scrollbar: with :scrollbar while lines are hidden.
        #
        # @param shown [Integer] The lines in sight.
        # @param width [Integer] Its lines' width.
        # @return [Boolean] Whether it does.
        def bar?(shown, width)
          @options[:scrollbar] && lines_for(width).size > shown ? true : false
        end

        # Keeps its scrolling within its lines, and holds the view still while new rows came in
        # scrolled up.
        #
        # @param count [Integer] Its lines.
        # @param shown [Integer] The lines in sight.
        def settle_offset(count, shown)
          if @grow_from
            @offset += [count - @grow_from, 0].max
            @grow_from = nil
          end
          @offset = UI.within(@offset, 0, [count - shown, 0].max)
        end

        # Tells the lines it drew last, nil before it drew.
        #
        # @return [Array<Hash>, nil] The lines, see lines_for.
        def drawn_lines
          @drawn_width && @layouts[@drawn_width]
        end

        # Lays its rows out in lines of a width, each width once until its rows change, so the
        # scrollbar's check at the whole width and the lines beside the scrollbar both stay.
        #
        # @param width [Integer] The width.
        # @return [Array<Hash>] Each line's :row, :opacity and :segments ([x, text, color, part, width]).
        def lines_for(width)
          @layouts[width] ||= laid_out(width)
        end

        # Lays its rows out in lines of a width in C#, a new line where a word does not fit with the
        # room its outline takes; when C# cannot, each row is one line without wrapping.
        #
        # @param width [Integer] The width.
        # @return [Array<Hash>] The lines, see lines_for.
        def laid_out(width)
          rows = Array(@options[:rows])
          parts = rows.map { |row| parts_of(row) }
          texts = parts.map { |each| each.map { |part| text_of(part) } }
          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          laid = Glyphs.ask(Glyphs::LOG, bitmap, texts.flatten.join, true) { |key| [key, [width - Canvas::OUTLINE_ROOM, 1].max, texts] }
          laid = unwrapped(bitmap, texts) unless laid.is_a?(Array) && laid.size == rows.size
          lines = []
          rows.each_with_index do |row, place|
            opacity = row.is_a?(Hash) ? row[:opacity] : nil
            laid[place].each do |pieces|
              segments = pieces.map do |x, at, text, wide|
                part = parts[place][at]
                [x, text, drawn_color((part.is_a?(Hash) ? part[:color] : nil) || @options[:color]), part, wide]
              end
              lines << { :row => row, :opacity => opacity, :segments => segments }
            end
          end
          lines
        end

        # Lays rows out as one line each, their parts side by side, for when C# cannot lay them out,
        # which it logs once while the DLL runs.
        #
        # @param bitmap [Bitmap] What measures in its font.
        # @param texts [Array<Array<String>>] Each row's parts' texts.
        # @return [Array] Per row its one line of [x, part, text, width].
        def unwrapped(bitmap, texts)
          Tree.log_once([:log_unwrapped], "a log showed its rows without wrapping them, since the DLL did not lay them out") if Mod_Framework.available?
          texts.map do |row|
            x = 0
            [row.each_with_index.map do |text, at|
              wide = UI.text_width(bitmap, text)
              x += wide
              [x - wide, at, text, wide]
            end]
          end
        end

        # Tells a row's parts.
        #
        # @param row [String, Array, Hash] The row.
        # @return [Array] Its parts as given.
        def parts_of(row)
          row.is_a?(Hash) ? Array(row[:parts]) : (row.is_a?(Array) ? row : [row.to_s])
        end

        # Tells a part's text.
        #
        # @param part [Hash, String] The part.
        # @return [String] Its text.
        def text_of(part)
          (part.is_a?(Hash) ? part[:text] : part).to_s
        end

        # Tells the color a part draws in: a color name stays a name, which the canvas finds in the
        # theme, and "#RRGGBB" or [r, g, b(, a)] becomes a Color.
        #
        # @param value [Symbol, String, Array, Color, nil] The part's color.
        # @return [Symbol, Color, nil] The color, nil for the plain text color.
        def drawn_color(value)
          case value
          when Array then Color.new(*value)
          when /\A#(\h\h)(\h\h)(\h\h)\z/ then Color.new($1.to_i(16), $2.to_i(16), $3.to_i(16))
          else value
          end
        end

        # Finds the part under a spot on the screen.
        #
        # @param spot [Array<Integer>, nil] The pointer's place.
        # @return [Array, nil] The row and the part, nil for none.
        def part_at(spot)
          return nil unless spot && @rect && @drawn

          x = spot[0] - @rect.x
          y = spot[1] - @rect.y
          found = @drawn.find { |left, top, width, _row, _part| x >= left && x < left + width && y >= top && y < top + line_height }
          found && [found[3], found[4]]
        end

        # Tells a lighter shade of a color, for a part under the pointer.
        #
        # @param color [Color] The color.
        # @return [Color] The shade.
        def lighter(color)
          Color.new(color.red + (255 - color.red) * LIGHTER, color.green + (255 - color.green) * LIGHTER, color.blue + (255 - color.blue) * LIGHTER, color.alpha)
        end
      end
    end
  end
end
