#----------------------------------------------------------------
#  layer_timeline_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the timeline of the UI layer in a booted game against FakeTree, through a mod's journal
# of the story: each entry's title and text beside its dot, the line that joins each dot to the
# entries before and after, and an entry added as the story goes on, which carries the line on.

require_relative "layer_support"

JOURNAL = <<-RUBY
  module Story_Journal
    UI = Mod_Framework::UI

    class Journal < UI::Component
      state(:entries) { [["Left Iliasville", "Luka set out to become a hero."], ["Met Alice", nil]] }

      def render
        window "Journal" do
          timeline do
            entries.each_with_index do |(title, text), place|
              timeline_item title, text: text, key: place, color: place == 0 ? :secondary : nil
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
    load_mod("Patch/Story_Journal.rb", JOURNAL)
    frame

    ui.open(Story_Journal::Journal)
    frame
    Graphics.update
    journal = ui::Engine::Layer.tops.last.mount.component
    items = lambda { nodes_of(tree, "custom").map { |node| ui::Engine::Tree.component(node) }.select { |part| part.is_a?(ui::Engine::TimelineMark) }.map { |mark| mark.parent } }
    texts = lambda { items.call.map { |item| item.children.last.children.select { |label| label.visible? }.map { |label| label.text } } }
    check("each entry shows its title, and its text under it where it has one", texts.call, [["Left Iliasville", "Luka set out to become a hero."], ["Met Alice"]])
    check("the first dot takes its color, the others primary", items.call.map { |item| item.mark.color }, [:secondary, :primary])
    lines = lambda { items.call.map { |item| item.mark.send(:line_ends) } }
    check("the line runs down from the first entry and up to the last", lines.call, [[false, true], [true, false]])

    # The story goes on: the new entry joins the line, which now runs on from Alice.
    journal.entries = journal.entries + [["Reached Iliasport", "The harbor town."]]
    frame
    Graphics.update
    check("the new entry joins the line [up, down] per entry", lines.call, [[false, true], [true, true], [true, false]])
  end
end
