#----------------------------------------------------------------
#  layer_group_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers group and field of the UI layer (design v2 sections 5.2 and 5.3) in a booted game against
# FakeTree, through a mod's party sheet: a group titled Party with a live note of how many joined,
# holding a leader on a plate after its caption and the members; a member joining changes the note
# and the rows under the heading, which stays first.

require_relative "layer_support"

PARTY_SHEET = <<-RUBY
  module Party_Sheet
    UI = Mod_Framework::UI

    class Sheet < UI::Component
      state(:members) { ["Ana", "Mia"] }

      def render
        window "Party" do
          group "Party", note: -> { "\#{members.size} joined" }, note_color: :success do
            field "Leader", caption_width: 68, plate: true do
              text members.first
            end
            members.each { |member| text member, key: member }
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
    load_mod("Patch/Party_Sheet.rb", PARTY_SHEET)
    frame

    ui.open(Party_Sheet::Sheet)
    frame
    Graphics.update
    sheet = ui::Engine::Layer.tops.last.mount.component
    group = ui::Engine::Tree.roots.last.children.find { |child| child.is_a?(ui::Engine::Group) }
    texts = lambda { group.children.drop(1).map { |child| child.is_a?(ui::Engine::Field) ? [child.caption, child.body.children.map { |shown| shown.text }] : child.text } }
    leader = group.children[1]
    check("the sheet as it opens [title, note, note color, leader's caption width and plate, rows]",
          [group.heading.text, group.note_label.text, group.note_label.color, leader.caption_label.width, leader.plate, texts.call],
          ["Party", "2 joined", :success, 68, true, [["Leader", ["Ana"]], "Ana", "Mia"]])

    # Nora joins: the note and the rows follow, the heading stays first.
    sheet.members = sheet.members + ["Nora"]
    frame
    Graphics.update
    check("the sheet after Nora joined [heading first, note, rows]", [group.children.first.equal?(group.head), group.note_label.text, texts.call],
          [true, "3 joined", [["Leader", ["Ana"]], "Ana", "Mia", "Nora"]])
  end
end
