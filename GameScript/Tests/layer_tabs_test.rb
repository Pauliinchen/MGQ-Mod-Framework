#----------------------------------------------------------------
#  layer_tabs_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers tabs of the UI layer (design v2 section 5.6) in a booted game against FakeTree, through the
# details of a mod's item: a Back button before the tabs, the item's type under them, a tab that
# comes and goes with the item and is kept while it is gone, the tab picked bound to the window's
# state by its id, and a click on a tab. C# steps the tabs by Tab and the pad's shoulders in a root
# of the layer (TreeKeysTests).

require_relative "layer_support"

DETAILS = <<-RUBY
  module Item_Details
    UI = Mod_Framework::UI

    class DetailsWindow < UI::Component
      state :shown_tab
      state :socketed, true
      state(:heard) { [] }

      def render
        window "Details" do
          tabs bind: :shown_tab, on_change: ->(tab) { self.heard = heard + [tab] } do
            tabs_header do
              button "Back", on_click: :close
            end
            tabs_subheader do
              text "Sword"
            end
            tab "Info", id: :info do
              text "Iron Sword"
            end
            if socketed
              tab "Gems 1/2", id: :gems, badge: 1 do
                text "Ruby"
              end
            end
            tab "Set", id: :sets do
              text "No set"
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
    load_mod("Patch/Item_Details.rb", DETAILS)
    frame

    # The details open on their first tab, with the Back button before the tabs.
    ui.open(Item_Details::DetailsWindow)
    frame
    details = ui::Engine::Layer.tops.last.mount.component
    tabs = nodes_of(tree, "tabs").last
    engine = ui::Engine::Tree.component(tabs)
    texts = lambda { engine.bar.children.map { |part| part.children.map { |each| each.text } }.flatten }
    shown = lambda { engine.pages.select { |page| page.visible? }.map { |page| page.children.first.text } }
    check("the tabs open on the first, with Back before them", [texts.call, shown.call, details.shown_tab], [["Back", "Info", "Gems 1/2", "Set"], ["Iron Sword"], :info])
    under = lambda { engine.children[1].children.map { |part| part.children.map { |each| each.text } }.flatten }
    check("the type lies under the row of tabs, over the pages", under.call, ["Sword"])
    check("the tabs leave their keys to C#'s rules of the layer", tree.nodes[tabs][:props].key?("tab_key"), false)

    # Tab steps to the Gems tab, and the bound state hears it by its id.
    tell(tree, [[tabs, "step", 1]])
    check("a step picks the next tab and tells its id", [shown.call, details.shown_tab, details.heard], [["Ruby"], :gems, [:gems]])

    # The item loses its sockets: the Gems tab goes, the first tab shows and the state keeps Gems,
    # which shows again once the item has sockets again; the type stays under the tabs.
    details.socketed = false
    frame
    check("a tab that goes shows the first and stays picked", [texts.call, shown.call, details.shown_tab, under.call], [["Back", "Info", "Set"], ["Iron Sword"], :gems, ["Sword"]])
    details.socketed = true
    frame
    check("the tab kept shows as it comes back", [shown.call, details.shown_tab], [["Ruby"], :gems])

    # A click on Info picks it; writing the state picks a tab too.
    tell(tree, [[engine.tab(0).node, "click"]])
    check("a click on a tab picks it", [shown.call, details.shown_tab, details.heard.last], [["Iron Sword"], :info, :info])
    details.shown_tab = :sets
    frame
    check("writing the bound tab picks it", shown.call, ["No set"])
  end
end
