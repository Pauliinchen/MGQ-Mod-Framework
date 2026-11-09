#----------------------------------------------------------------
#  layer_log_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Placed the parts a test places inside the content of their root, which draws only there
#      Paulinchen  2026-11-06: Checked that a word without room for its outline goes onto the next line
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers log of the UI layer (design v2 section 5.5) in a booted game against FakeTree, through a
# mod's camp talk: a log of the mod's own Array of lines, which grows as the mod adds lines to it; a
# line field that steers the log, whose Page Up scrolls it up, where a new line keeps the view still
# until the mod scrolls it back to the newest; a word without room for its outline wrapped onto the
# next line; and a name the pointer lights and a click on it tells the mod about.

require_relative "layer_support"

CAMP_TALK = <<-RUBY
  module Camp_Talk
    UI = Mod_Framework::UI

    class Talk < UI::Component
      state :line, ""
      state(:named) { [] }

      def render
        window "Camp talk", id: :camp_talk do
          log -> { $camp_lines }, id: :camp_log, on_click: ->(_row, part) { self.named = named + [part[:data]] }
          text_field bind: :line, id: :camp_line, steer: :camp_log
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ui.edit.open") { |_request| 1 }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| nil }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Talk.rb", CAMP_TALK)
    ana = { text: "Ana", color: :own, data: :ana }
    $camp_lines = [[ana, ": wait at the inn"], "Mia: on my way", "Bob: one", "Bob: two", "Bob: three"]
    frame
    ui.open(Camp_Talk::Talk)
    frame
    talk = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Layer.tops.last.root.engine
    log = root.find(:camp_log)
    field = root.find(:camp_line)
    line = ui.line_height_of(:small)
    tree.rects[log.node] = [root.content_rect.x, root.content_rect.y, 200, 2 * line]
    frame
    Graphics.update
    bottom = lambda do
      Graphics.update
      texts = root.base_surface.bitmap.texts.reject { |text| text[2].strip.empty? }
      lowest = texts.map { |text| text[1] }.max
      texts.select { |text| text[1] == lowest }.map { |text| text[2] }.join.strip
    end
    check("the newest line stands on the bottom edge", bottom.call, "Bob: three")

    # The mod adds a line to its own Array: the log shows it within the frames of a live value.
    $camp_lines << "Mia: four"
    5.times { frame }
    check("a line the mod added to its Array, and the bottom line", [log.rows.size, bottom.call], [6, "Mia: four"])

    # The line field steers the log: Page Up scrolls it up by the lines it shows, and a new line
    # keeps the view still until the mod scrolls it back to the newest.
    tell(tree, [[field.node, "focus"]])
    tell(tree, [[field.node, "key", 0x21]])
    check("the bottom line after Page Up in the line field", bottom.call, "Bob: two")
    $camp_lines << "Mia: five"
    5.times { frame }
    check("the bottom line after a new line, scrolled up", bottom.call, "Bob: two")
    talk.part(:camp_log).scroll_to_end
    frame
    check("the bottom line after scroll_to_end", bottom.call, "Mia: five")

    # A log as wide as a line's words without the room their outline takes puts the last word on
    # the next line instead of drawing it narrower.
    words = ui.text_width(ui.font_bitmap(ui.font_px(:small)), "Mia: in")
    tree.rects[log.node] = [root.content_rect.x, root.content_rect.y, words + 1 + ui::Engine::Style::SCROLLBAR_WIDTH + ui::Engine::LogView::BAR_GAP, 2 * line]
    $camp_lines << "Mia: in"
    5.times { frame }
    check("the bottom line once a word lacks the room of its outline", bottom.call, "in")
    tree.rects[log.node] = [root.content_rect.x, root.content_rect.y, 200, 2 * line]

    # The pointer on Ana's name lights it, and a click on it tells the mod whose name it is.
    $camp_lines.replace([[ana, ": wait"]])
    5.times { frame }
    Graphics.update
    name = root.base_surface.bitmap.texts.find { |text| text[2].strip == "Ana" }
    $mouse_at = [root.base_surface.x + name[0] + 2, root.base_surface.y + name[1] + 4]
    tell(tree, [[log.node, "hover", true]])
    check("the part lit under the pointer", log.instance_variable_get(:@hover_part)[:data], :ana)
    tell(tree, [[log.node, "click"]])
    check("the names a click told", talk.named, [:ana])
  end
end
