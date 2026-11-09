<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Services](README.md#services)
<!-- /nav -->

# Task

`UI.task` waits on work that ends later, such as a report your mod's DLL sends or a file it writes.
It asks a lambda once a frame, before the frame is drawn, until the lambda answers something other
than nil, and then runs its block once with that answer. With `seconds:` it gives up after that many
seconds of real time and runs the block with nil. The seconds stand while the game is not in
front, as a toast's do. It draws nothing; show what the player should see yourself, such as a
toast or a message.

## Examples

### Waiting for an answer

```ruby
Mod_Framework.toast "Sending the report . . ."
UI.task(-> { My_Mod.report_sent }, seconds: 30) do |sent|
  UI.message(sent ? "The report was sent." : "The report could not be sent. Try again later.")
end
```

The lambda takes no arguments and should be quick: it runs every frame. One that raises ends the
wait with nil and is logged with the place it was started from.

### Giving up

```ruby
@sending = UI.task(-> { My_Mod.report_sent }) { |sent| report_done(sent) }
# The player went back to the title:
@sending.cancel if @sending && @sending.pending?
```

`UI.task` answers a task: `pending?` tells whether it still waits, and `cancel` ends it without
running its block. F12 ends every task the same way.

## Params

| Param | Takes | Default | About |
|---|---|---|---|
| `seconds:` | a number | none | the most seconds of real time it waits; without it, it waits until answered or cancelled |

<!-- nav -->
---

← [Message](message.md) · [All components](README.md) · [Needed mods](needed_mods.md) →
<!-- /nav -->
