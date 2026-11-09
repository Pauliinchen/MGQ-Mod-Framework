#----------------------------------------------------------------
#  hooks.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Ran the original of around through a plain object instead of a lambda made at every call
#      Paulinchen  2026-10-30: Counted the hooks on a method
#                            - Added outermost blocks
#                            - Logged a registration after the run at once
#      Paulinchen  2026-10-28: Moved into the Mod Framework from core_hooks.rbx
#                            - Logged a failing block in the log of the mod that registered it
#                            - Checked in report that every wrap is still in place
#                            - Left holding the player to MGQ Online
#      Paulinchen  2026-10-12: Let around run the original with other arguments
#      Paulinchen  2026-10-08: Counted and named the distinct methods in report
#                            - Kept a wrap of around only once the method was wrapped
#                            - Logged the hooks as one line per script through report
#      Paulinchen  2026-10-07: Gave around the script that registers
#                            - Logged each hook, each wrap and who holds the player
#      Paulinchen  2026-10-06: Kept the map's menu shut through MGQ_MpGame
#      Paulinchen  2026-10-04: Renamed from mp_hooks.rbx
#      Paulinchen  2026-10-03: Added around and hold_player
#                            - Logged through MGQ_MpLog
#                            - Kept each method's blocks ready in their order
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # Wraps the game methods several mods follow, such as Scene_Map#update, once each, and runs the
  # blocks the mods register before, after or around them.
  #
  # Mods register here instead of wrapping a method themselves, so none depends on how the others
  # wrapped it. A failing block is logged in the log of the mod that registered it: a log is any
  # object with a log(message) method, such as a mod's own module.
  module Hooks
    # The original of a method around wrapped, for one call, which the wrap's block runs.
    #
    # A plain object, since a lambda made at every call of a hot method carries the whole call along,
    # and one shared by the wrap would mix up the calls of fibers that wait inside the method.
    class Original
      # @return [Exception, nil] What the original raised, so the wrap does not log it as its block's
      #   failure.
      attr_reader :raised

      # Keeps the call.
      #
      # @param object [Object] The object the method runs on.
      # @param name [Symbol] The original's name.
      # @param args [Array] The method's arguments.
      # @param block [Proc, nil] The method's block.
      def initialize(object, name, args, block)
        @object = object
        @name = name
        @args = args
        @block = block
      end

      # Runs the original with the method's arguments, or with those it is given.
      #
      # @param given [Array] Other arguments; none for the method's own.
      # @return [Object] What the original returns.
      def call(*given)
        @object.send(@name, *(given.empty? ? @args : given), &@block)
      rescue Exception => raised
        @raised = raised
        raise
      end
    end

    # The blocks by method, then by when they run, then by the tag that registered them: each
    # [block, log, whether it stays outermost].
    @blocks = {}

    # The blocks by method, then by when they run, as each wrap runs them: [tag, block, log] in
    # their order. Every wrap holds its own two lists, which a registration fills anew.
    @ready = {}

    # The original of each wrapped method by method.
    @originals = {}

    # How many methods around wrapped, which names each one's original.
    @arounds = 0

    # The body of each tag's wrap by method and tag, in a cell the wrap reads, [block, log], so a
    # tag registering again replaces its body instead of wrapping the method once more.
    @bodies = {}

    # The methods each tag followed and wrapped since report last wrote them, by the tag: two
    # hashes whose keys name each method once, such as "Scene_Map#update".
    @installed = {}

    # The newest wrap of each method by method, which report compares the method with: the wrap and
    # a cell the wrap marks once it ran.
    @wraps = {}

    # The methods report found defined again after their wrap, so each is logged once.
    @replaced = {}

    # Whether the run's report was written, after which each registration is logged at once.
    @live = false

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "hooks"

    # Runs a block before a game method, on the object the method runs on and with its arguments.
    #
    # The blocks run as nested wraps would, so the first tag to register stays closest to the
    # game's method: before blocks run from the last registered to the first.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @param tag [String] Who registers, such as the mod's name; a second registration of the same
    #   tag replaces the first.
    # @param logger [#log, nil] Where a failing block is logged, such as the mod's module; nil for
    #   the framework's log.
    # @yield [*args] Runs with the object as self and the method's arguments.
    def self.before(owner, name, tag, logger = nil, &block)
      register(owner, name, :before, tag, logger, block)
    end

    # Runs a block after a game method, on the object the method runs on and with its arguments.
    # The method's result is returned unchanged.
    #
    # After blocks run from the first registered to the last, see before.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @param tag [String] Who registers; a second registration of the same tag replaces the first.
    # @param logger [#log, nil] Where a failing block is logged; nil for the framework's log.
    # @yield [*args] Runs with the object as self and the method's arguments.
    def self.after(owner, name, tag, logger = nil, &block)
      register(owner, name, :after, tag, logger, block)
    end

    # Runs a block before or after a game method outside every block of the other tags, however
    # late they register: an outermost before block runs first, an outermost after block last.
    #
    # The framework's frame work follows Graphics.update this way, so a mod loaded after the game
    # started still runs its hooks inside the framework's frame.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @param moment [Symbol] :before or :after.
    # @param tag [String] Who registers; a second registration of the same tag replaces the first.
    # @param logger [#log, nil] Where a failing block is logged; nil for the framework's log.
    # @yield [*args] Runs with the object as self and the method's arguments.
    def self.outermost(owner, name, moment, tag, logger = nil, &block)
      register(owner, name, moment, tag, logger, block, true)
    end

    # Wraps a game method in a block that decides when the original runs and what the method
    # returns, for a hook that changes what the method does. A tag registering again replaces its
    # block instead of wrapping the method a second time.
    #
    # The block's errors reach the game as the method's own would, logged once in the block's log
    # when the block itself failed; a method not defined yet raises and keeps nothing, so a later
    # try wraps it.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @param tag [String] Who registers; a second registration of the same tag replaces the first.
    # @param logger [#log, nil] Where a failing block is logged; nil for the framework's log.
    # @yieldparam object [Object] The object the method runs on.
    # @yieldparam args [Array] The method's arguments.
    # @yieldparam original [Original] Its call runs the original with the arguments, or with those it
    #   is given, and returns its result.
    # @yieldreturn [Object] What the method returns.
    def self.around(owner, name, tag, logger = nil, &body)
      key = [owner, name, tag]
      if (cell = @bodies[key])
        cell.replace([body, logger])
        log("#{tag} wrapped #{named(owner, name)} again")
        return
      end

      original = :"mod_framework_around_#{@arounds + 1}_#{name.to_s.gsub(/[?!=]/, '_')}"
      was_private = owner.private_method_defined?(name)
      owner.send(:alias_method, original, name)
      @arounds += 1
      cell = [body, logger]
      ran = [false]
      label = "around #{named(owner, name)}"
      owner.send(:define_method, name) do |*args, &block|
        ran[0] = true
        call_original = ::Mod_Framework::Hooks::Original.new(self, original, args, block)
        begin
          cell[0].call(self, args, call_original)
        rescue => error
          ::Mod_Framework::Hooks.failed(cell[1], cell[0], "#{tag} failed #{label}: #{error.class}: #{error.message}") unless error.equal?(call_original.raised)
          raise
        end
      end
      owner.send(:private, name) if was_private
      @bodies[key] = cell
      note_wrap(owner, name, ran)
      count(tag, 1, owner, name)
    end

    # Tells how many tags follow or wrap a method, which grows as a mod hooks it.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @return [Integer] The before, after and around registrations together.
    def self.hooked(owner, name)
      blocks = @blocks[[owner, name]]
      followed = blocks ? blocks[:before].size + blocks[:after].size : 0
      followed + @bodies.keys.count { |each_owner, each_name, _tag| each_owner == owner && each_name == name }
    end

    # Keeps a block, wrapping the method the first time.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @param moment [Symbol] :before or :after.
    # @param tag [String] Who registers.
    # @param logger [#log, nil] Where the block's failure is logged.
    # @param block [Proc] What runs.
    # @param outer [Boolean] Whether it stays outside the blocks of the other tags.
    def self.register(owner, name, moment, tag, logger, block, outer = false)
      ready = @ready[[owner, name]] ||= { :before => [], :after => [] }
      wrap(owner, name, ready)
      blocks = @blocks[[owner, name]] ||= { :before => {}, :after => {} }
      again = blocks[moment].key?(tag)
      blocks[moment][tag] = [block, logger, outer]
      ready[:before].replace(listed(blocks[:before], true).reverse + listed(blocks[:before], false).reverse)
      ready[:after].replace(listed(blocks[:after], false) + listed(blocks[:after], true))
      again ? log("#{tag} follows #{named(owner, name)} (#{moment}, registered again)") : count(tag, 0, owner, name)
    rescue => e
      log("#{tag} could not follow #{named(owner, name)}: #{e.class}: #{e.message}")
    end

    # Lists the outermost blocks of a moment, or the others, in the order they registered.
    #
    # @param blocks [Hash] Each tag's [block, log, outer], in the order they registered.
    # @param outer [Boolean] Whether to list the outermost blocks.
    # @return [Array<Array>] Each [tag, block, log] in that order.
    def self.listed(blocks, outer)
      blocks.select { |_tag, entry| entry[2] == outer }.map { |tag, entry| [tag, entry[0], entry[1]] }
    end

    # Wraps a method once, keeping the original under a name of its own.
    #
    # The name counts the wraps, since a subclass's method of the same name may be wrapped too, and
    # a shared name would then call the subclass's original from the superclass's wrap.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @param ready [Hash] The method's blocks as the wrap runs them, see @ready.
    def self.wrap(owner, name, ready)
      return if @originals[[owner, name]]

      original = :"mod_framework_hooks_#{@originals.size + 1}_#{name.to_s.gsub(/[?!=]/, '_')}"
      was_private = owner.private_method_defined?(name)
      before = ready[:before]
      after = ready[:after]
      before_label = "before #{named(owner, name)}"
      after_label = "after #{named(owner, name)}"
      ran = [false]
      owner.send(:alias_method, original, name)
      owner.send(:define_method, name) do |*args, &block|
        ran[0] = true
        ::Mod_Framework::Hooks.run(self, before, before_label, args) unless before.empty?
        result = send(original, *args, &block)
        ::Mod_Framework::Hooks.run(self, after, after_label, args) unless after.empty?
        result
      end
      owner.send(:private, name) if was_private
      @originals[[owner, name]] = original
      note_wrap(owner, name, ran)
    end

    # Keeps a method's newest wrap, which report compares the method with.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @param ran [Array<Boolean>] The cell the wrap marks once it ran.
    def self.note_wrap(owner, name, ran)
      @wraps[[owner, name]] = [owner.instance_method(name), ran]
      @replaced.delete([owner, name])
    end

    # Notes a method a tag followed or wrapped, for report; once the run's report was written, it
    # writes the line at once, since no later report comes.
    #
    # @param tag [String] Who registered.
    # @param kind [Integer] 0 for a method followed, 1 for one wrapped.
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    def self.count(tag, kind, owner, name)
      (@installed[tag] ||= [{}, {}])[kind][named(owner, name)] = true
      report if @live
    end

    # Names a method for the log, a module's own method as Graphics.update and a class's instance
    # method as Scene_Map#update.
    #
    # @param owner [Module] The class that has the method, the singleton class for a module's
    #   method.
    # @param name [Symbol] The method.
    # @return [String] The name.
    def self.named(owner, name)
      single = owner.inspect[/\A#<Class:([\w:]+)>\z/, 1]
      single ? "#{single}.#{name}" : "#{owner}##{name}"
    end

    # Writes how many methods each tag followed and wrapped since the last report, and which, one
    # line per tag; asked to check, also logs each method defined again after its wrap, once.
    #
    # The game's plugins load after the mods, and some define a method again with a plain def, which
    # drops the wraps the mods put on it; the framework checks for that as the game starts running.
    #
    # @param check [Boolean] Whether to check that each wrap is still in place, as the run's report
    #   does.
    def self.report(check = false)
      @live = true if check
      @installed.each do |tag, (followed, wrapped)|
        named = [["follows", followed], ["wraps", wrapped]].reject { |_, methods| methods.empty? }
        log("#{tag}: follows #{followed.size}, wraps #{wrapped.size} game method(s): " +
            named.map { |verb, methods| "#{verb} #{methods.keys.join(', ')}" }.join("; "))
      end
      @installed.clear
      check_wraps if check
    rescue => e
      log("hook report failed: #{e.class}: #{e.message}")
    end

    # Logs each wrapped method that a later definition replaced or wrapped again, once, unless its
    # wrap ran since, which shows the later definition calls it.
    #
    # A wrap that ran only before the later definition replaced it is taken for one still in place.
    def self.check_wraps
      @wraps.each do |(owner, name), (wrap, ran)|
        next if @replaced[[owner, name]] || ran[0] || owner.instance_method(name) == wrap

        @replaced[[owner, name]] = true
        log("#{named(owner, name)} was defined again after its hooks were installed; they run only if the new definition calls the old one")
      end
    end

    # Runs the blocks registered for a moment of a method, logging a failing one once in its log.
    #
    # @param object [Object] The object the method runs on.
    # @param hooks [Array<Array>] Each tag, block and log, in the order they run.
    # @param label [String] The moment and the method, for the log.
    # @param args [Array] The method's arguments.
    def self.run(object, hooks, label, args)
      hooks.each do |tag, block, logger|
        begin
          object.instance_exec(*args, &block)
        rescue => e
          failed(logger, block, "#{tag} failed #{label}: #{e.class}: #{e.message}")
        end
      end
    end

    # Logs a block's failure once, in the log it was registered with, else in the framework's.
    #
    # @param logger [#log, nil] The block's log.
    # @param block [Proc] The block, which tells its failure from others.
    # @param message [String] The line.
    def self.failed(logger, block, message)
      return unless Logging.first_time?(self, block)

      logger.respond_to?(:log) ? logger.log(message) : log(message)
    rescue
      log(message)
    end
  end
end
