#----------------------------------------------------------------
#  layer_window_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that a part laid out past the window's content draws only inside it
#                            - Checked the hint for a misspelled key of a context menu choice
#      Paulinchen  2026-11-06: Took the context menu's choice in its menu of the UI layer
#      Paulinchen  2026-11-04: Covered a window as high as the screen with an icon on its button
#                            - Kept a few flows of a mod's window and checked each outcome on its own
#                            - Created
#
#----------------------------------------------------------------

# Covers a window of the UI layer written as markup in a booted game against FakeTree: the Camp
# Notes sample of the design (section 3.2) with its list bound both ways, every way a window closes
# with its reason (design v2 section 9.3), and a part's context menu (sections 9.7 and 9.8). C#
# checks the cancel chain and the pointer in its own tests.

require_relative "layer_support"

CAMP_NOTES = <<-RUBY
  module Camp_Notes
    UI = Mod_Framework::UI

    class NotesWindow < UI::Component
      state(:notes) { ["Buy herbs", "Ask Alice about the map"] }
      state :picked

      def render
        window "Camp notes", id: :camp_notes, width: 320 do
          list notes, bind: :picked, dense: true, empty: "No notes yet"
          stack row: true, justify: :end do
            button "Clear", color: :error, disabled: picked.nil?, on_click: -> { self.notes = notes - [picked] }
            button "Close", on_click: :close
          end
        end
      end
    end

    class LeaveWindow < UI::Component
      def render
        params = { id: :camp_leave, close_outside: true, if: -> { $gate || true } }
        window "Leave camp", params do
          button "Rest", on_click: -> {}
        end
      end
    end

    class TallWindow < UI::Component
      def render
        window "Log", height: :screen do
          button "Close", icon: 12, on_click: :close
        end
      end
    end

    class ChestWindow < UI::Component
      state(:taken) { [] }

      def render
        window "Chest" do
          list ["Herb", "Rope"], id: :items,
               context_menu: -> { [{ text: "Take", on_click: -> { self.taken = taken + [:take] } },
                                   { text: "Drop", disabled: true, on_click: -> {} }, "Look"] }
          button "Go", on_click: -> {}, context_menu: [{ text: "Go", on_clik: -> {} }] if $typo
        end
      end
    end

    class PartyWindow < UI::Component
      def render
        window "Party" do
          text "Alice"
          text "Luka"
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Notes.rb", CAMP_NOTES)
    frame

    # The player opens the notes, picks one, clears both and closes the window.
    results = []
    ui.open(Camp_Notes::NotesWindow) { |result, why| results << [result, why] }
    frame
    list = nodes_of(tree, "list").last
    clear, close = nodes_of(tree, "button")
    notes = ui::Engine::Layer.tops.last.mount.component
    tell(tree, [[list, "change", 1]])
    tell(tree, [[clear, "click"]])
    check("Clear removes the picked note on the same list node", [notes.notes, nodes_of(tree, "list")], [["Buy herbs"], [list]])
    tell(tree, [[clear, "click"]])
    tell(tree, [[close, "click"]])
    check("Close reaches UI.open's block with :button", results, [[nil, :button]])

    # Every other way a window closes reaches UI.open's block with its reason.
    ui.open(Camp_Notes::NotesWindow) { |result, why| results << [result, why] }
    frame
    tell(tree, [[nodes_of(tree, "window").last, "close"]])
    check("cancel closes it with :cancel", results.last, [nil, :cancel])
    ui.open(Camp_Notes::NotesWindow) { |result, why| results << [result, why] }
    frame
    ui::Engine::Layer.tops.last.mount.component.close(:done)
    frame
    whys = []
    open = lambda do |params|
      opened = ui.open(Camp_Notes::LeaveWindow, params) { |_result, why| whys << why }
      frame
      [opened, nodes_of(tree, "window").last]
    end
    _leave, leave_window = open.call({})
    tell(tree, [[leave_window, "close", "outside"]])
    check("a click outside closes it with :outside", whys.last, :outside)
    open.call({})
    Scene_Base.new.terminate
    $scene_now = :menu
    Graphics.update
    $scene_now = :map
    check("the scene's end closes it with :scene", whys.last, :scene)
    leave, _leave_window = open.call({})
    $gate = "the map is busy"
    frame
    $gate = nil
    check("a gate that stops answering true closes it with its answer", [leave.open?, whys.last], [false, "the map is busy"])

    # A log as high as the screen, closed by a button with an icon.
    ui.open(Camp_Notes::TallWindow)
    frame
    tall = ui::Engine::Tree.component(nodes_of(tree, "window").last)
    close = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    check("a window as high as the screen, with an icon on its Close button", [tall.height, close.instance_variable_get(:@options)[:icon]], [Graphics.height, 12])
    tall.close

    # The player opens a list's context menu and takes an item; a misspelled choice is refused.
    ui.open(Camp_Notes::ChestWindow)
    frame
    Graphics.update
    items = nodes_of(tree, "list").last
    tell(tree, [[items, "context", 100, 120]])
    tell(tree, [[ui::Engine::Placement.find("#mf_menu_list").node, "submit", 0]])
    chest = ui::Engine::Layer.tops.last.mount.component
    check("a pick runs the choice's on_click", chest.taken, [:take])
    $typo = true
    chest.taken = []
    frame
    check("a choice with a misspelled key is refused",
          layer_lines.last.to_s.include?("context_menu: a choice takes no on_clik:; did you mean on_click:?"), true)
    chest.close(:done)
    frame

    # A name laid out past the bottom of the window's content draws only inside it, never over the
    # frame: its line, which starts below, is left out.
    ui.open(Camp_Notes::PartyWindow)
    frame
    party = ui::Engine::Layer.tops.last.root.engine
    tree.rects[party.node] = [0, 0, 200, 120]
    frame
    inner = party.content_rect
    alice, luka = nodes_of(tree, "label").last(2)
    tree.rects[alice] = [inner.x, inner.y, inner.width, 24]
    tree.rects[luka] = [inner.x, inner.y + inner.height + 2, inner.width, 24]
    2.times { frame }
    drawn = party.base_surface.bitmap.texts.map { |text| text[2] }
    check("the names drawn: the one inside the content, not the one past its bottom", [drawn.include?("Alice"), drawn.include?("Luka")], [true, false])
  end
end
