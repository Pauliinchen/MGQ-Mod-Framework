#----------------------------------------------------------------
#  theme.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Calmed Monarch's success green, which every look takes
#                            - Let a window that paints a look of its own wear it after each dress
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#                            - Kept the window color the game's options hold however the game or a plugin sets it
#      Paulinchen  2026-11-06: Handed C# the colors an animated name moves through and dropped asking it for them at a frame
#                            - Called the engine's classes by their names under UI::Engine
#                            - Wrote the help of the Options row as one text, which the help window breaks to its width
#                            - Dressed a part of theme :game as the game's own windows are dressed, in the player's preset while
#                              Look on Game Windows is On
#      Paulinchen  2026-11-05: Took the colors a filled part hands to what it holds as a theme
#                            - Took the tint off a window in a preset without making objects
#                            - Told the game's window color as the game keeps it
#                            - Handed out the greyed colors of what a game window wears
#                            - Dropped leaving the game's windows to an older MGQ Online beside the framework
#                            - Handed C# the animated color names and a color name that follows another, and asked it
#                              for an animated color's letters at a frame
#      Paulinchen  2026-11-04: Handed the presets to C#, which works out what each holds along the presets it starts
#                              from, and took the presets and color names mods add and the player's pick through it
#                            - Set the text colors and every other color name of the player's preset, besides the box
#                              colors, and kept the typography, spacing and row heights of each preset
#                            - Drew a button's variant in its color as C# tells, in a text color of the button's own
#                            - Gave every preset a primary, a secondary and a tertiary color and a dark and a light text
#                              for filled parts, and handed C# the box colors of the game's window as its window color
#                              changes
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-30: Logged a missing row of the Mod Config without naming Mod Config Remake
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-28: Moved into the Mod Framework from ui_theme.rbx
#                            - Dressed each window by its own theme: the player's look, a preset or the game's
#                            - Painted a window skin per preset and gave each preset its palette
#                            - Kept the look and the window color in the framework's ini
#                            - Dressed the game's windows in Monarch without the DLL, storing nothing
#                            - Left the game's windows to MGQ Online releases that dress them themselves
#                            - Installed the hooks and the rows as the game starts running
#      Paulinchen  2026-10-24: Added the Game's Default look, which follows the game's window color
#                            - Kept the game's window color in Player.ini for every save of the install
#                            - Dressed the game's own windows in the look, unless turned off in the Mod Config
#      Paulinchen  2026-10-12: Gave the tabs not picked the edge's color, darkened
#                            - Added the scrollbar track's color
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The interface presets: the colors every box, frame, gauge and window is drawn in, the player's
      # pick kept in the framework's settings and offered as a row of Options > Mods. A preset sets
      # Style's colors in place, and every window takes a window skin painted in them (see dress);
      # the game's own look takes its box colors from the game's window.
      #
      # C# keeps the presets, the framework's and those mods add, with the color names mods add, and
      # works out what each holds along the presets it starts from (ThemeModel); this module hands
      # them over and draws with what C# answers.
      #
      # The theme needs no DLL: without it the game's windows wear Monarch, Look on Game Windows is
      # On and the game keeps its own window color, none of which the player can change there, since
      # the settings come through the DLL.
      #
      # It must never interrupt the game, so every entry point rescues.
      module Theme
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "theme"

        # One preset as the scripts draw it: its name; Style's colors it sets, by the constant's name,
        # as red, green, blue and alpha (with the game's own look on its chain the box colors it leaves
        # out come from the game's window, see colors_of); every color name it holds, by name; the
        # sizes of its typography names; whether the game's own look lies on its chain; the pixels of
        # a unit of spacing; and the heights of a normal and a dense row.
        Preset = Struct.new(:name, :colors, :roles, :typography, :game, :spacing, :rows)

        # The name of the look that follows the game's window and its window color.
        GAME_LOOK = "Game's Default"

        # The theme of a part that wears what the game's own windows wear, as theme: :game names it.
        GAME_WINDOWS = :game

        # The presets the framework adds, in the order the player's row offers them: Monarch, maroon
        # with a gold edge in a black rim, which holds every value the others start from: its primary
        # a muted gold, its secondary gold and its tertiary rose, and black and white as the texts a
        # filled part picks from; Legacy, black glass with a grey edge, its primary its heading's
        # blue and its tertiary teal; and the game's own look, whose primary and tertiary are the
        # game's heading and edge.
        BUILT_INS = [
          { "name" => "Monarch", "from" => nil,
            "palette" => { "back" => [36, 10, 14, 235], "plate" => [36, 10, 14, 200], "picked" => [120, 36, 52, 235], "field" => [20, 6, 8, 255],
                           "heading" => [240, 204, 130, 255], "edge" => [200, 164, 96, 230], "track" => [84, 50, 38, 240], "rim" => [0, 0, 0, 255],
                           "title" => [255, 224, 140, 255], "well" => [36, 10, 14, 235], "tab" => [100, 78, 40, 235], "text" => [255, 255, 255, 255],
                           "dim" => [176, 176, 176, 255], "success" => [92, 184, 92, 255], "warning" => [255, 224, 96, 255], "error" => [255, 96, 96, 255],
                           "gold" => [255, 200, 64, 255], "own" => [255, 225, 110, 255],
                           "primary" => [200, 160, 80, 255], "secondary" => [255, 200, 64, 255], "tertiary" => [214, 112, 128, 255],
                           "text_dark" => [0, 0, 0, 255], "text_light" => [255, 255, 255, 255] },
            "typography" => { "h6" => 20, "subtitle1" => 18, "subtitle2" => 16, "body1" => 18, "body2" => 16, "caption" => 14, "overline" => 14 },
            "spacing" => 4, "rows" => [24, 20], "motion" => [12, 8], "elevation" => [0, 1, 2, 4] },
          { "name" => "Legacy", "from" => "Monarch",
            "palette" => { "back" => [0, 0, 0, 170], "plate" => [0, 0, 0, 150], "picked" => [48, 96, 176, 220], "field" => [12, 16, 28, 255],
                           "heading" => [160, 200, 255, 255], "edge" => [140, 140, 140, 220], "track" => [48, 48, 48, 200], "rim" => [0, 0, 0, 0],
                           "title" => [255, 255, 255, 255], "well" => [0, 0, 0, 220], "tab" => [64, 64, 64, 170],
                           "primary" => [160, 200, 255, 255], "secondary" => [255, 200, 64, 255], "tertiary" => [96, 208, 176, 255] } },
          { "name" => GAME_LOOK, "from" => "Monarch", "game" => true }
        ]

        # The roles besides the box colors that the game's own look takes from the game, as
        # ThemeModel.GameGiven, for the presets worked out without the DLL.
        GAME_GIVEN = ["primary", "tertiary"]

        # Style's colors a preset sets, by their color names.
        CONSTANTS = { "back" => :BACK, "plate" => :PLATE, "picked" => :PICKED, "field" => :FIELD, "heading" => :HEADING, "edge" => :EDGE, "track" => :TRACK,
                      "rim" => :RIM, "title" => :TITLE, "well" => :WELL, "tab" => :TAB, "text" => :TEXT, "dim" => :DIM, "success" => :GOOD,
                      "warning" => :WARN, "error" => :BAD, "gold" => :GOLD, "own" => :OWN }

        # The topics of ThemeModel in C#.
        PRESET_TOPIC = "ui.theme.preset"
        COLOR_TOPIC = "ui.theme.color"
        NAMES_TOPIC = "ui.theme.names"
        PICK_TOPIC = "ui.theme.pick"
        RESOLVE_TOPIC = "ui.theme.resolve"
        LOOK_TOPIC = "ui.theme.look"
        GAME_TOPIC = "ui.theme.game"

        # Who adds the framework's presets, for C#'s refusals.
        FRAMEWORK = "Mod Framework"

        # The setting that keeps the preset's name.
        SETTING = "ui_preset"

        # The Options > Mods row's key.
        OPTION = :mf_ui_preset

        # The Options > Mods row's name.
        OPTION_NAME = "Interface Look"

        # The Options > Mods row's help.
        OPTION_HELP = "The look of the windows and boxes of mods built on the Mod Framework: Monarch is maroon " \
                      "with a gold edge, Legacy black glass, Game's Default the game's window in its Window Color; " \
                      "after them come the looks mods add."

        # The setting that keeps whether the game's windows wear the look, 1 or 0.
        GAME_WINDOWS_SETTING = "ui_game_windows"

        # The Options > Mods row's key that turns the look on the game's windows on and off.
        GAME_WINDOWS_OPTION = :mf_ui_game_windows

        # The Options > Mods row's name that turns the look on the game's windows on and off.
        GAME_WINDOWS_OPTION_NAME = "Look on Game Windows"

        # The Options > Mods row's help that turns the look on the game's windows on and off.
        GAME_WINDOWS_OPTION_HELP = "On: the game's own windows wear the Interface Look too.\n" \
                                   "Off: they keep the game's Window Color, and only the mods' windows wear it."

        # The Options > Mods row's values.
        ON = "On"
        OFF = "Off"

        # The game's window skin in Graphics/System.
        GAME_SKIN = "Window"

        # Side of a window skin, in pixels.
        SKIN_SIDE = 128

        # Where a window skin keeps the background stretched over the window, as x, y, width and height.
        SKIN_BACK = [0, 0, 64, 64]

        # Where a window skin keeps the pattern tiled over the background.
        SKIN_PATTERN = [0, 64, 64, 64]

        # Where a window skin keeps the frame's square.
        SKIN_FRAME = [64, 0, 64, 64]

        # Where a window skin keeps the cursor.
        SKIN_CURSOR = [64, 64, 32, 32]

        # Pixels of the frame's square along its sides that a window draws its borders from; its
        # middle holds the scroll arrows.
        SKIN_BORDER = 16

        # Where a window skin's palette keeps the normal text color and the system text color.
        SKIN_NORMAL_COLOR = [64, 96]
        SKIN_SYSTEM_COLOR = [64, 112]

        # Pixels between the samples a skin's background is averaged from.
        SAMPLE_STEP = 4

        # How opaque the game draws its windows' background, which the game's look gives the boxes.
        GAME_BACK_OPACITY = 192

        # How far the game's look moves the background towards the cursor's color for a picked row,
        # from 0 to 1; a box fills the row instead of laying the see-through cursor over it.
        PICKED_LIFT = 0.3

        # The setting that keeps the game's window color for every save of this install.
        COLOR_SETTING = "window_color"

        # Where the game's options keep the window color's red, green and blue in each save.
        COLOR_KEYS = [:tone_r, :tone_g, :tone_b]

        # The preset in use.
        @preset = nil

        # The presets C# worked out, by their names in lower case, until a preset or a color name is
        # added.
        @found = {}

        # The presets' names and the color names mods added, as C# lists them; nil until asked.
        @listed = nil

        # Whether C# holds the framework's presets.
        @handed = false

        # The colors of the color names of the player's preset that are none of Style's, by name,
        # changed in place as the player picks another preset.
        @live_roles = {}

        # The looks of a button's variants, by preset, variant and color.
        @looks = {}

        # The framework's presets as made without the DLL, by name.
        @local = {}

        # Counts every change of the colors, which whoever keeps a picture drawn in them compares.
        @serial = 0

        # The window color the game's look was last worked out from, as red, green, blue and gray.
        @tone_seen = nil

        # The window color C# last had the box colors of the game's window in; nil until handed.
        @tone_handed = nil

        # The game's system whose options' window color was last read; nil until read.
        @system_seen = nil

        # The window color that system's options held then, as red, green and blue.
        @color_seen = nil

        # Whether the game's windows wear the look; nil until read from the settings.
        @game_windows = nil

        # The window skin painted for each preset with colors, by the preset itself, not its values.
        @skins = {}.compare_by_identity

        # The palette of each preset with colors besides the player's, by the preset itself.
        @palettes = {}.compare_by_identity

        # The game's look as a palette, worked out for the window color it holds: [tone, palette].
        @game_palette = nil

        # Lists the presets' names, in the order Options > Mods cycles them.
        #
        # @return [Array<String>] The names.
        def self.names
          return BUILT_INS.map { |each| each["name"] } unless with_model?

          listed[0]
        end

        # Lists the color names added, plain and animated, the framework's built-in ones too.
        #
        # @return [Array<String>] The names, empty without the DLL.
        def self.color_names
          with_model? ? listed[1] : []
        end

        # Tells whether C#'s ThemeModel answers, which needs the DLL.
        #
        # @return [Boolean] Whether it does.
        def self.with_model?
          Mod_Framework.available? && Mod_Framework.bridge.has?(PRESET_TOPIC)
        end

        # Asks C#'s ThemeModel, handing it the framework's presets first.
        #
        # @param topic [String] The topic.
        # @param request [Object] The request.
        # @return [Object, nil] The answer, nil for none.
        def self.ask(topic, request)
          hand_built_ins unless @handed
          Mod_Framework.bridge.call(topic, request)
        end

        # Hands C# the framework's presets, once.
        def self.hand_built_ins
          @handed = true
          BUILT_INS.each do |preset|
            refused = Mod_Framework.bridge.call(PRESET_TOPIC, preset.merge("mod" => FRAMEWORK))
            log("the preset #{preset['name']} was refused: #{refused}") if refused
          end
        end

        # Lists the presets' names and the color names, once until another is added.
        #
        # @return [Array(Array<String>, Array<String>)] The names.
        def self.listed
          @listed ||= ask(NAMES_TOPIC, nil) || [BUILT_INS.map { |each| each["name"] }, []]
        end

        # Adds a mod's preset: C# checks it and keeps it.
        #
        # @param name [String] Its name.
        # @param from [String] The preset it starts from.
        # @param palette [Hash{Symbol => Object}] The roles it sets, each a color.
        # @param mod [String] The mod that adds it.
        # @return [String, nil] Why it was refused, nil once added.
        def self.add_preset(name, from, palette, mod)
          return "presets need the Mod Framework's DLL, which did not start" unless with_model?

          request = { "name" => name.to_s, "from" => from.to_s, "palette" => texts(palette), "mod" => mod.to_s }
          added(ask(PRESET_TOPIC, request), "the preset #{name} of #{mod}")
        end

        # Adds a mod's color name: C# checks it and keeps it.
        #
        # @param name [Symbol] The name.
        # @param value [Object] Its color, or the color name it follows.
        # @param presets [Hash{String => Object}] Its color in some presets.
        # @param mod [String] The mod that adds it.
        # @return [String, nil] Why it was refused, nil once added.
        def self.add_color(name, value, presets, mod)
          return "color names need the Mod Framework's DLL, which did not start" unless with_model?

          request = { "name" => name.to_s, "value" => plain_color(value), "presets" => texts(presets), "mod" => mod.to_s }
          added(ask(COLOR_TOPIC, request), "the color name #{name} of #{mod}")
        end

        # Adds a mod's animated color name: C# checks it and keeps it with the colors it moves
        # through, which a filled part picks its text color by; Colors moves it.
        #
        # @param name [Symbol] The name.
        # @param colors [Array] The colors it moves through, each a color or a color name: a slide's
        #   or a pulse's, or what its lambda answers over a cycle.
        # @param mod [String] The mod that adds it.
        # @return [String, nil] Why it was refused, nil once added.
        def self.add_effect(name, colors, mod)
          return "color names need the Mod Framework's DLL, which did not start" unless with_model?

          request = { "name" => name.to_s, "moves" => colors.map { |each| plain_color(each) }, "mod" => mod.to_s }
          added(ask(COLOR_TOPIC, request), "the animated color name #{name} of #{mod}")
        end

        # Takes C#'s answer to an addition: once added, every preset is worked out anew and the
        # player's pick put to use again, which brings back a preset of a mod that loaded after the
        # settings were read.
        #
        # @param refusal [String, nil] Why it was refused, nil once added.
        # @param what [String] What was added, for the log.
        # @return [String, nil] The refusal.
        def self.added(refusal, what)
          return refusal if refusal

          forget
          log("added #{what}")
          apply(Settings.setting(SETTING) || @preset.name, "#{what} added") if @preset
          nil
        end

        # Forgets what C# worked out, after a preset or a color name was added.
        def self.forget
          @found = {}
          @listed = nil
          @looks = {}
          @palettes = {}.compare_by_identity
          @game_palette = nil
        end

        # Writes a Hash for C#: its keys as texts, its colors as C# reads them.
        #
        # @param hash [Hash, nil] The Hash.
        # @return [Hash{String => Object}] The Hash.
        def self.texts(hash)
          Hash[(hash || {}).map { |key, value| [key.to_s, plain_color(value)] }]
        end

        # Writes a color for C#: "#RRGGBB" as it is, a Color or [r, g, b(, a)] as an Array, a color
        # name as a text.
        #
        # @param value [Object] The color.
        # @return [String, Array, Object] The color.
        def self.plain_color(value)
          return [value.red.to_i, value.green.to_i, value.blue.to_i, value.alpha.to_i] if value.is_a?(Color)

          value.is_a?(Symbol) ? value.to_s : value
        end

        # Makes a preset of what C# says it holds.
        #
        # @param table [Hash] What it holds, see ThemeTopics.ResolveTopic.
        # @return [Preset] The preset.
        def self.preset_from(table)
          palette = table["palette"] || {}
          colors = {}
          CONSTANTS.each { |role, constant| colors[constant] = palette[role] if palette[role] }
          roles = {}
          palette.merge(table["colors"] || {}).each { |name, rgba| roles[name.to_sym] = rgba }
          Preset.new(table["name"], colors, roles, table["typography"] || {}, table["game"] == true, table["spacing"], table["rows"])
        end

        # Makes one of the framework's presets without the DLL, which the theme runs without: each
        # role from the nearest preset that sets it, and with the game's own look on the way the box
        # colors from the game. The presets mods add and the color names need C#.
        #
        # @param name [String, nil] The preset's name, the first for an unknown one.
        # @return [Preset] The preset.
        def self.local_preset(name = nil)
          spec = BUILT_INS.find { |each| each["name"].downcase == name.to_s.strip.downcase } || BUILT_INS.first
          @local[spec["name"]] ||= begin
            chain = [spec]
            chain.unshift(BUILT_INS.find { |each| each["name"] == chain.first["from"] }) while chain.first["from"]
            table = chain.inject("palette" => {}) do |all, each|
              palette = each["game"] ? all["palette"].reject { |role, _rgba| (CONSTANTS[role] && Palette::ROLES.include?(CONSTANTS[role])) || GAME_GIVEN.include?(role) } : all["palette"]
              all.merge(each).merge("palette" => palette.merge(each["palette"] || {}), "game" => all["game"] || each["game"])
            end
            preset_from(table.merge("name" => spec["name"]))
          end
        end

        # Tells the colors a preset draws in: its own, and with the game's own look on its chain the
        # game's for the box colors it leaves out.
        #
        # @param preset [Preset] The preset.
        # @return [Hash{Symbol => Array<Integer>}] Each color by the constant's name.
        def self.colors_of(preset)
          preset.game ? game_colors.merge(preset.colors) : preset.colors
        end

        # Tells whether a preset is the game's own look as it is, drawn in the game's window skin.
        #
        # @param preset [Preset] The preset.
        # @return [Boolean] Whether it sets none of the box colors.
        def self.plain_game?(preset)
          preset.game && (preset.colors.keys & Palette::ROLES).empty?
        end

        # Tells the preset in use.
        #
        # @return [Preset] The preset.
        def self.current
          @preset || local_preset(nil)
        end

        # Tells whether the game's own look is in use, which leaves the windows to the game.
        #
        # @return [Boolean] Whether it is.
        def self.game?
          current.game
        end

        # Tells whether the game's windows wear the look, on until turned off, and always on without
        # the DLL, which keeps the setting.
        #
        # @return [Boolean] Whether they do.
        def self.game_windows?
          @game_windows = Settings.setting(GAME_WINDOWS_SETTING).to_s != "0" if @game_windows.nil?
          @game_windows
        end

        # Turns the look on the game's windows on or off and keeps it in the settings; every window
        # dresses anew on its next update.
        #
        # @param on [Boolean] Whether the game's windows wear the look.
        def self.dress_game_windows(on)
          @game_windows = on
          kept = Settings.store(GAME_WINDOWS_SETTING, on ? 1 : 0)
          log("the look on the game's windows is #{on ? 'on' : 'off'}#{kept ? '' : ', not kept'}")
        rescue => e
          log("keeping the look on the game's windows FAILED: #{e.class}: #{e.message}")
        end

        # Tells how often the colors changed, so a picture drawn in them knows to draw anew.
        #
        # @return [Integer] The count.
        def self.serial
          @serial
        end

        # Finds a preset by its name, ignoring case, as C# works it out, anew for the game's own look
        # once the window color changed; Monarch without the DLL.
        #
        # @param name [String, nil] The name.
        # @return [Preset] The preset, the first for an unknown name.
        def self.find(name)
          return local_preset(name) unless with_model?

          key = name.to_s.strip.downcase
          found = @found[key]
          found = @found[key] = worked_out(name) if found.nil? || (found.game && window_tone != @tone_handed)
          found
        end

        # Asks C# for the preset of a name and what it holds; with the game's own look on its chain,
        # in the box colors of the game's window now.
        #
        # @param name [String, nil] The name.
        # @return [Preset] The preset, the first for an unknown name.
        def self.worked_out(name)
          picked, refusal = ask(PICK_TOPIC, name.to_s.strip.empty? ? nil : name.to_s.strip)
          log_once([:pick, name.to_s], refusal) if refusal
          table = picked && ask(RESOLVE_TOPIC, picked)
          table = ask(RESOLVE_TOPIC, picked) if table && table["game"] && hand_game_colors
          table ? preset_from(table) : local_preset(name)
        end

        # Hands C# the box colors of the game's window in its window color once that changed, and
        # forgets what C# worked out in the colors before.
        #
        # @return [Boolean] Whether it handed them anew.
        def self.hand_game_colors
          tone = window_tone
          return false if tone == @tone_handed

          @tone_handed = tone
          @found.delete_if { |_key, preset| preset.game }
          @looks = {}
          @game_palette = nil
          refused = ask(GAME_TOPIC, Hash[game_colors.map { |constant, rgba| [CONSTANTS.key(constant), rgba] }])
          log_once(:game_colors, "the game's window colors were refused: #{refused}") if refused
          true
        end

        # Puts a preset to use: sets Style's box colors to it in place and counts the change.
        #
        # @param name [String, nil] The preset's name, the first preset's for an unknown one.
        # @param why [String] What chose it, for the log.
        def self.apply(name, why)
          preset = find(name)
          @preset = preset
          @tone_seen = preset.game ? window_tone : nil
          set_colors(colors_of(preset))
          set_roles(preset)
          Serials.bump(:theme) if defined?(Serials)
          log("interface look #{preset.name} (#{why})")
        rescue => e
          log("interface look #{name} FAILED: #{e.class}: #{e.message}")
        end

        # Sets Style's box colors in place and counts the change.
        #
        # @param colors [Hash{Symbol => Array<Integer>}] Each color by the constant's name.
        def self.set_colors(colors)
          colors.each do |constant, (red, green, blue, alpha)|
            color = Style.const_get(constant)
            color.red, color.green, color.blue, color.alpha = red, green, blue, alpha
          end
          @serial += 1
        end

        # Sets the colors of the player's preset's color names that are none of Style's in place and
        # lets go of those it does not hold.
        #
        # @param preset [Preset] The preset.
        def self.set_roles(preset)
          @live_roles.delete_if { |name, _color| !preset.roles.key?(name) }
          preset.roles.each do |name, (red, green, blue, alpha)|
            color = (@live_roles[name] ||= Color.new(0, 0, 0, 0))
            color.red, color.green, color.blue, color.alpha = red, green, blue, alpha
          end
        end

        # Finds the color of a color name of the player's preset that is none of Style's.
        #
        # @param name [Symbol] The name, such as :primary or a mod's :quest.
        # @return [Color, nil] The color, nil for none.
        def self.live_role(name)
          @live_roles[name]
        end

        # Tells a size of the player's preset: of a typography name, its spacing unit or a row.
        #
        # @param typo [Symbol] The typography name, such as :h6.
        # @return [Integer, nil] The pixels, nil for none.
        def self.typo_size(typo)
          Serials.read(:theme) if defined?(Serials)
          (current.typography || {})[typo.to_s]
        end

        # Tells the pixels of one unit of spacing of the player's preset.
        #
        # @return [Integer] The pixels.
        def self.spacing
          current.spacing || 4
        end

        # Tells the height of a normal and of a dense row of the player's preset.
        #
        # @return [Array<Integer>] The two heights.
        def self.rows
          current.rows || [UI::LINE_HEIGHT, UI::SMALL_LINE_HEIGHT]
        end

        # Tells the look of a button's variant in a color, as C# works it out, in a palette's preset:
        # each of :fill, :edge, :text, :lit and :focus a color name of the palette, a Color, an
        # animated color name lightened toward white (Lifted) or nil.
        #
        # @param palette [Palette] The palette.
        # @param variant [Symbol] :filled, :outlined or :text.
        # @param color [Symbol, Color, nil] The button's color.
        # @param text_color [Symbol, Color, nil] The button's own text color, nil for the preset's.
        # @return [Hash, nil] The look, nil without the DLL.
        def self.button_look(palette, variant, color, text_color = nil)
          return nil unless with_model?

          preset = palette.preset || current
          key = [preset.name, variant, look_color(color), look_color(text_color)]
          return @looks[key] if @looks.key?(key)

          answer = ask(LOOK_TOPIC, [preset.name, variant.to_s, look_color(color), look_color(text_color)])
          @looks[key] = answer && Hash[answer.map { |slot, paint| [slot.to_sym, look_paint(paint)] }]
        end

        # Reads a color of a button's look as C# writes it.
        #
        # @param paint [String, Array, Hash, nil] A color name, [r, g, b, a], {"name", "lift"} or nil.
        # @return [Symbol, Color, Lifted, nil] The color.
        def self.look_paint(paint)
          return paint.to_sym if paint.is_a?(String)
          return Lifted.new(paint["name"].to_sym, paint["lift"].to_i) if paint.is_a?(Hash)

          paint && Color.new(*paint)
        end

        # Writes a button's color for C#: a color name as a text, a Color as an Array.
        #
        # @param color [Symbol, Color, nil] The color.
        # @return [String, Array, nil] The color.
        def self.look_color(color)
          color.is_a?(Symbol) ? color.to_s : plain_color(color)
        end

        # Puts the preset the player picked to use and keeps it in the settings.
        #
        # @param name [String] The preset's name.
        def self.choose(name)
          apply(name, "picked in Options > Mods")
          log("the interface look is not kept") unless Settings.store(SETTING, @preset.name)
        rescue => e
          log("keeping the interface look FAILED: #{e.class}: #{e.message}")
        end

        # Puts the preset the settings keep to use, the first until the player picked one and always
        # without the DLL.
        def self.load
          stored = Settings.setting(SETTING)
          why = stored ? "kept in the settings" : Mod_Framework.available? ? "the default" : "the default without the DLL"
          apply(stored, why)
        end

        # Works the game's look out anew once the game's window color changed, through its options, a
        # save loaded or an event. Called after every Graphics.update.
        def self.follow_game
          return unless game?
          return if window_tone == @tone_seen

          @tone_seen = window_tone
          @preset = find(@preset.name)
          set_colors(colors_of(@preset))
          set_roles(@preset)
          log("interface look follows the window color #{@tone_seen.join(', ')}")
        rescue => e
          log_once(:follow_game, "following the window color FAILED: #{e.class}: #{e.message}")
        end

        # Keeps the window color of the game's options once it changed, and puts it on the game's
        # windows as the game's own options do. Called after every Graphics.update.
        #
        # A plugin's Options > Default, such as the translation's, resets the options' values without
        # the game's tone_refresh, so the options' values are read rather than one method followed.
        def self.notice_window_color
          conf = game_options
          return unless conf

          unless $game_system.equal?(@system_seen)
            @system_seen = $game_system
            @color_seen = COLOR_KEYS.map { |key| conf[key] }
            return
          end
          return unless window_color_changed?(conf)

          @color_seen = COLOR_KEYS.map { |key| conf[key] }
          keep_window_color
          color = @color_seen.map { |value| value.to_i }
          log("window color #{color.join(', ')} of the options put on") if wear_window_color(color)
        rescue => e
          log_once(:notice_color, "following the options' window color FAILED: #{e.class}: #{e.message}")
        end

        # Tells whether the window color of the game's options differs from the one last read.
        #
        # @param conf [Hash] The game's options.
        # @return [Boolean] Whether it changed.
        def self.window_color_changed?(conf)
          COLOR_KEYS.each_with_index { |key, at| return true unless conf[key] == @color_seen[at] }
          false
        end

        # Finds the game's options, which hold the window color the player set.
        #
        # @return [Hash, nil] The options, nil before the game's objects were made.
        def self.game_options
          $game_system && $game_system.respond_to?(:conf) ? $game_system.conf : nil
        end

        # Keeps the window color the player set in the game's options in the settings, for every save
        # of this install.
        def self.keep_window_color
          conf = game_options
          return unless conf

          color = COLOR_KEYS.map { |key| conf[key].to_i }
          return if color == stored_window_color
          return unless Settings.store(COLOR_SETTING, color.join(","))

          log("window color #{color.join(', ')} kept for every save")
        rescue => e
          log_once(:keep_color, "keeping the window color FAILED: #{e.class}: #{e.message}")
        end

        # Puts the window color the settings keep into the game, so every save of this install shows
        # it; until the player set one in the options, each save keeps its own.
        #
        # @param why [String] What happened, for the log.
        def self.restore_window_color(why)
          color = stored_window_color
          return unless color && $game_system

          conf = game_options
          COLOR_KEYS.each_with_index { |key, at| conf[key] = color[at] } if conf
          log("window color #{color.join(', ')} from the settings put on #{why}") if wear_window_color(color)
        rescue => e
          log_once(:restore_color, "putting the window color on FAILED: #{e.class}: #{e.message}")
        end

        # Puts a window color on the game's windows, as the game's options do.
        #
        # @param color [Array<Integer>] Red, green and blue.
        # @return [Boolean] Whether the windows wore another color before.
        def self.wear_window_color(color)
          return false if window_tone[0, 3] == color.map { |value| value.to_f }

          $game_system.window_tone = Tone.new(*color)
          true
        end

        # Reads the window color the settings keep.
        #
        # @return [Array<Integer>, nil] Red, green and blue, nil until the player set one.
        def self.stored_window_color
          parts = Settings.setting(COLOR_SETTING).to_s.split(",").map { |part| part.strip }
          return nil unless parts.size == COLOR_KEYS.size && parts.all? { |part| part =~ /\A-?\d+\z/ }

          parts.map { |part| UI.within(part.to_i, -255, 255) }
        end

        # Reads the game's window color.
        #
        # @return [Array<Float>] Red, green, blue and gray, all 0 before the game's data loaded.
        def self.window_tone
          tone = window_tone_object
          tone ? [tone.red, tone.green, tone.blue, tone.gray] : [0.0, 0.0, 0.0, 0.0]
        end

        # Finds the game's window color as the game keeps it, without reading its values, which
        # makes a Float of each in the game's Ruby.
        #
        # @return [Tone, nil] The tone, nil before the game's data loaded.
        def self.window_tone_object
          $game_system ? $game_system.window_tone : ($data_system && $data_system.window_tone)
        end

        # Works out Style's box colors from the game's window skin in the game's window color: the
        # background and its shades, the frame's line and rim, the palette's text colors.
        #
        # @return [Hash{Symbol => Array<Integer>}] Each color by the constant's name.
        def self.game_colors
          skin = Cache.system(GAME_SKIN)
          back = toned(average(skin, *SKIN_BACK), window_tone)
          rim, edge = frame_line(skin)
          cursor = skin.get_pixel(SKIN_CURSOR[0] + SKIN_CURSOR[2] / 2, SKIN_CURSOR[1] + SKIN_CURSOR[3] / 2)
          picked = mix(back, [cursor.red, cursor.green, cursor.blue], PICKED_LIFT)
          heading = rgb(skin.get_pixel(*SKIN_SYSTEM_COLOR))
          title = rgb(skin.get_pixel(*SKIN_NORMAL_COLOR))
          { :BACK => back + [GAME_BACK_OPACITY], :PLATE => back + [GAME_BACK_OPACITY - 32], :PICKED => picked + [230], :FIELD => mix(back, [0, 0, 0], 0.6) + [255],
            :HEADING => heading + [255], :EDGE => edge + [230], :TRACK => mix(back, [255, 255, 255], 0.15) + [GAME_BACK_OPACITY + 8],
            :RIM => rim + [255], :TITLE => title + [255], :WELL => mix(back, [0, 0, 0], 0.5) + [220],
            :TAB => mix(edge, [0, 0, 0], 0.7) + [GAME_BACK_OPACITY] }
        end

        # Averages a skin's area, from samples SAMPLE_STEP apart.
        #
        # @param skin [Bitmap] The skin.
        # @param x [Integer] The area's left.
        # @param y [Integer] The area's top.
        # @param width [Integer] The area's width.
        # @param height [Integer] The area's height.
        # @return [Array<Integer>] Red, green and blue.
        def self.average(skin, x, y, width, height)
          sum = [0, 0, 0]
          count = 0
          (y...y + height).step(SAMPLE_STEP) do |row|
            (x...x + width).step(SAMPLE_STEP) do |column|
              pixel = skin.get_pixel(column, row)
              sum = [sum[0] + pixel.red, sum[1] + pixel.green, sum[2] + pixel.blue]
              count += 1
            end
          end
          sum.map { |part| (part / count).round }
        end

        # Reads the frame's rim and line down the middle of the frame square's top border: the
        # outermost pixel is the rim, the brightest the line.
        #
        # @param skin [Bitmap] The skin.
        # @return [Array(Array<Integer>, Array<Integer>)] The rim's and the line's red, green and blue.
        def self.frame_line(skin)
          column = SKIN_FRAME[0] + SKIN_FRAME[2] / 2
          pixels = (SKIN_FRAME[1]...SKIN_FRAME[1] + SKIN_BORDER).map { |row| skin.get_pixel(column, row) }.select { |pixel| pixel.alpha > 0 }
          [rgb(pixels.first), rgb(pixels.max_by { |pixel| pixel.red + pixel.green + pixel.blue })]
        end

        # Reads a pixel's red, green and blue as whole numbers, since RGSS answers Floats, which the
        # bridge refuses.
        #
        # @param pixel [Color] The pixel.
        # @return [Array<Integer>] Red, green and blue.
        def self.rgb(pixel)
          [pixel.red, pixel.green, pixel.blue].map { |part| part.to_i }
        end

        # Colors a skin's color as a window's tone does: grays it, then adds the tone's red, green and
        # blue.
        #
        # @param color [Array<Integer>] Red, green and blue.
        # @param tone [Array<Float>] The tone's red, green, blue and gray.
        # @return [Array<Integer>] The colored red, green and blue.
        def self.toned(color, tone)
          gray = color.inject(:+) / 3.0
          color.each_with_index.map do |part, index|
            grayed = part + (gray - part) * tone[3] / 255.0
            [[grayed + tone[index], 0].max, 255].min.round
          end
        end

        # Moves one color towards another.
        #
        # @param from [Array<Integer>] Red, green and blue.
        # @param to [Array<Integer>] Red, green and blue.
        # @param share [Float] How far, from 0 to 1.
        # @return [Array<Integer>] The color between.
        def self.mix(from, to, share)
          from.zip(to).map { |a, b| (a + (b - a) * share).round }
        end

        # Finds the preset a theme names: nil and true name the player's, false the game's own look,
        # and :game the look the game's own windows wear: the player's while Look on Game Windows is
        # On, else the game's own look.
        #
        # @param theme [nil, Boolean, Symbol, String, Preset, Palette] The theme, as a window or
        #   component carries it; a palette names its preset.
        # @return [Preset] The preset.
        def self.preset_of(theme)
          return current if theme.nil? || theme == true
          return find(GAME_LOOK) if theme == false
          return game_windows? ? current : find(GAME_LOOK) if theme == GAME_WINDOWS
          return theme if theme.is_a?(Preset)
          return theme.preset || current if theme.is_a?(Palette)

          find(theme)
        end

        # Hands out the colors a theme draws in, for a part drawn in another preset than the player's.
        #
        # @param theme [nil, Boolean, Symbol, String, Preset, Palette] The theme: nil and true for the
        #   player's preset, false for the game's own look, :game for the look the game's own windows
        #   wear, a preset or its name, or the colors themselves, as a filled part hands them to what
        #   it holds.
        # @return [Palette] The palette; Palette.live for the player's preset.
        def self.palette(theme)
          return theme if theme.is_a?(Palette)

          preset = preset_of(theme)
          return Palette.live if preset.equal?(current)
          return game_palette(preset) if preset.game

          @palettes[preset] ||= Palette.of(preset)
        end

        # Hands out the greyed colors of what a game window wears: its preset's, else the game's own
        # look.
        #
        # @param window [Window] The window.
        # @return [GreyedPalette] The palette.
        def self.greyed_for(window)
          palette_for(window).greyed
        end

        # Hands out the colors a game window wears: its preset's, else the game's own look.
        #
        # @param window [Window] The window.
        # @return [Palette] The palette.
        def self.palette_for(window)
          palette(worn(window.ui_theme) || false)
        end

        # Hands out a preset with the game's own look on its chain as a palette, worked out anew once
        # the window color changed.
        #
        # @param preset [Preset] The preset.
        # @return [Palette] The palette.
        def self.game_palette(preset)
          tone = window_tone
          @game_palette = [tone, preset, Palette.of(preset)] unless @game_palette && @game_palette[0] == tone && @game_palette[1].equal?(preset)
          @game_palette[2]
        end

        # Hands out the window skin of a palette's preset, painted once per preset; the game's own skin
        # for the game's look.
        #
        # @param palette [Palette] The palette.
        # @return [Bitmap] The skin.
        def self.skin_for(palette)
          preset = palette.preset || current
          return Cache.system(GAME_SKIN) if plain_game?(preset)

          skin = @skins[preset]
          @skins[preset] = skin = paint_skin(palette) if skin.nil? || skin.disposed?
          skin
        end

        # Hands out the window skin of the player's preset.
        #
        # @return [Bitmap] The skin.
        def self.skin
          skin_for(Palette.live)
        end

        # Paints a window skin in a palette: the background opaque, since the window's back_opacity
        # carries its alpha, no pattern, the frame as a box's (Style.draw_frame) along the borders, and
        # the cursor as a picked row in its frame; the rest is the game's own skin.
        #
        # @param palette [Palette] The colors.
        # @return [Bitmap] The skin.
        def self.paint_skin(palette)
          skin = Bitmap.new(SKIN_SIDE, SKIN_SIDE)
          base = Cache.system(GAME_SKIN)
          skin.blt(0, 0, base, base.rect)
          back = palette.back
          skin.clear_rect(*SKIN_BACK)
          skin.fill_rect(*(SKIN_BACK + [Color.new(back.red, back.green, back.blue, 255)]))
          skin.clear_rect(*SKIN_PATTERN)
          paint_frame(skin, palette)
          skin.clear_rect(*SKIN_CURSOR)
          skin.fill_rect(*(SKIN_CURSOR + [palette.picked]))
          Style.draw_frame(skin, *(SKIN_CURSOR + [nil, palette]))
          skin
        end

        # Paints the frame's square of a window skin: clears its borders, keeping the scroll arrows in
        # its middle, and draws a box's frame along them.
        #
        # @param skin [Bitmap] The skin.
        # @param palette [Palette] The colors.
        def self.paint_frame(skin, palette)
          x, y, side = SKIN_FRAME[0], SKIN_FRAME[1], SKIN_FRAME[2]
          border = SKIN_BORDER
          skin.clear_rect(x, y, side, border)
          skin.clear_rect(x, y + side - border, side, border)
          skin.clear_rect(x, y + border, border, side - 2 * border)
          skin.clear_rect(x + side - border, y + border, border, side - 2 * border)
          Style.draw_frame(skin, x, y, side, side, nil, palette)
        end

        # Tells the preset a window wears by its theme, nil for the game's own skin and tone.
        #
        # @param theme [nil, Boolean, String, Preset] The window's theme.
        # @return [Preset, nil] The preset, nil for the game's own look.
        def self.worn(theme)
          return nil if theme.nil? && !game_windows?

          preset = preset_of(theme)
          plain_game?(preset) ? nil : preset
        end

        # Dresses a window by its theme (ui_theme): nil and :game wear the player's preset while Look
        # on Game Windows is On, else the game's skin; true the player's preset always; false the
        # game's skin and window color; a preset or its name that preset. A preset's skin wears no tone, which would
        # tint it; a window with a theme of its own also takes its look's background alpha as its
        # back_opacity. The skin changes once per change of what the window wears; the tone every
        # time, since the game sets it on every update.
        #
        # @param window [Window] The window.
        def self.dress(window)
          return if window.disposed?

          theme = window.ui_theme
          preset = worn(theme)
          own = !(theme.nil? || theme == false || theme == GAME_WINDOWS)
          look = palette(theme) if preset || own
          wear_skin(window, preset, look)
          window.back_opacity = look.back.alpha.to_i if own
          # Tone#set makes 16 objects from four numbers in the game, none from a Tone.
          window.tone.set(SpriteSurface.untoned) if preset
          window.wear_own_look if window.respond_to?(:wear_own_look)
        rescue => e
          log_once([:dress, window.class], "dressing a #{window.class} FAILED: #{e.class}: #{e.message}")
        end

        # Gives a window the skin of what it wears, only when that changed since its last dress.
        #
        # A skin a window sets itself after its initialize stays until then, so a mod keeps its own.
        #
        # @param window [Window] The window.
        # @param preset [Preset, nil] The preset it wears, nil for the game's own look.
        # @param look [Palette, nil] The preset's palette.
        def self.wear_skin(window, preset, look)
          return if window.instance_variable_defined?(:@mf_worn) && window.instance_variable_get(:@mf_worn).equal?(preset)

          window.instance_variable_set(:@mf_worn, preset)
          window.windowskin = preset ? skin_for(look) : Cache.system(GAME_SKIN)
        end

        # Puts the look to use as the game starts running and dresses every window from then on, with
        # the DLL or without it.
        def self.start
          load
          Hooks.after(::Window_Base, :initialize, "Mod Framework theme") { |*_args| Mod_Framework::UI::Engine::Theme.dress(self) }
          Hooks.after(::Window_Base, :update, "Mod Framework theme") { Mod_Framework::UI::Engine::Theme.dress(self) }
          Hooks.outermost(Graphics.singleton_class, :update, :after, "Mod Framework theme") { Mod_Framework::UI::Engine::Theme.follow_game }
        end

        # Offers the look as rows of Options > Mods and keeps the game's window color for every
        # save, which both need the DLL, since it keeps the settings.
        def self.start_settings
          follow_window_color

          added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, lambda { names }, lambda { current.name }, lambda { |name| choose(name) })
          Options.keep(GAME_WINDOWS_OPTION, Options::GROUP + GAME_WINDOWS_OPTION_NAME, GAME_WINDOWS_OPTION_HELP, lambda { [ON, OFF] },
                       lambda { game_windows? ? ON : OFF }, lambda { |value| dress_game_windows(value == ON) })
          log(added ? "added the interface look to Options > Mods" : "no interface look in Options > Mods, see the options lines")
        end

        # Keeps the window color the player sets in the game's options apart and puts it back whenever
        # the game makes its objects anew, as it starts and for a new game, and on every save loaded.
        def self.follow_window_color
          Hooks.outermost(Graphics.singleton_class, :update, :after, "Mod Framework window color") { Mod_Framework::UI::Engine::Theme.notice_window_color }
          Hooks.after(DataManager.singleton_class, :create_game_objects, "Mod Framework theme") { Mod_Framework::UI::Engine::Theme.restore_window_color("the game's objects made anew") }
          Hooks.after(DataManager.singleton_class, :load_game_without_rescue, "Mod Framework theme") { |_index| Mod_Framework::UI::Engine::Theme.restore_window_color("the save loaded") }
        end

        Run.on_start("theme") { Mod_Framework::UI::Engine::Theme.start }
        Run.on_start("look rows and window color", :dll => true) { Mod_Framework::UI::Engine::Theme.start_settings }
      end

      # Marks a window class whose windows wear the player's preset whatever Look on Game Windows
      # says, with its background alpha as their back_opacity: include it, or set ui_theme on a
      # window.
      module Themed
        # Tells the window's theme: true unless the window was given another.
        #
        # @return [nil, Boolean, String, Theme::Preset] The theme.
        def ui_theme
          @ui_theme.nil? ? true : @ui_theme
        end
      end
    end
  end
end

# Every window carries the theme it wears, nil until a mod gives it one; see Theme.dress.
if defined?(::Window_Base)
  class ::Window_Base
    # @return [nil, Boolean, String, Mod_Framework::UI::Engine::Theme::Preset] The window's theme: nil
    #   for the game's rule, true for the player's preset, false for the game's own look, or a
    #   preset or its name.
    attr_accessor :ui_theme
  end
end
