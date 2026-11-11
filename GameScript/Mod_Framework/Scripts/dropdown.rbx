#----------------------------------------------------------------
#  dropdown.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Removed the filter a steered list took from the entries that are on, which the layer turned off
#      Paulinchen  2026-11-09: Let a select's padding replace the room around its text, the arrow's room staying
#      Paulinchen  2026-11-07: Read a greyed entry from :disabled
#      Paulinchen  2026-11-06: Removed the add_ helper of the dropdown, which nothing called
#                            - Called the engine's classes by their names under UI::Engine
#                            - Closed and moved its menu with the dropdown through :opened_from
#      Paulinchen  2026-11-05: Moved its menu with the root of the dropdown
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Lined its menu up with a list it steers without narrowing it, by :narrows, its clear entry
#                              counting the rows the list shows once its owner filtered them
#                            - Opened no menu and hid its arrow while it takes no input, and laid its menu above every window and dialog
#      Paulinchen  2026-11-04: Named the entry that is on without :count_text
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Greyed out its text and arrow while it takes no input instead of drawing them see-through
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A button that opens a menu of entries below itself, each turned on and off, such as the
      # filters of a list. Its text names how many entries are on, "Filter (2)" by :count_text, or
      # with :count_text nil the text of the first entry on, and an arrow at its right points down. The entries are Hashes of :text, :icon, :value (else the
      # text) and :disabled (true greys it out and keeps it off); with :multi any number of
      # them are on, else one, which a pick turns on and closes the menu. :clear_text adds an entry
      # after the others that turns every one off; while one is on and the dropdown steers a list, it
      # tells how many rows show by :clear_count_text, "Clear · 2 shown".
      #
      # The menu lies in a grid of :columns, filled line by line, its ticked entries in the system
      # color; :auto takes as many columns as keep it to :most_rows lines, as far as the screen's width
      # holds them. While the dropdown steers a list, the menu lies at the list's left edge and is as
      # wide as the list, and :auto takes as many columns as that width holds. It shows as many lines
      # as the screen holds below the dropdown, so a long set of entries shows at once and scrolls only
      # past that. In it the arrows move between the entries, confirm or a click turns the one under
      # the cursor on or off, and cancel, the game's :button (such as :Z) or a press anywhere else
      # close it, the focus going back where it was. A click on the dropdown opens and closes it, and
      # open_menu opens it from a key with the focus in it.
      #
      # Events: change (values: those of the entries now on), open, close (of the menu).
      class Dropdown < Button
        # How a text names how many entries are on, by the text and the count.
        COUNT_TEXT = "%s (%d)"

        # The most lines the menu shows with :columns => :auto before it scrolls.
        MOST_ROWS = 8

        # The width of the arrow and the room before it.
        ARROW = 9
        ARROW_GAP = 6

        # The value of the entry :clear_text adds.
        CLEAR = :clear

        # How the clear entry tells how many rows of the list it steers show, by its text and the count.
        CLEAR_COUNT_TEXT = "%s #{[0xB7].pack('U')} %d shown"

        # Tells the defaults of the options: a menu of no entries, any number of them on, its columns
        # by its entries.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:items => [], :values => [], :multi => true, :columns => :auto, :most_rows => MOST_ROWS, :clear_text => nil,
                      :count_text => COUNT_TEXT, :button => nil, :clear_count_text => CLEAR_COUNT_TEXT)
        end

        # Tells which properties of C#'s tree each option sets: the entries on change its text.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:values => TextSized::PROPS, :items => TextSized::PROPS, :count_text => TextSized::PROPS)
        end

        options :items, :multi, :columns, :most_rows, :clear_text, :count_text, :button, :clear_count_text

        # @return [List, nil] The list it steers, see steer.
        attr_reader :steered

        # Makes the dropdown, the entries on kept to those it has.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @options[:values] = known(@options[:values])
        end

        # Tells the values of the entries that are on, in the entries' order.
        #
        # @return [Array] The values.
        def values
          @options[:values].dup
        end

        # Turns on the entries of some values and the others off, without telling change.
        #
        # @param value [Array] The values; those of no entry, or of one that is not enabled, are left
        #   out, and without :multi all but the first.
        def values=(value)
          set_option(:values, known(value))
        end

        # Gives it other entries, keeping on those still there and enabled.
        #
        # @param value [Array<Hash>] The entries.
        def items=(value)
          @options[:items] = value.to_a
          set_option(:values, known(@options[:values]))
          @menu.fill if menu_open?
        end

        # Tells whether the entry of a value is on.
        #
        # @param value [Object] The value.
        # @return [Boolean] Whether it is.
        def on?(value)
          @options[:values].include?(value)
        end

        # Steers a list from now on: the menu lies at its left edge as wide as it, and the clear entry
        # counts its rows, which its owner filters.
        #
        # @param list [List] The list.
        # @return [Dropdown] Itself.
        def steer(list)
          @steered = list.is_a?(List) ? list : nil
          self
        end

        # Turns the entry at a place on or off as the player does, or every one off for the entry of
        # :clear_text, and tells change; a pick without :multi closes the menu.
        #
        # @param place [Integer] The entry's place, Array(items).size for the clear entry.
        def toggle(place)
          return clear if place == Array(@options[:items]).size && @options[:clear_text]
          return unless enabled_at?(place)

          value = value_at(place)
          on = @options[:values]
          self.values = on.include?(value) ? on - [value] : (@options[:multi] ? on + [value] : [value])
          emit(:change, values)
          close_menu unless @options[:multi]
        end

        # Turns every entry off and tells change, unless none was on.
        def clear
          return if @options[:values].empty?

          self.values = []
          emit(:change, values)
        end

        # Opens the menu below it, the key focus in it, unless it is open, has no entries or takes
        # no input.
        #
        # @return [Dropdown] Itself.
        def open_menu
          return self if menu_open? || Array(@options[:items]).empty? || @rect.nil? || !enabled_here?

          @menu = DropdownMenu.new(self).open
          emit(:open)
          self
        end

        # Closes the menu, if it is open.
        #
        # @return [Dropdown] Itself.
        def close_menu
          @menu.close if menu_open?
          self
        end

        # Tells whether the menu is open.
        #
        # @return [Boolean] Whether it is.
        def menu_open?
          @menu && @menu.open? ? true : false
        end

        # Tells how many rows of the list it steers show that its entries judge, a row with
        # :search => false, such as a Remove row, left out.
        #
        # @return [Integer, nil] The rows, nil while it steers no list.
        def shown_count
          @steered && @steered.shown_rows.count { |row| !(row.is_a?(Hash) && row[:search] == false) }
        end

        # Tells whether the entry at a place may be turned on: unless it says :disabled => true.
        #
        # @param place [Integer] The entry's place.
        # @return [Boolean] Whether it may.
        def enabled_at?(place)
          item = Array(@options[:items])[place]
          !item.nil? && !(item.is_a?(Hash) && item[:disabled] == true)
        end

        # Tells the value of an entry.
        #
        # @param place [Integer] The entry's place.
        # @return [Object, nil] Its :value, else its text; nil for no entry.
        def value_at(place)
          item = Array(@options[:items])[place]
          return item[:value] if item.is_a?(Hash) && item.key?(:value)

          item.is_a?(Hash) ? item[:text].to_s : item && item.to_s
        end

        # Takes an event of C#'s tree: a click opens or closes the menu.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          super
          return unless name == "click"

          menu_open? ? close_menu : open_menu
        end

        # Draws its plate, its text in the room before the arrow and the arrow at its right; the arrow
        # hides while it takes no input, which opens nothing.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_plate(canvas)
          _top, edge_right, _bottom, edge_left = edge_sides
          right = canvas.width - edge_right - ARROW
          top = (canvas.height - LINE_HEIGHT) / 2
          canvas.text(edge_left, top, [right - ARROW_GAP - edge_left, 1].max, LINE_HEIGHT, measured_text, :color => text_color, :size => text_px, :cut => true)
          return unless enabled_here?

          tip = canvas.height / 2 + ARROW / 4
          (ARROW / 2 + 1).times { |step| canvas.fill(right + step, tip - ARROW / 2 + step, ARROW - 2 * step, 1, :text) }
        end

        # Tells the text it shows: its text, with how many entries are on, or the text of the first
        # entry on without :count_text.
        #
        # @return [String] The text, such as "Filter (2)".
        def shown_text
          count = @options[:values].size
          return @options[:text].to_s if count == 0
          return format(@options[:count_text].to_s, @options[:text], count) if @options[:count_text]

          place = (0...Array(@options[:items]).size).find { |each| value_at(each) == @options[:values].first }
          item = place && Array(@options[:items])[place]
          item.is_a?(Hash) ? item[:text].to_s : item.to_s
        end

        # Tells its close blocks that its menu closed.
        def menu_closed
          emit(:close)
        end

        private

        # Tells the text C# measures: the one it shows.
        #
        # @return [String] The text.
        def measured_text
          shown_text
        end

        # Tells the room around its text, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [PAD_Y, PAD_X, PAD_Y, PAD_X]
        end

        # Tells the room its arrow takes at its right.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [0, ARROW + ARROW_GAP, 0, 0]
        end

        # Keeps the values of entries that may be on, in the entries' order, one at most without
        # :multi.
        #
        # @param wanted [Array, nil] The values.
        # @return [Array] The values kept.
        def known(wanted)
          wanted = Array(wanted)
          places = (0...Array(@options[:items]).size).select { |place| enabled_at?(place) }
          kept = places.map { |place| value_at(place) }.select { |value| wanted.include?(value) }.uniq
          @options[:multi] ? kept : kept.first(1)
        end
      end

      # The menu a Dropdown opens below itself: a floating box above every window and dialog holding
      # its entries in a List of columns, each with a box that is filled while it is on; at the left
      # edge of the list the Dropdown steers and as wide as it, if it steers one.
      class DropdownMenu < Box
        # Tells the defaults of the options: closable, holding the game's buttons.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:closable => true, :captures => true, :z => Z[:popups])
        end

        # @return [List] The entries.
        attr_reader :list

        # Makes the menu below a Dropdown, in its theme, as wide as its columns and on the screen, the
        # key focus on its first entry.
        #
        # @param dropdown [Dropdown] The Dropdown, laid out.
        def initialize(dropdown)
          @dropdown = dropdown
          rows = entries
          cell = cell_width(rows)
          steered = dropdown.steered && dropdown.steered.rect
          across = columns_for(rows.size, cell, steered && steered.width)
          lines = (rows.size + across - 1) / across
          rect = dropdown.rect
          shown = UI.within(lines, 1, [(Graphics.height - rect.y - rect.height - 2 * ROOM) / LINE_HEIGHT, 1].max)
          width = steered ? steered.width : across * cell - List::CELL_GAP + 2 * ROOM + (shown < lines ? Style::SCROLLBAR_WIDTH + List::BAR_GAP : 0)
          left = steered ? steered.x : rect.x
          super(:at => [UI.within(left, 0, [Graphics.width - width, 0].max), rect.y + rect.height], :width => width, :theme => dropdown.theme_value,
                :log => dropdown.log_target, :z => Popup.depth(dropdown), :opened_from => dropdown)
          @fresh = true
          @held = dropdown.button && Capture.press?(dropdown.button)
          @list = add(List.new(:rows => rows, :columns => across, :rows_shown => shown, :shoulder_pages => false, :buttons => [dropdown.button].compact))
          @list.on(:submit) do |_row, place|
            dropdown.toggle(place)
            fill if open?
          end
          @list.on(:button) do |_button|
            unless @held
              Sound.play_cancel
              close
            end
          end
          on(:close) { dropdown.menu_closed }
          @list.focus
        end

        # Shows the entries anew, as they are on or off now, the cursor kept.
        def fill
          @list.rows = entries
        end

        # Draws it for the frame, closing it first when the left button went down outside it and its
        # Dropdown, after the frame it opened in, whose press opened it; the button that opened it
        # closes it only once it was let go.
        #
        # @param look_changed [Boolean] Whether the colors or the game's window color changed.
        def update_frame(look_changed)
          @held &&= Capture.press?(@dropdown.button)

          if @fresh
            @fresh = false
          elsif Mouse.clicked? && !Tree.over.equal?(self) && !@dropdown.hovered?
            return close
          end
          fill unless shown_now == @counted
          super
        end

        # Draws its frame on the field's color, which is opaque in every theme.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          framed? ? canvas.box(0, 0, canvas.width, canvas.height, :fill => :field) : canvas.fill(0, 0, canvas.width, canvas.height, :field)
        end

        private

        # Tells the rows of the entries, each ticked and in the system color while it is on, and the
        # clear entry after them, greyed out while none is on, else with the count of the rows shown.
        #
        # @return [Array<Hash>] The rows.
        def entries
          items = Array(@dropdown.items)
          rows = items.each_with_index.map do |item, place|
            own = item.is_a?(Hash) ? item : { :text => item.to_s }
            on = @dropdown.on?(@dropdown.value_at(place))
            { :text => own[:text].to_s, :icon => own[:icon], :checked => on, :color => on ? :system : nil, :disabled => !@dropdown.enabled_at?(place) }
          end
          clear = @dropdown.clear_text
          @counted = shown_now
          return rows unless clear

          count = @counted
          rows + [{ :text => count ? format(@dropdown.clear_count_text.to_s, clear, count) : clear.to_s, :disabled => @dropdown.values.empty? }]
        end

        # Tells how many rows the list its Dropdown steers shows while an entry is on, which the clear
        # entry tells; the owner of a list it does not narrow filters the rows after a toggle.
        #
        # @return [Integer, nil] The rows, nil while no entry is on or it steers no list.
        def shown_now
          @dropdown.values.empty? ? nil : @dropdown.shown_count
        end

        # Tells the width of a cell that holds the widest entry with its box and its icon.
        #
        # @param rows [Array<Hash>] The rows.
        # @return [Integer] The pixels, the room to the next cell included.
        def cell_width(rows)
          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          widest = rows.map { |row| UI.text_width(bitmap, row[:text]) }.max.to_i
          icons = rows.any? { |row| row[:icon] } ? ICON_STEP : 0
          widest + Canvas::OUTLINE_ROOM + List::CHECK + Style::GAP + icons + 2 * List::INSET + List::CELL_GAP
        end

        # Tells how many columns the entries take: :columns, or with :auto as many as keep them to
        # :most_rows lines, no more than the screen's width holds; within a width given, as many as it
        # holds.
        #
        # @param count [Integer] The entries.
        # @param cell [Integer] The width of a cell.
        # @param room [Integer, nil] The menu's width, nil for the screen's.
        # @return [Integer] The columns, at least one.
        def columns_for(count, cell, room = nil)
          given = @dropdown.columns
          return [given.to_i, 1].max unless given == :auto

          fit = [((room || Graphics.width) - 2 * ROOM + List::CELL_GAP) / [cell, 1].max, 1].max
          return UI.within(count, 1, fit) if room

          UI.within((count + [@dropdown.most_rows.to_i, 1].max - 1) / [@dropdown.most_rows.to_i, 1].max, 1, fit)
        end
      end
    end
  end
end
