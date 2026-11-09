#----------------------------------------------------------------
#  game_serials.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Found a character by its id and its first persona's id instead of going through every character
#                              made on each change
#                            - Found a character among the characters made, a persona changed too, and never looked one up
#                            - Called the engine's classes by their names under UI::Engine
#                            - Read the characters made without making one, so a companion's first join no longer loops
#                            - Added the notices' serial, bumped once the notice stack starts or stops showing
#      Paulinchen  2026-11-05: Told a character's base level, since the game keeps three levels
#      Paulinchen  2026-11-04: Added the windows' serial, which a game window a component draws in place of bumps as it
#                              draws its contents anew
#                            - Added the theme's serial, bumped once the player picks another look or a mod adds one
#                            - Added the keys' serial, bumped once the keys change that hints and key names name
#                            - Read the game's variables, switches and map through UI::Game
#                            - Noted the serials a render reads, and read the party, the gold, the items, the levels, the states and the gear through UI::Game
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Counters of the game's change points, each bumped by a hook on the game's method that
      # changes it, so a screen tells by one number whether what it shows changed: the party, a
      # character's gear, HP, MP and TP, states and levels, the gold, the items, the variables, the
      # switches and the map. A character's own counter, and a variable's or a switch's, goes up
      # with the shared one.
      module Serials
        # The serials and what bumps each, by class and method. A method the game lacks is left out.
        #   :party   Game_Party#add_actor, remove_actor, swap_order
        #   :gear    Game_Actor#change_equip, force_change_equip, discard_equip, optimize_equipments,
        #            clear_equipments, release_unequippable_items (only when an item left), and a gem
        #            set into an item (change_stone, no character)
        #   :vitals  Game_BattlerBase#hp=, mp=, tp=
        #   :states  Game_Battler#add_state, remove_state, clear_states (only when the states changed)
        #   :level   Game_Actor#change_exp, level_up, level_down, change_class, Paradox's job and race
        #            levels among them
        #   :gold    Game_Party#gain_gold
        #   :items   Game_Party#gain_item
        #   :variable  Game_Variables#[]= (only when the value changed), counted per id
        #   :switch    Game_Switches#[]= (only when the value changed), counted per id
        #   :map     Game_Map#setup
        #   :keys    the framework itself: F1 binds other keys, a hotkey gets another key, or a text field
        #            of any mod starts or stops typing, which changes the cancel keys a hint names
        #   :theme   the framework itself: the player picks another look, or a mod adds a preset or a
        #            color name
        #   :windows a game window whose drawing UI.replace_window replaced draws its contents anew,
        #            counted per window
        #   :notices the framework itself: the notice stack starts or stops showing (UI.notices_shown?)
        # A new game and a loaded save bump :variable, :switch and :map for every id.
        NAMES = [:party, :gear, :vitals, :states, :level, :gold, :items, :variable, :switch, :map, :keys, :theme, :windows, :notices]

        # The methods that bump a serial on the object they run on, by serial and class name.
        AFTER = { :party => { "Game_Party" => [:add_actor, :remove_actor, :swap_order] },
                  :gear => { "Game_Actor" => [:change_equip, :force_change_equip, :discard_equip, :optimize_equipments, :clear_equipments] },
                  :vitals => { "Game_BattlerBase" => [:hp=, :mp=, :tp=] },
                  :level => { "Game_Actor" => [:change_exp, :level_up, :level_down, :change_class] },
                  :gold => { "Game_Party" => [:gain_gold] },
                  :items => { "Game_Party" => [:gain_item] },
                  :map => { "Game_Map" => [:setup] } }

        # The methods that bump a serial only when what a signature reads changed.
        CHANGED = { :states => { "Game_Battler" => [:add_state, :remove_state, :clear_states] },
                    :gear => { "Game_Actor" => [:release_unequippable_items] } }

        # The methods that bump a serial of an id only when the value at that id changed.
        BY_ID = { :variable => ["Game_Variables", :[]=], :switch => ["Game_Switches", :[]=] }

        # The serials a new game or a loaded save bumps for every id, by DataManager's method.
        REPLACED = { :create_game_objects => [:variable, :switch, :map], :extract_save_contents => [:variable, :switch, :map] }

        # The game's items that take a gem; a gem set bumps :gear for every character.
        GEM_HOLDERS = ["RPG::Uniq_Item"]

        # Who hooks the game, for the hooks' log.
        TAG = "Mod Framework serials"

        # Each serial's count.
        @counts = Hash[NAMES.map { |name| [name, 0] }]

        # Each character's own count of a serial, or a variable's or a switch's, by serial and
        # character or id.
        @own = Hash[NAMES.map { |name| [name, {}] }]

        # What every own count of a serial is raised by, since a new game or a loaded save changed
        # every id at once.
        @raised = Hash[NAMES.map { |name| [name, 0] }]

        # What a change runs after a serial was bumped, each [block], such as forgetting kept values.
        @followers = []

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "serials"

        # Tells a serial's count, or a character's own, or a variable's or a switch's.
        #
        # @param name [Symbol] The serial, see NAMES.
        # @param actor [Game_Actor, Integer, nil] The character or the id, nil for the count of
        #   everyone.
        # @return [Integer] The count.
        def self.serial(name, actor = nil)
          actor ? @own[name][actor].to_i + @raised[name] : @counts[name].to_i
        end

        # Notes each serial read through UI::Game while a block runs, such as a component's render,
        # so the component renders again once one of them changes.
        #
        # @param reads [Hash] Where each serial read goes, as [name, actor] => its count then.
        # @yield The block.
        def self.record(reads)
          was = @reads
          @reads = reads
          yield
        ensure
          @reads = was
        end

        # Notes a serial read while record runs.
        #
        # @param name [Symbol] The serial.
        # @param actor [Game_Actor, nil] The character, nil for the count of everyone.
        def self.read(name, actor = nil)
          @reads[[name, actor]] = serial(name, actor) if @reads
          nil
        end

        # Bumps a serial and the own count of a variable's or a switch's id.
        #
        # @param name [Symbol] The serial.
        # @param id [Integer] The id.
        def self.bump_id(name, id)
          @counts[name] += 1
          @own[name][id] = @own[name][id].to_i + 1
          @followers.each { |block| block.call(name, nil, false) }
        end

        # Bumps a serial and every own count of it, as a new game or a loaded save replaced what it
        # counts.
        #
        # @param name [Symbol] The serial.
        def self.bump_all(name)
          @counts[name] += 1
          @raised[name] += 1
          @followers.each { |block| block.call(name, nil, true) }
        end

        # Bumps a serial, and a character's own count of it.
        #
        # @param name [Symbol] The serial.
        # @param battler [Object, nil] Who changed: a character counts on its own, anyone else only in
        #   the shared count.
        def self.bump(name, battler = nil)
          @counts[name] += 1
          actor = character?(battler) ? battler : nil
          own = @own[name]
          own[actor] = own[actor].to_i + 1 if actor
          @followers.each { |block| block.call(name, actor, battler.nil?) }
        end

        # Runs a block after every bump.
        #
        # @yieldparam name [Symbol] The serial.
        # @yieldparam actor [Game_Actor, nil] The character, nil for anyone else.
        # @yieldparam everyone [Boolean] Whether the change may touch every character, such as a gem
        #   set into an item.
        def self.follow(&block)
          @followers << block
        end

        # Forgets the characters' own counts, as a loaded save brings characters of its own.
        def self.forget_characters
          @own.each { |name, own| own.clear unless BY_ID.key?(name) }
        end

        # Hooks the game's change points, once the game runs.
        def self.install
          AFTER.each do |name, classes|
            each_method(classes) { |owner, method| Hooks.after(owner, method, TAG) { |*_args| Mod_Framework::UI::Engine::Serials.bump(name, self) } }
          end
          each_method(CHANGED[:states]) { |owner, method| bump_on_change(owner, method, :states) { |battler| Serials.states_of(battler) } }
          each_method(CHANGED[:gear]) { |owner, method| bump_on_change(owner, method, :gear) { |actor| Serials.gear_of(actor) } }
          BY_ID.each do |name, (path, method)|
            owner = constant(path)
            bump_id_on_change(owner, method, name) if owner && owner.method_defined?(method)
          end
          REPLACED.each do |method, names|
            next unless defined?(::DataManager) && ::DataManager.respond_to?(method)

            Hooks.after(::DataManager.singleton_class, method, TAG) { |*_args| names.each { |name| Mod_Framework::UI::Engine::Serials.bump_all(name) } }
          end
          GEM_HOLDERS.each do |path|
            owner = constant(path)
            Hooks.after(owner, :change_stone, TAG) { |*_args| Mod_Framework::UI::Engine::Serials.bump(:gear) } if owner && owner.method_defined?(:change_stone)
          end
        end

        # Tells a battler's states as a signature.
        #
        # @param battler [Game_Battler] The battler.
        # @return [Integer] How many states it has.
        def self.states_of(battler)
          states = battler.instance_variable_get(:@states)
          states ? states.size : 0
        end

        # Tells a character's equipment as a signature.
        #
        # @param actor [Game_Actor] The character.
        # @return [Array] The item in each slot.
        def self.gear_of(actor)
          equips = actor.instance_variable_get(:@equips)
          equips ? equips.map { |slot| slot.respond_to?(:object) ? slot.object : slot } : []
        end

        # Tells whether a battler is one of the game's characters, which keep counts of their own; a
        # copy of one, as Optimize and the game's equip screen make to try gear on, counts only in
        # the shared count.
        #
        # Counts kept for copies kept every copy alive, so the game ran out of memory on the map.
        #
        # @param battler [Object, nil] The battler.
        # @return [Boolean] Whether it is.
        def self.character?(battler)
          return false unless defined?(::Game_Actor) && battler.is_a?(::Game_Actor)

          return true if $game_actors.nil?

          # Reading $game_actors[id] makes a character not made yet, which the game does while it sets that
          # character up, so a bump during its setup made it again without end.
          made = $game_actors.instance_variable_get(:@data)
          return $game_actors[battler.id].equal?(battler) unless made

          first = first_persona_id(battler)
          made[battler.id].equal?(battler) || (!first.nil? && made[first].equal?(battler))
        end

        # Tells the id Paradox keeps a character under once its persona changed: the first persona's,
        # which the persona's data names, while the character's id tells the persona's.
        #
        # @param battler [Game_Actor] The battler.
        # @return [Integer, nil] The id, nil where the game names none.
        def self.first_persona_id(battler)
          data = $data_actors ? $data_actors[battler.id] : nil
          data.respond_to?(:original_persona_id) ? data.original_persona_id : nil
        end
        private_class_method :first_persona_id

        # Wraps a method so it bumps a serial when what a signature reads changed across the call.
        #
        # @param owner [Class] The class.
        # @param method [Symbol] The method.
        # @param name [Symbol] The serial.
        # @yieldparam object [Object] The object the method runs on.
        # @yieldreturn [Object] The signature.
        def self.bump_on_change(owner, method, name, &signature)
          Hooks.around(owner, method, TAG) do |object, _args, original|
            before = signature.call(object)
            result = original.call
            Mod_Framework::UI::Engine::Serials.bump(name, object) unless signature.call(object) == before
            result
          end
        end
        private_class_method :bump_on_change

        # Wraps a method that writes the value at an id so it bumps that id's serial when the value
        # changed.
        #
        # @param owner [Class] The class, such as Game_Variables.
        # @param method [Symbol] The method, :[]=.
        # @param name [Symbol] The serial.
        def self.bump_id_on_change(owner, method, name)
          Hooks.around(owner, method, TAG) do |object, args, original|
            id = args[0]
            before = object[id]
            result = original.call
            Mod_Framework::UI::Engine::Serials.bump_id(name, id) unless object[id] == before
            result
          end
        end
        private_class_method :bump_id_on_change

        # Runs a block for each method of each class the game defines.
        #
        # @param classes [Hash{String => Array<Symbol>}] The methods by class name.
        # @yieldparam owner [Class] The class.
        # @yieldparam method [Symbol] The method.
        def self.each_method(classes)
          classes.each do |path, methods|
            owner = constant(path)
            next unless owner

            methods.each { |method| yield(owner, method) if owner.method_defined?(method) || owner.private_method_defined?(method) }
          end
        end
        private_class_method :each_method

        # Finds a class by its name, nil where the game has none.
        #
        # @param path [String] The name, such as "RPG::Uniq_Item".
        # @return [Module, nil] The class.
        def self.constant(path)
          path.split("::").inject(Object) { |scope, name| scope.const_defined?(name) ? scope.const_get(name) : (return nil) }
        end
        private_class_method :constant
      end
    end

    module Game
      # Each character's max HP and MP as last read, [mhp, mmp] by character, renewed after its
      # gear, states or level changed or the game refreshed it, since the game works them out from
      # all traits on every read.
      @kept = {}

      # The game's characters the kept values belong to, so a loaded save forgets them.
      @kept_of = nil

      # Tells the party's members; a render that reads them renders again when the party changes.
      #
      # @return [Array<Game_Actor>] The members.
      def self.members
        Engine::Serials.read(:party)
        $game_party.members
      end

      # Tells the party's leader; a render that reads it renders again when the party changes.
      #
      # @return [Game_Actor, nil] The leader.
      def self.leader
        Engine::Serials.read(:party)
        $game_party.leader
      end

      # Tells the party's gold; a render that reads it renders again when the gold changes.
      #
      # @return [Integer] The gold.
      def self.gold
        Engine::Serials.read(:gold)
        $game_party.gold
      end

      # Tells how many of an item the party holds; a render that reads it renders again when the
      # items change.
      #
      # @param item [RPG::BaseItem] The item.
      # @return [Integer] How many.
      def self.count(item)
        Engine::Serials.read(:items)
        $game_party.item_number(item)
      end

      # Tells a character's level as the game's menus show it, its base level beside the levels of
      # its job and race; a render that reads it renders again when the level changes.
      #
      # @param actor [Game_Actor] The character.
      # @return [Integer] The level.
      def self.level(actor)
        Engine::Serials.read(:level, actor)
        actor.respond_to?(:base_level) ? actor.base_level : actor.level
      end

      # Tells a battler's states; a render that reads them renders again when they change.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Array<RPG::State>] The states.
      def self.states(battler)
        Engine::Serials.read(:states, actor_of(battler))
        battler.states
      end

      # Tells a character's gear; a render that reads it renders again when it changes.
      #
      # @param actor [Game_Actor] The character.
      # @return [Array<RPG::EquipItem, nil>] The gear, nil for an empty slot.
      def self.equips(actor)
        Engine::Serials.read(:gear, actor)
        actor.equips
      end

      # Tells a game variable; a render that reads it renders again when it changes.
      #
      # @param id [Integer] The variable's id.
      # @return [Object] Its value.
      def self.variable(id)
        Engine::Serials.read(:variable, id)
        $game_variables[id]
      end

      # Tells a game switch; a render that reads it renders again when it changes.
      #
      # @param id [Integer] The switch's id.
      # @return [Boolean] Whether it is on.
      def self.switch(id)
        Engine::Serials.read(:switch, id)
        $game_switches[id]
      end

      # Tells the id of the map the player is on; a render that reads it renders again when the
      # map changes.
      #
      # @return [Integer] The map's id.
      def self.map_id
        Engine::Serials.read(:map)
        $game_map.map_id
      end

      # Tells the name of the map the player is on, as the game shows it; a render that reads it
      # renders again when the map changes.
      #
      # @return [String] The map's name.
      def self.map_name
        Engine::Serials.read(:map)
        $game_map.display_name
      end

      # Tells the character a serial of a battler counts under.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Game_Actor, nil] The battler when it is one of the game's characters, nil for
      #   anyone else.
      def self.actor_of(battler)
        Engine::Serials.character?(battler) ? battler : nil
      end
      private_class_method :actor_of

      # Tells a battler's HP as a share of its max HP.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Float] From 0.0 to 1.0.
      def self.hp_rate(battler)
        Engine::Serials.read(:vitals, actor_of(battler))
        most = mhp(battler)
        most > 0 ? battler.hp.to_f / most : 0.0
      end

      # Tells a battler's MP as a share of its max MP.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Float] From 0.0 to 1.0.
      def self.mp_rate(battler)
        Engine::Serials.read(:vitals, actor_of(battler))
        most = mmp(battler)
        most > 0 ? battler.mp.to_f / most : 0.0
      end

      # Tells a battler's TP as a share of its max TP.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Float] From 0.0 to 1.0.
      def self.tp_rate(battler)
        Engine::Serials.read(:vitals, actor_of(battler))
        battler.tp_rate
      end

      # Tells a battler's max HP: kept for a character, read for anyone else.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Integer] The max HP.
      def self.mhp(battler)
        kept(battler)[0]
      end

      # Tells a battler's max MP: kept for a character, read for anyone else.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Integer] The max MP.
      def self.mmp(battler)
        kept(battler)[1]
      end

      # Tells a serial's count, see Serials.
      #
      # @param name [Symbol] The serial.
      # @param actor [Game_Actor, nil] The character, nil for the count of everyone.
      # @return [Integer] The count.
      def self.serial(name, actor = nil)
        Engine::Serials.serial(name, actor)
      end

      # Forgets a character's kept max values, or everyone's.
      #
      # @param actor [Game_Actor, nil] The character, nil for everyone.
      def self.renew(actor = nil)
        actor ? @kept.delete(actor) : @kept.clear
        nil
      end

      # Tells a battler's max HP and MP, keeping a character's until they are renewed.
      #
      # @param battler [Game_Battler] The battler.
      # @return [Array<Integer>] The max HP and MP.
      def self.kept(battler)
        return [battler.mhp, battler.mmp] unless Engine::Serials.character?(battler)

        unless $game_actors.equal?(@kept_of)
          @kept.clear
          Engine::Serials.forget_characters
          @kept_of = $game_actors
        end
        @kept[battler] ||= [battler.mhp, battler.mmp]
      end
      private_class_method :kept

      # The serials whose change may move a character's max HP and MP.
      RENEWED_BY = [:gear, :states, :level]

      # Forgets the kept max values once a change may move them.
      Engine::Serials.follow do |name, actor, everyone|
        Mod_Framework::UI::Game.renew(actor) if RENEWED_BY.include?(name) && (actor || everyone)
      end
    end

    # Once the game runs, its change points bump the serials and a refresh renews a character's
    # kept max values.
    Run.on_start("serials") do
      Mod_Framework::UI::Engine::Serials.install
      if defined?(::Game_BattlerBase) && ::Game_BattlerBase.method_defined?(:refresh)
        Hooks.after(::Game_BattlerBase, :refresh, Engine::Serials::TAG) { Mod_Framework::UI::Game.renew(self) if self.is_a?(::Game_Actor) }
      end
    end
  end
end
