#----------------------------------------------------------------
#  settings_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked readable? for a missing file, a file that cannot be read and the game without the DLL
#                            - Removed the checks of the hand-over of a mod
#      Paulinchen  2026-11-04: Rewrote the checks as flow tests of reading, keeping and writing the settings
#      Paulinchen  2026-11-01: Handed settings over once per mod
#      Paulinchen  2026-10-31: Took the plain notice of settings that cannot be saved
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Covers settings.rbx against an ini stand-in on FakeBridge: a session that reads, changes and
# writes the settings, a file that cannot be read, a write that fails, and the game without the
# DLL.

require_relative "bridge_support"

load_scripts "logging", "hooks", "run", "bridge", "settings"
settings = Mod_Framework::Settings
log = []
Mod_Framework::Log.define_singleton_method(:write) { |line| log << line }

# The files the stand-in DLL keeps, by path; :unreadable for one that cannot be read.
files = {}
reads = []
writes = []
# Whether the stand-in DLL fails every write, as under a lock by an antivirus.
locked = false
fake = FakeBridge.new
fake.answer("ini.read") do |(path)|
  reads << path
  files[path] == :unreadable ? nil : (files[path] || {})
end
fake.answer("ini.write") do |(path, values)|
  next false if locked || files[path] == :unreadable

  writes << path
  files[path] = values
  true
end

# Starts a session: the DLL opened or missing, and nothing read yet.
#
# @param dll [Boolean] Whether the DLL works.
start = lambda do |dll|
  Mod_Framework.available = dll
  Mod_Framework.bridge.open(fake) if dll
  %w[@values @pending @failed_at @refused @noticed @read_at].each { |name| settings.instance_variable_set(name, nil) }
  settings.instance_variable_set(:@readable, false)
  reads.clear
  writes.clear
end

file = "Patch/Mod_Framework/Mod_Framework.ini"

# A session: the file is read once, changes are kept at once and written after the frame in one
# write, a kept setting moving to the end of the file.
start.call(true)
files[file] = { "ui_preset" => "Legacy", "ui_chat" => "1,2,3,4", "ui_notices" => "5,6,7,8" }
settings.setting("ui_preset")
check("the places under a prefix list in the order of the file", settings.keys_under("ui_"), %w[preset chat notices])
settings.store("ui_preset", "Monarch")
settings.forget("ui_chat")
settings.store("key_accept", 89)
settings.flush
settings.flush
check("the file is read once and written once", [reads, writes], [[file], [file]])
check("the written file keeps the untouched setting first", files[file],
      { "ui_notices" => "5,6,7,8", "ui_preset" => "Monarch", "key_accept" => "89" })

# With only the embedded copy installed the folder is missing; the DLL makes it on the first write.
files.clear
start.call(true)
settings.store("ui_preset", "Legacy")
settings.flush
check("a missing file reads as empty, its values known, and the first store writes it", [settings.readable?, files[file]], [true, { "ui_preset" => "Legacy" }])

# A key the file could not hold is refused with its whole change.
start.call(true)
check("a key holding = is refused", settings.store("a=b", "1"), false)
check("a change with one bad key keeps none of its keys",
      [settings.change("ui_preset" => "Monarch", " ui_chat" => "1"), settings.setting("ui_preset")], [false, "Legacy"])

# A file that exists but cannot be read is never written, and the player is told once.
files[file] = :unreadable
start.call(true)
log.clear
settings.setting("ui_preset")
settings.store("ui_preset", "Monarch")
check("an unreadable file is never written [values known, writes, file]", [settings.readable?, writes, files[file]], [false, [], :unreadable])
check("the player is told once", [settings.take_notice, settings.take_notice], [settings::NOTICE, nil])

# A failed write waits a second before the next frame tries again, but not as the game closes.
files[file] = {}
start.call(true)
locked = true
settings.store("ui_preset", "Monarch")
settings.flush
locked = false
check("the next frame waits before trying again", settings.flush, false)
check("the closing write tries at once", [settings.flush(true), files[file]], [true, { "ui_preset" => "Monarch" }])

# The run reads the settings as the game starts running, keeping what a mod changed while it
# loaded, writes after the frame and again as the game closes.
module Graphics; def self.update; end; end
files[file] = { "ui_preset" => "Legacy" }
start.call(true)
settings.store("ui_preset", "Early")
Mod_Framework::Run.begin_run
check("the run keeps a change a mod made while it loaded", settings.setting("ui_preset"), "Early")
Graphics.update
check("the frame after it writes the change", files[file], { "ui_preset" => "Early" })

# Without the DLL nothing is read or written and one line says so.
start.call(false)
log.clear
settings.setting("ui_preset")
settings.store("ui_preset", "Legacy")
check("without the DLL nothing is read or written [values known, reads, writes]", [settings.readable?, reads, writes], [false, [], []])
check("without the DLL one line says so", log, ["settings: without the DLL no setting is read or stored"])
