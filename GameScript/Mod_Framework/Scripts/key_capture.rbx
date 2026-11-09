#----------------------------------------------------------------
#  key_capture.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The wait for the key the player presses to bind a hotkey, which C#'s tree runs: it holds every
      # key and the pointer, binds a free key as it is let go alone, keeps the old one on a cancel key
      # (Escape, Numpad 0 in either Num Lock state, a key F1 binds to cancel), the gamepad's cancel or
      # a click outside, and refuses a key a game button, the game, the framework or another hotkey
      # has, and a key let go with others. The part that waits hears captured (the key's code), refused
      # (the code, whose the key is: "game", "framework", "hotkey" or "chord", and the hotkey that has
      # it), kept (the cancel key's code, nil for the gamepad or a click, and "key", "pad" or "click")
      # and, once the key is let go, released. Each refusal and keep is logged.
      module KeyCapture
        # What the log says of a key's owner, by the owner C#'s tree tells.
        OWNERS = { "game" => "one of the game's keys", "framework" => "one of the framework's keys", "chord" => "pressed with another key" }

        # What the log says of the way the player kept the old key, by the way C#'s tree tells.
        KEPT_BY = { "pad" => "the gamepad's cancel", "click" => "a click outside" }

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "key capture"

        # The part that waits, nil while none does.
        @waiting = nil

        # The hotkey the part that waits binds, for the log.
        @hotkey = nil

        # Has a part wait for a key.
        #
        # @param component [Component] The part.
        # @param taken [Hash{Integer => String}] The keys other hotkeys have, each with that hotkey's
        #   name.
        # @param hotkey [Object] The hotkey it binds, such as its action or its row's key, for the log.
        def self.start(component, taken, hotkey)
          @waiting = component
          @hotkey = hotkey
          Tree.set(component, "capture" => taken)
        end

        # Logs a refusal of C#'s tree, one line per key pressed.
        #
        # @param code [Integer] Windows' code of the key.
        # @param owner [String] Whose the key is, see the module.
        # @param taker [String, nil] The hotkey that has the key, nil for any other owner.
        def self.refused(code, owner, taker)
          whose = taker ? "the hotkey #{taker}" : OWNERS[owner.to_s] || owner.to_s
          log("#{@hotkey.inspect} refused #{Options::Keys.name(code)} (key code #{code}): #{whose}")
        end

        # Logs that the player kept the old key.
        #
        # @param code [Integer, nil] Windows' code of the cancel key, nil for the gamepad or a click.
        # @param how [String] "key", "pad" or "click".
        def self.kept(code, how)
          by = code ? "#{Options::Keys.name(code)} (key code #{code}), a cancel key" : KEPT_BY[how.to_s] || how.to_s
          log("#{@hotkey.inspect} kept its key by #{by}")
        end

        # Ends the wait of a part, as its key was let go or the part goes.
        #
        # @param component [Component] The part.
        def self.finish(component)
          @waiting = nil if @waiting.equal?(component)
          Tree.set(component, "capture" => nil) if component.node
        end

        # Tells whether a part waits for a key, while every hotkey stays quiet.
        #
        # @return [Boolean] Whether one does.
        def self.waiting?
          @waiting && @waiting.node ? true : false
        end

        # Forgets the wait, as F12 starts the game anew.
        def self.reset
          @waiting = nil
        end
      end

      # A field the player presses to bind a hotkey: the hotkey's name at its start and its key at its
      # end, "Press a key . . ." while it waits for one (KeyCapture), and why a key was refused until
      # another is pressed. A key bound tells change with the key's name.
      #
      # Events: change (the key's name), click.
      class HotkeyField < Button
        # What the field reads while it waits for its key.
        WAITING_TEXT = "Press a key . . ."

        # Why a key another hotkey has is refused: the key and that hotkey's name.
        TAKEN_TEXT = "%s is the hotkey of %s"

        # Why a key the game reads itself is refused: the key.
        GAME_TEXT = "%s is one of the game's own keys"

        # Why a key the framework reads itself is refused: the key.
        FRAMEWORK_TEXT = "%s is one of the framework's own keys"

        # Why a key pressed with another is refused.
        CHORD_TEXT = "Press one key alone"

        # Tells the defaults of the options: no hotkey, its name from the hotkey.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:action => nil, :name => nil)
        end

        options :action, :name

        # Makes the field and has a press start the wait.
        #
        # @param options [Hash] Its options, see defaults.
        def initialize(options = {})
          super
          @waiting = false
          @refusal = nil
          on(:click) { start_wait }
        end

        # Tells whether it waits for its key.
        #
        # @return [Boolean] Whether it does.
        def waiting?
          @waiting
        end

        # Tells what it reads at its end: its key's name, or what it waits for.
        #
        # @return [String] The text.
        def key_text
          return @refusal || WAITING_TEXT if @waiting

          @options[:action] ? Hotkeys.label(@options[:action]) : Options::Keys::NONE
        end

        # Takes an event of C#'s tree: the wait's outcome, then its blocks.
        #
        # @param name [String] The event.
        # @param values [Array] Its values.
        def receive(name, *values)
          case name
          when "captured" then bind(values[0].to_i)
          when "refused" then refuse(values[0].to_i, values[1], values[2])
          when "kept" then keep(values[0], values[1])
          when "released" then KeyCapture.finish(self)
          end
          super
        end

        # Draws its plate, its name at its start and its key at its end.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_plate(canvas)
          row = line_height
          top = (canvas.height - row) / 2
          key = key_text
          key_width = [canvas.text_width(key, text_px) + Canvas::OUTLINE_ROOM, canvas.width / 2].min
          right = canvas.width - PAD_X
          canvas.text(right - key_width, top, key_width, row, key, :size => text_px, :align => :right, :cut => true,
                      :color => @waiting ? :system : text_color, :opacity => drawn_opacity(canvas))
          canvas.text(PAD_X, top, [right - key_width - PAD_X - Style::GAP, 1].max, row, name_text, :size => text_px, :cut => true,
                      :color => text_color, :opacity => drawn_opacity(canvas))
        end

        private

        # Tells the hotkey's name it shows: its :name, else the name its mod defined without the
        # group before it.
        #
        # @return [String] The name.
        def name_text
          (@options[:name] || Hotkeys.title(@options[:action])).to_s
        end

        # Tells the text C# measures it by: its name and its key, or what it waits for.
        #
        # @return [String] The text.
        def measured_text
          "#{name_text}  #{[key_text, WAITING_TEXT].max_by { |text| text.size }}"
        end

        # Starts the wait for its key, the keys of every other hotkey taken.
        def start_wait
          return Sound.play_buzzer unless @options[:action] && enabled_here?

          @waiting = true
          @refusal = nil
          KeyCapture.start(self, Hotkeys.taken_keys(@options[:action]), @options[:action])
          redraw
        end

        # Binds the key C#'s tree took and tells change.
        #
        # @param code [Integer] Windows' code of the key.
        def bind(code)
          Hotkeys.bind(@options[:action], code)
          end_wait
          emit(:change, Hotkeys.label(@options[:action]))
        end

        # Shows why a key was refused, until another is pressed, and logs it.
        #
        # @param code [Integer] Windows' code of the key.
        # @param owner [String] Whose the key is: "game", "framework", "hotkey" or "chord".
        # @param taker [String, nil] The hotkey that has it, nil for any other owner.
        def refuse(code, owner, taker)
          KeyCapture.refused(code, owner, taker)
          key = Options::Keys.name(code)
          @refusal = case owner
                     when "hotkey" then format(TAKEN_TEXT, key, taker)
                     when "framework" then format(FRAMEWORK_TEXT, key)
                     when "chord" then CHORD_TEXT
                     else format(GAME_TEXT, key)
                     end
          redraw
        end

        # Keeps the old key, logged, and ends the wait.
        #
        # @param code [Integer, nil] Windows' code of the cancel key, nil for the gamepad or a click.
        # @param how [String] "key", "pad" or "click".
        def keep(code, how)
          KeyCapture.kept(code, how)
          end_wait
        end

        # Ends the wait, the field showing its key again.
        def end_wait
          @waiting = false
          @refusal = nil
          relayout
        end
      end
    end

    Run.on_reset("key capture") { Mod_Framework::UI::Engine::KeyCapture.reset }
  end
end
