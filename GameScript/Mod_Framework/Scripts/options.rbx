#----------------------------------------------------------------
#  options.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Told the rows the title's Mod Configuration shows
#                            - Named Options > Mods in the log texts
#                            - Kept a row a UI.patch greyed from changes
#                            - Took disabled: instead of enabled: for a row
#                            - Removed key_owner, which nothing called
#                            - Removed the rows a multiplayer world set and the personal rows, which only one mod used
#      Paulinchen  2026-11-06: Listed the mods that have rows that show, the framework and its hotkeys first, and the rows of one mod
#      Paulinchen  2026-11-05: Told a key the framework reads itself apart from the game's; a key row takes neither
#      Paulinchen  2026-10-31: Let a later row of a key take the place of the earlier one and listed each key once
#                            - Named a bound key a hotkey in a key row's help
#                            - Let a row grey out, show only while a block allows, stay personal and tell a change
#      Paulinchen  2026-10-30: Looked for the key row that has a key among rows given
#                            - Kept the Mod Config's rows in place of Mod Config Remake, with the rows of mods that
#                              put them into the game's options before the framework loaded
#                            - Read, stepped and bound the rows, sorted them by mod and named the keys of key rows
#      Paulinchen  2026-10-29: Added rows the game keeps in the save
#                            - Read the value of a row the game keeps
#                            - Kept the rows of mods that load before Mod Config Remake until the game runs
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # Rows of Options > Mods, which ModConfig shows: rows grouped by the
  # "[Mod Name] " their names start with, inserted before its last row, Return, as mods made for
  # the Mod Config Menu and Mod Config Remake insert them. The framework keeps the rows,
  # NWConst::Config::MOD_CONTENTS, from its boot on, unless one of those menus made them first.
  #
  # A mod that loads before the game's options are there adds its rows all the same: they wait and
  # go in as the game runs.
  module Options
    # The first words of the framework's own rows.
    GROUP = "[Mod Framework] "

    # The group of the rows of no mod, OptionGroups.Global in C#.
    GLOBAL = "Global"

    # The topic that sorts rows by mod, OptionsTopics.GroupsTopic in C#.
    GROUPS_TOPIC = "options.groups"

    # What a key row's help adds.
    KEY_HELP = "Confirm, then press the new hotkey."

    # How far apart two decimal values may lie and still match.
    FLOAT_MARGIN = 1e-6

    # The last row of Options > Mods, which every mod inserts before.
    RETURN_ROW = { :key => :return, :name => "Return", :sub => false, :help => "Go back to the options." }

    # The key of the game's options row that opens Options > Mods, as Mod Config Remake named it.
    ENTRY_KEY = :mod_settings

    # The game's options row that opens Options > Mods, where the options screen has no tabs.
    ENTRY_ROW = { :key => ENTRY_KEY, :name => "Mods", :sub => false, :help => "Change the options of your mods." }

    # What the keys of mods' rows start with, as the Mod Config Menu asked of them.
    MOD_KEY = /\Amod_/

    # The rows waiting for the game's run, each [method, arguments].
    @waiting = []

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "options"

    # Adds a row whose value the game keeps in the save, in $game_system.conf, as it keeps its own
    # options: into Options > Mods, else into the game's own options before their last row.
    #
    # @param key [Symbol] The row's key, unique among every mod's rows, and its value's key in
    #   $game_system.conf.
    # @param name [String] Its name, starting with its group, such as "[Level Cap] Level Cap".
    # @param help [String] Its help.
    # @param values [Hash] Its values in order, each with its name, or with [name, help].
    # @param default [Object] Its value until the player picks another.
    # @param options [Hash] :disabled (a block: while true the row is greyed out and a change buzzes)
    #   and :if (a block: the row shows only while true).
    # @yield [value] Runs with the new value after the save took it.
    # @return [Boolean] Whether the row was added, or waits for the game's run since the game's
    #   options are not there yet.
    def self.add(key, name, help, values, default, options = {}, &block)
      options = options.merge(:changed => block) if block
      return wait(:add, [key, name, help, values, default, options]) if waits?

      config = ::NWConst::Config
      return false unless insert({ :key => key, :name => name, :sub => true, :help => help }.merge(row_options(options)), game_rows)

      config::DATA[key] = values.keys
      config::DATA_TEXT[key] = {}
      values.each do |value, named|
        label, text = Array(named)
        config::DATA_TEXT[key][value] = { :name => label.to_s, :help => text.to_s }
      end
      config::DEFAULT[key] = default
      true
    rescue => e
      log("the row #{name} could not be added: #{Logging.failure(e)}")
      false
    end

    # Tells the value of a row the game keeps in the save: the player's pick in $game_system.conf,
    # else the row's default, such as while no game is loaded.
    #
    # @param key [Symbol] The row's key.
    # @return [Object, nil] The value, nil for a row of no value and no default.
    def self.value(key)
      conf = $game_system && $game_system.respond_to?(:conf) ? $game_system.conf : nil
      picked = conf ? conf[key] : nil
      return picked unless picked.nil?

      defined?(::NWConst::Config::DEFAULT) ? ::NWConst::Config::DEFAULT[key] : nil
    end

    # Adds a row whose value a mod keeps itself, such as in a file of its own, so it holds in every
    # save.
    #
    # @param key [Symbol] The row's key, unique among every mod's rows.
    # @param name [String] Its name, starting with its group, such as "[Mod Framework] Interface
    #   Look".
    # @param help [String] Its help.
    # @param values [Proc] Lists its values, as texts the menu shows.
    # @param read [Proc] Reads its value.
    # @param write [Proc] Takes the value picked.
    # @param options [Hash] :disabled and :if, as add takes them.
    # @return [Boolean] Whether the row was added, or waits for the game's run since the game's
    #   options are not there yet.
    def self.keep(key, name, help, values, read, write, options = {})
      return wait(:keep, [key, name, help, values, read, write, options]) if waits?

      insert({ :key => key, :name => name, :sub => true, :help => help, :values => values,
               :mod_stored => true, :value => read, :on_change => write }.merge(row_options(options)))
    rescue => e
      log("the row #{name} could not be added: #{Logging.failure(e)}")
      false
    end

    # Turns the options of add and keep into the row's keys, as Mod Config Remake reads them.
    #
    # @param options [Hash] :disabled, :if and :changed (the block of add).
    # @return [Hash] The row's keys.
    def self.row_options(options)
      row = {}
      row[:enable] = lambda { !options[:disabled].call } if options[:disabled]
      row[:if] = options[:if] if options[:if]
      row[:on_change] = options[:changed] if options[:changed]
      row
    end
    private_class_method :row_options

    # Tells whether a row shows now: as its :if answers, a failing one counting as false, logged
    # once.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether it shows.
    def self.shown?(row)
      gate = row[:if]
      gate.nil? || gate.call ? true : false
    rescue => e
      log_once([:if, row[:key], e.class], "the :if of the row #{row[:key]} failed, so it does not show: #{Logging.failure(e)}")
      false
    end

    # Lists the rows that show now, see rows and shown?.
    #
    # @return [Array<Hash>] The rows.
    def self.shown_rows
      rows.select { |row| shown?(row) }
    end

    # Inserts a row before the last row, Return; a row of its key there already gives it its
    # place. The framework's hotkeys add their key bindings this way.
    #
    # @param row [Hash] The row, as Mod Config Remake reads it.
    # @param rows [Array<Hash>, nil] The rows it goes into, those of Options > Mods without; nil for
    #   none.
    # @return [Boolean] Whether it was inserted.
    def self.insert(row, rows = mod_rows)
      unless rows
        log("the row #{row[:name]} was not added: Options > Mods is not there")
        return false
      end

      at = rows.index { |each| each[:key] == row[:key] }
      if at
        rows[at] = row
        log("the row #{row[:key]} took the place of the row of that key added before")
      else
        rows.insert(-2, row)
      end
      true
    end

    # Finds the rows of Options > Mods.
    #
    # @return [Array<Hash>, nil] Its rows, nil while Options > Mods is not there.
    def self.mod_rows
      defined?(::NWConst::Config::MOD_CONTENTS) ? ::NWConst::Config::MOD_CONTENTS : nil
    end
    private_class_method :mod_rows

    # Finds the rows a row the game keeps goes into: those of Options > Mods, else the game's own
    # options, as the mods before the framework did.
    #
    # @return [Array<Hash>, nil] The rows, nil while the game has no options.
    def self.game_rows
      mod_rows || (defined?(::NWConst::Config::CONTENTS) ? ::NWConst::Config::CONTENTS : nil)
    end
    private_class_method :game_rows

    # Lists the rows of Options > Mods in their order, without its last row, Return, and each key
    # once: of the rows a mod put in with a key another row has, the later one.
    #
    # @return [Array<Hash>] The rows, none while Options > Mods is not there.
    def self.rows
      listed = (mod_rows || []).reject { |row| row[:key] == :return }
      last = {}
      listed.each { |row| last[row[:key]] = row }
      listed.select { |row| last[row[:key]].equal?(row) }
    end

    # Sorts rows by the mod their names start with: "[Mod Name] Option" starts or joins that mod's
    # group, an indented name joins the group above it, any other goes to Global.
    #
    # @param names [Array<String>] The rows' names in their order.
    # @return [Array<Array>] Each group's name with its rows' places and names without the group,
    #   [[group, [[place, name], ...]], ...]; without the DLL one group of every row as named.
    def self.groups(names)
      grouped = Mod_Framework.available? ? Mod_Framework.bridge.call(GROUPS_TOPIC, names) : nil
      return grouped if grouped.is_a?(Array)

      names.empty? ? [] : [[GLOBAL, names.each_with_index.map { |name, place| [place, name] }]]
    end

    # Lists the mods that have rows that show now, by the names their rows start with, as Options >
    # Mods lists them: the framework's own first, its hotkeys among them, then Global for the rows of
    # no mod while there are any, then the others in the order of their first rows.
    #
    # @param rows [Array<Hash>] The rows, those of Options > Mods by default.
    # @return [Array<String>] The mods' names, such as ["Mod Framework", "Level Cap"].
    def self.mods(rows = self.rows)
      names = grouped(rows).map { |name, _members| name }
      framework = GROUP[/\[(.+)\]/, 1]
      own = names.select { |name| name == framework || name.start_with?("#{framework} ") }
      own + (names - own)
    end

    # Lists the rows of one mod that show now, in their order: those whose names start with the
    # mod's name in brackets and the indented rows under them, or with Global the rows of no mod.
    #
    # @param mod [String] The mod's name, such as "Level Cap", any case.
    # @param rows [Array<Hash>] The rows, those of Options > Mods by default.
    # @return [Array<Hash>] The rows, none for a mod without rows that show.
    def self.rows_of(mod, rows = self.rows)
      found = grouped(rows).find { |name, _members| name.casecmp(mod.to_s.strip).zero? }
      found ? found[1] : []
    end

    # Sorts rows by mod as groups does, keeping in each group the rows that show now and leaving
    # out a group without any.
    #
    # @param rows [Array<Hash>] The rows.
    # @return [Array<Array>] Each group's name with its rows, [[name, [row, ...]], ...].
    def self.grouped(rows)
      groups(rows.map { |row| text(row[:name]) }).map do |name, members|
        [name, members.map { |place, _name| rows[place] }.select { |row| shown?(row) }]
      end.reject { |_name, members| members.empty? }
    end
    private_class_method :grouped

    # Reads a text of a row that may be a Proc, as mods give names and helps that change.
    #
    # @param text [String, Proc, nil] The text.
    # @return [String] The text, "" for none or for a Proc that fails.
    def self.text(text)
      (text.respond_to?(:call) ? text.call : text).to_s
    rescue => e
      log_once([:text, e.class], "a row's text failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      ""
    end

    # Tells whether a row binds a key: its value is a key's Windows code, which the next key
    # pressed replaces.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether it does.
    def self.key_row?(row)
      row[:keybind] ? true : false
    end

    # Tells whether a mod keeps a row's value itself: its :value reads it, its :on_change keeps it,
    # and nothing goes into the save.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether it does.
    def self.kept_by_mod?(row)
      row[:mod_stored] && row[:value].respond_to?(:call) ? true : false
    end

    # Tells whether the title's Mod Configuration shows a row: a hotkey row, or a row of values its
    # mod keeps itself, since at the title no save holds the others.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether it shows.
    def self.title_row?(row)
      return row[:value].respond_to?(:call) if key_row?(row)

      row[:sub] && kept_by_mod?(row) ? true : false
    end

    # Lists the values a row steps through: its :values, an Array or a Proc, else DATA's.
    #
    # @param row [Hash] The row.
    # @return [Array] The values in order, none for a row of none.
    def self.values_of(row)
      values = row[:values]
      values = values.call if values.respond_to?(:call)
      values ||= config(:DATA)[row[:key]]
      values ? values.to_a : []
    rescue => e
      log_once([:values, row[:key], e.class], "the values of the row #{row[:key]} failed: #{Logging.failure(e)}")
      []
    end

    # Reads a row's value: from its :value for a key row or a row its mod keeps, else from the
    # save, its default until the player picks another.
    #
    # @param row [Hash] The row.
    # @return [Object, nil] The value.
    def self.current(row)
      return row[:value].call if (key_row?(row) || kept_by_mod?(row)) && row[:value].respond_to?(:call)

      value(row[:key])
    rescue => e
      log_once([:current, row[:key], e.class], "reading the row #{row[:key]} failed: #{Logging.failure(e)}")
      nil
    end

    # Writes a row's value as the row shows it: a key row's key by its name, else the name DATA_TEXT
    # gives the value, else the value itself.
    #
    # @param row [Hash] The row.
    # @return [String] The text.
    def self.value_text(row)
      return Keys.name(current(row).to_i) if key_row?(row)

      value = current(row)
      named = (config(:DATA_TEXT)[row[:key]] || {})[value]
      return named[:name].to_s if named.is_a?(Hash) && named[:name]

      value.is_a?(Float) ? format("%.2f", value) : value.to_s
    end

    # Writes a row's help: its own, then its value's and what a key row asks for, with eval<...>
    # filled in as the game's own options do.
    #
    # @param row [Hash] The row.
    # @return [String] The help, its lines separated by "\r\n".
    def self.help_text(row)
      help = text(row[:help])
      if key_row?(row)
        help += "\r\n#{KEY_HELP}"
      elsif row[:sub]
        named = (config(:DATA_TEXT)[row[:key]] || {})[current(row)]
        extra = named.is_a?(Hash) ? text(named[:help]) : ""
        help += "\r\n#{extra}" unless extra.empty? || help.include?(extra)
      end
      help.gsub(/eval<(\S+)>/) { (eval($1).to_s rescue "") }
    end

    # Tells whether the player may change a row: not while a UI.patch greyed it (:disabled), else as
    # its :enable says.
    #
    # @param row [Hash] The row.
    # @return [Boolean] Whether they may.
    def self.enabled?(row)
      return false if row[:disabled]

      row[:enable] ? (row[:enable].call ? true : false) : true
    rescue => e
      log_once([:enable, row[:key], e.class], "the :enable of the row #{row[:key]} failed, so it stays changeable: #{Logging.failure(e)}")
      true
    end

    # Steps a row's value by some values, round at either end: into the save unless its mod keeps
    # it, then to its :on_change.
    #
    # @param row [Hash] The row.
    # @param by [Integer] 1 for the next value, -1 for the one before.
    # @return [Boolean] Whether it stepped; false for a row of no values.
    def self.step(row, by)
      values = values_of(row)
      return false if values.empty?

      at = index_of(values, current(row)) || 0
      value = values[(at + by) % values.size]
      $game_system.conf[row[:key]] = value if !kept_by_mod?(row) && conf
      changed(row, value)
      true
    end

    # Binds a key to a key row: into the save unless the row reads its key itself, then to its
    # :on_change.
    #
    # @param row [Hash] The row.
    # @param code [Integer] Windows' code of the key.
    def self.bind(row, code)
      $game_system.conf[row[:key]] = code if !row[:value].respond_to?(:call) && conf
      changed(row, code)
    end

    # Finds a value among a row's values; decimals a Proc makes anew each time match within a
    # margin.
    #
    # @param values [Array] The values.
    # @param value [Object] The value.
    # @return [Integer, nil] Its place, nil for none of them.
    def self.index_of(values, value)
      values.index { |each| each.is_a?(Float) || value.is_a?(Float) ? (each.to_f - value.to_f).abs < FLOAT_MARGIN : each == value }
    rescue
      nil
    end

    # Hands a row's new value to its :on_change, logging a failure, which keeps the list running.
    #
    # @param row [Hash] The row.
    # @param value [Object] The value.
    def self.changed(row, value)
      row[:on_change].call(value) if row[:on_change].respond_to?(:call)
    rescue => e
      log("the :on_change of the row #{row[:key]} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
    end
    private_class_method :changed

    # Finds a table of the game's options, such as DATA.
    #
    # @param name [Symbol] The table.
    # @return [Hash] The table, empty while the game has none.
    def self.config(name)
      defined?(::NWConst::Config) && ::NWConst::Config.const_defined?(name) ? ::NWConst::Config.const_get(name) : {}
    end
    private_class_method :config

    # Finds the save's options, where the game keeps them.
    #
    # @return [Hash, nil] They, nil while no game is loaded.
    def self.conf
      $game_system && $game_system.respond_to?(:conf) ? $game_system.conf : nil
    end
    private_class_method :conf

    # The keys a key row takes and their names, from the DLL, as Mod Config Remake named them.
    module Keys
      # The topic that names keys, OptionsTopics.NamesTopic in C#.
      NAMES_TOPIC = "keys.names"

      # The topic that lists the keys a key row takes, OptionsTopics.BindableTopic in C#.
      BINDABLE_TOPIC = "keys.bindable"

      # The topic that judges a key pressed for a key row, OptionsTopics.JudgeTopic in C#.
      JUDGE_TOPIC = "keys.judge"

      # What a key row shows for no key.
      NONE = "None"

      # The names the DLL gave, by code.
      @names = {}

      # Names a key: by the DLL, which also asks the keyboard's layout, else by Hotkeys.plain_name.
      #
      # @param code [Integer] Windows' code of the key, 0 for none.
      # @return [String] The name, such as "F5" or "Num 0".
      def self.name(code)
        code = code.to_i
        return NONE if code <= 0
        return @names[code] if @names[code]

        named = Mod_Framework.available? ? Array(Mod_Framework.bridge.call(NAMES_TOPIC, [code])).first : nil
        named ? @names[code] = named : Hotkeys.plain_name(code)
      end

      # Lists the keys a key row takes.
      #
      # @return [Array<Integer>] Their codes, none without the DLL.
      def self.bindable
        @bindable ||= Mod_Framework.available? ? Array(Mod_Framework.bridge.call(BINDABLE_TOPIC)) : nil
        @bindable || []
      end

      # Judges a key pressed for a waiting key row.
      #
      # @param code [Integer] Windows' code of the key.
      # @return [Symbol] :keep (Esc or the numpad's 0), :game (a key the game reads itself),
      #   :framework (a key the framework reads itself), :bind or :ignored.
      def self.judge(code)
        answer = Mod_Framework.available? ? Mod_Framework.bridge.call(JUDGE_TOPIC, code.to_i) : nil
        answer ? answer.to_sym : :ignored
      end

      # Tells whether the game or the framework reads a key itself, so no key row may take it.
      #
      # @param code [Integer] Windows' code of the key.
      # @return [Boolean] Whether one does.
      def self.game_key?(code)
        [:game, :framework].include?(judge(code))
      end
    end

    # Adds the rows that waited for the game's run, in the order they came.
    def self.add_waiting
      waiting = @waiting
      @waiting = []
      waiting.each do |method, args|
        log("the row #{args[1]} waited for the game to run and was not added") unless send(method, *args)
      end
    end

    # Tells whether a row waits for the game's run: before it, while the rows of Options > Mods are
    # not there.
    #
    # @return [Boolean] Whether it does.
    def self.waits?
      !mod_rows && !Run.started?
    end
    private_class_method :waits?

    # Keeps a row for the game's run, in the place of a row of its key that waits already.
    #
    # @param method [Symbol] What adds it then, :add or :keep.
    # @param args [Array] Its arguments.
    # @return [Boolean] Always true: it waits.
    def self.wait(method, args)
      at = @waiting.index { |_method, each| each[0] == args[0] }
      at ? @waiting[at] = [method, args] : @waiting << [method, args]
      true
    end
    private_class_method :wait

    # Makes the rows of Options > Mods, ending with Return, unless the Mod Config Menu or Mod Config
    # Remake made them first, and the row of the game's options that opens them. Rows mods put
    # into the game's options because they loaded before the framework, keys "mod_" first, move into
    # them. Without the game's options it does nothing until the game runs.
    def self.setup
      return unless defined?(::NWConst::Config::CONTENTS)

      config = ::NWConst::Config
      unless config.const_defined?(:MOD_CONTENTS)
        config.const_set(:MOD_CONTENTS, [RETURN_ROW.dup])
        adopt_strays(config)
      end
      config.define_singleton_method(:mod_target) { ::NWConst::Config::MOD_CONTENTS } unless config.respond_to?(:mod_target)
      config::CONTENTS.insert(-2, ENTRY_ROW.dup) unless config::CONTENTS.any? { |row| row[:key] == ENTRY_KEY }
    rescue => e
      log("making the rows of Options > Mods FAILED: #{Logging.failure(e)}")
    end

    # Moves the rows of mods that went into the game's options, since the rows of Options > Mods
    # were not there when they loaded, into Options > Mods, in their order.
    #
    # @param config [Module] NWConst::Config.
    def self.adopt_strays(config)
      strays = config::CONTENTS.select { |row| row[:key].to_s =~ MOD_KEY && row[:key] != ENTRY_KEY }
      return if strays.empty?

      config::CONTENTS.reject! { |row| strays.any? { |stray| stray.equal?(row) } }
      strays.each { |row| config::MOD_CONTENTS.insert(-2, row) }
      log("moved #{strays.size} row(s) of mods that loaded before the framework from the game's options into Options > Mods: #{strays.map { |row| row[:key] }.join(', ')}")
    end
    private_class_method :adopt_strays

    setup
    Run.on_start("waiting mod config rows") do
      Mod_Framework::Options.setup
      Mod_Framework::Options.add_waiting
    end
  end
end
