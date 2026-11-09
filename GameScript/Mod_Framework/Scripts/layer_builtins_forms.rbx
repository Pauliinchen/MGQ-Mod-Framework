#----------------------------------------------------------------
#  layer_builtins_forms.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked a field's caption_width: as pixels or texts of which the widest sets it
#                            - Told that an autocomplete in a field titles its letter pages by the field's caption
#      Paulinchen  2026-11-08: Told that an autocomplete shows its placeholder while the player types too
#      Paulinchen  2026-11-07: Added autocomplete, a text field with a list of matches under it
#      Paulinchen  2026-11-06: Followed the bound number of a numeric field alone, now that the digit field is gone
#      Paulinchen  2026-11-05: Gave a group the color and the size of its title and a lower title row, its note small
#                            - Added group and field, a titled section and a captioned value
#                            - Added numeric_field, a number typed as into a text field or stepped within its bounds
#                            - Added checkbox and switch
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer a form is made of: a checkbox, a switch, a numeric field, an autocomplete, a titled
      # group, a captioned field and the form that checks its inputs as the player sends it.
      # Like layer_builtins.rbx this file loads without the game, so
      # the tool writing docs/ui reads it too.
      module Builtins
        # The param of a checkbox and a switch for the text beside its mark.
        BESIDE_LABEL = { :label => { :kind => :live, :type => :text, :doc => "its text beside its mark, as MudBlazor draws a checkbox's label" } }

        # The param of a checkbox and a switch that binds whether it is on.
        ON_BIND = { :bind => { :kind => :bind, :doc => "a state that holds whether it is on, both ways" } }

        # The event of a checkbox and a switch.
        ON_CHANGE = { :change => "whether it is on now, as the player turned it" }

        # Turns a checkbox's or a switch's params into the engine's options.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.on_off(params)
          common(params).merge(:text => params[:label].to_s, :tri_state => params[:tri_state] == true,
                               :value_texts => params[:values].nil? ? nil : Array(params[:values]).map { |text| text.to_s })
        end

        # Hands a checkbox's or a switch's change to its bound state and on_change.
        #
        # @param part [Object] The layer's part.
        def self.wire_on_off(part)
          part.engine.on(:change) { |checked| Layer.bound_changed(part, checked) }
        end

        Declarations.define(:checkbox,
                            :summary => "A box the player ticks, with its label beside it, such as a rule to turn on; with tri_state: true it may also hold neither.",
                            :args => [:label], :labelled => :beside,
                            :params => BESIDE_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds whether it is ticked, both ways: true, false, or nil for neither with tri_state:" },
                                                          :tri_state => { :type => :bool, :default => false,
                                                                          :doc => "a click goes from off to on, to neither (nil, a bar across the box) and back to off" }).merge(FORM_INPUT),
                            :events => { :change => "true or false as the player ticked it, or nil for neither with tri_state:" },
                            :keys => "confirm ticks it", :pad => "A ticks it", :mouse => "a click ticks it",
                            :make => lambda { |options| Checkbox.new(options) },
                            :options => lambda { |params| on_off(params) },
                            :wire => lambda { |part| wire_on_off(part) },
                            :synced => lambda { |part| Layer.follow_on_off(part) })

        Declarations.define(:switch,
                            :summary => "A switch the player turns on and off, with its label beside it, such as a choice between two ways; values: names the two at its right end.",
                            :args => [:label], :labelled => :beside,
                            :params => BESIDE_LABEL.merge(ON_BIND).merge(:values => { :type => :array, :doc => "the texts of off and on, such as [\"Walk\", \"Dash\"], the one that holds shown at its right end" }).merge(FORM_INPUT),
                            :events => ON_CHANGE,
                            :keys => "Left, Right and confirm turn it, as the game's option rows step a value", :pad => "the d-pad's Left and Right and A turn it",
                            :mouse => "a click turns it",
                            :make => lambda { |options| Switch.new(options) },
                            :options => lambda { |params| on_off(params) },
                            :wire => lambda { |part| wire_on_off(part) },
                            :synced => lambda { |part| Layer.follow_on_off(part) })

        Declarations.define(:numeric_field,
                            :summary => "A number the player types, as MudBlazor's numeric field, between arrows that step it within its bounds, such as how much gold to give.",
                            :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds its number, both ways" },
                                                         :min => { :type => :int, :doc => "the least number; a number typed below it becomes it, the left arrow dims there and a minus types only while it is below 0" },
                                                         :max => { :type => :int, :doc => "the largest number; a number typed past it becomes it and the right arrow dims there" },
                                                         :step => { :type => :int, :default => 1, :doc => "what a step adds or takes away" },
                                                         :arrows => { :type => :bool, :default => true, :doc => "false shows no arrows; the arrow keys and the wheel still step it" },
                                                         :adornment => { :kind => :live, :type => :text, :doc => "a text after the number, such as \"G\" or \"%\"" }).merge(FORM_INPUT),
                            :events => { :change => "its number, as the player stepped it or as typing it ended", :submit => "its number within its bounds, as Enter gave it" },
                            :keys => "Up and Right step it up, Down and Left down, buzzing at a bound; confirm starts typing: the digit row, the numpad, a minus where " \
                                     "min: allows one, Backspace, Left and Right; Ctrl+V pastes a number whole or buzzes; Up and Down step the number typed; any other key " \
                                     "buzzes; Enter keeps the number within its bounds and submits; the first cancel puts the number back. The arrows never leave it: " \
                                     "Tab walks on to the next part and Shift+Tab back, cancel goes back the way the window's cancel goes, the jump key held with an " \
                                     "arrow or a click moves on, and in a form Enter moves on to the next field or sends it from its last",
                            :pad => "the d-pad steps it; A starts typing and A again submits; the game's A held with the d-pad moves on",
                            :mouse => "a click on an arrow steps it, a click elsewhere starts typing; the wheel steps it",
                            :make => lambda { |options| NumericField.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:min => params[:min], :max => params[:max], :step => params[:step] || 1, :arrows => params[:arrows] != false,
                                                   :adornment => params[:adornment].nil? ? nil : params[:adornment].to_s)
                            end,
                            :wire => lambda do |part|
                              part.engine.on(:change) { |number| Layer.bound_changed(part, number) }
                              part.engine.on(:submit) { |number| Layer.input_submitted(part, number) }
                            end,
                            :synced => lambda { |part| Layer.follow_numeric_field(part) })

        # The height of a dense group's title row by its size.
        DENSE_TITLE_ROWS = { :tiny => 14, :small => 18, :medium => 22 }

        Declarations.define(:group,
                            :summary => "A titled section of a column, such as the fields of a form that belong together, with a note at the right of its title.",
                            :args => [:title], :content => true,
                            :params => { :title => { :kind => :live, :type => :text, :doc => "its title" },
                                         :title_color => { :type => :color, :default => :system, :doc => "its title's color" },
                                         :size => { :values => LINE_SIZES.keys, :default => :small, :doc => "the size of its title; its note is small, tiny under a tiny title" },
                                         :dense => { :type => :bool, :default => false, :doc => "its title in a lower row: 14, 18 or 22 pixels high by its size" },
                                         :note => { :kind => :live, :type => :text, :doc => "a short text at the right of its title, such as \"5 joined\"" },
                                         :note_color => { :type => :color, :default => :dim, :doc => "the note's color" },
                                         :spacing => { :values => (0..6).to_a, :default => 1, :doc => "room between its parts, 4 px a unit" } },
                            :keys => "none of its own", :mouse => "none of its own",
                            :make => lambda { |options| Group.new(options) },
                            :options => lambda do |params|
                              size = params[:size] || :small
                              common(params).merge(:title => params[:title].to_s, :title_color => color(params[:title_color] || :system), :title_size => LINE_SIZES[size],
                                                   :title_height => params[:dense] ? DENSE_TITLE_ROWS[size] : nil, :note => params[:note].nil? ? nil : params[:note].to_s,
                                                   :note_color => color(params[:note_color] || :dim), :note_size => size == :tiny ? :tiny : :small,
                                                   :gap => spacing(params[:spacing] || 1))
                            end,
                            :sync => lambda { |part, wanted| Layer.sync_group(part, wanted) })

        Declarations.define(:field,
                            :summary => "A value with its caption before it, which the player reads but does not change, such as who leads the party.",
                            :args => [:label], :content => true,
                            :params => { :label => { :kind => :live, :type => :text, :doc => "its caption, small in the theme's system color" },
                                         :caption_width => { :type => :measure, :doc => "the caption's width: pixels, or the captions that should line up, of which the widest sets it" },
                                         :plate => { :type => :bool, :default => false, :doc => "the value lies on the darker plate a text field has, so it lines up with the fields of a form" } },
                            :keys => "none of its own", :mouse => "none of its own",
                            :make => lambda { |options| Field.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:caption => params[:label].to_s, :caption_width => params[:caption_width], :plate => params[:plate] == true)
                            end,
                            :sync => lambda { |part, wanted| Layer.sync_field(part, wanted) })

        Declarations.define(:form,
                            :summary => "Inputs that are sent together: each checks its required: and validate: and shows its error under it, and the form " \
                                        "tells on_submit only once all of them are fine.", :content => true,
                            :params => { :bind_valid => { :kind => :bind, :doc => "a state the form writes whether every input in it is fine now, such as to turn a button off" },
                                         :validate_on => { :values => [:change, :submit], :default => :change,
                                                           :doc => ":change checks an input and shows its error as the player changes it; :submit only as the form is sent" },
                                         :spacing => { :values => (0..6).to_a, :default => 2, :doc => "room between its parts, 4 px a unit" } },
                            :events => { :submit => "nothing; the player sent the form and every input in it is fine" },
                            :keys => "confirm in its last input that confirms (a text field or a numeric field) sends it, as does a button with " \
                                     "on_click: :submit; confirm in another of those moves on to the next of them; an input with an error stops the sending " \
                                     "with the buzzer and takes the focus",
                            :pad => "as the keys", :mouse => "a click on a button with on_click: :submit sends it",
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(params[:spacing] || 2)) },
                            :synced => lambda { |part| Layer.follow_form(part) })

        Declarations.define(:autocomplete,
                            :summary => "A text field with a list of matches under it, as MudBlazor's autocomplete: the items that hold the text typed anywhere, ignoring case; "                                         "Up and Down light one, and confirm, Tab or a click takes it.", :args => [:label], :labelled => true,
                            :params => INPUT_LABEL.merge(:bind => { :kind => :bind, :doc => "a state that holds its text, both ways" },
                                                         :items => { :type => :completions, :required => true,
                                                                     :doc => "what it offers: an Array, narrowed to the items that hold the text anywhere, ignoring case, or a lambda of the text answering its own matches" },
                                                         :placeholder => { :kind => :live, :type => :text, :doc => "a dim text it shows while it is empty, also while the player types, such as \"Search\"" },
                                                         :max_length => { :type => :int, :doc => "the most characters it takes" }).merge(FORM_INPUT),
                            :events => { :change => "its text, as the player typed it", :select => "the match taken, which is its text now",
                                         :submit => "its text, as Enter gave it with no match lit" },
                            :keys => "typing as in a text field; Up and Down light a match, Enter or Tab takes it; the first cancel hides the matches and stops typing",
                            :pad => "A opens the game's letter pages, titled by its label: or else the caption of the field it sits in; B as cancel", :mouse => "a click puts the caret there and types; a click on a match takes it",
                            :make => lambda { |options| TextField.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:placeholder => params[:placeholder], :max_length => params[:max_length], :whole => true)
                              options[:letters_title] = params[:label].to_s unless params[:label].nil?
                              options
                            end,
                            :wire => lambda { |part| Layer.wire_autocomplete(part) },
                            :synced => lambda { |part| Layer.follow_text_field(part) })
      end
    end
  end
end
