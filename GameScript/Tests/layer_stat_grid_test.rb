#----------------------------------------------------------------
#  layer_stat_grid_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers stat_grid of the UI layer in a booted game against FakeTree, through a mod's training
# window: a party member's stats in two dense columns, and after training the values that rose in
# the game's color for better, those that fell in its color for worse, a rate judged by its number,
# and the same rows plain again without the rows before.

require_relative "layer_support"

TRAINING = <<-RUBY
  module Camp_Training
    UI = Mod_Framework::UI

    class TrainingWindow < UI::Component
      state(:rows) { [{ name: "ATK", value: 330 }, { name: "DEF", value: 200 }, { name: "Hit", value: "95%", number: 95 }] }
      state :before, nil

      def render
        window "Training" do
          stat_grid rows, before: before, columns: 2, size: :small, dense: true
        end
      end

      def train
        self.before = rows
        self.rows = [{ name: "ATK", value: 630 }, { name: "DEF", value: 150 }, { name: "Hit", value: "95%", number: 95 }]
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Training.rb", TRAINING)
    frame

    # The stats fill two dense columns in the small font, plain.
    ui.open(Camp_Training::TrainingWindow)
    frame
    window = ui::Engine::Layer.tops.last.mount.component
    grid = ui::Engine::Tree.component(nodes_of(tree, "stats").first)
    colors = lambda { grid.rows.map { |row| grid.send(:value_color, row) } }
    check("the stats show in two dense columns, plain", [grid.columns, grid.font_size, grid.send(:row_height), colors.call], [2, :small, 18, [nil, nil, nil]])

    # Training raised ATK, lowered DEF and left Hit as it was.
    window.train
    frame
    up, down = ui::Game::POWER_UP_COLOR, ui::Game::POWER_DOWN_COLOR
    check("a value that rose shows in the color for better, one that fell in the color for worse", colors.call, [up, down, nil])

    # Without the rows before, the values show plain again.
    window.before = nil
    frame
    check("without the rows before the values show plain", colors.call, [nil, nil, nil])
  end
end
