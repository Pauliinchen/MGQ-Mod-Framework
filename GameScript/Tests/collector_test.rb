#----------------------------------------------------------------
#  collector_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-12: Dropped the checks of a dark scene change, which no longer collects
#      Paulinchen  2026-11-11: Checked that a dark scene change collects only after the next scene set up, never at a battle start
#                            - Checked the collections at a faded map change, a dark scene change and a battle start
#      Paulinchen  2026-11-09: Checked the collection and the pictures let go while the game runs low on memory
#                            - Created
#
#----------------------------------------------------------------

# Covers collector.rbx: the garbage collection at a map change behind a fade once ten seconds passed
# since the last collection, the game's own counted too, and the collection and the pictures let go
# while the game runs low on memory.

require_relative "support"

load_scripts "logging", "hooks", "run", "collector"
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }
collector = Mod_Framework::UI::Engine::Collector

# The game as the collector reads it: the map with its fade and the field typed into.
screen = Struct.new(:brightness).new(255)
$game_map = Struct.new(:map_id, :screen).new(51, screen)
$game_temp = Struct.new(:fade_type).new(0)
typing = false
Mod_Framework::UI.define_singleton_method(:typing?) { typing }
due = lambda { collector.instance_variable_set(:@collected_at, Time.now.to_f - collector::DUE - 1) }
collects = lambda do |&block|
  before = GC.count
  block.call
  GC.count > before
end

# Only the collections the test runs count, never one Ruby starts by itself.
GC.disable

# A map walk: the game collects, then doors with and without a fade, once the clock is due.
collector.note_frame
GC.start
collector.note_frame
right_after_the_games = collects.call { collector.transferred }
due.call
faded_lines = nil
faded = collects.call { faded_lines = logged_lines { collector.transferred } }
due.call
$game_temp.fade_type = 2
visible = collects.call { collector.transferred }
screen.brightness = 0
typing = true
typed_into = collects.call { collector.transferred }
typing = false
after_the_fadeout = collects.call { collector.transferred }
GC.enable

check("a door right after the game's collection collects nothing; once due a faded door collects and logs it, a door " \
      "on a visible screen does not, nor one after an event's fadeout while a field is typed into, until typing ends",
      [right_after_the_games, faded, faded_lines, visible, typed_into, after_the_fadeout],
      [false, true, ["collector: collected at the map change to map 51 in #{faded_lines.first[/in (\d+) ms/, 1]} ms, 11 s after the last collection"],
       false, false, true])

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
