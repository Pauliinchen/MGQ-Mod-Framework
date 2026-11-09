#----------------------------------------------------------------
#  equipment_window_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered the item list showing more rows in a taller window
#                            - Created
#
#----------------------------------------------------------------

# Covers the Equipment Window sample in a booted game against FakeTree, as a player uses it: the
# character's stats judged against what showed before new gear; the item's head with its element
# in a chip after its name and its sockets, whose tooltips end in the note and whose pick opens the
# gem dialog or buzzes in a fixed slot; the item dialog's comparison of the worn sword with another,
# whose gem moves over, sized for the item of the most stats, its list longer in a taller window,
# with its star and its hotkey help, and a pick that equips through the game or buzzes in a fixed
# slot; the gem dialog's color toggles and a gem set, taken out and refused through the game;
# Optimize, which picks by the character's stats, and Clear.

require_relative "game_lists_support"
require_relative "layer_support"
require_relative "equip_support"

# The Equipment Window sample.
EQUIPMENT_WINDOW = File.read(File.expand_path("../../Samples/Equipment_Window.rb", __dir__), :encoding => "UTF-8")

# Loads the Equipment Window anew into a game booted anew, whose component class is a new one.
def load_window
  Object.send(:remove_const, :Equipment_Window) if Object.const_defined?(:Equipment_Window)
  load_mod("Patch/Equipment_Window.rb", EQUIPMENT_WINDOW)
end

# An item that multiplies each of the character's parameters by a factor besides adding to it.
class FactorGear < FakeItem
  attr_reader :factors

  # Makes the item.
  #
  # @param name [String] Its name.
  # @param etype_id [Integer] The kind of slot it goes into.
  # @param params [Array<Integer>] What it adds to each parameter.
  # @param factors [Array<Numeric>] What it multiplies each parameter by.
  def initialize(name, etype_id, params, factors = [1] * 8)
    super(name, :params => params)
    @etype_id = etype_id
    @factors = factors
  end
end

# A character whose parameters follow its gear and whose gear changes through the bag, as the
# game's Optimize and Clear change it.
class GearHero < FakeHero
  # @return [Array<Symbol>] The game's commands it ran.
  attr_reader :done

  # @return [Integer] 100 plus what the gear adds, times the gear's factors.
  def param(id)
    flat = @equips.compact.inject(100) { |sum, item| sum + item.params[id] }
    @equips.compact.inject(flat.to_f) { |value, item| value * item.factors[id] }.round
  end

  # @return [Boolean] Always true.
  def equippable?(_item)
    true
  end

  # @return [Boolean] Whether an item is of a slot's kind.
  def equippable_slot?(slot, item)
    item.etype_id == equip_slots[slot]
  end

  # Swaps an item of the bag into a slot and the worn one into the bag.
  def change_equip(slot, item)
    $game_party.equip_items.delete_at($game_party.equip_items.index(item)) if item
    $game_party.equip_items << @equips[slot] if @equips[slot]
    @equips[slot] = item
  end

  # Puts an item into a slot without the bag, as the game's preview of an equip does.
  def force_change_equip(slot, item)
    @equips[slot] = item
  end

  # Optimizes as Paradox does: the weapon slot takes the item of the bag whose parameters sum highest.
  def optimize_equipments
    (@done ||= []) << :optimize
    change_equip(0, nil)
    change_equip(0, $game_party.equip_items.select { |item| item.etype_id == 0 }.max_by { |item| item.params.inject(:+) })
  end

  # Takes off every item, as the game's Clear does.
  def clear_equipments
    (@done ||= []) << :clear
    @equips.each_index { |slot| change_equip(slot, nil) }
  end
end

# A party whose bag holds gear.
class GearParty < FakeMenuParty
  # @return [Array] The gear in the bag.
  attr_reader :equip_items

  # Makes the party.
  #
  # @param members [Array<GearHero>] Its members.
  # @param items [Array] The gear in the bag.
  def initialize(members, items)
    super(members)
    @equip_items = items
  end
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    ui = Mod_Framework::UI
    [:Scene_Map, :Scene_Equip].each { |name| Object.const_set(name, Class.new(Scene_Base)) unless Object.const_defined?(name) }
    luka = equip_party
    sword = luka.equips[0]
    sword.features << Feature.new(31, 3, 1, 0, -1)
    load_window
    frame
    ui.open(Equipment_Window::EquipWindow, actor: luka)
    frame
    top = lambda { ui::Engine::Layer.tops.last }
    window = top.call.root.engine
    gear = top.call.mount.component
    parts = lambda { |part| [part] + (part.respond_to?(:children) ? part.children.map { |child| parts.call(child) }.flatten : []) }
    texts = lambda { |part| part.respond_to?(:text) ? [part.text] : part.children.map { |child| texts.call(child) }.flatten }
    find = lambda { |id| ui::Engine::Placement.find("##{id}") }

    # Luka's basic stats fill two columns; a stronger sword raises his ATK, judged against what showed before.
    stats = lambda { window.find(:ew_stats).children.select { |part| part.is_a?(ui::Engine::Stats) }.first }
    check("the basic stats fill two columns", [stats.call.rows.size, stats.call.columns], [8, 2])
    def luka.param(id)
      [1200, 80, 630, 200, 150, 120, 90, 60][id]
    end
    ui::Engine::Serials.bump(:gear, luka)
    frame
    atk = lambda { |rows| rows.find { |row| row[:key] == 2 }[:value] }
    check("new gear shows the new ATK, judged against the old", [atk.call(stats.call.rows), atk.call(stats.call.against)], ["630", "330"])

    # The sword heads the summary with its fire element in a chip after its name, its line and
    # Details; it adds its ATK with its ruby and its slash strike.
    header = parts.call(window.find(:ew_summary)).find { |part| part.is_a?(ui::Engine::Header) }
    chip = parts.call(header.title_row).find { |part| part.respond_to?(:chip) }
    check("the head names the sword with its element's chip after the name, its slot and type, and Details",
          [header.title_label.text, chip && chip.chip(0).instance_variable_get(:@options)[:icons], texts.call(header.subtitle_row)],
          ["Zantetsuken", [96], ["Right Hand: Sword", Equipment_Window::DETAILS]])
    summary = parts.call(window.find(:ew_summary))
    grid = summary.find { |part| part.is_a?(ui::Engine::Stats) }
    effects = summary.find { |part| part.is_a?(ui::Engine::Lines) }
    check("the summary sums up the sword with its ruby: the ATK it adds and its effect",
          [grid.rows.map { |row| [row[:name], row[:value]] }, effects.children.map { |label| label.text }], [[["ATK", "+420"]], ["Slash Strike"]])

    # The ruby's tooltip names its socket and ends in the note; a pick on a socket opens the gem
    # dialog, and in a fixed slot only buzzes.
    sockets = window.find(:ew_summary_gems)
    tip = ui::Engine::Box.new
    sockets.children[0].tooltip.call(tip)
    check("the ruby's tooltip names its socket and ends in the note", [texts.call(tip).include?("Socket 1 of 2"), texts.call(tip).last], [true, "Click to change"])
    tell(tree, [[sockets.children[1].node, "click"]])
    check("a pick on the empty socket opens the gem dialog on it", [top.call.id, top.call.mount.component.socket], ["ew_gem_dialog", 1])
    top.call.handle.close
    frame
    def luka.equip_change_ok?(_slot); false; end
    $sounds = []
    tell(tree, [[sockets.children[1].node, "click"]])
    check("a pick in a fixed slot buzzes and opens nothing", [top.call.id, $sounds], ["ew_equipment_window", [:buzzer]])
    def luka.equip_change_ok?(_slot); true; end

    # The Gems tab lists a line per socket with its gem's description.
    gear.details_tab = :gems
    frame
    lines = window.find(:ew_tab_gems)
    tree.rects[lines.node] = [0, 0, 300, 200]
    frame
    check("the Gems tab shows a line per socket, the ruby's with its description",
          lines.children.map { |part| part.is_a?(ui::Engine::Label) ? part.text : nil }.compact.reject { |text| text.empty? }, ["1", "A red gem.", "2", "Empty"])

    # The item dialog sets the worn sword against a sword of one socket, which takes the ruby, and
    # sizes its comparison for the item of the most stats.
    kusanagi = FakeSocketed.new("Kusanagi", :icon => 401, :sockets => 1, :stones => [nil], :params => [0, 0, 350, 0, 0, 0, 0, 0])
    def kusanagi.wtype_id; 1; end
    plain = FakeItem.new("Plain Edge")
    rich = FakeItem.new("Rich Edge", :params => [100, 50, 10, 10, 10, 10, 10, 10])
    favorites = []
    ui::Game.define_singleton_method(:favorite_icon) { ui::Game::FAVORITE_ICON }
    $game_party.define_singleton_method(:favorite_item?) { |item| favorites.include?(item) }
    $game_party.define_singleton_method(:set_favorite_item) { |item| favorites.include?(item) ? favorites.delete(item) : favorites << item }
    $game_party.define_singleton_method(:equip_items) { [plain, kusanagi, rich] }
    def luka.equippable?(_item); true; end
    def luka.change_equip(slot, item); @equips[slot] = item; end
    tree.rects[window.node] = [0, 0, 640, 560]
    frame
    tell(tree, [[window.find(:ew_slots).node, "submit", 0]])
    dialog = top.call.mount.component
    copies = parts.call(top.call.root.engine).find { |part| part.is_a?(ui::Engine::Measures) }.children
    check("the item dialog shows the first item and keeps hidden copies of the item of the most stats",
          [top.call.id, texts.call(copies[0]).include?("Plain Edge"), copies.map { |copy| copy.visible? }.uniq, copies.drop(1).any? { |copy| texts.call(copy).include?("Rich Edge") }],
          ["ew_item_dialog", true, [true, false], true])
    item_rows = lambda { find.call(:ew_item_list).rows }
    check("the item list shows more rows in the taller window that opened it [its size, rows]", [dialog.opener_size, find.call(:ew_item_list).most_rows], [[640, 560], 12])
    dialog.row = item_rows.call.find { |row| row[:item] == kusanagi }
    frame
    shown = lambda { |klass| parts.call(copies[0]).select { |part| part.instance_of?(klass) } }
    headers = shown.call(ui::Engine::Header).reject { |each| each.compact }
    worn_slots, picked_slots = shown.call(ui::Engine::Slots).first(2)
    tip = ui::Engine::Box.new
    worn_slots.children[0].tooltip.call(tip)
    check("the headers name the worn sword and the other, and the ruby moves to the other sword, which tells where it comes from",
          [headers.map { |each| [each.title_label.text, each.subtitle_label.text] }, texts.call(tip).last, texts.call(picked_slots.parent).last],
          [[["Zantetsuken", "Equipped · Sword"], ["Kusanagi", "Selected · Sword"]], "Moves to Kusanagi", "+1 gem from the worn item"])
    steps = nodes_of(tree, "stack").map { |node| tree.nodes[node][:props]["forms"] }.compact.uniq.sort
    counts = shown.call(ui::Engine::Label).map { |label| label.text }.grep(/gems?\z/).uniq
    check("the forms a short window steps through: the effect lines in one row, the gems as a count that holds the ruby moving over, the headers in one row",
          [steps, counts], [[[0, 1], [0, 2], [0, 3]], ["· 1 gem"]])

    # The star after the other sword marks it a favorite and lights; the hotkey help names the
    # list's keys before Back, and no favorite key on the row that takes the sword out.
    star = lambda { shown.call(ui::Engine::Icon).find { |icon| icon.icon == ui::Game.favorite_icon } }
    dim = star.call.opacity
    tell(tree, [[star.call.node, "click"]])
    check("a click on the star marks the sword a favorite and lights the star", [dim, favorites, star.call.opacity],
          [Equipment_Window::Compare::STAR_OFF_OPACITY, [kusanagi], ui::Engine::Component::OPAQUE])
    key_line = lambda { tree.nodes.keys.sort.map { |node| ui::Engine::Tree.component(node) }.grep(ui::Engine::KeyHelp).last.line }
    tree.post("states", find.call(:ew_item_list).node => ui::Engine::Tree::FOCUSED)
    frame
    Graphics.update
    on_item = key_line.call
    dialog.row = item_rows.call.find { |row| row[:item].nil? }
    frame
    Graphics.update
    check("the key help names the list's keys before Back, and no favorite key on the remove row",
          [$logged.grep(/render failed/), on_item, key_line.call],
          [[], "Tab: Search  D: Filter  S: Save favorite  Ctrl+arrows: Leave the list  X or Numpad 0: Back",
           "Tab: Search  D: Filter  Ctrl+arrows: Leave the list  X or Numpad 0: Back"])

    # A pick in a fixed slot buzzes and keeps the dialog open; else it equips the sword through the
    # game with the equip sound and the log line, and closes.
    pick_kusanagi = lambda { tell(tree, [[find.call(:ew_item_list).node, "submit", item_rows.call.index { |row| row[:item] == kusanagi }]]) }
    def luka.equip_change_ok?(_slot); false; end
    $sounds = []
    refused = logged_lines { pick_kusanagi.call }
    def luka.equip_change_ok?(_slot); true; end
    check("a pick in a fixed slot buzzes, keeps the dialog open and is logged", [$sounds, top.call.id, refused.grep(/refused/).size], [[:buzzer], "ew_item_dialog", 1])
    $sounds = []
    taken = logged_lines { pick_kusanagi.call }
    check("a pick equips the sword through the game with the equip sound and the log line, and closes the dialog",
          [luka.equips[0].name, $sounds, taken.grep(/\AEquipment Window: Equip for Luka \(actor 1\), Right Hand: Kusanagi/).size, top.call.id],
          ["Kusanagi", [:equip], 1, "ew_equipment_window"])
    luka.equips[0] = sword
    ui::Engine::Serials.bump(:gear, luka)
    frame
  end
end

# The gem dialog: a toggle per color, greyed where the bag has none, turned on by a click and by
# the digits; a gem picked goes into the socket through the game and pulses its line, the remove
# row sends it back to the bag, and a change the game refuses buzzes and keeps the dialog open.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    ui = Mod_Framework::UI
    [:Scene_Map, :Scene_Equip].each { |name| Object.const_set(name, Class.new(Scene_Base)) unless Object.const_defined?(name) }
    luka = equip_party
    garnet = FakeGem.new("Garnet", 1, :red).tap { |gem| gem.icon_index = 3473 }
    sapphire = FakeGem.new("Sapphire", 2, :blue).tap { |gem| gem.icon_index = 3479 }
    pearl = FakeGem.new("Pearl", 3, :white).tap { |gem| gem.icon_index = 3474 }
    party = $game_party
    party.instance_variable_set(:@counts, garnet => 1, sapphire => 1, pearl => 1)
    load_window
    frame
    ui.open(Equipment_Window::EquipWindow, actor: luka)
    frame
    top = lambda { ui::Engine::Layer.tops.last }
    window = top.call.root.engine
    gear = top.call.mount.component
    gear.details_tab = :gems
    frame
    lines = window.find(:ew_tab_gems)
    tree.rects[lines.node] = [0, 0, 300, 200]
    frame
    tell(tree, [[lines.children.select { |part| part.is_a?(ui::Engine::Button) }[1].node, "click"]])
    dialog = top.call.mount.component
    toggles = ui::Engine::Tree.component(nodes_of(tree, "stack").find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::ToggleGroup) })
    gems = lambda { ui::Engine::Placement.find("#ew_gem_list").rows.map { |row| row[:item] && row[:item].name }.compact }
    check("a confirm on the second socket's line opens the gem dialog with a toggle per color, greyed where the bag has none",
          [top.call.id, dialog.socket, toggles.children.size, toggles.children.map { |item| item.enabled? }.first(5)], ["ew_gem_dialog", 1, 6, [true, true, false, true, false]])
    tell(tree, [[toggles.children[1].node, "click"]])
    check("a click on the blue toggle keeps the blue gems", [dialog.colors, gems.call], [[3479], ["Sapphire"]])
    $keys = { 0x34 => 3 }
    frame
    Graphics.update
    $keys = nil
    frame
    Graphics.update
    check("the digit 4 turns the fourth color on beside it", [dialog.colors, gems.call], [[3479, 3474], ["Sapphire", "Pearl"]])
    gem_keys = lambda { tree.nodes.keys.sort.map { |node| ui::Engine::Tree.component(node) }.grep(ui::Engine::KeyHelp).last.line }
    resting = gem_keys.call
    ui::Engine::TextEdit.open = :field
    frame
    Graphics.update
    typing = gem_keys.call
    ui::Engine::TextEdit.release(:field)
    check("the key help names Tab, the digits of the colors and Back, and only Tab back to the list while the search types",
          [resting, typing], ["Tab: Search  1-6: Colors  X or Numpad 0: Back", "Tab: Back to the list"])

    # The sapphire goes into the socket through the game and its line pulses.
    pick = lambda do |found|
      rows = ui::Engine::Placement.find("#ew_gem_list").rows
      tell(tree, [[ui::Engine::Placement.find("#ew_gem_list").node, "submit", rows.index { |row| found.call(row) }]])
    end
    $sounds = []
    pick.call(lambda { |row| row[:item] == sapphire })
    frame
    check("a gem picked goes into the socket from the bag, the dialog closes and the socket's line pulses",
          [luka.equips[0].stones, party.item_number(sapphire), $sounds, top.call.id, lines.instance_variable_get(:@labels)[1].opacity < 255],
          [[luka.equips[0].stones[0], sapphire], 0, [:equip], "ew_equipment_window", true])

    # The remove row sends it back; a set the game refuses buzzes and keeps the dialog open.
    open_second = lambda { tell(tree, [[lines.children.select { |part| part.is_a?(ui::Engine::Button) }[1].node, "click"]]) }
    open_second.call
    pick.call(lambda { |row| row[:remove] })
    check("the remove row sends the gem back to the bag", [luka.equips[0].stones[1], party.item_number(sapphire)], [nil, 1])
    open_second.call
    party.refuse = true
    $sounds = []
    refused = logged_lines { pick.call(lambda { |row| row[:item] == sapphire }) }
    party.refuse = false
    check("a set the game refuses buzzes, keeps the dialog open and the socket empty, and is logged",
          [$sounds, top.call.id, luka.equips[0].stones[1], refused.grep(/Gems refused: Sapphire into socket 2/).size], [[:buzzer], "ew_gem_dialog", nil, 1])
  end
end

# Optimize puts into each slot the game changed the item that raises the character's stats most,
# not the one the game sums highest, and Clear takes everything off through the game; both are
# logged with the slots before and after.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    ui = Mod_Framework::UI
    [:Scene_Map, :Scene_Equip].each { |name| Object.const_set(name, Class.new(Scene_Base)) unless Object.const_defined?(name) }
    equip_party
    halo = FactorGear.new("Halo", 0, [0, 0, 100, 0, 0, 0, 0, 0], [1, 1, 3, 1, 1, 1, 1, 1])
    demiurge = FactorGear.new("Demiurge", 0, [50] * 8)
    luka = GearHero.new(1, "Luka", [nil, nil, nil])
    $game_party = GearParty.new([luka], [halo, demiurge])
    check("a mod reads Luka's stats with no weapon, the Halo and the Demiurge, and his gear stays as it is",
          [ui::Equip.stats_with(luka, 0, [nil, halo, demiurge]), luka.equips], [[[100] * 8, [100, 100, 600, 100, 100, 100, 100, 100], [150] * 8], [nil, nil, nil]])
    load_window
    frame
    ui.open(Equipment_Window::EquipWindow, actor: luka)
    frame
    optimize, clear = ui::Engine::Layer.tops.last.root.engine.find(:ew_buttons).children
    $sounds = []
    lines = logged_lines do
      tell(tree, [[optimize.node, "click"]])
      tell(tree, [[clear.node, "click"]])
    end
    check("Optimize and Clear go through the game with the equip sound", [luka.done, $sounds], [[:optimize, :clear], [:equip, :equip]])
    check("Optimize took the Halo, which raises the stats most, and both are logged with the slots before and after",
          lines.grep(/\AEquipment Window: (Optimize|Clear) for Luka/),
          ["Equipment Window: Optimize for Luka: before Right Hand -, Left Hand -, Accessory -; after Right Hand Halo, Left Hand -, Accessory -",
           "Equipment Window: Clear for Luka: before Right Hand Halo, Left Hand -, Accessory -; after Right Hand -, Left Hand -, Accessory -"])
  end
end
