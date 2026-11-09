#----------------------------------------------------------------
#  animation.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Kept a width and a height a tween moves whole pixels
#      Paulinchen  2026-11-05: Moved the tweens on without making a list while none runs
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-30: Logged a missing row of the Mod Config without naming Mod Config Remake
#      Paulinchen  2026-10-29: Added a pulse of any component
#                            - Added an entrance of any component from beside its place
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The player's Animations row: On lets tweens run over their frames, Off lands each at once.
      module Animations
        # The setting that keeps whether tweens run, 1 or 0.
        SETTING = "ui_animations"

        # The Options > Mods row's key.
        OPTION = :mf_ui_animations

        # The Options > Mods row's name.
        OPTION_NAME = "Animations"

        # The Options > Mods row's help.
        OPTION_HELP = "On: the mods' windows and pages slide and fade.\n" \
                      "Off: they land where they go at once."

        # The Options > Mods row's values.
        ON = "On"
        OFF = "Off"

        # Whether tweens run; nil until read from the settings.
        @on = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "animation"

        # Tells whether tweens run over their frames.
        #
        # @return [Boolean] Whether they do; on until the player turns them off.
        def self.on?
          @on = Settings.setting(SETTING).to_s != "0" if @on.nil?
          @on
        end

        # Turns the animations on or off and keeps it in the settings.
        #
        # @param on [Boolean] Whether tweens run.
        def self.turn(on)
          @on = on
          kept = Settings.store(SETTING, on ? 1 : 0)
          log("animations are #{on ? 'on' : 'off'}#{kept ? '' : ', not kept'}")
        end

        # Offers Animations as a row of Options > Mods.
        def self.add_option
          added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, lambda { [ON, OFF] },
                               lambda { on? ? ON : OFF }, lambda { |value| turn(value == ON) })
          log("no animations row in Options > Mods, see the options lines") unless added
        end

        Run.on_start("animations", :dll => true) { Mod_Framework::UI::Engine::Animations.add_option }
      end

      # What a Tween and a group of them share: blocks on their done event, run rescued.
      module TweenEvents
        # Runs a block once it is done; at once when it is done already.
        #
        # @param name [Symbol] The event, :done.
        # @yield Runs when it is done.
        # @return [Object] Itself, so calls chain.
        def on(name, &block)
          return self unless block && name.to_sym == :done

          done? ? run_block(block) : (@done_blocks ||= []) << block
          self
        end

        private

        # Runs the done blocks, once.
        def tell_done
          blocks = @done_blocks || []
          @done_blocks = []
          blocks.each { |block| run_block(block) }
        end

        # Runs one block, a failure logged once.
        #
        # @param block [Proc] The block.
        def run_block(block)
          block.call
        rescue => e
          Tree.log_once([:tween, Array(block.source_location).join(":"), e.class], "the done block at #{Array(block.source_location).join(':')} of a tween failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end
      end

      # Moves properties of a component from where they are to new values over frames, each frame a
      # step along an easing: :offset and :opacity (which move and fade what is drawn, drawing nothing
      # anew), :size (which lays the component out anew each frame, so it costs more) and :at of a
      # root, or any property a component reads and sets itself, such as a Slides' position. A new
      # tween of a property takes it over from the one running, from where it is, so nothing jumps.
      # With Animations Off a tween lands at once and tells done in the next frame.
      #
      # Events: done.
      class Tween
        include TweenEvents

        # How a tween's steps spread over its frames: even, starting slow, ending slow, or both.
        EASINGS = [:linear, :ease_in, :ease_out, :ease_in_out]

        # The frames of a tween that names none.
        FRAMES = 12

        # The properties whose values are whole pixels or an opacity.
        WHOLE = [:offset, :opacity, :size, :at, :width, :height]

        # The tweens that wait, run or land, in the order they started.
        @tweens = []

        # Moves every tween on by a frame, telling those that landed. Called once a frame, before the
        # components lay out and draw.
        def self.update
          @tweens.dup.each { |tween| @tweens.delete(tween) unless tween.step } unless @tweens.empty?
        rescue => e
          Tree.log_once([:tweens, e.class], "moving the tweens FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Tells the tweens that wait, run or land.
        #
        # @return [Array<Tween>] The tweens.
        def self.running
          @tweens.dup
        end

        # Notes a tween that started, waiting for its turn or running.
        #
        # @param tween [Tween] The tween.
        def self.add(tween)
          @tweens << tween unless @tweens.include?(tween)
        end

        # Forgets a tween that stopped.
        #
        # @param tween [Tween] The tween.
        def self.drop(tween)
          @tweens.delete(tween)
        end

        # Groups tweens that run together: done once every one of them is.
        #
        # @param tweens [Array<Tween>] The tweens.
        # @return [TweenGroup] The group.
        def self.all(tweens)
          TweenGroup.new(tweens)
        end

        # Tells how far an easing has come at a share of a tween's frames, by cubic curves.
        #
        # @param name [Symbol] The easing, one of EASINGS.
        # @param share [Float] The share of the frames run, from 0 to 1.
        # @return [Float] How far the values have come, from 0 to 1.
        def self.ease(name, share)
          t = UI.within(share.to_f, 0.0, 1.0)
          case name
          when :linear then t
          when :ease_in then t**3
          when :ease_in_out then t < 0.5 ? 4 * t**3 : 1 - ((-2 * t + 2)**3) / 2
          else 1 - (1 - t)**3
          end
        end

        # @return [Component] The component it moves.
        attr_reader :component

        # @return [Integer] The frames it has run.
        attr_reader :frame

        # @return [Integer] The frames it runs.
        attr_reader :frames

        # Makes a tween; start runs it.
        #
        # @param component [Component] The component.
        # @param props [Hash{Symbol => Object}] The properties and where they go.
        # @param options [Hash] :frames (FRAMES), :easing (:ease_out, see EASINGS), :delay (frames to
        #   wait first), :after (a Tween or a group it waits for).
        def initialize(component, props, options = {})
          @component = component
          @targets = props.dup
          @frames = [(options[:frames] || FRAMES).to_i, 0].max
          @easing = EASINGS.include?(options[:easing]) ? options[:easing] : :ease_out
          @wait = [options[:delay].to_i, 0].max
          @after = options[:after]
          @from = {}
          @frame = 0
          @state = :new
        end

        # Runs it: at once, or once the tween it comes after is done.
        #
        # @return [Tween] Itself.
        def start
          return self unless @state == :new

          @state = :waiting
          Tween.add(self)
          begin_now unless waits?
          self
        end

        # Tells whether it still waits, runs or lands.
        #
        # @return [Boolean] Whether it does.
        def running?
          [:waiting, :running, :landing].include?(@state)
        end

        # Tells whether it landed and told done.
        #
        # @return [Boolean] Whether it did.
        def done?
          @state == :done
        end

        # Stops it where it is; done is not told.
        #
        # @return [Tween] Itself.
        def stop
          @state = :stopped if running? || @state == :new
          Tween.drop(self)
          self
        end

        # Lands it at once and tells done.
        #
        # @return [Tween] Itself.
        def finish
          return self unless running? || @state == :new

          @targets.each { |name, value| write(name, value) }
          land
        end

        # Gives up properties a newer tween of the same component takes over; with none left it stops.
        #
        # @param names [Array<Symbol>] The properties.
        def give_up(names)
          names.each do |name|
            @targets.delete(name)
            @from.delete(name)
          end
          stop if @targets.empty?
        end

        # Moves it on by a frame. Called by Tween.update.
        #
        # @return [Boolean] Whether it still runs after this frame.
        def step
          return false unless running?
          return stop && false if gone?

          case @state
          when :waiting then begin_now unless waits?
          when :landing then land
          else advance
          end
          running?
        end

        private

        # Tells whether it waits for the tween it comes after or for its delay.
        #
        # @return [Boolean] Whether it waits.
        def waits?
          return true if @after && @after.running?

          if @wait > 0 && Animations.on?
            @wait -= 1
            return true
          end
          false
        end

        # Starts moving: takes its properties over from tweens running on them and notes where they
        # are; with Animations Off or no frames they land at once.
        def begin_now
          Tween.running.each { |other| other.give_up(@targets.keys) if !other.equal?(self) && other.component.equal?(@component) && other.moving? }
          @targets.each_key { |name| @from[name] = read(name) }
          @state = :running
          return unless @frames == 0 || !Animations.on?

          @targets.each { |name, value| write(name, value) }
          @state = :landing
        end

        # Moves every property a frame along the easing; on the last frame they land and done is told.
        def advance
          @frame += 1
          progress = Tween.ease(@easing, @frame.to_f / [@frames, 1].max)
          @targets.each { |name, target| write(name, between(@from[name], target, progress, name)) }
          land if @frame >= @frames
        end

        # Ends it and tells done.
        #
        # @return [Tween] Itself.
        def land
          @state = :done
          Tween.drop(self)
          tell_done
          self
        end

        # Tells whether its component was disposed or its root closed, so it stops silently.
        #
        # @return [Boolean] Whether it was.
        def gone?
          @component.disposed? || !@component.root.open?
        end

        # Reads where a property is now: its value, or for a size or a place its laid out one.
        #
        # @param name [Symbol] The property.
        # @return [Object, nil] The value, nil when it has none yet.
        def read(name)
          rect = @component.rect
          case name
          when :size then @component.size || (rect && [rect.width, rect.height])
          when :at then @component.at || (rect && [rect.x, rect.y])
          else @component.send(name)
          end
        end

        # Sets a property.
        #
        # @param name [Symbol] The property.
        # @param value [Object] Its value.
        def write(name, value)
          @component.send("#{name}=", value)
        end

        # Tells a value between where a property started and where it goes.
        #
        # @param from [Numeric, Array, nil] Where it started, nil to go there at once.
        # @param to [Numeric, Array] Where it goes.
        # @param progress [Float] How far it has come, from 0 to 1.
        # @param name [Symbol] The property, whose values may be whole.
        # @return [Numeric, Array] The value.
        def between(from, to, progress, name)
          return to if from.nil? || to.nil?
          return from.zip(to).map { |start, stop| between(start, stop, progress, name) } if from.is_a?(Array) && to.is_a?(Array)

          value = from + (to - from) * progress
          WHOLE.include?(name) ? value.round : value
        end

        protected

        # Tells whether it moves its properties now, past its wait.
        #
        # @return [Boolean] Whether it does.
        def moving?
          [:running, :landing].include?(@state)
        end
      end

      # Tweens that run together, done once every one of them is, see Tween.all.
      #
      # Events: done.
      class TweenGroup
        include TweenEvents

        # Groups the tweens.
        #
        # @param tweens [Array<Tween>] The tweens.
        def initialize(tweens)
          @tweens = tweens.dup
          @waiting = @tweens.reject { |tween| tween.done? }
          @waiting.dup.each do |tween|
            tween.on(:done) do
              @waiting.delete(tween)
              tell_done if @waiting.empty?
            end
          end
        end

        # Tells whether every tween is done.
        #
        # @return [Boolean] Whether it is.
        def done?
          @waiting.empty?
        end

        # Tells whether any tween still waits or runs.
        #
        # @return [Boolean] Whether one does.
        def running?
          @tweens.any? { |tween| tween.running? }
        end

        # Stops every tween where it is.
        #
        # @return [TweenGroup] Itself.
        def stop
          @tweens.each { |tween| tween.stop }
          self
        end

        # Lands every tween at once.
        #
        # @return [TweenGroup] Itself.
        def finish
          @tweens.each { |tween| tween.finish }
          self
        end
      end

      # The pulse and the entrance every component plays: from see-through back to whole, once, and
      # from beside its place back to it.
      class Component
        # How opaque a pulse starts.
        PULSE_OPACITY = 96

        # The frames a pulse takes.
        PULSE_FRAMES = 12

        # How opaque an entrance starts.
        ENTER_OPACITY = 64

        # The frames an entrance takes.
        ENTER_FRAMES = 8

        # Pulses it once: it turns see-through and fades back to whole, such as a part that just
        # changed.
        #
        # @param options [Hash] :opacity (PULSE_OPACITY, where it starts) and :frames (PULSE_FRAMES).
        # @return [Tween] The tween, running.
        def pulse(options = {})
          self.opacity = options.fetch(:opacity, PULSE_OPACITY)
          animate({ :opacity => OPAQUE }, :frames => options.fetch(:frames, PULSE_FRAMES), :easing => :ease_out)
        end

        # Comes in from beside its place: it is drawn shifted and see-through and eases back to its
        # place and to whole, such as new content coming in from the side a step points to. Another
        # entrance takes over at once, so steps in a row never queue.
        #
        # @param offset [Array<Integer>] Where it starts, in pixels right and down of its place.
        # @param options [Hash] :opacity (ENTER_OPACITY, where it starts) and :frames (ENTER_FRAMES).
        # @return [Tween] The tween, running.
        def enter_from(offset, options = {})
          self.offset = offset
          self.opacity = options.fetch(:opacity, ENTER_OPACITY)
          animate({ :offset => [0, 0], :opacity => OPAQUE }, :frames => options.fetch(:frames, ENTER_FRAMES), :easing => :ease_out)
        end
      end
    end
  end
end
