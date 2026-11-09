#----------------------------------------------------------------
#  mods_browser_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Covered a Data mod, whose page has no Install and which a collection's install leaves out
#      Paulinchen  2026-11-07: Checked that the framework's update installs and then starts the game again
#                            - Greyed rows and choices with disabled:
#                            - Took a Title mod of no name as the example
#      Paulinchen  2026-11-06: Gave the mod with details the website as its source
#                            - Called the engine's classes by their names under UI::Engine
#                            - Counted the questions the question box of the UI layer asked
#      Paulinchen  2026-11-06: Covered the browser as components of the UI layer: the search asked of the DLL, the filter
#                              drawer, a mod's page as a dialog, the change box and the restart question with Later lit
#                            - Covered an install that ends after the browser closed
#                            - Opened the browser as the title's Mods box does, which hides the title's commands itself
#      Paulinchen  2026-11-04: Kept a few flows of the mod browser and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the mod browser and covered removing a mod
#                            - Noted the texts a canvas draws instead of those the game draws, which a text drawn before
#                              no longer reaches
#      Paulinchen  2026-11-01: Covered the browser of the 0.6.9.1 release: the bar and the mods picked as a whole, the cards
#                              and the rows in the order picked, the tabs, the view, the search, the Filters box, a mod's and
#                              a collection's page, the box of a change, upvotes only, and a move of the cursor that draws
#                              only two cards
#      Paulinchen  2026-10-31: Took the plain restart questions
#      Paulinchen  2026-10-30: Covered a mod used at the title that a collection turns off without a restart
#                            - Covered the facts and the sections a player checks before installing, the dialog of a mod's
#                              pages and an install turned off for a mod that conflicts with one that is on
#                            - Covered the upvotes on the rows and on the page, a vote, one taken back and a refused one,
#                              and the Ratings row
#                            - Covered the filter panel, its picks, the order and the view among them
#                            - Covered the mods and versions not available on the platform the game runs on
#                            - Covered the framework's update once the game closed
#                            - Created
#
#----------------------------------------------------------------

# Covers mods_browser.rbx, the mod browser on the UI layer, in a booted game against FakeTree, the
# DLL's mod management played by a state the test changes as C# would: a session from the title
# through the search, a mod's page, installs, a failed one, an update of a running mod, a removal
# and upvotes; the filter drawer; a collection; the framework's update and a mod of another
# platform; the warnings of a mod's page before installing; and a Data mod, installed by hand.

require_relative "mods_support"
require_relative "layer_support"

$sounds = []

# Finds an open top of the UI layer by its id.
#
# @param id [String] The id.
# @return [Object, nil] The top.
def top_of(id)
  Mod_Framework::UI::Engine::Layer.tops.reverse.find { |top| top.id == id && !top.closed }
end

# Finds the open browser: its component and its window's engine part.
#
# @return [Array] The component and the window.
def browser_window
  top = top_of("mf_browser")
  top ? [top.mount.component, top.root.engine] : [nil, nil]
end

# Tells the names of the mods the browser's cards or rows show.
#
# @param window [Object] The browser's window.
# @return [Array<String>] The names.
def shown_names(window)
  list = window.find(:mf_browser_cards) || window.find(:mf_browser_rows)
  list.rows.map { |row| row[:text] }
end

# Opens a mod's page as confirm on its card does.
#
# @param tree [FakeTree] The tree.
# @param window [Object] The browser's window.
# @param name [String] The mod's name.
def open_card(tree, window, name)
  list = window.find(:mf_browser_cards) || window.find(:mf_browser_rows)
  tell(tree, [[list.node, "submit", list.rows.index { |row| row[:text] == name }]])
end

# Finds the open page of a mod or a collection: its dialog's engine part.
#
# @return [Object, nil] The dialog, nil while no page is open.
def page_window
  top = top_of("mf_browser_page")
  top && top.root.engine
end

# Tells the id of the mod or the collection whose page is open.
#
# @return [String, nil] The id, nil while no page is open.
def page_item
  top = top_of("mf_browser_page")
  top && top.mount.component.item_id
end

# Presses a button of the open page by its text.
#
# @param tree [FakeTree] The tree.
# @param text [String] The button's text.
def press_page(tree, text)
  button = page_buttons.find { |each| each.text == text }
  tell(tree, [[button.node, "click"]])
end

# Tells the buttons of the open page.
#
# @return [Array<Object>] The buttons that show.
def page_buttons
  [:mf_browser_install, :mf_browser_remove, :mf_browser_upvote, :mf_browser_open_page, :mf_browser_back].map { |id| page_window.find(id) }.compact.select { |each| each.visible }
end

# Tells the question the question box asks now.
#
# @return [String, nil] The question.
def question
  Mod_Framework::UI::Engine::Confirm.instance_variable_get(:@question)
end

# A session from the title: the search, a mod's page, installs, an update of a running mod, a
# removal and upvotes.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $mods.find { |mod| mod["name"] == "Level_Cap" }["tag"] = "Framework"
  $browsed = fresh_browsed.merge("total" => 4, "picks" => 0)
  $browsed["mods"].find { |mod| mod["name"] == "Invasions" }.merge!("upvotes" => 3, "vote" => nil, "rate" => nil, "author" => "Ann")
  $asked = 0
  fake = with_mods_topics(tree_dll(tree))
  fake.answer("mods.describe") { |request| $requests << ["mods.describe", request]; { "lines" => ["Shows a map of the region."], "fetching" => false } }
  boot_tree(fake, :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    ui = Mod_Framework::UI
    frame
    serial = mods::Title.serial
    mods.open_browser(true)
    frame
    Graphics.update
    browser, window = browser_window
    check("the browser opens on the cards in the DLL's order, fetching again behind, with how many show",
          [shown_names(window), $requests.find { |request| request[0] == "mods.browse" }[1]["fetch"], window.find(:mf_browser_bar).children[0].children[1].text],
          [["Level Cap", "Invasions", "Map Display", "Party Sheet"], true, "4 mods"])

    # The search: the DLL is asked with what was typed and the cards show what it lets through.
    search = window.find(:mf_browser_search)
    $browsed = $browsed.merge("mods" => [$browsed["mods"][2]])
    tell(tree, [[search.node, "focus"], [search.node, "change", "map"]])
    check("typing asks the DLL for the search and shows what it lets through, with how many of all",
          [last_request("mods.browse")["search"], shown_names(window), window.find(:mf_browser_bar).children[0].children[1].text], ["map", ["Map Display"], "1 of 4"])
    tell(tree, [[search.node, "cancelled"], [search.node, "rest"]])
    $browsed = $browsed.merge("mods" => fresh_browsed["mods"])
    $browsed["mods"].find { |mod| mod["name"] == "Invasions" }.merge!("upvotes" => 3, "vote" => nil, "rate" => nil)
    mods::Browser.bump
    frame
    check("cancel in the search empties it and asks the DLL for every mod", [browser.search, last_request("mods.browse")["search"]], ["", ""])

    # A mod's page opens at once as a dialog over the cards; its description is fetched once as it
    # opens.
    $requests.clear
    open_card(tree, window, "Map Display")
    check("confirm on a card opens its page at once as a dialog, fetching its description once, the focus on its first button",
          [page_item, $requests.count { |request| request[0] == "mods.describe" }, tree.nodes[page_window.find(:mf_browser_install).node][:props]["autofocus"]],
          ["site:map-display", 1, true])

    # Installing a mod whose requirement is missing asks to install both, then the change box shows
    # how it goes and closes by itself.
    press_page(tree, "Install 1.0")
    answer(true)
    box = top_of("mf_browser_change")
    check("the change box shows what installs", [box && box.mount.component.class, mods::Browser.change[:text]],
          [mods::ModChangeBox, "Installing Party Sheet 1.0 and Map Display 1.0 . . ."])
    tell(tree, [[box.root.engine.node, "cancel"]])
    check("cancel waits for the change with the buzzer", [top_of("mf_browser_change").nil?, $sounds.last], [false, :buzzer])
    $dll.post("mods.installed", "installed" => ["Party_Sheet", "Map_Display"], "mod" => nil, "error" => nil, "moved" => [])
    frame
    check("the installed mods turn on, the box closes and the bar says what was done",
          [last_request("mods.set"), top_of("mf_browser_change"), browser.said], [{ "on" => { "Party_Sheet" => true, "Map_Display" => true } }, nil, ["Installed Map Display and Party Sheet.", nil]])

    # A failed install keeps the box with why and Close.
    browser.close_page
    frame
    open_card(tree, window, "Party Sheet")
    press_page(tree, "Install 1.0")
    $dll.post("mods.installed", "installed" => [], "mod" => "Party Sheet", "error" => "The website could not be reached.", "moved" => [])
    frame
    Graphics.update
    box = top_of("mf_browser_change")
    check("a failed install keeps the box open saying why, with Close", [box && mods::Browser.change, box && box.root.engine.find(:mf_browser_change_close).visible],
          [{ :text => "Nothing changed: Party Sheet could not be installed.", :failed => true }, true])
    box.root.engine.close(:script)
    browser.close_page
    frame

    # Updating a running mod asks to start the game again, Later lit; Later says so on the bar.
    open_card(tree, window, "Level Cap")
    press_page(tree, "Update to 1.1")
    $dll.post("mods.installed", "installed" => ["Level_Cap"], "mod" => nil, "error" => nil, "moved" => [])
    frame
    check("updating a running mod asks to start the game again, Later lit",
          [question, ui::Engine::Confirm.picked?], ["Level Cap 1.1 is installed. It runs once the game starts again. Start it again now?", false])
    answer(false)
    check("Later leaves the bar saying a restart waits", browser.said, ["Restart the game to load the changed mods.", :warning])
    press_page(tree, "Remove")
    answer(true)
    check("Remove removes the mod after asking", last_request("mods.remove"), { "ids" => ["site:level-cap"] })
    answer(false)
    browser.close_page
    frame

    # An upvote reads Upvoted in gold; a refused one says why.
    open_card(tree, window, "Invasions")
    press_page(tree, "Upvote")
    $browsed["mods"].find { |mod| mod["name"] == "Invasions" }.merge!("upvotes" => 4, "vote" => "up")
    $dll.post("mods.voted", "id" => "site:invasions", "vote" => "up", "error" => nil)
    frame
    Graphics.update
    upvote = page_window.find(:mf_browser_upvote)
    check("an upvote reads Upvoted in gold", [upvote.text, upvote.instance_variable_get(:@options)[:color], browser.said], ["Upvoted", :gold, ["Upvoted.", nil]])
    tell(tree, [[upvote.node, "click"]])
    $dll.post("mods.voted", "id" => "site:invasions", "vote" => "up", "error" => "RateLimited")
    frame
    check("a refused vote says why", browser.said, ["Too many upvotes from here for now. Try again later.", :error])

    # Closing while an install runs: the title's Mods box reads its badges, and the install that
    # ends later turns the mod on and opens nothing.
    browser.close_page
    frame
    open_card(tree, window, "Party Sheet")
    press_page(tree, "Install 1.0")
    window.close(:cancel)
    frame
    check("closing has the title's Mods box draw its badges anew, the page and the change box gone",
          [top_of("mf_browser"), mods::Title.serial > serial, top_of("mf_browser_page"), top_of("mf_browser_change")], [nil, true, nil, nil])
    asked = questions_asked
    $dll.post("mods.installed", "installed" => ["Party_Sheet"], "mod" => nil, "error" => "Map Display could not be installed.", "moved" => [])
    frame
    check("an install that ends after the browser closed, partly failed, turns the mod installed on and opens no box and no question",
          [last_request("mods.set"), top_of("mf_browser_change"), questions_asked], [{ "on" => { "Party_Sheet" => true } }, nil, asked])
  end
end

# The filter drawer: Filters opens it beside the cards, two across, kept for the next time; a box
# row picks; Order steps and is kept; Clear filters clears every pick.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  filters = { "categories" => [["quality-of-life", "Quality of Life", 2, false]], "games" => [["english", 2, false]], "languages" => [],
              "keywords" => (1..12).map { |place| ["word#{place}", "word#{place}", 1, false] }, "platform" => "pc", "own_platform" => "pc", "platforms" => %w[pc android any] }
  $browsed = fresh_browsed.merge("total" => 4, "picks" => 0, "filters" => filters)
  $asked = 0
  ini = "Patch/Mod_Framework/Mod_Framework.ini"
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    frame
    mods.open_browser(true)
    frame
    Graphics.update
    browser, window = browser_window
    cards = window.find(:mf_browser_cards)
    drawer = window.find(:mf_browser_filters)
    check("the drawer is shut as the browser first opens, the cards three across", [drawer.instance_variable_get(:@options)[:open], cards.columns], [false, 3])

    tell(tree, [[window.find(:mf_browser_filters_button).node, "click"]])
    Graphics.update
    rows = window.find(:mf_browser_filter_list)
    texts = rows.rows.map { |row| row[:heading] || row[:text] }
    check("Filters opens the drawer beside the cards, two across, kept for the next time",
          [drawer.instance_variable_get(:@options)[:open], cards.columns, $files[ini]["browser_filters_open"]], [true, 2, "on"])
    check("its rows: Clear filters, the values, a box per pick under its heading, ten keywords before More keywords",
          [texts.first(6), texts.last(2), rows.rows[0][:disabled], rows.rows[4].values_at(:checked, :right)],
          [["Clear filters", "Order", "Platform", "Categories", "Quality of Life", "Works with"], ["word10", "More keywords · 2"], true, [false, "2"]])

    $browsed = $browsed.merge("mods" => [$browsed["mods"][1]], "picks" => 1)
    tell(tree, [[rows.node, "submit", 4]])
    check("a box row picks at once and the badge counts the picks",
          [last_request("mods.browse")["picks"]["categories"], shown_names(window), window.find(:mf_browser_filters_button).instance_variable_get(:@options)[:badge]],
          [["quality-of-life"], ["Invasions"], 1])
    tell(tree, [[rows.node, "side", 1, 1]])
    check("Order steps on and is kept for the next time", [$files[ini]["browser_order"], last_request("mods.browse")["order"]], ["newest", "newest"])
    tell(tree, [[rows.node, "submit", rows.rows.size - 1]])
    check("More keywords shows the rest", rows.rows.size, texts.size + 1)

    $browsed = $browsed.merge("mods" => fresh_browsed["mods"], "picks" => 0)
    tell(tree, [[rows.node, "submit", 0]])
    check("Clear filters clears every pick", last_request("mods.browse")["picks"]["categories"], [])
    tell(tree, [[window.find(:mf_browser_filters_button).node, "click"]])
    check("Filters again shuts the drawer, the cards three across", [drawer.instance_variable_get(:@options)[:open], cards.columns], [false, 3])
  end
end

# A collection: Install and turn on installs what is missing, then asks whether to turn the other
# mods off; one of its mods opens that mod's page.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $browsed = fresh_browsed
  $asked = 0
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    frame
    mods.open_browser(true)
    frame
    Graphics.update
    browser, window = browser_window
    tell(tree, [[window.find(:mf_browser_tabs).node, "step", 1]])
    browser.shown_tab = mods::ModBrowser::COLLECTIONS_TAB
    frame
    tell(tree, [[window.find(:mf_browser_collections).node, "submit", 0]])
    tell(tree, [[page_window.find(:mf_browser_collection_install).node, "click"]])
    check("Install and turn on installs what the collection misses, naming the mods in use", last_request("mods.install"),
          { "ids" => ["site:party-sheet"], "running" => ["Core_Lib", "Discord"] })
    $browsed["collections"][0]["mods"][1].merge!("status" => "current", "installed" => "1.0", "on" => true)
    $dll.post("mods.installed", "installed" => ["Party_Sheet"], "mod" => nil, "error" => nil, "moved" => [])
    frame
    check("then asks whether to turn the other mods off", question, "6 other mods are on: Core Lib, Online Arena and 4 more. Turn them off so only this collection's mods run?")
    answer(false)
    tell(tree, [[page_window.find(:mf_browser_entries).node, "submit", 1]])
    check("one of its mods opens that mod's page on the Mods tab", [browser.shown_tab, page_item], [mods::ModBrowser::MODS_TAB, "site:party-sheet"])
  end
end

# A mod not available on this platform, and the framework's update.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $browsed = fresh_browsed
  $browsed["mods"].unshift(browsed_mod("mod-framework", "Mod Framework", "update", "tag" => "Framework", "framework" => true, "latest" => "0.1.1", "installed" => "0.1.0"))
  $browsed["mods"] << browsed_mod("phone-only", "Phone Only", "other_platform", "installed" => nil, "place" => "", "on" => nil, "latest" => "2.0", "bytes" => 0, "files" => 0, "notes" => [])
  $asked = 0
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    frame
    Mod_Framework::Mods.open_browser
    frame
    Graphics.update
    _browser, window = browser_window
    check("a mod of another platform shows faint on its card", window.find(:mf_browser_cards).rows.last[:faint], true)
    open_card(tree, window, "Phone Only")
    check("and cannot be installed", page_window.find(:mf_browser_install).enabled?, false)
    page_window.find(:mf_browser_back).emit(:click)
    frame
    open_card(tree, window, "Mod Framework")
    press_page(tree, "Update to 0.1.1")
    answer(true)
    installing = [last_request("mods.install")["ids"], Mod_Framework::Run.quitting?]
    $dll.post("mods.installed", "installed" => ["Mod_Framework"], "mod" => nil, "error" => nil)
    frame
    Mod_Framework::Run.closing(nil)
    check("the framework's update installs, then the game starts again", [*installing, last_request("mods.restart"), Mod_Framework::Run.quitting?],
          [["site:mod-framework"], false, { "action" => nil, "value" => nil }, true])
  end
end

# A mod's page in the Russian translation warns before installing, then installing it asks and
# installs it turned off.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $browsed = fresh_browsed
  details = { "save" => "new-game", "conflicts" => [["Old Map", "Both draw the map.", true, "Old_Map"]], "load_after" => ["Level Cap"], "load_before" => [],
              "known_issues" => ["Flickers on the world map."], "options" => [["[Map Display] Size", "How big."]], "hotkeys" => [["[Map Display] Open", "F7"]],
              "works_with" => ["english"], "languages" => ["English"], "categories" => ["Quality of Life"], "keywords" => ["map"], "credits" => [["Ann", "Art"]],
              "license" => ["MIT", "no", "with-credit"], "links" => [["source", "https://github.com/someone/map-display"]] }
  $browsed["mods"].find { |mod| mod["name"] == "Map Display" }.merge!("details" => details, "needs" => [], "source" => "site")
  $asked = 0
  russian = lambda do
    define_mods_game
    Object.class_eval("module Vocab; def self.new_game; \"Новая игра\"; end; end")
  end
  boot_tree(with_mods_topics(tree_dll(tree)), :game => russian) do
    Mod_Framework::Mods.open_browser
    frame
    Graphics.update
    _browser, window = browser_window
    open_card(tree, window, "Map Display")
    Graphics.update
    texts = page_window.find(:mf_browser_text).children.map { |label| label.text }
    check("the page warns first", texts.first(3), ["Does not work with Old Map, which is on", "Not made for the Russian translation", "Needs a new game"])
    press_page(tree, "Open page")
    links = top_of("mf_browser_links")
    tell(tree, [[links.root.engine.find(:mf_browser_link_source).node, "click"]])
    check("a link of the mod's pages opens", last_request("mods.page"), { "id" => "site:map-display", "link" => "source" })
    press_page(tree, "Install 1.0")
    answer(true)
    $dll.post("mods.installed", "installed" => ["Map_Display"], "mod" => nil, "error" => nil, "moved" => [])
    frame
    check("it installs turned off", last_request("mods.set"), { "on" => { "Map_Display" => false } })
  end
end

# A Data mod, which the player installs by hand: its page has no Install and says so, a mod that
# needs it installs alone and the bar names it, and a collection's install leaves it out and names
# it.
in_game_folder do
  tree = FakeTree.new
  $mods = fresh_mods
  $browsed = fresh_browsed
  $browsed["mods"] << browsed_mod("bigger-shops", "Bigger Shops", "available", "tag" => "Data", "by_hand" => true)
  $browsed["mods"].find { |mod| mod["name"] == "Map Display" }["needs"] = [["Bigger Shops", "", "missing", "", "", "site:bigger-shops"]]
  $browsed["collections"][0]["mods"] << { "slug" => "bigger-shops", "id" => "site:bigger-shops", "name" => "Bigger Shops", "version" => "1.0", "available" => true,
                                          "by_hand" => true, "status" => "available", "installed" => nil, "folder" => "Bigger_Shops", "on" => nil }
  $asked = 0
  boot_tree(with_mods_topics(tree_dll(tree)), :game => lambda { define_mods_game }) do
    mods = Mod_Framework::Mods
    frame
    mods.open_browser(true)
    frame
    Graphics.update
    browser, window = browser_window
    open_card(tree, window, "Bigger Shops")
    Graphics.update
    line = page_window.find(:mf_browser_by_hand)
    check("a Data mod's page has no Install and says it is installed by hand",
          [page_buttons.map { |button| button.text }, line.visible, line.text],
          [["Remove", "Upvote", "Open page", "Back"], true, "This mod is installed by hand from its page on the website."])
    browser.close_page
    frame

    open_card(tree, window, "Map Display")
    press_page(tree, "Install 1.0")
    installing = last_request("mods.install")["ids"]
    $dll.post("mods.installed", "installed" => ["Map_Display"], "mod" => nil, "error" => nil)
    frame
    check("a mod that needs the Data mod installs alone without asking, the bar and the log naming the Data mod",
          [installing, browser.said, $logged.grep(/leaves site:bigger-shops out of the install of site:map-display/).size],
          [["site:map-display"], ["Installed. It loads when you enter the game. Bigger Shops is installed by hand from its page on the website.", nil], 1])
    browser.close_page
    frame

    browser.shown_tab = mods::ModBrowser::COLLECTIONS_TAB
    frame
    tell(tree, [[window.find(:mf_browser_collections).node, "submit", 0]])
    entries = page_window.find(:mf_browser_entries)
    check("the collection names the Data mod to install by hand",
          [entries.rows.last.values_at(:right, :tooltip), page_window.find(:mf_browser_collection_by_hand).text],
          [["Install by hand", "Install it by hand from its page on the website."], "Install Bigger Shops by hand from its page on the website."])
    tell(tree, [[page_window.find(:mf_browser_collection_install).node, "click"]])
    check("Install and turn on leaves the Data mod out and logs it", [last_request("mods.install")["ids"], $logged.grep(/leaves site:bigger-shops out of the install of collection:story-plus/).size],
          [["site:party-sheet"], 1])
  end
end
