#----------------------------------------------------------------
#  layer_help_line_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that the line keeps the room of its line while it tells nothing
#                            - Checked a hint that on_focus and on_blur of the field show and take away
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers help_line of the UI layer (design v2 section 5.4) in a booted game against FakeTree,
# through a mod's camp notes: the line tells the help: of the focused button, what say said after a
# save until the focus moves on, and the field's typing_help: while it types, keeping the room of its
# line while it tells nothing; and a hint the window shows while the focus is on the field, told by
# its on_focus and on_blur.

require_relative "layer_support"

HELP_CAMP = <<-RUBY
  module Help_Camp
    UI = Mod_Framework::UI

    class Notes < UI::Component
      state :note, ""
      state :at_field, false

      def render
        window "Camp notes", id: :help_camp do
          text_field "Note", bind: :note, id: :note, help: "A line for the camp book.", typing_help: "Enter keeps the line.",
                              on_focus: -> { self.at_field = true }, on_blur: -> { self.at_field = false }
          text at_field ? "Confirm: write a note" : "", id: :field_hint
          stack row: true do
            button "Save", id: :save, help: "Writes the line into the camp book.", on_click: -> { part(:help).say("Saved into the camp book.") }
            button "Clear", id: :clear, help: "Empties the line.", on_click: -> { self.note = "" }
          end
          help_line id: :help, lines: 1
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  opened = []
  fake.answer("ui.edit.open") { |request| opened << request; opened.size }
  fake.answer("ui.edit.close") { |_request| nil }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Help_Camp.rb", HELP_CAMP)
    frame

    ui.open(Help_Camp::Notes)
    frame
    Graphics.update
    root = ui::Engine::Tree.roots.last
    line = root.find(:help)
    shown = lambda { Graphics.update; line.text }
    focus = lambda { |id| tree.post("states", root.find(id).node => ui::Engine::Tree::FOCUSED); frame; Graphics.update }

    # The focus on Save: the line tells what Save does, on one line.
    focus.call(:save)
    check("the line on Save [text, its lines]", [shown.call, line.most_lines], ["Writes the line into the camp book.", 1])

    # Save pressed: the line says the mod's text until the focus moves to Clear.
    tell(tree, [[root.find(:save).node, "click"]])
    said = shown.call
    focus.call(:clear)
    check("what say said, then the help of Clear once the focus moved", [said, shown.call], ["Saved into the camp book.", "Empties the line."])

    # Saying nothing empties the line, which keeps the room of its line, so the buttons around it
    # stay where a press found them.
    line.say("")
    check("the line's least height while it tells nothing [height, text]", [tree.nodes[line.node][:props]["min"][1], shown.call],
          [ui.line_height_of(:small), ""])

    # The note field types: the line tells its typing help.
    field = root.find(:note)
    focus.call(:note)
    tell(tree, [[field.node, "focus"]])
    $dll.post("ui.edit", "id" => opened.size, "text" => "Ra", "cursor" => 2, "shown" => true, "outcomes" => ["typed"], "keys" => 1, "chars" => 1)
    frame
    check("the line while the field types", shown.call, "Enter keeps the line.")

    # The hint shows while the focus is on the field and goes as the focus leaves it.
    hint = root.find(:field_hint)
    with_focus = hint.text
    tell(tree, [[field.node, "blur"], [root.find(:save).node, "focus"]])
    check("the field's hint while it holds the focus, and after the focus left it", [with_focus, hint.text], ["Confirm: write a note", ""])
  end
end
