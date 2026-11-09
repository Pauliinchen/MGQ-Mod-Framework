#----------------------------------------------------------------
#  idle_frame_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Read the samples from their .rb files
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers the objects the framework's scripts make in an idle frame, in a booted game against
# FakeTree: the Equipment Window sample open and nothing pressed, as the in-game suite probes it.
# Every object brings the game's next garbage collection closer.

require "objspace"
require_relative "game_lists_support"
require_relative "layer_support"
require_relative "equip_support"

# The Equipment Window sample.
EQUIPMENT_WINDOW = File.read(File.expand_path("../../Samples/Equipment_Window.rb", __dir__), :encoding => "UTF-8")

# The idle frames counted.
IDLE_FRAMES = 30

# The most objects the framework's scripts may make in an idle frame here, under Ruby 3.3; the
# game's Ruby 1.9 makes more of the same, such as every Float.
MOST_OBJECTS = 12

# Counts the objects the framework's scripts make over a number of frames.
#
# @param frames [Integer] The frames.
# @return [Integer] The objects, made in a file of the framework's scripts.
def framework_objects(frames)
  GC.disable
  ObjectSpace.trace_object_allocations { frames.times { frame } }
  count = 0
  ObjectSpace.each_object { |object| count += 1 if ObjectSpace.allocation_sourcefile(object).to_s.end_with?(".rbx") }
  count
ensure
  GC.enable
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    [:Scene_Map, :Scene_Equip].each { |name| Object.const_set(name, Class.new(Scene_Base)) unless Object.const_defined?(name) }
    luka = equip_party
    load_mod("Patch/Equipment_Window.rb", EQUIPMENT_WINDOW)
    Mod_Framework::UI.open(Equipment_Window::EquipWindow, actor: luka)
    40.times { frame }
    each_frame = (framework_objects(IDLE_FRAMES) / IDLE_FRAMES.to_f).round
    check("an idle frame of the Equipment Window makes at most #{MOST_OBJECTS} objects in the framework's scripts", each_frame <= MOST_OBJECTS ? :within : each_frame, :within)
  end
end
