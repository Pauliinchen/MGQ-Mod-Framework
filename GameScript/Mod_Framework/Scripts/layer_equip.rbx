#----------------------------------------------------------------
#  layer_equip.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Let every reader note the gear of anyone, so its render renders again after a gem set
#                            - Removed the slots and the tooltip of an item's sockets, Optimize and Clear, which the Equipment Window does itself
#                            - Added readers of an item's stats, gems, comparison and details, and of a character's stats with an item
#      Paulinchen  2026-11-07: Took over the slots and the tooltip of an item's sockets and removed the old comparisons
#                            - Greyed the remove row by :remove_disabled
#      Paulinchen  2026-11-06: Took the warning color of a fixed slot as the game data names it
#      Paulinchen  2026-11-05: Named the color of a slot's line for an item header as color params name it
#                            - Moved the summary and the details of an item into the components Summary and Details
#                            - Told whether the gems of an item in a given slot cannot change
#                            - Added the item worn set against another, folded to its room, and a socket's gem set against
#                              another
#                            - Told the items a slot takes and the gems a socket takes as rows of a list
#      Paulinchen  2026-11-04: Added the summary and the details of an item, built anew as the item, its gems or its part change
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # What a component of the UI layer reads of a character's equipment, its items and their gems,
    # through the game's own methods, without changing anything. A render that reads anything here
    # renders again once anyone's gear or a gem in it changes.
    module Equip
      # Tells the item in a character's slot.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer, nil] The slot, from 0.
      # @return [RPG::EquipItem, nil] The item, nil for an empty slot or no slot.
      def self.item(actor, slot)
        read_gear
        slot ? Game.equips(actor)[slot] : nil
      end

      # Tells a character's slots as rows of a list: each slot's item as the game's menus show it,
      # or a faint row naming an empty slot; a slot whose item cannot change takes no pick.
      #
      # @param actor [Game_Actor] The character.
      # @return [Array<Hash>] A row per slot.
      def self.slot_rows(actor)
        read_gear
        Game.slot_rows(actor)
      end

      # Tells the items a character can wear in a slot as rows of a list, as the game's equip list
      # picks them from the bag: a row that takes the slot's item out while it holds one, then each
      # item with its count, a favorite with a star.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot, from 0.
      # @return [Array<Hash>] A row per item, its item under :item.
      def self.item_rows(actor, slot)
        read_gear
        Game.equip_rows(actor, slot)
      end

      # Tells the gems of the bag that go into a socket of an item without pushing another socket's
      # gem out, as rows of a list: a row that empties the socket, greyed while it is empty, then each
      # gem with what it adds and its count, or a dim row that says why there is none.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param socket [Integer] The socket, from 0.
      # @return [Array<Hash>] A row per gem, its gem under :item.
      def self.gem_rows(item, socket)
        read_gear
        Engine::Gems.rows(:remove_disabled => Engine::EquipInfo.gems_of(item)[socket].nil?, :item => item, :socket => socket)
      end

      # Tells a slot's line for an item header: its name and its item's type, dim, or in the warning
      # color with a word that its item cannot change, as color params name the colors.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @return [Array] The text and its color.
      def self.slot_note(actor, slot)
        read_gear
        note = Game.slot_note(actor, slot)
        [note[:note], note[:note_color]]
      end

      # Tells whether an item has sockets for gems.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Boolean] Whether it has.
      def self.socketed?(item)
        read_gear
        !Engine::EquipInfo.gems_of(item).empty?
      end

      # Tells how many of an item's sockets hold a gem, such as "1/2".
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [String] The gems and the sockets.
      def self.gems_text(item)
        read_gear
        Engine::Gems.filled_text(item)
      end

      # Tells whether an item belongs to a set.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Boolean] Whether it does.
      def self.in_set?(item)
        read_gear
        !Engine::EquipInfo.of(item).sets(nil).empty?
      end

      # The line of an item or a gem whose stats and effects are both empty.
      NOTHING_TEXT = Engine::EquipInfo::NOTHING_TEXT

      # The notes of what an equip does with the gems, see gems_after, by what they say.
      GEM_TEXTS = { :stays => "Stays in this item", :moves_to => "Moves to %s", :staying => "%s in the worn item", :moves_over => "Moves over from %s",
                    :from_worn => "+%s from the worn item", :gem_words => ["gem", "gems", "stays", "stay"] }

      # How many of the items with the most rows of stat cells beside the worn item, and how many
      # with the most features, room tells; measuring every item would be too slow for a list of
      # hundreds.
      MEASURED_ITEMS = 2

      # The columns the stat cells of a comparison lie in, which room counts the rows of.
      CELL_COLUMNS = 2

      # How many readings of an item info_of keeps before it starts anew.
      INFOS_KEPT = 64

      # Tells the stats an item adds with its gems, as rows of a stat_grid: the parameters, then the
      # rates, each row with the number a comparison judges it by.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param options [Hash] :gems (the gem in each socket in place of those it holds).
      # @return [Array<Array<Hash>>] The rows of the parameters and the rows of the rates.
      def self.stats(item, options = {})
        read_gear
        info = info_of(item, options[:gems])
        [Engine::EquipInfo.rows(info.basic_cells), Engine::EquipInfo.rows(info.rate_cells)]
      end

      # Tells the gem in each socket of an item.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<RPG::Item, nil>] A gem or nil per socket, empty for an item without sockets.
      def self.sockets(item)
        read_gear
        Engine::EquipInfo.gems_of(item)
      end

      # Tells the elements an item strikes with that show by its name: the first three with an
      # icon, its gems' among them; the others stay among its effect lines.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<Hash>] Each :id, :name and :icon.
      def self.elements(item)
        read_gear
        info_of(item).name_elements
      end

      # Sets an item against the worn one: the stat rows of both, paired so each stat has a row on
      # both sides, and the effect lines both have.
      #
      # @param worn [RPG::EquipItem, nil] The worn item.
      # @param item [RPG::EquipItem, nil] The item set against it.
      # @param options [Hash] :gems (the item's gems after the equip, see gems_after).
      # @return [Hash] :worn and :item (each the rows of the parameters and of the rates, see stats)
      #   and :shared (the effect lines both have).
      def self.compare(worn, item, options = {})
        read_gear
        worn_info = worn && info_of(worn)
        item_info = item && info_of(item, options[:gems])
        worn_rows, item_rows = Engine::EquipInfo.pair_rows(worn_info, item_info)
        { :worn => worn_rows, :item => item_rows, :shared => worn_info && item_info ? worn_info.effect_texts & item_info.effect_texts : [] }
      end

      # Tells what putting an item on in place of the worn one does with the gems, as the game's
      # change_equip moves them, with a note per socket of each side and a note of each side.
      #
      # @param worn [RPG::EquipItem, nil] The worn item.
      # @param item [RPG::EquipItem, nil] The item put on, nil for taking the worn one off.
      # @return [Hash] :gems (the item's gems after the equip), :kept (the worn item's), :moved (the
      #   sockets of the item the worn gems move into), :worn_notes and :item_notes (per socket a
      #   text and its color, or nil), :worn_note and :item_note (a text and its color, or nil).
      def self.gems_after(worn, item)
        read_gear
        gems, kept, moved = item ? Engine::EquipInfo.gems_after_equip(worn, item) : [[], Engine::EquipInfo.gems_of(worn), []]
        worse = Game::POWER_DOWN_COLOR
        staying = item ? kept.compact.size : 0
        worn_notes = Engine::EquipInfo.gems_of(worn).each_with_index.map do |gem, place|
          next nil unless item && gem

          kept[place] ? [GEM_TEXTS[:stays], worse] : [format(GEM_TEXTS[:moves_to], Game.item_name(item)), :system]
        end
        { :gems => gems, :kept => kept, :moved => moved, :worn_notes => worn_notes,
          :worn_note => staying > 0 ? [format(GEM_TEXTS[:staying], UI.counted(staying, *GEM_TEXTS[:gem_words])), worse] : nil,
          :item_notes => gems.each_index.map { |place| moved.include?(place) ? [format(GEM_TEXTS[:moves_over], Game.item_name(worn)), :system] : nil },
          :item_note => moved.empty? ? nil : [format(GEM_TEXTS[:from_worn], UI.counted(moved.size, *GEM_TEXTS[:gem_words].first(2))), :dim] }
      end

      # Tells how much room an item likely takes set against the worn one, or which items of a list
      # likely take the most, for the copies of compact_for:, so a comparison takes the compact forms
      # the tallest of them needs as it opens and keeps them as the cursor moves.
      #
      # @param item [RPG::EquipItem, Array] The item, or the items or rows of item_rows of a list.
      # @param worn [RPG::EquipItem, nil] The worn item, whose stat cells pair with each item's.
      # @return [Array] For an item its rows of stat cells beside the worn item's, all its features
      #   and 1 with sockets or 0; for a list up to twice MEASURED_ITEMS items: those with the most
      #   rows of stat cells, which never fold, and those with the most features, sockets first.
      def self.room(item, worn)
        read_gear
        worn_keys = cell_keys(worn)
        return room_of(item, worn_keys) unless item.is_a?(Array)

        counted = item.map { |each| each.is_a?(Hash) ? each[:item] : each }.compact.map { |each| [each, room_of(each, worn_keys)] }
        by_cells = counted.sort_by { |_each, room| [-room[0], -room[2]] }.first(MEASURED_ITEMS)
        by_features = counted.sort_by { |_each, room| [-room[1], -room[2]] }.first(MEASURED_ITEMS)
        (by_cells + by_features).map { |each, _room| each }.uniq
      end

      # Tells the effect lines of an item with its gems, as lines takes them: each group with its
      # heading as its label, and with actor: a gold line per set.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param options [Hash] :gems (its gems after an equip, see gems_after), :shared (lines another
      #   item has too, which fold into one line that counts them, see compare) and :actor (the
      #   character whose worn pieces of a set count).
      # @return [Array] The groups, then the lines of no group.
      def self.effects(item, options = {})
        read_gear
        info_of(item, options[:gems]).effect_lines(options)
      end

      # Tells the game's own Base Stats of an item, as its info page lists them: its parameters by
      # their full names, without its gems.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<Hash>] Rows of a stat_grid, each :name and :value.
      def self.base_stats(item)
        read_gear
        info_of(item).base_stat_rows
      end

      # Tells the game's own Special Effects of an item, as its info page lists them, in groups,
      # without the traits of its type (type_lines).
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<Hash>] Each group that has lines: :label and :lines.
      def self.special_effects(item)
        read_gear
        info_of(item).effect_name_groups(:type_traits => false)
      end

      # Tells the traits an item has by its weapon or armor type: a weapon's normal attack, then the
      # lines most items of its type show that it shows too.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<String>] The lines, with the game's escape codes; empty for none.
      def self.type_lines(item)
        read_gear
        info_of(item).type_traits
      end

      # Tells the sets an item belongs to, as the game's set page shows them.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param actor [Game_Actor, nil] The character whose worn pieces count, nil for none.
      # @return [Array<Hash>] Each :name, :worn, :size, :note (such as "2/4 worn"), :color (the game's
      #   color of a set's name) and :lines (a group per step that has lines, as lines takes them,
      #   faint while the character has not reached it).
      def self.set_lines(item, actor)
        read_gear
        info = info_of(item)
        info.sets(actor).map do |set|
          { :name => set[:name], :worn => set[:worn], :size => set[:size], :note => format(Engine::EquipInfo::WORN_TEXT, set[:worn], set[:size]),
            :color => Engine::EquipInfo::SET_COLOR, :lines => info.set_line_groups(set) }
        end
      end

      # Tells what a gem adds and what describes it.
      #
      # @param gem [RPG::Item, nil] The gem.
      # @return [Hash, nil] :elements (see elements), :stats (see stats), :effects (see effects),
      #   :lines (everything it adds as plain lines, else the first line of its description),
      #   :brief (the first of those lines in one text), :description (without the gem's tag) and
      #   :color (see gem_color); nil without a gem.
      def self.gem_info(gem)
        return nil unless gem

        read_gear
        info = Engine::EquipInfo.of_gem(gem)
        { :elements => info.name_elements, :stats => [Engine::EquipInfo.rows(info.basic_cells), Engine::EquipInfo.rows(info.rate_cells)],
          :effects => info.effect_lines, :lines => info.added_lines(:fallback => true), :brief => info.brief,
          :description => Engine::EquipInfo.untagged(gem.description.to_s), :color => gem_color(gem) }
      end

      # Tells what putting a gem into a socket of an item, or emptying it, would change, or why the
      # game would refuse it, without changing anything.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param socket [Integer] The socket, from 0.
      # @param gem [RPG::Item, nil] The gem, nil to empty the socket.
      # @param options [Hash] :actor and :slot, the character's slot the item lies in, whose being
      #   fixed refuses it too.
      # @return [Hash] :old (the socket's gem now), :gem, :moved_from (the socket the same gem
      #   leaves), :pushed (each [socket, gem] that goes back to the bag), :emptied, :changed (every
      #   socket it changes), :unchanged (:already or :empty, else nil), :note (what it does, a text
      #   and its color) and :refusal (why the game refuses it, nil when it takes it).
      def self.gem_preview(item, socket, gem, options = {})
        read_gear
        Engine::Serials.read(:items)
        preview = Engine::Gems.preview(item, socket, gem)
        preview.merge(:note => Engine::Gems.describe(preview), :refusal => Engine::Gems.refusal(item, socket, gem, options))
      end

      # Tells a filter per gem color for a socket of an item, such as the toggles over a gem list:
      # every color, off where the bag has none or another socket holds one.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param socket [Integer] The socket, from 0.
      # @param options [Hash] :tooltip (a filter's tooltip by the color's name, such as "%s gems").
      # @return [Array<Hash>] Each color's :icon, :value (its icon), :tooltip and :disabled.
      def self.gem_colors(item, socket, options = {})
        read_gear
        Engine::Gems.color_filters(gem_bag, { :every_color => true, :taken => Engine::Gems.taken_colors(item, socket) }.merge(options))
      end

      # Tells a gem's color, as its icon shows it.
      #
      # @param gem [RPG::Item] The gem.
      # @return [Integer] Its icon, which gem_colors names the color by.
      def self.gem_color(gem)
        Engine::Gems.color(gem)
      end

      # Tells the gems of the bag, which the game offers for its sockets.
      #
      # @return [Array<RPG::Item>] The gems, in the bag's order.
      def self.gem_bag
        Engine::Serials.read(:items)
        Engine::Gems.bag
      end

      # Tells the parameters a character would have wearing an item in a slot, as the game's equip
      # screen previews it, on a copy of the character, the bag untouched.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @param item [RPG::EquipItem, Array, nil] The item, nil for an empty slot, or a list of them,
      #   tried on one copy, which is much faster than a call per item.
      # @return [Array] The eight parameters by their ids; for a list such an Array per item.
      def self.stats_with(actor, slot, item)
        trial = Engine::GearTrial.new(actor, slot)
        begin
          item.is_a?(Array) ? item.map { |each| trial.stats(each) } : trial.stats(item)
        ensure
          trial.release
        end
      end

      # Tells what an item likely takes, from its parameters and features and its gems'.
      #
      # @param item [RPG::EquipItem] The item.
      # @param worn [Array<Array>] The keys of the worn item's stat cells, which pair with its own.
      # @return [Array<Integer>] Its rows of stat cells beside the worn item's, all its features, and
      #   1 with sockets or 0.
      def self.room_of(item, worn)
        keys = (cell_keys(item) | worn).group_by { |kind, _id| kind }.values
        rows = keys.inject(0) { |sum, group| sum + (group.size + CELL_COLUMNS - 1) / CELL_COLUMNS }
        [rows, features_of(item).size, item.respond_to?(:socket?) && item.socket? ? 1 : 0]
      end

      # Tells the keys of the stat cells an item likely shows: a parameter it changes and a rate it
      # adds, its gems' among them.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @return [Array<Array>] [:param, id] and [:rate, id] keys.
      def self.cell_keys(item)
        return [] unless item

        params = Array(item.respond_to?(:params) ? item.params : nil)
        keys = (0...params.size).select { |id| params[id].to_i != 0 }.map { |id| [:param, id] }
        features_of(item).each do |feature|
          kind = stat_codes[feature.code]
          keys << [kind, feature.data_id] if kind
        end
        keys.uniq
      end

      # Tells the features of an item and of its gems.
      #
      # @param item [RPG::EquipItem] The item.
      # @return [Array<RPG::BaseItem::Feature>] The features.
      def self.features_of(item)
        ([item] + Engine::EquipInfo.armors_of(Engine::EquipInfo.gems_of(item))).map { |part| Array(part.respond_to?(:features) ? part.features : nil) }.flatten
      end

      # Tells the kind of stat cell of each of the game's feature codes a comparison shows as cells.
      #
      # @return [Hash{Integer => Symbol}] :param or :rate by code.
      def self.stat_codes
        @stat_codes ||= Hash[{ :PARAM => :param, :XPARAM => :rate, :XPARAM_EX => :rate }.map do |name, kind|
          constant = "FEATURE_#{name}"
          defined?(::NWFeature) && ::NWFeature.const_defined?(constant) ? [::NWFeature.const_get(constant), kind] : nil
        end.compact]
      end
      private_class_method :room_of, :cell_keys, :features_of, :stat_codes

      # Reads an item with its gems once while they, anyone's gear and the database stay the same,
      # since a comparison and its compact copies ask several readers of the same items on every
      # render.
      #
      # @param item [RPG::EquipItem, nil] The item.
      # @param gems [Array<RPG::Item, nil>, nil] The gem in each socket, nil for those it holds.
      # @return [Engine::EquipInfo] The reading.
      def self.info_of(item, gems = nil)
        gems ||= Engine::EquipInfo.gems_of(item)
        key = [item, gems, Engine::Serials.serial(:gear), $data_armors.object_id]
        @infos = {} if @infos.nil? || @infos.size >= INFOS_KEPT
        @infos[key] ||= Engine::EquipInfo.of(item, gems)
      end

      # Notes that the render reads an item or its gems, so it renders again once a piece or a gem of
      # anyone's changes, also from a dialog or another mod.
      def self.read_gear
        Engine::Serials.read(:gear)
      end
      private_class_method :info_of, :read_gear

      # Tells whether the gems in a character's slot can change: its item has sockets and the slot
      # is not fixed.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @return [Boolean] Whether they can.
      def self.gems_changeable?(actor, slot)
        read_gear
        Engine::Gems.changeable?(actor, slot)
      end

      # Tells whether a character wears an item with sockets in a slot whose gems cannot change, such
      # as a fixed one.
      #
      # @param actor [Game_Actor] The character.
      # @param item [RPG::EquipItem, nil] The item.
      # @param slot [Integer, nil] The slot it lies in; nil for the slot that holds it.
      # @return [Boolean] Whether they do.
      def self.gems_fixed?(actor, item, slot = nil)
        read_gear
        slot ||= item && Game.equips(actor).index { |each| each.equal?(item) }
        !slot.nil? && socketed?(item) && !gems_changeable?(actor, slot)
      end
    end
  end
end
