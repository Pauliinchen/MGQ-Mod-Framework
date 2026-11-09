#----------------------------------------------------------------
#  components_lines.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Filled the tooltip of a line that stands for markup through :tips
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Lines of text that show as many as the room they get holds, never scrolling: each line is a
      # label on a row of :row_height, squeezed rather than wrapped, and the lines flow down the first
      # column, then the next. :columns => :auto takes a second column only when one does not hold
      # them all; :columns => :room takes two whenever every line fits a column's width, or one column
      # does not hold them all, and splits the lines evenly between them. With :span the lines lie
      # across the columns row by row instead: a line too wide for a column takes a whole row, and a
      # short line takes the first free cell of its group, so :columns => :room always takes two.
      # Lines come alone or in groups, each group with its label in a gutter beside its first line
      # unless :titles is false; :sort sorts the lines inside each group. A line's :detail shows
      # wrapped under it while there is room, else as its tooltip. When even that runs out of room,
      # the last row tells how many lines are left (:more_text) and holds them as its tooltip. :color
      # draws every line and detail without a color of its own. :note, a block that fills the end of
      # a tooltip's box, ends the tooltip of every line that has one. A line's :tip, a number, stands
      # for its tooltip: :tips, a block of the number and a tooltip's box, fills the box as it opens.
      # With no lines at all it shows
      # :empty_text in a dim line, unless that is nil. :detail_size and :detail_height set the font and
      # the row height of the details, the lines' own unless given. With :most_rows it measures no
      # higher than that many rows, so a part as high as what it holds gives it no more room than
      # that; it still shows what the room it gets holds. It lays itself out anew whenever its place
      # changes. pulse(place) pulses one line, such as one that just changed; every line pulsed before
      # it has a place pulses once it gets one.
      #
      # With :cursor every line is a key stop, as the rows of a list are: UP and DOWN move the focus
      # from line to line, the line with the focus draws the cursor's plate, and a click on a line or
      # confirm on it tells submit. :index is the line the cursor is on, which stays when the focus
      # leaves. With :compact => :auto, when the lines with every detail do not fit, each line takes
      # one row and only the cursor's line shows its detail, the others' going into their tooltips,
      # so moving the cursor moves the detail shown; a line whose tooltip is a block gets its detail
      # added at the end of the box. Lines with an :id give each line's key stop the id
      # "<id>:<place>", so a line laid out anew keeps the focus. With a gutter the cursor's plate
      # starts past it, so the group's label stays readable.
      #
      # A line is a String or a Hash of :text, :color, :tooltip, :faint, :item (an item as a label's
      # :item shows it), :icon, :accent (a color drawn as a bar down its left edge, such as a toast's
      # severity), :detail and :own_row (true puts it in a row of its own under every column, in the
      # first, such as a line that sums the others up). A group is [label, lines] or a
      # Hash of :label, :lines, :color (its label's) and :faint.
      #
      # Events: more (the lines left out, as the row that tells them is clicked), change (line, place:
      # the cursor moved to another line), submit (line, place: a click on a line, or confirm on it).
      class Lines < Component
        include Container

        # The component's kind in C#'s tree: a container whose lines lie at their own places.
        KIND = "stack"

        # Room between the gutter and the lines.
        GUTTER_GAP = 4

        # The width of a line's accent bar.
        ACCENT = 3

        # Room between a line's accent bar and its text.
        ACCENT_GAP = 4

        # The text of the row that tells how many lines are left out.
        MORE_TEXT = "+%d more"

        # Room a squeezed label keeps for the outline of its text, which a line that fits leaves free.
        OUTLINE = 2

        # The options that lay the lines out anew.
        LAYOUT_OPTIONS = [:lines, :font_size, :row_height, :escapes, :squeeze, :columns, :column_gap, :gutter, :group_gap, :more_text, :more_color,
                          :titles, :sort, :color, :span, :empty_text, :cursor, :compact, :detail_size, :detail_height, :most_rows, :note]

        # Tells the defaults of the options: one column of small lines, 18 high, squeezed, in the plain
        # text color, with the groups' labels, unsorted, flowing down the columns, their details in
        # their font; no key stops and the cursor on the first line.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :absolute, :lines => [], :font_size => :small, :row_height => 18, :escapes => false, :squeeze => true,
                      :columns => 1, :column_gap => 12, :gutter => 0, :group_gap => 2, :more_text => MORE_TEXT, :more_color => :dim,
                      :titles => true, :sort => nil, :color => nil, :span => false, :empty_text => nil, :cursor => false, :index => 0,
                      :compact => false, :detail_size => nil, :detail_height => nil, :most_rows => nil, :note => nil, :tips => nil)
        end

        # Tells which properties of C#'s tree each option sets: other lines measure anew.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          keys = super.dup
          [:lines, :font_size, :row_height, :escapes, :columns, :column_gap, :gutter, :group_gap, :titles, :span, :empty_text, :detail_size,
           :detail_height, :most_rows].each { |name| keys[name] = ["measured"] }
          keys
        end

        options(*LAYOUT_OPTIONS)
        options :tips

        # Sorts the lines inside each group, as :sort does; the groups and the lines of no group keep
        # their places.
        #
        # @param parts [Array] The lines and groups, as :lines takes them.
        # @param sort [Boolean, #call, nil] true sorts by the text without escape codes, ignoring case; a
        #   block of a line sorts by what it answers; nil and false leave them as they are.
        # @return [Array] The lines and groups.
        def self.sorted(parts, sort)
          return Array(parts) unless sort

          Array(parts).map do |part|
            next [part[0], sort_lines(part[1], sort)] if part.is_a?(Array)

            part.is_a?(Hash) && part.key?(:lines) ? part.merge(:lines => sort_lines(part[:lines], sort)) : part
          end
        end

        # Sorts lines, those alike keeping their order.
        #
        # @param lines [Array] The lines.
        # @param sort [Boolean, #call] See sorted.
        # @return [Array] The lines sorted.
        def self.sort_lines(lines, sort)
          Array(lines).each_with_index.sort_by { |line, place| [sort.respond_to?(:call) ? sort.call(line) : sort_key(line), place] }.map { |line, _place| line }
        end

        # Tells what a line sorts by with :sort => true.
        #
        # @param line [String, Hash] The line.
        # @return [String] Its text, or its item's name, without escape codes and in lower case.
        def self.sort_key(line)
          line = { :text => line } unless line.is_a?(Hash)
          text = line[:item] ? Game.item_name(line[:item]) : line[:text].to_s
          Escapes.convert(text).gsub(Escapes::CODE, "").downcase
        end

        # Makes the lines, laid out as one column until they have a place.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @plan = nil
          @entries = nil
          lay
        end

        # Tells its size: as wide as its widest line and detail in the columns a count of :columns
        # asks for, as high as every line in the columns it takes when it has room for all of them,
        # no higher than :most_rows rows.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          width = inner_width
          all, tail = apart(entries)
          count = @options[:columns] == :auto ? 1 : counts(all, width).first
          columns = under(fill(all, count, width, nil, true), tail)
          height = columns.map { |column| column.empty? ? 0 : column.last[1] + column.last[2] }.max.to_i
          [natural_width, @options[:most_rows] ? [height, @options[:most_rows].to_i * UI.whole(@options[:row_height])].min : height]
        end

        # Takes the place C# gave it, and lays the lines out anew when the room changed what fits; a
        # new width that wraps the details onto other rows, changes the columns :room takes or the
        # lines :span spreads over a row, measures it anew. The pulses asked for before it had a place
        # play now.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          width = @rect && @rect.width
          super
          lay
          pending = @pending_pulses || []
          @pending_pulses = nil
          pending.each { |place, options| pulse(place, options) }
          relayout if width != @rect.width && (@options[:columns] == :room || @options[:span] || entries.any? { |entry| entry[:detail] })
        end

        # Pulses one line once, its labels and its key stop, see Component#pulse; before the lines have
        # a place, as soon as they get one, and anew on the labels a new layout makes while it runs, as
        # the first layouts of new lines do. Without a line it pulses as any component does.
        #
        # @param place [Integer, Hash, nil] The line's place among the lines; the options of
        #   Component#pulse, or nil, to pulse every line.
        # @param options [Hash] The options of Component#pulse.
        # @return [Lines, Tween] Itself; the tween when it pulses every line.
        def pulse(place = nil, options = {})
          return super(place || options) unless place.is_a?(Integer)

          if @rect
            tweens = Array(@parts && @parts[place]).map { |part| part.pulse(options) }
            (@pulses ||= {})[place] = [options, tweens]
          else
            (@pending_pulses ||= []) << [place, options]
          end
          self
        end

        # Tells how many lines it leaves out for want of room.
        #
        # @return [Integer] The lines.
        def left_out
          @plan ? @plan[:rest].size : 0
        end

        # Tells how many columns it shows lines in.
        #
        # @return [Integer] The columns, at least one.
        def columns_shown
          @plan ? [@plan[:columns].count { |column| !column.empty? }, 1].max : 1
        end

        # Tells the line the cursor is on.
        #
        # @return [Integer] Its place among the lines.
        def index
          @options[:index].to_i
        end

        # Puts the cursor on a line without telling change; with :compact the detail shown follows.
        #
        # @param value [Integer] The line's place among the lines.
        def index=(value)
          @options[:index] = value.to_i
          lay
        end

        # Gives the lines new colors without laying them out anew, such as lines that fade out: the
        # line at each place takes the color at the same place, nil keeping its own.
        #
        # @param colors [Array<Symbol, Integer, Color, nil>] The colors, by the lines' places.
        # @return [Lines] Itself.
        def recolor(colors)
          Array(colors).each_with_index do |color, place|
            entry = entries[place]
            next if color.nil? || entry.nil?

            entry[:color] = color
            label = @labels && @labels[place]
            label.color = color if label
          end
          self
        end

        # Draws the lines see-through without drawing them anew, such as lines that fade out: the line
        # at each place at the opacity at the same place, nil drawing it whole; an accent bar fades
        # with its line.
        #
        # @param opacities [Array<Integer, nil>] The opacities from 0 to OPAQUE, by the lines' places.
        # @return [Lines] Itself.
        def fade_lines(opacities)
          Array(opacities).each_with_index do |opacity, place|
            entry = entries[place]
            next if entry.nil?

            redraw if entry[:accent] && entry[:opacity] != opacity
            entry[:opacity] = opacity
            label = @labels && @labels[place]
            label.opacity = opacity if label && label.opacity != (opacity || OPAQUE)
          end
          self
        end

        # Draws the accent bars of its lines, each as see-through as its line; the labels draw the
        # lines over it.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, _right, _bottom, left = padding_sides
          Array(@accents).each do |x, y, height, entry|
            color = entry[:accent]
            if entry[:opacity]
              color = canvas.color(color).dup
              color.alpha = color.alpha * entry[:opacity] / OPAQUE
            end
            canvas.fill(left + x, top + y, ACCENT, height, color)
          end
        end

        # Runs a block on an event; the first submit block makes a click on a line tell it.
        #
        # @param name [Symbol] The event.
        # @yield [*values] Runs on the event with its values.
        # @return [Lines] Itself.
        def on(name, &block)
          super
          lay_anew if name.to_sym == :submit
          self
        end

        # Drops every block of an event; without submit blocks a click on a line is quiet again.
        #
        # @param name [Symbol] The event.
        # @return [Lines] Itself.
        def off(name)
          super
          lay_anew if name.to_sym == :submit
          self
        end

        private

        # Follows a changed option: other lines or another look lay out anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless LAYOUT_OPTIONS.include?(name)

          @entries = nil
          @plan = nil
          lay
        end

        # Makes the labels anew even where the plan for its room stays the same.
        def lay_anew
          @plan = nil
          lay
        end

        # Makes a label per line where the plan for its room puts it, unless that plan is the one shown.
        def lay
          plan = plan_for(@rect ? inner_width : nil, @rect ? inner_height : nil)
          return if @plan && @plan[:key] == plan[:key]

          @plan = plan
          clear
          @parts = {}
          @labels = {}
          @accents = []
          count = plan[:columns].size
          width = column_width(count, plan[:width])
          plan[:columns].each_with_index do |column, place|
            left = place * (width + UI.whole(@options[:column_gap]))
            column.each { |entry, top, height, span| add_entry(entry, left, top, height, span_width(count, plan[:width], span || 1), plan) }
          end
          pulse_again
        end

        # Pulses the lines anew whose pulse still runs on the labels a new layout let go.
        def pulse_again
          running = (@pulses || {}).select { |_place, pulsed| pulsed[1].any? { |tween| tween.running? } }
          @pulses = {}
          running.each { |place, pulsed| pulse(place, pulsed[0]) } if @rect
        end

        # Works out what fits a room: every line with its details in as few columns as allowed, else
        # with :compact the cursor's detail alone, else without the details, else as many lines as fit
        # before a row that tells the rest; the lines in rows of their own go under them, or into that
        # row when they leave no room for it, such as in a room :most_rows keeps to one row.
        #
        # @param width [Integer, nil] The room's width, nil before it has one.
        # @param height [Integer, nil] The room's height, nil for room for everything.
        # @return [Hash] :key (what tells two plans apart), :columns (per column each line with its
        #   top and height), :details (see detailed?), :rest (the lines left out) and :width.
        def plan_for(width, height)
          all, tail = apart(entries)
          room = height && [height - tail_height(all, tail), 0].max
          tried = counts(all, width)
          detail_choices(all).each do |details|
            tried.each do |count|
              columns = fill(all, count, width, room, details)
              return planned(under(columns, tail), details, [], width, height) if columns
            end
          end
          (all.size - 1).downto(0) do |shown|
            rest = all[shown..-1]
            columns = flow(all.first(shown) + [more_entry(rest)], tried.last, width, room, false)
            return planned(under(columns, tail), false, rest, width, height) if columns
          end
          rest = all + tail
          columns = rest.empty? ? nil : flow([more_entry(rest)], 1, width, height, false)
          planned(columns || [[]], false, rest, width, height)
        end

        # Tells which details to try to show, the most first: every line's, then with :compact =>
        # :auto the cursor's line's alone, then none while any line has one.
        #
        # @param all [Array<Hash>] The lines that flow.
        # @return [Array<Boolean, Hash>] The choices, see detailed?.
        def detail_choices(all)
          return [true] if all.none? { |entry| entry[:detail] }

          shown = @options[:compact] == :auto ? entries[index] : nil
          shown && shown[:detail] && all.any? { |entry| entry.equal?(shown) } ? [true, shown, false] : [true, false]
        end

        # Tells whether a line shows its detail under it.
        #
        # @param entry [Hash] The line.
        # @param details [Boolean, Hash] true for every line's detail, false for none, or the one line
        #   whose detail alone shows.
        # @return [Boolean] Whether it does.
        def detailed?(entry, details)
          details == true || entry.equal?(details)
        end

        # Splits the lines into those that flow through the columns and those in rows of their own.
        #
        # @param all [Array<Hash>] The lines.
        # @return [Array<Array<Hash>>] The lines that flow, and those in rows of their own.
        def apart(all)
          [all.reject { |entry| entry[:own_row] }, all.select { |entry| entry[:own_row] }]
        end

        # Tells the height the lines in rows of their own take, with a group gap above them under
        # other lines.
        #
        # @param all [Array<Hash>] The lines that flow.
        # @param tail [Array<Hash>] The lines in rows of their own.
        # @return [Integer] The pixels.
        def tail_height(all, tail)
          return 0 if tail.empty?

          tail.inject(all.empty? ? 0 : UI.whole(@options[:group_gap])) { |sum, entry| sum + line_height(entry) }
        end

        # Puts the lines in rows of their own under every column, in the first.
        #
        # @param columns [Array<Array>] Per column each line with its top and height.
        # @param tail [Array<Hash>] The lines in rows of their own.
        # @return [Array<Array>] The columns with them.
        def under(columns, tail)
          return columns if tail.empty?

          top = columns.flatten(1).map { |_entry, at, tall| at + tall }.max.to_i
          top += UI.whole(@options[:group_gap]) if top > 0
          columns = columns.map { |column| column.dup }
          tail.each do |entry|
            tall = line_height(entry)
            columns[0] << [entry, top, tall]
            top += tall
          end
          columns
        end

        # Tells the counts of columns to try, fewest first.
        #
        # @param all [Array<Hash>] The lines.
        # @param width [Integer, nil] The room's width.
        # @return [Array<Integer>] The counts.
        def counts(all, width)
          case @options[:columns]
          when :auto then [1, 2]
          when :room then all.size > 1 && (@options[:span] || fit_width?(all, 2, width)) ? [2] : [1, 2]
          else [column_count]
          end
        end

        # Puts a plan together.
        #
        # @param columns [Array<Array>] Per column each line with its top and height.
        # @param details [Boolean, Hash] Which details show, see detailed?.
        # @param rest [Array<Hash>] The lines left out.
        # @param width [Integer, nil] The room's width.
        # @param height [Integer, nil] The room's height.
        # @return [Hash] The plan, see plan_for.
        def planned(columns, details, rest, width, height)
          shown = details.is_a?(Hash) ? [:cursor, index] : details
          { :key => [width, height, columns.map { |column| column.size }, shown, rest.size], :columns => columns, :details => details, :rest => rest, :width => width }
        end

        # Puts lines into columns: with :columns => :room split evenly, else each column filled before
        # the next.
        #
        # @param all [Array<Hash>] The lines.
        # @param count [Integer] The most columns.
        # @param width [Integer, nil] The room's width.
        # @param height [Integer, nil] The room's height, nil for room for everything.
        # @param details [Boolean, Hash] Which details show, see detailed?.
        # @return [Array<Array>, nil] Per column each line with its top and height; nil when they do not fit.
        def fill(all, count, width, height, details)
          return flow(all, count, width, height, details) if @options[:span] || @options[:columns] != :room || count < 2

          heights = all.map { |entry| entry_height(entry, detailed?(entry, details) ? column_width(count, width) - text_left : nil) }
          lines = heights.inject(0) { |sum, tall| sum + tall }
          total = lines + all.count { |entry| entry[:first] } * UI.whole(@options[:group_gap])
          least = [lines / count, heights.max.to_i].max
          least.upto(height ? [height, total].min : total) do |limit|
            columns = flow(all, count, width, limit, details, heights)
            return columns if columns
          end
          nil
        end

        # Puts lines into columns, each under the one before and a group's first line a group gap
        # lower, a line that does not fit at the bottom starting the next column.
        #
        # @param all [Array<Hash>] The lines.
        # @param count [Integer] The most columns.
        # @param width [Integer, nil] The room's width.
        # @param height [Integer, nil] The room's height, nil for room for everything.
        # @param details [Boolean, Hash] Which details show, see detailed?.
        # @param heights [Array<Integer>, nil] Each line's height, nil to work them out.
        # @return [Array<Array>, nil] Per column each line with its top and height; nil when they do not fit.
        def flow(all, count, width, height, details, heights = nil)
          return flow_rows(all, count, width, height, details) if @options[:span] && count > 1

          columns = [[]]
          top = 0
          text_width = column_width(count, width) - text_left
          all.each_with_index do |entry, place|
            tall = heights ? heights[place] : entry_height(entry, detailed?(entry, details) ? text_width : nil)
            gap = entry[:first] && top > 0 ? UI.whole(@options[:group_gap]) : 0
            if height && top + gap + tall > height
              return nil if columns.size >= count || tall > height

              columns << []
              top = 0
              gap = 0
            end
            columns.last << [entry, top + gap, tall]
            top += gap + tall
          end
          columns
        end

        # Puts lines across the columns row by row, as :span does: a line too wide for a column takes
        # a whole row, a short one the first free cell since its group began, and the row that tells
        # the lines left out the last row's free cell or a row of its own. A row is as high as its
        # highest line, a group's first row a group gap lower.
        #
        # @param all [Array<Hash>] The lines.
        # @param count [Integer] The columns.
        # @param width [Integer, nil] The room's width.
        # @param height [Integer, nil] The room's height, nil for room for everything.
        # @param details [Boolean, Hash] Which details show, see detailed?.
        # @return [Array<Array>, nil] Per column each line with its top, height and the columns it
        #   spans; nil when they do not fit.
        def flow_rows(all, count, width, height, details)
          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          room = column_width(count, width) - text_left
          rows = []
          group = 0
          all.each do |entry|
            group = rows.size if entry[:first]
            span = line_width(bitmap, entry) > room ? count : 1
            free = entry[:rest] ? rows.last(1) : rows[group..-1]
            row = span == 1 ? free.find { |candidate| candidate[:used] < count } : nil
            unless row
              row = { :cells => [], :used => 0, :gap => entry[:first] && !rows.empty? ? UI.whole(@options[:group_gap]) : 0 }
              rows << row
            end
            row[:cells] << [entry, row[:used], span]
            row[:used] += span
          end
          stack_rows(rows, count, width, height, details)
        end

        # Gives the rows of flow_rows their tops, each under the one before.
        #
        # @param rows [Array<Hash>] The rows: their :cells (each line with its column and span) and :gap.
        # @param count [Integer] The columns.
        # @param width [Integer, nil] The room's width.
        # @param height [Integer, nil] The room's height, nil for room for everything.
        # @param details [Boolean, Hash] Which details show, see detailed?.
        # @return [Array<Array>, nil] See flow_rows.
        def stack_rows(rows, count, width, height, details)
          columns = Array.new(count) { [] }
          top = 0
          rows.each do |row|
            cells = row[:cells].map do |entry, column, span|
              [entry, column, span, entry_height(entry, detailed?(entry, details) ? span_width(count, width, span) - text_left : nil)]
            end
            tall = cells.map { |cell| cell[3] }.max
            top += row[:gap]
            return nil if height && top + tall > height

            cells.each { |entry, column, span, own| columns[column] << [entry, top, own, span] }
            top += tall
          end
          columns
        end

        # Tells whether every line fits a column's width unsqueezed.
        #
        # @param all [Array<Hash>] The lines.
        # @param count [Integer] The columns.
        # @param width [Integer, nil] The room's width, nil before it has one.
        # @return [Boolean] Whether they do.
        def fit_width?(all, count, width)
          return true unless width

          room = column_width(count, width) - text_left
          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          all.all? { |entry| line_width(bitmap, entry) <= room }
        end

        # Tells the width its lines take unsqueezed and their details unwrapped, past the gutter, in as
        # many columns as a count of :columns names.
        #
        # @return [Integer] The pixels.
        def natural_width
          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          details = UI.font_bitmap(UI.font_px(detail_font))
          widest = entries.map do |entry|
            indent = entry[:icon] || entry[:item] ? ICON_STEP : 0
            detail = entry[:detail] ? indent + UI.text_width(details, plain(entry[:detail])) + OUTLINE : 0
            [line_width(bitmap, entry), detail].max
          end.max.to_i
          count = @options[:columns].is_a?(Integer) ? column_count : 1
          count * (text_left + widest) + (count - 1) * UI.whole(@options[:column_gap])
        end

        # Tells the width a line draws in, its icons and its outline with it.
        #
        # @param bitmap [Bitmap] What measures in the lines' font.
        # @param entry [Hash] The line.
        # @return [Integer] The pixels.
        def line_width(bitmap, entry)
          text = entry[:item] ? Game.item_name(entry[:item]) : entry[:text].to_s
          text = Escapes.convert(text) if @options[:escapes] && entry[:item].nil?
          icons = text.scan(Label::ICON_CODE).size + (entry[:icon] || entry[:item] ? 1 : 0)
          UI.text_width(bitmap, text.gsub(Escapes::CODE, "")) + icons * ICON_STEP + OUTLINE + (entry[:accent] ? ACCENT + ACCENT_GAP : 0)
        end

        # Adds the labels of one line: its key stop with :cursor, its group's label in the gutter, the
        # line, and its detail, kept for pulse; the labels over a key stop leave the pointer to it.
        #
        # @param entry [Hash] The line.
        # @param left [Integer] Its column's left.
        # @param top [Integer] Its top.
        # @param height [Integer] Its height with its detail.
        # @param width [Integer] Its column's width.
        # @param plan [Hash] The plan, see plan_for.
        def add_entry(entry, left, top, height, width, plan)
          sized = !plan[:width].nil?
          row = line_height(entry)
          faint = entry[:faint] ? true : false
          shown_detail = detailed?(entry, plan[:details]) && entry[:detail]
          tooltip = entry_tooltip(entry, shown_detail)
          stop = @options[:cursor] && !entry[:rest] && !entry[:none] ? true : false
          parts = []
          parts << add_stop(entry, tooltip, [left + text_left, top], [sized ? width - text_left : nil, height]) if stop
          if entry[:label] && titled?
            parts << add(Label.new(:text => entry[:label], :font_size => @options[:font_size], :color => entry[:label_color] || :system, :faint => faint,
                                   :squeeze => true, :row_height => row, :at => [left, top], :size => [UI.whole(@options[:gutter]), row],
                                   :visible => sized, :mouse => !stop))
          end
          accent = entry[:accent] ? ACCENT + ACCENT_GAP : 0
          @accents << [left + text_left, top, row, entry] if entry[:accent]
          label = add(Label.new(:text => entry[:text].to_s, :item => entry[:item], :icon => entry[:icon], :color => entry[:color] || line_color(entry),
                                :opacity => entry[:opacity], :tooltip => stop ? nil : tooltip, :font_size => @options[:font_size], :escapes => @options[:escapes] && entry[:item].nil?,
                                :squeeze => @options[:squeeze], :faint => faint, :row_height => row, :at => [left + text_left + accent, top],
                                :size => [sized ? width - text_left - accent : nil, row], :visible => sized, :mouse => !stop))
          parts << label
          label.on(:click) { emit(:more, entry[:rest].map { |line| line[:text] }) } if entry[:rest]
          if shown_detail
            indent = text_left + (entry[:icon] || entry[:item] ? ICON_STEP : 0)
            parts << add(Label.new(:text => entry[:detail].to_s, :font_size => detail_font, :escapes => @options[:escapes], :wrap => true, :faint => faint,
                                   :color => @options[:color], :row_height => detail_row_height, :at => [left + indent, top + row],
                                   :size => [sized ? width - indent : nil, height - row], :visible => sized, :mouse => !stop))
          end
          return if entry[:rest]

          place = entries.index { |each| each.equal?(entry) }
          @parts[place] = parts
          @labels[place] = label
        end

        # Tells a line's tooltip: its own with :note at its end, else its detail while that does not
        # show under it; a block of its own then gets the detail added at the end of its box.
        #
        # @param entry [Hash] The line.
        # @param shown_detail [Boolean] Whether its detail shows under it.
        # @return [String, Proc, nil] The tooltip.
        def entry_tooltip(entry, shown_detail)
          hidden = entry[:detail] && !shown_detail ? plain(entry[:detail]) : nil
          own = noted(entry[:tip].nil? ? entry[:tooltip] : tip_of(entry[:tip]))
          return own || hidden unless own.respond_to?(:call) && hidden

          lambda do |box|
            own.call(box)
            box.add_label(hidden, :font_size => :small, :wrap => true)
          end
        end

        # Tells the tooltip a line's :tip stands for: a block that has :tips fill the box, read as the
        # tooltip opens.
        #
        # @param key [Integer] The tip's number.
        # @return [Proc] The block.
        def tip_of(key)
          lambda { |box| @options[:tips].call(key, box) if @options[:tips] }
        end

        # Tells a line's own tooltip with :note, a block that fills the end of a tooltip's box, at its
        # end; a text becomes the first line of the box.
        #
        # @param tooltip [String, Proc, nil] The line's own tooltip.
        # @return [String, Proc, nil] The tooltip.
        def noted(tooltip)
          note = @options[:note]
          return tooltip unless note && !tooltip.to_s.empty?

          lambda do |box|
            tooltip.respond_to?(:call) ? tooltip.call(box) : box.add_label(tooltip.to_s, :font_size => :small, :wrap => true)
            note.call(box)
          end
        end

        # Adds the key stop of a line under its labels: a flat button as large as the line with its
        # detail, which draws the cursor's plate while it has the focus, moves the cursor there and,
        # while a block waits for submit, tells it on a click or confirm.
        #
        # It shows before the lines have a place, unlike their labels, so the focus a closing dialog
        # gives back finds it as soon as the lines are made anew.
        #
        # @param entry [Hash] The line.
        # @param tooltip [String, nil] The line's tooltip.
        # @param at [Array<Integer>] Its left and top.
        # @param size [Array<Integer, nil>] Its width, nil before the lines have a place, and height.
        # @return [Button] The key stop.
        def add_stop(entry, tooltip, at, size)
          place = entries.index { |each| each.equal?(entry) }
          key = @options[:id].nil? ? "lines#{object_id}:#{place}" : "#{@options[:id]}:#{place}"
          stop = add(Button.new(:flat => true, :id => key, :tooltip => tooltip, :at => at, :size => size))
          stop.on(:focus) { cursor_moved(place) }
          stop.on(:click) { emit(:submit, entry, place) } if listens?(:submit)
          stop
        end

        # Follows the focus onto a line: the cursor goes there, the detail shown follows, and change
        # tells it when it is another line.
        #
        # @param place [Integer] The line's place among the lines.
        def cursor_moved(place)
          return if place == index

          @options[:index] = place
          lay
          emit(:change, entries[place], place)
        end

        # Tells the font size of the details: :detail_size, else the lines'.
        #
        # @return [Symbol, Integer] The size.
        def detail_font
          @options[:detail_size] || @options[:font_size]
        end

        # Tells the height of a detail's rows: :detail_height, else :row_height.
        #
        # @return [Integer] The pixels.
        def detail_row_height
          UI.whole(@options[:detail_height] || @options[:row_height])
        end

        # Tells the color of a line without one of its own: :color, except for an item's line, whose
        # name keeps the game's color for it.
        #
        # @param entry [Hash] The line.
        # @return [Symbol, Integer, Color, nil] The color, nil for its label's own.
        def line_color(entry)
          entry[:item] ? nil : @options[:color]
        end

        # Turns the lines and groups into lines alone, sorted by :sort, each knowing its group's label
        # when it is a group's first; kept until the lines or their look change. No lines at all are
        # the dim line of :empty_text, if it has one.
        #
        # @return [Array<Hash>] The lines.
        def entries
          if Array(@options[:lines]).empty? && !@options[:empty_text].nil?
            return @entries ||= [{ :text => @options[:empty_text].to_s, :color => :dim, :none => true }]
          end

          @entries ||= Lines.sorted(@options[:lines], @options[:sort]).map do |part|
            group = part.is_a?(Array) ? { :label => part[0], :lines => part[1] } : part
            next [line_of(part)] unless group.is_a?(Hash) && group.key?(:lines)

            Array(group[:lines]).each_with_index.map do |line, place|
              entry = line_of(line)
              entry[:faint] = true if group[:faint]
              entry.merge!(:first => true, :label => group[:label], :label_color => group[:color]) if place == 0
              entry
            end
          end.flatten
        end

        # Reads one line.
        #
        # @param line [String, Hash] The line.
        # @return [Hash] The line as a Hash.
        def line_of(line)
          line.is_a?(Hash) ? line.dup : { :text => line.to_s }
        end

        # Makes the row that tells the lines left out, with them as its tooltip.
        #
        # @param rest [Array<Hash>] The lines left out.
        # @return [Hash] The row.
        def more_entry(rest)
          texts = rest.map { |line| line[:item] ? Game.item_name(line[:item]) : plain(line[:text]) }
          { :text => format(@options[:more_text].to_s, rest.size), :color => @options[:more_color], :tooltip => texts.join("\n"), :rest => rest }
        end

        # Tells how high a line is with its detail.
        #
        # @param entry [Hash] The line.
        # @param width [Integer, nil] The room of its text, nil to leave its detail out.
        # @return [Integer] The pixels.
        def entry_height(entry, width)
          tall = line_height(entry)
          return tall unless width && entry[:detail]

          indent = entry[:icon] || entry[:item] ? ICON_STEP : 0
          tall + detail_rows(entry[:detail].to_s, [width - indent, 1].max) * detail_row_height
        end

        # Tells the height of a line's own row: :row_height, an icon's when it draws one.
        #
        # @param entry [Hash] The line.
        # @return [Integer] The pixels.
        def line_height(entry)
          iconed = entry[:icon] || entry[:item] || (@options[:escapes] && Escapes.convert(entry[:text].to_s) =~ Label::ICON_CODE)
          [UI.whole(@options[:row_height]), iconed ? ICON_SIZE : 1].max
        end

        # Counts the rows a detail wraps onto.
        #
        # @param text [String] The detail.
        # @param width [Integer] Its width.
        # @return [Integer] The rows, at least one.
        def detail_rows(text, width)
          measure = UI.font_bitmap(UI.font_px(detail_font))
          lines = @options[:escapes] ? Escapes.runs(measure, text, width) : nil
          lines = UI.wrap(measure, plain(text), width) unless lines.is_a?(Array)
          [lines.size, 1].max
        end

        # Takes the game's escape codes out of a text.
        #
        # @param text [String] The text.
        # @return [String] The text without them.
        def plain(text)
          @options[:escapes] ? Escapes.convert(text.to_s).gsub(Escapes::CODE, "") : text.to_s
        end

        # Tells how many columns it may take when :columns is a count.
        #
        # @return [Integer] At least one.
        def column_count
          [@options[:columns].to_i, 1].max
        end

        # Tells a column's width.
        #
        # @param count [Integer] The columns.
        # @param width [Integer, nil] The room's width, nil before it has one.
        # @return [Integer] The pixels; a column with room for any line before it has a place.
        def column_width(count, width)
          return 10_000 unless width

          [(width - (count - 1) * UI.whole(@options[:column_gap])) / count, 1].max
        end

        # Tells the width of a line that spans columns, the gaps between them with it.
        #
        # @param count [Integer] The columns.
        # @param width [Integer, nil] The room's width, nil before it has one.
        # @param span [Integer] The columns it spans.
        # @return [Integer] The pixels.
        def span_width(count, width, span)
          column_width(count, width) * span + (span - 1) * UI.whole(@options[:column_gap])
        end

        # Tells whether the groups show their labels: with :titles and a gutter.
        #
        # @return [Boolean] Whether they do.
        def titled?
          @options[:titles] && UI.whole(@options[:gutter]) > 0 ? true : false
        end

        # Tells where the lines start in a column: past the gutter when the groups show their labels.
        #
        # @return [Integer] The pixels.
        def text_left
          titled? ? UI.whole(@options[:gutter]) + GUTTER_GAP : 0
        end

        # Tells its width inside its padding.
        #
        # @return [Integer, nil] The pixels, nil before it has a place.
        def inner_width
          return nil unless @rect

          _top, right, _bottom, left = padding_sides
          [@rect.width - left - right, 1].max
        end

        # Tells its height inside its padding.
        #
        # @return [Integer, nil] The pixels, nil before it has a place.
        def inner_height
          return nil unless @rect

          top, _right, bottom, _left = padding_sides
          [@rect.height - top - bottom, 0].max
        end
      end
    end

    Engine::Container.adds(:lines) { |lines, *rest| Engine::Lines.new((rest[0] || {}).merge(:lines => lines)) }
  end
end
