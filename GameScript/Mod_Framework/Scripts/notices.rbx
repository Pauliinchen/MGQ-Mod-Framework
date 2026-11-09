#----------------------------------------------------------------
#  notices.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Kept C# ticking for a toast queued in the frame in which the last toast went
#                            - Placed each toast by its bottom edge in a stack that grows up and by its top edge in one that grows
#                              down, whatever its corner or spot
#                            - Let each toast's seconds run from the moment it shows on a clock that always runs, so C# no
#                              longer hears whether the stack shows, and posted the settings notice only while it shows
#                            - Moved each toast as C# places it, also travelling up as it fades
#                            - Defined the toast stacks of mods in C# and placed their toasts where their mods put them
#      Paulinchen  2026-11-07: Read typing from UI.typing?
#      Paulinchen  2026-11-06: Found an answered offer in the rows by its key
#                            - Took an answered offer out of the rows at once, also while the stack hides
#                            - Stopped timing the frame for the probe, which is gone
#                            - Called the engine's classes by their names under UI::Engine
#                            - Bumped the notices' serial once the stack starts or stops showing
#      Paulinchen  2026-11-05: Drew the offers and each toast through the UI layer, the offers in a hud of the notices' layer
#                              and each toast in a hud of its own, and dropped the old boxes
#                            - Kept the clock of real time that toasts, bubbles, bars and tasks count by
#                            - Asked the scene and the offers without making objects while no offer stands
#                            - Asked the hide_while blocks and whether a scene hides the box without making objects
#                            - Made no rows while no notice shows and compared them without making lists
#                            - Showed each toast as a small box of its own sized to its text in the corner the player picks,
#                              the newest at the corner and the older moving away, sliding in and fading out as C# counts
#                              seconds of real time, at most five at once; showed the stack in battle
#                            - Kept a row's color name, which the box draws in its look, animated ones too, and faded rows by
#                              their opacity
#      Paulinchen  2026-11-04: Let the box shrink to its least height before a part of its corner hides for want of room
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Measured the notices' frame while a probe runs
#      Paulinchen  2026-11-01: Logged why each Accept or Decline press answers nothing
#                            - Showed that the framework's settings cannot be read
#                            - Recolored fading rows without laying the box out anew
#                            - Showed an accepted offer sent again at once
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The clock of real time that bubbles, bars and tasks count their seconds by: C#'s
      # NoticeQueue counts it while the game is in front, read once a frame.
      module Clock
        # The topic of C#'s clock, NoticeQueue.ClockTopic.
        TOPIC = "notices.clock"

        # Tells the seconds C#'s clock counted, read once a frame; without the DLL the frames
        # counted as seconds.
        #
        # @return [Float] The seconds.
        def self.seconds
          frame = Key.frame
          return @read[1] if @read && @read[0] == frame

          seconds = Mod_Framework.available? ? Mod_Framework.bridge.call(TOPIC).to_i / 1000.0 : frame.to_f / FRAMES_PER_SECOND
          @read = [frame, seconds]
          seconds
        end

        # Forgets the last read, as F12 starts the game anew.
        def self.reset
          @read = nil
        end
      end

      # The notices every mod shares, in the corner the player picks (the top left by default),
      # drawn through the UI layer: the offers that stand while their source lists them, answered
      # by their Accept and Decline buttons, the first also by the hotkeys :accept and :decline, in
      # a hud docked there that the player places like any part (UI::NoticeStack, kept as
      # ui_notices); and the toasts, each a hud of its own (UI::ToastCard): those of the general
      # stack beyond what is docked in that corner, those of a stack a mod defined with UI.toasts at
      # the corner or spot it named. Nothing of it shows while no offer stands and no toast shows.
      #
      # The offers' rows: the offers that stand, then the offers just answered fading out; "+N more"
      # past SHOWN. A declined offer stays away while it stands with the same mark, an accepted one
      # too but for at most ACCEPT_HOLD frames (release shows it again at once). C#'s NoticeQueue
      # keeps the toasts and the rules of each stack: which show, which wait in line, how far each
      # lies from its place at its stack's start and how opaque it is, each toast's seconds running
      # from the moment it shows on a clock that always runs. It tells only what moved, so a still
      # toast costs no work here. The notices show on the map, in menus and in battle; they hide on
      # the title, on game over, in novel scenes and while a hide_while block answers true. They
      # never take the game's keys: cancel stays the game's.
      module Notices
        # Its place's name, kept as ui_notices.
        ID = :notices

        # Its name while the player arranges.
        PLACE_NAME = "Notifications"

        # The offers' width at their default place.
        WIDTH = 390

        # The offers' least size: two rows.
        MIN_SIZE = [298, 48]

        # The offers' place among the parts docked in their corner: below a mod's own unless that
        # asks for more.
        DOCK_ORDER = 100

        # The most rows of offers that show; the rest are "+N more".
        SHOWN = 5

        # The widest a toast gets, its frame included; a longer text wraps.
        MOST_WIDTH = 300

        # The most lines a toast shows; the last of a longer text ends with "...".
        MOST_LINES = 4

        # The topics of C#'s NoticeQueue.
        TOAST_TOPIC = "notices.toast"
        STACK_TOPIC = "notices.stack"
        DROP_TOPIC = "notices.drop"
        DROP_GROUP_TOPIC = "notices.drop_group"

        # The event of C#'s NoticeQueue that tells where the toasts shown lie and which went.
        EVENT = "notices.toasts"

        # The name of C#'s NoticeQueue in the tick, which ticks it while it holds toasts.
        MODEL = "notices".freeze

        # The severities of a toast, as the alert's.
        SEVERITIES = [:normal, :info, :success, :warning, :error]

        # Pixels between the screen's edge and a toast, Docks.Margin in C#.
        MARGIN = 8

        # Pixels between the toasts and what is docked in their corner, Docks.Gap in C#.
        GAP = 4

        # Whether each corner lies at the left and at the top.
        CORNER_SIDES = { :top_left => [true, true], :top_right => [false, true], :bottom_left => [true, false], :bottom_right => [false, false] }

        # The name C#'s tree tells the room of each corner by.
        ZONES = { :top_left => "top_left", :top_right => "top_right", :bottom_left => "bottom_left", :bottom_right => "bottom_right" }

        # The corners the player picks for the stack, by their names in the options row.
        CORNERS = { "Top Left" => :top_left, "Top Right" => :top_right, "Bottom Left" => :bottom_left, "Bottom Right" => :bottom_right }

        # The options row of the corner and the setting that keeps it.
        CORNER_OPTION = :mf_notice_corner
        CORNER_SETTING = "notice_corner"

        # The corner row's name and help.
        CORNER_NAME = "Notice Corner"
        CORNER_HELP = "The corner of the screen the notices and toasts of every mod show in."

        # Frames an accepted offer stays away at most, so a second press accepts nothing.
        ACCEPT_HOLD = 600

        # What the row past the shown rows says.
        MORE_TEXT = "+%d more"

        # The Accept button's text unless the offer gives one.
        ACCEPT_TEXT = "Accept"

        # The Decline button's text.
        DECLINE_TEXT = "Decline"

        # The ids of the rows of answered offers fading out, by their place among them.
        FADING_IDS = (0...SHOWN).map { |place| "mf_notices_fading_#{place}" }

        # What the notice that the framework's settings cannot be read is about.
        SETTINGS_KEY = :framework_ini

        # Seconds the notice that the framework's settings cannot be read shows.
        SETTINGS_SECONDS = 10

        # The scenes it hides in, by their class names, besides those whose name holds NOVEL.
        HIDDEN_SCENES = ["Scene_Title", "Scene_Gameover"]

        # What the class name of a novel scene holds.
        NOVEL = /Novel/

        # The rows of a stack with nothing to show, and the offers of no source.
        NO_ROWS = [].freeze

        # The hotkeys that answer the first offer.
        ANSWERS = [:accept, :decline]

        # What a toast's top is while its hud did not show; the log says why.
        REFUSED = :refused

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "notices"

        # The toasts queued in C# by their ids, each as look made it, with :top once it shows.
        @toasts = {}

        # Whether C# holds toasts, so it ticks each frame.
        @queued = false
        @toast_id = 0
        @showing = false
        @corner = nil
        @sources = {}
        @hiders = {}

        # The scene class hidden_scene? last looked at and its answer.
        @hidden_class = nil
        @hidden_answer = false
        @declined = {}
        @accepted = {}
        @fading = []
        @first = nil
        @shown_rows = nil
        @answered = nil

        # A count that goes up whenever the rows of offers or the corner changed.
        @serial = 0

        # Where each stack a mod defined lies, by its name: { :corner => a corner or nil, :at =>
        # [x, y] or nil, :grows_up => whether it grows up }, as C# read it. Kept through F12, as the
        # mods defined them once.
        @stacks = {}

        # The corner C# was told the general stack lies at, nil before it was told.
        @told_corner = nil

        # The top of the offers' hud, nil while it does not show.
        @stack = nil

        # Queues a toast, which shows from the next frame on, or waits in line while its stack
        # shows its most; it never waits itself, so an event's Script command or a battle event
        # goes on at once. A toast into a stack no mod defined is refused, logged once per stack.
        #
        # @param text [String] What it says; wrapped past MOST_WIDTH.
        # @param options [Hash] :seconds (its stack's, 3 for the general stack; counted from the
        #   moment it shows), :severity (:normal, :info, :success, :warning or :error, the color of
        #   its bar), :icon (an icon before it: an IconSet index, a name UI.icon gave or { file:
        #   path }), :key (a newer toast of its stack with the same key takes its place and starts
        #   its time again), :group (see drop_group), :stack (the name a mod gave UI.toasts; nil
        #   for the general stack).
        # @return [nil] Nothing.
        def self.show(text, options = {})
          return nil unless Mod_Framework.available?

          stack = options[:stack]
          unless stack.nil? || @stacks.key?(stack)
            log_once([:no_stack, stack], "toasts into the stack #{stack.inspect} were refused: no mod defined it with UI.toasts, so they do not show")
            return nil
          end

          tell_corner if stack.nil?
          severity = SEVERITIES.include?(options[:severity]) ? options[:severity] : :normal
          key = options[:key]
          id = @toast_id += 1
          toast = look(text.to_s, severity, icon_of(options[:icon]))
          toast[:stack] = stack
          milliseconds = options[:seconds].nil? ? nil : (options[:seconds].to_f * 1000).round
          shows = Mod_Framework.bridge.call(TOAST_TOPIC, [id, milliseconds, key.nil? ? nil : key.inspect, options[:group].nil? ? nil : options[:group].inspect,
                                                          toast[:size][0], toast[:size][1], stack.nil? ? nil : stack.inspect])
          return nil unless shows

          @toasts[id] = toast
          @queued = true
          log("toast #{id}#{stack.nil? ? '' : " into #{stack.inspect}"} for #{shows / 1000.0} s#{key.nil? ? '' : " (#{key})"}: #{text}")
          nil
        end

        # Defines a stack of toasts of a mod, or defines it anew; C# reads its options, logs each
        # one refused and keeps the stack's rules, and its toasts lie where C# says it lies.
        #
        # @param name [Symbol, String] The stack's name, such as :my_traps.
        # @param options [Hash] See UI.toasts.
        # @return [nil] Nothing.
        def self.define_stack(name, options)
          unless name.is_a?(Symbol) || name.is_a?(String)
            log("UI.toasts was refused: a toast stack needs a name such as :my_traps, not #{name.inspect}")
            return nil
          end
          unless options.is_a?(Hash)
            log("UI.toasts #{name.inspect} was refused: its options are #{options.inspect}, not a Hash such as { corner: :top_right }")
            return nil
          end
          return nil unless Mod_Framework.available?

          wired = {}
          options.each { |option, value| wired[option.to_s] = wire(value) }
          placed = Mod_Framework.bridge.call(STACK_TOPIC, [name.inspect, wired])
          return nil unless placed

          corner = placed["corner"]
          @stacks[name] = { :corner => corner && corner.to_sym, :at => placed["at"], :grows_up => placed["grows"] == "up" }
          place_toasts
          nil
        end

        # Lays a toast out: its size as UI::ToastCard draws it, an alert whose text wraps to the
        # room MOST_WIDTH leaves, MOST_LINES lines at most.
        #
        # @param text [String] What it says.
        # @param severity [Symbol] Its severity.
        # @param icon [Integer, Hash, nil] Its icon, see show.
        # @return [Hash] :text, :severity, :icon, :lines (how many it shows) and :size.
        def self.look(text, severity, icon)
          room = Alert::ROOM
          across = room[1] + room[3] + Canvas::OUTLINE_ROOM + (icon ? ICON_STEP : 0)
          bitmap = UI.font_bitmap(Style::SMALL_SIZE)
          lines = UI.wrap(bitmap, text, MOST_WIDTH - across)
          lines = [""] if lines.empty?
          widest = lines.map { |line| UI.text_width(bitmap, line) }.max
          count = [lines.size, MOST_LINES].min
          line = icon ? LINE_HEIGHT : UI.line_height_of(:small)
          { :text => text, :severity => severity, :icon => icon, :lines => count,
            :size => [[widest + across, MOST_WIDTH].min, room[0] + room[2] + count * line] }
        end

        # Ends a toast before its time: shown, it fades out; waiting, it never shows.
        #
        # @param key [Object] The toast's key.
        # @return [nil] Nothing.
        def self.drop(key)
          dropped = Mod_Framework.available? && Mod_Framework.bridge.call(DROP_TOPIC, key.inspect)
          log("toast #{key} dropped") if dropped
          nil
        end

        # Takes away every toast, answered offer and fading row of a group, such as everything about
        # a place that just closed.
        #
        # @param name [Object] The group.
        # @return [nil] Nothing.
        def self.drop_group(name)
          Mod_Framework.bridge.call(DROP_GROUP_TOPIC, name.inspect) if Mod_Framework.available?
          @fading.reject! { |row| row[:group] == name }
          @declined.reject! { |_key, answer| answer[:group] == name }
          @accepted.reject! { |_key, answer| answer[:group] == name }
          log("group #{name} dropped")
          nil
        end

        # Registers a block that lists the offers standing now, asked every frame while the stack
        # shows; a second block of the same name replaces the first. An offer is a Hash of :key,
        # :text, :decline (a block, required), :accept (a block; without one only Decline shows),
        # :accept_text (ACCEPT_TEXT), :color (:text), :mark (what tells a new offer from the one
        # declined, its text by default) and :group.
        #
        # @param name [Object] The source's name.
        # @param options [Hash] :log (where a failure of the block or an answer is logged).
        # @return [nil] Nothing.
        def self.offers(name, options = {}, &block)
          @sources[name] = [block, options[:log]]
          nil
        end

        # Shows an accepted offer again at once, as when the other side turned the accept down.
        #
        # @param key [Object] The offer's key.
        # @return [nil] Nothing.
        def self.release(key)
          log("offer #{key} released") if @accepted.delete(key)
          nil
        end

        # Tells whether the stack may show in this scene now: not on the title, on game over or in
        # a novel scene, and not while a hide_while block answers true.
        #
        # @return [Boolean] Whether it may.
        def self.shown?
          scene = Game.current_scene
          return false if scene && hidden_scene?(scene)

          @hiders.each_value { |hider| return false if hides?(hider[0], hider[1]) }
          true
        end

        # Hides the stack while a block answers true; a second block of the same name replaces the
        # first, and nil takes it away.
        #
        # @param name [Object] The block's name.
        # @return [nil] Nothing.
        def self.hide_while(name, &block)
          block ? @hiders[name] = [name, block] : @hiders.delete(name)
          nil
        end

        # Tells whether no offer and no answered offer shows.
        #
        # @return [Boolean] Whether none does.
        def self.empty?
          @shown_rows.nil? || @shown_rows.empty?
        end

        # Tells whether the stack showed at this frame, as shown? answered it once.
        #
        # @return [Boolean] Whether it did.
        def self.showing?
          @showing
        end

        # Tells whether the stack hides at this frame, which its huds hide by.
        #
        # @return [Boolean] Whether it does.
        def self.hiding?
          !@showing
        end

        # Lists the rows of offers the stack shows: the offers, then those just answered fading out.
        #
        # @return [Array<Array>] Each [kind, row], kind :offer or :fading.
        def self.rows
          @shown_rows || NO_ROWS
        end

        # Tells a count that goes up whenever the rows of offers or the corner changed, which
        # UI::NoticeStack watches.
        #
        # @return [Integer] The count.
        def self.serial
          @serial
        end

        # Lists the engine's roots of the toasts that show, oldest first.
        #
        # @return [Array<Box>] The roots.
        def self.toasts
          @toasts.values.map { |toast| root_of(toast[:top]) }.compact
        end

        # @return [Box, nil] The engine's root of the offers, nil while they do not show.
        def self.box
          root_of(@stack)
        end

        # Follows the frame: whether the stack shows is kept for C#'s tick, the toasts follow what is
        # docked in their corner, the offers are listed, and the offers' hud shows while it has rows
        # and goes once it has none; while the stack hides, it keeps what it showed and answers
        # nothing. Called before every frame shows.
        def self.frame
          return unless Mod_Framework.available? && Game.current_scene

          showing = shown?
          post_settings_notice if showing
          Serials.bump(:notices) unless showing == @showing
          @showing = showing
          count_down
          follow_corner if @queued
          unless showing
            @first = nil
            return refuse_presses(nil)
          end

          rows = rows_of(standing_offers)
          refuse_presses(rows)
          if rows_changed?(rows)
            tell_change(rows)
            @serial += 1
          end
          @shown_rows = rows
          @first = rows.first && rows.first[0] == :offer ? rows.first[1] : nil
          rows.empty? ? end_stack : start_stack
          fade_rows unless @fading.empty?
        rescue => e
          log_once([:frame, e.class], "the notices FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Answers an offer, from its button or, for the first, its hotkey.
        #
        # @param accept [Boolean] Whether it accepts.
        # @param offer [Hash, nil] The offer, the first by default.
        def self.answer(accept, offer = @first)
          return log("#{accept ? 'Accept' : 'Decline'} answered nothing: no offer stands") unless offer

          Sound.play_cancel unless accept
          block = accept ? offer[:accept] : offer[:decline]
          begin
            block.call if block
          rescue => e
            log_into(offer[:log], "the #{accept ? 'accept' : 'decline'} of #{offer[:key]} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          end
          answer = { :mark => mark_of(offer), :group => offer[:group], :left => ACCEPT_HOLD }
          accept ? @accepted[offer[:key]] = answer : @declined[offer[:key]] = answer
          @fading << { :text => offer[:text].to_s, :color => offer[:color], :group => offer[:group], :left => Style::FADE_FRAMES }
          @first = nil if offer.equal?(@first)
          @answered = Key.frame
          log("offer #{offer[:key]} #{accept ? 'accepted' : 'declined'}: #{offer[:text]}")
          drop_answered(offer)
        end

        # Takes an answered offer out of the rows at once, its fading row in its place, even while
        # the stack hides and keeps its rows. The offer is found by its key, since its button holds
        # the row it was drawn with, which each frame's rows replace.
        #
        # @param offer [Hash] The offer.
        def self.drop_answered(offer)
          left = rows.select { |kind, row| kind == :offer && row[:key] != offer[:key] }.map { |_kind, row| row }
          @shown_rows = rows_of(left)
          tell_change(@shown_rows)
          @serial += 1
        end
        private_class_method :drop_answered

        # Forgets everything, as F12 starts the game anew; C#'s queue goes with its context, the
        # huds with the UI layer.
        def self.reset
          @toasts = {}
          @queued = false
          @toast_id = 0
          @start = nil
          @declined = {}
          @accepted = {}
          @fading = []
          @first = nil
          @shown_rows = nil
          @answered = nil
          @stack = nil
        end

        # Shows once that the framework's settings cannot be read, called only while the stack
        # shows, so its time never runs out unseen on the title.
        def self.post_settings_notice
          text = Mod_Framework::Settings.take_notice
          show(text, :key => SETTINGS_KEY, :seconds => SETTINGS_SECONDS) if text
        end
        private_class_method :post_settings_notice

        # Tells the engine's root of a hud of the stack that shows.
        #
        # @param top [Layer::Top, Symbol, nil] The hud's top, REFUSED or nil.
        # @return [Box, nil] The root, nil for none.
        def self.root_of(top)
          top.is_a?(Layer::Top) && !top.closed && top.root ? top.root.engine : nil
        end
        private_class_method :root_of

        # Tells whether a scene is one the stack hides in, worked out once per scene class.
        #
        # @param scene [Scene_Base] The scene.
        # @return [Boolean] Whether it is.
        def self.hidden_scene?(scene)
          return @hidden_answer if scene.class.equal?(@hidden_class)

          @hidden_class = scene.class
          @hidden_answer = scene.class.name.to_s =~ NOVEL || HIDDEN_SCENES.any? { |name| Object.const_defined?(name) && scene.is_a?(Object.const_get(name)) } ? true : false
        end
        private_class_method :hidden_scene?

        # Asks a hide_while block, a failing one logged once and taken as false.
        #
        # @param name [Object] The block's name.
        # @param block [Proc] The block.
        # @return [Boolean] Whether it hides the stack.
        def self.hides?(name, block)
          block.call ? true : false
        rescue => e
          log_once([:hider, name, e.class], "the hide_while block #{name} failed, so it hides nothing: #{Logging.failure(e)}")
          false
        end
        private_class_method :hides?

        # Turns a toast's icon into what it shows: a name UI.icon gave into its IconSet index or
        # picture file; a name nobody gave is logged once and shows no icon.
        #
        # @param icon [Integer, Symbol, Hash, nil] The icon as the mod gave it.
        # @return [Integer, Hash, nil] The IconSet index or { file: path }, nil for none.
        def self.icon_of(icon)
          return icon if icon.nil? || icon.is_a?(Integer) || icon.is_a?(Hash)

          found = icon.is_a?(Symbol) ? Looks.icon_of(icon) : nil
          log_once([:icon, icon], "a toast names the icon #{icon.inspect}, which no mod named with UI.icon, so it shows none") unless found
          found
        end
        private_class_method :icon_of

        # Lists the rows of offers: the offers, then the rows fading out after their answer.
        #
        # @param offers [Array<Hash>] The offers that stand.
        # @return [Array<Array>] Each [kind, row], kind :offer or :fading.
        def self.rows_of(offers)
          return NO_ROWS if offers.empty? && @fading.empty?

          offers.map { |offer| [:offer, offer] } + @fading.map { |row| [:fading, row] }
        end
        private_class_method :rows_of

        # Tells whether the rows differ from those shown last in kind, key, mark, text, color or
        # answers, so an offer replaced by another of the same text gets its own buttons.
        #
        # @param rows [Array<Array>] The rows, see rows_of.
        # @return [Boolean] Whether they do.
        def self.rows_changed?(rows)
          shown = @shown_rows || NO_ROWS
          return true unless rows.size == shown.size

          rows.each_index do |index|
            now = rows[index][1]
            was = shown[index][1]
            return true unless rows[index][0] == shown[index][0] && now[:key] == was[:key] && now[:mark] == was[:mark] && now[:text] == was[:text] &&
                               now[:color] == was[:color] && now[:accept].nil? == was[:accept].nil? && now[:accept_text] == was[:accept_text]
          end
          false
        end
        private_class_method :rows_changed?

        # Counts a frame of the fading rows and of the accepted offers' hold.
        def self.count_down
          return if @fading.empty? && @accepted.empty?

          @fading.each { |row| row[:left] -= 1 }
          @fading.reject! { |row| row[:left] <= 0 }
          @accepted.each_value { |answer| answer[:left] -= 1 }
          @accepted.select { |_key, answer| answer[:left] <= 0 }.each_key { |key| log("the hold of accepted offer #{key} ran out") }
          @accepted.reject! { |_key, answer| answer[:left] <= 0 }
        end
        private_class_method :count_down

        # Lists the offers that stand now and show: those of every source but the ones declined with
        # the same mark and the ones accepted lately with the same mark. An answered offer that no
        # longer stands, or stands with another mark, is forgotten.
        #
        # @return [Array<Hash>] The offers, each with :log.
        def self.standing_offers
          return NO_ROWS if @sources.empty? && @declined.empty? && @accepted.empty?

          offers = nil
          @sources.each do |name, (block, target)|
            listed = begin
              Array(block.call)
            rescue => e
              log_into(target, "the offers of #{name} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}", [:offers, name, e.class])
              []
            end
            listed.each do |offer|
              next log_once([:no_decline, name, offer[:key]], "an offer of #{name} has no :decline, so it does not show: #{offer[:text]}") unless offer.is_a?(Hash) && offer[:decline]

              (offers ||= []) << offer.merge(:log => target)
            end
          end
          if offers.nil?
            @declined.clear
            @accepted.clear
            return NO_ROWS
          end

          standing = offers.map { |offer| offer[:key] }
          [@declined, @accepted].each do |answered|
            answered.reject! { |key, answer| !standing.include?(key) || offers.none? { |offer| offer[:key] == key && mark_of(offer) == answer[:mark] } }
          end
          offers.reject { |offer| @declined.key?(offer[:key]) || @accepted.key?(offer[:key]) }
        end
        private_class_method :standing_offers

        # Tells what tells an offer from the one declined.
        #
        # @param offer [Hash] The offer.
        # @return [Object] Its :mark, else its text.
        def self.mark_of(offer)
          offer.key?(:mark) ? offer[:mark] : offer[:text].to_s
        end
        private_class_method :mark_of

        # Logs a press of the Accept or Decline hotkey that no button of the stack takes, with why;
        # a press a button takes, or one C#'s tree keeps quiet, is the tree's to log.
        #
        # @param rows [Array, nil] The rows, nil while the stack hides.
        def self.refuse_presses(rows)
          ANSWERS.each do |action|
            code = Hotkeys.code(action)
            next unless code && Key.triggered?(code) && @answered != Key.frame

            why = refusal(action, rows)
            log("#{Hotkeys.label(action)} answered nothing: #{why}") if why
          end
        end
        private_class_method :refuse_presses

        # Tells why a press of the Accept or Decline hotkey answers nothing where the stack has no
        # button for it.
        #
        # @param action [Symbol] :accept or :decline.
        # @param rows [Array, nil] The rows, nil while the stack hides.
        # @return [String, nil] Why, nil when a button of the stack takes it or the player types.
        def self.refusal(action, rows)
          return nil if UI.typing?
          return "the notices hide" if rows.nil?
          return "no offer stands" unless rows.first && rows.first[0] == :offer
          return "the first offer cannot be accepted" if action == :accept && !rows.first[1][:accept]

          nil
        end
        private_class_method :refusal

        # Shows the offers' hud once it has rows.
        def self.start_stack
          return if @stack && !@stack.closed

          @stack = Layer.start(:show, UI::NoticeStack, {}, nil)
          log("the offers show") if @stack
        end
        private_class_method :start_stack

        # Takes the offers' hud away once it has no rows; it fades out and frees its room.
        def self.end_stack
          return unless @stack

          Layer.close_top(@stack, nil) unless @stack.closed
          @stack = nil
          log("the offers went")
        end
        private_class_method :end_stack

        # Draws the rows of answered offers as see-through as their fade has left them, without
        # drawing them anew.
        def self.fade_rows
          root = box
          return unless root

          @fading.each_with_index do |row, place|
            part = place < SHOWN ? root.find(FADING_IDS[place]) : nil
            part.opacity = Component::OPAQUE * [row[:left], 0].max / Style::FADE_FRAMES if part
          end
        end
        private_class_method :fade_rows

        # Ticks C#'s queue in the frame's tick while it holds toasts.
        def self.collect
          Tick.put(MODEL, nil) if @queued
        end

        # Takes what C#'s queue tells after a tick in which a toast moved, faded, showed or went: the
        # huds of those gone go, a toast that starts showing shows its hud at its stack's start, and
        # each shown hud moves as far from there as C# placed it and takes its opacity. C# ticks on
        # while any toast is left, also one queued after this tick, such as by a click's block.
        #
        # @param event [Hash] {"shown" => [[id, x, y, opacity], ...], "gone" => [id, ...]}.
        def self.take_toasts(event)
          Array(event["gone"]).each { |id| end_toast(id) }
          rows = Array(event["shown"])
          rows.each { |id, x, y, opacity| move_toast(id, x.to_i, y.to_i, opacity.to_i) }
          @queued = !@toasts.empty?
        rescue => e
          log_once([:toasts, e.class], "showing the toasts FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
        end

        # Moves a toast's hud, showing it at its stack's start as it starts showing, without
        # drawing it anew.
        #
        # @param id [Integer] The toast's id.
        # @param x [Integer] Pixels right of its place at its stack's start.
        # @param y [Integer] Pixels below that place.
        # @param opacity [Integer] How opaque it shows, 0 to 255.
        def self.move_toast(id, x, y, opacity)
          toast = @toasts[id]
          return unless toast

          unless toast[:top]
            toast[:at] = toast_at(toast)
            toast[:top] = Layer.start(:show, UI::ToastCard, { :notice => toast, :card_id => "mf_toast_#{id}" }, nil) || REFUSED
            log("toast shows: #{toast[:text]}") unless toast[:top].equal?(REFUSED)
          end
          root = root_of(toast[:top])
          return unless root

          root.opacity = opacity unless root.opacity == opacity
          shift = root.offset
          root.offset = [x, y] unless shift[0] == x && shift[1] == y
        end
        private_class_method :move_toast

        # Takes the hud of a toast that went away and forgets the toast.
        #
        # @param id [Integer] The toast's id.
        def self.end_toast(id)
          toast = @toasts.delete(id)
          return unless toast

          top = toast[:top]
          Layer.close_top(top, nil) if root_of(top)
          log(top ? "toast ended: #{toast[:text]}" : "toast ended without showing: #{toast[:text]}")
        end
        private_class_method :end_toast

        # Places the toasts' huds anew once the room docked in their corner or the screen changed.
        def self.follow_corner
          start = toast_start
          return if start == @start && Graphics.width == @screen_width && Graphics.height == @screen_height

          @start = start
          @screen_width = Graphics.width
          @screen_height = Graphics.height
          place_toasts
        end
        private_class_method :follow_corner

        # Places the huds of the toasts that show at their stacks' starts anew.
        def self.place_toasts
          @toasts.each_value do |toast|
            root = root_of(toast[:top])
            root.at = toast_at(toast) if root
          end
        end
        private_class_method :place_toasts

        # Tells where a toast lies at its stack's start, before C# moves it along the stack: at the
        # spot its mod named, else at its corner, MARGIN in from the edges; at the general stack's
        # corner past what is docked there. It lies by its bottom edge on the start in a stack that
        # grows up and by its top edge in one that grows down, so toasts of other heights never
        # overlap as C# moves each the room of those before it.
        #
        # @param toast [Hash] The toast, as look made it, with :stack.
        # @return [Array<Integer>] Its left and top.
        def self.toast_at(toast)
          place = toast[:stack].nil? ? nil : @stacks[toast[:stack]]
          size = toast[:size]
          if place && place[:at]
            left, start = place[:at]
            grows_up = place[:grows_up]
          else
            on_left, on_top = CORNER_SIDES[place ? place[:corner] : corner_now]
            left = on_left ? MARGIN : Graphics.width - MARGIN - size[0]
            room = place ? MARGIN : toast_start
            start = on_top ? room : Graphics.height - room
            grows_up = place ? place[:grows_up] : !on_top
          end
          [left, grows_up ? start - size[1] : start]
        end
        private_class_method :toast_at

        # Tells C# the corner of the general stack once it differs from the corner C# was told,
        # which the side its toasts slide in from and the direction it grows in follow.
        def self.tell_corner
          corner = corner_now
          return if corner == @told_corner

          @told_corner = corner if Mod_Framework.bridge.call(STACK_TOPIC, [nil, { "corner" => corner.to_s }])
        end
        private_class_method :tell_corner

        # Turns an option's value into one that crosses the bridge: a Symbol or a Float into its
        # text, an Array item by item, and anything else C# cannot read into its inspect, which C#
        # refuses by name.
        #
        # @param value [Object] The value.
        # @return [Object] The value as it crosses.
        def self.wire(value)
          case value
          when Symbol, Float then value.to_s
          when Array then value.map { |item| wire(item) }
          when Integer, String, true, false, nil then value
          else value.inspect
          end
        end
        private_class_method :wire

        # Tells the pixels between the corner's edge of the screen and the first toast: past what
        # is docked there, the offers among it, or MARGIN in an empty corner.
        #
        # @return [Integer] The pixels.
        def self.toast_start
          room = Layout.docked_room(ZONES[corner_now])
          room > 0 ? room + GAP : MARGIN
        end
        private_class_method :toast_start

        # Tells the corner the stack is in, read from the settings once.
        #
        # @return [Symbol] The corner.
        def self.corner_now
          @corner ||= corner
        end
        private_class_method :corner_now

        # Offers the corner of the stack as a row of Options > Mods, kept in the framework's
        # settings, and docks the stack there.
        def self.offer_corner
          Options.keep(CORNER_OPTION, Options::GROUP + CORNER_NAME, CORNER_HELP, lambda { CORNERS.keys },
                       lambda { CORNERS.key(corner) || CORNERS.keys.first }, lambda { |name| Notices.corner = CORNERS[name] })
        end

        # Tells the corner the player picked for the stack.
        #
        # @return [Symbol] The corner, such as :top_left.
        def self.corner
          picked = Settings.setting(CORNER_SETTING).to_s
          CORNERS.values.find { |each| each.to_s == picked } || :top_left
        end

        # Docks the stack in a corner and keeps it; the offers' hud docks there as it renders anew.
        #
        # @param value [Symbol, nil] The corner, nil for the top left.
        def self.corner=(value)
          value = CORNERS.values.include?(value) ? value : :top_left
          Settings.store(CORNER_SETTING, value.to_s)
          @corner = value
          @serial += 1
          @start = nil
          @told_corner = nil
          tell_corner if Mod_Framework.available?
          follow_corner
          log("the notices show at the #{value.to_s.tr('_', ' ')}")
        end

        # Logs what the offers show now, once it changed.
        #
        # @param rows [Array] The rows.
        def self.tell_change(rows)
          log(rows.empty? ? "the offers show nothing" : "the offers show: #{rows.map { |kind, row| "#{kind} #{row[:text]}" }.join(' | ')}")
        end
        private_class_method :tell_change

        # Logs a failure into the log of the mod that gave it, else the framework's.
        #
        # @param target [#log, nil] The mod's log.
        # @param message [String] The line.
        # @param once [Object, nil] A key to log it only once, nil for always.
        def self.log_into(target, message, once = nil)
          return if once && !Logging.first_time?(self, once)

          target.respond_to?(:log) ? target.log(message) : log(message)
        end
        private_class_method :log_into
      end
    end

    Run.on_start("notices", :dll => true) do
      Mod_Framework::UI::Engine::Notices.offer_corner
      Engine::Tick.collect("Mod Framework notices") { Mod_Framework::UI::Engine::Notices.collect }
      Hooks.outermost(Graphics.singleton_class, :update, :before, "Mod Framework notices") { Mod_Framework::UI::Engine::Notices.frame }
    end
    Run.on_reset("notices") { Mod_Framework::UI::Engine::Notices.reset }
    Run.on_reset("clock") { Mod_Framework::UI::Engine::Clock.reset }
    Mod_Framework.bridge.on(Engine::Notices::EVENT) { |event| Mod_Framework::UI::Engine::Notices.take_toasts(event) }
  end
end
