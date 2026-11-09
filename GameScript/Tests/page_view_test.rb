#----------------------------------------------------------------
#  page_view_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Added the page view without the removed builder
#                            - Greyed rows and choices with disabled:
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Dropped the view filled from a mod's page, which the page view no longer takes
#      Paulinchen  2026-11-04: Kept a few flows of a page view and checked each outcome on its own
#                            - Rewrote the checks as flow tests of a page view of its owner's and one filled from a mod's page
#      Paulinchen  2026-11-01: Checked the entries indented under their group and a character's picture beside a thing named
#                            - Checked the focus given to the head
#                            - Checked Ctrl in the pane, whether the focus lies there and the folds the view keeps
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers page_view.rbx in a booted game against FakeTree: a view its owner fills, with its events,
# folds and the focus into its pane and back.

require_relative "tree_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    $sounds = []
    frame
    focus = lambda { tree.changes.map { |change| change["focus"] }.compact.last }

    # The owner fills a view; the player folds its group, picks an entry and goes into its pane and
    # back.
    window = ui::Engine::Window.new(:at => [0, 0], :size => [600, 400])
    view = window.add(ui::Engine::PageView.new({}))
    told = []
    view.on(:change) { |data| told << [:change, data] }
    view.on(:fold) { |key, open| told << [:fold, key, open] }
    view.on(:press) { |index| told << [:press, index] }
    rows = [{ :group => :side, :text => "Side quests (1)", :open => true }, { :text => "Find the lost ring.", :data => :ring }, { :none => "None right now." }]
    view.head = { :title => "Main quest", :lines => ["Go to the village."], :pick => :main }
    view.rows = rows
    view.pane = { :title => "Find the lost ring", :buttons => ["Track", { :text => "Drop", :disabled => true }],
                  :lines => ["First paragraph.", :gap, { :items => [{ :text => "Ring", :icon => 12 }, { :text => "Ana", :figure => :ana }] },
                             { :gauge => 0.5, :text => "Half way" }] }
    window.open
    2.times { frame }
    view.focus
    frame
    tree.post("events", [[view.instance_variable_get(:@head).node, "focus"]])
    frame
    check("the head tells its pick once it takes the focus", told.last, [:change, :main])
    tree.post("events", [[view.list.node, "change", 1]])
    frame
    tree.post("events", [[view.list.node, "submit", 0]])
    frame
    check("a folded group shows its entries no more", view.list.rows.map { |row| row[:text] }, ["▸ Side quests (1)"])
    view.rows = rows.map { |row| row.reject { |key, _value| key == :open } }
    view.rows = rows
    tree.post("events", [[view.list.node, "submit", 1]])
    2.times { frame }
    track = view.instance_variable_get(:@buttons)[0]
    check("confirm on an entry moves the focus onto the pane's first button", focus.call, track.node)
    tree.post("events", [[track.node, "click"]])
    tree.post("states", track.node => ui::Engine::Tree::FOCUSED)
    frame
    frame([:CTRL])
    frame
    view.in_pane?
    check("Ctrl in the pane goes back to the list", focus.call, view.list.node)
    window.close
  end
end
