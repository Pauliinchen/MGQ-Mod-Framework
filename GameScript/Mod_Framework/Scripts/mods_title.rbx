#----------------------------------------------------------------
#  mods_title.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Marked a greyed row of the Mods box with :disabled
#                            - Opened the Mod List from List without a tab, and the Mod Configuration from Configuration
#      Paulinchen  2026-11-06: Adopted through Adopt.adopt, since UI.adopt is gone
#                            - Opened the Mods screen of the UI layer on its tab by name
#                            - Drew the title's Mods box as a window of the UI layer joined to the title's commands
#      Paulinchen  2026-11-05: Named the id of the box's list, which the mods' rows go into
#      Paulinchen  2026-11-04: Gave the Mods box the id mf_title_mods, which a UI.patch names it by
#      Paulinchen  2026-11-03: Said a mod did not load last time when it failed in an earlier game session
#      Paulinchen  2026-11-01: Showed Browser, List and Configuration in a Mods box beside the title commands
#                            - Answered the screen a command of the box opened, which gives the box the keys again as it closes
#      Paulinchen  2026-10-30: Showed the dot on Mods while two mods that are on do not work together
#                            - Counted the framework's own update on Mod browser and named the updates in its tooltip
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The title's Mods box: a window of the UI layer left of the title's commands, centered on them
    # and sharing one cursor with them, with the heading Mods above Browser, List and Configuration,
    # and the rows mods put into its list. Browser counts the updates, the framework's own included,
    # and List shows a dot while a mod failed to load or a mod that is on misses a requirement or
    # does not work with another one on. Without the DLL there are no screens and no box, and the
    # mods' commands for it show nowhere.
    module Title
      # The heading, the names of the commands, and the troubles a mod can have.
      TEXTS = { :heading => "Mods", :browser => "Browser", :list => "List", :config => "Configuration",
                :failed => "%s did not load", :failed_before => "%s did not load last time", :needs => "%s needs %s", :conflicts => "%s conflicts with %s" }

      # The id a UI.patch names the box by.
      ID = :mf_title_mods

      # The id of the box's list, whose rows UI.patch changes, where the mods' title commands with
      # :in => :mods go as rows {:id, :text, :disabled, :badge, :badge_color, :icon, :open}.
      LIST_ID = :mf_title_mods_list

      # The least width of the box, the untranslated game's title width, so it never looks thinner
      # than the title's commands.
      LEAST_WIDTH = 160

      # The room the game's command rows keep at both ends of a text together, and the padding of
      # the game's windows on each side.
      ROW_ROOM = 8
      PADDING = 12

      # The step the box's width is rounded up to.
      WIDTH_STEP = 4

      # The room the box keeps from the screen's top and bottom, and the height of its rows.
      SCREEN_MARGIN = 8
      ROW_HEIGHT = 24

      # How often what the box shows changed, which renders it again.
      @serial = 0

      # Whether the box comes onto the title.
      @installed = false

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods title"

      # Has the Mods box come onto every title, once, as the framework boots with the DLL and its
      # list of mods, which the screens need; without them no box comes.
      def self.install
        return if @installed || !defined?(::Window_TitleCommand) || !screens?

        @installed = true
        Mod_Framework.bridge.on(FETCHED_TOPIC) { |_event| Mod_Framework::Mods::Title.show_badges }
        Run.on_start(LOG_TAG, :dll => true) { Mod_Framework::Mods::Title.follow_titles }
      rescue => e
        log("the title's Mods box could not be added: #{Logging.failure(e)}")
      end

      # Opens the box at each title once the title has started, and keeps the title's commands
      # around their middle as mods add commands to them.
      def self.follow_titles
        return unless defined?(::Scene_Base) && ::Scene_Base.method_defined?(:post_start)

        UI::Engine::Adopt.adopt(::Window_TitleCommand, :keep_center => true)
        Hooks.after(::Scene_Base, :post_start, LOG_TAG) { Mod_Framework::Mods::Title.open_box if defined?(::Scene_Title) && is_a?(::Scene_Title) }
      end

      # Opens the box beside the title's commands, which closes with the title's scene.
      #
      # @return [Object, nil] Its handle, nil when it did not open.
      def self.open_box
        return nil unless screens?

        handle = UI.open(TitleModsBox)
        log(handle ? "opened #{ID} beside the title's commands" : "#{ID} did not open")
        handle
      rescue => e
        log("#{ID} did not open: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        nil
      end

      # Tells how often what the box shows changed.
      #
      # @return [Integer] The count.
      def self.serial
        @serial
      end

      # Has the box draw its commands anew with their badges, such as once the fetch ended or a
      # screen it opened closed.
      def self.show_badges
        @serial += 1
      end

      # Tells whether the screens can open: the DLL works and lists the mods.
      #
      # @return [Boolean] Whether they can.
      def self.screens?
        Mod_Framework.available? && Mods.state.is_a?(Hash)
      end

      # Tells whether the mod browser can open.
      #
      # @return [Boolean] Whether it can.
      def self.browser?
        Mods.respond_to?(:open_browser)
      end

      # Counts the updates for Browser's badge, once the website was fetched.
      #
      # @return [Integer] The count; 0 while the fetch runs.
      def self.update_count
        updates_of(Updates.ask(false)).size
      end

      # Tells whether List shows its dot.
      #
      # @return [Boolean] Whether a mod has trouble, see trouble_of.
      def self.trouble?
        trouble_of(Mods.state) ? true : false
      end

      # Takes the updates, once the website was fetched.
      #
      # @param answer [Hash, nil] The updates, see Updates.ask.
      # @return [Array<Hash>] The updates; none while the fetch runs.
      def self.updates_of(answer)
        return [] unless answer.is_a?(Hash) && !answer["fetching"]

        Array(answer["updates"])
      end

      # Names the first mod that is on and failed to load, misses a requirement or does not work
      # with another mod that is on.
      #
      # @param state [Hash, nil] The installed mods, see Mods.state.
      # @return [String, nil] Such as "Map Display needs Level Cap"; nil for none.
      def self.trouble_of(state)
        return nil unless state.is_a?(Hash)

        Array(state["mods"]).each do |mod|
          next unless mod["on"] && mod["tag"]
          return format(TEXTS[Mods.failed_now?(mod["name"]) ? :failed : :failed_before], mod["title"]) if Mods.failed_last(mod["name"])

          need = Array(mod["needs"]).find { |each| %w[off missing].include?(each[2]) }
          return format(TEXTS[:needs], mod["title"], need[0]) if need

          conflict = Array(mod["conflicts"]).find { |each| each[2] }
          return format(TEXTS[:conflicts], mod["title"], conflict[0]) if conflict
        end
        nil
      end

      # Tells the box's commands: Browser with the count of the updates, greyed while the browser
      # cannot open, List with its dot while a mod has trouble, and Configuration.
      #
      # @return [Array<Hash>] Each command {:id, :text, :disabled, :badge, :badge_color, :open}.
      def self.commands
        [{ :id => :mods_browser, :text => TEXTS[:browser], :disabled => !browser?, :badge => update_count, :open => lambda { Mod_Framework::Mods::Title.open_browser } },
         { :id => :mods_list, :text => TEXTS[:list], :badge => trouble?, :badge_color => :warning, :open => lambda { Mod_Framework::Mods::Title.open_mods } },
         { :id => :mods_config, :text => TEXTS[:config], :open => lambda { Mod_Framework::Mods::Title.open_config } }]
      end

      # Tells a command's row: its text, its icon, whether it can be picked, and its badge.
      #
      # @param command [Hash] The command, see commands.
      # @return [Hash] The row.
      def self.row_of(command)
        row = { :text => command[:text].to_s, :disabled => command[:disabled] == true }
        [:icon, :badge, :badge_color].each { |key| row[key] = command[key] if command.key?(key) }
        row
      end

      # Tells the box's width: its widest line with the room of its badge and icon, the rows' room
      # and the window's padding, rounded up to WIDTH_STEP, at least LEAST_WIDTH and at most the
      # screen's, as the game sizes its command windows.
      #
      # @param commands [Array<Hash>] The commands, see commands.
      # @return [Integer] The width.
      def self.width_of(commands)
        bitmap = Bitmap.new(1, 1)
        widths = commands.map do |command|
          UI.text_width(bitmap, command[:text]) + (command[:icon] ? UI::ICON_STEP : 0) + (command.key?(:badge) ? UI::Engine::Badge::ROOM : 0)
        end
        widths << UI.text_width(bitmap, TEXTS[:heading])
        width = (widths.max + ROW_ROOM + PADDING * 2 + WIDTH_STEP - 1) / WIDTH_STEP * WIDTH_STEP
        [[width, LEAST_WIDTH].max, Graphics.width].min
      ensure
        bitmap.dispose if bitmap
      end

      # Tells the most rows the box's list shows before it scrolls: as many as fit the screen under
      # the heading, the box kept SCREEN_MARGIN inside the screen.
      #
      # @return [Integer] The rows.
      def self.most_rows
        [(Graphics.height - SCREEN_MARGIN * 2 - PADDING * 2) / ROW_HEIGHT - 1, 1].max
      end

      # Runs a command the player picked in the box, logged with its id.
      #
      # @param command [Hash] The command, see commands.
      # @return [Object] What its open answered.
      def self.pick(command)
        log("#{command[:id]} picked in #{ID}")
        command[:open].call
      end

      # Opens the Mod List from the box; the box played the confirm sound.
      #
      # @return [Object, nil] The menu's handle, nil when it did not open.
      def self.open_mods
        opening { Screen.open(true) }
      end

      # Opens the Mod Configuration from the box; the box played the confirm sound.
      #
      # @return [Object, nil] The menu's handle, nil when it did not open.
      def self.open_config
        opening { Screen.open_config(true) }
      end

      # Opens the mod browser from the box; the box played the confirm sound.
      #
      # @return [UI::Engine::Window, nil] The browser, nil when it did not open.
      def self.open_browser
        opening { browser? && Mods.open_browser(true) }
      end

      # Opens a screen over the title, which hides the box and the title's commands until it
      # closes; one that did not open is logged.
      #
      # @yield Opens the screen.
      # @yieldreturn [Object, nil] The screen or its handle, nil when it did not open.
      # @return [Object, nil] The screen or its handle.
      def self.opening
        screen = yield
        log("a screen of #{ID} did not open") unless screen
        screen || nil
      end
    end

    # The title's Mods box on the UI layer, left of the title's commands and joined to them: the
    # heading Mods in the system color, then the box's commands and the rows mods put into its
    # list, in the game's own window look.
    class TitleModsBox < UI::Component
      # What the box shows changes with the fetch and as the screens it opened close.
      watch { Mod_Framework::Mods::Title.serial }

      # Describes the box.
      def render
        commands = Title.commands
        width = Title.width_of(Loader.box_rows(commands))
        window nil, id: Title::ID, beside: "Window_TitleCommand", side: :left, join: true, theme: :game, width: width do
          stack spacing: 0 do
            text Title::TEXTS[:heading], color: :system, align: :center, width: width - Title::PADDING * 2
            list commands, id: Title::LIST_ID, row: ->(command) { Title.row_of(command) }, most_rows: Title.most_rows,
                           on_submit: ->(command) { Title.pick(command) }
          end
        end
      end
    end
  end
end
