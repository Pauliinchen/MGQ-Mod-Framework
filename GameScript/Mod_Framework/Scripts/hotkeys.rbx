#----------------------------------------------------------------
#  hotkeys.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Forgot the remembered hotkeys a mod that loaded no longer defines
#      Paulinchen  2026-11-07: Listed the rows of Options > Mods with the remembered hotkeys of the mods that are on
#                            - Read typing from UI.typing?
#                            - Judged the framework's own keys anew once F1 binds other keys
#      Paulinchen  2026-11-06: Left a hotkey unbound whose kept key or default another hotkey holds
#                            - Refused a hotkey on one of the framework's own keys, by default or as kept
#                            - Called the engine's classes by their names under UI::Engine
#                            - Let the accept and decline hotkeys answer the question box of the UI layer
#      Paulinchen  2026-11-05: Made the key rows of every hotkey of the mods that are on, as a Hotkeys tab lists them
#                            - Looked for the hotkeys pressed without making a list every frame
#                            - Read a hotkey's key without making objects
#                            - Made the move hotkeys the framework's Move Up and Move Down of its mod list
#                            - Dropped keeping the framework's own hotkeys rowless beside an older MGQ Online
#                            - Kept every hotkey quiet while a part waits for the key the player presses, and told a hotkey's
#                              name without its group and the keys the other hotkeys have
#      Paulinchen  2026-11-04: Let a hotkey on a key of the game's extra buttons act wherever no screen uses that button, the
#                              clash logged once where one does
#                            - Defined the framework's hotkey held with an arrow to jump out of a list
#                            - Bumped the keys' serial once a key is bound, and noted it read where a hotkey's key is named
#                            - Took a key's name as a hotkey's key, told C#'s tree every hotkey with its key and whether it
#                              is off its scenes, and logged a part's hotkey the tree kept quiet
#      Paulinchen  2026-11-01: Defined the framework's hotkeys that move the mod under the cursor of the Mods screen's list
#      Paulinchen  2026-10-31: Told the key of a hotkey that fired just now, so a text field it opens leaves out its character
#                            - Opened and closed a root of the components by its hotkey, refusals logged
#      Paulinchen  2026-10-30: Remembered the hotkeys of the mods, so their keys can be bound while the mods are not loaded
#                            - Gave every hotkey a key row of the framework's Mod Config and dropped the plain rows
#                            - Kept the hotkeys quiet while a key row waits for its key
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The hotkeys of every mod: keys the player binds in Options > Mods, each kept in the
  # framework's settings, whose block runs when the key goes down on one of its scenes.
  #
  # A hotkey stays quiet while a question box is open, while a key row waits for its key, while a
  # text field types and when an open window of the framework took its key, such as Tab moving the
  # focus. On a key F1 binds to one of the game's extra buttons (Shift, A, S and D) it works wherever
  # no screen uses that button; where one does, the button wins and the clash is logged once. Without the DLL no key is read, so no hotkey fires and none gets a row.
  #
  # The hotkeys of the mods in Patch are remembered in the framework's settings as they are defined,
  # so the title, where a Regular mod is not loaded, lists them and binds their keys; a key bound
  # that way applies when the mod defines the hotkey again. Once a mod loaded, those it no longer
  # defines are forgotten.
  module Hotkeys
    # The first words of the rows of the framework's own hotkeys.
    GROUP = "[Mod Framework Hotkeys] "

    # What the settings that remember a hotkey start with, the hotkey's action after it.
    REMEMBERED = "hotkey."

    # What the settings that keep a key bound while its hotkey was not defined start with, the
    # hotkey's action after it.
    BOUND_LATER = "hotkey_bound."

    # The characters a remembered text writes as an escape, so it stays on one line of the settings.
    ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\r" => "\\r", "\n" => "\\n" }

    # Why a hotkey stays quiet while the game's own screen uses one of its extra buttons, the
    # button after it; the same words as C#'s tree.
    GAME_SCREEN_CLASH = "the game's screen uses the game's %s button"

    # The highest key code Windows has.
    MAX_CODE = 0xFE

    # Windows' codes of I and K, the keys that move the mod under the cursor of the framework's mod
    # list up and down until the player binds others; no key a list, the game or a known mod reads.
    MOVE_UP_KEY = 0x49
    MOVE_DOWN_KEY = 0x4B

    # Windows' code of Ctrl, held with an arrow to jump out of a list until the player binds another
    # key; C#'s tree reads it held, so it presses nothing by itself.
    LIST_JUMP_KEY = 0x11

    # The characters of a key's code as the store keeps it, for String#count.
    DIGITS = "0-9"

    # What Options::Keys.judge answers for the framework's own keys, which no hotkey sits on: the
    # keys it reads itself, such as Tab, and the cancel keys, such as Esc and Numpad 0.
    FRAMEWORK_VERDICTS = [:framework, :keep]

    # What code answers for a hotkey that stays unbound: no key, so nothing presses it.
    UNBOUND = 0

    # How strongly a hotkey holds the key it wants, the lowest first: a key its store kept, a default
    # while its store keeps none, a default in place of a kept key that was refused.
    SAVED = 0
    DEFAULT = 1
    FALLBACK = 2

    # A hotkey a mod defined.
    #
    # @!attribute action [Symbol] What it does, its name in the calls.
    # @!attribute default [Integer] Windows' code of its key until the player binds another.
    # @!attribute name [String] Its row's name in Options > Mods, its group first.
    # @!attribute help [String] Its row's help.
    # @!attribute scenes [Array<Class>, nil] The scenes it fires on, nil for every scene.
    # @!attribute store [#setting, #store] Where its key is kept.
    # @!attribute setting [String] Its key's name in the store.
    # @!attribute block [Proc, nil] What it does when its key goes down.
    # @!attribute logger [#log, nil] Where its failures are logged, nil for the framework's log.
    # @!attribute mod [String] The file of the mod that defined it.
    # @!attribute row [Symbol, nil] The key of its row in Options > Mods, nil while it has none.
    Hotkey = Struct.new(:action, :default, :name, :help, :scenes, :store, :setting, :block, :logger, :mod, :row)

    # The hotkeys by action, in the order they were defined.
    @hotkeys = {}

    # The frame of UI::Engine::Key.frame whose keys were looked at, nil before the first.
    @fired = nil

    # The key of the last hotkey that fired and the frame of UI::Engine::Key.frame it fired in, nil for none.
    @recent = nil

    # Frames after a hotkey fired in which a text field it opened leaves out its character.
    RECENT_FRAMES = 1

    # The codes of the keys a hotkey's :key may name that are neither a letter, a digit nor an F key.
    KEY_CODES = { "TAB" => 0x09, "ENTER" => 0x0D, "SPACE" => 0x20, "PAGE UP" => 0x21, "PAGE DOWN" => 0x22, "END" => 0x23, "HOME" => 0x24,
                  "INSERT" => 0x2D, "DELETE" => 0x2E, "CTRL" => 0x11 }

    # The roots each hotkey opens and closes, by action.
    @roots = {}

    # Whether a key is one of the framework's own, by its code, as the DLL judged it.
    @framework_keys = {}

    # The keys' serial @framework_keys was judged at, nil before the first.
    @framework_serial = nil

    # What for_tree answered last, the scene and the keys' serial it answered for, nil until a hotkey
    # or a key changes.
    @for_tree = nil
    @for_tree_scene = nil
    @for_tree_serial = nil

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "hotkeys"

    # Defines a hotkey. Its key row comes into Options > Mods as the game runs.
    #
    # @param action [Symbol] What it does, unique among every mod's hotkeys, so it starts with the
    #   mod's name, such as :sample_windows_open.
    # @param options [Hash] :key (its key until the player binds another: a name such as "G" or
    #   "F5", or Windows' code of the key), :name
    #   (its row's name, its group first, such as "[Sample] Open the Sample Windows"), :help (its
    #   row's help), :scenes (the scene classes it fires on, every scene without), :store (an object
    #   with setting and store that keeps its key instead of the framework's settings), :setting (its
    #   key's name in the store, "key_<action>" without), :log (where its failures are logged, such as
    #   the mod's module).
    # @yield Runs when its key goes down on one of its scenes and it is not quiet.
    # @return [Boolean] Whether it was defined; a second definition of an action is refused, and so
    #   are a :key that is one of the framework's own keys and a :setting another hotkey keeps in the
    #   same store.
    def self.define(action, options = {}, &block)
      mod = UI::Engine::Root.mod_file(caller)
      return refuse(mod, "#{action.inspect} is no Symbol") unless action.is_a?(Symbol)
      return refuse(mod, "#{action} is defined already by #{@hotkeys[action].mod}") if @hotkeys.key?(action)

      key = key_code(options[:key])
      return refuse(mod, "#{action} has no key: #{options[:key].inspect}") unless code?(key)
      if framework_key?(key, action)
        return refuse(mod, "#{action} (#{options[:name] || action}) has #{Options::Keys.name(key)}, one of the framework's own keys, and stays unbound")
      end

      store = options[:store] || Settings
      setting = (options[:setting] || "key_#{action}").to_s
      taken = @hotkeys.values.find { |other| other.store.equal?(store) && other.setting == setting }
      return refuse(mod, "#{setting} is kept already by #{taken.action} of #{taken.mod}") if taken

      hotkey = Hotkey.new(action, key, (options[:name] || action).to_s, options[:help].to_s,
                          options[:scenes] ? Array(options[:scenes]) : nil, store, setting, block, options[:log], mod, nil)
      @hotkeys[action] = hotkey
      @for_tree = nil
      bind_waiting(hotkey)
      remember(hotkey)
      UI::Engine::Key.watch(Run.started? ? code(action) : hotkey.default)
      add_row(hotkey) if Run.started? && Mod_Framework.available?
      true
    rescue => e
      log("defining the hotkey #{action.inspect} FAILED: #{Logging.failure(e)}")
      false
    end

    # Reads the key of a hotkey: the one the player bound, else its default, also in place of a kept
    # key that is no key or one of the framework's own keys. A hotkey never shares its key with
    # another, by the rule of holder.
    #
    # @param action [Symbol] The hotkey.
    # @return [Integer, nil] Windows' code of its key, UNBOUND while another hotkey holds it, nil for
    #   a hotkey nobody defined.
    def self.code(action)
      hotkey = @hotkeys[action]
      return nil unless hotkey

      saved = saved(hotkey)
      key = saved.is_a?(Integer) ? saved : hotkey.default
      holder = holder(hotkey, key, rank(saved))
      return key unless holder || saved.is_a?(String)

      log_once([:key, action, saved, holder && holder.action], key_note(hotkey, saved, key, holder))
      holder ? UNBOUND : key
    rescue => e
      log_once([:code, action, e.class], "reading the key of #{action} FAILED, it keeps its default: #{Logging.failure(e)}")
      hotkey.default
    end

    # Binds a key to a hotkey, kept in its store.
    #
    # @param action [Symbol] The hotkey.
    # @param code [Integer] Windows' code of the key.
    # @return [Boolean] Whether the key is kept.
    def self.bind(action, code)
      hotkey = @hotkeys[action]
      return false unless hotkey && code?(code)

      kept = hotkey.store.store(hotkey.setting, code) ? true : false
      @for_tree = nil
      remember(hotkey)
      UI::Engine::Key.watch(code)
      UI::Engine::Serials.bump(:keys)
      log("bound #{hotkey.name} to #{label(action)} (key code #{code})#{kept ? '' : ', which its store did not keep'}")
      kept
    rescue => e
      log("binding #{action} to #{code} FAILED: #{Logging.failure(e)}")
      false
    end

    # Lists the hotkeys of the mods remembered as they were last defined, also of mods not loaded
    # now.
    #
    # @return [Array<Hash>] Each {:action, :mod (the mod's name), :code (the key bound last,
    #   or bound since while it was not defined), :default, :name, :help}, in the order of the
    #   settings.
    def self.remembered
      Settings.keys_under(REMEMBERED).map { |action| remembered_entry(action) }.compact
    end

    # Binds a key to a remembered hotkey: at once while it is defined, else when its mod defines it
    # again.
    #
    # @param action [Symbol, String] The hotkey.
    # @param code [Integer] Windows' code of the key.
    # @return [Boolean] Whether the key is kept.
    def self.bind_later(action, code)
      action = action.to_sym
      return bind(action, code) if @hotkeys.key?(action)

      entry = remembered_entry(action)
      return false unless entry && code?(code)

      kept = Settings.change(REMEMBERED + action.to_s => remembered_text(entry[:mod], code, entry[:default], entry[:name], entry[:help]),
                             BOUND_LATER + action.to_s => code.to_s)
      log("bound #{entry[:name]} to key code #{code} for when #{entry[:mod]} loads#{kept ? '' : ', which the settings did not keep'}")
      kept
    end

    # Forgets the remembered hotkeys of mods that loaded in this game session but did not define
    # them, with the keys bound to them for later.
    #
    # @param mods [Array<String>] The names of the mods that loaded.
    def self.forget_undefined(mods)
      return if mods.empty? || !Mod_Framework.available?

      names = mods.map { |name| name.to_s.downcase }
      remembered.each do |entry|
        next if @hotkeys.key?(entry[:action]) || !names.include?(entry[:mod].downcase)

        Settings.change(REMEMBERED + entry[:action].to_s => nil, BOUND_LATER + entry[:action].to_s => nil)
        log("forgot #{entry[:name]} (#{entry[:action]}) of #{entry[:mod]}, which the mod no longer defines")
      end
    rescue => e
      log("forgetting the hotkeys the mods no longer define FAILED: #{Logging.failure(e)}")
    end

    # Makes key rows of the remembered hotkeys not defined now, as the rows of Options > Mods, whose
    # key binds through bind_later.
    #
    # @yield [mod] Tells whether the hotkeys of a mod get rows, such as only those of mods that are
    #   on; every remembered hotkey gets one without a block.
    # @return [Array<Hash>] The rows.
    def self.remembered_rows
      remembered.reject { |entry| @hotkeys.key?(entry[:action]) }.select { |entry| !block_given? || yield(entry[:mod]) }.map do |entry|
        action = entry[:action]
        { :key => :"mf_key_#{action}", :name => entry[:name], :keybind => true, :help => entry[:help],
          :value => lambda { (Mod_Framework::Hotkeys.remembered_entry(action) || {})[:code] },
          :on_change => lambda { |code| Mod_Framework::Hotkeys.bind_later(action, code) } }
      end
    end

    # Lists the rows of Options > Mods, then the key rows of the hotkeys remembered for the mods that
    # are on and not loaded now, as the title's Mod Configuration lists the Regular mods' hotkeys.
    #
    # @return [Array<Hash>] The rows, as those of Options > Mods.
    def self.rows_with_remembered
      on = Mods.on_names.map { |name| name.downcase }
      Options.rows + remembered_rows { |mod| on.include?(mod.to_s.downcase) }
    end

    # Reads a remembered hotkey.
    #
    # @param action [Symbol, String] The hotkey.
    # @return [Hash, nil] See remembered; nil for one not remembered or unreadable.
    def self.remembered_entry(action)
      text = Settings.setting(REMEMBERED + action.to_s)
      return nil unless text

      mod, code, default, name, help = text.split("\t", 5)
      return nil unless code.to_s =~ /\A\d+\z/ && default.to_s =~ /\A\d+\z/ && name

      { :action => action.to_sym, :mod => unescaped(mod), :code => code.to_i, :default => default.to_i, :name => unescaped(name), :help => unescaped(help.to_s) }
    end

    # Tells whether the key of a hotkey went down since the last ask, for a mod that asks every frame
    # instead of giving a block. A press while the hotkey is quiet or off its scenes is dropped.
    #
    # @param action [Symbol] The hotkey.
    # @return [Boolean] Whether it went down.
    def self.pressed?(action)
      hotkey = @hotkeys[action]
      return false unless hotkey && Mod_Framework.available? && UI::Engine::Key.down?(wanted(hotkey))

      code = code(action)
      return false unless UI::Engine::Key.pressed?(code)

      quiet = quiet_reason(hotkey, code)
      return refused(hotkey, quiet) if quiet

      log("hotkey #{label(action)} pressed: #{hotkey.name}")
      note_fired(code)
      true
    end

    # Notes the key of a hotkey that fired, a button's too, so a text field it opens leaves out its
    # character.
    #
    # @param code [Integer] Windows' code of the key.
    def self.note_fired(code)
      @recent = [code, UI::Engine::Key.frame]
    end

    # Tells the key of a hotkey that fired in this frame or the one before.
    #
    # @return [Integer, nil] Windows' code of the key, nil for none.
    def self.recent_key
      @recent && UI::Engine::Key.frame - @recent[1] <= RECENT_FRAMES ? @recent[0] : nil
    end

    # Has a hotkey open and close a root of the components: it opens the root on its scenes while
    # the root's :if allows and no other root holds the game's buttons, and closes it while it is
    # open; a later root of the same hotkey takes its place.
    #
    # @param action [Symbol] The hotkey.
    # @param root [Object] The root, such as a Box or a Wheel.
    # @return [Boolean] true.
    def self.attach(action, root)
      @roots[action.to_sym] = root
      true
    end

    # Names the key of a hotkey, for the texts that tell the player which key to press.
    #
    # @param action [Symbol] The hotkey.
    # @return [String] The key's name, such as "Y"; "" for a hotkey nobody defined.
    def self.label(action)
      UI::Engine::Serials.read(:keys)
      key = code(action)
      return "" unless key

      Options::Keys.name(key)
    rescue
      plain_name(key)
    end

    # Names a key without the DLL, which names the others: letters, digits, F keys and Tab by their
    # own name, other keys by their code.
    #
    # @param code [Integer] Windows' code of the key.
    # @return [String] The name, such as "K", "F11" or "key 186".
    def self.plain_name(code)
      case code
      when 0x30..0x39, 0x41..0x5A then code.chr
      when 0x70..0x87 then "F#{code - 0x6F}"
      when 0x09 then "Tab"
      when 0x11 then "Ctrl"
      else "key #{code}"
      end
    end

    # Tells a hotkey's name without the group before it, such as "Open" for "[Camp Notes] Open".
    #
    # @param action [Symbol] The hotkey.
    # @return [String] The name; "" for a hotkey nobody defined.
    def self.title(action)
      hotkey = @hotkeys[action]
      hotkey ? hotkey.name.to_s.sub(/\A\s*\[[^\]]+\]\s*/, "").strip : ""
    end

    # Tells the keys the other hotkeys have, which a hotkey being bound may not take.
    #
    # @param action [Symbol] The hotkey being bound.
    # @return [Hash{Integer => String}] Each key with the name of the hotkey that has it.
    def self.taken_keys(action)
      taken = {}
      @hotkeys.each_value do |hotkey|
        next if hotkey.action == action

        key = code(hotkey.action)
        taken[key] ||= hotkey.name.to_s.strip if code?(key)
      end
      taken
    end

    # Tells the names of the hotkeys defined, for a did-you-mean.
    #
    # @return [Array<Symbol>] The names.
    def self.names
      @hotkeys.keys
    end

    # Tells C#'s tree every hotkey with its key and why it is off its scenes, so the tree presses the
    # parts that declare one by the quiet rules of the UI layer; worked out anew only once a hotkey,
    # a key or the scene changed.
    #
    # @return [Hash{String => Array}] Each hotkey's name with [its key's code, why it is off its
    #   scenes or nil].
    def self.for_tree
      scene = defined?(SceneManager) ? SceneManager.scene : nil
      serial = UI::Engine::Serials.serial(:keys)
      return @for_tree if @for_tree && @for_tree_scene.equal?(scene) && @for_tree_serial == serial

      @for_tree_scene = scene
      @for_tree_serial = serial
      @for_tree = {}
      @hotkeys.each_value do |hotkey|
        key = code(hotkey.action)
        @for_tree[hotkey.action.to_s] = [key, off_scene(hotkey, scene)] if code?(key)
      end
      @for_tree
    end

    # Logs a hotkey of a part that C#'s tree kept quiet, with why; a clash with one of the game's
    # buttons only once.
    #
    # @param action [String] The hotkey's name.
    # @param why [String] Why.
    # @param clash [Boolean] Whether a screen used its key as one of the game's buttons.
    def self.quiet_in_tree(action, why, clash = false)
      hotkey = @hotkeys[action.to_sym]
      return unless hotkey
      return log_clash(hotkey, why) if clash

      log("hotkey #{label(hotkey.action)} (#{hotkey.name}) ignored: #{why}")
    end

    # Runs the block of every hotkey whose key went down in the frame, once a frame, right after the
    # frame's tick, so a window it opens is placed and drawn in the same frame.
    def self.fire
      return if @fired == UI::Engine::Key.frame

      @fired = UI::Engine::Key.frame
      pressed = nil
      @hotkeys.each_value do |hotkey|
        next unless (hotkey.block || @roots[hotkey.action]) && UI::Engine::Key.triggered?(wanted(hotkey))

        (pressed ||= []) << hotkey if UI::Engine::Key.triggered?(code(hotkey.action))
      end
      return unless pressed

      pressed.each do |hotkey|
        code = code(hotkey.action)
        quiet = quiet_reason(hotkey, code)
        next refused(hotkey, quiet) if quiet

        log("hotkey #{label(hotkey.action)} pressed: #{hotkey.name}")
        note_fired(code)
        run(hotkey) if hotkey.block
        toggle(hotkey) if @roots[hotkey.action]
      end
    end

    # Opens the root of a hotkey, or closes it while it is open; a refusal is logged with why.
    #
    # @param hotkey [Hotkey] The hotkey.
    def self.toggle(hotkey)
      root = @roots[hotkey.action]
      return root.close(:hotkey) if root.open?

      why = root.refusal
      return log("hotkey #{label(hotkey.action)} did not open #{root.describe}: #{why}") if why

      root.open
    rescue => e
      log("the hotkey #{hotkey.action} could not open or close its root: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
    end
    private_class_method :toggle

    # Adds the rows of every hotkey defined so far and fires the hotkeys from now on, once the game
    # runs with the DLL.
    def self.start
      Hooks.outermost(::Input.singleton_class, :update, :after, "Mod Framework hotkeys") { Mod_Framework::Hotkeys.fire }
      @hotkeys.each_value do |hotkey|
        UI::Engine::Key.watch(code(hotkey.action))
        add_row(hotkey)
      end
      log("the hotkeys and their keys: #{summary}") unless @hotkeys.empty?
    end

    # Lists every hotkey with the key bound to it, for the log.
    #
    # @return [String] Each hotkey's name and key.
    def self.summary
      @hotkeys.values.map { |hotkey| "#{hotkey.name} #{label(hotkey.action)}" }.join(", ")
    end

    # Remembers a hotkey of a mod in Patch with its key now, once the settings hold something else.
    #
    # @param hotkey [Hotkey] The hotkey.
    def self.remember(hotkey)
      mod = Mods.name_of(hotkey.mod)
      return unless mod && Mod_Framework.available?

      key = REMEMBERED + hotkey.action.to_s
      text = remembered_text(mod, code(hotkey.action), hotkey.default, hotkey.name, hotkey.help)
      Settings.store(key, text) unless Settings.setting(key) == text
    end
    private_class_method :remember

    # Binds the key bound to a hotkey while it was not defined, once its mod defines it again.
    #
    # @param hotkey [Hotkey] The hotkey.
    def self.bind_waiting(hotkey)
      key = BOUND_LATER + hotkey.action.to_s
      bound = Mod_Framework.available? ? Settings.setting(key) : nil
      return unless bound

      Settings.forget(key)
      bind(hotkey.action, bound.to_i) if bound =~ /\A\d+\z/
    end
    private_class_method :bind_waiting

    # Writes a remembered hotkey as one line of the settings.
    #
    # @param mod [String] The mod's folder name.
    # @param code [Integer] Its key.
    # @param default [Integer] Its key until the player binds another.
    # @param name [String] Its row's name.
    # @param help [String] Its row's help.
    # @return [String] The line.
    def self.remembered_text(mod, code, default, name, help)
      [escaped(mod), code.to_i, default.to_i, escaped(name), escaped(help)].join("\t")
    end
    private_class_method :remembered_text

    # Writes a text with escapes for what would break its line.
    #
    # @param text [String] The text.
    # @return [String] The text escaped.
    def self.escaped(text)
      text.to_s.gsub(/[\\\t\r\n]/) { |character| ESCAPES[character] }
    end
    private_class_method :escaped

    # Reads a text with escapes.
    #
    # @param text [String] The text escaped.
    # @return [String] The text.
    def self.unescaped(text)
      text.to_s.gsub(/\\[\\trn]/) { |escape| ESCAPES.key(escape) }
    end
    private_class_method :unescaped

    # Adds a hotkey's key row to Options > Mods.
    #
    # @param hotkey [Hotkey] The hotkey.
    def self.add_row(hotkey)
      return if hotkey.row

      key = :"mf_key_#{hotkey.action}"
      action = hotkey.action
      added = Options.insert(:key => key, :name => hotkey.name, :keybind => true, :help => hotkey.help,
                             :value => lambda { Mod_Framework::Hotkeys.code(action) },
                             :on_change => lambda { |code| Mod_Framework::Hotkeys.bind(action, code) })
      hotkey.row = key if added
    end
    private_class_method :add_row

    # Tells why a hotkey stays quiet now.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param code [Integer] Windows' code of its key.
    # @return [String, Symbol, nil] Why, :typing while a text field types, :clash while a screen uses
    #   its key as one of the game's buttons, nil when it is not quiet.
    def self.quiet_reason(hotkey, code)
      return :typing if UI.typing?
      return "a question box is open" if UI::Engine::Confirm.open? && ![:accept, :decline].include?(hotkey.action)
      return "a field waits for the key the player presses" if UI::Engine::KeyCapture.waiting?
      return "an open window took the key" if UI::Engine::Tree.taken?(code)

      off_scene(hotkey, SceneManager.scene) || clash(hotkey, code)
    end
    private_class_method :quiet_reason

    # Tells whether a screen uses the key of a hotkey as one of the game's extra buttons: what C#'s
    # tree told for the windows of the framework, else whether the game itself asked about the
    # button before the tick, as a menu of the game that filters by D; the clash is logged once.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param code [Integer] Windows' code of its key.
    # @return [Symbol, nil] :clash, nil while no screen uses the button.
    def self.clash(hotkey, code)
      why = UI::Engine::Tree.clash(hotkey.action)
      button = why ? nil : UI::Engine::Tick::EXTRA_BUTTONS.find { |each| UI::Engine::Buttons.asked?(each) && UI::Engine::Pad.keys(each).include?(code) }
      why ||= format(GAME_SCREEN_CLASH, button) if button
      return nil unless why

      log_clash(hotkey, why)
      :clash
    end
    private_class_method :clash

    # Logs a hotkey whose key a screen uses as one of the game's buttons, once per hotkey and reason.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param why [String] Why.
    def self.log_clash(hotkey, why)
      log_once([:clash, hotkey.action, why], "hotkey #{label(hotkey.action)} (#{hotkey.name}) ignored: #{why}, which wins over the hotkey")
    end
    private_class_method :log_clash

    # Tells why a hotkey is off its scenes.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param scene [Scene_Base, nil] The scene now.
    # @return [String, nil] Why, nil while it is on its scenes or has none.
    def self.off_scene(hotkey, scene)
      return nil unless hotkey.scenes

      hotkey.scenes.any? { |klass| scene.is_a?(klass) } ? nil : "it works only on #{hotkey.scenes.map { |klass| klass.name }.join(', ')}"
    end
    private_class_method :off_scene

    # Reads a hotkey's key as its definition gives it: a key's name, such as "G" or "F5", or a code.
    #
    # @param key [String, Integer, nil] The key.
    # @return [Integer, Object] Windows' code of a named key, else the key as given.
    def self.key_code(key)
      return key unless key.is_a?(String)

      name = key.strip.upcase
      return name.ord if name =~ /\A[A-Z0-9]\z/
      return 0x6F + name[1..-1].to_i if name =~ /\AF([1-9]|1[0-9]|2[0-4])\z/

      KEY_CODES[name] || key
    end
    private_class_method :key_code

    # Logs why a hotkey pressed did nothing; nothing while the player types, whose letters would
    # otherwise land in the log, and nothing for a clash, logged once already.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param reason [String, Symbol] Why.
    # @return [Boolean] false.
    def self.refused(hotkey, reason)
      log("hotkey #{label(hotkey.action)} (#{hotkey.name}) ignored: #{reason}") unless reason == :typing || reason == :clash
      false
    end
    private_class_method :refused

    # Runs a hotkey's block, logging its failure in the log of the mod that defined it.
    #
    # @param hotkey [Hotkey] The hotkey.
    def self.run(hotkey)
      hotkey.block.call
    rescue => e
      message = "the block of the hotkey #{hotkey.action} at #{Array(hotkey.block.source_location).join(':')} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}"
      hotkey.logger.respond_to?(:log) ? hotkey.logger.log(message) : log(message)
    end
    private_class_method :run

    # Reads the key a hotkey's store keeps for it.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @return [Integer, String, nil] The key's code; nil while the store keeps none; the text kept
    #   when it is no key or one of the framework's own keys.
    def self.saved(hotkey)
      stored = hotkey.store.setting(hotkey.setting)
      return nil if stored.nil?

      stored = stored.to_s
      return nil if stored.empty?
      return stored unless stored.count(DIGITS) == stored.size && code?(stored.to_i)

      framework_key?(stored.to_i, hotkey.action) ? stored : stored.to_i
    end
    private_class_method :saved

    # Tells the key a hotkey wants before any other hotkey is asked: the one its store keeps, else
    # its default.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @return [Integer] Windows' code of the key.
    def self.wanted(hotkey)
      saved = saved(hotkey)
      saved.is_a?(Integer) ? saved : hotkey.default
    end
    private_class_method :wanted

    # Tells how strongly a hotkey holds the key it wants.
    #
    # @param saved [Integer, String, nil] What saved read for it.
    # @return [Integer] SAVED, DEFAULT or FALLBACK.
    def self.rank(saved)
      return SAVED if saved.is_a?(Integer)

      saved ? FALLBACK : DEFAULT
    end
    private_class_method :rank

    # Finds another hotkey that holds the key a hotkey wants, as a key row refuses a key another
    # hotkey has: one that holds it more strongly, or as strongly and was defined earlier.
    #
    # Two defaults share a key, as their mods chose them for screens of their own, such as Move Down
    # and a hotkey of the map.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param key [Integer] The key it wants.
    # @param rank [Integer] How strongly it wants the key, see rank.
    # @return [Hotkey, nil] The hotkey that holds the key, nil for none.
    def self.holder(hotkey, key, rank)
      earlier = true
      @hotkeys.each_value do |other|
        next earlier = false if other.equal?(hotkey)

        saved = saved(other)
        next unless (saved.is_a?(Integer) ? saved : other.default) == key

        held = rank(saved)
        return other if held < rank || (held == rank && earlier && rank != DEFAULT)
      end
      nil
    end
    private_class_method :holder

    # Words the log line of a hotkey whose kept key was refused or whose key another hotkey holds.
    #
    # @param hotkey [Hotkey] The hotkey.
    # @param saved [Integer, String, nil] What saved read for it.
    # @param key [Integer] The key it wanted.
    # @param holder [Hotkey, nil] The hotkey that holds that key.
    # @return [String] The line.
    def self.key_note(hotkey, saved, key, holder)
      kept = "#{hotkey.setting}=#{saved}"
      if saved.is_a?(String)
        kept += saved =~ /\A\d+\z/ && code?(saved.to_i) ? " is one of the framework's own keys" : " is no key"
        return "#{kept}, #{hotkey.action} keeps #{plain_name(key)}" unless holder

        return "#{kept} and #{plain_name(key)}, its default, is the key of #{holder.name}, so #{hotkey.action} stays unbound"
      end

      "#{plain_name(key)}#{saved ? " (#{kept})" : ', its default,'} is the key of #{holder.name}, so #{hotkey.action} stays unbound"
    end
    private_class_method :key_note

    # Tells whether a key is one of the framework's own, which no hotkey sits on: a key it reads
    # itself, a cancel key or the key of its jump hotkey, by the keys F1 binds now, so the answers
    # are asked anew once the keys' serial changed.
    #
    # @param code [Integer] Windows' code of the key.
    # @param action [Symbol] The hotkey that would have it.
    # @return [Boolean] Whether it is; false without the DLL, which judges the keys.
    def self.framework_key?(code, action)
      return false unless Mod_Framework.available?
      return true if action != :list_jump && @hotkeys.key?(:list_jump) && code == wanted(@hotkeys[:list_jump])

      serial = UI::Engine::Serials.serial(:keys)
      @framework_keys = {} unless @framework_serial == serial
      @framework_serial = serial
      @framework_keys[code] = FRAMEWORK_VERDICTS.include?(Options::Keys.judge(code)) unless @framework_keys.key?(code)
      @framework_keys[code]
    end
    private_class_method :framework_key?

    # Tells whether a value is a key code Windows has.
    #
    # @param code [Object] The value.
    # @return [Boolean] Whether it is.
    def self.code?(code)
      code.is_a?(Integer) && code >= 1 && code <= MAX_CODE
    end
    private_class_method :code?

    # Logs a definition refused, once per mod and reason.
    #
    # @param mod [String] The file of the mod that defined it.
    # @param why [String] Why.
    # @return [Boolean] false.
    def self.refuse(mod, why)
      log_once([:refused, mod, why], "#{mod} defined a hotkey, refused: #{why}")
      false
    end
    private_class_method :refuse

    define(:accept, :key => UI::Engine::Confirm::ACCEPT_KEY, :name => GROUP + "Accept Notification",
                    :help => "Answers yes in a question box and accepts a notice.")
    define(:decline, :key => UI::Engine::Confirm::DECLINE_KEY, :name => GROUP + "Decline Notification",
                     :help => "Answers no in a question box and declines a notice.")

    # Only the framework's mod list takes the move hotkeys: C#'s tree moves the rows of the Mod
    # List, which gives move_hotkeys:.
    define(:list_move_up, :key => MOVE_UP_KEY, :name => GROUP + "Move Up",
                          :help => "Moves the mod under the cursor in the Mod List one place up within its tag, so it loads earlier.")
    define(:list_move_down, :key => MOVE_DOWN_KEY, :name => GROUP + "Move Down",
                            :help => "Moves the mod under the cursor in the Mod List one place down within its tag, so it loads later.")

    define(:list_jump, :key => LIST_JUMP_KEY, :name => GROUP + "Jump Out of a List",
                       :help => "Held with an arrow, moves the focus out of a list to the part beside it that way; on a gamepad, hold A with the d-pad.")

    Run.on_start("hotkeys", :dll => true) { Mod_Framework::Hotkeys.start }
  end
end
