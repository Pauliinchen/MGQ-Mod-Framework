#----------------------------------------------------------------
#  loader.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Stopped loading the gear components and dialogs of UI::Equip, which the Equipment Window builds itself
#      Paulinchen  2026-11-07: Loaded the Mod Configuration
#                            - Loaded UI::Drawn, a component that draws itself
#                            - Loaded the timeline
#                            - Loaded the drop zones
#                            - Loaded the avatar
#                            - Loaded the badge over the corner of a part
#                            - Loaded the head of a card
#                            - Loaded the grid and its items
#                            - Loaded the breadcrumbs
#                            - Loaded the slider
#                            - Loaded the filter drawer and the pages of the mod browser from files of their own
#                            - Loaded the surfaces and the kinds of root from files of their own
#                            - Loaded the canvas and the base component from files of their own
#                            - Loaded the gear trial, the equip info and the gems from files of their own
#                            - Loaded the engine's components from one file per family
#      Paulinchen  2026-11-06: Stopped loading the split of plain Title scripts
#                            - Stopped loading the copy of the database read
#                            - Stopped retiring the framework's old name, which no release had
#                            - Loaded the collector behind scene changes on its own and stopped loading the probe
#                            - Loaded the selectors under their own name, now that UI.dump is gone
#                            - Stopped loading the UI Inspector
#                            - Stopped loading the old UI scan
#                            - Stopped loading the calls REFERENCE.md told of
#                            - Left out giving UI the names of the engine's classes
#                            - Added the presets and color names mods gave before the DLL started once it starts
#                            - Loaded the dialog of the mods a place needs after the UI layer it is drawn with
#                            - Loaded the boxes of UI.confirm, UI.message, UI.number and UI.menu on the UI layer
#                            - Loaded what the reference tells of the calls of the UI layer
#                            - Loaded the mod browser after the UI layer it is drawn with
#                            - Loaded the save's mods dialog after the UI layer it is drawn with
#                            - Loaded Options > Mods after the UI layer it is drawn with
#                            - Loaded the Mods screen after the UI layer it is drawn with
#                            - Loaded the title's Mods box after the UI layer it is drawn with
#      Paulinchen  2026-11-05: Loaded the gear components of UI::Equip
#                            - Loaded the expansion panels
#                            - Loaded the table, the pagination and the UI layer's parts of a page of an overview
#                            - Loaded the declarations of the UI layer's parts forms are made of
#                            - Loaded the declarations of the UI layer's parts a chat is made of
#                            - Loaded the tasks UI.task waits on
#                            - Loaded the declaration of the UI layer's wheel
#                            - Loaded the declarations of the UI layer's parts that HUDs are made of
#                            - Loaded the fixes of the game's own menus
#                            - Stopped loading the old equip dialog and the search list, which the UI layer replaces
#                            - Loaded the item and gem dialogs of the UI layer
#                            - Loaded the toasts and bubbles script
#                            - Loaded the drawer script
#                            - Loaded the key capture script
#                            - Loaded the colors script
#      Paulinchen  2026-11-04: Loaded the equipment readers of the UI layer
#                            - Loaded the declarations of the UI layer's parts that show the game's data
#                            - Loaded the script of the UI layer's parts that follow what they hold, such as slides
#                            - Loaded the UI Inspector's script
#                            - Loaded the script of UI.patch on the game's windows
#                            - Loaded the script of UI.patch
#                            - Loaded the looks mods add to the UI layer
#                            - Loaded the placement of the UI layer
#                            - Loaded the script of UI.dump
#                            - Loaded the scripts of the UI layer
#                            - Loaded the engine script and let UI stand for the engine's names once every script loaded
#                            - Loaded the probe script
#                            - Loaded the glyph cache script
#                            - Loaded the serials script
#                            - Loaded the script that reads mod scripts for calls of the old UI
#      Paulinchen  2026-10-31: Loaded the database script
#                            - Loaded the log view, the help line, the markers, the notices and the page view scripts
#      Paulinchen  2026-10-30: Started the library for JoiPlay there instead of the DLL
#                            - Loaded the mods split script
#                            - Told where the game runs
#                            - Loaded the mod browser script
#                            - Loaded the title box script
#                            - Loaded the mods screen script
#                            - Loaded the mod config script
#                            - Claimed the Mod Config's interface once the DLL started
#                            - Loaded the options list script
#                            - Loaded the save check script
#                            - Loaded the mods install script
#                            - Loaded the mods restart script
#                            - Loaded the mods of the boot
#                            - Loaded the mods loader script
#                            - Loaded the mods script
#      Paulinchen  2026-10-29: Retired the framework under its old name
#                            - Loaded the equip dialog script
#                            - Loaded the key help script
#                            - Loaded the dropdown script
#                            - Loaded the search list script
#                            - Loaded the scenes script
#                            - Loaded the hotkeys script
#                            - Loaded the adopt, game mouse and defaults scripts
#                            - Loaded the dialogs and wheel scripts
#                            - Loaded the game script
#                            - Loaded the components script
#                            - Loaded the animation script
#      Paulinchen  2026-10-28: Loaded the scripts of the component tree, the containers and the roots
#                            - Loaded the layout script
#                            - Loaded the style, theme and options scripts
#                            - Loaded the text script
#                            - Loaded the input script
#                            - Created
#
#----------------------------------------------------------------

# Loads the copy of the Mod Framework the stub picked (Mod_Framework::Boot): its scripts in
# a fixed order, then its DLL, the bridge to it, the hook of the game's run and the managed mods of
# the boot. Evaluated once per game session; the scripts that need no DLL work without it.
module Mod_Framework
  # The version of the copy that loaded, as its Version.txt names it, such as "0.1.0".
  VERSION = Boot.version

  # The folder of the copy that loaded, relative to the game folder, such as
  # "Patch/Mod_Framework".
  FOLDER = Boot.folder

  # Folder of the scripts inside the copy's folder.
  SCRIPTS_DIR = "Scripts"

  # Extension of the scripts, which the game's loader skips, since only this loader may load them.
  SCRIPT_EXTENSION = ".rbx"

  # The scripts in SCRIPTS_DIR, in the order they load; a script may use only what loaded before
  # it while it loads.
  SCRIPTS = %w[logging hooks run bridge joiplay settings mods mods_loader mods_restart mods_install engine input collector text style glyph_cache colors theme layout tree tree_canvas tree_component animation containers roots_surfaces roots roots_windows components components_text components_pictures components_buttons components_choices components_list components_tabs components_lines components_stats components_fields drawer dropdown game game_gear_trial game_equip_info game_gems game_serials key_help scenes dialogs log_view help_line markers notices page_view table_view expansion value_inputs breadcrumbs cards badges avatars drop_zones timelines wheel adopt game_mouse hotkeys options game_menus key_capture options_list mods_update defaults layer_declarations layer_builtins layer_builtins_game layer_builtins_hud layer_builtins_wheel layer_builtins_chat layer_builtins_forms layer_builtins_pages layer_builtins_inputs layer_builtins_layout layer_builtins_display layer_markup layer_component layer_drawn layer_runtime layer_parts layer_pages layer_equip layer_entry layer_boxes layer_selector layer_patch layer_game_windows layer_placement layer_theme toasts tasks mods_screen mods_configuration mods_browser mods_browser_filters mods_browser_pages mods_title mods_saves mods_needed mod_config]

  # File name of the DLL inside the copy's folder.
  DLL = "ModFramework.dll"

  # The DLL's start: it names the game folder, starts its log and hooks the game's window.
  START = "mf_start"

  # Tells whether the framework loaded, with or without its DLL, so no other copy loads.
  #
  # @return [Boolean] Whether it did.
  def self.booted?
    @booted == true
  end

  # Tells whether the framework's DLL works: it loaded and shook hands, and its build is the
  # version of the copy. Without it the framework's windows, boxes and fields stay closed.
  #
  # @return [Boolean] Whether it does.
  def self.available?
    @available == true
  end

  # The platforms platform names: Windows, Wine (Linux, or Proton on the Steam Deck) and JoiPlay
  # on Android.
  WINDOWS = "windows"
  WINE = "wine"
  JOIPLAY = "joiplay"

  # Tells where the game runs, found once per game session without the DLL, which JoiPlay never
  # loads. A mod asks it before a call that works on one platform only.
  #
  # @return [String] WINDOWS, WINE or JOIPLAY.
  def self.platform
    @platform ||= find_platform
  end

  # Finds where the game runs: JoiPlay by its own mark or an Android Ruby, Wine by the function
  # only Wine's ntdll exports.
  #
  # @return [String] WINDOWS, WINE or JOIPLAY.
  def self.find_platform
    return JOIPLAY if $joiplay || RUBY_PLATFORM =~ /android/i

    ntdll = Win32API.new("kernel32", "GetModuleHandleA", "p", "l").call("ntdll.dll")
    # JoiPlay's stand-in for Win32API answers 0 to every call, and Windows always has ntdll loaded.
    return JOIPLAY if ntdll == 0

    Win32API.new("kernel32", "GetProcAddress", "lp", "l").call(ntdll, "wine_get_version") == 0 ? WINDOWS : WINE
  rescue StandardError, NotImplementedError
    JOIPLAY
  end

  # Tells whether the framework is at least a version, as a mod that needs a newer framework asks.
  # A "-dev" build counts as its release.
  #
  # @param version [String] The version, such as "0.1.0".
  # @return [Boolean] Whether VERSION is that version or newer.
  def self.at_least?(version)
    (numbers(VERSION) <=> numbers(version)) >= 0
  end

  # Reads the numbers of a version.
  #
  # @param version [String] The version, such as "0.1.0-dev".
  # @return [Array<Integer>] Major, minor and patch.
  def self.numbers(version)
    parts = version.to_s.split("-").first.to_s.split(".").map { |part| part.to_i }
    (parts + [0, 0, 0])[0, 3]
  end

  # Builds the path of a file inside the copy's folder, relative to the game folder, with
  # backslashes, as Win32API loads a DLL.
  #
  # The path stays relative, since Win32API takes a path only in the system's code page and the
  # untranslated game's folder name is not ASCII; the game always runs in its own folder.
  #
  # @param name [String] The file name, relative to the copy's folder.
  # @return [String] The path.
  def self.path(name)
    "#{FOLDER}/#{name}".tr("/", "\\")
  end

  # Loads the scripts in the order of SCRIPTS. One that is missing or fails is logged, and the
  # others load all the same.
  def self.load_scripts
    failed = []
    SCRIPTS.each do |name|
      file = "#{FOLDER}/#{SCRIPTS_DIR}/#{name}#{SCRIPT_EXTENSION}"
      begin
        eval(File.read(file, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, file)
      # A script that does not parse raises a SyntaxError, which is no StandardError.
      rescue Exception => e
        failed << "#{name} (#{e.class}: #{e.message})"
      end
    end
    @failed_scripts = failed
  end

  # Starts the DLL and opens the bridge to it, once per game session, and hands the log's early
  # lines and the presets and color names given before over.
  def self.start
    return if @started

    @started = true
    @available = open_dll
    Log.settle(@available)
    UI::Engine::Looks.settle if @available && defined?(UI::Engine::Looks)
  rescue Exception => e
    Log.write("start failed: #{e.class}: #{e.message}")
    Log.settle(false)
  end

  # Starts the DLL, or the library on JoiPlay, and opens the bridge to it.
  #
  # @return [Boolean] Whether the DLL works; the log tells why not.
  def self.open_dll
    return open_library if platform == JOIPLAY

    dll = path(DLL)
    unless File.file?(dll)
      Log.write("runs without its DLL: #{dll} is missing, so its windows, boxes and fields stay closed")
      return false
    end

    hooked = Win32API.new(dll, START, 'v', 'l').call
    Log.write("#{START} answered #{hooked}: the game's window is not hooked, see the DLL's lines") if hooked != 1
    return false unless bridge.start(dll)

    built_as_copy?(dll)
  rescue => e
    Log.write("runs without its DLL: starting #{dll} failed: #{e.class}: #{e.message}")
    false
  end

  # Starts the library for JoiPlay and opens the bridge to it.
  #
  # @return [Boolean] Whether the library works; the log tells why not.
  def self.open_library
    library = "#{FOLDER}/#{JoiPlay::LIBRARY}"
    unless File.file?(library)
      Log.write("runs without its DLL: #{library} is missing, so its windows, boxes and fields stay closed")
      return false
    end

    backend = JoiPlay.start(FOLDER)
    return false unless backend && bridge.open(backend)

    built_as_copy?(library)
  rescue => e
    Log.write("runs without its DLL: starting #{library} failed: #{e.class}: #{e.message}")
    false
  end

  # Tells whether the opened DLL is the build of the copy, and closes the bridge when not.
  #
  # @param file [String] The DLL or library, for the log.
  # @return [Boolean] Whether it is.
  def self.built_as_copy?(file)
    return true if bridge.build == VERSION

    Log.write("runs without its DLL: #{file} is build #{bridge.build}, but Version.txt names #{VERSION}")
    bridge.close
    false
  end

  # Loads the scripts, starts the DLL, follows the game's run and loads the managed mods of the
  # boot.
  #
  # The framework counts as booted from the start, whatever fails, so neither another copy nor a
  # managed mod whose folder holds the stub loads it a second time.
  def self.boot
    @booted = true
    load_scripts
    Boot.notes.each { |line| Log.write(line) }
    Log.write("Mod Framework #{VERSION} from #{FOLDER} on Ruby #{RUBY_VERSION}, platform #{platform}")
    Log.write("scripts that did not load: #{@failed_scripts.join(', ')}") unless @failed_scripts.empty?
    start
    ModConfig.claim if defined?(ModConfig)
    Run.install
    Mods::Loader.boot if defined?(Mods::Loader)
    Hooks.report
  rescue Exception => e
    boot_failed("#{e.class}: #{e.message} (#{Array(e.backtrace).first})")
  end

  # Writes why the boot failed: into the log, or into Logs/Mod Framework boot.log when the log
  # itself did not load.
  #
  # @param reason [String] What failed.
  def self.boot_failed(reason)
    return Log.write("boot failed: #{reason}") if defined?(Log)

    Dir.mkdir("Logs") unless File.directory?("Logs")
    File.open("Logs/Mod Framework boot.log", "ab") do |file|
      file.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  the Mod Framework #{VERSION} in #{FOLDER} failed to boot: #{reason}\r\n")
    end
  rescue Exception
    nil
  end
end

Mod_Framework.boot
