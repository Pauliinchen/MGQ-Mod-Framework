#----------------------------------------------------------------
#  component_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Drew a cached text with the outline and opacity the cache now takes
#      Paulinchen  2026-11-06: Kept only the pictures of texts and the batches C# refused, which no layer test walks
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Kept a few flows of a window of components and checked each outcome on its own
#                            - Took over the dump of the tree
#                            - Rewrote the checks as flow tests of a window of components and its frames
#                            - Covered a change C#'s tree refused logged in the mod's log, and every root sent again once
#                              C# could not read the changes
#                            - Covered options set to the value they hold, which send and draw nothing, and options
#                              changed several times in a frame, measured once
#                            - Covered a text drawn once and copied afterwards, the pictures of texts kept within their
#                              budget, and all of them freed at the title
#                            - Covered a part drawn anew without the parts beside it, and a moved part cleared where it was
#      Paulinchen  2026-10-29: Covered a steady component with a share of its column
#                            - Covered cancel sent to a component added after it, the focus key of an id and the
#                              screen's size
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Covers what tree.rbx does that no layer test walks, in a booted game against FakeTree, which
# plays C#'s tree: the pictures of texts within their budget, and a batch C# refused or could not
# read.

require_relative "tree_support"

# A mod's own log, which a refused change of its components writes into.
module SampleModLog
  @lines = []

  # Tells the lines written.
  #
  # @return [Array<String>] The lines.
  def self.lines
    @lines
  end

  # Writes a line.
  #
  # @param line [String] The line.
  def self.log(line)
    @lines << line
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame
    window = ui::Engine::Window.new(:title => "Notes", :log => SampleModLog)
    plain = window.add(TestPart.new(:id => :plain))
    window.open
    Graphics.update

    # The pictures of texts stay within their budget and are freed at the title.
    cache = ui::Engine::LabelCache
    cache.clear
    big = (1..3).map { |number| cache.find(["big #{number}"]) { cache::Label.new(Bitmap.new(1024, 512), 0, 0, false) }.bitmap }
    check("the pictures of texts take at most 4 MB, the least recently drawn freed first", big.map { |bitmap| bitmap.disposed? }, [true, false, false])
    Object.class_eval("class Scene_Title < Scene_Base; end") unless defined?(Scene_Title)
    $scene_now = Scene_Title.new
    ui::Engine::Tree.scene_ended(Object.new)
    $scene_now = :map
    check("all are freed at the title", big.map { |bitmap| bitmap.disposed? }, [true, true, true])

    # Many texts lie on the few shared sheets within the budget, and a text whose sheet was cleared
    # draws anew.
    draw = lambda { |text| cache.find([text, 20]) { cache.draw(text, 20, ui::Engine::Style::TEXT, nil, nil, 300, 24, 0, nil) } }
    draw.call("warm")
    cache.clear
    made = 0
    Bitmap.class_eval do
      alias_method :uncounted_initialize, :initialize
      define_method(:initialize) { |*args| uncounted_initialize(*args); made += 1 }
    end
    first = draw.call("text 0")
    2000.times { |index| draw.call("text #{index + 1}") }
    again = draw.call("text 0")
    Bitmap.class_eval { alias_method :initialize, :uncounted_initialize }
    check("many texts lie on the few shared sheets within the budget, besides the picture that measures, and one whose sheet was cleared draws anew",
          [made, cache.size[1] <= cache::BUDGET, again.equal?(first), again.bitmap.disposed?], [cache::MOST_SHEETS + 1, true, false, false])

    # A property C# refused is logged, and after a batch C# could not read every open root goes over
    # again (818c6d72).
    tree.post("refused", [[plain.node, "No component property is named colour.", false]])
    frame
    check("a refused property is logged in the mod's log",
          SampleModLog.lines.grep(/TestPart plain kept its last value: No component property is named colour\./).size, 1)
    tree.post("resync", "Expected an Array, found Integer.")
    frame
    Graphics.update
    check("every open root goes over again", tree.changes.last["add"].map { |add| add[2] }.count("window"), ui::Engine::Tree.roots.size)
  end
end
