#----------------------------------------------------------------
#  layer_progress_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a bar whose border is a shade of its live fill color
#                            - Covered the refusal of framed:, which border: replaces
#      Paulinchen  2026-11-07: Covered the fill of a bar that drains as it falls, rises at once and drops at once without animations
#                            - Placed the parts a test places inside the content of their root, which draws only there
#      Paulinchen  2026-11-06: Covered a line of gold that shows the first of its texts that fits
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers progress of the UI layer (design v2 section 5.4) in a booted game against FakeTree, through
# a mod's camp HUD and a stand-in for C#'s clock: an HP bar bound to the leader's live HP with its
# label and its value, whose fill drains as it falls and whose loss stays as a trail, a thin bar of a wait whose length nobody knows, whose stripe sweeps along it,
# a line of the party's gold that shows the first of its ever shorter texts that fits its room,
# and a thin MP bar whose border is a darker shade of its live fill color; framed: is refused,
# naming border:.

require_relative "layer_support"

CAMP_BARS = <<-RUBY
  module Camp_Bars
    UI = Mod_Framework::UI

    class Bars < UI::Component
      def render
        hud anchor: :top_left, id: :camp_bars, fade: false do
          progress value: -> { $camp_hp }, max: 252, label: "HP", value_text: -> { "\#{$camp_hp} / 252" }, trail: true, id: :camp_hp, width: 200
          progress indeterminate: true, size: :small, id: :camp_wait, width: 200
          text -> { ["Gold: \#{$camp_gold} G", "\#{$camp_gold} G", "\#{$camp_gold / 1000}k"] }, id: :camp_gold
          progress value: 40, color: -> { $camp_mp_color }, border: :shade, size: :small, id: :camp_mp, width: 200
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  $clock_ms = 0
  fake.answer("notices.clock") { |_request| $clock_ms }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Bars.rb", CAMP_BARS)
    $camp_hp = 189
    $camp_gold = 12345
    $camp_mp_color = "#40C080"
    frame
    ui.show(Camp_Bars::Bars)
    frame
    Graphics.update
    root = ui::Engine::Layer.tops.last.root.engine
    hp = root.find(:camp_hp)
    wait = root.find(:camp_wait)
    drawn = lambda { root.base_surface.bitmap.texts.map { |text| text[2] } }

    # The HP bar is filled to 189 of 252 and draws HP at its left and the numbers at its right.
    check("the HP bar's rate", hp.rate.round(2), 0.75)
    check("its texts drawn", drawn.call & ["HP", "189 / 252"], ["HP", "189 / 252"])

    # A hit drains the fill down over the clock's seconds while what was lost stays as a trail for
    # its two seconds, and the numbers follow at once; a rise shows at once and ends both.
    state = lambda do
      frame
      Graphics.update
      fill = hp.instance_variable_get(:@fill)
      [fill && fill.round(2), hp.instance_variable_get(:@trail), hp.value]
    end
    $camp_hp = 63
    hit = state.call
    $clock_ms = 50
    draining = state.call
    $camp_hp = 31
    again = state.call
    $clock_ms = 1000
    drained = state.call
    $camp_hp = 189
    risen = state.call
    check("the HP bar's [fill, trail, value text] at a hit, 50 ms on, at a second hit then, 1 second on and after a rise",
          [hit, draining, again, drained, risen],
          [[0.75, 0.75, "63 / 252"], [0.57, 0.75, "63 / 252"], [0.57, 0.75, "31 / 252"], [nil, 0.75, "31 / 252"], [nil, nil, "189 / 252"]])

    # With the Animations row Off a hit takes the fill down at once.
    ui::Engine::Animations.turn(false)
    $camp_hp = 63
    off = state.call
    ui::Engine::Animations.turn(true)
    check("the HP bar's fill at a hit while animations are off", off[0], nil)

    # The wait bar is 4 pixels high without texts, and its stripe moves on from frame to frame.
    check("the wait bar's size", tree.nodes[wait.node][:props]["size"], [200, 4])
    tree.rects[wait.node] = [root.content_rect.x, 40, 200, 4]
    frame
    stripe = lambda do
      Graphics.update
      root.base_surface.bitmap.fills.select { |fill| fill[1] == 41 && fill[3] == 2 && fill[2] < 198 }.last
    end
    before = stripe.call
    10.times { frame }
    after = stripe.call
    check("the stripe ten frames on reaches further right", before && after && after[0] + after[2] > before[0] + before[2], true)

    # The gold line shows its whole text where it has the room, a shorter one where the HUD is
    # narrower, with the whole text as its tooltip, and the shortest where none fits.
    gold = root.find(:camp_gold)
    gold_drawn = lambda do |width|
      tree.rects[gold.node] = [root.content_rect.x, 50, width, 24]
      2.times { frame }
      Graphics.update
      [root.base_surface.bitmap.texts.select { |text| text[1] == 50 }.last[2], gold.tooltip]
    end
    check("the gold line 300, 100 and 40 pixels wide [text drawn, tooltip]", [gold_drawn.call(300), gold_drawn.call(100), gold_drawn.call(40)],
          [["Gold: 12345 G", nil], ["12345 G", "Gold: 12345 G"], ["12k", "Gold: 12345 G"]])

    # The MP bar's border of one pixel is a darker shade of its fill, and follows its live color.
    mp = root.find(:camp_mp)
    tree.rects[mp.node] = [root.content_rect.x, 80, 200, 8]
    mp_drawn = lambda do
      2.times { frame }
      Graphics.update
      fills = root.base_surface.bitmap.fills
      [fills.select { |fill| fill[1] == 81 && fill[3] == 6 && fill[2] == 79 }.last[4], fills.select { |fill| fill[1] == 80 && fill[2] == 200 && fill[3] == 1 }.last[4]]
    end
    green = mp_drawn.call
    $camp_mp_color = "#C04040"
    red = mp_drawn.call
    check("the MP bar's [fill, border] in green and once its color turned red", [green, red],
          [[[64, 192, 128, 255], [32, 96, 64, 255]], [[192, 64, 64, 255], [96, 32, 32, 255]]])

    refusal = begin
      ui::Engine::Declarations[:progress].take([{ :value => 40, :framed => true }])
      nil
    rescue ui::Engine::MarkupError => e
      e.message
    end
    check("framed: is refused, naming border:", [refusal.to_s.include?("takes no framed:"), refusal.to_s.include?("border:")], [true, true])
  end
end
