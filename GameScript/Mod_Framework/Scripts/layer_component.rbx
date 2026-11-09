#----------------------------------------------------------------
#  layer_component.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Added opener_size, the size of the window that opened the component's own
#                            - Added memo, which keeps what a render made while its keys stay the same
#      Paulinchen  2026-11-07: Declared the mount, params, state and block of a component as private readers
#      Paulinchen  2026-11-06: Removed OPAQUE, which only MGQ Online's chat read
#                            - Marked a component's own params, whose refusal of a lambda tells how to give live data
#      Paulinchen  2026-11-05: Let bubble with params alone be the markup of a bubble root
#                            - Let a component declare the calls of its handle, and take a text for a content param
#                            - Gave a component toast, bubble, back and forward
#                            - Handed out a handle of a part the component rendered, by its id, with the calls its part offers
#      Paulinchen  2026-11-04: Let a component class declare the hotkey that opens it
#                            - Told the mod that defined a component class
#                            - Logged two mods that define a component of the same name, and a component outside any module
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The markup names of mods' components, one module per module that defines components. A
      # component class includes the modules of the modules it lies in, so a component's markup
      # name works there and in the modules nested in it.
      module Scopes
        @all = {}

        # The mod that first defined each component, by the class's name.
        @mods = {}

        # Hands out the module of markup names of a module, made the first time.
        #
        # @param path [String] The module's name, "" for the top level.
        # @return [Module] The module of markup names.
        def self.[](path)
          @all[path] ||= Module.new
        end

        # Tells the snake case of a class's own name, such as member_card for MemberCard.
        #
        # @param name [String] The class's name, its modules left out.
        # @return [String] The snake case.
        def self.snake(name)
          name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        end

        # Gives a component class its markup name in the module it lies in, and the markup names of
        # the modules it lies in.
        #
        # @param klass [Class] The component class.
        # @raise [MarkupError] Its markup name would hide a built-in or a method every component has.
        def self.register(klass)
          parts = klass.name.split("::")
          own = parts.pop
          (0..parts.size).each { |size| klass.send(:include, self[parts[0, size].join("::")]) unless size == 0 }
          markup = snake(own)
          if Declarations.names.include?(markup.to_sym)
            raise MarkupError, "#{klass.name} would hide the built-in `#{markup}`. Rename the class, for example to #{parts.last.to_s.split('_').first}#{own}"
          end
          if UI::Component::OWN.include?(markup.to_sym)
            raise MarkupError, "#{klass.name} would hide the component's own `#{markup}`. Rename the class"
          end

          self[parts.join("::")].module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{markup}(*values, &block)
              ::Mod_Framework::UI::Engine::Builder.component(::#{klass.name}, values, block, markup_owner)
            end
          RUBY
          trace = caller
          claim(klass, trace)
          return unless parts.empty?

          Errors.hint([:top_level, klass.name], trace, "#{klass.name} lies outside any module, so its markup name #{markup} reaches every mod and another mod's #{klass.name} changes it; put it inside your mod's own module")
        end

        # Tells the mod that first defined a component class.
        #
        # @param klass [Class] The class.
        # @return [String, nil] The mod's name, nil for a class no mod defined.
        def self.mod_of(klass)
          @mods[klass.name.to_s]
        end

        # Logs a component class that a second mod defines too, once per mod.
        #
        # A second definition of a class of the same name reopens the first one, so the two mods
        # change each other's component.
        #
        # @param klass [Class] The component class.
        # @param trace [Array<String>] The backtrace of the definition.
        def self.claim(klass, trace)
          mod = Errors.mod(trace)
          first = (@mods[klass.name] ||= mod)
          return if first == mod

          Errors.hint([:shared_path, klass.name, mod], trace, "#{first} and #{mod} both define the component #{klass.name}, so each changes the other's; put each mod's components inside a module of its own")
        end
      end
    end

    # The base class of a component of the new UI layer. A subclass declares its params, state,
    # events and exposed values, and describes what it shows in render with markup; the framework
    # renders it again whenever what it showed may have changed.
    class Component
      include Markup
      include Engine::Scopes[""]

      # The methods every component has, which no markup name, param or state may hide.
      OWN = [:render, :setup, :mounted, :unmounted, :children, :children?, :emit, :close, :toast, :bubble, :back, :forward, :part, :memo, :component, :markup_owner]

      # What a declaration without a default holds.
      NONE = Object.new.freeze

      # The plain values a default may be, since one default object is shared by every instance.
      IMMUTABLE = [Numeric, Symbol, NilClass, TrueClass, FalseClass]

      # Gives a new component class its markup name, once it has its name.
      #
      # @param klass [Class] The new class.
      def self.inherited(klass)
        super
        klass.send(:markup_name!) if klass.name
      end

      # Gives the class its markup name once a method is defined, for a Ruby that names a class only
      # after inherited ran, and notes which mod defined the method.
      #
      # @param name [Symbol] The method.
      def self.method_added(name)
        super
        return unless name && self.name && !equal?(UI::Component)

        @markup_named ? Engine::Scopes.claim(self, caller) : markup_name!
      end

      class << self
        # Declares a param: a value the caller gives, which the component only reads.
        #
        # @param name [Symbol] Its name.
        # @param rest [Array] Its default, then a Hash with :content => true for markup the caller
        #   hands in, or :content => :text for markup or a text, which shows as one line.
        # @yield Makes a fresh default for each component.
        def param(name, *rest, &block)
          options = rest.last.is_a?(Hash) ? rest.pop : {}
          unknown = options.keys - [:content]
          raise Engine::MarkupError, "param takes no #{unknown.first}:; it takes content:" unless unknown.empty?

          default = rest.empty? ? NONE : frozen_text(rest.first)
          content = options[:content] == :text ? :text : (options[:content] ? true : false)
          default = nil if content && default.equal?(NONE)
          declare(name, :param, default, block)
          own_params[name] = { :default => default, :block => block, :content => content }
          define_method(name) { @__params[name] }
          define_method("#{name}=") do |_value|
            raise Engine::MarkupError, "#{name} is a param; keep your own copy in a state, for example state(:shown) { #{name} }"
          end
          forget_declaration
        end

        # Declares a state: the component's own value, written with self.name = value, which renders
        # the component again at the end of the frame.
        #
        # @param name [Symbol] Its name.
        # @param rest [Array] Its default.
        # @yield Makes a fresh default for each component; it may read the params.
        def state(name, *rest, &block)
          default = rest.empty? ? nil : frozen_text(rest.first)
          declare(name, :state, default, block)
          own_states[name] = { :default => default, :block => block }
          define_method(name) { @__state[name] }
          define_method("#{name}=") { |value| Engine::Layer.write_state(self, name, value) }
        end

        # Declares a call of the component's handle: part(:id).name(...) in the render's owner runs the
        # component's public method of that name, such as pulse.
        #
        # @param name [Symbol] The method.
        def action(name)
          own_actions[name] = {}
        end

        # Tells every call of the handle the class and its superclasses declare, by name.
        #
        # @return [Hash{Symbol => Hash}] The calls.
        def actions
          inherited_merge(:actions, own_actions)
        end

        # Declares an event: the on_name param the caller gives, which emit calls.
        #
        # @param name [Symbol] Its name, such as :pick for on_pick.
        def event(name)
          own_params[:"on_#{name}"] = { :default => nil, :handler => true }
          forget_declaration
        end

        # Declares the hotkey that opens the component with UI.open while it is not open; its window
        # or dialog closes by it again and names it in the key help, unless its hotkey: names
        # another. The hotkey must be defined with Mod_Framework::Hotkeys.define before the class.
        #
        # @param name [Symbol] The hotkey, such as :camp_bag_open.
        # @raise [Engine::MarkupError] It names no hotkey defined so far.
        def hotkey(name)
          unless name.is_a?(Symbol) && !Mod_Framework::Hotkeys.code(name).nil?
            near = name.is_a?(Symbol) ? Engine::Declarations.nearest(name, Mod_Framework::Hotkeys.names) : nil
            raise Engine::MarkupError, Engine::Errors.placed("hotkey :#{name} is no hotkey; define it with Mod_Framework::Hotkeys.define before the class#{near ? "; did you mean :#{near}?" : ''}", caller)
          end

          @declared_hotkey = name
          Mod_Framework::Hotkeys.attach(name, Engine::HotkeyOpener.new(self))
        end

        # Tells the hotkey that opens the component, its superclass's when it declares none.
        #
        # @return [Symbol, nil] The hotkey, nil for none.
        def declared_hotkey
          @declared_hotkey || (superclass.respond_to?(:declared_hotkey) ? superclass.declared_hotkey : nil)
        end

        # Declares a value another mod's UI.patch block may read.
        #
        # @param name [Symbol] Its name.
        # @yield Works out the value on each read; without a block the method of that name answers.
        def expose(name, &block)
          own_exposes[name] = block
        end

        # Declares a watch: data the framework cannot see, asked while the component shows; a new
        # answer renders it again.
        #
        # @param options [Hash] :every => frames between two asks (1).
        # @yield Answers the data's signature, such as a serial its owner gives.
        def watch(options = {}, &block)
          raise Engine::MarkupError, "watch needs a block that answers what to watch" unless block

          every = options[:every] || 1
          raise Engine::MarkupError, "watch takes every: as a whole number of frames, not #{every.inspect}" unless every.is_a?(Integer) && every > 0

          own_watches << [every, block]
        end

        # Tells every param of the class and its superclasses, by name.
        #
        # @return [Hash{Symbol => Hash}] Each param's default, block and kind.
        def params
          inherited_merge(:params, own_params)
        end

        # Tells every state of the class and its superclasses, by name.
        #
        # @return [Hash{Symbol => Hash}] Each state's default and block.
        def states
          inherited_merge(:states, own_states)
        end

        # Tells every exposed value of the class and its superclasses, by name.
        #
        # @return [Hash{Symbol => Proc, nil}] Each value's block, nil for the method of its name.
        def exposes
          inherited_merge(:exposes, own_exposes)
        end

        # Tells every watch of the class and its superclasses.
        #
        # @return [Array<Array>] Each watch's frames between asks and its block.
        def watches
          inherited = superclass.respond_to?(:watches) ? superclass.watches : nil
          return own_watches if inherited.nil? || inherited.empty?

          own_watches.empty? ? inherited : inherited + own_watches
        end

        # Tells the declaration markup calls of the class are checked against.
        #
        # @return [Engine::Declarations::Declaration] The declaration.
        def declaration
          @declaration ||= begin
            params = Engine::Declarations::COMMON.reject { |name, _param| name == :key }
            self.params.each do |name, param|
              params[name] = if param[:handler] then { :kind => :handler }
                             elsif param[:content] then { :kind => :content, :type => param[:content] == :text ? :text : nil }
                             else { :required => param[:default].equal?(NONE) && param[:block].nil?, :own => true }
                             end
            end
            Engine::Declarations::Declaration.new(markup_name.to_sym, :params => params, :common => false)
          end
        end

        # Checks the params a markup call gives the component.
        #
        # @param values [Array] The call's values: a Hash.
        # @return [Hash] The params, key: among them.
        # @raise [Engine::MarkupError] A param is unknown or missing.
        def take_params(values)
          params = values.last.is_a?(Hash) ? values.last.dup : {}
          raise Engine::MarkupError, "#{markup_name} takes its params as a Hash, such as #{markup_name} actor: a" if values.size > (values.last.is_a?(Hash) ? 1 : 0)

          key = params.delete(:key)
          checked = declaration.take([params])
          checked[:key] = key unless key.nil?
          checked
        end

        # Tells the class's markup name.
        #
        # @return [String] Such as "member_card".
        def markup_name
          Engine::Scopes.snake(name.to_s.split("::").last.to_s)
        end

        private

        # Gives the class its markup name in its module, once.
        def markup_name!
          return if @markup_named

          @markup_named = true
          Engine::Scopes.register(self)
        end

        # Refuses a name or a default a param or state may not have.
        #
        # @param name [Symbol] The name.
        # @param kind [Symbol] :param or :state.
        # @param default [Object] The default.
        # @param block [Proc, nil] The block that makes a default.
        # @raise [Engine::MarkupError] The name hides a method, or the default is shared and mutable.
        def declare(name, kind, default, block)
          raise Engine::MarkupError, "#{kind} takes a Symbol as its name, not #{name.inspect}" unless name.is_a?(Symbol)
          if OWN.include?(name) || Engine::Declarations.names.include?(name) || Object.method_defined?(name)
            raise Engine::MarkupError, "#{kind} :#{name} would hide the component's own #{name}; pick another name"
          end
          return if default.equal?(NONE) || block || IMMUTABLE.any? { |type| default.is_a?(type) } || (default.is_a?(String) && default.frozen?)

          raise Engine::MarkupError, "#{kind} :#{name} would share one #{default.class} among every component; use #{kind}(:#{name}) { #{default.inspect} }"
        end

        # Freezes a copy of a text default, so a text written as a default is safe to share.
        #
        # @param default [Object] The default.
        # @return [Object] A frozen copy of a text, else the default.
        def frozen_text(default)
          default.is_a?(String) && !default.frozen? ? default.dup.freeze : default
        end

        # Forgets the declaration made from the params, after a param changed.
        def forget_declaration
          @declaration = nil
        end

        # Merges a superclass's declarations with the class's own.
        #
        # @param reader [Symbol] The reader of the superclass's.
        # @param own [Hash] The class's own.
        # @return [Hash] All of them.
        def inherited_merge(reader, own)
          above = superclass.respond_to?(reader) ? superclass.send(reader) : {}
          above.merge(own)
        end

        # @return [Hash] The class's own params.
        def own_params
          @own_params ||= {}
        end

        # @return [Hash] The class's own states.
        def own_states
          @own_states ||= {}
        end

        # @return [Hash] The class's own exposed values.
        def own_exposes
          @own_exposes ||= {}
        end

        # @return [Array] The class's own watches.
        def own_watches
          @own_watches ||= []
        end

        # @return [Hash] The calls of the handle the class declares itself.
        def own_actions
          @own_actions ||= {}
        end
      end

      # Runs once, after the params and the state exist and before the first render.
      def setup
      end

      # Describes what the component shows, with markup.
      def render
      end

      # Runs once, after the first frame the component shows.
      def mounted
      end

      # Runs once, when the component leaves the screen; its watches and handlers stop then.
      def unmounted
      end

      # Places the caller's block, or a content param, where it is called; a text given for a
      # content param shows as one line of small text.
      #
      # @param name [Symbol, nil] The content param, nil for the block.
      # @return [nil] Always.
      def children(name = nil)
        content = name ? @__params[name] : @__block
        return text(content, Engine::Builder::CONTENT_TEXT) if content.is_a?(String)

        content.call if content
        nil
      end

      # Tells whether the caller gave the component a block.
      #
      # @return [Boolean] Whether it did.
      def children?
        !@__block.nil?
      end

      # Tells an event to the caller's on_ handler.
      #
      # @param name [Symbol] The event.
      # @param values [Array] What it tells.
      # @return [nil] Always.
      def emit(name, *values)
        Engine::Layer.emit(self, name, values)
      end

      # Closes the window or dialog the component lies in; UI.open's block gets the value.
      #
      # @param value [Object] The result.
      # @return [nil] Always.
      def close(value = nil)
        Engine::Layer.close(self, value, :script)
      end

      # Shows a toast in the notice stack every mod shares, as Mod_Framework.toast does.
      #
      # @param text [String] What it says.
      # @param params [Hash] The params of Mod_Framework.toast, such as seconds: and severity:.
      # @return [nil] Always.
      def toast(text, params = {})
        Mod_Framework.toast(text, params)
      end

      # Shows a speech bubble over a map character, as Mod_Framework.bubble does; called with params
      # alone, inside render, it is the markup of a bubble root.
      #
      # @param values [Array] The character or an event's id on this map, what it says and the
      #   params of Mod_Framework.bubble, such as seconds: and color:; or the bubble root's params.
      # @return [nil] Always, for a speech bubble.
      def bubble(*values, &block)
        return super if values.size < 2 || block

        Mod_Framework.bubble(*values)
      end

      # Slides the first slides the component's last render made a page back, as a button with
      # on_click: :back slides the slides it lies in.
      #
      # @return [nil] Always.
      def back
        Engine::Layer.slide_own(self, :back)
      end

      # Slides the first slides the component's last render made a page on, as a button with
      # on_click: :forward slides the slides it lies in.
      #
      # @return [nil] Always.
      def forward
        Engine::Layer.slide_own(self, :forward)
      end

      # Hands out a handle of a part the component's last render made, by its id, which offers the
      # calls its built-in has, such as enter_from of slides.
      #
      # @param id [Symbol, String] The part's id:.
      # @return [Engine::PartHandle] The handle.
      # @raise [Engine::MarkupError] The last render made no part of that id.
      def part(id)
        Engine::Layer.handle(self, id)
      end

      # Tells the size of the window or dialog whose handler or render opened the one the component
      # lies in, such as the window a dialog with cover: takes the place of.
      #
      # @return [Array<Integer>, nil] Its width and height, nil without one or before it has a place.
      def opener_size
        opener = Engine::Layer.opener_of(self)
        opener && opener.rect ? [opener.rect.width, opener.rect.height] : nil
      end

      # Tells what a block answers, worked out anew only once one of the keys differs from the render
      # before, so the lambdas it makes, such as tooltips, stay the same objects and the parts that
      # take them are not made anew on every render. Each call in render keeps its own answer, also
      # in a loop, by the place of its block and its keys; an answer no render asked for again is
      # let go.
      #
      # @param keys [Array] What the answer depends on, such as an item and its gems.
      # @yield Works the answer out.
      # @return [Object] What the block answered.
      def memo(*keys, &block)
        key = [block.source_location, keys]
        kept = (@__memos_kept ||= {})
        return kept[key] if kept.key?(key)

        last = @__memos || {}
        kept[key] = last.key?(key) ? last[key] : block.call
      end

      private

      # @return [Layer::Mount] The mount that renders it.
      attr_accessor :__mount

      # @return [Hash] Its params, those its caller left out at their defaults.
      attr_accessor :__params

      # @return [Hash] Its state.
      attr_accessor :__state

      # @return [Proc, nil] Its caller's block, nil for none.
      attr_accessor :__block

      # Keeps the answers of memo the render that just ended asked for, and lets go of the others.
      def __memos_rendered
        @__memos = @__memos_kept
        @__memos_kept = nil
      end

      # Tells who writes the component's markup: the component itself.
      #
      # @return [Component] Itself.
      def markup_owner
        self
      end
    end
  end
end
