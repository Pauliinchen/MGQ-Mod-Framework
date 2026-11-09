#----------------------------------------------------------------
#  components_list.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Kept a table cell's avatar picture scaled at any factor with the list
#                            - Scaled a table cell's avatar picture at any factor with scale: :auto
#                            - Drew a table cell's avatar face in its hue
#                            - Measured the labels' and the notes' columns from texts, the labels' by default from the labels of all rows
#      Paulinchen  2026-11-08: Drew a table cell's avatar before its text, and a cell in the middle of a higher row
#      Paulinchen  2026-11-07: Wrote the text of a row's toggle that is on in the plain text color unless it has contrast
#                            - Drew the places of the rows' texts, cells and card names that hold :highlight on the picked color
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Rows with an icon, a name, a text at the right and small icons before it; a String row is its
      # text alone, a Hash row takes :label (a name in a column of its own, :label_width wide, as wide
      # as the widest label of all rows by default), :icon, :text, :right, :icons, :color, :faint (its
      # text at half its opacity, such as an empty slot), :note (a small dim text after its text, from
      # the column :note_at on, half the row by default, which gives way to the text and is cut first),
      # :disabled (true greys it, picking it buzzes and the cursor's
      # plate on it stays unlit), :checked (true or false draws a box before its icon, filled while
      # true, as the entries of a menu that turns them on and off; the other rows keep its room; a
      # click on the box picks its row at once, also while the cursor stands on another row) and
      # :data, or :item, which shows an item as the game's menus do, see Label, and :bag. Its cursor
      # moves by the keys and follows the pointer; with :follow_pointer => false a click moves it
      # instead and the row under the pointer is framed, so the pointer can cross the list to what
      # lies past it; left unset, C# frames the row that way in a window of the new UI layer. It scrolls by the wheel, its scrollbar, the arrows, Page Up and Down and, unless
      # :shoulder_pages is false, L and R. Its rows draw on a picture of their own, so a cursor move
      # redraws them alone. Without :rows_shown it is as high as its rows, up to :most_rows (SHOWN),
      # and scrolls the rest. With :rows_shown => :fill it takes the room its column leaves, as one
      # that grows does, and shows only whole rows, as many as that room holds. :index => :first_found
      # starts the cursor on the first row a search can find. A row of an item with :count shows how
      # many the bag holds at its right. With :submit_to a picked row also moves the focus there.
      #
      # With :columns it shows that many rows side by side on each line, filled line by line from the
      # left as the game's equip and item lists do, in cells of one width :cell_gap apart, each row
      # squeezed or cut to its cell: UP and DOWN move the cursor a line, LEFT and RIGHT to the row
      # beside and at the end of a line on to the next or the last, the pointer hits each cell, and
      # :rows_shown, :most_rows and the scrolling count lines. A row cut to its room shows its whole
      # text as its tooltip, unless it has a :tooltip of its own.
      #
      # :row_height makes every line that high, never lower than a line of text. With :share_room
      # and :rows_shown a count, the lines share the height it is placed in, each never lower than
      # that, as rows that fill a box whatever its height. A row with :picture
      # ({:file, :blur, :fit, :badge => {:text, :color}, :label}, see PictureLook) shows as a card: the
      # picture across the top of its cell, then its text squeezed or cut to one line and its :note,
      # small, on the line under it. With :columns that makes a grid of cards that keeps all a list
      # has: the cursor, filters, steering and the wheel. A picture file loads once and is let go once
      # no row names it. With :leave_sides RIGHT on the last row of a line and LEFT on the first
      # move the focus to the part beside the list, level with it, instead of on to the next or the
      # last line; with none there, nothing happens. With :leave_ends UP on its first line goes to the
      # text field that steers it, when one does.
      #
      # The parts after a list of whole rows in its column keep to the column's bottom edge, the rest
      # of the room left between the list and them, so a part docked at the bottom stays there.
      #
      # A :filter shows only the rows that hold its text, in any case: a row's :search (a text, or a
      # block asked once for it), else its text or its item's name; a row with :search => false, such
      # as a Remove row, is no entry: a text leaves it out, and :only keeps it unasked. :only (a block
      # of a row, nil for none) also keeps only the rows it answers true for, such as those the chips
      # over the list allow, and every block narrow gave keeps only the rows it answers true for, so
      # several parts filter one list together. When no row a search can find is left it shows
      # :no_match_text after the rows kept, and with no rows at all :empty_text, in a dim row that
      # takes no pick. A new filter shows the rows from the first, the cursor on the first row a search
      # can find; with :keep_cursor the cursor stays on its row while that still shows, else goes to
      # the nearest row shown, the next one down first. Its index and row_at count the rows shown.
      # :label_width and :note_at take pixels, or texts of which the widest sets the column, the notes'
      # after the room before a row's text. A :note ends NOTE_GAP before the row's right text. A :note or :right may be an Array of parts,
      # each {:text, :icon, :icon_file, :color}, drawn in order: its icon (any icon Canvas#icon
      # draws) or picture file, PART_ICON square, then its text in its own color or the row's; a note of parts cut to its room shows their texts as its
      # tooltip.
      #
      # start_move carries the cursor's row, see Move mode: UP and DOWN, Page Up and Down and the
      # pointer move it to another place, confirm or a click drops it there and cancel puts it back;
      # with :reorder the pointer also drags a row out of its place, and with :move_hotkeys too in a
      # root of the new UI layer C#'s tree moves the cursor's row by the framework's Move Up and Move
      # Down hotkeys, as on the framework's own mod list. A row with :group moves only among the rows
      # of its group.
      #
      # With :sides LEFT and RIGHT on a row with a :value tell side instead of moving the focus, and
      # a click on the value's left or right half does the same; on every other row they move the
      # focus as in a list without it, so a list of values and boxes hands RIGHT on to its neighbour.
      #
      # A row's :toggles are small on/off buttons at its right end, each {:text, :color, :on,
      # :tooltip}, outlined while off and filled while on, which a heading's :toggle_titles titles;
      # RIGHT and LEFT move the cursor from the row's text onto its toggles and back, and confirm or a
      # click on one tells toggle. set_row draws one row anew. With :describe a row of an :item shows
      # the game's description of it as its tooltip; with :escapes the rows' texts draw the game's
      # text codes; with :round the cursor goes round at the ends on every press, and left unset a list
      # of the new UI layer goes round on a fresh press only; with :cells each row's :cells lie
      # in table columns of those widths. A row with a :value takes :less and :more, false drawing
      # that arrow dim and buzzing a step that way. A row's :key keeps the cursor on it when the rows
      # are set anew. A row's :gauge (0 to 1) draws a thin bar left of its right text, in its
      # :gauge_color (:bad unless told), and its :indent moves what it shows that many pixels right.
      # A row's :badge draws a count or a dot at its end in its :badge_color, see Badge.
      #
      # A row with :lines shows as a card too, with or without a :picture: its name on the first line
      # with its :right at the end (at most a third of the room, small and :right_color, dim unless
      # told), then each line in the small font, a String or {:text, :color, :right (a text or parts)},
      # the last wrapped to :wrap_lines lines (1) and ended with "..." where more did not fit. Its
      # picture lies across its top, 16:9 of its width, or with :picture_at => :left beside its texts,
      # :picture_width wide (96); a picture lower than that where the cell leaves no more room beside
      # its texts is cut from its middle; without a picture the texts stand in the middle of its height. :plate
      # draws a dark plate under the whole card, and :faint draws it see-through.
      #
      # Each cell in sight is drawn once on a picture of its own and copied from there until its row,
      # its width or its state (the cursor, the pointer's frame) changes, so a move of the cursor
      # draws only the two cells it leaves and enters. In a container the keys enter (:enter), the
      # cursor's plate shows only while the focus is inside that container, so the container's own
      # frame is the only cursor while it is picked as a whole. With :click_picks a click on any row
      # moves the cursor there and picks it at once. With :pages_beside Page Up and Page Down scroll the
      # box that scrolls beside it instead of paging it, such as a reading pane beside its entries.
      # :highlight draws the places of the rows' texts, cells and card names that hold that text,
      # ignoring case, on the theme's primary color, the letters in their own color and outline.
      #
      # Events: change (row, index: the row the cursor moved to, nil for none), submit (row, index:
      # a click on the cursor's row, a double click or Enter), moved (row, from, to: a row carried was
      # dropped, or put back, then at the place it came from, or move_row moved it), side (row, index,
      # step: -1 or 1), toggle (row, index, toggle index), refuse (row, index: a pick of a row that
      # takes none).
      class List < Component
        # The component's kind in C#'s tree.
        KIND = "list"

        # The most rows it shows with no :rows_shown, as the game's lists do.
        SHOWN = 6

        # Its width with no labels, before its parent stretches it.
        MIN_WIDTH = 120

        # The side of the small icons at the right.
        SMALL_ICON = 12

        # Room at the left and the right of a row, and in the look of the game's own windows, as the
        # game's command windows keep it.
        INSET = 2
        GAME_INSET = 4

        # The row shown when a filter leaves no row.
        NO_MATCH_TEXT = "Nothing matches"

        # The least room a row's note keeps; with less it is left out.
        NOTE_ROOM = 32

        # Room between the rows and the scrollbar, so the right texts end clear of it.
        BAR_GAP = 4

        # The least room between a row's note and its right text, so a cut note never reads as part
        # of a count.
        NOTE_GAP = 12

        # Room between two cells of a line with :columns, unless :cell_gap says otherwise.
        CELL_GAP = 8

        # The side of the box of a row with :checked.
        CHECK = 14

        # The arrow before a row's :value, which a click steps back.
        VALUE_LEFT = "<"

        # The arrow after a row's :value, which a click steps on.
        VALUE_RIGHT = ">"

        # Room between a row's value and its arrows.
        VALUE_GAP = 6

        # Room between that box's edge and its filling.
        CHECK_INSET = 3

        # Room between a card's edge and what it shows.
        CARD_INSET = 4

        # Room between a card's picture and its text.
        CARD_GAP = 2

        # The height of a card's text line.
        CARD_TEXT_ROW = 22

        # The height of a card's note line.
        CARD_NOTE_ROW = 18

        # The side of the picture of a part of a row's note or right text.
        PART_ICON = 16

        # Room between a part's picture and its text.
        PART_ICON_GAP = 2

        # Room between two parts.
        PART_GAP = 6

        # Room between a toggle's edge and its text.
        TOGGLE_PAD = 4

        # Room between two toggles, and between the toggles and the rest of a row.
        TOGGLE_GAP = 4

        # Room between two table cells of a row.
        TABLE_GAP = 6

        # Room above and below the highest avatar of a row's table cells.
        AVATAR_ROOM = 2

        # The width and height of a row's :gauge.
        ROW_GAUGE = [40, 6]

        # How opaque the plate under a card with :plate is: black at 28 percent.
        CARD_PLATE = 72

        # The width of a card's picture beside its texts, unless its :picture_width says otherwise.
        PICTURE_BESIDE = 96

        # Room between a picture beside a card's texts and the texts.
        PICTURE_GAP = 8

        # The pictures of cells left over for the next cells drawn, at most this many lines of them.
        SPARE_LINES = 2

        # The most rows in an animated color it notes; more start the notes anew.
        MOST_MOVING_ROWS = 256

        # Where a cell draws: its own picture and where that picture's top left lies on the screen.
        CellSurface = Struct.new(:bitmap, :x, :y)

        # A cell drawn once: its picture, its tooltip, and where its value's arrows and its toggles lie.
        Cell = Struct.new(:bitmap, :tip, :value_spot, :toggle_spots)

        # Tells the defaults of the options: no rows, the cursor on the first, no filter.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:rows => [], :rows_shown => nil, :label_width => nil, :index => 0, :follow_pointer => nil, :shoulder_pages => true, :filter => "",
                      :only => nil, :no_match_text => NO_MATCH_TEXT, :empty_text => nil, :note_at => nil, :submit_to => nil, :most_rows => SHOWN,
                      :keep_cursor => false, :columns => 1, :cell_gap => CELL_GAP, :reorder => false, :move_hotkeys => false, :leave_ends => false, :sides => false,
                      :quiet => false, :row_height => nil, :leave_sides => false, :describe => false, :escapes => false, :round => nil, :cells => nil,
                      :click_picks => false, :share_room => false, :pages_beside => false, :highlight => nil)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          shown = ["rows", "disabled_rows", "heading_rows", "value_rows", "toggle_rows", "row_groups", "measured", "index"]
          super.merge(:rows => shown, :filter => shown, :only => shown, :no_match_text => shown, :empty_text => shown, :rows_shown => ["measured", "whole_rows", "shrink"],
                      :label_width => ["measured"], :note_at => ["measured"], :most_rows => ["measured"], :columns => ["row_cells", "measured"], :row_height => ["row_height", "measured"],
                      :index => ["index"], :grow => ["grow", "measured"], :follow_pointer => ["follow_pointer"], :shoulder_pages => ["shoulder_pages"],
                      :reorder => ["reorder", "row_groups"], :move_hotkeys => ["move_hotkeys"], :leave_ends => ["leave_ends"], :leave_sides => ["leave_sides"], :sides => ["sides"], :quiet => ["quiet"],
                      :round => ["round"], :click_picks => ["click_picks"], :pages_beside => ["pages_beside"])
        end

        options :rows, :rows_shown, :label_width, :index, :follow_pointer, :shoulder_pages, :filter, :only, :no_match_text, :empty_text, :note_at, :submit_to,
                :most_rows, :keep_cursor, :columns, :cell_gap, :reorder, :move_hotkeys, :leave_ends, :sides, :quiet, :row_height, :leave_sides, :describe, :escapes, :round,
                :cells, :click_picks, :share_room, :pages_beside, :highlight

        # Makes a list, its cursor on one of its rows or on none.
        #
        # @param options [Hash] Its options, see DEFAULTS and defaults.
        def initialize(options = {})
          @narrows = {}
          @narrowed = 0
          super
          @options[:index] = cursor_at(@options[:index])
          release_pictures
        end

        # Sets its rows, the cursor kept on one of them; with the cursor on none it goes on the first.
        # When the cursor's row is no longer the same row, it tells its change blocks as a move does.
        #
        # @param value [Array] The rows.
        def rows=(value)
          value = Patches.rows_for(self, value) if @patch_rows
          abandon_move
          index = @options[:index].to_i
          shown = row_at(index)
          @options[:rows] = value.nil? ? [] : value.to_a
          release_pictures
          keyed = shown.is_a?(Hash) && !shown[:key].nil? ? shown_rows.index { |row| row.is_a?(Hash) && row[:key] == shown[:key] } : nil
          place = keyed || kept_index(index < 0 ? 0 : index, shown_rows.size)
          @options[:index] = place
          set_option(:rows, @options[:rows])
          emit(:change, row_at(place), place >= 0 ? place : nil) unless place == index && row_at(place) == shown
        end

        # Puts a row in the place of one shown and draws it anew, the cursor kept; when it is the
        # cursor's row, it tells its change blocks.
        #
        # @param place [Integer] The row's place among those shown.
        # @param row [Hash, String] The new row.
        # @return [List] Itself.
        def set_row(place, row)
          old = row_at(place)
          at = old && Array(@options[:rows]).index { |each| each.equal?(old) }
          return self unless at

          rows = @options[:rows].dup
          rows[at] = row
          @options[:rows] = rows
          set_option(:rows, rows)
          emit(:change, row_at(place), place) if place == @options[:index].to_i
          self
        end

        # Shows only the rows that hold a text, the cursor on the first a search can find. When the
        # cursor's row is no longer the same row, it tells its change blocks as a move does.
        #
        # @param value [String, nil] The text, empty or nil for every row.
        def filter=(value)
          text = value.to_s
          refilter(:filter, text) unless text == @options[:filter].to_s
        end

        # Shows only the rows a block keeps, besides the filter's text, the cursor on the first a
        # search can find. When the cursor's row is no longer the same row, it tells its change blocks
        # as a move does.
        #
        # @param block [Proc, nil] The block of a row, answering whether it shows; nil for every row.
        def only=(block)
          refilter(:only, block) unless block.equal?(@options[:only])
        end

        # Puts the cursor on a row, kept on its rows.
        #
        # @param value [Integer, Symbol] The row's place, -1 for none, or :first_found for the first
        #   row a search can find.
        def index=(value)
          set_option(:index, cursor_at(value))
        end

        # Shows only the rows a block keeps, besides the filter and :only, under a key of its own, so
        # several parts filter one list together, each with its own block; the cursor goes on the first
        # row a search can find. When the cursor's row is no longer the same row, it tells its change
        # blocks as a move does. A row with :search => false stays unasked.
        #
        # @param key [Object] What narrows it, such as the chips that steer it.
        # @param block [Proc, nil] The block of a row, answering whether it shows; nil drops the key's.
        # @return [List] Itself.
        def narrow(key, block)
          return self if block.nil? && !@narrows.key?(key)

          shown = row_at(@options[:index].to_i)
          block.nil? ? @narrows.delete(key) : @narrows[key] = block
          @narrowed += 1
          refilter(:only, @options[:only], shown)
          self
        end

        # Hands out a row the filter shows.
        #
        # @param place [Integer, nil] Its place among them.
        # @return [Hash, String, nil] The row as given, nil for none.
        def row_at(place)
          place && place >= 0 ? shown_rows[place] : nil
        end

        # Tells the rows the filter and :only show, every row while neither filters.
        #
        # @return [Array<Hash, String>] The rows as given.
        def shown_rows
          rows = @options[:rows]
          word = @options[:filter].to_s.downcase
          only = @options[:only]
          same_rows = @shown && @shown[0].equal?(rows)
          return @shown[3] if same_rows && @shown[1] == word && @shown[2].equal?(only) && @shown[4] == @narrowed

          @searched = {} unless same_rows
          all = Array(rows)
          kept = word.empty? && only.nil? && @narrows.empty? ? all : headed(all.select { |row| heading?(row) || kept?(row, word, only) })
          @shown = [rows, word, only, kept, @narrowed]
          @shown[3]
        end

        # Tells whether a row is a heading: a row of :heading, which heads the rows under it and is no
        # stop of the cursor.
        #
        # @param row [Hash, String, nil] The row.
        # @return [Boolean] Whether it is.
        def heading?(row)
          row.is_a?(Hash) && !row[:heading].nil?
        end

        # Tells whether a row takes no pick: one with :disabled => true, greyed out.
        #
        # @param row [Hash, String, nil] The row.
        # @return [Boolean] Whether it does.
        def refuses?(row)
          row.is_a?(Hash) && row[:disabled] == true
        end

        # Notes the text field that steers it, see TextField#steer.
        #
        # @param field [TextField, nil] The field, nil for none.
        def steered_by=(field)
          @steered_by = field
          Tree.set(self, "up_to" => field && field.node) if node
          redraw
        end

        # Moves the cursor by a count of lines, kept on its rows, with the cursor's sound, as a text
        # field that steers it does; from no row a move down starts at the first and up at the last.
        #
        # @param rows [Integer] The lines, negative upwards: rows, or with :columns lines of them.
        def step_cursor(rows)
          count = shown_rows.size
          return if count == 0 || rows == 0

          from = @options[:index].to_i
          to = from < 0 ? (rows > 0 ? 0 : count - 1) : UI.within(from + rows * across, 0, count - 1)
          to = kept_index(to, count, rows > 0 ? 1 : -1)
          return if to == from || to < 0

          self.index = to
          Sound.play_cursor
          emit(:change, row_at(to), to)
        end

        # Picks the cursor's row, as Enter in a text field that steers it does; a row that takes no
        # pick, no row or a list that takes no input plays the buzzer.
        def submit_cursor
          place = @options[:index].to_i
          row = row_at(place)
          return Sound.play_buzzer if row.nil? || (row.is_a?(Hash) && row[:disabled] == true) || !enabled_here?

          Sound.play_ok unless @options[:quiet]
          emit(:submit, row, place)
          pass_focus
        end

        # Starts Move mode: it carries a row, which UP and DOWN, Page Up and Down and the pointer move
        # to another place, among the rows of its :group when it has one, a key past the group's first
        # or last row playing the buzzer; confirm or a click drops it
        # there and cancel puts it back, either telling moved. It takes the focus. Setting rows or a
        # filter ends Move mode without telling moved.
        #
        # @param place [Integer, nil] The row's place, nil for the cursor's.
        # @return [Boolean] Whether it carries the row; false for no row, a row that takes no pick,
        #   while a filter hides rows and while it takes no input.
        def start_move(place = nil)
          place = place.nil? ? @options[:index].to_i : place.to_i
          row = row_at(place)
          return false if row.nil? || heading?(row) || refuses?(row) || filtering? || !enabled_here?

          @moving = [row, place, @options[:rows]]
          @options[:index] = place
          Tree.set(self, "moving" => true, "index" => place, "move_span" => group_span(@options[:rows], row))
          focus
          redraw
          true
        end

        # Tells whether it carries a row in Move mode.
        #
        # @return [Boolean] Whether it does.
        def moving?
          @moving ? true : false
        end

        # Drops the row it carries where it is now, as confirm does.
        #
        # @return [Boolean] Whether it carried one.
        def end_move
          return false unless @moving

          Tree.set(self, "moving" => false)
          finish_move
          true
        end

        # Puts the row it carries back where it came from, as cancel does.
        #
        # @return [Boolean] Whether it carried one.
        def cancel_move
          return false unless @moving

          Tree.set(self, "moving" => false)
          put_back
          true
        end

        # Moves a row to the place C#'s tree took it to by the move hotkeys, the cursor with it, and
        # tells moved; the tree kept it within its group.
        #
        # @param from [Integer] The row's place.
        # @param to [Integer] Its new place.
        # @return [Boolean] Whether the row moved; false for no row, in Move mode and while a filter
        #   hides rows.
        def move_to(from, to)
          row = row_at(from)
          return false if row.nil? || row_at(to).nil? || from == to || @moving || filtering?

          rows = @options[:rows].dup
          rows.delete_at(from)
          rows.insert(to, row)
          @options[:rows] = rows
          @options[:index] = to
          set_option(:rows, rows)
          emit(:moved, row, from, to)
          true
        end

        # Moves the cursor's row one place up or down among the rows of its :group, every row for a
        # row of none, the cursor with it, and tells moved. It works outside Move mode.
        #
        # @param step [Integer] -1 for up, 1 for down.
        # @return [Boolean] Whether the row moved; false at its group's end, for no row, in Move mode,
        #   while a filter hides rows and while it takes no input.
        def move_row(step)
          from = @options[:index].to_i
          row = row_at(from)
          return false if step.to_i == 0 || row.nil? || heading?(row) || @moving || filtering? || !enabled_here?

          rows = @options[:rows].dup
          first, last = group_span(rows, row)
          to = from + (step.to_i > 0 ? 1 : -1)
          return false if to < first || to > last

          rows.delete_at(from)
          rows.insert(to, row)
          @options[:rows] = rows
          @options[:index] = to
          set_option(:rows, rows)
          emit(:moved, row, from, to)
          true
        end

        # Tells the properties C#'s tree lays it out and routes input by: its rows, the cursor and
        # the rows that take no pick; a list that fills its room gives back what its parent lacks.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["shrink"] ||= fills?
          rows = drawn_rows
          props["rows"] = rows.size
          props["row_cells"] = across
          props["row_height"] = line_height
          props["index"] = shown_rows.empty? ? nil : @options[:index].to_i
          props["disabled_rows"] = (0...rows.size).select { |place| rows[place].is_a?(Hash) && rows[place][:disabled] == true }
          props["heading_rows"] = (0...rows.size).select { |place| heading?(rows[place]) }
          props["follow_pointer"] = @options[:follow_pointer] ? true : false unless @options[:follow_pointer].nil?
          props["shoulder_pages"] = @options[:shoulder_pages] ? true : false
          props["reorder"] = @options[:reorder] ? true : false
          props["move_hotkeys"] = @options[:move_hotkeys] ? true : false
          props["leave_ends"] = @options[:leave_ends] ? true : false
          props["leave_sides"] = @options[:leave_sides] ? true : false
          props["up_to"] = @steered_by && @steered_by.node
          props["sides"] = @options[:sides] ? true : false
          props["value_rows"] = @options[:sides] ? (0...rows.size).select { |place| rows[place].is_a?(Hash) && !rows[place][:value].nil? } : []
          props["quiet"] = @options[:quiet] ? true : false
          props["moving"] = moving?
          props["move_span"] = @moving ? group_span(@options[:rows], @moving[0]) : nil
          props["row_groups"] = @options[:reorder] ? group_numbers(rows) : []
          props["whole_rows"] = fills?
          props["tooltip"] = tips?
          props["round"] = @options[:round] ? true : false unless @options[:round].nil?
          props["click_picks"] = @options[:click_picks] ? true : false
          props["pages_beside"] = @options[:pages_beside] ? true : false
          props["toggle_rows"] = rows.map { |row| row.is_a?(Hash) ? Array(row[:toggles]).size : 0 }
          props["box_ends"] = rows.map { |row| row.is_a?(Hash) && !row[:checked].nil? ? row_inset + row[:indent].to_i + CHECK + Style::GAP : 0 }
          props
        end

        # Tells its tooltip for the pointer at a spot: its own, else that of the row there, the row's
        # :tooltip or the whole text of a row drawn cut.
        #
        # @param x [Integer] The pointer's left on the screen.
        # @param y [Integer] Its top.
        # @return [String, Proc, nil] The tooltip, nil for none.
        def tooltip_at(x, y)
          return @options[:tooltip] if @options[:tooltip] || @rect.nil?

          left = x - @rect.x
          top = y - @rect.y
          found = Array(@row_tips).find { |at, line, width, _tip| left >= at && left < at + width && top >= line && top < line + line_height }
          found && found[3]
        end

        # Tells its size: as wide as its widest row draws whole, never below MIN_WIDTH and the labels'
        # room; every line high when it fills its room, which it gives back where its parent has less
        # (see node_props); :rows_shown lines; else one line when it grows in a column, so that it
        # takes exactly the room its column leaves; else its lines up to :most_rows, at least one. A
        # line holds one row, or with :columns that many.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          rows = drawn_rows
          shown = if fills?
                    [lines_of(rows.size), 1].max
                  elsif @options[:rows_shown]
                    @options[:rows_shown].to_i
                  elsif @options[:grow].to_i > 0 && grows_in_column?
                    1
                  else
                    UI.within(lines_of(rows.size), 1, [@options[:most_rows].to_i, 1].max)
                  end
          [[MIN_WIDTH + label_room, natural_width(rows, shown)].max, shown * own_line_height]
        end

        # Tells the height of its lines: their share of its height with :share_room, else
        # :row_height, never lower than a line of text.
        #
        # @return [Integer] The pixels.
        def line_height
          own = own_line_height
          @shared && shares_room? ? [@shared, own].max : own
        end

        # Takes the place C# gave it; with :share_room its lines take their share of its height, and
        # C# learns their height.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          return unless shares_room?

          top, _right, bottom, _left = padding_sides
          shared = (@rect.height - top - bottom) / @options[:rows_shown]
          return if shared == @shared

          @shared = shared
          Tree.set(self, "row_height" => line_height)
          redraw
        end

        # Takes an event of C#'s tree: the cursor moved, which moves a row carried with it, a row was
        # picked, the pointer dragged a row out of its place, or a row carried was dropped or put back;
        # a move hotkey that moved no row is logged with why.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return carry_to(values[0].to_i) if name == "change" && @moving

          case name
          when "carry"
            Tree.set(self, "moving" => false) unless start_move(values[0].to_i)
          when "drop"
            finish_move if @moving
          when "uncarry"
            put_back if @moving
          when "change"
            place = kept_index(values[0].to_i, shown_rows.size)
            # A move onto the no-match row after the rows kept goes back to the last of them.
            place == values[0].to_i ? @options[:index] = place : set_option(:index, place)
            redraw
            emit(:change, row_at(place), place >= 0 ? place : nil)
          when "submit"
            place = values[0].to_i
            return unless row_at(place)

            step = value_click(place)
            return side(place, step) if step

            emit(:submit, row_at(place), place)
            pass_focus
          when "side"
            place = values[0].to_i
            side(place, values[1].to_i) if row_at(place)
          when "toggle"
            place = values[0].to_i
            emit(:toggle, row_at(place), place, values[1].to_i) if row_at(place)
          when "reorder"
            move_to(values[0].to_i, values[1].to_i)
          when "move_refused"
            Tree.log("#{Hotkeys.label(values[0].to_s.to_sym)} (#{values[0]}) moved no row of list #{@options[:id] || node}: #{values[1]}")
          when "refuse"
            place = values[0].to_i
            emit(:refuse, row_at(place), place) if row_at(place)
          when "toggle_cursor"
            @toggle_cursor = values[1].to_i
            redraw
          when "row_click"
            click_row(values[0].to_i, values[1])
          when "hover_row"
            @hover_row = values[0].to_i
            redraw
          else
            super
          end
        end

        # Draws its rows anew on the next frame; it draws nothing on the picture it lies on.
        #
        # @return [List] Itself.
        def redraw
          @inner.dirty = true if @inner
          self
        end

        # Tells that it draws its rows on a picture of its own.
        #
        # @return [Boolean] Always true.
        def scrolls_part?
          true
        end

        # Tells where its rows show on the screen: its whole place, in one rectangle it keeps for
        # every frame.
        #
        # @return [Rect] The place.
        def inner_region
          (@inner_region ||= Rect.new(0, 0, 0, 0)).set(@rect.x, @rect.y, @rect.width > 1 ? @rect.width : 1, @rect.height > 1 ? @rect.height : 1)
          @inner_region
        end

        # Tells the picture its rows draw on.
        #
        # @return [SpriteSurface, nil] The picture, nil before it showed.
        def inner_surface
          @inner
        end

        # Hands out the picture its rows draw on, made as it first shows.
        #
        # @return [SpriteSurface] The picture.
        def inner_surface!
          @inner ||= SpriteSurface.new(self, root.surface_viewport)
        end

        # Frees the picture of its rows, those of its cells and the scaled pictures of its avatars.
        def release_surfaces
          super
          @inner.dispose if @inner
          @inner = nil
          (@cells || {}).each_value { |cell| cell.bitmap.dispose unless cell.bitmap.disposed? }
          (@spare_cells || []).each { |bitmap| bitmap.dispose unless bitmap.disposed? }
          @cells = nil
          @spare_cells = nil
          @avatar_copies.dispose if @avatar_copies
        end

        # Draws the lines in sight, the cursor's row picked while it has the focus, and the scrollbar
        # while not every line shows; with :columns each line's rows in cells side by side. Each cell
        # is copied from the picture it was drawn on last while its row, width and state are the same,
        # else drawn anew. It keeps the tooltip of each row in sight that has one.
        #
        # @param canvas [Canvas] Where it draws, its own place.
        def draw_part(canvas)
          rows = drawn_rows
          tall = line_height
          top, shown, total = @scrolling || [0, canvas.height / tall, lines_of(rows.size)]
          pad_top, pad_right, _pad_bottom, pad_left = padding_sides
          bar = total > shown
          width = canvas.width - pad_left - pad_right - (bar ? Style::SCROLLBAR_WIDTH + BAR_GAP : 0)
          gap = UI.whole(@options[:cell_gap])
          cell = [(width - (across - 1) * gap) / across, 1].max
          icons = rows.any? { |row| row.is_a?(Hash) && (row[:icon] || row[:item]) }
          checks = rows.any? { |row| row.is_a?(Hash) && !row[:checked].nil? }
          tips = []
          @value_spots = {}
          @toggle_spots = {}
          @toggle_widths = toggle_widths(canvas, rows)
          @cursor_shown = cursor_shown?
          look = [cell, tall, icons, checks, label_room, @options[:note_at], @toggle_widths, canvas.enabled?, canvas.palette.object_id, Theme.serial, Theme.window_tone,
                  @options[:highlight]]
          drawn = @cells || {}
          @cells = {}
          # The last line may show in part below the lines that show whole.
          (top...[top + shown + 1, lines_of(rows.size)].min).each do |line|
            y = pad_top + (line - top) * tall
            (0...across).each do |column|
              place = line * across + column
              break if place >= rows.size

              left = pad_left + column * (cell + gap)
              kept = cell_of(rows, place, [left, y, cell, tall], look, [icons, checks], drawn)
              canvas.copy(left, y, kept.bitmap)
              @value_spots[place] = kept.value_spot if kept.value_spot
              @toggle_spots[place] = kept.toggle_spots if kept.toggle_spots
              tips << [left, y, cell, kept.tip] if kept.tip
            end
          end
          spare_cells(drawn, [cell, tall])
          canvas.scrollbar(canvas.width - Style::SCROLLBAR_WIDTH, 0, canvas.height, top, shown, total) if bar
          note_tips(tips)
        end

        private

        # Hands out a cell's picture: the one drawn last for the same row, width and state, else a new
        # drawing of the row, greyed out while it or the list takes no pick, kept for the next draw. A
        # row drawn in an animated color is drawn anew in every frame the list draws.
        #
        # @param rows [Array<Hash, String>] The rows drawn.
        # @param place [Integer] The row's place.
        # @param box [Array<Integer>] The cell's left, top, width and height in the list.
        # @param look [Array] What every cell of this draw shares, see draw_part.
        # @param marks [Array<Boolean>] Whether any row has an icon and whether any has a box.
        # @param drawn [Hash] The cells of the last draw by their keys.
        # @return [Cell] The cell.
        def cell_of(rows, place, box, look, marks, drawn)
          row = rows[place]
          shown = shown_row(row).hash
          moving = @moving_rows && @moving_rows[shown]
          key = [shown, cell_state(place), look, moving ? Key.frame : nil]
          kept = @cells[key] || drawn[key]
          return @cells[key] = kept if kept

          x, y, width, height = box
          bitmap = spare_bitmap(width, height)
          canvas = Canvas.new(self, CellSurface.new(bitmap, @rect.x + x, @rect.y + y), draws_enabled? && !(row.is_a?(Hash) && row[:disabled] == true))
          @value_spots.delete(place)
          @toggle_spots.delete(place)
          if heading?(row)
            draw_heading(canvas, row, x, y, width)
            return @cells[key] = Cell.new(bitmap, nil, nil, nil)
          end

          cut = card?(row) ? draw_card(canvas, row, place, x, y, width, height) : draw_row(canvas, row, place, x, y, width, marks[0], marks[1])
          note_moving_row(shown) if canvas.animated? && !moving
          @cells[key] = Cell.new(bitmap, row_tip(row, cut), @value_spots[place], @toggle_spots[place])
        end

        # Notes a row drawn in an animated color, whose cell is drawn anew whenever the list draws.
        #
        # @param shown [Integer] The hash of the row as shown.
        def note_moving_row(shown)
          @moving_rows = {} if @moving_rows.nil? || @moving_rows.size >= MOST_MOVING_ROWS
          @moving_rows[shown] = true
        end

        # Tells what of a cell's look follows the cursor and the pointer: whether the cursor's plate
        # shows on it and is lit, the pointer's frame, a row carried, and the cursor's toggle.
        #
        # @param place [Integer] The row's place.
        # @return [Array] The state.
        def cell_state(place)
          cursor = cursor_here?(place)
          lit = cursor && cursor_lit?
          [cursor ? (lit ? 2 : 1) : 0, place == @hover_row && !@options[:follow_pointer], @moving && place == @options[:index] ? true : false,
           lit ? @toggle_cursor : nil]
        end

        # Hands out a picture for a cell: one left over of that size, cleared, else a new one.
        #
        # @param width [Integer] The cell's width.
        # @param height [Integer] Its height.
        # @return [Bitmap] The picture.
        def spare_bitmap(width, height)
          spares = @spare_cells ||= []
          found = spares.index { |bitmap| bitmap.width == width && bitmap.height == height }
          return Bitmap.new([width, 1].max, [height, 1].max) unless found

          bitmap = spares.delete_at(found)
          bitmap.clear
          bitmap
        end

        # Keeps the pictures of the cells the last draw left out for the next cells, as many as
        # SPARE_LINES lines take, and frees the rest.
        #
        # @param drawn [Hash] The cells of the last draw by their keys.
        # @param size [Array<Integer>] The cells' width and height now.
        def spare_cells(drawn, size)
          spares = @spare_cells ||= []
          drawn.each { |key, cell| spares << cell.bitmap unless @cells.key?(key) }
          fitting, other = spares.partition { |bitmap| bitmap.width == size[0] && bitmap.height == size[1] }
          kept = fitting.first(SPARE_LINES * across)
          (other + fitting.drop(kept.size)).each { |bitmap| bitmap.dispose unless bitmap.disposed? }
          @spare_cells = kept
        end

        # Tells whether the cursor's plate shows on a row: the cursor stands on it and the cursor shows,
        # never in a list of rows to read that has neither an action nor a bind.
        #
        # @param place [Integer] The row's place.
        # @return [Boolean] Whether it does.
        def cursor_here?(place)
          place == @options[:index] && @cursor_shown != false && @options[:acts] != false
        end

        # Tells whether the cursor shows: while it is lit, and in a container the keys enter only
        # while the focus is inside that container; in a root joined to a game window only while it is
        # lit, since the two show one cursor between them.
        #
        # @return [Boolean] Whether it does.
        def cursor_shown?
          return true if cursor_lit?
          return false if root.respond_to?(:joined) && root.joined

          box = @parent
          box = box.parent until box.nil? || (box.container? && box.enter && !box.is_a?(Tabs))
          return true unless box

          focused = Tree.focused
          focused && box.holds?(focused) ? true : false
        end

        # Steps a row's value, unless the row takes no pick or the arrow that way is off (its :less or
        # :more false), which buzzes and tells nothing.
        #
        # @param place [Integer] The row's place.
        # @param step [Integer] -1 or 1.
        def side(place, step)
          row = row_at(place)
          return Sound.play_buzzer if refuses?(row) || (row.is_a?(Hash) && row[step < 0 ? :less : :more] == false)

          emit(:side, row, place, step)
        end

        # Takes a click on a row that has toggles: on a toggle it tells toggle with the confirm sound,
        # elsewhere on the cursor's row it picks the row; a row that takes no pick buzzes.
        #
        # @param place [Integer] The row's place.
        # @param on_cursor [Boolean] Whether the row held the cursor as the button went down.
        def click_row(place, on_cursor)
          row = row_at(place)
          return unless row

          toggle = toggle_under_pointer(place)
          return unless toggle || on_cursor
          return Sound.play_buzzer if refuses?(row)

          if toggle
            Sound.play_ok unless @options[:quiet]
            return emit(:toggle, row, place, toggle)
          end

          Sound.play_ok unless @options[:quiet]
          emit(:submit, row, place)
          pass_focus
        end

        # Tells the toggle of a row under the pointer.
        #
        # @param place [Integer] The row's place.
        # @return [Integer, nil] The toggle's index, nil for none.
        def toggle_under_pointer(place)
          spots = @toggle_spots && @toggle_spots[place]
          at = Mouse.position
          return nil unless spots && at && @rect

          x = at[0] - @rect.x
          spots.index { |left, right| x >= left && x < right }
        end

        # Tells whether a row shows as a card: with a picture, or with lines under its name.
        #
        # @param row [Hash, String] The row.
        # @return [Boolean] Whether it does.
        def card?(row)
          row.is_a?(Hash) && (row[:picture].is_a?(Hash) || row[:lines].is_a?(Array))
        end

        # Draws a row as a card: the cursor's plate and the pointer's frame around its whole cell, its
        # picture across the top with its badge and label, its text and its note under it; it tells
        # whether its text was cut.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash] The row.
        # @param place [Integer] Its place.
        # @param x [Integer] Its cell's left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its cell's width.
        # @param height [Integer] Its height.
        # @return [Boolean, String] Whether its text was cut, else the texts of its note's parts when
        #   they were.
        def draw_card(canvas, row, place, x, y, width, height)
          return draw_lined_card(canvas, row, place, [x, y, width, height]) if row[:lines].is_a?(Array)

          enabled = row[:disabled] != true
          canvas.fill(x, y, width, height, cursor_lit? && enabled ? :picked : :tab) if cursor_here?(place)
          canvas.outline(x, y, width, height, :edge) if (place == @hover_row && !@options[:follow_pointer]) || (@moving && place == @options[:index])
          inner = width - 2 * CARD_INSET
          picture = [height - 2 * CARD_INSET - CARD_GAP - CARD_TEXT_ROW - CARD_NOTE_ROW, 0].max
          PictureLook.draw(canvas, x + CARD_INSET, y + CARD_INSET, inner, picture, row[:picture])
          text_top = y + CARD_INSET + picture + CARD_GAP
          cut = canvas.text(x + CARD_INSET, text_top, inner, CARD_TEXT_ROW, row[:text].to_s, :color => row[:color], :squeeze => true, :highlight => @options[:highlight])
          parts = parts_of(row[:note])
          if parts
            note_cut = draw_parts(canvas, parts, x + CARD_INSET, text_top + CARD_TEXT_ROW, inner, CARD_NOTE_ROW, :small, row[:note_color] || :dim)
          elsif !row[:note].to_s.empty?
            canvas.text(x + CARD_INSET, text_top + CARD_TEXT_ROW, inner, CARD_NOTE_ROW, row[:note].to_s, :size => :small, :color => row[:note_color] || :dim, :cut => true)
          end
          cut || (note_cut ? parts_text(parts) : false)
        end

        # Draws a card row with lines, see the class: its plate, the cursor's plate and the pointer's
        # frame, its picture, its name with its right text, then its lines; it tells whether its name
        # was cut.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash] The row.
        # @param place [Integer] Its place.
        # @param box [Array<Integer>] Its cell's left, top, width and height.
        # @return [Boolean] Whether its name was cut.
        def draw_lined_card(canvas, row, place, box)
          x, y, width, height = box
          enabled = row[:disabled] != true
          opacity = row[:faint] ? Label::FAINT : nil
          canvas.fill(x, y, width, height, Color.new(0, 0, 0, CARD_PLATE)) if row[:plate]
          canvas.fill(x, y, width, height, cursor_lit? && enabled ? :picked : :tab) if cursor_here?(place)
          canvas.outline(x, y, width, height, :edge) if (place == @hover_row && !@options[:follow_pointer]) || (@moving && place == @options[:index])
          lines = Array(row[:lines]).map { |line| line.is_a?(Hash) ? line : { :text => line.to_s } }
          wrap = [row[:wrap_lines].to_i, 1].max
          left = x + CARD_INSET
          texts = CARD_TEXT_ROW + CARD_NOTE_ROW * (lines.empty? ? 0 : lines.size - 1 + wrap)
          top = y + (height - texts) / 2
          look = row[:picture].is_a?(Hash) ? row[:picture] : nil
          if look
            beside = row[:picture_at] == :left
            picture = beside ? (row[:picture_width] || PICTURE_BESIDE).to_i : width - 2 * CARD_INSET
            room = height - 2 * CARD_INSET - (beside ? 0 : CARD_GAP + texts)
            tall = [[picture * 9 / 16, room].min, 0].max
            PictureLook.draw(canvas, left, y + CARD_INSET, picture, tall, opacity ? look.merge(:opacity => opacity) : look)
            if beside
              left += picture + PICTURE_GAP
            else
              top = y + CARD_INSET + tall + CARD_GAP
            end
          end
          room = x + width - CARD_INSET - left
          name_room = room - draw_card_right(canvas, row, [left + room, top, room / 3, CARD_TEXT_ROW], opacity)
          cut = canvas.text(left, top, [name_room, 1].max, CARD_TEXT_ROW, row[:text].to_s, :color => row[:color], :cut => true, :opacity => opacity,
                            :highlight => @options[:highlight])
          top += CARD_TEXT_ROW
          lines.each_with_index do |line, index|
            edge = room - draw_card_right(canvas, line, [left + room, top, room, CARD_NOTE_ROW], opacity)
            texts = index == lines.size - 1 ? card_lines(line[:text].to_s, edge, wrap) : [line[:text].to_s]
            texts.each_with_index do |text, at|
              canvas.text(left, top + at * CARD_NOTE_ROW, [edge, 1].max, CARD_NOTE_ROW, text, :size => :small, :color => line[:color] || :dim,
                          :cut => true, :opacity => opacity)
            end
            top += CARD_NOTE_ROW * texts.size
          end
          cut
        end

        # Draws the right text of a card's name or of one of its lines, small, at the end of its line.
        #
        # @param canvas [Canvas] Where it draws.
        # @param part [Hash] The row or the line: :right (a text or parts) and :right_color.
        # @param box [Array<Integer>] The line's right edge, top, the widest the text may be and the
        #   line's height.
        # @param opacity [Integer, nil] How opaque a text draws, nil for whole.
        # @return [Integer] The room it took, the gap before it included; 0 for none.
        def draw_card_right(canvas, part, box, opacity)
          edge, top, most, height = box
          color = part[:right_color] || :dim
          parts = parts_of(part[:right])
          if parts
            return 0 if parts.empty?

            wide = [parts_width(parts, :small), most].min
            draw_parts(canvas, parts, edge - wide, top, wide + Canvas::OUTLINE_ROOM, height, :small, color)
            return wide + Style::GAP
          end
          text = part[:right].to_s
          return 0 if text.empty?

          wide = [canvas.text_width(text, :small) + Canvas::OUTLINE_ROOM, most].min
          canvas.text(edge - wide, top, wide, height, text, :size => :small, :color => color, :align => :right, :cut => true, :opacity => opacity)
          wide + Style::GAP
        end

        # Breaks a card's last line into the lines it may take, the last ending with ELLIPSIS where
        # more did not fit.
        #
        # @param text [String] The text.
        # @param width [Integer] The room of a line.
        # @param most [Integer] The most lines.
        # @return [Array<String>] The lines.
        def card_lines(text, width, most)
          return [text] if most <= 1 || text.empty?

          bitmap = UI.font_bitmap(Style::SMALL_SIZE)
          UI.keep_lines(bitmap, UI.wrap(bitmap, text, width), most, width)
        end

        # Lets go of the picture files the rows named before and name no more.
        def release_pictures
          files = Array(@options[:rows]).map { |row| row.is_a?(Hash) && row[:picture].is_a?(Hash) ? row[:picture][:file] : nil }.compact.map(&:to_s).uniq
          ((@picture_files || []) - files).each { |file| UI.release_picture(file) }
          @picture_files = files
        end

        # Tells whether it shows as many whole rows as the room its column leaves holds.
        #
        # @return [Boolean] Whether it does.
        def fills?
          @options[:rows_shown] == :fill
        end

        # Tells whether its lines share the height it is placed in: :share_room with :rows_shown a
        # count.
        #
        # @return [Boolean] Whether they do.
        def shares_room?
          @options[:share_room] && @options[:rows_shown].is_a?(Integer) && @options[:rows_shown] > 0 ? true : false
        end

        # Tells the height of its lines of their own: :row_height, never lower than a line of text.
        #
        # @return [Integer] The pixels.
        def own_line_height
          @options[:row_height] ? [UI.whole(@options[:row_height]), LINE_HEIGHT].max : LINE_HEIGHT
        end

        # Tells a row's tooltip: its own :tooltip, else its whole text, without escape codes, when it
        # was drawn cut, else the texts of its note's parts when they were.
        #
        # @param row [Hash, String] The row.
        # @param cut [Boolean, String] Whether its text was drawn cut, or the texts of a note of parts
        #   drawn cut.
        # @return [String, Proc, nil] The tooltip, nil for none.
        def row_tip(row, cut)
          return row[:tooltip] if row.is_a?(Hash) && row[:tooltip]
          return item_description(row[:item]) if @options[:describe] && row.is_a?(Hash) && row[:item]
          return cut if cut.is_a?(String)
          return nil unless cut

          Escapes.convert(shown_row(row)[:text].to_s).gsub(Escapes::CODE, "")
        end

        # Tells the tooltip of an item's description, its text codes drawn, wrapped to the tooltip's
        # width.
        #
        # @param item [RPG::BaseItem] The item.
        # @return [Proc, nil] The tooltip, nil for an item without a description.
        def item_description(item)
          text = item.respond_to?(:description) ? item.description.to_s : ""
          return nil if text.empty?

          lambda { |box| box.add_label(text, :escapes => true, :wrap => true, :font_size => :small) }
        end

        # Keeps the tooltips of the rows in sight, each with its cell, and tells C# whether it has any.
        #
        # @param tips [Array<Array>] Each row's left, top, width and tooltip.
        def note_tips(tips)
          had = tips?
          @row_tips = tips
          Tree.set(self, "tooltip" => tips?) unless tips? == had
        end

        # Tells whether it has a tooltip: its own, or one of a row in sight.
        #
        # @return [Boolean] Whether it has.
        def tips?
          !@options[:tooltip].to_s.empty? || !Array(@row_tips).empty?
        end

        # Tells the width its widest row takes drawn whole, in as many cells as lie on a line, with the
        # scrollbar beside them when not every line shows; a card takes no width of its own.
        #
        # @param rows [Array<Hash, String>] The rows drawn.
        # @param shown [Integer] The lines it shows.
        # @return [Integer] The pixels.
        def natural_width(rows, shown)
          icons = rows.any? { |row| row.is_a?(Hash) && (row[:icon] || row[:item]) }
          checks = rows.any? { |row| row.is_a?(Hash) && !row[:checked].nil? }
          lead = 2 * row_inset + label_room + (icons ? ICON_STEP : 0) + (checks ? CHECK + Style::GAP : 0)
          widest = rows.map do |row|
            next 0 if card?(row)
            next 2 * row_inset + INSET + text_width(row[:heading], :small) + Canvas::OUTLINE_ROOM if heading?(row)

            entry = shown_row(row)
            lead + entry[:indent].to_i + (entry[:cells] && @options[:cells] ? cells_width(entry) : row_width(entry))
          end.max.to_i
          widest * across + UI.whole(@options[:cell_gap]) * (across - 1) + (lines_of(rows.size) > shown ? Style::SCROLLBAR_WIDTH + BAR_GAP : 0)
        end

        # Tells the width a row's texts and marks take drawn whole after its icon, as draw_row lays
        # them out: its text, its note, its right text and icons, its gauge, value, badge and toggles.
        #
        # @param entry [Hash] The row as it draws.
        # @return [Integer] The pixels.
        def row_width(entry)
          text = entry[:text].to_s
          width = text_width(@options[:escapes] ? Escapes.convert(text).gsub(Escapes::CODE, "") : text) + Canvas::OUTLINE_ROOM
          note = parts_of(entry[:note]) ? parts_width(parts_of(entry[:note]), :small) : text_width(entry[:note].to_s, :small)
          width = [width + Style::PAD, note_from_text].max + note + NOTE_GAP if note > 0
          right = parts_of(entry[:right]) ? parts_width(parts_of(entry[:right]), nil) : text_width(entry[:right].to_s)
          width += right + Style::GAP if right > 0
          width += Array(entry[:icons]).size * SMALL_ICON + Style::GAP unless Array(entry[:icons]).empty?
          width += ROW_GAUGE[0] + Style::GAP if entry[:gauge]
          width += 2 * (text_width(VALUE_RIGHT) + VALUE_GAP) + text_width(entry[:value].to_s) + Style::GAP if entry[:value]
          width += Badge::ROOM if entry.key?(:badge)
          Array(entry[:toggles]).inject(width) do |sum, toggle|
            sum + text_width((toggle.is_a?(Hash) ? toggle[:text] : toggle).to_s, :small) + 2 * TOGGLE_PAD + TOGGLE_GAP
          end
        end

        # Tells the width a row's table cells take: the widths :cells gives, and each column that takes
        # the room left as wide as the widest of the row's cells there.
        #
        # @param entry [Hash] The row as it draws.
        # @return [Integer] The pixels.
        def cells_width(entry)
          given = Array(@options[:cells])
          shared = given.each_with_index.map do |width, index|
            cell = Array(entry[:cells])[index]
            next 0 unless width.nil? && cell

            cell = { :text => cell.to_s } unless cell.is_a?(Hash)
            avatar = cell[:avatar].is_a?(Hash) ? UI.whole(cell[:avatar][:width]) + Style::GAP : 0
            avatar + Array(cell[:icons]).size * ICON_STEP + text_width(cell[:text].to_s, cell[:font_size]) + Canvas::OUTLINE_ROOM
          end
          given.compact.inject(0) { |sum, width| sum + width.to_i } + shared.max.to_i * given.count(&:nil?) + TABLE_GAP * [given.size - 1, 0].max
        end

        # Measures a text as the rows draw it, normal texts in the game's own font size in the look of
        # its own windows, as Canvas#text_width does.
        #
        # @param text [String] The text.
        # @param size [Symbol, Integer, nil] Its size, nil for the normal one.
        # @return [Integer] The pixels.
        def text_width(text, size = nil)
          px = (size.nil? || size == :normal) && game_look? ? UI.game_font_px : UI.font_px(size || :normal)
          text.to_s.empty? ? 0 : LabelCache.width(text.to_s, px)
        end

        # Tells how many rows lie side by side on a line.
        #
        # @return [Integer] The rows, at least one.
        def across
          [@options[:columns].to_i, 1].max
        end

        # Tells how many lines some rows take.
        #
        # @param count [Integer] The rows.
        # @return [Integer] The lines.
        def lines_of(count)
          (count + across - 1) / across
        end

        # Tells where the cursor goes for an index given.
        #
        # @param value [Integer, Symbol] The row's place, -1 for none, or :first_found.
        # @return [Integer] The place kept on the rows shown.
        def cursor_at(value)
          value == :first_found ? first_found : kept_index(value.to_i, shown_rows.size)
        end

        # Moves the focus to :submit_to after a pick.
        def pass_focus
          target = @options[:submit_to]
          target.focus if target.is_a?(Component)
        end

        # Tells whether its cursor's row shows as picked: while it or the text field that steers it
        # has the focus.
        #
        # @return [Boolean] Whether it does.
        def cursor_lit?
          focused? || (@steered_by && @steered_by.focused?) ? true : false
        end

        # Tells the room of the labels' column: the pixels :label_width gives, else the widest of its
        # texts or of the labels of all rows, shown or not, so a filter never moves the column, with
        # the gap after a label.
        #
        # @return [Integer] The pixels, 0 when no row has a label.
        def label_room
          given = @options[:label_width]
          return UI.whole(given) if given.is_a?(Numeric)

          rows = @options[:rows]
          px = row_px
          return @label_room[3] if @label_room && @label_room[0].equal?(rows) && @label_room[1].equal?(given) && @label_room[2] == px

          labels = given || Array(rows).map { |row| row.is_a?(Hash) ? row[:label] : nil }
          texts = Array(labels).map { |label| plain(label.to_s) }.reject { |label| label.empty? }
          @label_room = [rows, given, px, texts.empty? ? 0 : UI.measured_width(texts, px) + Style::GAP]
          @label_room[3]
        end

        # Tells where the notes start after the room before a row's text, as :note_at gives it in
        # texts: after the widest of them.
        #
        # @return [Integer] The pixels.
        def note_texts_room
          given = @options[:note_at]
          px = row_px
          return @note_texts_room[2] if @note_texts_room && @note_texts_room[0].equal?(given) && @note_texts_room[1] == px

          @note_texts_room = [given, px, UI.measured_width(given.map { |text| plain(text.to_s) }, px) + Style::GAP]
          @note_texts_room[2]
        end

        # Tells a text as the rows measure it: without the game's text codes while :escapes draws them.
        #
        # @param text [String] The text.
        # @return [String] The text measured.
        def plain(text)
          @options[:escapes] ? Escapes.convert(text).gsub(Escapes::CODE, "") : text
        end

        # Tells the pixels of the font the rows' texts draw in: the game's own size in the look of its
        # own windows.
        #
        # @return [Integer] The pixels.
        def row_px
          game_look? ? UI.game_font_px : UI.font_px(:normal)
        end

        # Keeps a cursor place on the rows shown, so it never marks a row that is gone, and off the
        # heading rows: from a heading on to the first row after it, else the last before it.
        #
        # @param place [Integer] The place, -1 for none.
        # @param count [Integer] How many rows show.
        # @param toward [Integer] 1 to look for a row after a heading first, -1 before it.
        # @return [Integer] The place on the rows, -1 for none and always for no rows.
        def kept_index(place, count, toward = 1)
          return -1 if count == 0

          place = UI.within(place, -1, count - 1)
          rows = shown_rows
          return place if place < 0 || !heading?(rows[place])

          stop_from(rows, place, toward) || stop_from(rows, place, -toward) || -1
        end

        # Finds the first row that is no heading, from a place on in one direction.
        #
        # @param rows [Array<Hash, String>] The rows shown.
        # @param place [Integer] Where to start.
        # @param toward [Integer] 1 down, -1 up.
        # @return [Integer, nil] Its place, nil for none.
        def stop_from(rows, place, toward)
          at = place
          while at >= 0 && at < rows.size
            return at unless heading?(rows[at])

            at += toward
          end
          nil
        end

        # Keeps the heading rows of rows a filter kept only where a row under them was kept.
        #
        # @param rows [Array<Hash, String>] The rows kept, headings among them.
        # @return [Array<Hash, String>] The rows without the headings that head no row.
        def headed(rows)
          rows.each_with_index.reject { |row, place| heading?(row) && (place + 1 >= rows.size || heading?(rows[place + 1])) }.map(&:first)
        end

        # Tells the rows it draws: those shown, then the dim row of :no_match_text when something
        # filters and no row a search can find is left, or of :empty_text when it has no rows at all,
        # unless that text is nil.
        #
        # @return [Array<Hash, String>] The rows.
        def drawn_rows
          shown = shown_rows
          return shown if shown.any? { |row| findable?(row) } || (!shown.empty? && !filtering?)

          text = Array(@options[:rows]).empty? ? @options[:empty_text] : @options[:no_match_text]
          text.nil? ? shown : shown + [{ :text => text.to_s, :disabled => true, :color => :dim }]
        end

        # Tells whether its text or :only filters its rows.
        #
        # @return [Boolean] Whether one does.
        def filtering?
          !@options[:filter].to_s.empty? || !@options[:only].nil? || !@narrows.empty?
        end

        # Tells whether a search can find a row: any row but one with :search => false.
        #
        # @param row [Hash, String] The row.
        # @return [Boolean] Whether it can.
        def findable?(row)
          !(row.is_a?(Hash) && row[:search] == false) && !heading?(row)
        end

        # Tells where the cursor goes once the filter changed: on the first row a search can find,
        # else on the first row.
        #
        # @return [Integer] The place, -1 for no rows.
        def first_found
          rows = shown_rows
          found = rows.index { |row| findable?(row) }
          found || (rows.empty? ? -1 : 0)
        end

        # Changes what filters the rows, the cursor on the first row a search can find and the rows
        # shown from the first, or with :keep_cursor the cursor kept on its row or the nearest, and
        # tells the change blocks when the cursor's row is no longer the same row.
        #
        # @param name [Symbol] :filter or :only.
        # @param value [String, Proc, nil] Its new value.
        # @param shown [Hash, String, nil] The cursor's row before the change.
        def refilter(name, value, shown = row_at(@options[:index].to_i))
          abandon_move
          index = @options[:index].to_i
          @options[name] = value
          place = @options[:keep_cursor] && shown ? kept_index(nearest(shown), shown_rows.size) : first_found
          @options[:index] = place
          set_option(name, value)
          Tree.set(self, "scroll_top" => 0) unless @options[:keep_cursor]
          emit(:change, row_at(place), place >= 0 ? place : nil) unless place == index && row_at(place) == shown
        end

        # Moves the row it carries to a place, kept among the rows of the row's :group, and the
        # cursor with it.
        #
        # @param place [Integer] The place the cursor moved to.
        def carry_to(place)
          row = @moving[0]
          rows = @options[:rows].dup
          from = rows.index { |each| each.equal?(row) }
          return unless from

          first, last = group_span(rows, row)
          to = UI.within(place, first, last)
          rows.delete_at(from)
          rows.insert(to, row)
          @options[:rows] = rows
          @options[:index] = to
          set_option(:rows, rows)
        end

        # Tells the places a row may be carried among: the unbroken run of rows around it that share
        # its :group, as C#'s tree keeps the move hotkeys within it; rows of no group count as one.
        #
        # @param rows [Array<Hash, String>] The rows.
        # @param row [Hash, String] The row.
        # @return [Array<Integer>] The first and the last place.
        def group_span(rows, row)
          place = rows.index { |each| each.equal?(row) }
          return [0, rows.size - 1] unless place

          group = group_of(row)
          first = place
          first -= 1 while first > 0 && group_of(rows[first - 1]) == group
          last = place
          last += 1 while last < rows.size - 1 && group_of(rows[last + 1]) == group
          [first, last]
        end

        # Tells the :group of a row.
        #
        # @param row [Hash, String] The row.
        # @return [Object, nil] Its group, nil for none.
        def group_of(row)
          row.is_a?(Hash) ? row[:group] : nil
        end

        # Numbers the group of each row for C#'s tree, in the rows' order: rows of one :group share a
        # number, and so do the rows of none.
        #
        # @param rows [Array<Hash, String>] The rows.
        # @return [Array<Integer>] The numbers.
        def group_numbers(rows)
          groups = {}
          rows.map { |row| groups[row.is_a?(Hash) ? row[:group] : nil] ||= groups.size }
        end

        # Ends Move mode with the row carried where it is now, telling moved.
        def finish_move
          row, from = @moving
          @moving = nil
          redraw
          emit(:moved, row, from, @options[:index].to_i)
        end

        # Ends Move mode with the rows as they were before it, telling moved.
        def put_back
          row, from, rows = @moving
          @moving = nil
          @options[:rows] = rows
          @options[:index] = from
          set_option(:rows, rows)
          emit(:moved, row, from, from)
        end

        # Ends Move mode without telling moved, for rows or a filter set while a row is carried.
        def abandon_move
          return unless @moving

          @moving = nil
          Tree.set(self, "moving" => false)
        end

        # Tells where a row shows now, else where the nearest row shows: the first shown that came
        # after it among the rows given, else the last shown.
        #
        # @param row [Hash, String] The row.
        # @return [Integer] Its place among the rows shown, -1 for none.
        def nearest(row)
          all = Array(@options[:rows])
          from = all.index { |each| each.equal?(row) } || 0
          shown = shown_rows
          after = shown.index { |each| (all.index { |given| given.equal?(each) } || 0) >= from }
          after || shown.size - 1
        end

        # Tells whether a row shows while something filters: it holds the filter's text, and :only and
        # every block of narrow keep it; a row with :search => false shows while there is no text,
        # whatever the blocks say.
        #
        # @param row [Hash, String] The row.
        # @param word [String] The filter's text in lower case.
        # @param only [Proc, nil] The block of :only, nil for none.
        # @return [Boolean] Whether it shows.
        def kept?(row, word, only)
          return word.empty? unless findable?(row)

          (word.empty? || filter_match?(row, word)) && (only.nil? || only.call(row)) && @narrows.values.all? { |block| block.call(row) } ? true : false
        end

        # Tells whether a row holds a filter's text.
        #
        # @param row [Hash, String] The row.
        # @param word [String] The text in lower case.
        # @return [Boolean] Whether it does.
        def filter_match?(row, word)
          text = searched_text(row)
          text ? text.include?(word) : false
        end

        # Tells the text a filter looks through in a row; a block is asked once for the rows given.
        #
        # @param row [Hash, String] The row.
        # @return [String, nil] The text in lower case, nil for a row no filter finds.
        def searched_text(row)
          return row.to_s.downcase unless row.is_a?(Hash)
          return nil if row[:search] == false
          return @searched[row.object_id] ||= row[:search].call.to_s.downcase if row[:search].respond_to?(:call)

          text = row[:search] || row[:text] || (row[:item] && Game.item_name(row[:item]))
          text.to_s.downcase
        end

        # Tells whether its parent stacks its children in a column, where growing hands out height.
        #
        # @return [Boolean] Whether it does.
        def grows_in_column?
          return false unless @parent && @parent.container?

          UI.choice(@parent.layout, Container::LAYOUTS, :column, "layout") == "column"
        end

        # Draws one row: the cursor's plate, the frame of the row under the pointer, its label, its
        # icon, its right text, its small icons and its text and its note in the room left; it tells
        # whether its text was cut.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash, String] The row.
        # @param place [Integer] Its place.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param icons [Boolean] Whether any row has an icon, so every text starts after an icon's room.
        # @param checks [Boolean] Whether any row has a box of :checked, so every row starts after its
        #   room.
        # @return [Boolean, String] Whether its text was cut, else the texts of its note's parts when
        #   they were.
        def draw_row(canvas, row, place, x, y, width, icons, checks = false)
          entry = shown_row(row)
          enabled = entry[:disabled] != true
          color = entry[:color]
          canvas.fill(x, y, width, line_height, cursor_lit? && enabled ? :picked : :tab) if cursor_here?(place)
          canvas.outline(x, y, width, line_height, :edge) if (place == @hover_row && !@options[:follow_pointer]) || (@moving && place == @options[:index])
          left = x + row_inset + entry[:indent].to_i
          if checks
            draw_check(canvas, left, y, entry[:checked]) unless entry[:checked].nil?
            left += CHECK + Style::GAP
          end
          room = label_room
          if room > 0
            label = entry[:label].to_s
            unless label.empty?
              @options[:escapes] ? draw_escaped(canvas, label, left, y, [room - Style::GAP, 1].max, :system) :
                                   canvas.text(left, y, [room - Style::GAP, 1].max, LINE_HEIGHT, label, :color => :system, :cut => true)
            end
            left += room
          end
          if icons
            canvas.icon(entry[:icon], left, y) if entry[:icon]
            left += ICON_STEP
          end
          edge = x + width - row_inset
          edge = draw_toggles(canvas, entry, place, edge, y) - (Array(entry[:toggles]).empty? ? 0 : TOGGLE_GAP - Style::GAP) if entry[:toggles]
          return draw_cells(canvas, entry, left, edge, y, color) if entry[:cells] && @options[:cells]

          edge = draw_value(canvas, entry, place, edge, y) if entry[:value]
          edge = draw_badge(canvas, entry, edge, y) if entry.key?(:badge)
          right = draw_right(canvas, entry, edge, y, entry[:right_color] || color)
          right = draw_row_gauge(canvas, entry, right, y) if entry[:gauge]
          @note_cut = nil
          unless parts_of(entry[:note]) ? entry[:note].empty? : entry[:note].to_s.empty?
            ends = right == edge ? right : right + Style::GAP - NOTE_GAP
            right = draw_note(canvas, entry, left, x + note_column(width, left - x - entry[:indent].to_i), ends, y) || right
          end
          cut = if @options[:escapes]
                  draw_escaped(canvas, entry[:text].to_s, left, y, [right - left, 1].max, color)
                else
                  canvas.text(left, y, [right - left, 1].max, LINE_HEIGHT, entry[:text].to_s, :color => color, :cut => true, :squeeze => across > 1,
                              :opacity => entry[:faint] ? Label::FAINT : nil, :highlight => @options[:highlight])
                end
          cut || @note_cut || false
        end

        # Tells the room at the left and the right of a row: the game's in the look of its own windows.
        #
        # @return [Integer] The pixels.
        def row_inset
          game_look? ? GAME_INSET : INSET
        end

        # Draws a row's :badge at the end of the room left, see Badge, in its :badge_color (:gold
        # unless told), and keeps its room while it shows nothing, so the texts of the rows keep
        # their width as a count comes and goes.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row as it draws.
        # @param edge [Integer] Where the room left ends.
        # @param y [Integer] The row's top.
        # @return [Integer] Where the room left of the badge ends.
        def draw_badge(canvas, entry, edge, y)
          text = Badge.text_of(entry[:badge])
          Badge.draw_on(canvas, edge, y, line_height, text, entry[:badge_color] || :gold) if text
          edge - Badge::ROOM
        end

        # Draws a row's :gauge as a thin bar that ends where the room left ends, in its :gauge_color.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row as it draws.
        # @param right [Integer] Where the room left for the rest of the row ends.
        # @param y [Integer] Its top.
        # @return [Integer] Where the room left ends after the gauge.
        def draw_row_gauge(canvas, entry, right, y)
          width, height = ROW_GAUGE
          canvas.gauge(right - width, y + (LINE_HEIGHT - height) / 2, width, height, entry[:gauge].to_f, :colors => entry[:gauge_color] || :bad)
          right - width - Style::GAP
        end

        # Draws a row's value at its right edge between a left and a right arrow, the arrows only
        # while the row takes input, and keeps where they lie for a click on them.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row as it draws.
        # @param place [Integer] Its place.
        # @param right [Integer] The row's right edge.
        # @param y [Integer] Its top.
        # @return [Integer] Where the room left for the rest of the row ends.
        def draw_value(canvas, entry, place, right, y)
          text = entry[:value].to_s
          arrow = canvas.text_width(VALUE_RIGHT)
          width = canvas.text_width(text)
          left = right - arrow - VALUE_GAP - width - VALUE_GAP - arrow
          less = entry[:less] != false ? :system : :dim
          more = entry[:more] != false ? :system : :dim
          canvas.text(left, y, arrow + Canvas::OUTLINE_ROOM, LINE_HEIGHT, VALUE_LEFT, :color => less) if canvas.enabled?
          canvas.text(left + arrow + VALUE_GAP, y, width + Canvas::OUTLINE_ROOM, LINE_HEIGHT, text, :color => entry[:right_color] || entry[:color])
          canvas.text(right - arrow, y, arrow + Canvas::OUTLINE_ROOM, LINE_HEIGHT, VALUE_RIGHT, :color => more) if canvas.enabled?
          @value_spots[place] = [left, right]
          left - Style::GAP
        end

        # Tells which way a click stepped a row's value: the pick came from the left button let go over
        # the value of a row of a list with :sides, its left half stepping back and its right half on.
        #
        # @param place [Integer] The row picked.
        # @return [Integer, nil] -1 or 1, nil for a pick that is no such click.
        def value_click(place)
          spot = @value_spots && @value_spots[place]
          at = Mouse.position
          return nil unless @options[:sides] && spot && at && @rect && Mouse.released?

          x = at[0] - @rect.x
          return nil unless x >= spot[0] && x < spot[1]

          x < (spot[0] + spot[1]) / 2 ? -1 : 1
        end

        # Draws the box of a row with :checked, filled while it is on.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left.
        # @param y [Integer] The row's top.
        # @param on [Boolean] Whether it is on.
        def draw_check(canvas, x, y, on)
          top = y + (LINE_HEIGHT - CHECK) / 2
          canvas.box(x, top, CHECK, CHECK, :fill => :field)
          canvas.fill(x + CHECK_INSET, top + CHECK_INSET, CHECK - 2 * CHECK_INSET, CHECK - 2 * CHECK_INSET, :text) if on
        end

        # Draws a heading row: its text in the small font and the system color, never picked.
        #
        # @param canvas [Canvas] Where it draws.
        # @param row [Hash] The row.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        def draw_heading(canvas, row, x, y, width)
          right = x + width - INSET
          Array(row[:toggle_titles]).each_with_index.to_a.reverse_each do |title, index|
            wide = @toggle_widths[index].to_i
            right -= wide
            canvas.text(right, y, wide, LINE_HEIGHT, title.to_s, :size => :small, :color => :system, :align => :center, :cut => true)
            right -= TOGGLE_GAP
          end
          canvas.text(x + INSET, y, [right - x - INSET, 1].max, LINE_HEIGHT, row[:heading].to_s, :size => :small, :color => row[:color] || :system, :cut => true)
        end

        # Tells the width of each toggle column: the widest toggle of any row at that place, or its
        # heading's title, so the toggles of every row line up under their titles.
        #
        # @param canvas [Canvas] Where they draw.
        # @param rows [Array<Hash, String>] The rows drawn.
        # @return [Array<Integer>] The widths by the toggles' places.
        def toggle_widths(canvas, rows)
          widths = []
          rows.each do |row|
            next unless row.is_a?(Hash)

            texts = Array(row[:toggles]).map { |toggle| toggle.is_a?(Hash) ? toggle[:text] : toggle } + Array(row[:toggle_titles])
            texts.each_with_index do |text, index|
              place = index < Array(row[:toggles]).size ? index : index - Array(row[:toggles]).size
              widths[place] = [widths[place].to_i, canvas.text_width(text.to_s, :small) + 2 * TOGGLE_PAD].max
            end
          end
          widths
        end

        # Draws a row's toggles at its right end, outlined while off and filled while on, the one the
        # cursor stands on framed brighter, and keeps where they lie for a click.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row.
        # @param place [Integer] Its place.
        # @param right [Integer] The row's right edge.
        # @param y [Integer] Its top.
        # @return [Integer] Where the room left for the rest of the row ends.
        def draw_toggles(canvas, entry, place, right, y)
          toggles = Array(entry[:toggles])
          return right if toggles.empty?

          spots = []
          toggles.each_with_index.to_a.reverse_each do |toggle, index|
            toggle = { :text => toggle.to_s } unless toggle.is_a?(Hash)
            wide = @toggle_widths[index].to_i
            right -= wide
            top = y + 2
            height = LINE_HEIGHT - 4
            color = toggle[:color] || :text
            if toggle[:on]
              canvas.fill(right, top, wide, height, color)
              canvas.text(right, y, wide, LINE_HEIGHT, toggle[:text].to_s, :size => :small, :color => text_on(color), :align => :center, :cut => true)
            else
              canvas.outline(right, top, wide, height, color)
              canvas.text(right, y, wide, LINE_HEIGHT, toggle[:text].to_s, :size => :small, :color => color, :align => :center, :cut => true)
            end
            canvas.outline(right - 1, top - 1, wide + 2, height + 2, :title) if place == @options[:index] && @toggle_cursor == index && cursor_lit?
            spots.unshift([right, right + wide])
            right -= TOGGLE_GAP
          end
          @toggle_spots[place] = spots
          right
        end

        # Draws a row's table cells in the columns of :cells, each cut with "..." to its width and in
        # the middle of the row's height: a String, or {:text, :color, :font_size, :align, :icons,
        # :avatar}, its avatar ({:actor, :image, :shape, :width, :height}) before its icons and text.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row.
        # @param left [Integer] The cells' left.
        # @param right [Integer] Their right edge.
        # @param y [Integer] The row's top.
        # @param color [Symbol, Integer, Color, nil] The color of a cell with none of its own.
        # @return [Boolean] Whether a cell was cut.
        def draw_cells(canvas, entry, left, right, y, color)
          widths = cell_widths(right - left)
          top = y + (line_height - LINE_HEIGHT) / 2
          cut = false
          Array(entry[:cells]).each_with_index do |cell, index|
            wide = widths[index]
            break unless wide

            cell = { :text => cell.to_s } unless cell.is_a?(Hash)
            x = cell[:avatar].is_a?(Hash) ? draw_cell_avatar(canvas, cell[:avatar], left, y, left + wide) : left
            Array(cell[:icons]).each do |icon|
              break if x + ICON_SIZE > left + wide

              canvas.icon(icon, x, top)
              x += ICON_STEP
            end
            text = cell[:text].to_s
            unless text.empty?
              align = { :end => :right, :center => :center }[cell[:align]] || :left
              cut = true if canvas.text(x, top, [left + wide - x, 1].max, LINE_HEIGHT, text, :size => cell[:font_size], :color => cell[:color] || color,
                                        :align => align, :cut => true, :highlight => @options[:highlight])
            end
            left += wide + TABLE_GAP
          end
          cut
        end

        # Draws a table cell's avatar at its left, in the middle of the row's height and cut to the
        # cell's right edge, as the avatar part draws.
        #
        # @param canvas [Canvas] Where it draws.
        # @param avatar [Hash] The avatar: :actor, :image, :shape, :width and :height.
        # @param x [Integer] Its left.
        # @param y [Integer] The row's top.
        # @param edge [Integer] The cell's right edge.
        # @return [Integer] Where the cell's icons and text start after it.
        def draw_cell_avatar(canvas, avatar, x, y, edge)
          width = UI.whole(avatar[:width])
          height = UI.whole(avatar[:height])
          @avatar_copies ||= Scaled::Copies.new(false)
          Avatar.paint(canvas, [x, y + (line_height - height) / 2, [width, edge - x].min, height], avatar[:actor], avatar[:image], avatar[:shape], :well, avatar[:hue].to_i,
                       avatar[:sampling], @avatar_copies)
          x + width + Style::GAP
        end

        # Tells the width of each table column: the widths of :cells, nil sharing what is left.
        #
        # @param room [Integer] The row's room.
        # @return [Array<Integer>] The widths.
        def cell_widths(room)
          given = Array(@options[:cells])
          fixed = given.compact.inject(0) { |sum, width| sum + width.to_i } + TABLE_GAP * [given.size - 1, 0].max
          shared = given.count(&:nil?)
          share = shared > 0 ? [(room - fixed) / shared, 0].max : 0
          given.map { |width| width.nil? ? share : width.to_i }
        end

        # Draws a text with the game's text codes on one line, measured without the codes and cut
        # with "..." to its width.
        #
        # @param canvas [Canvas] Where it draws.
        # @param text [String] The text.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param color [Symbol, Integer, Color, nil] The color of the text no code colors.
        # @return [Boolean] Whether it was cut.
        def draw_escaped(canvas, text, x, y, width, color)
          lines = Escapes.runs(UI.font_bitmap(Style::TEXT_SIZE), text.to_s, nil)
          plain = Escapes.convert(text.to_s).gsub(Escapes::CODE, "")
          return canvas.text(x, y, width, LINE_HEIGHT, plain, :color => color, :cut => true) unless lines.is_a?(Array) && lines[0]

          line = lines[0]
          cut = line["width"].to_i > width
          room = cut ? width - canvas.text_width(ELLIPSIS) : width
          Array(line["runs"]).each do |run|
            left = x + run["x"].to_i
            if run["icon"]
              break if left + ICON_SIZE > x + room

              canvas.icon(run["icon"], left, y)
              next
            end
            part = run["text"].to_s
            shown = cut ? UI.cut(UI.font_bitmap(Style::TEXT_SIZE), part, x + room - left) : part
            shown = shown.sub(/#{Regexp.escape(ELLIPSIS)}\z/, "")
            code = run["color"]
            canvas.text(left, y, [x + width - left, 1].max, LINE_HEIGHT, shown, :color => code.nil? || code == Label::NORMAL_COLOR ? color : code)
            if shown != part
              canvas.text(left + canvas.text_width(shown), y, canvas.text_width(ELLIPSIS) + Canvas::OUTLINE_ROOM, LINE_HEIGHT, ELLIPSIS, :color => color)
              break
            end
          end
          cut
        end

        # Tells where the notes of the rows start: :note_at's pixels, or after the room before a row's
        # text and the widest of its texts, else half the row.
        #
        # @param width [Integer] The rows' width.
        # @param lead [Integer] The room before a row's text: its inset, box, label and icon.
        # @return [Integer] The column from the rows' left.
        def note_column(width, lead)
          at = @options[:note_at]
          return width / 2 if at.nil?

          at.is_a?(Array) ? lead + note_texts_room : UI.whole(at)
        end

        # Tells the least room from a row's text to its note that :note_at keeps, for the width the
        # row takes drawn whole.
        #
        # @return [Integer] The pixels, 0 without :note_at.
        def note_from_text
          at = @options[:note_at]
          return 0 if at.nil?

          at.is_a?(Array) ? note_texts_room : UI.whole(at) - 2 * row_inset
        end

        # Draws a row's note, small and in its :note_color (dim by default), from its column or right after the row's text when that
        # reaches further, cut to the room it may take; a note with less than NOTE_ROOM is left out.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row as it draws.
        # @param left [Integer] Where the row's text starts.
        # @param column [Integer] Where the notes start.
        # @param right [Integer] Where the note's room ends.
        # @param y [Integer] The row's top.
        # @return [Integer, nil] Where the room left for the row's text ends, nil for a note left out.
        def draw_note(canvas, entry, left, column, right, y)
          start = [column, left + canvas.text_width(entry[:text].to_s) + Style::PAD].max
          return nil if right - start < NOTE_ROOM

          parts = parts_of(entry[:note])
          if parts
            @note_cut = parts_text(parts) if draw_parts(canvas, parts, start, y, right - start, LINE_HEIGHT, :small, entry[:note_color] || :dim)
          else
            canvas.text(start, y, right - start, LINE_HEIGHT, entry[:note].to_s, :size => :small, :color => entry[:note_color] || :dim, :cut => true)
          end
          start - Style::GAP
        end

        # Tells the parts of a row's note or right text.
        #
        # @param value [String, Array, nil] The note or the right text.
        # @return [Array<Hash>, nil] Its parts, nil for a plain text.
        def parts_of(value)
          value.is_a?(Array) ? value.select { |part| part.is_a?(Hash) } : nil
        end

        # Tells how wide parts draw, their pictures and texts and the room between them.
        #
        # @param parts [Array<Hash>] The parts.
        # @param size [Symbol, nil] Their texts' size, nil for the normal one.
        # @return [Integer] The pixels.
        def parts_width(parts, size)
          widths = parts.map do |part|
            text = part[:text].to_s
            (part_icon(part) ? PART_ICON + (text.empty? ? 0 : PART_ICON_GAP) : 0) + text_width(text, size)
          end
          widths.empty? ? 0 : widths.inject(:+) + PART_GAP * (widths.size - 1)
        end

        # Draws parts from a left edge in their order, each its picture then its text, and cuts them
        # at the room's end: a picture that does not fit whole is left out, a text is cut.
        #
        # @param canvas [Canvas] Where they draw.
        # @param parts [Array<Hash>] The parts.
        # @param x [Integer] Their left.
        # @param y [Integer] Their top.
        # @param width [Integer] Their room.
        # @param height [Integer] Their line's height; the pictures stand in its middle.
        # @param size [Symbol, nil] Their texts' size, nil for the normal one.
        # @param color [Symbol, Integer, Color, nil] The color of a text with none of its own.
        # @return [Boolean] Whether they were cut.
        def draw_parts(canvas, parts, x, y, width, height, size, color)
          left = x
          right = x + width
          parts.each_with_index do |part, place|
            left += PART_GAP if place > 0
            text = part[:text].to_s
            icon = part_icon(part)
            if icon
              return true if left + PART_ICON > right

              canvas.icon(icon, left, y + (height - PART_ICON) / 2, :side => PART_ICON)
              left += PART_ICON + (text.empty? ? 0 : PART_ICON_GAP)
            end
            next if text.empty?
            return true if left >= right
            return true if canvas.text(left, y, right - left, height, text, :size => size, :color => part[:color] || color, :cut => true)

            left += canvas.text_width(text, size)
          end
          false
        end

        # Tells the icon of a part: its :icon, else its :icon_file as a picture file.
        #
        # @param part [Hash] The part.
        # @return [Integer, Symbol, Hash, nil] The icon as Canvas#icon takes it, nil for none.
        def part_icon(part)
          return part[:icon] if part[:icon]

          part[:icon_file] ? { :file => part[:icon_file].to_s } : nil
        end

        # Joins the texts of parts, such as for the tooltip of parts drawn cut.
        #
        # @param parts [Array<Hash>] The parts.
        # @return [String] Their texts, a space apart.
        def parts_text(parts)
          parts.map { |part| part[:text].to_s }.reject { |text| text.empty? }.join(" ")
        end

        # Tells what a row shows: a String's text, a Hash as given, with an item's icon, name and color
        # where it names none of its own.
        #
        # @param row [Hash, String] The row.
        # @return [Hash] The row as it draws.
        def shown_row(row)
          return { :text => row.to_s } unless row.is_a?(Hash)

          item = row[:item]
          return row unless item

          color = Game.item_color(item, row[:bag])
          shown = { :icon => item.icon_index, :text => Game.item_name(item), :color => color == Label::NORMAL_COLOR ? nil : color }
          shown[:right] = $game_party.item_number(item).to_s if row[:count] && $game_party
          shown.merge(row.reject { |_key, value| value.nil? })
        end

        # Draws a row's right text at its right edge, with room for its outline so it is never drawn
        # narrower, and its small icons before it.
        #
        # @param canvas [Canvas] Where it draws.
        # @param entry [Hash] The row.
        # @param right [Integer] The row's right edge.
        # @param y [Integer] Its top.
        # @param color [Symbol, Integer, Color, nil] The text's color.
        # @return [Integer] Where the room left for the text ends.
        def draw_right(canvas, entry, right, y, color)
          parts = parts_of(entry[:right])
          if parts && !parts.empty?
            width = parts_width(parts, nil)
            draw_parts(canvas, parts, right - width, y, width + Canvas::OUTLINE_ROOM, LINE_HEIGHT, nil, color)
            right -= width + Style::GAP
          end
          text = parts ? "" : entry[:right].to_s
          unless text.empty?
            width = canvas.text_width(@options[:escapes] ? Escapes.convert(text).gsub(Escapes::CODE, "") : text)
            @options[:escapes] ? draw_escaped(canvas, text, right - width, y, width + Canvas::OUTLINE_ROOM, color) :
                                 canvas.text(right - width, y, width + Canvas::OUTLINE_ROOM, LINE_HEIGHT, text, :color => color)
            right -= width + Style::GAP
          end
          icons = Array(entry[:icons])
          icons.reverse_each do |icon|
            right -= SMALL_ICON
            canvas.icon(icon, right, y + (LINE_HEIGHT - SMALL_ICON) / 2, :side => SMALL_ICON)
          end
          icons.empty? ? right : right - Style::GAP
        end
      end
    end

    Engine::Container.adds(:list) { |*args| Engine::List.new(args[0] || {}) }
  end
end
