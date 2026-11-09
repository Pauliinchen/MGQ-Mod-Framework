# MGQ Paradox Mod Framework: the parts you can patch

Written by `GameScript/Tests/parts_table_test.rb`, which opens each of the framework's screens in the test driver; do not edit it by hand.
`docs/ui/patch.md` in the framework's repository tells how `UI.patch` names these parts: by an id, by a type inside an id, or both, such as `"#mf_mods_side text"`.

## Mod List

`UI.patch "#mf_mods"`

| Id | Type |
|---|---|
| `#mf_mods` | window |
| `#mf_mods_list` | list |
| `#mf_mods_side` | stack |
| `#mf_mods_text` | paper |
| `#mf_mods_keys` | key_help |
| `#mf_mods_notice` | alert |
| `#mf_restart_bar` | alert |

Types: `Mod_Framework::Mods::ModsScreen`, `alert`, `button`, `key_help`, `lines`, `list`, `paper`, `stack`, `text`, `window`.

Exposed values: none.

## Mod Configuration

`UI.patch "#mf_mods_config"`

| Id | Type |
|---|---|
| `#mf_mods_config` | window |
| `#mf_mods_config_mods` | list |
| `#mf_mods_options` | options_list |

Types: `Mod_Framework::Mods::ModsConfiguration`, `list`, `options_list`, `stack`, `window`.

Exposed values: none.

## Mod browser

`UI.patch "#mf_browser"`

| Id | Type |
|---|---|
| `#mf_browser` | window |
| `#mf_browser_bar` | paper |
| `#mf_browser_tabs` | tabs |
| `#mf_browser_mods_tab` | tab |
| `#mf_browser_collections_tab` | tab |
| `#mf_browser_view` | button |
| `#mf_browser_update_all` | button |
| `#mf_browser_refresh` | button |
| `#mf_browser_search` | text_field |
| `#mf_browser_filters_button` | button |
| `#mf_browser_filters` | drawer |
| `#mf_browser_filter_rows` | Mod_Framework::Mods::BrowserFilters |
| `#mf_browser_filter_list` | list |
| `#mf_browser_mods` | paper |
| `#mf_browser_cards` | list |

Types: `Mod_Framework::Mods::BrowserFilters`, `Mod_Framework::Mods::ModBrowser`, `button`, `drawer`, `list`, `paper`, `stack`, `tab`, `tabs`, `text`, `text_field`, `window`.

Exposed values: none.

## Options > Mods

`UI.patch "#mf_mod_options"`

| Id | Type |
|---|---|
| `#mf_mod_options` | window |
| `#mf_mod_options_mods` | list |
| `#mf_mod_options_list` | options_list |

Types: `Mod_Framework::ModOptions`, `list`, `options_list`, `stack`, `window`.

Exposed values: none.

## The title's Mods box

`UI.patch "#mf_title_mods"`

| Id | Type |
|---|---|
| `#mf_title_mods` | window |
| `#mf_title_mods_list` | list |

Types: `Mod_Framework::Mods::TitleModsBox`, `list`, `stack`, `text`, `window`.

Exposed values: none.

## The save's mods dialog

`UI.patch "#mods_save_check"`

| Id | Type |
|---|---|
| `#mods_save_check` | dialog |
| `#mods_save_rows` | list |

Types: `Mod_Framework::Mods::SaveModsDialog`, `button`, `dialog`, `list`, `progress`, `stack`, `text`.

Exposed values: none.

## The game's windows

A game window is named by its class, and a command of a command window by its symbol inside it, such as `"Window_MenuCommand #equip"`. Any game window takes `set` with `opacity:`, `anchor:`, `at:`, `width:`, `height:`, `theme:` and `movable:`; the rows of a list window take `name_color:`, `name:`, `grey:` and `line_above:` through `rows`.

### The title's commands

`UI.patch "Window_TitleCommand"`

| Id | Type |
|---|---|
| `#new_game` | command |
| `#continue` | command |
| `#auto_continue` | command |
| `#call_library_h` | command |
| `#shutdown` | command |

Types: `command`.

Exposed values: none.

### The menu's commands

`UI.patch "Window_MenuCommand"`

| Id | Type |
|---|---|
| `#item` | command |
| `#equip` | command |
| `#stone` | command |
| `#skill` | command |
| `#ability` | command |
| `#status` | command |
| `#formation` | command |
| `#library` | command |
| `#config` | command |
| `#save` | command |
| `#game_end` | command |

Types: `command`.

Exposed values: none.
