#----------------------------------------------------------------
#  equip_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Gave the characters no states, which the Equipment Window reads for its stats
#      Paulinchen  2026-11-07: Gave the party its fighting members, every member
#      Paulinchen  2026-11-04: Took in the Equipment Window's characters and party from the fixtures' script
#                            - Created
#
#----------------------------------------------------------------

# The game's items, gems and bag as the framework's equipment readers take them, for the tests of
# game.rbx and the flows that open the Equipment Window: the feature codes, the terms, the
# constants of the status screen, the database classes, items with their effect lines, sockets and
# gems, the party's bag of gems, and the party the window shows.

require_relative "tree_support"

# The game's feature codes, as NWFeature names them.
module NWFeature
  FEATURE_ELEMENT_RATE = 11
  FEATURE_PARAM = 21
  FEATURE_XPARAM = 22
  FEATURE_ATK_ELEMENT = 31
  FEATURE_ATK_STATE = 32
  FEATURE_XPARAM_EX = 66
  FEATURE_DUMMY_ENCHANT = 70
end

# The game's terms.
module Vocab
  # Tells a parameter's name.
  #
  # @param id [Integer] The parameter.
  # @return [String] The name.
  def self.param(id)
    ["Max HP", "Max MP", "Attack", "Defense", "Magic", "Willpower", "Agility", "Dexterity"][id]
  end

  # Tells a parameter's short name by its place in the compare order.
  #
  # @param place [Integer] The place.
  # @return [String] The name.
  def self.params_a(place)
    ["ATK", "DEF", "MAG", "WIL", "AGI", "DEX", "HP", "MP"][place]
  end
end

# The game's constants of the status screen.
module NWConst
  # The icons of the elements.
  module Status
    ELEMENT_RESIST = [3, 4, 5]
    ELEMENT_ICONS = [96, 97, 98]
    ADD_ELEMENT_RESIST = [6]
    ADD_ELEMENT_ICONS = [99]
  end

  # The formulas of each weapon type's normal attack.
  module Parameter
    WEAPON_TYPE_DAMAGE = { 1 => "(a.atk + a.luk) * 1.2", 4 => "a.atk * 2.5", 9 => "a.atk * a.level" }
  end
end

# The game's database classes the reader tells apart.
module RPG
  # A weapon.
  class Weapon; end

  # An item, such as a gem.
  class Item; end
end

# A feature of an item.
Feature = Struct.new(:code, :data_id, :value, :priority, :enchant_id)

# The value of a template's feature, which the game works out for each copy of the item and which
# no line of the game can name.
class Enchant_Value; end

# An item of the game with what the reader asks of it, its effect lines named as the game names them.
class FakeItem < RPG::Weapon
  attr_accessor :name, :icon_index, :params, :features, :display_color, :socket_num, :stones, :favorite, :etype_id, :enchant_stone_id,
                :enchant_stone_category, :description

  # Makes an item.
  #
  # @param name [String] Its name.
  # @param options [Hash] Its other values.
  def initialize(name, options = {})
    @name = name
    @icon_index = options[:icon] || 1
    @params = options[:params] || [0] * 8
    @features = options[:features] || []
    @display_color = options[:color] || 0
    @socket_num = options[:sockets] || 0
    @stones = options[:stones] || []
    @favorite = options[:favorite]
    @etype_id = 0
    @enchant_stone_id = options[:armors]
    @enchant_stone_category = options[:category]
    @description = options[:description].to_s
  end

  # @return [String] The name the menus show.
  def display_name
    @name
  end

  # @return [Boolean] Whether the party marked it.
  def favorite?
    @favorite ? true : false
  end

  # @return [Boolean] Whether it has sockets.
  def socket?
    @socket_num > 0
  end

  # @return [String] The line of its sockets.
  def socket_name
    "Sockets:#{@socket_num}"
  end

  # @return [Array] No sets.
  def set_effects
    []
  end

  # @return [Array<String>] Its effect lines, after the line of its sockets.
  def enchant_names
    (socket? ? [socket_name] : []) + get_enchant_names(@features)
  end

  # Names the effect lines of features as the game does, hand-written lines replacing the others.
  #
  # @param features [Array<Feature>] The features.
  # @return [Array<String>] The lines.
  def get_enchant_names(features)
    dummy = nil
    names = []
    features.sort_by { |feature| [-feature.priority, feature.code, feature.data_id] }.each do |feature|
      case feature.code
      when NWFeature::FEATURE_DUMMY_ENCHANT then (dummy ||= []).concat(feature.value.split("\\n"))
      when NWFeature::FEATURE_PARAM then names << "#{Vocab.param(feature.data_id)} +#{((feature.value - 1) * 100).round}%"
      when NWFeature::FEATURE_XPARAM then names << "Critical Rate #{(feature.value * 100).round}%"
      when NWFeature::FEATURE_ATK_ELEMENT then names << "#{$data_system.elements[feature.data_id]} Strike"
      when NWFeature::FEATURE_ATK_STATE then names << "Poison Strike +#{(feature.value * 100).round}%"
      when NWFeature::FEATURE_ELEMENT_RATE then names << "#{$data_system.elements[feature.data_id]} Resist #{100 - (feature.value * 100).round}%"
      end
    end
    dummy || names
  end
end

# A weapon of a type, whose lines of no feature the game adds after the lines of every call.
class FakeWeapon < FakeItem
  attr_accessor :wtype_id

  # Makes a weapon of a type.
  #
  # @param name [String] Its name.
  # @param wtype_id [Integer] Its type.
  # @param options [Hash] Its other values and :loose, its lines of no feature.
  def initialize(name, wtype_id, options = {})
    super(name, options)
    @wtype_id = wtype_id
    @loose = options[:loose] || []
  end

  # Names the effect lines of features, then its lines of no feature.
  #
  # @param features [Array<Feature>] The features.
  # @return [Array<String>] The lines.
  def get_enchant_names(features)
    super + @loose
  end
end

# An armor of a type.
class FakeArmor < FakeItem
  attr_accessor :atype_id

  # Makes an armor of a type.
  #
  # @param name [String] Its name.
  # @param atype_id [Integer] Its type.
  # @param options [Hash] Its other values.
  def initialize(name, atype_id, options = {})
    super(name, options)
    @atype_id = atype_id
  end
end

# A gem of the bag, as the game's gem list takes it.
class FakeGem < RPG::Item
  attr_accessor :name, :icon_index, :enchant_stone_category, :enchant_stone_id, :description, :id

  # Makes a gem.
  #
  # @param name [String] Its name.
  # @param id [Integer] Its id.
  # @param category [Symbol, nil] Its category, of which an item holds one.
  def initialize(name, id, category)
    @name = name
    @id = id
    @icon_index = 300 + id
    @enchant_stone_category = category
    @enchant_stone_id = []
    @description = ""
  end

  # @return [Boolean] Always true.
  def enchant_stone?
    true
  end
end

# A worn item with sockets whose gems change as the game's RPG::Uniq_Item#change_stone changes
# them, the gem itself in each socket instead of its id.
class FakeSocketed < FakeItem
  # Puts a gem into a socket, or nil to empty it, as the game does.
  #
  # @param slot_id [Integer] The socket.
  # @param item [FakeGem, nil] The gem.
  def change_stone(slot_id, item)
    return if slot_id >= socket_num
    return unless $game_party.trade_item(item, stones[slot_id])

    if item
      stones.each.with_index do |stone, index|
        change_stone(index, nil) if stone && index != slot_id && stone.enchant_stone_category == item.enchant_stone_category
      end
    end
    @stones[slot_id] = item
  end

  # Empties every socket, as the game does.
  def clear_stones
    socket_num.times { |place| change_stone(place, nil) }
  end
end

# The party's bag as the game's gem screens use it.
class FakeParty
  # @return [Boolean] Whether trade_item refuses the next trade, as when the bag lost the gem.
  attr_accessor :refuse

  # Makes the bag.
  #
  # @param counts [Hash{Object => Integer}] How many of each item it holds, in its order.
  def initialize(counts)
    @counts = counts
  end

  # @return [Array] The items it holds, in its order.
  def all_items
    @counts.keys.select { |item| @counts[item] > 0 }
  end

  # @return [Integer] How many of an item it holds.
  def item_number(item)
    @counts[item].to_i
  end

  # @return [Boolean] Whether it holds an item.
  def has_item?(item)
    item_number(item) > 0
  end

  # Trades an item of the bag for another, as the game's Game_Party#trade_item does.
  #
  # @param new_item [Object, nil] The item that leaves the bag.
  # @param old_item [Object, nil] The item that comes in.
  # @return [Boolean] Whether it traded.
  def trade_item(new_item, old_item)
    return false if @refuse || (new_item && !has_item?(new_item))

    @counts[old_item] = item_number(old_item) + 1 if old_item
    @counts[new_item] = item_number(new_item) - 1 if new_item
    true
  end

  # Runs a block on an item that has sockets of its own; a worn one has them already.
  #
  # @param item [FakeSocketed] The item.
  # @return [FakeSocketed] The item.
  def create_socket_item(item)
    yield item
    restore_socket_item(item)
  end

  # Hands back a worn item as it is.
  #
  # @param item [FakeSocketed] The item.
  # @return [FakeSocketed] The item.
  def restore_socket_item(item)
    item
  end
end

# The game's system data: the elements and the window color.
SystemData = Struct.new(:elements, :window_tone)

# A character of the Equipment Window: a weapon with two sockets in the right hand, nothing in the
# left hand and the accessory.
class FakeHero
  attr_reader :name, :level, :equips, :id

  # Makes a character.
  #
  # @param id [Integer] Its id.
  # @param name [String] Its name.
  # @param equips [Array] Its items by slot.
  def initialize(id, name, equips)
    @id = id
    @name = name
    @level = 300
    @equips = equips
  end

  # @return [Array<Integer>] The kinds of its slots.
  def equip_slots
    [0, 1, 4]
  end

  # @return [String] A slot's name.
  def slot_name(slot)
    ["Right Hand", "Left Hand", "Accessory"][slot]
  end

  # @return [Boolean] Whether a slot's item can change.
  def equip_change_ok?(_slot)
    true
  end

  # @return [Integer] A parameter.
  def param(id)
    [1200, 80, 330, 200, 150, 120, 90, 60][id]
  end

  # @return [Float] The hit rate.
  def hit
    0.95
  end

  # @return [Float] The critical rate.
  def cri
    0.05
  end

  # @return [Array] No states.
  def states
    []
  end

  # @return [String] No face.
  def face_name
    ""
  end

  # @return [Integer] The face's place.
  def face_index
    0
  end
end

# The party as the Equipment Window steps through it: its members and the menu's character.
class FakeMenuParty < FakeParty
  attr_accessor :menu_actor

  # Makes the party.
  #
  # @param members [Array<FakeHero>] Its members.
  def initialize(members)
    super({})
    @members = members
    @menu_actor = members[0]
  end

  # @return [Array<FakeHero>] Its members.
  attr_reader :members

  # @return [Array<FakeHero>] Its fighting members: every member.
  def battle_members
    @members
  end

  # Steps to the next character.
  def menu_actor_next
    @menu_actor = @members[(@members.index(@menu_actor) + 1) % @members.size]
  end

  # Steps to the previous character.
  def menu_actor_prev
    @menu_actor = @members[(@members.index(@menu_actor) - 1) % @members.size]
  end

  # @return [Array] No items in the bag to equip.
  def equip_items
    []
  end
end

# Makes the party the Equipment Window sample shows: Luka with a socketed sword whose first socket
# holds a ruby, and Alice with nothing worn; Luka is the menu's character.
#
# @return [FakeHero] Luka.
def equip_party
  $data_system = SystemData.new(["", "Physical", "Slash", "Fire"], Tone.new)
  def $data_system.weapon_types; ["", "Sword"]; end
  def $data_system.armor_types; ["", "Shield"]; end
  ruby = FakeItem.new("Ruby", :icon => 300, :armors => [10], :category => :red, :description => "A red gem.")
  $data_armors = [nil] * 10 + [FakeItem.new("Ruby armor", :params => [0, 0, 120, 0, 0, 0, 0, 0])]
  sword = FakeSocketed.new("Zantetsuken", :icon => 400, :sockets => 2, :stones => [ruby, nil], :params => [0, 0, 300, 0, 0, 0, 0, 0],
                           :features => [Feature.new(31, 2, 1, 0, -1)])
  def sword.wtype_id; 1; end
  hero = FakeHero.new(1, "Luka", [sword, nil, nil])
  $game_party = FakeMenuParty.new([hero, FakeHero.new(2, "Alice", [nil, nil, nil])])
  hero
end
