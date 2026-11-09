#----------------------------------------------------------------
#  components_text.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Drew a label's line whole with :whole, which the game's draw_text squeezes into its width
#                            - Put a part right after a header's title and its marks
#                            - Measured a field's caption by the helper the list's columns share
#                            - Let a label's padding set the room of its plate and an alert's the room inside its plate
#      Paulinchen  2026-11-07: Took the outline of a label from the option every component has
#                            - Drew the places of a label's text that hold its :highlight on the picked color
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A text, cut with "..." to its width or wrapped onto lines, in a color and a size, with an
      # icon before it; with :escapes it converts the game's escape codes as the game's windows do and
      # draws their colors and icons, \C[0] going back to its own color. Its :align places it across
      # its parent's stack and its text in its width alike. With :item it shows an item as the game's
      # menus do: its icon (none with :icon => false) and its name in the game's color for it
      # (UI::Game.item_color, a favorite's with :bag). With :squeeze a text too wide is drawn narrower
      # before it is cut, and once it is cut its tooltip holds it whole unless the label has a tooltip
      # of its own. With :whole a line too wide is drawn whole into its width, which the game's
      # Bitmap#draw_text squeezes as the game's own windows draw it, without "...". With :hide_cut a text that does not fit, squeezed with :squeeze, draws nothing
      # instead of a cut one, such as a count whose number would be cut off, and its whole text is its
      # tooltip unless it has one of its own. :row_height sets the height of its lines, never below an
      # icon it draws; :faint draws it at half its opacity, as a part that does not count yet.
      #
      # A wrapped label keeps at most :most_lines lines, the last kept one ending with "..."; with
      # :most_lines => :fill as many as its room holds, then wrapped anew after a resize; once cut, its
      # whole text is its tooltip. :plate => true draws it on the darker plate a text field has, as
      # wide as its place; :plate => :text on the theme's dark plate as wide as its text, placed by
      # :align, so it reads over a busy map. :min_font_size lowers its font step by step down to that size until its text fits
      # before it cuts it, the labels with it in one row sharing the smallest size any of them needs.
      # :body marks plain body text, which in the game's own look (theme :game) draws in the game's
      # own font size instead of its :font_size. On a line that neither wraps nor reads escape codes,
      # :shorter (ever shorter texts) stands in for a text that does not fit: the first of them that
      # fits shows, else the last, and the whole text becomes its tooltip. :highlight draws the places
      # of its text that hold that text, ignoring case, on the theme's primary color, the letters in
      # their own color and outline.
      #
      # Events: click.
      class Label < Component
        include TextSized
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "label"

        # The game's text color that \C[0] picks, its windows' normal color, which a label takes as its
        # own color.
        NORMAL_COLOR = 0

        # The escape code of an icon once converted, which a line needs the room of an icon for.
        ICON_CODE = /\eI\[/i

        # Tells the defaults of the options: one line in the plain text color and the normal size.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:text => "", :wrap => false, :escapes => false, :icon => nil, :icon_file => nil, :color => nil, :font_size => :normal,
                      :item => nil, :bag => false, :squeeze => false, :row_height => nil, :faint => false, :most_lines => nil, :plate => false,
                      :min_font_size => nil, :hide_cut => false, :body => false, :shorter => nil, :highlight => nil, :whole => false)
        end

        # Tells which properties of C#'s tree each option sets, the text's for its own.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          keys = super.dup
          [:text, :wrap, :escapes, :icon, :icon_file, :font_size, :item, :row_height, :body].each { |name| keys[name] = TextSized::PROPS }
          keys[:most_lines] = TextSized::PROPS + ["most_lines"]
          keys[:plate] = ["padding"]
          keys
        end

        # The room between a plate's edge and its text.
        PLATE_INSET = 4

        # What :plate names for a plate as wide as the text.
        TEXT_PLATE = :text

        # What :most_lines names to keep as many lines as the label's room holds.
        FILL = :fill

        # The opacity of a faint label.
        FAINT = 128

        # The canvas options of a line drawn whole, which draw_text squeezes into its width.
        WHOLE_LINE = {}.freeze

        # The canvas options of a line squeezed down to Canvas::SQUEEZE, then cut.
        SQUEEZED_LINE = { :squeeze => true }.freeze

        # The canvas options of a line cut with "..." to its width.
        CUT_LINE = { :cut => true }.freeze

        options :text, :wrap, :escapes, :icon, :icon_file, :color, :font_size, :item, :bag, :squeeze, :row_height, :faint, :most_lines, :plate, :min_font_size,
                :hide_cut, :body, :shorter, :highlight, :whole

        # Tells the properties C#'s tree lays it out by: the lines it keeps added.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["most_lines"] = most_lines_prop
          props
        end

        # Tells the largest font size, down to its :min_font_size, at which its text fits a width.
        #
        # @param width [Integer] The width.
        # @return [Integer] The pixels.
        def needed_px(width)
          px = UI.font_px(own_font_size)
          least = [@options[:min_font_size].to_i, 1].max
          text = label_text
          px -= 1 while px > least && UI.text_width(UI.font_bitmap(px), text) + Canvas::OUTLINE_ROOM > width
          px
        end

        # Tells its tooltip: its own, else its whole text while :squeeze cut it.
        #
        # @return [String, #call, nil] The tooltip.
        def tooltip
          @options[:tooltip] || @cut_text
        end

        # Tells how many lines it shows, as many as its height holds, and how high a line is.
        #
        # @return [Array<Integer>] The lines, at least one, and the pixels of a line.
        def lines_and_height
          height = line_height
          top, _right, bottom, _left = padding_sides
          room = @rect ? @rect.height - top - bottom : height
          [[room / height, 1].max, height]
        end

        # Draws its icon and its text.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, bottom, left = padding_sides
          top = line_top(canvas.height, top, bottom) unless wraps? || escapes?
          width = [canvas.width - left - right, 1].max
          look = text_look
          look[:size] = shared_px(width) if @options[:min_font_size] && !escapes? && !wraps?
          @shown_text = @options[:shorter] && !escapes? && !wraps? ? fitted_text(canvas, width, look[:size]) : nil
          draw_plate(canvas, left, width, look[:size]) if @options[:plate]
          draw_mark(canvas, left - ICON_STEP, top) if marked?
          if escapes?
            draw_runs(canvas, left, top, width)
          elsif wraps?
            draw_wrapped(canvas, left, top, width, canvas.height - top - bottom)
          else
            return note_cut(label_text) if @options[:hide_cut] && !fits?(canvas, width, look[:size])

            cut = canvas.text(left, top, width, line_height, label_text, look.merge(fit_look))
            note_cut(shorter_shown? || (cut && (@options[:squeeze] || @options[:min_font_size])) ? whole_text : nil)
          end
        end

        private

        # Tells how Canvas#text fits its line into its width: whole with :whole, which draw_text
        # squeezes, squeezed then cut with :squeeze, else cut.
        #
        # @return [Hash] The canvas options.
        def fit_look
          return WHOLE_LINE if @options[:whole]

          @options[:squeeze] ? SQUEEZED_LINE : CUT_LINE
        end

        # Tells where a text of one line starts: at the top of its room.
        #
        # @param _height [Integer] Its height.
        # @param top [Integer] The room above its text.
        # @param _bottom [Integer] The room below its text.
        # @return [Integer] The line's top.
        def line_top(_height, top, _bottom)
          top
        end

        # Picks the text a line shows: its whole text, else the first of its :shorter texts, that fits
        # a width; the last of them when none does.
        #
        # @param canvas [Canvas] Where it draws.
        # @param width [Integer] The width.
        # @param px [Integer] The pixels of the font it draws in.
        # @return [String] The text.
        def fitted_text(canvas, width, px)
          texts = [whole_text] + Array(@options[:shorter]).map { |text| text.to_s }
          texts.find { |text| canvas.text_width(text, px) <= width } || texts.last
        end

        # Tells whether a shorter text shows in place of its whole text.
        #
        # @return [Boolean] Whether one does.
        def shorter_shown?
          !@shown_text.nil? && @shown_text != whole_text
        end

        # Tells whether its text fits a width whole, squeezed down to Canvas::SQUEEZE with :squeeze.
        #
        # @param canvas [Canvas] Where it draws.
        # @param width [Integer] The width.
        # @param px [Integer] The pixels of the font it draws in.
        # @return [Boolean] Whether it fits.
        def fits?(canvas, width, px)
          canvas.text_width(label_text, px) * (@options[:squeeze] ? Canvas::SQUEEZE : 1) <= width
        end

        # Draws its plate: the field's across its place, or with :plate => :text the theme's plate as
        # wide as its text with its room on either side, where :align puts the text. A text the label
        # wraps or reads escape codes in takes its whole width.
        #
        # @param canvas [Canvas] Where it draws.
        # @param left [Integer] The text's left.
        # @param width [Integer] The text's room.
        # @param px [Integer] The pixels of the font it draws in.
        def draw_plate(canvas, left, width, px)
          return canvas.box(0, 0, canvas.width, canvas.height, :fill => :field) unless @options[:plate] == TEXT_PLATE

          text = label_text
          return if text.empty? && !marked?

          text_width = wraps? || escapes? ? width : [canvas.text_width(text, px), width].min
          x = { :center => left + (width - text_width) / 2, :right => left + width - text_width }[text_align] || left
          x -= ICON_STEP if marked? && text_align == :left
          text_width += ICON_STEP if marked? && text_align == :left
          _top, room_right, _bottom, room_left = room_sides
          canvas.fill(x - room_left, 0, text_width + room_left + room_right, canvas.height, :plate)
        end

        # Draws its text wrapped to its width, keeping the lines :most_lines lets it, the last kept one
        # ending with "..." when more follow; the whole text is then its tooltip.
        #
        # @param canvas [Canvas] Where it draws.
        # @param left [Integer] The text's left.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        # @param room [Integer] The height its lines may take.
        def draw_wrapped(canvas, left, top, width, room)
          bitmap = UI.font_bitmap(text_px)
          lines = UI.wrap(bitmap, label_text, width)
          kept = kept_lines(lines.size, room)
          if @parent && @parent.container? && @parent.tail && lines.size > room / [line_height, 1].max
            lines = lines.last([room / [line_height, 1].max, 1].max)
            kept = lines.size
          end
          cut = lines.size > kept
          lines = UI.keep_lines(bitmap, lines, kept, width)
          lines.each_with_index { |line, row| canvas.text(left, top + row * line_height, width, line_height, line, text_look) }
          note_cut(cut ? label_text : nil)
        end

        # Tells how many lines it keeps of some: :most_lines of them, as many as its room holds with
        # :fill, else all of them.
        #
        # @param count [Integer] The lines there are.
        # @param room [Integer] The height its lines may take.
        # @return [Integer] The lines kept, at least one.
        def kept_lines(count, room)
          most = @options[:most_lines]
          return count if most.nil?

          most = room / [line_height, 1].max if most == FILL
          [[most.to_i, 1].max, count].min
        end

        # Tells C# the lines it keeps: the number, -1 for as many as its room holds, 0 for every one.
        #
        # @return [Integer] The lines.
        def most_lines_prop
          most = @options[:most_lines]
          return 0 if most.nil? || !wraps?

          most == FILL ? -1 : [most.to_i, 1].max
        end

        # Tells the font size it draws in with :min_font_size: the smallest that it or another label
        # of its row with one needs, so names side by side read alike.
        #
        # @param width [Integer] Its text's room.
        # @return [Integer] The pixels.
        def shared_px(width)
          own = needed_px(width)
          peers = @parent ? @parent.children.select { |child| child.is_a?(Label) && child.min_font_size && child.rect && !child.equal?(self) } : []
          peers.inject(own) do |least, peer|
            _top, right, _bottom, left = peer.send(:padding_sides)
            [least, peer.needed_px([peer.rect.width - left - right, 1].max)].min
          end
        end

        # Follows a changed option: a label with :min_font_size has the others of its row draw anew,
        # whose shared size may change with its text.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @options[:min_font_size] && @parent && [:text, :item, :min_font_size].include?(name)

          @parent.children.each { |child| child.redraw if child.is_a?(Label) && child.min_font_size }
        end

        # Tells the text it shows: the shorter text that fits in place of its whole text, else its
        # whole text.
        #
        # @return [String] The text.
        def label_text
          @shown_text || whole_text
        end

        # Tells its whole text: its item's name, else its text.
        #
        # @return [String] The text.
        def whole_text
          @options[:item] ? Game.item_name(@options[:item]) : @options[:text].to_s
        end

        # Keeps the whole text as its tooltip while :squeeze cut it, and tells C# it has one.
        #
        # @param text [String, nil] The whole text, nil when nothing was cut.
        def note_cut(text)
          return if text == @cut_text

          @cut_text = text
          Tree.set(self, "tooltip" => !tooltip.to_s.empty?)
        end

        # Tells the text as C# measures it: with its escape codes converted when it has them.
        #
        # @return [String] The text.
        def measured_text
          escapes? ? Escapes.convert(whole_text) : whole_text
        end

        # Tells the pixels of its font.
        #
        # @return [Integer] The pixels.
        def text_px
          UI.font_px(own_font_size)
        end

        # Tells its font size: the game's own for body text (:body) in the game's own look, as the
        # game's windows draw their texts, else its :font_size.
        #
        # @return [Symbol, Integer] The size, see UI.font_px.
        def own_font_size
          @options[:body] && game_look? ? :game : @options[:font_size]
        end

        # Tells whether its text wraps.
        #
        # @return [Boolean] Whether it does.
        def wraps?
          @options[:wrap] ? true : false
        end

        # Tells whether its text carries the game's escape codes.
        #
        # @return [Boolean] Whether it does.
        def escapes?
          @options[:escapes] ? true : false
        end

        # Tells the height of a line: its :row_height, else its font's (UI.line_height_of), or the
        # game's when an icon or an escape code's icon needs the room; never below an icon it draws.
        #
        # @return [Integer] The pixels.
        def line_height
          iconed = marked? || escaped_icon?
          own = @options[:row_height]
          return [UI.whole(own), iconed ? ICON_SIZE : 1].max if own

          iconed ? LINE_HEIGHT : UI.line_height_of(own_font_size)
        end

        # Tells whether its text draws an icon by an escape code, kept for the text.
        #
        # @return [Boolean] Whether it does.
        def escaped_icon?
          return false unless escapes?

          text = label_text
          @escaped_icon = [text, (Escapes.convert(text) =~ ICON_CODE) ? true : false] unless @escaped_icon && @escaped_icon[0] == text
          @escaped_icon[1]
        end

        # Tells whether it has an icon or an icon file before its text.
        #
        # @return [Boolean] Whether it has.
        def marked?
          !mark_icon.nil? || !@options[:icon_file].nil?
        end

        # Tells the icon before its text: its own, else its item's unless :icon is false.
        #
        # @return [Integer, nil] The icon, nil for none.
        def mark_icon
          return nil if @options[:icon] == false

          @options[:icon] || (@options[:item] && @options[:item].icon_index)
        end

        # Tells its plate's inset on either side, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          inset = @options[:plate] ? PLATE_INSET : 0
          [0, inset, 0, inset]
        end

        # Tells the room its icon takes before its text.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [0, 0, 0, marked? ? ICON_STEP : 0]
        end

        # Tells how its text draws: its color, size and place in its width.
        #
        # @return [Hash] The options of Canvas#text.
        def text_look
          look = { :color => own_color, :size => text_px, :align => text_align }
          look[:opacity] = FAINT if @options[:faint]
          look[:highlight] = @options[:highlight] if @options[:highlight]
          look
        end

        # Tells its text's color: its own, else its item's in the game, nil for the plain text color.
        #
        # @return [Symbol, Integer, Color, nil] The color.
        def own_color
          return @options[:color] if @options[:color] || @options[:item].nil?

          color = Game.item_color(@options[:item], @options[:bag])
          color == Label::NORMAL_COLOR ? nil : color
        end

        # Tells where its text lies in its width, by its :align.
        #
        # @return [Symbol] :left, :center or :right.
        def text_align
          { :center => :center, :end => :right }[@options[:align]] || :left
        end

        # Draws its icon, or the picture of its icon file, as large as an icon.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The icon's left.
        # @param y [Integer] The top of its first line.
        def draw_mark(canvas, x, y)
          top = y + (line_height - ICON_SIZE) / 2
          return canvas.icon(mark_icon, x, top, :opacity => @options[:faint] ? FAINT : nil) if mark_icon

          picture = UI.picture(@options[:icon_file])
          canvas.picture(picture, x, top, ICON_SIZE, ICON_SIZE) if picture
        end

        # Draws a text with escape codes as C# laid it out: each line's runs of colored text and its
        # icons, or, while C# cannot lay it out, the text without its codes on one line.
        #
        # @param canvas [Canvas] Where it draws.
        # @param left [Integer] The text's left.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        def draw_runs(canvas, left, top, width)
          lines = Escapes.runs(UI.font_bitmap(text_px), label_text, wraps? ? width : nil)
          unless lines.is_a?(Array)
            plain = Escapes.convert(label_text).gsub(Escapes::CODE, "")
            cut = canvas.text(left, top, width, line_height, plain, text_look.merge(@options[:squeeze] ? { :squeeze => true } : { :cut => true }))
            return note_cut(cut && @options[:squeeze] ? plain : nil)
          end
          return draw_squeezed(canvas, lines[0], left, top, width) if @options[:squeeze] && !wraps? && lines.size == 1

          lines.each_with_index do |line, row|
            y = top + row * line_height
            shift = { :center => (width - line["width"].to_i) / 2, :right => width - line["width"].to_i }[text_align] || 0
            Array(line["runs"]).each { |run| draw_run(canvas, run, left + shift, y, left + width) }
          end
        end

        # Draws a line of runs too wide for its width narrower, every run alike, down to the canvas's
        # least share; a line wider than that is cut with "..." first.
        #
        # @param canvas [Canvas] Where it draws.
        # @param line [Hash] The line C# laid out: "width" and "runs".
        # @param left [Integer] Its left.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        def draw_squeezed(canvas, line, left, top, width)
          runs = Array(line["runs"])
          total = [line["width"].to_i, 1].max
          room = [total, (width / Canvas::SQUEEZE).floor].min
          cut = room < total
          runs = cut_runs(runs, room) if cut
          note_cut(cut ? Escapes.convert(label_text).gsub(Escapes::CODE, "") : nil)
          factor = [width.to_f / room, 1.0].min
          runs.each { |run| draw_run(canvas, run, left, top, left + width, factor) }
        end

        # Cuts runs to a width with "..." after the last text that fits.
        #
        # @param runs [Array<Hash>] The runs.
        # @param room [Integer] The width.
        # @return [Array<Hash>] The runs that fit, the last cut.
        def cut_runs(runs, room)
          measure = UI.font_bitmap(text_px)
          kept = []
          runs.each do |run|
            x = run["x"].to_i
            if run["icon"]
              break if x + ICON_STEP > room

              kept << run
              next
            end
            text = run["text"].to_s
            shown = UI.cut(measure, text, room - x)
            kept << run.merge("text" => shown)
            break if shown != text
          end
          kept
        end

        # Draws one run of a line: an icon, or a text in the color an escape code gave it.
        #
        # @param canvas [Canvas] Where it draws.
        # @param run [Hash] The run: "x" and "icon", or "x", "text" and "color".
        # @param left [Integer] The line's left.
        # @param y [Integer] Its top.
        # @param right [Integer] The text's right edge.
        # @param factor [Float] How much narrower the line draws, 1 for as wide as it is.
        def draw_run(canvas, run, left, y, right, factor = 1.0)
          x = left + (run["x"].to_i * factor).floor
          if factor < 1.0 && !run["icon"]
            box = [(canvas.text_width(run["text"].to_s, text_px) * factor).ceil, 1].max
            return canvas.text(x, y, [box, right - x].min, line_height, run["text"].to_s, text_look.merge(:color => run_color(run["color"]), :align => :left, :squeeze => true))
          end
          return canvas.icon(run["icon"], x, y + (line_height - ICON_SIZE) / 2, :opacity => @options[:faint] ? FAINT : nil) if run["icon"]

          # Bitmap#draw_text squeezes a text into a box narrower than it, so the box runs to the edge.
          canvas.text(x, y, [right - x, 1].max + Style::PAD, line_height, run["text"].to_s, text_look.merge(:color => run_color(run["color"]), :align => :left))
        end

        # Tells the color a run draws in: the one an escape code gave it, else the label's own.
        #
        # The game's texts, such as the effect names of items, start with \C[0], which would otherwise
        # draw a dimmed label in the plain text color.
        #
        # @param code [Integer, nil] The game text color an escape code gave the run, nil for none.
        # @return [Symbol, Integer, Color, nil] The color.
        def run_color(code)
          code.nil? || code == NORMAL_COLOR ? own_color : code
        end
      end

      # A column under a heading, as the parts of a panel are titled: what is added goes under the
      # heading, which clear keeps. A :note stands at the heading's right, dim unless :note_color says
      # otherwise, in :note_size, the heading's size without it.
      class Group < Stack
        # The options of the heading by the group's options that set them.
        HEADING = { :title => :text, :title_color => :color, :title_size => :font_size, :title_height => :row_height }

        # Tells the defaults of the options: a heading in the small font and the system color.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 4, :title => "", :title_color => :system, :title_size => :small, :title_height => nil, :note => nil,
                      :note_color => :dim, :note_size => nil)
        end

        options :title, :title_color, :title_size, :title_height, :note, :note_color, :note_size

        # @return [Label, nil] The note at the heading's right, nil until it has one.
        attr_reader :note_label

        # @return [Label] The heading.
        attr_reader :heading

        # Tells what heads it: the heading, or the row of the heading and its note.
        #
        # @return [Component] The heading or its row.
        def head
          @heading_row || @heading
        end

        # Makes the group with its heading.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @heading = add(Label.new(Hash[HEADING.map { |option, own| [own, @options[option]] }]))
          show_note
        end

        # Takes every component out of it but its heading.
        #
        # @return [Group] Itself.
        def clear
          super
          add(@heading_row || @heading)
          self
        end

        private

        # Follows a changed option: the heading's own take it.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          @heading.send("#{HEADING[name]}=", @options[name]) if HEADING.key?(name) && @heading
          show_note if [:note, :note_color, :note_size, :title_size].include?(name) && @heading
        end

        # Shows its note at the heading's right, putting the heading and the note in a row the first
        # time it has one.
        def show_note
          return if @options[:note].nil? && @note_label.nil?

          unless @note_label
            place = @heading.index
            remove(@heading)
            @heading.grow = 1
            @heading_row = add(Stack.new(:layout => :row, :gap => Style::PAD), place)
            @heading_row.add(@heading)
            @note_label = @heading_row.add(Label.new(:align => :end))
          end
          @note_label.text = @options[:note].to_s
          @note_label.color = @options[:note_color]
          @note_label.font_size = @options[:note_size] || @options[:title_size]
        end
      end

      # A head over what follows, as the game's info page heads an item: its :icon at :icon_scale
      # beside its :title in the large font and :title_color, squeezed before it is cut, its :marks
      # after the title (icons, each a Hash of :icon and :tooltip) and a :subtitle line under the
      # title in :subtitle_color. An :icon of nil keeps the icon's room empty; false leaves it out.
      # The title's row and the subtitle's row take other components after the title and the
      # subtitle, such as a button, which a new :icon_scale or :compact drops as it makes the header
      # anew; the other options change in place. With :compact it is one row of a line's height: the icon
      # at the icon sheet's size, the title, the marks and the subtitle in the room the title leaves,
      # which gives up its room first, cut with "..." and its whole text as its tooltip; its subtitle
      # row is then a row within the title's row. trailing= puts a part at the end of the title's
      # row and title_after= one right after the title and its marks, also after it made itself anew.
      class Header < Stack
        # The options that make the header anew.
        BUILT_BY = [:icon_scale, :compact]

        # Room between the parts of the title's row and of the subtitle's.
        TITLE_GAP = 4

        # Tells the defaults of the options: a row without an icon, a title in the plain text color
        # and a dim subtitle.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => 8, :icon => false, :title => "", :title_color => nil, :marks => [], :subtitle => "", :subtitle_color => :dim,
                      :icon_scale => 2, :compact => false)
        end

        options :icon, :title, :title_color, :marks, :subtitle, :subtitle_color, :icon_scale, :compact

        # @return [Icon, nil] The icon, nil when it is left out.
        attr_reader :icon_part

        # @return [Label] The title.
        attr_reader :title_label

        # @return [Stack] The row of the title, which takes other components after it.
        attr_reader :title_row

        # @return [Stack] The row of the subtitle, which takes other components after it.
        attr_reader :subtitle_row

        # @return [Label] The subtitle.
        attr_reader :subtitle_label

        # Makes the header.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          build
        end

        # Tells its size with :compact: as wide as its icon, its title, its marks and its subtitle
        # drawn whole, though the subtitle takes only the room the title leaves; without it, nil,
        # as C# measures what it holds.
        #
        # @return [Array, nil] Its width and nil for its height, nil without :compact.
        def measure
          return nil unless @options[:compact] && @title_label

          title = UI.text_width(UI.font_bitmap(UI.font_px(:large)), @title_label.text)
          subtitle = UI.text_width(UI.font_bitmap(UI.font_px(:small)), @subtitle_label.text)
          icon = @icon_part ? ICON_SIZE + UI.whole(@options[:gap]) : 0
          after = @title_after && @title_after.rect ? @title_after.rect.width + TITLE_GAP : 0
          [icon + title + @mark_icons.size * (ICON_SIZE + TITLE_GAP) + after + TITLE_GAP + subtitle + 2 * Canvas::OUTLINE_ROOM, nil]
        end

        # Puts a part at the end of the title's row, after room that pushes it to the row's end unless
        # it is compact, where it follows the subtitle; nil takes it away.
        #
        # @param part [Component, nil] The part, such as a star that marks a favorite.
        def trailing=(part)
          return if part.equal?(@trailing) && (part.nil? || @title_row.children.last.equal?(part))

          [@trailing_room, @trailing].compact.each { |each| each.parent.remove(each) if each.parent }
          @trailing = part
          return unless part

          @trailing_room = @options[:compact] ? nil : @title_row.add_column(:width => 0, :grow => 1)
          @title_row.add(part)
        end

        # Puts a part right after the title and its marks, such as a chip of a weapon's elements; nil
        # takes it away.
        #
        # @param part [Component, nil] The part.
        def title_after=(part)
          place = 1 + @mark_icons.size
          return if part.equal?(@title_after) && (part.nil? || @title_row.children[place].equal?(part))

          @title_after.parent.remove(@title_after) if @title_after && @title_after.parent
          @title_after = part
          @title_row.add(part, place) if part
        end

        private

        # Follows a changed option: those of BUILT_BY make the header anew, the others change their
        # part in place, so a header that follows a cursor keeps the parts after its title; a compact
        # header measures anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @title_label

          relayout if @options[:compact]
          return build if self.class::BUILT_BY.include?(name)

          case name
          when :icon then show_icon
          when :title, :title_color then show_title
          when :marks then show_marks
          when :subtitle then @subtitle_label.text = subtitle_text
          when :subtitle_color then @subtitle_label.color = @options[:subtitle_color]
          end
        end

        # Shows the icon of now, making the header anew when the icon's room comes or goes.
        def show_icon
          icon = shown_icon
          return build if (icon == false) != @icon_part.nil?

          @icon_part.icon = icon if @icon_part
        end

        # Shows the title of now in its color.
        def show_title
          title, color = shown_title
          @title_label.text = title
          @title_label.color = color
        end

        # Shows the marks of now after the title.
        def show_marks
          @mark_icons.each { |icon| @title_row.remove(icon) }
          @mark_icons = shown_marks.each_with_index.map { |mark, place| @title_row.add(Icon.new(:icon => mark[:icon], :tooltip => mark[:tooltip]), place + 1) }
        end

        # Tells the icon it shows: an icon, nil for an empty room, false for none.
        #
        # @return [Integer, Symbol, Hash, nil, false] The icon.
        def shown_icon
          @options[:icon]
        end

        # Tells the title's text and color.
        #
        # @return [Array] The text and its color, nil for the plain text color.
        def shown_title
          [@options[:title].to_s, @options[:title_color]]
        end

        # Tells the marks after the title.
        #
        # @return [Array<Hash>] Each :icon and :tooltip.
        def shown_marks
          Array(@options[:marks])
        end

        # Tells the subtitle's text.
        #
        # @return [String] The text.
        def subtitle_text
          @options[:subtitle].to_s
        end

        # Makes the icon, the title with the marks and the subtitle's row, under the title or with
        # :compact after it.
        def build
          clear
          compact = @options[:compact]
          icon = shown_icon
          @icon_part = icon == false ? nil : add_icon(icon, :scale => compact ? 1 : @options[:icon_scale], :align => compact ? :center : :start)
          text = compact ? self : add_column(:grow => 1, :gap => 0, :shrink => true)
          line = @title_row = text.add_row(:gap => TITLE_GAP, :height => LINE_HEIGHT, :grow => compact ? 1 : 0, :shrink => compact)
          title, color = shown_title
          @title_label = line.add_label(title, :color => color, :font_size => :large, :squeeze => true, :shrink => true)
          @mark_icons = shown_marks.map { |mark| line.add_icon(mark[:icon], :tooltip => mark[:tooltip]) }
          @subtitle_row = compact ? line.add_row(:gap => TITLE_GAP, :width => 0, :grow => 1) : text.add_row(:gap => TITLE_GAP, :height => LINE_HEIGHT)
          @subtitle_label = @subtitle_row.add_label(subtitle_text, :font_size => :small, :color => @options[:subtitle_color], :squeeze => true, :shrink => true,
                                                    :grow => 1, :padding => [2, 0, 2, 0])
        end
      end

      # A row with a caption: the caption in the small font and the system color at the left, then a
      # column that takes whatever is added to the field, such as a value beside its name.
      # :caption_width makes the caption that wide: pixels, or the captions of the fields that should
      # line up, of which the widest sets the width, so captions on either side of a comparison start
      # their values alike. :plate draws the column on the darker plate a text field has, so a value
      # reads as one. clear empties the column and keeps the caption.
      class Field < Stack
        # Room above the caption, so its small text sits on the line of a text in the game's font.
        CAPTION_TOP = 2

        # Tells the defaults of the options: a row with room after the caption and a column of a gap
        # of 2 for what is added.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => 6, :caption => "", :caption_width => nil, :caption_color => :system, :caption_size => :small,
                      :body => { :gap => 2 }, :plate => false)
        end

        options :caption, :caption_width, :caption_color, :caption_size, :plate

        # @return [Label] The caption.
        attr_reader :caption_label

        # @return [Stack] The column that takes what is added.
        attr_reader :body

        # Makes the field with its caption and its column.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @caption_label = add(Label.new(:text => @options[:caption].to_s, :font_size => @options[:caption_size], :color => @options[:caption_color],
                                         :width => caption_px, :padding => [CAPTION_TOP, 0, 0, 0]))
          @body = add(Stack.new({ :layout => :column }.merge(@options[:body] || {}).merge(:grow => 1, :shrink => true, :padding => plate_padding)))
        end

        # Draws its plate behind its column while :plate holds.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          super
          return unless @options[:plate] && @body && @body.rect && @rect

          canvas.box(@body.rect.x - @rect.x, @body.rect.y - @rect.y, @body.rect.width, @body.rect.height, :fill => :field)
        end

        # Adds a component into its column.
        #
        # @param child [Component] The component.
        # @param index [Integer, nil] Its place in the column, nil for its end.
        # @return [Component] The component added.
        def add(child, index = nil)
          @body ? @body.add(child, index) : super
        end

        # Empties its column; the caption stays.
        #
        # @return [Field] Itself.
        def clear
          @body ? @body.clear : super
          self
        end

        private

        # Follows a changed option: the caption takes its own.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @caption_label

          case name
          when :caption then @caption_label.text = @options[:caption].to_s
          when :plate
            @body.padding = plate_padding
            redraw
          when :caption_color then @caption_label.color = @options[:caption_color]
          when :caption_size, :caption_width
            @caption_label.font_size = @options[:caption_size]
            @caption_label.width = caption_px
          end
        end

        # Tells the room around the column: a plate's inset at either side while :plate holds.
        #
        # @return [Array<Integer>, Integer] Top, right, bottom and left, or 0.
        def plate_padding
          @options[:plate] ? [1, Label::PLATE_INSET, 1, Label::PLATE_INSET] : 0
        end

        # Tells the caption's width: the pixels given, else the widest of the captions given in the
        # caption's font, with room for its outline.
        #
        # @return [Integer, nil] The pixels, nil to fit the caption.
        def caption_px
          UI.measured_width(@options[:caption_width], UI.font_px(@options[:caption_size]))
        end
      end

      # A notice on a plate across its parent: a line in the small font, in :warn unless :color says
      # otherwise, squeezed and then cut with its whole text as its tooltip unless :tip gives one, and
      # the buttons added after it, such as a restart a change waits for. Hidden, it takes no room, so
      # a window adds it last and shows it while the notice holds. An :accent color draws a bar down
      # its left edge, an :icon stands before its line, :dense keeps it low, and :closeable puts a
      # close mark at its end, whose click tells close.
      #
      # Events: close.
      class Alert < Stack
        # The alert's line: a label whose text of one line stands in the middle of its height, level
        # with the buttons and the close mark beside it, as the row stretches a line that starts at
        # its left as high as they are.
        class Line < Label
          private

          # Tells where its text of one line starts: in the middle of its room.
          #
          # @param height [Integer] Its height.
          # @param top [Integer] The room above its text.
          # @param bottom [Integer] The room below its text.
          # @return [Integer] The line's top.
          def line_top(height, top, bottom)
            top + [(height - top - bottom - line_height) / 2, 0].max
          end
        end

        # Room between the plate's edge and what it holds: top, right, bottom and left.
        ROOM = [2, 4, 2, 8]

        # Room of a dense alert: top, right, bottom and left.
        DENSE_ROOM = [0, 4, 0, 8]

        # The width of the accent bar down its left edge.
        ACCENT = 3

        # The close mark's text.
        CLOSE_MARK = "x"

        # Tells the defaults of the options: a row 4 apart, its text in the warning color.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => Style::GAP, :text => "", :color => :warn, :tip => nil, :accent => nil, :icon => nil, :dense => false,
                      :closeable => false, :align_text => :center, :most_lines => nil)
        end

        # Tells which properties of C#'s tree each option sets, the room its plate keeps for :dense.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:dense => ["padding"])
        end

        options :text, :color, :tip, :accent, :icon, :dense, :closeable, :most_lines

        # @return [Label] The line.
        attr_reader :label

        # @return [Button, nil] The close mark, nil while it is not closeable.
        attr_reader :close_mark

        # Makes the alert with its line, and its close mark when it is closeable.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          most = @options[:most_lines]
          align = @options[:align_text] == :start ? :stretch : @options[:align_text]
          @label = add(Line.new(:text => @options[:text].to_s, :color => @options[:color], :font_size => :small, :squeeze => most.nil?, :icon => @options[:icon],
                                :tooltip => @options[:tip], :width => 0, :grow => 1, :align => align, :wrap => !most.nil?, :most_lines => most))
          @close_mark = nil
          mark_close if @options[:closeable]
        end

        # Tells the parts it holds besides the line and the close mark, such as its buttons.
        #
        # @return [Array<Component>] The parts.
        def own_parts
          @children - [@label, @close_mark]
        end

        # Draws its plate and its accent bar; the line and the buttons draw over it.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          canvas.box(0, 0, canvas.width, canvas.height, :fill => :plate)
          canvas.fill(0, 0, ACCENT, canvas.height, @options[:accent]) if @options[:accent]
        end

        private

        # Follows a changed option: the line takes its text, its color and its tooltip.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @label

          case name
          when :text then @label.text = @options[:text].to_s
          when :color then @label.color = @options[:color]
          when :tip then @label.tooltip = @options[:tip]
          when :icon then @label.icon = @options[:icon]
          when :closeable then @options[:closeable] ? mark_close : drop_close
          when :most_lines then wrap_label
          end
        end

        # Has the line wrap into at most :most_lines lines, or keep to one line cut to its room.
        def wrap_label
          most = @options[:most_lines]
          @label.squeeze = most.nil?
          @label.wrap = !most.nil?
          @label.most_lines = most
        end

        # Puts the close mark at its end, once.
        def mark_close
          return if @close_mark

          @close_mark = add(Button.new(:text => CLOSE_MARK, :flat => true, :font_size => :small))
          @close_mark.on(:click) { emit(:close) }
        end

        # Takes the close mark away.
        def drop_close
          return unless @close_mark

          remove(@close_mark)
          @close_mark = nil
        end

        # Tells the room its plate keeps around what it holds, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          @options[:dense] ? DENSE_ROOM : ROOM
        end
      end
    end

    Engine::Container.adds(:label) { |text, *rest| Engine::Label.new((rest[0] || {}).merge(:text => text)) }
    Engine::Container.adds(:field) { |caption, *rest| Engine::Field.new((rest[0] || {}).merge(:caption => caption)) }
  end
end
