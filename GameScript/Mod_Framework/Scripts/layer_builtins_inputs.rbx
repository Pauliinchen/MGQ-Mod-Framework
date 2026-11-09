#----------------------------------------------------------------
#  layer_builtins_inputs.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Gave a toggle group number_keys:, the digits that turn its items on and off
#                            - Handed the palette: of a color picker to its swatch colors
#                            - Made a read-only rating a part without an action, which C#'s tree leaves alone
#                            - Added toggle_group and toggle_item, joined buttons the player turns on
#                            - Added radio_group and radio, radios of which the player picks one
#                            - Added color_picker, swatches and sliders that pick a color
#                            - Added rating, stars the player fills from the left
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer that pick a value by sliding, stepping or pointing: the slider,
      # the rating, the color picker, the radio group and the toggle group.
      # Like layer_builtins.rbx this file loads without the game, so
      # the tool writing docs/ui reads it too.
      module Builtins
        # Hands an input's change of its value to its bound state and on_change.
        #
        # @param part [Object] The layer's part.
        def self.wire_value(part)
          part.engine.on(:change) { |value| Layer.bound_changed(part, value) }
        end

        Declarations.define(:slider,
                            :summary => "A whole number the player slides between its bounds, as MudBlazor's slider, such as the volume of the music.",
                            :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds its number, both ways" },
                                                         :min => { :type => :int, :default => 0, :doc => "the least number" },
                                                         :max => { :type => :int, :default => 100, :doc => "the largest number" },
                                                         :step => { :type => :int, :default => 1, :doc => "what a step adds or takes away; the number keeps to steps from min:" },
                                                         :show_value => { :type => :bool, :default => false, :doc => "the number shows at the right end of the track" },
                                                         :color => { :type => :color, :doc => "the color of the track up to the knob and of the knob; the theme's primary color by default" }).merge(FORM_INPUT),
                            :events => { :change => "its number, as the player slid it" },
                            :keys => "Left and Right step it, at a bound nothing; Up and Down move on", :pad => "the d-pad's Left and Right step it",
                            :mouse => "a click on the track sets the number there; a held press drags the knob",
                            :make => lambda { |options| Slider.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:min => params[:min] || 0, :max => params[:max] || 100, :step => params[:step] || 1,
                                                   :show_value => params[:show_value] == true, :color => color(params[:color]))
                            end,
                            :wire => lambda { |part| wire_value(part) },
                            :synced => lambda { |part| Layer.follow_value(part) })

        Declarations.define(:rating,
                            :summary => "Stars the player fills from the left, as MudBlazor's rating, such as how fast the player dashes; with read_only: true it only shows them.",
                            :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds how many stars are filled, both ways" },
                                                         :value => { :type => :int, :doc => "how many stars are filled, without bind:, such as on one that only shows them; it fills them anew once it changes, and the player's change stays between" },
                                                         :max_value => { :type => :int, :default => 5, :doc => "how many stars it has" },
                                                         :read_only => { :type => :bool, :default => false, :doc => "it only shows its stars: the keys pass over it and the pointer fills none" },
                                                         :size => { :type => :size, :values => ICON_SIDES.keys, :default => :medium,
                                                                    :doc => "the side of a star: :small (16 px), :medium (24 px) or :large (48 px), as an icon's, or pixels" },
                                                         :color => { :type => :color, :doc => "the color of the filled stars; the theme's primary color by default" }).merge(FORM_INPUT),
                            :events => { :change => "how many stars are filled, as the player filled them, 0 for none" },
                            :keys => "Right fills one more star and Left one less; Up and Down move on", :pad => "the d-pad's Left and Right fill one less or one more",
                            :mouse => "a click fills the stars up to the one under the pointer, and a click on the last filled star empties them; the stars up to the one under the pointer show filled while it rests there",
                            :make => lambda { |options| Rating.new(options) },
                            :options => lambda do |params|
                              read_only = params[:read_only] == true
                              options = common(params).merge(:max_value => params[:max_value] || 5, :side => ICON_SIDES[params[:size] || :medium] || params[:size],
                                                             :color => color(params[:color]), :read_only => read_only)
                              read_only ? options.merge(:acts => false) : options
                            end,
                            :wire => lambda { |part| wire_value(part) },
                            :synced => lambda { |part| Layer.follow_value(part) })

        Declarations.define(:color_picker,
                            :summary => "A color the player picks from swatches or sets by sliders of its red, green and blue, as MudBlazor's color picker, such as the color of the windows.",
                            :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds the color as \"#RRGGBB\", both ways; it may also be set to any color a color param takes" },
                                                         :palette => { :type => :array, :doc => "the colors of its swatches, each any color a color param takes; the game's 32 text colors, as \\C[n] shows them, by default" },
                                                         :sliders => { :type => :bool, :default => true, :doc => "sliders of the color's red, green and blue show under the swatches" }).merge(FORM_INPUT),
                            :events => { :change => "the color as \"#RRGGBB\", as the player picked a swatch or moved a slider" },
                            :keys => "the arrows step over the swatches and confirm picks one; Left and Right step a slider, Up and Down move on",
                            :pad => "the d-pad steps over the swatches and A picks one; Left and Right step a slider",
                            :mouse => "a click picks a swatch; a click on a slider's track or a drag of its knob sets that part of the color; resting on a swatch shows its \"#RRGGBB\"",
                            :make => lambda { |options| ColorPicker.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:sliders => params[:sliders] != false)
                              params[:palette] ? options.merge(:swatch_colors => Array(params[:palette])) : options
                            end,
                            :wire => lambda { |part| wire_value(part) },
                            :sync => lambda { |_part, _wanted| nil },
                            :synced => lambda { |part| Layer.follow_value(part) })

        Declarations.define(:radio_group,
                            :summary => "Radios of which the player picks one, as MudBlazor's radio group, such as the game's Battle Wait; each is a radio.",
                            :args => [:label], :content => true, :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds the value of the radio picked, both ways; nil for none" },
                                                         :row => { :type => :bool, :default => false, :doc => "the radios stand in a row instead of under each other" }).merge(FORM_INPUT),
                            :events => { :change => "the value of the radio the player picked" },
                            :keys => "the arrows move from radio to radio and pick the one they reach; confirm picks the radio the focus is on",
                            :pad => "the d-pad moves and picks as the arrows, A picks", :mouse => "a click picks a radio",
                            :make => lambda { |options| RadioGroup.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => params[:row] ? :row : :column, :gap => params[:row] ? spacing(3) : 2) },
                            :wire => lambda { |part| wire_value(part) },
                            :sync => lambda { |part, _wanted| Layer.sync_held_items(part, :radio, :label) },
                            :synced => lambda { |part| Layer.follow_picked(part) })

        Declarations.define(:radio,
                            :summary => "One radio of a radio_group.", :args => [:label], :inside => [:radio_group], :common => false,
                            :params => { :label => { :type => :text, :doc => "its text beside its round mark" },
                                         :value => { :doc => "what stands for it in the radio group's bound value; its label by default" },
                                         :tooltip => Declarations::COMMON[:tooltip], :disabled => Declarations::COMMON[:disabled], :key => Declarations::COMMON[:key] },
                            :make => HELD, :options => NO_OPTIONS)

        Declarations.define(:toggle_group,
                            :summary => "Buttons joined in a row that the player turns on, as MudBlazor's toggle group, such as the game's Button Explanation; each is a toggle_item.",
                            :args => [:label], :content => true, :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds the value of the item on, both ways; with multi: true the values on, an Array" },
                                                         :multi => { :type => :bool, :default => false, :doc => "any number of items may be on; false keeps one on, and a click on it keeps it on" },
                                                         :color => { :type => :color, :doc => "the fill of the items on; the theme's primary color by default" },
                                                         :number_keys => { :type => :bool, :default => false,
                                                                           :doc => "the digits 1 to 9 press the first to the ninth item, also while a field of its window types that takes no digits" }).merge(FORM_INPUT),
                            :events => { :change => "the value of the item the player turned on; with multi: true the values on now, in the items' order" },
                            :keys => "Left and Right move among the items; confirm turns one on, or with multi: true on or off; with number_keys: the digits too",
                            :pad => "the d-pad's Left and Right move, A turns one on or off", :mouse => "a click turns an item on, or with multi: true on or off",
                            :make => lambda { |options| ToggleGroup.new(options) },
                            :options => lambda { |params| common(params).merge(:multi => params[:multi] == true, :color => color(params[:color]), :number_keys => params[:number_keys] == true) },
                            :wire => lambda { |part| wire_value(part) },
                            :sync => lambda { |part, _wanted| Layer.sync_held_items(part, :toggle_item, :text) },
                            :synced => lambda { |part| Layer.follow_picked(part) })

        Declarations.define(:toggle_item,
                            :summary => "One item of a toggle_group.", :args => [:text], :inside => [:toggle_group], :common => false,
                            :params => { :text => { :type => :text, :doc => "what it says" },
                                         :icon => { :type => :icon, :doc => "an icon before its text, or alone in its middle without one" },
                                         :value => { :doc => "what stands for it in the toggle group's bound value; its text by default" },
                                         :tooltip => Declarations::COMMON[:tooltip], :disabled => Declarations::COMMON[:disabled], :key => Declarations::COMMON[:key] },
                            :make => HELD, :options => NO_OPTIONS)
      end
    end
  end
end
