#----------------------------------------------------------------
#  move_list_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Greyed rows and choices with disabled:
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Checked that a carried row stays within the run of rows of its group
#      Paulinchen  2026-11-04: Kept the flows of moving a row by the keys and by a step and checked each outcome on its own
#                            - Rewrote the checks as flow tests of moving a row by the keys, the pointer and a step
#      Paulinchen  2026-11-01: Covered a row moved by a step within its group
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Covers Move mode of a List in a booted game against FakeTree, which plays C#'s tree: a row
# carried by the keys among the rows of its group and dropped or put back, and move_row moving the
# cursor's row by a step.

require_relative "tree_support"

$sounds = []

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame
    window = ui::Engine::Window.new(:title => "Mods", :size => [300, 240])
    rows = [{ :text => "Framework", :disabled => true, :search => false },
            { :text => "Bridge", :group => :framework }, { :text => "Core", :group => :framework },
            { :text => "Level Cap", :group => :regular }, { :text => "Invasions", :group => :regular }, { :text => "Party Sheet", :group => :regular }]
    list = window.add_list(:rows => rows, :index => 3, :reorder => true)
    window.open
    frame
    moved = []
    list.on(:moved) { |row, from, to| moved << [row[:text], from, to] }
    names = lambda { list.rows.map { |row| row[:text] } }

    # The player carries Level Cap by the keys, tries to leave its group and drops it last.
    list.start_move
    frame
    tree.post("events", [[list.node, "change", 4]])
    frame
    tree.post("events", [[list.node, "change", 1]])
    frame
    check("it stays among the rows of its group", [names.call[3], list.index], ["Level Cap", 3])
    tree.post("events", [[list.node, "change", 5], [list.node, "drop", 5]])
    frame
    check("a drop leaves it there and tells moved once", moved, [["Level Cap", 3, 5]])

    # Cancel puts a carried row back, and a filter refuses the move.
    list.start_move(1)
    tree.post("events", [[list.node, "change", 2], [list.node, "uncarry"]])
    frame
    check("cancel puts the row back where it came from", names.call[1, 2], ["Bridge", "Core"])
    list.filter = "core"
    check("a filter refuses the move", list.start_move, false)
    list.filter = ""

    # A step moves the cursor's row within its group, but not past its first row.
    list.index = 2
    list.move_row(-1)
    frame
    check("the cursor goes with it in C# too", [names.call[1, 2], tree.nodes[list.node][:props]["index"]], [["Core", "Bridge"], 1])
    check("nothing moves past the first row of its group", list.move_row(-1), false)

    # A group another group splits keeps a carried row within its own run of rows.
    list.rows = [{ :text => "Bridge", :group => :framework }, { :text => "Level Cap", :group => :regular }, { :text => "Core", :group => :framework }]
    list.start_move(0)
    frame
    tree.post("events", [[list.node, "change", 2], [list.node, "drop", 2]])
    frame
    check("a drag stays within the run of its group", [names.call, tree.nodes[list.node][:props]["index"]], [["Bridge", "Level Cap", "Core"], 0])
  end
end
