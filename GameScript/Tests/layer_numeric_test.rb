#----------------------------------------------------------------
#  layer_numeric_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers numeric_field of the UI layer (design v2 section 5.3) in a booted game against FakeTree,
# through a mod's gold gift: the gold to give between bounds, stepped by a hundred, bound to a
# state, in a form that checks it against the party's gold. A step of C#'s tree reaches the state;
# confirm starts typing into a text box that types a whole number within the bounds; a refused key
# buzzes; Enter, a key bound to confirm and the focus leaving take the number C#'s text box settled,
# Enter sending the form; cancel puts the number back; an empty text keeps it. C#'s tree steps it and
# hands it the keys (TreeListTests), C#'s text box keeps the text a number (EditModelTests).

require_relative "layer_support"

GOLD_GIFT = <<-RUBY
  module Gold_Gift
    UI = Mod_Framework::UI

    class Gift < UI::Component
      state :gold, 500
      state(:given) { [] }

      def render
        window "Gift" do
          form on_submit: -> { self.given = given + [gold] } do
            numeric_field "Gold to give", bind: :gold, min: 0, max: 5000, step: 100, adornment: "G",
                                          validate: ->(gold) { "The party has 3000 G" if gold > 3000 }
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
  typed = {}
  fake.answer("ui.edit.open") { |request| opened << request; opened.size }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| typed.merge("view" => { "line" => [0, typed["text"].to_s.length, 0] }) }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Gold_Gift.rb", GOLD_GIFT)
    frame

    # What C#'s text box tells as the player types: the text and the number it settles it to.
    type_in = lambda do |text, number, outcomes|
      typed.replace("id" => opened.size, "text" => text, "cursor" => text.length, "shown" => true, "number" => number)
      $dll.post("ui.edit", typed.merge("outcomes" => outcomes, "keys" => 1, "chars" => text.length))
      frame
      frame
    end

    ui.open(Gold_Gift::Gift)
    frame
    Graphics.update
    gift = ui::Engine::Layer.tops.last.mount.component
    field = ui::Engine::Tree.component(nodes_of(tree, "numeric_field").last)
    props = lambda { tree.nodes[field.node][:props] }
    error = lambda { shown = field.parent.children.last; shown.visible? ? shown.text : nil }
    typing = lambda { ui::Engine::TextField.typing.equal?(field) }
    check("the gold as it opens [number, least, largest, step, arrows, typed once confirmed, label above]",
          [props.call["number"], props.call["number_min"], props.call["number_max"], props.call["number_step"], props.call["number_arrows"] > 0,
           props.call["confirm_to_type"], field.parent.children.first.text],
          [500, 0, 5000, 100, true, true, "Gold to give"])

    # The player steps to 600: the state follows.
    tell(tree, [[field.node, "number", 600]])
    check("the gold stepped to 600", gift.gold, 600)

    # Confirm starts typing into a text box of a whole number within the bounds, the number as its
    # text; what is typed waits until it is taken, and a refused key buzzes.
    tell(tree, [[field.node, "click"]])
    check("typing after confirm [typing, text box, told C#]", [typing.call, opened.last, props.call["typing"]],
          [true, { "text" => "600", "number" => [0, 5000], "alt_codes" => 3 }, true])
    $sounds = []
    type_in.call("6004", 5000, ["typed"])
    type_in.call("6004", 5000, ["refused"])
    check("typing 6004 and a letter [gold, sounds]", [gift.gold, $sounds], [600, [:buzzer]])

    # Enter takes the number within the bounds, stops typing and sends the form, which refuses more
    # gold than the party has.
    type_in.call("6004", 5000, ["enter"])
    check("Enter on 6004 [gold, typing, error, given, last sound]", [gift.gold, typing.call, error.call, gift.given, $sounds.last],
          [5000, false, "The party has 3000 G", [], :buzzer])

    # Cancel puts the number back.
    tell(tree, [[field.node, "click"]])
    type_in.call("2", 2, ["typed"])
    tell(tree, [[field.node, "revert"]])
    check("cancel after typing 2 [gold, typing]", [gift.gold, typing.call], [5000, false])

    # The focus leaving takes the number typed.
    tell(tree, [[field.node, "click"]])
    type_in.call("2500", 2500, ["typed"])
    tell(tree, [[field.node, "blur"]])
    check("the focus leaving after 2500 [gold, typing, error]", [gift.gold, typing.call, error.call], [2500, false, nil])

    # A key bound to confirm that types nothing gives Enter: the form sends the gold.
    tell(tree, [[field.node, "focus"], [field.node, "click"]])
    type_in.call("1200", 1200, ["typed"])
    tell(tree, [[field.node, "enter"]])
    check("Z after typing 1200 [gold, given, typing]", [gift.gold, gift.given, typing.call], [1200, [1200], false])

    # The mod sets 300: the field follows; Enter on an empty text keeps it.
    gift.gold = 300
    frame
    Graphics.update
    tell(tree, [[field.node, "click"]])
    check("the text typing starts from after the mod set 300", opened.last["text"], "300")
    type_in.call("", nil, ["enter"])
    check("Enter on an empty text [gold, typing]", [gift.gold, typing.call], [300, false])
  end
end
