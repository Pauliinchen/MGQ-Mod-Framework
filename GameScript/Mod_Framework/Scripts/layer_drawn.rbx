#----------------------------------------------------------------
#  layer_drawn.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # The base class of a component that draws itself, such as a bar drawn by hand: a subclass
    # declares params and state as any component, tells its size in measure, draws on the game's
    # picture in draw and tells by role how the keys and the pointer treat it. It draws again
    # whenever it would render again, such as after its state changed.
    class Drawn < Component
      # The roles a drawn component takes.
      ROLES = [:none, :button, :slider]

      # Describes it: one part that measures and draws through the component, a part the framework
      # makes for it, which markup does not name.
      def render
        Engine::Builder.build(:drawn_part, [{ :drawn => self }], nil, self)
      end

      # Tells its size for the room it has, asked again whenever it renders or its parent's room
      # changes.
      #
      # @param width [Integer, nil] The width of the room its parent gives, nil before it is laid out.
      # @param height [Integer, nil] The height of that room, nil before it is laid out.
      # @return [Array] Its width and height, a side nil to take what the layout gives; all the room
      #   by default.
      def measure(width, height)
        [nil, nil]
      end

      # Draws it.
      #
      # @param bitmap [Bitmap] The game's picture it draws on, which other parts share.
      # @param rect [Rect] Its place on that picture, which it draws inside.
      def draw(bitmap, rect)
      end

      # Tells how the keys and the pointer treat it: :none passes them over; :button is a key stop
      # that confirm or a click presses, calling pressed; :slider is a key stop whose places Left and
      # Right step through, calling moved.
      #
      # @return [Symbol] :none, :button or :slider.
      def role
        :none
      end

      # Tells how many places a :slider steps through.
      #
      # @return [Integer] The places, 0 for none.
      def places
        0
      end

      # Tells the place a :slider stands at.
      #
      # @return [Integer] The place, from 0.
      def place
        0
      end

      # Runs as confirm or a click presses a :button.
      def pressed
      end

      # Runs as Left or Right steps a :slider to another place.
      #
      # @param _place [Integer] The place, from 0.
      def moved(_place)
      end
    end

    module Engine
      # The part a UI::Drawn renders: C# lays it out by what the component's measure tells for the
      # room its parent has, and its picture is what the component's draw puts there. A :button is a
      # key stop C# clicks; a :slider is a key stop whose places C# steps by Left and Right.
      #
      # Events: click (a :button pressed), move (place: a :slider stepped).
      class DrawnPart < Component
        include StateBlind

        # Tells the defaults of the options: no component, passed over by the keys.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:drawn => nil, :role => :none, :places => 0, :place => 0)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:role => ["focusable", "acts", "steps", "rows", "index"], :places => ["rows"], :place => ["index"])
        end

        options :drawn, :role, :places, :place

        # Tells the properties C#'s tree lays it out and routes input by: a key stop for a :button or
        # a :slider, a :slider's places and its place.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          stop = @options[:role] != :none
          props["focusable"] = stop
          props["acts"] = stop
          props["steps"] = @options[:role] == :slider
          props["rows"] = @options[:role] == :slider ? UI.whole(@options[:places]) : 0
          props["index"] = @options[:role] == :slider ? UI.whole(@options[:place]) : -1
          @last_size = props["measured"]
          props
        end

        # Takes the place C# gave it, and measures it again for the room its parent has now, laying
        # it out anew when its size changed, such as a bar as wide as its window.
        #
        # @param rect [Array<Integer>] Its left, top, width and height on the screen.
        def placed(rect)
          super
          size = measured_size
          return if size == @last_size

          @last_size = size
          relayout
        end

        # Tells its size: what the component's measure answers for the room its parent has.
        #
        # @return [Array, nil] Its width and height, nil without a component.
        def measure
          drawn = @options[:drawn]
          return nil unless drawn

          room = @parent && @parent.content_rect
          drawn.measure(room && room.width, room && room.height)
        end

        # Draws what the component's draw puts on the picture in its place; a draw that fails is
        # logged once with the mod's file and line.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          drawn = @options[:drawn]
          return unless drawn

          drawn.draw(canvas.bitmap, canvas.area(0, 0, canvas.width, canvas.height))
        rescue StandardError => e
          Errors.report(e, "the draw of #{drawn.class}")
        end

        # Measures it again, laying it out anew when its size changed, and draws it again, as its
        # component rendered again.
        def refresh
          size = measured_size
          relayout unless size == @last_size
          @last_size = size
          redraw
        end
      end
    end
  end
end
