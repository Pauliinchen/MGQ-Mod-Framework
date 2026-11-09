#----------------------------------------------------------------
#  value_inputs.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Let the digits turn the items of a toggle group on and off with :number_keys
#                            - Named the colors of the color picker's swatches :swatch_colors, apart from the look's palette
#                            - Left the number rules of the slider and the rating to C#'s tree, which tells each new number
#                            - Added the toggle group, joined buttons the player turns on
#                            - Added the radio group, radios of which the player picks one
#                            - Added the color picker, swatches and sliders that pick a color
#                            - Added the rating, stars the player fills from the left
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A whole number the player slides between :min and :max, as MudSlider: a thin track filled in
      # its :color up to a round knob. C#'s tree owns the number's rules: LEFT and RIGHT step it by
      # :step while UP and DOWN move on, a click on the track sets the number at the pointer and a
      # held press drags the knob, and a number given in between goes to the nearest step within the
      # bounds; it tells each new number, which the slider takes and draws. With :show_value the
      # number stands at the track's right end.
      #
      # Events: change (the number).
      class Slider < Component
        # The component's kind in C#'s tree.
        KIND = "slider"

        # Its width before its parent stretches it, the number's room left out.
        WIDTH = 200

        # The track's thickness.
        TRACK = 4

        # The knob's radius.
        KNOB = 7

        # The radius of the light round the knob while it is focused or hovered.
        HALO = 11

        # Room between the track and the number at its right end.
        VALUE_GAP = 8

        # Tells the defaults of the options: 0 of 0 to 100 in steps of 1, without the number shown.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:value => 0, :min => 0, :max => 100, :step => 1, :show_value => false, :color => nil)
        end

        # Tells which properties of C#'s tree each option sets: the number, its bounds and its step,
        # and the track, which the padding and the number shown narrow.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:value => ["number"], :min => ["number_min", "track", "measured"], :max => ["number_max", "track", "measured"],
                      :step => ["number_step"], :show_value => ["track", "measured"], :padding => super[:padding] + ["track"])
        end

        options :min, :max, :step, :show_value, :color

        # Tells its number.
        #
        # @return [Integer] The number.
        def value
          @options[:value]
        end

        # Sets its number without telling a change; C#'s tree fits it to the bounds and steps.
        #
        # @param number [Numeric] The number.
        def value=(number)
          set_option(:value, number.to_i)
        end

        # Tells the properties C#'s tree picks its number by: the number, its bounds, its step and
        # the room left and right of its track.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          _top, right, _bottom, left = padding_sides
          super.update("number" => value, "number_min" => low, "number_max" => high, "number_step" => [@options[:step].to_i, 1].max,
                       "track" => [left + KNOB, right + KNOB + value_room])
        end

        # Takes an event of C#'s tree: a new number, as the player moved it or as it was fitted.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "number"

          @options[:value] = values[0].to_i
          redraw
          emit(:change, value)
        end

        # Tells its size: a line high, the track's width and the number's room.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          [WIDTH + value_room, LINE_HEIGHT]
        end

        # Draws the track, the part up to the knob in its color, the knob with its light while it is
        # focused or hovered, and the number at the right end.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, bottom, left = padding_sides
          start = left + KNOB
          length = [canvas.width - left - right - 2 * KNOB - value_room, 1].max
          middle = top + (canvas.height - top - bottom) / 2
          fill = @options[:color] || :primary
          knob = start + (rate * length).round
          canvas.fill(start, middle - TRACK / 2, length, TRACK, :well)
          canvas.fill(start, middle - TRACK / 2, knob - start, TRACK, fill)
          canvas.disc(knob, middle, HALO, :picked) if (focused? || hovered?) && enabled_here?
          canvas.disc(knob, middle, KNOB, fill)
          return unless @options[:show_value]

          canvas.text(left, top, canvas.width - left - right, canvas.height - top - bottom, value.to_s, :align => :right)
        end

        private

        # Tells the room the number takes at the right end, its longest text's.
        #
        # @return [Integer] The pixels, 0 without :show_value.
        def value_room
          return 0 unless @options[:show_value]

          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          [low, high].map { |number| UI.text_width(bitmap, number.to_s) }.max + Canvas::OUTLINE_ROOM + VALUE_GAP
        end

        # Tells how far along its bounds the number stands.
        #
        # @return [Float] From 0 to 1.
        def rate
          high > low ? UI.within((value - low).to_f / (high - low), 0.0, 1.0) : 0.0
        end

        # Tells the least number.
        #
        # @return [Integer] The number.
        def low
          @options[:min].to_i
        end

        # Tells the largest number.
        #
        # @return [Integer] The number.
        def high
          @options[:max].to_i
        end
      end

      # Stars the player fills from the left, as MudRating: :value of :max_value stars filled in its
      # :color, the rest in the theme's edge color. To C#'s tree it is a slider of one cell per star,
      # which owns its rules: LEFT and RIGHT take a star away and add one, a click fills up to the star
      # under the pointer and a click on the last filled star empties them all, and while the pointer
      # rests on it the tree tells the star under it, up to which the stars show filled. With
      # :read_only it only shows its stars, as a part without an action.
      #
      # Events: change (the stars filled).
      class Rating < Component
        # The component's kind in C#'s tree.
        KIND = "slider"

        # Room between two stars.
        GAP = 2

        # Room around the stars.
        PAD = 2

        # How far the inner corners of a star lie from its middle, a share of its outer corners'.
        INNER = 0.382

        # The rows of a star's shape by its side, made once each.
        @stars = {}

        # Hands out the shape of a five-pointed star of a side as rows of spans, its tip at the top.
        #
        # @param side [Integer] The side of the square it fills.
        # @return [Array<Array<Array<Integer>>>] The spans of each row, see Canvas#spans.
        def self.star(side)
          @stars[side] ||= begin
            outer = side / 2.0
            middle_y = outer + (outer - outer * Math.cos(Math::PI / 5)) / 2
            corners = (0...10).map do |index|
              angle = -Math::PI / 2 + index * Math::PI / 5
              reach = index.even? ? outer : outer * INNER
              [outer + reach * Math.cos(angle), middle_y + reach * Math.sin(angle)]
            end
            (0...side).map { |row| row_spans(corners, row + 0.5) }
          end
        end

        # Tells where a row crosses a closed shape, as spans of whole pixels.
        #
        # @param corners [Array<Array<Float>>] The shape's corners, in order.
        # @param y [Float] The row's middle.
        # @return [Array<Array<Integer>>] The spans, each [left, width].
        def self.row_spans(corners, y)
          crossings = []
          corners.each_with_index do |(x1, y1), index|
            x2, y2 = corners[(index + 1) % corners.size]
            next if (y1 <= y) == (y2 <= y)

            crossings << x1 + (y - y1) * (x2 - x1) / (y2 - y1)
          end
          crossings.sort.each_slice(2).map { |from, to| [from.round, (to - from).round] }.select { |_left, width| width > 0 }
        end
        private_class_method :row_spans

        # Tells the defaults of the options: no star filled of five, 24 pixels each.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:value => 0, :max_value => 5, :side => 24, :color => nil, :read_only => false)
        end

        # Tells which properties of C#'s tree each option sets: the stars filled, how many there are
        # and the cell of each, and more or larger stars make it wider.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:value => ["number"], :max_value => ["number_max", "measured"], :side => ["cells", "measured"])
        end

        options :max_value, :side, :color, :read_only

        # Tells how many stars are filled.
        #
        # @return [Integer] The stars.
        def value
          @options[:value]
        end

        # Fills a number of stars without telling a change; C#'s tree keeps it within 0 and :max_value.
        #
        # @param stars [Integer] The stars.
        def value=(stars)
          set_option(:value, stars.to_i)
        end

        # Tells the properties C#'s tree picks its stars by: the stars filled, from 0 to its stars in
        # steps of one, and the cell of each star from the left of its room.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          super.update("number" => value, "number_min" => 0, "number_max" => most, "number_step" => 1, "track" => [PAD, PAD], "cells" => side + GAP)
        end

        # Takes an event of C#'s tree: the stars filled, as the player filled them or as they were
        # fitted, and the star under the pointer, nil once it left them.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          case name
          when "number"
            @options[:value] = values[0].to_i
            redraw
            emit(:change, value)
          when "preview"
            @hover = values[0]
            redraw
          else super
          end
        end

        # Tells its size: its stars in a row.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          [2 * PAD + most * side + [most - 1, 0].max * GAP, side + 2 * PAD]
        end

        # Draws its plate while focused or hovered, then its stars: those filled, or up to the one
        # under the pointer, in its color and the rest in the edge color.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          canvas.fill(0, 0, canvas.width, canvas.height, focused? ? :picked : :tab) if (focused? || hovered?) && enabled_here? && !@options[:read_only]
          shape = Rating.star(side)
          filled = @hover || value
          top = (canvas.height - side) / 2
          most.times do |index|
            canvas.spans(PAD + index * (side + GAP), top, shape, index < filled ? (@options[:color] || :primary) : :edge)
          end
        end

        private

        # Tells how many stars it has.
        #
        # @return [Integer] The stars, at least 1.
        def most
          [@options[:max_value].to_i, 1].max
        end

        # Tells the side of a star.
        #
        # @return [Integer] The pixels.
        def side
          [@options[:side].to_i, 4].max
        end
      end

      # A color the player picks, as MudColorPicker: swatches of :swatch_colors that the arrows step over
      # and confirm or a click picks, the picked one framed; with :sliders three sliders of its red,
      # green and blue; and a swatch of the color with its "#RRGGBB" under them. Its value is that
      # "#RRGGBB", nil while none is picked.
      #
      # Events: change (the color as "#RRGGBB").
      class ColorPicker < Stack
        # The swatches in a row.
        COLUMNS = 8

        # The side of a swatch.
        SWATCH = 20

        # Room between two swatches.
        SWATCH_GAP = 2

        # The width of a slider's caption.
        CAPTION = 16

        # The captions of the sliders, red first.
        CHANNELS = ["R", "G", "B"]

        # Tells the defaults of the options: a column of the game's 32 text colors and the sliders,
        # nothing picked.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => Style::GAP, :value => nil, :swatch_colors => (0..31).to_a, :sliders => true)
        end

        # The colors of its swatches are :swatch_colors, as a reader named palette would hide the
        # palette of its look that a color name is found in.
        options :swatch_colors, :sliders

        # Makes the picker with its swatches, its sliders and its swatch of the color.
        #
        # @param options [Hash] :value, :swatch_colors, :sliders and the options of a container.
        def initialize(options = {})
          super
          @options[:value] = ColorPicker.hex(@options[:value])
          @grid = add(Grid.new(:columns => Array.new(COLUMNS, SWATCH), :gap => SWATCH_GAP, :align => :start))
          @sliders = CHANNELS.map do |caption|
            row = add(Stack.new(:layout => :row, :gap => Style::GAP))
            row.add(Label.new(:text => caption, :color => :system, :width => CAPTION))
            slider = row.add(Slider.new(:max => 255, :show_value => true, :grow => 1))
            slider.on(:change) { slid }
            slider
          end
          shown = add(Stack.new(:layout => :row, :gap => Style::GAP))
          @preview = shown.add(Swatch.new(:shown_only => true, :focusable => false, :mouse => false))
          @hex = shown.add(Label.new(:text => ""))
          fill_swatches
          show_value
        end

        # Tells a color as "#RRGGBB": a game text color by its index, a color name in the player's
        # look, "#RRGGBB" or [r, g, b].
        #
        # @param color [Integer, Symbol, String, Array, Color, nil] The color.
        # @param palette [Palette, nil] The look a color name is found in, the player's by default.
        # @return [String, nil] The color, nil for nil or a name that names no color.
        def self.hex(color, palette = nil)
          found = case color
                  when nil then nil
                  when Integer then UI.text_color(color)
                  when Symbol then (palette || Palette.live).now(color)
                  else Colors.color_of(color)
                  end
          found && format("#%02X%02X%02X", found.red.to_i, found.green.to_i, found.blue.to_i)
        end

        # Tells the color picked.
        #
        # @return [String, nil] The color as "#RRGGBB", nil for none.
        def value
          @options[:value]
        end

        # Picks a color without telling a change.
        #
        # @param color [String, Integer, Symbol, Array, nil] The color, see hex.
        def value=(color)
          @options[:value] = ColorPicker.hex(color, palette)
          show_value
        end

        # Picks the color of a swatch as the player did and tells the change.
        #
        # @param color [String] The color as "#RRGGBB".
        def pick(color)
          return if color == value

          @options[:value] = color
          show_value
          emit(:change, color)
        end

        private

        # Follows a changed option: new colors make the swatches anew, and :sliders shows or hides
        # the sliders.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @grid

          fill_swatches if name == :swatch_colors
          show_value if name == :sliders
        end

        # Makes a swatch for each of its colors, a color name found in the palette of its look.
        def fill_swatches
          @grid.clear
          Array(@options[:swatch_colors]).each do |color|
            hex = ColorPicker.hex(color, palette)
            @grid.add(Swatch.new(:color => color, :hex => hex, :tooltip => hex)) if hex
          end
          show_value
        end

        # Takes the sliders as the player moved one: their red, green and blue make the color.
        def slid
          pick(format("#%02X%02X%02X", *@sliders.map { |slider| slider.value }))
        end

        # Shows the color picked on the swatches, the sliders, the swatch of the color and its text.
        def show_value
          return unless @hex

          color = value
          @grid.children.each { |swatch| swatch.picked = swatch.hex == color }
          channels = color ? [color[1, 6]].pack("H*").unpack("C3") : [0, 0, 0]
          @sliders.each_with_index do |slider, index|
            slider.parent.visible = @options[:sliders] ? true : false
            slider.value = channels[index]
          end
          @preview.color = color
          @hex.text = color.to_s
        end
      end

      # One swatch of a ColorPicker: a square filled in its :color, framed while :picked, that confirm
      # or a click picks. With :shown_only it only shows a color, as the picker's swatch of its color.
      class Swatch < Component
        # The component's kind in C#'s tree.
        KIND = "button"

        # Tells the defaults of the options: a swatch of no color, not picked.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:color => nil, :hex => nil, :picked => false, :shown_only => false)
        end

        options :color, :hex, :picked, :shown_only

        # Takes an event of C#'s tree: a click picks its color in its picker.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "click" && !@options[:shown_only]

          picker = parent && parent.parent
          picker.pick(@options[:hex]) if picker.respond_to?(:pick)
        end

        # Tells its size: a square.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          [ColorPicker::SWATCH, ColorPicker::SWATCH]
        end

        # Draws its color inside the theme's field plate, a frame in the text color while picked and
        # one in the picked color while focused or hovered.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          side = ColorPicker::SWATCH
          canvas.fill(0, 0, side, side, :field)
          color = @options[:color]
          color = Colors.color_of(color) if color.is_a?(String) || color.is_a?(Array)
          canvas.fill(2, 2, side - 4, side - 4, color) if color
          canvas.outline(0, 0, side, side, :picked) if (focused? || hovered?) && enabled_here?
          return unless @options[:picked]

          canvas.outline(0, 0, side, side, :text)
          canvas.outline(1, 1, side - 2, side - 2, :text)
        end
      end

      # Radios of which the player picks one, as MudRadioGroup: each item a Radio with its text
      # beside its round mark. Confirm or a click picks a radio; the arrows that move the focus from
      # one radio onto the next pick that one too, as a group of radios does.
      #
      # An item is a Hash of :text, :value, :disabled (true greys the radio out) and :tooltip.
      #
      # Events: change (the value of the radio picked).
      class RadioGroup < Stack
        # Tells the defaults of the options: a column of no radios, none picked.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 2, :items => [], :value => nil)
        end

        options :items

        # Makes the group with a radio for each item.
        #
        # @param options [Hash] :items, :value and the options of a container.
        def initialize(options = {})
          super
          build
        end

        # Tells the value of the radio picked.
        #
        # @return [Object, nil] The value, nil for none.
        def value
          @options[:value]
        end

        # Picks the radio of a value without telling a change.
        #
        # @param value [Object, nil] The value, nil for none.
        def value=(value)
          @options[:value] = value
          mark
        end

        # Picks a radio as the player did and tells the change.
        #
        # @param radio [Radio] The radio.
        def pick(radio)
          return if !radio.enabled? || radio.value == value

          @options[:value] = radio.value
          mark
          emit(:change, radio.value)
        end

        # Notes a radio the focus left, so the radio it moves onto in the same frame is picked.
        #
        # @param radio [Radio] The radio.
        def left(radio)
          @left = [radio, Key.frame]
        end

        # Picks a radio the focus moved onto from another radio of the group in the same frame.
        #
        # @param radio [Radio] The radio.
        def entered(radio)
          came_from = @left
          @left = nil
          pick(radio) if came_from && came_from[1] == Key.frame && !came_from[0].equal?(radio)
        end

        private

        # Follows a changed option: new items make the radios anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          build if name == :items && @built
        end

        # Makes a radio for each item.
        def build
          @built = true
          clear
          Array(@options[:items]).each do |item|
            add(Radio.new(:text => item[:text].to_s, :value => item[:value], :enabled => item[:disabled] != true, :tooltip => item[:tooltip]))
          end
          mark
        end

        # Marks the radio of the value picked and no other.
        def mark
          @children.each do |radio|
            picked = radio.value == value
            radio.checked = picked unless radio.checked == picked
          end
        end
      end

      # One radio of a RadioGroup: a round mark, filled in its middle while picked, with its text
      # beside it. Confirm or a click picks it in its group.
      class Radio < Checkbox
        # Room between the mark's ring and its dot.
        DOT_ROOM = 4

        # Tells the defaults of the options: a radio of no value.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:value => nil)
        end

        options :value

        # Takes an event of C#'s tree: a click picks it in its group, and the focus moving from one
        # radio onto it picks it too.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          group = parent.is_a?(RadioGroup) ? parent : nil
          return group.pick(self) if name == "click" && group

          super
          group.left(self) if name == "blur" && group
          group.entered(self) if name == "focus" && group
        end

        private

        # Draws the round mark: a ring in the theme's edge around the field's color, and a dot in the
        # text color while picked.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        def draw_box(canvas, x, y)
          radius = BOX / 2
          canvas.disc(x + radius, y + radius, radius, :edge)
          canvas.disc(x + radius, y + radius, radius - 1, :field)
          canvas.disc(x + radius, y + radius, radius - DOT_ROOM, :text) if checked?
        end
      end

      # Buttons joined in a row that the player turns on, as MudToggleGroup: each item an outlined
      # button, filled in :color while on, the theme's primary color without one. Without :multi one
      # is on and a click on it keeps it on; with :multi each turns on and off, and the value is an
      # Array of the values on, in the items' order. With :number_keys the digits 1 to 9, of the row
      # and of the numpad, press the first to the ninth item as their hotkeys while their root takes
      # input, also while a field there types that refuses digits.
      #
      # An item is a Hash of :text, :value, :icon, :disabled (true greys it out) and :tooltip.
      #
      # Events: change (the value on, with :multi the values on).
      class ToggleGroup < Stack
        # The most items :number_keys reach, the digits 1 to 9.
        NUMBER_KEYS = 9

        # Tells the defaults of the options: a row of no items, one on at most, none on, no digits.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => 0, :items => [], :multi => false, :color => nil, :value => nil, :number_keys => false)
        end

        options :items, :multi, :color, :number_keys

        # Makes the group with a button for each item.
        #
        # @param options [Hash] :items, :multi, :color, :value and the options of a container.
        def initialize(options = {})
          super
          build
        end

        # Tells the value on.
        #
        # @return [Object, Array] The value, nil for none; with :multi the values on, an Array.
        def value
          @options[:multi] ? Array(@options[:value]) : @options[:value]
        end

        # Turns on the items of a value without telling a change.
        #
        # @param value [Object, Array, nil] The value; with :multi the values on.
        def value=(value)
          @options[:value] = value
          mark
        end

        # Turns an item on or off as the player did and tells the change: without :multi it turns on
        # and the others off, and one already on stays on.
        #
        # @param item [ToggleItem] The item's button.
        def toggle(item)
          return unless item.enabled?

          if @options[:multi]
            wanted = on?(item.value) ? value - [item.value] : value + [item.value]
            now = @children.map { |button| button.value }.select { |each| wanted.include?(each) }
          else
            return if on?(item.value)

            now = item.value
          end
          @options[:value] = now
          mark
          emit(:change, now)
        end

        private

        # Follows a changed option: new items or digits make the buttons anew, and :multi or :color
        # draw them anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @built

          [:items, :number_keys].include?(name) ? build : mark
        end

        # Makes a button for each item, with its digit as its hotkey with :number_keys.
        def build
          @built = true
          clear
          Array(@options[:items]).each_with_index do |entry, place|
            button = add(ToggleItem.new(:text => entry[:text].to_s, :icon => entry[:icon], :value => entry[:value], :enabled => entry[:disabled] != true,
                                        :tooltip => entry[:tooltip], :acts => true, :hotkey => digit_keys(place)))
            button.on(:click) { toggle(button) }
          end
          mark
        end

        # Tells the keys that press an item with :number_keys: the digit of its place from 1, of the
        # row and of the numpad.
        #
        # @param place [Integer] The item's place.
        # @return [Array<Integer>, nil] Windows' codes of the keys, nil for none.
        def digit_keys(place)
          @options[:number_keys] && place < NUMBER_KEYS ? [0x31 + place, 0x61 + place] : nil
        end

        # Tells whether the item of a value is on.
        #
        # @param value [Object] The item's value.
        # @return [Boolean] Whether it is.
        def on?(value)
          @options[:multi] ? Array(@options[:value]).include?(value) : @options[:value] == value
        end

        # Draws the buttons of the items on filled in the group's color and the others outlined.
        def mark
          @children.each { |button| button.show_on(on?(button.value), @options[:color]) }
        end
      end

      # One item of a ToggleGroup: a button, outlined while off and filled in its group's color while
      # on, that confirm or a click toggles.
      class ToggleItem < Button
        # Tells the defaults of the options: an outlined button of no value.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:value => nil, :variant => :outlined)
        end

        options :value

        # Tells whether it is on.
        #
        # @return [Boolean] Whether it is.
        def on?
          @options[:variant] == :filled
        end

        # Draws it on or off.
        #
        # @param on [Boolean] Whether it is on.
        # @param color [Symbol, Color, nil] The fill while on, nil for the theme's primary color.
        def show_on(on, color)
          variant = on ? :filled : :outlined
          self.variant = variant unless @options[:variant] == variant
          fill = on ? color : nil
          self.color = fill unless @options[:color] == fill
        end
      end
    end
  end
end
