#----------------------------------------------------------------
#  layer_list_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a filter that keeps some rows, a pick among them and the row that says none is left
#      Paulinchen  2026-11-07: Dropped cancel_to:, which the cancel rule replaces
#      Paulinchen  2026-11-06: Covered a pick that goes on into the slots, from where cancel comes back to the bag
#      Paulinchen  2026-11-05: Covered rows with a value that Left and Right step, and an item's description as its tooltip
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers the rows of a list of the UI layer (design v2 section 5.5) in a booted game against
# FakeTree, through a mod's camp bag: items with their icon and count, a character's slots given as
# rows of their own, a pick that hands back the item, not its row, and goes on into the slots, a
# pouch whose filter keeps some rows and says so when it keeps none, and the herbs a trade gives:
# rows whose value Left and Right step within the count, each herb's description as its tooltip.

require_relative "layer_support"
require_relative "equip_support"

BAG_ROWS = <<-RUBY
  module Camp_Rows
    UI = Mod_Framework::UI

    Herb = Struct.new(:name, :icon_index, :count, :description)

    class BagWindow < UI::Component
      param :actor
      state :picked
      state :slot, 0

      def render
        window "Bag" do
          list [Herb.new("Herb", 176, 3), Herb.new("Rope", 210, 1)], text: :name, icon: :icon_index, right: ->(herb) { "x\#{herb.count}" },
               on_submit: ->(herb) { self.picked = herb }, id: :camp_bag, submit_to: :camp_slots
          list UI::Game.slot_rows(actor), bind_index: :slot, id: :camp_slots
        end
      end
    end

    class PouchWindow < UI::Component
      state :shown
      state :picked

      def render
        window "Pouch" do
          list [{ text: "Throw away", search: false }, { text: "Herb", icon: 176 }, { text: "Rope", icon: 210 }], filter: ->(row) { shown.nil? || row[:text] == shown },
               no_match: "No item matches", on_submit: ->(row) { self.picked = row }
        end
      end
    end

    class GiveWindow < UI::Component
      param :bag
      state(:given) { {} }

      def render
        window "Give to Mia" do
          list bag, row: ->(herb) { give_row(herb) }, describe: true, on_side: ->(herb, step) { give(herb, step) }
        end
      end

      def give_row(herb)
        count = given[herb.name] || 0
        { item: herb, value: "\#{count} / \#{herb.count}", less: count > 0, more: count < herb.count }
      end

      def give(herb, step)
        self.given = given.merge(herb.name => (given[herb.name] || 0) + step)
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    luka = equip_party
    load_mod("Patch/Camp_Rows.rb", BAG_ROWS)
    frame

    # The bag shows each item with its icon and count, and Luka's slots as the game reads them.
    ui.open(Camp_Rows::BagWindow, actor: luka)
    frame
    bag = ui::Engine::Layer.tops.last.mount.component
    herbs, slots = nodes_of(tree, "list").map { |node| ui::Engine::Tree.component(node) }
    check("the items show their icon and count", herbs.rows, [{ :text => "Herb", :icon => 176, :right => "x3" }, { :text => "Rope", :icon => 210, :right => "x1" }])
    check("rows given as Hashes show as they are", [slots.rows.size, slots.rows[0][:item].name], [3, "Zantetsuken"])

    # A pick hands the item to on_submit and goes on into the slots.
    tree.changes.clear
    tell(tree, [[herbs.node, "submit", 1]])
    check("a pick tells the item, not its row, and moves the focus to the slots",
          [bag.picked.name, tree.changes.map { |change| change["focus"] }.compact.last], ["Rope", slots.node])
    ui::Engine::Layer.tops.last.handle.close

    # The pouch keeps the Rope and the row a search cannot find, and a pick there hands back the
    # Rope; a filter that keeps nothing shows the dim row of no_match:, which takes no pick.
    ui.open(Camp_Rows::PouchWindow)
    frame
    pouch = ui::Engine::Layer.tops.last.mount.component
    pouch.shown = "Rope"
    frame
    list = ui::Engine::Tree.component(nodes_of(tree, "list").last)
    tell(tree, [[list.node, "submit", 1]])
    check("the filter keeps the Rope and the row of no search, and a pick hands back the Rope", [list.rows.map { |row| row[:text] }, pouch.picked[:text]],
          [["Throw away", "Rope"], "Rope"])
    pouch.shown = "Lamp"
    frame
    check("a filter that keeps nothing shows the dim row of no_match:, greyed", list.rows.map { |row| [row[:text], row[:disabled] == true] },
          [["Throw away", false], ["No item matches", true]])
    ui::Engine::Layer.tops.last.handle.close

    # The trade's herbs: Right gives one more herb, up to the count, and Left one fewer; each row
    # tells the herb's description as its tooltip.
    herb = Camp_Rows::Herb.new("Herb", 176, 2, "Heals a little.")
    ui.open(Camp_Rows::GiveWindow, bag: [herb])
    frame
    give = ui::Engine::Layer.tops.last.mount.component
    list = ui::Engine::Tree.component(nodes_of(tree, "list").last)
    check("the list hands Left and Right to its value rows", tree.nodes[list.node][:props].values_at("sides", "value_rows"), [true, [0]])
    2.times { tell(tree, [[list.node, "side", 0, 1]]) }
    check("two steps right give both herbs", [give.given, list.rows[0].values_at(:value, :less, :more)], [{ "Herb" => 2 }, ["2 / 2", true, false]])
    $sounds = []
    tell(tree, [[list.node, "side", 0, 1]])
    check("a third step right buzzes and gives nothing more", [$sounds, give.given], [[:buzzer], { "Herb" => 2 }])
    tell(tree, [[list.node, "side", 0, -1]])
    check("a step left gives one fewer", list.rows[0][:value], "1 / 2")
    shown = []
    box = Object.new
    box.define_singleton_method(:add_label) { |text, *_options| shown << text }
    list.send(:row_tip, list.rows[0], false).call(box)
    check("the row's tooltip is the herb's description", shown, ["Heals a little."])
  end
end

# The party's members with their place as a label and their level as a note: the labels' column as
# wide as the widest label of all members, also while a search hides that member; the notes after
# the widest name note_at: gives, and label_width: given as texts.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Party_Rows.rb", <<-RUBY)
      module Party_Rows
        UI = Mod_Framework::UI

        class Party < UI::Component
          state :note_at
          state :label_width

          def render
            window "Party" do
              list [%w(Leader Luka Lv12), %w(Reserve Alice Lv40), %w(Fighter Granberia Lv30)], id: :party, bind_index: :picked,
                   row: ->(member) { { label: member[0], text: member[1], note: member[2] } }, note_at: note_at, label_width: label_width
            end
          end
        end
      end
    RUBY
    frame

    ui.open(Party_Rows::Party)
    frame
    party = ui::Engine::Layer.tops.last.mount.component
    list = ui::Engine::Tree.roots.last.find(:party)
    draw = lambda do
      tree.rects[list.node] = [0, 0, 400, 72]
      list.placed([0, 0, 400, 72])
      frame
      Graphics.update
      list.inner_surface.bitmap.texts.each_with_object({}) { |(x, _y, text), lefts| lefts[text] = x }
    end
    widest = lambda { |texts| ui.measured_width(texts, ui.font_px(:normal)) }
    gap = ui::Engine::Style::GAP

    lefts = draw.call
    check("the names start after the widest label and a gap", lefts["Luka"] - lefts["Leader"], widest.call(%w(Reserve)) + gap)
    list.filter = "Luka"
    lefts = draw.call
    check("a search that hides the member with the widest label leaves the column", lefts["Luka"] - lefts["Leader"], widest.call(%w(Reserve)) + gap)
    list.filter = ""

    party.note_at = %w(Granberia)
    lefts = draw.call
    check("the notes start after the widest name note_at: gives, also after a short name",
          [lefts["Lv12"] - lefts["Luka"], lefts["Lv30"] - lefts["Granberia"]], [widest.call(%w(Granberia)) + gap] * 2)

    party.label_width = ["Reserve member"]
    lefts = draw.call
    check("label_width: given as texts sets the labels' column", lefts["Luka"] - lefts["Leader"], widest.call(["Reserve member"]) + gap)
  end
end
