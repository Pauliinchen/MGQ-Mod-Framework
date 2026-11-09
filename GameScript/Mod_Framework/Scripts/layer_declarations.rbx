#----------------------------------------------------------------
#  layer_declarations.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Added padding_shrinks: to the params every built-in takes
#                            - Let a declaration need one of several params, and added the param type of a face of a face file
#                            - Added the param type of frames, one number or [in, out]
#                            - Added the param type of a width given as pixels or as texts of which the widest sets it
#                            - Let button_help: take nil for a button the key help leaves out
#                            - Added margin:, padding:, border:, border_width: and background: to the params every built-in takes
#                            - Checked room in units of 4 px for every side or as [vertical, horizontal] or [top, right, bottom, left]
#                            - Checked a background: a color, :theme, false, or { color:, fade: [side, pixels] }
#      Paulinchen  2026-11-07: Added contrast: to the params every built-in takes and left outline: a color only
#                            - Added outline: to the params every built-in takes, :auto or a color
#                            - Added compact_for: to the params every built-in takes, its copies checked against the part's params
#                            - Added compact: to the params every built-in takes, its forms checked against the part's params
#                            - Hinted the nearest key for a misspelled key of a context menu choice
#                            - Removed cancel_to:, since cancel walks back to the part that handed a list the focus
#      Paulinchen  2026-11-06: Removed the old color names and the old values a message named
#                            - Removed REFERENCE.md and the calls it told of, which the pages of docs/ui replace
#                            - Wrote the calls of the UI layer that are no built-ins into the reference after the built-ins
#                            - Checked a text or an Array of ever shorter texts
#                            - Told a lambda on a component's own param how to give live data instead
#                            - Added on_focus and on_blur to the params every built-in takes
#                            - Added cancel_to: to the params every built-in takes
#      Paulinchen  2026-11-05: Checked a cover, true, false, a game window or its class name
#                            - Checked a game window that shows a text, such as the scene's help window
#                            - Checked a game text color by its number as a color
#                            - Checked the items of a menu, each a text or { text:, enabled:, tooltip:, data:, items: }, also a lambda
#                            - Added pulse: to the params every built-in takes
#                            - Checked the choices of a wheel and its middle, each also a lambda
#                            - Checked a spot on the map, a character or a tile [x, y]
#                            - Checked a hiding, a lambda, true, false or :top_message, and a map character to follow
#                            - Wrote the calls a built-in's handle offers into its table
#                            - Left a param only the framework's own screens give out of the reference
#                            - Checked completions:, an Array of words or a lambda of the word typed
#      Paulinchen  2026-11-04: Left the parts the framework makes for itself out of the names a component may not take
#                            - Took a text as one line of text in a content param that allows it
#                            - Checked a count, a whole number or one of its names, such as the lines a text keeps
#                            - Checked an icon: an IconSet index, a name UI.icon gave one, or a picture file
#                            - Wrote the table of a built-in for its page of docs/ui
#                            - Took every palette role and the color names mods add as colors, and named the new name of
#                              an old one
#                            - Added theme: to the params every built-in takes, :game or a preset's name
#                            - Checked a spot [x, y] and a selector, and named the new name of a value that was renamed
#                            - Added context_menu: to the params every built-in takes, with its choices checked
#                            - Checked the game's extra buttons of on_button: and button_help:
#                            - Took nil on a handler param as no handler
#                            - Added autofocus: to the params every built-in takes
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What a markup call or a component's params got wrong, raised at the call with the file and
      # line of the mod's code.
      class MarkupError < ArgumentError
      end

      # The declarations of the new UI layer's built-in components: each one's params with their
      # allowed values, its events, its keys and its places. They make the markup methods, check
      # every markup call and write the tables of the pages in docs/ui.
      #
      # This file loads without the game, so the tool writing docs/ui can read it alone.
      module Declarations
        # The palette roles a color param takes, as the theme names them; mods add more (UI.color).
        COLORS = [:primary, :secondary, :tertiary, :info, :success, :warning, :error, :default,
                  :text, :text_dark, :text_light, :dim, :gold, :own, :ally, :system,
                  :back, :plate, :picked, :field, :heading, :edge, :track, :rim, :title, :well, :tab]


        # The most edits between a wrong name and the name it is taken for.
        NEAR = 2

        # What a choice of a context menu takes.
        CHOICE_KEYS = [:text, :on_click, :disabled, :tooltip]

        # The game's extra buttons a screen may take with on_button:.
        BUTTONS = [:a, :x, :y, :z]

        # The most choices a wheel takes, one in each of its eight directions.
        MOST_WHEEL_CHOICES = 8

        # The sides a background fades toward.
        FADE_SIDES = [:left, :right, :top, :bottom]

        # What a background's Hash takes.
        BACKGROUND_KEYS = [:color, :fade]

        # What the refusal of a lambda on a component's own param adds: how to give live data.
        OWN_LAMBDA = "; a component's own param takes a plain value, so give it what the value comes from, such as actor:, " \
                     "and read the value in its render through UI::Game or a live param of a built-in, or watch it".freeze

        # One param of a component: its name, kind, allowed values, default and a line about it.
        #
        # Kinds: :value (a plain value), :live (a plain value or a lambda without arguments read while
        # it shows), :handler (a lambda or a method name), :content (markup as a lambda without
        # arguments; with :type => :text a text too, which stands for one line of text), :item (a
        # lambda of one item, or the item's method name), :bind (the name of a state of the component
        # that renders it).
        class Param
          # @return [Symbol] Its name.
          attr_reader :name

          # @return [Symbol] Its kind, see the class.
          attr_reader :kind

          # @return [Symbol] What a plain value must be: :any, :bool, :int, :count, :text, :color, :id,
          #   :symbols, :scenes, :pair, :point, :selector, :target, :size, :array, :completions, :gate,
          #   :while, :character, :map_spot, :hotkey, :buttons, :button_texts, :choices, :wheel_choices,
          #   :wheel_choice, :menu_items, :theme, :icon, :texts, :forms, :copies, :sides, :background or :enum.
          attr_reader :type

          # @return [Array, nil] The allowed values of an :enum, or the names a :size, a :count or a :color takes.
          attr_reader :values

          # @return [Object] Its default, nil for none.
          attr_reader :default

          # @return [String] A line about it for a page of docs/ui.
          attr_reader :doc

          # Makes a param.
          #
          # @param name [Symbol] Its name.
          # @param spec [Hash] :kind (:value), :type (:any), :values, :default, :required, :doc,
          #   :hidden (only the framework's own screens give it, so docs/ui leaves it out), :own (a
          #   param a component class declares, whose refusal of a lambda tells how to give live data).
          def initialize(name, spec)
            @name = name
            @kind = spec[:kind] || :value
            @type = spec[:type] || (spec[:values] ? :enum : :any)
            @values = spec[:values]
            @default = spec[:default]
            @required = spec[:required] ? true : false
            @hidden = spec[:hidden] ? true : false
            @own = spec[:own] ? true : false
            @doc = spec[:doc].to_s
          end

          # Tells whether only the framework's own screens give it, so docs/ui leaves it out.
          #
          # @return [Boolean] Whether they do.
          def hidden?
            @hidden
          end

          # Tells whether a caller must give it.
          #
          # @return [Boolean] Whether it must.
          def required?
            @required
          end

          # Tells whether it takes a lambda read while the part shows.
          #
          # @return [Boolean] Whether it does.
          def live?
            @kind == :live
          end

          # Checks a value given for it.
          #
          # @param owner [String] The component's markup name, for the message.
          # @param value [Object] The value.
          # @raise [MarkupError] The value does not fit.
          def check(owner, value)
            case @kind
            when :handler
              return if value.nil? || value.is_a?(Proc) || value.is_a?(Symbol)

              fail_with("#{@name}: takes a lambda, a method name or nil, not #{Declarations.show(value)}")
            when :content
              return if value.nil? || (value.is_a?(Proc) && value.arity <= 0) || (@type == :text && value.is_a?(String))

              fail_with("#{@name}: takes markup as a lambda without arguments, such as -> { text \"Hi\" }#{@type == :text ? ', or a text' : ''}")
            when :item
              return if value.is_a?(Symbol) || (value.is_a?(Proc) && value.arity != 0)

              fail_with("#{@name}: takes a lambda of one item or the item's method name, not #{Declarations.show(value)}")
            when :bind
              return if value.is_a?(Symbol)

              fail_with("#{@name}: takes the name of a state, such as :picked, not #{Declarations.show(value)}")
            else
              if value.is_a?(Proc)
                return if (live? || [:gate, :choices, :while, :wheel_choices, :wheel_choice, :menu_items].include?(@type)) && value.arity <= 0
                return if @type == :completions && value.arity == 1

                fail_with(@type == :completions ? "#{@name}: takes a lambda of the word typed, such as ->(word) { ... }" :
                          (live? ? "#{@name}: takes a lambda without arguments" : "#{@name}: takes no lambda#{@own ? OWN_LAMBDA : ''}"))
              end
              check_type(owner, value)
            end
          end

          # Describes what it takes, for a page of docs/ui.
          #
          # @return [String] Such as "`:filled`, `:outlined`, `:text`".
          def takes
            return @type == :text ? "markup as a lambda, or a text for one line" : "markup as a lambda" if @kind == :content

            case @type
            when :enum then @values.map { |each| "`#{each.inspect}`" }.join(", ")
            when :size then (["px"] + Array(@values).map { |each| "`#{each.inspect}`" }).join(", ")
            when :count then (["a whole number"] + Array(@values).map { |each| "`#{each.inspect}`" }).join(", ")
            when :bool then "true, false"
            when :int then "a whole number"
            when :text then "a text"
            when :texts then "a text, or an Array of ever shorter texts"
            when :measure then "pixels, or an Array of texts of which the widest sets it"
            when :frames then "a whole number of frames, or [in, out]"
            when :face_file then "[file, index]: a face file of Graphics/Faces and the face's place in it, from 0"
            when :color then (Array(@values).map { |each| "`#{each.inspect}`" } + ["a color name such as :primary or :rainbow, \"#RRGGBB\", [r, g, b] or a game text color such as 2"]).join(", ")
            when :theme then ":game, or a preset's name such as \"Legacy\""
            when :icon then "an IconSet index, a name UI.icon gave one, or { file: \"Graphics/Pictures/x\" }"
            when :id then "a Symbol or a text"
            when :symbols then "a Symbol or an Array of Symbols"
            when :scenes then "scene classes or patterns of their names"
            when :pair then "[width, height]"
            when :point then "[x, y]"
            when :selector then "a selector, such as \"#gear_compare_score\", or a game window's class name, such as \"Window_Gold\""
            when :target then "a selector, such as \"#slots\", or :pointer"
            when :array then "an Array"
            when :completions then "an Array of words, or a lambda of the word typed answering them"
            when :gate then "a lambda answering true or why not, or :map_free"
            when :while then "a lambda answering true while it hides, true, false, or :top_message"
            when :character then ":player, a map character such as an event, a sprite, or an event's id on this map"
            when :map_spot then ":player, a map character such as an event, a sprite, an event's id on this map, or a tile [x, y]"
            when :hotkey then "the name of a hotkey of Mod_Framework::Hotkeys"
            when :cover then "true, false, a game window, or its class name such as \"Window_Config\""
            when :text_window then "a game window that shows a text with set_text, such as the scene's help window"
            when :choices then "an Array of choices, each a text or { text:, on_click:, disabled:, tooltip: }, or a lambda without arguments answering them"
            when :wheel_choices then "an Array of up to eight choices, each a text or { text:, icon:, bitmap:, disabled:, tooltip:, data: }, or a lambda without arguments answering them"
            when :wheel_choice then "a choice, a text or { text:, icon:, bitmap:, disabled:, tooltip:, data: }, or a lambda without arguments answering one"
            when :menu_items then "an Array of items, each a text or { text:, disabled:, tooltip:, data:, items: }, items: making a menu of its own, or a lambda without arguments answering them"
            when :buttons then "{ z: -> { ... } }: a lambda or a method name, or nil, for each of the game's buttons :a, :x, :y and :z it takes"
            when :button_texts then "{ z: \"Filter\" }: what each button of on_button: does, for the key help"
            when :forms then "{ 1 => { dense: true } }: the params of each compact form by the step it comes in at, from 1"
            when :copies then "[{ picked: item }]: the params of each copy"
            when :sides then "units of 4 px, also half units such as 0.5, for every side, or as [vertical, horizontal] or [top, right, bottom, left]"
            when :background then "a color name such as :primary, \"#RRGGBB\", [r, g, b] or see-through [r, g, b, a], or a game text color such as 2; `:theme`, `false`, or { color:, fade: [side, pixels] }"
            else
              { :handler => "a lambda, a method name or nil", :item => "a lambda of one item, or its method name",
                :bind => "the name of a state" }[@kind] || "any value"
            end
          end

          private

          # Checks a plain value against the param's type.
          #
          # @param owner [String] The component's markup name.
          # @param value [Object] The value.
          # @raise [MarkupError] The value does not fit.
          def check_type(owner, value)
            return if value.nil? && !@required

            case @type
            when :enum
              return if @values.include?(value)

              near = Declarations.nearest(value, @values)
              fail_with("#{@name}: #{Declarations.show(value)} is not one of #{@values.map { |each| each.inspect }.join(', ')}#{near ? "; did you mean #{near.inspect}?" : ''}")
            when :color
              return if Declarations.color?(value) || Array(@values).include?(value)

              names = Declarations.color_names
              near = value.is_a?(Symbol) ? Declarations.nearest(value, names) : nil
              fail_with("#{@name}: #{Declarations.show(value)} is no color name#{near ? "; did you mean #{near.inspect}?" : '.'} Names: #{names.map { |each| each.inspect }.join(', ')}")
            when :theme
              check_theme(value)
            when :icon
              check_icon(value)
            when :bool
              fail_with("#{@name}: takes true or false, not #{Declarations.show(value)}") unless value == true || value == false
            when :int
              fail_with("#{@name}: takes a whole number, not #{Declarations.show(value)}") unless value.is_a?(Integer)
            when :text
              fail_with("#{@name}: takes a text, not #{Declarations.show(value)}") unless value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Symbol)
            when :texts
              texts = value.is_a?(Array) ? value : [value]
              fits = !texts.empty? && texts.all? { |each| each.is_a?(String) || each.is_a?(Numeric) || each.is_a?(Symbol) }
              fail_with("#{@name}: takes a text or an Array of ever shorter texts, not #{Declarations.show(value)}") unless fits
            when :measure
              texts = value.is_a?(Array) && !value.empty? && value.all? { |each| each.is_a?(String) || each.is_a?(Numeric) || each.is_a?(Symbol) }
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless texts || (value.is_a?(Integer) && value >= 0)
            when :frames
              frames = value.is_a?(Array) && value.size == 2 ? value : [value]
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless frames.all? { |each| each.is_a?(Integer) && each > 0 }
            when :face_file
              fits = value.is_a?(Array) && value.size == 2 && value[0].is_a?(String) && value[1].is_a?(Integer) && value[1] >= 0
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless fits
            when :id
              fail_with("#{@name}: takes a Symbol or a text, not #{Declarations.show(value)}") unless value.is_a?(Symbol) || value.is_a?(String)
            when :symbols
              fail_with("#{@name}: takes a Symbol or an Array of Symbols") unless Array(value).all? { |each| each.is_a?(Symbol) }
            when :scenes
              fail_with("#{@name}: takes scene classes or patterns of their names") unless Array(value).all? { |each| each.is_a?(Module) || each.is_a?(Regexp) }
            when :pair
              fail_with("#{@name}: takes [width, height], not #{Declarations.show(value)}") unless value.is_a?(Array) && value.size == 2
            when :point
              fail_with("#{@name}: takes [x, y], not #{Declarations.show(value)}") unless value.is_a?(Array) && value.size == 2 && value.all? { |each| each.is_a?(Integer) }
            when :selector, :target
              fits = value.is_a?(String) || (@type == :target && value == :pointer)
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless fits
            when :size, :count
              return if (value.is_a?(Integer) && value >= 0) || Array(@values).include?(value)

              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}")
            when :array
              fail_with("#{@name}: takes an Array, not #{Declarations.show(value)}") unless value.is_a?(Array)
            when :completions
              fail_with("#{@name}: takes an Array of words or a lambda of the word typed, not #{Declarations.show(value)}") unless value.is_a?(Array)
            when :gate
              fail_with("#{@name}: takes a lambda or :map_free, not #{Declarations.show(value)}") unless value == :map_free
            when :while
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless [true, false, :top_message].include?(value)
            when :character
              check_character(value)
            when :map_spot
              check_character(value) unless value.is_a?(Array) && value.size == 2 && value.all? { |each| each.is_a?(Integer) }
            when :hotkey
              check_hotkey(value)
            when :cover
              fits = value == true || value == false || (value.is_a?(String) && value =~ /\AWindow_\w+\z/) || (value.respond_to?(:width) && value.respond_to?(:visible=))
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless fits
            when :text_window
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless value.respond_to?(:set_text)
            when :buttons, :button_texts
              check_buttons(value)
            when :forms
              fits = value.is_a?(Hash) && !value.empty? && value.all? { |step, form| step.is_a?(Integer) && step > 0 && form.is_a?(Hash) }
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless fits
            when :copies
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless value.is_a?(Array) && value.all? { |copy| copy.is_a?(Hash) }
            when :sides
              sides = value.is_a?(Array) && [2, 4].include?(value.size) ? value : [value]
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless sides.all? { |side| half_units?(side) }
            when :background
              check_background(value)
            when :choices
              check_choices(value)
            when :wheel_choices
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless value.is_a?(Array) && value.all? { |each| wheel_choice?(each) }
              fail_with("#{@name}: a wheel takes up to eight choices, not #{value.size}") if value.size > MOST_WHEEL_CHOICES
            when :wheel_choice
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless wheel_choice?(value)
            when :menu_items
              fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless menu_items?(value)
            end
          end

          # Tells whether a value is a number of whole or half units of room, 0 or more.
          #
          # @param value [Object] The value.
          # @return [Boolean] Whether it is.
          def half_units?(value)
            value.is_a?(Numeric) && value >= 0 && (value * 2) == (value * 2).round
          end

          # Checks a background: a color, :theme, false, or { color:, fade: [side, pixels] } whose
          # side is one of FADE_SIDES.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] It is none of them.
          def check_background(value)
            return if value == :theme || value == false || Declarations.color?(value)

            fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless value.is_a?(Hash)
            unknown = value.keys - BACKGROUND_KEYS
            fail_with("#{@name}: a background takes no #{unknown.first}:; it takes color: and fade:") unless unknown.empty?
            fail_with("#{@name}: color: takes a color, not #{Declarations.show(value[:color])}") unless value[:color] == :theme || Declarations.color?(value[:color])
            fade = value[:fade]
            return if fade.nil?

            fits = fade.is_a?(Array) && fade.size == 2 && FADE_SIDES.include?(fade[0]) && fade[1].is_a?(Integer) && fade[1] > 0
            fail_with("#{@name}: fade: takes [side, pixels] with a side among #{FADE_SIDES.map { |side| side.inspect }.join(', ')}, such as [:right, 48], not #{Declarations.show(fade)}") unless fits
          end

          # Tells whether a value is a choice of a wheel: a text, or a Hash such as { text:, icon: }.
          #
          # @param value [Object] The value.
          # @return [Boolean] Whether it is.
          def wheel_choice?(value)
            value.is_a?(String) || value.is_a?(Hash)
          end

          # Tells whether a value is the items of a menu: texts, or Hashes with a :text whose :items
          # are the items of a menu of their own.
          #
          # @param value [Object] The value.
          # @return [Boolean] Whether it is.
          def menu_items?(value)
            value.is_a?(Array) && value.all? do |item|
              item.is_a?(String) || (item.is_a?(Hash) && !item[:text].nil? && (item[:items].nil? || menu_items?(item[:items])))
            end
          end

          # Checks a theme: :game, or the name of a preset the player's row offers.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] It names no preset.
          def check_theme(value)
            return if value == :game

            fail_with("#{@name}: takes :game or a preset's name such as \"Legacy\", not #{Declarations.show(value)}") unless value.is_a?(String)
            presets = Declarations.presets
            return if presets.nil? || presets.any? { |name| name.downcase == value.strip.downcase }

            near = Declarations.nearest(value, presets)
            fail_with("#{@name}: #{value.inspect} is no preset#{near ? "; did you mean #{near.inspect}?" : '.'} Presets: #{presets.map { |each| each.inspect }.join(', ')}")
          end

          # Checks an icon: an IconSet index, a name UI.icon gave one, or a picture file as { file: }.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] It is none of them, or a name no mod gave an icon.
          def check_icon(value)
            return if value.is_a?(Integer) && value >= 0
            return if value.is_a?(Hash) && value.keys == [:file] && value[:file].is_a?(String)
            fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}") unless value.is_a?(Symbol)

            names = Declarations.icon_names
            return if names.nil? || names.include?(value)

            near = Declarations.nearest(value, names)
            fail_with("#{@name}: :#{value} is no icon name; give it one with UI.icon :#{value}, 191#{near ? "; did you mean :#{near}?" : ''}")
          end

          # Checks a map character to follow: :player, an event's id, a character or a sprite.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] It is none of them.
          def check_character(value)
            return if value == :player || value.is_a?(Integer) || value.respond_to?(:screen_x) || (defined?(::Sprite) && value.is_a?(::Sprite))

            near = value.is_a?(Symbol) ? Declarations.nearest(value, [:player]) : nil
            fail_with("#{@name}: takes #{takes}, not #{Declarations.show(value)}#{near ? "; did you mean #{near.inspect}?" : ''}")
          end

          # Checks a hotkey's name: a Symbol, and a hotkey some mod defined once the hotkeys loaded.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] It names no hotkey.
          def check_hotkey(value)
            fail_with("#{@name}: takes the name of a hotkey, such as :gear_compare_open, not #{Declarations.show(value)}") unless value.is_a?(Symbol)
            return unless defined?(Mod_Framework::Hotkeys) && Mod_Framework::Hotkeys.code(value).nil?

            near = Declarations.nearest(value, Mod_Framework::Hotkeys.names)
            fail_with("#{@name}: :#{value} is no hotkey; define it with Mod_Framework::Hotkeys.define#{near ? "; did you mean :#{near}?" : ''}")
          end

          # Checks a Hash by the game's extra buttons: its keys among :a, :x, :y and :z, its values
          # handlers for on_button: and texts for button_help:, nil for none in either.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] A key is no extra button or a value does not fit.
          def check_buttons(value)
            fail_with("#{@name}: takes a Hash such as { z: ... }, not #{Declarations.show(value)}") unless value.is_a?(Hash)

            value.each do |button, each|
              unless BUTTONS.include?(button)
                near = Declarations.nearest(button, BUTTONS)
                fail_with("#{@name}: #{Declarations.show(button)} is none of the game's buttons :a, :x, :y and :z#{near ? "; did you mean #{near.inspect}?" : ''}")
              end
              fits = each.nil? || (@type == :buttons ? each.is_a?(Proc) || each.is_a?(Symbol) : each.is_a?(String) || each.is_a?(Symbol))
              fail_with("#{@name}: #{button.inspect} takes #{@type == :buttons ? 'a lambda, a method name' : 'a text'} or nil, not #{Declarations.show(each)}") unless fits
            end
          end

          # Checks the choices of a context menu: each a text, or a Hash with a :text, whose
          # :on_click is a lambda or a method name.
          #
          # @param value [Object] The value.
          # @raise [MarkupError] A choice does not fit.
          def check_choices(value)
            fail_with("#{@name}: takes an Array of choices or a lambda answering them, not #{Declarations.show(value)}") unless value.is_a?(Array)

            value.each do |choice|
              next if choice.is_a?(String)

              unless choice.is_a?(Hash) && !choice[:text].nil?
                fail_with("#{@name}: takes texts or { text:, on_click: } as choices, not #{Declarations.show(choice)}")
              end
              unknown = choice.keys - CHOICE_KEYS
              unless unknown.empty?
                near = Declarations.nearest(unknown.first, CHOICE_KEYS)
                fail_with("#{@name}: a choice takes no #{unknown.first}:#{near ? "; did you mean #{near}:?" : "; it takes #{CHOICE_KEYS.map { |key| "#{key}:" }.join(', ')}"}")
              end
              handler = choice[:on_click]
              fail_with("#{@name}: on_click: of a choice takes a lambda or a method name, not #{Declarations.show(handler)}") unless handler.nil? || handler.is_a?(Proc) || handler.is_a?(Symbol)
            end
          end

          # Raises a markup error.
          #
          # @param message [String] What went wrong.
          # @raise [MarkupError] Always.
          def fail_with(message)
            raise MarkupError, message
          end
        end

        # A component's declaration: its params, events, keys and places, which a markup call is
        # checked against.
        class Declaration
          # @return [Symbol] Its markup name.
          attr_reader :name

          # @return [String] A line about it.
          attr_reader :summary

          # @return [Array<Symbol>] The params its values before the Hash name, in order.
          attr_reader :args

          # @return [Hash{Symbol => Param}] Its params by name.
          attr_reader :params

          # @return [Hash{Symbol => String}] Its events and what each tells.
          attr_reader :events

          # @return [Symbol, nil] :open for a root UI.open opens, :show for one UI.show shows, nil
          #   for a part inside a root.
          attr_reader :root

          # @return [Hash] Anything else the declaration holds: :keys, :pad, :mouse, :places,
          #   :content, and what builds its engine part.
          attr_reader :spec

          # Makes a declaration.
          #
          # @param name [Symbol] Its markup name.
          # @param spec [Hash] :summary, :args, :params (name to Param spec), :one_of (lists of params
          #   of which a call needs one), :events, :root, :content, :keys, :pad, :mouse, :places and
          #   the rest of spec.
          def initialize(name, spec)
            @name = name
            @spec = spec
            @summary = spec[:summary].to_s
            @args = spec[:args] || []
            @root = spec[:root]
            @events = spec[:events] || {}
            @params = {}
            (spec[:common] == false ? {} : Declarations::COMMON).merge(spec[:params] || {}).each { |key, param| @params[key] = Param.new(key, param) }
            @events.each_key { |event| @params[:"on_#{event}"] ||= Param.new(:"on_#{event}", :kind => :handler, :doc => @events[event]) }
          end

          # Tells whether it takes markup in a block.
          #
          # @return [Boolean] Whether it does.
          def content?
            @spec[:content] ? true : false
          end

          # Turns the values of a markup call into params and checks each one.
          #
          # @param values [Array] The call's values: those the declaration's args name, then a Hash.
          # @return [Hash{Symbol => Object}] The params.
          # @raise [MarkupError] A value or a param does not fit.
          def take(values)
            options = values.last.is_a?(Hash) ? values.last : nil
            plain = options ? values[0...-1] : values
            if plain.size > @args.size
              raise MarkupError, "#{@name} takes #{@args.empty? ? 'no values' : "#{@args.size} value#{@args.size == 1 ? '' : 's'} (#{@args.join(', ')})"} before its params, not #{plain.size}"
            end

            params = {}
            plain.each_with_index { |value, index| params[@args[index]] = value }
            options.each { |key, value| params[key] = value } if options
            params.each { |key, value| check(key, value) }
            check_changes("compact: a form", params[:compact].values) if params[:compact]
            check_changes("compact_for: a copy", params[:compact_for]) if params[:compact_for]
            @params.each_value { |param| raise MarkupError, "#{@name} needs #{param.name}:" if param.required? && params[param.name].nil? }
            Array(@spec[:one_of]).each do |names|
              raise MarkupError, "#{@name} needs #{names.map { |name| "#{name}:" }.join(' or ')}" if names.all? { |name| params[name].nil? }
            end
            params
          end

          # Checks one param.
          #
          # @param key [Symbol] Its name.
          # @param value [Object] Its value.
          # @raise [MarkupError] It is unknown or its value does not fit.
          def check(key, value)
            param = @params[key]
            return param.check(@name, value) if param

            near = Declarations.nearest(key, @params.keys)
            raise MarkupError, "#{@name} takes no #{key}:#{near ? "; did you mean #{near}:?" : "; it takes #{@params.keys.map { |each| "#{each}:" }.join(', ')}"}"
          end

          # The params a compact form or a copy cannot change: who the part is, its forms and its copies.
          FORMLESS = [:id, :key, :compact, :compact_for]

          # Checks the params of each compact form or copy as the part's own.
          #
          # @param what [String] What each is in a refusal, such as "compact: a form".
          # @param changes [Array<Hash>] The params of each.
          # @raise [MarkupError] One changes who the part is, or a param does not fit.
          def check_changes(what, changes)
            changes.each do |form|
              form.each do |key, value|
                raise MarkupError, "#{what} cannot change #{key}:" if FORMLESS.include?(key)

                check(key, value)
              end
            end
          end
        end

        # The params every built-in takes.
        COMMON = {
          :id => { :type => :id, :doc => "its public name, which other mods' UI.patch selects; unique within the mod" },
          :class => { :type => :symbols, :doc => "names for selectors" },
          :key => { :doc => "who it is among siblings of its type, so a part made in a loop keeps its state" },
          :visible => { :kind => :live, :type => :bool, :default => true, :doc => "false takes no room" },
          :disabled => { :kind => :live, :type => :bool, :default => false, :doc => "greyed out and takes no input: a press buzzes and the keys skip it; its tooltip still shows" },
          :tooltip => { :kind => :live, :type => :text, :doc => "shows on hover and on key focus" },
          :help => { :type => :text, :doc => "a line for the help line" },
          :width => { :type => :size, :values => [:fill, :content], :default => :content, :doc => "pixels; :fill takes the free room" },
          :height => { :type => :size, :values => [:fill, :content], :default => :content, :doc => "pixels; :fill takes the free room" },
          :min_size => { :type => :pair, :doc => "the least size" },
          :max_size => { :type => :pair, :doc => "the largest size" },
          :grow => { :type => :int, :default => 0, :doc => "share of the free room in a stack" },
          :align_self => { :values => [:start, :center, :end, :stretch], :doc => "where it sits across its stack" },
          :autofocus => { :type => :bool, :default => false, :doc => "the focus starts on it as its window opens, not on the first part that takes the keys, and lands on it as the keys go into a part around it, such as confirm into a page view's pane" },
          :context_menu => { :type => :choices, :doc => "the choices a right click, the Menu key or a gamepad's confirm held opens on it, each a text or { text:, on_click:, disabled:, tooltip: }, or a lambda answering them" },
          :on_focus => { :kind => :handler, :doc => "runs as the keys or a click move the focus onto it, such as to change a key help or a help text by the part in use" },
          :on_blur => { :kind => :handler, :doc => "runs as the focus leaves it" },
          :compact => { :type => :forms,
                        :doc => "its compact forms, tried in order as its window runs short of room: at each step every part takes the form of the highest step it names up to it, until what the window holds fits; the window keeps its step while it keeps its size" },
          :compact_for => { :type => :copies,
                            :doc => "copies of it that never show, each with these params over its own, such as [{ picked: tallest_item }]: its window picks the step of the compact forms as for the tallest of the part and its copies, so the step stays as what the part shows changes" },
          :pulse => { :kind => :live,
                      :doc => "any value; each time it changes, the part pulses once, turning see-through and fading back, such as gold an event gave; not as it first shows, nor with Animations off" },
          :outline => { :kind => :live, :type => :color, :doc => "the outline of its texts and of everything inside it; black by default" },
          :contrast => { :kind => :live, :type => :bool, :default => false,
                         :doc => "true writes the texts of it and of everything inside it that lie on a fill, such as a filled button's, in text_dark or text_light, whichever reads better on the fill, a dark text with text_light round it; text_color: and outline: set by hand win" },
          :theme => { :type => :theme, :doc => "the look of it and everything inside it, whose color names resolve in that preset: :game for the look of the game's own windows, their skin, or the player's pick while Look on Game Windows is On, with its rows and its texts without typo: in the game's own font size; or a preset's name; the player's pick by default" },
          :margin => { :type => :sides,
                       :doc => "room kept around it, outside its size, where nothing of it draws and it takes no clicks; it adds to the spacing: of what it lies in; on a window, a dialog or a hud the room from the screen's edge and the parts beside it" },
          :padding => { :type => :sides,
                        :doc => "room between its border and what it holds, in place of the part's own room; a title row, a scrollbar and the room of a mark, an icon, a badge or an arrow stay; by default the part's own room" },
          :padding_shrinks => { :type => :bool, :default => false,
                                :doc => "true lets its padding give way, down to none on each side, before what it holds narrows once it reaches its max_size: or the room it gets, such as a strip whose text takes the whole max width" },
          :border => { :kind => :live, :type => :color, :values => [:shade, :theme, false],
                       :doc => "a line along the inside of its edge, in that color: :shade a darker shade of its own color (its color:, the first of colors:), :theme the theme's frame, false none; " \
                               "by default the theme's frame on a paper, card, hud, popover and text field, the theme's edge on a progress bar, none elsewhere; while the focus or the pointer lights a part by its edge, the light shows instead" },
          :border_width => { :type => :count,
                             :doc => "how thick its border is, in pixels, inside its size; with :theme the theme's rim takes the outer pixel and its edge the rest; by default the part's own, 1 where it draws none" },
          :background => { :kind => :live, :type => :background,
                           :doc => "fills its size under everything it draws, inside its border: a color, :theme for the look's own back, false for none, or { color:, fade: [:right, 48] }, which thins it from its alpha to nothing over its last pixels toward that side; " \
                                   "by default the theme's back on a paper, card, hud and popover, the field color on a text field, the well on a progress bar and an avatar, none elsewhere; on a window or a dialog with the game's frame it paints the frame's back, which takes no fade" }
        }

        @all = {}


        # Declares a built-in component.
        #
        # @param name [Symbol] Its markup name.
        # @param spec [Hash] See Declaration#initialize.
        # @return [Declaration] The declaration.
        def self.define(name, spec)
          @all[name] = Declaration.new(name, spec)
        end

        # Finds a built-in's declaration.
        #
        # @param name [Symbol] Its markup name.
        # @return [Declaration, nil] The declaration, nil for none.
        def self.[](name)
          @all[name]
        end

        # Tells every built-in's declaration, in the order they were declared.
        #
        # @return [Array<Declaration>] The declarations.
        def self.all
          @all.values
        end

        # Tells the markup names of the built-ins a modder writes, without the parts the framework
        # makes for itself.
        #
        # @return [Array<Symbol>] The names.
        def self.names
          documented.map { |declaration| declaration.name }
        end

        # Tells the color names a color param takes: the palette roles and the names mods added.
        #
        # @return [Array<Symbol>] The names.
        def self.color_names
          return COLORS unless defined?(Theme)

          COLORS + Theme.color_names.map { |name| name.to_sym }
        end

        # Tells the names mods gave icons with UI.icon, nil while the UI layer's looks are not
        # loaded, as for docs/ui.
        #
        # @return [Array<Symbol>, nil] The names.
        def self.icon_names
          defined?(Looks) ? Looks.icon_names : nil
        end

        # Tells the presets a theme: param may name, nil while the theme is not loaded, as for the
        # docs/ui.
        #
        # @return [Array<String>, nil] The names.
        def self.presets
          defined?(Theme) ? Theme.names : nil
        end

        # Tells whether a value names a color.
        #
        # @param value [Object] The value.
        # @return [Boolean] Whether it is a color name, "#RRGGBB", [r, g, b] with an alpha or not, or a
        #   game text color, numbered as the game's \C[n] numbers them.
        def self.color?(value)
          return value >= 0 if value.is_a?(Integer)
          return color_names.include?(value) if value.is_a?(Symbol)
          return !(value =~ /\A#\h{6}\z/).nil? if value.is_a?(String)

          value.is_a?(Array) && [3, 4].include?(value.size) && value.all? { |each| each.is_a?(Integer) }
        end

        # Finds the name nearest a wrong one, within NEAR edits.
        #
        # @param wrong [Object] The wrong name.
        # @param names [Array] The right names.
        # @return [Object, nil] The nearest name, nil when none is near.
        def self.nearest(wrong, names)
          text = wrong.to_s
          best = nil
          best_distance = NEAR + 1
          names.each do |name|
            distance = distance(text, name.to_s)
            next unless distance < best_distance

            best = name
            best_distance = distance
          end
          best
        end

        # Counts the edits between two words: letters put in, taken out or changed.
        #
        # @param from [String] One word.
        # @param to [String] The other word.
        # @return [Integer] The edits.
        def self.distance(from, to)
          row = (0..to.size).to_a
          from.each_char.with_index do |letter, index|
            previous = row.dup
            row[0] = index + 1
            to.each_char.with_index do |other, place|
              row[place + 1] = [previous[place + 1] + 1, row[place] + 1, previous[place] + (letter == other ? 0 : 1)].min
            end
          end
          row[to.size]
        end

        # Describes a wrong value for a message.
        #
        # @param value [Object] The value.
        # @return [String] Its inspect, cut short.
        def self.show(value)
          text = value.inspect
          text.size > 40 ? "#{text[0, 37]}..." : text
        end


        # Tells the built-ins a modder writes, without the parts the framework makes for itself.
        #
        # @return [Array<Declaration>] The declarations, in the order they were declared.
        def self.documented
          all.reject { |declaration| declaration.spec[:hidden] }
        end

        # Writes the table a page of docs/ui shows between its markers: a built-in's params, events
        # and keys, or with :common the params every built-in takes.
        #
        # @param name [Symbol] The built-in's markup name, or :common.
        # @return [String, nil] The table in Markdown, nil for a name no built-in has.
        def self.page_table(name)
          return common_table.join("\n") if name == :common

          declaration = self[name]
          declaration && !declaration.spec[:hidden] ? section(declaration).join("\n") : nil
        end

        # Writes the table of the params every built-in takes.
        #
        # @return [Array<String>] The lines.
        def self.common_table
          ["| Param | Takes | Default | Live | About |", "|---|---|---|---|---|"] + COMMON.keys.map { |key| param_row(Param.new(key, COMMON[key])) }
        end
        private_class_method :common_table

        # Writes what a page tells of a built-in: its summary, how it is written, its
        # own params, its events, the calls of its handle and its keys.
        #
        # @param declaration [Declaration] The built-in's declaration.
        # @return [Array<String>] The lines.
        def self.section(declaration)
          lines = [declaration.summary, ""]
          call = ([declaration.name.to_s] + declaration.args.map { |arg| arg.to_s }).join(" ")
          lines << "Written `#{call}#{declaration.args.empty? ? '' : ','} ...`#{declaration.content? ? ' with a `do ... end` block of markup' : ''}."
          lines << "Opened by `UI.#{declaration.root}`." if declaration.root
          lines << "It goes inside #{Array(declaration.spec[:inside]).map { |name| "`#{name}`" }.join(' or ')}." if declaration.spec[:inside]
          own = declaration.params.values.reject { |param| COMMON.key?(param.name) || param.kind == :handler || param.hidden? }
          unless own.empty?
            lines.concat(["", "| Param | Takes | Default | Live | About |", "|---|---|---|---|---|"])
            own.each { |param| lines << param_row(param) }
          end
          unless declaration.events.empty?
            lines.concat(["", "| Event | Tells |", "|---|---|"])
            declaration.events.each { |event, doc| lines << "| `on_#{event}` | #{doc} |" }
          end
          actions = declaration.spec[:actions] || {}
          unless actions.empty?
            lines.concat(["", "| Call on `part(:id)` | Does |", "|---|---|"])
            actions.each { |action, spec| lines << "| `#{action}#{spec[:args] ? "(#{spec[:args]})" : ''}` | #{spec[:doc]} |" }
          end
          [[:keys, "Keys"], [:pad, "Pad"], [:mouse, "Mouse"], [:places, "Places"]].each do |key, title|
            lines.concat(["", "**#{title}:** #{declaration.spec[key]}"]) if declaration.spec[key]
          end
          lines
        end
        private_class_method :section

        # Writes a param's row of a table.
        #
        # @param param [Param] The param.
        # @return [String] The row.
        def self.param_row(param)
          default = param.default.nil? ? "" : "`#{param.default.inspect}`"
          "| `#{param.name}:` | #{param.takes} | #{default} | #{param.live? ? 'yes' : ''} | #{param.doc} |"
        end
        private_class_method :param_row
      end
    end
  end
end
