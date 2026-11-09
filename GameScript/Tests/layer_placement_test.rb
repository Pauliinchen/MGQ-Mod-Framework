#----------------------------------------------------------------
#  layer_placement_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed the check of an old side name
#      Paulinchen  2026-11-05: Covered a hud in the notices' layer without a frame
#                            - Covered a window that lies over a game window, hidden until it closes
#      Paulinchen  2026-11-04: Covered a hud that keeps its place as its live tooltip is read again
#                            - Kept a few flows of the places a mod's windows take and checked each outcome on its own
#                            - Rewrote the checks as flow tests of the places a mod's windows take
#                            - Created
#
#----------------------------------------------------------------

# Covers the placement params of the UI layer (design section 6) in a booted game against
# FakeTree: what a window, a dialog and a hud hand C#'s tree with the band of depths of each layer,
# the setting a place is kept under, a hud hidden under a CG and outside its scenes, a dialog
# closing with the window that opened it, a window beside a game window, a window over the game's
# options list as Options > Mods lies, a popover, and a side refused.
# ModFramework.Tests covers the places themselves.

require_relative "layer_support"

PLACES = <<-RUBY
  module Camp_Places
    UI = Mod_Framework::UI

    class Shop < UI::Component
      def render
        window "Shop", id: :shop do
          text "Wares"
          button "Leave", on_click: -> { UI.open(Sure) }
        end
      end
    end

    class Sure < UI::Component
      def render
        dialog "Sure?", id: :sure do
          text "Leave the camp?"
        end
      end
    end

    class Gold < UI::Component
      def render
        hud anchor: :top_right, order: 3, z: 5, tooltip: -> { "Gold in the purse" } do
          text "120 G"
        end
      end
    end

    class Saved < UI::Component
      def render
        hud anchor: :top_right, layer: :notices, frame: false do
          text "Saved to slot 3"
        end
      end
    end

    class Clock < UI::Component
      def render
        hud anchor: :top, shown_in: [Scene_Map] do
          text "Noon"
        end
      end
    end

    class Pack < UI::Component
      def render
        window "Pack", id: :pack, anchor: :top_right do
          text "Rope"
          button "Drop", on_click: -> { UI.open(Drop) { |_value, why| $whys << [:drop, why] } }
        end
      end
    end

    class Drop < UI::Component
      def render
        dialog "Drop the rope?", anchor: :bottom do
          text "It is gone for good."
        end
      end
    end

    class Details < UI::Component
      def render
        window "Details", id: :details, beside: "Window_MenuCommand", side: :right do
          text "More"
        end
      end
    end

    class ModOptions < UI::Component
      def render
        window nil, id: :mod_options, cover: "Window_Config" do
          text "Interface Look"
        end
      end
    end

    class Slots < UI::Component
      state :more, false

      def render
        window "Slots" do
          list ["Head", "Body"], id: :slots, on_submit: lambda { |_item| self.more = true }
          popover target: "#slots", side: :right, bind: :more, on_close: lambda { |why| $popover_closed = why } do
            text "A slot"
          end
        end
      end
    end
  end
RUBY

# A picture of the game as Cache.picture hands it out, by its size.
ShownPicture = Struct.new(:width, :height)

# A picture the map shows, as Game_Picture holds it.
MapPicture = Struct.new(:name, :origin, :x, :y, :zoom_x, :zoom_y, :opacity)

# The game's menu commands, a game window a mod's window lies beside.
MENU = lambda do
  Object.class_eval <<-RUBY
    class Window_MenuCommand < Window_Base
      def viewport; nil; end
    end
    class Window_Config < Window_Base
      def viewport; nil; end
    end
  RUBY
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => MENU) do
    ui = Mod_Framework::UI
    Object.class_eval("class Scene_Map < Scene_Base; end")
    load_mod("Patch/Camp_Places.rb", PLACES)
    $scene_now = Scene_Base.new
    frame
    props = lambda { |kind| tree.nodes[nodes_of(tree, kind).last][:props] }
    $whys = []

    # A window sits in the middle in the windows' band, a dialog it opens over it, one opened
    # outside any window in the middle, and a hud in its zone in the HUD band.
    shop = ui.open(Camp_Places::Shop)
    frame
    shop_node = nodes_of(tree, "window").last
    leave = nodes_of(tree, "button").last
    check("a window sits alone in the middle of the windows' band", props.call("window").values_at("anchor", "z"), ["center", 1000])
    check("its place is kept under the mod and the id", $registered.map { |request| request[0] }.include?("Camp_Places/shop"), true)
    sure = ui.open(Camp_Places::Sure)
    frame
    check("a dialog opened outside any window sits in the middle", props.call("dialog").values_at("anchor", "beside"), ["center", nil])
    sure.close
    frame
    tell(tree, [[leave, "click"]])
    check("a dialog a window opens lies over it in the dialogs' band", props.call("dialog").values_at("beside", "side", "z"), [shop_node, "over", 1050])
    shop.close
    frame
    ui.show(Camp_Places::Gold)
    frame
    check("a hud docks in its zone by its order in the HUD band with its z:", props.call("box").values_at("dock", "dock_order", "z"), ["top_right", 3, 205])
    4.times { frame }
    check("it keeps its zone and z: as its live tooltip is read again", props.call("box").values_at("dock", "dock_order", "z"), ["top_right", 3, 205])
    gold = $registered.find { |request| request[0] == "Camp_Places/Camp_Places::Gold" }
    check("a hud without an id keeps its moved place under its mod and its class", gold && gold[11], true)
    saved = ui.show(Camp_Places::Saved)
    frame
    check("a hud in the notices' layer lies above every window and dialog in the notices' band, gives room first in its zone and, without a frame, keeps no room for one",
          props.call("box").values_at("z", "gives_room", "padding"), [1090, true, [0, 0, 0, 0]])
    saved.hide
    frame

    # The hud hides while the map shows a CG or a novel scene runs, and stays over a standing
    # portrait; both are as large as the screen with see-through corners.
    pictures = { "ev_astaroth_hd1" => ShownPicture.new(640, 480), "80_zylphe_st01" => ShownPicture.new(640, 480) }
    Cache.define_singleton_method(:picture) { |name| pictures[name] }
    on_map = []
    $game_map = Struct.new(:screen).new(Struct.new(:pictures).new(on_map))
    $game_party = Struct.new(:in_novel).new(false)
    gold_node = nodes_of(tree, "box").last
    on_map << MapPicture.new("80_zylphe_st01", 0, 0, 0, 100, 100, 255)
    frame
    check("it stays over a standing portrait", tree.nodes[gold_node][:props]["visible"], true)
    on_map << MapPicture.new("ev_astaroth_hd1", 0, 0, 0, 100, 100, 255)
    frame
    check("it hides while the map shows a CG", tree.nodes[gold_node][:props]["visible"], false)
    on_map.pop
    frame
    check("it shows again once the CG is erased", tree.nodes[gold_node][:props]["visible"], true)
    $game_party.in_novel = true
    frame
    check("it hides while a novel scene runs", tree.nodes[gold_node][:props]["visible"], false)
    $game_party.in_novel = false

    # A dialog closes with the window that opened it, also one placed in a zone of its own, and one
    # opened outside it stays.
    pack = ui.open(Camp_Places::Pack)
    frame
    tell(tree, [[nodes_of(tree, "button").last, "click"]])
    elsewhere = ui.open(Camp_Places::Sure) { |_value, why| $whys << [:sure, why] }
    frame
    pack.close(nil)
    frame
    check("the dialog closes with the window that opened it, with :script, and one opened outside it stays", [$whys, elsewhere.open?], [[[:drop, :script]], true])
    elsewhere.close
    frame

    # A hud with shown_in: shows only in those scenes.
    ui.show(Camp_Places::Clock)
    frame
    clock_node = nodes_of(tree, "box").last
    check("a hud hides outside the scenes of its shown_in:", tree.nodes[clock_node][:props]["visible"], false)
    $scene_now = Scene_Map.new
    frame
    check("it shows in them", tree.nodes[clock_node][:props]["visible"], true)

    # A window beside a game window hides while that does not show and closes with the scene once it
    # is gone.
    menu = Window_MenuCommand.new(10, 20, 160, 120)
    $scene_now.instance_variable_set(:@command_window, menu)
    ui.open(Camp_Places::Details) { |_value, why| $whys << [:details, why] }
    frame
    details = nodes_of(tree, "window").last
    menu.visible = false
    frame
    check("it hides while the game window does not show", tree.nodes[details][:props]["visible"], false)
    menu.visible = true
    frame
    menu.dispose
    frame
    check("it closes with :scene once the game window is gone", $whys.last, [:details, :scene])

    # Options > Mods lies exactly over the game's options list, which hides while it is open, the
    # game's scripts still reading it as shown, and shows again as it closes.
    config = Window_Config.new(0, 72, 544, 344)
    $scene_now.instance_variable_set(:@config_window, config)
    options = ui.open(Camp_Places::ModOptions)
    frame
    covering = tree.nodes[nodes_of(tree, "window").last][:props]
    check("the window takes the game window's place and size", [covering["at"], covering["size"]], [[0, 72], [544, 344]])
    check("the game window hides while it is open, its scripts still reading it as shown", [config.instance_variable_get(:@visible), config.visible], [false, true])
    options.close
    frame
    check("the game window shows again as it closes", config.instance_variable_get(:@visible), true)

    # A popover opens beside its target once its state turns true, and cancel closes it.
    ui.open(Camp_Places::Slots)
    frame
    list = nodes_of(tree, "list").last
    tell(tree, [[list, "submit", 0, 0]])
    frame
    popover = tree.nodes.keys.sort.reverse.find { |node| tree.nodes[node][:parent].nil? && tree.nodes[node][:props]["side"] == "right" }
    check("the popover opens as a root of its own beside its target, lined up with its start", tree.nodes[popover][:props].values_at("beside", "z", "line_up"), [list, 1050, "start"])
    tell(tree, [[popover, "close"]])
    frame
    check("on_close hears :cancel", $popover_closed, :cancel)

  end
end
