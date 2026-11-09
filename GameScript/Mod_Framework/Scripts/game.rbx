#----------------------------------------------------------------
#  game.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Removed the equip writer, Optimize, Clear and the favorite toggle, which the Equipment Window does itself
#      Paulinchen  2026-11-08: Found the scene's top viewport for a root that follows a character on the scene's map
#      Paulinchen  2026-11-07: Named the type helper type_filters, as chips no longer filter
#                            - Moved the gear trial, the equip info and the gems into files of their own
#                            - Removed the engine's gear compares, item header and sockets, which UI::Equip builds from the general parts
#                            - Kept the summary of what an item adds to the wrapped labels of a tooltip, which the compares no longer share
#                            - Marked greyed rows and chips with :disabled
#      Paulinchen  2026-11-06: Removed the scene's picture viewport and its screen's tone, which the roots under the windows no longer take
#                            - Let each item Optimize tries share the first try's features by code and id, and its abilities
#                            - Named the warning color of a fixed slot :warning
#                            - Removed the add_ helper of the equip comparison, which nothing called
#                            - Removed the set header and the add_ helper of the gem comparison, which nothing called
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Told the scene, a character's sprite and whether a CG shows without making objects
#                            - Built the item header on the general header and left the note and the empty text of sockets to their slots
#                            - Told whether the game's message shows at the top of the screen, which a HUD hides under
#                            - Found the event of an id on this map for a root that follows it
#                            - Told whether the game's refresh would leave a character as it is, for the game's own gear previews
#                            - Weighed the items of a slot Optimize changed on one copy of the character, which shares
#                              the features and boosts the items do not change
#                            - Removed the old gem dialog, which UI::Equip::GemDialog of the UI layer replaces
#                            - Asked the slot a character wears an item in before a gem change, as the game's equip screen asks
#                            - Hid the gem count of a folded comparison once it would be cut
#                            - Logged each equip, favorite and gem change, each character switch and why one was refused
#                            - Took each copy of a character Optimize tries gear on out of the game's cache of features
#                            - Placed a root that follows a character at whole pixels, as the game may give a character's
#                              place on the screen in fractions
#                            - Found a character's sprite without making lists
#      Paulinchen  2026-11-04: Showed a text in place of sockets without any, and made them anew as the gear's serial moves on
#                            - Let a block fill the end of a gem's tooltip in place of its note line
#                            - Told whether the game shows a CG, once a frame: a novel scene, or a picture named as a CG
#                              that covers the screen
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Left out the scene's picture and top viewports once RGSS freed them
#                            - Found the screen tone of the map or the battle
#      Paulinchen  2026-11-01: Took a sprite on a viewport a scene freed as not shown
#                            - Stacked the roots that follow a character's sprite with those on its tile, and followed the
#                              character of a freed sprite
#                            - Found the scene's top viewport for a wheel that follows
#                            - Found a map character's sprite outside the scene's own map, such as on the live map behind a menu
#      Paulinchen  2026-10-31: Named a button by the key F1 binds it to once that is not the game's own
#                            - Picked the item of each slot Optimize changed by the character's stats and logged the
#                              slots of Optimize and Clear
#                            - Read a template of random enchantments by the features every copy has
#                            - Reworded the refusal of an item that is not a gem
#                            - Let the gem count of a folded side give way within its column
#                            - Told whether the player stands free on the map, and why not
#                            - Told the gem dialog's close blocks why it closed after whether a gem changed
#                            - Found the viewport the scene's pictures lie on
#                            - Found where a map character, the player or a sprite shows on the screen
#                            - Read the letters of the game's own name entry
#      Paulinchen  2026-10-29: Added favorites, the type chips of items and a star that marks the picked item of a
#                              comparison a favorite
#                            - Added the game's names of its buttons
#                            - Added the game's terms, the step to the menu's next character, and Optimize and Clear
#                            - Built the gem dialog on a search list
#                            - Gave each empty socket a line of its own and kept the gem comparison small and of one height
#                            - Kept the gem dialog on the one socket it opened for, without the gems of colors other
#                              sockets hold and the kind chips, its chips turned on by the digits and its search
#                              reached by Tab
#                            - Added the colors other sockets hold and gem rows and color chips for one socket
#                            - Added a character's title, slots, equip rows and equip writer
#                            - Let the item header's name row take other components
#                            - Added gem previews with their notes, gem rows and chips, and the gem writers' sounds
#                            - Added the comparison of two items, the comparison of two gems, the set header and the
#                              gem dialog
#                            - Read a gem once while the database stays the same
#                            - Refused a gem change on an item worn in a fixed slot
#                            - Named the attack and defense kinds Damage and Resist and the pink gems Pink
#                            - Listed what an item or a gem adds as plain lines
#                            - Added the innate traits of a weapon or armor type
#                            - Added a character's stat rows, the gem lines and the set steps for Lines
#                            - Judged a weapon's base hit rate against the rate every weapon has
#                            - Read a weapon's base hit rate apart from the bonuses
#                            - Showed by the name only the elements with an icon
#                            - Read the effect lines for Lines and dropped the party's changes
#                            - Added the item header, the type name, the paired cells, the search text and the
#                              Special Effects by kind, built the sockets on Slots and dropped the effect headings
#                            - Added a short note of what an item adds, the gems after a set and the writer that
#                              changes gems through the game
#                            - Put the count of the shared effect lines in a row of its own
#                            - Added the kinds of what an item or a gem adds and the colors of gems, and searched a gem
#                              by its name
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # The game's own look of what it shows: the colors of item names, the icons of the elements,
    # the short names of the parameters and its big numbers, as its menus draw them; a character's
    # title, slots and the items its equip list offers, the writer that changes an equip through
    # the game, the equip screen's Optimize and Clear, and the step to the menu's next character.
    # Each copes with a game that lacks what it reads.
    module Game
      # The icon the game's equip menu draws for a socket that holds no gem.
      EMPTY_SOCKET_ICON = 3471

      # The text color the game's item lists give a favorite item, its tp_gauge_color2.
      FAVORITE_COLOR = 29

      # The icon of a favorite: the plain star of the game's icon sheet.
      FAVORITE_ICON = 192

      # The words of marking an item a favorite and of taking the mark away, where the game has
      # none of its own.
      FAVORITE_TEXTS = ["Save favorite", "Remove favorite"]

      # The text colors the game's equip screen draws a higher and a lower value in, its
      # power_up_color and power_down_color.
      POWER_UP_COLOR = 24
      POWER_DOWN_COLOR = 25

      # The parameters in the order the game's compare pages list them, which Vocab.params_a counts.
      COMPARE_ORDER = [2, 3, 4, 5, 6, 7, 0, 1]

      # A number the game writes with a unit: its whole part, its decimals and its unit.
      UNIT_NUMBER = /\A(-?\d+)(?:\.(\d+))?(\D.*)\z/

      # From this size on a number shows with the game's units, as its status screen does.
      BIG_NUMBER = 10_000_000

      # The side of an icon in the game's icon sheet.
      ICON_SIDE = 24

      # The parameters a character's stat rows read unless told otherwise, all eight.
      STAT_PARAMS = (0..7).to_a

      # The parameters a weapon type's damage formula names, by the game's names of them in a
      # formula.
      FORMULA_PARAMS = { "mhp" => 0, "mmp" => 1, "atk" => 2, "def" => 3, "mat" => 4, "mdf" => 5, "agi" => 6, "luk" => 7 }

      # A parameter of the character in a weapon type's damage formula.
      FORMULA_PARAM = /\ba\.(mhp|mmp|atk|def|mat|mdf|agi|luk)\b/

      # The rates a character's stat rows read unless told otherwise: the method that reads each
      # and a name that fits a column of stats.
      STAT_RATES = [[:hit, "Hit"], [:cri, "Critical"], [:eva, "Evasion"], [:mev, "M. Evasion"], [:cnt, "Counter"], [:magical_critical, "M. Critical"]]

      # The :data of a row that takes the item out of a slot or a gem out of a socket.
      REMOVE = :remove

      # A character's title, by the name and the level.
      TITLE_TEXT = "%s  Lv %d"

      # What stands between a slot's name and its item's type.
      SLOT_JOIN = ": "

      # A slot's note when its item cannot change, by the note.
      FIXED_TEXT = "%s (fixed)"

      # A slot that holds nothing, by the slot's name.
      EMPTY_SLOT_TEXT = "%s (empty)"

      # The row that takes the item out of a slot.
      REMOVE_TEXT = "(Remove)"

      # The keys of the game's buttons on the keyboard, as its key help names them where its Vocab
      # names none.
      KEY_NAMES = { :A => "Shift", :B => "X", :C => "Z", :X => "A", :Y => "S", :Z => "D", :L => "Q", :R => "W" }

      extend Logging

      # What starts this script's lines in the log.
      LOG_TAG = "game"

      # Sprites of map characters kept before the disposed ones among them are let go.
      CHARACTER_SPRITES_KEPT = 256

      # The least share of the screen a picture covers to count as a full-screen picture; some of
      # the game's CGs are a pixel short of the screen.
      COVER_SHARE = 0.9

      # The least opacity a full-screen picture shows with.
      COVER_ALPHA = 128

      # The names of the game's pictures that are CGs, by their prefixes: event and H scenes,
      # cut-ins, backgrounds, flashes and the screens sys_ fills in one color or noise. Standing
      # portraits (80_) are as large as the screen too, with see-through corners like many CGs, so
      # only the name tells the two apart.
      CG_NAMES = /\A(?:ev_|ct_|iv_|bg|flash|sys_(?:black|white|noise|cut)\z)/

      # Pictures whose last look was noted, before all are let go.
      PICTURES_KEPT = 256

      # What each picture showed when it was last looked at, by the picture: its name, opacity,
      # zoom, place and origin, and whether it covered the screen as a CG then.
      @pictures_seen = {}.compare_by_identity

      # The frame of Engine::Key.frame cutscene? last answered in, and its answer then.
      @cutscene_frame = nil
      @cutscene = false

      # Every sprite of a map character the game or a mod made, oldest first, so a root follows a
      # character whose sprite lies outside the scene's own map, such as on the live map behind a
      # menu or among a mod's own sprites.
      @character_sprites = []

      # Notes a sprite of a map character as it is made, letting go of the disposed ones once
      # CHARACTER_SPRITES_KEPT are kept.
      #
      # @param sprite [Sprite_Character] The sprite.
      def self.note_character_sprite(sprite)
        @character_sprites.reject! { |each| each.disposed? } if @character_sprites.size >= CHARACTER_SPRITES_KEPT
        @character_sprites << sprite
      end

      # Notes every sprite of a map character made from now on, see note_character_sprite.
      def self.watch_character_sprites
        return unless defined?(::Sprite_Character)

        Hooks.after(::Sprite_Character, :initialize, "Mod Framework character sprites") { |*_args| Mod_Framework::UI::Game.note_character_sprite(self) }
      end

      # Tells the text color the game's menus draw an item's name in: its enchantment's color, and
      # in a list of the bag a favorite's first.
      #
      # @param item [RPG::BaseItem, nil] The item.
      # @param bag [Boolean] Whether it shows in a list of the bag.
      # @return [Integer] The game's text color, 0 for the plain one.
      def self.item_color(item, bag = false)
        return 0 unless item
        return FAVORITE_COLOR if bag && item.respond_to?(:favorite?) && item.favorite?

        item.respond_to?(:display_color) ? item.display_color.to_i : 0
      rescue => e
        log_once([:item_color, e.class], "the color of an item could not be read, so it is the plain one: #{Logging.failure(e)}")
        0
      end

      # Tells the name the game's menus show of an item.
      #
      # @param item [RPG::BaseItem, nil] The item.
      # @return [String] Its name, empty for none.
      def self.item_name(item)
        return "" unless item

        item.respond_to?(:display_name) ? item.display_name.to_s : item.name.to_s
      end

      # Finds the icon the game's status screen shows for an element.
      #
      # @param element [Integer, String] The element's id, or its name as $data_system names it.
      # @return [Integer, nil] The icon, nil for an element without one.
      def self.element_icon(element)
        id = element.is_a?(Integer) ? element : element_id(element)
        return nil unless id && defined?(::NWConst::Status)

        status = ::NWConst::Status
        [[:ADD_ELEMENT_RESIST, :ADD_ELEMENT_ICONS], [:ELEMENT_RESIST, :ELEMENT_ICONS]].each do |ids, icons|
          next unless status.const_defined?(ids) && status.const_defined?(icons)

          place = status.const_get(ids).index(id)
          return status.const_get(icons)[place] if place
        end
        nil
      end

      # Finds an element's id by its name.
      #
      # @param name [String] The name.
      # @return [Integer, nil] The id, nil for none.
      def self.element_id(name)
        elements = $data_system ? Array($data_system.elements) : []
        place = elements.index(name.to_s)
        place && place > 0 ? place : nil
      end

      # Tells an element's name.
      #
      # @param id [Integer] The element.
      # @return [String] Its name, empty for none.
      def self.element_name(id)
        $data_system ? Array($data_system.elements)[id].to_s : ""
      end

      # Tells a parameter's short name, as the game's compare pages show it (ATK to MP).
      #
      # @param id [Integer] The parameter.
      # @return [String] The name; its full name in a game without short ones.
      def self.param_short(id)
        place = COMPARE_ORDER.index(id)
        return Vocab.params_a(place).to_s if place && Vocab.respond_to?(:params_a)

        Vocab.param(id).to_s
      end

      # Writes a number, from BIG_NUMBER on with the game's units.
      #
      # @param value [Integer] The number.
      # @return [String] The text, such as "3412880" or "720.46Mil.".
      def self.number(value)
        value.abs >= BIG_NUMBER && value.respond_to?(:give_unit) ? value.give_unit : value.to_s
      end

      # Writes a number ever shorter, for a place too narrow for number: the game's text with its
      # units, then that text with one decimal fewer each time, down to none.
      #
      # @param value [Integer] The number.
      # @return [Array<String>] Such as ["953.492Mil.", "953.49Mil.", "953.5Mil.", "953Mil."]; empty
      #   for a number the game writes in digits.
      def self.shorter_numbers(value)
        text = value.respond_to?(:give_unit) ? value.give_unit.to_s : ""
        found = text.match(UNIT_NUMBER)
        return [] unless found

        decimals = found[2].to_s.size
        [text] + (decimals - 1).downto(0).map { |kept| format("%.#{kept}f", "#{found[1]}.#{found[2]}".to_f) + found[3] }
      end

      # Writes what is added to a number: its sign, then the number.
      #
      # @param value [Integer] What is added.
      # @return [String] Such as "+3000" or "-30".
      def self.added(value)
        (value < 0 ? "-" : "+") + number(value.abs)
      end

      # Tells whether the game's icon sheet holds an icon.
      #
      # @param icon [Integer] The icon.
      # @return [Boolean] Whether it does.
      def self.icon?(icon)
        sheet = Cache.system("Iconset")
        icon < (sheet.width / ICON_SIDE) * (sheet.height / ICON_SIDE)
      rescue => e
        log_once([:icon, e.class], "the icon sheet could not be read: #{Logging.failure(e)}")
        false
      end

      # Tells the icon of a socket that holds no gem, where the game's icon sheet has it.
      #
      # @return [Integer, nil] EMPTY_SOCKET_ICON, nil for a sheet without it.
      def self.empty_socket_icon
        icon?(EMPTY_SOCKET_ICON) ? EMPTY_SOCKET_ICON : nil
      end

      # Reads a character's stats as rows of Stats, each keyed and with its number, so a later
      # reading can be judged against them: the parameters by their names and the game's numbers,
      # each a big one with its :shorter texts (shorter_numbers), then the rates in whole percents.
      # A rate the character cannot read is left out.
      #
      # @param actor [Game_Actor] The character.
      # @param options [Hash] :params (the parameter ids, STAT_PARAMS unless given) and :rates (the
      #   method and the name of each rate, STAT_RATES unless given); an empty list leaves them out.
      # @return [Array<Hash>] The rows, a parameter keyed by its id and a rate by its method.
      def self.stat_rows(actor, options = {})
        basic = options.fetch(:params, STAT_PARAMS).map do |id|
          value = actor.param(id)
          row = { :key => id, :name => Vocab.param(id).to_s, :value => number(value), :number => value }
          shorter = shorter_numbers(value)
          shorter.empty? ? row : row.merge(:shorter => shorter)
        end
        rates = options.fetch(:rates, STAT_RATES).select { |method, _name| actor.respond_to?(method) }.map do |method, name|
          percent = (actor.send(method).to_f * 100).round
          { :key => method, :name => name, :value => "#{percent}%", :number => percent }
        end
        basic + rates
      end


      # Tells an equipment's type, as the game's database names it.
      #
      # @param item [RPG::BaseItem, nil] The item.
      # @return [String] Its weapon or armor type, empty for none.
      def self.type_name(item)
        return "" unless $data_system
        return Array($data_system.weapon_types)[item.wtype_id].to_s if item.respond_to?(:wtype_id)

        item.respond_to?(:atype_id) ? Array($data_system.armor_types)[item.atype_id].to_s : ""
      end

      # Writes the formula of a weapon type's normal attack, the base attack power the game's
      # WEAPON_TYPE_DAMAGE table gives the type, with the parameters' short names.
      #
      # @param wtype_id [Integer] The weapon type.
      # @return [String, nil] Such as "(ATK + DEX) × 1.2"; nil for a type the table lacks and for
      #   a formula that names more than the character's parameters.
      def self.attack_formula(wtype_id)
        return nil unless defined?(::NWConst::Parameter) && ::NWConst::Parameter.const_defined?(:WEAPON_TYPE_DAMAGE)

        formula = ::NWConst::Parameter::WEAPON_TYPE_DAMAGE[wtype_id]
        return nil unless formula.is_a?(String) && formula.gsub(FORMULA_PARAM, "") !~ /[A-Za-z_$@]/

        formula.gsub(FORMULA_PARAM) { param_short(FORMULA_PARAMS[Regexp.last_match(1)]) }.gsub("*", [0xD7].pack("U")).squeeze(" ").strip
      end

      # Tells a character's title: the name and the level, as a window over the character heads it.
      #
      # @param actor [Game_Actor] The character.
      # @return [String] Such as "Luka  Lv 42".
      def self.actor_title(actor)
        format(TITLE_TEXT, actor.name, actor.respond_to?(:base_level) ? actor.base_level : actor.level)
      end

      # Tells a slot's name, as the game's equip screen names it.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @return [String] The name, such as "Weapon".
      def self.slot_name(actor, slot)
        actor.respond_to?(:slot_name) ? actor.slot_name(slot).to_s : Vocab.etype(actor.equip_slots[slot]).to_s
      end

      # Tells the item a character wears in a slot.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer, nil] The slot.
      # @return [RPG::EquipItem, nil] The item, nil for none or no slot.
      def self.equip(actor, slot)
        slot ? actor.equips[slot] : nil
      end

      # Tells the note of a slot for an item header: the slot's name and its item's type, in the
      # warn color with :fixed_text when the slot's item cannot change.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @param options [Hash] :fixed_text (FIXED_TEXT, by the note).
      # @return [Hash] :note and :note_color, the line and its color.
      def self.slot_note(actor, slot, options = {})
        text = [slot_name(actor, slot), type_name(actor.equips[slot])].reject { |part| part.empty? }.join(SLOT_JOIN)
        return { :note => text, :note_color => :dim } if actor.equip_change_ok?(slot)

        { :note => format(options.fetch(:fixed_text, FIXED_TEXT), text), :note_color => :warning }
      end

      # Tells a character's slots as rows of a List: each slot's item, or a faint dim row with
      # :empty_text for an empty slot; a slot whose item cannot change takes no pick.
      #
      # @param actor [Game_Actor] The character.
      # @param options [Hash] :empty_text (EMPTY_SLOT_TEXT, by the slot's name).
      # @return [Array<Hash>] A row per slot.
      def self.slot_rows(actor, options = {})
        empty = options.fetch(:empty_text, EMPTY_SLOT_TEXT)
        actor.equips.each_with_index.map do |item, slot|
          disabled = !actor.equip_change_ok?(slot)
          next { :item => item, :disabled => disabled } if item

          { :text => format(empty, slot_name(actor, slot)), :color => :dim, :faint => true, :disabled => disabled }
        end
      end

      # Tells the items a character can wear in a slot as rows of a List, as the game's equip list
      # chooses them from the bag: each with its count and found by its name, a favorite with the
      # star before its count (and its name in FAVORITE_COLOR, as :bag colors
      # it), after a row that takes the slot's item out while it holds one. A row's :data is its
      # item, the remove row's REMOVE.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @param options [Hash] :remove_text (REMOVE_TEXT; nil leaves the remove row out).
      # @return [Array<Hash>] The rows.
      def self.equip_rows(actor, slot, options = {})
        remove = options.fetch(:remove_text, REMOVE_TEXT)
        rows = actor.equips[slot] && !remove.nil? ? [{ :text => remove.to_s, :remove => true, :search => false, :data => REMOVE }] : []
        items = $game_party ? $game_party.equip_items.uniq : []
        items.each do |item|
          next unless fits_slot?(actor, slot, item)

          row = { :item => item, :bag => true, :count => true, :data => item }
          row[:icons] = [favorite_icon].compact if favorite?(item)
          rows << row
        end
        rows
      end

      # Tells the icon of a favorite, where the game's icon sheet has it.
      #
      # @return [Integer, nil] FAVORITE_ICON, nil for a sheet without it.
      def self.favorite_icon
        icon?(FAVORITE_ICON) ? FAVORITE_ICON : nil
      end

      # Tells whether the party marked an item a favorite, as the game's item lists show it.
      #
      # @param item [RPG::BaseItem, nil] The item.
      # @return [Boolean] Whether it did; false in a game without favorites.
      def self.favorite?(item)
        return false unless item && $game_party && $game_party.respond_to?(:favorite_item?)

        $game_party.favorite_item?(item) ? true : false
      rescue => e
        log_once([:favorite, e.class], "whether an item is a favorite could not be read: #{Logging.failure(e)}")
        false
      end

      # Tells the game's words of marking an item a favorite, or of taking the mark away.
      #
      # @param on [Boolean] Whether the item is a favorite now, so the words take the mark away.
      # @return [String] Such as "Save favorite".
      def self.favorite_text(on)
        return ::ShowKey_Help.favorite(on).to_s if defined?(::ShowKey_Help) && ::ShowKey_Help.respond_to?(:favorite)

        FAVORITE_TEXTS[on ? 1 : 0]
      end

      # Tells an equipment's weapon or armor type as a value, such as one filter keeps; since it is an
      # Array itself, a block that steers a filter by it answers it inside an Array.
      #
      # @param item [RPG::BaseItem, nil] The item.
      # @return [Array, nil] [:weapon, id] or [:armor, id]; nil for anything else.
      def self.type_key(item)
        return [:weapon, item.wtype_id] if item.respond_to?(:wtype_id)

        item.respond_to?(:atype_id) ? [:armor, item.atype_id] : nil
      end

      # Tells a filter per weapon or armor type among some items, as the game's database names it, the
      # weapons' first, each in the order of its type's id; a type without a name has none.
      #
      # @param rows_or_items [Array] The items, or rows whose :data are items (other rows are
      #   left out), such as equip_rows.
      # @return [Array<Hash>] Each type's :text and :value (type_key).
      def self.type_filters(rows_or_items)
        items = Array(rows_or_items).map { |each| each.is_a?(Hash) ? each[:data] : each }.select { |item| type_key(item) }
        found = {}
        items.each { |item| found[type_key(item)] ||= type_name(item) }
        keys = found.keys.reject { |key| found[key].empty? }.sort_by { |kind, id| [kind == :weapon ? 0 : 1, id.to_i] }
        keys.map { |key| { :text => found[key], :value => key } }
      end

      # Names an item for the log: its name and its kind and id in the game's data.
      #
      # @param item [RPG::BaseItem] The item.
      # @return [String] Such as "Zantetsuken (Weapon 12)".
      def self.item_ref(item)
        "#{item_name(item)} (#{item.class.name.to_s.split('::').last} #{item.respond_to?(:id) ? item.id : '?'})"
      end

      # Names a character for the log: their name and their id in the game's data.
      #
      # @param actor [Game_Actor] The character.
      # @return [String] Such as "Luka (actor 1)".
      def self.actor_ref(actor)
        "#{actor.respond_to?(:name) ? actor.name : actor} (actor #{actor.respond_to?(:id) ? actor.id : '?'})"
      end

      # The letters a gamepad types with where the game has no name entry of its own.
      LETTERS = [("A".."Z").to_a + ("a".."z").to_a, ("0".."9").to_a + [" ", ".", ",", "!", "?", "-", "'", "&", "(", ")", ":", ";", "/", "+", "#", "%"]]

      # The cells of the game's name entry that are no letters: its Page and OK.
      ENTRY_KEYS = 2

      # Reads the pages of the game's own name entry (Window_NameInput), in its translation, each
      # without its Page and OK; LETTERS where the game has none.
      #
      # @return [Array<Array<String>>] The letters of each page.
      def self.letter_pages
        return LETTERS unless defined?(::Window_NameInput)

        pages = ::Window_NameInput.allocate.send(:table)
        pages = pages.map { |page| page.first([page.size - ENTRY_KEYS, 0].max).map { |cell| cell.to_s } }.reject { |page| page.empty? }
        pages.empty? ? LETTERS : pages
      rescue => e
        log_once([:letters, e.class], "the game's letters could not be read, so the framework's own show: #{Logging.failure(e)}")
        LETTERS
      end

      # Finds where a map character, the player (:player) or a sprite shows on the screen, for a root
      # that follows it, with the shake of the map its viewport adds.
      #
      # The map frees and rebuilds every character sprite on a map change, so a freed sprite of a
      # character hands over to its character, whose new sprite then shows.
      #
      # @param target [Symbol, Integer, Game_Character, Sprite] What is followed: the player
      #   (:player), the event of an id on this map, a character or a sprite.
      # @return [Hash, nil] :x (its middle), :y (its feet), :height, :viewport and :tile (its map
      #   place; for a sprite its character's, nil for a sprite of none); nil while it does not show:
      #   none, gone, see-through, on another map, with no sprite that shows or on a freed viewport.
      def self.anchor_of(target)
        target = $game_player if target == :player
        target = $game_map && $game_map.events[target] if target.is_a?(Integer)
        return nil if target.nil?
        if Object.const_defined?(:Sprite) && target.is_a?(::Sprite)
          return sprite_anchor(target) unless target.disposed? && target.respond_to?(:character) && target.character

          target = target.character
        end
        return nil unless target.respond_to?(:screen_x) && !(target.respond_to?(:transparent) && target.transparent)

        sprite = character_sprite(target)
        return nil unless sprite && !sprite.disposed? && sprite.visible && sprite.opacity.to_i > 0 && !UI.freed?(sprite.viewport)

        x, y = on_screen(sprite.viewport, target.screen_x.round, target.screen_y.round)
        { :x => x, :y => y, :height => sprite.src_rect ? sprite.src_rect.height : TILE, :viewport => sprite.viewport, :tile => [target.x, target.y] }
      end

      # The side of a map tile in pixels.
      TILE = 32

      # Finds where a sprite shows on the screen.
      #
      # @param sprite [Sprite] The sprite.
      # @return [Hash, nil] See anchor_of; nil while it does not show.
      def self.sprite_anchor(sprite)
        return nil if sprite.disposed? || !sprite.visible || sprite.opacity.to_i <= 0 || UI.freed?(sprite.viewport)

        height = sprite.src_rect ? sprite.src_rect.height : (sprite.bitmap ? sprite.bitmap.height : 0)
        width = sprite.src_rect ? sprite.src_rect.width : (sprite.bitmap ? sprite.bitmap.width : 0)
        x, y = on_screen(sprite.viewport, sprite.x - sprite.ox.to_i + width / 2, sprite.y - sprite.oy.to_i + height)
        character = sprite.respond_to?(:character) ? sprite.character : nil
        tile = character.respond_to?(:x) && character.respond_to?(:y) ? [character.x, character.y] : nil
        { :x => x, :y => y, :height => height, :viewport => sprite.viewport, :tile => tile }
      end
      private_class_method :sprite_anchor

      # Finds the sprite of a map character: in the scene's spriteset, else the newest one made that
      # shows, such as on the live map behind a menu or among a mod's own sprites.
      #
      # @param character [Game_Character] The character.
      # @return [Sprite, nil] Its sprite, nil when the screen shows none of it.
      def self.character_sprite(character)
        scene = current_scene
        spriteset = scene && scene.instance_variable_get(:@spriteset)
        sprites = spriteset && spriteset.instance_variable_get(:@character_sprites)
        if sprites.is_a?(Array)
          # A return from inside a block makes an object in the game's Ruby, a loop none.
          place = 0
          while place < sprites.size
            sprite = sprites[place]
            return sprite if sprite.respond_to?(:character) && sprite.character.equal?(character)

            place += 1
          end
        end
        @character_sprites.reverse.find { |sprite| !sprite.disposed? && sprite.character.equal?(character) && sprite.visible }
      end
      private_class_method :character_sprite

      # Turns a place on a viewport into one on the screen, with the viewport's shake.
      #
      # @param viewport [Viewport, nil] The viewport, nil for the screen.
      # @param x [Integer] The left on the viewport.
      # @param y [Integer] The top on the viewport.
      # @return [Array<Integer>] The left and the top on the screen.
      def self.on_screen(viewport, x, y)
        return [x, y] unless viewport

        [viewport.rect.x + x - viewport.ox.to_i, viewport.rect.y + y - viewport.oy.to_i]
      end
      private_class_method :on_screen

      # Tells the game's scene, for what asks every frame.
      #
      # defined? makes a String on every call in the game's Ruby, const_defined? none.
      #
      # @return [Scene_Base, nil] The scene, nil where the game has none.
      def self.current_scene
        Object.const_defined?(:SceneManager) ? ::SceneManager.scene : nil
      end

      # Finds the scene's top viewport, over its pictures and weather and under the game's windows,
      # which neither the screen's tone nor its flash reaches, for a root drawn :under_windows and a
      # wheel that follows a character.
      #
      # @return [Viewport, nil] The viewport, nil in a scene without one.
      def self.top_viewport
        scene = current_scene
        spriteset = scene && scene.instance_variable_get(:@spriteset)
        viewport = spriteset && spriteset.instance_variable_get(:@viewport3)
        viewport && !UI.freed?(viewport) ? viewport : nil
      end

      # Finds the viewport a root that follows a character draws on: the scene's top viewport where
      # the character lies on the scene's map or battle, which neither the screen's tone nor its
      # flash reaches; else the character's own, such as a map a menu draws on behind its windows.
      #
      # @param viewport [Viewport, nil] The viewport the character's sprite lies on.
      # @return [Viewport, nil] The viewport, nil for the screen.
      def self.follow_viewport(viewport)
        scene = current_scene
        spriteset = viewport && scene && scene.instance_variable_get(:@spriteset)
        return viewport unless spriteset && spriteset.instance_variable_get(:@viewport1).equal?(viewport)

        top_viewport || viewport
      end

      # Tells whether the game shows a CG: a novel scene of the story runs, or the map or the battle
      # shows a CG that covers the screen. Asked by every hud each frame, so it reads the game once a
      # frame.
      #
      # @return [Boolean] Whether it does.
      def self.cutscene?
        frame = Engine::Key.frame
        return @cutscene if @cutscene_frame == frame

        @cutscene_frame = frame
        @cutscene = cutscene_now?
      end

      # Reads whether the game shows a CG now, see cutscene?.
      #
      # @return [Boolean] Whether it does.
      def self.cutscene_now?
        return true if $game_party && $game_party.respond_to?(:in_novel) && $game_party.in_novel

        scene = current_scene
        owner = Object.const_defined?(:Scene_Battle) && scene.is_a?(::Scene_Battle) ? $game_troop : $game_map
        screen = owner.respond_to?(:screen) ? owner.screen : nil
        return false unless screen && screen.respond_to?(:pictures)

        pictures = screen.pictures
        # Game_Pictures#each compacts its pictures into a new Array on every call.
        held = pictures.instance_variable_get(:@data) if pictures.instance_variable_defined?(:@data)
        return pictures.any? { |picture| picture && covers_screen?(picture) } unless held.is_a?(Array)

        place = 0
        while place < held.size
          return true if held[place] && covers_screen?(held[place])

          place += 1
        end
        false
      rescue => e
        log_once([:cutscene, e.class], "reading the game's pictures FAILED, so no CG is taken to show: #{e.class}: #{e.message}")
        false
      end
      private_class_method :cutscene_now?

      # Tells whether a picture is a CG by its name that covers COVER_SHARE of the screen, worked
      # out again only once the picture changed.
      #
      # @param picture [Game_Picture] The picture.
      # @return [Boolean] Whether it is.
      def self.covers_screen?(picture)
        seen = @pictures_seen[picture]
        if seen && seen[0] == picture.name && seen[1] == picture.opacity && seen[2] == picture.zoom_x && seen[3] == picture.zoom_y &&
           seen[4] == picture.x && seen[5] == picture.y && seen[6] == picture.origin
          return seen[7]
        end

        @pictures_seen.clear if @pictures_seen.size >= PICTURES_KEPT
        covers = cg_covering?(picture)
        @pictures_seen[picture] = [picture.name, picture.opacity, picture.zoom_x, picture.zoom_y, picture.x, picture.y, picture.origin, covers]
        covers
      end
      private_class_method :covers_screen?

      # Works out whether a picture is a CG by its name that covers COVER_SHARE of the screen.
      #
      # @param picture [Game_Picture] The picture.
      # @return [Boolean] Whether it is.
      def self.cg_covering?(picture)
        return false unless picture.name.to_s =~ CG_NAMES && picture.opacity >= COVER_ALPHA

        bitmap = Cache.picture(picture.name)
        width = bitmap.width * picture.zoom_x / 100.0
        height = bitmap.height * picture.zoom_y / 100.0
        left = picture.origin == 0 ? picture.x : picture.x - width / 2
        top = picture.origin == 0 ? picture.y : picture.y - height / 2
        across = [[left + width, Graphics.width].min - [left, 0].max, 0].max
        down = [[top + height, Graphics.height].min - [top, 0].max, 0].max
        across * down >= COVER_SHARE * Graphics.width * Graphics.height
      end
      private_class_method :cg_covering?

      # Tells whether the player stands free on the map, as a wheel or a screen of the map asks
      # before it opens.
      #
      # @return [Boolean] Whether they do, see map_free_reason.
      def self.map_free?
        map_free_reason.nil?
      end

      # Tells why the player does not stand free on the map: the map is not the scene, an event
      # runs, a message shows, a transfer or a scene change waits, or a move route moves the player.
      #
      # @return [String, nil] Why, nil while they stand free.
      def self.map_free_reason
        scene = current_scene
        return "the map is not the scene" unless Object.const_defined?(:Scene_Map) && scene.is_a?(::Scene_Map)
        return "a scene change waits" if scene.respond_to?(:scene_changing?) && scene.scene_changing?
        return "an event runs" if $game_map && $game_map.respond_to?(:interpreter) && $game_map.interpreter.running?
        return "a message shows" if $game_message && ($game_message.busy? || $game_message.visible)
        return "the player moves to another map" if $game_player && $game_player.transfer?
        return "a move route moves the player" if $game_player && $game_player.move_route_forcing

        nil
      end

      # Tells whether the game's message shows at the top of the screen, which a HUD at the top
      # would lie under.
      #
      # @return [Boolean] Whether it does.
      def self.top_message?
        $game_message && $game_message.visible && $game_message.position == 0 ? true : false
      end

      # Tells the name the game shows for one of its buttons in its key help (Vocab.key_y and the
      # others): its key on the keyboard, or its number on a gamepad, by the player's setting; the
      # key the player bound in F1 once that is not the game's own.
      #
      # @param button [Symbol] The button, such as :Y.
      # @return [String] Its name, such as "S"; KEY_NAMES where the game names none.
      def self.key_name(button)
        bound = Engine::Pad.key_name(button.to_sym)
        return bound if bound

        fallback = KEY_NAMES[button.to_sym] || button.to_s
        reader = "key_#{button.to_s.downcase}"
        return fallback unless KEY_NAMES.key?(button.to_sym) && defined?(::Vocab) && ::Vocab.respond_to?(reader)

        name = ::Vocab.send(reader).to_s
        name.empty? ? fallback : name
      rescue => e
        log_once([:key_name, e.class], "the name of a button could not be read, so it is the keyboard's: #{Logging.failure(e)}")
        fallback
      end

      # Tells a term of the game's Vocab, as the game's translation names it, such as :optimize.
      #
      # @param name [Symbol] The term, such as :optimize, :clear or :equip.
      # @return [String] Its text; the name itself for a term the game lacks.
      def self.term(name)
        Vocab.respond_to?(name) ? Vocab.send(name).to_s : name.to_s
      end

      # Steps from a character to the menu's character before or after, as the game's menu screens
      # do with L and R (menu_actor_prev and menu_actor_next), so whoever the game's menu order
      # skips is skipped here too, with the game's cursor sound when the character changed.
      #
      # @param actor [Game_Actor, nil] The character shown now; nil for the menu's own.
      # @param step [Integer] -1 for the one before, 1 for the one after.
      # @param options [Hash] :sound (false plays no sound).
      # @return [Game_Actor, nil] The character now the menu's, nil when it stayed the same.
      def self.next_actor(actor, step, options = {})
        return nil unless $game_party && step != 0

        $game_party.menu_actor = actor if actor
        before = $game_party.menu_actor
        after = step < 0 ? $game_party.menu_actor_prev : $game_party.menu_actor_next
        return log("Character switch #{step < 0 ? 'back' : 'on'} from #{before ? actor_ref(before) : 'nobody'} refused: no other character") if after.nil? || after.equal?(before)

        log("Character switch #{step < 0 ? 'back' : 'on'}: #{before ? actor_ref(before) : 'nobody'} to #{actor_ref(after)}")
        Sound.play_cursor if options.fetch(:sound, true)
        after
      end

      # Tells whether a character can wear an item in a slot, as the game's equip list tells.
      #
      # @param actor [Game_Actor] The character.
      # @param slot [Integer] The slot.
      # @param item [RPG::BaseItem] The item.
      # @return [Boolean] Whether it can.
      def self.fits_slot?(actor, slot, item)
        return false if defined?(::RPG::EquipItem) && !item.is_a?(::RPG::EquipItem)
        return false unless actor.equippable?(item)

        actor.respond_to?(:equippable_slot?) ? actor.equippable_slot?(slot, item) : item.etype_id == actor.equip_slots[slot]
      end
      private_class_method :fits_slot?
    end

    Run.on_start("character sprites") { Mod_Framework::UI::Game.watch_character_sprites }
  end
end
