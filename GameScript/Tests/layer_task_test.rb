#----------------------------------------------------------------
#  layer_task_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers UI.task (design v2 section 4.7) in a booted game against FakeTree and a stand-in for C#'s
# clock, through a mod that sends a camp report: the wait asks every frame until the report is
# sent, a second one gives up once its seconds of the clock passed, and a third is cancelled.

require_relative "layer_support"

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  $clock_ms = 0
  fake.answer("notices.clock") { |_request| $clock_ms }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    frame

    # The report goes out: the wait asks each frame and hears the answer once it comes.
    $report = nil
    asked = 0
    heard = []
    sending = ui.task(-> { asked += 1; $report }, seconds: 30) { |answer| heard << [:sent, answer] }
    3.times { frame }
    waited = [sending.pending?, asked, heard.dup]
    $report = "issue 12"
    2.times { frame }
    check("the wait [pending while unanswered, asked each frame], then the answer once",
          [waited, sending.pending?, heard, asked], [[true, 3, []], false, [[:sent, "issue 12"]], 4])
    check("the log lines of the wait", $logged.grep(/a task of .*layer_task_test\.rb:\d+ (started, waiting at most 30 seconds|was answered: "issue 12")$/).size, 2)

    # No answer comes: the wait gives up after its seconds of the clock with nil.
    silent = ui.task(-> { nil }, seconds: 2) { |answer| heard << [:silent, answer] }
    $clock_ms = 1500
    frame
    early = heard.size
    $clock_ms = 2500
    frame
    check("a wait without answer [heard before its seconds, then what it heard]", [early, heard.last, silent.pending?], [1, [:silent, nil], false])

    # The mod cancels a wait: its block hears nothing more.
    later = ui.task(-> { "too late" }) { |answer| heard << [:later, answer] }
    later.cancel
    frame
    check("a cancelled wait", [later.pending?, heard.size], [false, 2])
  end
end
