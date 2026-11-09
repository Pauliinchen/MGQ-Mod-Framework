#----------------------------------------------------------------
#  adopt.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Sent the game window's padding as C#'s tree takes it, whatever of it gave way
#                            - Kept the game window's padding as fixed room, which no padding replaces
#      Paulinchen  2026-11-06: Removed the commands an adoption took off and put back, which only the split of plain Title scripts used
#                            - Removed UI.adopt, which mods no longer call
#                            - Removed the commands an adoption added, renamed or turned off, which nothing called
#                            - Took out the adoption of one window, undo and the components over an adopted window, which
#                              served only the old UI
#                            - Called the engine's classes by their names under UI::Engine
#                            - Took out the side windows of commands, which a window of the UI layer joined to a game window
#                              replaces
#                            - Gave a root beside a game window the keys as the pointer moves onto it
#      Paulinchen  2026-11-05: Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Asked again for a root beside a game window while none is open, and hid the window's cursor
#                              while the root beside it holds the keys
#                            - Greyed out the commands the game disables in the command windows it draws, as the framework's
#                              parts are, instead of see-through
#                            - Drew a command's badge in any color name of its window's look, an animated one anew while
#                              it shows
#      Paulinchen  2026-11-04: Listed the side windows of commands, which the UI Inspector finds under the pointer
#                            - Gave a side window of commands an id, which a UI.patch names it by
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Asked an added command's blocks with the window only when they take it
#                            - Placed a game window whose viewport was freed as on the screen
#                            - Showed one cursor between a side window of commands and its window, and let cancel in the side
#                              window do what it does in its window
#                            - Put a game command window with a heading beside an adopted window, reached by the arrows and the mouse
#                              and shared by every adoption of its class asking for the same side
#                            - Gave the game window the keys again after an added command, once the roots its block opened closed
#                            - Gave no keys back when F12 closed the roots an added command opened
#      Paulinchen  2026-10-31: Placed the picture of an adopted window as every root's is placed
#                            - Followed its game window under the name every root follows what it lies on by
#                            - Showed an added command only while its :if allows, the window's height and cursor following
#      Paulinchen  2026-10-30: Put a command removed from a game window back
#                            - Moved a root beside a command window above the window as the window comes near
#                            - Let the arrows reach a root beside a command window and come back
#                            - Drew a badge at the end of a button too
#                            - Kept a command window the framework made larger around its middle and on the screen
#                            - Drew a badge at the end of a command
#                            - Made a command list made before a change of the commands anew
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI

    # Tells where a game window's picture starts on the screen: its place plus its viewport's
    # offset, none for a viewport that was freed.
    #
    # @param window [Window_Base] The game window.
    # @return [Array<Integer>] Its left and top.
    def self.window_origin(window)
      viewport = window.viewport
      return [window.x, window.y] if viewport.nil? || UI.freed?(viewport)

      [window.x + viewport.rect.x - viewport.ox, window.y + viewport.rect.y - viewport.oy]
    end

    module Engine
      # The sprite the components of an adopted game window draw on: on the window's viewport, one
      # above the window, following its place, its opening and its contents' opacity.
      class OverlaySurface < SpriteSurface
        # Makes the hidden surface of a game window.
        #
        # @param window [Window_Base] The game window.
        def initialize(window)
          @window = window
          @on = false
          super(nil, window.viewport)
        end

        # Puts the surface at the place of its root and its sprite over the game window.
        #
        # @param x [Integer] The root's left on the screen, where its picture starts.
        # @param y [Integer] The root's top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param z [Integer] Its depth.
        # @param clip [Rect, nil] What may show of it, nil for all of it.
        # @param shift [Array<Integer>, nil] How far it is drawn from its place, nil for not at all.
        # @param opacity [Integer, nil] How opaque it is drawn, which follows its window's contents.
        def place(x, y, width, height, z, clip, shift = nil, opacity = nil)
          super
          follow_window
        end

        # Shows or hides the surface; it shows only while its game window shows whole.
        #
        # @param on [Boolean] Whether it shows.
        def show(on)
          @on = on
          follow_window
        end

        # Follows the game window by a frame.
        def update
          follow_window
        end

        private

        # Puts the sprite over the game window, as see-through as its contents.
        def follow_window
          return if @window.disposed?

          @sprite.x = @window.x
          @sprite.y = @window.y
          @sprite.opacity = @window.contents_opacity if @window.respond_to?(:contents_opacity)
          @sprite.visible = @on && @window.visible && @window.openness >= 255
        end
      end

      # The game windows of a class in the tree of components, made by Adopt.adopt: a root that lies
      # on the window of the class shown now, and the rule the class applies to each window of it.
      #
      # Events: close (when :closable and the player closes it).
      class Adopted < Component
        include Root

        # The component's kind in C#'s tree.
        KIND = "adopted"

        # Room a window that keeps its middle keeps from an edge of the screen it would stick out of.
        SCREEN_MARGIN = 8

        # The arrow that reaches a root beside a game window, and the way of the arrow back from it,
        # by the side the root lies on.
        SIDES = { :right => [:RIGHT, :left], :left => [:LEFT, :right] }

        # Room a root beside a game window keeps from the window and from the screen's top.
        SIDE_ROOM = 8

        # Tells the defaults of the options: the window's own depth, no press for a click, not
        # closable, holding none of the game's buttons, placed and sized as the game does.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:z => nil, :click => nil, :right_click => nil, :closable => false, :captures => false, :keep_center => false)
        end

        options :click, :right_click, :keep_center

        # @return [Class] The game window class it adopts.
        attr_reader :target

        # @return [Window_Base, nil] The game window it lies on now, nil before the first.
        attr_reader :window

        # Makes the adopted window of a target; Adopt.adopt makes it.
        #
        # @param target [Class] A game window class.
        # @param options [Hash] Its options, see Adopt.adopt.
        def initialize(target, options = {})
          super(options)
          @target = target

          @sides = []
          @window = nil
          @arranged = false
        end

        # Tells that an adopted window is only ever a root.
        #
        # @return [Boolean] Always true.
        def root_only?
          true
        end

        # Tells whether it applies to a game window: one of its class.
        #
        # @param window [Window_Base] The game window.
        # @return [Boolean] Whether it does.
        def applies_to?(window)
          window.is_a?(@target)
        end

        # Tells whether it lies on a game window that is not disposed.
        #
        # @return [Boolean] Whether it does.
        def bound?
          @window && !@window.disposed? ? true : false
        end

        # Puts it on a game window: moves, sizes and dresses the window by its options, gives the
        # window its commands' handlers and opens it in the tree where it needs to be there.
        #
        # @param window [Window_Base] The game window.
        def bind(window)
          return if @window.equal?(window) && bound?

          unbind if @window
          @window = window
          @arranged = false
          place_window
          Adopted.keep_on_screen(window) if keep_center? && !@options[:at]
          window.ui_theme = @options[:theme] unless @options[:theme].nil?
          window.instance_variable_set(:@mf_mouse_off, true) if @options[:mouse] == false
          @home = [window.x, window.y, window.width, window.height]
          @followed = nil
          open_on_window
        rescue => e
          mod_log("adopting a #{window.class} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Takes it off its game window.
        def unbind
          teardown(false) if open?
          @window = nil
        end

        # Puts a root of yours beside the game window on its way of the keys, such as a box of
        # buttons in a corner of the title: the arrow toward the root on a command that has nothing
        # that way, or the pointer moving onto the root, gives a part of the root the focus, and the
        # root holds the game's buttons while it has the focus, the window taking none; the arrow
        # back that finds nothing in the root, cancel, or the pointer moving onto the window gives
        # the window the input again. The root shows only while the window shows whole.
        #
        # @param side [Symbol] Where the root lies: :right or :left, the arrows a list of one column
        #   leaves alone.
        # @yield [window] Makes and opens the root, not closable, as a window of the adoption first
        #   updates, such as each time a scene that shows it starts.
        # @yieldreturn [Component] The part of the root that takes the focus.
        # @return [Adopted] Itself.
        def add_side(side = :right, &make)
          raise ArgumentError, "#{side.inspect} is no side: :right or :left" unless SIDES.key?(side)

          @sides << { :make => make, :made_for => nil, :part => nil, :side => side, :holding => false, :entering => nil, :letting_go => false, :home => nil }
          self
        end

        # Follows the roots beside the game window before its update: each shows while the window
        # shows whole and keeps clear of it; one that has the focus takes the input from the window,
        # which gets it back once the focus left the root or the pointer moves onto the window; the
        # arrow toward a root, or the pointer moving onto it, gives its part the focus.
        #
        # @param window [Window_Base] The game window.
        def follow_sides(window)
          return if @sides.empty? || !window.equal?(@window)

          shown = window_shown?
          @sides.each do |side|
            root = side_root(side, window)
            next unless root

            root.visible = shown unless root.visible == shown
            give_way(side, window, root)
            follow_side(side, window, shown)
          end
        end

        # Tells the open root beside the window, made once for each window and asked for again while
        # none is open, as a window joined to it opens later or anew.
        #
        # @param side [Hash] The root's maker, part and side.
        # @param window [Window_Base] The game window.
        # @return [Component, nil] The root; nil when it closed or the maker made none, which is logged
        #   once.
        def side_root(side, window)
          unless side[:made_for].equal?(window) && side[:part] && side[:part].root.open?
            side.update(:made_for => window, :part => nil, :holding => false, :entering => nil, :letting_go => false, :home => nil)
            side[:part] = make_side(side, window)
          end
          side[:part] && side[:part].root.open? ? side[:part].root : nil
        end

        # Makes the root beside a window and has it tell an arrow that found nothing in it.
        #
        # @param side [Hash] The root's maker and side.
        # @param window [Window_Base] The game window.
        # @return [Component, nil] The part that takes the focus; nil when the maker made no open root.
        def make_side(side, window)
          part = UI.call_with(side[:make], window)
          return nil unless part.respond_to?(:root) && part.root.open?

          part.root.on(:leave) { |way| leave_side(side, way) }
          part
        rescue => e
          mod_log("the root beside a #{window.class} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}") if Logging.first_time?(Adopt, [:side, window.class, e.class])
          nil
        end

        # Keeps a root beside the game window clear of it: a root the window comes within SIDE_ROOM of,
        # such as a title window a translation or more commands made wider, stands SIDE_ROOM above the
        # window's top instead, keeping its own left edge and SIDE_ROOM from the screen's top, and goes
        # back where it was made once the window leaves it room.
        #
        # @param side [Hash] The root's part and the place it was made at.
        # @param window [Window_Base] The game window.
        # @param root [Component] The root.
        def give_way(side, window, root)
          home = side[:home] ||= UI.point(root.at)
          size = UI.pair(root.size)
          return unless home && size && size[0] && size[1]

          left, top = UI.window_origin(window)
          near = home[0] < left + window.width + SIDE_ROOM && left < home[0] + size[0] + SIDE_ROOM &&
                 home[1] < top + window.height + SIDE_ROOM && top < home[1] + size[1] + SIDE_ROOM
          at = near ? [home[0], [top - SIDE_ROOM - size[1], SIDE_ROOM].max] : home
          root.at = at unless UI.point(root.at) == at
        end

        # Follows one root beside the game window, see follow_sides.
        #
        # @param side [Hash] The root's part and side, and whether it holds the input.
        # @param window [Window_Base] The game window.
        # @param shown [Boolean] Whether the window shows whole.
        def follow_side(side, window, shown)
          holds = shown && focus_in?(side[:part].root)
          side[:letting_go] &&= holds
          if holds && !side[:holding] && !side[:letting_go]
            hold_side(side, window)
          elsif side[:holding] && !holds
            release_side(side, window, shown && Tree.focused.nil?)
          elsif side[:holding] && pointer_onto?(window)
            let_go(side, window)
          elsif side[:entering] && !holds && Key.frame - side[:entering] > 1
            side[:entering] = nil
            window.activate
          elsif shown && window.active && !side[:holding] && ::Input.repeat?(SIDES[side[:side]][0])
            enter_side(side, window, true)
          elsif shown && window.active && !side[:holding] && pointer_over?(side[:part].root)
            enter_side(side, window, false)
          end
        end

        # Gives the part of a root beside the window the focus, as the arrow toward it went down,
        # with the cursor sound, or quietly as the pointer moved onto the root.
        #
        # @param side [Hash] The root's part and side.
        # @param window [Window_Base] The game window.
        # @param sound [Boolean] Whether the cursor sound plays.
        def enter_side(side, window, sound)
          window.deactivate
          Sound.play_cursor if sound
          side[:entering] = Key.frame
          side[:part].focus
        end

        # Lets a root beside the window that took the focus hold the input; the window waits without
        # its cursor, keeping its index.
        #
        # @param side [Hash] The root's part and side.
        # @param window [Window_Base] The game window.
        def hold_side(side, window)
          side[:holding] = true
          side[:entering] = nil
          side[:part].root.captures = true
          window.deactivate
          window.cursor_rect.empty if window.respond_to?(:cursor_rect)
        end

        # Gives the input back from a root beside the window.
        #
        # @param side [Hash] The root's part and side.
        # @param window [Window_Base] The game window.
        # @param activate [Boolean] Whether the window takes it, rather than another root that took
        #   the focus or a scene that hid the window.
        def release_side(side, window, activate)
          side[:holding] = false
          side[:part].root.captures = false
          window.activate if activate
          window.update_cursor if activate && window.respond_to?(:update_cursor)
        end

        # Follows an arrow that found nothing in a root beside the window: the arrow back gives the
        # window the input again.
        #
        # @param side [Hash] The root's part and side.
        # @param way [Symbol] The arrow's way: :left, :right, :up or :down.
        def leave_side(side, way)
          return unless side[:holding] && way == SIDES[side[:side]][1] && bound?

          Sound.play_cursor
          let_go(side, @window)
        end

        # Takes the focus off a root beside the window and gives the window the input, the root
        # left alone until C#'s tree took the focus off it.
        #
        # @param side [Hash] The root's part and side.
        # @param window [Window_Base] The game window.
        def let_go(side, window)
          Tree.focused.blur if Tree.focused
          side[:letting_go] = true
          release_side(side, window, true)
        end

        # Tells whether the focus lies in a root.
        #
        # @param root [Component] The root.
        # @return [Boolean] Whether it does.
        def focus_in?(root)
          focused = Tree.focused
          focused && focused.root.equal?(root) ? true : false
        end

        # Tells whether the pointer moved onto the game window or clicked it in this frame.
        #
        # @param window [Window_Base] The game window.
        # @return [Boolean] Whether it did.
        def pointer_onto?(window)
          Adopted.pointer_onto?(window)
        end

        # Tells whether the pointer moved over a root beside the window in this frame.
        #
        # @param root [Component] The root.
        # @return [Boolean] Whether it did.
        def pointer_over?(root)
          Mouse.moved? && Tree.over.equal?(root) ? true : false
        end

        # Tells whether the pointer moved onto a game window or clicked it in this frame.
        #
        # @param window [Window_Base] The game window.
        # @return [Boolean] Whether it did.
        def self.pointer_onto?(window)
          position = Mouse.position
          return false unless position && (Mouse.moved? || Mouse.clicked?)

          left, top = UI.window_origin(window)
          position[0] >= left && position[1] >= top && position[0] < left + window.width && position[1] < top + window.height
        end

        # Tells whether a window it lies on keeps its middle as the framework sizes it, and stays on
        # the screen.
        #
        # @return [Boolean] Whether it does.
        def keep_center?
          @options[:keep_center] ? true : false
        end

        # Moves a game window that sticks out over an edge of the screen inside it, SCREEN_MARGIN
        # from that edge; a window inside the screen stays where it is.
        #
        # @param window [Window_Base] The game window.
        def self.keep_on_screen(window)
          width = Graphics.width
          height = Graphics.height
          window.x = UI.within(window.x, SCREEN_MARGIN, width - SCREEN_MARGIN - window.width) if window.x < 0 || window.x + window.width > width
          window.y = UI.within(window.y, SCREEN_MARGIN, height - SCREEN_MARGIN - window.height) if window.y < 0 || window.y + window.height > height
        end

        # Tells whether it shows: visible itself and its game window showing whole.
        #
        # @return [Boolean] Whether it does.
        def visible?
          @options[:visible] && window_shown? ? true : false
        end

        # Tells its depth: one above its game window.
        #
        # @return [Integer] The depth, 0 before it lies on one.
        def z
          bound? ? @window.z + 1 : 0
        end

        # Follows its game window before the frame's layout: a place the player arranged moves the
        # window there, and the window's place, size, depth and whether it shows go to C#'s tree when
        # they changed; a disposed window takes it off the tree.
        def follow_place
          return unbind unless bound?

          follow_arranged
          now = [screen_x, screen_y, @window.width, @window.height, window_shown?, @window.z, padding_prop]
          return if now == @followed

          @followed = now
          Tree.set(self, "at" => now[0, 2], "size" => now[2, 2], "visible" => visible?, "z" => z, "padding" => now[6])
        end

        # Tells the properties C#'s tree lays it out by: the game window's place and size.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["at"] = bound? ? [screen_x, screen_y] : nil
          props["center"] = false
          props["z"] = z
          props
        end

        # Tells the viewport the pictures of the parts it scrolls lie on: its game window's, so they
        # show over the window.
        #
        # @return [Viewport, nil] The viewport, nil for the screen.
        def surface_viewport
          bound? ? @window.viewport : nil
        end

        # Tells where the game window's picture starts on the screen.
        #
        # @return [Integer] Its left.
        def screen_x
          UI.window_origin(@window)[0]
        end

        # Tells where the game window's picture starts on the screen.
        #
        # @return [Integer] Its top.
        def screen_y
          UI.window_origin(@window)[1]
        end

        private

        # Tells whether its game window shows whole: visible and open.
        #
        # @return [Boolean] Whether it does.
        def window_shown?
          bound? && @window.visible && @window.openness >= 255
        end

        # Opens it in the tree once it lies on a game window and has something to do there: a place
        # the player arranges.
        def open_on_window
          return if open? || !bound?
          return unless @options[:movable] || resize_option != false

          open
        end

        # Moves and sizes the game window by its options, within its least and most size.
        def place_window
          at = UI.point(@options[:at])
          @window.x, @window.y = at if at
          size = UI.pair(@options[:size])
          resize_window(size[0] || @window.width, size[1] || @window.height) if size
          @window.z = @options[:z].to_i unless @options[:z].nil?
        end

        # Sizes the game window within its least and most size and draws its contents anew.
        #
        # @param width [Integer] The width.
        # @param height [Integer] The height.
        def resize_window(width, height)
          least = UI.pair(@options[:min_size]) || [nil, nil]
          most = UI.pair(@options[:max_size]) || [nil, nil]
          width = [[width, least[0] || 0].max, most[0] || width].min
          height = [[height, least[1] || 0].max, most[1] || height].min
          return if width == @window.width && height == @window.height

          @window.width = width
          @window.height = height
          @window.create_contents if @window.respond_to?(:create_contents)
          @window.refresh if @window.respond_to?(:refresh)
        end

        # Moves the game window to the place the player arranged, or back to where it started once
        # the player put it back.
        def follow_arranged
          return unless @registered && bound? && @rect

          if Layout.moved?(place_id) || Layout.arranging?
            @window.x += @rect.x - screen_x
            @window.y += @rect.y - screen_y
            resize_window(@rect.width, @rect.height) if resize_option != false
            @arranged = true
          elsif @arranged
            @window.x, @window.y = @home[0, 2]
            resize_window(@home[2], @home[3])
            @arranged = false
          end
        end

        # Gives a game window the keys again after a command's block ran: once every root the block
        # opened, and the root it answers, closed; at once when none of them is open; never when the
        # block answers :off.
        #
        # @param window [Window_Base] The game window.
        # @param answer [Object] What the block answered.
        # @param before [Array<Component>] The roots open before the block ran.
        def self.give_back_after(window, answer, before)
          return if answer == :off

          opened = Tree.roots.reject { |root| before.any? { |each| each.equal?(root) } }
          opened << answer.root if answer.is_a?(Component) && opened.none? { |root| root.equal?(answer.root) }
          opened = opened.select { |root| root.open? }
          return give_back(window) if opened.empty?

          given = false
          opened.each do |root|
            root.on(:close) do |why|
              next if why == :reset || given || opened.any? { |each| each.open? }

              given = true
              give_back(window)
            end
          end
        end

        # Lets a game window take the keys again, unless it went, such as at a scene change, and
        # shows the one cursor on it.
        #
        # @param window [Window_Base] The game window.
        def self.give_back(window)
          return unless window.respond_to?(:activate) && !(window.respond_to?(:disposed?) && window.disposed?)

          window.activate
          window.send(:update_cursor) if window.respond_to?(:update_cursor, true)
        end

        # Tells the room the game window's padding takes around its contents.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          return [0, 0, 0, 0] unless bound?

          padding = @window.padding
          bottom = @window.respond_to?(:padding_bottom) ? @window.padding_bottom : padding
          [padding, padding, bottom, padding]
        end

        # Tells its fixed size: the game window's.
        #
        # @return [Array<Integer>, nil] Its width and height, nil before it lies on a window.
        def fixed_size
          bound? ? [@window.width, @window.height] : nil
        end

        # Tells the depth its pictures start from: one above its game window.
        #
        # @return [Integer] The depth.
        def depth_base
          z
        end

        # Makes its picture: a sprite over its game window.
        #
        # @return [OverlaySurface] The picture.
        def make_base
          OverlaySurface.new(@window)
        end

        # Follows a changed option on the game window it lies on.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless bound?

          case name
          when :at, :size, :z then place_window
          when :theme then @window.ui_theme = @options[:theme]
          when :mouse then @window.instance_variable_set(:@mf_mouse_off, @options[:mouse] == false ? true : nil)
          end
          open_on_window
        end

        # Closes it as C# closed it on cancel, and its game window with it.
        def closed_by_player
          window = @window
          super
          return unless window && !window.disposed?

          window.deactivate if window.respond_to?(:deactivate)
          window.close if window.respond_to?(:close)
        end

        # Takes it out of the tree and frees its pictures; the game's buttons stay the game's, since
        # it never held them.
        #
        # @param removed [Boolean] Whether C# removed it already.
        def teardown(removed)
          @open = false
          Tree.close_root(self, removed)
          Capture.stop(self)
          release_surfaces
        end
      end

      # A badge at the end of a command of a game window or of a button: a count on a dark plate, or a
      # dot.
      module Badge
        # The highest count a badge shows; more shows as this count and a "+".
        MOST = 9

        # The room a badge takes at the end of its command, kept while it shows nothing.
        ROOM = 26

        # The plate's width and height.
        WIDTH = 22
        HEIGHT = 18

        # The side of a dot.
        DOT = 8

        # The plate under a count, black at 70 %.
        PLATE = Color.new(0, 0, 0, 178)

        # Tells what a badge's value shows: a count above 0, "9+" above 9, or a dot for true.
        #
        # @param value [Object] The value, such as a count.
        # @return [String, nil] The text, "" for a dot, nil for nothing.
        def self.text_of(value)
          return "" if value == true
          return nil unless value.is_a?(Integer) && value > 0

          value > MOST ? "#{MOST}+" : value.to_s
        end

        # Draws a badge at the end of a room of a component.
        #
        # @param canvas [Canvas] Where it draws.
        # @param right [Integer] Where the room ends in the component.
        # @param y [Integer] The room's top.
        # @param height [Integer] Its height.
        # @param text [String] The count, "" for a dot.
        # @param color [Symbol, Color] Its color: a text color's name, such as :gold, or a Color.
        def self.draw_on(canvas, right, y, height, text, color)
          left = right - WIDTH
          return canvas.fill(left + (WIDTH - DOT) / 2, y + (height - DOT) / 2, DOT, DOT, color) if text.empty?

          top = y + (height - HEIGHT) / 2
          canvas.fill(left, top, WIDTH, HEIGHT, PLATE)
          canvas.text(left, top, WIDTH, HEIGHT, text, :size => :small, :color => color, :align => :center)
        end

        # Draws a badge at the end of a command's room on its window's contents, in a color name of
        # the window's palette; one in an animated color takes its color now and draws anew every few
        # frames while the window shows.
        #
        # @param window [Window_Selectable] The window.
        # @param index [Integer] The command's row.
        # @param rect [Rect] The command's room.
        # @param text [String] The count, "" for a dot.
        # @param color [Symbol, String, Array, Integer, Color] Its color: a color name, such as :gold
        #   or :rainbow, "#RRGGBB", [r, g, b(, a)], a game text color or a Color.
        def self.draw(window, index, rect, text, color)
          color = color_in(window, index, color)
          bitmap = window.contents
          right = rect.x + rect.width
          y = rect.y
          height = rect.height
          left = right - WIDTH
          return bitmap.fill_rect(left + (WIDTH - DOT) / 2, y + (height - DOT) / 2, DOT, DOT, color) if text.empty?

          top = y + (height - HEIGHT) / 2
          bitmap.fill_rect(left, top, WIDTH, HEIGHT, PLATE)
          size = bitmap.font.size
          before = bitmap.font.color
          bitmap.font.size = Style::SMALL_SIZE
          bitmap.font.color = color
          bitmap.draw_text(left, top, WIDTH, HEIGHT, text, 1)
          bitmap.font.size = size
          bitmap.font.color = before
        end

        # Finds a badge's color in its window's look; an animated name notes the row, which draws
        # anew while the window shows.
        #
        # @param window [Window_Selectable] The window.
        # @param index [Integer] The command's row.
        # @param color [Object] The color, see draw.
        # @return [Color] The color, gold for a name nobody named.
        def self.color_in(window, index, color)
          return UI.text_color(color) if color.is_a?(Integer)
          return Colors.color_of(color) || Style::GOLD unless color.is_a?(Symbol) || (color.is_a?(String) && !color.start_with?("#"))

          palette = Theme.palette_for(window)
          Colors.note_row(window, index) if palette.animated(color.to_sym)
          palette.now(color.to_sym) || Style::GOLD
        end
        private_class_method :color_in
      end

      # The adoptions of the mods: each class rule applied as a window of its class is made, at the
      # latest at its first update, and the commands of every adoption kept in their lists. The hooks
      # go onto the classes at the game's run, since the game's plugins define some of their methods
      # again as they load, and they work without the DLL; only the components need it.
      module Adopt
        # Who the hooks are registered by.
        TAG = "Mod Framework adopt"

        # Who the hooks that grey out disabled commands are registered by.
        GREY_TAG = "Mod Framework greyed commands"

        # The adoptions, in the order the mods made them.
        @rules = []

        # The classes whose methods carry the hooks, each true.
        @classes = {}

        # The command window classes that grey out their disabled commands, each true.
        @greyed_classes = {}

        # Whether the game runs, so new rules hook their class at once.
        @started = false


        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "adopt"

        # Puts the game windows of a class into the tree of components: they take the options a
        # root takes. The class is a rule for every window of it, applied as each one is made.
        #
        # @param target [Class] A game window class, such as Window_TitleCommand.
        # @param options [Hash] The options of a root (:at, :size, :min_size, :max_size, :resizable,
        #   :movable, :id, :theme, :closable, :z, :visible, :mouse, :layout and the other container
        #   options), :click and :right_click (a game button, such as :C, that a click on a window
        #   which reads Input itself presses for its update), :keep_center (true: a window the
        #   framework makes wider or taller keeps its middle where it was, and one that sticks out
        #   of the screen moves inside it), :log.
        # @return [Adopted] The adoption.
        def self.adopt(target, options = {})
          rule = Adopted.new(target, options)
          unless window_class?(target)
            log_once([:target, target.inspect[0, 80]], "#{target.inspect[0, 80]} is no game window class, so it is not adopted")
            return rule
          end

          @rules << rule
          install(target) if @started
          rule
        end

        # Tells whether the game runs.
        #
        # @return [Boolean] Whether it does.
        def self.started?
          @started
        end

        # Lists the adoptions.
        #
        # @return [Array<Adopted>] The adoptions.
        def self.rules
          @rules.dup
        end

        # Hooks every adopted class, once the game runs.
        def self.start
          @started = true
          @rules.map { |rule| rule.target }.uniq.each { |klass| install(klass) }
          log("#{@rules.size} adopted game #{@rules.size == 1 ? 'window' : 'windows'} in place") unless @rules.empty?
        end

        # Hooks a game window class, once: its windows are adopted as they are made, their update
        # presses the buttons of a click, and a command window's list takes the commands added.
        #
        # @param klass [Class] The class.
        def self.install(klass)
          return if @classes[klass]

          @classes[klass] = true
          Hooks.after(klass, :initialize, TAG) { |*_args| Mod_Framework::UI::Engine::Adopt.made(self) }
          Hooks.around(klass, :update, TAG) { |window, _args, original| Mod_Framework::UI::Engine::Adopt.update(window, original) }
          return unless klass.method_defined?(:make_command_list)

          Hooks.after(klass, :make_command_list, TAG) { Mod_Framework::UI::Engine::Adopt.edit_commands(self) }
          Hooks.around(klass, :draw_item, TAG) { |window, args, original| Mod_Framework::UI::Engine::Adopt.draw_item(window, original) }
          grey_disabled(klass)
        end

        # Has a command window class grey out the commands the game disables while the framework
        # draws its rows, as the framework's parts are, rather than draw them see-through.
        #
        # @param klass [Class] The window's class.
        def self.grey_disabled(klass)
          return if @greyed_classes[klass]

          @greyed_classes[klass] = true
          Hooks.around(klass, :change_color, GREY_TAG) { |window, args, original| Mod_Framework::UI::Engine::Adopt.greyed_color(window, args, original) }
          Hooks.around(klass, :draw_icon, GREY_TAG) { |window, args, original| Mod_Framework::UI::Engine::Adopt.greyed_icon(window, args, original) }
        end

        # Draws a row of a command window with its disabled text and icons greyed out.
        #
        # @param window [Window_Command] The window.
        # @yield Draws the row.
        # @return [Object] What the block returns.
        def self.greying(window)
          before = window.instance_variable_get(:@mf_greyed)
          window.instance_variable_set(:@mf_greyed, Theme.greyed_for(window))
          begin
            yield
          ensure
            window.instance_variable_set(:@mf_greyed, before)
          end
        end

        # Sets the color of a text a row draws: a disabled one in its grey and opaque while the row
        # greys, any other as the game does.
        #
        # @param window [Window_Base] The window.
        # @param args [Array] The color and whether it is enabled.
        # @param original [Proc] Sets it as the game does.
        # @return [Object] What setting it returns.
        def self.greyed_color(window, args, original)
          greyed = window.instance_variable_get(:@mf_greyed)
          return original.call if greyed.nil? || args.size < 2 || args[1]

          original.call(greyed.drawn_text(args[0]), true)
        end

        # Draws an icon of a row: a disabled one from its greyed copy, opaque, while the row greys, any
        # other as the game does.
        #
        # @param window [Window_Base] The window.
        # @param args [Array] The icon, its left and top, and whether it is enabled.
        # @param original [Proc] Draws it as the game does.
        # @return [Object] What drawing it returns.
        def self.greyed_icon(window, args, original)
          greyed = window.instance_variable_get(:@mf_greyed)
          return original.call if greyed.nil? || args.size < 4 || args[3]

          source, part = greyed.icon_source(args[0])
          window.contents.blt(args[1], args[2], source, part)
        end

        # Adopts a game window of an adopted class as it is made.
        #
        # @param window [Window_Base] The window.
        def self.made(window)
          window.instance_variable_set(:@mf_made, true)
          @rules.each { |rule| rule.bind(window) if rule.applies_to?(window) }
        end

        # Runs a game window's update: a window of an adopted class made before its rule is adopted
        # now, the roots beside it follow it, and a click on a window that reads Input itself presses
        # its button for the update.
        #
        # @param window [Window_Base] The window.
        # @param original [Proc] Runs the update.
        # @return [Object] What the update returns.
        def self.update(window, original)
          rules = @rules.select { |rule| rule.applies_to?(window) }
          return original.call if rules.empty?

          rules.each { |rule| rule.bind(window) unless rule.bound? }
          rules.each { |rule| rule.follow_sides(window) }
          buttons = GameMouse.clicks_on(window, rules)
          buttons.empty? ? original.call : GameMouse.pressing(window, buttons) { original.call }
        end

        # Sizes a window made before anew as its make_command_list ends, where an adoption keeps its
        # middle.
        #
        # @param window [Window_Command] The window.
        def self.edit_commands(window)
          rules = @rules.select { |rule| rule.applies_to?(window) }
          return unless window.instance_variable_get(:@mf_made)

          refit(window) if rules.any? { |rule| rule.keep_center? }
        rescue => e
          log_once([:commands, window.class, e.class], "adding the commands of a #{window.class} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Sizes a window made before anew as its list now asks, keeping its middle where it was and
        # the window on the screen; the game's refresh then makes its contents of the new size.
        #
        # @param window [Window_Command] The window.
        def self.refit(window)
          return unless window.respond_to?(:window_width) && window.respond_to?(:window_height)

          width = window.window_width
          height = window.window_height
          return if width == window.width && height == window.height

          middle = [window.x + window.width / 2, window.y + window.height / 2]
          window.width = width
          window.height = height
          window.x = middle[0] - width / 2
          window.y = middle[1] - height / 2
          Adopted.keep_on_screen(window)
        end
        private_class_method :refit

        # Draws a row of a command window as the game draws it, a disabled one greyed out.
        #
        # @param window [Window_Command] The window.
        # @param original [Proc] Draws the row as the game does.
        # @return [Object] What the drawing returns.
        def self.draw_item(window, original)
          greying(window) { original.call }
        end

        # Tells whether a target can be adopted: a game window class.
        #
        # @param target [Object] The target.
        # @return [Boolean] Whether it can.
        def self.window_class?(target)
          defined?(::Window_Base) && target.is_a?(Module) && target <= ::Window_Base ? true : false
        end
        private_class_method :window_class?

        Run.on_start("adopt") { Mod_Framework::UI::Engine::Adopt.start }
      end
    end
  end
end
