#----------------------------------------------------------------
#  layer_patch.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Let read take a value a game window keeps and answers
#      Paulinchen  2026-11-07: Let rows change the rows of an options list as it makes them
#                            - Kept the state of patches on an old component in its declared attributes
#      Paulinchen  2026-11-06: Kept only the mod of a param a patch set, now that UI.dump is gone
#                            - Removed the log of ids two mods write, which only the old UI scan fed
#      Paulinchen  2026-11-05: Checked the new targets of the patches only while some wait
#      Paulinchen  2026-11-04: Let later patches change the parts a patch added, which a selector names by their id or by
#                              the key they got
#                            - Logged once a patch whose selector names an id two mods write
#                            - Refused t.read on a game window, which exposes nothing
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      class Node
        # @return [Layer::Mount, nil] The component a component's node made, nil before and for a
        #   built-in.
        attr_accessor :mount

        # @return [Array<Patches::Entry>, nil] The patches that named it in its render, each run on it.
        attr_accessor :patch_entries

        # @return [Array<Array>, nil] The prepends and appends a patch asked for inside a component,
        #   which its render takes.
        attr_accessor :patch_inside

        # @return [Hash, nil] Each param a patch set, with the mod whose patch set it.
        attr_accessor :patch_set

        # @return [Boolean] Whether the patches applied to it in this render.
        attr_accessor :patch_done

        # @return [Integer, nil] The place in the patch order of the patch that added it, nil for a
        #   part its owner wrote; only patches after that place apply to it.
        attr_accessor :patch_floor

        # @return [String, nil] The key a patch gave it, which names it like an id while it has none.
        attr_accessor :patch_key

        # A patch gives a part it adds a key of its mod.
        attr_writer :key
      end

      # UI.patch: the patches mods register on other UI by selector, and how they apply. A patch
      # names its target parts; its block runs each time a target renders, and the operations it
      # asks for change the target's description before the layer matches it with the parts on the
      # screen. On the old engine's screens a patch applies as a target goes onto the screen.
      module Patches
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # The operations a patch block asks for.
        OPERATIONS = [:set, :before, :after, :prepend, :append, :hide, :replace, :on, :rows, :read]

        # The order operations on one part apply in, so hide beats set.
        APPLY_ORDER = [:set, :on, :rows, :prepend, :append, :hide]

        # How many frames apart the live values of the parts a patch added to an old screen are read.
        GRAFT_LIVE_EVERY = 4

        # The most ids and types the log names for a selector that matches nothing.
        MOST_NAMED = 8

        # The framework's own name as an owner of ids, which is always loaded.
        FRAMEWORK = "Mod Framework"

        # One UI.patch call: its selector, its block, its mod and where it was written.
        class Patch
          # @return [String] The selector as written.
          attr_reader :text

          # @return [Array<Array<Selector::Step>>] The selector, read.
          attr_reader :paths

          # @return [Proc] The block, which gets the handle.
          attr_reader :block

          # @return [Object] The block's own self, which owns the parts it adds.
          attr_reader :owner

          # @return [String] The mod that registered it.
          attr_reader :mod

          # @return [String, nil] Where, such as "Gear_Compare.rb:12".
          attr_reader :site

          # @return [Integer] Its place among every patch registered.
          attr_reader :seq

          # @return [Integer] Its place among the patches of its mod, 1 for the first.
          attr_accessor :number

          # Makes a patch.
          #
          # @param text [String] The selector.
          # @param paths [Array<Array<Selector::Step>>] The selector, read.
          # @param block [Proc] The block.
          # @param mod [String] The mod.
          # @param site [String, nil] Where it was written.
          # @param seq [Integer] Its place.
          def initialize(text, paths, block, mod, site, seq)
            @text = text
            @paths = paths
            @block = block
            @owner = block.binding.eval("self")
            @mod = mod
            @site = site
            @seq = seq
          end
        end

        # One operation a patch block asked for.
        class Op
          # @return [Symbol] The operation, one of OPERATIONS.
          attr_reader :kind

          # @return [String, nil] The selector as written, nil for the target itself.
          attr_reader :text

          # @return [Array<Array<Selector::Step>>, nil] The selector, read.
          attr_reader :paths

          # @return [Array] What it was given besides the selector and the block.
          attr_reader :values

          # @return [Proc, nil] Its block.
          attr_reader :block

          # @return [String, nil] Where it was written.
          attr_reader :site

          # @return [Integer] Its place in the patch block.
          attr_reader :index

          # Makes an operation.
          #
          # @param kind [Symbol] The operation.
          # @param text [String, nil] The selector.
          # @param values [Array] What it was given.
          # @param block [Proc, nil] Its block.
          # @param site [String, nil] Where it was written.
          # @param index [Integer] Its place.
          def initialize(kind, text, values, block, site, index)
            @kind = kind
            @text = text
            @paths = text.nil? ? nil : Selector.parse(text)
            @values = values
            @block = block
            @site = site
            @index = index
          end
        end

        # A patch run on one target: the operations its block asked for there.
        class Entry
          # @return [Patch] The patch.
          attr_reader :patch

          # @return [Array<Op>] The operations.
          attr_reader :ops

          # @return [Node, Component] The target.
          attr_reader :target

          # @return [String] The root it lies in, which a failing patch is switched off for.
          attr_reader :root

          # Makes an entry.
          #
          # @param patch [Patch] The patch.
          # @param ops [Array<Op>] The operations.
          # @param target [Node, Component] The target.
          # @param root [String] The root.
          def initialize(patch, ops, target, root)
            @patch = patch
            @ops = ops
            @target = target
            @root = root
          end
        end

        # What a patch block gets: it notes the operations the block asks for, which apply once the
        # block ends.
        class Handle
          # Makes the handle of a patch on a target.
          #
          # @param patch [Patch] The patch.
          # @param target [Node, Component] The target.
          def initialize(patch, target)
            @patch = patch
            @target = target
            @ops = []
          end

          # @return [Array<Op>] The operations asked for.
          attr_reader :ops

          # Sets params on the parts a selector names, or on the target; they beat the owner's.
          #
          # @param values [Array] An optional selector, then the params as a Hash.
          # @return [nil] Always.
          def set(*values)
            params = values.pop
            unless params.is_a?(Hash) && values.size <= 1
              raise MarkupError, "set takes an optional selector and the params as a Hash, such as t.set \"#ok\", color: :primary"
            end

            add(:set, values.first, [params], nil)
          end

          # Adds markup before the parts a selector names, or before the target.
          #
          # @param selector [String, nil] The selector.
          # @yield The markup.
          # @return [nil] Always.
          def before(selector = nil, &block)
            add(:before, selector, [], needed(:before, block))
          end

          # Adds markup after the parts a selector names, or after the target.
          #
          # @param selector [String, nil] The selector.
          # @yield The markup.
          # @return [nil] Always.
          def after(selector = nil, &block)
            add(:after, selector, [], needed(:after, block))
          end

          # Adds markup inside the parts a selector names, or inside the target, before what they
          # hold.
          #
          # @param selector [String, nil] The selector.
          # @yield The markup.
          # @return [nil] Always.
          def prepend(selector = nil, &block)
            add(:prepend, selector, [], needed(:prepend, block))
          end

          # Adds markup inside the parts a selector names, or inside the target, after what they
          # hold.
          #
          # @param selector [String, nil] The selector.
          # @yield The markup.
          # @return [nil] Always.
          def append(selector = nil, &block)
            add(:append, selector, [], needed(:append, block))
          end

          # Hides the parts a selector names, or the target.
          #
          # @param selector [String, nil] The selector.
          # @return [nil] Always.
          def hide(selector = nil)
            add(:hide, selector, [], nil)
          end

          # Puts a component or markup in the place of the parts a selector names, within this root.
          #
          # @param selector [String, nil] The selector, nil for the target.
          # @param component [Class, nil] A class of UI::Component, which gets the part's params it
          #   declares and original: (place it with children :original).
          # @yieldparam original [Object] The part, which original.place places.
          # @return [nil] Always.
          def replace(selector = nil, component = nil, &block)
            selector, component = nil, selector if selector.is_a?(Class)
            unless component.nil? ^ block.nil?
              raise MarkupError, "replace takes a component class or a block of markup, such as t.replace \"#stats\", BigStats"
            end

            add(:replace, selector, [component], block)
          end

          # Wraps a handler of the parts a selector names, or of the target: the block runs instead
          # and original.call(*values) runs the owner's; a block that does not call it refuses the
          # event.
          #
          # @param selector [String, Symbol, nil] The selector, or the event for the target.
          # @param event [Symbol, nil] The event, such as :click.
          # @yieldparam original [Object] The owner's handler.
          # @yieldparam values [Array] What the event tells.
          # @return [nil] Always.
          def on(selector, event = nil, &block)
            selector, event = nil, selector if event.nil?
            raise MarkupError, "on takes the event as a Symbol, such as t.on \"#ok\", :click do |original| ... end" unless event.is_a?(Symbol)

            add(:on, selector, [event], needed(:on, block))
          end

          # Patches the rows of the lists a selector names, or of the target, after the owner made
          # them.
          #
          # @param selector [String, nil] The selector.
          # @yieldparam rows [Array] The rows.
          # @yieldreturn [Array] The rows to show.
          # @return [nil] Always.
          def rows(selector = nil, &block)
            add(:rows, selector, [], needed(:rows, block))
          end

          # Reads a value the owner exposed.
          #
          # @param name [Symbol] The value.
          # @return [Object] The value.
          # @raise [MarkupError] The owner exposes no value of that name.
          def read(name)
            Patches.read(@target, name)
          end

          # Refuses an operation that does not exist, with the nearest one.
          #
          # @param name [Symbol] The method.
          # @raise [MarkupError] Always.
          def method_missing(name, *values)
            return super if name.to_s.start_with?("to_")

            near = Declarations.nearest(name, OPERATIONS)
            raise MarkupError, "UI.patch takes no #{name}#{near ? "; did you mean #{near}?" : ''}; it takes #{OPERATIONS.join(', ')}"
          end

          # Tells that only the operations exist.
          #
          # @return [Boolean] False.
          def respond_to_missing?(_name, _all = false)
            false
          end

          # Lists what the handle offers.
          #
          # @return [String] The operations.
          def inspect
            "#<UI.patch #{@patch.text}: #{OPERATIONS.join(', ')}>"
          end

          private

          # Notes an operation.
          #
          # @param kind [Symbol] The operation.
          # @param selector [String, nil] Its selector.
          # @param values [Array] What it was given.
          # @param block [Proc, nil] Its block.
          # @return [nil] Always.
          def add(kind, selector, values, block)
            raise MarkupError, "#{kind} takes a selector as a text, such as \"#clear\", not #{Declarations.show(selector)}" unless selector.nil? || selector.is_a?(String)

            @ops << Op.new(kind, selector, values, block, Errors.site(caller), @ops.size)
            nil
          end

          # Checks that an operation that needs a block got one.
          #
          # @param kind [Symbol] The operation.
          # @param block [Proc, nil] The block.
          # @return [Proc] The block.
          def needed(kind, block)
            raise MarkupError, "#{kind} needs a block" unless block

            block
          end
        end

        # What a wrapped handler gets as original: the owner's handler, run by call.
        class Original
          # Makes it.
          #
          # @yield Runs the owner's handler with values.
          def initialize(&run)
            @run = run
            @called = false
          end

          # Runs the owner's handler.
          #
          # @param values [Array] What the event tells, the event's own by default.
          # @return [Object] What the handler answered.
          def call(*values)
            @called = true
            @run.call(values)
          end

          # Tells whether the block ran the owner's handler.
          #
          # @return [Boolean] Whether it did.
          def called?
            @called
          end

          # Hands out call as a Proc.
          #
          # @return [Proc] The Proc.
          def to_proc
            method(:call).to_proc
          end
        end

        # What the block of replace gets: the part it replaces, which place puts where the block is.
        class Kept
          # Makes it.
          #
          # @param node [Node] The part's node.
          def initialize(node)
            @node = node
          end

          # Places the original part here.
          #
          # @return [nil] Always.
          def place
            Builder.place_node(@node)
          end
        end

        # The parts a patch adds to a screen of the old engine: a part of the layer whose engine
        # parts lie in the old component it names, before, after or in the place of it.
        class Graft < Layer::Part
          # @return [Component] The old component the engine parts go into.
          attr_reader :target

          # @return [Component] The old component the patch named.
          attr_reader :anchor

          # Makes a graft.
          #
          # @param target [Component] Where the parts go.
          # @param mode [Symbol] :before, :after, :prepend, :append or :replace.
          # @param anchor [Component] The component the patch named.
          # @param hint [Integer, nil] The anchor's place in target before it was replaced.
          def initialize(target, mode, anchor, hint)
            @target = target
            @mode = mode
            @anchor = anchor
            @hint = hint
            @engines = []
            self.node = Node.new(:fragment, nil, {}, nil)
            self.engine = target
            self.options = {}
            self.children = []
            self.depth = 0
            self.top = GraftTop.new(anchor)
          end

          # Puts the engine parts of what it holds into its target, where they lay or at their
          # place by the operation.
          def sync_graft
            wanted = Layer.engines_of(children)
            return if wanted == @engines && wanted.all? { |engine| engine.parent.equal?(@target) }

            first = @engines.find { |engine| engine.parent.equal?(@target) }
            place = first ? @target.children.index(first) : start
            (@engines - wanted).each { |engine| @target.remove(engine) if engine.parent.equal?(@target) }
            place = [place, @target.children.size].min
            wanted.each_with_index { |engine, at| @target.add(engine, place + at) unless @target.children[place + at].equal?(engine) }
            @engines = wanted
          end

          private

          # Tells where its parts start in its target the first time.
          #
          # @return [Integer] The place.
          def start
            children = @target.children
            at = children.index(@anchor)
            case @mode
            when :prepend then 0
            when :append then children.size
            when :before then at || @hint || 0
            when :after then at ? at + 1 : @hint || children.size
            else @hint || children.size
            end
          end
        end

        # The root of a graft's parts: it shows while the old component it lies at shows.
        class GraftTop < Layer::Top
          # Makes it.
          #
          # @param anchor [Component] The old component.
          def initialize(anchor)
            @anchor = anchor
            self.kind = :graft
            self.closed = false
          end

          # Tells whether the parts show: the old component shows.
          #
          # @return [Boolean] Whether they do.
          def shown?
            !@anchor.disposed? && @anchor.shown?
          end

          # Tells the frames between two reads of the parts' live values.
          #
          # @return [Integer] The frames.
          def live_every
            GRAFT_LIVE_EVERY
          end
        end

        # The node of an old component a patch keeps inside the parts it put in its place.
        KEPT = Declarations::Declaration.new(:kept_part, :common => false, :kept => true,
                                             :make => lambda { |options| options[:kept] }, :options => lambda { |params| { :kept => params[:kept] } })

        @patches = []
        @index = nil
        @order = {}
        @seq = 0
        @off = {}
        @grafts = []
        @pending = []
        @checked = {}
        @hits = {}
        @types = {}
        @frame = 0
        @version = 0

        # Registers a patch.
        #
        # @param selector [String] The selector of its targets.
        # @param block [Proc] Its block, which gets the handle.
        # @param trace [Array<String>] Where UI.patch was called.
        # @return [nil] Always.
        # @raise [MarkupError] The selector is none, or there is no block.
        def self.register(selector, block, trace)
          raise MarkupError, "UI.patch needs a block, such as UI.patch(\"#camp_notes\") { |t| t.hide \"#clear\" }" unless block
          raise MarkupError, "UI.patch takes a selector as a text, such as \"#camp_notes\", not #{Declarations.show(selector)}" unless selector.is_a?(String)

          paths = Selector.parse(selector)
          @seq += 1
          patch = Patch.new(selector, paths, block, Errors.mod(trace), Errors.site(trace), @seq)
          @patches << patch
          patch.number = @patches.count { |each| each.mod == patch.mod }
          @index = nil
          @version += 1
          log("#{patch.mod}#{patch.site ? " (#{patch.site})" : ''} patches #{selector}")

          Layer.tops.each { |top| Layer.render_all(top) }
          GameWindows.patched
          nil
        end

        # Tells how often a patch was registered, so what keeps the patches of a game window class
        # knows when to look again.
        #
        # @return [Integer] The count.
        def self.version
          @version
        end

        # Lists every patch, in the order they apply.
        #
        # @return [Array<Patch>] The patches.
        def self.all
          index
          ordered
        end

        # Tells a patch's place in the order the patches apply.
        #
        # @param patch [Patch] The patch.
        # @return [Integer] The place.
        def self.order_of(patch)
          index
          @order[patch] || 0
        end

        # Tells whether any patch is registered.
        #
        # @return [Boolean] Whether one is.
        def self.any?
          !@patches.empty?
        end

        # Tells whether a frame of the layer has work of the patches: parts added to old screens or
        # checks of what a selector matched.
        #
        # @return [Boolean] Whether it has.
        def self.busy?
          !@grafts.empty? || !@pending.empty?
        end

        # Applies the patches to what a component's render described, before the layer matches it
        # with the parts on the screen. A failure inside never reaches the owner.
        #
        # @param mount [Layer::Mount] The component.
        # @param nodes [Array<Node>] What its render described.
        # @return [Array<Node>] What it shows.
        def self.render(mount, nodes)
          return nodes if @patches.empty? || mount.top.is_a?(GraftTop)

          chain = []
          item = mount
          while item
            chain.unshift(item.node)
            item = item.parent
          end
          context = { :root => root_of_top(mount.top), :top => mount.top, :top_level => mount.parent.nil? }
          floor = chain.map { |node| node.patch_floor }.compact.max
          mount.node.patch_entries = targets_at(chain, context, floor) if mount.parent.nil?
          active = []
          chain.each_with_index { |node, at| Array(node.patch_entries).each { |entry| active << [entry, at] } }
          inside = Array(mount.node.patch_inside)
          if mount.parent.nil?
            ops = ops_for(chain, chain.size - 1, active, floor)
            inside = ops.select { |op, _entry| [:prepend, :append].include?(op.kind) }
            refuse_on_top(ops - inside)
          end
          nodes = add_inside(nodes, inside, context) unless inside.empty?
          walk(nodes, chain, active, context, floor)
        rescue StandardError => e
          log_once([:render, e.class, e.message], "the patches of #{mount.component.class.name} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          nodes
        end

        # Applies the patches to an old component going onto the screen, and to what it holds. A
        # failure inside never reaches the owner.
        #
        # @param component [Component] The component.
        # @param parent [Component, nil] Its parent, nil for a root.
        # @param index [Integer, nil] Its place among the parent's children, nil for their end.
        # @return [Integer, nil] Its place now, which parts a patch added beside it may have moved.
        def self.attaching(component, parent, index)
          return index if @patches.empty? || layered?(component) || kept?(component)

          chain = []
          above = parent
          while above
            return index if layered?(above) || kept?(above)

            chain.unshift(above)
            above = above.parent
          end
          root = old_root_name(chain.first || component)
          active = []
          chain.each_with_index { |item, at| Array(item.patch_entries).each { |entry| active << [entry, at] } }
          walk_engine(component, chain, active, root)
          return index unless parent && component.parent.equal?(parent)

          place = parent.children.index(component)
          index.nil? && place == parent.children.size - 1 ? nil : place
        rescue StandardError => e
          log_once([:attach, e.class, e.message], "the patches of #{component.describe} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          index
        end

        # Runs the work of the patches after the layer rendered a frame: what each new target's
        # selectors match is checked once, and the parts added to old screens read their live values
        # and leave with what they lie in.
        def self.after_frame
          @frame += 1
          check_pending
          return if @grafts.empty?

          gone = @grafts.select { |graft| graft.gone || left?(graft.anchor) }
          gone.each { |graft| Layer.drop_graft(graft) }
          @grafts -= gone
          return unless (@frame % GRAFT_LIVE_EVERY).zero?

          @grafts.each { |graft| Layer.refresh_live_of(graft.children) if graft.top.shown? }
        end

        # Logs once each patch whose selector names an owner (#Owner/id) that is not loaded, as the
        # game starts; such a patch changes nothing.
        def self.check_owners
          loaded = defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:loaded) ? Array(Mod_Framework::Mods.loaded).map { |name| plain(name) } : []
          return if loaded.empty?

          @patches.each do |patch|
            patch.paths.flatten.each do |step|
              step.ids.each do |owner, _name|
                next if owner.nil? || loaded.include?(plain(owner)) || plain(owner) == plain(FRAMEWORK)

                log_once([:owner, patch.seq, owner], "#{patch.mod}#{patch.site ? " (#{patch.site})" : ''}: #{patch.text.inspect} names #{owner}, " \
                                                     "which is not loaded, so it changes nothing")
              end
            end
          end
        end

        # Forgets the parts added to old screens, as F12 starts the game again; the patches stay.
        def self.reset
          @grafts = []
          @pending = []
        end

        # Tells the rows a list of the old engine shows: those its owner gives, changed by the
        # patches that change them.
        #
        # @param list [List] The list.
        # @param rows [Array] The rows its owner gives.
        # @return [Array] The rows to show.
        def self.rows_for(list, rows)
          list.patch_raw_rows = rows
          shown = rows.nil? ? [] : rows.to_a
          list.patch_rows.each_value do |op, entry|
            next if off?(entry.patch, entry.root)

            guarded(entry, op) { shown = changed_rows(op, shown) }
          end
          shown
        end

        # Runs an event of an old component through the handlers patches wrap around it, the last
        # loaded outermost.
        #
        # @param component [Component] The component.
        # @param name [Symbol] The event.
        # @param values [Array] What it tells.
        # @yield Runs the component's own blocks with values.
        # @return [Object] What the outermost handler answered, false when one refused.
        def self.wrapped(component, name, values, &inner)
          call = lambda { |args| inner.call(*args) }
          component.patch_wraps[name.to_sym].each_value do |op, entry|
            next if off?(entry.patch, entry.root)

            call = engine_wrapper(op, entry, component, call)
          end
          call.call(values)
        end

        # Tells whether an old component has handlers patches wrap around an event.
        #
        # @param component [Component] The component.
        # @param name [Symbol] The event.
        # @return [Boolean] Whether it has.
        def self.wraps?(component, name)
          wraps = component.patch_wraps
          !wraps.nil? && !wraps[name.to_sym].nil? && !wraps[name.to_sym].empty?
        end

        # Reads a value the owner of a target exposed: the component that wrote a part of the layer,
        # or the nearest old component from the target up that exposes it; a game window's value it
        # keeps and answers.
        #
        # @param target [Node, Component, Window_Base] The target.
        # @param name [Symbol] The value.
        # @return [Object] The value.
        # @raise [MarkupError] It exposes no value of that name.
        def self.read(target, name)
          return GameWindows.read(target, name) if GameWindows.target?(target)
          return read_engine(target, name) unless target.is_a?(Node)

          component = target.component? ? target.mount && target.mount.component : target.owner
          raise MarkupError, "#{describe(target)} is not made yet, so it exposes nothing; read it in a handler" if target.component? && component.nil?
          raise MarkupError, "#{describe(target)} exposes nothing" unless component.is_a?(UI::Component)

          Layer.exposed(component, name)
        end

        # Lists what other mods may name of an open root: the parts with an id, the types of the
        # parts inside it and the values it exposes, as the table of the parts you can patch gives
        # them.
        #
        # @param root [Component, Layer::Top] An old root, or a top of the layer.
        # @return [Hash] :ids (each [id, type]), :types and :exposes, sorted.
        def self.parts_of(root)
          found = { :ids => [], :types => [], :exposes => [] }
          if root.is_a?(Layer::Top)
            collect_layer(root.mount, found)
          else
            collect_engine(root, found)
          end
          found[:ids].uniq!
          found[:types] = found[:types].uniq.sort
          found[:exposes] = found[:exposes].uniq.sort
          found
        end

        # Tells the type a selector names a part by: a built-in's markup name, a component's class
        # name, or for an old component the snake case of the engine class it is built on.
        #
        # @param item [Node, Component] The part.
        # @return [String] The type.
        def self.type_of(item)
          if item.is_a?(Node)
            return item.component? ? item.type.name.to_s : item.type.to_s
          end

          @types[item.class] ||= begin
            klass = item.class
            klass = klass.superclass until klass.nil? || klass.name.to_s =~ /\AMod_Framework::UI::Engine::\w+\z/
            Scopes.snake((klass || item.class).name.to_s.split("::").last)
          end
        end

        # Tells whether a part has what a step of a selector asks for. An old component tells no
        # mod, so #Owner/id matches its id alone.
        #
        # @param item [Node, Component] The part.
        # @param step [Selector::Step] The step.
        # @return [Boolean] Whether it has.
        def self.fits?(item, step)
          return false if step.type && step.type != type_of(item)

          id = id_of(item)
          unless step.ids.empty?
            return false if id.nil?
            return false unless step.ids.all? { |owner, name| same_id?(id, name) && (owner.nil? || owner_fits?(item, owner)) }
          end
          return true if step.classes.empty?

          classes = item.is_a?(Node) ? Array(item.params[:class]).map { |each| each.to_s } : []
          step.classes.all? { |name| classes.include?(name) }
        end

        # Tells whether a part at a place of a path is the one a selector's path names, the parts
        # it lies in named by the steps before, looking no higher than a place.
        #
        # @param path [Array] The parts from the top down.
        # @param last [Integer] The place of the part.
        # @param steps [Array<Selector::Step>] The selector's path.
        # @param from [Integer] The highest place the steps before may name.
        # @return [Boolean] Whether it is.
        def self.path_fits?(path, last, steps, from)
          return false unless fits?(path[last], steps.last)
          return true if steps.size == 1

          rest = steps[0...-1]
          above = last - 1
          while above >= from
            return true if path_fits?(path, above, rest, from)
            return false if steps.last.child

            above -= 1
          end
          false
        end

        # Logs a patch that failed and switches it off for the root it failed in, which renders
        # again without it.
        #
        # @param patch [Patch] The patch.
        # @param root [String] The root.
        # @param op [Op, nil] The operation that failed, nil for the block.
        # @param error [Exception] What it raised.
        def self.switch_off(patch, root, op, error)
          @off[[patch.seq, root]] = true
          place = (op && op.site) || Errors.site(error.backtrace) || patch.site
          message = error.message.to_s.sub(/ \(\S+:\d+\)\z/, "")
          log_once([:failed, patch.seq, root], "#{patch.mod}#{place ? " (#{place})" : ''}: the UI.patch of #{patch.text.inspect} failed: #{message}; " \
                                               "#{root} shows without it for the rest of the session")
          Layer.tops.each { |top| Layer.render_all(top) if root_of_top(top) == root }
        end

        # Tells whether a patch is switched off for a root.
        #
        # @param patch [Patch] The patch.
        # @param root [String] The root.
        # @return [Boolean] Whether it is.
        def self.off?(patch, root)
          @off.key?([patch.seq, root])
        end

        # Names a part for the log.
        #
        # @param item [Node, Component] The part.
        # @return [String] Such as "button #clear".
        def self.describe(item)
          id = id_of(item)
          "#{type_of(item)}#{id ? " ##{id}" : ''}"
        end

        # Tells the patches in the order they apply: by their mods' load order, then as registered.
        #
        # @return [Array<Patch>] The patches.
        def self.ordered
          @patches.sort_by { |patch| [Placement.load_order(patch.mod), patch.seq] }
        end
        private_class_method :ordered

        # Tells the patches indexed by the last step of each path of their selectors: by its first
        # id, else its type, else its first class.
        #
        # @return [Hash] {:id, :type, :class} => {name => [Patch]}.
        def self.index
          @index ||= begin
            index = { :id => {}, :type => {}, :class => {} }
            @order = {}
            ordered.each_with_index do |patch, place|
              @order[patch] = place
              patch.paths.each do |steps|
                step = steps.last
                kind, name = if !step.ids.empty? then [:id, step.ids.first[1]]
                             elsif step.type then [:type, step.type]
                             else [:class, step.classes.first]
                             end
                list = (index[kind][name.to_s] ||= [])
                list << patch unless list.include?(patch)
              end
            end
            index
          end
        end
        private_class_method :index

        # Tells the patches whose selectors may name a part, by its id, type and classes.
        #
        # @param item [Node, Component] The part.
        # @return [Array<Patch>] The patches, in the order they apply.
        def self.candidates(item)
          table = index
          found = []
          id = id_of(item)
          found.concat(table[:id][id.to_s]) if id && table[:id][id.to_s]
          typed = table[:type][type_of(item)]
          found.concat(typed) if typed
          if item.is_a?(Node) && !table[:class].empty?
            Array(item.params[:class]).each { |name| found.concat(table[:class][name.to_s] || []) }
          end
          return found if found.size < 2

          found.uniq.sort_by { |patch| @order[patch] }
        end
        private_class_method :candidates

        # Runs the patches whose selectors name the last part of a path on it.
        #
        # @param path [Array] The parts from the top down.
        # @param context [Hash] :root, the root's name.
        # @param floor [Integer, nil] The place of the patch that added the part, after which a patch
        #   must come to apply to it; nil for a part its owner wrote.
        # @return [Array<Entry>] Each patch run, without those that failed.
        def self.targets_at(path, context, floor = nil)
          item = path.last
          entries = []
          candidates(item).each do |patch|
            next if off?(patch, context[:root]) || (floor && @order[patch] <= floor)
            next unless patch.paths.any? { |steps| path_fits?(path, path.size - 1, steps, 0) }

            entry = run(patch, item, context[:root])
            entries << entry if entry
          end
          entries
        end
        private_class_method :targets_at

        # Runs a patch's block on a target.
        #
        # @param patch [Patch] The patch.
        # @param target [Node, Component] The target.
        # @param root [String] The root.
        # @return [Entry, nil] The patch run, nil when its block raised.
        def self.run(patch, target, root)
          handle = Handle.new(patch, target)
          patch.block.call(handle)
          Entry.new(patch, handle.ops, target, root)
        rescue StandardError => e
          switch_off(patch, root, nil, e)
          nil
        end
        private_class_method :run

        # Lists the operations of the patches run above a part that name it, in the order the
        # patches apply.
        #
        # @param path [Array] The parts from the top down.
        # @param last [Integer] The part's place.
        # @param active [Array<Array>] Each patch run, with the place of its target.
        # @param floor [Integer, nil] See targets_at.
        # @return [Array<Array>] Each [Op, Entry].
        def self.ops_for(path, last, active, floor = nil)
          index if floor
          found = []
          active.each do |entry, at|
            next if off?(entry.patch, entry.root) || (floor && @order[entry.patch] <= floor)

            entry.ops.each do |op|
              next if op.kind == :read

              hit = op.paths.nil? ? last == at : last > at && op.paths.any? { |steps| path_fits?(path, last, steps, at + 1) }
              next unless hit

              found << [op, entry]
              @hits[[entry.patch.seq, op.index]] = true
            end
          end
          return found if found.size < 2

          index
          found.sort_by { |op, entry| [@order[entry.patch] || 0, op.index] }
        end
        private_class_method :ops_for

        # Runs an operation of a patch, switching the patch off where it raises.
        #
        # @param entry [Entry] The patch run.
        # @param op [Op] The operation.
        # @yield The operation.
        # @return [Boolean] Whether it ran.
        def self.guarded(entry, op)
          return false if off?(entry.patch, entry.root)

          yield
          true
        rescue StandardError => e
          switch_off(entry.patch, entry.root, op, e)
          false
        end
        private_class_method :guarded

        # Applies the patches to the parts a render described and to what they hold.
        #
        # @param list [Array<Node>] The parts.
        # @param path [Array<Node>] The parts above them, from the top down.
        # @param active [Array<Array>] Each patch run above them, with the place of its target.
        # @param context [Hash] :root, :top and :top_level.
        # @param floor [Integer, nil] See targets_at, for the parts the list lies in.
        # @return [Array<Node>] The parts to show.
        def self.walk(list, path, active, context, floor = nil)
          shown = []
          list.each do |node|
            next shown << node if node.patch_done

            node.patch_done = true
            own = [floor, node.patch_floor].compact.max
            path.push(node)
            at = path.size - 1
            here = active
            entries = targets_at(path, context, own)
            unless entries.empty?
              node.patch_entries = entries
              here = active + entries.map { |entry| [entry, at] }
              entries.each { |entry| @pending << [entry, context[:top]] if entry.ops.any? { |op| op.paths && !@checked[[entry.patch.seq, op.index]] } }
            end
            ops = ops_for(path, at, here, own)
            whole = context[:top_level] && at == 1 && !node.component? && node.declaration.root
            kept = apply_node(node, ops, context, whole)
            node.children.replace(walk(node.children, path, here, context, own)) unless node.component?
            path.pop
            shown.concat(walk(added(node, ops, :before, context, whole), path, active, context, floor))
            shown.concat(kept ? walk(replaced(node, ops, context, whole), path, active, context, floor) : [])
            shown.concat(walk(added(node, ops, :after, context, whole), path, active, context, floor))
          end
          shown
        end
        private_class_method :walk

        # Applies a part's sets, wrapped handlers, rows, prepends, appends and hiding.
        #
        # @param node [Node] The part.
        # @param ops [Array<Array>] Its operations.
        # @param context [Hash] See walk.
        # @param whole [Boolean] Whether it is the root of a window, which stays.
        # @return [Boolean] False when a hidden component leaves.
        def self.apply_node(node, ops, context, whole)
          kept = true
          APPLY_ORDER.each do |kind|
            ops.each do |op, entry|
              next unless op.kind == kind

              guarded(entry, op) do
                case kind
                when :set then set_node(node, op, entry)
                when :on then wrap_node(node, op, entry)
                when :rows then rows_node(node, op, entry)
                when :prepend, :append then inside_node(node, op, entry, context)
                when :hide
                  raise MarkupError, "hide cannot hide the #{node.type} itself; close it, or hide a part inside it" if whole

                  if node.component?
                    kept = false
                  else
                    node.params[:visible] = false
                  end
                end
              end
            end
          end
          kept
        end
        private_class_method :apply_node

        # Sets params on a part, after checking them as markup is checked.
        #
        # @param node [Node] The part.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        def self.set_node(node, op, entry)
          params = op.values[0]
          declaration = node.component? ? node.type.declaration : node.declaration
          params.each do |name, value|
            raise MarkupError, "set cannot change key:, which tells a part from its siblings" if name == :key

            declaration.check(name, value)
          end
          params.each do |name, value|
            set = (node.patch_set ||= {})
            note_conflict(:set, node, name, set[name], entry.patch.mod)
            set[name] = entry.patch.mod
            node.params[name] = value
          end
        end
        private_class_method :set_node

        # Wraps a part's handler of an event.
        #
        # @param node [Node] The part.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        def self.wrap_node(node, op, entry)
          event = op.values[0]
          param = :"on_#{event}"
          events = node.component? ? node.type.params.select { |_name, each| each[:handler] }.keys : node.declaration.params.values.select { |each| each.kind == :handler }.map { |each| each.name }
          unless events.include?(param)
            names = events.map { |name| name.to_s.sub(/\Aon_/, "").to_sym }
            near = Declarations.nearest(event, names)
            raise MarkupError, "#{describe(node)} has no event :#{event}#{near ? "; did you mean :#{near}?" : ''}#{names.empty? ? '' : "; it has #{names.map { |name| ":#{name}" }.join(', ')}"}"
          end
          owner = node.owner
          handler = node.params[param]
          what = describe(node)
          node.params[param] = lambda do |*values|
            original = Original.new { |args| Layer.invoke(owner, handler, args.empty? ? values : args) }
            Patches.wrapper_answer(op, entry, what, original, values)
          end
        end
        private_class_method :wrap_node

        # Runs the block of a wrapped handler: its answer when it ran the owner's handler, else the
        # event is refused and logged. A block that raises is switched off and the owner's handler
        # runs.
        #
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param what [String] The part, for the log.
        # @param original [Original] The owner's handler.
        # @param values [Array] What the event tells.
        # @return [Object] What the block answered, false when it refused.
        def self.wrapper_answer(op, entry, what, original, values)
          return original.call(*values) if off?(entry.patch, entry.root)

          begin
            answer = op.block.call(original, *values)
          rescue StandardError => e
            switch_off(entry.patch, entry.root, op, e)
            return original.called? ? nil : original.call(*values)
          end
          return answer if original.called?

          log("#{entry.patch.mod} refused #{op.values[0]} of #{what} in #{entry.root}#{op.site ? " (#{op.site})" : ''}")
          false
        end

        # Patches a list's rows, or adds the block to those an options list runs on the rows it makes
        # itself.
        #
        # @param node [Node] The list or the options list.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        def self.rows_node(node, op, entry)
          if !node.component? && node.declaration.params.key?(:patched_rows)
            return node.params[:patched_rows] = Array(node.params[:patched_rows]) + [lambda { |rows| patched_rows(op, entry, rows) }]
          end
          unless !node.component? && node.declaration.params.key?(:items)
            raise MarkupError, "rows changes the rows of a list or an options list, not of #{describe(node)}"
          end

          node.params[:items] = changed_rows(op, Array(node.params[:items]))
        end
        private_class_method :rows_node

        # Runs the block of rows on the rows an options list made, as it makes them.
        #
        # The block runs after the patch run, so a raise is caught here: it switches the patch off
        # and the rows stay as made.
        #
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param rows [Array<Hash>] The rows.
        # @return [Array<Hash>] The rows the block answered, else the rows as made.
        def self.patched_rows(op, entry, rows)
          return rows if off?(entry.patch, entry.root)

          changed_rows(op, rows)
        rescue StandardError => e
          switch_off(entry.patch, entry.root, op, e)
          rows
        end
        private_class_method :patched_rows

        # Runs the block of rows on a copy of the rows.
        #
        # @param op [Op] The operation.
        # @param rows [Array] The rows.
        # @return [Array] The rows the block answered.
        # @raise [MarkupError] It answered no Array.
        def self.changed_rows(op, rows)
          answer = op.block.call(rows.dup)
          raise MarkupError, "the block of rows answers the rows as an Array, not #{Declarations.show(answer)}" unless answer.is_a?(Array)

          answer
        end
        private_class_method :changed_rows

        # Adds markup inside a part, or notes it for a component's render.
        #
        # @param node [Node] The part.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param context [Hash] See walk.
        def self.inside_node(node, op, entry, context)
          return (node.patch_inside ||= []) << [op, entry] if node.component?
          raise MarkupError, "#{op.kind} adds parts inside a part that holds parts; #{describe(node)} holds none, so add them after it" unless node.declaration.content?

          made = build(op, entry, nil)
          op.kind == :prepend ? node.children.unshift(*made) : node.children.concat(made)
        end
        private_class_method :inside_node

        # Adds the prepends and appends a patch asked for inside a component to what it rendered:
        # inside the one part it rendered when that holds parts, else among what it rendered.
        #
        # @param nodes [Array<Node>] What it rendered.
        # @param inside [Array<Array>] Each [Op, Entry].
        # @param context [Hash] See walk.
        # @return [Array<Node>] What it shows.
        def self.add_inside(nodes, inside, context)
          holder = nodes.size == 1 && !nodes[0].component? && nodes[0].declaration.content? ? nodes[0].children : nodes.dup
          inside.each do |op, entry|
            guarded(entry, op) do
              made = build(op, entry, nil)
              op.kind == :prepend ? holder.unshift(*made) : holder.concat(made)
            end
          end
          holder.equal?(nodes[0] && nodes[0].children) ? nodes : holder
        end
        private_class_method :add_inside

        # Makes the parts the operations of a kind add next to a part.
        #
        # @param node [Node] The part.
        # @param ops [Array<Array>] Its operations.
        # @param kind [Symbol] :before or :after.
        # @param context [Hash] See walk.
        # @param whole [Boolean] Whether it is the root of a window, which takes nothing beside it.
        # @return [Array<Node>] The parts.
        def self.added(node, ops, kind, context, whole)
          made = []
          ops.each do |op, entry|
            next unless op.kind == kind

            guarded(entry, op) do
              raise MarkupError, "#{kind} cannot add parts beside the #{node.type} itself; add them inside it" if whole

              made.concat(build(op, entry, nil))
            end
          end
          made
        end
        private_class_method :added

        # Tells what shows in a part's place: what the last loaded patch that replaces it puts
        # there, or the part. Two mods that replace one part are logged.
        #
        # @param node [Node] The part.
        # @param ops [Array<Array>] Its operations.
        # @param context [Hash] See walk.
        # @param whole [Boolean] Whether it is the root of a window, which stays.
        # @return [Array<Node>] What shows.
        def self.replaced(node, ops, context, whole)
          replaces = ops.select { |op, entry| op.kind == :replace && !off?(entry.patch, entry.root) }
          return [node] if replaces.empty?

          mods = replaces.map { |_op, entry| entry.patch.mod }.uniq
          note_conflict(:replace, node, nil, mods[-2], mods[-1]) if mods.size > 1
          op, entry = replaces.last
          made = nil
          ran = guarded(entry, op) do
            raise MarkupError, "replace cannot replace the #{node.type} itself; replace a part inside it" if whole

            made = replacement(node, op, entry)
          end
          ran ? made : [node]
        end
        private_class_method :replaced

        # Makes what a replace puts in a part's place.
        #
        # @param node [Node] The part.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @return [Array<Node>] The parts.
        def self.replacement(node, op, entry)
          component = op.values[0]
          return build(op, entry, node) unless component

          raise MarkupError, "replace takes a class of UI::Component, not #{Declarations.show(component)}" unless component.is_a?(Class) && component < UI::Component

          declared = component.params
          given = {}
          node.params.each do |name, value|
            param = declared[name]
            next unless param || [:id, :class].include?(name)
            next if value.is_a?(Proc) && !(param && (param[:handler] || param[:content]))

            given[name] = value
          end
          given[:original] = lambda { Builder.place_node(node) } if declared[:original] && declared[:original][:content]
          made = Node.new(component, nil, component.take_params([given]), entry.patch.owner)
          mark_added(made, op, entry, 0)
          [made]
        end
        private_class_method :replacement

        # Runs the markup of an operation and hands out the parts it describes, keyed by their mod.
        #
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param kept [Node, nil] The part a replace keeps, which the block may place.
        # @return [Array<Node>] The parts.
        def self.build(op, entry, kept)
          values = kept ? [Kept.new(kept)] : []
          made = Builder.capture { MarkupProxy.run(op.block, *values) }
          made.reject { |node| node.equal?(kept) }.each_with_index do |node, place|
            raise MarkupError, "#{op.kind} adds parts; #{node.type} is a root of its own, which UI.open or UI.show opens" if !node.component? && node.declaration && node.declaration.root

            mark_added(node, op, entry, place)
          end
          made
        end

        # Gives a part a patch added the key of its mod and the place in the patch block of the
        # operation that added it, such as "Camp_Plus:3", "Camp_Plus:3_2" for its second part and
        # "Camp_Plus:2:3" in the mod's second patch; notes where it was written; and keeps every
        # earlier patch off it.
        #
        # @param node [Node] The part.
        # @param op [Op] The operation that added it.
        # @param entry [Entry] The patch run.
        # @param place [Integer] Its place among the parts the operation added, 0 for the first.
        def self.mark_added(node, op, entry, place)
          block = entry.patch.number > 1 ? "#{entry.patch.number}:" : ''
          node.patch_key = "#{entry.patch.mod.tr(' ', '_')}:#{block}#{op.index + 1}#{place > 0 ? "_#{place + 1}" : ''}"
          node.key = node.patch_key if node.key.nil?
          node.patch_floor = order_of(entry.patch)
          node.site ||= op.site
        end
        private_class_method :mark_added

        # Logs two mods that set the same param of a part, or replace it, once.
        #
        # @param kind [Symbol] :set or :replace.
        # @param item [Node, Component] The part.
        # @param name [Symbol, nil] The param.
        # @param first [String, nil] The mod that did it before, nil for none.
        # @param last [String] The mod that does it now.
        def self.note_conflict(kind, item, name, first, last)
          return if first.nil? || first == last

          what = kind == :set ? "set #{name}: of" : "replace"
          shown = kind == :set ? "its value is used" : "its part shows"
          log_once([:conflict, kind, first, last, type_of(item), id_of(item), name],
                   "#{first} and #{last} both #{what} #{describe(item)}; #{last} loaded last, so #{shown}")
        end
        private_class_method :note_conflict

        # Logs operations of a patch run on the component at the top of a root that cannot change
        # it, once.
        #
        # @param ops [Array<Array>] Each [Op, Entry].
        def self.refuse_on_top(ops)
          ops.each do |op, entry|
            log_once([:top, entry.patch.seq, op.index], "#{entry.patch.mod}#{op.site ? " (#{op.site})" : ''}: #{op.kind} changes nothing on the component " \
                                                        "#{type_of(entry.target)} itself; name its window by its id")
          end
        end
        private_class_method :refuse_on_top

        # Checks once what the operations of each new target's patches match, and logs a selector
        # that matches nothing with the ids and types found there.
        def self.check_pending
          return if @pending.empty?

          pending = @pending
          @pending = []
          pending.each do |entry, top|
            item = top && !top.closed ? find_item(top.mount, entry.target) : nil
            next unless item

            entry.ops.each do |op|
              key = [entry.patch.seq, op.index]
              next if op.paths.nil? || @checked[key]

              @checked[key] = true
              next if @hits[key]

              found = { :ids => [], :types => [] }
              matched = false
              each_below(item, [item.node]) do |path|
                node = path.last
                found[:ids] << "##{node.params[:id]}" if node.params[:id]
                found[:types] << type_of(node)
                matched ||= op.paths.any? { |steps| path_fits?(path, path.size - 1, steps, 1) }
              end
              nothing(entry, op, found) unless matched
            end
          end
        end
        private_class_method :check_pending

        # Finds the part or component of the layer whose node is a target.
        #
        # @param item [Layer::Part, Layer::Mount] Where to look.
        # @param node [Node] The target's node.
        # @return [Layer::Part, Layer::Mount, nil] It, nil when it is gone.
        def self.find_item(item, node)
          return item if item.node.equal?(node)

          item.children.each do |child|
            found = find_item(child, node)
            return found if found
          end
          nil
        end
        private_class_method :find_item

        # Walks the parts and components below one, handing each one's path from it down.
        #
        # @param item [Layer::Part, Layer::Mount] The part.
        # @param path [Array<Node>] The nodes from the target down to it.
        # @yieldparam path [Array<Node>] The path of a part below.
        def self.each_below(item, path, &block)
          item.children.each do |child|
            path.push(child.node)
            block.call(path)
            each_below(child, path, &block)
            path.pop
          end
        end
        private_class_method :each_below

        # Logs an operation whose selector matches nothing, once, with the nearest id or type found.
        #
        # @param entry [Entry] The patch run.
        # @param op [Op] The operation.
        # @param found [Hash] :ids and :types found below the target.
        def self.nothing(entry, op, found)
          ids = found[:ids].uniq
          types = found[:types].uniq
          step = op.paths.last.last
          near = step.ids.empty? ? (step.type ? Declarations.nearest(step.type, types) : nil) : Declarations.nearest("##{step.ids.first[1]}", ids)
          there = (ids.first(MOST_NAMED) + types.first(MOST_NAMED)).join(", ")
          log("#{entry.patch.mod}#{op.site ? " (#{op.site})" : ''}: #{op.kind} #{op.text.inspect} matches nothing inside #{describe(entry.target)}" \
              "#{near ? "; did you mean #{near}?" : ''}#{there.empty? ? '' : "; there: #{there}"}")
        end
        private_class_method :nothing

        # Applies the patches to an old component and to what it holds.
        #
        # @param component [Component] The component.
        # @param chain [Array<Component>] The components above it, from the root down.
        # @param active [Array<Array>] Each patch run above it, with the place of its target.
        # @param root [String] The root's name.
        def self.walk_engine(component, chain, active, root)
          path = chain + [component]
          at = path.size - 1
          entries = targets_at(path, :root => root)
          unless entries.empty?
            component.patch_entries = entries
            active = active + entries.map { |entry| [entry, at] }
          end
          ops = ops_for(path, at, active)
          APPLY_ORDER.each do |kind|
            ops.each { |op, entry| guarded(entry, op) { apply_engine(component, op, entry, [path, active, root]) } if op.kind == kind }
          end
          component.children.dup.each { |child| walk_engine(child, path, active, root) unless layered?(child) || kept?(child) }
          [:replace, :before, :after].each do |kind|
            picked = ops.select { |op, entry| op.kind == kind && !off?(entry.patch, entry.root) }
            if kind == :replace && !picked.empty?
              note_conflict(:replace, component, nil, picked[0][1].patch.mod, picked[-1][1].patch.mod)
              picked = picked.last(1)
            end
            picked.each { |op, entry| guarded(entry, op) { graft_beside(component, op, entry, [chain, active, root]) } }
          end
          entries.each { |entry| check_engine(entry, component) }
        end
        private_class_method :walk_engine

        # Applies one operation to an old component: set, wrapped handlers, rows, prepend, append or
        # hide.
        #
        # @param component [Component] The component.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param around [Array] The components from the root down to it, the patches run on them and
        #   the root's name, which the parts it adds are walked with.
        def self.apply_engine(component, op, entry, around)
          case op.kind
          when :set
            params = op.values[0]
            params.each do |name, value|
              next if name != :id && component.respond_to?("#{name}=")

              near = Declarations.nearest(name, component.class.defaults.keys - [:id])
              raise MarkupError, "#{describe(component)} takes no #{name}:#{near ? "; did you mean #{near}:?" : ''}"
            end
            set_engine(component, params, entry)
          when :hide
            set_engine(component, { :visible => false }, entry)
          when :on
            wraps = (component.patch_wraps ||= {})
            (wraps[op.values[0]] ||= {})[[entry.patch.seq, op.index]] = [op, entry]
          when :rows
            raise MarkupError, "rows changes the rows of a list, not of #{describe(component)}" unless component.is_a?(List)

            rows = (component.patch_rows ||= {})
            rows[[entry.patch.seq, op.index]] = [op, entry]
            raw = component.patch_raw_rows
            component.rows = raw.nil? ? component.rows : raw
          when :prepend, :append
            raise MarkupError, "#{op.kind} adds parts inside a part that holds parts; #{describe(component)} holds none, so add them after it" unless component.container?

            graft(component, component, op, entry, nil, around)
          end
        end
        private_class_method :apply_engine

        # Sets options of an old component that its owner's later changes do not undo.
        #
        # @param component [Component] The component.
        # @param params [Hash] The options.
        # @param entry [Entry] The patch run.
        def self.set_engine(component, params, entry)
          kept = (component.patch_options ||= {})
          by = (component.patch_set_by ||= {})
          params.each do |name, value|
            note_conflict(:set, component, name, by[name], entry.patch.mod) unless name == :visible && value == false
            by[name] = entry.patch.mod
            kept[name] = value
            component.__send__("#{name}=", value)
          end
        end
        private_class_method :set_engine

        # Puts parts before, after or in the place of an old component.
        #
        # @param component [Component] The component.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param around [Array] The components above it, the patches run on them and the root's name.
        def self.graft_beside(component, op, entry, around)
          parent = component.parent
          raise MarkupError, "#{op.kind} needs a part that lies in another; #{describe(component)} is a root" unless parent

          graft(component, parent, op, entry, parent.children.index(component), around)
        end
        private_class_method :graft_beside

        # Makes or renders anew the parts an operation adds to an old screen.
        #
        # @param anchor [Component] The component the patch named.
        # @param target [Component] Where the parts go.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param hint [Integer, nil] The anchor's place in target.
        # @param around [Array] The components the parts lie in from the root down, the patches run
        #   on them and the root's name: the later patches among them apply to the parts too.
        def self.graft(anchor, target, op, entry, hint, around)
          grafts = (anchor.patch_grafts ||= {})
          key = [entry.patch.seq, op.index]
          holder = grafts[key]
          if holder.nil? || holder.gone
            holder = Graft.new(target, op.kind, anchor, hint)
            grafts[key] = holder
            @grafts << holder
          end
          nodes = if op.kind == :replace
                    anchor.patch_kept = true
                    kept = Node.new(:kept_part, KEPT, { :kept => anchor }, nil)
                    kept.key = "kept:#{anchor.object_id}"
                    kept.patch_done = true
                    op.values[0] ? [replace_engine(anchor, kept, op, entry)] : build(op, entry, kept)
                  else
                    build(op, entry, nil)
                  end
          path, active, root = around
          nodes = walk(nodes, path.dup, active, { :root => root, :top => nil, :top_level => false })
          Layer.graft(holder, nodes)
        end
        private_class_method :graft

        # Makes the component a replace puts in an old component's place, which gets original: when
        # it declares it.
        #
        # @param anchor [Component] The old component.
        # @param kept [Node] The node that keeps it.
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @return [Node] The component's node.
        def self.replace_engine(anchor, kept, op, entry)
          component = op.values[0]
          raise MarkupError, "replace takes a class of UI::Component, not #{Declarations.show(component)}" unless component.is_a?(Class) && component < UI::Component

          given = {}
          declared = component.params[:original]
          given[:original] = lambda { Builder.place_node(kept) } if declared && declared[:content]
          made = Node.new(component, nil, component.take_params([given]), entry.patch.owner)
          mark_added(made, op, entry, 0)
          made
        end
        private_class_method :replace_engine

        # Checks what the operations of a patch run on an old component match, once, and logs a
        # selector that matches nothing.
        #
        # @param entry [Entry] The patch run.
        # @param component [Component] The target.
        def self.check_engine(entry, component)
          entry.ops.each do |op|
            key = [entry.patch.seq, op.index]
            next if op.paths.nil? || @checked[key]

            @checked[key] = true
            next if @hits[key]

            found = { :ids => [], :types => [] }
            matched = false
            each_engine_below(component, [component]) do |path|
              found[:ids] << "##{path.last.id}" if path.last.id
              found[:types] << type_of(path.last)
              matched ||= op.paths.any? { |steps| path_fits?(path, path.size - 1, steps, 1) }
            end
            nothing(entry, op, found) unless matched
          end
        end
        private_class_method :check_engine

        # Walks the old components below one, handing each one's path from it down.
        #
        # @param component [Component] The component.
        # @param path [Array<Component>] The components from the target down to it.
        # @yieldparam path [Array<Component>] The path of a component below.
        def self.each_engine_below(component, path, &block)
          component.children.each do |child|
            next if layered?(child)

            path.push(child)
            block.call(path)
            each_engine_below(child, path, &block)
            path.pop
          end
        end
        private_class_method :each_engine_below

        # Makes the handler a patch wraps around an event of an old component.
        #
        # @param op [Op] The operation.
        # @param entry [Entry] The patch run.
        # @param component [Component] The component.
        # @param below [Proc] Runs the handler it wraps with values.
        # @return [Proc] The handler, which takes the values.
        def self.engine_wrapper(op, entry, component, below)
          what = describe(component)
          lambda do |values|
            original = Original.new { |args| below.call(args.empty? ? values : args) }
            wrapper_answer(op, entry, what, original, values)
          end
        end
        private_class_method :engine_wrapper

        # Reads a value the nearest old component from a target up exposes.
        #
        # @param target [Component] The target.
        # @param name [Symbol] The value.
        # @return [Object] The value.
        # @raise [MarkupError] None exposes it.
        def self.read_engine(target, name)
          names = []
          item = target
          while item
            exposes = item.exposes || {}
            return exposes[name].call if exposes.key?(name)

            names.concat(exposes.keys)
            item = item.parent
          end
          near = Declarations.nearest(name, names)
          raise MarkupError, "#{describe(target)} exposes #{names.empty? ? 'nothing' : "no #{name}#{near ? "; did you mean #{near}?" : ''}; it exposes #{names.uniq.join(', ')}"}"
        end
        private_class_method :read_engine

        # Collects what other mods may name inside a component of the layer.
        #
        # @param item [Layer::Mount, Layer::Part] Where to look.
        # @param found [Hash] See parts_of.
        def self.collect_layer(item, found)
          node = item.node
          if item.is_a?(Layer::Mount)
            found[:exposes].concat(item.component.class.exposes.keys.map { |name| name.to_s })
          end
          found[:types] << type_of(node) unless node.type == :fragment
          found[:ids] << [node.params[:id].to_s, type_of(node)] if node.params[:id]
          item.children.each { |child| collect_layer(child, found) }
        end
        private_class_method :collect_layer

        # Collects what other mods may name inside an old component.
        #
        # @param component [Component] The component.
        # @param found [Hash] See parts_of.
        def self.collect_engine(component, found)
          return if layered?(component)

          found[:exposes].concat((component.exposes || {}).keys.map { |name| name.to_s })
          found[:types] << type_of(component)
          found[:ids] << [component.id.to_s, type_of(component)] if component.id
          component.children.each { |child| collect_engine(child, found) }
        end
        private_class_method :collect_engine

        # Tells a part's id: the one its owner gave, else for a part a patch added the key it got.
        #
        # @param item [Node, Component] The part.
        # @return [Object, nil] The id, nil for none.
        def self.id_of(item)
          item.is_a?(Node) ? item.params[:id] || item.patch_key : item.id
        end

        # Tells whether an id is the one a selector names; a mod's name in a key a patch gave may be
        # written with spaces or underscores.
        #
        # @param id [Object, nil] The part's id.
        # @param name [String] The name in the selector.
        # @return [Boolean] Whether it is.
        def self.same_id?(id, name)
          return false if id.nil?

          id.to_s == name || (id.to_s.include?(":") && plain(id) == plain(name))
        end

        # Tells whether a part of the layer was written by the mod an id names; an old component
        # tells none, so any mod fits.
        #
        # @param item [Node, Component] The part.
        # @param owner [String] The mod, as #Owner/id names it.
        # @return [Boolean] Whether it was.
        def self.owner_fits?(item, owner)
          return true unless item.is_a?(Node)

          mod = item.component? ? Scopes.mod_of(item.type) : Layer.mod_of_owner(item.owner)
          plain(mod) == plain(owner)
        end
        private_class_method :owner_fits?

        # Writes a mod's name as the log does.
        #
        # @param name [String, nil] The name.
        # @return [String] The name with spaces, in lower case.
        def self.plain(name)
          name.to_s.tr("_", " ").downcase
        end
        private_class_method :plain

        # Tells the name a failing patch is switched off under for a root of the layer: its
        # component's class.
        #
        # @param top [Layer::Top] The root.
        # @return [String] The name.
        def self.root_of_top(top)
          "#{top.mount.component.class.name}"
        end
        private_class_method :root_of_top

        # Tells the name a failing patch is switched off under for an old root: its id, else what
        # it is.
        #
        # @param root [Component] The root.
        # @return [String] The name.
        def self.old_root_name(root)
          root.id ? "##{root.id}" : root.describe
        end
        private_class_method :old_root_name

        # Tells whether an old component is a part of the layer.
        #
        # @param component [Component] The component.
        # @return [Boolean] Whether it is.
        def self.layered?(component)
          component.layer_part == true
        end
        private_class_method :layered?

        # Tells whether an old component left the screen for good: it was disposed, or what it lay
        # in was taken out; a closed window keeps what it holds for its next opening.
        #
        # @param component [Component] The component.
        # @return [Boolean] Whether it did.
        def self.left?(component)
          root = component.root
          component.disposed? || (!root.open? && !root.root_only?)
        end
        private_class_method :left?

        # Tells whether an old component lies inside the parts a patch put in its place.
        #
        # @param component [Component] The component.
        # @return [Boolean] Whether it does.
        def self.kept?(component)
          component.patch_kept == true
        end
        private_class_method :kept?
      end
    end

    Run.on_start("ui patch") { Mod_Framework::UI::Engine::Patches.check_owners }

    # Patches another mod's UI, the framework's or a game window by the ids, classes and types its
    # owner gave. The block runs each time a part the selector names renders, after its owner's
    # render, and gets the handle, whose operations apply once the block ends: set, before, after,
    # prepend, append, hide, replace, on, rows and read.
    #
    # Inside the block, self is your mod's own, so its methods work; in the markup blocks of
    # before, after, prepend, append and replace an @variable belongs to the framework, so use
    # methods or local variables there.
    #
    # @param selector [String] Such as "#equipment_window" or "#mf_mods list".
    # @yieldparam handle [Object] The handle: set(selector, params), before/after/prepend/append
    #   (selector) { markup }, hide(selector), replace(selector, Component) or replace(selector) {
    #   |original| markup }, on(selector, :event) { |original, *values| }, rows(selector) { |rows| },
    #   read(:name).
    # @return [nil] Always.
    # @raise [Engine::MarkupError] The selector is none, or there is no block.
    def self.patch(selector, &block)
      Engine::Patches.register(selector, block, caller)
    rescue Engine::MarkupError => e
      raise Engine::MarkupError, Engine::Errors.placed(e.message, caller)
    end
  end
end
