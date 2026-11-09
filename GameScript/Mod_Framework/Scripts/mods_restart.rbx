#----------------------------------------------------------------
#  mods_restart.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Started the game again as the last thing the closing game does, without the helper
#      Paulinchen  2026-11-06: Showed the message of a save that did not load through UI.message
#                            - Called the engine's classes by their names under UI::Engine
#                            - Kept the changes that wait for the game to start again and told the lines of the restart bar
#      Paulinchen  2026-10-31: Told the restart by hand without its cause
#      Paulinchen  2026-10-30: Let a mod name the action a restart that names none carries, such as the way back to the title's
#                            - Restarted once the rest of a Title mod loaded, not for its title part
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that starts the game's own Game.exe again.
    RESTART_TOPIC = "mods.restart"

    # The environment variable in which the action after a restart reaches the game that starts
    # again, "name" or "name:value"; the DLL sets it for the game it starts.
    AFTER_RESTART = "MOD_FRAMEWORK_AFTER_RESTART"

    # What an action's name may be, as the DLL checks it too.
    ACTION_NAME = /\A[a-z0-9][a-z0-9_.-]{0,63}\z/

    # The framework's action after a restart that loads a save; its value is the save's index.
    LOAD_ACTION = "load"

    # The lines of the restart bar: a mod that runs until the game starts again, one that loads once
    # it does, and how many changes wait.
    RESTART_TEXTS = { :runs_until => "%s runs until the game starts again.", :loads_once => "%s loads once the game starts again.",
                      :changes_wait => "%d changes wait for the game to start again." }

    # The changes of this game session that count only once the game starts again, each its line
    # of the restart bar, by what changed.
    @waits = {}

    # Notes a change that counts only once the game starts again, for the restart bar of the
    # screens at the title; a change of the same key replaces its line.
    #
    # @param key [Object] What changed, such as [:world, "My World"].
    # @param text [String] Its line, such as "My World moves once the game starts again."
    def self.wait_for_restart(key, text)
      @waits[key] = text.to_s
    end

    # Takes back a change that no longer waits for the game to start again, such as a move undone.
    #
    # @param key [Object] What changed.
    # @return [Boolean] Whether it waited.
    def self.unwait(key)
      @waits.delete(key) ? true : false
    end

    # Tells whether a change waits for the game to start again.
    #
    # @param key [Object] What changed.
    # @return [Boolean] Whether it waits.
    def self.waits?(key)
      @waits.key?(key)
    end

    # Lists the lines of the changes that wait for the game to start again.
    #
    # @return [Array<String>] The lines, in the order the changes came.
    def self.restart_waits
      @waits.values
    end

    # Lists the lines of the restart bar: each mod turned off that runs until the game starts
    # again, each mod turned on that loads only once it does, then the changes other screens wait
    # with.
    #
    # @param mods [Array<Hash>] The installed mods, see Mods.state.
    # @return [Array<String>] The lines; none while nothing waits.
    def self.restart_lines(mods)
      mods.select { |mod| off_after_restart?(mod) }.map { |mod| format(RESTART_TEXTS[:runs_until], mod["title"]) } +
        mods.select { |mod| on_after_restart?(mod) }.map { |mod| format(RESTART_TEXTS[:loads_once], mod["title"]) } + restart_waits
    end

    # Tells the text of the restart bar for its lines: the one line, or how many changes wait.
    #
    # @param lines [Array<String>] The lines, see restart_lines.
    # @return [String] The text.
    def self.restart_text(lines)
      lines.size == 1 ? lines[0] : format(RESTART_TEXTS[:changes_wait], lines.size)
    end

    # Tells whether a mod is turned off but runs until the game starts again, see running?; never
    # the framework's own row.
    #
    # @param mod [Hash] The mod, see Mods.state.
    # @return [Boolean] Whether it does.
    def self.off_after_restart?(mod)
      !mod["on"] && !mod["framework"] && running?(mod["name"]) ? true : false
    end

    # Tells whether a mod is turned on but loads only once the game starts again: it did not load
    # and the title counts as entered, such as after a mod's own choice at New Game was cancelled.
    #
    # @param mod [Hash] The mod, see Mods.state.
    # @return [Boolean] Whether it does.
    def self.on_after_restart?(mod)
      return false unless mod["on"] && !mod["framework"] && entered?

      loaded.none? { |name| name.casecmp(mod["name"].to_s) == 0 } && !failed_last(mod["name"])
    end

    # Starts the game again, so the mods loaded unload and the mods turned on and the updates that
    # wait load: the game ends after this frame, and as the last thing it does the DLL starts the
    # game's own Game.exe once more. Where nothing can start it again (JoiPlay, no DLL, Game.exe
    # not starting) a message asks the player to, and the game ends all the same.
    #
    # @param reason [String] Why, for the log.
    # @param action [String, nil] What the game does at its title once it started again, a name
    #   registered with after_restart, such as LOAD_ACTION; nil for nothing.
    # @param value [String, Integer, nil] What the action takes, such as the save's index.
    # @return [Symbol] :restarting, or :closing when the player starts the game again.
    # @raise [ArgumentError] The action's name does not match ACTION_NAME.
    def self.restart(reason, action = nil, value = nil)
      raise ArgumentError, "#{action.inspect} is no action name" if action && action.to_s !~ ACTION_NAME

      Restart.restart(reason.to_s, action && action.to_s, value.nil? ? nil : value.to_s)
    end

    # Names the action that the next restart naming none of its own carries, such as the restart on
    # the way back to the title or at F12, so something the player asked for during the game
    # happens at the title of the game that starts again. A later call replaces it.
    #
    # @param name [String, nil] The action's name, registered with after_restart; nil takes the
    #   action back.
    # @param value [String, Integer, nil] What the action takes.
    # @raise [ArgumentError] The action's name does not match ACTION_NAME.
    def self.carry_after_restart(name, value = nil)
      raise ArgumentError, "#{name.inspect} is no action name" if name && name.to_s !~ ACTION_NAME

      Restart.carry(name && name.to_s, value.nil? ? nil : value.to_s)
      nil
    end

    # Tells whether the way back to the title restarts the game: code that loads on entering ran in
    # this game session, a Regular or Data mod or the rest of a Title mod past its title part,
    # which only a restart takes out of the game again.
    #
    # @return [Boolean] Whether it does.
    def self.restart_needed?
      Loader.entering_ran?
    end

    # Runs a block at the title once the game started again with an action of this name. Register
    # it at the boot (a Framework or Title mod), since the title comes before the player enters.
    #
    # @param name [String] The action's name, matching ACTION_NAME.
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :log (where a failure is logged; the framework's log by default).
    # @yield [value] Runs once, with the action's value as text, nil for none.
    # @raise [ArgumentError] The name does not match ACTION_NAME.
    def self.after_restart(name, tag, options = {}, &block)
      raise ArgumentError, "#{name.inspect} is no action name" unless name.to_s =~ ACTION_NAME

      Restart.after_restart(name.to_s, [tag, block, options[:log]])
      nil
    end

    # Restarts the game on every way back to the title once code that loads on entering ran (To
    # Title, game over, an event's return to the title, F12), and runs the action a restart
    # carried at the first title.
    module Restart
      # Who the hooks are registered by.
      TAG = "Mod Framework restart"

      # What the player reads where the game cannot start itself again.
      BY_HAND_TEXT = "The game closes now. Start it again to use your changed mods."

      # What the player reads when the save a restart was for did not load.
      LOAD_FAILED_TEXT = "Save %s could not be loaded."

      # The block of each action by its name, each [tag, block, log].
      @handlers = {}

      # The action this game started with, [name, value], nil for none.
      @action = nil

      # Whether the first title came, after which no action runs.
      @title_came = false

      # Why the game restarts, once it does.
      @restarting = nil

      # The action a restart that names none carries, [name, value], nil for none.
      @carried = nil

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "restart"

      # Takes the action the restart carried out of the environment, once as the framework loads,
      # so nothing the game starts inherits it.
      def self.take_action
        text = ENV[AFTER_RESTART]
        return if text.nil? || text.empty?

        ENV.delete(AFTER_RESTART)
        name, value = text.dup.force_encoding("UTF-8").split(":", 2)
        @action = [name, value]
        log("the game started again to run #{described(name, value)} at the title")
      rescue => e
        log("the action after the restart could not be read: #{Logging.failure(e)}")
      end

      # Tells the action this game started with.
      #
      # @return [Array, nil] [name, value], nil for none or once it ran.
      def self.action
        @action
      end

      # Keeps an action's block, see Mods.after_restart.
      #
      # @param name [String] The action's name.
      # @param entry [Array] The tag, the block and its log.
      def self.after_restart(name, entry)
        log("#{entry[0]} takes the action #{name} after a restart, instead of #{@handlers[name][0]}") if @handlers[name]
        @handlers[name] = entry
      end

      # Keeps the action a restart that names none carries, see Mods.carry_after_restart.
      #
      # @param name [String, nil] The action's name, nil for none.
      # @param value [String, nil] Its value.
      def self.carry(name, value)
        @carried = name ? [name, value] : nil
        log(name ? "a restart that names no action carries #{described(name, value)}" : "a restart carries no action unless it names one")
      end

      # Starts the game again, see Mods.restart. A second call while the game ends does nothing.
      #
      # @param reason [String] Why.
      # @param action [String, nil] The action's name; nil for the one carried, see carry.
      # @param value [String, nil] Its value.
      # @return [Symbol] :restarting or :closing.
      def self.restart(reason, action, value)
        return @restarting if @restarting

        action, value = @carried if action.nil? && @carried
        if Mod_Framework.available? && Mod_Framework.platform != Mod_Framework::JOIPLAY
          log("#{reason}: the game starts again as it closes#{action ? ", then #{described(action, value)}" : ''}")
          @restarting = :restarting
          Run.on_close(TAG) { Mod_Framework::Mods::Restart.start_again(action, value) }
        else
          why = Mod_Framework.available? ? "JoiPlay" : "there is no DLL"
          log("#{reason}: the game cannot start itself again (#{why}), so it closes for the player to start it#{action ? ", without #{described(action, value)}" : ''}")
          @restarting = :closing
          tell(BY_HAND_TEXT)
        end
        Run.quit(reason)
        @restarting
      end

      # Has the DLL start the game's own Game.exe again, as the last of the closing work, so the
      # game that starts finds what this one wrote as it closed; where it does not start, a message
      # asks the player to.
      #
      # @param action [String, nil] The action's name.
      # @param value [String, nil] Its value.
      def self.start_again(action, value)
        answer = Mod_Framework.bridge.call(RESTART_TOPIC, "action" => action, "value" => value)
        return log("the game starts again#{action ? " to run #{described(action, value)}" : ''}") if answer.is_a?(Hash) && answer["started"]

        log("the game did not start again (#{answer.is_a?(Hash) ? answer['refused'] || 'Game.exe did not start' : 'the DLL gave no answer'}), so the player starts it")
        tell(BY_HAND_TEXT)
      end

      # Shows the player a message box, which waits for them, as the game's own msgbox does on every
      # platform.
      #
      # @param text [String] The message.
      def self.tell(text)
        msgbox(text) if Kernel.respond_to?(:msgbox, true)
      rescue => e
        log("the message could not show: #{Logging.failure(e)}")
      end

      # Follows the ways back to the title and the first title, once the game runs.
      def self.install
        manager = ::SceneManager.singleton_class
        [:goto, :call].each do |name|
          next unless ::SceneManager.respond_to?(name)

          Hooks.around(manager, name, TAG) { |_manager, args, original| Mod_Framework::Mods::Restart.title?(args[0]) ? Mod_Framework::Mods::Restart.back_to_title : original.call }
        end
        if ::SceneManager.respond_to?(:return)
          Hooks.around(manager, :return, TAG) { |_manager, _args, original| Mod_Framework::Mods::Restart.returns_to_title? ? Mod_Framework::Mods::Restart.back_to_title : original.call }
        end
        Run.on_reset(TAG) { Mod_Framework::Mods::Restart.at_reset }
        Hooks.after(::Scene_Base, :post_start, TAG) { Mod_Framework::Mods::Restart.at_title if defined?(::Scene_Title) && is_a?(::Scene_Title) } if defined?(::Scene_Base) && ::Scene_Base.method_defined?(:post_start)
      rescue => e
        log("the ways back to the title could not be followed: #{Logging.failure(e)}")
      end

      # Tells whether a scene the game goes to is the title while a restart is needed.
      #
      # @param scene [Class, Object] The scene's class.
      # @return [Boolean] Whether it is.
      def self.title?(scene)
        Mods.restart_needed? && defined?(::Scene_Title) && scene.is_a?(Class) && scene <= ::Scene_Title ? true : false
      end

      # Tells whether the scene SceneManager.return goes back to is the title while a restart is
      # needed.
      #
      # @return [Boolean] Whether it is.
      def self.returns_to_title?
        stack = ::SceneManager.instance_variable_get(:@stack)
        Mods.restart_needed? && defined?(::Scene_Title) && stack.is_a?(Array) && stack.last.is_a?(::Scene_Title) ? true : false
      end

      # Restarts instead of going to the title.
      #
      # @return [nil] What the way to the title returns.
      def self.back_to_title
        scene = ::SceneManager.respond_to?(:scene) ? ::SceneManager.scene : nil
        restart("#{scene ? scene.class.name : 'the game'} went back to the title, and mods were loaded on entering", nil, nil)
        nil
      end

      # Restarts instead of starting the scenes again at F12.
      def self.at_reset
        restart("F12 reset the game, and mods were loaded on entering", nil, nil) if Mods.restart_needed?
      end

      # Runs the action the restart carried, at the first title only.
      def self.at_title
        return if @title_came

        @title_came = true
        return unless @action

        name, value = @action
        @action = nil
        tag, block, logger = @handlers[name]
        return log("nothing takes the action #{name} after the restart, so the title stays") unless block

        log("#{tag} runs #{described(name, value)} after the restart")
        block.call(value)
      rescue => e
        message = "#{tag} failed to run #{described(name, value)} after the restart: #{Logging.failure(e)} at #{Array(e.backtrace).first}"
        logger.respond_to?(:log) ? logger.log(message) : log(message)
      end

      # Loads a save at the title as the game's load screen does, entering the game first, so a mod
      # that wraps the load runs.
      #
      # @param value [String] The save's index, as DataManager.load_game takes it: a number, or the
      #   translation's text such as "01" for an autosave.
      def self.load_save(value)
        index = value.to_s =~ /\A(0|[1-9][0-9]*)\z/ ? value.to_i : value.to_s
        Mods.enter("the load of save #{value} after the restart")
        if ::DataManager.load_game(index)
          log("loaded save #{value} after the restart")
          ::Scene_Load.new.on_load_success
        else
          log("save #{value} did not load after the restart, so the title stays")
          UI.message(format(LOAD_FAILED_TEXT, value), :title => "Load") if Mod_Framework.available? && UI.respond_to?(:message)
        end
      end

      # Describes an action for the log.
      #
      # @param name [String] Its name.
      # @param value [String, nil] Its value.
      # @return [String] Such as "the action load (3)".
      def self.described(name, value)
        "the action #{name}#{value ? " (#{value})" : ''}"
      end
    end

    Restart.take_action
    after_restart(LOAD_ACTION, "Mod Framework") { |value| Mod_Framework::Mods::Restart.load_save(value) }
    Run.on_start(Restart::LOG_TAG) { Mod_Framework::Mods::Restart.install }
  end
end
