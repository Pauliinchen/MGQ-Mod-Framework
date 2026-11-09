#----------------------------------------------------------------
#  game_mouse.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Wrote the help of the Options row as one text, which the help window breaks to its width
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-30: Logged a missing row of the Mod Config without naming Mod Config Remake
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The mouse on the game's own windows: the pointer picks the row under it, the wheel scrolls a
      # list, a click confirms the row under the pointer and a right click cancels, each inside the
      # game's own gates, so whether a row can be picked and which sound plays stay the window's.
      #
      # The hooks go onto every class that defines process_handling or process_cursor_move itself,
      # since many game windows define them again without calling the one of Window_Selectable. They
      # act only while the pointer is on none of the framework's roots, no root holds the buttons, the
      # player does not arrange the boxes with Alt and Mouse on Game Windows is On.
      #
      # It must never interrupt the game, so every entry point rescues.
      module GameMouse
        # The setting that keeps whether the mouse works the game's windows, 1 or 0.
        SETTING = "ui_game_mouse"

        # The Options > Mods row's key.
        OPTION = :mf_ui_game_mouse

        # The Options > Mods row's name.
        OPTION_NAME = "Mouse on Game Windows"

        # The Options > Mods row's help.
        OPTION_HELP = "On: the pointer picks the rows of the game's windows, " \
                      "a click confirms, a right click cancels. Off: keys only."

        # The Options > Mods row's values.
        ON = "On"
        OFF = "Off"

        # Who the hooks are registered by.
        TAG = "Mod Framework game mouse"

        # The game's windows the mouse leaves alone, whose rows are no list to pick from: the name
        # input, the number input and the shop's number.
        OFF_LIST = %w[Window_NameInput Window_NumberInput Window_ShopNumber]

        # The most rows a click looks through one by one; a longer list is searched only where it
        # shows.
        SCAN_ALL = 256

        # Rows a notch of the wheel scrolls a game list.
        WHEEL_ROWS = 1

        # Whether the mouse works the game's windows; nil until read from the settings.
        @on = nil

        # The frame each click was last taken in, so one click presses for one window.
        @taken = {}

        # The classes of OFF_LIST the game has.
        @off = []

        # The window whose update presses buttons for a click on it, with those buttons.
        @pressing = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "game mouse"

        # Tells whether the mouse works the game's windows, as Mouse on Game Windows says.
        #
        # @return [Boolean] Whether it does; on until the player turns it off.
        def self.on?
          @on = Settings.setting(SETTING).to_s != "0" if @on.nil?
          @on
        end

        # Turns the mouse on the game's windows on or off and keeps it in the settings.
        #
        # @param on [Boolean] Whether the mouse works them.
        def self.turn(on)
          @on = on
          kept = Settings.store(SETTING, on ? 1 : 0)
          log("the mouse on the game's windows is #{on ? 'on' : 'off'}#{kept ? '' : ', not kept'}")
        end

        # Tells whether the mouse may work a game window now: it is on, the game is in front, the
        # pointer is on no root of the framework, no root holds the buttons and the player does not
        # arrange the boxes.
        #
        # @return [Boolean] Whether it may.
        def self.free?
          on? && Tick.in_front? && Tree.over.nil? && !Capture.on? && !Mouse.arranging?
        end

        # Tells the buttons a click on an adopted window that reads Input itself presses for its
        # update, as its :click and :right_click say; each click presses for one window.
        #
        # @param window [Window_Base] The game window.
        # @param rules [Array<Adopted>] The adoptions that apply to it.
        # @return [Array<Symbol>] The game's buttons, empty for none.
        def self.clicks_on(window, rules)
          position = Mouse.position
          return [] unless position && free? && shown?(window) && inside?(window, position)

          buttons = []
          rules.each do |rule|
            next unless rule.window.equal?(window) && rule.mouse != false

            buttons << rule.click if rule.click && Mouse.clicked? && take(:left)
            buttons << rule.right_click if rule.right_click && Mouse.right_clicked? && take(:right)
          end
          buttons.uniq
        rescue => e
          log_once([:clicks, window.class, e.class], "a click on a #{window.class} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          []
        end

        # Runs a game window's update with buttons pressed for a click on it; the windows it updates
        # in turn, such as a message's choices, do not see them.
        #
        # @param window [Window_Base] The game window.
        # @param buttons [Array<Symbol>] The game's buttons.
        # @yield Runs the update.
        # @return [Object] What the update returns.
        def self.pressing(window, buttons)
          outer = @pressing
          @pressing = [window, buttons]
          buttons.each { |button| Buttons.press(button) }
          yield
        ensure
          buttons.each { |button| Buttons.release(button) }
          @pressing = outer
        end

        # Runs a game window's process_handling with confirm pressed for a click on one of its rows,
        # or cancel for a right click, while it is open and active; the window's own gates decide what
        # the press does.
        #
        # @param window [Window_Selectable] The game window.
        # @param original [Proc] Runs process_handling.
        # @return [Object] What it returns.
        def self.handling(window, original)
          return original.call if window.instance_variable_get(:@mf_handling)
          return without_foreign_presses(window) { original.call } if @pressing && !@pressing[0].equal?(window)

          button = press_for(window)
          return original.call unless button

          window.instance_variable_set(:@mf_handling, true)
          Buttons.press(button)
          begin
            original.call
          ensure
            Buttons.release(button)
            window.instance_variable_set(:@mf_handling, false)
          end
        end

        # Follows the pointer on a game list before it moves its cursor, once a frame: the wheel
        # scrolls it with the cursor kept in sight, and a pointer that moved onto a row picks it
        # without a sound.
        #
        # @param window [Window_Selectable] The game window.
        def self.cursor_move(window)
          return unless free? && selectable?(window) && window.cursor_movable?
          return if window.instance_variable_get(:@mf_mouse_frame) == Key.frame

          window.instance_variable_set(:@mf_mouse_frame, Key.frame)
          position = Mouse.position
          return unless position && inside?(window, position)

          scroll(window, Mouse.wheel) if Mouse.wheel != 0
          return unless Mouse.moved?

          index = index_at(window, position[0], position[1])
          window.select(index) if index && index != window.index
        rescue => e
          log_once([:cursor, window.class, e.class], "the pointer on a #{window.class} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Finds the row of a game list under a point of the screen, among the rows inside its
        # contents.
        #
        # @param window [Window_Selectable] The game window.
        # @param x [Integer] The point's left on the screen.
        # @param y [Integer] Its top.
        # @return [Integer, nil] The row, nil for none.
        def self.index_at(window, x, y)
          left, top = UI.window_origin(window)
          left += window.padding
          top += window.padding
          count = window.item_max
          first, last = count <= SCAN_ALL ? [0, count] : shown_rows(window)
          (first...last).each do |index|
            rect = window.item_rect(index)
            rx = left + rect.x - window.ox
            ry = top + rect.y - window.oy
            return index if x >= rx && x < rx + rect.width && y >= ry && y < ry + rect.height
          end
          nil
        end

        # Hooks every class that defines process_handling or process_cursor_move itself, offers the
        # row in Options > Mods, once the game runs with the DLL.
        def self.start
          @off = OFF_LIST.select { |name| Object.const_defined?(name) }.map { |name| Object.const_get(name) }
          handlers = owners(:process_handling)
          movers = owners(:process_cursor_move)
          handlers.each do |owner|
            Hooks.around(owner, :process_handling, TAG) { |window, _args, original| Mod_Framework::UI::Engine::GameMouse.handling(window, original) }
          end
          movers.each { |owner| Hooks.before(owner, :process_cursor_move, TAG) { Mod_Framework::UI::Engine::GameMouse.cursor_move(self) } }
          log("the mouse works the game's windows: #{handlers.size} classes handle input, #{movers.size} move cursors, #{@off.size} are left alone")
          add_option
        end

        # Lists the owners of a method among Window_Selectable and its subclasses.
        #
        # @param name [Symbol] The method.
        # @return [Array<Module>] The classes or modules that define it.
        def self.owners(name)
          classes = [::Window_Selectable]
          ObjectSpace.each_object(Class) { |klass| classes << klass if klass < ::Window_Selectable }
          classes.map { |klass| klass.instance_method(name).owner }.uniq
        rescue => e
          log("looking for the game's windows FAILED, so only Window_Selectable follows the mouse: #{Logging.failure(e)}")
          [::Window_Selectable]
        end

        # Offers Mouse on Game Windows as a row of Options > Mods.
        def self.add_option
          added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, lambda { [ON, OFF] },
                               lambda { on? ? ON : OFF }, lambda { |value| turn(value == ON) })
          log(added ? "added the mouse on game windows to Options > Mods" : "no mouse row in Options > Mods, see the options lines")
        end

        # Tells the button a click presses in a game list's process_handling: confirm for a left
        # click on a row, which it picks first, cancel for a right click anywhere.
        #
        # @param window [Window_Selectable] The game window.
        # @return [Symbol, nil] :C, :B or nil.
        def self.press_for(window)
          return nil unless free? && selectable?(window)

          position = Mouse.position
          if Mouse.clicked? && position && inside?(window, position)
            index = index_at(window, position[0], position[1])
            if index && take(:left)
              window.select(index) if index != window.index
              return :C
            end
          end
          Mouse.right_clicked? && take(:right) ? :B : nil
        rescue => e
          log_once([:press, window.class, e.class], "a click on a #{window.class} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          nil
        end

        # Runs a block with the buttons another window's click pressed taken off, so a click on one
        # window never presses for another.
        #
        # @param _window [Window_Selectable] The game window the block runs for.
        # @yield Runs process_handling.
        # @return [Object] What it returns.
        def self.without_foreign_presses(_window)
          held = @pressing[1].select { |button| Buttons.marked?(button) }
          held.each { |button| Buttons.release(button) }
          yield
        ensure
          held.each { |button| Buttons.press(button) } if held
        end

        # Tells whether a game list takes the mouse: shown whole, active, not left alone by the off
        # list or its adoption, its cursor neither fixed nor on every row.
        #
        # @param window [Window_Selectable] The game window.
        # @return [Boolean] Whether it does.
        def self.selectable?(window)
          return false unless shown?(window) && window.active
          return false if window.instance_variable_get(:@mf_mouse_off)
          return false if window.cursor_fix || window.cursor_all

          !@off.any? { |klass| window.is_a?(klass) }
        end

        # Tells whether a game window shows whole.
        #
        # @param window [Window_Base] The game window.
        # @return [Boolean] Whether it does.
        def self.shown?(window)
          !window.disposed? && window.visible && window.openness >= 255
        end

        # Tells whether a point of the screen lies on a game window.
        #
        # @param window [Window_Base] The game window.
        # @param position [Array<Integer>] The point.
        # @return [Boolean] Whether it does.
        def self.inside?(window, position)
          left, top = UI.window_origin(window)
          position[0] >= left && position[1] >= top && position[0] < left + window.width && position[1] < top + window.height
        end

        # Takes a click for one window, once per frame.
        #
        # @param click [Symbol] :left or :right.
        # @return [Boolean] Whether it was still free in this frame.
        def self.take(click)
          return false if @taken[click] == Key.frame

          @taken[click] = Key.frame
          true
        end

        # Tells the rows of a long game list that show, as the first and the one after the last.
        #
        # @param window [Window_Selectable] The game window.
        # @return [Array<Integer>] The rows.
        def self.shown_rows(window)
          columns = window.col_max
          first = window.top_row * columns
          [first, [first + (window.page_row_max + 1) * columns, window.item_max].min]
        end

        # Scrolls a game list by the wheel's notches, its cursor kept among the rows that show.
        #
        # @param window [Window_Selectable] The game window.
        # @param notches [Integer] The notches, positive away from the player.
        def self.scroll(window, notches)
          last_top = [window.row_max - window.page_row_max, 0].max
          window.top_row = [[window.top_row - notches * WHEEL_ROWS, 0].max, last_top].min
          columns = window.col_max
          first = window.top_row * columns
          last = [(window.top_row + window.page_row_max) * columns - 1, window.item_max - 1].min
          window.select(first) if window.index < first
          window.select(last) if window.index > last
        end
        private_class_method :press_for, :without_foreign_presses, :selectable?, :shown?, :inside?, :take, :shown_rows, :scroll

        Run.on_start("game mouse", :dll => true) { Mod_Framework::UI::Engine::GameMouse.start }
      end
    end
  end
end
