#----------------------------------------------------------------
#  roots_windows.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Freed a tooltip's old picture only once its sprite shows the new one
#                            - Made a window's own look anew only when its background, border or border width changes
#                            - Drew a box's background and border by its params, the theme's back and frame by default, and let its padding replace its room
#                            - Let a window's padding replace its room and kept the game window's own padding within it
#      Paulinchen  2026-11-07: Laid a tooltip on a side where it does not fit on the other sides before it covers its part
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A part a component scrolls, on a picture of its own: what a Box scrolls.
      class Component
        # Tells whether it scrolls what it holds on a picture of its own.
        #
        # @return [Boolean] Whether it does.
        def scrolls_part?
          false
        end

        # Draws on the picture of the part it scrolls, after what it holds: its scrollbar.
        #
        # @param _canvas [Canvas] Where it draws.
        def draw_part(_canvas)
          nil
        end
      end

      # A root with the game's window frame: an RGSS window underneath, worn in its theme (the game's
      # own skin and tone with theme false), its background as opaque as its theme makes it or as its
      # :back_opacity, an optional title row with an icon, and the components it holds in a column
      # unless its layout says otherwise. It takes the game's buttons while it is open, closes on
      # Escape, cancel and the numpad's 0 and when its scene ends. With :frame => false it draws
      # neither frame nor background and keeps no room for them, so the framed boxes it holds are
      # what shows, as a screen of the game's windows side by side.
      #
      # Events: close, page (step, pad: the game's L or R, -1 or 1, that the part with the focus did
      # not use and no text field typed, and whether a gamepad pressed it, see Pad).
      class Window < Component
        include Container
        include Root

        # The component's kind in C#'s tree.
        KIND = "window"

        # Room between the window's edge and what it holds, the game's own window padding.
        PADDING = 12

        # Tells the defaults of the options: closable, holding the buttons, below the floating boxes.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:z => 200, :closable => true, :captures => true, :min_size => [96, 48], :title => nil, :icon => nil, :icon_file => nil, :back_opacity => nil,
                      :frame => true)
        end

        # Tells which properties of C#'s tree each option sets, the title row's room among them.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:title => ["padding", "layout_id"], :icon => ["padding"], :icon_file => ["padding"], :frame => ["padding"])
        end

        options :title, :icon, :icon_file, :back_opacity, :frame

        # Tells that a Window is only ever a root.
        #
        # @return [Boolean] Always true.
        def root_only?
          true
        end

        # Draws its title row; the game draws its frame and background, worn in its own border and
        # background where it has them (see Frame).
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_container(canvas)
          top, right, _bottom, left = edge_sides
          draw_title(canvas, left, top, canvas.width - left - right) if titled?
        end

        # Tells the least room its frame keeps on any side, which the game window's own padding stays
        # within; asked every frame, so it makes no Arrays without a :padding.
        #
        # @return [Integer] The pixels.
        def frame_room
          room = @options[:padding].nil? ? (framed? ? PADDING : 0) : sides_of(@options[:padding]).min
          room + (framed? ? 0 : border_px)
        end

        # Tells the background, the border and the border's width its game window wears in its skin
        # (Frame#wear_own_look): nil while it has neither. A skin stretches its background over the
        # whole window, so a fade is left out and logged. Asked every frame, so it tells the same
        # look until one of those options is another object.
        #
        # @return [Array, nil] The background, the border and its width; nil for the theme's skin.
        def skin_look
          background = @options[:background]
          border = @options[:border]
          width = @options[:border_width]
          given = @skin_look_of
          return @skin_look if given && given[0].equal?(background) && given[1].equal?(border) && given[2].equal?(width)

          @skin_look_of = [background, border, width]
          @skin_look = new_skin_look(background, border, width)
        end

        # Tells how opaque its game window draws its own background: the alpha of its color, 0 for
        # false; nil to follow its theme.
        #
        # @return [Integer, nil] The opacity.
        def skin_back_opacity
          look = skin_look
          background = look && look[0]
          return nil if background.nil? || background == :theme
          return 0 if background == false

          background.is_a?(Color) ? background.alpha.to_i : OPAQUE
        end

        private

        # Makes the look skin_look tells from its options.
        #
        # @param background [Object, nil] Its :background.
        # @param border [Object, nil] Its :border.
        # @param width [Numeric, nil] Its :border_width.
        # @return [Array, nil] The background, the border and its width; nil for the theme's skin.
        def new_skin_look(background, border, width)
          return nil if background.nil? && border.nil?

          if background.is_a?(Hash)
            if background[:fade] && Logging.first_time?(Tree, [:skin_fade, @options[:id]])
              mod_log("#{describe} drew its background without its fade: the game's frame shows no fade; frame: false draws it")
            end
            background = background[:color]
          end
          [background, border, width.nil? ? 1 : UI.whole(width)]
        end

        # Tells whether it draws the game's window frame and background.
        #
        # @return [Boolean] Whether it does.
        def framed?
          @options[:frame] == false ? false : true
        end

        # Makes its picture: the contents of its game window, or a plain picture without a frame.
        #
        # @return [WindowSurface, SpriteSurface] The picture.
        def make_base
          framed? ? WindowSurface.new(self) : SpriteSurface.new(nil, surface_viewport)
        end

        # Follows a changed option: a window that gains or loses its frame makes its picture anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless name == :frame && @base

          @base.dispose
          @base = nil
        end

        # Tells the room its frame keeps around what it holds, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          edge = framed? ? PADDING : 0
          [edge, edge, edge, edge]
        end

        # Tells the room its title row takes.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [title_room, 0, 0, 0]
        end

        # Tells the room its border takes: none while it wears the game's frame, whose skin draws the
        # border inside its own room.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def border_room
          framed? ? NO_ROOM : super
        end

        # Tells whether its game window paints its background, worn in its skin.
        #
        # @return [Boolean] Whether it does.
        def own_back?
          framed?
        end

        # Tells whether its game window paints its border, worn in its skin.
        #
        # @return [Boolean] Whether it does.
        def own_edge?
          framed?
        end
      end

      # What a root that opens from a part of another root shares, such as a select's list or a
      # menu behind a button: it lies above every window and dialog (Popup.depth), and with that
      # part as its :opened_from it closes and moves with that part's root (see Root).
      module Popup
        # Tells the depth a popup opens at: in the popups' band above every window and dialog, above
        # the popups open, such as a menu over a select's list, and above the root it opens from
        # should that lie higher still.
        #
        # @param opener [Component, nil] The part it opens from, nil for none.
        # @return [Integer] The depth.
        def self.depth(opener)
          band = BANDS[:popups]
          open = Tree.roots.map { |root| root.respond_to?(:z) ? root.z.to_i : 0 }.select { |z| band.include?(z) }
          above = open.empty? ? band.first : UI.within(open.max + 1, band.first, band.last)
          root = opener.respond_to?(:root) && opener.root
          root ? [above, root.z.to_i + 1].max : above
        end

        # Tells the top left of a root on the screen.
        #
        # @param root [Component] The root.
        # @return [Array<Integer>, nil] Its left and top, nil before C# placed it.
        def self.top_left(root)
          rect = root.rect
          rect && [rect.x, rect.y]
        end
      end

      # A modal Window: centered, above every other root but the confirm, the roots below it taking no
      # input, the game's buttons held.
      #
      # Events: close, page (see Window).
      class Dialog < Window
        # The component's kind in C#'s tree.
        KIND = "dialog"

        # Tells the defaults of the options: centered, above the boxes.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:z => 1040, :center => true)
        end

        # Tells that the roots below it take no input while it shows.
        #
        # @return [Boolean] Always true.
        def modal?
          true
        end
      end

      # A panel: framed in the theme's look, or plain with :frame => false, scrolling what it holds by
      # the wheel, its scrollbar and the keys with :scroll => true; with :keep_ends => true UP at its
      # top and DOWN at its end keep the focus in it. With no parent it is a root, a floating panel on
      # the screen, which holds no buttons and does not close on cancel unless told.
      #
      # Events: close (as a root), scroll (lines: the lines of its texts in sight changed as it
      # scrolled, see lines_in_view; told only while a block listens).
      class Box < Component
        include Container
        include Root

        # The component's kind in C#'s tree.
        KIND = "box"

        # Pixels a box's frame takes on each side, for every preset, so the room inside stays the same
        # whichever the player picks.
        FRAME = 2

        # Room between a framed box's edge and what it holds.
        ROOM = FRAME + Style::PAD

        # Room between what a box scrolls and its scrollbar.
        BAR_GAP = 2

        # Room between the edge of a box without a frame that takes the focus and what it holds,
        # where the frame it shows while it has the focus draws.
        FOCUS_ROOM = Style::GAP

        # The least size of a floating box that names none.
        FLOATING_MIN = [96, 32]

        # Tells the defaults of the options: framed, not scrolling.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:frame => true, :scroll => false, :keep_ends => false, :title => nil, :icon => nil, :icon_file => nil)
        end

        # Tells which properties of C#'s tree each option sets, the room of its frame, title and
        # scrollbar among them.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:frame => ["padding"], :scroll => ["scroll", "padding"], :keep_ends => ["keep_ends"], :title => ["padding", "layout_id"], :icon => ["padding"],
                      :icon_file => ["padding"])
        end

        options :frame, :scroll, :keep_ends, :title, :icon, :icon_file

        # Tells the properties C#'s tree lays it out by: whether it scrolls and keeps the focus at its
        # ends, and as a root its least size.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["scroll"] = scrolls_part?
          props["keep_ends"] = @options[:keep_ends] ? true : false
          props["min"] = UI.pair(least_size)
          props
        end

        # Follows a changed option: a box that stops scrolling frees the picture it scrolled on, and
        # what it holds draws on the picture it lies on again.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless name == :scroll && !scrolls_part? && @inner

          @inner.dispose
          @inner = nil
          @children.each { |child| child.redraw }
        end
        private :changed

        # Tells whether it scrolls what it holds.
        #
        # @return [Boolean] Whether it does.
        def scrolls_part?
          @options[:scroll] ? true : false
        end

        # Scrolls what it holds a page up or down, with the cursor's sound when it moved.
        #
        # @param step [Integer] -1 for a page up, 1 for one down.
        # @return [Box] Itself.
        def scroll_page(step)
          shown = @scrolling ? @scrolling[1].to_i : 0
          scroll_from_code(step.to_i * [shown, 1].max)
        end

        # Scrolls what it holds by lines of text, with the cursor's sound when it moved.
        #
        # @param lines [Integer] The lines, negative up.
        # @return [Box] Itself.
        def scroll_by(lines)
          scroll_from_code(lines.to_i * LINE_HEIGHT)
        end

        # Takes its scrolling from C#, and tells the scroll blocks the lines in sight once they changed.
        #
        # @param scroll [Array<Integer>] Where it starts, how much shows and how much there is.
        def scrolled(scroll)
          super
          return unless listens?(:scroll)

          lines = lines_in_view
          return if lines == @lines_told

          @lines_told = lines
          emit(:scroll, lines)
        end

        # Tells the lines of the texts it holds that are in sight: the first and the last wholly in
        # sight, counted from 1 over every line of every text, and how many there are; 0 for none.
        #
        # @return [Hash] :first, :last and :total.
        def lines_in_view
          sight = @scrolling ? @scrolling[1].to_i : (@rect ? @rect.height : 0)
          top = @rect ? inner_region.y : 0
          count = 0
          first = last = 0
          labels_in(self).each do |label|
            lines, height = label.lines_and_height
            lines.times do |line|
              count += 1
              y = label.rect.y - top + line * height
              next unless y >= 0 && y + height <= sight

              first = count if first == 0
              last = count
            end
          end
          { :first => first, :last => last, :total => count }
        end

        # Scrolls what it holds to a place from the next layout on, such as back to its top after it
        # was filled anew, which keeps the scrolling otherwise.
        #
        # @param top [Integer] The first pixel in sight, kept within what it holds.
        # @return [Box] Itself.
        def scroll_to(top)
          Tree.set(self, "scroll_top" => UI.whole(top))
          self
        end

        # Draws its background and border, by default the theme's back and frame, and its title row;
        # a border it was given gives way to the frame that lights it while it has the focus.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          back = @options[:background].nil? ? own_back : @options[:background]
          canvas.background(0, 0, canvas.width, canvas.height, back, plate_opacity)
          unless focused? && !@options[:border].nil?
            canvas.border(0, 0, canvas.width, canvas.height, border_look, border_px, :opacity => plate_opacity, :of => shade_base)
          end
          canvas.outline(0, 0, canvas.width, canvas.height, :title) if focused? && !framed?
          draw_container(canvas)
          top, right, _bottom, left = title_edges
          draw_title(canvas, left, top, canvas.width - left - right) if titled?
        end

        # Draws its scrollbar at its right, on the picture of what it scrolls, and a frame around it
        # while a key gave it the focus to scroll it; a box without a frame draws that frame around
        # the picture, in the room it keeps for it.
        #
        # @param canvas [Canvas] Where it draws, the box's own place.
        def draw_part(canvas)
          canvas.outline(0, 0, canvas.width, canvas.height, :title) if focused? && framed?
          return unless @scrolling

          top, shown, total = @scrolling
          inside = padding_sides
          canvas.scrollbar(canvas.width - bar_inset - Style::SCROLLBAR_WIDTH, inside[0], canvas.height - inside[0] - inside[2], top, shown, total)
        end

        # Takes its state from C#; a scrolling box that took or lost the focus draws what it scrolls anew.
        #
        # @param bits [Integer] The bits of hover, press and focus.
        def state=(bits)
          focus_changed = (bits.to_i ^ @state.to_i) & Tree::FOCUSED != 0
          super
          redraw_content if focus_changed && scrolls_part?
        end

        # Tells where the part it scrolls shows on the screen: inside its padding, out to its frame at
        # the right, where its scrollbar runs; one rectangle it keeps for every frame.
        #
        # @return [Rect] The part.
        def inner_region
          sides = padding_sides
          width = @rect.width - sides[3] - border_room[1] - (framed? ? 0 : focus_room)
          height = @rect.height - sides[0] - sides[2]
          (@inner_region ||= Rect.new(0, 0, 0, 0)).set(@rect.x + sides[3], @rect.y + sides[0], width > 1 ? width : 1, height > 1 ? height : 1)
          @inner_region
        end

        # Tells the picture of the part it scrolls.
        #
        # @return [SpriteSurface, nil] The picture, nil when it scrolls nothing or before it showed.
        def inner_surface
          scrolls_part? ? @inner : nil
        end

        # Hands out the picture of the part it scrolls, made as it first shows.
        #
        # @return [SpriteSurface] The picture.
        def inner_surface!
          @inner ||= SpriteSurface.new(self, root.surface_viewport)
        end

        # Frees the picture of the part it scrolls and every other picture it and those it holds have.
        def release_surfaces
          super
          @inner.dispose if @inner
          @inner = nil
        end

        private

        # Finds the texts a part holds that show and have a place, in their order.
        #
        # @param part [Component] The part.
        # @return [Array<Label>] The texts.
        def labels_in(part)
          part.children.select { |child| child.visible? }.map do |child|
            next [] unless child.rect

            child.is_a?(Label) ? [child] : (child.respond_to?(:children) ? labels_in(child) : [])
          end.flatten
        end

        # Scrolls what it holds by pixels from where it is, kept within what it holds, with the cursor's
        # sound when it moved.
        #
        # @param pixels [Integer] The pixels, negative up.
        # @return [Box] Itself.
        def scroll_from_code(pixels)
          return self unless @scrolling && scrolls_part?

          top, shown, total = @scrolling
          target = UI.within(top + pixels, 0, [total - shown, 0].max)
          return self if target == top

          Sound.play_cursor
          scroll_to(target)
        end

        # Tells whether it draws its frame.
        #
        # @return [Boolean] Whether it does.
        def framed?
          @options[:frame] ? true : false
        end

        # Tells how opaque its background and frame draw.
        #
        # @return [Integer, nil] The opacity, nil for whole.
        def plate_opacity
          nil
        end

        # Tells the room between its frame and what it holds, which its :padding replaces; without a
        # frame the room of the frame it shows while it has the focus.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          edge = framed? ? Style::PAD : focus_room
          [edge, edge, edge, edge]
        end

        # Tells the room its title row and its scrollbar take; a framed box's scrollbar lies in its
        # room, which keeps the scrollbar's gap only.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [title_room, scrolls_part? ? bar_room : 0, 0, 0]
        end

        # Tells the room its scrollbar takes beside what it scrolls: past its padding, the scrollbar
        # and its gap.
        #
        # @return [Integer] The pixels.
        def bar_room
          return Style::SCROLLBAR_WIDTH + BAR_GAP unless framed?

          [BAR_GAP, bar_inset - border_room[1] + Style::SCROLLBAR_WIDTH + BAR_GAP - room_sides[1]].max
        end

        # Tells how far its scrollbar lies from its right edge: inside its border, a pixel off a frame.
        #
        # @return [Integer] The pixels.
        def bar_inset
          border_room[1] + (framed? ? 1 : focus_room)
        end

        # Tells where its title row starts from its edges: inside its border and its padding, or
        # inside the room of its border alone where its room is only the focus frame's.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def title_edges
          framed? || !@options[:padding].nil? ? edge_sides : border_room
        end

        # Tells its background while it has none of its own: the theme's back with a frame.
        #
        # @return [Symbol, nil] :theme, nil for none.
        def own_back
          framed? ? :theme : nil
        end

        # Tells its border while it has none of its own: the theme's frame with a frame.
        #
        # @return [Symbol, nil] :theme, nil for none.
        def own_border
          framed? ? :theme : nil
        end

        # Tells the room its own frame keeps.
        #
        # @return [Integer] The pixels.
        def own_border_room
          framed? ? FRAME : 0
        end

        # Tells the width of its own frame.
        #
        # @return [Integer] The pixels.
        def own_border_width
          framed? ? FRAME : 1
        end

        # Tells that it draws its background itself, the theme's back by default.
        #
        # @return [Boolean] Always true.
        def own_back?
          true
        end

        # Tells that it draws its border itself, the theme's frame by default.
        #
        # @return [Boolean] Always true.
        def own_edge?
          true
        end

        # Tells the room a box without a frame keeps at its edge for the frame it shows while it has
        # the focus: FOCUS_ROOM when it takes the focus, else none.
        #
        # @return [Integer] The pixels.
        def focus_room
          !framed? && @options[:focusable] ? FOCUS_ROOM : 0
        end

        # Tells its least size: its own, or as a floating box FLOATING_MIN; a box that follows a
        # character, such as a name over a head, is as large as what it holds.
        #
        # @return [Array, nil] Its width and height.
        def least_size
          @options[:min_size] || (root? && @options[:follow].nil? ? FLOATING_MIN : nil)
        end
      end

      # Shows a component's tooltip once the pointer rests on it, beside the pointer, or at once under
      # the component a key gave the focus to, as C# tells, in the component's theme and kept on the
      # screen: a text of one line or several in a small box, or, for a tooltip that is a block, a
      # floating box the block fills with any components (TipBox). A tooltip under a focused
      # component stays within the component's column (column_of), a text wrapped to its width, so it
      # never covers the column beside.
      module Tooltip
        # Room between the box's frame and its text.
        PAD = 4

        # How far right of the pointer the box starts.
        OFFSET_X = 12

        # How far below the pointer the box starts.
        OFFSET_Y = 18

        # Room between a focused component and its tooltip.
        FOCUS_GAP = 4

        # The sides a tooltip may lie on beside a component.
        SIDES = [:top, :bottom, :left, :right]

        # The sides a tooltip on a side tries next where it does not fit there: the opposite one, then
        # the two across.
        SIDE_TRIES = { :right => [:left, :bottom, :top], :left => [:right, :bottom, :top], :bottom => [:top, :right, :left], :top => [:bottom, :right, :left] }

        # Room between two lines of a text.
        LINE_GAP = 2

        # How opaque the box's background and frame draw, about 85 %; its text and icons stay whole.
        PLATE_OPACITY = 217

        # The component whose tooltip shows, nil for none.
        @shown = nil

        # Tells the component whose tooltip shows.
        #
        # @return [Component, nil] The component, nil while none shows.
        def self.shown
          @shown
        end

        # Shows a component's tooltip beside the pointer, or under the component when a key focused it.
        #
        # @param component [Component] The component.
        # @param x [Integer] The pointer's left.
        # @param y [Integer] The pointer's top.
        # @param by_focus [Boolean] Whether a key gave the component the focus.
        def self.show(component, x, y, by_focus = false)
          hide
          rect = component.rect
          column = by_focus && rect && !component.tooltip_side ? column_of(component) : nil
          spot = if component.tooltip_side && rect then { :side => component.tooltip_side, :rects => Hash[SIDES.map { |side| [side, side_rect(component, side)] }] }
                 elsif by_focus && rect then [rect.x, rect.y + rect.height + FOCUS_GAP, rect.y - FOCUS_GAP]
                 else [x + OFFSET_X, y + OFFSET_Y, y - PAD]
                 end
          spot += [column.x, column.x + column.width] if column
          tip = by_focus ? component.tooltip : component.tooltip_at(x, y)
          tip.respond_to?(:call) ? show_box(component, tip, spot) : show_text(component, tip.to_s, spot)
        end

        # Tells the place a tooltip on a side of a component lies beside: the component's, reaching
        # out to its root's edge on that side where the component lies against the root's content
        # edge there, so the tooltip clears the root's frame instead of covering it.
        #
        # @param component [Component] The component.
        # @param side [Symbol] :top, :bottom, :left or :right.
        # @return [Rect] The place.
        def self.side_rect(component, side)
          rect = component.rect
          root = component.root
          inner = root.equal?(component) ? nil : root.content_rect
          return rect unless inner

          outer = root.rect
          case side
          when :top then rect.y <= inner.y ? Rect.new(rect.x, outer.y, rect.width, rect.y + rect.height - outer.y) : rect
          when :left then rect.x <= inner.x ? Rect.new(outer.x, rect.y, rect.x + rect.width - outer.x, rect.height) : rect
          when :right then rect.x + rect.width >= inner.x + inner.width ? Rect.new(rect.x, rect.y, outer.x + outer.width - rect.x, rect.height) : rect
          else rect.y + rect.height >= inner.y + inner.height ? Rect.new(rect.x, rect.y, rect.width, outer.y + outer.height - rect.y) : rect
          end
        end
        private_class_method :side_rect

        # Finds the column a component lies in: the nearest page of a Slides that holds it, else its
        # root's content.
        #
        # @param component [Component] The component.
        # @return [Rect, nil] The column on the screen, nil before it has a place.
        def self.column_of(component)
          part = component
          part = part.parent until part.parent.nil? || part.parent.is_a?(Slides)
          part.parent ? part.rect : part.content_rect
        end

        # Hides the tooltip.
        def self.hide
          @sprite.visible = false if @sprite && !@sprite.disposed?
          box = @box
          @box = nil
          @shown = nil
          box.close if box && box.open?
        end

        # Finds where a tooltip lies: below its spot when it fits there, else ending above it, within
        # the spot's column when it has one, and kept on the screen; or on its side of a component,
        # flush with the component's start.
        #
        # @param spot [Array<Integer>, Hash] Its left, the top below and the bottom above, then the left
        #   and the right edge of its column, if it has one; or { :side, :rects } of the component, the
        #   place it lies beside on each side (side_rect).
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @return [Array<Integer>] Its left and top.
        def self.place(spot, width, height)
          return beside(spot[:side], spot[:rects], width, height) if spot.is_a?(Hash)

          left, below, above, column_left, column_right = spot
          top = below + height > Graphics.height ? [above - height, 0].max : below
          left = UI.within(left, column_left, [column_right - width, column_left].max) if column_left
          [UI.within(left, 0, [Graphics.width - width, 0].max), top]
        end

        # Finds where a tooltip lies beside a component, flush with its left or its top: on its side,
        # else on the first of the other sides in SIDE_TRIES where it fits whole on the screen, else on
        # its side kept on the screen.
        #
        # @param side [Symbol] :top, :bottom, :left or :right.
        # @param rects [Hash{Symbol => Rect}] The place it lies beside on each side.
        # @param width [Integer] The tooltip's width.
        # @param height [Integer] Its height.
        # @return [Array<Integer>] Its left and top.
        def self.beside(side, rects, width, height)
          places = ([side] + SIDE_TRIES[side]).map { |each| side_place(each, rects[each], width, height) }
          left, top = places.find { |x, y| x >= 0 && y >= 0 && x + width <= Graphics.width && y + height <= Graphics.height } || places.first
          [UI.within(left, 0, [Graphics.width - width, 0].max), UI.within(top, 0, [Graphics.height - height, 0].max)]
        end
        private_class_method :beside

        # Tells where a tooltip lies on one side of a place, flush with its left or its top.
        #
        # @param side [Symbol] :top, :bottom, :left or :right.
        # @param rect [Rect] The place.
        # @param width [Integer] The tooltip's width.
        # @param height [Integer] Its height.
        # @return [Array<Integer>] Its left and top, which may lie off the screen.
        def self.side_place(side, rect, width, height)
          case side
          when :top then [rect.x, rect.y - FOCUS_GAP - height]
          when :left then [rect.x - FOCUS_GAP - width, rect.y]
          when :right then [rect.x + rect.width + FOCUS_GAP, rect.y]
          else [rect.x, rect.y + rect.height + FOCUS_GAP]
          end
        end
        private_class_method :side_place

        # Tells the most width a tooltip takes: its column's, if its spot has one.
        #
        # @param spot [Array<Integer>, Hash] Its spot, see place.
        # @return [Integer, nil] The pixels, nil for no limit.
        def self.room(spot)
          spot.is_a?(Array) && spot[3] ? spot[4] - spot[3] : nil
        end

        # Shows a text in a small box, one line per line of the text, each wrapped at its words to the
        # room of its column, if its spot has one.
        #
        # @param component [Component] The component.
        # @param text [String] The text.
        # @param spot [Array<Integer>] Where it goes, see place.
        def self.show_text(component, text, spot)
          lines = text.split("\n")
          return if lines.empty?

          @sprite = Sprite.new if @sprite.nil? || @sprite.disposed?
          old = @sprite.bitmap
          picture = Bitmap.new(1, 1)
          Style.use_font(picture, Style::SMALL_SIZE, Style::TEXT)
          most = room(spot)
          lines = lines.map { |line| line.empty? ? [line] : UI.wrap(picture, line, most - 2 * (PAD + Box::FRAME)) }.flatten if most
          width = lines.map { |line| UI.text_width(picture, line) }.max + 2 * (PAD + Box::FRAME)
          height = lines.size * Style::SMALL_SIZE + (lines.size - 1) * LINE_GAP + 2 * (PAD + Box::FRAME)
          picture.dispose
          draw(component, lines, width, height)
          # RGSS may end the game drawing a sprite whose picture was freed, so the old one goes only
          # once the sprite shows the new.
          old.dispose if old && !old.disposed?
          @sprite.x, @sprite.y = place(spot, width, height)
          @sprite.z = Z[:tooltips]
          @sprite.visible = true
          @shown = component
        end
        private_class_method :show_text

        # Shows a floating box a block fills.
        #
        # @param component [Component] The component.
        # @param block [#call] The block, which gets the box.
        # @param spot [Array<Integer>] Where it goes, see place.
        def self.show_box(component, block, spot)
          box = TipBox.new(spot, :theme => component.theme_value, :log => component.log_target)
          block.call(box)
          box.fit
          @box = box.open
          @shown = component
        rescue => e
          component.mod_log("the tooltip block of #{component.describe} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}") if Logging.first_time?(Tree, [:tooltip, component.class, e.class])
        end
        private_class_method :show_box

        # Draws the tooltip's box and lines on a new picture.
        #
        # @param component [Component] The component, whose theme the box wears.
        # @param lines [Array<String>] The lines.
        # @param width [Integer] The box's width.
        # @param height [Integer] The box's height.
        def self.draw(component, lines, width, height)
          picture = Bitmap.new(width, height)
          Style.draw_box(picture, 0, 0, width, height, component.palette, PLATE_OPACITY)
          Style.use_font(picture, Style::SMALL_SIZE, Style::TEXT)
          lines.each_with_index do |line, row|
            top = PAD + Box::FRAME + row * (Style::SMALL_SIZE + LINE_GAP)
            picture.draw_text(PAD + Box::FRAME, top, width - 2 * (PAD + Box::FRAME), Style::SMALL_SIZE, line)
          end
          @sprite.bitmap = picture
        end
        private_class_method :draw
      end

      # The floating box a tooltip block fills: above every root, never taking the pointer; while it
      # holds a text that wraps at most MOST_WIDTH wide, or its column's width when that is less,
      # unless the block gives it a width, and else as wide as what it holds, so a text that does not
      # wrap shows whole. It shows once it lies where Tooltip.place puts it for its size, which C#
      # tells only after it laid the box out.
      class TipBox < Box
        # The most width of a box whose block gives it none.
        MOST_WIDTH = 240

        # Makes the box.
        #
        # @param spot [Array<Integer>] Where it goes, see Tooltip.place.
        # @param options [Hash] Its options.
        def initialize(spot, options = {})
          super({ :z => Z[:tooltips], :mouse => false, :at => Tooltip.place(spot, 0, 0) }.merge(options))
          @spot = spot
          @target = nil
        end

        # Keeps it at most MOST_WIDTH wide, or its column's width, while it holds a text that wraps,
        # unless the block gave it a width.
        def fit
          return unless @options[:size].nil? && @options[:width].nil? && @options[:max_size].nil? && wraps_text?(self)

          self.max_size = [[MOST_WIDTH, Tooltip.room(@spot)].compact.min, nil]
        end

        # Takes the place C# gave it, and moves it where its size lets it lie.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          target = Tooltip.place(@spot, @rect.width, @rect.height)
          @placements = @placements.to_i + 1
          @target = target
          self.at = target unless target == [@rect.x, @rect.y]
        end

        # Draws it for the frame once it lies where it belongs, or when C# kept it elsewhere twice.
        #
        # @param look_changed [Boolean] Whether the colors or the game's window color changed.
        def update_frame(look_changed)
          return hide_surfaces unless @rect && (@target == [@rect.x, @rect.y] || @placements.to_i > 2)

          super
        end

        private

        # Tells whether a part holds a text that wraps, itself or anywhere inside.
        #
        # @param part [Component] The part.
        # @return [Boolean] Whether it does.
        def wraps_text?(part)
          (part.is_a?(Label) && part.wrap) || part.children.any? { |child| wraps_text?(child) }
        end

        # Tells how opaque its background and frame draw: as a tooltip's text box.
        #
        # @return [Integer] The opacity.
        def plate_opacity
          Tooltip::PLATE_OPACITY
        end

        # Takes it out of the tree and frees its pictures; it holds no buttons, so the frame's buttons
        # stay the game's as it goes.
        #
        # @param removed [Boolean] Whether C# removed it already.
        def teardown(removed)
          @open = false
          @scene = nil
          Tree.close_root(self, removed)
          release_surfaces
        end
      end

      # A modal root that draws nothing, so the roots below it take no key, click or hover while a
      # part reads them itself, such as an open Wheel over its picture or a key row waiting for its
      # key.
      class Cover < Component
        include Root

        # The component's kind in C#'s tree.
        KIND = "box"

        # Tells that the roots below it take no input while it shows.
        #
        # @return [Boolean] Always true.
        def modal?
          true
        end

        # Tells the properties C#'s tree lays it out by, modal added.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["modal"] = true
          props
        end

        # Draws nothing; what it covers for draws itself.
        #
        # @param _look_changed [Boolean] Whether the colors or the game's window color changed.
        def update_frame(_look_changed)
          nil
        end
      end
    end
  end
end
