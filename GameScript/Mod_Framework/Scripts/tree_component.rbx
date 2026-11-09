#----------------------------------------------------------------
#  tree_component.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Let go of the kept pictures but a few as memory runs low
#                            - Kept at most 32 picture files and 32 sized copies, letting go of the least used first
#                            - Let a component's padding give way at its largest size, as C#'s tree tells
#                            - Gave every component a margin, a border and a background, and let its padding replace its look's own room
#      Paulinchen  2026-11-07: Gave every component contrast, the text on a fill by contrast with its outline
#                            - Gave every component the outline its texts take
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The base of every component: its place in the tree of components, the properties that lay it
      # out and take input, which go to C#'s tree, its events, its theme and its drawing. A modder's own
      # component subclasses it, answers its size in measure and draws itself in draw.
      #
      # Cancel while it or anything it holds has the focus moves the focus to its :cancel_to instead
      # of closing its root. What the UI layer makes tells C# what it is, and C# works out whether
      # the keys reach it unless :focusable or :pointer_only says so: :acts (false for a part with
      # neither an action nor a bind), :repeats (a button whose press only repeats a key, such as
      # one that closes its root), :aside (the keys never enter it) and :autofocus (the focus starts
      # on it as its root opens). The UI layer also tells :page_step (it takes the window's page step,
      # Q and W), :declared_hotkey (a hotkey of Hotkeys that C# presses it by, or closes it by as a
      # root), and of a root :layer (its keys follow the layer's rules) and :shoulders (:tabs keeps
      # a gamepad's shoulders for its tabs), and :extra_buttons (the game's extra buttons, such as
      # [:Z], that C# tells it as button when one goes down nearest the focus) and :context_menu (C#
      # tells it context with where its menu opens), and :submits (false hands a list's submit up
      # to the nearest part with :submits true, which C# tells submit with the row and the list). Its
      # :id also keeps the focus: a component made anew with the id of the
      # one that had it gets the focus its root kept. While it has the focus and no text field types,
      # each of the game's buttons its :buttons names, such as :Y, tells button as it goes down.
      #
      # In a column, :steady keeps it as high as the tallest content it held since it opened or last
      # reset_steady, so what lies beside it never moves as its content changes, and steady_over
      # shows it several contents at once to take the tallest of them before any shows; :max_share
      # (such as 0.5) keeps it to at most that share of the column's height, what it holds shrinking
      # into the room.
      #
      # Its :margin is room kept around it, outside its size, as pixels for every side or [top, right,
      # bottom, left]. Its :padding replaces the room its look keeps inside its border (own_room);
      # the room of its fixed pieces, such as a title row, a scrollbar or a mark, stays (fixed_room),
      # and its border's width comes on top (border_room). Its :border is a color, :shade, :theme or
      # false, drawn :border_width pixels thick along the inside of its edge, and its :background a
      # color, :theme, false or { :color, :fade }, filled under what it draws (see Canvas#border and
      # Canvas#background); a part with an edge or a back of its own draws them in place of its own,
      # every other part gets them from draw_whole. Its :padding_shrinks lets its padding or own room
      # give way as it reaches its largest size, C#'s tree telling how much did (padding_cut=).
      #
      # Its :outline is the outline of every text it and the components inside it draw, unless one
      # of them has its own; black by default (Canvas#text). Its :contrast, true for it and the
      # components inside it unless one of them sets its own, draws a text on a fill in text_dark or
      # text_light by contrast with the fill, with the outline that contrasts with that text.
      #
      # Events: button (the game's button, such as :Y), sight (it came into sight, see
      # came_into_sight).
      class Component
        # The component's kind in C#'s tree; a modder's own component is "custom".
        KIND = "custom"

        # Where a child sits across its parent's stack, as C# names it.
        ALIGNS = [:start, :center, :end, :stretch]

        # The options every component takes, with their defaults.
        DEFAULTS = { :id => nil, :at => nil, :center => false, :size => nil, :width => nil, :height => nil, :min_size => nil, :max_size => nil,
                     :grow => 0, :shrink => false, :align => :stretch, :padding => nil, :visible => true, :enabled => true, :mouse => true,
                     :theme => nil, :tooltip => nil, :data => nil, :log => nil, :focusable => nil, :offset => nil, :opacity => nil, :inert => false,
                     :pointer_only => nil, :cancel_to => nil, :buttons => nil, :steady => false, :max_share => nil, :help => nil,
                     :acts => nil, :repeats => nil, :aside => nil, :autofocus => nil, :page_step => nil, :declared_hotkey => nil, :layer => nil,
                     :shoulders => nil, :extra_buttons => nil, :context_menu => nil, :submits => nil, :panel => nil,
                     :jump_only => nil, :outline => nil, :contrast => nil, :margin => nil, :border => nil, :border_width => nil, :background => nil,
                     :padding_shrinks => false }

        # The properties of C#'s tree each option sets, by the option.
        NODE_KEYS = { :at => ["at"], :size => ["size"], :width => ["size"], :height => ["size"], :min_size => ["min"],
                      :max_size => ["max"], :grow => ["grow"], :shrink => ["shrink"], :align => ["align"], :padding => ["padding"],
                      :visible => ["visible"], :enabled => ["enabled"], :mouse => ["mouse"], :tooltip => ["tooltip"], :focusable => ["focusable"],
                      :pointer_only => ["pointer_only"], :cancel_to => ["cancel_to"], :id => ["focus_key"], :steady => ["steady"],
                      :max_share => ["max_share"], :acts => ["acts"], :repeats => ["repeats"], :aside => ["aside"], :autofocus => ["autofocus"],
                      :page_step => ["pages"], :declared_hotkey => ["hotkey"], :layer => ["layer"], :shoulders => ["shoulders"],
                      :extra_buttons => ["extra_buttons"], :context_menu => ["context_menu"], :submits => ["submits"], :panel => ["tab_page"],
                      :jump_only => ["jump_only"], :margin => ["margin"], :border => ["padding"], :border_width => ["padding"],
                      :padding_shrinks => ["padding"] }

        # The opacity of a component drawn whole.
        OPAQUE = 255

        # The offset of a component drawn at its place.
        NO_OFFSET = [0, 0].freeze

        # Room of no pixels on every side: top, right, bottom and left.
        NO_ROOM = [0, 0, 0, 0].freeze

        # What a root's gamepad shoulders do unless :shoulders says :tabs, as C# names it.
        SHOULDERS_DEFAULT = :tabs_or_page

        # Reads the option of each name, and sets it: the component lays out and draws anew on the next
        # frame.
        #
        # @param names [Array<Symbol>] The options.
        def self.options(*names)
          names.each do |name|
            define_method(name) { @options[name] }
            define_method("#{name}=") { |value| set_option(name, value) }
          end
        end

        options :id, :at, :center, :size, :width, :height, :min_size, :max_size, :grow, :shrink, :align, :padding, :visible, :enabled, :mouse,
                :theme, :tooltip, :data, :log, :focusable, :pointer_only, :cancel_to, :buttons, :steady, :max_share, :help, :acts, :repeats,
                :aside, :autofocus, :page_step, :declared_hotkey, :layer, :shoulders, :extra_buttons, :context_menu, :submits, :panel,
                :jump_only, :outline, :contrast, :margin, :border, :border_width, :background, :padding_shrinks

        # Tells the defaults of the component's options.
        #
        # @return [Hash] The defaults.
        def self.defaults
          DEFAULTS
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          NODE_KEYS
        end

        # @return [Component, nil] The component it lies in, nil for a root.
        attr_reader :parent

        # @return [Array<Component>] The components it holds, in their order.
        attr_reader :children

        # @return [Rect, nil] Where it lies on the screen after the last layout, nil before it.
        attr_reader :rect

        # @return [Array<Integer>, nil] Its scrolling as C# answered it: where it starts, how much shows
        #   and how much there is; nil for a component that does not scroll.
        attr_reader :scrolling

        # @return [Integer, nil] Its node id in C#'s tree, nil while it is not there.
        attr_accessor :node

        # @return [Boolean] Whether it takes the focus once it goes into C#'s tree, asked before that.
        attr_accessor :wants_focus

        # @return [Symbol, nil] The side of it its tooltip shows on, :top, :bottom, :left or :right;
        #   nil beside the pointer, and under it as a key focuses it.
        attr_accessor :tooltip_side

        # @return [Hash, nil] The values it exposes to other mods' patches, each a block by its name; nil for none.
        attr_reader :exposes

        # @return [Boolean, nil] Whether a part of the UI layer made it, so the patches of old screens pass over it.
        attr_accessor :layer_part

        # @return [Array, nil] The patch runs that name it, which apply to what it holds too; nil for none.
        attr_accessor :patch_entries

        # @return [Hash, nil] The handlers patches wrap around its events, by event; nil for none.
        attr_accessor :patch_wraps

        # @return [Hash, nil] A list's blocks of rows that patches run on the rows its owner gives; nil for none.
        attr_accessor :patch_rows

        # @return [Array, nil] A list's rows as its owner gave them last, before the patches changed them.
        attr_accessor :patch_raw_rows

        # @return [Hash, nil] The options patches set, which its owner's later changes do not undo; nil for none.
        attr_accessor :patch_options

        # @return [Hash, nil] The mod that set each of patch_options last, by option.
        attr_accessor :patch_set_by

        # @return [Hash, nil] The parts patches put beside, inside or in place of it, by patch and operation.
        attr_accessor :patch_grafts

        # @return [Boolean, nil] Whether a patch put parts in its place, which hold it from then on.
        attr_accessor :patch_kept

        # Makes a component.
        #
        # @param options [Hash] Its options, see DEFAULTS and each component's own.
        def initialize(options = {})
          @options = self.class.defaults.dup
          options.each { |name, value| @options[name] = value }
          @children = []
          @handlers = {}
          @state = 0
          @parent = nil
          @rect = nil
          @scrolling = nil
          @node = nil
          @wants_focus = false
          @layered = !(@options[:offset].nil? && @options[:opacity].nil?)
        end

        # Tells whether it holds other components.
        #
        # @return [Boolean] Whether it does.
        def container?
          false
        end

        # Tells how far it is drawn from its place, with what it holds; the layout keeps the place.
        #
        # @return [Array<Integer>] Pixels right and down, [0, 0] for none.
        def offset
          value = @options[:offset]
          return NO_OFFSET if value.nil?

          @offset_read = [value, UI.point(value) || NO_OFFSET] unless @offset_read && @offset_read[0].equal?(value)
          @offset_read[1]
        end

        # Tells how far it is drawn from its place inside what it lies in, in one list it keeps for
        # every frame.
        #
        # @param outer [Array<Integer>] How far what it lies in is drawn from its place.
        # @param offset [Array<Integer>] Its offset.
        # @return [Array<Integer>] Pixels right and down.
        def shift_within(outer, offset)
          shift = (@shift_within ||= [0, 0])
          shift[0] = outer[0] + offset[0]
          shift[1] = outer[1] + offset[1]
          shift
        end

        # Draws it shifted from its place, with what it holds, from the next frame on; the pointer hits
        # it where it is drawn. It moves what is drawn and draws nothing anew.
        #
        # @param value [Array<Integer>, nil] Pixels right and down, nil for none.
        def offset=(value)
          @options[:offset] = UI.point(value)
          layer!
          Tree.set(self, "offset" => offset)
        end

        # Tells how opaque it is drawn, with what it holds.
        #
        # @return [Integer] From 0 (unseen) to OPAQUE.
        def opacity
          @options[:opacity].nil? ? OPAQUE : UI.within(@options[:opacity].to_i, 0, OPAQUE)
        end

        # Draws it and what it holds at an opacity from the next frame on, without drawing them anew.
        #
        # @param value [Integer, nil] From 0 to OPAQUE, nil for OPAQUE.
        def opacity=(value)
          @options[:opacity] = value
          layer!
        end

        # Tells whether it is inert: drawn, but neither the pointer nor the keys reach it or what it holds.
        #
        # @return [Boolean] Whether it is.
        def inert?
          @options[:inert] ? true : false
        end

        # Makes it inert or lets the pointer and the keys reach it again, without drawing it anew.
        #
        # @param value [Boolean] Whether it is inert.
        def inert=(value)
          @options[:inert] = value ? true : false
          Tree.set(self, "inert" => inert?)
        end

        # Animates properties of it from where they are to new values over frames, see Tween.
        #
        # @param props [Hash{Symbol => Object}] The properties and where they go: :offset, :opacity,
        #   :size, and :at of a root.
        # @param options [Hash] :frames, :easing, :delay, :after, see Tween.
        # @return [Tween] The tween, running.
        def animate(props, options = {})
          Tween.new(self, props, options).start
        end

        # Tells whether it draws itself and what it holds on a picture of its own, which a shift or an
        # opacity moves and fades without drawing anything anew.
        #
        # @return [Boolean] Whether it does.
        def layered?
          @layered == true
        end

        # Puts it on a picture of its own, once: the picture it drew on draws without it, and the parts
        # it holds on pictures of their own are made anew above it.
        def layer!
          return if @layered

          below = surface
          @layered = true
          below.dirty = true if below
          @children.each { |child| child.release_surfaces }
        end

        # Tells the picture it draws on while layered.
        #
        # @return [SpriteSurface, nil] The picture, nil before it showed.
        def layer_surface
          @layer
        end

        # Hands out the picture it draws on while layered, made as it first shows.
        #
        # @return [SpriteSurface] The picture.
        def layer_surface!
          @layer ||= SpriteSurface.new(nil, root.surface_viewport)
        end

        # Tells whether the pictures of what it holds are cut to its place, as a Slides cuts its pages.
        #
        # @return [Boolean] Whether they are.
        def clips?
          false
        end

        # Tells whether it is only ever a root, such as a Window.
        #
        # @return [Boolean] Whether it is.
        def root_only?
          false
        end

        # Tells whether it is a root: it lies in no other component.
        #
        # @return [Boolean] Whether it is.
        def root?
          @parent.nil?
        end

        # Tells the root it lies in.
        #
        # @return [Component] The root, itself for a root.
        def root
          @parent ? @parent.root : self
        end

        # Tells its place among its parent's children.
        #
        # @return [Integer, nil] The place, nil for a root.
        def index
          @parent && @parent.children.index(self)
        end

        # Finds the component of an id: itself or one it holds, searched depth first.
        #
        # @param id [Symbol, String] The id.
        # @return [Component, nil] The component, nil for none.
        def find(id)
          return self if !@options[:id].nil? && @options[:id].to_s == id.to_s

          @children.each do |child|
            found = child.find(id)
            return found if found
          end
          nil
        end

        # Adds a component into this one, taking it out of where it lay before.
        #
        # @param child [Component] The component.
        # @param index [Integer, nil] Its place among the children, nil for their end.
        # @return [Component] The component added.
        def add(child, index = nil)
          return refused_child(child, "#{describe} holds no other components") unless container?
          return refused_child(child, "#{child.describe} is only ever a root") if child.root_only?
          return refused_child(child, "#{child.describe} cannot lie in itself") if child.equal?(self) || child.holds?(self)

          child.leave
          index = nil if index && index >= @children.size
          index ? @children.insert(index, child) : @children << child
          child.parent = self
          Tree.attach(child, self, index) if @node
          redraw_content
          child
        end

        # Takes a component out of this one; it is kept, so it can be added again.
        #
        # @param child [Component] The component.
        # @return [Component, nil] The component taken out, nil when it was not here.
        def remove(child)
          return nil unless @children.delete(child)

          Tree.detach(child)
          child.parent = nil
          child.release_surfaces
          redraw_content
          child
        end

        # Takes every component out of this one.
        #
        # @return [Component] Itself.
        def clear
          @children.dup.each { |child| remove(child) }
          self
        end

        # Takes the component out of where it lies, closing it when it is an open root.
        def dispose
          leave
          release_surfaces
          @disposed = true
        end

        # Tells whether it was disposed.
        #
        # @return [Boolean] Whether it was.
        def disposed?
          @disposed == true
        end

        # Tells whether it lies out of sight: it or a component it lies in is hidden, or lies on a
        # page that what holds the page keeps out of view, such as slides.
        #
        # @return [Boolean] Whether it does.
        def out_of_sight?
          return true unless visible?

          @parent ? @parent.keeps_out_of_view?(self) || @parent.out_of_sight? : false
        end

        # Tells whether it keeps one of the components it holds out of view, drawing nothing of it.
        #
        # @param _child [Component] The component.
        # @return [Boolean] Whether it does; false here, slides tell their pages.
        def keeps_out_of_view?(_child)
          false
        end

        # Tells sight, then what it holds that shows, that it came into sight, such as a part that put
        # off building what it shows while out of sight.
        def came_into_sight
          emit(:sight) if listens?(:sight)
          @children.each { |child| child.came_into_sight if child.visible? }
        end

        # Tells whether it is shown: it and every component it lies in are visible and its root is open.
        #
        # @return [Boolean] Whether it is.
        def shown?
          visible? && (@parent ? @parent.shown? : open?)
        end

        # Tells whether it is open; only a root opens.
        #
        # @return [Boolean] Whether it is.
        def open?
          false
        end

        # Tells whether it is visible itself.
        #
        # @return [Boolean] Whether it is.
        def visible?
          @options[:visible] ? true : false
        end

        # Tells whether it takes input itself.
        #
        # @return [Boolean] Whether it does.
        def enabled?
          @options[:enabled] ? true : false
        end

        # Tells whether it and every component it lies in take input.
        #
        # @return [Boolean] Whether they do.
        def enabled_here?
          enabled? && (@parent ? @parent.enabled_here? : true)
        end

        # Tells whether the pointer is on it.
        #
        # @return [Boolean] Whether it is.
        def hovered?
          @state & Tree::HOVERED != 0
        end

        # Tells whether the left button went down on it and the pointer stays on it.
        #
        # @return [Boolean] Whether it did.
        def pressed?
          @state & Tree::PRESSED != 0
        end

        # Tells whether it holds the focus.
        #
        # @return [Boolean] Whether it does.
        def focused?
          @state & Tree::FOCUSED != 0
        end

        # Gives it the focus, from the next layout on; a strip of pages it lies on out of view first
        # slides its page into view.
        #
        # @return [Component] Itself.
        def focus
          reveal
          Tree.focus(self)
          self
        end

        # Slides each strip of pages it lies on so that the page holding it is in view.
        #
        # @return [Component] Itself.
        def reveal
          child = self
          step = @parent
          while step
            step.bring_into_view(child) if step.respond_to?(:bring_into_view)
            child = step
            step = step.parent
          end
          self
        end

        # Takes the focus off it, from the next layout on.
        #
        # @return [Component] Itself.
        def blur
          Tree.blur(self)
          self
        end

        # Forgets the tallest content a :steady component held, so it is as high as what it holds now
        # from the next layout on, such as for a new set of contents.
        #
        # @return [Component] Itself.
        def reset_steady
          Tree.set(self, "steady" => @options[:steady] ? true : false)
          self
        end

        # Shows a :steady component each of some contents and lays it out at once, so it keeps the
        # height of the tallest of them before any shows; the block shows a value, and the caller
        # shows the content it keeps afterwards. A component of no open root lays out nothing.
        #
        # @param values [Array] The values, such as the rows a list may put under its cursor.
        # @yieldparam value [Object] A value to show.
        # @return [Component] Itself.
        def steady_over(values)
          values.each do |value|
            yield value
            Tree.flush
          end
          self
        end

        # Runs a block on an event of the component, see the events of each component.
        #
        # @param name [Symbol] The event, such as :click.
        # @yield [*values] Runs on the event with its values.
        # @return [Component] Itself, so calls chain.
        def on(name, &block)
          (@handlers[name.to_sym] ||= []) << block if block
          Tree.set(self, "clicks" => true) if name.to_sym == :click && block
          self
        end

        # Drops every block of an event.
        #
        # @param name [Symbol] The event.
        # @return [Component] Itself.
        def off(name)
          @handlers.delete(name.to_sym)
          self
        end

        # Tells whether blocks of an event wait.
        #
        # @param name [Symbol] The event.
        # @return [Boolean] Whether some do.
        def listens?(name)
          blocks = @handlers[name.to_sym]
          !blocks.nil? && !blocks.empty?
        end

        # Runs the blocks of an event that may refuse what it tells, as emit does.
        #
        # @param name [Symbol] The event.
        # @param values [Array] Its values.
        # @return [Boolean] False when a block answered false, true otherwise.
        def ask(name, *values)
          return Patches.wrapped(self, name, values) { |*args| ask_blocks(name, args) } != false if @patch_wraps && Patches.wraps?(self, name)

          ask_blocks(name, values)
        end

        # Runs the blocks of an event; one that fails is logged in the log of the mod that made the
        # component, and the others still run.
        #
        # @param name [Symbol] The event.
        # @param values [Array] Its values.
        # @return [Component] Itself.
        def emit(name, *values)
          if @patch_wraps && Patches.wraps?(self, name)
            Patches.wrapped(self, name, values) { |*args| emit_blocks(name, args) }
          else
            emit_blocks(name, values)
          end
          self
        end

        # Lets other mods' UI.patch blocks read a value of this component and what it holds with
        # read, as a component of the UI layer exposes one.
        #
        # @param name [Symbol] The value.
        # @yield Works out the value on each read.
        # @return [Component] Itself.
        def expose(name, &block)
          raise ArgumentError, "expose needs a block that answers the value" unless block

          (@exposes ||= {})[name] = block
          self
        end

        # Tells the theme it draws in: its own, else its parent's, and for a root the player's preset.
        #
        # @return [Boolean, Symbol, String, Theme::Preset] true for the player's preset, false for the
        #   game's own look, :game for the look the game's own windows wear, or a preset or its name.
        def theme_value
          own = @options[:theme]
          return own unless own.nil?

          @parent ? @parent.theme_value : true
        end

        # Tells whether it draws in the look the game's own windows wear (theme :game), whose rows and
        # body text take the game's own font size.
        #
        # @return [Boolean] Whether it does.
        def game_look?
          theme_value == :game
        end

        # Hands out the colors of its theme.
        #
        # @return [Palette] The palette.
        def palette
          Theme.palette(theme_value)
        end

        # Tells whether its texts on a fill take the text that contrasts with the fill: its own
        # :contrast, else its parent's.
        #
        # @return [Boolean] Whether they do; false by default.
        def contrast?
          own = @options[:contrast]
          return own unless own.nil?

          @parent ? @parent.contrast? : false
        end

        # Tells the color of a text on a fill: the plain text color, or with contrast? text_dark or
        # text_light, whichever contrasts more with the fill.
        #
        # @param fill [Symbol, Color] The fill.
        # @return [Symbol, Color] The color.
        def text_on(fill)
          contrast? ? palette.text_on(fill) : :text
        end

        # Tells where a failing block of it is logged: its own :log, else the one of the component it
        # lies in.
        #
        # @return [#log, nil] The log, nil for the framework's.
        def log_target
          @options[:log] || (@parent && @parent.log_target)
        end

        # Tells its size as it draws, for a modder's own component; the layout gives it the rest.
        #
        # @return [Array, nil] Its width and height, a side nil to take what the layout gives; nil for
        #   a component that measures nothing itself.
        def measure
          nil
        end

        # Draws the component, for a modder's own component.
        #
        # @param _canvas [Canvas] Where it draws.
        def draw(_canvas)
          nil
        end

        # Draws the component whole: its background, what draw draws, then its border; a part with a
        # back or an edge of its own draws those itself in draw.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_whole(canvas)
          canvas.background(0, 0, canvas.width, canvas.height, @options[:background]) unless own_back?
          draw(canvas)
          draw_border(canvas) unless own_edge?
        end

        # Draws it again on the next frame: where it lies, or all of the picture it lies on before it
        # has a place.
        #
        # @return [Component] Itself.
        def redraw
          surface = self.surface
          return self unless surface

          @rect && surface.respond_to?(:invalidate) ? surface.invalidate(@rect) : surface.dirty = true
          self
        end

        # Draws it and what it holds again on the next frame, also where it scrolls them on a picture of
        # its own.
        #
        # @return [Component] Itself.
        def redraw_content
          part = inner_surface
          part.dirty = true if part
          redraw
        end

        # Measures it again and lays it out anew on the next frame, after what measure answers changed.
        #
        # @return [Component] Itself.
        def relayout
          Tree.set_later(self, [Tree::MEASURED])
          redraw
        end

        # Tells its tooltip for the pointer at a spot: its tooltip, wherever the pointer is on it. A
        # component whose parts tip apart, such as the rows of a list, answers by the spot.
        #
        # @param _x [Integer] The pointer's left on the screen.
        # @param _y [Integer] Its top.
        # @return [String, Proc, nil] The tooltip, nil for none.
        def tooltip_at(_x, _y)
          tooltip
        end

        # Tells where what it holds lies on the screen: its place inside its padding.
        #
        # @return [Rect, nil] The place, nil before it has one.
        def content_rect
          return nil unless @rect

          top, right, bottom, left = padding_sides
          Rect.new(@rect.x + left, @rect.y + top, [@rect.width - left - right, 1].max, [@rect.height - top - bottom, 1].max)
        end

        # Names it for the log.
        #
        # @return [String] Its class and its id.
        def describe
          name = self.class.name.to_s.split("::").last
          @options[:id] ? "#{name} #{@options[:id]}" : name
        end

        # Names it for the in-game test suite: its class, its id and its text or title.
        #
        # @return [String] The name.
        def dump_name
          parts = [self.class.name.to_s.split("::").last]
          parts << @options[:id].to_s if @options[:id]
          text = @options[:text] || @options[:title]
          parts << text if text.is_a?(String) && !text.empty?
          parts.join(" ")
        end

        # Tells the properties C#'s tree lays it out and routes input by, by their names there.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = { "padding" => padding_prop, "margin" => sides_of(@options[:margin]) || NO_ROOM, "align" => UI.choice(@options[:align], ALIGNS, :stretch, "align"),
                    "grow" => UI.whole(@options[:grow]),
                    "size" => fixed_size, "min" => UI.size(@options[:min_size]), "max" => UI.size(@options[:max_size]),
                    "at" => UI.point(@options[:at]), "visible" => visible?, "enabled" => enabled?, "mouse" => @options[:mouse] ? true : false,
                    "tooltip" => !tooltip.to_s.empty? }
          props["focusable"] = @options[:focusable] ? true : false unless @options[:focusable].nil?
          props["pointer_only"] = @options[:pointer_only] ? true : false unless @options[:pointer_only].nil?
          [:acts, :repeats, :aside, :autofocus, :layer, :context_menu, :submits, :jump_only].each { |name| props[name.to_s] = @options[name] ? true : false unless @options[name].nil? }
          props["pages"] = @options[:page_step] ? true : false unless @options[:page_step].nil?
          props["tab_page"] = @options[:panel] ? true : false unless @options[:panel].nil?
          props["hotkey"] = @options[:declared_hotkey] ? @options[:declared_hotkey].to_s : "" unless @options[:declared_hotkey].nil?
          props["shoulders"] = (@options[:shoulders] || SHOULDERS_DEFAULT).to_s unless @options[:shoulders].nil?
          props["extra_buttons"] = Array(@options[:extra_buttons]).map { |button| button.to_s.upcase } unless @options[:extra_buttons].nil?
          props["shrink"] = @options[:shrink] ? true : false
          props["steady"] = @options[:steady] ? true : false
          props["max_share"] = @options[:max_share] && UI.within((@options[:max_share].to_f * 100).round, 0, 100)
          props["offset"] = offset if @options[:offset]
          props["inert"] = true if inert?
          props["focus_key"] = @options[:id].nil? ? nil : @options[:id].to_s
          target = @options[:cancel_to]
          props["cancel_to"] = target.is_a?(Component) ? target.node : nil
          measured = measured_size
          props["measured"] = measured if measured
          props
        end

        # Takes the place C# gave it.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          before = @rect
          surface = self.surface
          surface.invalidate(before) if before && surface && surface.respond_to?(:invalidate)
          @rect = Rect.new(*rect)
          redraw
        end

        # Takes from C# how much of its padding gave way at its place, and draws anew.
        #
        # @param cut [Array<Integer>] Top, right, bottom and left.
        def padding_cut=(cut)
          @padding_cut = cut.any? { |side| side != 0 } ? cut : nil
          redraw
        end

        # Takes its state from C#: the bits of hover, press and focus.
        #
        # @param bits [Integer] The bits.
        def state=(bits)
          return if bits == @state

          @state = bits
          redraw
        end

        # Takes its scrolling from C#: what it holds and its scrollbar draw anew.
        #
        # @param scroll [Array<Integer>] Where it starts, how much shows and how much there is.
        def scrolled(scroll)
          @scrolling = scroll
          part = inner_surface
          part.dirty = true if part
          redraw
        end

        # Takes an event of C#'s tree and runs its blocks: focus, blur, hover, click and the others of
        # each component.
        #
        # @param name [String] The event, such as "click".
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          redraw if name == "focus" || name == "blur"
          emit(name.to_sym, *values)
        end

        # Tells the picture it draws itself on: its parent's, or its own as a root.
        #
        # @return [#bitmap, nil] The picture, nil before it was made.
        def surface
          return @layer if @layered && @parent

          @parent ? @parent.content_surface : base_surface
        end

        # Tells the picture what it holds draws on: its own when it scrolls them, else the one it lies on.
        #
        # @return [#bitmap, nil] The picture, nil before it was made.
        def content_surface
          inner_surface || surface
        end

        # Tells the picture a root draws itself on.
        #
        # @return [#bitmap, nil] The picture, nil for a component that is no root.
        def base_surface
          nil
        end

        # Tells the picture of the part it scrolls.
        #
        # @return [#bitmap, nil] The picture, nil for a component that scrolls nothing.
        def inner_surface
          nil
        end

        # Frees the pictures of every part it and the components it holds scroll, and its layer's.
        def release_surfaces
          @children.each { |child| child.release_surfaces }
          @layer.dispose if @layer
          @layer = nil
        end

        # Tells whether it holds a component, at any depth.
        #
        # @param other [Component] The component.
        # @return [Boolean] Whether it does.
        def holds?(other)
          @children.any? { |child| child.equal?(other) || child.holds?(other) }
        end

        # Puts it into a parent; only add and remove call it.
        #
        # @param component [Component, nil] The parent, nil for none.
        def parent=(component)
          @parent = component
        end

        # Writes a line into the log of the mod that made it, see log_target, else the framework's.
        #
        # @param message [String] The line.
        def mod_log(message)
          target = log_target
          target.respond_to?(:log) ? target.log(message) : Tree.log(message)
        end

        # Takes it out of where it lies: out of its parent, or closed as an open root.
        def leave
          @parent ? @parent.remove(self) : (open? && close)
        end

        private

        # Sets an option, queues the properties it sets for C#'s tree and draws anew; an option set to
        # the plain value it holds stays as it is, see UI.plain_copy.
        #
        # @param name [Symbol] The option.
        # @param value [Object] Its value.
        def set_option(name, value)
          value = @patch_options[name] if @patch_options && @patch_options.key?(name)
          seen = (@seen ||= {})
          return if seen.key?(name) && seen[name] == value && @options[name] == value

          @options[name] = value
          plain = UI.plain_copy(value)
          plain.equal?(UI::NOT_PLAIN) ? seen.delete(name) : seen[name] = plain
          keys = self.class.node_keys[name]
          Tree.set_later(self, keys) if keys
          changed(name)
          came_into_sight if name == :visible && value && !out_of_sight?
          redraw
        end

        # Runs the blocks of an event that may refuse what it tells.
        #
        # @param name [Symbol] The event.
        # @param values [Array] Its values.
        # @return [Boolean] False when a block answered false, true otherwise.
        def ask_blocks(name, values)
          allowed = true
          Array(@handlers[name.to_sym]).dup.each do |block|
            begin
              allowed = false if block.call(*values) == false
            rescue => e
              block_failed(name, block, e)
            end
          end
          allowed
        end

        # Runs the blocks of an event; one that fails is logged and the others still run.
        #
        # @param name [Symbol] The event.
        # @param values [Array] Its values.
        # @return [Boolean] True, as the blocks ran.
        def emit_blocks(name, values)
          Array(@handlers[name.to_sym]).dup.each do |block|
            begin
              block.call(*values)
            rescue => e
              block_failed(name, block, e)
            end
          end
          true
        end

        # Follows a changed option beyond C#'s tree, for a component whose drawing or state hangs on
        # it.
        #
        # @param _name [Symbol] The option.
        def changed(_name)
          nil
        end

        # Tells whether it draws as taking input: it and every component it lies in are enabled.
        #
        # @return [Boolean] Whether it does.
        def draws_enabled?
          enabled_here?
        end
        public :draws_enabled?

        # Asks measure for its size, logging a measure that fails once in the log of its mod.
        #
        # @return [Array, nil] Its width and height as C# takes them, nil for none.
        def measured_size
          UI.pair(measure)
        rescue => e
          mod_log("measuring #{describe} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}") if Logging.first_time?(Tree, [:measure, self.class, e.class])
          nil
        end

        # Tells the room its look keeps inside its border, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          NO_ROOM
        end

        # Tells the room it keeps for its fixed pieces, such as a title row, a scrollbar, a mark, an
        # icon, a badge or an arrow, which stays whatever its :padding.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          NO_ROOM
        end

        # Tells the border it draws by default: nil for none, else a color, :shade or :theme.
        #
        # @return [Object, nil] The border.
        def own_border
          nil
        end

        # Tells the room its own border keeps while no :border or :border_width is given: none, as a
        # part's own edge lies inside its own room.
        #
        # @return [Integer] The pixels.
        def own_border_room
          0
        end

        # Tells the width of its own border while no :border_width is given.
        #
        # @return [Integer] The pixels.
        def own_border_width
          1
        end

        # Tells the border it draws: its :border, else its own.
        #
        # @return [Object, nil] A color, :shade or :theme; nil or false for none.
        def border_look
          @options[:border].nil? ? own_border : @options[:border]
        end

        # Tells how thick it draws its border: its :border_width, else its own; 0 for none.
        #
        # @return [Integer] The pixels.
        def border_px
          look = border_look
          return 0 if look.nil? || look == false

          @options[:border_width].nil? ? own_border_width : UI.whole(@options[:border_width])
        end

        # Tells the room its border takes inside its size: its width once a :border or a
        # :border_width is given, else the room of its own border.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def border_room
          px = @options[:border].nil? && @options[:border_width].nil? ? own_border_room : border_px
          [px, px, px, px]
        end

        # Tells the room between its border and what it holds: its :padding, else its own room.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def room_sides
          sides_of(@options[:padding]) || own_room
        end

        # Tells where the room of its border and its padding ends, from each edge, where a title
        # row starts.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def edge_sides
          border_room.zip(room_sides).map { |border, room| border + room }
        end

        # Tells the room inside its edges as C# takes it: its border, its padding or own room, and its
        # fixed room.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def full_padding_sides
          edge_sides.zip(fixed_room).map { |edge, fixed| edge + fixed }
        end

        # Tells the room inside its edges at its place: as C# takes it, less what of its padding gave
        # way.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def padding_sides
          full = full_padding_sides
          @padding_cut ? full.zip(@padding_cut).map { |side, cut| side - cut } : full
        end

        # Tells its padding as C#'s tree takes it: the room inside its edges, and with
        # :padding_shrinks the room of each side that gives way, its padding or own room.
        #
        # @return [Array<Integer>] Top, right, bottom and left, with :padding_shrinks four more.
        def padding_prop
          @options[:padding_shrinks] ? full_padding_sides + room_sides : full_padding_sides
        end

        # Turns pixels for every side or [top, right, bottom, left] into the four sides.
        #
        # @param value [Integer, Array<Integer>, nil] The pixels.
        # @return [Array<Integer>, nil] Top, right, bottom and left, nil for none.
        def sides_of(value)
          return nil if value.nil?

          value.is_a?(Array) && value.size == 4 ? value.map { |side| UI.whole(side) } : [UI.whole(value)] * 4
        end

        # Tells whether it draws its background itself in draw, in place of its own back.
        #
        # @return [Boolean] Whether it does.
        def own_back?
          false
        end

        # Tells whether it draws its border itself in draw, in place of its own edge.
        #
        # @return [Boolean] Whether it does.
        def own_edge?
          false
        end

        # Draws its :border after what it draws, for a part without an edge of its own; :shade in a
        # darker shade of its color.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_border(canvas)
          canvas.border(0, 0, canvas.width, canvas.height, @options[:border], border_px, :of => shade_base)
        end

        # Tells the color a :shade border darkens: its :color, else the first of its :colors, else
        # the theme's primary color.
        #
        # @return [Object] The color.
        def shade_base
          @options[:color] || Array(@options[:colors]).first || :primary
        end

        # Tells its fixed size as C# takes it.
        #
        # @return [Array, nil] Its width and height, a side nil to fit what it holds; nil for neither.
        def fixed_size
          size = UI.size(@options[:size]) || [nil, nil]
          width = @options[:width].nil? ? size[0] : UI.whole(@options[:width])
          height = @options[:height].nil? ? size[1] : UI.whole(@options[:height])
          width.nil? && height.nil? ? nil : [width, height]
        end

        # Logs a component that could not be added and hands it back.
        #
        # @param child [Component] The component.
        # @param why [String] Why.
        # @return [Component] The component.
        def refused_child(child, why)
          Tree.log_once([:refused_child, why], "#{child.describe} was not added: #{why}")
          child
        end

        # Logs a block of an event that failed, once per block and error, in the log of the mod that
        # made the component.
        #
        # @param name [Symbol] The event.
        # @param block [Proc] The block.
        # @param error [Exception] What it raised.
        def block_failed(name, block, error)
          place = Array(block.source_location).join(":")
          return unless Logging.first_time?(Tree, [:block, place, name, error.class])

          mod_log("the #{name} block at #{place} of #{describe} failed: #{Logging.failure(error)} at #{Array(error.backtrace).first}")
        end
      end
    end

    # What plain_copy answers for a value it cannot copy.
    NOT_PLAIN = Object.new.freeze

    # The kinds of value no script can change once made.
    FIXED_KINDS = [Numeric, Symbol, NilClass, TrueClass, FalseClass]

    # Copies an option's value that holds only plain data, so a later set can tell whether it is
    # the same: a number, a symbol, nil, true or false as it is, a String, and an Array of those.
    #
    # @param value [Object] The value.
    # @return [Object] A frozen copy, or NOT_PLAIN for a value with other objects in it, such as a
    #   Hash or a block, which a script may have changed in place.
    def self.plain_copy(value)
      return value if FIXED_KINDS.any? { |kind| value.is_a?(kind) }
      return value.frozen? ? value : value.dup.freeze if value.is_a?(String)
      return NOT_PLAIN unless value.is_a?(Array)

      copies = value.map { |each| plain_copy(each) }
      copies.any? { |each| each.equal?(NOT_PLAIN) } ? NOT_PLAIN : copies.freeze
    end

    # Reads a size or a place option as C# takes it.
    #
    # @param value [Array, nil] Two numbers, either nil.
    # @return [Array, nil] Two whole numbers or nils, nil for none.
    def self.pair(value)
      return nil unless value.is_a?(Array) && value.size == 2

      value.map { |side| side.nil? ? nil : side.to_i }
    end

    # Reads a size option as C# takes it: :screen for the game's screen, or two numbers.
    #
    # @param value [Symbol, Array, nil] :screen, or two numbers, either nil.
    # @return [Array, nil] Two whole numbers or nils, nil for none.
    def self.size(value)
      value == :screen ? [Graphics.width, Graphics.height] : pair(value)
    end

    # Reads a place option as C# takes it: both sides or none.
    #
    # @param value [Array, nil] Two numbers.
    # @return [Array<Integer>, nil] The place, nil for none or for a side missing.
    def self.point(value)
      place = pair(value)
      place && !place.include?(nil) ? place : nil
    end

    # Reads a number C# takes as a whole number of at least 0.
    #
    # @param value [Numeric, nil] The number.
    # @return [Integer] The number, 0 for nil or less.
    def self.whole(value)
      [value.to_i, 0].max
    end

    # Reads an option that names one of a few ways, as C# takes it; another is logged once and the
    # fallback taken, since C# refuses a name it does not know with every change of the frame.
    #
    # @param value [Symbol, String] The way, such as :row.
    # @param allowed [Array<Symbol>] The ways there are.
    # @param fallback [Symbol] The way taken for another.
    # @param what [String] What the option is, for the log.
    # @return [String] The way's name.
    def self.choice(value, allowed, fallback, what)
      name = value.to_s
      return name if allowed.map { |way| way.to_s }.include?(name)

      Engine::Tree.log_once([:choice, what, name], "#{value.inspect} is no #{what}, so #{fallback} is taken (one of #{allowed.join(', ')})")
      fallback.to_s
    end

    # Calls a block of a mod with as many of the values as it takes, since a lambda refuses values
    # it does not name.
    #
    # @param block [Proc] The block.
    # @param values [Array] The values the framework hands over.
    # @return [Object] What the block answered.
    def self.call_with(block, *values)
      block.arity < 0 ? block.call(*values) : block.call(*values.first(block.arity))
    end

    # Tells whether a viewport, a sprite or a picture was freed.
    #
    # RGSS's Viewport has no disposed?, but every call on a freed one raises, so a viewport is asked
    # its depth.
    #
    # @param object [Object, nil] What is asked about; nil was not freed.
    # @return [Boolean] Whether it was.
    def self.freed?(object)
      return object.disposed? ? true : false if object.respond_to?(:disposed?)
      # defined? makes a String on every call in the game's Ruby, const_defined? none.
      return false unless Object.const_defined?(:Viewport) && object.is_a?(::Viewport)

      object.z
      false
    rescue StandardError
      true
    end

    # Tells where two rectangles overlap.
    #
    # @param one [Rect] One rectangle.
    # @param other [Rect] The other.
    # @return [Rect] The overlap, empty when they do not.
    def self.overlap(one, other)
      return one if inside?(one, other)
      return other if inside?(other, one)

      left = one.x > other.x ? one.x : other.x
      top = one.y > other.y ? one.y : other.y
      right = one.x + one.width < other.x + other.width ? one.x + one.width : other.x + other.width
      bottom = one.y + one.height < other.y + other.height ? one.y + one.height : other.y + other.height
      Rect.new(left, top, right > left ? right - left : 0, bottom > top ? bottom - top : 0)
    end

    # Tells whether a rectangle lies wholly inside another.
    #
    # @param one [Rect] The rectangle.
    # @param other [Rect] The other.
    # @return [Boolean] Whether it does.
    def self.inside?(one, other)
      one.x >= other.x && one.y >= other.y && one.x + one.width <= other.x + other.width && one.y + one.height <= other.y + other.height
    end
    private_class_method :inside?

    # Times a blurred picture is blurred, enough that nothing in it can be told apart.
    BLUR_PASSES = 6

    # The most picture files kept loaded, and the most copies kept at a size; the least used go
    # first.
    PICTURES_KEPT = 32

    # Hands out a picture file of a mod, loaded once, or blurred once; with a size, cut from its
    # middle to that size's proportions and scaled to it once, so a part that draws it again copies
    # it instead of scaling it every time.
    #
    # @param file [String] The file, relative to the game folder, such as "Patch/Sample/close.png".
    # @param blurred [Boolean] Whether it is handed out blurred, such as a screenshot that shows a
    #   spoiler.
    # @param size [Array<Integer>, nil] The width and height to hand it out at, nil for its own.
    # @return [Bitmap, nil] The picture, nil for one that cannot be loaded, which is logged once.
    def self.picture(file, blurred = false, size = nil)
      return sized_picture(file, blurred, size) if size

      @pictures ||= {}
      key = [file, blurred ? true : false]
      picture = kept(@pictures, key)
      return picture if picture

      picture = Bitmap.new(file)
      BLUR_PASSES.times { picture.blur } if blurred && picture.respond_to?(:blur)
      keep(@pictures, key, picture)
    rescue => e
      Engine::Tree.log_once([:picture, file], "the picture #{file} cannot be loaded: #{Logging.failure(e)}")
      nil
    end

    # Hands out a picture file cut from its middle to a size's proportions and scaled to it, made
    # once from the picture of its file.
    #
    # @param file [String] The file, relative to the game folder.
    # @param blurred [Boolean] Whether it is handed out blurred.
    # @param size [Array<Integer>] The width and height.
    # @return [Bitmap, nil] The picture, nil for one that cannot be loaded or a size without room.
    def self.sized_picture(file, blurred, size)
      width, height = size.map { |side| side.to_i }
      return nil if width <= 0 || height <= 0

      @sized_pictures ||= {}
      key = [file, blurred ? true : false, width, height]
      sized = kept(@sized_pictures, key)
      return sized if sized

      source = picture(file, blurred)
      return nil unless source

      sized = Bitmap.new(width, height)
      sized.stretch_blt(sized.rect, source, cover_part(source.rect, width, height))
      keep(@sized_pictures, key, sized)
    end

    # Finds a kept picture and marks it the latest used.
    #
    # @param pictures [Hash] The kept pictures, the least used first.
    # @param key [Array] The picture's key.
    # @return [Bitmap, nil] The picture, nil for none or one that was freed.
    def self.kept(pictures, key)
      picture = pictures.delete(key)
      return nil unless picture && !picture.disposed?

      pictures[key] = picture
    end
    private_class_method :kept

    # Keeps a picture, letting go of the least used past PICTURES_KEPT; the collector frees one let
    # go once nothing draws it.
    #
    # A picture let go is never freed here, since a mod's sprite may still show it.
    #
    # @param pictures [Hash] The kept pictures, the least used first.
    # @param key [Array] The picture's key.
    # @param picture [Bitmap] The picture.
    # @return [Bitmap] The picture.
    def self.keep(pictures, key, picture)
      pictures[key] = picture
      pictures.shift while pictures.size > PICTURES_KEPT
      picture
    end
    private_class_method :keep

    # Lets go of the picture files and sized copies kept least long ago, as memory runs low; the
    # collector frees each once nothing draws or shows it.
    #
    # @param left [Integer] How many of each it keeps.
    # @return [Integer] How many it let go.
    def self.trim_pictures(left)
      [@pictures, @sized_pictures].compact.inject(0) do |gone, pictures|
        count = [pictures.size - left, 0].max
        count.times { pictures.shift }
        gone + count
      end
    end

    # Finds the part of a picture, from its middle, that has the proportions of a frame, so scaled
    # into the frame it fills it and what sticks out is cut.
    #
    # @param source [Rect] The picture's whole rectangle.
    # @param width [Integer] The frame's width.
    # @param height [Integer] The frame's height.
    # @return [Rect] The part.
    def self.cover_part(source, width, height)
      factor = [width.to_f / [source.width, 1].max, height.to_f / [source.height, 1].max].max
      part = [(width / factor).round, (height / factor).round].zip([source.width, source.height]).map { |want, have| [[want, have].min, 1].max }
      Rect.new((source.width - part[0]) / 2, (source.height - part[1]) / 2, part[0], part[1])
    end

    # Lets go of a picture file loaded by picture, plain and blurred and at every size, so its
    # memory is freed; it loads again when asked again.
    #
    # @param file [String] The file.
    def self.release_picture(file)
      (@sized_pictures || {}).keys.select { |key| key[0] == file }.each do |key|
        picture = @sized_pictures.delete(key)
        picture.dispose unless picture.disposed?
      end
      return unless @pictures

      [true, false].each do |blurred|
        picture = @pictures.delete([file, blurred])
        picture.dispose if picture && !picture.disposed?
      end
    end
  end
end
