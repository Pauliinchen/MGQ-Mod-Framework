#----------------------------------------------------------------
#  bridge_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed the reader of the contract fixtures
#                            - Answered the exports by their mf_ names
#      Paulinchen  2026-10-30: Answered the calls of kernel32 that find the platform
#      Paulinchen  2026-10-28: Moved into the Mod Framework from MGQ Online, with FakeBridge alone
#                            - Answered mf_start and named the build in the handshake
#                            - Stood in for Win32API
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# The bridge to C# for the script tests: FakeBridge, a stand-in for the DLL's side that answers
# topics with Ruby lambdas, and Win32API, which reaches it. Every request and reply crosses through
# Marshal and the plain-value check of the core's strict reader, so a test fails where the game
# would refuse a value.

require_relative "support"

# The DLL's side of the bridge as a backend of Mod_Framework::Bridge: the four exports and
# mf_start, answering topics with the Ruby blocks a test registers and keeping what the scripts
# sent.
class FakeBridge
  # What a handler raises for a request that misses what its topic needs, as BridgeRequestException.
  class BadRequest < StandardError; end

  # The encodings a String may cross in.
  PLAIN_ENCODINGS = [Encoding::UTF_8, Encoding::US_ASCII, Encoding::ASCII_8BIT]

  # How the core names a plain value that is no String or Integer, as a refused Hash key.
  KEY_KINDS = { Array => "An Array", Hash => "A Hash", NilClass => "Nil", TrueClass => "True", FalseClass => "False" }

  # The deepest nesting the core reads.
  MAX_DEPTH = 256

  # @return [Array<Array>] Each mf_call as [topic, request bytes].
  attr_reader :calls

  # @return [Array<Integer>] The frame of each mf_drain.
  attr_reader :frames

  # @return [Array<Integer>] The buffer size of each mf_call and mf_reply.
  attr_reader :sizes

  # @return [String] The build the handshake names, as the DLL names its version.
  attr_accessor :build

  # @return [Integer] What mf_start answers: 1 once the game window is hooked.
  attr_accessor :hooked

  # @return [Integer] How often mf_start was called.
  attr_reader :starts

  # Creates the stand-in with no topic but the batch.
  #
  # @param version [Integer, nil] The bridge version it speaks, nil for the scripts' own.
  def initialize(version = nil)
    @version = version
    @build = "test"
    @hooked = 1
    @starts = 0
    @handlers = {}
    @raw = {}
    @events = []
    @parked = {}
    @calls = []
    @frames = []
    @sizes = []
    @context = 0
  end

  # Tells why a value cannot cross the bridge, as the core's strict reader does.
  #
  # @param value [Object] The value.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for a plain value.
  def self.refusal(value, depth = 0)
    return "The value nests too deep to cross the bridge." if depth > MAX_DEPTH

    case value
    when nil, true, false, Integer then nil
    when String then text_refusal(value)
    when Array then list_refusal(value, depth)
    when Hash then hash_refusal(value, depth)
    when Symbol then "The Symbol :#{value} cannot cross the bridge."
    when Float then "The Float #{value} cannot cross the bridge."
    else "#{value.class} cannot cross the bridge."
    end
  end

  # Tells why a String cannot cross the bridge.
  #
  # @param text [String] The string.
  # @return [String, nil] The refusal, nil for one that can.
  def self.text_refusal(text)
    return "A String in #{text.encoding} cannot cross the bridge." unless PLAIN_ENCODINGS.include?(text.encoding)

    text.valid_encoding? ? nil : "A String marked #{text.encoding} with bytes outside it cannot cross the bridge."
  end

  # Tells why an Array cannot cross the bridge.
  #
  # @param list [Array] The Array.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for one that can.
  def self.list_refusal(list, depth)
    list.each do |item|
      found = refusal(item, depth + 1)
      return found if found
    end
    nil
  end

  # Tells why a Hash cannot cross the bridge.
  #
  # @param hash [Hash] The Hash.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for one that can.
  def self.hash_refusal(hash, depth)
    return "A Hash with a default value cannot cross the bridge." unless hash.default.nil? && hash.default_proc.nil?

    hash.each do |key, item|
      found = refusal(key, depth + 1)
      return found if found
      return "#{KEY_KINDS[key.class]} as a Hash key cannot cross the bridge." unless key.is_a?(String) || key.is_a?(Integer)

      found = refusal(item, depth + 1)
      return found if found
    end
    nil
  end

  # Answers a topic with a block, which gets the request and returns the value; nil answers nothing.
  #
  # @param topic [String] The topic.
  # @yieldparam request [Object] The request as it crossed.
  def answer(topic, &handler)
    @handlers[topic] = handler
  end

  # Answers a topic with bytes as they are, such as a reply Marshal wrote.
  #
  # @param topic [String] The topic.
  # @param bytes [String] The reply, Marshal.
  def answer_bytes(topic, bytes)
    @raw[topic] = bytes
  end

  # Queues an event for the next drain.
  #
  # @param topic [String] The event's topic.
  # @param payload [Object] A plain value.
  def post(topic, payload)
    @events << [topic, payload]
  end

  # mf_start.
  #
  # @return [Integer] As the export.
  def start
    @starts += 1
    @hooked
  end

  # mf_bridge_open.
  #
  # @param version [Integer] The scripts' version.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def open(version, reply, size)
    return take(:open, reply, size) if @parked[:open]

    speaks = @version || Mod_Framework::Bridge::VERSION
    answer =
      if version == speaks
        ok("bridge" => speaks, "build" => @build, "context" => (@context += 1), "topics" => [Mod_Framework::Bridge::BATCH] + @handlers.keys)
      else
        error("bad_request", "The scripts speak bridge version #{version}, the core version #{speaks}.")
      end
    hand(:open, Marshal.dump(answer), reply, size)
  end

  # mf_call.
  #
  # @param context [Integer] The context.
  # @param topic [String] The topic, null-terminated.
  # @param request [String] The request.
  # @param length [Integer] Its length.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def call(context, topic, request, length, reply, size)
    name = topic.chomp("\0")
    bytes = request[0, length]
    @calls << [name, bytes]
    @sizes << size
    return hand(:call, @raw[name], reply, size) if @raw.key?(name)

    envelope = context == @context ? envelope_of(name, bytes) : error("bad_request", "There is no bridge context #{context}.")
    envelope.nil? ? 0 : hand(:call, Marshal.dump(envelope), reply, size)
  end

  # mf_reply.
  #
  # @param _context [Integer] The context.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def reply(_context, reply, size)
    @sizes << size
    take(:call, reply, size)
  end

  # mf_drain.
  #
  # @param _context [Integer] The context.
  # @param frame [Integer] The scripts' frame.
  # @param buffer [String] The drain buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def drain(_context, frame, buffer, size)
    @frames << frame
    return take(:drain, buffer, size) if @parked[:drain]
    return 0 if @events.empty?

    events = @events
    @events = []
    hand(:drain, Marshal.dump(events), buffer, size)
  end

  private

  # Answers a call as the core's dispatcher does.
  #
  # @param topic [String] The topic.
  # @param bytes [String] The request's bytes.
  # @return [Hash, nil] The envelope, nil for no reply.
  def envelope_of(topic, bytes)
    return error("unknown_topic", "There is no topic #{topic}.") unless topic == Mod_Framework::Bridge::BATCH || @handlers.key?(topic)

    request =
      begin
        bytes.empty? ? nil : Marshal.load(bytes)
      rescue ArgumentError => e
        return error("bad_request", "#{e.message} cannot cross the bridge.")
      end
    refused = FakeBridge.refusal(request)
    return error("bad_request", refused) if refused

    run(topic, request)
  end

  # Runs a topic's block on a request that crossed.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Hash, nil] The envelope, nil for no reply.
  def run(topic, request)
    return error("unknown_topic", "There is no topic #{topic}.") unless topic == Mod_Framework::Bridge::BATCH || @handlers.key?(topic)

    value = topic == Mod_Framework::Bridge::BATCH ? run_batch(request) : @handlers[topic].call(request)
    return nil if value.nil?

    refused = FakeBridge.refusal(value)
    refused ? error("internal", "The reply cannot cross: #{refused}") : ok(value)
  rescue BadRequest => e
    error("bad_request", e.message)
  rescue => e
    error("internal", e.message)
  end

  # Runs a batch's entries in order, after checking every one, as the core's batch topic does.
  #
  # @param request [Object] The batch.
  # @return [Array<Hash>, nil] The failed entries, nil when every one ran.
  def run_batch(request)
    raise BadRequest, "Expected an Array, found #{request.class}." unless request.is_a?(Array)

    request.each do |pair|
      raise BadRequest, "Batch entry #{pair.inspect} is no [topic, payload] pair." unless pair.is_a?(Array) && pair.size == 2 && pair[0].is_a?(String)
      raise BadRequest, "A batch cannot hold a batch." if pair[0] == Mod_Framework::Bridge::BATCH
    end
    failed = request.map do |topic, payload|
      answer = run(topic, payload)
      answer && !answer["ok"] ? { "topic" => topic, "error" => answer["error"], "text" => answer["text"] } : nil
    end.compact
    failed.empty? ? nil : failed
  end

  # Writes bytes into the scripts' buffer, or parks them when they do not fit.
  #
  # @param slot [Symbol] What parks them: :open, :call or :drain.
  # @param bytes [String] The bytes.
  # @param buffer [String] The buffer.
  # @param size [Integer] Its size.
  # @return [Integer] Their length, or it negated when they were parked.
  def hand(slot, bytes, buffer, size)
    if bytes.bytesize > size
      @parked[slot] = bytes
      return -bytes.bytesize
    end
    buffer[0, bytes.bytesize] = bytes
    bytes.bytesize
  end

  # Writes parked bytes into the scripts' buffer once it is large enough.
  #
  # @param slot [Symbol] What parked them.
  # @param buffer [String] The buffer.
  # @param size [Integer] Its size.
  # @return [Integer] Their length, 0 when none are parked, or it negated when they still do not fit.
  def take(slot, buffer, size)
    bytes = @parked[slot]
    return 0 unless bytes
    return -bytes.bytesize if bytes.bytesize > size

    @parked.delete(slot)
    buffer[0, bytes.bytesize] = bytes
    bytes.bytesize
  end

  # Makes the reply of a topic that answered.
  #
  # @param value [Object] The value.
  # @return [Hash] The envelope.
  def ok(value)
    { "ok" => true, "value" => value }
  end

  # Makes the reply of a request that failed.
  #
  # @param code [String] The error code.
  # @param text [String] What went wrong.
  # @return [Hash] The envelope.
  def error(code, text)
    { "ok" => false, "error" => code, "text" => text }
  end
end


# Stands in for the game's Win32API: the DLL's exports reach $dll through the arguments their
# signatures name, and loading one fails while $exports_missing, as with an older DLL. Each DLL
# path loaded is kept in $dll_paths. A call into kernel32 answers from $kernel32 by its last
# argument, 0 for one it lacks.
class Win32API
  # The method of $dll each export reaches.
  METHODS = { "mf_start" => :start, "mf_bridge_open" => :open, "mf_call" => :call, "mf_reply" => :reply, "mf_drain" => :drain }

  # What kernel32 answers on Windows: ntdll is loaded, and it exports no wine_get_version.
  WINDOWS_KERNEL32 = { "ntdll.dll" => 0x7700_0000 }

  # Loads an export.
  #
  # @param path [String] The DLL.
  # @param name [String] The export.
  # @param arguments [String] Its arguments in Win32API notation.
  # @param _result [String] Its result.
  def initialize(path, name, arguments, _result)
    raise "GetProcAddress failed for #{name}" if $exports_missing

    ($dll_paths ||= []) << path unless path == "kernel32"
    @path = path
    @name = name
    @arguments = arguments == "v" ? "" : arguments
  end

  # Calls the export, refusing arguments its signature does not name, as RGSS does.
  #
  # @param args [Array] The arguments.
  # @return [Integer] What the export answers.
  def call(*args)
    kinds = args.map { |arg| arg.is_a?(Integer) ? "l" : arg.is_a?(String) ? "p" : "?" }.join
    raise "#{@name} takes #{@arguments}, got #{kinds}" if kinds != @arguments
    return ($kernel32 || WINDOWS_KERNEL32).fetch(args.last, 0) if @path == "kernel32"

    $dll.public_send(METHODS.fetch(@name), *args)
  end
end
