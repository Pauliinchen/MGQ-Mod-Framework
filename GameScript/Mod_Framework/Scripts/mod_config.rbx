#----------------------------------------------------------------
#  mod_config.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#                            - Answered the rest of Remake's methods mods may call, from the framework's options
#                            - Left the way back from the rows to the list of the mods to the cancel rule
#                            - Took the rows a world sets out of Remake's methods
#      Paulinchen  2026-11-06: Kept the handle of the open Options > Mods on its scene, now that a handle is a plain object
#                            - Drew Options > Mods as a component of the UI layer over the options list, the mods with
#                              options or hotkeys on the left and the rows of the mod picked on the right
#      Paulinchen  2026-11-05: Showed the help in the game's help window through the options list's own way
#      Paulinchen  2026-11-01: Left the scene alone when F12 closes the Mod Config
#      Paulinchen  2026-10-31: Hid the options screen's windows the Mod Config covers while it is open
#                            - Lent the game's options only the rows whose :if allows
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Mod Config Remake's interface, which the framework keeps so mods made for it, and for the Mod
# Config Menu before it, work unchanged: its rows, NWConst::Config::MOD_CONTENTS (Options), the
# methods mods ask about (mod_stored?, groups, Keys.name and the rest) and the options screen's
# refresh_mod_config. Mod_Framework::ModConfig claims it.
module ModConfigRemake
end

module Mod_Framework
  # The game's Options > Mods in the place of Mod Config Remake: a Mods tab of the translation's
  # tabbed options screen, else a Mods row of the game's options, opens ModOptions over the options
  # list, the help in the game's help window. A button row calls the handler mods set on the
  # screen's @mod_config_window, as they did for the Mod Config Menu.
  #
  # A Mod Config Remake or Mod Config Menu still in the Patch folder gives way while the DLL works.
  # Without the DLL no window opens: Remake or the Menu keeps showing the rows if one is there,
  # else the rows the game's options can show go into them as the options screen opens.
  module ModConfig
    # The tab of the translation's tabbed options screen that holds Options > Mods.
    TAB = "Mods"

    # The id of the window of Options > Mods.
    ID = :mf_mod_options

    # The methods of ModConfigRemake that answer for the framework, each with the block it runs.
    FACADE = {
      :mod_stored? => lambda { |entry| Options.kept_by_mod?(entry) },
      :key_binding? => lambda { |entry| Options.key_row?(entry) },
      :values_of => lambda { |entry| Options.values_of(entry) },
      :value_of => lambda { |key| Options.value(key) },
      :index_of => lambda { |values, value| Options.index_of(values, value) },
      :current_value => lambda { |entry| Options.current(entry) },
      :entry_value => lambda { |entry| Options.current(entry) },
      :value_text => lambda { |entry| Options.value_text(entry) },
      :help_text => lambda { |entry| Options.help_text(entry) },
      :enabled? => lambda { |entry| Options.enabled?(entry) },
      :text => lambda { |text| Options.text(text) },
      :option_name => lambda { |entry| ModConfig.option_name(entry) },
      :key_owner => lambda { |code, except| ModConfig.key_owner(code, except) },
      :groups => lambda { ModConfig.groups },
      :show_help => lambda { |window, text| UI::Engine::OptionsList.show_in(window, text) },
    }

    # The methods of ModConfigRemake::Keys that answer for the framework.
    KEYS_FACADE = {
      :name => lambda { |code| Options::Keys.name(code) },
      :layout_name => lambda { |code| Options::Keys.name(code) },
      :game_key? => lambda { |code| Options::Keys.game_key?(code) },
      :down? => lambda { |code| UI::Engine::Key.down?(code.to_i) },
    }

    # The arrow before an indented row's name, which a row's name in a message leaves out.
    INDENTED_MARK = /\A\s*->\s*/

    # How often the rows were asked to show anew, which renders Options > Mods again.
    @redraws = 0

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "mod config"

    class << self
      # @return [Integer] How often the rows were asked to show anew.
      attr_reader :redraws
    end

    # Has ModConfigRemake answer through the framework, also over a Mod Config Remake that loaded
    # before or after it. ModConfigRemake::Keys, by which mods tell that key rows show, answers only
    # while the DLL works, since without it the game's options show no key row and a mod then
    # offers a row of values instead.
    def self.claim
      FACADE.each { |name, block| ::ModConfigRemake.define_singleton_method(name, &block) }
      return unless Mod_Framework.available?

      ::ModConfigRemake.const_set(:Keys, Module.new) unless ::ModConfigRemake.const_defined?(:Keys, false)
      KEYS_FACADE.each { |name, block| ::ModConfigRemake::Keys.define_singleton_method(name, &block) }
    end

    # Names a row for a message, as Mod Config Remake did: its name without its mod, followed by the
    # mod in brackets.
    #
    # @param row [Hash] The row.
    # @return [String] The name, such as "Show Gold (Camp Notes)"; a row of no mod by its name alone.
    def self.option_name(row)
      mod, members = Options.groups([Options.text(row[:name])]).first
      short = members.first[1].sub(INDENTED_MARK, "").strip
      mod == Options::GLOBAL ? short : "#{short} (#{mod})"
    end

    # Finds the key row of any mod that has a key already, as Mod Config Remake did.
    #
    # @param code [Integer] Windows' code of the key.
    # @param except [Hash] The row being bound, which may keep its own key.
    # @return [Hash, nil] The row, nil when no other row has the key.
    def self.key_owner(code, except)
      Options.rows.find { |row| !row.equal?(except) && Options.key_row?(row) && Options.current(row).to_i == code }
    end

    # Sorts the rows of Options > Mods by mod, as Mod Config Remake did.
    #
    # @return [Array<Array>] Each mod's name with its rows, [[name, [row, ...]], ...], Global first
    #   while it has rows.
    def self.groups
      rows = Options.rows
      Options.groups(rows.map { |row| Options.text(row[:name]) }).map do |name, members|
        [name, members.map { |place, _name| rows[place] }]
      end
    end

    # Takes the options screen once the game runs: with the DLL the Mods tab or row opens the
    # framework's window, and a Mod Config Remake in the Patch folder installs nothing; without it
    # the rows go into the game's options unless such a menu shows them.
    def self.start
      claim
      return fall_back unless Mod_Framework.available?

      ::ModConfigRemake.define_singleton_method(:install) { nil }
      ::ModConfigRemake.instance_variable_set(:@installed, true)
      return log("the game has no options screen, so Options > Mods opens nowhere") unless defined?(::Scene_Config)

      define_scene_methods
      link_tab_or_row
      log(remake? ? "Options > Mods opens the framework's window; the Mod Config Remake in the Patch folder gives way and can go" : "Options > Mods opens the framework's window")
    end

    # Opens Options > Mods over a window of the options screen, the help of the first mod in the
    # game's help window.
    #
    # @param scene [Scene_Config] The options screen.
    # @param covered [Window_Base] The window it lies over, the options list.
    # @return [Object, nil] The window's handle, nil when it did not open.
    def self.open(scene, covered)
      help = scene.instance_variable_get(:@help_window)
      log("#{ID} opens over the #{covered.class} at #{[covered.x, covered.y, covered.width, covered.height].join(', ')}")
      handle = UI.open(ModOptions, :scene => scene, :over => covered, :help_window => help)
      show_mod_help(help, Options.mods.first) if handle
      handle
    end

    # Finds the window of the options screen that lies at a place, which Options > Mods covers.
    #
    # @param windows [Array<Window, nil>] The screen's windows.
    # @param rect [Array<Integer>] The place's left, top, width and height.
    # @return [Window, nil] The first that lies within it, nil for none.
    def self.covered(windows, rect)
      x, y, width, height = rect
      windows.compact.find do |window|
        window.x >= x && window.y >= y && window.x + window.width <= x + width && window.y + window.height <= y + height
      end
    end

    # Shows in the game's help window what the list of the mods does for the mod under its cursor.
    #
    # @param window [Window_Help, nil] The help window, nil for none.
    # @param mod [String, nil] The mod's name, nil while no mod has options.
    def self.show_mod_help(window, mod)
      return unless window

      UI::Engine::OptionsList.show_in(window, mod ? format(ModOptions::TEXTS[:mod_help], mod) : ModOptions::TEXTS[:empty])
    end

    # Presses a button row through the handler a mod set on the screen's @mod_config_window.
    #
    # @param window [Window_Selectable, nil] The window that holds the handlers.
    # @param key [Symbol] The row's key.
    # @return [Boolean] Whether a handler pressed it.
    def self.press(window, key)
      return false unless window && window.handle?(key)

      window.call_handler(key)
      true
    rescue => e
      log("the button row #{key} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      true
    end

    # Has the rows show anew after a row changed or a button row was pressed, refreshing first the
    # window of the button rows' handlers, which mods made for the Mod Config Menu hook to show or
    # hide rows of theirs as their options change.
    #
    # @param window [Window_Selectable, nil] The window that holds the handlers.
    def self.redraw(window)
      begin
        window.refresh if window && window.respond_to?(:refresh)
      rescue => e
        log("refreshing the window of the button rows' handlers failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end
      @redraws += 1
    end

    # The rows lent into the game's options, taken back before they are lent again.
    @lent = []

    # Puts the rows the game's options can show into them, without the DLL and without a Mod
    # Config Remake or Mod Config Menu: rows of values in DATA and button rows, each once. The rows
    # lent before are taken back first, so a row a mod hid since leaves.
    def self.lend_rows
      config = ::NWConst::Config
      config::CONTENTS.reject! { |row| @lent.any? { |each| each.equal?(row) } }
      lent = Options.shown_rows.select { |row| shown_by_game?(row) && !config::CONTENTS.any? { |each| each.equal?(row) } }
      lent.each { |row| config::CONTENTS.insert(-2, row) }
      @lent = lent
      left = Options.rows.reject { |row| shown_by_game?(row) }.map { |row| row[:key] }
      log_once([:left_out, left], "without the DLL the game's options cannot show these rows of Options > Mods: #{left.join(', ')}") unless left.empty?
    end

    # Tells whether a Mod Config Remake or a Mod Config Menu is in the Patch folder.
    #
    # @return [Boolean] Whether one is.
    def self.remake?
      ::ModConfigRemake.const_defined?(:TAB, false) || (defined?(::Window_ModConfig) && !::Window_ModConfig.const_defined?(:FRAMEWORK, false)) ? true : false
    end

    # Leaves Options > Mods to a Mod Config Remake or Mod Config Menu in the Patch folder, else puts
    # the rows into the game's options as its screen opens, without the row that opens the Mod
    # Config.
    def self.fall_back
      return log("without the DLL the Mod Config Remake or Mod Config Menu in the Patch folder shows the rows") if remake?
      return unless defined?(::NWConst::Config::CONTENTS)

      ::NWConst::Config::CONTENTS.reject! { |row| row[:key] == Options::ENTRY_KEY }
      Hooks.before(::Scene_Config, :start, "Mod Framework mod config", self) { Mod_Framework::ModConfig.lend_rows } if defined?(::Scene_Config)
      log("without the DLL the rows of Options > Mods go into the game's options")
    end
    private_class_method :fall_back

    # Tells whether the game's options can show a row: a row of values whose values and names are
    # in DATA and DATA_TEXT, or a button row.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether they can.
    def self.shown_by_game?(row)
      return false if Options.key_row?(row) || row[:values] || Options.kept_by_mod?(row)
      return true unless row[:sub]

      config = ::NWConst::Config
      config::DATA.key?(row[:key]) && config::DATA_TEXT.key?(row[:key]) ? true : false
    end
    private_class_method :shown_by_game?

    # Defines the options screen's methods of Options > Mods, which mods made for the Mod Config
    # Menu call and hook: the hidden window of the button rows' handlers, opening and closing the
    # window, and refresh_mod_config.
    def self.define_scene_methods
      ::Scene_Config.class_eval do
        # Makes the hidden window mods set the handlers of their button rows on, once.
        define_method(:create_mod_config_window) do
          return if @mod_config_window

          begin
            @mod_config_window = ::Window_ModConfig.new
            @mod_config_window.viewport = @viewport if @viewport
          rescue => e
            Mod_Framework::ModConfig.log("making the window of the button rows' handlers FAILED, so button rows buzz: #{Mod_Framework::Logging.failure(e)}")
          end
        end

        # Opens Options > Mods over the options' list.
        define_method(:start_mod_config) do
          open_mod_config(@config_window.x, @config_window.y, @config_window.width, @config_window.height)
        end

        # Opens Options > Mods over the window of the screen that lies at a place, the options' list
        # unless another lies there, the options' windows waiting meanwhile.
        define_method(:open_mod_config) do |x, y, width, height|
          create_mod_config_window
          @config_window.deactivate if @config_window
          @item_window.deactivate if @item_window
          covered = Mod_Framework::ModConfig.covered([@item_window, @config_window], [x, y, width, height]) || @config_window
          @mod_config = Mod_Framework::ModConfig.open(self, covered)
          end_mod_config unless @mod_config
        end

        # Draws the rows of Options > Mods anew, as a mod asks after one of its rows changed others.
        define_method(:refresh_mod_config) do
          Mod_Framework::ModConfig.redraw(nil) if @mod_config && @mod_config.open?
        end

        # Goes back to the options once Options > Mods closed: they take the keys again and the
        # help window tells their row once more.
        define_method(:end_mod_config) do
          root = @mod_config
          @mod_config = nil
          root.close if root && root.open?
          next unless @config_window

          @config_window.activate
          @config_window.call_update_help if @config_window.respond_to?(:call_update_help)
        end
      end
      define_handler_window unless defined?(::Window_ModConfig)
    end
    private_class_method :define_scene_methods

    # Defines Window_ModConfig, the hidden window that holds the handlers of the button rows, where
    # no Mod Config Menu or Mod Config Remake defined it.
    def self.define_handler_window
      Object.class_eval <<-RUBY
        # The handlers of the button rows of Options > Mods, which mods set as they did on the Mod
        # Config Menu's window; it never shows.
        class Window_ModConfig < Window_Selectable
          # Mods made for the Mod Config Menu reopen this window and read DATA or MOD_CONTENTS
          # unqualified.
          include NWConst::Config

          # Tells that the framework defined it.
          FRAMEWORK = true

          # Makes the window, hidden.
          def initialize
            super(0, 0, 32, 32)
            deactivate
            hide
          end

          # Keeps its place, which mods made for the Mod Config Menu ask it to measure anew.
          def calculate_and_resize
          end
        end
      RUBY
    end
    private_class_method :define_handler_window

    # Has the Mods tab of the tabbed options screen, else the Mods row of the game's options, open
    # Options > Mods, and makes the handlers' window as the options' windows are made, before the
    # hooks mods put on the screen's start set their handlers on it.
    def self.link_tab_or_row
      Hooks.after(::Scene_Config, :create_config_window, "Mod Framework mod config", self) do
        create_mod_config_window
        @config_window.set_handler(Options::ENTRY_KEY, method(:start_mod_config)) unless defined?(::Window_BetterConfigTabs)
      end
      return unless defined?(::Window_BetterConfigTabs)

      entry = ::NWConst::Config::CONTENTS.find { |row| row[:key] == Options::ENTRY_KEY }
      entry[:group] = TAB if entry
      Hooks.around(::Scene_Config, :on_config_tab_ok, "Mod Framework mod config", self) do |scene, args, original|
        tab = scene.instance_variable_get(:@config_window).current_tab
        next original.call(*args) unless tab && tab[:name] == TAB

        items = scene.instance_variable_get(:@item_window)
        items.clear_items
        scene.open_mod_config(items.x, items.y, items.width, items.height)
      end
    end
    private_class_method :link_tab_or_row

    claim
    Run.on_start("mod config") { Mod_Framework::ModConfig.start }
  end

  # The game's Options > Mods, a window of the UI layer that lies exactly over the options list:
  # the mods that have options or hotkeys on the left, the framework's own first, and the rows of
  # the mod under the cursor on the right at once. Confirm or Right goes into the rows, cancel or
  # Left on a row without a value comes back to the mod, and cancel there closes the window and
  # gives the options list the keys back. The help shows in the game's help window: what the list
  # of the mods does while it has the focus, the help of the row under the cursor while the rows
  # have it.
  class ModOptions < UI::Component
    # The texts it shows, by what they say.
    TEXTS = {
      :empty => "No mod has options yet.",
      :mod_help => "The options and hotkeys of %s.\r\nConfirm to change them."
    }

    # The width of the list of the mods: room for a long mod name, the rest of the options list's
    # 640 for the rows, their names and values.
    LIST_WIDTH = 200

    # The options screen.
    param :scene

    # The window it lies over, the options list.
    param :over

    # The game's help window, nil for none.
    param :help_window, nil

    # The name of the mod under the cursor of the list of the mods.
    state(:picked) { Options.mods.first }

    # Whether the rows of the mod have the focus.
    state :inside, false

    # A row a mod asked to show anew renders it again.
    watch { ModConfig.redraws }

    # Describes the window: the list of the mods beside the rows of the mod picked.
    def render
      mods = Options.mods
      shown = mods.include?(picked) ? picked : mods.first
      window nil, id: ModConfig::ID, cover: over, movable: false, on_close: ->(why) { closed(why) } do
        stack row: true, height: :fill do
          list mods, bind: :picked, empty: TEXTS[:empty], id: :mf_mod_options_mods, submit_to: :mf_mod_options_list, width: LIST_WIDTH, align_self: :stretch,
                     rows_shown: :fill, autofocus: true, on_change: ->(mod) { pointed(mod) }
          options_list mod: shown.to_s, headings: false, help_line: false, help_window: inside ? help_window : nil, id: :mf_mod_options_list,
                       width: :fill, align_self: :stretch, visible: !shown.nil?, on_change: ->(key, value) { changed(key, value) }, on_press: ->(key) { pressed(key) },
                       on_enter: -> { self.inside = true }, on_leave: -> { left }
        end
      end
    end

    private

    # Follows the cursor of the list of the mods: the help names the mod.
    #
    # @param mod [String, nil] The mod's name.
    def pointed(mod)
      ModConfig.show_mod_help(help_window, mod) unless inside
    end

    # Follows the focus leaving the rows: the help names the mod again.
    def left
      self.inside = false
      ModConfig.show_mod_help(help_window, picked)
    end

    # Logs a row the player changed and has the rows show anew.
    #
    # @param key [Symbol] The row's key.
    # @param value [Object] Its value now, a hotkey row's key code.
    def changed(key, value)
      ModConfig.log("#{ModConfig::ID} changed #{key} to #{value.inspect}")
      ModConfig.redraw(handlers)
    end

    # Presses a button row through the handler a mod set, and has the rows show anew.
    #
    # @param key [Symbol] The row's key.
    # @return [Boolean] Whether a handler pressed it.
    def pressed(key)
      done = ModConfig.press(handlers, key)
      ModConfig.log(done ? "#{ModConfig::ID} pressed the button row #{key}" : "#{ModConfig::ID} refused the button row #{key}: no mod set a handler for it")
      ModConfig.redraw(handlers) if done
      done
    end

    # Finds the window the mods set the handlers of their button rows on.
    #
    # @return [Window_Selectable, nil] The window, nil for none.
    def handlers
      scene.instance_variable_get(:@mod_config_window)
    end

    # Gives the options screen the keys back once the window closed; F12 changes nothing.
    #
    # @param why [Symbol, String] Why it closed.
    def closed(why)
      ModConfig.log("#{ModConfig::ID} closed (#{why})")
      scene.end_mod_config unless why == :reset
    end
  end
end
