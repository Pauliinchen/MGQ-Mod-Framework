#----------------------------------------------------------------
#  layer_drop_zone_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the drop zones of the UI layer in a booted game against FakeTree, through a mod's
# formation of the party: a front row and a reserve, each member an item of their zone; the line
# that marks where a member carried would go, and a member put into the reserve, which on_drop
# moves in the mod's data so the zones show the new formation.

require_relative "layer_support"

FORMATION = <<-RUBY
  module Camp_Formation
    UI = Mod_Framework::UI

    class Formation < UI::Component
      state(:front) { ["Luka", "Alice"] }
      state(:reserve) { ["Tamamo"] }
      state(:moves) { [] }

      def render
        window "Formation" do
          drop_container on_drop: ->(name, from, to, place) { move(name, from, to, place) } do
            drop_zone :front, title: "Front row", items: front do |name|
              text name
            end
            drop_zone :reserve, title: "Reserve", items: reserve
          end
        end
      end

      def move(name, from, to, place)
        rows = { :front => front - [name], :reserve => reserve - [name] }
        rows[to] = rows[to].dup.insert(place, name)
        self.front = rows[:front]
        self.reserve = rows[:reserve]
        self.moves = moves + [[name, from, to, place]]
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Formation.rb", FORMATION)
    frame

    ui.open(Camp_Formation::Formation)
    frame
    Graphics.update
    formation = ui::Engine::Layer.tops.last.mount.component
    zones = lambda { nodes_of(tree, "box").map { |node| ui::Engine::Tree.component(node) }.select { |part| part.is_a?(ui::Engine::DropZone) } }
    shown = lambda do
      zones.call.map do |zone|
        [zone.zone, zone.children.select { |child| child.is_a?(ui::Engine::DropItem) }.map { |item| item.children.first.text }]
      end
    end
    check("each zone shows its members, the reserve by their names without a block", shown.call, [[:front, ["Luka", "Alice"]], [:reserve, ["Tamamo"]]])
    front, reserve = zones.call
    props = [front, reserve.children.first].map { |part| tree.nodes[part.node][:props].values_at("drop_zone", "drag", "focusable", "clickable") }
    check("a zone is a drop zone, its items one key stop each that is dragged", props, [[true, nil, false, false], [nil, true, true, true]])

    # C# picks Luka up and carries him over the reserve: the reserve marks the place before Tamamo.
    luka = front.children.first
    tell(tree, [[luka.node, "lift"], [reserve.node, "target", 0]])
    check("Luka carried, the reserve marks its first place [lifted, mark]", [luka.lifted?, reserve.send(:mark_spot)[1] < reserve.children.first.rect.y], [true, true])

    # C# puts him down there: the formation moves him into the reserve, before Tamamo.
    container_node = tree.nodes[front.node][:parent]
    tell(tree, [[luka.node, "unlift"], [reserve.node, "target", -1], [container_node, "drop", luka.node, front.node, reserve.node, 0]])
    frame
    Graphics.update
    check("the drop tells the member, both zones and the place", formation.moves, [["Luka", :front, :reserve, 0]])
    check("the zones show the new formation", shown.call, [[:front, ["Alice"]], [:reserve, ["Luka", "Tamamo"]]])
  end
end
