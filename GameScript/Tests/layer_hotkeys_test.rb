#----------------------------------------------------------------
#  layer_hotkeys_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers hotkey_field of the UI layer (design v2 sections 5.3 and 9.4) in a booted game against
# FakeTree, through a mod's Hotkeys tab: the player presses a field, C#'s tree waits for a key with
# the other hotkeys' keys taken, a taken key, one of the framework's and a chord are refused, said
# why and logged, a free one binds, a cancel key keeps the old one, logged, and every hotkey stays
# quiet while it waits.

require_relative "layer_support"

HOTKEYS_TAB = <<-RUBY
  module Camp_Keys
    UI = Mod_Framework::UI

    Mod_Framework::Hotkeys.define(:camp_keys_open, :key => "G", :name => "[Camp Keys] Open Camp")
    Mod_Framework::Hotkeys.define(:camp_keys_map, :key => "M", :name => "[Camp Keys] Map")

    class HotkeysTab < UI::Component
      state(:told) { [] }

      def render
        window "Hotkeys" do
          hotkey_field :camp_keys_open, on_change: ->(key) { self.told = told + [key] }
          hotkey_field :camp_keys_map, text: "World map"
        end
      end
    end
  end
RUBY

# Windows' codes of the keys the test binds.
KEY_M = 0x4D
KEY_O = 0x4F

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  dll.answer("keys.names") { |codes| codes.map { |code| code == 0x09 ? "Tab" : code.chr } }
  boot_tree(dll) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Keys.rb", HOTKEYS_TAB)
    frame

    ui.open(Camp_Keys::HotkeysTab)
    frame
    Graphics.update
    open_field, map_field = nodes_of(tree, "button").map { |node| ui::Engine::Tree.component(node) }
    tab = ui::Engine::Layer.tops.last.mount.component
    check("each field shows its hotkey's name and key", [[open_field.send(:name_text), open_field.key_text], [map_field.send(:name_text), map_field.key_text]],
          [["Open Camp", "G"], ["World map", "M"]])

    # A press waits for a key: C#'s tree learns the other hotkeys' keys and every hotkey is quiet.
    tell(tree, [[open_field.node, "click"]])
    taken = tree.nodes[open_field.node][:props]["capture"]
    check("the wait with the keys the other hotkeys have [Map's, its own]", [taken[KEY_M], taken[0x47]], ["[Camp Keys] Map", nil])
    check("the field while it waits, every hotkey quiet", [open_field.key_text, ui::Engine::KeyCapture.waiting?], ["Press a key . . .", true])

    # The Map hotkey's key, Tab and a chord are refused, the field says why and the log names the
    # hotkey, the key and its owner; O binds as it is let go.
    refusals = logged_lines { tell(tree, [[open_field.node, "refused", KEY_M, "hotkey", "[Camp Keys] Map"]]) }
    check("a key another hotkey has is refused, the field says why", open_field.key_text, "M is the hotkey of [Camp Keys] Map")
    refusals += logged_lines { tell(tree, [[open_field.node, "refused", 0x09, "framework", nil]]) }
    check("a key of the framework is refused, the field says why", open_field.key_text, "Tab is one of the framework's own keys")
    refusals += logged_lines { tell(tree, [[open_field.node, "refused", KEY_O, "chord", nil]]) }
    check("a chord is refused, the field says why", open_field.key_text, "Press one key alone")
    check("each refusal is logged once with the hotkey, the key and its owner", refusals.grep(/key capture: :camp_keys_open refused/),
          ["key capture: :camp_keys_open refused M (key code 77): the hotkey [Camp Keys] Map",
           "key capture: :camp_keys_open refused Tab (key code 9): one of the framework's keys",
           "key capture: :camp_keys_open refused O (key code 79): pressed with another key"])
    tell(tree, [[open_field.node, "captured", KEY_O]])
    check("O binds Open Camp and on_change hears its name", [Mod_Framework::Hotkeys.code(:camp_keys_open), tab.told, open_field.key_text], [KEY_O, ["O"], "O"])
    tell(tree, [[open_field.node, "released"]])
    Graphics.update
    check("the wait ends once the key is let go", [ui::Engine::KeyCapture.waiting?, tree.nodes[open_field.node][:props]["capture"]], [false, nil])

    # X, bound to the game's cancel, keeps the World map's key, logged.
    tell(tree, [[map_field.node, "click"]])
    kept = logged_lines { tell(tree, [[map_field.node, "kept", 0x58, "key"], [map_field.node, "released"]]) }
    check("X keeps the World map's key", [Mod_Framework::Hotkeys.code(:camp_keys_map), map_field.key_text, ui::Engine::KeyCapture.waiting?], [KEY_M, "M", false])
    check("the keep is logged with the hotkey and the key", kept.grep(/key capture/), ["key capture: :camp_keys_map kept its key by X (key code 88), a cancel key"])
  end
end
