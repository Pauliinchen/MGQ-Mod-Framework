#----------------------------------------------------------------
#  style_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Typed through the framework's text box in place of a flag of another mod
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Loaded the text script the plate measures with
#      Paulinchen  2026-11-04: Kept a few flows of drawing a box, the hints and a motion and checked each outcome on its own
#                            - Took the sprite from the game's stand-ins
#                            - Rewrote the checks as flow tests of drawing a box, the hints and a motion
#                            - Checked the motion of a sprite in two checks
#                            - Loaded the engine script before the input script
#      Paulinchen  2026-11-01: Checked the keys that leave a text field named before it types
#                            - Checked the hint of a part that goes back on cancel
#      Paulinchen  2026-10-31: Checked the cancel keys and the close hint as F1 binds the game's cancel
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Covers style.rbx: a box drawn in the player's preset and in another one, the plate, the scrollbar
# and the motion of a sprite; and the cancel keys and the close hint of input.rbx that every hint
# names.

require_relative "bridge_support"
require_relative "game_support"

load_scripts "logging", "hooks", "run", "bridge", "settings", "engine", "input", "text", "style", "theme"
ui = Mod_Framework::UI
style = ui::Engine::Style
theme = ui::Engine::Theme
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }

# A box drawn in the player's preset and in another one.
theme.apply("Legacy", "a test")
bitmap = Bitmap.new(100, 50)
style.draw_frame(bitmap, 0, 0, 100, 50)
check("Legacy's frame is the grey edge alone, one pixel wide", [bitmap.fills.map { |fill| fill[4] }.uniq, style.frame_width], [[[140, 140, 140, 220]], 1])
monarch = theme.palette("Monarch")
bitmap.clear
style.draw_box(bitmap, 0, 0, 100, 50, monarch)
check("a box given Monarch's palette draws in Monarch while the player's look is Legacy", [bitmap.fills.first[4], style.frame_width(monarch)], [[36, 10, 14, 235], 2])

# The plate and the scrollbar.
bitmap.clear
check("a plate fills the text's width with the padding on either side, centered", style.draw_plate(bitmap, 10, 5, 200, 20, "abcd").to_a, [80, 5, 60, 20])
bitmap.clear
style.draw_scrollbar(bitmap, 10, 20, 100, 0, 10, 10)
style.draw_scrollbar(bitmap, 10, 20, 100, 30, 10, 40)
check("a scrollbar draws its track and its thumb at the end", bitmap.fills.map { |fill| fill[0, 4] }, [[10, 20, 4, 100], [10, 95, 4, 25]])

# The hints name the game's own cancel keys, the keys F1 binds and Esc while a text field types.
check("the hints name the game's X and Numpad 0", ui.close_hint("a click outside"), "X, Numpad 0 or a click outside: close")
ui::Engine::Pad.assign("B" => [0x1B, 0x60, 0x2D, 0x41], "C" => [0x20, 0x0D, 0x5A, 0x58])
check("after F1 binds A to cancel the hints name A", ui.close_hint("F11"), "A, Numpad 0 or F11: close")
ui::Engine::TextEdit.open = :field
check("while a text field types the hint names Esc", ui.close_hint, "Esc or Numpad 0: close")
ui::Engine::TextEdit.release(:field)
ui::Engine::Pad.assign("B" => [0x1B, 0x60, 0x2D, 0x58])

# The motion of a sprite: a fade in with a slide, and a fade out turned back half way.
sprite = Sprite.new
sprite.x, sprite.y = 100, 50
motion = ui::Engine::Motion.new(sprite)
motion.show(-40, 0)
style::FADE_FRAMES.times { motion.update }
check("it is opaque and still after FADE_FRAMES", [sprite.opacity, motion.update], [255, false])
motion.hide
6.times { motion.update }
halfway = sprite.opacity
motion.show(-40, 0)
check("show during a fade out turns the opacity back without a jump", [sprite.x, sprite.opacity], [100, halfway])
motion.hide
style::FADE_FRAMES.times { motion.update }
check("a fade out ends invisible", [sprite.opacity, sprite.visible, motion.hidden?], [0, false, true])
