#----------------------------------------------------------------
#  page_view.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Handed :label_width on to its list
#                            - Kept the room of a picture's frame, which a padding of 0 now takes away
#      Paulinchen  2026-11-07: Removed add_page_view of the old API
#                            - Read a greyed button of the pane from :disabled
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Removed the page a mod filled it from, which other mods' pages through UI.patch replace
#                            - Scrolled the pane by Page Up and Page Down from the list, gave the focus to a pane that holds no
#                              key stop, where Up and Down scroll it, and left the game's L and R to the root's page step
#                              unless :root_pages
#      Paulinchen  2026-11-05: Took the parts of the UI layer's page_head and page_pane into its head and pane, and put the
#                              cursor on an entry by its data
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Indented the entries under a group and drew a picture of a character beside a thing named
#                            - Gave the focus to the head or the list, whichever was picked last
#                            - Took Ctrl in the pane back to the list and told whether the focus lies in the pane
#                            - Folded and opened the groups itself
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A page of an overview: a head, a list in folding groups and a
      # reading pane beside it, :list_share of its width for the list.
      #
      # head= takes :title, :note, :lines (two at most, wrapped), :grid (rows of cells), a picture
      # (:face, :figure or :portrait as Picture takes them, or :icon) and :pick (the head is then a
      # stop of the keys above the list, telling change with it). rows= takes List rows, plus
      # { :group => key, :text, :open } (with an open or closed mark; confirm or a click folds or
      # opens it and tells fold, an :open given wins) and { :none => text } (a dim line the cursor
      # passes). pane=
      # takes :title, a picture, :subtitle, :buttons (texts or { :text, :disabled }) and :lines:
      # Strings (wrapped paragraphs), :gap, { :items => [...] }, { :gauge => rate, :text } and
      # { :control => key, :text, :value, :color, :less, :more }. A thing named is { :text, :note,
      # :faint } with an :icon, or a :face, :figure or :portrait as Picture takes them. The entries
      # under a group stand ENTRY_INDENT in from it.
      #
      # A new pane keeps the focus, the controls' cursors and the scroll; it goes back to its top only
      # once another entry or the head is picked.
      #
      # head_parts and pane_parts take parts made elsewhere instead, such as the UI layer's markup:
      # the head then fits them, and confirm on an entry moves the focus onto the pane's first part
      # that takes the keys.
      #
      # Confirm on an entry moves the focus into the pane onto its first control or button, or onto
      # the pane itself while it holds none, where Up and Down scroll it; cancel or Ctrl there goes back
      # to the list. Page Up and Page Down from the list scroll the pane a page, as does the paging a
      # gamepad's shoulders fall back to; with :root_pages (the engine's own windows) the game's L and
      # R scroll it too. :label_width is the width of its entries' labels' column, as a List's.
      #
      # Events: change (the pick's data, or the head's :pick), fold (key, open), press (button index),
      # side (control key, step).
      class PageView < Stack
        # The share of its width the list takes unless told.
        LIST_SHARE = 0.45

        # Height of the head, and the side of its picture.
        HEAD_HEIGHT = 64

        # Room between the head and the body, and inside the head.
        HEAD_GAP = 8

        # Room between the list and the pane.
        BODY_GAP = 16

        # Side of the picture beside the pane's title.
        PANE_PICTURE = 48

        # Width of a button beside the pane's title.
        BUTTON_WIDTH = 80

        # Room between two paragraphs of the pane, and a :gap line's height.
        PARAGRAPH_GAP = 10

        # Size of a gauge in the pane.
        GAUGE_SIZE = [160, 12]

        # The most columns of things named in the pane.
        ITEM_COLUMNS = 4

        # Side of the picture of a character beside a thing named.
        ITEM_PICTURE = 24

        # Room the entries under a group stand in from it.
        ENTRY_INDENT = 8

        # The most lines of the head under its title.
        HEAD_LINES = 2

        # The most rows of the head's grid, two a line.
        HEAD_GRID = 4

        # What starts an open group's row.
        OPEN_MARK = "▾ "

        # What starts a closed group's row.
        CLOSED_MARK = "▸ "

        # The head, a stop of the keys while it has a :pick.
        class Head < Stack
          # @return [PageView, nil] The view it heads.
          attr_accessor :view

          # Takes an event of C#'s tree: taking the focus picks the head.
          #
          # @param name [String] The event.
          # @param values [Array] Its value, if it has one.
          def receive(name, *values)
            super
            @view.head_picked if name == "focus" && @view
          end
        end

        # Tells the defaults of the options: a column that takes the room it is given, the list
        # LIST_SHARE wide.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => HEAD_GAP, :grow => 1, :list_share => LIST_SHARE, :root_pages => true, :label_width => nil)
        end

        options :list_share, :root_pages, :label_width

        # @return [List] The list of entries.
        attr_reader :list

        # @return [Box] The reading pane.
        attr_reader :pane

        # Makes the view with its head, list and pane.
        #
        # @param options [Hash] :list_share, :root_pages, :label_width and the options of a container.
        def initialize(options = {})
          super
          @head = Head.new(:layout => :row, :height => HEAD_HEIGHT, :gap => HEAD_GAP, :visible => false)
          @head.view = self
          @head.on(:click) { head_picked }
          add(@head)
          body = add_row(:grow => 1, :gap => BODY_GAP)
          @list = body.add_list(:round => true, :leave_ends => true, :rows_shown => :fill, :shoulder_pages => false, :pages_beside => true,
                                :label_width => @options[:label_width])
          body.add_divider(:direction => :vertical)
          @pane = body.add_box(:frame => false, :scroll => true, :grow => 1, :cancel_to => @list, :gap => 4, :focusable => true, :jump_only => true,
                               :keep_ends => true)
          @list.on(:change) { |row, _index| moved(row) }
          @list.on(:submit) { |row, _index| taken(row) }
          @groups_open = {}
          @buttons = []
          @controls = []
        end

        # Sets the head, see the class; nil for none.
        #
        # @param value [Hash, nil] The head.
        def head=(value)
          return if value == @head_value

          @head_value = value
          @head.clear
          @head.visible = value ? true : false
          @head.clickable = value && value.key?(:pick) ? true : false
          build_head(value) if value
        end

        # Puts parts into the head in place of a head= Hash; the head fits them, and with a pick it is
        # a stop of the keys above the list that tells change with the pick as it takes the focus.
        #
        # @param parts [Array<Component>] The parts, none to hide the head.
        # @param pick [Object, nil] What the head stands for, nil for no stop of the keys.
        def head_parts(parts, pick = nil)
          unless @head_markup
            @head_markup = true
            @head_value = nil
            @head.clear
            @head.height = nil
          end
          keep(@head, parts)
          @head_pick = pick
          @head.visible = !parts.empty?
          @head.clickable = !pick.nil?
        end

        # Puts parts into the pane in place of a pane= Hash; confirm on an entry then moves the focus
        # onto the first of them that takes the keys.
        #
        # @param parts [Array<Component>] The parts.
        def pane_parts(parts)
          unless @pane_markup
            @pane_markup = true
            @pane_value = nil
            @pane.clear
          end
          keep(@pane, parts)
        end

        # Puts the cursor on the entry of some data without telling change, and the focus with it
        # once the focus comes back to the view.
        #
        # @param data [Object] The entry's :data, or the head's pick.
        def pick(data)
          return @picked = data if !data.nil? && data == head_pick

          place = @list.rows.index { |row| row.is_a?(Hash) && !row.key?(:page_group) && row.key?(:data) && row[:data] == data }
          return unless place

          @picked = data
          @list.index = place unless @list.index == place
        end

        # Sets the rows of the list, see the class; a group's :open given sets its fold.
        #
        # @param rows [Array<Hash, String>] The rows.
        def rows=(rows)
          rows = Array(rows)
          return if rows == @rows

          @rows = rows
          rows.each { |row| @groups_open[row[:group]] = row[:open] ? true : false if group?(row) && row.key?(:open) }
          show_rows
        end

        # Sets the pane, see the class; nil for an empty one.
        #
        # @param value [Hash, nil] The pane.
        def pane=(value)
          return if value == @pane_value

          same = pane_frame(value) == pane_frame(@pane_value)
          @pane_value = value
          same ? refresh_pane(value) : rebuild_pane(value)
          return if @picked == @pane_picked

          @pane_picked = @picked
          @pane.scroll_to(0)
        end

        # Gives the focus to what was picked there last: its head while it has a :pick and nothing
        # else was picked since, else its list.
        #
        # @return [PageView] Itself.
        def focus
          pick = head_pick
          head = !pick.nil? && (@picked.nil? || @picked == pick)
          (head ? @head : @list).focus
          self
        end

        # Tells whether the focus lies in the pane, on one of its buttons or controls.
        #
        # @return [Boolean] Whether it does.
        def in_pane?
          part = Tree.focused
          part = part.parent while part && !part.equal?(@pane)
          part ? true : false
        end

        # Tells the head was picked by the keys or a click: change with its :pick.
        def head_picked
          pick = head_pick
          return if pick.nil?

          @pane.scroll_to(0) if @pane_markup && @picked != pick
          @picked = pick
          emit(:change, pick)
        end

        # Tells what the head stands for: its :pick, or the pick head_parts gave.
        #
        # @return [Object, nil] The pick, nil while the head is no stop of the keys.
        def head_pick
          @head_value ? @head_value[:pick] : @head_pick
        end

        # Takes the place C# gave it: the list takes its share of the width, the pane the rest; with
        # :root_pages the game's L and R scroll the pane once it lies in a root.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          width = (@rect.width * @options[:list_share].to_f).round
          @list.width = width unless @list.width == width
          listen_to_pages
        end

        private

        # Follows a changed option: the list takes the width of the labels' column.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          @list.label_width = @options[:label_width] if name == :label_width && @list
        end

        # Keeps exactly some parts in a container, in their order.
        #
        # @param container [Component] The head or the pane.
        # @param parts [Array<Component>] The parts.
        def keep(container, parts)
          return if container.children == parts

          (container.children - parts).each { |child| container.remove(child) }
          parts.each_with_index { |child, place| container.add(child, place) unless container.children[place].equal?(child) }
        end

        # Shows the rows in the list, those under a folded group left out and those under any group
        # standing in from it.
        def show_rows
          grouped = false
          open = true
          shown = []
          @rows.each do |row|
            if group?(row)
              grouped = true
              open = @groups_open.fetch(row[:group], true)
              shown << list_row(row.merge(:open => open))
            elsif open
              made = list_row(row)
              indent = grouped && made.is_a?(Hash) && !made.key?(:heading) && !made.key?(:indent)
              shown << (indent ? made.merge(:indent => ENTRY_INDENT) : made)
            end
          end
          @list.rows = shown
        end

        # Tells whether a row of the view is a group's.
        #
        # @param row [Hash, String] The row.
        # @return [Boolean] Whether it is.
        def group?(row)
          row.is_a?(Hash) && row.key?(:group)
        end

        # Takes Ctrl on a button or a control of the pane back to the list, as cancel does there.
        #
        # @param button [Symbol] The game's button that went down.
        def pane_button(button)
          return unless button == :CTRL

          Sound.play_cancel
          @list.focus
        end

        # Lays the head out: its picture, its title and note, and its lines or its grid.
        #
        # @param value [Hash] The head.
        def build_head(value)
          add_picture_to(@head, value, HEAD_HEIGHT)
          text = @head.add_column(:grow => 1, :gap => 2)
          top = text.add_row(:gap => HEAD_GAP)
          top.add_label(value[:title].to_s, :font_size => :small, :color => :system, :shrink => true)
          top.add_column(:grow => 1)
          top.add_label(value[:note].to_s, :font_size => :small, :color => :dim) unless value[:note].nil?
          return build_head_grid(text, value[:grid]) if value[:grid]

          lines = Array(value[:lines]).map { |line| line.to_s }
          text.add_label(lines.join("\n"), :wrap => true, :most_lines => HEAD_LINES, :font_size => :small) unless lines.empty?
        end

        # Lays the head's grid out, two rows of cells a line, the first cell giving way.
        #
        # @param text [Component] The column under the head's title.
        # @param rows [Array<Array>] The rows, each cells of a String or { :text, :color }.
        def build_head_grid(text, rows)
          grid = text.add_grid(2, :gap => 4)
          Array(rows).first(HEAD_GRID).each do |cells|
            row = grid.add_row(:gap => 6)
            Array(cells).each_with_index do |cell, index|
              look = cell.is_a?(Hash) ? cell : { :text => cell }
              row.add_label(look[:text].to_s, :font_size => :small, :color => look[:color] || (index == 0 ? :text : :dim), :shrink => index == 0)
            end
          end
        end

        # Adds a framed picture of a head or a pane, when it has one.
        #
        # @param parent [Component] Where it goes.
        # @param value [Hash] The head or the pane: :face, :figure, :portrait or :icon.
        # @param side [Integer] The picture's side.
        def add_picture_to(parent, value, side)
          look = [:face, :figure, :portrait].find { |key| value[key] }
          return unless look || value[:icon]

          frame = parent.add_box(:size => [side, side])
          look ? frame.add_picture(look => value[look], :fit => :contain, :grow => 1) : frame.add_icon(value[:icon], :scale => 2)
        end

        # Tells what of a pane only a rebuild shows: everything but the texts and states of its
        # buttons and the values of its controls.
        #
        # @param value [Hash, nil] The pane.
        # @return [Hash, nil] Its frame.
        def pane_frame(value)
          return value unless value.is_a?(Hash)

          lines = Array(value[:lines]).map { |line| control?(line) ? [:control, line[:control]] : line }
          value.merge(:buttons => Array(value[:buttons]).size, :lines => lines)
        end

        # Tells whether a line of the pane is a control.
        #
        # @param line [Object] The line.
        # @return [Boolean] Whether it is.
        def control?(line)
          line.is_a?(Hash) && line.key?(:control)
        end

        # Changes the texts and states of the pane's buttons and the rows of its controls in place, so
        # the focus, the cursors and the scroll stay.
        #
        # @param value [Hash] The pane, of the same frame as the one shown.
        def refresh_pane(value)
          Array(value[:buttons]).each_with_index do |button, index|
            look = button_look(button)
            made = @buttons[index]
            made.text = look[:text] unless made.text == look[:text]
            made.enabled = look[:enabled] unless made.enabled == look[:enabled]
          end
          runs = control_runs(Array(value[:lines]))
          @controls.each_with_index { |list, index| list.rows = control_rows(runs[index]) }
        end

        # Lays the pane out anew, the focus and the cursors handed to the new buttons and controls of
        # the same place and key.
        #
        # @param value [Hash, nil] The pane.
        def rebuild_pane(value)
          kept = @controls.map { |list| list.index.to_i >= 0 ? list.rows[list.index.to_i] : nil }.select { |row| row.is_a?(Hash) }.map { |row| row[:key] }
          @pane.clear
          @buttons = []
          @controls = []
          build_pane(value, kept) if value
        end

        # Lays the pane out: the title row with its picture and buttons, the subtitle and the lines.
        #
        # @param value [Hash] The pane.
        # @param kept [Array] The keys of the controls the cursors stood on.
        def build_pane(value, kept)
          top = @pane.add_row(:gap => HEAD_GAP)
          add_picture_to(top, value, PANE_PICTURE)
          heading = top.add_column(:grow => 1, :gap => 2)
          title = heading.add_row(:gap => 6)
          title.add_label(value[:title].to_s, :font_size => :small, :color => :system, :shrink => true, :grow => 1)
          Array(value[:buttons]).each_with_index do |button, index|
            look = button_look(button)
            made = title.add_button(look[:text], :width => BUTTON_WIDTH, :font_size => :small, :enabled => look[:enabled], :id => "#{focus_base}:button:#{index}",
                                    :buttons => [:CTRL])
            made.on(:click) { pressed(index) }
            made.on(:button) { |button| pane_button(button) }
            @buttons << made
          end
          heading.add_label(value[:subtitle].to_s, :font_size => :small, :color => :dim) if value[:subtitle]
          build_lines(Array(value[:lines]), kept)
        end

        # Tells how a button of the pane looks.
        #
        # @param button [Hash, String] { :text, :disabled } or a text.
        # @return [Hash] Its :text and whether it is :enabled.
        def button_look(button)
          look = button.is_a?(Hash) ? button : { :text => button }
          { :text => look[:text].to_s, :enabled => look[:disabled] != true }
        end

        # Tells what the focus keys of the pane's parts start with: its :id, else its own.
        #
        # @return [String] The start.
        def focus_base
          @options[:id].nil? ? "page#{object_id}" : @options[:id].to_s
        end

        # Lays out the pane's lines in their order, the controls in a row of each run of them.
        #
        # @param lines [Array] The lines, see the class.
        # @param kept [Array] The keys of the controls the cursors stood on.
        def build_lines(lines, kept)
          controls = []
          last = nil
          lines.each do |line|
            if control?(line)
              controls << line
              next
            end
            add_controls(controls, kept)
            controls = []
            @pane.add_column(:height => PARAGRAPH_GAP) if line.is_a?(String) && last.is_a?(String)
            add_line(line)
            last = line
          end
          add_controls(controls, kept)
        end

        # Splits the pane's lines into the runs of controls next to each other.
        #
        # @param lines [Array] The lines.
        # @return [Array<Array<Hash>>] The runs.
        def control_runs(lines)
          runs = [[]]
          lines.each { |line| control?(line) ? runs.last << line : runs << [] }
          runs.reject { |run| run.empty? }
        end

        # Adds one line of the pane.
        #
        # @param line [String, Symbol, Hash] The line.
        def add_line(line)
          return @pane.add_label(line, :wrap => true) if line.is_a?(String)
          return @pane.add_column(:height => PARAGRAPH_GAP) if line == :gap
          return unless line.is_a?(Hash)
          return add_items(Array(line[:items])) if line.key?(:items)

          row = @pane.add_row(:gap => HEAD_GAP)
          row.add_gauge(:rate => line[:gauge].to_f, :size => GAUGE_SIZE, :colors => line[:color] || :bad)
          row.add_label(line[:text].to_s, :font_size => :small) if line[:text]
        end

        # Adds things named, in as many columns as fit.
        #
        # @param items [Array<Hash, String>] Each { :text, :icon, :note, :faint }, or with a :face,
        #   :figure or :portrait in place of the icon, or a text.
        def add_items(items)
          grid = @pane.add_grid(:fit, :most_columns => ITEM_COLUMNS)
          items.each do |item|
            look = item.is_a?(Hash) ? item : { :text => item }
            cell = grid.add_row(:gap => 4)
            picture = [:face, :figure, :portrait].find { |key| look[key] }
            if picture
              cell.add_picture(picture => look[picture], :size => [ITEM_PICTURE, ITEM_PICTURE], :fit => :contain)
            elsif look[:icon]
              cell.add_icon(look[:icon])
            end
            cell.add_label(look[:text].to_s, :shrink => true, :faint => look[:faint] ? true : false)
            cell.add_label(look[:note].to_s, :font_size => :small, :color => :dim) if look[:note]
          end
        end

        # Adds a run of controls as a list Left and Right change, the cursor on the control it stood on.
        #
        # @param controls [Array<Hash>] The controls.
        # @param kept [Array] The keys of the controls the cursors stood on.
        def add_controls(controls, kept)
          return if controls.empty?

          rows = control_rows(controls)
          index = rows.index { |row| kept.include?(row[:key]) } || 0
          list = @pane.add_list(:rows => rows, :index => index, :sides => true, :most_rows => rows.size, :cancel_to => @list,
                                :id => "#{focus_base}:controls:#{@controls.size}", :buttons => [:CTRL])
          list.on(:side) { |row, _index, step| adjusted(row[:key], step) }
          list.on(:button) { |button| pane_button(button) }
          @controls << list
        end

        # Makes the list's rows of a run of controls.
        #
        # @param controls [Array<Hash>] The controls.
        # @return [Array<Hash>] The rows.
        def control_rows(controls)
          controls.map do |control|
            { :key => control[:control], :text => control[:text].to_s, :value => control[:value].to_s, :color => control[:color],
              :less => control[:less] != false, :more => control[:more] != false }
          end
        end

        # Makes a row of the list from a row of the view.
        #
        # @param row [Hash, String] The row.
        # @return [Hash, String] The list's row.
        def list_row(row)
          return row unless row.is_a?(Hash)

          if group?(row)
            { :key => [:page_group, row[:group]], :text => (row[:open] ? OPEN_MARK : CLOSED_MARK) + row[:text].to_s, :color => :system,
              :page_group => row[:group], :open => row[:open] ? true : false }
          elsif row.key?(:none)
            { :heading => row[:none].to_s, :color => :dim }
          else
            row
          end
        end

        # Follows the cursor onto a row: change with an entry's data.
        #
        # @param row [Hash, String] The list's row.
        def moved(row)
          return if row.is_a?(Hash) && row.key?(:page_group)

          data = row.is_a?(Hash) ? row[:data] : row
          @pane.scroll_to(0) if @pane_markup && @picked != data
          @picked = data
          emit(:change, data)
        end

        # Takes confirm or a click on a row: a group folds, an entry moves the focus into the pane.
        #
        # @param row [Hash, String] The list's row.
        def taken(row)
          return fold(row) if row.is_a?(Hash) && row.key?(:page_group)
          return Tree.focus_in(@pane) if @pane_markup

          target = @controls.first || @buttons.find { |button| button.enabled? }
          target ? target.focus : Tree.focus_in(@pane)
        end

        # Folds or opens a group and tells fold with its key and whether it opens, for an owner who
        # keeps the folds.
        #
        # @param row [Hash] The group's row.
        def fold(row)
          key = row[:page_group]
          open = !row[:open]
          @groups_open[key] = open
          emit(:fold, key, open)
          show_rows
        end

        # Takes a press of a button of the pane: press with its place.
        #
        # @param index [Integer] The button.
        def pressed(index)
          emit(:press, index)
        end

        # Takes Left or Right on a control: side with its key and the step.
        #
        # @param key [Object] The control.
        # @param step [Integer] -1 or 1.
        def adjusted(key, step)
          emit(:side, key, step)
        end

        # Has the game's L and R scroll the pane a page while it shows, once it lies in a root, with
        # :root_pages.
        def listen_to_pages
          return if @pages_heard || root.equal?(self) || !@options[:root_pages]

          @pages_heard = true
          root.on(:page) { |step, _pad| @pane.scroll_page(step) if shown? }
        end
      end
    end
  end
end
