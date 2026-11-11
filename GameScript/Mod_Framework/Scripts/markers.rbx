#----------------------------------------------------------------
#  markers.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Drew a marker's triangle from the arrow of its angle, so its place carries no rows
#                            - Removed an arrow's :triangle, which no caller set, so C# alone keeps its size
#      Paulinchen  2026-11-07: Wrote the plain text of a bubble by contrast with its fill only under contrast
#                            - Removed add_arrow of the old API
#      Paulinchen  2026-11-06: Drew a bubble's body a little see-through and what it holds whole
#                            - Called the engine's classes by their names under UI::Engine
#                            - Removed the text and the frames a bubble took, which only MGQ Online's chat gave it
#      Paulinchen  2026-11-05: Made the speech bubble a root that holds any parts, its plain text on its fill
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Closed a bubble after its seconds of real time while the game is in front
#                            - Wrote a bubble's text in text_dark or text_light, whichever reads better on its fill
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Hid a bubble while it has no character to follow
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The geometry of the markers and the arrows, kept in C# (MarkerModel): where a marker sits at
      # the screen's edge, which way it points, its picture, and an arrow's rows.
      module Markers
        # Places a marker, MarkerModel.PlaceTopic.
        PLACE = "ui.marker.place"

        # Lays out an arrow, MarkerModel.ArrowTopic.
        ARROW = "ui.marker.arrow"

        # The color of an arrow's outline: the solid outline of the texts.
        OUTLINE = Style::OUTLINE

        # The arrows laid out, by angle.
        @arrows = {}

        # Lays out an arrow: a marker's triangle pointing along an angle with its outline, its size
        # kept in C#.
        #
        # @param angle [Integer] Degrees, 0 to the right and 90 down.
        # @return [Array, nil] The picture's left and top from the triangle's center, its width and
        #   height, and its rows ([x, y, width, fill]); nil without the DLL or when the call failed.
        def self.arrow(angle)
          @arrows[angle.to_i] ||= Mod_Framework.available? ? Mod_Framework.bridge.call(ARROW, [angle.to_i]) : nil
        end

        # Places a marker, see MarkerModel.PlaceTopic.
        #
        # @param from [Array<Integer>] Where the line starts on the screen.
        # @param to [Array<Integer>] Where it points.
        # @param margin [Array<Integer>] Pixels the marker keeps from each edge of the screen: top,
        #   right, bottom and left.
        # @param plate_width [Integer] Its plate's width.
        # @return [Array, nil] x, y, the angle stepped, the picture's left, top, width and height, the
        #   plate's x and y and the slide's x and y; nil for two equal spots or without the DLL.
        def self.place(from, to, margin, plate_width)
          return nil unless Mod_Framework.available?

          Mod_Framework.bridge.call(PLACE, [from[0], from[1], to[0], to[1], Graphics.width, Graphics.height, Layout.docked_room(:top)] + margin + [plate_width])
        end

        # Fills the rows of a triangle: the outline's in OUTLINE, the fill's in a color.
        #
        # @param canvas [Canvas] Where it draws.
        # @param rows [Array<Array<Integer>>] The rows, [x, y, width, fill].
        # @param color [Symbol, Integer, Color] The fill's color.
        # @param x [Integer] Where the rows' 0 lies, x.
        # @param y [Integer] Where the rows' 0 lies, y.
        def self.fill(canvas, rows, color, x = 0, y = 0)
          Array(rows).each { |left, top, width, filled| canvas.fill(x + left, y + top, width, 1, filled == 1 ? color : OUTLINE) }
        end
      end

      # A filled triangle pointing along an angle in degrees (0 right, 90 down), with the solid
      # outline, as large as a marker's.
      class Arrow < Component
        include StateBlind

        # Tells the defaults of the options: pointing right in the text color.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:angle => 0, :color => :text)
        end

        # Tells which properties of C#'s tree each option sets: another angle measures anew.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:angle => ["measured"])
        end

        options :angle, :color

        # Tells its size: its picture's, the outline included.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          picture = laid_out
          picture ? [picture[2], picture[3]] : [0, 0]
        end

        # Draws the triangle in the middle of its place.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          picture = laid_out
          return unless picture

          Markers.fill(canvas, picture[4], @options[:color], (canvas.width - picture[2]) / 2, (canvas.height - picture[3]) / 2)
        end

        private

        # Lays the arrow out in C#.
        #
        # @return [Array, nil] See Markers.arrow.
        def laid_out
          Markers.arrow(@options[:angle].to_i)
        end
      end

      # The colors of the parts a filled part with contrast holds: those of another palette, but the
      # plain text in text_dark or text_light, whichever contrasts more with the fill.
      class FilledPalette < Palette
        # Makes the colors of a fill.
        #
        # @param source [Palette] The colors around the filled part.
        # @param fill [Symbol, Color] The fill.
        def initialize(source, fill)
          @source = source
          text = source.text_on(fill)
          @text = text.is_a?(Color) ? text : source.named(text) || Style::TEXT
          super(Hash[ROLES.map { |role| [role, source[role]] }], source.preset, nil)
        end

        # @return [Palette] The colors around the filled part.
        attr_reader :source

        # Finds a color name's color: the plain text color the one on the fill, any other the
        # source's.
        #
        # @param name [Symbol] The name.
        # @return [Color, nil] The color, nil for a name the source does not hold.
        def named(name)
          name == :text ? @text : @source.named(name)
        end
      end

      # A speech bubble that follows a character and holds any parts, as the layer's bubble makes
      # it: its fill in :color, the plain text of what it holds in the plain text color, under
      # :contrast in text_dark or text_light, whichever contrasts more with the fill (FilledPalette),
      # a dark edge and a tail toward the character, its body a little see-through and what it holds whole. :width (240) is the widest it gets. :seconds closes it after that many
      # seconds of real time while the game is in front (Clock), never without. It hides while
      # :follow is nil.
      class Bubble < Box
        # The opacity of the bubble's body, 85 % of whole.
        OPACITY = 217

        # Its edge's color.
        DARK = Color.new(24, 24, 24)

        # Pixels its tail reaches toward the character.
        TAIL = 6

        # Room between its edge and what it holds.
        INSET = 6

        # Its widest unless told.
        WIDTH = 240

        # Tells the defaults of the options: white, until closed.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:color => Color.new(255, 255, 255), :seconds => nil, :frame => false, :mouse => false,
                      :z => Z[:bubbles])
        end

        options :color, :seconds

        # Makes the bubble.
        #
        # @param options [Hash] :follow, :side (:above, :below or :middle), :color, :width (the
        #   widest), :seconds and the options of a root.
        def initialize(options = {})
          widest = options[:width] || WIDTH
          side = options[:side] || :above
          tail = side == :middle ? 0 : TAIL
          padding = side == :below ? [INSET + tail, INSET, INSET, INSET] : [INSET, INSET, INSET + tail, INSET]
          super({ :min_size => [2 * (INSET + TAIL), 0] }.merge(options.reject { |key, _value| key == :width }).merge(:max_size => [widest, nil], :padding => padding))
        end

        # Tells its fill's color.
        #
        # @return [Symbol, Color] The color.
        def fill
          @options[:color]
        end

        # Hands out the colors of what it holds: its theme's, under contrast with the plain text on
        # its fill.
        #
        # @return [Palette] The palette.
        def palette
          own = @options[:theme]
          source = Theme.palette(own.nil? ? (@parent ? @parent.theme_value : true) : own)
          return source unless contrast?

          @filled = nil unless @filled && @filled.source.equal?(source) && @filled_for == [fill, Theme.serial]
          @filled_for = [fill, Theme.serial]
          @filled ||= FilledPalette.new(source, fill)
        end

        # Tells the theme what it holds draws in: its own colors, see palette.
        #
        # @return [Palette] The palette.
        def theme_value
          palette
        end

        # Opens it, counting its seconds from now when it has :seconds.
        #
        # @return [Bubble] Itself.
        def open
          @ends = @options[:seconds] && Clock.seconds + @options[:seconds].to_f
          super
          Tree.ticking(self, true) if open? && @ends
          self
        end

        # Counts a frame, closing it once its seconds ran out.
        #
        # @return [Boolean] Whether it still counts.
        def frame_tick
          return false unless open? && @ends
          return true if Clock.seconds < @ends

          close(:script)
          false
        end

        # Draws its body in its color with a dark edge and its tail toward the character, a little
        # see-through, and what it holds whole.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          side = @options[:side] || :above
          tail = side == :middle ? 0 : TAIL
          top = side == :below ? tail : 0
          height = canvas.height - tail
          body = body_color(canvas)
          canvas.fill(0, top, canvas.width, height, body)
          canvas.outline(0, top, canvas.width, height, Style.see_through(DARK, OPACITY))
          draw_container(canvas)
          return if tail == 0

          middle = canvas.width / 2
          tail.times do |step|
            width = 2 * (tail - step) - 1
            y = side == :below ? tail - 1 - step : height + step
            canvas.fill(middle - width / 2, y, width, 1, body)
          end
        end

        private

        # Tells that it follows a character, with or without one yet.
        #
        # @return [Boolean] True.
        def follows?
          true
        end

        # Follows a changed option: a new fill draws what it holds anew, whose text color follows it.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          @children.each { |child| child.redraw } if name == :color
        end

        # Tells the color its body draws in: its :color at OPACITY, an animated color whole as it
        # moves.
        #
        # @param canvas [Canvas] Where it draws.
        # @return [Symbol, Color] The color.
        def body_color(canvas)
          color = @options[:color]
          return color if color.is_a?(Symbol) && canvas.palette.animated(color)

          Style.see_through(canvas.color(color), OPACITY)
        end
      end

      # An arrow at the screen's edge toward a character, or a tile ([x, y]), while it is off the
      # screen, with :text on a plate inside the screen; on the screen it fades out. The line starts
      # at :from (the player unless told), keeps :margin (14 pixels, or [top, right, bottom, left])
      # from the screen's edges and clear of the strips docked at the top; C#'s tree takes no margin
      # of it, as it places itself by :at. Its angle steps by 10 degrees, and it slides in as it fades in.
      class Marker < Box
        # Pixels from a character's feet up to the middle of its tile.
        HALF_TILE = 16

        # The side of a map tile.
        TILE = 32

        # Tells the defaults of the options: toward nothing, from the player, under the windows.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:target => nil, :text => "", :color => :text, :from => :player, :margin => 14, :frame => false, :mouse => false, :z => Z[:arrows],
                      :fade => true)
        end

        options :target, :text, :color, :from, :margin

        # Points it for the frame: where its target lies off the screen it shows at the edge, else it
        # hides. Called before every frame's layout.
        def follow_place
          to = spot_of(@options[:target])
          from = spot_of(@options[:from])
          on = to && from && !on_screen?(to) ? Markers.place(from, to, sides_of(@options[:margin]), plate_width) : nil
          @away = on.nil?
          return unless on

          @placed = on
          at = [on[0] + on[3], on[1] + on[4]]
          self.at = at unless at == @options[:at]
          size = [on[5], on[6]]
          self.size = size unless size == @options[:size]
          slide
          redraw unless on[2] == @angle
          @angle = on[2]
        end

        # Tells the properties C#'s tree lays it out by, without a margin, which it keeps from the
        # screen's edges itself.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["margin"] = NO_ROOM
          props
        end

        # Draws its triangle, the arrow of its angle placed in its picture, and its plate with its text.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          return unless @placed

          arrow = Markers.arrow(@placed[2])
          Markers.fill(canvas, arrow[4], @options[:color], arrow[0] - @placed[3], arrow[1] - @placed[4]) if arrow
          text = @options[:text].to_s
          return if text.empty?

          canvas.fill(@placed[7], @placed[8], plate_width, Markers::PLATE_HEIGHT, :plate)
          canvas.text(@placed[7], @placed[8], plate_width, Markers::PLATE_HEIGHT, text, :size => :small, :align => :center)
        end

        private

        # Tells whether it hides now: while its target is on the screen or gone, besides the hiding
        # of every root.
        #
        # @return [Boolean] Whether it does.
        def hidden_now?
          @away || super
        end

        # Shifts it toward the edge while it fades in, the slide's share as much as the fade has left.
        def slide
          share = 1.0 - (@fade || Component::OPAQUE).to_f / Component::OPAQUE
          @options[:offset] = [(@placed[9] * share).round, (@placed[10] * share).round]
        end

        # Tells the plate's width around its text.
        #
        # @return [Integer] The pixels.
        def plate_width
          text = @options[:text].to_s
          text.empty? ? 0 : UI.text_width(UI.font_bitmap(Style::SMALL_SIZE), text) + 2 * Style::PAD
        end

        # Tells where a character, :player or a tile lies on the screen: the middle of its tile.
        #
        # @param target [Symbol, Game_Character, Array<Integer>, nil] What.
        # @return [Array<Integer>, nil] The x and y, nil for nothing that shows.
        def spot_of(target)
          if target.is_a?(Array)
            return nil unless $game_map

            return [($game_map.adjust_x(target[0]) * TILE + TILE / 2).round, ($game_map.adjust_y(target[1]) * TILE + TILE / 2).round]
          end
          anchor = Game.anchor_of(target)
          anchor && [anchor[:x], anchor[:y] - HALF_TILE]
        end

        # Tells whether a spot lies on the screen.
        #
        # @param spot [Array<Integer>] The spot.
        # @return [Boolean] Whether it does.
        def on_screen?(spot)
          spot[0] >= 0 && spot[1] >= 0 && spot[0] < Graphics.width && spot[1] < Graphics.height
        end
      end

      module Markers
        # The height of a marker's plate, MarkerModel.PlateHeight.
        PLATE_HEIGHT = 20
      end
    end
  end
end
