<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Options

`Mod_Framework::Options` adds the rows of your mod to Options > Mods in the game's Options. The
player picks a mod on the left, and its rows show on the right, its hotkeys after them under
"Hotkeys". A row joins its mod by the name in brackets its name starts with, "[Camp Notes] ...".

## Examples

### Rows of your own

```ruby
module Camp_Notes_Options
  Mod_Framework::Options.add(:camp_notes_count, "[Camp Notes] Show Count",
                             "Whether the menu's Notes command shows how many notes there are.",
                             { 1 => "On", 0 => "Off" }, 1) { |value| Mod_Framework.log("Show Count: #{value}") }

  Mod_Framework::Options.keep(:camp_notes_corner, "[Camp Notes] Corner", "Where the notes window opens.", ["Left", "Right"],
                              -> { Mod_Framework::Settings.setting("camp_notes_corner") || "Left" },
                              ->(value) { Mod_Framework::Settings.store("camp_notes_corner", value) })
end
```

- `Options.add(key, name, help, values, default) { |value| }` keeps a value in the save, as the game
  keeps its own options. `values` gives each value its name, or `[name, help]`. The block runs with
  the new value.
- `Options.value(key)` reads the player's pick, else the default, such as while no game is loaded.
- `Options.keep(key, name, help, values, read, write)` keeps a value your mod keeps itself, the same
  in every save, such as in [Settings](settings.md): `values` lists the texts the row shows (or a
  lambda answers them), `read` answers the current one, and `write` takes the one picked. The rows
  ask `read` again every few frames while they show, so a value your mod changes elsewhere shows.
- Both take `disabled: -> { ... }` (greyed out while true) and `if: -> { ... }` (shown only while
  true).
- `Options.mods` lists the mods that have rows that show now, and `Options.rows_of("Camp Notes")`
  the rows of one.
- An [options list](options_list.md) shows the rows in a window of your own.

### At the title

The title's Mods box opens the Mod Configuration, laid out as Options > Mods, before any save is
loaded. It shows the framework and the Framework and Title mods with their hotkeys and the rows
kept with `Options.keep`, since no save holds the others there, and the Default mods that are on
with their hotkeys alone. A row of `Options.add` shows only in the game.

### A row greyed out

A mod greys out a row of Options > Mods, such as one it sets for the player, through the rows of
`#mf_mod_options_list`; the row keeps its help and takes no change:

```ruby
Mod_Framework::UI.patch "#mf_mod_options" do |t|
  t.rows "#mf_mod_options_list" do |rows|
    rows.map { |row| row[:key] == :camp_notes_count ? row.merge(disabled: true) : row }
  end
end
```

## Mods made for Mod Config Remake

The framework keeps the interface of Mod Config Remake and the Mod Config Menu, so a mod made for
them works unchanged: its rows inserted into `NWConst::Config::MOD_CONTENTS` show in Options > Mods.
`ModConfigRemake::Keys` is there only while the DLL works, so check `defined?(ModConfigRemake::Keys)`
before a hotkey row.

<!-- nav -->
---

← [Mod](mod.md) · [All components](README.md) · [Hotkeys](hotkeys.md) →
<!-- /nav -->
