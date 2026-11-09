#----------------------------------------------------------------
#  mods_update_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that a needed update installs, then starts the game again, and tells a failed install
#                            - Removed the way by hand through Update.bat
#                            - Took a mod of no name as the example of a need
#      Paulinchen  2026-11-06: Told the end of a fetch without the relay's list
#                            - Noted the messages UI.message shows
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Checked each outcome of the updates and the needs of a mod on its own
#                            - Rewrote the checks as flow tests of the updates and the needs of a mod
#      Paulinchen  2026-10-31: Took the plain texts of a needed version
#      Paulinchen  2026-10-30: Checked that JoiPlay sends a needed update to the website
#                            - Checked how to run Update.bat by hand under Wine or Proton
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_update.rbx in a booted game against FakeTree: on_updates and the title's fetch; a
# mod's need met, declined, waiting for the lists, failing to install and updating with a restart;
# JoiPlay; and a need without the DLL.

require_relative "mods_support"

$sounds = []

# Answers a need of Level Cap as ModsTopics.Require does.
#
# @param state [String] "current", "update", "unavailable" or "unknown".
# @param offered [String, nil] The version an update brings.
# @return [Hash] The answer.
def need(state, offered = nil)
  { "state" => state, "id" => "site:level-cap", "name" => "Level Cap", "installed" => "0.6.9", "offered" => offered, "framework" => false }
end

# Shows a message box as the game's msgbox does, noting its text.
#
# @param text [String] The message.
def msgbox(text)
  $msgboxes << text
end

in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $asked = 0
  $fetching = true
  $required = {}
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    $messages = []
    Mod_Framework::UI.singleton_class.send(:define_method, :message) { |text, params = {}, &_closed| $messages << [params[:title], text]; nil }

    # on_updates hears of the updates once the fetch ended and again only once they change.
    told = []
    mods.on_updates("Test") { |updates| told << updates.map { |update| "#{update['name']} #{update['latest']}" } }
    frame
    $fetching = false
    2.times do
      $dll.post("mods.fetched", "site" => true)
      frame
    end
    $mods.find { |mod| mod["name"] == "Discord" }.merge!("update" => true, "latest" => "2.0")
    $dll.post("mods.fetched", "site" => true)
    frame
    check("on_updates hears of the updates again once they change", told.last, ["Discord 2.0", "Level Cap 1.1"])
    Object.class_eval("class Scene_Base; def post_start; end; end; class Scene_Title < Scene_Base; end")
    mods::Updates.install
    Scene_Title.new.post_start
    check("each title asks for the lists again", $requests.last, ["mods.updates", { "fetch" => true }])
    # A need the installed version meets, then one the lists meet, declined.
    results = []
    $required["level-cap"] = need("current")
    check("a need the installed version meets is current at once", mods.require("level-cap", "0.6.0") { |result| results << result }, :current)
    $required["level-cap"] = need("update", "0.7.0")
    mods.require("level-cap", "0.7.0", :reason => "This version cannot read the saves.") { |result| results << result }
    answer(false)
    check("a need the lists meet asks to update, and Back declines it", results.last, :declined)
    # JoiPlay, which cannot start the game again.
    Mod_Framework.instance_variable_set(:@platform, Mod_Framework::JOIPLAY)
    $msgboxes = []
    mods.require("level-cap", "0.7.0") { |result| results << result }
    check("JoiPlay sends a needed update to the website", [results.last, $msgboxes],
          [:unavailable, ["Level Cap 0.7.0 is needed. Install it from mgqonline.org and start the game again."]])
    Mod_Framework.instance_variable_set(:@platform, nil)
    # An exact need waits for the lists, then its install fails.
    $fetching = true
    $required["level-cap"] = need("unknown")
    check("a need waits while the lists are fetched", mods.require("level-cap", "0.6.8", :exact => true) { |result| results << result }, :waiting)
    $fetching = false
    $required["level-cap"] = need("update", "0.6.8")
    $dll.post("mods.fetched", "site" => true)
    frame
    answer(true)
    installed = last_request("mods.install")
    $dll.post("mods.installed", "installed" => [], "mod" => "Level Cap", "error" => "The website could not be reached.")
    frame
    check("an exact need installs that version, and a failed install tells why and the game goes on",
          [installed["versions"], $messages.last, results.last, Mod_Framework::Run.quitting?],
          [{ "site:level-cap" => "0.6.8" }, ["Update", "Level Cap could not be installed."], :failed, false])
    # Update and restart.
    $required["level-cap"] = need("update", "0.7.0")
    mods.require("level-cap", "0.7.0", :action => "level-cap.open") { |result| results << result }
    answer(true)
    $dll.post("mods.installed", "installed" => ["Level_Cap"], "mod" => nil, "error" => nil)
    frame
    Mod_Framework::Run.closing(nil)
    check("Update and restart installs it, then starts the game again with the action", [results.last, last_request("mods.restart"), Mod_Framework::Run.quitting?],
          [:restarting, { "action" => "level-cap.open", "value" => nil }, true])
  end
end

# Without the DLL a message names the version needed.
in_game_folder do
  tree = FakeTree.new
  $msgboxes = []
  boot_tree(tree_dll(tree), :dll => false, :game => lambda { define_game_lists }) do
    results = []
    Mod_Framework::Mods.require("level-cap", "0.7.0", :title => "Level Cap") { |result| results << result }
    check("without the DLL a message names the version needed", $msgboxes, ["Level Cap 0.7.0 is needed. Install it from mgqonline.org and start the game again."])
  end
end
