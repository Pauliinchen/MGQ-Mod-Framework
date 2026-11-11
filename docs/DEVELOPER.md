# Developer notes

This file holds what the code cannot say: how to build, test and release, how the parts connect, why things are the way they are, and the traps that broke before. What a method does, which topics exist and which fields they carry is in the code and its docs. Modders read [docs/ui](ui/README.md), players the [player guide](GUIDE.md).

## Build and test

### What you need

- The .NET 10 SDK and the Visual Studio workload **Desktop development with C++**, whose linker the NativeAOT publish uses. `Directory.Build.targets` puts `vswhere.exe` on the PATH, which the link needs.
- The x86 .NET 10 runtime (`C:\Program Files (x86)\dotnet`) for `ModFramework.Tests`, which runs 32-bit like the game. When the 64-bit `dotnet` cannot find it, set `DOTNET_ROOT_X86` to it.
- Ruby 3.x for the script tests.
- For the Android package: WSL or Linux with the .NET 10 SDK and the Android NDK r28c (`DOTNET_ROOT`, `ANDROID_NDK_ROOT`).

### Building

Only a publish runs NativeAOT, so a plain build gives no usable DLL:

```powershell
dotnet publish ModFramework -c Release -r win-x86 -p:Version=0.1.0
```

The DLL is 32-bit, because the game is a 32-bit process; players need no .NET installed. Without `-p:Version` the version is the csproj's `x.y.z-dev`. A publish writes `Version.txt` beside the DLL and assembles the release layout in `Shipping/` (replaced every time), with a `Manifest.txt` of every file of the framework it ships; a Release publish also writes `ModFramework/bin/Release/MGQ-Mod-Framework-<version>.zip`.

```
Patch/                      !Mod_Framework.rb  Equipment_Window.rb
Patch/Mod_Framework/        ModFramework.dll  Version.txt  Manifest.txt  README.txt  PARTS.md  boot.rbx  loader.rbx
Patch/Mod_Framework/Scripts/   *.rbx
Patch/Mod_Framework/Graphics/  *.png
```

- **The framework ships no program.** The game starts again by starting its own `Game.exe`, and the stub moves the waiting updates into place as it starts (see [The boot and the copies](#the-boot-and-the-copies)). A game that cannot start gets the framework from the website again by hand.
- **No other mod's zip carries the framework.** Players install it on their own, from the website or the release zip; the stub still looks for copies inside mod folders.
- **The zip brings the Equipment Window's first copy.** `Patch/Equipment_Window.rb`, the Mod Collection's latest released copy put in `Bundled/`, is the website's mod `equipment-window`, which owns its updates. `Manifest.txt` leaves it out, and the framework's package (slug `mod-framework`) owns only `!Mod_Framework.rb` and `Mod_Framework/` (`ModMerge.FilesOf`), so the framework's update never touches the file and the browser updates and removes it like any mod. **Trap:** each release's copy must be a version the website lists, or the browser shows it as a changed copy: it asks whether to lose that copy before an update and cannot remove it.

The Android package builds the same C# for JoiPlay (NativeAOT linux-bionic-arm64, `ModFramework.so`) in a copy of the sources outside the repository, zips it with the scripts and the libssl stand-in as `MGQ-Mod-Framework-<version>-android.zip` and checks the zip:

```bash
bash Android/build.sh [version]        # build and check
bash Android/build.sh check <zip>      # check a zip built before
```

### Trying it out

- Copy `Shipping/` into a test copy of the game; close the game first, since `ModFramework.dll` is locked while it runs. A `-dev` copy beats the release of the same number, so a deploy over an installed release wins.
- `MGQ_MODS_SITE=http://127.0.0.1:<port>` points the mod browser, its downloads, collections, filters and votes at a website on this PC instead of mgqonline.org.

### Tests

| What | Run | Runtime |
|---|---|---|
| Script tests (`GameScript/Tests/`) | `ruby GameScript/Tests/run.rb` (`-v` shows every check) | Ruby 3.x |
| `ModFramework.Tests` (the DLL) | `dotnet run --project ModFramework.Tests`, after the publish | 32-bit, x86 runtime |

- Each script test file runs in a Ruby process of its own with stand-ins for RGSS, the game and the DLL (`FakeBridge`, and `FakeTree` for C#'s tree), so a test checks what the scripts ask and do with the answer; the rules themselves are tested in C#.
- `ModFramework.Tests` checks the published DLL and its `Version.txt`, so the publish runs first. `ExportsTests` compares the export table with dumpbin's.
- The input rules are tested from the design, never from recordings: the tree tests (`TreeKeysTests`, `TreeFocusTests`, `TreeCancelTests`, `TreeListTests`, `TreePointerTests`, `WheelTests`) play keys, clicks and the pointer against C#'s tree.
- The docs are tested too. `parts_table_test.rb` writes `PARTS.md` with `--write` and fails while the shipped file differs. `modder_test.rb` runs every Ruby block of the modder pages of `docs/ui` as a mod.
- **Trap:** the script tests run on Ruby 3.x, not the game's 1.9.2, so they do not catch what only 1.9.2 lacks. Drawing, the game's own windows and real input need the game.
- **The in-game suite** lives outside this repository (`MGQ Game Tests`). It walks the framework's screens and runs every example of the `docs/ui` pages in the game with input injected inside the game process, and takes the docs pictures; a reviewer approves each against the decided looks, and an approved picture is copied into `docs/ui/images`. It also holds `make_reference.rb`, which writes the tables of params, events and keys of `docs/ui`, the links between its pages and the README's list of the components from the declarations and the index `docs/ui/README.md`; run it after either changed.

### Releasing

1. Push your changes. When the Equipment Window changed, the Mod Collection releases first and its `Equipment_Window.rb` is imported on the website as a new version of `equipment-window`, its requirement of the framework set to this release's version.
2. On GitHub, draft a release with a tag like `v0.1.0` and publish it. Players read the notes as they update, so write them for players, not as a commit log.
3. The *Release* workflow (`.github/workflows/release.yml`) takes the Equipment Window from the Mod Collection's latest release into `Bundled/`, fails while no `equipment-window` version on the website holds it, runs the script tests, publishes at that version, runs the C# tests against the published DLL and attaches `MGQ-Mod-Framework-0.1.0.zip`; then `Android/build.sh` on Linux attaches the Android zip. Keep the zip names: the website takes a zip whose name says android as the package for Android. If the run failed, fix the cause, then run it by hand from **Actions → Release** with the release's tag.
4. Import the release on the website as a new version of the mod `mod-framework`, which the framework updates itself from.

Before a release, check the hooks against the newest translation. Within 0.x a release may change the Ruby API and the bridge topics, never their conventions; its notes name each change and how a mod adapts, and the Mod Collection and MGQ Online change in the same release.

### Logs

- `Logs/Mod Framework <day>.log` in the game folder holds the DLL's and the scripts' lines. As the DLL starts it deletes the framework's logs of other days and leaves every other log alone.
- `Logs/Mod Framework boot.log` holds what the stub did and why it failed, since the stub runs before the DLL and may replace the loader that writes the day's log.
- Each cause is logged once per session, and events of every frame are summed.
- **Trap:** Ruby's `at_exit` never runs. The game's Main section ends the process with `ExitProcess`, so the last moment the scripts run is the end of `SceneManager.run`: a quit returns, an error throws. `Run.on_close` blocks and the log's last flush run there.

## Architecture

### Layout

| Path | What it is |
|---|---|
| `GameScript/!Mod_Framework.rb` | The stub, shipped as `Patch/!Mod_Framework.rb`: picks the newest copy, moves the waiting updates, boots its loader |
| `GameScript/Mod_Framework/` | A copy's files, shipped in `Patch/Mod_Framework/`: `boot.rbx`, `loader.rbx`, `Scripts/*.rbx` (Ruby 1.9.2 in RGSS3), `Graphics/*.png`, the player's `README.txt` and the generated `PARTS.md` |
| `GameScript/Tests/` | Script tests outside the game |
| `ModFramework/` | NativeAOT project -> `ModFramework.dll` (win-x86): the bridge host (`Bridge/`), the topics (`Topics/`), the game window's hook (`Windows/`), input (`Input/`), the tree, the places, the text measuring, the notices, the markers, the wheels and the theme (`Ui/`), the options' groups and key names (`Options/`), mod management (`Mods/`), the log, ini files and threads (`Runtime/`) |
| `ModFramework.Tests/` | xUnit tests of the DLL, 32-bit like the game |
| `Android/` | `build.sh`, the package for JoiPlay, and the libssl stand-in it links |
| `Bundled/` | gitignored; put the Mod Collection's `Equipment_Window/Equipment_Window.rb`, or its latest release's, here to build or test: a publish without it fails and names the file, and the release zips bring it as a mod of its own |
| `docs/` | This file, the player guide and the modders' pages of the UI layer (`ui/`, with its pictures in `ui/images/`) |

### How the parts connect

```
game scripts (Ruby 1.9.2, RGSS3)          mods built on the framework
   | Marshal plain values over four DLL exports (one batch per frame, events drained per frame)
ModFramework.dll (win-x86; ModFramework.so on JoiPlay): tree, input, places, theme, mod management
   | HTTPS
mgqonline.org: the mods, collections and filters, the downloads and the upvotes
```

- **Scripts read and apply; C# decides.** A script reads what only the game knows, hands it to a topic and carries out the answer with the game's own methods. New logic goes to C#. The one exception: the animated colors (slide, pulse) are worked out in Ruby where the text is drawn.
- **C# lays out, Ruby draws.** C#'s tree holds what lays the parts out and takes input: sizes, places, focus, scrolling, what the pointer hits, the cancel chain, the hotkeys. What Ruby draws (texts, icons, colors, row contents) never crosses. Ruby measures the glyphs, and C# measures the texts with those widths.
- **The framework names no other mod.** A mod may need the framework; the framework never names a mod, its ids or its wording.

### Where state lives

| State | Where | Who writes it |
|---|---|---|
| The player's settings, hotkeys, the places of moved boxes, why a mod failed to load, settings mods store | `Patch/Mod_Framework/Mod_Framework.ini` | the scripts through `ini.write`, after the frame of a change and as the game closes |
| Which mods are on and the player's order | `Patch/Mod_Framework/Mods.ini` | the DLL, at every plan whose lines changed, so the loader follows it without the DLL |
| The install key, whether upvotes are off, the mods downloaded with the key | `Patch/Mod_Framework/Install.ini` | the DLL only |
| The website's lists, the key's votes, the cards' pictures | `Patch/Mod_Framework/Cache/` | the DLL; a failed fetch keeps the old copy |
| Updates waiting for the next start | `Patch/Mod_Framework/Waiting/` (`Waiting.txt` and numbered files) | the DLL writes, the stub moves |
| A save's mods | `:mods` in the save's header, as plain values | the scripts |

None of these is in a package, a manifest or a hash list, so no update or removal touches them; with only a copy inside a mod's folder installed, the first store makes the folder.

### Rules that hold everywhere

- **Nothing blocks the game.** The DLL's threads fetch and download; every export returns at once.
- **Nothing throws into the game.** The stub rescues everything; a failing hook, hotkey or options block is logged in the log its registration named and never stops the others; a mod that fails to load is named, and the others load.
- **The DLL never ends the game.** An exception that escapes a thread or an export ends the process, so every thread runs through `Threads.TryStart` (the log's writer through `Threads.Start`, since `TryStart` logs), which catches what its work lets through and tells the caller when the thread cannot start, so the caller rolls back what it marked as running, and every export and the window procedure catch everything. Their catch blocks make no objects, since running out of memory may be the error: they note it in `ExportFaults`, and the next drain logs it, summed, at most once a minute.
- **Nothing outside `Patch`.** Installs, updates and removals write only inside `Patch` (`FolderGuard`), never the game's loader `Patch.rb` nor, but for the framework's own package, the framework's files (`PatchFolder.RefusalOf`), and only what the website lists with its hash. The one exception is the game's own `Game.exe`, whose 4 GB flag the framework sets once (see **4 GB** below).
- **Case.** Every path inside `Patch` is spelled as the folder spells it already, ignoring case, since under Linux the folder is case-sensitive while the game is not.
- **Wine.** One PC build runs on Windows and under Wine and Proton: no PowerShell and no Windows-only call without a way that works under Wine.
- **One window hook.** Only `ModFramework.dll` hooks the game's window; mods built on the framework keep no input or drawing engine of their own.

### Ruby 1.9.2 and RGSS3 traps

- No keyword arguments, `&.`, `%i[]`, `Array#to_h`, `Hash#dig`, `then`, `prepend` or `__dir__`, and no `Encoding::` constants (write `Encoding.find("UTF-8")`); a test greps every script for `Encoding::`.
- `at_exit` never runs (see [Logs](#logs)).
- The game's Win32API refuses an export with more than 16 arguments; none here takes more than six.
- Win32API takes code-page paths, and the untranslated game's folder name is not ASCII, so the loader loads the DLL by a relative path, and `mf_start` names the game folder after the current directory, which RGSS keeps at the game folder.
- The translation's plugins load after the `Patch` folder (script 295) and define some methods again with a plain `def`, which drops a wrap made before them. So the framework hooks the game's classes at the first `SceneManager.run`, and the run's `Hooks.report(true)` checks that each wrap is still in place.
- The translation's gamepad plugin wraps `Input` at a great cost per call. The framework reads each button it watches once a frame, past every wrapper, through the game's own `Input` that the plugin keeps as `vxa_press?`, and answers every ask of the frame from that read.
- A full garbage collection of a late-game heap takes about 220 ms, so the framework starts one only in the hold of a map change behind a fade, once 10 seconds passed since the last collection, the game's own counted too. A scene change, a battle start among them, never collects, since the game collects inside every scene transition itself and a second collection would only lengthen that hold. A menu or any other screen that answers a key press on a visible frame never collects, and a white fade or an event's fadeout skips while a text field is typed into, since both lie below the framework's windows. Without such a moment the game collects on its own, about every 20 to 26 seconds.
- **4 GB.** `Game.exe` is not large address aware, so it gets 2 GB. Once per start, on Windows and Wine (the renames are not yet tried under Wine), a thread of the DLL sets `IMAGE_FILE_LARGE_ADDRESS_AWARE` in the running program's file header when it lies in the game folder and its ini names an RGSS3 library: it writes a changed copy `Game.exe.new` (only that flag; the checksum stays, since Windows checks it only for drivers and system DLLs), renames the running `Game.exe` to `Game.exe.before-4gb` (Windows lets a running program be renamed, not replaced) and the copy to `Game.exe`. A failed step puts the program back, so a `Game.exe` always exists; an existing backup is never replaced. `Install.ini` notes that it was set, so a player who put the old program back keeps it. While Smart App Control is on or evaluating (`HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy`, `VerifiedAndReputablePolicyState` 1 or 2; Windows may turn evaluation into on by itself), it is skipped and logged, since Windows blocks a changed program it does not know; an unreadable value counts as off. A virus scanner that holds the copy for a moment gets two more tries 200 ms apart. It takes effect at the next start. No release zip carries a `Game.exe`.
- **Memory.** `Game.exe` is a 32-bit program, and RGSS ends the game without a word once a picture finds no room in its address space. Every 300 frames the DLL sums the free regions of the address space with `VirtualQuery`, which works the same under Wine (the largest free block alone stays high long after the game ran short); below 300 MB free it answers low, at most once every 20 seconds (a trim that freed under 50 MB doubles that gap, up to 5 minutes, until a trim frees more or the free space is back at 300 MB), and the scripts let go of the framework's kept pictures and the game's picture cache down to a few and collect at once. A picture let go is never freed, since a sprite may still show it; the collector frees it once nothing does. Each such event is one log line with the numbers.
- Paradox's `hp=` removes the death state and every refresh lets go of unequippable items, so the serials of states and gear go up only when they really changed.
- Paradox's `$data_weapons` and `$data_armors` are no Arrays but Paradox's own Enumerable, so `Array()` or `to_a` copies the whole database; read their `size` and `[]` only.
- `draw_text` cuts what reaches left of where its text starts, and starts a centered or right-aligned text a pixel left of its measure. The framework draws every text aligned left behind a space, in a box a space further left, and works out where it lines up itself.

## The boot and the copies

- `Patch/!Mod_Framework.rb` is the only `.rb` of the framework. Its name sorts before every mod's script under the byte order both kinds of loader sort by: the English translation's `Patch.rb` (which the untranslated game takes too) sorts `Dir.glob("Patch/**/*.rb")`, the Russian translation's sorts `Dir.entries("Patch")`. No other `.rb` may sit under a framework folder, since the English loader would run it.
- Every release ships **the same bytes** of the stub, since the mod browser marks an installed file whose hash it does not know as a changed copy. `boot.rbx` holds the same code under another header (`boot_test` compares them), and `.gitattributes` pins both to CRLF. Change the stub only when a release has to, and then in both.
- The English loader evaluates each file in a block whose locals every later file shares, with a rescue around it; the Russian one evaluates the text alone, with no file name, no rescue and no strip of a byte order mark. So the stub is ASCII, sets no local, never returns and rescues everything into `boot.log`; nothing may reach the game's error box.
- **A copy** is a folder holding `Version.txt`: `Patch/Mod_Framework/` or a `Patch/<mod>/Mod_Framework/`. The stub picks one: a copy with its DLL beats every copy without, then the higher version, then `-dev` over the release of the same number, then the standalone copy. Only the winner's `loader.rbx` runs; the loader counts a DLL whose build differs from `Version.txt` as none.
- **The waiting updates** move before any DLL loads: the stub moves each file a waiting one replaces aside to `.old` (retrying for 3 seconds while the game that just closed still holds a DLL, since Windows lets a loaded DLL be renamed but not replaced), moves the waiting files in, then deletes what the update drops. A file still in use puts everything back for the next start; a start cut short is finished by the next one.
- **The web installer's stand-ins:** a browser refuses to write some file names into a real folder, such as any ending in `.dll`, so the website's installer writes `<path>.web` and leaves `<path>.remove` beside a file it cannot remove. The stub carries both out under `Patch` before it picks a copy.
- **The hold:** until the game runs, a read of a mod's `.rb` in `Patch` answers an empty text, so the game's loader runs nothing of it, and the framework loads each mod at its tag's stage, in its order, only if it is on. Ending the hold removes the one method it defined.
- **Without the DLL** the scripts load and answer as usual: the loader follows `Mods.ini`, the theme dresses the game's windows in fixed defaults, `Settings` answers nil and stores nothing, every root's open is refused once per mod, and the title shows no Mods box. There is no Ruby fallback of any C# model.

## Loading the mods

- **Stages:** at the first `SceneManager.run` the Framework and then the Title mods load, before every other block of the run, as they would have before it. On entering (New Game, a save's load, a mod's own `Mods.enter`) the Title mods' rest, the Default mods and then the Data mods load, before `DataManager.setup_new_game` or `load_game`.
- **The traps of a late load:** a mod's `SceneManager.run` wrapper set up during entering runs once, through a stand-in run; the database is read again when a Data mod loaded or a mod hooked `DataManager.load_database` or `load_normal_database`; New Game and the save's load run again by `send`, so a wrapper a mod put on them runs; hooks registered late wrap at once. `Mods.load_late` takes scripts the framework does not load itself, such as a battle server's per battle, through the same wrapper and database steps.
- Each file loads with its path as its file name in a binding of its own at the top level, so constants and methods land where Patch's would and locals stay the file's. The first file that fails ends that mod.
- **A Title mod** whose scripts name `title_command`, `on_enter` or `load_part` tells its parts itself; one that names none loads whole at the title, worked out at every start and never written to `Mods.ini`.
- **Back to the title starts the game again** once code that loads on entering ran, since nothing unloads a mod: `SceneManager.goto`, `call` and `return` onto the title are hooked, and F12 through a `Run.on_reset` block.
- **The restart:** `Mods.restart` has the game quit and registers the start as the last `Run.on_close` block, after every other closing write. The DLL writes the action to carry into `MOD_FRAMEWORK_AFTER_RESTART` in its own environment and starts the game's own, unchanged program through the shell, which passes the environment on. No game file changes, so it should work under Wine and Proton; it is checked on Windows only so far. Without the DLL or on JoiPlay the game's message box asks the player to start the game again.

## The bridge

- The DLL exports `mf_bridge_open`, `mf_call`, `mf_reply` and `mf_drain` for the bridge, and `mf_start` and `mf_start_android`, all with the framework's prefix `mf_`.
- Ruby and C# trade Marshal plain values; names are texts, never Symbols. `Mod_Framework.bridge` is pinned to the framework's own DLL; a mod with a DLL of its own keeps its own bridge to it. The exact shape of every topic is in the doc comment of its constant in C#.
- **One frame**, as `Scene_Base#update_basic` runs it: after-hooks of `Input.update` tick the DLL with this frame's buttons and input and drain its events, so clicks, typed text and the tree's events reach the components before the scene reads `Input` (a before-hook would carry the last frame's presses, which the scene already took); then the scene updates, with `Input`'s answers following what the framework's windows hold; before-hooks of `Graphics.update` render and draw; its after-hooks flush the frame's batch and write the settings that changed.
- The framework's hooks of the frame are **outermost**: its before-blocks run before every other tag's and its after-blocks after them, however late a mod registers, so a mod loaded once the game runs still runs inside the framework's frame.

## The UI layer

- **Declarations** (`layer_declarations.rbx`, `layer_builtins*.rbx`) tell each built-in's params, events, keys and engine part. They make the markup methods, check every markup call (a wrong name or value raises with the nearest right one and the mod's file and line), and write the tables of `docs/ui`. Both files load without the game.
- **Each frame** the components whose state, serials or watches changed render, parents first, at most 3 times a frame; then the live params of the roots that are due are read, every 4 frames for `UI.open` and every 2 for `UI.show`. A render is matched with the last one per parent by type and `key:`, so a kept part gets only its changed options. A component out of sight, such as on a page the slides keep out of view, only turns dirty and renders once it shows.
- **Key stops:** markup sets no input flag. A built-in tells C# what it is (it acts, it repeats a key the player has anyway, it is an aside, it takes the focus first) and C#'s tree works out which parts take the keys, the cancel chain and the way back.
- **Older screens** of the engine under `UI::Engine` still draw through the same tree with their own rules ("old roots"); a change to the layer's rules leaves them as they are. `UI` holds no alias of the engine.
- **Bands:** each layer has its depths, and a part's `z:` orders it only within its own: the HUD parts, `layer: :over`, the windows, the dialogs, the popups, the notices and the tooltips, from the bottom up. A popup takes a depth above every window and dialog, also one opened after it, and C#'s tree orders the roots by the same depth, so a click lands on what draws on top.
- **HUD parts hide under a CG.** Many CGs have see-through corners like the standing portraits, so only the picture's name tells them apart: the novel scene, or a picture covering nine tenths of the screen whose name is a CG's.
- **The serials:** hooks on the game's change points (party, gear, HP and MP, states, levels, gold, items, variables, switches, map) bump counters, which `UI::Game` reads for the component that renders, so a render renders again only when what it read changed. Max HP and MP are kept per character, since the game works them out from all traits on every read, and so is whether a character can wear each item of the bag, since an equip list asks about every item of a late-game bag of thousands.
- **Drawing:** each text is drawn once onto one of four shared sheets and copied afterwards, and each character once per font, size, color and outline, so a new text makes no picture of its own. A part that changes is drawn anew only where it lies.
- **The game's windows:** a `UI.patch` on a game window class hooks that class once the game runs, or a class defined later as its first window is made. The looks of a list window's rows are drawn on the game's own bitmap while the game draws the row: the name is what its `draw_actor_name` methods draw, and a grey row greys what `change_color`, `draw_icon` and `draw_face` draw, so the HP and MP gauges keep their colors. A hidden or replaced window keeps what the game sets for `visible` and answers it, so the game's scripts work as before and the window never draws.
- **The theme** lives in C#: every preset, the color names mods add, what a preset holds along the presets it starts from, the player's pick (a preset that is gone gives Monarch), and the text color on a fill by the higher contrast. Ruby draws in the resolved palette and sets the game's window colors in place, so every older screen keeps its look.

## Mod management

- **The website is the only source.** The DLL reads its lists as plain JSON over HTTPS and takes a download only from it and only with the list's hash of every file (a script hashed without its carriage returns). Each version has a package per platform: `pc` on Windows and Wine, `android` on JoiPlay.
- **An install** stages every file, checks it against its hash and only then copies it into `Patch`, putting every replaced file back when one fails; a loaded DLL is renamed to `.old` and replaced. The framework and the mods in use go to the waiting folder instead, whose list is written last, so a failure leaves nothing behind. Every file a package puts into `Patch` is the mod's (`ModMerge.FilesOf`); a package laid out like the game folder puts only its `Patch/` folder there, and the rest, such as a changelog beside it, is left out and logged. An update or removal also deletes every file a listed version ships that is still exactly that version's, such as a renamed script, and keeps a file that matches none.
- **The installed version** is the newest listed version whose files are all there. A copy that misses files of a version, or holds files of older ones, is an update that rewrites it whole, while its version stays unknown to worlds and needs; a listed file that matches no version makes a changed copy, which the browser never overwrites without asking and never removes.
- **The plan** gives each mod its tag (the website's, else the copy of the website's tags built into the DLL, else Default, `Regular` in code), orders the mods by tag, the player's order, their requirements and their authors' load order hints, and warns of every requirement not met and every conflict. Players never set a tag.
- **Updates** are checked as the game starts and at each title, the lists fetched again once they are half an hour old. An installed version newer than the lists' latest counts as current.
- **Upvotes** use the install key in `Install.ini`, sent only to the website as the bearer token of its downloads and votes, and never logged. Turning upvotes off has the website forget the key.
- **Options > Mods** keeps the interface of Mod Config Remake and the Mod Config Menu (`NWConst::Config::MOD_CONTENTS`, `ModConfigRemake`), so mods made for them work unchanged; `ModConfigRemake::Keys` exists only while the DLL works, so a mod that checks it offers no key row the game's options cannot show. Its window covers the game's options list exactly and hides it, while the game's scripts still read it as shown.

## JoiPlay

JoiPlay runs VX Ace games on its own Ruby 1.9.2 engine, whose Win32API answers 0 to every DLL call. The Android package carries the same C# as `ModFramework.so` and a `libssl.so` stand-in.

- Android loads a library only from the app's own folder, since shared storage is mounted noexec, so the loader copies both files there (a new file renamed over the old one, never rewritten in place) and opens the library with the engine's `DL`. JoiPlay replaces `DL::CFunc`, so every call goes through `CFunc.allocate`, with addresses passed as signed numbers, since Android tags heap pointers in the top byte.
- Android gives an app no libssl, and .NET ends the game at its first crypto call without one. The stand-in hands .NET the OpenSSL the engine exports, and `mf_start_android` sets `SSL_CERT_DIR` to Android's certificate folder, since the engine's OpenSSL looks in a folder of JoiPlay's build machine.
- No Windows function reads the input there, so the scripts read the engine's `Input` each tick and hand it to the DLL; the clipboard is the engine's `Input.clipboard`.
- There is no window hook and no start of the game again: a restart closes the game with a message, and the stub moves the waiting updates at the next start as on the PC.

## The game's own menus

Four fixes take the lag out of the game's own menus, each with a row in Options > Mods that turns it off:

- **Quick Gear Previews:** the equip screen and the shop try an item on a copy of a character whose refresh works every feature out several times; the fix leaves the refresh out where it would change nothing.
- **Picture Cache:** Paradox empties the game's picture cache whole once it holds 100 pictures and runs a full garbage collection; the fix forgets the pictures used least long ago down to 80 and collects only once those take 64 MB.
- **Long Item Lists:** an item list of more than three pages draws the rows in view and one page on either side, instead of one picture as tall as the list, which Paradox makes through a PNG file once it is large.
- **Quick Party List:** Paradox's `draw_face_hue` disposes the face it drew in the picture cache, so each opening of the menu read every member's face from its file again; the menu's party list keeps its faces in the cache, which Picture Cache keeps bounded.

The in-game suite measures each with the fix on and off.
