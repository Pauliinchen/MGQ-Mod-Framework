#----------------------------------------------------------------
#  layout.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Freed the overlay's screen-sized picture when the screen's size changes
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#                            - Kept every place under its mod, with no ids kept apart
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#                            - Wrote the help of the Options row as one text, which the help window breaks to its width
#      Paulinchen  2026-11-05: Named the layout in the tick by a frozen text, which the tick keeps without a copy
#                            - Kept the offered boxes from tick to tick and handed C# a new list of them only once one changed
#      Paulinchen  2026-11-04: Kept a place as its zone and offset, turned an older place in pixels into one once, and kept
#                              a new part's place under its mod and id, the kept place ids under their old keys
#                            - Added room, the pixels a zone's parts take
#                            - Put back every place the settings keep, also of parts not open, on Default of Interface
#                              Positions
#                            - Kept the place of a box that stores none only while the game runs
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-31: Told the room the roots docked at a corner take
#      Paulinchen  2026-10-30: Logged a missing row of the Mod Config without naming Mod Config Remake
#      Paulinchen  2026-10-28: Moved into the Mod Framework from ui_layout.rbx
#                            - Kept every box within a most size as well as a least size
#                            - Took how a box resizes and whether it moves as options
#                            - Kept the places in the framework's ini
#                            - Left Alt, the button and the mouse to the DLL's input model
#                            - Added forget
#                            - Kept the framework's own settings and unregistered boxes out of drags
#      Paulinchen  2026-10-23: Left the fitting, the drags and the double click to C#, keeping the places it answers
#                            - Removed dragging?, which only the tests read
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Where the floating boxes and windows of the mods lie and how large they are, which the player
      # changes with the left Alt held: a drag inside a movable box moves it, a drag on the edge or
      # corner of a resizable one resizes it, a double click puts it back where it starts. Each box
      # keeps its place in the framework's settings as the zone of the screen it lies in and the
      # offset from that zone's point, so it stays in its corner at another screen size, never
      # smaller than its least size and never larger than its most size or the screen.
      #
      # A box registers once with its name and sizes, asks rect for where to draw each frame, and
      # offers where it drew while it shows. C# keeps the rules (LayoutModel): the fitting, the drags
      # and the double click, read from the DLL's input of the same tick; the frame's tick hands it the
      # boxes offered in the frame before, its events keep the places and the settings up to date, and
      # the overlay outlines the boxes above everything here. Without the DLL every box lies at its
      # default.
      #
      # It must never interrupt the game, so every entry point rescues.
      module Layout
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "layout"

        # Windows' code of the left Alt; the right Alt is AltGr, which types characters.
        ALT_KEY = 0xA4

        # What starts a box's setting, followed by its id: "zone,dx,dy,width,height".
        SETTING_PREFIX = "ui_"

        # Ids a box cannot take, since their settings are the framework's own.
        RESERVED = [:preset, :game_windows, :game_mouse]

        # Pixels inside a box's border on which a drag resizes it rather than moving it, as
        # LayoutModel.Grab in C#.
        GRAB = 8

        # The least size of a box that names none: room for the grab on both sides.
        MIN_SIZE = [2 * GRAB, 2 * GRAB]

        # How a box resizes, by the :resizable option, as C# names it: both ways, in width alone, in
        # height alone, or not at all.
        RESIZES = { true => "both", :width => "width", :height => "height", false => "none", nil => "none" }

        # Color of every box's outline while Alt is held.
        OUTLINE = Color.new(255, 255, 255, 200)

        # Color of the light wash over the box under the mouse or being dragged.
        WASH = Color.new(255, 255, 255, 36)

        # Side of the grip drawn into a resizable box's bottom right corner while Alt is held.
        GRIP = 10

        # What the screen says at its bottom while Alt is held.
        HINT = "Alt + drag: move   Drag an edge: resize   Double-click: reset"

        # Height of the hint's plate.
        HINT_HEIGHT = 22

        # The Options > Mods row's key.
        OPTION = :mf_ui_positions

        # The Options > Mods row's name.
        OPTION_NAME = "Interface Positions"

        # The Options > Mods row's help.
        OPTION_HELP = "Hold the left Alt: drag a window or box of a mod to move it, its edge to resize it, and " \
                      "double-click one to put it back. Pick Default to put every one back where it starts."

        # The row's value while any box was moved or resized.
        MOVED = "Moved"

        # The row's value that puts every box back.
        DEFAULT = "Default"

        # A box the player can arrange: its name for the log and the outline, how it resizes as C#
        # names it, see RESIZES, and whether it moves.
        Box = Struct.new(:name, :resize, :movable)

        # Where a box drew in the frame before, its depth deciding which of two overlapping boxes a
        # click takes, and the tick it was offered for.
        Offer = Struct.new(:id, :rect, :z, :tick)

        # The boxes the outline draws while the player does not arrange them.
        NO_OFFERS = [].freeze

        # Makes a box arrangeable in C#, LayoutModel.RegisterTopic.
        REGISTER = "ui.layout.register"

        # Tells where a box draws, LayoutModel.RectTopic.
        RECT = "ui.layout.rect"

        # Puts a box back, LayoutModel.ResetTopic.
        RESET = "ui.layout.reset"

        # The layout's event, LayoutModel.EventTopic.
        EVENT = "ui.layout"

        # The layout's name in the tick, LayoutModel.ModelName.
        MODEL = "layout".freeze

        # The registered boxes, by their ids.
        @boxes = {}

        # Where each box draws as C# answered: the default and the screen it answered for, and the
        # place, by the boxes' ids.
        @stored = {}

        # Whether the player moved or resized each box, by the boxes' ids.
        @moved = {}

        # The boxes offered, kept from tick to tick; a tick drops those not offered since the last.
        @offers = []

        # The ticks counted, which mark the boxes offered for each.
        @tick = 0

        # The list of the boxes last handed C#, nil once one changed.
        @handed_list = nil

        # Whether a drag runs, as C# said.
        @dragging = false

        # The box under the mouse or being dragged, as C# said.
        @hot = nil

        # Whether the last tick handed C# any box or a drag, so the tick after it hands it the frame
        # in which they are gone.
        @handed = false

        # Tells the pixels the shown roots of a dock take at their default places, from the dock's
        # edge, for a mod that moves a game window of its own clear of them; a top corner counts the
        # strips docked at :top.
        #
        # @param dock [Symbol] :top_left, :top_right, :bottom_left, :bottom_right or :top.
        # @return [Integer] The pixels, 0 while none shows there.
        def self.docked_room(dock)
          Tree.docked_room(dock)
        end

        # Tells the pixels the shown, unmoved parts of a zone take from the zone's edge, for a mod
        # that keeps a game window of its own clear of them.
        #
        # @param zone [Symbol] One of the nine zones, such as :top_left.
        # @return [Integer] The pixels, 0 while none shows there.
        def self.room(zone)
          Tree.docked_room(zone)
        end

        # Tells the id a part's place is kept under: the mod and the id, so two mods' ids never
        # meet.
        #
        # @param mod [String] The mod, such as "Camp Notes".
        # @param id [Symbol, String] The part's id.
        # @return [String] Such as "Camp_Notes/log".
        def self.place_key(mod, id)
          "#{mod.to_s.tr(' ', '_')}/#{id}"
        end

        # Makes a box arrangeable, handing C# its sizes and where the settings keep it.
        #
        # @param id [Symbol] The box, which names its setting.
        # @param name [String] Its name for the outline and the log.
        # @param options [Hash] :min_size ([width, height], MIN_SIZE by default), :max_size ([width,
        #   height], a nil side or none for the screen's), :resizable (true, :width, :height or false;
        #   true by default), :movable (true by default), :stores (false keeps its place only while
        #   the game runs; true by default).
        # @return [Boolean] Whether the player moved or resized it before.
        def self.register(id, name, options = {})
          id = id.to_sym
          if RESERVED.include?(id)
            log_once([:reserved, id], "#{name} was not made arrangeable: its id #{id} names a setting of the framework")
            return false
          end

          resize = RESIZES.fetch(options.key?(:resizable) ? options[:resizable] : true, "both")
          movable = !options.key?(:movable) || options[:movable] ? true : false
          @boxes[id] = Box.new(name.to_s, resize, movable)
          @stored.delete(id)
          min = sides(options[:min_size], MIN_SIZE)
          max = sides(options[:max_size], [0, 0])
          stores = options[:stores] != false
          answer = Mod_Framework.bridge.call(REGISTER, [id.to_s, name.to_s, min[0], min[1], max[0], max[1], resize, movable, stores ? stored_text(id) : nil,
                                                        screen_width, screen_height, stores])
          turned(id, answer[1]) if answer.is_a?(Array)
          @moved[id] = answer.is_a?(Array) && answer[0] == true
        rescue => e
          log_once([:register, id], "#{name} was not made arrangeable: #{Logging.failure(e)}")
          false
        end

        # Tells where a box draws, as C# answers: where it is being dragged, else where the player left
        # it, else its default, fitted to its sizes and the screen. C# is asked once per default and
        # screen; its events keep the answer up to date.
        #
        # @param id [Symbol] The box.
        # @param default [Rect] Where it starts.
        # @return [Rect] Where it draws; its default without the DLL.
        def self.rect(id, default)
          return default unless Mod_Framework.available?

          id = id.to_sym
          key = [default.x, default.y, default.width, default.height, screen_width, screen_height]
          kept = @stored[id]
          return copy(kept[1]) if kept && kept[0] == key

          answer = Mod_Framework.bridge.call(RECT, [id.to_s] + key + [kept ? false : stored_text(id)])
          return default unless answer

          turned(id, answer[5])
          @moved[id] = answer[4] == true
          @stored[id] = [key, Rect.new(*answer[0, 4])]
          copy(@stored[id][1])
        rescue => e
          log_once([:rect, id], "place of #{id} FAILED: #{Logging.failure(e)}")
          default
        end

        # Tells whether a box lies where the player left it rather than at its default.
        #
        # @param id [Symbol] The box.
        # @return [Boolean] Whether it does.
        def self.moved?(id)
          @moved[id.to_sym] == true
        end

        # Tells whether the player is arranging the boxes: the left Alt is held, so the mouse moves and
        # resizes them instead of clicking.
        #
        # @return [Boolean] Whether they are.
        def self.arranging?
          Key.down?(ALT_KEY) || @dragging ? true : false
        end

        # Offers where a registered box drew this frame, so a drag can take it and the outline show it.
        #
        # @param id [Symbol] The box.
        # @param x [Integer] Its left on the screen.
        # @param y [Integer] Its top on the screen.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param z [Integer] Its depth.
        def self.offer(id, x, y, width, height, z = 0)
          return unless Mod_Framework.available?

          id = id.to_sym
          return unless @boxes.key?(id)

          offer = offered(id)
          if offer.nil?
            @offers << Offer.new(id, Rect.new(x.to_i, y.to_i, width.to_i, height.to_i), z.to_i, @tick)
            @handed_list = nil
            return nil
          end

          rect = offer.rect
          unless rect.x == x && rect.y == y && rect.width == width && rect.height == height && offer.z == z
            rect.set(x.to_i, y.to_i, width.to_i, height.to_i)
            offer.z = z.to_i
            @handed_list = nil
          end
          offer.tick = @tick
          nil
        end

        # Finds the offer of a box.
        #
        # @param id [Symbol] The box.
        # @return [Offer, nil] Its offer, nil for none.
        def self.offered(id)
          place = 0
          while place < @offers.size
            return @offers[place] if @offers[place].id == id

            place += 1
          end
          nil
        end
        private_class_method :offered

        # Puts a box back where it starts.
        #
        # @param id [Symbol] The box.
        # @param why [String] What put it back, for the log.
        def self.reset(id, why)
          id = id.to_sym
          @stored.delete(id)
          @moved[id] = false
          Settings.forget(SETTING_PREFIX + id.to_s)
          Mod_Framework.bridge.call(RESET, [id.to_s])
          log("put #{name_of(id)} back (#{why})")
        end

        # Puts every box back where it starts, also the places the settings keep of boxes not open.
        #
        # @param why [String] What put them back, for the log.
        def self.reset_all(why)
          @boxes.keys.each { |id| reset(id, why) if moved?(id) }
          kept_places.each do |id|
            Settings.forget(SETTING_PREFIX + id)
            log("put #{id} back (#{why})")
          end
          nil
        end

        # Lists the ids of the places the settings keep, the framework's own settings left out.
        #
        # @return [Array<String>] The ids.
        def self.kept_places
          Settings.keys_under(SETTING_PREFIX).reject { |id| RESERVED.include?(id.to_sym) }
        end

        # Forgets the place C# answered for a box, so the next rect asks again, as after its default
        # or the screen changed. Its place in the settings stays.
        #
        # @param id [Symbol] The box.
        def self.forget(id)
          @stored.delete(id.to_sym)
          nil
        end

        # Tells whether any box lies where the player left it, or the settings keep a place of one.
        #
        # @return [Boolean] Whether one does.
        def self.any_moved?
          @boxes.keys.any? { |id| moved?(id) } || !kept_places.empty?
        end

        # Keeps the place C# turned from pixels into its zone and offset, once, in the settings.
        #
        # @param id [Symbol] The box.
        # @param text [String, nil] The turned place, nil when nothing was turned.
        def self.turned(id, text)
          return unless text

          Settings.store(SETTING_PREFIX + id.to_s, text)
          log("kept the place of #{name_of(id)} as its zone and offset: #{text}")
        end

        # Hands C# the boxes offered since the tick before, while any are shown or a drag runs and once
        # more after, and draws the outlines. Called just before the frame's tick goes over.
        def self.tick
          @handed_list = nil if @offers.reject! { |offer| offer.tick != @tick }
          @tick += 1
          handing = !@offers.empty? || @dragging
          if handing || @handed
            @handed_list ||= @offers.map { |offer| [offer.id.to_s, offer.rect.x, offer.rect.y, offer.rect.width, offer.rect.height, offer.z] }
            Tick.put(MODEL, @handed_list)
          end
          @handed = handing
          draw(arranging? ? @offers : NO_OFFERS, @hot)
        end

        # Takes the layout's event: places changed, places kept or forgotten in the settings, the drag,
        # the box under the mouse, and the lines for the log.
        #
        # @param event [Hash] The event, see LayoutModel.EventTopic.
        def self.take_event(event)
          (event["rects"] || {}).each do |id, place|
            kept = @stored[id.to_sym]
            kept[1] = Rect.new(*place) if kept
          end
          (event["store"] || {}).each do |id, text|
            next if RESERVED.include?(id.to_sym)

            text ? Settings.store(SETTING_PREFIX + id, text) : Settings.forget(SETTING_PREFIX + id)
            @moved[id.to_sym] = !text.nil?
          end
          @dragging = event["dragging"] if event.key?("dragging")
          @hot = event["hot"] && event["hot"].to_sym if event.key?("hot")
          Array(event["log"]).each { |line| log(line) }
        end

        # Drops what a drag and the offers held as F12 starts the game's scenes again; the place of a
        # drag C# still follows is kept once the button is let go.
        def self.reset_frame
          @offers = []
          @handed_list = nil
          @dragging = false
          @hot = nil
          @handed = false
          draw([], nil)
        end

        # Reads where the settings say the player left a box.
        #
        # @param id [Symbol] The box.
        # @return [String, nil] Its "zone,dx,dy,width,height", or an older "x,y,width,height"; nil for
        #   none.
        def self.stored_text(id)
          text = Settings.setting(SETTING_PREFIX + id.to_s)
          text && text.to_s
        end

        # Reads a size option.
        #
        # @param size [Array, nil] [width, height], a nil side for the fallback's.
        # @param fallback [Array<Integer>] The width and height when none is given.
        # @return [Array<Integer>] The width and height.
        def self.sides(size, fallback)
          size = Array(size)
          [(size[0] || fallback[0]).to_i, (size[1] || fallback[1]).to_i]
        end

        # Draws the outlines of the boxes shown while Alt is held, if they changed: every box framed,
        # the one under the mouse or being dragged washed, a grip in each resizable box's corner, its
        # name at its top left, and the hint at the screen's bottom.
        #
        # @param offers [Array<Offer>] The boxes to outline, none while Alt is let go.
        # @param hot [Symbol, nil] The box C# says is under the mouse or being dragged.
        def self.draw(offers, hot)
          shown = offers.empty? ? nil : [offers.map { |offer| [offer.id, offer.rect.x, offer.rect.y, offer.rect.width, offer.rect.height] }.sort_by { |row| row[0].to_s },
                                         hot, Theme.serial]
          return if shown == @shown && (shown.nil? || (@overlay && !@overlay.disposed?))

          @shown = shown
          return hide_overlay unless shown

          sprite = overlay
          bitmap = sprite.bitmap
          bitmap.clear
          sprite.visible = true
          offers.sort_by { |offer| offer.z }.each { |offer| draw_outline(bitmap, offer, offer.id == hot) }
          style = Style
          style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
          style.draw_plated(bitmap, 0, bitmap.height - HINT_HEIGHT - style::PAD, bitmap.width, HINT_HEIGHT, HINT)
        end

        # Hides the overlay, if there is one.
        def self.hide_overlay
          @overlay.visible = false if @overlay && !@overlay.disposed?
        end

        # Draws one box's outline, see draw.
        #
        # @param bitmap [Bitmap] The overlay's picture.
        # @param offer [Offer] The box.
        # @param hot [Boolean] Whether it is under the mouse or being dragged.
        def self.draw_outline(bitmap, offer, hot)
          rect = offer.rect
          bitmap.fill_rect(rect.x, rect.y, rect.width, rect.height, WASH) if hot
          Style.draw_line_box(bitmap, rect.x, rect.y, rect.width, rect.height, OUTLINE)
          box = @boxes[offer.id]
          draw_grip(bitmap, rect) if box && box.resize != RESIZES[false]
          style = Style
          style.use_font(bitmap, style::TINY_SIZE, style::TEXT)
          style.draw_plated(bitmap, rect.x + 2, rect.y + 2, rect.width - 4, style::TINY_SIZE + 4, name_of(offer.id), 0)
        end

        # Draws the grip into a box's bottom right corner: a small stepped triangle.
        #
        # @param bitmap [Bitmap] The overlay's picture.
        # @param rect [Rect] The box.
        def self.draw_grip(bitmap, rect)
          right = rect.x + rect.width - 2
          bottom = rect.y + rect.height - 2
          (0...GRIP).step(3) { |step| bitmap.fill_rect(right - step, bottom - GRIP + step, step + 1, 1, OUTLINE) }
        end

        # Hands out the overlay the outlines are drawn on, a sprite over the whole screen above
        # everything, made anew once the screen's size changes or it was freed.
        #
        # @return [Sprite] The overlay.
        def self.overlay
          sprite = @overlay
          fits = sprite && !sprite.disposed? && sprite.bitmap && !sprite.bitmap.disposed? &&
                 sprite.bitmap.width == screen_width && sprite.bitmap.height == screen_height
          return sprite if fits

          if sprite && !sprite.disposed?
            old = sprite.bitmap
            sprite.dispose
            old.dispose if old && !old.disposed?
          end
          @overlay = Sprite.new
          @overlay.z = Z[:layout]
          @overlay.bitmap = Bitmap.new(screen_width, screen_height)
          @overlay
        end

        # Names a box for the log and its outline.
        #
        # @param id [Symbol] The box.
        # @return [String] Its name.
        def self.name_of(id)
          box = @boxes[id]
          box ? box.name : id.to_s
        end

        # Copies a place, so no box changes the layout's own.
        #
        # @param rect [Rect] The place.
        # @return [Rect] The copy.
        def self.copy(rect)
          Rect.new(rect.x, rect.y, rect.width, rect.height)
        end

        # Tells the screen's width.
        #
        # @return [Integer] Its pixels.
        def self.screen_width
          Graphics.width
        end

        # Tells the screen's height.
        #
        # @return [Integer] Its pixels.
        def self.screen_height
          Graphics.height
        end

        # Offers the places as a row of Options > Mods: Moved while any box was moved, and Default,
        # which puts every box back.
        def self.add_option
          values = lambda { any_moved? ? [MOVED, DEFAULT] : [DEFAULT] }
          read = lambda { any_moved? ? MOVED : DEFAULT }
          write = lambda { |value| reset_all("picked Default in Options > Mods") if value == DEFAULT }
          added = Options.keep(OPTION, Options::GROUP + OPTION_NAME, OPTION_HELP, values, read, write)
          log(added ? "added the interface positions to Options > Mods" : "no interface positions in Options > Mods, see the options lines")
        end

        # Hands C# the boxes before every tick and offers the row, once the game runs with the DLL.
        def self.start
          Key.watch(ALT_KEY)
          Tick.collect("Mod Framework layout") { Mod_Framework::UI::Engine::Layout.tick }
          add_option
        end

        Run.on_start("layout", :dll => true) { Mod_Framework::UI::Engine::Layout.start }
        Run.on_reset("layout") { Mod_Framework::UI::Engine::Layout.reset_frame }
        Mod_Framework.bridge.on(EVENT) { |event| Mod_Framework::UI::Engine::Layout.take_event(event) }
      end
    end
  end
end
