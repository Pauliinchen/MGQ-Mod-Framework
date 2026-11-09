#----------------------------------------------------------------
#  badges.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Kept the room for a badge's upper half as fixed room, which no padding replaces
#      Paulinchen  2026-11-07: Wrote the text of a badge in the plain text color with its outline unless it has contrast
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A badge over the top right corner of the parts it holds, as MudBlazor's badge: a count or a
      # text on a pill in its :color, or a dot with :dot, the text as Component#text_on tells it. A
      # count shows "9+" above 9 and nothing at 0, as every badge: of the framework. It keeps the room
      # of the badge's upper half above and right of what it holds, so the badge never covers its
      # neighbours.
      class BadgeHolder < Stack
        # Tells the defaults of the options: a column without gaps, nothing to show, in primary.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:gap => 0, :content => nil, :dot => false, :color => :primary)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:dot => ["padding"])
        end

        options :content, :dot, :color

        # Makes it with its badge, which stays its last part.
        #
        # @param options [Hash] :content, :dot, :color and the options of a container.
        def initialize(options = {})
          super
          @mark = add(BadgeMark.new(:text => shown_text, :color => @options[:color], :visible => !shown_text.nil?))
        end

        # Puts the parts it holds before its badge, in order.
        #
        # @param parts [Array<Component>] The parts.
        def hold(parts)
          wanted = parts + [@mark]
          return if children == wanted

          (children - wanted).each { |child| remove(child) }
          wanted.each_with_index { |child, place| add(child, place) unless children[place].equal?(child) }
        end

        private

        # Follows a changed option: its badge shows the new count, text, dot or color.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @mark && [:content, :dot, :color].include?(name)

          @mark.text = shown_text.to_s
          @mark.color = @options[:color]
          @mark.visible = !shown_text.nil?
        end

        # Tells what its badge shows: "" for a dot, a count as Badge.text_of tells it, or a text.
        #
        # @return [String, nil] The text, nil for nothing.
        def shown_text
          return "" if @options[:dot]

          content = @options[:content]
          return Badge.text_of(content) if content.is_a?(Integer)

          content.to_s.empty? ? nil : content.to_s
        end

        # Tells the room it keeps for its badge's upper half: above and at the right of what it holds.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          half = (@options[:dot] ? BadgeMark::DOT : BadgeMark::HEIGHT) / 2
          [half, half, 0, 0]
        end
      end

      # The badge of a BadgeHolder, which C#'s tree lays over the holder's top right corner: a pill
      # with its :text, or a dot for an empty :text, in its :color. It takes neither the pointer nor
      # the keys.
      class BadgeMark < Component
        # The pill's height.
        HEIGHT = 16

        # The side of a dot.
        DOT = 8

        # Room between the pill's ends and its text.
        INSET = 4

        # Tells the defaults of the options: a dot in primary that takes no pointer.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:text => "", :color => :primary, :mouse => false)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:text => ["measured"])
        end

        options :text, :color

        # Tells the properties C#'s tree lays it out by: that it lies over its holder's corner.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["corner"] = true
          props
        end

        # Tells its size: a dot, or a pill as wide as its text and at least round.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          text = @options[:text].to_s
          return [DOT, DOT] if text.empty?

          [[UI.text_width(UI.font_bitmap(Style::TINY_SIZE), text) + 2 * INSET, HEIGHT].max, HEIGHT]
        end

        # Draws its dot, or its pill and its text in the text on the pill.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          text = @options[:text].to_s
          color = @options[:color] || :primary
          return canvas.disc(canvas.width / 2, canvas.height / 2, DOT / 2, color) if text.empty?

          canvas.pill(0, 0, canvas.width, canvas.height, :fill => color)
          canvas.text(0, 0, canvas.width, canvas.height, text, :size => :tiny, :color => text_on(color), :align => :center)
        end
      end
    end
  end
end
