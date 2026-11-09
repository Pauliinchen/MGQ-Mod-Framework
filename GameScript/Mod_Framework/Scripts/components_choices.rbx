#----------------------------------------------------------------
#  components_choices.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Let a chip show several icons side by side
#                            - Filled the tooltip of a slot that stands for markup through :tips
#                            - Split the room of a chip and a check box into the room padding replaces and the room of their marks
#      Paulinchen  2026-11-07: Wrote the text of a chip in the plain text color unless it has contrast
#                            - Made chips only show, without focus, clicks, digits, a close mark or a box of the others
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A wrapping row of icon slots, such as the gems in an item's sockets, a bar of skills or the
      # buffs on a character: each slot an icon button with its tooltip, an empty one :empty_icon (the
      # empty well when nil) with :empty_tooltip. A slot is nil for an empty one, an icon, or a Hash of
      # :icon, :icon_file, :tooltip (a text or a block, see Tooltips), :disabled and :data. While no
      # click block waits, a click or confirm on a slot is quiet. :note, a block that fills the end of
      # a tooltip's box, ends the tooltip of every slot that is not empty. A slot's :tip, a number,
      # stands for its tooltip: :tips, a block of the number and a tooltip's box, fills the box as
      # it opens. Without slots it shows :none, dim, unless that is empty.
      #
      # With an :index the slots are one key stop with a chosen slot, in a bright frame, drawn picked
      # and framed as focused instead while the slots have the focus: LEFT and RIGHT choose the slot
      # beside without going round, then move the focus on along the row; a click chooses a slot; the
      # chosen slot's tooltip shows as a key chooses it. :index => :first_empty chooses the first
      # empty slot, else the first. With :submit_to, confirm on the key stop also moves the focus
      # there with the confirm sound. Slots with an :id give each slot the id "<id>:<place>", so a
      # slot made anew keeps the focus. fade draws some slots see-through and pulse pulses them.
      #
      # Events: click (index, slot: a click on a slot, or confirm on it while it has the focus),
      # change (index, slot: another slot chosen), submit (index, slot: confirm on the slots as a key
      # stop).
      class Slots < Stack
        # The side of a slot with no :slot.
        SLOT = 26

        # How opaque fade draws a slot unless told.
        FADED = 128

        # The options that make the slots anew.
        BUILT_BY = [:slots, :slot, :empty_icon, :empty_tooltip, :note, :none]

        # Tells the defaults of the options: a wrapping row of no slots, none chosen.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :wrap => true, :gap => 2, :slots => [], :slot => SLOT, :empty_icon => nil, :empty_tooltip => nil, :index => nil,
                      :submit_to => nil, :note => nil, :none => nil, :tips => nil)
        end

        # Tells which properties of C#'s tree each option sets: a chosen slot makes it a key stop.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          stop = ["focusable", "steps", "rows", "index", "tooltip"]
          super.merge(:index => stop, :slots => stop)
        end

        options :slots, :slot, :empty_icon, :empty_tooltip, :index, :submit_to, :note, :none, :tips

        # Makes the slots.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          build
        end

        # Hands out the button of a slot, such as to animate it.
        #
        # @param place [Integer] The slot's place.
        # @return [IconButton, nil] The button, nil for none.
        def slot(place)
          place && place >= 0 ? @children[place] : nil
        end

        # Tells whether the slots are one key stop with a chosen slot.
        #
        # @return [Boolean] Whether they are.
        def stop?
          !@options[:index].nil?
        end

        # Chooses a slot, kept on the slots, without telling change.
        #
        # @param value [Integer, Symbol, nil] The slot's place, or :first_empty; nil makes the slots
        #   plain buttons again.
        def index=(value)
          was = stop?
          set_option(:index, value.nil? ? nil : kept(value))
          was == stop? ? mark_chosen : build
        end

        # Draws some slots see-through and the others whole, such as the slots a choice would empty.
        #
        # @param places [Array<Integer>] The slots' places.
        # @param opacity [Integer] How opaque they draw, FADED unless given.
        # @return [Slots] Itself.
        def fade(places, opacity = FADED)
          @children.each_with_index do |button, place|
            wanted = places.include?(place) ? opacity : OPAQUE
            button.opacity = wanted unless button.opacity == wanted
          end
          self
        end

        # Pulses some slots once, see Component#pulse, such as the slots that just changed.
        #
        # @param places [Array<Integer>] The slots' places.
        # @param options [Hash] The options of Component#pulse.
        # @return [Slots] Itself.
        def pulse(places, options = {})
          places.each do |place|
            button = slot(place)
            button.pulse(options) if button
          end
          self
        end

        # Tells the tooltip of the slots as a key stop: the chosen slot's.
        #
        # @return [String, Proc, nil] The tooltip.
        def tooltip
          return @options[:tooltip] unless stop?

          button = slot(kept(@options[:index]))
          button ? button.tooltip : @options[:tooltip]
        end

        # Tells the properties C#'s tree routes the keys by: as a key stop, its slots and the chosen one.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["steps"] = stop?
          props["rows"] = Array(@options[:slots]).size
          props["index"] = stop? ? kept(@options[:index]) : nil
          props["focusable"] = stop? if @options[:focusable].nil?
          props["tooltip"] = !tooltip.to_s.empty?
          props
        end

        # Runs a block on an event; the first click block makes the slots tell click.
        #
        # @param name [Symbol] The event.
        # @yield [*values] Runs on the event with its values.
        # @return [Slots] Itself.
        def on(name, &block)
          super
          build if name.to_sym == :click
          self
        end

        # Drops every block of an event; without click blocks the slots are quiet again.
        #
        # @param name [Symbol] The event.
        # @return [Slots] Itself.
        def off(name)
          super
          build if name.to_sym == :click
          self
        end

        # Takes an event of C#'s tree as a key stop: LEFT or RIGHT chose a slot, and confirm submits
        # the chosen slot, or buzzes on one that takes no input.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless stop?

          case name
          when "move" then choose(values[0].to_i)
          when "click"
            chosen = slot(@options[:index])
            return Sound.play_buzzer if chosen && !chosen.enabled?

            emit(:submit, @options[:index], Array(@options[:slots])[@options[:index]])
            pass_focus
          else super
          end
        end

        # Takes its state from C#: the chosen slot draws picked while the slots have the focus.
        #
        # @param bits [Integer] The bits.
        def state=(bits)
          super
          mark_chosen
        end

        private

        # Follows a changed option: other slots or another look make the slots anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          build if BUILT_BY.include?(name)
        end

        # Makes a button per slot, the chosen one marked, or the dim :none in their place without any.
        def build
          clear
          side = UI.whole(@options[:slot])
          @options[:index] = kept(@options[:index]) if stop? && !Array(@options[:slots]).empty?
          Array(@options[:slots]).each_with_index do |slot, place|
            own = slot.is_a?(Hash) ? slot : { :icon => slot }
            tooltip = own[:tip].nil? ? own[:tooltip] : tip_of(own[:tip])
            shown = slot.nil? ? { :icon => @options[:empty_icon], :tooltip => @options[:empty_tooltip] } : { :icon => own[:icon], :icon_file => own[:icon_file], :tooltip => noted(tooltip) }
            shown[:focusable] = false if stop?
            shown[:id] = "#{@options[:id]}:#{place}" unless @options[:id].nil?
            button = add(IconButton.new(shown.merge(:size => [side, side], :enabled => own[:disabled] != true)))
            button.on(:click) { clicked(place, slot) } if listens?(:click) || stop?
          end
          add(Label.new(:text => @options[:none].to_s, :color => :dim, :font_size => :small)) if @children.empty? && !@options[:none].to_s.empty?
          mark_chosen
        end

        # Tells the tooltip a slot's :tip stands for: a block that has :tips fill the box, read as the
        # tooltip opens.
        #
        # @param key [Integer] The tip's number.
        # @return [Proc] The block.
        def tip_of(key)
          lambda { |box| @options[:tips].call(key, box) if @options[:tips] }
        end

        # Tells a slot's tooltip with :note at its end; a text becomes the first line of the box.
        #
        # @param tooltip [String, Proc, nil] The slot's own tooltip.
        # @return [String, Proc, nil] The tooltip.
        def noted(tooltip)
          note = @options[:note]
          return tooltip unless note && !tooltip.to_s.empty?

          lambda do |box|
            tooltip.respond_to?(:call) ? tooltip.call(box) : box.add_label(tooltip.to_s, :font_size => :small, :wrap => true)
            note.call(box)
          end
        end

        # Takes a click on a slot: as a key stop it chooses the slot first.
        #
        # @param place [Integer] The slot's place.
        # @param slot [Object] The slot.
        def clicked(place, slot)
          choose(place) if stop?
          emit(:click, place, slot)
        end

        # Chooses a slot and tells change when it is another.
        #
        # @param place [Integer] The slot's place.
        def choose(place)
          place = kept(place)
          return if place == @options[:index]

          self.index = place
          emit(:change, place, Array(@options[:slots])[place])
        end

        # Draws the chosen slot as chosen, picked while the slots have the focus, and the other slots
        # plain; the text of :none without any is left alone.
        def mark_chosen
          @children.first(Array(@options[:slots]).size).each_with_index do |button, place|
            look = stop? && place == @options[:index] ? (focused? ? :focused : true) : false
            button.chosen = look unless button.chosen == look
          end
        end

        # Keeps a slot's place on the slots.
        #
        # @param place [Integer, Symbol, nil] The place, or :first_empty for the first empty slot.
        # @return [Integer] The place kept, 0 for no slots.
        def kept(place)
          place = Array(@options[:slots]).index(nil) || 0 if place == :first_empty
          UI.within(place.to_i, 0, [Array(@options[:slots]).size - 1, 0].max)
        end

        # Moves the focus to :submit_to with the confirm sound, after confirm on the key stop.
        def pass_focus
          target = @options[:submit_to]
          return unless target.is_a?(Component)

          Sound.play_ok
          target.focus
        end
      end

      # A wrapping row of chips that show facts, such as a mod's tags: each chip a pill lower than a
      # button with a text, an icon or both and its tooltip, its :color filling it as a :filled
      # button's does (its :variant, :filled by default). Chips take no focus, no click, no key and no
      # digit; a filter the player turns on and off is a checkbox, a switch or a toggle group.
      #
      # A chip is a String, its text, or a Hash of :text, :icon (or :icons, several side by side),
      # :tooltip, :color and :variant.
      #
      # With :most_rows they keep to that many rows of their width, and with :most to that many
      # chips: the chips left out stand behind a last chip, "+3" by :more_text, whose tooltip names
      # them.
      class Chips < Stack
        # The height of a chip, a small text's line with a pixel of room above and below, lower than a
        # button's.
        HEIGHT = SMALL_LINE_HEIGHT + 2

        # The text of the chip that stands for the chips left out, by how many, unless :more_text gives one.
        MORE_TEXT = "+%d"

        # What the tooltip of that chip names the chips by, and joins them with.
        MORE_JOIN = ", "

        # Tells the defaults of the options: a wrapping row of no chips in the small font, every chip
        # shown.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :wrap => true, :gap => 2, :items => [], :font_size => :small, :most_rows => nil, :most => nil, :more_text => MORE_TEXT)
        end

        options :items, :font_size, :most_rows, :most, :more_text

        # Makes the chips.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          @shown = nil
          super
          build
        end

        # Tells how many chips show, the first ones; :most and :most_rows leave the others out.
        #
        # @return [Integer] The chips that show.
        def shown_count
          @shown || Array(@options[:items]).size
        end

        # Tells the chip that stands for the chips left out.
        #
        # @return [Chip, nil] The chip, nil before the chips are made.
        attr_reader :more

        # Takes the place C# gave it, and keeps to :most_rows of its width.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          fold
        end

        # Keeps to :most_rows of its width and to :most chips: as many chips as fit with the chip that
        # stands for the others show, the others hide; with every chip fitting, all show. A chip whose
        # width C# told anew asks it again.
        def fold
          return unless @rect && @more

          count = Array(@options[:items]).size
          shown = @options[:most] ? [@options[:most].to_i, count].min : count
          shown = [shown, fitting(count)].min if @options[:most_rows]
          return if shown == shown_count && @more.visible? == (shown < count)

          @shown = shown < count ? shown : nil
          @children.first(count).each_with_index { |chip, place| chip.visible = place < shown if chip.visible? != (place < shown) }
          @more.text = format(@options[:more_text].to_s, count - shown)
          @more.tooltip = Array(@options[:items])[shown..-1].map { |item| item.is_a?(Hash) ? item[:text] || item[:tooltip] : item }.join(MORE_JOIN)
          @more.visible = shown < count
        end

        # Hands out a chip, such as to read how it shows.
        #
        # @param place [Integer] The chip's place.
        # @return [Chip, nil] The chip, nil for none.
        def chip(place)
          place && place >= 0 ? @children[place] : nil
        end

        private

        # Follows a changed option: other chips or another font make them anew, another most keeps to
        # it.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          build if [:items, :font_size].include?(name)
          fold if [:most, :most_rows, :more_text].include?(name) && @rect
        end

        # Makes a chip per item, and the hidden chip that stands for those left out.
        def build
          clear
          @shown = nil
          Array(@options[:items]).each do |item|
            own = item.is_a?(Hash) ? item : { :text => item.to_s }
            add(Chip.new(self, :text => own[:text].to_s, :icon => own[:icon], :icons => own[:icons], :tooltip => own[:tooltip], :font_size => @options[:font_size],
                               :height => HEIGHT, :color => own[:color], :variant => own[:variant] || :filled))
          end
          @more = add(Chip.new(self, :font_size => @options[:font_size], :height => HEIGHT, :visible => false, :variant => :filled))
          fold if @rect
        end

        # Tells how many of the first chips fit :most_rows of its width, with the chip that stands
        # for the others after them when not all fit.
        #
        # @param count [Integer] The chips.
        # @return [Integer] The chips that fit.
        def fitting(count)
          _top, right, _bottom, left = padding_sides
          room = @rect.width - left - right
          widths = (0...count).map { |place| @children[place].rect ? @children[place].rect.width : @children[place].measured_width }
          return count if rows_of(widths, room) <= @options[:most_rows].to_i

          (0...count).to_a.reverse.find do |shown|
            rows_of(widths.first(shown) + [@more.measured_width(format(@options[:more_text].to_s, count - shown))], room) <= @options[:most_rows].to_i
          end || 0
        end

        # Tells how many rows chips of some widths wrap into in a room.
        #
        # @param widths [Array<Integer>] The chips' widths, in their order.
        # @param room [Integer] The room's width.
        # @return [Integer] The rows.
        def rows_of(widths, room)
          gap = UI.whole(@options[:gap])
          rows = 1
          x = nil
          widths.each do |width|
            if x && x + gap + width > room
              rows += 1
              x = width
            else
              x = x ? x + gap + width : width
            end
          end
          rows
        end
      end

      # One chip of Chips: MudBlazor's chip, a pill lower than a button in the look the theme gives
      # its :variant in its :color, its icon smaller than the iconset's, or its :icons side by side,
      # alone in its middle without a text. It only shows: it takes no focus and nothing answers a
      # click, so the pointer only shows its tooltip.
      class Chip < Button
        # The side of its icon, scaled down from the iconset's to fit the chip.
        ICON = 16

        # Room between its icon and its text.
        ICON_GAP = 4

        # Room between two of its :icons.
        ICONS_GAP = 2

        # Makes the chip, which the keys never reach.
        #
        # @param chips [Chips] Its Chips.
        # @param options [Hash] Its options.
        def initialize(chips, options = {})
          super(options.merge(:focusable => false, :acts => false))
          @chips = chips
        end

        # Takes the place C# gave it; another width has its Chips keep to their rows anew.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          width = @rect && @rect.width
          super
          @chips.fold if width != @rect.width
        end

        # Tells the width it takes with a text as it measures here, such as for a chip not laid out
        # yet.
        #
        # @param text [String] The text, its own by default.
        # @return [Integer] The pixels.
        def measured_width(text = @options[:text].to_s)
          _top, right, _bottom, left = padding_sides
          (text.empty? ? 0 : UI.text_width(UI.font_bitmap(text_px), text) + Canvas::OUTLINE_ROOM) + left + right
        end

        # Draws its pill and its icon alone in its middle, or as a button draws its icon and text.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          return super unless @options[:text].to_s.empty?

          look = look_of(canvas)
          look ? draw_look(canvas, look) : draw_plate(canvas)
          draw_mark(canvas, (canvas.width - icons_width) / 2, 0) if marked?
        end

        # Draws its pill in the look of the theme: its fill, ringed in its edge.
        #
        # @param canvas [Canvas] Where it draws.
        # @param look [Hash] The look, see Theme.button_look.
        def draw_look(canvas, look)
          canvas.pill(0, 0, canvas.width, canvas.height, :fill => look[:fill], :edge => look[:edge])
        end

        private

        # Tells whether it shows as picked: never, since it only shows.
        #
        # @return [Boolean] false.
        def lit?
          false
        end

        # Draws its pill in its plate's color where the theme gives no look, without the DLL.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_plate(canvas)
          canvas.pill(0, 0, canvas.width, canvas.height, :fill => plate_fill)
        end

        # Tells the plate's color where the theme gives no look: its :color.
        #
        # @return [Symbol, Color] The color.
        def plate_fill
          @options[:color] || :tab
        end

        # Tells its text's color where the theme gives no look: its own :text_color, else the text on
        # its plate, since its :color fills it.
        #
        # @return [Symbol, Color] The color.
        def text_color
          @options[:text_color] || plate_text
        end

        # Tells the height of its text's line: its font's.
        #
        # @return [Integer] The pixels.
        def line_height
          UI.line_height_of(@options[:font_size])
        end

        # Draws its icons at ICON, side by side, in the middle of its height.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The first icon's left.
        # @param _y [Integer] The top a button gives, which a chip's lower icon does not take.
        def draw_mark(canvas, x, _y)
          top = (canvas.height - ICON) / 2
          shown_icons.each_with_index { |icon, place| canvas.icon(icon, x + place * (ICON + ICONS_GAP), top, :side => ICON, :opacity => drawn_opacity(canvas)) }
        end

        # Tells whether it has an icon.
        #
        # @return [Boolean] Whether it has.
        def marked?
          !shown_icons.empty?
        end

        # Tells the icons it shows: its :icons, else its :icon.
        #
        # @return [Array] The icons.
        def shown_icons
          @options[:icons] ? Array(@options[:icons]).compact : [@options[:icon]].compact
        end

        # Tells the width of its icons side by side.
        #
        # @return [Integer] The pixels, 0 without an icon.
        def icons_width
          count = shown_icons.size
          count > 0 ? count * ICON + (count - 1) * ICONS_GAP : 0
        end

        # Tells the room its icons take before its text.
        #
        # @return [Integer] The pixels, 0 without an icon.
        def mark_room
          marked? ? icons_width + ICON_GAP : 0
        end

        # Tells the room around its text, or around its icon alone, which then makes it as wide as
        # high.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          return super unless @options[:text].to_s.empty?

          side = (Chips::HEIGHT - ICON) / 2
          [PAD_Y, side, PAD_Y, side]
        end

        # Tells the room its icon takes: a button's with a text, else the icon's at its left.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          return super unless @options[:text].to_s.empty?

          [0, 0, 0, icons_width]
        end
      end

      # A box with a label, ticked by a click, the game's confirm button or Enter while focused; with
      # :style => :switch an On and Off switch instead of the box. With :tri_state a click goes from
      # off to on to neither (:checked nil, a bar in the box) and back to off. :value_texts names the
      # off and the on state, the one that holds drawn at its right end.
      #
      # Events: change (checked).
      class Checkbox < Component
        include TextSized

        # The component's kind in C#'s tree.
        KIND = "checkbox"

        # The side of the box, and the height of the switch.
        BOX = 16

        # The width of the switch.
        SWITCH_WIDTH = 32

        # Room between the box or switch and the label.
        MARK_GAP = 6

        # Room around the whole.
        PAD = 2

        # Room between the label and the text of the state at the right end.
        VALUE_GAP = 12

        # The looks there are.
        STYLES = [:box, :switch]

        # Tells the defaults of the options: an empty box.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:text => "", :checked => false, :style => :box, :tri_state => false, :value_texts => nil)
        end

        # Tells which properties of C#'s tree each option sets: the text's, and the room of the look.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:text => TextSized::PROPS, :style => ["padding"], :value_texts => TextSized::PROPS)
        end

        options :text, :checked, :style, :tri_state, :value_texts

        # Takes an event of C#'s tree: a click ticks it or takes the tick off.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "click"

          turn
        end

        # Tells whether it is ticked.
        #
        # @return [Boolean] Whether it is.
        def checked?
          @options[:checked] ? true : false
        end

        # Draws its plate while hovered or focused, its box or switch, its label and the text of its
        # state.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          top, right, _bottom, left = padding_sides
          canvas.fill(0, 0, canvas.width, canvas.height, focused? ? :picked : :tab) if (focused? || hovered?) && enabled_here?
          mark_x = left - mark_width - MARK_GAP
          mark_y = top + (LINE_HEIGHT - BOX) / 2
          switch? ? draw_switch(canvas, mark_x, mark_y) : draw_box(canvas, mark_x, mark_y)
          room = [canvas.width - left - right, 1].max
          state = value_text
          if state
            state_width = UI.text_width(UI.font_bitmap(text_px), state) + Canvas::OUTLINE_ROOM
            canvas.text(left, top, room, LINE_HEIGHT, state, :align => :end, :cut => true)
            room = [room - state_width - VALUE_GAP, 1].max
          end
          canvas.text(left, top, room, LINE_HEIGHT, @options[:text].to_s, :cut => true)
        end

        private

        # Turns it to its next state and tells the change: on and off, or with :tri_state from off to
        # on to neither and back to off.
        def turn
          now = @options[:checked]
          @options[:checked] = if @options[:tri_state]
                                 now.nil? ? false : (now ? nil : true)
                               else
                                 !now
                               end
          redraw
          emit(:change, @options[:checked])
        end

        # Tells the text of its state from :value_texts, off first.
        #
        # @return [String, nil] The text, nil without :value_texts.
        def value_text
          texts = @options[:value_texts]
          return nil unless texts.is_a?(Array) && texts.size == 2

          texts[checked? ? 1 : 0].to_s
        end

        # Tells the text as C# measures it: the label and the longer text of a state after it.
        #
        # @return [String] The text.
        def measured_text
          texts = @options[:value_texts]
          return @options[:text].to_s unless texts.is_a?(Array) && texts.size == 2

          longer = texts.map { |text| text.to_s }.max_by { |text| text.length }
          "#{@options[:text]}    #{longer}"
        end

        # Tells whether it draws as a switch.
        #
        # @return [Boolean] Whether it does.
        def switch?
          UI.choice(@options[:style], STYLES, :box, "checkbox style") == "switch"
        end

        # Tells the width of the box or the switch.
        #
        # @return [Integer] The pixels.
        def mark_width
          switch? ? SWITCH_WIDTH : BOX
        end

        # Tells the room around its label, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [0, PAD, 0, PAD]
        end

        # Tells the room its box or switch takes at its left.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [0, 0, 0, mark_width + MARK_GAP]
        end

        # Draws the box, its middle filled while ticked and a bar across it while neither.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        def draw_box(canvas, x, y)
          canvas.box(x, y, BOX, BOX, :fill => :field)
          canvas.fill(x + 4, y + 4, BOX - 8, BOX - 8, :text) if checked?
          canvas.fill(x + 4, y + BOX / 2 - 1, BOX - 8, 2, :text) if @options[:tri_state] && @options[:checked].nil?
        end

        # Draws the switch: its track, picked while on, and its knob at the left while off and at the
        # right while on.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        def draw_switch(canvas, x, y)
          canvas.box(x, y, SWITCH_WIDTH, BOX, :fill => checked? ? :picked : :well)
          knob = BOX - 6
          canvas.fill(checked? ? x + SWITCH_WIDTH - knob - 3 : x + 3, y + 3, knob, knob, :text)
        end
      end

      # An on and off switch that Left and Right turn as well as a click and confirm, as the game's
      # option rows step their values: C#'s tree steps it as a select.
      #
      # Events: change (checked).
      class Switch < Checkbox
        # The component's kind in C#'s tree, which steps it by LEFT and RIGHT.
        KIND = "select"

        # Tells the defaults of the options: a switch that is off.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:style => :switch)
        end

        # Takes an event of C#'s tree: LEFT or RIGHT turns it as a click does.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "step"

          turn
        end
      end
    end
  end
end
