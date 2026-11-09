#----------------------------------------------------------------
#  layout_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Checked that UI.arranging? tells a mod whether the boxes are arranged
#      Paulinchen  2026-11-04: Kept a few flows of a box the player arranges and checked each outcome on its own
#                            - Rewrote the checks as flow tests of a box the player arranges
#                            - Checked that a place C# turned from pixels into its zone and offset is kept once, and that
#                              Default puts back the places of boxes not open too
#      Paulinchen  2026-10-28: Moved into the Mod Framework from the layout part of ui_layout_test.rb
#                            - Checked the most size and how a box resizes handed to C#
#                            - Checked the places kept in the framework's ini
#                            - Checked forget and reset_all, and nothing without the DLL
#                            - Checked that a reserved or unregistered box stays out of drags
#      Paulinchen  2026-10-23: Checked what the script does with the layout in C#, its rules gone there
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers layout.rbx in a booted game against FakeBridge, which plays C#'s LayoutModel (whose rules
# ModFramework.Tests covers): a box registered, placed where C# answers, handed over at the tick,
# dragged while Alt is held and kept in the ini, the Interface Positions row, F12, and nothing
# without the DLL.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"
INI = "Patch/Mod_Framework/Mod_Framework.ini"

# Windows' code of the left Alt.
ALT = 0xA4

# Mod Config Remake, which reads the value of a row a mod keeps.
module ModConfigRemake; def self.mod_stored?(entry); entry[:mod_stored] ? true : false; end; end

# Boots the framework in the current game folder, with Mod Config Remake.
#
# @param fake [FakeBridge] The DLL's side.
# @param options [Hash] :dll (false for a copy without its DLL).
def boot_layout(fake, options = {})
  new_session
  Object.send(:remove_const, :NWConst) if defined?(NWConst)
  Object.class_eval <<-RUBY
    module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
  RUBY
  $dll = fake
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => options[:dll])
  run_patch_loader
end

# Runs one frame as the game does: the frame before ends, Input reads the frame's buttons and the
# tick goes over, then the scene runs.
#
# @param alt [Boolean] Whether the left Alt is held at this frame's tick.
# @param posts [Array<Array>] The events C# posts at this frame's tick, each [topic, payload].
def frame(alt = false, posts = [])
  $alt = alt
  $posts = posts
  Graphics.update
  Input.update
end

# Without the DLL every box lies at its default and nothing crosses.
in_game_folder do
  fake = FakeBridge.new
  boot_layout(fake, :dll => false)
  layout = Mod_Framework::UI::Engine::Layout
  $scenes = lambda do
    layout.register(:test_box, "Test box")
    layout.offer(:test_box, 1, 2, 3, 4)
    default = Rect.new(20, 30, 300, 120)
    layout.rect(:test_box, default).equal?(default)
    check("without the DLL nothing crosses", fake.calls.map { |call| call[0] }.grep(/\Aui\./), [])
  end
  SceneManager.run
end

in_game_folder do
  fake = FakeBridge.new
  fake.build = "0.1.0"
  $files = {}
  $logged = []
  asked = []
  ticks = []
  fake.answer("log.write") { |(_time, line)| $logged << line; nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |(path)| $files[path] || {} }
  fake.answer("ini.write") { |(path, values)| $files[path] = values.dup; true }
  fake.answer("ui.layout.register") { |request| asked << [:register, request]; [request[8] == "1,2,3,4", request[8] == "1,2,3,4" ? "top_left,1,2,3,4" : nil] }
  fake.answer("ui.layout.rect") { |request| asked << [:rect, request]; [request[1] + 1, request[2], request[3], request[4], false] }
  fake.answer("ui.layout.reset") { |request| asked << [:reset, request]; [0, 0, 0, 0] }
  fake.answer("ui.tick") do |request|
    ticks << request
    fake.post("ui.input", "mouse" => [150, 100], "buttons" => 1 | 4, "double" => false, "wheel" => 0, "keys" => $alt ? { ALT => 1 } : {}, "front" => true)
    $posts.each { |topic, payload| fake.post(topic, payload) }
    nil
  end
  $files[INI] = { "ui_test_box" => "1,2,3,4" }
  boot_layout(fake)
  ui = Mod_Framework::UI
  layout = ui::Engine::Layout

  $scenes = lambda do
    # A box registers in C# with its sizes, how it resizes, its place in the ini and the screen; an
    # older place C# turned into its zone and offset is kept in the ini once.
    layout.register(:test_box, "Test box", :min_size => [200, 100], :max_size => [480, nil], :resizable => :height)
    check("a box registers in C# with its sizes, how it resizes, its place and the screen",
          asked.last, [:register, ["test_box", "Test box", 200, 100, 480, 0, "height", true, "1,2,3,4", 640, 480, true]])
    Graphics.update
    check("an older place C# turned into its zone and offset is kept in the ini", $files[INI]["ui_test_box"], "top_left,1,2,3,4")

    # An id that names a setting of the framework is refused, never handed to C# nor stored.
    check("an id that names a setting is refused", layout.register(:preset, "Preset box"), false)
    frame
    ticks.clear
    layout.offer(:preset, 0, 0, 10, 10)
    frame(false, [["ui.layout", { "store" => { "preset" => "1,2,3,4" } }]])
    Graphics.update
    check("a refused box is never stored", $files[INI].key?("ui_preset"), false)

    # The box lies where C# answers, asked once per default and screen; forget asks again.
    default = Rect.new(20, 30, 300, 120)
    asked.clear
    layout.rect(:test_box, default).to_a
    layout.rect(:test_box, default)
    layout.forget(:test_box)
    layout.rect(:test_box, default)
    check("forget asks again", asked.size, 2)

    # While Alt is held the boxes are arranged, the mouse's click stays with them, and the overlay
    # above everything washes the box the mouse is on.
    layout.offer(:test_box, 20, 30, 300, 120, 10)
    frame(true, [["ui.layout", { "dragging" => true, "hot" => "test_box", "rects" => { "test_box" => [20, 30, 300, 200] } }]])
    check("while Alt is held the boxes are arranged, which UI.arranging? tells a mod", [layout.arranging?, Mod_Framework::UI.arranging?], [true, true])
    layout.offer(:test_box, 20, 30, 300, 200, 10)
    frame(true)
    overlay = layout.overlay

    # Letting go keeps the place C# stopped at the most size in the ini and hides the overlay; a box
    # C# put back on a double click is forgotten.
    frame(false, [["ui.layout", { "dragging" => false, "hot" => nil, "store" => { "test_box" => "20,30,300,240" }, "log" => ["resized Test box to 20,30 at 300x240"] }]])
    Graphics.update
    check("letting go keeps the place in the ini", $files[INI]["ui_test_box"], "20,30,300,240")
    frame(false, [["ui.layout", { "store" => { "test_box" => nil }, "log" => ["put Test box back (a double click with Alt)"] }]])
    Graphics.update
    check("a box put back on a double click is forgotten in the ini", [$files[INI].key?("ui_test_box"), layout.moved?(:test_box)], [false, false])

    # The positions row says Moved while any box was moved, and Default puts every moved box back in
    # the ini and in C#, forgetting the places of boxes not open.
    positions = NWConst::Config::MOD_CONTENTS.find { |row| row[:key] == layout::OPTION }
    layout.register(:other_box, "Other box")
    Mod_Framework::Settings.store("ui_Closed_Mod/log", "left,8,0,200,100")
    frame(false, [["ui.layout", { "store" => { "test_box" => "5,5,300,120", "other_box" => "9,9,100,50" } }]])
    asked.clear
    positions[:on_change].call("Default")
    Graphics.update
    check("Default puts every moved box back in C#", asked.map { |entry| entry[1] }, [["test_box"], ["other_box"]])
    check("Default forgets every place in the ini, of boxes not open too", $files[INI].keys.grep(/\Aui_/), [])

    # F12 drops a drag and the offers.
    layout.offer(:test_box, 0, 0, 10, 10)
    frame(false, [["ui.layout", { "dragging" => true }]])
    raise RGSSReset
  end
  begin
    SceneManager.run
  rescue RGSSReset
    nil
  end
  $scenes = lambda do
    ticks.clear
    frame
    check("F12 drops the drag and the boxes offered", [layout.arranging?, Mod_Framework::UI.arranging?, ticks.last["layout"]], [false, false, nil])
  end
  SceneManager.run
end
