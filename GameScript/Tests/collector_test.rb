#----------------------------------------------------------------
#  collector_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked the collection and the pictures let go while the game runs low on memory
#                            - Created
#
#----------------------------------------------------------------

# Covers collector.rbx: the garbage collection behind a scene change, skipped after a collection
# the game ran since the last frame and within a minute of the last one, and the collection and the
# pictures let go while the game runs low on memory.

require_relative "support"

load_scripts "logging", "hooks", "run", "collector"
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }
collector = Mod_Framework::UI::Engine::Collector
scene = Object.new

# Only the collections the test runs count, never one Ruby starts by itself.
GC.disable
collector.note_frame
GC.start
after_the_games = collector.scene_changed(scene)
collector.instance_variable_set(:@collected_at, Time.now.to_f - collector::GAP - 1)
a_minute_later = collector.scene_changed(scene)
right_after = collector.scene_changed(scene)
GC.enable
check("a collection the game ran since the last frame counts, then a scene change collects once a minute at most",
      [after_the_games, a_minute_later, right_after], [false, true, false])

# The memory: a check every few seconds; while the DLL answers low, the framework's and the game's
# pictures are let go of down to a few and a collection runs at once.
guard = Mod_Framework::UI::Engine::MemoryGuard
low = false
asked = []
trimmed = []
dll = Object.new
dll.define_singleton_method(:has?) { |_topic| true }
dll.define_singleton_method(:call) do |topic, _request = nil|
  asked << topic
  { "used" => 1750, "free" => low && topic == guard::CHECK_TOPIC ? 280 : 700, "private" => 1100, "low" => low }
end
Mod_Framework.define_singleton_method(:bridge) { dll }
Mod_Framework::UI.define_singleton_method(:trim_pictures) { |left| trimmed << [:framework, left]; 28 }
module Mod_Framework::UI::Engine::GameMenus; module PictureCache; end; end
Mod_Framework::UI::Engine::GameMenus::PictureCache.define_singleton_method(:forget) { |left| trimmed << [:game, left]; 60 }
guard::CHECK_FRAMES.times { guard.check }
plenty = [asked.dup, trimmed.dup]
low = true
collections = GC.count
lines = logged_lines { guard.check }
check("memory is checked once every few seconds, and nothing is let go of while it is plenty", plenty, [[guard::CHECK_TOPIC], []])
check("running low lets go of pictures down to a few, collects at once and logs the numbers",
      [trimmed, GC.count > collections, lines],
      [[[:framework, guard::PICTURES_LEFT], [:game, guard::GAME_PICTURES_LEFT]], true,
       ["memory: the game ran low on memory, 280 MB of address space free with 1750 MB used and 1100 MB private: let go of 88 pictures and collected in #{lines.first[/in (\d+) ms/, 1]} ms, 700 MB free now"]])
