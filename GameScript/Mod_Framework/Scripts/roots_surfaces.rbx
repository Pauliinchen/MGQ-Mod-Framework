#----------------------------------------------------------------
#  roots_surfaces.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Freed a tilemap left on a viewport the game frees where RGSS cannot move it onto another
#                            - Noted the tilemaps on a viewport too, which move onto the hidden one as the game frees it
#                            - Made no objects on a frame of a window whose look and padding stay the same
#                            - Kept the game's window color off a window's own skin on every frame
#                            - Dressed a framed window that has a border or a background of its own in a skin painted with them
#                            - Kept the game window's padding within the least room the window keeps on any side
#      Paulinchen  2026-11-07: Kept a second spare picture, for a component drawn only inside a box
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What a picture the components draw on shares: it draws anew either whole or only in the parts
      # of it where components changed.
      module Spots
        # The most parts kept apart; past that the whole picture draws anew.
        MOST = 8

        # Room added around each part, where a component's outline may reach past its place.
        MARGIN = 4

        # @return [Boolean] Whether all of it draws anew on the next frame.
        attr_reader :dirty

        # Has all of it draw anew on the next frame, or none of it.
        #
        # @param on [Boolean] Whether it does.
        def dirty=(on)
          @dirty = on
          @spots = nil
        end

        # Has a part of the screen it covers draw anew on the next frame; parts that overlap draw as
        # one.
        #
        # @param rect [Rect] The part on the screen.
        def invalidate(rect)
          return if @dirty

          spot = Rect.new(rect.x - x - MARGIN, rect.y - y - MARGIN, rect.width + 2 * MARGIN, rect.height + 2 * MARGIN)
          spots = (@spots ||= [])
          while (met = spots.index { |each| touch?(each, spot) })
            spot = joined(spots.delete_at(met), spot)
          end
          spots << spot
          @dirty = true if spots.size > MOST
        end

        # Tells whether any of it draws anew on the next frame.
        #
        # @return [Boolean] Whether it does.
        def needs_paint?
          @dirty || !(@spots.nil? || @spots.empty?)
        end

        # Hands out the parts to draw anew, or nil when all of it draws anew, as when the parts cover
        # more than half of it.
        #
        # @return [Array<Rect>, nil] The parts on its picture.
        def spots
          return nil if @dirty || @spots.nil?

          picture = bitmap
          area = @spots.inject(0) { |sum, spot| sum + spot.width * spot.height }
          area * 2 > picture.width * picture.height ? nil : @spots
        end

        private

        # Tells whether two parts overlap or touch.
        #
        # @param one [Rect] One part.
        # @param other [Rect] The other.
        # @return [Boolean] Whether they do.
        def touch?(one, other)
          one.x <= other.x + other.width && other.x <= one.x + one.width && one.y <= other.y + other.height && other.y <= one.y + one.height
        end

        # Tells the smallest part holding two parts.
        #
        # @param one [Rect] One part.
        # @param other [Rect] The other.
        # @return [Rect] The part holding both.
        def joined(one, other)
          left = [one.x, other.x].min
          top = [one.y, other.y].min
          Rect.new(left, top, [one.x + one.width, other.x + other.width].max - left, [one.y + one.height, other.y + other.height].max - top)
        end
      end

      # A spare picture each part of a picture that draws anew is drawn on first, which cuts what the
      # components draw past the part, kept for the next part and grown as a larger one needs it.
      module Scratch
        # The spare picture of a part of a picture that draws anew.
        SPOT = 0

        # The spare picture of a component drawn only inside a box, which may draw onto the first.
        CLIP = 1

        # The spare pictures by their use, none before the first part.
        @bitmaps = []

        # Hands out a spare picture, its top left as large as asked cleared.
        #
        # @param width [Integer] The width needed.
        # @param height [Integer] The height needed.
        # @param use [Integer] Which picture: SPOT or CLIP.
        # @return [Bitmap] The picture.
        def self.bitmap(width, height, use = SPOT)
          picture = @bitmaps[use]
          if picture.nil? || picture.disposed? || picture.width < width || picture.height < height
            wide = [width, picture && !picture.disposed? ? picture.width : 0].max
            high = [height, picture && !picture.disposed? ? picture.height : 0].max
            picture.dispose if picture && !picture.disposed?
            return @bitmaps[use] = Bitmap.new(wide, high)
          end

          picture.clear_rect(0, 0, width, height)
          picture
        end

        # Frees the spare pictures.
        def self.clear
          @bitmaps.each { |picture| picture.dispose if picture && !picture.disposed? }
          @bitmaps = []
        end
      end
    end

    # Where a part of a picture that draws anew draws: the spare picture, standing at the part's
    # place on the screen.
    ClipSurface = Struct.new(:bitmap, :x, :y)

    module Engine
      # The framework's sprites that lie on a viewport of the game, which move onto the screen just
      # before the game frees that viewport, and the sprites, windows, planes and tilemaps of the
      # game and of every mod that are still on it then, which move onto a hidden viewport of their
      # own, or are freed with it where they cannot move, as RGSS3's tilemap cannot.
      #
      # RGSS ends the game without a word when it draws a sprite whose viewport was freed, or when
      # the garbage collector frees a sprite, a window or a tilemap that was still on a viewport as
      # it was freed (in RGSS301.dll at 0x111a1c).
      module ViewportSprites
        # Who the hook on the freeing of a viewport is registered by.
        TAG = "Mod Framework viewport sprites"

        # The instance variable of a viewport that lists the object ids of what of the game lies on
        # it; ids, so the list keeps nothing alive that the game dropped.
        ON_IT = :@mod_framework_on_it

        # The instance variable of a viewport that holds the size its list may reach before the
        # freed entries go.
        PRUNE_AT = :@mod_framework_prune_at

        # The size a viewport's list reaches before its freed entries go the first time.
        FIRST_PRUNE = 64

        # The instance variable of the game's Viewport class that marks the hooks noting what is put
        # on a viewport as made.
        NOTED = :@mod_framework_viewports_noted

        # What lies on each viewport, by the viewport: each answers leave_viewport.
        @held = {}.compare_by_identity

        # The hidden viewport what the game left on a freed viewport moves onto, nil before the first.
        @shelter = nil

        # Notes something that lies on a viewport.
        #
        # @param viewport [Viewport, nil] The viewport, nil for the screen.
        # @param holder [#leave_viewport] What lies on it.
        def self.add(viewport, holder)
          (@held[viewport] ||= []) << holder if viewport
        end

        # Forgets something that no longer lies on a viewport.
        #
        # @param viewport [Viewport, nil] The viewport.
        # @param holder [Object] What lay on it.
        def self.remove(viewport, holder)
          held = viewport && @held[viewport]
          return unless held

          held.delete_if { |each| each.equal?(holder) }
          @held.delete(viewport) if held.empty?
        end

        # Has everything on a viewport leave it, as the game is about to free it.
        #
        # @param viewport [Viewport] The viewport.
        def self.freeing(viewport)
          held = @held.delete(viewport)
          held.each { |holder| holder.leave_viewport } if held
          shelter_left(viewport)
        end

        # Tells how many viewports hold framework sprites, for the tests.
        #
        # @return [Integer] The viewports.
        def self.viewports
          @held.size
        end

        # Notes a sprite, window, plane or tilemap of the game or of a mod on the viewport it was put
        # on.
        #
        # The list lives on the viewport, so a viewport dropped without being freed takes it along.
        #
        # @param object [Sprite, Window, Plane, Tilemap] What was put on it.
        # @param viewport [Viewport, nil] The viewport, nil for the screen.
        def self.note(object, viewport)
          return if viewport.nil? || viewport.equal?(@shelter)

          on_it = viewport.instance_variable_get(ON_IT)
          viewport.instance_variable_set(ON_IT, on_it = []) unless on_it
          on_it << object.object_id
          prune(viewport, on_it) if on_it.size >= (viewport.instance_variable_get(PRUNE_AT) || FIRST_PRUNE)
        end

        # Drops the entries of a viewport's list that were freed or collected, and lets it grow to
        # twice what is left.
        #
        # @param viewport [Viewport] The viewport.
        # @param on_it [Array<Integer>] Its list.
        def self.prune(viewport, on_it)
          on_it.select! { |id| (object = living(id)) && !object.disposed? }
          viewport.instance_variable_set(PRUNE_AT, [on_it.size * 2, FIRST_PRUNE].max)
        end
        private_class_method :prune

        # Finds a sprite, window, plane or tilemap by its object id while the collector has not
        # taken it.
        #
        # @param id [Integer] The object id.
        # @return [Sprite, Window, Plane, Tilemap, nil] It, nil once collected or when the id now
        #   names something else.
        def self.living(id)
          object = ObjectSpace._id2ref(id)
          object.respond_to?(:viewport) && object.respond_to?(:disposed?) ? object : nil
        rescue RangeError
          nil
        end
        private_class_method :living

        # Moves what the game left on a viewport it frees onto the hidden shelter, where it stays
        # usable and the collector may free it, frees what cannot move, and logs both.
        #
        # Freeing what cannot move is safe: drawing it on the freed viewport would close the game
        # anyway.
        #
        # @param viewport [Viewport] The viewport.
        def self.shelter_left(viewport)
          on_it = viewport.instance_variable_get(ON_IT)
          return unless on_it

          viewport.instance_variable_set(ON_IT, nil)
          left = on_it.map { |id| living(id) }.compact.select { |each| !each.disposed? && each.viewport.equal?(viewport) }
          movable, stuck = left.partition { |each| each.respond_to?(:viewport=) }
          unless movable.empty?
            refuge = shelter
            movable.each { |each| each.viewport = refuge }
            Mod_Framework.log("moved #{movable.size} picture(s) of the game left on a viewport it freed onto a hidden one, so freeing them later cannot close the game: #{class_names(movable)}")
          end
          return if stuck.empty?

          stuck.each(&:dispose)
          Mod_Framework.log("freed #{stuck.size} picture(s) of the game left on a viewport it freed, which cannot move onto another, so the collector cannot close the game with them: #{class_names(stuck)}")
        end
        private_class_method :shelter_left

        # Tells the class names of pictures, each once.
        #
        # @param pictures [Array<Object>] The pictures.
        # @return [String] The names, sorted and joined by commas.
        def self.class_names(pictures)
          pictures.map { |each| each.class.name }.uniq.sort.join(", ")
        end
        private_class_method :class_names

        # Tells the hidden viewport the left pictures move onto, made at first need.
        #
        # @return [Viewport] The viewport.
        def self.shelter
          @shelter = nil if @shelter && UI.freed?(@shelter)
          @shelter ||= ::Viewport.new.tap { |viewport| viewport.visible = false }
        end
        private_class_method :shelter

        # Follows the freeing of every viewport, and the sprites, windows, planes and tilemaps put on
        # one, once the game runs.
        def self.install
          return unless defined?(::Viewport) && ::Viewport.method_defined?(:dispose)

          Hooks.before(::Viewport, :dispose, TAG) { Mod_Framework::UI::Engine::ViewportSprites.freeing(self) }
          return if ::Viewport.instance_variable_get(NOTED)

          # Marked on the game's class, which outlives a second load of the framework's scripts,
          # whose new hooks would wrap the wrapped methods again.
          ::Viewport.instance_variable_set(NOTED, true)
          %w[Sprite Plane Tilemap].each do |name|
            next unless Object.const_defined?(name)

            Hooks.after(Object.const_get(name), :initialize, TAG) { |*args| Mod_Framework::UI::Engine::ViewportSprites.note(self, args[0]) }
          end
          %w[Sprite Window Plane Tilemap].each do |name|
            klass = Object.const_defined?(name) ? Object.const_get(name) : nil
            next unless klass && klass.method_defined?(:viewport=)

            Hooks.after(klass, :viewport=, TAG) { |viewport| Mod_Framework::UI::Engine::ViewportSprites.note(self, viewport) }
          end
        end
      end

      # A picture the components of a root draw on, on a sprite of its own: a floating box's, or the
      # part a box scrolls, cut to what shows of it.
      class SpriteSurface
        include Spots

        # @return [Integer] Its left on the screen, where its picture starts.
        attr_reader :x

        # @return [Integer] Its top on the screen.
        attr_reader :y

        # @return [Component, nil] The component whose scrolled part it is, nil for a root's own.
        attr_reader :owner

        # Makes a hidden surface.
        #
        # @param owner [Component, nil] The component whose scrolled part it is, nil for a root's own.
        # @param viewport [Viewport, nil] The viewport its sprite lies on, nil for the screen.
        def initialize(owner = nil, viewport = nil)
          @owner = owner
          @sprite = Sprite.new(viewport)
          @sprite.visible = false
          @left_viewport = false
          @dirty = true
          @x = @y = 0
          ViewportSprites.add(viewport, self)
        end

        # Tells its picture.
        #
        # @return [Bitmap, nil] The picture, nil before it was placed.
        def bitmap
          @sprite.bitmap
        end

        # Puts it at a place, with a new picture when its size changed, drawn shifted from there and
        # showing only what lies inside a clip.
        #
        # @param x [Integer] Its left on the screen, where its components are laid out.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param z [Integer] Its depth.
        # @param clip [Rect, nil] What may show of it on the screen, nil for all of it.
        # @param shift [Array<Integer>, nil] How far it is drawn from its place, nil for not at all.
        # @param opacity [Integer, nil] How opaque it is drawn, nil for whole.
        def place(x, y, width, height, z, clip, shift = nil, opacity = nil)
          move_to_screen if UI.freed?(@sprite.viewport)
          width = 1 if width < 1
          height = 1 if height < 1
          picture = @sprite.bitmap
          unless picture && !picture.disposed? && picture.width == width && picture.height == height
            picture.dispose if picture && !picture.disposed?
            @sprite.bitmap = Bitmap.new(width, height)
            @dirty = true
          end
          @x = x
          @y = y
          left = shift ? x + shift[0] : x
          top = shift ? y + shift[1] : y
          show_part(left, top, width, height, clip)
          @sprite.z = z
          @sprite.opacity = opacity || Component::OPAQUE
        end

        # Shows the part of its picture that lies inside a clip, with the picture's top left corner at
        # a place on the screen, setting only what changed, since this runs every frame.
        #
        # @param left [Integer] Where its top left corner lies on the screen.
        # @param top [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param clip [Rect, nil] What may show of it on the screen, nil for all of it.
        def show_part(left, top, width, height, clip)
          shown_left = left
          shown_top = top
          right = left + width
          bottom = top + height
          if clip
            shown_left = clip.x if clip.x > shown_left
            shown_top = clip.y if clip.y > shown_top
            right = clip.x + clip.width if clip.x + clip.width < right
            bottom = clip.y + clip.height if clip.y + clip.height < bottom
          end
          shown_width = right > shown_left ? right - shown_left : 0
          shown_height = bottom > shown_top ? bottom - shown_top : 0
          source = @sprite.src_rect
          unless source.x == shown_left - left && source.y == shown_top - top && source.width == shown_width && source.height == shown_height
            source.set(shown_left - left, shown_top - top, shown_width, shown_height)
          end
          viewport = @sprite.viewport
          @sprite.x = viewport ? shown_left - viewport.rect.x + viewport.ox : shown_left
          @sprite.y = viewport ? shown_top - viewport.rect.y + viewport.oy : shown_top
        end
        private :show_part

        # Draws it at an opacity where it is, as a root fading out does.
        #
        # @param opacity [Integer] How opaque, 0 to 255.
        def fade(opacity)
          @sprite.opacity = opacity
        end

        # Tells what of the screen it covers, which the parts it holds are cut to, in one rectangle
        # it keeps for every frame.
        #
        # @return [Rect] The rectangle.
        def clip
          (@clip ||= Rect.new(0, 0, 0, 0)).set(@x, @y, bitmap ? bitmap.width : 0, bitmap ? bitmap.height : 0)
          @clip
        end

        # Shows or hides it.
        #
        # @param on [Boolean] Whether it shows.
        def show(on)
          @sprite.visible = on
        end

        # Moves it on by a frame: a sprite has nothing to move.
        def update
          nil
        end

        # Tells whether what it holds may show: a sprite shows at once.
        #
        # @return [Boolean] Always true.
        def ready?
          true
        end

        # Tells the tone without a tint, made once.
        #
        # @return [Tone] The tone.
        def self.untoned
          @untoned ||= Tone.new(0, 0, 0, 0)
        end

        # Frees its sprite and picture.
        def dispose
          ViewportSprites.remove(@sprite.viewport, self) unless @sprite.disposed?
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose unless @sprite.disposed?
        end

        # Tells whether the viewport its sprite lay on was freed, as a scene that ends frees its
        # spriteset's.
        #
        # @return [Boolean] Whether it was.
        def viewport_freed?
          @left_viewport || UI.freed?(@sprite.viewport)
        end

        # Moves its picture onto the screen while the viewport it lies on is about to be freed.
        def leave_viewport
          @left_viewport = true
          move_to_screen unless @sprite.disposed?
        end

        private

        # Moves its picture onto a sprite of its own on the screen, since RGSS refuses to place a
        # sprite whose viewport was freed.
        def move_to_screen
          lost = @sprite
          ViewportSprites.remove(lost.viewport, self)
          @sprite = Sprite.new
          @sprite.bitmap = lost.bitmap
          @sprite.visible = lost.visible
          lost.dispose unless lost.disposed?
        end
      end

      # Where a Canvas draws into a window skin: the skin, and where the screen's top left lies on it
      # for the Window's place, so a part of the skin lies where the canvas is told.
      SkinSurface = Struct.new(:bitmap, :x, :y)

      # The game window a framework Window is underneath, so the game's skin, the theme's dress and the
      # opening work on it as on any game window. Its theme is the Window's; a Window with a border or
      # a background of its own wears a skin painted with them over its theme's (wear_own_look).
      if defined?(::Window_Base)
        class Frame < ::Window_Base
          # Makes the window, closed and hidden until its Window has a place.
          #
          # @param component [Window] The framework Window it is.
          def initialize(component)
            @component = component
            @own_skin = nil
            @own_key = nil
            super(0, 0, 32, 32)
            self.back_opacity = back_opacity
            self.openness = 0
            self.visible = false
          end

          # Sets how opaque its background is: the Window's :back_opacity when it has one, else the
          # alpha of its own background, which the theme's dress does not overwrite.
          #
          # @param value [Integer] The opacity the game or the theme asks for.
          def back_opacity=(value)
            @asked_opacity = value
            own = @component.back_opacity
            own = @component.skin_back_opacity if own.nil?
            super(own.nil? ? value : UI.within(own.to_i, 0, Component::OPAQUE))
          end

          # Wears a skin painted in the Window's own border and background, over the skin of its
          # theme, while it has either and a place; else the skin of its theme again. Its own skin
          # wears no tone, which the game's update puts back on every frame. Called after every dress
          # of the theme, so it makes no objects while nothing it wears changed: its look, the preset
          # Theme.wear_skin put on it (@mf_worn), the colors and whether it draws enabled.
          def wear_own_look
            look = @component.rect ? @component.skin_look : nil
            return if look.nil? && @own_key.nil?

            enabled = @component.draws_enabled?
            unless look.equal?(@own_look) && @mf_worn.equal?(@own_worn) && Theme.serial == @own_serial && enabled == @own_enabled
              @own_look = look
              @own_worn = @mf_worn
              @own_serial = Theme.serial
              @own_enabled = enabled
              renew_own_skin(look, enabled)
            end
            self.tone.set(SpriteSurface.untoned) if @own_skin
          end

          # Frees its own skin with the window.
          def dispose
            super
            @own_skin.dispose if @own_skin && !@own_skin.disposed?
            @own_skin = nil
          end

          private

          # Paints its own skin anew, or gives it the skin of its theme again, when what it wears
          # differs from what it last wore.
          #
          # @param look [Array, nil] The look, as Window#skin_look tells; nil for the theme's skin.
          # @param enabled [Boolean] Whether its Window draws enabled.
          def renew_own_skin(look, enabled)
            base = theme_skin
            key = look ? [base.object_id, Theme.serial, enabled] + look.map { |each| plain_value(each) } : nil
            return if key == @own_key

            @own_key = key
            painted = key ? paint_own_skin(base, look) : nil
            self.windowskin = painted || base
            @own_skin.dispose if @own_skin && !@own_skin.disposed?
            @own_skin = painted
            self.back_opacity = @asked_opacity || back_opacity
          end

          # Tells the skin the theme gives it: its preset's, else the game's own.
          #
          # @return [Bitmap] The skin.
          def theme_skin
            preset = Theme.worn(ui_theme)
            preset ? Theme.skin_for(Theme.palette(ui_theme)) : Cache.system(Theme::GAME_SKIN)
          end

          # Paints a skin from the theme's: the background's square in the background's color, opaque,
          # since back_opacity carries its alpha, without the pattern; the frame's borders in the
          # border, at most the skin's border band deep. :theme keeps the theme's part, false leaves it
          # empty.
          #
          # @param base [Bitmap] The theme's skin.
          # @param look [Array] The background, the border and its width, as Window#skin_look tells.
          # @return [Bitmap] The skin.
          def paint_own_skin(base, look)
            background, border, width = look
            skin = Bitmap.new(Theme::SKIN_SIDE, Theme::SKIN_SIDE)
            skin.blt(0, 0, base, base.rect)
            rect = @component.rect
            canvas = Canvas.new(@component, SkinSurface.new(skin, rect.x, rect.y))
            unless background.nil? || background == :theme
              skin.clear_rect(*Theme::SKIN_BACK)
              skin.clear_rect(*Theme::SKIN_PATTERN)
              unless background == false
                color = canvas.color(background)
                skin.fill_rect(*(Theme::SKIN_BACK + [Color.new(color.red, color.green, color.blue, Component::OPAQUE)]))
              end
            end
            paint_own_frame(skin, canvas, border, width) unless border.nil? || border == :theme
            skin
          end

          # Clears the borders of a skin's frame square, keeping the scroll arrows in its middle, and
          # draws a border along them.
          #
          # @param skin [Bitmap] The skin.
          # @param canvas [Canvas] A canvas on the skin.
          # @param border [Object] The border: a color, :shade or false.
          # @param width [Integer] Its pixels.
          def paint_own_frame(skin, canvas, border, width)
            x, y, side = Theme::SKIN_FRAME[0], Theme::SKIN_FRAME[1], Theme::SKIN_FRAME[2]
            band = Theme::SKIN_BORDER
            skin.clear_rect(x, y, side, band)
            skin.clear_rect(x, y + side - band, side, band)
            skin.clear_rect(x, y + band, band, side - 2 * band)
            skin.clear_rect(x + side - band, y + band, band, side - 2 * band)
            canvas.border(x, y, side, side, border, [width, band].min, :of => :edge)
          end

          # Turns a color or a look into a value that compares by what it holds.
          #
          # @param value [Object] The value.
          # @return [Object] The value, a Color as its red, green, blue and alpha.
          def plain_value(value)
            value.is_a?(Color) ? [value.red, value.green, value.blue, value.alpha] : value
          end

          public

          # Tells the window's theme, which the theme's dress reads: the Window's.
          #
          # @return [Boolean, String, Theme::Preset] The theme, see Component#theme_value.
          def ui_theme
            @component.theme_value
          end
        end
      end

      # A picture the components of a Window draw on: the contents of its game window, whose frame and
      # background the game draws in the theme's skin.
      class WindowSurface
        include Spots

        # @return [Frame] The game window.
        attr_reader :frame

        # Makes the game window of a Window, closed and hidden.
        #
        # @param component [Window] The Window.
        def initialize(component)
          @component = component
          @frame = Frame.new(component)
          @dirty = true
          @shown = false
          @inset = MARGIN
        end

        # Tells its picture.
        #
        # @return [Bitmap] The window's contents.
        def bitmap
          @frame.contents
        end

        # Tells where its picture starts where its components are laid out: inside the window's
        # padding, before the window is drawn shifted.
        #
        # @return [Integer] Its left.
        def x
          @frame.x + @frame.padding - (@shift ? @shift[0] : 0)
        end

        # Tells where its picture starts where its components are laid out.
        #
        # @return [Integer] Its top.
        def y
          @frame.y + @frame.padding - (@shift ? @shift[1] : 0)
        end

        # Puts the window at a place, with new contents when its size changed.
        #
        # Its padding stays MARGIN short of the least room the Window keeps on any side, since the game
        # cuts the contents at the padding and would cut the outline of a text at the edge of what the
        # Window holds.
        #
        # @param x [Integer] Its left on the screen.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width, its frame included.
        # @param height [Integer] Its height.
        # @param z [Integer] Its depth.
        # @param _clip [Rect, nil] Unused, a window shows whole.
        # @param shift [Array<Integer>, nil] How far the window is drawn from its place, nil for not at all.
        # @param opacity [Integer, nil] How opaque it is drawn, nil for whole.
        def place(x, y, width, height, z, _clip, shift = nil, opacity = nil)
          fade(opacity || Component::OPAQUE)
          @shift = shift
          x += shift[0] if shift
          y += shift[1] if shift
          @frame.move(x, y, width, height) unless @frame.x == x && @frame.y == y && @frame.width == width && @frame.height == height
          room = @component.frame_room
          padding = room > MARGIN ? room - MARGIN : 0
          @inset = room - padding
          @frame.padding = padding unless @frame.padding == padding
          inner_width = width - 2 * padding > 1 ? width - 2 * padding : 1
          inner_height = height - 2 * padding > 1 ? height - 2 * padding : 1
          contents = @frame.contents
          unless contents && !contents.disposed? && contents.width == inner_width && contents.height == inner_height
            contents.dispose if contents && !contents.disposed?
            @frame.contents = Bitmap.new(inner_width, inner_height)
            @dirty = true
          end
          @frame.z = z
        end

        # Tells what of the screen lies inside the room the Window keeps, which the parts it holds are
        # cut to, in one rectangle it keeps for every frame.
        #
        # @return [Rect] The rectangle.
        def clip
          width = bitmap.width - 2 * @inset
          height = bitmap.height - 2 * @inset
          (@clip ||= Rect.new(0, 0, 0, 0)).set(x + @inset, y + @inset, width > 0 ? width : 0, height > 0 ? height : 0)
          @clip
        end

        # Draws the window and its contents at an opacity, as a root fading in or out does.
        #
        # @param opacity [Integer] How opaque, 0 to 255.
        def fade(opacity)
          return if opacity == (@opacity || Component::OPAQUE)

          @opacity = opacity
          @frame.opacity = opacity
          @frame.contents_opacity = opacity
        end

        # Shows the window, opening it the first time, or hides it.
        #
        # @param on [Boolean] Whether it shows.
        def show(on)
          @frame.visible = on
          @frame.open if on && !@shown
          @shown = on
        end

        # Moves the window on by a frame: its opening, its tone and the theme's dress.
        def update
          @frame.update
        end

        # Tells whether the window is open whole, so the parts it holds on sprites may show.
        #
        # @return [Boolean] Whether it is.
        def ready?
          @frame.openness >= 255
        end

        # Frees the window and its contents.
        def dispose
          @frame.dispose unless @frame.disposed?
        end

        # Tells whether the viewport its window lies on was freed: a framework window lies on none.
        #
        # @return [Boolean] Whether it was.
        def viewport_freed?
          UI.freed?(@frame.viewport)
        end
      end
    end

    # Once the game runs, the framework's sprites leave a viewport before the game frees it.
    Run.on_start("viewport sprites") { Mod_Framework::UI::Engine::ViewportSprites.install }
  end
end
