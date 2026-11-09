#----------------------------------------------------------------
#  components.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Moved the components into one file per family, keeping the parts they share
#                            - Removed ItemBlock, which nothing used any more
#                            - Put a part at the end of a header's title row, after room that pushes it there unless it is compact
#                            - Drew a chip as a pill lower than a button, filled in its :color by its :variant with its text contrasting
#                              and its icon scaled down
#                            - Read the rows blocks of patches from a declared attribute
#                            - Read a greyed row, slot, chip and choice from :disabled
#                            - Named the characters a text field types for the cancel keys C# says leave it
#                            - Stopped refusing the focus and the hotkeys for typing outside the text fields
#      Paulinchen  2026-11-06: Measured a compact header as wide as its title and its subtitle whole
#                            - Stood an alert's line in the middle of its height, level with its buttons and its close mark
#                            - Measured a list that fills its room as high as all its rows, giving back what its parent lacks
#                            - Measured a list as wide as its widest row, lines as wide as their widest line and a text field
#                              as wide as its placeholder
#                            - Ended a card's last line with the ellipsis where more did not fit, as every cut text
#                            - Wrote a bar's texts in the text that contrasts with the bar under each
#                            - Wrote the text of a button, a tab and a chip in the text that contrasts with its plate, a chip that is off unfaded
#                            - Removed the add_ helpers of the checkbox, the text field, the group, the slots and the chips, which nothing called
#                            - Stopped timing the frame for the probe, which is gone
#                            - Removed the select, its list and the tags, and the add_ helpers of the alert, the header and the tabs, which nothing called
#                            - Called the engine's classes by their names under UI::Engine
#                            - Let a label show the first of its :shorter texts that fits its line when its text does not
#                            - Closed and moved a select's list and the box of the chips left out with their part through :opened_from
#                            - Let Page Up and Page Down on a list scroll the box that scrolls beside it instead, with :pages_beside
#                            - Let a numeric field's subclass name the text its typing starts with
#                            - Took out the tabs that stay stops of the arrows while keys step them, which the old mod browser
#                              alone used
#                            - Showed no cursor in a list of rows to read, which has neither an action nor a bind
#                            - Took out the row of tabs as one key stop, which no screen uses any more
#                            - Drew a list row's badge at its end
#                            - Drew the rows and the body text of a part in the game's own look in the game's own font size
#                            - Kept the game's room at both ends of a list's rows in the look of the game's own windows
#                            - Showed the cursor of a list in a root joined to a game window only while the list has the focus
#      Paulinchen  2026-11-05: Let an alert's text wrap into lines up to its most_lines
#                            - Read the seconds of real time from the clock that toasts and bubbles count by
#                            - Told how many lines a text shows and how high each is
#                            - Cut a card's picture lower where a wide card leaves too little room for its texts under it
#                            - Let a list's rows share the height it is given between the rows it shows
#                            - Drew an icon of the game's iconset or a name UI.icon gave one in a part of a row's note or right text
#                            - Kept a list's scrolled place in one rectangle and walked the roots for button hotkeys without a copy
#                            - Added the header, an icon, a title, marks after it and a line under it
#                            - Gave a group's note a size of its own
#                            - Ended the tooltips of slots and of lines in a note, and showed a dim text in place of slots without any
#                            - Moved a select's list and the box of the chips left out with their root
#                            - Held and drained a gauge's trail in real seconds, and filled a gauge without colors in the
#                              theme's primary color
#                            - Took the last letter away by a gamepad's B in the game's letters, closed them on an
#                              empty text and titled them by a text field's :letters_title
#                            - Told what heads a group, and drew a field's value on a plate with :plate
#                            - Added the numeric field, a number typed as into a text field or stepped within its bounds
#                            - Gave a text field Enter by a key bound to confirm that types nothing into it
#                            - Gave a checkbox a third state and the texts of its two states, and added the switch,
#                              which Left and Right turn
#                            - Told the root a text field lies in as it starts and stops typing, and as a cancel stops it
#                            - Handed the focus to the part under a bar of tabs alone with :enter as a tab is picked, and
#                              let cancel there walk back to the tab
#                            - Swept a stripe along a gauge that shows no rate, every second frame while animations run
#                            - Told a button without a hotkey no key codes without making lists
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Pulsed a line of Lines anew on the labels a new layout makes while its pulse runs
#                            - Logged what the buzzer refused and why, when told
#                            - Counted a line in a row of its own in the last row of Lines when it leaves no room beside
#                            - Showed a stat a reading lacks in the worse color when it is judged against another
#                            - Let a label draw nothing rather than a cut text
#                            - Drew a bar in a line's accent color down its left edge, as a toast shows its severity
#                            - Gave the alert an accent bar in its color, an icon, a lower dense look and a close mark
#                            - Told C#'s tree the group of each row of a list whose rows move and whether the move hotkeys
#                              move them, and moved a row where the tree tells the move hotkeys took it
#                            - Kept the look of the parts of a root under another that holds the game's buttons; only a
#                              disabled part greys out
#                            - Drew the cell of a list row in an animated color anew whenever the list draws
#                            - Let lines fade by their opacity, keeping their color names
#                            - Laid the box of the chips left out and a select's list above every window and dialog
#                            - Took no input on a disabled part: tabs step past a disabled tab, slots buzz on a disabled
#                              slot, and a row that takes no pick neither moves, steps its value nor toggles
#                            - Hid a disabled chip's close mark and the value arrows of a row that takes no input
#                            - Drew a filled button's text with the outline that contrasts with it
#                            - Put a completion taken in place of the last word typed, before telling complete
#                            - Pressed the buttons by their hotkeys without making objects in a frame no hotkey went down
#      Paulinchen  2026-11-04: Kept chips to :most of them, named the chip for the others by :more_text, let chips be read
#                              only, and drew a chip in its own :color with a mark that closes it while it is :closeable
#                            - Told which chip a context menu is for and whether it closes
#                            - Drew a divider in a color and a thickness of its own
#                            - Stretched a picture to its place with :fit => :fill
#                            - Showed a list's rows as the UI.patch blocks that change them answer
#                            - Drew a button in the look the theme gives its :variant in its :color, its text in its own
#                              :text_color where it has one and without an outline on a filled plate
#                            - Let a text field rest without typing where C# tells, until confirm or a click wakes it
#                            - Left a list's following of the pointer and going round to C# unless they are set
#                            - Named a button's hotkey the UI layer declared with :show_key
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Measured the button hotkeys' frame while a probe runs
#                            - Marked only the slots of Slots as chosen, never the text Sockets shows without any
#                            - Wrote the text on a picked tab in its own color and on a list's toggle that is on in the
#                              text that contrasts with the fill
#                            - Greyed out a part that takes no input and a row that takes no pick instead of drawing
#                              them see-through
#      Paulinchen  2026-11-01: Moved the cursor's row of a list one place within its group by a step
#                            - Made tabs with :stop one key stop above their pages, the cursor drawn on the picked tab, and
#                              marked the pages of tabs for C#'s tree
#                            - Drew a label with :plate => :text on a plate as wide as its text
#                            - Kept each cell of a list on a picture of its own until its row, width or state changes, so a move
#                              of the cursor draws only the two cells it leaves and enters
#                            - Drew a card row with its version, lines under its name, the last wrapped, a dark plate and its
#                              picture beside its texts
#                            - Hid the cursor of a list in a box the keys enter while the focus is outside the box
#                            - Let a click on any row of a list pick it at once
#                            - Copied the picture of a card scaled once instead of scaling it at every draw
#                            - Kept tabs that keys step as stops of the arrows when asked
#                            - Told a text field left by a cancel key
#                            - Picked a row at once by a click on its box, also while the cursor stood on another row
#                            - Held what a gauge lost in its trail for two seconds before the trail drains
#                            - Recolored the lines of a Lines without laying them out anew
#                            - Gave a text field typed into once confirmed a help that names the key starting it and the
#                              keys keeping and putting back its text
#                            - Stopped a typing field at once when code takes its focus away
#                            - Locked the text box of a typing field as it turns read-only
#                            - Drew a text field and tabs in a font size of their own
#                            - Lit the completion a script picks with completion_index= at once
#                            - Drew a list row's thin gauge left of its right text and indented a row by its :indent
#                            - Kept the cursor off the tabs that the arrows step
#      Paulinchen  2026-10-31: Told C# the characters a text field types of the keys bound to cancel, so only those that type
#                              nothing leave it
#                            - Drew a button's hotkey before its text and anew once the player binds another key
#                            - Typed neither the numpad's Alt codes nor the character of the hotkey that opened a field
#                            - Closed a root by a button with :closes for the reason :button, and quieted the buttons of a root under
#                              another that holds the game's buttons
#                            - Kept a wrapped label to a most number of lines, drew a label on a plate and lowered its font before
#                              it cuts, and put a note at a group heading's right
#                            - Drew a gauge's label, value and the first of its texts that fits, its trail, its colors from the top to
#                              the bottom and a frame of two pixels
#                            - Added tags, read-only values on plates in a row that count the rest
#                            - Added toggles to a list's rows, set one row anew, told an item's description, drew the game's text
#                              codes in rows, went round at the ends, drew table cells, dimmed a value's arrows and kept the
#                              cursor on a row's key
#                            - Made tabs a bar alone, colored a tab, stepped tabs by the arrows, moved the focus into a tab's page
#                              and dropped the first lines of a label in a column that keeps its newest parts
#                            - Read and set a text field's caret, claimed keys by name and with Alt, showed completions, made
#                              a field read-only or typed into only once confirmed, cut its last line with ... and opened
#                              the game's letters for a gamepad
#                            - Told a list a pick of a row that takes none
#                            - Scrolled a log a text field steers, and told a field's help while it types
#                            - Drew a label without its outline
#                            - Cut a cell out of a sheet of the game's system pictures
#                            - Drew a list heading in its own color
#      Paulinchen  2026-10-30: Drew pictures in the parts of a list row's note and right text, and named the framework's
#                              own pictures
#                            - Drew a button's picture smaller than an icon at its own size
#                            - Let Left and Right step the value of a list's row only on a row that has one
#                            - Wrote a size in bytes as the player reads it
#                            - Let a list of columns and a text field of one line hand the focus on past their sides, and a
#                              list up to the text field that steers it
#                            - Drew a picture across the top of each row of a list taller than a line, as cards, and blurred
#                              and labelled a picture
#                            - Showed a badge with a count or a dot at the end of a button
#                            - Added the alert, a notice with buttons on a plate across its parent
#                            - Let a list step the value of its row by Left, Right and a click on the value's arrows,
#                              and pick a row without a sound of its own
#                            - Headed the groups of a list's rows with heading rows the cursor passes over
#                            - Let a list hand the focus on past its first and last line
#                            - Let a list row color its right text and its note
#                            - Let a list carry a row to another place by the keys or a drag of the pointer
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-29: Let a list row show a box ticked while it is on
#                            - Let a list show its rows side by side in columns
#                            - Let Lines be key stops line by line, fold to one row each with the cursor's detail
#                              shown when they do not fit, and draw their details in a size of their own
#                            - Let a button's hotkey be several keys, pressed in the window of a typing field by keys
#                              it does not take
#                            - Let chips turn on by the digits and stay off while disabled, a list keep its cursor
#                              through a new filter and a field refuse characters quietly
#                            - Let an item block name its item in a size of its own
#                            - Let a list fill its room with whole rows, take filters of several parts, count the bag
#                              and pass the focus on a pick
#                            - Let slots start on the first empty one, fade, pulse, keep their ids and pass the focus
#                            - Let chips steer a list and stats follow a character
#                            - Let stats take another character in place
#                            - Let a button click without a sound of its own
#                            - Let chips keep to a number of rows, the others behind a chip that opens them
#                            - Added fields, item blocks, a text for no lines and counts and lists in words
#                            - Drew a chosen slot and a chip that is on in a bright frame and kept the picked plate
#                              for the key focus
#                            - Let :only keep a list's rows that no search finds and showed a filtered list from its
#                              first row
#                            - Kept a list row's note clear of its right text
#                            - Let a button's hotkey be a hotkey the player binds
#                            - Showed an item in labels and list rows as the game's menus show it, and squeezed a
#                              label too wide before cutting it
#                            - Let the shoulder buttons step tabs and hid tabs
#                            - Added the tiny font's line height and one color for every line of Lines
#                            - Let Lines lie row by row with a line too wide for a column across the row
#                            - Split lines without groups evenly in a room as high as their measure
#                            - Added the room between the columns of stats
#                            - Let a button take a font size and a color
#                            - Added the Library portrait, covering, anchors and fixed scales to pictures and icons
#                            - Added icons, colors, a font size and a row height to stat rows
#                            - Judged a stat the other reading lacks against its base
#                            - Let a list filter its rows by a text
#                            - Added the empty well of an icon button and kept a button no block answers quiet
#                            - Let a list keep its cursor under the pointer and frame the row there
#                            - Put a list's rows on the viewport of what its root lies on
#                            - Added the text field, which can steer a list
#                            - Added Lines, which show as many lines as their room holds, and a bar beside tabs
#                            - Let a label set its line height and draw faint, squeeze a line with escape codes,
#                              stats and lists draw a row faint, buttons draw flat and a list leave L and R alone
#                            - Added groups, icon slots, stats judged against another reading and paired with it,
#                              and lines sorted, without their groups' names or in two columns by their room
#                            - Let slots be one key stop with a chosen place, a list row take a note and a button
#                              draw as chosen
#                            - Let Tab and a gamepad's shoulder buttons step tabs
#                            - Kept a list's right texts whole and clear of its scrollbar, and the cursor's plate
#                              on a row that takes no pick unlit
#                            - Let a line of Lines take a row of its own under the others
#                            - Added chips the player turns on and off and let a list keep only the rows a block allows
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # The height of a line of text and of a list's row, the game's line height.
    LINE_HEIGHT = 24

    # The height of a line in the small font.
    SMALL_LINE_HEIGHT = 20

    # The height of a line in the tiny font.
    TINY_LINE_HEIGHT = 16

    # Finds the pixels of a font size.
    #
    # @param size [Symbol, Integer, nil] :tiny, :small, :normal, :large, :game (the game's own, which
    #   its windows draw their texts in) or pixels; nil for :normal.
    # @return [Integer] The pixels.
    def self.font_px(size)
      return size if size.is_a?(Integer)
      return game_font_px if size == :game

      Engine::Canvas::SIZES[size] || Engine::Style::TEXT_SIZE
    end

    # Tells the pixels of the game's own font size, which its windows draw their texts in.
    #
    # @return [Integer] The pixels.
    def self.game_font_px
      defined?(::Font) && ::Font.respond_to?(:default_size) ? ::Font.default_size.to_i : Engine::Style::TEXT_SIZE
    end

    # Finds the height of a line of text in a font size: the tiny and the small font's own, the
    # game's line height for the others.
    #
    # @param size [Symbol, Integer, nil] The font size, see font_px.
    # @return [Integer] The pixels.
    def self.line_height_of(size)
      { :tiny => TINY_LINE_HEIGHT, :small => SMALL_LINE_HEIGHT }[size] || LINE_HEIGHT
    end

    # Hands out a small picture set to the font a text of a size draws in, for measuring.
    #
    # @param size [Integer] The font's size in pixels.
    # @return [Bitmap] The picture.
    def self.font_bitmap(size)
      @font_bitmaps ||= {}
      bitmap = @font_bitmaps[size]
      bitmap = @font_bitmaps[size] = Bitmap.new(1, 1) if bitmap.nil? || bitmap.disposed?
      Engine::Style.use_font(bitmap, size, Engine::Style::TEXT)
      bitmap
    end

    # Cuts one cell out of a sheet in Graphics/System, such as a balloon of Balloon, kept once made.
    #
    # @param file [String] The sheet's name.
    # @param column [Integer] The cell's column, from 0.
    # @param row [Integer] Its row, from 0.
    # @param size [Integer] The side of a cell in pixels.
    # @return [Bitmap] The cell's picture.
    def self.sheet_cell(file, column, row, size)
      @sheet_cells ||= {}
      key = [file.to_s, column.to_i, row.to_i, size.to_i]
      cell = @sheet_cells[key]
      return cell if cell && !cell.disposed?

      cell = Bitmap.new(key[3], key[3])
      cell.blt(0, 0, Cache.system(key[0]), Rect.new(key[1] * key[3], key[2] * key[3], key[3], key[3]))
      @sheet_cells[key] = cell
    end

    # Finds a character of the game: an actor itself, or the actor of an id.
    #
    # @param value [Game_Actor, Integer, nil] The actor or its id.
    # @return [Game_Actor, nil] The actor, nil for none.
    def self.actor(value)
      value.is_a?(Integer) ? ($game_actors && $game_actors[value]) : value
    end

    # Reads a :scale option.
    #
    # @param value [Numeric, nil] The factor.
    # @return [Float] The factor; 1 for none and for one that is not above 0.
    def self.scale(value)
      value.is_a?(Numeric) && value > 0 ? value.to_f : 1.0
    end

    # Writes a count with its word, in the plural for any count but one, and a verb after it that
    # agrees with the count.
    #
    # @param count [Integer] The count.
    # @param word [String] The word, such as "gem".
    # @param words [String, nil] Its plural, the word with an "s" when not given.
    # @param verb [String, nil] A verb for one, such as "stays"; nil for none.
    # @param verbs [String, nil] The verb for more, such as "stay".
    # @return [String] Such as "1 gem", "3 gems" or "3 gems stay".
    def self.counted(count, word, words = nil, verb = nil, verbs = nil)
      text = "#{count} #{count == 1 ? word : words || "#{word}s"}"
      verb ? "#{text} #{count == 1 ? verb : verbs}" : text
    end

    # Writes a size in bytes as the player reads it: whole kilobytes, rounded up, below a megabyte,
    # else megabytes with one decimal.
    #
    # @param bytes [Integer] The size.
    # @return [String] Such as "34 KB" or "1.2 MB".
    def self.bytes_text(bytes)
      bytes = bytes.to_i
      bytes >= 1024 * 1024 ? format("%.1f MB", bytes / 1048576.0) : "#{[(bytes + 1023) / 1024, 1].max} KB"
    end

    # Writes names as a list, the last two joined by "and", and a verb after them that agrees with
    # how many they are.
    #
    # @param names [Array<String>] The names.
    # @param verb [String, nil] A verb for one name, such as "goes"; nil for none.
    # @param verbs [String, nil] The verb for more, such as "go".
    # @return [String] Such as "Ruby", "Ruby and Onyx" or "Ruby, Onyx and Pearl go".
    def self.listed(names, verb = nil, verbs = nil)
      names = Array(names).map { |name| name.to_s }
      text = names.size > 1 ? "#{names[0..-2].join(', ')} and #{names.last}" : names.first.to_s
      verb ? "#{text} #{names.size == 1 ? verb : verbs}" : text
    end

    # The folder of the framework's own pictures, inside the framework's folder.
    GRAPHICS = "Graphics"

    # Names a picture the framework ships, such as "thumb_up", for UI.picture and a row's parts.
    #
    # @param name [String] The picture's name without ".png".
    # @return [String] Its file, relative to the game folder.
    def self.graphic(name)
      "#{Mod_Framework::FOLDER}/#{GRAPHICS}/#{name}.png"
    end

    # Plays the game's buzzer, as for a choice the game refuses, and logs why when told.
    #
    # @param why [String, nil] What was refused and why, such as "socket 2 of Zantetsuken (Weapon 12):
    #   the slot is fixed"; nil logs nothing.
    # @return [nil] Nothing, so a refusal can return it.
    def self.buzz(why = nil)
      Sound.play_buzzer
      Mod_Framework.log("UI: refused #{why}") if why
      nil
    end

    # Plays the game's confirm sound.
    #
    # @return [nil] Nothing.
    def self.confirm_sound
      Sound.play_ok
      nil
    end

    module Engine
      # What every component that shows a text shares: C# measures the text from the widths of its
      # characters in the font it draws in, and a text in a font whose widths do not add up (Glyphs) is
      # measured here instead, a wrapped one for the width C# gave it last, so it settles a frame later.
      module TextSized
        # The properties of C#'s tree a change of the text, its size or its mark sets.
        PROPS = ["text", "font", "wrap", "escapes", "row_height", "measured", "padding"]

        # Tells the properties C#'s tree lays it out by, its text's added.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          text = measured_text
          key = text_font(text)
          props.update("text" => key ? text : nil, "font" => key, "wrap" => wraps?, "escapes" => escapes?, "row_height" => line_height)
          props["measured"] = nil unless props.key?("measured")
          props
        end

        # Tells its size when its text is measured here, nil while C# measures it.
        #
        # @return [Array<Integer>, nil] The text's width and height.
        def measure
          text = measured_text
          text_font(text) ? nil : measured_here(text)
        end

        # Takes the place C# gave it; a wrapped text measured here is measured again for a new width.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          width = @rect && @rect.width
          super
          relayout if wraps? && width != @rect.width && text_font(measured_text).nil?
        end

        private

        # Tells the text as C# measures it.
        #
        # @return [String] The text.
        def measured_text
          @options[:text].to_s
        end

        # Tells the pixels of the font the text draws in.
        #
        # @return [Integer] The pixels.
        def text_px
          Style::TEXT_SIZE
        end

        # Tells whether the text breaks into lines that fit its width.
        #
        # @return [Boolean] Whether it does.
        def wraps?
          false
        end

        # Tells whether the text carries the game's escape codes.
        #
        # @return [Boolean] Whether it does.
        def escapes?
          false
        end

        # Tells the height of one of the text's lines.
        #
        # @return [Integer] The pixels.
        def line_height
          LINE_HEIGHT
        end

        # Finds the key of the font C# measures the text in.
        #
        # @param text [String] The text.
        # @return [Integer, nil] The key; nil when the text is measured here.
        def text_font(text)
          return nil unless Glyphs.utf8?(text)

          bitmap = UI.font_bitmap(text_px)
          escapes? ? Glyphs.font_key(bitmap) : Glyphs.key_of(bitmap)
        end

        # Measures the text here: its width on one line, and as many lines as it breaks into when it
        # wraps, for the width inside the place C# gave it last.
        #
        # @param text [String] The text.
        # @return [Array<Integer>] Its width and height.
        def measured_here(text)
          bitmap = UI.font_bitmap(text_px)
          plain = escapes? ? text.gsub(Escapes::CODE, "") : text
          width = UI.text_width(bitmap, plain)
          return [width, line_height] unless wraps?

          _top, right, _bottom, left = padding_sides
          room = @rect ? [@rect.width - left - right, 1].max : width
          [width, UI.wrap_measured(bitmap, plain, room).size * line_height]
        end
      end

      # What every component shares whose look stays the same while hovered, pressed or focused: a
      # change of those states draws nothing anew, so the pointer crossing texts redraws no window.
      module StateBlind
        # Takes its state from C# without drawing anew.
        #
        # @param bits [Integer] The bits of hover, press and focus.
        def state=(bits)
          @state = bits
        end
      end
    end
  end
end
