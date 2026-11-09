#----------------------------------------------------------------
#  boot_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Booted the framework as any mod that ships a copy does
#      Paulinchen  2026-11-01: Wrote the lines of Mods.ini without the mark of a tag the player gave
#      Paulinchen  2026-10-30: Ran the loader the website's installer writes for the untranslated game
#                            - Ran the Russian translation's loader
#                            - Put a mod into Patch with its tag
#      Paulinchen  2026-10-28: Made the game's windows anew for each session
#                            - Stood in for the game's Input and screen size
#                            - Created
#
#----------------------------------------------------------------

# Game folders for the tests of the boot: copies of the framework installed where the game finds
# them, the game's own loader over the Patch folder, and a new game session in the same process.

require_relative "bridge_support"
require_relative "game_support"

# A loader that only notes which copy the stub picked, for the tests of the pick.
NOTING_LOADER = <<-RUBY
  ($booted_from ||= []) << [Mod_Framework::Boot.folder, Mod_Framework::Boot.version, Mod_Framework::Boot.dll?]
  module Mod_Framework; def self.booted?; true; end; end
RUBY

# Stands in for the error the game raises when the player presses F12.
class RGSSReset < Exception; end

# Installs the stub as Patch/!Mod_Framework.rb in the current game folder.
def install_stub
  FileUtils.mkdir_p("Patch")
  FileUtils.cp(STUB, "Patch/!Mod_Framework.rb")
end

# Puts a mod's script into the current game folder's Patch with its line of Mods.ini, so it loads
# at the stage of its tag: a Framework mod as the game starts running, before what waits for the run.
#
# @param name [String] The mod's name, its script's without .rb.
# @param code [String] Its script.
# @param tag [String] Its tag.
def put_mod(name, code, tag = "Framework")
  FileUtils.mkdir_p("Patch/Mod_Framework")
  File.write("Patch/#{name}.rb", code)
  File.open("Patch/Mod_Framework/Mods.ini", "ab") { |file| file.write("#{name}=on #{tag}\n") }
end

# Installs a copy of the framework in the current game folder.
#
# @param folder [String] The copy's folder, such as "Patch/Camp_Notes/Mod_Framework".
# @param version [String, nil] What its Version.txt holds, nil for no Version.txt.
# @param options [Hash] :dll (false for a copy without its DLL), :real (true for the repository's
#   loader and scripts instead of NOTING_LOADER).
def install_copy(folder, version, options = {})
  FileUtils.mkdir_p(folder)
  File.write("#{folder}/Version.txt", version) if version
  File.write("#{folder}/ModFramework.dll", "") unless options[:dll] == false
  FileUtils.cp(File.join(FRAMEWORK_DIR, "boot.rbx"), folder)
  if options[:real]
    FileUtils.cp(File.join(FRAMEWORK_DIR, "loader.rbx"), folder)
    FileUtils.cp_r(SCRIPTS_DIR, folder)
  else
    File.write("#{folder}/loader.rbx", NOTING_LOADER)
  end
end

# Starts a new game session in this process: no framework loaded, and the game's run, frame,
# Input, windows and DataManager as the game has them before any mod follows them, with no button
# pressed.
def new_session
  define_game_windows
  Mod_Framework::Mods::Hold.stop if defined?(Mod_Framework::Mods::Hold)
  Object.send(:remove_const, :Mod_Framework) if defined?(Mod_Framework)
  Object.send(:remove_const, :SceneManager) if defined?(SceneManager)
  Object.send(:remove_const, :Graphics) if defined?(Graphics)
  Object.send(:remove_const, :Input) if defined?(Input)
  Object.class_eval <<-RUBY
    module SceneManager
      def self.run; $scenes.call; end
    end
    module Graphics
      def self.update; end
      def self.width; 640; end
      def self.height; 480; end
    end
    module Input
      def self.update; end
      def self.trigger?(button); false; end
      def self.press?(button); false; end
      def self.repeat?(button); false; end
      def self.dir4; 0; end
      def self.dir8; 0; end
    end
  RUBY
  $booted_from = []
  $scenes = lambda { nil }
end

# Runs the game's own loader, the English translation's Patch/Patch.rb, which the untranslated game
# takes too: every .rb under Patch in byte order, each evaluated inside the loop's block. An error
# goes into $patch_errors, as the game shows it in a box.
def run_patch_loader
  $patch_errors = []
  Dir.glob("Patch/**/*.rb").sort.each do |filepath|
    next if File.basename(filepath).downcase == "patch.rb"

    begin
      s = File.read(filepath, encoding: "BOM|UTF-8")
      eval(s, nil, filepath)
    rescue Exception => e
      $patch_errors << "#{filepath}: #{e.class}: #{e.message}"
    end
  end
end

# Runs the Russian translation's own Patch/Patch.rb: the scripts at the top of Patch in byte order,
# each read without a byte order mark's strip and evaluated without a file name or a rescue.
def run_russian_loader
  Dir.entries("Patch").sort.each do |filename|
    if filename && filename.match(/(?<!^Patch)\.rb$/i)
      s = File.read("Patch/" + filename)
      eval(s)
    end
  end
end

# Runs the loader the website's installer writes into a game folder without one, such as the
# untranslated game's, whose own Patch.rb loads nothing: every .rb under Patch in byte order, the
# byte order mark stripped, each evaluated at the top level and rescued.
def run_installer_loader
  $patch_errors = []
  Dir.glob("Patch/**/*.rb").sort.each do |filepath|
    next if File.basename(filepath).downcase == "patch.rb"

    begin
      eval(File.read(filepath, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, filepath)
    rescue Exception => e
      $patch_errors << "#{filepath}: #{e.class}: #{e.message}"
    end
  end
end

# Runs the stub or boot.rbx as a mod that ships a copy boots the framework at the top of its script.
#
# @param file [String] The file, relative to the game folder.
def boot_from_mod(file)
  eval(File.read(file, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, file)
end

# Reads the framework's own log of the day, which it writes without its DLL.
#
# @return [Array<String>] Its lines without their time.
def own_log
  path = Dir.glob("Logs/Mod Framework 2*.log").first
  path ? File.binread(path).force_encoding("UTF-8").split("\r\n").map { |line| line.sub(/\A\d\d:\d\d:\d\d  \[script\] /, "") } : []
end
