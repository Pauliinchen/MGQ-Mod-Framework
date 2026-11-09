#----------------------------------------------------------------
#  layer_slides_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Opened a window on the second page of its slides
#                            - Named focus among the calls of the slides' handle
#                            - Covered a pick that slides a page of slides with enter: into view and gives it the focus
#      Paulinchen  2026-11-05: Rendered a component on a page out of view only as the page comes into view
#                            - Slid the pages by the journal's own back and forward
#                            - Eased the pages in through the slides' handle
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers slides of the UI layer (design v2 section 5.2) in a booted game against FakeTree, through a
# mod's journal: two pages shown of three, the third refusing to slide in while no entry is picked,
# a button that slides on, the keys' slide and cancel's slide back, all bound to the window's state, and
# a button that eases the pages in through the slides' handle, and a component on a page out of view
# that renders only as its page comes into view; and a pick that slides slides with enter: onto a page,
# whose part with autofocus: takes the focus.
# C# replays when the keys slide in TreeCancelTests.

require_relative "layer_support"

JOURNAL = <<-RUBY
  module Camp_Journal
    UI = Mod_Framework::UI

    class JournalWindow < UI::Component
      state :page, 0
      state :entry
      state(:heard) { [] }

      def render
        window "Journal", id: :camp_journal do
          slides bind: :page, shown: 2, id: :journal_pages, on_change: ->(page) { self.heard = heard + [[:change, page]] },
                 on_refuse: ->(page) { self.heard = heard + [[:refuse, page]] } do
            slide do
              text "Day 3"
            end
            slide do
              list ["Herbs", "Rope"], on_submit: ->(item) { self.entry = item }
              button "More", on_click: :forward
              button "Next day", on_click: -> { part(:journal_pages).enter_from(1) }
              button "Wrong", on_click: -> { part(:journal_pages).open_menu }
            end
            slide can_enter: -> { !entry.nil? } do
              text "About the entry"
              component EntryNote, entry: entry
            end
          end
        end
      end
    end

    class StrayWindow < UI::Component
      def render
        window "Stray" do
          slide do
            text "Lost"
          end
        end
      end
    end

    # The entries each render of the note showed.
    NOTES = []

    class EntryNote < UI::Component
      param :entry, nil

      def render
        NOTES << entry
        text entry.to_s
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Journal.rb", JOURNAL)
    frame

    # The journal opens on its first two pages; the third waits for an entry.
    ui.open(Camp_Journal::JournalWindow)
    frame
    journal = ui::Engine::Layer.tops.last.mount.component
    slides = nodes_of(tree, "slides").last
    engine = ui::Engine::Tree.component(slides)
    check("the slides show two pages from the first", [engine.pages.size, tree.nodes[slides][:props]["shown"], engine.index], [3, 2, 0])

    # Right at the edge asks for the third page, which refuses while no entry is picked.
    tell(tree, [[slides, "slide", 1]])
    check("a slide to a page that may not come in stays put and tells on_refuse", [engine.index, journal.page, journal.heard], [0, 0, [[:refuse, 2]]])

    # With an entry picked, the More button slides on, and the bound page follows; the note on the
    # page out of view renders the entry only as that page comes into view.
    journal.entry = "Rope"
    frame
    rendered_out_of_view = Camp_Journal::NOTES.dup
    more = nodes_of(tree, "button")[-3]
    tell(tree, [[more, "click"]])
    frame
    check("More slides a page on, the bound page and on_change follow", [engine.index, journal.page, journal.heard.last], [1, 1, [:change, 1]])
    check("the note out of view renders the new entry only once its page comes into view", [rendered_out_of_view, Camp_Journal::NOTES], [[nil], [nil, "Rope"]])
    check("More is left to the mouse, since the keys slide anyway", tree.nodes[more][:props]["repeats"], true)

    # Cancel slides back, and a page the window writes slides there by itself.
    tell(tree, [[slides, "back"]])
    check("cancel slides a page back", [engine.index, journal.page], [0, 0])
    journal.page = 1
    frame
    check("writing the bound page slides there, without on_change", [engine.index, journal.heard.last], [1, [:change, 0]])

    # The journal's own back and forward slide its slides, as its code calls them.
    journal.back
    frame
    back = engine.index
    journal.forward
    frame
    check("the pages after the journal's back, then its forward", [back, engine.index], [0, 1])

    # Next day eases the pages in from the right through the slides' handle; a call slides do not
    # have is refused and named in the log with the calls they have.
    tell(tree, [[nodes_of(tree, "button")[-2], "click"]])
    eased = [engine.offset[0] > 0, engine.opacity < 255]
    tell(tree, [[nodes_of(tree, "button")[-1], "click"]])
    check("Next day eases the pages in from the right, half see-through, and a call slides do not have is refused",
          [eased, layer_lines.any? { |line| line.include?("slides has no call open_menu; it has focus, enter_from") }], [[true, true], true])

    # A slide outside slides is refused where it is written.
    ui.open(Camp_Journal::StrayWindow)
    frame
    check("a slide outside slides is refused with its place", layer_lines.any? { |line| line.include?("(Camp_Journal.rb:33): Camp_Journal::StrayWindow's render failed: slide goes inside slides, not inside window") }, true)
  end
end

ROSTER = <<-RUBY
  module Camp_Roster
    UI = Mod_Framework::UI

    class RosterWindow < UI::Component
      param :start, 0
      state(:page) { start }
      state :member

      def render
        window "Roster", id: :camp_roster do
          slides bind: :page, enter: true do
            slide do
              list ["Alice", "Granberia"], id: :roster_list, on_submit: ->(member) { self.member = member; self.page = 1 }
            end
            slide do
              text member.to_s
              button "Train", id: :roster_train, on_click: -> { nil }
              button "Lead", id: :roster_lead, autofocus: true, on_click: -> { nil }
            end
          end
        end
      end
    end
  end
RUBY

# A pick that slides a page of slides with enter: into view moves the focus onto that page's part
# with autofocus:; a window opens on its second page as well.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Roster.rb", ROSTER)
    frame
    ui.open(Camp_Roster::RosterWindow)
    frame
    root = ui::Engine::Layer.tops.last.root.engine
    list = root.find(:roster_list)
    tell(tree, [[list.node, "submit", 1]])
    focused = tree.changes.reverse.find { |each| each["focus"] }
    check("a pick that opens the page moves the focus onto its part with autofocus:", focused && focused["focus"], root.find(:roster_lead).node)

    ui.open(Camp_Roster::RosterWindow, :start => 1)
    frame
    slides = ui::Engine::Tree.component(nodes_of(tree, "slides").last)
    check("a window opened on its second page shows it", slides.index, 1)
  end
end
