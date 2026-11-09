#----------------------------------------------------------------
#  key_help.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed add_key_help of the old API
#      Paulinchen  2026-11-06: Put the entries that do not fit its width on further lines instead of leaving them out
#                            - Called the engine's classes by their names under UI::Engine
#                            - Put the entries closer together
#      Paulinchen  2026-11-05: Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#      Paulinchen  2026-11-04: Named a hotkey of Hotkeys in an entry by the key bound to it
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Kept the cancel entry whole, leaving out the other entries that do not fit first
#      Paulinchen  2026-10-31: Named every cancel key for the game's cancel and took several buttons and keys in one entry
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A line that names keys and what they do, as the game's key help at the foot of its menus does,
      # such as "D: Filter  S: Save favorite  Tab: Search". Its :entries are Hashes of :button (one of
      # the game's buttons, such as :Z, named as the game names it for the player's keyboard or gamepad
      # setting, see Game.key_name; :B names every cancel key, see UI.cancel_keys), :key (a name of
      # its own, such as "Tab") or :hotkey (a hotkey of Hotkeys, named by its key), each an Array too
      # and several in one entry, joined with ", " and a last
      # " or ", and :text (a text, or a block asked each time it draws; nil or an empty text leaves the
      # entry out). The names draw in
      # the system color and the texts in the plain one, in the small font, each line placed by :align
      # (:end by default); the entries that do not fit its width go on to the next line, so none is
      # left out. refresh reads the names and the blocks anew, such as after the state they tell
      # changed; the framework refreshes an entry of :B itself once a text field starts or stops
      # typing.
      class KeyHelp < Component
        # What stands between a key's name and its text.
        NAME_JOIN = ": "

        # Room between two entries, small enough that a list's key help with its move and jump keys
        # fits a window 640 wide.
        ENTRY_GAP = 10

        # Where the line may lie in its width.
        ALIGNS = [:start, :center, :end]

        # Tells the defaults of the options: no entries, in the small font, at the end of its width.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:entries => [], :font_size => :small, :text_align => :end)
        end

        # Tells which properties of C#'s tree each option sets: other entries measure anew.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:entries => ["measured"], :font_size => ["measured"])
        end

        options :entries, :font_size, :text_align

        # Tells the entries it shows now: each key's name and its text, those without a text left out.
        #
        # @return [Array<Array<String>>] The names and the texts.
        def shown_entries
          Array(@options[:entries]).map do |entry|
            text = entry[:text].respond_to?(:call) ? entry[:text].call : entry[:text]
            next nil if text.nil? || text.to_s.empty?

            [listed(entry_names(entry)), text.to_s]
          end.compact
        end

        # Tells whether an entry names the cancel keys, which change while a text field types.
        #
        # @return [Boolean] Whether one does.
        def names_cancel?
          Array(@options[:entries]).any? { |entry| cancels?(entry) }
        end

        # Tells the line as it reads, such as "D: Filter  S: Save favorite".
        #
        # @return [String] The line.
        def line
          shown_entries.map { |name, text| name + NAME_JOIN + text }.join("  ")
        end

        # Reads the names and the texts anew, measures and draws the line again.
        #
        # @return [KeyHelp] Itself.
        def refresh
          relayout
          self
        end

        # Tells its size: every entry on one line in the small font, and as many lines as the entries
        # take in the width C# gave it last.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          widths = entry_widths
          [widths.inject(0) { |sum, width| sum + width } + ENTRY_GAP * [widths.size - 1, 0].max, line_count(widths) * line_height]
        end

        # Takes the place C# gave it, and is measured again when its entries take other lines there.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          lines = line_count(entry_widths)
          super
          relayout if lines != line_count(entry_widths)
        end

        # Draws the entries line by line, broken as they were measured, each name in the system color
        # before its text.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          size = UI.font_px(@options[:font_size])
          pieces = shown_entries.map do |name, text|
            named = name + NAME_JOIN
            [named, text, canvas.text_width(named, size) + Canvas::OUTLINE_ROOM, canvas.text_width(text, size) + Canvas::OUTLINE_ROOM]
          end
          lines = broken(entry_widths, canvas.width)
          top = [(canvas.height - lines.size * line_height) / 2, 0].max
          lines.each_with_index do |line, row|
            drawn = line.map { |place| pieces[place] }
            total = drawn.inject(0) { |sum, piece| sum + piece[2] + piece[3] } + ENTRY_GAP * (drawn.size - 1)
            x = [start_of(canvas.width, total), 0].max
            y = top + row * line_height
            drawn.each do |name, text, name_width, text_width|
              canvas.text(x, y, name_width, line_height, name, :size => size, :color => :system)
              canvas.text(x + name_width, y, text_width, line_height, text, :size => size)
              x += name_width + text_width + ENTRY_GAP
            end
          end
        end

        private

        # Tells the width of each entry it shows: its name with the join and its text in its font.
        #
        # @return [Array<Integer>] The widths.
        def entry_widths
          bitmap = UI.font_bitmap(UI.font_px(@options[:font_size]))
          shown_entries.map { |name, text| UI.text_width(bitmap, name + NAME_JOIN) + UI.text_width(bitmap, text) + 2 * Canvas::OUTLINE_ROOM }
        end

        # Tells how many lines the entries take in the width C# gave it last, one before it has a width.
        #
        # @param widths [Array<Integer>] The entries' widths.
        # @return [Integer] The lines.
        def line_count(widths)
          @rect && @rect.width > 0 ? [broken(widths, @rect.width).size, 1].max : 1
        end

        # Breaks the entries into lines that fit a width, each line as full as the entries in their
        # order let it be; an entry wider than the width takes a line of its own.
        #
        # @param widths [Array<Integer>] The entries' widths.
        # @param room [Integer] The width.
        # @return [Array<Array<Integer>>] The places of the entries on each line.
        def broken(widths, room)
          lines = []
          used = nil
          widths.each_with_index do |width, place|
            if used && used + ENTRY_GAP + width <= room
              lines.last << place
              used += ENTRY_GAP + width
            else
              lines << [place]
              used = width
            end
          end
          lines
        end

        # Tells whether an entry names the game's cancel button.
        #
        # @param entry [Hash] The entry.
        # @return [Boolean] Whether it does.
        def cancels?(entry)
          Array(entry[:button]).any? { |button| button.to_s.upcase == "B" }
        end

        # Names the keys of an entry: its buttons as the game names them, cancel by every cancel key
        # as UI.cancel_keys does, then its own keys.
        #
        # @param entry [Hash] The entry.
        # @return [Array<String>] The names, each once.
        def entry_names(entry)
          buttons = Array(entry[:button]).map { |button| button.to_s.upcase == "B" ? UI.cancel_names : [Game.key_name(button)] }
          hotkeys = Array(entry[:hotkey]).map { |action| Hotkeys.label(action) }
          (buttons.flatten + Array(entry[:key]).map { |key| key.to_s } + hotkeys).reject { |name| name.empty? }.uniq
        end

        # Joins names with ", " and a last " or ", such as "X, Numpad 0 or F11".
        #
        # @param names [Array<String>] The names.
        # @return [String] The list; the name alone for one.
        def listed(names)
          names.size < 2 ? names.join : "#{names[0..-2].join(', ')} or #{names[-1]}"
        end

        # Tells where the line starts in a width by :text_align.
        #
        # @param width [Integer] The width.
        # @param total [Integer] The line's width.
        # @return [Integer] The left.
        def start_of(width, total)
          case UI.choice(@options[:text_align], ALIGNS, :end, "key help align")
          when "start" then 0
          when "center" then (width - total) / 2
          else width - total
          end
        end

        # Tells the height of the line.
        #
        # @return [Integer] The pixels.
        def line_height
          UI.line_height_of(@options[:font_size])
        end
      end
    end
  end
end
