#----------------------------------------------------------------
#  toasts.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Added UI.toasts, which defines a stack of toasts of a mod, and the stack: option of a toast
#      Paulinchen  2026-11-06: Added UI.release_offer, which shows an accepted offer again at once
#                            - Added UI.notices_shown?, which a render reads like a serial
#      Paulinchen  2026-11-05: Drew the offers and each toast of the notice stack as components of the UI layer
#                            - Showed a speech bubble as a bubble root of the UI layer holding its text
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  # Shows a toast, a small box of its own, from a mod or an event's Script command; it only
  # queues, so the event goes on at once. It goes to the general stack in the corner of the
  # notices every mod shares, where at most five show, the newest at the corner, and the rest
  # wait in line; or to a stack your mod defined with UI.toasts.
  #
  #   Mod_Framework.toast "Found 250 G", seconds: 3
  #   Mod_Framework.toast "Monsters ahead!", seconds: 4, severity: :warning, key: :encounter
  #   Mod_Framework.toast "Spikes!", stack: :my_traps
  #
  # @param text [String] What it says; a long text wraps.
  # @param options [Hash] :seconds (its stack's, 3 for the general stack; real time from the
  #   moment it shows), :severity (:normal, :info, :success, :warning or :error), :icon (an
  #   IconSet index, a name UI.icon gave or { file: path }; by default the icon UI.defaults
  #   :severity_icons gave its severity), :key (a newer toast of its stack with the same key takes
  #   its place), :group (UI.drop_group takes a group's toasts away), :stack (the name your mod
  #   gave UI.toasts).
  # @return [nil] Nothing.
  def self.toast(text, options = {})
    UI::Engine::Notices.show(text, UI::Engine::Looks.toast_icon(options, caller))
  end

  # Shows a speech bubble over a character on the map for a while, from a mod or an event's Script
  # command: a bubble root holding the text (UI::SpeechBubble); outside the map it shows as a toast.
  #
  #   Mod_Framework.bubble $game_player, "Ouch!", seconds: 2
  #   Mod_Framework.bubble 12, "Help me!", side: :top, key: :help_12
  #
  # @param target [Game_Character, Integer] The character, or the id of an event on this map.
  # @param text [String] What it says.
  # @param options [Hash] :seconds (nil: until the map changes; real time while the game is in
  #   front), :side (:top, :bottom or
  #   :middle), :color (its fill), :key (a newer bubble with the same key replaces it), :most_lines
  #   (3), :width (the widest, 240).
  # @return [nil] Nothing.
  def self.bubble(target, text, options = {})
    UI::Engine::SpeechBubbles.show(target, text, options)
  end

  module UI
    # Defines a stack of toasts of your mod, once, such as as the mod loads; a second call of the
    # same name defines it anew. It lies where your mod puts it and the player cannot move it.
    # Mod_Framework.toast with stack: puts a toast into it. An option of a wrong value keeps its
    # default and is logged.
    #
    #   Mod_Framework::UI.toasts :my_traps, corner: :top_left, slide_from: :left, grows: :down,
    #                            most_shown: 3, seconds: 2, newest_on_top: true
    #
    # @param name [Symbol, String] Its name, such as :my_traps.
    # @param options [Hash] :corner (:top_left, :top_right, :bottom_left or :bottom_right; the
    #   top left unless :at is given), :at ([x, y], in place of a corner, the spot of its first
    #   toast's top left when it grows down, its bottom left when it grows up), :slide_from (:left,
    #   :right, :top or :bottom, the side new toasts slide in from; the corner's side, the left at
    #   a spot), :grows (:up or :down, the direction further toasts appear in; away from the
    #   corner's edge, down at a spot), :most_shown (5, the most that show at once; the rest wait in
    #   line), :seconds (3, how long each shows unless its call says), :newest_on_top (true puts the newest toast at the top of the stack, false at its
    #   bottom; by default the newest lies at the corner or spot).
    # @return [nil] Nothing.
    def self.toasts(name, options = {})
      Engine::Notices.define_stack(name, options)
    end

    # Lists the offers of a mod that stand now in the notice stack, asked every frame while it
    # shows; a second block of the same name replaces the first.
    #
    # @param name [Object] The source's name, such as :my_mod_quests.
    # @param options [Hash] :log (where a failure of the block or an answer is logged).
    # @yieldreturn [Array<Hash>] The offers, each { key:, text:, decline:, accept:, accept_text:,
    #   color:, mark:, group: }, decline: required.
    # @return [nil] Nothing.
    def self.offers(name, options = {}, &block)
      Engine::Notices.offers(name, options, &block)
    end

    # Shows an offer the player accepted again at once, as when the other side turned the accept
    # down; an accepted offer stays away up to ten seconds otherwise.
    #
    #   UI.release_offer(:my_mod_sonya)
    #
    # @param key [Object] The offer's key.
    # @return [nil] Nothing.
    def self.release_offer(key)
      Engine::Notices.release(key)
    end

    # Takes away every toast and answered offer of a group, a toast shown fading out.
    #
    # @param name [Object] The group.
    # @return [nil] Nothing.
    def self.drop_group(name)
      Engine::Notices.drop_group(name)
    end

    # Ends a toast before its time: shown, it fades out; waiting, it never shows.
    #
    # @param key [Object] The toast's key.
    # @return [nil] Nothing.
    def self.drop_toast(key)
      Engine::Notices.drop(key)
    end

    # Tells whether the notice stack shows at this frame: not on the title, on game over or in a
    # novel scene, and not while a block of UI.notices_hidden_while answers true; false without
    # the DLL. Read in a render, it renders the component again once the answer changes.
    #
    #   text(UI.notices_shown? ? "Notices on" : "Notices hidden")
    #
    # @return [Boolean] Whether it shows.
    def self.notices_shown?
      Engine::Serials.read(:notices)
      Engine::Notices.showing?
    end

    # Hides the notice stack while a block answers true, such as while a screen of a mod covers it;
    # nil instead of a block takes the hiding away.
    #
    # @param name [Object] The block's name; a second block of the same name replaces the first.
    # @return [nil] Nothing.
    def self.notices_hidden_while(name, &block)
      Engine::Notices.hide_while(name, &block)
    end

    # The offers of the notice stack every mod shares, in a hud of the notices' layer docked in the
    # corner the player picks below the parts docked there, which the player moves like any part
    # (kept as ui_notices): each offer a dense alert in its own text color with its Accept and
    # Decline buttons, which name the hotkeys on the first; the offers just answered fading out;
    # and "+N more" past five rows, its tooltip naming the rest. Engine::Notices shows it while it
    # has rows; it hides while the stack hides.
    class NoticeStack < Component
      # Hides it while the stack hides.
      HIDDEN = lambda { Engine::Notices.hiding? }

      # Renders it anew once the rows or the corner changed.
      watch { Engine::Notices.serial }

      # Describes the offers.
      def render
        notices = Engine::Notices
        rows = notices.rows
        hud id: notices::ID, anchor: notices.corner, order: notices::DOCK_ORDER, layer: :notices, place_name: notices::PLACE_NAME,
            width: notices::WIDTH, min_size: notices::MIN_SIZE, resizable: :width, hide_while: HIDDEN do
          fading = 0
          rows.first(notices::SHOWN).each_with_index do |(kind, row), place|
            if kind == :offer
              offer(row, place == 0)
            else
              alert row[:text], dense: true, text_color: text_color(row), id: notices::FADING_IDS[fading], key: [:fading, fading]
              fading += 1
            end
          end
          if rows.size > notices::SHOWN
            text format(notices::MORE_TEXT, rows.size - notices::SHOWN), typo: :caption, color: :dim, tooltip: rest_of(rows), key: :more
          end
        end
      end

      private

      # Describes an offer in its text color with its buttons; the first names the Accept and
      # Decline hotkeys on them.
      #
      # @param row [Hash] The offer.
      # @param first [Boolean] Whether it is the first.
      def offer(row, first)
        notices = Engine::Notices
        alert row[:text].to_s, dense: true, text_color: text_color(row), key: [:offer, row[:key]] do
          if row[:accept]
            button((row[:accept_text] || notices::ACCEPT_TEXT).to_s, hotkey: first ? :accept : nil, show_key: first, on_click: -> { notices.answer(true, row) })
          end
          button notices::DECLINE_TEXT, hotkey: first ? :decline : nil, show_key: first, on_click: -> { notices.answer(false, row) }
        end
      end

      # Tells the text color of a row: its own, else the plain text color.
      #
      # @param row [Hash] The offer.
      # @return [Symbol, Integer, String, Array] The color.
      def text_color(row)
        color = row[:color]
        return :text if color.nil?

        color.respond_to?(:red) ? [color.red.to_i, color.green.to_i, color.blue.to_i] : color
      end

      # Tells the texts of the rows past the shown ones, one per line, as "+N more" names them.
      #
      # @param rows [Array<Array>] The rows.
      # @return [String] The texts.
      def rest_of(rows)
        rows[Engine::Notices::SHOWN..-1].map { |_kind, row| row[:text].to_s }.join("\n")
      end
    end

    # A toast: a hud of its own in the notices' layer without a frame, as large as Engine::Notices
    # laid it out, at its stack's start, holding an alert with a bar in its severity's color beside
    # its text in the plain text color. Engine::Notices shows it, moves it along its stack and
    # fades it as C#'s NoticeQueue tells; the pointer passes through it and it hides while the
    # notices hide.
    class ToastCard < Component
      # Hides it while the stack hides.
      HIDDEN = lambda { Engine::Notices.hiding? }

      # The toast, as Engine::Notices.look laid it out, with :at.
      param :notice

      # Its id, which keeps two toasts apart.
      param :card_id

      # Describes the toast.
      def render
        hud id: card_id, at: notice[:at], width: notice[:size][0], height: notice[:size][1], layer: :notices, frame: false, mouse: :none, movable: false,
            fade: false, hide_while: HIDDEN do
          alert notice[:text], severity: notice[:severity], icon: notice[:icon], text_color: :text, most_lines: Engine::Notices::MOST_LINES, height: :fill
        end
      end
    end

    # The speech bubble Mod_Framework.bubble shows: a bubble root holding its text, wrapped in the
    # small font to the bubble's width and cut after its most lines.
    class SpeechBubble < Component
      # The character it follows, or an event's id on this map.
      param :target

      # What it says.
      param :says

      # Its id, which keeps two bubbles apart.
      param :bubble_id

      # Its fill, nil for white.
      param :color, nil

      # The seconds it shows, nil until hidden.
      param :seconds, nil

      # The side of the character it lies on.
      param :side, :top

      # The most lines its text takes.
      param :most_lines, 3

      # The widest it gets.
      param :width, nil

      # The map it shows on; it closes once the map changes.
      param :map_id

      # Describes the bubble.
      def render
        bubble follow: target, id: bubble_id, side: side, color: color, seconds: seconds, width: width, if: -> { on_its_map } do
          text says, typo: :body2, wrap: true, most_lines: most_lines
        end
      end

      private

      # Tells whether the map it shows on is still the game's.
      #
      # @return [Boolean, Symbol] true, else :map, why it closes.
      def on_its_map
        $game_map && $game_map.map_id == map_id ? true : :map
      end
    end

    module Engine
      # The speech bubbles Mod_Framework.bubble shows, each a SpeechBubble shown with UI.show, with
      # the bubble of each key, timed in seconds of real time by the Clock.
      module SpeechBubbles
        # The sides a bubble lies on by the names a mod gives.
        SIDES = [:top, :bottom, :middle]

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "bubbles"

        # The bubbles shown, by their keys.
        @shown = {}

        # The number of the last bubble, which names its id.
        @count = 0

        # Shows a bubble over a character for its seconds, replacing the one of its key; outside the
        # map, or for a character the map does not have, it shows as a toast.
        #
        # @param target [Game_Character, Integer] The character, or an event's id on this map.
        # @param text [String] What it says.
        # @param options [Hash] See Mod_Framework.bubble.
        # @return [nil] Nothing.
        def self.show(target, text, options = {})
          character = target.is_a?(Integer) ? ($game_map && $game_map.events[target]) : target
          scene = defined?(::SceneManager) ? ::SceneManager.scene : nil
          unless character && defined?(::Scene_Map) && scene.is_a?(::Scene_Map)
            log("bubble shown as a toast, #{character ? 'outside the map' : "no character #{target.inspect} on this map"}: #{text}")
            return Notices.show(text, :seconds => options[:seconds], :key => options[:key])
          end

          key = options[:key]
          old = key.nil? ? nil : @shown.delete(key)
          old.hide if old && old.shown?
          handle = UI.show(SpeechBubble, params_of(character, text, options))
          @shown[key] = handle if handle && !key.nil?
          log("bubble over #{character.class.name}#{key.nil? ? '' : " (#{key})"}: #{text}")
          nil
        end

        # Forgets the bubbles of each key, as F12 starts the game anew.
        def self.reset
          @shown = {}
        end

        # Turns a bubble's options into the params of its SpeechBubble.
        #
        # @param character [Game_Character] The character it follows.
        # @param text [String] What it says.
        # @param options [Hash] See Mod_Framework.bubble.
        # @return [Hash] The params.
        def self.params_of(character, text, options)
          @count += 1
          params = { :target => character, :says => text.to_s, :bubble_id => "mf_bubble_#{@count}", :map_id => $game_map.map_id }
          params[:side] = options[:side] if SIDES.include?(options[:side])
          params[:seconds] = options[:seconds].to_f unless options[:seconds].nil?
          [:color, :most_lines, :width].each { |name| params[name] = options[name] unless options[name].nil? }
          params
        end
        private_class_method :params_of
      end
    end

    Run.on_reset("bubbles") { Mod_Framework::UI::Engine::SpeechBubbles.reset }
  end
end
