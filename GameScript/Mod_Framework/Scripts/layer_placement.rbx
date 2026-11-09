#----------------------------------------------------------------
#  layer_placement.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Moved the shown huds of a column defined anew, and let a hud refused for an unknown column join once it is defined
#                            - Added UI.column, a named column of huds stacked down from a spot, and put a hud in the column it names
#                            - Placed a root at the spot its live at: answers now
#      Paulinchen  2026-11-06: Kept a root that opens from a part at the depth it opened at, under the popups opened from it
#                            - Closed and moved a popover at the pointer with the part it lies in
#                            - Put a root that opens from a part, such as a menu of UI.menu, in the popups' band
#                            - Put a window in the layer :hud or :over in that layer's band
#      Paulinchen  2026-11-05: Put a hud in the notices' layer in the notices' band
#                            - Put a window or a dialog with cover: a game window exactly over that window, which it hides
#                            - Put a hud that follows a map character in the map's band, outside every zone
#                            - Put a dialog with cover: in the place of the window that opened it, which it hides
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Where the roots of the new UI layer go: it turns a root's placement params into what the
      # engine's root hands C#'s tree, which works the places out (Docks in C#): the zone, edge,
      # spot or part it sits at, the band of depths of its layer, its mod's load order and the
      # setting its place is kept under. It also finds what a root lies beside, opens and closes
      # popovers and keeps the columns of huds that mods define.
      module Placement
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "UI"

        # How the huds of a column line up with its spot across, Docks.ColumnAligns in C#.
        COLUMN_ALIGNS = [:left, :center, :right]

        # The pixels between two huds of a column whose UI.column gives no gap:, as between two parts of a zone.
        COLUMN_GAP = 4

        # The params UI.column takes besides the column's name.
        COLUMN_PARAMS = [:at, :gap, :align]

        # The columns of huds the mods defined, by name: [name, x, y, gap, align] as C#'s tree takes it.
        @columns = {}

        # The roots this module places, by their markup names.
        ROOTS = [:window, :dialog, :hud, :popover]

        # Each root's band of depths of BANDS and where in it a root with z: 0 lies.
        BAND = { :window => [:windows, 0], :dialog => [:dialogs, 0], :popover => [:dialogs, 0], :hud => [:hud, 10], :over => [:over, 0], :notices => [:notices, 0],
                 :map => [:map, 0] }

        # What names a game window: its class name.
        GAME_WINDOW = /\AWindow_\w+\z/

        # Finds what a root lies beside each frame: once found, the same part or game window until it
        # is gone; before that, a look every Root::BESIDE_RETRY frames.
        class Target
          # Makes the finder of a selector.
          #
          # @param text [String] The selector or the game window's class name.
          def initialize(text)
            @text = text
            @target = nil
            @found = false
            @looked = nil
          end

          # @return [String] The selector.
          attr_reader :text

          # Tells what the root lies beside now.
          #
          # @return [Object, nil] An engine part or a game window, nil for none.
          def current
            if @target && Root.beside_gone?(@target)
              @lost_reason = Root.gone_reason(@target)
              @target = nil
            end
            return @target if @target || (@found && @lost_reason)

            frame = Key.frame
            return nil if @looked && frame - @looked < Root::BESIDE_RETRY

            @looked = frame
            @target = Placement.find(@text)
            @found ||= !@target.nil?
            @target
          end

          # Tells whether what it found once is gone.
          #
          # @return [Boolean] Whether it is.
          def lost?
            @found && @target.nil? ? true : false
          end

          # Tells why the root closes once what it lay beside is gone.
          #
          # @return [Symbol] :scene for a game window, :script for a part.
          def lost_reason
            @lost_reason || :script
          end
        end

        # Adds what places a root to the engine options its params give.
        #
        # @param part [Layer::Part] The root's part.
        # @param options [Hash] The engine options.
        # @param params [Hash] Its params with their live values read, such as a live at:.
        # @return [Hash] The options with the place.
        def self.apply(part, options, params = part.node.params)
          type = part.node.type
          return options unless ROOTS.include?(type)

          z = if !params[:opened_from] then depth(type, params)
              elsif part.engine then part.engine.z
              else Popup.depth(params[:opened_from])
              end
          placed = { :center => false, :z => z, :load_order => load_order(Layer.mod_of(part)) }
          placed.update(type == :popover ? popover_place(part) : spot(part, params))
          placed.update(storage(part, params)) unless type == :popover
          options.merge(placed)
        end

        # Tells a root's depth: z: within the band of its layer, the map's for a hud that follows a
        # character, that of :over or :notices for a hud in one and that of :hud or :over for a window
        # in one.
        #
        # @param type [Symbol] The root's markup name.
        # @param params [Hash] Its params.
        # @return [Integer] The depth.
        def self.depth(type, params)
          layer = if type == :hud && params[:follow] then :map
                  elsif type == :hud && [:over, :notices].include?(params[:layer]) then params[:layer]
                  elsif type == :window && [:hud, :over].include?(params[:layer]) then params[:layer]
                  else type
                  end
          band, start = BAND[layer]
          range = BANDS[band]
          UI.within(range.first + start + params[:z].to_i, range.first, range.last)
        end

        # Tells a mod's place in the load order: the managed mods in the order they loaded, every
        # other mod after them.
        #
        # @param mod [String] The mod, such as "Camp Notes".
        # @return [Integer] The place.
        def self.load_order(mod)
          loaded = defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:loaded) ? Array(Mod_Framework::Mods.loaded) : []
          key = plain(mod)
          index = loaded.index { |name| plain(name) == key }
          index || loaded.size
        end

        # Tells where a window, a dialog or a hud sits by default: beside the character it follows (a
        # hud, which the engine moves there from the screen's corner each frame), in the column it
        # names (a hud, which neither the player nor its own place moves), along an edge,
        # beside a part, at a spot, stacked in a zone (a hud), exactly over a game window, which it
        # hides (cover: a game window or its class name), in the place of the window that opened it,
        # which it hides (cover: true), over that window (a dialog without a zone) or alone at a zone.
        #
        # @param part [Layer::Part] The root's part.
        # @param params [Hash] Its params.
        # @return [Hash] The engine options.
        def self.spot(part, params)
          return { :at => [0, 0] } if part.node.type == :hud && params[:follow]

          column = part.node.type == :hud && params[:column] ? column_place(part, params[:column]) : nil
          return { :column => column, :movable => false, :resizable => false } if column
          return { :edge => params[:dock] } if params[:dock]

          covered = covered_window(params[:cover])
          return { :over => covered } if covered
          return { :beside => beside(part, params[:beside]), :beside_side => params[:side] || :right } if params[:beside]
          return { :at => params[:at] } if params[:at]
          return { :dock => params[:anchor] || :top_left, :dock_order => params[:order].to_i } if part.node.type == :hud

          opener = part.top && part.top.opener
          return { :over => opener } if params[:cover] == true && opener
          return { :beside => opener, :beside_side => :over } if part.node.type == :dialog && params[:anchor].nil? && opener

          { :anchor => params[:anchor] || :center }
        end

        # Finds the game window a cover: names: the window itself, or the window of the scene of that
        # class name.
        #
        # @param cover [Object] The cover: param.
        # @return [Window_Base, nil] The window, nil for none or for cover: true and false.
        def self.covered_window(cover)
          return game_window(cover) if cover.is_a?(String)

          defined?(::Window_Base) && cover.is_a?(::Window_Base) && !cover.disposed? ? cover : nil
        end

        # Tells where a popover sits: beside its target, or beside the pointer as it opened, lined up
        # with its left or top as MudPopover lines up.
        #
        # @param part [Layer::Part] The popover's part.
        # @return [Hash] The engine options.
        def self.popover_place(part)
          target = part.node.params[:target]
          return { :beside => part.beside, :beside_start => true } if target == :pointer && part.beside.is_a?(Array)
          return { :beside => pointer_spot, :beside_start => true } if target == :pointer

          { :beside => beside(part, target), :beside_start => true }
        end

        # Tells the setting a root's place is kept under: its mod and id, or for a root without an id
        # its mod and its component's class.
        #
        # @param part [Layer::Part] The root's part.
        # @param params [Hash] Its params.
        # @return [Hash] The engine options.
        def self.storage(part, params)
          mod = Layer.mod_of(part)
          id = params[:id]
          return { :place_key => Layout.place_key(mod, id), :stores_place => true } if id

          owner = part.top ? part.top.mount.component.class.name : part.node.owner.class.name
          { :place_key => Layout.place_key(mod, owner), :stores_place => true }
        end

        # Hands out a root's finder of what it lies beside, the same while the selector stays.
        #
        # @param part [Layer::Part] The root's part.
        # @param text [String] The selector.
        # @return [Target] The finder.
        def self.beside(part, text)
          part.beside = Target.new(text.to_s) unless part.beside.is_a?(Target) && part.beside.text == text.to_s
          part.beside
        end

        # Finds what a selector names: a game window of the scene by its class name, a part of the
        # layer, or a root of the old names by its id.
        #
        # @param text [String] The selector.
        # @return [Object, nil] The game window or the engine part, nil for none.
        def self.find(text)
          return game_window(text) if text =~ GAME_WINDOW

          item = Selector.find(Selector.parse(text)).first
          engine = item && Layer.engine_of(item)
          return engine if engine

          id = text[/\A#(\w+)\z/, 1]
          id && Tree.roots.find { |root| root.id.to_s == id && root.open? }
        rescue MarkupError => e
          log_once([:beside, text], "beside #{text.inspect} names no part: #{e.message}")
          nil
        end

        # Finds a game window of the scene by its class name.
        #
        # @param name [String] The class name, such as "Window_TitleCommand".
        # @return [Window_Base, nil] The window, nil for none.
        def self.game_window(name)
          scene = defined?(::SceneManager) ? ::SceneManager.scene : nil
          return nil unless scene && defined?(::Window_Base)

          klass = Object.const_defined?(name) ? Object.const_get(name) : nil
          scene.instance_variables.each do |ivar|
            window = scene.instance_variable_get(ivar)
            next unless window.is_a?(::Window_Base) && !window.disposed?
            return window if klass ? window.is_a?(klass) : window.class.name == name
          end
          nil
        end

        # Tells the spot of the pointer as a place one pixel large, the screen's middle while the
        # pointer is off the screen.
        #
        # @return [Array<Integer>] [x, y, 1, 1].
        def self.pointer_spot
          at = Mouse.position || [Graphics.width / 2, Graphics.height / 2]
          [at[0].to_i, at[1].to_i, 1, 1]
        end

        # Opens a popover as its open: or its bound state turns true and closes it as that turns
        # false; called after every render of what holds it.
        #
        # @param part [Layer::Part] The popover's part.
        def self.follow_popover(part)
          params = part.node.params
          bind = params[:bind]
          owner = part.node.owner
          wanted = bind ? owner.respond_to?(bind) && owner.__send__(bind) ? true : false : params[:open] == true
          was = part.open_wanted
          part.open_wanted = wanted
          engine = part.engine
          if wanted && !was && !engine.open?
            if params[:target] == :pointer
              part.beside = pointer_spot
              engine.beside = part.beside
              engine.opened_from = holder(part)
            end
            engine.open
          elsif !wanted && engine.open?
            engine.close(:script)
          end
        end

        # Tells the engine part of the nearest part a part lies in, which a popover at the pointer
        # closes and moves with.
        #
        # @param part [Layer::Part] The part.
        # @return [Component, nil] The engine part, nil for none.
        def self.holder(part)
          around = part.parent
          around = around.parent until around.nil? || around.is_a?(Layer::Part)
          around && around.engine
        end
        private_class_method :holder

        # Takes a popover's close: its on_close, its bound state turned false and the focus back on
        # its target.
        #
        # @param part [Layer::Part] The popover's part.
        # @param why [Symbol] Why it closed.
        def self.popover_closed(part, why)
          return if part.gone && why == :script

          target = part.beside.is_a?(Target) ? part.beside.current : nil
          target.focus if target.is_a?(Component) && target.shown?
          Layer.popover_closed(part, why)
        end

        # Defines a column of huds under a name, or defines it anew, logs it and places the shown huds
        # that name it there.
        #
        # @param name [Symbol, String] The column's name.
        # @param params [Hash] :at, :gap and :align, see UI.column.
        # @param lines [Array<String>] The calls that led here.
        # @raise [MarkupError] A param is unknown or does not fit.
        def self.define_column(name, params, lines)
          check_column(name, params)
          x, y = params[:at]
          gap = params[:gap] || COLUMN_GAP
          align = params[:align] || :left
          again = @columns.key?(name.to_sym)
          @columns[name.to_sym] = [name.to_s, x, y, gap, align.to_s]
          lined = align == :center ? "its middle" : "its #{align} edge"
          log("#{Root.mod_file(lines)} #{again ? 'defined anew' : 'defined'} the column #{name.inspect} at [#{x}, #{y}], #{gap} px apart, each hud with #{lined} there")
          Layer.place_column_again(name.to_s)
          nil
        end

        # Checks the name and the params of a column.
        #
        # @param name [Object] The column's name.
        # @param params [Object] Its params.
        # @raise [MarkupError] A param is unknown or does not fit.
        def self.check_column(name, params)
          raise MarkupError, "UI.column takes a Symbol or a text as its name, not #{Declarations.show(name)}" unless name.is_a?(Symbol) || name.is_a?(String)
          raise MarkupError, "UI.column takes its params as at:, gap: and align:, not #{Declarations.show(params)}" unless params.is_a?(Hash)

          unknown = params.keys.find { |key| !COLUMN_PARAMS.include?(key) }
          if unknown
            near = Declarations.nearest(unknown, COLUMN_PARAMS)
            raise MarkupError, "UI.column takes no #{unknown}:#{near ? "; did you mean #{near}:?" : ''}"
          end
          at = params[:at]
          raise MarkupError, "UI.column needs at: [x, y], not #{Declarations.show(at)}" unless at.is_a?(Array) && at.size == 2 && at.all? { |each| each.is_a?(Integer) }

          gap = params[:gap]
          raise MarkupError, "UI.column takes gap: as pixels, not #{Declarations.show(gap)}" unless gap.nil? || (gap.is_a?(Integer) && gap >= 0)
          return if params[:align].nil? || COLUMN_ALIGNS.include?(params[:align])

          raise MarkupError, "UI.column takes align: #{COLUMN_ALIGNS.map { |each| each.inspect }.join(', ')}, not #{Declarations.show(params[:align])}"
        end
        private_class_method :check_column

        # Tells the column a hud names as C#'s tree takes it; one no mod defined is refused, logged
        # once per mod and name, and the hud keeps its own place until a mod defines it.
        #
        # @param part [Layer::Part] The hud's part.
        # @param name [Symbol, String] The column's name.
        # @return [Array, nil] [name, x, y, gap, align], nil for a column no mod defined.
        def self.column_place(part, name)
          place = @columns[name.to_s.to_sym]
          return place if place

          mod = Layer.mod_of(part)
          log_once([:column, mod, name.to_s], "#{mod} put a hud in the column #{name.inspect}, refused: no UI.column defined it, so the hud shows at its own place")
          nil
        end

        # Writes a mod's name as the log does.
        #
        # @param name [String, nil] The name.
        # @return [String] The name with spaces, in lower case.
        def self.plain(name)
          name.to_s.tr("_", " ").downcase
        end
        private_class_method :plain
      end
    end

    # Defines a named column of huds that the framework stacks down from a spot by their laid-out
    # heights: a hud given column: with the name joins it as it shows, the newest on top, and the
    # older ones jump down at once; one that leaves keeps its place until its leave: ends, then the
    # ones below close up. Defining a name again moves its column with the huds shown in it, and a
    # hud shown before its column was defined joins it then.
    #
    # @param name [Symbol, String] The column's name, such as :battle_left.
    # @param params [Hash] at: [x, y], the spot of its newest hud's top; gap:, the pixels between two
    #   huds, 4 by default; align: :left, :center or :right, which edge of each hud lies at x, its
    #   middle with :center, :left by default.
    # @return [nil] Always.
    # @raise [Engine::MarkupError] A param is unknown or does not fit.
    def self.column(name, params = {})
      Engine::Placement.define_column(name, params, caller)
    rescue Engine::MarkupError => e
      raise Engine::MarkupError, Engine::Errors.placed(e.message, caller)
    end
  end
end
