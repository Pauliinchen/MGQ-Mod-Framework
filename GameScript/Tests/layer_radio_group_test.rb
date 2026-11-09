#----------------------------------------------------------------
#  layer_radio_group_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers radio_group and radio of the UI layer (design v2 section 5.3) in a booted game against
# FakeTree, through a mod's battle options: the game's Battle Wait as three radios bound to a state,
# a click that picks one, the arrows that pick the radio they move onto but not one the focus
# enters from outside the group, a greyed radio, and the state set by the mod.

require_relative "layer_support"

BATTLE_OPTIONS = <<-RUBY
  module Battle_Options
    UI = Mod_Framework::UI

    class Options < UI::Component
      state :wait, 100
      state(:told) { [] }

      def render
        window "Battle options" do
          radio_group "Battle Wait", bind: :wait, on_change: ->(wait) { self.told = told + [wait] } do
            radio "Normal", value: 100
            radio "Fast", value: 50
            radio "Fastest", value: 25
            radio "Skip", value: 0, disabled: true
          end
          button "Done", on_click: -> {}
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Battle_Options.rb", BATTLE_OPTIONS)
    frame

    ui.open(Battle_Options::Options)
    frame
    Graphics.update
    options = ui::Engine::Layer.tops.last.mount.component
    normal, fast, fastest, skip = nodes_of(tree, "checkbox").map { |node| ui::Engine::Tree.component(node) }
    done = ui::Engine::Tree.component(nodes_of(tree, "button").last)
    picked = lambda { [normal, fast, fastest, skip].map { |radio| radio.checked? } }
    check("the options as they open [texts, picked]", [[normal, fast, fastest, skip].map { |radio| radio.text }, picked.call],
          [["Normal", "Fast", "Fastest", "Skip"], [true, false, false, false]])

    # A click on Fastest picks it alone: the state and on_change follow.
    tell(tree, [[fastest.node, "click"]])
    check("Fastest after a click [picked, state, told]", [picked.call, options.wait, options.told], [[false, false, true, false], 25, [25]])

    # Up from Fastest moves the focus onto Fast, which picks it.
    tell(tree, [[fastest.node, "blur"], [fast.node, "focus"]])
    check("Fast after Up [picked, state]", [picked.call, options.wait], [[false, true, false, false], 50])

    # The focus coming in from Done onto Normal leaves the pick as it is.
    tell(tree, [[fast.node, "blur"], [done.node, "focus"]])
    tell(tree, [[done.node, "blur"], [normal.node, "focus"]])
    check("Normal reached from Done [picked, state]", [picked.call, options.wait], [[false, true, false, false], 50])

    # The greyed Skip takes no click.
    tell(tree, [[skip.node, "click"]])
    check("Skip greyed out after a click [picked, state]", [picked.call, options.wait], [[false, true, false, false], 50])

    # The mod sets the wait back to Normal: the radios follow without telling on_change.
    options.wait = 100
    frame
    Graphics.update
    check("the radios after the mod set Normal [picked, told]", [picked.call, options.told], [[true, false, false, false], [25, 50]])
  end
end
