#----------------------------------------------------------------
#  layer_markup.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Described the markup tooltips of a part's slots or lines, each in a slot of its own
#      Paulinchen  2026-11-07: Showed a UI error also as a toast once per cause while the row Show UI Errors is on
#                            - Added a part per item of a built-in that shows each of its items, such as a drop zone
#                            - Put a part or a component with compact_for: into a part of copies, the part itself and one hidden copy per entry
#                            - Kept a width or a height in pixels of a part with compact: on its forms' part alone
#                            - Put a part with compact: into a part of its forms, the part itself and one copy per compact form
#      Paulinchen  2026-11-06: Removed the notes of where every part was written, which only UI.dump read
#      Paulinchen  2026-11-05: Put an input with required: or validate: into a column too, where its error shows under it,
#                              and kept the label of a checkbox and a switch beside its mark
#      Paulinchen  2026-11-04: Put an input with label: into a column under its label
#                            - Put a text given for a content param that takes one into its slot as one line of text
#                            - Noted the serials a built-in that shows the game's data reads, for the component that renders it
#                            - Put the markup of a built-in's content param into a slot of its own
#                            - Refused a part outside the parts it goes inside, such as a slide outside slides
#                            - Placed a node described before, as the part a UI.patch keeps inside what replaces it
#                            - Gave a markup call of a mod's component the defaults its mod set
#                            - Noted where every part was written while UI.dump asks
#                            - Noted where a part was written only after a sibling of its type without key:
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # One part a render described: a built-in by its markup name or a component by its class,
      # its params, the parts it holds, and the component whose render wrote it.
      class Node
        # @return [Symbol, Class] The built-in's markup name, or the component's class.
        attr_reader :type

        # @return [Declarations::Declaration, nil] The built-in's declaration, nil for a component.
        attr_reader :declaration

        # @return [Hash] Its params, without key:.
        attr_reader :params

        # @return [Array<Node>] The parts it holds, in order.
        attr_reader :children

        # @return [Object] Whoever wrote it: the rendering component, or the self of a block.
        attr_reader :owner

        # @return [Proc, nil] A component's block, which it places with children.
        attr_reader :block

        # @return [Object] Who it is among its siblings of its type, nil for its place among them.
        attr_reader :key

        # @return [String, nil] Where a first render wrote it, kept to find loops without key:.
        attr_accessor :site

        # Makes a node.
        #
        # @param type [Symbol, Class] The markup name or the component class.
        # @param declaration [Declarations::Declaration, nil] The built-in's declaration.
        # @param params [Hash] Its params.
        # @param owner [Object] Whoever wrote it.
        # @param block [Proc, nil] A component's block.
        def initialize(type, declaration, params, owner, block = nil)
          @type = type
          @declaration = declaration
          @key = params.delete(:key)
          @params = params
          @children = []
          @owner = owner
          @block = block
        end

        # Notes that it holds a part of a type without key: or id:.
        #
        # @param type [Symbol, Class] The part's type.
        # @return [Boolean] Whether it held one of that type before.
        def keyless_again?(type)
          @keyless ||= {}
          again = @keyless.key?(type)
          @keyless[type] = true
          again
        end

        # Tells whether it stands for a component of a mod rather than a built-in.
        #
        # @return [Boolean] Whether it does.
        def component?
          @type.is_a?(Class)
        end
      end

      # The builder stack: the parts open while markup runs, one stack for every way markup is
      # reached. Each markup call checks its values, adds its node to the part on top and runs its
      # block with itself on top.
      module Builder
        # How a text given for a content param that takes one shows: one line of small text in the
        # system color.
        CONTENT_TEXT = { :typo => :body2, :color => :system }

        # Where the framework's own scripts lie, which the place of a markup call leaves out.
        OWN_FILES = %r{(\A|[/\\])Mod_Framework[/\\]}

        @stack = []

        # Whether the render running is its component's first, which notes where each part was
        # written.
        @first = false


        # The params every part takes that an input with label: hands to the column it lies in with
        # its label, so the label hides, grows and lines up with it.
        LABELLED_MOVES = [:visible, :grow, :align_self]

        # Adds a built-in's node to the part on top.
        #
        # @param name [Symbol] The built-in's markup name.
        # @param values [Array] The call's values.
        # @param block [Proc, nil] Its markup block.
        # @param owner [Object] Whoever wrote it.
        # @return [nil] Always, so markup reads as statements.
        # @raise [MarkupError] A value does not fit, or no render runs.
        def self.build(name, values, block, owner)
          declaration = Declarations[name]
          params = declaration.take(Looks.with_defaults(name, values, owner))
          raise MarkupError, "#{name} takes no block of markup" if block && !declaration.content?

          copies = params.delete(:compact_for)
          return build_part(name, params, block, owner) if copies.nil? || copies.empty?

          build_copies(params, copies, owner) { |made| build_part(name, made, block, owner) }
        rescue MarkupError => e
          raise MarkupError, Errors.placed(e.message, caller)
        end

        # Adds a built-in's node to the part on top, as a part of its forms with compact:.
        #
        # @param name [Symbol] The built-in's markup name.
        # @param params [Hash] Its params, checked.
        # @param block [Proc, nil] Its markup block.
        # @param owner [Object] Whoever wrote it.
        # @return [nil] Always.
        def self.build_part(name, params, block, owner)
          return build_forms(name, params, block, owner) if params[:compact]

          build_node(Node.new(name, Declarations[name], params, owner), block, owner)
        end
        private_class_method :build_part

        # Adds a part with compact_for: as a part of copies: the part itself and a hidden copy per
        # entry with that entry's params, which C#'s tree lays out in the part's place so its root
        # picks the step of the compact forms as for the tallest of them.
        #
        # @param params [Hash] The part's params, checked, without compact_for:.
        # @param copies [Array<Hash>] The params of each copy.
        # @param owner [Object] Whoever wrote it.
        # @yield [made] Adds the part or a copy to the part on top.
        # @yieldparam made [Hash] Its params.
        # @return [nil] Always.
        def self.build_copies(params, copies, owner, &make)
          holder = Node.new(:measures, Declarations[:measures], holder_params(params), owner)
          place(holder)
          fill(holder, lambda do
            ([{}] + copies).each_with_index do |copy, place|
              made = params.merge(copy).merge(:key => place)
              made.delete(:id) unless place == 0
              make.call(made)
              holder.children.last.params[:visible] = false unless place == 0
            end
          end)
          nil
        end
        private_class_method :build_copies

        # Takes the params of a part that the part holding it with its forms or copies takes, so it
        # sits in its stack as the part would: its key, else its id as the key, and FORM_MOVES.
        #
        # @param params [Hash] The part's params, which keep neither its key nor a width or a height
        #   in pixels.
        # @return [Hash] The holder's params.
        def self.holder_params(params)
          moved = { :key => params.key?(:key) ? params.delete(:key) : params[:id] }
          FORM_MOVES.each { |each| moved[each] = params[each] if params.key?(each) }
          [:width, :height].each { |side| params.delete(side) if params[side].is_a?(Integer) }
          moved
        end
        private_class_method :holder_params

        # The params of a part with compact: that its forms' part takes too, so it sits in its stack
        # as the part would; a width or a height in pixels stays on the forms' part alone, since a
        # form keeps it inside that part, where width: 0 with grow: would leave it no room.
        FORM_MOVES = [:grow, :align_self, :width, :height]

        # Adds a part with compact: as a part of its forms: the part itself and a copy per compact
        # form with that form's params, of which C#'s tree shows the one its root's step picks.
        #
        # @param name [Symbol] The built-in's markup name.
        # @param params [Hash] Its params, checked.
        # @param block [Proc, nil] Its markup block, which each form runs.
        # @param owner [Object] Whoever wrote it.
        # @return [nil] Always.
        def self.build_forms(name, params, block, owner)
          forms = params.delete(:compact).sort
          moved = holder_params(params).merge(:steps => [0] + forms.map { |step, _form| step })
          holder = Node.new(:forms, Declarations[:forms], moved, owner)
          place(holder)
          fill(holder, lambda do
            ([{}] + forms.map { |_step, form| form }).each_with_index do |form, place|
              copy = params.merge(form).merge(:key => place)
              copy.delete(:id) unless place == 0
              build_node(Node.new(name, Declarations[name], copy, owner), block, owner)
            end
          end)
          nil
        end
        private_class_method :build_forms

        # Adds a built-in's node to the part on top with what it holds: its markup block and the
        # markup of its content params, each in a slot of its own, and the markup tooltips of its
        # slots or lines, each in a slot keyed by its number.
        #
        # @param node [Node] The node.
        # @param block [Proc, nil] Its markup block.
        # @param owner [Object] Whoever wrote it.
        # @return [nil] Always.
        def self.build_node(node, block, owner)
          declaration = node.declaration
          place(labelled?(node) ? labelled(node) : node)
          read_serials(declaration, node.params)
          if declaration.spec[:each]
            fill(node, lambda { build_each(node, block, owner) })
          elsif block
            fill(node, block)
          end
          declaration.params.each_value do |param|
            content = node.params[param.name]
            next unless param.kind == :content && content

            slot = Node.new(:slot, Declarations[:slot], { :key => param.name, :name => param.name }, owner)
            node.children << slot
            next fill(slot, content) unless content.is_a?(String)

            slot.children << Node.new(:text, Declarations[:text], CONTENT_TEXT.merge(:text => content), owner)
          end
          tips = declaration.spec[:tips]
          (tips ? tips.call(node.params) : []).each_with_index do |markup, key|
            slot = Node.new(:slot, Declarations[:slot], { :key => [:tip, key], :name => :tip }, owner)
            node.children << slot
            fill(slot, markup)
          end
          nil
        end
        private_class_method :build_node

        # Tells whether an input goes into a column of its own: one with a label: drawn above it, or
        # one whose required: or validate: may show an error under it.
        #
        # @param input [Node] The input's node.
        # @return [Boolean] Whether it does.
        def self.labelled?(input)
          how = input.declaration.spec[:labelled]
          return false unless how

          label_above?(input) || (!input.params[:required].nil? && input.params[:required] != false) || !input.params[:validate].nil?
        end
        private_class_method :labelled?

        # Tells whether an input's label: goes above it, rather than beside its mark as a checkbox's.
        #
        # @param input [Node] The input's node.
        # @return [Boolean] Whether it does.
        def self.label_above?(input)
          input.declaration.spec[:labelled] != :beside && !input.params[:label].nil?
        end
        private_class_method :label_above?

        # Puts an input under its label in a column of their own, which takes the input's place
        # among its siblings and the params that place it, and shows the input's error under it.
        #
        # @param input [Node] The input's node.
        # @return [Node] The column's node.
        def self.labelled(input)
          moved = {}
          LABELLED_MOVES.each { |name| moved[name] = input.params.delete(name) if input.params.key?(name) }
          [:width, :height].each { |side| moved[side] = :fill if input.params[side] == :fill }
          key = input.key.nil? ? input.params[:id] : input.key
          moved[:key] = key unless key.nil?
          column = Node.new(:input_label, Declarations[:input_label], moved, input.owner)
          column.children << Node.new(:text, Declarations[:text], { :text => input.params[:label], :typo => :body2, :color => :system }, input.owner) if label_above?(input)
          column.children << input
          column
        end
        private_class_method :labelled

        # Notes the serials a built-in that shows the game's data reads, such as a character's stats,
        # so the component that renders it renders again once they change.
        #
        # @param declaration [Declarations::Declaration] The built-in's declaration.
        # @param params [Hash] Its params.
        def self.read_serials(declaration, params)
          reads = declaration.spec[:reads]
          return unless reads && defined?(Serials)

          reads.call(params).each { |name, actor| Serials.read(name, actor) }
        end
        private_class_method :read_serials

        # Adds a part per item of a built-in that shows each of its items in a part of its own, such
        # as a drop zone: the built-in's block shows the item it takes, else the item's name shows.
        #
        # @param node [Node] The built-in's node.
        # @param block [Proc, nil] Its block, which takes an item.
        # @param owner [Object] Whoever wrote it.
        def self.build_each(node, block, owner)
          param, type = node.declaration.spec[:each]
          Array(node.params[param]).each_with_index do |item, index|
            child = Node.new(type, Declarations[type], { :key => index, :item => item }, owner)
            place(child)
            fill(child, lambda { block ? block.call(item) : build(:text, [item.respond_to?(:name) ? item.name.to_s : item.to_s], nil, owner) })
          end
        end
        private_class_method :build_each

        # Runs markup with a node on top, so the parts it describes go into that node.
        #
        # @param node [Node] The node.
        # @param markup [Proc] The markup.
        def self.fill(node, markup)
          @stack.push(node)
          begin
            markup.call
          ensure
            @stack.pop
          end
        end
        private_class_method :fill

        # Adds a component's node to the part on top; the component renders it later.
        #
        # @param klass [Class] The component's class.
        # @param values [Array] The call's values: its params as a Hash.
        # @param block [Proc, nil] Its block, which it places with children.
        # @param owner [Object] Whoever wrote it.
        # @return [nil] Always.
        # @raise [MarkupError] It is no component, or its params do not fit.
        def self.component(klass, values, block, owner)
          unless klass.is_a?(Class) && klass < UI::Component
            raise MarkupError, "component takes a class of UI::Component, not #{Declarations.show(klass)}"
          end

          params = klass.take_params(values)
          copies = params.delete(:compact_for)
          if copies.nil? || copies.empty?
            place(Node.new(klass, nil, params, owner, block))
          else
            build_copies(params, copies, owner) { |made| place(Node.new(klass, nil, made, owner, block)) }
          end
          nil
        rescue MarkupError => e
          raise MarkupError, Errors.placed(e.message, caller)
        end

        # Runs a block of markup with an empty part on top and hands out what it described.
        #
        # @param first [Boolean] Whether it is a component's first render.
        # @yield The markup.
        # @return [Array<Node>] The parts it described at its top.
        def self.capture(first = false)
          holder = Node.new(:fragment, nil, {}, nil)
          was = @first
          @first = first
          @stack.push(holder)
          begin
            yield
          ensure
            @stack.pop
            @first = was
          end
          holder.children
        end

        # Places a node a render described before where markup runs now, such as the part a
        # UI.patch keeps inside what replaces it.
        #
        # @param node [Node] The node.
        # @return [nil] Always.
        # @raise [MarkupError] No markup runs.
        def self.place_node(node)
          parent = @stack.last
          raise MarkupError, "original.place works only inside the block of replace or a render" unless parent

          parent.children << node
          nil
        end

        # Tells whether markup may run now: a render or a block of markup is under way.
        #
        # @return [Boolean] Whether it may.
        def self.open?
          !@stack.empty?
        end

        # Adds a node to the part on top.
        #
        # @param node [Node] The node.
        # @raise [MarkupError] No render runs.
        def self.place(node)
          parent = @stack.last
          unless parent
            raise MarkupError, "#{node.component? ? node.type.name : node.type} is markup, which works only inside render or a block of markup"
          end
          if node.declaration && node.declaration.root && parent.type != :fragment
            raise MarkupError, "#{node.type} is a root, so it goes at the top of a render, not inside #{parent.component? ? parent.type.markup_name : parent.type}"
          end
          inside = node.declaration && node.declaration.spec[:inside]
          if inside && !inside.include?(parent.type) && parent.type != :fragment
            raise MarkupError, "#{node.type} goes inside #{inside.join(' or ')}, not inside #{parent.component? ? parent.type.markup_name : parent.type}"
          end

          node.site = Errors.site(caller) if @first && keyless?(node) && parent.keyless_again?(node.type)
          parent.children << node
        end
        private_class_method :place

        # Tells whether a node has neither key: nor id:, so only its place tells it from its
        # siblings.
        #
        # @param node [Node] The node.
        # @return [Boolean] Whether it has neither.
        def self.keyless?(node)
          node.key.nil? && node.params[:id].nil?
        end
        private_class_method :keyless?
      end

      # Where an error of a mod's code lies, and the lines that tell it in the framework's log; while
      # the player's row Show UI Errors is on, an error also shows a toast that names the mod.
      module Errors
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # The setting that keeps whether a UI error shows a toast, 1 or 0.
        SETTING = "ui_show_errors"

        # The Options > Mods row's key.
        OPTION = :mf_ui_show_errors

        # The Options > Mods row's name.
        OPTION_NAME = "Show UI Errors"

        # The Options > Mods row's help.
        OPTION_HELP = "On: a mistake in a mod's windows also shows a message that names the mod.
"                       "Off: it goes to the log only."

        # The Options > Mods row's values.
        ON = "On"
        OFF = "Off"

        # Whether a UI error shows a toast; nil until read from the settings.
        @shown = nil

        # Tells whether a UI error shows a toast.
        #
        # @return [Boolean] Whether it does; off until the player turns it on.
        def self.shown?
          @shown = Settings.setting(SETTING).to_s == "1" if @shown.nil?
          @shown
        end

        # Turns the toasts of UI errors on or off and keeps it in the settings.
        #
        # @param on [Boolean] Whether a UI error shows a toast.
        def self.show_errors(on)
          @shown = on
          kept = Settings.store(SETTING, on ? 1 : 0)
          log("UI errors show #{on ? 'a toast and go to the log' : 'in the log only'}#{kept ? '' : ', not kept'}")
        end

        # Offers Show UI Errors as a row of Options > Mods.
        def self.add_option
          added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, lambda { [OFF, ON] },
                               lambda { shown? ? ON : OFF }, lambda { |value| show_errors(value == ON) })
          log("no Show UI Errors row in Options > Mods, see the options lines") unless added
        end

        # Tells the file and line of the first frame of a backtrace that lies in a mod's code.
        #
        # @param trace [Array<String>] The backtrace.
        # @return [String, nil] Such as "Camp_Notes.rb:20", nil when every frame is the framework's.
        def self.site(trace)
          frame = Array(trace).find { |line| line !~ Builder::OWN_FILES }
          return nil unless frame && frame =~ /\A(.+?):(\d+)/

          "#{File.basename($1)}:#{$2}"
        end

        # Tells the mod a backtrace's first frame outside the framework belongs to.
        #
        # @param trace [Array<String>] The backtrace.
        # @return [String] Its name, as the mod's script or folder names it with spaces.
        def self.mod(trace)
          frame = Array(trace).find { |line| line !~ Builder::OWN_FILES }.to_s
          path = frame[/\A(.+?):\d+/, 1].to_s.tr("\\", "/")
          name = path =~ %r{(?:\A|/)Patch/([^/]+?)(?:\.rb)?(?:/|\z)} ? $1 : File.basename(path, ".*")
          name.tr("_", " ")
        end

        # Adds the place of the mod's code to a message.
        #
        # @param message [String] The message.
        # @param trace [Array<String>] The backtrace of the call.
        # @return [String] The message, ended with the place in brackets when there is one.
        def self.placed(message, trace)
          return message if message =~ /\(\S+:\d+\)\z/

          place = site(trace)
          place ? "#{message} (#{place})" : message
        end

        # Logs an error of a mod's UI code once per cause, naming the mod, the file and the line, and
        # shows a toast that names the mod while Show UI Errors is on.
        #
        # @param error [Exception] The error.
        # @param what [String] What failed, such as "Camp_Notes::NotesWindow's render".
        # @param hint [String, nil] What to do instead.
        def self.report(error, what, hint = nil)
          trace = Array(error.backtrace)
          place = site(trace)
          message = error.message.to_s.sub(/ \(\S+:\d+\)\z/, "")
          name = mod(trace)
          return unless Mod_Framework::Logging.first_time?(self, [place, error.class, message])

          log("#{name}#{place ? " (#{place})" : ''}: #{what} failed: #{message}#{hint ? "; #{hint}" : ''}")
          Mod_Framework.toast("UI error in #{name}. See the log.", :severity => :error) if shown?
        end

        Run.on_start("UI errors", :dll => true) { Mod_Framework::UI::Engine::Errors.add_option }

        # Logs a hint about a mod's UI code once per place.
        #
        # @param key [Object] What tells the hint from others.
        # @param trace [Array<String>, String] The backtrace, or the place.
        # @param text [String] The hint.
        def self.hint(key, trace, text)
          place = trace.is_a?(String) ? trace : site(trace)
          log_once([:hint, key, place], "#{place ? "#{place}: " : ''}#{text}")
        end
      end
    end

    # The markup a component's render writes: one method per built-in, made from its declaration,
    # and component for a component of another module. UI::Component includes it.
    module Markup
      # Makes the markup method of a built-in.
      #
      # @param name [Symbol] The built-in's markup name.
      def self.define(name)
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}(*values, &block)
            ::Mod_Framework::UI::Engine::Builder.build(:#{name}, values, block, markup_owner)
          end
        RUBY
      end

      # Describes a component of a class, such as one of another mod that its markup name does
      # not reach.
      #
      # @param klass [Class] The component's class.
      # @param values [Array] Its params as a Hash.
      # @yield Markup the component places with children.
      # @return [nil] Always.
      def component(klass, *values, &block)
        ::Mod_Framework::UI::Engine::Builder.component(klass, values, block, markup_owner)
      end

      Engine::Declarations.names.each { |name| define(name) }
    end

    module Engine
      # The self of a block of markup that runs outside a component, such as a UI.patch block:
      # markup names reach the markup, and everything else reaches the block's own self.
      #
      # An @variable inside such a block belongs to this proxy, not to the mod.
      class MarkupProxy < BasicObject
        include ::Mod_Framework::UI::Markup

        # Makes a proxy for a block.
        #
        # @param target [Object] The block's own self, which every other call reaches.
        def initialize(target)
          @target = target
        end

        # Runs a block of markup with the proxy as its self.
        #
        # @param block [Proc] The block.
        # @param values [Array] What the block takes.
        # @return [Object] What the block answers.
        def self.run(block, *values)
          new(block.binding.eval("self")).instance_exec(*values, &block)
        end

        # Hands a call that is no markup to the block's own self.
        #
        # @param name [Symbol] The method.
        # @param values [Array] Its values.
        # @return [Object] What the block's self answers.
        def method_missing(name, *values, &block)
          @target.__send__(name, *values, &block)
        end

        # Tells whether the block's own self answers a method.
        #
        # @param name [Symbol] The method.
        # @param all [Boolean] Whether private methods count.
        # @return [Boolean] Whether it does.
        def respond_to_missing?(name, all = false)
          @target.respond_to?(name, all)
        end

        private

        # Tells who wrote the markup: the block's own self.
        #
        # @return [Object] The block's self.
        def markup_owner
          @target
        end
      end
    end
  end
end
