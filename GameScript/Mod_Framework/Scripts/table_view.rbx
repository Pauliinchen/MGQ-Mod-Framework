#----------------------------------------------------------------
#  table_view.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Handed the table's highlight to its list
#      Paulinchen  2026-11-06: Showed the dots after the pages around the page shown as well as those before them
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A table: a row of column headers over a list whose rows hold a cell for each column, and a
      # pagination under the list while its rows take more than one page. Each of :table_columns is
      # { :title, :width (pixels, nil to share the room left), :align, :sortable }; the header of a
      # sortable column is a stop of the keys, and confirm or a click on it tells sort with the
      # column's place. :sorted ([place, :asc or :desc]) marks the column the rows are sorted by.
      # :pages and :page (from 1) are the pagination's; a page picked there tells page. The rows,
      # their widths and their height go to its list, which tells change and submit as a List does.
      # Without rows the list shows :empty_text in a dim line under the headers.
      #
      # Events: sort (the column's place), page (the page picked, from 1).
      class Table < Stack
        # The mark after the title of the column the rows are sorted by, for each direction.
        SORT_MARKS = { :asc => " ▲", :desc => " ▼" }

        # What a table without rows says under its headers, as MudTable's NoRecordsContent.
        EMPTY_TEXT = "No entries"

        # The options it hands its list, by the list's names of them.
        LIST_OPTIONS = { :rows => :rows, :most_rows => :most_rows, :rows_shown => :rows_shown, :row_height => :row_height,
                         :empty_text => :empty_text, :list_acts => :acts, :highlight => :highlight }

        # What :rows_shown names to show as many rows as the list's room holds.
        FILL_ROWS = :fill

        # Tells the defaults of the options: no columns and no rows, on its only page.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 2, :table_columns => [], :sorted => nil, :pages => 1, :page => 1, :rows => [], :most_rows => List::SHOWN,
                      :rows_shown => nil, :row_height => nil, :empty_text => EMPTY_TEXT, :list_acts => nil, :highlight => nil)
        end

        options :table_columns, :sorted, :pages, :page, :rows, :most_rows, :rows_shown, :row_height, :empty_text, :list_acts, :highlight

        # @return [Stack] The row of column headers.
        attr_reader :header

        # @return [TableList] The list of rows.
        attr_reader :list

        # @return [Pagination] The pagination under the list.
        attr_reader :pagination

        # Makes the table with its headers, its list and its pagination.
        #
        # @param options [Hash] Its options, see defaults and the class.
        def initialize(options = {})
          super
          @header = add(Stack.new(:layout => :row, :gap => List::TABLE_GAP))
          @list = add(TableList.new(:cells => []))
          @list.table = self
          @pagination = add(Pagination.new(:visible => false, :align => :center))
          @pagination.on(:change) { |page| emit(:page, page) }
          @header_labels = []
          LIST_OPTIONS.each_key { |name| hand_to_list(name) }
          build_header
          show_pages
          bar_shown(false)
        end

        # Tells the row the list's cursor is on.
        #
        # @return [Integer] Its place among the rows shown, -1 for none.
        def index
          @list.index
        end

        # Puts the list's cursor on a row.
        #
        # @param value [Integer] Its place among the rows shown, -1 for none.
        def index=(value)
          @list.index = value
        end

        # Lines the headers up with the cells as the list shows its scrollbar or takes it away, so
        # each title stands over its column.
        #
        # @param bar [Boolean] Whether the list shows its scrollbar.
        def bar_shown(bar)
          _top, right, _bottom, left = @list.send(:padding_sides)
          wanted = [0, right + List::INSET + (bar ? Style::SCROLLBAR_WIDTH + List::BAR_GAP : 0), 0, left + List::INSET]
          @header.padding = wanted unless @header.padding == wanted
        end

        private

        # Follows a changed option: the list takes its own, new columns make the headers anew, a new
        # sort marks them, and the pages reach the pagination.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @list

          hand_to_list(name) if LIST_OPTIONS.key?(name)
          build_header if name == :table_columns
          mark_sort if name == :sorted
          show_pages if name == :pages || name == :page
        end

        # Hands one of its options to its list: :rows_shown => :fill grows the table and its list
        # too.
        #
        # @param name [Symbol] The option.
        def hand_to_list(name)
          @list.send("#{LIST_OPTIONS[name]}=", @options[name])
          return unless name == :rows_shown

          fills = @options[:rows_shown] == FILL_ROWS
          @list.grow = fills ? 1 : 0
          self.grow = 1 if fills && @options[:grow].to_i == 0
        end

        # Makes the headers anew once the columns changed, one a column, as wide as its cells: a
        # sortable column's a stop of the keys that tells sort, the others plain titles; the list
        # takes the widths.
        def build_header
          columns = Array(@options[:table_columns])
          return if columns == @built_columns

          @built_columns = columns
          @header.clear
          @list.cells = columns.empty? ? nil : columns.map { |column| column[:width] }
          @header.visible = columns.any? { |column| !column[:title].to_s.empty? }
          @header_labels = columns.each_with_index.map do |column, place|
            room = column[:width] ? { :width => column[:width], :grow => 0 } : { :width => 0, :grow => 1 }
            look = { :text => header_text(column, place), :font_size => :small, :color => :system, :align => column[:align] || :start, :shrink => true }
            next @header.add(Label.new(look.merge(room))) unless column[:sortable]

            cell = @header.add(Stack.new(room.merge(:layout => :row, :clickable => true, :jump_only => true, :id => "#{focus_base}:sort:#{place}")))
            cell.on(:click) { emit(:sort, place) }
            cell.add(Label.new(look.merge(:grow => 1)))
          end
        end

        # Writes the sort's mark after the title of the column the rows are sorted by, and takes it
        # off the others.
        def mark_sort
          columns = Array(@options[:table_columns])
          @header_labels.each_with_index { |label, place| label.text = header_text(columns[place] || {}, place) }
        end

        # Tells a header's text: the column's title, with the sort's mark while the rows are sorted
        # by it.
        #
        # @param column [Hash] The column.
        # @param place [Integer] Its place.
        # @return [String] The text.
        def header_text(column, place)
          place_sorted, direction = @options[:sorted]
          text = column[:title].to_s
          place_sorted == place && SORT_MARKS[direction] ? text + SORT_MARKS[direction] : text
        end

        # Shows the pagination while the rows take more than one page, and has Page Up and Page
        # Down turn the page then.
        def show_pages
          pages = [@options[:pages].to_i, 1].max
          @pagination.count = pages
          @pagination.page = @options[:page]
          @pagination.visible = pages > 1
          @list.own_pages = pages > 1
        end

        # Tells what the focus keys of its headers start with: its :id, else its own.
        #
        # @return [String] The start.
        def focus_base
          @options[:id].nil? ? "table#{object_id}" : @options[:id].to_s
        end
      end

      # The list of a Table, which tells the table whether it shows its scrollbar as it draws, so the
      # headers stay over their columns. With :own_pages, while the table shows a page of its rows at
      # a time, Page Up, Page Down and the shoulders that page it tell page_step instead of moving
      # its cursor.
      #
      # Events: page_step (-1 for the page before, 1 for the next), and those of a List.
      class TableList < List
        # Tells the defaults of the options: its cursor pages as a List's does.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:own_pages => false)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:own_pages => ["own_pages"])
        end

        options :own_pages

        # @return [Table, nil] The table it lies in.
        attr_accessor :table

        # Tells the properties C#'s tree lays it out by, with whether its table turns its pages.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["own_pages"] = @options[:own_pages] ? true : false
          props
        end

        # Takes an event of C#'s tree: page_step tells the step, the others go as a List's do.
        #
        # @param name [String] The event.
        # @param values [Array] Its values.
        def receive(name, *values)
          return emit(:page_step, values[0].to_i) if name == "page_step"

          super
        end

        # Draws the rows as a List does, then tells its table whether the scrollbar shows.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_part(canvas)
          super
          _top, shown, total = @scrolling || [0, canvas.height / line_height, lines_of(drawn_rows.size)]
          @table.bar_shown(total > shown) if @table
        end
      end

      # Pages to pick from, as MudPagination draws them: a button back, a button for each page and a
      # button on, the page shown filled. With many pages it shows the first, the last and those
      # around the page shown, "..." between. Left and Right walk its buttons, confirm or a click
      # picks one.
      #
      # Events: change (the page picked, from 1).
      class Pagination < Stack
        # The text of the button back.
        BACK_TEXT = "<"

        # The text of the button on.
        ON_TEXT = ">"

        # What stands for pages left out.
        GAP_TEXT = "..."

        # The most page buttons before pages are left out.
        MOST_BUTTONS = 7

        # Tells the defaults of the options: one page, the first shown.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => Style::GAP, :count => 1, :page => 1)
        end

        options :count, :page

        # Makes the pagination with its buttons.
        #
        # @param options [Hash] :count, :page and the options of a container.
        def initialize(options = {})
          super
          @built = true
          build
        end

        # Tells the pages it shows a button for, nil where pages are left out: all of them up to
        # MOST_BUTTONS, else the first, the last and three around the page shown.
        #
        # @param count [Integer] How many pages there are.
        # @param page [Integer] The page shown.
        # @return [Array<Integer, nil>] The pages.
        def self.pages_shown(count, page)
          return (1..count).to_a if count <= MOST_BUTTONS

          middle = [[page, 3].max, count - 2].min
          shown = [1]
          shown << nil if middle - 1 > 2
          shown.concat((middle - 1..middle + 1).to_a)
          shown << nil if middle + 1 < count - 1
          shown << count
        end

        # Picks a page, as a press of its button does: change tells it.
        #
        # @param page [Integer] The page, kept within its pages.
        def pick(page)
          page = [[page.to_i, 1].max, count_now].min
          return if page == @options[:page]

          self.page = page
          emit(:change, page)
        end

        private

        # Follows a changed option: its buttons are made anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          build if @built && (name == :count || name == :page)
        end

        # Tells how many pages there are, at least one.
        #
        # @return [Integer] The pages.
        def count_now
          [@options[:count].to_i, 1].max
        end

        # Makes its buttons anew; each keeps the focus by its id.
        def build
          clear
          page = @options[:page].to_i
          add_button(BACK_TEXT, page - 1, page > 1, :back)
          self.class.pages_shown(count_now, page).each do |shown|
            next add(Label.new(:text => GAP_TEXT, :color => :dim)) if shown.nil?

            add_button(shown.to_s, shown, true, shown, shown == page)
          end
          add_button(ON_TEXT, page + 1, page < count_now, :on)
        end

        # Adds one button that picks a page.
        #
        # @param text [String] Its text.
        # @param page [Integer] The page it picks.
        # @param enabled [Boolean] Whether it takes a press.
        # @param name [Object] What tells it apart in its focus key.
        # @param shown [Boolean] Whether it is the page shown, drawn filled.
        def add_button(text, page, enabled, name, shown = false)
          base = @options[:id].nil? ? "pages#{object_id}" : @options[:id].to_s
          button = add(Button.new(:text => text, :enabled => enabled, :variant => shown ? :filled : :text, :font_size => :small, :id => "#{base}:#{name}"))
          button.on(:click) { pick(page) }
        end
      end
    end
  end
end
