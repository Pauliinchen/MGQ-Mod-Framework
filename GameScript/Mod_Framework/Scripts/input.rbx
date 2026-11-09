#----------------------------------------------------------------
#  input.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked the memory at the end of a frame
#      Paulinchen  2026-11-07: Asked C# which cancel keys leave the text field typing now
#                            - Told typing from the text box open in place of a flag of another mod
#      Paulinchen  2026-11-06: Stopped timing the frame for the probe, which is gone
#                            - Called the engine's classes by their names under UI::Engine
#                            - Added UI.pad? and UI.pad_trigger?, the kept names for what UI::Pad told mods
#                            - Added UI.in_front? and UI.room, the kept names for what UI::Tick and UI::Layout told mods
#                            - Added UI.arranging?, whether the player arranges the parts with Alt
#      Paulinchen  2026-11-05: Read the buttons and named the tick's parts without making objects
#                            - Read the buttons past the gates and sent the tick without making objects in an idle frame
#                            - Asked a key's state without making a list once the key is watched
#      Paulinchen  2026-11-04: Kept whether the player used a gamepad last, as the DLL tells it
#                            - Told the tick which of the game's extra buttons the game itself asked about in the frame before
#                            - Put the game's extra buttons A, X, Y and Z into the tick
#                            - Told whether any mod types now
#                            - Bumped the keys' serial once F1 binds other keys, and noted it read where a hint names the cancel
#                              keys, so a component of the UI layer that shows one renders it anew
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Measured the frame's tick and noted each frame shown while a probe runs
#                            - Read each of the game's buttons once a frame through Input and worked out from that
#                              whether it went down or repeats, as the game's Input does
#                            - Noted each garbage collection the game ran at the frame's end
#                            - Read the game's buttons through Input while no tick reads them
#      Paulinchen  2026-11-01: Told whether a screen held by a name holds the buttons
#                            - Told whether a box holds the buttons over the scene, leaving out a root that hosts its scene
#                            - Named the keys that leave a text field before it types
#                            - Answered and named the cancel of a field that types only digits, the focused text field's own without being told
#                            - Wrote a hint of the cancel keys that names what cancel does, such as back
#      Paulinchen  2026-10-31: Answered whether the player cancelled and named the cancel key as F1 binds it
#                            - Took the keys of F1 the DLL read for the gamepad's presses
#                            - Kept the game running behind other windows for a mod that asks, its buttons quiet there
#                            - Named the cancel keys for a key help's entry of cancel
#                            - Told whether any mod's screen holds the game
#      Paulinchen  2026-10-30: Handed the devices the engine read to the tick on JoiPlay
#                            - Told whether the left button came up in the frame
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-29: Told whether the pointer moved at the frame's tick
#                            - Let a mark be taken off before the frame ends
#                            - Told a gamepad's presses of the game's buttons apart from the keyboard's
#      Paulinchen  2026-10-28: Kept the game's buttons from the scene to the end of a frame in which a root closed
#                            - Kept a button the tree took a tick late from the scene
#                            - Put the game's L and R buttons into the tick
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The Windows functions the scripts call directly.
  module Windows
    # Loads a Windows function.
    #
    # @param library [String] The Windows library, such as "user32".
    # @param name [String] The function.
    # @param arguments [String] Its arguments, in Win32API notation.
    # @param result [String] Its result, in Win32API notation.
    # @return [Win32API] The function, loaded once.
    def self.api(library, name, arguments, result)
      @functions ||= {}
      @functions[[library, name]] ||= Win32API.new(library, name, arguments, result)
    end
  end

  # The topic that keeps the game running behind other windows, WindowTopics.KeepRunningTopic in C#.
  KEEP_RUNNING = "window.keep_running"

  # Keeps the game running while another window is in front, as an online mod does so its world
  # goes on while the player looks away, or gives the window back to the game's own rule, which
  # pauses there. The game's buttons stay quiet meanwhile. Without the DLL nothing changes, logged
  # once.
  #
  # @param on [Boolean] Whether it keeps running.
  def self.keep_running=(on)
    unless available?
      log("the game cannot keep running behind other windows without the DLL") unless @keep_running_refused
      @keep_running_refused = true
      return
    end
    return if (on ? true : false) == keep_running?

    @keep_running = bridge.call(KEEP_RUNNING, on ? true : false) == true
    log(@keep_running ? "the game keeps running behind other windows" : on ? "the game could not keep running behind other windows, see the DLL's lines" : "the game pauses behind other windows again")
  end

  # Tells whether the game keeps running while another window is in front.
  #
  # @return [Boolean] Whether it does; false without the DLL.
  def self.keep_running?
    @keep_running == true
  end

  # The framework's interface: its components, its look and its input.
  module UI
    module Engine
      # The frame's tick to the DLL's models (UiHost in C#): right after the game reads its buttons,
      # the frame's inputs go over in one call and the models' events come back in the drain that
      # follows, so the scene of the same frame reads what they answered.
      #
      # The game's windows call Input.update again within a frame as they take a press, so the tick
      # runs only at the first Input.update after each frame's end.
      module Tick
        # The topic of the frame's tick, UiHost.TickTopic in C#.
        TOPIC = "ui.tick"

        # The name the game's buttons go under in the tick, UiHost.ButtonsKey in C#.
        BUTTONS_KEY = "buttons".freeze

        # The name the game's extra buttons go under in the tick, UiHost.ExtraButtonsKey in C#.
        EXTRA_BUTTONS_KEY = "extra_buttons".freeze

        # The name of the input model in the tick, InputModel.ModelName in C#.
        INPUT_MODEL = "input".freeze

        # The name of the devices in the input model's part on JoiPlay, ScriptInput.DeviceKey in C#.
        DEVICES_KEY = "device".freeze

        # The name of the screen's size in the input model's part, which C# keeps while it is left out.
        SCREEN_KEY = "screen".freeze

        # The ticks after which the screen's size goes over again though it stayed the same.
        SCREEN_EVERY = 60

        # The topic of the input model's event, InputModel.EventTopic in C#.
        EVENT = "ui.input"

        # The key of the sounds in a model's event, UiCue.Key in C#.
        CUES_KEY = "cues"

        # The game's system sound of each cue a model names, see UiCue in C#.
        CUES = { "ok" => :play_ok, "cancel" => :play_cancel, "cursor" => :play_cursor, "buzzer" => :play_buzzer }

        # The game's buttons in the order of their bits, UiButton in C#: one group of bits for the
        # buttons that went down, one for those that went down or repeat, one for those held.
        BUTTONS = [:C, :B, :UP, :DOWN, :LEFT, :RIGHT, :L, :R]

        # The game's extra buttons in the order of their bits, UiExtraButton in C#, grouped as BUTTONS.
        EXTRA_BUTTONS = [:A, :X, :Y, :Z]

        # The inputs put for this frame's tick, by model.
        @inputs = {}

        # The tick's request and the input model's part of it, kept for every tick.
        @request = {}
        @input = {}

        # The screen's size the input model was last told, and the ticks since.
        @screen_width = nil
        @screen_height = nil
        @screen_ticks = 0

        # What runs just before the tick, each [tag, block, log].
        @collectors = []

        # The frame of Key.frame whose tick ran, nil before the first.
        @ticked = nil

        # Whether the game's window was in front at the last tick; true before the first.
        @front = true

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "input"

        # Puts a model's input for this frame's tick; a second put for the same model replaces the
        # first.
        #
        # @param model [String] The model's name, such as "layout", frozen, since a Hash copies a
        #   String key that is not.
        # @param input [Object] A plain value, as the model reads it.
        def self.put(model, input)
          @inputs[model] = input
          nil
        end

        # Runs a block once a frame just before the tick, for a model whose input is read every frame.
        #
        # @param tag [String] Who registers, for the log.
        # @param logger [#log, nil] Where a failure is logged, such as the mod's module; nil for the
        #   framework's log.
        # @yield Puts the model's input, if it needs any this frame.
        def self.collect(tag, logger = nil, &block)
          @collectors << [tag, block, logger]
          nil
        end

        # Sends the frame's tick and takes the DLL's events, once a frame. Called after every
        # Input.update; a later one in the same frame uses up the marks, as it uses up a key's press.
        def self.send_frame
          if @ticked == Key.frame
            Buttons.clear
            Capture.spend
            return
          end

          @ticked = Key.frame
          tick
        end

        # Sends the frame's tick, see send_frame.
        def self.tick
          Capture.read_buttons
          @collectors.each { |entry| collect_one(entry) }
          input = @input.clear
          Key.add_changes(input)
          add_screen(input)
          input[DEVICES_KEY] = JoiPlay.devices(!TextEdit.current.nil?) if Mod_Framework.platform == JOIPLAY
          inputs = @request.clear
          inputs[BUTTONS_KEY] = buttons
          inputs[EXTRA_BUTTONS_KEY] = extra_buttons
          inputs[INPUT_MODEL] = input
          inputs.update(@inputs) unless @inputs.empty?
          @inputs.clear
          bridge = Mod_Framework.bridge
          bridge.flush
          bridge.call(TOPIC, inputs)
          bridge.frame
        end
        private_class_method :tick

        # Puts the screen's size into the input model's part once it changed, and every SCREEN_EVERY
        # ticks, so C# has it again after the DLL started anew.
        #
        # @param input [Hash] The input model's part.
        def self.add_screen(input)
          width = Graphics.width
          height = Graphics.height
          @screen_ticks += 1
          return if width == @screen_width && height == @screen_height && @screen_ticks < SCREEN_EVERY

          @screen_width = width
          @screen_height = height
          @screen_ticks = 0
          input[SCREEN_KEY] = [width, height]
        end
        private_class_method :add_screen

        # Takes the input model's event, which a tick brings whenever the input changed, and logs when
        # another window comes to the front or the game's window comes back.
        #
        # @param event [Hash] The event, see InputModel in C#.
        def self.take(event)
          front = event["front"] != false
          log(front ? "the game's window came to the front" : "another window came to the front, the input waits") if front != @front
          @front = front
          Key.take(event["keys"] || {})
          Mouse.take(event)
          Pad.assign(event["assign"]) if event["assign"]
          Pad.used(event["pad"]) if event.key?("pad")
        end

        # Tells whether the game's window was in front at the last tick.
        #
        # @return [Boolean] Whether it was; true before the first tick and without the DLL.
        def self.in_front?
          @front
        end

        # Tells the game's buttons past the capture as the models take them, once a frame.
        #
        # @return [Integer] The bits, see BUTTONS.
        def self.buttons
          bits_of(BUTTONS)
        end

        # Tells the game's extra buttons past the capture as the models take them, once a frame, and
        # after their groups one bit per button the game itself asked about since the last tick.
        #
        # @return [Integer] The bits, see EXTRA_BUTTONS.
        def self.extra_buttons
          asked = Buttons.take_asked
          bits = bits_of(EXTRA_BUTTONS)
          place = 0
          while place < EXTRA_BUTTONS.size
            bits |= 1 << (3 * EXTRA_BUTTONS.size + place) if asked[EXTRA_BUTTONS[place]]
            place += 1
          end
          bits
        end

        # Tells some of the game's buttons past the capture: a group of bits for those that went
        # down, one for those that went down or repeat, one for those held.
        #
        # @param buttons [Array<Symbol>] The buttons in the order of their bits.
        # @return [Integer] The bits.
        def self.bits_of(buttons)
          bits = 0
          # each_with_index makes an object in the game's Ruby, a loop none.
          place = 0
          while place < buttons.size
            button = buttons[place]
            bits |= 1 << place if Capture.trigger?(button)
            bits |= 1 << (buttons.size + place) if Capture.repeat?(button)
            bits |= 1 << (2 * buttons.size + place) if Capture.press?(button)
            place += 1
          end
          bits
        end
        private_class_method :bits_of

        # Plays the sounds a model's event names.
        #
        # @param event [Hash] The event, its cues under CUES_KEY.
        def self.play(event)
          Array(event[CUES_KEY]).each do |cue|
            sound = CUES[cue]
            Sound.send(sound) if sound
          end
        end

        # Ends a frame: the keys count it, the presses of the frame end, the marks go, buttons given
        # back reach the game again, a garbage collection the game ran is noted and the memory is
        # checked. Called after every Graphics.update.
        def self.end_frame
          Collector.note_frame
          MemoryGuard.check
          Key.next_frame
          Mouse.next_frame
          Buttons.clear
          Buttons.next_frame
          Capture.next_frame
        end

        # Follows the game's frame and wraps Input, once the game runs with the DLL: the tick after
        # Input.update, the frame's end after Graphics.update and Buttons' wraps of Input.
        #
        # At the run, so the wraps go around the translation's gamepad plugin, which wraps Input as
        # it loads after the mods; the tick and the frame's end are outermost, so they follow every
        # mod's hooks of Input.update and Graphics.update, however late a mod registers them.
        def self.install
          Hooks.outermost(::Input.singleton_class, :update, :after, "Mod Framework input") { Mod_Framework::UI::Engine::Tick.send_frame }
          Buttons.install
          Hooks.outermost(Graphics.singleton_class, :update, :after, "Mod Framework frame end") { Mod_Framework::UI::Engine::Tick.end_frame }
          log("the frame's tick and Input's wraps are in place")
        end

        # Runs a collector, logging its failure in its log.
        #
        # @param entry [Array] The tag, the block and its log.
        def self.collect_one(entry)
          tag, block, logger = entry
          block.call
        rescue => e
          message = "the tick collector of #{tag} failed: #{Logging.failure(e)}"
          logger.respond_to?(:log) ? logger.log(message) : log_once([:collector, tag, e.class], message)
        end
        private_class_method :collect_one
      end

      # Keys the game's own Input does not know, as the DLL read them at the frame's tick: held, gone
      # down in this frame, or pressed since the last ask. A key counts from the tick after it is
      # first watched, so a mod watches its keys as it loads.
      module Key
        # The bit of a key's state while it is held, InputModel.KeyHeld in C#.
        HELD = 1

        # The bit of a key's state when it went down at this frame's tick, InputModel.KeyWentDown in C#.
        WENT_DOWN = 2

        # The lowest key code Windows has.
        LOWEST = 0x01

        # The highest key code Windows has.
        HIGHEST = 0xFE

        # The names of the keys watched and no longer watched in the input model's part of the tick.
        WATCH_KEY = "watch"
        UNWATCH_KEY = "unwatch"

        # Frames counted by next_frame.
        @frame = 0

        # The watched keys' codes, each true.
        @watched = {}

        # The codes watched and no longer watched since the last tick.
        @added = []
        @removed = []

        # The watched keys held or gone down at the last tick, each code with its bits.
        @states = {}

        # The frame each key was last asked about by pressed?, and whether it was held then.
        @asked = {}
        @held_when_asked = {}

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "input"

        # Tells the frames counted at each frame's end, which run on the title screen too, where the
        # game's Graphics.frame_count raises.
        #
        # @return [Integer] The frames.
        def self.frame
          @frame
        end

        # Counts a frame and ends the presses of the frame. Called after every Graphics.update.
        def self.next_frame
          @frame += 1
          @states.each_key { |code| @states[code] &= HELD }
        end

        # Has the DLL read keys at every tick from now on.
        #
        # @param codes [Array<Integer>] Windows' codes of the keys, such as 0x60 for the numpad's 0.
        def self.watch(*codes)
          codes.each do |code|
            next unless code?(code) && !@watched[code]

            @watched[code] = true
            @removed.delete(code)
            @added << code
          end
          nil
        end

        # Has the DLL stop reading keys.
        #
        # @param codes [Array<Integer>] Windows' codes of the keys.
        def self.unwatch(*codes)
          codes.each do |code|
            next unless @watched.delete(code)

            @added.delete(code)
            @removed << code
            @states.delete(code)
          end
          nil
        end

        # Puts the keys watched and no longer watched since the last tick into the tick.
        #
        # @param input [Hash] The input model's part of the tick, which takes "watch" and "unwatch"
        #   with their codes, each only when there are some.
        def self.add_changes(input)
          unless @added.empty?
            input[WATCH_KEY] = @added
            @added = []
          end
          return if @removed.empty?

          input[UNWATCH_KEY] = @removed
          @removed = []
        end

        # Takes the keys' states of the frame's tick.
        #
        # @param states [Hash] Each watched key held or gone down, with its bits.
        def self.take(states)
          @states = states
        end

        # Tells whether a key went down at this frame's tick, while the game window is in front, as
        # Input.trigger? tells the game's buttons: the same answer however often it is asked in the
        # frame.
        #
        # @param code [Integer] Windows' code of the key, watched from its first ask on.
        # @return [Boolean] Whether the key went down.
        def self.triggered?(code)
          watch(code) unless @watched[code]
          bits(code) & WENT_DOWN != 0
        end

        # Tells whether a key went down since the last ask about it, while the game window is in front.
        #
        # Only the first ask in a frame can answer true; a key asked about only while a screen is open
        # may have been let go while none was, so one held over a pause in the asking counts again.
        #
        # @param code [Integer] Windows' code of the key, watched from its first ask on.
        # @return [Boolean] Whether the key went down.
        def self.pressed?(code)
          watch(code) unless @watched[code]
          held = bits(code) & HELD != 0
          pressed = held && !(@held_when_asked[code] && @asked[code] >= @frame - 1)
          @held_when_asked[code] = held
          @asked[code] = @frame
          pressed
        end

        # Tells whether a key is held, while the game window is in front, without taking its press
        # from pressed?.
        #
        # @param code [Integer] Windows' code of the key, watched from its first ask on.
        # @return [Boolean] Whether it is held.
        def self.down?(code)
          watch(code) unless @watched[code]
          bits(code) & HELD != 0
        end

        # Reads a key's bits of the last tick.
        #
        # @param code [Integer] Windows' code of the key.
        # @return [Integer] Its bits, 0 for a key up.
        def self.bits(code)
          @states[code] || 0
        end
        private_class_method :bits

        # Tells whether a value is a key code Windows has, logging one that is not once.
        #
        # @param code [Object] The value.
        # @return [Boolean] Whether it is.
        def self.code?(code)
          return true if code.is_a?(Integer) && code >= LOWEST && code <= HIGHEST

          log_once([:bad_code, code], "#{code.inspect} is no key code, so it is not watched")
          false
        end
        private_class_method :code?
      end

      # The mouse over the game's window, as the DLL read it at the frame's tick: where it points on
      # the game's screen, its buttons with their clicks, double clicks and drags, and the wheel.
      # Every answer is the same however often it is asked in a frame, and quiet while another window
      # is in front or the player arranges the boxes with Alt.
      module Mouse
        # The bit of the tick's buttons while the left button is held, InputModel.LeftHeld in C#.
        LEFT_HELD = 1

        # The bit while the right button is held.
        RIGHT_HELD = 2

        # The bit when the left button went down at the tick.
        LEFT_PRESSED = 4

        # The bit when the right button went down at the tick.
        RIGHT_PRESSED = 8

        # The bit when the left button came up at the tick.
        LEFT_RELEASED = 16

        # The bit when the right button came up at the tick.
        RIGHT_RELEASED = 32

        # The bit while the held left button drags.
        DRAGGING = 64

        # The bits that last only the frame of their tick.
        EDGES = LEFT_PRESSED | RIGHT_PRESSED | LEFT_RELEASED | RIGHT_RELEASED

        # Where the pointer was on the game's screen at the last tick, nil for nowhere.
        @position = nil

        # Whether the pointer moved on the game's screen at the last tick.
        @moved = false

        # The buttons' bits of the last tick.
        @buttons = 0

        # Whether the left press of the last tick is a double click.
        @double = false

        # The wheel's notches of the last tick.
        @wheel = 0

        # Takes the mouse of the frame's tick.
        #
        # @param event [Hash] The input model's event.
        def self.take(event)
          position = event["mouse"]
          @moved = !position.nil? && position != @position
          @position = position
          @buttons = event["buttons"].to_i
          @double = event["double"] == true
          @wheel = event["wheel"].to_i
        end

        # Ends the presses of the frame, so a frame without a tick reports none. Called after every
        # Graphics.update.
        def self.next_frame
          @buttons &= ~EDGES
          @moved = false
          @double = false
          @wheel = 0
        end

        # Tells where the pointer is on the game's screen.
        #
        # @return [Array<Integer>, nil] x and y in the game's pixels, nil outside the window or while
        #   another window is in front.
        def self.position
          @position
        end

        # Tells whether the pointer moved on the game's screen in this frame, onto it included.
        #
        # @return [Boolean] Whether it did.
        def self.moved?
          @moved == true
        end

        # Tells whether the left button went down in this frame.
        #
        # @return [Boolean] Whether it did.
        def self.clicked?
          bit?(LEFT_PRESSED)
        end

        # Tells whether the left button came up in this frame, which ends a click.
        #
        # @return [Boolean] Whether it did.
        def self.released?
          bit?(LEFT_RELEASED)
        end

        # Tells whether the left button is held.
        #
        # @return [Boolean] Whether it is.
        def self.held?
          bit?(LEFT_HELD)
        end

        # Tells whether the right button went down in this frame.
        #
        # @return [Boolean] Whether it did.
        def self.right_clicked?
          bit?(RIGHT_PRESSED)
        end

        # Tells whether the left button went down in this frame as the second press of a double click.
        #
        # @return [Boolean] Whether it did.
        def self.double_clicked?
          @double && !arranging?
        end

        # Tells whether the held left button drags: it moved more than a few pixels since it went down.
        #
        # @return [Boolean] Whether it does.
        def self.dragging?
          bit?(DRAGGING)
        end

        # Tells how many notches the wheel turned since the last frame.
        #
        # @return [Integer] The notches, positive away from the player, negative towards.
        def self.wheel
          arranging? ? 0 : @wheel
        end

        # Tells whether the mouse moves and resizes the boxes instead of clicking, see Layout.
        #
        # @return [Boolean] Whether it does.
        def self.arranging?
          defined?(Mod_Framework::UI::Engine::Layout) && Mod_Framework::UI::Engine::Layout.arranging? ? true : false
        end

        # Tells whether a bit of the tick's buttons is set while the player does not arrange the boxes.
        #
        # @param bit [Integer] The bit.
        # @return [Boolean] Whether it is.
        def self.bit?(bit)
          @buttons & bit != 0 && !arranging?
        end
        private_class_method :bit?
      end

      # Takes the game's buttons away from the game while a root of the framework holds them, such as
      # a window drawn over the map, under which the player would walk or open the game's menu
      # otherwise.
      #
      # It also reads the game's buttons for the framework: each button once a frame, at the tick, as
      # Input reports it beneath the framework's own wrap (see Buttons.device_reader), and works out
      # from that whether it went down or repeats, so a button behaves the same on every translation
      # and on the untranslated game.
      module Capture
        # The frames a button is held before it repeats, and the frames between two repeats, as the
        # game's Input counts them.
        REPEAT_FIRST = 24
        REPEAT_EVERY = 6

        # The roots that hold the buttons, each until it gives them back, so one root closing never
        # hands the buttons to the game under another.
        @owners = []

        # The buttons read each frame: the tick's, and any other once it was asked about.
        @watched = Tick::BUTTONS + Tick::EXTRA_BUTTONS

        # The buttons held at the last read, each with the reads since it went down (0 in the frame
        # it did).
        @held = {}

        # The frame of Key.frame the buttons were last read in, nil before the first read.
        @read_in = nil

        # Whether the game read Input again in this frame, which uses up the presses of the frame.
        @spent = false

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "capture"

        # Takes the buttons for a root.
        #
        # @param owner [Object] The root, or a name such as :wheel.
        def self.start(owner)
          return if @owners.include?(owner)

          @owners.push(owner)
          log("buttons taken by #{named(owner)}, held by #{@owners.map { |each| named(each) }.join(', ')}")
        end

        # Gives the buttons back for a root. The game gets them once no other root holds them, from the
        # next frame on.
        #
        # @param owner [Object] The root.
        def self.stop(owner)
          return unless @owners.delete(owner)

          @released = true if @owners.empty?
          log("buttons given back by #{named(owner)}, #{@owners.empty? ? 'the game has them again from the next frame' : "still held by #{@owners.map { |each| named(each) }.join(', ')}"}")
        end

        # Keeps the buttons away from the game to the end of the frame, as after a root closed that
        # held none, so the press that closed it reaches no scene under it.
        def self.hold_to_frame_end
          @released = true
        end

        # Tells whether the last root gave the buttons back in this frame.
        #
        # The press that closed the root, such as the Escape that closed a window, still reads as
        # pressed until the frame ends, where a battle's wait would take it as leaving.
        #
        # @return [Boolean] Whether it did.
        def self.released?
          @released == true
        end

        # Starts a frame, in which buttons given back in the frame before reach the game again. Called
        # after every Graphics.update.
        def self.next_frame
          @released = false
        end

        # Gives every root's buttons back at once, as F12 starts the game's scenes again.
        def self.reset
          return if @owners.empty?

          log("F12 gave the buttons back from #{@owners.map { |each| named(each) }.join(', ')}")
          @owners = []
          @released = false
        end

        # Tells whether a root holds the buttons.
        #
        # @return [Boolean] Whether one does.
        def self.on?
          !@owners.empty?
        end

        # Tells whether a screen held by a name holds the buttons, such as one a mod draws without the
        # components.
        #
        # @return [Boolean] Whether one does.
        def self.held_by_name?
          place = 0
          while place < @owners.size
            return true unless @owners[place].is_a?(Component)

            place += 1
          end
          false
        end

        # Tells whether a box holds the buttons over the scene: any holder but a root that hosts its
        # scene (:hosts_scene), over which a box that waits for the buttons, such as a chat box, may
        # open as over the game's own menus.
        #
        # @return [Boolean] Whether one does.
        def self.over_scene?
          @owners.any? { |owner| !(owner.respond_to?(:hosts_scene?) && owner.hosts_scene?) }
        end

        # Tells whether the framework asks Input past the capture right now.
        #
        # @return [Boolean] Whether it does.
        def self.reading?
          @reading == true
        end

        # Tells whether a button went down, past the capture, while the game window is in front.
        #
        # @param button [Symbol] The game's button, such as :C or :UP.
        # @return [Boolean] Whether it went down.
        def self.trigger?(button)
          read(:trigger?, button)
        end

        # Tells whether a button is held, past the capture, while the game window is in front.
        #
        # @param button [Symbol] The game's button, such as :UP.
        # @return [Boolean] Whether it is held.
        def self.press?(button)
          read(:press?, button)
        end

        # Tells whether a button went down or repeats while held, past the capture, while the game
        # window is in front.
        #
        # @param button [Symbol] The game's button, such as :LEFT.
        # @return [Boolean] Whether it went down or repeats.
        def self.repeat?(button)
          read(:repeat?, button)
        end

        # Reads every watched button once through Input, as the game's buttons are at the frame's
        # tick. Called at the start of every tick.
        def self.read_buttons
          @read_in = Key.frame
          @spent = false
          unless Tick.in_front?
            @held.clear
            return
          end

          reader = Buttons.device_reader
          @watched.each do |button|
            if reader.call(button)
              count = @held[button]
              @held[button] = count ? count + 1 : 0
            else
              @held.delete(button)
            end
          end
        end

        # Uses up the presses of the frame, as the game's Input does when the game reads it again
        # within a frame: a button held stays held, but no longer went down or repeats.
        def self.spend
          @spent = true
        end

        # Answers a button past the capture, while the game window is in front: from the frame's
        # read for a watched button, through Input for one asked about the first time, which is read
        # from the next frame on, and for every button while no tick reads them, as without the DLL.
        #
        # @param method [Symbol] :press?, :trigger? or :repeat?.
        # @param button [Symbol] The game's button.
        # @return [Boolean] Whether it is held, went down or repeats.
        def self.read(method, button)
          return false unless Tick.in_front?
          return first_read(method, button) unless @read_in && @watched.include?(button)

          Buttons.past_capture(button) { held_as?(method, button) }
        end

        # Tells a watched button as the frame's read found it.
        #
        # @param method [Symbol] :press?, :trigger? or :repeat?.
        # @param button [Symbol] The game's button.
        # @return [Boolean] Whether it is held, went down or repeats.
        def self.held_as?(method, button)
          count = @held[button]
          return false if count.nil?
          return true if method == :press?
          return false if @spent || @read_in != Key.frame
          return count == 0 if method == :trigger?

          count == 0 || (count >= REPEAT_FIRST && (count - REPEAT_FIRST) % REPEAT_EVERY == 0)
        end
        private_class_method :held_as?

        # Asks Input about a button the frame does not read yet and reads it from the next frame on,
        # held from now if it is, so it does not go down again then.
        #
        # @param method [Symbol] :press?, :trigger? or :repeat?.
        # @param button [Symbol] The game's button.
        # @return [Boolean] What Input answers.
        def self.first_read(method, button)
          @watched << button unless @watched.include?(button)
          @held[button] = 0 if Buttons.raw { ::Input.press?(button) }
          @reading = true
          ::Input.send(method, button) ? true : false
        ensure
          @reading = false
        end
        private_class_method :first_read

        # Names a root for the log.
        #
        # @param owner [Object] The root.
        # @return [String] Its name.
        def self.named(owner)
          owner.is_a?(Symbol) || owner.is_a?(String) ? owner.to_s : owner.class.name.to_s
        end
        private_class_method :named
      end

      # A gamepad's presses of the game's buttons, told apart from the keyboard's: a button counts as
      # the gamepad's when it went down past the capture while none of the keyboard's keys the game
      # reads as it is held or went down. The keys are those the player bound in the game's F1
      # settings, as the DLL read them, and the game's own until it did. The keyboard's keys count
      # from the frame after the first ask, so a mod asks every frame from when it listens.
      module Pad
        # The keyboard's keys the game reads as each of its buttons by default, as Windows codes.
        KEYS = { :A => [0x10], :B => [0x1B, 0x58, 0x60, 0x2D], :C => [0x20, 0x0D, 0x5A], :X => [0x41], :Y => [0x53], :Z => [0x44],
                 :L => [0x51, 0x21], :R => [0x57, 0x22] }

        # The keys a bound button is named by, the first bound in this order: the letters as F1 lists
        # them, then Space, Enter, Shift, Escape and the numpad's 0.
        NAME_ORDER = [0x5A, 0x58, 0x43, 0x56, 0x42, 0x41, 0x53, 0x44, 0x51, 0x57, 0x20, 0x0D, 0x10, 0x1B, 0x60]

        # The names of the keys of NAME_ORDER that are not letters.
        KEY_NAMES = { 0x20 => "Space", 0x0D => "Enter", 0x10 => "Shift", 0x1B => "Esc", 0x60 => "Numpad 0" }

        # The keys of each button as F1 binds them, nil until the DLL read them.
        @assigned = nil

        # Whether the player used a gamepad last, as the DLL tells it; false until it does.
        @last = false

        # Takes the keys of F1 the DLL read, which it hands over at its first tick and once they changed.
        #
        # @param assigned [Hash{String => Array<Integer>}] Each button's name, such as "B", with its keys.
        def self.assign(assigned)
          @assigned = {}
          assigned.each { |button, codes| @assigned[button.to_sym] = Array(codes).map { |code| code.to_i } }
          Key.watch(*@assigned.values.flatten.uniq)
          Serials.bump(:keys) if defined?(Serials)
        end

        # Takes whether the player used a gamepad last, which the DLL tells at every tick in front.
        #
        # @param pad [Boolean] Whether a gamepad was used last.
        def self.used(pad)
          @last = pad == true
        end

        # Tells whether the player used a gamepad last: one of the game's buttons went down with none
        # of its keyboard keys held, and no key or mouse button went down since. A key help names the
        # pad's buttons then.
        #
        # @return [Boolean] Whether a gamepad was used last; false without the DLL.
        def self.last?
          @last
        end

        # Tells the keyboard's keys the game reads as one of its buttons.
        #
        # @param button [Symbol] The game's button, such as :B.
        # @return [Array<Integer>] Windows' codes of the keys, as F1 binds them.
        def self.keys(button)
          (@assigned && @assigned[button]) || KEYS[button] || []
        end

        # Names the key the player bound to one of the game's buttons in F1, once F1 binds other keys
        # than the game's own, whose names the game's key help gives.
        #
        # @param button [Symbol] The game's button, such as :B.
        # @return [String, nil] The key's name, such as "A"; nil while F1 binds the game's own keys.
        def self.key_name(button)
          bound = keys(button)
          return nil if bound.sort == KEYS[button].to_a.sort

          code = NAME_ORDER.find { |each| bound.include?(each) }
          code && (KEY_NAMES[code] || code.chr)
        end

        # Tells whether a gamepad's button went down in this frame, as Input.trigger? tells it.
        #
        # @param button [Symbol] The game's button: :A, :B, :C, :X, :Y, :Z, :L or :R.
        # @return [Boolean] Whether it went down on a gamepad; false for another button.
        def self.trigger?(button)
          return false unless KEYS[button]

          codes = keys(button)
          Key.watch(*codes)
          return false unless Capture.trigger?(button)

          codes.none? { |code| Key.down?(code) || Key.triggered?(code) }
        end
      end
    end

    # Windows' codes of the numpad's 0 with Num Lock on and off; with either, cancel goes down on
    # every root, whatever F1 binds it to.
    NUMPAD_ZERO = [0x60, 0x2D]

    # Windows' code of Escape, which leaves a text field whatever F1 binds it to.
    ESCAPE_KEY = 0x1B

    # The topic that tells which cancel keys leave a text field that types some characters.
    LEAVE_FIELD_TOPIC = "keys.leave_field"

    # What a field of digits types of the keys bound to the game's buttons, as a text field's takes.
    DIGITS_TAKES = "0"

    # What another mod's field of its own types, as a text field's takes: every character.
    EVERY_CHARACTER = nil

    # The cancel keys that leave a text field, by what it types and the keys asked.
    @leaving = {}

    # How the hints name the numpad's 0.
    NUMPAD_NAME = "Numpad 0"

    # How the hints name Escape while a text field types.
    ESCAPE_NAME = "Esc"

    # How the hints name the game's cancel key where the game's key help cannot be read.
    CANCEL_NAME = "X"

    # What a close hint names as what cancel does.
    CLOSE_WORD = "close"

    Engine::Key.watch(ESCAPE_KEY, *NUMPAD_ZERO)

    # Tells whether the player cancelled in this frame: the game's cancel button past the capture,
    # as F1 binds it, or the numpad's 0 with Num Lock on or off, one press counted once. While a
    # text field of any mod types: a gamepad's cancel and the cancel keys C# says leave that field,
    # so a letter bound to cancel types its letter and a field of digits types the numpad's 0.
    #
    # @param field [Symbol, nil] :digits while a field of your own that takes only digits types; a
    #   framework text field that has the focus tells it itself.
    # @return [Boolean] Whether the player did.
    def self.cancel?(field = nil)
      takes = typing_takes(field)
      return Engine::Pad.trigger?(:B) || leaving_keys(takes).any? { |code| Engine::Key.triggered?(code) } if takes != false

      game = Engine::Capture.trigger?(:B)
      numpad = NUMPAD_ZERO.map { |code| Engine::Key.triggered?(code) }.any?
      game || numpad
    end

    # Names the keys that cancel now, for a hint: the game's cancel key as F1 binds it, then the
    # numpad's 0, such as "X or Numpad 0"; "Esc or Numpad 0" while a text field types, and "Esc"
    # alone while a field of digits types, whose numpad's 0 types a 0.
    #
    # @param field [Symbol, nil] :text names the keys that leave a text field even before it types,
    #   for a hint written as the field opens; :digits while a field of your own that takes only
    #   digits types, as a framework text field that has the focus tells it itself.
    # @return [String] The keys.
    def self.cancel_keys(field = nil)
      cancel_names(field).join(" or ")
    end

    # Writes the hint that tells how to close, in one wording and order everywhere: the keys that
    # cancel, then what else closes it.
    #
    # @param also [Array<String>] What else closes it, such as a hotkey's label or "a click outside".
    # @return [String] Such as "X, Numpad 0 or a click outside: close".
    def self.close_hint(*also)
      cancel_hint(CLOSE_WORD, *also)
    end

    # Writes the hint that tells what cancel does, in the wording and order of close_hint, for a
    # part that goes back or stops instead of closing.
    #
    # @param what [String] What cancel does, such as "back".
    # @param also [Array<String>] What else does it, such as a hotkey's label.
    # @return [String] Such as "X, Numpad 0 or Ctrl: back".
    def self.cancel_hint(what, *also)
      parts = cancel_names + also.map { |part| part.to_s }
      text = parts.size > 1 ? "#{parts[0..-2].join(', ')} or #{parts[-1]}" : parts[0]
      "#{text}: #{what}"
    end

    # Names the keys that cancel now, see cancel_keys, as a key help's entry of cancel names them.
    #
    # @param field [Symbol, nil] :text for the keys that leave a text field, see cancel_keys; :digits
    #   while a field of your own that takes only digits types, as a framework text field that has
    #   the focus tells it itself.
    # @return [Array<String>] The names, the bound key named once when it is the numpad's 0.
    def self.cancel_names(field = nil)
      Engine::Serials.read(:keys) if defined?(Engine::Serials)
      takes = field == :text ? EVERY_CHARACTER : typing_takes(field)
      return leaving_keys(takes).include?(NUMPAD_ZERO[0]) ? [ESCAPE_NAME, NUMPAD_NAME] : [ESCAPE_NAME] if takes != false

      name = defined?(UI::Game) && UI::Game.respond_to?(:key_name) ? UI::Game.key_name(:B) : Engine::Pad.key_name(:B) || CANCEL_NAME
      name == NUMPAD_NAME ? [NUMPAD_NAME] : [name, NUMPAD_NAME]
    end

    # Tells what the text field typing now types, as a text field's takes names it.
    #
    # @param field [Symbol, nil] :digits for a field of your own that takes only digits.
    # @return [String, nil, false] The characters: the field's own, DIGITS_TAKES, EVERY_CHARACTER
    #   (nil) while a text box types that is no text field; false while nothing types.
    def self.typing_takes(field)
      return DIGITS_TAKES if field == :digits
      return false unless typing?

      typing = defined?(Engine::TextField) ? Engine::TextField.typing : nil
      typing ? typing.takes : EVERY_CHARACTER
    end
    private_class_method :typing_takes

    # Asks C# which cancel keys leave a text field that types some characters: Escape, the numpad's
    # 0 in either Num Lock state and the keys F1 binds to cancel, once per field and binding.
    #
    # @param takes [String, nil] What the field types, see typing_takes.
    # @return [Array<Integer>] Windows' codes of the keys; every one asked without the DLL.
    def self.leaving_keys(takes)
      codes = ([ESCAPE_KEY] + NUMPAD_ZERO + Engine::Pad.keys(:B)).uniq
      return codes unless Mod_Framework.available?

      @leaving[[takes, codes]] ||= Array(Mod_Framework.bridge.call(LEAVE_FIELD_TOPIC, [takes, codes]))
    end
    private_class_method :leaving_keys

    module Engine
      # The game's buttons as Input answers them to the game: idle while a root holds them or while a
      # gate closes them, and with the buttons the framework marks for the frame, such as C for a
      # click on a game window.
      module Buttons
        # The Input methods that report buttons, with what each reports while none is pressed.
        IDLE = { :press? => false, :trigger? => false, :repeat? => false, :dir4 => 0, :dir8 => 0 }

        # The direction buttons with the number dir4 and dir8 answer for each.
        DIRECTIONS = { :DOWN => 2, :LEFT => 4, :RIGHT => 6, :UP => 8 }

        # The buttons marked for this frame, each true.
        @marks = {}

        # The buttons kept from the game for the rest of this frame, each true.
        @swallowed = {}

        # The buttons the game asked Input about since the last tick while they reached it, each true.
        @asked = {}

        # The buttons the game asked about before the last tick, each true.
        @asked_before = {}

        # What decides whether Input passes the buttons, each [tag, block, log].
        @gates = []

        # Input.press? as it was before the framework wrapped it, and the game's own Input.press?
        # that the translation's gamepad plugin keeps as vxa_press?; each nil until install.
        @device_press = nil
        @game_press = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "input"

        # Marks a game button as pressed until the game next reads Input (Input.update) or the frame
        # ends: Input reports it gone down, repeated and held.
        #
        # @param button [Symbol] The game's button, such as :C.
        def self.press(button)
          @marks[button] = true
          nil
        end

        # Tells whether a game button is marked for this frame.
        #
        # @param button [Symbol] The game's button.
        # @return [Boolean] Whether it is.
        def self.marked?(button)
          @marks[button] == true
        end

        # Takes the mark off a game button before the frame ends, as after the one call it was meant
        # for.
        #
        # @param button [Symbol] The game's button.
        def self.release(button)
          @marks.delete(button)
          nil
        end

        # Drops the marks. Called after every Graphics.update, after every Input.update but the
        # frame's first, and at F12.
        def self.clear
          @marks.clear unless @marks.empty?
        end

        # Keeps a game button from the game for the rest of the frame: Input reports it neither gone
        # down, repeated nor held, as for the late press of a key the tree took a tick earlier.
        #
        # @param button [Symbol] The game's button, such as :B.
        def self.swallow(button)
          @swallowed[button] = true
          nil
        end

        # Hands over the buttons the game asked about since the last tick, which asked? tells from
        # then on until the next tick. Called at every tick.
        #
        # @return [Hash{Symbol => true}] The buttons.
        def self.take_asked
          before = @asked
          @asked = @asked_before
          @asked_before = before
          @asked.clear
          before
        end

        # Tells whether the game itself asked Input about a button before the last tick, so a screen of
        # the game uses it now.
        #
        # @param button [Symbol] The game's button, such as :Z.
        # @return [Boolean] Whether it did.
        def self.asked?(button)
          @asked_before[button] == true
        end

        # Gives the buttons kept from the game back. Called after every Graphics.update.
        def self.next_frame
          @swallowed.clear unless @swallowed.empty?
        end

        # Adds a gate: while its block answers false, Input reports no button to the game, as the
        # framework keeps the buttons away while the game runs behind another window.
        #
        # @param tag [String] Who registers, for the log.
        # @param logger [#log, nil] Where a failure is logged, such as the mod's module; nil for the
        #   framework's log.
        # @yieldreturn [Boolean] Whether Input passes the buttons.
        def self.gate(tag, logger = nil, &block)
          @gates << [tag, block, logger]
          nil
        end

        # Tells whether Input passes the buttons to whoever asks now: no root gave them back in this
        # frame, none holds them unless the framework reads past the capture, and every gate is open.
        #
        # @return [Boolean] Whether it does.
        def self.passes?
          return false if Capture.released?
          return false if Capture.on? && !Capture.reading?

          gates_open?
        end

        # Runs a block with Input answering as the device does, without the capture, the gates or
        # the marks, as Capture reads the buttons once a frame.
        #
        # @yield Reads Input.
        # @return [Object] What the block answers.
        def self.raw
          @raw = true
          yield
        ensure
          @raw = false
        end

        # Tells what reads a button as the device reports it, without the capture, the gates or the
        # marks: the game's own Input.press? while the translation's gamepad plugin has no gamepad
        # plugged in, where the plugin answers just as it does, else Input.press? beneath the
        # framework's wrap.
        #
        # The plugin's reads cost the game far more than its own Input, in time and in objects.
        #
        # @return [Method] Takes the button and answers whether it is held.
        def self.device_reader
          return @game_press if @game_press && !::WolfPad.plugged_in?

          @device_press || ::Input.method(:press?)
        end

        # Answers a button for the framework past the capture as answer answers it while the
        # framework reads: nothing once a root gave the buttons back in this frame, for a button kept
        # from the game, or while a gate closes, else what the block says or the button's mark.
        #
        # @param button [Symbol] The game's button.
        # @yieldreturn [Boolean] Whether the button is held, went down or repeats.
        # @return [Boolean] The answer.
        def self.past_capture(button)
          return false if Capture.released? || @swallowed[button]
          return false unless gates_open?

          yield || marked?(button)
        end

        # Tells whether every gate lets the buttons pass, without the objects an Enumerable method
        # makes in the game's Ruby on each of the many reads a frame.
        #
        # @return [Boolean] Whether they do.
        def self.gates_open?
          place = 0
          while place < @gates.size
            return false unless open?(@gates[place])

            place += 1
          end
          true
        end
        private_class_method :gates_open?

        # Answers an Input method as the game gets it, see IDLE.
        #
        # @param method [Symbol] The method.
        # @param args [Array] Its arguments.
        # @param original [Proc] Runs the method.
        # @return [Boolean, Integer] Its answer, idle while the buttons do not pass, and with the marks;
        #   a button asked about while they pass is noted as one the game uses.
        def self.answer(method, args, original)
          return original.call if @raw
          return IDLE[method] unless passes?

          @asked[args[0]] = true if IDLE[method] == false && !Capture.reading?
          return IDLE[method] if IDLE[method] == false && @swallowed[args[0]]

          value = original.call
          return value || marked?(args[0]) if IDLE[method] == false
          return value unless value == 0

          marked = DIRECTIONS.keys.find { |button| marked?(button) }
          marked ? DIRECTIONS[marked] : value
        end

        # Wraps the Input methods of IDLE in answer, once the game runs.
        def self.install
          @device_press = ::Input.method(:press?)
          @game_press = ::Input.method(:vxa_press?) if defined?(::WolfPad) && ::WolfPad.respond_to?(:plugged_in?) && ::Input.respond_to?(:vxa_press?)
          input = ::Input.singleton_class
          IDLE.each_key do |method|
            Hooks.around(input, method, "Mod Framework buttons") { |_input, args, original| Mod_Framework::UI::Engine::Buttons.answer(method, args, original) }
          end
        end

        # Asks a gate, taking one that fails as open, logged once.
        #
        # @param entry [Array] The tag, the block and its log.
        # @return [Boolean] Whether it is open.
        def self.open?(entry)
          tag, block, logger = entry
          block.call ? true : false
        rescue => e
          if Logging.first_time?(self, [:gate, tag, e.class])
            message = "the button gate of #{tag} failed, so it lets the buttons pass: #{Logging.failure(e)}"
            logger.respond_to?(:log) ? logger.log(message) : log(message)
          end
          true
        end
        private_class_method :open?
      end
    end

    # While the game runs behind another window for a mod, the game's buttons stay quiet there, so
    # a gamepad played in another program does not steer this game.
    Engine::Buttons.gate("Mod Framework keep running") { !Mod_Framework.keep_running? || Mod_Framework::UI::Engine::Tick.in_front? }

    # Tells whether any mod's screen holds the game now: a root that holds the game's buttons (a
    # capturing window, a dialog, a wheel, the question box) or a text field typing.
    #
    # @return [Boolean] Whether one does.
    def self.busy?
      Engine::Capture.on? || typing?
    end

    # Tells whether any mod types now into a text field, while which every mod's hotkeys stay quiet.
    #
    # @return [Boolean] Whether one does.
    def self.typing?
      defined?(Engine::TextEdit) && Engine::TextEdit.current ? true : false
    end

    # Tells whether the player arranges the parts now: the left Alt is held or a part is dragged, so
    # the mouse moves and resizes them instead of clicking, such as for a HUD of a mod that shows
    # its outline only then.
    #
    # @return [Boolean] Whether the player does.
    def self.arranging?
      Engine::Layout.arranging?
    end

    # Tells whether the game's window is in front, so a mod that keeps the game running behind
    # other windows can leave out what only a player at the game needs.
    #
    # @return [Boolean] Whether it was at the last tick; true before the first tick and without the
    #   DLL.
    def self.in_front?
      Engine::Tick.in_front? ? true : false
    end

    # Tells whether the player used a gamepad last, so a hint of your own names the pad's buttons
    # instead of the keyboard's keys.
    #
    # @return [Boolean] Whether a gamepad was used last; false before the first tick and without
    #   the DLL.
    def self.pad?
      Engine::Pad.last? ? true : false
    end

    # Tells whether one of the game's buttons went down on a gamepad in this frame, so the pad's
    # shoulders can do what the keyboard's Q and W do not.
    #
    # The keyboard's keys count from the frame after the first ask, so ask every frame from when
    # your screen listens.
    #
    # @param button [Symbol] The game's button: :A, :B, :C, :X, :Y, :Z, :L or :R.
    # @return [Boolean] Whether it went down on a gamepad; false for another button.
    def self.pad_trigger?(button)
      Engine::Pad.trigger?(button)
    end

    # Tells the pixels the shown, unmoved parts of a zone take from the zone's edge, for a game
    # window of a mod that keeps clear of them.
    #
    # @param zone [Symbol] One of the nine zones, such as :top_left.
    # @return [Integer] The pixels, 0 while none shows there.
    def self.room(zone)
      Engine::Layout.room(zone)
    end

    # Once the game runs with the DLL, the frame's tick follows Input.update and Input is wrapped.
    Run.on_start("input", :dll => true) { Mod_Framework::UI::Engine::Tick.install }

    # F12 gives every root's buttons back and drops the marks.
    Run.on_reset("input") do
      Mod_Framework::UI::Engine::Capture.reset
      Mod_Framework::UI::Engine::Buttons.clear
      Mod_Framework::UI::Engine::Buttons.next_frame
    end

    Mod_Framework.bridge.on(Engine::Tick::EVENT) { |event| Mod_Framework::UI::Engine::Tick.take(event) }
  end
end
