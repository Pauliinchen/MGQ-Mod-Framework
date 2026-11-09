MGQ Paradox Mod Framework
=========================
The mod other mods of Monster Girl Quest! Paradox RPG run on.

Install, update and turn your mods on and off from the title screen,
set their options and hotkeys in one place, and play every mod built on
the framework in the look you pick. It also lets the mouse work the
game's own menus and takes lag out of them.

The player guide explains everything the framework does:

   https://github.com/Pauliinchen/MGQ-Mod-Framework/blob/main/docs/GUIDE.md


REQUIREMENTS
------------
Monster Girl Quest! Paradox RPG 3.06, untranslated or with the English
or Russian translation.

The community's mod loader must be installed: download "Patch.rb
(enable Type 1 mods)" from the MGQ wiki and put it into your Patch
folder. If you already use other Patch folder mods, you have it. The
Russian translation brings its own Patch.rb, which loads the framework
too: keep it and skip the wiki one.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

It runs on Windows, on Linux with Wine or Proton, and on JoiPlay on
Android with the Android package.


INSTALL
-------
Download the Mod Framework from the website, close the game and extract
it into your Monster Girl Quest! Paradox RPG folder (the one that
contains Game.exe). On JoiPlay take the Android package, the zip ending
in -android.

   https://mgqonline.org/mods

It should then look like this:

   Game.exe
   Patch\!Mod_Framework.rb       (sorts first, so it loads before every mod)
   Patch\Mod_Framework\          (the framework's files and ModFramework.dll)
   Patch\Equipment_Window.rb     (the Equipment Window, a mod of its own)

Your mods stay in the Patch folder as before, and the framework loads
them itself. Your settings go into Patch\Mod_Framework, the logs into
the Logs folder of the game folder.

The Equipment Window replaces the game's equip screen. It comes with
the framework as a mod of its own and is on from the start: turn it off
in the Mod List, or set "[Equipment Window] Equip Command" in
"Options > Mods" to the game's screen. "Browser" updates and removes it
like any other mod.

On Windows and Linux, the first time the game starts with the
framework, it sets a mark in Game.exe that lets the game use up to
4 GB of memory from the next start. The old program stays beside it as
Game.exe.before-4gb. See "4 GB for the game" in the guide.


UPDATE
------
The framework looks for updates of itself and of your mods as the game
starts and at the title, and "Browser" in the title's Mods box counts
them. Its own update and that of a mod that runs download into
Patch\Mod_Framework\Waiting and move into place as the game starts
again, which the framework does for you; on JoiPlay the game closes
and you start it again. This is checked on Windows and should work
under Wine and Proton too, but is not checked there yet: if an update
does not move into place there, extract the framework's zip into the
game folder by hand.

If the game cannot start, download the framework again from the website
and extract it into the game folder. The website keeps every version,
so you can also take the one before. Your settings, the mods you turned
on and their order are kept. The zip brings Equipment_Window.rb too:
leave it out if you removed it or updated it in the Browser.


UNINSTALL
---------
Close the game and delete !Mod_Framework.rb and the Mod_Framework folder
in Patch. Keep Patch\Mod_Framework\Mod_Framework.ini if you want your
settings back after a later install. Equipment_Window.rb is a mod of
its own: delete it as well, and keep a copy outside Patch if you want it
back after a later install. Mods built on the framework, the Equipment
Window too, cannot run without it: left in Patch, each shows an error
as the game starts.

Game.exe keeps its 4 GB mark. To put the old program back, delete
Game.exe and rename Game.exe.before-4gb to Game.exe, as "4 GB for the
game" in the guide tells.


QUICK START
-----------
1. Start the game and press Left on the title's commands: the cursor
   moves into the Mods box.
2. Pick "Browser", open a mod's page and pick "Install".
3. Pick "List" to turn mods on and off and to move them with I and K.
   A change to a mod that runs already counts once the game starts
   again; "Restart now" on the bar at the foot starts it again.
4. Pick "Configuration" to set your mods' options and hotkeys. In a
   game they are in "Options > Mods".


HOTKEYS
-------
   Y / N          accept / decline the first offer of the notices,
                  or answer a question box
   I / K          move the mod under the cursor up / down within its
                  tag in the Mod List
   Ctrl + arrow   jump out of a list to the part beside it
                  (on a gamepad, hold A with the d-pad)

Rebind them in "Options > Mods > Mod Framework Hotkeys", or at the
title in "Configuration". The game's cancel key as you bound it in F1,
and Numpad 0, close every window of the framework and of the mods built
on it. Hold the left Alt to move and resize the boxes with the mouse.


TROUBLE?
--------
The guide's troubleshooting section explains the game's messages:

   https://github.com/Pauliinchen/MGQ-Mod-Framework/blob/main/docs/GUIDE.md#troubleshooting

The log is in the Logs folder of your game folder, one per day you
played, named after the day, such as "Mod Framework 2026-11-07.log",
and "Mod Framework boot.log" when the framework could not start at all.
Starting the game deletes the logs of earlier days, so attach the log
of the day something went wrong when you report a problem.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link
above). It is not included in this download.

The MGQ Paradox Mod Framework is an unofficial fan project. It is not
affiliated with or endorsed by Torotoro Resistance, the creators of
Monster Girl Quest!, or the English translation team. It contains no
game or translation files.

   https://github.com/Pauliinchen/MGQ-Mod-Framework
