#----------------------------------------------------------------
#  logging.rbx
#
#  Changelog:
#      Paulinchen  2026-10-29: Let a mod write a line into the framework's log
#      Paulinchen  2026-10-28: Moved into the Mod Framework from core_log.rbx, with the log writer of Multiplayer.rb
#      Paulinchen  2026-10-10: Made log and log_once return nil
#      Paulinchen  2026-10-07: Added failure
#                            - Added short and named
#      Paulinchen  2026-10-04: Renamed from mp_log.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # Writes a line of a mod into the framework's log, as a mod without a log of its own does.
  #
  # @param message [String] The line.
  # @return [nil] Always.
  def self.log(message)
    Log.write(message.to_s)
    nil
  end

  # The framework's log: each line goes to the DLL's log of the day, Logs/Mod Framework
  # <day>.log, which holds the DLL's lines too, through the bridge, staged with the rest of the
  # frame. Lines written before the bridge opens wait for it; without the DLL the scripts write
  # them into that file themselves.
  #
  # Writing a line never raises, since the log must never interrupt the game.
  module Log
    # The topic of one line, [time of day, line], see ScriptLog.cs.
    TOPIC = "log.write"

    # The topic that writes every line handed over at once.
    FLUSH_TOPIC = "log.flush"

    # How the time of day starts each line.
    TIME = "%H:%M:%S"

    # The most lines kept while the bridge has not opened yet.
    EARLY_LINES = 1000

    # The file the scripts write without the DLL, named after the day as the DLL names it.
    OWN_FILE = "Mod Framework %s.log"

    # How the day shows in OWN_FILE.
    STAMP = "%Y-%m-%d"

    # The folder in the game folder that holds the logs of every mod.
    FOLDER = "Logs"

    # What starts each line in OWN_FILE, as the DLL starts the scripts' lines (ScriptLog.Mark).
    MARK = "[script] "

    # The encodings a line crosses the bridge in as text; any other crosses as its bytes.
    # Named, since the Encoding constants are missing in the game.
    TEXT_ENCODINGS = [Encoding.find("UTF-8"), Encoding.find("US-ASCII")]

    # The lines written before the bridge opened, each [time, line]; nil once handed over.
    @early = []

    # The path of OWN_FILE without the DLL, nil while the lines go to the DLL.
    @own_file = nil

    # Appends a line, stamped with the time of day.
    #
    # @param message [String] The line to append.
    # @return [nil] Always.
    def self.write(message)
      line = [Time.now.strftime(TIME), plain(message.to_s)]
      if @early
        @early << line if @early.size < EARLY_LINES
      elsif @own_file
        append(line)
      else
        Mod_Framework.bridge.stage(TOPIC, line)
      end
      nil
    rescue
      nil
    end

    # Hands the lines written so far over once the start decided: to the DLL when the bridge
    # opened, else into OWN_FILE, where every later line goes too. Only the first call acts.
    #
    # @param open [Boolean] Whether the bridge opened.
    def self.settle(open)
      lines = @early
      return unless lines

      @early = nil
      if open
        lines.each { |line| Mod_Framework.bridge.stage(TOPIC, line) }
      else
        Dir.mkdir(FOLDER) unless File.directory?(FOLDER)
        @own_file = "#{FOLDER}/#{format(OWN_FILE, Time.now.strftime(STAMP))}"
        lines.each { |line| append(line) }
      end
    rescue
      nil
    end

    # Hands every line over at once and has the DLL write them, as the game closes or stops on an
    # error.
    def self.flush
      return settle(false) if @early
      return if @own_file

      Mod_Framework.bridge.flush
      Mod_Framework.bridge.call(FLUSH_TOPIC)
      nil
    rescue
      nil
    end

    # Appends a line to OWN_FILE.
    #
    # @param line [Array<String>] The time and the line.
    def self.append(line)
      File.open(@own_file, "ab") { |file| file.write("#{line[0]}  #{MARK}#{line[1]}\r\n") }
    end

    # Makes a line one that crosses the bridge.
    #
    # @param text [String] The line.
    # @return [String] The line, or its bytes when it is no valid text, such as one built from
    #   bytes the DLL handed over.
    def self.plain(text)
      TEXT_ENCODINGS.include?(text.encoding) && text.valid_encoding? ? text : text.dup.force_encoding("ASCII-8BIT")
    end
  end

  # Writes a module's lines into the framework's log. A script's module extends this and starts
  # each of its lines with its LOG_TAG, such as "settings".
  #
  # Writing a line never raises, since the log must never interrupt the game.
  module Logging
    # What was logged once already, by the module and its key.
    @logged = {}

    # Notes that a module logs a line it logs only once.
    #
    # @param owner [Module] The module.
    # @param key [Object] What tells the line from the module's other lines.
    # @return [Boolean] Whether this is the first time.
    def self.first_time?(owner, key)
      return false if @logged[[owner, key]]

      @logged[[owner, key]] = true
    end

    # Shortens a text for a line of the log, keeping it on one line.
    #
    # @param text [Object] The text.
    # @param length [Integer] The most characters kept.
    # @return [String] The text, cut with "..." when longer.
    def self.short(text, length = 80)
      text = text.to_s.gsub(/[\r\n]+/, " ")
      text.length > length ? "#{text[0, length - 3]}..." : text
    rescue
      "?"
    end

    # Names an entry of the game's database with its id, such as "517 Puruel", for a line of the
    # log.
    #
    # @param table [Array, nil] The database, such as $data_actors.
    # @param id [Integer, nil] The entry's id.
    # @return [String] The id and the entry's name, the id alone when the database lacks a name.
    def self.named(table, id)
      entry = table && id.is_a?(Integer) && id >= 0 ? table[id] : nil
      name = entry && entry.respond_to?(:name) ? entry.name.to_s : ""
      name.empty? ? id.to_s : "#{id} #{name}"
    rescue
      id.to_s
    end

    # Describes an error for a line of the log, adding the pictures in memory to an RGSSError.
    #
    # The count tells a leak of pictures from a single picture too large to make.
    #
    # @param error [Exception] The error.
    # @return [String] Its class and message, "?" when it cannot be described.
    def self.failure(error)
      text = "#{error.class}: #{error.message}"
      text << " (#{bitmaps_alive} pictures in memory)" if defined?(RGSSError) && error.is_a?(RGSSError)
      text
    rescue
      "?"
    end

    # Counts the pictures the game holds in memory.
    #
    # @return [Integer, String] How many are not disposed, "?" where they cannot be counted.
    def self.bitmaps_alive
      ObjectSpace.each_object(Bitmap).count { |bitmap| !bitmap.disposed? }
    rescue
      "?"
    end

    # Writes a line to the log, after the module's LOG_TAG.
    #
    # Many methods give nothing through `return log(...)`, so a log must never hand back what
    # writing returned.
    #
    # @param message [String] The line.
    # @return [nil] Always.
    def log(message)
      Mod_Framework::Log.write("#{self::LOG_TAG}: #{message}")
      nil
    rescue
      nil
    end

    # Writes a line the first time only, for what would otherwise fail every frame.
    #
    # @param key [Object] What tells the line from the module's other lines.
    # @param message [String] The line.
    # @return [nil] Always, see log.
    def log_once(key, message)
      log(message) if Mod_Framework::Logging.first_time?(self, key)
      nil
    end
  end
end
