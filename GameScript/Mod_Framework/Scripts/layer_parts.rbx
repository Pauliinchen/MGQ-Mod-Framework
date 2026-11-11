#----------------------------------------------------------------
#  layer_parts.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Told a match an autocomplete takes to on_complete with its place, as a text field tells a completion
#      Paulinchen  2026-11-09: Put the parts of a header's title_after: right after its title
#                            - Gave a chip of a chip set its icons:
#                            - Handed a part the markup of the tooltips of its slots or lines
#      Paulinchen  2026-11-07: Gave a chip set only the chips it shows, now that chips take no input
#                            - Read the text of an autocomplete for its required: and validate:
#                            - Offered an autocomplete its matches for its whole text, matched by the rule worked out in C#
#                            - Gave a radio group its radios and the radio its bound state picks
#                            - Followed the value: of a rating
#                            - Followed the bound value of a slider
#                            - Put the part of a header's trailing: at the end of its title row
#                            - Handed a chip's variant: to its chip set
#                            - Kept the tooltip block, note block, completions, links, steered list and error label on the part
#                            - Linked only the submit_to: of a list, since cancel_to: is gone
#                            - Marked a disabled chip or select entry with :disabled
#      Paulinchen  2026-11-06: Followed the bound number of a numeric field alone, now that the digit field is gone
#                            - Made the handles plain objects
#                            - Adopted through Adopt.adopt, since UI.adopt is gone
#                            - Answered is_a? and the other calls every object answers from PartHandle, so a scene's variables may hold it
#                            - Gave the handle of a component its render made focus, which moves the focus into that component
#                            - Moved the focus to the part a part's cancel_to: names on cancel and to the part a list's
#                              submit_to: names after a pick, each found once its window is made
#                            - Gave every part's handle focus, which moves the focus onto the part
#                            - Told a text field's on_cancel the cancel that stopped its typing
#                            - Moved the focus of slides with enter: onto the page their bound state slides to
#                            - Played the cancel sound of a joined window only where its game window's cancel does something
#      Paulinchen  2026-11-05: Hid a joined window and its game window while the roots its handler opened are open, and gave
#                              it the keys back on the part that held them as they closed
#                            - Handed out a handle of a component the render made, with the calls its class declares
#                            - Put a header's note after its subtitle, and dropped the stats that judged themselves
#                            - Put what a group holds under its heading and what a field holds after its caption
#                            - Followed whether a checkbox or a switch is on by its bound state
#                            - Checked an input's required: and validate: and showed its error under it, sent a form
#                              whose inputs are fine and moved on from an input that confirms to the next
#                            - Let a text field steer a log, which its Up, Down, Page Up and Page Down scroll
#                            - Followed a digit field's bound number and told its change and submit
#                            - Kept the tab a state binds while a render lacks it, and put the parts of tabs_subheader under
#                              the row of tabs
#                            - Logged a slide a page refused
#                            - Dropped following pulse: of sockets, which the pulse call of their handle replaces
#                            - Handed out a part's handle, whose calls its built-in declares
#                            - Lined a select's menu up with the list its steer: names
#                            - Joined a window to the game window it lies beside, one cursor between them, and gave cancel to
#                              the game window
#                            - Put an alert's buttons between its text and its close mark
#                            - Opened and closed a drawer by its bound state, its header at its top and the rest in its body,
#                              one over the rest as a root inside the edge of what it lies in that gives the focus back
#                              as it closes
#                            - Told a list's on_reorder the item the player moved and its new place, the rows kept as the
#                              items say until they change
#                            - Narrowed a text field's completions to the last word typed, or asked its lambda for them
#                            - Looked for the parts that steer a list only while some wait
#      Paulinchen  2026-11-04: Followed a text field's bound text, completions and steered list, found once its window is made,
#                              the entries and values of chips and a select, a select's single value, and a list's pick
#                              without on_submit
#                            - Offered Remove in a chip set's context menu for a closeable chip
#                            - Put the parts of an item header's note after its line and those of a sockets' note at the end
#                              of each gem's tooltip, and pulsed the sockets a pulse: names
#                            - Added a character's stats that read themselves anew and judge a change against what showed before
#                            - Showed a tooltip's content for the part it wraps, to the pointer and the keys, on its side:
#                            - Added the tabs of the UI layer, their pages with the look of their tabs, the tab bound to a
#                              state, and a row of tabs that wraps
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The page of a tab of the UI layer, which carries what its tab shows: its title, badge,
      # color, icon, tooltip and whether it shows and takes a pick.
      class LayerTabPage < TabPage
        # Tells the defaults of the options: no look of a tab yet.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:tab_look => nil)
        end

        options :tab_look

        private

        # Follows a changed option: a new look reaches its tab.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          parent.look_changed(self) if name == :tab_look && parent.respond_to?(:look_changed)
        end
      end

      # The parts of tabs_subheader, which lie under the row of tabs and over every page.
      class TabsSubheader < Stack
      end

      # Tabs of the UI layer: its tabs come from the pages a render describes, each with its tab's
      # look, the parts of its tabs_header lie before the tabs in their row, which with :wrap goes on
      # in a new row when full, and those of its tabs_subheader under that row, over every page. In a
      # root of the layer C#'s tree steps them by Tab and the pad's shoulders, so they stay off the
      # arrows' way unless they are a bar alone.
      class LayerTabs < Tabs
        # Tells the defaults of the options: the tabs in one row.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:wrap => false)
        end

        options :wrap

        # Makes the tabs, their row wrapping with :wrap, and the room under it for tabs_subheader.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @under = add(Stack.new(:layout => :column, :gap => 0, :visible => false), 1)
          wrap_tabs
        end

        # Tells the properties C#'s tree routes the keys by, without the old screens' own key
        # settings, so the tree works them out from the layer.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props.delete("tab_key")
          props.delete("pad_shoulders")
          props
        end

        # Takes the engine parts a render put into the tabs: the pages, each making its tab anew
        # when they changed, the parts of tabs_header before the tabs and those of tabs_subheader
        # under them.
        #
        # @param wanted [Array<Component>] The engine parts, in the order they were described.
        def layer_sync(wanted)
          pages = wanted.select { |part| part.is_a?(LayerTabPage) }
          under = wanted.select { |part| part.is_a?(TabsSubheader) }
          sync_header(wanted - pages - under)
          sync_under(under)
          pages == @pages ? @pages.each_index { |place| refresh_tab(place) } : take_pages(pages)
        end

        # Draws the tab of a page anew once the page's look changed.
        #
        # @param page [LayerTabPage] The page.
        def look_changed(page)
          place = @pages.index(page)
          refresh_tab(place) if place
        end

        private

        # Follows a changed option: :wrap lets the row of tabs go on in a new row.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          wrap_tabs if name == :wrap
        end

        # Lets the row of tabs take the room left beside tabs_header and go on in a new row when full,
        # with :wrap.
        def wrap_tabs
          wrap = @options[:wrap] ? true : false
          @header.wrap = wrap
          @header.grow = wrap ? 1 : 0
          @header.shrink = wrap
        end

        # Tells whether keys step the tabs, so they stay off the arrows' way: always, but for a bar
        # alone.
        #
        # @return [Boolean] Whether they do.
        def keyed?
          @options[:pages] != false
        end

        # Puts the parts of tabs_header before the tabs in their row.
        #
        # @param parts [Array<Component>] The parts.
        def sync_header(parts)
          old = @bar.children.reject { |child| child.equal?(@header) }
          return if old == parts

          (old - parts).each { |child| @bar.remove(child) }
          parts.each_with_index { |child, place| @bar.add(child, place) unless @bar.children[place].equal?(child) }
        end

        # Puts the parts of tabs_subheader under the row of tabs, a room that hides without them.
        #
        # @param parts [Array<TabsSubheader>] The parts.
        def sync_under(parts)
          old = @under.children
          return if old == parts

          (old - parts).each { |child| @under.remove(child) }
          parts.each_with_index { |child, place| @under.add(child, place) unless @under.children[place].equal?(child) }
          @under.visible = !parts.empty?
        end

        # Makes the tabs anew for other pages, keeping the page picked, else the place picked.
        #
        # @param pages [Array<LayerTabPage>] The pages.
        def take_pages(pages)
          picked = @pages[@options[:index].to_i]
          (@pages - pages).each { |page| remove(page) if page.parent.equal?(self) }
          @header.clear
          @pages = []
          pages.each_with_index do |page, place|
            page.visible = false
            @header.add(Tab.new(self, place, :font_size => @options[:font_size], :focusable => stops?))
            @pages << page
            add(page, place + 2) unless children[place + 2].equal?(page)
            refresh_tab(place)
          end
          @chosen = pages.index(picked) || UI.within(@chosen.to_i, 0, [pages.size - 1, 0].max)
          show_chosen
        end

        # Gives a tab its page's look.
        #
        # @param place [Integer] The tab's place.
        def refresh_tab(place)
          tab = @header.children[place]
          look = @pages[place].tab_look || {}
          return unless tab

          tab.text = look[:text].to_s
          tab.badge = look[:badge]
          tab.color = look[:color]
          tab.icon = look[:icon]
          tab.tooltip = look[:tooltip]
          tab.enabled = look[:enabled] != false
          tab.visible = look[:visible] != false unless tab.visible? == (look[:visible] != false)
        end
      end

      # How the built-ins that hold their parts their own way follow what a render describes: the
      # slides and the tabs with their bound page and tab.
      module Layer
        # Hands the slides' page changes to its bound state and on_change, and asks the page coming
        # into view whether it may.
        #
        # @param part [Part] The slides' part.
        def self.wire_slides(part)
          part.engine.on(:change) { |place| slid(part, place) }
          part.engine.on(:slide) { |place| slide_allowed?(part, place) }
        end

        # Puts the slides on the page their bound state holds: at once on their first render, by a
        # slide after it, with enter: the focus onto that page, and writes the page back once the
        # slides kept it on their pages.
        #
        # @param part [Part] The slides' part.
        def self.bind_slides(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          engine = part.engine
          wanted = owner.__send__(bind)
          if wanted.is_a?(Integer) && wanted != engine.index
            first = part.index.nil?
            quietly { first ? engine.index = wanted : engine.slide_to(wanted) }
            focus_page(part, engine.index) if !first && part.node.params[:enter]
          end
          part.index = engine.index
          write_bound(owner, bind, engine.index) unless wanted == engine.index
        end

        # Moves the focus onto a page of slides: onto its part with autofocus: that shows, else onto
        # its first key stop at the next layout.
        #
        # @param part [Part] The slides' part.
        # @param place [Integer] The page, from 0.
        def self.focus_page(part, place)
          page = part.children.select { |child| child.is_a?(Part) && child.node.type == :slide }[place]
          return unless page

          wanted = autofocused(page)
          wanted ? wanted.engine.focus : Tree.focus_in(page.engine)
        end
        private_class_method :focus_page

        # Finds the first part inside a part, in tree order, that has autofocus: and shows.
        #
        # @param item [Part, Mount] Where to look.
        # @return [Part, nil] The part, nil for none.
        def self.autofocused(item)
          item.children.each do |child|
            next if child.respond_to?(:gone) && child.gone
            next if child.is_a?(Part) && child.node.params[:visible] == false

            return child if child.is_a?(Part) && child.node.params[:autofocus] && !child.node.params[:disabled]

            found = autofocused(child)
            return found if found
          end
          nil
        end
        private_class_method :autofocused

        # Takes a slide that started: the bound state and on_change hear its first page.
        #
        # @param part [Part] The slides' part.
        # @param place [Integer] The first page shown.
        def self.slid(part, place)
          return if @applying || part.gone

          part.index = place
          bind = part.node.params[:bind]
          write_bound(part.node.owner, bind, place) if bind
          call_handler(part.node.owner, part.node.params[:on_change], [place])
        end
        private_class_method :slid

        # Tells whether the slides may start at a page: the page it brings into view does not
        # refuse with can_enter: false, else on_refuse hears that page.
        #
        # @param part [Part] The slides' part.
        # @param place [Integer] The first page it would show.
        # @return [Boolean] Whether it may.
        def self.slide_allowed?(part, place)
          return true if part.gone

          engine = part.engine
          coming = place > engine.index ? place + [part.options[:shown].to_i, 1].max - 1 : place
          page = engine.pages[coming]
          slide = page && part.children.find { |child| child.is_a?(Part) && child.engine.equal?(page) }
          return true unless slide && param_now(slide, :can_enter) == false

          named = part.node.params[:id] ? " #{part.node.params[:id]}" : ""
          log("#{part.node.owner.class.name}: the slides#{named} refused page #{coming + 1}#{slide.node.params[:id] ? " (#{slide.node.params[:id]})" : ''}: its can_enter: is false")
          call_handler(part.node.owner, part.node.params[:on_refuse], [coming])
          false
        end
        private_class_method :slide_allowed?

        # Hands the tab the player picks to the tabs' bound state and on_change.
        #
        # @param part [Part] The tabs' part.
        def self.wire_tabs(part)
          part.engine.on(:change) do |place|
            next if @applying || part.gone

            value = tab_value(part, place)
            bind = part.node.params[:bind]
            write_bound(part.node.owner, bind, value) if bind
            call_handler(part.node.owner, part.node.params[:on_change], [value])
          end
        end

        # Picks the tab the tabs' bound state holds, by its id or its place. While this render lacks
        # that tab the first one shows and the state keeps it, so it comes back with its tab; a
        # state that holds no tab yet takes the one shown.
        #
        # @param part [Part] The tabs' part.
        def self.bind_tabs(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          engine = part.engine
          wanted = owner.__send__(bind)
          tabs = tab_parts(part)
          place = tabs.index { |tab| !tab.node.params[:id].nil? && tab.node.params[:id] == wanted }
          place ||= wanted if wanted.is_a?(Integer) && wanted >= 0 && wanted < tabs.size
          shown = place || 0
          quietly { engine.index = shown } if shown != engine.index
          write_bound(owner, bind, tab_value(part, engine.index)) if wanted.nil?
        end

        # Tells the tabs a tabs part holds, in their order.
        #
        # @param part [Part] The tabs' part.
        # @return [Array<Part>] The tabs' parts.
        def self.tab_parts(part)
          parts = []
          collect_parts(part.children, parts)
          parts.select { |each| each.node.type == :tab }
        end
        private_class_method :tab_parts

        # Tells what stands for a tab: its id, else its place.
        #
        # @param part [Part] The tabs' part.
        # @param place [Integer] The tab's place.
        # @return [Object] The id or the place.
        def self.tab_value(part, place)
          tab = tab_parts(part)[place.to_i]
          tab && tab.node.params[:id] ? tab.node.params[:id] : place
        end
        private_class_method :tab_value

        # Puts the parts a tooltip wraps into its engine part, and has its content show as the
        # tooltip of the wrapper and of the first part inside, on its side:, so the pointer and the
        # keys both show it; the content's engine part goes into each tooltip box as it opens.
        #
        # @param part [Part] The tooltip's part.
        # @param wanted [Array<Component>] The engine parts of what it holds.
        def self.sync_tooltip(part, wanted)
          content = slot_engine(part, :content)
          inside = wanted.reject { |each| each.equal?(content) }
          engine = part.engine
          (engine.children - inside).each { |child| engine.remove(child) }
          inside.each_with_index { |child, place| engine.add(child, place) unless engine.children[place].equal?(child) }
          tip = part.tip ||= lambda { |box| box.add(slot_engine(part, :content)) unless part.gone }
          engine.tooltip = tip unless engine.tooltip.equal?(tip)
          engine.tooltip_side = part.node.params[:side]
          first = inside.first
          first.tooltip = tip if first && first.tooltip.nil?
          first.tooltip_side = engine.tooltip_side if first && first.tooltip.equal?(tip)
        end

        # Puts the parts of a header's note after its subtitle, the part of its title_after: right
        # after its title and the part of its trailing: at the end of its title's row, also after the
        # header made itself anew.
        #
        # @param part [Part] The header's part.
        # @param wanted [Array<Component>] The engine parts of what it holds.
        def self.sync_header_note(part, wanted)
          trailing = slot_engine(part, :trailing)
          after = slot_engine(part, :title_after)
          notes = wanted.reject { |child| child.equal?(trailing) || child.equal?(after) }
          row = part.engine.subtitle_row
          row.children.drop(1).each { |child| row.remove(child) unless notes.include?(child) }
          notes.each_with_index { |child, place| row.add(child, place + 1) unless row.children[place + 1].equal?(child) }
          part.engine.trailing = trailing
          part.engine.title_after = after
        end

        # Hands a part the markup of its note: as a block that puts the note's engine part into a box,
        # such as each tooltip box of its slots or lines as it opens, as a tooltip's content goes; nil
        # without note:. It hands the markup of the tooltips of its slots or lines the same way, by
        # their numbers, see Builtins.markup_tips.
        #
        # @param part [Part] The part.
        def self.sync_note(part)
          engine = part.engine
          note = nil
          if slot_engine(part, :note)
            note = part.note_block ||= lambda { |box| shown = slot_engine(part, :note); box.add(shown) if shown && !part.gone }
          end
          engine.note = note unless engine.note.equal?(note)
          tips = part.tips_block ||= lambda { |key, box| shown = slot_engine(part, [:tip, key]); box.add(shown) if shown && !part.gone }
          engine.tips = tips unless engine.tips.equal?(tips)
        end

        # Hands what a text field tells to its bound state and its handlers.
        #
        # @param part [Part] The text field's part.
        def self.wire_text_field(part)
          engine = part.engine
          engine.on(:change) do |text|
            follow_completions(part)
            bound_changed(part, text)
          end
          engine.on(:submit) { |text| input_submitted(part, text) }
          engine.on(:revert) { dispatch(part, :on_revert, []) }
          engine.on(:key) { |name| dispatch(part, :on_key, [name]) }
          engine.on(:complete) { |text, place| dispatch(part, :on_complete, [text, place]) }
          engine.on(:type) { dispatch(part, :on_type, []) }
          engine.on(:refuse) { dispatch(part, :on_refuse, []) }
          engine.on(:cancelled) { dispatch(part, :on_cancel, []) }
        end

        # Hands what an autocomplete tells to its bound state and its handlers: a match taken tells
        # on_complete with its place, as a text field tells a completion taken.
        #
        # @param part [Part] The autocomplete's part.
        def self.wire_autocomplete(part)
          engine = part.engine
          engine.on(:change) do |text|
            follow_completions(part)
            bound_changed(part, text)
          end
          engine.on(:submit) { |text| input_submitted(part, text) }
          engine.on(:complete) { |text, place| dispatch(part, :on_complete, [text, place]) }
        end

        # Gives a text field the text its bound state holds, the completions it offers and the list
        # it steers, each only once it changed.
        #
        # @param part [Part] The text field's part.
        def self.follow_text_field(part)
          engine = part.engine
          bind = part.node.params[:bind]
          owner = part.node.owner
          if bind && bound_state?(owner, bind)
            text = owner.__send__(bind).to_s
            quietly { engine.text = text } unless engine.text == text
          end
          follow_completions(part)
          follow_steer(part)
        end

        # Gives a numeric field the number its bound state holds, once it changed.
        #
        # @param part [Part] The numeric field's part.
        def self.follow_numeric_field(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          number = owner.__send__(bind).to_i
          quietly { part.engine.value = number } unless part.engine.value == number
        end

        # Gives an input the value its bound state holds, once it changed, such as a slider's number;
        # without a bind: the value its value: gives, once that changed, so the player's change stays
        # between.
        #
        # @param part [Part] The input's part.
        def self.follow_value(part)
          params = part.node.params
          bind = params[:bind]
          if bind
            return unless bound_state?(part.node.owner, bind)

            held = part.node.owner.__send__(bind)
          else
            held = params[:value]
            return if held.nil? || part.value_given == [held]

            part.value_given = [held]
          end
          quietly { part.engine.value = held } unless held.nil? || part.engine.value == held
        end

        # Gives a group its items from the parts it holds that only give it a value, such as the
        # radios of a radio group, once they changed.
        #
        # @param part [Part] The group's part.
        # @param type [Symbol] The type of the parts that are its items, such as :radio.
        # @param text [Symbol] The param that holds an item's text, such as :label.
        def self.sync_held_items(part, type, text)
          items = part.children.select { |child| child.is_a?(Part) && child.node.type == type }.map do |child|
            params = child.node.params
            item = { :text => params[text].to_s, :value => params.key?(:value) ? params[:value] : params[text].to_s, :disabled => params[:disabled] == true }
            item[:icon] = params[:icon] if params[:icon]
            item[:tooltip] = params[:tooltip].to_s if params[:tooltip]
            item
          end
          part.engine.items = items unless part.engine.items == items
        end

        # Gives a group the value its bound state holds once it changed, such as the radio picked;
        # nil picks none.
        #
        # @param part [Part] The group's part.
        def self.follow_picked(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          held = owner.__send__(bind)
          quietly { part.engine.value = held } unless part.engine.value == held
        end

        # Gives a checkbox or a switch whether it is on as its bound state holds it, once it changed:
        # nil stays nil only for a checkbox with tri_state:.
        #
        # @param part [Part] The checkbox's or the switch's part.
        def self.follow_on_off(part)
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          held = owner.__send__(bind)
          held = held ? true : false unless held.nil? && part.node.params[:tri_state]
          quietly { part.engine.checked = held } unless part.engine.checked == held
        end

        # Shows a text field's completions for the last word typed, or an autocomplete's matches for
        # its whole text, once they changed: the words of an Array that hold it anywhere, ignoring
        # case, or what a lambda of it answers.
        #
        # @param part [Part] The text field's or the autocomplete's part.
        def self.follow_completions(part)
          engine = part.engine
          wanted = completions_for(part, engine.whole ? engine.text.to_s : engine.text.to_s.split(" ", -1).last.to_s)
          return if wanted == part.completions

          part.completions = wanted
          engine.completions = wanted
        end
        private_class_method :follow_completions

        # Tells the completions of a text field for a word, or an autocomplete's matches for its text,
        # by TextMatch's rule for an Array.
        #
        # @param part [Part] The text field's or the autocomplete's part.
        # @param word [String] The last word typed, or the autocomplete's whole text.
        # @return [Array<String>] The completions.
        def self.completions_for(part, word)
          source = part.node.params[part.node.type == :autocomplete ? :items : :completions]
          return Array(source.call(word)).map { |each| each.to_s } if source.is_a?(Proc)

          TextMatch.matches(word, Array(source))
        rescue StandardError => e
          Errors.report(e, "the completions: of #{part.node.type}")
          []
        end
        private_class_method :completions_for

        # Notes a text field or a select whose steer: names a list, or a text field's a log, which
        # resolve_steers finds once the whole window is made; one without steer: lets go of what it
        # steered.
        #
        # @param part [Part] The text field's or the select's part.
        def self.follow_steer(part)
          return steer_list(part, nil) unless part.node.params[:steer]

          @steers << part unless @steers.include?(part)
        end

        # Has each part noted by follow_steer steer the list or the log its steer: names in its
        # window, once the window has its root, logging a name that names none of them once.
        def self.resolve_steers
          return if @steers.empty?

          pending = @steers
          @steers = []
          pending.each do |part|
            next if part.gone
            next @steers << part unless part.top && part.top.root

            name = part.node.params[:steer]
            list = name && find_part(part.top.root, name)
            next steer_list(part, list.engine) if list && steerable?(part, list)

            Errors.hint([:steer, part.node.owner.class, name], nil, "#{part.node.type} steer: :#{name} names no #{part.node.type == :text_field ? 'list or log' : 'list'} in its window") if name
          end
        end

        # The params that name another part of the window the focus moves to, each with the engine's
        # option it sets.
        LINKS = { :submit_to => :submit_to }

        # Notes a part whose submit_to: names another part, or named one before, which
        # resolve_links links once the whole window is made.
        #
        # @param part [Part] The part.
        def self.follow_links(part)
          named = LINKS.keys.any? { |name| part.node.params[name] }
          linked = part.links
          @links << part if (named || linked) && !@links.include?(part)
        end

        # Gives each part noted by follow_links the engine part of the id its submit_to: names in its
        # window, nil for a param it dropped, logging a name that names no part once.
        def self.resolve_links
          return if @links.empty?

          pending = @links
          @links = []
          pending.each do |part|
            next if part.gone
            next @links << part unless part.top && part.top.root

            linked = {}
            LINKS.each do |name, option|
              id = part.node.params[name]
              target = id && find_part(part.top.root, id)
              Errors.hint([name, part.node.owner.class, id], nil, "#{part.node.type} #{name}: :#{id} names no part in its window") if id && !target
              next unless target || part.engine.respond_to?(option)

              value = target ? target.engine : nil
              linked[name] = value if value
              part.engine.__send__("#{option}=", value) unless part.engine.__send__(option).equal?(value)
            end
            part.links = linked.empty? ? nil : linked
          end
        end

        # Tells whether a part may steer another: a list, and for a text field a log too.
        #
        # @param part [Part] The text field's or the select's part.
        # @param steered [Part] The part its steer: names.
        # @return [Boolean] Whether it may.
        def self.steerable?(part, steered)
          steered.node.type == :list || (steered.node.type == :log && part.node.type == :text_field)
        end
        private_class_method :steerable?

        # Has a text field or a select steer a list, or a text field a log, unless it steers that one
        # already.
        #
        # @param part [Part] The text field's or the select's part.
        # @param list [List, LogView, nil] The engine part of the list or the log, nil for none.
        def self.steer_list(part, list)
          return if part.steered.equal?(list)

          part.steered = list
          part.engine.steer(list)
        end
        private_class_method :steer_list

        # Finds the part of an id below a part.
        #
        # @param item [Part, Mount] Where to look.
        # @param id [Symbol, String] The id.
        # @return [Part, nil] The part, nil for none.
        def self.find_part(item, id)
          return item if item.is_a?(Part) && !item.node.params[:id].nil? && item.node.params[:id].to_s == id.to_s

          item.children.each do |child|
            found = find_part(child, id)
            return found if found
          end
          nil
        end
        private_class_method :find_part

        # Takes a list's pick: its own on_submit hears the item, else the nearest part around it with
        # one, as C#'s tree sends a pick up; a text field that steers the list picks this way.
        #
        # @param part [Part] The list's part.
        # @param index [Integer] The row picked.
        def self.list_submitted(part, index)
          taker = part
          taker = taker.parent until taker.nil? || (taker.is_a?(Part) && taker.node.type != :form && !taker.node.params[:on_submit].nil?)
          dispatch(taker, :on_submit, [item_at(part, index)]) if taker
        end

        # Takes a row the player moved by a drag or the move hotkeys: on_reorder hears the item and its
        # new place among the items, a bind_index: the new place, and the rows go back to the order of
        # the items, which the handler changes when it takes the move. A row carried and put back where
        # it came from tells nothing.
        #
        # @param part [Part] The list's part.
        # @param from [Integer] The row's place before the move.
        # @param to [Integer] Its place after it.
        def self.list_reordered(part, from, to)
          return if @applying || part.gone || from == to

          item = item_at(part, from)
          params = part.node.params
          quietly { part.engine.rows = Builtins.list_rows(params, Array(part.items)) }
          part.index = to
          write_bound(part.node.owner, params[:bind_index], to) if params[:bind_index]
          call_handler(part.node.owner, params[:on_reorder], [item, to])
        end

        # Tells whether a drawer's params ask for it open: its bound state, else its open:.
        #
        # @param params [Hash] The drawer's params.
        # @param owner [Object, nil] The component that renders it, which holds the bound state.
        # @return [Boolean] Whether they do.
        def self.drawer_wanted?(params, owner = nil)
          bind = params[:bind]
          return params[:open] == true unless bind

          owner && owner.respond_to?(bind) && owner.__send__(bind) ? true : false
        end

        # Has a drawer over the rest tell its close: its bound state turns false, on_change hears
        # false, and the focus goes back where it was as it opened.
        #
        # @param part [Part] The drawer's part.
        def self.wire_drawer(part)
          part.engine.on(:close) { |why| drawer_closed(part, why) } if part.options[:floating]
        end

        # Puts what a drawer holds into it: its header at its top, the rest into its body.
        #
        # @param part [Part] The drawer's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_drawer(part, wanted)
          engine = part.engine
          header = engine_parts(part.children.select { |child| child.is_a?(Part) && child.node.type == :drawer_header }, [])
          body = wanted - header
          keep_in(engine, header + [engine.body])
          keep_in(engine.body, body)
        end

        # What a game window beside a joined window hands the keys to: the window, focused on the part
        # inside that held the focus last, else its first.
        JoinedFocus = Struct.new(:root) do
          # Gives the part inside the window the focus.
          def focus
            Tree.focus_in(root)
          end
        end

        # Joins a window with join: to the game window its beside: names, once for each class and
        # side: the game window's adoption hands the keys over by the arrows (Adopted#add_side), to the
        # newest open window joined there.
        #
        # @param part [Part] The window's part.
        def self.follow_join(part)
          params = part.node.params
          return unless params[:join] && params[:beside].to_s =~ Placement::GAME_WINDOW && Object.const_defined?(params[:beside].to_s)

          key = [params[:beside].to_s, params[:side] == :right ? :right : :left]
          (@joins ||= {})[key] = part
          return if (@joined ||= {})[key]

          @joined[key] = true
          Adopt.adopt(Object.const_get(key[0])).add_side(key[1]) { |_window| Layer.joined_focus(key) }
        end

        # Tells what a game window hands the keys to: the newest open window joined to it.
        #
        # @param key [Array] The game window's class name and the side.
        # @return [JoinedFocus, nil] The window to focus, nil while none is open.
        def self.joined_focus(key)
          part = (@joins || {})[key]
          part && !part.gone && part.engine.open? ? JoinedFocus.new(part.engine) : nil
        end

        # Does what cancel does in a joined window's game window, its cancel handler with the cancel
        # sound, and keeps the window open; without a handler, as on the title, cancel does nothing
        # and plays no sound.
        #
        # @param part [Part] The window's part.
        # @return [Boolean] false, so the window stays.
        def self.join_cancel(part)
          window = Placement.game_window(part.node.params[:beside].to_s)
          return false unless window && window.respond_to?(:handle?) && window.handle?(:cancel)

          Sound.play_cancel
          window.call_handler(:cancel)
          false
        end

        # Hides a window joined to a game window, and that game window, while the screens a handler
        # of the window opened are open, such as one the title's Mods box opens; once they all closed
        # both show again and the window takes the keys back on the part, and the row, that held
        # them.
        #
        # Only roots that hold the game's buttons count, so a toast the handler shows hides nothing.
        #
        # @param part [Part] The joined window's part.
        # @param before [Array<Component>] The roots open before the handler ran.
        def self.hide_join_while_opened(part, before)
          opened = Tree.roots.select { |root| root.open? && root.holds_buttons? && before.none? { |each| each.equal?(root) } }
          window = Placement.game_window(part.node.params[:beside].to_s)
          return if opened.empty? || window.nil?

          hid = window.visible
          window.visible = false if hid
          log("#{part.node.params[:id] || part.node.type} hides with its #{window.class} while #{opened.map { |root| root.describe }.join(', ')} " \
              "#{opened.size == 1 ? 'is' : 'are'} open")
          given = false
          opened.each do |root|
            root.on(:close) do |why|
              next if why == :reset || given || opened.any? { |each| each.open? }

              given = true
              window.visible = true if hid && !window.disposed?
              Tree.focus_in(part.engine) if !part.gone && part.engine.open?
            end
          end
        end

        # Puts what a group holds under its heading.
        #
        # @param part [Part] The group's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_group(part, wanted)
          keep_in(part.engine, [part.engine.head] + wanted)
        end

        # Puts what a field holds into its column after its caption.
        #
        # @param part [Part] The field's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_field(part, wanted)
          keep_in(part.engine.body, wanted)
        end

        # Puts what an alert holds between its text and its close mark.
        #
        # @param part [Part] The alert's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_alert(part, wanted)
          engine = part.engine
          keep_in(engine, [engine.label] + wanted + [engine.close_mark].compact)
        end

        # Keeps exactly some engine parts in a container, in their order.
        #
        # @param container [Engine::Component] The container.
        # @param wanted [Array<Engine::Component>] The parts.
        def self.keep_in(container, wanted)
          return if container.children == wanted

          (container.children - wanted).each { |child| container.remove(child) }
          wanted.each_with_index { |child, place| container.add(child, place) unless container.children[place].equal?(child) }
        end
        private_class_method :keep_in

        # Opens or shuts a drawer as its bound state or open: asks: one beside the rest shows or hides
        # its body, one over the rest opens as a root inside the edge of what it lies in and takes
        # the focus, noting where the focus was.
        #
        # @param part [Part] The drawer's part.
        def self.follow_drawer(part)
          wanted = drawer_wanted?(part.node.params, part.node.owner)
          engine = part.engine
          return engine.open_now = wanted unless part.options[:floating]

          was = part.open_wanted
          part.open_wanted = wanted
          if wanted && !was && !engine.open?
            holder = part.parent
            holder = holder.parent until holder.nil? || holder.is_a?(Part)
            part.beside = Tree.focused
            engine.beside = holder ? holder.engine : nil
            engine.open
          elsif !wanted && engine.open?
            engine.close(:script)
          end
        end

        # Takes the close of a drawer over the rest: its bound state turns false, on_change hears it
        # unless the owner closed it, and the focus goes back where it was.
        #
        # @param part [Part] The drawer's part.
        # @param why [Symbol] Why it closed.
        def self.drawer_closed(part, why)
          part.open_wanted = false
          back = part.beside
          part.beside = nil
          back.focus if back.is_a?(Component) && back.shown?
          return if part.gone || why == :script

          bind = part.node.params[:bind]
          write_bound(part.node.owner, bind, false) if bind
          call_handler(part.node.owner, part.node.params[:on_change], [false])
        end

        # Takes a value a part tells as the player changed it: its bound state and on_change hear it.
        #
        # @param part [Part] The part.
        # @param value [Object] The value, such as a text or the values that are on.
        def self.bound_changed(part, value)
          return if @applying || part.gone

          bind = part.node.params[:bind]
          write_bound(part.node.owner, bind, value) if bind
          call_handler(part.node.owner, part.node.params[:on_change], [value])
          input_changed(part) if part.node.declaration.params.key?(:validate)
        end

        # Takes the values of a select as the player changed them: its bound state and on_change
        # hear them, a select without multi: its single value.
        #
        # @param part [Part] The select's part.
        # @param values [Array] The values that are on.
        def self.choices_changed(part, values)
          bound_changed(part, single_choice?(part) ? values.first : values)
        end

        # Gives a chip set its chips from the chip parts it holds.
        #
        # @param part [Part] The chip set's part.
        def self.sync_chips(part)
          chips = part.children.select { |child| child.is_a?(Part) && child.node.type == :chip }.map do |child|
            params = child.node.params
            chip = { :text => params[:text].to_s }
            chip[:icon] = params[:icon] if params[:icon]
            chip[:icons] = Array(params[:icons]) if params[:icons]
            chip[:tooltip] = params[:tooltip].to_s if params[:tooltip]
            chip[:color] = Builtins.color(params[:color]) if params[:color]
            chip[:variant] = params[:variant] if params[:variant]
            chip
          end
          part.engine.items = chips unless part.engine.items == chips
        end

        # Gives a select its entries from the parts they hold, and the values its bound state holds:
        # an Array, or without multi: a single value, nil for none.
        #
        # @param part [Part] The select's part.
        # @param type [Symbol] The type of the parts that are its entries, :select_item.
        def self.sync_choices(part, type)
          entries = part.children.select { |child| child.is_a?(Part) && child.node.type == type }.map do |child|
            params = child.node.params
            entry = { :text => params[:text].to_s, :value => params.key?(:value) ? params[:value] : params[:text].to_s, :disabled => params[:disabled] == true }
            entry[:icon] = params[:icon] if params[:icon]
            entry[:tooltip] = params[:tooltip].to_s if params[:tooltip]
            entry
          end
          engine = part.engine
          engine.items = entries unless engine.items == entries
          bind = part.node.params[:bind]
          owner = part.node.owner
          return unless bind && bound_state?(owner, bind)

          held = owner.__send__(bind)
          single = single_choice?(part)
          wanted = single ? (held.nil? ? [] : [held]) : Array(held)
          engine.values = wanted unless engine.values == wanted
          now = single ? engine.values.first : engine.values
          write_bound(owner, bind, now) unless now == (single ? held : wanted)
        end

        # Tells whether a part binds a single value: a select without multi:.
        #
        # @param part [Part] The select's part.
        # @return [Boolean] Whether it does.
        def self.single_choice?(part)
          part.node.type == :select && part.node.params[:multi] != true
        end
        private_class_method :single_choice?

        # Finds the engine part of the markup a content param of a part describes.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The content param.
        # @return [Component, nil] The engine part, nil when the param is not given.
        def self.slot_engine(part, name)
          slot = part.children.find { |child| child.is_a?(Part) && child.node.type == :slot && child.node.key == name }
          slot && slot.engine
        end
        private_class_method :slot_engine

        # The error an input with required: shows while it is empty, unless required: names its own.
        REQUIRED_TEXT = "Required"

        # How an input's error shows under it: in the theme's error color, wrapped, hidden while there
        # is none.
        ERROR_LOOK = { :color => :error, :wrap => true, :visible => false }

        # Tells an input's value as the player sees it now: the text of a text field or an
        # autocomplete, a number, whether a checkbox or a switch is on, or the values of a select that
        # are on, a select without multi: its single value.
        #
        # @param part [Part] The input's part.
        # @return [Object] The value.
        def self.input_value(part)
          engine = part.engine
          case part.node.type
          when :text_field, :autocomplete then engine.text.to_s
          when :checkbox, :switch then engine.checked
          when :select then single_choice?(part) ? engine.values.first : engine.values
          else engine.value
          end
        end

        # Tells the error of an input's value: its required: while it is empty, else what its
        # validate: answers; a validate: that fails is logged once and counts as no error.
        #
        # @param part [Part] The input's part.
        # @return [String, nil] The error, nil while the value is fine.
        def self.input_error(part)
          params = part.node.params
          value = input_value(part)
          required = params[:required]
          return required.is_a?(String) ? required : REQUIRED_TEXT if !required.nil? && required != false && blank?(value)

          check = params[:validate]
          answer = case check
                   when Proc then check.call(value)
                   when Symbol then part.node.owner.__send__(check, value)
                   end
          answer.is_a?(String) && !answer.empty? ? answer : nil
        rescue StandardError => e
          Errors.report(e, "the validate: of #{part.node.type}")
          nil
        end

        # Tells whether a value counts as empty for required:: nil, false, a text of spaces alone or
        # an empty Array.
        #
        # @param value [Object] The value.
        # @return [Boolean] Whether it does.
        def self.blank?(value)
          value.nil? || value == false || (value.is_a?(String) && value.strip.empty?) || (value.is_a?(Array) && value.empty?)
        end
        private_class_method :blank?

        # Shows an input's error under it, or takes it away, in the column the markup made for it.
        #
        # @param part [Part] The input's part.
        # @param error [String, nil] The error, nil for none.
        def self.show_error(part, error)
          part.error = error
          column = part.parent
          return unless column.is_a?(Part) && column.node.type == :input_label && !column.gone

          label = column.error_label
          return if label.nil? && error.nil?

          unless label
            label = Label.new(ERROR_LOOK.merge(:font_size => Builtins.typo_size(:body2)))
            column.error_label = label
            column.engine.add(label)
          end
          label.text = error.to_s
          label.visible = !error.nil?
        end

        # Puts what an input's column holds into it: its label and the input, then the input's error.
        #
        # @param part [Part] The column's part.
        # @param wanted [Array<Engine::Component>] The engine's parts it holds, in order.
        def self.sync_input_label(part, wanted)
          error = part.error_label
          keep_in(part.engine, error ? wanted + [error] : wanted)
        end

        # Follows a value the player changed in an input: it shows its error at once unless its form
        # checks only as it is sent, and its form writes whether it is fine now.
        #
        # @param part [Part] The input's part.
        def self.input_changed(part)
          form = form_of(part)
          show_error(part, input_error(part)) unless form && form.node.params[:validate_on] == :submit
          follow_form(form) if form
        end

        # The kinds of input whose confirm moves on in a form or sends it.
        #
        # A checkbox or a switch never confirms, so counting one after the last of these would keep
        # confirm from ever sending the form.
        SUBMITTING_INPUTS = [:text_field, :numeric_field].freeze

        # Takes confirm in an input that confirms, such as Enter in a text field: its on_submit hears
        # the value; in a form, the last input that confirms sends the form and any other hands the
        # focus to the next one.
        #
        # @param part [Part] The input's part.
        # @param value [Object] The value confirm gave.
        def self.input_submitted(part, value)
          dispatch(part, :on_submit, [value])
          form = !part.gone && form_of(part)
          return unless form

          inputs = form_inputs(form).select { |input| SUBMITTING_INPUTS.include?(input.node.type) }
          place = inputs.index(part)
          return unless place

          place == inputs.size - 1 ? submit_form(form) : inputs[place + 1].engine.focus
        end

        # Sends a form: every input shows its error, and with none the form's on_submit hears it;
        # otherwise the buzzer plays, the first input with an error takes the focus and the log says
        # why.
        #
        # @param form [Part] The form's part.
        # @return [Boolean] Whether it was sent.
        def self.submit_form(form)
          return false if form.gone

          checked = form_inputs(form).map { |input| [input, input_error(input)] }
          checked.each { |input, error| show_error(input, error) }
          wrong = checked.find { |_input, error| error }
          write_valid(form, wrong.nil?)
          if wrong
            Sound.play_buzzer
            wrong[0].engine.focus
            log("#{form.node.owner.class.name}: the form#{form.node.params[:id] ? " #{form.node.params[:id]}" : ''} was not sent: #{input_name(wrong[0])}: #{wrong[1]}")
            return false
          end

          Sound.play_ok
          log("#{form.node.owner.class.name}: the form#{form.node.params[:id] ? " #{form.node.params[:id]}" : ''} was sent")
          dispatch(form, :on_submit, [])
          true
        end

        # Sends the form a part lies in, as a button with on_click: :submit does, logging one that
        # lies in none once.
        #
        # @param part [Part] The part.
        def self.submit_around(part)
          form = form_of(part)
          return submit_form(form) if form

          Errors.hint([:submit, part.node.owner.class, part.node.type], nil, "#{part.node.type} has on_click: :submit, which sends the form it lies in, but it lies in none")
        end

        # Writes whether every input of a form is fine now to the state its bind_valid: names.
        #
        # @param form [Part] The form's part.
        def self.follow_form(form)
          return if form.gone || form.node.params[:bind_valid].nil?

          write_valid(form, form_inputs(form).all? { |input| input_error(input).nil? })
        end

        # Writes whether a form is fine to the state its bind_valid: names, once it changed.
        #
        # @param form [Part] The form's part.
        # @param valid [Boolean] Whether it is.
        def self.write_valid(form, valid)
          bind = form.node.params[:bind_valid]
          owner = form.node.owner
          return unless bind && bound_state?(owner, bind)

          write_bound(owner, bind, valid) unless owner.__send__(bind) == valid
        end
        private_class_method :write_valid

        # Finds the form a part lies in.
        #
        # @param part [Part] The part.
        # @return [Part, nil] The form's part, nil for none.
        def self.form_of(part)
          step = part.parent
          step = step.parent until step.nil? || (step.is_a?(Part) && step.node.type == :form)
          step
        end
        private_class_method :form_of

        # Tells the inputs of a form that count, in their order: those that check their value, shown
        # and not disabled.
        #
        # @param form [Part] The form's part.
        # @return [Array<Part>] The inputs' parts.
        def self.form_inputs(form)
          found = []
          collect_inputs(form.children, found)
          found
        end
        private_class_method :form_inputs

        # Collects the inputs that count among parts and components, and inside them.
        #
        # @param list [Array] The parts and components.
        # @param into [Array<Part>] Where they go.
        def self.collect_inputs(list, into)
          list.each do |item|
            next if item.gone

            if item.is_a?(Part) && item.node.declaration && item.node.declaration.params.key?(:validate)
              into << item if in_view?(item.engine) && item.engine.enabled_here?
            else
              collect_inputs(item.children, into)
            end
          end
        end
        private_class_method :collect_inputs

        # Tells whether an engine part and every part it lies in show.
        #
        # @param engine [Engine::Component] The engine part.
        # @return [Boolean] Whether they do.
        def self.in_view?(engine)
          step = engine
          step = step.parent while step && step.visible?
          step.nil?
        end
        private_class_method :in_view?

        # Names an input for the log: its label, else its id, else its kind.
        #
        # @param part [Part] The input's part.
        # @return [String] The name.
        def self.input_name(part)
          params = part.node.params
          (params[:label] unless params[:label].is_a?(Proc)) || params[:id] || part.node.type
        end
        private_class_method :input_name

        # Reads a param of a part as it is now, calling the lambda of a live param.
        #
        # @param part [Part] The part.
        # @param name [Symbol] The param.
        # @return [Object] Its value.
        def self.param_now(part, name)
          value = part.node.params[name]
          value.is_a?(Proc) && part.node.declaration.params[name].live? ? read_live(part, name, value) : value
        end
        private_class_method :param_now

        # Runs a block that changes engine parts as the scripts asked, so their events go to no
        # handler.
        #
        # @yield The block.
        def self.quietly
          was = @applying
          @applying = true
          yield
        ensure
          @applying = was
        end
        private_class_method :quietly

        # Hands out a handle of a part or a component a component's last render made, by its id.
        #
        # @param component [UI::Component] The component.
        # @param id [Symbol, String] The id: of the part or the component.
        # @return [PartHandle] The handle.
        # @raise [MarkupError] The last render made no part of that id.
        def self.handle(component, id)
          mount = component.__send__(:__mount)
          found = mount && own_part(mount, component, id.to_s)
          return PartHandle.new(found) if found

          raise MarkupError, Errors.placed("part(:#{id}) finds no part with id: :#{id} in the last render of #{component.class.name}", caller(2))
        end

        # Finds a part or a component a component rendered itself, by its id, also inside the parts it
        # holds but not inside the components it holds.
        #
        # @param item [Part, Mount] Where to look.
        # @param owner [UI::Component] The component.
        # @param id [String] The id.
        # @return [Part, Mount, nil] The part or the component's mount, nil for none.
        def self.own_part(item, owner, id)
          return item if item.is_a?(Part) && item.node.owner.equal?(owner) && item.node.params[:id].to_s == id && !item.gone

          item.children.each do |child|
            return child if child.is_a?(Mount) && child.node && child.node.owner.equal?(owner) && child.node.params[:id].to_s == id && !child.gone
            next if child.is_a?(Mount) && !child.equal?(item)

            found = own_part(child, owner, id)
            return found if found
          end
          nil
        end
        private_class_method :own_part
      end

      # A handle of a part or a component a component rendered, which UI::Component#part hands out:
      # it offers only the calls the part's built-in declares as its actions, such as enter_from of
      # slides, and those every part takes (COMMON_ACTIONS), or those the component's class declares
      # with action and those every component takes (COMPONENT_ACTIONS).
      class PartHandle
        # The calls every part's handle takes, besides those its built-in declares.
        COMMON_ACTIONS = {
          :focus => { :args => "", :doc => "moves the focus onto the part, such as back onto a bar after Enter in a search",
                      :call => lambda { |part| part.engine.focus } }
        }

        # The calls every component's handle takes, besides those its class declares, which win.
        COMPONENT_ACTIONS = {
          :focus => { :args => "",
                      :doc => "moves the focus into the component: onto the part inside it that held the focus last, else onto its first part that takes the keys, " \
                              "such as a field of a form made of components of your own",
                      :call => lambda { |mount| top = PartHandle.first_part(mount); Tree.focus_in(top.engine) if top } }
        }

        # Finds the first part a component's render made, inside the components it holds too.
        #
        # @param item [Layer::Mount, Layer::Part] Where to look.
        # @return [Layer::Part, nil] The part, nil for none.
        def self.first_part(item)
          item.children.each do |child|
            next if child.gone
            return child if child.is_a?(Layer::Part)

            found = first_part(child)
            return found if found
          end
          nil
        end

        # Makes the handle.
        #
        # @param part [Layer::Part, Layer::Mount] The part, or the component's mount.
        def initialize(part)
          @part = part
        end

        # Runs a call the part's built-in or the component's class declares; one that left the screen
        # does nothing.
        #
        # @param name [Symbol] The call.
        # @param values [Array] Its values.
        # @return [nil] Always.
        # @raise [MarkupError] The built-in declares no such call.
        def method_missing(name, *values)
          action = actions[name]
          ::Kernel.raise MarkupError, "#{type_name} has no call #{name}#{actions.empty? ? '' : "; it has #{actions.keys.join(', ')}"}" unless action
          return nil if @part.gone

          own = @part.is_a?(Layer::Mount) && @part.component.class.actions.key?(name)
          own ? @part.component.__send__(name, *values) : action[:call].call(@part, *values)
          nil
        end

        # Tells whether the part's built-in declares a call.
        #
        # @param name [Symbol] The call.
        # @return [Boolean] Whether it does.
        def respond_to?(name)
          actions.key?(name.to_sym)
        end

        # Names the part and its calls.
        #
        # @return [String] Such as "#<part slides #pages: enter_from>".
        def inspect
          "#<part #{type_name} ##{@part.node.params[:id]}: #{actions.keys.join(', ')}>"
        end

        private

        # Tells the calls the part's built-in or the component's class declares.
        #
        # @return [Hash{Symbol => Hash}] Each call's :doc, and a built-in's :call.
        def actions
          return COMPONENT_ACTIONS.merge(@part.component.class.actions) if @part.is_a?(Layer::Mount)

          COMMON_ACTIONS.merge(@part.node.declaration.spec[:actions] || {})
        end

        # Tells the markup name of the part or the component.
        #
        # @return [String] The name.
        def type_name
          @part.is_a?(Layer::Mount) ? @part.component.class.markup_name : @part.node.type.to_s
        end
      end
    end
  end
end
