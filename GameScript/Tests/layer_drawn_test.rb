#----------------------------------------------------------------
#  layer_drawn_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Placed the parts a test places inside the content of their root, which draws only there
#                            - Created
#
#----------------------------------------------------------------

# Covers UI::Drawn of the UI layer in a booted game against FakeTree, through a mod's camp window:
# an HP bar drawn by hand, as wide as the room its parent gives and drawn again as the HP fall; a
# rest button drawn by hand that confirm or a click presses; and a potion count drawn by hand whose
# places Left and Right step.

require_relative "layer_support"

CAMP_DRAWN = <<-RUBY
  module Camp_Drawn
    UI = Mod_Framework::UI

    class HpBar < UI::Drawn
      param :rate, 1.0

      def measure(width, height)
        [width, 8]
      end

      def draw(bitmap, rect)
        bitmap.fill_rect(rect.x, rect.y, (rect.width * rate).round, rect.height, Color.new(200, 40, 40))
      end
    end

    class RestButton < UI::Drawn
      event :rest

      def measure(width, height)
        [64, 24]
      end

      def role
        :button
      end

      def pressed
        emit :rest
      end
    end

    class PotionCount < UI::Drawn
      state :count, 1
      state(:steps) { [] }

      def measure(width, height)
        [96, 24]
      end

      def role
        :slider
      end

      def places
        4
      end

      def place
        count
      end

      def moved(place)
        self.count = place
        self.steps = steps + [place]
      end
    end

    class Camp < UI::Component
      state :hp, 100
      state :rests, 0

      def render
        window "Camp" do
          hp_bar rate: hp / 100.0
          rest_button on_rest: -> { self.rests = rests + 1 }
          potion_count
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Drawn.rb", CAMP_DRAWN)
    frame

    ui.open(Camp_Drawn::Camp)
    frame
    Graphics.update
    camp = ui::Engine::Layer.tops.last.mount.component
    bar, rest, potions = nodes_of(tree, "custom").map { |node| ui::Engine::Tree.component(node) }.select { |part| part.is_a?(ui::Engine::DrawnPart) }
    props = [bar, rest, potions].map { |part| tree.nodes[part.node][:props].values_at("focusable", "steps", "rows", "index") }
    check("the bar is no key stop, the button one, the count one that steps through its places [focusable, steps, rows, index]",
          props, [[false, false, 0, -1], [true, false, 0, -1], [true, true, 4, 1]])
    frame
    Graphics.update
    room = bar.parent.content_rect
    check("the bar is as wide as the room its window gives, 8 pixels high", tree.nodes[bar.node][:props]["measured"], [room.width, 8])

    red = [200, 40, 40, 255]
    widths = lambda { bar.surface.bitmap.fills.select { |fill| fill[4] == red }.map { |fill| fill[2] } }
    tree.rects[bar.node] = [room.x, room.y, 200, 8]
    frame
    Graphics.update
    check("the bar draws full in its place", widths.call.last, 200)

    # The party takes damage: the bar draws again at a quarter.
    camp.hp = 25
    frame
    Graphics.update
    check("the bar draws again at a quarter", widths.call.last, 50)

    # The rest button takes a click; the count steps to its third place.
    tell(tree, [[rest.node, "click"]])
    tell(tree, [[potions.node, "move", 2]])
    frame
    potion = potions.drawn
    check("the button pressed and the count stepped, which shows its new place [rests, steps, index]",
          [camp.rests, potion.steps, tree.nodes[potions.node][:props]["index"]], [1, [2], 2])
  end
end
