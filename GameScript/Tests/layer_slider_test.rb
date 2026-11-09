#----------------------------------------------------------------
#  layer_slider_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Told the slider its new numbers as C#'s tree tells them, which moves it by the arrows and the pointer
#                            - Created
#
#----------------------------------------------------------------

# Covers slider of the UI layer (design v2 section 5.3) in a booted game against FakeTree, through
# a mod's sound box: the music volume bound to a state in steps of 10, which C#'s tree moves by the
# arrows, a click and a drag and tells each new number of, and the volume the mod sets reaching the
# tree, which fits it to the steps.

require_relative "layer_support"

SOUND_BOX = <<-RUBY
  module Sound_Box
    UI = Mod_Framework::UI

    class SoundWindow < UI::Component
      state :music, 60
      state(:told) { [] }

      def render
        window "Sound" do
          slider "Music volume", bind: :music, step: 10, on_change: ->(volume) { self.told = told + [volume] }
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Sound_Box.rb", SOUND_BOX)
    frame

    ui.open(Sound_Box::SoundWindow)
    frame
    Graphics.update
    sound = ui::Engine::Layer.tops.last.mount.component
    music = ui::Engine::Tree.component(nodes_of(tree, "slider").last)
    props = tree.nodes[music.node][:props]
    check("the volume as it opens [number, label above it, what the tree moves it by]",
          [music.value, music.parent.children.first.text, props.values_at("number", "number_min", "number_max", "number_step")],
          [60, "Music volume", [60, 0, 100, 10]])

    # The tree tells a new number, as Right or the pointer moved it: the state and on_change hear it.
    tell(tree, [[music.node, "number", 70]])
    check("the volume after the tree told 70 [state, told]", [sound.music, sound.told], [70, [70]])

    # The mod sets the volume: the tree is given it to fit to the steps.
    sound.music = 34
    frame
    Graphics.update
    check("the number given to the tree after the mod set 34", tree.nodes[music.node][:props]["number"], 34)
  end
end
