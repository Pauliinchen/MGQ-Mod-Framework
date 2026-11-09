#----------------------------------------------------------------
#  mods_screen.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Called the group of the Regular mods Default
#      Paulinchen  2026-11-07: Drew the mod list as a menu of its own named Mod List, without tabs
#                            - Opened the Mod Configuration
#      Paulinchen  2026-11-06: Read whether the gamepad was used last through UI.pad?
#                            - Drew the screen as a component of the UI layer, its tabs no key stop, the restart bar and the
#                              notice line as alerts and the restart lines kept with the restart
#                            - Left hiding the title's commands to the title's Mods box that opens the screen
#      Paulinchen  2026-11-05: Moved the mod by the framework's hotkeys under their new names, Move Up and Move Down
#      Paulinchen  2026-11-03: Said Failed to load last time for a mod that failed in an earlier game session
#      Paulinchen  2026-11-01: Moved the mod under the list's cursor within its tag by the framework's move hotkeys and
#                              named their keys in the key help
#                            - Made the row of tabs one key stop above the pages, reached by Up and left by Down
#                            - Took the tag switch off the screen, since only a mod's authors tag it, and showed beside
#                              the list only the mod's name, its description and what it needs
#                            - Named the keys of the list and of the mod's side in a key help at the page's foot
#                            - Opened on the first mod under the framework's row, which has no box and reads Always on
#                            - Told a refused change on a notice line at the window's foot instead of a status line
#                            - Opened the screen on the tab a title command asks for
#                            - Left the confirm sound to the title commands that open the screen
#                            - Followed no change of the mods when F12 closes the screen
#      Paulinchen  2026-10-31: Kept the status line to the mod it tells of and told the state a Title script turned on in
#                              the window will have
#                            - Told the states in plain words without their causes
#                            - Named the folder of the framework's copy, which may lie inside a mod's folder
#      Paulinchen  2026-10-30: Told how a plain Title script the framework split stands and listed one that loads whole
#                              under Framework with why
#                            - Moved the scripts loaded whole among themselves, told how a script turned on at the title
#                              loads and kept the changes at a title that counts as entered for the restart bar
#                            - Turned a Title mod off without a restart and told when one loads whole at the title
#                            - Warned of mods on together that do not work together and of an order against an author's
#                              load order hint, asked before turning on a mod that does not work with one that is on,
#                              and told when saves may need a mod turned off
#                            - Showed the options of the mods loaded at the title and every hotkey on tabs of their own
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # Opens the Mod List at the title and keeps what it shares between openings: the tags the
    # mods had as it first opened in this game session and the descriptions the DLL fetched.
    module Screen
      # The id of the Mod List's window.
      ID = :mf_mods

      # The words a reason may start with that read in lower case after "Nothing changed:": articles
      # and pronouns, never a mod's name.
      PLAIN_STARTS = /\A(?:The|A|An|Your|Its|It|This|These|No)\b/

      # The tag each mod had as the screen first opened in this game session.
      @first_tags = nil

      # The lines of each description fetched since the screen opened, by the mod's id, or :failed.
      @descriptions = {}

      # How often a fetched description came, which renders the screen again.
      @described_count = 0

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "mods screen"

      class << self
        # @return [Hash{String => String}, nil] The tag each mod had as the screen first opened.
        attr_accessor :first_tags

        # @return [Hash{String => Object}] The descriptions fetched since the screen opened.
        attr_reader :descriptions

        # @return [Integer] How often a fetched description came.
        attr_reader :described_count
      end

      # Tells a reason as it reads after "Nothing changed:", its first word in lower case where it is
      # an article or a pronoun.
      #
      # @param why [String] The reason, such as "The website could not be reached.".
      # @return [String] Such as "the website could not be reached.".
      def self.reason(why)
        why.to_s.sub(PLAIN_STARTS) { |word| word.downcase }
      end

      # Opens the Mod List, one at a time; the same menu open again takes the focus.
      #
      # @param quiet [Boolean] Whether what opened it played the confirm sound, such as the title's
      #   Mods box, so the menu plays none.
      # @return [Object, nil] The menu's handle, nil without the DLL or its list of mods.
      def self.open(quiet = false)
        return nil unless Mod_Framework.available?

        state = Mods.state
        return nil unless state.is_a?(Hash)

        self.first_tags ||= Hash[Array(state["mods"]).map { |mod| [mod["name"], mod["tag"]] }]
        @descriptions = {}
        UI.confirm_sound unless quiet
        log("opened #{ID}")
        UI.open(ModsScreen)
      end

      # Opens the Mod Configuration, one at a time; the same menu open again takes the focus.
      #
      # @param quiet [Boolean] Whether what opened it played the confirm sound, such as the title's
      #   Mods box, so the menu plays none.
      # @return [Object, nil] The menu's handle, nil without the DLL or its list of mods.
      def self.open_config(quiet = false)
        return nil unless Mod_Framework.available? && Mods.state.is_a?(Hash)

        UI.confirm_sound unless quiet
        log("opened #{ModsConfiguration::ID}")
        UI.open(ModsConfiguration)
      end

      # Takes a description whose fetch ended, its summary in its place when the fetch failed, and
      # has the screen show it.
      #
      # @param event [Hash, nil] The event of mods.described, {"id"}.
      def self.described(event)
        return unless event.is_a?(Hash) && event["id"] && Mods.respond_to?(:describe)

        answer = Mods.describe(event["id"], false)
        lines = answer.is_a?(Hash) ? answer["lines"] : nil
        @descriptions[event["id"]] = lines ? Array(lines) : :failed
        @described_count += 1
      end
    end

    # The Mod List at the title, a window of the UI layer: every mod of the Patch folder under its
    # tag, each turned on and off by confirm or a click on its box and moved within its tag by the
    # framework's hotkeys Move Up and Move Down or a drag, the mod under the cursor beside the list
    # with its name, description and needs. A notice line at the window's foot tells a change that
    # was refused, and the restart bar there names the changes that count only once the game starts
    # again.
    class ModsScreen < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :title => "Mod List",
        :heading => "%s · %d",
        :regular => "Default",
        :framework => "Mod Framework",
        :always_on => "Always on",
        :about => "About",
        :needs => "Needs",
        :none => "None",
        :framework_about => "Every mod here runs on it. It is always on.",
        :describing => "Loading the description . . .",
        :no_text => "No description.",
        :not_on_site_about => "No description. It is not on the website.",
        :note_failed => "Failed to load",
        :note_failed_before => "Failed to load last time",
        :note_needs => "Needs %s",
        :note_needs_more => "Needs %d mods",
        :note_order => "Loads before %s",
        :note_after => "Loads after %s",
        :note_conflict => "Conflicts with %s",
        :note_conflicts => "Conflicts with %d mods",
        :note_off_after => "Off after restart",
        :note_update => "Update %s",
        :note_changed => "Changed copy",
        :note_unknown => "Not on the site",
        :need_on => "%s %s: on",
        :need_on_any => "%s: on",
        :need_off => "%s: off",
        :need_missing => "%s: not installed",
        :need_version => "%s %s: you have %s",
        :off_ask => "%s %s. Turn it off anyway?",
        :off_yes => "Turn it off",
        :off_no => "Keep it on",
        :conflict_ask => "%s does not work with %s, %s%s Turn it on anyway?",
        :which_is_on => "which is on",
        :which_are_on => "which are on",
        :conflict_yes => "Turn it on",
        :conflict_no => "Keep it off",
        :on_ask => "%s needs %s, %s. %s",
        :which_is_off => "which is off",
        :which_are_off => "which are off",
        :turn_one_on => "Turn %s on too?",
        :turn_them_on => "Turn them on too?",
        :both_on => "Turn both on",
        :all_on => "Turn all on",
        :only => "Only %s",
        :restart_now => "Restart now",
        :not_kept => "Nothing changed: %s",
        :ini_unwritable => "Your changes could not be saved.",
        :more => "%d more",
        :help_toggle => "On / off",
        :help_close => "Close",
        :help_back => "Back"
      }

      # The window's size, and its least height: the player resizes its height between them.
      SIZE = [640, 480]
      LEAST_HEIGHT = 400

      # The width of the list of the mods.
      LIST_WIDTH = 302

      # The least height of the box of the description.
      TEXT_LEAST = 36

      # The height of a line of what a mod needs.
      NEED_ROW = 18

      # Where the notes of the list's rows start, from the rows' left.
      NOTE_AT = 170

      # The most lines of what a mod needs the side shows, the last of them "+N more" once more
      # are left out.
      SHOWN_NEEDS = 3

      # The most names a question names before "N more".
      SHOWN_NAMES = 3

      # The name a requirement gives the framework by.
      FRAMEWORK_NAME = "Mod_Framework"

      # The installed mods as the DLL last told them, see Mods.state.
      state(:listed) { Mods.state || {} }

      # The name of the mod under the list's cursor: the first mod under the framework's row as it
      # opens, which can be turned off at once.
      state(:picked) { first_name(listed) }

      # A change that was refused: the name of the mod it was for and what the notice line says,
      # nil for none.
      state :refusal

      # Whether the focus is on the mod's text beside the list.
      state :reading, false

      # A description fetched later renders it again.
      watch { Screen.described_count }

      # Describes the menu: the list beside the mod's side, the key help, the notice line and the
      # restart bar.
      def render
        all = all_mods
        notice = refusal && refusal[0] == picked ? refusal[1] : nil
        window TEXTS[:title], id: Screen::ID, width: SIZE[0], height: SIZE[1], min_size: [SIZE[0], LEAST_HEIGHT], max_size: SIZE,
                              resizable: :height, on_close: ->(why) { closed(why) } do
          mods_page(all)
          alert notice.to_s, severity: :error, dense: true, id: :mf_mods_notice, visible: !notice.nil?
          restart_bar(all, !notice.nil?)
        end
      end

      private

      # Describes the list beside the mod's side, and the key help under both.
      #
      # @param all [Array<Hash>] Every mod, the framework's own first.
      def mods_page(all)
        mod = all.find { |each| each["name"] == picked }
        stack row: true, height: :fill do
          list list_items(all), bind: :picked, id: :mf_mods_list, row: ->(item) { row_of(item, all) }, group: ->(item) { group_of(mod_named(item, all)) },
                                reorder: :within_group, move_hotkeys: true, note_at: NOTE_AT, width: LIST_WIDTH, height: :fill, rows_shown: :fill,
                                autofocus: true, on_change: ->(item) { cursor_moved(item) }, on_submit: ->(item) { toggle(item) },
                                on_reorder: ->(item, to) { move(item, to) }
          side_of(mod, all) if mod
        end
        key_help entries: key_entries, auto: !reading, id: :mf_mods_keys
      end

      # Describes the mod's side: its name and version, About in a box the keys stop on and scroll,
      # and what it needs.
      #
      # @param mod [Hash] The mod.
      # @param all [Array<Hash>] Every mod.
      def side_of(mod, all)
        needs = need_lines(mod)
        stack id: :mf_mods_side, width: :fill, height: :fill do
          stack row: true do
            text mod["title"].to_s, typo: :h6, grow: 1, min_font_size: 14
            version, color = version_of(mod)
            text version, typo: :caption, color: color if version
          end
          paper id: :mf_mods_text, scroll: :vertical, focusable: true, grow: 1, min_size: [0, TEXT_LEAST], key: mod["name"],
                on_enter: -> { self.reading = true }, on_leave: -> { self.reading = false } do
            text TEXTS[:about], typo: :caption, color: :system
            description_of(mod).each_with_index { |line, place| text line.to_s, typo: :body2, wrap: true, key: place }
          end
          text TEXTS[:needs], typo: :caption, color: :system
          lines needs, empty: TEXTS[:none], size: :small, height: NEED_ROW * [[needs.size, 1].max, SHOWN_NEEDS].min, key: mod["name"]
        end
      end

      # Describes the restart bar at the window's foot, while a change waits for the game to start
      # again and no notice shows: one change's line, or how many wait with each one's line as its
      # tooltip.
      #
      # @param all [Array<Hash>] Every mod.
      # @param noticed [Boolean] Whether the notice line shows in its place.
      def restart_bar(all, noticed)
        lines = Mods.restart_lines(all)
        params = { severity: :warning, id: :mf_restart_bar, visible: !lines.empty? && !noticed }
        params[:tooltip] = lines.join("\n") if lines.size > 1
        alert(lines.empty? ? "" : Mods.restart_text(lines), params) do
          button TEXTS[:restart_now], variant: :outlined, on_click: -> { restart }
        end
      end

      # Tells the entries of the key help: confirm and cancel while the list holds the focus, the move
      # hotkeys and the jump keys added by the key help itself; only cancel while the mod's text does.
      #
      # @return [Array<Hash>] The entries.
      def key_entries
        return [{ button: :B, text: TEXTS[:help_back] }] if reading

        [{ button: :C, text: TEXTS[:help_toggle] }, { button: :B, text: TEXTS[:help_close] }]
      end

      # Lists every mod as the list shows it: the framework's own first.
      #
      # @return [Array<Hash>] The mods.
      def all_mods
        [framework_mod] + Array(listed["mods"])
      end

      # Tells the name of the first mod under the framework's row, which the cursor opens on.
      #
      # @param state [Hash] The installed mods.
      # @return [String, nil] Its name, nil for only the framework.
      def first_name(state)
        first = groups([framework_mod] + Array(state["mods"])).map { |_title, members| members }.flatten(1).find { |mod| !fixed?(mod) }
        first ? first["name"] : FRAMEWORK_NAME
      end

      # Lists the list's items: a heading per group with its count, then the names of its mods.
      #
      # @param all [Array<Hash>] Every mod.
      # @return [Array] The headings, each { text:, heading: true }, and the names.
      def list_items(all)
        groups(all).map { |title, members| [{ text: format(TEXTS[:heading], title == REGULAR ? TEXTS[:regular] : title, members.size), heading: true }] + members.map { |mod| mod["name"] } }.flatten(1)
      end

      # Sorts the mods into the groups the list shows, in the order they load, a Title mod that loads
      # whole at the end of Framework; Data only once a Data mod is there, no group without mods.
      #
      # @param all [Array<Hash>] Every mod.
      # @return [Array<Array>] Each group's title and its mods.
      def groups(all)
        whole = all.select { |mod| whole?(mod) }
        TAGS.map { |tag| [tag, all.select { |mod| mod["tag"] == tag } - whole + (tag == FRAMEWORK_TAG ? whole : [])] }.reject { |_title, members| members.empty? }
      end

      # Finds a mod by its name.
      #
      # @param name [String, Hash] The name, or a heading.
      # @param all [Array<Hash>] Every mod.
      # @return [Hash, nil] The mod, nil for a heading.
      def mod_named(name, all)
        all.find { |mod| mod["name"] == name }
      end

      # Describes an item's row: a heading as it is; a mod's box (none for the framework), its name
      # and the one note that matters most.
      #
      # @param item [String, Hash] A mod's name, or a heading.
      # @param all [Array<Hash>] Every mod.
      # @return [Hash] The row.
      def row_of(item, all)
        mod = mod_named(item, all)
        return item unless mod

        note, color = note_of(mod, all)
        { text: mod["title"].to_s, check: fixed?(mod) ? nil : (mod["on"] ? true : false), note: note, note_color: color }
      end

      # Tells whether a mod tagged Title loads whole as a Framework mod, listed at the end of
      # Framework, since Mods.ini keeps its tag.
      #
      # @param mod [Hash] The mod.
      # @return [Boolean] Whether it does.
      def whole?(mod)
        mod["tag"] == TITLE_TAG && !fixed?(mod) && Mods.loads_as_framework?(mod["name"])
      end

      # Tells the group a mod's row moves within: the framework's a group of its own, so nothing
      # moves past it; the Title mods that load whole one together, so they move only among
      # themselves; every other mod its tag's.
      #
      # @param mod [Hash, nil] The mod; nil for a heading.
      # @return [Object] The group.
      def group_of(mod)
        return nil unless mod
        return [:fixed, mod["name"]] if fixed?(mod)

        whole?(mod) ? [:whole] : mod["tag"]
      end

      # Tells the one note of a row that matters most.
      #
      # @param mod [Hash] The mod.
      # @param all [Array<Hash>] Every mod.
      # @return [Array] The note and its color; nil for none.
      def note_of(mod, all)
        return [TEXTS[:always_on], :dim] if fixed?(mod)
        return [Mods.failed_now?(mod["name"]) ? TEXTS[:note_failed] : TEXTS[:note_failed_before], :error] if failure(mod)

        clashing = mod["on"] ? Array(mod["conflicts"]).select { |conflict| conflict[2] } : []
        return [clashing.size == 1 ? format(TEXTS[:note_conflict], clashing[0][0]) : format(TEXTS[:note_conflicts], clashing.size), :error] unless clashing.empty?

        missing = mod["on"] ? unmet(mod) : []
        return [missing.size == 1 ? format(TEXTS[:note_needs], missing[0][0]) : format(TEXTS[:note_needs_more], missing.size), :warning] unless missing.empty?

        later = Array(mod["warnings"]).find { |kind, _name, _version| %w[order loads_before loads_after].include?(kind) }
        return [format(later[0] == "loads_after" ? TEXTS[:note_after] : TEXTS[:note_order], title_of(later[1], all)), :warning] if later
        return [TEXTS[:note_off_after], :warning] if Mods.off_after_restart?(mod)
        return [format(TEXTS[:note_update], mod["latest"]), :gold] if mod["update"]
        return [TEXTS[:note_changed], :warning] if changed_copy?(mod)
        return [TEXTS[:note_unknown], :dim] unless mod["id"]

        [nil, nil]
      end

      # Lists a mod's requirements that are not met: off, missing or too old.
      #
      # @param mod [Hash] The mod.
      # @return [Array<Array>] Each need, see ModsTopics.StateTopic.
      def unmet(mod)
        Array(mod["needs"]).reject { |need| need[2] == "on" }
      end

      # Finds a mod's title by its name.
      #
      # @param name [String] The mod's name.
      # @param all [Array<Hash>] Every mod.
      # @return [String] Its title, else the name.
      def title_of(name, all)
        found = mod_named(name, all)
        found ? found["title"].to_s : name.to_s
      end

      # Tells the version beside the mod's name: the installed one, "?" for a changed copy.
      #
      # @param mod [Hash] The mod.
      # @return [Array] The text and its color; nil for a mod no source knows.
      def version_of(mod)
        return ["?", :warning] if changed_copy?(mod)
        return [nil, nil] unless mod["framework"] || mod["id"]

        [mod["version"].to_s, :dim]
      end

      # Tells the lines of a mod's description: the website's for a mod of the website, asked of
      # the DLL the first time, a line that says it loads while it comes and its summary when it
      # failed; another mod's summary.
      #
      # @param mod [Hash] The mod.
      # @return [Array<String>] The lines.
      def description_of(mod)
        return [TEXTS[:framework_about]] if fixed?(mod)
        return [TEXTS[:not_on_site_about]] unless mod["id"]

        known = Screen.descriptions[mod["id"]]
        return known if known.is_a?(Array)

        answer = mod["source"] == "site" && known != :failed && Mods.respond_to?(:describe) ? Mods.describe(mod["id"]) : nil
        lines = answer.is_a?(Hash) && answer["lines"]
        return Screen.descriptions[mod["id"]] = Array(lines) if lines
        return [TEXTS[:describing]] if answer.is_a?(Hash) && answer["fetching"]

        summary = mod["summary"].to_s
        [summary.empty? ? TEXTS[:no_text] : summary]
      end

      # Makes the lines of a mod's requirements, each in the color of how it stands.
      #
      # @param mod [Hash] The mod.
      # @return [Array<Hash>] The lines.
      def need_lines(mod)
        Array(mod["needs"]).map do |name, version, state, have, _folder|
          case state
          when "on"
            shown = version.to_s.empty? ? have.to_s : version.to_s
            { text: shown.empty? || shown == "?" ? format(TEXTS[:need_on_any], name) : format(TEXTS[:need_on], name, shown), color: :success }
          when "off" then { text: format(TEXTS[:need_off], name), color: :warning }
          when "missing" then { text: format(TEXTS[:need_missing], name), color: :error }
          else { text: format(TEXTS[:need_version], name, version, have), color: :warning }
          end
        end
      end

      # Follows the cursor: a notice of another mod goes.
      #
      # @param item [String, Hash, nil] The name of the mod the cursor moved to.
      def cursor_moved(item)
        self.refusal = nil if refusal && refusal[0] != item
      end

      # Turns the mod of a row on or off, asking first where other mods need it or it needs a mod
      # that is off; the framework's row buzzes.
      #
      # @param item [String] The mod's name.
      def toggle(item)
        mod = mod_named(item, all_mods)
        return UI.buzz unless mod
        return UI.buzz("the framework is always on") if fixed?(mod)

        mod["on"] ? turn_off(mod) : turn_on(mod)
      end

      # Turns a mod off; first asks when mods that are on need it, Keep it on lit.
      #
      # @param mod [Hash] The mod.
      def turn_off(mod)
        needers = Array(mod["needed_by"])
        return set_on(mod, false) if needers.empty?

        question = format(TEXTS[:off_ask], named(needers), needers.size == 1 ? "needs #{mod['title']}" : "need #{mod['title']}")
        UI.confirm(question, yes: TEXTS[:off_yes], no: TEXTS[:off_no]) { |yes| yes ? set_on(mod, false) : kept(mod, "on") }
      end

      # Turns a mod on; first asks whether to turn it on beside the mods that are on it does not
      # work with, Keep it off lit, then whether to turn on too the mods it needs that are off.
      #
      # @param mod [Hash] The mod.
      def turn_on(mod)
        clashing = Array(mod["conflicts"]).select { |conflict| conflict[2] }
        return turn_on_needing(mod) if clashing.empty?

        note = clashing.size == 1 ? clashing[0][1].to_s.strip : ""
        ending = note.empty? ? "." : ": #{note}#{note =~ /[.!?]\z/ ? '' : '.'}"
        question = format(TEXTS[:conflict_ask], mod["title"], UI.listed(clashing.map { |conflict| conflict[0] }), clashing.size == 1 ? TEXTS[:which_is_on] : TEXTS[:which_are_on], ending)
        UI.confirm(question, yes: TEXTS[:conflict_yes], no: TEXTS[:conflict_no]) { |yes| yes ? turn_on_needing(mod) : kept(mod, "off") }
      end

      # Turns a mod on; first asks whether to turn on too the mods it needs that are off.
      #
      # @param mod [Hash] The mod.
      def turn_on_needing(mod)
        off = Array(mod["needs"]).select { |need| need[2] == "off" && !need[4].to_s.empty? }
        return set_on(mod, true) if off.empty?

        names = off.map { |need| need[0] }
        ask = off.size == 1 ? format(TEXTS[:turn_one_on], names[0]) : TEXTS[:turn_them_on]
        question = format(TEXTS[:on_ask], mod["title"], UI.listed(names), off.size == 1 ? TEXTS[:which_is_off] : TEXTS[:which_are_off], ask)
        yes = off.size == 1 ? TEXTS[:both_on] : TEXTS[:all_on]
        UI.confirm(question, yes: yes, no: format(TEXTS[:only], mod["title"])) { |both| set_on(mod, true, both ? off.map { |need| need[4] } : []) }
      end

      # Logs that the player kept a mod as it was in a question.
      #
      # @param mod [Hash] The mod.
      # @param how [String] "on" or "off".
      def kept(mod, how)
        Screen.log("#{mod['name']} stays #{how}, as the player answered in #{Screen::ID}")
      end

      # Names mods in a question, the first two and how many more past SHOWN_NAMES.
      #
      # @param names [Array<String>] The names.
      # @return [String] Such as "Map Display, Party Sheet and 2 more".
      def named(names)
        names.size > SHOWN_NAMES ? UI.listed(names.first(SHOWN_NAMES - 1) + [format(TEXTS[:more], names.size - SHOWN_NAMES + 1)]) : UI.listed(names)
      end

      # Turns mods on or off in Mods.ini with the cursor's sound.
      #
      # @param mod [Hash] The mod.
      # @param on [Boolean] Whether it turns on.
      # @param also [Array<String>] The names of mods that turn on with it.
      def set_on(mod, on, also = [])
        changes = { mod["name"] => on }
        also.each { |name| changes[name] = true }
        Screen.log("#{Screen::ID} turns #{changes.map { |name, value| "#{name} #{value ? 'on' : 'off'}" }.join(', ')}")
        Sound.play_cursor if take_answer(Mods.set("on" => changes), mod["name"])
      end

      # Keeps the order of a mod's group once the player moved its row by a step or a drag.
      #
      # @param item [String] The mod's name.
      # @param to [Integer] Its new place among the list's items.
      def move(item, to)
        all = all_mods
        items = list_items(all).reject { |each| each == item }
        items.insert(to, item)
        group = group_of(mod_named(item, all))
        names = items.select { |each| each.is_a?(String) && group_of(mod_named(each, all)) == group }
        Screen.log("#{Screen::ID} moves #{item} to place #{names.index(item) + 1} of its group")
        take_answer(Mods.set("order" => names), item)
      end

      # Starts the game again, as the restart bar's button does.
      def restart
        Mods.restart("the player restarted from the Mod List")
      end

      # Takes the state a change answers, which the rows show from then on; a change made whole ends
      # a notice, and one refused in whole or in part tells why on the notice line with the buzzer.
      #
      # @param answer [Hash, nil] The state after the change, see Mods.set.
      # @param name [String] The name of the mod the change was for.
      # @return [Boolean] Whether the whole change was made.
      def take_answer(answer, name)
        written = answer.is_a?(Hash) && answer["written"]
        self.listed = answer if written
        refused = answer.is_a?(Hash) ? answer["refused"] : nil
        why = refused.is_a?(String) ? refused : Array(refused).map { |_name, reason| reason }.first
        if written && why.nil?
          self.refusal = nil
          return true
        end

        text = format(TEXTS[:not_kept], Screen.reason(why || TEXTS[:ini_unwritable]))
        Screen.log("#{Screen::ID} refused the change of #{name}: #{text}")
        UI.buzz
        self.refusal = [name, text]
        false
      end

      # Tells whether a mod is the framework, which is always on and never moves.
      #
      # @param mod [Hash] The mod.
      # @return [Boolean] Whether it is.
      def fixed?(mod)
        mod["framework"] ? true : false
      end

      # Tells whether a mod is a copy that matches no version its source knows.
      #
      # @param mod [Hash] The mod.
      # @return [Boolean] Whether it is.
      def changed_copy?(mod)
        mod["id"] && mod["version"] == "?" ? true : false
      end

      # Tells why a mod failed to load in this game session or the last one.
      #
      # @param mod [Hash] The mod.
      # @return [String, nil] Why, nil when it did not fail.
      def failure(mod)
        fixed?(mod) ? nil : Mods.failed_last(mod["name"])
      end

      # Tells the framework's own row's mod.
      #
      # @return [Hash] The mod, as the state names a mod.
      def framework_mod
        { "name" => FRAMEWORK_NAME, "title" => TEXTS[:framework], "framework" => true, "on" => true, "tag" => FRAMEWORK_TAG,
          "version" => Mod_Framework::VERSION, "place" => Mod_Framework::FOLDER, "needs" => [], "needed_by" => [] }
      end

      # Follows the screen's close: the title's commands and its Mods box follow the mods turned on
      # and off; a mod whose website tag changed while the game ran keeps its new tag for the next
      # start. F12 changes nothing.
      #
      # @param why [Symbol, String] Why it closed.
      def closed(why)
        return if why == :reset

        mods = Array(listed["mods"])
        retagged = (Screen.first_tags || {}).select { |name, tag| (mods.find { |mod| mod["name"] == name } || {})["tag"] != tag }.keys
        Loader.follow_changes(mods.select { |mod| mod["on"] }.map { |mod| mod["name"] }, retagged)
        Title.show_badges
      end
    end

    # The screen takes the descriptions with a handler of its own, beside the mod browser's.
    Mod_Framework.bridge.on("mods.described") { |event| Mod_Framework::Mods::Screen.described(event) }
  end
end
