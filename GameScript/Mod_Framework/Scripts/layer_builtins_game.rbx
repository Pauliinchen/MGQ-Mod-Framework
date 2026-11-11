#----------------------------------------------------------------
#  layer_builtins_game.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Told a slot of slot_row and a line of lines picked to on_submit in place of on_pick
#      Paulinchen  2026-11-09: Added title_after: to header, parts right after its title
#                            - Let a slot of slot_row and a line of lines take a tooltip of markup
#      Paulinchen  2026-11-07: Removed equip_compare and gem_compare, which the components Compare and GemCompare of UI::Equip replace
#                            - Added trailing: to header, a part at the end of its title row
#                            - Added most_rows: to lines, the most rows it asks room for, such as for a compact form
#                            - Passed the disabled: of a slot on as it is
#      Paulinchen  2026-11-05: Added slot_row, header, stat_grid and lines, general parts that replace the gear-only stats,
#                              item_header, sockets, equip_summary and equip_details
#                            - Played the buzzer for a gem pick in a slot whose gems cannot change, and pulsed sockets by a
#                              call of the handle of sockets and equip_details in place of pulse:
#                            - Added equip_compare and gem_compare, the item worn and the gem a socket holds set against another
#      Paulinchen  2026-11-04: Added equip_summary and equip_details, what an item adds summed up and its details by part
#                            - Added item_header and sockets, the head and the gems of an item that follow the gear
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer that show data in rows: a row of icon slots, a header, a grid
      # of stats and lines of text. Like layer_builtins.rbx
      # this file loads without the game, so the tool writing docs/ui reads it too.
      module Builtins
        # The engine's font of each size: param of a grid of stats.
        GAME_SIZES = { :small => :small, :medium => :normal, :large => :large }

        # The height of a row of a dense grid of stats, and the room between its columns.
        DENSE_ROW = 18
        DENSE_GAP = 8

        # The engine's font of each size: param of lines and of a group's title.
        LINE_SIZES = { :tiny => :tiny, :small => :small, :medium => :normal }

        # The height of a row of lines of each size.
        LINE_ROWS = { :tiny => 14, :small => 18, :medium => 24 }

        # The font and the height of a row of a line's detail under it.
        DETAIL_SIZE = :tiny
        DETAIL_ROW = 15

        # Tells the doc of a handle's pulse call of the parts it pulses.
        #
        # @param what [String] The parts, such as "slots".
        # @return [Hash] The call's :args and :doc.
        def self.pulse_doc(what)
          { :args => what, :doc => "pulses those #{what} once, from 0, such as those a change just touched; asked as they change, they pulse as they show anew" }
        end

        # Tells whether a tooltip of a slot or a line is markup: a lambda that takes nothing, such as
        # -> { text "Ruby" }; the engine's block that fills a tooltip's box takes the box.
        #
        # @param tooltip [Object] The tooltip.
        # @return [Boolean] Whether it is.
        def self.markup_tip?(tooltip)
          tooltip.is_a?(Proc) && tooltip.arity == 0
        end

        # Takes the markup tooltips out of slots or lines, also out of the lines of a group: each
        # such slot or line takes :tip, the number of its markup, in place of its tooltip, so it
        # stays equal from one render to the next, and the markup goes into a slot of its own.
        #
        # @param list [Array] The slots or the lines and groups.
        # @return [Array] The slots or lines with :tip, and the markup by number.
        def self.markup_tips(list)
          tips = []
          mark = lambda do |entry|
            next entry unless entry.is_a?(Hash) && markup_tip?(entry[:tooltip])

            tips << entry[:tooltip]
            entry.merge(:tooltip => nil, :tip => tips.size - 1)
          end
          marked = Array(list).map do |entry|
            if entry.is_a?(Hash) && entry[:lines].is_a?(Array)
              entry.merge(:lines => entry[:lines].map { |line| mark.call(line) })
            elsif entry.is_a?(Array)
              [entry[0], Array(entry[1]).map { |line| mark.call(line) }]
            else
              mark.call(entry)
            end
          end
          [marked, tips]
        end

        Declarations.define(:slot_row,
                            :summary => "A row of icon slots to pick, such as the gems in an item's sockets or a party member's skills: each slot its " \
                                        "icon with its tooltip, or the empty mark.", :args => [:slots],
                            :params => { :slots => { :type => :array, :default => [],
                                                     :doc => "a slot each: nil for an empty one, an icon, or { icon:, tooltip:, disabled: }, tooltip: a text or markup as a lambda, such as -> { text \"Ruby\" }" },
                                         :empty_icon => { :type => :icon, :doc => "the empty mark: the icon of an empty slot; an empty well without it" },
                                         :empty_tooltip => { :type => :text, :doc => "the tooltip of an empty slot" },
                                         :empty => { :type => :text, :doc => "what shows, dim, in place of the row without slots" },
                                         :note => { :kind => :content, :type => :text, :doc => "parts at the end of the tooltip of each slot that is not empty, such as \"Click to change\"" } },
                            :events => { :submit => "the slot picked, from 0" },
                            :actions => { :pulse => pulse_doc("slots").merge(:call => lambda { |part, places| Layer.after_render { part.engine.pulse(Array(places)) unless part.gone } }) },
                            :keys => "with on_submit: as it is made, each slot takes the keys and confirm picks it; without, the keys pass over them",
                            :pad => "as the keys", :mouse => "a click picks a slot; resting on one shows its tooltip",
                            :places => "`note`, the parts at the end of each slot's tooltip",
                            :make => lambda { |options| Slots.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:slots => markup_tips(params[:slots])[0], :empty_icon => params[:empty_icon], :empty_tooltip => params[:empty_tooltip],
                                                   :none => params[:empty].to_s, :acts => !params[:on_submit].nil?)
                            end,
                            :tips => lambda { |params| markup_tips(params[:slots])[1] },
                            :wire => lambda { |part| part.engine.on(:click) { |place, _slot| Layer.dispatch(part, :on_submit, [place]) } if part.node.params[:on_submit] },
                            :sync => lambda { |part, _wanted| Layer.sync_note(part) })

        Declarations.define(:header,
                            :summary => "A head over what follows, such as an item's or a party member's: an icon, a large title in a color of its own, " \
                                        "marks after the title and a small line under it.", :args => [:title],
                            :params => { :title => { :type => :text, :doc => "what it says, large" },
                                         :title_color => { :type => :color, :doc => "the title's color; the plain text color without it" },
                                         :icon => { :type => :icon, :doc => "an icon before the title, twice an icon's size; given as nil, its room stays empty, such as for an empty slot" },
                                         :subtitle => { :type => :text, :doc => "a small line under the title" },
                                         :subtitle_color => { :type => :color, :default => :dim, :doc => "the subtitle's color" },
                                         :marks => { :type => :array, :default => [], :doc => "icons after the title, each { icon:, tooltip: }, such as the elements a weapon strikes with" },
                                         :title_after => { :kind => :content, :type => :text, :doc => "parts right after the title and its marks, such as a chip of the elements a weapon strikes with" },
                                         :dense => { :type => :bool, :default => false, :doc => "one row of a line's height: an icon of an icon's size, the title and the subtitle after it" },
                                         :note => { :kind => :content, :type => :text, :doc => "parts after the subtitle, such as a Details button" },
                                         :trailing => { :kind => :content, :type => :text,
                                                        :doc => "a small part at the end of the title's row, such as a star that marks a favorite; dense, it follows the subtitle" } },
                            :events => { :click => "nothing; its icon or its title was clicked" },
                            :keys => "none of its own", :mouse => "a mark names itself in its tooltip; a click tells on_click",
                            :places => "`title_after`, the parts right after the title; `note`, the parts after the subtitle; `trailing`, the part at the end of the title's row",
                            :make => lambda { |options| Header.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:title => params[:title].to_s, :title_color => color(params[:title_color]), :icon => params.key?(:icon) ? params[:icon] : false,
                                                   :subtitle => params[:subtitle].to_s, :subtitle_color => color(params[:subtitle_color] || :dim),
                                                   :marks => Array(params[:marks]), :compact => params[:dense] == true)
                            end,
                            :wire => lambda { |part| wire_click(part) },
                            :sync => lambda { |part, wanted| Layer.sync_header_note(part, wanted) })

        Declarations.define(:stat_grid,
                            :summary => "Name and value rows in columns, such as a party member's stats; given the rows before a change, it colors the " \
                                        "values that rose or fell in the game's colors for better and worse.", :args => [:rows],
                            :params => { :rows => { :type => :array, :default => [],
                                                    :doc => "a row each: { name:, value: }, with key: when two rows share a name, and number: for a value that is no number, such as 20 for \"+20%\"" },
                                         :before => { :type => :array,
                                                      :doc => "the rows before a change, such as before new gear: a value higher than the row of the same key or name there shows in the game's color for better, a lower one in its color for worse" },
                                         :columns => { :type => :int, :default => 1, :doc => "how many columns the rows fill" },
                                         :size => { :values => GAME_SIZES.keys, :default => :medium, :doc => "the size of its font" },
                                         :dense => { :type => :bool, :default => false, :doc => "lower rows and less room between the columns" } },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| Stats.new(options) },
                            :options => lambda do |params|
                              dense = params[:dense] == true
                              common(params).merge(:rows => Array(params[:rows]), :against => params[:before], :columns => params[:columns] || 1,
                                                   :font_size => GAME_SIZES[params[:size] || :medium], :row_height => dense ? DENSE_ROW : nil,
                                                   :column_gap => dense ? DENSE_GAP : nil, :better_color => Game::POWER_UP_COLOR, :worse_color => Game::POWER_DOWN_COLOR)
                            end)

        Declarations.define(:lines,
                            :summary => "Lines of text that show as many as their room holds, never scrolling, such as an item's effects: alone or in " \
                                        "groups with their labels, in one or two columns; the last line tells how many more there are.", :args => [:lines],
                            :params => { :lines => { :type => :array, :default => [],
                                                     :doc => "a line each: a text, or { text:, color:, icon:, item:, tooltip:, detail: }, tooltip: a text or markup as a lambda, detail: a small line under it; or a group { label:, lines: }" },
                                         :columns => { :values => [1, 2, :auto, :room], :default => 1,
                                                       :doc => ":auto takes a second column only when one does not hold them all; :room takes two whenever every line fits a column's width" },
                                         :span => { :type => :bool, :default => false, :doc => "the lines lie across the columns row by row; a line too wide for a column takes a whole row" },
                                         :titles => { :type => :bool, :default => true, :doc => "each group's label stands beside its first line" },
                                         :sort => { :type => :bool, :default => false, :doc => "sorts the lines in each group by their text" },
                                         :size => { :values => LINE_SIZES.keys, :default => :small, :doc => "the size of its font; its rows are 14, 18 or 24 pixels high" },
                                         :color => { :type => :color, :doc => "the color of every line without one of its own" },
                                         :escapes => { :type => :bool, :default => false, :doc => "draws the game's text codes, such as \\C[2] for a color and \\I[64] for an icon" },
                                         :gutter => { :type => :int, :default => 0, :doc => "the width of the room at their left that holds each group's label, in pixels" },
                                         :spacing => { :values => (0..6).to_a, :default => 3, :doc => "room between two columns, 4 px a unit" },
                                         :group_spacing => { :values => (0..6).to_a, :doc => "room between two groups, 4 px a unit; 2 px without it" },
                                         :more_text => { :type => :text, :doc => "the last line once lines are left out, %d for how many; \"+%d more\" without it" },
                                         :more_color => { :type => :color, :doc => "that line's color; dim without it" },
                                         :empty => { :type => :text, :doc => "a dim line that shows without lines" },
                                         :most_rows => { :type => :int, :doc => "the most rows it asks room for, such as one in a compact form; given more room it still shows what the room holds" },
                                         :note => { :kind => :content, :type => :text, :doc => "parts at the end of the tooltip of each line that has one, such as \"Confirm to change\"" } },
                            :events => { :submit => "the line picked, from 0 among all of them; with on_submit: each line takes the keys",
                                         :more => "the last line, which tells how many more lines there are, was clicked: the lines left out" },
                            :actions => { :pulse => pulse_doc("lines").merge(:call => lambda { |part, places| Layer.after_render { Array(places).each { |place| part.engine.pulse(place) } unless part.gone } }) },
                            :keys => "with on_submit: as it is made, Up and Down walk the lines and confirm picks one; lines whose details do not all fit " \
                                     "take a row each, and only the line with the cursor shows its detail; without, none",
                            :pad => "as the keys", :mouse => "with on_submit: a click picks a line; a click on the last line tells on_more; resting on a line shows its tooltip",
                            :places => "`note`, the parts at the end of each line's tooltip",
                            :make => lambda { |options| Lines.new(options) },
                            :options => lambda do |params|
                              size = params[:size] || :small
                              picks = !params[:on_submit].nil?
                              options = common(params).merge(:lines => markup_tips(params[:lines])[0], :columns => params[:columns] || 1, :span => params[:span] == true,
                                                             :titles => params[:titles] != false, :sort => params[:sort] == true ? true : nil, :font_size => LINE_SIZES[size],
                                                             :row_height => LINE_ROWS[size], :color => color(params[:color]), :escapes => params[:escapes] == true,
                                                             :gutter => params[:gutter] || 0, :column_gap => spacing(params[:spacing] || 3),
                                                             :group_gap => params[:group_spacing] ? spacing(params[:group_spacing]) : 2, :empty_text => params[:empty],
                                                             :cursor => picks, :compact => picks ? :auto : false, :detail_size => DETAIL_SIZE, :detail_height => DETAIL_ROW)
                              options[:more_text] = params[:more_text].to_s if params[:more_text]
                              options[:more_color] = color(params[:more_color]) if params[:more_color]
                              options[:most_rows] = params[:most_rows] if params[:most_rows]
                              options
                            end,
                            :tips => lambda { |params| markup_tips(params[:lines])[1] },
                            :wire => lambda do |part|
                              part.engine.on(:more) { |rest| Layer.dispatch(part, :on_more, [rest]) }
                              part.engine.on(:submit) { |_line, place| Layer.dispatch(part, :on_submit, [place]) } if part.node.params[:on_submit]
                            end,
                            :sync => lambda { |part, _wanted| Layer.sync_note(part) })
      end
    end
  end
end
