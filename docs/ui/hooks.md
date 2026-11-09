<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Hooks

`Mod_Framework::Hooks` runs a block of your mod before, after or around a method of the game, and
`Mod_Framework::Run` runs blocks as the game starts, at F12 and as it closes. Every mod's hooks of
one method share one wrap, so mods never undo each other's, and a failing block is logged and never
stops the others.

## Examples

### Before and after a method

```ruby
module Gold_Log
  @gained = 0

  # Writes a line into the framework's log.
  def self.log(message)
    Mod_Framework.log("Gold Log: #{message}")
  end

  # Counts the gold the party got.
  def self.gained(amount)
    @gained += amount
  end

  # Tells the gold the party got in this game session.
  def self.total
    @gained
  end

  Mod_Framework::Hooks.after(Game_Party, :gain_gold, "Gold Log", Gold_Log) do |amount|
    Gold_Log.gained(amount) if amount > 0
  end
end
```

- `Hooks.before(owner, method, tag, log) { |*args| }` and `Hooks.after` run the block with the
  object as `self` and the method's arguments; `after` leaves the method's result as it is.
- For a module's method give its singleton class, `SceneManager.singleton_class`.
- A second hook with the same tag replaces the first. `log` is where a failing block is logged,
  such as your mod's module; the framework's log without one.
- Before-blocks run from the last registered to the first and after-blocks from the first to the
  last, as nested wraps would.

### Around a method

`Hooks.around` decides when the game's method runs and what it answers. Its block gets the object,
the arguments and the original, whose `call` runs the method with the arguments, or with those it
is given:

```ruby
module Double_Gold
  Mod_Framework::Hooks.around(Game_Party, :gain_gold, "Double Gold") do |_party, args, original|
    original.call(args[0] * 2)
  end
end
```

## The game's run

The game ends through its own `ExitProcess`, so Ruby's `at_exit` never runs. Work for the game's end
goes into `Run.on_close`, which runs as the game's scenes end, on a quit or an error:

```ruby
module Gold_Log_Run
  Mod_Framework::Run.on_start("Gold Log") { Gold_Log.log("counting the gold from now on") }
  Mod_Framework::Run.on_close("Gold Log") { Gold_Log.log("the party got #{Gold_Log.total} G in this game session") }
end
```

- `Run.on_start(tag) { }` runs once the game starts running, before its first scene, or at once
  when it runs already, as for a Default mod.
- `Run.on_reset(tag) { }` runs whenever F12 starts the game's scenes again, which runs no script
  again.
- `Run.on_close(tag) { }` runs once as the game closes, before the framework's log writes its last
  lines.
- Each takes `log:`, where a failing block is logged.

## Running behind other windows

`Mod_Framework.keep_running = true` keeps the game running while another window is in front, such as
for an online mod; the game's buttons stay quiet meanwhile. `UI.in_front?` tells whether the game's
window is in front.

<!-- nav -->
---

← [Settings](settings.md) · [All components](README.md) · [Window](window.md) →
<!-- /nav -->
