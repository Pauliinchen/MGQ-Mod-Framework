#----------------------------------------------------------------
#  layer_boxes.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Greyed a menu choice by disabled:
#      Paulinchen  2026-11-06: Named only the cancel keys in the foot line of a context menu, which opens as a menu of UI.menu
#                            - Let the keys reach the OK button of UI.message, so the focus starts on it
#                            - Asked the number of UI.number in a numeric field
#                            - Logged a menu that did not open with why, and told UI.menu's on_refuse
#                            - Moved a menu with the window it opened from, and a menu after another with that menu
#                            - Told UI.menu's on_refuse each greyed choice the player tried to take
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # The yes or no question of UI.confirm, a dialog of the UI layer over any scene: the question,
    # the yes and the no choice side by side, the lit one taking the focus first, and a key line.
    # Its parts take ids from its own (by default confirm_box): <id>_question, <id>_yes, <id>_no and
    # <id>_keys, so UI.patch reaches them.
    class QuestionBox < Component
      # Its width where it starts, and the least the player makes it.
      WIDTH = 400
      MIN_WIDTH = 240

      # The question.
      param :question

      # The texts of the yes and the no choice.
      param :yes_text, "Yes"
      param :no_text, "No"

      # The choice lit first: :no or :yes.
      param :lit, :no

      # Its id, which names its parts and keeps its place.
      param :box_id, :confirm_box

      # Describes the question.
      def render
        dialog nil, id: box_id, width: WIDTH, resizable: :width, min_size: [MIN_WIDTH, 0] do
          text question, wrap: true, id: :"#{box_id}_question"
          stack row: true, spacing: 2 do
            button yes_text, id: :"#{box_id}_yes", grow: 1, hotkey: :accept, autofocus: lit == :yes, on_click: -> { close(true) }
            button no_text, id: :"#{box_id}_no", grow: 1, hotkey: :decline, autofocus: lit != :yes, on_click: -> { close(false) }
          end
          key_help id: :"#{box_id}_keys", entries: [{ key: Hotkeys.label(:accept), text: yes_text },
                                                    { key: "#{Hotkeys.label(:decline)}, #{UI.cancel_keys}", text: no_text }]
        end
      end
    end

    # The message of UI.message, a dialog of the UI layer: a title, its text wrapped to its width and
    # an OK button. Its parts take ids from its own (by default message_box): <id>_text and <id>_ok.
    class MessageBox < Component
      # Room between the box and either side of the screen where it starts, and the least width.
      SIDE = 80
      MIN_WIDTH = 240

      # Its title, nil for none.
      param :title, nil

      # Its text.
      param :body

      # Whether the text wraps; false keeps it on one line, cut with "...".
      param :wrap, true

      # The button's text.
      param :ok_text, "OK"

      # Its id, which names its parts and keeps its place.
      param :box_id, :message_box

      # Describes the message.
      def render
        dialog title, id: box_id, width: [Graphics.width - 2 * SIDE, MIN_WIDTH].max, resizable: :width, min_size: [MIN_WIDTH, 48] do
          text body, id: :"#{box_id}_text", wrap: wrap, most_lines: (wrap ? nil : 1)
          stack row: true, justify: :end do
            button ok_text, id: :"#{box_id}_ok", autofocus: true, on_click: -> { close }
          end
        end
      end
    end

    # The number box of UI.number, a dialog of the UI layer: a numeric field, a note under it, an OK
    # and a Back button and a key line. Its parts take ids from its own (by default mf_number):
    # <id>_digits, <id>_note, <id>_ok, <id>_back and <id>_keys. It closes with [number given,
    # number shown], or nil.
    class NumberBox < Component
      # The words of the key line for the keys that step and type the number.
      KEY_TEXTS = { :step => "Change", :type => "Type" }

      # The number it starts at.
      param :start, 0

      # The numeric field's params: :min, :max, :adornment.
      param(:field_params) { {} }

      # A title over it, the note under the number, nil for none.
      param :title, nil
      param :note, nil

      # The buttons' texts.
      param :ok_text, "OK"
      param :cancel_text, "Back"

      # Its id, which names its parts and keeps its place.
      param :box_id, :mf_number

      # The number the field shows.
      state(:number) { start.to_i }

      # Describes the box.
      def render
        dialog title, id: box_id, close_outside: true, on_cancel: -> { close([nil, number]); false } do
          numeric_field({ bind: :number, id: :"#{box_id}_digits", autofocus: true, align_self: :center,
                          on_submit: ->(given) { close([given, number]) } }.merge(field_params))
          text(note.to_s, id: :"#{box_id}_note", typo: :caption, color: :dim, align: :center) unless note.to_s.empty?
          stack row: true, justify: :end do
            button ok_text, id: :"#{box_id}_ok", on_click: -> { close([kept, number]) }
            button cancel_text, id: :"#{box_id}_back", on_click: -> { close([nil, number]) }
          end
          key_help id: :"#{box_id}_keys", entries: [{ button: :B, text: cancel_text }, { button: :C, text: ok_text },
                                                    { key: "Up/Down", text: KEY_TEXTS[:step] }, { key: "0-9", text: KEY_TEXTS[:type] }]
        end
      end

      private

      # Tells the number shown kept within min: and max:.
      #
      # @return [Integer] The number.
      def kept
        most = field_params[:max]
        UI.within(number.to_i, field_params[:min].to_i, most.nil? ? number.to_i : most.to_i)
      end
    end

    # A menu of UI.menu, of menu and of a part's context menu, a dialog of the UI layer with the id
    # mf_menu: an optional title line, the choices as rows, the cursor following the pointer, and a
    # line naming what closes it where it lies at a spot or in the middle. A choice with items: opens
    # them in a menu beside its row, with the id mf_menu_2, then mf_menu_3. Its parts take ids from
    # its own: <id>_title, <id>_list and <id>_keys. It lies where Engine::Menus works it out, kept on
    # the screen.
    class MenuBox < Component
      # Its id.
      ID = :mf_menu

      # The choices.
      param(:choices) { [] }

      # Where and how it shows: :title, :at, :beside (an engine part) with :row, :under (an engine
      # part) with :side, :most_rows, :width, :from (the engine part it opens from, which it closes
      # and moves with), :before (the rect of the menu it opened after), :context (true for a
      # context menu).
      param(:place) { {} }

      # Its place in the way of menus, 0 for the first.
      param :level, 0

      # Describes the menu.
      def render
        menus = Engine::Menus
        id = menus.id_of(level)
        dialog nil, id: id, at: menus.spot(choices, place), width: menus.width(choices, place), close_outside: true, movable: false,
                    opened_from: menus.opener(place) do
          text(place[:title].to_s, id: :"#{id}_title", wrap: true) unless place[:title].to_s.empty?
          list menus.rows(choices), id: :"#{id}_list", most_rows: menus.most_rows(place), autofocus: true, follow_pointer: true,
                                    on_submit: ->(row) { menus.take(level, choices, row[:place]) }, on_refuse: ->(row) { menus.refuse(choices, row[:place]) }
          text(menus.close_line(place), id: :"#{id}_keys", typo: :caption, color: :dim) if menus.foot_line?(place)
        end
      end
    end

    module Engine
      # What UI.confirm asks with, one question at a time, now a QuestionBox of the UI layer. The block
      # runs once in the frame after the answer, once the box gave the game's buttons back, so the press
      # that answered reaches nothing under it: true for yes, false for no, for cancel, a change of the
      # scene and a close from outside.
      module Confirm
        # Why a box was answered no from outside unless the caller says.
        CLOSED_REASON = "closed from outside"

        # The handle of the box open, nil for none.
        @handle = nil

        # The number of the last question asked, which tells one question's handle from another's.
        @serial = 0

        # The id of the box open.
        @box_id = nil

        # Whether a question is asked and its block has not run yet.
        @asking = false

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "confirm"

        # Asks a question. Refused while one is asked, for an empty question and without the DLL.
        #
        # @param question [String] The question.
        # @param choices [Array<String>] The yes and the no choice's texts.
        # @param options [Hash] :index (0 lights yes first), :id (the box's id, :confirm_box).
        # @yieldparam answer [Boolean] true for yes, false for anything else.
        # @return [Boolean] Whether it opened.
        def self.ask(question, choices = ["Yes", "No"], options = {}, &answer)
          return refuse("one is open (#{@question})", caller) if open?
          return refuse("the question is empty", caller) if question.to_s.empty?
          return refuse("the framework runs without its DLL", caller) unless Mod_Framework.available?

          @question = question.to_s
          yes = choices[0].to_s
          no = choices[1].to_s
          params = { :question => @question, :yes_text => yes, :no_text => no, :lit => options[:index] == 0 && options.key?(:index) ? :yes : :no,
                     :box_id => options[:id] || :confirm_box }
          handle = UI.open(QuestionBox, params) { |value, why| answered(value == true, why, yes, no, answer) }
          return refuse("the box did not open", caller) unless handle

          @handle = handle
          @serial += 1
          @box_id = params[:box_id]
          @asking = true
          log("asked: #{@question} (#{yes} / #{no})")
          true
        end

        # Tells whether a question is asked: from ask until the frame its block runs in.
        #
        # @return [Boolean] Whether one is.
        def self.open?
          @asking
        end

        # Tells which question is asked: its number, nil while none is.
        #
        # @return [Integer, nil] The number.
        def self.asked_id
          @asking ? @serial : nil
        end

        # Tells whether the yes choice holds the focus.
        #
        # @return [Boolean] Whether it does.
        def self.picked?
          part = @asking && Placement.find("##{@box_id}_yes")
          part ? part.focused? : false
        end

        # Answers no without the player.
        #
        # @param reason [String] Why, for the log.
        def self.close(reason = CLOSED_REASON)
          @handle.close(reason.to_s) if @asking && @handle && @handle.open?
        end

        # Tells whether a root is the question box asked now, which the question holds no root under.
        #
        # @param root [Component] The root.
        # @return [Boolean] Whether it is.
        def self.box?(root)
          @asking && root.respond_to?(:id) && root.id == @box_id ? true : false
        end

        # Forgets the question, as F12 starts the game anew; its block does not run.
        def self.reset
          @asking = false
          @handle = nil
        end

        # Takes the box's close: logs the answer and runs the block in the next frame.
        #
        # @param yes [Boolean] Whether the player chose yes.
        # @param why [Symbol, String] Why it closed.
        # @param yes_text [String] The yes choice's text.
        # @param no_text [String] The no choice's text.
        # @param block [Proc, nil] The question's block.
        def self.answered(yes, why, yes_text, no_text, block)
          return unless @asking

          log("answered #{yes ? yes_text : no_text} (#{why}): #{@question}")
          Layer.after_render do
            @asking = false
            @handle = nil
            begin
              block.call(yes) if block
            rescue => e
              log("the block of a question failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
            end
          end
        end

        # Logs a question refused, once per mod and reason.
        #
        # @param why [String] Why.
        # @param lines [Array<String>] The calls that led here.
        # @return [Boolean] Always false.
        def self.refuse(why, lines)
          mod = Root.mod_file(lines)
          log_once([:refused, mod, why], "#{mod} asked a question, refused: #{why}")
          false
        end
        private_class_method :refuse
      end

      # What UI.menu, menu and a part's context menu open: MenuBoxes of the UI layer, one menu at a
      # time, a choice with items: opening them in another beside its row, as deep as they go; cancel
      # there steps back, a click outside both closes both.
      module Menus
        # Its width centered on the screen unless told, and the most it takes at a part.
        WIDTH = 360

        # The most rows it shows unless told; the rest scroll.
        MOST_ROWS = 10

        # Room kept from the screen's edges.
        MARGIN = 8

        # What else closes it, which its foot line names after the cancel keys.
        OUTSIDE_TEXT = "a click outside"

        # The mark at the right of a choice that opens a menu of its own.
        SUB_MARK = "▸"

        # The handles of the menus open, the first one first.
        @open = []

        # UI.menu's block, which runs once.
        @block = nil

        # UI.menu's on_refuse, told each greyed choice the player tried to take.
        @refused = nil

        # The number of the last way of menus opened, which tells one handle from another.
        @serial = 0

        # A way of menus UI.menu opened, as its handle reads it.
        class Way
          # Makes the way of a number.
          #
          # @param serial [Integer] The way's number.
          def initialize(serial)
            @serial = serial
          end

          # Tells whether its menus still show.
          #
          # @return [Boolean] Whether they do.
          def open?
            Menus.open_way?(@serial)
          end

          # Closes its menus; the block gets nil.
          #
          # @param _why [Symbol] Why.
          def close_with_subs(_why)
            Menus.close_way(@serial)
          end

          # Tells its first menu's id.
          #
          # @return [Symbol] The id.
          def id
            MenuBox::ID
          end
        end

        # Whether the way of menus answered.
        @done = true

        # Opens a menu, see UI.menu.
        #
        # @param choices [Array<String, Hash>] The choices.
        # @param place [Hash] See MenuBox's place.
        # @param refused [Proc, nil] Told each greyed choice the player tried to take and its place,
        #   and nil and why when the menu does not open.
        # @param trace [Array<String>] The calls that led here, which name the mod.
        # @yieldparam choice [String, Hash, nil] The choice taken at the end of the way, nil for none.
        # @yieldparam index [Integer, nil] Its place among the choices of its menu.
        # @return [Object, false] The first menu's handle, false when it did not open.
        def self.open(choices, place, refused = nil, trace = caller, &block)
          return refuse_way("another menu is open", refused, trace) if open?

          @open = []
          @block = block
          @refused = refused
          @done = false
          @serial += 1
          handle = open_level(Array(choices), place)
          return handle if handle

          @done = true
          @block = nil
          @refused = nil
          refuse_way(Layer.refusal || "its box did not open", refused, trace)
        end

        # Logs a way of menus that did not open with why, and tells on_refuse nil and why; one that
        # fails is logged.
        #
        # @param why [String] Why.
        # @param refused [Proc, nil] UI.menu's on_refuse.
        # @param trace [Array<String>] The calls that led here, which name the mod.
        # @return [Boolean] Always false.
        def self.refuse_way(why, refused, trace)
          site = Errors.site(trace)
          Tree.log("#{Errors.mod(trace)}#{site ? " (#{site})" : ''}: UI.menu did not open: #{why}")
          begin
            refused.call(nil, why) if refused
          rescue => e
            Tree.log("the on_refuse of a menu failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          end
          false
        end
        private_class_method :refuse_way

        # Tells the way of menus opened last, for its handle.
        #
        # @return [Way] The way.
        def self.way
          Way.new(@serial)
        end

        # Tells whether the menus of a way still show.
        #
        # @param serial [Integer] The way's number.
        # @return [Boolean] Whether they do.
        def self.open_way?(serial)
          serial == @serial && !@done && open?
        end

        # Closes the menus of a way while they show; the block gets nil.
        #
        # @param serial [Integer] The way's number.
        def self.close_way(serial)
          finish(nil, nil) if open_way?(serial)
        end

        # Tells whether a menu of UI.menu is open.
        #
        # @return [Boolean] Whether one is.
        def self.open?
          @open.any? { |handle| handle.open? }
        end

        # Tells the id of a menu of the way: mf_menu for the first, mf_menu_2 and on for the menus of
        # items after it.
        #
        # @param level [Integer] Its place in the way, 0 for the first.
        # @return [Symbol] The id.
        def self.id_of(level)
          level == 0 ? MenuBox::ID : :"#{MenuBox::ID}_#{level + 1}"
        end

        # Takes a pick in a menu: a choice with items opens them beside its row, the menu staying
        # open under them; any other answers the way and closes every menu of it.
        #
        # @param level [Integer] The menu's place in the way.
        # @param choices [Array] Its choices.
        # @param index [Integer] The choice's place.
        def self.take(level, choices, index)
          choice = choices[index]
          items = choice.is_a?(Hash) ? Array(choice[:items]) : []
          return finish(choice, index) if items.empty?

          @open.slice!(level + 1..-1).to_a.each { |handle| handle.close(:done) if handle.open? }
          top = Layer.tops.reverse.find { |each| !each.closed && each.id == id_of(level).to_s }
          rect = top && top.root && top.root.engine.rect
          list = Placement.find("##{id_of(level)}_list")
          return if open_level(items, :beside => list, :row => index, :before => rect, :from => list)

          Tree.log("the items of a menu's choice #{choice.inspect} did not open: #{Layer.refusal || 'their box did not open'}")
        end

        # Tells UI.menu's on_refuse a greyed choice the player tried to take, which buzzed; one that
        # fails is logged.
        #
        # @param choices [Array] The choices of its menu.
        # @param index [Integer] Its place.
        def self.refuse(choices, index)
          Tree.log("a menu's choice #{choices[index].inspect} was refused: it is greyed out")
          @refused.call(choices[index], index) if @refused
        rescue => e
          Tree.log("the on_refuse of a menu failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Opens one menu of the way.
        #
        # @param choices [Array<String, Hash>] The choices.
        # @param place [Hash] See MenuBox's place.
        # @return [Object, nil] The handle, nil when it did not open.
        def self.open_level(choices, place)
          level = @open.size
          handle = UI.open(MenuBox, :choices => choices, :place => place, :level => level) { |_value, why| closed(level, why) }
          @open << handle if handle
          handle
        end
        private_class_method :open_level

        # Takes a menu's close without a pick: the first answers the way with nil, a later one steps
        # back to the menu before it, and a click outside both closes both.
        #
        # @param level [Integer] The menu's place in the way.
        # @param why [Symbol, String] Why it closed.
        def self.closed(level, why)
          return if @done || level >= @open.size
          return finish(nil, nil) if level == 0 || (why == :outside && !under_pointer?(id_of(level - 1)))

          @open = @open.first(level)
        end
        private_class_method :closed

        # Answers the way: closes every menu of it and runs the block in the next frame, once the
        # menus gave the game's buttons back; a block that fails is logged.
        #
        # @param choice [Object, nil] The choice, nil for none.
        # @param index [Integer, nil] Its place.
        def self.finish(choice, index)
          return if @done

          @done = true
          handles = @open
          @open = []
          handles.reverse_each { |handle| handle.close(:done) if handle.open? }
          block = @block
          @block = nil
          Layer.after_render do
            begin
              block.call(choice, index) if block
            rescue => e
              Tree.log("the block of a menu failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
            end
          end
        end
        private_class_method :finish

        # Tells whether the pointer lies on a menu, so a click there that closed the menu after it
        # leaves it open.
        #
        # @param id [Symbol] The menu's id.
        # @return [Boolean] Whether it does.
        def self.under_pointer?(id)
          top = Layer.tops.reverse.find { |each| !each.closed && each.id == id.to_s }
          box = top && top.root && top.root.engine.rect
          spot = Mouse.position
          spot && box && spot[0] >= box.x && spot[0] < box.x + box.width && spot[1] >= box.y && spot[1] < box.y + box.height ? true : false
        end
        private_class_method :under_pointer?

        # Tells the part a menu opened from, which it closes and moves with: the part UI.menu opened
        # it from, or the list of the menu before it.
        #
        # @param place [Hash] See MenuBox's place.
        # @return [Component, nil] The engine part, nil for none.
        def self.opener(place)
          from = place[:from]
          from.is_a?(Component) ? from : nil
        end

        # Tells the rows of choices: a text, or a choice's text, greyed while disabled, with its
        # tooltip and a mark for one with items, each with its place.
        #
        # @param choices [Array] The choices.
        # @return [Array<Hash>] The rows.
        def self.rows(choices)
          choices.each_with_index.map do |choice, place|
            next { :text => choice.to_s, :place => place } unless choice.is_a?(Hash)

            row = { :text => choice[:text].to_s, :disabled => choice[:disabled] == true, :tooltip => choice[:tooltip], :place => place }
            row[:right] = SUB_MARK unless Array(choice[:items]).empty?
            row
          end
        end

        # Tells whether a menu shows a line that names what closes it: centered or at a spot it does,
        # at a part it does not, as MudMenu.
        #
        # @param place [Hash] See MenuBox's place.
        # @return [Boolean] Whether it does.
        def self.foot_line?(place)
          !place[:beside] && !place[:under]
        end

        # Tells the line that names what closes a menu: the cancel keys alone for a context menu, so
        # it stays as narrow as its choices, else the cancel keys and a click outside.
        #
        # @param place [Hash] See MenuBox's place.
        # @return [String] The line.
        def self.close_line(place)
          place[:context] ? UI.close_hint : UI.close_hint(OUTSIDE_TEXT)
        end

        # Tells the most rows a menu shows before they scroll.
        #
        # @param place [Hash] See MenuBox's place.
        # @return [Integer] The rows.
        def self.most_rows(place)
          (place[:most_rows] || MOST_ROWS).to_i
        end

        # Tells a menu's width: :width, else WIDTH centered, else as wide as its rows, its title and
        # its foot line, at most WIDTH.
        #
        # @param choices [Array] The choices.
        # @param place [Hash] See MenuBox's place.
        # @return [Integer] The pixels.
        def self.width(choices, place)
          return place[:width].to_i if place[:width]
          return WIDTH unless placed?(place)

          bitmap = UI.font_bitmap(Style::TEXT_SIZE)
          widest = choices.map { |choice| UI.text_width(bitmap, choice.is_a?(Hash) ? choice[:text].to_s : choice.to_s) }.max.to_i
          widest += UI.text_width(bitmap, " #{SUB_MARK}") if choices.any? { |choice| choice.is_a?(Hash) && !Array(choice[:items]).empty? }
          widest += Style::SCROLLBAR_WIDTH + List::BAR_GAP if choices.size > most_rows(place)
          room = [widest + 2 * List::INSET, UI.text_width(bitmap, place[:title].to_s)].max
          room = [room, UI.text_width(UI.font_bitmap(Style::SMALL_SIZE), close_line(place))].max if foot_line?(place)
          [room + 2 * Window::PADDING + Canvas::OUTLINE_ROOM, WIDTH].min
        end

        # Tells a menu's top left: its bottom at :at or the pointer, beside :beside's :row, or on
        # :side of :under, kept on the screen; nil centered.
        #
        # @param choices [Array] The choices.
        # @param place [Hash] See MenuBox's place.
        # @return [Array<Integer>, nil] The left and the top, nil for the middle of the screen.
        def self.spot(choices, place)
          return nil unless placed?(place)

          width = width(choices, place)
          height = height(choices, place)
          if place[:at]
            x, y = place[:at] == :pointer ? Mouse.position || [Graphics.width / 2, Graphics.height / 2] : UI.point(place[:at])
            y -= height
          elsif place[:beside]
            x, y = beside_spot(place, width, height)
          else
            x, y = side_spot(box_of(place[:under]), place[:side], width, height)
          end
          [UI.within(x, MARGIN, [Graphics.width - width - MARGIN, MARGIN].max), UI.within(y, MARGIN, [Graphics.height - height - MARGIN, MARGIN].max)]
        end

        # Tells whether a menu lies at a spot or a part rather than in the middle.
        #
        # @param place [Hash] See MenuBox's place.
        # @return [Boolean] Whether it does.
        def self.placed?(place)
          place[:at] || place[:beside] || place[:under] ? true : false
        end
        private_class_method :placed?

        # Tells a menu's height before it is laid out: its title, its rows and its foot line.
        #
        # @param choices [Array] The choices.
        # @param place [Hash] See MenuBox's place.
        # @return [Integer] The pixels.
        def self.height(choices, place)
          shown = [choices.size, most_rows(place)].min
          title = place[:title].to_s.empty? ? 0 : UI::LINE_HEIGHT + Style::GAP
          2 * Window::PADDING + title + shown * UI::LINE_HEIGHT + (foot_line?(place) ? Style::GAP + UI::SMALL_LINE_HEIGHT : 0)
        end
        private_class_method :height

        # Tells where a menu lies on a side of a part: under it, over it or beside it, lined up with
        # its left or its top.
        #
        # @param part [Rect, nil] The part's place.
        # @param side [Symbol, nil] :bottom unless told, :top, :right or :left.
        # @param width [Integer] The menu's width.
        # @param height [Integer] The menu's height.
        # @return [Array<Integer>] The left and the top.
        def self.side_spot(part, side, width, height)
          return [MARGIN, MARGIN] unless part

          case side
          when :top then [part.x, part.y - height]
          when :right then [part.x + part.width, part.y]
          when :left then [part.x - width, part.y]
          else [part.x, part.y + part.height]
          end
        end
        private_class_method :side_spot

        # Tells where a menu lies beside a row of a list or of a game's command window: right of it,
        # else left of it, else below it, else above it; a menu after another lies beside that whole
        # menu, its first row level with the row it came from. A part that holds a list, such as a
        # table, stands for its list.
        #
        # @param place [Hash] See MenuBox's place.
        # @param width [Integer] The menu's width.
        # @param height [Integer] The menu's height.
        # @return [Array<Integer>] The left and the top.
        def self.beside_spot(place, width, height)
          list = place[:beside]
          list = list.list if list.is_a?(Component) && !list.is_a?(List) && list.respond_to?(:list) && list.list.is_a?(List)
          rect = box_of(list)
          return [MARGIN, MARGIN] unless rect

          row_top, row_height = row_place(list, rect, place[:row].to_i)
          edge = place[:before] || rect
          top = place[:before] ? row_top - Window::PADDING : row_top
          return [edge.x + edge.width, top] if edge.x + edge.width + width <= Graphics.width - MARGIN
          return [edge.x - width, top] if edge.x - width >= MARGIN

          below = row_top + row_height
          below + height <= Graphics.height - MARGIN ? [rect.x, below] : [rect.x, row_top - height]
        end
        private_class_method :beside_spot

        # Tells the top of a row of a list on the screen and the row's height.
        #
        # @param list [List, Window_Selectable] The list.
        # @param rect [Rect] The list's place on the screen.
        # @param row [Integer] The row.
        # @return [Array<Integer>] The top and the height.
        def self.row_place(list, rect, row)
          unless list.respond_to?(:scrolling)
            item = list.item_rect(row)
            return [rect.y + list.standard_padding + item.y - list.oy, item.height]
          end

          first = list.scrolling ? list.scrolling[0].to_i : 0
          [rect.y + (row - first) * list.line_height, list.line_height]
        end
        private_class_method :row_place

        # Tells the place on the screen of a part of the framework or of a game window.
        #
        # @param part [Component, Window, nil] The part.
        # @return [Rect, nil] Its place, nil while it has none.
        def self.box_of(part)
          return nil if part.nil?
          return part.rect if part.is_a?(Component)

          Rect.new(part.x, part.y, part.width, part.height)
        end
        private_class_method :box_of

        # Forgets the menus, as F12 starts the game anew; no block runs.
        def self.reset
          @open = []
          @block = nil
          @done = true
        end
      end
    end

    Run.on_reset("layer boxes") do
      Mod_Framework::UI::Engine::Confirm.reset
      Mod_Framework::UI::Engine::Menus.reset
    end
  end
end
