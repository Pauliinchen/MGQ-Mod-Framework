#----------------------------------------------------------------
#  mods_update.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Told the player to install a needed version of a mod by hand from its page
#      Paulinchen  2026-11-07: Installed a needed update and started the game again once it was in, without the helper
#                            - Removed the way by hand through Update.bat
#      Paulinchen  2026-11-06: Stopped telling the DLL the framework booted, now that no earlier files are kept
#                            - Showed the messages of a failed update through UI.message
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-10-31: Told the needed versions in plain words
#      Paulinchen  2026-10-30: Sent JoiPlay players to the website for an update, since JoiPlay runs no helper
#                            - Told how to run Update.bat by hand under Wine or Proton
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that lists the updates of the installed mods, the framework's included.
    UPDATES_TOPIC = "mods.updates"

    # The topic that tells how a version a mod needs stands.
    REQUIRE_TOPIC = "mods.require"

    # Lists the installed mods the website offers a newer version of, the framework first.
    #
    # @return [Array<Hash>] Each {"id", "name", "folder", "installed", "latest", "framework"}; none
    #   without the DLL.
    def self.updates
      answer = Updates.ask(false)
      answer ? Array(answer["updates"]) : []
    end

    # Runs a block whenever the check finds updates other than the ones it told last: as the game
    # starts and at the title, which fetches the lists again once they are half an hour old.
    #
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :log (where a failure is logged; the framework's log by default).
    # @yield [updates] Runs with the updates, see updates.
    def self.on_updates(tag, options = {}, &block)
      Updates.on_updates([tag, block, options[:log]])
      nil
    end

    # Makes sure a mod is at least at a version: when it is older, the player is asked to update
    # it, and the update installs and the game starts again, see update_after_exit. Call it once
    # the game runs. Without the DLL, or on JoiPlay, which cannot start the game again, when it is
    # older, a message names the version needed.
    #
    # @param name [String] The mod's slug on the website, such as "level-cap", its name in Patch or
    #   its title.
    # @param version [String] The version needed, such as "0.7.0".
    # @param options [Hash] :exact (exactly that version, an older one too), :have (the version the
    #   mod knows it runs, which counts before its files'), :title (the mod's name in the texts
    #   while the lists do not know it), :reason (a sentence before the question, such as "This
    #   version cannot play online."), :action and :value (what the game does at its title once it
    #   started again, see after_restart).
    # @yield [result] Runs once it is settled.
    # @yieldparam result [Symbol] :current (nothing to do), :restarting (the update is in and the
    #   game closes to start again), :declined (the player went back), :unavailable (no version that
    #   meets the need, no way to install it here, or a mod the player installs by hand from its
    #   page on the website, which a message tells), :failed (the update did not install).
    # @return [Symbol] :current, :asking (the question shows), :waiting (for the lists), or the
    #   result when it is settled at once.
    # @raise [ArgumentError] :action is no action name, see after_restart.
    def self.require(name, version, options = {}, &done)
      raise ArgumentError, "#{options[:action].inspect} is no action name" if options[:action] && options[:action].to_s !~ ACTION_NAME

      Updates.require(name.to_s, version.to_s, options, done)
    end

    # Installs updates and starts the game again once they are in: the framework and the mods in
    # use wait for the next start, see Mods.install, and the game ends after the frame the install
    # ended in. The game goes on while they download.
    #
    # @param ids [Array<String>] The mods' ids, as updates names them; none for every update.
    # @param options [Hash] :version (of the one mod named, newer or older; the latest by default),
    #   :action and :value (what the game does at its title once it started again), :reason (why,
    #   for the log).
    # @yield [result] Runs once it is settled.
    # @yieldparam result [Symbol] :restarting (the update is in and the game closes to start
    #   again), or :failed (the update did not install, which a message tells the player, or the
    #   game cannot start again here).
    # @return [Symbol] :installing, or :failed when the install did not start.
    # @raise [ArgumentError] :action is no action name, see after_restart.
    def self.update_after_exit(ids, options = {}, &done)
      raise ArgumentError, "#{options[:action].inspect} is no action name" if options[:action] && options[:action].to_s !~ ACTION_NAME

      Updates.update_after_exit(Array(ids).map { |id| id.to_s }, options, done)
    end

    # The check of the updates as the game starts and at each title, the notice of new ones, the
    # versions mods need and the update that starts the game again once it is in.
    module Updates
      # What the player reads.
      TEXTS = {
        :title => "Update",
        :needed => "%s %s or newer is needed, and %s is installed.",
        :needed_exact => "%s %s is needed, and %s is installed.",
        :another => "another version",
        :ask => "Update downloads %s %s and starts the game again.",
        :update => "Update and restart",
        :back => "Back",
        :unavailable => "%s %s is needed but not available yet. Try again later.",
        :by_hand => "%s %s is needed. Install it by hand from its page on the website.",
        :no_dll => "%s %s is needed. Install it from mgqonline.org and start the game again."
      }

      # The blocks told of new updates, each [tag, block, log].
      @handlers = []

      # The ids and versions of the updates told last, nil before the first check.
      @told = nil

      # The needs that wait for the lists, each [name, version, options, block].
      @waiting = []

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods updates"

      # Asks the DLL for the updates.
      #
      # @param fetch [Boolean] Whether to fetch the lists again once they are old.
      # @return [Hash, nil] {"fetching", "site", "updates"}; nil without the DLL.
      def self.ask(fetch)
        return nil unless Mod_Framework.available?

        answer = Mod_Framework.bridge.call(UPDATES_TOPIC, fetch ? { "fetch" => true } : nil)
        answer.is_a?(Hash) ? answer : nil
      end

      # Keeps a block told of new updates, see Mods.on_updates.
      #
      # @param entry [Array] The tag, the block and its log.
      def self.on_updates(entry)
        @handlers << entry
      end

      # Checks the updates and tells new ones, unless the lists are being fetched.
      #
      # @param fetch [Boolean] Whether to fetch the lists again once they are old.
      def self.check(fetch)
        answer = ask(fetch)
        tell(Array(answer["updates"])) if answer && !answer["fetching"]
      end

      # Follows the end of a fetch: tells new updates and settles the needs that waited.
      def self.fetched
        check(false)
        waiting = @waiting
        @waiting = []
        waiting.each { |name, version, options, done| require(name, version, options.merge(:fetched => true), done) }
      end

      # Tells the blocks of Mods.on_updates the updates, when they differ from the ones told last.
      #
      # @param updates [Array<Hash>] The updates.
      def self.tell(updates)
        seen = updates.map { |update| [update["id"], update["latest"]] }
        return if seen == @told

        @told = seen
        return if updates.empty?

        log("updates are out: #{updates.map { |update| "#{update['name']} #{update['installed']} to #{update['latest']}" }.join(', ')}")
        @handlers.each do |tag, block, logger|
          begin
            block.call(updates)
          rescue => e
            message = "#{tag} failed to take the updates: #{Logging.failure(e)} at #{Array(e.backtrace).first}"
            logger.respond_to?(:log) ? logger.log(message) : log(message)
          end
        end
      end

      # Checks a version a mod needs, see Mods.require.
      #
      # @param name [String] The mod.
      # @param version [String] The version needed.
      # @param options [Hash] See Mods.require; :fetched once the lists were fetched for it.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] See Mods.require.
      def self.require(name, version, options, done)
        title = options[:title] || name
        return refuse(done, :unavailable, format(TEXTS[:no_dll], title, version)) unless Mod_Framework.available?

        answer = Mod_Framework.bridge.call(REQUIRE_TOPIC, "name" => name, "version" => version, "exact" => options[:exact] ? true : false,
                                                          "have" => options[:have] && options[:have].to_s)
        return finish(done, :unavailable, "#{name} #{version}: the DLL gave no answer") unless answer.is_a?(Hash)

        case answer["state"]
        when "current" then finish(done, :current, nil)
        when "update" then offer(answer, version, options, done)
        when "by_hand" then by_hand(answer, version, done)
        when "unknown"
          return unavailable(answer, version, options, done) if options[:fetched]

          log("#{name} #{version} waits for the mod lists")
          @waiting << [name, version, options, done]
          :waiting
        else unavailable(answer, version, options, done)
        end
      end

      # Asks the player to update a mod to the version offered, or names the version needed where
      # the game cannot start itself again.
      #
      # @param answer [Hash] The DLL's answer, see ModsTopics.RequireTopic.
      # @param version [String] The version needed.
      # @param options [Hash] See Mods.require.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] :asking, or the result when the question could not open or the game
      #   cannot start itself again.
      def self.offer(answer, version, options, done)
        name = answer["name"].to_s
        return refuse(done, :unavailable, format(TEXTS[:no_dll], name, version)) unless Updates.restarts?

        offered = answer["offered"].to_s
        needed = format(options[:exact] ? TEXTS[:needed_exact] : TEXTS[:needed], name, version, answer["installed"] || TEXTS[:another])
        question = [options[:reason], needed, format(TEXTS[:ask], name, offered)].compact.join(" ")
        asked = UI::Engine::Confirm.ask(question, [TEXTS[:update], TEXTS[:back]]) do |yes|
          Mod_Framework::Mods::Updates.answered(yes, answer, options, done)
        end
        return finish(done, :declined, "the question about #{name} #{offered} could not open") unless asked

        log("asked to update #{name} to #{offered}")
        :asking
      end

      # Follows the player's answer to the update: it installs, and the game starts again.
      #
      # @param yes [Boolean] Whether the player picked the update.
      # @param answer [Hash] The DLL's answer.
      # @param options [Hash] See Mods.require.
      # @param done [Proc, nil] Told the result.
      def self.answered(yes, answer, options, done)
        name = answer["name"].to_s
        offered = answer["offered"].to_s
        return finish(done, :declined, "the player did not update #{name}") unless yes

        update_after_exit([answer["id"].to_s], { :version => options[:exact] ? offered : nil, :action => options[:action], :value => options[:value],
                                                 :reason => "#{name} #{offered} is needed" }, lambda { |result| Mod_Framework::Mods::Updates.finish(done, result, nil) })
      end

      # Tells the player that no version meets a need.
      #
      # @param answer [Hash] The DLL's answer.
      # @param version [String] The version needed.
      # @param options [Hash] See Mods.require.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] :unavailable.
      def self.unavailable(answer, version, options, done)
        name = options[:title] && answer["id"].nil? ? options[:title] : answer["name"].to_s
        UI.message(format(TEXTS[:unavailable], name, version), :title => TEXTS[:title]) if UI.respond_to?(:message)
        finish(done, :unavailable, "no version of #{name} meets #{version}")
      end

      # Tells the player to install the version a mod needs by hand from its page on the website.
      #
      # @param answer [Hash] The DLL's answer.
      # @param version [String] The version needed.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] :unavailable.
      def self.by_hand(answer, version, done)
        name = answer["name"].to_s
        UI.message(format(TEXTS[:by_hand], name, version), :title => TEXTS[:title]) if UI.respond_to?(:message)
        finish(done, :unavailable, "#{name} #{version} is installed by hand")
      end

      # Installs updates and starts the game again once they are in, see Mods.update_after_exit.
      #
      # @param ids [Array<String>] The mods' ids; none for every update.
      # @param options [Hash] See Mods.update_after_exit.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] :installing or :failed.
      def self.update_after_exit(ids, options, done)
        what = ids.empty? ? "every update" : ids.join(", ")
        return finish(done, failed(what, Mod_Framework.available? ? "JoiPlay cannot start the game again" : "there is no DLL"), nil) unless Updates.restarts?

        ids = Mods.updates.map { |update| update["id"].to_s } if ids.empty?
        versions = options[:version] ? { ids[0] => options[:version].to_s } : {}
        reason = options[:reason] || "the player updates #{what}"
        started = Mods.install(ids, :versions => versions) { |names, error| Mod_Framework::Mods::Updates.installed(what, reason, names, error, options, done) }
        return :failed unless started

        log("#{reason}: installs #{what}, then the game starts again")
        :installing
      end

      # Follows the end of an update's install: once it is in, the game starts again; a failure
      # tells the player why.
      #
      # @param what [String] What it installed, for the log.
      # @param reason [String] Why, for the log.
      # @param names [Array<String>] The names of the mods installed; none when it failed.
      # @param error [String, nil] Why it failed, for the player.
      # @param options [Hash] See Mods.update_after_exit.
      # @param done [Proc, nil] Told the result.
      # @return [Symbol] :restarting or :failed.
      def self.installed(what, reason, names, error, options, done)
        if error || names.empty?
          UI.buzz
          UI.message(error || format(Install::FAILED_TEXT, what), :title => TEXTS[:title])
          return finish(done, failed(what, error.to_s), nil)
        end

        Mods.restart(reason, options[:action], options[:value])
        finish(done, :restarting, nil)
      end

      # Tells whether the game can update a mod in use and start itself again: the DLL works, and
      # the game does not run on JoiPlay, which closes instead.
      #
      # @return [Boolean] Whether it can.
      def self.restarts?
        Mod_Framework.available? && Mod_Framework.platform != Mod_Framework::JOIPLAY
      end

      # Logs an update that could not start.
      #
      # @param what [String] What it would have installed.
      # @param why [String] Why not.
      # @return [Symbol] :failed.
      def self.failed(what, why)
        log("the update of #{what} could not start: #{why}")
        :failed
      end

      # Tells the player a need that cannot be met here in a message box, which waits for them, as
      # the game's own msgbox does on every platform.
      #
      # @param done [Proc, nil] Told the result.
      # @param result [Symbol] The result.
      # @param text [String] The message.
      # @return [Symbol] The result.
      def self.refuse(done, result, text)
        msgbox(text) if Kernel.respond_to?(:msgbox, true)
        finish(done, result, text)
      rescue => e
        log("the message could not show: #{Logging.failure(e)}")
        finish(done, result, text)
      end

      # Tells a need's block its result, logging its failure.
      #
      # @param done [Proc, nil] The block.
      # @param result [Symbol] The result.
      # @param why [String, nil] Why, for the log; nil for nothing to log.
      # @return [Symbol] The result.
      def self.finish(done, result, why)
        log("#{why}: #{result}") if why
        done.call(result) if done
        result
      rescue => e
        log("the block of a need failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        result
      end

      # Checks the updates at each title, fetching the lists again once they are old.
      def self.install
        return unless defined?(::Scene_Base) && ::Scene_Base.method_defined?(:post_start)

        Hooks.after(::Scene_Base, :post_start, LOG_TAG) { Mod_Framework::Mods::Updates.check(true) if defined?(::Scene_Title) && is_a?(::Scene_Title) }
      rescue => e
        log("the check at the title could not be added: #{Logging.failure(e)}")
      end
    end

    Run.on_start(Updates::LOG_TAG, :dll => true) do
      Mod_Framework::Mods::Updates.install
      Mod_Framework::Mods::Updates.check(false)
    end
    Mod_Framework.bridge.on(FETCHED_TOPIC) { |_event| Mod_Framework::Mods::Updates.fetched }
  end
end
