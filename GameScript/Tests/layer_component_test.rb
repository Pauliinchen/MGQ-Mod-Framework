#----------------------------------------------------------------
#  layer_component_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered memo keeping each tooltip made in a loop between renders
#      Paulinchen  2026-11-07: Covered a box and a HUD written as a block of markup without a class
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Renamed a state that the markup name log now takes
#                            - Expected a wheel among the roots UI.open takes
#      Paulinchen  2026-11-04: Covered the params every part takes, handed to the top part of a component
#                            - Kept a few flows of the components a mod writes and checked each outcome on its own
#                            - Rewrote the checks as flow tests of components a mod writes
#                            - Checked each rule in one check
#                            - Covered two mods that define the same component and a component outside any module
#                            - Covered siblings that share a key
#                            - Covered a param the caller leaves out
#                            - Covered a content param that reads the caller's state
#                            - Created
#
#----------------------------------------------------------------

# Covers a component of the UI layer in a booted game against FakeTree, through the components a
# mod writes: refused declarations, the lifecycle and mistakes logged, events, children and the
# params every part takes (the Party Picker of the design's appendix A.2), content params and
# params left out, components outside a module, watches and exposed values, siblings that share a
# key, memo keeping what it made between renders, UI.show, and a box and a HUD written as a block
# without a class.

require_relative "layer_support"

PARTY_PICKER = <<-RUBY
  module Party_Picker
    UI = Mod_Framework::UI

    class MemberCard < UI::Component
      param :actor
      param :selected, false
      param :footer, content: true
      event :pick

      def render
        stack id: :card, row: true do
          button actor, color: (selected ? :primary : :default), on_click: -> { emit :pick, actor }
          children if children?
          children :footer if footer
        end
      end
    end

    class PickerWindow < UI::Component
      state :chosen

      def render
        window "Pick a member", id: :party_picker do
          %w[Ana Ilias].each do |member|
            member_card actor: member, selected: chosen == member, key: member, tooltip: "Pick " + member, disabled: chosen == member,
                        on_pick: ->(picked) { self.chosen = picked } do
              text "HP"
            end
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame
    top = lambda { ui::Engine::Layer.tops.last }

    # Declarations a mod gets wrong are refused where they are written, with what to write instead.
    refused = lambda do |code|
      begin
        eval(code, TOPLEVEL_BINDING, "Patch/Rules.rb", 1)
        nil
      rescue ui::Engine::MarkupError => e
        e.message
      end
    end
    check("a mutable default is refused", refused.call("class SharedNotes < Mod_Framework::UI::Component; state :notes, []; end"),
          "state :notes would share one Array among every component; use state(:notes) { [] }")
    check("a state that hides close is refused", refused.call("class Closer < Mod_Framework::UI::Component; state :close; end"),
          "state :close would hide the component's own close; pick another name")
    check("a class named like a built-in is refused", refused.call("module Equipment_Window; class Window < Mod_Framework::UI::Component; end; end"),
          "Equipment_Window::Window would hide the built-in `window`. Rename the class, for example to EquipmentWindow")

    # A component opens with its defaults, runs its lifecycle, and logs handlers and renders that
    # break the rules.
    load_mod("Patch/Rules.rb", <<-RUBY)
      class Rules < Mod_Framework::UI::Component
        param :actor
        state(:shown) { actor }
        state(:notes) { ["a"] }
        state :steps
        def setup; self.steps = [:setup]; end
        def mounted; self.steps = steps + [:mounted]; end
        def unmounted; $unmounted = true; end
        def render
          window "Rules" do
            button "Add", id: :add, on_click: -> { notes << "b" }
            button "Rename", id: :rename, on_click: -> { self.actor = "Bo" }
          end
        end
      end
      class Busy < Mod_Framework::UI::Component
        state :count, 0
        def render
          self.count = count + 1
          window("Busy") { }
        end
      end
    RUBY
    rules = ui.open(Rules, :actor => "Ana")
    frame
    Graphics.update
    add, rename = nodes_of(tree, "button").last(2)
    tell(tree, [[add, "click"], [rename, "click"]])
    check("a handler that changes a frozen state is logged with what to write",
          layer_lines.grep(/state :notes is frozen; write self.notes = notes \+ \[x\]/).size, 1)
    check("a handler that writes a param is logged with what to write",
          layer_lines.grep(/actor is a param; keep your own copy in a state, for example state\(:shown\) \{ actor \}/).size, 1)
    rules.close
    ui.open(Busy)
    frame
    check("the log names the mod, the file and the line of that render", layer_lines.last,
          "Rules (Rules.rb:19): Busy's render failed: Busy writes state :count inside render; write it in a handler, in setup or after a watch")

    # The Party Picker: a component's markup name places the caller's block, and emit reaches the
    # caller.
    load_mod("Patch/Party_Picker.rb", PARTY_PICKER)
    picker = ui.open(Party_Picker::PickerWindow)
    ui.open(Party_Picker::PickerWindow)
    frame
    cards = nodes_of(tree, "stack").last(2)
    tell(tree, [[tree.nodes[cards[1]][:children].first, "click"]])
    check("emit reaches the caller's on_pick", top.call.mount.component.chosen, "Ilias")
    check("a card hands the tooltip: and disabled: its caller gave it to its stack",
          [ui::Engine::Tree.component(cards[0]).tooltip, tree.nodes[cards[1]][:props]["enabled"]], ["Pick Ana", false])
    picker.close

    # A content param follows the caller's state (0d1d3ee4), and a param left out goes back to its
    # default (f83cd7ff).
    load_mod("Patch/Purse.rb", <<-RUBY)
      class Purse < Mod_Framework::UI::Component
        state :gold, 1
        state :plain, false
        def render
          window "Purse" do
            if plain
              component Party_Picker::MemberCard, actor: "Ana"
            else
              component Party_Picker::MemberCard, actor: "Ana", selected: true, footer: -> { text "Gold " + gold.to_s }
            end
          end
        end
      end
    RUBY
    purse = ui.open(Purse)
    frame
    owner = top.call.mount.component
    owner.gold = 2
    Graphics.update
    check("a content param shows the caller's new state", top.call.root.engine.children.first.children.last.text, "Gold 2")
    owner.plain = true
    Graphics.update
    card = top.call.mount.children.first.children.first.component
    check("params the caller leaves out go back to their defaults", [card.selected, card.footer], [false, nil])
    purse.close

    # Components outside a module and defined twice are logged (86e4103d); outside its module only
    # component reaches one.
    load_mod("Patch/Other.rb", <<-RUBY)
      class Outside < Mod_Framework::UI::Component
        def render
          window "Outside" do
            member_card actor: "Ana"
          end
        end
      end
    RUBY
    load_mod("Patch/Coins_A.rb", "class Coin < Mod_Framework::UI::Component\n  def render; end\nend")
    load_mod("Patch/Coins_B.rb", "class Coin < Mod_Framework::UI::Component\n  def render; end\nend")
    frame
    check("a component outside any module is logged once", layer_lines.grep(/Coin lies outside any module/).size, 1)
    check("a second mod that defines it is named", layer_lines.grep(/Coin/).last,
          "Coins_B.rb:2: Coins A and Coins B both define the component Coin, so each changes the other's; put each mod's components inside a module of its own")
    ui.open(Outside)
    frame
    line = __LINE__ + 1
    missing = (ui.open(Party_Picker::MemberCard) rescue $!.message)
    check("a missing param is told where the component is opened", missing, "member_card needs actor: (layer_component_test.rb:#{line})")

    # A watch's new answer and a serial read in render render a component again, and another mod
    # reads its exposed value.
    load_mod("Patch/Watcher.rb", <<-RUBY)
      class Watcher < Mod_Framework::UI::Component
        param :actor, "Ana"
        expose(:greeting) { "Hi " + actor }
        watch(every: 2) { $signature }
        def render
          $renders = ($renders || 0) + 1
          window "Watcher" do
            text "Gold " + Mod_Framework::UI::Game.gold.to_s
          end
        end
      end
    RUBY
    $game_party = Struct.new(:gold).new(100)
    $signature = 1
    watcher = ui.open(Watcher)
    3.times { Graphics.update }
    $signature = 2
    2.times { Graphics.update }
    check("only a watch's new answer renders it again", $renders, 2)
    $game_party.gold = 150
    ui::Engine::Serials.bump(:gold)
    Graphics.update
    check("a serial read in render renders it again", $renders, 3)
    check("another mod reads an exposed value", ui::Engine::Layer.exposed(top.call.mount.component, :greeting), "Hi Ana")
    watcher.close

    # memo keeps the tooltip of each gem, made in a loop, the same object while the gems stay, and
    # makes it anew only for a gem that came in.
    load_mod("Patch/Gem_Tips.rb", <<-RUBY)
      module Gem_Tips
        class GemRow < Mod_Framework::UI::Component
          state(:gems) { ["Ruby", "Onyx"] }
          state :tick, 0

          def render
            $tips = gems.map { |gem| memo(gem) { -> { text gem } } }
            window "Gems" do
              text "Tick \#{tick}"
            end
          end
        end
      end
    RUBY
    gem_row = ui.open(Gem_Tips::GemRow)
    frame
    made = $tips
    top.call.mount.component.tick = 1
    frame
    kept = $tips
    top.call.mount.component.gems = ["Ruby", "Pearl"]
    frame
    check("memo keeps each gem's tooltip while the render runs again, and makes one anew only for a new gem",
          [kept.zip(made).map { |now, before| now.equal?(before) }, $tips[0].equal?(made[0]), $tips[1].equal?(made[1])], [[true, true], true, false])
    gem_row.close

    # Siblings that share a key keep their components while their parent renders and leave with it
    # (a2e43b1e), and a loop without key: is logged.
    load_mod("Patch/Satchel.rb", <<-RUBY)
      class Satchel < Mod_Framework::UI::Component
        state :renders, 0
        def render
          window "Satchel" do
            %w[Potion Potion Herb].each { |name| component Party_Picker::MemberCard, actor: name, key: name }
            3.times { text renders.to_s }
          end
        end
      end
    RUBY
    mounted = ui::Engine::Layer.instance_variable_get(:@mounted)
    before = mounted.size
    satchel = ui.open(Satchel)
    frame
    opened = mounted.size
    owner = top.call.mount.component
    5.times { |time| owner.renders = time + 1; Graphics.update }
    check("siblings that share a key keep their components while the parent renders", mounted.size, opened)
    satchel.close
    check("they leave with their parent", mounted.size, before)
    check("the shared key is logged once", layer_lines.grep(/Satchel gives several member_card parts the key "Potion"/).size, 1)

    # UI.show shows a hud without holding the game's buttons, and UI.open refuses one.
    load_mod("Patch/Hud.rb", <<-RUBY)
      class GoldHud < Mod_Framework::UI::Component
        def render
          hud anchor: :top_right, id: :gold_hud do
            text -> { "Gold " + $game_party.gold.to_s }
          end
        end
      end
    RUBY
    shown = ui.show(GoldHud)
    Graphics.update
    check("the hud does not hold the game's buttons", ui::Engine::Capture.on?, false)
    $game_party.gold = 175
    2.times { Graphics.update }
    ui.open(GoldHud)
    frame
    check("the refusal says which call fits", layer_lines.last[/UI.open takes .*/],
          "UI.open takes a component whose render describes a window, a dialog or a wheel at its top; GoldHud described hud. hud goes to UI.show.")
    shown.hide
    Graphics.update

    # A sign and a mark written as blocks without a class: the mod's own method works inside, each
    # place opens a root of its own, and on_click: :close closes the sign.
    load_mod("Patch/Camp_Sign.rb", <<-RUBY)
      module Camp_Sign
        UI = Mod_Framework::UI

        def self.rest_line
          "The party rests until morning."
        end

        def self.open_sign
          UI.open do
            window "Camp" do
              text rest_line
              button "OK", on_click: :close
            end
          end
        end

        def self.show_mark
          UI.show do
            hud anchor: :top_left do
              text "Camp"
            end
          end
        end
      end
    RUBY
    sign = Camp_Sign.open_sign
    frame
    mark = Camp_Sign.show_mark
    Graphics.update
    shown = nodes_of(tree, "label").map { |node| ui::Engine::Tree.component(node).text }
    check("a block's window and hud show, the mod's method read inside",
          [sign.open?, mark.shown?, shown.include?("The party rests until morning."), shown.include?("Camp"), sign.id == mark.id], [true, true, true, true, false])
    tell(tree, [[nodes_of(tree, "button").last, "click"]])
    check("on_click: :close closes the block's window", sign.open?, false)
    mark.hide
    Graphics.update
  end
end
