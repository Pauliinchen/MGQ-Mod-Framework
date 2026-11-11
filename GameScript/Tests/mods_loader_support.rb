#----------------------------------------------------------------
#  mods_loader_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Read the database through load_normal_database as the game does
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Game folders holding mods for the tests of the loader: the game's scenes and DataManager's ways
# into the game as far as the loader follows them, mods put into Patch with Mods.ini, and a boot
# through one of the game's loaders without the DLL.

require_relative "game_lists_support"

# Defines the game's scenes and DataManager's ways into the game as far as the loader follows them:
# the title with its command window, New Game, the load of a save and the translation's load of an
# autosave, and the database's read through load_normal_database, counting what they do.
def define_scenes
  [:Scene_AutoSave_Load, :Scene_Load, :Scene_File, :Scene_Title, :Scene_Base].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
  Object.class_eval <<-RUBY
    class Scene_Base; def post_start; end; end
    class Scene_Title < Scene_Base
      attr_reader :command_window
      def start; create_command_window; end
      def create_command_window
        @command_window = Window_TitleCommand.new
        @command_window.set_handler(:new_game, method(:command_new_game))
      end
      def command_new_game; DataManager.setup_new_game; end
    end
    class Scene_File < Scene_Base; def on_savefile_ok; end; end
    class Scene_Load < Scene_File; def on_savefile_ok; super; DataManager.load_game(0); end; end
    class Scene_AutoSave_Load < Scene_Load; def on_savefile_ok; DataManager.load_game("01"); end; end
    module DataManager
      def self.load_database; load_normal_database; end
      def self.load_normal_database; $database_reads += 1; end
      def self.setup_new_game; $new_games += 1; end
      def self.load_game(index); $loads << index; load_game_without_rescue(index); end
    end
  RUBY
  $order = []
  $database_reads = 0
  $new_games = 0
  $loads = []
  $level_cap_set_up = 0
end

# Puts mods into the current game folder's Patch, without the framework.
#
# @param mods [Hash{String => String}] Each file's path in Patch and its code.
# @param ini [String] What Mods.ini holds.
def put_mods(mods, ini)
  new_session
  define_game_lists
  define_scenes
  $dll = nil
  FileUtils.mkdir_p("Patch/Mod_Framework")
  File.write("Patch/Mod_Framework/Mods.ini", ini)
  mods.each do |path, code|
    FileUtils.mkdir_p(File.dirname("Patch/#{path}"))
    File.write("Patch/#{path}", code)
  end
end

# Boots a game folder holding mods through a game's loader, without the DLL.
#
# @param mods [Hash{String => String}] Each file's path in Patch and its code.
# @param ini [String] What Mods.ini holds.
# @param loader [Symbol] :english for the English translation's loader, :russian for the Russian
#   one's, :installer for the one the website's installer writes into the untranslated game.
def boot_with_mods(mods, ini, loader = :english)
  put_mods(mods, ini)
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => false)
  case loader
  when :russian then run_russian_loader
  when :installer then run_installer_loader
  else run_patch_loader
  end
end
