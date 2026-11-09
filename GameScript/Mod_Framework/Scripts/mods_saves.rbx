#----------------------------------------------------------------
#  mods_saves.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Told the player to install a mod by hand from its page instead of installing it
#      Paulinchen  2026-11-06: Drew the save's mods dialog as a component of the UI layer, its mods as rows to read and a
#                              line naming the mods to get from their authors
#      Paulinchen  2026-10-31: Told the restart for a save without its cause
#      Paulinchen  2026-10-30: Left a Title mod whose rest did not load out of the mods of a save
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that compares a save's mods with the installed ones.
    CHECK_TOPIC = "mods.check"

    # Lists the mods of this game session as a save's header keeps them: each mod loaded, but a
    # Title mod that loaded only its title part, which never reached the game; in plain values
    # only, so the header reads without any mod's classes.
    #
    # @return [Array<Array>] Each [name, version, tag]; a version nobody knows is "?" or nil.
    def self.session_mods
      planned = last_plan || {}
      known = {}
      Array(planned["load"]).each { |name, tag, _place, version| known[name] = [version, tag] }
      loaded.reject { |name| Loader.title_part_only?(name) }.map { |name| [name, (known[name] || [])[0], (known[name] || [])[1]] }
    end

    # Compares the mods a save was made with against the installed ones.
    #
    # @param saved [Array<Array>] Each [name, version, tag], as session_mods lists them.
    # @return [Array<Hash>, nil] A row per mod off or missing, then per mod in another version, each
    #   {"kind" => "off", "install", "unknown" or "version", "name", "title", "saved",
    #   "installed", "target"} (see ModsTopics.CheckTopic); none when no mod is off or missing; nil
    #   without the DLL.
    def self.check(saved)
      answer = Mod_Framework.available? ? Mod_Framework.bridge.call(CHECK_TOPIC, "mods" => saved) : nil
      answer.is_a?(Hash) ? Array(answer["rows"]) : nil
    end

    # Keeps the mods of the game session in each save's header, and asks the player before a save
    # loads whose mods are off or missing now: SaveModsDialog over the save list turns them on,
    # installs them and loads, or loads anyway. In the game, where mods turn on only as it starts,
    # it restarts the game instead and loads the save at the title.
    module Saves
      # Who the hooks are registered by.
      TAG = "Mod Framework saves"

      # The key of the mods in a save's header.
      HEADER_KEY = :mods

      # The id of the dialog, which mods name it by.
      ID = :mods_save_check

      # The id of the dialog's list of the mods that differ.
      ROWS_ID = :mods_save_rows

      # Whether a load the player chose runs, which passes the check.
      @passing = false

      # What the scene of the save list does in its next update, [scene, args, action, index], nil
      # for nothing.
      @pending = nil

      # The handle of the dialog shown, nil before the first.
      @handle = nil

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods saves"

      # Follows the save's header, the picks of a save and the save list's updates, once the game
      # runs, after the loader's ways in, so the check comes before the mods load.
      def self.install
        if defined?(::DataManager) && ::DataManager.respond_to?(:make_save_header)
          Hooks.around(::DataManager.singleton_class, :make_save_header, TAG) { |_manager, _args, original| Mod_Framework::Mods::Saves.with_mods(original.call) }
        end
        Loader.load_scenes.each do |klass|
          Hooks.around(klass, :on_savefile_ok, TAG) { |scene, args, original| Mod_Framework::Mods::Saves.picked(scene, args, original) }
        end
        Hooks.after(::Scene_Load, :update, TAG) { |*_args| Mod_Framework::Mods::Saves.go_on(self) } if defined?(::Scene_Load) && ::Scene_Load.method_defined?(:update)
      rescue => e
        log("the saves could not be followed: #{Logging.failure(e)}")
      end

      # Adds the mods of the game session to a save's header.
      #
      # @param header [Hash] The header the game made.
      # @return [Hash] The header.
      def self.with_mods(header)
        header[HEADER_KEY] = Mods.session_mods if header.is_a?(Hash)
        header
      rescue => e
        log("the mods could not be kept in the save: #{Logging.failure(e)}")
        header
      end

      # Picks a save: loads it when its mods are on, else asks the player first; loads it as well
      # when the dialog cannot open.
      #
      # @param scene [Scene_Load] The save list.
      # @param args [Array] The pick's arguments.
      # @param original [Proc] Picks it as the game does.
      # @return [Object] What the pick returns.
      def self.picked(scene, args, original)
        return original.call if @passing || !Mod_Framework.available? || (@handle && @handle.open?)

        index = save_index(scene)
        saved = saved_mods(index)
        rows = saved ? Mods.check(saved) : nil
        return original.call if rows.nil? || rows.empty?

        log("save #{index} was made with mods that differ now: #{rows.map { |row| "#{row['name']} (#{row['kind']})" }.join(', ')}")
        @handle = UI.open(SaveModsDialog, :save_list => scene, :pick => args, :save => index, :rows => rows, :in_game => Mods.entered?)
        return original.call unless @handle

        UI.confirm_sound
        nil
      end

      # Tells the save a pick loads: the file index of the picked save window, as the translation's
      # autosaves name theirs ("01"), else the scene's index.
      #
      # @param scene [Scene_Load] The save list.
      # @return [Integer, String] The index DataManager takes.
      def self.save_index(scene)
        index = scene.instance_variable_get(:@index)
        windows = scene.instance_variable_get(:@savefile_windows)
        window = windows.is_a?(Array) && index.is_a?(Integer) ? windows[index] : nil
        file = window ? window.instance_variable_get(:@file_index) : nil
        file.nil? ? index : file
      end

      # Reads the mods a save's header names.
      #
      # @param index [Integer, String] The save.
      # @return [Array<Array>, nil] Each [name, version, tag]; nil for a save without the list.
      def self.saved_mods(index)
        header = ::DataManager.load_header(index)
        list = header.is_a?(Hash) ? header[HEADER_KEY] : nil
        return nil unless list.is_a?(Array)

        list.select { |entry| entry.is_a?(Array) && entry[0].is_a?(String) }.map { |name, version, tag| [name, version && version.to_s, tag && tag.to_s] }
      rescue => e
        log("the header of save #{index} could not be read: #{Logging.failure(e)}")
        nil
      end

      # Keeps what the save list does in its next update, outside the frame's work, since a load
      # fades the screen out over frames of its own.
      #
      # @param scene [Scene_Load] The save list.
      # @param args [Array] The pick's arguments.
      # @param action [Symbol] :load, or :restart to start the game again and load the save there.
      # @param index [Integer, String] The save.
      def self.decide(scene, args, action, index)
        @pending = [scene, args, action, index]
      end

      # Runs what the save list was to do, once, in its own update.
      #
      # @param scene [Scene_Load] The save list updating.
      def self.go_on(scene)
        return unless @pending && @pending[0].equal?(scene)

        _scene, args, action, index = @pending
        @pending = nil
        action == :restart ? Mods.restart("Restart and load save #{index}", LOAD_ACTION, index) : pass(scene, args)
      end

      # Picks the save again as the player did, past the check.
      #
      # @param scene [Scene_Load] The save list.
      # @param args [Array] The pick's arguments.
      def self.pass(scene, args)
        @passing = true
        scene.send(:on_savefile_ok, *args)
      ensure
        @passing = false
      end
    end

    # The dialog over the save list, a dialog of the UI layer, that names the mods of a save that
    # are off or missing now, those in another version after them, as rows to read. Its first
    # button does what can be done: turns the mods on, installs the missing ones the website has,
    # but those the player installs by hand, and loads, or in the game restarts and loads; Load
    # anyway loads with the mods as
    # they are; Back and cancel go back to the save list.
    class SaveModsDialog < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :title => "This save used other mods",
        :intro => "%s was made with mods that are not on now.",
        :in_game => "The game starts again and loads this save.",
        :save => "Save %d",
        :autosave => "The autosave",
        :off => "turns on",
        :install => "installs",
        :unknown => "not on the site",
        :unknown_tip => "Get it from its author and put it into the Patch folder.",
        :get_one => "Get %s from its author and put it into the Patch folder.",
        :get_more => "Get %s from their authors and put them into the Patch folder.",
        :by_hand => "install by hand",
        :by_hand_tip => "Install it by hand from its page on the website.",
        :by_hand_one => "Install %s by hand from its page on the website.",
        :by_hand_more => "Install %s by hand from their pages on the website.",
        :version => "the save used %s, you have %s",
        :turn_on => "Turn on and load",
        :install_load => "Install and load",
        :install_turn_on => "Install, turn on and load",
        :restart => "Restart and load",
        :anyway => "Load anyway",
        :back => "Back",
        :installing => "Installing %s . . .",
        :writing => "Installing . . ."
      }

      # The dialog's width and its most height.
      WIDTH = 520
      MAX_HEIGHT = 360

      # The most rows the list shows; more scroll.
      ROWS_SHOWN = 6

      # The save list the dialog lies over, which does what the player chose in its next update.
      param :save_list, nil

      # The arguments of the player's pick of the save, which the load passes on.
      param(:pick) { [] }

      # The save, as DataManager takes it: a number, or the text of an autosave such as "01".
      param :save

      # The mods that differ, see Mods.check.
      param(:rows) { [] }

      # Whether the player entered the game, so the mods turn on only as it starts again.
      param :in_game, false

      # Whether the install runs, which greys every button and keeps cancel from closing it.
      state :busy, false

      # What the line under the list says instead of naming the mods to get from their authors:
      # [text, color], such as how the install goes or why it failed; nil for none.
      state :status

      # How far the install came, 0 to 1; nil while none runs.
      state :rate

      # Describes the dialog: the line under its title, the rows, the status line, the install's
      # bar and the buttons.
      def render
        first = first_text
        line, color = status || [missing_line, nil]
        dialog TEXTS[:title], id: Saves::ID, width: WIDTH, max_size: [WIDTH, MAX_HEIGHT], on_cancel: -> { cancelled }, on_close: ->(why) { closed(why) } do
          text intro, typo: :body2, wrap: true, key: :intro
          list rows.map { |row| row_of(row) }, id: Saves::ROWS_ID, most_rows: ROWS_SHOWN
          text line.to_s, typo: :body2, key: :status, wrap: true, color: color || :text, visible: !line.nil?
          progress value: (rate.to_f * 100).round, visible: !rate.nil?
          stack row: true, justify: :end do
            button first.to_s, variant: :filled, key: :first, autofocus: !first.nil?, visible: !first.nil?, disabled: busy, on_click: -> { act }
            button TEXTS[:anyway], key: :anyway, autofocus: first.nil?, disabled: busy, on_click: -> { load_anyway }
            button TEXTS[:back], key: :back, disabled: busy, on_click: :close
          end
        end
      end

      # Forgets the dialog once it left the screen, so an install that ends later changes nothing.
      def unmounted
        @gone = true
      end

      # Does what the first button says: turns the mods on, installs the missing ones, then loads or
      # restarts.
      def act
        return if busy

        off = targets("off")
        ids = targets("install")
        Saves.log("#{Saves::ID}: the player chose #{first_text} for save #{save}")
        return finish(off) if ids.empty?

        self.busy = true
        self.rate = 0
        self.status = [TEXTS[:writing], nil]
        Mods.install(ids, :progress => lambda { |done, total, name| progressed(done, total, name) }) { |installed, error| installed(off, installed, error) }
      end

      # Loads with the mods as they are.
      def load_anyway
        return if busy

        decided(:load)
      end

      private

      # Tells the line under the title.
      #
      # @return [String] The line.
      def intro
        return TEXTS[:in_game] if in_game && first_text

        format(TEXTS[:intro], save.is_a?(Integer) ? format(TEXTS[:save], save + 1) : TEXTS[:autosave])
      end

      # Tells the line that names, once for the keys, the mods the website does not have and the
      # mods the player installs by hand, which a row's tooltip tells only the mouse.
      #
      # @return [String, nil] The line, nil when the dialog installs every missing mod.
      def missing_line
        parts = [[:get_one, :get_more, "unknown"], [:by_hand_one, :by_hand_more, "by_hand"]].map do |one, more, kind|
          names = rows.select { |row| row["kind"] == kind }.map { |row| row["title"].to_s }
          names.empty? ? nil : format(names.size == 1 ? TEXTS[one] : TEXTS[more], UI.listed(names))
        end.compact
        parts.empty? ? nil : parts.join(" ")
      end

      # Makes a row of the list.
      #
      # @param row [Hash] A mod that differs.
      # @return [Hash] The row.
      def row_of(row)
        saved = row["saved"].to_s
        text = saved.empty? || saved == "?" ? row["title"].to_s : "#{row['title']} #{saved}"
        case row["kind"]
        when "off" then { text: text, right: TEXTS[:off], right_color: :warning }
        when "install" then { text: text, right: TEXTS[:install], right_color: :warning }
        when "unknown" then { text: text, right: TEXTS[:unknown], right_color: :dim, faint: true, tooltip: TEXTS[:unknown_tip] }
        when "by_hand" then { text: text, right: TEXTS[:by_hand], right_color: :warning, tooltip: TEXTS[:by_hand_tip] }
        else { text: row["title"].to_s, right: format(TEXTS[:version], saved, row["installed"]), right_color: :dim }
        end
      end

      # Tells the first button's text by what it can do.
      #
      # @return [String, nil] The text; nil when it can do nothing.
      def first_text
        off = !targets("off").empty?
        install = !targets("install").empty?
        return nil unless off || install
        return TEXTS[:restart] if in_game

        off && install ? TEXTS[:install_turn_on] : install ? TEXTS[:install_load] : TEXTS[:turn_on]
      end

      # Lists what the rows of a kind act on.
      #
      # @param kind [String] The kind.
      # @return [Array<String>] The folders to turn on or the ids to install.
      def targets(kind)
        rows.select { |row| row["kind"] == kind }.map { |row| row["target"].to_s }
      end

      # Shows how far the install came.
      #
      # @param done [Integer] The mods downloaded.
      # @param total [Integer] The mods to install.
      # @param name [String, nil] The mod downloading now, nil while the files are written.
      def progressed(done, total, name)
        return if @gone

        self.rate = total > 0 ? done.to_f / total : 0
        self.status = [name ? format(TEXTS[:installing], name) : TEXTS[:writing], nil]
      end

      # Goes on once the install ended: on to the load, or back to the buttons with why it failed.
      #
      # @param off [Array<String>] The folders turned off that turn on.
      # @param installed [Array<String>] The folders installed into.
      # @param error [String, nil] Why it failed.
      def installed(off, installed, error)
        return if @gone
        return finish(off + installed) unless error

        Saves.log("#{Saves::ID}: the install stopped before save #{save} loaded: #{error}")
        self.busy = false
        self.rate = nil
        self.status = [error, :error]
        UI.buzz
      end

      # Turns mods on, then loads or restarts.
      #
      # @param names [Array<String>] Their folders.
      def finish(names)
        unless names.empty?
          on = {}
          names.each { |name| on[name] = true }
          answer = Mods.set("on" => on)
          Saves.log("turning on #{names.join(', ')} was not kept: #{answer.inspect}") unless answer.is_a?(Hash) && answer["written"]
        end
        decided(in_game ? :restart : :load)
      end

      # Closes and hands the save list what it does next.
      #
      # @param action [Symbol] :load or :restart.
      def decided(action)
        @decided = true
        Saves.log("the player chose to #{action == :restart ? 'restart and load' : 'load'} save #{save}")
        Saves.decide(save_list, pick, action, save)
        close
      end

      # Answers cancel: Back, unless the install runs, which cancel waits for with the buzzer.
      #
      # @return [Boolean] Whether the dialog closes.
      def cancelled
        return true unless busy

        UI.buzz("#{Saves::ID}: cancel waits for the install of save #{save}")
        false
      end

      # Logs the way back to the save list, by cancel or Back, unless the player chose a load.
      #
      # @param why [Symbol, String] Why it closed.
      def closed(why)
        Saves.log("the player went back to the save list from #{Saves::ID} (#{why})") unless @decided
      end
    end

    Run.on_start(Saves::LOG_TAG) { Mod_Framework::Mods::Saves.install }
  end
end
