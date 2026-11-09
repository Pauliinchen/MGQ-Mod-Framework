#----------------------------------------------------------------
#  layer_table_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked the dots on either side of the pages around the page shown of many pages
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers table, column and pagination of the UI layer (design v2 section 5.5) in a booted game
# against FakeTree, through a mod's camp roster: the members in columns, sorted by their level as
# the player presses its title, two to a page that Page Up and Page Down turn too, the picked member
# bound both ways, and once empty a dim line under the titles; and a pagination of its own bound to
# a page, which with many pages leaves the pages out on either side of those around the page shown.
# C# walks the titles and the buttons
# with the arrows by its focus rules.

require_relative "layer_support"

CAMP_ROSTER = <<-RUBY
  module Camp_Roster
    UI = Mod_Framework::UI

    Member = Struct.new(:name, :level, :awake)

    class Roster < UI::Component
      state(:members) { [Member.new("Ana", 30, true), Member.new("Mia", 12, false), Member.new("Nora", 21, true)] }
      state :picked
      state(:sorts) { [] }
      state :awake_only, false
      state :page, 1

      def render
        window "Camp" do
          table members, id: :roster, bind: :picked, rows_per_page: 2, filter: ->(member) { !awake_only || member.awake },
                         on_sort: ->(column, direction) { self.sorts = sorts + [[column, direction]] } do
            column "Name", value: :name
            column "Level", value: ->(member) { member.level }, sortable: true, align: :end, width: 48, id: :level
            column "", value: ->(member) { member.awake ? "" : { text: "asleep", color: :dim } }, width: 64
          end
          pagination count: 3, bind: :page, id: :log_pages
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Roster.rb", CAMP_ROSTER)
    frame

    ui.open(Camp_Roster::Roster)
    frame
    Graphics.update
    roster = ui::Engine::Layer.tops.last.mount.component
    table = ui::Engine::Tree.roots.last.find(:roster)
    rows = lambda { table.list.rows.map { |row| row[:cells].map { |cell| cell[:text] } } }
    titles = lambda { table.header.children.map { |cell| cell.is_a?(ui::Engine::Label) ? cell.text : cell.children.first.text } }
    level = table.header.children[1]
    check("the roster as it opens [titles, rows of page 1, widths, pages shown, picked]",
          [titles.call, rows.call, table.list.cells, table.pagination.visible?, roster.picked.name],
          [["Name", "Level", ""], [["Ana", "30", ""], ["Mia", "12", "asleep"]], [nil, 48, 64], true, "Ana"])
    check("the rows take the room of the two rows of a page", tree.nodes[table.list.node][:props]["measured"][1], 2 * table.list.send(:line_height))

    # The player presses the Level title: up, down, then unsorted again, each told to on_sort; the
    # table turns to the page of Ana, who stays picked.
    tell(tree, [[level.node, "click"]])
    check("sorted up by level [title, rows, page]", [titles.call[1], rows.call.map(&:first), table.page], ["Level ▲", ["Ana"], 2])
    tell(tree, [[level.node, "click"]])
    tell(tree, [[level.node, "click"]])
    check("down, then unsorted [rows, on_sort]", [rows.call.map(&:first), roster.sorts], [["Ana", "Mia"], [[:level, :asc], [:level, :desc], [:level, nil]]])

    # Page Down in the rows turns to page 2, where the picked member follows the cursor; Page Up
    # turns back.
    tell(tree, [[table.list.node, "page_step", 1]])
    check("Page Down [C# told the rows turn pages, page, rows, picked]",
          [tree.nodes[table.list.node][:props]["own_pages"], table.page, rows.call.map(&:first), roster.picked.name], [true, 2, ["Nora"], "Nora"])
    tell(tree, [[table.list.node, "page_step", -1]])
    check("Page Up [page, picked]", [table.page, roster.picked.name], [1, "Ana"])

    # Page 2 of the roster: the cursor lands on Nora, whom the bound state takes; the owner binding
    # Mia turns the table back to page 1.
    two = table.pagination.children.find { |child| child.respond_to?(:text) && child.text == "2" }
    tell(tree, [[two.node, "click"]])
    check("page 2 [rows, picked, page]", [rows.call.map(&:first), roster.picked.name, table.page], [["Nora"], "Nora", 2])
    roster.picked = roster.members[1]
    frame
    Graphics.update
    check("Mia bound by the owner [page, rows, cursor]", [table.page, rows.call.map(&:first), table.index], [1, ["Ana", "Mia"], 1])

    # The filter keeps the awake members: one page, no pagination.
    roster.awake_only = true
    frame
    Graphics.update
    check("awake only [rows, pages shown]", [rows.call.map(&:first), table.pagination.visible?], [["Ana", "Nora"], false])

    # Everyone leaves the camp: the titles stay, and a dim line under them says the roster is empty.
    roster.members = []
    frame
    Graphics.update
    lines = table.list.send(:drawn_rows).map { |row| [row[:text], row[:color]] }
    check("an empty roster [titles, the lines under them, the lines that take no pick]",
          [titles.call, lines, tree.nodes[table.list.node][:props]["disabled_rows"]], [["Name", "Level", ""], [["No entries", :dim]], [0]])

    # A pagination of its own: a click on the button on writes the page to its state.
    pages = ui::Engine::Tree.roots.last.find(:log_pages)
    tell(tree, [[pages.children.last.node, "click"]])
    check("the button on of the pagination [state, page shown]", [roster.page, pages.page], [2, 2])
    pages.count = 12
    pages.page = 6
    shown = pages.children.map { |child| child.text.to_s }
    check("twelve pages on page 6", shown, ["<", "1", "...", "5", "6", "7", "...", "12", ">"])
  end
end
