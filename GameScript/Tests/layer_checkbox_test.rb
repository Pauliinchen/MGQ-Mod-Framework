#----------------------------------------------------------------
#  layer_checkbox_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers checkbox and switch of the UI layer (design v2 section 5.3) in a booted game against
# FakeTree, through a mod's camp rules: a box bound to a state that a click ticks, a box of three
# states, a switch between two paces that Left and Right turn as well as a click, the state set by
# the mod reaching both, and a box the rules require, whose error shows under it as the rules are
# kept. C#'s tree steps the switch as a select.

require_relative "layer_support"

CAMP_RULES = <<-RUBY
  module Camp_Rules
    UI = Mod_Framework::UI

    class Rules < UI::Component
      state :watch, true
      state :loot, false
      state :fast, false
      state :read, false
      state(:told) { [] }
      state(:kept) { [] }

      def render
        window "Camp rules" do
          form on_submit: -> { self.kept = kept + [[watch, loot, fast]] } do
            checkbox "Night watch", bind: :watch, on_change: ->(on) { self.told = told + [on] }
            checkbox "Share the loot", bind: :loot, tri_state: true
            switch "Pace", bind: :fast, values: ["Slow", "Fast"]
            checkbox "I read the rules", bind: :read, required: "Read them first"
            button "Keep", on_click: :submit
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Rules.rb", CAMP_RULES)
    frame

    ui.open(Camp_Rules::Rules)
    frame
    Graphics.update
    rules = ui::Engine::Layer.tops.last.mount.component
    watch, loot, read = nodes_of(tree, "checkbox").map { |node| ui::Engine::Tree.component(node) }
    pace = ui::Engine::Tree.component(nodes_of(tree, "select").last)
    keep = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    check("the rules as they open [watch ticked, its text, pace a switch, pace on, the read box's column holds only it]",
          [watch.checked?, watch.text, pace.style, pace.checked?, read.parent.children.size], [true, "Night watch", :switch, false, 1])

    # A click takes the watch's tick off: the state and on_change follow.
    tell(tree, [[watch.node, "click"]])
    check("the watch after a click [state, told]", [rules.watch, rules.told], [false, [false]])

    # The loot box goes from off to on, to neither and back to off.
    states = []
    3.times do
      tell(tree, [[loot.node, "click"]])
      states << rules.loot
    end
    check("the loot box after three clicks", states, [true, nil, false])

    # Right turns the pace on, a click turns it off again.
    tell(tree, [[pace.node, "step", 1]])
    check("the pace after Right", rules.fast, true)
    tell(tree, [[pace.node, "click"]])
    check("the pace after a click", rules.fast, false)

    # The mod sets the watch and the pace: both follow.
    rules.watch = true
    rules.fast = true
    frame
    Graphics.update
    check("the watch and the pace after the mod set them", [watch.checked?, pace.checked?], [true, true])

    # Keeping the rules unread shows the error under the read box; ticked, they are kept.
    tell(tree, [[keep.node, "click"]])
    shown = read.parent.children.last
    check("keeping the rules unread [error under the read box, kept]", [shown.equal?(read) ? nil : shown.text, rules.kept], ["Read them first", []])
    tell(tree, [[read.node, "click"]])
    tell(tree, [[keep.node, "click"]])
    check("keeping the rules once read [error shown, kept]", [shown.visible?, rules.kept], [false, [[true, false, true]]])
  end
end
