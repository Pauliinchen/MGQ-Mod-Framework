#----------------------------------------------------------------
#  layer_pages.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Kept the sort and the open given last on the part
#      Paulinchen  2026-11-06: Kept the group rows and none lines a page view's owner lays out apart from its items
#      Paulinchen  2026-11-05: Showed the items of a page view under their groups, its head and its pane, and handed its pick and its folds on
#                            - Opened and shut an expansion panel by its bound state or by its open: given anew, and told its folds
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      module Layer
        # The direction a sort takes after each, from unsorted on: up, down, then unsorted again.
        NEXT_SORT = { nil => :asc, :asc => :desc, :desc => nil }

        # Hands what a table's list and pagination tell to the table's bound state and handlers.
        #
        # @param part [Part] The table's part.
        def self.wire_table(part)
          engine = part.engine
          engine.list.on(:change) { |_row, index| list_moved(part, index) }
          engine.list.on(:submit) { |_row, index| list_submitted(part, index) }
          engine.on(:sort) { |place| table_sorted(part, place) }
          engine.on(:page) { |page| table_paged(part, page) }
          engine.list.on(:page_step) { |step| table_stepped(part, step) }
        end

        # Shows a table's items: those its filter: keeps, in the order of its sort, the page shown of
        # them, each a row of a cell a column; the cursor goes to its bound item, turning to that
        # item's page unless the player just turned the page.
        #
        # @param part [Part] The table's part.
        # @param follow_bind [Boolean] Whether it turns to the page of its bound item.
        def self.show_table(part, follow_bind = true)
          params = part.node.params
          engine = part.engine
          columns = table_columns(part)
          items = Array(params[:items])
          items = items.select { |item| Builtins.per_item(params[:filter], item) } if params[:filter]
          sort = table_sort(part, columns)
          items = sorted_items(items, columns[sort[0]], sort[1]) if sort && columns[sort[0]]
          per_page = params[:rows_per_page].to_i
          per_page = items.size if per_page <= 0
          pages = per_page > 0 ? [(items.size + per_page - 1) / per_page, 1].max : 1
          page = [[engine.page.to_i, 1].max, pages].min
          bound = follow_bind ? bound_place(part, items) : nil
          page = bound / per_page + 1 if bound && per_page > 0
          shown = items[(page - 1) * per_page, per_page] || []
          quietly do
            engine.table_columns = columns.map { |column| { :title => column[:title].to_s, :width => column[:width], :align => column[:align], :sortable => column[:sortable] == true } }
            engine.rows = shown.map { |item| { :cells => columns.map { |column| table_cell(column, item) } } }
            engine.pages = pages
            engine.page = page
          end
          bind_list(part, shown)
        end

        # Tells the place among a table's items of the item its bind: holds, nil for none.
        #
        # @param part [Part] The table's part.
        # @param items [Array] The items in the order shown.
        # @return [Integer, nil] The place.
        def self.bound_place(part, items)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return nil unless bind && owner.is_a?(UI::Component) && owner.class.states.key?(bind)

          items.index(owner.__send__(bind))
        end
        private_class_method :bound_place

        # Tells the columns of a table that show, as their params.
        #
        # @param part [Part] The table's part.
        # @return [Array<Hash>] The columns' params.
        def self.table_columns(part)
          parts = []
          collect_parts(part.children, parts)
          parts.select { |each| each.node.type == :column && each.node.params[:visible] != false }.map { |each| each.node.params }
        end
        private_class_method :table_columns

        # Tells the column and the direction a table's rows are sorted by: its sort: when the owner
        # gives it anew, else the player's last sort.
        #
        # @param part [Part] The table's part.
        # @param columns [Array<Hash>] The columns' params.
        # @return [Array, nil] The column's place and :asc or :desc, nil for unsorted.
        def self.table_sort(part, columns)
          engine = part.engine
          given = part.node.params[:sort]
          return engine.sorted if part.sort_given == [given]

          part.sort_given = [given]
          name, direction = given.is_a?(Array) ? given : [given, :asc]
          place = given.nil? ? nil : columns.index { |column| (!column[:id].nil? && column[:id] == name) || column[:title].to_s == name.to_s }
          quietly { engine.sorted = place ? [place, direction == :desc ? :desc : :asc] : nil }
          engine.sorted
        end
        private_class_method :table_sort

        # Sorts items by what a column shows, keeping the order of the items that show the same;
        # empty values go last.
        #
        # @param items [Array] The items.
        # @param column [Hash] The column's params.
        # @param direction [Symbol] :asc or :desc.
        # @return [Array] The items sorted.
        def self.sorted_items(items, column, direction)
          keyed = items.each_with_index.map { |item, place| [sort_value(column, item), place, item] }
          keyed.sort! do |a, b|
            order = compare_values(a[0], b[0])
            order = -order if direction == :desc && !a[0].nil? && !b[0].nil?
            order == 0 ? a[1] <=> b[1] : order
          end
          keyed.map { |entry| entry[2] }
        end
        private_class_method :sorted_items

        # Tells what an item sorts by in a column: its value, a cell's :text.
        #
        # @param column [Hash] The column's params.
        # @param item [Object] The item.
        # @return [Object] The value, nil for an empty one.
        def self.sort_value(column, item)
          value = column[:value] ? Builtins.per_item(column[:value], item) : item
          value = value[:text] if value.is_a?(Hash)
          value.is_a?(String) && value.empty? ? nil : value
        end
        private_class_method :sort_value

        # Compares two values a column shows: numbers by size, anything else by its text in any
        # case, an empty value after the others.
        #
        # @param a [Object] One value.
        # @param b [Object] The other.
        # @return [Integer] -1, 0 or 1.
        def self.compare_values(a, b)
          return (a.nil? ? 1 : 0) - (b.nil? ? 1 : 0) if a.nil? || b.nil?
          return a <=> b if a.is_a?(Numeric) && b.is_a?(Numeric)

          a.to_s.casecmp(b.to_s)
        end
        private_class_method :compare_values

        # Tells the cell of an item in a column: its text, its own color, the column's alignment and
        # the item's icon there.
        #
        # @param column [Hash] The column's params.
        # @param item [Object] The item.
        # @return [Hash] The cell.
        def self.table_cell(column, item)
          value = column[:value] ? Builtins.per_item(column[:value], item) : item
          cell = value.is_a?(Hash) ? { :text => value[:text].to_s, :color => Builtins.color(value[:color]) } : { :text => value.to_s }
          cell[:align] = column[:align] if column[:align]
          icon = column[:icon] ? Builtins.per_item(column[:icon], item) : nil
          cell[:icons] = [icon] if icon
          cell
        end
        private_class_method :table_cell

        # Takes a press on a sortable column's title: the rows sort by it up, down, then unsorted
        # again, and on_sort hears the column and the direction.
        #
        # @param part [Part] The table's part.
        # @param place [Integer] The column's place.
        def self.table_sorted(part, place)
          return if @applying || part.gone

          column = table_columns(part)[place]
          return unless column && column[:sortable]

          engine = part.engine
          now = engine.sorted
          direction = NEXT_SORT[now && now[0] == place ? now[1] : nil]
          quietly { engine.sorted = direction ? [place, direction] : nil }
          show_table(part)
          call_handler(part.node.owner, part.node.params[:on_sort], [column[:id] || column[:title], direction])
        end
        private_class_method :table_sorted

        # Takes a page the player picked in a table's pagination: the table shows it, and its bound
        # state takes the item the cursor lands on.
        #
        # @param part [Part] The table's part.
        # @param page [Integer] The page, from 1.
        def self.table_paged(part, page)
          return if @applying || part.gone

          quietly { part.engine.page = page }
          show_table(part, false)
        end
        private_class_method :table_paged

        # Turns a paged table a page back or on by Page Up or Page Down; on its first or last page
        # the cursor goes to the first or last row instead.
        #
        # @param part [Part] The table's part.
        # @param step [Integer] -1 for the page before, 1 for the next.
        def self.table_stepped(part, step)
          return if part.gone

          engine = part.engine
          page = engine.page.to_i + step
          if page >= 1 && page <= engine.pages.to_i
            Sound.play_cursor
            return table_paged(part, page)
          end

          row = step < 0 ? 0 : engine.rows.size - 1
          return if row < 0 || engine.index == row

          Sound.play_cursor
          engine.index = row
          list_moved(part, row)
        end
        private_class_method :table_stepped

        # Puts a pagination on the page its bound state holds, within its pages, and writes that page
        # back.
        #
        # @param part [Part] The pagination's part.
        def self.follow_pagination(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          engine = part.engine
          wanted = owner.__send__(bind)
          page = wanted.is_a?(Integer) ? [[wanted, 1].max, [engine.count.to_i, 1].max].min : 1
          quietly { engine.page = page } unless engine.page == page
          write_bound(owner, bind, page) unless wanted == page
        end

        # Puts what an expansion panel holds into its body.
        #
        # @param part [Part] The panel's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_panel(part, wanted)
          keep_in(part.engine.body, wanted)
        end

        # Opens or shuts an expansion panel as its bound state holds, else as its open: asks when the
        # owner gives it anew, so the player's fold stays between.
        #
        # @param part [Part] The panel's part.
        def self.follow_panel(part)
          params = part.node.params
          engine = part.engine
          owner = part.node.owner
          if params[:bind]
            return unless bound_state?(owner, params[:bind])

            wanted = owner.__send__(params[:bind]) ? true : false
          else
            given = params[:open] == true
            return if part.open_given == [given]

            part.open_given = [given]
            wanted = given
          end
          quietly { engine.open = wanted } unless engine.open == wanted
        end

        # Takes a panel folded open or shut: its bound state and on_fold hear whether it is open.
        #
        # @param part [Part] The panel's part.
        # @param open [Boolean] Whether it is open now.
        def self.panel_folded(part, open)
          return if @applying || part.gone

          bind = part.node.params[:bind]
          write_bound(part.node.owner, bind, open) if bind
          call_handler(part.node.owner, part.node.params[:on_fold], [open])
        end

        # What a group's entry in a page view says: its title and how many items it holds.
        GROUP_TEXT = "%s (%d)"

        # Hands what a page view tells to its bound state and handlers: the item picked, or the
        # head's pick, and a group folded.
        #
        # @param part [Part] The page view's part.
        def self.wire_page_view(part)
          engine = part.engine
          engine.on(:change) do |data|
            next if @applying || part.gone

            item = page_item(part, data)
            bind = part.node.params[:bind]
            write_bound(part.node.owner, bind, item) if bind
            call_handler(part.node.owner, part.node.params[:on_change], [item])
          end
          engine.on(:fold) do |group, open|
            next if @applying || part.gone

            call_handler(part.node.owner, part.node.params[:on_fold], [group, open])
          end
        end

        # Puts what a page view holds into its head and its pane: page_head and the head: param into
        # the head, the rest into the pane.
        #
        # @param part [Part] The page view's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_page_view(part, wanted)
          heads = []
          collect_parts(part.children, heads)
          heads = heads.select { |each| each.node.type == :page_head || (each.node.type == :slot && each.node.key == :head) }
          head = engine_parts(heads, [])
          pick = heads.map { |each| each.node.params[:pick] }.compact.first
          engine = part.engine
          engine.head_parts(head, pick.nil? ? nil : [:page_head, pick])
          engine.pane_parts(wanted - head)
        end

        # Shows a page view's items as entries under their groups, and puts the cursor on its bound
        # item; a bound state that holds no item there takes the item picked.
        #
        # @param part [Part] The page view's part.
        def self.show_page_view(part)
          params = part.node.params
          items = Array(params[:items])
          part.items = items
          engine = part.engine
          quietly { engine.rows = page_rows(params, items) }
          bind = params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          wanted = owner.__send__(bind)
          head = engine.head_pick
          place = items.index(wanted)
          data = head && head[1] == wanted && !wanted.nil? ? head : (place ? [:page_item, place] : nil)
          quietly { engine.pick(data) } if data
        end

        # Makes a page view's rows: the items without a group first, then each group's row followed
        # by its items, each item's entry carrying its place.
        #
        # @param params [Hash] The page view's params.
        # @param items [Array] The items.
        # @return [Array<Hash, String>] The rows.
        def self.page_rows(params, items)
          groups = []
          members = {}
          loose = []
          items.each_with_index do |item, place|
            group = params[:group] ? Builtins.per_item(params[:group], item) : nil
            next loose << place if group.nil?

            groups << group unless members.key?(group)
            (members[group] ||= []) << place
          end
          rows = loose.map { |place| page_entry(params, items[place], place) }
          groups.each do |group|
            rows << { :group => group, :text => format(GROUP_TEXT, group, members[group].size) }
            members[group].each { |place| rows << page_entry(params, items[place], place) }
          end
          rows
        end
        private_class_method :page_rows

        # Makes a page view's entry of an item: its list row, carrying its place as its data and its
        # key; a group's row or a none line the owner laid out stays as it is, which the cursor
        # never picks as an item.
        #
        # @param params [Hash] The page view's params.
        # @param item [Object] The item.
        # @param place [Integer] Its place among the items.
        # @return [Hash] The entry.
        def self.page_entry(params, item, place)
          row = Builtins.list_row(params, item)
          row = { :text => row.to_s } unless row.is_a?(Hash)
          return row if row.key?(:group) || row.key?(:none)

          row.merge(:data => [:page_item, place], :key => [:page_item, place])
        end
        private_class_method :page_entry

        # Tells the item a page view's data stands for: an entry's item, or the head's pick.
        #
        # @param part [Part] The page view's part.
        # @param data [Array, nil] [:page_item, place] or [:page_head, pick].
        # @return [Object, nil] The item or the pick.
        def self.page_item(part, data)
          return nil unless data.is_a?(Array)

          data[0] == :page_item ? Array(part.items)[data[1]] : data[1]
        end
        private_class_method :page_item
      end
    end
  end
end
