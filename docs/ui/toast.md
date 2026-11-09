<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Notices](README.md#notices)
<!-- /nav -->

# Toast

`Mod_Framework.toast` shows a short message for a few seconds, as MudBlazor's snackbar does. Each
toast is a small box of its own, as wide as its text. There are two ways to toast: into the
general stack every mod shares, at the edge of the screen in the corner the player picks in
Options > Mods (Notice Corner, the top left unless changed), or into a
[stack of your own](#a-stack-of-your-own) that your mod defines once with `UI.toasts`. A new toast
slides in at the corner and the older ones move away from it: down from a top corner, up from a
bottom corner. Each toast shows for its own seconds (3 unless the call or its stack gives
`seconds:`), counted from the moment it shows; then it fades out over a second while it travels up
the screen, and the others close its gap meanwhile. At most five show at once; the rest wait in
line and show as the first ones go, each starting its seconds then. Each toast is an
[alert](alert.md) in a box of its own without a frame: a bar in its severity's color at its left
and its text in the plain text color, wrapped into four lines at most.
Toasts lie above every window and dialog (the [hud](hud.md#above-every-window) layer `:notices`)
and show on the map, in menus and in battle, past the HUD parts and the offers docked in their
corner. The pointer passes through them, and they never take cancel.

## Examples

### A toast

<!-- example: toast-plain -->
```ruby
Mod_Framework.toast "Found 250 G", seconds: 2
```
![A toast sliding in at its corner, staying and fading out](images/toast-plain.gif)

A toast only queues and never waits, so it works from an event's Script command, inside a message
or in a battle event. Its seconds are real time from the moment it shows and run on while the
toasts hide or the game is in the background. A text wider than a toast wraps. In a game without
the framework, guard the call:

```ruby
Mod_Framework.toast("Found 250 G", seconds: 3) if defined?(Mod_Framework)
```

### Toasts one after another

<!-- example: toast-stack -->
```ruby
Mod_Framework.toast "Found 250 G", seconds: 4
Mod_Framework.toast "Got 2 Herbs", seconds: 2
Mod_Framework.toast "Alice joined the party", seconds: 4, severity: :info
Mod_Framework.toast "Saved to slot 3", seconds: 3, severity: :success
```
![Toasts arriving at the bottom left, the older moving up, each fading out and the gaps closing](images/toast-stack.gif)

Here the player picked the bottom left, and each call comes from an event half a second after the
one before. The gold's toast shows first; as the party gets two Herbs, Alice joins and the game is
saved, each new toast slides in at the corner and pushes the older ones up. The Herbs' toast ends
first and fades out while it travels up, and the gold's toast moves down into its place; then the
others fade out one after another until the corner is empty. A sixth toast waits until one of the
five ends.

### Severity, icon and key

<!-- example: toast-severity -->
```ruby
Mod_Framework.toast "Monsters ahead!", seconds: 2, severity: :warning, key: :encounter
```
![A warning toast sliding in and fading out](images/toast-severity.gif)

`severity:` (`:info`, `:success`, `:warning`, `:error`) draws a bar in its color down the left of
the toast, whose text stays in the plain text color; `:normal` draws none. `icon:` puts an icon
before the text: an IconSet index, a name `UI.icon` gave, or a picture file as
`{ file: "Graphics/Pictures/x" }`. A toast shows no icon unless it names one or your mod gave its
severity one, as the [alert](alert.md#an-icon-for-each-severity) shows:

```ruby
Mod_Framework::UI.defaults :severity_icons, warning: 56, error: 49
Mod_Framework.toast "Monsters ahead!", seconds: 2, severity: :warning   # with the exclamation mark
```

A newer toast of the same stack with the same `key:` takes the place of the one shown, whole at
once, and starts its time again; `UI.drop_toast(key)` fades it out. `group:` names a group, and
`UI.drop_group(name)` ends all its toasts.

### A stack of your own

<!-- example: toast-own-stack -->
```ruby
UI.toasts :my_traps, corner: :top_right, slide_from: :right, grows: :down, most_shown: 3, seconds: 2
Mod_Framework.toast "Spikes! 25 damage dealt", stack: :my_traps, severity: :error
Mod_Framework.toast "Poison darts! 10 damage dealt", stack: :my_traps, severity: :warning
```
![Two trap toasts sliding in at the top right, each fading out upward](images/toast-own-stack.gif)

`UI.toasts` defines a stack of toasts for your mod, once, such as as your mod loads; `stack:`
puts a toast into it, which may still give its own `seconds:`, `severity:`, `icon:`, `key:` and
`group:`. The stack lies where your mod puts it, apart from the general stack, and the player
cannot move it. Defined again with the same name, it takes the new options at once.

| Option | Values | Default | |
|---|---|---|---|
| `corner:` | `:top_left`, `:top_right`, `:bottom_left`, `:bottom_right` | `:top_left` | the corner it lies in, 8 pixels in from the edges |
| `at:` | `[x, y]` |  | a spot in place of a corner: the top left of its first toast when it grows down, the bottom left when it grows up |
| `slide_from:` | `:left`, `:right`, `:top`, `:bottom` | the corner's side, `:left` at a spot | the side new toasts slide in from |
| `grows:` | `:up`, `:down` | away from the corner's edge, `:down` at a spot | the direction further toasts appear in |
| `most_shown:` | 1 to 32 | 5 | the most toasts that show at once; the rest wait in line |
| `seconds:` | a number above 0 | 3 | how long each toast shows unless its call gives `seconds:` |
| `newest_on_top:` | `true`, `false` | the newest at the corner or spot | `true` puts the newest toast at the top of the stack, `false` at its bottom |

A toast into a stack no mod defined does not show, and an option of a wrong value keeps its
default; the framework's log in `Logs` names both.

### A speech bubble

`Mod_Framework.bubble $game_player, "Ouch!", seconds: 2` shows a speech bubble over a character
on the map for its seconds of real time; outside the map it shows as a toast. See
[Bubble](bubble.md).

### Offers

<!-- example: toast-offers -->
```ruby
UI.offers :party_joins do
  [{ key: :sonya_joins, text: "Sonya wants to join the party",
     accept: -> { add_sonya }, decline: -> { send_sonya_away } }]
end
```
![An offer with Accept and Decline, declined with N and fading out](images/toast-offers.gif)

Offers stand in a framed box docked in the same corner, below the HUD parts there and before the
toasts, which the player moves with Alt like any part. Each offer is a dense alert with its Accept
and Decline buttons; the first offer's buttons name the Accept and Decline hotkeys ("Y: Accept",
"N: Decline"), which answer it. The hotkeys are quiet while the notices hide, while a screen that
holds the game's buttons or a question box is open and while anything types. The block is asked
every frame while the notices show, so an offer stands while it is valid. A declined offer stays
away while it stands; an accepted one up to ten seconds; an answered one fades out. Past five rows
"+N more" shows, its tooltip naming the rest. `decline:` is required; without `accept:` only
Decline shows. `accept_text:` renames Accept, `mark:` tells a new offer apart from one declined,
and `color:` colors its text. A block that fails is logged once into its mod's log and shows no
offers.

### An accepted offer turned down

<!-- example: toast-release -->
```ruby
UI.offers :party_joins do
  [{ key: :sonya_joins, text: "Sonya wants to join the party",
     accept: -> { ask_the_party_for_room }, decline: -> { send_sonya_away } }]
end
```
![An offer accepted with Y fading out, then standing again once the party had no room](images/toast-release.gif)

An accept may be turned down after the player pressed it, such as when the party turns out to be
full or the other player left. The accepted offer stays away up to ten seconds, so a second press
accepts nothing; `UI.release_offer(key)` shows it again at once, where the player can accept it
later or decline it:

```ruby
UI.release_offer(:sonya_joins) unless room_in_party?
```

### Hiding the notices

```ruby
UI.notices_hidden_while(:my_mod_screen) { my_screen_open? }
```

The toasts of every stack and the offers hide while the block answers true, and on the title, game
over and in novel scenes. While they hide, the toasts' time runs on.

### Telling whether the notices show

```ruby
class InviteHint < UI::Component
  def render
    hud anchor: :bottom_left, id: :invite_hint do
      text "Invites show in the corner" if UI.notices_shown?
    end
  end
end
```

`UI.notices_shown?` tells whether the notices show at this frame: false on the title, on game over,
in novel scenes, while a block of `UI.notices_hidden_while` answers true, and without the
framework's DLL. It tells whether the corner may show toasts and offers, not whether one stands
there now. A component that reads it in `render` renders again once the answer changes, as it does
for the values it reads through `UI::Game`.

<!-- nav -->
---

← [Patch](patch.md) · [All components](README.md) · [Drawn](drawn.md) →
<!-- /nav -->
