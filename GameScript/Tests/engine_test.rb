#----------------------------------------------------------------
#  engine_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that UI no longer stands for the engine's names
#      Paulinchen  2026-11-04: Checked the engine's old names in two checks
#                            - Rewrote the checks as one flow test of the engine's old names
#                            - Checked the names in one check
#                            - Created
#
#----------------------------------------------------------------

# Covers the engine's namespace in a booted game: the engine's classes live under UI::Engine and
# UI stands for none of them, so an old call such as UI::Window.new fails; UI keeps its own Game
# and the names of the new layer; and a window the framework makes through the engine opens and
# takes its parts, also beside the game's own top-level Container module.

require_relative "tree_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { Object.const_set(:Container, Module.new) unless Object.const_defined?(:Container) }) do
    ui = Mod_Framework::UI
    frame
    old = [:Window, :Label, :Tick, :Layout, :Style, :Pad].map do |name|
      begin
        ui.const_get(name, false)
      rescue NameError
        nil
      end
    end
    check("the engine's classes live under UI::Engine and UI stands for none of them, keeping its own Game and the new layer's names",
          [ui::Engine::Window.name, old.compact, ui::Game.name, ui::Component.name],
          ["Mod_Framework::UI::Engine::Window", [], "Mod_Framework::UI::Game", "Mod_Framework::UI::Component"])
    window = ui::Engine::Window.new(:title => "Engine")
    label = window.add_label("Kept")
    window.open
    frame
    check("a window made through the engine opens with its parts",
          [label.class, window.open?, tree.nodes[window.node][:kind]], [ui::Engine::Label, true, "window"])
    window.close
  end
end
