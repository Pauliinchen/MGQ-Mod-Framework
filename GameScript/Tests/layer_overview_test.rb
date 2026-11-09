#----------------------------------------------------------------
#  layer_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers the parts of a world overview built on the UI layer (design v2 sections 5.13 and 14.3,
# overview.md) in a booted game against FakeTree: a window with the root id overview that stays open
# only on a free map, its tabs with a dot while a call waits on another page, the tabs two other mods
# add by UI.patch "#overview" in their load order, and the notice stack hidden while it shows.

require_relative "layer_support"

WORLD_OVERVIEW = <<-RUBY
  module World_Overview
    UI = Mod_Framework::UI

    class Overview < UI::Component
      state :page, :players
      state :called, false

      def render
        window "World overview", id: :overview, place_name: "World overview", if: :map_free, close_outside: true do
          tabs bind: :page, wrap: true, arrows: true, id: :overview_tabs do
            tab "Players", id: :players, badge: called && page != :players ? true : nil do
              table ["Ana", "Mia"], id: :players_table do
                column "Name"
              end
            end
            tab "Quests", id: :quests do
              text "Go to the harpy village."
            end
          end
        end
      end
    end

    def self.open?
      @handle && @handle.open?
    end

    def self.open
      @handle = UI.open(Overview) { |_value, why| (@closed ||= []) << why }
    end

    def self.closed
      @closed || []
    end

    UI.notices_hidden_while(:world_overview) { World_Overview.open? }
  end
RUBY

JOB_POINTS = <<-RUBY
  module Job_Points
    UI = Mod_Framework::UI

    UI.patch "#overview" do |o|
      o.append "tabs" do
        tab "Job Points", id: :job_points do
          text "3 points left"
        end
      end
    end
  end
RUBY

CAMP_LOG = <<-RUBY
  module Camp_Log
    UI = Mod_Framework::UI

    UI.patch "#overview" do |o|
      o.append "tabs" do
        tab "Camp Log", id: :camp_log do
          text "Day 3"
        end
      end
    end
  end
RUBY

# A stand-in for the game's map scene.
class Scene_Map
end

# A stand-in for the map's event runner.
class TestInterpreter
  # @return [Boolean] Whether an event runs.
  attr_accessor :running

  # @return [Boolean] Whether an event runs.
  def running?
    @running ? true : false
  end
end

# A stand-in for the game's map, which holds the event runner.
class TestMap
  # @return [TestInterpreter] The event runner.
  attr_reader :interpreter

  # Makes the map with no event running.
  def initialize
    @interpreter = TestInterpreter.new
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    $scene_now = Scene_Map.new
    $game_map = TestMap.new
    load_mod("Patch/World_Overview.rb", WORLD_OVERVIEW)
    load_mod("Patch/Job_Points.rb", JOB_POINTS)
    load_mod("Patch/Camp_Log.rb", CAMP_LOG)
    frame

    # On a free map it opens with its own tabs, then the tabs of the two mods in their load order;
    # the notice stack hides while it shows.
    World_Overview.open
    frame
    Graphics.update
    overview = ui::Engine::Layer.tops.last.mount.component
    root = ui::Engine::Tree.roots.last
    tabs = root.find(:overview_tabs)
    titles = lambda { (0...tabs.pages.size).map { |place| tabs.tab(place).text } }
    check("the overview on a free map [open, tabs, notices shown]", [World_Overview.open?, titles.call, ui::Engine::Notices.shown?],
          [true, ["Players", "Quests", "Job Points", "Camp Log"], false])

    # A call while another page shows puts a dot on the Players tab, gone once Players shows.
    tell(tree, [[tabs.tab(2).node, "click"]])
    overview.called = true
    frame
    Graphics.update
    dot = tabs.tab(0).badge
    tell(tree, [[tabs.tab(0).node, "click"]])
    check("the dot of a call [on Job Points, back on Players, page]", [dot, tabs.tab(0).badge, overview.page], [true, nil, :players])

    # An event that starts closes it with its reason, and it does not open while the event runs;
    # the notice stack shows again.
    $game_map.interpreter.running = true
    frame
    World_Overview.open
    frame
    check("an event started [open, why it closed, then why the open was refused, notices shown]",
          [World_Overview.open? ? true : false, World_Overview.closed, ui::Engine::Notices.shown?], [false, ["an event runs", "an event runs"], true])
  end
end
