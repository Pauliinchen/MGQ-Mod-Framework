#----------------------------------------------------------------
#  components_fields.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Removed the filter a steered list took from a text field's text, which nothing used
#      Paulinchen  2026-11-09: Titled the letter pages of a text field by the caption of the nearest field it sits in
#                            - Kept a text field's room at its sides in its padding, which its padding replaces
#                            - Drew a text field's background and border in place of its well and frame, its frame lit while it types
#                            - Let a numeric field's padding set the room around its arrows
#      Paulinchen  2026-11-08: Showed the placeholder of an empty field while it types too
#      Paulinchen  2026-11-07: Let the completions stand for the whole text, shown under the field, as an autocomplete's matches
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A field the player types into, one line or several: while it has the focus the DLL takes what
      # is typed, with Shift, Caps Lock, AltGr, the dead keys and Ctrl+V, the game's buttons and the
      # hotkeys stay quiet, but for the buttons' hotkeys of its own root on a key it does not take
      # (takes_key?), and UI.typing? tells so; Enter, or a
      # key bound to confirm that it does not type, gives the text, Escape and the numpad's 0 leave the field. It keeps its text while another has the
      # focus. With no parent it is a root of its own, a field alone on the screen that leaves its
      # focus on the numpad's 0, or closes with :closable. steer has its arrows and Enter drive a list.
      # A character :allowed refuses plays the buzzer, unless :buzz is false, such as for digits
      # that are hotkeys of its window instead.
      # With :leave_sides a field of one line hands the focus to the part beside it by RIGHT with the
      # caret at the end of its text and LEFT at its start, as a row of buttons walks; coming back,
      # the caret stands at the end.
      #
      # caret and caret= read and set where typing goes on. :keys takes key names as well as codes,
      # "Alt+Up" claiming Up only with Alt held, and key tells the name as given. completions= shows a
      # short list over the field where its last word starts, which Up and Down move and Enter, Tab or
      # a click take, putting it in place of the last word; with :whole they stand for its whole text,
      # as an autocomplete's matches, show under it from its left and replace all of it. :font_size draws its text, caret and
      # placeholder in that font, the field as high as the font's lines. :read_only takes the focus
      # and shows its text but takes no typing. With :confirm_to_type the focus rests on it without
      # typing until confirm or a click starts it; Enter then keeps the text and cancel puts it back,
      # the focus staying; its help names the confirm key after its own :help, and its :typing_help
      # defaults to what Enter and the cancel keys do. In a root of the UI layer any field rests the
      # same way after the first cancel that stops its typing, until confirm or a click wakes it or
      # the focus leaves. A field of several lines ends its last line in "..." when its text runs past
      # them, its whole text its tooltip. A gamepad's confirm opens the game's letters for it in a
      # dialog, unless :letters is false, titled :letters_title, else the caption of the Field it sits in.
      #
      # Events: change (text), submit (text), key (code or name, a key it claims with :keys), focus,
      # blur, completion (index), complete (text, index), type, revert, refuse, cancelled (a cancel key
      # left a field that types, before the focus moves on), close (as a root).
      class TextField < Component
        include Root

        # The component's kind in C#'s tree.
        KIND = "text_field"

        # Its width as a root with no size.
        ROOT_WIDTH = 240

        # Its least width inside another component, which the stack it lies in stretches.
        MIN_WIDTH = 48

        # Room between its edge and its text.
        INSET = 4

        # Windows' codes of the keys it claims while it steers a list, with the rows each moves the
        # list's cursor by; nil stands for a page.
        STEER_KEYS = { 0x26 => -1, 0x28 => 1, 0x21 => nil, 0x22 => nil }

        # Frames an arrow is held before it moves a steered list's cursor again, as the game's own
        # lists wait before they repeat.
        REPEAT_WAIT = 24

        # Frames between the moves of a held arrow after that.
        REPEAT_STEP = 6

        # Frames after the left Alt is let go in which what arrives is dropped, as the numpad types
        # Alt codes while the left Alt, the framework's arranging key, is held.
        ALT_CODE_FRAMES = 3

        # Frames in which the character of the hotkey that opened a field may still arrive.
        ECHO_FRAMES = 4

        # Windows' codes of the keys a name in :keys may stand for, besides letters, digits and F keys.
        KEY_CODES = { "tab" => 0x09, "enter" => 0x0D, "esc" => 0x1B, "space" => 0x20, "pageup" => 0x21, "pagedown" => 0x22, "end" => 0x23, "home" => 0x24,
                      "left" => 0x25, "up" => 0x26, "right" => 0x27, "down" => 0x28, "delete" => 0x2E }

        # The bit of a claimed key that claims it only with Alt held, Node.AltFlag in C#.
        ALT_FLAG = 0x100

        # Windows' codes of Up, Down and Tab, which a field claims while it shows completions.
        COMPLETION_KEYS = { 0x26 => -1, 0x28 => 1, 0x09 => 0 }

        # The most completions shown at once.
        MOST_COMPLETIONS = 6

        # What a help line says while a field with :confirm_to_type types, with the keys that put the
        # text back, unless the field has a :typing_help of its own.
        TYPING_HELP = "Enter keeps the text; %s puts it back as it was."

        # What a field with :confirm_to_type adds to its :help while it does not type, with the key
        # that starts typing.
        START_HELP = "%s: type"

        # The field the player types into now, nil for none.
        @typing = nil

        # Windows' codes of the keys whose character takes_key? knows, with that character: the
        # letters, the digits and the numpad's digits.
        KEY_CHARACTERS = Hash[(0x41..0x5A).map { |code| [code, (code + 0x20).chr] } + (0x30..0x39).map { |code| [code, code.chr] } +
                              (0x60..0x69).map { |code| [code, (code - 0x30).chr] }]

        # The characters the keys F1 binds to the game's buttons may type: the letters, the space and
        # the numpad's 0.
        BOUND_CHARACTERS = "abcdefghijklmnopqrstuvwxyz 0"

        # Tells the defaults of the options: one empty line, taking any character, the buzzer on one
        # refused.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:text => "", :placeholder => nil, :lines => 1, :mask => nil, :max_length => nil, :allowed => nil, :keys => [], :buzz => true,
                      :leave_sides => false, :read_only => false, :confirm_to_type => false, :letters => true, :completion_index => 0, :typing_help => nil,
                      :font_size => :normal, :letters_title => nil, :whole => false)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:lines => ["rows", "measured", "min"], :keys => ["keys"], :min_size => ["min"], :leave_sides => ["leave_sides"], :allowed => ["takes"],
                      :read_only => ["takes"], :confirm_to_type => ["confirm_to_type"], :font_size => ["measured", "min"],
                      :placeholder => ["measured"])
        end

        options :text, :placeholder, :lines, :mask, :max_length, :allowed, :keys, :buzz, :leave_sides, :read_only, :confirm_to_type, :letters,
                :completion_index, :typing_help, :font_size, :letters_title, :whole

        # Tells the field the player types into now.
        #
        # @return [TextField, nil] The field, nil while none has the focus.
        def self.typing
          @typing
        end

        # Notes the field the player types into now.
        #
        # @param field [TextField, nil] The field, nil for none.
        def self.typing=(field)
          @typing = field
        end

        # Hands the field typed into the frame's keys, just before every tick.
        def self.follow
          field = @typing
          field.follow_frame if field
        end

        # Hands what typing did to the field typed into, after the text box took the event.
        #
        # @param event [Hash] The event, see EditModel.EventTopic.
        def self.take_edit(event)
          field = @typing
          field.edited if field && field.editor && field.editor.id == event["id"]
        rescue => e
          Tree.log_once([:take_edit, e.class], "a text field could not take what was typed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # @return [TextEdit, nil] The text box it types into while it has the focus.
        attr_reader :editor

        # @return [List, nil] The list it steers, nil for none.
        attr_reader :steered

        # Tells what it does, for a help line: its :help, followed with :confirm_to_type or while it
        # rests, while it does not type, by the key that starts typing.
        #
        # @return [String, nil] The help, nil for none.
        def help
          own = @options[:help]
          own = own.call if own.respond_to?(:call)
          return own unless (@options[:confirm_to_type] || @resting) && !@options[:read_only] && !TextField.typing.equal?(self)

          start = format(START_HELP, Game.key_name(:C))
          own.to_s.empty? ? start : "#{own} #{start}"
        end

        # Tells what a help line says while it types: its :typing_help, else with :confirm_to_type
        # what Enter and the cancel keys do.
        #
        # @return [String, Proc, nil] The help, nil for none.
        def typing_help
          own = @options[:typing_help]
          return own unless own.nil? && @options[:confirm_to_type]

          format(TYPING_HELP, UI.cancel_keys)
        end

        # Makes a field.
        #
        # @param options [Hash] Its options, see DEFAULTS and defaults.
        def initialize(options = {})
          super
          @options[:text] = @options[:text].to_s
          @editor = nil
          @resting = false
          @steered = nil
          @held = {}
        end

        # Sets its text; while it has the focus the cursor goes to the text's end.
        #
        # @param value [String] The text.
        def text=(value)
          text = value.to_s
          @caret = nil
          @editor.edit(text, text.length) if @editor
          set_option(:text, text)
        end

        # Tells where typing goes on: the caret's place in the text.
        #
        # @return [Integer] The characters before the caret.
        def caret
          @editor ? @editor.cursor.to_i : (@caret || @options[:text].to_s.length)
        end

        # Puts the caret at a place in the text, now while it types, else where typing starts.
        #
        # @param value [Integer] The characters before it, kept within the text.
        def caret=(value)
          text = (@editor ? @editor.text : @options[:text]).to_s
          @caret = UI.within(value.to_i, 0, text.length)
          @editor.edit(text, @caret) if @editor
          tell_caret
          redraw
        end

        # Lets go of the focus. A field that types stops at once, so the keys it held reach the game
        # and every mod's hotkeys in the same frame.
        #
        # @return [TextField] Itself.
        def blur
          stop_typing
          super
        end

        # Tells its tooltip: its own, else its whole text while its lines cut it.
        #
        # @return [String, #call, nil] The tooltip.
        def tooltip
          @options[:tooltip] || @cut_text
        end

        # Shows a short list of completions over it, where its last word starts; an empty list hides
        # it. Up and Down move the lit one, Enter, Tab or a click take it.
        #
        # @param list [Array<String>] The completions.
        def completions=(list)
          @completions = Array(list).map { |each| each.to_s }
          @options[:completion_index] = 0
          Tree.set(self, "keys" => claimed_keys)
          show_completions
        end

        # Tells the completions shown.
        #
        # @return [Array<String>] The completions, none while it shows none.
        def completions
          Array(@completions)
        end

        # Has its arrows, Page Up and Page Down move a list's cursor and its Enter pick the list's row
        # while it has the focus, as a search field over a list does; nil stops it.
        #
        # @param list [List, nil] The list.
        # @return [TextField] Itself.
        def steer(list)
          @steered.steered_by = nil if @steered
          @steered_log = defined?(LogView) && list.is_a?(LogView) ? list : nil
          @steered = list.is_a?(List) ? list : nil
          @steered.steered_by = self if @steered
          @held = {}
          Tree.set(self, "keys" => claimed_keys)
          self
        end

        # Tells whether the field takes what a key types: every key but a letter or a digit whose
        # character :allowed refuses.
        #
        # @param code [Integer] Windows' code of the key.
        # @return [Boolean] Whether it does.
        def takes_key?(code)
          character = KEY_CHARACTERS[code]
          allowed = @options[:allowed]
          character.nil? || !allowed.is_a?(Regexp) || [character, character.upcase].any? { |each| each =~ allowed } ? true : false
        end

        # Tells the properties C#'s tree lays it out and routes input by: its lines, the keys it
        # claims, its least size and the characters it types of the keys bound to cancel.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["rows"] = line_count
          props["keys"] = claimed_keys
          props["min"] = UI.pair(least_size)
          props["leave_sides"] = @options[:leave_sides] ? true : false
          props["caret_ends"] = caret_ends
          props["takes"] = takes
          props["confirm_to_type"] = @options[:confirm_to_type] ? true : false
          props["typing"] = @editor ? true : false
          props["tells_cancelled"] = listens?(:cancelled)
          props
        end

        # Runs a block on an event; a :cancelled block has C#'s tree tell the field when a cancel key
        # left it.
        #
        # @param name [Symbol] The event.
        # @yield [*values] Runs on the event.
        # @return [TextField] Itself.
        def on(name, &block)
          super
          Tree.set(self, "tells_cancelled" => listens?(:cancelled)) if name.to_sym == :cancelled
          self
        end

        # Tells the characters of the keys bound to the game's buttons it types, which C#'s field rule
        # reads to tell the cancel keys that leave it.
        #
        # @return [String] The characters.
        def takes
          BOUND_CHARACTERS.chars.select { |character| types?(character) }.join
        end

        # Tells whether it types a character, by :allowed; read only it types none.
        #
        # @param character [String] The character.
        # @return [Boolean] Whether it does.
        def types?(character)
          return false if @options[:read_only]

          allowed = @options[:allowed]
          !allowed.is_a?(Regexp) || [character, character.upcase].any? { |each| each =~ allowed } ? true : false
        end

        # Tells its size: as wide as a root's or the least width inside another component, which the
        # stack it lies in stretches, and never narrower than its placeholder; as high as its lines.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          placeholder = UI.text_width(UI.font_bitmap(text_px), @options[:placeholder].to_s) + Canvas::OUTLINE_ROOM
          [[(root? ? ROOT_WIDTH : MIN_WIDTH) - 2 * INSET, placeholder].max, line_count * row_height]
        end

        # Takes an event of C#'s tree: the focus starts and ends typing, rest ends it with the focus
        # kept until a click starts it again, a key it claims steers its list or goes to the key
        # blocks, and a gamepad's confirm or a key bound to confirm that it does not type gives the text.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          case name
          when "focus"
            start_typing unless @options[:confirm_to_type]
            @steered.redraw if @steered
          when "blur"
            @resting = false
            stop_typing
            @steered.redraw if @steered
          when "key"
            return press_key(values[0].to_i)
          when "submit"
            return @options[:letters] == false || @options[:read_only] ? submit_text : LetterPad.open(self)
          when "enter"
            return submit_text
          when "click"
            return begin_typing if (@options[:confirm_to_type] || @resting) && @editor.nil?
          when "rest"
            @resting = true
            stop_typing
            return tell_root(:typing_cancelled, self)
          when "revert"
            revert_typing
            return tell_root(:typing_cancelled, self)
          when "cancelled"
            return emit(:cancelled)
          end
          super
        end

        # Tells the caption the game's letters name it by: its :letters_title, else the caption of the
        # nearest Field it sits in, else its placeholder.
        #
        # @return [String] The caption.
        def caption
          return @options[:letters_title].to_s unless @options[:letters_title].nil?

          field = @parent
          field = field.parent while field && !field.is_a?(Field)
          field ? field.caption.to_s : @options[:placeholder].to_s
        end

        # Tells the text as it shows: a character of the mask for each of a masked text.
        #
        # @param text [String] The text.
        # @return [String] What shows.
        def shown_text(text)
          mask = @options[:mask].to_s
          mask.empty? ? text : mask * text.length
        end

        # Forgets its node, and stops typing once it left C#'s tree, which takes the focus along
        # without a blur.
        #
        # @param value [Integer, nil] The node id, nil once it left the tree.
        def node=(value)
          stop_typing if value.nil? && @editor
          super
        end

        # Hands the text box the frame's keys and repeats a held arrow on the list it steers. Called
        # just before every tick while it has the focus.
        def follow_frame
          return unless @editor

          @editor.follow(true)
          repeat_steer
        end

        # Takes what typing did: a changed text goes to the change blocks, Enter gives the text, a
        # character refused plays the buzzer with :buzz.
        def edited
          taken = @editor.take
          text = @editor.text.to_s
          if text != @options[:text]
            @options[:text] = text
            emit(:change, text)
          end
          redraw
          tell_caret
          Sound.play_buzzer if taken.outcomes.include?(:refused) && @options[:buzz]
          submit_text if taken.outcomes.include?(:enter)
          show_completions if @completions && !@completions.empty?
        end

        # Draws the field: its well in the theme's field color, framed brighter while it has the focus,
        # and the text being typed with its cursor, else its text; its placeholder while it is empty,
        # typing or not.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          draw_well(canvas, :field, @editor ? :title : :edge, !@editor.nil?)
          _top, right, _bottom, left = padding_sides
          width = [canvas.width - left - right, 1].max
          return draw_typing(canvas, width) if @editor

          text = @options[:text].to_s
          return draw_lines(canvas, width, [@options[:placeholder].to_s], :dim) if text.empty?

          shown = shown_text(text)
          Style.use_font(canvas.bitmap, text_px, Style::TEXT)
          lines = line_count > 1 ? UI.wrap(canvas.bitmap, shown, width) : [shown]
          cut = lines.size > line_count
          lines = UI.keep_lines(canvas.bitmap, lines, line_count, width)
          note_cut(cut && @options[:mask].to_s.empty? ? text : nil)
          draw_lines(canvas, width, lines, nil)
        end

        # Draws its well and frame: its background in place of the well, and its border in place of
        # the frame unless the frame lights it, which then shows in the frame's lit color.
        #
        # @param canvas [Canvas] Where it draws.
        # @param fill [Symbol] The well's color.
        # @param edge [Symbol, nil] The frame's edge color, nil for the theme's.
        # @param lit [Boolean] Whether its frame lights it.
        def draw_well(canvas, fill, edge, lit)
          canvas.background(0, 0, canvas.width, canvas.height, @options[:background].nil? ? fill : @options[:background])
          if @options[:border].nil? || lit
            canvas.frame(0, 0, canvas.width, canvas.height, edge)
          else
            canvas.border(0, 0, canvas.width, canvas.height, @options[:border], border_px, :of => shade_base)
          end
        end

        private

        # Tells the room at its sides, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [0, INSET, 0, INSET]
        end

        # Tells that it draws its background itself, in place of its well.
        #
        # @return [Boolean] Always true.
        def own_back?
          true
        end

        # Tells that it draws its border itself, in place of its frame.
        #
        # @return [Boolean] Always true.
        def own_edge?
          true
        end

        # Follows a changed option: a field that types locks its text box at once as it turns
        # read-only, and frees it as it turns back; a completion picked by a script lights at once.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          @editor.lock(@options[:read_only] ? true : false) if name == :read_only && @editor
          show_completions if name == :completion_index && !completions.empty?
        end

        # Tells how many lines it shows.
        #
        # @return [Integer] At least one.
        def line_count
          [@options[:lines].to_i, 1].max
        end

        # Tells its least size: its own, else MIN_WIDTH by its lines' height.
        #
        # @return [Array] Its width and height.
        def least_size
          @options[:min_size] || [MIN_WIDTH, line_count * row_height]
        end

        # Tells the pixels of its font.
        #
        # @return [Integer] The pixels.
        def text_px
          UI.font_px(@options[:font_size])
        end

        # Tells the height of one of its lines: its font's line.
        #
        # @return [Integer] The pixels.
        def row_height
          UI.line_height_of(@options[:font_size])
        end

        # Tells the keys it claims: its own, by code or by name, those of steering a list and those of
        # its completions while it shows some.
        #
        # @return [Array<Integer>] Windows' codes of the keys, ALT_FLAG set on those claimed with Alt.
        def claimed_keys
          own = Array(@options[:keys]).map { |key| key_code(key) }.compact
          steering = @steered || @steered_log ? STEER_KEYS.keys : []
          completing = completions.empty? ? [] : COMPLETION_KEYS.keys
          (own + steering + completing).uniq
        end

        # Reads a key of :keys: a code, or a name such as "Tab" or "Alt+Up", logged once when it is
        # neither.
        #
        # @param key [Integer, String] The key.
        # @return [Integer, nil] Windows' code of the key, ALT_FLAG set for one with Alt; nil for none.
        def key_code(key)
          return key if key.is_a?(Integer) && key >= Key::LOWEST && key <= Key::HIGHEST

          name = key.to_s.downcase.gsub(" ", "")
          alt = name.start_with?("alt+")
          name = name.sub(/\Aalt\+/, "")
          code = KEY_CODES[name] || (name =~ /\A[a-z0-9]\z/ ? name.upcase.ord : nil) || (name =~ /\Af(\d{1,2})\z/ && $1.to_i.between?(1, 12) ? 0x6F + $1.to_i : nil)
          unless code
            Tree.log_once([:key_name, key], "#{describe} names no key in #{key.inspect}, so it claims none for it")
            return nil
          end

          alt ? code | ALT_FLAG : code
        end

        # Puts the text and the caret back as they were before a field typed into only once confirmed
        # started, stops typing and tells revert.
        def revert_typing
          return unless @editor

          @editor.edit(@saved_text.to_s, @saved_text.to_s.length)
          stop_typing
          self.text = @saved_text.to_s
          emit(:revert)
        end

        # Starts typing a field typed into only once confirmed, as confirm or a click asks; when its
        # text box does not open it buzzes and tells refuse.
        def begin_typing
          start_typing
          return refuse_typing unless @editor

          emit(:type)
        end

        # Refuses to start typing with the buzzer, and tells refuse.
        def refuse_typing
          Sound.play_buzzer
          emit(:refuse)
        end

        # Keeps its whole text as its tooltip while its lines cut it, and tells C# it has one.
        #
        # @param text [String, nil] The whole text, nil when nothing was cut.
        def note_cut(text)
          return if text == @cut_text

          @cut_text = text
          Tree.set(self, "tooltip" => !tooltip.to_s.empty?)
        end

        # Shows its completions in a box over it, from where its last word starts, or hides them.
        def show_completions
          list = completions
          return hide_completions if list.empty? || @editor.nil? || @rect.nil?

          @completion_box ||= CompletionBox.new(self)
          @completion_box.show(list.first(MOST_COMPLETIONS), @options[:completion_index].to_i, completion_left, @options[:whole])
        end

        # Hides its completions.
        def hide_completions
          @completion_box.close if @completion_box && @completion_box.open?
        end

        # Tells where its last word starts on the screen, where its completions show; with :whole
        # its own left.
        #
        # @return [Integer] The left.
        def completion_left
          return @rect.x if @options[:whole]

          text = (@editor ? @editor.text : @options[:text]).to_s
          start = (text.rindex(" ") || -1) + 1
          bitmap = UI.font_bitmap(text_px)
          _top, right, _bottom, left = padding_sides
          @rect.x + left + [UI.text_width(bitmap, shown_text(text[0, start])), @rect.width - left - right].min
        end

        # Moves the lit completion, round, and tells completion.
        #
        # @param step [Integer] -1 up, 1 down.
        def move_completion(step)
          count = [completions.size, MOST_COMPLETIONS].min
          return if count == 0

          @options[:completion_index] = (@options[:completion_index].to_i + step) % count
          Sound.play_cursor
          show_completions
          emit(:completion, @options[:completion_index])
        end

        # Takes the lit completion, or one a click picked: it replaces the last word typed, as a chat's
        # completion does, or with :whole the whole text, which tells change, then complete; the
        # completions hide.
        #
        # @param index [Integer, nil] The completion picked, nil for the lit one.
        def take_completion(index = nil)
          place = index || @options[:completion_index].to_i
          text = completions[place]
          return unless text

          @completions = []
          Tree.set(self, "keys" => claimed_keys)
          hide_completions
          typed = (@editor ? @editor.text : @options[:text]).to_s
          self.text = @options[:whole] ? text : typed[0, (typed.rindex(" ") || -1) + 1] + text
          emit(:change, @options[:text])
          emit(:complete, text, place)
        end
        public :take_completion

        # Opens the text box with its text and options, holds the game's buttons and notes that it
        # types. Nothing types while the bridge is closed.
        def start_typing
          return if @editor

          editor = TextEdit.new(@options[:text].to_s, typing_options)
          return mod_log("#{describe} took the focus, but its text box did not open") unless editor.id

          @editor = editor
          @resting = false
          @saved_text = @options[:text].to_s
          editor.lock(true) if @options[:read_only]
          editor.edit(@options[:text].to_s, @caret) if @caret
          Tree.set(self, "typing" => true)
          @held = {}
          TextField.typing = self
          Capture.start(self)
          tell_root(:typing_changed)
          tell_caret
          redraw
        end

        # Tells whether the caret stands at the start of the text and at its end: while it types,
        # where its text box has it, else at the end, where typing starts.
        #
        # @return [Array<Boolean>] At the start, at the end.
        def caret_ends
          text = @editor ? @editor.text.to_s : @options[:text].to_s
          cursor = @editor ? @editor.cursor.to_i : text.length
          [cursor <= 0, cursor >= text.length]
        end

        # Tells the root it lies in what its typing did, when that root follows it, as one with
        # :captures => :typing does.
        #
        # @param name [Symbol] What happened: :typing_changed or :typing_cancelled.
        # @param values [Array] What it tells.
        # @return [nil] Always.
        def tell_root(name, *values)
          owner = root
          owner.__send__(name, *values) if !owner.equal?(self) && owner.respond_to?(name)
          nil
        end

        # Tells C# where the caret stands once that changed, for :leave_sides.
        def tell_caret
          ends = caret_ends
          return if ends == @told_caret

          @told_caret = ends
          Tree.set(self, "caret_ends" => ends)
        end

        # Closes the text box, keeping the text typed, and gives the game's buttons back.
        def stop_typing
          editor = @editor
          return unless editor

          @editor = nil
          @options[:text] = editor.text.to_s
          @caret = nil
          editor.close
          hide_completions
          Tree.set(self, "typing" => false)
          TextField.typing = nil if TextField.typing.equal?(self)
          Capture.stop(self)
          tell_root(:typing_changed)
          redraw
        end

        # Tells the text box's options from the field's, and what it never types: the Alt codes of the
        # numpad, and the character of a hotkey that went down just now, which opened it.
        #
        # @return [Hash] :max_chars, :allowed and :mask, as given, :alt_codes and :echo.
        def typing_options
          options = { :alt_codes => ALT_CODE_FRAMES }
          hotkey = Hotkeys.recent_key
          options[:echo] = [hotkey, ECHO_FRAMES] if hotkey
          options[:max_chars] = @options[:max_length].to_i if @options[:max_length]
          options[:allowed] = @options[:allowed] if @options[:allowed].is_a?(Regexp)
          options[:mask] = @options[:mask].to_s if @options[:mask]
          options
        end

        # Takes a key it claims: a steering key moves the list's cursor, its own goes to the key blocks.
        #
        # @param code [Integer] Windows' code of the key.
        def press_key(code)
          return completion_key(code) if !completions.empty? && COMPLETION_KEYS.key?(code)

          if @steered_log && STEER_KEYS.key?(code)
            rows = STEER_KEYS[code]
            rows ? @steered_log.scroll_by(-rows) : @steered_log.scroll_page(code == 0x21 ? -1 : 1)
          elsif @steered && STEER_KEYS.key?(code)
            @held[code] = 0
            step_steered(code)
          end
          given = Array(@options[:keys]).find { |key| key_code(key) == code }
          emit(:key, given) unless given.nil?
        end

        # Takes a key of its completions: Up and Down move the lit one, Tab takes it.
        #
        # @param code [Integer] Windows' code of the key.
        def completion_key(code)
          step = COMPLETION_KEYS[code]
          step == 0 ? take_completion : move_completion(step)
        end

        # Moves the steered list's cursor by a steering key: a row, or a page for Page Up and Down.
        #
        # @param code [Integer] Windows' code of the key.
        def step_steered(code)
          rows = STEER_KEYS[code]
          rows ||= (code == 0x21 ? -1 : 1) * [(@steered.scrolling ? @steered.scrolling[1] : List::SHOWN).to_i, 1].max
          @steered.step_cursor(rows)
        end

        # Moves the steered list's cursor again while an arrow stays held, as the game repeats a held
        # button.
        def repeat_steer
          return unless @steered

          @held.keys.each do |code|
            next @held.delete(code) unless STEER_KEYS[code] && Key.down?(code)

            @held[code] += 1
            frames = @held[code] - REPEAT_WAIT
            step_steered(code) if frames >= 0 && frames % REPEAT_STEP == 0
          end
        end

        # Gives the text: the steered list picks its cursor's row, else the submit blocks get the text.
        def submit_text
          return take_completion unless completions.empty?
          return @steered.submit_cursor if @steered

          stop_typing if @options[:confirm_to_type]
          emit(:submit, @options[:text].to_s)
        end

        # Draws the text being typed, with its cursor, where the text box shows it, over the placeholder
        # while nothing is typed.
        #
        # @param canvas [Canvas] Where it draws.
        # @param width [Integer] The text's room.
        def draw_typing(canvas, width)
          draw_lines(canvas, width, [@options[:placeholder].to_s], :dim) if @editor.text.to_s.empty?
          bitmap = canvas.bitmap
          Style.use_font(bitmap, text_px, canvas.text_color(:text))
          top, _right, bottom, left = padding_sides
          height = [canvas.height - top - bottom, 1].max
          if line_count > 1
            TextBox.draw_area(bitmap, canvas.area(left, top, width - Style::SCROLLBAR_WIDTH - 2, height), @editor, row_height)
          else
            TextBox.draw_line(bitmap, canvas.area(left, top, width, height), @editor, shown_text(@editor.text.to_s))
          end
        end

        # Draws lines of text from the top, as many as it shows, each cut to its width.
        #
        # @param canvas [Canvas] Where it draws.
        # @param width [Integer] The text's room.
        # @param lines [Array<String>] The lines.
        # @param color [Symbol, nil] Their color, nil for the plain text color.
        def draw_lines(canvas, width, lines, color)
          top, _right, _bottom, left = padding_sides
          lines.first(line_count).each_with_index do |line, row|
            canvas.text(left, top + row * row_height, width, row_height, line, :color => color, :size => text_px, :cut => true)
          end
        end
      end

      # A number the player types as into a text field, between arrows that step it, as MudBlazor's
      # numeric field: confirm or a click starts typing, and C#'s text box keeps the text a whole
      # number (NumberRule). Enter, a pad's confirm or the focus leaving takes the number within
      # :min and :max, and cancel puts it back. While it does not type, C#'s tree steps it by :step
      # within its bounds as LEFT and RIGHT, the wheel or a click on an arrow asks. An arrow dims at
      # its end; :arrows false shows none. :adornment is a text after the number, such as a unit.
      #
      # Events: change (number), submit (number, as confirm gave it), type, refuse, revert.
      class NumericField < TextField
        # The component's kind in C#'s tree.
        KIND = "numeric_field"

        # The arrows at either end.
        ARROWS = ["<", ">"]

        # Room at either side of the arrows.
        PAD_X = Style::PAD + 2

        # Room above and below it.
        PAD_Y = 2

        # The least width of the room between the arrows, so a short number does not make it tiny.
        MIN_ROOM = 40

        # What a help line says while it types, with the keys that put the number back, unless it has a
        # :typing_help of its own.
        TYPING_HELP = "Enter keeps the number; %s puts it back as it was."

        # Tells the defaults of the options: 0, stepped by 1, without bounds, with arrows, typed into
        # only once confirmed and without the game's letters.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:value => 0, :min => nil, :max => nil, :step => 1, :adornment => nil, :arrows => true, :confirm_to_type => true, :letters => false)
        end

        # Tells which properties of C#'s tree each option sets: the number, its bounds, its step and
        # its arrows, and other texts measure anew.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:value => ["number"], :min => ["number_min", "measured"], :max => ["number_max", "measured"], :step => ["number_step"],
                      :adornment => ["measured"], :arrows => ["number_arrows", "measured"], :padding => ["padding", "number_arrows"],
                      :border => ["padding", "number_arrows"], :border_width => ["padding", "number_arrows"])
        end

        options :value, :min, :max, :step, :adornment, :arrows

        # Tells what a help line says while it types: its :typing_help, else what Enter and the cancel
        # keys do.
        #
        # @return [String, Proc] The help.
        def typing_help
          own = @options[:typing_help]
          own.nil? ? format(TYPING_HELP, UI.cancel_keys) : own
        end

        # Lets go of the focus, taking the number typed first.
        #
        # @return [NumericField] Itself.
        def blur
          settle
          super
        end

        # Tells whether it types a character: digits only, none read only. A minus C#'s text box
        # takes by :min.
        #
        # @param character [String] The character.
        # @return [Boolean] Whether it does.
        def types?(character)
          !@options[:read_only] && character =~ /\A\d\z/ ? true : false
        end

        # Tells whether it takes what a key types: every key but a letter.
        #
        # @param code [Integer] Windows' code of the key.
        # @return [Boolean] Whether it does.
        def takes_key?(code)
          character = KEY_CHARACTERS[code]
          character.nil? || types?(character)
        end

        # Tells the properties C#'s tree steps it by and types it as a text field by, with the least
        # size every part has rather than a text field's.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props.update("number" => @options[:value].to_i, "number_min" => @options[:min], "number_max" => @options[:max],
                       "number_step" => [@options[:step].to_i, 1].max, "number_arrows" => arrow_room, "min" => UI.size(@options[:min_size]))
          props
        end

        # Tells its size: room for its widest number and its adornment between the arrows.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          widest = [@options[:min], @options[:max], @options[:value]].compact.map { |number| UI.text_width(bitmap, shown(number)) }.max.to_i
          [[widest, MIN_ROOM].max + (@options[:arrows] ? 2 * (arrow_width + Style::PAD) : 0), LINE_HEIGHT]
        end

        # Takes an event of C#'s tree: a number stepped, and the focus leaving, which takes the number
        # typed first; the rest as a text field takes them.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          case name
          when "number"
            @options[:value] = values[0].to_i
            redraw
            emit(:change, @options[:value])
          when "blur"
            settle
            super
          else super
          end
        end

        # Takes what typing did: a character refused buzzes, Enter takes the number.
        def edited
          taken = @editor.take
          redraw
          tell_caret
          Sound.play_buzzer if taken.outcomes.include?(:refused)
          submit_text if taken.outcomes.include?(:enter)
        end

        # Draws its field, picked while hovered or focused, its number between arrows and each arrow
        # dimmed at its end; while it types, the text typed with its caret and both arrows dimmed.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          live = enabled_here?
          typing = !@editor.nil?
          draw_well(canvas, !typing && (hovered? || focused?) && live ? :picked : :field, typing || focused? ? :title : nil, typing || focused?)
          top = (canvas.height - LINE_HEIGHT) / 2
          room = [canvas.width - 2 * side_room, 1].max
          value = @options[:value].to_i
          if live && @options[:arrows]
            canvas.text(side_room, top, room, LINE_HEIGHT, ARROWS[0], :color => typing || end?(value, :min) ? :dim : nil)
            canvas.text(side_room, top, room, LINE_HEIGHT, ARROWS[1], :align => :end, :color => typing || end?(value, :max) ? :dim : nil)
          end
          return draw_typed(canvas, top) if typing

          canvas.text(side_room, top, room, LINE_HEIGHT, shown(value), :align => :center, :cut => true)
        end

        private

        # Takes the number typed, as C#'s text box settles it within :min and :max, telling change
        # once it differs; a text that gives no number, such as an empty one, keeps the number.
        def settle
          number = @editor && @editor.number
          return if number.nil? || number == @options[:value]

          set_option(:value, number)
          emit(:change, number)
        end

        # Takes the number typed, stops typing and tells submit.
        def submit_text
          settle
          stop_typing
          emit(:submit, @options[:value])
        end

        # Opens the text box with typing_text as the text.
        def start_typing
          @options[:text] = typing_text unless @editor
          super
        end

        # Tells the text typing starts with: its number.
        #
        # @return [String] The text.
        def typing_text
          @options[:value].to_i.to_s
        end

        # Tells the text box's options: a text field's, with the bounds of the number it types.
        #
        # @return [Hash] The options.
        def typing_options
          super.merge(:number => [@options[:min], @options[:max]])
        end

        # Draws the text typed with its caret, in the middle between the arrows.
        #
        # @param canvas [Canvas] Where it draws.
        # @param top [Integer] The top of its line.
        def draw_typed(canvas, top)
          bitmap = canvas.bitmap
          Style.use_font(bitmap, text_px, canvas.text_color(:text))
          side = @options[:arrows] ? arrow_room : side_room
          room = [canvas.width - 2 * side, 1].max
          indent = [(room - UI.text_width(bitmap, @editor.text.to_s) - TextBox::CURSOR_WIDTH) / 2, 0].max
          TextBox.draw_line(bitmap, canvas.area(side + indent, top, room - indent, LINE_HEIGHT), @editor)
        end

        # Tells the width of its widest arrow.
        #
        # @return [Integer] The pixels.
        def arrow_width
          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          ARROWS.map { |arrow| UI.text_width(bitmap, arrow) }.max
        end

        # Tells the room at either end where a click steps it: from its edge past its arrow.
        #
        # @return [Integer] The pixels, 0 without arrows.
        def arrow_room
          @options[:arrows] ? side_room + arrow_width + Style::PAD : 0
        end

        # Tells the room at its left before its arrow or its number: its border and its padding.
        #
        # @return [Integer] The pixels.
        def side_room
          edge_sides[3]
        end

        # Tells how a number shows: with its adornment after it.
        #
        # @param number [Integer] The number.
        # @return [String] What shows.
        def shown(number)
          adornment = @options[:adornment]
          adornment.nil? || adornment.to_s.empty? ? number.to_s : "#{number} #{adornment}"
        end

        # Tells whether a number stands at a bound.
        #
        # @param number [Integer] The number.
        # @param bound [Symbol] :min or :max.
        # @return [Boolean] Whether it does.
        def end?(number, bound)
          limit = @options[bound]
          !limit.nil? && (bound == :min ? number <= limit : number >= limit)
        end

        # Tells the room around its number, which its :padding replaces.
        #
        # @return [Array<Integer>] Top, right, bottom and left.
        def own_room
          [PAD_Y, PAD_X, PAD_Y, PAD_X]
        end
      end

      # The completions of a text field: a small box over the field, from where its last word starts,
      # or under it for an autocomplete's matches, at least as wide as the field, with the lit
      # completion picked; the pointer picks one and a click takes it, while the keys stay
      # with the field.
      class CompletionBox < Box
        # Makes the box of a field's completions, closed.
        #
        # @param field [TextField] The field.
        def initialize(field)
          super(:z => Z[:typing], :frame => true, :captures => false, :closable => false)
          @field = field
          @list = add_list(:pointer_only => true, :quiet => true, :most_rows => TextField::MOST_COMPLETIONS)
          @list.on(:submit) { |_row, index| field.take_completion(index) }
        end

        # Shows completions over the field, or under it, from a left edge on the screen; where they
        # do not fit that side, they show on the other.
        #
        # @param list [Array<String>] The completions.
        # @param index [Integer] The lit one.
        # @param left [Integer] Where they start.
        # @param under [Boolean] Whether they show under the field, as an autocomplete's matches,
        #   at least as wide as the field.
        def show(list, index, left, under = false)
          @list.rows = list unless @list.rows == list
          @list.index = index
          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          width = list.map { |text| UI.text_width(bitmap, text) }.max.to_i + 2 * (ROOM + List::INSET) + Canvas::OUTLINE_ROOM
          width = [width, @field.rect.width].max if under
          height = list.size * LINE_HEIGHT + 2 * ROOM
          above = @field.rect.y - height
          below = @field.rect.y + @field.rect.height
          top = under ? (below + height > Graphics.height ? above : below) : (above < 0 ? below : above)
          self.at = [UI.within(under ? left : left - ROOM - List::INSET, 0, [Graphics.width - width, 0].max), top]
          self.size = [width, height]
          open unless open?
        end
      end

      # The game's own letter table for a text field, which a gamepad types with: a dialog under the
      # field's caption with its text as the field shows it, the letters of the game's name entry, a
      # page, a delete and an OK button. The letters type as the field would, so its :allowed and
      # :max_length hold; OK fills the field and tells its submit, cancel leaves it as it was. A
      # gamepad's B takes the last letter away, as the game's own name entry does, and closes the
      # letters only once the text is empty.
      class LetterPad < Dialog
        # The letters side by side on a line, as the game's name entry lays them out.
        COLUMNS = 10

        # The width of the dialog.
        WIDTH = 520

        # The texts of its buttons.
        TEXTS = { :page => "Page", :delete => "Delete", :ok => "OK", :title => "Letters" }

        # Opens the letters for a field.
        #
        # @param field [TextField] The field.
        # @return [LetterPad] The dialog, open unless refused.
        def self.open(field)
          pad = new(field)
          pad.open
          pad
        end

        # @return [String] The text typed so far.
        attr_reader :typed

        # Makes the dialog for a field.
        #
        # @param field [TextField] The field.
        def initialize(field)
          caption = field.caption
          super(:title => caption.empty? ? TEXTS[:title] : caption, :width => WIDTH, :id => :mf_letter_pad)
          @field = field
          @typed = field.text.to_s
          @pages = Game.letter_pages
          @page = 0
          @shown = add_label("", :wrap => field.lines.to_i > 1, :plate => true)
          @letters = add_list(:columns => COLUMNS, :rows => @pages[0], :rows_shown => (@pages[0].size + COLUMNS - 1) / COLUMNS, :quiet => true)
          @letters.on(:submit) { |letter, _index| type(letter) }
          row = add_row(:justify => :end, :gap => Style::GAP)
          row.add_button(TEXTS[:page]).on(:click) { turn_page } if @pages.size > 1
          row.add_button(TEXTS[:delete], :quiet => true).on(:click) { delete }
          row.add_button(TEXTS[:ok], :closes => true).on(:click) { finish }
          on(:cancel) { true }
          show_typed
        end

        # Takes an event of C#'s tree: a gamepad's cancel takes the last letter away while there is
        # one, any other cancel closes the letters.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return delete if name == "cancel" && values[0] == "pad" && !@typed.empty?

          super
        end

        # Types a letter as the field would, or buzzes for one it refuses or one past its most.
        #
        # @param letter [String] The letter.
        def type(letter)
          most = @field.max_length
          return Sound.play_buzzer unless @field.types?(letter.to_s) && (most.nil? || @typed.length < most.to_i)

          Sound.play_ok
          @typed += letter.to_s
          show_typed
        end

        # Takes the last letter typed away.
        def delete
          return Sound.play_buzzer if @typed.empty?

          Sound.play_cancel
          @typed = @typed[0..-2]
          show_typed
        end

        # Shows the next page of letters, round.
        def turn_page
          @page = (@page + 1) % @pages.size
          @letters.rows = @pages[@page]
        end

        # Fills the field with the text typed and tells its submit.
        def finish
          @field.text = @typed
          @field.emit(:submit, @typed)
        end

        private

        # Shows the text typed as the field shows it.
        def show_typed
          shown = @field.shown_text(@typed)
          @shown.text = shown.empty? ? " " : shown
        end
      end
    end

    Run.on_start("text fields", :dll => true) { Engine::Tick.collect("Mod Framework text fields") { Mod_Framework::UI::Engine::TextField.follow } }
    Mod_Framework.bridge.on(Engine::TextEdit::EVENT) { |event| Mod_Framework::UI::Engine::TextField.take_edit(event) }
  end
end
