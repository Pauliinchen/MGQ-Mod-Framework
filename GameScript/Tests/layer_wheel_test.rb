#----------------------------------------------------------------
#  layer_wheel_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a wheel closed through the handle of UI.open
#      Paulinchen  2026-11-07: Greyed rows and choices with disabled:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers the wheel of the UI layer (design v2 sections 5.1 and 5.8) in a booted game against FakeTree
# and a stand-in for C#'s wheels, through a mod's camp wheel opened by its hotkey: refused off a
# free map, its choices asked from a block, a choice that cannot be taken refused, the middle taken
# and handed to UI.open's block, the hotkey closing it again, and UI.open's handle closing it.

require_relative "layer_support"

CAMP_WHEEL = <<-RUBY
  module Camp_Wheel
    UI = Mod_Framework::UI

    Mod_Framework::Hotkeys.define(:camp_wheel, :key => "G", :name => "[Camp Wheel] Camp Wheel")

    class CampWheel < UI::Component
      hotkey :camp_wheel

      def render
        wheel choices: -> { $camp_choices }, center: { text: "Camp" }, look: :boxes, none_text: "None",
              on_submit: ->(choice) { $camp_told << [:submit, choice] }, on_refuse: ->(choice) { $camp_told << [:refuse, choice[:text]] },
              on_close: ->(why) { $camp_told << [:close, why] }, on_gone: -> { $camp_told << :gone }
      end
    end
  end
RUBY

# A stand-in for the game's map scene.
class Scene_Map
end

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ui.wheel.define") { |_request| true }
  fake.answer("ui.wheel.close") { |_request| nil }
  fake.answer("ui.wheel.places") { |request| [[0], [0, 4], [0, 3, 5]][request[0] - 1] }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Wheel.rb", CAMP_WHEEL)
    $camp_told = []
    $camp_choices = ["Rest", { :text => "Fish", :disabled => true }]
    $sounds = []
    frame
    press = lambda do
      $keys = { 0x47 => 3 }
      frame
      $keys = nil
      frame
    end
    engine = lambda { (top = ui::Engine::Layer.tops.last) && top.root.engine }

    # In a menu the hotkey opens nothing: the wheel waits for a free map.
    $scene_now = :menu
    lines = logged_lines { press.call }
    check("the hotkey in a menu [tops open, the reason logged]", [ui::Engine::Layer.tops.size, lines.grep(/did not open: the map is not the scene/).size], [0, 1])

    # On the map the hotkey opens it, its choices asked from the mod's block.
    $scene_now = Scene_Map.new
    press.call
    wheel = engine.call
    $dll.post("ui.wheel", "wheel" => wheel.model, "open" => true, "selected" => -1, "cues" => [])
    frame
    check("the wheel the hotkey opened [open?, told, its hint's hotkey]", [wheel.open?, $camp_told, wheel.hotkey], [true, [], :camp_wheel])
    $camp_choices = $camp_choices + ["Cook"]
    frame
    check("the choices the frame handed C# [count]", $ticks.last[wheel.model][5], 3)

    # Fishing cannot be taken: it buzzes, the wheel stays open and the mod hears the refusal.
    $dll.post("ui.wheel", "wheel" => wheel.model, "open" => true, "selected" => 3, "take" => 3, "cues" => [])
    frame
    check("a choice that cannot be taken [sound, open?, told]", [$sounds.last, wheel.open?, $camp_told], [:buzzer, true, [[:refuse, "Fish"]]])

    # The hotkey closes it again.
    press.call
    check("the hotkey closes the open wheel [open?, told]", [wheel.open?, $camp_told.last], [false, [:close, :hotkey]])

    # Opened by UI.open, the middle taken: the mod and the block get the middle's choice.
    answers = []
    handle = ui.open(Camp_Wheel::CampWheel) { |choice, why| answers << [choice, why] }
    frame
    wheel = engine.call
    $dll.post("ui.wheel", "wheel" => wheel.model, "open" => true, "selected" => -1, "take" => -1, "cues" => [])
    frame
    check("the middle taken [told, the block's answer, open?]", [$camp_told.last(2), answers, handle.open?],
          [[[:submit, { :text => "Camp" }], [:close, :submit]], [[{ :text => "Camp" }, :submit]], false])
    20.times { Graphics.update }
    check("gone told once it faded out", $camp_told.last, :gone)

    # Opened by UI.open and closed through its handle: the block gets no choice and :script.
    answers = []
    handle = ui.open(Camp_Wheel::CampWheel) { |choice, why| answers << [choice, why] }
    frame
    wheel = engine.call
    $dll.post("ui.wheel", "wheel" => wheel.model, "open" => true, "selected" => -1, "cues" => [])
    frame
    handle.close
    check("the handle closes the open wheel [open?, told, the block's answer]", [handle.open?, $camp_told.last, answers],
          [false, [:close, :script], [[nil, :script]]])
  end
end
