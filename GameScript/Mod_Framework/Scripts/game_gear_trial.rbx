#----------------------------------------------------------------
#  game_gear_trial.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Tells a character's parameters with each of many items in one slot, as the game's equip
      # screen previews one: on one copy of the character that wears each item in turn, the bag
      # untouched.
      #
      # The game's refresh after an equip change works out every feature of the character several
      # times; a try skips it where it would leave the copy as it is, else it takes a copy of its
      # own through the game's force_change_equip.
      class GearTrial
        # The answers of the game's cache of features a try may share with the first try, each
        # about the feature code its first argument names; true where also about the data id its
        # second argument names.
        SHARED_ANSWERS = { :features => false, :features_set => false, :features_with_id => true, :features_sum => true,
                           :features_pi => true, :features_max => true }

        # The feature codes Paradox's abilities read, by the module that names each: the skills
        # features add, which the abilities learned include, and the ability points they add.
        ABILITY_CODES = [[:Game_BattlerBase, :FEATURE_SKILL_ADD], [:Fts, :FEATURE_MAX_AP_BONUS], [:Fts, :FEATURE_MAX_AP_RATE]]

        # Keeps the features a copy worked out for the item it wears until it wears another.
        module KeptFeatures
          # The trial the copy belongs to.
          attr_writer :__mf_trial

          # Tells the objects whose features the copy has, worked out once per item worn.
          #
          # @return [Object] What the game's feature_objects answers, see GearTrial#shared.
          def feature_objects
            @__mf_trial_features ||= @__mf_trial.shared(super)
          end

          # Forgets the features worked out, as the copy wears another item.
          def forget_features
            @__mf_trial_features = nil
          end

          # Tells the feature objects of the abilities the copy has equipped, worked out once, as
          # a try changes no ability.
          #
          # @return [Array] What Paradox's ability_feature_objects answers.
          def ability_feature_objects
            @__mf_abilities ||= super
          end

          # Tells Paradox's boost of a parameter by the party's members, shared between tries
          # where it can be, see GearTrial#shared_boost.
          #
          # @param param_id [Integer] The parameter.
          # @return [Float] The boost.
          def booster_actor_exist_param(param_id)
            @__mf_trial.shared_boost(param_id) { super(param_id) }
          end
        end

        # The features of the copy with the slot as it first worked them out, which every later try
        # shares where its own objects add nothing to a feature asked: Paradox's feature objects,
        # whose every answer joins the answers of its objects in their order.
        class FirstFeatures
          # Takes the feature objects of the first try.
          #
          # @param objects [Hima::FeatureObjects] The objects.
          def initialize(objects)
            @objects = objects
            @list = objects.instance_variable_get(:@feature_objects)
            @filter = objects.instance_variable_get(:@filter)
            @features = {}
            @with_id = {}
          end

          # Tells the objects a try has besides these, in their order, where it has all of these in
          # theirs and filters alike.
          #
          # @param objects [Hima::FeatureObjects] The try's objects.
          # @return [Array, nil] The other objects, nil where the try lacks one of these or filters
          #   otherwise.
          def others(objects)
            list = objects.instance_variable_get(:@feature_objects)
            return nil unless list.is_a?(Array) && objects.instance_variable_get(:@filter) == @filter

            matched = 0
            others = []
            list.each { |object| @list[matched].equal?(object) ? matched += 1 : others << object }
            matched == @list.size ? others : nil
          end

          # Tells the features of a code these objects have, worked out once.
          #
          # @param code [Integer] The feature code.
          # @return [Array] The features.
          def features(code)
            (@features[code] ||= @objects.features(code)).dup
          end

          # Tells the features of a code and id these objects have, worked out once.
          #
          # @param code [Integer] The feature code.
          # @param id [Object] The data id.
          # @return [Array] The features.
          def features_with_id(code, id)
            ((@with_id[code] ||= {})[id] ||= @objects.features_with_id(code, id)).dup
          end
        end

        # Makes the copy a character tries the items of a slot on.
        #
        # @param actor [Game_Actor] The character.
        # @param slot [Integer] The slot.
        def initialize(actor, slot)
          @saved = Marshal.dump(actor)
          @slot = slot
          @copy = copy
          @slots = @copy.instance_variable_get(:@equips)
          @worn = Array(@slots).map { |each| each.respond_to?(:object) ? each.object : each }
          @copy.extend(KeptFeatures)
          @copy.__mf_trial = self
          @first = nil
          @boosts = {}
          @abilities = equipped_abilities
        end

        # Tells the character's parameters with an item in the slot.
        #
        # @param item [RPG::EquipItem, nil] The item, nil for an empty slot.
        # @return [Array<Integer>] The parameters, see Game::STAT_PARAMS.
        def stats(item)
          shared = steady_party { Game::STAT_PARAMS.map { |id| @copy.param(id) } if wear(item) && unchanged_by_refresh? }
          @answers ||= first_answers
          shared || stats_on_own_copy(item)
        end

        # Lets go of the copy.
        def release
          GearTrial.forget(@copy)
        end

        # Hands out the feature objects of a try, sharing the answers of the first try for every
        # feature the objects it adds to them lack.
        #
        # @param objects [Object] What the game's feature_objects answered.
        # @return [Object] The objects, sharing where they can.
        def shared(objects)
          return objects unless defined?(::Hima::FeatureObjects) && objects.instance_of?(::Hima::FeatureObjects)

          @first ||= FirstFeatures.new(objects)
          others = @first.others(objects)
          codes = others && codes_of(others)
          codes ? GearTrial.shared_class.new(objects, @first, codes) : objects
        end

        # Hands out the class of feature objects that share the first try's answers.
        #
        # @return [Class] A Hima::FeatureObjects that asks its own objects only for the codes and
        #   ids of those the first try lacks.
        def self.shared_class
          @shared_class ||= Class.new(::Hima::FeatureObjects) do
            # Takes a try's objects.
            #
            # @param objects [Hima::FeatureObjects] The try's objects.
            # @param first [FirstFeatures] The first try's.
            # @param added [Hash] The data ids of the objects the try adds, true by id, by code.
            def initialize(objects, first, added)
              super(objects.instance_variable_get(:@feature_objects))
              self.filter = objects.instance_variable_get(:@filter)
              @first = first
              @added = added
            end

            # Tells whether the objects the try adds have features of a code.
            #
            # @param code [Integer] The feature code.
            # @return [Boolean] Whether they have.
            def adds_code?(code)
              @added.key?(code)
            end

            # Tells whether the objects the try adds have features of a code and data id.
            #
            # @param code [Integer] The feature code.
            # @param id [Object] The data id.
            # @return [Boolean] Whether they have.
            def adds?(code, id)
              ids = @added[code]
              ids ? ids.key?(id) : false
            end

            # Tells the features of a code, the first try's where the added objects lack it.
            #
            # @param code [Integer] The feature code.
            # @return [Array] The features.
            def features(code)
              adds_code?(code) ? super : @first.features(code)
            end

            # Tells the features of a code and id, the first try's where the added objects lack
            # both.
            #
            # @param code [Integer] The feature code.
            # @param id [Object] The data id.
            # @return [Array] The features.
            def features_with_id(code, id)
              adds?(code, id) ? super : @first.features_with_id(code, id)
            end
          end
        end

        # Tells Paradox's boost of a parameter by the party's members, worked out once for every
        # try whose objects add no booster of it.
        #
        # The boost reads only the copy's boosters of it and the ids of the party's members, but
        # looks each member up for each parameter, which costs a parameter read the most.
        #
        # @param param_id [Integer] The parameter.
        # @yield Works the boost out.
        # @return [Float] The boost.
        def shared_boost(param_id)
          objects = @copy.feature_objects
          return yield unless defined?(::Fts::ACTOR_EXIST_PARAM) && objects.respond_to?(:adds?) &&
                              !objects.adds?(::Fts::FEATURE_MULTI_BOOSTER, ::Fts::ACTOR_EXIST_PARAM)

          @boosts.key?(param_id) ? @boosts[param_id] : @boosts[param_id] = yield
        end

        # Tells whether the game's refresh would leave a character as it is, such as a copy that
        # just put an item on, see #unchanged_by_refresh?.
        #
        # @param actor [Game_Actor] The character.
        # @return [Boolean] Whether it would.
        def self.refresh_keeps?(actor)
          check = allocate
          check.instance_variable_set(:@copy, actor)
          check.instance_variable_set(:@abilities, check.__send__(:equipped_abilities))
          check.__send__(:unchanged_by_refresh?)
        end

        # Takes a copy of a character out of the game's cache of each character's features.
        #
        # The game keeps every character it saw there until its scene ends, so on the map each copy
        # an Optimize made stayed with all its features until the game ran out of memory.
        #
        # @param copy [Game_Actor, nil] The copy, nil for none.
        def self.forget(copy)
          cache = copy && defined?(::CacheActorFeatures) ? ::CacheActorFeatures.instance_variable_get(:@cache) : nil
          cache.delete(copy) if cache.is_a?(Hash)
        end

        private

        # Makes a copy of the character as the game's equip screen makes one to preview an item.
        #
        # @return [Game_Actor] The copy.
        def copy
          copy = Marshal.load(@saved)
          copy.extend(::OverrideStones) if defined?(::OverrideStones)
          copy
        end

        # Tells the feature codes and data ids some objects have.
        #
        # @param objects [Array] The objects.
        # @return [Hash, nil] True by data id, by code; nil where an object keeps its features
        #   otherwise.
        def codes_of(objects)
          codes = {}
          objects.each do |object|
            data = object.respond_to?(:feature_data) ? object.feature_data : nil
            return nil unless data.is_a?(Hash) && data.values.all? { |by_id| by_id.is_a?(Hash) }

            data.each { |code, by_id| ids = (codes[code] ||= {}); by_id.each_key { |id| ids[id] = true } }
          end
          codes
        end

        # Puts the item into the slot of the copy, its other slots as the character wears them,
        # and has it work its features out anew.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Boolean] Whether it could; false where the slots hold no game items.
        def wear(item)
          return false unless @slots.is_a?(Array) && @slots.all? { |each| each.respond_to?(:object=) }

          @worn.each_with_index { |worn, slot| @slots[slot].object = worn }
          @slots[@slot].object = item
          @copy.forget_features
          ::CacheActorFeatures.init_actor(@copy) if defined?(::CacheActorFeatures) && ::CacheActorFeatures.respond_to?(:init_actor)
          keep_first_answers
          true
        end

        # Lets the game's cache of the copy's features answer with the first try's answer about
        # each feature code and id the objects of this try add nothing to, as each is asked.
        def keep_first_answers
          cache = answers_cache
          return unless cache && @answers

          objects = @copy.feature_objects
          return unless objects.respond_to?(:adds?)

          own = (cache[@copy] ||= {})
          @answers.each do |name, answers|
            own[name] = Hash.new { |kept, args| kept[args] = answers[args] if answers.key?(args) && shared_answer?(objects, name, args) }
          end
        end

        # Tells the answers of the game's cache of features the first try worked out, which later
        # tries may share.
        #
        # @return [Hash, nil] The answers by method and arguments; nil without the cache.
        def first_answers
          cache = answers_cache
          own = cache && cache[@copy]
          return nil unless own.is_a?(Hash)

          answers = {}
          shared_answers.each { |name| answers[name] = own[name].dup if own[name].is_a?(Hash) }
          answers
        end

        # Tells the methods of the game's cache of features whose answers a try may share: each of
        # SHARED_ANSWERS, and Paradox's boosters, which ask about its feature code of boosters.
        #
        # @return [Array<Symbol>] The methods.
        def shared_answers
          defined?(::Fts::FEATURE_MULTI_BOOSTER) ? SHARED_ANSWERS.keys + [:features_sum_booster] : SHARED_ANSWERS.keys
        end

        # Tells whether a try may share an answer of the first try: whether the objects it adds
        # lack the feature code, and the data id, the answer is about.
        #
        # @param objects [Hima::FeatureObjects] The try's objects, see GearTrial.shared_class.
        # @param name [Symbol] The method of the game's cache of features.
        # @param args [Array] Its arguments.
        # @return [Boolean] Whether it may.
        def shared_answer?(objects, name, args)
          return !objects.adds?(::Fts::FEATURE_MULTI_BOOSTER, args[0]) if name == :features_sum_booster

          SHARED_ANSWERS[name] ? !objects.adds?(args[0], args[1]) : !objects.adds_code?(args[0])
        end

        # Tells the game's cache of each character's features, while it keeps answers.
        #
        # @return [Hash, nil] The cache, nil for a game without it.
        def answers_cache
          return nil unless defined?(::CacheActorFeatures) && ::CacheActorFeatures.respond_to?(:cache?) && ::CacheActorFeatures.cache?

          cache = ::CacheActorFeatures.instance_variable_get(:@cache)
          cache.is_a?(Hash) ? cache : nil
        end

        # Tells whether the game's refresh would leave the copy as it is: every item still fits
        # its slot, every equipped ability stays, no state the gear resists is on, and death
        # comes with no HP.
        #
        # @return [Boolean] Whether it would.
        def unchanged_by_refresh?
          return false unless kept_items? && kept_abilities?

          states = Array(@copy.instance_variable_get(:@states))
          return false unless (Array(@copy.state_resist_set) & states).empty?

          !@copy.respond_to?(:death_state_id) || (@copy.hp == 0) == states.include?(@copy.death_state_id)
        end

        # Tells whether every item of the copy still fits its slot, as release_unequippable_items asks.
        #
        # @return [Boolean] Whether it does.
        def kept_items?
          fixed = @copy.respond_to?(:equip_type_fixed?) && @copy.respond_to?(:basic_equip_slots)
          @copy.equips.each_with_index.all? do |item, slot|
            item.nil? || (fixed && @copy.equip_type_fixed?(@copy.basic_equip_slots[slot])) || Game.__send__(:fits_slot?, @copy, slot, item)
          end
        end

        # Tells whether every ability the copy has equipped stays, as Paradox's refresh_ability asks;
        # worked out once for every try whose objects add none of ABILITY_CODES.
        #
        # @return [Boolean] Whether it does; true for a game without equipped abilities.
        def kept_abilities?
          return true unless @abilities

          shared = shares_abilities?
          return @abilities_kept if shared && !@abilities_kept.nil?

          kept = @abilities.all? do |stype, equipped, fitting, used|
            fitting && learned_all?(stype, equipped) && !(used && used > @copy.max_ap(stype))
          end
          @abilities_kept = kept if shared
          kept
        end

        # Tells whether the copy's objects add no feature the abilities it learned and the ability
        # points it has depend on, so its abilities stay as with the first try.
        #
        # @return [Boolean] Whether they add none.
        def shares_abilities?
          objects = @copy.feature_objects
          return false unless objects.respond_to?(:adds_code?)

          ABILITY_CODES.all? do |owner, name|
            owner = Object.const_defined?(owner) ? Object.const_get(owner) : nil
            owner && owner.const_defined?(name) && !objects.adds_code?(owner.const_get(name))
          end
        end

        # Tells whether the copy has learned every one of some abilities of a skill type.
        #
        # @param stype [Integer] The skill type.
        # @param ids [Array<Integer>] The abilities.
        # @return [Boolean] Whether it has.
        def learned_all?(stype, ids)
          return true if ids.empty?

          learned = {}
          @copy.abilities(stype).each { |id| learned[id] = true }
          ids.all? { |id| learned[id] }
        end

        # Tells the abilities the copy has equipped per skill type, which no item it wears changes,
        # with whether they suit its class and the ability points they take.
        #
        # @return [Array<Array>, nil] Per skill type the type, the abilities, whether they suit and
        #   the points (nil without points); nil for a game without equipped abilities.
        def equipped_abilities
          return nil unless @copy.respond_to?(:equip_abilities) && @copy.respond_to?(:abilities)

          @copy.equip_abilities.map do |stype, ids|
            [stype, ids.dup, ids.all? { |id| $data_skills[id].class_conditions_met?(@copy) }, @copy.respond_to?(:ap) ? @copy.ap(stype) : nil]
          end
        end

        # Reads the copy against a steady party: its members looked up once, and the game's
        # one-time fixes of each character it looks up turned off.
        #
        # Paradox looks every party member up for each parameter read, running those fixes each
        # time; they fixed every member at its first lookup, and the read takes only their ids.
        #
        # @yield Reads the copy.
        # @return [Object] What the block answers.
        def steady_party
          actors = $game_actors
          party = $game_party
          fixes = actors.respond_to?(:bugfix_ignore_flag=)
          was = actors.bugfix_ignore_flag if fixes
          begin
            actors.bugfix_ignore_flag = true if fixes
            $game_party = @steady ||= SteadyParty.new(party) if party.respond_to?(:members)
            yield
          ensure
            $game_party = party
            actors.bugfix_ignore_flag = was if fixes
          end
        end

        # The party while the copy is read: its members looked up once, everything else asked of
        # the party itself.
        class SteadyParty
          # Looks the party's members up.
          #
          # @param party [Game_Party] The party.
          def initialize(party)
            @party = party
            @members = party.members
          end

          # Tells the party's members.
          #
          # @return [Array<Game_Actor>] The members.
          def members
            @members.dup
          end

          # Asks the party itself.
          #
          # @param name [Symbol] The method.
          # @param args [Array] Its arguments.
          # @param block [Proc, nil] Its block.
          # @return [Object] What the party answers.
          def method_missing(name, *args, &block)
            @party.__send__(name, *args, &block)
          end

          # Tells whether the party answers a method.
          #
          # @param name [Symbol] The method.
          # @param private [Boolean] Whether private methods count.
          # @return [Boolean] Whether it does.
          def respond_to_missing?(name, private = false)
            @party.respond_to?(name, private)
          end
        end

        # Tells the parameters on a copy of their own with the item, through the game's refresh.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array<Integer>] The parameters.
        def stats_on_own_copy(item)
          own = copy
          own.force_change_equip(@slot, item)
          Game::STAT_PARAMS.map { |id| own.param(id) }
        ensure
          GearTrial.forget(own)
        end
      end
    end
  end
end
