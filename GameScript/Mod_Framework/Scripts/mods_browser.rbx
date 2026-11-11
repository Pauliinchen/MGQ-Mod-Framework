#----------------------------------------------------------------
#  mods_browser.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Left turning a collection on, the mods it keeps on, the needs an install brings and finding a mod by
#                              a name to the DLL
#                            - Named the card lines by rows_shown: and the page links' pick by on_submit
#      Paulinchen  2026-11-09: Said on the bar when an upvote could not start
#      Paulinchen  2026-11-08: Left the mods installed by hand out of Update all, a collection's install and the install of a mod's needs, and named them on the bar and in the log
#      Paulinchen  2026-11-07: Highlighted the text searched for in the names on the cards
#                            - Moved the filter drawer and the pages of a mod into files of their own
#                            - Installed the framework's update with the others and started the game again once it was in
#                            - Left the way back from the filter rows to the Filters button to the cancel rule
#                            - Marked the greyed Clear filters row with :disabled
#                            - Named Options > Mods in the log texts
#      Paulinchen  2026-11-06: Stopped asking for the restart of an update by the split of plain Title scripts
#                            - Stopped naming the relay and GitHub as the sources of mods, now that the website is the only one
#                            - Drew the browser as components of the UI layer, with the filters in a drawer at the left
#                              that the player opens and shuts, the cards two across beside it, the page of a mod as a
#                              dialog over the cards and the change box with its progress bar
#                            - Left Mods.ini alone to an install that ends after the browser closed, which asks nothing
#                            - Searched the mods and the collections in the DLL
#                            - Asked whether to start the game again with Later lit
#                            - Left hiding the title's commands to the title's Mods box that opens the browser
#      Paulinchen  2026-11-05: Read the mods that are on anew after a removal
#      Paulinchen  2026-11-04: Built the text panel and the page picture on the engine's component
#      Paulinchen  2026-11-01: Brought back the browser of the 0.6.9.1 release: the bar with the tabs, the view, Update all,
#                              Refresh, the search typed in place and the Filters button over the cards three across and two
#                              down or the list of six rows, picked as a whole before moving inside, and a full page of the
#                              mod or collection in place of the cards
#                            - Showed the mods in the order picked, without grouping them by whether they are installed
#                            - Upvoted mods only, and named the option Upvotes
#                            - Fetched a mod's description only as its page opens
#                            - Told how a change goes in a box in the middle and what happened last on the bar
#                            - Left the confirm sound to the title commands that open the browser
#                            - Followed no change of the mods when F12 closes the browser
#      Paulinchen  2026-10-31: Told the browser's states and questions in plain words
#      Paulinchen  2026-10-30: Asked for a restart when a split plain Title script is updated
#                            - Asked for no restart when a used Title mod is removed or turned off
#                            - Told the save safety, conflicts, load order, known issues, options, hotkeys, games,
#                              languages, categories, credits, license and links of a mod in the pane, opened its links
#                              and asked before installing a mod that does not work with one that is on
#                            - Showed the upvotes of each mod and voted from the page, and offered the ratings as a row of
#                              the framework's options
#                            - Filtered, searched and ordered the mods
#                            - Told how to run Update.bat by hand under Wine or Proton
#                            - Named the mods and versions not available on the platform the game runs on
#                            - Updated the framework once the game closed, then started the game again
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The topic that lists what the mod browser shows.
    BROWSE_TOPIC = "mods.browse"

    # The topic that turns a collection on.
    COLLECTION_ON_TOPIC = "mods.collection_on"

    # The topic that tells a mod's description.
    DESCRIBE_TOPIC = "mods.describe"

    # The topic that removes mods.
    REMOVE_TOPIC = "mods.remove"

    # The event once the images of the mods were cached.
    PICTURES_TOPIC = "mods.pictures"

    # The event once a description's fetch ended.
    DESCRIBED_TOPIC = "mods.described"

    # The topic that upvotes a mod or takes the upvote back.
    VOTE_TOPIC = "mods.vote"

    # The event once a vote ended.
    VOTED_TOPIC = "mods.voted"

    # The topic that tells whether the player upvotes mods, and turns it on or off.
    RATINGS_TOPIC = "mods.ratings"

    # The kinds of the game a mod works with, as the website names them.
    GAME_KINDS = %w[english russian untranslated]

    # Lists what the mod browser shows: the mods of the website the picks of the
    # filters and the search let through, in the order asked, what the filters offer and the
    # website's collections, see ModsTopics.BrowseTopic.
    #
    # @param fetch [Boolean] Whether to fetch the lists again first; the answer comes from the
    #   cache at once, and mods.fetched tells once the fetch ended.
    # @param query [Hash, nil] {"order", "search", "picks", "find"}, see ModsTopics.BrowseTopic;
    #   nil for every mod by name.
    # @return [Hash, nil] {"fetching", "pictures", "site", "collections_kept", "total",
    #   "collections_total", "picks", "filters", "mods", "updates", "collections"}, and "found" for
    #   a "find"; nil without the DLL.
    def self.browsed(fetch = false, query = nil)
      return nil unless Mod_Framework.available?

      request = query ? query.dup : {}
      request["fetch"] = true if fetch
      Mod_Framework.bridge.call(BROWSE_TOPIC, request.empty? ? nil : request)
    end

    # Turns a collection on: its installed mods on, each tag's of them in its order, in one write
    # of Mods.ini, see ModsTopics.CollectionOnTopic.
    #
    # @param id [String] The collection's id, such as "collection:story-plus".
    # @return [Hash, nil] The state after it, see set, with "others" => [[name, title], ...]: the
    #   mods that are on beside the collection's and those they need; nil without the DLL.
    def self.collection_on(id)
      @on_names = nil
      Mod_Framework.available? ? Mod_Framework.bridge.call(COLLECTION_ON_TOPIC, "id" => id) : nil
    end

    # Tells which game runs, as the website's "works with" names it, by the words of the title's
    # commands and the loader's version: Cyrillic for the Russian translation, Japanese for the
    # untranslated game, else the English translation.
    #
    # @return [String] "english", "russian" or "untranslated".
    def self.game_kind
      return @game_kind if @game_kind

      texts = [$patch_ver]
      texts += [:new_game, :continue, :shutdown].map { |name| ::Vocab.respond_to?(name) ? ::Vocab.send(name) : nil } if defined?(::Vocab)
      codes = texts.compact.map { |text| text.to_s.dup.force_encoding("UTF-8") }.select { |text| text.valid_encoding? }.join.unpack("U*")
      @game_kind = if codes.any? { |code| code >= 0x400 && code <= 0x4FF } then GAME_KINDS[1]
                   elsif codes.any? { |code| (code >= 0x3040 && code <= 0x30FF) || (code >= 0x4E00 && code <= 0x9FFF) } then GAME_KINDS[2]
                   else GAME_KINDS[0]
                   end
    rescue => e
      log("could not tell which game runs: #{Logging.failure(e)}")
      GAME_KINDS[0]
    end

    # Tells a mod's description, fetching it from the website unless it is known or told not to;
    # mods.described tells once a fetch ended.
    #
    # @param id [String] The mod's id.
    # @param fetch [Boolean] Whether to fetch it while it is not known; false only reads it.
    # @return [Hash, nil] {"lines" => [line, ...] or nil while it is not known, "fetching"}; nil
    #   without the DLL.
    def self.describe(id, fetch = true)
      Mod_Framework.available? ? Mod_Framework.bridge.call(DESCRIBE_TOPIC, "id" => id.to_s, "fetch" => fetch ? true : false) : nil
    end

    # Upvotes a mod of the website with this install, or takes its upvote back; mods.voted tells
    # how it ended.
    #
    # @param id [String] The mod's id.
    # @param vote [String, nil] "up"; nil takes the upvote back.
    # @return [Hash, nil] {"started", "refused" => why not, or nil}; nil without the DLL.
    def self.vote(id, vote)
      Mod_Framework.available? ? Mod_Framework.bridge.call(VOTE_TOPIC, "id" => id.to_s, "vote" => vote) : nil
    end

    # Tells whether the player upvotes mods from the Mod browser.
    #
    # @return [Boolean] Whether upvotes are on; off without the DLL.
    def self.ratings_on?
      answer = Mod_Framework.available? ? Mod_Framework.bridge.call(RATINGS_TOPIC, nil) : nil
      answer.is_a?(Hash) && answer["on"] ? true : false
    end

    # Turns the player's upvotes on or off; off has the website forget this game's key and upvotes.
    #
    # @param on [Boolean] Whether the player upvotes mods.
    # @return [Boolean] Whether upvotes are on now.
    def self.turn_ratings(on)
      answer = Mod_Framework.available? ? Mod_Framework.bridge.call(RATINGS_TOPIC, "on" => on ? true : false) : nil
      log("upvotes are #{on ? 'on' : 'off'}")
      answer.is_a?(Hash) && answer["on"] ? true : false
    end

    # The Upvotes row of the framework's options: On upvotes mods from the Mod browser with this
    # game's install key, Off upvotes none and has the website forget this game's upvotes.
    module Ratings
      # The Options > Mods row's key, kept from when the row was named Ratings.
      OPTION = :mf_mod_ratings

      # The Options > Mods row's name.
      OPTION_NAME = "Upvotes"

      # The Options > Mods row's help.
      OPTION_HELP = "On: the Mod browser can upvote mods.\nOff: no upvotes, and the website forgets this game's upvotes."

      # The Options > Mods row's values.
      ON = "On"
      OFF = "Off"

      # Offers Upvotes as a row of Options > Mods, among the framework's own.
      def self.add_option
        added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, lambda { [ON, OFF] },
                             lambda { Mods.ratings_on? ? ON : OFF }, lambda { |value| Mods.turn_ratings(value == ON) })
        Mods.log("no upvotes row in Options > Mods, see the options lines") unless added
      end

      Run.on_start("ratings", :dll => true) { Mod_Framework::Mods::Ratings.add_option }
    end

    # Removes the installed versions of mods: their files that are still exactly that version's,
    # and their folders once empty.
    #
    # @param ids [Array<String>] The mods' ids.
    # @return [Hash, nil] {"removed" => [name, ...], "refused" => why for the player, or nil}; nil
    #   without the DLL.
    def self.remove(ids)
      forget_on_names
      Mod_Framework.available? ? Mod_Framework.bridge.call(REMOVE_TOPIC, "ids" => Array(ids).map { |id| id.to_s }) : nil
    end

    # Opens the mod browser from the title.
    #
    # @param quiet [Boolean] Whether what opened it played the confirm sound, such as the title's
    #   Mods box, so the browser plays none.
    # @return [Object, nil] The browser's handle, nil without the DLL.
    def self.open_browser(quiet = false)
      Browser.open(nil, quiet)
    end

    # Opens the mod browser on a mod's page, such as the update or a missing requirement of a mod;
    # a browser open already shows that mod's page.
    #
    # @param mod [String] The mod's id, else a name a requirement names it by.
    # @return [Object, nil] The browser's handle, nil without the DLL.
    def self.browse(mod)
      Browser.open(mod, false)
    end

    # What the mod browser keeps between its openings and shares with the parts it opens: the
    # player's order, view, picks of the filters and whether the filters are open, the
    # descriptions fetched, the browser open now and the change that runs. The DLL's events reach
    # the browser through it.
    module Browser
      # The setting that keeps the view the player left the mods in.
      VIEW_SETTING = "browser_view"

      # The setting that keeps the order the player left the mods in.
      ORDER_SETTING = "browser_order"

      # The setting that keeps whether the player left the filters open.
      FILTERS_SETTING = "browser_filters_open"

      # The orders the filters offer, each by the DLL's name with its text, see ModBrowse.Orders.
      ORDERS = [["updated", "Recently updated"], ["newest", "Newest"], ["downloads", "Most downloaded"], ["rating", "Most upvoted"], ["name", "Name"]]

      # The order before the player picks one.
      FIRST_ORDER = "updated"

      # The groups of picks, as the DLL takes them.
      PICK_GROUPS = %w[categories keywords languages games]

      # The views of the mods, as the setting keeps them; cards before the player picks.
      CARDS = "cards"
      LIST = "list"

      # The player's picks of the filters in this game session, nil before the first.
      @picks = nil

      # How often what the browser shows changed: a fetch, the pictures, a description, a pick.
      @serial = 0

      # The lines of each description fetched in this game session, by the mod's id, or :failed.
      @descriptions = {}

      # The browser open now, nil while none is.
      @current = nil

      # The change that runs or failed, {:text, :rate, :failed}, and how often it changed.
      @change = nil
      @change_serial = 0

      class << self
        # @return [Integer] How often what the browser shows changed.
        attr_reader :serial

        # @return [Hash{String => Object}] The descriptions fetched.
        attr_reader :descriptions

        # @return [ModBrowser, nil] The browser open now.
        attr_accessor :current

        # @return [Hash, nil] The change that runs or failed.
        attr_reader :change

        # @return [Integer] How often the change changed.
        attr_reader :change_serial
      end

      # Tells the order the player left the mods in.
      #
      # @return [String] The DLL's name of the order.
      def self.order
        kept = Settings.setting(ORDER_SETTING).to_s
        ORDERS.any? { |name, _text| name == kept } ? kept : FIRST_ORDER
      end

      # Keeps the order the player picked for the next time.
      #
      # @param name [String] The DLL's name of the order.
      def self.order=(name)
        Settings.store(ORDER_SETTING, name)
        bump
      end

      # Tells the view the player left the mods in.
      #
      # @return [Symbol] :cards or :list.
      def self.view
        Settings.setting(VIEW_SETTING).to_s == LIST ? :list : :cards
      end

      # Keeps the view for the next time.
      #
      # @param view [Symbol] :cards or :list.
      def self.view=(view)
        Settings.store(VIEW_SETTING, view == :list ? LIST : CARDS)
      end

      # Tells whether the player left the filters open; shut before the first time.
      #
      # @return [Boolean] Whether they are open.
      def self.filters_open
        Settings.setting(FILTERS_SETTING).to_s == "on"
      end

      # Keeps whether the filters are open for the next time.
      #
      # @param open [Boolean] Whether they are.
      def self.filters_open=(open)
        Settings.store(FILTERS_SETTING, open ? "on" : "off")
      end

      # Hands out the player's picks of the filters, kept while the game runs.
      #
      # @return [Hash] {"categories", "keywords", "languages", "games" => [value, ...], "platform"
      #   (nil for the one the game runs on)}.
      def self.picks
        @picks ||= Hash[PICK_GROUPS.map { |group| [group, []] }].merge("platform" => nil)
      end

      # Clears every pick, the platform back to the one the game runs on.
      def self.clear_picks
        @picks = nil
        bump
      end

      # Turns a pick of a group on or off.
      #
      # @param group [String] The group, see PICK_GROUPS.
      # @param value [String] The pick.
      def self.toggle_pick(group, value)
        picked = picks[group]
        picked.include?(value) ? picked.delete(value) : picked << value
        bump
      end

      # Picks the platform whose mods show.
      #
      # @param platform [String, nil] Such as "android"; nil for the one the game runs on.
      def self.platform=(platform)
        picks["platform"] = platform
        bump
      end

      # Tells what the DLL is asked for the mods: the order, the search and the picks.
      #
      # @param search [String] What the player typed.
      # @return [Hash] {"order", "search", "picks"}.
      def self.query(search = "")
        { "order" => order, "search" => search.to_s, "picks" => picks }
      end

      # Has the browser read what it shows anew.
      def self.bump
        @serial += 1
      end

      # Opens the browser, one at a time; one open already opens the page of the mod asked for.
      #
      # @param mod [String, nil] The mod whose page it opens on, see Mods.browse; nil for none.
      # @param quiet [Boolean] Whether what opened it played the confirm sound.
      # @return [Object, nil] The browser's handle, nil without the DLL.
      def self.open(mod, quiet)
        return nil unless Mod_Framework.available?

        if @current
          handle = UI.open(ModBrowser)
          @current.show_mod(mod) if mod
          return handle
        end

        UI.confirm_sound unless quiet
        Mods.log("opened #{ModBrowser::ID}#{mod ? " on #{mod}" : ''}")
        UI.open(ModBrowser, :mod => mod)
      end

      # Hands an event of the DLL to the browser: a fetch or the pictures that ended read the mods
      # anew, a description that came shows on its page, a vote that ended says how.
      #
      # @param name [Symbol] What happened: :fetched, :pictures, :described or :voted.
      # @param value [Object] What the event carried.
      def self.take(name, value = nil)
        case name
        when :described then described(value.is_a?(Hash) ? value["id"] : nil)
        when :voted then @current.voted(value.is_a?(Hash) ? value : {}) if @current
        else bump
        end
      rescue => e
        Mods.log("the mod browser could not take #{name}: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
      end

      # Keeps a description whose fetch ended, its summary in its place when the fetch failed.
      #
      # @param id [String, nil] The mod's id.
      def self.described(id)
        return unless id

        answer = Mods.describe(id, false)
        lines = answer.is_a?(Hash) ? answer["lines"] : nil
        @descriptions[id] = lines ? Array(lines) : :failed
        bump
      end

      # Fetches a mod's description as its page opens, for a mod of the website that is not
      # installed, whose page tells its description; never as the cursor moves.
      #
      # @param mod [Hash] The mod.
      def self.fetch_description(mod)
        return unless mod["source"] == "site" && ModBrowser.described?(mod) && !@descriptions[mod["id"]].is_a?(Array)

        answer = Mods.describe(mod["id"])
        lines = answer.is_a?(Hash) ? answer["lines"] : nil
        @descriptions[mod["id"]] = if lines then Array(lines)
                                   elsif answer.is_a?(Hash) && answer["fetching"] then :fetching
                                   else :failed
                                   end
      end

      # Shows how a change goes in the change box.
      #
      # @param change [Hash, nil] {:text, :rate (0 to 1), :failed}; nil for none.
      def self.change=(change)
        @change = change
        @change_serial += 1
      end
    end

    # The mod browser at the title, a window of the UI layer: the bar with the tabs Mods and Collections, how many show, List view or Card view,
    # Update all and Refresh, and under them the search typed in place, the Filters button and what
    # happened last; under the bar the filter drawer at the left, shut until the player opens it,
    # and the mods as cards three across and two down (two across beside the open drawer) or as six
    # rows, or the website's collections as rows. Up and Down pick the bar or the mods as a whole,
    # confirm moves inside and cancel back out, cancel while picking closes the browser. A mod or a
    # collection opens at once on a page of its own, a dialog over the cards. A change runs in the
    # change box and says on the bar how it ended; a mod installed at the title loads when the
    # player enters the game, one that runs already once the game starts again, which the browser
    # asks about.
    class ModBrowser < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :mods_tab => "Mods",
        :collections_tab => "Collections",
        :shown_of => "%d of %d",
        :loading => "Loading . . .",
        :list_view => "List view",
        :card_view => "Card view",
        :update_all => "Update all",
        :update_all_count => "Update all (%d)",
        :update_all_tip => "Updates %s.",
        :refresh => "Refresh",
        :search => "Search",
        :search_placeholder => "Down from the buttons to type",
        :filters => "Filters",
        :fetching => "Loading the mods . . .",
        :not_fetched => "The mods could not be loaded.",
        :no_match => "Nothing matches",
        :no_collections => "The website has no collections yet.",
        :badge_update => "Update",
        :badge_installed => "Installed",
        :badge_changed => "Changed",
        :spoiler => "Spoiler",
        :no_screenshot => "No screenshot",
        :picture_loading => "Loading . . .",
        :by => "by %s",
        :line => "%s  -  %s",
        :other_platform => "Not available on this platform",
        :all_set => "All set",
        :back => "Back",
        :box_title => "Mods",
        :installing_names => "Installing %s . . .",
        :failed => "Nothing changed: %s",
        :upvoted_done => "Upvoted.",
        :upvote_taken_back => "Upvote taken back.",
        :refused_not_downloaded => "Only mods this game installed with the Mod browser can be upvoted here. Upvote it on its page.",
        :refused_ratings_off => "Upvotes are off. Turn them on in Configuration on the title.",
        :refused_key_blocked => "The site takes no upvotes from this game.",
        :refused_unknown_mod => "The site no longer lists this mod.",
        :refused_rate_limited => "Too many upvotes from here for now. Try again later.",
        :refused_unreachable => "Nothing changed: the site could not be reached.",
        :refused_not_started => "Nothing changed: the upvote could not start.",
        :refused_other => "Nothing changed: the site refused it.",
        :restart_later => "Restart the game to load the changed mods.",
        :ask_conflict => "%s does not work with %s, %s%s Install it turned off? You can turn it on in Mods.",
        :which_is_on => "which is on",
        :which_are_on => "which are on",
        :install_off => "Install it turned off",
        :installed_off => "Installed, turned off.",
        :ask_framework => "Update the Mod Framework to %s? It downloads, then the game starts again.",
        :update_restart => "Update and restart",
        :installed_regular => "Installed. It loads when you enter the game.",
        :installed_title => "Installed. It shows on the title screen when you close the browser.",
        :installed_framework => "Installed. It runs once the game starts again.",
        :installed_both => "Installed %s.",
        :updated_to => "Updated to %s.",
        :updated => "Updated %s.",
        :replaced => "Replaced with %s.",
        :removed => "Removed.",
        :ask_both => "%s needs %s, which is not installed. Install both?",
        :ask_all => "%s needs %s, which are not installed. Install them too?",
        :install_both => "Install both",
        :install_all => "Install them too",
        :by_hand_one => "%s is installed by hand from its page on the website.",
        :by_hand_more => "%s are installed by hand from their pages on the website.",
        :ask_replace => "Your copy of %s was changed. Replace it with %s? Your changes are lost.",
        :replace_yes => "Replace",
        :ask_remove => "Remove %s? %s",
        :remove_files => "Its files are deleted from the Patch folder.",
        :needs_it => " %s it.",
        :remove_yes => "Remove",
        :restart_installed => "%s. It runs once the game starts again. Start it again now?",
        :restart_installed_more => "%s. They run once the game starts again. Start it again now?",
        :restart_removed => "%s is removed. It runs until the game starts again. Start it again now?",
        :restart_turned_off => "%s. It runs until the game starts again. Start it again now?",
        :restart_turned_off_more => "%s. They run until the game starts again. Start it again now?",
        :runs_once => "%s %s runs once the game starts again.",
        :runs_until => "%s runs until the game starts again.",
        :restart_now => "Restart now",
        :later => "Later",
        :page_opened => "Its page opened in your web browser.",
        :page_failed => "Its page could not be opened.",
        :collection_done => "Installed and turned on.",
        :collection_on => "Turned on.",
        :ask_others => "%s on: %s. Turn them off so only this collection's mods run?",
        :others_off => "Turn them off",
        :others_on => "Keep them on",
        :more => "%d more"
      }

      # The id of its window.
      ID = :mf_browser

      # The filter drawer's look: beside the cards (:persistent), over them (:temporary), or a
      # narrow strip while shut (:mini).
      FILTERS_VARIANT = :persistent

      # The filter drawer's width while open.
      FILTERS_WIDTH = 240

      # Room the bar and the boxes' frames take from the screen's height, which the two lines of
      # cards share.
      CARDS_ROOM = 104

      # Cards side by side, beside the open drawer, and lines of them in sight; rows of the list
      # view in sight.
      CARD_COLUMNS = 3
      CARD_COLUMNS_BESIDE = 2
      CARD_LINES = 2
      LIST_LINES = 6

      # The width of a row's picture in the list view.
      ROW_PICTURE = 96

      # The width of the bar's buttons on the first line, at least.
      BAR_BUTTON = 112

      # The width of the search's label and its field.
      SEARCH_LABEL = 56
      SEARCH_WIDTH = 244

      # The most characters a search takes.
      SEARCH_CHARS = 40

      # The most names a question names before "N more".
      SHOWN_NAMES = 3

      # What the bar says for each refusal of a vote, by the DLL's or the website's name.
      REFUSALS = { "NotDownloaded" => :refused_not_downloaded, "RatingsOff" => :refused_ratings_off, "KeyBlocked" => :refused_key_blocked,
                   "UnknownMod" => :refused_unknown_mod, "RateLimited" => :refused_rate_limited, "Unreachable" => :refused_unreachable,
                   "NotStarted" => :refused_not_started }

      # An upvote, as the DLL names it.
      UP = "up"

      # The statuses of a mod as the DLL names them, see ModStatus.
      UPDATE = "update"
      CURRENT = "current"
      CHANGED = "changed"
      AVAILABLE = "available"
      OTHER_PLATFORM = "other_platform"

      # The tag whose mods run from the start of the game.
      FRAMEWORK = "Framework"

      # The tag of the mods a title command loads.
      TITLE = "Title"

      # The tabs' ids.
      MODS_TAB = :mf_browser_mods_tab
      COLLECTIONS_TAB = :mf_browser_collections_tab

      # The mod whose page it opens on, by its id or a name a requirement names it by.
      param :mod, nil

      # The tab shown: MODS_TAB or COLLECTIONS_TAB.
      state :shown_tab, MODS_TAB

      # The view of the mods: :cards or :list.
      state(:view) { Browser.view }

      # Whether the player opened the filter drawer.
      state(:filters_open) { Browser.filters_open }

      # What the player typed into the search.
      state :search, ""

      # What happened last, [text, color], nil for nothing.
      state :said

      # The ids of the mods a change installs while it runs, nil while none does.
      state :busy

      # What the browser shows changes with the DLL's events and the player's picks.
      watch { Mod_Framework::Mods::Browser.serial }

      # Tells whether a mod's page tells its description rather than its changes: it is not
      # installed.
      #
      # @param mod [Hash] The mod.
      # @return [Boolean] Whether it does.
      def self.described?(mod)
        mod["status"] == AVAILABLE || mod["status"] == OTHER_PLATFORM
      end

      # Reads the mods as the browser opens, fetching them again behind.
      def setup
        Browser.current = self
        @answer = nil
        take(Mods.browsed(true, Browser.query(search)))
      end

      # Opens the page of the mod asked for once the browser shows, with the focus on its first
      # button, as a pick of its card opens it.
      def mounted
        show_mod(mod) if mod
      end

      # Forgets the browser once it left the screen, with its page and its change box; a change that
      # ends later asks and says nothing.
      def unmounted
        @gone = true
        Browser.current = nil if Browser.current.equal?(self)
        close_page
        close_change
      end

      # Describes the browser: the bar, the filter drawer and the mods or the collections.
      def render
        answer = browsed
        shown = shown_tab == MODS_TAB ? mods : collections
        window nil, id: ID, width: :screen, height: :screen, frame: false, movable: false, on_close: ->(why) { closed(why) } do
          bar(answer, shown)
          stack row: true, height: :fill, spacing: 1 do
            filter_drawer(answer)
            paper enter: true, id: :mf_browser_mods, grow: 1, height: :fill, autofocus: !shown.empty?, disabled: shown.empty? do
              shown_tab == MODS_TAB ? mods_view : collections_view
            end
          end
        end
      end

      # Opens a mod's page on the Mods tab, clearing the picks and the search that hide it.
      #
      # @param key [String] The mod's id, or a name a requirement names it by.
      def show_mod(key)
        found = found_mod(key)
        return UI.buzz("#{ID} finds no mod #{key}") unless found

        self.shown_tab = MODS_TAB
        open_page(found)
      end

      # Takes the end of a vote: the bar says how it ended.
      #
      # @param event [Hash] {"id", "vote", "error"}, see ModsTopics.VotedTopic.
      def voted(event)
        @voting = nil
        Browser.bump
        return refuse_vote(event["id"], event["error"]) if event["error"]

        Sound.play_ok
        Mods.log("#{ID}: the vote on #{event['id']} counted (#{event['vote'] || 'taken back'})")
        say(event["vote"] == UP ? TEXTS[:upvoted_done] : TEXTS[:upvote_taken_back])
      end

      # Installs a mod, or updates or replaces it; first asks whether to lose a changed copy, or
      # whether to install it turned off beside a mod that is on and that it does not work with.
      #
      # @param mod [Hash] The mod.
      def install(mod)
        return if busy

        if mod["status"] == CHANGED
          question = format(TEXTS[:ask_replace], mod["name"], mod["latest"])
          return UI.confirm(question, :yes => TEXTS[:replace_yes], :no => TEXTS[:back]) { |yes| run_install([mod], mod, :replaced) if yes }
        end

        on = conflicts_of(mod).select { |conflict| conflict[2] }
        return install_with_needs(mod, false) if on.empty? || mod["status"] != AVAILABLE

        note = on.size == 1 ? on[0][1].to_s.strip : ""
        ending = note.empty? ? "." : ": #{note}#{note =~ /[.!?]\z/ ? '' : '.'}"
        question = format(TEXTS[:ask_conflict], mod["name"], UI.listed(on.map { |conflict| conflict[0] }), on.size == 1 ? TEXTS[:which_is_on] : TEXTS[:which_are_on], ending)
        UI.confirm(question, :yes => TEXTS[:install_off], :no => TEXTS[:back]) { |yes| install_with_needs(mod, true) if yes }
      end

      # Upvotes a mod, takes back the upvote this game gave it, or says why this game may not upvote
      # it.
      #
      # @param mod [Hash] The mod.
      def upvote(mod)
        return if @voting
        return refuse_vote(mod["id"], mod["rate"]) if mod["rate"]

        answer = Mods.vote(mod["id"], mod["vote"] == UP ? nil : UP)
        return refuse_vote(mod["id"], answer.is_a?(Hash) ? answer["refused"] : "Unreachable") unless answer.is_a?(Hash) && answer["started"]

        Mods.log("#{ID}: votes on #{mod['id']}")
        @voting = mod["id"]
      end

      # Asks whether to update the framework, which waits for the next start, and starts the game
      # again once it is in.
      #
      # @param mod [Hash] The framework.
      def update_framework(mod)
        UI.confirm(format(TEXTS[:ask_framework], mod["latest"]), :yes => TEXTS[:update_restart], :no => TEXTS[:back]) do |yes|
          run_install([mod], mod, :framework) if yes
        end
      end

      # Removes a mod's installed version, after asking.
      #
      # @param mod [Hash] The mod.
      def remove_mod(mod)
        return if busy

        needers = needed_by(mod)
        reason = TEXTS[:remove_files]
        reason += format(TEXTS[:needs_it], UI.listed(needers, "needs", "need")) unless needers.empty?
        UI.confirm(format(TEXTS[:ask_remove], mod["name"], reason), :yes => TEXTS[:remove_yes], :no => TEXTS[:back]) { |yes| removed(mod) if yes }
      end

      # Installs what a collection needs, turns its mods on in its order, then asks whether to turn
      # the other mods off.
      #
      # @param collection [Hash] The collection.
      def install_collection(collection)
        return if busy

        wanted = Array(collection["mods"]).select { |entry| BrowserCollectionPage.installs?(entry) }
        by_hand_note(Array(collection["mods"]).select { |entry| BrowserCollectionPage.by_hand?(entry) }, collection["id"])
        installs = every_mod(wanted.map { |entry| entry["id"] })
        return turn_on_collection(collection) if installs.empty?

        run_install(installs, nil, collection)
      end

      # Opens a mod's page on the Mods tab from a collection's page.
      #
      # @param entry [Hash] The collection's mod.
      def show_in_mods(entry)
        found = entry["id"] ? found_mod(entry["id"]) : nil
        return UI.buzz("#{ID}: #{entry['name']} is not listed") unless found

        UI.confirm_sound
        close_page
        self.shown_tab = MODS_TAB
        open_page(found)
      end

      # Opens a mod's page in the player's web browser, or, for a mod with links of its own, a
      # dialog of its pages to pick from.
      #
      # @param mod [Hash] The mod.
      def open_pages(mod)
        links = Array((mod["details"] || {})["links"])
        return open_page_of(mod) if links.empty?

        UI.open(BrowserLinks, :mod => mod, :on_submit => ->(link) { open_page_of(mod, link) })
      end

      # Opens a mod's or a collection's page in the player's web browser, or a link of a mod, and
      # says on the bar whether it opened.
      #
      # @param item [Hash] The mod or the collection.
      # @param link [String, nil] The kind of the mod's link, such as "source"; nil for its page.
      def open_page_of(item, link = nil)
        opened = Mods.open_page(item["id"], link)
        opened ? UI.confirm_sound : UI.buzz("#{ID}: the page of #{item['id']} did not open")
        say(opened ? TEXTS[:page_opened] : TEXTS[:page_failed], opened ? nil : :error)
      end

      # Picks a row of the filter drawer: a value steps on, a box fills or clears, Clear filters
      # clears every pick, More keywords shows the rest.
      #
      # @param item [Array] The row's item, see BrowserFilters#items.
      # @return [Boolean] Whether it shows every keyword now.
      def pick_filter(item)
        case item[0]
        when :clear then clear_filters
        when :order, :platform then step_filter(item, 1)
        when :more then Sound.play_cursor
        else
          Browser.toggle_pick(item[0], item[1])
          Mods.log("#{ID}: #{item[0]} #{item[1]} #{Browser.picks[item[0]].include?(item[1]) ? 'picked' : 'cleared'}")
          Sound.play_cursor
        end
        item[0] == :more
      end

      # Steps a value row of the filter drawer by Left, Right or confirm: the order, kept for the
      # next time, or the platform, the one the game runs on counting as none picked.
      #
      # @param item [Array] The row's item.
      # @param step [Integer] -1 or 1.
      def step_filter(item, step)
        if item[0] == :order
          place = Browser::ORDERS.index { |name, _text| name == Browser.order } || 0
          Browser.order = Browser::ORDERS[(place + step) % Browser::ORDERS.size][0]
        else
          platforms = filters_of(browsed)["platforms"] || []
          return UI.buzz if platforms.empty?

          picked = platforms[((platforms.index(platform_pick) || 0) + step) % platforms.size]
          Browser.platform = picked == own_platform ? nil : picked
        end
        Mods.log("#{ID}: #{item[0]} stepped to #{item[0] == :order ? Browser.order : platform_pick}")
        Sound.play_cursor
      end

      # Clears every pick of the filters, the platform back to the one the game runs on, as Clear
      # filters does.
      def clear_filters
        Browser.clear_picks
        Mods.log("#{ID}: cleared the filters")
        Sound.play_cursor
      end

      # Tells the platform whose mods show.
      #
      # @return [String] Such as "pc" or "any".
      def platform_pick
        Browser.picks["platform"] || own_platform
      end

      # Tells the platform the game runs on, as the filters name it.
      #
      # @return [String] Such as "pc".
      def own_platform
        filters_of(browsed)["own_platform"] || "pc"
      end

      # Closes the page of a mod or a collection, the focus back on its card or row.
      def close_page
        @page.close if @page && @page.open?
        @page = nil
      end

      # Tells the mods the DLL lists for the picks and the search, in the order picked.
      #
      # @return [Array<Hash>] Each mod, see Mods.browsed.
      def mods
        Array(browsed["mods"])
      end

      # Tells the website's collections the search lets through.
      #
      # @return [Array<Hash>] Each collection, see Mods.browsed.
      def collections
        Array(browsed["collections"])
      end

      # Tells what the DLL lists, asked anew only once the picks, the search or what the DLL holds
      # changed.
      #
      # @return [Hash] See Mods.browsed.
      def browsed
        query = Browser.query(search)
        key = [Browser.serial, Marshal.dump(query)]
        return @answer if @answer && @asked == key

        @asked = key
        take(Mods.browsed(false, query))
      end

      # Tells the badge of how a mod stands.
      #
      # @param mod [Hash] The mod.
      # @return [Hash, nil] {:text, :color}; nil for a mod not installed.
      def badge_of(mod)
        case mod["status"]
        when UPDATE then { :text => TEXTS[:badge_update], :color => :gold }
        when CURRENT then { :text => TEXTS[:badge_installed], :color => :success }
        when CHANGED then { :text => TEXTS[:badge_changed], :color => :warning }
        end
      end

      # Tells how a mod's screenshot shows: blurred under "Spoiler" on a card or row while it shows a
      # spoiler, clear on its page; a label while it is on its way or missing.
      #
      # @param mod [Hash] The mod.
      # @param page [Boolean] Whether it shows on the mod's page.
      # @return [Hash] {:file, :blur, :label, :badge}.
      def picture_of(mod, page = false)
        hidden = mod["spoiler"] && !page ? true : false
        label = if mod["picture"] then hidden ? TEXTS[:spoiler] : nil
                elsif mod["picture_waits"] then TEXTS[:picture_loading]
                else TEXTS[:no_screenshot]
                end
        { :file => mod["picture"], :blur => hidden, :label => label, :badge => badge_of(mod) }
      end

      # Tells the color of a mod's name: gold for an update, warning for a changed copy, success for
      # one installed, plain for one not installed.
      #
      # @param mod [Hash] The mod.
      # @return [Symbol, nil] The color.
      def name_color(mod)
        { UPDATE => :gold, CHANGED => :warning, CURRENT => :success }[mod["status"]]
      end

      # Lists the installed mods a mod does not work with.
      #
      # @param mod [Hash] The mod.
      # @return [Array<Array>] Each mod's name, its author's note, whether it is on and its folder.
      def conflicts_of(mod)
        Array((mod["details"] || {})["conflicts"])
      end

      # Tells whether a mod can be removed: a known version of it is installed.
      #
      # @param mod [Hash] The mod.
      # @return [Boolean] Whether it can.
      def removable?(mod)
        [UPDATE, CURRENT].include?(mod["status"]) || (mod["status"] == OTHER_PLATFORM && !mod["installed"].nil?)
      end

      # Finds a mod of the lists by its id.
      #
      # @param id [String, nil] The id.
      # @return [Hash, nil] The mod, nil for none.
      def mod_by_id(id)
        mods.find { |each| each["id"] == id }
      end

      # Finds a collection of the lists by its id.
      #
      # @param id [String, nil] The id.
      # @return [Hash, nil] The collection, nil for none.
      def collection_by_id(id)
        collections.find { |each| each["id"] == id }
      end

      private

      # Takes what the DLL lists, kept until the next ask.
      #
      # @param answer [Hash, nil] See Mods.browsed.
      # @return [Hash] It, or what was kept when the DLL answered nothing.
      def take(answer)
        @answer = answer if answer.is_a?(Hash)
        @answer ||= {}
      end

      # Tells what the filters offer.
      #
      # @param answer [Hash] See Mods.browsed.
      # @return [Hash] See ModsTopics.BrowseTopic.
      def filters_of(answer)
        answer["filters"].is_a?(Hash) ? answer["filters"] : {}
      end

      # Describes the bar: the tabs, how many show and the buttons on its first line; the search,
      # the Filters button and what happened last on its second.
      #
      # @param answer [Hash] What the DLL lists.
      # @param shown [Array<Hash>] The mods or the collections shown.
      def bar(answer, shown)
        waiting = updates(answer)
        message, color = said
        paper enter: true, id: :mf_browser_bar, autofocus: shown.empty? do
          stack row: true, spacing: 1, key: :first_line do
            tabs pages: false, bind: :shown_tab, id: :mf_browser_tabs, on_change: ->(tab) { tab_changed(tab) } do
              tab TEXTS[:mods_tab], id: MODS_TAB
              tab TEXTS[:collections_tab], id: COLLECTIONS_TAB
            end
            text status_text(answer, shown), typo: :caption, color: :dim, grow: 1, key: :status
            button view == :cards ? TEXTS[:list_view] : TEXTS[:card_view], id: :mf_browser_view, variant: :outlined, min_size: [BAR_BUTTON, 0],
                                                                          disabled: shown_tab != MODS_TAB, on_click: -> { switch_view }
            button waiting.empty? ? TEXTS[:update_all] : format(TEXTS[:update_all_count], waiting.size), id: :mf_browser_update_all, variant: :outlined,
                   min_size: [BAR_BUTTON, 0], disabled: waiting.empty? || !busy.nil?,
                   tooltip: waiting.empty? ? nil : format(TEXTS[:update_all_tip], UI.listed(waiting.map { |mod| mod["name"] })), on_click: -> { update_every }
            button TEXTS[:refresh], id: :mf_browser_refresh, variant: :outlined, min_size: [BAR_BUTTON, 0], on_click: -> { refresh_lists }
          end
          stack row: true, spacing: 2, key: :search_line do
            text TEXTS[:search], color: :system, width: SEARCH_LABEL, key: :search_label
            text_field bind: :search, id: :mf_browser_search, placeholder: TEXTS[:search_placeholder], max_length: SEARCH_CHARS, width: SEARCH_WIDTH,
                       letters: false, leave_sides: true, on_submit: ->(_text) { part(:mf_browser_refresh).focus },
                       on_cancel: -> { clear_search }
            button TEXTS[:filters], id: :mf_browser_filters_button, variant: :outlined, badge: answer["picks"].to_i, disabled: shown_tab != MODS_TAB,
                                    on_click: -> { switch_filters }
            text message.to_s, typo: :caption, color: color || :text, grow: 1, key: :said
          end
        end
      end

      # Describes the filter drawer at the left of the mods, open while the player opened it on the
      # Mods tab.
      #
      # @param answer [Hash] What the DLL lists.
      def filter_drawer(answer)
        open = filters_open && shown_tab == MODS_TAB
        drawer open: open, variant: FILTERS_VARIANT, width: FILTERS_WIDTH, id: :mf_browser_filters, key: FILTERS_VARIANT,
               on_change: ->(now) { keep_filters(now) } do
          if FILTERS_VARIANT == :mini
            drawer_header do
              button filters_open ? "<" : ">", on_click: -> { switch_filters }
            end
          end
          component BrowserFilters, filters: filters_of(answer), picks: answer["picks"].to_i, order: Browser.order, platform: platform_pick,
                                    enter: FILTERS_VARIANT != :temporary, browser: self, id: :mf_browser_filter_rows, height: :fill
        end
      end

      # Describes the mods as cards, three across (two beside the open drawer) and two lines in
      # sight, or as six rows, without a bind, so a move of the cursor renders nothing.
      def mods_view
        shown = mods
        if view == :cards
          beside = filters_open && FILTERS_VARIANT != :temporary
          list shown, look: :cards, columns: beside ? CARD_COLUMNS_BESIDE : CARD_COLUMNS, rows_shown: CARD_LINES, height: Graphics.height - CARDS_ROOM, highlight: search,
                      id: :mf_browser_cards, click_picks: true, row: ->(mod) { card_row(mod) }, empty: empty_text, on_submit: ->(mod) { open_page(mod["id"]) }
        else
          list shown, rows_shown: LIST_LINES, height: :fill, id: :mf_browser_rows, click_picks: true, row: ->(mod) { list_row(mod) }, empty: empty_text,
                      on_submit: ->(mod) { open_page(mod["id"]) }
        end
      end

      # Describes the collections as six rows of two lines.
      def collections_view
        list collections, rows_shown: LIST_LINES, height: :fill, id: :mf_browser_collections, click_picks: true, row: ->(collection) { collection_row(collection) },
                          empty: fetching? ? TEXTS[:fetching] : browsed["collections_kept"] ? TEXTS[:no_collections] : TEXTS[:not_fetched],
                          on_submit: ->(collection) { open_page(collection["id"]) }
      end

      # Makes a mod's card: its screenshot with its badge, its name in its state's color with its
      # newest version, who made it with its upvotes, and two lines of its summary.
      #
      # @param mod [Hash] The mod.
      # @return [Hash] The row.
      def card_row(mod)
        { :text => mod["name"].to_s, :color => name_color(mod), :right => mod["latest"].to_s, :right_color => :dim, :faint => mod["status"] == OTHER_PLATFORM,
          :picture => picture_of(mod), :lines => [{ :text => author_line(mod), :right => upvote_parts(mod) }, mod["summary"].to_s] }
      end

      # Makes a mod's row of the list view: a small screenshot with its badge, the name and version,
      # and who made it with its summary and its upvotes on one line.
      #
      # @param mod [Hash] The mod.
      # @return [Hash] The row.
      def list_row(mod)
        author = author_line(mod)
        summary = mod["summary"].to_s
        { :text => mod["name"].to_s, :color => name_color(mod), :right => mod["latest"].to_s, :right_color => :dim, :faint => mod["status"] == OTHER_PLATFORM,
          :picture => picture_of(mod), :picture_width => ROW_PICTURE,
          :lines => [{ :text => summary.empty? ? author : format(TEXTS[:line], author, summary), :right => upvote_parts(mod) }] }
      end

      # Makes a collection's row: its name with how many mods it has, or All set when installing it
      # changes nothing, and who made it with its summary.
      #
      # @param collection [Hash] The collection.
      # @return [Hash] The row.
      def collection_row(collection)
        todo = BrowserCollectionPage.todo?(collection)
        author = format(TEXTS[:by], collection["author"])
        summary = collection["summary"].to_s
        { :text => collection["name"].to_s, :right => todo ? UI.counted(Array(collection["mods"]).size, "mod") : TEXTS[:all_set],
          :right_color => todo ? :dim : :success, :lines => [summary.empty? ? author : format(TEXTS[:line], author, summary)] }
      end

      # Tells who made a mod, as a card's line under its name says it.
      #
      # @param mod [Hash] The mod.
      # @return [String] Such as "by Ana", or what a mod not available here is.
      def author_line(mod)
        return TEXTS[:other_platform] if mod["status"] == OTHER_PLATFORM

        author = mod["author"].to_s
        author.empty? ? "" : format(TEXTS[:by], author)
      end

      # Makes the parts of a mod's upvotes: the thumb up with the count, gold when this game upvoted
      # it.
      #
      # @param mod [Hash] The mod.
      # @return [Array<Hash>, nil] The parts; nil at no upvotes or for a mod not on the website.
      def upvote_parts(mod)
        count = mod["upvotes"].to_i
        return nil if count <= 0

        [{ :text => count.to_s, :icon => { :file => UI.graphic("thumb_up") }, :color => mod["vote"] == UP ? :gold : :dim }]
      end

      # Tells what the mods box says while it shows nothing.
      #
      # @return [String] The text.
      def empty_text
        return TEXTS[:fetching] if fetching?

        failed? ? TEXTS[:not_fetched] : TEXTS[:no_match]
      end

      # Tells how many mods or collections show, of every one there is.
      #
      # @param answer [Hash] What the DLL lists.
      # @param shown [Array<Hash>] The mods or the collections shown.
      # @return [String] Such as "8 of 40" or "40 mods".
      def status_text(answer, shown)
        if shown_tab == COLLECTIONS_TAB
          total = answer["collections_total"].to_i
          return shown.size < total ? format(TEXTS[:shown_of], shown.size, total) : UI.counted(total, "collection")
        end

        total = (answer["total"] || shown.size).to_i
        return TEXTS[:loading] if shown.empty? && fetching?

        shown.size < total ? format(TEXTS[:shown_of], shown.size, total) : UI.counted(total, "mod")
      end

      # Tells whether the lists are being fetched.
      #
      # @return [Boolean] Whether they are.
      def fetching?
        browsed["fetching"] ? true : false
      end

      # Tells whether no list could be had: the fetch ended and the cache holds none.
      #
      # @return [Boolean] Whether none could.
      def failed?
        answer = browsed
        !answer["fetching"] && !answer["site"]
      end

      # Lists every mod an update waits for, whatever the picks of the filters, but the framework,
      # which updates on its own page, and the mods installed by hand.
      #
      # @param answer [Hash] What the DLL lists.
      # @return [Array<Hash>] Each mod, see Mods.browsed.
      def updates(answer = browsed)
        listed = answer.key?("updates") ? Array(answer["updates"]) : Array(answer["mods"]).select { |mod| mod["status"] == UPDATE }
        listed.reject { |mod| mod["framework"] || mod["by_hand"] }
      end

      # Says on the bar what happened last.
      #
      # @param text [String, nil] What; nil for nothing.
      # @param color [Symbol, nil] Its color: :error for a failure, :warning for what waits; nil for
      #   the plain one.
      def say(text, color = nil)
        self.said = text.nil? ? nil : [text.to_s, color]
      end

      # Switches the mods between the cards and the rows, and keeps the choice for the next time.
      def switch_view
        self.view = view == :cards ? :list : :cards
        Browser.view = view
        Mods.log("#{ID}: shows the mods as #{view}")
      end

      # Opens or shuts the filter drawer and keeps that for the next time; open, the keys go into it.
      def switch_filters
        keep_filters(!filters_open)
        Sound.play_cursor
        part(:mf_browser_filter_rows).focus_rows if filters_open && FILTERS_VARIANT != :temporary
      end

      # Keeps whether the filter drawer is open, as the player left it.
      #
      # @param open [Boolean] Whether it is.
      def keep_filters(open)
        self.filters_open = open ? true : false
        Browser.filters_open = filters_open
      end

      # Takes the tab the player picked: what happened last goes from the bar.
      #
      # @param _tab [Symbol] MODS_TAB or COLLECTIONS_TAB.
      def tab_changed(_tab)
        say(nil)
      end

      # Empties the search, as the cancel that stops its typing does, and goes back to the bar's
      # first line.
      def clear_search
        self.search = ""
        part(:mf_browser_refresh).focus
      end

      # Fetches the lists again, as Refresh does.
      def refresh_lists
        Mods.log("#{ID}: fetches the lists again")
        take(Mods.browsed(true, Browser.query(search)))
        Browser.bump
      end

      # Opens the page of a mod or a collection of the tab shown, a dialog over the cards; a mod's
      # description is fetched as its page opens.
      #
      # @param id [String] The id.
      def open_page(id)
        mod = shown_tab == MODS_TAB ? mod_by_id(id) : nil
        return UI.buzz("#{ID}: #{id} is not listed") if shown_tab == MODS_TAB && mod.nil?

        say(nil)
        Browser.fetch_description(mod) if mod
        close_page
        @page = UI.open(BrowserPage, :item_id => id, :collection => shown_tab == COLLECTIONS_TAB, :browser => self)
        Mods.log("#{ID}: opened the page of #{id}")
      end

      # Updates every mod an update waits for, but the framework, which updates once the game closed.
      def update_every
        return if busy

        waiting = updates
        return UI.buzz if waiting.empty?

        run_install(waiting, waiting.first, :updated)
      end

      # Installs a mod, or updates it; first asks to install too the mods it needs that are missing,
      # but those installed by hand, which the bar names once it is installed.
      #
      # @param mod [Hash] The mod.
      # @param off [Boolean] Whether it is installed turned off.
      def install_with_needs(mod, off)
        needed = every_mod(Array(mod["brings"]))
        missing = needed.reject { |other| other["by_hand"] }
        note = by_hand_note(needed - missing, mod["id"])
        kind = mod["status"] == UPDATE ? :updated_to : :installed
        @install_off = off ? mod["folder"] : nil
        return run_install([mod], mod, kind, note) if missing.empty?

        names = missing.map { |other| other["name"] }
        question = format(missing.size == 1 ? TEXTS[:ask_both] : TEXTS[:ask_all], mod["name"], UI.listed(names))
        UI.confirm(question, :yes => missing.size == 1 ? TEXTS[:install_both] : TEXTS[:install_all], :no => TEXTS[:back]) do |yes|
          run_install(missing + [mod], mod, :installed_both, note) if yes
        end
      end

      # Logs the mods an install leaves out, which the player installs by hand, and tells the
      # sentence the bar adds about them once it is installed.
      #
      # @param left [Array<Hash>] The mods left out, each with its "id" and "name".
      # @param what [String] What the install is for, such as a mod's id, for the log.
      # @return [String, nil] The sentence; nil when none is left out.
      def by_hand_note(left, what)
        return nil if left.empty?

        Mods.log("#{ID}: leaves #{left.map { |each| each['id'] }.join(', ')} out of the install of #{what}: installed by hand")
        format(left.size == 1 ? TEXTS[:by_hand_one] : TEXTS[:by_hand_more], UI.listed(left.map { |each| each["name"] }))
      end

      # Says with the buzzer why a vote did not count.
      #
      # @param id [String] The mod's id.
      # @param why [String, nil] The refusal's name, see REFUSALS.
      def refuse_vote(id, why)
        UI.buzz
        Mods.log("#{ID}: a vote on #{id} was refused: #{why}")
        say(TEXTS[REFUSALS[why.to_s] || :refused_other], :error)
      end

      # Finds a mod to show, clearing the picks of the filters and the search when they hide it.
      #
      # @param key [String] The mod's id, or a name a requirement names it by.
      # @return [String, nil] The mod's id, nil for none.
      def found_mod(key)
        answer = Mods.browsed(false, "find" => key.to_s)
        found = answer.is_a?(Hash) ? answer["found"] : nil
        return found if found.nil? || mod_by_id(found)

        Browser.clear_picks
        self.search = ""
        found
      end

      # Finds mods by their ids among every mod the lists have, whatever the picks of the filters
      # and the search.
      #
      # @param ids [Array<String>] The ids.
      # @return [Array<Hash>] Each mod found, in the order of the ids, see Mods.browsed.
      def every_mod(ids)
        return [] if ids.empty?

        answer = Mods.browsed(false, "order" => Browser.order, "picks" => { "platform" => "any" })
        every = answer.is_a?(Hash) ? Array(answer["mods"]) : mods
        ids.map { |id| every.find { |mod| mod["id"] == id } }.compact
      end

      # Lists the mods that are on and need a mod, as the Mods screen tells it.
      #
      # @param mod [Hash] The mod.
      # @return [Array<String>] Their names.
      def needed_by(mod)
        installed = Array((Mods.state || {})["mods"]).find { |each| each["name"] == mod["folder"] }
        installed ? Array(installed["needed_by"]) : []
      end

      # Installs mods in the change box and tells how it ended.
      #
      # @param installs [Array<Hash>] The mods.
      # @param mod [Hash, nil] The mod the install is for; nil for a collection's.
      # @param kind [Symbol, Hash] What the install is: :installed, :installed_both, :updated_to,
      #   :updated, :replaced or :framework (which starts the game again once it is in), or the
      #   collection it installs for.
      # @param note [String, nil] What the bar adds once it is installed, such as the mods it needs
      #   that the player installs by hand; nil for nothing.
      def run_install(installs, mod, kind, note = nil)
        self.busy = installs.map { |each| each["id"] }
        names = installs.map { |each| "#{each['name']} #{each['latest']}" }
        Browser.change = { :text => format(TEXTS[:installing_names], UI.listed(names)), :rate => 0 }
        @change_box = UI.open(ModChangeBox)
        Mods.log("#{ID}: installs #{busy.join(', ')}")
        Mods.install(busy, :progress => lambda { |done, total, _name| progressed(done, total) }) do |installed, error|
          installed(installs, mod, kind, installed, error, note)
        end
      end

      # Shows how far the install came on the change box's bar.
      #
      # @param done [Integer] The mods downloaded.
      # @param total [Integer] The mods to install.
      def progressed(done, total)
        return if @gone

        change = Browser.change
        Browser.change = change.merge(:rate => total > 0 ? done.to_f / total : 0) if change && !change[:failed]
      end

      # Closes the change box.
      def close_change
        @change_box.close if @change_box && @change_box.open?
        @change_box = nil
        Browser.change = nil
      end

      # Keeps the change box open once a change failed, saying why, with Close.
      #
      # @param text [String] Why, as the player reads it.
      def change_failed(text)
        return if @gone

        @change_box.close if @change_box && @change_box.open?
        Browser.change = { :text => text, :failed => true }
        @change_box = UI.open(ModChangeBox)
      end

      # Follows the end of an install: the mods new to the game folder and a collection's mods turn
      # on, while an update or a replacement keeps a mod on or off as it was; the change box closes
      # and the bar says what was done, or the box stays with why it failed, and a mod that runs
      # already asks whether to start the game again. Once the browser closed, only Mods.ini follows.
      #
      # @param installs [Array<Hash>] The mods.
      # @param mod [Hash, nil] The mod the install is for.
      # @param kind [Symbol, Hash] See run_install.
      # @param names [Array<String>] The names of the mods installed.
      # @param error [String, nil] Why it failed.
      # @param note [String, nil] What the bar adds once it is installed; nil for nothing.
      def installed(installs, mod, kind, names, error, note = nil)
        new_names = installs.select { |each| each["status"] == AVAILABLE }.map { |each| each["folder"] }
        off = @install_off && names.include?(@install_off) && !kind.is_a?(Hash) ? @install_off : nil
        @install_off = nil
        turn_on(kind.is_a?(Hash) ? names : names & new_names - [off])
        turn_off(off) if off
        Browser.bump
        Mods.log("#{ID}: the install of #{installs.map { |each| each['id'] }.join(', ')} ended: #{error || 'installed'}")
        return Mods.restart("the player updated the Mod Framework from the mod browser") if kind == :framework && !names.empty?

        keep_collection_on(kind) if @gone && kind.is_a?(Hash) && !names.empty?
        return if @gone

        self.busy = nil
        return failed_install(error) if names.empty?

        if error
          UI.buzz
          change_failed(error)
        else
          close_change
        end
        return turn_on_collection(kind, error) if kind.is_a?(Hash)

        Sound.play_ok unless error
        done = off ? TEXTS[:installed_off] : done_text(installs, mod, kind)
        say(error || [done, note].compact.join(" "), error ? :error : nil)
        running = installs.select { |each| running_after_install?(each) }
        ask_restart(running) unless running.empty?
      end

      # Tells the player an install failed, in the change box and on the bar.
      #
      # @param error [String, nil] Why.
      def failed_install(error)
        UI.buzz
        text = format(TEXTS[:failed], Screen.reason(error))
        change_failed(text)
        say(text, :error)
      end

      # Tells what an install did.
      #
      # @param installs [Array<Hash>] The mods.
      # @param mod [Hash] The mod the install is for.
      # @param kind [Symbol] See run_install.
      # @return [String] What the bar says.
      def done_text(installs, mod, kind)
        case kind
        when :installed_both then format(TEXTS[:installed_both], UI.listed(installs.reverse.map { |each| each["name"] }))
        when :updated_to then format(TEXTS[:updated_to], mod["latest"])
        when :updated then format(TEXTS[:updated], UI.listed(installs.map { |each| each["name"] }))
        when :replaced then format(TEXTS[:replaced], mod["latest"])
        else
          case mod["tag"]
          when TITLE then TEXTS[:installed_title]
          when FRAMEWORK then TEXTS[:installed_framework]
          else TEXTS[:installed_regular]
          end
        end
      end

      # Tells whether a mod installed runs only once the game starts again: a Framework mod, a mod
      # that runs already (see Mods.running?), or a Title mod whose command was used.
      #
      # @param mod [Hash] The mod, as it was before the install.
      # @return [Boolean] Whether it does.
      def running_after_install?(mod)
        mod["tag"] == FRAMEWORK || Mods.running?(mod["folder"]) || Mods.used?(mod["folder"])
      end

      # Turns mods on in Mods.ini.
      #
      # @param folders [Array<String>] Their names.
      def turn_on(folders)
        return if folders.empty?

        on = {}
        folders.each { |folder| on[folder] = true }
        answer = Mods.set("on" => on)
        Mods.log("turning on #{folders.join(', ')} was not kept: #{answer.inspect}") unless answer.is_a?(Hash) && answer["written"]
      end

      # Turns a mod off in Mods.ini, such as one installed turned off.
      #
      # @param folder [String] Its name.
      def turn_off(folder)
        answer = Mods.set("on" => { folder => false })
        Mods.log("turning off #{folder} was not kept: #{answer.inspect}") unless answer.is_a?(Hash) && answer["written"]
      end

      # Removes a mod and says so; a mod that runs asks whether to start the game again.
      #
      # @param mod [Hash] The mod.
      def removed(mod)
        answer = Mods.remove([mod["id"]])
        refused = answer.is_a?(Hash) ? answer["refused"] : TEXTS[:not_fetched]
        Browser.bump
        if refused
          UI.buzz("#{ID}: the removal of #{mod['id']} was refused: #{refused}")
          return say(format(TEXTS[:failed], Screen.reason(refused)), :error)
        end

        Mods.log("#{ID}: removed #{mod['id']}")
        Sound.play_ok
        say(TEXTS[:removed])
        ask_restart([mod], true) if Mods.running?(mod["folder"])
      end

      # Asks whether to start the game again now for mods installed or removed while they run;
      # Later notes each for the Mods screen's restart bar and says on the bar that a restart waits.
      #
      # @param changed [Array<Hash>] The mods.
      # @param removal [Boolean] Whether they were removed rather than installed.
      def ask_restart(changed, removal = false)
        changed.each do |mod|
          line = removal ? format(TEXTS[:runs_until], mod["name"]) : format(TEXTS[:runs_once], mod["name"], mod["latest"])
          Mods.wait_for_restart([:browser, mod["folder"]], line)
        end
        names = changed.map { |mod| removal ? mod["name"].to_s : "#{mod['name']} #{mod['latest']}" }
        question = if removal then format(TEXTS[:restart_removed], UI.listed(names))
                   else format(changed.size == 1 ? TEXTS[:restart_installed] : TEXTS[:restart_installed_more], UI.listed(names, "is installed", "are installed"))
                   end
        ask_restart_now(question)
      end

      # Asks a restart question, Later lit first: Restart now starts the game again, Later says on
      # the bar that a restart waits.
      #
      # @param question [String] The question.
      def ask_restart_now(question)
        UI.confirm(question, :yes => TEXTS[:restart_now], :no => TEXTS[:later]) do |yes|
          if yes
            Mods.restart("the player restarted from the mod browser")
          else
            Mods.log("#{ID}: the player starts the game again later")
            say(TEXTS[:restart_later], :warning)
          end
        end
      end

      # Turns a collection's mods on in its order, then asks whether to turn the other mods off.
      #
      # @param collection [Hash] The collection, as it was before the install.
      # @param error [String, nil] What went wrong in the install, said instead of the done line.
      def turn_on_collection(collection, error = nil)
        others = keep_collection_on(collection)
        installed = Array(collection["mods"]).any? { |entry| BrowserCollectionPage.installs?(entry) }
        Sound.play_ok unless error
        say(error || (installed ? TEXTS[:collection_done] : TEXTS[:collection_on]), error ? :error : nil)
        ask_others(others)
      end

      # Turns a collection's installed mods on in Mods.ini in its order.
      #
      # @param collection [Hash] The collection.
      # @return [Array<Hash>] The other mods that are on, each {"name", "title"}: neither the
      #   collection's nor needed by them.
      def keep_collection_on(collection)
        answer = Mods.collection_on(collection["id"])
        Mods.log("turning on the collection #{collection['id']} was not kept: #{answer.inspect}") unless answer.is_a?(Hash) && answer["written"]
        Browser.bump
        Array(answer.is_a?(Hash) ? answer["others"] : nil).map { |name, title| { "name" => name, "title" => title } }
      end

      # Asks whether to turn off the mods that are on beside a collection's and those they need.
      #
      # @param others [Array<Hash>] The mods, each {"name", "title"}, see keep_collection_on.
      def ask_others(others)
        return if others.empty?

        names = others.map { |mod| mod["title"] }
        shown = names.size > SHOWN_NAMES ? names.first(SHOWN_NAMES - 1) + [format(TEXTS[:more], names.size - SHOWN_NAMES + 1)] : names
        question = format(TEXTS[:ask_others], UI.counted(others.size, "other mod", "other mods", "is", "are"), UI.listed(shown))
        UI.confirm(question, :yes => TEXTS[:others_off], :no => TEXTS[:others_on]) do |yes|
          next unless yes

          off = {}
          others.each { |mod| off[mod["name"]] = false }
          Mods.set("on" => off)
          Mods.log("#{ID}: turned off #{off.keys.join(', ')} for a collection")
          Sound.play_cursor
          Browser.bump
          running = others.select { |mod| Mods.running?(mod["name"]) }
          ask_restart_turned_off(running) unless running.empty?
        end
      end

      # Asks whether to start the game again now for running mods a collection turned off.
      #
      # @param turned_off [Array<Hash>] The mods, each {"name", "title"}.
      def ask_restart_turned_off(turned_off)
        turned_off.each { |mod| Mods.wait_for_restart([:browser, mod["name"]], format(TEXTS[:runs_until], mod["title"])) }
        what = UI.listed(turned_off.map { |mod| mod["title"] }, "is turned off", "are turned off")
        ask_restart_now(format(turned_off.size == 1 ? TEXTS[:restart_turned_off] : TEXTS[:restart_turned_off_more], what))
      end

      # Follows the browser's close: the pictures are let go, and the title's commands and its Mods
      # box follow the mods installed and turned on. F12 changes nothing.
      #
      # @param why [Symbol, String] Why it closed.
      def closed(why)
        Mods.log("closed #{ID} (#{why})")
        mods.map { |each| each["picture"] }.compact.map { |file| file.to_s }.uniq.each { |file| UI.release_picture(file) }
        return if why == :reset

        state = Mods.state || {}
        first = Screen.first_tags || {}
        retagged = first.select { |name, tag| (Array(state["mods"]).find { |each| each["name"] == name } || {})["tag"] != tag }.keys
        Loader.follow_changes(Array(state["mods"]).select { |each| each["on"] && each["tag"] }.map { |each| each["name"] }, retagged)
        Title.show_badges
      end
    end

    Mod_Framework.bridge.on(FETCHED_TOPIC) { |_event| Mod_Framework::Mods::Browser.take(:fetched) }
    Mod_Framework.bridge.on(PICTURES_TOPIC) { |_event| Mod_Framework::Mods::Browser.take(:pictures) }
    Mod_Framework.bridge.on(DESCRIBED_TOPIC) { |event| Mod_Framework::Mods::Browser.take(:described, event) }
    Mod_Framework.bridge.on(VOTED_TOPIC) { |event| Mod_Framework::Mods::Browser.take(:voted, event) }
  end
end
