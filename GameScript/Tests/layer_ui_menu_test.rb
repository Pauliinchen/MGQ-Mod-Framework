#----------------------------------------------------------------
#  layer_ui_menu_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Heard an item taken through on_submit
#      Paulinchen  2026-11-07: Greyed rows and choices with disabled:
#      Paulinchen  2026-11-06: Checked that the items of menu open as the root mf_menu of the UI layer, which cancel closes alone
#                            - Checked that the items of a choice stay above their menu once it rendered again
#                            - Called the engine's classes by their names under UI::Engine
#                            - Checked that a menu whose box fails is logged with why and tells on_refuse
#                            - Checked that the menus of UI.menu lie in the popups' band, the items of a choice above its menu
#                            - Checked that a greyed choice of UI.menu tells on_refuse and the menu stays
#                            - Checked that a menu of UI.menu and the items of its choice move with the window they came from
#                            - Checked the menu of UI.menu as a dialog of the UI layer
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers menu and UI.menu of the UI layer (design v2 sections 4.7 and 5.6) in a booted game against
# FakeTree, through a mod's party page: Ana's menu button opens its items under it; a duel that
# cannot be taken buzzes and tells on_refuse; Trade opens its own items beside its row, where Gold is
# picked and both menus close; cancel in Trade's items steps back to the first menu, and cancel there
# closes it without a pick, the party window staying open. Then a menu at the pointer for Bob, one at a time, whose greyed
# choice tells on_refuse and whose pick reaches its block. Last, Ana's menu moves with the party window, and so do a menu a click on
# Bob's name opened and the items of its Trade beside it, which stay above it and close with the window. A menu whose
# box fails, for a width that does not fit, opens nothing, is logged with why and tells on_refuse.

require_relative "layer_support"

PARTY_PAGE = <<-RUBY
  module Party_Page
    UI = Mod_Framework::UI

    class Page < UI::Component
      state(:picked) { [] }
      state(:refused) { [] }

      def render
        window "Party" do
          menu "Ana", id: :ana_menu, on_submit: ->(item) { self.picked = picked + [item] },
                      on_refuse: ->(item) { self.refused = refused + [item[:text]] },
                      items: ["Invite", { text: "Trade", items: ["Gold", "Herbs"] },
                              { text: "Duel", disabled: true, tooltip: "Not in a battle." }]
          text "Bob", id: :bob_name, on_click: -> { UI.menu(["Whisper", { text: "Trade", items: ["Gold"] }], at: :pointer) { |_choice, _index| } }
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    $sounds = []
    load_mod("Patch/Party_Page.rb", PARTY_PAGE)
    frame
    party = ui.open(Party_Page::Page)
    frame
    page = ui::Engine::Layer.tops.last.mount.component
    window = ui::Engine::Layer.tops.last.root.engine
    button = ui::Engine::Layer.tops.last.root.engine.find(:ana_menu)
    tree.rects[button.node] = [40, 60, 80, 24]
    frame
    menu_list = lambda { |menu| menu.children.find { |child| child.is_a?(ui::Engine::List) } }

    # The button opens Ana's items under it, Trade marked as a way into items of its own.
    tell(tree, [[button.node, "click"]])
    first = ui::Engine::Tree.roots.last
    check("the menu under the button [its top left, its rows]", [first.at, menu_list.call(first).rows.map { |row| [row[:text], row[:right]] }],
          [[40, 84], [["Invite", nil], ["Trade", "▸"], ["Duel", nil]]])

    # Duel cannot be taken: on_refuse hears it and the menu stays.
    tell(tree, [[menu_list.call(first).node, "refuse", 2]])
    check("the refused item, and the menu after it", [page.refused, first.open?], [["Duel"], true])

    # Trade opens Gold and Herbs beside its row, right of the first menu, as narrow as its items;
    # Gold reaches on_submit and both menus close.
    tree.rects[first.node] = [40, 84, first.width, 96]
    tree.rects[menu_list.call(first).node] = [52, 96, first.width - 24, 72]
    frame
    tell(tree, [[menu_list.call(first).node, "change", 1], [menu_list.call(first).node, "submit", 1]])
    trade = ui::Engine::Tree.roots.last
    check("Trade's items in a menu of their own [rows, left, top, narrower than 150]",
          [menu_list.call(trade).rows.map { |row| row[:text] }, trade.at[0], trade.at[1], trade.width < 150],
          [["Gold", "Herbs"], 40 + first.width, 96 + 24 - 12, true])
    2.times { frame }
    popups = Mod_Framework::UI::BANDS[:popups]
    check("both menus in the popups' band above every window and dialog, Trade's items above the first, as they render again",
          [popups.include?(first.z), popups.include?(trade.z), trade.z > first.z, first.z > window.z], [true, true, true, true])
    tell(tree, [[menu_list.call(trade).node, "submit", 0]])
    check("the item picked, and both menus after it", [page.picked, first.open?, trade.open?], [["Gold"], false, false])

    # The items open as the root mf_menu of the UI layer. Cancel in Trade's items steps back to the
    # first menu; cancel there closes only it, no pick.
    tell(tree, [[button.node, "click"]])
    first = ui::Engine::Tree.roots.last
    check("the button's items as a root of the UI layer [its id, the layer's top]", [first.id, ui::Engine::Layer.tops.last.id], [:mf_menu, "mf_menu"])
    tell(tree, [[menu_list.call(first).node, "submit", 1]])
    trade = ui::Engine::Tree.roots.last
    tell(tree, [[trade.node, "close", "cancel"]])
    check("cancel in Trade's items [first menu open, Trade's open]", [first.open?, trade.open?], [true, false])
    tell(tree, [[first.node, "close", "cancel"]])
    check("cancel closes only the first menu, without a pick [menu open, window open, picked]", [first.open?, window.open?, page.picked], [false, true, ["Gold"]])

    # At the right edge of the screen Trade's items open left of the first menu.
    tell(tree, [[button.node, "click"]])
    first = ui::Engine::Tree.roots.last
    tree.rects[first.node] = [Graphics.width - 8 - first.width, 84, first.width, 96]
    tree.rects[menu_list.call(first).node] = [Graphics.width - first.width + 4, 96, first.width - 24, 72]
    frame
    tell(tree, [[menu_list.call(first).node, "submit", 1]])
    trade = ui::Engine::Tree.roots.last
    check("Trade's items at the screen's right edge [their right edge at the first menu's left]",
          trade.at[0] + trade.width, Graphics.width - 8 - first.width)
    tell(tree, [[first.node, "close", "cancel"]])

    # A menu at the pointer for Bob, one at a time; its pick reaches the block with its place.
    $mouse_at = [100, 200]
    frame
    answers = []
    refusals = []
    bob = ui.menu(["Whisper", "Invite", { text: "Duel", disabled: true, tooltip: "Not in a battle." }], at: :pointer, title: "Bob",
                  on_refuse: ->(choice, index) { refusals << [choice[:text], index] }) { |choice, index| answers << [choice, index] }
    frame
    at = ui::Engine::Tree.roots.last
    check("Bob's menu stands with its bottom at the pointer [left, bottom above the pointer]", [at.at[0], at.at[1] < 200], [100, true])
    check("a second menu while Bob's is open", ui.menu(["Other"]), false)
    tell(tree, [[menu_list.call(at).node, "refuse", 2]])
    check("Duel, greyed, tells on_refuse with its place, and the menu stays", [refusals, bob.open?], [[["Duel", 2]], true])
    tell(tree, [[menu_list.call(at).node, "submit", 0]])
    check("the choice the block got, and the handle after it", [answers, bob.open?], [[["Whisper", 0]], false])

    # Ana's menu moves as far as the party window is dragged, and closes with the window.
    tell(tree, [[button.node, "click"]])
    first = ui::Engine::Tree.roots.last
    tree.rects[window.node] = [window.rect.x + 30, window.rect.y + 10, window.rect.width, window.rect.height]
    2.times { frame }
    check("the menu after the window moved 30 right and 10 down", first.at, [70, 94])
    tell(tree, [[first.node, "close", "outside"]])

    # The menu a click on Bob's name opens at the pointer, and Trade's items beside it, move as far
    # as the window is dragged, and close with the window.
    $mouse_at = [200, 300]
    tell(tree, [[window.find(:bob_name).node, "click"]])
    named = ui::Engine::Tree.roots.last
    frame
    tell(tree, [[menu_list.call(named).node, "submit", 1]])
    goods = ui::Engine::Tree.roots.last
    frame
    check("Trade's items above Bob's menu once that rendered again after the pick, so cancel reaches them", goods.z > named.z, true)
    before = [named.at, goods.at]
    tree.rects[window.node] = [window.rect.x - 20, window.rect.y + 15, window.rect.width, window.rect.height]
    4.times { frame }
    check("Bob's menu and Trade's items after the window moved 20 left and 15 down", [named.at, goods.at],
          before.map { |spot| [spot[0] - 20, spot[1] + 15] })
    party.close
    frame
    check("the menus after the window closed [Bob's, Trade's items, a dialog of the UI layer with its id]", [named.open?, goods.open?, named.id], [false, false, :mf_menu])

    # A menu whose box cannot render opens nothing; the log names the mod and why, and on_refuse
    # hears it; the next menu opens.
    $told = []
    failed = nil
    lines = logged_lines { failed = load_mod("Patch/Party_Page.rb", "Mod_Framework::UI.menu(['Rest'], width: -5, on_refuse: ->(choice, why) { $told << [choice, why] })") }
    why = "its render failed: width: takes px, `:fill`, `:content`, `:screen`, not -5"
    check("the failed menu [answer, logged, told]", [failed, lines.grep(/UI.menu did not open/), $told],
          [false, ["components: Party Page (Party_Page.rb:1): UI.menu did not open: #{why}"], [[nil, why]]])
    check("the next menu opens", ui.menu(["Rest"]).open?, true)
  end
end
