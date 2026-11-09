#----------------------------------------------------------------
#  layer_page_view_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that the pane keeps room for its focus frame around its text
#                            - Removed the backdrop
#                            - Checked a log whose owner lays its groups out with their folds and a none line
#                            - Checked that the list pages the pane, which takes the focus while it holds no key stop, and
#                              that the window takes no page step for it
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers page_view, page_head and page_pane of the UI layer (design v2 section 5.5) in a booted game
# against FakeTree, through a mod's quest page: the main quest in the head, the side and companion
# quests in groups that fold, the pane showing the quest picked, bound both ways, with room for its
# focus frame around its text, over a faint picture; then a log whose owner lays its groups out, keeps their folds and shows a none line.
# page_view_test.rb covers the engine's keys of the pane.

require_relative "layer_support"

CAMP_QUESTS = <<-RUBY
  module Camp_Quests
    UI = Mod_Framework::UI

    Quest = Struct.new(:title, :kind, :text)

    class Quests < UI::Component
      state(:quests) do
        [Quest.new("Find the lost ring", "Side quests", "I lost my ring near the river."),
         Quest.new("Bring herbs", "Side quests", "The healer needs three herbs."),
         Quest.new("Ana: a song for the camp", "Companion quests", "Ana wants to hear the old song.")]
      end
      state :picked
      state(:folds) { [] }

      def render
        window "Quests", id: :camp_quests, width: 480, height: 300 do
          page_view quests, group: :kind, text: :title, bind: :picked, id: :quest_page,
                    on_fold: ->(group, open) { self.folds = folds + [[group, open]] } do
            page_head pick: :main do
              text "Main quest"
              text "Go to the harpy village."
            end
            page_pane do
              text pane_text, wrap: true, id: :pane_text
              button "Track", id: :track, on_click: -> {} if picked.is_a?(Quest)
            end
          end
        end
      end

      def pane_text
        return "Go to the harpy village and speak with the elder." if picked == :main

        picked ? picked.text : ""
      end
    end
  end
RUBY

QUEST_LOG = <<-RUBY
  module Quest_Log
    UI = Mod_Framework::UI

    class QuestLog < UI::Component
      state(:shut) { ["Done"] }
      state :picked

      def render
        window "Quest log", id: :quest_log, width: 480, height: 300 do
          page_view [[:group, "Active"], "Find the lost ring", [:group, "Failed"], [:none], [:group, "Done"], "Bring herbs"],
                    row: ->(item) { row_of(item) }, bind: :picked, id: :log_page,
                    on_fold: ->(group, open) { self.shut = open ? shut - [group] : shut + [group] } do
            page_pane { text picked.to_s, id: :log_pane }
          end
        end
      end

      def row_of(item)
        return item if item.is_a?(String)
        return { none: "None right now." } if item == [:none]

        { group: item[1], text: item[1], open: !shut.include?(item[1]) }
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Quests.rb", CAMP_QUESTS)
    frame

    ui.open(Camp_Quests::Quests)
    frame
    Graphics.update
    page = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    view = root.find(:quest_page)
    texts = lambda { view.list.rows.map { |row| [row[:text], row[:indent]] } }
    head = view.instance_variable_get(:@head)
    check("the page as it opens [entries and their indent, head texts]",
          [texts.call, head.children.first.children.map { |shown| shown.text }],
          [[["▾ Side quests (2)", nil], ["Find the lost ring", 8], ["Bring herbs", 8], ["▾ Companion quests (1)", nil], ["Ana: a song for the camp", 8]],
           ["Main quest", "Go to the harpy village."]])

    # The cursor on Bring herbs picks it and the pane shows it; the head taking the focus picks the
    # main quest.
    tell(tree, [[view.list.node, "change", 2]])
    check("Bring herbs picked [bound, pane]", [page.picked.title, root.find(:pane_text).text], ["Bring herbs", "The healer needs three herbs."])
    tell(tree, [[head.node, "focus"]])
    check("the head picked [bound, pane, Track]", [page.picked, root.find(:pane_text).text, root.find(:track)], [:main, "Go to the harpy village and speak with the elder.", nil])

    # Confirm on the side quests folds them and tells on_fold; confirm on an entry asks the focus
    # into the pane.
    tell(tree, [[view.list.node, "submit", 0]])
    check("the side quests folded [entries, on_fold]", [texts.call.map(&:first), page.folds],
          [["▸ Side quests (2)", "▾ Companion quests (1)", "Ana: a song for the camp"], [["Side quests", false]]])
    tell(tree, [[view.list.node, "change", 2]])
    tell(tree, [[view.list.node, "submit", 2]])
    asked = tree.changes.map { |changes| changes["focus_in"] }.compact.last
    check("confirm on Ana's quest asks the focus into the pane", asked, view.pane.node)

    # The pane of text holds no key stop, so it takes the focus itself and the arrows scroll it;
    # Page Up and Page Down from the list scroll it; Q and W are left to the window's on_page.
    check("C# learns the paging of the list and the pane's keys [pages_beside, focusable, jump_only, keep_ends, the window's page step]",
          [tree.nodes[view.list.node][:props]["pages_beside"]] + tree.nodes[view.pane.node][:props].values_at("focusable", "jump_only", "keep_ends") +
          [tree.nodes[view.root.node][:props]["pages"]], [true, true, true, true, false])
    sides = tree.nodes[view.pane.node][:props]["padding"]
    check("the pane keeps room for its focus frame around its text [top, left, bottom]", sides.values_at(0, 3, 2),
          [ui::Engine::Box::FOCUS_ROOM] * 3)

    # The owner binds the lost ring: its group opens again by the player's fold only, so the cursor
    # stays; once opened, the bound quest gets the cursor.
    page.picked = page.quests[0]
    frame
    Graphics.update
    tell(tree, [[view.list.node, "submit", 0]])
    page.picked = page.quests[0]
    frame
    Graphics.update
    check("the lost ring bound by the owner once its group is open [cursor's row]", view.list.rows[view.list.index][:text], "Find the lost ring")

    # A log whose owner lays its groups out and keeps their folds: Done starts shut, Failed shows
    # its none line; the player opens Done, which the owner keeps, and picks the herbs.
    load_mod("Patch/Quest_Log.rb", QUEST_LOG)
    ui.open(Quest_Log::QuestLog)
    frame
    Graphics.update
    log = ui::Engine::Layer.tops.last.mount.component
    log_view = ui::Engine::Tree.roots.last.find(:log_page)
    rows = lambda { log_view.list.rows.map { |row| row[:text] || row[:heading] } }
    check("the owner's groups as the log opens", rows.call, ["▾ Active", "Find the lost ring", "▾ Failed", "None right now.", "▸ Done"])
    tell(tree, [[log_view.list.node, "submit", 4]])
    check("Done opened by the player and kept by the owner [rows, shut]", [rows.call, log.shut],
          [["▾ Active", "Find the lost ring", "▾ Failed", "None right now.", "▾ Done", "Bring herbs"], []])
    tell(tree, [[log_view.list.node, "change", 5]])
    check("the herbs picked [bound, pane]", [log.picked, ui::Engine::Tree.roots.last.find(:log_pane).text], ["Bring herbs", "Bring herbs"])
  end
end
