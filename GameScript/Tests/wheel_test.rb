#----------------------------------------------------------------
#  wheel_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that a closed wheel frees its picture
#                            - Called the engine's classes by their names under UI::Engine
#                            - Dropped the wheel a mod defined by its name before the game ran, which the wheel no longer takes
#      Paulinchen  2026-11-04: Kept a few flows of a wheel and checked each outcome on its own
#                            - Rewrote the checks as flow tests of opening a wheel, taking a choice and closing it
#      Paulinchen  2026-11-01: Expected the close a wheel hears on F12
#      Paulinchen  2026-10-31: Checked the numpad's 0 with Num Lock off closing a wheel a mod puts
#                            - Took the choice on a wheel that stays open for it
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# Covers wheel.rbx in a booted game against a stand-in for C#'s wheels: a Wheel opened, drawn over
# a cover and closed by the choice taken.

require_relative "tree_support"

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  defined = []
  fake.answer("ui.wheel.define") { |request| defined << request; true }
  fake.answer("ui.wheel.close") { |_request| nil }
  fake.answer("ui.wheel.places") { |request| [[0], [0, 4], [0, 3, 5], [0, 2, 4, 6]][request[0] - 1] }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    $sounds = []
    frame

    # The player opens an actions wheel, which shows around the screen's middle over a modal cover.
    taken = []
    actions = ui::Engine::Wheel.new(:choices => ["Wave", { :text => "Bow", :icon => 12 }, "Sit", "Run"], :center => "Talk", :fade => false)
    actions.on(:submit) { |choice| taken << choice }
    actions.open
    model = defined.last[0]
    frame
    check("it opens with its key, count and place in the next tick", $ticks.last[model], [true, true, false, false, 0, 4, [320, 240, 26, 86]])
    $dll.post("ui.wheel", "wheel" => model, "open" => true, "selected" => -1, "places" => [0, 2, 4, 6], "cues" => ["cursor"])
    frame
    frame([:UP, :LEFT])
    Graphics.update
    sprite = actions.instance_variable_get(:@sprite)
    cover = actions.cover.node
    check("a modal cover that cancel does not close lies under it", tree.nodes[cover][:props].values_at("modal", "closable", "z"), [true, false, ui::Z[:open_wheel]])

    # A choice taken closes the wheel with its cover and reaches the submit blocks, then the close
    # blocks.
    $dll.post("ui.wheel", "wheel" => model, "open" => true, "selected" => 2, "take" => 2, "cues" => [])
    frame
    Graphics.update
    check("the choice reaches the submit blocks as given", taken, [{ :text => "Bow", :icon => 12 }])
    check("the wheel and its cover close, its picture freed", [actions.open?, sprite.disposed?, tree.nodes.key?(cover)], [false, true, false])
  end
end
