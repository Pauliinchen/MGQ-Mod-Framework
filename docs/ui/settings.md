<!-- nav -->
[Mod Framework](../../README.md) › [UI components](README.md) › [Your mod](README.md#your-mod)
<!-- /nav -->

# Settings

`Mod_Framework::Settings` keeps settings in the framework's own file,
`Patch/Mod_Framework/Mod_Framework.ini`, the same in every save. Updates of the framework keep
the file, so what your mod stores there stays. Values go in as text and come back
as text.

## Example

```ruby
module Camp_Journal_Count
  # Tells how many times the journal opened, in every save together.
  def self.opened
    Mod_Framework::Settings.setting("camp_journal_opened").to_i
  end

  # Counts one more opening, unless the settings file cannot be read.
  def self.count_opening
    return unless Mod_Framework::Settings.readable?

    Mod_Framework::Settings.store("camp_journal_opened", opened + 1)
  end
end
```

- `Settings.setting(key)` reads a setting, nil while it is not set.
- `Settings.store(key, value)` keeps one and `Settings.forget(key)` removes it; each answers whether
  the change will be written. The file is written after the frame of the change and as the game
  closes.
- `Settings.readable?` tells whether the file's values are known: false without the DLL or while
  the file cannot be read, when every change is refused.
- Start every key with your mod's name: the file is shared by every mod.

An options row whose value your mod keeps here is an `Options.keep` row: [Options](options.md).

<!-- nav -->
---

← [Hotkeys](hotkeys.md) · [All components](README.md) · [Hooks](hooks.md) →
<!-- /nav -->
