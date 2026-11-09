#----------------------------------------------------------------
#  hooks_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-04: Kept a few flows of the hooks with a check per outcome that matters
#                            - Rewrote the checks as flow tests of before, after, around and the report
#      Paulinchen  2026-10-30: Checked outermost blocks and a registration logged at once after the run
#      Paulinchen  2026-10-28: Moved into the Mod Framework from MGQ Online
#                            - Checked that a failing block is logged in the log of the mod that registered it
#                            - Checked that report finds a wrap a later definition replaced
#                            - Left holding the player to MGQ Online
#      Paulinchen  2026-10-12: Checked around with other arguments
#      Paulinchen  2026-10-08: Checked the hook report and a wrap of a method defined later
#                            - Checked that the hooks are logged as one line per script, once
#      Paulinchen  2026-10-07: Checked that who holds the player is logged when it changes
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked around and holding the player
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers hooks.rbx: before and after blocks of two mods on a game method and a module's method, a
# failing block, around wraps with their arguments and errors, the report, a method defined later
# and one a plugin defines again, and outermost blocks around a mod that registers late.

require_relative "support"

$calls = []
$log = []

load_scripts "logging", "hooks"
Mod_Framework::Log.define_singleton_method(:write) { |line| $log << line }
hooks = Mod_Framework::Hooks

# A mod's own log, as a mod's module has one.
module Some_Mod
  # The lines it wrote.
  LINES = []

  # Writes a line into the mod's log.
  #
  # @param message [String] The line.
  def self.log(message); LINES << message; end
end

# A stand-in for a game class.
class Scene_Test
  def initialize; @name = "scene"; end
  def update(value); $calls << [:update, value]; value * 2; end
  def double(value); value * 2; end
  def add(a, b); a + b; end
  def fails; raise ArgumentError, "the game's own error"; end
end

# A stand-in for a module's method, such as Graphics.update.
module Frames; def self.update; $calls << :frame; end; end

# A game window whose methods a plugin defines again.
class Window_Plugin
  def refresh; :game; end
  def update; :game; end
end

# Two mods follow a game method; the second registration of a tag takes the first one's place.
hooks.before(Scene_Test, :update, "first") { |value| $calls << [:first_before, @name, value] }
hooks.after(Scene_Test, :update, "first") { |value| $calls << [:first_after, value] }
hooks.before(Scene_Test, :update, "second") { |_value| $calls << :second_before }
hooks.after(Scene_Test, :update, "second") { |_value| $calls << :second_after }
Scene_Test.new.update(3)
check("before blocks run last registered first and after blocks first registered first, on the object with the arguments",
      $calls, [:second_before, [:first_before, "scene", 3], [:update, 3], [:first_after, 3], :second_after])
$calls.clear
hooks.after(Scene_Test, :update, "first") { |_value| $calls << :first_again }
Scene_Test.new.update(1)
check("a second registration replaces the first in its place", $calls, [:second_before, [:first_before, "scene", 1], [:update, 1], :first_again, :second_after])
$calls.clear
hooks.after(Frames.singleton_class, :update, "frames") { $calls << [:after_frame, self] }
Frames.update
check("a module's method runs its blocks on the module", $calls, [:frame, [:after_frame, Frames]])

# A failing block leaves the method and the other blocks running and is logged once in its mod's log.
$calls.clear
hooks.before(Scene_Test, :update, "broken", Some_Mod) { |_value| raise "boom" }
hooks.after(Scene_Test, :update, "broken framework") { |_value| raise "bang" }
2.times { Scene_Test.new.update(1) }
check("the method and the other blocks still run", [$calls.count([:update, 1]), $calls.count(:second_after)], [2, 2])
check("each failure is logged once, in the log of the mod that registered it or the framework's",
      [*Some_Mod::LINES, $log.grep(/boom|hooks: broken framework failed after Scene_Test#update: RuntimeError: bang/).size],
      ["broken failed before Scene_Test#update: RuntimeError: boom", 1])

# Around wraps decide what the method returns and stack; a wrap may pass other arguments.
hooks.around(Scene_Test, :double, "one") { |_scene, args, original| args[0] > 5 ? :refused : original.call + 1 }
hooks.around(Scene_Test, :double, "two") { |_scene, _args, original| [original.call] }
check("around wraps stack, the inner one deciding first", [Scene_Test.new.double(2), Scene_Test.new.double(9)], [[5], [:refused]])
hooks.around(Scene_Test, :add, "args") { |_scene, args, original| args[0] > 5 ? original.call(args[0] * 10, args[1]) : original.call }
hooks.around(Scene_Test, :double, "two") { |_scene, _args, original| [original.call, :again] }
check("a tag wrapping again replaces its wrap, which is logged", [*Scene_Test.new.double(2), $log.grep(/two wrapped Scene_Test#double again/).size], [5, :again, 1])
check("a wrap runs the original with arguments of its own or with the method's", [Scene_Test.new.add(9, 1), Scene_Test.new.add(2, 1)], [91, 3])
Some_Mod::LINES.clear
hooks.around(Scene_Test, :fails, "passes", Some_Mod) { |_scene, _args, original| original.call }
check("an error of the original reaches the game", (Scene_Test.new.fails rescue $!.message), "the game's own error")
hooks.around(Scene_Test, :add, "broken", Some_Mod) { |_scene, _args, _original| raise "bad wrap" }
check("a failing wrap reaches the game and only it is logged, in its mod's log",
      [(Scene_Test.new.add(1, 1) rescue $!.message), *Some_Mod::LINES], ["bad wrap", "broken failed around Scene_Test#add: RuntimeError: bad wrap"])

# The report: one line per tag, once.
$log.clear
hooks.report
lines = $log.dup
$log.clear
hooks.report
check("the report logs once one line per tag with the methods it follows and wraps, a module's method as the module calls it",
      [lines.grep(/hooks: (first: follows 1, wraps 0 game method\(s\): follows Scene_Test#update|one: follows 0, wraps 1 game method\(s\): wraps Scene_Test#double)\z/).size,
       lines.grep(/hooks: frames: .*: follows Frames\.update\z/).size, $log.size], [2, 1, 0])

# A method the game defines only later, as a plugin does, and plugins that define a wrapped method
# again, as the translation's plugins load after the mods: one with a plain def, which drops the
# hooks, and one that calls the wrap it replaced.
early = (hooks.around(Window_Plugin, :late, "late") { |_scene, _args, original| original.call + 1 } rescue $!.class)
class Window_Plugin; def late; 1; end; end
hooks.around(Window_Plugin, :late, "late") { |_scene, _args, original| original.call + 1 }
check("a wrap of a method not defined yet fails and the next try once it is defined wraps it", [early, Window_Plugin.new.late], [NameError, 2])
hooks.after(Window_Plugin, :refresh, "plugin test") { $calls << :refresh_after }
hooks.after(Window_Plugin, :update, "plugin test") { $calls << :update_after }
$log.clear
hooks.report(true)
class Window_Plugin
  def refresh; :plugin; end
  alias plugin_update update
  def update; plugin_update; end
end
Window_Plugin.new.update
2.times { hooks.report(true) }
check("it names once a method a plain def replaced, but not one whose hooks still run", $log.grep(/defined again/),
      ["hooks: Window_Plugin#refresh was defined again after its hooks were installed; they run only if the new definition calls the old one"])

# The framework's frame blocks stay outside a mod that registers after the run's report.
class Scene_Frame
  def update; $calls << :update; end
end
$calls.clear
hooks.outermost(Scene_Frame, :update, :before, "frame start") { $calls << :frame_start }
hooks.outermost(Scene_Frame, :update, :after, "frame end") { $calls << :frame_end }
$log.clear
hooks.before(Scene_Frame, :update, "late mod") { $calls << :mod_before }
hooks.after(Scene_Frame, :update, "late mod") { $calls << :mod_after }
Scene_Frame.new.update
check("outermost blocks stay outside the blocks of a tag registered after the run's report, which is logged at once",
      [*$calls, $log.grep(/hooks: late mod: follows 1, wraps 0 game method\(s\): follows Scene_Frame#update\z/).size],
      [:frame_start, :mod_before, :update, :mod_after, :frame_end, 2])
