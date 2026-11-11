#----------------------------------------------------------------
#  mods_loader.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Read the database again once a mod wrapped DataManager.load_normal_database too
#      Paulinchen  2026-11-09: Logged the scripts and framework copies in a Patch folder inside Patch and named their folders in a message
#      Paulinchen  2026-11-08: Forgot the remembered hotkeys of the mods that loaded once the boot and the entering loaded them
#      Paulinchen  2026-11-07: Named the mods in use, whose updates wait for the next start
#                            - Took disabled: instead of enabled: for a title command
#                            - Removed holding?, which nothing called
#      Paulinchen  2026-11-06: Loaded a plain Title script whole at the title, without splitting it
#                            - Read the database again through DataManager.load_database alone, without keeping the data files in memory
#                            - Stopped skipping the framework's old entry file, which no release had
#                            - Removed the old UI scan before a mod loads; a mod that calls the old UI now stops at its NameError as any failing script does
#                            - Showed the message of the mods that failed to load through UI.message
#                            - Read the scripts in a mod's folder that the mod loads itself for calls of the old UI too, before
#                              any script of the mod runs, and each script only once
#                            - Read every script of a mod or part for calls of the old UI before any of them runs, a split
#                              Title mod too
#                            - Called the engine's classes by their names under UI::Engine
#                            - Stopped a mod whose script the old UI scan refuses before it runs
#                            - Put the mods' rows of the title's Mods box only into the list of the box on the UI layer
#      Paulinchen  2026-11-05: Put the mods' title commands on the title's commands, and their rows into the list of the title's
#                              Mods box, through UI.patch, so other mods may patch them; none goes to the title without the DLL
#      Paulinchen  2026-11-04: Read each mod script for calls of the old UI before it runs
#      Paulinchen  2026-11-03: Forgot why a mod failed to load once its scripts changed and told a failure of this game
#                              session apart
#      Paulinchen  2026-11-01: Ran a title command's block with the window only when it takes it
#                            - Put a title command into the title's Mods box with :in => :mods
#                            - Gave the title's commands the keys again once the roots a title command opened closed
#      Paulinchen  2026-10-31: Named the mods that did not load without pointing to the log
#                            - Read the database again from what its first read took into memory, and only for a Data mod that loaded
#                            - Showed a title command only while its :if allows
#      Paulinchen  2026-10-30: Split a plain Title script into its title screen parts and the rest
#                            - Kept the mods turned on and off at a title that counts as entered for the restart
#                            - Loaded only the title part of a Title mod at the title and the rest as the player enters,
#                              only for the mods of the session
#                            - Loaded the scripts of a folder mod under every game loader
#                            - Logged the plan's warnings of mods that do not work together and of load order hints
#                            - Put the framework's box of Mods and Mod browser on the title at the boot
#                            - Kept why a mod failed to load for the next game session, loaded the Title mods turned on
#                              at the title and hid the title commands of those turned off
#                            - Let the player enter again at a title that came without a restart
#                            - Noted whether a Regular or Data mod ran
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The tags whose mods load as the game starts running, before its first scene.
    BOOT_TAGS = %w[Framework Title]

    # The tags whose mods load as the player enters the game, in the order they load.
    ENTERING_TAGS = %w[Regular Data]

    # The tag of the mods that change the game's data, after which entering reads the database
    # again.
    DATA = "Data"

    # The tag of the mods that run from the start of the game until it ends.
    FRAMEWORK_TAG = "Framework"

    # The tag of the mods whose title part loads at the start of the game and whose rest loads as
    # the player enters it.
    TITLE_TAG = "Title"

    # The extension of a mod's scripts only the mod loads, through load_part.
    PART = ".rbx"

    # The names of the framework's entry file, which a mod that embeds the framework may ship in its
    # folder and the loader skips, since the framework booted already, and of the game's loader.
    SKIPPED = ["!Mod_Framework.rb", "Patch.rb"]


    # Tells the folder of a mod in the Patch folder, which holds its files beside its script.
    #
    # @param name [String, nil] The mod's name; nil for the mod whose script calls: the nearest
    #   script on the call stack that belongs to a mod, else the mod loading now.
    # @return [String, nil] The folder relative to the game folder, such as "Patch/Camp_Notes";
    #   nil for a mod without a folder and for a caller that belongs to no mod.
    def self.folder(name = nil)
      name = name ? names.find { |each| each.casecmp(name.to_s) == 0 } : Loader.calling_mod
      place = name ? "#{FOLDER}/#{name}" : nil
      place && File.directory?(place) ? place : nil
    end

    # Runs a block as the player enters the game, before the Regular mods load, or at once when the
    # player entered already. A Title mod loads the rest of it here, past its title part; its
    # block runs only when the mod is among the mods of the session, and running it counts as
    # code in the game, which only a restart takes out again.
    #
    # @param tag [String] Who registers, for the log.
    # @param options [Hash] :log (where a failure is logged, such as the mod's module; the
    #   framework's log by default).
    # @yield Runs once.
    def self.on_enter(tag, options = {}, &block)
      Loader.on_enter([tag, block, options[:log], Loader.calling_mod])
      nil
    end

    # Loads a part of the calling mod once per game session, such as what its title command
    # needs. Its scripts are evaluated as the loader evaluates a mod's own.
    #
    # @param path [String] A script, or a folder whose .rbx scripts load sorted by their paths,
    #   relative to the calling mod's folder (to the game folder for a caller in no mod's folder).
    # @return [Boolean] Whether it loaded now: false when it loaded before, is missing or failed,
    #   each logged.
    def self.load_part(path)
      Loader.load_part(path, Loader.calling_mod)
    end

    # Adds a command to the game's title screen, before Shutdown unless the options place it, or
    # a row to the end of the title's Mods box. Picking it counts the calling mod as used in this
    # game session. A Title mod that adds one, or registers an on_enter block, says that its .rb
    # files are only its title part and the rest loads in its on_enter blocks.
    #
    # The command goes onto the title's commands through a UI.patch of "Window_TitleCommand", and
    # the row into the box's list through a UI.patch of "#mf_title_mods_list", so other mods patch
    # them by the symbol as their id. Without the DLL the box does not show, and neither do its rows.
    #
    # @param name [String] The command's name.
    # @param options [Hash] :in (:mods for the title's Mods box, beside :mods_browser, :mods_list
    #   and :mods_config), :symbol (the command's symbol, made from the mod and the name by
    #   default), :after and :before (the symbol it goes after or before), :disabled and :if (true,
    #   false or a block), :icon, :badge (a count, true for a dot, or a block) and :badge_color.
    # @yield [window] Runs when the player picks it, with the title's commands; the title's
    #   commands, or the box, take the keys again once the windows it opened closed; a failure is
    #   logged.
    # @yieldreturn [Object] :off to leave the title's commands off, which then gets them back itself.
    # @return [Symbol, nil] The command's symbol, nil when the game has no title commands.
    def self.title_command(name, options = {}, &block)
      Loader.title_command(name.to_s, options, Loader.calling_mod, block)
    end

    # Enters the game once per game session, and once more after each title that came without a
    # restart: loads the mods that load on entering and did not load yet, runs the on_enter
    # blocks once and forgets the remembered hotkeys the mods that run no longer define. New Game and the load of a save enter by themselves; a mod with a way of its
    # own into the game calls it before that way sets up or loads the game.
    #
    # @param reason [String] What enters, for the log.
    # @param options [Hash] :only (the names of the mods of the session, such as a world's: of the
    #   mods that are on, only these load, but the Framework mods, which run already; every mod
    #   that is on by default).
    # @return [Boolean] Whether this call entered, false when the game was entered before.
    def self.enter(reason, options = {})
      Loader.enter(reason.to_s, options[:only] && Array(options[:only]).map(&:to_s))
    end

    # Tells whether a mod runs until the game starts again, whatever the player turns off or a
    # world leaves out: a Framework mod that loaded, a Title mod that loaded whole as a Framework
    # mod, a mod the game's loader ran before the framework booted, and once the player entered the
    # game any mod that loaded but a Title mod whose rest did not.
    #
    # @param name [String] The mod's name.
    # @return [Boolean] Whether it does.
    def self.running?(name)
      Loader.running?(name)
    end

    # Lists the mods that run until the game starts again, see running?, such as for a world that
    # leaves the other mods out to name.
    #
    # @return [Array<String>] Their names in the order they loaded.
    def self.stays_on
      loaded.select { |name| running?(name) }
    end

    # Lists the mods whose files must not change under the game: those that run, see running?,
    # and the Title mods whose command was used. Their updates wait for the next start.
    #
    # @return [Array<String>] Their names in the order they loaded.
    def self.in_use
      loaded.select { |name| running?(name) || used?(name) }
    end

    # Tells whether a Title mod that loaded loads whole as a Framework mod: it registered no title
    # command and no on_enter block. Such a mod counts as a Framework mod in every way until the
    # game starts again; Mods.ini keeps its tag.
    #
    # @param name [String] The mod's name.
    # @return [Boolean] Whether it does; false for a mod that did not load as a Title mod.
    def self.loads_as_framework?(name)
      Loader.loads_as_framework?(name)
    end

    # Tells whether the player entered the game in this game session.
    #
    # @return [Boolean] Whether they did.
    def self.entered?
      Loader.entered?
    end

    # Lists the managed mods loaded in this game session.
    #
    # @return [Array<String>] Their names in the order they loaded, a mod the game's loader ran
    #   before the framework booted first.
    def self.loaded
      Loader.loaded
    end

    # Holds the scripts of the Patch folder back from the game's loader while its loop runs, so that
    # each mod loads at the stage of its tag, if it is on: from the framework's boot until the game
    # runs, File.read of a script in Patch answers an empty text, which the loader evaluates to
    # nothing, and notes the script.
    #
    # The English translation's loader and the untranslated game's read Patch/**/*.rb, the Russian
    # translation's Patch.rb only the scripts at the top of Patch, each by File.read; the framework's
    # entry file sorts before every mod, so the loaders read the mods after it.
    module Hold
      # The scripts the game's loader read while they were held, in the order it read them.
      @held = []

      # Whether the scripts are held now.
      @holding = false

      # The method File.read had of its own before the hold, nil when it came from IO.
      @replaced = nil

      # Whether the game's loader reads the scripts in the folders of Patch; nil before the hold
      # ended.
      @deep = nil

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods"

      # Starts holding the scripts back, once per game session.
      def self.start
        return if @holding || !@deep.nil?

        owner = ::File.singleton_class
        @replaced = owner.instance_methods(false).include?(:read) ? owner.instance_method(:read) : nil
        owner.send(:define_method, :read) { |*args, &block| ::Mod_Framework::Mods::Hold.read(args, block) }
        owner.send(:ruby2_keywords, :read) if owner.respond_to?(:ruby2_keywords, true)
        @holding = true
      end

      # Ends the hold and puts File.read back as it was; notes whether the loader read the scripts
      # in the folders of Patch, which it did unless such scripts lay there and it read none.
      def self.stop
        return unless @holding

        @holding = false
        owner = ::File.singleton_class
        @replaced ? owner.send(:define_method, :read, @replaced) : owner.send(:remove_method, :read)
        @replaced = nil
        nested = Dir.glob("#{FOLDER}/*/**/*#{SCRIPT}").select { |path| Mods.name_of(path) }
        @deep = nested.empty? || @held.any? { |path| path.count("/") > 1 }
        log("held back #{@held.size} #{@held.size == 1 ? 'script' : 'scripts'} from the game's loader#{@deep ? '' : ', which reads no script in the folders of Patch'}")
      end

      # Lists the scripts the game's loader read while they were held.
      #
      # @return [Array<String>] Their paths relative to the game folder, in the order it read them.
      def self.held
        @held.dup
      end

      # Reads a file as File.read does, but a script of the Patch folder while the hold lasts.
      #
      # @param args [Array] File.read's arguments.
      # @param block [Proc, nil] Its block.
      # @return [String] The file's text; an empty one for a script held back.
      def self.read(args, block)
        path = held_path(args[0])
        return original_read(args, block) unless path

        @held << path unless @held.include?(path)
        ""
      end

      # Reads a file through the File.read of before the hold.
      #
      # @param args [Array] Its arguments.
      # @param block [Proc, nil] Its block.
      # @return [String] The file's text.
      def self.original_read(args, block)
        @replaced ? @replaced.bind(::File).call(*args, &block) : ::IO.read(*args, &block)
      end

      # Tells whether a path is a script the hold keeps back: a .rb in Patch, but the game's loader.
      #
      # @param path [Object] The path File.read was given.
      # @return [String, nil] The path relative to the game folder with forward slashes; nil for
      #   any other file and while nothing is held.
      def self.held_path(path)
        return nil unless @holding && path.is_a?(String)

        relative = path.tr("\\", "/").sub(%r{\A(\./)+}, "")
        return nil unless relative =~ %r{\A#{FOLDER}/.+\.rb\z}i && File.basename(relative).casecmp("Patch.rb") != 0

        relative
      end

      # Lists the scripts the framework loads of a mod: its script at the top of Patch, then those
      # in its folder and below unless the game's loader reads none there, sorted by path; for a
      # folder mod, one without a script at the top, the scripts of its folder under every loader.
      #
      # @param name [String] The mod's name.
      # @return [Array<String>] The scripts, relative to the game folder.
      def self.files_of(name)
        files = loader_files(name)
        folder = "#{FOLDER}/#{name}"
        files = Loader.scripts_in(folder, SCRIPT) if files.empty? && File.directory?(folder)
        files.reject { |file| SKIPPED.any? { |skipped| File.basename(file).casecmp(skipped) == 0 } }
      end

      # Lists the scripts of a mod the game's loader reads: its script at the top of Patch, then
      # those in its folder and below unless the loader reads none there, sorted by path.
      #
      # @param name [String] The mod's name.
      # @return [Array<String>] The scripts, relative to the game folder.
      def self.loader_files(name)
        script = "#{FOLDER}/#{name}#{SCRIPT}"
        folder = "#{FOLDER}/#{name}"
        files = File.file?(script) ? [script] : []
        files.concat(Loader.scripts_in(folder, SCRIPT)) if deep? && File.directory?(folder)
        files
      end

      # Tells whether the game's loader reads the scripts in the folders of Patch.
      #
      # @return [Boolean] Whether it does; true before the hold ended.
      def self.deep?
        @deep != false
      end

      # Tells whether the game's loader ran a mod before the framework booted: the hold ended and
      # saw none of the scripts the loader reads of it, its script at the top of Patch if it has
      # one, else those in its folder.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it ran.
      def self.ran_before?(name)
        return false if @deep.nil?

        script = "#{FOLDER}/#{name}#{SCRIPT}"
        read = File.file?(script) ? [script] : loader_files(name)
        held = @held.map(&:downcase)
        !read.empty? && read.none? { |file| held.include?(file.downcase) }
      end
    end

    # Lists the managed mods that failed to load in this game session.
    #
    # @return [Hash{String => String}] Why each failed, by its name.
    def self.failed
      Loader.failed
    end

    # Tells why a mod failed to load in this game session, else the last time it was to load, as
    # the framework's settings keep it until it loads or its scripts change.
    #
    # @param name [String] The mod's name.
    # @return [String, nil] Why, nil when it did not fail.
    def self.failed_last(name)
      Loader.failed[name] || Loader.failed_before(name.to_s)
    end

    # Tells whether a mod failed to load in this game session, not only in an earlier one.
    #
    # @param name [String] The mod's name.
    # @return [Boolean] Whether it did.
    def self.failed_now?(name)
      Loader.failed.key?(name)
    end

    # Tells whether a mod's title command was picked or a part of it loaded in this game session.
    #
    # @param name [String] The mod's name.
    # @return [Boolean] Whether it was.
    def self.used?(name)
      Loader.used?(name)
    end

    # Loads the managed mods in their stages: the boot's as the game starts running, the entering's
    # as the player enters the game, each through the traps that loading after the game started
    # brings.
    module Loader
      # Who the hooks are registered by.
      TAG = "Mod Framework mods"

      # Makes a binding for a mod's script as the game's loader evaluates the scripts in Patch: at
      # the top level, with locals of its own.
      FRESH_BINDING = eval("lambda { binding }", TOPLEVEL_BINDING)

      # Takes the path of a script from a line of the call stack, such as
      # "Patch/Level_Cap.rb:12:in `run'".
      STACK_FILE = /\A(.+?):\d+(?::|\z)/

      # What the settings that keep why a mod failed to load start with, the mod's name after it.
      FAILED = "mod_failed."

      # What stands between the signature of a failed mod's scripts and why it failed in the settings.
      FAILED_SEPARATOR = "|"

      # The most characters of why a mod failed that the settings keep.
      FAILED_LENGTH = 200

      # The methods of DataManager that reading the database runs, the game's load_database calling
      # load_normal_database; a mod that wraps either changes what the read gives.
      DATABASE_READS = [:load_database, :load_normal_database]

      # The managed mods loaded, in the order they loaded.
      @loaded = []

      # Why each mod that failed to load failed, by its name.
      @failed = {}

      # The mods that failed and were not named in a notice yet.
      @unnoticed = []

      # The folders named Patch inside the Patch folder that hold scripts or a framework copy and
      # were not named in a notice yet.
      @misplaced = []


      # The mods whose title command was picked or whose part loaded, by their names in lower case.
      @used = {}

      # The parts loaded, by their paths in lower case.
      @parts = {}

      # The on_enter blocks waiting for the player to enter, each [tag, block, log, mod].
      @enter_blocks = []

      # Whether the player entered the game since the boot or the last title that came without a
      # restart.
      @entered = false

      # Whether the on_enter blocks ran, so later ones run at once.
      @enter_blocks_ran = false

      # Whether code that loads on entering started to run: the scripts of a Regular or Data mod,
      # or an on_enter block of a Title mod.
      @entering_ran = false

      # The tag each mod loaded with, by its name in lower case.
      @load_tags = {}

      # The mods the game's loader ran before the framework booted, by their names in lower case.
      @ran_before = {}

      # The mods that registered a title command or an on_enter block, which tells their title part
      # from the rest, by their names in lower case.
      @split = {}

      # The Title mods whose rest past their title part ran, by their names in lower case.
      @rest_ran = {}

      # The names of the mods of the session in lower case, as the entering named them; nil for
      # every mod that is on.
      @only = nil

      # The mod whose scripts are evaluated now, nil between them.
      @loading = nil

      # The title commands of the mods, each {:mod, :name, :symbol, :placing, :block, :box}.
      @title_commands = []

      # The symbols of the title commands taken off the title, since their mods were turned off.
      @hidden = {}

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods"

      # Boots the mods: holds the scripts of the Patch folder back from the game's loader, puts the
      # framework's box beside the title's commands and asks the plan, which also starts the DLL's
      # fetch of the website. The boot's mods load once the game runs, before what
      # waits for the run, as they would have loaded before it.
      def self.boot
        Hold.start
        Run.on_start(LOG_TAG, :first => true) { Mod_Framework::Mods::Loader.start_boot }
        Title.install
        plan = Mods.plan
        Array(plan["warnings"]).each { |mod, kind, name, version| log(warning_line(mod, kind, name, version)) }
      rescue => e
        log("the boot's mods did not load: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end

      # Words a warning of the plan for the log.
      #
      # @param mod [String] The mod that warns.
      # @param kind [String] What of, see ModWarning.
      # @param name [String] The other mod.
      # @param version [String, nil] The version needed.
      # @return [String] The line.
      def self.warning_line(mod, kind, name, version)
        case kind
        when "conflict" then "#{mod} does not work with #{name}, which is on"
        when "loads_before" then "#{mod} loads before #{name}, though its author advises after"
        when "loads_after" then "#{mod} loads after #{name}, though its author advises before"
        else "#{mod} needs #{name}#{version.to_s.empty? ? '' : " #{version}"} (#{kind})"
        end
      end

      # Ends the hold as the game starts running and loads the mods of the boot: every Framework
      # and Title mod that is on, in the plan's order, before the first scene, then forgets the
      # remembered hotkeys they no longer define. A mod the game's loader ran before the framework
      # booted counts as loaded.
      def self.start_boot
        Hold.stop
        note_misplaced
        plan = Mods.plan
        Mods.names.each do |name|
          next unless Hold.ran_before?(name) && !@loaded.include?(name)

          @loaded << name
          @ran_before[name.downcase] = true
          log("#{name} ran before the framework booted, so the game's loader loaded it")
        end
        loaded = []
        set_up_runs { loaded = load_boot_mods(pending(plan, BOOT_TAGS)) }
        log("the boot loaded #{described(loaded)}") unless loaded.empty?
        Hotkeys.forget_undefined(@loaded.select { |name| running?(name) })
      rescue => e
        log("the boot's mods did not load: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end

      # Enters the game, see Mods.enter.
      #
      # @param reason [String] What enters.
      # @param only [Array<String>, nil] The names of the mods of the session; nil for every mod
      #   that is on.
      # @return [Boolean] Whether this call entered.
      def self.enter(reason, only = nil)
        return false if @entered

        @entered = true
        @only = only && only.map(&:downcase)

        log("#{reason} enters with only these mods besides the Framework mods: #{only.empty? ? 'none' : only.join(', ')}") if only
        started = Time.now
        plan = Mods.plan
        database = database_state
        loaded = []
        set_up_runs do
          loaded.concat(load_boot_mods(pending(plan, BOOT_TAGS)))
          run_enter_blocks
          loaded.concat(load_mods(pending(plan, ENTERING_TAGS)))
        end
        Hotkeys.forget_undefined(@loaded.select { |name| running?(name) })
        data = loaded.any? { |_name, tag| tag == DATA }
        reread = data || database_state != database ? read_database : nil
        log("#{reason} entered the game in #{((Time.now - started) * 1000).round} ms: loaded #{described(loaded)}#{reread ? ", #{reread}" : ''}")
        true
      rescue => e
        log("#{reason} entered the game, but loading the mods failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        true
      end

      # Tells whether the player entered the game.
      #
      # @return [Boolean] Whether they did.
      def self.entered?
        @entered
      end

      # Lists the mods loaded.
      #
      # @return [Array<String>] Their names in the order they loaded.
      def self.loaded
        @loaded.dup
      end

      # Lists the mods that failed to load.
      #
      # @return [Hash{String => String}] Why each failed, by its name.
      def self.failed
        @failed.dup
      end


      # Tells whether a mod was used.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether its title command was picked or a part of it loaded.
      def self.used?(name)
        @used[name.to_s.downcase] == true
      end

      # Tells whether code that loads on entering started to run, loaded or failed part of the way:
      # the scripts of a Regular or Data mod, or the rest of a Title mod past its title part.
      #
      # @return [Boolean] Whether it did.
      def self.entering_ran?
        @entering_ran
      end

      # Tells whether a mod runs until the game starts again, see Mods.running?.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it does.
      def self.running?(name)
        key = name.to_s.downcase
        @load_tags[key] == FRAMEWORK_TAG || @ran_before[key] == true || loads_as_framework?(name) ||
          (@entered && @loaded.any? { |each| each.downcase == key } && !title_part_only?(name))
      end

      # Tells whether a Title mod loads whole as a Framework mod, see Mods.loads_as_framework?.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it does.
      def self.loads_as_framework?(name)
        key = name.to_s.downcase
        @load_tags[key] == TITLE_TAG && !@split[key]
      end

      # Tells whether a mod loaded only its title part, which never reaches the game: a Title mod
      # that tells its title part from the rest, whose rest did not run.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it did.
      def self.title_part_only?(name)
        key = name.to_s.downcase
        @load_tags[key] == TITLE_TAG && @split[key] == true && !@rest_ran[key]
      end

      # Runs an on_enter block once the player enters, or at once when the blocks ran; a Title
      # mod's block waits while the mod is not among the mods of the session.
      #
      # @param entry [Array] The tag, the block, its log and the mod that registered it.
      def self.on_enter(entry)
        mod = entry[3]
        @split[mod.downcase] = true if mod
        return @enter_blocks << entry unless @enter_blocks_ran

        @enter_blocks << entry unless run_block(entry)
      end

      # Runs the on_enter blocks in the order they registered; those of Title mods that are not
      # among the mods of the session wait for a later entering.
      def self.run_enter_blocks
        @enter_blocks_ran = true
        blocks = @enter_blocks
        @enter_blocks = []
        blocks.each { |entry| @enter_blocks << entry unless run_block(entry) }
      end

      # Runs a registered block, logging its failure in its log; a Title mod's only while the mod
      # is among the mods of the session, which counts as code that loaded on entering.
      #
      # @param entry [Array] The tag, the block, its log and the mod that registered it.
      # @return [Boolean] Whether it ran, false when it waits.
      def self.run_block(entry)
        tag, block, logger, mod = entry
        if mod && @load_tags[mod.downcase] == TITLE_TAG
          return false unless in_session?(mod)

          unless @rest_ran[mod.downcase]
            @rest_ran[mod.downcase] = true
            @entering_ran = true
            log("#{mod} loads the rest of it, past its title part")
          end
        end
        block.call
        true
      rescue => e
        message = "#{tag} failed as the player entered the game: #{Logging.failure(e)} at #{Array(e.backtrace).first}"
        logger.respond_to?(:log) ? logger.log(message) : log(message)
        true
      end

      # Tells whether a mod is among the mods of the session: on in the plan last asked, and named
      # by the entering, if it named any.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether it is.
      def self.in_session?(name)
        key = name.to_s.downcase
        (@only.nil? || @only.include?(key)) && Array((Mods.last_plan || {})["load"]).any? { |each, _tag| each.to_s.downcase == key }
      end

      # Lists the mods of a plan with some tags that did not load yet and are among the mods of the
      # session, the Framework mods always.
      #
      # @param plan [Hash] The plan, see Mods.plan.
      # @param tags [Array<String>] The tags.
      # @return [Array<Array>] Each [name, tag, place] in the plan's order.
      def self.pending(plan, tags)
        Array(plan["load"]).select do |name, tag, _place|
          tags.include?(tag) && !@loaded.include?(name) && !@failed.key?(name) && (tag == FRAMEWORK_TAG || @only.nil? || @only.include?(name.downcase))
        end
      end

      # Loads the mods of the boot's tags: the Framework mods, then the Title mods, each whole, each
      # group in the plan's order.
      #
      # @param mods [Array<Array>] Each [name, tag, place, version, needs] in the plan's order.
      # @return [Array<Array>] The [name, tag] of each that loaded.
      def self.load_boot_mods(mods)
        titles = mods.select { |_name, tag, _place| tag == TITLE_TAG }
        load_mods(mods - titles) + load_mods(titles)
      end

      # Loads mods one after another; one that fails is logged and the others load all the same.
      #
      # @param mods [Array<Array>] Each [name, tag, place].
      # @return [Array<Array>] The [name, tag] of each that loaded.
      def self.load_mods(mods)
        mods.map { |name, tag, place| load_mod(name, tag, place) ? [name, tag] : nil }.compact
      end

      # Loads a mod: evaluates the scripts of Hold.files_of, sorted by their paths, under the file
      # names the game's loader gives them. The first that fails ends the mod's loading, and the mod
      # counts as not loaded.
      #
      # @param name [String] The mod's name.
      # @param tag [String] Its tag.
      # @param _place [String] Where it lies, relative to the game folder.
      # @return [Boolean] Whether it loaded.
      def self.load_mod(name, tag, _place)
        files = Hold.files_of(name)
        if files.empty?
          log("#{name} has no script the game's loader reads, so it loads nothing")
          return false
        end


        @entering_ran = true if ENTERING_TAGS.include?(tag)
        @load_tags[name.downcase] = tag
        failure = evaluate_all(files, name)
        return fail_mod(name, failure) if failure

        @loaded << name
        Settings.forget(FAILED + name) if Mod_Framework.available? && Settings.setting(FAILED + name)
        true
      end

      # Evaluates scripts of a mod, up to the first that fails.
      #
      # @param files [Array<String>] The scripts, relative to the game folder.
      # @param name [String, nil] The mod they belong to, nil for none.
      # @return [String, nil] Why one failed, nil when every one ran.
      def self.evaluate_all(files, name)
        @loading = name
        files.each do |file|
          begin
            eval(File.read(file, :encoding => "BOM|UTF-8"), FRESH_BINDING.call, file)
          # A script that does not parse raises a SyntaxError, which is no StandardError.
          rescue Exception => e
            raise if Run.reset?(e)

            return "#{file}: #{Logging.failure(e)} at #{Array(e.backtrace).find { |line| line.start_with?(file) } || Array(e.backtrace).first}"
          end
        end
        nil
      ensure
        @loading = nil
      end

      # Notes a mod that failed to load, for the log and the next notice.
      #
      # @param name [String] The mod's name.
      # @param why [String] Why it failed.
      # @return [Boolean] Always false.
      def self.fail_mod(name, why)
        @failed[name] = why
        @unnoticed << name
        log("#{name} did not load: #{why}")
        Settings.store(FAILED + name, "#{signature(Hold.files_of(name))}#{FAILED_SEPARATOR}#{why.to_s.split("\n").first.to_s[0, FAILED_LENGTH]}") if Mod_Framework.available?
        false
      end

      # Tells why a mod failed to load in an earlier game session, and forgets it once the mod's
      # scripts changed since.
      #
      # @param name [String] The mod's name.
      # @return [String, nil] Why, nil when it did not fail or its scripts changed.
      def self.failed_before(name)
        return nil unless Mod_Framework.available?

        note = Settings.setting(FAILED + name)
        return nil unless note

        kept, why = note.split(FAILED_SEPARATOR, 2)
        return why if why && kept == signature(Hold.files_of(name))

        Settings.forget(FAILED + name)
        nil
      end

      # Tells the signature of a mod's scripts: their sizes and the times they were written, which
      # change as the scripts change.
      #
      # @param files [Array<String>] The scripts, relative to the game folder.
      # @return [String] The signature.
      def self.signature(files)
        files.map { |file| "#{File.size(file)}:#{File.mtime(file).to_i}" }.join(",")
      end

      # Lists the scripts of a kind in a folder and below.
      #
      # @param folder [String] The folder, relative to the game folder.
      # @param extension [String] Their extension, such as ".rb", in any case.
      # @return [Array<String>] Their paths relative to the game folder, sorted.
      def self.scripts_in(folder, extension)
        found = []
        (Dir.entries(folder) - [".", ".."]).each do |entry|
          path = "#{folder}/#{entry}"
          if File.directory?(path)
            found.concat(scripts_in(path, extension))
          elsif File.extname(entry).downcase == extension
            found << path
          end
        end
        found.sort
      end

      # Describes loaded mods for the log.
      #
      # @param mods [Array<Array>] Each [name, tag].
      # @return [String] Such as "2 mods: Core (Framework), Menu (Title)".
      def self.described(mods)
        return "no mod" if mods.empty?

        "#{mods.size} #{mods.size == 1 ? 'mod' : 'mods'}: #{mods.map { |name, tag| "#{name} (#{tag})" }.join(', ')}"
      end

      # Lets every wrapper of SceneManager.run that the block's mods put on set up, as it would
      # when the game starts: run is an empty method while the block loads them, is called once,
      # and the real one comes back.
      #
      # Mods set up their hooks in such a wrapper, and the game's run started long before they
      # loaded. Work a wrapper does after the run returns runs at once.
      #
      # @yield Loads the mods.
      def self.set_up_runs
        return yield unless defined?(::SceneManager) && ::SceneManager.respond_to?(:run)

        owner = ::SceneManager.singleton_class
        real = owner.instance_method(:run)
        owner.send(:define_method, :run) { nil }
        stand_in = owner.instance_method(:run)
        begin
          yield
          if owner.instance_method(:run) != stand_in
            log("the mods wrapped SceneManager.run, so their wrappers set up now")
            ::SceneManager.run
          end
        rescue => e
          log("a wrapper of SceneManager.run failed as it set up: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        ensure
          owner.send(:define_method, :run, real)
        end
      end

      # Tells what reading the database runs: each of its methods and the framework's hooks of it,
      # which a mod that wraps it changes.
      #
      # @return [Array, nil] Each method DataManager has and how many hooks follow it; nil without
      #   DataManager.
      def self.database_state
        return nil unless defined?(::DataManager) && ::DataManager.respond_to?(:load_database)

        owner = ::DataManager.singleton_class
        DATABASE_READS.select { |name| ::DataManager.respond_to?(name) }.map { |name| [owner.instance_method(name), Hooks.hooked(owner, name)] }
      end

      # Reads the game's database again, so the wrappers of the mods that loaded run on it.
      #
      # @return [String, nil] How it was read, for the log; nil when it was not.
      def self.read_database
        return nil unless defined?(::DataManager) && ::DataManager.respond_to?(:load_database)

        started = Time.now
        ::DataManager.load_database
        "read the database again in #{((Time.now - started) * 1000).round} ms"
      rescue => e
        log("reading the database again failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        nil
      end

      # Finds the mod whose script calls: the nearest line of the call stack in a mod's script or
      # folder outside the framework's own folder, which may lie inside a mod.
      #
      # @return [String, nil] The mod's name, else the mod loading now.
      def self.calling_mod
        own = defined?(Mod_Framework::FOLDER) ? "#{Mod_Framework::FOLDER.to_s.downcase}/" : nil
        caller.each do |line|
          path = line.tr("\\", "/")[STACK_FILE, 1]
          next if path.nil? || (own && path.downcase.start_with?(own))

          name = Mods.name_of(path)
          return name if name
        end
        @loading
      end

      # Loads a part of a mod, see Mods.load_part.
      #
      # @param path [String] The part, relative to the mod's folder.
      # @param mod [String, nil] The mod, nil for a caller in no mod's folder.
      # @return [Boolean] Whether it loaded now.
      def self.load_part(path, mod)
        relative = path.to_s.tr("\\", "/").sub(%r{\A(\./)+}, "")
        full = mod ? "#{FOLDER}/#{mod}/#{relative}" : relative
        return false if @parts[full.downcase]
        return part_failed("#{mod || 'a script'} asked for the part #{full}, which is missing") unless File.exist?(full)

        @parts[full.downcase] = true
        @used[mod.downcase] = true if mod
        files = File.directory?(full) ? scripts_in(full, PART) : [full]
        failure = evaluate_all(files, mod)
        return part_failed("the part #{full} did not load: #{failure}") if failure

        log("loaded the part #{full} (#{files.size} #{files.size == 1 ? 'script' : 'scripts'})")
        true
      end

      # Logs why a part did not load.
      #
      # @param why [String] The line.
      # @return [Boolean] Always false.
      def self.part_failed(why)
        log(why)
        false
      end

      # Adds a mod's command to the title's commands, or a row to the title's Mods box, see
      # Mods.title_command.
      #
      # @param name [String] The command's name.
      # @param options [Hash] Its options.
      # @param mod [String, nil] The mod it belongs to.
      # @param block [Proc, nil] What runs when the player picks it.
      # @return [Symbol, nil] Its symbol.
      def self.title_command(name, options, mod, block)
        return log("#{mod || 'a script'} cannot add the title command #{name}: the game has no title commands") unless defined?(::Window_TitleCommand)

        symbol = options[:symbol] || "mods #{mod} #{name}".downcase.gsub(/[^a-z0-9]+/, "_").to_sym
        placing = {}
        [:after, :before, :disabled, :if, :icon, :badge, :badge_color].each { |key| placing[key] = options[key] if options.key?(key) }
        box = options[:in] == :mods
        log("#{mod || 'a script'} puts the title command #{name} on the title's commands: :in takes only :mods") if options[:in] && !box
        log("#{mod || 'a script'} gives the title command #{name} an :ext, which the title's commands no longer keep") if options.key?(:ext)
        placing[:before] = :shutdown unless placing[:after] || placing[:before] || box
        entry = { :mod => mod, :name => name, :symbol => symbol, :placing => placing, :block => block, :box => box }
        @split[mod.downcase] = true if mod
        @title_commands.reject! { |each| each[:symbol] == symbol }
        @title_commands << entry
        patch_title(box)
        symbol
      rescue => e
        log("#{mod || 'a script'} cannot add the title command #{name}: #{Logging.failure(e)}")
      end

      # Registers, once each, the UI.patch that puts the mods' commands on the title's commands, or
      # the one that puts the mods' rows into the list of the title's Mods box, so other mods may
      # patch them as they patch any command or row.
      #
      # @param box [Boolean] Whether the patch of the Mods box's list is meant.
      def self.patch_title(box)
        if box
          @box_patched ||= UI.patch("##{Title::LIST_ID}") { |t| t.rows { |rows| Mod_Framework::Mods::Loader.box_rows(rows) } } || true
        else
          @title_patched ||= UI.patch("Window_TitleCommand") { |t| Mod_Framework::Mods::Loader.place_title_commands(t) } || true
        end
      end

      # Puts the mods' commands that show onto the title's commands, each before or after the
      # command its options name, as a patch of the title's commands runs.
      #
      # @param handle [Object] The patch's handle on the title's commands.
      def self.place_title_commands(handle)
        # The handle hides its target from mods; the commands' gates and blocks get the window.
        window = handle.instance_variable_get(:@target)
        @title_commands.each do |entry|
          next if entry[:box]

          placing = entry[:placing]
          params = title_params(entry, window)
          text = entry[:name]
          markup = proc { command text, params }
          placing[:after] ? handle.after("##{placing[:after]}", &markup) : handle.before("##{placing[:before]}", &markup)
        end
      end

      # Makes the params of a mod's command on the title's commands: its symbol, its gates, its icon
      # and badge, and its pick, each told the window as the mod's blocks take it.
      #
      # @param entry [Hash] The command, see @title_commands.
      # @param window [Window_TitleCommand] The title's commands.
      # @return [Hash] The params of command.
      def self.title_params(entry, window)
        placing = entry[:placing]
        params = { :id => entry[:symbol], :if => lambda { Mod_Framework::Mods::Loader.title_shown?(entry, window) },
                   :on_click => lambda { Mod_Framework::Mods::Loader.title_command_picked(entry[:mod], entry[:name], window, entry[:block]) } }
        params[:disabled] = lambda { Mod_Framework::Mods::Loader.asked(placing[:disabled], window) ? true : false } if placing.key?(:disabled)
        params[:badge] = lambda { Mod_Framework::Mods::Loader.asked(placing[:badge], window) } if placing.key?(:badge)
        params[:badge_color] = placing[:badge_color] if placing[:badge_color]
        params[:icon] = placing[:icon] if placing[:icon]
        params
      end

      # Puts the mods' rows that show into the rows of the title's Mods box, each before or after
      # the row its options name, else at the end, as a patch of the box's list runs.
      #
      # @param rows [Array<Hash>] The box's rows, each {:id, :text, :badge, :badge_color, :disabled,
      #   :open}.
      # @return [Array<Hash>] The rows with the mods' rows.
      def self.box_rows(rows)
        window = defined?(UI::Engine::Placement) ? UI::Engine::Placement.game_window("Window_TitleCommand") : nil
        @title_commands.each do |entry|
          next unless entry[:box] && title_shown?(entry, window)

          placing = entry[:placing]
          row = { :id => entry[:symbol], :text => entry[:name], :disabled => placing.key?(:disabled) && asked(placing[:disabled], window) ? true : false,
                  :open => lambda { Mod_Framework::Mods::Loader.title_command_picked(entry[:mod], entry[:name], window, entry[:block]) } }
          row[:badge] = asked(placing[:badge], window) if placing.key?(:badge)
          row[:badge_color] = placing[:badge_color] if placing[:badge_color]
          row[:icon] = placing[:icon] if placing[:icon]
          beside = rows.index { |each| each.is_a?(Hash) && each[:id] == (placing[:after] || placing[:before]) }
          rows = beside ? rows.dup.insert(placing[:after] ? beside + 1 : beside, row) : rows + [row]
        end
        rows
      end

      # Tells whether a mod's title command shows: its mod is on and its :if allows; a failing :if
      # counts as false, logged once.
      #
      # @param entry [Hash] The command, see @title_commands.
      # @param window [Window_TitleCommand, nil] The title's commands.
      # @return [Boolean] Whether it shows.
      def self.title_shown?(entry, window)
        return false if @hidden[entry[:symbol]]
        return true unless entry[:placing].key?(:if)

        asked(entry[:placing][:if], window) ? true : false
      rescue => e
        log_once([:title_if, entry[:symbol], e.class], "whether the title command #{entry[:name]} shows failed, so it does not: #{Logging.failure(e)}")
        false
      end

      # Reads an option of a mod's title command: a block's answer, told the window when it takes
      # it, or the value itself.
      #
      # @param value [Object] The option.
      # @param window [Window_TitleCommand, nil] The title's commands.
      # @return [Object] Its value.
      def self.asked(value, window)
        value.is_a?(Proc) ? UI.call_with(value, window) : value
      end

      # Follows the mods the player turned on and off at the title: the Title mods turned on load
      # their title part now, but those retagged, whose new tag counts from the next start; the
      # title commands of a Title mod leave the title while it is off, used or not, and come back
      # once it is on, as do the title screen parts of a split plain Title script. A title the
      # player came back to after entering, such as by cancelling a mod's own choice at New Game,
      # counts as entered, so every change there waits for the game to start again.
      #
      # @param on [Array<String>] The names of the managed mods that are on.
      # @param retagged [Array<String>] The names of the mods retagged in this game session.
      def self.follow_changes(on, retagged)
        return log("the mods turned on and off wait for the game to start again, since the title counts as entered") if @entered

        title_mods = pending(Mods.plan, ["Title"]).reject { |name, _tag, _place| retagged.include?(name) }
        unless title_mods.empty?
          loaded = []
          set_up_runs { loaded = load_boot_mods(title_mods) }
          log("turned on at the title, loaded #{described(loaded)}")
        end
        keys = on.map { |name| name.downcase }
        changed = false
        @title_commands.each do |entry|
          next if entry[:mod].nil?

          shown = keys.include?(entry[:mod].downcase)
          next if shown == !@hidden[entry[:symbol]]

          changed = true
          shown ? @hidden.delete(entry[:symbol]) : @hidden[entry[:symbol]] = true
        end
        refresh_title if changed
      rescue => e
        log("following the mods turned on and off failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end

      # Has the title's commands make their list anew, so the commands of the mods turned on and off
      # come and go.
      def self.refresh_title
        window = defined?(UI::Engine::Placement) ? UI::Engine::Placement.game_window("Window_TitleCommand") : nil
        window.refresh if window && window.respond_to?(:refresh)
      end

      # Runs a mod's title command the player picked, counting the mod as used.
      #
      # @param mod [String, nil] The mod it belongs to.
      # @param name [String] The command's name.
      # @param window [Window_Command, nil] The title's commands.
      # @param block [Proc, nil] What runs.
      # @return [Object] What the block answered, nil when it failed.
      def self.title_command_picked(mod, name, window, block)
        if mod && !used?(mod)
          @used[mod.downcase] = true
          log("#{mod} is in use: its title command #{name} was picked")
        end
        block ? UI.call_with(block, window) : nil
      rescue => e
        log("the title command #{name}#{mod ? " of #{mod}" : ''} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        nil
      end

      # Lets the player enter the game again at a title that came without a restart, since no code
      # that loads on entering ran, so the mods turned on since load as the player enters and the
      # on_enter blocks that waited run then.
      #
      # It runs before the title's other hooks, since the action after a restart enters there.
      def self.reopen
        return unless @entered && !@entering_ran

        @entered = false
        @enter_blocks_ran = false
        @only = nil
        log("the title came back without a restart, so entering the game loads the mods turned on since")
      end

      # Logs each script and framework copy in a folder named Patch inside the Patch folder, such as
      # Patch/Patch, and keeps those folders for the next notice.
      #
      # A zip extracted into Patch instead of the game folder puts its files there, where no loader
      # runs them as mods.
      def self.note_misplaced
        nested_patch_folders.each do |folder|
          scripts = scripts_in(folder, SCRIPT)
          copies = scripts_in(folder, ".txt").select { |file| framework_version?(file) }.map { |file| File.dirname(file) }
          next if scripts.empty? && copies.empty?

          scripts.each { |path| log("#{path} lies in a Patch folder inside Patch, so it does not load as a mod") }
          copies.each { |path| log("the framework copy #{path} lies in a Patch folder inside Patch") }
          @misplaced << folder
        end
      rescue SystemCallError => e
        log("could not look for Patch folders inside #{FOLDER}: #{e.message}")
      end

      # Lists the folders named Patch, in any case, right inside the Patch folder or inside one of
      # its folders, such as Patch/Patch and Patch/MGQ-Online-0.7/Patch.
      #
      # @return [Array<String>] The folders, relative to the game folder, sorted.
      def self.nested_patch_folders
        return [] unless File.directory?(FOLDER)

        patch = lambda { |path| File.basename(path).casecmp(FOLDER) == 0 }
        tops = folders_in(FOLDER)
        (tops.select(&patch) + tops.reject(&patch).map { |top| folders_in(top).select(&patch) }.flatten).sort
      end

      # Tells whether a file is the Version.txt of a framework copy.
      #
      # @param file [String] The file's path.
      # @return [Boolean] Whether it is a Version.txt in a folder named Mod_Framework.
      def self.framework_version?(file)
        File.basename(file).casecmp("Version.txt") == 0 && File.basename(File.dirname(file)).casecmp("Mod_Framework") == 0
      end

      # Lists the folders right inside a folder.
      #
      # @param folder [String] The folder, relative to the game folder.
      # @return [Array<String>] Their paths, relative to the game folder.
      def self.folders_in(folder)
        (Dir.entries(folder) - [".", ".."]).map { |entry| "#{folder}/#{entry}" }.select { |path| File.directory?(path) }
      end

      # Names the mods that failed to load and the Patch folders inside Patch in one message, once
      # each, as a scene starts.
      def self.show_notice
        return if (@unnoticed.empty? && @misplaced.empty?) || !Mod_Framework.available? || !UI.respond_to?(:message)

        lines = []
        lines << "#{@unnoticed.join(', ')} did not load." unless @unnoticed.empty?
        lines << misplaced_line(@misplaced) unless @misplaced.empty?
        @unnoticed = []
        @misplaced = []
        UI.message(lines.join(" "), :title => "Mods")
      end

      # Words the notice of the Patch folders inside Patch.
      #
      # @param folders [Array<String>] The folders, relative to the game folder.
      # @return [String] Such as "Some files are in Patch\Patch and do not load. Extract mod and
      #   framework zips into the game folder, the one with Game.exe."
      def self.misplaced_line(folders)
        "Some files are in #{folders.map { |folder| folder.tr('/', '\\') }.join(', ')} and do not load. " \
          "Extract mod and framework zips into the game folder, the one with Game.exe."
      end

      # Follows the ways into the game and the start of each scene, once the game runs, after the
      # game's plugins defined these methods.
      #
      # New Game and the load of a save run again once the mods loaded, so a mod's wrapper of them
      # runs too; DataManager enters for every other way, without that.
      def self.install
        if defined?(::Scene_Title) && ::Scene_Title.method_defined?(:command_new_game)
          Hooks.around(::Scene_Title, :command_new_game, TAG) { |scene, args, original| Mod_Framework::Mods::Loader.enter_by(scene, :command_new_game, args, original, "New Game") }
        end
        load_scenes.each do |klass|
          Hooks.around(klass, :on_savefile_ok, TAG) { |scene, args, original| Mod_Framework::Mods::Loader.enter_by(scene, :on_savefile_ok, args, original, "the load of a save") }
        end
        if defined?(::DataManager)
          [:setup_new_game, :load_game, :load_game_without_rescue].each do |name|
            next unless ::DataManager.respond_to?(name)

            Hooks.before(::DataManager.singleton_class, name, TAG) { |*_args| Mod_Framework::Mods.enter("DataManager.#{name}") }
          end
        end
        if defined?(::Scene_Base) && ::Scene_Base.method_defined?(:post_start)
          Hooks.before(::Scene_Base, :post_start, TAG) { Mod_Framework::Mods::Loader.reopen if defined?(::Scene_Title) && is_a?(::Scene_Title) }
          Hooks.after(::Scene_Base, :post_start, TAG) { Mod_Framework::Mods::Loader.show_notice }
        end
      rescue => e
        log("the ways into the game could not be followed: #{Logging.failure(e)}")
      end

      # Lists the game's load scenes that pick a save with a method of their own, such as the
      # translation's load of an autosave.
      #
      # @return [Array<Class>] Scene_Load and each subclass that defines on_savefile_ok again.
      def self.load_scenes
        return [] unless defined?(::Scene_Load)

        classes = []
        ObjectSpace.each_object(Class) do |klass|
          classes << klass if klass <= ::Scene_Load && (klass.instance_methods(false) + klass.private_instance_methods(false)).include?(:on_savefile_ok)
        end
        classes
      end

      # Runs a way into the game: the first time it enters, then runs the way again from its start,
      # so that what the mods put on it runs too.
      #
      # @param scene [Scene_Base] The scene the way runs on.
      # @param method [Symbol] The way's method.
      # @param args [Array] Its arguments.
      # @param original [Proc] Runs it as it was before the mods loaded.
      # @param reason [String] What enters, for the log.
      # @return [Object] What the way returns.
      def self.enter_by(scene, method, args, original, reason)
        return original.call if @entered

        enter(reason)
        scene.send(method, *args)
      end
    end

    Run.on_start(Loader::LOG_TAG) { Mod_Framework::Mods::Loader.install }
  end
end
