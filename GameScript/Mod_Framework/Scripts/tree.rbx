#----------------------------------------------------------------
#  tree.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Took how much of a component's padding gave way at its place
#                            - Ended a root's fade out at once when told, its pictures freed and its column's place given up
#                            - Kept a closed root in C#'s tree while it fades out where its column keeps its place
#      Paulinchen  2026-11-07: Moved the canvas and the base component into files of their own
#                            - Added the pill a canvas draws, filled, ringed or both
#                            - Declared the state of patches and the exposed values as attributes
#                            - Removed the dump of the tree and the properties it kept, which nothing read
#                            - Read typing from UI.typing? and stopped telling C# of typing outside the text fields
#      Paulinchen  2026-11-06: Stopped timing the frame for the probe, which is gone
#                            - Called the engine's classes by their names under UI::Engine
#                            - Drew the normal text of a part in the look of the game's own windows in the game's own font size,
#                              and its system color as those windows draw their labels
#      Paulinchen  2026-11-05: Drew the roots and collected the tree's input with fewer objects every frame
#                            - Told sight to a component that came into sight
#                            - Marked a part the keys reach only by an arrow with the jump key, such as a table's column title
#                            - Told the component whose event the scripts handle now
#                            - Filled a gauge without colors in the theme's primary color
#                            - Marked a part as the panel of a bar of tabs, which cancel walks back from
#                            - Read a component's offset and overlapped nested rectangles without making objects
#                            - Overlapped two rectangles without making lists
#                            - Drew a text in an animated color letter by letter and an area in moving bands, and drew
#                              them anew every few frames while they show
#                            - Logged a color name that names no color once, with the nearest name
#                            - Took a game text color past the window skin's from the game's own text_color
#                            - Drew the roots and sent the tree's changes every frame with far fewer objects
#                            - Outlined each letter of a text in an animated color by its own color
#                            - Drew a canvas's box at an opacity, if asked
#      Paulinchen  2026-11-04: Let a component's tooltip show on a side of it
#                            - Drew an icon by the name UI.icon gave it, or a picture file, as a canvas's icon
#                            - Applied UI.patch to a component going onto the screen, ran its events through
#                              the handlers they wrap, kept the options they set and let a root expose values to them
#                            - Found a color name through the palette of the theme a component draws in
#                            - Drew a component that takes no input, or a row of a list that takes no pick, greyed out
#                            - Hid the docked roots C#'s tree finds no room for in their zone
#                            - Kept the hotkeys whose key a screen uses as one of the game's buttons, as C#'s tree tells them
#                            - Sent C#'s tree the game's extra buttons a part takes, whether it has a context menu and
#                              whether it takes the submit of a list
#                            - Sent C#'s tree the roots of the new UI layer, the parts that take the window's page step or
#                              declare a hotkey, an empty name for none, and the defined hotkeys with their keys, and
#                              logged a hotkey C# kept quiet
#                            - Bumped the keys' serial once a text field of any mod starts or stops typing
#                            - Sent C#'s tree whether a component has an action, repeats a key, is set aside for the
#                              pointer or takes the focus as its root opens
#                            - Ran the blocks of before_draw, such as the UI layer's render, before each frame is drawn
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Took a viewport as freed once RGSS refuses it, since RGSS's viewport has no disposed?
#                            - Kept the shown roots that hold the game's buttons or block the roots below, worked out once
#                              until a root opens, closes, hides, changes or moves among the others
#                            - Logged each change C#'s tree refused in the log of the mod the component belongs to, and
#                              sent every root again once C# could not read the changes
#                            - Left an option set to the value it holds as it was, and worked out the properties C# lays
#                              a component out by once a frame however many of its options changed
#                            - Drew each text once into a picture of its own, with room on both sides for its outline, and
#                              copied it from there whenever the same text draws again, and kept the widths of texts
#                              measured
#                            - Drew a component anew only where it lies, and where it lay before it moved
#                            - Measured the drawing of the components while a probe runs
#                            - Built a text drawn into its cached picture from copies of its characters where that draws
#                              it as the game does, and measured it from their widths
#                            - Described the components in C#'s tree for an input fixture
#      Paulinchen  2026-11-01: Told whether a viewport or a sprite was freed
#                            - Called a block of a mod with as many values as it takes
#                            - Told C# to take no keys while a box outside the tree types, such as another mod's chat box
#                            - Handed out a picture file cut and scaled to a size once, and let it go with the file
#                            - Let a canvas copy a picture as it is
#                            - Named the cancel keys of every key line anew once a text field starts or stops typing
#                            - Kept the part asked to take the focus until C# answered
#                            - Closed a root waiting for its menu scene once another scene took that scene's place
#                            - Told close with :reset to every root F12 closed
#      Paulinchen  2026-10-31: Squeezed a text by setting its whole characters closer instead of narrowing its picture
#                            - Followed every root's gate, hiding and place under others before the frame, faded out the roots that
#                              close with :fade and told them gone once nothing of them showed
#                            - Told C# the components that take a click
#                            - Kept the room each dock takes
#                            - Stacked the roots that follow one map tile in the order they opened
#                            - Named a party member's color :ally, and drew a gauge's trail, its colors from the top to the bottom
#                              and a frame of two pixels
#                            - Told a component every frame while it asks, such as a gauge whose trail drains
#                            - Gave the first part inside a component the focus
#                            - Let every component tell what it does in :help
#                            - Drew a text without its outline when asked
#      Paulinchen  2026-10-30: Slid the page of a component that takes the focus into view
#                            - Blurred a picture file, and let go of one no longer shown
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-29: Let a component keep the height of its tallest content and take at most a share of its
#                              column
#                            - Handed the focused component the game's buttons it asks for
#                            - Let a component send cancel to another and keep the focus by its id, and took the
#                              screen's size for a size
#                            - Let the roots follow what they lie on before the frame's layout
#                            - Let a component draw shifted and faded on a picture of its own, turn inert, shrink,
#                              ask its blocks and animate
#                            - Let a canvas squeeze a text into its width, never below its least share nor in a
#                              smaller font, and draw a text see-through
#                            - Let a canvas draw a frame without a fill
#                            - Added the tiny font size
#                            - Placed the tooltip a key's focus shows under its component
#                            - Let a canvas tell where a part of the component lies on its picture
#                            - Told C# while another mod types, so no text field takes the focus
#                            - Let a canvas draw a part of a picture
#                            - Added components only the pointer reaches
#                            - Showed the tooltip after the events
#                            - Squeezed a text to no less than four fifths of its width
#                            - Drew a squeezed text wider than the screen in pieces
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The components of the mods mirrored into the DLL's tree (ComponentTree in C#), which lays them
      # out and routes the pointer and the keys to them: every component sent there is a node with an
      # id of its own, every change of a property that lays it out or takes input goes there as one set
      # per frame, and what the tree answers (places, states, scrolling, events, sounds) comes back to
      # the components here.
      #
      # The changes go over with the frame's tick and, for whatever the scene or an event block changed
      # after it, in one call right before the components draw, so a component added in the frame
      # shows in that frame at its place.
      #
      # It must never interrupt the game, so every entry point rescues.
      module Tree
        # The tree's name in the tick, ComponentTree.ModelName in C#.
        MODEL = "tree".freeze

        # The tree's event, ComponentTree.EventTopic.
        EVENT = "ui.tree"

        # Lays out the changes queued after the tick, ComponentTree.LayoutTopic.
        LAYOUT = "ui.tree.layout"

        # Forgets every component, ComponentTree.ResetTopic.
        RESET = "ui.tree.reset"

        # The state bit of the component under the pointer, ComponentTree.Hovered.
        HOVERED = 1

        # The state bit of the component the left button went down on, ComponentTree.Pressed.
        PRESSED = 2

        # The state bit of the component holding the focus, ComponentTree.Focused.
        FOCUSED = 4

        # The fewest frames between two times every root is sent again, see resync.
        RESYNC_FRAMES = 60

        # The frames between two reads of the game's window color while it stays the same object.
        LOOK_EVERY = 30

        # The hotkeys that clashed at a tick at which none did.
        NO_CLASHES = {}.freeze

        # More rows than any map has, which make one number of a tile and a side for stack_follow.
        FOLLOW_ROWS = 4096

        # The property of the size a component measured, which goes over as nil when it measures nothing.
        MEASURED = "measured"

        # The last node id handed out; a component gets a new one each time it goes into C#'s tree, so
        # a component taken out and put back in the same frame never meets its old node there.
        @last_id = 0

        # The components in C#'s tree by their node ids.
        @nodes = {}

        # The node last asked to take the focus, or whose first part that takes the focus was, nil
        # for none.
        @focus_sent = nil
        @focus_in_sent = nil

        # The roots open, in the order they opened.
        @roots = []

        # The frame of Key.frame every root was last sent again in, nil before it ever was.
        @resynced = nil

        # The shown roots that hold the game's buttons or block the roots below them, nil until asked
        # after a root opened, closed, hid, changed or moved among the others.
        @holders = nil

        # The changes queued for C#: the nodes to add, the properties to set by node, the nodes to
        # remove, and the node to focus or to blur.
        @adds = []
        @sets = {}
        @removes = []
        @focus = nil
        @blur = nil

        # The blocks that run before a frame is drawn, each with its tag for the log.
        @before_draw = []

        # The properties of components whose options changed, by component, worked out from the
        # options as the changes go over, so a component whose options change several times in a frame
        # works them out once.
        @later = {}

        # The root under the pointer as C# told it, nil for none.
        @over = nil

        # The key codes the tree acted on at the last tick.
        @taken = []

        # The hotkeys whose key a screen used as one of the game's buttons at the last tick, each name
        # with why.
        @clashes = {}

        # The Hash changes hands over, kept for every call: the tick and flush send it at once.
        @changes = {}

        # Whether the last tick handed C# the tree, so the tick after the last root closed still does:
        # C# tells the cancel that closed it, which the game's buttons bring a tick late, only then.
        @ticked = false

        # The look the components were last drawn in: the colors' count, the game's window color as
        # an object and its values, and the frames since the values were last read.
        @look_serial = nil
        @look_tone = nil
        @look_values = nil
        @look_frames = 0

        # The hotkeys and their keys as C# was last told them, nil before the first time.
        @hotkeys_sent = nil

        # The components whose :cancel_to was not in C#'s tree yet when they went in.
        @unlinked = []

        # The component holding the focus as C# last told it, nil for none.
        @focused = nil

        # The component asked to take the focus that C# has not answered for yet, nil for none, and
        # whether the ask went over to C#.
        @asked = nil
        @asked_sent = false

        # The roots that closed with :fade and still fade out where they lay.
        @fading = []

        # The closed roots that stay in C#'s tree while they fade out, so their column keeps their place.
        @held = []

        # Whether a text field of any mod typed as the key lines last named the cancel keys.
        @typing = false

        # The roots gone from the screen since the last frame, told gone in the next.
        @gone = []

        # The room each dock takes as C# last told it, by the dock's name.
        @docks = {}

        # The room the roots that follow a map character took this frame, by the tile and the side, so
        # those following one tile stack in the order they opened.
        @follow_stack = {}

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "components"

        # Hands out a node id never handed out before.
        #
        # @return [Integer] The id.
        def self.next_id
          @last_id += 1
        end

        # Tells the component in C#'s tree under a node id.
        #
        # @param node [Integer] The node id.
        # @return [Component, nil] The component, nil for a node no longer in the tree.
        def self.component(node)
          @nodes[node]
        end

        # Tells the roots open, in the order they opened.
        #
        # @return [Array<Component>] The roots.
        def self.roots
          @roots.dup
        end

        # Tells the shown roots that hold the game's buttons or block the roots below them, which
        # every root checks whether it lies under.
        #
        # @return [Array<Component>] The roots.
        def self.holders
          @holders ||= @roots.select { |root| root.shown? && (root.holds_buttons? || root.modal?) }
        end

        # Has holders work the roots out anew, after a root hid, showed or changed an option.
        def self.roots_changed
          @holders = nil
        end

        # Tells the root under the pointer, which covers the game's windows below it.
        #
        # @return [Component, nil] The root, nil while the pointer is on none.
        def self.over
          @over
        end

        # Tells the component holding the focus, as C# last told it.
        #
        # @return [Component, nil] The component, nil for none.
        def self.focused
          @focused
        end

        # Tells the component asked to take the focus until C# answers, so what waits for the focus
        # to land there, such as a help line's say, keeps meanwhile.
        #
        # @return [Component, nil] The component, nil once C# answered or when none was asked.
        def self.asked
          @asked
        end

        # Tells whether the tree acted on a key at the last tick, such as Tab moving the focus, so a
        # hotkey on that key stays quiet.
        #
        # @param code [Integer] Windows' code of the key.
        # @return [Boolean] Whether it did.
        def self.taken?(code)
          @taken.include?(code)
        end

        # Tells why a screen used the key of a hotkey as one of the game's buttons at the last tick,
        # such as a part's on_button, so the hotkey stays quiet.
        #
        # @param action [Symbol] The hotkey.
        # @return [String, nil] Why, nil when none did.
        def self.clash(action)
          @clashes[action.to_s]
        end

        # Opens a root: it goes into C#'s tree with everything it holds.
        #
        # @param root [Component] The root.
        def self.open_root(root)
          @holders = nil
          @roots << root
          attach(root, nil, nil)
        end

        # Closes a root: it leaves C#'s tree, unless C# took it out already; one whose column keeps
        # its place stays there hidden until it is gone, so C# goes on stacking it.
        #
        # @param root [Component] The root.
        # @param removed [Boolean] Whether C# removed it already.
        # @param hold [Boolean] Whether its column keeps its place while it fades out.
        def self.close_root(root, removed, hold = false)
          @holders = nil
          @roots.delete(root)
          return detach(root, removed) unless hold && !removed && root.node

          @held << root unless @held.include?(root)
          set(root, "visible" => false, "column_hold" => true)
        end

        # Takes a closed root whose column kept its place out of C#'s tree, once it is gone or opens
        # again.
        #
        # @param root [Component] The root.
        def self.release(root)
          detach(root) if @held.delete(root)
        end
        private_class_method :release

        # Puts a component and everything it holds into C#'s tree.
        #
        # C# adds before it removes, so a component inserted between others while a removal waits would
        # land at another place there; the waiting changes go over first then.
        #
        # @param component [Component] The component.
        # @param parent [Component, nil] Its parent, nil for a root.
        # @param index [Integer, nil] Its place among the parent's children, nil for their end.
        def self.attach(component, parent, index)
          if defined?(Patches) && Patches.any?
            index = Patches.attaching(component, parent, index)
            return unless component.parent.equal?(parent)
          end
          flush if index && !@removes.empty?
          queue_add(component, parent, index)
        end

        # Takes a component and everything it holds out of C#'s tree.
        #
        # @param component [Component] The component.
        # @param removed [Boolean] Whether C# removed it already, as when it closed a root itself.
        def self.detach(component, removed = false)
          node = component.node
          return unless node

          @removes << node unless removed
          forget(component)
        end

        # Queues properties of a component in C#'s tree; several in one frame go over as one set.
        #
        # @param component [Component] The component.
        # @param props [Hash{String => Object}] The properties by C#'s names.
        def self.set(component, props)
          node = component.node
          return unless node && !props.empty?

          later = @later[component]
          later.reject! { |key| props.key?(key) } if later
          (@sets[node] ||= {}).update(props)
        end

        # Queues properties of a component in C#'s tree by their names, worked out from its options
        # as the changes go over.
        #
        # @param component [Component] The component.
        # @param keys [Array<String>] The properties by C#'s names.
        def self.set_later(component, keys)
          return unless component.node && !keys.empty?

          later = (@later[component] ||= [])
          keys.each { |key| later << key unless later.include?(key) }
        end

        # Gives a component the focus at the next layout.
        #
        # @param component [Component] The component.
        def self.focus(component)
          component.wants_focus = component.node.nil?
          @asked = component
          @asked_sent = false
          return unless component.node

          @focus = component.node
          @blur = nil
        end

        # Gives the first part inside a component that takes the focus the focus at the next layout,
        # such as the page of a tab picked.
        #
        # @param component [Component] The component.
        def self.focus_in(component)
          @focus_in = component.node if component.node
        end

        # Tells the component whose event of C#'s tree the scripts handle now, such as the log a name
        # in it was clicked in, so a menu its handler opens closes and moves with that part's root.
        #
        # @return [Component, nil] The component, nil outside an event.
        def self.acting
          @acting
        end

        # Takes the focus off a component at the next layout, if it holds it then.
        #
        # @param component [Component] The component.
        def self.blur(component)
          component.wants_focus = false
          @asked = nil if @asked.equal?(component)
          return unless component.node

          @blur = component.node
          @focus = nil if @focus == component.node
        end

        # Tells whether changes wait for C#.
        #
        # @return [Boolean] Whether some do.
        def self.queued?
          !(@adds.empty? && @sets.empty? && @later.empty? && @removes.empty? && @focus.nil? && @blur.nil? && @focus_in.nil?)
        end

        # Takes the changes waiting for C#, as the tree's input names them, with whether another mod
        # started or stopped typing; the tree takes the screen's size from the input model. The Hash
        # is the same at every call, so the caller sends it before the next call.
        #
        # @return [Hash] The changes.
        def self.changes
          send_links
          work_out_later
          changes = @changes.clear
          unless @adds.empty?
            changes["add"] = @adds
            @adds = []
          end
          unless @sets.empty?
            changes["set"] = @sets.map { |node, props| [node, props] }
            @sets = {}
          end
          unless @removes.empty?
            changes["remove"] = @removes
            @removes = []
          end
          changes["focus"] = @focus if @focus
          changes["blur"] = @blur if @blur
          changes["focus_in"] = @focus_in if @focus_in
          @focus_sent, @focus_in_sent = @focus, nil if @focus
          @focus_sent, @focus_in_sent = nil, @focus_in if @focus_in
          @asked_sent = true if @asked && @focus && @asked.node == @focus
          hotkeys = Hotkeys.for_tree
          changes["hotkeys"] = @hotkeys_sent = hotkeys unless hotkeys.equal?(@hotkeys_sent) || hotkeys == @hotkeys_sent
          @focus = @blur = @focus_in = nil
          changes
        end

        # Puts the tree's input into the frame's tick: the changes, while any wait or any root is open,
        # so the tree follows the pointer and the keys for the roots. Called just before every tick.
        def self.collect
          press_buttons
          @taken.clear
          @clashes = NO_CLASHES
          ticking = queued? || !@roots.empty?
          Tick.put(MODEL, changes) if ticking || @ticked
          @ticked = ticking
        end

        # Sends the changes queued since the tick at once and takes what the tree answers, so they
        # have their places before the components draw. Changes that never reached C# send every
        # root again.
        def self.flush
          return unless queued? && Mod_Framework.available?

          report = Mod_Framework.bridge.call(LAYOUT, changes)
          report.is_a?(Hash) ? take(report) : resync("the changes did not reach it")
        end

        # Sends every open root again with everything it holds, under new node ids, after C#'s tree
        # forgot them or missed changes; the focus stays where it was. At most once a second, so a
        # change C# can never read does not send the roots every frame.
        #
        # @param why [String] Why, for the log.
        def self.resync(why)
          frame = Key.frame
          return if @resynced && frame - @resynced < RESYNC_FRAMES

          @resynced = frame
          log("the components' tree in the DLL was sent again: #{why}")
          focused = @focused
          @adds = []
          @sets = {}
          @later = {}
          @removes = []
          @focus = @blur = @focus_in = nil
          @unlinked = []
          @held.each { |root| forget(root) }
          @held = []
          Mod_Framework.bridge.call(RESET) if Mod_Framework.available?
          @roots.each do |root|
            forget(root)
            queue_add(root, nil, nil)
          end
          focus(focused) if focused && focused.node
        end

        # Takes what the tree answered, at the tick or after a layout: a tree that forgot every
        # component gets them all again and the changes it refused are logged, then places, states
        # and scrolling, the order of the roots, the pointer's root, the buttons and keys it took and
        # the sounds, then the events, so every block sees the components as they are, and last the
        # tooltip, which shows what the events changed, such as the place a key moved to.
        #
        # @param report [Hash] What changed, see ComponentTree.EventTopic.
        def self.take(report)
          return resync("it could not read the changes: #{report['resync']}") if report["resync"]

          Array(report["refused"]).each { |node, why, left| refused(node, why, left) }
          each_component(report["rects"]) { |component, rect| component.placed(rect) }
          each_component(report["padding_cut"]) { |component, cut| component.padding_cut = cut }
          each_component(report["states"]) do |component, bits|
            component.state = bits
            note_focus(component, bits)
          end
          @asked = nil if @asked_sent
          @asked_sent = false
          each_component(report["scroll"]) { |component, scroll| component.scrolled(scroll) }
          rank(report["order"]) if report["order"]
          @over = report["over"] && @nodes[report["over"]] if report.key?("over")
          swallow(report["late"].to_i) if report["late"]
          @taken.concat(Array(report["taken"]))
          @clashes = report["clashes"] if report["clashes"]
          Array(report["quiet"]).each { |action, why, clash| Hotkeys.quiet_in_tree(action, why, clash) }
          @docks = report["docks"] if report["docks"]
          crowd(report["crowded"]) if report.key?("crowded")
          Tick.play(report)
          Array(report["events"]).each { |event| deliver(event) }
          tooltip(report["tooltip"]) if report.key?("tooltip")
        rescue => e
          log_once([:take, e.class], "taking what the tree answered FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Draws the roots for the frame, right before the game shows it: the tweens move on, every
        # root follows what it lies on, the changes queued since the tick go over, roots of a scene
        # that ended close, and every root redraws what changed. Called before every Graphics.update.
        def self.draw_frame
          draw_roots
        end

        # Runs a block before each frame is drawn, before the roots follow what they lie on and the
        # changes go over, such as the UI layer rendering what changed.
        #
        # @param tag [String] What runs, for the log.
        # @yield Runs once a frame.
        def self.before_draw(tag, &block)
          @before_draw << [tag, block]
          nil
        end

        # Runs the blocks of before_draw; one that fails is logged once and the others run.
        def self.run_before_draw
          @before_draw.each do |tag, block|
            begin
              block.call
            rescue => e
              log_once([:before_draw, tag, e.class], "#{tag} before the frame FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
            end
          end
        end
        private_class_method :run_before_draw

        # Draws the roots for the frame, see draw_frame.
        def self.draw_roots
          run_before_draw
          Tween.update
          tick_components
          tell_gone
          roots_now.each { |root| watch(root) }
          @fading.reject! { |root| !root.fade_frame && gone(root) }
          roots_now.each { |root| root.follow_place }
          @follow_stack.clear
          follow_typing
          flush
          close_stale
          changed = look_changed?
          Colors.redraw
          roots_now.each { |root| root.update_frame(changed) }
        rescue => e
          log_once([:draw, e.class], "drawing the components FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end
        private_class_method :draw_roots

        # Copies the roots open into one list kept for every frame, which a root that closes or opens
        # while the copy is walked leaves as it is.
        #
        # @return [Array<Component>] The copy.
        def self.roots_now
          (@roots_now ||= []).replace(@roots)
        end

        # Tells whether the look changed since the last frame: the colors' count or the game's window
        # color, whose values are read only every LOOK_EVERY frames while it stays the same object.
        #
        # @return [Boolean] Whether it changed.
        def self.look_changed?
          tone = Theme.window_tone_object
          @look_frames = (@look_frames + 1) % LOOK_EVERY
          return false if Theme.serial == @look_serial && tone.equal?(@look_tone) && (@look_frames != 0 || Theme.window_tone == @look_values)

          @look_serial = Theme.serial
          @look_tone = tone
          @look_values = Theme.window_tone
          true
        end
        private_class_method :look_changed?

        # Has every key line that names the cancel keys name them anew once a text field of any mod
        # starts or stops typing, since the bound cancel key types its letter there.
        def self.follow_typing
          typing = UI.typing?
          return if typing == @typing

          @typing = typing
          Serials.bump(:keys)
          @nodes.each_value { |component| component.refresh if component.is_a?(KeyHelp) && component.names_cancel? }
        end
        private_class_method :follow_typing

        # Closes the roots opened in a scene that ends, unless they keep through scene changes, before
        # the next scene's first frame shows them, and a root whose menu scene another scene replaced,
        # see Scenes.scene_ended. Called after every Scene_Base#terminate.
        #
        # @param scene [Scene_Base] The scene that ends.
        def self.scene_ended(scene)
          @roots.dup.each { |root| root.close(:scene) if !root.keep && root.scene && root.scene.equal?(scene) }
          if defined?(::Scene_Title) && SceneManager.scene.is_a?(::Scene_Title)
            LabelCache.clear
            Scratch.clear
          end
          Scenes.scene_ended
        rescue => e
          log_once([:scene_ended, e.class], "closing the roots of an ended scene FAILED: #{Logging.failure(e)}")
        end

        # Closes every root as F12 starts the game's scenes again, the ones that keep included, and
        # empties the tree in C#; then the close blocks of the roots that were open or waited for their
        # menu scene hear :reset.
        def self.reset
          closed = @roots.size
          dropped = @roots.dup
          dropped.each do |root|
            root.drop
            forget(root)
          end
          dropped.concat(Scenes.reset)
          @roots = []
          @holders = nil
          @nodes = {}
          @focus_sent = @focus_in_sent = nil
          @adds = []
          @sets = {}
          @later = {}
          @removes = []
          @focus = @blur = nil
          @over = nil
          @focused = nil
          @asked = nil
          @asked_sent = false
          @taken = []
          @clashes = {}
          @ticked = false
          @hotkeys_sent = nil
          @unlinked = []
          @fading.each { |root| root.release_surfaces }
          @fading = []
          @held.each { |root| forget(root) }
          @held = []
          @gone = []
          LabelCache.clear
          Scratch.clear
          Colors.reset
          Tooltip.hide
          Mod_Framework.bridge.call(RESET) if Mod_Framework.available?
          log("F12 closed #{closed} open #{closed == 1 ? 'root' : 'roots'} and emptied the tree") if closed > 0
          dropped.each { |root| root.not_opened(:reset) }
        end

        # Follows the frame once the game runs with the DLL: the tree's input before every tick, the
        # drawing before every Graphics.update, and the closing of a scene's roots as it ends.
        def self.start
          Tick.collect("Mod Framework components") { Mod_Framework::UI::Engine::Tree.collect }
          Hooks.outermost(Graphics.singleton_class, :update, :before, "Mod Framework components") { Mod_Framework::UI::Engine::Tree.draw_frame }
          Hooks.after(::Scene_Base, :terminate, "Mod Framework components") { Mod_Framework::UI::Engine::Tree.scene_ended(self) } if defined?(::Scene_Base)
        end

        # Tells the pixels the shown roots at their default places of a dock take from its edge, as C#
        # laid them out last.
        #
        # @param dock [Symbol] The dock, such as :top_left.
        # @return [Integer] The pixels, 0 for none.
        def self.docked_room(dock)
          @docks[dock.to_s].to_i
        end

        # Hides the docked roots C#'s tree finds no room for in their zone and shows the others again.
        #
        # @param nodes [Array<Integer>] The nodes of the roots that hide.
        def self.crowd(nodes)
          crowded = Array(nodes)
          @roots.each { |root| root.crowded = crowded.include?(root.node) if root.respond_to?(:crowded=) }
        end
        private_class_method :crowd

        # Has a component be told every frame until it answers that it is done, such as a gauge whose
        # trail drains, or no longer.
        #
        # @param component [Component] The component, which answers frame_tick.
        # @param on [Boolean] Whether it is told.
        def self.ticking(component, on)
          @ticking ||= []
          on ? (@ticking << component unless @ticking.include?(component)) : @ticking.delete(component)
        end

        # Tells every component that asked for it the frame, dropping those done or no longer shown.
        def self.tick_components
          return unless @ticking

          @ticking.reject! { |component| !component.shown? || !component.frame_tick }
        end
        private_class_method :tick_components

        # Hands out the room the roots following a tile on a side took so far this frame, and adds a
        # root's.
        #
        # @param tile [Array<Integer>] The tile's x and y.
        # @param side [Integer] The side's place among Root::SIDES.
        # @param height [Integer] The root's height with the room after it.
        # @return [Integer] The room taken before it.
        def self.stack_follow(tile, side, height)
          key = (tile[0] * FOLLOW_ROWS + tile[1]) * Root::SIDES.size + side
          taken = @follow_stack[key].to_i
          @follow_stack[key] = taken + height
          taken
        end

        # Lets a root that closed with :fade fade out where it lay, frame by frame.
        #
        # @param root [Component] The root.
        def self.fade_out(root)
          @fading << root unless @fading.include?(root)
        end

        # Stops a root fading out at once and frees its pictures, as when it opens again.
        #
        # @param root [Component] The root.
        def self.stop_fading(root)
          root.release_surfaces if @fading.delete(root)
          release(root)
          @gone.delete(root)
        end

        # Ends a root's fade out at once, as if it had ended: frees its pictures and takes it out of
        # C#'s tree where its column kept its place.
        #
        # @param root [Component] The root.
        def self.end_fade(root)
          return unless @fading.delete(root)

          root.release_surfaces
          gone(root)
          nil
        end

        # Notes a root nothing of which shows any longer, told gone in the next frame, once a frame
        # without it was shown; a root its column held leaves C#'s tree now.
        #
        # @param root [Component] The root.
        # @return [Boolean] Always true.
        def self.gone(root)
          release(root)
          @gone << root unless @gone.include?(root)
          true
        end

        # Tells the roots gone since the last frame.
        def self.tell_gone
          return if @gone.empty?

          gone = @gone
          @gone = []
          gone.each { |root| root.emit(:gone) }
        end
        private_class_method :tell_gone

        # Has a root follow the frame before it draws, logging a failure once.
        #
        # @param root [Component] The root.
        def self.watch(root)
          root.watch_frame if root.open?
        rescue => e
          log_once([:watch, root.class, e.class], "following the frame of #{root.describe} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end
        private_class_method :watch

        # Queues a component and everything it holds as new nodes, each parent before its children.
        #
        # @param component [Component] The component.
        # @param parent [Component, nil] Its parent, nil for a root.
        # @param index [Integer, nil] Its place among the parent's children, nil for their end.
        def self.queue_add(component, parent, index)
          node = next_id
          component.node = node
          @nodes[node] = component
          @adds << [node, parent && parent.node, component.class::KIND, index, component.node_props]
          @unlinked << component if component.cancel_to.is_a?(Component)
          if component.wants_focus
            @focus = node
            @blur = nil
          end
          component.children.each { |child| queue_add(child, component, nil) }
        end
        private_class_method :queue_add

        # Works out the properties queued by name from their components' options, once per component.
        # "measured" goes over as nil when the component measures nothing, so C# forgets its last size.
        def self.work_out_later
          return if @later.empty?

          later = @later
          @later = {}
          later.each do |component, keys|
            next unless component.node && !keys.empty?

            begin
              props = component.node_props
              picked = {}
              keys.each { |key| picked[key] = props[key] if props.key?(key) || key == MEASURED }
              (@sets[component.node] ||= {}).update(picked) unless picked.empty?
            rescue => e
              log_once([:later, component.class, e.class], "working out the properties of #{component.describe} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
            end
          end
        end
        private_class_method :work_out_later

        # Sends the :cancel_to of the components whose target has gone into C#'s tree since they did,
        # and forgets those no longer there.
        def self.send_links
          @unlinked.reject! do |component|
            target = component.cancel_to
            next true unless component.node && target.is_a?(Component)
            next false unless target.node

            set(component, "cancel_to" => target.node)
            true
          end
        end
        private_class_method :send_links

        # Forgets a component and everything it holds as nodes.
        #
        # @param component [Component] The component.
        def self.forget(component)
          @nodes.delete(component.node)
          @sets.delete(component.node)
          @later.delete(component)
          @over = nil if @over.equal?(component)
          @focused = nil if @focused.equal?(component)
          @asked = nil if @asked.equal?(component)
          Tooltip.hide if Tooltip.shown.equal?(component)
          component.node = nil
          component.state = 0
          component.children.each { |child| forget(child) }
        end
        private_class_method :forget

        # Logs a change of a component C#'s tree refused, once per kind of component and reason, in the
        # log of the mod it belongs to; one C# left out of its tree is forgotten here too.
        #
        # @param node [Integer] The component's node id.
        # @param why [String] Why C# refused it.
        # @param left [Boolean] Whether C# left the component out of its tree.
        def self.refused(node, why, left)
          component = @nodes[node]
          return unless component

          if Logging.first_time?(self, [:refused, component.class, why])
            component.mod_log("#{component.describe} #{left ? 'was not added' : 'kept its last value'}: #{why}")
          end
          forget(component) if left
        end
        private_class_method :refused

        # Hands each entry of a part of the report to the component of its node.
        #
        # @param part [Hash, nil] Values by node id.
        # @yieldparam component [Component] The component.
        # @yieldparam value [Object] Its value.
        def self.each_component(part)
          (part || {}).each do |node, value|
            component = @nodes[node]
            yield(component, value) if component
          end
        end
        private_class_method :each_component

        # Notes the component holding the focus from its state's bits.
        #
        # @param component [Component] The component.
        # @param bits [Integer] Its state's bits.
        def self.note_focus(component, bits)
          if bits & FOCUSED != 0
            @focused = component
          elsif @focused.equal?(component)
            @focused = nil
          end
        end
        private_class_method :note_focus

        # Tells the focused component each of the game's buttons of its :buttons that went down, as
        # button, while no text field types and it takes input.
        def self.press_buttons
          component = @focused
          return unless component && component.node && !UI.typing? && component.enabled_here?

          buttons = component.buttons
          Array(buttons).each { |button| component.emit(:button, button) if Capture.trigger?(button) } if buttons
        end
        private_class_method :press_buttons

        # Ranks the roots of each depth from the bottom up as C# ordered them, so a root raised by a
        # press draws above the others of its depth.
        #
        # @param order [Array<Integer>] The roots' node ids from the bottom to the top.
        def self.rank(order)
          @holders = nil
          counts = Hash.new(0)
          order.each do |node|
            root = @nodes[node]
            next unless root

            root.rank = counts[root.z.to_i]
            counts[root.z.to_i] += 1
          end
        end
        private_class_method :rank

        # Shows the tooltip C# asked for, or hides it.
        #
        # @param tip [Array, nil] The node, the pointer's place and, for a component a key focused,
        #   true; nil to hide it.
        def self.tooltip(tip)
          component = tip && @nodes[tip[0]]
          component ? Tooltip.show(component, tip[1], tip[2], tip[3] == true) : Tooltip.hide
        end
        private_class_method :tooltip

        # Keeps the game's buttons that came a tick after the key the tree took them from away from the
        # scene for the rest of the frame.
        #
        # @param bits [Integer] The buttons' bits, in the order of Tick::BUTTONS.
        def self.swallow(bits)
          Tick::BUTTONS.each_with_index { |button, place| Buttons.swallow(button) if bits[place] == 1 }
        end
        private_class_method :swallow

        # Hands one event of the tree to its component.
        #
        # @param event [Array] The node, the event's name and its value, if it has one.
        def self.deliver(event)
          component = @nodes[event[0]]
          return unless component

          outer = @acting
          @acting = component
          begin
            component.receive(event[1], *event[2..-1])
          ensure
            @acting = outer
          end
        rescue => e
          log_once([:deliver, event[1], e.class], "the #{event[1]} of a component FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end
        private_class_method :deliver

        # Closes the roots whose scene is no longer the game's, for a scene that ended without the
        # game's own terminate.
        def self.close_stale
          scene = SceneManager.scene
          return unless scene

          stale = nil
          @roots.each { |root| (stale ||= []) << root if !root.keep && root.scene && !root.scene.equal?(scene) }
          stale.each { |root| root.close(:scene) } if stale
        end
        private_class_method :close_stale
      end
    end

    Run.on_start("components", :dll => true) { Mod_Framework::UI::Engine::Tree.start }
    Run.on_reset("components") { Mod_Framework::UI::Engine::Tree.reset }
    Mod_Framework.bridge.on(Engine::Tree::EVENT) { |report| Mod_Framework::UI::Engine::Tree.take(report) }
  end
end
