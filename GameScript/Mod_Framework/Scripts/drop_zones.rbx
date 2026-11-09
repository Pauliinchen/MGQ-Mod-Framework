#----------------------------------------------------------------
#  drop_zones.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The parts that hold drop zones, as MudBlazor's drop container: C# moves an item between the
      # zones inside by the keys or the pointer and tells drop with the item's node, the node of
      # the zone it came from, the node of the zone it goes to and its place there.
      #
      # Events: drop (item node, from node, to node, place).
      class DropContainer < Stack
        # Tells the properties C#'s tree lays it out by: that it holds drop zones.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["drop_container"] = true
          props
        end
      end

      # A framed area of items the player drags, as MudBlazor's drop zone, with its :title at its
      # top; :zone names it to the container's drop. While an item is carried over it, a line in the
      # theme's primary color marks the place it would go to.
      class DropZone < Box
        # The thickness of the line that marks the place.
        MARK = 2

        # Tells the defaults of the options: framed, no zone name.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:zone => nil)
        end

        options :zone

        # Tells the properties C#'s tree lays it out by: that it is a drop zone.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["drop_zone"] = true
          props
        end

        # Takes an event of C#'s tree: target tells the place an item carried would go to, -1 for
        # none.
        #
        # @param name [String] The event.
        # @param values [Array] Its values.
        def receive(name, *values)
          return super unless name == "target"

          @target = values[0].to_i
          redraw
        end

        # Draws its frame and title, and the line that marks the place an item carried would go to.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          super
          spot = mark_spot
          return unless spot

          row = @options[:layout] == :row
          left = spot[0] - @rect.x
          top = spot[1] - @rect.y
          row ? canvas.fill(left, top, MARK, spot[2], :primary) : canvas.fill(left, top, spot[2], MARK, :primary)
        end

        private

        # Tells where the line that marks the place lies on the screen: before the item at that
        # place among the items not carried, else after the last.
        #
        # @return [Array<Integer>, nil] Its left, top and length; nil while no item is carried over it.
        def mark_spot
          return nil unless @target && @target >= 0 && @rect

          items = @children.select { |child| child.is_a?(DropItem) && child.visible? && child.rect && !child.lifted? }
          inner = content_rect
          row = @options[:layout] == :row
          gap = UI.whole(@options[:gap])
          if items.empty?
            return row ? [inner.x, inner.y, inner.height] : [inner.x, inner.y, inner.width]
          end

          before = items[@target]
          rect = before ? before.rect : items.last.rect
          if row
            x = before ? rect.x - (gap + MARK) / 2 : rect.x + rect.width + (gap - MARK) / 2
            [x, inner.y, inner.height]
          else
            y = before ? rect.y - (gap + MARK) / 2 : rect.y + rect.height + (gap - MARK) / 2
            [inner.x, y, inner.width]
          end
        end
      end

      # An item of a drop zone: one key stop, clicked as one part, that confirm or a drag of the
      # pointer picks up; :item is what it stands for. While carried it draws on the theme's picked
      # color in a frame of its title color.
      class DropItem < Box
        # Tells the defaults of the options: a frame, clicked as one part, standing for nothing.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:item => nil, :clickable => true)
        end

        options :item

        # Tells the properties C#'s tree lays it out by: that it is dragged.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["drag"] = true
          props
        end

        # Tells whether the player carries it.
        #
        # @return [Boolean] Whether it is carried.
        def lifted?
          @lifted ? true : false
        end

        # Takes an event of C#'s tree: lift and unlift tell that the player picked it up and put it
        # down.
        #
        # @param name [String] The event.
        # @param values [Array] Its values.
        def receive(name, *values)
          return super unless name == "lift" || name == "unlift"

          @lifted = name == "lift"
          parent.redraw if parent
          redraw
        end

        # Draws its frame, and while carried the picked plate and a frame in the title color.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          super
          return unless lifted?

          canvas.fill(0, 0, canvas.width, canvas.height, :picked)
          canvas.outline(0, 0, canvas.width, canvas.height, :title)
        end
      end
    end
  end
end
