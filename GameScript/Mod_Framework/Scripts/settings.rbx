#----------------------------------------------------------------
#  settings.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Brought readable? back, which released mods call
#                            - Removed take_over, which only one mod called
#      Paulinchen  2026-11-01: Took settings over once per mod instead of once for every mod
#      Paulinchen  2026-10-31: Told the unreadable settings in plain words
#      Paulinchen  2026-10-30: Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The framework's settings, such as the look and the stored places of the boxes, kept in
  # Patch/Mod_Framework/Mod_Framework.ini whichever copy boots, which only the DLL reads and
  # writes (IniTopics.cs). The file sits in no manifest and no zip, so no update or removal touches
  # it.
  #
  # The settings are read once the game runs, or when first asked; a change is written after the
  # frame it was made in and as the game closes. Without the DLL nothing is read or written: every
  # setting answers nil and every change is refused.
  module Settings
    # The settings file, relative to the game folder.
    FILE = "Patch/Mod_Framework/Mod_Framework.ini"

    # The topic that reads a file: [path] answers its values, nil when it could not be read.
    READ_TOPIC = "ini.read"

    # The topic that writes a file: [path, values] answers whether it was written.
    WRITE_TOPIC = "ini.write"

    # Seconds before the file is read again, or a failed write tried again, which a lock by an
    # antivirus or a cloud sync is usually gone after.
    RETRY_SECONDS = 1

    # What a key must not hold, or start or end with, since the DLL refuses it or trims it on read.
    BAD_KEY = /[=\r\n]|\A[\0\t\n\v\f\r ]|[\0\t\n\v\f\r ]\z/

    # What the DLL trims off a value on read.
    TRIMMED = /\A[\0\t\n\v\f\r ]+|[\0\t\n\v\f\r ]+\z/

    # What the player is told once a change could not be kept because the file cannot be read.
    NOTICE = "Mod Framework: your settings cannot be saved. Restart the game."

    # The values by setting as last read and changed; nil before the first read.
    @values = nil

    # Whether the file was read, or is missing, so its values are known.
    @readable = false

    # Whether a change waits to be written.
    @pending = false

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "settings"

    # Reads a setting.
    #
    # @param key [String] The setting, such as "ui_preset".
    # @return [String, nil] Its value, nil while it is not set or without the DLL.
    def self.setting(key)
      known = values
      known ? known[key.to_s] : nil
    end

    # Lists the settings whose keys start with a prefix, such as the stored places.
    #
    # @param prefix [String] What their keys start with.
    # @return [Array<String>] The rest of each key after the prefix, in the file's order.
    def self.keys_under(prefix)
      known = values || {}
      known.keys.select { |key| key.start_with?(prefix) }.map { |key| key[prefix.size..-1] }
    end

    # Tells whether the file was read, or is missing, so its values are known, reading it the first
    # time.
    #
    # @return [Boolean] Whether they are; false without the DLL or while the file cannot be read.
    def self.readable?
      values
      @readable
    end

    # Keeps a setting.
    #
    # @param key [String] The setting.
    # @param value [Object] Its value, kept as text.
    # @return [Boolean] Whether it is kept and will be written.
    def self.store(key, value)
      change(key => value.to_s)
    end

    # Removes a setting.
    #
    # @param key [String] The setting.
    # @return [Boolean] Whether it is removed and the file will be written.
    def self.forget(key)
      change(key => nil)
    end

    # Keeps and removes settings in one write. A setting kept moves to the end of the file.
    #
    # A key the file could not hold is refused with all the other changes, since one such key in the
    # file's values would make every later write fail.
    #
    # @param changes [Hash] The values by setting, nil for one to remove.
    # @return [Boolean] Whether the changes are kept and will be written.
    def self.change(changes)
      known = values
      return false unless known

      bad = changes.keys.map { |key| key.to_s }.find { |key| key.empty? || key =~ BAD_KEY }
      return bad_key(bad) if bad
      return refused unless @readable

      changes.each do |key, value|
        known.delete(key.to_s)
        known[key.to_s] = value.to_s.gsub(TRIMMED, "") unless value.nil?
      end
      @pending = true
      true
    end

    # Takes the notice that the file cannot be read, once a session and only after a change was
    # refused for it.
    #
    # @return [String, nil] The notice, nil when there is none to show.
    def self.take_notice
      return nil unless @refused && !@noticed

      @noticed = true
      NOTICE
    end

    # Writes the waiting changes, if any, after a frame or as the game closes.
    #
    # @param now [Boolean] Whether to write even when a write failed less than RETRY_SECONDS ago.
    # @return [Boolean] Whether nothing waits any more.
    def self.flush(now = false)
      return true unless @pending
      return false if !now && @failed_at && Time.now - @failed_at < RETRY_SECONDS

      if Mod_Framework.bridge.call(WRITE_TOPIC, [FILE, @values]) == true
        @pending = false
        @failed_at = nil
        return true
      end

      log("could not write #{FILE}; trying again") unless @failed_at
      @failed_at = Time.now
      false
    end

    # Reads the file, without the DLL never.
    def self.load
      return unless Mod_Framework.available?

      @read_at = Time.now
      read = Mod_Framework.bridge.call(READ_TOPIC, [FILE])
      @readable = read.is_a?(Hash)
      @values = @readable ? read : (@values || {})
      log("#{FILE} could not be read, so the settings stay as they are until it can") unless @readable
    end

    # Gives the values, reading the file the first time and again at most every RETRY_SECONDS
    # while it cannot be read.
    #
    # @return [Hash, nil] The values by setting; nil without the DLL.
    def self.values
      unless Mod_Framework.available?
        log_once(:no_dll, "without the DLL no setting is read or stored")
        return nil
      end
      load if @values.nil? || (!@readable && Time.now - @read_at >= RETRY_SECONDS)
      @values
    end

    # Notes a change refused for a key the file could not hold.
    #
    # @param key [String] The key.
    # @return [Boolean] false.
    def self.bad_key(key)
      log_once([:bad_key, key], "a change was not kept: the key #{key.inspect} is empty, holds = or a line break, or starts or ends with a space")
      false
    end

    # Notes a change refused because the file cannot be read, for take_notice.
    #
    # @return [Boolean] false.
    def self.refused
      log_once(:refused, "a change was not kept: #{FILE} cannot be read")
      @refused = true
      false
    end

    # Reads the file as the game starts running, unless a mod asked for a setting before, and writes
    # waiting changes after every frame.
    Run.on_start("settings", :dll => true) do
      Settings.values
      Hooks.outermost(Graphics.singleton_class, :update, :after, "Mod Framework settings") { Mod_Framework::Settings.flush }
    end

    # Writes waiting changes as the game closes.
    Run.on_close("settings") { Settings.flush(true) }
  end
end
