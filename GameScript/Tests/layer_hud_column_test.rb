#----------------------------------------------------------------
#  layer_hud_column_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a fading box taken off at once, which frees its place in the column
#                            - Covered a column defined anew, which moves its box, and a box that joins a column defined after it showed
#                            - Created
#
#----------------------------------------------------------------

# Covers UI.column and a hud's column: in a booted game against FakeTree, through a mod's battle
# lines as Battle Dialogue shows them: the mod defines a column once, logged; each box shown with
# column: hands C#'s tree its column in place of its own spot and does not move with Alt, and slides
# in from the column's side; a box that leaves stays in the tree, hidden and holding its place, until
# its fade ends, unless told to hide at once, which takes it off the next frame; a box that hides
# holds its place while it fades out; a column defined anew moves
# its shown box; a box naming a column no mod defined shows at its own place, logged, and joins the
# column once a mod defines it; a misspelt param of UI.column raises at the mod's line.

require_relative "layer_support"

BATTLE_COLUMN = <<-RUBY
  module Battle_Column
    UI = Mod_Framework::UI
    UI.column :battle_left, at: [16, 4], gap: 8, align: :left

    class Box < UI::Component
      param :tag
      param :line
      param :place, :battle_left

      def render
        hud id: tag, column: place, at: [300, 300], enter: :move, leave: :fade, motion_frames: [15, 30], width: 288,
            hide_while: -> { $quiet_line == line } do
          text line
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Battle_Column.rb", BATTLE_COLUMN)
    frame
    check("the column is logged as defined",
          layer_lines.include?("Patch/Battle_Column.rb defined the column :battle_left at [16, 4], 8 px apart, each hud with its left edge there"), true)

    # A box in the column hands the tree its column instead of its spot and slides from the left,
    # though the top edge lies nearer.
    root_of = lambda { |handle| handle.instance_variable_get(:@top).root.engine }
    first = ui.show(Battle_Column::Box, tag: :first, line: "Stand back!")
    first_root = root_of.call(first)
    props = lambda { |root| tree.nodes[root.node][:props] }
    tree.rects[first_root.node] = [16, 4, 288, 30]
    frame
    check("the box takes its column's place and no spot of its own [column, movable, at, dock]",
          props.call(first_root).values_at("column", "movable", "at", "dock"), [["battle_left", 16, 4, 8, "left"], false, nil, nil])
    check("it slides in from the column's side", first_root.base_surface.instance_variable_get(:@sprite).x, 16 - (304 * (14 / 15.0)**2).round)
    14.times { frame }

    # A box that leaves stays in the tree, hidden and holding its place, until its fade ends.
    second = ui.show(Battle_Column::Box, tag: :second, line: "Hmph.")
    second_root = root_of.call(second)
    first_node = first_root.node
    first.hide
    29.times { frame }
    check("the leaving box stays in the tree while it fades, hidden and holding its place [visible, column_hold]",
          tree.nodes[first_node][:props].values_at("visible", "column_hold"), [false, true])
    frame
    check("it leaves the tree the frame its fade ends", tree.nodes.key?(first_node), false)

    # A box told to hide at once while it fades out leaves the tree the next frame, freeing its
    # place in the column, its picture released.
    stop = ui.show(Battle_Column::Box, tag: :stop, line: "Enough!")
    stop_root = root_of.call(stop)
    tree.rects[stop_root.node] = [16, 4, 288, 30]
    15.times { frame }
    stop_node = stop_root.node
    stop.hide
    5.times { frame }
    fading = tree.nodes[stop_node][:props]["column_hold"]
    stop.hide(at_once: true)
    frame
    check("a fading box told to hide at once leaves the tree the next frame [held while fading, in the tree, picture]",
          [fading, tree.nodes.key?(stop_node), stop_root.base_surface], [true, false, nil])

    # A box that hides holds its place while it fades out and frees it once gone.
    15.times { frame }
    $quiet_line = "Hmph."
    holding = (1..30).map { frame; props.call(second_root).values_at("visible", "column_hold") }
    check("the hiding box holds its place while it fades out", holding.uniq, [[false, true]])
    frame
    check("it frees its place once gone", props.call(second_root)["column_hold"], false)
    $quiet_line = nil
    second.hide(at_once: true)

    # A column defined anew moves its shown box there.
    third = ui.show(Battle_Column::Box, tag: :third, line: "Again!")
    third_root = root_of.call(third)
    frame
    ui.column :battle_left, at: [24, 40], gap: 8
    frame
    check("the box moves with its column defined anew", props.call(third_root)["column"], ["battle_left", 24, 40, 8, "left"])
    third.hide(at_once: true)

    # A column no mod defined leaves the box at its own place.
    lost = ui.show(Battle_Column::Box, tag: :lost, line: "Lost", place: :battle_middle)
    lost_root = root_of.call(lost)
    frame
    check("a box in an unknown column shows at its own spot [column, at]", props.call(lost_root).values_at("column", "at"), [nil, [300, 300]])
    check("the unknown column is logged as refused",
          layer_lines.include?("Battle Column put a hud in the column :battle_middle, refused: no UI.column defined it, so the hud shows at its own place"), true)
    ui.column :battle_middle, at: [320, 4], align: :center
    frame
    check("the box joins the column once a mod defines it [column, at]", props.call(lost_root).values_at("column", "at"), [["battle_middle", 320, 4, 4, "center"], nil])

    refusal = begin
      eval("Mod_Framework::UI.column :battle_right, at: [632, 88], allign: :right", TOPLEVEL_BINDING, "Patch/Battle_Column.rb", 7)
      nil
    rescue ui::Engine::MarkupError => e
      e.message
    end
    check("a misspelt param of UI.column raises at the mod's line, naming the right one",
          [refusal.to_s.include?("UI.column takes no allign:; did you mean align:?"), refusal.to_s.include?("Battle_Column.rb:7")], [true, true])
  end
end
