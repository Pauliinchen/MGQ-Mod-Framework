#----------------------------------------------------------------
#  layer_keys_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Walked the key help as the focus moves between the bag, the days and Sort
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Expected the keys a key help adds before its entry of cancel
#      Paulinchen  2026-11-04: Kept a few flows of the windows of a camp bag and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the windows of a mod's camp bag
#                            - Checked each rule in one check
#                            - Covered the jump keys named for the device the player used last
#                            - Covered the hotkey a component class declares, which opens it
#                            - Covered a pick of a list sent up to the window's on_submit
#                            - Covered the key help that names the jump keys around a list
#                            - Covered on_button: and the key help that names its buttons
#                            - Covered UI.typing?
#                            - Covered a close hint that follows the keys F1 binds
#                            - Covered the hotkeys parts declare, the key help that lists them and a window's hotkey that
#                              closes it
#                            - Created
#
#----------------------------------------------------------------

# Covers what the new UI layer tells C# for its key rules (design v2 sections 9.1, 9.4 and 9.5) in a
# booted game against FakeTree, through the windows of a mod's camp bag: the page step, the game's
# buttons and the hotkeys parts declare, the key help and a close hint that follow the keys bound,
# a pick sent up to the window, and hotkeys nobody defined. C# checks the rules themselves in
# TreeKeysTests.

require_relative "layer_support"

BAG = <<-RUBY
  module Camp_Bag
    UI = Mod_Framework::UI

    Mod_Framework::Hotkeys.define(:camp_bag_open, :key => "G", :name => "[Camp Bag] Open")
    Mod_Framework::Hotkeys.define(:camp_bag_sort, :key => "F5", :name => "[Camp Bag] Sort")
    Mod_Framework::Hotkeys.define(:camp_bag_notes, :key => "H", :name => "[Camp Bag] Notes")

    class BagWindow < UI::Component
      state(:steps) { [] }

      def render
        window "Bag", id: :camp_bag, hotkey: :camp_bag_open, shoulders: :tabs do
          paper id: :bag, on_page: ->(step) { self.steps = steps + [step] }, on_button: { z: -> { self.steps = steps + [:filter] }, y: nil },
                button_help: { z: "Filter" } do
            button "Potion", id: :potion, on_click: -> {}
          end
          list ["Day 1", "Day 2"], id: :days
          button "Sort", id: :sort, hotkey: :camp_bag_sort, show_key: true, on_click: -> {}
          text UI.close_hint
          key_help entries: [{ button: :B, text: "close" }]
        end
      end
    end

    class DaysWindow < UI::Component
      state :picked

      def render
        window "Days", on_submit: ->(item) { self.picked = item } do
          list ["Day 1", "Day 2"]
        end
      end
    end

    class TypoWindow < UI::Component
      def render
        window "Typo" do
          button "Sort", hotkey: :camp_bag_srot, on_click: -> {}
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    props = lambda { |node| tree.nodes[node][:props] }
    load_mod("Patch/Camp_Bag.rb", BAG)
    frame

    # The bag tells C# its key rules, takes the page step and buttons C# tells, and names its keys
    # as they are bound.
    whys = []
    handle = ui.open(Camp_Bag::BagWindow) { |_result, why| whys << why }
    frame
    Graphics.update
    window = nodes_of(tree, "window").last
    paper = nodes_of(tree, "box").last
    check("the window tells C# it holds the game's buttons, its shoulders and its hotkey",
          props.call(window).values_at("layer", "captures", "shoulders", "hotkey"), [true, true, "tabs", "camp_bag_open"])
    tell(tree, [[paper, "page", -1, false]])
    tell(tree, [[paper, "button", "Z"]])
    component = ui::Engine::Layer.tops.last.mount.component
    check("the page step and the button C# tells reach on_page and on_button", component.steps, [-1, :filter])
    engine = ui::Engine::Layer.tops.last.root.engine
    help = engine.children.last

    # The key help names only the keys of the part in focus and of the parts it lies in, as the
    # focus moves: the bag's Filter on the Potion inside it, the jump keys on the days, Sort's
    # hotkey on Sort, and the window's way out everywhere.
    focus = lambda do |id|
      tree.post("states", engine.find(id).node => ui::Engine::Tree::FOCUSED)
      frame
      Graphics.update
      help.line
    end
    keys_by_focus = [:potion, :days, :sort].map { |id| focus.call(id) }
    check("the key help names the keys of the part in focus and its pane as the focus moves", keys_by_focus,
          ["D: Filter  X, Numpad 0 or G: close", "Ctrl+arrows: Leave the list  X, Numpad 0 or G: close", "F5: Sort  X, Numpad 0 or G: close"])
    Mod_Framework::Hotkeys.bind(:camp_bag_sort, 0x4A)
    frame
    Graphics.update
    check("the key help names the key the player bound", help.line, "J: Sort  X, Numpad 0 or G: close")
    ui::Engine::Pad.assign("B" => [0x1B, 0x60, 0x2D, 0x41], "C" => [0x20, 0x0D, 0x5A, 0x58])
    frame
    Graphics.update
    hint = engine.children.find { |child| child.is_a?(ui::Engine::Label) && child.text.to_s.end_with?(": close") }
    check("the close hint follows the key F1 binds", hint.text, "A or Numpad 0: close")
    ui::Engine::Pad.assign("B" => [0x1B, 0x60, 0x2D, 0x58])
    ui::Engine::Tree.take("quiet" => [["camp_bag_sort", "its part is hidden"]])
    frame
    tell(tree, [[window, "close", "hotkey"]])
    check("the window's own hotkey closes it with :hotkey", [handle.open?, whys], [false, [:hotkey]])

    # A list's pick goes up to the window's on_submit.
    days = ui.open(Camp_Bag::DaysWindow)
    frame
    tell(tree, [[nodes_of(tree, "window").last, "submit", 1, nodes_of(tree, "list").last]])
    check("the list's pick reaches the window's on_submit", ui::Engine::Layer.tops.last.mount.component.picked, "Day 2")
    days.close

    # Hotkeys nobody defined are refused with the nearest name.
    ui.open(Camp_Bag::TypoWindow)
    frame
    check("the log names the nearest hotkey", layer_lines.last.to_s.include?(":camp_bag_srot is no hotkey; define it with Mod_Framework::Hotkeys.define; did you mean :camp_bag_sort?"), true)
    typo_class = begin
      eval("class Camp_Bag::LateWindow < Mod_Framework::UI::Component; hotkey :camp_bag_note; end", TOPLEVEL_BINDING, "Patch/Camp_Bag.rb", 90)
    rescue ui::Engine::MarkupError => e
      e.message
    end
    check("a class's undefined hotkey is refused", typo_class,
          "hotkey :camp_bag_note is no hotkey; define it with Mod_Framework::Hotkeys.define before the class; did you mean :camp_bag_notes? (Camp_Bag.rb:90)")
  end
end
