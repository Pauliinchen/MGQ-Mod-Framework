#----------------------------------------------------------------
#  drawer.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A framed panel that opens and closes at the side of what it lies in, such as the filters
      # beside a list: its header at its top, then its body. Open it shows both at :open_width; shut
      # it takes no room, or with :mini keeps a narrow strip of :mini_width that shows its header
      # only, such as the button that opens it. A :floating drawer lies over what it opens beside as
      # a root of its own, placed inside the edge of the part it lies beside, and opens and closes as
      # a root does.
      class Drawer < Box
        # Its width while open unless told.
        WIDTH = 240

        # The width of a mini drawer while shut: an icon button and its frame.
        MINI_WIDTH = 44

        # Tells the defaults of the options: open, not mini.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:open => true, :mini => false, :floating => false, :open_width => WIDTH, :mini_width => MINI_WIDTH)
        end

        # @return [Stack] The column of what it holds below its header.
        attr_reader :body

        # Makes the drawer with its body.
        #
        # @param options [Hash] Its options, see defaults.
        def initialize(options = {})
          super
          @body = add(Stack.new(:layout => :column, :gap => Style::GAP, :grow => 1))
          shape
        end

        # Tells whether it is open.
        #
        # @return [Boolean] Whether it is.
        def open_now?
          @options[:open] ? true : false
        end

        # Opens or shuts it.
        #
        # @param value [Boolean] Whether it is open.
        def open_now=(value)
          return if open_now? == (value ? true : false)

          @options[:open] = value ? true : false
          shape
        end

        private

        # Gives it the width and the parts its state shows: open, its body at its width; shut, the
        # strip of a mini drawer, else nothing.
        def shape
          open = open_now?
          @body.visible = open
          self.width = open ? @options[:open_width] : @options[:mini_width]
          self.visible = open || @options[:mini] unless @options[:floating]
        end
      end
    end
  end
end
