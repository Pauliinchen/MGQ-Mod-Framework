#----------------------------------------------------------------
#  command_parts_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed the checks of commands an adoption added
#      Paulinchen  2026-11-04: Kept the flow of gated commands and checked each outcome on its own
#                            - Rewrote the checks as flow tests of gated commands and options rows
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers the gates of commands in a booted game against FakeTree: a title command that shows only
# while its :if allows.

require_relative "game_lists_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    frame

    $copy_shown = false
    title = Window_TitleCommand.new
    Mod_Framework::Mods.title_command("Copy", :symbol => :copy_title, :if => lambda { $copy_shown })
    title.refresh
    check("a title command of a mod is hidden while its :if refuses", title.symbols.include?(:copy_title), false)
  end
end
