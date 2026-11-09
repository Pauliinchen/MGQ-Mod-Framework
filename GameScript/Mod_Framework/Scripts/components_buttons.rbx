#----------------------------------------------------------------
#  components_buttons.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Let a button's padding replace the room around its text and drew a border it was given in place of its plate's edge
#      Paulinchen  2026-11-07: Wrote the text of a filled button in the plain text color unless it has contrast
#                            - Outlined the text of a filled button as its part asks, black by default
#                            - Gave a button a small and a large size
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What a Button and an IconButton share: a plate picked while hovered, pressed or focused (with
      # :flat no plate at all otherwise), greyed out while it takes no input, a hotkey that clicks it
      # while its root takes input (a key code, the action of a hotkey of Hotkeys, or an Array of them,
      # any of which clicks it), and :closes, which closes its root after its click blocks ran. A
      # click plays the confirm sound unless nothing answers it or it is :quiet, such as a button whose
      # block plays the game's own sound. :chosen draws it as the one chosen
      # among others, in a bright frame on its plain plate, and :focused picked and framed as focused
      # instead, as when the row it stands in has the focus.
      module Pressable
        # The options every pressable component takes, with their defaults.
        DEFAULTS = { :icon => nil, :icon_file => nil, :hotkey => nil, :closes => false, :flat => false, :chosen => false, :quiet => false }

        # How thick the bright frame of the one chosen among others is.
        CHOSEN_FRAME = 2

        # The key codes of a component without a hotkey.
        NO_CODES = [].freeze

        # The defaults a pressable class adds to its component's.
        module ClassMethods
          # Tells the defaults of the options, the pressable's added.
          #
          # @return [Hash] The defaults.
          def defaults
            super.merge(Pressable::DEFAULTS)
          end

          # Tells which properties of C#'s tree each option sets: :closes answers a click.
          #
          # @return [Hash{Symbol => Array<String>}] The properties by option.
          def node_keys
            super.merge(:closes => ["quiet"], :quiet => ["quiet"])
          end
        end

        # Makes a class including it pressable.
        #
        # @param base [Class] The component class.
        def self.included(base)
          base.extend(ClassMethods)
          base.options(*DEFAULTS.keys)
        end

        # Makes the component and watches its hotkey.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          watch_hotkey
        end

        # Takes an event of C#'s tree: after a click's blocks it closes its root with :closes.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          super
          root.close(:button) if name == "click" && @options[:closes] && root.open?
        end

        # Tells the properties C#'s tree routes input by, whether a click on it plays no sound added.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["quiet"] = quiet?
          props
        end

        # Runs a block on an event; a click block makes a click on it sound.
        #
        # @param name [Symbol] The event.
        # @yield [*values] Runs on the event with its values.
        # @return [Component] Itself.
        def on(name, &block)
          super
          Tree.set(self, "quiet" => quiet?) if name.to_sym == :click
          self
        end

        # Drops every block of an event; with the last click block gone a click on it is quiet.
        #
        # @param name [Symbol] The event.
        # @return [Component] Itself.
        def off(name)
          super
          Tree.set(self, "quiet" => quiet?) if name.to_sym == :click
          self
        end

        # Tells whether a click on it plays no sound: it is :quiet, or nothing answers the click (no
        # click block, no :closes and no receive of its own class).
        #
        # @return [Boolean] Whether it plays none.
        def quiet?
          return true if @options[:quiet]

          blocks = @handlers[:click]
          (blocks.nil? || blocks.empty?) && !@options[:closes] && method(:receive).owner == Pressable
        end

        # Tells the key codes of its hotkey: each key code given, and the key bound to each hotkey of
        # Hotkeys given, worked out anew once the hotkey or the keys' serial changed.
        #
        # @return [Array<Integer>] Windows' codes of the keys, empty for none.
        def hotkey_codes
          hotkey = @options[:hotkey]
          return NO_CODES if hotkey.nil?

          serial = Serials.serial(:keys)
          return @hotkey_codes if @hotkey_codes && @codes_serial == serial && @codes_of.equal?(hotkey)

          @codes_serial = serial
          @codes_of = hotkey
          @hotkey_codes = Array(hotkey).map { |code| code.is_a?(Symbol) ? Hotkeys.code(code) : code }.select do |code|
            code.is_a?(Integer) && code >= Key::LOWEST && code <= Key::HIGHEST
          end
        end

        # Takes a press of its hotkey as a click, or plays the buzzer while it takes no input.
        def press_hotkey
          return Sound.play_buzzer unless enabled_here?

          Sound.play_ok unless quiet?
          receive("click")
        end

        private

        # Follows a changed option: a new hotkey is watched.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          watch_hotkey if name == :hotkey
        end

        # Has the DLL read its hotkey's keys from now on, so their first press counts.
        def watch_hotkey
          Key.watch(*hotkey_codes)
        end

        # Tells whether it shows as picked: hovered, pressed, focused or chosen in a row that has the
        # focus.
        #
        # @return [Boolean] Whether it does.
        def lit?
          hovered? || pressed? || focused? || @options[:chosen] == :focused ? true : false
        end

        # Tells whether it draws the bright frame of the one chosen among others: chosen in a row
        # that has no focus.
        #
        # @return [Boolean] Whether it does.
        def chosen_frame?
          @options[:chosen] == true
        end

        # Tells how opaque its icon and its text draw while it takes input.
        #
        # @return [Integer, nil] The opacity, nil for opaque.
        def content_opacity
          nil
        end

        # Tells whether it draws framed as focused: focused, or chosen in a row that has the focus.
        #
        # @return [Boolean] Whether it does.
        def framed_as_focused?
          focused? || @options[:chosen] == :focused
        end

        # Draws its plate: picked while lit, framed brighter while focused, in the bright frame of
        # chosen_frame?, greyed out while it takes no input; with :flat only while lit.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_plate(canvas)
          return if @options[:flat] && !(lit? && canvas.enabled?)

          if @options[:border].nil? || lit_by_edge?
            canvas.box(0, 0, canvas.width, canvas.height, :fill => plate_fill, :edge => canvas.enabled? && framed_as_focused? ? :title : nil)
          else
            canvas.fill(0, 0, canvas.width, canvas.height, plate_fill)
          end
          draw_chosen_frame(canvas) if chosen_frame?
        end

        # Tells whether the focus lights its edge now, which then shows in place of a border it was
        # given.
        #
        # @return [Boolean] Whether it does.
        def lit_by_edge?
          draws_enabled? && framed_as_focused?
        end

        # Draws a border it was given after what it draws, unless the focus lights its edge.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_border(canvas)
          super unless lit_by_edge?
        end

        # Tells how opaque its icon and its text draw: as content_opacity tells while it takes input,
        # whole while it is greyed out.
        #
        # @param canvas [Canvas] Where it draws.
        # @return [Integer, nil] The opacity, nil for opaque.
        def drawn_opacity(canvas)
          canvas.enabled? ? content_opacity : nil
        end

        # Draws the bright frame of the one chosen among others, CHOSEN_FRAME thick.
        #
        # @param canvas [Canvas] Where it draws.
        def draw_chosen_frame(canvas)
          CHOSEN_FRAME.times { |inset| canvas.outline(inset, inset, canvas.width - 2 * inset, canvas.height - 2 * inset, :system) }
        end

        # Tells the plate's color.
        #
        # @return [Symbol] A color of the theme.
        def plate_fill
          lit? && enabled_here? ? :picked : :tab
        end

        # Draws its icon, or the picture of its icon file, as large as an icon; a smaller picture, such
        # as the framework's thumbs, at its own size in the icon's middle, so it stays sharp.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The icon's left.
        # @param y [Integer] Its top.
        def draw_mark(canvas, x, y)
          return canvas.icon(@options[:icon], x, y, :opacity => drawn_opacity(canvas)) if @options[:icon]

          picture = UI.picture(@options[:icon_file])
          return unless picture
          return canvas.picture(picture, x, y, ICON_SIZE, ICON_SIZE) if picture.width >= ICON_SIZE || picture.height >= ICON_SIZE

          canvas.blt(x + (ICON_SIZE - picture.width) / 2, y + (ICON_SIZE - picture.height) / 2, picture)
        end

        # Tells whether it has an icon or an icon file.
        #
        # @return [Boolean] Whether it has.
        def marked?
          !@options[:icon].nil? || !@options[:icon_file].nil?
        end
      end

      # A text button with an optional icon before its text, both in its middle, in a :font_size and
      # a :color of its own, and a badge at its end: a count on a dark plate, "9+" above 9 and nothing
      # at 0, or a dot for true, in :badge_color (:gold by default). A button with a :badge keeps the
      # badge's room while it shows nothing, so its width never jumps.
      #
      # Events: click.
      #
      # With :show_key it draws its hotkey's key before its text, "Y: Accept", from its :hotkey (the
      # first one, a hotkey's action or a key code), and anew once the player binds another key.
      #
      # With :variant (:filled, :outlined or :text) it draws in the look the theme gives that variant
      # in its :color (Palette#button_look), else in the plate every pressable has, its text on a
      # filled plate without an outline. A :text_color of its own wins over both.
      #
      # :button_size (:small, :medium or :large) gives it the font and the room of MudBlazor's sizes.
      class Button < Component
        include TextSized
        include Pressable

        # The component's kind in C#'s tree.
        KIND = "button"

        # Room at either side of the text.
        PAD_X = Style::PAD + 2

        # Room above and below the text.
        PAD_Y = 2

        # The font, the room above and below the text and the room at either side by :button_size.
        SIZES = { :small => [:small, 1, Style::PAD], :medium => [:normal, PAD_Y, PAD_X], :large => [:large, 5, Style::PAD + 6] }

        # Tells the defaults of the options: no text, in the normal size and the plain text color.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:text => "", :font_size => :normal, :color => nil, :text_color => nil, :badge => nil, :badge_color => :gold, :show_key => false,
                      :variant => nil, :button_size => nil)
        end

        # Tells which properties of C#'s tree each option sets, the text's for its text, its size and
        # its mark.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:text => TextSized::PROPS, :icon => TextSized::PROPS, :icon_file => TextSized::PROPS, :font_size => TextSized::PROPS, :button_size => TextSized::PROPS, :badge => ["padding"],
                      :show_key => TextSized::PROPS, :hotkey => TextSized::PROPS, :declared_hotkey => TextSized::PROPS + ["hotkey"])
        end

        options :text, :font_size, :color, :badge, :badge_color, :show_key, :variant, :button_size

        # Sets its own text color, which wins over its :color and the theme's; reading it is
        # text_color, which every kind of button works out its own way.
        #
        # @param value [Symbol, Color, nil] The color, nil for none of its own.
        def text_color=(value)
          set_option(:text_color, value)
        end

        # Names the key of its hotkey, for :show_key: the key bound to its first hotkey action, or its
        # first key code, else to the hotkey the UI layer declared on it.
        #
        # @return [String, nil] The key's name, such as "Y"; nil without a hotkey.
        def key_label
          first = Array(@options[:hotkey]).first || @options[:declared_hotkey]
          return nil if first.nil?

          first.is_a?(Symbol) ? Hotkeys.label(first) : Options::Keys.name(first)
        end

        # Measures and draws it anew once the key its :show_key names changed, as after the player
        # bound another key. Called before every frame for the buttons of every open root.
        def follow_key
          return unless @options[:show_key]

          label = key_label
          return if label == @key_label

          @key_label = label
          relayout
        end

        # Draws its plate, then its icon and its text together in its middle, and its badge at its end.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          look = look_of(canvas)
          look ? draw_look(canvas, look) : draw_plate(canvas)
          text = measured_text
          mark = mark_room
          text_width = text.empty? ? 0 : canvas.text_width(text, text_px)
          _top, edge_right, _bottom, edge_left = edge_sides
          right = canvas.width - edge_right - badge_room
          left = edge_left + [(right - edge_left - mark - text_width) / 2, 0].max
          row = line_height
          top = (canvas.height - row) / 2
          draw_mark(canvas, left, top) if marked?
          canvas.text(left + mark, top, [right - left - mark, 1].max, row, text,
                      :color => look ? look_text(look) : text_color, :size => text_px, :cut => true, :opacity => drawn_opacity(canvas))
          badge = Badge.text_of(@options[:badge])
          Badge.draw_on(canvas, canvas.width - edge_right, top, row, badge, @options[:badge_color] || :gold) if badge
        end

        # Draws its plate in a look of the theme: its fill, its lit fill while lit, framed in its
        # edge or, while focused, its focus edge; only the edge where the look has no fill.
        #
        # @param canvas [Canvas] Where it draws.
        # @param look [Hash] The look, see Theme.button_look.
        def draw_look(canvas, look)
          shown = canvas.enabled?
          fill = shown && lit? && enabled_here? ? look[:lit] : look[:fill]
          edge = shown && framed_as_focused? ? look[:focus] : look[:edge]
          unless @options[:border].nil? || lit_by_edge?
            canvas.fill(0, 0, canvas.width, canvas.height, fill) if fill
            return
          end

          if fill
            canvas.box(0, 0, canvas.width, canvas.height, :fill => fill, :edge => edge)
          elsif edge
            canvas.outline(0, 0, canvas.width, canvas.height, edge)
          end
        end

        private

        # Tells the look the theme gives its :variant in its :color.
        #
        # @param canvas [Canvas] Where it draws.
        # @return [Hash, nil] The look, nil without a :variant or without the DLL.
        def look_of(canvas)
          @options[:variant] ? canvas.palette.button_look(@options[:variant], @options[:color], @options[:text_color]) : nil
        end

        # Tells its text's color in a look of the theme: the plain text color on a fill, else the
        # look's; the look's own also where its :text_color is set or contrast? asks for the text C#
        # picks for the fill.
        #
        # @param look [Hash] The look, see Theme.button_look.
        # @return [Symbol, Color] The color.
        def look_text(look)
          look[:fill] && !@options[:text_color] && !contrast? ? :text : look[:text]
        end

        # Tells the room its icon takes before its text.
        #
        # @return [Integer] The pixels, 0 without an icon.
        def mark_room
          marked? ? ICON_STEP : 0
        end

        # Tells the text it shows and C# measures: its key's name before its text with :show_key.
        #
        # @return [String] The text.
        def measured_text
          text = @options[:text].to_s
          label = @options[:show_key] ? key_label : nil
          label.to_s.empty? ? text : "#{label}: #{text}"
        end

        # Tells its text's color.
        #
        # @return [Symbol, Integer, Color, nil] Its :text_color, else its :color, else the text on its
        #   plate, nil for the plain text color where it draws no plate.
        def text_color
          @options[:text_color] || @options[:color] || plate_text
        end

        # Tells the text on its plate as it draws, see Component#text_on.
        #
        # @return [Symbol, Color, nil] The color, nil where it draws no plate.
        def plate_text
          @options[:flat] && !(lit? && enabled_here?) ? nil : text_on(plate_fill)
        end

        # Tells the pixels of its font: its size's, else its :font_size's.
        #
        # @return [Integer] The pixels.
        def text_px
          sized = SIZES[@options[:button_size]]
          UI.font_px(sized ? sized[0] : @options[:font_size])
        end

        # Tells the height of its text's line: its size's font's, else the normal line.
        #
        # @return [Integer] The pixels.
        def line_height
          sized = SIZES[@options[:button_size]]
          sized ? UI.line_height_of(sized[0]) : super
        end

        # Tells the room above and below its text, by its size.
        #
        # @return [Integer] The pixels.
        def pad_y
          sized = SIZES[@options[:button_size]]
          sized ? sized[1] : PAD_Y
        end

        # Tells the room at either side of its text, by its size.
        #
        # @return [Integer] The pixels.
        def pad_x
          sized = SIZES[@options[:button_size]]
          sized ? sized[2] : PAD_X
        end

        # Tells the room a badge takes at its end: kept while it has a :badge, though it shows nothing.
        #
        # @return [Integer] The room.
        def badge_room
          @options[:badge].nil? ? 0 : Badge::ROOM
        end

        # Tells the room around its text, by its size, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [pad_y, pad_x, pad_y, pad_x]
        end

        # Tells the room its icon takes at its left and its badge at its right.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def fixed_room
          [0, badge_room, 0, mark_room]
        end
      end

      # An icon alone as a button, with its tooltip. With no icon it is an empty well, a dim frame
      # where the icon would be, so an empty socket or slot still reads as a place.
      #
      # Events: click.
      class IconButton < Component
        include Pressable

        # The component's kind in C#'s tree.
        KIND = "icon_button"

        # Room around the icon.
        PAD = 2

        # Tells its size: an icon's.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          [ICON_SIZE, ICON_SIZE]
        end

        # Draws its plate and its icon in the middle, or the empty well there without one.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_plate(canvas)
          x = (canvas.width - ICON_SIZE) / 2
          y = (canvas.height - ICON_SIZE) / 2
          marked? ? draw_mark(canvas, x, y) : canvas.outline(x, y, ICON_SIZE, ICON_SIZE, :dim)
        end

        private

        # Tells the room around its icon, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [PAD, PAD, PAD, PAD]
        end
      end

      # Clicks the buttons whose hotkey went down in the frame, in every root that takes input: shown,
      # with no Dialog above it, while the tree did not act on the key itself. While a text field
      # types, only the buttons of its root click, and only by a key whose character it does not take,
      # such as a digit in a field that refuses digits.
      module ButtonHotkeys
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "components"

        # Clicks the buttons whose hotkey went down. Called before every Graphics.update.
        def self.press
          typing = TextField.typing
          roots = Tree.roots_now
          roots.each do |root|
            next unless root.shown? && !covered?(root, roots) && !(root.respond_to?(:held_under) && root.held_under)
            next if typing && !typing.root.equal?(root)

            press_in(root, typing)
          end
        rescue => e
          log_once([:press, e.class], "pressing the buttons by their hotkeys FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Tells whether a Dialog lies above a root, which then takes no input.
        #
        # @param root [Component] The root.
        # @param roots [Array<Component>] Every open root.
        # @return [Boolean] Whether one does.
        def self.covered?(root, roots)
          depth = root.z.to_i
          rank = root.rank.to_i
          roots.each do |other|
            next if other.equal?(root) || !other.modal? || !other.shown?

            z = other.z.to_i
            return true if z > depth || (z == depth && other.rank.to_i > rank)
          end
          false
        end

        # Clicks each shown pressable component a component holds, itself included, whose hotkey
        # went down.
        #
        # @param component [Component] The component.
        # @param typing [TextField, nil] The text field that types, nil for none.
        def self.press_in(component, typing)
          return unless component.visible?

          press_one(component, typing) if component.is_a?(Pressable)
          component.children.each { |child| press_in(child, typing) }
        end
        private_class_method :press_in

        # Clicks a pressable component once one of its hotkey's keys went down that neither C#'s tree
        # nor the typing text field took.
        #
        # @param button [Pressable] The component.
        # @param typing [TextField, nil] The text field that types, nil for none.
        def self.press_one(button, typing)
          button.follow_key if button.respond_to?(:follow_key)
          codes = button.hotkey_codes
          place = 0
          while place < codes.size
            code = codes[place]
            if Key.triggered?(code) && !Tree.taken?(code) && !(typing && typing.takes_key?(code))
              Hotkeys.note_fired(code)
              button.press_hotkey
              return
            end
            place += 1
          end
        end
        private_class_method :press_one
      end
    end

    Engine::Container.adds(:button) { |text, *rest| Engine::Button.new((rest[0] || {}).merge(:text => text)) }
    Engine::Container.adds(:icon_button) { |icon, *rest| Engine::IconButton.new((rest[0] || {}).merge(:icon => icon)) }

    Run.on_start("button hotkeys", :dll => true) do
      Hooks.outermost(Graphics.singleton_class, :update, :before, "Mod Framework button hotkeys") { Mod_Framework::UI::Engine::ButtonHotkeys.press }
    end
  end
end
