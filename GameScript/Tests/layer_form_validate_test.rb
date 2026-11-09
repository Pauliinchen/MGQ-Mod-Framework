#----------------------------------------------------------------
#  layer_form_validate_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked that the letter pages of a field's text field take the field's caption as their title
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers form, required: and validate: of the UI layer (design v2 section 5.3) in a booted game
# against FakeTree, through a mod's quest board: posting with the name left empty buzzes, shows the
# error under the name and hands it the focus; typing shows a giver's error at once and the bound
# validity follows; Enter in the name moves on to the giver, and Enter in the giver, the last input
# that confirms, posts the quest past the switch after it and past a required reward that stays
# disabled while the quest is not urgent; last, the gamepad's letter pages of the board's text
# field, which sits in a field with its caption beside it, are titled by that caption.

require_relative "layer_support"

QUEST_BOARD = <<-RUBY
  module Quest_Board
    UI = Mod_Framework::UI

    class PostQuest < UI::Component
      state :board, ""
      state :name, ""
      state :giver, ""
      state :ready, false
      state :urgent, false
      state :reward, ""
      state(:posted) { [] }

      def render
        dialog "Post a quest" do
          form bind_valid: :ready, id: :quest_form, on_submit: -> { self.posted = posted + [[name, giver]] } do
            field "Board", caption_width: ["Board"] do
              text_field bind: :board, validate: ->(board) { "Only letters" if board =~ /[^A-Za-z ]/ }, id: :quest_board
            end
            text_field "Quest name", bind: :name, required: "Name the quest", id: :quest_name
            text_field "Given by", bind: :giver, validate: ->(giver) { "Only letters" if giver =~ /[^A-Za-z ]/ }, id: :quest_giver
            switch "Urgent", bind: :urgent
            text_field "Reward", bind: :reward, required: "Name the reward", disabled: !urgent
            button "Post", on_click: :submit, id: :quest_post
          end
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
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| { "id" => opened.size, "text" => "", "cursor" => 0, "shown" => true, "view" => { "line" => [0, 0, 0] } } }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Quest_Board.rb", QUEST_BOARD)
    frame

    ui.open(Quest_Board::PostQuest)
    frame
    Graphics.update
    board = ui::Engine::Layer.tops.last.mount.component
    board_field, name, giver = nodes_of(tree, "text_field").map { |node| ui::Engine::Tree.component(node) }
    post = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    error_of = lambda { |field| shown = field.parent.children.last; shown.is_a?(ui::Engine::Label) && shown.visible? ? shown.text : nil }
    asked = lambda { change = tree.changes.reverse.find { |each| each["focus"] }; change && ui::Engine::Tree.component(change["focus"]) }
    typing = nil
    type = lambda do |field, text, outcome|
      tell(tree, (typing && !typing.equal?(field) ? [[typing.node, "blur"]] : []) + [[field.node, "focus"]]) unless typing.equal?(field)
      typing = field
      $dll.post("ui.edit", "id" => opened.size, "text" => text, "cursor" => text.size, "shown" => true, "outcomes" => [outcome], "keys" => 1, "chars" => 1)
      frame
      frame
    end
    check("the board as it opens [name's error, giver's error, ready, the post button quiet]", [error_of.call(name), error_of.call(giver), board.ready, post.quiet],
          [nil, nil, false, true])

    # Post with the name empty: the buzzer, the error under the name, the focus asked there, nothing posted.
    $sounds = []
    tell(tree, [[post.node, "click"]])
    check("posting with the name empty [sounds, name's error, focus asked on the name, posted]",
          [$sounds, error_of.call(name), asked.call.equal?(name), board.posted], [[:buzzer], "Name the quest", true, []])
    check("the log line of the refused post", layer_lines.grep(/PostQuest: the form quest_form was not sent: Quest name: Name the quest/).size, 1)

    # The name typed: its error goes and the board is ready; a giver with a digit shows its error at once.
    type.call(name, "Herbs", "typed")
    check("the name typed [name's error, ready]", [error_of.call(name), board.ready], [nil, true])
    type.call(giver, "Ana1", "typed")
    check("a giver with a digit [giver's error, ready]", [error_of.call(giver), board.ready], ["Only letters", false])

    # Enter in the name moves on to the giver; Enter in the giver, the last input that confirms, posts
    # the quest though the urgent switch and the empty reward, disabled, follow it.
    type.call(giver, "Ana", "typed")
    type.call(name, "Herbs", "enter")
    check("Enter in the name [focus asked on the giver, posted]", [asked.call.equal?(giver), board.posted], [true, []])
    $sounds = []
    type.call(giver, "Ana", "enter")
    check("Enter in the giver posts the quest past the empty reward, disabled [posted, sounds, giver's error]", [board.posted, $sounds, error_of.call(giver)], [[["Herbs", "Ana"]], [:ok], nil])
    check("the log line of the post", layer_lines.grep(/PostQuest: the form quest_form was sent$/).size, 1)

    # A gamepad's A on the board's text field opens the game's letter pages under the field's caption.
    tell(tree, [[board_field.node, "submit"]])
    pad = ui::Engine::Tree.component(tree.nodes.keys.sort.reverse.find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::LetterPad) })
    check("the letter pages of the text field in the Board field are titled Board", pad && pad.title, "Board")
  end
end
