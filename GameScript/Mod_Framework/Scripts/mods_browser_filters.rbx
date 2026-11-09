#----------------------------------------------------------------
#  mods_browser_filters.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The rows of the mod browser's filter drawer: Clear filters, the order and the platform as
    # values, then a box with its count for each category, game, language and keyword the DLL
    # offers under their headings, the first keywords before More keywords. A component of its
    # own, so a move of its cursor renders only it.
    class BrowserFilters < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :clear => "Clear filters",
        :order => "Order",
        :platform => "Platform",
        :categories => "Categories",
        :works_with => "Works with",
        :languages => "Languages",
        :keywords => "Keywords",
        :more_keywords => "More keywords · %d",
        :this_game => "this game"
      }

      # The platforms the filters offer, by the DLL's name, see ModBrowse.PlatformPicks.
      PLATFORMS = { "pc" => "PC", "android" => "Android", "any" => "Any" }

      # The kinds of the game the filters offer, by the website's name, short so the note of the game
      # that runs fits beside them in the drawer.
      GAMES = { "english" => "English", "russian" => "Russian", "untranslated" => "Japanese" }

      # The keywords it shows before More keywords.
      SHOWN_KEYWORDS = 10

      # The place of Order among the rows, where the cursor starts.
      ORDER_ROW = 1

      # What the filters offer, see ModsTopics.BrowseTopic.
      param(:filters) { {} }

      # How many picks the player made.
      param :picks, 0

      # The order picked, by the DLL's name.
      param :order, Browser::FIRST_ORDER

      # The platform whose mods show.
      param :platform, "pc"

      # Whether the keys enter the rows as a box first, as beside the mods.
      param :enter, true

      # The browser it filters, which the picks go to.
      param :browser, nil

      # The row under the cursor.
      state :row, ORDER_ROW

      # Whether every keyword shows.
      state :every_keyword, false

      # Moves the focus onto the rows, on the row it had last.
      action :focus_rows

      # Describes the rows in a box the keys enter.
      def render
        paper enter: enter, height: :fill do
          list items, bind_index: :row, id: :mf_browser_filter_list, height: :fill, rows_shown: :fill, row: ->(item) { row_of(item) },
                      on_submit: ->(item) { picked(item) }, on_side: ->(item, step) { stepped(item, step) }
        end
      end

      # Moves the focus onto the rows.
      def focus_rows
        part(:mf_browser_filter_list).focus
      end

      private

      # Lists the rows' items: [:clear], [:order], [:platform], a heading, [group, value, name,
      # count, picked] for a box and [:more] for More keywords.
      #
      # @return [Array] The items.
      def items
        rows = [[:clear], [:order], [:platform]]
        rows += group(TEXTS[:categories], "categories", Array(filters["categories"]))
        rows += group(TEXTS[:works_with], "games", Array(filters["games"]).map { |value, count, on| [value, GAMES[value] || value.to_s, count, on] })
        rows += group(TEXTS[:languages], "languages", Array(filters["languages"]))
        keywords = Array(filters["keywords"])
        shown = every_keyword ? keywords : keywords.each_with_index.select { |(_value, _name, _count, on), place| place < SHOWN_KEYWORDS || on }.map { |each, _place| each }
        rows += group(TEXTS[:keywords], "keywords", shown)
        rest = keywords.size - shown.size
        rest > 0 ? rows + [[:more, rest]] : rows
      end

      # Heads the box rows of a group, none for a group without rows.
      #
      # @param title [String] The group's heading.
      # @param name [String] The group, as the DLL takes its picks.
      # @param offered [Array<Array>] Each pick's value, name, count and whether it is picked.
      # @return [Array] The heading and the items.
      def group(title, name, offered)
        offered.empty? ? [] : [{ :text => title, :heading => true }] + offered.map { |value, label, count, on| [name, value, label, count, on] }
      end

      # Makes a row of an item.
      #
      # @param item [Array, Hash] The item.
      # @return [Hash] The row.
      def row_of(item)
        return item if item.is_a?(Hash)

        case item[0]
        when :clear then { :text => TEXTS[:clear], :disabled => picks == 0 }
        when :order then { :text => TEXTS[:order], :value => (Browser::ORDERS.find { |name, _text| name == order } || Browser::ORDERS[0])[1] }
        when :platform then { :text => TEXTS[:platform], :value => PLATFORMS[platform] || platform.to_s }
        when :more then { :text => format(TEXTS[:more_keywords], item[1]) }
        else
          note = item[0] == "games" && item[1] == Mods.game_kind ? TEXTS[:this_game] : nil
          { :text => item[2].to_s, :check => item[4] ? true : false, :right => item[3].to_s, :right_color => :dim, :note => note }
        end
      end

      # Takes confirm or a click on a row.
      #
      # @param item [Array] The item.
      def picked(item)
        return UI.buzz if item[0] == :clear && picks <= 0

        self.every_keyword = true if browser.pick_filter(item)
      end

      # Takes Left or Right on a value row; a box row stays.
      #
      # @param item [Array] The item.
      # @param step [Integer] -1 or 1.
      def stepped(item, step)
        browser.step_filter(item, step) if item[0] == :order || item[0] == :platform
      end
    end
  end
end
