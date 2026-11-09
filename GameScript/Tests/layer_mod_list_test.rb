#----------------------------------------------------------------
#  layer_mod_list_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Expected the move hotkeys in the key help while the list holds the focus
#      Paulinchen  2026-11-06: Expected the move hotkeys before the entry of cancel in the key help
#      Paulinchen  2026-11-05: Covered a mod list with an on/off box at the start of each row and a note of what a mod needs
#                            - Created
#
#----------------------------------------------------------------

# Covers a list of the UI layer whose rows have toggles and move within their group (design v2
# sections 5.5 and 9.1) in a booted game against FakeTree, through a mod list as the framework's
# Mods screen writes it: mods under the headings of their tags, a toggle that turns a mod on and
# off, and a mod moved within its tag by the move hotkeys, which only this list takes, and by a
# drag; and the Mods screen's list, a box at the start of each row that a pick turns on or off, and
# a note in its column of what a mod needs.

require_relative "layer_support"

MOD_LIST = <<-RUBY
  module Camp_Mods
    UI = Mod_Framework::UI

    Mod = Struct.new(:name, :tag, :on)

    class ModList < UI::Component
      state(:mods) { [Mod.new("Map Display", "Look", true), Mod.new("Wide Text", "Look", false), Mod.new("Level Cap", "Rules", true)] }
      state :picked

      def rows
        mods.map { |mod| mod.tag }.uniq.map do |tag|
          [{ text: tag, heading: true }] + mods.select { |mod| mod.tag == tag }
        end.flatten
      end

      def render
        window "Mods" do
          list rows, text: :name, bind: :picked, reorder: :within_group, move_hotkeys: true,
                     toggles: ->(mod) { [{ text: "On", on: mod.on }] },
                     on_toggle: ->(mod, _toggle) { mod.on = !mod.on; self.mods = mods.dup },
                     on_reorder: ->(mod, to) { move(mod, to) }
          key_help entries: [{ button: :B, text: "close" }]
        end
      end

      def move(mod, to)
        others = rows - [mod]
        self.mods = others.insert(to, mod).reject { |row| row.is_a?(Hash) }
      end
    end

    Need = Struct.new(:name, :needs)

    class ModBoxes < UI::Component
      state(:on) { { "Level Cap" => true, "Map Display" => true } }

      def mods
        [Need.new("Mod Framework"), Need.new("Level Cap"), Need.new("Map Display", "Level Cap")]
      end

      def render
        window "Mods" do
          list mods, row: ->(mod) { mod_row(mod) }, note_at: 150, on_submit: ->(mod) { toggle(mod) }
        end
      end

      def mod_row(mod)
        return { text: mod.name, check: nil, note: "Always on" } if mod.name == "Mod Framework"

        missing = on[mod.name] && mod.needs && !on[mod.needs]
        { text: mod.name, check: on[mod.name], note: missing ? "Needs \#{mod.needs}" : nil, note_color: :warning }
      end

      def toggle(mod)
        self.on = on.merge(mod.name => !on[mod.name]) if on.key?(mod.name)
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Mods.rb", MOD_LIST)
    frame

    ui.open(Camp_Mods::ModList)
    frame
    Graphics.update
    node = nodes_of(tree, "list").last
    list = ui::Engine::Tree.component(node)
    mods = ui::Engine::Layer.tops.last.mount.component
    names = lambda { list.rows.map { |row| row[:heading] || row[:text] } }
    props = tree.nodes[node][:props]

    # The tags head their mods, each mod's row has its toggle, and C# learns the headings, the
    # toggles and the groups the move hotkeys keep a mod within.
    check("the rows under the headings of their tags", names.call, ["Look", "Map Display", "Wide Text", "Rules", "Level Cap"])
    check("what C# learns of the rows [reorder, move hotkeys, headings, toggles, groups]",
          props.values_at("reorder", "move_hotkeys", "heading_rows", "toggle_rows", "row_groups"), [true, true, [0, 3], [0, 1, 1, 0, 1], [0, 1, 1, 0, 2]])
    check("the toggles show each mod on or off", list.rows.values_at(1, 2).map { |row| row[:toggles][0][:on] }, [true, false])

    # A toggle pressed turns its mod on.
    tell(tree, [[node, "toggle", 2, 0]])
    check("the toggle turned Wide Text on and shows it", [mods.mods[1].on, list.rows[2][:toggles][0][:on]], [true, true])

    # The move hotkey moves Wide Text up within Look, the cursor going with it.
    tell(tree, [[node, "change", 2]])
    tell(tree, [[node, "reorder", 2, 1]])
    check("Move Up moved Wide Text above Map Display", names.call, ["Look", "Wide Text", "Map Display", "Rules", "Level Cap"])
    check("the moved mod stays picked", [mods.picked.name, list.index], ["Wide Text", 1])
    refused = logged_lines { tell(tree, [[node, "move_refused", "list_move_up", "the row is at the end of its group"]]) }
    check("a move the tree refused is logged with the list and why", refused.grep(/moved no row of list #{node}: the row is at the end of its group/).size, 1)

    # A drag carries Map Display down a row and drops it there.
    tell(tree, [[node, "carry", 2]])
    tell(tree, [[node, "change", 1]])
    tell(tree, [[node, "drop", 1]])
    check("the drag moved Map Display back on top", names.call, ["Look", "Map Display", "Wide Text", "Rules", "Level Cap"])

    # The key help names the move hotkeys as they are bound while the list holds the focus.
    tree.post("states", node => ui::Engine::Tree::FOCUSED)
    frame
    Graphics.update
    help = ui::Engine::Layer.tops.last.root.engine.children.last
    check("the key help names the move hotkeys", help.line, "I: Move up  K: Move down  X or Numpad 0: close")
    ui::Engine::Layer.tops.last.handle.close
    frame

    # The Mods screen's rows: the framework's without a box, the others with theirs, and C# learns
    # where each box ends, so a click there picks its row at once.
    ui.open(Camp_Mods::ModBoxes)
    frame
    Graphics.update
    node = nodes_of(tree, "list").last
    list = ui::Engine::Tree.component(node)
    check("each row's box: none for the framework, then on, on", list.rows.map { |row| row[:checked] }, [nil, true, true])
    check("the notes stand in their column", [list.rows[0][:note], list.note_at], ["Always on", 150])
    check("C# learns which rows have a box", tree.nodes[node][:props]["box_ends"].map { |room| room > 0 }, [false, true, true])

    # A pick on Level Cap, by confirm or a click on its box, turns it off; Map Display, which needs
    # it, notes that.
    tell(tree, [[node, "submit", 1]])
    check("Level Cap's box cleared", list.rows[1][:checked], false)
    check("Map Display notes what it needs", list.rows[2].values_at(:note, :note_color), ["Needs Level Cap", :warning])
  end
end
