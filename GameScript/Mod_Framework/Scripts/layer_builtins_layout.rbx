#----------------------------------------------------------------
#  layer_builtins_layout.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Told that Up and Down in a grid go to the item spanning the column where the focused one starts
#                            - Gave a grid leave_ends:, which moves the focus on past its first and last lines instead of wrapping
#                            - Added container, its parts in a column in the middle of its room at a most width, with gutters
#      Paulinchen  2026-11-07: Added drop_container, drop_zone and the items dragged between the zones
#                            - Named the cell of a grid grid_item
#                            - Added card, card_header, card_media, card_content and actions
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer that lay parts out in a grid of twelve columns and on cards. Like
      # layer_builtins.rbx this file loads without the game, so the tool writing docs/ui
      # reads it too.
      module Builtins
        # The columns of a grid, which the items' xs: share, as in MudBlazor.
        GRID_COLUMNS = 12

        Declarations.define(:grid,
                            :summary => "Items side by side in a grid of twelve columns, as MudBlazor's grid: each item spans its xs: of them, and an item that no longer fits a row starts the next.",
                            :content => true,
                            :params => { :spacing => { :values => STACK_SPACINGS, :default => 2, :doc => "room between its items, across and down, 4 px a unit, also half a unit such as 2.5" },
                                         :leave_ends => { :type => :bool, :default => false,
                                                          :doc => "in a grid of cards, Up on its first line and Down on its last move the focus to the part above or below instead of wrapping, such as a search field over the cards; Left and Right still wrap" } },
                            :keys => "the arrows move between the items, Up and Down to the item in the line above or below that spans the column where the focused item starts, out of the first or last line to the part above or below; " \
                                     "in a grid of cards a fresh press at an edge wraps to the other end, a held arrow stops there",
                            :pad => "as the keys", :mouse => "as its parts",
                            :make => lambda { |options| Grid.new(options) },
                            :options => lambda { |params| common(params).merge(:columns => GRID_COLUMNS, :gap => spacing(params[:spacing] || 2), :leave_ends => params[:leave_ends] == true) })

        # The most widths of a container by name, in pixels: from a drawer's width to the screen's
        # 640, in steps of 80.
        CONTAINER_WIDTHS = { :xs => 240, :sm => 320, :md => 400, :lg => 480, :xl => 560, :xxl => 640 }

        # Turns a container's params into the engine's options: a centered column whose named width or
        # pixels are its most width, the smaller of it and its own max_size:'s; :fixed hands it every
        # named width to pick from, :fluid none.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.container(params)
          options = common(params).merge(:gap => spacing(2))
          width = params[:max_width] || :lg
          return options.merge(:widths => CONTAINER_WIDTHS.values) if width == :fixed

          most = width.is_a?(Integer) ? width : CONTAINER_WIDTHS[width]
          return options unless most

          own = params[:max_size]
          options.merge(:max_size => [own && own[0] ? [own[0], most].min : most, own && own[1]])
        end

        Declarations.define(:container,
                            :summary => "Its parts in a column in the middle of the room it gets, at most max_width: wide, with gutters at its sides, as MudBlazor's container; " \
                                        "padding: 0 drops the gutters.",
                            :content => true,
                            :params => { :max_width => { :type => :size, :values => CONTAINER_WIDTHS.keys + [:fluid, :fixed], :default => :lg,
                                                         :doc => "its most width: :xs 240, :sm 320, :md 400, :lg 480, :xl 560 or :xxl 640 pixels, or pixels; :fluid the whole room; " \
                                                                 ":fixed the largest named width that fits the room; a window that fits what it holds takes the named width, with :fixed " \
                                                                 "the next named width above what the container holds" } },
                            :make => lambda { |options| CenteredColumn.new(options) },
                            :options => lambda { |params| container(params) })

        Declarations.define(:grid_item,
                            :summary => "One item of a grid, its parts in a column, as MudBlazor's item.",
                            :content => true, :inside => [:grid],
                            :params => { :xs => { :values => (1..GRID_COLUMNS).to_a, :default => GRID_COLUMNS,
                                                  :doc => "how many of the grid's twelve columns it spans: 12 the whole row, 6 half of it, 4 a third, 3 a quarter" } },
                            :make => lambda { |options| GridItem.new(options) },
                            :options => lambda { |params| common(params).merge(:span => params[:xs] || GRID_COLUMNS, :gap => spacing(2)) })

        Declarations.define(:card,
                            :summary => "A framed card, as MudBlazor's card: a card_header, a card_media, a card_content and actions in a column. With clickable: true it is one part " \
                                        "that confirm or a click presses, such as a card of a party member to pick; with enter: true the keys stop on it whole and confirm goes in to its actions.",
                            :content => true,
                            :params => { :clickable => { :type => :bool, :default => false,
                                                         :doc => "one key stop that confirm or a click anywhere on it presses, telling on_click, what it holds taking neither the keys nor the pointer" },
                                         :enter => { :type => :bool, :default => false,
                                                     :doc => "for a card with several actions: the arrows stop on it whole; confirm goes inside onto the action picked there last, cancel inside comes back out" } },
                            :events => { :click => "nothing; with clickable: true, confirm or a click on it pressed it",
                                         :enter => "nothing; with enter: true, the focus went inside it", :leave => "nothing; with enter: true, the focus came out of it" },
                            :keys => "with clickable: true, the arrows stop on it as one part and confirm presses it; with enter: true, the arrows stop on it whole, confirm goes in and cancel comes back out; " \
                                     "else the keys reach its actions as any buttons",
                            :pad => "as the keys", :mouse => "with clickable: true, a click anywhere on it presses it; else a click on an action presses it",
                            :make => lambda { |options| Box.new(options) },
                            :options => lambda { |params| common(params).merge(:enter => params[:enter] == true, :clickable => params[:clickable] == true, :gap => spacing(2)) },
                            :wire => lambda do |part|
                              part.engine.on(:click) { Layer.dispatch(part, :on_click, []) }
                              part.engine.on(:went_in) { Layer.dispatch(part, :on_enter, []) }
                              part.engine.on(:came_out) { Layer.dispatch(part, :on_leave, []) }
                            end)

        Declarations.define(:card_header,
                            :summary => "The head of a card: its title, and a subtitle under it in small dim text.", :args => [:title], :inside => [:card],
                            :params => { :title => { :kind => :live, :type => :text, :doc => "what the card is, such as a character's name" },
                                         :subtitle => { :kind => :live, :type => :text, :doc => "a line under the title, such as the character's level" } },
                            :make => lambda { |options| CardHeader.new(options) },
                            :options => lambda { |params| common(params).merge(:title => params[:title].to_s, :subtitle => params[:subtitle] && params[:subtitle].to_s) },
                            :sync => lambda { |_part, _wanted| nil })

        Declarations.define(:card_media,
                            :summary => "A picture across a card: a picture file, a character's face or their portrait, filling the card's width.", :inside => [:card],
                            :params => { :file => { :type => :text, :doc => "a picture file of the game or of your mod, such as \"Graphics/Pictures/bg010\"" },
                                         :face => { :doc => "a character whose face shows" },
                                         :portrait => { :doc => "a character whose Library portrait shows" },
                                         :fit => { :values => [:cover, :contain, :fill], :default => :cover,
                                                   :doc => ":cover fills its room and cuts what sticks out, :contain shows all of it, :fill stretches it" },
                                         :blur => { :type => :bool, :default => false, :doc => "draws a picture file blurred, such as a screenshot that spoils the story" } },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| Picture.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:fit => params[:fit] || :cover, :blur => params[:blur] == true)
                              [:file, :face, :portrait].each { |name| options[name] = params[name] unless params[name].nil? }
                              options
                            end)

        Declarations.define(:card_content,
                            :summary => "What a card tells, its parts in a column, such as texts and fields.", :content => true, :inside => [:card],
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(1)) })

        Declarations.define(:actions,
                            :summary => "The buttons at the foot of a card, in a row, as MudBlazor's card actions.", :content => true, :inside => [:card],
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :row, :gap => spacing(2)) })

        Declarations.define(:drop_container,
                            :summary => "Drop zones between which the player drags their items, as MudBlazor's drop container, such as a front row and a reserve of the party.",
                            :content => true,
                            :events => { :drop => "the item, the zone it came from, the zone it goes to and its place there, from 0 among that zone's other items; move it there in your data, which shows it there" },
                            :keys => "confirm on an item picks it up; the arrows move it along its zone and past the zone's ends, or across, into the zone before or after; confirm puts it down, cancel puts it back",
                            :pad => "as the keys", :mouse => "drag an item and let go over a zone; let go elsewhere and it goes back",
                            :make => lambda { |options| DropContainer.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(2)) },
                            :wire => lambda do |part|
                              part.engine.on(:drop) do |item, from, to, place|
                                found = [item, from, to].map { |node| Tree.component(node) }
                                Layer.dispatch(part, :on_drop, [found[0].item, found[1].zone, found[2].zone, place]) if found.all?
                              end
                            end)

        Declarations.define(:drop_zone,
                            :summary => "A framed area of items the player drags into other drop zones of its drop_container, as MudBlazor's drop zone; "                                         "its block shows one item, which it takes, else the item's name shows.", :args => [:zone], :content => true, :each => [:items, :drop_item],
                            :params => { :zone => { :required => true, :doc => "what the zone is, which on_drop tells, such as :front" },
                                         :title => { :type => :text, :doc => "the title at its top, such as \"Front row\"" },
                                         :items => { :type => :array, :default => [], :doc => "its items, in order, such as the members of the front row" },
                                         :row => { :type => :bool, :default => false, :doc => "its items side by side; Left and Right then move an item along it, Up and Down to the zone before or after" } },
                            :make => lambda { |options| DropZone.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:zone => params[:zone], :title => params[:title] && params[:title].to_s, :layout => params[:row] ? :row : :column, :gap => spacing(1))
                            end)

        Declarations.define(:drop_item,
                            :summary => "An item of a drop zone, which the markup makes for each of its items.", :hidden => true, :content => true, :inside => [:drop_zone],
                            :params => { :item => { :doc => "what it stands for" } },
                            :make => lambda { |options| DropItem.new(options) },
                            :options => lambda { |params| common(params).merge(:item => params[:item], :gap => spacing(1)) })
      end
    end
  end
end
