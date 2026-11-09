#----------------------------------------------------------------
#  layer_toggle_group_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers toggle_group and toggle_item of the UI layer (design v2 section 5.3) in a booted game
# against FakeTree, through a mod's battle options: the game's Button Explanation as two joined
# buttons of which one stays on, the skill cut-ins as buttons each turned on and off, and the state
# set by the mod.

require_relative "layer_support"

CUT_IN_OPTIONS = <<-RUBY
  module Cut_In_Options
    UI = Mod_Framework::UI

    class Options < UI::Component
      state :keys, :gamepad
      state(:cut_ins) { [:skill] }
      state(:told) { [] }

      def render
        window "Battle options" do
          toggle_group "Button Explanation", bind: :keys, on_change: ->(keys) { self.told = told + [keys] } do
            toggle_item "Gamepad", value: :gamepad
            toggle_item "Keyboard", value: :keyboard
          end
          toggle_group "Cut-ins shown", bind: :cut_ins, multi: true, color: :secondary do
            toggle_item "Skills", value: :skill
            toggle_item "Enemies", value: :enemy
            toggle_item "Chains", value: :chain
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
    load_mod("Patch/Cut_In_Options.rb", CUT_IN_OPTIONS)
    frame

    ui.open(Cut_In_Options::Options)
    frame
    Graphics.update
    options = ui::Engine::Layer.tops.last.mount.component
    gamepad, keyboard, skills, enemies, chains = nodes_of(tree, "button").map { |node| ui::Engine::Tree.component(node) }
    on = lambda { [gamepad, keyboard, skills, enemies, chains].map { |button| button.on? } }
    check("the options as they open [texts, on, the fill of the cut-ins on]",
          [[gamepad, keyboard, skills, enemies, chains].map { |button| button.text }, on.call, skills.color],
          [["Gamepad", "Keyboard", "Skills", "Enemies", "Chains"], [true, false, true, false, false], :secondary])

    # A click on Keyboard turns it on and Gamepad off; a second click keeps it on.
    tell(tree, [[keyboard.node, "click"]])
    tell(tree, [[keyboard.node, "click"]])
    check("Keyboard after two clicks [on, state, told]", [on.call[0, 2], options.keys, options.told], [[false, true], :keyboard, [:keyboard]])

    # The cut-ins turn on and off each: Chains on, then Skills off, in the items' order.
    tell(tree, [[chains.node, "click"]])
    tell(tree, [[enemies.node, "click"]])
    tell(tree, [[skills.node, "click"]])
    check("the cut-ins after three clicks [on, state]", [on.call[2, 3], options.cut_ins], [[false, true, true], [:enemy, :chain]])

    # The mod sets both states back: the buttons follow.
    options.keys = :gamepad
    options.cut_ins = [:skill]
    frame
    Graphics.update
    check("the buttons after the mod set the states", on.call, [true, false, true, false, false])
  end
end
