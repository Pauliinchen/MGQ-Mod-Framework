#----------------------------------------------------------------
#  layer_builtins_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Told a taken item of menu to on_submit in place of on_pick
#                            - Stopped giving a log most_rows, which it no longer takes
#      Paulinchen  2026-11-06: Opened the items of menu as the menus of UI.menu, dialogs of the UI layer
#      Paulinchen  2026-11-05: Stopped the typing of a field in a log's window as a name in the log is clicked
#                            - Added menu, a button that opens a menu of items, sub-menus of items within them
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer a chat is made of: a log of colored rows and a menu behind a
      # button. Like layer_builtins.rbx this file loads without the game, so
      # the tool writing docs/ui reads it too.
      module Builtins
        # Turns a log's params into the engine's options: a copy of its rows, so rows a mod adds to
        # the same Array still count as a change, and with rows_shown: :fill the
        # room its stack leaves.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.log(params)
          shown = params[:rows_shown] || :fill
          options = common(params).merge(:rows => Array(params[:rows]).dup, :rows_shown => shown, :keep_place => params[:keep_place] != false,
                                         :wheel_rows => params[:wheel_rows] || 3, :scrollbar => params[:scrollbar] != false)
          options[:grow] ||= 1 if shown == :fill
          options
        end

        # Hands a click on a part of a log to its on_click, when it has one as it is made, so a log
        # without one lets the pointer through in a hud that takes it only on its parts. The click
        # first stops the typing of a field in the log's window and takes the focus off it, so
        # on_click can open a menu or a dialog that takes the keys.
        #
        # @param part [Object] The layer's part of the log.
        def self.wire_log(part)
          return unless part.node.params[:on_click]

          part.engine.on(:click) do |row, piece|
            field = TextField.typing
            field.blur if field && field.root.equal?(part.engine.root)
            Layer.dispatch(part, :on_click, [row, piece])
          end
        end

        Declarations.define(:log,
                            :summary => "Rows of colored parts that wrap at their words, the newest at the bottom, such as a chat, a battle log or a feed; " \
                                        "a part with data: lights under the pointer and tells a click.", :args => [:rows],
                            :params => { :rows => { :kind => :live, :type => :array, :default => [],
                                                    :doc => "its rows, oldest first: each a text, or an Array of parts, each a text or { text:, color:, data: }; a row { parts:, opacity: } draws see-through" },
                                         :keep_place => { :type => :bool, :default => true,
                                                          :doc => "rows that come while the player scrolled up keep the view still; false scrolls to the newest row" },
                                         :wheel_rows => { :type => :int, :default => 3, :doc => "the lines a notch of the mouse wheel scrolls" },
                                         :scrollbar => { :type => :bool, :default => true, :doc => "a scrollbar shows at its right while lines are hidden" },
                                         :rows_shown => { :type => :count, :values => [:fill], :default => :fill,
                                                          :doc => "how many lines high it is, or :fill for the room its stack leaves; whole lines stand on its bottom edge" } },
                            :events => { :click => "the row and the part the player clicked, a part with data:" },
                            :keys => "none: it is no key stop; a text_field whose steer: names it scrolls it by Up, Down, Page Up and Page Down while it types",
                            :mouse => "the wheel scrolls it; a part with data: draws lighter under the pointer and a click on it stops the typing of a field in its window, " \
                                      "takes the focus off that field and then tells on_click",
                            :actions => { :scroll_to_end => { :doc => "scrolls to the newest row, such as when its chat opens or another tab shows",
                                                              :call => lambda { |part| part.engine.scroll_to_end } } },
                            :make => lambda { |options| LogView.new(options) },
                            :options => lambda { |params| log(params) },
                            :wire => lambda { |part| wire_log(part) })

        # The sides of its button a menu opens on.
        MENU_SIDES = [:bottom, :top, :right, :left]

        # Turns a menu's params into the engine's options of the button that opens it: its label: or
        # its icon:, a button that acts, so the keys stop on it.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.menu_button(params)
          common(params).merge(:text => params[:label].to_s, :icon => params[:icon], :variant => :text, :acts => true, :repeats => false)
        end

        # Opens a menu's items on the side of its button as UI.menu opens its choices: an item with
        # items: opens them beside its row, an item taken tells on_submit, a disabled one on_refuse. A
        # menu open elsewhere refuses it with the buzzer.
        #
        # @param part [Object] The layer's part of the menu.
        def self.open_menu(part)
          params = part.node.params
          items = params[:items]
          items = items.call if items.is_a?(Proc)
          refused = lambda { |item, _index| Layer.dispatch(part, :on_refuse, [item]) if item && !part.gone }
          place = { :under => part.engine, :side => params[:side] || :bottom, :from => part.engine }
          opened = Menus.open(Array(items), place, refused) do |item, _index|
            Layer.dispatch(part, :on_submit, [item]) if item && !part.gone
          end
          Sound.play_buzzer unless opened
        rescue StandardError => e
          Errors.report(e, "the items: of menu")
        end

        Declarations.define(:menu,
                            :summary => "A button that opens a menu of items beside it, such as the actions on a player; an item may hold items of its own, " \
                                        "which open in a menu beside its row.", :args => [:label],
                            :params => { :label => { :kind => :live, :type => :text, :doc => "the text of the button that opens it" },
                                         :icon => { :kind => :live, :type => :icon, :doc => "an icon on the button that opens it, before its label:" },
                                         :items => { :type => :menu_items, :default => [],
                                                     :doc => "its items, each a text or { text:, disabled:, tooltip:, data:, items: }: disabled: true greys it out, items: opens a menu of its own; a lambda is asked as it opens" },
                                         :side => { :values => MENU_SIDES, :default => :bottom, :doc => "the side of its button it opens on, lined up with the button's left or top" } },
                            :events => { :submit => "the item the player took, as given", :refuse => "the item with disabled: true the player tried to take, which buzzed" },
                            :keys => "confirm on its button opens it; Up and Down move and go round; confirm takes an item or opens its items; cancel closes it, or steps back from the items of an item",
                            :pad => "A opens it and takes; B closes it or steps back",
                            :mouse => "a click on its button opens it; pointing picks an item and a click takes it; a click outside closes it",
                            :make => lambda { |options| Button.new(options) },
                            :options => lambda { |params| menu_button(params) },
                            :wire => lambda { |part| part.engine.on(:click) { open_menu(part) } })
      end
    end
  end
end
