#----------------------------------------------------------------
#  colors.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Let a pulse go through any number of colors and gave mods the rainbow's colors as UI::RAINBOW
#                            - Left the game windows their own outline round a dark text
#      Paulinchen  2026-11-06: Worked out the slides and pulses here instead of in C#
#      Paulinchen  2026-11-05: Outlined a dark text of a game window in text_light
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A color name that changes with the letter, or the band of an area, and the frame, as drawn in
      # one preset: a slide, a pulse or a mod's lambda. A canvas draws a text in it letter by letter
      # and an area in bands (Canvas#text, Canvas#fill).
      class Animated
        # @return [Symbol] Its name.
        attr_reader :name

        # @return [Theme::Preset] The preset it is drawn in, whose colors a slide or a pulse takes.
        attr_reader :preset

        # @return [Integer] How far an area in it lightens toward white, in percent.
        attr_reader :lift

        # Makes an animated color as drawn in a preset.
        #
        # @param name [Symbol] Its name.
        # @param preset [Theme::Preset] The preset.
        # @param lift [Integer] How far an area in it lightens toward white, in percent.
        def initialize(name, preset, lift = 0)
          @name = name
          @preset = preset
          @lift = lift
        end

        # Tells the colors of its first letters or bands now.
        #
        # @param count [Integer] How many.
        # @return [Array<Color>] The colors, left to right.
        def colors(count)
          Colors.colors_of(self, count)
        end
      end

      # An animated color name lightened toward white, as C# answers the lit fill of a filled part in
      # it: its name and how far, in percent.
      Lifted = Struct.new(:name, :lift)

      # The animated color names: the slides and pulses and the lambdas mods named colors by, the
      # colors of each frame, and the parts drawn in an animated color, which draw anew every REDRAW
      # frames while they show.
      module Colors
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # Who the hook on the game's text codes is registered by.
        TAG = "Mod Framework colors"

        # A color name in the brackets of the game's text code \C, as the text holds it past the code.
        NAME_CODE = /\A\[([A-Za-z_]\w*)\]/

        # The frames between two draws of what is drawn in an animated color, as a mod redraws its
        # rainbow names.
        REDRAW = 3

        # The width in pixels of one band of an area drawn in an animated color, about a letter's.
        BAND = 10

        # How far one letter lies from the next on a slide's cycle, in degrees, as a mod's rainbow
        # names step.
        STEP = 42

        # The degrees a slide or a pulse moves a frame unless the mod gives a speed.
        SPEED = 3

        # The fastest speed a mod may give, half a cycle a frame.
        MOST_SPEED = 180

        # The colors of the built-in :rainbow, a slide through every hue; frozen, as mods take them
        # as UI::RAINBOW.
        RAINBOW = [[255, 0, 0], [255, 255, 0], [0, 255, 0], [0, 255, 255], [0, 0, 255], [255, 0, 255]].map(&:freeze).freeze

        # The letters and the frames a mod's lambda is sampled at as it is named: eight letters over
        # a cycle of 360 frames, which a filled part picks its text color by.
        SAMPLE_LETTERS = (0..7).to_a
        SAMPLE_FRAMES = (0...360).step(10).to_a

        # The lambdas mods named colors by, by the name.
        @lambdas = {}

        # The slides and pulses, each [kind, colors, speed], by the name.
        @moving = { :rainbow => [:slide, RAINBOW, SPEED] }

        # The places on the screen to draw anew of each part drawn in an animated color.
        @drawn = {}.compare_by_identity

        # The rows of game windows to draw anew, each window's rows as a Hash of true by the index.
        @rows = {}.compare_by_identity

        # The colors worked out in the frame @frame, by the preset's name, the color name and the count.
        @worked_out = {}
        @frame = nil

        # Names a color by a mod's lambda of the letter and the frame; C# keeps the name with the
        # colors the lambda answers over a cycle, which a filled part picks its text color by.
        #
        # @param name [Symbol] The name.
        # @param lambda [Proc] The lambda, answering a Color, [r, g, b(, a)], "#RRGGBB" or a plain
        #   color name.
        # @param mod [String] The mod that names it.
        # @return [String, nil] Why it was refused, nil once named.
        def self.add_lambda(name, lambda, mod)
          samples = samples_of(name, lambda)
          return samples if samples.is_a?(String)

          refused = Theme.add_effect(name, samples, mod)
          @lambdas[name] = lambda unless refused
          refused
        end

        # Names a color that slides or pulses; C# keeps the name with its colors, which a filled part
        # picks its text color by.
        #
        # @param name [Symbol] The name.
        # @param effect [Hash] :slide or :pulse, its colors, and :speed.
        # @param mod [String] The mod that names it.
        # @return [String, nil] Why it was refused, nil once named.
        def self.add_moving(name, effect, mod)
          kind = effect[:slide] ? :slide : :pulse
          refused = Theme.add_effect(name, effect[kind], mod)
          @moving[name] = [kind, effect[kind], effect[:speed] || SPEED] unless refused
          refused
        end

        # Samples a mod's lambda at SAMPLE_LETTERS over SAMPLE_FRAMES; a lambda that fails is logged
        # once and stands for the text color, as it draws.
        #
        # @param name [Symbol] The color's name.
        # @param lambda [Proc] The lambda.
        # @return [Array<Color>, String] The different colors it answered, or why it is refused.
        def self.samples_of(name, lambda)
          found = []
          SAMPLE_FRAMES.each do |frame|
            SAMPLE_LETTERS.each do |letter|
              answer = lambda.call(letter, frame)
              color = color_of(answer)
              return "the lambda of the color :#{name} answers #{Logging.short(answer.inspect)}, which is no color" unless color

              found << color
            end
          end
          found.uniq { |color| [color.red, color.green, color.blue, color.alpha] }
        rescue StandardError => e
          failed(name, e)
          [Style::TEXT]
        end
        private_class_method :samples_of

        # Finds an animated color by its name, as drawn in a preset.
        #
        # @param name [Symbol] The name.
        # @param preset [Theme::Preset] The preset.
        # @param lift [Integer] How far an area in it lightens toward white, in percent.
        # @return [Animated, nil] The color, nil for a name that does not move.
        def self.find(name, preset, lift = 0)
          @lambdas.key?(name) || @moving.key?(name) ? Animated.new(name, preset, lift) : nil
        end

        # Tells the colors of an animated color's first letters or bands in this frame, each worked
        # out once a frame.
        #
        # @param animated [Animated] The color.
        # @param count [Integer] How many.
        # @return [Array<Color>] The colors.
        def self.colors_of(animated, count)
          frame = Key.frame
          unless frame == @frame
            @worked_out = {}
            @frame = frame
          end
          @worked_out[[animated.preset.name, animated.name, count]] ||= worked_out(animated, frame, count)
        end

        # Notes a place a part drew in an animated color, so it draws there anew every REDRAW frames
        # while it shows.
        #
        # @param component [Component] The part.
        # @param rect [Rect] The place on the screen.
        def self.note(component, rect)
          kept = @drawn[component]
          @drawn[component] = kept ? joined(kept, rect) : rect
        end

        # Notes a row of a game window drawn in an animated color, so it draws anew every REDRAW frames
        # while the window shows.
        #
        # @param window [Window_Selectable] The window.
        # @param index [Integer] The row.
        def self.note_row(window, index)
          (@rows[window] ||= {})[index] = true
        end

        # Has every part and every game window's row drawn in an animated color that shows draw anew,
        # every REDRAW frames; one whose root closed or whose window was freed is let go. Called before
        # the roots draw for each frame.
        def self.redraw
          return if (@drawn.empty? && @rows.empty?) || Key.frame % REDRAW != 0

          redraw_rows
          @drawn.keys.each do |component|
            root = component.root
            next @drawn.delete(component) unless root.open?
            next unless component.shown?

            rect = @drawn.delete(component)
            component.scrolls_part? ? component.redraw_content : redraw_place(component, rect)
          end
        end

        # Tells how many parts are drawn in an animated color, for the tests.
        #
        # @return [Integer] The parts.
        def self.parts
          @drawn.size
        end

        # Logs once that a text or a part names a color nobody named, with the nearest name.
        #
        # @param component [Component] The part.
        # @param name [Symbol] The name.
        def self.unknown(component, name)
          return unless Logging.first_time?(Colors, [:unknown, name])

          near = Declarations.nearest(name, Declarations.color_names)
          component.mod_log("#{component.describe} names the color #{name.inspect}, which is no color name#{near ? "; did you mean #{near.inspect}?" : ''} It draws in the text color")
        end

        # Lets the game's own windows take a color name in the text code \C, such as \C[legendary],
        # \C[primary] or \C[rainbow], once the game runs; their texts keep the game's own outline.
        def self.install
          return unless defined?(::Window_Base) && ::Window_Base.private_method_defined?(:process_escape_character)

          Hooks.around(::Window_Base, :process_escape_character, TAG) { |window, args, original| Mod_Framework::UI::Engine::Colors.escape(window, args, original) }
        end

        # Takes a text code of a game window: \C with a color name sets the text's color to that
        # name's in the window's look, an animated one its color now, which the window keeps as drawn;
        # every other code, \C with a number too, goes to the game.
        #
        # @param window [Window_Base] The window.
        # @param args [Array] The code, the text left and the drawing's position.
        # @param original [Proc] Takes the code as the game does.
        # @return [Object] What taking it returns.
        def self.escape(window, args, original)
          code, text = args
          name = code.to_s.upcase == "C" && text.is_a?(String) ? text[NAME_CODE, 1] : nil
          return original.call unless name

          text.slice!(NAME_CODE)
          color = Theme.palette_for(window).now(name.to_sym)
          game_unknown(name.to_sym) unless color
          window.send(:change_color, color || window.send(:normal_color))
        end

        # Logs once that a game window's text names a color nobody named, with the nearest name.
        #
        # @param name [Symbol] The name.
        def self.game_unknown(name)
          near = Declarations.nearest(name, Declarations.color_names)
          log_once([:unknown, name], "a game window's text names the color #{name.inspect}, which is no color name#{near ? "; did you mean #{near.inspect}?" : ''} It draws in the normal color")
        end
        private_class_method :game_unknown

        # Tells a color of the color wheel, as the rainbow's letters take them.
        #
        # @param degrees [Numeric] The hue, any number: 0 red, 60 yellow, 120 green, 180 cyan, 240 blue,
        #   300 magenta.
        # @return [Color] The color.
        def self.hue(degrees)
          hue = degrees.to_f % 360
          rising = (255 * (1 - ((hue / 60) % 2 - 1).abs)).round
          case (hue / 60).floor
          when 0 then Color.new(255, rising, 0)
          when 1 then Color.new(rising, 255, 0)
          when 2 then Color.new(0, 255, rising)
          when 3 then Color.new(0, rising, 255)
          when 4 then Color.new(rising, 0, 255)
          else Color.new(255, 0, rising)
          end
        end

        # Reads a color a lambda answers: a Color, [r, g, b(, a)], "#RRGGBB" or a plain color name of
        # the player's preset.
        #
        # @param value [Object] The value.
        # @return [Color, nil] The color, nil for none.
        def self.color_of(value)
          return value if value.is_a?(Color)
          return Color.new(*value) if value.is_a?(Array) && [3, 4].include?(value.size) && value.all? { |each| each.is_a?(Integer) }
          return Color.new(*[value[1, 6]].pack("H*").unpack("C3")) if value.is_a?(String) && value =~ /\A#\h{6}\z/

          value.is_a?(Symbol) ? Palette.live.named(value) : nil
        end

        # Lets go of every part and row noted, as F12 starts the game again.
        def self.reset
          @drawn = {}.compare_by_identity
          @rows = {}.compare_by_identity
          @worked_out = {}
        end

        # Works out an animated color's colors: its slide or pulse, or the mod's lambda; the text
        # color where the lambda answers no color.
        #
        # @param animated [Animated] The color.
        # @param frame [Integer] The frame.
        # @param count [Integer] How many.
        # @return [Array<Color>] The colors.
        def self.worked_out(animated, frame, count)
          lambda = @lambdas[animated.name]
          return moved(@moving[animated.name], animated.preset, frame, count) unless lambda

          found = (0...count).map { |letter| color_of(lambda.call(letter, frame)) }
          found.all? ? found : Array.new(count) { Style::TEXT }
        rescue StandardError => e
          failed(animated.name, e)
          Array.new(count) { Style::TEXT }
        end
        private_class_method :worked_out

        # Logs once per name and kind of error that a mod's lambda failed.
        #
        # @param name [Symbol] The color's name.
        # @param error [StandardError] What it raised.
        def self.failed(name, error)
          log_once([:lambda, name, error.class], "the color :#{name} failed, so it draws in the text color: #{Logging.failure(error)}")
        end
        private_class_method :failed

        # Works out a slide or a pulse: a slide steps STEP degrees of its cycle a letter and its speed
        # a frame, a pulse colors every letter alike, going through its colors in turn and back to
        # the first.
        #
        # @param moving [Array(Symbol, Array, Integer)] Its kind, its colors and its speed.
        # @param preset [Theme::Preset] The preset its color names are taken in.
        # @param frame [Integer] The frame.
        # @param count [Integer] How many.
        # @return [Array<Color>] The colors.
        def self.moved(moving, preset, frame, count)
          kind, stops, speed = moving
          stops = stops.map { |stop| stop_color(stop, preset) }
          segment = 360.0 / stops.size
          if kind == :pulse
            place = frame * speed % 360
            from = [(place / segment).floor, stops.size - 1].min
            share = (1 - Math.cos((place - from * segment) / segment * Math::PI)) / 2
            return Array.new(count) { toward(stops[from], stops[(from + 1) % stops.size], share) }
          end

          (0...count).map do |letter|
            place = (letter * STEP - frame * speed) % 360
            from = [(place / segment).floor, stops.size - 1].min
            toward(stops[from], stops[(from + 1) % stops.size], (place - from * segment) / segment)
          end
        end
        private_class_method :moved

        # Reads a color of a slide or a pulse in a preset; a name the preset does not hold takes its
        # text color.
        #
        # @param stop [Symbol, String, Array, Color] A color name, "#RRGGBB", [r, g, b(, a)] or a Color.
        # @param preset [Theme::Preset] The preset.
        # @return [Color] The color.
        def self.stop_color(stop, preset)
          named = stop.is_a?(Symbol) || (stop.is_a?(String) && !stop.start_with?("#"))
          found = named ? preset.roles[stop.to_sym] || preset.roles[:text] : color_of(stop)
          found.is_a?(Array) ? Color.new(*found) : found || Style::TEXT
        end
        private_class_method :stop_color

        # Tells the color a share of the way from one color to another, in whole numbers, with the
        # first color's alpha.
        #
        # @param from [Color] The one color.
        # @param to [Color] The other.
        # @param share [Float] How far, from 0 to 1.
        # @return [Color] The color between.
        def self.toward(from, to, share)
          mix = lambda { |one, other| (one + (other - one) * share).round }
          Color.new(mix.call(from.red, to.red), mix.call(from.green, to.green), mix.call(from.blue, to.blue), from.alpha)
        end
        private_class_method :toward

        # Draws the noted rows of the game windows that show anew, each noting itself again as it
        # draws in an animated color.
        def self.redraw_rows
          @rows.keys.each do |window|
            next @rows.delete(window) if window.disposed?
            next unless window.visible && window.openness > 0

            @rows.delete(window).keys.each { |index| window.redraw_item(index) if index < window.item_max }
          end
        end
        private_class_method :redraw_rows

        # Tells the rectangle that holds two others.
        #
        # @param one [Rect] One rectangle.
        # @param other [Rect] The other.
        # @return [Rect] The rectangle holding both.
        def self.joined(one, other)
          left = [one.x, other.x].min
          top = [one.y, other.y].min
          Rect.new(left, top, [one.x + one.width, other.x + other.width].max - left, [one.y + one.height, other.y + other.height].max - top)
        end
        private_class_method :joined

        # Draws a part's place anew on the picture it lies on.
        #
        # @param component [Component] The part.
        # @param rect [Rect] The place on the screen.
        def self.redraw_place(component, rect)
          surface = component.surface
          return unless surface

          surface.respond_to?(:invalidate) ? surface.invalidate(rect) : surface.dirty = true
        end
        private_class_method :redraw_place
      end
    end

    # Once the game runs, the game's windows take color names in \C.
    Run.on_start("colors") { Mod_Framework::UI::Engine::Colors.install }

    # The colors of the rainbow, red, yellow, green, cyan, blue and magenta, for a slide or a pulse of
    # a mod's own, such as UI.color :festival, pulse: UI::RAINBOW.
    RAINBOW = Engine::Colors::RAINBOW

    # Tells a color of the color wheel, such as for a color a mod names by a lambda:
    # UI.color :glow, ->(letter, frame) { UI.hue(letter * 42 - frame * 3) }.
    #
    # @param degrees [Numeric] The hue: 0 red, 60 yellow, 120 green, 180 cyan, 240 blue, 300 magenta.
    # @return [Color] The color.
    def self.hue(degrees)
      Engine::Colors.hue(degrees)
    end
  end
end
