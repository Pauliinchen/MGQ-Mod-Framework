#----------------------------------------------------------------
#  layer_builtins_pages.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Gave a page view label_width: and documented its entries' label:
#      Paulinchen  2026-11-07: Gave a table highlight:, a text drawn on the picked color wherever it occurs
#                            - Added breadcrumbs, the way to the place shown as links the player follows back
#      Paulinchen  2026-11-06: Removed a page view's list_share: and backdrop:, which no mod gave
#                            - Documented the group rows with their fold and the none lines a page view's owner lays out through row:
#                            - Scrolled a page view's pane by Page Up and Page Down from its list and by the d-pad in a pane that
#                              holds no key stop, and left Q and W to the window's on_page
#      Paulinchen  2026-11-05: Added page_view, page_head and page_pane, a head, a list of items in groups that fold and a reading pane
#                            - Added expansion_panels and expansion_panel, panels whose titles fold them open and shut
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer a page of an overview is made of: a table of items in columns
      # with its pagination, panels that fold open and shut, a page view of a head, a list of
      # items in groups and a reading pane, and breadcrumbs, the way to the page shown. Like
      # layer_builtins.rbx this file loads without the game, so the tool writing docs/ui
      # reads it too.
      module Builtins
        # The events of a table.
        TABLE_EVENTS = { :change => "the item the cursor moved to", :submit => "the item picked; without on_submit: the pick goes to the nearest on_submit: around the table",
                         :sort => "the column the player sorted by (its id:, else its title) and :asc, :desc or nil once it is unsorted again" }

        Declarations.define(:table,
                            :summary => "Items in rows under the titles of their columns, such as the party members with their job and level; " \
                                        "each column part names one column. It stays one part however many rows it has.",
                            :args => [:items], :content => true,
                            :params => { :items => { :type => :array, :default => [], :doc => "the items, one row each" },
                                         :bind => { :kind => :bind, :doc => "the state that holds the picked item, both ways; on another page the table turns to it" },
                                         :filter => { :kind => :item, :doc => "keeps only the items it answers true for, such as those a search matches" },
                                         :sort => { :doc => "the column the rows start sorted by: its id: or title, or [column, :asc or :desc]; given anew it sorts anew" },
                                         :rows_per_page => { :type => :int, :doc => "the most rows a page shows; more items add a pagination under the table" },
                                         :dense => { :type => :bool, :default => false, :doc => "lower rows, as high as the theme's dense row" },
                                         :empty => { :type => :text, :default => "No entries", :doc => "what it says in a dim line under the titles without items" },
                                         :most_rows => { :type => :int, :default => 6, :doc => "the most rows it shows before it scrolls; height: :fill shows as many as its room holds" } }.merge(HIGHLIGHT),
                            :events => TABLE_EVENTS,
                            :keys => "as a list: Up and Down move and wrap at the ends on a fresh press, confirm picks; Ctrl and Up from the rows reach the titles " \
                                     "of the sortable columns, which Left and Right walk and confirm sorts by: up, down, then unsorted; Down goes back to the rows; " \
                                     "Page Up and Page Down turn the page of a table with rows_per_page:, on the first or last page they go to the first or last row; " \
                                     "the keys skip the rows of a table without bind:, on_submit: or on_change:",
                            :pad => "the d-pad moves; A picks and sorts; A held with the d-pad reaches the titles",
                            :mouse => "a click moves the cursor there and picks; a click on a sortable title sorts by it; the wheel scrolls",
                            :places => "each `column` by its id",
                            :make => lambda { |options| Table.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:most_rows => params[:most_rows] || 6, :empty_text => params[:empty].nil? ? Table::EMPTY_TEXT : params[:empty].to_s,
                                                             :row_height => params[:dense] ? Theme.rows[1] : nil, :rows_shown => params[:height] == :fill ? :fill : nil,
                                                             :list_acts => LIST_ACTIONS.any? { |name| !params[name].nil? }, :highlight => params[:highlight] && params[:highlight].to_s)
                              options.delete(:height)
                              options
                            end,
                            :wire => lambda { |part| Layer.wire_table(part) },
                            :sync => lambda { |_part, _wanted| nil },
                            :synced => lambda { |part| Layer.show_table(part) })

        Declarations.define(:column,
                            :summary => "One column of a table: its title over its cells, what each item shows there, and its width: in pixels; the columns " \
                                        "without one share the room left.", :args => [:title], :inside => [:table],
                            :common => false,
                            :params => { :title => { :type => :text, :doc => "its title over the rows; a column without one has none" },
                                         :value => { :kind => :item,
                                                     :doc => "what an item shows in it, also what it sorts by: a text, a number, or { text:, color: } for a cell in its own color; the item itself by default" },
                                         :sortable => { :type => :bool, :default => false, :doc => "the player sorts the rows by it with its title" },
                                         :align => { :values => [:start, :center, :end], :default => :start, :doc => "where its title and its texts sit in its width" },
                                         :width => { :type => :int, :doc => "pixels; the columns without a width share the room left" },
                                         :icon => { :kind => :item, :doc => "an icon before an item's text in it" },
                                         :id => Declarations::COMMON[:id], :key => Declarations::COMMON[:key], :visible => Declarations::COMMON[:visible] },
                            :make => HELD, :options => NO_OPTIONS)

        Declarations.define(:pagination,
                            :summary => "Numbered pages to pick one from, with a button back and one on, such as under a long list; the page shown is filled.",
                            :params => { :count => { :kind => :live, :type => :int, :required => true, :doc => "how many pages there are" },
                                         :bind => { :kind => :bind, :doc => "the state that holds the page shown, both ways: 1 for the first" } },
                            :events => { :change => "the page the player picked: 1 for the first" },
                            :keys => "Left and Right walk its buttons, confirm picks the page", :pad => "the d-pad walks, A picks",
                            :mouse => "a click picks a page",
                            :make => lambda { |options| Pagination.new(options) },
                            :options => lambda { |params| common(params).merge(:count => [params[:count].to_i, 1].max) },
                            :sync => lambda { |_part, _wanted| nil },
                            :wire => lambda { |part| part.engine.on(:change) { |page| Layer.bound_changed(part, page) } },
                            :synced => lambda { |part| Layer.follow_pagination(part) })

        Declarations.define(:expansion_panels,
                            :summary => "Panels under each other that their titles fold open and shut, such as the parts of a long text; with multi: false one is open at a time.",
                            :content => true,
                            :params => { :multi => { :type => :bool, :default => true, :doc => "several may be open; false shuts the others as one opens" },
                                         :spacing => { :values => (0..6).to_a, :default => 1, :doc => "room between two panels, 4 px a unit" } },
                            :keys => "Up and Down step the titles and the parts of the open panels; confirm on a title folds its panel", :pad => "as the keys",
                            :mouse => "a click on a title folds its panel", :places => "each `expansion_panel` by its id",
                            :make => lambda { |options| ExpansionPanels.new(options) },
                            :options => lambda { |params| common(params).merge(:multi => params[:multi] != false, :gap => spacing(params[:spacing] || 1)) })

        Declarations.define(:expansion_panel,
                            :summary => "One panel of expansion_panels: a title that folds it, and the parts it shows while open.", :args => [:title], :content => true,
                            :inside => [:expansion_panels],
                            :params => { :title => { :kind => :live, :type => :text, :required => true, :doc => "its title, after the mark of whether it is open" },
                                         :note => { :kind => :live, :type => :text, :doc => "a short dim text at its title's right, such as \"3 left\"" },
                                         :open => { :type => :bool, :default => false, :doc => "it opens as this turns true and shuts as it turns false; the player folds it between" },
                                         :bind => { :kind => :bind, :doc => "a state that holds whether it is open, both ways, instead of open:" } },
                            :events => { :fold => "whether it is open now, as the player folded it, or as another opened while its panels hold one at a time" },
                            :make => lambda { |options| ExpansionPanel.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:title => params[:title].to_s, :note => params[:note].nil? ? nil : params[:note].to_s)
                            end,
                            :wire => lambda { |part| part.engine.on(:fold) { |open| Layer.panel_folded(part, open) } },
                            :sync => lambda { |part, wanted| Layer.sync_panel(part, wanted) },
                            :synced => lambda { |part| Layer.follow_panel(part) })

        Declarations.define(:page_view,
                            :summary => "A page of a head, a list of items in groups that fold, and a reading pane beside the list that shows the item picked, " \
                                        "such as a page of a shop's items: page_head holds the head, page_pane what the pane shows.",
                            :args => [:items], :content => true,
                            :params => { :items => { :type => :array, :default => [], :doc => "the items, one entry each" },
                                         :group => { :kind => :item,
                                                     :doc => "an item's group, such as \"Seeds\": its items stand under its row, which counts them, \"Seeds (2)\"; the groups in the order of their first items, items without one above every group; " \
                                                             "an owner who keeps the folds or shows empty groups lays its groups out through row: instead" },
                                         :text => { :kind => :item, :doc => "an item's entry text; the item itself by default" },
                                         :icon => { :kind => :item, :doc => "an item's icon before its text" },
                                         :right => { :kind => :item, :doc => "what an item's entry says at its right end, such as \"68%\"" },
                                         :row => { :kind => :item,
                                                   :doc => "an item's whole entry, a list row such as { text:, right:, gauge: 0.68, faint: true }, its label: a caption in the system color in a column before its text; for groups the owner lays out itself, " \
                                                           "a group's row { group: key, text: \"Passed (3)\", open: false }, which folds the entries after it up to the next group " \
                                                           "and whose open: wins over the player's fold, or a dim line the cursor passes, { none: \"None right now.\" }, such as " \
                                                           "under a group without entries" },
                                         :label_width => { :type => :measure, :doc => "the width of the entries' label: column: pixels, or texts of which the widest sets it; the widest label of all entries by default" },
                                         :bind => { :kind => :bind, :doc => "the state that holds the picked item, or the pick: of page_head, both ways" },
                                         :head => { :kind => :content, :doc => "markup of the head over the list and the pane, as page_head holds it" },
                                         :pane => { :kind => :content, :doc => "markup of what the pane shows, as page_pane holds it" } },
                            :events => { :change => "the item the cursor moved to, or the pick: of page_head as the head took the focus",
                                         :fold => "the group the player folded or opened, and whether it is open now" },
                            :keys => "Up and Down pick an entry or a group and wrap at the ends on a fresh press; confirm folds a group, or moves the focus into the pane " \
                                     "onto its first part that takes the keys, or onto the pane itself while it holds none, where Up and Down scroll it; cancel there goes " \
                                     "back to the list; Page Up and Page Down scroll the pane a page, also from the list; Q and W never scroll it, they reach the " \
                                     "window's on_page only; Ctrl and Up from the list reach a head with pick:; the cursor passes a none: line",
                            :pad => "the d-pad picks; A folds or goes into the pane, where the d-pad scrolls a pane that holds no part that takes the keys; B comes back; " \
                                    "the shoulders step the tabs in view, else the window's on_page, else scroll the pane a page",
                            :mouse => "a click picks an entry or folds a group, a click on the picked entry goes into the pane; the wheel scrolls the list or the pane under the pointer",
                            :places => "`page_head` (the head over the list and the pane), `page_pane` (what the pane shows)",
                            :make => lambda do |options|
                              view = PageView.new(options)
                              view.list.round = nil
                              view.list.leave_ends = false
                              view.list.acts = true
                              view
                            end,
                            :options => lambda do |params|
                              common(params).merge(:root_pages => false, :label_width => params[:label_width])
                            end,
                            :wire => lambda { |part| Layer.wire_page_view(part) },
                            :sync => lambda { |part, wanted| Layer.sync_page_view(part, wanted) },
                            :synced => lambda { |part| Layer.show_page_view(part) })

        Declarations.define(:page_head,
                            :summary => "The head of a page view over its list and its pane, such as what the page is about.", :content => true, :inside => [:page_view],
                            :params => { :pick => { :doc => "what the head stands for: it is then a stop of the keys over the list, and taking the focus or a click " \
                                                             "tells on_change of its page view with it, such as the party's gold the pane then shows" },
                                         :spacing => { :values => (0..6).to_a, :default => 1, :doc => "room between its parts, 4 px a unit" } },
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(params[:spacing] || 1), :grow => 1) })

        Declarations.define(:page_pane,
                            :summary => "What the pane of a page view shows, such as the item picked in its list; it scrolls.", :content => true, :inside => [:page_view],
                            :params => { :spacing => { :values => (0..6).to_a, :default => 2, :doc => "room between its parts, 4 px a unit" } },
                            :make => lambda { |options| Stack.new(options) },
                            :options => lambda { |params| common(params).merge(:layout => :column, :gap => spacing(params[:spacing] || 2)) })

        Declarations.define(:breadcrumbs,
                            :summary => "The way to the place shown, as MudBlazor's breadcrumbs: links the player follows back, and the place shown at the end, such as Menu / Equip / Luka.",
                            :params => { :items => { :kind => :live, :type => :array, :required => true,
                                                     :doc => "the places from the first to the one shown, each { text:, data:, icon:, disabled:, tooltip: }; the last is the place shown and takes no click" },
                                         :separator => { :type => :text, :default => "/", :doc => "what stands between two places" } },
                            :events => { :click => "the data: of the place the player followed, its text without data:" },
                            :keys => "Left and Right move among the links; confirm follows one; the place shown takes no focus",
                            :pad => "the d-pad's Left and Right move, A follows", :mouse => "a click follows a link",
                            :make => lambda { |options| Breadcrumbs.new(options) },
                            :options => lambda { |params| common(params).merge(:items => Array(params[:items]), :separator => (params[:separator] || "/").to_s) },
                            :wire => lambda { |part| part.engine.on(:click) { |data| Layer.dispatch(part, :on_click, [data]) } },
                            :sync => lambda { |_part, _wanted| nil })
      end
    end
  end
end
