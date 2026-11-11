#----------------------------------------------------------------
#  mods_loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Covered a script an update renamed, which moved in after the game's loader listed Patch
#                            - Covered scripts loaded late through Mods.load_late
#                            - Had Level_Cap wrap load_normal_database, as the Unified Bugfix Module does
#      Paulinchen  2026-11-09: Covered a script in Patch/Patch, which is logged and named in a message
#                            - Covered a release folder extracted into Patch, which is no mod
#      Paulinchen  2026-11-06: Covered a mod that calls the old UI, which stops at its NameError and is named in a message
#      Paulinchen  2026-11-04: Kept a few flows of loading the mods and checked each outcome on its own
#                            - Rewrote the checks as flow tests of loading the mods
#      Paulinchen  2026-11-01: Wrote the lines of Mods.ini without the mark of a tag the player gave
#      Paulinchen  2026-10-30: Took its helpers from mods_loader_support.rb and had its whole Title mod name the title calls
#                            - Covered the title part and the rest of a Title mod
#                            - Covered a folder mod under either loader
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_loader.rbx in a booted game without the DLL, the order coming from Mods.ini: a game
# session from the boot through the title to New Game with the traps of a late load and a script
# loaded late after it, a folder mod under the Russian translation's loader, a world that leaves
# the other mods out, a Title mod that embeds the framework, a script an update renamed at the
# start, a mod that calls a name the framework no longer has, and mods extracted into Patch/Patch
# and into a release folder's Patch inside Patch.

require_relative "mods_loader_support"
require_relative "tree_support"

# The mods of the first game, each script's path in Patch and its code.
MODS = {
  "Core.rb" => <<-RUBY,
    $order << "Core"
  RUBY
  "Menu.rb" => <<-RUBY,
    $order << "Menu"
    $menu_folder = Mod_Framework::Mods.folder
    Mod_Framework::Mods.title_command("Menu") do |_window|
      $part = Mod_Framework::Mods.load_part("Parts/heavy.rbx")
      $part_again = Mod_Framework::Mods.load_part("Parts/heavy.rbx")
    end
    Mod_Framework::Mods.on_enter("Menu") { $order << "Menu entered"; $later_folder = Mod_Framework::Mods.folder }
  RUBY
  "Menu/Parts/heavy.rbx" => <<-RUBY,
    $order << "Menu part"
  RUBY
  "Broken.rb" => <<-RUBY,
    raise "broken on purpose"
  RUBY
  "Hero.rb" => <<-RUBY,
    $order << "Hero"
    $hero_file = __FILE__
    class Scene_Title
      alias hero_command_new_game command_new_game
      def command_new_game; $hero_chosen = true; hero_command_new_game; end
    end
  RUBY
  "Hero/hero_data.rb" => <<-RUBY,
    $order << "Hero data"
  RUBY
  "Level_Cap.rb" => <<-RUBY
    $order << "Level_Cap"
    class << SceneManager
      alias level_cap_run run
      def run; $level_cap_set_up += 1; level_cap_run; end
    end
    class << DataManager
      alias level_cap_load_normal_database load_normal_database
      def load_normal_database; level_cap_load_normal_database; $level_cap_notes = true; end
    end
  RUBY
}

# The order and tags of the first game's mods.
MODS_INI = "Core=on Framework\nMenu=on Title\nBroken=on Regular\nHero=on Regular\nLevel_Cap=on Regular\n"

# A script loaded once the game runs, outside the framework's loading, that wraps SceneManager.run
# and the database's read as Level_Cap does.
LATE_SCRIPT = <<-RUBY
  $late_set_up = 0
  class << SceneManager
    alias late_run run
    def run; $late_set_up += 1; late_run; end
  end
  class << DataManager
    alias late_load_normal_database load_normal_database
    def load_normal_database; late_load_normal_database; $late_notes = true; end
  end
RUBY

# A game session: the boot holds the mods back, the title loads the Framework and Title mods, a
# Title mod's command loads its part, New Game loads the rest through the traps of a late load, and
# a script loaded late afterwards goes through the same traps.
in_game_folder do
  boot_with_mods(MODS, MODS_INI)
  mods = Mod_Framework::Mods
  check("while the game's loader runs every mod is held back in its order", [$order, mods::Hold.held.first(2)], [[], %w[Patch/Broken.rb Patch/Core.rb]])
  $scenes = lambda do
    title = Window_TitleCommand.new
    title.call_handler(:mods_menu_menu)
    check("a Title mod's command loads its part once", [$part, $part_again], [true, false])
    $order << "New Game"
    Scene_Title.new.command_new_game
    $runs_after = Mod_Framework::Run.runs
  end
  SceneManager.run
  check("New Game runs the on_enter blocks, then loads the Regular mods with the scripts in their folders", $order,
        ["Core", "Menu", "Menu part", "New Game", "Menu entered", "Hero", "Hero data", "Level_Cap"])
  check("a failing mod is named with why while the others go on", [mods.failed["Broken"].include?("Patch/Broken.rb: RuntimeError: broken on purpose"), mods.loaded],
        [true, %w[Core Menu Hero Level_Cap]])
  check("a wrapper of SceneManager.run sets up once without counting as a run", [$level_cap_set_up, $runs_after], [1, 1])
  check("the database is read again once for a mod that wrapped load_normal_database", [$database_reads, $level_cap_notes], [1, true])
  check("New Game runs again for a mod that wrapped it while the game is set up once", [$hero_chosen, $new_games], [true, 1])
  ran = false
  mods.on_enter("late") { ran = true }
  check("once entered an on_enter block runs at once and entering again does nothing", [ran, mods.enter("again")], [true, false])
  run = SceneManager.singleton_class.instance_method(:run)
  reads = $database_reads
  value = mods.load_late("a server's battle") { eval(LATE_SCRIPT, TOPLEVEL_BINDING, "Late.rb"); 1 }
  check("a script loaded late sets its SceneManager.run wrapper up once, the database is read again for its wrap, and the real run is back",
        [$late_set_up, $database_reads - reads, $late_notes, SceneManager.singleton_class.instance_method(:run) == run, value], [1, 1, true, true, 1])
end

# Under the Russian translation's loader a folder mod, a folder of scripts in Patch with no script
# of its name, loads its scripts sorted.
in_game_folder do
  boot_with_mods({ "Texts/b.rb" => "$order << 'Texts b'\n", "Texts/a/a.rb" => "$order << 'Texts a'\n", "Hero.rb" => "$order << 'Hero'\n" }, "", :russian)
  $scenes = lambda { Scene_Title.new.command_new_game }
  SceneManager.run
  check("a folder mod loads its scripts sorted by path", $order, ["Hero", "Texts a", "Texts b"])
end

# A Framework mod, a Title mod that tells its title part from the rest, a Title mod that does not,
# and a Regular mod.
TITLE_MODS = {
  "Core.rb" => "$order << 'Core'\n",
  "Menu.rb" => <<-RUBY,
    $order << "Menu title part"
    Mod_Framework::Mods.on_enter("Menu") { $order << "Menu rest" }
  RUBY
  "Whole.rb" => "$order << 'Whole'\nMod_Framework::Mods.on_enter('Whole') { } if $whole_waits\n",
  "Plain.rb" => "$order << 'Plain'\n"
}

# A world that leaves the other mods out, then New Game at the title that came back.
in_game_folder do
  boot_with_mods(TITLE_MODS, "Core=on Framework\nMenu=on Title\nWhole=on Title\nPlain=on Regular\n")
  mods = Mod_Framework::Mods
  $scenes = lambda do
    mods.enter("a world without mods", :only => [])
    check("a world without mods loads neither a Title mod's rest nor a Regular mod, so its title needs no restart",
          [$order, mods.restart_needed?], [["Core", "Menu title part", "Whole"], false])
    Scene_Title.new.post_start
    Scene_Title.new.command_new_game
  end
  SceneManager.run
  check("New Game at the title that came back loads the rest, after which the title restarts", [$order, mods.restart_needed?],
        [["Core", "Menu title part", "Whole", "Menu rest", "Plain"], true])
end

# A Title mod that embeds the framework and boots it, between Alpha and Zed.
EMBEDDING = <<-RUBY
  $order << "Online"
  eval(File.read("Patch/Online/Mod_Framework/boot.rbx", encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, "Patch/Online/Mod_Framework/boot.rbx") unless defined?(Mod_Framework)
RUBY

# A Title mod that embeds the framework boots it once, the mod before it runs once and the mod
# after it waits.
in_game_folder do
  put_mods({ "Alpha.rb" => "$order << 'Alpha'\n", "Online.rb" => EMBEDDING, "Zed.rb" => "$order << 'Zed'\n" }, "Online=on Title\n")
  install_copy("Patch/Online/Mod_Framework", "0.1.0", :real => true, :dll => false)
  run_patch_loader
  SceneManager.run
  check("a Title mod that embeds the framework runs once, as does the mod before it, and the mod after waits", [$order, $patch_errors], [%w[Alpha Online], []])
end

# An update that renames its script waited for Restart now; the stub moves it in after the game's
# loader listed the folder, so the loader never reads the new script and New Game loads it.
in_game_folder do
  put_mods({ "Rarity.rb" => "$order << 'Rarity 1.0'\n" }, "Rarity=on Regular\n")
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => false)
  put_waiting(["mod\tRarity\t1.1", "file\t0\tPatch/0_Rarity.rb", "remove\tPatch/Rarity.rb"], "0" => "$order << 'Rarity 1.1'\n")
  run_patch_loader
  $scenes = lambda { Scene_Title.new.command_new_game }
  SceneManager.run
  check("a script renamed by an update moved in at the start loads at New Game, not as one the game's loader ran",
        [$order, Mod_Framework::Mods.loaded, $patch_errors], [["Rarity 1.1"], ["0_Rarity"], []])
end

# A mod that calls the old UI stops at the NameError with the DLL running: it loads nothing, the
# others go on, and the next scene names it in a message.
in_game_folder do
  put_mods({ "Old_Ui.rb" => "Mod_Framework::UI::Window.new\n$order << 'Old UI'\n", "Hero.rb" => "$order << 'Hero'\n" }, "Old_Ui=on Regular\nHero=on Regular\n")
  Object.class_eval("module SceneManager; def self.scene; $scene_now; end; end")
  $scene_now = :map
  $dll = tree_dll(FakeTree.new)
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true)
  run_patch_loader
  $scenes = lambda do
    Scene_Title.new.command_new_game
    Scene_Base.new.post_start
    frame
  end
  SceneManager.run
  notice = Mod_Framework::UI::Engine::Placement.find("#message_box_text")
  check("a mod that calls the old UI loads nothing, its NameError is kept with its file and line, and a message names it",
        [$order, Mod_Framework::Mods.loaded, Mod_Framework::Mods.failed_last("Old_Ui").start_with?("Patch/Old_Ui.rb: NameError:"), notice && notice.text],
        [["Hero"], ["Hero"], true, "Old_Ui did not load."])
end

# A mod extracted into Patch instead of the game folder sits in Patch/Patch, or in the Patch of a
# release folder there: no script of either loads or makes a mod, each is logged with its path, and
# the next scene names both folders in a message.
in_game_folder do
  put_mods({ "Patch/Hero.rb" => "$order << 'Hero'\n", "MGQ-Online-0.7/Patch/Online.rb" => "$order << 'Online'\n" }, "")
  Object.class_eval("module SceneManager; def self.scene; $scene_now; end; end")
  $scene_now = :map
  $logged = []
  $dll = tree_dll(FakeTree.new)
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true)
  run_patch_loader
  $scenes = lambda do
    Scene_Base.new.post_start
    frame
  end
  SceneManager.run
  notice = Mod_Framework::UI::Engine::Placement.find("#message_box_text")
  check("a script in Patch/Patch does not load, is logged with its path, and a message names the folder",
        [$order, $logged.any? { |line| line.include?("Patch/Patch/Hero.rb lies in a Patch folder inside Patch") }, notice && notice.text],
        [[], true, "Some files are in Patch\\MGQ-Online-0.7\\Patch, Patch\\Patch and do not load. Extract mod and framework zips into the game folder, the one with Game.exe."])
  check("a release folder whose scripts lie only in its own Patch folder is no mod", Mod_Framework::Mods.plan_from_ini["load"], [])
end
