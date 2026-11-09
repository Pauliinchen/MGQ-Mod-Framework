#----------------------------------------------------------------
#  layer_builtins_wheel.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed a wheel's box_width:, which no mod gave
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The wheel of the UI layer: choices spread over the eight directions around the player, which
      # the arrows point at like a joystick. Like layer_builtins.rbx this file loads without the game,
      # so the tool writing docs/ui reads it too.
      module Builtins
        # The width of a wheel's wide box unless told.
        WHEEL_BOX_WIDTH = 200

        # The events of a wheel.
        WHEEL_EVENTS = ROOT_EVENTS.merge(:submit => "the choice taken, as given: one of choices:, or center: for the middle",
                                         :refuse => "the player took a choice with disabled: true, which buzzed and kept the wheel open: the choice",
                                         :close => "why it closed: :submit, :cancel, :outside, :hotkey, :scene, :script or the gate's answer",
                                         :gone => "nothing of it shows any more, once it faded out after it closed, such as for a screenshot without it")

        # Turns a wheel's params into the engine's options: its choices and its middle as given, a
        # block asked by the engine every frame; on the player and only on a free map unless told.
        #
        # @param params [Hash] The params.
        # @return [Hash] The options.
        def self.wheel(params)
          options = common(params).merge(:choices => params[:choices] || [], :center => params[:center], :look => params[:look] || :ring,
                                         :box_width => WHEEL_BOX_WIDTH, :none_text => params[:none_text].to_s,
                                         :follow => params.key?(:follow) ? params[:follow] : :player, :if => params.key?(:if) ? params[:if] : :map_free,
                                         :fade => params[:fade] != false, :hotkey => params[:hotkey])
          options[:at] = params[:at] if params[:at]
          options
        end

        # Tells the choice a wheel's submit or refuse names: the middle's choice for the engine's
        # :center, asked anew when it is a block.
        #
        # @param part [Object] The layer's part of the wheel.
        # @param choice [Object] The choice as the engine names it.
        # @return [Object] The choice as given.
        def self.wheel_choice(part, choice)
          return choice unless choice == :center

          center = part.node.params[:center]
          center.respond_to?(:call) ? center.call : center
        end

        # Makes the engine's wheel. Its hotkey only names the key in its hint here: the layer opens
        # and closes the component by its class's hotkey, while the engine's wheel would open itself
        # again.
        #
        # @param options [Hash] The engine's options.
        # @return [Wheel] The wheel.
        def self.make_wheel(options)
          wheel = Wheel.new(options.reject { |key, _value| key == :hotkey })
          wheel.hotkey = options[:hotkey]
          wheel
        end

        # Wires a wheel to the layer: its open, its close with UI.open's block getting the choice
        # taken, its submit, refuse and gone, and the hotkey its hint names, its component class's
        # declared hotkey unless told.
        #
        # Only the class's hotkey opens and closes it, since that one is attached as the mod loads;
        # a hotkey: of the markup could only be attached once the wheel first rendered.
        #
        # @param part [Object] The layer's part of the wheel.
        def self.wire_wheel(part)
          engine = part.engine
          engine.on(:open) { Layer.dispatch(part, :on_open, []) }
          engine.on(:close) { |why| Layer.root_closed(part, why) }
          engine.on(:submit) do |choice|
            taken = wheel_choice(part, choice)
            part.top.value = taken if part.top
            Layer.dispatch(part, :on_submit, [taken])
          end
          engine.on(:refuse) { |choice| Layer.dispatch(part, :on_refuse, [wheel_choice(part, choice)]) } if part.node.params[:on_refuse]
          engine.on(:gone) { Layer.root_gone(part) }
          klass = part.top && part.top.mount.component.class
          declared = klass && klass.declared_hotkey
          hotkey = part.node.params[:hotkey] || declared
          return unless hotkey

          engine.hotkey = hotkey
          return if hotkey == declared

          Errors.hint([:wheel_hotkey, klass, hotkey], nil,
                      "#{klass ? klass.name : 'a wheel'}: the wheel's hotkey: #{hotkey.inspect} only names a hotkey in its hint; " \
                      "#{declared ? "#{declared.inspect}, the hotkey its class declares, opens and closes it" : 'declare hotkey :name on its class to open and close it by a hotkey'}")
        end

        Declarations.define(:wheel,
                            :summary => "Up to eight choices spread evenly over the eight directions around the player, clockwise from the top, " \
                                        "and a middle; the arrows point at one like a joystick and confirm takes it. UI.open opens a component whose top part is one.",
                            :root => :open,
                            :params => { :choices => { :type => :wheel_choices, :default => [],
                                                       :doc => "its choices, up to eight; a lambda is asked every frame while it is open, it draws anew only when they change, and the pick stays on its direction; " \
                                                               "it shows the first eight of more a lambda answers and the log says so once" },
                                         :center => { :type => :wheel_choice,
                                                      :doc => "the middle's choice, picked as the wheel opens and by a direction without a choice; without one nothing is picked as it opens" },
                                         :look => { :values => [:ring, :boxes], :default => :ring,
                                                    :doc => ":ring draws square boxes in a ring, :boxes wide boxes with their texts in a column at each side, one above and one below" },
                                         :none_text => { :type => :text, :default => "", :doc => "what the line under it says while nothing is picked, such as \"None\"" },
                                         :follow => { :type => :character, :default => :player, :doc => "the map character it lies around, on its middle; nil for the screen's middle" },
                                         :at => { :type => :point, :doc => "an exact spot [x, y] on the screen for its middle instead of follow:" },
                                         :if => { :type => :gate, :default => :map_free,
                                                  :doc => "asked every frame; anything but true refuses the open and closes it, the answer its reason; :map_free while no event, message or transfer runs on the map" },
                                         :hotkey => { :type => :hotkey,
                                                      :doc => "the hotkey of Mod_Framework::Hotkeys its hint names, by default the one its component class declares with hotkey :name; " \
                                                              "only that declared hotkey opens and closes it, from the moment the mod loads" },
                                         :fade => { :type => :bool, :default => true, :doc => "it fades in as it opens and out as it closes" } },
                            :events => WHEEL_EVENTS,
                            :keys => "the arrows point like a joystick, two at once at the direction between them, and letting go keeps the pick; confirm takes the pick; " \
                                     "a choice with disabled: true buzzes and stays open; the game's cancel key and Numpad 0 close it; the hotkey its class declares closes it; " \
                                     "a press held from before it opened counts only once let go",
                            :pad => "the d-pad and the stick point; A takes; B closes",
                            :mouse => "pointing at a choice picks it, a click takes it, a click outside closes it",
                            :make => lambda { |options| make_wheel(options) },
                            :options => lambda { |params| wheel(params) },
                            :wire => lambda { |part| wire_wheel(part) })
      end
    end
  end
end
