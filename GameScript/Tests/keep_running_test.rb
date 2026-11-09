#----------------------------------------------------------------
#  keep_running_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that UI.in_front? tells whether the game's window is in front
#      Paulinchen  2026-11-04: Checked the outcomes of each step of keeping the game running together
#                            - Rewrote the checks as a flow test of keeping the game running
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers Mod_Framework.keep_running in a booted game against FakeBridge: the topic called once,
# the game's buttons quiet while another window is in front and back once the game is, and
# nothing but one log line without the DLL.

require_relative "boot_support"

# Boots the framework in the current game folder over a stand-in Input whose buttons the test sets
# in $held, and runs the game with a scene.
#
# @param fake [FakeBridge] The DLL's side.
# @param dll [Boolean] Whether the copy has its DLL.
# @yield The scene.
def run_game(fake, dll = true, &scene)
  new_session
  $held = []
  def Input.press?(button); $held.include?(button); end
  $dll = fake
  install_stub
  install_copy("Patch/Mod_Framework", "0.1.0", :real => true, :dll => dll)
  run_patch_loader
  $scenes = scene
  SceneManager.run
end

# Runs one frame, the input model answering whether the game's window is in front.
#
# @param front [Boolean] Whether it is.
def game_frame(front)
  $front = front
  Graphics.update
  Input.update
end

in_game_folder do
  fake = FakeBridge.new
  fake.build = "0.1.0"
  asked = []
  fake.answer("log.write") { |(_time, _line)| nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |_request| {} }
  fake.answer("ini.write") { |_request| true }
  fake.answer("window.keep_running") { |on| asked << on; on }
  fake.answer("ui.tick") do |_request|
    fake.post("ui.input", "mouse" => nil, "buttons" => 0, "double" => false, "wheel" => 0, "keys" => {}, "front" => $front)
    nil
  end
  run_game(fake) do
    2.times { Mod_Framework.keep_running = true }
    $held = [:DOWN]
    game_frame(false)
    behind = [Input.press?(:DOWN), Mod_Framework::UI.in_front?]
    game_frame(true)
    check("keep_running = true calls the topic once and the game's buttons are idle while another window is in front, as UI.in_front? tells",
          [*asked, Mod_Framework.keep_running?, *behind, Input.press?(:DOWN), Mod_Framework::UI.in_front?], [true, true, false, false, true, true])
    Mod_Framework.keep_running = false
    game_frame(false)
    check("false gives the window back to the game's rule and lets the buttons pass", [*asked, Mod_Framework.keep_running?, Input.press?(:DOWN)], [true, false, false, true])
  end
end

in_game_folder do
  fake = FakeBridge.new
  run_game(fake, false) do
    lines = logged_lines { 2.times { Mod_Framework.keep_running = true } }
    check("without the DLL it answers false and logs one line, calling nothing",
          [Mod_Framework.keep_running?, lines.size, fake.calls.map { |call| call[0] }.include?("window.keep_running")], [false, 1, false])
  end
end
