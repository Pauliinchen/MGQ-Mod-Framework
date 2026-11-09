#----------------------------------------------------------------
#  run.rbx
#
#  Changelog:
#      Paulinchen  2026-10-30: Ended the game on request, at an F12 reset before its scenes start again
#                            - Ran a block before the others at the first run when asked
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The game's run, SceneManager.run: what the framework and the mods built on it install once the
  # game starts running, what they reset when F12 starts the scenes again, and what they finish as
  # the game closes.
  #
  # Every game-class hook installs at the run, not as the scripts load, since the game's plugins
  # load after the mods and some define a method again with a plain def. The game ends through its
  # Exit-EX plugin with ExitProcess, which runs no at_exit, so the closing work runs here, as
  # SceneManager.run returns or raises.
  module Run
    # What runs once at the first run, each [tag, block, log, whether it needs the DLL].
    @starts = []

    # What runs at every later run, each [tag, block, log].
    @resets = []

    # What runs as the game closes, each [tag, block, log].
    @closings = []

    # How many times the scenes started running; 2 and more are F12 resets.
    @runs = 0

    # Why the game ends on request, nil while nothing asked it to.
    @quitting = nil

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "run"

    # Runs a block once the game starts running, at the first SceneManager.run before its first
    # scene, or at once when the game runs already. A block that needs the DLL is left out without
    # it.
    #
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :dll (true when the block needs the framework's DLL), :log (where a
    #   failure is logged, such as the mod's module; the framework's log by default), :first (true
    #   to run before every block registered so far).
    # @yield Runs once.
    def self.on_start(tag, options = {}, &block)
      entry = [tag, block, options[:log], options[:dll] == true]
      return start(entry) if started?

      options[:first] ? @starts.unshift(entry) : @starts.push(entry)
      nil
    end

    # Runs a block whenever F12 starts the game's scenes again, which runs no script again.
    #
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :log (where a failure is logged).
    # @yield Runs at each reset.
    def self.on_reset(tag, options = {}, &block)
      @resets << [tag, block, options[:log]]
      nil
    end

    # Runs a block as the game closes: its scenes end on a quit, or an error ends them.
    #
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :log (where a failure is logged).
    # @yield Runs once as the game closes, before the framework's log writes its last lines.
    def self.on_close(tag, options = {}, &block)
      @closings << [tag, block, options[:log]]
      nil
    end

    # Tells whether the game's scenes started running.
    #
    # @return [Boolean] Whether they did.
    def self.started?
      @runs > 0
    end

    # Tells how many times the game's scenes started running.
    #
    # @return [Integer] 0 before the first run, 2 and more after F12.
    def self.runs
      @runs
    end

    # Ends the game: its scenes end after the current frame, or do not start again when a block of
    # an F12 reset asks. The closing work runs as at any other end.
    #
    # @param reason [String] Why, for the log's closing line.
    def self.quit(reason)
      @quitting = reason
      ::SceneManager.exit if defined?(::SceneManager) && ::SceneManager.respond_to?(:exit)
    end

    # Tells whether the game ends on request.
    #
    # @return [Boolean] Whether quit was called.
    def self.quitting?
      @quitting ? true : false
    end

    # Follows SceneManager.run, once as the framework loads.
    def self.install
      Hooks.around(SceneManager.singleton_class, :run, "Mod Framework") { |_manager, _args, original| Mod_Framework::Run.run_game(original) }
    rescue => e
      log("SceneManager.run could not be followed: #{e.class}: #{e.message}")
    end

    # Notes that the game's scenes start running: the first time runs what waits for it, every
    # later time is an F12 reset.
    def self.begin_run
      @runs += 1
      if @runs == 1
        first_run
      else
        log("F12 reset the game: its scenes start again from the title (run #{@runs}), the framework keeps its hooks and state")
        @resets.each { |entry| call(entry) }
      end
    end

    # Runs what waits for the first run, then checks that every hook is still in place.
    def self.first_run
      skipped = @starts.select { |entry| entry[3] && !Mod_Framework.available? }
      log("without the DLL these stay off: #{skipped.map { |entry| entry[0] }.join(', ')}") unless skipped.empty?
      (@starts - skipped).each { |entry| call(entry) }
      @starts = []
      log("the game runs, #{Mod_Framework.available? ? 'with' : 'without'} the DLL")
      Hooks.report(true)
    end

    # Runs a block registered with on_start, unless it needs the DLL, which is missing.
    #
    # @param entry [Array] The tag, block, log and whether it needs the DLL.
    def self.start(entry)
      return log("without the DLL #{entry[0]} stays off") if entry[3] && !Mod_Framework.available?

      call(entry)
    end

    # Counts the run, runs the game's scenes to their end and runs the closing work while the game
    # still runs: on a quit the scenes return, the window closing or an error throws out of them.
    # The scenes do not start when a block of the reset ended the game.
    #
    # @param original [Proc] Runs SceneManager.run.
    # @return [Object] What it returns.
    def self.run_game(original)
      begin_run
      result = @quitting ? nil : original.call
    rescue Exception => e
      closing(e) unless reset?(e)
      raise
    else
      closing(nil)
      result
    end

    # Runs the closing work once per ending: writes how the game closes, runs every block
    # registered with on_close and has the log write every line.
    #
    # @param error [Exception, nil] What ends the game, nil when it ends without one.
    def self.closing(error)
      return if @closed_by && @closed_by[0].equal?(error)

      @closed_by = [error]
      log(closing_text(error))
      @closings.each { |entry| call(entry) }
      Log.flush
    end

    # Tells whether an error is the game's reset by F12, which starts its scenes again and ends
    # nothing.
    #
    # @param error [Exception] The error.
    # @return [Boolean] Whether it is.
    def self.reset?(error)
      defined?(RGSSReset) && error.is_a?(RGSSReset) ? true : false
    end

    # Tells how the game closes, for the log's last line, without which a log that just stops
    # cannot tell a game closed from one that crashed.
    #
    # @param error [Exception, nil] What ends the game.
    # @return [String] The line.
    def self.closing_text(error)
      return "the game closes#{@quitting ? ": #{@quitting}" : ''}" if error.nil?
      return "the game closes: it was quit (exit status #{error.status})" if error.is_a?(SystemExit)

      "the game closes after an error: #{error.class}: #{error.message.to_s[0, 200]} at #{Array(error.backtrace).first}"
    end

    # Runs a registered block, logging its failure in its log.
    #
    # @param entry [Array] The tag, the block and its log.
    def self.call(entry)
      tag, block, logger = entry
      block.call
    rescue => e
      message = "#{tag} failed at the run: #{Logging.failure(e)}"
      logger.respond_to?(:log) ? logger.log(message) : log(message)
    end
  end
end
