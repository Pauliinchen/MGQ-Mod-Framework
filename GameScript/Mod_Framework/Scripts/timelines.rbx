#----------------------------------------------------------------
#  timelines.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A timeline, as MudBlazor's timeline: its entries under each other in the order things
      # happened, each dot joined to the next by a line.
      class Timeline < Stack
        # Tells the defaults of the options: a column without gaps, the entries keeping their own
        # room under them.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 0)
        end

        # Draws the marks of its entries again, whose lines join the entries before and after, once
        # its entries changed.
        def redraw_marks
          children.each { |child| child.mark.redraw if child.is_a?(TimelineItem) }
        end
      end

      # An entry of a timeline, as MudBlazor's timeline item: a dot in its :color on a line that
      # joins it to the entries before and after, and beside it its :title with its :text under it in
      # the small dim text, wrapped, left out while it has none.
      class TimelineItem < Stack
        # Room under an entry's text, before the next entry.
        ROOM = 12

        # Tells the defaults of the options: a row without gaps, no title or text, in primary.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => Style::GAP, :title => "", :text => nil, :color => :primary)
        end

        options :title, :text, :color

        # @return [TimelineMark] Its dot and line.
        attr_reader :mark

        # Makes its mark and the column of its title and its text.
        #
        # @param options [Hash] :title, :text, :color and the options of a container.
        def initialize(options = {})
          super
          @mark = add(TimelineMark.new(:color => @options[:color]))
          column = add(Stack.new(:layout => :column, :gap => 0, :grow => 1, :padding => [0, 0, ROOM, 0]))
          @title = column.add(Label.new(:text => @options[:title].to_s))
          @text = column.add(Label.new(:text => @options[:text].to_s, :font_size => :small, :color => :dim, :wrap => true, :visible => shows_text?))
        end

        private

        # Follows a changed option: a new title, text or color shows at once.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @text

          @title.text = @options[:title].to_s if name == :title
          @mark.color = @options[:color] if name == :color
          return unless name == :text

          @text.text = @options[:text].to_s
          @text.visible = shows_text?
        end

        # Tells whether it has a text to show.
        #
        # @return [Boolean] Whether it has.
        def shows_text?
          !@options[:text].to_s.empty?
        end
      end

      # The mark of a timeline's entry: a dot in its :color at the height of the entry's title, and
      # the line in the theme's edge color that runs up to the entry before and down to the entry
      # after, as far as there are such entries.
      class TimelineMark < Component
        include StateBlind

        # Its width.
        WIDTH = 16

        # The dot's radius.
        RADIUS = 5

        # Where the dot's middle lies under its top: the middle of the title's line.
        DOT_Y = 12

        # The line's thickness.
        LINE = 2

        # Tells the defaults of the options: a dot in primary that takes no pointer.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:color => :primary, :mouse => false)
        end

        options :color

        # Tells its size: its width, and the height of its entry.
        #
        # @return [Array] Its width, nil for its height.
        def measure
          [WIDTH, nil]
        end

        # Draws its line, then its dot over it.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          middle = canvas.width / 2
          up, down = line_ends
          top = up ? 0 : DOT_Y
          bottom = down ? canvas.height : DOT_Y
          canvas.fill(middle - LINE / 2, top, LINE, bottom - top, :edge) if bottom > top
          canvas.disc(middle, DOT_Y, RADIUS, @options[:color] || :primary)
        end

        private

        # Tells which way its line runs: up while an entry is before its own in the timeline, down
        # while one is after.
        #
        # @return [Array<Boolean>] Up and down.
        def line_ends
          item = parent
          entries = item && item.parent ? item.parent.children.select { |child| child.is_a?(TimelineItem) && child.visible? } : []
          place = entries.index { |entry| entry.equal?(item) }
          return [false, false] unless place

          [place > 0, place < entries.size - 1]
        end
      end
    end
  end
end
