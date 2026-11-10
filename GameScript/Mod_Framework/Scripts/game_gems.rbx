#----------------------------------------------------------------
#  game_gems.rbx
#
#  Changelog:
#      Paulinchen  2026-11-10: Read the bag's gems from its items alone
#      Paulinchen  2026-11-09: Removed setting, taking out and clearing gems, which the Equipment Window does itself
#      Paulinchen  2026-11-07: Named the color helper color_filters, as chips no longer filter
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Tells what the game lets a mod change of the gems in an item's sockets and what a change
      # would do, without changing anything; it keeps no rule of its own. The game takes any gem of the bag into any socket, one gem of a kind
      # per item (a gem pushes another socket's gem of its category out), a gem taken out or pushed
      # out goes back to the bag, and an item a character wears in a fixed slot keeps its gems.
      module Gems
        # The notes describe writes of what a change does, by what it says.
        TEXTS = { :empty => "This socket is empty", :already => "Already in this socket", :back_to_bag => "%s back to the bag",
                  :back_verbs => ["goes", "go"], :moves => "Moves from socket %d", :moves_back => "Moves from socket %d, %s",
                  :one_per_color => "One gem per color: socket %d empties; %s", :its_gem_back => "its gem goes back to the bag",
                  :both_back => "both gems go back to the bag", :into => "Goes into socket %d" }

        # The row of a gem list that empties a socket.
        REMOVE_ROW_TEXT = "Remove gem"

        # The row of a gem list while the bag holds no gem, and while every gem of the bag is of a
        # color another socket holds.
        NO_GEMS_TEXT = "No gems in the bag"
        ALL_TAKEN_TEXT = "Other sockets hold every color of the bag"

        # The tooltips of a color's filter while another socket holds that color, and while no gem of
        # the bag has it.
        TAKEN_COLOR_TEXT = "%s: another socket holds one"
        MISSING_COLOR_TEXT = "%s: none in the bag"

        # Why a change is refused, by what is wrong.
        NO_ITEM_TEXT = "Nothing equipped"
        NO_SOCKETS_TEXT = "%s has no sockets"
        NO_SOCKET_TEXT = "%s has no socket %d"
        NOT_A_GEM_TEXT = "%s is not a gem"
        NOT_IN_BAG_TEXT = "No %s in the bag"
        EMPTY_TEXT = "Socket %d is empty"
        FIXED_TEXT = "%s cannot change its gems"

        # The names of the gems' colors by their icon, in the order of the game's gem categories,
        # whose gems each share one icon.
        COLORS = [[3473, "Red"], [3479, "Blue"], [3476, "Green"], [3474, "Pink"], [3475, "Yellow"]]

        # The name of a color COLORS does not know.
        OTHER_COLOR = "Other"

        # Tells a gem's color, as its icon shows it.
        #
        # @param gem [RPG::Item] The gem.
        # @return [Integer] Its icon.
        def self.color(gem)
          gem.icon_index
        end

        # Tells the colors of some gems, each once, in the order of COLORS, then in the gems' order.
        #
        # @param gems [Array<RPG::Item>] The gems, such as the bag's.
        # @return [Array<Integer>] Their icons.
        def self.colors(gems)
          known = COLORS.map { |icon, _name| icon }
          found = gems.map { |gem| color(gem) }.uniq
          found.sort_by { |icon| [known.index(icon) || known.size, found.index(icon)] }
        end

        # Tells the name of a color.
        #
        # @param icon [Integer] The color's icon.
        # @return [String] Its name, such as "Red"; OTHER_COLOR for one COLORS does not know.
        def self.color_name(icon)
          found = COLORS.find { |known, _name| known == icon }
          found ? found[1] : OTHER_COLOR
        end

        # Tells the gems the game offers for its sockets: those in the bag, in its order; the
        # storehouse's are not offered.
        #
        # Gems are items, so the weapons and armors stay unread, which a late-game bag holds
        # thousands of.
        #
        # @return [Array<RPG::Item>] The gems.
        def self.bag
          $game_party ? $game_party.items.select { |item| gem?(item) } : []
        end

        # Tells whether an item is a gem, as the game's gem list takes it.
        #
        # @param item [RPG::BaseItem, nil] The item.
        # @return [Boolean] Whether it is.
        def self.gem?(item)
          defined?(::RPG::Item) && item.is_a?(::RPG::Item) && item.respond_to?(:enchant_stone?) && item.enchant_stone? ? true : false
        end

        # Tells whether the gems of a character's slot may change, as the game's equip screen lets its
        # gem screen open: the slot holds an item with sockets and is not fixed.
        #
        # @param actor [Game_Actor] The character.
        # @param slot [Integer] The slot.
        # @return [Boolean] Whether they may.
        def self.changeable?(actor, slot)
          item = actor.equips[slot]
          item && item.respond_to?(:stones) && item.stones.size > 0 && actor.equip_change_ok?(slot) ? true : false
        end

        # Tells why the game would refuse a gem in a socket, or emptying it: a character wears the
        # item in a fixed slot, the item has no such socket, the gem is none or is not in the bag, or
        # the socket to empty is empty.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @param gem [RPG::Item, nil] The gem, nil to empty the socket.
        # @param options [Hash] :actor and :slot, the character's slot the item lies in, which the
        #   game's equip screen asks too, since an item without gems cannot tell its slot.
        # @return [String, nil] Why, nil when the game takes it.
        def self.refusal(item, socket, gem, options = {})
          return NO_ITEM_TEXT unless item

          gems = EquipInfo.gems_of(item)
          name = Game.item_name(item)
          return format(FIXED_TEXT, name) unless unfixed?(item) && slot_unfixed?(options)
          return format(NO_SOCKETS_TEXT, name) if gems.empty?
          return format(NO_SOCKET_TEXT, name, socket + 1) unless socket >= 0 && socket < gems.size
          return gems[socket] ? nil : format(EMPTY_TEXT, socket + 1) unless gem
          return format(NOT_A_GEM_TEXT, Game.item_name(gem)) unless gem?(gem)

          $game_party.has_item?(gem) ? nil : format(NOT_IN_BAG_TEXT, Game.item_name(gem))
        end

        # Tells what putting a gem into a socket, or emptying it, would do, without doing it.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @param gem [RPG::Item, nil] The gem, nil to empty the socket.
        # @return [Hash] :socket, :old (the socket's gem now), :gem, :moved_from (the socket the same
        #   gem leaves, nil for none), :pushed (each [socket, gem] the one gem of a kind rule sends back
        #   to the bag), :emptied (the sockets it empties), :changed (every socket it changes)
        #   and :unchanged (:already for the gem the socket holds, :empty to empty an empty socket, else
        #   nil).
        def self.preview(item, socket, gem)
          old = EquipInfo.gems_of(item)[socket]
          found = { :socket => socket, :old => old, :gem => gem, :moved_from => nil, :pushed => [], :emptied => [], :changed => [], :unchanged => nil }
          return found.merge(old ? { :emptied => [socket], :changed => [socket] } : { :unchanged => :empty }) unless gem
          return found.merge(:unchanged => :already) if old && same_gem?(old, gem)

          moved = EquipInfo.gems_after_set(item, socket, gem)[1]
          same = moved.find { |_place, other| same_gem?(other, gem) }
          emptied = moved.map { |place, _gem| place }
          found.merge(:moved_from => same && same[0], :pushed => moved.reject { |_place, other| same_gem?(other, gem) }, :emptied => emptied,
                      :changed => [socket] + emptied)
        end

        # Writes what a preview tells as a note and its color: that nothing changes, where the gem
        # moves from, which socket the one gem of a kind rule empties, which gem goes back to the bag,
        # or the socket the gem goes into, unless :into is nil.
        #
        # @param preview [Hash] The preview, see preview.
        # @param texts [Hash] Texts of TEXTS to word it otherwise.
        # @return [Array, nil] The note and its color, nil for none.
        def self.describe(preview, texts = {})
          texts = TEXTS.merge(texts)
          old = preview[:old]
          return [texts[:empty], :dim] if preview[:unchanged] == :empty
          return [texts[:already], :dim] if preview[:unchanged] == :already
          return [back_to_bag(old, texts), :dim] unless preview[:gem]

          from = preview[:moved_from]
          return [old ? format(texts[:moves_back], from + 1, back_to_bag(old, texts)) : format(texts[:moves], from + 1), :system] if from
          return [format(texts[:one_per_color], preview[:pushed][0][0] + 1, old ? texts[:both_back] : texts[:its_gem_back]), :warn] unless preview[:pushed].empty?
          return [back_to_bag(old, texts), :dim] if old

          texts[:into] ? [format(texts[:into], preview[:socket] + 1), :dim] : nil
        end

        # Tells whether a gem in a socket would push another socket's gem out, by the one gem of a
        # kind rule, so that the change is not this socket's alone.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @param gem [RPG::Item] The gem.
        # @return [Boolean] Whether it would.
        def self.pushes_out?(item, socket, gem)
          !EquipInfo.gems_after_set(item, socket, gem)[1].empty?
        end

        # Tells the colors the gems of an item's other sockets have, which a gem in this socket
        # would push out.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @return [Array<Integer>] Their icons, each once.
        def self.taken_colors(item, socket)
          EquipInfo.gems_of(item).each_with_index.select { |gem, place| gem && place != socket }.map { |gem, _place| color(gem) }.uniq
        end

        # Tells the gems of the bag as rows of a List, as a gem list shows them: each gem in the game's
        # order and color, what it adds in short as its note, its count, found by its name, with its
        # kinds as :kinds; first a row that empties a socket, and a dim row while the
        # bag holds none. With :item and :socket only the gems that go into that socket without
        # pushing another socket's gem out (pushes_out?), and a dim row when that leaves none. A gem
        # row's :data is its gem, the remove row's Game::REMOVE.
        #
        # @param options [Hash] :remove_text (REMOVE_ROW_TEXT; nil leaves the row out),
        #   :remove_disabled (true greys it, such as while the socket is empty), :empty_text
        #   (NO_GEMS_TEXT), :item, :socket and :all_taken_text (ALL_TAKEN_TEXT).
        # @return [Array<Hash>] The rows.
        def self.rows(options = {})
          remove = options.fetch(:remove_text, REMOVE_ROW_TEXT)
          rows = []
          unless remove.nil?
            rows << { :text => remove.to_s, :icon => Game.empty_socket_icon, :color => :system, :remove => true, :search => false,
                      :disabled => options[:remove_disabled] ? true : false, :data => Game::REMOVE }
          end
          gems = bag
          return rows << { :text => options.fetch(:empty_text, NO_GEMS_TEXT).to_s, :color => :dim, :faint => true, :disabled => true, :search => false } if gems.empty?

          item = options[:item]
          gems = gems.reject { |gem| pushes_out?(item, options[:socket].to_i, gem) } if item
          return rows << { :text => options.fetch(:all_taken_text, ALL_TAKEN_TEXT).to_s, :color => :dim, :faint => true, :disabled => true, :search => false } if gems.empty?

          gems.each do |gem|
            info = EquipInfo.of_gem(gem)
            rows << { :item => gem, :bag => true, :count => true, :note => info.brief, :data => gem, :kinds => info.kinds }
          end
          rows
        end

        # Tells a filter per color of some gems, in the order of colors, such as for the toggles that
        # filter a gem list. With :every_color each color of COLORS and of :taken has a filter too, so
        # a filter keeps its place, disabled while no gem has its color; a color of :taken has a
        # disabled filter.
        #
        # @param gems [Array<RPG::Item>] The gems, such as the bag's.
        # @param options [Hash] :tooltip (a filter's tooltip by the color's name, "%s" unless given),
        #   :every_color (false), :taken (colors whose filters are disabled, such as taken_colors),
        #   :taken_tooltip (TAKEN_COLOR_TEXT) and :missing_tooltip (MISSING_COLOR_TEXT).
        # @return [Array<Hash>] Each color's :icon, :value (its icon), :tooltip and :disabled.
        def self.color_filters(gems, options = {})
          found = colors(gems)
          taken = Array(options[:taken])
          shown = options[:every_color] ? (COLORS.map { |icon, _name| icon } + found + taken).uniq : found
          shown.map do |icon|
            tip = taken.include?(icon) ? options.fetch(:taken_tooltip, TAKEN_COLOR_TEXT) : found.include?(icon) ? options.fetch(:tooltip, "%s") : options.fetch(:missing_tooltip, MISSING_COLOR_TEXT)
            { :icon => icon, :value => icon, :tooltip => format(tip, color_name(icon)), :disabled => !found.include?(icon) || taken.include?(icon) }
          end
        end

        # Tells the sockets of an item that hold a gem.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [Array<Integer>] The sockets, from 0.
        def self.filled(item)
          EquipInfo.gems_of(item).each_with_index.select { |gem, _place| gem }.map { |_gem, place| place }
        end

        # Tells how many of an item's sockets hold a gem, of how many.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @return [String] Such as "3/10".
        def self.filled_text(item)
          gems = EquipInfo.gems_of(item)
          "#{gems.compact.size}/#{gems.size}"
        end

        # Tells whether the game takes a gem in a socket.
        #
        # @param item [RPG::EquipItem, nil] The item.
        # @param socket [Integer] The socket, from 0.
        # @param gem [RPG::Item] The gem.
        # @param options [Hash] :actor and :slot, see refusal.
        # @return [Boolean] Whether it does, see refusal for why not.
        def self.fits?(item, socket, gem, options = {})
          !gem.nil? && refusal(item, socket, gem, options).nil?
        end

        # Tells whether two gems are the same gem of the database.
        #
        # @param one [RPG::Item] One gem.
        # @param other [RPG::Item] The other.
        # @return [Boolean] Whether they are.
        def self.same_gem?(one, other)
          one.equal?(other) || (one.class == other.class && one.respond_to?(:id) && one.id == other.id)
        end

        # Writes which gem goes back to the bag.
        #
        # @param gem [RPG::Item] The gem.
        # @param texts [Hash] The texts, see TEXTS.
        # @return [String] Such as "Ruby goes back to the bag".
        def self.back_to_bag(gem, texts)
          format(texts[:back_to_bag], UI.listed([Game.item_name(gem)], *texts[:back_verbs]))
        end
        private_class_method :back_to_bag

        # Tells whether the game lets an item's gems change, as its item-side gem list asks: not while
        # a character wears it in a fixed slot.
        #
        # @param item [RPG::EquipItem] The item.
        # @return [Boolean] Whether it does; true for an item that cannot tell.
        def self.unfixed?(item)
          !item.respond_to?(:change_ok?) || item.change_ok? ? true : false
        end

        # Tells whether a character's slot lets the gems of its item change, as the game's equip
        # screen asks before its gem screen opens.
        #
        # @param options [Hash] :actor and :slot; without both nothing is asked.
        # @return [Boolean] Whether it does.
        def self.slot_unfixed?(options)
          actor = options[:actor]
          slot = options[:slot]
          actor.nil? || slot.nil? || actor.equip_change_ok?(slot) ? true : false
        end
      end
    end
  end
end
