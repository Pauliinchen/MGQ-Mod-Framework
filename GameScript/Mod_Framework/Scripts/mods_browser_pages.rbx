#----------------------------------------------------------------
#  mods_browser_pages.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Told the page link picked to on_submit in place of on_pick
#      Paulinchen  2026-11-08: Showed a mod installed by hand without Install or Update, and left it out of a collection's install
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The page of a mod in the mod browser, in the dialog over the cards: its screenshot clear
    # beside its name and facts, the text that scrolls (warnings first, then its description or
    # changes and the sections of what the website tells), and its buttons, the focus on the first
    # that takes a press.
    class BrowserModPage < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :author => "Author",
        :from => "From",
        :yours => "Yours",
        :newest => "Newest",
        :size => "Size",
        :upvotes => "Upvotes",
        :not_installed => "Not installed",
        :changed_copy => "Changed copy",
        :unknown => "Unknown",
        :none_yet => "None yet",
        :yours_among => "%d, yours among them",
        :files_size => "%s, %s",
        :description => "Description",
        :changes_in => "Changes in %s",
        :range => "%d-%d of %d",
        :describing => "Loading the description . . .",
        :no_text => "No description.",
        :no_changes => "No changes told.",
        :install => "Install %s",
        :update => "Update to %s",
        :replace => "Replace with %s",
        :installed => "Installed",
        :remove => "Remove",
        :upvote => "Upvote",
        :upvoted => "Upvoted",
        :page => "Open page",
        :back => "Back",
        :conflict_on => "Does not work with %s, which is on",
        :conflict_installed => "Does not work with %s, which is installed",
        :conflicts_many => "Does not work with %d installed mods",
        :not_made_for => "Not made for %s",
        :safe_any_time => "Safe to add or remove in a save",
        :safe_add_only => "Safe to add, not to remove",
        :needs_new_game => "Needs a new game",
        :conflicts => "Conflicts",
        :load_order => "Load order",
        :loads_after => "Loads after %s.",
        :loads_before => "Loads before %s.",
        :known_issues => "Known issues",
        :issue => "- %s",
        :options => "Options",
        :hotkeys => "Hotkeys",
        :hotkey => "%s: %s",
        :works_with => "Works with",
        :languages => "Languages",
        :categories => "Categories",
        :credits => "Credits",
        :credit => "%s: %s",
        :license => "License",
        :license_rules => "Uploading it again: %s. Changed copies: %s.",
        :links => "Links",
        :link => "%s: %s",
        :and_keywords => "%s · keywords: %s",
        :this_game_note => "%s (this game)",
        :need_on => "Needs %s %s: on",
        :need_on_any => "Needs %s: on",
        :need_off => "Needs %s: off",
        :need_missing => "Needs %s: not installed",
        :need_version => "Needs %s %s: you have %s",
        :newer_elsewhere => "%s is not available on this platform.",
        :framework_note => "Updating closes the game, installs it and starts the game again.",
        :other_platform => "Not available on this platform",
        :by_hand => "This mod is installed by hand from its page on the website."
      }

      # The page picture's size.
      PICTURE_SIZE = [288, 162]

      # The kinds of the game as a mod's facts name them, by the website's name.
      GAME_NAMES = { "english" => "the English translation", "russian" => "the Russian translation", "untranslated" => "the untranslated game" }

      # The names of the kinds of the game in the section Works with.
      GAMES = { "english" => "English translation", "russian" => "Russian translation", "untranslated" => "Japanese, untranslated" }

      # The names of a mod's links, by the website's kind, in the order they show.
      LINK_NAMES = { "source" => "Source code", "homepage" => "Homepage", "support" => "Help", "donation" => "Donate" }

      # How a license's rules read, by the website's name.
      LICENSE_RULES = { "no" => "no", "ask-first" => "ask first", "with-credit" => "yes, with credit" }

      # Where a mod comes from, as its page names it, by the DLL's name.
      SOURCES = { "site" => "Website" }

      # What starts the name of an option or a hotkey of a mod, which its section leaves out.
      ROW_GROUP = /\A\s*\[[^\]]*\]\s*/

      # The mod.
      param :mod, nil

      # The browser it lies in, which its buttons act through.
      param :browser, nil

      # The lines of the text in sight, { first:, last:, total: }.
      state :in_sight

      # A description that came renders it again.
      watch { Mod_Framework::Mods::Browser.serial }

      # Describes the page.
      def render
        stack spacing: 2, height: :fill do
          stack row: true, spacing: 2, key: :head do
            image file: mod["picture"], fit: :cover, width: PICTURE_SIZE[0], height: PICTURE_SIZE[1], label: mod["picture"] ? nil : browser.picture_of(mod, true)[:label]
            stack spacing: 0, grow: 1, key: :facts do
              text mod["name"].to_s, typo: :h6, color: ModBrowser.described?(mod) ? :system : browser.name_color(mod)
              labels = fact_rows.map { |label, _value, _color| label }
              fact_rows.each do |label, value, color|
                field label, caption_width: labels, key: label do
                  text value.to_s, typo: :body2, color: color
                end
              end
            end
          end
          stack row: true, key: :text_head do
            text head, typo: :caption, color: :system, grow: 1
            text range_text, typo: :caption, color: :dim
          end
          paper scroll: :vertical, focusable: true, grow: 1, id: :mf_browser_text, key: mod["id"], on_scroll: ->(lines) { self.in_sight = lines } do
            texts.each_with_index { |(line, color), place| text line.to_s, typo: :body2, color: color || :text, wrap: true, key: place }
          end
          text TEXTS[:by_hand], typo: :body2, color: :dim, wrap: true, id: :mf_browser_by_hand, visible: mod["by_hand"] ? true : false
          stack row: true, spacing: 2, key: :buttons do
            first = nil
            buttons.each do |label, enabled, id, act, color|
              lit = enabled && first.nil? && act != :close
              first ||= id if lit
              button label, id: id, grow: 1, disabled: !enabled, color: color, autofocus: lit, on_click: act
            end
          end
        end
      end

      private

      # Makes the facts beside the picture: who made it, where it comes from, the copy the player
      # has, the newest version, its size and, for a mod of the website, its upvotes.
      #
      # @return [Array<Array>] Each fact's label, value and color.
      def fact_rows
        other = mod["status"] == ModBrowser::OTHER_PLATFORM
        size = other ? TEXTS[:other_platform] : format(TEXTS[:files_size], UI.bytes_text(mod["bytes"]), UI.counted(mod["files"].to_i, "file"))
        author = mod["author"].to_s
        rows = [[TEXTS[:author], author.empty? ? TEXTS[:unknown] : author, nil],
                [TEXTS[:from], SOURCES[mod["source"]] || mod["source"].to_s, nil],
                [TEXTS[:yours], yours_text, browser.name_color(mod)],
                [TEXTS[:newest], mod["latest"].to_s, nil],
                [TEXTS[:size], size, other ? :dim : nil]]
        return rows if mod["upvotes"].nil?

        count = mod["upvotes"].to_i
        voted = mod["vote"] == ModBrowser::UP
        rows + [[TEXTS[:upvotes], count <= 0 ? TEXTS[:none_yet] : voted ? format(TEXTS[:yours_among], count) : count.to_s, voted ? :gold : nil]]
      end

      # Tells the copy of the mod the player has.
      #
      # @return [String] The version, "Changed copy" or "Not installed".
      def yours_text
        return TEXTS[:changed_copy] if mod["status"] == ModBrowser::CHANGED
        return TEXTS[:not_installed] if mod["installed"].to_s.empty?

        mod["installed"].to_s
      end

      # Tells the head over the text: Description for a mod not installed, else its changes.
      #
      # @return [String] The head.
      def head
        ModBrowser.described?(mod) ? TEXTS[:description] : format(TEXTS[:changes_in], mod["latest"])
      end

      # Tells which lines of the text are in sight while it is longer than its box.
      #
      # @return [String] Such as "1-12 of 40"; empty while the whole text shows.
      def range_text
        lines = in_sight
        return "" unless lines.is_a?(Hash) && lines[:total].to_i > lines[:last].to_i - lines[:first].to_i + 1

        format(TEXTS[:range], lines[:first], lines[:last], lines[:total])
      end

      # Tells the text: the warnings, the description of a mod not installed or the changes of one
      # installed, then the sections of what the website tells.
      #
      # @return [Array<Array>] Each line and its color.
      def texts
        lines = warning_texts + (ModBrowser.described?(mod) ? description_texts : change_texts)
        detail_sections.each do |title, section|
          lines << [title, :system]
          lines.concat(section)
        end
        lines
      end

      # Makes the warnings a player reads first: the requirements, the mods it does not work with,
      # a game it is not made for, how safe it is in a save, a newer version not available here,
      # and how the framework's own update goes.
      #
      # @return [Array<Array>] Each line and its color.
      def warning_texts
        lines = need_lines + detail_facts
        lines << [format(TEXTS[:newer_elsewhere], mod["newer_elsewhere"]), :dim] if mod["newer_elsewhere"]
        lines << [TEXTS[:framework_note], :warning] if mod["framework"] && mod["status"] == ModBrowser::UPDATE
        lines
      end

      # Makes the lines of the description: fetched as its page opened, its summary when the fetch
      # failed or the mod has none on the website.
      #
      # @return [Array<Array>] Each line and its color.
      def description_texts
        known = Browser.descriptions[mod["id"]]
        return known.map { |line| [line.to_s, nil] } if known.is_a?(Array) && !known.empty?
        return [[TEXTS[:describing], :dim]] if known == :fetching

        summary = mod["summary"].to_s
        [[summary.empty? ? TEXTS[:no_text] : summary, nil]]
      end

      # Makes the lines of what changed in the newest version.
      #
      # @return [Array<Array>] Each line and its color.
      def change_texts
        notes = Array(mod["notes"])
        notes.empty? ? [[TEXTS[:no_changes], :dim]] : notes.map { |line| [line.to_s, nil] }
      end

      # Makes the lines of the requirements, each in the color of how it stands.
      #
      # @return [Array<Array>] Each line and its color.
      def need_lines
        Array(mod["needs"]).map do |name, version, state, have, _folder, _id|
          case state
          when "on" then [version.to_s.empty? ? format(TEXTS[:need_on_any], name) : format(TEXTS[:need_on], name, version), :success]
          when "off" then [format(TEXTS[:need_off], name), :warning]
          when "missing" then [format(TEXTS[:need_missing], name), :error]
          else [format(TEXTS[:need_version], name, version, have), :warning]
          end
        end
      end

      # Makes the facts a player checks before installing: the installed mods it does not work
      # with, a game it is not made for, and whether it is safe in a running save.
      #
      # @return [Array<Array>] Each line and its color.
      def detail_facts
        details = mod["details"]
        return [] unless details.is_a?(Hash)

        lines = []
        conflicts = browser.conflicts_of(mod)
        unless conflicts.empty?
          on = conflicts.any? { |conflict| conflict[2] }
          text = if conflicts.size > 1 then format(TEXTS[:conflicts_many], conflicts.size)
                 else format(on ? TEXTS[:conflict_on] : TEXTS[:conflict_installed], conflicts[0][0])
                 end
          lines << [text, on ? :error : :warning]
        end
        games = Array(details["works_with"])
        lines << [format(TEXTS[:not_made_for], GAME_NAMES[Mods.game_kind]), :warning] unless games.empty? || games.include?(Mods.game_kind)
        case details["save"]
        when "any-time" then lines << [TEXTS[:safe_any_time], :success]
        when "add-only" then lines << [TEXTS[:safe_add_only], :warning]
        when "new-game" then lines << [TEXTS[:needs_new_game], :warning]
        end
        lines
      end

      # Makes the sections of the text after its description or changes, in the order a player
      # checks them, each a heading and its lines.
      #
      # @return [Array<Array>] Each section's heading and its lines, each a text and its color.
      def detail_sections
        details = mod["details"]
        return [] unless details.is_a?(Hash)

        plain = lambda { |lines| Array(lines).map { |line| [line.to_s, nil] } }
        order = Array(details["load_after"]).map { |name| format(TEXTS[:loads_after], name) } + Array(details["load_before"]).map { |name| format(TEXTS[:loads_before], name) }
        options = Array(details["options"]).map { |name, help| [[name.to_s.sub(ROW_GROUP, ""), nil], [help.to_s, :dim]] }.flatten(1).reject { |line, _color| line.empty? }
        hotkeys = Array(details["hotkeys"]).map { |name, key| key.to_s.empty? ? name.to_s.sub(ROW_GROUP, "") : format(TEXTS[:hotkey], name.to_s.sub(ROW_GROUP, ""), key) }
        sections = [[TEXTS[:conflicts], browser.conflicts_of(mod).map { |name, note, on| [note.to_s.empty? ? name.to_s : "#{name}: #{note}", on ? :error : nil] }],
                    [TEXTS[:load_order], plain.call(order)],
                    [TEXTS[:known_issues], plain.call(Array(details["known_issues"]).map { |issue| format(TEXTS[:issue], issue) })],
                    [TEXTS[:options], options],
                    [TEXTS[:hotkeys], plain.call(hotkeys)],
                    [TEXTS[:works_with], works_with_lines(details)],
                    [TEXTS[:languages], plain.call(Array(details["languages"]).empty? ? [] : [Array(details["languages"]).join(", ")])],
                    [TEXTS[:categories], category_lines(details)],
                    [TEXTS[:credits], plain.call(Array(details["credits"]).map { |name, role| role.to_s.empty? ? name.to_s : format(TEXTS[:credit], name, role) })],
                    [TEXTS[:license], license_lines(details["license"])],
                    [TEXTS[:links], plain.call(Array(details["links"]).map { |kind, url| format(TEXTS[:link], LINK_NAMES[kind] || kind, url.to_s.sub(%r{\Ahttps?://}i, "")) })]]
        sections.reject { |_title, lines| lines.empty? }
      end

      # Makes the line of the games the mod works with, the one that runs saying so.
      #
      # @param details [Hash] The mod's details.
      # @return [Array<Array>] The line and its color, none when it names no game.
      def works_with_lines(details)
        games = Array(details["works_with"])
        return [] if games.empty?

        names = games.map { |game| game == Mods.game_kind ? format(TEXTS[:this_game_note], GAMES[game] || game) : GAMES[game] || game }
        [[names.join(", "), nil]]
      end

      # Makes the line of the mod's categories and keywords.
      #
      # @param details [Hash] The mod's details.
      # @return [Array<Array>] The line and its color, none when it has neither.
      def category_lines(details)
        categories = Array(details["categories"]).join(", ")
        keywords = Array(details["keywords"]).join(", ")
        return [] if categories.empty? && keywords.empty?
        return [[categories, nil]] if keywords.empty?

        [[categories.empty? ? format(TEXTS[:and_keywords], "", keywords).sub(/\A · /, "") : format(TEXTS[:and_keywords], categories, keywords), nil]]
      end

      # Makes the line of the mod's license.
      #
      # @param license [Array, nil] Its name, reuploads and edits; nil for none.
      # @return [Array<Array>] The line and its color, none without a license.
      def license_lines(license)
        return [] unless license.is_a?(Array)

        name, reuploads, edits = license
        rules = format(TEXTS[:license_rules], LICENSE_RULES[reuploads] || "not stated", LICENSE_RULES[edits] || "not stated")
        [[name.to_s.empty? ? rules : "#{name}. #{rules}", nil]]
      end

      # Tells the page's buttons: Install, Update or Replace (or Installed), Remove, Upvote for a mod
      # of the website, Open page and Back; the framework's own page offers only its update, and a
      # mod installed by hand has no Install, Update or Replace.
      #
      # @return [Array<Array>] Each button's text, whether it takes a press, its id, its action and
      #   its color.
      def buttons
        id = mod["id"]
        current = lambda { browser.mod_by_id(id) || mod }
        list = []
        if mod["framework"]
          update = mod["status"] == ModBrowser::UPDATE
          list << [update ? format(TEXTS[:update], mod["latest"]) : TEXTS[:installed], update, :mf_browser_install, -> { browser.update_framework(current.call) }]
        else
          action = action_text
          unless mod["by_hand"]
            list << [action || TEXTS[:installed], !action.nil? && mod["status"] != ModBrowser::OTHER_PLATFORM, :mf_browser_install, -> { browser.install(current.call) }]
          end
          list << [TEXTS[:remove], browser.removable?(mod), :mf_browser_remove, -> { browser.remove_mod(current.call) }]
          voted = mod["vote"] == ModBrowser::UP
          list << [voted ? TEXTS[:upvoted] : TEXTS[:upvote], true, :mf_browser_upvote, -> { browser.upvote(current.call) }, voted ? :gold : nil] if mod["source"] == "site"
        end
        links = Array((mod["details"] || {})["links"])
        list << [TEXTS[:page], mod["page"] || !links.empty? ? true : false, :mf_browser_open_page, -> { browser.open_pages(current.call) }]
        list << [TEXTS[:back], true, :mf_browser_back, :close]
      end

      # Tells what the first button says.
      #
      # @return [String, nil] The text; nil when there is nothing to install.
      def action_text
        case mod["status"]
        when ModBrowser::AVAILABLE, ModBrowser::OTHER_PLATFORM then format(TEXTS[:install], mod["latest"])
        when ModBrowser::UPDATE then format(TEXTS[:update], mod["latest"])
        when ModBrowser::CHANGED then format(TEXTS[:replace], mod["latest"])
        end
      end
    end

    # The page of a collection in the mod browser, in the dialog over the rows: its name with who
    # made it, how many mods it has and what installing it does, its summary, its mods with what
    # installing does with each, a line naming the mods the player installs by hand, and its
    # buttons.
    class BrowserCollectionPage < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :author => "Author",
        :mods => "Mods",
        :installing_it => "Installing it",
        :installs => "installs %d",
        :turns_on => "turns on %d",
        :changes_nothing => "changes nothing",
        :mods_in_it => "Mods in it",
        :install => "Install and turn on",
        :all_set => "All set",
        :page => "Open page",
        :back => "Back",
        :entry_installed => "Installed",
        :entry_install => "Install %s",
        :entry_update => "Update to %s",
        :entry_turn_on => "Turn on",
        :entry_unavailable => "Unavailable",
        :entry_tip => "The website no longer offers this mod.",
        :entry_other_platform => "Not available on this platform.",
        :entry_by_hand => "Install by hand",
        :entry_by_hand_tip => "Install it by hand from its page on the website.",
        :by_hand_one => "Install %s by hand from its page on the website.",
        :by_hand_more => "Install %s by hand from their pages on the website."
      }

      # The collection.
      param :collection, nil

      # The browser it lies in, which its buttons act through.
      param :browser, nil

      # Tells whether installing a collection changes anything.
      #
      # @param collection [Hash] The collection.
      # @return [Boolean] Whether it does.
      def self.todo?(collection)
        Array(collection["mods"]).any? { |entry| installs?(entry) || turns_on?(entry) }
      end

      # Tells whether installing the collection installs or updates one of its mods.
      #
      # @param entry [Hash] The mod, see ModsTopics.BrowseTopic.
      # @return [Boolean] Whether it does.
      def self.installs?(entry)
        entry["available"] && !entry["by_hand"] && [ModBrowser::AVAILABLE, ModBrowser::UPDATE].include?(entry["status"]) ? true : false
      end

      # Tells whether installing the collection only turns one of its mods on: installed, off, and
      # not updated.
      #
      # @param entry [Hash] The mod.
      # @return [Boolean] Whether it does.
      def self.turns_on?(entry)
        entry["available"] && entry["status"] != ModBrowser::AVAILABLE && !entry["on"] && !installs?(entry) ? true : false
      end

      # Tells whether the player installs or updates one of the collection's mods by hand.
      #
      # @param entry [Hash] The mod.
      # @return [Boolean] Whether they do.
      def self.by_hand?(entry)
        entry["available"] && entry["by_hand"] && [ModBrowser::AVAILABLE, ModBrowser::UPDATE].include?(entry["status"]) ? true : false
      end

      # Describes the page.
      def render
        entries = Array(collection["mods"])
        todo = BrowserCollectionPage.todo?(collection)
        labels = [TEXTS[:author], TEXTS[:mods], TEXTS[:installing_it]]
        stack spacing: 2, height: :fill do
          text collection["name"].to_s, typo: :h6, color: :system
          [[TEXTS[:author], collection["author"].to_s], [TEXTS[:mods], entries.size.to_s], [TEXTS[:installing_it], installing_text(entries)]].each do |label, value|
            field label, caption_width: labels, key: label do
              text value, typo: :body2
            end
          end
          summary = collection["summary"].to_s
          text summary, typo: :body2, wrap: true, most_lines: 3, visible: !summary.empty?
          text TEXTS[:mods_in_it], typo: :caption, color: :system
          list entries, id: :mf_browser_entries, height: :fill, rows_shown: :fill, row: ->(entry) { entry_row(entry) }, on_submit: ->(entry) { browser.show_in_mods(entry) }
          by_hand = by_hand_text(entries)
          text by_hand.to_s, typo: :body2, color: :warning, wrap: true, id: :mf_browser_collection_by_hand, visible: !by_hand.nil?
          stack row: true, spacing: 2 do
            button todo ? TEXTS[:install] : TEXTS[:all_set], id: :mf_browser_collection_install, grow: 1, disabled: !todo, autofocus: todo,
                   on_click: -> { browser.install_collection(collection) }
            button TEXTS[:page], id: :mf_browser_collection_page, grow: 1, visible: collection["page"] ? true : false, autofocus: !todo,
                   on_click: -> { browser.open_page_of(collection) }
            button TEXTS[:back], id: :mf_browser_back, grow: 1, on_click: :close
          end
        end
      end

      private

      # Tells what installing the collection does.
      #
      # @param entries [Array<Hash>] Its mods.
      # @return [String] Such as "installs 2, turns on 1", or "changes nothing".
      def installing_text(entries)
        installs = entries.count { |entry| BrowserCollectionPage.installs?(entry) }
        turns_on = entries.count { |entry| BrowserCollectionPage.turns_on?(entry) }
        parts = []
        parts << format(TEXTS[:installs], installs) if installs > 0
        parts << format(TEXTS[:turns_on], turns_on) if turns_on > 0
        parts.empty? ? TEXTS[:changes_nothing] : parts.join(", ")
      end

      # Tells the line naming the mods of the collection the player installs or updates by hand.
      #
      # @param entries [Array<Hash>] Its mods.
      # @return [String, nil] The line; nil for none.
      def by_hand_text(entries)
        names = entries.select { |entry| BrowserCollectionPage.by_hand?(entry) }.map { |entry| entry["name"].to_s }
        return nil if names.empty?

        format(names.size == 1 ? TEXTS[:by_hand_one] : TEXTS[:by_hand_more], UI.listed(names))
      end

      # Makes the row of a mod of the collection: its name and what installing the collection does
      # with it.
      #
      # @param entry [Hash] The mod, see ModsTopics.BrowseTopic.
      # @return [Hash] The row.
      def entry_row(entry)
        tip = entry["other_platform"] ? TEXTS[:entry_other_platform] : TEXTS[:entry_tip]
        return { :text => entry["name"].to_s, :right => TEXTS[:entry_by_hand], :right_color => :warning, :tooltip => TEXTS[:entry_by_hand_tip] } if BrowserCollectionPage.by_hand?(entry)

        text, color = if !entry["available"] then [TEXTS[:entry_unavailable], :dim]
                      elsif entry["status"] == ModBrowser::AVAILABLE then [format(TEXTS[:entry_install], entry["version"]), :warning]
                      elsif entry["status"] == ModBrowser::UPDATE then [format(TEXTS[:entry_update], entry["version"]), :gold]
                      elsif !entry["on"] then [TEXTS[:entry_turn_on], :warning]
                      else [TEXTS[:entry_installed], :dim]
                      end
        row = { :text => entry["name"].to_s, :right => text, :right_color => color }
        entry["available"] ? row : row.merge(:faint => true, :tooltip => tip)
      end
    end

    # The page of a mod or a collection over the mod browser, a dialog under the browser's bar that
    # opens at once as a card or a row is picked; cancel or Back closes it, the cursor still on that
    # card or row. It follows what the browser lists, such as a description that came.
    class BrowserPage < UI::Component
      # The id of the mod or the collection.
      param :item_id, nil

      # Whether it is a collection's page.
      param :collection, false

      # The browser it lies over, which its buttons act through.
      param :browser, nil

      # What the browser lists changes with the DLL's events.
      watch { Mod_Framework::Mods::Browser.serial }

      # Describes the dialog: the page of the mod or the collection as the browser lists it now, else
      # as it was listed last.
      def render
        @item = (collection ? browser.collection_by_id(item_id) : browser.mod_by_id(item_id)) || @item
        dialog nil, id: :mf_browser_page, anchor: :bottom, width: :screen, height: Graphics.height - ModBrowser::CARDS_ROOM do
          if collection
            component BrowserCollectionPage, collection: @item, browser: browser, key: item_id
          else
            component BrowserModPage, mod: @item, browser: browser, key: item_id
          end
        end
      end
    end

    # The change box of the mod browser, a dialog over it: what runs with a bar of how far it came,
    # closed by the browser on success; after a failure, why with Close.
    class ModChangeBox < UI::Component
      # The texts it shows, by what they say.
      TEXTS = { :title => "Mods", :wait => "Downloading and checking the files . . .", :close => "Close" }

      # Its id.
      ID = :mf_browser_change

      # The box's width.
      WIDTH = 400

      # It follows the change.
      watch { Mod_Framework::Mods::Browser.change_serial }

      # Describes the box.
      def render
        change = Browser.change || {}
        failed = change[:failed] ? true : false
        dialog TEXTS[:title], id: ID, width: WIDTH, on_cancel: -> { failed || UI.buzz("#{ID}: cancel waits for the change") || false } do
          text change[:text].to_s, wrap: true, key: :what
          progress value: (change[:rate].to_f * 100).round, visible: !failed
          text TEXTS[:wait], typo: :caption, color: :dim, visible: !failed, key: :wait
          stack row: true, justify: :end, visible: failed do
            button TEXTS[:close], id: :mf_browser_change_close, autofocus: failed, on_click: -> { close }
          end
        end
      end
    end

    # The dialog of a mod's pages in the mod browser: its page on the website and each of its
    # links, then Back.
    class BrowserLinks < UI::Component
      # The texts it shows, by what they say.
      TEXTS = { :title => "Pages of %s", :mod_page => "Mod page", :back => "Back" }

      # The mod.
      param :mod, nil

      # Tells the kind of the link picked, nil for the mod's page on the website.
      event :submit

      # Describes the dialog.
      def render
        pages = (mod["page"] ? [[nil, TEXTS[:mod_page], nil]] : []) +
                Array((mod["details"] || {})["links"]).map { |kind, url| [kind, BrowserModPage::LINK_NAMES[kind] || kind.to_s, url] }
        dialog format(TEXTS[:title], mod["name"]), id: :mf_browser_links do
          pages.each do |kind, name, url|
            button name, id: :"mf_browser_link_#{kind || 'site'}", tooltip: url, key: kind || :site, on_click: -> { close; emit(:submit, kind) }
          end
          button TEXTS[:back], id: :mf_browser_link_back, on_click: :close
        end
      end
    end
  end
end
