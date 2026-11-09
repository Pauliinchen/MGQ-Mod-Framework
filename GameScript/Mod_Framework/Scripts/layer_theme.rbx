#----------------------------------------------------------------
#  layer_theme.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Let a pulse take two colors or more, as a slide does
#      Paulinchen  2026-11-06: Checked the colors and the speed of a slide or a pulse here instead of in C#
#                            - Added UI.color_now, the color a name has in the player's look now
#                            - Kept the color names and presets a mod gives before the DLL started, and added them once it starts
#      Paulinchen  2026-11-05: Let a mod give each severity an icon, which its alerts and toasts show unless they name one
#                            - Let a mod name a color after another color name, or an animated color that slides, pulses or
#                              follows its own lambda
#      Paulinchen  2026-11-04: Let a mod name an icon with UI.icon
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What a mod adds to the looks of the UI layer and the defaults of its own parts: UI.preset and
      # UI.color hand a preset or a color name to the theme, which C# checks and keeps, UI.icon
      # names an icon, and UI.defaults keeps the defaults a mod gives its own parts, which a markup
      # call of the mod's components takes for the params it leaves out, and the icon of each severity
      # its alerts and toasts show. A preset or a color name given before the DLL started waits and is
      # added once it starts, so a mod need not load after the framework's DLL.
      module Looks
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # The keys UI.preset takes.
        PRESET_KEYS = [:from, :palette]

        # The keys an animated UI.color takes.
        EFFECT_KEYS = [:slide, :pulse, :speed]

        # The kinds of params a default may not give: what names, binds or runs.
        NO_DEFAULT_KINDS = [:handler, :content, :item, :bind]

        # The params a default may not give, since each names one part.
        NO_DEFAULT_PARAMS = [:id, :key]

        # The name UI.defaults takes for the icons of the severities instead of a built-in's.
        SEVERITY_ICONS = :severity_icons

        # The severities that may have an icon.
        SEVERITIES = [:info, :success, :warning, :error]

        # Each mod's defaults, by the mod and the built-in's markup name.
        @defaults = {}

        # The icons mods named, each an IconSet index or { :file => path }, by the name.
        @icons = {}

        # The mod that named each icon, by the name.
        @icon_mods = {}

        # The presets and color names given before the DLL started, in order, each [kind, name, value,
        # presets, mod] with kind :preset or :color.
        @kept = []

        # Adds a mod's preset to the player's list.
        #
        # @param name [String] Its name.
        # @param options [Hash] :from, the preset it starts from; :palette, the roles it sets.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] A key or a value does not fit.
        def self.preset(name, options, trace)
          unknown = options.keys - PRESET_KEYS
          unless unknown.empty?
            near = Declarations.nearest(unknown.first, PRESET_KEYS)
            refuse("UI.preset takes no #{unknown.first}:#{near ? "; did you mean #{near}:?" : "; it takes from: and palette:"}", trace)
          end
          refuse("UI.preset #{name.inspect} needs from:, the preset it starts from, such as \"Legacy\"", trace) if options[:from].nil?
          refuse("UI.preset takes palette: as a Hash such as { primary: \"#B08CFF\" }", trace) unless options[:palette].nil? || options[:palette].is_a?(Hash)

          given = [:preset, name, options, nil, Errors.mod(trace)]
          return keep(given) unless Theme.with_model?

          refused = add(given)
          refuse(refused, trace) if refused
        end

        # Adds a mod's color name: plain, with its own color in some presets, or animated.
        #
        # @param name [Symbol] The name.
        # @param value [String, Array, Symbol, Hash, Proc] Its color, the color name it follows, the
        #   keys of an animated color, or a lambda of the letter and the frame.
        # @param presets [Hash{String => Object}] Its color in some presets, by their names.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] It was refused.
        def self.color(name, value, presets, trace)
          refuse("UI.color takes the name as a Symbol, such as :quest, not #{Declarations.show(name)}", trace) unless name.is_a?(Symbol)

          if value.is_a?(Proc) && value.arity != 2
            refuse("UI.color :#{name} takes a lambda of the letter and the frame, such as ->(letter, frame) { ... }", trace)
          end
          effect(name, value, trace) if value.is_a?(Hash)
          given = [:color, name, value, presets, Errors.mod(trace)]
          return keep(given) unless Theme.with_model?

          refused = add(given)
          refuse(refused, trace) if refused
        end

        # Adds the presets and color names given before the DLL started, in the order given, once it
        # started; each refused is logged, since the mod's call returned long ago.
        def self.settle
          kept = @kept
          @kept = []
          kept.each do |given|
            refused = add(given)
            log("#{given[4]}'s #{given[0] == :preset ? 'preset' : 'color name'} #{given[1].inspect} was refused once the DLL started: #{refused}") if refused
          end
        end

        # Keeps a preset or a color name given before the DLL started, a later one of the same kind
        # and name in place of the earlier.
        #
        # @param given [Array] The kind, the name, the value, its presets and the mod.
        def self.keep(given)
          @kept.reject! { |each| each[0] == given[0] && each[1] == given[1] }
          @kept << given
          log("#{given[4]} gives the #{given[0] == :preset ? 'preset' : 'color name'} #{given[1].inspect} before the DLL started; it is added once it starts")
        end
        private_class_method :keep

        # Hands a preset or a color name to C#.
        #
        # @param given [Array] The kind, the name, the value (a preset's options), its presets and the mod.
        # @return [String, nil] Why it was refused, nil once added.
        def self.add(given)
          kind, name, value, presets, mod = given
          return Theme.add_preset(name, value[:from], value[:palette], mod) if kind == :preset
          return Colors.add_lambda(name, value, mod) if value.is_a?(Proc)

          value.is_a?(Hash) ? Colors.add_moving(name, value, mod) : Theme.add_color(name, value, presets, mod)
        end
        private_class_method :add

        # Checks the keys of an animated color.
        #
        # @param name [Symbol] Its name.
        # @param value [Hash] slide: or pulse:, and speed:.
        # @param trace [Array<String>] Where the mod called it.
        # @return [Hash] The keys.
        # @raise [MarkupError] A key or a value does not fit.
        def self.effect(name, value, trace)
          unknown = value.keys - EFFECT_KEYS
          unless unknown.empty?
            near = Declarations.nearest(unknown.first, EFFECT_KEYS)
            refuse("UI.color :#{name} takes no #{unknown.first}:#{near ? "; did you mean #{near}:?" : "; it takes slide:, pulse: and speed:"}", trace)
          end
          kinds = [:slide, :pulse].select { |kind| value.key?(kind) }
          refuse("UI.color :#{name} takes slide: or pulse:, one of them, with an Array of colors", trace) unless kinds.size == 1 && value[kinds[0]].is_a?(Array)
          kind = kinds[0]
          refuse("UI.color :#{name} takes #{kind}: with two colors or more, not #{value[kind].size}", trace) if value[kind].size < 2
          speed = value[:speed]
          unless speed.nil? || (speed.is_a?(Integer) && speed >= 1 && speed <= Colors::MOST_SPEED)
            refuse("UI.color :#{name} takes speed: as a whole number from 1 to #{Colors::MOST_SPEED}, such as 3", trace)
          end
          value
        end

        # Names an icon for every part's icon:, refusing a name another mod gave first.
        #
        # @param name [Symbol] The name, such as :quest.
        # @param value [Integer, Hash] An IconSet index, or a picture file as { file: path }.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] It was refused.
        def self.icon(name, value, trace)
          refuse("UI.icon takes the name as a Symbol, such as :quest, not #{Declarations.show(name)}", trace) unless name.is_a?(Symbol)
          fits = (value.is_a?(Integer) && value >= 0) || (value.is_a?(Hash) && value.keys == [:file] && value[:file].is_a?(String))
          refuse("UI.icon :#{name} takes an IconSet index or { file: \"Graphics/Pictures/x\" }, not #{Declarations.show(value)}", trace) unless fits

          mod = Errors.mod(trace)
          first = @icon_mods[name]
          refuse("UI.icon :#{name} is named by #{first} already; prefix the name with your mod's", trace) if first && first != mod

          @icons[name] = value
          @icon_mods[name] = mod
          log("#{mod} names the icon :#{name} #{value.inspect}")
        end

        # Tells the icon a name stands for.
        #
        # @param name [Symbol] The name.
        # @return [Integer, Hash, nil] The IconSet index or { :file => path }, nil for no such name.
        def self.icon_of(name)
          @icons[name]
        end

        # Tells the names mods gave icons.
        #
        # @return [Array<Symbol>] The names.
        def self.icon_names
          @icons.keys
        end

        # Keeps the defaults a mod gives a built-in of its own parts.
        #
        # @param name [Symbol] The built-in's markup name, such as :button.
        # @param params [Hash] The defaults.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] The built-in or a param does not fit.
        def self.defaults(name, params, trace)
          return severity_icons(params, trace) if name == SEVERITY_ICONS

          declaration = Declarations[name]
          unless declaration
            near = Declarations.nearest(name, Declarations.names)
            refuse("UI.defaults: #{Declarations.show(name)} is no built-in#{near ? "; did you mean #{near.inspect}?" : ''}", trace)
          end

          params.each do |key, value|
            begin
              declaration.check(key, value)
            rescue MarkupError => e
              refuse("UI.defaults #{name.inspect}: #{e.message}", trace)
            end
            param = declaration.params[key]
            if NO_DEFAULT_PARAMS.include?(key) || NO_DEFAULT_KINDS.include?(param.kind) || declaration.args.include?(key)
              refuse("UI.defaults #{name.inspect} gives #{key}:, which names, binds or runs one part; defaults give looks and sizes, such as variant: and dense:", trace)
            end
          end

          mod = Errors.mod(trace)
          own = (@defaults[mod] ||= {})
          own[name] = (own[name] || {}).merge(params)
          log("#{mod} gives its #{name} the defaults #{own[name].inspect}")
        end

        # Keeps the icon a mod gives each severity, which its alerts and toasts show.
        #
        # @param params [Hash] The icons by severity, such as { warning: 56 }.
        # @param trace [Array<String>] Where the mod called it.
        # @raise [MarkupError] A severity or an icon does not fit.
        def self.severity_icons(params, trace)
          params.each do |severity, icon|
            unless SEVERITIES.include?(severity)
              near = Declarations.nearest(severity, SEVERITIES)
              refuse("UI.defaults #{SEVERITY_ICONS.inspect} takes no #{severity}:#{near ? "; did you mean #{near}:?" : "; it takes #{SEVERITIES.map { |each| "#{each}:" }.join(', ')}"}", trace)
            end
            begin
              Declarations::Param.new(severity, :type => :icon).check(SEVERITY_ICONS, icon)
            rescue MarkupError => e
              refuse("UI.defaults #{SEVERITY_ICONS.inspect}: #{e.message}", trace)
            end
          end

          mod = Errors.mod(trace)
          own = (@defaults[mod] ||= {})
          own[SEVERITY_ICONS] = (own[SEVERITY_ICONS] || {}).merge(params)
          log("#{mod} gives its severities the icons #{own[SEVERITY_ICONS].inspect}")
        end
        private_class_method :severity_icons

        # Tells the icon a mod gave a severity.
        #
        # @param mod [String, nil] The mod.
        # @param severity [Symbol, nil] The severity.
        # @return [Integer, Symbol, Hash, nil] The icon, nil for none.
        def self.severity_icon(mod, severity)
          icons = mod && @defaults[mod] && @defaults[mod][SEVERITY_ICONS]
          icons ? icons[severity] : nil
        end

        # Gives a toast the icon of its severity that the mod calling it gave, unless it names one.
        #
        # @param options [Hash] The toast's options.
        # @param trace [Array<String>] Where it was called.
        # @return [Hash] The options.
        def self.toast_icon(options, trace)
          return options if @defaults.empty? || options.key?(:icon)

          icon = severity_icon(Errors.mod(trace), options[:severity])
          icon.nil? ? options : options.merge(:icon => icon)
        end

        # Adds a mod's defaults to the values of a markup call its components make: each default
        # stands for a param the call leaves out, and an alert without icon: takes the icon the mod
        # gave its severity. Other mods' calls stay as they are.
        #
        # @param name [Symbol] The built-in's markup name.
        # @param values [Array] The call's values.
        # @param owner [Object] Whoever wrote the call.
        # @return [Array] The values.
        def self.with_defaults(name, values, owner)
          return values if @defaults.empty?

          mod = Scopes.mod_of(owner.class)
          own = mod && @defaults[mod] && @defaults[mod][name]
          icons = name == :alert && mod && @defaults[mod] && @defaults[mod][SEVERITY_ICONS]
          return values unless own || icons

          given = values.last.is_a?(Hash) ? values.last : nil
          params = (own || {}).merge(given || {})
          icon = icons && !params.key?(:icon) ? icons[params[:severity]] : nil
          params = params.merge(:icon => icon) unless icon.nil?
          (given ? values[0...-1] : values) + [params]
        end

        # Raises a markup error that names the mod's file and line.
        #
        # @param message [String] What went wrong.
        # @param trace [Array<String>] Where the mod called.
        # @raise [MarkupError] Always.
        def self.refuse(message, trace)
          raise MarkupError, Errors.placed(message, trace)
        end
        private_class_method :refuse
      end
    end

    # Adds a look preset to the player's Interface Look row. Only the player picks the look in use;
    # a mod may pin a preset on its own parts with theme:. A preset given before the framework's DLL
    # started waits and is added once it starts.
    #
    # @param name [String] Its name, such as "Moonlight".
    # @param options [Hash] from: (the preset it starts from, such as "Legacy") and palette: (the
    #   roles it sets, such as { primary: "#B08CFF", back: [20, 16, 40, 235] }).
    # @raise [Engine::MarkupError] It was refused, with the reason and the nearest right name.
    def self.preset(name, options = {})
      Engine::Looks.preset(name, options, caller)
    end

    # Names a color that every color param and the text code \C[name] take, of every part. Names
    # are global, so prefix rare ones with your mod, such as :gear_compare_up. A name given before the
    # framework's DLL started waits and is added once it starts.
    #
    #   UI.color :legendary, [181, 162, 21]                  # a plain color
    #   UI.color :quest, "#FFC040", "Legacy" => "#FFD878"    # with its own color in a preset
    #   UI.color :fire, slide: [:red, :yellow]               # colors moving across the letters
    #   UI.color :alarm, pulse: [:text, :error], speed: 6    # the whole text going to :error and back
    #   UI.color :festival, pulse: UI::RAINBOW               # the whole text going through the rainbow
    #   UI.color :glow, ->(letter, frame) { UI.hue(letter * 20 + frame) }
    #
    # @param name [Symbol] The name, such as :quest.
    # @param value [String, Array, Symbol, Hash, Proc] Its color: "#RRGGBB", [r, g, b(, a)] or a
    #   color name it follows; or slide: or pulse:, each with two colors or more, with speed:
    #   (the degrees of the cycle it moves a frame, 3 by default); or a lambda of the letter, or
    #   the band of an area, and the frame, answering a color.
    # @param presets [Hash{String => Object}] Its color in some presets, such as "Legacy" => "#FFD878".
    # @raise [Engine::MarkupError] It was refused, such as a name another mod added first.
    def self.color(name, value = nil, presets = {})
      Engine::Looks.color(name, value, presets, caller)
    end

    # Tells the color a color name or a role has in the player's look right now, for drawing on a
    # bitmap of a mod's own or of a game window, such as a name in change_color; a moving color
    # answers its color in this frame.
    #
    # Ask it each time you draw: the player may pick another look while the game runs.
    #
    # @param name [Symbol, String, Array, Color] A role such as :error or :own, a color name a mod
    #   added, "#RRGGBB", [r, g, b(, a)] or a Color.
    # @param window [Window_Base, nil] A game window whose look counts instead, as Look on Game
    #   Windows dresses it; nil for the player's look.
    # @return [Color] A copy of the color, which the caller may change.
    # @raise [Engine::MarkupError] The name is no color name, with the nearest one.
    def self.color_now(name, window = nil)
      found = name.is_a?(Symbol) ? (window ? Engine::Theme.palette_for(window) : Engine::Palette.live).now(name) : Engine::Colors.color_of(name)
      unless found
        near = name.is_a?(Symbol) ? Engine::Declarations.nearest(name, Engine::Declarations.color_names) : nil
        raise Engine::MarkupError, Engine::Errors.placed("UI.color_now takes a color name, \"#RRGGBB\" or [r, g, b], not #{name.inspect}#{near ? "; did you mean #{near.inspect}?" : ''}", caller)
      end

      Color.new(found.red, found.green, found.blue, found.alpha)
    end

    # Names an icon that every part's icon: and a canvas take by its name, such as UI.icon :quest,
    # 191. Names are global, so prefix rare ones with your mod.
    #
    # @param name [Symbol] The name.
    # @param value [Integer, Hash] An IconSet index, or a picture file as { file: "Graphics/Pictures/x" }.
    # @raise [Engine::MarkupError] It was refused, such as a name another mod gave first.
    def self.icon(name, value)
      Engine::Looks.icon(name, value, caller)
    end

    # Sets defaults for a built-in of your own mod's parts, such as UI.defaults :button, variant:
    # :outlined, or with :severity_icons the icon of each severity your alerts and toasts show, such as
    # UI.defaults :severity_icons, warning: 56. A param a markup call gives wins; other mods' parts are
    # never touched.
    #
    # @param name [Symbol] The built-in's markup name, or :severity_icons.
    # @param params [Hash] The defaults: looks and sizes, no id:, key:, handler or text; or icons by
    #   :info, :success, :warning and :error.
    # @raise [Engine::MarkupError] The built-in or a param does not fit.
    def self.defaults(name, params)
      Engine::Looks.defaults(name, params, caller)
    end
  end
end
