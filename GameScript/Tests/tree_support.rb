#----------------------------------------------------------------
#  tree_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Took nil for the column of a root that stacks in none, as C# does
#      Paulinchen  2026-11-08: Placed no root that does not show, as C# does
#      Paulinchen  2026-11-07: Sized a root without a size to the places of what it holds, as C# does
#                            - Placed nothing inside a compact form not shown, as C# does
#                            - Found a part in a text as C# does
#                            - Matched a typed text against words as C# does
#      Paulinchen  2026-11-06: Judged every key as one a hotkey may take
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Took nil for the keys of a part that waits for a key, which ends the wait
#      Paulinchen  2026-11-04: Dropped the hold on the places, which no test uses
#                            - Took nil for the zone, the edge and what a root lies beside
#                            - Told the scripts the device used last, a gamepad while $pad is true
#                            - Built the test part on the engine's component
#                            - Took the rest of a change whose property is nil where C# refuses nil, and told that property
#                              refused as C# does
#                            - Counted how often a TestPart measures
#                            - Drew every text whole in the framework a test boots
#                            - Gave the game's scenes their main
#      Paulinchen  2026-10-31: Failed a test that sends a component property C#'s tree does not know
#      Paulinchen  2026-10-30: Took nil for the text field that steers a list
#                            - Took nil for the places a carried row may move to
#      Paulinchen  2026-10-29: Took nil for the share of a column a node takes
#                            - Took a focus key and the component cancel goes to as nil, and stood in for the equip
#                              sound
#                            - Reported the pointer and the wheel a test sets at the tick
#                            - Let a test define more of the game before the mods load
#                            - Reported the keys and the mouse buttons a test holds at the tick
#                            - Stood in for the game's system sounds
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# A booted game for the tests of the components: FakeTree, which plays C#'s ComponentTree far
# enough to give every node a place (its own layout rules ModFramework.Tests covers), the DLL's
# side answering the tree's tick and layout through it, and the game's scenes, Input and frames.

require_relative "boot_support"

STANDALONE = "Patch/Mod_Framework"

# C#'s tree as far as the scripts see it: the nodes the scripts add, set and remove, a place for
# each in a root that shows (one a test gives, else a root at its place and size and each child a
# row under the one before, inside its parent's padding), and what a test posts for the next report. A property set to
# nil where C# cannot take nil is left out and told refused, as Node.Apply refuses it.
class FakeTree
  # The height of the rows a child takes under the one before.
  ROW = 30

  # The properties C#'s Node takes, read from Node.cs, so a test fails on one C# would refuse.
  KNOWN = File.read(File.expand_path("../../ModFramework/Ui/Tree/Node.cs", __dir__)).scan(/case "(\w+)":/).flatten

  # The properties C# takes nil for.
  NILABLE = %w[at size min max measured text font layout_id index width height focus_key cancel_to max_share move_span up_to dock anchor edge beside capture column]

  # @return [Array<Array>] Each property refused, as its node and its name.
  attr_reader :refused

  # @return [Hash{Integer => Hash}] Each node: :parent, :kind, :props and :children.
  attr_reader :nodes

  # @return [Array<Hash>] Each change the scripts sent, from a tick or a layout, as it came.
  attr_reader :changes

  # @return [Hash{Integer => Array}] Places a test gives nodes, by node id.
  attr_reader :rects

  # @return [Integer] How often the scripts emptied the tree.
  attr_accessor :resets

  # Makes an empty tree.
  def initialize
    @nodes = {}
    @changes = []
    @rects = {}
    @told = {}
    @pending = {}
    @resets = 0
    @refused = []
  end

  # Takes the scripts' changes, as Change does in C#.
  #
  # @param changes [Hash] The changes, see ComponentTree.ModelName.
  def apply(changes)
    @changes << changes
    Array(changes["add"]).each { |node, parent, kind, index, props| add(node, parent, kind, index, taken(node, props || {})) }
    Array(changes["set"]).each { |node, props| @nodes[node][:props].update(taken(node, props)) if @nodes[node] }
    Array(changes["remove"]).each { |node| remove(node) }
  end

  # Queues a part of the next report, such as events.
  #
  # @param part [String] The part, such as "events".
  # @param value [Object] Its value; events and cues add to those queued.
  def post(part, value)
    @pending[part] = value.is_a?(Array) && @pending[part].is_a?(Array) ? @pending[part] + value : value
  end

  # Builds what changed since the last report: the places of the nodes that are new or moved in
  # roots that show, and what a test posted.
  #
  # @return [Hash] The report, see ComponentTree.EventTopic.
  def report
    report = @pending
    @pending = {}
    rects = {}
    @roots = {}
    @nodes.each_key do |node|
      next if in_hidden_root?(node)

      rect = rect_of(node)
      rects[node] = rect unless @told[node] == rect
      @told[node] = rect
    end
    report["rects"] = rects unless rects.empty?
    report
  end

  # Finds the node of a kind added last.
  #
  # @param kind [String] The kind, such as "window".
  # @return [Integer, nil] Its id.
  def last(kind)
    @nodes.keys.select { |node| @nodes[node][:kind] == kind }.max
  end

  private

  # Tells a component's properties without those C# refuses as nil, telling each refused in the
  # next report.
  #
  # @param node [Integer] The component's node id.
  # @param props [Hash] Its properties.
  # @return [Hash] The properties taken.
  def taken(node, props)
    ($unknown_props ||= []).concat(props.keys - KNOWN - $unknown_props)
    refused = props.keys.select { |key| props[key].nil? && !NILABLE.include?(key) }
    refused.each do |key|
      @refused << [node, key]
      post("refused", [[node, "The #{key} of a component cannot be nil.", false]])
    end
    props.reject { |key, _value| refused.include?(key) }
  end

  # Adds a node, leaving out one whose parent is gone, as C# does.
  def add(node, parent, kind, index, props)
    return if parent && !@nodes[parent]

    @nodes[node] = { :parent => parent, :kind => kind, :props => props, :children => [] }
    return unless parent

    siblings = @nodes[parent][:children]
    index ? siblings.insert([index, siblings.size].min, node) : siblings << node
  end

  # Removes a node with every node it holds.
  def remove(node)
    entry = @nodes.delete(node)
    return unless entry

    @told.delete(node)
    @nodes[entry[:parent]][:children].delete(node) if entry[:parent] && @nodes[entry[:parent]]
    entry[:children].each { |child| remove(child) }
  end

  # Tells whether a node lies in a root that does not show, which C# places nowhere.
  def in_hidden_root?(node)
    node = @nodes[node][:parent] while @nodes[node][:parent]
    @nodes[node][:props]["visible"] == false
  end

  # Tells a node's place: none inside a compact form not shown, which itself takes no room, as C#
  # shows the part itself of each part's forms and lays out nothing inside the others.
  def rect_of(node)
    return @rects[node] if @rects[node]

    entry = @nodes[node]
    entry[:parent] ? child_rect(node, rect_of(entry[:parent])) : root_rect(node)
  end

  # Tells a root's place: at its place, at its size, else large enough for the places of what it
  # holds with its padding, as C# sizes a root to what it holds, which draws only inside it.
  def root_rect(node)
    (@roots ||= {})[node] ||= begin
      props = @nodes[node][:props]
      at = props["at"] || [0, 0]
      size = props["size"] || [nil, nil]
      x, y = at[0] || 0, at[1] || 0
      _top, right, bottom, _left = props["padding"] || [0, 0, 0, 0]
      far_right, far_bottom = extent(node, [x, y])
      [x, y, size[0] || [200, far_right - x + right].max, size[1] || [100, far_bottom - y + bottom].max]
    end
  end

  # Tells a child's place in its parent's place: a row under the one before, inside the parent's
  # padding.
  def child_rect(node, parent)
    return @rects[node] if @rects[node]

    entry = @nodes[node]
    return nil if parent.nil? || hidden_form?(entry[:parent])

    top, _right, _bottom, left = @nodes[entry[:parent]][:props]["padding"] || [0, 0, 0, 0]
    return [parent[0] + left, parent[1] + top, 0, 0] if hidden_form?(node)

    place = @nodes[entry[:parent]][:children].index(node)
    [parent[0] + left, parent[1] + top + ROW * place, 100, 24]
  end

  # Tells how far right and down the places of what a node holds reach, the node at a place.
  def extent(node, rect)
    @nodes[node][:children].inject([0, 0]) do |far, child|
      place = child_rect(child, rect)
      next far unless place

      inside = extent(child, place)
      [[far[0], place[0] + place[2], inside[0]].max, [far[1], place[1] + place[3], inside[1]].max]
    end
  end

  # Tells whether a node is a compact form not shown: a form after the part itself.
  def hidden_form?(node)
    parent = @nodes[node][:parent]
    parent && @nodes[parent][:props]["forms"] && @nodes[parent][:children].index(node) > 0 ? true : false
  end
end

at_exit { check("every component property sent is one C#'s tree knows", $unknown_props || [], []) }

# The game's system sounds, noted in $sounds.
module Sound
  # Notes the confirm sound.
  def self.play_ok
    ($sounds ||= []) << :ok
  end

  # Notes the buzzer.
  def self.play_buzzer
    ($sounds ||= []) << :buzzer
  end

  # Notes the cancel sound.
  def self.play_cancel
    ($sounds ||= []) << :cancel
  end

  # Notes the cursor sound.
  def self.play_cursor
    ($sounds ||= []) << :cursor
  end

  # Notes the equip sound.
  def self.play_equip
    ($sounds ||= []) << :equip
  end
end

# Defines TestPart anew over the framework just booted: a component of a test that measures 100 by
# 24, counting each time it measures, notes each time it draws with its canvas's picture and size,
# and writes its id.
def define_test_part
  Object.send(:remove_const, :TestPart) if defined?(TestPart)
  Object.class_eval <<-RUBY
    class TestPart < Mod_Framework::UI::Engine::Component
      attr_reader :draws, :measures
      def initialize(options = {}); super; @draws = []; @measures = 0; end
      def measure; @measures += 1; [100, 24]; end
      def draw(canvas); @draws << [canvas.bitmap, canvas.width, canvas.height]; canvas.text(0, 0, canvas.width, canvas.height, id.to_s); end
    end
  RUBY
end

# Makes the DLL's side: the log, the ini in $files, the layout's registrations in $registered, every
# key judged one a hotkey may take, and the frame's tick and the tree's layout through a FakeTree; the tick reports the keys in $keys
# (bits by key code), the mouse buttons in $mouse_buttons, the pointer in $mouse_at and the wheel's
# notches in $wheel, which it hands out once.
#
# @param tree [FakeTree] The tree.
# @return [FakeBridge] The DLL's side.
def tree_dll(tree)
  fake = FakeBridge.new
  fake.build = "0.1.0"
  fake.answer("log.write") { |(_time, line)| $logged << line; nil }
  fake.answer("log.flush") { |_request| nil }
  fake.answer("ini.read") { |(path)| $files[path] || {} }
  fake.answer("ini.write") { |(path, values)| $files[path] = values.dup; true }
  fake.answer("keys.judge") { |_code| "bind" }
  fake.answer("text.match") { |(typed, words)| words.select { |word| word.downcase.include?(typed.downcase) && word.downcase != typed.downcase } }
  fake.answer("text.find") do |(text, part)|
    places = []
    at = text.downcase.index(part.downcase)
    while at
      places << [at, part.size]
      at = text.downcase.index(part.downcase, at + part.size)
    end
    places
  end
  fake.answer("ui.layout.register") { |request| $registered << request; false }
  fake.answer("ui.layout.rect") { |request| request[1, 4] + [false] }
  fake.answer("ui.tree.reset") { |_request| tree.resets += 1; nil }
  fake.answer("ui.tree.layout") { |changes| tree.apply(changes); tree.report }
  fake.answer("ui.tick") do |request|
    $ticks << request
    wheel = $wheel || 0
    $wheel = 0
    fake.post("ui.input", "mouse" => $mouse_at, "buttons" => $mouse_buttons || 0, "double" => false, "wheel" => wheel, "keys" => $keys || {}, "front" => true, "pad" => $pad == true)
    tree.apply(request["tree"]) if request["tree"]
    report = tree.report
    fake.post("ui.tree", report) unless report.empty?
    nil
  end
  fake
end

# Boots the framework in the current game folder with a game that has scenes, whose Input reports
# the buttons in $pressed, and runs a block as the game's scenes.
#
# @param fake [FakeBridge] The DLL's side.
# @param options [Hash] :dll (false for a copy without its DLL), :game (a Proc that defines more of
#   the game before the mods load).
# @yield Runs as SceneManager.run.
def boot_tree(fake, options = {}, &scenes)
  new_session
  options[:game].call if options[:game]
  $logged = []
  $files = {}
  $registered = []
  $ticks = []
  $pressed = []
  $scene_now = :map
  Object.send(:remove_const, :Scene_Base) if defined?(Scene_Base)
  Object.class_eval <<-RUBY
    class Scene_Base; def main; end; def terminate; end; end
    module SceneManager; def self.scene; $scene_now; end; end
    module Input
      def self.trigger?(button); $pressed.include?(button); end
      def self.press?(button); $pressed.include?(button); end
      def self.repeat?(button); $pressed.include?(button); end
    end
  RUBY
  $dll = fake
  install_stub
  install_copy(STANDALONE, "0.1.0", :real => true, :dll => options[:dll])
  run_patch_loader
  whole_texts
  define_test_part
  $scenes = scenes
  SceneManager.run
end

# Has the framework just booted draw every text whole with draw_text, where Bitmap notes it as one
# text, instead of from copies of its characters, which glyph_cache_test covers.
def whole_texts
  Mod_Framework::UI::Engine::GlyphCache.on = false if defined?(Mod_Framework::UI::Engine::GlyphCache)
end

# Runs one frame as the game does: the frame before shows, Input reads the frame's buttons and the
# tick goes over; the scene runs after it.
#
# @param pressed [Array<Symbol>] The game's buttons pressed in this frame.
def frame(pressed = [])
  $pressed = pressed
  Graphics.update
  Input.update
end
