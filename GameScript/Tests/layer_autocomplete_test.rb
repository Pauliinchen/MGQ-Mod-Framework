#----------------------------------------------------------------
#  layer_autocomplete_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Heard the match taken through on_complete
#      Paulinchen  2026-11-07: Checked that a form with a required autocomplete refuses it empty and is sent once a match is taken
#                            - Created
#
#----------------------------------------------------------------

# Covers the autocomplete of the UI layer in a booted game against FakeTree and the DLL's text box,
# through a mod's quest search: the matches of the whole text typed, anywhere in a quest's name and
# ignoring case, in a box under the field from its left; Enter takes the lit match, which becomes
# the field's text, the bound state's and what on_complete hears; its form refuses it empty, as it is
# required, and is sent once a match is taken.

require_relative "layer_support"

QUEST_SEARCH = <<-RUBY
  module Quest_Search
    UI = Mod_Framework::UI

    class Search < UI::Component
      state :quest, ""
      state(:picked) { [] }
      state :ready, false
      state :sent, 0

      def render
        window "Quests" do
          form bind_valid: :ready, on_submit: -> { self.sent += 1 } do
            autocomplete "Quest", bind: :quest, items: ["Find the herbs", "The herbalist's request", "Rope bridge"], required: "Pick a quest",
                         on_complete: ->(name) { self.picked = picked + [name] }
            button "Search", on_click: :submit
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  opened = []
  fake.answer("ui.edit.open") { |request| opened << request; opened.size }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| { "id" => opened.size, "text" => "", "cursor" => 0, "shown" => true, "view" => { "line" => [0, 0, 0] } } }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Quest_Search.rb", QUEST_SEARCH)
    frame

    ui.open(Quest_Search::Search)
    frame
    search = ui::Engine::Layer.tops.last.mount.component
    field = ui::Engine::Tree.component(nodes_of(tree, "text_field").last)
    check("the field shows its label above it and offers nothing while empty", [field.parent.children.first.text, field.completions], ["Quest", []])
    error_of = lambda { shown = field.parent.children.last; shown.is_a?(ui::Engine::Label) && shown.visible? ? shown.text : nil }
    tell(tree, [[ui::Engine::Tree.component(nodes_of(tree, "button").last).node, "click"]])
    check("the form refuses the quest empty [error, sent]", [error_of.call, search.sent], ["Pick a quest", 0])

    # The player types "the HERB": the matches hold the whole text anywhere, ignoring case.
    tell(tree, [[field.node, "focus"]])
    $dll.post("ui.edit", "id" => opened.size, "text" => "HERB", "cursor" => 4, "shown" => true, "outcomes" => ["typed"], "keys" => 1, "chars" => 1)
    frame
    frame
    box = field.instance_variable_get(:@completion_box)
    check("the matches of the whole text, in a box under the field from its left",
          [field.completions, box.at[1] >= field.rect.y + field.rect.height, box.at[0]], [["Find the herbs", "The herbalist's request"], true, field.rect.x])
    $dll.post("ui.edit", "id" => opened.size, "text" => "HERB", "cursor" => 4, "shown" => true, "outcomes" => ["enter"], "keys" => 1, "chars" => 0)
    frame
    frame
    check("Enter takes the lit match as the whole text, which the bound state keeps and on_complete hears",
          [field.text, search.quest, search.picked, field.completions], ["Find the herbs", "Find the herbs", ["Find the herbs"], []])
    tell(tree, [[ui::Engine::Tree.component(nodes_of(tree, "button").last).node, "click"]])
    check("the form is sent with the match taken [error, ready, sent, a failed validate: logged]",
          [error_of.call, search.ready, search.sent, layer_lines.grep(/validate: of autocomplete failed/).size], [nil, true, 1, 0])
  end
end
