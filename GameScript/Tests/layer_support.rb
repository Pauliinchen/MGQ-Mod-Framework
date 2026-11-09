#----------------------------------------------------------------
#  layer_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# What the tests of the UI layer share: finding FakeTree's nodes of a kind, telling the scripts
# what C# tells, and loading a mod's code under its own file name.

require_relative "tree_support"

# Finds the nodes of a kind in FakeTree, in the order they were added.
#
# @param tree [FakeTree] The tree.
# @param kind [String] The kind, such as "button".
# @return [Array<Integer>] The nodes.
def nodes_of(tree, kind)
  tree.nodes.keys.sort.select { |node| tree.nodes[node][:kind] == kind }
end

# Posts what C# tells, then lets a frame tick and draw, as the game does: the events arrive in the
# tick, and the layer renders what they changed before the frame is drawn.
#
# @param tree [FakeTree] The tree.
# @param events [Array<Array>] The events, each [node, name, values...].
def tell(tree, events)
  tree.post("events", events)
  frame
  Graphics.update
end

# Runs a mod's code as the game's loader does, under the mod's file name, so the layer's messages
# name that file.
#
# @param file [String] The mod's file, such as "Patch/Camp_Notes.rb".
# @param code [String] Its code.
def load_mod(file, code)
  eval(code, TOPLEVEL_BINDING, file, 1)
end

# Tells the lines the layer wrote to the framework's log.
#
# @return [Array<String>] The lines after "UI: ".
def layer_lines
  $logged.grep(/\AUI: /).map { |line| line.sub(/\AUI: /, "") }
end
