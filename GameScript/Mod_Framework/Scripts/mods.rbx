#----------------------------------------------------------------
#  mods.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Left out a folder whose scripts lie only in a Patch folder inside it
#      Paulinchen  2026-11-07: Named the website as the only host of a mod's page
#      Paulinchen  2026-11-06: Counted the framework's old name, which no release had, as a mod's name again
#      Paulinchen  2026-11-05: Listed the names of the mods that are on, read again after a change
#      Paulinchen  2026-11-01: Loaded a mod new to Mods.ini as Regular without the DLL, never by a tag its folder declares
#      Paulinchen  2026-10-30: Gave a mod new to Mods.ini the tag it declares without the DLL
#                            - Opened a link of a mod beyond its page
#                            - Opened a mod's page
#                            - Kept the plan last asked, with each mod's version
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The managed mods: every mod in the Patch folder, a script at its top with the folder of the same
  # name, or such a folder alone. Their state for the Mods screen, the plan the loader follows and
  # the player's changes; the DLL works them out from the cached list of the website,
  # Patch/Mod_Framework/Mods.ini and the Patch folder (ModsTopics.cs).
  #
  # Without the DLL there is no state and no change; the plan follows Mods.ini, whose lines the DLL
  # writes in the order the mods load, and adds a mod it lacks last by name as Regular.
  module Mods
    # The topic that lists the installed mods for the Mods screen.
    STATE_TOPIC = "mods.state"

    # The topic that plans the loading.
    PLAN_TOPIC = "mods.plan"

    # The topic that keeps the player's changes in Mods.ini.
    SET_TOPIC = "mods.set"

    # The event once the website was fetched, or could not be.
    FETCHED_TOPIC = "mods.fetched"

    # The topic that opens a mod's page in the player's browser.
    PAGE_TOPIC = "mods.page"

    # The folder of the mods, relative to the game folder.
    FOLDER = "Patch"

    # The player's choices, relative to the game folder.
    INI = "Patch/Mod_Framework/Mods.ini"

    # The names in the Patch folder that are no mod: the game's loader and the framework's entry
    # file and folder.
    NOT_MODS = %w[Patch !Mod_Framework Mod_Framework]

    # The extension of the scripts the game's loader evaluates.
    SCRIPT = ".rb"

    # The tags in the order their mods load.
    TAGS = %w[Framework Title Regular Data]

    # The tag of a mod neither a source nor a line tags.
    REGULAR = "Regular"

    # The first word of a line of a mod that is off.
    OFF = "off"

    # The plan last asked, nil before the first.
    @planned = nil

    # The names of the mods that are on, nil until on_names reads them again.
    @on_names = nil

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "mods"

    # Lists the installed mods in the order they load, each a Hash with "name", "title", "author",
    # "summary", "source", "page", "place", "tag", "tag_from", "on", "version", "latest", "update",
    # "id", "requires", "needs", "needed_by" and "warnings" (see ModsTopics.StateTopic).
    #
    # @return [Hash, nil] {"mods", "fetching", "site", "ini"}; nil without the DLL.
    def self.state
      Mod_Framework.available? ? Mod_Framework.bridge.call(STATE_TOPIC) : nil
    end

    # Plans the loading of the mods that are on.
    #
    # @return [Hash] {"load" => [[name, tag, place, version], ...] in the order they load,
    #   "warnings" => [[mod, kind, name, version], ...]}; without the DLL from Mods.ini, with no
    #   versions and no warnings.
    def self.plan
      planned = Mod_Framework.available? ? Mod_Framework.bridge.call(PLAN_TOPIC) : nil
      @planned = planned || plan_from_ini
    end

    # Tells the plan last asked, which the mods loaded since followed.
    #
    # @return [Hash, nil] See plan; nil before the first.
    def self.last_plan
      @planned
    end

    # Keeps the player's changes in Mods.ini.
    #
    # @param changes [Hash] {"on" => {name => Boolean}, "order" => [name, ...]}, each part optional.
    # @return [Hash, nil] The state after them with "written" and "refused"; nil without the DLL.
    def self.set(changes)
      @on_names = nil
      Mod_Framework.available? ? Mod_Framework.bridge.call(SET_TOPIC, changes) : nil
    end

    # Lists the names of the installed mods that are on, read once and again after the player
    # turned mods on or off or removed one; without the DLL those of the plan last asked.
    #
    # @return [Array<String>] The names, such as "Level_Cap".
    def self.on_names
      return @on_names if @on_names

      listed = state
      names = if listed.is_a?(Hash)
                Array(listed["mods"]).select { |mod| mod["on"] }.map { |mod| mod["name"].to_s }
              else
                Array((@planned || {})["load"]).map { |entry| entry[0].to_s }
              end
      @on_names = names
    end

    # Forgets the names of the mods that are on, so on_names reads them anew.
    def self.forget_on_names
      @on_names = nil
    end

    # Opens a mod's page on the website in the player's browser, or a link the website names for
    # it.
    #
    # @param id [String] The mod's id, as state names it.
    # @param link [String, nil] The kind of the link, such as "source"; nil for its page.
    # @return [Boolean] Whether it opened; false for a page elsewhere and without the DLL.
    def self.open_page(id, link = nil)
      request = { "id" => id.to_s }
      request["link"] = link.to_s if link
      answer = Mod_Framework.available? ? Mod_Framework.bridge.call(PAGE_TOPIC, request) : nil
      answer.is_a?(Hash) && answer["opened"] ? true : false
    end

    # Names the mod a file in the Patch folder belongs to.
    #
    # @param path [String] The file, relative to the game folder, with either slash, such as
    #   "Patch/Level_Cap.rb" or "Patch/Camp_Notes/Scripts/notes.rbx".
    # @return [String, nil] The script's name without its extension for a file at the top, else the
    #   name of the folder at the top; nil for a file outside Patch and for a name that is no mod.
    def self.name_of(path)
      inside = path.to_s.tr("\\", "/").sub(%r{\A(\./)+}, "")[%r{\A#{FOLDER}/(.+)\z}i, 1]
      return nil unless inside

      name = inside.include?("/") ? inside.split("/").first : File.basename(inside, File.extname(inside))
      mod_name?(name) ? name : nil
    end

    # Tells whether a name can be a mod's.
    #
    # @param name [String] The name.
    # @return [Boolean] Whether it is no name of NOT_MODS and Mods.ini can hold it.
    def self.mod_name?(name)
      !name.empty? && !name.include?("=") && NOT_MODS.none? { |other| other.casecmp(name) == 0 }
    end

    # Lists the mods in the Patch folder: each script at its top, and each folder there that holds a
    # script outside a Patch folder right inside it and has no script of its name beside it.
    #
    # @return [Array<String>] Their names, sorted.
    def self.names
      return [] unless File.directory?(FOLDER)

      found = {}
      (Dir.entries(FOLDER) - [".", ".."]).each do |entry|
        path = "#{FOLDER}/#{entry}"
        name = if File.directory?(path)
                 own_script_in?(path) ? entry : nil
               elsif File.extname(entry).downcase == SCRIPT
                 File.basename(entry, File.extname(entry))
               end
        found[name.downcase] ||= name if name && mod_name?(name)
      end
      found.values.sort_by { |name| name.downcase }
    rescue SystemCallError => e
      log("could not list the mods in #{FOLDER}: #{e.message}")
      []
    end

    # Tells whether a folder at the top of Patch holds a script of its own: in it, or below in a
    # folder not named Patch.
    #
    # A release zip extracted into Patch leaves its scripts in such a Patch folder, where they belong
    # to no mod and the loader names them in a message instead.
    #
    # @param folder [String] The folder, relative to the game folder.
    # @return [Boolean] Whether it does.
    def self.own_script_in?(folder)
      (Dir.entries(folder) - [".", ".."]).any? do |entry|
        path = "#{folder}/#{entry}"
        if File.directory?(path)
          entry.casecmp(FOLDER) != 0 && script_in?(path)
        else
          File.extname(entry).downcase == SCRIPT
        end
      end
    end

    # Tells whether a folder holds a script, in it or below.
    #
    # @param folder [String] The folder, relative to the game folder.
    # @return [Boolean] Whether it does.
    def self.script_in?(folder)
      (Dir.entries(folder) - [".", ".."]).any? do |entry|
        path = "#{folder}/#{entry}"
        File.directory?(path) ? script_in?(path) : File.extname(entry).downcase == SCRIPT
      end
    end

    # Plans the loading from Mods.ini alone.
    #
    # @return [Hash] {"load" => [[name, tag, place, nil], ...], "warnings" => []}.
    def self.plan_from_ini
      named = {}
      names.each { |name| named[name.downcase] = name }
      load = []
      ini_lines.each do |key, value|
        name = named.delete(key.downcase)
        next unless name

        words = value.split(" ")
        next if words.first.to_s.downcase == OFF

        load << [name, TAGS.find { |tag| tag.downcase == words[1].to_s.downcase } || REGULAR]
      end
      named.values.sort_by { |name| name.downcase }.each { |name| load << [name, REGULAR] }
      log_once(:without_dll, "without the DLL the mods load in the order of Mods.ini, #{load.size} of them") unless Mod_Framework.available?
      ordered = load.each_with_index.sort_by { |(_name, tag), index| [TAGS.index(tag), index] }.map { |entry, _index| entry }
      { "load" => ordered.map { |name, tag| [name, tag, FOLDER, nil] }, "warnings" => [] }
    end

    # Reads the lines of Mods.ini.
    #
    # @return [Array<Array(String, String)>] Each line's name and value in the file's order; none
    #   when the file is missing or cannot be read.
    def self.ini_lines
      return [] unless File.file?(INI)

      File.read(INI, :encoding => "BOM|UTF-8").split("\n").map { |line| line.split("=", 2) }.select { |pair| pair.size == 2 }.map { |key, value| [key.strip, value.strip] }
    rescue SystemCallError, ArgumentError => e
      log("could not read #{INI}: #{e.message}")
      []
    end
  end
end
