#----------------------------------------------------------------
#  layer_captures_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Placed the parts a test places inside the content of their root, which draws only there
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers window captures: :typing of the UI layer (design v2 sections 5.1 and 5.13, chat) in a
# booted game against FakeTree, through a mod's camp talk that stays on the screen while the player
# walks: it holds the game's buttons only while its line types; the first cancel gives them back,
# takes the focus off the line and asks on_cancel, which keeps the window open; a click on a name in
# its log stops the line typing before the mod hears the name.

require_relative "layer_support"

CAMP_TYPING = <<-RUBY
  module Camp_Typing
    UI = Mod_Framework::UI

    class Talk < UI::Component
      state :line, ""
      state :cancels, 0
      state(:named) { [] }

      def render
        window "Camp talk", id: :camp_typing, captures: :typing, on_cancel: -> { self.cancels = cancels + 1; false } do
          log [[{ text: "Ana", data: :ana }, ": wait"]], id: :camp_typing_log,
              on_click: ->(_row, part) { self.named = named + [[part[:data], Mod_Framework::UI::Engine::TextField.typing.nil?]] }
          text_field bind: :line, id: :camp_typing_line
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
    load_mod("Patch/Camp_Typing.rb", CAMP_TYPING)
    frame
    handle = ui.open(Camp_Typing::Talk)
    frame
    talk = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Layer.tops.last.root.engine
    field = root.find(:camp_typing_line)
    holding = lambda { [root.holds_buttons?, tree.nodes[root.node][:props]["captures"]] }
    check("the window before its line types [holds the buttons, C# told it captures]", holding.call, [false, false])

    # The line types: the window holds the game's buttons.
    tell(tree, [[field.node, "focus"]])
    check("the window while its line types", holding.call, [true, true])

    # The first cancel while it types: the buttons go back, the line lets go of the focus and
    # on_cancel keeps the window.
    tell(tree, [[field.node, "rest"]])
    blurred = tree.changes.map { |changes| changes["blur"] }.compact.flatten
    check("after the first cancel [holds the buttons, the line blurred, cancels heard, window open]",
          [root.holds_buttons?, blurred.include?(field.node), talk.cancels, handle.open?], [false, true, 1, true])

    # The line types again, and a click on Ana's name in the log stops it before the mod hears her
    # name, so a menu the mod opens on it takes the keys.
    tell(tree, [[field.node, "focus"]])
    log = root.find(:camp_typing_log)
    tree.rects[log.node] = [root.content_rect.x, root.content_rect.y, 200, 40]
    frame
    Graphics.update
    name = root.base_surface.bitmap.texts.find { |text| text[2].strip == "Ana" }
    $mouse_at = [root.base_surface.x + name[0] + 2, root.base_surface.y + name[1] + 4]
    tell(tree, [[log.node, "click"]])
    check("a click on a name while the line types [holds the buttons, names heard with whether the line had stopped]",
          [root.holds_buttons?, talk.named], [false, [[:ana, true]]])
  end
end
