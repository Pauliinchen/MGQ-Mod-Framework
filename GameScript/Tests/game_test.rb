#----------------------------------------------------------------
#  game_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Removed the check of the engine list's text filter, which is gone
#      Paulinchen  2026-11-09: Covered a window showing an item's gem count, which renders again after a gem set
#                            - Moved the gem changes, the equip writer and the gem tooltips to the test of the Equipment Window
#                            - Walked the readers of UI::Equip over the sword with its ruby set against a worn blade
#      Paulinchen  2026-11-07: Read a gem's tooltip from the slots of UI::Equip and left the comparison to the test of UI::Equip
#                            - Greyed rows and choices with disabled:
#      Paulinchen  2026-11-06: Added the equip comparison without its add_ helper
#                            - Removed the set header
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Dropped the old gem and equip dialogs, which the UI layer replaces
#                            - Covered an item without gems kept in a fixed slot of a character
#      Paulinchen  2026-11-04: Kept a few flows of each equipment feature with a check per step that matters
#                            - Rewrote the checks as flow tests of the equipment readers, gems and their dialogs
#                            - Took the stand-ins of the game's items, gems and bag from equip_support
#                            - Noted where a text lands as it lines up in its box
#      Paulinchen  2026-10-31: Covered a template of random enchantments read by the features every copy has
#                            - Covered a squeezed text drawn as whole characters set closer
#                            - Covered the gem count of a folded side giving way within its column
#      Paulinchen  2026-10-29: Covered favorites, the type chips of items and the equip dialog with its Filter menu,
#                              its list in two columns, its steady comparison, its key help and the game's keys of
#                              favorites
#                            - Covered a line of its own for each empty socket, the gem rows and color chips for one
#                              socket and the gem dialog on one socket with its digits
#                            - Covered stats given another character
#                            - Covered a character's title, slots and equip rows, the equip writer, stats bound to a
#                              character, gem previews and their notes, the gem rows and chips, a gem read once, the
#                              worn item set against another, the gem comparison and the gem dialog
#                            - Covered the refused gem change on an item worn in a fixed slot, the pink gems and
#                              the plain lines of a gem
#                            - Covered the innate traits of a weapon or armor type
#                            - Covered the short note of what a gem adds, the gems after a set and changing gems
#                              through the game
#                            - Covered the kinds of what a gem adds and the colors of gems
#                            - Covered a squeezed text wider than the screen
#                            - Covered a character's stat rows, the gem lines, the set steps and a base hit rate judged
#                              against the rate every weapon has
#                            - Covered a weapon's base hit rate, an element without an icon and the effect lines for Lines
#                            - Dropped the party's changes
#                            - Covered the Special Effects by kind, the search text, paired cells, a summary in Lines and
#                              the item header, and dropped the effect headings from the gem tooltip
#                            - Covered a squeezed label that C# lets through too wide
#                            - Created
#
#----------------------------------------------------------------

# Covers game.rbx in a booted game against FakeTree, through what a player sees and does with
# equipment: stat rows, the cells and Lines of a weapon with a gem, the readers of UI::Equip over
# that weapon set against a worn one, the traits of a weapon type, why the game refuses a gem, slots
# and equip rows, bound stats, what a gem change would do and a window that follows a gem set.

require_relative "equip_support"

# A picture that notes the color each text was last drawn in.
class Bitmap
  # Notes a text drawn with its place and its color.
  def draw_text(x, y, width, _height, text, align = 0)
    @texts << [landing(x, width, text, align), y, text]
    (@colors ||= {})[text] = @font.color.to_a
  end

  # @return [Hash{String => Array}] The colors' values by text.
  def colors
    @colors || {}
  end
end

$sounds = []

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  fake.answer("ui.glyphs") { |_request| nil }
  fake.answer("ui.text.runs") { |_request| nil }
  # A C# that knows the font's widths narrower than the picture draws them lets every text through whole.
  fake.answer("ui.text.cut") { |request| request[2] + request[3].to_s }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    game = ui::Game
    gems = ui::Engine::Gems
    # The game's text colors by their index, told apart by their red.
    def ui.text_color(index)
      Color.new(index, 0, 0, 255)
    end
    $data_system = SystemData.new(["", "Physical", "Slash", "Fire", "Ice", "Thunder", "Holy"], Tone.new)
    ruby_armor = FakeItem.new("Ruby armor", :params => [0, 0, 120, 0, 0, 0, 0, 0],
                              :features => [Feature.new(21, 0, 1.1, 0, -1), Feature.new(22, 2, 0.3, 0, -1), Feature.new(70, 0, "\\c[0]Max HP +10%\\nCritical Rate +30%\\nBlessed", 0, -1)])
    $data_armors = [nil] * 10 + [ruby_armor]
    ruby = FakeItem.new("Ruby", :icon => 300, :armors => [10], :category => :red, :description => "【秘石】A red gem.")
    poison = Feature.new(32, 7, 0.1, 0, -1)
    fire_resist = Feature.new(11, 3, 0.8, 0, -1)
    slash = Feature.new(31, 2, 1, 0, -1)
    sword = FakeItem.new("Zantetsuken:Dawn", :icon => 400, :color => 23, :sockets => 3, :stones => [ruby, nil, nil],
                         :params => [1200, 0, 3000, 1500, 0, 0, 0, 0],
                         :features => [Feature.new(21, 0, 1.4, 0, -1), slash, Feature.new(31, 3, 1, 0, -1), Feature.new(31, 4, 1, 0, -1),
                                       Feature.new(31, 5, 1, 0, -1), Feature.new(31, 6, 1, 0, -1), poison, fire_resist])
    frame

    # A character's stats as rows, a big number told ever shorter.
    hero = Object.new
    def hero.param(id); [1200, 80, 330, 0, 0, 0, 0, 0][id]; end
    def hero.hit; 0.29; end
    def hero.cri; 0.57; end
    check("a character's stat rows hold the parameters asked for and each rate in whole percents",
          game.stat_rows(hero, :params => [2, 0]).map { |row| "#{row[:name]} #{row[:value]}" }, ["Attack 330", "Max HP 1200", "Hit 29%", "Critical 57%"])
    Integer.class_eval { def give_unit; abs < 1_000_000 ? to_s : format("%.3fMil.", self / 1_000_000.0); end }
    def hero.param(id); [0, 0, 953_492_000, 0, 0, 0, 0, 0][id]; end
    check("a big number carries ever shorter forms", game.stat_rows(hero, :params => [2], :rates => [])[0][:shorter], ["953.492Mil.", "953.49Mil.", "953.5Mil.", "953Mil."])
    Integer.send(:remove_method, :give_unit)

    # A tooltip and Lines read a weapon with a gem.
    info = ui::Engine::EquipInfo.of(sword)
    check("the bonuses of the weapon and its gem merge into cells, the attack elements with their icons",
          [*info.stat_cells.map { |cell| "#{cell[:name]} #{cell[:value]}" }, *info.attack_elements.map { |element| element[:icon] }],
          ["ATK +3120", "DEF +1500", "HP +1200 +54%", "Critical +30%", nil, 96, 97, 98, 99])
    check("the effect lines the cells and the name leave are grouped by kind", Hash[info.effect_groups.map { |kind, _label, lines| [kind, lines] }],
          { :attack => ["Slash Strike", "Holy Strike", "Poison Strike +10%"], :defense => ["Fire Resist 20%"], :other => ["Blessed"] })
    check("the game's Special Effects add what the item itself adds but not its gems",
          Hash[info.effect_name_groups.map { |group| [group[:label], group[:lines].size] }], { "Attack" => 6, "Defense" => 1, "Other" => 1 })
    tagged = ["[Самоцвет] Камень.", "A [Gem] inside."].map do |text|
      ui::Engine::EquipInfo.of(FakeItem.new("Holder", :sockets => 1, :stones => [FakeItem.new("Stone", :armors => [10], :description => text)])).gems[0][:description]
    end
    check("a gem's description loses its leading tag, also a translated one", tagged, ["Камень.", "A [Gem] inside."])
    lines = info.effect_lines(:shared => ["Holy Strike", "Blessed"])
    check("in Lines the shared effects fold into one line", lines.last[:text], "2 shared effects")
    info.set_line_groups(:steps => [{ :pieces => 2, :lines => ["ATK +5%"], :reached => true }, { :pieces => 4, :lines => ["DEF +5%"], :reached => false }])

    # A worn weapon set against the one picked moves its gems.
    moved_gems = ui::Engine::EquipInfo.gems_after_equip(FakeItem.new("Old", :sockets => 2, :stones => [ruby, FakeItem.new("Sapphire", :category => :blue)]),
                                                FakeItem.new("New", :sockets => 3, :stones => [nil, nil, FakeItem.new("Garnet", :category => :red)]))[0]
    check("an equip moves the worn gems into the same sockets, pushing out one of the same category", moved_gems.map { |gem| gem && gem.name }, ["Ruby", "Sapphire", nil])

    # A mod reads the sword with its ruby against a worn blade whose sapphire moves over, as a
    # comparison shows them: the sword's elements, its gems after the equip with where each comes
    # from, both sides' stats paired with the poison strike they share folded away, the tallest of a
    # list, and what the ruby adds.
    equip = ui::Equip
    sapphire = FakeItem.new("Sapphire", :category => :blue)
    old_blade = FakeItem.new("Old Blade", :sockets => 2, :stones => [nil, sapphire], :params => [0, 0, 1000, 0, 0, 0, 0, 0], :features => [poison])
    after = equip.gems_after(old_blade, sword)
    compared = equip.compare(old_blade, sword, :gems => after[:gems])
    check("the readers tell the sword's elements, its gems after the equip, the sapphire moving over and its note",
          [equip.elements(sword).map { |element| element[:name] }, after[:gems].map { |gem| gem && gem.name }, after[:worn_notes][1][0], after[:item_note][0]],
          [["Fire", "Ice", "Thunder"], ["Ruby", "Sapphire", nil], "Moves to Zantetsuken:Dawn", "+1 gem from the worn item"])
    check("both sides' stats pair up, the worn blade's missing ones as stand-ins, and the shared poison strike folds into one line",
          [compared[:item][0].map { |row| row[:value] }, compared[:worn][0].map { |row| row[:missing] ? nil : row[:value] },
           equip.effects(sword, :gems => after[:gems], :shared => compared[:shared]).last[:text]],
          [["+3120", "+1500", "+1200 +54%"], ["+1000", nil, nil], "1 shared effect"])
    ruby_info = equip.gem_info(ruby)
    check("the sword needs the most room of a list, and the ruby tells what it adds without the gem's tag",
          [equip.room([{ :item => old_blade }, { :item => sword }], old_blade).first.name, ruby_info[:lines], ruby_info[:description]],
          ["Zantetsuken:Dawn", ["ATK +120", "HP +10%", "Critical +30%", "Blessed"], "A red gem."])

    # The traits every item of a weapon or armor type shares.
    defense_down = "Sword Skills Add to Foes Defense Down 50%"
    claymore = FakeWeapon.new("Claymore", 4, :features => [Feature.new(21, 0, 1.1, 0, -1), slash, poison, fire_resist], :loose => [defense_down])
    zweihander = FakeWeapon.new("Zweihander", 4, :features => [fire_resist, poison, Feature.new(21, 0, 1.1, 0, -1), slash], :loose => ["Cursed", defense_down])
    flamberge = FakeWeapon.new("Flamberge", 4, :features => [slash, poison], :loose => [defense_down])
    bastard = FakeWeapon.new("Bastard Sword", 4, :features => [slash, Feature.new(32, 7, 0.3, 0, -1), fire_resist], :loose => [defense_down])
    knife = FakeWeapon.new("Knife", 1, :features => [poison])
    $data_weapons = [nil, claymore, zweihander, flamberge, bastard, FakeWeapon.new("", 4), knife, FakeWeapon.new("Odd", 9, :features => [poison])]
    $data_armors = [nil] * 10 + [ruby_armor, FakeArmor.new("Robe", 7, :features => [fire_resist]), FakeArmor.new("Gown", 7, :features => [fire_resist])]
    check("a weapon type's traits are its normal attack and the lines three in four of its items show", ui::Engine::EquipInfo.type_traits(claymore),
          ["Normal Attack: ATK × 2.5", "Poison Strike +10%", "Slash Strike", "Fire Resist 20%", defense_down])
    ui::Engine::EquipInfo.type_traits($data_armors[11])
    $data_weapons = $data_weapons.dup.push(FakeWeapon.new("Rapier", 4, :features => [slash]))
    check("a new database reads the traits anew", ui::Engine::EquipInfo.type_traits(claymore), ["Normal Attack: ATK × 2.5", "Slash Strike", defense_down])
    template = FakeWeapon.new("Fire Knife", 1, :features => [poison, Feature.new(32, 8, Enchant_Value.new, 0, -1), Feature.new(21, 2, [Enchant_Value.new], 0, -1)])
    $data_weapons = [nil, knife, template]
    check("a template of random enchantments counts by the features every copy has, without a failure",
          [logged_lines { ui::Engine::EquipInfo.type_traits(knife) }.size, *ui::Engine::EquipInfo.of(template).effect_texts], [0, "Poison Strike +10%"])

    # The game refuses a gem where it cannot go.
    garnet_gem = FakeGem.new("Garnet", 1, :red)
    sapphire_gem = FakeGem.new("Sapphire", 2, :blue)
    ruby_gem = FakeGem.new("Ruby", 3, :red)
    onyx = FakeGem.new("Onyx", 4, nil)
    pearl = FakeGem.new("Pearl", 5, nil)
    garnet_gem.icon_index = 3475
    onyx.icon_index = 3473
    blade = FakeSocketed.new("Blade", :sockets => 3, :stones => [ruby_gem, nil, nil])
    potion = FakeGem.new("Potion", 6, nil)
    def potion.enchant_stone?; false; end
    $game_party = FakeParty.new(potion => 2, garnet_gem => 1, sapphire_gem => 2, onyx => 1, pearl => 1, ruby_gem => 0)
    check("the game's refusals tell why a gem cannot go in",
          [gems.refusal(nil, 0, garnet_gem), gems.refusal(sword.dup.tap { |item| item.socket_num = 0 }, 0, garnet_gem), gems.refusal(blade, 3, garnet_gem),
           gems.refusal(blade, 1, potion), gems.refusal(blade, 1, ruby_gem), gems.refusal(blade, 1, nil)],
          ["Nothing equipped", "Zantetsuken:Dawn has no sockets", "Blade has no socket 4", "Potion is not a gem", "No Ruby in the bag", "Socket 2 is empty"])
    cursed = FakeSocketed.new("Cursed Blade", :sockets => 2, :stones => [ruby_gem, nil])
    def cursed.change_ok?; false; end
    check("an item worn in a fixed slot keeps its gems", gems.refusal(cursed, 1, garnet_gem), "Cursed Blade cannot change its gems")
    holder = Object.new
    def holder.equip_change_ok?(_slot); false; end
    fixed = { :actor => holder, :slot => 0 }
    check("an item without gems of its own in a fixed slot keeps its sockets empty", gems.refusal(blade, 1, garnet_gem, fixed), "Blade cannot change its gems")

    # A character's slots and the items the equip list offers.
    great = FakeWeapon.new("Great Sword", 4, :sockets => 1)
    knife_item = FakeWeapon.new("Knife", 1)
    buckler = FakeArmor.new("Buckler", 7)
    knight = Object.new
    knight.instance_variable_set(:@equips, [great, nil, buckler])
    def knight.equips; @equips; end
    def knight.name; "Knight"; end
    def knight.base_level; 42; end
    def knight.slot_name(slot); ["Weapon", "Shield", "Head"][slot]; end
    def knight.equip_change_ok?(slot); slot != 2; end
    def knight.equippable?(item); !item.name.include?("Cursed"); end
    def knight.equippable_slot?(slot, item); slot == 0 ? item.respond_to?(:wtype_id) : item.respond_to?(:atype_id); end
    def $data_system.weapon_types; ["", "Knife", "", "", "Great Sword", "", "Rapier"]; end
    def $data_system.armor_types; ["", "", "", "", "", "", "", "Shield"]; end
    bag = $game_party = FakeParty.new(knife_item => 2, buckler => 1, FakeWeapon.new("Cursed Blade", 1) => 1)
    def bag.equip_items; all_items; end
    check("a character's slots show as rows, an empty one by its slot's name", game.slot_rows(knight).map { |row| row[:item] ? row[:item].name : row[:text] },
          ["Great Sword", "Shield (empty)", "Buckler"])
    game.slot_note(knight, 2, :fixed_text => "%s!")
    check("the equip rows offer remove and what fits", game.equip_rows(knight, 0).map { |row| row[:item] ? row[:item].name : row[:text] }, ["(Remove)", "Knife"])

    # Stats bound to a character, marked before a change.
    hero_stats = Object.new
    hero_stats.instance_variable_set(:@params, [100, 0, 50, 0, 0, 0, 0, 0])
    def hero_stats.param(id); @params[id]; end
    bound_box = ui::Engine::Box.new(:at => [0, 0], :size => [300, 100])
    bound = bound_box.add_stats(:actor => hero_stats, :params => [0, 2], :rates => [])
    bound_box.open
    frame
    bound.mark
    hero_stats.instance_variable_set(:@params, [90, 0, 60, 0, 0, 0, 0, 0])
    bound.refresh
    Graphics.update
    colors = bound_box.base_surface.bitmap.colors
    check("marked stats refreshed after a change show higher green and lower red", [colors["60"], colors["90"]], [ui::Engine::Style::GOOD.to_a, ui::Engine::Style::BAD.to_a])
    bound.unmark
    Graphics.update
    other_stats = Object.new
    def other_stats.param(id); [500, 0, 70, 0, 0, 0, 0, 0][id]; end
    bound.mark
    bound.actor = other_stats
    bound.refresh
    check("given another character they show its stats unmarked", [*bound.rows.map { |row| row[:value] }, bound.against], ["500", "70", nil])

    # What a gem change would do, and the rows and chips the gem dialog offers.
    edge = FakeSocketed.new("Edge", :sockets => 3, :stones => [ruby_gem, onyx, nil])
    $game_party = FakeParty.new(garnet_gem => 1, sapphire_gem => 1, pearl => 1, ruby_gem => 1)
    note = lambda { |socket, gem| gems.describe(gems.preview(edge, socket, gem)) }
    check("a preview tells a gem moving from another socket and warns of one of the same color pushing the other out",
          [*note.call(2, ruby_gem), *note.call(2, garnet_gem)], ["Moves from socket 1", :system, "One gem per color: socket 1 empties; its gem goes back to the bag", :warn])
    check("the notes of an empty socket, a gem sent back and a gem going in", [note.call(2, nil)[0], note.call(1, nil)[0], note.call(2, sapphire_gem)[0]],
          ["This socket is empty", "Onyx goes back to the bag", "Goes into socket 3"])
    gems.filled_text(edge)
    check("the gem rows offer remove, off when told, then the bag's gems",
          gems.rows(:remove_disabled => true).map { |row| row[:item] ? row[:item].name : "#{row[:text]} #{row[:disabled]}" }, ["Remove gem true", "Garnet", "Sapphire", "Pearl", "Ruby"])
    check("every color shows a filter, off where another socket holds one or the bag has none",
          gems.color_filters([garnet_gem], :every_color => true, :taken => [3473]).first(2).map { |chip| chip[:tooltip] if chip[:disabled] == true },
          ["Red: another socket holds one", "Blue: none in the bag"])

    # A window showing the edge's gem count shows the new count once a gem goes in, as the game's
    # change_stone bumps the gear of everyone.
    gem_count = Class.new(ui::Component) do
      define_method(:render) { window("Edge") { text ui::Equip.gems_text(edge), id: :edge_gems } }
    end
    shown = ui.open(gem_count)
    frame
    count_label = lambda { ui::Engine::Layer.tops.last.root.engine.find(:edge_gems) }
    before = count_label.call.text
    edge.change_stone(2, sapphire_gem)
    ui::Engine::Serials.bump(:gear)
    frame
    check("a window showing the edge's gem count renders the new count after a gem set [before, after]", [before, count_label.call.text], ["2/3", "3/3"])
    shown.close
    $game_party = FakeParty.new({})
  end
end
