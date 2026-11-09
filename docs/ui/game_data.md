<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Game parts](README.md#game-parts)
<!-- /nav -->

# Game data

`UI::Game` and `UI::Equip` read the game's own data the way its menus show it: the party, a
character's stats and gear, an item's stats, effects, gems and sets. They only read; nothing here
changes the game. A component that reads them in its `render` renders again once that part of the
game changes, such as after a new piece of gear or a gem set into an item.

## Examples

### The weapon a character wears, with its elements

```ruby
weapon = UI::Equip.item(actor, 0)
icons = UI::Equip.elements(weapon).map { |element| element[:icon] }
basic, rates = UI::Equip.stats(weapon)
header UI::Game.item_name(weapon), icon: weapon.icon_index, title_color: UI::Game.item_color(weapon), subtitle: UI::Game.type_name(weapon),
       title_after: icons.empty? ? nil : -> { chip_set { chip icons: icons } }
stat_grid basic + rates, columns: 2, size: :small, dense: true
lines UI::Equip.effects(weapon, actor: actor), columns: :room, sort: true, escapes: true
```

An item without stats or effects shows `UI::Equip::NOTHING_TEXT` in their place: both `stats` and
`effects` are then empty.

### An item from the bag set against the worn one

```ruby
worn = UI::Equip.item(actor, slot)
after = UI::Equip.gems_after(worn, item)
compared = UI::Equip.compare(worn, item, gems: after[:gems])
stat_grid compared[:item][0], before: compared[:worn][0], columns: 2, size: :small, dense: true
lines UI::Equip.effects(item, gems: after[:gems], shared: compared[:shared], actor: actor), columns: :room, sort: true, escapes: true
```

`before:` colors the stats the new item raises or lowers, and the effect lines both items have fold
into one line, "2 shared effects". `after[:worn_notes]` tells per socket where each worn gem goes,
"Stays in this item" or "Moves to" the new item, and `after[:item_notes]` which gems move over.

### A gem of the bag

```ruby
gem = UI::Equip.gem_bag.first
info = UI::Equip.gem_info(gem)
text UI::Game.item_name(gem), color: UI::Game.item_color(gem)
lines info[:lines], size: :tiny
```

## The gear: `UI::Equip`

| Call | Tells |
|---|---|
| `item(actor, slot)` | the item a character wears in a slot, nil for an empty one |
| `slot_rows(actor)` | a character's slots as rows of a `list`, an empty slot as a faint row |
| `item_rows(actor, slot)` | the items a character can wear in a slot as rows of a `list`: a Remove row while the slot holds an item, then the bag's items with their counts |
| `gem_rows(item, socket)` | the bag's gems that go into a socket as rows of a `list`, after a Remove gem row |
| `slot_note(actor, slot)` | the line under an item's name: the slot's name and the item's type, and the color it shows in, the warning color when the slot is fixed |
| `socketed?(item)` | whether an item has sockets |
| `gems_text(item)` | how many sockets hold a gem, such as `"1/2"` |
| `in_set?(item)` | whether an item belongs to a set |
| `gems_changeable?(actor, slot)` | whether the gems in a character's slot can change: its item has sockets and the slot is not fixed |
| `gems_fixed?(actor, item, slot)` | whether a character wears an item with sockets where its gems cannot change; without `slot` the slot that holds it |
| `stats(item, gems: ...)` | the stats an item adds with its gems: `[parameter rows, rate rows]` for a `stat_grid`; `gems:` reads it with other gems |
| `sockets(item)` | the gem in each socket, nil for an empty one |
| `elements(item)` | the elements an item strikes with that show by its name, at most three with an icon: each `{ id:, name:, icon: }` |
| `compare(worn, item, gems: ...)` | both items' stats, paired so each stat has a row on both sides: `{ worn:, item:, shared: }`, `shared:` the effect lines both have |
| `gems_after(worn, item)` | what putting the item on does with the gems: `{ gems:, kept:, moved:, worn_notes:, worn_note:, item_notes:, item_note: }`, each note a text and its color |
| `room(items, worn)` | the items of a list that likely need the most room set against the worn one, for `compact_for:`; given one item, what it likely takes |
| `effects(item, actor: ..., shared: ..., gems: ...)` | an item's effect lines in groups for `lines`; with `actor:` a gold line per set, with `shared:` the lines another item has fold into one |
| `base_stats(item)` | the game's own Base Stats of the item, without its gems, as `stat_grid` rows |
| `special_effects(item)` | the game's own Special Effects in groups for `lines`, without the traits of its type |
| `type_lines(item)` | the traits an item has by its type, such as a weapon's normal attack |
| `set_lines(item, actor)` | each set the item belongs to: `{ name:, worn:, size:, note:, color:, lines: }`, `lines:` a group per step, faint until the character wears enough pieces |
| `gem_info(gem)` | what a gem adds: `{ elements:, stats:, effects:, lines:, brief:, description:, color: }` |
| `gem_preview(item, socket, gem, actor: ..., slot: ...)` | what setting a gem, or nil to empty the socket, would change, and `note:` and `refusal:`, why the game would refuse it |
| `gem_colors(item, socket, tooltip: ...)` | a filter per gem color for a socket, such as for a `toggle_group`: `{ icon:, value:, tooltip:, disabled: }`, off where the bag has none or another socket holds one |
| `gem_color(gem)` | a gem's color, the value its filter in `gem_colors` has |
| `gem_bag` | the gems in the bag, which the game offers for its sockets |
| `stats_with(actor, slot, item)` | the eight parameters a character would have wearing an item in a slot, on a copy of the character; given a list of items, one such list per item, much faster than a call per item |

## Items and characters: `UI::Game`

| Call | Tells |
|---|---|
| `item_name(item)` | an item's name as the game's menus show it |
| `item_color(item)` | the game's text color of an item's name, for `title_color:` or `color:` |
| `type_name(item)` | an equipment's weapon or armor type, such as `"Sword"` |
| `type_key(item)` | an equipment's type as a value, `[:weapon, id]` or `[:armor, id]` |
| `type_filters(rows)` | a filter per weapon or armor type of some items or rows, such as for a `select`: `{ text:, value: }` |
| `element_icon(element)` | the icon of an element, by its id or name |
| `element_name(id)` | an element's name |
| `favorite?(item)` | whether the party marked an item a favorite |
| `favorite_icon` | the star of a favorite |
| `favorite_text(on)` | the game's words of marking an item a favorite, or with `true` of taking the mark away |
| `empty_socket_icon` | the icon of a socket without a gem |
| `stat_rows(actor, params: ..., rates: ...)` | a character's stats as `stat_grid` rows, the parameters, then the rates |
| `actor_title(actor)` | a character's name and level, such as `"Luka  Lv 42"` |
| `slot_name(actor, slot)` | a slot's name, such as `"Weapon"` |
| `param_short(id)` | a parameter's short name, such as `"ATK"` |
| `number(value)`, `added(value)` | a number as the game writes it, big ones with its units; `added` with its sign |
| `next_actor(actor, step)` | the menu's character before (`-1`) or after (`1`) a character, as the game's menus step with Q and W, with the cursor sound; nil when there is no other; `sound: false` plays none |
| `item_ref(item)`, `actor_ref(actor)` | an item or a character named for the log, such as `"Zantetsuken (Weapon 12)"` and `"Luka (actor 1)"` |
| `REMOVE` | the `data:` of the Remove row of `UI::Equip.item_rows` and `gem_rows`, which a pick hands back |

## The party and the game: `UI::Game`

| Call | Tells |
|---|---|
| `members`, `leader` | the party's members and its leader |
| `gold`, `count(item)` | the party's gold, how many of an item it holds |
| `level(actor)`, `states(battler)`, `equips(actor)` | a character's level, a battler's states, a character's gear |
| `hp_rate(battler)`, `mp_rate(battler)`, `tp_rate(battler)` | HP, MP and TP as a share from 0.0 to 1.0, for a `progress` |
| `mhp(battler)`, `mmp(battler)` | max HP and max MP |
| `variable(id)`, `switch(id)` | a game variable and a game switch |
| `map_id`, `map_name` | the map the player is on |
| `map_free?`, `map_free_reason` | whether the player stands free on the map, and why not |
| `cutscene?`, `top_message?` | whether the game shows a CG, and its message at the top of the screen |
| `term(name)`, `key_name(button)` | a term of the game, such as `:optimize`, and the key a button is bound to, such as `"S"` |

<!-- nav -->
---

← [Command](command.md) · [All components](README.md) · [Colors](colors.md) →
<!-- /nav -->
