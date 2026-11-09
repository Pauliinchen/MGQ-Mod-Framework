<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Layout](README.md#layout)
<!-- /nav -->

# Container

`container` holds its parts in a column in the middle of the room it gets, at most `max_width:`
wide, with gutters of 8 pixels at its sides, as MudBlazor's container. Each width is a most, so a
smaller room narrows it; in a row it is a column at its width. A window that fits what it holds
takes the container's width, so a container sets how wide such a window opens.

| `max_width:` | Width | Why |
|---|---|---|
| `:xs` | 240 | a narrow column, as wide as a drawer |
| `:sm` | 320 | half the 640 pixels of the screen |
| `:md` | 400 | |
| `:lg` (by default) | 480 | three quarters of the screen |
| `:xl` | 560 | |
| `:xxl` | 640 | the whole screen |
| pixels | as given | |
| `:fluid` | the whole room | |
| `:fixed` | the largest named width that fits the room | |

The gutters are its padding, so `padding: 0` drops them. Its parts stand a stack's room apart;
put a `stack` inside for other room between them. A `max_size:` of its own still wins where it is
narrower.

## Examples

### In the middle of a wide window

<!-- example: container-sizes -->
```ruby
container max_width: :sm do
  paper do
    text "The road to Iliasburg is open again.", wrap: true
  end
end
```
![A paper of text 320 pixels wide in the middle of a window as wide as the screen](images/container-sizes.png)

### The whole room

<!-- example: container-fluid -->
```ruby
container max_width: :fluid do
  paper do
    text "The road to Iliasburg is open again.", wrap: true
  end
end
```
![A paper of text across the whole window, the gutters at its sides](images/container-fluid.png)

### The largest width that fits

In a window 520 pixels wide the room inside is 496 pixels, so a `:fixed` container takes 480.

<!-- example: container-fixed -->
```ruby
container max_width: :fixed do
  paper do
    text "The road to Iliasburg is open again.", wrap: true
  end
end
```
![A paper of text 480 pixels wide in a window 520 pixels wide](images/container-fixed.png)

## Params, events and keys

Every part also takes [the params every part takes](README.md#params-every-part-takes).

<!-- generated: container -->
Its parts in a column in the middle of the room it gets, at most max_width: wide, with gutters at its sides, as MudBlazor's container; padding: 0 drops the gutters.

Written `container ...` with a `do ... end` block of markup.

| Param | Takes | Default | Live | About |
|---|---|---|---|---|
| `max_width:` | px, `:xs`, `:sm`, `:md`, `:lg`, `:xl`, `:xxl`, `:fluid`, `:fixed` | `:lg` |  | its most width: :xs 240, :sm 320, :md 400, :lg 480, :xl 560 or :xxl 640 pixels, or pixels; :fluid the whole room; :fixed the largest named width that fits the room; a window that fits what it holds takes the named width, with :fixed the next named width above what the container holds |
<!-- /generated -->

<!-- nav -->
---

← [Stack](stack.md) · [All components](README.md) · [Grid](grid.md) →
<!-- /nav -->
