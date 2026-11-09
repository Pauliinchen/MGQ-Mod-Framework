#----------------------------------------------------------------
#  mods_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed the answer of the update through the helper
#                            - Took in the last request of a topic from the browser's test
#                            - Took a Title mod of no name as the example
#      Paulinchen  2026-11-06: Answered without the relay's list
#                            - Removed the answer of the framework's boot
#                            - Answered the question box by a click on its choice of the UI layer, and counted the questions it asked
#      Paulinchen  2026-11-01: Gave each mod its summary, dropped the player's retag and refused a change while $refuse says why,
#                              or in an answer that wrote Mods.ini while $written_refusals holds the refusals
#      Paulinchen  2026-10-30: Had the Discord mod name the title calls, so it still loads whole
#                            - Gave the MGQ Online mod a title command
#                            - Played the topics of the votes
#                            - Played the topics of the updates
#                            - Played the topics of the mod browser
#                            - Created
#
#----------------------------------------------------------------

# The installed mods and the DLL's mod management as the tests of the Mods screen and the title's
# row play them: a state of mods as ModsTopics.StateOf writes it, kept in $mods and changed as C#
# keeps the player's changes or refuses them while $refuse says why, or writes Mods.ini and refuses
# what $written_refusals holds, the updates of the mods marked so, the needs in $required by the
# mod's name, every request noted in $requests, and helpers that answer the question box and pick rows of the screen's list.

require_relative "game_lists_support"

# A mod of the state, as ModsTopics.StateOf writes one.
#
# @param name [String] Its name in Patch.
# @param tag [String] Its tag.
# @param options [Hash] Its other parts by name.
# @return [Hash] The mod.
def mod_state(name, tag, options = {})
  { "name" => name, "title" => name.tr("_", " "), "author" => "", "summary" => "", "source" => "site", "page" => false, "place" => "Patch",
    "tag" => tag, "tag_from" => "site", "on" => true, "version" => "1.0", "latest" => "1.0",
    "update" => false, "id" => "site:#{name.downcase}", "requires" => [], "needs" => [], "needed_by" => [], "warnings" => [] }.merge(options)
end

# The installed mods: a Framework mod, two Title mods and four Regular ones.
def fresh_mods
  [mod_state("Core_Lib", "Framework"),
   mod_state("Online_Arena", "Title", "title" => "Online Arena"),
   mod_state("Discord", "Title"),
   mod_state("Level_Cap", "Regular", "needed_by" => ["Map Display"], "update" => true, "latest" => "1.1"),
   mod_state("Map_Display", "Regular", "needs" => [["Level Cap", "1.0", "on", "1.0", "Level_Cap"]]),
   mod_state("Invasions", "Regular", "on" => false),
   mod_state("Skip_Intro", "Regular", "id" => nil, "source" => nil, "tag_from" => "default", "version" => "?", "latest" => nil)]
end

# A mod of the mod browser, as ModsTopics.BrowsedOf writes one.
#
# @param slug [String] Its slug on the website.
# @param name [String] Its name.
# @param status [String] "update", "current", "changed" or "available".
# @param options [Hash] Its other parts by name.
# @return [Hash] The mod.
def browsed_mod(slug, name, status, options = {})
  installed = status == "available" || status == "changed" ? nil : "1.0"
  { "id" => "site:#{slug}", "name" => name, "author" => "Someone", "source" => "site", "page" => true, "summary" => "#{name} does a thing.", "tag" => "Regular",
    "status" => status, "installed" => installed, "place" => status == "available" ? "" : "Patch", "folder" => name.tr(" ", "_"),
    "on" => status == "available" ? nil : true, "latest" => status == "update" ? "1.1" : "1.0", "bytes" => 2048, "files" => 2, "notes" => ["- Fixed a thing"],
    "picture" => "Patch/Mod_Framework/Cache/Thumbnails/#{slug}.png", "spoiler" => false, "picture_waits" => false, "framework" => false, "needs" => [] }.merge(options)
end

# What the mod browser shows: an update, an installed mod, two not installed (one needing the
# other) and a collection of both.
#
# @return [Hash] As ModsTopics.Browse answers.
def fresh_browsed
  { "fetching" => false, "pictures" => false, "site" => true, "collections_kept" => true,
    "mods" => [browsed_mod("level-cap", "Level Cap", "update", "tag" => "Title"),
               browsed_mod("invasions", "Invasions", "current", "spoiler" => true),
               browsed_mod("map-display", "Map Display", "available", "needs" => [["Party Sheet", "", "missing", "", "", "site:party-sheet"]]),
               browsed_mod("party-sheet", "Party Sheet", "available", "picture" => nil)],
    "collections" => [{ "slug" => "story-plus", "id" => "collection:story-plus", "name" => "Story Plus", "summary" => "A second run.", "author" => "Someone", "page" => true,
                        "mods" => [{ "slug" => "invasions", "id" => "site:invasions", "name" => "Invasions", "version" => "1.0", "available" => true, "status" => "current", "installed" => "1.0", "folder" => "Invasions", "on" => false },
                                   { "slug" => "party-sheet", "id" => "site:party-sheet", "name" => "Party Sheet", "version" => "1.0", "available" => true, "status" => "available", "installed" => nil, "folder" => "Party_Sheet", "on" => nil },
                                   { "slug" => "gone", "id" => nil, "name" => "gone", "version" => "1.0", "available" => false, "status" => "available", "installed" => nil, "folder" => nil, "on" => nil }] }] }
end

# Defines the game's lists and puts a script into Patch for each mod, Online Arena's with a title
# command, so it tells its title part from the rest; Discord's names the title calls but registers
# nothing, so it loads whole.
def define_mods_game
  define_game_lists
  FileUtils.mkdir_p("Patch")
  $mods.each { |mod| File.write("Patch/#{mod['name']}.rb", "") }
  File.write("Patch/Online_Arena.rb", "Mod_Framework::Mods.title_command(\"Arena\") { |window| window.activate }\n")
  File.write("Patch/Discord.rb", "Mod_Framework::Mods.on_enter(\"Discord\") { } if $discord_waits\n")
end

# Answers the mod management's topics from $mods as C# would keep the player's changes.
#
# @param fake [FakeBridge] The DLL's side.
# @return [FakeBridge] It.
def with_mods_topics(fake)
  $requests = []
  state = lambda { |extra| { "mods" => $mods, "fetching" => false, "site" => true, "ini" => true }.merge(extra) }
  fake.answer("mods.state") { |_request| state.call("fetching" => $fetching ? true : false) }
  fake.answer("mods.plan") { |_request| { "load" => $mods.select { |mod| mod["on"] }.map { |mod| [mod["name"], mod["tag"], mod["place"], mod["version"]] }, "warnings" => [] } }
  fake.answer("mods.set") do |request|
    $requests << ["mods.set", request]
    next state.call("written" => false, "refused" => request.values.map { |part| [Array(part).flatten.first, $refuse] }) if $refuse
    next state.call("written" => true, "refused" => $written_refusals) if $written_refusals

    (request["on"] || {}).each { |name, on| $mods.find { |mod| mod["name"] == name }["on"] = on }
    if request["order"]
      moved = request["order"].map { |name| $mods.find { |mod| mod["name"] == name } }
      places = moved.map { |mod| $mods.index(mod) }.sort
      places.each_with_index { |place, at| $mods[place] = moved[at] }
    end
    state.call("written" => true, "refused" => [])
  end
  fake.answer("mods.restart") { |request| $requests << ["mods.restart", request]; { "started" => true, "refused" => nil } }
  fake.answer("mods.browse") { |request| $requests << ["mods.browse", request] if request; $browsed || fresh_browsed }
  fake.answer("mods.describe") { |request| { "lines" => ["Caps the levels of the party."], "fetching" => false } }
  fake.answer("mods.install") { |request| $requests << ["mods.install", request]; { "started" => true, "refused" => nil } }
  fake.answer("mods.remove") { |request| $requests << ["mods.remove", request]; { "removed" => ["Level Cap"], "refused" => nil } }
  fake.answer("mods.page") { |request| $requests << ["mods.page", request]; { "opened" => true } }
  fake.answer("mods.vote") { |request| $requests << ["mods.vote", request]; { "started" => true, "refused" => nil } }
  fake.answer("mods.ratings") do |request|
    $requests << ["mods.ratings", request] if request
    $ratings_on = request["on"] if request
    { "on" => $ratings_on != false }
  end
  fake.answer("mods.updates") do |request|
    $requests << ["mods.updates", request] if request
    updates = $mods.select { |mod| mod["update"] }.map do |mod|
      { "id" => mod["id"], "name" => mod["title"], "folder" => mod["name"], "installed" => mod["version"], "latest" => mod["latest"], "framework" => false }
    end
    { "fetching" => $fetching ? true : false, "site" => true, "updates" => updates }
  end
  fake.answer("mods.require") { |request| $requests << ["mods.require", request]; ($required || {})[request["name"]] }
  fake
end

# Tells how many questions the question box asked since the game started.
#
# @return [Integer] The questions.
def questions_asked
  Mod_Framework::UI::Engine::Confirm.instance_variable_get(:@serial).to_i
end

# Tells the last request of a topic.
#
# @param topic [String] The topic.
# @return [Object] Its request.
def last_request(topic)
  found = $requests.reverse.find { |request| request[0] == topic }
  found && found[1]
end

# Answers the question box open as a click on one of its choices does.
#
# @param yes [Boolean] Whether the first choice is taken.
def answer(yes)
  choice = Mod_Framework::UI::Engine::Placement.find(yes ? "#confirm_box_yes" : "#confirm_box_no")
  choice.receive("click") if choice
  2.times do
    frame
    Graphics.update
  end
end

# Tells what the list shows: each heading, and each mod's name, box and note.
#
# @param list [Mod_Framework::UI::Engine::List] The list.
# @return [Array] The rows.
def shown(list)
  list.rows.map { |row| row[:heading] || [row[:text], row[:checked], row[:note]] }
end

# Picks a row of the list as confirm on it does.
#
# @param tree [FakeTree] The tree.
# @param list [Mod_Framework::UI::Engine::List] The list.
# @param text [String] The row's name.
def pick(tree, list, text)
  place = list.rows.index { |row| row[:text] == text }
  list.index = place
  tree.post("events", [[list.node, "submit", place]])
  frame
end

