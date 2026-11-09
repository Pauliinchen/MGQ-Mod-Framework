#----------------------------------------------------------------
#  mods_needed.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Told the player to install a mod by hand from its page instead of installing it
#      Paulinchen  2026-11-06: Said that a mod left out which runs already stays on
#                            - Installed each mod at the version the place needs
#                            - Let the caller start the game again itself with restart: :caller
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that compares the mods a place needs with the installed ones.
    NEEDS_TOPIC = "mods.needs"

    # Compares the mods a place needs, such as a world of another mod, with the installed ones.
    #
    # @param mods [Array<Hash>] Each { name:, version:, differs: }: its name, the version needed
    #   (nil or empty for any) and whether the place found this game's copy differs from its own.
    # @return [Array<Hash>, nil] A row per mod not on in the version needed, each {"kind" =>
    #   "install", "update", "change", "by_hand", "off" or "author", "name", "title", "have", "want", "target",
    #   "installed"} (see ModsTopics.NeedsTopic); none when every one is; nil without the DLL.
    def self.needs(mods)
      listed = Array(mods).map { |mod| [mod[:name].to_s, mod[:version].to_s, mod[:differs] ? true : false] }
      answer = Mod_Framework.available? ? Mod_Framework.bridge.call(NEEDS_TOPIC, "mods" => listed) : nil
      answer.is_a?(Hash) ? Array(answer["rows"]) : nil
    end

    # Asks the player to make ready the mods a place needs before it goes on, such as the mods of a
    # world another mod enters: the NeededModsDialog names each mod to install, update, change or
    # turn on, each one to get from its author, and the mods the place leaves out of this session;
    # its first button does what can be done and goes on. Without a mod to change and without one
    # left out, no dialog opens and the block hears :ready at once. Where a mod that runs already
    # changes, the game starts again, or with restart: :caller the block hears :restart_needed and
    # the caller starts it with Mods.restart, such as once its own wait ended.
    #
    #   Mod_Framework::Mods.ask_needed("Galda's World", [{ name: "Level Cap", version: "1.5.2" }], restart: ["my_mod.enter", world_id]) do |result|
    #     enter_world(world_id) if result == :ready
    #   end
    #
    # @param place [String] What needs the mods, such as the world's name.
    # @param mods [Array<Hash>] See needs.
    # @param options [Hash] :verb ("enter", what the first button does after the mods are ready),
    #   :leaves_out (the names of the mods the place leaves out of this session), :restart ([action,
    #   value] the game carries to its title when it starts again, see Mods.after_restart; or
    #   :caller, which leaves the start to the caller: the block hears :restart_needed once the mods
    #   are ready, and the caller calls Mods.restart when its own conditions allow),
    #   :restart_text (the line that says the game starts again), :id (the dialog's id,
    #   :mods_needed).
    # @yieldparam result [Symbol] :ready (go on), :back (the player went back), :restarting (the
    #   game starts again with the mods) or, with restart: :caller, :restart_needed (the mods are
    #   ready, and the game must start again before they run).
    # @return [Object, Symbol, nil] The dialog's handle, :ready when none was needed, nil when the
    #   DLL could not compare the mods.
    def self.ask_needed(place, mods, options = {}, &block)
      rows = needs(mods)
      unless rows
        NeededModsDialog.log("the mods #{place} needs could not be compared: the DLL did not answer")
        return nil
      end

      left_out = Array(options[:leaves_out]).map { |name| name.to_s }
      if rows.empty? && left_out.empty?
        NeededModsDialog.log("#{place} needs no change of the mods")
        block.call(:ready) if block
        return :ready
      end

      NeededModsDialog.log("#{place} needs #{rows.map { |row| "#{row['name']} (#{row['kind']})" }.join(', ')}#{left_out.empty? ? '' : "; leaves out #{left_out.join(', ')}"}")
      params = { :place => place.to_s, :rows => rows, :left_out => left_out, :verb => (options[:verb] || "enter").to_s, :restart => options[:restart],
                 :restart_text => options[:restart_text], :box_id => options[:id] || NeededModsDialog::ID }
      UI.open(NeededModsDialog, params) { |result, _why| block.call(result.is_a?(Symbol) ? result : :back) if block }
    end

    # The dialog of Mods.ask_needed, a dialog of the UI layer over what opened it: the mods a place
    # needs as rows to read, the mods it leaves out of this session in dim lines, a status line with
    # the install's bar, and its buttons. The first does what can be done (turns mods on, installs
    # and updates, starts the game again where a mod that runs changes) and goes on; Back and cancel
    # go back. While a mod comes from its author only, or the player installs it by hand from its
    # page on the website, the first button hides and the status line says so. It closes with
    # :ready, :restarting, :restart_needed or :back.
    class NeededModsDialog < UI::Component
      # Its id unless the call names another, which names its parts: <id>_rows, <id>_first and <id>_back.
      ID = :mods_needed

      # The texts it shows, by what they say.
      TEXTS = {
        :title => "Mods for %s",
        :intro => "%s needs these mods.",
        :install => "install %s",
        :update => "update %s to %s",
        :change => "change %s to %s",
        :off => "turn on",
        :author => "from its author only",
        :author_tip => "Get it from its author and put it into the Patch folder.",
        :get_one => "Get %s from its author, put it into the Patch folder, then try again.",
        :get_more => "Get %s from their authors, put them into the Patch folder, then try again.",
        :by_hand => "install by hand",
        :by_hand_tip => "Install it by hand from its page on the website.",
        :by_hand_one => "Install %s by hand from its page on the website, then try again.",
        :by_hand_more => "Install %s by hand from their pages on the website, then try again.",
        :left_out => "%s turns off your other mods while you play in it: %s. They stay on in your saves.",
        :framework_one => "%s is part of the framework and stays on.",
        :framework_more => "%s are part of the framework and stay on.",
        :running_one => "%s runs already and stays on.",
        :running_more => "%s run already and stay on.",
        :restart => "The game starts again with these mods, then goes on.",
        :back => "Back",
        :installing => "Installing %s . . .",
        :writing => "Installing . . ."
      }

      # The kinds of rows that install a mod.
      INSTALLS = ["install", "update", "change"]

      # Its width and its most height; the most rows its list shows before it scrolls.
      WIDTH = 560
      MAX_HEIGHT = 360
      ROWS_SHOWN = 5

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods needed"

      # What needs the mods, such as a world's name.
      param :place

      # The mods that differ, see Mods.needs.
      param(:rows) { [] }

      # The names of the mods the place leaves out of this session.
      param(:left_out) { [] }

      # What the first button does once the mods are ready, such as "enter".
      param :verb, "enter"

      # What the game carries to its title when it starts again: [action, value], nil for nothing;
      # :caller leaves the start to the caller.
      param :restart, nil

      # The line that says the game starts again, nil for the framework's.
      param :restart_text, nil

      # Its id.
      param :box_id, ID

      # Whether the install runs, which greys the buttons and keeps cancel from closing it.
      state :busy, false

      # What the status line says instead of naming the mods to get from their authors: [text,
      # color]; nil for none.
      state :status

      # How far the install came, 0 to 1; nil while none runs.
      state :rate

      # Describes the dialog.
      def render
        first = first_text
        line, color = status || [author_line, :error]
        dialog format(TEXTS[:title], place), id: box_id, width: WIDTH, max_size: [WIDTH, MAX_HEIGHT], on_cancel: -> { cancelled } do
          text(format(TEXTS[:intro], place), typo: :body2, wrap: true, key: :intro) unless rows.empty?
          list rows.map { |row| row_of(row) }, id: :"#{box_id}_rows", most_rows: ROWS_SHOWN, visible: !rows.empty?
          left_out_lines.each_with_index { |each, place_of| text each, typo: :body2, color: :dim, wrap: true, key: [:left_out, place_of] }
          text(restart_line, typo: :body2, color: :dim, wrap: true, key: :restart) if first && restarts?
          text line.to_s, typo: :body2, key: :status, wrap: true, color: color || :text, visible: !line.nil?
          progress value: (rate.to_f * 100).round, visible: !rate.nil?
          stack row: true, justify: :end do
            button first.to_s, id: :"#{box_id}_first", variant: :filled, autofocus: true, visible: !first.nil?, disabled: busy, on_click: -> { act }
            button TEXTS[:back], id: :"#{box_id}_back", autofocus: first.nil?, disabled: busy, on_click: -> { close(:back) }
          end
        end
      end

      # Forgets the dialog once it left the screen, so an install that ends later changes nothing.
      def unmounted
        @gone = true
      end

      # Does what the first button says: turns the mods on, installs the others, then goes on or
      # starts the game again.
      def act
        return if busy

        ids = targets(INSTALLS)
        NeededModsDialog.log("#{box_id}: the player chose #{first_text} for #{place}")
        return finish([]) if ids.empty?

        self.busy = true
        self.rate = 0
        self.status = [TEXTS[:writing], nil]
        Mods.install(ids, :versions => versions(INSTALLS), :progress => lambda { |done, total, name| progressed(done, total, name) }) { |installed, error| installed(installed, error) }
      end

      private

      # Makes a row of the list: the mod and what happens to it.
      #
      # @param row [Hash] A mod that differs.
      # @return [Hash] The row.
      def row_of(row)
        title = row["title"].to_s
        case row["kind"]
        when "install" then { text: title, right: format(TEXTS[:install], row["want"]), right_color: :warning }
        when "update" then { text: title, right: format(TEXTS[:update], row["have"], row["want"]), right_color: :warning }
        when "change" then { text: title, right: format(TEXTS[:change], row["have"], row["want"]), right_color: :warning }
        when "off" then { text: title, right: TEXTS[:off], right_color: :warning }
        when "by_hand" then { text: title, right: TEXTS[:by_hand], right_color: :error, tooltip: TEXTS[:by_hand_tip] }
        else { text: title, right: TEXTS[:author], right_color: :error, tooltip: TEXTS[:author_tip] }
        end
      end

      # Tells the line naming the mods to get from their authors and those the player installs by
      # hand.
      #
      # @return [String, nil] The line, nil while none is needed.
      def author_line
        parts = [[:get_one, :get_more, "author"], [:by_hand_one, :by_hand_more, "by_hand"]].map do |one, more, kind|
          names = rows.select { |row| row["kind"] == kind }.map { |row| row["title"].to_s }
          names.empty? ? nil : format(names.size == 1 ? TEXTS[one] : TEXTS[more], UI.listed(names))
        end.compact
        parts.empty? ? nil : parts.join(" ")
      end

      # Tells the dim lines of the mods the place leaves out: those that stay off this session, the
      # framework's that stay on, and the others that run already and so stay on too.
      #
      # @return [Array<String>] The lines.
      def left_out_lines
        framework = left_out.select { |name| framework_mod?(name) }
        running = left_out.select { |name| !framework.include?(name) && Mods.running?(name) }
        off = left_out - framework - running
        lines = []
        lines << format(TEXTS[:left_out], place, UI.listed(off)) unless off.empty?
        lines << format(framework.size == 1 ? TEXTS[:framework_one] : TEXTS[:framework_more], UI.listed(framework)) unless framework.empty?
        lines << format(running.size == 1 ? TEXTS[:running_one] : TEXTS[:running_more], UI.listed(running)) unless running.empty?
        lines
      end

      # Tells whether a mod runs as part of the framework from the game's start: tagged Framework, or
      # a Title mod that loaded whole.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it does.
      def framework_mod?(name)
        planned = Array((Mods.last_plan || {})["load"]).find { |entry| entry[0].to_s.casecmp(name) == 0 }
        (planned && planned[1].to_s == "Framework") || Mods.loads_as_framework?(name) ? true : false
      end

      # Tells the first button's text by what it does, nil while a mod comes from its author only or
      # is installed by hand.
      #
      # @return [String, nil] The text.
      def first_text
        return nil if rows.any? { |row| row["kind"] == "author" || row["kind"] == "by_hand" }

        installs = !targets(INSTALLS).empty?
        on = !targets(["off"]).empty?
        doing = if installs && restarts? then "Install, restart and %s"
                elsif installs && on then "Install, turn on and %s"
                elsif installs then "Install and %s"
                elsif on then "Turn on and %s"
                end
        doing ? format(doing, verb) : verb.capitalize
      end

      # Tells whether the game starts again once the mods are ready: a mod that changes runs already,
      # or one turns on after the player entered the game.
      #
      # @return [Boolean] Whether it does.
      def restarts?
        rows.any? do |row|
          installed = row["installed"].to_s
          (INSTALLS.include?(row["kind"]) && !installed.empty? && Mods.running?(installed)) || (row["kind"] == "off" && Mods.entered?)
        end
      end

      # Tells the line that says the game starts again.
      #
      # @return [String] The line.
      def restart_line
        (restart_text || TEXTS[:restart]).to_s
      end

      # Lists what the rows of some kinds act on.
      #
      # @param kinds [Array<String>] The kinds.
      # @return [Array<String>] The ids to install or the mods to turn on.
      def targets(kinds)
        rows.select { |row| kinds.include?(row["kind"]) }.map { |row| row["target"].to_s }.reject { |target| target.empty? }
      end

      # Tells the version each row of some kinds wants written.
      #
      # @param kinds [Array<String>] The kinds.
      # @return [Hash{String => String}] Each id to install and its version.
      def versions(kinds)
        wanted = rows.select { |row| kinds.include?(row["kind"]) && !row["target"].to_s.empty? && !row["want"].to_s.empty? }
        Hash[wanted.map { |row| [row["target"].to_s, row["want"].to_s] }]
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

      # Goes on once the install ended, or back to the buttons with why it failed.
      #
      # @param installed [Array<String>] The folders installed into.
      # @param error [String, nil] Why it failed.
      def installed(installed, error)
        return if @gone
        return finish(installed) unless error

        NeededModsDialog.log("#{box_id}: the install for #{place} stopped: #{error}")
        self.busy = false
        self.rate = nil
        self.status = [error, :error]
        UI.buzz
      end

      # Turns the mods on, then goes on, or starts the game again with them.
      #
      # @param installed [Array<String>] The folders installed into.
      def finish(installed)
        restart = restarts?
        names = targets(["off"])
        unless names.empty?
          on = {}
          names.each { |name| on[name] = true }
          answer = Mods.set("on" => on)
          NeededModsDialog.log("turning on #{names.join(', ')} was not kept: #{answer.inspect}") unless answer.is_a?(Hash) && answer["written"]
        end
        return close(:ready) unless restart
        if self.restart == :caller
          NeededModsDialog.log("#{box_id}: #{place} needs the game started again with #{(installed + names).join(', ')}, which the caller does")
          return close(:restart_needed)
        end

        NeededModsDialog.log("#{box_id}: the game starts again for #{place} with #{(installed + names).join(', ')}")
        action, value = Array(self.restart)
        close(:restarting)
        Mods.restart("#{place} needs mods that run already loaded anew", action, value)
      end

      # Answers cancel: Back, unless the install runs, which cancel waits for with the buzzer.
      #
      # @return [Boolean] Whether it closes.
      def cancelled
        return true unless busy

        UI.buzz("#{box_id}: cancel waits for the install for #{place}")
        false
      end
    end
  end
end
