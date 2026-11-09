#----------------------------------------------------------------
#  layer_search_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

# Covers a search typed in place in a bar of buttons on the UI layer, in a booted game against
# FakeTree: the field leaves to the parts beside it at the ends of its text (leave_sides:), the
# cancel that stops its typing empties it (on_cancel), and Enter and that cancel move the focus
# back onto the bar through the handle's focus.

require_relative "layer_support"

CAMP_SEARCH = <<-RUBY
  module Camp_Search
    UI = Mod_Framework::UI

    class Bag < UI::Component
      state :search, ""

      def render
        window "Bag", id: :camp_search do
          stack row: true do
            button "Refresh", id: :camp_search_refresh, on_click: -> { nil }
            text_field bind: :search, id: :camp_search_field, leave_sides: true,
                       on_submit: ->(_text) { part(:camp_search_refresh).focus },
                       on_cancel: -> { self.search = ""; part(:camp_search_refresh).focus }
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ui.edit.open") { |_request| 1 }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| nil }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Search.rb", CAMP_SEARCH)
    frame
    ui.open(Camp_Search::Bag)
    frame
    bag = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Layer.tops.last.root.engine
    field = root.find(:camp_search_field)
    refresh = root.find(:camp_search_refresh)
    focused = lambda { (change = tree.changes.reverse.find { |each| each["focus"] }) && change["focus"] }
    check("C# learns that the field leaves at the ends of its text", tree.nodes[field.node][:props]["leave_sides"], true)

    tell(tree, [[field.node, "focus"], [field.node, "change", "herb"]])
    tell(tree, [[field.node, "enter"]])
    check("Enter keeps the search and moves the focus back onto the bar", [bag.search, focused.call], ["herb", refresh.node])

    tell(tree, [[field.node, "focus"], [field.node, "cancelled"], [field.node, "rest"]])
    check("the cancel that stops the typing empties the search and moves the focus onto the bar", [bag.search, field.text, focused.call], ["", "", refresh.node])
  end
end
