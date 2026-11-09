#----------------------------------------------------------------
#  mods_install.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Named the mods in use, whose updates wait for the next start
#      Paulinchen  2026-11-06: Installed a mod at the version asked with :versions
#      Paulinchen  2026-10-31: Told a failed install without its cause, which the log keeps, and a refusal alone
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that starts installing mods of the website.
    INSTALL_TOPIC = "mods.install"

    # The event that tells how far an install came.
    INSTALLING_TOPIC = "mods.installing"

    # The event once an install ended.
    INSTALLED_TOPIC = "mods.installed"

    # Installs mods of the website into the Patch folder, from the lists the DLL
    # fetched, while the game goes on: the DLL downloads them one after another, checks every file
    # against the lists and writes them together, so a failure changes nothing. The framework and
    # the mods in use (see Mods.in_use) wait in the waiting folder until the game starts again; the
    # others are in place at once. One install runs at a time. A mod installed is on unless the
    # player turned a mod of that name off before; turn it on with Mods.set.
    #
    # @param ids [Array<String>] The mods' ids, as Mods.state and Mods.check name them.
    # @param options [Hash] :progress (a block of the mods downloaded, the mods to install and the
    #   name of the mod downloading now, nil while the files are written), :versions (the version
    #   to write of each id, such as { "site:level-cap" => "1.5.0" }; the latest when left out).
    # @yield [installed, error] Runs once the install ended, or at once when it was refused.
    # @yieldparam installed [Array<String>] The names of the mods installed; none when it failed.
    # @yieldparam error [String, nil] Why it failed, for the player, such as "Map Display could not
    #   be installed."; nil when it did not.
    # @return [Boolean] Whether it started.
    def self.install(ids, options = {}, &done)
      versions = Hash[(options[:versions] || {}).map { |id, version| [id.to_s, version.to_s] }]
      Install.start(Array(ids).map { |id| id.to_s }, versions, options[:progress], done)
    end

    # Starts the installs and hands their events to the blocks of the one that runs.
    module Install
      # What the player reads when the DLL is missing.
      NO_DLL_TEXT = "Mods cannot be installed from the game here."

      # What the player reads when a mod could not be installed.
      FAILED_TEXT = "%s could not be installed."

      # The blocks of the install that runs, [progress, done], nil while none runs.
      @running = nil

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods install"

      # Starts an install, see Mods.install.
      #
      # @param ids [Array<String>] The mods' ids.
      # @param versions [Hash{String => String}] The version to write of each id, see Mods.install.
      # @param progress [Proc, nil] Told how far it came.
      # @param done [Proc, nil] Told how it ended.
      # @return [Boolean] Whether it started.
      def self.start(ids, versions, progress, done)
        request = { "ids" => ids, "running" => Mods.in_use }
        request["versions"] = versions unless versions.empty?
        answer = Mod_Framework.available? ? Mod_Framework.bridge.call(INSTALL_TOPIC, request) : nil
        unless answer.is_a?(Hash) && answer["started"]
          why = answer.is_a?(Hash) ? answer["refused"].to_s : NO_DLL_TEXT
          log("did not install #{ids.join(', ')}: #{why}")
          call(done, [], why)
          return false
        end

        log("installs #{ids.join(', ')}")
        @running = [progress, done]
        true
      end

      # Tells the install's block how far it came.
      #
      # @param event [Hash] {"done", "total", "mod"}.
      def self.installing(event)
        progress = @running && @running[0]
        progress.call(event["done"].to_i, event["total"].to_i, event["mod"]) if progress
      rescue => e
        log("the progress block of an install failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end

      # Tells the install's block how it ended.
      #
      # @param event [Hash] {"installed", "mod", "error"}.
      def self.installed(event)
        return unless @running

        done = @running[1]
        @running = nil
        error = event["error"] ? format(FAILED_TEXT, event["mod"] || "A mod") : nil
        log(error ? "the install of #{event['mod'] || 'a mod'} failed: #{event['error']}" : "installed #{Array(event['installed']).join(', ')}")
        call(done, Array(event["installed"]), error)
      end

      # Calls a block that is told how an install ended, logging its failure.
      #
      # @param done [Proc, nil] The block.
      # @param installed [Array<String>] The names of the mods installed.
      # @param error [String, nil] Why it failed.
      def self.call(done, installed, error)
        done.call(installed, error) if done
      rescue => e
        log("the block of an install failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end
    end

    Mod_Framework.bridge.on(INSTALLING_TOPIC) { |event| Mod_Framework::Mods::Install.installing(event) }
    Mod_Framework.bridge.on(INSTALLED_TOPIC) { |event| Mod_Framework::Mods::Install.installed(event) }
  end
end
