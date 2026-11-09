#----------------------------------------------------------------
#  layer_confirm_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that the key help names each choice once
#                            - Checked that the keys reach the OK button of a message
#                            - Called the engine's classes by their names under UI::Engine
#                            - Covered the question box as a dialog of the UI layer whose choices take the Accept and Decline hotkeys
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers UI.confirm and UI.message (design v2 sections 4.7 and 5.9), dialogs of the UI layer, in a
# booted game against FakeTree, through a mod's camp: leaving the camp asked with No taking the focus
# first, its choices taking the Accept and Decline hotkeys, answered by Leave in the frame after, one
# question at a time; burning the old notes asked with Yes first under the mod's own place id and
# taken back from outside; and a message that the notes were copied, its OK button holding the focus,
# closed by its handle.

require_relative "layer_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    $sounds = []
    frame

    # Leaving the camp: No takes the focus first, the choices take the Accept and Decline hotkeys, a
    # second question waits its turn, and Leave answers yes in the frame after.
    answers = []
    leave = ui.confirm("Leave the camp?", yes: "Leave", no: "Stay") { |yes| answers << [:leave, yes] }
    check("the second question while the first is open", ui.confirm("Rest first?") { |yes| answers << [:rest, yes] }, false)
    frame
    Graphics.update
    box = ui::Engine::Tree.roots.last
    yes, no = box.find(:confirm_box_yes), box.find(:confirm_box_no)
    check("the box's choices, their hotkeys and its place id", [[yes.text, no.text], [tree.nodes[yes.node][:props]["hotkey"], tree.nodes[no.node][:props]["hotkey"]], box.id],
          [["Leave", "Stay"], ["accept", "decline"], :confirm_box])
    check("the choice that takes the focus first", [tree.nodes[no.node][:props]["autofocus"], tree.nodes[yes.node][:props]["autofocus"]], [true, nil])
    check("the key help names each choice once", box.find(:confirm_box_keys).line, "Y: Leave  N, X or Numpad 0: Stay")
    check("the handle while the question waits [open?, id]", [leave.open?, leave.id], [true, :confirm_box])
    tell(tree, [[yes.node, "click"]])
    2.times { frame; Graphics.update }
    check("the answer the block got, and the handle after it", [answers, leave.open?], [[[:leave, true]], false])

    # Burning the old notes: Yes takes the focus first in the mod's own box, and the mod takes the
    # question back when the notes went away meanwhile.
    burn = ui.confirm("Burn the old notes?", lit: :yes, id: :camp_burn) { |yes| answers << [:burn, yes] }
    frame
    Graphics.update
    burned = ui::Engine::Tree.roots.last
    check("the question with Yes first [yes takes the focus first, place id]",
          [tree.nodes[burned.find(:camp_burn_yes).node][:props]["autofocus"], burned.id], [true, :camp_burn])
    burn.close("the notes went away")
    2.times { frame; Graphics.update }
    check("a question taken back answers no", [answers.last, burn.open?], [[:burn, false], false])

    # The notes copied: a message with the mod's button text, closed by its handle, which runs its block.
    closed = []
    copied = ui.message("Your notes were copied into the camp book.", ok: "Done") { closed << :copied }
    frame
    Graphics.update
    dialog = ui::Engine::Tree.roots.last
    texts = dialog.children.map { |child| child.respond_to?(:text) ? child.text : child.children.map { |each| each.text } }
    check("the message's text and button, and its place id", [texts, dialog.id], [["Your notes were copied into the camp book.", ["Done"]], :message_box])
    ok = tree.nodes[dialog.find(:message_box_ok).node][:props]
    check("the OK button the keys reach, where the focus starts [acts, repeats a key, autofocus]", [ok["acts"], ok["repeats"], ok["autofocus"]], [true, false, true])
    copied.close
    frame
    Graphics.update
    check("the message closed by its handle ran its block", [copied.open?, closed], [false, [:copied]])

    # A param the call does not take is named in the log with the one meant.
    lines = logged_lines { ui.message("Saved.", okay: "Fine") }
    check("the log line of a wrong param", lines.grep(/UI\.message takes no okay:; did you mean ok:\?/).size, 1)
  end
end
