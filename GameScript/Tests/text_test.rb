#----------------------------------------------------------------
#  text_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked the text rules on the cases C# checks, written here instead of read from a fixture
#                            - Read the typing from UI.typing?
#      Paulinchen  2026-11-06: Loaded the collector in place of the probe
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Kept a few flows of measuring texts and typing into a text box and checked each outcome on its own
#                            - Took the picture, the rect and the font from the game's stand-ins
#                            - Rewrote the checks as flow tests of measuring texts and typing into a text box
#                            - Loaded the engine script before the input script
#                            - Loaded the probe script, which the frame's tick measures with
#                            - Followed the box within the frame whose buttons it reads, as a scene does
#      Paulinchen  2026-10-31: Expected Escape and the numpad's 0 watched from the input's load
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Covers text.rbx against FakeBridge: the cases of cutting and breaking a text C# checks too, texts
# laid out in C# with each font defined once, the game's escape codes, a text box
# typed into, drawn and closed, F12, and the framework without the DLL.

require_relative "bridge_support"
require_relative "game_support"

# Stands in for the game's Window_Base: its conversion of escape codes as the game's base has it.
class Window_Base
  attr_accessor :visible, :openness

  # Makes a window, as the game's reads $game_system.
  def initialize(_x, _y, _width, _height)
    $game_system.window_tone
    @disposed = false
  end

  # Disposes it.
  def dispose
    @disposed = true
  end

  # Tells whether it was disposed.
  def disposed?
    @disposed
  end

  # Converts the escape codes as the game does.
  #
  # @param text [String] The text.
  # @return [String] The text converted.
  def convert_escape_characters(text)
    result = text.to_s.gsub(/\\/) { "\e" }
    result.gsub!(/\eV\[(\d+)\]/i) { $game_variables[$1.to_i] }
    result.gsub!(/\eN\[(\d+)\]/i) { $game_actors[$1.to_i] }
    result
  end
end

# Stands in for the game's Input: the buttons a test holds in $held.
module Input
  def self.trigger?(button); $held.include?(button); end
  def self.press?(button); $held.include?(button); end
  def self.repeat?(button); $held.include?(button); end
end

# Stands in for the game's screen.
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end

$held = []
load_scripts "logging", "hooks", "run", "bridge", "settings", "engine", "input", "collector", "text"
ui = Mod_Framework::UI
glyphs = ui::Engine::Glyphs
log = []
Mod_Framework::Log.define_singleton_method(:write) { |line| log << line }

# The text rules measured here, while the bridge is closed, on the cases TextLayoutTests checks in
# C#, so the two never drift apart: every character 10 pixels wide.
ten = Object.new
def ten.text_size(text)
  Struct.new(:width).new(text.to_s.length * 10)
end
check("a text too wide is cut as C# cuts it",
      [ui.cut_measured(ten, "Alice", 50), ui.cut_measured(ten, "Alice the Monster Lord", 100), ui.cut_measured(ten, "Ilias Village", 120, " (2F)"),
       ui.cut_measured(ten, "ab   cdefgh", 80), ui.cut_measured(ten, "Alice", 20)],
      ["Alice", "Alice t...", "Ilia... (2F)", "ab...", "..."])
check("a text breaks into the lines C# breaks it into",
      [ui.wrap_measured(ten, "Leave the party and go back", 100), ui.wrap_measured(ten, "a Supercalifragilistic word", 70)],
      [["Leave the", "party and", "go back"], ["a", "Superca", "lifragi", "listic", "word"]])
check("a text breaks into the stretches C# breaks it into",
      [ui.wrap_spans("Leave the party", 10) { |part| part.length }, ui.wrap_spans("abcdefghijkl mn", 5) { |part| part.length }],
      [[[0, 10], [10, 5]], [[0, 5], [5, 5], [10, 5]]])

# Texts laid out in C#: the font defined once with its ASCII widths, new characters handed over once
# with the text that brings them or with the frame's batch when a model asks for them.
fake = FakeBridge.new
asked = []
ticks = []
$keys = {}
[glyphs::TOPIC, glyphs::CUT, glyphs::WRAP, glyphs::SPANS, glyphs::RUNS].each do |topic|
  fake.answer(topic) { |request| asked << [topic, request]; topic == glyphs::CUT ? "cut by C#" : nil }
end
fake.answer("ui.tick") do |request|
  ticks << request
  fake.post("ui.input", "mouse" => nil, "buttons" => 0, "double" => false, "wheel" => 0, "keys" => $keys, "front" => true)
  nil
end
Mod_Framework.bridge.open(fake)
measure = Bitmap.new(10, 10)
ui.cut(measure, "Alice the Monster Lord", 60, " (2)")
check("the cut names the font's key, the width, the text and the tail", asked[1], [glyphs::CUT, [1, 60, "Alice the Monster Lord", " (2)", nil]])
asked.clear
ui.wrap(measure, "日本 b", 40)
ui.wrap(measure, "日本", 40)
check("new characters go once with the first text that brings them", asked.map { |entry| entry[1][3] }, [{ 26085 => 12, 26412 => 12 }, nil])
glyphs.measure_wanted("key" => 1, "points" => [0x3042])
Mod_Framework.bridge.flush

# Escape codes are converted by a hidden game window and laid out in C#; a conversion that fails
# takes the text as it is, logged once.
# Stands in for the game's system data, which a game window reads as it is made.
$game_system = Struct.new(:window_tone).new(nil)
$game_variables = { 1 => 42 }
$game_actors = { 1 => "Luka" }
asked.clear
ui::Engine::Escapes.runs(measure, "\\C[2]\\N[1] has \\V[1]é", 100)
check("the game's conversion fills in the codes before C# lays the text out", asked.last, [glyphs::RUNS, [1, 100, "\eC[2]Luka has 42é", { 233 => 12 }]])
log.clear
converter = ui::Engine::Escapes.method(:converter)
ui::Engine::Escapes.define_singleton_method(:converter) { raise ArgumentError, "a broken plugin" }
ui::Engine::Escapes.convert("\\C[1]x")
check("a failing conversion takes the text as it is, logged once", [ui::Engine::Escapes.convert("\\C[1]x"), log.size], ["\eC[1]x", 1])
ui::Engine::Escapes.define_singleton_method(:converter, converter)

# A text box typed into: it opens in C# with its options, hands C# the frame's keys, mirrors its own
# box's events and draws what C# says it shows.
edit = ui::Engine::TextEdit
opened = []
closed = []
fake.answer(edit::OPEN) { |request| opened << request; 7 }
fake.answer(edit::CLOSE) { |id| closed << id; nil }
fake.answer(edit::VIEW) { |_request| { "id" => 7, "text" => "hello", "cursor" => 4, "shown" => true, "view" => { "line" => [1, 3, 14] } } }
Mod_Framework.bridge.open(fake)
# Runs a frame: the tick after Input.update, then the frame's end.
frame = lambda do
  ui::Engine::Tick.send_frame
  ui::Engine::Tick.end_frame
end
editor = edit.new("hello", :max_chars => 8, :allowed => /\A[a-z]\z/i, :mask => "*")
opened.first.delete("allowed_check")
check("the box opens in C# with its options", opened.first, { "text" => "hello", "max_chars" => 8, "allowed" => ["\\A[a-z]\\z", true], "mask" => "*" })
frame.call
$held = [:LEFT]
$keys = { edit::HOME_KEY => 3 }
ui::Engine::Tick.send_frame
editor.follow(true, 2)
ui::Engine::Tick.end_frame
frame.call
$held = []
$keys = {}
check("the box hands C# the frame's keys", ticks.last[edit::MODEL], [7, 1 | 16, 1, 2, 0])
fake.post(edit::EVENT, "id" => 7, "text" => "hi", "cursor" => 1, "shown" => false, "view" => nil, "outcomes" => ["typed", "enter"], "keys" => 2, "chars" => 3)
fake.post(edit::EVENT, "id" => 9, "text" => "other", "cursor" => 0, "shown" => true, "view" => nil, "outcomes" => ["escape"], "keys" => 1, "chars" => 1)
frame.call
check("the box mirrors its own box's events only", [editor.text, editor.cursor, editor.take.outcomes], ["hi", 1, [:typed, :enter]])
bitmap = Bitmap.new(200, 24)
ui::Engine::TextBox.draw_line(bitmap, Rect.new(10, 0, 100, 24), editor, "******")
fake.answer(edit::VIEW) { |_request| { "id" => 7, "text" => "ab cd", "cursor" => 4, "shown" => true, "view" => { "area" => [[[0, 3], [3, 2]], 0, 1, 8] } } }
area = Bitmap.new(200, 48)
ui::Engine::TextBox.draw_area(area, Rect.new(0, 0, 100, 48), editor, 24)
check("a box of several lines draws the lines C# broke", area.texts, [[0, 0, "ab "], [0, 24, "cd"]])

# Closing the box stops the typing and leaves out a later event; F12 closes the box and drops the
# hidden window.
editor.close
fake.post(edit::EVENT, "id" => 7, "text" => "late", "cursor" => 4, "shown" => true, "view" => nil, "outcomes" => ["typed"], "keys" => 1, "chars" => 1)
frame.call
check("closing a box closes it in C# and stops the typing", [closed, ui.typing?], [[7], false])
edit.new("")
ui::Engine::Escapes.converter
Mod_Framework::Run.begin_run
Mod_Framework::Run.begin_run
check("F12 closes the box being typed into", [edit.current, ui.typing?], [nil, false])

# Without the DLL every text is measured here, and a box opens nothing in C# and types nothing.
Mod_Framework.bridge.close
asked.clear
ui.cut(measure, "Alice the Monster Lord", 60)
ui.spans(nil, "ab cd", 3)
ui::Engine::Escapes.runs(measure, "a")
check("without the DLL nothing is asked of C#", asked, [])
offline = edit.new("abc")
offline.follow
offline.close
check("without the DLL a box opens nothing", [offline.id, ui.typing?], [nil, false])
