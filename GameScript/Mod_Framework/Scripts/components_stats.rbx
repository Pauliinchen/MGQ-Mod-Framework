#----------------------------------------------------------------
#  components_stats.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Let a bar draw its border in a color of its own, or in a shade of its fill
#                            - Drew a bar's border and well by its border and background, and dropped :framed for a border two pixels wide
#                            - Let a divider's padding replace the room at either side of its line
#      Paulinchen  2026-11-07: Wrote a bar's texts in the plain text color unless it has contrast
#                            - Drained a bar's fill at the trail's pace as it falls while animations run
#                            - Wrote a bar's text over its fill and over its well each in the text that contrasts with it
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A bar filled by a rate, in one color or running between two, with a text in its middle.
      #
      # Besides its centered :text (an Array: the first that fits shows) it takes a :label at its
      # left and a :value at its right inside the bar, in :font_size, each in the plain text color or
      # under contrast in the text that contrasts with the part of the bar under it. Without :colors it fills in the theme's primary
      # color. Its fill drains toward a lower rate at the trail's pace while animations run, and a
      # rise shows at once. :trail shows what the rate lost in a darker shade that stays two seconds
      # of real time (a number of seconds for :trail holds that long) and then drains toward the
      # rate; :vertical runs its :colors from the top to the bottom, two or three of them. Its
      # :border is the bar's edge, the theme's by default, :shade a darker shade of its first color as
      # it stands, and its :background the bar's well. :indeterminate shows no rate but a stripe that
      # sweeps along it, for a wait whose length nobody knows; it stands still in the middle while
      # animations are off.
      class Gauge < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "gauge"

        # Its height without a text.
        BAR = 12

        # Its width before its parent stretches it.
        MIN_WIDTH = 96

        # Tells the defaults of the options: empty, in the theme's primary color, without a text.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:rate => 0, :colors => nil, :text => nil, :label => nil, :value => nil, :font_size => :small, :trail => false, :vertical => false,
                      :indeterminate => false)
        end

        # The frames the stripe of an indeterminate gauge takes to sweep along it.
        SWEEP = 90

        # The frames between two drawings of the sweeping stripe.
        SWEEP_STEP = 2

        # The share of the bar the sweeping stripe takes.
        STRIPE = 0.3

        # Where the stripe starts while animations are off, a share of the bar.
        STRIPE_AT_REST = 0.35

        # The share of the way to the rate a trail or a falling fill drains each second.
        DRAIN = 7.2

        # The least a trail or a falling fill drains each second, of the whole bar.
        LEAST_DRAIN = 0.12

        # The seconds a loss stays in the trail before it drains, unless :trail names others.
        TRAIL_HOLD = 2.0

        # Tells which properties of C#'s tree each option sets: a text makes it higher.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:text => ["measured"], :label => ["measured"], :value => ["measured"], :font_size => ["measured"])
        end

        options :colors, :text, :label, :value, :font_size, :trail, :vertical, :indeterminate

        # Tells how full it is.
        #
        # @return [Numeric] From 0 to 1.
        def rate
          @options[:rate]
        end

        # Fills it to a rate: while animations run the fill drains toward a lower rate from where it
        # stands, a rise shows at once; with :trail what it lost shows in a darker shade, stays for
        # the seconds of the trail's hold and then drains toward it.
        #
        # @param value [Numeric] From 0 to 1.
        def rate=(value)
          before = @options[:rate].to_f
          if value.to_f < before
            now = Clock.seconds
            @fill ||= before if Animations.on?
            if @options[:trail]
              @trail = [@trail || before, before].max
              @held = (@held || []) + [[now + trail_hold, before]]
            end
            @drained_at ||= now if @fill || @trail
          end
          @fill = nil if @fill && value.to_f >= @fill
          @trail = @held = nil if @trail && value.to_f >= @trail
          @drained_at = nil unless @fill || @trail
          Tree.ticking(self, true) if @fill || @trail
          set_option(:rate, value)
        end

        # Moves the falling fill and the trail on by the seconds of the clock since the last frame:
        # the fill drains toward the rate, at once while animations are off; the trail stays at the
        # most the rate was within the trail's hold, and drains toward that once it is higher; an
        # indeterminate gauge sweeps its stripe on instead. Called every frame while its fill falls,
        # it has a trail or it sweeps.
        #
        # @return [Boolean] Whether its fill still falls or it still has a trail, or still sweeps.
        def frame_tick
          return sweep if @options[:indeterminate]
          return false unless @fill || @trail

          now = Clock.seconds
          seconds = now - (@drained_at || now)
          @drained_at = now
          rate = UI.within(@options[:rate].to_f, 0.0, 1.0)
          drawn = [@fill, @trail]
          @fill = Animations.on? ? drained(@fill, rate, seconds) : rate if @fill
          if @trail
            @held = (@held || []).select { |ends, _share| ends > now }
            @trail = drained(@trail, ([rate] + @held.map { |_ends, share| share }).max, seconds)
          end
          redraw if [@fill, @trail] != drawn
          @fill = nil if @fill && @fill <= rate
          @trail = @held = nil if @trail && @trail <= rate
          @drained_at = nil unless @fill || @trail
          !(@fill || @trail).nil?
        end

        # Tells its size: a bar, high enough for its text when it has one.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          texts = Array(@options[:text]) + [@options[:label], @options[:value]]
          [MIN_WIDTH, texts.all? { |text| text.to_s.empty? } ? BAR : UI.line_height_of(@options[:font_size])]
        end

        # Draws the bar, its trail and its texts: the label at its left, the value at its right and
        # the first of its texts that fits between them in its middle.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, bottom, left = padding_sides
          width = [canvas.width - left - right, 2].max
          height = [canvas.height - top - bottom, 2].max
          rate = @options[:indeterminate] ? 0.0 : (@fill || @options[:rate]).to_f
          canvas.gauge(left, top, width, height, rate, :colors => @options[:colors], :trail => @trail, :vertical => @options[:vertical], :border => border_look,
                                                       :border_width => border_px, :well => @options[:background])
          draw_stripe(canvas, left, top, width, height) if @options[:indeterminate]
          size = UI.font_px(@options[:font_size])
          inset = Style::PAD
          label = @options[:label].to_s
          value = @options[:value].to_s
          edge = fill_edge(left, width, rate)
          unless label.empty?
            spot = (inset + canvas.text_width(label, size) / 2).to_f / width
            bar_text(canvas, [left + inset, top, width - 2 * inset, height], label, { :size => size }, rate, spot, edge)
          end
          unless value.empty?
            spot = (width - inset - canvas.text_width(value, size) / 2).to_f / width
            bar_text(canvas, [left + inset, top, width - 2 * inset, height], value, { :size => size, :align => :right }, rate, spot, edge)
          end
          sides = [label, value].map { |text| text.empty? ? 0 : canvas.text_width(text, size) + inset }.max
          room = width - 2 * (inset + sides)
          text = Array(@options[:text]).map { |each| each.to_s }.find { |each| canvas.text_width(each, size) <= room } || Array(@options[:text]).last.to_s
          bar_text(canvas, [left, top, width, height], text, { :size => size, :align => :center }, rate, 0.5, edge) unless text.empty?
        end

        private

        # Tells where the fill ends, as Canvas#gauge fills it inside its frame.
        #
        # @param left [Integer] The bar's left in the component.
        # @param width [Integer] Its width.
        # @param rate [Float] How full it is drawn, from 0 to 1.
        # @return [Integer] The column of the component the fill ends at.
        def fill_edge(left, width, rate)
          rim = border_px
          left + rim + (UI.within(rate.to_f, 0.0, 1.0) * (width - 2 * rim)).round
        end

        # Draws a text on the bar, cut to its box: the part over the fill in the text on the fill and
        # the rest in the text on the well; on a vertical bar all of it in the text on what lies under
        # a spot.
        #
        # @param canvas [Canvas] Where it draws.
        # @param box [Array<Integer>] The text's box: left, top, width and height in the component.
        # @param text [String] The text.
        # @param look [Hash] Its :size and :align, see Canvas#text.
        # @param rate [Float] How full the bar is drawn, from 0 to 1.
        # @param spot [Float] The spot on a vertical bar, a share of its width.
        # @param edge [Integer] The column the fill ends at, see fill_edge.
        def bar_text(canvas, box, text, look, rate, spot, edge)
          x, y, width, height = box
          look = look.merge(:cut => true)
          return canvas.text(x, y, width, height, text, look.merge(:color => text_over(rate, spot))) if @options[:vertical]

          canvas.text(x, y, width, height, text, look.merge(:color => text_over(rate, 0.0), :span => [0, edge]))
          canvas.text(x, y, width, height, text, look.merge(:color => text_over(rate, 1.0), :span => [edge, canvas.width]))
        end

        # Tells the text on the bar at a spot (Component#text_on): on its first color where the rate
        # fills it, else on its well.
        #
        # @param rate [Float] How full it is drawn, from 0 to 1.
        # @param spot [Float] The spot, a share of its width.
        # @return [Symbol, Color] The color.
        def text_over(rate, spot)
          text_on(spot < rate ? Array(@options[:colors] || [:primary]).first : :well)
        end

        # Draws the stripe of an indeterminate gauge where its sweep stands now, inside its frame, and
        # has the frames tell it while animations run.
        #
        # @param canvas [Canvas] Where it draws.
        # @param left [Integer] The bar's left.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        def draw_stripe(canvas, left, top, width, height)
          moving = Animations.on?
          Tree.ticking(self, true) if moving
          rim = border_px
          room = width - 2 * rim
          start = moving ? (Key.frame % SWEEP).to_f / SWEEP * (1 + STRIPE) - STRIPE : STRIPE_AT_REST
          from = (UI.within(start, 0.0, 1.0) * room).round
          to = (UI.within(start + STRIPE, 0.0, 1.0) * room).round
          canvas.fill(left + rim + from, top + rim, to - from, height - 2 * rim, Array(@options[:colors] || [:primary]).first) if to > from
        end

        # Draws the stripe of an indeterminate gauge anew every SWEEP_STEP frames while animations
        # run.
        #
        # @return [Boolean] Whether it still sweeps.
        def sweep
          return false unless Animations.on?

          redraw if (Key.frame % SWEEP_STEP).zero?
          true
        end

        # Tells where a share of the bar stands after draining toward a lower target for some seconds,
        # by DRAIN of the way there each second and at least LEAST_DRAIN of the bar.
        #
        # @param share [Float] Where it stands, from 0 to 1.
        # @param target [Float] Where it drains to.
        # @param seconds [Float] The seconds it drains.
        # @return [Float] Where it stands then, never below the target.
        def drained(share, target, seconds)
          return share unless share > target && seconds > 0

          gap = share - target
          step = [gap * [DRAIN * seconds, 1.0].min, LEAST_DRAIN * seconds].max
          step >= gap ? target : share - step
        end

        # Tells the seconds a loss stays in the trail before it drains: the number :trail names, else
        # TRAIL_HOLD.
        #
        # @return [Float] The seconds.
        def trail_hold
          @options[:trail].is_a?(Numeric) ? [@options[:trail].to_f, 0.0].max : TRAIL_HOLD
        end

        # Tells its own border: the theme's edge.
        #
        # @return [Symbol] :theme.
        def own_border
          :theme
        end

        # Tells the room its border takes: none, since it draws on the bar, inside the bar's size.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def border_room
          NO_ROOM
        end

        # Tells that it draws its well itself, from its background.
        #
        # @return [Boolean] Always true.
        def own_back?
          true
        end

        # Tells that it draws its border itself, on the bar.
        #
        # @return [Boolean] Always true.
        def own_edge?
          true
        end
      end

      # A line across its parent's stack, horizontal in a column and vertical in a row, :thickness
      # pixels thick in its :color, the theme's edge color unless told.
      class Divider < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "divider"

        # The ways it runs.
        DIRECTIONS = [:horizontal, :vertical]

        # Room at either side of the line.
        ROOM = 2

        # Tells the defaults of the options: horizontal, a pixel thick, in the edge color.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:direction => :horizontal, :color => nil, :thickness => 1)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:direction => ["measured", "padding"], :thickness => ["measured"])
        end

        options :direction, :color, :thickness

        # Tells its size: its thickness, as long as its parent gives it.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          vertical? ? [thickness, 0] : [0, thickness]
        end

        # Draws the line in its color.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, bottom, left = padding_sides
          look = @options[:color] || :edge
          if vertical?
            canvas.fill(left, top, thickness, canvas.height - top - bottom, look)
          else
            canvas.fill(left, top, canvas.width - left - right, thickness, look)
          end
        end

        private

        # Tells how thick the line is.
        #
        # @return [Integer] The pixels, at least 1.
        def thickness
          [@options[:thickness].to_i, 1].max
        end

        # Tells whether it runs up and down.
        #
        # @return [Boolean] Whether it does.
        def vertical?
          UI.choice(@options[:direction], DIRECTIONS, :horizontal, "divider direction") == "vertical"
        end

        # Tells the room at either side of the line, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          vertical? ? [0, ROOM, 0, ROOM] : [ROOM, 0, ROOM, 0]
        end
      end

      # Name and value rows in one or more columns, as the status screen shows them; a row with a
      # :change shows the new value after an arrow, in the good color when it is higher and the bad
      # one when lower, as the equip screen compares them. A row's :icons sit between its name and its
      # value, as many as fit; its :color and :change_color draw its value and its change in a color
      # of their own, and :faint draws the whole row at half its opacity, as a stat that is not there.
      # A name is never cut while a value fits beside it: a value too wide is squeezed, then gives way
      # to the first of the row's :shorter texts (ever shorter texts of it, such as with fewer
      # decimals) that fits, and is cut only when none does.
      # :font_size draws and measures the rows in a smaller or larger font, on rows of :row_height,
      # which follows the font unless given and is never lower than an icon.
      #
      # With :against, the rows of an earlier reading or of another item, each value is judged against
      # the row of the same :key there (its :name without one) by its :number: higher in
      # :better_color, lower in :worse_color. A row the other reading lacks is judged against its
      # :base, what a reading without the stat stands for (0 unless given), so a penalty shows worse.
      # A :number is a number or several, such as a flat and a percent bonus, which are judged part by
      # part: better only when no part is lower, worse only when no part is higher. A stand-in row of
      # Stats.pair stands for its :base: it shows in :better_color when the other reading's stat is
      # worse than that, as a penalty given up, else in :worse_color, a stat lost; without :against
      # it is dim.
      #
      # With an :actor the rows are that character's stats (Game.stat_rows, with :params and :rates
      # when given): mark keeps the reading of now, refresh reads them anew and judges them against
      # the reading marked, if any, and unmark shows the values plain again; a mark not refreshed yet
      # stays. Another :actor shows that character's stats, plain and unmarked.
      class Stats < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "stats"

        # The arrow between a value and its change, as the game's equip screen draws it.
        ARROW = [0x2192].pack("U")

        # Room between a name and its value.
        NAME_GAP = 12

        # Room between a name and the icons after it.
        ICONS_GAP = 4

        # Room around the arrow.
        ARROW_GAP = 4

        # Room between two columns with no :column_gap.
        COLUMN_GAP = 16

        # The value of a stand-in row, for a stat one reading lacks.
        MISSING = [0x2014].pack("U")

        # Tells the defaults of the options: no rows, one column, judged against nothing.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:rows => [], :columns => 1, :font_size => :normal, :row_height => nil, :column_gap => nil, :against => nil,
                      :better_color => :good, :worse_color => :bad, :actor => nil, :params => nil, :rates => nil)
        end

        # Sets the rows of two readings side by side, such as two items or a character before and
        # after a change: both in one order, and each row one reading lacks a faint stand-in with the
        # other's name and :missing_text, so the rows line up.
        #
        # @param first [Array<Hash>] The rows of one reading.
        # @param second [Array<Hash>] The rows of the other.
        # @param options [Hash] :order (a block of a row's key that tells where it sorts; without it the
        #   first's rows come first, then the second's the first lacks) and :missing_text (MISSING).
        # @return [Array<Array<Hash>>] The rows of the first and of the second.
        def self.pair(first, second, options = {})
          all = Array(first) + Array(second)
          keys = all.map { |row| key_of(row) }.uniq
          order = options[:order]
          keys = keys.each_with_index.sort_by { |key, place| [order.call(key), place] }.map { |key, _place| key } if order
          [Array(first), Array(second)].map do |rows|
            keys.map do |key|
              rows.find { |row| key_of(row) == key } || stand_in(all.find { |row| key_of(row) == key }, options.fetch(:missing_text, MISSING))
            end
          end
        end

        # Tells what pairs a row with the same stat of another reading.
        #
        # @param row [Hash] The row.
        # @return [Object] Its :key, its :name without one.
        def self.key_of(row)
          row.key?(:key) ? row[:key] : row[:name]
        end

        # Makes the stand-in of a row another reading lacks, with the other row's :base.
        #
        # @param row [Hash] The other reading's row.
        # @param text [String] Its value.
        # @return [Hash] The stand-in.
        def self.stand_in(row, text)
          stand_in = { :key => key_of(row), :name => row[:name], :value => text, :faint => true, :missing => true }
          stand_in[:base] = row[:base] if row.key?(:base)
          stand_in
        end

        # Tells which properties of C#'s tree each option sets: other rows or another size measure
        # anew.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:rows => ["measured"], :columns => ["measured"], :font_size => ["measured"], :row_height => ["measured"], :column_gap => ["measured"])
        end

        options :rows, :columns, :font_size, :row_height, :column_gap, :against, :better_color, :worse_color, :actor, :params, :rates

        # Makes the stats, the character's stats as its rows with an :actor.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @mark = nil
          @options[:rows] = reading if @options[:actor]
        end

        # Keeps the character's stats of now, so the next refresh judges against them.
        #
        # @return [Stats] Itself.
        def mark
          @mark = reading if @options[:actor]
          self
        end

        # Reads the character's stats anew and judges them against the reading marked, if any, which
        # is then used up; without a mark they show plain.
        #
        # @return [Stats] Itself.
        def refresh
          return self unless @options[:actor]

          self.rows = reading
          self.against = @mark
          @mark = nil
          self
        end

        # Shows the values plain again; a mark not refreshed yet stays.
        #
        # @return [Stats] Itself.
        def unmark
          self.against = nil unless @options[:against].nil?
          self
        end

        # Tells its size: its columns of rows side by side.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          count = column_count
          lines = (Array(@options[:rows]).size + count - 1) / count
          [count * cell_width(widths(UI.font_bitmap(text_px))) + (count - 1) * column_gap, lines * row_height]
        end

        # Draws each row in its column: its icon, name and icons at the left, its value and change at
        # the right.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, _bottom, left = padding_sides
          count = column_count
          found = widths(UI.font_bitmap(text_px))
          cell = [(canvas.width - left - right - (count - 1) * column_gap) / count, 1].max
          Array(@options[:rows]).each_with_index do |row, place|
            x = left + place % count * (cell + column_gap)
            draw_row(canvas, row, x, top + place / count * row_height, cell, found)
          end
        end

        private

        # Follows a changed option: another character's stats show plain, the mark dropped.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless name == :actor && @options[:actor]

          @mark = nil
          self.against = nil
          self.rows = reading
        end

        # Reads the character's stats as rows, with :params and :rates when given.
        #
        # @return [Array<Hash>] The rows, see Game.stat_rows.
        def reading
          asked = {}
          [:params, :rates].each { |name| asked[name] = @options[name] unless @options[name].nil? }
          Game.stat_rows(@options[:actor], asked)
        end

        # Tells the pixels of the font its rows draw in.
        #
        # @return [Integer] The pixels.
        def text_px
          UI.font_px(@options[:font_size])
        end

        # Tells the height of a row: its :row_height, else its font's line (UI.line_height_of); an
        # icon's height at least once a row has one.
        #
        # @return [Integer] The pixels.
        def row_height
          height = @options[:row_height] ? UI.whole(@options[:row_height]) : UI.line_height_of(@options[:font_size])
          iconed = Array(@options[:rows]).any? { |row| row[:icon] || !Array(row[:icons]).empty? }
          [height, iconed ? ICON_SIZE : 1].max
        end

        # Tells the room between two columns.
        #
        # @return [Integer] The pixels.
        def column_gap
          @options[:column_gap].nil? ? COLUMN_GAP : UI.whole(@options[:column_gap])
        end

        # Tells how many columns the rows go in.
        #
        # @return [Integer] At least one.
        def column_count
          [@options[:columns].to_i, 1].max
        end

        # Measures the widest of each part of the rows.
        #
        # @param bitmap [Bitmap] What measures in the font the rows draw in.
        # @return [Hash] :icon (the room of an icon, 0 when no row has one), :name (with the icons
        #   after it), :value, :change (0 when no row has one) and :arrow.
        def widths(bitmap)
          rows = Array(@options[:rows])
          width = lambda { |text| text.nil? ? 0 : UI.text_width(bitmap, text.to_s) }
          widest = lambda { |key| rows.map { |row| width.call(row[key]) }.max || 0 }
          { :icon => rows.any? { |row| row[:icon] } ? ICON_STEP : 0, :name => rows.map { |row| width.call(row[:name]) + icons_room(row) }.max || 0,
            :value => widest.call(:value), :change => widest.call(:change), :arrow => UI.text_width(bitmap, ARROW) }
        end

        # Tells the room a row's icons take after its name.
        #
        # @param row [Hash] The row.
        # @return [Integer] The pixels, 0 for none.
        def icons_room(row)
          count = Array(row[:icons]).size
          count > 0 ? ICONS_GAP + count * ICON_STEP - (ICON_STEP - ICON_SIZE) : 0
        end

        # Tells the width a row needs.
        #
        # @param widths [Hash] The widest parts, see widths.
        # @return [Integer] The pixels.
        def cell_width(widths)
          change = widths[:change] > 0 ? 2 * ARROW_GAP + widths[:arrow] + widths[:change] : 0
          widths[:icon] + widths[:name] + NAME_GAP + widths[:value] + change
        end

        # Draws one row: its value right aligned with the others, as fitted_value picks it, its name in
        # the room the value leaves. Both measure on the picture they draw on, whose font may differ
        # from the one the stats measured their size in.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash] The row: :name, :value, :shorter, :change, :icon, :icons, :color,
        #   :change_color, :faint.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param widths [Hash] The widest parts, see widths.
        def draw_row(canvas, row, x, y, width, widths)
          right = x + width
          look = { :size => text_px, :opacity => row[:faint] ? Label::FAINT : nil }
          height = row_height
          if widths[:change] > 0
            change_left = right - widths[:change]
            unless row[:change].nil?
              canvas.text(change_left, y, widths[:change], height, row[:change].to_s, look.merge(:color => row[:change_color] || change_color(row), :align => :right))
              canvas.text(change_left - ARROW_GAP - widths[:arrow], y, widths[:arrow], height, ARROW, look.merge(:color => :system))
            end
            right = change_left - 2 * ARROW_GAP - widths[:arrow]
          end
          canvas.icon(row[:icon], x, y + (height - ICON_SIZE) / 2, :opacity => look[:opacity]) if row[:icon]
          name_left = x + widths[:icon]
          name = row[:name].to_s
          name_width = canvas.text_width(name, text_px)
          value, value_room = fitted_value(canvas, row, right - name_left, name_width)
          canvas.text(right - value_room, y, value_room, height, value, look.merge(:color => value_color(row), :align => :right, :squeeze => true))
          room = value.empty? ? right - name_left : [right - name_left - [canvas.text_width(value, text_px), value_room].min - ICONS_GAP, 1].max
          # Bitmap#draw_text squeezes a text into a box barely narrower than it draws, so a name that
          # fits draws in the room up to its value.
          canvas.text(name_left, y, room, height, name, look.merge(:color => :system, :cut => true))
          draw_icons(canvas, Array(row[:icons]), name_left + [name_width, room].min + ICONS_GAP, y, name_left + room)
        end

        # Picks the text of a row's value and the room it takes beside the whole name, at least
        # ICONS_GAP from it: the value, else the first of its :shorter texts, that fits drawn down to
        # Canvas::SQUEEZE of its width. The name gives up room only to the shortest of them.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash] The row.
        # @param width [Integer] The room of its name, its icons and its value.
        # @param name_width [Integer] Its name's width.
        # @return [Array] The text, the last one when none fits, and the width of its box.
        def fitted_value(canvas, row, width, name_width)
          texts = [row[:value].to_s] + Array(row[:shorter]).map { |text| text.to_s }
          return ["", 0] if texts[0].empty?

          least = (canvas.text_width(texts.last, text_px) * Canvas::SQUEEZE).ceil
          room = UI.within(width - name_width - ICONS_GAP, [least, 1].max, [width, 1].max)
          [texts.find { |text| canvas.text_width(text, text_px) * Canvas::SQUEEZE <= room } || texts.last, room]
        end

        # Draws a row's icons after its name, as many as fit before its value.
        #
        # @param canvas [Canvas] Where it draws.
        # @param icons [Array<Integer>] The icons.
        # @param x [Integer] The first icon's left.
        # @param y [Integer] The row's top.
        # @param right [Integer] Where the room for them ends.
        def draw_icons(canvas, icons, x, y, right)
          icons.each do |icon|
            break if x + ICON_SIZE > right

            canvas.icon(icon, x, y + (row_height - ICON_SIZE) / 2)
            x += ICON_STEP
          end
        end

        # Tells the color of a row's value: its own, else as :against judges it.
        #
        # @param row [Hash] The row.
        # @return [Symbol, Integer, Color, nil] The color, nil for the plain one.
        def value_color(row)
          return row[:color] if row[:color]
          return missing_color(row) if row[:missing]

          @options[:against] ? judged_color(row, other_row(row)) : nil
        end

        # Tells the color of a stand-in: dim without the other reading's stat; else, as the stat is
        # lost, the worse color unless its :base is better than the other reading's stat.
        #
        # @param row [Hash] The stand-in.
        # @return [Symbol, Integer, Color] :better_color, :worse_color or :dim.
        def missing_color(row)
          other = other_row(row)
          return :dim unless other

          compared(base_of(row), numbers(other)) == 1 ? @options[:better_color] : @options[:worse_color]
        end

        # Finds the row of the same stat in :against, a stand-in there counting as none.
        #
        # @param row [Hash] The row.
        # @return [Hash, nil] The row, nil for none.
        def other_row(row)
          key = Stats.key_of(row)
          Array(@options[:against]).find { |each| !each[:missing] && Stats.key_of(each) == key }
        end

        # Judges a row against the same stat of the other reading, or against its :base when the
        # other reading lacks the stat.
        #
        # @param row [Hash] The row.
        # @param other [Hash, nil] The other reading's row, nil when it lacks the stat.
        # @return [Symbol, Integer, Color, nil] :better_color, :worse_color, or nil for plain.
        def judged_color(row, other)
          sign = compared(numbers(row), other ? numbers(other) : base_of(row))
          sign == 1 ? @options[:better_color] : sign == -1 ? @options[:worse_color] : nil
        end

        # Compares two readings of a stat part by part, a missing part counting as 0.
        #
        # @param mine [Array<Numeric, nil>, nil] The parts of one.
        # @param theirs [Array<Numeric, nil>, nil] The parts of the other.
        # @return [Integer, nil] 1 when no part is lower and one higher, -1 the other way round, nil
        #   for parts that move both ways, none that moves, or a reading without a number.
        def compared(mine, theirs)
          return nil unless mine && theirs

          signs = (0...[mine.size, theirs.size].max).map { |part| mine[part].to_f <=> theirs[part].to_f }.reject { |sign| sign == 0 }.uniq
          signs.size == 1 ? signs[0] : nil
        end

        # Reads what a reading without a row's stat stands for: its :base.
        #
        # @param row [Hash] The row.
        # @return [Array<Numeric, nil>] The parts, 0 without a :base.
        def base_of(row)
          Array(row.fetch(:base, 0))
        end

        # Reads what a row is judged by: its :number, else its :value when that is a number.
        #
        # @param row [Hash] The row.
        # @return [Array<Numeric, nil>, nil] The parts, nil for a row that has no number.
        def numbers(row)
          parts = Array(row.key?(:number) ? row[:number] : row[:value])
          parts.all? { |part| part.nil? || part.is_a?(Numeric) } ? parts : nil
        end

        # Tells the color of a row's change: good when it is higher than the value, bad when lower.
        #
        # @param row [Hash] The row.
        # @return [Symbol] :good, :bad or :text.
        def change_color(row)
          value = row[:value]
          change = row[:change]
          return :text unless value.is_a?(Numeric) && change.is_a?(Numeric)

          change > value ? :good : change < value ? :bad : :text
        end
      end
    end

    Engine::Container.adds(:gauge) { |*args| Engine::Gauge.new(args[0] || {}) }
    Engine::Container.adds(:divider) { |*args| Engine::Divider.new(args[0] || {}) }
    Engine::Container.adds(:stats) { |*args| Engine::Stats.new(args[0] || {}) }
  end
end
