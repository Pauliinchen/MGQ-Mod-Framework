#----------------------------------------------------------------
#  keys_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Checked that UI.pad_trigger? takes the DLL's word on the gamepad
#      Paulinchen  2026-11-06: Added the slots without their add_ helper
#                            - Called the engine's classes by their names under UI::Engine
#                            - Checked the gamepad through UI.pad_trigger? and UI.pad?
#      Paulinchen  2026-11-04: Kept a few flows of the parts the keys reach and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the parts the keys and the gamepad reach
#                            - Checked the looks of a chosen slot in one check
#      Paulinchen  2026-10-30: Covered a list of values
#                            - Covered the heading rows of a list
#                            - Covered the colors of a list row's right text and note
#      Paulinchen  2026-10-29: Covered the game's buttons a focused component asks for
#                            - Covered the game's L and R a root takes as page
#                            - Covered the looks of a chosen slot and of chips, and the gap after a cut note
#                            - Created
#
#----------------------------------------------------------------

# Covers the parts of components.rbx, input.rbx and tree.rbx that the keys and the gamepad reach in
# a booted game against FakeTree: the player moves over slots and presses the game's L from a
# gamepad or the keyboard.

require_relative "tree_support"

$sounds = []

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame
    window = ui::Engine::Window.new(:title => "Keys", :size => [400, 300])

    # The player moves over slots, clicks one and confirms.
    strip = window.add(Mod_Framework::UI::Engine::Slots.new(:slots => [64, nil, { :icon => 65, :tooltip => "Haste" }], :index => 0))
    submits = []
    strip.on(:submit) { |index, _slot| submits << index }
    window.open
    frame
    tree.post("events", [[strip.node, "move", 2]])
    frame
    check("a move chooses a slot and takes its tooltip", [strip.index, strip.tooltip], [2, "Haste"])
    tree.post("events", [[strip.slot(1).node, "click"]])
    frame
    tree.post("events", [[strip.node, "click"]])
    frame
    check("a click chooses a slot and confirm submits it", submits, [1])

    # The game's L counts as the gamepad's as the DLL tells it at the frame's tick, and so does the
    # device used last.
    $pad = true
    frame([:L])
    pad = [ui.pad_trigger?(:L), ui.pad?]
    $pad = false
    frame([:L])
    check("UI.pad_trigger? and UI.pad? tell the gamepad, and the keyboard after it, as the DLL does", [pad, [ui.pad_trigger?(:L), ui.pad?]], [[true, true], [false, false]])
  end
end
