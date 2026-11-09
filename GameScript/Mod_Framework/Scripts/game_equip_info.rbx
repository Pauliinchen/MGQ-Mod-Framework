#----------------------------------------------------------------
#  game_equip_info.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Removed the lines and the summary of gems in a tooltip's box, which the Equipment Window builds itself
#                            - Told a gem's description without its tag to anyone who asks
#      Paulinchen  2026-11-07: Removed kind_chips, which nothing called
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What the game's equip info page and an item summary read of an equipment and the gems in its
      # sockets, or of a gem alone, without changing anything: the stats they change as cells, their
      # effect lines grouped, the elements a weapon strikes with, the game's own Base Stats and Special
      # Effects, the gems and the sets. It reads the game's enchant names from the item at runtime,
      # since a plugin replaces them, and copes with an item that lacks any of the game's methods.
      class EquipInfo
        # The groups of effect lines, in the order they show, with their headings.
        GROUPS = [[:attack, "Attack"], [:defense, "Defense"], [:other, "Other"]]

        # The kinds of what an item or a gem adds (#kinds), in the order they show, each with its name
        # and what it stands for.
        KINDS = [[:basic, "Stats", "Raises a stat, such as HP or ATK"], [:rate, "Rates", "Raises a rate, such as Hit or Critical"],
                 [:attack, "Damage", "Deals more damage, strikes or an element"], [:defense, "Resist", "Resists an element, a state or a debuff"],
                 [:other, "Other", "Any other effect"]]

        # The feature codes whose lines are Attack effects.
        ATTACK_CODES = [:ATK_STATE, :ATK_SPEED, :ATK_TIMES, :ACTION_PLUS, :MULTI_BOOSTER, :TERRAIN_BOOSTER, :EQUIP_MASTERY, :ATK_ELEMENT]

        # The feature codes whose lines are Defense effects.
        DEFENSE_CODES = [:ELEMENT_RATE, :DEBUFF_RATE, :STATE_RATE, :STATE_RESIST, :ELEMENT_DRAIN, :BLOCK_RATE]

        # The feature codes the cells show, whose lines are left out.
        STAT_CODES = [:PARAM, :XPARAM, :XPARAM_EX]

        # The elements a weapon can strike with, as the game names them.
        STRIKE_ELEMENTS = 2..53

        # The most elements a summary shows by an item's name, of those with an icon; the others are
        # Attack lines.
        NAME_ELEMENTS = 3

        # The names of the rate cells by the extra parameter's id, the game's own shortened.
        RATE_NAMES = ["Hit", "Evasion", "Critical", "Crit. Evasion", "M. Evasion", "M. Reflect", "Counter", "HP Regen", "MP Regen", "TP Regen"]

        # The hit rate the game gives a weapon that names none.
        DEFAULT_HIT = 0.8

        # The key of the cell of a weapon's base hit rate, which is no bonus.
        HIT_BASE = :hit_base

        # The words of the line that counts the effect lines two items share.
        SHARED_WORDS = ["shared effect", "shared effects"]

        # What stands between the parts of a short note of what is added.
        BRIEF_JOIN = " #{[0xB7].pack('U')} "

        # The brackets, as code points, of the tag the game puts before a gem's description, which its
        # info page leaves out: the game's 【秘石】, the English translation's [Gem] and the Russian
        # translation's [Самоцвет].
        GEM_TAG_BRACKETS = [[0x3010, 0x3011], [0x5B, 0x5D]]

        # One tag of any word in GEM_TAG_BRACKETS at the start of a gem's description, with the space
        # after it.
        GEM_TAG = Regexp.new("\\A(?:" + GEM_TAG_BRACKETS.map { |open, close|
          closing = Regexp.escape([close].pack("U"))
          "#{Regexp.escape([open].pack('U'))}[^#{closing}\\r\\n]*#{closing}"
        }.join("|") + ") ?")

        # The line of an item or a gem that changes nothing.
        NOTHING_TEXT = "Adds no stats or effects"

        # The label of a set's step, by the pieces it needs.
        PIECES_TEXT = "%d pc"

        # The game's text color of a set's name, as its set page shows it.
        SET_COLOR = 11

        # How many pieces of a set a character wears, by those and the set's size.
        WORN_TEXT = "%d/%d worn"

        # The line of a weapon type's normal attack, by its formula.
        NORMAL_ATTACK_TEXT = "Normal Attack: %s"

        # The share of a type's named items that must show a line before it counts as the type's
        # own. Stronger items of a type replace its line with their own value, so not every item
        # shows it.
        TYPE_SHARE = 0.75

        # The fewest named items of a type that have lines of the type, since one item's lines are its
        # own.
        TYPE_LEAST = 2

        # The game's escape codes, which a line compares without.
        ESCAPE = /\\[A-Za-z]+(\[[^\]]*\])?/

        # The no-break space, which hand-written lines put between words.
        NO_BREAK_SPACE = [0xA0].pack("U")

        # Reads an equipment with the gems in its sockets.
        #
        # @param item [RPG::EquipItem, nil] The item; nil reads nothing, for a side with no item.
        # @param gems [Array<RPG::Item, nil>, nil] The gem in each socket, nil for an empty one; nil for
        #   those it holds.
        # @return [EquipInfo] What it reads.
        def self.of(item, gems = nil)
          return new(nil, [], []) unless item

          gems ||= gems_of(item)
          new(item, gems, [item] + armors_of(gems))
        end

        # Reads a gem alone, once per gem while the database stays the same.
        #
        # @param gem [RPG::Item] The gem.
        # @return [EquipInfo] What it reads.
        def self.of_gem(gem)
          stamp = [$data_armors.object_id, Array($data_armors).size]
          @gem_reads = {} unless @gem_stamp == stamp
          @gem_stamp = stamp
          @gem_reads[gem] ||= new(nil, [], armors_of([gem]), gem)
        end

        # Tells the gem in each socket of an item.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array<RPG::Item, nil>] A gem or nil per socket, empty for an item without sockets.
        def self.gems_of(item)
          count = item && item.respond_to?(:socket_num) ? item.socket_num.to_i : 0
          return [] if count <= 0

          gems = item.respond_to?(:stones) ? Array(item.stones).first(count) : []
          gems + [nil] * (count - gems.size)
        end

        # Finds the armors that stand for gems, as the game reads what a gem adds.
        #
        # @param gems [Array<RPG::Item, nil>] The gems.
        # @return [Array<RPG::Armor>] The armors.
        def self.armors_of(gems)
          gems.compact.map { |gem| gem.respond_to?(:enchant_stone_id) ? Array(gem.enchant_stone_id).map { |id| $data_armors[id] } : [] }.flatten.compact
        end

        # Tells what an equip does with the gems, without doing it: as Game_Actor#change_equip has
        # the worn item trade_stone, each empty socket of the new item takes the worn item's gem of
        # the same socket while the worn item has any, and a gem that comes in pushes out the new
        # item's gems of its category.
        #
        # @param worn [RPG::EquipItem, nil] The item worn now.
        # @param item [RPG::EquipItem, nil] The item put on.
        # @return [Array] The new item's gems after the equip, the worn item's, and the sockets of the
        #   new item the worn item's gems moved into.
        def self.gems_after_equip(worn, item)
          kept = gems_of(worn)
          gems = gems_of(item)
          moved = []
          gems.size.times do |place|
            next if gems[place]
            break if kept.compact.empty?

            gem = kept[place]
            kept[place] = nil if place < kept.size
            next unless gem

            gems.each_with_index do |other, at|
              next unless other && at != place && same_category?(other, gem)

              gems[at] = nil
              moved.delete(at)
            end
            gems[place] = gem
            moved << place
          end
          [gems, kept, moved]
        end

        # Tells the gems of an item after a gem goes into one of its sockets, without changing
        # anything, as the game's change_stone puts it there: the gem pushes every other socket's gem
        # of its category out (two gems without a category count as one kind), and nil empties the
        # socket. A socket the item lacks changes nothing.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @param gem [RPG::Item, nil] The gem, nil to empty the socket.
        # @return [Array] The gem in each socket afterwards, and each [socket, gem] pushed out.
        def self.gems_after_set(item, socket, gem)
          gems = gems_of(item)
          return [gems, []] unless socket >= 0 && socket < gems.size

          moved = []
          gems.each_with_index do |other, place|
            next unless gem && other && place != socket && same_category?(other, gem)

            moved << [place, other]
            gems[place] = nil
          end
          gems[socket] = gem
          [gems, moved]
        end

        # Tells whether two gems are of the same category, which one socket holds once.
        #
        # @param one [RPG::Item] One gem.
        # @param other [RPG::Item] The other.
        # @return [Boolean] Whether they are.
        def self.same_category?(one, other)
          one.respond_to?(:enchant_stone_category) && other.respond_to?(:enchant_stone_category) && one.enchant_stone_category == other.enchant_stone_category
        end

        # Tells the traits of an equipment's weapon or armor type: for a weapon its normal attack's
        # formula, then the Special Effects lines that at least TYPE_SHARE of the named items of its
        # type in the database show, by kind and by name. Each type is read once while the database
        # stays the same.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array<String>] The lines, with the game's escape codes; empty for none.
        def self.type_traits(item)
          formula, lines = type_parts(item)
          [formula].compact + lines
        end

        # Tells the game's own Special Effects lines of an item, see #effect_names.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array<String>] The lines, with the game's escape codes.
        def self.effect_names_of(item)
          return [] unless item && item.respond_to?(:enchant_names)

          kept = features_of(item)
          template = kept.size < Array(item.features).size && item.respond_to?(:get_enchant_names)
          names = Array(template ? item.get_enchant_names(kept) : item.enchant_names)
          socketed = item.respond_to?(:socket?) && item.socket? && item.respond_to?(:socket_name)
          socketed && names.first == item.socket_name ? names.drop(1) : names
        end

        # Tells the features of an item or an armor that every copy of it has: a template of random
        # enchantments leaves out the features whose value the game works out for each copy.
        #
        # @param part [RPG::BaseItem] The item or the armor.
        # @return [Array<RPG::BaseItem::Feature>] The features.
        def self.features_of(part)
          Array(part.respond_to?(:features) ? part.features : []).reject { |feature| per_copy?(feature.value) }
        end

        # Tells whether a feature's value is one the game works out for each copy of an item, its
        # Enchant_Value, also inside a list or a table.
        #
        # @param value [Object] The value.
        # @return [Boolean] Whether it is.
        def self.per_copy?(value)
          case value
          when Array then value.any? { |each| per_copy?(each) }
          when Hash then value.values.any? { |each| per_copy?(each) }
          else defined?(::Enchant_Value) ? value.is_a?(::Enchant_Value) : false
          end
        end
        private_class_method :per_copy?

        # Tells a line as two lines are compared: without escape codes and plus signs, its spaces plain.
        #
        # Hand-written lines put no-break spaces where the game's own lines have plain ones, and a plus
        # sign where the game's line of an extra parameter has none.
        #
        # @param line [String] The line.
        # @return [String] The line compared.
        def self.compared(line)
          plain(line).gsub(NO_BREAK_SPACE, " ").delete("+").squeeze(" ").strip
        end

        # Tells the two parts of the traits of an item's type, read once per type while the database
        # stays the same.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array] The normal attack's line, nil for none, and the lines most items show.
        def self.type_parts(item)
          kind, list, id = type_of(item)
          return [nil, []] unless kind && id.to_i > 0

          stamp = [list.object_id, list.size]
          @type_parts ||= {}
          known = @type_parts[[kind, id]]
          return known[1] if known && known[0] == stamp

          formula = kind == :wtype_id ? Game.attack_formula(id) : nil
          items = list.select { |entry| entry && !entry.name.to_s.empty? && entry.respond_to?(kind) && entry.send(kind) == id }
          parts = [formula && format(NORMAL_ATTACK_TEXT, formula), shared_lines(items)]
          @type_parts[[kind, id]] = [stamp, parts]
          parts
        end

        # Tells an equipment's type and the database it is read against.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array] The type's method, the database's list and the type's id; nils for an item
        #   of no type.
        def self.type_of(item)
          if item.respond_to?(:wtype_id)
            [:wtype_id, $data_weapons || [], item.wtype_id]
          elsif item.respond_to?(:atype_id)
            [:atype_id, $data_armors || [], item.atype_id]
          else
            [nil, [], nil]
          end
        end

        # Tells the Special Effects lines that at least TYPE_SHARE of a list's items show, each in the
        # wording of the first that shows it, by kind (as that item's reading sorts it) and by name.
        # A template of random enchantments counts by the features every copy has (features_of); an
        # item the game cannot name the lines of does not count.
        #
        # @param items [Array<RPG::EquipItem>] The items of one type.
        # @return [Array<String>] The lines.
        def self.shared_lines(items)
          named = items.map { |entry| [entry, readable(entry) { effect_names_of(entry) }] }.select { |_entry, lines| lines }
          return [] if named.size < TYPE_LEAST

          counts = Hash.new(0)
          first = {}
          named.each do |entry, lines|
            lines.map { |line| [compared(line), line] }.uniq { |key, _line| key }.each do |key, line|
              counts[key] += 1
              first[key] ||= [line, entry]
            end
          end
          needed = (named.size * TYPE_SHARE).ceil
          readings = {}
          lines = counts.keys.select { |key| counts[key] >= needed }.map do |key|
            line, entry = first[key]
            readings[entry] = readable(entry) { new(entry, [], [entry]) } unless readings.key?(entry)
            [readings[entry] ? readings[entry].line_kind(line) : :other, line]
          end
          lines.sort_by { |kind, line| [GROUPS.index(GROUPS.assoc(kind)), plain(line).downcase] }.map { |_kind, line| line }
        end

        # Reads something of an item of the database, which the game may fail to name.
        #
        # @param item [RPG::EquipItem] The item.
        # @return [Object, nil] What the block reads, nil when it fails.
        def self.readable(item)
          yield
        rescue => e
          Game.log_once([:type_item, e.class], "an item of a type could not be read, so it does not count for the type's traits: #{item.name} #{Logging.failure(e)}")
          nil
        end
        private_class_method :type_of, :shared_lines, :readable

        # Takes the gem's tag, the game's or a translation's, off the start of a gem's description, as
        # the game's info page does.
        #
        # @param text [String] The description.
        # @return [String] The description without the tag; as it is when its encoding cannot be read.
        def self.untagged(text)
          text.sub(GEM_TAG, "")
        rescue ArgumentError, EncodingError
          text
        end

        # Takes the game's escape codes out of a text.
        #
        # @param text [String] The text.
        # @return [String] The text without them.
        def self.plain(text)
          text.to_s.gsub(ESCAPE, "")
        end

        # Tells where a cell goes among the cells of two items set side by side: the parameters in the
        # order of the game's compare pages, then the base hit rate, then the rates.
        #
        # @param key [Array] The cell's key, see stat_cells.
        # @return [Array] What sorts it.
        def self.cell_rank(key)
          return [0, Game::COMPARE_ORDER.index(key[1]).to_i] if key[0] == :param

          key[1] == HIT_BASE ? [1, -1] : [1, key[1].to_i]
        end

        # Turns cells into rows of Stats, keyed and with their flat and percent bonus to judge them by,
        # and the :base of a cell that has one.
        #
        # @param cells [Array<Hash>] The cells, see stat_cells.
        # @return [Array<Hash>] The rows.
        def self.rows(cells)
          cells.map do |cell|
            row = { :key => cell[:key], :name => cell[:name], :value => cell[:value], :number => [cell[:flat], cell[:percent]] }
            row[:base] = cell[:base] if cell.key?(:base)
            row
          end
        end

        # Sets the cells of two items side by side, as Stats.pair does, in the order of cell_rank.
        #
        # @param one [EquipInfo, nil] One item, nil for none.
        # @param other [EquipInfo, nil] The other, nil for none.
        # @return [Array<Array<Array<Hash>>>] The rows of the parameters and of the rates of the one, and
        #   those of the other.
        def self.pair_rows(one, other)
          order = lambda { |key| cell_rank(key) }
          basic = Stats.pair(rows(one ? one.basic_cells : []), rows(other ? other.basic_cells : []), :order => order)
          rates = Stats.pair(rows(one ? one.rate_cells : []), rows(other ? other.rate_cells : []), :order => order)
          [[basic[0], rates[0]], [basic[1], rates[1]]]
        end

        # @return [RPG::EquipItem, nil] The item, nil for a gem alone.
        attr_reader :item

        # Reads the parts that make up what is added.
        #
        # @param item [RPG::EquipItem, nil] The item, nil for a gem alone.
        # @param gems [Array<RPG::Item, nil>] The item's gems.
        # @param parts [Array<RPG::BaseItem>] The item and the armors of its gems, or a gem's armors.
        # @param gem [RPG::Item, nil] The gem read alone, nil for an item.
        def initialize(item, gems, parts, gem = nil)
          @item = item
          @gem = gem
          @gem_list = gems
          @parts = parts
          @flat = Array.new(8) { |id| parts.inject(0) { |sum, part| sum + part_param(part, id) } }
          @factors = {}
          @rates = {}
          @hit_base = nil
          @elements = []
          @lines = { :attack => [], :defense => [], :other => [] }
          @element_lines = []
          @stat_lines = []
          @kinds = {}
          parts.each { |part| read(part) }
          @named = @elements.select { |id| Game.element_icon(id) }.first(NAME_ELEMENTS)
          parts.each { |part| read_lines(part) }
          drop_repeated_lines
        end

        # Tells the stats the item and its gems change as cells, the parameters first in the order of
        # the game's compare pages, then the rates.
        #
        # @return [Array<Hash>] Each :key (the same stat of another item has the same), :kind (:basic
        #   or :rate), :name, :flat, :percent (nil for none) and :value (the text shown, a flat and a
        #   percent bonus together, such as "+1200 +40%"); the base hit rate's also :base, the flat
        #   and the percent of an item without it.
        def stat_cells
          basic_cells + rate_cells
        end

        # Tells the cells of the parameters, see stat_cells.
        #
        # @return [Array<Hash>] The cells.
        def basic_cells
          Game::COMPARE_ORDER.map do |id|
            flat = @flat[id] == 0 ? nil : @flat[id]
            percent = @factors[id] && ((@factors[id] - 1) * 100).round
            percent = nil if percent == 0
            next nil unless flat || percent

            value = [flat && Game.added(flat), percent && format("%+d%%", percent)].compact.join(" ")
            { :key => [:param, id], :kind => :basic, :name => Game.param_short(id), :flat => flat, :percent => percent, :value => value }
          end.compact
        end

        # Tells the cells of the rates, see stat_cells: a weapon's base hit rate first, with no sign
        # since it is no bonus, unless it is the one every weapon has, which its :base holds.
        #
        # @return [Array<Hash>] The cells.
        def rate_cells
          cells = @rates.keys.sort.map do |id|
            percent = @rates[id].round
            next nil if percent == 0

            { :key => [:rate, id], :kind => :rate, :name => RATE_NAMES[id], :flat => nil, :percent => percent, :value => format("%+d%%", percent) }
          end.compact
          return cells unless @hit_base && (@hit_base - DEFAULT_HIT).abs > 0.001

          base = (@hit_base * 100).round
          [{ :key => [:rate, HIT_BASE], :kind => :rate, :name => RATE_NAMES[0], :flat => nil, :percent => base, :value => "#{base}%",
             :base => [nil, (DEFAULT_HIT * 100).round] }] + cells
        end

        # Tells the elements the item and its gems strike with.
        #
        # @return [Array<Hash>] Each :id, :name and :icon.
        def attack_elements
          @elements.map { |id| element_of(id) }
        end

        # Tells the elements a summary shows by the item's name: the first NAME_ELEMENTS with an icon.
        # The others keep their lines among the Attack effects.
        #
        # @return [Array<Hash>] Each :id, :name and :icon.
        def name_elements
          @named.map { |id| element_of(id) }
        end

        # Tells the effect lines grouped, in the game's order and wording, without the lines the cells
        # and the elements by the name show.
        #
        # @return [Array<Array>] Each group that has lines: its key, its heading and its lines.
        def effect_groups
          GROUPS.map { |key, title| [key, title, @lines[key]] }.reject { |_key, _title, lines| lines.empty? }
        end

        # Tells every effect line, in the order of effect_groups.
        #
        # @return [Array<String>] The lines, with the game's escape codes.
        def effect_texts
          effect_groups.map { |_key, _title, lines| lines }.flatten
        end

        # Tells in short what the item or the gem adds, such as for a note beside its name: its first
        # cells, then the lines of the elements by its name, then its effect lines; with none of
        # them, the first line of its description.
        #
        # @param parts [Integer] How many it tells at most.
        # @return [String] Such as "ATK +50% · Fire Strike", empty for nothing added or told.
        def brief(parts = 3)
          told = added_lines.first(parts)
          told.empty? ? first_description_line : told.join(BRIEF_JOIN)
        end

        # Tells everything the item or the gem adds as plain lines, each value beside its name: its
        # cells, then the lines of the elements by its name, then its effect lines.
        #
        # @param options [Hash] :fallback (true answers the first line of its description when it
        #   adds none of them, else NOTHING_TEXT).
        # @return [Array<String>] Such as ["ATK +50%", "Fire Strike"], without escape codes.
        def added_lines(options = {})
          lines = stat_cells.map { |cell| "#{cell[:name]} #{cell[:value]}" } + (@element_lines + effect_texts).map { |line| EquipInfo.plain(line) }
          return lines unless lines.empty? && options[:fallback]

          told = first_description_line
          [told.empty? ? NOTHING_TEXT : told]
        end

        # Tells the text a search looks through for the item: its name and its effect lines.
        #
        # @return [String] The text in lower case, without escape codes, a line each.
        def search_text
          ([Game.item_name(@item || @gem)] + @element_lines + effect_texts).map { |line| EquipInfo.plain(line) }.join("\n").downcase
        end

        # Tells whether the item or the gem changes no stat and has no effect line and no set.
        #
        # @return [Boolean] Whether it adds nothing.
        def nothing?
          stat_cells.empty? && effect_groups.empty? && sets_of_item.empty?
        end

        # Tells the kinds of what the item or the gem adds, see KINDS, such as to filter gems by them.
        # A gem that tells none of them counts as :other, since its description alone tells what it
        # adds.
        #
        # @return [Array<Symbol>] The kinds, in the order of KINDS.
        def kinds
          found = { :basic => !basic_cells.empty?, :rate => !rate_cells.empty?, :attack => !@lines[:attack].empty? || !@element_lines.empty?,
                    :defense => !@lines[:defense].empty?, :other => !@lines[:other].empty? }
          kinds = KINDS.map { |key, _name, _tip| key }.select { |key| found[key] }
          kinds.empty? && @gem ? [:other] : kinds
        end

        # Tells the game's own Base Stats of the item: its parameters that are not 0, without gems.
        #
        # @return [Array<Array>] Each the parameter's full name and what it adds, such as "+3000".
        def base_stats
          return [] unless @item

          (0...8).map { |id| [Vocab.param(id).to_s, part_param(@item, id)] }.reject { |_name, value| value == 0 }.map { |name, value| [name, Game.added(value)] }
        end

        # Tells the game's own Base Stats as rows of Stats.
        #
        # @return [Array<Hash>] Each :name and :value.
        def base_stat_rows
          base_stats.map { |name, value| { :name => name, :value => value } }
        end

        # Tells the game's own Special Effects of the item, every line in its order and wording, but
        # the count of sockets, which shows with the item's name.
        #
        # @return [Array<String>] The lines, with the game's escape codes.
        def effect_names
          EquipInfo.effect_names_of(@item)
        end

        # Tells the game's own Special Effects of the item in the groups of effect_groups, as Lines
        # takes them, then the item's own lines they lack (missing_lines), each in its group; the lines
        # of the stats it changes are Other lines.
        #
        # @param options [Hash] :type_traits (false leaves out the lines of #type_traits and the
        #   traits of the item's type).
        # @return [Array<Hash>] Each group that has lines: :label (its heading) and :lines.
        def effect_name_groups(options = {})
          names = own_lines(effect_names, options) + missing_lines(options)
          GROUPS.map { |key, title| { :label => title, :lines => names.select { |name| line_kind(name) == key } } }.reject { |group| group[:lines].empty? }
        end

        # Tells the lines the item itself adds that its Special Effects lack, so a summary shows nothing
        # its details do not: the effect lines and the lines of the elements by its name of the item
        # read without gems, each once and never summed.
        #
        # @param options [Hash] :type_traits (false leaves out the traits of the item's type).
        # @return [Array<String>] The lines, with the game's escape codes.
        def missing_lines(options = {})
          return [] unless @item

          bare = EquipInfo.of(@item, [])
          shown = effect_names.map { |line| compared(line) }
          shown += EquipInfo.type_traits(@item).map { |line| compared(line) } if options[:type_traits] == false
          (bare.effect_texts + bare.element_lines).reject { |line| shown.include?(compared(line)) }.uniq { |line| compared(line) }
        end

        # Tells the group one of the item's own lines goes in.
        #
        # @param line [String] The line.
        # @return [Symbol] :attack, :defense or :other, :other for a line of no feature.
        def line_kind(line)
          @kinds.fetch(compared(line), :other)
        end

        # Tells the traits the item has by its weapon or armor type: its type's normal attack, then the
        # lines of EquipInfo.type_traits that the item shows among its Special Effects. A line whose
        # value the item changes is its own.
        #
        # @return [Array<String>] The lines, empty for none.
        def type_traits
          formula, lines = EquipInfo.type_parts(@item)
          own = effect_names.map { |line| compared(line) }
          [formula].compact + lines.select { |line| own.include?(compared(line)) }
        end

        # Tells each socket's gem with what the game's info page shows of it.
        #
        # @return [Array<Hash, nil>] Per socket nil for an empty one, else :gem, :description (without
        #   the gem's tag) and :info (an EquipInfo of the gem).
        def gems
          @gem_list.map do |gem|
            next nil unless gem

            { :gem => gem, :description => untagged(gem.description.to_s), :info => EquipInfo.of_gem(gem) }
          end
        end

        # Tells the steps of a set as Lines takes them: a group per step with the pieces it needs as
        # its label, faint while the character has not reached it.
        #
        # @param set [Hash] The set, see sets.
        # @return [Array<Hash>] The groups.
        def set_line_groups(set)
          set[:steps].map { |step| { :label => format(PIECES_TEXT, step[:pieces]), :faint => !step[:reached], :lines => step[:lines] } }
        end

        # Tells the sets the item belongs to, as the game's set page shows them.
        #
        # @param actor [Game_Actor, nil] The character whose worn pieces count, nil for none.
        # @return [Array<Hash>] Each :name, :size, :worn and :steps, each step :pieces, :lines and
        #   :reached, only the steps that have lines.
        def sets(actor)
          worn = actor && actor.respond_to?(:set_effect_count) ? actor.set_effect_count : {}
          sets_of_item.map do |effect|
            count = worn.fetch(effect, 0).to_i
            steps = (1..effect.size).map { |pieces| { :pieces => pieces, :lines => Array(effect[pieces].enchant_names), :reached => count >= pieces } }
            { :name => effect.name.to_s, :size => effect.size, :worn => count, :steps => steps.reject { |step| step[:lines].empty? } }
          end
        end

        # Tells the effect lines as Lines takes them: each group with its heading as its label, the
        # lines shared with another item left out for one line that counts them, and with :actor a
        # gold line per set with its bonuses as the tooltip.
        #
        # @param options [Hash] :shared (lines another item has too), :actor (the character whose worn
        #   pieces count), :type_traits (false leaves out the lines of #type_traits).
        # @return [Array] The groups, then the lines of no group.
        def effect_lines(options = {})
          shared = Array(options[:shared])
          common = []
          groups = effect_groups.map do |_key, title, lines|
            lines = own_lines(lines, options)
            own = lines.reject { |line| shared.include?(line) }
            common.concat(lines - own)
            own.empty? ? nil : { :label => title, :lines => own }
          end.compact
          unless common.empty?
            groups << { :text => UI.counted(common.size, *SHARED_WORDS), :color => :dim, :tooltip => common.map { |line| EquipInfo.plain(line) }.join("\n"),
                        :own_row => true }
          end
          groups + (options.key?(:actor) ? set_lines(options[:actor]) : [])
        end

        # Tells a gold line per set, with how many pieces the character wears and its bonuses as the
        # tooltip, a step a line.
        #
        # @param actor [Game_Actor, nil] The character.
        # @return [Array<Hash>] The lines.
        def set_lines(actor)
          sets(actor).map do |set|
            bonuses = set[:steps].map { |step| "#{format(PIECES_TEXT, step[:pieces])}: #{step[:lines].map { |line| EquipInfo.plain(line) }.join(', ')}" }
            { :text => "#{set[:name]}  #{set[:worn]}/#{set[:size]}", :color => :gold, :tooltip => bonuses.join("\n") }
          end
        end

        private

        # Reads a parameter of an item or an armor.
        #
        # @param part [RPG::BaseItem] The item or the armor.
        # @param id [Integer] The parameter.
        # @return [Integer] Its value, 0 for none.
        def part_param(part, id)
          part.respond_to?(:params) ? part.params[id].to_i : 0
        end

        # Tells the item's sets.
        #
        # @return [Array] The game's set effects, empty for none.
        def sets_of_item
          @item && @item.respond_to?(:set_effects) ? Array(@item.set_effects) : []
        end

        # Tells an element with its name and icon.
        #
        # @param id [Integer] The element.
        # @return [Hash] :id, :name and :icon.
        def element_of(id)
          { :id => id, :name => Game.element_name(id), :icon => Game.element_icon(id) }
        end

        # Reads the features of the item or of one of its gems' armors.
        #
        # The game turns a weapon's hit rate into the extra hit feature, which it averages as the base
        # hit instead of adding it, so that one is kept apart from the bonuses.
        #
        # @param part [RPG::BaseItem] The item or the armor.
        def read(part)
          EquipInfo.features_of(part).each do |feature|
            case feature.code
            when code(:PARAM) then @factors[feature.data_id] = (@factors[feature.data_id] || 1.0) * feature.value
            when code(:XPARAM_EX) then feature.data_id == 0 ? @hit_base = feature.value.to_f : add_rate(feature)
            when code(:XPARAM) then add_rate(feature)
            when code(:ATK_ELEMENT) then @elements << feature.data_id if STRIKE_ELEMENTS.include?(feature.data_id) && !@elements.include?(feature.data_id)
            end
          end
        end

        # Adds an extra parameter's bonus to its rate cell.
        #
        # @param feature [RPG::BaseItem::Feature] The feature.
        def add_rate(feature)
          @rates[feature.data_id] = (@rates[feature.data_id] || 0) + feature.value * 100 if RATE_NAMES[feature.data_id]
        end

        # Sorts the effect lines of the item or an armor into their groups, as the game names them.
        #
        # The game's lines come from get_enchant_names, which a plugin replaces and which also adds the
        # lines of no feature at the end of each call, so they are taken once and cut from the others.
        # Hand-written lines replace every computed line of their group, as the game shows them.
        #
        # @param part [RPG::BaseItem] The item or the armor.
        def read_lines(part)
          return unless part.respond_to?(:get_enchant_names)

          loose = part.get_enchant_names([])
          kept = EquipInfo.features_of(part)
          groups = part.respond_to?(:enchant_item?) && part.enchant_item? ? kept.group_by { |feature| feature.enchant_id }.values : [kept]
          groups.each do |features|
            features.each { |feature| @stat_lines.concat(without(part.get_enchant_names([feature]), loose)) if codes(STAT_CODES).include?(feature.code) }
            if features.any? { |feature| feature.code == code(:DUMMY_ENCHANT) }
              @lines[:other].concat(without(part.get_enchant_names(features), loose))
              loose = [] if groups.size == 1
              next
            end
            features.sort_by { |feature| [-feature.priority, feature.code, feature.data_id] }.each do |feature|
              names = without(part.get_enchant_names([feature]), loose)
              note_kinds(part, names, group_of(feature.code))
              next @element_lines.concat(names) if named_element?(feature)
              next if codes(STAT_CODES).include?(feature.code)

              @lines[group_of(feature.code)].concat(names)
            end
          end
          @lines[:other].concat(loose)
        end

        # Notes the group of the item's own lines, which its Special Effects are sorted into.
        #
        # @param part [RPG::BaseItem] The item or an armor of its gems.
        # @param names [Array<String>] The lines of one feature.
        # @param kind [Symbol] Their group.
        def note_kinds(part, names, kind)
          names.each { |name| @kinds[compared(name)] = kind } if part.equal?(@item)
        end

        # Tells the first line of the description of the item or the gem read alone, without its
        # gem tag and the game's codes.
        #
        # @return [String] The line, empty for none.
        def first_description_line
          source = @item || @gem
          return "" unless source && source.respond_to?(:description)

          text = source.description.to_s
          line = (@item ? text : untagged(text)).split(/\r?\n/).find { |each| !each.strip.empty? }
          EquipInfo.plain(line).strip
        end

        # Takes the gem's tag off the start of a gem's description, see EquipInfo.untagged.
        #
        # @param text [String] The description.
        # @return [String] The description without the tag.
        def untagged(text)
          EquipInfo.untagged(text)
        end

        # Tells whether a feature is an element shown by the item's name, whose line is left out.
        #
        # @param feature [RPG::BaseItem::Feature] The feature.
        # @return [Boolean] Whether it is.
        def named_element?(feature)
          feature.code == code(:ATK_ELEMENT) && @named.include?(feature.data_id)
        end

        # Leaves out the hand-written lines that only repeat what a cell shows.
        def drop_repeated_lines
          repeated = @stat_lines.map { |line| compared(line) }
          @lines[:other].reject! { |line| repeated.include?(compared(line)) }
        end

        protected

        # @return [Array<String>] The lines of the elements shown by the name, see name_elements.
        attr_reader :element_lines

        private

        # Tells a line as two lines are compared, see EquipInfo.compared.
        #
        # @param line [String] The line.
        # @return [String] The line compared.
        def compared(line)
          EquipInfo.compared(line)
        end

        # Leaves out of lines those of #type_traits when told to.
        #
        # @param lines [Array<String>] The lines.
        # @param options [Hash] :type_traits (false leaves them out).
        # @return [Array<String>] The lines kept.
        def own_lines(lines, options)
          return lines unless options[:type_traits] == false

          innate = type_traits.map { |line| compared(line) }
          lines.reject { |line| innate.include?(compared(line)) }
        end

        # Cuts the lines of no feature from the end of a call's lines.
        #
        # @param names [Array<String>] The lines.
        # @param loose [Array<String>] The lines of no feature.
        # @return [Array<String>] The lines without them.
        def without(names, loose)
          !loose.empty? && names.last(loose.size) == loose ? names[0, names.size - loose.size] : names
        end

        # Tells the group a feature's line goes in.
        #
        # @param feature_code [Integer] The feature's code.
        # @return [Symbol] :attack, :defense or :other.
        def group_of(feature_code)
          return :attack if codes(ATTACK_CODES).include?(feature_code)

          codes(DEFENSE_CODES).include?(feature_code) ? :defense : :other
        end

        # Finds a feature code of the game by its name.
        #
        # @param name [Symbol] The name after FEATURE_, such as :PARAM.
        # @return [Integer, nil] The code, nil in a game without it.
        def code(name)
          constant = "FEATURE_#{name}"
          defined?(::NWFeature) && ::NWFeature.const_defined?(constant) ? ::NWFeature.const_get(constant) : nil
        end

        # Finds feature codes of the game by their names.
        #
        # @param names [Array<Symbol>] The names.
        # @return [Array<Integer>] The codes the game has.
        def codes(names)
          names.map { |name| code(name) }.compact
        end
      end
    end
  end
end
