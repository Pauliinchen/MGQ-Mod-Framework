#----------------------------------------------------------------
#  layer_game_windows.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Worked out the looks of a row anew when the game draws it alone
#                            - Gave the rows of a game list window a name color, a name, a grey look and a line above
#                              through rows
#                            - Read a value a game window keeps for read, such as the party edit's actors
#                            - Named a game window by a nested class name, such as a plugin's
#                            - Hooked a window class a patch names once the class exists, also after the game runs
#                            - Took the patches on a window made before its class was hooked at its next update
#      Paulinchen  2026-11-07: Removed the enabled: of a command, which disabled: replaces
#      Paulinchen  2026-11-06: Made the handle of a replaced window a plain object
#                            - Removed a command's remember:, which no mod gave
#                            - Removed the UI Inspector's lookups of a window's selector and of the mod that added a command
#                            - Left a window the player moved where it is as it updates
#                            - Answered is_a? and the other calls every object answers from Facade, so a scene's variables may hold it
#                            - Named the game's windows by their class alone, since the framework names none of its own any more
#      Paulinchen  2026-11-05: Greyed out the commands the game disables in a patched command window instead of see-through
#      Paulinchen  2026-11-04: Told the selector of a game window, its patches and the mod that added a command, for the
#                              UI Inspector
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # UI.patch on the game's own windows, named by their class (Window_MenuCommand): the commands
      # of a command window are parts with their symbols as ids, the rows of a list window take
      # looks through rows, and the window itself takes a few params. The patches run again each
      # time the window makes its command list, and the looks of the rows each time it draws them,
      # so the game's refreshes keep them; a patch registered later reaches the windows open then at
      # their next update.
      module GameWindows
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # Who hooks the game's windows, for the hooks' log.
        TAG = "Mod Framework game windows"

        # Who follows every game window as it is made while a patch names a class not there yet.
        LATE_TAG = "Mod Framework late game windows"

        # The type a selector names a command by.
        COMMAND = "command"

        # The events a patch wraps: a command's pick, and cancel on the window.
        EVENTS = { :command => [:click], :window => [:cancel] }

        # The params UI.patch sets on a game window, checked as markup is.
        WINDOW = Declarations::Declaration.new(:game_window, :common => false, :params => Builtins::GAME_WINDOW)

        # The params of a game command that set cannot change, with what to use instead.
        FIXED = { :id => "it is the command's symbol", :key => "it tells added commands apart",
                  :on_click => "wrap the pick with t.on \"#symbol\", :click instead" }

        # One part of a type of a selector that can name a game window class, such as PTEdit of
        # Foo::PTEdit::Window_PartyMember; the parts' types, such as window, are no constants.
        CLASS_NAME = /\A[A-Z]\w*\z/

        # The params of a row of a game list window, checked as markup is.
        ROW = Declarations::Declaration.new(:row, :common => false, :params => Builtins::GAME_ROW)

        # The looks of a row that a command's entry carries; its name is the command's text.
        COMMAND_LOOKS = [:name_color, :grey, :line_above]

        # One command of a game command window, as a patch's target: the window and the command's
        # entry in the window's list.
        CommandPart = Struct.new(:window, :entry)

        @classes = {}
        @hooked = {}
        @lists = {}
        @for_class = {}
        @missing = {}
        @looked = {}
        @started = false

        # Starts the patches on the game's windows as the game runs: the classes they name are
        # hooked, and a class a patch names that is not there yet once a window of it is made.
        def self.start
          @started = true
          Hooks.after(::Window_Base, :initialize, LATE_TAG) { |*_args| Mod_Framework::UI::Engine::GameWindows.window_made(self) } if defined?(::Window_Base)
          patched
        end

        # Follows a new patch: the classes it names are hooked once the game runs, and every window
        # of them takes the patches anew at its next update.
        def self.patched
          @for_class = {}
          @looked = {}
          return unless @started

          @missing = {}
          Patches.all.each do |patch|
            begin
              patch.paths.each do |steps|
                type = steps[0].type
                @missing[type] = true if type && class_path?(type) && class_named(type).nil?
                classes_of(steps[0]).each { |klass| install(klass) }
              end
            rescue => e
              log_once([:install, patch.seq, e.class], "#{patch.mod}: the game windows of #{patch.selector.inspect} could not be hooked, so the patch skips them: #{Logging.failure(e)}")
            end
          end
        end

        # Looks for the classes the patches name but were not there, once per class of the windows
        # made: a class defined after its patch, such as by a mod loaded as the player enters, is
        # hooked as its first window is made and takes the patches at its first update.
        #
        # @param window [Window_Base] The window just made.
        def self.window_made(window)
          return if @missing.empty? || @looked[window.class]

          @looked[window.class] = true
          patched if window.class.ancestors.any? { |klass| @missing[klass.name.to_s] }
        rescue => e
          log_once([:late, window.class, e.class], "looking for the patched classes as a #{window.class} was made FAILED: #{Logging.failure(e)}")
        end

        # Tells whether a patch's target is a game window or one of its commands.
        #
        # @param target [Object] The target.
        # @return [Boolean] Whether it is.
        def self.target?(target)
          target.is_a?(CommandPart) || (defined?(::Window_Base) && target.is_a?(::Window_Base)) ? true : false
        end

        # Names a game window or a command for the log.
        #
        # @param target [Window_Base, CommandPart] The window or the command.
        # @return [String] Such as "Window_MenuCommand" or "command #equip of Window_MenuCommand".
        def self.describe(target)
          return "#{COMMAND} ##{target.entry[:symbol]} of #{name_of(target.window)}" if target.is_a?(CommandPart)

          name_of(target)
        end

        # Reads a value a game window keeps and answers by a reader of the same name, such as the
        # party edit's actors; a method that only acts is no value, so it is refused.
        #
        # @param target [Window_Base, CommandPart] The window, or one of its commands.
        # @param name [Symbol] The value.
        # @return [Object] The value.
        # @raise [MarkupError] The window keeps no such value.
        def self.read(target, name)
          window = target.is_a?(CommandPart) ? target.window : target
          unless name.to_s =~ /\A[a-z_]\w*\z/ && window.instance_variable_defined?(:"@#{name}") && window.respond_to?(name)
            raise MarkupError, "#{name_of(window)} keeps no value #{name} it answers; read the game's own values there"
          end

          window.public_send(name)
        end

        # Lists what other mods may name in a game window: its commands by their symbols.
        #
        # @param window [Window_Base] The window.
        # @return [Hash] :ids (each [id, type]), :types and :exposes, as Patches.parts_of answers.
        def self.parts_of(window)
          list = window.instance_variable_get(:@list)
          ids = list.is_a?(Array) ? list.map { |entry| [entry[:symbol].to_s, COMMAND] } : []
          { :ids => ids, :types => ids.empty? ? [] : [COMMAND], :exposes => [] }
        end

        # Takes a game window as it is made: a class whose command list was made before it was
        # hooked makes it anew, and the window takes the patches on it.
        #
        # @param window [Window_Base] The window.
        def self.made(window)
          return if window.instance_variable_get(:@mf_game_made)

          window.instance_variable_set(:@mf_game_made, true)
          fresh = hook_list(window.class)
          note_rows(window) unless fresh
          if fresh || window.instance_variable_get(:@mf_patch_version) != Patches.version
            catch_up(window)
          else
            follow_list(window)
          end
        rescue => e
          log_once([:made, window.class, e.class], "the patches of a #{window.class} FAILED as it was made: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Follows a game window after its update: a window made before its class was hooked takes
        # the patches as if made now, any other the patches registered since it last took them, and
        # the params they set on it, which the game's scenes may have changed.
        #
        # @param window [Window_Base] The window.
        def self.updated(window)
          return made(window) unless window.instance_variable_get(:@mf_game_made)

          catch_up(window) if window.instance_variable_get(:@mf_patch_version) != Patches.version
          keep_sets(window)
        rescue => e
          log_once([:updated, window.class, e.class], "the patches of a #{window.class} FAILED in its update: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Runs the patches on a command list the game just made: the commands they add, change, hide
        # and wrap, and the params they set on the window.
        #
        # @param window [Window_Command] The window.
        def self.edit_list(window)
          list = window.instance_variable_get(:@list)
          return unless list.is_a?(Array)

          made = window.instance_variable_get(:@mf_game_made)
          height = made ? game_height(window) : nil
          run_patches(window, list)
          return unless made

          window.instance_variable_get(:@mf_patch_state)[:game_height] = height
          follow_list(window)
        rescue => e
          log_once([:edit, window.class, e.class], "the patches of a #{window.class} FAILED on its commands: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Runs a handler of a game window through the handlers patches wrap around it, the last loaded
        # outermost.
        #
        # @param window [Window_Selectable] The window.
        # @param symbol [Symbol] The handler's symbol: a command's, or :cancel.
        # @param original [Proc] Runs the game's handler.
        # @return [Object] What the outermost handler answered, false when one refused.
        def self.call_handler(window, symbol, original)
          state = window.instance_variable_get(:@mf_patch_state)
          return original.call if state.nil?

          wraps = state[:wraps][symbol]
          return original.call if wraps.nil? || wraps.empty?

          call = lambda { |_values| original.call }
          wraps.each { |op, entry| call = wrapper(op, entry, window, symbol, call) }
          call.call([])
        end

        # Draws a row of a game list window in the look the patches' rows give it; a command a patch
        # gave an icon or a badge draws them, and a disabled one greyed out.
        #
        # @param window [Window_Selectable] The window.
        # @param index [Integer] The row.
        # @param original [Proc] Draws the row as the game does.
        # @return [Object] What the drawing returns.
        def self.draw_item(window, index, original)
          Rows.drawing(window, index) do
            command_window?(window) ? Adopt.greying(window) { draw_row(window, index, original) } : original.call
          end
        end

        # Tells whether a game window lists commands.
        #
        # @param window [Window_Base] The window.
        # @return [Boolean] Whether it does.
        def self.command_window?(window)
          window.instance_variable_get(:@list).is_a?(Array)
        end

        # Tells the looks the patches' rows give the rows of a list window, worked out once while the
        # window draws all its rows and anew for each row it draws alone; a patch whose block raises
        # is switched off for the window.
        #
        # A row drawn alone follows a change the window did not refresh for, such as two characters
        # the formation swapped.
        #
        # @param window [Window_Selectable] The window.
        # @return [Hash{Integer => Hash}] Each row's look by its index; a row without one is left out.
        def self.row_looks(window)
          looks = window.instance_variable_get(:@mf_row_looks)
          return looks if looks && window.instance_variable_get(:@mf_drawing_rows)

          looks = {}
          state = window.instance_variable_get(:@mf_patch_state)
          ops = state ? state[:row_ops] : []
          unless ops.empty?
            rows = Array.new(window.item_max) { |index| { :index => index } }
            ops.each { |op, entry| guarded(entry, op) { rows = list_rows(window, op, rows) } }
            rows.each { |row| looks[row[:index]] = row if Rows.look?(row) }
          end
          window.instance_variable_set(:@mf_row_looks, looks)
        end

        # Finds a color of a row's look in the window's look; a game text color by its number in
        # the window's own skin, and an animated name notes the row, which draws anew while the
        # window shows.
        #
        # @param window [Window_Selectable] The window.
        # @param index [Integer] The row.
        # @param color [Symbol, String, Array, Integer] The color, as a :color param takes it.
        # @return [Color] The color.
        def self.row_color(window, index, color)
          return (window.respond_to?(:text_color) ? window.text_color(color) : UI.text_color(color)) if color.is_a?(Integer)
          return Colors.color_of(color) || Style::TEXT unless color.is_a?(Symbol)

          palette = Theme.palette_for(window)
          Colors.note_row(window, index) if palette.animated(color)
          palette.now(color) || Style::TEXT
        end

        # Draws a row of a command window, see draw_item.
        #
        # @param window [Window_Command] The window.
        # @param index [Integer] The row.
        # @param original [Proc] Draws the row as the game does.
        # @return [Object] What the drawing returns.
        def self.draw_row(window, index, original)
          state = window.instance_variable_get(:@mf_patch_state)
          entry = state && (window.instance_variable_get(:@list) || [])[index]
          look = entry && state[:looks][entry[:symbol]]
          return original.call unless look && (look[:icon] || look.key?(:badge))

          rect = window.item_rect_for_text(index)
          enabled = entry[:enabled] ? true : false
          left = rect.x
          right = rect.x + rect.width - (look.key?(:badge) ? Badge::ROOM : 0)
          window.send(:change_color, window.send(:normal_color), enabled)
          if look[:icon]
            window.send(:draw_icon, look[:icon], left, rect.y, enabled)
            left += ICON_STEP
          end
          window.send(:draw_text, left, rect.y, right - left, rect.height, entry[:name], window.send(:alignment))
          text = look.key?(:badge) ? Badge.text_of(live(look[:badge])) : nil
          Badge.draw(window, index, rect, text, look[:badge_color] || :gold) if text
        end
        private_class_method :draw_row

        # Runs the pick of a command a patch added: its on_click, then the window takes the keys
        # again once every window its handler opened closed, at once when it opened none, and never
        # once the window is gone.
        #
        # @param window [Window_Command] The window.
        # @param symbol [Symbol] The command's symbol.
        def self.pick(window, symbol)
          state = window.instance_variable_get(:@mf_patch_state)
          added = state && state[:added][symbol]
          return Adopted.give_back(window) unless added

          node = added[:node]
          before = Tree.roots
          answer = Layer.invoke(node.owner, node.params[:on_click], [])
          Adopted.give_back_after(window, answer == :off ? :off : nil, before)
        rescue => e
          Errors.report(e, "the command #{symbol} of #{name_of(window)}")
          Adopted.give_back(window)
        end

        # Hooks a game window class, once: its windows take the patches as they are made and after
        # each update, its command list as it is made, its handlers through the wrapping patches,
        # its rows in the looks the patches' rows give and with the icons and badges patches give
        # its commands, its disabled commands greyed out.
        #
        # @param klass [Class] The class.
        def self.install(klass)
          return if @classes[klass]

          @classes[klass] = true
          hook(klass, :initialize) { Hooks.after(klass, :initialize, TAG) { |*_args| Mod_Framework::UI::Engine::GameWindows.made(self) } }
          hook(klass, :update) { Hooks.after(klass, :update, TAG) { Mod_Framework::UI::Engine::GameWindows.updated(self) } }
          hook(klass, :call_handler) { Hooks.around(klass, :call_handler, TAG) { |window, args, original| Mod_Framework::UI::Engine::GameWindows.call_handler(window, args[0], original) } }
          Adopt.grey_disabled(klass) if klass.method_defined?(:make_command_list)
          install_rows(klass) if klass.method_defined?(:draw_item)
          Hidden.install(klass)
          hook_list(klass)
        end

        # Hooks what a game list window class draws its rows with: each row in its look, the looks
        # worked out once as the window draws all its rows, and the colors, texts, icons and faces a
        # row draws, the name inside the methods that draw a character's name.
        #
        # @param klass [Class] The class.
        def self.install_rows(klass)
          hook(klass, :draw_item) { Hooks.around(klass, :draw_item, TAG) { |window, args, original| Mod_Framework::UI::Engine::GameWindows.draw_item(window, args[0], original) } }
          hook(klass, :draw_all_items) { Hooks.around(klass, :draw_all_items, TAG) { |window, _args, original| Mod_Framework::UI::Engine::GameWindows::Rows.drawing_all(window, original) } }
          [:change_color, :draw_text, :draw_icon, :draw_face].each do |name|
            hook(klass, name) { Hooks.around(klass, name, TAG) { |window, args, original| Mod_Framework::UI::Engine::GameWindows::Rows.send(name, window, args, original) } }
          end
          (klass.instance_methods + klass.private_instance_methods).grep(Rows::NAMING).each do |name|
            hook(klass, name) { Hooks.around(klass, name, TAG) { |window, _args, original| Mod_Framework::UI::Engine::GameWindows::Rows.naming(window, original) } }
          end
        end
        private_class_method :install_rows

        # Hooks a method of a game window class, once along its ancestors: a class that inherits the
        # method from a class hooked before already runs that hook, and a second one would run it
        # twice.
        #
        # @param klass [Class] The class.
        # @param name [Symbol] The method.
        # @yield Hooks the method on the class.
        def self.hook(klass, name)
          return unless klass.method_defined?(name) || klass.private_method_defined?(name)

          owner = klass.instance_method(name).owner
          return if owner != klass && @hooked[[owner, name]]

          @hooked[[klass, name]] = true
          yield
        end
        private_class_method :hook

        # Hooks the method that makes a class's command list, where it is written, once: a class
        # that only inherits it is hooked where it is written.
        #
        # @param klass [Class] The window's class.
        # @return [Boolean] Whether it was hooked now.
        def self.hook_list(klass)
          return false unless klass.method_defined?(:make_command_list)

          owner = klass.instance_method(:make_command_list).owner
          return false if @lists[owner]

          @lists[owner] = true
          Hooks.around(owner, :make_command_list, TAG) do |window, _args, original|
            depth = window.instance_variable_get(:@mf_making).to_i
            window.instance_variable_set(:@mf_making, depth + 1)
            begin
              original.call
            ensure
              window.instance_variable_set(:@mf_making, depth)
            end
            Mod_Framework::UI::Engine::GameWindows.edit_list(window) if depth == 0
          end
          true
        end

        # Tells whether a step of a selector names a game window: its class or one it is built on.
        #
        # @param window [Window_Base] The window.
        # @param step [Selector::Step] The step.
        # @return [Boolean] Whether it does.
        def self.fits_window?(window, step)
          return false unless step.classes.empty?
          return false if step.type && !window.class.ancestors.any? { |klass| klass.is_a?(Class) && klass.name == step.type }

          step.ids.empty?
        end

        # Tells whether a step of a selector names a command: by the type command, its symbol, and
        # for a command a patch added, its mod and classes.
        #
        # @param window [Window_Base] The window.
        # @param entry [Hash] The command's entry in the window's list.
        # @param step [Selector::Step] The step.
        # @param state [Hash] What the patches did to the window so far.
        # @return [Boolean] Whether it does.
        def self.fits_command?(window, entry, step, state)
          return false if step.type && step.type != COMMAND

          added = state[:added][entry[:symbol]]
          ok = step.ids.all? { |owner, name| entry[:symbol].to_s == name && (owner.nil? || added.nil? || plain(owner) == plain(added[:mod])) }
          return false unless ok && (step.type || !step.ids.empty? || !step.classes.empty?)

          classes = added ? Array(added[:node].params[:class]).map { |each| each.to_s } : []
          step.classes.all? { |name| classes.include?(name) }
        end

        # Tells the game window classes a step of a selector names.
        #
        # @param step [Selector::Step] The step.
        # @return [Array<Class>] The classes.
        def self.classes_of(step)
          klass = step.type && class_path?(step.type) ? class_named(step.type) : nil
          klass.is_a?(Class) && defined?(::Window_Base) && klass <= ::Window_Base ? [klass] : []
        end
        private_class_method :classes_of

        # Tells whether a type of a selector is written as a class name, nested ones too.
        #
        # @param type [String] The type, such as "Foo::PTEdit::Window_PartyMember".
        # @return [Boolean] Whether it is.
        def self.class_path?(type)
          type.split("::", -1).all? { |part| part =~ CLASS_NAME }
        end
        private_class_method :class_path?

        # Finds a class or module by its name, part by part, since Ruby 1.9 finds no nested name at
        # once.
        #
        # @param name [String] The name, such as "Foo::PTEdit::Window_PartyMember".
        # @return [Module, nil] What the name names, nil while it names nothing.
        def self.class_named(name)
          name.split("::").inject(Object) do |scope, part|
            return nil unless scope.is_a?(Module) && scope.const_defined?(part, false)

            scope.const_get(part, false)
          end
        end
        private_class_method :class_named

        # Lists the patches whose selectors start at a window, in the order they apply.
        #
        # @param window [Window_Base] The window.
        # @return [Array<Patches::Patch>] The patches.
        def self.patches_for(window)
          @for_class[window.class] ||= Patches.all.select { |patch| patch.paths.any? { |steps| steps.size <= 2 && fits_window?(window, steps[0]) } }
        end

        # Runs every patch on a window: its block with each target, then the operations it asked
        # for, hiding last, and keeps what they did on the window.
        #
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>, nil] Its command list, nil for a window without one.
        def self.run_patches(window, list)
          window.instance_variable_set(:@mf_patch_version, Patches.version)
          state = { :added => {}, :wraps => {}, :looks => {}, :sets => {}, :set_by => {}, :hides => [], :row_ops => [] }
          root = name_of(window)
          rows = list ? list.size : nil
          patches_for(window).each do |patch|
            next if Patches.off?(patch, root)

            targets_of(patch, window, list, state).each do |target|
              entry = run(patch, target, root)
              next unless entry

              entry.ops.each { |op| guarded(entry, op) { apply(window, list, op, entry, target, state) } }
            end
          end
          state[:hides].each { |symbol| list.reject! { |each| each[:symbol] == symbol } } if list
          state[:rows] = list.size - rows if list
          window.instance_variable_set(:@mf_patch_state, state)
        end
        private_class_method :run_patches

        # Lists a patch's targets in a window: the window, or the commands its selector names.
        #
        # @param patch [Patches::Patch] The patch.
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>, nil] The command list.
        # @param state [Hash] What the patches did so far.
        # @return [Array] The window and the CommandParts.
        def self.targets_of(patch, window, list, state)
          found = []
          patch.paths.each do |steps|
            next unless fits_window?(window, steps[0])

            if steps.size == 1
              found << window unless found.include?(window)
            elsif steps.size == 2 && list
              list.each { |entry| found << CommandPart.new(window, entry) if fits_command?(window, entry, steps[1], state) }
            end
          end
          found
        end
        private_class_method :targets_of

        # Runs a patch's block on a target, switching the patch off for the window where it raises.
        #
        # @param patch [Patches::Patch] The patch.
        # @param target [Window_Base, CommandPart] The target.
        # @param root [String] The window's class name.
        # @return [Patches::Entry, nil] The patch run, nil when it raised.
        def self.run(patch, target, root)
          handle = Patches::Handle.new(patch, target)
          patch.block.call(handle)
          Patches::Entry.new(patch, handle.ops, target, root)
        rescue StandardError => e
          Patches.switch_off(patch, root, nil, e)
          nil
        end
        private_class_method :run

        # Runs an operation, switching its patch off for the window where it raises.
        #
        # @param entry [Patches::Entry] The patch run.
        # @param op [Patches::Op] The operation.
        # @yield The operation.
        def self.guarded(entry, op)
          return if Patches.off?(entry.patch, entry.root)

          yield
        rescue StandardError => e
          Patches.switch_off(entry.patch, entry.root, op, e)
        end
        private_class_method :guarded

        # Applies one operation of a patch run on a window or a command.
        #
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>, nil] Its command list.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param target [Window_Base, CommandPart] The patch's target.
        # @param state [Hash] What the patches did so far.
        def self.apply(window, list, op, entry, target, state)
          raise MarkupError, "replace takes no game window; draw your own in its place with UI.replace_window" if op.kind == :replace

          commands = op.paths ? matched(window, list, op, entry, target, state) : nil
          on_window = op.paths.nil? && target.equal?(window)
          case op.kind
          when :set
            on_window ? set_window(window, op, entry, state) : each_command(commands, target) { |found| set_command(found, op, entry, state) }
          when :hide
            on_window ? state[:sets][:hidden] = true : each_command(commands, target) { |found| state[:hides] << found[:symbol] }
          when :on
            wrap(window, op, entry, on_window ? :window : :command, on_window ? nil : commands || [target.entry], state)
          when :rows
            raise MarkupError, "rows changes the rows of #{describe(window)} itself; t.rows takes no selector there" unless on_window
            raise MarkupError, "#{describe(window)} has no rows" unless window.respond_to?(:draw_item)

            list ? command_rows(list, op) : state[:row_ops] << [op, entry]
          else
            add(window, list, op, entry, target, commands, state)
          end
        end
        private_class_method :apply

        # Runs the block of rows on a command list, whose answer becomes the list.
        #
        # @param list [Array<Hash>] The command list.
        # @param op [Patches::Op] The operation.
        # @raise [MarkupError] The block answered no commands, or a look that does not fit.
        def self.command_rows(list, op)
          changed = op.block.call(list.map { |each| each.dup })
          unless changed.is_a?(Array) && changed.all? { |each| each.is_a?(Hash) && each[:symbol] }
            raise MarkupError, "the block of rows answers the commands as an Array of { name:, symbol:, enabled: }, not #{Declarations.show(changed)}"
          end

          changed.each { |row| COMMAND_LOOKS.each { |key| ROW.check(key, row[key]) if row.key?(key) } }
          list.replace(changed)
        end
        private_class_method :command_rows

        # Runs the block of rows on the rows of a list window, each { index: } and the looks the
        # patches before gave it.
        #
        # @param window [Window_Selectable] The window.
        # @param op [Patches::Op] The operation.
        # @param rows [Array<Hash>] The rows.
        # @return [Array<Hash>] The rows the block answered.
        # @raise [MarkupError] The block answered no rows, or a look that does not fit.
        def self.list_rows(window, op, rows)
          changed = op.block.call(rows.map { |each| each.dup })
          unless changed.is_a?(Array) && changed.all? { |each| each.is_a?(Hash) && each[:index].is_a?(Integer) }
            raise MarkupError, "the block of rows answers the rows of #{describe(window)} as an Array of { index:, name_color:, grey:, ... }, not #{Declarations.show(changed)}"
          end

          changed.each { |row| row.each { |key, value| ROW.check(key, value) unless key == :index } }
          changed
        end
        private_class_method :list_rows

        # Lists the commands an operation's selector names inside its target, and logs once a
        # selector that names none.
        #
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>, nil] Its command list.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param target [Window_Base, CommandPart] The patch's target.
        # @param state [Hash] What the patches did so far.
        # @return [Array<Hash>] The commands' entries.
        def self.matched(window, list, op, entry, target, state)
          found = []
          if target.equal?(window) && list
            list.each { |each| found << each if op.paths.any? { |steps| steps.size == 1 && fits_command?(window, each, steps[0], state) } }
          end
          return found unless found.empty?

          there = list ? list.map { |each| "##{each[:symbol]}" }.first(Patches::MOST_NAMED) : []
          near = op.paths.last.last.ids.empty? ? nil : Declarations.nearest("##{op.paths.last.last.ids.first[1]}", there)
          log_once([:nothing, entry.patch.seq, op.index], "#{entry.patch.mod}#{op.site ? " (#{op.site})" : ''}: #{op.kind} #{op.text.inspect} matches nothing inside " \
                                                          "#{describe(target)}#{near ? "; did you mean #{near}?" : ''}#{there.empty? ? '' : "; there: #{there.join(', ')}"}")
          found
        end
        private_class_method :matched

        # Runs a block on each command an operation names, or on the command the patch targets.
        #
        # @param commands [Array<Hash>, nil] The commands its selector named, nil for none given.
        # @param target [Window_Base, CommandPart] The patch's target.
        # @yieldparam entry [Hash] A command's entry.
        def self.each_command(commands, target)
          (commands || (target.is_a?(CommandPart) ? [target.entry] : [])).each { |found| yield found }
        end
        private_class_method :each_command

        # Sets params on a command: its text, whether it can be picked or shows, its icon and badge;
        # two mods setting the same param are logged once.
        #
        # @param found [Hash] The command's entry.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param state [Hash] What the patches did so far.
        def self.set_command(found, op, entry, state)
          params = op.values[0]
          params.each do |name, value|
            raise MarkupError, "set cannot change #{name}: of a command; #{FIXED[name]}" if FIXED.key?(name)

            Declarations[:command].check(name, value)
          end
          symbol = found[:symbol]
          params.each do |name, value|
            conflict(symbol, name, entry.patch.mod, state)
            case name
            when :text then found[:name] = live(value).to_s
            when :disabled then found[:enabled] = !live(value)
            when :visible then state[:hides] << symbol unless live(value)
            when :if then state[:hides] << symbol unless gate(value)
            else (state[:looks][symbol] ||= {})[name] = value
            end
          end
        end
        private_class_method :set_command

        # Keeps the params a patch sets on a window itself, after checking them as markup is.
        #
        # @param window [Window_Base] The window.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param state [Hash] What the patches did so far.
        def self.set_window(window, op, entry, state)
          params = op.values[0]
          params.each { |name, value| WINDOW.check(name, value) }
          params.each do |name, value|
            conflict(nil, name, entry.patch.mod, state)
            state[:sets][name] = value
          end
          if params[:movable]
            Adopt.adopt(window.class, :movable => true, :id => place_id(window)) unless @adopted && @adopted[window.class]
            (@adopted ||= {})[window.class] = true
          end
        end
        private_class_method :set_window

        # Tells the id the place of a window a patch lets the player move is kept under.
        #
        # @param window [Window_Base] The window.
        # @return [Symbol] The id, such as :game_Window_TitleCommand.
        def self.place_id(window)
          :"game_#{window.class.name}"
        end
        private_class_method :place_id

        # Logs, once, two mods that set the same param of a command or a window.
        #
        # @param symbol [Symbol, nil] The command's symbol, nil for the window.
        # @param name [Symbol] The param.
        # @param mod [String] The mod setting it now.
        # @param state [Hash] What the patches did so far.
        def self.conflict(symbol, name, mod, state)
          first = state[:set_by][[symbol, name]]
          state[:set_by][[symbol, name]] = mod
          return if first.nil? || first == mod

          what = symbol ? "#{COMMAND} ##{symbol}" : "the window"
          log_once([:conflict, symbol, name, first, mod], "#{first} and #{mod} both set #{name}: of #{what}; #{mod} loaded last, so its value is used")
        end
        private_class_method :conflict

        # Adds the commands of an operation's markup before, after or inside what it names.
        #
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>, nil] Its command list.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param target [Window_Base, CommandPart] The patch's target.
        # @param commands [Array<Hash>, nil] The commands its selector named.
        # @param state [Hash] What the patches did so far.
        def self.add(window, list, op, entry, target, commands, state)
          raise MarkupError, "#{describe(window)} has no commands, so #{op.kind} adds nothing; set its params or replace it with UI.replace_window" unless list

          inside = [:prepend, :append].include?(op.kind)
          if commands.nil? && target.equal?(window)
            raise MarkupError, "#{op.kind} cannot add commands beside #{describe(window)} itself; add them inside it with prepend or append" unless inside
          elsif inside
            raise MarkupError, "#{op.kind} adds commands inside the window; a command holds none, so add them after it"
          end

          made = Patches.build(op, entry, nil)
          made.each do |node|
            raise MarkupError, "#{op.kind} in #{describe(window)} takes command markup, not #{node.component? ? node.type.name : node.type}" unless node.type == :command
          end
          anchors = commands || (target.is_a?(CommandPart) ? [target.entry] : [])
          place = case op.kind
                  when :prepend then 0
                  when :append then list.size
                  when :before then anchors.empty? ? nil : list.index(anchors.first)
                  else anchors.empty? ? nil : list.index(anchors.last) + 1
                  end
          return if place.nil?

          made.each do |node|
            command = added_command(window, list, node, entry, state)
            next unless command

            list.insert(place, command)
            place += 1
          end
        end
        private_class_method :add

        # Makes the entry of a command a patch adds, nil while its if: or visible: keeps it off the
        # list or the list holds its symbol already, which is logged once.
        #
        # @param window [Window_Base] The window.
        # @param list [Array<Hash>] The command list.
        # @param node [Node] The command's markup.
        # @param entry [Patches::Entry] The patch run.
        # @param state [Hash] What the patches did so far.
        # @return [Hash, nil] The entry.
        def self.added_command(window, list, node, entry, state)
          params = node.params
          symbol = params[:id].to_sym
          if list.any? { |each| each[:symbol] == symbol }
            log_once([:taken, entry.patch.seq, symbol], "#{entry.patch.mod}#{node.site ? " (#{node.site})" : ''}: #{describe(window)} has a command ##{symbol} already, so the one added is left out")
            return nil
          end
          state[:added][symbol] = { :node => node, :mod => entry.patch.mod }
          look = {}
          look[:icon] = params[:icon] if params[:icon]
          look[:badge] = params[:badge] if params.key?(:badge)
          look[:badge_color] = params[:badge_color] if params[:badge_color]
          state[:looks][symbol] = look unless look.empty?
          return nil if (params.key?(:if) && !gate(params[:if])) || (params.key?(:visible) && !live(params[:visible]))

          disabled = params.key?(:disabled) && live(params[:disabled])
          { :name => live(params[:text]).to_s, :symbol => symbol, :enabled => !disabled, :ext => nil }
        end
        private_class_method :added_command

        # Keeps the handlers a patch wraps around a command's pick or the window's cancel.
        #
        # @param window [Window_Base] The window.
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param kind [Symbol] :window or :command.
        # @param commands [Array<Hash>, nil] The commands, nil for the window.
        # @param state [Hash] What the patches did so far.
        def self.wrap(window, op, entry, kind, commands, state)
          event = op.values[0]
          unless EVENTS[kind].include?(event)
            names = EVENTS[kind].map { |name| ":#{name}" }.join(', ')
            near = Declarations.nearest(event, EVENTS[kind])
            raise MarkupError, "#{kind == :window ? describe(window) : 'a game command'} has no event :#{event}#{near ? "; did you mean :#{near}?" : ''}; it has #{names}"
          end
          symbols = kind == :window ? [:cancel] : commands.map { |each| each[:symbol] }
          symbols.each { |symbol| (state[:wraps][symbol] ||= []) << [op, entry] }
        end
        private_class_method :wrap

        # Makes the handler a patch wraps around one of a window's handlers.
        #
        # @param op [Patches::Op] The operation.
        # @param entry [Patches::Entry] The patch run.
        # @param window [Window_Base] The window.
        # @param symbol [Symbol] The handler's symbol.
        # @param below [Proc] Runs the handler it wraps.
        # @return [Proc] The handler, which takes the event's values.
        def self.wrapper(op, entry, window, symbol, below)
          what = symbol == :cancel ? "#{name_of(window)}" : "#{COMMAND} ##{symbol} of #{name_of(window)}"
          lambda do |values|
            original = Patches::Original.new { |args| below.call(args) }
            answer = Patches.wrapper_answer(op, entry, what, original, values)
            window.activate if !original.called? && window.respond_to?(:activate) && !window.disposed?
            answer
          end
        end
        private_class_method :wrapper

        # Gives a window the handlers of the commands patches added that it lacks.
        #
        # @param window [Window_Base] The window.
        # @param state [Hash] What the patches did.
        def self.install_handlers(window, state)
          return unless window.respond_to?(:set_handler) && window.respond_to?(:handle?) && window.instance_variable_get(:@handler)

          state[:added].each_key do |symbol|
            window.set_handler(symbol, lambda { Mod_Framework::UI::Engine::GameWindows.pick(window, symbol) }) unless window.handle?(symbol)
          end
        end
        private_class_method :install_handlers

        # Runs the patches on a window anew: a command window makes its list again, any other runs
        # the patches on itself and draws its rows again where they take looks or took them.
        #
        # @param window [Window_Base] The window.
        def self.catch_up(window)
          if command_window?(window) && window.respond_to?(:refresh)
            window.refresh
          else
            looked = window.instance_variable_get(:@mf_row_looks)
            run_patches(window, nil)
            Rows.forget(window)
            redraw = !window.instance_variable_get(:@mf_patch_state)[:row_ops].empty? || (looked && !looked.empty?)
            window.refresh if redraw && window.respond_to?(:refresh)
          end
          follow_list(window)
        end
        private_class_method :catch_up

        # Follows a command list the patches changed on a window made before: its handlers, its
        # height and its cursor, and the params set on it.
        #
        # @param window [Window_Base] The window.
        def self.follow_list(window)
          state = window.instance_variable_get(:@mf_patch_state)
          return unless state

          install_handlers(window, state)
          Hidden.follow(window, :hide, state[:sets][:hidden])
          follow_height(window, state)
          list = window.instance_variable_get(:@list)
          window.select([list.size - 1, 0].max) if list.is_a?(Array) && window.respond_to?(:index) && window.index >= list.size
          keep_sets(window)
        end
        private_class_method :follow_list

        # Grows or shrinks a command window by the rows the patches added or took away, from the height
        # the game gave it for its own commands, so a window whose row count they left alone keeps the
        # game's height.
        #
        # @param window [Window_Base] The window.
        # @param state [Hash] What the patches did to its list just made.
        def self.follow_height(window, state)
          base = state.delete(:game_height)
          return if base.nil? || state[:sets][:height]

          height = base + state[:rows] * window.item_height
          window.height = height unless height == window.height
          window.instance_variable_set(:@mf_rows, state[:rows] == 0 ? nil : [state[:rows], height])
        end
        private_class_method :follow_height

        # Tells the height a command window has for the game's own commands, before the patches
        # change its list: the game's own height, less the rows the patches added last time while
        # the game kept the height they gave it.
        #
        # @param window [Window_Base] The window.
        # @return [Integer, nil] The height, nil for a window without rows.
        def self.game_height(window)
          return nil unless window.respond_to?(:item_height)
          return window.height if window.respond_to?(:window_height) && window.height == window.window_height

          kept = window.instance_variable_get(:@mf_rows)
          kept && kept[1] == window.height ? window.height - kept[0] * window.item_height : window.height
        end
        private_class_method :game_height

        # Notes the rows the patches added to a command window's list as it was made, which its height
        # holds when the game sized it to its commands.
        #
        # @param window [Window_Base] The window.
        def self.note_rows(window)
          state = window.instance_variable_get(:@mf_patch_state)
          rows = state && state[:rows]
          return if rows.nil? || rows == 0 || !window.respond_to?(:window_height) || window.height != window.window_height

          window.instance_variable_set(:@mf_rows, [rows, window.height])
        end
        private_class_method :note_rows

        # Puts a window where the params a patch set on it say, after the game or its scene moved it,
        # except where the player moved it.
        #
        # @param window [Window_Base] The window.
        def self.keep_sets(window)
          state = window.instance_variable_get(:@mf_patch_state)
          sets = state ? state[:sets] : nil
          return if sets.nil? || sets.empty?

          window.opacity = sets[:opacity] if sets[:opacity] && window.opacity != sets[:opacity]
          resize(window, sets[:width] || window.width, sets[:height] || window.height) if sets[:width] || sets[:height]
          player_placed = sets[:movable] && (Layout.moved?(place_id(window)) || Layout.arranging?)
          if sets[:at] && !player_placed
            window.x, window.y = sets[:at] unless [window.x, window.y] == sets[:at]
          elsif sets[:anchor] && !player_placed
            place = zone_place(window, sets[:anchor])
            window.x, window.y = place unless [window.x, window.y] == place
          end
          if sets.key?(:theme)
            theme = sets[:theme] == :game ? false : sets[:theme]
            window.ui_theme = theme unless window.respond_to?(:ui_theme) && window.ui_theme == theme
          end
        end
        private_class_method :keep_sets

        # Sizes a window and draws its contents anew.
        #
        # @param window [Window_Base] The window.
        # @param width [Integer] The width.
        # @param height [Integer] The height.
        def self.resize(window, width, height)
          return if width == window.width && height == window.height

          window.width = width
          window.height = height
          window.create_contents if window.respond_to?(:create_contents)
          window.refresh if window.respond_to?(:refresh)
        end
        private_class_method :resize

        # Tells where a window lies in a zone of the screen, flush with the screen's edges there.
        #
        # @param window [Window_Base] The window.
        # @param zone [Symbol] One of the nine zones.
        # @return [Array<Integer>] Its left and top.
        def self.zone_place(window, zone)
          at = Builtins::ZONES.index(zone)
          lefts = [0, (Graphics.width - window.width) / 2, Graphics.width - window.width]
          tops = [0, (Graphics.height - window.height) / 2, Graphics.height - window.height]
          [lefts[at % 3], tops[at / 3]]
        end
        private_class_method :zone_place

        # Reads a value that may be a lambda without arguments.
        #
        # @param value [Object] The value.
        # @return [Object] The value, the lambda's answer for a lambda.
        def self.live(value)
          value.is_a?(Proc) ? value.call : value
        end
        private_class_method :live

        # Asks a command's if: gate, a failing gate counting as false.
        #
        # @param gate [Proc, Symbol] The gate, or :map_free.
        # @return [Boolean] Whether the command shows.
        def self.gate(gate)
          answer = gate == Root::MAP_FREE ? UI::Game.map_free? : gate.call
          answer == true
        rescue => e
          Errors.report(e, "the if: of a game command")
          false
        end
        private_class_method :gate

        # Names a window by its class.
        #
        # @param window [Window_Base] The window.
        # @return [String] The name.
        def self.name_of(window)
          window.class.name.to_s
        end
        private_class_method :name_of

        # Writes a mod's name as the log does.
        #
        # @param name [String, nil] The name.
        # @return [String] The name with spaces, in lower case.
        def self.plain(name)
          name.to_s.tr("_", " ").downcase
        end
        private_class_method :plain

        # Keeps a game window hidden while a patch hides it or a component draws in its place, and
        # tells the game's own scripts whether the window would show, so they work as before.
        module Hidden
          @classes = {}

          # Hooks a class's visible and visible=, once, unless it inherits them from a class hooked
          # before.
          #
          # @param klass [Class] The class.
          def self.install(klass)
            return if @classes[klass]

            @classes[klass] = true
            owner = klass.instance_method(:visible).owner
            return if owner != klass && @classes[owner]

            Hooks.around(klass, :visible=, TAG) { |window, args, original| Mod_Framework::UI::Engine::GameWindows::Hidden.set(window, args[0], original) }
            Hooks.around(klass, :visible, TAG) { |window, _args, original| Mod_Framework::UI::Engine::GameWindows::Hidden.get(window, original) }
          end

          # Hides a window for a reason, or shows it again once no reason is left.
          #
          # @param window [Window_Base] The window.
          # @param reason [Symbol] :hide, :replaced or :covered.
          # @param on [Boolean, nil] Whether that reason holds.
          def self.follow(window, reason, on)
            reasons = window.instance_variable_get(:@mf_hidden) || []
            return if reasons.include?(reason) == (on ? true : false)

            if on
              window.instance_variable_set(:@mf_game_visible, window.visible) if reasons.empty?
              window.instance_variable_set(:@mf_hidden, reasons + [reason])
            else
              window.instance_variable_set(:@mf_hidden, reasons - [reason])
            end
            window.visible = window.instance_variable_get(:@mf_game_visible)
          end

          # Tells whether a window is kept hidden.
          #
          # @param window [Window_Base] The window.
          # @return [Boolean] Whether it is.
          def self.hidden?(window)
            reasons = window.instance_variable_get(:@mf_hidden)
            !reasons.nil? && !reasons.empty?
          end

          # Sets a window's visible: a hidden window keeps what the game set for later and stays
          # hidden.
          #
          # @param window [Window_Base] The window.
          # @param value [Boolean] What the game sets.
          # @param original [Proc] Sets it.
          # @return [Object] What setting it returns.
          def self.set(window, value, original)
            return original.call(value) unless hidden?(window)

            window.instance_variable_set(:@mf_game_visible, value)
            original.call(false)
          end

          # Tells a window's visible: for a hidden window what the game set.
          #
          # @param window [Window_Base] The window.
          # @param original [Proc] Reads it.
          # @return [Boolean] The value.
          def self.get(window, original)
            hidden?(window) ? window.instance_variable_get(:@mf_game_visible) : original.call
          end
        end

        # Draws a row of a game list window in its look while the game draws it on its own bitmap:
        # the name in its color and text, the texts, faces and icons greyed, and a line along its top.
        module Rows
          # The methods of the game's windows that draw a character's name, such as draw_actor_name
          # and Paradox's draw_actor_name_ex.
          NAMING = /\Adraw_actor_name/

          # How thick a line above a row is, in pixels.
          LINE = 2

          # A row as it draws in its look: the look, the row's index, the greyed palette of a grey
          # row, whether the row is a command's, and how many methods drawing a name it is inside.
          Drawing = Struct.new(:look, :index, :grey, :command, :naming)

          # Tells whether a row of a list window has a look.
          #
          # @param row [Hash] The row, as the block of rows answered it.
          # @return [Boolean] Whether it has.
          def self.look?(row)
            Builtins::GAME_ROW.keys.any? { |key| row[key] }
          end

          # Draws a row in its look, once: a row drawn inside another, such as by a hooked method a
          # subclass calls with super, draws as the outer one does.
          #
          # @param window [Window_Selectable] The window.
          # @param index [Integer] The row.
          # @yield Draws the row as the game does.
          # @return [Object] What the drawing returns.
          def self.drawing(window, index)
            return yield if window.instance_variable_get(:@mf_row_look)

            look = look_at(window, index)
            return yield unless look

            grey = look[:grey] ? Theme.greyed_for(window) : nil
            window.instance_variable_set(:@mf_row_look, Drawing.new(look, index, grey, GameWindows.command_window?(window), 0))
            begin
              drawn = yield
            ensure
              window.instance_variable_set(:@mf_row_look, nil)
            end
            line(window, index, look[:line_above]) if look[:line_above]
            drawn
          end

          # Lets go of a list window's looks, so they are worked out anew as it draws its rows.
          #
          # @param window [Window_Selectable] The window.
          def self.forget(window)
            window.instance_variable_set(:@mf_row_looks, nil)
          end

          # Draws all rows of a list window, their looks worked out anew once for them all.
          #
          # @param window [Window_Selectable] The window.
          # @param original [Proc] Draws the rows as the game does.
          # @return [Object] What the drawing returns.
          def self.drawing_all(window, original)
            forget(window)
            window.instance_variable_set(:@mf_drawing_rows, true)
            begin
              original.call
            ensure
              window.instance_variable_set(:@mf_drawing_rows, nil)
            end
          end

          # Sets the color of what a row draws: a name in its name color, and in a grey row every
          # color greyed and opaque.
          #
          # @param window [Window_Base] The window.
          # @param args [Array] The color and whether it is enabled.
          # @param original [Proc] Sets it as the game does.
          # @return [Object] What setting it returns.
          def self.change_color(window, args, original)
            row = window.instance_variable_get(:@mf_row_look)
            return original.call if row.nil? || args.empty?

            named = row.look[:name_color] && (row.command || row.naming > 0)
            return original.call unless named || row.grey

            color = named ? GameWindows.row_color(window, row.index, row.look[:name_color]) : args[0]
            row.grey ? original.call(row.grey.drawn_text(color), true) : original.call(color, *args[1..-1])
          end

          # Draws a text of a row: the name a row's look gives in place of the character's.
          #
          # @param window [Window_Base] The window.
          # @param args [Array] A rectangle, the text and its alignment, or x, y, width, height, the
          #   text and its alignment.
          # @param original [Proc] Draws it as the game does.
          # @return [Object] What drawing it returns.
          def self.draw_text(window, args, original)
            row = window.instance_variable_get(:@mf_row_look)
            return original.call unless row && !row.command && row.naming > 0 && row.look[:name]

            args = args.dup
            args[args[0].is_a?(Rect) ? 1 : 4] = row.look[:name].to_s
            original.call(*args)
          end

          # Draws an icon of a row, in a grey row from its greyed copy.
          #
          # @param window [Window_Base] The window.
          # @param args [Array] The icon, its left and top, and whether it is enabled.
          # @param original [Proc] Draws it as the game does.
          # @return [Object] What drawing it returns.
          def self.draw_icon(window, args, original)
            row = window.instance_variable_get(:@mf_row_look)
            return original.call unless row && row.grey

            source, part = row.grey.icon_source(args[0])
            window.contents.blt(args[1], args[2], source, part)
          end

          # Draws a face of a row, in a grey row from its greyed copy.
          #
          # @param window [Window_Base] The window.
          # @param args [Array] The face sheet's name, the face's index, its left and top, and
          #   whether it is enabled.
          # @param original [Proc] Draws it as the game does.
          # @return [Object] What drawing it returns.
          def self.draw_face(window, args, original)
            row = window.instance_variable_get(:@mf_row_look)
            return original.call unless row && row.grey

            name, face, x, y = args
            side = Picture::FACE_SIDE
            part = Rect.new(face % Picture::FACES_PER_ROW * side, face / Picture::FACES_PER_ROW * side, side, side)
            source, whole = row.grey.face_source(name, part)
            window.contents.blt(x, y, source, whole)
          end

          # Runs a method that draws a character's name, the texts it draws counting as the name.
          #
          # @param window [Window_Base] The window.
          # @param original [Proc] Runs it as the game does.
          # @return [Object] What it returns.
          def self.naming(window, original)
            row = window.instance_variable_get(:@mf_row_look)
            return original.call unless row

            row.naming += 1
            begin
              original.call
            ensure
              row.naming -= 1
            end
          end

          # Tells the look of a row: a command's from its entry, a list window's from the patches'
          # rows.
          #
          # @param window [Window_Selectable] The window.
          # @param index [Integer] The row.
          # @return [Hash, nil] The look, nil for a row without one.
          def self.look_at(window, index)
            unless GameWindows.command_window?(window)
              looks = GameWindows.row_looks(window)
              return looks.empty? ? nil : looks[index]
            end

            entry = window.instance_variable_get(:@list)[index]
            entry && GameWindows::COMMAND_LOOKS.any? { |key| entry[key] } ? entry : nil
          end
          private_class_method :look_at

          # Draws the line along the top of a row.
          #
          # @param window [Window_Selectable] The window.
          # @param index [Integer] The row.
          # @param color [Object] Its color, as a :color param takes it.
          def self.line(window, index, color)
            rect = window.item_rect(index)
            window.contents.fill_rect(rect.x, rect.y, rect.width, LINE, GameWindows.row_color(window, index, color))
          end
          private_class_method :line
        end
      end

      # UI.replace_window: a component of a mod draws in a game window's place. The game still makes,
      # opens and closes the window, which only draws nothing while the component shows.
      module ReplacedWindows
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # The serial a replaced window's refresh bumps, by the window.
        SERIAL = :windows

        # A replacement: the component, its gate and its params, and where a mod asked for it.
        Rule = Struct.new(:component, :gate, :params, :mod, :site)

        # What the component of a replaced window gets as game_window:, a handle that offers only its
        # documented methods.
        class Facade
          # Makes the handle of a game window.
          #
          # @param window [Window_Base] The window.
          def initialize(window)
            @window = window
          end

          # Tells whether the game's window would show now: visible, open and its contents not faded
          # out.
          #
          # @return [Boolean] Whether it would.
          def shown?
            !@window.disposed? && @window.visible && @window.openness > 0 &&
              (!@window.respond_to?(:contents_opacity) || @window.contents_opacity > 0) ? true : false
          end

          # Tells whether the game's window is open whole.
          #
          # @return [Boolean] Whether it is.
          def open?
            !@window.disposed? && @window.openness >= 255
          end

          # Tells how often the game's window drew its contents anew; a render that reads it renders
          # again after each of them.
          #
          # @return [Integer] The count.
          def refreshes
            id = @window.object_id
            ::Mod_Framework::UI::Engine::Serials.read(SERIAL, id)
            ::Mod_Framework::UI::Engine::Serials.serial(SERIAL, id)
          end

          # Lists what the handle offers.
          #
          # @return [String] The methods.
          def inspect
            "#<game window #{@window.class}: shown?, open?, refreshes>"
          end
          alias_method :to_s, :inspect

          # Tells whether the handle is of a class, as a component's params are checked by it.
          #
          # @param klass [Module] The class.
          # @return [Boolean] Whether it is.
          def is_a?(klass)
            Facade <= klass ? true : false
          end
          alias_method :kind_of?, :is_a?

          # Tells that the handle is no nil, as a component's params are checked by it.
          #
          # @return [Boolean] False.
          def nil?
            false
          end
        end

        @rules = {}
        @classes = {}
        @started = false

        # Replaces a game window class's drawing with a component, see UI.replace_window.
        #
        # @param klass [Class] The game window class.
        # @param component [Class] The component's class.
        # @param options [Hash] :if and :params.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] A value does not fit.
        def self.replace(klass, component, options, trace)
          unless klass.is_a?(Class) && defined?(::Window_Base) && klass <= ::Window_Base
            raise MarkupError, "UI.replace_window takes a game window class such as Window_MapName, not #{Declarations.show(klass)}"
          end
          check_options(component, options, "replace_window")
          mod = Errors.mod(trace)
          old = @rules[klass]
          log("#{mod} replaces #{klass}, which #{old.mod} replaced before; #{mod} loaded last, so its component draws") if old && old.mod != mod
          @rules[klass] = Rule.new(component, options[:if], options[:params], mod, Errors.site(trace))
          log("#{mod}#{@rules[klass].site ? " (#{@rules[klass].site})" : ''} draws #{klass} through #{component.name}")
          install(klass) if @started
          nil
        end

        # Checks the options of replace_window and replace_scene.
        #
        # @param component [Object] The component's class.
        # @param options [Object] The options.
        # @param call [String] The call, for the message.
        # @raise [MarkupError] A value does not fit.
        def self.check_options(component, options, call)
          raise MarkupError, "UI.#{call} takes a class of UI::Component, not #{Declarations.show(component)}" unless component.is_a?(Class) && component < UI::Component
          raise MarkupError, "UI.#{call} takes its options as a Hash, such as if: -> { ... }" unless options.is_a?(Hash)

          unknown = options.keys - [:if, :params]
          raise MarkupError, "UI.#{call} takes no #{unknown.first}:; it takes if: and params:" unless unknown.empty?
          raise MarkupError, "UI.#{call}: if: takes a lambda answering whether it holds" unless options[:if].nil? || options[:if].is_a?(Proc)
          raise MarkupError, "UI.#{call}: params: takes a lambda answering the component's params" unless options[:params].nil? || options[:params].is_a?(Proc)
        end

        # Hooks the replaced classes as the game runs.
        def self.start
          @started = true
          @rules.each_key { |klass| install(klass) }
        end

        # Hooks a replaced class, once: its windows are followed as they are made, after each update
        # and refresh, and as they are disposed.
        #
        # @param klass [Class] The class.
        def self.install(klass)
          return if @classes[klass]

          @classes[klass] = true
          Hooks.after(klass, :initialize, GameWindows::TAG) { |*_args| Mod_Framework::UI::Engine::ReplacedWindows.follow(self) }
          Hooks.after(klass, :update, GameWindows::TAG) { Mod_Framework::UI::Engine::ReplacedWindows.follow(self) } if klass.method_defined?(:update)
          Hooks.after(klass, :refresh, GameWindows::TAG) { Mod_Framework::UI::Engine::ReplacedWindows.refreshed(self) } if klass.method_defined?(:refresh)
          Hooks.after(klass, :dispose, GameWindows::TAG) { Mod_Framework::UI::Engine::ReplacedWindows.stop(self) } if klass.method_defined?(:dispose)
          GameWindows::Hidden.install(klass)
        end

        # Shows the component in a window's place while its gate holds, and the window again while
        # it does not.
        #
        # @param window [Window_Base] The window.
        def self.follow(window)
          return if window.disposed?

          rule = rule_for(window)
          shown = window.instance_variable_get(:@mf_replacement)
          wanted = rule && holds?(rule)
          if wanted && (shown.nil? || !open?(shown))
            start_component(window, rule)
          elsif !wanted && shown
            stop(window)
          end
        rescue => e
          log_once([:follow, window.class, e.class], "drawing a #{window.class} through a component FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Notes a refresh of a replaced window, so a render that read its refreshes renders again.
        #
        # @param window [Window_Base] The window.
        def self.refreshed(window)
          Serials.bump_id(SERIAL, window.object_id)
        end

        # Takes the component off a window and shows the window again.
        #
        # @param window [Window_Base] The window.
        def self.stop(window)
          shown = window.instance_variable_get(:@mf_replacement)
          return unless shown

          window.instance_variable_set(:@mf_replacement, nil)
          GameWindows::Hidden.follow(window, :replaced, false) unless window.disposed?
          return unless open?(shown)

          ShowHandle === shown ? shown.hide : shown.close
        end

        # Tells the replacement of a window: that of its class, or of the nearest class it is built
        # on.
        #
        # @param window [Window_Base] The window.
        # @return [Rule, nil] The replacement.
        def self.rule_for(window)
          window.class.ancestors.each { |klass| return @rules[klass] if @rules[klass] }
          nil
        end
        private_class_method :rule_for

        # Asks a replacement's gate; a failing gate counts as false, so the game's window draws.
        #
        # @param rule [Rule] The replacement.
        # @return [Boolean] Whether it holds.
        def self.holds?(rule)
          rule.gate.nil? || rule.gate.call == true
        rescue => e
          log_once([:gate, rule.mod, e.class], "the if: #{rule.mod} gave UI.replace_window FAILED, so the game's window draws: #{Logging.failure(e)}")
          false
        end
        private_class_method :holds?

        # Opens or shows the component of a replacement for a window and hides the window.
        #
        # @param window [Window_Base] The window.
        # @param rule [Rule] The replacement.
        def self.start_component(window, rule)
          params = rule.params ? UI.call_with(rule.params, window) : {}
          raise MarkupError, "the params: of UI.replace_window answer a Hash, not #{Declarations.show(params)}" unless params.is_a?(Hash)

          params = params.merge(:game_window => Facade.new(window)) if rule.component.params.key?(:game_window)
          shown = UI.__send__(:start_component, :any, rule.component, params, nil)
          return unless shown

          window.instance_variable_set(:@mf_replacement, shown)
          GameWindows::Hidden.follow(window, :replaced, true)
        end
        private_class_method :start_component

        # Tells whether a component's handle is still open or shown.
        #
        # @param shown [Object] The handle.
        # @return [Boolean] Whether it is.
        def self.open?(shown)
          ShowHandle === shown ? shown.shown? : shown.open?
        end
        private_class_method :open?
      end

      Run.on_start("ui game windows") do
        Mod_Framework::UI::Engine::GameWindows.start
        Mod_Framework::UI::Engine::ReplacedWindows.start
      end
    end

    # Draws a component in the place of a game window: the game still makes, opens and closes the
    # window, which draws nothing while the component shows, so game code that calls it keeps
    # working. The component's render describes a hud (UI.show) or a window (UI.open); while the
    # gate answers false, the game's window draws as before.
    #
    # @param window_class [Class] The game window class, such as Window_MapName.
    # @param component [Class] The component's class. It gets game_window: when it declares it: a
    #   handle that answers shown?, open? and refreshes.
    # @param options [Hash] :if (a lambda: the component draws while it answers true), :params (a
    #   lambda of the game window answering the component's params).
    # @return [nil] Always.
    # @raise [Engine::MarkupError] A value does not fit.
    def self.replace_window(window_class, component, options = {})
      Engine::ReplacedWindows.replace(window_class, component, options, caller)
    rescue Engine::MarkupError => e
      raise Engine::MarkupError, Engine::Errors.placed(e.message, caller)
    end

    # Opens a component in the place of a game scene: while the gate answers true, a call or a goto
    # of the scene opens the component in a stand-in menu scene over the game's blurred background,
    # and closing it returns where the scene would have returned. One replacement per scene; the
    # last one counts.
    #
    # @param scene_class [Class] The scene, such as Scene_Equip.
    # @param component [Class] The component's class; its render describes a window.
    # @param options [Hash] :if (a lambda, such as one that reads an Options > Mods row), :params (a
    #   lambda of the stand-in scene, whose actor is the character the menu picked, answering the
    #   component's params).
    # @return [nil] Always.
    # @raise [Engine::MarkupError] A value does not fit.
    def self.replace_scene(scene_class, component, options = {})
      Engine::ReplacedWindows.check_options(component, options, "replace_scene")
      raise Engine::MarkupError, "UI.replace_scene takes a scene class such as Scene_Equip, not #{Engine::Declarations.show(scene_class)}" unless scene_class.is_a?(Class)

      Engine::Scenes.replace(scene_class, :if => options[:if], :component => component, :params => options[:params])
      nil
    rescue Engine::MarkupError => e
      raise Engine::MarkupError, Engine::Errors.placed(e.message, caller)
    end
  end
end
