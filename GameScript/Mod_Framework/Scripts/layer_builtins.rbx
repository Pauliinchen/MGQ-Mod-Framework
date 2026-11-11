#----------------------------------------------------------------
#  layer_builtins.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Gave an alert its close mark by on_close: alone, without closeable:
#                            - Counted a list's lines of cards by most_rows: or rows_shown:, without lines_shown:
#      Paulinchen  2026-11-10: Told a list's on_refuse the item and the step of a dim arrow Left or Right pressed
#      Paulinchen  2026-11-09: Gave an image scale: :auto, which scales it to its room at any factor keeping its proportions, and sampling:
#                            - Passed padding_shrinks: on to every part
#                            - Gave a text fit:, which cuts a line too wide, squeezes it into its width or narrows it
#                            - Gave a hud column:, the named column of UI.column it stacks in
#                            - Gave a list filter:, which keeps some items, and no_match:, the row once it keeps none
#                            - Gave a chip icons:, several icons side by side
#                            - Gave a text line_height:, the height of each of its lines
#                            - Gave a hud enter: :move, leave: and motion_frames:, and let a root's at: be live
#                            - Gave a list label_width: and let its note_at: take texts, of which the widest sets the column
#                            - Gave a list leave_ends:, which moves the focus on past its first and last rows instead of wrapping
#                            - Passed margin:, padding:, border:, border_width: and background: on to every part, the room in pixels
#                            - Told that a text field in a field titles its letter pages by the field's caption
#      Paulinchen  2026-11-08: Let a list's cell take an avatar before its text, the rows as high as the highest one
#                            - Added the looks a row of a game list window takes from UI.patch
#                            - Told that a text field shows its placeholder while the player types too
#                            - Told that key_help names only the keys of the part in focus and of the parts it lies in
#      Paulinchen  2026-11-07: Passed contrast: on to every part, the text on a fill by contrast
#                            - Made chip_set and chip only show, without bind:, multi:, read_only:, number_keys:, the
#                              checks of a form, on_change, on_close, value:, closeable: and disabled:
#                            - Gave an options list help:, its caller's text while its rows lack the focus, and had
#                              hotkeys: :remembered add the remembered hotkeys of the mods that are on to its rows
#                            - Passed outline: on to every part, the outline of its texts
#                            - Gave text and list highlight:, a text drawn on the picked color wherever it occurs
#                            - Gave a button size:, small, medium or large
#                            - Added badge, a count, a text or a dot over the corner of the parts it holds
#                            - Added measures, the part of a part and its copies that the markup makes for compact_for:
#                            - Added opacity: to icon, such as for a star that is off
#                            - Added forms, the part of a part's compact forms that the markup makes for compact:
#                            - Let a chip's color: fill it and gave the chip a variant:
#                            - Gave an options list the rows blocks of UI.patch
#                            - Removed the enabled: of a command, which disabled: replaces
#                            - Told a text field refuses typing only when its text box does not open
#      Paulinchen  2026-11-06: Removed digit_field, which a numeric field replaces
#                            - Removed the params no mod gave: answers_under:, hidden_in:, follow_gap:, a paper's backdrop:, a list's picture_at:, a command's remember: and the old side names
#                            - Let a hud slide in from its zone's edge with enter: :slide
#                            - Added icon, an icon on its own in one of three sizes or in pixels
#                            - Let the framework's own menus close and move with the part they opened from
#                            - Let a text take ever shorter texts, of which the first that fits its line shows
#                            - Told a part's on_focus and on_blur as the focus moves onto it and leaves it
#                            - Told a list's on_refuse the item of a greyed row the player tried to pick
#                            - Let the framework's own menus have a list's cursor follow the pointer
#                            - Gave a window layer: and mouse:, and let them and its frame: change while it shows
#                            - Gave a list cells:, the columns its rows' cells stand in, under heading rows across the row
#                            - Gave a paper clickable:, one part that confirm or a click presses, telling on_click
#                            - Typed a digit field as a numeric field types once a digit starts it, without the calculator start
#                            - Gave a list click_picks:, which picks any row a click lands on at once
#                            - Gave slides enter:, which moves the focus onto the page their bound state slides to
#                            - Gave a text field leave_sides:, which hands the focus to the part beside it at either end of its
#                              text, and on_cancel, the cancel that stopped its typing
#                            - Showed an options list of one mod as Options > Mods groups its rows, gave it headings:,
#                              on_press for its button rows, and on_enter and on_leave as the focus comes onto its rows
#                              and leaves them
#                            - Gave a list submit_to:, the part of its window a pick moves the focus to
#                            - Told a paper the keys stop on when the focus comes onto it and leaves it, and walked cancel on
#                              it back to the part the focus came from
#                            - Put the keys a key help adds before its entry of cancel when that entry ends it
#                            - Gave a list row a badge, a count or a dot at its end
#                            - Kept theme: :game as the look of the game's own windows and marked a text without typo: as body text
#                            - Marked a window with join: as joined, which takes the keys only from its game window
#      Paulinchen  2026-11-05: Gave an alert most_lines:, its text wrapped into lines up to that many
#                            - Gave a hud layer: :notices, which lies above every window and dialog and gives room first in a full zone
#                            - Gave a window and a dialog cover: a game window, which they lie exactly over and hide while open
#                            - Gave an options_list hotkeys: :remembered, the hotkeys of every mod that is on, and
#                              help_window:, a game window that shows the help
#                            - Gave a window frame:, which false leaves out with its background, such as a screen of framed boxes
#                            - Gave a paper scroll: :vertical and focusable:, a box of text the player scrolls, and on_scroll, the lines in sight
#                            - Gave an alert text_color:, which keeps its text in a color of its own beside the bar of its severity
#                            - Gave a button badge:, a count or a dot at its end, in badge_color:
#                            - Let a list's columns: change while it shows, its cursor staying on its item in sight
#                            - Gave a list rows with a picture at their left and lines under their name, and rows_shown:, rows that
#                              share its height
#                            - Gave a card's picture a badge, its name line a right text, and each of its lines a right text of icons and counts
#                            - Gave a list's rows an on/off box at their start, and a note in a column of its own
#                            - Took a game text color by its number in every color param, and a stack's spacing also in half units
#                            - Gave a paper backdrop:, a picture under what it holds
#                            - Titled the game's letters of a text field by its label:
#                            - Added required: and validate: to every input, whose error shows under it, and on_click:
#                              :submit, which sends the form a button lies in
#                            - Gave a window and a dialog captures: :typing, which holds the game's buttons only while a field inside types
#                            - Let a text field's steer: name a log
#                            - Let a bar of tabs alone with enter: hand the focus to the part under it
#                            - Added digit_field, a number the player sets digit by digit as in the game's number window
#                            - Added help_line, a line that tells what the part under the pointer or the focus does, with say
#                            - Gave a window and a dialog menu:, a menu scene of their own over the blurred map
#                            - Gave a list rows with a value that Left and Right step, told by on_side, and describe:, a game
#                              item's description as its row's tooltip
#                            - Gave a stack tail:, a column that keeps its newest parts
#                            - Gave a hud hide_while:, mouse: and fade:, and follow: with side:, follow_gap:, flip: and on_screen:
#                            - Added tabs_subheader, the parts under the row of tabs and over every page
#                            - Let a dialog cover the window that opened it, hiding it until it closes
#                            - Let a window take the screen's whole width
#                            - Set the room between the columns of a list by spacing:
#                            - Gave a select open_menu and close_menu, calls of its handle, lined its menu up with the list its steer: names, closed it
#                              by its button: and told its menu opening and closing
#                            - Gave slides enter_from, a call of their handle
#                            - Told a paper the keys enter its on_enter and on_leave as the focus goes inside and comes out
#                            - Added a window's join:, one cursor with the game window it lies beside, whose cancel it follows
#                            - Added alert, a notice across its parent in the color of its severity with its buttons and a
#                              close mark
#                            - Added drawer and drawer_header, a panel at the side of what it lies in that opens and closes,
#                              beside the rest, as a narrow strip while shut, or over the rest
#                            - Added options_list, the options rows of the mods as Options > Mods shows them
#                            - Added hotkey_field, a field the player presses to bind a hotkey to the next key
#                            - Showed a list's rows as cards in columns with look: :cards, each with a picture and lines
#                            - Gave a list's rows toggles, heading rows and groups, and let its rows move within their group by a
#                              drag, and on the framework's own mod list by its Move Up and Move Down hotkeys
#                            - Offered a text field's completions: for the last word typed, from an Array or a lambda of the word
#      Paulinchen  2026-11-04: Added text_field, chip_set with chip and select with select_item, each bound to a state and under
#                              its label:, and sent a list's pick a field steers up to the nearest on_submit
#                            - Kept a chip set to most: chips, read only, with closeable chips in a color of their own that
#                              Remove in its context menu closes too
#                            - Let a window take the screen's whole height and a button draw an icon
#                            - Gave a list row Hashes, a row: per item, an icon: and a right: per item and the game's text codes
#                            - Added tooltip, markup shown for the part it wraps on its side:, and the slot a content param of a
#                              built-in fills
#                            - Added to text align:, plate:, escapes:, on_click and most_lines: :fill
#                            - Added divider, a line across a column or upright in a row, in a color and thickness
#                            - Added image, a picture file or a character's art, face or figure scaled to its room
#                            - Added tabs, tab and tabs_header, the picked tab bound to a state by its id, in rows with wrap:
#                            - Added slides and slide, pages side by side bound to a state, a page refusing to slide into view
#                            - Added command, a command of a game command window that a UI.patch adds, and the params a
#                              UI.patch sets on a game window
#                            - Drew a button by its variant: in the theme, and handed the color names, the typography, the
#                              spacing and a dense row through the theme of the part
#                            - Added a button's text_color:, which wins over the theme's
#                            - Handed a part's theme: to the engine
#                            - Placed a window, a dialog and a hud by anchor:, dock:, at:, beside: and side:, a hud in the
#                              nine zones by order:, and each root in the band of its layer by z:
#                            - Added shown_in: to every root and kept a hud open across scene changes
#                            - Let a hud resize with Alt
#                            - Added popover, a framed box beside a part or the pointer, lined up with its start
#                            - Kept the keys out of a hud, also after a click on its buttons
#                            - Named in a button's hotkey param that a screen using the game's button of its key wins
#                            - Sent the pick of a list without on_submit up to the nearest window, dialog, paper or stack
#                              with one
#                            - Told the engine whether a part has a context menu and opened it where C# tells
#                            - Added on_button and button_help to windows, dialogs, papers, stacks and lists
#                            - Added on_page to windows, dialogs, papers, stacks and lists, a window's hotkey that closes it,
#                              a window's shoulders that keep a gamepad's shoulders for its tabs, a button's hotkey and
#                              show_key, answers_under, and key_help, which adds the hotkeys of the parts in view by
#                              itself
#                            - Let a window's and a dialog's on_cancel keep them open by answering false
#                            - Added paper, a framed box that the keys may enter as a whole
#                            - Told the engine whether a button or a list has an action or a bind and whether a button
#                              repeats a key, and added aside, whose parts only the pointer uses
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The new UI layer's built-in components: what each one declares and how each one becomes a
      # part of the engine. The engine's classes are read only when a part is made, so this file
      # loads without the game too.
      module Builtins
        # The engine's font size each typo stands for where the theme gives none, as without the DLL.
        TYPO_SIZE = { :h6 => :TITLE_SIZE, :subtitle1 => :TEXT_SIZE, :subtitle2 => :SMALL_SIZE, :body1 => :TEXT_SIZE, :body2 => :SMALL_SIZE,
                      :caption => :TINY_SIZE, :overline => :TINY_SIZE }

        # The handlers that make a button repeat a key the player has anyway, so the keys skip it.
        REPEATED_KEYS = [:close, :back, :forward]

        # The params that give a list an action or a bind.
        LIST_ACTIONS = [:bind, :bind_index, :on_submit, :on_change, :on_toggle, :on_side]

        # The nine zones of the screen a root sits in, row by row from the top left.
        ZONES = [:top_left, :top, :top_right, :left, :center, :right, :bottom_left, :bottom, :bottom_right]

        # The edges of the screen a root docks along.
        EDGES = [:left, :right, :top, :bottom]

        # The sides of a part a root lies on.
        SIDES = [:top, :bottom, :left, :right]


        # The params every root takes.
        ROOT = {
          :at => { :kind => :live, :type => :point,
                   :doc => "an exact spot [x, y] on the screen instead of its zone, rarely needed; a lambda is read every frame, and it jumps to a new spot the frame the answer changes" },
          :movable => { :type => :bool, :default => true, :doc => "false keeps the player from moving it with Alt" },
          :shown_in => { :type => :scenes, :doc => "the only scenes it shows in; elsewhere it fades out without closing and keeps its place" },
          :place_name => { :type => :text, :doc => "the name the player sees for its stored place" },
          :if => { :type => :gate, :doc => "asked every frame; anything but true closes it, the answer its reason" },
          :z => { :type => :int, :doc => "which root lies above which within the band of its layer, 0 by default" },
          :opened_from => { :hidden => true,
                            :doc => "the engine part it opened from, which it closes and moves with as a popup; only the framework's own menus give it" }
        }

        # The params of a window and a dialog that place them besides ROOT's.
        WINDOW_PLACE = {
          :anchor => { :values => ZONES, :default => :center, :doc => "the zone of the screen it sits in; a dialog without one sits over the window that opened it" },
          :dock => { :values => EDGES, :doc => "the edge of the screen it takes the whole length of, such as a full-height side window" },
          :beside => { :type => :selector, :doc => "the part it sits next to: a game window's class name, or another window's #id" },
          :side => { :values => SIDES, :default => :right, :doc => "the side of beside: it sits on; the other side where that has no room" }
        }

        # The event of a part that takes the window's page step.
        PAGE_EVENT = { :page => "Q or W, or a gamepad's shoulder without tabs in view, reached it from the focus upward: -1 for the page before, 1 for the next" }

        # The params of a part that takes the game's extra buttons.
        BUTTONS = {
          :on_button => { :type => :buttons,
                          :doc => "what the game's buttons :a, :x, :y and :z (Shift, A, S and D on the keyboard) do while the focus is on it or inside it, such as { z: -> { open_filter } }; only where a screen mirrors the game's own" },
          :button_help => { :type => :button_texts, :doc => "what each button of on_button: does, which the key help names, such as { z: \"Filter\" }; nil leaves a button out, such as on a row it does nothing on" }
        }

        # The params of a window and a dialog besides ROOT.
        WINDOW = {
          :width => { :type => :size, :values => [:fill, :content, :screen], :default => :content, :doc => "pixels; :screen for the screen's whole width" },
          :height => { :type => :size, :values => [:fill, :content, :screen], :default => :content, :doc => "pixels; :screen for the screen's whole height" },
          :hotkey => { :type => :hotkey, :doc => "a hotkey of Mod_Framework::Hotkeys that closes it again, with the reason :hotkey; by default the hotkey its component class declares with hotkey :name, which opens it too" },
          :shoulders => { :values => [:tabs_or_page, :tabs], :default => :tabs_or_page,
                          :doc => "what a gamepad's shoulders do: :tabs_or_page steps the tabs in view, else on_page, else the focused list's page; :tabs only steps the tabs" },
          :title => { :kind => :live, :type => :text, :doc => "the title bar's text" },
          :closable => { :type => :bool, :default => true, :doc => "the game's cancel key and Numpad 0 close it" },
          :resizable => { :values => [false, true, :width, :height], :default => false, :doc => "the player resizes it with Alt" },
          :close_outside => { :type => :bool, :default => false, :doc => "a click outside closes it" },
          :captures => { :values => [true, false, :typing], :default => true,
                         :doc => "it holds the game's buttons while open; :typing only while a text field inside it types, such as a chat whose log stays on the screen while the player walks" },
          :menu => { :type => :bool, :default => false,
                     :doc => "opened outside the game's menu, it opens in a menu scene of its own over the blurred map, which waits behind it, and the game goes back as it closes; opened in a menu it opens in place" }
        }

        # The param of a window or a dialog that stands in for another window, which it hides.
        COVER = {
          :cover => { :type => :cover, :default => false,
                      :doc => "true: it lies over the window that opened it at that window's place, such as a dialog as large as the window it stands in for; " \
                              "a game window or its class name, such as \"Window_Config\": it lies exactly over that game window, its place and size, such as " \
                              "Options > Mods over the game's options list; either window hides until it closes" }
        }

        # The param of a window that leaves out its frame.
        FRAME = {
          :frame => { :type => :bool, :default => true,
                      :doc => "false draws neither its frame nor its background and keeps no room for them, so only the papers it holds show, such as the mod browser over the whole screen; " \
                              "it may change while the window shows, such as a chat framed only while it types" }
        }

        # The params of a window that may rest under the game's windows while it holds no keys.
        WINDOW_LAYER = {
          :layer => { :values => [:windows, :over, :hud], :default => :windows,
                      :doc => ":windows lies with the framework's windows above the game's; :over above the game's windows but under the framework's windows and dialogs; " \
                              ":hud with the HUD parts under the game's windows, such as the message box, and without its frame; it may change while the window shows, such as a chat " \
                              "that rests under the message box while closed and rises above everything while it types" },
          :mouse => { :values => [:all, :parts, :none], :default => :all,
                      :doc => ":all takes the pointer on all of it, :parts only on its parts that take clicks or show a tooltip and lets it through elsewhere, :none nowhere, " \
                              "such as a chat's log of recent lines while it is closed; it may change while the window shows" }
        }

        # The param of a window beside a game window that gives the two one cursor.
        JOIN = {
          :join => { :type => :bool, :default => false,
                     :doc => "with beside: a game window such as \"Window_TitleCommand\", the two share one cursor: the arrow toward it or the pointer moving onto it hands it the keys, which it never takes as it opens, " \
                             "the arrow back or the pointer moving onto the game window hands them back, cancel does what it does in the game window, and L, R, Page Up and Page Down do nothing; " \
                             "a window or a dialog its handler opens hides both until it closes, and it then takes the keys back on the row that opened it" }
        }

        # The events of a root.
        ROOT_EVENTS = { :open => "once it shows", :close => "why it closed: :cancel, :button, :hotkey, :script, :scene, :outside or the gate's answer" }

        # The event of a part that takes the pick of a list inside it without on_submit.
        SUBMIT_EVENT = { :submit => "a list inside it without on_submit: picked an item, nearest first: the item" }

        # The events of a window and a dialog.
        WINDOW_EVENTS = ROOT_EVENTS.merge(PAGE_EVENT).merge(SUBMIT_EVENT).merge(:cancel => "cancel reached it, or a click outside with close_outside:; answering false keeps it open without the cancel sound, such as to ask first or to buzz while something runs")

        # Tells the engine's color of a color param: a color name stays a name, which the part finds
        # in the palette of its theme as it draws, and a game text color stays its number.
        #
        # @param value [Symbol, Integer, String, Array, nil] A color name, a game text color, "#RRGGBB"
        #   or [r, g, b(, a)].
        # @return [Symbol, Integer, Color, nil] The name, the number or the color, nil for the default.
        def self.color(value)
          case value
          when nil, :default then nil
          when Symbol, Integer then value
          when String then Color.new(value[1, 2].to_i(16), value[3, 2].to_i(16), value[5, 2].to_i(16))
          else Color.new(*value)
          end
        end

        # Tells a font size of a typography name in the player's preset.
        #
        # @param typo [Symbol] The name, such as :h6.
        # @return [Integer] The pixels.
        def self.typo_size(typo)
          Theme.typo_size(typo) || Style.const_get(TYPO_SIZE[typo])
        end

        # Tells the pixels of units of spacing in the player's preset.
        #
        # @param units [Numeric] The units, also half ones.
        # @return [Integer] The pixels.
        def self.spacing(units)
          (units * Theme.spacing).round
        end

        # Turns room in units of spacing into the pixels of each side.
        #
        # @param value [Numeric, Array<Numeric>] The units for every side, [vertical, horizontal] or
        #   [top, right, bottom, left].
        # @return [Array<Integer>] Top, right, bottom and left in pixels.
        def self.sides(value)
          units = value.is_a?(Array) ? value : [value]
          units = units.size == 2 ? [units[0], units[1], units[0], units[1]] : (units.size == 4 ? units : units * 4)
          units.map { |each| spacing(each) }
        end

        # Turns a border: or a background:'s color into the engine's: false, :theme and :shade stay.
        #
        # @param value [Object] The value.
        # @return [Object] The engine's value.
        def self.look_color(value)
          value == false || value == :theme || value == :shade ? value : color(value)
        end

        # Turns the params every part takes into the engine's options.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.common(params)
          options = { :visible => params[:visible] != false, :enabled => params[:disabled] != true }
          options[:id] = params[:id] if params[:id]
          options[:tooltip] = params[:tooltip].to_s if params[:tooltip]
          options[:help] = params[:help].to_s if params[:help]
          [:width, :height].each do |side|
            value = params[side]
            options[side] = value if value.is_a?(Integer)
            options[:grow] = 1 if value == :fill
          end
          options[:grow] = params[:grow] if params[:grow]
          options[:min_size] = params[:min_size] if params[:min_size]
          options[:max_size] = params[:max_size] if params[:max_size]
          options[:align] = params[:align_self] if params[:align_self]
          options[:autofocus] = true if params[:autofocus]
          options[:context_menu] = !params[:context_menu].nil?
          options[:theme] = params[:theme]
          options[:outline] = color(params[:outline])
          options[:contrast] = params[:contrast]
          options[:margin] = sides(params[:margin]) unless params[:margin].nil?
          options[:padding] = sides(params[:padding]) unless params[:padding].nil?
          options[:padding_shrinks] = true if params[:padding_shrinks]
          options[:border] = look_color(params[:border]) unless params[:border].nil?
          options[:border_width] = params[:border_width] unless params[:border_width].nil?
          background = params[:background]
          unless background.nil?
            options[:background] = background.is_a?(Hash) ? { :color => look_color(background[:color]), :fade => background[:fade] } : look_color(background)
          end
          options
        end

        # Tells whether a part takes the window's page step and the pick of a list: it has on_page and
        # on_submit.
        #
        # @param params [Hash] The params.
        # @return [Hash] The option.
        def self.pages(params)
          { :page_step => !params[:on_page].nil?, :submits => !params[:on_submit].nil? }
        end

        # Tells the game's extra buttons a part takes: those its on_button: gives a handler.
        #
        # @param params [Hash] The params.
        # @return [Hash] The option.
        def self.buttons(params)
          taken = (params[:on_button] || {}).reject { |_button, handler| handler.nil? }.keys
          { :extra_buttons => taken.map { |button| button.to_s.upcase } }
        end

        # Turns a root's params into the engine's options.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.root(params)
          options = common(params).merge(pages(params)).merge(:movable => params[:movable] != false, :layer => true)
          options[:shown_in] = params[:shown_in] if params[:shown_in]
          options[:place_name] = params[:place_name].to_s if params[:place_name]
          options[:if] = params[:if] if params[:if]
          options[:opened_from] = params[:opened_from] if params[:opened_from]
          options
        end

        # Turns a window's or a dialog's params into the engine's options.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.window(params)
          options = root(params).merge(buttons(params))
          options.merge!(:title => params[:title].nil? ? nil : params[:title].to_s, :closable => params[:closable] != false,
                         :resizable => params[:resizable] || false, :close_outside => params[:close_outside] == true,
                         :captures => params[:captures] == :typing ? :typing : params[:captures] != false, :declared_hotkey => params[:hotkey] || false,
                         :shoulders => params[:shoulders] == :tabs ? :tabs : false, :menu => params[:menu] == true, :frame => params[:frame] != false && params[:layer] != :hud,
                         :under_windows => params[:layer] == :hud, :mouse => HUD_MOUSE[params[:mouse] || :all])
          options[:width] = Graphics.width if params[:width] == :screen
          options[:height] = Graphics.height if params[:height] == :screen
          options.update(:captures => false, :joined => true) if params[:join]
          options
        end

        # Tells the scenes a HUD hides in: the title and the game over.
        #
        # @return [Array] The scenes.
        def self.hud_scenes
          [:Scene_Title, :Scene_Gameover].select { |name| Object.const_defined?(name) }.map { |name| Object.const_get(name) }
        end

        # Tells the text of a list's item.
        #
        # @param text [Proc, Symbol, nil] The list's text: param.
        # @param item [Object] The item.
        # @return [String] The text.
        def self.item_text(text, item)
          value = case text
                  when Proc then text.call(item)
                  when Symbol then item.__send__(text)
                  else item
                  end
          value.to_s
        end

        # Tells a list's row of an item: its row: answer, the item itself when it is a row, else its
        # text, with an icon and a right text where the list gives them.
        #
        # @param params [Hash] The list's params.
        # @param item [Object] The item.
        # @return [String, Hash] The row.
        def self.list_row(params, item)
          return per_item(params[:row], item) if params[:row]
          return item if item.is_a?(Hash) && (params[:text].nil? || heading_row?(item))

          text = item_text(params[:text], item)
          return text if params[:icon].nil? && params[:right].nil?

          row = { :text => text }
          row[:icon] = per_item(params[:icon], item) if params[:icon]
          row[:right] = per_item(params[:right], item).to_s if params[:right]
          row
        end

        # The height of a card with a picture, which takes its card's width at 16:9 above the card's
        # texts: the mod browser's card in three columns.
        CARD_HEIGHT = 192

        # The height of a card without a picture: its name and two lines, the last of them two lines
        # long, within the card's room.
        TEXT_CARD_HEIGHT = 102

        # The lines a card's last line wraps to, such as a summary.
        CARD_WRAP = 2

        # Room between two cards.
        CARD_GAP = 8

        # The band across a blurred card picture, as the mod browser marks a spoiler.
        SPOILER_TEXT = "Spoiler"

        # Turns a card list's rows into cards: each row a Hash with its lines, so it draws as a card
        # on its dark plate, its last line wrapped to CARD_WRAP lines, a blurred picture marked
        # SPOILER_TEXT unless it has a label of its own.
        #
        # @param params [Hash] The list's params.
        # @param items [Array] The items, one for each row.
        # @param rows [Array<String, Hash>] The rows.
        # @return [Array<Hash>] The cards.
        def self.card_rows(params, items, rows)
          rows.each_with_index.map do |row, place|
            row = { :text => row.to_s } unless row.is_a?(Hash)
            next row if heading_row?(row)

            { :lines => [], :plate => true, :wrap_lines => CARD_WRAP }.merge(picture_look(params, items[place], row))
          end
        end

        # Turns the rows of a list of rows that show pictures or lines into rows with lines, so each
        # draws its picture at its left, its name and its lines beside it; the other rows stay.
        #
        # @param params [Hash] The list's params.
        # @param items [Array] The items, one for each row.
        # @param rows [Array<String, Hash>] The rows.
        # @return [Array<String, Hash>] The rows.
        def self.pictured_rows(params, items, rows)
          return rows unless params[:picture] || params[:lines] || rows.any? { |row| lined_row?(row) }

          rows.each_with_index.map do |row, place|
            next row if heading_row?(row)

            row = picture_look(params, items[place], row.is_a?(Hash) ? row : { :text => row.to_s })
            lined_row?(row) ? { :lines => [], :picture_at => :left }.merge(row) : row
          end
        end

        # Tells whether a row shows a picture or lines under its name.
        #
        # @param row [String, Hash] The row.
        # @return [Boolean] Whether it does.
        def self.lined_row?(row)
          row.is_a?(Hash) && (row[:picture].is_a?(Hash) || row[:lines].is_a?(Array))
        end

        # Gives a row an item's picture: and lines: and the list's picture_width:,
        # where the row has none of its own, a blurred picture marked SPOILER_TEXT unless it has a
        # label of its own.
        #
        # @param params [Hash] The list's params.
        # @param item [Object] The row's item.
        # @param row [Hash] The row.
        # @return [Hash] The row.
        def self.picture_look(params, item, row)
          row = row.merge(:picture => per_item(params[:picture], item)) if params[:picture]
          row = row.merge(:lines => Array(per_item(params[:lines], item))) if params[:lines]
          picture = row[:picture]
          return row unless picture.is_a?(Hash)

          row = row.merge(:picture => { :label => SPOILER_TEXT }.merge(picture)) if picture[:blur]
          row = row.merge(:picture_width => params[:picture_width]) if params[:picture_width] && !row.key?(:picture_width)
          row
        end

        # Tells the height of a list's cards: a share of its height: by its lines of cards, else a
        # card's height with a picture across its top or without.
        #
        # @param params [Hash] The list's params.
        # @param rows [Array<Hash>] The cards.
        # @return [Integer] The pixels.
        def self.card_height(params, rows)
          return params[:height] / card_lines(params) if params[:height].is_a?(Integer)

          rows.any? { |row| row[:picture] && row[:picture_at] != :left } ? CARD_HEIGHT : TEXT_CARD_HEIGHT
        end

        # Tells how many lines of cards a list shows before it scrolls: its rows_shown: count, else its
        # most_rows:, else 2.
        #
        # @param params [Hash] The list's params.
        # @return [Integer] The lines.
        def self.card_lines(params)
          params[:rows_shown].is_a?(Integer) ? params[:rows_shown] : params[:most_rows] || 2
        end

        # Tells the height of a list's rows with lines: as high as the highest row's picture at its
        # left, 16:9 of its width, or its name and lines, with the card's room around them.
        #
        # @param rows [Array<String, Hash>] The rows.
        # @return [Integer] The pixels.
        def self.lined_height(rows)
          rows.map do |row|
            next 0 unless lined_row?(row)

            picture = row[:picture].is_a?(Hash) ? (row[:picture_width] || List::PICTURE_BESIDE).to_i * 9 / 16 : 0
            [List::CARD_TEXT_ROW + List::CARD_NOTE_ROW * Array(row[:lines]).size, picture].max + 2 * List::CARD_INSET
          end.max
        end

        # Tells the height of a list's rows with avatars in their cells: the highest avatar's, with
        # the room a row keeps above and below it.
        #
        # @param rows [Array<String, Hash>] The engine's rows.
        # @return [Integer] The pixels, 0 without an avatar.
        def self.avatar_height(rows)
          rows.map do |row|
            cells = row.is_a?(Hash) ? Array(row[:cells]) : []
            cells.map { |cell| cell.is_a?(Hash) && cell[:avatar].is_a?(Hash) ? cell[:avatar][:height].to_i + 2 * List::AVATAR_ROOM : 0 }.max.to_i
          end.max.to_i
        end

        # Tells the items a list shows: those its filter: keeps, as a table's filter: keeps them, an
        # item a search cannot find (a row of search: false or a heading) always, and after them the
        # dim row of its no_match: once the filter left out every item it asked about.
        #
        # @param params [Hash] The list's params.
        # @return [Array] The items.
        def self.list_items(params)
          items = Array(params[:items])
          filter = params[:filter]
          return items unless filter

          found = false
          left_out = false
          kept = items.select do |item|
            next true if item.is_a?(Hash) && (item[:search] == false || !item[:heading].nil?)

            keep = per_item(filter, item) ? true : false
            keep ? found = true : left_out = true
            keep
          end
          return kept if found || !left_out || params[:no_match].nil?

          kept + [{ :text => params[:no_match].to_s, :color => :dim, :faint => true, :disabled => true, :search => false }]
        end

        # Turns a list's items into the engine's rows: a heading row's text becomes its heading, a
        # row's check: its box, an item's toggles: join its row, and with reorder: each row gets its
        # group, its own group: or else the heading above it, so a row moves only among the rows
        # under the same heading.
        #
        # @param params [Hash] The list's params.
        # @param items [Array] The items.
        # @return [Array<String, Hash>] The rows.
        def self.list_rows(params, items)
          section = 0
          items.map do |item|
            row = list_row(params, item)
            if heading_row?(row)
              section += 1
              next engine_heading(row)
            end

            row = { :text => row.to_s } if !row.is_a?(Hash) && (params[:toggles] || params[:reorder])
            row = engine_box(row) if row.is_a?(Hash) && row.key?(:check)
            row = row.merge(:cells => Array(row[:cells]).map { |cell| engine_cell(cell) }) if row.is_a?(Hash) && row.key?(:cells)
            row = row.merge(:toggles => per_item(params[:toggles], item)) if params[:toggles]
            if params[:reorder]
              group = params[:group] ? per_item(params[:group], item) : row[:group]
              row = row.merge(:group => group.nil? ? [:section, section] : group)
            end
            row
          end
        end

        # Turns a row's check: into the engine's box: true or false draws the box, nil none.
        #
        # @param row [Hash] The row.
        # @return [Hash] The engine's row.
        def self.engine_box(row)
          boxed = row.reject { |key, _value| key == :check }
          row[:check].nil? ? boxed : boxed.merge(:checked => row[:check] ? true : false)
        end

        # Turns a cell of a row's cells: into the engine's: a text stays, a Hash's avatar: becomes the
        # engine's avatar and its typo: its font size.
        #
        # @param cell [String, Hash] The cell: a text, or { text:, color:, typo:, align:, icons:, avatar: }.
        # @return [String, Hash] The engine's cell.
        def self.engine_cell(cell)
          return cell.to_s unless cell.is_a?(Hash)

          cell = cell.merge(:avatar => cell_avatar(cell[:avatar])) if cell[:avatar].is_a?(Hash)
          return cell unless cell[:typo]

          cell.reject { |key, _value| key == :typo }.merge(:font_size => typo_size(cell[:typo]))
        end

        # Tells whether a row is a heading.
        #
        # @param row [String, Hash] The row.
        # @return [Boolean] Whether it is.
        def self.heading_row?(row)
          row.is_a?(Hash) && (row[:heading] == true || row[:heading].is_a?(String))
        end

        # Turns a heading row { text:, heading: true } into the engine's, whose heading holds its
        # text.
        #
        # @param row [Hash] The row.
        # @return [Hash] The engine's row.
        def self.engine_heading(row)
          return row unless row[:heading] == true

          row.reject { |key, _value| key == :heading || key == :text }.merge(:heading => row[:text].to_s)
        end

        # Answers a per-item param for an item: a lambda's answer, or the item's method the Symbol
        # names.
        #
        # @param given [Proc, Symbol] The param.
        # @param item [Object] The item.
        # @return [Object] The answer.
        def self.per_item(given, item)
          given.is_a?(Proc) ? given.call(item) : item.__send__(given)
        end

        # Wires a root's open and close to the layer.
        #
        # @param part [Object] The layer's part of the root.
        def self.wire_root(part)
          part.engine.on(:open) { Layer.dispatch(part, :on_open, []) }
          part.engine.on(:close) { |why| Layer.root_closed(part, why) }
          wire_page(part)
          wire_submit(part)
        end

        # Opens a part's context menu where C#'s tree tells it to, and tells its on_focus and on_blur as
        # the focus moves onto it and leaves it.
        #
        # @param part [Object] The layer's part.
        def self.wire_context(part)
          part.engine.on(:context) { |x, y| Layer.open_context(part, x, y) }
          part.engine.on(:focus) { Layer.dispatch(part, :on_focus, []) }
          part.engine.on(:blur) { Layer.dispatch(part, :on_blur, []) }
        end

        # Hands the window's page step C#'s tree tells a part to its on_page, and one of the game's
        # extra buttons to its on_button.
        #
        # @param part [Object] The layer's part.
        def self.wire_page(part)
          part.engine.on(:page) { |step, _pad| Layer.dispatch(part, :on_page, [step]) }
          part.engine.on(:button) { |name| Layer.press_button(part, name) }
        end

        # Hands the pick of a list inside a part that C#'s tree sends up to it to its on_submit.
        #
        # @param part [Object] The layer's part.
        def self.wire_submit(part)
          part.engine.on(:submit) { |row, list| Layer.submit_up(part, row, list) }
        end

        # Hands a click on a part that only the mouse presses to its on_click, when it has one as it
        # is made, so a part without one lets the pointer through in a hud.
        #
        # @param part [Object] The layer's part.
        def self.wire_click(part)
          part.engine.on(:click) { Layer.dispatch(part, :on_click, []) } if part.node.params[:on_click]
        end

        # Has cancel ask a window's on_cancel before it closes the window, while it has one, so the
        # engine closes a window without one at once; a joined window does what cancel does in its
        # game window instead and stays.
        #
        # @param part [Object] The layer's part of the window.
        def self.follow_cancel(part)
          wanted = !part.node.params[:on_cancel].nil? || part.node.params[:join] == true
          return if wanted == part.engine.listens?(:cancel)

          wanted ? part.engine.on(:cancel) { part.node.params[:join] ? Layer.join_cancel(part) : Layer.ask(part, :on_cancel) } : part.engine.off(:cancel)
        end

        Declarations.define(:window,
                            :summary => "A window that holds the game's buttons while it is open. UI.open opens a component whose top part is one.",
                            :args => [:title], :root => :open, :content => true, :params => ROOT.merge(WINDOW_PLACE).merge(WINDOW).merge(FRAME).merge(WINDOW_LAYER).merge(JOIN).merge(COVER).merge(BUTTONS),
                            :events => WINDOW_EVENTS,
                            :keys => "the game's cancel key and Numpad 0 step back: out of a paper the keys entered, then on_cancel is asked, then it closes; " \
                                     "Q and W reach the nearest on_page from the focus upward; Page Up and Page Down page the focused list; Tab steps the tabs " \
                                     "nearest the focus, or goes into its first text field and back; its hotkey: closes it; " \
                                     "Shift, A, S and D (the game's buttons :a, :x, :y and :z) reach the nearest on_button: from the focus upward",
                            :pad => "B as cancel; the shoulders step the tabs in view that show two or more, else reach on_page, else page the focused list",
                            :mouse => "as mouse: says; Alt-drag moves it; Alt double-click puts it back",
                            :make => lambda { |options| Window.new(options) }, :options => lambda { |params| window(params) },
                            :wire => lambda { |part| wire_root(part) }, :follow => lambda { |part| follow_cancel(part); Layer.follow_join(part) })

        Declarations.define(:dialog,
                            :summary => "A window over whatever opened it; the windows under it keep their look but take no input while it is open.",
                            :args => [:title], :root => :open, :content => true, :params => ROOT.merge(WINDOW_PLACE).merge(WINDOW).merge(BUTTONS).merge(COVER), :events => WINDOW_EVENTS,
                            :keys => "as window", :pad => "as window", :mouse => "as window",
                            :make => lambda { |options| Dialog.new(options) }, :options => lambda { |params| window(params) },
                            :wire => lambda { |part| wire_root(part) }, :follow => lambda { |part| follow_cancel(part) })

        # How a hud comes and goes, by the names enter: and leave: take.
        HUD_MOTIONS = [:fade, :slide, :move]

        # What a hud's mouse: names, as the engine's root takes it.
        HUD_MOUSE = { :parts => :parts, :all => true, :none => false }

        # The side of a character a root that follows it lies on, by the names a mod gives.
        FOLLOW_SIDES = { :top => :above, :bottom => :below, :middle => :middle }

        # The hiding of hide_while: :top_message, asked every frame.
        TOP_MESSAGE = lambda { Game.top_message? }

        # The hiding of hide_while: true.
        ALWAYS_HIDDEN = lambda { true }

        # The params of a hud that follows a map character.
        FOLLOW = {
          :follow => { :type => :character,
                       :doc => "the map character it lies beside, above the map's pictures and the screen's tone and flash; it hides while the character is gone, see-through or on another map, and shows over a CG; huds that follow one tile stack upward in the order they opened; with shown_in: naming a menu scene that draws the map on behind its windows, it shows on that map too; anchor:, dock: and at: give way, and it does not move with Alt" },
          :side => { :values => [:top, :bottom, :middle], :default => :top, :doc => "with follow:, over the character's head, under its feet or on it" },
          :flip => { :type => :bool, :default => false, :doc => "with follow:, it takes the other side where its own leaves the screen" },
          :on_screen => { :type => :bool, :default => false, :doc => "with follow:, it slides back onto the screen whole at the screen's edges" }
        }

        # Turns a hide_while: into the engine's hiding, asked every frame.
        #
        # @param value [Proc, Boolean, Symbol, nil] A lambda, true, false or :top_message.
        # @return [Proc, nil] The hiding, nil for none.
        def self.hiding(value)
          case value
          when :top_message then TOP_MESSAGE
          when true then ALWAYS_HIDDEN
          when Proc then value
          end
        end

        # Turns a hud's params into the engine's options: a box that never takes the keys, faded,
        # hidden by hide_while:, in the map's band while it follows one; one in the notices'
        # layer gives room first in a full zone.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.hud(params)
          layer = params[:layer] || :hud
          options = root(params).merge(:under_windows => layer == :hud, :resizable => params[:resizable] || false, :fade => params[:fade] != false,
                                       :mouse => HUD_MOUSE[params[:mouse] || :parts], :hide_while => hiding(params[:hide_while]), :gives_room => layer == :notices,
                                       :frame => params[:frame] != false, :enter_motion => params[:enter] || :fade, :leave_motion => params[:leave],
                                       :motion_frames => params[:motion_frames])
          options.merge!(:hidden_in => hud_scenes, :aside => true, :keep => true)
          return options if params[:follow].nil?

          options.merge(:follow => params[:follow], :side => FOLLOW_SIDES[params[:side] || :top],
                        :flip => params[:flip] == true, :on_screen => params[:on_screen] == true, :movable => false, :resizable => false)
        end

        Declarations.define(:hud,
                            :summary => "A box over the map or the battle that never takes the keys, or one that follows a map character. " \
                                        "UI.show shows a component whose top part is one.",
                            :root => :show, :content => true,
                            :params => ROOT.merge(:anchor => { :values => ZONES, :default => :top_left,
                                                               :doc => "the zone of the screen it stacks in with the other parts there, by order: and then the load order of their mods" },
                                                  :dock => { :values => EDGES, :doc => "the edge of the screen it takes the whole length of, such as a boss strip; the zones keep clear of it" },
                                                  :order => { :type => :int, :default => 0, :doc => "its place in its zone's stack, lower nearer the edge; notices are 100" },
                                                  :column => { :type => :id,
                                                               :doc => "the name of a column UI.column defined, which it joins as it shows: the column stacks its huds down from its spot, the newest on top, " \
                                                                       "and one that leaves keeps its place until its leave: ends; anchor:, dock: and at: give way, and it does not move with Alt; " \
                                                                       "a name no UI.column defined leaves it at its own place, logged" },
                                                  :layer => { :values => [:hud, :over, :notices], :default => :hud,
                                                              :doc => ":hud lies under the game's windows, :over above them, :notices above every window and dialog with the notices, such as a notice of your own; "                                                                       "in a zone too full for its parts, a hud in :notices shrinks to its min_size: first" },
                                                  :resizable => { :values => [false, true, :width, :height], :default => false, :doc => "the player resizes it with Alt" },
                                                  :hide_while => { :type => :while,
                                                                   :doc => "asked every frame: while it answers true it fades out without closing, keeps its place and frees its room in its zone; :top_message hides it while the game's message shows at the top of the screen" },
                                                  :mouse => { :values => HUD_MOUSE.keys, :default => :parts,
                                                              :doc => ":parts takes the pointer only on its parts that take clicks or show a tooltip and lets it through elsewhere, :all on all of it, :none nowhere, such as a line of info" },
                                                  :fade => { :type => :bool, :default => true, :doc => "it comes and goes by enter: and leave: as it shows and hides; false shows and hides it at once" },
                                                  :enter => { :values => HUD_MOTIONS, :default => :fade,
                                                              :doc => "how it comes as it shows: :fade fades it in; :slide also slides it in from beyond the screen's edge at its zone as it fades in, as a toast does: " \
                                                                      "the top left, left and bottom left from the left, the top from above, the bottom and the center from below, one at a spot from the edge nearest it; :move slides it so without fading" },
                                                  :leave => { :values => HUD_MOTIONS, :doc => "how it goes as it hides or closes, the way enter: comes reversed: out there by :slide or :move; enter:'s by default" },
                                                  :motion_frames => { :type => :frames, :default => 12,
                                                                      :doc => "the frames its coming and its going take, one number for both or [in, out], such as [15, 30]" },
                                                  :frame => { :type => :bool, :default => true,
                                                              :doc => "false draws neither its frame nor its background and keeps no room for them, so only what it holds shows, such as a notice that is all its alert" }).merge(FOLLOW),
                            :events => ROOT_EVENTS, :keys => "none: cancel, the arrows and confirm stay the game's, also after a click on its buttons",
                            :mouse => "as mouse: says: clicks on its buttons, while the pointer passes through the rest; Alt-drag moves it",
                            :make => lambda { |options| Box.new(options) },
                            :options => lambda { |params| hud(params) },
                            :wire => lambda { |part| wire_root(part) })

        Declarations.define(:popover,
                            :summary => "A framed box beside a part or the pointer, over the window it lies in, such as more about a slot.",
                            :content => true, :detached => true,
                            :params => { :target => { :type => :target, :required => true, :doc => "the part it sits next to, or :pointer for where the pointer is as it opens" },
                                         :side => { :values => SIDES, :default => :bottom, :doc => "the side of target: it sits on, lined up with its left edge or its top" },
                                         :open => { :type => :bool, :default => false, :doc => "it opens as this turns true and closes as it turns false" },
                                         :bind => { :kind => :bind, :doc => "a state that holds whether it is open, both ways, instead of open:" },
                                         :close_outside => { :type => :bool, :default => true, :doc => "a click outside closes it" },
                                         :flip => { :type => :bool, :default => true, :doc => "it takes the other side where its own has no room" },
                                         :z => { :type => :int, :doc => "which root lies above which within the dialogs' band, 0 by default" } },
                            :events => { :close => "why it closed: :cancel, :outside, :script or :scene" },
                            :keys => "it takes the keys while open; cancel closes it and the focus goes back to target:", :pad => "B closes it",
                            :mouse => "a click outside closes it",
                            :make => lambda { |options| Box.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:layer => true, :captures => true, :closable => true, :close_outside => params[:close_outside] != false,
                                                   :beside_side => params[:side] || :bottom, :beside_flip => params[:flip] != false, :movable => false)
                            end,
                            :wire => lambda { |part| part.engine.on(:close) { |why| Placement.popover_closed(part, why) } },
                            :follow => lambda { |part| Placement.follow_popover(part) })

        # The spacings a stack takes, in half units, so a column of sections can keep the room between
        # them that the game's own pages have.
        STACK_SPACINGS = (0..12).map { |halves| halves.even? ? halves / 2 : halves / 2.0 }

        Declarations.define(:stack,
                            :summary => "Parts in a column, or in a row with row: true.", :content => true,
                            :events => PAGE_EVENT.merge(SUBMIT_EVENT),
                            :params => { :row => { :type => :bool, :default => false, :doc => "true lays its parts out in a row" },
                                         :spacing => { :values => STACK_SPACINGS, :default => 2, :doc => "room between its parts, 4 px a unit, also half a unit such as 2.5" },
                                         :justify => { :values => [:start, :center, :end, :space_between], :default => :start, :doc => "where its parts sit along it when room is left" },
                                         :wrap => { :type => :bool, :default => false, :doc => "a row goes on in a new line when full" },
                                         :tail => { :type => :bool, :default => false,
                                                    :doc => "a column keeps its newest parts: it lays them out from its bottom and leaves out from the top what its height does not hold, a wrapped text its first lines first, such as status lines or a log" } }.merge(BUTTONS),
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda do |params|
                              justify = params[:justify] == :space_between ? :between : (params[:justify] || :start)
                              common(params).merge(pages(params)).merge(buttons(params)).merge(:layout => params[:row] ? :row : :column, :gap => spacing(params[:spacing] || 2),
                                                                        :justify => justify, :wrap => params[:wrap] == true, :tail => params[:tail] == true && !params[:row])
                            end,
                            :wire => lambda { |part| wire_page(part); wire_submit(part) })


        # Turns a paper's params into the engine's options: a box the keys may enter whole, or one
        # that scrolls what it holds, a key stop with focusable: that keeps the focus at its ends.
        #
        # A paper the keys stop on is a way in for C#'s tree (:panel), so cancel on it walks back to
        # the part the focus came from, as from a tab's page.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.paper(params)
          options = common(params).merge(pages(params)).merge(buttons(params)).merge(:enter => params[:enter] == true, :clickable => params[:clickable] == true)
          scrolls = params[:scroll] == :vertical
          options.merge!(:scroll => scrolls, :keep_ends => scrolls)
          options.merge!(:focusable => true, :panel => true) if reading_paper?(params)
          options
        end

        # Tells whether a paper scrolls and the keys stop on it, such as a description the player
        # reads.
        #
        # @param params [Hash] The paper's params.
        # @return [Boolean] Whether it does.
        def self.reading_paper?(params)
          params[:scroll] == :vertical && params[:focusable] ? true : false
        end

        Declarations.define(:paper,
                            :summary => "A framed box around its parts. With enter: true the keys stop on it as a whole first; with clickable: true it is one part that confirm or a click " \
                                        "presses; with scroll: it scrolls what it holds, such as a text the player reads.",
                            :content => true,
                            :params => { :enter => { :type => :bool, :default => false,
                                                     :doc => "the arrows stop on it as a whole; confirm goes inside onto the part picked there last, cancel inside comes back out" },
                                         :clickable => { :type => :bool, :default => false,
                                                         :doc => "one key stop that confirm or a click anywhere on it presses, telling on_click, what it holds taking neither the keys nor the pointer, such as a box of the party that opens the party's screen" },
                                         :scroll => { :values => [false, :vertical], :default => false,
                                                      :doc => ":vertical scrolls what it holds up and down when it is higher than the paper, by the wheel and its scrollbar; give it a key: of what it shows, such as the mod, so another text starts at its top" },
                                         :focusable => { :type => :bool, :default => false,
                                                         :doc => "with scroll:, the keys stop on it and scroll it, such as a description the player reads" } }.merge(BUTTONS),
                            :events => PAGE_EVENT.merge(SUBMIT_EVENT).merge(:click => "nothing; with clickable: true, confirm or a click on it pressed it",
                                                                            :enter => "nothing; with enter: true, the focus went inside it; with scroll: and focusable: true, the focus came onto it",
                                                                            :leave => "nothing; with enter: true, the focus came out of it; with scroll: and focusable: true, the focus left it",
                                                                            :scroll => "with scroll:, the lines of its texts in sight changed: { first:, last:, total: }, counted from 1 over every line " \
                                                                                       "of every text it holds, 0 for none, such as for \"Lines 1-12 of 40\""),
                            :keys => "with enter: true, the arrows stop on it whole and from it pick the box below, above or beside it whole by where it lies, confirm goes in and cancel comes back out; cancel on it whole closes the window; " \
                                     "with clickable: true, the arrows stop on it as one part and confirm presses it; " \
                                     "with scroll: and focusable: true, Up and Down scroll it a line and Page Up and Page Down a page, at its ends nothing, Left and Right leave it, "                                      "and cancel goes back to the part the focus came from",
                            :pad => "as the keys", :mouse => "a click on a part inside goes straight in; with clickable: true, a click anywhere on it presses it; with scroll:, the wheel over it scrolls it and its scrollbar drags",
                            :make => lambda { |options| Box.new(options) },
                            :options => lambda { |params| paper(params) },
                            :wire => lambda do |part|
                              wire_page(part)
                              wire_submit(part)
                              part.engine.on(:click) { Layer.dispatch(part, :on_click, []) }
                              part.engine.on(:went_in) { Layer.dispatch(part, :on_enter, []) }
                              part.engine.on(:came_out) { Layer.dispatch(part, :on_leave, []) }
                              part.engine.on(:focus) { Layer.dispatch(part, :on_enter, []) if reading_paper?(part.node.params) }
                              part.engine.on(:blur) { Layer.dispatch(part, :on_leave, []) if reading_paper?(part.node.params) }
                              part.engine.on(:scroll) { |lines| Layer.dispatch(part, :on_scroll, [lines]) }
                            end)

        Declarations.define(:aside,
                            :summary => "Parts beside the rest that only the mouse uses, such as a summary beside a list; the keys never enter it.",
                            :content => true, :keys => "none: the keys pass over it and what it holds", :mouse => "as its parts",
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(2), :aside => true) })

        # A drawer's width while open unless told.
        DRAWER_WIDTH = 240

        # Turns a drawer's params into the engine's options: one that lies over the rest is a root of
        # its own over its window, inside the edge of what it lies in, that takes the keys while open
        # and closes on cancel and a click outside.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.drawer(params)
          options = common(params)
          options.delete(:width)
          options.delete(:visible)
          options.merge!(:open_width => params[:width].is_a?(Integer) ? params[:width] : DRAWER_WIDTH, :mini => params[:variant] == :mini)
          return options unless params[:variant] == :temporary

          options.merge(:floating => true, :layer => true, :captures => true, :closable => true, :close_outside => true, :movable => false,
                        :z => Placement.depth(:popover, params), :beside_side => params[:side] == :right ? :inside_right : :inside_left)
        end

        Declarations.define(:drawer,
                            :summary => "A panel at the left or right of what it lies in that opens and closes, such as the filters beside a list; " \
                                        "a button the owner places opens it. Its drawer_header stays at its top.",
                            :content => true, :detached => lambda { |params| params[:variant] == :temporary },
                            :params => { :side => { :values => [:left, :right], :default => :left, :doc => "the side of what it lies in it opens at" },
                                         :open => { :type => :bool, :default => false, :doc => "it opens as this turns true and closes as it turns false" },
                                         :bind => { :kind => :bind, :doc => "a state that holds whether it is open, both ways, instead of open:" },
                                         :variant => { :values => [:persistent, :temporary, :mini], :default => :persistent,
                                                       :doc => ":persistent stands beside the rest and takes no room while shut; :mini keeps a narrow strip with its drawer_header while shut; " \
                                                               ":temporary lies over the rest and takes the keys while open" },
                                         :width => { :type => :int, :default => DRAWER_WIDTH, :doc => "its width while open, in pixels" } },
                            :events => { :change => "whether it is open now, after cancel or a click outside closed a :temporary drawer" },
                            :keys => "an open drawer's parts take the keys as the parts beside them do: Left from the left edge of the rest enters an open :left drawer; " \
                                     "a :temporary drawer takes the focus as it opens, and cancel closes it and gives the focus back",
                            :pad => "as the keys", :mouse => "a click outside a :temporary drawer closes it",
                            :places => "`drawer_header`", :make => lambda { |options| Drawer.new(options) },
                            :options => lambda { |params| drawer(params) },
                            :wire => lambda { |part| Layer.wire_drawer(part) },
                            :sync => lambda { |part, wanted| Layer.sync_drawer(part, wanted) },
                            :follow => lambda { |part| Layer.follow_drawer(part) })

        Declarations.define(:drawer_header,
                            :summary => "The top of a drawer, which a :mini drawer keeps while shut, such as the button that opens it.", :content => true, :inside => [:drawer],
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :row, :gap => spacing(2)) })

        # The color of each severity of an alert and a toast, nil for none of its own.
        SEVERITY_COLORS = { :normal => nil, :info => :info, :success => :success, :warning => :warning, :error => :error }

        Declarations.define(:alert,
                            :summary => "A notice on a plate across its parent in the color of its severity, such as a change that waits for the game " \
                                        "to start again, with the buttons it holds after its text.", :args => [:text], :content => true,
                            :params => { :text => { :kind => :live, :type => :text, :doc => "what it says; cut to its room, the whole text becomes its tooltip" },
                                         :severity => { :values => SEVERITY_COLORS.keys, :default => :normal,
                                                        :doc => "its color: the text's and a bar down its left edge; :normal draws the plain text without a bar" },
                                         :icon => { :type => :icon, :doc => "an icon before its text" },
                                         :text_color => { :type => :color, :doc => "its text's color instead of its severity's, which keeps the bar, such as :text for a toast in the plain text color" },
                                         :dense => { :type => :bool, :default => false, :doc => "lower, with less room above and below its text" },
                                         :most_lines => { :type => :count,
                                                          :doc => "its text breaks into lines that fit, at most this many; the last ends in ... and the whole text becomes its tooltip; without it one line cut to its room" } },
                            :events => { :close => "nothing; the player clicked its close mark, which shows at its end only with on_close:, or pressed it; hide it there" },
                            :keys => "none of its own: the keys reach its buttons and its close mark", :pad => "as the keys",
                            :mouse => "a click on its close mark tells on_close",
                            :make => lambda { |options| Alert.new(options) },
                            :options => lambda do |params|
                              severity = SEVERITY_COLORS[params[:severity] || :normal]
                              common(params).merge(:text => params[:text].to_s, :color => color(params[:text_color]) || severity || :text, :accent => severity, :icon => params[:icon],
                                                   :dense => params[:dense] == true, :closeable => !params[:on_close].nil?, :align_text => :start,
                                                   :most_lines => params[:most_lines])
                            end,
                            :wire => lambda { |part| part.engine.on(:close) { Layer.dispatch(part, :on_close, []) } },
                            :sync => lambda { |part, wanted| Layer.sync_alert(part, wanted) })

        Declarations.define(:divider,
                            :summary => "A thin line between parts: across a column, or upright in a row with vertical: true.",
                            :params => { :vertical => { :type => :bool, :default => false, :doc => "true draws it upright, between parts of a row" },
                                         :color => { :type => :color, :default => :edge, :doc => "its color" },
                                         :thickness => { :type => :int, :default => 1, :doc => "how many pixels thick it is" } },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| Divider.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:direction => params[:vertical] ? :vertical : :horizontal, :color => color(params[:color]),
                                                   :thickness => params[:thickness] || 1)
                            end)

        # How far the pages of slides start beside their place as they ease in.
        ENTER_SHIFT = 24

        Declarations.define(:slides,
                            :summary => "Pages side by side that slide, such as a character page that gives way to the details of the item picked. " \
                                        "Each page is a slide; shown: tells how many show at once.", :content => true,
                            :params => { :bind => { :kind => :bind, :doc => "a state that holds the first page shown, both ways: 0 for the first" },
                                         :shown => { :values => [1, 2, 3], :default => 1, :doc => "how many pages show side by side" },
                                         :spacing => { :values => (0..6).to_a, :default => 3, :doc => "room between two pages, 4 px a unit" },
                                         :enter => { :type => :bool, :default => false,
                                                     :doc => "a page the bound state slides to takes the focus: its part with autofocus:, else its first key stop, such as the buttons of a page a pick opened" } },
                            :events => { :change => "the first page shown, as a slide starts: 0 for the first",
                                         :refuse => "the page a slide would have brought into view, refused by its can_enter: false" },
                            :keys => "Right or Left at the edge of the page the focus is on slides a page that way; cancel slides a page back " \
                                     "before it reaches the window, except on the part the window opened on; a slide brings a page into view as the focus enters it",
                            :pad => "the d-pad as the arrows; B as cancel",
                            :mouse => "a button inside with on_click: :forward or :back slides a page on or back, which the keys skip",
                            :actions => { :enter_from => { :args => "step",
                                                           :doc => "the pages ease in from the side a step points to, the right for 1 and the left for -1, such as after the window switched to another character",
                                                           :call => lambda { |part, step| part.engine.enter_from([ENTER_SHIFT * (step.to_i <=> 0), 0]) } } },
                            :make => lambda { |options| Slides.new(options) },
                            :options => lambda { |params| common(params).merge(:shown => params[:shown] || 1, :gap => spacing(params[:spacing] || 3)) },
                            :wire => lambda { |part| Layer.wire_slides(part) },
                            :synced => lambda { |part| Layer.bind_slides(part) })

        Declarations.define(:slide,
                            :summary => "One page of slides: a column of parts. Its slides decides when it shows.", :content => true, :inside => [:slides],
                            :params => { :can_enter => { :kind => :live, :type => :bool, :default => true,
                                                         :doc => "false refuses a slide that would bring it into view, with the buzzer and on_refuse of its slides" },
                                         :spacing => { :values => (0..6).to_a, :default => 2, :doc => "room between its parts, 4 px a unit" } },
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:layout => :column, :gap => spacing(params[:spacing] || 2))
                              options.delete(:visible)
                              options
                            end)

        Declarations.define(:tabs,
                            :summary => "Tabs over one page each; only the picked tab's page shows. Each page is a tab, tabs_header holds parts " \
                                        "before the tabs in their row, such as a Back button, and tabs_subheader parts under that row that stay " \
                                        "as the tabs change.", :content => true,
                            :params => { :bind => { :kind => :bind, :doc => "a state that holds the picked tab, both ways: its id:, else its place from 0" },
                                         :pages => { :type => :bool, :default => true,
                                                     :doc => "false makes a bar of tabs alone, whose tabs the arrows walk with the parts beside them" },
                                         :wrap => { :type => :bool, :default => false, :doc => "the tabs go on in a new row when their row is full, such as many tabs in a narrow window" },
                                         :enter => { :type => :bool, :default => false, :doc => "a tab picked moves the focus into its page; on a bar alone, into the part under the bar, such as the list the tab fills" },
                                         :arrows => { :type => :bool, :default => false, :doc => "Left and Right step the tabs too, wherever the focus has no use for them" },
                                         :spacing => { :values => (0..6).to_a, :default => 1, :doc => "room between the row of tabs and the page, 4 px a unit" } },
                            :events => { :change => "the tab the player picked: its id:, else its place from 0" },
                            :keys => "Tab and Shift+Tab step the tabs nearest the focus, round at either end; the arrows stay in the page",
                            :pad => "the shoulders step the tabs nearest the focus; tabs that show a single tab pass them on, such as to the window's on_page", :mouse => "a click on a tab picks it",
                            :places => "`tabs_header` (parts before the tabs), `tabs_subheader` (parts under the tabs, over every page), each `tab` by its id",
                            :make => lambda { |options| LayerTabs.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:pages => params[:pages] != false, :enter => params[:enter] == true, :arrows => params[:arrows] == true,
                                                   :wrap => params[:wrap] == true, :gap => spacing(params[:spacing] || 1))
                            end,
                            :wire => lambda { |part| Layer.wire_tabs(part) },
                            :sync => lambda { |part, wanted| part.engine.layer_sync(wanted) },
                            :synced => lambda { |part| Layer.bind_tabs(part) })

        Declarations.define(:tab,
                            :summary => "One tab of tabs and its page, a column of parts.", :args => [:title], :content => true, :inside => [:tabs],
                            :params => { :title => { :kind => :live, :type => :text, :required => true, :doc => "the tab's text" },
                                         :badge => { :kind => :live, :doc => "a count above 0 on a plate at the tab's end, \"9+\" above 9; true shows a dot" },
                                         :color => { :type => :color, :doc => "the tab's own color: its text, and its plate while it is picked" },
                                         :icon => { :type => :icon, :doc => "an icon drawn before its text" },
                                         :spacing => { :values => (0..6).to_a, :default => 1, :doc => "room between the parts of its page, 4 px a unit" } },
                            :make => lambda { |options| LayerTabPage.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:layout => :column, :gap => spacing(params[:spacing] || 1))
                              options[:tab_look] = { :text => params[:title].to_s, :badge => params[:badge], :color => color(params[:color]), :icon => params[:icon],
                                                     :tooltip => options.delete(:tooltip), :visible => options.delete(:visible), :enabled => options.delete(:enabled) }
                              options
                            end)

        Declarations.define(:tabs_header,
                            :summary => "The parts before the tabs in their row, such as a Back button.", :content => true, :inside => [:tabs],
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :row, :gap => spacing(2)) })

        Declarations.define(:tabs_subheader,
                            :summary => "The parts under the row of tabs and over every page, which stay where they are as the tabs change, " \
                                        "such as what every page is about.", :content => true, :inside => [:tabs],
                            :make => lambda { |options| TabsSubheader.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(1)) })

        # The param of a text, a list and a table that highlights a text wherever it occurs.
        HIGHLIGHT = { :highlight => { :kind => :live, :type => :text,
                                      :doc => "a text drawn on the theme's primary color, its letters in their own color and outline, wherever it occurs, ignoring case, such as the words a search typed" } }

        Declarations.define(:text,
                            :summary => "A line of text.", :args => [:text],
                            :params => { :text => { :kind => :live, :type => :texts,
                                                    :doc => "what it says, or an Array of ever shorter texts of which the first that fits its line shows, picked by its pixels; the whole text then becomes its tooltip" },
                                         :typo => { :values => TYPO_SIZE.keys, :default => :body1, :doc => "its size and weight" },
                                         :color => { :kind => :live, :type => :color, :doc => "its color" },
                                         :align => { :values => [:start, :center, :end], :doc => "where its lines sit in its width, and it across its stack" },
                                         :wrap => { :type => :bool, :default => false, :doc => "breaks into lines that fit" },
                                         :most_lines => { :type => :count, :values => [:fill],
                                                          :doc => "the most lines, or :fill for as many as its room holds; the last ends in ... and the whole text becomes its tooltip" },
                                         :min_font_size => { :type => :int, :doc => "it gets this small before it cuts; texts in one row share the smallest size" },
                                         :fit => { :values => [:cut, :squeeze, :narrow], :default => :cut,
                                                   :doc => "what a line too wide for its room does: :cut ends it in ...; " \
                                                           ":squeeze hands it whole to the game's draw_text, which draws it narrower into its width as the game's own windows draw a line too wide; not with escapes:; " \
                                                           ":narrow gives up its room in a row first, then draws narrower, down to 85% of its width, and past that ends in ... with the whole text as its tooltip" },
                                         :line_height => { :type => :int, :doc => "the height of each of its lines in pixels, its text in their middle, never below an icon it draws; its typo:'s own by default" },
                                         :plate => { :type => :bool, :default => false, :doc => "draws it on a dark plate as wide as its text, so it reads over a busy map" },
                                         :escapes => { :type => :bool, :default => false, :doc => "draws the game's text codes, such as \\C[2] for a color and \\I[64] for an icon" } }.merge(HIGHLIGHT),
                            :events => { :click => "nothing; it was clicked" },
                            :keys => "none", :mouse => "a click tells on_click",
                            :make => lambda { |options| Label.new(options) },
                            :options => lambda do |params|
                              texts = params[:text].is_a?(Array) ? params[:text] : [params[:text]]
                              options = common(params).merge(:text => texts.first.to_s, :shorter => texts.size > 1 ? texts.drop(1).map { |each| each.to_s } : nil,
                                                             :font_size => typo_size(params[:typo] || :body1), :body => params[:typo].nil?,
                                                             :color => color(params[:color]), :wrap => params[:wrap] == true || !params[:most_lines].nil?,
                                                             :escapes => params[:escapes] == true, :plate => params[:plate] ? :text : false)
                              options[:align] = params[:align] if params[:align]
                              options[:most_lines] = params[:most_lines] if params[:most_lines]
                              options[:min_font_size] = params[:min_font_size] if params[:min_font_size]
                              options[:row_height] = params[:line_height] if params[:line_height]
                              options[:whole] = true if params[:fit] == :squeeze
                              options[:squeeze] = options[:shrink] = true if params[:fit] == :narrow
                              options[:highlight] = params[:highlight].to_s if params[:highlight]
                              options
                            end,
                            :wire => lambda { |part| wire_click(part) })

        Declarations.define(:image,
                            :summary => "A picture scaled to its room: a picture file, or a character's art, face or map figure.",
                            :params => { :file => { :type => :text, :doc => "a picture file of the game or of your mod, such as \"Graphics/Pictures/bg010\"" },
                                         :portrait => { :doc => "a character whose art the game's Library shows" },
                                         :face => { :doc => "a character whose face shows" },
                                         :figure => { :doc => "a character whose map figure shows, standing" },
                                         :fit => { :values => [:contain, :cover, :fill],
                                                   :doc => ":contain shows all of it, :cover fills its room and cuts what sticks out, :fill stretches it to its room; without fit: a figure scales by whole steps so its pixels stay sharp, the others as :contain" },
                                         :anchor => { :values => [:top, :center, :bottom], :doc => "which part stays when it is cut, and where a smaller picture sits; :bottom for a figure, else :center" },
                                         :scale => { :values => [:auto],
                                                     :doc => ":auto scales it to the room it gets, keeping its proportions: its height follows the width it gets, such as a grid item's or its width:'s, " \
                                                             "and its width its height:; it draws at any size, larger or smaller; without it as told under fit:" },
                                         :sampling => { :values => [:sharp, :smooth],
                                                        :doc => "with scale: :auto, how its pixels scale: :sharp takes each pixel's nearest pixel, so pixel art stays crisp, :smooth blends them; " \
                                                                ":sharp for a figure, else :smooth" },
                                         :blur => { :type => :bool, :default => false, :doc => "draws a picture file blurred, such as a screenshot that spoils the story" },
                                         :label => { :kind => :live, :type => :text, :doc => "a text on a dark band across its middle" } },
                            :events => { :click => "nothing; it was clicked" },
                            :keys => "none", :mouse => "a click tells on_click",
                            :make => lambda { |options| Picture.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:blur => params[:blur] == true, :auto_scale => params[:scale] == :auto)
                              [:file, :portrait, :face, :figure, :fit, :anchor, :sampling].each { |name| options[name] = params[name] unless params[name].nil? }
                              options[:label] = params[:label].to_s unless params[:label].nil?
                              options
                            end,
                            :wire => lambda { |part| wire_click(part) })

        # The sides of an icon by the names its size: takes, :medium the IconSet's own.
        ICON_SIDES = { :small => 16, :medium => 24, :large => 48 }

        Declarations.define(:icon,
                            :summary => "An icon on its own, such as the mark of a quest in a head, drawn from the game's IconSet or a picture file.",
                            :args => [:icon],
                            :params => { :icon => { :type => :icon, :required => true, :doc => "the icon" },
                                         :size => { :type => :size, :values => ICON_SIDES.keys, :default => :medium,
                                                    :doc => "its side: :small (16 px), :medium (24 px, the IconSet's own) or :large (48 px), or pixels" },
                                         :opacity => { :type => :int, :doc => "how see-through it draws, 0 to 255, such as a star that is off; opaque without it" } },
                            :events => { :click => "nothing; it was clicked" },
                            :keys => "none", :mouse => "a click tells on_click",
                            :make => lambda { |options| Icon.new(options) },
                            :options => lambda do |params|
                              side = ICON_SIDES[params[:size] || :medium] || params[:size]
                              common(params).merge(:icon => params[:icon], :size => [side, side])
                            end,
                            :wire => lambda { |part| wire_click(part) },
                            :follow => lambda do |part|
                              wanted = part.node.params[:opacity]
                              part.engine.opacity = wanted unless part.engine.opacity == (wanted || Component::OPAQUE)
                            end)

        Declarations.define(:tooltip,
                            :summary => "Wraps a part and shows markup while the pointer rests on it, or while the keys focus it, such as a gem " \
                                        "with what it adds; a plain text needs no tooltip part, as every part takes tooltip:.", :content => true,
                            :params => { :content => { :kind => :content, :required => true, :doc => "the markup it shows, such as -> { text \"Gem of Attack\" }" },
                                         :side => { :values => SIDES, :doc => "the side of the part inside it shows on, flush with its start; without side: beside the pointer, and under the part as the keys focus it" } },
                            :keys => "none of its own; it shows under the part inside, or on its side:, as the keys focus it",
                            :mouse => "it shows beside the pointer, or on its side: of the part inside, once the pointer rests on the part inside",
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => 0) },
                            :sync => lambda { |part, wanted| Layer.sync_tooltip(part, wanted) })

        Declarations.define(:slot,
                            :summary => "The markup a content param of a built-in describes, which the built-in places itself.", :hidden => true,
                            :common => false, :params => { :name => { :type => :id, :doc => "the content param" } },
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |_params| { :layout => :column, :gap => 0 } })

        Declarations.define(:forms,
                            :summary => "A part and its compact forms, of which the one its window's step picks shows; the markup makes it for compact:.",
                            :hidden => true, :content => true,
                            :params => { :steps => { :type => :array, :doc => "the step from which each form shows, the first 0" } },
                            :make => lambda { |options| Forms.new(options) },
                            :options => lambda { |params| common(params).merge(:steps => params[:steps]) })

        Declarations.define(:measures,
                            :summary => "A part and its hidden copies, which its window picks the step of compact forms for; the markup makes it for compact_for:.",
                            :hidden => true, :content => true,
                            :make => lambda { |options| Measures.new(options) },
                            :options => lambda { |params| common(params) })

        Declarations.define(:button,
                            :summary => "A button the player presses.", :args => [:text],
                            :params => { :text => { :kind => :live, :type => :text, :doc => "what it says" },
                                         :variant => { :values => [:filled, :outlined, :text], :default => :text,
                                                       :doc => "its look, which the theme draws in its color: :filled a plate in it, :outlined its edge in it, :text its text in it; each lights while the pointer, a press or the focus is on it" },
                                         :color => { :type => :color, :doc => "its color, a color name of its theme's palette or one a mod added" },
                                         :text_color => { :type => :color, :doc => "its text's color, which wins over the theme's, such as the text on a :filled plate" },
                                         :hotkey => { :type => :hotkey, :doc => "a hotkey of Mod_Framework::Hotkeys that presses it; quiet while anything types, while a window above holds the game's buttons, while it is hidden, off the hotkey's scenes, and where a screen uses the game's button its key is bound to" },
                                         :show_key => { :type => :bool, :default => false, :doc => "draws its hotkey's key before its text, \"Y: Accept\", anew after the player binds another" },
                                         :icon => { :kind => :live, :type => :icon, :doc => "an icon drawn before its text" },
                                         :badge => { :type => :count, :values => [true, false],
                                                     :doc => "a count at its end on a dark plate, such as the filters picked: \"9+\" above 9 and nothing at 0, or a dot for true; it keeps its room at 0, so the button never changes its width" },
                                         :badge_color => { :type => :color, :default => :gold, :doc => "the color of its badge's count or dot" },
                                         :size => { :values => [:small, :medium, :large], :default => :medium,
                                                    :doc => "its size, as MudBlazor's: :small in the small font with less room around it, such as beside a list's row; :large in the large font with more room" } },
                            :events => { :click => "nothing; it was pressed. on_click: :close closes the root with the reason :button, on_click: :submit sends the form it lies in" },
                            :keys => "confirm presses it, and so does its hotkey; the keys skip a button without on_click and one whose on_click is :close, :back or :forward, as those repeat a key",
                            :pad => "A presses it", :mouse => "a click presses it",
                            :make => lambda { |options| Button.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:text => params[:text].to_s, :color => color(params[:color]), :text_color => color(params[:text_color]),
                                                   :variant => params[:variant] || :text, :acts => !params[:on_click].nil?,
                                                   :repeats => REPEATED_KEYS.include?(params[:on_click]), :quiet => params[:on_click] == :submit, :declared_hotkey => params[:hotkey] || false,
                                                   :show_key => params[:show_key] == true, :icon => params[:icon], :badge => params[:badge] == false ? nil : params[:badge],
                                                   :badge_color => color(params[:badge_color]) || :gold, :button_size => params[:size])
                            end,
                            :wire => lambda { |part| part.engine.on(:click) { Layer.dispatch(part, :on_click, []) } })

        Declarations.define(:badge,
                            :summary => "A count, a short text or a dot over the top right corner of the parts it holds, as MudBlazor's badge, such as the count of unread letters on a button.",
                            :content => true,
                            :params => { :content => { :kind => :live, :doc => "a count, \"9+\" above 9 and nothing at 0, or a short text such as \"New\"; nil shows nothing" },
                                         :dot => { :type => :bool, :default => false, :doc => "a dot instead of the content, such as for something new without a count" },
                                         :color => { :type => :color, :doc => "the badge's color; the theme's primary color by default" } },
                            :keys => "none: the keys reach the parts it holds", :mouse => "the pointer passes through the badge to the parts it holds",
                            :make => lambda { |options| BadgeHolder.new(options) },
                            :options => lambda { |params| common(params).merge(:content => params[:content], :dot => params[:dot] == true, :color => color(params[:color]) || :primary) },
                            :sync => lambda { |part, wanted| part.engine.hold(wanted) })

        # What a param of a part that only gives a value to its parent hands its engine part: nothing.
        NO_OPTIONS = lambda { |_params| {} }

        # The engine part of a part that only gives a value to its parent, such as a chip, which is
        # never put on the screen.
        HELD = lambda { |_options| Component.new }

        # The param every input takes for its label, which the markup draws above it (input_label).
        INPUT_LABEL = { :label => { :kind => :live, :type => :text, :doc => "a caption above it, as MudBlazor draws an input's label" } }

        # The params every input takes that check its value, which shows its error under it.
        FORM_INPUT = {
          :required => { :doc => "true, or the error to show, such as \"Name the formation\": an empty value is an error, \"Required\" by default" },
          :validate => { :kind => :item,
                         :doc => "a lambda of its value answering the error to show, or nil while the value is fine, such as ->(name) { \"Too short\" if name.size < 3 }; " \
                                 "a method name calls that method of the component" }
        }

        Declarations.define(:input_label,
                            :summary => "An input with its label: the label above the input and its error under it, in a column the markup makes for an " \
                                        "input's label: or its required: and validate:.",
                            :hidden => true, :content => true,
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(1)) },
                            :sync => lambda { |part, wanted| Layer.sync_input_label(part, wanted) })

        Declarations.define(:text_field,
                            :summary => "A field the player types into, with the chat's text input: Shift, Caps Lock, AltGr, accented letters and " \
                                        "Ctrl+V work, and the game's buttons and every mod's hotkeys stay quiet while it types.", :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds its text, both ways" },
                                         :placeholder => { :kind => :live, :type => :text, :doc => "a dim text it shows while it is empty, also while the player types, such as \"Search\"" },
                                         :password => { :type => :bool, :default => false, :doc => "shows a * for each character" },
                                         :lines => { :type => :int, :default => 1, :doc => "its lines; with more than 1 it ends in ... while it does not type" },
                                         :max_length => { :type => :int, :doc => "the most characters it takes" },
                                         :allowed => { :doc => "a Regexp of the characters it takes, such as /[0-9]/; any other plays the buzzer" },
                                         :read_only => { :type => :bool, :default => false, :doc => "it takes the focus and shows its text but takes no typing" },
                                         :confirm_to_type => { :type => :bool, :default => false,
                                                               :doc => "the focus rests on it until confirm or a click starts typing; cancel then puts the text back" },
                                         :letters => { :type => :bool, :default => true, :doc => "a gamepad's A opens the game's letter pages for it" },
                                         :completions => { :type => :completions,
                                                           :doc => "words it offers for the last word typed: an Array, narrowed to the words that hold it anywhere, ignoring case, or a lambda of that word answering its own words; Up and Down move, Enter or Tab take one" },
                                         :steer => { :type => :id,
                                                     :doc => "the id of a list in its window whose cursor Up, Down, Page Up, Page Down and Enter move while it types, as a search over a list; or of a log, which Up, Down, Page Up and Page Down scroll, as a chat's line over its log" },
                                         :keys => { :type => :array, :doc => "names of keys it claims while it types, such as [\"Alt+Up\"], which tell on_key" },
                                         :typing_help => { :type => :text, :doc => "the help line's text while it types" },
                                         :leave_sides => { :type => :bool, :default => false,
                                                           :doc => "Right with the caret at the end of its text and Left at its start move the focus to the part beside it, as along a bar of buttons with a search among them" }).merge(FORM_INPUT),
                            :events => { :change => "its text, as the player typed it", :submit => "its text, as Enter gave it; a field that steers a list picks the list's row instead, and one that offers completions takes the lit one first",
                                         :revert => "nothing; a field with confirm_to_type: put its text back on cancel",
                                         :key => "the name of a key of keys: pressed while it types", :complete => "the completion taken and its place",
                                         :type => "nothing; a field with confirm_to_type: started typing",
                                         :refuse => "nothing; it could not start typing, as its text box did not open",
                                         :cancel => "nothing; the first cancel stopped its typing, such as to empty a search" },
                            :keys => "typing, Left, Right, Home, End and Ctrl+V; Enter submits, as does a key bound to confirm that it does not type; the first cancel stops typing and the next goes on; " \
                                     "Up and Down leave a field of one line, and with leave_sides: Right at the end of its text and Left at its start; " \
                                     "Tab goes into the window's first field and back while the window shows no tabs",
                            :pad => "A opens the game's letter pages unless letters: false, titled by its label: or else the caption of the field it sits in, where B takes the last letter away and closes them on an empty text; B as cancel", :mouse => "a click puts the caret there and types",
                            :make => lambda { |options| TextField.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:placeholder => params[:placeholder], :mask => params[:password] ? "*" : nil, :lines => params[:lines] || 1,
                                                             :max_length => params[:max_length], :allowed => params[:allowed], :keys => Array(params[:keys]),
                                                             :read_only => params[:read_only] == true, :confirm_to_type => params[:confirm_to_type] == true,
                                                             :letters => params[:letters] != false, :leave_sides => params[:leave_sides] == true)
                              options[:typing_help] = params[:typing_help].to_s if params[:typing_help]
                              options[:letters_title] = params[:label].to_s unless params[:label].nil?
                              options
                            end,
                            :wire => lambda { |part| Layer.wire_text_field(part) },
                            :synced => lambda { |part| Layer.follow_text_field(part) })

        # Tells the block that keeps the options rows an options_list shows: those its only: answers
        # true for.
        #
        # @param params [Hash] The options_list's params.
        # @return [Proc, nil] The block, nil for every row.
        def self.options_filter(params)
          params[:only] && lambda { |row| per_item(params[:only], row) }
        end

        # Presses a button row of an options_list through its on_press, which may answer false.
        #
        # @param part [Object] The options_list's part.
        # @param key [Symbol] The row's key.
        # @return [Boolean] Whether it was pressed; false without on_press.
        def self.press_option(part, key)
          return false if part.gone || part.node.params[:on_press].nil?

          Layer.ask(part, :on_press, [key])
        end

        # The rows of options_list hotkeys: :remembered, read each time the list reads its rows.
        REMEMBERED_HOTKEYS = lambda { Mod_Framework::Hotkeys.rows_with_remembered }

        Declarations.define(:options_list,
                            :summary => "The options rows mods add with Mod_Framework::Options, as Options > Mods shows them: under a heading per mod, " \
                                        "each with its value, a mod's hotkey rows after its other rows, under a small Hotkeys caption when it has other rows, " \
                                        "and a help line under them that tells the row under the cursor.",
                            :params => { :mod => { :type => :text,
                                                   :doc => "the mod whose rows it shows, by the name in brackets its rows start with, such as \"Camp Notes\", with the indented rows under them, " \
                                                           "or \"Global\" for the rows of no mod, as Options.rows_of reads them; every mod's by default" },
                                         :headings => { :type => :bool, :default => true, :doc => "false leaves out the heading over each mod's rows, such as beside a list of the mods" },
                                         :only => { :kind => :item, :doc => "a lambda of a row answering whether it shows, such as ->(row) { row[:key] != :camp_debug }" },
                                         :hotkeys => { :values => [:remembered],
                                                       :doc => ":remembered adds a hotkey row for every hotkey remembered from an earlier game of the mods that are on and not loaded now, " \
                                                               "such as the Default mods' at the title, as the title's Mod Configuration shows them" },
                                         :help_line => { :type => :bool, :default => true, :doc => "the help line under the rows" },
                                         :help_window => { :type => :text_window,
                                                           :doc => "a game window that shows the row's help in place of the help line, such as the help window of the game's Options" },
                                         :empty => { :type => :text, :doc => "what it says without rows" },
                                         :help => { :type => :text,
                                                    :doc => "what the help line or help_window: tells while the rows lack the focus, such as what the list of the mods beside them does; " \
                                                            "the help of the row under the cursor by default" },
                                         :patched_rows => { :hidden => true, :doc => "the blocks of UI.patch's rows, each run in turn on the rows it shows; only UI.patch gives them" } },
                            :events => { :change => "the key of the row the player changed and its value now, a hotkey row's key code",
                                         :press => "the key of a button row the player confirmed; answering false buzzes, and without on_press a button row buzzes",
                                         :enter => "nothing; the focus came onto its rows", :leave => "nothing; the focus left its rows" },
                            :keys => "Up and Down move; Left and Right step a row's value, dimmed at its end, and on a row without a value move to the part beside; " \
                                     "confirm steps a value on, presses a button row or " \
                                     "has a hotkey row wait for its key, as hotkey_field does: the help says \"Press the new key for Chat. Esc keeps F5.\", " \
                                     "a key another hotkey has is refused with the buzzer and the help names that hotkey, and Esc or Numpad 0 keeps the " \
                                     "old key; while a row waits nothing else acts",
                            :pad => "as the keys; B keeps a waiting row's key", :mouse => "a click on a value's arrows steps it; a click on a row picks it; a click outside a waiting row keeps its key",
                            :make => lambda { |options| OptionsList.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:only => options_filter(params), :mod => params[:mod] && params[:mod].to_s, :headings => params[:headings] != false,
                                                             :help_line => params[:help_line] != false, :help_window => params[:help_window], :help => params[:help] && params[:help].to_s)
                              options[:rows] = REMEMBERED_HOTKEYS if params[:hotkeys] == :remembered
                              options[:empty_text] = params[:empty].to_s if params[:empty]
                              options[:patched_rows] = params[:patched_rows] if params[:patched_rows]
                              options
                            end,
                            :wire => lambda do |part|
                              part.engine.on(:change) { |row, value| Layer.dispatch(part, :on_change, [row[:key], value]) }
                              part.engine.on(:enter) { Layer.dispatch(part, :on_enter, []) }
                              part.engine.on(:leave) { Layer.dispatch(part, :on_leave, []) }
                              part.engine.handler = lambda { |key| press_option(part, key) }
                            end,
                            :sync => lambda { |_part, _wanted| nil },
                            :follow => lambda { |part| part.engine.refresh })

        Declarations.define(:hotkey_field,
                            :summary => "A field the player presses to bind one of the hotkeys mods define to another key, as Options > Mods does: " \
                                        "the hotkey's name at its start and its key at its end.", :args => [:hotkey], :labelled => true,
                            :params => INPUT_LABEL.merge(:hotkey => { :type => :hotkey, :required => true, :doc => "the hotkey it binds, as Mod_Framework::Hotkeys.define named it" },
                                                         :text => { :kind => :live, :type => :text, :doc => "the name at its start; the hotkey's own name without its group by default" }),
                            :events => { :change => "the name of the key the player bound, such as \"F5\"" },
                            :keys => "confirm waits for one key: a free key binds as it is let go, unless another key was held with it; Esc, Numpad 0 " \
                                     "or a key bound to cancel keeps the old key; a key one of the game's buttons, the game, the framework or " \
                                     "another hotkey has is refused with the buzzer, the field says why and waits on; while it waits, every " \
                                     "other key and every hotkey stays quiet",
                            :pad => "A waits for a key; B keeps the old one", :mouse => "a click waits for a key; a click outside it keeps the old one",
                            :make => lambda { |options| HotkeyField.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:action => params[:hotkey], :name => params[:text].nil? ? nil : params[:text].to_s, :acts => true)
                            end,
                            :wire => lambda { |part| part.engine.on(:change) { |key| Layer.dispatch(part, :on_change, [key]) } })

        # The text of the last chip of a chip_set that stands for the chips left out, by how many.
        MORE_CHIPS_TEXT = "+%d more"

        Declarations.define(:chip_set,
                            :summary => "A wrapping row of chips that only show, such as a mod's tags; each chip is a chip. A filter the player turns on and off is a checkbox, a switch or a toggle_group.",
                            :content => true, :labelled => true,
                            :params => INPUT_LABEL.merge(:most => { :type => :count, :values => [:fit], :default => :fit,
                                                                    :doc => "the most chips it shows, or :fit for as many as one row of its width holds; a last chip \"+3 more\" stands for the others and names them in its tooltip" }),
                            :keys => "none: the chips take no focus", :pad => "none",
                            :mouse => "the pointer shows a chip's tooltip; a click does nothing",
                            :make => lambda { |options| Chips.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:more_text => MORE_CHIPS_TEXT)
                              most = params[:most] || :fit
                              if most == :fit
                                options[:most_rows] = 1
                              else
                                options[:most] = most
                              end
                              options
                            end,
                            :sync => lambda { |part, _wanted| Layer.sync_chips(part) })

        Declarations.define(:chip,
                            :summary => "One chip of a chip_set.", :args => [:text], :inside => [:chip_set], :common => false,
                            :params => { :text => { :type => :text, :doc => "what it says" },
                                         :icon => { :type => :icon, :doc => "an icon; a chip of an icon alone shows it in its middle" },
                                         :icons => { :type => :array, :doc => "several icons side by side in place of icon:, such as the elements a weapon strikes with" },
                                         :variant => { :values => [:filled, :outlined, :text], :default => :filled,
                                                       :doc => "its look, which the theme draws in its color: :filled the chip in it, :outlined its edge and text in it, :text its text in it" },
                                         :color => { :type => :color, :doc => "its color, which fills it; the theme's primary color without one" },
                                         :tooltip => Declarations::COMMON[:tooltip], :key => Declarations::COMMON[:key] },
                            :make => HELD, :options => NO_OPTIONS)

        Declarations.define(:select,
                            :summary => "A button that opens a menu of values below it: one is picked, or any number turned on with multi: true, " \
                                        "such as the filters of a list. Each value is a select_item.", :args => [:label], :content => true, :labelled => true,
                            :params => INPUT_LABEL.merge(:placeholder => { :kind => :live, :type => :text,
                                                                           :doc => "the button's text while no value is on, such as \"Filter\"; with multi: true it names how many are on, \"Filter (2)\"" },
                                                         :bind => { :kind => :bind, :doc => "a state that holds the value picked, both ways; with multi: true the values that are on, an Array" },
                                                         :multi => { :type => :bool, :default => false, :doc => "any number of values may be on; false keeps one, which a pick turns on and closes the menu, and the button shows it" },
                                                         :columns => { :type => :count, :values => [:auto], :default => :auto,
                                                                       :doc => "the menu's columns; :auto as many as keep it to most_rows: lines" },
                                                         :most_rows => { :type => :int, :default => 8, :doc => "the most lines of the menu with columns: :auto" },
                                                         :clear_text => { :type => :text, :doc => "an entry after the others that turns every value off, such as \"Clear\"" },
                                                         :steer => { :type => :id,
                                                                     :doc => "the id of a list in its window whose left edge and width its menu takes, and whose rows its clear_text: entry counts while a value is on" },
                                                         :button => { :values => Declarations::BUTTONS,
                                                                      :doc => "one of the game's buttons that closes its open menu, such as the one a list's on_button: opens it with" }).merge(FORM_INPUT),
                            :events => { :change => "the value picked, nil once cleared; with multi: true the values that are on now",
                                         :open => "nothing; its menu opened", :close => "nothing; its menu closed" },
                            :actions => { :open_menu => { :doc => "opens its menu with the keys in it, such as from a list's on_button:",
                                                          :call => lambda { |part| part.engine.open_menu } },
                                          :close_menu => { :doc => "closes its menu", :call => lambda { |part| part.engine.close_menu } } },
                            :keys => "confirm opens the menu; in it the arrows move, confirm turns a value on or off, cancel, its button: or confirm on the button closes it",
                            :pad => "as the keys", :mouse => "a click opens and closes the menu; a click on a value turns it on or off",
                            :make => lambda { |options| Dropdown.new(options) },
                            :options => lambda do |params|
                              multi = params[:multi] == true
                              options = common(params).merge(:text => params[:placeholder].to_s, :multi => multi, :count_text => multi ? Dropdown::COUNT_TEXT : nil,
                                                             :columns => params[:columns] || :auto, :most_rows => params[:most_rows] || 8, :acts => true,
                                                             :narrows => false, :button => params[:button] && params[:button].to_s.upcase.to_sym)
                              options[:clear_text] = params[:clear_text].to_s if params[:clear_text]
                              options
                            end,
                            :wire => lambda do |part|
                              part.engine.on(:change) { |values| Layer.choices_changed(part, values) }
                              part.engine.on(:open) { Layer.dispatch(part, :on_open, []) }
                              part.engine.on(:close) { Layer.dispatch(part, :on_close, []) }
                            end,
                            :sync => lambda { |part, _wanted| Layer.sync_choices(part, :select_item) },
                            :synced => lambda { |part| Layer.follow_steer(part) })

        Declarations.define(:select_item,
                            :summary => "One value of a select.", :args => [:text], :inside => [:select], :common => false,
                            :params => { :text => { :type => :text, :doc => "what it says" },
                                         :icon => { :type => :icon, :doc => "an icon before its text" },
                                         :value => { :doc => "what stands for it in the select's bound values; its text by default" },
                                         :disabled => Declarations::COMMON[:disabled], :key => Declarations::COMMON[:key] },
                            :make => HELD, :options => NO_OPTIONS)

        Declarations.define(:list,
                            :summary => "Rows to pick from, one per item; it stays one part however many rows it has.", :args => [:items],
                            :params => { :items => { :type => :array, :default => [], :doc => "the items, one row each" },
                                         :bind => { :kind => :bind, :doc => "the state that holds the picked item, both ways" },
                                         :bind_index => { :kind => :bind, :doc => "the state that holds the picked row's place, both ways" },
                                         :text => { :kind => :item, :doc => "an item's row text; the item itself by default" },
                                         :icon => { :kind => :item, :doc => "an item's icon before its text: an IconSet index, a name UI.icon gave one, or { file: }" },
                                         :right => { :kind => :item, :doc => "what an item's row says at its right end, such as a count; on a card, at the end of its name line, such as its version" },
                                         :row => { :kind => :item,
                                                   :doc => "an item's whole row, a Hash of :text, :icon, :right (a text, or parts [{ text:, icon:, color: }]), :right_color, :color, :disabled, :tooltip, :item (a game item shown as the game's menus show it), :faint, " \
                                                           ":label (a caption in the system color in a column before its text, see label_width:), " \
                                                           ":check (true or false draws an on/off box at its start, filled while true, nil none; confirm and a click on the box tell on_submit), " \
                                                           ":note and :note_color (a small text after its text, from the column note_at:, dim unless told), " \
                                                           ":badge and :badge_color (a count above 0 on a plate at its end, \"9+\" above 9, true a dot, gold unless told; its room kept while it shows nothing), " \
                                                           "and :value with :less and :more (a value at its right end that Left and Right step, see on_side; less: false or more: false dims that arrow " \
                                                           "and buzzes a step that way, see on_refuse), :cells (its texts in the list's columns, see cells:); a row { heading: \"Online (2)\" } heads the rows under it " \
                                                           "across the whole row and the cursor passes over it; an item that is such a Hash is its own row" },
                                         :cells => { :type => :array,
                                                     :doc => "the widths of the columns the rows' cells: stand in, such as [52, 172, nil, 64], each in pixels or nil to share the room left; " \
                                                             "a cell is a text, { text:, color:, typo:, align: :start, :center or :end } or { icons: [...] }, each cut with \"...\" to its column; " \
                                                             "a cell's avatar: { character:, index:, face:, hue:, image:, shape:, size:, width:, height: } draws that avatar before its text, and the rows grow to the highest avatar and 2 px above and below it" },
                                         :describe => { :type => :bool, :default => false,
                                                        :doc => "a row of a game item (its :item) shows the item's description as its tooltip, unless the row has a tooltip: of its own" },
                                         :escapes => { :type => :bool, :default => false, :doc => "the rows draw the game's text codes" },
                                         :dense => { :type => :bool, :default => false, :doc => "lower rows, as high as the theme's dense row" },
                                         :click_picks => { :type => :bool, :default => false,
                                                           :doc => "a click on any row picks it at once, such as a card that opens its page; else a click on another row only moves the cursor there" },
                                         :leave_ends => { :type => :bool, :default => false,
                                                          :doc => "Up on its first row and Down on its last move the focus to the part above or below instead of wrapping, Up to the text field that steers it when one does, as a search over a list" },
                                         :empty => { :type => :text, :doc => "what it says without items" },
                                         :filter => { :kind => :item,
                                                      :doc => "keeps only the items it answers true for, such as those the toggles over the list allow; a row with search: false, such as a Remove row, always shows" },
                                         :no_match => { :type => :text, :doc => "a dim row that shows once filter: keeps none of the items it was asked about, such as \"No item matches\"" },
                                         :submit_to => { :type => :id,
                                                         :doc => "the id: of another part of its window that a pick moves the focus to once on_submit heard it, such as the slots of the character picked" },
                                         :note_at => { :type => :measure,
                                                       :doc => "where the rows' notes start, so they stand in one column: pixels from a row's left, or texts, of which the widest fits before the notes after a row's box, label and icon; " \
                                                               "half the row by default; a long text pushes its note on" },
                                         :label_width => { :type => :measure, :doc => "the width of the rows' label: column: pixels, or texts of which the widest sets it; the widest label of all rows by default, so a filter never moves it" },
                                         :most_rows => { :type => :int, :doc => "the most rows, with look: :cards lines of cards, before it scrolls; 6 rows or 2 lines" },
                                         :rows_shown => { :type => :count, :values => [:fill],
                                                          :doc => "instead of most_rows:, a count of rows that share its height between them, each at least as high as its own, such as 6 rows of mods that fill a box, " \
                                                                  "with look: :cards a count of lines that share its height:; :fill shows as many whole rows as the room its column leaves holds" },
                                         :toggles => { :kind => :item,
                                                       :doc => "an item's toggles, small on/off buttons at its row's end: an Array of { text:, on:, tooltip:, color: }, filled while on; a row Hash takes toggles: too" },
                                         :reorder => { :values => [false, :within_group], :default => false,
                                                       :doc => ":within_group lets the player move a row within its group by a drag" },
                                         :follow_pointer => { :type => :bool, :default => false, :hidden => true,
                                                              :doc => "the cursor follows the pointer, as the rows of a menu do; only the framework's own menus take it" },
                                         :move_hotkeys => { :type => :bool, :default => false, :hidden => true,
                                                            :doc => "with reorder:, the framework's hotkeys Move Up and Move Down (I and K) move the cursor's row too; only the framework's own mod list takes them" },
                                         :group => { :kind => :item, :doc => "an item's group, which reorder: keeps it within; by default the heading row above it" },
                                         :look => { :values => [:rows, :cards], :default => :rows,
                                                    :doc => ":cards shows each item as a card on a dark plate: its picture across its top, its text, then its lines" },
                                         :columns => { :type => :int, :doc => "how many rows or cards stand side by side; 3 for cards, else 1; it may change while the list shows, such as 2 cards across beside an open drawer, and the cursor stays on its item, scrolled into sight" },
                                         :spacing => { :values => (0..6).to_a, :doc => "room between two columns of rows or cards, 4 px a unit; 2 for rows, else the cards' own" },
                                         :picture => { :kind => :item, :doc => "an item's picture: { file:, blur:, label:, badge: { text:, color: } }, blur: for a picture that spoils the story, marked Spoiler unless label: says otherwise, " \
                                                                                     "badge: a small text on a dark plate at its top left, such as Installed; a card shows it across its top, a row at its left; a row Hash takes picture: too" },
                                         :picture_width => { :type => :int, :default => 96, :doc => "the width of a picture at a row's left, its height 16:9 of it; a row Hash takes picture_width: too" },
                                         :lines => { :kind => :item, :doc => "an item's lines under its text on a card or a row, such as [\"by Ana\", summary], on a card the last wrapped to two lines; a line is a text or { text:, color:, right: }, its right a text or parts [{ text:, icon:, color: }] at the line's end; a row Hash takes lines: too" } }.merge(BUTTONS).merge(HIGHLIGHT),
                            :events => { :change => "the item the cursor moved to", :submit => "the item picked; without on_submit: the pick goes to the nearest on_submit: around the list",
                                         :toggle => "the item and the place of its toggle the player pressed, from 0; the toggle shows its new state once the items say so",
                                         :reorder => "the item the player moved and its new place among the items; the rows show the new order once the items have it",
                                         :side => "Left or Right stepped the value of an item's row: the item and -1 or 1; the row shows its new value once the items say so",
                                         :refuse => "the item of a row with disabled: true the player tried to pick, or the item and -1 or 1 of a step of a dim arrow, which buzzed" }.merge(PAGE_EVENT),
                            :keys => "Up/Down, Page Up/Down and Home/End move; confirm picks; Left and Right walk a row's toggles and confirm presses one; " \
                                     "on a row with a value Left and Right step it and stay in the row at its end; " \
                                     "the keys skip a list without bind:, bind_index:, on_submit:, on_change:, on_toggle:, on_side: or reorder:, which shows rows to read: no cursor, and the pointer neither lights nor picks them, while their tooltips show",
                            :pad => "the d-pad moves; A picks",
                            :mouse => "a click moves the cursor there, and a click on the cursor's row picks it, with click_picks: a click on any row; a click on a row's box moves the cursor there and picks at once; a click on a toggle presses it; " \
                                      "a click on the left or right half of a row's value steps it; " \
                                      "with reorder:, a drag moves a row within its group; the wheel scrolls",
                            :make => lambda { |options| List.new(options) },
                            :options => lambda do |params|
                              items = list_items(params)
                              rows = list_rows(params, items)
                              cards = params[:look] == :cards
                              rows = cards ? card_rows(params, items, rows) : pictured_rows(params, items, rows)
                              reorder = params[:reorder] == :within_group
                              options = common(params).merge(pages(params)).merge(buttons(params)).merge(:rows => rows, :most_rows => params[:most_rows] || 6,
                                                                                  :acts => reorder || LIST_ACTIONS.any? { |name| !params[name].nil? },
                                                                                  :reorder => reorder, :move_hotkeys => reorder && params[:move_hotkeys] == true, :columns => params[:columns] || (cards ? 3 : 1),
                                                                                  :highlight => params[:highlight] && params[:highlight].to_s)
                              if cards
                                options.merge!(:row_height => card_height(params, rows), :most_rows => card_lines(params), :cell_gap => CARD_GAP)
                                options.delete(:height)
                              end
                              options[:cell_gap] = spacing(params[:spacing]) if params[:spacing]
                              options[:empty_text] = params[:empty].to_s if params[:empty]
                              options[:note_at] = params[:note_at] if params[:note_at]
                              options[:label_width] = params[:label_width] if params[:label_width]
                              options[:cells] = Array(params[:cells]) if params[:cells]
                              options[:row_height] = Theme.rows[1] if params[:dense]
                              options[:row_height] = lined_height(rows) if !cards && rows.any? { |row| lined_row?(row) }
                              tallest = avatar_height(rows)
                              options[:row_height] = [options[:row_height].to_i, tallest].max if tallest > 0
                              options.merge!(:rows_shown => params[:rows_shown], :share_room => params[:rows_shown].is_a?(Integer)) if params[:rows_shown] && !cards
                              options[:escapes] = true if params[:escapes]
                              options[:describe] = true if params[:describe]
                              options[:click_picks] = true if params[:click_picks]
                              options[:leave_ends] = true if params[:leave_ends]
                              options[:follow_pointer] = true if params[:follow_pointer]
                              options[:sides] = true if rows.any? { |row| row.is_a?(Hash) && !row[:value].nil? }
                              options
                            end,
                            :wire => lambda do |part|
                              part.engine.on(:change) { |_row, index| Layer.list_moved(part, index) }
                              part.engine.on(:side) { |_row, index, step| Layer.dispatch(part, :on_side, [Layer.item_at(part, index), step]) }
                              part.engine.on(:submit) { |_row, index| Layer.list_submitted(part, index) }
                              part.engine.on(:toggle) { |_row, index, toggle| Layer.dispatch(part, :on_toggle, [Layer.item_at(part, index), toggle]) }
                              part.engine.on(:refuse) { |_row, index, step| Layer.dispatch(part, :on_refuse, [Layer.item_at(part, index), step]) }
                              part.engine.on(:moved) { |_row, from, to| Layer.list_reordered(part, from, to) }
                              wire_page(part)
                            end)

        # The params UI.patch sets on a game window itself.
        GAME_WINDOW = {
          :opacity => { :type => :int, :doc => "how see-through the whole window draws, 0 to 255" },
          :anchor => { :values => ZONES, :doc => "the zone of the screen it sits in, flush with the screen's edges there" },
          :at => { :type => :point, :doc => "an exact spot [x, y] on the screen" },
          :width => { :type => :int, :doc => "its width in pixels" },
          :height => { :type => :int, :doc => "its height in pixels" },
          :theme => { :type => :theme, :doc => ":game leaves it undressed; a preset's name dresses it in that preset" },
          :movable => { :type => :bool, :doc => "true lets the player move it with Alt, where it then stays" }
        }

        # The looks a row of a game list window takes from the rows of a UI.patch of the window.
        GAME_ROW = {
          :name => { :type => :text, :doc => "the text the character's name in the row shows instead; a command's text is its name already" },
          :name_color => { :type => :color, :doc => "the color the character's name in the row draws in, or a command's text" },
          :grey => { :type => :bool, :doc => "true greys the row's texts, faces and icons" },
          :line_above => { :type => :color, :doc => "a line of that color along the row's top edge" }
        }

        Declarations.define(:command,
                            :summary => "A command of a game command window, such as the menu's, which a UI.patch of the window adds with "                                         "before, after, prepend or append; it works only there. Its id: is its symbol, which "                                         "other patches name as #id.", :args => [:text], :common => false,
                            :params => { :text => { :kind => :live, :type => :text, :doc => "what it says" },
                                         :id => { :type => :id, :required => true, :doc => "its symbol, unique in the window, such as :gear_compare" },
                                         :class => Declarations::COMMON[:class], :key => Declarations::COMMON[:key],
                                         :if => { :type => :gate, :doc => "asked each time the window makes its list; while it answers false the command takes no line" },
                                         :disabled => { :kind => :live, :type => :bool, :default => false, :doc => "true greys it out and a pick buzzes" },
                                         :visible => { :kind => :live, :type => :bool, :default => true, :doc => "false takes it off the list" },
                                         :icon => { :type => :int, :doc => "an IconSet index drawn before its text" },
                                         :badge => { :kind => :live, :doc => "a count above 0 on a plate at the end of its row, \"9+\" above 9; true shows a dot" },
                                         :badge_color => { :type => :color, :doc => "the badge's color, :gold by default" } },
                            :events => { :click => "nothing; the player picked it. The window takes the keys again once the windows its handler opened closed" },
                            :keys => "as the game's own commands: confirm picks it", :pad => "as the keys", :mouse => "a click picks it",
                            :make => lambda { |_options| raise MarkupError, "command goes only into a game command window, through a UI.patch of it such as UI.patch \"Window_MenuCommand\"" })

        Declarations.define(:key_help,
                            :summary => "A line that names keys as the player bound them and what they do, as the game's key help does: \"X or Numpad 0: close\".",
                            :params => { :entries => { :type => :array, :default => [],
                                                       :doc => "each { button:, key:, hotkey:, text: }: one of the game's buttons such as :B, a key's name or a hotkey, and what it does" },
                                         :auto => { :type => :bool, :default => true,
                                                    :doc => "adds the hotkeys and the game's buttons of the part in focus and of the parts it lies in, and the jump keys while a list with other parts around it is in focus, after its entries, or before its entry of cancel when that one ends them" } },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| KeyHelp.new(options) },
                            :options => lambda { |params| common(params).merge(:entries => Array(params[:entries])) },
                            :follow => lambda { |part| Layer.follow_key_help(part) })

        # The call of a help line's handle that says a text until the focus moves.
        SAY = { :args => "text",
                :doc => "says a text, such as what just happened, until the focus moves; said right after a part took the focus, until the focus leaves that part; nil clears it",
                :call => lambda { |part, text| part.engine.say(text.nil? ? nil : text.to_s) } }

        Declarations.define(:help_line,
                            :summary => "A small dim line that tells what the part the player is on does: what say said last, else the typing_help: " \
                                        "of a text field of its window while it types, else the help: of the part under the pointer, else the help: " \
                                        "of the focused part or the nearest part holding it.",
                            :params => { :lines => { :type => :int, :default => 2, :doc => "the most lines it wraps to; the last ends in ... and the whole text becomes its tooltip" } },
                            :actions => { :say => SAY },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| HelpLine.new(options) },
                            :options => lambda { |params| common(params).merge(:lines => params[:lines] || 2) })
      end
    end
  end
end
