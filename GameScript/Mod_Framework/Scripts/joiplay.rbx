#----------------------------------------------------------------
#  joiplay.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Scaled a tap to the game's pixels by how far the engine's pointer reaches
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The framework on JoiPlay (Android), whose engine loads no Windows DLL: the same C# built as
  # ModFramework.so runs through the engine's DL, and these scripts read the pointer, the keys and
  # what is typed from the engine's Input for it.
  module JoiPlay
    # The library inside the copy's folder.
    LIBRARY = "ModFramework.so"

    # The libssl stand-in inside the copy's folder, the name .NET loads it by.
    STAND_IN = "libssl.so"

    # The library's start, Exports.StartAndroid in C#.
    START = "mf_start_android"

    # The app's own folder when /proc names no app, that of JoiPlay's RPG Maker plugin.
    PLUGIN_FOLDER = "/data/user/0/cyou.joiplay.runtime.rpgmaker/files"

    # Android numbers the users of a phone in steps of this many app ids.
    USER_RANGE = 100_000

    # Windows' codes of the mouse buttons, which the engine's mouse constants read instead.
    LEFT_BUTTON = 0x01
    RIGHT_BUTTON = 0x02

    # Windows' codes of every key the tick reads, past the mouse buttons.
    KEY_CODES = (0x03..0xFE).to_a - [0x04, 0x05, 0x06]

    # The keys that type a control character in a text box, by Windows' code: Enter, Escape and
    # Tab; Backspace repeats while held.
    TYPED_KEYS = { 0x0D => "\r", 0x1B => "\e", 0x09 => "\t" }

    # Windows' code of Backspace.
    BACKSPACE = 0x08

    # How far the engine's pointer reaches across the game's screen, as a part of its width and
    # height: JoiPlay scales a tap from the phone's screen by another factor than the one it draws
    # the game at, so the middle of the 640x480 screen reads 247,208 (measured on the emulator).
    POINTER_REACH = [247.0 / 320, 208.0 / 240]

    # Whether the soft keyboard is on; the engine starts with it off.
    @keyboard = false

    extend Logging

    # What starts this script's lines in the log.
    LOG_TAG = "joiplay"

    # Copies the library and the stand-in into the app's own folder, the only place Android loads
    # a library from, opens the library and starts it.
    #
    # @param folder [String] The copy's folder, relative to the game folder.
    # @return [Bridge::DLBackend, nil] The bridge's way to the library; nil when it did not start,
    #   which the log tells.
    def self.start(folder)
      own = own_folder
      Dir.mkdir(own) unless File.directory?(own)
      library = install("#{folder}/#{LIBRARY}", own)
      stand_in = install("#{folder}/#{STAND_IN}", own)
      handle = DL::Handle.new(library)
      started = Native.call(handle[START], DL::TYPE_INT, Native.text(File.expand_path(folder)), Native.text(stand_in))
      return Bridge::DLBackend.new(handle) if started == 1

      log("#{START} answered #{started}, see the DLL's lines")
      nil
    end

    # Names the app's own folder from the process's name and user.
    #
    # @param command_line [String] /proc/self/cmdline, the app's name first.
    # @param uid [Integer] The process's user id.
    # @return [String] The folder, PLUGIN_FOLDER when the name is no app's.
    def self.own_folder(command_line = File.open("/proc/self/cmdline", "rb") { |file| file.read }, uid = Process.uid)
      app = command_line.to_s.split("\0").first.to_s.split(":").first.to_s
      app =~ /\A[A-Za-z][\w.]*\z/ ? "/data/user/#{uid / USER_RANGE}/#{app}/files" : PLUGIN_FOLDER
    end

    # Copies a file into a folder unless the same bytes lie there already, writing a new file and
    # renaming it over the old one.
    #
    # A library the process loaded stays mapped from its file, so rewriting that file in place
    # could crash the game, and Android would hand back the loaded build for the same file.
    #
    # @param source [String] The file.
    # @param folder [String] The folder.
    # @return [String] The copy's path.
    def self.install(source, folder)
      target = "#{folder}/#{File.basename(source)}"
      bytes = File.open(source, "rb") { |file| file.read }
      return target if File.file?(target) && File.size(target) == bytes.bytesize && File.open(target, "rb") { |file| file.read } == bytes

      written = "#{target}.#{Process.pid}.new"
      begin
        File.open(written, "wb") { |file| file.write(bytes) }
        File.chmod(0700, written)
        File.rename(written, target)
      ensure
        File.delete(written) if File.exist?(written)
      end
      log("copied #{source} to #{target}")
      target
    end

    # Reads the devices for the frame's tick, see ScriptInput in C#, and turns the soft keyboard on
    # while a text box is typed into. The mouse buttons are read past the capture, which keeps the
    # game's buttons from the game while a window of the framework is open.
    #
    # @param typing [Boolean] Whether a text box takes what is typed.
    # @return [Hash] The devices.
    def self.devices(typing)
      keyboard(typing)
      keys = []
      keys << LEFT_BUTTON if UI::Engine::Capture.press?(::Input::MOUSELEFT)
      keys << RIGHT_BUTTON if UI::Engine::Capture.press?(::Input::MOUSERIGHT)
      KEY_CODES.each { |code| keys << code if ::Input.pressex?(code) }
      devices = { "mouse" => [::Input.mouse_x, ::Input.mouse_y] + pointer_range, "keys" => keys, "wheel" => ::Input.scroll_v.to_i }
      devices["typed"] = typed if typing
      devices
    end

    # Tells the range the engine's pointer reports over the game's screen, which C# scales a tap
    # from to the game's pixels.
    #
    # @return [Array<Integer>] The range's width and height.
    def self.pointer_range
      [(Graphics.width * POINTER_REACH[0]).round, (Graphics.height * POINTER_REACH[1]).round]
    end

    # Shows the soft keyboard while a text box is typed into and hides it after.
    #
    # @param on [Boolean] Whether a text box takes what is typed.
    def self.keyboard(on)
      return if @keyboard == on

      @keyboard = on
      ::Input.text_input = on
    end

    # Takes what was typed since the last frame: the engine's text, then Backspace, Enter, Escape
    # and Tab as their characters.
    #
    # @return [String] The text in UTF-8.
    def self.typed
      text = ::Input.gets.to_s.dup.force_encoding("UTF-8")
      text << "\b" if ::Input.repeatex?(BACKSPACE)
      TYPED_KEYS.each { |code, character| text << character if ::Input.triggerex?(code) }
      text
    end

    # Native calls through the engine's DL.
    module Native
      # Calls a native function.
      #
      # JoiPlay replaces DL::CFunc#initialize and #call, so calls go through allocate and [].
      #
      # @param address [Integer] The function's address.
      # @param ctype [Integer] The DL return type.
      # @param arguments [Array<Integer>] Integer and pointer arguments.
      # @return [Integer] What the function returned.
      def self.call(address, ctype, *arguments)
        raise ArgumentError, "the function was not found" if address.nil? || address == 0

        function = DL::CFunc.allocate
        function.ptr = signed(address)
        function.ctype = ctype
        function[arguments.map { |argument| signed(argument) }]
      end

      # Turns an address into the signed number CFunc#[] takes.
      #
      # Android marks heap pointers in their top byte, which CFunc#[] refuses as unsigned numbers.
      #
      # @param value [Integer] The address or number.
      # @return [Integer] The same bits as a signed 64-bit number.
      def self.signed(value)
        value = value.to_i
        value >= (1 << 63) ? value - (1 << 64) : value
      end

      # Copies a text into native memory with a closing zero byte, kept for the session.
      #
      # @param text [String] The text.
      # @return [Integer] The memory's address.
      def self.text(text)
        bytes = text.dup.force_encoding("ASCII-8BIT") + "\0"
        memory = DL::CPtr.malloc(bytes.bytesize)
        memory[0, bytes.bytesize] = bytes
        (@kept ||= []) << memory
        memory.to_i
      end
    end
  end
end
