#----------------------------------------------------------------
#  notices_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered a toast queued in the frame in which the last toast goes, which C# still ticks
#                            - Covered a short and a tall toast in a stack that grows up from a spot, which never overlap
#                            - Covered a toast stack a mod defines, its toasts placed where it lies, the refusals of a toast into
#                              no stack and of a stack without a name, the corner the general stack tells C#, and toasts that
#                              C# ticks on while the stack hides
#                            - Moved the toasts by the offsets C# tells
#      Paulinchen  2026-11-06: Covered an offer accepted by its button leaving the rows while the stack hides
#                            - Called the engine's classes by their names under UI::Engine
#                            - Released the accepted offer through UI.release_offer
#                            - Checked UI.notices_shown? and a hint that renders again as it changes
#      Paulinchen  2026-11-05: Covered the stack on the UI layer: each toast a hud of its own that C# moves and fades, the offers
#                              in a hud of the notices' layer answered by their buttons, "+N more" past five rows, a failing
#                              block logged once, and the offers' hud gone while nothing stands
#                            - Checked that a bubble shows as a bubble root that closes once the map changes
#                            - Covered toasts as boxes of their own that C# lays out in the stack, sliding in and fading,
#                              with bars in the colors of their severities, a still toast making no objects, bubbles
#                              timed by C#'s clock, the stack in battle and in the corner the player picks
#                            - Checked that a message keeps its color name as it fades
#      Paulinchen  2026-11-04: Kept a few flows of the notices box and checked each outcome on its own
#                            - Rewrote the checks as flow tests of messages, offers, the rows the box draws and refused presses
#      Paulinchen  2026-11-01: Checked the fades, the rows past the room, a resize, a look change, a rebound key, every
#                              refused press and the framework's settings notice
#                            - Checked that an accepted offer sent again shows at once
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers notices.rbx and toasts.rbx in a booted game against FakeTree: toasts handed to C#'s queue
# with their sizes, each shown as a hud of its own where C# places it, in the plain text color with
# a bar in the color of its severity, also in battle and ticked by C# while the stack hides; a
# still toast that makes no objects; offers in a hud of the notices' layer, accepted, released,
# declined and sent again by their buttons, "+N more" past five rows and a failing block logged
# once; presses that answer nothing, logged with why; bubbles timed by C#'s clock; the corner the
# player picks; and a toast stack a mod defines, with the refusals of toasts into no stack.

require "objspace"
require_relative "layer_support"

# A stand-in for the game's battle scene.
class Scene_Battle
end

# A stand-in for the game's map scene.
class Scene_Map
end

# A mod's hint that tells whether invites show in the notices' corner.
INVITE_HINT = <<-RUBY
  module Invite_Hint
    UI = Mod_Framework::UI

    class Hint < UI::Component
      def render
        hud anchor: :bottom_left, id: :invite_hint do
          text UI.notices_shown? ? "Invites show" : "Invites wait", id: :invite_hint_text
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  dll = tree_dll(tree)
  $sent = []
  dll.answer("notices.toast") { |toast| $sent << toast; toast[1] || 3000 }
  $stacks_sent = []
  dll.answer("notices.stack") do |(name, options)|
    $stacks_sent << [name, options]
    { "corner" => options["at"] ? nil : options["corner"] || "top_left", "at" => options["at"], "grows" => options["grows"] || "down" }
  end
  dll.answer("notices.drop") { |_key| true }
  dll.answer("notices.drop_group") { |group| $sent << [:group, group]; 0 }
  $clock_ms = 0
  dll.answer("notices.clock") { |_request| $clock_ms }
  boot_tree(dll) do
    ui = Mod_Framework::UI
    notices = ui::Engine::Notices
    $sounds = []
    shows = lambda { |rows, gone = []| dll.post("notices.toasts", "shown" => rows, "gone" => gone); frame; Graphics.update }
    alert_of = lambda { |root| root.children.first }
    look = lambda { notices.toasts.map { |root| [alert_of.call(root).text, alert_of.call(root).accent, root.at, root.offset, root.opacity] } }
    frame

    # Finding gold, an encounter and a party member joining go to C#'s queue with their seconds,
    # key and the size of their boxes: each as wide as its text, the long one wrapped.
    ui.icon(:encounter, 17)
    Mod_Framework.toast "Found 250 G", seconds: 3
    Mod_Framework.toast "Monsters ahead!", seconds: 4, severity: :warning, icon: :encounter, key: :encounter
    Mod_Framework.toast "Alice joined the party, bringing the Holy Sword and three Medicinal Herbs.", severity: :success
    check("the toasts handed to C# [milliseconds, key, group, stack]", $sent.map { |toast| toast[1, 3] + [toast[6]] },
          [[3000, nil, nil, nil], [4000, ":encounter", nil, nil], [nil, nil, nil, nil]])
    check("the general stack's corner told to C# before its first toast", $stacks_sent, [[nil, { "corner" => "top_left" }]])
    sizes = $sent.map { |toast| toast[4, 2] }
    check("their sizes: short ones narrower than the long one, which is at most as wide as a toast gets and higher",
          [sizes[0][0] < sizes[1][0], sizes[1][0] < sizes[2][0], sizes[2][0] <= 300, sizes[2][1] > sizes[0][1]], [true, true, true, true])

    # C# shows them: each a hud of its own at the top left, moved as far as C# placed it, in the
    # plain text color with a bar in the color of its severity.
    ids = $sent.map { |toast| toast[0] }
    shows.call([[ids[0], 0, 70, 255], [ids[1], 0, 30, 255], [ids[2], -160, 0, 96]])
    long = "Alice joined the party, bringing the Holy Sword and three Medicinal Herbs."
    check("the toasts shown [text, bar, at, offset, opacity]", look.call,
          [["Found 250 G", nil, [8, 8], [0, 70], 255], ["Monsters ahead!", :warning, [8, 8], [0, 30], 255], [long, :success, [8, 8], [-160, 0], 96]])
    check("each toast's hud as large as its toast, above every window in the notices' band",
          notices.toasts.map { |root| tree.nodes[root.node][:props].values_at("size", "z") }, sizes.map { |size| [size, 1090] })
    joined = alert_of.call(notices.toasts[2]).label
    check("the long toast wraps into lines and the warning's text keeps the plain color beside its icon",
          [tree.nodes[joined.node][:props]["most_lines"], alert_of.call(notices.toasts[1]).label.color, alert_of.call(notices.toasts[1]).icon], [4, :text, 17])

    # A still toast makes no objects in a frame; while toasts are queued, C# ticks every frame.
    shows.call([[ids[0], 0, 70, 255], [ids[1], 0, 30, 255], [ids[2], 0, 0, 255]])
    2.times { frame }
    GC.disable
    ObjectSpace.trace_object_allocations { 10.times { frame } }
    made = ObjectSpace.each_object.select { |object| ObjectSpace.allocation_sourcefile(object).to_s =~ /(notices|toasts)\.rbx\z/ }.size
    GC.enable
    check("objects made in notices.rbx and toasts.rbx over 10 frames of still toasts", made, 0)
    check("C# ticks the toasts", $ticks.last.key?("notices"), true)

    # The stack shows in battle; hidden, the toasts hide and C# still ticks them, so their time runs on.
    $scene_now = Scene_Battle.new
    frame
    check("the stack shows in battle and C# counts the toasts' time", [notices.shown?, $ticks.last.key?("notices")], [true, true])
    $scene_now = :map
    load_mod("Patch/Invite_Hint.rb", INVITE_HINT)
    hint_root = ui.show(Invite_Hint::Hint)
    frame
    hint = lambda { ui::Engine::Placement.find("#invite_hint_text").text }
    shown_before = [ui.notices_shown?, hint.call]
    $hide = true
    ui.notices_hidden_while(:test) { $hide }
    2.times { frame }
    check("while it hides, the toasts hide and C# still ticks them", [$ticks.last.key?("notices"), notices.toasts.map { |root| root.send(:hidden_now?) }],
          [true, [true, true, true]])
    hidden = [ui.notices_shown?, hint.call]
    $hide = false
    2.times { frame }
    check("UI.notices_shown? and a hint that reads it in its render, while the stack shows, hides and shows again",
          [shown_before, hidden, [ui.notices_shown?, hint.call]], [[true, "Invites show"], [false, "Invites wait"], [true, "Invites show"]])
    hint_root.hide

    # The encounter's toast goes and the gold's moves down into its gap; once the last went, C#
    # hears nothing more and no hud is left.
    shows.call([[ids[0], 0, 50, 255], [ids[2], 0, 0, 255]], [ids[1]])
    check("the encounter's toast went and the gold's moves into its gap", [notices.toasts.map { |root| alert_of.call(root).text }, notices.toasts[0].offset],
          [["Found 250 G", long], [0, 50]])
    shows.call([], [ids[0], ids[2]])
    frame
    check("with no toast left [huds, C# ticked, tops of the UI layer]", [notices.toasts, $ticks.last.key?("notices"), ui::Engine::Layer.tops.size], [[], false, 0])

    # A toast queued before the drain that tells the last toast gone, as a click's block may
    # queue one in the same frame, still has C# tick, so it shows.
    Mod_Framework.toast "Found 2 Herbs"
    herbs = $sent.last
    shows.call([[herbs[0], 0, 0, 255]])
    Mod_Framework.toast "Found a Potion"
    potion = $sent.last
    shows.call([], [herbs[0]])
    frame
    check("a toast queued as the last one went has C# tick", $ticks.last.key?("notices"), true)
    shows.call([], [potion[0]])
    ui.drop_group(:world)
    check("drop_group reaches C#'s queue", $sent.last, [:group, ":world"])

    # The player accepts a party invite, sees a duel offer, declines it and gets the invite again.
    answers = []
    $offers = [{ :key => :party, :text => "Ana invites you to a party", :accept => lambda { answers << :accepted }, :decline => lambda { answers << :declined } },
               { :key => :duel, :text => "Cid challenges you to a duel", :decline => lambda { answers << :duel_declined } }]
    notices.offers(:test) { $offers }
    2.times { frame }
    Graphics.update
    texts = lambda { notices.box ? notices.box.children.map { |row| [row.text] + row.own_parts.map { |button| button.text } } : [] }
    hotkeys = lambda { notices.box.children.map { |row| row.own_parts.map { |button| button.declared_hotkey } } }
    check("the offers in the notices' layer, docked at the top left below the parts there [z, dock, order]",
          tree.nodes[notices.box.node][:props].values_at("z", "dock", "dock_order"), [1090, "top_left", 100])
    check("the offers with their buttons", texts.call, [["Ana invites you to a party", "Accept", "Decline"], ["Cid challenges you to a duel", "Decline"]])
    check("the first offer's buttons take the Accept and Decline hotkeys", hotkeys.call, [[:accept, :decline], [false]])
    $hide = true
    tell(tree, [[notices.box.children[0].own_parts[0].node, "click"]])
    frame
    check("the accepted invite leaves the rows at once, also while the stack hides", notices.rows.map { |kind, row| [kind, row[:key]] },
          [[:offer, :duel], [:fading, nil]])
    $hide = false
    2.times { frame }
    Graphics.update
    check("accepting runs its block", answers, [:accepted])
    check("the duel's offer first now, its Decline taking the hotkey, the invite fading out",
          [texts.call.first, hotkeys.call.first, notices.box.children[1].text], [["Cid challenges you to a duel", "Decline"], [:decline], "Ana invites you to a party"])
    15.times { frame }
    Mod_Framework::UI.release_offer(:party)
    2.times { frame }
    Graphics.update
    check("UI.release_offer shows the accepted offer again", texts.call.first, ["Ana invites you to a party", "Accept", "Decline"])
    tell(tree, [[notices.box.children[0].own_parts[1].node, "click"]])
    2.times { frame }
    check("declining runs its block with the cancel sound", [answers.last, $sounds.last], [:declined, :cancel])
    $offers[0] = $offers[0].merge(:text => "Ana invites you to her party")
    2.times { frame }
    Graphics.update
    check("the same offer sent again with another text shows at once", texts.call.first.first, "Ana invites you to her party")
    $offers[0] = { :key => :party_again, :text => "Ana invites you to her party", :accept => lambda { answers << :accepted_again }, :decline => lambda {} }
    2.times { frame }
    Graphics.update
    tell(tree, [[notices.box.children[0].own_parts[0].node, "click"]])
    check("an offer replaced by another of the same text answers for the new one", answers.last, :accepted_again)

    # Six offers show five rows and "+1 more", whose tooltip names the sixth.
    15.times { frame }
    $offers = (1..6).map { |place| { :key => place, :text => "Offer #{place}", :decline => lambda {} } }
    2.times { frame }
    Graphics.update
    more = notices.box.children.last
    check("past five rows [rows, the last row, its tooltip]", [notices.box.children.size, more.text, more.tooltip], [6, "+1 more", "Offer 6"])

    # Once nothing stands the offers' hud goes; a failing block is logged once, naming the mod.
    $offers = []
    20.times { frame }
    check("with no offer the offers' hud went", [notices.box, ui::Engine::Layer.tops.size], [nil, 0])
    mod_log = Struct.new(:lines) { def log(line); lines << line; end }.new([])
    notices.offers(:broken, :log => mod_log) { raise "the quest list is gone" }
    3.times { frame }
    check("a failing block logged once into its mod's log", mod_log.lines.size, 1)
    notices.offers(:broken) { [] }

    # Accept answers nothing while the stack hides or on a toast, logged with why.
    press = lambda do
      logged_lines do
        $keys = { Mod_Framework::Hotkeys.code(:accept) => 3 }
        frame
        $keys = nil
        frame
      end
    end
    $offers = [{ :key => :trade, :text => "Bo offers a trade", :accept => lambda { answers << :traded }, :decline => lambda {} }]
    2.times { frame }
    $hide = true
    frame
    check("Accept while the stack hides answers nothing", press.call.grep(/answered nothing: the notices hide/).size, 1)
    $hide = false
    $offers = []
    2.times { frame }
    check("Accept with no offer standing answers nothing", press.call.grep(/answered nothing: no offer stands/).size, 1)
    Mod_Framework.toast "Saved to slot 3", key: :saved
    saved = $sent.last

    # A bubble over a character on the map closes after its seconds of C#'s clock, a newer one of
    # its key replaces it; outside the map it shows as a toast.
    $scene_now = Scene_Map.new
    baker = Sprite.new
    baker.x = 300
    baker.y = 200
    $game_map = Struct.new(:map_id, :events).new(3, {})
    $clock_ms = 1000
    frame
    Mod_Framework.bubble baker, "Ouch!", seconds: 0.5, key: :ouch
    ouch = ui::Engine::Tree.roots.last
    check("the bubble over the character [its root, its text, seconds]", [ouch.class.name, ouch.children.first.text, ouch.seconds],
          ["Mod_Framework::UI::Engine::Bubble", "Ouch!", 0.5])
    $clock_ms = 1400
    2.times { frame }
    check("it shows while its seconds last", ouch.open?, true)
    $clock_ms = 1500
    2.times { frame }
    check("it closes once C#'s clock counted its seconds", ouch.open?, false)
    Mod_Framework.bubble baker, "Ouch!", key: :ouch
    ouch = ui::Engine::Tree.roots.last
    Mod_Framework.bubble baker, "Ouch again!", key: :ouch
    again = ui::Engine::Tree.roots.last
    check("a newer bubble of its key replaces it", [ouch.open?, again.open?, again.children.first.text], [false, true, "Ouch again!"])
    $game_map.map_id = 4
    frame
    check("it closes once the map changes", again.open?, false)
    $scene_now = :menu
    Mod_Framework.bubble baker, "Hungry.", seconds: 2
    check("outside the map the bubble is a toast [milliseconds, lines]", [$sent.last[1], notices.instance_variable_get(:@toasts)[$sent.last[0]][:lines]],
          [2000, 1])
    $scene_now = :map

    # The player puts the stack at the bottom right, which the settings keep; a toast there lies
    # at the bottom edge, the older moving up, and slides in from the right; the offers dock there.
    notices.corner = :bottom_right
    check("the corner picked is kept and told to C#", [Mod_Framework::Settings.setting("notice_corner"), notices.corner, $stacks_sent.last],
          ["bottom_right", :bottom_right, [nil, { "corner" => "bottom_right" }]])
    shows.call([[saved[0], 12, -30, 255]])
    root = notices.toasts.first
    check("a toast at the bottom right [at, offset]", [root.at, root.offset], [[Graphics.width - 8 - saved[4], Graphics.height - 8 - saved[5]], [12, -30]])
    $offers = [{ :key => :trade, :text => "Bo offers a trade", :decline => lambda {} }]
    2.times { frame }
    check("the offers docked at the bottom right", tree.nodes[notices.box.node][:props]["dock"], "bottom_right")

    # A trap mod defines a stack of its own at the top right, whose options C# reads; its toast
    # goes there with the stack's name and its own severity, at the top right whatever corner the
    # player picked, and moves to a spot once the stack is defined anew there. A toast into a
    # stack nobody defined and a stack without a name are refused, each logged once.
    ui.toasts :my_traps, corner: :top_right, slide_from: :right, grows: :down, most_shown: 3, seconds: 2.5, newest_on_top: true
    check("the stack C# reads [name, options]", $stacks_sent.last,
          [":my_traps", { "corner" => "top_right", "slide_from" => "right", "grows" => "down", "most_shown" => 3, "seconds" => "2.5", "newest_on_top" => true }])
    Mod_Framework.toast "Spikes!", stack: :my_traps, severity: :error
    spikes = $sent.last
    check("its toast handed to C# [milliseconds, stack]", spikes.values_at(1, 6), [nil, ":my_traps"])
    shows.call([[spikes[0], 0, 0, 255]])
    trap = notices.toasts.last
    check("its toast at the top right [text, bar, at]", [alert_of.call(trap).text, alert_of.call(trap).accent, trap.at],
          ["Spikes!", :error, [Graphics.width - 8 - spikes[4], 8]])
    ui.toasts :my_traps, at: [100, 60]
    check("defined anew at a spot, its toast moves there", trap.at, [100, 60])

    # Defined to grow up from a spot, the stack places each toast by its bottom edge: a tall toast
    # above a short one, moved the short one's height and gap up as C# lays them, never covers it.
    ui.toasts :my_traps, at: [200, 300], grows: :up
    Mod_Framework.toast "Pit!", stack: :my_traps
    short = $sent.last
    Mod_Framework.toast "A pit opened under the party and swallowed two Medicinal Herbs and a Holy Sword.", stack: :my_traps
    tall = $sent.last
    shows.call([[short[0], 0, 0, 255], [tall[0], 0, -(short[5] + 4), 255]])
    edges = notices.toasts.last(2).map { |root| [root.at[1] + root.offset[1], root.at[1] + root.offset[1] + tree.nodes[root.node][:props]["size"][1]] }
    check("growing up from [200, 300]: the short toast ends at the spot, the tall one ends 4 px above it [short, tall: top, bottom]",
          [tall[5] > short[5], edges], [true, [[300 - short[5], 300], [296 - short[5] - tall[5], 296 - short[5]]]])
    refused = logged_lines do
      2.times { Mod_Framework.toast "Darts!", stack: :my_dart }
      ui.toasts 42, corner: :top_left
    end
    check("the refusals logged [a toast into no stack, once; a stack without a name; toasts handed to C#]",
          [refused.grep(/stack :my_dart were refused: no mod defined it/).size, refused.grep(/UI\.toasts was refused: a toast stack needs a name/).size, $sent.last.equal?(tall)],
          [1, 1, true])
  end
end
