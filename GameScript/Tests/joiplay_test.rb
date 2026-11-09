#----------------------------------------------------------------
#  joiplay_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Answered the exports by their mf_ names
#                            - Covered a tap at the middle of the screen landing at the middle of the game's screen
#      Paulinchen  2026-11-04: Kept the flows of the JoiPlay install, bridge and devices with a check per step that matters
#                            - Rewrote the checks as flow tests of the JoiPlay install, bridge and devices
#                            - Loaded the engine script before the input script
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Covers joiplay.rbx and the bridge's DLBackend outside JoiPlay: the app's own folder named from
# /proc, the library copied there only when it changed and then as a new file, a handshake and a
# call through native buffers whose addresses pass as signed numbers, and the devices of the tick
# with the soft keyboard.

require "tmpdir"
require_relative "support"

# Stands in for the engine's DL: its return type and native memory, each block of it at an address
# of its own with the top byte set, as Android marks heap pointers.
module DL
  TYPE_INT = 4

  # Native memory as DL::CPtr gives it, each block kept by its address.
  class CPtr
    @blocks = {}
    class << self; attr_reader :blocks; end
    attr_reader :bytes

    # Makes a block of a size, or points at a string's own bytes.
    def self.malloc(size); new(("\0" * size).force_encoding("ASCII-8BIT")); end
    def self.[](text); new(text); end

    # Takes the bytes and an address for them.
    def initialize(bytes)
      @bytes = bytes
      @address = 0xB400_0000_0000_0000 + CPtr.blocks.size * 0x1000
      CPtr.blocks[@address] = self
    end

    # Tells the address, and reads and writes the bytes.
    def to_i; @address; end
    def [](offset, length); @bytes[offset, length]; end
    def []=(offset, length, value); @bytes[offset, length] = value; end
  end

  # Stands in for DL's native call, which refuses a number past a signed 64-bit one as Ruby 1.9's
  # CFunc#[] does.
  class CFunc
    class << self
      attr_accessor :functions, :addresses
    end

    attr_accessor :ptr, :ctype

    # Calls the function at the address with the arguments as unsigned numbers.
    def [](arguments)
      raise RangeError, "bignum too big to convert into `long'" if arguments.any? { |argument| argument >= (1 << 63) }

      CFunc.functions[CFunc.addresses.key(ptr)].call(*arguments.map { |argument| argument < 0 ? argument + (1 << 64) : argument })
    end
  end
end

load_scripts "logging", "hooks", "run", "bridge", "joiplay", "engine", "input"
joiplay = Mod_Framework::JoiPlay
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }

check("the app's own folder is named after the process and the user it runs as, the plugin's folder without a process name",
      [joiplay.own_folder("cyou.joiplay.runtime.rpgmaker\0", 10_189), joiplay.own_folder("org.example.app:game\0", 1_010_123), joiplay.own_folder("", 10_000)],
      ["/data/user/0/cyou.joiplay.runtime.rpgmaker/files", "/data/user/10/org.example.app/files", joiplay::PLUGIN_FOLDER])

# The library is installed twice unchanged, then changed.
Dir.mktmpdir do |root|
  Dir.mkdir("#{root}/own")
  File.binwrite("#{root}/ModFramework.so", "first")
  copied = logged_lines do
    2.times { joiplay.install("#{root}/ModFramework.so", "#{root}/own") }
  end
  loaded = File.stat("#{root}/own/ModFramework.so").ino
  File.binwrite("#{root}/ModFramework.so", "second")
  joiplay.install("#{root}/ModFramework.so", "#{root}/own")
  check("the library is copied only while its bytes changed, and then as a new file, so the loaded one is never rewritten",
        [copied.grep(/copied/).size, File.binread("#{root}/own/ModFramework.so"), File.stat("#{root}/own/ModFramework.so").ino == loaded, *Dir.children("#{root}/own")],
        [1, "second", false, "ModFramework.so"])
end

# The library's functions, each answering from the native memory it is handed.
handshake = Marshal.dump("ok" => true, "value" => { "bridge" => 1, "topics" => ["echo"], "build" => "0.1.0", "context" => 7 })
topics = []
DL::CFunc.functions = {
  "mf_bridge_open" => lambda do |_version, buffer, _size|
    DL::CPtr.blocks[buffer][0, handshake.bytesize] = handshake
    handshake.bytesize
  end,
  "mf_call" => lambda do |context, topic, request, length, buffer, _size|
    topics << DL::CPtr.blocks[topic].bytes.delete("\0")
    reply = Marshal.dump("ok" => true, "value" => [context, Marshal.load(DL::CPtr.blocks[request][0, length])])
    DL::CPtr.blocks[buffer][0, reply.bytesize] = reply
    reply.bytesize
  end,
  "mf_reply" => ->(*_) { 0 },
  "mf_drain" => ->(*_) { 0 },
}
DL::CFunc.addresses = Hash[DL::CFunc.functions.keys.each_with_index.map { |name, index| [name, 0x9000 + index] }]
bridge = Mod_Framework::Bridge.new
opened = bridge.open(Mod_Framework::Bridge::DLBackend.new(DL::CFunc.addresses))
check("a handshake and a call cross through native buffers by their signed addresses", [opened, bridge.build, *bridge.call("echo", "hi"), *topics],
      [true, "0.1.0", 7, "hi", "echo"])

# The engine's Input as a test sets it.
$held = []
$typed = ""
$keyboard = []
module Input
  MOUSELEFT = :MOUSELEFT
  MOUSERIGHT = :MOUSERIGHT
  def self.press?(button); $held.include?(button); end
  def self.pressex?(code); $held.include?(code); end
  def self.repeatex?(code); $held.include?(code); end
  def self.triggerex?(code); $held.include?(code); end
  def self.mouse_x; 247; end
  def self.mouse_y; 208; end
  def self.scroll_v; 0; end
  def self.gets; text = $typed; $typed = ""; text.dup.force_encoding("ASCII-8BIT"); end
  def self.text_input=(on); $keyboard << on; end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end

# The player taps the middle of the screen, which the engine reads as 247,208, and holds a key,
# then types into a box.
$held = [:MOUSELEFT, 0x41]
quiet = joiplay.devices(false)
x, y, width, height = quiet["mouse"]
check("a tap at the middle of the screen lands at the middle of the game's screen as C# scales it, the left button as Windows' 0x01, " \
      "with the key held and no text while no box takes typing",
      [x * 640 / width, y * 480 / height, *quiet["keys"], quiet.key?("typed")], [320, 240, 0x01, 0x41, false])
$held = [0x08]
$typed = "ü"
typing = joiplay.devices(true)
joiplay.devices(true)
joiplay.devices(false)
check("while a box takes typing the text comes in UTF-8 with Backspace as its character, the soft keyboard open once for it",
      [typing["typed"], typing["typed"].encoding, *$keyboard], ["ü\b", Encoding::UTF_8, true, false])
