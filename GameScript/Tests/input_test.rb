#----------------------------------------------------------------
#  input_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Read the cancel keys that leave a text field from C#
#                            - Typed through the framework's text box in place of a flag of another mod
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Kept a few flows of the frames a game runs and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the frames a game runs
#                            - Expected the game's extra buttons and the jump hotkey's key in the tick
#                            - Held a button the stand-in Input reports gone down, and checked the buttons read once a
#                              frame, going down once and repeating as the game's Input does
#                            - Checked the buttons read through Input without the DLL
#      Paulinchen  2026-11-01: Expected the keys of the framework's move hotkeys in the first tick
#                            - Checked cancel? and the cancel keys in a field of digits, told or read from the focused field
#      Paulinchen  2026-10-31: Checked cancel? outside and inside a text field, with the keys F1 binds
#                            - Expected Escape and the numpad's 0 watched from the first tick
#      Paulinchen  2026-10-29: Expected the keys of the accept and decline hotkeys in the first tick
#      Paulinchen  2026-10-28: Expected the game's L and R buttons among the tick's bits
#                            - Expected the left Alt the layout watches in the first tick
#                            - Created
#
#----------------------------------------------------------------

# Covers input.rbx in a booted game against FakeBridge, through the frames a game runs: the tick and
# what the scene reads of it, a held button that repeats, a mod's marks and gates, cancel? in and
# outside text fields, F12, and the game's own Input without the DLL.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"

# Windows' code of the numpad's 0.
NUMPAD_0 = 0x60

# Boots the framework in the current game folder over a stand-in Input whose buttons the test sets
# in $triggered and $held, with a gamepad plugin that wraps Input after the mods load, as the
# translation's does: it keeps the game's own press? as vxa_press?, counts its reads of press? in
# $plugin_reads and answers the buttons in $pad while $pad_plugged. Runs the game's scenes until the
# test's frames end.
#
# @param fake [FakeBridge] The DLL's side.
# @param options [Hash] :dll (false for a copy without its DLL).
def boot_game(fake, options = {})
  new_session
  $triggered = []
  $held = []
  $pad = []
  def Input.trigger?(button); $triggered.include?(button); end
  def Input.press?(button); $held.include?(button) || $triggered.include?(button); end
  def Input.repeat?(button); $triggered.include?(button); end
  def Input.dir4; $held.include?(:DOWN) ? 2 : 0; end
  $dll = fake
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => options[:dll])
  run_patch_loader
  $plugin_reads = 0
  $pad_plugged = false
  Object.class_eval("module WolfPad; def self.plugged_in?; $pad_plugged; end; end") unless defined?(WolfPad)
  class << Input
    alias_method :pad_trigger?, :trigger?
    alias_method :vxa_press?, :press?
    def trigger?(button); pad_trigger?(button) || $pad.include?(button); end
    def press?(button); $plugin_reads += 1; $pad_plugged ? $pad.include?(button) : vxa_press?(button); end
  end
end

# Runs one frame of a scene as Scene_Base#update_basic does: the frame before ends, Input reads the
# frame's buttons, then the scene reads them in the block.
#
# @param event [Hash, nil] What the input model answers at the frame's tick; nil keeps the last.
# @yield The scene's update.
def game_frame(event = nil)
  $input_event = event if event
  Graphics.update
  Input.update
  yield if block_given?
end

# What the input model answers with nothing pressed.
QUIET = { "mouse" => nil, "buttons" => 0, "double" => false, "wheel" => 0, "keys" => {}, "front" => true }

# The pointer at [10, 20], the left button gone down, a notch of the wheel, and the numpad's 0
# gone down.
CLICK = QUIET.merge("mouse" => [10, 20], "buttons" => 1 | 4, "wheel" => 1, "keys" => { NUMPAD_0 => 3 })

in_game_folder do
  fake = FakeBridge.new
  fake.build = "0.1.0"
  logged = []
  ticks = []
  fake.answer("log.write") { |(_time, line)| logged << line; nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |_request| {} }
  fake.answer("ini.write") { |_request| true }
  # C#'s field rule as it answers here: the numpad's 0 types into a field of digits, X into one of letters.
  fake.answer("keys.leave_field") { |(takes, codes)| codes - [takes == "0" ? NUMPAD_0 : 0x58] }
  fake.answer("ui.tick") do |request|
    ticks << request
    fake.post("ui.input", $input_event)
    nil
  end
  boot_game(fake)
  ui = Mod_Framework::UI
  ui::Engine::Key.watch(NUMPAD_0)

  $scenes = lambda do
    # A frame: the tick goes after Input.update with the frame's buttons, the scene reads what it
    # drained, and behind another window no button goes out.
    $triggered = [:C]
    game_frame(CLICK) do
      check("the scene reads the pointer, the click, the wheel and the key of the frame",
            [ui::Engine::Mouse.position, ui::Engine::Mouse.clicked?, ui::Engine::Mouse.wheel, ui::Engine::Key.triggered?(NUMPAD_0)], [[10, 20], true, 1, true])
    end
    game_frame(CLICK.merge("front" => false))
    game_frame
    check("behind another window no button goes out", ticks.last["buttons"], 0)
    $triggered = []
    game_frame(QUIET)

    # A held button goes down once and repeats as the game's Input does.
    $held = [:DOWN]
    seen = []
    31.times { |index| game_frame { seen << index if ui::Engine::Capture.repeat?(:DOWN) } }
    check("a held button repeats as the game's Input does", seen, [0, ui::Engine::Capture::REPEAT_FIRST, ui::Engine::Capture::REPEAT_FIRST + ui::Engine::Capture::REPEAT_EVERY])

    # The gamepad plugin reads no button for the framework while no gamepad is plugged in, and the
    # gamepad's buttons while one is.
    $plugin_reads = 0
    game_frame { $seen = [$plugin_reads, ui::Engine::Capture.press?(:DOWN)] }
    $pad_plugged = true
    $pad = [:UP]
    game_frame { $seen += [$plugin_reads > 0, ui::Engine::Capture.press?(:UP), ui::Engine::Capture.press?(:DOWN)] }
    check("the gamepad plugin reads the buttons only while a gamepad is plugged in", $seen, [0, true, true, true, false])
    $pad_plugged = false
    $pad = []
    $held = []

    # Mods mark buttons pressed and gate them.
    game_frame do
      ui::Engine::Buttons.press(:LEFT)
      ui::Engine::Buttons.press(:C)
      check("a mark reads pressed and as a direction for the rest of its frame", [Input.trigger?(:C), Input.dir4], [true, 4])
    end
    $held = [:DOWN]
    $gate = false
    ui::Engine::Buttons.gate("Some Mod") { $gate }
    game_frame { check("a closed gate keeps the buttons from the game", [Input.press?(:DOWN), Input.dir4], [false, 0]) }
    $gate = true
    ui::Engine::Buttons.gate("Broken Mod") { raise ArgumentError, "a broken gate" }
    game_frame
    game_frame
    check("a failing gate is logged once", logged.grep(/the button gate of Broken Mod failed, so it lets the buttons pass: ArgumentError: a broken gate/).size, 1)
    $held = []

    # Cancel outside a text field and while one types, with the keys F1 binds and in a field of
    # digits.
    ui::Engine::Capture.start(:probe)
    $triggered = [:B]
    game_frame(QUIET) { check("cancel? answers the game's cancel past a capture", ui.cancel?, true) }
    ui::Engine::TextEdit.open = :field
    game_frame(QUIET.merge("keys" => { 0x58 => 3 })) { check("while a text field types a typed X is no cancel", ui.cancel?, false) }
    game_frame(QUIET.merge("keys" => { 0x1B => 3 })) { check("while a text field types Escape cancels", ui.cancel?, true) }
    game_frame(QUIET.merge("keys" => { NUMPAD_0 => 3 })) { check("in a field of digits the numpad's 0 types", ui.cancel?(:digits), false) }
    $triggered = []
    ui::Engine::TextEdit.release(:field)
    game_frame(QUIET.merge("assign" => { "B" => [0x1B, NUMPAD_0, 0x2D, 0x41], "C" => [0x20, 0x0D, 0x5A, 0x58] }))
    $triggered = [:B]
    game_frame(QUIET.merge("keys" => { 0x41 => 3 })) { check("a letter F1 binds to cancel cancels outside a text field", ui.cancel?, true) }
    $triggered = []
    game_frame(QUIET.merge("assign" => { "B" => [0x1B, NUMPAD_0, 0x2D, 0x58], "C" => [0x20, 0x0D, 0x5A] }))
    ui::Engine::Capture.stop(:probe)
    game_frame(CLICK)

    # F12 gives the buttons back and drops the marks.
    ui::Engine::Capture.start(:probe)
    ui::Engine::Buttons.press(:C)
    raise RGSSReset
  end
  begin
    SceneManager.run
  rescue RGSSReset
    nil
  end
  $scenes = lambda do
    check("F12 gives every root's buttons back and drops the marks", [ui::Engine::Capture.on?, ui::Engine::Buttons.marked?(:C)], [false, false])
  end
  SceneManager.run
end

# Without the DLL Input stays the game's own and the facades stay quiet, while the buttons are read
# through Input (07d009b9).
in_game_folder do
  fake = FakeBridge.new
  boot_game(fake, :dll => false)
  ui = Mod_Framework::UI
  $scenes = lambda do
    $triggered = [:C]
    ui::Engine::Capture.start(:probe)
    game_frame do
      Input.trigger?(:C)
      check("without the DLL the buttons are read through Input", ui::Engine::Capture.trigger?(:C), true)
    end
    check("without the DLL no tick is sent", fake.calls.map { |call| call[0] }.include?("ui.tick"), false)
  end
  SceneManager.run
end
