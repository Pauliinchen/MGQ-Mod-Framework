#----------------------------------------------------------------
#  game_serials_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-10: Checked that the equip rows ask the game once per item until the character changes
#      Paulinchen  2026-11-06: Named a persona's first id in its data, as Paradox does
#                            - Checked that a character whose persona changed keeps its own count
#                            - Checked that a character not made yet is not made by its own bump
#      Paulinchen  2026-11-05: Checked that a copy of a character is held nowhere
#      Paulinchen  2026-11-04: Kept a few flows of the serials with a check per step that matters
#                            - Rewrote the checks as flow tests of the serials a game session bumps
#                            - Checked each rule in one check
#                            - Covered the variables, the switches and the map
#                            - Created
#
#----------------------------------------------------------------

# Covers game_serials.rbx in a booted game with stand-ins for the game's battlers and party, through
# a session: a character takes damage, changes gear and levels with its max HP kept between them;
# the party gains gold and items and an enemy is hit; the story sets variables and switches, the
# party changes maps and a save is loaded.

require_relative "tree_support"

# Defines the game's battlers and party far enough for the serials: a max HP the test counts the
# reads of, and the change points the serials hook.
DEFINE_BATTLERS = lambda do
  Object.class_eval <<-RUBY
    class Game_BattlerBase
      attr_reader :hp, :mp, :tp
      def initialize; @hp = 100; @mp = 30; @tp = 0; @states = []; @bonus = 0; end
      def mhp; $max_reads += 1; 200 + @bonus; end
      def mmp; 60; end
      def hp=(hp); @hp = hp; end
      def mp=(mp); @mp = mp; end
      def tp=(tp); @tp = tp; end
      def tp_rate; @tp / 100.0; end
      def refresh; end
      def raise_quietly(bonus); @bonus = bonus; end
    end
    class Game_Battler < Game_BattlerBase
      def add_state(id); @states << id unless @states.include?(id); refresh; end
      def remove_state(id); @states.delete(id); end
      def clear_states; @states = []; end
    end
    class Game_Actor < Game_Battler
      attr_reader :id
      def initialize(id); super(); @id = id; @equips = [nil, nil]; end
      def change_equip(slot, bonus); @equips[slot] = bonus; @bonus = bonus if bonus.is_a?(Integer); end
      def release_unequippable_items(_gain = true); @equips[1] = nil if @equips[1] == :cursed; end
      def change_exp(_exp, _show, _kind = nil); @bonus += 10; end
    end
    class Game_Enemy < Game_Battler
    end
    class Game_Actors
      def initialize(*actors); @data = {}; actors.each { |actor| @data[actor.id] = actor }; end
      def [](id); @data[id]; end
    end
    module RPG
      class Uniq_Item
        def change_stone(_slot, _gem); end
      end
    end
    class Game_Party
      def add_actor(_id); end
      def gain_gold(_amount); end
      def gain_item(_item, _amount, _equip = false); end
    end
    class Game_Variables
      def initialize; @data = []; end
      def [](id); @data[id] || 0; end
      def []=(id, value); @data[id] = value; end
    end
    class Game_Switches
      def initialize; @data = []; end
      def [](id); @data[id] || false; end
      def []=(id, value); @data[id] = value; end
    end
    class Game_Map
      attr_reader :map_id, :display_name
      def setup(map_id); @map_id = map_id; @display_name = "Map " + map_id.to_s; end
    end
    module DataManager
      def self.extract_save_contents(contents); $game_variables = contents[:variables]; end
    end
  RUBY
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => DEFINE_BATTLERS) do
    game = Mod_Framework::UI::Game
    $max_reads = 0
    ana = Game_Actor.new(1)
    bea = Game_Actor.new(2)
    $game_actors = Game_Actors.new(ana, bea)

    # A character takes damage, changes gear and is refreshed: the max HP is read once and kept.
    check("the HP and MP rates read the max once and keep it", [*Array.new(100) { game.hp_rate(ana) }.uniq, game.mp_rate(ana), $max_reads], [0.5, 0.5, 1])
    vitals = game.serial(:vitals)
    ana.hp = 150
    check("a change of HP bumps :vitals and the character's own count, not another's, and the rate follows without reading the max",
          [game.serial(:vitals) - vitals, game.serial(:vitals, ana), game.serial(:vitals, bea), game.hp_rate(ana), $max_reads], [1, 1, 0, 0.75, 1])
    ana.change_equip(0, 100)
    gear_max = game.mhp(ana)
    ana.raise_quietly(0)
    stale = game.mhp(ana)
    ana.refresh
    check("gear bumps :gear and renews the max, and a max changed past the hooks shows after a refresh",
          [game.serial(:gear, ana), gear_max, stale, game.mhp(ana)], [1, 300, 300, 200])

    # Optimize tries gear on copies of the character; counts kept for them held every copy.
    copy = Marshal.load(Marshal.dump(ana))
    gear = game.serial(:gear)
    copy.change_equip(0, 50)
    game.mhp(copy)
    own = Mod_Framework::UI::Engine::Serials.instance_variable_get(:@own)[:gear]
    kept = game.instance_variable_get(:@kept)
    check("a copy of a character bumps :gear in the shared count only and is held nowhere [shared, own count held, max held, the character's own]",
          [game.serial(:gear) - gear, own.key?(copy), kept.key?(copy), game.serial(:gear, ana)], [1, false, false, 1])

    # States, gear let go of, a level and a gem bump their serials only when something changed.
    ana.add_state(4)
    ana.add_state(4)
    ana.remove_state(9)
    ana.release_unequippable_items
    quiet = game.serial(:gear, ana)
    ana.change_equip(1, :cursed)
    ana.release_unequippable_items
    check("a state and released gear bump only when they changed", [game.serial(:states, ana), quiet, game.serial(:gear, ana)], [1, 1, 3])
    before = game.mhp(ana)
    ana.change_exp(500, false, :job)
    check("a job level bumps :level and renews the max", [game.serial(:level, ana), game.mhp(ana) - before], [1, 10])
    game.mhp(bea)
    reads = $max_reads
    gear = game.serial(:gear)
    RPG::Uniq_Item.new.change_stone(0, :ruby)
    game.mhp(ana)
    game.mhp(bea)
    check("a gem set bumps :gear and renews every kept max", [game.serial(:gear) - gear, $max_reads - reads], [1, 2])

    # The equip list asks the game about every item of a late-game bag, which took longer than a frame on each cursor move.
    asked = []
    def ana.equips; @equips; end
    ana.define_singleton_method(:equippable?) { |item| asked << item; true }
    def ana.equippable_slot?(_slot, _item); true; end
    $game_party = Object.new
    def $game_party.equip_items; [:sword, :shield]; end
    2.times { game.equip_rows(ana, 0) }
    once = asked.size
    ana.change_equip(0, 120)
    game.equip_rows(ana, 0)
    check("the equip rows ask the game once per item of the bag, and again once the character changed gear [asked, asked after]", [once, asked.size], [2, 4])

    # The party gains a member, gold and an item; an enemy takes a hit.
    party = Game_Party.new
    party.add_actor(2)
    party.gain_gold(10)
    party.gain_item(:potion, 1)
    check("the party, the gold and the items bump their serials", [game.serial(:party), game.serial(:gold), game.serial(:items)], [1, 1, 1])
    enemy = Game_Enemy.new
    reads = $max_reads
    2.times { game.hp_rate(enemy) }
    enemy.hp = 20
    check("an enemy reads its max HP each time and counts only in the shared serial", [$max_reads - reads, game.serial(:vitals, enemy)], [2, 0])

    # The story sets variables and switches, the party walks to another map, and a save is loaded.
    $game_variables = Game_Variables.new
    $game_switches = Game_Switches.new
    $game_map = Game_Map.new
    reads = {}
    Mod_Framework::UI::Engine::Serials.record(reads) { [game.variable(5), game.switch(3)] }
    $game_variables[5] = 7
    $game_variables[6] = 1
    $game_variables[5] = 7
    $game_switches[3] = true
    check("a read of a variable or a switch is recorded, and each bumps its own count only when its value changed",
          [*reads.keys.flatten, game.serial(:variable, 5), game.serial(:variable, 6), game.serial(:switch, 3), game.variable(5), game.switch(3)],
          [:variable, 5, :switch, 3, 1, 1, 1, 7, true])
    $game_map.setup(12)
    check("a map change bumps :map", [game.serial(:map), game.map_id, game.map_name], [1, 12, "Map 12"])
    saved = Game_Variables.new
    saved[5] = 7
    counts = [game.serial(:variable, 5), game.serial(:variable, 9), game.serial(:map)]
    DataManager.extract_save_contents(:variables => saved)
    bumped = [game.serial(:variable, 5) - counts[0], game.serial(:variable, 9) - counts[1], game.serial(:map) - counts[2]]
    reads = $max_reads
    $game_actors = Game_Actors.new(ana, bea)
    game.hp_rate(ana)
    check("a loaded save bumps every variable and the map, renews every kept max and forgets the characters' own counts",
          [*bumped, $max_reads - reads, game.serial(:gear, ana)], [1, 1, 1, 1, 0])

    # The game's Game_Actors#[] makes a character not made yet, and a companion's first join bumps it while the game
    # sets it up; a lookup there made it again without end.
    making = Game_Actors.new(ana)
    def making.[](id); @made = (@made || 0) + 1; @data[id] ||= Game_Actor.new(id); end
    $game_actors = making
    joining = Game_Actor.new(3)
    joining.hp = 100
    check("a character not made yet is not made again by its own bump [made by a lookup, its own count]",
          [making.instance_variable_get(:@made).to_i, game.serial(:vitals, joining)], [0, 0])

    # Paradox keeps a character whose persona changed under its first id, which the persona's data
    # names, while its id tells the persona's.
    persona = Game_Actor.new(4)
    $game_actors = Game_Actors.new(ana, persona)
    $data_actors = { 40 => Struct.new(:original_persona_id).new(4) }
    persona.instance_variable_set(:@id, 40)
    persona.hp = 90
    check("a character whose persona changed keeps its own count", game.serial(:vitals, persona), 1)
  end
end
