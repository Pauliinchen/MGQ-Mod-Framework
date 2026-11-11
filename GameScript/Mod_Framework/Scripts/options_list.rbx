#----------------------------------------------------------------
#  options_list.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Stopped giving its list :keep_cursor, which only a filter read
#      Paulinchen  2026-11-10: Showed a row's value anew once a mod changed it elsewhere, such as Interface Positions after a box moved
#      Paulinchen  2026-11-07: Showed the Hotkeys caption only under a mod's other rows
#                            - Listed each mod's hotkey rows after its other rows, under a small Hotkeys caption
#                            - Showed a help of its caller's while its rows lack the focus
#                            - Removed add_options of the old API
#                            - Ran the rows blocks of UI.patch on the rows it shows
#                            - Marked a greyed row with :disabled
#      Paulinchen  2026-11-06: Ended a help longer than the help line's two lines in "..." instead of cutting its third line
#                            - Called the engine's classes by their names under UI::Engine
#                            - Showed the rows of one mod as Options > Mods groups them, without the headings if asked, and
#                              told when the focus comes onto the rows and leaves them
#                            - Broke a help as one text where its own lines take more lines than the help window has
#                            - Showed the help in another help window at once
#                            - Left the ends of the list to the rules of every list, as the Mods screen moved to the UI layer
#                            - Took another source, filter, empty text or help window of the rows while it shows
#      Paulinchen  2026-11-05: Showed the help in a game window of the scene with :help_window, broken to its width, in place of
#                              the help line
#                            - Showed a waiting key row as waiting also once its source made its rows anew
#                            - Asked for the new key and named the hotkey that has a refused key as the step 8 spec words it
#                            - Logged each key a key row refused and each keep of its key
#                            - Had a key row wait for its key through C#'s tree, as every field that binds a hotkey does
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Let the list hand the focus on by Up on its first row and Down on its last
#      Paulinchen  2026-10-31: Named a bound key a hotkey
#                            - Showed only the rows whose :if allows
#      Paulinchen  2026-10-30: Listed rows of a source of its own, such as the key rows of hotkeys not loaded
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The rows of Options > Mods (Options.rows) as a list, under a heading per mod, each mod's
      # hotkey rows after its other rows under the caption Hotkeys, with a help line under it that
      # tells the cursor row's help, as Mod Config Remake showed them. Up and
      # Down move between the rows; Left, Right and a click on a value's arrows step a row's value;
      # confirm steps it on, presses a button row or has a key row wait for its next key. While a
      # key row waits, C#'s tree holds every other part from the keys and the pointer (KeyCapture):
      # a free key binds as it is let go, a cancel key and a gamepad's cancel keep the old key, and
      # a click outside the list ends the wait too.
      #
      # Options: :rows (a block that lists the rows in place of those of Options > Mods, such as key
      # rows of hotkeys whose mods are not loaded; a key is refused when another of these rows has
      # it), :mod (the name of the mod whose rows alone show, see Options.rows_of), :headings (false
      # leaves out the heading of each mod), :only (a block of a row: only the rows it answers true
      # for show), :help_line (false leaves the help line out, for a screen that shows the help in a
      # window of its own through the help event), :help_window (a game window with set_text, such
      # as the Options screen's help window, which shows the help in place of the help line),
      # :handler (a block of a button row's key that presses it and answers whether it did; without
      # one a button row buzzes), :patched_rows (blocks that each take the rows shown and answer those
      # to show, such as a row merged with :disabled => true, greyed out), :help (a text the help shows
      # while the rows lack the focus, such as what the list beside them does), :empty_text and
      # :rows_shown (the list's).
      #
      # Events: help (the cursor row's help, whenever it changes), change (row, value: a row's value
      # stepped or a key bound), enter (the focus came onto the rows), leave (the focus left them).
      class OptionsList < Stack
        # The height of the help line: two lines of the small font.
        HELP_HEIGHT = 40

        # The height of one line of the help.
        HELP_ROW = 20

        # Where the game's help window starts its text, from the left of its contents.
        HELP_WINDOW_LEFT = 4

        # The list's text when no row shows.
        EMPTY_TEXT = "None of your mods has options."

        # The caption over a mod's hotkey rows.
        HOTKEYS_CAPTION = "Hotkeys"

        # The frames between two reads of the rows' values while it shows, since a mod may change a
        # value elsewhere, such as Interface Positions once the player moved a box.
        VALUES_EVERY = 10

        # What a key row's value reads while it waits for its key.
        WAITING_TEXT = "Press a key . . ."

        # The help while a key row waits: its name and its key.
        WAIT_HELP = "Press the new key for %s.\r\nEsc keeps %s."

        # The help after a key was refused: why, and the row's key.
        REFUSED_HELP = "%s\r\nPress another key, or Esc to keep %s."

        # Why a key another key row has is refused: the key and that row's name.
        TAKEN = "%s is already the key of %s."

        # Why a key the game reads itself is refused: the key.
        GAME_KEY = "%s is one of the game's own keys."

        # Why a key the framework reads itself is refused: the key.
        FRAMEWORK_KEY = "%s is one of the framework's own keys."

        # Why a key pressed with another is refused.
        CHORD = "Press one key alone."

        # Tells whether a key row of an open options list waits for its key, while every hotkey stays
        # quiet.
        #
        # @return [Boolean] Whether one does.
        def self.waiting?
          KeyCapture.waiting?
        end

        # Shows a help in a game window, such as the game's help window: each line broken at its
        # words to the window's width; where that takes more lines than the window has, the whole
        # help broken as one text; and the lines past the window's last one joined onto that line,
        # as the untranslated game's help window has two lines and the translation's four.
        #
        # The lines are broken here because the translation's help window breaks a long line itself
        # and then draws the next line over what it broke off.
        #
        # @param window [Window_Help] The window.
        # @param text [String] The help, its lines separated by "\r\n".
        def self.show_in(window, text)
          lines = text.to_s.split(/\r?\n/)
          room = (window.height - window.standard_padding * 2) / window.line_height
          if window.respond_to?(:contents) && window.respond_to?(:contents_width)
            width = window.contents_width - HELP_WINDOW_LEFT
            broken = lines.map { |line| fitted_lines(window.contents, line, width) }.flatten(1)
            broken = fitted_lines(window.contents, lines.join(" "), width) if broken.size > room
            lines = broken
          end
          lines[room - 1..-1] = lines[room - 1..-1].join(" ") if room >= 1 && lines.size > room
          window.set_text(lines.join("\n"))
        rescue => e
          Tree.log_once([:help_window, e.class], "showing the help in a #{window.class} FAILED: #{Logging.failure(e)}")
        end

        # Breaks a line at its words into lines no wider than a width in a picture's font.
        #
        # @param picture [Bitmap] The picture whose font measures the words.
        # @param line [String] The line.
        # @param width [Integer] The width in pixels.
        # @return [Array<String>] The lines, the line alone when it fits.
        def self.fitted_lines(picture, line, width)
          lines = []
          line.split(" ").each do |word|
            joined = lines.empty? ? word : "#{lines.last} #{word}"
            if !lines.empty? && picture.text_size(joined).width <= width
              lines[-1] = joined
            else
              lines << word
            end
          end
          lines.empty? ? [line] : lines
        end

        # Tells the defaults of the options: a column 4 apart that takes its parent's room, every row,
        # with its help line.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 4, :grow => 1, :rows => nil, :mod => nil, :headings => true, :only => nil, :help_line => true, :help_window => nil,
                      :handler => nil, :empty_text => EMPTY_TEXT, :rows_shown => :fill, :patched_rows => nil, :help => nil)
        end

        options :rows, :mod, :headings, :only, :help_window, :handler, :empty_text, :patched_rows, :help

        # @return [List] The list of the rows.
        attr_reader :list

        # @return [Label, nil] The help line, nil without one.
        attr_reader :help

        # @return [String, nil] The help it told last, nil before the first.
        attr_reader :shown_help

        # Makes the list and the help line and reads the rows.
        #
        # @param options [Hash] Its options, see the class.
        def initialize(options = {})
          super
          @waiting_row = nil
          @inside = false
          build
          refresh
        end

        # Reads the rows anew, as a row's name, value or state may have changed, the cursor kept on its
        # place.
        #
        # @return [OptionsList] Itself.
        def refresh
          rows = @options[:rows] ? Array(@options[:rows].call) : Options.rows
          @source = rows
          rows = @options[:mod] ? Options.rows_of(@options[:mod], rows) : rows.select { |row| Options.shown?(row) }
          only = @options[:only]
          rows = rows.select { |row| only.call(row) } if only
          Array(@options[:patched_rows]).each { |patch| rows = patch.call(rows) }
          @list.rows = list_rows(rows)
          @shown_rows = rows
          @shown_values = values_of(rows)
          show_help
          self
        end

        # Reads the rows' values every VALUES_EVERY frames while it shows, and shows the rows anew once
        # one changed elsewhere; not while a key row waits for its key.
        #
        # @return [Boolean] Always true, while it shows.
        def frame_tick
          @ticks = @ticks.to_i + 1
          refresh if (@ticks % VALUES_EVERY).zero? && !@waiting_row && values_of(@shown_rows) != @shown_values
          true
        end

        # Draws it, and reads its rows' values from then on while it shows.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          Tree.ticking(self, true)
          super
        end

        # Follows a changed option: another source or filter of the rows reads them anew, another
        # empty text goes to the list, another help window or help shows the help.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @list

          case name
          when :rows, :mod, :headings, :only, :patched_rows then refresh
          when :empty_text then @list.empty_text = @options[:empty_text]
          when :help_window
            @shown_help = nil
            show_help
          when :help then show_help
          end
        end

        # Gives the list the focus.
        #
        # @return [OptionsList] Itself.
        def focus
          @list.focus
          self
        end

        # Tells whether one of its key rows waits for its key.
        #
        # @return [Boolean] Whether one does.
        def waiting?
          @waiting_row ? true : false
        end

        private

        # Makes the list, the help line and their wiring.
        def build
          @list = add_list(:rows => [], :rows_shown => @options[:rows_shown], :grow => 1, :sides => true, :quiet => true,
                           :empty_text => @options[:empty_text])
          if @options[:help_line] && !@options[:help_window]
            add_divider
            @help = add_label("", :wrap => true, :font_size => :small, :row_height => HELP_ROW, :height => HELP_HEIGHT, :most_lines => HELP_HEIGHT / HELP_ROW)
          end
          @list.on(:change) { |_row, _place| show_help }
          @list.on(:submit) { |row, _place| confirm(row[:data]) if row.is_a?(Hash) && row[:data] }
          @list.on(:side) { |row, _place, step| side(row[:data], step) if row.is_a?(Hash) && row[:data] }
          @list.on(:captured) { |code| take_key(code.to_i) }
          @list.on(:refused) { |code, owner, taker| refuse(code.to_i, owner, taker) }
          @list.on(:kept) do |code, how|
            KeyCapture.kept(code, how)
            finish_wait
          end
          @list.on(:released) { KeyCapture.finish(@list) }
          @list.on(:focus) { focus_moved(true) }
          @list.on(:blur) { focus_moved(false) }
        end

        # Tells the help and the enter or leave event as the focus comes onto the rows or leaves them.
        #
        # @param inside [Boolean] Whether the rows have the focus now.
        def focus_moved(inside)
          @inside = inside
          show_help
          emit(inside ? :enter : :leave)
        end

        # Turns the rows of Options > Mods into the list's: a heading per mod unless :headings is
        # false, then its rows by their names without the mod's, each with its value, its hotkey rows
        # last, under the caption Hotkeys only when other rows come before them.
        #
        # @param rows [Array<Hash>] The rows of Options > Mods.
        # @return [Array<Hash>] The list's rows.
        def list_rows(rows)
          names = rows.map { |row| Options.text(row[:name]) }
          Options.groups(names).map do |group, members|
            keys, others = members.partition { |place, _name| Options.key_row?(rows[place]) }
            shown = others.map { |place, name| list_row(rows[place], name) }
            shown << { :heading => HOTKEYS_CAPTION } unless others.empty? || keys.empty?
            shown += keys.map { |place, name| list_row(rows[place], name) }
            @options[:headings] == false ? shown : [{ :heading => group }] + shown
          end.flatten(1)
        end

        # Tells the values rows show, nil for a row without one.
        #
        # @param rows [Array<Hash>] The rows of Options > Mods.
        # @return [Array<String, nil>] The values as the rows show them.
        def values_of(rows)
          rows.map { |row| row[:sub] || Options.key_row?(row) ? Options.value_text(row) : nil }
        end

        # Turns one row of Options > Mods into the list's.
        #
        # @param row [Hash] The row.
        # @param name [String] Its name without its mod's.
        # @return [Hash] The list's row.
        def list_row(row, name)
          shown = { :text => name, :data => row, :search => name, :disabled => !Options.enabled?(row) }
          if @waiting_row && (row.equal?(@waiting_row) || row[:key] == @waiting_row[:key])
            shown[:value] = WAITING_TEXT
            shown[:right_color] = :system
          elsif row[:sub] || Options.key_row?(row)
            shown[:value] = Options.value_text(row)
          end
          shown
        end

        # Shows the cursor row's help, the key row's while it waits, or :help while the rows lack the
        # focus, and tells the help blocks when it changed.
        def show_help
          text = @waiting_row ? wait_help : (@options[:help] && !@inside ? @options[:help].to_s : cursor_help)
          @help.text = text if @help
          return if text == @shown_help

          @shown_help = text
          OptionsList.show_in(@options[:help_window], text) if @options[:help_window]
          emit(:help, text)
        end

        # Writes the cursor row's help.
        #
        # @return [String] The help, "" for no row.
        def cursor_help
          row = @list.row_at(@list.index)
          row.is_a?(Hash) && row[:data] ? Options.help_text(row[:data]) : ""
        end

        # Writes what the waiting key row asks for, after a refusal why the key was refused.
        #
        # @return [String] The help.
        def wait_help
          key = Options.value_text(@waiting_row)
          return format(REFUSED_HELP, @refusal, key) if @refusal

          format(WAIT_HELP, short_name(@waiting_row), key)
        end

        # Names a row without its mod, for the help.
        #
        # @param row [Hash] The row.
        # @return [String] The name.
        def short_name(row)
          Options.text(row[:name]).sub(/\A\s*\[[^\]]+\]\s*/, "").sub(/\A[\s\->]+/, "").strip
        end

        # Takes confirm on a row: a row of values steps on, a key row waits for its key, a button row
        # is pressed by the handler.
        #
        # @param row [Hash] The row of Options > Mods.
        def confirm(row)
          return UI.buzz unless Options.enabled?(row)
          return change(row, 1) if row[:sub]
          return start_wait(row) if Options.key_row?(row)

          handler = @options[:handler]
          handler && handler.call(row[:key]) ? UI.confirm_sound : UI.buzz
        end

        # Takes Left or Right, or a click on a value's arrows, on a row of values.
        #
        # @param row [Hash] The row of Options > Mods.
        # @param step [Integer] -1 or 1.
        def side(row, step)
          return unless row[:sub]
          return UI.buzz unless Options.enabled?(row)

          change(row, step)
        end

        # Steps a row's value, with the cursor's sound.
        #
        # @param row [Hash] The row of Options > Mods.
        # @param step [Integer] -1 or 1.
        def change(row, step)
          return UI.buzz unless Options.step(row, step)

          Sound.play_cursor
          refresh
          emit(:change, row, Options.current(row))
        end

        # Has a key row wait for its next key, the keys of the other key rows taken.
        #
        # @param row [Hash] The key row.
        def start_wait(row)
          UI.confirm_sound
          @waiting_row = row
          @refusal = nil
          KeyCapture.start(@list, taken_keys(row), row[:key])
          refresh
        end

        # Tells the keys the other key rows have, which the waiting row may not take.
        #
        # @param row [Hash] The waiting key row.
        # @return [Hash{Integer => String}] Each key with the name of the row that has it.
        def taken_keys(row)
          taken = {}
          (@source || Options.rows).each do |other|
            next if other.equal?(row) || !Options.key_row?(other)

            code = Options.current(other).to_i
            taken[code] ||= Options.text(other[:name]).strip if code > 0
          end
          taken
        end

        # Binds the key C#'s tree took for the waiting key row and tells change; the wait ends.
        #
        # @param code [Integer] Windows' code of the key.
        def take_key(code)
          row = @waiting_row
          return unless row

          Options.bind(row, code)
          finish_wait
          emit(:change, row, code)
        end

        # Tells why a key was refused in the help, and logs it.
        #
        # @param code [Integer] Windows' code of the key.
        # @param owner [String] Whose the key is: "game", "framework", "hotkey" or "chord".
        # @param taker [String, nil] The row that has it, nil for any other owner.
        def refuse(code, owner, taker)
          KeyCapture.refused(code, owner, taker)
          key = Options::Keys.name(code)
          @refusal = case owner
                     when "hotkey" then format(TAKEN, key, taker)
                     when "framework" then format(FRAMEWORK_KEY, key)
                     when "chord" then CHORD
                     else format(GAME_KEY, key)
                     end
          show_help
        end

        # Ends the wait: the rows show anew.
        def finish_wait
          @waiting_row = nil
          @refusal = nil
          refresh
        end
      end
    end
  end
end
