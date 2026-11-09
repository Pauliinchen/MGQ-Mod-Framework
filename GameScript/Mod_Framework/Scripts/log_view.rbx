#----------------------------------------------------------------
#  log_view.rbx
#
#  Changelog:
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
      # add(row) (or <<) puts one row at the bottom, wrapping only that row; past :most_rows the oldest
      # rows go. rows= sets them all anew.
      #
      # Events: click (row, part).
      class LogView < Component
        # Its width before its parent stretches it.
        MIN_WIDTH = 96

        # Room between its lines and its scrollbar.
        BAR_GAP = 2

        # How much lighter a part with :data draws under the pointer.
        LIGHTER = 0.4

        # The rows a log keeps unless it says otherwise.
        MOST_ROWS = 200

        # Tells the defaults of the options: no rows, filling its room, holding still scrolled up,
        # keeping the newest MOST_ROWS rows.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:rows => [], :rows_shown => :fill, :keep_place => true, :wheel_rows => 3, :scrollbar => true, :font_size => :small, :color => nil,
                      :most_rows => MOST_ROWS)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:rows_shown => ["measured"], :font_size => ["measured"])
        end

        options :rows_shown, :keep_place, :wheel_rows, :scrollbar, :font_size, :color, :most_rows

        # Makes a log, scrolled to its newest row.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @offset = 0
          @lines = nil
          @counts = []
          @options[:rows] = Array(@options[:rows]).dup
          drop_oldest
        end

        # Tells its rows.
        #
        # @return [Array] The rows.
        def rows
          @options[:rows]
        end

        # Sets all its rows anew, the newest :most_rows kept; scrolled up with :keep_place, the view
        # holds still while new rows come in.
        #
        # @param value [Array] The rows.
        def rows=(value)
          before = @lines ? @lines[1].size : nil
          @options[:rows] = Array(value).dup
          @lines = nil
          drop_oldest
          @grow_from = before if @offset > 0 && @options[:keep_place]
          redraw
        end

        # Puts one row at the bottom, wrapping only that row, and lets the oldest rows past
        # :most_rows go; scrolled up with :keep_place, the view holds still.
        #
        # @param row [String, Array, Hash] The row, as rows= takes them.
        # @return [LogView] Itself.
        def add(row)
          @options[:rows] << row
          if @lines
            added = row_lines(UI.font_bitmap(UI.font_px(@options[:font_size])), row, [@lines[0], 1].max)
            @lines[1].concat(added)
            @counts << added.size
            @offset += added.size if @offset > 0 && @options[:keep_place]
          end
          drop_oldest
          redraw
          self
        end
        alias_method :<<, :add

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
          @offset = [@offset, hidden_lines].min if @lines
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
          settle_offset(lines.size, shown)
          first = [lines.size - shown - @offset, 0].max
          visible = lines[first, shown] || []
          y = canvas.height - bottom - visible.size * line_height
          size = UI.font_px(@options[:font_size])
          @drawn = []
          visible.each do |line|
            line[:segments].each do |x, text, color, part|
              look = part.equal?(@hover_part) ? lighter(canvas.color(color)) : color
              canvas.text(left + x, y, width - x, line_height, text, :size => size, :color => look, :opacity => line[:opacity])
              @drawn << [left + x, y, canvas.text_width(text, size), line[:row], part]
            end
            y += line_height
          end
          canvas.scrollbar(canvas.width - right - Style::SCROLLBAR_WIDTH, top, canvas.height - top - bottom, first, shown, lines.size) if bar?(shown, width) && lines.size > shown
        end

        private

        # Follows a changed option: fewer :most_rows lets the oldest rows go at once.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          drop_oldest if name == :most_rows
        end

        # Lets the oldest rows past :most_rows go, with their lines.
        def drop_oldest
          most = @options[:most_rows]
          rows = @options[:rows]
          return unless most && rows.size > most.to_i

          gone = rows.size - [most.to_i, 0].max
          rows.shift(gone)
          @lines[1].shift(@counts.shift(gone).inject(0) { |sum, count| sum + count }) if @lines
        end

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
          [Array(@lines && @lines[1]).size - shown_lines, 0].max
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

        # Lays its rows out in lines of a width, once per width and rows.
        #
        # @param width [Integer] The width.
        # @return [Array<Hash>] Each line's :row, :opacity and :segments ([x, text, color, part]).
        def lines_for(width)
          return @lines[1] if @lines && @lines[0] == width

          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          lines = []
          @counts = []
          Array(@options[:rows]).each do |row|
            laid = row_lines(bitmap, row, [width, 1].max)
            @counts << laid.size
            lines.concat(laid)
          end
          @lines = [width, lines]
          lines
        end

        # Lays one row out in lines: its parts' words side by side, a new line where the next word
        # does not fit with the room its outline takes, a word longer than the width broken inside.
        #
        # @param bitmap [Bitmap] What measures in its font.
        # @param row [String, Array, Hash] The row.
        # @param width [Integer] The width.
        # @return [Array<Hash>] The row's lines.
        def row_lines(bitmap, row, width)
          opacity = row.is_a?(Hash) ? row[:opacity] : nil
          parts = row.is_a?(Hash) ? Array(row[:parts]) : (row.is_a?(Array) ? row : [row.to_s])
          lines = [{ :row => row, :opacity => opacity, :segments => [] }]
          x = 0
          parts.each do |part|
            entry = part.is_a?(Hash) ? part : { :text => part.to_s }
            color = drawn_color(entry[:color] || @options[:color])
            entry[:text].to_s.scan(/\S+\s*|\s+/).each do |word|
              pieces(bitmap, word, width).each do |piece|
                if x > 0 && x + UI.text_width(bitmap, piece.rstrip) + Canvas::OUTLINE_ROOM > width
                  lines << { :row => row, :opacity => opacity, :segments => [] }
                  x = 0
                end
                lines.last[:segments] << [x, piece, color, part]
                x += UI.text_width(bitmap, piece)
              end
            end
          end
          lines
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

        # Breaks a word longer than a width into pieces that fit it with the room their outline
        # takes, character by character.
        #
        # @param bitmap [Bitmap] What measures in its font.
        # @param word [String] The word.
        # @param width [Integer] The width.
        # @return [Array<String>] The pieces, the word alone when it fits.
        def pieces(bitmap, word, width)
          return [word] if UI.text_width(bitmap, word.rstrip) + Canvas::OUTLINE_ROOM <= width

          word.each_char.inject([""]) do |all, char|
            all << "" if !all.last.empty? && UI.text_width(bitmap, all.last + char) + Canvas::OUTLINE_ROOM > width
            all.last << char
            all
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
