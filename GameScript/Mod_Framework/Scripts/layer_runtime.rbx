#----------------------------------------------------------------
#  layer_runtime.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Took a root that leaves off at once when told to hide at once
#                            - Placed the open huds of a column again once UI.column defines it
#                            - Let go of the answers of memo the render did not ask for again
#                            - Bound a list to the items its filter: keeps
#                            - Kept the block that puts the markup of a slot's or a line's tooltip into its box
#                            - Kept a live part from drawing anew while its colors read again stay the same
#                            - Read a root's live at: every frame, and closed a shown component at once when told
#                            - Built the key help's entries with fewer new objects, so an idle window with a key help stays light
#                            - Left a button out of the key help whose button_help: is nil
#      Paulinchen  2026-11-08: Named in the key help only the keys of the part in focus and of the parts it lies in,
#                              followed as the focus moves
#      Paulinchen  2026-11-07: Kept the value: an input was last given on its part
#                            - Marked a disabled choice of a context menu with :disabled
#                            - Declared the state the layer keeps of a part on Layer::Part
#      Paulinchen  2026-11-06: Left a hotkey out of the key help whose action one of its entries names already
#                            - Opened a part's context menu as a menu of UI.menu, a dialog of the UI layer
#                            - Removed the render that noted where every part was written, which only UI.dump read
#                            - Kept why the last component opened or shown did not open, such as its render failing
#                            - Ran the blocks of after_render also once the last root closed
#                            - Eased a part of a hud to a new height in pixels instead of taking it at once
#                            - Linked a part to the parts its cancel_to: and submit_to: name once its window is made
#                            - Put the keys a key help adds before its entry of cancel when that entry ends it
#                            - Counted a paper the keys stop on among the parts around a list for the jump keys
#                            - Named the jump keys in the key help as "Ctrl+arrows: Leave the list"
#      Paulinchen  2026-11-05: Hid a window joined to a game window with that window while the roots its handler opened are open
#                            - Rendered a component out of sight, such as on a page slides keep out of view, only once it
#                              comes into sight
#                            - Closed a context menu with the root of its part and moved it with that root
#                            - Put a table's cursor on its bound item among the rows its page shows
#                            - Sent the form a part lies in for its handler :submit, and kept the error an input shows
#                            - Slid the first slides a component rendered for its back and forward
#                            - Pulsed a part once each time its pulse: changed
#                            - Kept a window that waits for its menu scene, and took a root down once when its open was refused
#                            - Named a wheel besides a window and a dialog as what UI.open takes, and told a root gone
#                            - Named a marker besides a hud as what UI.show takes
#                            - Logged each window and dialog opening and closing, with why it closed
#                            - Told the window a dialog was opened from, and ran blocks once the next frame rendered
#                            - Kept a part out of the part it lies in by its params, as a drawer over the rest is a root
#                            - Named the move hotkeys in the key help of a window whose list they move the rows of
#                            - Asked the serials, the watches and the blocks after a render every frame with far fewer objects
#      Paulinchen  2026-11-04: Had a text field steer its list once the whole window is made
#                            - Offered the choices a built-in gives its context menu itself before those of context_menu:
#                            - Had a part follow its params as its live values are read again
#                            - Let a built-in put what it holds into its engine part its own way
#                            - Slid the slides around a part for a handler :forward or :back, and let a built-in follow what it holds after it
#                            - Opened or showed a component by the root its render describes
#                            - Read the live visible: of a root it hides, so the root shows again
#                            - Applied UI.patch to every render, put the parts they add to old screens there,
#                              and named the exposed values when one is read that is not
#                            - Placed each root by its placement params, also as its live values are read again, a dialog
#                              over the window that opened it, and kept a popover out of the part it lies in, opened and
#                              closed by itself
#                            - Closed the dialogs a window opened with it, wherever they sit
#                            - Named the jump keys of the device the player used last in the key help
#                            - Gave a component's window the hotkey its class declares
#                            - Ran a part's on_submit for the pick of a list inside it that C# sent up to it
#                            - Opened a part's context menu where C#'s tree tells, its pick running the choice's on_click and
#                              a right click cancelling it
#                            - Named the jump keys in the key help of a window whose list has other parts around it
#                            - Ran a part's on_button for the game's extra button C#'s tree told it, and named the buttons
#                              the parts in view take in the key help
#                            - Gave each key_help the hotkeys the parts in view in its window declare as it opens and every 4
#                              frames
#                            - Asked a part's handler that may refuse what it tells, and let a built-in follow its params
#                              after each render, as a window has cancel ask its on_cancel
#                            - Rendered a component again with the places of its parts noted, for UI.dump
#                            - Matched siblings that share a key in order and named the key in the log
#                            - Put a param its caller leaves out back to its default
#                            - Rendered a component again when its caller gives it a content param
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Runs the new UI layer each frame: it asks what may have changed, renders the dirty
      # components parents first, matches what they describe with what they described before by
      # type and key, and hands only the differences to the engine's parts.
      module Layer
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # The most renders of one component in one frame; past that it waits for the next frame.
        MOST_RENDERS = 3

        # The most siblings of one type before a hint to use a list.
        MANY_PARTS = 50

        # The params every part takes that a component hands to the parts at the top of its render;
        # id:, class: and key: stay its own.
        PASSED_COMMON = Declarations::COMMON.keys - [:id, :class, :key]

        # What the key help says the jump keys do.
        JUMP_TEXT = "Leave the list"

        # How the key help names the arrows after the jump key.
        ARROW_WORD = "arrows"

        # How the key help names the jump keys of a gamepad: the game's A button held with the d-pad.
        PAD_JUMP_KEYS = "Hold A + D-pad"

        # What the key help reads where a part names no buttons or keys, made once.
        NO_ENTRIES = [].freeze
        NO_BUTTONS = {}.freeze

        # The names of the game's cancel button a key help entry may give.
        CANCEL_BUTTONS = [:B, :b, "B", "b"].freeze

        # Frames between two reads of the live values, for a root UI.open opened and one UI.show
        # shows.
        LIVE_EVERY = { :open => 4, :show => 2 }

        # A component in the tree: the component, the node that placed it, and the parts and
        # components it rendered.
        class Mount
          # @return [Component] The component.
          attr_accessor :component

          # @return [Node, nil] The node its parent rendered for it, nil at the top.
          attr_accessor :node

          # @return [Array] The parts and components its last render described.
          attr_accessor :children

          # @return [Mount, Part, nil] What it lies in.
          attr_accessor :parent

          # @return [Integer] How deep it lies, 0 at the top.
          attr_accessor :depth

          # @return [Top] The root it lies in.
          attr_accessor :top

          # @return [Array] Who it is among its siblings.
          attr_accessor :identity

          # @return [Boolean] Whether it left the tree.
          attr_accessor :gone

          # @return [Boolean] Whether it waits to render.
          attr_accessor :dirty

          # @return [Boolean] Whether it waits out of sight to render, see put_behind.
          attr_accessor :behind

          # @return [Boolean] Whether it rendered once.
          attr_accessor :rendered

          # @return [Integer] The frame of its last render.
          attr_accessor :rendered_in

          # @return [Integer] Its renders in that frame.
          attr_accessor :renders

          # @return [Hash] The serials its last render read, with their counts then.
          attr_accessor :reads

          # @return [Array] The last answer of each of its watches.
          attr_accessor :watched
        end

        # A built-in in the tree: the node, the engine's part made for it and the parts it holds.
        class Part
          # @return [Node] The node it was last rendered from.
          attr_accessor :node

          # @return [Engine::Component] The engine's part.
          attr_accessor :engine

          # @return [Hash] The engine's options last set.
          attr_accessor :options

          # @return [Array] The parts and components it holds.
          attr_accessor :children

          # @return [Mount, Part, nil] What it lies in.
          attr_accessor :parent

          # @return [Integer] How deep it lies.
          attr_accessor :depth

          # @return [Top] The root it lies in.
          attr_accessor :top

          # @return [Array] Who it is among its siblings.
          attr_accessor :identity

          # @return [Boolean] Whether it left the tree.
          attr_accessor :gone

          # @return [Boolean] Whether a param of it is live.
          attr_accessor :live

          # @return [Array] A list's items.
          attr_accessor :items

          # @return [Integer, nil] A list's last row.
          attr_accessor :index

          # @return [Object, nil] What a root lies beside: a finder of its selector or a place.
          attr_accessor :beside

          # @return [Boolean] Whether a popover's open: or bound state asked for it last.
          attr_accessor :open_wanted

          # @return [Array, nil] A copy of its pulse: value as it was last read, in an Array so nil
          #   counts too; nil before the first read.
          attr_accessor :pulse_seen

          # @return [String, nil] The error an input shows under it, nil for none.
          attr_accessor :error

          # @return [Label, nil] The label of the error under an input's column, nil before its first error.
          attr_accessor :error_label

          # @return [Proc, nil] A tooltip's block that fills the box with its content, kept so the same block stays set.
          attr_accessor :tip

          # @return [Proc, nil] The block that puts its note into a tooltip's box, kept so the same block stays set.
          attr_accessor :note_block

          # @return [Proc, nil] The block that puts the markup of a slot's or a line's tooltip into a tooltip's box, kept so the
          #   same block stays set.
          attr_accessor :tips_block

          # @return [Array, nil] The completions a text field shows now.
          attr_accessor :completions

          # @return [Hash, nil] The engine parts its submit_to: names, by the param, nil for none.
          attr_accessor :links

          # @return [Engine::Component, nil] The list or the log a text field or a select steers.
          attr_accessor :steered

          # @return [Array, nil] A table's sort: as its owner gave it last, in an Array so nil counts too.
          attr_accessor :sort_given

          # @return [Array, nil] A popover's open: as its owner gave it last, in an Array so nil counts too.
          attr_accessor :open_given

          # @return [Array, nil] An input's value: as its owner gave it last, in an Array so nil counts too.
          attr_accessor :value_given

          # @return [Boolean, nil] Whether it brings the components behind it into sight as it comes into sight.
          attr_accessor :sight_followed
        end

        # A component UI.open opened or UI.show shows.
        class Top
          # @return [Mount] Its component.
          attr_accessor :mount

          # @return [Symbol] :open or :show.
          attr_accessor :kind

          # @return [Proc, nil] UI.open's block.
          attr_accessor :block

          # @return [Object] The value close gave.
          attr_accessor :value

          # @return [Part, nil] Its root part.
          attr_accessor :root

          # @return [String] Its id, or the mod and the class.
          attr_accessor :id

          # @return [Object] The handle UI.open or UI.show answered.
          attr_accessor :handle

          # @return [Boolean] Whether it closed.
          attr_accessor :closed

          # @return [String, nil] Where the mod opened or showed it, such as "Camp_Notes.rb:40".
          attr_accessor :site

          # @return [Component, nil] The engine's root of the window or dialog whose handler or render
          #   opened it, which a dialog without a zone sits over and closes with.
          attr_accessor :opener

          # Tells the frames between two reads of its live values.
          #
          # @return [Integer] The frames.
          def live_every
            LIVE_EVERY[@kind]
          end

          # Tells whether it shows now.
          #
          # @return [Boolean] Whether its root is open and not hidden.
          def shown?
            !@closed && !@root.nil? && @root.engine.shown?
          end
        end

        @tops = []
        @by_id = {}
        @mounted = []
        @dirty = []
        @mounting = []
        @rendering = []
        @handling = []
        @frame = 0
        @applying = false
        @key_helps = []
        @key_labels = {}
        @key_focus = nil
        @steers = []
        @links = []
        @after_render = []
        @busy = 0

        # Why the last start opened nothing, nil after one that opened.
        @refusal = nil

        # Opens or shows a component: makes it, renders it and opens its root.
        #
        # @param kind [Symbol] :open or :show, or :any for whichever the root its render describes
        #   needs.
        # @param klass [Class] The component's class.
        # @param params [Hash] Its params.
        # @param block [Proc, nil] UI.open's block.
        # @return [Top, nil] The top, nil when it did not open.
        def self.start(kind, klass, params, block)
          @refusal = nil
          node = Node.new(klass, nil, klass.take_params([params]), nil)
          top = Top.new
          top.kind = kind
          top.block = block
          top.site = Errors.site(caller)
          top.opener = opener_now if kind == :open
          mount = new_mount(node, nil, top)
          top.mount = mount
          return refuse(top, nil) unless render_mount(mount)

          root = top_root(top)
          return refuse(top, nil) unless root

          top.kind = root.node.declaration.root
          top.root = root
          resolve_steers
          resolve_links
          top.id = (root.node.params[:id] || "#{Errors.mod(caller)}/#{klass.name}").to_s
          same = @by_id[top.id]
          if same && !same.closed
            teardown(top)
            same.root.engine.focus
            return same
          end
          root.engine.open
          if top.closed
            @refusal = "it closed as it opened"
            return nil
          end

          waits = Scenes.waiting?(root.engine)
          return refuse(top, "it did not open") unless root.engine.open? || waits

          @key_helps.each { |part| refresh_key_help(part) if part.top.equal?(top) }

          @tops << top
          @by_id[top.id] = top
          log("#{root.node.type} #{top.id} #{waits ? 'waits for its menu scene' : 'opened'} (#{klass.name})")
          mount.watched = first_watches(mount)
          @mounting << mount
          @refusal = nil
          top
        end

        # Asks what may have changed and renders what did, before the engine draws the frame.
        def self.frame
          return if @tops.empty? && @dirty.empty? && @after_render.empty? && !Patches.busy?

          @busy += 1
          begin
            @frame += 1
            tell_mounted
            look_for_changes
            render_dirty
            read_live_values
            run_after_render
            follow_key_helps if (@frame % LIVE_EVERY[:open]).zero? || !Tree.focused.equal?(@key_focus)
            Patches.after_frame
          ensure
            @busy -= 1
          end
        rescue => e
          log_once([:frame, e.class], "the frame of the UI layer FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Tells the engine's root of the open window or dialog whose handler or render runs now, which
        # a dialog opened now sits over and closes with; a dialog a frame hook, a timer or another
        # mod opens has none.
        #
        # @return [Component, nil] The root, nil for none.
        def self.opener_now
          owner = @handling.last || @rendering.last
          mount = owner.is_a?(UI::Component) ? owner.__send__(:__mount) : nil
          top = mount && mount.top
          top && top.kind == :open && top.shown? ? top.root.engine : nil
        end
        private_class_method :opener_now

        # Tells the engine's root of the window or dialog whose handler or render opened the top a
        # component lies in, such as the window a dialog with cover: takes the place of.
        #
        # @param component [UI::Component] The component.
        # @return [Component, nil] The root, nil for none.
        def self.opener_of(component)
          mount = component.__send__(:__mount)
          mount && mount.top ? mount.top.opener : nil
        end

        # Runs a block once the next frame of the layer rendered what changed, such as a pulse of
        # parts that a change makes anew.
        #
        # @yield Runs then.
        def self.after_render(&block)
          @after_render << block
        end

        # Runs the blocks after_render took, each once; one that fails is logged.
        def self.run_after_render
          return if @after_render.empty?

          blocks = @after_render
          @after_render = []
          blocks.each do |block|
            begin
              block.call
            rescue => e
              log_once([:after_render, e.class], "a block after the render FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
            end
          end
        end
        private_class_method :run_after_render

        # Tells the engine part that stands for a part or a component: its own, or the first one a
        # component rendered.
        #
        # @param item [Part, Mount] The part or the component.
        # @return [Engine::Component, nil] The engine part, nil for none.
        def self.engine_of(item)
          item.is_a?(Part) ? item.engine : engine_parts(item.children, []).first
        end

        # Takes a popover's close: its on_close with why, and its bound state turned false.
        #
        # @param part [Part] The popover's part.
        # @param why [Symbol] Why it closed.
        def self.popover_closed(part, why)
          part.open_wanted = false
          bind = part.node.params[:bind]
          write_bound(part.node.owner, bind, false) if bind && !part.gone
          call_handler(part.node.owner, part.node.params[:on_close], [why]) unless part.gone
        end

        # Forgets every component, as F12 starts the game again.
        def self.reset
          @tops.dup.each { |top| top.closed = true }
          @tops = []
          @by_id = {}
          @mounted = []
          @dirty = []
          @mounting = []
          @rendering = []
          @handling = []
          @key_helps = []
          @key_labels = {}
          @key_focus = nil
          @steers = []
          @links = []
          @after_render = []
          Patches.reset
        end

        # Has a key_help add the keys of the part in focus and of the parts it lies in, followed as the
        # focus moves and every 4 frames while its window is open.
        #
        # @param part [Part] The key_help's part.
        def self.follow_key_help(part)
          @key_helps << part unless @key_helps.include?(part)
          refresh_key_help(part)
        end

        # Tells the tops open or shown, for tests.
        #
        # @return [Array<Top>] The tops.
        def self.tops
          @tops
        end

        # Has every component of a top render again at the end of the frame, such as after a
        # UI.patch came or went.
        #
        # @param top [Top] The top.
        def self.render_all(top)
          each_mount(top.mount) { |mount| mark_dirty(mount.component) }
        end

        # Runs a handler with as many of the values as it takes, without rendering its owner again or
        # catching what it raises, as a handler a patch wraps runs the owner's.
        #
        # @param owner [Object] Who wrote the handler.
        # @param handler [Proc, Symbol, nil] The handler.
        # @param values [Array] What the event tells.
        # @return [Object] What the handler answered, nil for none.
        def self.invoke(owner, handler, values)
          return nil if handler.nil?
          return close(owner, nil, :button) if handler == :close && owner.is_a?(UI::Component)
          return owner.__send__(handler, *cut(owner.method(handler).arity, values)) if handler.is_a?(Symbol)

          handler.call(*cut(handler.arity, values))
        end

        # Matches the parts a patch adds to an old screen with those it added before, and puts their
        # engine parts there.
        #
        # @param holder [Patches::Graft] What holds them.
        # @param nodes [Array<Node>] The parts now.
        def self.graft(holder, nodes)
          holder.children = reconcile(holder, holder.children, nodes)
          sync_engine(holder)
        end

        # Takes the parts a patch added to an old screen out of the tree.
        #
        # @param holder [Patches::Graft] What holds them.
        def self.drop_graft(holder)
          holder.children.each { |child| destroy(child) }
          holder.children = []
          holder.gone = true
        end

        # Collects the engine's parts of parts and components, see engine_parts.
        #
        # @param list [Array] The parts and components.
        # @return [Array] The engine's parts.
        def self.engines_of(list)
          engine_parts(list, [])
        end

        # Reads the live params of parts again, such as those a patch added to an old screen.
        #
        # @param list [Array] The parts and components.
        def self.refresh_live_of(list)
          refresh_live(list)
        end

        # Hands every component below a mount to a block, the mount first.
        #
        # @param mount [Mount] The mount.
        # @yieldparam mount [Mount] A component's mount.
        def self.each_mount(item, &block)
          block.call(item) if item.is_a?(Mount)
          item.children.each { |child| each_mount(child, &block) }
        end
        private_class_method :each_mount

        # Writes a component's state and renders it again at the end of the frame when it changed.
        #
        # @param component [Component] The component.
        # @param name [Symbol] The state.
        # @param value [Object] Its value, frozen as it is kept.
        # @return [Object] The value kept.
        # @raise [MarkupError] A render runs.
        def self.write_state(component, name, value)
          unless @rendering.empty?
            raise MarkupError, Errors.placed("#{component.class.name} writes state :#{name} inside render; write it in a handler, in setup or after a watch", caller)
          end

          state = component.__send__(:__state)
          old = state[name]
          value = frozen(value)
          return value if old.equal?(value) || old == value

          state[name] = value
          mark_dirty(component)
          value
        end

        # Freezes an Array, a Hash or a String one level deep, as state keeps them.
        #
        # @param value [Object] The value.
        # @return [Object] A frozen copy, or the value itself.
        def self.frozen(value)
          return value if value.frozen? || !(value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(String))

          value.dup.freeze
        end

        # Has a component render again at the end of the frame.
        #
        # @param component [Component] The component.
        def self.mark_dirty(component)
          mount = component.__send__(:__mount)
          return if mount.nil? || mount.gone || mount.dirty

          mount.dirty = true
          @dirty << mount
        end

        # Runs a component's on_ handler for an event it emits.
        #
        # @param component [Component] The component.
        # @param name [Symbol] The event.
        # @param values [Array] What it tells.
        def self.emit(component, name, values)
          handler = component.__send__(:__params)[:"on_#{name}"]
          mount = component.__send__(:__mount)
          call_handler(mount && mount.node ? mount.node.owner : nil, handler, values)
          nil
        end

        # Runs a part's handler for an event of its engine part; a handler :submit sends the form the
        # part lies in.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The handler's param, such as :on_click.
        # @param values [Array] What the event tells.
        def self.dispatch(part, name, values)
          return if part.gone

          handler = part.node.params[name]
          return slide_step(part, name, handler) if handler == :forward || handler == :back
          return submit_around(part) if handler == :submit

          call_handler(part.node.owner, handler, values)
        end

        # Slides the nearest slides around a part a page on or back, as the keys do, with the
        # buzzer for a slide refused; a handler :forward or :back runs it.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The handler's param, such as :on_click.
        # @param handler [Symbol] :forward or :back.
        def self.slide_step(part, name, handler)
          slides = part.parent
          slides = slides.parent until slides.nil? || (slides.is_a?(Part) && slides.node.type == :slides)
          unless slides
            return Errors.hint([:slide_step, part.node.owner.class, part.node.type], nil,
                               "#{part.node.type} has #{name}: :#{handler}, which slides the slides it lies in, but it lies in none")
          end

          handler == :forward ? slides.engine.receive("slide", 1) : slides.engine.receive("back")
        end
        private_class_method :slide_step

        # Slides the first slides a component's last render made a page on or back, as the keys do,
        # logging a component that rendered none.
        #
        # @param component [Component] The component.
        # @param step [Symbol] :forward or :back.
        # @return [nil] Always.
        def self.slide_own(component, step)
          mount = component.__send__(:__mount)
          slides = mount && own_part_of_type(mount, component, :slides)
          unless slides
            Errors.hint([:slide_own, component.class, step], nil, "#{component.class.name}##{step} slides the slides its render made, but it made none")
            return nil
          end

          step == :forward ? slides.engine.receive("slide", 1) : slides.engine.receive("back")
          nil
        end

        # Finds the first part of a type a component rendered itself, also inside the parts it holds
        # but not inside the components it holds.
        #
        # @param item [Part, Mount] Where to look.
        # @param owner [UI::Component] The component.
        # @param type [Symbol] The part's markup name.
        # @return [Part, nil] The part, nil for none.
        def self.own_part_of_type(item, owner, type)
          return item if item.is_a?(Part) && item.node.owner.equal?(owner) && item.node.type == type && !item.gone

          item.children.each do |child|
            next if child.is_a?(Mount) && !child.equal?(item)

            found = own_part_of_type(child, owner, type)
            return found if found
          end
          nil
        end
        private_class_method :own_part_of_type

        # Runs a part's on_submit for the pick of a list inside it that C#'s tree sent up to it, with
        # the list's item.
        #
        # @param part [Part] The part.
        # @param row [Integer] The row picked.
        # @param node [Integer] The list's node in C#'s tree.
        def self.submit_up(part, row, node)
          list = Tree.component(node)
          found = list && part_of(part, list)
          dispatch(part, :on_submit, [item_at(found, row.to_i)]) if found
        end

        # Finds the layer's part of an engine part among what a part holds.
        #
        # @param item [Part, Mount] Where to look.
        # @param engine [Engine::Component] The engine part.
        # @return [Part, nil] The part, nil for none.
        def self.part_of(item, engine)
          return item if item.is_a?(Part) && item.engine.equal?(engine)

          item.children.each do |child|
            found = part_of(child, engine)
            return found if found
          end
          nil
        end
        private_class_method :part_of

        # Opens a part's context menu at a spot: the choices its built-in offers itself
        # (:context_choices, such as Remove on a closeable chip), then its context_menu: choices, read
        # anew from a lambda, in a menu of UI.menu, and a pick runs the choice's on_click; a right
        # click cancels it, as in the window below. A button keeps its look while its menu is open.
        #
        # @param part [Part] The part.
        # @param x [Integer] The menu's left on the screen.
        # @param y [Integer] Where its bottom goes, at the pointer or under the focused part.
        def self.open_context(part, x, y)
          return if part.gone

          given = part.node.params[:context_menu]
          own = part.node.declaration.spec[:context_choices]
          choices = (own ? own.call(part) : []) + Array(given.is_a?(Proc) ? read_live(part, :context_menu, given) : given)
          return log("the context menu of #{part.node.type} has no choices") if choices.empty?

          rows = choices.map do |choice|
            next { :text => choice.to_s } unless choice.is_a?(Hash)

            row = { :text => choice[:text].to_s, :disabled => choice[:disabled] == true }
            row[:tooltip] = choice[:tooltip].to_s if choice[:tooltip]
            row
          end
          Menus.open(rows, :at => [x.to_i, y.to_i], :context => true, :from => part.engine) do |_row, index|
            choice = index ? choices[index] : nil
            call_handler(part.node.owner, choice[:on_click], []) if choice.is_a?(Hash) && !part.gone
          end
        end

        # Runs a part's on_button handler for one of the game's extra buttons C#'s tree told it.
        #
        # @param part [Part] The part.
        # @param name [String] The button, such as "Z".
        def self.press_button(part, name)
          return if part.gone

          handlers = part.node.params[:on_button] || {}
          call_handler(part.node.owner, handlers[name.to_s.downcase.to_sym], [])
        end

        # Asks a part's handler that may refuse what its event tells, such as a window's on_cancel.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The handler's param, such as :on_cancel.
        # @param values [Array] What the event tells.
        # @return [Boolean] False when the handler answered false, true otherwise.
        def self.ask(part, name, values = [])
          return true if part.gone

          call_handler(part.node.owner, part.node.params[name], values) != false
        end

        # Closes the root a component lies in, with a value for UI.open's block.
        #
        # @param component [Component] The component.
        # @param value [Object] The value.
        # @param why [Symbol] The reason, :script or :button.
        def self.close(component, value, why)
          mount = component.__send__(:__mount)
          top = mount && mount.top
          return nil unless top && !top.closed && top.root

          top.value = value
          top.root.engine.close(why)
          nil
        end

        # Hides a component UI.show shows, or closes one UI.open opened.
        #
        # @param top [Top] Its top.
        # @param value [Object] The value for UI.open's block.
        # @param at_once [Boolean] Whether it leaves at once, without its leave motion, also one that
        #   is leaving already.
        def self.close_top(top, value, at_once = false)
          return Tree.end_fade(top.root.engine) if at_once && top.closed && top.root
          return if top.closed || top.root.nil?

          top.value = value
          top.root.engine.close(:script, at_once)
        end

        # Closes the dialogs a closing window or dialog opened, wherever they sit, with the reason
        # :script.
        #
        # @param engine [Component] The engine's root that closed.
        def self.close_dialogs_of(engine)
          opened = @tops.select { |each| !each.closed && each.opener.equal?(engine) && each.root && each.root.node.type == :dialog }
          opened.each { |each| each.root.engine.close(:script) }
        end
        private_class_method :close_dialogs_of

        # Takes a root's close: its on_close, its components leaving, the dialogs it opened, and
        # UI.open's block.
        #
        # @param part [Part] The root's part.
        # @param why [Symbol, String] Why it closed.
        def self.root_closed(part, why)
          top = part.top
          return if top.nil? || top.closed || !top.root.equal?(part)

          top.closed = true
          log("#{part.node.type} #{top.id} closed: #{why}")
          call_handler(part.node.owner, part.node.params[:on_close], [why], false)
          teardown(top)
          close_dialogs_of(part.engine)
          return unless top.kind == :open && top.block

          begin
            top.block.call(*cut(top.block.arity, [top.value, why]))
          rescue => e
            Errors.report(e, "the block of UI.open for #{top.mount.component.class.name}")
          end
        end

        # Runs a root's on_gone once nothing of it shows any more, after it closed and left the tree.
        #
        # @param part [Part] The root's part.
        def self.root_gone(part)
          call_handler(part.node.owner, part.node.params[:on_gone], [], false)
        end

        # Tells the mod a part or a component belongs to: a part to the mod of the component that
        # wrote it, a component to the mod that defined its class.
        #
        # @param item [Part, Mount] The part or the component.
        # @return [String] The mod's name.
        def self.mod_of(item)
          owner = item.is_a?(Mount) ? item.component : item.node.owner
          mod_of_owner(owner) || "a script outside the mods"
        end

        # Tells the mod of whoever wrote a part: a component's class's mod, or for the module of a
        # mod's UI.patch block the mod it names.
        #
        # @param owner [Object] Whoever wrote it.
        # @return [String, nil] The mod's name, nil for none.
        def self.mod_of_owner(owner)
          return owner.name.to_s.split("::").first.tr("_", " ") if owner.is_a?(Module) && owner.name && !owner.name.empty?

          Scopes.mod_of(owner.class)
        end

        # Tells the item of a list's row.
        #
        # @param part [Part] The list's part.
        # @param index [Integer, nil] The row's place.
        # @return [Object, nil] The item, nil for none.
        def self.item_at(part, index)
          index && index >= 0 ? Array(part.items)[index] : nil
        end

        # Takes a list's cursor move: the bound state follows and on_change hears the item.
        #
        # @param part [Part] The list's part.
        # @param index [Integer, nil] The row the cursor moved to.
        def self.list_moved(part, index)
          return if @applying || part.gone

          part.index = index
          item = item_at(part, index)
          params = part.node.params
          owner = part.node.owner
          write_bound(owner, params[:bind], item) if params[:bind]
          write_bound(owner, params[:bind_index], index) if params[:bind_index]
          call_handler(owner, params[:on_change], [item])
        end

        # Tells a value another mod's UI.patch block may read.
        #
        # @param component [Component] The component.
        # @param name [Symbol] The value.
        # @return [Object] The value.
        # @raise [MarkupError] The component exposes no value of that name.
        def self.exposed(component, name)
          exposes = component.class.exposes
          unless exposes.key?(name)
            near = Declarations.nearest(name, exposes.keys)
            names = exposes.empty? ? "; it exposes nothing" : "; it exposes #{exposes.keys.join(', ')}"
            raise MarkupError, "#{component.class.name} exposes no #{name}#{near ? "; did you mean #{near}?" : ''}#{names}"
          end

          block = exposes[name]
          block ? component.instance_exec(&block) : component.__send__(name)
        end

        # Makes a component and the mount that holds it.
        #
        # @param node [Node] Its node.
        # @param parent [Mount, Part, nil] What it lies in.
        # @param top [Top] Its root.
        # @return [Mount] The mount.
        def self.new_mount(node, parent, top)
          mount = Mount.new
          mount.node = node
          mount.parent = parent
          mount.depth = parent ? parent.depth + 1 : 0
          mount.top = top
          mount.children = []
          node.mount = mount
          mount.component = instantiate(node.type, node.params, node.block, mount)
          @mounted << mount
          begin
            mount.component.setup
          rescue => e
            Errors.report(e, "#{node.type.name}'s setup")
          end
          mount
        end
        private_class_method :new_mount

        # Makes a component with its params and its state.
        #
        # @param klass [Class] The component's class.
        # @param given [Hash] The params its caller gave.
        # @param block [Proc, nil] Its caller's block.
        # @param mount [Mount] Its mount.
        # @return [Component] The component.
        def self.instantiate(klass, given, block, mount)
          component = klass.allocate
          params = given.dup
          component.__send__(:__mount=, mount)
          component.__send__(:__block=, block)
          component.__send__(:__params=, params)
          klass.params.each { |name, param| params[name] = param_default(component, param) unless params.key?(name) }
          state = {}
          component.__send__(:__state=, state)
          klass.states.each { |name, each| state[name] = frozen(each[:block] ? component.instance_exec(&each[:block]) : each[:default]) }
          component
        end
        private_class_method :instantiate

        # Makes a param's default for a component.
        #
        # @param component [Component] The component.
        # @param param [Hash] The param's declaration.
        # @return [Object] A fresh value from its block, its default, or nil.
        def self.param_default(component, param)
          return component.instance_exec(&param[:block]) if param[:block]

          param[:default].equal?(UI::Component::NONE) ? nil : param[:default]
        end
        private_class_method :param_default

        # Renders a component and matches what it describes with its last tree. A render that
        # raises keeps the last tree.
        #
        # @param mount [Mount] The component's mount.
        # @param sync [Boolean] Whether it puts what it rendered into its host at once; a component
        #   rendered while its host matches its own parts leaves that to the host.
        # @return [Boolean] Whether it rendered.
        def self.render_mount(mount, sync = true)
          component = mount.component
          mount.dirty = false
          mount.behind = false
          first = !mount.rendered
          reads = {}
          nodes = nil
          @busy += 1
          @rendering.push(component)
          begin
            Serials.record(reads) { nodes = Builder.capture(first) { component.render } }
          rescue StandardError => e
            report_render(component, e)
            return false
          ensure
            @rendering.pop
          end
          component.__send__(:__memos_rendered)
          return false if mount.parent.nil? && !top_fits?(mount, nodes)

          hand_down_common(mount, nodes)
          nodes = Patches.render(mount, nodes)
          mount.reads = reads
          mount.rendered = true
          hint_loops(component, nodes) if first
          mount.children = reconcile(mount, mount.children, nodes)
          sync_host(mount) if sync
          true
        ensure
          @busy -= 1
        end
        private_class_method :render_mount

        # Tells whether a component that rendered before lies out of sight, such as on a page slides
        # keep out of view or in a tab not picked.
        #
        # @param mount [Mount] The component's mount.
        # @return [Boolean] Whether it does.
        def self.out_of_sight?(mount)
          return false unless mount.rendered

          host = host_of(mount)
          host ? host.engine.out_of_sight? : false
        end
        private_class_method :out_of_sight?

        # Has a component out of sight render only once it comes into sight; a page out of view would
        # otherwise render everything it shows on every change, such as on every cursor move.
        #
        # @param mount [Mount] The component's mount.
        def self.put_behind(mount)
          mount.dirty = true
          mount.behind = true
          host = host_of(mount)
          return if host.sight_followed

          host.sight_followed = true
          host.engine.on(:sight) { bring_into_sight(host) }
        end
        private_class_method :put_behind

        # Renders the components that waited out of sight in a part that came into sight, at once
        # unless a render or the frame's work runs, which then renders them.
        #
        # @param part [Part] The part.
        def self.bring_into_sight(part)
          return if part.gone

          waiting = behind_in(part.children, [])
          return if waiting.empty?

          waiting.each { |mount| @dirty << mount }
          render_dirty if @busy.zero?
        end
        private_class_method :bring_into_sight

        # Collects the components that wait out of sight among parts and components, not inside the
        # parts they hold, which tell their own.
        #
        # @param list [Array] The parts and components.
        # @param into [Array<Mount>] Where they go.
        # @return [Array<Mount>] The mounts.
        def self.behind_in(list, into)
          list.each do |each|
            next unless each.is_a?(Mount)

            each.behind ? into << each : behind_in(each.children, into)
          end
          into
        end
        private_class_method :behind_in

        # Hands the params every part takes that a component's caller gave it, besides those it
        # declares itself, to the parts at the top of its render, the caller's value winning.
        #
        # @param mount [Mount] The component's mount.
        # @param nodes [Array<Node>] What its render described.
        def self.hand_down_common(mount, nodes)
          given = mount.node.params
          own = mount.component.class.params
          handed = PASSED_COMMON.select { |name| !own.key?(name) && !given[name].nil? }
          return if handed.empty?

          nodes.each do |node|
            declared = node.component? ? node.type.declaration.params : node.declaration.params
            handed.each { |name| node.params[name] = given[name] if declared.key?(name) && !(node.component? && node.type.params.key?(name)) }
          end
        end
        private_class_method :hand_down_common

        # Matches the nodes a render described with the parts and components described before, by
        # type and key, or by place among siblings of their type without a key. Siblings that share
        # a key are matched in order.
        #
        # @param parent [Mount, Part] What they lie in.
        # @param old [Array] What was described before.
        # @param nodes [Array<Node>] What is described now.
        # @return [Array] The parts and components now.
        def self.reconcile(parent, old, nodes)
          by_identity = {}
          old.each { |each| (by_identity[each.identity] ||= []) << each }
          counts = {}
          taken = {}
          now = nodes.map do |node|
            identity = identity_of(node, counts)
            hint_shared_key(parent, node, identity) if taken[identity]
            taken[identity] = true
            found = by_identity[identity] && by_identity[identity].shift
            found = found ? update(found, node) : create(node, parent)
            found.identity = identity
            found
          end
          by_identity.each_value { |left| left.each { |each| destroy(each) } }
          hint_many(parent, counts) if nodes.size > MANY_PARTS
          now
        end
        private_class_method :reconcile

        # Logs siblings that share a key, once.
        #
        # @param parent [Mount, Part] What they lie in.
        # @param node [Node] The second of them.
        # @param identity [Array] Their type and key.
        def self.hint_shared_key(parent, node, identity)
          owner = parent.is_a?(Mount) ? parent.component.class.name : parent.node.owner.class.name
          type = node.component? ? node.type.markup_name : node.type
          Errors.hint([:shared_key, owner, identity], nil, "#{owner} gives several #{type} parts the key #{identity.last.inspect}; give each one a key of its own, so each keeps its state when the parts change")
        end
        private_class_method :hint_shared_key

        # Tells who a node is among its siblings.
        #
        # @param node [Node] The node.
        # @param counts [Hash] The siblings without a key counted so far, by type.
        # @return [Array] Its type and key, or its type and place among those without a key.
        def self.identity_of(node, counts)
          key = node.key.nil? ? node.params[:id] : node.key
          return [node.type, :key, key] unless key.nil?

          place = counts[node.type].to_i
          counts[node.type] = place + 1
          [node.type, :place, place]
        end
        private_class_method :identity_of

        # Makes what a node describes.
        #
        # @param node [Node] The node.
        # @param parent [Mount, Part] What it lies in.
        # @return [Mount, Part] The component's mount or the built-in's part.
        def self.create(node, parent)
          return create_part(node, parent) unless node.component?

          mount = new_mount(node, parent, parent.top)
          render_mount(mount, false)
          mount.watched = first_watches(mount)
          @mounting << mount
          mount
        end
        private_class_method :create

        # Makes a built-in's part and the engine's part for it.
        #
        # @param node [Node] The node.
        # @param parent [Mount, Part] What it lies in.
        # @return [Part] The part.
        def self.create_part(node, parent)
          spec = node.declaration.spec
          part = Part.new
          part.node = node
          part.parent = parent
          part.depth = parent.depth + 1
          part.top = parent.top
          read = read_params(part)
          part.options = Placement.apply(part, with_class_hotkey(part, spec[:options].call(read)), read)
          part.engine = spec[:make].call(part.options)
          follow_pulse(part, read)
          follow_links(part)
          part.engine.layer_part = true unless spec[:kept]
          spec[:wire].call(part) if spec[:wire]
          Builtins.wire_context(part) unless spec[:kept]
          spec[:follow].call(part) if spec[:follow]
          part.children = reconcile(part, [], node.children)
          sync_engine(part)
          bind_list(part) if node.type == :list
          spec[:synced].call(part) if spec[:synced]
          part
        end
        private_class_method :create_part

        # Takes a node for what was described before in its place.
        #
        # @param found [Mount, Part] What was described before.
        # @param node [Node] The node now.
        # @return [Mount, Part] The same mount or part.
        def self.update(found, node)
          found.is_a?(Mount) ? update_mount(found, node) : update_part(found, node)
          found
        end
        private_class_method :update

        # Gives a component its new params, and puts those its caller left out back to their
        # defaults; it renders again when one changed, leaving lambdas out, when its caller gave it a
        # block or a content param, or when it waits to render.
        #
        # @param mount [Mount] The component's mount.
        # @param node [Node] Its node now.
        def self.update_mount(mount, node)
          old = mount.node
          mount.node = node
          node.mount = mount
          component = mount.component
          component.__send__(:__block=, node.block)
          params = component.__send__(:__params)
          changed = !node.block.nil? || gives_content?(node) || params_changed?(old.params, node.params)
          node.params.each { |name, value| params[name] = value }
          (old.params.keys - node.params.keys).each { |name| reset_param(component, params, name) }
          return unless changed || mount.dirty

          out_of_sight?(mount) ? put_behind(mount) : render_mount(mount, false)
        end
        private_class_method :update_mount

        # Puts a param its caller left out back to its default, or forgets a common one such as id:.
        #
        # @param component [Component] The component.
        # @param params [Hash] Its params.
        # @param name [Symbol] The param.
        def self.reset_param(component, params, name)
          param = component.class.params[name]
          if param
            params[name] = param_default(component, param)
          else
            params.delete(name)
          end
        end
        private_class_method :reset_param

        # Tells whether a caller gives a component markup in a content param.
        #
        # Such markup may read the caller's state, so it may show something new whenever the caller
        # renders.
        #
        # @param node [Node] The component's node.
        # @return [Boolean] Whether it does.
        def self.gives_content?(node)
          declared = node.type.params
          node.params.any? { |name, value| !value.nil? && declared[name] && declared[name][:content] }
        end
        private_class_method :gives_content?

        # Tells whether a component's params changed, leaving lambdas out.
        #
        # @param old [Hash] The params before.
        # @param now [Hash] The params now.
        # @return [Boolean] Whether one changed.
        def self.params_changed?(old, now)
          return true unless old.size == now.size

          now.each do |name, value|
            return true unless old.key?(name)
            next if value.is_a?(Proc)
            return true unless old[name] == value
          end
          false
        end
        private_class_method :params_changed?

        # Gives a part its new node: the engine's options that changed, then what it holds.
        #
        # @param part [Part] The part.
        # @param node [Node] Its node now.
        def self.update_part(part, node)
          part.node = node
          spec = node.declaration.spec
          read = read_params(part)
          set_options(part, Placement.apply(part, with_class_hotkey(part, spec[:options].call(read)), read))
          follow_pulse(part, read)
          follow_links(part)
          spec[:follow].call(part) if spec[:follow]
          part.children = reconcile(part, part.children, node.children)
          sync_engine(part)
          bind_list(part) if node.type == :list
          spec[:synced].call(part) if spec[:synced]
        end
        private_class_method :update_part

        # Gives the window or dialog at the top of a component the hotkey its class declares, unless
        # its hotkey: names one, so C#'s tree closes it by that hotkey and the key help names it.
        #
        # @param part [Part] The part.
        # @param options [Hash] Its engine options.
        # @return [Hash] The options.
        def self.with_class_hotkey(part, options)
          return options unless options[:declared_hotkey] == false && part.node.declaration.root == :open && part.top

          hotkey = part.top.mount.component.class.declared_hotkey
          hotkey ? options.merge(:declared_hotkey => hotkey) : options
        end
        private_class_method :with_class_hotkey

        # Pulses a part once, after the frame rendered, whenever its pulse: changed since it was last
        # read; not as it is made.
        #
        # @param part [Part] The part.
        # @param params [Hash] Its params, live values read.
        def self.follow_pulse(part, params)
          return unless params.key?(:pulse) || part.pulse_seen

          value = params[:pulse]
          changed = part.pulse_seen && part.pulse_seen != [value]
          part.pulse_seen = [snapshot(value)] if changed || !part.pulse_seen
          after_render { part.engine.pulse unless part.gone } if changed
        end
        private_class_method :follow_pulse

        # The levels of Arrays and Hashes inside each other a pulse: snapshot copies.
        SNAPSHOT_DEPTH = 4

        # Copies a value with the Arrays, Hashes and Strings inside it, so a value the mod changes in
        # place, such as an offer it adds an item to with <<, differs from the copy afterwards.
        #
        # @param value [Object] The value.
        # @param depth [Integer] The levels left to copy.
        # @return [Object] The copy.
        def self.snapshot(value, depth = SNAPSHOT_DEPTH)
          return value if depth <= 0

          case value
          when Array then value.map { |each| snapshot(each, depth - 1) }
          when Hash then value.each_with_object({}) { |(key, each), copy| copy[key] = snapshot(each, depth - 1) }
          when String then value.dup
          else value
          end
        end
        private_class_method :snapshot

        # Reads a part's params, calling the lambdas of its live params.
        #
        # @param part [Part] The part.
        # @return [Hash] The params with plain values.
        def self.read_params(part)
          params = part.node.params
          declared = part.node.declaration.params
          read = params
          live = false
          params.each do |name, value|
            next unless value.is_a?(Proc) && declared[name] && declared[name].live?

            read = params.dup if read.equal?(params)
            read[name] = read_live(part, name, value)
            live = true
          end
          part.live = live
          read
        end
        private_class_method :read_params

        # Reads a live value, logging a lambda that fails once.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The param.
        # @param lambda [Proc] Its lambda.
        # @return [Object, nil] Its answer, nil when it failed.
        def self.read_live(part, name, lambda)
          lambda.call
        rescue StandardError => e
          Errors.report(e, "the live #{name}: of #{part.node.type}")
          nil
        end
        private_class_method :read_live

        # Sets the engine's options that changed, and puts back the defaults of those left out.
        #
        # @param part [Part] The part.
        # @param options [Hash] The options now.
        def self.set_options(part, options)
          old = part.options
          engine = part.engine
          @applying = true
          options.each do |key, value|
            next if old.key?(key) && same_option?(old[key], value)

            key == :height && eases_height?(part, old[key], value) ? engine.animate({ :height => value }, :frames => HEIGHT_FRAMES) : engine.__send__("#{key}=", value)
          end
          old.each_key { |key| engine.__send__("#{key}=", engine.class.defaults[key]) unless options.key?(key) }
          part.options = options
        ensure
          @applying = false
        end
        private_class_method :set_options

        # Tells whether an option's value read again is the one set: equal, or colors of the same
        # values, also inside Arrays and Hashes, such as a background { color:, fade: }.
        #
        # A live part's colors are made anew at each read, and a color that differs only as an object
        # would draw the part anew at each read.
        #
        # @param old [Object] The value set.
        # @param now [Object] The value read again.
        # @return [Boolean] Whether they are the same.
        def self.same_option?(old, now)
          return true if old == now
          return [old.red, old.green, old.blue, old.alpha] == [now.red, now.green, now.blue, now.alpha] if old.is_a?(Color) && now.is_a?(Color)
          return old.size == now.size && old.zip(now).all? { |a, b| same_option?(a, b) } if old.is_a?(Array) && now.is_a?(Array)
          return false unless old.is_a?(Hash) && now.is_a?(Hash) && old.size == now.size

          old.all? { |key, value| now.key?(key) && same_option?(value, now[key]) }
        end
        private_class_method :same_option?

        # The frames over which a part of a hud eases to its new height.
        HEIGHT_FRAMES = 10

        # Tells whether a part eases to a new height instead of taking it at once: a part of a hud,
        # such as a strip that turns small, going from one height in pixels to another while its hud
        # shows, so the hud and what is docked beside it slide along.
        #
        # @param part [Part] The part.
        # @param from [Object] Its height before.
        # @param to [Object] Its height now.
        # @return [Boolean] Whether it eases.
        def self.eases_height?(part, from, to)
          root = part.top && part.top.root
          from.is_a?(Integer) && to.is_a?(Integer) && root && root.node.type == :hud && part.engine.rect ? true : false
        end
        private_class_method :eases_height?

        # Puts the engine's parts of what a part holds into its engine part, in order.
        #
        # @param part [Part] The part.
        def self.sync_engine(part)
          return part.sync_graft if part.respond_to?(:sync_graft)

          spec = part.node.declaration ? part.node.declaration.spec : {}
          return if spec[:kept]

          engine = part.engine
          wanted = engine_parts(part.children, [])
          @applying = true
          return spec[:sync].call(part, wanted) if spec[:sync]
          return if engine.children == wanted

          (engine.children - wanted).each { |child| engine.remove(child) }
          wanted.each_with_index { |child, place| engine.add(child, place) unless engine.children[place].equal?(child) }
        ensure
          @applying = false
        end
        private_class_method :sync_engine

        # Collects the engine's parts of parts and components, a component standing for what it
        # rendered; a popover is a root of its own and stays out.
        #
        # @param list [Array] The parts and components.
        # @param into [Array] Where they go.
        # @return [Array] The engine's parts.
        def self.engine_parts(list, into)
          list.each do |each|
            next engine_parts(each.children, into) unless each.is_a?(Part)

            into << each.engine unless detached?(each)
          end
          into
        end
        private_class_method :engine_parts

        # Puts what a component rendered into the part it lies in, or opens its new root.
        #
        # @param mount [Mount] The component's mount.
        def self.sync_host(mount)
          host = host_of(mount)
          return sync_engine(host) if host

          top = mount.top
          root = top_root(top)
          return if root.nil? || top.root.nil? || root.equal?(top.root)

          old = top.root
          top.root = root
          old.top = nil
          old.engine.close(:script)
          root.engine.open
        end
        private_class_method :sync_host

        # Tells the part a component's parts lie in: the nearest built-in around it.
        #
        # @param mount [Mount] The component's mount.
        # @return [Part, nil] The part, nil at the top.
        def self.host_of(mount)
          host = mount.parent
          host = host.parent while host && !host.is_a?(Part)
          host
        end
        private_class_method :host_of

        # Tells the root part of a top: the one built-in its component rendered at the top.
        #
        # @param top [Top] The top.
        # @return [Part, nil] The root's part, nil when the top rendered no single root of its kind.
        def self.top_root(top)
          parts = []
          collect_parts(top.mount.children, parts)
          root = parts.size == 1 ? parts.first : nil
          return nil unless root && root.node.declaration.root && [:any, root.node.declaration.root].include?(top.kind)

          root.top = top
          root
        end
        private_class_method :top_root

        # Collects the parts at the top of a list, a component standing for what it rendered.
        #
        # @param list [Array] The parts and components.
        # @param into [Array<Part>] Where they go.
        def self.collect_parts(list, into)
          list.each { |each| each.is_a?(Part) ? into << each : collect_parts(each.children, into) }
        end
        private_class_method :collect_parts

        # Checks what the top component of UI.open or UI.show rendered: one root of the kind that
        # call takes.
        #
        # @param mount [Mount] The top component's mount.
        # @param nodes [Array<Node>] What it rendered.
        # @return [Boolean] Whether it fits.
        def self.top_fits?(mount, nodes)
          kind = mount.top.kind
          node = nodes.size == 1 ? nodes.first : nil
          return true if node && (node.component? || node.declaration.root == kind || (kind == :any && node.declaration.root))

          name = mount.component.class.name
          fits = kind == :open ? "a window, a dialog or a wheel" : "a hud or a marker"
          other = node && !node.component? && node.declaration.root ? " #{node.type} goes to UI.#{node.declaration.root}." : ""
          @refusal = "its render describes no #{fits} at its top"
          Errors.hint([:top, name], nil, "UI.#{kind} takes a component whose render describes #{fits} at its top; #{name} described #{nodes.empty? ? 'nothing' : nodes.map { |each| each.component? ? each.type.markup_name : each.type }.join(', ')}.#{other}")
          false
        end
        private_class_method :top_fits?

        # Tells whether a part is a root of its own instead of a part of what it lies in, such as a
        # popover, or a drawer that lies over the rest.
        #
        # @param part [Part] The part.
        # @return [Boolean] Whether it is.
        def self.detached?(part)
          detached = part.node.declaration.spec[:detached]
          detached.is_a?(Proc) ? detached.call(part.node.params) : detached ? true : false
        end

        # Takes a part or a component out of the tree, and what it holds; a component's unmounted
        # runs.
        #
        # @param found [Mount, Part] What leaves.
        def self.destroy(found)
          found.gone = true
          found.children.each { |child| destroy(child) }
          found.engine.close(:script) if found.is_a?(Part) && detached?(found) && found.engine.open?
          return unless found.is_a?(Mount)

          @mounted.delete(found)
          begin
            found.component.unmounted
          rescue => e
            Errors.report(e, "#{found.component.class.name}'s unmounted")
          end
        end
        private_class_method :destroy

        # Takes a closed top's components out of the tree.
        #
        # @param top [Top] The top.
        def self.teardown(top)
          top.closed = true
          destroy(top.mount)
          @tops.delete(top)
          @by_id.delete(top.id) if top.id && @by_id[top.id].equal?(top)
        end
        private_class_method :teardown

        # Ends an open that failed.
        #
        # @param top [Top] The top.
        # @param why [String, nil] Why, for the log.
        # @return [nil] Always.
        def self.refuse(top, why)
          teardown(top)
          log("#{top.mount.component.class.name} did not open: #{why}") if why
          @refusal ||= why || "its render described no root"
          nil
        end
        private_class_method :refuse

        # Tells why the last component UI.open or UI.show started did not open, such as its render
        # failing.
        #
        # @return [String, nil] Why, nil after one that opened.
        def self.refusal
          @refusal
        end

        # Puts a list's cursor on its bound item, or on the nearest row when that item is gone, and
        # writes that row's item back.
        #
        # @param part [Part] The list's or the table's part.
        # @param items [Array] The items of its rows: the items a list's filter: keeps, the items a
        #   table's page shows.
        def self.bind_list(part, items = Builtins.list_items(part.node.params))
          params = part.node.params
          part.items = items
          owner = part.node.owner
          bind = params[:bind] || params[:bind_index]
          return unless bind && bound_state?(owner, bind)

          value = owner.__send__(bind)
          index = params[:bind] ? items.index(value) : (value.is_a?(Integer) && value >= 0 && value < items.size ? value : nil)
          index ||= items.empty? ? -1 : [[part.index.to_i, 0].max, items.size - 1].min
          @applying = true
          begin
            part.engine.index = index unless part.engine.index == index
          ensure
            @applying = false
          end
          part.index = index
          write_bound(owner, params[:bind], item_at(part, index)) if params[:bind]
          write_bound(owner, params[:bind_index], index < 0 ? nil : index) if params[:bind_index]
        end
        private_class_method :bind_list

        # Tells whether a bind: names a state of the component that wrote it, logging it once when
        # it does not.
        #
        # @param owner [Object] Who wrote the bind.
        # @param name [Symbol] The state.
        # @return [Boolean] Whether it is one.
        def self.bound_state?(owner, name)
          return true if owner.is_a?(UI::Component) && owner.class.states.key?(name)

          states = owner.is_a?(UI::Component) ? owner.class.states.keys : []
          near = Declarations.nearest(name, states)
          Errors.hint([:bind, owner.class, name], nil, "bind: :#{name} is no state of #{owner.class.name}#{near ? "; did you mean :#{near}?" : ''}")
          false
        end
        private_class_method :bound_state?

        # Writes a bound state, once the render that bound it ended.
        #
        # @param owner [Component] Who wrote the bind.
        # @param name [Symbol] The state.
        # @param value [Object] The value.
        def self.write_bound(owner, name, value)
          write_state(owner, name, value) if bound_state?(owner, name)
        end
        private_class_method :write_bound

        # Runs a handler with as many of the values as it takes, then renders its owner again.
        #
        # @param owner [Object] Who wrote the handler.
        # @param handler [Proc, Symbol, nil] The handler.
        # @param values [Array] What the event tells.
        # @param again [Boolean] Whether the owner renders again after it.
        # @return [Object] What the handler answered, nil for none or one that failed.
        def self.call_handler(owner, handler, values, again = true)
          return nil if handler.nil?

          answer = nil
          joined = joined_root_of(owner)
          before = joined ? Tree.roots.dup : nil
          @handling.push(owner)
          begin
            answer = invoke(owner, handler, values)
          rescue StandardError => e
            report_handler(owner, handler, e)
          ensure
            @handling.pop
          end
          hide_join_while_opened(joined, before) if joined
          mark_dirty(owner) if again && owner.is_a?(UI::Component)
          answer
        end
        private_class_method :call_handler

        # Tells the window joined to a game window that a handler's owner lies in, whose handler
        # then hides the two while the roots it opens are open.
        #
        # @param owner [Object] Who wrote the handler.
        # @return [Part, nil] The window's part, nil for none.
        def self.joined_root_of(owner)
          mount = owner.is_a?(UI::Component) ? owner.__send__(:__mount) : nil
          top = mount && mount.top
          root = top && !top.closed ? top.root : nil
          root && root.node.params[:join] && root.node.params[:beside].to_s =~ Placement::GAME_WINDOW ? root : nil
        end
        private_class_method :joined_root_of

        # Cuts what an event tells to what a lambda or a method takes.
        #
        # @param arity [Integer] Its arity.
        # @param values [Array] What the event tells.
        # @return [Array] The values it takes, nil for those the event did not tell.
        def self.cut(arity, values)
          return values if arity < 0

          taken = values[0, arity]
          taken.fill(nil, taken.size...arity)
        end
        private_class_method :cut

        # Logs a handler that failed, with a hint for a frozen state or a nil.
        #
        # @param owner [Object] Who wrote the handler.
        # @param handler [Proc, Symbol] The handler.
        # @param error [Exception] What it raised.
        def self.report_handler(owner, handler, error)
          name = owner.is_a?(UI::Component) ? owner.class.name : owner.class.to_s
          hint = nil
          if error.message =~ /can't modify frozen (\w+)/ && owner.is_a?(UI::Component)
            state = owner.class.states.keys.find { |key| (value = owner.__send__(key)).frozen? && value.class.name == $1 }
            hint = state ? "state :#{state} is frozen; write self.#{state} = #{state} + [x]" : "state values are frozen; write a new value with self.name ="
          elsif error.is_a?(NoMethodError) && error.message =~ /for nil/
            hint = "a value in #{name} was nil"
          elsif error.is_a?(NameError) && handler.is_a?(Symbol) && error.name == handler
            near = Declarations.nearest(handler, owner.methods + owner.private_methods)
            hint = "#{name} has no method #{handler}#{near ? "; did you mean :#{near}?" : ''}"
          end
          Errors.report(error, "a handler of #{name}", hint)
        end
        private_class_method :report_handler

        # Logs a render that raised once per cause; an unknown markup name gets the nearest name.
        #
        # @param component [Component] The component.
        # @param error [Exception] What its render raised.
        def self.report_render(component, error)
          hint = nil
          if error.is_a?(NameError) && error.name
            names = Declarations.names + component.methods + component.private_methods
            near = Declarations.nearest(error.name, names.uniq)
            hint = "did you mean #{near}?" if near && near.to_s != error.name.to_s
          end
          Errors.report(error, "#{component.class.name}'s render", hint)
          @refusal = "its render failed: #{error.message.to_s.sub(/ \(\S+:\d+\)\z/, '')}"
        end
        private_class_method :report_render

        # Logs a loop that makes several siblings of one type without key: at one place, once.
        #
        # @param component [Component] The component.
        # @param nodes [Array<Node>] What its first render described.
        def self.hint_loops(component, nodes)
          seen = {}
          nodes.each do |node|
            next if node.site.nil? || !node.key.nil? || !node.params[:id].nil?

            key = [node.type, node.site]
            if seen[key]
              type = node.component? ? node.type.markup_name : node.type
              Errors.hint([:loop, node.site], node.site, "#{component.class.name} makes several #{type} parts in a loop without key:; give each one key:, so each keeps its state when the loop changes")
            end
            seen[key] = true
          end
          nodes.each { |node| hint_loops(component, node.children) unless node.children.empty? }
        end
        private_class_method :hint_loops

        # Logs a part that holds more than MANY_PARTS siblings of a type, once.
        #
        # @param parent [Mount, Part] The part.
        # @param counts [Hash] Its siblings without a key, by type.
        def self.hint_many(parent, counts)
          type = counts.keys.find { |key| counts[key] > MANY_PARTS }
          return unless type

          owner = parent.is_a?(Mount) ? parent.component.class.name : parent.node.owner.class.name
          Errors.hint([:many, owner, type], nil, "#{owner} makes more than #{MANY_PARTS} #{type} parts; a list or a table stays one part with its rows as data")
        end
        private_class_method :hint_many

        # Runs mounted for the components that showed for a frame.
        def self.tell_mounted
          return if @mounting.empty?

          ready = @mounting
          @mounting = []
          ready.each do |mount|
            next if mount.gone

            begin
              mount.component.mounted
            rescue => e
              Errors.report(e, "#{mount.component.class.name}'s mounted")
            end
          end
        end
        private_class_method :tell_mounted

        # Marks the components dirty whose serials changed or whose watches answer anew, while they
        # show.
        def self.look_for_changes
          @mounted.each do |mount|
            next if mount.gone || mount.dirty || !mount.top.shown?

            if serials_changed?(mount.reads)
              mark_dirty(mount.component)
            elsif watches_changed?(mount)
              mark_dirty(mount.component)
            end
          end
        end
        private_class_method :look_for_changes

        # Tells whether a serial a render read changed since.
        #
        # @param reads [Hash, nil] The serials read and their counts then.
        # @return [Boolean] Whether one changed.
        def self.serials_changed?(reads)
          return false if reads.nil? || reads.empty?

          reads.each_key { |read| return true unless Serials.serial(read[0], read[1]) == reads[read] }
          false
        end
        private_class_method :serials_changed?

        # Asks a component's watches that are due, keeping their answers.
        #
        # @param mount [Mount] The component's mount.
        # @return [Boolean] Whether one answered anew.
        def self.watches_changed?(mount)
          watches = mount.component.class.watches
          return false if watches.empty?

          changed = false
          place = 0
          while place < watches.size
            every, block = watches[place]
            if (@frame % every).zero?
              answer = ask_watch(mount, block)
              unless answer == mount.watched[place]
                mount.watched[place] = answer
                changed = true
              end
            end
            place += 1
          end
          changed
        end
        private_class_method :watches_changed?

        # Asks each watch of a new component once, as the answers later ones are compared with.
        #
        # @param mount [Mount] The component's mount.
        # @return [Array] The answers.
        def self.first_watches(mount)
          mount.component.class.watches.map { |_every, block| ask_watch(mount, block) }
        end
        private_class_method :first_watches

        # Asks a watch, logging one that fails once.
        #
        # @param mount [Mount] The component's mount.
        # @param block [Proc] The watch.
        # @return [Object, nil] Its answer, nil when it failed.
        def self.ask_watch(mount, block)
          mount.component.instance_exec(&block)
        rescue StandardError => e
          Errors.report(e, "a watch of #{mount.component.class.name}")
          nil
        end
        private_class_method :ask_watch

        # Renders the dirty components, parents first, each at most MOST_RENDERS times a frame.
        def self.render_dirty
          until @dirty.empty?
            batch = @dirty.sort_by { |mount| mount.depth }
            @dirty = []
            batch.each do |mount|
              next if mount.gone || !mount.dirty
              next put_behind(mount) if out_of_sight?(mount)

              if mount.rendered_in == @frame
                mount.renders += 1
              else
                mount.rendered_in = @frame
                mount.renders = 1
              end
              if mount.renders > MOST_RENDERS
                mount.dirty = false
                name = mount.component.class.name
                Errors.hint([:renders, name], nil, "#{name} rendered more than #{MOST_RENDERS} times in one frame and was stopped; a state written on every render keeps it busy")
                next
              end
              render_mount(mount)
            end
          end
          resolve_steers
          resolve_links
        end
        private_class_method :render_dirty

        # Reads the live values that are due and sets what changed, also of a root its own live
        # visible: hides, which shows again only once that is read; a shown root with a live at:
        # reads its own every frame, so it jumps the frame its spot changes.
        def self.read_live_values
          @tops.each do |top|
            if (@frame % top.live_every).zero? && (top.shown? || (!top.closed && top.root && top.root.node.params[:visible].is_a?(Proc)))
              refresh_live(top.mount.children)
            elsif top.shown? && top.root.node.params[:at].is_a?(Proc)
              follow_spot(top.root)
            end
          end
        end
        private_class_method :read_live_values

        # Gives each key_help its entries and the keys of the part in focus now, and has it name the
        # keys anew once a hotkey got another key; as the focus moves and every 4 frames, as the live
        # values of a window are read.
        def self.follow_key_helps
          @key_focus = Tree.focused
          if @key_helps.index { |part| part.gone }
            gone = @key_helps.select { |part| part.gone }
            gone.each { |part| @key_labels.delete(part) }
            @key_helps -= gone
          end
          @key_helps.each { |part| refresh_key_help(part) }
        end
        private_class_method :follow_key_helps

        # Gives a key_help its entries and the keys of the part in focus and of the parts it lies in.
        #
        # @param part [Part] The key_help's part.
        def self.refresh_key_help(part)
          root = part.top && part.top.root
          return if part.gone || root.nil?

          entries = Array(part.node.params[:entries])
          unless part.node.params[:auto] == false
            chain = focus_chain(root)
            entries = with_found_keys(entries, button_entries(chain), declared_hotkeys(chain), jump_entries(root, chain.first))
          end
          labels = entries.map { |entry| entry[:hotkey] ? Hotkeys.label(entry[:hotkey]) : nil }
          if part.engine.entries != entries
            part.engine.entries = entries
          elsif @key_labels[part] != labels
            part.engine.refresh
          end
          @key_labels[part] = labels
        end
        private_class_method :refresh_key_help

        # Tells the part in focus inside a root and the parts it lies in, nearest first, up to the
        # root; the root alone while the focus is elsewhere.
        #
        # @param root [Part] The root's part.
        # @return [Array<Part>] The parts.
        def self.focus_chain(root)
          by_engine = parts_by_engine(root, {})
          engine = Tree.focused
          engine = engine.parent while engine && !by_engine[engine.object_id]
          return [root] unless engine

          chain = []
          item = by_engine[engine.object_id]
          while item
            chain << item if item.is_a?(Part)
            item = item.parent
          end
          chain
        end
        private_class_method :focus_chain

        # Collects the parts that lie in a part or a component by the object id of their engine part.
        #
        # @param item [Part, Mount] Where to look.
        # @param into [Hash{Integer => Part}] Where they go.
        # @return [Hash{Integer => Part}] The parts.
        def self.parts_by_engine(item, into)
          into[item.engine.object_id] = item if item.is_a?(Part)
          item.children.each { |child| parts_by_engine(child, into) }
          into
        end
        private_class_method :parts_by_engine

        # Adds the keys of the part in focus and of the parts it lies in to a key_help's entries: the
        # root's own hotkey joins the entry of cancel, as UI.close_hint names it, or closes on its
        # own; the game's buttons, each other part's hotkey whose action no entry names already and
        # then the jump keys come after the entries, or before the entry of cancel when that one ends
        # them, so the way out the mod put last stays last.
        #
        # @param entries [Array<Hash>] The key_help's entries.
        # @param buttons [Array<Hash>] The entries of the game's buttons.
        # @param hotkeys [Array<Array>] Each hotkey with its part's text, nil for the root's.
        # @param jumps [Array<Hash>] The entry of the jump keys, or none.
        # @return [Array<Hash>] The entries.
        def self.with_found_keys(entries, buttons, hotkeys, jumps)
          closing = hotkeys.find { |_hotkey, text| text.nil? }
          cancel = entries.index { |entry| cancel_entry?(entry) }
          last = cancel && cancel == entries.size - 1
          way_out = cancel && closing ? entries[cancel].merge(:hotkey => Array(entries[cancel][:hotkey]) + [closing[0]]) : cancel && entries[cancel]
          found = last ? entries.first(cancel) : entries.dup
          found[cancel] = way_out if cancel && !last
          found.concat(buttons)
          hotkeys.each do |hotkey, text|
            next if cancel && closing && hotkey.equal?(closing[0]) && text.nil?
            next if text && entries.any? { |entry| entry[:text] == text }

            found << { :hotkey => hotkey, :text => text || UI::CLOSE_WORD }
          end
          found.concat(jumps)
          found << way_out if last
          found
        end
        private_class_method :with_found_keys

        # Tells whether a key_help's entry names the game's cancel button.
        #
        # @param entry [Hash] The entry.
        # @return [Boolean] Whether it does.
        def self.cancel_entry?(entry)
          button = entry[:button]
          button.is_a?(Array) ? button.any? { |each| CANCEL_BUTTONS.include?(each) } : CANCEL_BUTTONS.include?(button)
        end
        private_class_method :cancel_entry?

        # Tells the key help entry of the jump keys while a list that has other parts taking the keys
        # around it is in focus: the bound jump key with an arrow, or on a gamepad used last the A
        # button held with the d-pad.
        #
        # @param root [Part] The window's part.
        # @param focus [Part] The part in focus, the root while the focus is elsewhere.
        # @return [Array<Hash>] The entry, or none.
        def self.jump_entries(root, focus)
          return NO_ENTRIES unless focus.node.type == :list && key_stops(root, []).any? { |stop| !stop.equal?(focus) }

          [{ :key => Pad.last? ? PAD_JUMP_KEYS : "#{Hotkeys.label(:list_jump)}+#{ARROW_WORD}", :text => JUMP_TEXT }]
        end
        private_class_method :jump_entries

        # Collects the parts in view that take the keys, an aside's left out.
        #
        # @param item [Part, Mount] Where to look.
        # @param into [Array<Part>] Where they go.
        # @return [Array<Part>] The parts.
        def self.key_stops(item, into)
          if item.is_a?(Part)
            return into unless item.engine.visible? && !item.options[:aside]

            into << item if (item.options[:acts] || item.options[:focusable]) && !item.options[:repeats]
          end
          item.children.each { |child| key_stops(child, into) }
          into
        end
        private_class_method :key_stops

        # Collects key help entries of the game's extra buttons the parts take with on_button:, the
        # nearest part's first, as the nearest takes a button; each is named by its button_help:,
        # else by the method it calls; one whose button_help: is nil is left out, and one without
        # either is left out and logged once.
        #
        # @param parts [Array<Part>] The parts, nearest first.
        # @return [Array<Hash>] Each { :button, :text }.
        def self.button_entries(parts)
          into = []
          parts.each do |item|
            next unless item.engine.visible?

            texts = item.node.params[:button_help] || NO_BUTTONS
            (item.node.params[:on_button] || NO_BUTTONS).each do |button, handler|
              next if handler.nil? || into.any? { |entry| entry[:button] == button.to_s.upcase.to_sym }
              next if texts.key?(button) && texts[button].nil?

              text = texts[button] || (handler.is_a?(Symbol) ? handler.to_s.tr("_", " ") : nil)
              next Errors.hint([:button_help, item.node.owner.class, button], nil, "on_button: :#{button} of #{item.node.type} has no button_help:, so the key help leaves it out") unless text

              into << { :button => button.to_s.upcase.to_sym, :text => text.to_s }
            end
          end
          into
        end
        private_class_method :button_entries

        # The framework's hotkeys that move a row of a list that takes them, with what the key help
        # says they do.
        MOVE_HOTKEYS = [[:list_move_up, "Move up"], [:list_move_down, "Move down"]]

        # Collects the hotkeys the parts declare, each with its part's text, nil for a root's, and the
        # move hotkeys of a list that takes them.
        #
        # @param parts [Array<Part>] The parts, nearest first.
        # @return [Array<Array>] Each [hotkey, text].
        def self.declared_hotkeys(parts)
          into = []
          parts.each do |item|
            next unless item.engine.visible?

            hotkey = item.options[:declared_hotkey]
            into << [hotkey, item.engine.root? ? nil : item.options[:text].to_s] if hotkey
            MOVE_HOTKEYS.each { |move, text| into << [move, text] unless into.any? { |each| each[0] == move } } if item.options[:move_hotkeys]
          end
          into
        end
        private_class_method :declared_hotkeys

        # Reads the live params of parts again, sets the engine's options that changed and has each
        # part follow its params, as a part pulses once its live pulse: changed.
        #
        # @param list [Array] The parts and components.
        def self.refresh_live(list)
          list.each do |each|
            if each.is_a?(Part) && each.live
              spec = each.node.declaration.spec
              read = read_params(each)
              set_options(each, Placement.apply(each, with_class_hotkey(each, spec[:options].call(read)), read))
              follow_pulse(each, read)
              spec[:follow].call(each) if spec[:follow]
            end
            refresh_live(each.children)
          end
        end
        private_class_method :refresh_live

        # Places every hud of the open components that names a column again, so it moves to the
        # column's new place or joins a column defined after it showed.
        #
        # @param name [String] The column's name.
        # @param list [Array, nil] The parts and components to look through, nil for every open top's.
        def self.place_column_again(name, list = nil)
          list ||= @tops.reject { |top| top.closed }.map { |top| top.mount.children }.flatten
          list.each do |each|
            if each.is_a?(Part) && each.node.type == :hud && !each.gone
              read = read_params(each)
              set_options(each, Placement.apply(each, with_class_hotkey(each, each.node.declaration.spec[:options].call(read)), read)) if read[:column].to_s == name
            end
            place_column_again(name, each.children)
          end
        end

        # Reads a root's live at: and moves the root only when the spot it answers changed.
        #
        # Reading its other params as well would set options anew each frame whose values are new
        # objects, such as a color, and draw the root anew each frame.
        #
        # @param part [Part] The root's part.
        def self.follow_spot(part)
          at = read_live(part, :at, part.node.params[:at])
          return if at.nil? || at == part.options[:at]

          part.options = part.options.merge(:at => at)
          part.engine.at = at
        end
        private_class_method :follow_spot
      end
    end
  end
end
