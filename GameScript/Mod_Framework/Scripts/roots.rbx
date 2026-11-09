#----------------------------------------------------------------
#  roots.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Stacked a root in a named column, kept its place there while it fades out and slid it from the column's side
#                            - Faded a root out or in where a slide left it, and slid on from there
#                            - Turned a root back from a coming or going of another motion where it shows the same
#                            - Counted the frames of a root's coming and going, each way its own frames and its own motion
#                            - Closed a root at once without its leave motion when told
#                            - Drew each part with its background and border around what it draws
#      Paulinchen  2026-11-08: Drew a root that follows a character on the map above the screen's tone and flash
#                            - Showed a root that follows and opened hidden once it may
#      Paulinchen  2026-11-07: Drew what a root holds only inside its content, a badge besides
#                            - Drew a picture whose compact forms not shown hold parts without a place
#                            - Moved the surfaces and the kinds of root into files of their own
#                            - Took a tooltip's column from the pages of a Slides alone
#      Paulinchen  2026-11-06: Sized a box that follows a character to what it holds, without the least size of a floating box
#                            - Laid a tooltip on a side of a part against its root's edge beyond the root's frame, and kept a
#                              tooltip box of texts that do not wrap as wide as they are
#                            - Drew nothing of a part laid out without room
#                            - Kept room for the focus frame of a box without a frame, and drew that frame around what it scrolls
#                            - Drew a root under the game's windows on the scene's top viewport, which neither the screen's tone nor
#                              its flash reaches
#                            - Kept a root closed while it waits for its menu scene from opening there
#                            - Worked out the depth of a popup only as it opens
#                            - Removed answers_under, which no mod gave
#                            - Slid a root with :slide_in in from its zone's edge as it fades in, and out as it fades out
#                            - Moved the sprites, windows and planes the game leaves on a viewport it frees onto a hidden one
#                            - Closed and moved every root given :opened_from with the part it opened from, as the popups did
#                            - Left a popup itself out of the popups it opens above, so placing it anew keeps its depth
#                            - Kept the question box of the UI layer above the roots it holds
#                            - Told C# a root joined to a game window, which takes the focus only when that window hands it over
#                            - Played no cancel sound of a root joined to a game window, which that window's cancel plays
#                            - Played the cancel sound of a root of the UI layer only as cancel closes it
#      Paulinchen  2026-11-05: Drew a root as see-through as its own opacity, such as a toast that fades
#                            - Took the place and the size of a game window given as :over, hidden until the root closes
#                            - Told a box that scrolls which lines of its texts are in sight, and framed one that scrolls while it has the focus
#                            - Followed a character only once a root has a place, and placed and asked roots with fewer objects
#                            - Let a closed root go of the scene it opened in, so an ended scene and its windows can go
#                            - Told what a root holds that it came into sight as it shows again or opens no longer hidden
#                            - Closed a popup with the root of the part it opened from and moved it as far as that root moves
#                            - Held the game's buttons with :captures => :typing only while a field inside types, and took the
#                              cancel that stops its typing as a cancel of its own
#                            - Placed the parts of a root without a shift and its pictures without making objects
#                            - Kept the opacity of a root that does not fade without working it out anew
#                            - Placed the pictures of the parts every frame without making objects for it
#                            - Measured texts from the widths of their characters where texts are built from them (UI.text_width)
#                            - Drew a root shifted from its place, as one that follows a character, on its picture rather
#                              than past it, which left a speech bubble empty
#                            - Laid a root that follows a character above the map's pictures
#                            - Laid a root inside the left or right edge of the part it lies beside, as a drawer lies
#                            - Laid a popup a part opens above every window and dialog
#                            - Moved the pictures on a viewport onto the screen before the game frees the viewport, which
#                              ended the game without a word as it opened the menu
#                            - Placed, tinted and offered the roots for the layout every frame with far fewer objects
#                            - Drew a tooltip's background and frame slightly see-through
#      Paulinchen  2026-11-04: Showed a tooltip on the side of its component that the component names
#                            - Placed a root alone at a zone of the screen, along an edge or beside a part, a game window
#                              or a place, hid it while what it lies beside does not show and closed it once that is gone
#                            - Hid a root in every scene but those of :shown_in
#                            - Told C#'s tree its mod's load order and whether it gives room in a full zone, and hid a
#                              docked root whose zone has no room left for it
#                            - Kept a root's place under the id given it, and kept the place of one that stores none only
#                              while the game runs
#                            - Drew a root on the scene's pictures above every picture, and hid it while the game shows a CG
#                            - Lined a root beside a part up with its left or top with :beside_start
#                            - Drew the tooltips at their own depth
#                            - Told C#'s tree whether a root holds the game's buttons, and closed a root C# closed by its
#                              declared hotkey with the reason :hotkey
#                            - Moved the engine's classes and modules under UI::Engine
#                            - Kept the outline of a text at the edge of a window, its contents reaching into the padding
#                            - Found whether a root lies under another that holds the game's buttons in the roots that hold
#                              them only, worked out once a frame
#                            - Drew a picture anew only where its components changed, each part on a spare picture that
#                              cuts what reaches past it
#                            - Tinted a root under the game's windows with the map's or the battle's screen tone every
#                              frame, unless its :screen_tone is false
#      Paulinchen  2026-11-01: Moved a picture whose viewport a scene freed onto the screen, and ended the fade of a root
#                              that lay on it
#                            - Left a hidden root that follows a character no room on its tile
#                            - Kept the focus in a box that scrolls at its ends when asked
#                            - Let a window leave out its own frame and background, holding framed boxes only
#                            - Drew the buttons of a root see-through while a screen held by a name holds the game's buttons
#                            - Let a root host its scene, which a box that waits for the buttons opens over
#                            - Told close with why for an open refused
#                            - Named F12 among the reasons a root closes
#                            - Followed a character at a height above its feet with :lift
#                            - Hid a root that follows while it has no character to follow
#      Paulinchen  2026-10-31: Told a root's open and why it closed, gated it by a block or the free map, closed it on a click
#                              outside, opened and closed it by a hotkey, closable unless the mod says otherwise, and faded it in
#                              and out
#                            - Hid a root in some scenes and states and showed it again with its content and place
#                            - Drew the buttons of a root under another that holds the game's buttons see-through
#                            - Docked a root at a corner of the screen, drew a floating one under the game's windows, let the
#                              pointer through one but for its parts, named an untitled one for the player's arranging, and
#                              opened one in a menu scene of its own
#                            - Let a root follow a map character, the player or a sprite above, below or on it
#                            - Scrolled a box by a page or by lines from a script, and drew a window's and a box's backdrop and plate
#                            - Shared the check of a gate with the wheels
#      Paulinchen  2026-10-30: Told a root an arrow that found nothing of it to move the focus to
#                            - Added the cover, a modal root that draws nothing, from the wheel
#      Paulinchen  2026-10-29: Told a root the game's L and R that its focused part did not use
#                            - Let a root take the place and the size of another root it hides while it is open
#                            - Let a root follow what it lies on and draw from a depth of its own
#                            - Placed the pictures of components drawn shifted and faded, cut to a Slides
#                            - Let a root ask its cancel blocks before cancel closes it
#                            - Framed a focused box that scrolls
#                            - Showed a tooltip of several lines, a tooltip box a block fills and a tooltip under
#                              the component a key focused
#                            - Let a box scroll what it holds to a place
#                            - Put a sprite surface on a viewport when asked
#                            - Put the scrolled parts on the viewport of what the root lies on
#                            - Told a root's place among its depth and whether it is modal
#                            - Let a window keep a back opacity of its own
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What every root shares: it opens and closes, takes the game's buttons while it holds them,
      # keeps the place the player gives it, closes with its scene unless it keeps, and draws the
      # pictures of the components it holds, each frame what changed. A root given another open root
      # as :over takes that root's place, and its size unless it has a size of its own, and hides that
      # root from its opening to its closing, such as a dialog that stands in for a window it would
      # show through; given a game window, it takes that window's place and size and hides it the same
      # way, such as Options > Mods over the game's options list.
      #
      # It tells open once it shows and close with why it closed (CLOSE_REASONS, or the text of its
      # :if), an open refused too, with why. Its :if is asked every frame: while it answers anything
      # but true, open is refused and an open root closes. :close_outside closes it on a left click
      # outside it, :hotkey opens and closes it by a hotkey of Hotkeys and makes it :closable unless
      # the mod gives :closable, :fade fades it in and out, telling gone once nothing of it shows.
      # :enter_motion is how it comes and :leave_motion how it goes, as it opens, closes, hides or
      # shows again: :fade, :slide (from beyond the screen's edge at its zone while it fades) or
      # :move (that slide without fading); :leave_motion is :enter_motion's unless given. Each takes
      # :motion_frames frames, one number or [in, out], Style::FADE_FRAMES by default, counted from
      # the frame it starts.
      # :hidden_in and :hide_while hide it in some scenes or states without closing it, and :shown_in
      # hides it in every scene but those. :dock gives it
      # a default place stacked in a zone of the screen (:dock_order first, then :load_order),
      # :gives_room lets it shrink to its least height before a root of a full zone hides, :anchor
      # puts it alone at a zone and :edge along an edge of the screen, taking its whole length.
      # :column ([name, x, y, gap, align] of Placement) stacks it in a named column, where it keeps
      # its place while it fades out, hidden or closed, and slides from the column's side.
      # :beside puts it beside a component, a game window, a place [x, y, width, height] or an object
      # whose current answers one of those, on :beside_side (:top, :bottom, :left, :right or :over to
      # center it on that), turning to the other side where that has no room unless :beside_flip is
      # false, centered along it unless :beside_start lines it up with its left or top; it hides while that
      # does not show and closes once that is gone. :opened_from makes it a popup of a component it
      # opened from, such as a menu: it closes once that component no longer shows and its spot, :at
      # or a place it lies beside, moves as far as that component's root moves, such as by an
      # Alt-drag. :place_key names the
      # setting its place is kept under, and :stores_place => false keeps a place only while the game
      # runs. :under_windows draws a floating one under the game's windows, above the scene's pictures
      # and the screen's tone and flash, hidden while the game shows a CG (Game.cutscene?),
      # :mouse => :parts lets the pointer through it but for its parts that take clicks or show
      # a tooltip, :place_name names it while the player arranges, and :menu opens a Window or Dialog in
      # a menu scene of its own outside one. :follow keeps it above, below or on a map character, the
      # player or a sprite, above the map's pictures and the screen's tone and flash, hidden while the character
      # does not show or :follow turns nil, shown over a CG; with :lift its side of a spot that many pixels above the character's feet,
      # whatever the sprite's height. :hosts_scene marks a capturing root as the whole screen of its
      # scene, which Capture.over_scene? leaves out. :captures holds the game's buttons while it is
      # open, and :captures => :typing only while a field inside it types, such as a chat's line; the
      # cancel that stops that typing also takes the focus off the field and asks its cancel blocks,
      # closing it unless one answers false while it is :closable. :joined marks a root that shares
      # one cursor with a game window beside it, which takes the focus only when that window hands
      # it over, never as it opens or as another root closes. While
      # another root holds the game's buttons above it, its buttons keep their look but take no click.
      #
      # Events: open, close (why), gone.
      module Root
        # The options every root takes, with their defaults.
        DEFAULTS = { :center => false, :closable => false, :keep => false, :movable => false, :resizable => false, :captures => false, :z => 1000,
                     :over => nil, :if => nil, :close_outside => false, :hotkey => nil, :fade => nil, :hidden_in => nil,
                     :shown_in => nil, :hide_while => nil, :dock => nil, :dock_order => 0, :under_windows => false, :place_name => nil, :menu => false, :follow => nil,
                     :side => nil, :follow_gap => 4, :flip => false, :on_screen => false, :hosts_scene => false, :lift => nil, :anchor => nil, :edge => nil,
                     :load_order => 0, :gives_room => false, :beside => nil, :beside_side => :right, :beside_flip => true, :beside_start => false, :place_key => nil,
                     :stores_place => true, :joined => false, :opened_from => nil, :enter_motion => :fade, :leave_motion => nil, :motion_frames => nil,
                     :column => nil }

        # How a root comes and goes: fading, sliding while it fades, or sliding alone.
        MOTIONS = [:fade, :slide, :move]

        # The pictures hide_surfaces hands place_parts, which places none while hiding.
        NO_SURFACES = [].freeze

        # The properties of C#'s tree each root option sets.
        NODE_KEYS = { :center => ["center"], :closable => ["closable"], :movable => ["movable", "layout_id"], :resizable => ["resizable", "layout_id"],
                      :z => ["z"], :id => ["layout_id", "focus_key"], :close_outside => ["close_outside"], :dock => ["dock"], :dock_order => ["dock_order"],
                      :mouse => ["mouse", "mouse_parts"], :place_name => ["layout_id"], :anchor => ["anchor"], :edge => ["edge"], :load_order => ["load_order"],
                      :gives_room => ["gives_room"], :beside_side => ["side"], :beside_flip => ["flip"], :beside_start => ["line_up"],
                      :place_key => ["layout_id"], :joined => ["joined"], :column => ["column"] }

        # The zones of the screen a root docks or lies alone at, Docks.Names in C#.
        DOCKS = [:top_left, :top, :top_right, :left, :center, :right, :bottom_left, :bottom, :bottom_right]

        # The edges of the screen a root docks along, Docks.Edges in C#.
        EDGES = [:top, :bottom, :left, :right]

        # The sides of what it lies beside a root lies on, Docks.Sides in C#.
        BESIDE_SIDES = [:top, :bottom, :left, :right, :over, :inside_left, :inside_right]

        # Frames between two looks for what a root lies beside while none is found.
        BESIDE_RETRY = 15

        # What :mouse names for a root the pointer passes through but for its parts.
        MOUSE_PARTS = :parts

        # The sides of a character a root that follows it lies on.
        SIDES = [:above, :below, :middle]

        # What a :side that is none of SIDES is named in the log.
        SIDE_WHAT = "side"

        # Room between two roots that follow one tile.
        STACK_GAP = 4

        # Why a root closes, as its close blocks hear it: the player's cancel, a click outside it, a
        # button with :closes, its hotkey, a pick of a wheel or a menu, close from a script, the
        # scene changing, and F12 starting the game's scenes again. A gate's own text is a reason too.
        CLOSE_REASONS = [:cancel, :outside, :button, :hotkey, :submit, :script, :scene, :reset]

        # The reasons C#'s tree tells with a close, by its word; a close without one is a cancel.
        PLAYER_CLOSES = { "outside" => :outside, "hotkey" => :hotkey }

        # The gate that holds while the player stands free on the map, see Game.map_free?.
        MAP_FREE = :map_free

        # Why a root that holds the game's buttons does not open while another holds them.
        BUSY_REASON = "another screen holds the game's buttons"

        # How a root resizes, by the :resizable option, as C# takes it.
        RESIZES = { true => true, false => false, nil => false, :width => "width", :height => "height" }

        # The defaults and properties a root class adds to its component's.
        module ClassMethods
          # Tells the defaults of the options, the root's added.
          #
          # @return [Hash] The defaults.
          def defaults
            super.merge(Root::DEFAULTS)
          end

          # Tells which properties of C#'s tree each option sets, the root's added.
          #
          # @return [Hash{Symbol => Array<String>}] The properties by option.
          def node_keys
            super.merge(Root::NODE_KEYS)
          end
        end

        # Makes a class including it a root.
        #
        # @param base [Class] The component class.
        def self.included(base)
          base.extend(ClassMethods)
          base.options(*DEFAULTS.keys)
        end

        # Makes the root and hands it to the hotkey that opens and closes it.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super
          @closable_given = options.key?(:closable)
          closable_by_hotkey
          Hotkeys.attach(@options[:hotkey], self) if @options[:hotkey]
        end

        # @return [Boolean] Whether it lies under another root that holds the game's buttons, as last
        #   told to C#.
        attr_reader :held_under

        # Finds the file of the mod that called the framework, for the log.
        #
        # @param lines [Array<String>] The calls, as caller lists them.
        # @return [String] The file, such as "Patch/Sample_Windows.rb".
        def self.mod_file(lines)
          own = defined?(Mod_Framework::FOLDER) ? Mod_Framework::FOLDER : "Mod_Framework"
          line = lines.find { |entry| !entry.include?(own) } || lines.first
          line.to_s.split(/:\d+/).first.to_s
        end

        # @return [Object, nil] The scene it opened in while it is open, nil once it closed or for one opened before the
        #   first scene.
        attr_reader :scene

        # @return [Integer] Its place among the open roots of its depth, from the bottom.
        attr_writer :rank

        # Opens it: it goes into C#'s tree with everything it holds and shows once C# placed it, in the
        # same frame. Refused for a component inside another and without the DLL, logged once per mod.
        #
        # @return [Component] Itself.
        def open
          return self if open?
          return refuse_open("it lies in #{@parent.describe}, and only a root opens", caller) if @parent
          return refuse_open("the framework runs without its DLL, so its windows, boxes and fields stay closed", caller) unless Mod_Framework.available?

          why = gate_reason
          return refuse_gate(why) if why
          return Scenes.open_in_menu(self) if @options[:menu] && !Scenes.menu_scene?

          Tree.stop_fading(self)
          cover
          @beside_sent = nil
          @beside_hidden = false
          @crowded = false
          @opener_at = nil
          follow_beside
          @open = true
          @told_open = false
          @hiding_fade = false
          @column_hold = false
          was_hidden = @hidden
          @hidden = hidden_now?
          @fade = fades?(nil) && !@hidden ? 0.0 : Component::OPAQUE.to_f
          @motion = nil
          @rank = 0
          @scene = defined?(::SceneManager) ? ::SceneManager.scene : nil
          @registered = register_layout
          Tree.open_root(self)
          Capture.start(self) if holds_buttons?
          came_into_sight if was_hidden && visible?
          self
        end

        # Closes it and runs its close blocks with why; the game's buttons stay away from the scene to
        # the end of the frame, so the press that closed it does nothing more. One still waiting for
        # its menu scene does not open there.
        #
        # @param why [Symbol, String] Why it closes, see CLOSE_REASONS; :script from a script.
        # @param at_once [Boolean] Whether it leaves at once, without its leave motion.
        # @return [Component] Itself.
        def close(why = :script, at_once = false)
          return not_opened(why) if Scenes.cancel_waiting(self)
          return self unless open?

          @leaves_at_once = at_once
          teardown(false)
          emit(:close, why)
          self
        end

        # Tells close for an end close did not tell, such as an open refused or F12, so a mod hears
        # every end of an open in its close blocks.
        #
        # @param why [Symbol, String] Why, see CLOSE_REASONS, or the refusal's text.
        # @return [Component] Itself.
        def not_opened(why)
          emit(:close, why) unless open?
          self
        end

        # Tells why it may not open now: its :if, or another root holding the game's buttons while
        # it would hold them itself, as its hotkey asks.
        #
        # @return [String, nil] Why, nil when it may.
        def refusal
          gate_reason || (UI.busy? ? BUSY_REASON : nil)
        end

        # Writes the hint that names what closes it: the cancel keys, then its hotkey.
        #
        # @param also [Array<String>] What else closes it, such as "a click outside".
        # @return [String] Such as "X, Numpad 0 or G: close".
        def close_hint(*also)
          label = @options[:hotkey].is_a?(Symbol) ? Hotkeys.label(@options[:hotkey]) : nil
          UI.close_hint(*(also + [label]).compact.reject { |each| each.empty? })
        end

        # Tells whether it shows, which hidden_in, shown_in and hide_while take away from it without
        # closing it.
        #
        # @return [Boolean] Whether it is visible.
        def visible?
          super && !@hidden
        end

        # Tells whether it is open.
        #
        # @return [Boolean] Whether it is.
        def open?
          @open == true
        end

        # Tells its place among the open roots of its depth, from the bottom.
        #
        # @return [Integer] The place.
        def rank
          @rank.to_i
        end

        # Tells whether the roots below it take no input while it shows.
        #
        # @return [Boolean] Whether they do not.
        def modal?
          false
        end

        # Follows what it lies on before the frame's layout: a root of its own lies on nothing.
        def follow_place
          nil
        end

        # Tells the viewport its pictures lie on: for a root drawn :under_windows the scene's top
        # viewport, under the game's windows; for one that follows a character the one
        # Game.follow_viewport picks for the character's; else the screen.
        #
        # @return [Viewport, nil] The viewport, nil for the screen.
        def surface_viewport
          return (UI.freed?(@follow_viewport) ? nil : Game.follow_viewport(@follow_viewport)) if @options[:follow]

          @options[:under_windows] ? Game.top_viewport : nil
        end

        # Takes an event of C#'s tree: a root C# closed, on cancel, closes here too, a root with
        # cancel blocks closes on cancel unless one of them answers false, the game's L or R that
        # the focused part did not use tells page, and an arrow that found nothing of the root to move
        # the focus to tells leave.
        #
        # @param name [String] The event.
        # @param values [Array] Its value, if it has one.
        def receive(name, *values)
          return closed_by_player(PLAYER_CLOSES.fetch(values[0], :cancel)) if name == "close" && root?
          return cancelled(values[0] == "outside" ? :outside : :cancel) if name == "cancel" && root?
          return emit(:page, values[0].to_i, values[1] ? true : false) if name == "page" && root?
          return emit(:leave, values[0].to_s.to_sym) if name == "leave" && root?

          super
        end

        # Runs a block on an event; a :cancel block has cancel ask the root before it closes it, and
        # a :leave block has C#'s tree tell the root an arrow that found nothing.
        #
        # @param name [Symbol] The event.
        # @yield [*values] Runs on the event.
        # @return [Component] Itself.
        def on(name, &block)
          super
          Tree.set(self, "cancel_guard" => listens?(:cancel)) if name.to_sym == :cancel
          Tree.set(self, "leave_told" => listens?(:leave)) if name.to_sym == :leave
          self
        end

        # Drops every block of an event; with the cancel blocks gone cancel closes the root at once.
        #
        # @param name [Symbol] The event.
        # @return [Component] Itself.
        def off(name)
          super
          Tree.set(self, "cancel_guard" => false) if name.to_sym == :cancel
          Tree.set(self, "leave_told" => false) if name.to_sym == :leave
          self
        end

        # Closes it quietly as F12 empties the tree: nothing goes to C#, and Tree.reset tells its close
        # blocks :reset once the tree is empty.
        def drop
          Tree.stop_fading(self)
          return unless open?

          @open = false
          Capture.stop(self)
          release_surfaces
        end

        # Follows the frame before it draws: its gate or the component it opened from closes it, its
        # hiding hides or shows it, its column keeps its place while it fades out hidden, and C#
        # learns whether it lies under another root that holds the game's buttons. Called before
        # every frame's layout for every open root.
        def watch_frame
          why = gate_reason
          return close(why) if why

          why = follow_opener
          return close(why) if why

          why = follow_beside
          return close(why) if why

          hide(hidden_now?)
          hold_column(@hidden && @told_open && fades?(true) && @fade.to_f > 0)
          held = held_under?
          return if held == @held_under

          @held_under = held
          Tree.set(self, "held_under" => held)
          @look_dirty = true
        end

        # Fades it out a frame after it closed with :fade, where it lay, and frees its pictures once it
        # is gone or the scene it lay on freed its viewport.
        #
        # @return [Boolean] Whether it still shows.
        def fade_frame
          @fade = fade_step(@fade, 0)
          @slide_shift = slide_shift
          if @fade <= 0 || @rect.nil? || (@base && @base.viewport_freed?)
            release_surfaces
            return false
          end

          place_surfaces(@fade.round, false)
          true
        end

        # Tells the properties C#'s tree lays it out by, the root's added while it is one.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          return props unless root?

          props["center"] = @options[:center] ? true : false
          props["z"] = @options[:z].to_i
          props["closable"] = @options[:closable] ? true : false
          props["movable"] = @options[:movable] ? true : false
          props["resizable"] = resize_option
          props["layout_id"] = @registered ? place_id : nil
          props["cancel_guard"] = listens?(:cancel)
          props["leave_told"] = listens?(:leave)
          props["close_outside"] = @options[:close_outside] ? true : false
          props["held_under"] = @held_under ? true : false
          props["dock"] = dock_name
          props["dock_order"] = @options[:dock_order].to_i
          props["anchor"] = zone_name(:anchor, DOCKS)
          props["edge"] = zone_name(:edge, EDGES)
          props["load_order"] = @options[:load_order].to_i
          props["gives_room"] = @options[:gives_room] ? true : false
          props["beside"] = @beside_sent
          props["side"] = zone_name(:beside_side, BESIDE_SIDES) || "right"
          props["flip"] = @options[:beside_flip] != false
          props["line_up"] = @options[:beside_start] ? "start" : "center"
          props["mouse_parts"] = @options[:mouse] == MOUSE_PARTS
          props["captures"] = captures_now?
          props["joined"] = @options[:joined] ? true : false
          props["column"] = @options[:column]
          props["column_hold"] = @column_hold ? true : false
          props
        end

        # Draws the root for the frame: shows its pictures once C# placed it, places them at its depth
        # among the roots, moves its window on and draws anew what changed. Called before every frame
        # shows.
        #
        # @param look_changed [Boolean] Whether the colors or the game's window color changed.
        def update_frame(look_changed)
          follow_target
          follow_viewport
          @fade = fade_step(@fade || Component::OPAQUE.to_f, @hidden ? 0 : Component::OPAQUE)
          @slide_shift = slide_shift
          unless @rect && (visible? || (@hidden && @fade > 0))
            hide_surfaces
            return
          end

          if @crowded
            hide_surfaces
            return
          end

          surfaces = place_surfaces(@fade.round, true)
          surfaces.each { |surface| surface.dirty = true } if look_changed || @look_dirty
          @look_dirty = false
          surfaces.each { |surface| paint(surface) if surface.needs_paint? } unless @hidden
          Layout.offer(offered_id, @rect.x, @rect.y, @rect.width, @rect.height, depth_now) if @registered && !@hidden
          tell_open
        end

        # Tells the picture it draws itself on.
        #
        # @return [#bitmap, nil] The picture, nil before it showed.
        def base_surface
          @base
        end

        # Hides it or shows it again as C#'s tree tells whether its zone has room left for it; the
        # first hide is logged.
        #
        # @param on [Boolean] Whether its zone has no room for it.
        def crowded=(on)
          on = on ? true : false
          return if on == (@crowded ? true : false)

          @crowded = on
          Tree.log_once([:crowded, place_id || describe], "#{describe} hides: its zone of the screen has no room left for it") if on
        end

        # Tells what it lies beside as C#'s tree takes it: a component's node or a place
        # [x, y, width, height].
        #
        # @param target [Object, nil] A component, a game window, a place or nil.
        # @return [Integer, Array, nil] The node or the place, nil while it does not show.
        def self.beside_value(target)
          case target
          when Array then target
          when Component then target.node && target.shown? ? target.node : nil
          else
            return nil unless defined?(::Window_Base) && target.is_a?(::Window_Base)
            return nil if target.disposed? || !target.visible || target.openness < 255

            UI.window_origin(target) + [target.width, target.height]
          end
        end

        # Tells why a root closes once what it lies beside is gone: a game window goes with its
        # scene, a component with a script.
        #
        # @param target [Object] A component or a game window.
        # @return [Symbol] :scene or :script.
        def self.gone_reason(target)
          defined?(::Window_Base) && target.is_a?(::Window_Base) ? :scene : :script
        end

        # Tells whether a scene is one of a list of scene classes or patterns of the scene class's
        # name.
        #
        # @param scene [Scene_Base] The scene.
        # @param scenes [Array, Module, Regexp, nil] The list, nil for none.
        # @return [Boolean] Whether it is.
        def self.scene_in?(scene, scenes)
          return false if scenes.nil?
          return scene_is?(scene, scenes) unless scenes.is_a?(Array)

          place = 0
          while place < scenes.size
            return true if scene_is?(scene, scenes[place])

            place += 1
          end
          false
        end

        # Tells whether a scene is a scene class or matches a pattern of the scene class's name.
        #
        # @param scene [Scene_Base] The scene.
        # @param each [Class, Regexp] The class or the pattern.
        # @return [Boolean] Whether it is.
        def self.scene_is?(scene, each)
          each.is_a?(Regexp) ? (scene.class.name.to_s =~ each ? true : false) : each.is_a?(Module) && scene.is_a?(each)
        end

        # Tells whether what a root lies beside is gone: a game window disposed or a component whose
        # root closed.
        #
        # @param target [Object] A component, a game window or a place.
        # @return [Boolean] Whether it is.
        def self.beside_gone?(target)
          return target.disposed? if defined?(::Window_Base) && target.is_a?(::Window_Base)
          return !target.root.open? if target.is_a?(Component)

          false
        end

        # Frees its pictures and those of every part it holds.
        def release_surfaces
          super
          @base.dispose if @base
          @base = nil
        end

        private

        # Tells how far its pictures are drawn from the place C# gave it: where it follows a
        # character, where it slides in or out, plus its own :offset.
        #
        # @return [Array<Integer>] Pixels right and down.
        def draw_shift
          own = offset
          follow = @follow_shift
          slide = @slide_shift
          return own unless follow || slide

          follow ||= Component::NO_OFFSET
          slide ||= Component::NO_OFFSET
          [own[0] + follow[0] + slide[0], own[1] + follow[1] + slide[1]]
        end

        # Tells how far it lies from its place as it slides in or out with :slide or :move: from
        # beyond the screen's edge by the share of its frames left as it comes, easing out, and by the
        # share gone as it goes, easing in; a fade keeps the shift it started from.
        #
        # @return [Array<Integer>, nil] Pixels right and down, nil while it does not slide.
        def slide_shift
          return nil unless @motion && @rect

          left = shift_left
          return nil if left <= 0

          way = slide_way
          room = slide_room(way)
          [(way[0] * room * left).round, (way[1] * room * left).round]
        end

        # Tells the share of its slide room it lies from its place on this frame of its motion.
        #
        # @return [Float] 0.0 at its place, 1.0 beyond the screen's edge.
        def shift_left
          way, frame, frames, held = @motion
          return held || 0.0 if motion_kind(way) == :fade

          (way == :in ? 1.0 - frame / frames.to_f : frame / frames.to_f)**2
        end

        # Tells which way it slides out: toward the side its column lines up on, the edge of the screen
        # at its zone, the bottom at the center, else toward the edge nearest it.
        #
        # @return [Array<Integer>] -1, 0 or 1 across and down.
        def slide_way
          column = @options[:column]
          return [column[4] == "right" ? 1 : -1, 0] if column && column[4] != "center"

          zone = (@options[:dock] || @options[:edge] || @options[:anchor]).to_s
          return [-1, 0] if zone.include?("left")
          return [1, 0] if zone.include?("right")
          return [0, -1] if zone == "top"
          return [0, 1] if zone == "bottom" || zone == "center"

          gaps = { [-1, 0] => @rect.x, [1, 0] => Graphics.width - @rect.x - @rect.width,
                   [0, -1] => @rect.y, [0, 1] => Graphics.height - @rect.y - @rect.height }
          gaps.min_by { |_way, gap| gap }[0]
        end

        # Tells how far it moves to leave the screen whole one way.
        #
        # @param way [Array<Integer>] The way, see slide_way.
        # @return [Integer] Pixels.
        def slide_room(way)
          return way[0] < 0 ? @rect.x + @rect.width : Graphics.width - @rect.x if way[0] != 0

          way[1] < 0 ? @rect.y + @rect.height : Graphics.height - @rect.y
        end

        # Follows the character of :follow for the frame: where it shows, it lies on its side of it,
        # turned to the other side with :flip where the screen has no room and kept whole on the
        # screen with :on_screen, above the shown roots following the same tile that opened before it;
        # where it does not show, or :follow is nil, it hides. C# learns the shift, so the pointer hits
        # it where it is drawn.
        #
        # Lost is the character alone: C# places no root that is hidden, so one that opened hidden
        # has no place until it shows, and counting that as lost would keep it hidden for good.
        def follow_target
          target = @options[:follow]
          @follows = true if target
          return unless follows?

          anchor = target ? Game.anchor_of(target) : nil
          lost = anchor.nil?
          @follow_viewport = anchor && anchor[:viewport]
          if lost != (@follow_lost ? true : false)
            @follow_lost = lost
            hide(hidden_now?)
          end
          return if lost || @rect.nil?

          x, y = follow_spot(anchor)
          dx = x - @rect.x
          dy = y - @rect.y
          return if @follow_shift && @follow_shift[0] == dx && @follow_shift[1] == dy

          @follow_shift = [dx, dy]
          Tree.set(self, "offset" => draw_shift)
        end

        # Tells where its top left corner lies beside a character's spot, by its side, its gap, the
        # roots following the same tile and the screen's room.
        #
        # @param anchor [Hash] Where the character shows, see Game.anchor_of.
        # @return [Array<Integer>] The left and the top.
        def follow_spot(anchor)
          width, height = @rect.width, @rect.height
          gap = @options[:follow_gap].to_i
          side = @options[:side] || default_side
          side = UI.choice(side, SIDES, :above, SIDE_WHAT).to_sym unless SIDES.include?(side)
          top = side_top(side, anchor, height, gap, 0)
          side = side == :above ? :below : :above if @options[:flip] && side != :middle && (top < 0 || top + height > Graphics.height)
          stacked = anchor[:tile] && visible? ? Tree.stack_follow(anchor[:tile], SIDES.index(side), height + STACK_GAP) : 0
          x = anchor[:x] - width / 2
          y = side_top(side, anchor, height, gap, stacked)
          return [x, y] unless @options[:on_screen]

          [UI.within(x, 0, [Graphics.width - width, 0].max), UI.within(y, 0, [Graphics.height - height, 0].max)]
        end

        # Tells its top on a side of a character, or of the spot :lift pixels above its feet.
        #
        # @param side [Symbol] :above, :below or :middle.
        # @param anchor [Hash] Where the character shows.
        # @param height [Integer] Its height.
        # @param gap [Integer] The pixels between it and the character.
        # @param stacked [Integer] The room the roots following the same tile before it took.
        # @return [Integer] The top.
        def side_top(side, anchor, height, gap, stacked)
          lifted = @options[:lift] && anchor[:y] - @options[:lift].to_i
          case side
          when :below then (lifted || anchor[:y] + gap) + stacked
          when :middle then (lifted || anchor[:y] - anchor[:height] / 2) - height / 2
          else (lifted || anchor[:y] - anchor[:height] - gap) - height - stacked
          end
        end

        # Tells whether it follows a character: once it was given a :follow, so it hides while that is
        # nil instead of staying where it last was.
        #
        # @return [Boolean] Whether it does.
        def follows?
          @follows ? true : false
        end

        # Tells the side it lies on of what it follows without a :side.
        #
        # @return [Symbol] :above.
        def default_side
          :above
        end

        # Makes its pictures anew on the viewport they lie on now, such as a root drawn under the
        # game's windows that a scene of another spriteset keeps.
        def follow_viewport
          viewport = surface_viewport
          viewport = nil if UI.freed?(viewport)
          return if viewport.equal?(@viewport)

          @viewport = viewport
          release_surfaces
        end

        # Tells its dock as C# names it, logging one it does not know once.
        #
        # @return [String, nil] The dock's name, nil for none.
        def dock_name
          zone_name(:dock, DOCKS)
        end

        # Tells a zone, an edge or a side of an option as C# names it, logging one it does not know
        # once.
        #
        # @param option [Symbol] The option.
        # @param names [Array<Symbol>] The names it may take, the first standing in for another.
        # @return [String, nil] The name, nil for none.
        def zone_name(option, names)
          value = @options[option]
          return nil if value.nil?

          UI.choice(value, names, names.first, option.to_s).to_s
        end

        # Follows what it lies beside for the frame: C# learns the component's node or the game
        # window's place once it changed, it hides while that does not show, and it closes once that
        # is gone.
        #
        # @return [Symbol, nil] Why it closes, nil while it stays.
        def follow_beside
          spec = @options[:beside]
          return nil if spec.nil?

          target = spec.respond_to?(:current) ? spec.current : spec
          gone = target.nil? ? spec.respond_to?(:lost?) && spec.lost? : Root.beside_gone?(target)
          return spec.respond_to?(:lost_reason) ? spec.lost_reason : Root.gone_reason(target) if gone

          value = Root.beside_value(target)
          @beside_hidden = value.nil?
          return nil if value.nil? || value == @beside_sent

          @beside_sent = value
          Tree.set(self, "beside" => value)
          nil
        end

        # Follows the component it opened from (:opened_from) for the frame: it closes once that no
        # longer shows, and otherwise moves by as far as that component's root moved since the frame
        # before.
        #
        # @return [Symbol, nil] :script once that component no longer shows, nil while it stays.
        def follow_opener
          opener = @options[:opened_from]
          return nil if opener.nil?
          return :script unless opener.shown?

          now = Popup.top_left(opener.root)
          shift(now[0] - @opener_at[0], now[1] - @opener_at[1]) if now && @opener_at && now != @opener_at
          @opener_at = now if now
          nil
        end

        # Moves its spot by pixels: :at, or the place [x, y, width, height] it lies beside.
        #
        # @param dx [Integer] The pixels to the right.
        # @param dy [Integer] The pixels down.
        def shift(dx, dy)
          spot = @options[:at]
          self.at = [spot[0] + dx, spot[1] + dy] if spot.is_a?(Array)
          place = @options[:beside]
          self.beside = [place[0] + dx, place[1] + dy, place[2], place[3]] if place.is_a?(Array)
        end

        # Places its pictures at its depth among the roots, at an opacity and its own :opacity, and
        # moves its window on.
        #
        # @param opacity [Integer] How opaque it draws, 0 to 255.
        # @param update [Boolean] Whether its window moves on by a frame.
        # @return [Array] The pictures placed.
        def place_surfaces(opacity, update)
          opacity = opacity * @options[:opacity].to_i / Component::OPAQUE unless @options[:opacity].nil?
          base = base_surface!
          depth = depth_now
          shift = draw_shift
          base.place(@rect.x, @rect.y, @rect.width, @rect.height, depth, nil, shift, opacity)
          base.show(opacity > 0)
          base.update if update
          surfaces = (@placed_surfaces ||= [])
          surfaces.clear
          surfaces << base
          place_parts(self, true, depth + 1, shifted(base.clip, shift), base.ready?, surfaces, shift, opacity)
          surfaces
        end

        # Tells the depth its pictures lie at now: its own and its place among the roots of its depth.
        #
        # @return [Integer] The depth.
        def depth_now
          depth_base + 2 * @rank.to_i
        end

        # Tells open once, the first frame it shows.
        def tell_open
          return if @told_open || @hidden

          @told_open = true
          emit(:open)
        end

        # Tells whether it fades in and out: its :fade, else as the caller says.
        #
        # @param default [Boolean, nil] Whether it fades without a :fade.
        # @return [Boolean] Whether it fades.
        def fades?(default)
          fade = @options[:fade].nil? ? default : @options[:fade]
          fade && Animations.on? ? true : false
        end

        # Moves its coming or going on a frame and tells its opacity there, at once where it does not
        # fade: hiding and showing again move unless :fade is false, opening and closing only with
        # :fade. Turning back halfway starts the other way where it shows the same (start_motion).
        #
        # @param value [Numeric] Its opacity now.
        # @param target [Integer] Where it goes: 0 or OPAQUE.
        # @return [Numeric] Its opacity on this frame.
        def fade_step(value, target)
          return value if value == target && @motion.nil?

          unless fades?(@hiding_fade ? true : nil)
            @motion = nil
            return target.to_f
          end

          way = target > 0 ? :in : :out
          start_motion(way, value) unless @motion && @motion[0] == way
          @motion[1] += 1
          way, frame, frames = @motion
          @motion = nil if frame >= frames
          motion_opacity(way, frame, frames)
        end

        # Starts its coming or going at the frame that shows what shows now; a fade keeps the shift
        # it starts from for all its frames.
        #
        # @param way [Symbol] :in or :out.
        # @param value [Numeric] Its opacity now.
        def start_motion(way, value)
          frames = frames_of(way)
          left = @motion ? shift_left : 0.0
          held = motion_kind(way) == :fade && left > 0 ? left : nil
          @motion = [way, (start_share(way, value, left) * frames).round, frames, held]
        end

        # Tells how far into its frames a coming or going starts: a slide at the shift it lies at
        # when it turns back from a slide or from a fade that holds a shift, a fade as far in as the
        # fade it turns back from, else at the opacity it has, and a move from a fade without a shift
        # at its start; at rest, by whether it shows.
        #
        # @param way [Symbol] :in or :out.
        # @param value [Numeric] Its opacity now.
        # @param left [Float] The share of its slide room it lies from its place now, see shift_left.
        # @return [Float] The share of its frames, 0.0 to 1.0.
        def start_share(way, value, left)
          shown = value > 0 ? 1.0 : 0.0
          if @motion
            kind = motion_kind(way)
            before = motion_kind(@motion[0])
            if kind != :fade && (before != :fade || left > 0)
              shown = 1.0 - Math.sqrt(left)
            elsif kind == :move
              return 0.0
            elsif kind == before
              done = @motion[1] / @motion[2].to_f
              shown = @motion[0] == :in ? done : 1.0 - done
            else
              shown = value / Component::OPAQUE.to_f
            end
          end
          way == :in ? shown : 1.0 - shown
        end

        # Tells the frames its coming or going takes.
        #
        # @param way [Symbol] :in or :out.
        # @return [Integer] The frames, at least one.
        def frames_of(way)
          given = @options[:motion_frames]
          frames = given.is_a?(Array) ? given[way == :in ? 0 : 1] : given
          frames.is_a?(Integer) && frames > 0 ? frames : Style::FADE_FRAMES
        end

        # Tells how it comes or goes: :fade, :slide or :move.
        #
        # @param way [Symbol] :in or :out.
        # @return [Symbol] The motion.
        def motion_kind(way)
          kind = way == :out && !@options[:leave_motion].nil? ? @options[:leave_motion] : @options[:enter_motion]
          MOTIONS.include?(kind) ? kind : :fade
        end

        # Tells its opacity at a frame of its coming or going: counted up from 0 as it comes and down
        # from OPAQUE in whole steps as it goes, or whole all along with :move until it is gone.
        #
        # @param way [Symbol] :in or :out.
        # @param frame [Integer] The frame, from 1.
        # @param frames [Integer] The frames it takes.
        # @return [Integer] The opacity.
        def motion_opacity(way, frame, frames)
          opaque = Component::OPAQUE
          return way == :out && frame >= frames ? 0 : opaque if motion_kind(way) == :move

          way == :in ? (opaque * frame / frames.to_f).round : opaque - opaque * frame / frames
        end

        # Tells why its :if keeps it from showing now.
        #
        # @return [String, nil] The gate's answer as a reason, nil while it lets it show.
        def gate_reason
          Root.gate_reason_of(self, @options[:if])
        end

        # Tells why a gate keeps a component from showing now, for a root and for a Wheel.
        #
        # @param component [Component] The component, which logs a failing gate.
        # @param gate [Proc, Symbol, nil] Its :if: a block, MAP_FREE or nil for none.
        # @return [String, nil] The gate's answer as a reason, nil while it lets it show.
        def self.gate_reason_of(component, gate)
          return nil if gate.nil?

          answer = gate == MAP_FREE ? Game.map_free_reason || true : gate.call
          answer == true ? nil : (answer.nil? || answer == false ? "its :if answered #{answer.inspect}" : answer.to_s)
        rescue => e
          if Logging.first_time?(Tree, [:gate, component.class, e.class])
            component.mod_log("the :if of #{component.describe} failed, so it does not show: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          end
          "its :if failed"
        end

        # Logs an open its gate refused and tells close with the gate's answer.
        #
        # @param why [String] Why.
        # @return [Component] Itself.
        def refuse_gate(why)
          Tree.log("#{describe} did not open: #{why}")
          not_opened(why)
        end

        # Tells whether it hides now: what it lies beside does not show, it lies above the scene's
        # pictures while the game shows a CG, its scene is one of :hidden_in or none of :shown_in
        # (classes, or patterns of the scene class's name) or its :hide_while answers true.
        #
        # @return [Boolean] Whether it does.
        def hidden_now?
          return true if @follow_lost || @beside_hidden
          return true if @options[:under_windows] && !@options[:follow] && Game.cutscene?

          scene = Game.current_scene
          return true if scene && Root.scene_in?(scene, @options[:hidden_in])
          return true if scene && @options[:shown_in] && !Root.scene_in?(scene, @options[:shown_in])

          @options[:hide_while] ? (@options[:hide_while].call ? true : false) : false
        rescue => e
          mod_log("the :hide_while of #{describe} failed, so it shows: #{Logging.failure(e)}") if Logging.first_time?(Tree, [:hide_while, self.class, e.class])
          false
        end

        # Hides it or shows it again with what it holds and where it lies: hidden, it fades out, takes
        # neither the pointer nor the keys and frees its dock room; shown again, it fades back in.
        #
        # @param on [Boolean] Whether it hides.
        def hide(on)
          return if on == (@hidden ? true : false)

          @hidden = on
          @hiding_fade = true
          Tree.roots_changed
          Tree.set(self, "visible" => visible?)
          came_into_sight if !on && visible?
          holds_buttons? ? Capture.start(self) : Capture.stop(self)
          Tree.log("#{describe} #{on ? 'hides' : 'shows again'}")
        end

        # Has its column keep its place while it fades out, or close up once it is gone; without a
        # column it keeps none.
        #
        # @param on [Boolean] Whether it keeps its place.
        def hold_column(on)
          on = on && @options[:column] ? true : false
          return if on == (@column_hold ? true : false)

          @column_hold = on
          Tree.set(self, "column_hold" => on)
        end

        # Tells whether it lies under another screen that holds the game's buttons: a capturing window,
        # a dialog, a wheel or the question box above it, or one holding them while it holds none, such
        # as a screen a mod draws without the components.
        #
        # @return [Boolean] Whether it does.
        def held_under?
          return false unless visible?
          return true if Confirm.open? && !Confirm.box?(self)
          return true if !holds_buttons? && !Confirm.box?(self) && Capture.held_by_name?

          mine = holds_buttons?
          depth = z.to_i
          holders = Tree.holders
          place = 0
          while place < holders.size
            other = holders[place]
            place += 1
            return true if !other.equal?(self) && (!mine || other.z.to_i > depth || (other.z.to_i == depth && other.rank > rank))
          end
          false
        end

        # Tells the depth its pictures start from, before its place among the roots of its depth: on
        # a viewport it lies above every picture, keeping the order of its band.
        #
        # @return [Integer] The depth.
        def depth_base
          band = lifted_band
          lift = band ? PICTURES_TOP + 1 - BANDS[band].first : 0
          @options[:z].to_i + lift
        end

        # Tells the band whose depths it lifts above the pictures of the viewport it lies on: the HUD
        # band on the scene's top viewport under the game's windows, the map band on a character's
        # own viewport. Following a character on the scene's top viewport it keeps the map band's
        # depths, which lie under a wheel that follows and the HUD band's roots there.
        #
        # @return [Symbol, nil] :hud, :map or nil for none.
        def lifted_band
          return nil unless @viewport
          return (@options[:under_windows] ? :hud : nil) unless @options[:follow]

          @viewport.equal?(Game.top_viewport) ? nil : :map
        end

        # Makes its picture as it first shows.
        #
        # @return [#bitmap] The picture.
        def base_surface!
          @base ||= make_base
        end

        # Makes its picture: a sprite of its own, on the viewport it lies on.
        #
        # @return [SpriteSurface] The picture.
        def make_base
          SpriteSurface.new(nil, surface_viewport)
        end

        # Hides its pictures, which it keeps.
        def hide_surfaces
          @base.show(false) if @base
          place_parts(self, false, 0, nil, false, NO_SURFACES)
        end

        # Places the pictures of the components on pictures of their own and of the parts they scroll,
        # each shifted and faded with the components it lies in and cut to the picture it lies on, or
        # hides them. Each is made after the one it lies on, which keeps it above it.
        #
        # @param component [Component] The component.
        # @param shown [Boolean] Whether it shows.
        # @param depth [Integer] The pictures' depth.
        # @param clip [Rect, nil] What may show of them.
        # @param ready [Boolean] Whether the root shows whole, so its parts may show.
        # @param surfaces [Array] Where the placed pictures go.
        # @param shift [Array<Integer>] How far the components it lies in are drawn from their places.
        # @param opacity [Integer] How opaque they are drawn.
        def place_parts(component, shown, depth, clip, ready, surfaces, shift = Component::NO_OFFSET, opacity = Component::OPAQUE)
          if component.layered? && !component.equal?(self)
            offset = component.offset
            shift = component.shift_within(shift, offset) unless offset.equal?(Component::NO_OFFSET)
            opacity = opacity * component.opacity / Component::OPAQUE
            clip = place_part(component.layer_surface!, component.rect, shown, depth, clip, ready, surfaces, shift, opacity) if shown && component.rect
            component.layer_surface.show(false) if component.layer_surface && !(shown && component.rect)
          end
          if component.scrolls_part?
            if shown && component.rect
              clip = place_part(component.inner_surface!, component.inner_region, shown, depth, clip, ready, surfaces, shift, opacity)
            elsif component.inner_surface
              component.inner_surface.show(false)
            end
          end
          clip = UI.overlap(clip, shifted(component.rect, shift)) if clip && component.clips? && component.rect
          component.children.each { |child| place_parts(child, shown && child.visible?, depth, clip, ready, surfaces, shift, opacity) }
        end

        # Places one picture of a part and shows it once the root shows whole and it is not unseen.
        #
        # @param surface [SpriteSurface] The picture.
        # @param region [Rect] Where its part is laid out on the screen.
        # @param shown [Boolean] Whether it shows.
        # @param depth [Integer] Its depth.
        # @param clip [Rect, nil] What may show of it.
        # @param ready [Boolean] Whether the root shows whole.
        # @param surfaces [Array] Where the placed pictures go.
        # @param shift [Array<Integer>] How far it is drawn from its place.
        # @param opacity [Integer] How opaque it is drawn.
        # @return [Rect, nil] What may show of the parts it holds.
        def place_part(surface, region, shown, depth, clip, ready, surfaces, shift, opacity)
          surface.place(region.x, region.y, region.width, region.height, depth, clip, shift, opacity)
          surface.show(shown && ready && opacity > 0)
          surfaces << surface
          clip && UI.overlap(clip, shifted(region, shift))
        end

        # Tells where a rectangle is drawn when shifted.
        #
        # @param rect [Rect] The rectangle.
        # @param shift [Array<Integer>] The shift.
        # @return [Rect] The rectangle drawn.
        def shifted(rect, shift)
          return rect if shift[0] == 0 && shift[1] == 0

          Rect.new(rect.x + shift[0], rect.y + shift[1], rect.width, rect.height)
        end

        # Draws one picture anew, all of it or only the parts where components changed: every shown
        # component that lies on it, each before the ones it holds, and the scrollbar of the part it
        # is. A picture whose components are not all placed yet keeps what it shows, so a box emptied
        # and filled again never shows empty.
        #
        # @param surface [#bitmap] The picture.
        def paint(surface)
          return unless placed_on?(self, surface)

          spots = surface.spots
          if spots
            spots.each { |spot| paint_spot(surface, spot) }
          else
            surface.bitmap.clear
            paint_area(surface, surface, nil)
          end
          surface.dirty = false
        end

        # Draws one part of a picture anew: the components that reach into it draw on the spare
        # picture, which then takes the part's place.
        #
        # @param surface [#bitmap] The picture.
        # @param spot [Rect] The part on the picture.
        def paint_spot(surface, spot)
          picture = surface.bitmap
          spot = UI.overlap(spot, picture.rect)
          return if spot.width <= 0 || spot.height <= 0

          scratch = Scratch.bitmap(spot.width, spot.height)
          area = ClipSurface.new(scratch, surface.x + spot.x, surface.y + spot.y)
          paint_area(surface, area, Rect.new(area.x, area.y, spot.width, spot.height))
          picture.clear_rect(spot)
          picture.blt(spot.x, spot.y, scratch, Rect.new(0, 0, spot.width, spot.height))
        end

        # Draws the components of a picture that reach into an area, and the scrollbar of the part it
        # is.
        #
        # @param surface [#bitmap] The picture the components lie on.
        # @param target [#bitmap, #x, #y] Where they draw: the picture, or the spare picture of a part.
        # @param area [Rect, nil] The part of the screen drawn, nil for all of the picture.
        def paint_area(surface, target, area)
          paint_component(self, surface, target, area)
          owner = surface.respond_to?(:owner) ? surface.owner : nil
          owner.draw_part(Canvas.new(owner, target)) if owner && owner.rect && reaches?(owner.rect, area)
        end

        # Draws a component that lies on a picture and those it holds that do, where they reach into
        # an area; one laid out without room draws nothing, nor do those it holds. What the root holds
        # on its own picture draws only inside the root's content, a badge over a part's corner
        # besides.
        #
        # A column that keeps its newest parts leaves the parts above them without room, which drew
        # their texts over the parts below otherwise; a part laid out past the content, such as a
        # line more than the window holds, drew over the window's frame.
        #
        # @param component [Component] The component.
        # @param surface [#bitmap] The picture the components lie on.
        # @param target [#bitmap, #x, #y] Where they draw.
        # @param area [Rect, nil] The part of the screen drawn, nil for all of the picture.
        # @param box [Rect, nil] The place on the screen it draws inside, nil for anywhere.
        def paint_component(component, surface, target, area, box = nil)
          return unless component.visible?

          place = component.rect
          return if place && (place.width <= 0 || place.height <= 0)

          box = nil if component.is_a?(BadgeMark)
          if place && component.surface.equal?(surface) && reaches?(place, area)
            begin
              box && !inside?(place, box) ? draw_clipped(component, target, box) : component.draw_whole(Canvas.new(component, target))
            rescue => e
              component.mod_log("drawing #{component.describe} failed: #{Logging.failure(e)} at #{Array(e.backtrace).first}") if Logging.first_time?(Tree, [:paint, component.class, e.class])
            end
          end
          box = content_rect if component.equal?(self) && surface.equal?(@base)
          component.children.each { |child| paint_component(child, surface, target, area, box) }
        end

        # Tells whether a place lies whole inside a box.
        #
        # @param place [Rect] The place.
        # @param box [Rect] The box.
        # @return [Boolean] Whether it does.
        def inside?(place, box)
          place.x >= box.x && place.y >= box.y && place.x + place.width <= box.x + box.width && place.y + place.height <= box.y + box.height
        end

        # Draws a component only where it lies inside a box: on a spare picture of that part, which is
        # then copied where it lies.
        #
        # @param component [Component] The component.
        # @param target [#bitmap, #x, #y] Where it draws.
        # @param box [Rect] The place on the screen it draws inside.
        def draw_clipped(component, target, box)
          shown = UI.overlap(component.rect, box)
          return if shown.width <= 0 || shown.height <= 0

          spare = Scratch.bitmap(shown.width, shown.height, Scratch::CLIP)
          component.draw_whole(Canvas.new(component, ClipSurface.new(spare, shown.x, shown.y)))
          target.bitmap.blt(shown.x - target.x, shown.y - target.y, spare, Rect.new(0, 0, shown.width, shown.height))
        end

        # Tells whether a place reaches into an area, with the room an outline may reach past it.
        #
        # @param rect [Rect] The place.
        # @param area [Rect, nil] The area, nil for everywhere.
        # @return [Boolean] Whether it does.
        def reaches?(rect, area)
          return true unless area

          room = Spots::MARGIN
          rect.x - room < area.x + area.width && area.x < rect.x + rect.width + room &&
            rect.y - room < area.y + area.height && area.y < rect.y + rect.height + room
        end

        # Tells whether every shown component that lies on a picture has its place; those inside a
        # component laid out without room need none, since they draw nothing.
        #
        # C# lays out nothing inside a compact form it does not show, so those parts never get a
        # place, and waiting for them kept the whole picture empty.
        #
        # @param component [Component] The component the search starts at.
        # @param surface [#bitmap] The picture.
        # @return [Boolean] Whether every one has.
        def placed_on?(component, surface)
          return true unless component.visible?

          place = component.rect
          return true if place && (place.width <= 0 || place.height <= 0)
          return false if place.nil? && component.surface.equal?(surface)

          component.children.all? { |child| placed_on?(child, surface) }
        end

        public

        # Tells whether it holds the game's buttons: while it is visible and captures them.
        #
        # @return [Boolean] Whether it does.
        def holds_buttons?
          captures_now? && visible?
        end

        # Tells whether it captures the game's buttons now: with :captures, and with :captures =>
        # :typing while a field inside it types.
        #
        # @return [Boolean] Whether it does.
        def captures_now?
          return @options[:captures] ? true : false unless @options[:captures] == :typing

          field = TextField.typing
          field && field.root.equal?(self) ? true : false
        end

        # Follows a field inside it that starts or stops typing: with :captures => :typing it takes the
        # game's buttons, or gives them back.
        def typing_changed
          return unless @options[:captures] == :typing && open?

          Tree.roots_changed
          Tree.set(self, "captures" => captures_now?)
          holds_buttons? ? Capture.start(self) : Capture.stop(self)
        end

        # Follows a field inside it whose typing a cancel stopped: with :captures => :typing the field
        # lets go of the focus, so no part of it takes the keys the game has again, and the cancel
        # asks its cancel blocks, then closes it while it is :closable, unless one answered false.
        #
        # @param field [TextField] The field.
        def typing_cancelled(field)
          return unless @options[:captures] == :typing && open?

          field.blur
          close(:cancel) if ask(:cancel) && @options[:closable]
        end

        # Tells whether it is the whole screen of its scene (:hosts_scene).
        #
        # @return [Boolean] Whether it is.
        def hosts_scene?
          @options[:hosts_scene] ? true : false
        end

        # Follows a changed option: being shown or capturing decides whether it holds the buttons.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          Tree.roots_changed
          Tree.set(self, "captures" => captures_now?) if name == :captures && root?
          @closable_given = true if name == :closable
          closable_by_hotkey if name == :hotkey
          return unless open?

          holds_buttons? ? Capture.start(self) : Capture.stop(self) if name == :visible || name == :captures
          rearrange if [:movable, :resizable, :id, :title].include?(name)
          Hotkeys.attach(@options[:hotkey], self) if name == :hotkey && @options[:hotkey]
        end
        private :changed

        # Makes a root a hotkey opens closable unless the mod gave :closable, so the game's cancel key
        # closes it as it closes the game's own screens instead of reaching the map.
        def closable_by_hotkey
          return if @closable_given || !@options[:hotkey] || @options[:closable]

          @options[:closable] = true
          Tree.set(self, "closable" => true) if open?
        end
        private :closable_by_hotkey

        # Makes it arrangeable anew after what decides that changed while it is open: whether it moves
        # or resizes, and the id its place is kept under.
        def rearrange
          @registered = register_layout
          Tree.set(self, "layout_id" => @registered ? place_id : nil)
        end

        private

        # Closes it on cancel unless a cancel block answers false, with the cancel sound; a root of
        # the UI layer plays it only as it closes, leaving the sound of a refusal to its cancel block,
        # such as the buzzer while something runs or the question it asks. A root joined to a game
        # window plays none, since cancel does there what it does in that window, whose own cancel
        # plays it.
        #
        # @param why [Symbol] :cancel, or :outside for a click outside it.
        def cancelled(why = :cancel)
          return unless open?

          sound = !@options[:joined]
          Sound.play_cancel if sound && !@options[:layer]
          return unless ask(:cancel)

          Sound.play_cancel if sound && @options[:layer]
          close(why)
        end

        # Closes it as C# closed it on cancel, which removed it from C#'s tree already.
        #
        # @param why [Symbol] :cancel, :outside for a click outside it, or :hotkey for the hotkey the UI
        #   layer declared on it.
        def closed_by_player(why = :cancel)
          return unless open?

          teardown(true)
          emit(:close, why)
        end

        # Takes the place and the size of its :over, while that root is open and placed, and hides
        # that root until it closes.
        def cover
          over = @options[:over]
          @covered = nil
          return cover_game_window(over) if defined?(::Window_Base) && over.is_a?(::Window_Base)
          return unless over.is_a?(Component) && over.open? && !over.equal?(self)

          @own_size = !(@options[:size].nil? && @options[:width].nil? && @options[:height].nil?) if @own_size.nil?
          if over.rect
            @options[:center] = false
            @options[:at] = [over.rect.x, over.rect.y]
            @options[:size] = [over.rect.width, over.rect.height] unless @own_size
          end
          @covered = over if over.visible?
          over.visible = false
        end

        # Takes the place and the size of a game window and hides it until it closes, the game's own
        # scripts still reading the window as shown.
        #
        # @param window [Window_Base] The game window.
        def cover_game_window(window)
          return if window.disposed?

          @options[:center] = false
          @options[:at] = UI.window_origin(window)
          @options[:size] = [window.width, window.height]
          GameWindows::Hidden.install(window.class)
          GameWindows::Hidden.follow(window, :covered, true)
          @covered = window
        end

        # Shows the root or the game window it hid as it opened again, while that one is still there.
        def uncover
          over = @covered
          @covered = nil
          return GameWindows::Hidden.follow(over, :covered, false) if defined?(::Window_Base) && over.is_a?(::Window_Base) && !over.disposed?

          over.visible = true if over && over.open?
        end

        # Takes it out of the tree, gives the buttons back, shows the root it hid and frees its
        # pictures, after its leave motion unless close told it to leave at once; its column keeps
        # its place until that motion ends.
        #
        # @param removed [Boolean] Whether C# removed it already.
        def teardown(removed)
          at_once = @leaves_at_once
          @leaves_at_once = false
          leaving = !at_once && fades?(nil) && @rect && @base && !@hidden
          Scenes.root_closed(self) if @options[:menu]
          uncover
          @open = false
          @scene = nil
          @column_hold = leaving && @options[:column] ? true : false
          Tree.close_root(self, removed, @column_hold)
          Capture.stop(self)
          Capture.hold_to_frame_end
          @hiding_fade = false
          if leaving
            Tree.fade_out(self)
          else
            release_surfaces
            Tree.gone(self)
          end
        end

        # Logs an open refused, once per mod and reason, and tells close with why.
        #
        # @param why [String] Why.
        # @param lines [Array<String>] The calls that led here.
        # @return [Component] Itself.
        def refuse_open(why, lines)
          mod = Root.mod_file(lines)
          Tree.log_once([:refused_open, mod, why], "#{mod} opened #{describe}, refused: #{why}")
          not_opened(why)
        end

        # Makes it arrangeable by the player when it moves or resizes and has an id, from its title
        # if it names none.
        #
        # @return [Boolean] Whether it is.
        def register_layout
          return false unless @options[:movable] || resize_option != false

          id = place_id
          unless id && !Layout::RESERVED.include?(id.to_sym)
            Tree.log_once([:place_id, describe], "#{describe} does not move or resize: it needs an id or a title, and not one of #{Layout::RESERVED.join(', ')}")
            return false
          end

          Layout.register(id, layout_name, :min_size => UI.size(least_size), :max_size => UI.size(@options[:max_size]),
                                           :resizable => RESIZES.key(resize_option), :movable => @options[:movable] ? true : false,
                                           :stores => @options[:stores_place] != false)
          true
        end

        # Tells the id its place is kept under: its id, else its title in lower case words joined by
        # underscores.
        #
        # @return [String, nil] The id, nil for none.
        def place_id
          return @options[:place_key].to_s if @options[:place_key]

          id = @options[:id]
          id = @options[:title].to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "") if id.nil?
          id.to_s.empty? ? nil : id.to_s
        end

        # Tells its place id as a Symbol for the layout's offers, every frame, worked out anew only
        # once what it comes from changed.
        #
        # @return [Symbol, nil] The id, nil for none.
        def offered_id
          from = @options[:place_key] || @options[:id] || @options[:title]
          return @offered_id if from.equal?(@offered_from) && @offered_from

          @offered_from = from
          id = place_id
          @offered_id = id && id.to_sym
        end

        # Names it for the outlines the player arranges by and for Interface Positions.
        #
        # @return [String] Its :place_name, else its title, else its kind and id.
        def layout_name
          return @options[:place_name].to_s unless @options[:place_name].to_s.empty?

          title = @options[:title].to_s
          title.empty? ? describe : title
        end

        # Tells its least size, which a drag keeps it above.
        #
        # @return [Array, nil] Its width and height.
        def least_size
          @options[:min_size]
        end

        # Reads how it resizes as C# takes it, logging another value once.
        #
        # @return [Boolean, String] true, false, "width" or "height".
        def resize_option
          value = @options[:resizable]
          return RESIZES[value] if RESIZES.key?(value)

          Tree.log_once([:resizable, value], "#{value.inspect} is no way to resize, so #{describe} does not resize (true, false, :width or :height)")
          false
        end

        # Draws its title row: its icon or its icon file, then its title cut to the room left.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The row's left in the root.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        def draw_title(canvas, x, y, width)
          left = x
          if @options[:icon]
            canvas.icon(@options[:icon], x, y)
            left += ICON_STEP
          elsif @options[:icon_file]
            picture = UI.picture(@options[:icon_file])
            canvas.picture(picture, x, y, ICON_SIZE, ICON_SIZE) if picture
            left += ICON_STEP
          end
          title = @options[:title].to_s
          canvas.text(left, y, x + width - left, ICON_SIZE, title, :color => :title, :size => :large, :cut => true) unless title.empty?
        end

        # Tells whether it has a title row.
        #
        # @return [Boolean] Whether it has a title, an icon or an icon file.
        def titled?
          !@options[:title].to_s.empty? || !@options[:icon].nil? || !@options[:icon_file].nil?
        end

        # Tells the room its title row takes above what it holds.
        #
        # @return [Integer] The pixels, 0 without a title row.
        def title_room
          titled? ? ICON_SIZE + Style::GAP : 0
        end
      end
    end
  end
end
