#----------------------------------------------------------------
#  wheel.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Took whether it leaves at once as the second argument of close, as every root does
#      Paulinchen  2026-11-07: Read typing from UI.typing?
#                            - Read a greyed choice from :disabled
#      Paulinchen  2026-11-06: Freed its sprite once it no longer shows, so the viewport it lay on no longer keeps it
#                            - Stopped timing the frame for the probe, which is gone
#                            - Called the engine's classes by their names under UI::Engine
#                            - Removed defining a wheel by its name before the game runs and naming a pick's direction, which
#                              only MGQ Online's own wheels used
#      Paulinchen  2026-11-05: Logged once that a block gave a wheel more than eight choices
#                            - Took no focus as UI.open of an open wheel asks for it, and told where its picture lies
#                            - Made no lists while no wheel is open or gone
#                            - Lit no choice that cannot be taken and refused one a let go button took
#                            - Moved its picture onto the screen before the game frees the viewport it lies on
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#                            - Measured the wheels' frame while a probe runs
#                            - Greyed out a choice that cannot be taken instead of drawing it see-through
#      Paulinchen  2026-11-01: Drew a wheel that follows over the map's pictures and told gone a frame after its last picture
#                            - Showed a wheel that follows only in the scene it opened in
#                            - Moved a wheel by its :offset and showed a refused choice's tooltip as a notice
#                            - Told close with :reset to every wheel F12 closed
#      Paulinchen  2026-10-31: Closed a wheel on every cancel of UI.cancel? and named the bound cancel key in its hint
#                            - Took the root parts, choices from blocks, choices that cannot be taken, wide boxes and a text for none
#      Paulinchen  2026-10-30: Took its cover from the roots
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A wheel of up to eight choices around a middle, generated from the choices: its choices
      # spread evenly over the eight directions the arrows point to, clockwise from the top, the
      # arrows held point at one like a joystick, the pointer moving over it points too, and confirm
      # or a click takes the choice, which closes the wheel. Cancel, the numpad's 0 and a click outside
      # it close it without a choice. C# keeps its rules (WheelModel); here it draws and hands the
      # choice over. While it is open it holds the game's buttons and covers every root below it, and
      # while a Dialog or the confirm lies above it, it waits.
      #
      # The class also carries what every wheel shares: defining a wheel in C#, handing it a frame
      # (put), placing choices and drawing the hint under a wheel.
      #
      # A Wheel of the components takes the root parts: :if (asked every frame, refusing the open and
      # closing it), :hotkey, :fade (on by default), :follow (on the character's middle, drawn over the
      # map's pictures and under every other root), :offset (pixels from its middle), and tells open
      # and close with why (Root::CLOSE_REASONS), then gone once nothing of it shows. :choices and
      # :center may be blocks, asked every frame; a count that changes drops the pick to the middle,
      # or to none. A choice with :disabled => true is greyed out and refuses to be taken; without a
      # refuse block its :tooltip shows as a notice. :look => :boxes draws wide boxes in two
      # columns, one above and one below, :box_width wide; :none_text names the pick of none.
      #
      # Events: open, submit (the choice taken: one of :choices as given, or :center), refuse (a
      # choice with :disabled => true confirmed or clicked), close (why), gone (a frame after its last
      # picture showed).
      class Wheel < Component
        # The directions the arrows can point to, clockwise from the top, WheelDirection in C#.
        DIRECTIONS = [:UP, :UP_RIGHT, :RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :LEFT, :UP_LEFT]

        # The wheels' event, WheelModel.EventTopic.
        EVENT = "ui.wheel"

        # Defines a wheel in C#, WheelModel.DefineTopic.
        DEFINE = "ui.wheel.define"

        # Closes a wheel from outside, WheelModel.CloseTopic.
        CLOSE = "ui.wheel.close"

        # Places a count of choices, WheelModel.PlacesTopic.
        PLACES = "ui.wheel.places"

        # What a wheel's event names the middle choice, WheelModel.Center.
        CENTER = -1

        # The bits of the arrows held, WheelArrows in C#.
        ARROW_BITS = { :UP => 1, :DOWN => 2, :LEFT => 4, :RIGHT => 8 }

        # Height of the hint under a wheel, see draw_hint.
        HINT_HEIGHT = 18

        # Side of a choice's box.
        BOX = 36

        # Pixels from the wheel's middle to the middle of each choice's box.
        RADIUS = 60

        # Side of the box in the middle of a wheel without a middle choice, which stands for none.
        NONE_BOX = 12

        # Height of the line naming the choice pointed at.
        NAME_HEIGHT = 22

        # Width and height of the ring.
        SIZE = (RADIUS + BOX) * 2

        # Height of its picture: the ring, the name and the hint.
        HEIGHT = SIZE + NAME_HEIGHT + HINT_HEIGHT

        # How far past the boxes the pointer still points at the wheel.
        REACH = 8

        # How a wheel of the components looks: a ring of square boxes, or wide boxes in two columns.
        LOOKS = [:ring, :boxes]

        # Height of a wide box.
        ROW = 28

        # Room between two wide boxes.
        GAP = 4

        # Side of a choice's icon or picture in a wide box.
        MARK = 24

        # Where each direction's wide box lies: its column (-1 left, 0 the middle, 1 right) and row.
        BOX_PLACES = { :UP => [0, -2], :UP_RIGHT => [1, -1], :RIGHT => [1, 0], :DOWN_RIGHT => [1, 1], :DOWN => [0, 2], :DOWN_LEFT => [-1, 1],
                       :LEFT => [-1, 0], :UP_LEFT => [-1, -1] }

        # Why a wheel closed, by the reason C# tells; any other reason is told as it is.
        REASONS = { "its key" => :hotkey, "a click outside it" => :outside, "cancel" => :cancel, "confirmed with nothing pointed at" => :cancel,
                    "took a choice" => :submit, "the scene changed" => :scene }

        # The wheels of the components fading out after they closed.
        @fading = []

        # The wheels of the components that stopped showing, each with the count of drawn frames then.
        @gone = []

        # The frames the wheels of the components were drawn for.
        @drawn_frames = 0

        # What the names of the wheels of the components start with in C#.
        MODEL_PREFIX = "mf.wheel."

        # The wheels C# took the definition of.
        @known = {}

        # The places of each count of choices C# answered.
        @places = {}

        # The wheels of the components open or opening.
        @open_wheels = []

        # The last number a wheel of the components was named with.
        @last_model = 0

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "wheel"

        # Tells whether C# knows a wheel.
        #
        # @param name [String] The wheel's name.
        # @return [Boolean] Whether it does.
        def self.known?(name)
          @known[name.to_s] == true
        end

        # Hands a wheel its frame: whether the scene leaves it free, its key, and while it is open
        # cancel (UI.cancel?), confirm and the arrows held, past the capture; no button reads while a
        # text field types. A wheel C# does not know gets nothing, since the tick refuses a model it lacks.
        #
        # @param name [String] The wheel's name in the tick.
        # @param free [Boolean, String] true, or why the wheel may not show, which closes it.
        # @param key [Boolean] Whether its key went down.
        # @param count [Integer] How many choices it has.
        # @param open [Boolean] Whether it is open, so the buttons are read.
        # @param ring [Array<Integer>, nil] Where it shows for the pointer: its middle's x and y, the
        #   middle choice's radius and the ring's; nil for a wheel the pointer does not reach.
        # @param boxes [Array<Array<Integer>>, nil] For a wheel of boxes, the boxes the pointer hits
        #   instead of the ring: [direction or CENTER, left, top, width, height] on the screen.
        def self.put(name, free, key, count, open, ring = nil, boxes = nil)
          return log_once([:unknown, name], "the wheel #{name} gets no frame: C# does not know it") unless known?(name)

          reading = open && !UI.typing?
          arrows = 0
          ARROW_BITS.each { |button, bit| arrows |= bit if reading && Capture.press?(button) }
          cancel = reading && UI.cancel?
          confirm = reading && Capture.trigger?(:C)
          frame = [free, key ? true : false, cancel ? true : false, confirm ? true : false, arrows, count, ring]
          frame << boxes if boxes
          Tick.put(name.to_s, frame)
        end

        # Spreads a wheel's choices evenly over DIRECTIONS, clockwise from the top, as C# places them;
        # asked once per count.
        #
        # @param count [Integer] How many choices the wheel has, at most DIRECTIONS.size.
        # @return [Array<Symbol>] Each choice's direction, in the choices' order; none while the bridge
        #   is closed.
        def self.places(count)
          return @places[count] if @places.key?(count)

          answer = Mod_Framework.bridge.call(PLACES, [count])
          return [] unless answer

          @places[count] = answer.map { |direction| DIRECTIONS[direction] }
        end

        # Draws the hint under a wheel, HINT_HEIGHT high: what closes it, in the style's tiny size and
        # heading color, whole even when a key's longer name makes it wide.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param x [Integer] The hint's left.
        # @param y [Integer] The hint's top.
        # @param width [Integer] The hint's width.
        # @param also [Array<String>] What else closes it, such as its key's label.
        def self.draw_hint(bitmap, x, y, width, *also)
          Style.draw_hint(bitmap, x, y, width, HINT_HEIGHT, UI.close_hint(*also), Style::TINY_SIZE, Style::HEADING)
        end

        # Hands the wheels of the components open or opening their frames. Called just before every tick.
        def self.collect
          @open_wheels.dup.each { |wheel| wheel.collect } unless @open_wheels.empty?
        rescue => e
          log_once([:collect, e.class], "handing the wheels their frames FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Draws the wheels of the components for the frame, after telling gone those whose last
        # picture a frame already replaced. Called before every Graphics.update.
        def self.draw_frame
          unless @gone.empty?
            shown, @gone = @gone.partition { |_wheel, frame| frame >= @drawn_frames }
            @gone.each { |wheel, _frame| wheel.emit(:gone) }
            @gone = shown
          end
          @open_wheels.dup.each { |wheel| wheel.update_frame } unless @open_wheels.empty?
          @fading.reject! { |wheel| !wheel.fade_frame }
          @drawn_frames += 1
        rescue => e
          log_once([:draw, e.class], "drawing the wheels FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Hands a wheels' event to the wheel of the components it names.
        #
        # @param event [Hash] The event, see WheelModel.EventTopic.
        def self.take_event(event)
          wheel = @open_wheels.find { |each| each.model == event["wheel"] }
          wheel.take(event) if wheel
        end

        # Closes every wheel of the components quietly, here and in C#, as F12 starts the game's
        # scenes again; then the close blocks of the wheels that were open hear :reset.
        def self.reset
          dropped = @open_wheels.dup
          dropped.each { |wheel| wheel.drop }
          @open_wheels = []
          @fading.dup.each { |wheel| wheel.drop }
          @fading = []
          @gone = []
          dropped.each { |wheel| wheel.emit(:close, :reset) }
        end

        # Notes a wheel of the components opening, or forgets one closed.
        #
        # @param wheel [Wheel] The wheel.
        # @param on [Boolean] Whether it opens.
        def self.follow(wheel, on)
          on ? (@open_wheels << wheel unless @open_wheels.include?(wheel)) : @open_wheels.delete(wheel)
        end

        # Notes a wheel of the components whose picture stopped showing, told gone once a frame was
        # drawn without it.
        #
        # @param wheel [Wheel] The wheel.
        def self.note_gone(wheel)
          @gone << [wheel, @drawn_frames]
        end

        # Lets a wheel of the components that closed fade out frame by frame, or stops it at once.
        #
        # @param wheel [Wheel] The wheel.
        # @param on [Boolean] Whether it fades out.
        def self.fade_out(wheel, on)
          on ? (@fading << wheel unless @fading.include?(wheel)) : @fading.delete(wheel)
        end

        # Names a new wheel of the components in C#, defined with its settings.
        #
        # @param settings [Array<Boolean>] Whether it has a middle choice, and that confirm closes it.
        # @return [String, nil] The name, nil when C# took no definition.
        def self.new_model(settings)
          @last_model += 1
          name = "#{MODEL_PREFIX}#{@last_model}"
          define(name, settings) ? name : nil
        end

        # Defines a wheel in C#.
        #
        # @param name [String] The wheel's name.
        # @param settings [Array<Boolean>] Whether it has a middle choice, and that confirm closes it.
        # @return [Boolean] Whether C# knows the wheel now; false without the DLL.
        def self.define(name, settings)
          return false unless Mod_Framework.available?

          @known[name] = Mod_Framework.bridge.call(DEFINE, [name] + settings) == true
        end
        private_class_method :define

        # Tells the defaults of the options: no choices, no middle choice, in the screen's middle, a
        # ring, fading in and out.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:choices => [], :center => nil, :keep => false, :if => nil, :hotkey => nil, :fade => true, :follow => nil, :look => :ring,
                      :box_width => 200, :none_text => "")
        end

        options :choices, :center, :keep, :if, :hotkey, :fade, :follow, :look, :box_width, :none_text

        # @return [String, nil] Its name in C#, nil before it first opened.
        attr_reader :model

        # @return [Cover, nil] Its place in C#'s tree, nil before it first opened.
        attr_reader :cover

        # Makes the wheel and hands it to the hotkey that opens and closes it.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          Hotkeys.attach(@options[:hotkey], self) if @options[:hotkey]
        end

        # Tells that a Wheel is only ever a root, which no other component holds.
        #
        # @return [Boolean] Always true.
        def root_only?
          true
        end

        # Tells where its picture lies on the screen while it is open, as a part tells its place.
        #
        # @return [Rect, nil] The place, nil while it is closed.
        def rect
          return nil unless open?

          x, y = corner
          width, height = picture_size
          Rect.new(x, y, width, height)
        end

        # Takes no focus: it reads its keys itself while it is open.
        #
        # @return [Wheel] Itself.
        def focus
          self
        end

        # Tells why it may not open now: its :if, or another root holding the game's buttons.
        #
        # @return [String, nil] Why, nil when it may.
        def refusal
          gate_reason || (UI.busy? ? Root::BUSY_REASON : nil)
        end

        # Opens it in the next tick, holding the game's buttons from now on. Refused by its :if and
        # without the DLL, logged.
        #
        # @return [Wheel] Itself.
        def open
          return self if open? || @opening
          unless Mod_Framework.available?
            Tree.log_once([:refused_wheel, Root.mod_file(caller)], "#{Root.mod_file(caller)} opened #{describe}, refused: the framework runs without its DLL")
            return self
          end

          why = gate_reason
          if why
            Tree.log("#{describe} did not open: #{why}")
            return self
          end

          @asked = nil
          settings = [!asked[1].nil?, false]
          @model = Wheel.new_model(settings) unless @model && @settings == settings
          @settings = settings
          return self unless @model

          Wheel.fade_out(self, false)
          @opening = true
          @told_open = false
          @opacity = fades? ? 0.0 : Component::OPAQUE.to_f
          @scene = defined?(::SceneManager) ? ::SceneManager.scene : nil
          Wheel.follow(self, true)
          Capture.start(self)
          @cover = Cover.new(:z => Z[:open_wheel], :keep => @options[:keep], :at => corner, :size => picture_size)
          @cover.open
          self
        end

        # Closes it without a choice and runs its close blocks with why.
        #
        # @param why [Symbol, String] Why it closes, see Root::CLOSE_REASONS; :script from a script.
        # @param at_once [Boolean] Whether its picture goes at once, without its fade.
        # @return [Wheel] Itself.
        def close(why = :script, at_once = false)
          return self unless open? || @opening

          Mod_Framework.bridge.call(CLOSE, [@model]) if @open
          closed(true)
          hide_now if at_once && @sprite
          emit(:close, why)
          self
        end

        # Tells whether it is open or opening.
        #
        # @return [Boolean] Whether it is.
        def open?
          @open == true || @opening == true
        end

        # Tells the choice pointed at.
        #
        # @return [Object, nil] One of :choices as given, :center, or nil for none.
        def selected
          choice_at(@selected)
        end

        # Hands C# its frame: its key while it opens, whether its scene still runs, the buttons and
        # where it shows; none while a Dialog or the confirm lies above it, so it reads no key and no
        # click then. Its :if closes it, and its blocks of choices are asked anew. Called just before
        # every tick while it is open or opening.
        def collect
          why = gate_reason
          return close(why) if why

          @asked = nil
          return if covered?

          @cover.at = corner unless @cover.at == corner
          free = !@options[:keep] && scene_left? ? "the scene changed" : true
          key = @opening ? true : false
          @opening = false
          x, y = middle
          Wheel.put(@model, free, key, choices.size, @open || key, [x, y, inner_radius, RADIUS + BOX / 2 + REACH], boxes_on_screen)
        end

        # Takes its event: what is pointed at and whether it is open, and a choice taken, which closes
        # it unless the choice cannot be taken now; a wheel that closes as its button is let go on such
        # a choice buzzes and closes as cancel.
        #
        # @param event [Hash] The event, see WheelModel.EventTopic.
        def take(event)
          Tick.play(event)
          @selected = event["selected"]
          return take_choice(event["take"]) if event["open"] && event.key?("take")

          if event["open"]
            @open = true
            tell_open
            return redraw
          end

          taken = event.key?("take") && !event["take"].nil? ? choice_at(event["take"]) : nil
          closed(true)
          if taken && !enabled_choice?(taken)
            UI.buzz
            refuse(refused_choice(taken))
            return emit(:close, :cancel)
          end
          emit(:submit, taken) unless taken.nil?
          emit(:close, taken.nil? ? REASONS.fetch(event["reason"].to_s, event["reason"] || :cancel) : :submit)
        end

        # Draws it for the frame: shown in its theme around its middle, faded in, drawn anew once the
        # pick, its choices or the look changed; one that follows shows only in the scene it opened in.
        def update_frame
          return @sprite.visible = false if @sprite && (!@open || away?)

          return unless @open && !away?

          width, height = picture_size
          x, y = corner
          viewport = layer
          renew_sprite(viewport) unless @sprite && !@sprite.disposed? && @sprite.viewport.equal?(viewport)
          unless @sprite.bitmap && @sprite.bitmap.width == width && @sprite.bitmap.height == height
            @sprite.bitmap.dispose if @sprite.bitmap
            @sprite.bitmap = Bitmap.new(width, height)
            @drawn = nil
          end
          @sprite.x = viewport ? x - viewport.rect.x + viewport.ox : x
          @sprite.y = viewport ? y - viewport.rect.y + viewport.oy : y
          @sprite.z = viewport ? Z[:wheels] : Z[:open_wheel]
          @sprite.visible = true
          @opacity = fades? ? Motion.step_towards(@opacity.to_f, Component::OPAQUE.to_f, Component::OPAQUE.to_f / Style::FADE_FRAMES) : Component::OPAQUE.to_f
          @sprite.opacity = @opacity.round
          drawn = [@selected, choices, asked[1], Theme.serial, Wheel.places(choices.size)]
          return if drawn == @drawn

          @drawn = drawn
          draw_wheel(@sprite.bitmap)
        end

        # Fades it out a frame after it closed, or hides it at once once the scene it follows in left.
        #
        # @return [Boolean] Whether it still shows.
        def fade_frame
          return false if @open || @sprite.nil? || @sprite.disposed?
          return hide_now if away?

          @opacity = Motion.step_towards(@opacity.to_f, 0.0, Component::OPAQUE.to_f / Style::FADE_FRAMES)
          @sprite.opacity = @opacity.round
          return true if @opacity > 0

          hide_now
        end

        # Draws it anew on the next frame.
        #
        # @return [Wheel] Itself.
        def redraw
          @drawn = nil
          self
        end

        # Ends it quietly, as F12 does: C# forgets it is open, and Wheel.reset tells its close blocks
        # :reset once every wheel ended.
        def drop
          Mod_Framework.bridge.call(CLOSE, [@model]) if @open && @model
          closed(false)
        end

        # Moves its picture onto the screen, hidden, while the viewport it lies on is about to be
        # freed; the next frame makes it anew where it shows.
        def leave_viewport
          renew_sprite(nil)
          @sprite.visible = false
        end

        private

        # Lets go of what it holds as it closes: the buttons, to the end of the frame, its place in
        # C#'s tree and its picture, which fades out where it fades.
        #
        # @param fade [Boolean] Whether its picture may fade out rather than hide at once.
        def closed(fade)
          @open = false
          @opening = false
          Wheel.follow(self, false)
          Capture.stop(self)
          Capture.hold_to_frame_end
          @cover.close if @cover && @cover.open?
          @drawn = nil
          unless @sprite && !@sprite.disposed?
            Wheel.note_gone(self) if fade
            return
          end

          fading = fade && fades? && @sprite.visible && @opacity.to_f > 0 && !away?
          Wheel.fade_out(self, fading)
          free_sprite unless fading
          Wheel.note_gone(self) if fade && !fading
        end

        # Frees its picture at once and notes it gone.
        #
        # @return [Boolean] Always false, as it no longer shows.
        def hide_now
          free_sprite
          Wheel.note_gone(self)
          false
        end

        # Takes the choice confirm or a click took on a wheel that stays open for it: one that cannot
        # be taken buzzes and tells refuse, none closes it as cancel, any other closes it with it.
        #
        # @param selected [Integer, nil] The direction's number, CENTER for the middle, nil for none.
        def take_choice(selected)
          choice = choice_at(selected)
          if choice.nil?
            Sound.play_cancel
            return close(:cancel)
          end
          unless enabled_choice?(choice)
            UI.buzz
            return refuse(refused_choice(choice))
          end

          Mod_Framework.bridge.call(CLOSE, [@model])
          closed(true)
          emit(:submit, choice)
          emit(:close, :submit)
        end

        # Tells refuse with a choice that cannot be taken; without a refuse block its :tooltip shows
        # as a notice.
        #
        # @param choice [Object] The choice as given.
        def refuse(choice)
          return emit(:refuse, choice) if listens?(:refuse)

          tooltip = choice.is_a?(Hash) ? choice[:tooltip] : nil
          Notices.show(tooltip) unless tooltip.nil? || tooltip.to_s.empty?
        end

        # Tells the choice a refuse names: the middle's own choice for :center.
        #
        # @param choice [Object] The choice as choice_at finds it.
        # @return [Object] The choice as given.
        def refused_choice(choice)
          choice == :center ? asked[1] : choice
        end

        # Tells once that it shows.
        def tell_open
          return if @told_open

          @told_open = true
          emit(:open)
        end

        # Tells whether the scene it opened in no longer runs.
        #
        # @return [Boolean] Whether another scene runs now.
        def scene_left?
          @scene && defined?(::SceneManager) && !@scene.equal?(::SceneManager.scene) ? true : false
        end

        # Tells whether it follows a character of a scene that no longer runs, so its picture shows
        # nowhere: never on the new scene's viewport, nor on the screen.
        #
        # @return [Boolean] Whether it does.
        def away?
          @options[:follow] && scene_left? ? true : false
        end

        # Tells why its :if keeps it from showing now.
        #
        # @return [String, nil] The gate's answer as a reason, nil while it lets it show.
        def gate_reason
          Root.gate_reason_of(self, @options[:if])
        end

        # Tells whether it fades in and out.
        #
        # @return [Boolean] Whether it does.
        def fades?
          @options[:fade] && Animations.on? ? true : false
        end

        # Asks its choices and its middle, once a tick: blocks are called, a failing one logged once
        # and taken as none.
        #
        # @return [Array] The choices, eight at most, and the middle choice.
        def asked
          @asked ||= [first_choices(Array(answer_of(@options[:choices], []))), answer_of(@options[:center], nil)]
        end

        # Keeps the choices its directions hold, logging once that a block gave it more.
        #
        # @param choices [Array] The choices given.
        # @return [Array] The first eight of them.
        def first_choices(choices)
          return choices if choices.size <= DIRECTIONS.size

          mod_log("#{describe} was given #{choices.size} choices; a wheel takes up to eight choices, so it leaves out the rest") if Logging.first_time?(Tree, [:wheel_choices, describe])
          choices.first(DIRECTIONS.size)
        end

        # Reads an option that may be a block.
        #
        # @param value [Object] The option.
        # @param fallback [Object] What a failing block gives.
        # @return [Object] The value, or the block's answer.
        def answer_of(value, fallback)
          value.respond_to?(:call) ? value.call : value
        rescue => e
          mod_log("a block of #{describe} failed, so it shows none: #{Logging.failure(e)} at #{Array(e.backtrace).first}") if Logging.first_time?(Tree, [:wheel_block, e.class])
          fallback
        end

        # Tells its choices, eight at most.
        #
        # @return [Array] The choices.
        def choices
          asked[0]
        end

        # Tells whether a choice may be taken now: any but one with :disabled => true.
        #
        # @param choice [Object] The choice, or :center.
        # @return [Boolean] Whether it may.
        def enabled_choice?(choice)
          choice = asked[1] if choice == :center
          !(choice.is_a?(Hash) && choice[:disabled] == true)
        end

        # Finds the choice of a pick.
        #
        # @param selected [Integer, nil] The direction's number, CENTER for the middle, nil for none.
        # @return [Object, nil] The choice as given, :center, or nil for none.
        def choice_at(selected)
          return nil if selected.nil?
          return asked[1].nil? ? nil : :center if selected == CENTER

          index = Wheel.places(choices.size).index(DIRECTIONS[selected])
          index && choices[index]
        end

        # Tells where its middle lies on the screen: on the middle of its :follow while that shows, at
        # its :at, else in the screen's middle, moved by its :offset; kept so that its picture stays
        # on the screen.
        #
        # @return [Array<Integer>] The middle's x and y.
        def middle
          anchor = @options[:follow] && Game.anchor_of(@options[:follow])
          @followed = [anchor[:x], anchor[:y] - anchor[:height].to_i / 2] if anchor
          x, y = (@options[:follow] && @followed) || UI.point(@options[:at]) || [Graphics.width / 2, Graphics.height / 2]
          shift = UI.point(@options[:offset]) || [0, 0]
          x += shift[0]
          y += shift[1]
          width, height = picture_size
          ring = ring_size[1]
          [UI.within(x, width / 2, [Graphics.width - (width + 1) / 2, width / 2].max), UI.within(y, ring / 2, [Graphics.height - height + ring / 2, ring / 2].max)]
        end

        # Tells the viewport its picture lies on: for one that follows, the scene's top one over the
        # pictures and the weather, under every other root and the game's windows; else none, above
        # the roots it holds the buttons from.
        #
        # Never the viewport of what it follows: the map tints that one and draws its pictures and
        # weather over it.
        #
        # @return [Viewport, nil] The viewport, nil for the screen.
        def layer
          @options[:follow] ? Game.top_viewport : nil
        end

        # Makes its sprite anew on a viewport, keeping how opaque and visible it was.
        #
        # @param viewport [Viewport, nil] The viewport, nil for the screen.
        def renew_sprite(viewport)
          free_sprite if @sprite && !@sprite.disposed?
          @sprite = Sprite.new(viewport)
          ViewportSprites.add(viewport, self)
          @drawn = nil
        end

        # Frees its sprite and picture, which the next frame it shows makes anew.
        #
        # The viewport it lies on holds it until the game frees that viewport, so a closed wheel that
        # kept its sprite would keep it alive that long.
        def free_sprite
          ViewportSprites.remove(@sprite.viewport, self)
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose
          @sprite = nil
        end

        # Tells where its picture's top left corner lies on the screen.
        #
        # @return [Array<Integer>] The corner's x and y.
        def corner
          x, y = middle
          width, height = ring_size
          [x - width / 2, y - height / 2]
        end

        # Tells the size of its ring of choices, or of its boxes.
        #
        # @return [Array<Integer>] The width and height.
        def ring_size
          return [SIZE, SIZE] unless boxes?

          [BOX + 2 * (GAP + @options[:box_width].to_i), 5 * ROW + 4 * GAP]
        end

        # Tells the size of its picture: the ring or the boxes, the name and the hint.
        #
        # @return [Array<Integer>] The width and height.
        def picture_size
          width, height = ring_size
          [width, height + NAME_HEIGHT + HINT_HEIGHT]
        end

        # Tells whether it draws wide boxes.
        #
        # @return [Boolean] Whether it does.
        def boxes?
          @options[:look] == :boxes
        end

        # Lays out its wide boxes on its picture: the middle's square, and each choice's box by its
        # direction.
        #
        # @return [Array<Array>] Each box: [direction's number or CENTER, choice, left, top, width,
        #   height].
        def box_rects
          width, height = ring_size
          mid_x = width / 2
          mid_y = height / 2
          wide = @options[:box_width].to_i
          side = asked[1].nil? ? NONE_BOX : BOX
          rects = [[CENTER, asked[1], mid_x - side / 2, mid_y - side / 2, side, side]]
          places = Wheel.places(choices.size)
          choices.each_with_index do |choice, index|
            direction = places[index]
            next unless direction

            column, row = BOX_PLACES[direction]
            if column == 0
              top = row < 0 ? 0 : height - ROW
              rects << [DIRECTIONS.index(direction), choice, mid_x - wide / 2, top, wide, ROW]
            else
              left = column < 0 ? mid_x - BOX / 2 - GAP - wide : mid_x + BOX / 2 + GAP
              rects << [DIRECTIONS.index(direction), choice, left, mid_y - ROW / 2 + row * (ROW + GAP), wide, ROW]
            end
          end
          rects
        end

        # Tells C# where its wide boxes lie on the screen.
        #
        # @return [Array<Array<Integer>>, nil] Each box: [direction's number or CENTER, left, top,
        #   width, height]; nil for a ring.
        def boxes_on_screen
          return nil unless boxes?

          left, top = corner
          box_rects.map { |direction, _choice, x, y, width, height| [direction, left + x, top + y, width, height] }
        end

        # Tells whether the confirm is open or a Dialog lies above it.
        #
        # @return [Boolean] Whether one does.
        def covered?
          Confirm.open? || (@cover && @cover.open? && ButtonHotkeys.covered?(@cover, Tree.roots)) ? true : false
        end

        # Tells the radius around the middle that points at the middle choice, or at none.
        #
        # @return [Integer] The pixels.
        def inner_radius
          (asked[1].nil? ? NONE_BOX : BOX) / 2 + REACH
        end

        # Draws the ring of choices or the boxes, the middle, the name of the choice pointed at, or
        # :none_text, and the hint.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        def draw_wheel(bitmap)
          bitmap.clear
          look = palette
          boxes? ? draw_boxes(bitmap, look) : draw_ring(bitmap, look)
          width, height = ring_size
          Style.use_font(bitmap, Style::TEXT_SIZE, Style::TEXT)
          pick = selected
          name = pick.nil? ? @options[:none_text].to_s : text_of(pick == :center ? asked[1] : pick)
          bitmap.draw_text(0, height, width, NAME_HEIGHT, UI.cut(bitmap, name, width), 1)
          label = @options[:hotkey].is_a?(Symbol) ? Hotkeys.label(@options[:hotkey]) : ""
          Wheel.draw_hint(bitmap, 0, height + NAME_HEIGHT, width, *[label].reject { |each| each.empty? })
        end

        # Draws the ring of square boxes and the middle.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param look [Palette] The colors.
        def draw_ring(bitmap, look)
          places = Wheel.places(choices.size)
          choices.each_with_index do |choice, index|
            direction = places[index]
            next unless direction

            angle = Math::PI * 2 * DIRECTIONS.index(direction) / DIRECTIONS.size
            x = (SIZE / 2 + Math.sin(angle) * RADIUS - BOX / 2).round
            y = (SIZE / 2 - Math.cos(angle) * RADIUS - BOX / 2).round
            draw_choice(bitmap, choice, x, y, BOX, @selected == DIRECTIONS.index(direction), look)
          end
          center = asked[1]
          if center.nil?
            middle = (SIZE - NONE_BOX) / 2
            draw_square(bitmap, middle, middle, NONE_BOX, @selected.nil?, look)
          else
            middle = (SIZE - BOX) / 2
            draw_choice(bitmap, center, middle, middle, BOX, @selected == CENTER, look)
          end
        end

        # Draws the wide boxes and the middle.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param look [Palette] The colors.
        def draw_boxes(bitmap, look)
          box_rects.each do |direction, choice, x, y, width, height|
            picked = direction == CENTER ? (choice.nil? ? @selected.nil? : @selected == CENTER) : @selected == direction
            next draw_square(bitmap, x, y, width, picked, look) if choice.nil?
            next draw_choice(bitmap, choice, x, y, width, picked, look) if direction == CENTER

            shown = look_of(choice, look)
            draw_square(bitmap, x, y, width, picked && enabled_choice?(choice), shown, height)
            left = x + Style::PAD
            left += MARK + GAP if draw_mark(bitmap, choice, left, y + (height - MARK) / 2, MARK, shown)
            room = x + width - Style::PAD - left
            Style.use_font(bitmap, Style::SMALL_SIZE, shown.drawn_text(Style::TEXT))
            bitmap.draw_text(left, y, room, height, UI.cut(bitmap, text_of(choice), room), 0)
          end
        end

        # Draws one choice's square box: its picture or icon, else its text, lit while pointed at
        # unless it cannot be taken, then greyed out.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param choice [String, Hash] The choice: a text, or { :text, :icon, :bitmap, :disabled }.
        # @param x [Integer] The box's left.
        # @param y [Integer] Its top.
        # @param side [Integer] Its side.
        # @param picked [Boolean] Whether it is pointed at.
        # @param look [Palette] The colors.
        def draw_choice(bitmap, choice, x, y, side, picked, look)
          shown = look_of(choice, look)
          draw_square(bitmap, x, y, side, picked && enabled_choice?(choice), shown)
          return if draw_mark(bitmap, choice, x, y, side, shown)

          Style.use_font(bitmap, Style::TINY_SIZE, shown.drawn_text(Style::TEXT))
          bitmap.draw_text(x, y, side, side, UI.cut(bitmap, text_of(choice), side), 1)
        end

        # Tells the colors a choice draws in: the wheel's, greyed out while it cannot be taken.
        #
        # @param choice [Object] The choice.
        # @param look [Palette] The wheel's colors.
        # @return [Palette] The colors.
        def look_of(choice, look)
          enabled_choice?(choice) ? look : look.greyed
        end

        # Draws a choice's :bitmap, else its :icon, in the middle of a square, in the colors it draws
        # in; a picture larger than the square shrinks to it.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param choice [Object] The choice.
        # @param x [Integer] The square's left.
        # @param y [Integer] Its top.
        # @param side [Integer] Its side.
        # @param look [Palette] The choice's colors, see look_of.
        # @return [Boolean] Whether it drew one.
        def draw_mark(bitmap, choice, x, y, side, look)
          return false unless choice.is_a?(Hash)

          picture = choice[:bitmap]
          if picture && !picture.disposed?
            source, part = look.picture_source(picture, picture.rect)
            if picture.width <= side && picture.height <= side
              bitmap.blt(x + (side - picture.width) / 2, y + (side - picture.height) / 2, source, part)
            else
              bitmap.stretch_blt(Rect.new(x, y, side, side), source, part)
            end
            return true
          end
          return false unless choice[:icon]

          UI.draw_icon(bitmap, choice[:icon], x + (side - ICON_SIZE) / 2, y + (side - ICON_SIZE) / 2, ICON_SIZE, Component::OPAQUE, look)
          true
        end

        # Draws a box of the wheel in its frame, lit while pointed at.
        #
        # @param bitmap [Bitmap] The wheel's picture.
        # @param x [Integer] Its left.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param picked [Boolean] Whether it is pointed at.
        # @param look [Palette] The colors.
        # @param height [Integer] Its height, its width for a square.
        def draw_square(bitmap, x, y, width, picked, look, height = width)
          bitmap.fill_rect(x, y, width, height, picked ? look.picked : look.back)
          Style.draw_frame(bitmap, x, y, width, height, picked ? look.title : nil, look)
        end

        # Tells a choice's text.
        #
        # @param choice [String, Hash, nil] The choice.
        # @return [String] Its text, empty for none.
        def text_of(choice)
          choice.is_a?(Hash) ? choice[:text].to_s : choice.to_s
        end
      end
    end

    Run.on_start("wheels", :dll => true) do
      Engine::Tick.collect("Mod Framework wheels") { Mod_Framework::UI::Engine::Wheel.collect }
      Hooks.outermost(Graphics.singleton_class, :update, :before, "Mod Framework wheels") { Mod_Framework::UI::Engine::Wheel.draw_frame }
    end
    Run.on_reset("wheels") { Mod_Framework::UI::Engine::Wheel.reset }
    Mod_Framework.bridge.on(Engine::Wheel::EVENT) { |event| Mod_Framework::UI::Engine::Wheel.take_event(event) }
  end
end
