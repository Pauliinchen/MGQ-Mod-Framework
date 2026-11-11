#----------------------------------------------------------------
#  layer_slot_row_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Heard a slot picked through on_submit
#      Paulinchen  2026-11-09: Checked tooltips of markup on the slots of a slot row and the lines of lines, read anew as the
#                              state changes while the slots stay as they are
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers slot_row of the UI layer in a booted game against FakeTree, through a mod's skill bar: a
# party member's skills as icon slots with their names as tooltips and an empty slot's mark, the
# note at the end of a skill's tooltip, a slot picked (C# tells confirm and a click alike) and
# pulsed by the call of the part's handle, and the dim text of a bar without skills; then a spell
# book whose slot and lines take tooltips of markup, which show the state of now while the slots
# stay the same parts.

require_relative "layer_support"

BAR = <<-RUBY
  module Skill_Bar
    UI = Mod_Framework::UI

    class BarWindow < UI::Component
      state(:skills) { [{ icon: 64, tooltip: "Heal" }, nil, { icon: 65, tooltip: "Fire" }] }
      state(:picked) { [] }

      def render
        window "Skills" do
          slot_row skills, id: :bar, empty_icon: 16, empty_tooltip: "No skill", empty: "No skills learned", note: "Click to use",
                           on_submit: ->(place) { self.picked = picked + [place]; part(:bar).pulse([place]) }
        end
      end
    end

    class BookWindow < UI::Component
      state :cost, 10

      def render
        window "Spells" do
          slot_row [{ icon: 64, tooltip: -> { text "Heal"; text "\#{cost} MP", color: :system } }], note: "Click to cast", on_submit: ->(place) {}
          lines [{ label: "Magic", lines: [{ text: "Heal", tooltip: -> { text "Restores HP for \#{cost} MP" } }] }]
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Skill_Bar.rb", BAR)
    frame

    # Heal and Fire show their icons, the slot between them the empty mark with its tooltip.
    ui.open(Skill_Bar::BarWindow)
    frame
    window = ui::Engine::Layer.tops.last.mount.component
    bar = ui::Engine::Tree.component(nodes_of(tree, "stack").find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::Slots) })
    look = lambda { |button| button.instance_variable_get(:@options).values_at(:icon, :tooltip) }
    check("the skills show their icons and the empty slot its mark", bar.children.map { |button| look.call(button)[0] }, [64, 16, 65])
    check("the empty slot's tooltip", look.call(bar.children[1])[1], "No skill")

    # Heal's tooltip names it and ends in the note.
    tip = ui::Engine::Box.new
    look.call(bar.children[0])[1].call(tip)
    texts = lambda { |part| part.respond_to?(:text) ? [part.text] : part.children.map { |child| texts.call(child) }.flatten }
    check("a skill's tooltip ends in the note", texts.call(tip), ["Heal", "Click to use"])

    # Fire picked tells its place and pulses once the next frame rendered.
    tell(tree, [[bar.children[2].node, "click"]])
    frame
    check("a picked slot tells its place and pulses", [window.picked, bar.children[2].opacity < 255], [[2], true])

    # A party member without skills shows the dim text in place of the bar.
    window.skills = []
    frame
    check("a bar without slots shows the empty text", bar.children.map { |part| part.text }, ["No skills learned"])

    # The spell book's slot and line show their markup; once the cost changes they show the new
    # cost, and the slot is still the same part.
    ui.open(Skill_Bar::BookWindow)
    frame
    book = ui::Engine::Layer.tops.last.mount.component
    in_book = lambda { |klass| nodes_of(tree, "stack").map { |node| ui::Engine::Tree.component(node) }.select { |part| part.instance_of?(klass) }.last }
    spell = in_book.call(ui::Engine::Slots).children[0]
    effects = in_book.call(ui::Engine::Lines)
    tree.rects[effects.node] = [0, 0, 300, 100]
    frame
    tips = lambda do
      slot_tip = ui::Engine::Box.new
      look.call(in_book.call(ui::Engine::Slots).children[0])[1].call(slot_tip)
      line_tip = ui::Engine::Box.new
      in_book.call(ui::Engine::Lines).children.find { |part| part.is_a?(ui::Engine::Label) && part.text == "Heal" }.tooltip.call(line_tip)
      [texts.call(slot_tip), texts.call(line_tip)]
    end
    shown = tips.call
    book.cost = 12
    frame
    check("a slot's and a line's markup tooltips show the cost of now, the slot's ending in the note, and the slot stays the same part",
          [shown, tips.call, in_book.call(ui::Engine::Slots).children[0].equal?(spell)],
          [[["Heal", "10 MP", "Click to cast"], ["Restores HP for 10 MP"]], [["Heal", "12 MP", "Click to cast"], ["Restores HP for 12 MP"]], true])
  end
end
