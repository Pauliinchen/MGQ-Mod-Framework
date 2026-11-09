#----------------------------------------------------------------
#  dialogs.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Gave UI.number its max: as given and named its text after the number adornment:
#      Paulinchen  2026-11-06: Removed the old menu, whose place the menus of UI.menu take
#                            - Removed the number field set digit by digit; UI.number asks through a numeric field, its digits: the most digits
#                            - Made the handles plain objects
#                            - Removed the old question box and message box, which UI.confirm and UI.message replace
#                            - Called the engine's classes by their names under UI::Engine
#                            - Named the mod whose UI.menu did not open in the log
#                            - Closed and moved a menu with the part it opened from through :opened_from
#                            - Let UI.menu take on_refuse:, told each greyed choice the player tried to take
#                            - Answered is_a? and the other calls every object answers from ConfirmHandle, MessageHandle, MenuHandle, so a scene's variables may hold them
#                            - Opened UI.confirm, UI.message, UI.number and UI.menu as components of the UI layer, and took out
#                              the question box's C# keys
#                            - Typed a number field as a numeric field types once a digit of the number row starts it, and took
#                              out its calculator start
#      Paulinchen  2026-11-05: Named the box in the tick by a frozen text, which the tick keeps without a copy
#                            - Opened UI.menu from the part given as from:, else the part whose event its caller handles
#                            - Sized a menu at a part to its rows, without a foot line, and opened a menu after another
#                              beside that menu, on its left where the right has no room
#                            - Closed a menu with the root of the part it opened from and moved it with that root
#                            - Placed a menu beside a row of a table or a page view by the list it holds
#                            - Added UI.menu, a menu at a spot, the pointer, beside a row or under a part, answering a handle
#                            - Laid a menu above every window and dialog
#                            - Opened the choices a menu's choice holds in a menu beside its row, as deep as they go, and
#                              closed both menus on a click outside both
#                            - Placed a menu on a side of a part or a game window, and beside a row of a game's command window
#                            - Added UI.number, the digit box answering a handle
#                            - Added UI.confirm and UI.message, each answering a handle, with the place id of each box and
#                              the message's OK text and wrap
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#      Paulinchen  2026-11-04: Made a menu at a spot as wide as its close hint, which a context menu keeps short
#                            - Let a right click cancel a menu opened with :right_cancels
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Typed digits into a number field as on a calculator until the player picks a digit
#                            - Worded the key help of a number question by its buttons, cancel first
#                            - Called no answer block of a question, number or menu F12 closes
#                            - Opened a menu above every root open, a field that types included
#      Paulinchen  2026-10-31: Named the cancel key in the question box's hint as F1 binds it
#                            - Added the number field, a number set digit by digit, and its question
#                            - Added the menu, one way to ask the player to pick one of some choices, and a question that
#                              starts on its first choice
#      Paulinchen  2026-10-29: Answered with the keys of the accept and decline hotkeys
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The keys the accept and decline hotkeys start on; UI.confirm's QuestionBox (layer_boxes.rbx)
      # answers with those hotkeys.
      module Confirm
        # Windows' code of the key that answers yes until the player binds another, Y.
        ACCEPT_KEY = 0x59

        # Windows' code of the key that answers no until the player binds another, N.
        DECLINE_KEY = 0x4E
      end
    end

    module Engine
      # What UI.confirm and UI.message share: the check of their params.
      module Services
        # Logs once each param a call does not take, with the nearest one it takes.
        #
        # @param call [String] The call, such as "UI.confirm".
        # @param params [Hash] The params given.
        # @param names [Array<Symbol>] The params it takes.
        # @param trace [Array<String>] Where it was called from.
        def self.check(call, params, names, trace)
          (params.keys - names).each do |name|
            near = Declarations.nearest(name, names)
            Errors.hint([:service_param, call, name], trace, "#{call} takes no #{name}:#{near ? "; did you mean #{near}:?" : ''} It takes #{names.map { |each| "#{each}:" }.join(', ')}.")
          end
        end
      end

      # What UI.confirm hands back: a handle that offers only its documented methods.
      class ConfirmHandle
        # Makes the handle of a question.
        #
        # @param asked [Integer] C#'s number of the question's box.
        # @param id [Symbol] The box's place id.
        def initialize(asked, id)
          @asked = asked
          @id = id
        end

        # Tells whether the question waits for its answer.
        #
        # @return [Boolean] Whether it does.
        def open?
          Confirm.asked_id == @asked
        end

        # Answers the question no from outside, as when what it asks about went away.
        #
        # @param reason [String] Why, for the log.
        # @return [nil] Always.
        def close(reason = Confirm::CLOSED_REASON)
          Confirm.close(reason) if open?
          nil
        end

        # Tells the box's place id.
        #
        # @return [Symbol] The id.
        def id
          @id
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.confirm handle #{@id}: open?, close(reason), id>"
        end
        alias_method :to_s, :inspect
      end

      # What UI.message hands back: a handle that offers only its documented methods.
      class MessageHandle
        # Makes the handle of a message.
        #
        # @param dialog [Dialog] The message's Dialog.
        # @param id [Symbol] Its place id.
        def initialize(dialog, id)
          @dialog = dialog
          @id = id
        end

        # Tells whether the message still shows.
        #
        # @return [Boolean] Whether it does.
        def open?
          @dialog.open?
        end

        # Closes the message; its block runs as when the player closed it.
        #
        # @return [nil] Always.
        def close
          @dialog.close(:script) if @dialog.open?
          nil
        end

        # Tells its place id.
        #
        # @return [Symbol] The id.
        def id
          @id
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.message handle #{@id}: open?, close, id>"
        end
        alias_method :to_s, :inspect
      end

      # What UI.number hands back: the handle of its dialog, as UI.message's.
      class NumberHandle < MessageHandle
        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.number handle #{@id}: open?, close, id>"
        end
        alias_method :to_s, :inspect
      end

      # What UI.menu hands back: a handle that offers only its documented methods.
      class MenuHandle
        # Makes the handle of a menu.
        #
        # @param menu [Menus::Way] The way of menus UI.menu opened.
        def initialize(menu)
          @menu = menu
        end

        # Tells whether the menu still shows.
        #
        # @return [Boolean] Whether it does.
        def open?
          @menu.open?
        end

        # Closes the menu and the menus opened from it; its block gets nil.
        #
        # @return [nil] Always.
        def close
          @menu.close_with_subs(:script)
          nil
        end

        # Tells its place id.
        #
        # @return [Symbol] The id.
        def id
          @menu.id
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.menu handle #{id}: open?, close, id>"
        end
        alias_method :to_s, :inspect
      end
    end

    # The params UI.confirm takes.
    CONFIRM_PARAMS = [:yes, :no, :lit, :id]

    # The params UI.message takes.
    MESSAGE_PARAMS = [:ok, :wrap, :title, :id]

    # The params UI.number takes.
    NUMBER_PARAMS = [:min, :max, :adornment, :title, :note, :ok, :cancel, :id]

    # The params UI.menu takes.
    MENU_PARAMS = [:at, :beside, :row, :under, :title, :most_rows, :width, :from, :on_refuse]

    # Asks the player a yes or no question in the question box, above every root, one question at a
    # time: Left and Right move the light, confirm answers the lit choice, the Accept hotkey answers
    # yes, the Decline hotkey and cancel answer no. A change of the scene answers no.
    #
    #   UI.confirm("Leave the camp?", yes: "Leave", no: "Stay") { |yes| leave_camp if yes }
    #
    # @param question [String] The question, wrapped to the box's width.
    # @param params [Hash] yes: (the yes choice's text, "Yes"), no: (the no choice's text, "No"),
    #   lit: (:no or :yes, the choice lit first; :no unless told), id: (the box's place id,
    #   :confirm_box).
    # @yieldparam yes [Boolean] true for yes, false for no; once, in the frame after the answer.
    # @return [Object, false] The handle (open?, close(reason), id), or false while another question
    #   is open or the question is empty, logged.
    def self.confirm(question, params = {}, &block)
      Engine::Services.check("UI.confirm", params, CONFIRM_PARAMS, caller)
      id = params[:id] || :confirm_box
      options = { :id => id }
      options[:index] = 0 if params[:lit] == :yes
      asked = Engine::Confirm.ask(question, [(params[:yes] || "Yes").to_s, (params[:no] || "No").to_s], options, &block)
      asked ? Engine::ConfirmHandle.new(Engine::Confirm.asked_id, id) : false
    end

    # Shows a message in a small dialog above every root, its text wrapped to its width, with an OK
    # button; confirm, cancel or a click on OK closes it, and so does a change of the scene.
    #
    #   UI.message("Your notes were copied into the camp book.") { notes_saved }
    #
    # @param text [String] The text.
    # @param params [Hash] ok: (the button's text, "OK"), wrap: (false keeps the text on one line,
    #   cut with "..."; true unless told), title: (a title over it, none unless told), id: (its
    #   place id, :message_box).
    # @yield Runs once as it closes.
    # @return [Object, nil] The handle (open?, close, id), nil when it did not open, logged.
    def self.message(text, params = {}, &block)
      Engine::Services.check("UI.message", params, MESSAGE_PARAMS, caller)
      id = params[:id] || :message_box
      shown = { :title => params[:title].nil? ? nil : params[:title].to_s, :body => text.to_s, :wrap => params[:wrap] != false,
                :ok_text => (params[:ok] || "OK").to_s, :box_id => id }
      handle = open(MessageBox, shown) { |_value, _why| Engine::Layer.after_render { block.call } if block }
      handle ? Engine::MessageHandle.new(handle, id) : nil
    end

    # Asks for a number in the number box: a numeric field, a note under it, an OK and a Back
    # button and a key line. The keys of numeric_field set it; OK gives it, kept within min: and
    # max:; cancel, Back, a click outside and a change of the scene give nil.
    #
    #   UI.number(0, max: 500, adornment: "G", note: "You have 500 G") { |gold, _shown| offer(gold) if gold }
    #
    # @param value [Integer] The number it starts at.
    # @param params [Hash] min: (0), max: (none), adornment: (a text after the number), title:
    #   (none), note: (a line under the number), ok: ("OK"), cancel: ("Back"), id: (its place id,
    #   :mf_number).
    # @yieldparam number [Integer, nil] The number given, nil for none.
    # @yieldparam shown [Integer] The number the box showed, so a question that must be answered
    #   can open again later with it.
    # @return [Object, nil] The handle (open?, close, id), nil when it did not open, logged.
    def self.number(value, params = {}, &block)
      Engine::Services.check("UI.number", params, NUMBER_PARAMS, caller)
      id = params[:id] || :mf_number
      field = { :min => params[:min] || 0 }
      field[:max] = params[:max] unless params[:max].nil?
      field[:adornment] = params[:adornment].to_s unless params[:adornment].nil?
      asked = { :start => value.to_i, :field_params => field, :title => params[:title], :note => params[:note], :ok_text => (params[:ok] || "OK").to_s,
                :cancel_text => (params[:cancel] || "Back").to_s, :box_id => id }
      shown = value.to_i
      handle = open(NumberBox, asked) do |answer, _why|
        number, shown = answer.is_a?(Array) ? answer : [nil, shown]
        Engine::Layer.after_render { block.call(number, shown) } if block
      end
      handle ? Engine::NumberHandle.new(handle, id) : nil
    end

    # Opens a menu of choices above every root open: centered, with its bottom at a spot or at the
    # pointer, beside a row of a list, or under a part, always on the screen. Up and Down pick and go
    # round, confirm or a click takes a choice, cancel or a click outside closes it. A choice with
    # items: opens them in a menu beside its row, whose cancel steps back. A disabled choice buzzes
    # and shows its tooltip.
    #
    #   UI.menu(["Invite", "Trade", { text: "Duel", disabled: true, tooltip: "Not in a battle." }], at: :pointer, title: "Ana") do |choice, _index|
    #     act_on("Ana", choice) if choice
    #   end
    #
    # @param choices [Array<String, Hash>] The choices, each a text or { text:, disabled:, tooltip:,
    #   data:, items: }.
    # @param params [Hash] at: ([x, y] or :pointer, where its bottom lies), beside: (a selector of a
    #   list, such as "#members", or a game window's class name) with row: (the row's place),
    #   under: (a selector of a part or a game window), title: (a line over the choices), most_rows:
    #   (the rows it shows before it scrolls, 10), width: (pixels; as wide as its choices unless
    #   told), from: (a selector of the part it opens from, whose root it closes and moves with;
    #   unless told, a part under: or beside: names, else the part whose click or confirm the
    #   caller handles), on_refuse: (a lambda told each choice with disabled: true the player tried
    #   to take, with its place among the choices of its menu, such as to log it; it buzzed already;
    #   and nil with why when the menu does not open, as its log says too).
    # @yieldparam choice [String, Hash, nil] The choice taken, as given, nil when it closed without one.
    # @yieldparam index [Integer, nil] Its place among the choices of its menu.
    # @return [Object, false] The handle (open?, close, id), or false when it did not open: another
    #   menu is open or its box failed, such as for a param that does not fit; the log says why.
    def self.menu(choices, params = {}, &block)
      Engine::Services.check("UI.menu", params, MENU_PARAMS, caller)
      place = {}
      [:at, :row, :title, :most_rows, :width].each { |key| place[key] = params[key] unless params[key].nil? }
      [:beside, :under].each do |key|
        next if params[key].nil?

        found = Engine::Placement.find(params[key].is_a?(Symbol) ? "##{params[key]}" : params[key].to_s)
        found ? place[key] = found : Engine::Tree.log("UI.menu #{key}: #{params[key].inspect} names no part open, so the menu opens in the middle")
      end
      place[:from] = menu_opener(params[:from], place)
      handle = Engine::Menus.open(choices, place, params[:on_refuse], caller, &block)
      handle ? Engine::MenuHandle.new(Engine::Menus.way) : false
    end

    # Tells the part UI.menu opens from: the part from: names, else the part under: or beside:
    # names, else the part whose click or confirm the caller handles.
    #
    # @param from [String, Symbol, nil] The selector from: gave, nil for none.
    # @param options [Hash] The menu's options, with :under and :beside found.
    # @return [Engine::Component, nil] The part, nil for none.
    def self.menu_opener(from, options)
      unless from.nil?
        found = Engine::Placement.find(from.is_a?(Symbol) ? "##{from}" : from.to_s)
        return found if found.is_a?(Engine::Component)

        Engine::Tree.log("UI.menu from: #{from.inspect} names no part open, so the menu follows the part whose event opened it")
      end
      [options[:under], options[:beside]].find { |each| each.is_a?(Engine::Component) } || Engine::Tree.acting
    end
    private_class_method :menu_opener

  end
end
