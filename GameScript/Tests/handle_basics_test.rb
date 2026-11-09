#----------------------------------------------------------------
#  handle_basics_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Asked UI.number without digits:
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

# Covers what every handle of the framework answers as any object does in a
# booted game against FakeTree: a scene that keeps each kind of handle in its variables, as a mod
# keeps the handle of a window it opened, runs MGQ Paradox's all_windows, which asks each variable
# is_a?(Window), without failing, and finds only its game window (the crash of 2026-11-06 in
# update_all_windows).

require_relative "layer_support"

CAMP_HANDLES = <<-RUBY
  module Camp_Handles
    UI = Mod_Framework::UI

    class Notes < UI::Component
      def render
        window "Notes", id: :camp_notes do
          text "Buy Herbs in Iliasburg", id: :camp_line
        end
      end

      def line_handle
        part(:camp_line)
      end
    end

    class Gold < UI::Component
      def render
        hud anchor: :top_right, id: :camp_gold do
          text "250 G"
        end
      end
    end
  end
RUBY

# A scene of MGQ Paradox, with its all_windows as the game's Scene_Base has it; the game's Window
# class is RGSS's, which this test's game stands in for with Window_Base.
class ParadoxScene
  # Lists the scene's windows that are not disposed, as the game does before it updates them.
  #
  # @return [Array] The windows.
  def all_windows
    ivers = instance_variables.map do |varname|
      instance_variable_get(varname)
    end
    ivers.select do |iver|
      iver.is_a?(defined?(::Window) ? ::Window : ::Window_Base) && !iver.disposed?
    end
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Handles.rb", CAMP_HANDLES)
    frame

    window = Window_Base.new(0, 0, 32, 32)
    notes = ui.open(Camp_Handles::Notes)
    frame
    handles = {
      :open => notes,
      :show => ui.show(Camp_Handles::Gold),
      :part => ui::Engine::Layer.tops.find { |top| top.id == "camp_notes" }.mount.component.line_handle,
      :confirm => ui.confirm("Leave the camp?") { |_yes| nil },
      :message => ui.message("Saved.") { nil },
      :number => ui.number(3, max: 20) { |_number, _shown| nil },
      :menu => ui.menu(["Rest", "Cook"]) { |_choice, _index| nil },
      :task => ui.task(-> { nil }, seconds: 5) { |_answer| nil },
      :game_window => ui::Engine::ReplacedWindows::Facade.new(window)
    }
    frame
    check("every kind of handle was made", handles.reject { |_kind, handle| handle }.keys, [])

    scene = ParadoxScene.new
    scene.instance_variable_set(:@command_window, window)
    handles.each { |kind, handle| scene.instance_variable_set(:"@#{kind}", handle) }
    found = begin
      scene.all_windows
    rescue NoMethodError => e
      e.message
    end
    check("all_windows over a scene that keeps every kind of handle finds its game window alone", found, [window])
    check("a handle answers for its own class and for no game class [is_a? OpenHandle, is_a? Window, nil?, instance_of?]",
          [notes.is_a?(ui::Engine::OpenHandle), notes.is_a?(Window_Base), notes.nil?, handles[:number].instance_of?(ui::Engine::NumberHandle)],
          [true, false, false, true])
  end
end
