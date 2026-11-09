#----------------------------------------------------------------
#  bridge.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed the library loader through Fiddle, which the game has not
#                            - Named the four exports with the framework's prefix mf_
#      Paulinchen  2026-11-05: Read a reply's envelope by keys made once, without a new text for each read
#                            - Looked a topic up among the DLL's topics by key rather than through the whole list
#      Paulinchen  2026-10-30: Reached the library on JoiPlay through DL in DLBackend
#                            - Kept its frame hooks outside those of every mod
#      Paulinchen  2026-10-28: Sent the staged entries after every frame and left the drain to the frame's tick
#                            - Moved into the Mod Framework from MGQ Online's Multiplayer.rb as a class of its own
#                            - Told the build the DLL named in its handshake
#      Paulinchen  2026-10-23: Loaded the battle server's core library through Fiddle in FiddleBackend
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  # The bridge to C# (ModFramework/Bridge): named topics the DLL answers, with plain values crossing as
  # Marshal through four exports. A script calls a topic for its value, stages what it hands over
  # during a frame, and takes the DLL's events in the handlers it registered; once a frame the
  # staged entries go over in one batch call and the events come back in one drain. Plain values are
  # nil, true, false, Integer, String (UTF-8, US-ASCII or binary), Array and Hash with String or
  # Integer keys; the DLL refuses anything else, such as a Symbol or a game object.
  #
  # The framework talks to its DLL through its own instance, Mod_Framework.bridge; a mod with a DLL
  # of its own keeps its own bridge code pinned to that DLL.
  class Bridge
    # The bridge version these scripts speak, BridgeHost.Version in C#; a DLL of another refuses
    # the handshake.
    VERSION = 1

    # Bytes of the reply buffer at first; a larger reply grows it for good.
    REPLY_SIZE = 4_096

    # Bytes of the drain buffer at first; a larger drain grows it for good.
    DRAIN_SIZE = 16_384

    # The topic the DLL runs a frame's staged entries through, in order.
    BATCH = "batch"

    # The largest frame the drain passes, the most a Win32API long holds; the count starts again
    # from 0 past it.
    MAX_FRAME = 0x7fff_ffff

    # What a call without a request hands over: an empty request, which C# reads as nil.
    NO_REQUEST = ""

    # The keys of a reply's envelope, made once, since a text written in a call is made anew at each
    # call in the game's Ruby.
    OK_KEY = "ok"
    VALUE_KEY = "value"
    ERROR_KEY = "error"
    TEXT_KEY = "text"

    # What call! raises for a topic that answered an error, or while the bridge is closed.
    class Error < StandardError; end

    # Reaches the DLL through the game's Win32API.
    class Win32Backend
      # The four exports with their arguments in Win32API notation; each returns a long.
      SIGNATURES = {
        'mf_bridge_open' => 'lpl',
        'mf_call' => 'lpplpl',
        'mf_reply' => 'lpl',
        'mf_drain' => 'llpl',
      }

      # Loads the four exports.
      #
      # @param path [String] The DLL's path, relative to the game's folder.
      # @raise [RuntimeError] The DLL lacks one of them, as an older build does.
      def initialize(path)
        @functions = {}
        SIGNATURES.each { |name, arguments| @functions[name] = Win32API.new(path, name, arguments, 'l') }
      end

      # Shakes hands (mf_bridge_open).
      #
      # @param version [Integer] The scripts' VERSION.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def open(version, reply, size)
        @functions['mf_bridge_open'].call(version, reply, size)
      end

      # Runs a topic (mf_call).
      #
      # @param context [Integer] The context from the handshake.
      # @param topic [String] The topic, null-terminated.
      # @param request [String] The request as Marshal, empty for nil.
      # @param length [Integer] The request's length in bytes.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def call(context, topic, request, length, reply, size)
        @functions['mf_call'].call(context, topic, request, length, reply, size)
      end

      # Hands out a parked reply (mf_reply).
      #
      # @param context [Integer] The context from the handshake.
      # @param reply [String] The reply buffer, now large enough.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none.
      def reply(context, reply, size)
        @functions['mf_reply'].call(context, reply, size)
      end

      # Takes the queued events (mf_drain).
      #
      # @param context [Integer] The context from the handshake.
      # @param frame [Integer] The bridge's frame.
      # @param buffer [String] The drain buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The events' length, 0 for none, or the size needed negated.
      def drain(context, frame, buffer, size)
        @functions['mf_drain'].call(context, frame, buffer, size)
      end
    end

    # Reaches the library through the engine's DL on JoiPlay, with the same four functions, called
    # as Win32Backend calls them. A buffer the library writes into is native memory whose bytes are
    # copied into the Ruby buffer after the call, since DL hands over addresses, not Ruby strings.
    class DLBackend
      # Binds the four functions of an opened library without calling one.
      #
      # @param library [#[]] The library, such as a DL::Handle, giving each function's address.
      # @param memory [#malloc, #[]] What makes native memory and gives a string's address,
      #   DL::CPtr in the game.
      # @raise [ArgumentError] The library lacks one of them.
      def initialize(library, memory = DL::CPtr)
        @memory = memory
        @functions = {}
        Win32Backend::SIGNATURES.each_key do |name|
          address = library[name]
          raise ArgumentError, "the library lacks #{name}" if address.nil? || address == 0

          @functions[name] = address
        end
        @buffers = {}
      end

      # Shakes hands (mf_bridge_open), see Win32Backend#open.
      #
      # @param version [Integer] The scripts' VERSION.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def open(version, reply, size)
        into('mf_bridge_open', [version], reply, size)
      end

      # Runs a topic (mf_call), see Win32Backend#call.
      #
      # @param context [Integer] The context from the handshake.
      # @param topic [String] The topic, null-terminated.
      # @param request [String] The request as Marshal, empty for nil.
      # @param length [Integer] The request's length in bytes.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def call(context, topic, request, length, reply, size)
        topic_memory = @memory[topic]
        request_memory = @memory[request]
        into('mf_call', [context, topic_memory.to_i, request_memory.to_i, length], reply, size)
      end

      # Hands out a parked reply (mf_reply), see Win32Backend#reply.
      #
      # @param context [Integer] The context from the handshake.
      # @param reply [String] The reply buffer, now large enough.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none.
      def reply(context, reply, size)
        into('mf_reply', [context], reply, size)
      end

      # Takes the queued events (mf_drain), see Win32Backend#drain.
      #
      # @param context [Integer] The context from the handshake.
      # @param frame [Integer] The bridge's frame.
      # @param buffer [String] The drain buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The events' length, 0 for none, or the size needed negated.
      def drain(context, frame, buffer, size)
        into('mf_drain', [context, frame], buffer, size)
      end

      private

      # Calls a function that writes into a buffer, then copies what it wrote into the Ruby buffer.
      #
      # @param name [String] The function.
      # @param arguments [Array<Integer>] The arguments before the buffer and its size.
      # @param buffer [String] The Ruby buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The length written, 0 for none, or the size needed negated.
      def into(name, arguments, buffer, size)
        native = (@buffers[size] ||= @memory.malloc(size))
        length = JoiPlay::Native.call(@functions[name], DL::TYPE_INT, *(arguments + [native.to_i, size]))
        buffer[0, length] = native[0, length] if length > 0
        length
      end
    end

    # Tells the build the DLL named in its handshake.
    #
    # @return [String, nil] The build, such as "0.1.0-dev"; nil before a handshake succeeded.
    attr_reader :build

    # Makes a closed bridge; every call answers nil and a frame does nothing until a handshake.
    def initialize
      @handlers = {}
      @frame = 0
      close
    end

    # Opens the bridge to a DLL.
    #
    # @param path [String] The DLL's path, relative to the game's folder.
    # @return [Boolean] Whether it opened; the log tells why not.
    def start(path)
      backend =
        begin
          Win32Backend.new(path)
        rescue => e
          return refuse("#{path} lacks the bridge's exports (#{e.class}: #{e.message})")
        end
      open(backend)
    end

    # Shakes hands with C# through a backend. Until one succeeds, every call answers nil and a
    # frame does nothing.
    #
    # @param backend [#open, #call, #reply, #drain] The four exports, see Win32Backend.
    # @return [Boolean] Whether the bridge opened; the log tells why not.
    def open(backend)
      close
      @backend = backend
      @reply = buffer(REPLY_SIZE)
      length = backend.open(VERSION, @reply, @reply.bytesize)
      if length < 0
        # The DLL parked its answer, which the next handshake hands out.
        @reply = buffer(-length)
        length = backend.open(VERSION, @reply, @reply.bytesize)
      end
      return refuse("the DLL answered no handshake, as a stand-in DLL does") if length <= 0

      answer = Marshal.load(@reply[0, length])
      return refuse("the DLL refused the handshake: #{answer['text']}") unless answer["ok"]

      value = answer["value"]
      return refuse("the DLL speaks bridge version #{value['bridge']}, these scripts #{VERSION}") if value["bridge"] != VERSION

      @topics = {}
      Array(value["topics"]).each { |topic| @topics[topic] = true }
      @events = buffer(DRAIN_SIZE)
      @frame = 0
      @build = value["build"]
      @context = value["context"]
      Log.write("bridge: opened context #{@context} with the DLL of build #{@build}, #{@topics.size} topic(s)")
      true
    rescue => e
      refuse("the handshake failed: #{e.class}: #{e.message}")
    end

    # Closes the bridge and forgets what was staged and which failures were logged; the handlers
    # stay.
    def close
      @context = nil
      @build = nil
      @staged = []
      @failures = {}
    end

    # Tells whether the handshake succeeded.
    #
    # @return [Boolean] Whether the bridge is open.
    def open?
      !@context.nil?
    end

    # Tells whether the DLL answers a topic.
    #
    # @param topic [String] The topic.
    # @return [Boolean] Whether the handshake named it.
    def has?(topic)
      open? && @topics.key?(topic)
    end

    # Calls a topic and takes its value. An error it answers is logged once per topic and code.
    #
    # @param topic [String] The topic, such as "ini.read".
    # @param request [Object] A plain value, nil for none.
    # @return [Object, nil] The topic's value; nil for none, for an error and while the bridge is
    #   closed.
    def call(topic, request = nil)
      answer = exchange(topic, request)
      return nil if answer.nil?
      return answer[VALUE_KEY] if answer[OK_KEY]

      failed(topic, answer[ERROR_KEY], answer[TEXT_KEY])
      nil
    rescue => e
      failed(topic, "script", "#{e.class}: #{e.message}")
      nil
    end

    # Calls a topic, for a caller that must know whether it answered.
    #
    # @param topic [String] The topic.
    # @param request [Object] A plain value, nil for none.
    # @return [Object, nil] The topic's value, nil for none.
    # @raise [Error] The topic answered an error, or the bridge is closed.
    def call!(topic, request = nil)
      raise Error, "the bridge is closed, so #{topic} was not called" unless open?

      answer = exchange(topic, request)
      return nil if answer.nil?
      return answer[VALUE_KEY] if answer[OK_KEY]

      raise Error, "#{topic} answered #{answer['error']}: #{answer['text']}"
    end

    # Stages what a script hands over during a frame, which the next frame sends in one batch with
    # the rest, in order. Nothing is staged while the bridge is closed.
    #
    # @param topic [String] The topic, such as "log.write".
    # @param payload [Object] A plain value.
    def stage(topic, payload = nil)
      @staged << [topic, payload] if @context
      nil
    end

    # Registers a handler for a topic's events, which a frame's drain hands to every handler of the
    # topic in order.
    #
    # @param topic [String] The topic.
    # @yieldparam payload [Object] The event's plain value.
    def on(topic, &handler)
      (@handlers[topic] ||= []) << handler
    end

    # Sends what was staged and takes the DLL's events, once a frame, right after the frame's tick.
    #
    # The bridge counts its own frames, which never go back as Graphics.frame_count does when a save
    # loads, since C#'s timers run on them.
    def frame
      return unless @context

      @frame = @frame >= MAX_FRAME ? 0 : @frame + 1
      send_staged
      drain
    end

    # Tells the bridge's frame, the one the last drain passed, which C#'s timers count by.
    #
    # @return [Integer] The frame, 0 before the first.
    def frame_number
      @frame
    end

    # Sends what was staged at once, outside the frame, such as the log's last lines as the game
    # closes.
    def flush
      send_staged if @context
    end

    private

    # Sends the staged entries as one batch and logs each entry that failed, once per topic and
    # code.
    def send_staged
      return if @staged.empty?

      failures = call(BATCH, @staged)
      @staged.clear
      failures.each { |entry| failed(entry["topic"], entry["error"], entry["text"]) } if failures.is_a?(Array)
    end

    # Takes the DLL's events and hands each to its topic's handlers.
    def drain
      length = @backend.drain(@context, @frame, @events, @events.bytesize)
      if length < 0
        # The DLL parked the events, which the next drain of the frame hands out.
        @events = buffer(-length)
        length = @backend.drain(@context, @frame, @events, @events.bytesize)
      end
      return if length <= 0

      Marshal.load(@events[0, length]).each { |topic, payload| dispatch(topic, payload) }
    rescue => e
      failed("(drain)", "script", "#{e.class}: #{e.message}")
    end

    # Hands an event to its topic's handlers; one that fails is logged and the others still run.
    #
    # @param topic [String] The event's topic.
    # @param payload [Object] The event's plain value.
    def dispatch(topic, payload)
      handlers = @handlers[topic]
      return failed(topic, "no_handler", "no script takes its events") unless handlers

      handlers.each do |handler|
        begin
          handler.call(payload)
        rescue => e
          failed(topic, "handler", "#{e.class}: #{e.message}")
        end
      end
    end

    # Calls a topic through the backend: the request dumped, a parked reply taken into a grown
    # buffer, and the reply loaded at once, since the next call writes into the same buffer.
    #
    # @param topic [String] The topic.
    # @param request [Object] A plain value, nil for none.
    # @return [Hash, nil] The reply's envelope, nil for no reply or while the bridge is closed.
    def exchange(topic, request)
      return nil unless @context

      dump = request.nil? ? NO_REQUEST : Marshal.dump(request)
      length = @backend.call(@context, name_of(topic), dump, dump.bytesize, @reply, @reply.bytesize)
      if length < 0
        @reply = buffer(-length)
        length = @backend.reply(@context, @reply, @reply.bytesize)
      end
      length > 0 ? Marshal.load(@reply[0, length]) : nil
    end

    # Names a topic as the DLL reads it, made once per topic.
    #
    # @param topic [String] The topic.
    # @return [String] The topic, null-terminated.
    def name_of(topic)
      (@names ||= {})[topic] ||= "#{topic}\0"
    end

    # Makes a buffer the DLL writes into.
    #
    # @param size [Integer] Its size in bytes.
    # @return [String] The buffer, binary, so its length counts bytes.
    def buffer(size)
      ("\0" * size).force_encoding("ASCII-8BIT")
    end

    # Logs a failure, once per topic and code.
    #
    # @param topic [String] The topic.
    # @param code [String] The error code, such as "bad_request", or what failed in the scripts.
    # @param text [String] What went wrong.
    def failed(topic, code, text)
      key = "#{topic} #{code}"
      return if @failures[key]

      @failures[key] = true
      Log.write("bridge: #{topic} failed with #{code}: #{text}")
    end

    # Keeps the bridge closed and logs why.
    #
    # @param reason [String] Why it did not open.
    # @return [Boolean] false.
    def refuse(reason)
      close
      Log.write("bridge: not opened, #{reason}")
      false
    end
  end

  # Gives the framework's bridge to its DLL, closed until the framework starts.
  #
  # @return [Bridge] The bridge.
  def self.bridge
    @bridge ||= Bridge.new
  end

  # Once the game runs, sends what the scripts staged for the bridge after every frame; the events
  # come back in the drain after the frame's tick (UI::Engine::Tick). Outermost, so it follows every mod's
  # Graphics.update hooks, however late a mod registers them.
  Run.on_start("bridge frame", :dll => true) do
    Hooks.outermost(Graphics.singleton_class, :update, :after, "Mod Framework bridge") { Mod_Framework.bridge.flush }
  end
end
