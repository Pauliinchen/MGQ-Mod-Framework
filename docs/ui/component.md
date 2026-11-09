<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Component

`UI::Component` is the class every screen of your mod starts from. Its `render` writes markup,
one call per part, and the framework lays the parts out, draws them, moves the focus and renders
again when your data changes. `UI.open` opens a component whose top part is a `window`, `dialog`
or `wheel`; `UI.show` shows one whose top part is a `hud`, `bubble` or `marker`.

## Examples

### A whole mod

The command Notes in the game's menu opens a window that lists notes and clears the picked one:

```ruby
module Camp_Notes
  UI = Mod_Framework::UI

  # The notes window.
  class NotesWindow < UI::Component
    # The notes, one per row.
    state(:notes) { ["Buy Herbs in Iliasburg", "Visit the Harpy Village"] }

    # The note under the list's cursor.
    state :picked

    # Describes the window.
    def render
      window "Camp notes", id: :camp_notes, width: 320 do
        list notes, bind: :picked, dense: true, empty: "No notes yet"
        stack row: true, justify: :end do
          button "Clear", id: :clear, color: :error, disabled: picked.nil?, on_click: -> { clear }
          button "Close", on_click: :close
        end
      end
    end

    # Removes the picked note.
    def clear
      self.notes = notes - [picked]
    end
  end

  # A Notes command after Formation in the game's menu.
  UI.patch "Window_MenuCommand" do |menu|
    menu.after "#formation" do
      command "Notes", id: :camp_notes, on_click: -> { UI.open(NotesWindow) }
    end
  end
end
```

With no more code the keys, the mouse and a gamepad work, cancel closes the window, Clear greys
out while nothing is picked, the player moves the window with Alt and it opens there again, it
wears the look the player picked, and the menu takes the keys back once it closes.

### A component of your own

A class declares what its caller gives and what it keeps:

| Declaration | Means |
|---|---|
| `param :actor` | a value the caller gives; required |
| `param :max, 99` | with a default |
| `param(:rows) { [] }` | a fresh default per component |
| `param :footer, content: true` | markup the caller hands in as a lambda, placed with `children :footer` |
| `state :page, 0` | the component's own value, written with `self.page = 1` |
| `state(:notes) { [] }` | a fresh default per component |
| `event :pick` | makes the `on_pick:` param, which `emit :pick, value` calls |
| `expose :actor` | a value another mod's `UI.patch` reads with `t.read(:actor)` |
| `action :pulse` | a public method the owner calls through `part(:id).pulse` |
| `watch { My_Mod.serial }` | renders again once the answer changes |
| `hotkey :my_mod_open` | its hotkey opens it and closes it again, see [Hotkeys](hotkeys.md) |

Its markup name is the class name in snake case, `MemberCard` becoming `member_card`, inside the
module that defines it. Elsewhere write `component Party_Picker::MemberCard, actor: a`.

```ruby
module Party_Picker
  UI = Mod_Framework::UI

  # A card of one party member, which the player picks.
  class MemberCard < UI::Component
    param :actor
    event :pick

    def render
      card clickable: true, on_click: -> { emit :pick, actor } do
        card_media face: actor, height: 96, fit: :contain
        card_header actor.name, subtitle: "Level #{UI::Game.level(actor)}"
      end
    end
  end

  # A window of the party's cards, four to a row.
  class PickerWindow < UI::Component
    def render
      window "Party", width: 480 do
        grid do
          $game_party.battle_members.each do |member|
            grid_item xs: 3, key: member.id do
              member_card actor: member, on_pick: ->(actor) { close(actor) }
            end
          end
        end
      end
    end
  end
end
```

- **Params are read-only.** `self.actor = x` raises; keep a copy in a state, `state(:shown) { actor }`.
- **State is written with `self.name = value`**, which renders the component again at the end of the
  frame. `notes = x` without `self.` makes a local variable, and the log hints at that line as the
  mod loads.
- **State values are frozen.** `notes << x` raises; write `self.notes = notes + [x]`.
- **A default is a plain value** (a number, a Symbol, nil, true, false or a text). A list or a Hash
  takes a block, `state(:notes) { [] }`, so components never share one.
- A component takes every param a part takes (`visible:`, `disabled:`, `tooltip:` and the others of
  the [table](README.md#params-every-part-takes)) and hands them to the part at the top of its
  `render`.
- Inside a component, `close(value)`, `toast(text)`, `bubble(target, text)`, `back`, `forward`,
  `emit`, `part(:id)`, `memo` and `opener_size` are methods of its own.
- Write markup blocks with `do ... end`; braces work only after parentheses, `slide(id: :gear) { gear_page }`.
- A part made in a loop needs `key:`, so it keeps its focus and state as the list changes.
- `id:` is a part's public name, which other mods' `UI.patch` uses. Start the ids of your roots
  with your mod's name.
- A `nil` handler, such as `on_click: editable ? -> { edit } : nil`, is no handler.

### Rendering again

`bind: :picked` ties an input, a list, tabs, slides, a drawer or a popover to a state, both ways. A
list binds the item, `bind_index:` its place.

A component renders again when its state changes, a handler of it ran, its params changed, or the
game data it read changed. The framework sees the game data you read through `UI::Game`:

| Read | Renders again when |
|---|---|
| `UI::Game.members`, `leader` | the party changes |
| `UI::Game.gold`, `count(item)` | gold or items change |
| `UI::Game.level(actor)`, `states(actor)`, `equips(actor)` | that character changes |
| `UI::Game.hp_rate(actor)`, `mp_rate(actor)` | the character's HP or MP change |
| `UI::Game.variable(id)`, `switch(id)` | that variable or switch changes |
| `UI::Game.map_name`, `map_id` | the map changes |

Reading `$game_party.gold` directly records nothing, and the log hints at such a line in `render`.
For data the framework cannot see, such as your own mod's, declare a `watch`:

```ruby
module Battle_Tally
  UI = Mod_Framework::UI

  @wins = 0

  # Tells the battles won since the game started.
  def self.wins
    @wins
  end

  # A line at the bottom right with the battles won.
  class TallyBox < UI::Component
    watch { Battle_Tally.wins }

    def render
      hud anchor: :bottom_right do
        text "Battles won: #{Battle_Tally.wins}"
      end
    end
  end
end
```

A value that changes every frame, such as an HP bar, goes to a part's live param as a lambda. Only
that part redraws, and only when what it shows changed. The table of each part's page marks its
live params:

```ruby
module Party_HP
  UI = Mod_Framework::UI

  # A corner box with a health bar per party member.
  class HealthBox < UI::Component
    def render
      hud anchor: :top_right do
        UI::Game.members.each do |member|
          progress value: -> { UI::Game.hp_rate(member) }, max: 1, color: :error, label: member.name,
                   key: member.name
        end
      end
    end
  end
end
```

A component's own params take plain values, never a lambda: give it the actor and read the value
inside its `render`.

### Keeping what a render makes

A lambda written in `render` is a new object on every render, so a part that takes it, such as a
slot row with a tooltip per gem, is made anew each time. `memo(*keys) { ... }` answers what its
block made the render before while the keys stay the same:

```ruby
module Gem_Bar
  UI = Mod_Framework::UI

  # The gems in the sockets of a character's weapon, each with what it adds as its tooltip.
  class GemBar < UI::Component
    param :actor

    def render
      weapon = UI::Equip.item(actor, 0)
      gems = UI::Equip.sockets(weapon)
      window "Gems" do
        slot_row memo(weapon, gems) { gem_slots(gems) }, empty_icon: UI::Game.empty_socket_icon
      end
    end

    # Tells a slot per socket, a gem's with the lines it adds as its tooltip.
    def gem_slots(gems)
      gems.map { |gem| gem && { icon: gem.icon_index, tooltip: -> { lines UI::Equip.gem_info(gem)[:lines], size: :tiny } } }
    end
  end
end
```

Each `memo` in `render` keeps its own answer, also inside a loop, told apart by its place and its
keys; an answer no render asks for again is let go.

### Content the caller hands in

`children` places the caller's block where it is called, and `children :footer` a content param.
`param :footer, content: :text` takes markup as a lambda or a text, which shows as one line of small
text:

```ruby
module Item_Shop
  UI = Mod_Framework::UI

  # A titled box whose caller fills it, with a footer when the caller gives one.
  class Shelf < UI::Component
    param :title
    param :footer, content: :text

    def render
      paper do
        text title, typo: :subtitle1
        children
        children :footer if footer
      end
    end
  end

  # The shop's window, a shelf per kind of item.
  class ShopWindow < UI::Component
    def render
      window "Item Shop" do
        shelf title: "Healing" do
          text "Herb  10 G"
          text "Antidote Grass  15 G"
        end
        shelf title: "Seeds", footer: "One per visit" do
          text "Seed of Power  100 G"
        end
      end
    end
  end
end
```

### Opening, closing and the answer

`UI.open(Klass, params) { |result, why| }` answers a handle (`open?`, `close(value)`, `id`,
`forward`), or nil when nothing opened; the log says why. When a root of the same id is open, that
one comes forward. `close(value)` hands the value to the block; every other close gives nil and the
reason:

| Reason | When |
|---|---|
| `:cancel` | the player cancelled |
| `:outside` | a click outside, with `close_outside: true` |
| `:button` | a button with `on_click: :close` |
| `:hotkey` | its hotkey pressed again |
| `:submit` | a pick in a wheel or a menu |
| `:script` | `close` from your code |
| `:scene` | the scene changed |
| a text | its `if:` answered that text instead of true |

```ruby
module Herb_Shop
  UI = Mod_Framework::UI

  # Asks how many Herbs to buy, at 10 G each.
  class BuyDialog < UI::Component
    state :count, 1

    def render
      dialog "Buy Herbs" do
        numeric_field "How many?", bind: :count, min: 1, max: [UI::Game.gold / 10, 1].max, adornment: "Herbs"
        text "#{count * 10} G", align: :end
        stack row: true, justify: :end do
          button "Back", on_click: :close
          button "Buy", variant: :filled, on_click: -> { close(count) }
        end
      end
    end
  end

  # Opens the dialog and tells what was bought.
  def self.buy
    UI.open(BuyDialog) do |count, why|
      Mod_Framework.toast("Bought #{count} Herbs", severity: :success) if count
      Mod_Framework.log("the herb dialog closed: #{why}")
    end
  end
end
```

`UI.show(Klass, params)` answers a handle with `shown?`, `hide` and `id`. A HUD stays across scene
changes until you hide it; `hide` lets it leave as its `leave:` says, `hide(at_once: true)` takes it
off in the same frame, also one already leaving, such as a box whose battle ends. A window's `on_cancel:` is asked before cancel closes it; answering false
keeps it open. `if: -> { ... }` on a root is asked every frame, and anything but true closes it.
A box without state or methods of its own needs no class: see [Window](window.md#without-a-class)
and [HUD](hud.md#without-a-class).

## Lifecycle

| Method | Runs |
|---|---|
| `setup` | once, after the params and the state exist, before the first render |
| `render` | whenever the component may show something new; it never writes state |
| `mounted` | once, after the first frame it shows |
| `unmounted` | once, as it leaves the screen; its watches and handlers stop |

## Sounds and words

| Call | Does |
|---|---|
| `UI.confirm_sound` | plays the game's confirm sound, such as when a hotkey of your own took effect |
| `UI.buzz(why)` | plays the game's buzzer for something the game refuses and logs `why` when given; it answers nil, so `return UI.buzz("...") unless ok` refuses in one line |
| `UI.counted(count, word, words, verb, verbs)` | writes a count with its word in the plural for any count but one: `UI.counted(3, "gem")` is `"3 gems"`, `UI.counted(1, "gem", "gems", "stays", "stay")` is `"1 gem stays"` |

```ruby
def mark_favorite(item)
  return UI.buzz("a favorite mark: the row holds no item") unless item

  UI.confirm_sound
  self.marked = marked + [item]
  toast "#{UI.counted(marked.size, 'favorite')} marked"
end
```

## What the keys do by themselves

- A part takes the keys only when it does something: a button with `on_click:`, a list with
  `bind:` or a handler, an input. Other parts, and everything inside an `aside`, take only the mouse.
- The focus starts on the first part that takes the keys, or on the one with `autofocus: true`.
- Up or Down into a row of parts lands on the part of the row nearest across, such as from a list
  onto the toggle right above it.
- Lists wrap like the game's own. Ctrl with an arrow (on a gamepad, A held with the d-pad) jumps
  out of a list toward the parts around it.
- Cancel walks back the way the player came: out of a typing field, out of a menu or a popover, out
  of a `paper enter: true`, back from a page of tabs or slides, then `on_cancel`, then it closes.
  Cancel on the part the window opened on closes it at once, whichever way the player came back.
- A window ignores a press that began before it opened, so a held message skip never answers it.
- Inside a window the pointer lights only the row of a list under it. `context_menu:` on any part
  opens a menu on a right click, the Menu key or a gamepad's confirm held half a second.

[Hotkeys](hotkeys.md) lists the keys every window knows.

## Placement

You write no pixel offsets: a window or a dialog sits in the middle and a HUD in the top left
unless `anchor:` names another of the nine zones, `dock:` gives it an edge, or `beside:` puts it
next to another part. [Window](window.md) and [HUD](hud.md) show each. The player moves every top
part with Alt and the mouse unless it says `movable: false`; it keeps its place under your mod's
name and its `id:`. `UI.arranging?` tells whether the player arranges the parts now, such as for a
HUD that names itself only then: `text "Party HP", visible: -> { UI.arranging? }`.

`UI.column :battle_left, at: [8, 88], gap: 8, align: :left` defines a named column once, as the mod
loads: each HUD given `column: :battle_left` stacks there, the newest on top, each by the height
its layout gives it, and the player does not move it. [A column of boxes](hud.md#a-column-of-boxes)
shows it.

`opener_size` tells a dialog the `[width, height]` of the window whose handler or render opened it,
or nil before that window has a place, such as for a list that shows more rows in a taller window:
`list rows, most_rows: opener_size ? opener_size[1] / 40 : 6`.

## Mistakes

A mistake raises at your call with your file and line and the nearest right name:
`button takes no colour:; did you mean color:?`. A raise inside `render` keeps the last good look of
the component and is logged once, see [Mod](mod.md#logs).

<!-- nav -->
---

[All components](README.md) · [Mod](mod.md) →
<!-- /nav -->
