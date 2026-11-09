#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Stood in for the platform, Windows unless a test sets another
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# What every test file shares: checks that count and report, and loading the framework's scripts
# outside RGSS. Each test file runs in a Ruby process of its own (see run.rb), since each brings its
# own stand-ins for the game.

require "fileutils"
require "tmpdir"

# The repository's GameScript folder.
GAME_SCRIPT_DIR = File.expand_path("..", __dir__)

# The stub, shipped as Patch/!Mod_Framework.rb.
STUB = File.join(GAME_SCRIPT_DIR, "!Mod_Framework.rb")

# The folder of a copy's files, shipped as Patch/Mod_Framework.
FRAMEWORK_DIR = File.join(GAME_SCRIPT_DIR, "Mod_Framework")

# Folder of the framework's scripts in the repository.
SCRIPTS_DIR = File.join(FRAMEWORK_DIR, "Scripts")

# Counts a test file's checks and reports them once the file ends.
module Checks
  @count = 0
  @failures = 0

  # Compares a value with the expected one and prints the result.
  #
  # @param label [String] What is checked.
  # @param actual [Object] What came out.
  # @param expected [Object] What should have.
  def self.check(label, actual, expected)
    @count += 1
    ok = actual == expected
    @failures += 1 unless ok
    puts "#{ok ? 'ok  ' : 'FAIL'} #{label}#{ok ? '' : ": #{actual.inspect} (expected #{expected.inspect})"}"
  end

  # Prints how many checks ran and how many failed, and ends the process with 1 when one failed.
  #
  # @param error [Exception, nil] What stopped the file early, nil when it ran to its end.
  def self.finish(error)
    stopped = error && !error.is_a?(SystemExit) ? ", stopped by #{error.class}: #{error.message}" : ""
    puts "#{@count} checks, #{@failures.zero? ? 'all passed' : "#{@failures} FAILED"}#{stopped}"
    exit(1) unless @failures.zero?
  end
end

at_exit { Checks.finish($!) }

# Checks a value, see Checks.check.
#
# @param label [String] What is checked.
# @param actual [Object] What came out.
# @param expected [Object] What should have.
def check(label, actual, expected)
  Checks.check(label, actual, expected)
end

# Stands in for what loader.rbx gives the scripts: whether the DLL works and where the game runs,
# which a test sets.
def stand_in_loader
  Object.class_eval <<-RUBY
    module Mod_Framework
      def self.available?; @available == true; end
      def self.available=(on); @available = on; end
      WINDOWS = "windows"
      JOIPLAY = "joiplay"
      def self.platform; @platform || WINDOWS; end
      def self.platform=(name); @platform = name; end
    end
  RUBY
end

# Loads framework scripts by name, in the order given, over a stand-in for loader.rbx.
#
# @param names [Array<String>] The scripts without their extension, such as "hooks".
def load_scripts(*names)
  stand_in_loader unless defined?(Mod_Framework) && Mod_Framework.respond_to?(:available?)
  names.each { |name| load File.join(SCRIPTS_DIR, "#{name}.rbx") }
end

# Collects the lines a block writes into the framework's log, then lets the log write as before.
#
# @yield The block whose log lines are collected.
# @return [Array<String>] The lines.
def logged_lines
  lines = []
  writer = Mod_Framework::Log.method(:write)
  Mod_Framework::Log.define_singleton_method(:write) { |line| lines << line; nil }
  begin
    yield
  ensure
    Mod_Framework::Log.define_singleton_method(:write, writer)
  end
  lines
end

# Runs a block in a new empty game folder, which it is the current folder for.
#
# @yield The block.
def in_game_folder
  Dir.mktmpdir do |game|
    Dir.chdir(game) { yield }
  end
end
