#----------------------------------------------------------------
#  boot_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked the waiting updates moved into place at the next start, after a crash too
#                            - Booted the embedded copy from a mod of no name
#      Paulinchen  2026-11-06: Removed the check of an install over the old name, which no release had
#      Paulinchen  2026-11-04: Kept the flows of the boot with one check per guard
#                            - Rewrote the checks as flow tests of the boot
#                            - Left the Tools folder out of the files that ship
#      Paulinchen  2026-10-31: Checked the files the web installer leaves for the stub
#      Paulinchen  2026-10-30: Checked the platform the framework finds
#      Paulinchen  2026-10-29: Checked that an install over the old name retires it
#      Paulinchen  2026-10-28: Checked that every script loads without the DLL
#                            - Created
#
#----------------------------------------------------------------

# Covers the boot: which installed copy the stub loads and which it skips, the waiting updates and
# the files the web installer left for it, the stub run twice, the loader with a working DLL, one of another build,
# one that refuses the handshake and none, and the shipped files.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"
EMBEDDED = "Patch/Camp_Notes/Mod_Framework"

# Boots a game folder through the game's loader and tells which copy loaded.
#
# @yield Installs the copies in the current game folder.
# @return [Array] The copy's folder, version and whether it has its DLL; nil when none loaded.
def picked
  in_game_folder do
    new_session
    install_stub
    yield
    run_patch_loader
    $booted_from.first
  end
end

# The pick: the newest copy, one with its DLL before one without, the standalone copy on a tie.
check("the stub loads the newest copy", picked { install_copy(STANDALONE, "0.1.0"); install_copy(EMBEDDED, "0.2.0") }, [EMBEDDED, "0.2.0", true])
check("a -dev build goes before its release",
      picked { install_copy(STANDALONE, "0.1.0"); install_copy(EMBEDDED, "0.1.0-dev") }, [EMBEDDED, "0.1.0-dev", true])
check("a copy with its DLL goes before a newer one without",
      picked { install_copy(STANDALONE, "0.3.0", :dll => false); install_copy(EMBEDDED, "0.1.0") }, [EMBEDDED, "0.1.0", true])
check("without any DLL the newest copy loads",
      picked { install_copy(STANDALONE, "0.3.0", :dll => false); install_copy(EMBEDDED, "0.1.0", :dll => false) }, [STANDALONE, "0.3.0", false])
check("the standalone copy wins a tie", picked { install_copy(EMBEDDED, "0.1.0"); install_copy(STANDALONE, "0.1.0") }, [STANDALONE, "0.1.0", true])

# What the pick skips: a folder with only the settings, a malformed Version.txt and a standalone
# copy of a higher major than every embedded one.
settings_only = picked do
  FileUtils.mkdir_p(STANDALONE)
  File.write("#{STANDALONE}/Mod_Framework.ini", "ui_preset=Legacy\n")
  install_copy(EMBEDDED, "0.1.0")
end
check("a folder holding only the settings is no copy", settings_only, [EMBEDDED, "0.1.0", true])
malformed = picked { install_copy(STANDALONE, "0.1.0"); install_copy(EMBEDDED, "\xEF\xBB\xBFnew!\r\n") }
check("a malformed Version.txt is skipped and noted",
      [*malformed, Mod_Framework::Boot.notes.grep(%r{\Askipped #{EMBEDDED}: its Version.txt holds "new!"}).size], [STANDALONE, "0.1.0", true, 1])
higher = picked { install_copy(STANDALONE, "1.0.0"); install_copy(EMBEDDED, "0.4.0") }
check("a standalone copy of a higher major than the embedded ones is skipped and noted",
      [*higher, Mod_Framework::Boot.notes.grep(/skipped the standalone copy 1\.0\.0/).size], [EMBEDDED, "0.4.0", true, 1])
check("a standalone copy of a higher major loads when it is alone", picked { install_copy(STANDALONE, "1.0.0") }, [STANDALONE, "1.0.0", true])
check("a Version.txt with a byte order mark reads", picked { install_copy(STANDALONE, "\xEF\xBB\xBF0.2.0\r\n") }, [STANDALONE, "0.2.0", true])

# The web installer left a .web file and .remove markers; the stub finishes them under Patch before the pick.
in_game_folder do
  new_session
  install_stub
  install_copy(STANDALONE, "0.1.0", :dll => false)
  File.binwrite("#{STANDALONE}/ModFramework.dll.web", "new library")
  FileUtils.mkdir_p("Patch/Old_Mod")
  File.write("Patch/Old_Mod/Old.dll", "old")
  File.write("Patch/Old_Mod/Old.dll.remove", "")
  File.write("Patch/Gone.lnk.remove", "")
  FileUtils.mkdir_p("Data")
  File.write("Data/Outside.dll.web", "kept")
  run_patch_loader
  check("the .web file takes its place before the pick, the named files go with their markers, a .web file outside Patch stays",
        [*$booted_from.first, Dir.glob("Patch/**/*.{web,remove}").size, File.exist?("Patch/Old_Mod/Old.dll"), File.exist?("Data/Outside.dll.web")],
        [STANDALONE, "0.1.0", true, 0, false, true])
end

# The waiting folder, which the DLL fills and the stub empties.
WAITING = "Patch/Mod_Framework/Waiting"

# Writes the waiting folder as the DLL leaves it: each waiting file under its number, then the list.
#
# @param lines [Array<String>] The list's lines.
# @param files [Hash{String => String}] Each waiting file's bytes by its number.
def put_waiting(lines, files)
  FileUtils.mkdir_p(WAITING)
  files.each { |number, bytes| File.binwrite("#{WAITING}/#{number}", bytes) }
  File.binwrite("#{WAITING}/Waiting.txt", lines.map { |line| "#{line}\n" }.join)
end

# An update of the framework and of a mod waited; the next start moves them into place before the
# pick, while the game that just closed still holds the old DLL for a moment.
in_game_folder do
  new_session
  install_stub
  install_copy(STANDALONE, "0.1.0")
  File.write("Patch/Camp_Notes.rb", "# old")
  FileUtils.mkdir_p("Patch/Camp_Notes")
  File.write("Patch/Camp_Notes/dropped.txt", "dropped")
  put_waiting(["mod\tMod Framework\t0.2.0", "file\t0\tPatch/Mod_Framework/Version.txt", "file\t1\tPatch/Mod_Framework/ModFramework.dll",
               "mod\tCamp Notes\t1.1", "file\t2\tPatch/Camp_Notes.rb", "file\t3\tPatch/Camp_Notes/Pages/first.txt", "remove\tPatch/Camp_Notes/dropped.txt",
               "file\t4\t../Escape.rb"],
              "0" => "0.2.0", "1" => "new library", "2" => "# new", "3" => "page", "4" => "escaped")
  held = File.open("#{STANDALONE}/ModFramework.dll", "rb")
  closing = Thread.new { sleep(0.5); held.close }
  run_patch_loader
  closing.join
  check("the waiting updates move into place before the pick, a file held for a moment included, and the folder goes",
        [*$booted_from.first, File.binread("#{STANDALONE}/ModFramework.dll"), File.read("Patch/Camp_Notes.rb"), File.read("Patch/Camp_Notes/Pages/first.txt"),
         File.exist?("Patch/Camp_Notes/dropped.txt"), File.exist?("Escape.rb") || File.exist?("../Escape.rb"), File.exist?(WAITING), Dir.glob("Patch/**/*.old")],
        [STANDALONE, "0.2.0", true, "new library", "# new", "page", false, false, false, []])
  check("the boot log names each mod moved with its version and files, and the line it skipped",
        File.binread("Logs/Mod Framework boot.log").scan(/  (moved .*|skipped the line .*)\r$/).flatten,
        ["skipped the line \"file\\t4\\t../Escape.rb\" of #{WAITING}/Waiting.txt", "moved Mod Framework 0.2.0 into place: 2 files, 0 removed",
         "moved Camp Notes 1.1 into place: 2 files, 1 removed"])
end

# A start that ended halfway through the move: the first file is in place, the second was moved
# aside but not yet replaced; the next start finishes the move.
in_game_folder do
  new_session
  install_stub
  install_copy(STANDALONE, "0.2.0")
  FileUtils.mkdir_p("Patch/Camp_Notes")
  File.write("Patch/Camp_Notes/core.rb.old", "# old core")
  File.write("Patch/Camp_Notes.rb", "# new")
  put_waiting(["mod\tCamp Notes\t1.1", "file\t0\tPatch/Camp_Notes.rb", "file\t1\tPatch/Camp_Notes/core.rb"], "1" => "# new core")
  run_patch_loader
  check("the next start finishes a move cut short",
        [File.read("Patch/Camp_Notes.rb"), File.read("Patch/Camp_Notes/core.rb"), File.exist?(WAITING), $patch_errors], ["# new", "# new core", false, []])
end

# Without any copy the stub loads nothing, never reaches the game's error box and says why.
in_game_folder do
  new_session
  install_stub
  run_patch_loader
  check("without any copy nothing loads and the boot log says why",
        [$booted_from.size, $patch_errors.size, File.read("Logs/Mod Framework boot.log").include?("did not boot: RuntimeError: no copy is installed")], [0, 0, true])
end

# The stub run by the game's loader and by a mod that ships a copy, twice each; then that mod alone.
in_game_folder do
  new_session
  install_stub
  install_copy(STANDALONE, "0.1.0")
  install_copy(EMBEDDED, "0.1.0")
  locals = TOPLEVEL_BINDING.local_variables
  run_patch_loader
  boot_from_mod("Patch/!Mod_Framework.rb")
  boot_from_mod("#{EMBEDDED}/boot.rbx")
  run_patch_loader
  check("a stub run four times loads the copy once, raises nothing and leaves no local in the binding every mod shares",
        [$booted_from.size, $patch_errors.size, TOPLEVEL_BINDING.local_variables == locals], [1, 0, true])
  new_session
  FileUtils.rm_rf("Patch")
  install_copy(EMBEDDED, "0.1.0")
  boot_from_mod("#{EMBEDDED}/boot.rbx")
  check("without a stub a mod boots its embedded copy through its boot.rbx", $booted_from, [[EMBEDDED, "0.1.0", true]])
end

# Boots the repository's loader with a DLL and runs the game.
#
# @param dll [FakeBridge, nil] What the DLL answers, nil for no DLL file.
# @return [Hash] :booted, :available, :log (its own lines), :errors (the loader's), :ran (whether a part
#   that needs no DLL ran) and :ini (whether the settings file was written).
def real_boot(dll)
  in_game_folder do
    new_session
    $dll = dll
    install_stub
    install_copy(STANDALONE, "0.1.0", :real => true, :dll => !dll.nil?)
    run_patch_loader
    $ran_without_dll = false
    Mod_Framework::Run.on_start("a part without the DLL") { $ran_without_dll = true }
    SceneManager.run
    { :booted => Mod_Framework.booted?, :available => Mod_Framework.available?, :log => own_log, :errors => $patch_errors, :ran => $ran_without_dll,
      :ini => File.exist?(Mod_Framework::Settings::FILE) }
  end
end

# With its DLL the framework boots and logs through the DLL; then the platform it finds.
good = FakeBridge.new
good.build = "0.1.0"
logged = []
good.answer("log.write") { |(_time, line)| logged << line; nil }
good.answer("log.flush") { |_request| nil }
good.answer("ini.read") { |_request| {} }
booted = real_boot(good)
check("with its DLL the framework boots, the DLL works and the log goes through it",
      [booted[:booted], booted[:available], booted[:errors].size, booted[:log].size, logged.include?("Mod Framework 0.1.0 from Patch/Mod_Framework on Ruby #{RUBY_VERSION}, platform windows")],
      [true, true, 0, 0, true])
platforms = [[{ "ntdll.dll" => 1, "wine_get_version" => 2 }, nil], [nil, true], [{}, nil]].map do |kernel32, joiplay|
  $kernel32, $joiplay = kernel32, joiplay
  Mod_Framework.find_platform
end
$kernel32 = $joiplay = nil
check("the platform is Wine by its export and JoiPlay by its mark or by Win32API answering 0", platforms, %w[wine joiplay joiplay])

# A DLL of another build, one that refuses the handshake, and none.
other = FakeBridge.new
other.build = "0.2.0"
other_build = real_boot(other)
check("a DLL of another build than Version.txt counts as no DLL, the log naming both builds",
      [other_build[:available], other_build[:log].grep(/ModFramework\.dll is build 0\.2\.0, but Version\.txt names 0\.1\.0/).size], [false, 1])
refused = real_boot(FakeBridge.new(Mod_Framework::Bridge::VERSION + 1))
check("after a refused handshake the framework boots and what needs no DLL runs",
      [refused[:booted], refused[:available], refused[:errors].size, refused[:ran], refused[:log].grep(/without the DLL these stay off: bridge frame/).size],
      [true, false, 0, true, 1])
missing = real_boot(nil)
check("without the DLL file every script loads, the run runs, nothing writes the settings and one line says the DLL is missing",
      [missing[:booted], missing[:errors].size + missing[:log].grep(/scripts that did not load/).size, missing[:ran], missing[:ini], missing[:log].grep(/DLL/).first],
      [true, 0, true, false, "runs without its DLL: Patch\\Mod_Framework\\ModFramework.dll is missing, so its windows, boxes and fields stay closed"])

in_game_folder do
  new_session
  install_copy(STANDALONE, "0.1.0-dev", :real => true, :dll => false)
  boot_from_mod("#{STANDALONE}/boot.rbx")
  check("at_least? counts a -dev build as its release", [Mod_Framework.at_least?("0.1.0"), Mod_Framework.at_least?("0.1.1")], [true, false])
end

# The shipped files.
stub = File.binread(STUB)
header = /\A(#[^\n]*\n)+\r?\n/
check("boot.rbx holds the stub's code byte for byte", File.binread(File.join(FRAMEWORK_DIR, "boot.rbx")).sub(header, ""), stub.sub(header, ""))
shipped = Dir.glob(File.join(GAME_SCRIPT_DIR, "*")).map { |path| File.basename(path) }.sort - ["Tests", "Tools"]
check("the stub is ASCII and alone in Patch beside the copy's folder", [stub.bytes.all? { |byte| byte < 0x80 }, *shipped], [true, "!Mod_Framework.rb", "Mod_Framework"])
inside = Dir.glob(File.join(FRAMEWORK_DIR, "**", "*")).grep(/\.(rb|ini)\z/i)
scripts = [STUB, File.join(FRAMEWORK_DIR, "boot.rbx"), File.join(FRAMEWORK_DIR, "loader.rbx")] + Dir.glob(File.join(SCRIPTS_DIR, "*.rbx"))
check("the copy's folder holds no .rb or settings, and no script names an Encoding constant, which the game lacks",
      inside + scripts.select { |file| File.read(file, :encoding => "UTF-8").include?("Encoding::") }, [])
