#----------------------------------------------------------------
#  layer_number_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Asked UI.number without digits:
#      Paulinchen  2026-11-06: Asked UI.number through a numeric field, as the digit field is gone
#                            - Checked that a digit starts typing the coins, kept within the purse by Enter and put back by cancel
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers UI.number of the UI layer (design v2 section 5.3) in a booted game against FakeTree: the
# number box asking how many herbs to buy, its numeric field kept to two digits and answered with
# the number kept within its max:, then asked again and taken back by its handle.

require_relative "layer_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame

    # The number box asks for herbs: at most 20, answered with 20 and the number shown.
    answers = []
    handle = ui.number(5, max: 20, title: "Herbs", note: "The cook sells 20.", ok: "Buy") { |herbs, shown| answers << [herbs, shown] }
    frame
    Graphics.update
    box = ui::Engine::Tree.roots.last
    field = tree.nodes.keys.select { |node| tree.nodes[node][:kind] == "numeric_field" }.max
    buttons = box.children[2].children
    check("the number box [title, note, buttons, open?, id]", [box.title, box.children[1].text, buttons.map { |button| button.text }, handle.open?, handle.id],
          ["Herbs", "The cook sells 20.", ["Buy", "Back"], true, :mf_number])
    tell(tree, [[field, "number", 35]])
    tell(tree, [[buttons[0].node, "click"]])
    check("the answer within max: and the number shown, and the box closed", [answers, handle.open?], [[[20, 35]], false])

    # Asked again and taken back by the mod: the block hears nil.
    again = ui.number(3) { |herbs, shown| answers << [herbs, shown] }
    frame
    again.close
    frame
    check("the box taken back by its handle", [answers.last, again.open?], [[nil, 3], false])

    lines = logged_lines { ui.number(1, adornmnet: "G") }
    check("the log line of a wrong param", lines.grep(/UI\.number takes no adornmnet:; did you mean adornment:\?/).size, 1)
  end
end
