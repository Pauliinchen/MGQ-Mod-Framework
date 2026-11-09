#----------------------------------------------------------------
#  bridge_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked the bytes of a request and its error against Marshal instead of fixtures
#                            - Read the exports from the framework's project
#                            - Read the exports by their mf_ names
#      Paulinchen  2026-11-04: Kept a few flows of the bridge with a check per outcome that matters
#                            - Rewrote the checks as flow tests of the handshake, calls, frames and drains
#      Paulinchen  2026-10-28: Moved into the Mod Framework from MGQ Online, with the bridge as a class
#                            - Left the start of the mod to boot_test.rb
#      Paulinchen  2026-10-23: Stood in for the log's hand-over once the start decided
#                            - Checked that only a handshake turns the mod on
#                            - Created
#                            - Stood in without the deleted mod switch
#
#----------------------------------------------------------------

# Covers Mod_Framework::Bridge against FakeBridge: the handshake and the DLLs it refuses, calls
# and their errors as Marshal writes them, a frame's batch, the drain, the buffers
# growing, a closed bridge, and the signatures of the DLL's exports.

require_relative "bridge_support"

load_scripts "logging", "hooks", "run", "bridge"
Mod_Framework::Log.settle(true)
bridge = Mod_Framework::Bridge.new

# An older DLL, a stand-in and another bridge version keep the bridge closed; a handshake opens it.
$exports_missing = true
lines = logged_lines { bridge.start("Old.dll") }
$exports_missing = false
lines += logged_lines { bridge.open(Class.new { def open(*); 0; end }.new) }
lines += logged_lines { bridge.open(FakeBridge.new(Mod_Framework::Bridge::VERSION + 1)) }
check("each refusal keeps the bridge closed and is logged with its reason", lines.map { |line| line[/\Abridge: not opened, [^,:(]*[^,:( ]/] },
      ["bridge: not opened, Old.dll lacks the bridge's exports", "bridge: not opened, the DLL answered no handshake",
       "bridge: not opened, the DLL refused the handshake"])
fake = FakeBridge.new
fake.build = "0.1.0-dev"
check("a handshake opens the bridge and tells the DLL's build", [bridge.open(fake), bridge.build], [true, "0.1.0-dev"])

# Calls hand back the value as it crossed; errors give nil and are logged once.
fake = FakeBridge.new
fake.answer("test.echo") { |request| request }
bridge.open(fake)
request = { "seat" => 2, 1001 => [true, nil, "ルカ", -(2**40)], "raw" => "\xFF".force_encoding("ASCII-8BIT") }
check("a call hands back the value as it crossed, Integer keys and encodings included", bridge.call("test.echo", request), request)
lines = logged_lines { 2.times { bridge.call("no.such.topic", { "seat" => 2 }) } }
reply = "\0".b * 256
length = fake.call(bridge.instance_variable_get(:@context), "no.such.topic\0", fake.calls.last[1], fake.calls.last[1].bytesize, reply, reply.bytesize)
check("a request and its error cross as Marshal writes them", [fake.calls.last[1], reply[0, length]],
      [Marshal.dump("seat" => 2), Marshal.dump("ok" => false, "error" => "unknown_topic", "text" => "There is no topic no.such.topic.")])
lines += logged_lines { bridge.call("test.echo", { :seat => 2 }) }
check("each error gives nil and is logged once per topic and code, a refused request naming what cannot cross", lines,
      ["bridge: no.such.topic failed with unknown_topic: There is no topic no.such.topic.",
       "bridge: test.echo failed with bad_request: The Symbol :seat cannot cross the bridge."])
raised = begin
  bridge.call!("no.such.topic")
rescue Mod_Framework::Bridge::Error => e
  e.message
end
check("call! raises the error", raised, "no.such.topic answered unknown_topic: There is no topic no.such.topic.")

# A frame sends what was staged as one batch, in order, and logs failed entries once.
appended = []
fake.answer("test.append") do |text|
  raise FakeBridge::BadRequest, "Expected a String, found an Integer." unless text.is_a?(String)

  appended << text
  nil
end
calls = fake.calls.size
%w[a b c].each { |text| bridge.stage("test.append", text) }
bridge.frame
check("staged calls go over at the frame as one batch as Marshal writes it, run in order",
      [fake.calls.size - calls, *fake.calls.last, *appended],
      [1, "batch", Marshal.dump([["test.append", "a"], ["test.append", "b"], ["test.append", "c"]]), "a", "b", "c"])
fake.answer_bytes("batch", Marshal.dump("ok" => true, "value" => [
                                          { "topic" => "no.such.topic", "error" => "unknown_topic", "text" => "There is no topic no.such.topic." },
                                          { "topic" => "test.append", "error" => "bad_request", "text" => "Expected a String, found an Integer." }
                                        ]))
# A new handshake forgets the failures logged so far.
bridge.open(fake)
lines = logged_lines { 2.times { bridge.stage("test.append", "x"); bridge.frame } }
check("each failed entry of a batch is logged once per topic and code", lines,
      ["bridge: no.such.topic failed with unknown_topic: There is no topic no.such.topic.", "bridge: test.append failed with bad_request: Expected a String, found an Integer."])

# The drain hands events to every handler of their topic, a failing handler logged once.
fake = FakeBridge.new
bridge.open(fake)
got = []
bridge.on("test.push") { |payload| got << payload }
bridge.on("test.push") { |payload| got << "second #{payload['n']}" }
bridge.on("test.broken") { |_payload| raise "broken handler" }
bridge.on("test.broken") { |payload| got << payload }
lines = logged_lines do
  2.times do
    fake.post("test.push", { "n" => 1 })
    fake.post("test.nobody", 1)
    fake.post("test.broken", 3)
    bridge.frame
  end
end
check("a frame hands each event to its topic's handlers in order, past a failing one", got.first(3), [{ "n" => 1 }, "second 1", 3])
check("an event nobody takes and a failing handler are logged once",
      lines, ["bridge: test.nobody failed with no_handler: no script takes its events", "bridge: test.broken failed with handler: RuntimeError: broken handler"])

# A reply or a drain larger than the buffer comes through a grown one, which stays.
big = "x" * 10_000
fake.answer("test.big") { |_request| big }
needed = Marshal.dump({ "ok" => true, "value" => big }).bytesize
sizes = fake.sizes.size
replies = [bridge.call("test.big"), bridge.call("test.big")]
fake.post("test.push", { "n" => "y" * 20_000 })
bridge.frame
check("a reply larger than the buffer comes through a grown buffer that stays, a larger event through a grown drain in the same frame",
      [replies == [big, big], *fake.sizes[sizes..-1], got[-2]["n"].size, *fake.frames.last(2)],
      [true, Mod_Framework::Bridge::REPLY_SIZE, needed, needed, 20_000, 3, 3])

# A closed bridge stages nothing and calls nothing.
bridge.close
calls = fake.calls.size
bridge.stage("test.append", "late")
bridge.frame
check("a closed bridge gives nil and calls nothing", [bridge.call("test.echo", 1), fake.calls.size - calls], [nil, 0])

# The signatures the scripts load the exports with are those of the DLL's BridgeExports.
exports = File.read(File.expand_path("../../ModFramework/Bridge/BridgeExports.cs", __dir__), :encoding => "UTF-8")
exported = exports.scan(/EntryPoint = "(mf_[a-z_]+)".*?\n\s*public static int \w+\(([^)]*)\)/m).map do |name, parameters|
  [name, parameters.split(",").map { |parameter| parameter.strip.start_with?("int ") ? "l" : "p" }.join]
end
check("the bridge loads each export with the arguments it takes", Hash[exported], Mod_Framework::Bridge::Win32Backend::SIGNATURES)
