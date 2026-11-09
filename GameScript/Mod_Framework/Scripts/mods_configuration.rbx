#----------------------------------------------------------------
#  mods_configuration.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module Mods
    # The Mod Configuration at the title, a window of the UI layer laid out as the game's Options >
    # Mods: on the left the mods whose rows show at the title, the framework's groups first; on the
    # right the picked mod's options, then its hotkeys, under a small Hotkeys caption after options.
    # At the title only the framework, the Framework mods and the Title mods run, so it shows their
    # options and hotkeys, and of the Regular mods that are on only the hotkeys remembered from an
    # earlier game.
    # Confirm or Right goes into the rows, cancel there comes back to the mod, and cancel on the mods
    # closes it.
    class ModsConfiguration < UI::Component
      # The texts it shows, by what they say.
      TEXTS = {
        :title => "Mod Configuration",
        :no_options => "No options here. Your other mods' options are in the game's Options > Mods."
      }

      # The id of its window.
      ID = :mf_mods_config

      # The width of the list of the mods, as in Options > Mods.
      LIST_WIDTH = 200

      # The name of the mod under the cursor of the list of the mods.
      state(:picked) { Options.mods(rows).first }

      # Describes the window: the list of the mods beside the rows of the mod picked, with the help
      # line under the rows.
      def render
        mods = Options.mods(rows)
        shown = mods.include?(picked) ? picked : mods.first
        size = ModsScreen::SIZE
        window TEXTS[:title], id: ID, width: size[0], height: size[1], min_size: [size[0], ModsScreen::LEAST_HEIGHT], max_size: size,
                              resizable: :height, on_close: ->(why) { closed(why) } do
          stack row: true, height: :fill do
            list mods, bind: :picked, empty: TEXTS[:no_options], id: :mf_mods_config_mods, submit_to: :mf_mods_options, width: LIST_WIDTH,
                       align_self: :stretch, rows_shown: :fill, autofocus: true
            options_list mod: shown.to_s, headings: false, hotkeys: :remembered, only: ->(row) { Options.title_row?(row) },
                         help: shown && format(ModOptions::TEXTS[:mod_help], shown), id: :mf_mods_options, width: :fill, align_self: :stretch,
                         visible: !shown.nil?, on_change: ->(key, value) { changed(key, value) }
          end
        end
      end

      private

      # Lists the rows it shows: the rows of Options > Mods that show at the title, then the
      # remembered hotkeys of the Regular mods that are on.
      #
      # @return [Array<Hash>] The rows.
      def rows
        Hotkeys.rows_with_remembered.select { |row| Options.title_row?(row) }
      end

      # Logs a row the player changed.
      #
      # @param key [Symbol] The row's key.
      # @param value [Object] Its value now, a hotkey row's key code.
      def changed(key, value)
        Screen.log("#{ID} changed #{key} to #{value.inspect}")
      end

      # Logs that it closed.
      #
      # @param why [Symbol, String] Why it closed.
      def closed(why)
        Screen.log("#{ID} closed (#{why})")
      end
    end
  end
end
