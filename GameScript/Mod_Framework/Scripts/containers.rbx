#----------------------------------------------------------------
#  containers.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Removed add_page, which nothing called
#      Paulinchen  2026-11-09: Let a grid hand the focus on past its first and last lines
#                            - Added CenteredColumn, a column in the middle of its room at a most width with gutters at its sides
#      Paulinchen  2026-11-07: Added GridItem, a column that spans columns of a grid
#                            - Removed Columns, which nothing used any more
#                            - Added Measures, a part and its hidden copies that C# picks the step of compact forms for
#                            - Added Forms, a part's forms of which C# shows the one its root's step picks
#      Paulinchen  2026-11-06: Took the key stop away from a container that stops being clickable or entered
#                            - Removed the backdrop, which no mod gave
#                            - Removed the add_ helper of the slides, which nothing called
#                            - Removed the add_ helper of the columns, which nothing called
#                            - Called the engine's classes by their names under UI::Engine
#                            - Opened a Slides on a later page without failing on the pages before it
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Put a backdrop at a side or a corner
#      Paulinchen  2026-10-31: Clicked a container as one part, stopped the keys on one as a whole first, kept the newest
#                              parts of a column, drew a picture behind one and fitted a grid's columns
#                            - Drew a container's backdrop and its plate as one part clicked or entered
#      Paulinchen  2026-10-30: Slid the page of a part that takes the focus into view
#      Paulinchen  2026-10-29: Added columns whose parts line up and let cancel slide a Slides back
#                            - Added the Slides, a strip of pages that slides between them
#                            - Showed every page a slide passes over and timed a slide by how far it goes
#                            - Kept a list given alone to an add helper whole
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What every component that holds others shares: how it places them (a column, a row, a grid or
      # each at its own place, laid out in C#), and the helpers that make a component and add it in one
      # call, add_<name>.
      #
      # :clickable makes it one key stop clicked as a whole, what it holds taking neither the pointer
      # nor the keys; :enter makes the keys stop on it as a whole while the focus is outside, confirm
      # moving the focus inside and cancel back out; :tail lays a column out from its bottom, leaving
      # out from the top what its height does not hold.
      #
      # Events: click (as one part).
      module Container
        # How a container places its children, as C# names it.
        LAYOUTS = [:column, :row, :grid, :absolute]

        # Where a stack puts its children along itself when they leave room over.
        JUSTIFIES = [:start, :center, :end, :between]

        # The options every container takes, with their defaults.
        DEFAULTS = { :layout => :column, :gap => Style::GAP, :justify => :start, :wrap => false, :columns => nil, :clickable => false, :enter => false,
                     :tail => false, :most_columns => nil }

        # What a grid's columns name to take as many equal columns as its widest child fits.
        FIT = :fit

        # The properties of C#'s tree each container option sets.
        NODE_KEYS = { :layout => ["layout"], :gap => ["gap"], :justify => ["justify"], :wrap => ["wrap"], :columns => ["columns", "fit_columns"],
                      :clickable => ["clickable", "focusable"], :enter => ["enter", "focusable"], :tail => ["tail"], :most_columns => ["fit_columns"] }

        # The defaults and properties a container class adds to its component's.
        module ClassMethods
          # Tells the defaults of the options, the container's added.
          #
          # @return [Hash] The defaults.
          def defaults
            super.merge(Container::DEFAULTS)
          end

          # Tells which properties of C#'s tree each option sets, the container's added.
          #
          # @return [Hash{Symbol => Array<String>}] The properties by option.
          def node_keys
            super.merge(Container::NODE_KEYS)
          end
        end

        # Makes a class including it a container.
        #
        # @param base [Class] The component class.
        def self.included(base)
          base.extend(ClassMethods)
          base.options(*DEFAULTS.keys)
        end

        # Adds a helper add_<name> to every container: it makes a component through a block, adds it,
        # hands it to the caller's block, which only scopes the caller's code, and returns it.
        #
        # @param name [Symbol] The helper's name after add_, such as :box.
        # @yield [*args] Makes the component from the helper's arguments.
        # @yieldreturn [Component] The component.
        def self.adds(name, &maker)
          define_method("add_#{name}") do |*args, &block|
            # A block splits an Array given alone over its parameters, so a list of lines or slots
            # given without options goes with empty options.
            child = maker.call(*(args.size == 1 ? args + [{}] : args))
            add(child)
            block.call(child) if block
            child
          end
        end

        # Tells that it holds other components.
        #
        # @return [Boolean] Always true.
        def container?
          true
        end

        # Tells the properties C#'s tree lays it out by, the container's added.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["layout"] = UI.choice(@options[:layout], LAYOUTS, :column, "layout")
          props["gap"] = UI.whole(@options[:gap])
          props["justify"] = UI.choice(@options[:justify], JUSTIFIES, :start, "justify")
          props["wrap"] = @options[:wrap] ? true : false
          columns = grid_columns
          props["columns"] = columns if columns
          props["fit_columns"] = @options[:columns] == FIT ? [@options[:most_columns] || 99, 1].max : 0
          props["clickable"] = @options[:clickable] ? true : false
          props["enter"] = @options[:enter] ? true : false
          props["tail"] = @options[:tail] ? true : false
          props["focusable"] = (@options[:clickable] || @options[:enter]) ? true : false if @options[:focusable].nil?
          props
        end

        # Draws what a container draws under what it holds: as one part clicked or entered, the
        # cursor's plate or frame while it has the focus.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_container(canvas)
          if @options[:clickable]
            canvas.fill(0, 0, canvas.width, canvas.height, :picked) if focused? && canvas.enabled?
            canvas.outline(0, 0, canvas.width, canvas.height, focused? ? :title : :edge) if focused? || hovered?
          elsif @options[:enter] && focused?
            canvas.outline(0, 0, canvas.width, canvas.height, :title)
          end
        end

        # Draws the cursor's plate, under what it holds.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_container(canvas)
        end

        private

        # Reads the grid's columns as C# takes them: a count of equal columns, or each column's width
        # with nil for one that shares the room left; one that names none is logged once.
        #
        # @return [Integer, Array, nil] The columns, nil for none given.
        def grid_columns
          columns = @options[:columns]
          return 1 if columns == FIT
          return columns if columns.is_a?(Integer) && columns > 0
          return columns.map { |width| width.nil? ? nil : UI.whole(width) } if columns.is_a?(Array) && !columns.empty?

          Tree.log_once([:columns, columns], "#{describe} names no columns in #{columns.inspect}, so it has one") unless columns.nil?
          nil
        end
      end


      # A plain container with no look of its own: its children in a column or a row, as add_row and
      # add_column make it.
      class Stack < Component
        include Container

        # The component's kind in C#'s tree.
        KIND = "stack"
      end

      # A part's forms, the part itself and its compact forms, each a child, of which C#'s tree shows
      # the one its root's step picks and lays the others out without room. :steps tells the step from
      # which each child shows, the first 0.
      class Forms < Stack
        # Tells the defaults of the options: a column without gaps, the part alone.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:gap => 0, :steps => [0])
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:steps => ["forms"])
        end

        options :steps

        # Tells the properties C#'s tree lays it out by: the steps of its forms.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["forms"] = Array(@options[:steps])
          props
        end
      end

      # A part and copies of it that the markup hides, which C#'s tree lays out in the part's place,
      # so its root picks the step of its compact forms as for the tallest of them.
      class Measures < Stack
        # Tells the defaults of the options: a column without gaps.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:gap => 0)
        end

        # Tells the properties C#'s tree lays it out by: that it holds copies.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["measures"] = true
          props
        end
      end

      # A plain container with no look of its own that places its children in columns, filled row by
      # row, as add_grid makes it. With :leave_ends, UP on its first line and DOWN on its last move the
      # focus on to the part above or below where a grid of boxes would wrap.
      class Grid < Component
        include Container

        # The component's kind in C#'s tree.
        KIND = "grid"

        # Tells the defaults of the options: in a grid of one column that wraps at its ends.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :grid, :columns => 1, :leave_ends => false)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:leave_ends => ["leave_ends"])
        end

        options :leave_ends

        # Tells the properties C#'s tree lays it out by: whether it leaves its ends.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["leave_ends"] = @options[:leave_ends] ? true : false
          props
        end
      end

      # A column in a grid that spans :span of the grid's columns, as MudBlazor's item spans its xs
      # of twelve.
      class GridItem < Stack
        # Tells the defaults of the options: the whole row of a grid of twelve columns.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:span => 12)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:span => ["span"])
        end

        options :span

        # Tells the properties C#'s tree lays it out by: the columns it spans.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["span"] = UI.whole(@options[:span])
          props
        end
      end

      # A column in the middle of the room it gets, as wide as that room up to its most width, with
      # gutters at its sides as its own room, as MudBlazor's container: its :max_size's width is its
      # most, and its own width while it lies in a row or its window fits what it holds. With
      # :widths it takes the largest of them that fits its room instead, and as its own width the
      # narrowest that holds what it holds.
      class CenteredColumn < Stack
        # The room at either side of what it holds.
        GUTTER = 8

        # Tells the defaults of the options: a column with a stack's room between its parts, no
        # widths to pick from.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :widths => nil)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:widths => ["widths"])
        end

        options :widths

        # Tells the properties C#'s tree lays it out by: centered, and the widths it picks from.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["centered"] = true
          props["widths"] = @options[:widths] ? @options[:widths].map { |width| UI.whole(width) } : nil
          props
        end

        private

        # Tells its gutters, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [0, GUTTER, 0, GUTTER]
        end
      end

      # A strip of equal pages side by side, :shown of them in view at a time with :gap between, that
      # slides to other pages over :frames along an :easing, the pages leaving the view fading out and
      # those coming in fading in with :fade. The slide moves what is drawn, cut to the Slides' place,
      # and lays out and draws nothing anew. Pages out of view are not drawn and take neither the
      # pointer nor the keys; a page leaving the view is drawn but takes neither while it slides. With
      # :keys, LEFT and RIGHT that find nothing to focus that way inside it focus the page beside in
      # view, else slide a page that way, and cancel while the focus is inside it slides a page back
      # before it reaches the root, unless :cancel_back is false, the first page is in view or the
      # focus is on the part its root opened on. A part on a page out of view that takes the focus,
      # by focus or a list's :submit_to, slides its page into view first. Each page is any component
      # added.
      #
      # Events: change (index, as a slide starts), done (index, as it lands), slide (index, before a
      # slide by the keys or cancel; a block that answers false refuses it with the buzzer).
      class Slides < Component
        include Container

        # The component's kind in C#'s tree.
        KIND = "slides"

        # Tells the defaults of the options: one page in view, sliding over 14 frames, easing out and
        # fading, moved by the keys.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:shown => 1, :index => 0, :frames => 14, :easing => :ease_out, :fade => true, :keys => true, :cancel_back => true)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:shown => ["shown"], :keys => ["slide_keys", "slide_back"], :cancel_back => ["slide_back"])
        end

        options :shown, :frames, :easing, :fade, :keys, :cancel_back

        # @return [Float] Where the strip is drawn, in pages from the first: the index once it landed.
        attr_reader :position

        # Makes the strip, at its :index.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @options[:index] = [@options[:index].to_i, 0].max
          @position = @options[:index].to_f
          @tween = nil
        end

        # Tells the properties C#'s tree lays it out and routes the keys by.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["shown"] = shown_count
          props["slide_keys"] = @options[:keys] ? true : false
          props["slide_back"] = slides_back?
          props
        end

        # Adds a page: a component put on a picture of its own, shown while in view.
        #
        # @param child [Component] The page.
        # @param index [Integer, nil] Its place among the pages, nil for their end.
        # @return [Component] The page.
        def add(child, index = nil)
          super
          child.layer! if child.parent.equal?(self)
          settle(false)
          child
        end

        # Hands out the pages in their order.
        #
        # @return [Array<Component>] The pages.
        def pages
          @children.dup
        end

        # Tells the first page in view, where a slide goes once it started.
        #
        # @return [Integer] The page's place.
        def index
          @options[:index]
        end

        # Puts the strip at a page at once, with no slide and no event.
        #
        # @param value [Integer] The first page in view, kept on the pages.
        def index=(value)
          @tween.stop if @tween
          @tween = nil
          @options[:index] = kept(value)
          self.position = @options[:index].to_f
          settle(false)
          Tree.set(self, "slide_back" => slides_back?)
        end

        # Slides to a page from where the strip is drawn: a slide turned around runs back over the
        # frames it ran, any other over :frames per page it goes, so none jumps. Tells change as it
        # starts and done as it lands.
        #
        # @param value [Integer] The first page in view, kept on the pages.
        # @return [Slides] Itself.
        def slide_to(value)
          place = kept(value)
          return self if place == index && !sliding?

          turning = sliding? && (place - @position) * (index - @position) < 0
          frames = turning ? [@tween.frame, 1].max : [((place - @position).abs * @options[:frames].to_i).ceil, 1].max
          @options[:index] = place
          settle(true)
          Tree.set(self, "slide_back" => slides_back?)
          emit(:change, place)
          @tween = animate({ :position => place.to_f }, :frames => frames, :easing => @options[:easing])
          @tween.on(:done) { landed }
          self
        end

        # Slides a page into view the shortest way, with no sound, such as for a part on it that takes
        # the focus; a page in view stays.
        #
        # @param page [Component] The page.
        # @return [Slides] Itself.
        def bring_into_view(page)
          place = @children.index { |child| child.equal?(page) }
          return self if place.nil? || (place >= index && place < index + shown_count)

          slide_to(place < index ? place : place - shown_count + 1)
        end

        # Slides a page on, when there is one.
        #
        # @return [Slides] Itself.
        def forward
          slide_to(index + 1)
        end

        # Slides a page back, when there is one.
        #
        # @return [Slides] Itself.
        def back
          slide_to(index - 1)
        end

        # Tells whether it slides now.
        #
        # @return [Boolean] Whether it does.
        def sliding?
          @tween ? @tween.running? : false
        end

        # Draws the strip at a place between pages: each page shifted there and, with :fade, as opaque
        # as the share of it in view.
        #
        # @param value [Float] The place, in pages from the first.
        def position=(value)
          @position = value.to_f
          step = page_step
          shown = shown_count
          @children.each_with_index do |page, place|
            page.offset = [-(@position * step).round, 0]
            seen = UI.within([place + 1, @position + shown].min - [place, @position].max, 0.0, 1.0)
            page.opacity = @options[:fade] ? (seen * Component::OPAQUE).round : Component::OPAQUE
            page.came_into_sight if seen > 0 && (@out_of_view ||= {}).delete(page) && page.visible?
            (@out_of_view ||= {})[page] = true if seen <= 0
          end
        end

        # Tells whether a page lies out of view, drawing nothing.
        #
        # @param child [Component] The page.
        # @return [Boolean] Whether it does.
        def keeps_out_of_view?(child)
          place = @children.index { |page| page.equal?(child) }
          return false unless place

          [place + 1, @position + shown_count].min - [place, @position].max <= 0
        end

        # Takes the place C# gave it, and shifts the pages for its width.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          self.position = @position
        end

        # Takes an event of C#'s tree: LEFT or RIGHT slides a page that way, and cancel a page back,
        # when there is one and no slide block refuses it.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "slide" || name == "back"

          place = index + (name == "back" ? -1 : values[0].to_i)
          return unless place >= 0 && place <= last_index
          return Sound.play_buzzer unless ask(:slide, place)

          Sound.play_cursor if name == "slide"
          slide_to(place)
        end

        # Tells that it cuts its pages to its place.
        #
        # @return [Boolean] Always true.
        def clips?
          true
        end

        private

        # Tells whether cancel slides it back now: with :keys and :cancel_back, past its first page.
        #
        # @return [Boolean] Whether it does.
        def slides_back?
          @options[:keys] && @options[:cancel_back] && index > 0 ? true : false
        end

        # Tells how many pages show at once.
        #
        # @return [Integer] At least one.
        def shown_count
          [@options[:shown].to_i, 1].max
        end

        # Tells the last page the strip can start at.
        #
        # @return [Integer] The page's place.
        def last_index
          [@children.size - shown_count, 0].max
        end

        # Keeps a page's place on the pages the strip can start at.
        #
        # @param value [Integer] The place.
        # @return [Integer] The place kept.
        def kept(value)
          UI.within(value.to_i, 0, last_index)
        end

        # Tells how far the strip moves for one page: a page's width and the gap.
        #
        # @return [Integer] The pixels, 0 before it was laid out.
        def page_step
          return 0 unless @rect

          _top, right, _bottom, left = padding_sides
          gap = UI.whole(@options[:gap])
          (@rect.width - left - right - gap * (shown_count - 1)) / shown_count + gap
        end

        # Shows the pages in view and hides the others: while it slides, every page the strip passes
        # over on its way shows too, inert unless it stays in view.
        #
        # @param sliding [Boolean] Whether it slides now.
        def settle(sliding)
          shown = shown_count
          low = [@position, index].min
          high = [@position, index].max + shown
          @children.each_with_index do |page, place|
            coming = place >= index && place < index + shown
            drawn = sliding && place + 1 > low && place < high
            page.visible = coming || drawn if page.visible? != (coming || drawn)
            page.inert = drawn && !coming if page.inert? != (drawn && !coming)
          end
        end

        # Hides the pages out of view once the strip landed, and tells done.
        def landed
          settle(false)
          emit(:done, index)
        end
      end
    end

    Engine::Container.adds(:row) { |*args| Engine::Stack.new({ :layout => :row }.merge(args[0] || {})) }
    Engine::Container.adds(:column) { |*args| Engine::Stack.new({ :layout => :column }.merge(args[0] || {})) }
    Engine::Container.adds(:grid) { |columns, *rest| Engine::Grid.new((rest[0] || {}).merge(:columns => columns)) }
    Engine::Container.adds(:box) { |*args| Engine::Box.new(args[0] || {}) }
  end
end
