#----------------------------------------------------------------
#  layer_list_cells_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

# Covers a list of the UI layer whose rows stand in columns (design v2 section 5.5) in a booted game
# against FakeTree, through a mod's camp roster: the party under a heading per place, each member's
# name, level and HP in the list's columns, a cell's typo: in its font size, the headings across the
# row and passed over by the cursor in C#, the list as wide as its widest cells ask; a pick tells the
# member's row.

require_relative "layer_support"

CAMP_ROSTER = <<-RUBY
  module Camp_Roster
    UI = Mod_Framework::UI

    class Roster < UI::Component
      state(:picked) { [] }

      def render
        window "Roster", width: 360 do
          list rows, id: :roster, cells: [120, 56, nil], on_submit: ->(row) { self.picked = picked + [row[:key]] }
        end
      end

      def rows
        [{ heading: "In battle" },
         { key: :luka, cells: ["Luka", { text: "Lv 42", typo: :caption }, { text: "812 / 812", align: :end }] },
         { key: :alice, cells: ["Alice", { text: "Lv 40", typo: :caption }, { text: "1290 / 1450", align: :end, color: :warning }] },
         { heading: "In reserve" },
         { key: :tamamo, cells: ["Tamamo", { text: "Lv 38", typo: :caption }, { text: "640 / 900", align: :end }] }]
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
    list = ui::Engine::Tree.roots.last.find(:roster)
    rows = list.rows

    # The columns, the headings and the cells as the engine draws them: the caption's level in the
    # caption's size, the HP at the column's end.
    check("the list's columns and the headings [cells, first row, fourth row]", [list.instance_variable_get(:@options)[:cells], rows[0], rows[3]],
          [[120, 56, nil], { :heading => "In battle" }, { :heading => "In reserve" }])
    check("Alice's cells", rows[2][:cells],
          ["Alice", { :text => "Lv 40", :font_size => ui::Engine::Builtins.typo_size(:caption) }, { :text => "1290 / 1450", :align => :end, :color => :warning }])
    check("C# passes the cursor over the headings", tree.nodes[list.node][:props]["heading_rows"], [0, 3])

    # The list asks C# for room for its fixed columns and Alice's HP whole in the column that takes
    # the rest, so a window sized to it shows every cell.
    asked = tree.nodes[list.node][:props]["measured"][0]
    hp = ui::Engine::LabelCache.width("1290 / 1450", ui::Engine::Style::TEXT_SIZE)
    check("the room the list asks for holds the fixed columns and the widest HP", asked >= 120 + 56 + hp, true)

    # The player picks Tamamo, in the row after the second heading.
    tell(tree, [[list.node, "submit", 4]])
    check("the member picked", roster.picked, [:tamamo])
  end
end
