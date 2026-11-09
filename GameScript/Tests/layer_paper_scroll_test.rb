#----------------------------------------------------------------
#  layer_paper_scroll_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Covered the focus coming onto the box and leaving it, and cancel on it walking back
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers a paper of the UI layer that scrolls its text (design v2 section 5.2) in a booted game
# against FakeTree, through the side of a mod list: the mod's About text in a box the keys stop on,
# which tells the lines in sight as the player scrolls it and when the focus comes onto it and
# leaves it, and sends cancel back to the part the focus came from.

require_relative "layer_support"

MOD_SIDE = <<-RUBY
  module Camp_Side
    UI = Mod_Framework::UI

    class ModSide < UI::Component
      state :mod, "Map Display"
      state :in_sight
      state :reading, false

      def render
        window "Mods", width: 600 do
          stack row: true do
            list ["Map Display", "Level Cap"], bind: :mod, width: 200
            paper scroll: :vertical, focusable: true, height: 100, grow: 1, key: mod, id: :about_box, on_scroll: ->(lines) { self.in_sight = lines },
                  on_enter: -> { self.reading = true }, on_leave: -> { self.reading = false } do
              text "About", id: :about
              text "Shows the map's name for a few seconds after each map change, in the corner the player picks.", wrap: true, id: :description
            end
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Side.rb", MOD_SIDE)
    frame

    ui.open(Camp_Side::ModSide)
    frame
    Graphics.update
    side = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    box = root.find(:about_box)

    # The box scrolls, the keys stop on it, at its ends it keeps the focus, and cancel on it walks
    # back the way the focus came, as from a page.
    check("C# learns a box that scrolls, a key stop that keeps its ends and a way in [scroll, focusable, keep_ends, tab_page]",
          tree.nodes[box.node][:props].values_at("scroll", "focusable", "keep_ends", "tab_page"), [true, true, true, true])

    # The focus coming onto the box and leaving it tells on_enter and on_leave.
    tell(tree, [[box.node, "focus"]])
    entered = side.reading
    tell(tree, [[box.node, "blur"]])
    check("the focus onto the box and off it [reading after focus, after blur]", [entered, side.reading], [true, false])

    # Scrolled down two lines: the heading and the description's first line lie above the box, its
    # next three lines show, and three more lie below it.
    about = root.find(:about)
    description = root.find(:description)
    line = description.lines_and_height[1]
    top = box.inner_region.y
    tree.rects[about.node] = [0, top - 2 * line, 280, line]
    tree.rects[description.node] = [0, top - line, 280, 6 * line]
    tree.post("scroll", { box.node => [2 * line, 3 * line, 7 * line] })
    frame
    Graphics.update
    check("on_scroll tells the lines in sight and how many there are", side.in_sight, { :first => 3, :last => 5, :total => 7 })
  end
end
