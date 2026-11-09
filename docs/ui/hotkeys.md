<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Hotkeys

`Mod_Framework::Hotkeys` keeps the hotkeys of every mod. A mod defines a hotkey once, and the player
binds it to another key in Options > Mods, or at the title in the Mod Configuration. A screen needs
no hotkey of its own, since the keys below reach every part: give a part a hotkey only where players
asked for one or where your screen mirrors one of the game's own that has it.

## The keys every window knows

They work in every window of the framework as in the game's own menus, and mods do not redefine
them. The player binds the game's buttons in F1.

| Key | Keyboard | Pad | Does |
|---|---|---|---|
| Confirm | Enter, Space, Z | A | press, pick, go into a box |
| Cancel | Esc, X, Numpad 0 | B | step back, then close |
| Arrows | arrow keys | d-pad, stick | move the focus and the cursor |
| Q, W | Q, W | | the window's page, such as the Equipment Window's characters |
| Page Up, Page Down | Page Up, Page Down | | page the focused list |
| Tab, Shift+Tab | Tab | | step the nearest tabs, or go into the window's text field and back |
| Shoulders | | LB, RB | the tabs in view that show two or more, else the window's page |
| Jump Out of a List | Ctrl + arrow | A held + d-pad | leave a list toward the parts around it |
| Arranging | left Alt + drag | | move a part; Alt + double click puts it back |

Cancel is the game's cancel key as the player bound it, plus Numpad 0. The framework's own hotkeys
are bindable like a mod's: Accept Notification (Y) and Decline Notification (N), which answer a
question box and the first offer of the notices, Move Up (I) and Move Down (K) in the Mod List, and
Jump Out of a List (Ctrl).

## Examples

### Defining a hotkey

```ruby
module Camp_Notes
  UI = Mod_Framework::UI

  # H on the map writes the party leader's name into the log.
  Mod_Framework::Hotkeys.define(:camp_notes_leader, key: "H", name: "[Camp Notes] Note the Leader",
                                help: "Writes the name of the party leader into the log.",
                                scenes: [Scene_Map]) do
    Mod_Framework.log("#{UI::Game.leader.name} leads the party")
  end
end
```

- `key:` takes a name (`"G"`, `"F5"`) or a key code. `name:` starts with your mod's name in
  brackets, which puts the hotkey after your options under "Hotkeys". The block runs on the
  `scenes:` given, on every scene without.
- Start the hotkey's own name with your mod's name (`:camp_notes_leader`): a second definition
  of a name is refused.
- `log:` names where a failing block is logged, such as your mod's module.

### A hotkey that opens a window

`hotkey :name` in a component class, after the definition, opens that component with the hotkey
and closes its window by it again. `hotkey:` on a `button` presses it, and `show_key: true` draws
the bound key before its text, "J: Journal". A [key help](key_help.md) names by itself the hotkeys
of the part in focus and of the parts it lies in, such as the window's.

```ruby
module Camp_Journal
  UI = Mod_Framework::UI

  Mod_Framework::Hotkeys.define(:camp_journal_open, key: "J", name: "[Camp Journal] Open",
                                help: "Opens the journal of the camp.", scenes: [Scene_Map])

  # The journal, which J opens and closes.
  class JournalWindow < UI::Component
    hotkey :camp_journal_open

    def render
      window "Camp journal", width: 320 do
        text "The party rests by the fire."
        key_help
      end
    end
  end
end
```

## Rules

- **The framework's keys are never a hotkey's.** A `key:` on Tab, Enter, Space, the arrows, Page Up,
  Page Down, Home, End, the Menu key, the left Alt, the jump key, Esc, Numpad 0 or a key F1 binds to
  confirm, cancel, L or R (such as Z, X, Q and W) is refused with a line in the log, and the hotkey
  stays unbound. A key kept from an older binding there is ignored, and the hotkey keeps its default.
- **No two hotkeys share a key the player bound.** Where a kept key, or a default in place of a
  refused one, is another hotkey's, the hotkey stays unbound with a line in the log until the player
  binds it a key. Two defaults may share a key.
- **A hotkey stays quiet** while any mod types, while a window above holds the game's buttons, while
  its part is hidden, and outside its `scenes:`; the log names each refusal. On a key F1 binds to
  one of the game's extra buttons (Shift, A, S and D) it works wherever no screen uses that button.
- **A hotkey of a mod that is not loaded is remembered,** so the Mod Configuration lists it while
  the mod is on, and a key the player binds there reaches it once the mod defines it again. Once
  the mod loads without defining it, it is forgotten.
- `Hotkeys.pressed?(name)`, `code(name)`, `label(name)` and `bind(name, code)` read and change a
  hotkey from your code.

## The game's extra buttons

Where your screen mirrors one of the game's own that uses its extra buttons, a window, dialog,
paper, stack or list takes them with `on_button: { z: -> { open_filter } }` (the game's `:a`, `:x`,
`:y` and `:z`: Shift, A, S and D on the keyboard), and `button_help: { z: "Filter" }` names them in
the key help, "D: Filter".

## Outside the framework's parts

- `UI.typing?` tells whether the player types into a text field of any mod now; meanwhile the
  hotkeys of every mod stay quiet.
- `UI.cancel?` tells whether the player cancelled in this frame by the keys every window takes, for
  a sprite of your own.
- Hints name the keys as the player bound them: `UI.close_hint` gives "X or Numpad 0: close" and
  `UI.cancel_keys` "X or Numpad 0" ("Esc or Numpad 0" while a field types). Never write "Esc" into
  a hint yourself.
- `UI.pad?` tells whether the player used a gamepad last, so a hint of your own names the pad's
  buttons.
- `UI.pad_trigger?(:L)` tells whether one of the game's buttons went down on a gamepad in this
  frame and not on the keyboard, so the pad's shoulders step the tabs of a sprite of your own while
  Q and W stay for its page. Ask it every frame from when your sprite listens.

<!-- nav -->
---

← [Options](options.md) · [All components](README.md) · [Settings](settings.md) →
<!-- /nav -->
