#----------------------------------------------------------------
#  components_tabs.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Told C#'s tree how many tabs show
#      Paulinchen  2026-11-07: Wrote the text of a tab on its plate in the plain text color unless it has contrast
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A row of tabs over one page each, only the picked tab's page showing; add_tab makes a tab and
      # hands out its page, a column that takes any component. A click picks a tab. Keys step to the
      # tab shown beside, round at either end, while the tabs show, their root has the focus and no
      # text field has it, as the options choose: with :tab_key Tab and Shift+Tab, in place of moving
      # the focus; with :pad_shoulders a gamepad's R and L, never the keyboard's keys of the game's L
      # and R (see Pad); with :shoulder the game's L and R, the keyboard's Q and W too, and a list of
      # that root then pages by Page Up and Page Down only. With any of them the tabs stay off the
      # arrows' and Tab's way. A tab hidden with tab(place).visible = false hides its page too; the
      # tab last picked comes back once it shows. Its bar is the row the tabs lie in, which takes
      # other components beside them, such as a Back button before them.
      #
      # Events: change (index).
      #
      # With :pages => false they are a bar alone that tells which tab is picked; add_tab(title,
      # :color => c) draws the title in a color of its own and the picked tab filled with it. With
      # :arrows LEFT and RIGHT step the tabs, round, whenever the focused part has no use for them, the
      # tabs then off the cursor's way too, and with :enter a tab picked moves the focus into its page.
      # :font_size draws every tab in that font, its row as high as the font's line; add_tab(title,
      # :font_size => :small) sets one tab's.
      class Tabs < Component
        include Container

        # The component's kind in C#'s tree.
        KIND = "tabs"

        # Room between two tabs.
        TAB_GAP = 2

        # Room between the tabs and what else their bar holds.
        BAR_GAP = 8

        # Tells the defaults of the options: the first tab picked.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:index => 0, :shoulder => false, :tab_key => false, :pad_shoulders => false, :pages => true, :arrows => false, :font_size => :normal)
        end

        # Tells which properties of C#'s tree each option sets.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:shoulder => ["shoulder"], :tab_key => ["tab_key"], :pad_shoulders => ["pad_shoulders"], :arrows => ["arrows"])
        end

        # The options of a tab itself; the others of add_tab are its page's.
        TAB_OPTIONS = [:color, :badge, :badge_color, :tooltip, :icon, :font_size]

        options :index, :shoulder, :tab_key, :pad_shoulders, :pages, :arrows, :font_size

        # @return [Stack] The row the tabs lie in, for components beside them.
        attr_reader :bar

        # Makes the tabs with the row their tabs go in.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @pages = []
          @chosen = @options[:index].to_i
          @bar = add(Stack.new(:layout => :row, :gap => BAR_GAP))
          @header = @bar.add(Stack.new(:layout => :row, :gap => TAB_GAP))
        end

        # Tells the properties C#'s tree routes the keys by, with how many tabs show.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["shoulder"] = @options[:shoulder] ? true : false
          props["tab_key"] = @options[:tab_key] ? true : false
          props["pad_shoulders"] = @options[:pad_shoulders] ? true : false
          props["arrows"] = @options[:arrows] ? true : false
          props["tabs_shown"] = shown_tabs.size
          props["enter"] = false
          props["focusable"] = false if @options[:enter]
          props
        end

        # Hands out a tab, to hide or show it.
        #
        # @param place [Integer] The tab's place.
        # @return [Tab, nil] The tab, nil for none.
        def tab(place)
          @header.children[place]
        end

        # Hands out the pages in the order of their tabs.
        #
        # @return [Array<Stack>] The pages.
        def pages
          @pages.dup
        end

        # Makes a tab and its page; a bar alone makes no page.
        #
        # @param title [String] The tab's text.
        # @param options [Hash] The tab's :color, :badge, :badge_color, :tooltip, :icon and :font_size
        #   (the tabs' own unless given), and the page's options, a column's by default.
        # @return [Stack, Tab] The page, or the tab of a bar alone.
        def add_tab(title, options = {})
          own = { :font_size => @options[:font_size] }.merge(options.select { |key, _value| TAB_OPTIONS.include?(key) })
          page = TabPage.new(options.reject { |key, _value| TAB_OPTIONS.include?(key) })
          page.visible = @pages.size == @options[:index].to_i && @options[:pages] != false
          tab = @header.add(Tab.new(self, @pages.size, own.merge(:text => title, :focusable => stops?)))
          @pages << page
          Tree.set(self, "tabs_shown" => shown_tabs.size)
          return tab if @options[:pages] == false

          add(page)
        end

        # Picks a tab: its page shows and the others hide.
        #
        # @param value [Integer] The tab's place.
        def index=(value)
          @chosen = UI.within(value.to_i, 0, [@pages.size - 1, 0].max)
          show_chosen
        end

        # Picks a tab as the player clicked it, and runs the change blocks.
        #
        # @param place [Integer] The tab's place.
        def picked(place)
          Tree.focus_in(@pages[place]) if @options[:enter] && @options[:pages] != false && @pages[place]
          return if place == @options[:index]

          @chosen = place
          show_chosen
          emit(:change, place)
        end

        # Picks the nearest tab shown that takes input beside the picked one, round at either end, as
        # the keys that step the tabs do.
        #
        # @param by [Integer] -1 for the one before, 1 for the one after.
        def step(by)
          shown = shown_tabs
          return if shown.empty?

          place = shown.index(@options[:index]) || 0
          next_place = (1...shown.size).map { |distance| shown[(place + by * distance) % shown.size] }.find { |each| @header.children[each].enabled? }
          return unless next_place

          picked(next_place)
        end

        # Picks a tab as the player clicked it; a bar alone with :enter hands the focus to the part
        # below it.
        #
        # @param place [Integer] The tab's place.
        def clicked(place)
          picked(place)
          below = mark_panel
          Tree.focus_in(below) if below
        end

        # Marks the part under a bar of tabs alone with :enter as the panel its tabs fill, so cancel
        # there walks the focus back to the tab it came from, as from a page.
        #
        # @return [Component, nil] The part, nil for none or for tabs that are no such bar.
        def mark_panel
          return nil unless @options[:enter] && @options[:pages] == false

          below = part_below
          below.panel = true if below && !below.panel
          below
        end

        # Finds the part under a bar of tabs alone, which shows what the picked tab stands for: the
        # first part shown after it, or after the row it lies in, in the nearest column holding it.
        #
        # @return [Component, nil] The part, nil for none.
        def part_below
          child = self
          holder = parent
          while holder
            if holder.respond_to?(:layout) && holder.layout != :row
              after = holder.children.drop_while { |each| !each.equal?(child) }.drop(1)
              found = after.find { |each| each.visible? }
              return found if found
            end
            child = holder
            holder = holder.parent
          end
          nil
        end

        # Takes an event of C#'s tree: a key that steps the tabs steps to the tab beside, round at
        # either end.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return super unless name == "step"

          step(values[0].to_i)
        end

        # Shows the page of the tab picked last, or of the first tab shown while that one hides, and
        # tells C#'s tree how many tabs show.
        def show_chosen
          shown = shown_tabs
          place = shown.include?(@chosen) ? @chosen : (shown.first || 0)
          @options[:index] = place
          @pages.each_with_index { |page, at| page.visible = at == place && shown.include?(at) if @options[:pages] != false && page.visible? != (at == place && shown.include?(at)) }
          @header.children.each { |tab| tab.redraw }
          Tree.set(self, "tabs_shown" => shown.size)
        end

        private

        # Tells the places of the tabs shown.
        #
        # @return [Array<Integer>] The places.
        def shown_tabs
          (0...@pages.size).select { |place| @header.children[place].visible? }
        end

        # Tells whether keys step the tabs, so the tabs stay off the cursor's and Tab's way.
        #
        # @return [Boolean] Whether they do.
        def keyed?
          @options[:shoulder] || @options[:tab_key] || @options[:pad_shoulders] || @options[:arrows] ? true : false
        end

        # Tells whether the tabs are stops of the arrows and of Tab: while no key steps them.
        #
        # @return [Boolean] Whether they are.
        def stops?
          !keyed?
        end

        # Follows a changed option: with a key that steps the tabs they leave the arrows' way unless
        # they are stops, and a new font size reaches every tab.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          @header.children.each { |tab| tab.focusable = stops? } if [:shoulder, :tab_key, :pad_shoulders, :arrows].include?(name)
          @header.children.each { |tab| tab.font_size = @options[:font_size] } if name == :font_size
        end
      end

      # The page of one tab of Tabs, a column by default, told apart in C#'s tree from the other parts
      # the tabs hold, so the focus of a page that hides goes into the page shown and cancel in a page
      # of a layer root walks back the way the focus came into it.
      class TabPage < Stack
        # Tells the properties C#'s tree lays it out by, marked as a page of tabs.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["tab_page"] = true
          props
        end
      end

      # One tab of Tabs: a button on the picked plate while its page shows.
      class Tab < Button
        # Makes the tab.
        #
        # @param tabs [Tabs] Its Tabs.
        # @param place [Integer] Its place among them.
        # @param options [Hash] Its options.
        def initialize(tabs, place, options = {})
          super(options)
          @tabs = tabs
          @place = place
        end

        # Takes an event of C#'s tree: a click picks its page.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          super
          @tabs.clicked(@place) if name == "click"
          @tabs.mark_panel if name == "focus"
        end

        # Shows or hides the tab and its page.
        #
        # @param value [Boolean] Whether it shows.
        def visible=(value)
          super
          @tabs.show_chosen
        end

        private

        # Tells the plate's color: picked while its page shows, in its own :color when it has one.
        #
        # @return [Symbol, Integer, Color] A color.
        def plate_fill
          return :tab unless @tabs.index == @place

          @options[:color] || :picked
        end

        # Tells its text's color: its own :color while its page hides, else the text on its plate
        # (Component#text_on).
        #
        # @return [Symbol, Integer, Color] A color.
        def text_color
          return @options[:color] if @options[:color] && @tabs.index != @place

          text_on(plate_fill)
        end

        # Tells the height of its text's line: its font's, so a tab in the small font takes a lower row.
        #
        # @return [Integer] The pixels.
        def line_height
          UI.line_height_of(@options[:font_size])
        end
      end
    end
  end
end
