#----------------------------------------------------------------
#  mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Loaded the loader, which names the mods in use to an install
#      Paulinchen  2026-11-04: Took in the install's flows of mods_install_test.rb and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the plan with and without the DLL
#      Paulinchen  2026-11-01: Covered a new mod as Regular without the DLL, whatever its folder holds
#                            - Wrote the lines of Mods.ini without the mark of a tag the player gave
#      Paulinchen  2026-10-30: Covered the tag a new mod declares without the DLL
#                            - Covered a mod's page
#                            - Covered the plan without the DLL, which names no versions
#                            - Created
#
#----------------------------------------------------------------

# Covers mods.rbx and mods_install.rbx: the mods of Patch and the plan from Mods.ini without the
# DLL, the requests through the DLL, and an install refused or started.

require_relative "bridge_support"

load_scripts "logging", "hooks", "run", "bridge", "mods", "mods_loader", "mods_install"
mods = Mod_Framework::Mods
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }

# Without the DLL the mods are the scripts and folders of Patch, and the plan follows Mods.ini.
Mod_Framework.available = false
in_game_folder do
  FileUtils.mkdir_p("Patch/Menu/Parts")
  FileUtils.mkdir_p("Patch/Mod_Framework")
  %w[Zed alpha Level_Cap Menu a=b !Mod_Framework Patch].each { |name| File.write("Patch/#{name}.rb", "# #{name}\n") }
  File.write("Patch/Menu/Parts/part.rb", "# part\n")
  FileUtils.mkdir_p("Patch/Extras")
  File.write("Patch/Extras/extra.rb", "# extra\n")
  File.write("Patch/Mod_Framework/Mods.ini", "Menu=on Title\nlevel_cap=on Regular\nZed=off Regular\nGone=on Regular\n")
  check("the mods leave out the loader, the framework and a name Mods.ini cannot hold", mods.names, %w[alpha Extras Level_Cap Menu Zed])
  check("the plan follows Mods.ini by tag, a new mod last as Regular", mods.plan["load"].map { |entry| entry.first(2) },
        [%w[Menu Title], %w[Level_Cap Regular], %w[alpha Regular], %w[Extras Regular]])
  check("without the DLL a change is refused", mods.set("on" => { "Zed" => true }), nil)
end

# Without the DLL an install is refused at once.
told = []
mods.install(["site:level-cap"]) { |installed, error| told << [installed, error] }
check("an install without the DLL does not start and says why at once", told, [[[], Mod_Framework::Mods::Install::NO_DLL_TEXT]])

requests = []
fake = FakeBridge.new
fake.answer("mods.plan") { |request| requests << ["mods.plan", request]; { "load" => [["Own", "Regular", "Patch"]], "warnings" => [] } }
fake.answer("mods.state") { |request| requests << ["mods.state", request]; { "mods" => [], "fetching" => true } }
fake.answer("mods.set") { |request| requests << ["mods.set", request]; { "mods" => [], "written" => true, "refused" => [] } }
fake.answer("mods.page") { |request| requests << ["mods.page", request]; { "opened" => true } }
fake.answer("mods.install") do |request|
  requests << ["mods.install", request]
  next { "started" => false, "refused" => "site:gone is not available right now." } if request["ids"].include?("site:gone")

  { "started" => true, "refused" => nil }
end
Mod_Framework.available = true
Mod_Framework.bridge.open(fake)

# With the DLL the plan, the state, a change and a mod's page cross the bridge.
mods.plan
mods.state
mods.set("on" => { "Own" => false })
mods.open_page("site:level-cap")
check("each request crosses the bridge", requests.map { |name, _request| name }, %w[mods.plan mods.state mods.set mods.page])

# An install the DLL refuses says why at once.
told = []
mods.install(["site:gone"]) { |installed, error| told << [installed, error] }
check("an install the DLL refuses says why at once", told, [[[], "site:gone is not available right now."]])

# An install tells its progress and how it ended once; a failed one names the mod.
steps = []
told = []
mods.install(["site:level-cap", "site:map-display"], :progress => lambda { |done, total, name| steps << [done, total, name] }) do |installed, error|
  told << [installed, error]
end
fake.post("mods.installing", "done" => 1, "total" => 2, "mod" => "Map Display")
2.times { fake.post("mods.installed", "installed" => ["level-cap", "map-display"], "mod" => nil, "error" => nil) }
Mod_Framework.bridge.frame
check("the progress is told", steps, [[1, 2, "Map Display"]])
check("the end is told once", told, [[["level-cap", "map-display"], nil]])
told = []
mods.install(["site:map-display"]) { |installed, error| told << [installed, error] }
fake.post("mods.installed", "installed" => [], "mod" => "Map Display", "error" => "The website could not be reached.")
Mod_Framework.bridge.frame
check("a failed install names the mod and leaves why to the log", told, [[[], "Map Display could not be installed."]])
