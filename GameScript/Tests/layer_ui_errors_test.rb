#----------------------------------------------------------------
#  layer_ui_errors_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Answered the toasts and the general stack's corner as C#'s queue does, and read the toast's id in
#                              its log line
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

# Covers the framework's row Show UI Errors in a booted game against FakeTree, through a mod whose
# window fails: off by default, a UI error goes to the log only; once the player turns the row on,
# a new error also shows a toast that names the mod, once per cause, while the log takes it either
# way.

require_relative "layer_support"

BROKEN_CAMP = <<-RUBY
  module Broken_Camp
    UI = Mod_Framework::UI

    class Camp < UI::Component
      param :herbs, nil

      def render
        window "Camp" do
          text "\#{herbs.size} herbs"
        end
      end
    end

    class Shop < UI::Component
      def render
        window "Shop" do
          text gold_text
        end
      end
    end
  end
RUBY

# The game's options with Options > Mods holding no rows.
ERRORS_GAME = lambda do
  Object.send(:remove_const, :NWConst) if Object.const_defined?(:NWConst)
  Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; MOD_CONTENTS = [{ :key => :return }]; end; end")
end

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  dll.answer("notices.toast") { |toast| toast[1] || 3000 }
  dll.answer("notices.stack") { |_stack| { "corner" => "top_left", "at" => nil } }
  boot_tree(dll, :game => ERRORS_GAME) do
    ui = Mod_Framework::UI
    errors = ui::Engine::Errors
    load_mod("Patch/Broken_Camp.rb", BROKEN_CAMP)
    frame

    row = Mod_Framework::Options.rows.find { |each| each[:key] == :mf_ui_show_errors }
    check("the framework's row Show UI Errors stands in Options > Mods, off", [row && row[:name], row && row[:value].call], ["[Mod Framework] Show UI Errors", "Off"])
    toasts = lambda { $logged.grep(/toast \d+ for .*UI error in/) }

    ui.open(Broken_Camp::Camp)
    frame
    check("off: the failed render goes to the log, no toast [log lines, toasts]", [layer_lines.grep(/Camp's render failed/).size, toasts.call.size], [1, 0])

    # The player turns the row on: the next error shows a toast that names the mod, once.
    row[:on_change].call("On")
    ui.open(Broken_Camp::Shop)
    frame
    ui.open(Broken_Camp::Shop)
    frame
    check("on: the new error goes to the log and shows one toast naming the mod [log lines, toasts]",
          [layer_lines.grep(/Shop's render failed/).size, toasts.call.map { |line| line[/UI error in .*/] }], [1, ["UI error in Broken Camp. See the log."]])
    check("the row keeps On in the settings", [errors.shown?, row[:value].call], [true, "On"])
  end
end
