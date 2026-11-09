<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Display](README.md#display)
<!-- /nav -->

# Arrow

`arrow` is a filled triangle with a dark outline that points right, such as a hint beside a
line. A [marker](marker.md) draws an arrow toward a place at the screen's edge for you.

## Examples

### Colors

<!-- example: arrow-colors -->
```ruby
stack row: true do
  arrow
  arrow color: :warning
  arrow color: :success
end
```
![Three arrows pointing right in the text, warning and success colors](images/arrow-colors.png)

## Params, events and keys

Every part also takes [the params every part takes](README.md#params-every-part-takes).

<!-- generated: arrow -->
A filled triangle with a dark outline that points right.

Written `arrow ...`.

| Param | Takes | Default | Live | About |
|---|---|---|---|---|
| `color:` | a color name such as :primary or :rainbow, "#RRGGBB", [r, g, b] or a game text color such as 2 |  | yes | its fill's color; the theme's text color by default |

**Keys:** none

**Mouse:** none; its tooltip: shows on hover
<!-- /generated -->

<!-- nav -->
---

← [Progress](progress.md) · [All components](README.md) · [Tooltip](tooltip.md) →
<!-- /nav -->
