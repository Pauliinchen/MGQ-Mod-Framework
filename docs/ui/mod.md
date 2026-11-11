<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Mod

A mod is a script at the top of the game's `Patch` folder, with a folder of the same name beside it
when it has more files: `Patch/Camp_Notes.rb` and `Patch/Camp_Notes/`. The framework's own script,
`Patch/!Mod_Framework.rb`, runs first and loads every mod itself, so your script calls the framework
from its first line. `Mod_Framework::Mods` tells when your mod loads, starts the game again, and
installs and updates mods of the website.

## Your package

- Your mod is its package: every file your zip or script puts into `Patch` is your mod's, whatever
  its name, and installs, updates and goes away with it. An update also removes the files of your
  older versions that the player has not changed, such as a script you renamed.
- A zip holds your files as they lie in `Patch`, or laid out like the game folder under `Patch/`.
  Then only the files under `Patch/` are installed, and a changelog beside it stays out.
- A package is at most one mod to the loader: one script at the top, or one folder of scripts
  alone; a package of pictures without scripts is fine too. Its name in the Mod List and `Mods.ini`
  is that script's name, such as `0_Camp_Notes` for `0_Camp_Notes.rb`.
- No package may hold the game's loader `Patch.rb` or the framework's files (`!Mod_Framework.rb`,
  `Mod_Framework/`). The website refuses such an upload, and one that is two mods to the loader.

## Your files

- The framework loads each mod under its own file name: `__FILE__` is `"Patch/Camp_Notes.rb"`.
- The `.rb` files in your mod's folder run after your script, sorted by path. `.rbx` files are
  yours to load.
- A folder of scripts alone (`Patch/Camp_Notes/`) is one mod named after the folder.
- `Mods.folder` names your folder, `Mods.folder("Other_Mod")` another mod's, nil for none.

## Tags: when your mod loads

Your mod's tag comes from the website, picked when you upload it. A mod the website does not know
is Default (`Regular` in Mods.ini and code). Players never change a tag, and there is no Mod.ini.

| Tag | Loads |
|---|---|
| Framework | as the game starts running, before its first scene |
| Title | its title part as the game starts running; the rest as the player enters the game, only when it is among the mods of that session |
| Default | as the player enters the game: New Game, a save's load, or a mod's own way in |
| Data | as the player enters the game, after the Default mods; the game then reads its database again |

Within a tag the mods load after the mods they need, then as their authors' load order hints on the
website say, then by name, unless the player moved them in the Mod List. A mod that fails to load
is written into the log and named in the Mod List; the others load all the same.
`Mods.failed_last(name)` tells why a mod failed, also in the last game session.

A Default mod loads after the game started, and the framework takes care of what that changes:
the `SceneManager.run` wrappers a mod sets up run once, the game reads its database again once the
mods loaded when a Data mod loaded or a mod hooked `DataManager.load_database` or
`load_normal_database`, the New Game or the load that entered runs again, and hooks, hotkeys,
options and `Run.on_start` blocks registered then take effect at once. A mod that changes the title
screen must be a Title mod.

## Title mods

A Title mod adds only what the title needs at the start, such as a command; the rest loads as the
player enters the game, so turning it off never needs a restart:

```ruby
module My_Menu
  # The title part: a row in the title's Mods box and the screen it opens.
  Mod_Framework::Mods.title_command("My Menu", in: :mods) do |_window|
    Mod_Framework::Mods.load_part("Title/menu.rbx")
  end

  # The rest: everything that runs in the game.
  Mod_Framework::Mods.on_enter("My Menu") { Mod_Framework::Mods.load_part("Game") }
end
```

- `title_command(name, options) { |window| }` adds a command. With `in: :mods` it is a row of the
  title's Mods box, under Browser, List and Configuration; else it goes on the title's commands
  before Shutdown. `after:`, `before:`, `disabled:`, `if:`, `icon:` and `badge:` place, gate and
  mark it.
- `load_part(path)` loads a script, or a folder of `.rbx` scripts, of your mod once per game session.
- `on_enter(tag) { }` runs as the player enters the game, before the Default mods load.
- A plain script tagged Title that names none of these calls loads whole at the title.
- `Mods.enter(reason, only: names)`: a mod with a way of its own into the game calls it before that
  way sets up or loads the game; `only:` names the mods of the session, such as a world's.
  `Mods.stays_on` lists the mods that run from the start and stay, `Mods.running?(name)` tells it of
  one.
- `Mods.load_late(reason) { }`: a block that loads scripts the framework does not load itself, once
  the game runs, such as by `eval`, goes through the same steps as entering: the `SceneManager.run`
  wrappers set up once and the database is read again when a script wrapped its read. It answers
  the block's value.

## Back to the title starts the game again

Nothing takes a loaded mod out of the game, so once a Default mod loaded, every way back to the
title (To Title, a game over, F12) starts the game again: right before the game closes, the
framework starts the game's own Game.exe once more. On JoiPlay the game closes and the player
starts it. A mod can start the game again itself and carry one action to the title of the game
that starts:

```ruby
module My_World
  Mod_Framework::Mods.after_restart("my-world.open", "My World") { |place| Mod_Framework.log("opening #{place}") }

  # Starts the game again, which then opens a place of the world at its title.
  def self.restart_into(place)
    Mod_Framework::Mods.restart("My World changed its mods", "my-world.open", place)
  end
end
```

- `restart(reason, action, value)` answers `:restarting` or `:closing`; the game ends after this
  frame. The framework's own action `"load"` loads the save of that index:
  `Mods.restart("Load save 3", "load", 3)`.
- `after_restart(name, tag) { |value| }` runs at the first title of the game that started again.
  Register it at the start, in a Framework or Title mod. A name is lower-case letters, digits and
  `.` `_` `-`, starting with your mod's name.
- `restart_needed?` tells whether going back to the title starts the game again, and
  `carry_after_restart(name, value)` has the next restart that names no action carry this one.
- A screen of your own at the title adds a change that counts only after a restart to the Mod
  List's restart bar with `Mods.wait_for_restart(key, text)`, and takes it back with
  `Mods.unwait(key)`.

## Saves and the mods a place needs

Every save keeps the mods of its game session, and a save whose mods are off or missing opens a
dialog that turns them on, installs them and loads it. A mod with its own way into a save asks the
same: `Mods.check(header[:mods])` answers the mods that differ, and `Mods.session_mods` lists the
mods of this session. For a place of your own, such as a world, `Mods.needs(mods)` compares the
mods it needs and `Mods.ask_needed` makes them ready: [Needed mods](needed_mods.md).

## Installing and updating

`Mods.install(ids) { |installed, error| }` installs mods of the website while the game goes on; a
failure changes nothing, and `error` tells the player why. `progress:` follows the downloads, and
`versions:` names the version to write of a mod where the latest is not the one wanted:

```ruby
module Level_Cap_Helper
  # Installs Level Cap and says how it went.
  def self.install
    Mod_Framework::Mods.install(["site:level-cap"], progress: ->(done, total, _name) { Mod_Framework.log("#{done} of #{total}") }) do |_installed, error|
      Mod_Framework.toast(error || "Installed. It loads when you enter the game.")
    end
  end
end
```

A Data mod is never installed or updated by the framework: `Mods.install` refuses it,
`Mods.updates` leaves it out, and the player installs it by hand from its page on the website.

The framework looks for updates of itself and of every mod as the game starts and at each title.
`Mods.updates` lists them, and `Mods.on_updates(tag) { |updates| }` runs whenever the check finds
new ones. A mod that needs a mod at least at a version asks for it once the game runs:

```ruby
module My_World_Check
  # Asks for My World 0.7.0 or newer before the world opens.
  def self.check
    Mod_Framework::Mods.require("my-world", "0.7.0", reason: "This version cannot play online.") do |result|
      Mod_Framework.log("My World is #{result}")
    end
  end
end
```

The player reads the reason and picks Update and restart or Back; the block hears `:current`,
`:restarting`, `:declined`, `:unavailable` or `:failed`. `Mods.update_after_exit(ids)` installs the
updates without a question and starts the game again once they are in; its block hears
`:restarting` or `:failed`. An update of the framework or of a mod in use (`Mods.in_use`) waits in
`Patch/Mod_Framework/Waiting` and moves into place as the game starts again; any other mod installs
at once. `Mods.browse(mod)` opens the mod browser on a mod's page.

What the website tells of your mod (its tag, the mods it needs and does not work with, its load
order hints, whether it is safe to add to a running save, known issues, options and hotkeys) you
set on its page of the website. Tell your players there that it needs the Mod Framework.

## Versions and platforms

- `Mod_Framework.at_least?("0.1.0")` tells whether the installed framework is that version or newer.
  Within 0.x a release may change a call; its release notes say what changed and how to adapt.
- `Mod_Framework.available?` is false when the DLL is missing or refused, such as under Wine without
  it. Then no window opens (each open is refused, with a line in the log), and hotkeys and typing
  do nothing; your mod keeps running and nothing raises.
- `Mod_Framework.platform` tells where the game runs: `"windows"`, `"wine"` (Linux, or Proton on
  the Steam Deck) or `"joiplay"` (Android, where everything works but starting the game again and
  updating).
- `Mod_Framework::Clipboard.text` reads the clipboard and `Clipboard.text = "..."` writes it.
- `Mod_Framework.memory` reads the game's memory now: `"used"` and `"free"` address space and
  `"private"`, the memory the game holds for itself, all three in megabytes; nil without the DLL
  and on JoiPlay. The game is a 32-bit program and ends without a word once a picture finds no
  room, so a mod that makes large pictures can log this at a screen change. A reading takes a few
  milliseconds; read it at most every few seconds. The framework itself collects and lets go of
  pictures while less than 300 MB is free.

## Rules for game scripts

- The game runs Ruby 1.9.2: no keyword arguments in your own methods (take an options Hash), no
  `&.`, no `%i[]`, no `Array#to_h`, no `Hash#dig`, no `then`, no `prepend`, no `__dir__`.
- The game has no `Encoding::` constants. Write `force_encoding("UTF-8")` with the name as a text.
- `at_exit` never runs; see [Hooks](hooks.md#the-games-run).
- Start every name you share with your mod's name: hotkeys, ids of windows, options, hook tags,
  settings, color and icon names.
- Name `UI = Mod_Framework::UI` inside your own module; the framework takes no short name at the
  top level.

## Logs

`Mod_Framework.log("text")` writes a line into the framework's log, `Logs/Mod Framework <day>.log`
in the game folder. Log every action and refusal of your mod there, never a secret. A failing block
of yours is logged with its place, into your mod's own log when you give a hook or a hotkey `log:`
(any object with a `log(message)` method).

Every UI error goes to that log with your mod, file and line, once per cause:

```
UI: Gear Compare (Gear_Compare.rb:42): button takes no colour:; did you mean color:?
UI: Gear Compare (Gear_Compare.rb:57): UI.patch "#ew_equipment_window": "#ew_stat" matches nothing; ids there: #ew_stats, #ew_slots, #ew_buttons
```

While the player's row Show UI Errors in Options > Mods is On, an error also shows a toast,
"UI error in <mod>. See the log.", once per cause.

<!-- nav -->
---

← [Component](component.md) · [All components](README.md) · [Options](options.md) →
<!-- /nav -->
