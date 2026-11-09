#----------------------------------------------------------------
#  frame_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-04: Checked each outcome of a run with its F12 and its end on its own
#                            - Rewrote the checks as flow tests of a run with its F12 and its end
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Covers the game's run and frame as the boot sets them up: what waits for the run, the frame's
# hand-over to the bridge after every mod's frame hooks, F12, and the closing work as the game's
# scenes end, which the game's Exit-EX end never runs at_exit for.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"

in_game_folder do
  new_session
  fake = FakeBridge.new
  fake.build = "0.1.0"
  logged = []
  flushed = []
  fake.answer("log.write") { |(_time, line)| logged << line; nil }
  fake.answer("log.flush") { |_request| flushed << logged.size; nil }
  fake.answer("ini.read") { |_request| {} }
  fake.answer("ini.write") { |_request| true }
  $dll = fake
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true)
  put_mod("Some_Mod", <<-RUBY)
    Mod_Framework::Hooks.after(Graphics.singleton_class, :update, "Some Mod") { $order << :mod_frame }
    Mod_Framework::Run.on_start("some mod", :dll => true) { $order << :mod_start }
    Mod_Framework::Run.on_reset("some mod") { $order << :mod_reset }
    Mod_Framework::Run.on_close("some mod") { $order << :mod_close }
  RUBY
  run_patch_loader
  framework = Mod_Framework

  # The game runs: what waits for the run runs once before the first scene, the frame hands the
  # staged lines over after every mod's frame hook, and a block registered once the game runs runs
  # at once.
  $order = []
  $scenes = lambda do
    $order << :first_scene
    Graphics.update
    $order << [:frame_sent, fake.calls.last[0]]
    framework::Run.on_start("late") { $order << :late_start }
    raise RGSSReset
  end
  begin
    SceneManager.run
  rescue RGSSReset
    nil
  end
  check("the run starts, the frame hands over after the mods' frame hooks, and a late block runs at once",
        $order, [:mod_start, :first_scene, :mod_frame, [:frame_sent, "batch"], :late_start])

  # F12: the scenes after it run what resets, not what started.
  $order.clear
  $scenes = lambda { $order << :scenes_again }
  SceneManager.run
  check("the scenes after F12 run what resets, not what started", $order.first(2), [:mod_reset, :scenes_again])

  # The scenes returning run the closing work while the game still runs, which the game's Exit-EX
  # end never runs at_exit for, the log writing every line.
  check("the scenes returning run the closing work", $order.last, :mod_close)

  # An error out of the scenes reaches the game after the closing work, which writes the waiting
  # settings and names the error.
  framework::Settings.store("ui_preset", "Legacy")
  writes = fake.calls.count { |call| call[0] == "ini.write" }
  $scenes = lambda { raise ArgumentError, "a broken scene" }
  raised = begin
    SceneManager.run
  rescue ArgumentError => e
    e.message
  end
  check("an error out of the scenes reaches the game", raised, "a broken scene")
  check("the closing work writes the waiting settings", fake.calls.count { |call| call[0] == "ini.write" } - writes, 1)
end
