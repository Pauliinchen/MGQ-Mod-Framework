#----------------------------------------------------------------
#  components_pictures.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Kept each scaled picture with its part, by the picture's name
#                            - Scaled an image to its room at any factor with :auto_scale, its pixels sharp or smooth
#                            - Found a character's face in a hue
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # An icon of the game's iconset, as large as its size: with no size, the iconset's own times its
      # :scale, so :scale => 2 draws it at 48 pixels.
      #
      # Events: click.
      class Icon < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "icon"

        # Tells the defaults of the options: no icon, at the iconset's size.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:icon => nil, :scale => nil)
        end

        # Tells which properties of C#'s tree each option sets: a scale is a size.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:scale => ["size"])
        end

        options :icon, :scale

        # Draws the icon in the middle of its place, as large as the place's shorter side.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          side = [canvas.width, canvas.height].min
          canvas.icon(@options[:icon], (canvas.width - side) / 2, (canvas.height - side) / 2, :side => side)
        end

        private

        # Tells its fixed size: each side given, else the iconset's icon times its scale.
        #
        # @return [Array<Integer>] Its width and height.
        def fixed_size
          side = (ICON_SIZE * UI.scale(@options[:scale])).round
          given = super || [nil, nil]
          [given[0] || side, given[1] || side]
        end
      end

      # A character's map sprite, standing and facing down, trimmed to its pixels, such as for a HUD
      # of the party's leader.
      module Figure
        # Characters side by side in a sheet of eight.
        CHARACTERS_PER_ROW = 4

        # Frames of a walk in a sheet.
        WALK_FRAMES = 3

        # Directions in a sheet, one row each.
        DIRECTIONS = 4

        # The frame of a walk that stands.
        STANDING_FRAME = 1

        # Each character's figure in its sheet, by the sheet's name and the character's place.
        @figures = {}

        # Finds a character's figure.
        #
        # @param actor [Game_Actor] The character.
        # @return [Array, nil] The sprite sheet and the figure's rectangle in it; nil for a character
        #   without a sprite.
        def self.of(actor)
          name = actor.character_name.to_s
          return nil if name.empty?

          sheet = Cache.character(name)
          index = actor.character_index.to_i
          [sheet, trimmed(sheet, frame_rect(sheet, name, index), [name, index])]
        end

        # Finds a character's standing frame facing down in their sprite sheet.
        #
        # @param sheet [Bitmap] The sprite sheet.
        # @param name [String] Its file name, whose $ marks a sheet of one character.
        # @param index [Integer] The character's place in a sheet of eight.
        # @return [Rect] The frame.
        def self.frame_rect(sheet, name, index)
          single = name[/\A[!$]./].to_s.include?("$")
          width = sheet.width / (single ? WALK_FRAMES : WALK_FRAMES * CHARACTERS_PER_ROW)
          height = sheet.height / (single ? DIRECTIONS : DIRECTIONS * 2)
          index = 0 if single
          left = (index % CHARACTERS_PER_ROW * WALK_FRAMES + STANDING_FRAME) * width
          top = index / CHARACTERS_PER_ROW * DIRECTIONS * height
          Rect.new(left, top, width, height)
        end

        # Finds where a frame draws its figure: the smallest rectangle holding every pixel that is not
        # see-through, the whole frame for an empty one. Kept per character, since reading the pixels
        # takes a while.
        #
        # @param sheet [Bitmap] The sprite sheet.
        # @param frame [Rect] The frame.
        # @param key [Array] What the figure is kept by, the sheet's name and the character's place.
        # @return [Rect] The figure.
        def self.trimmed(sheet, frame, key)
          @figures[key] ||= begin
            xs = []
            ys = []
            frame.height.times do |dy|
              frame.width.times do |dx|
                next if sheet.get_pixel(frame.x + dx, frame.y + dy).alpha.to_i == 0

                xs << frame.x + dx
                ys << frame.y + dy
              end
            end
            xs.empty? ? frame : Rect.new(xs.min, ys.min, xs.max - xs.min + 1, ys.max - ys.min + 1)
          end
        end
      end

      # Pictures scaled to a size at any factor, each side as C# plans it (PictureScale): copied,
      # taken pixel by pixel (each the nearest pixel, or for a smooth enlargement a blend of the two
      # it lies between) or shrunk in one stretch, which the game smooths. The part that draws one
      # keeps it in its Copies.
      module Scaled
        # Plans how a picture scales, PictureScale.Topic.
        TOPIC = "ui.picture.scale"

        # How the pixels of a picture scale.
        SAMPLINGS = [:sharp, :smooth]

        # The scaled copies a part keeps for its draws, each by the name of the picture it was scaled
        # from, made anew only when that picture or the size changes and freed with the part.
        #
        # Paradox frees a face sheet after each draw, so a copy kept by the sheet's picture would be
        # made anew every time.
        class Copies
          # Makes an empty keeper.
          #
          # @param single [Boolean] Whether it keeps one copy in all, as a part that shows one
          #   picture, else one per picture, as a list's avatars.
          def initialize(single)
            @single = single
            @copies = {}
          end

          # Hands out a part of a picture scaled into a room, made anew only when the picture's name or
          # the room, the fit or the sampling changes.
          #
          # @param name [Array] What names the picture whatever Bitmap holds it, see Scaled.name_of.
          # @param found [Array] The picture and the part of it.
          # @param room [Array<Integer>] The room's width and height.
          # @param fit [Symbol] :contain, :cover or :fill.
          # @param sampling [Symbol] :sharp or :smooth.
          # @return [Bitmap, nil] The scaled copy; nil without the DLL's plan.
          def picture(name, found, room, fit, sampling)
            key = [room[0].to_i, room[1].to_i, fit.to_s, sampling.to_s]
            kept = @copies[name]
            return kept[1] if kept && kept[0] == key && !kept[1].disposed?

            part = found[1]
            plan = Scaled.plan(part.width, part.height, room, fit, sampling)
            return nil unless plan

            @single ? dispose : forget(name)
            copy = Scaled.picture(found[0], part, plan)
            @copies[name] = [key, copy]
            copy
          end

          # Frees every copy it keeps.
          def dispose
            @copies.each_value { |_key, copy| copy.dispose unless copy.disposed? }
            @copies.clear
          end

          private

          # Frees the copy of a picture.
          #
          # @param name [Array] The picture's name.
          def forget(name)
            kept = @copies.delete(name)
            kept[1].dispose if kept && !kept[1].disposed?
          end
        end

        # Tells what names a character's picture whatever Bitmap holds it: the face file, the face and
        # the hue, the sprite file and the character's place in it, or the character.
        #
        # @param actor [Object] The character.
        # @param kind [Symbol] :face, :figure or :art.
        # @param hue [Integer] The hue a face draws in.
        # @return [Array] The name.
        def self.name_of(actor, kind, hue = 0)
          case kind
          when :face then [:face, actor.face_name.to_s, actor.face_index.to_i, hue.to_i]
          when :figure then [:figure, actor.character_name.to_s, actor.character_index.to_i]
          else [kind, actor.id]
          end
        end

        # Plans how a picture scales into a room, asked of C#.
        #
        # @param width [Integer] The picture's width.
        # @param height [Integer] Its height.
        # @param room [Array<Integer>] The room's width and height.
        # @param fit [Symbol] :contain, :cover or :fill.
        # @param sampling [Symbol] :sharp or :smooth.
        # @return [Array, nil] The scaled width and height and how each side scales, see
        #   PictureScale.Topic; nil without the DLL.
        def self.plan(width, height, room, fit, sampling)
          return nil unless Mod_Framework.available?

          Mod_Framework.bridge.call(TOPIC, [width.to_i, height.to_i, room[0].to_i, room[1].to_i, fit.to_s, sampling.to_s])
        end

        # Makes a copy of a part of a picture scaled as a plan tells.
        #
        # The part is cut out first, since a stretch straight from a sheet blends in pixels of the
        # pictures beside it at the edges.
        #
        # @param sheet [Bitmap] The picture.
        # @param part [Rect] The part of it.
        # @param plan [Array] The plan, as plan hands it out.
        # @return [Bitmap] The scaled copy, the caller's to free.
        def self.picture(sheet, part, plan)
          width, height, across, down = plan
          alone = Bitmap.new(part.width, part.height)
          alone.blt(0, 0, sheet, part)
          tall = Bitmap.new(part.width, height)
          side(tall, alone, alone.rect, down, false)
          alone.dispose
          scaled = Bitmap.new(width, height)
          side(scaled, tall, tall.rect, across, true)
          tall.dispose
          scaled
        end

        # Scales one side of a picture onto another as its side of a plan tells.
        #
        # @param target [Bitmap] Where it draws, as long as the side scaled.
        # @param source [Bitmap] The picture.
        # @param part [Rect] The part of it.
        # @param side [Array] The side's way and samples, see PictureScale.Topic.
        # @param across [Boolean] Whether the side is the width, else the height.
        def self.side(target, source, part, side, across)
          way, samples = side
          case way
          when "copy" then target.blt(0, 0, source, part)
          when "stretch" then target.stretch_blt(target.rect, source, part)
          else
            samples.each_with_index do |(from, toward, weight), at|
              line(target, source, part, at, from, across, Component::OPAQUE)
              line(target, source, part, at, toward, across, weight) if weight > 0
            end
          end
        end

        # Copies one line of a picture, a column or a row, onto a line of another.
        #
        # @param target [Bitmap] Where it draws.
        # @param source [Bitmap] The picture.
        # @param part [Rect] The part of it.
        # @param at [Integer] The line it draws on.
        # @param from [Integer] The line of the part it copies.
        # @param across [Boolean] Whether the lines are columns, else rows.
        # @param opacity [Integer] How opaque the copy draws over what the line holds.
        def self.line(target, source, part, at, from, across, opacity)
          if across
            target.blt(at, 0, source, Rect.new(part.x + from, part.y, 1, part.height), opacity)
          else
            target.blt(0, at, source, Rect.new(part.x, part.y + from, part.width, 1), opacity)
          end
        end

        private_class_method :side, :line
      end

      # An image: a picture file of the mod, a Bitmap, a character's face, their figure (Figure) or
      # their portrait, the art the game's Library shows of them. With no size it is as large as the
      # image times its :scale. :scale draws it at that fixed factor whatever its place; without it,
      # :fit scales it to its place, also as the place changes: :whole multiples (the figure's default,
      # which keeps its pixels sharp), :contain (all of it shows, the default of the others), :cover
      # (it fills its place and what sticks out is cut) or :fill (stretched to its place). :anchor tells which part stays when it is cut
      # and where a smaller image sits: :top, :center or :bottom (a figure's default, so it stands).
      # :auto_scale keeps its height following the width it gets in C#'s tree and draws it at any
      # factor, its pixels as :sampling tells (Scaled): :sharp, a figure's default, or :smooth.
      # :blur draws a picture file blurred, such as a screenshot that shows a spoiler, and :label a
      # text on a dark band across its middle, on a dim plate while it has no image.
      #
      # Events: click.
      class Picture < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "picture"

        # The side of a face in the game's face sheets.
        FACE_SIDE = 96

        # Faces side by side in a face sheet.
        FACES_PER_ROW = 4

        # How an image scales into its place.
        FITS = [:whole, :contain, :cover, :fill]

        # Where an image sits in its place, up and down.
        ANCHORS = [:top, :center, :bottom]

        # The place of the folder in an entry of the Library's art.
        ART_FOLDER = 0

        # The place of the file in an entry of the Library's art.
        ART_NAME = 1

        # The place of the hue in an entry of the Library's art.
        ART_HUE = 2

        # The place of the ratio the Library draws the art at in an entry of the Library's art.
        ART_RATIO = 5

        # Tells the defaults of the options: no image.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:file => nil, :bitmap => nil, :face => nil, :figure => nil, :portrait => nil, :fit => nil, :anchor => nil, :scale => nil, :blur => false,
                      :label => nil, :auto_scale => false, :sampling => nil)
        end

        # Tells which properties of C#'s tree each option sets: an image or a scale measures anew, and
        # :auto_scale keeps its proportions.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:file => ["measured"], :bitmap => ["measured"], :face => ["measured"], :figure => ["measured"], :portrait => ["measured"],
                      :scale => ["measured"], :auto_scale => ["aspect"])
        end

        options :file, :bitmap, :face, :figure, :portrait, :fit, :anchor, :scale, :blur, :label, :auto_scale, :sampling

        # Finds a character's face in their face sheet, in a hue as the game's draw_face_hue loads it.
        #
        # @param actor [Game_Actor] The character: anything with a face_name and a face_index.
        # @param hue [Integer] The hue, 0 for the face's own colors.
        # @return [Array, nil] The face sheet and the face's rectangle; nil for a character without one.
        def self.face(actor, hue = 0)
          name = actor.face_name.to_s
          return nil if name.empty?

          index = actor.face_index.to_i
          sheet = hue.to_i == 0 ? Cache.face(name) : Cache.face(name, hue.to_i)
          [sheet, Rect.new(index % FACES_PER_ROW * FACE_SIDE, index / FACES_PER_ROW * FACE_SIDE, FACE_SIDE, FACE_SIDE)]
        end

        # Finds the art the game's Library shows of a character, in its hue.
        #
        # Cache.load_bitmap also reads the game's archive, where a test for the file finds nothing.
        #
        # @param actor [Game_Actor] The character.
        # @return [Array, nil] The art, its whole rectangle and the ratio the Library draws it at; nil
        #   for a character without art, and for art that cannot be loaded, which is logged once.
        def self.portrait(actor)
          entry = defined?(NWConst::Library::ACTOR_IMAGE) ? NWConst::Library::ACTOR_IMAGE[actor.id] : nil
          return nil unless entry.is_a?(Array) && !entry[ART_NAME].to_s.empty?

          bitmap = Cache.load_bitmap(entry[ART_FOLDER].to_s, entry[ART_NAME].to_s, entry[ART_HUE].to_i)
          ratio = entry[ART_RATIO].is_a?(Numeric) && entry[ART_RATIO] > 0 ? entry[ART_RATIO].to_f : 1.0
          [bitmap, bitmap.rect, ratio]
        rescue => e
          Tree.log_once([:portrait, actor.id], "the Library art of actor #{actor.id} cannot be loaded: #{Logging.failure(e)}")
          nil
        end

        # Tells its size: the image's times its scale.
        #
        # @return [Array<Integer>] Its width and height, nothing without an image.
        def measure
          found = source
          return [0, 0] unless found

          width, height = natural_size(found)
          factor = UI.scale(@options[:scale])
          [(width * factor).round, (height * factor).round]
        end

        # Tells the properties of C#'s tree: with :auto_scale it keeps its proportions.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["aspect"] = @options[:auto_scale] ? true : false
          props
        end

        # Draws the image scaled into its place, the part outside its place cut, and its label over
        # it; without an image the label on a dim plate.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          found = source
          top, right, bottom, left = padding_sides
          room = Rect.new(left, top, canvas.width - left - right, canvas.height - top - bottom)
          label = @options[:label].to_s
          unless found
            PictureLook.draw_plate(canvas, room.x, room.y, room.width, room.height) unless label.empty?
            PictureLook.draw_label(canvas, room.x, room.y, room.width, room.height, label)
            return
          end

          draw_image(canvas, found, room)
          PictureLook.draw_label(canvas, room.x, room.y, room.width, room.height, label)
        end

        # Frees its pictures and its scaled copy.
        def release_surfaces
          super
          @copies.dispose if @copies
        end

        private

        # Draws the image scaled into its place, the part outside its place cut.
        #
        # @param canvas [Canvas] Where it draws.
        # @param found [Array] The image as source hands it out.
        # @param room [Rect] Its place.
        def draw_image(canvas, found, room)
          width, height = natural_size(found)
          return if width <= 0 || height <= 0 || room.width <= 0 || room.height <= 0
          return if @options[:auto_scale] && draw_scaled(canvas, found, room)
          return draw_cut(canvas, found[0], found[1], [room.x, room.y, room.width, room.height], room) if fit(found) == :fill && !@options[:scale]

          factor = scale_in(room, width, height, found)
          drawn_width = width * factor
          drawn_height = height * factor
          top_gap = { :top => 0, :center => (room.height - drawn_height) / 2, :bottom => room.height - drawn_height }[anchor(found)]
          draw_cut(canvas, found[0], found[1], [room.x + (room.width - drawn_width) / 2, room.y + top_gap, drawn_width, drawn_height], room)
        end

        # Draws the image scaled into its place at any factor as C# plans it, its pixels as its
        # sampling tells, the part outside its place cut.
        #
        # @param canvas [Canvas] Where it draws.
        # @param found [Array] The image as source hands it out.
        # @param room [Rect] Its place.
        # @return [Boolean] Whether it drew, false without the DLL's plan.
        def draw_scaled(canvas, found, room)
          sampling = sampling_of(found)
          fitted = fit(found)
          @copies ||= Scaled::Copies.new(true)
          scaled = @copies.picture(picture_name(found), found, [room.width, room.height], fitted == :whole ? :contain : fitted, sampling)
          return false unless scaled

          top_gap = { :top => 0, :center => (room.height - scaled.height) / 2, :bottom => room.height - scaled.height }[anchor(found)]
          draw_cut(canvas, scaled, scaled.rect, [room.x + (room.width - scaled.width) / 2, room.y + top_gap, scaled.width, scaled.height], room)
          true
        end

        # Tells what names the image whatever Bitmap holds it: its file, its Bitmap, or the
        # character's picture.
        #
        # @param found [Array] The image as source hands it out.
        # @return [Array] The name.
        def picture_name(found)
          return [:file, @options[:file].to_s, @options[:blur] ? true : false] if @options[:file]
          return [:bitmap, @options[:bitmap]] if @options[:bitmap]

          Scaled.name_of(UI.actor(@options[:face] || @options[:figure] || @options[:portrait]), found[3])
        end

        # Tells how the image's pixels scale with :auto_scale: its :sampling, else sharp for a figure
        # and smooth for the others.
        #
        # @param found [Array] The image as source hands it out.
        # @return [Symbol] :sharp or :smooth.
        def sampling_of(found)
          return (found[3] == :figure ? :sharp : :smooth) if @options[:sampling].nil?

          UI.choice(@options[:sampling], Scaled::SAMPLINGS, :smooth, "sampling").to_sym
        end

        # Finds the image and the part of it drawn.
        #
        # @return [Array, nil] The picture, the rectangle, the ratio of its natural size to the
        #   rectangle and what it is (:image, :face, :figure or :art); nil without one.
        def source
          if @options[:file]
            picture = UI.picture(@options[:file], @options[:blur])
            picture && [picture, picture.rect, 1.0, :image]
          elsif @options[:bitmap]
            @options[:bitmap].disposed? ? nil : [@options[:bitmap], @options[:bitmap].rect, 1.0, :image]
          elsif @options[:face]
            actor = UI.actor(@options[:face])
            kind_of(actor && Picture.face(actor), :face)
          elsif @options[:figure]
            actor = UI.actor(@options[:figure])
            kind_of(actor && Figure.of(actor), :figure)
          elsif @options[:portrait]
            actor = UI.actor(@options[:portrait])
            art = actor && Picture.portrait(actor)
            art ? art + [:art] : stand_in(actor)
          end
        end

        # Finds what a portrait shows of a character without Library art: the face, else the figure.
        #
        # @param actor [Game_Actor, nil] The character.
        # @return [Array, nil] The image as source hands it out, nil for none.
        def stand_in(actor)
          actor && (kind_of(Picture.face(actor), :face) || kind_of(Figure.of(actor), :figure))
        end

        # Hands out a picture and its rectangle as source does.
        #
        # @param found [Array, nil] The picture and the rectangle.
        # @param kind [Symbol] What it is.
        # @return [Array, nil] The image, nil for none.
        def kind_of(found, kind)
          found && [found[0], found[1], 1.0, kind]
        end

        # Tells the image's natural size: its rectangle times its ratio.
        #
        # @param found [Array] The image as source hands it out.
        # @return [Array<Float>] Its width and height.
        def natural_size(found)
          [found[1].width * found[2], found[1].height * found[2]]
        end

        # Tells the factor the image draws at: its :scale, else the one its fit gives in its place.
        #
        # @param room [Rect] The place.
        # @param width [Float] The image's natural width.
        # @param height [Float] Its natural height.
        # @param found [Array] The image as source hands it out.
        # @return [Float] The factor.
        def scale_in(room, width, height, found)
          return UI.scale(@options[:scale]) if @options[:scale]

          least, most = [room.width / width, room.height / height].minmax
          case fit(found)
          when :cover then most
          when :whole then least >= 1 ? least.floor.to_f : least
          else least
          end
        end

        # Tells how the image scales: its :fit, else whole multiples for a figure and to fit for the
        # others; a portrait's stand-in always by whole multiples, so it is never cut.
        #
        # @param found [Array] The image as source hands it out.
        # @return [Symbol] :whole, :contain, :cover or :fill.
        def fit(found)
          return :whole if @options[:portrait] && found[3] != :art
          return (found[3] == :figure ? :whole : :contain) if @options[:fit].nil?

          UI.choice(@options[:fit], FITS, :contain, "fit").to_sym
        end

        # Tells where the image sits up and down: its :anchor, else a figure on the bottom and the
        # others in the middle.
        #
        # @param found [Array] The image as source hands it out.
        # @return [Symbol] :top, :center or :bottom.
        def anchor(found)
          return (found[3] == :figure ? :bottom : :center) if @options[:anchor].nil?

          UI.choice(@options[:anchor], ANCHORS, :center, "anchor").to_sym
        end

        # Draws the part of an image that lies in its place.
        #
        # @param canvas [Canvas] Where it draws.
        # @param bitmap [Bitmap] The picture.
        # @param part [Rect] The part of the picture the image is.
        # @param drawn [Array<Float>] Where the whole image would draw: left, top, width and height,
        #   kept unrounded so a cut image stays centered to the pixel.
        # @param room [Rect] The place.
        def draw_cut(canvas, bitmap, part, drawn, room)
          x, y, width, height = drawn
          left = [x, room.x].max
          top = [y, room.y].max
          right = [x + width, room.x + room.width].min
          bottom = [y + height, room.y + room.height].min
          return if right - left < 1 || bottom - top < 1

          across = part.width / width
          down = part.height / height
          cut = Rect.new((part.x + (left - x) * across).round, (part.y + (top - y) * down).round,
                         [((right - left) * across).round, 1].max, [((bottom - top) * down).round, 1].max)
          canvas.picture(bitmap, left.round, top.round, (right - left).round, (bottom - top).round, cut)
        end
      end

      # What a picture shows over itself: a badge on a dark plate at its top left and a label on a
      # dark band across its middle, and a dim plate in its place while it has no image; Picture and
      # the picture rows of a List draw them alike.
      module PictureLook
        # The badge's height.
        BADGE_HEIGHT = 20

        # Room between the picture's edge and its badge.
        BADGE_INSET = 4

        # Room between the badge's edge and its text.
        BADGE_PAD = 6

        # The label's band's height.
        BAND_HEIGHT = 22

        # How opaque the plates behind a badge and a label are: black at 70 percent.
        PLATE_OPACITY = 178

        # Draws an image file into a rectangle, filling it and cut from its middle (:cover) or whole
        # (:contain), and over it its badge and its label; a file that cannot be read draws the dim
        # plate with its label. A filled rectangle copies the file scaled to its size once (see
        # UI.picture), so drawing it again scales nothing.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The rectangle's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Hash] :file, :blur, :fit (:cover by default, or :contain), :badge ({:text,
        #   :color}), :label, :opacity (how opaque a filling image draws, whole by default).
        def self.draw(canvas, x, y, width, height, look)
          return if width <= 0 || height <= 0

          drawn = look[:file] ? draw_file(canvas, look[:file].to_s, x, y, width, height, look) : false
          draw_plate(canvas, x, y, width, height) unless drawn
          badge = look[:badge]
          draw_badge(canvas, x + BADGE_INSET, y + BADGE_INSET, width - 2 * BADGE_INSET, badge[:text], badge[:color]) if badge.is_a?(Hash)
          draw_label(canvas, x, y, width, height, look[:label])
        end

        # Draws an image file into a rectangle: whole and centered with :contain, else filling it, cut
        # from its middle and scaled once.
        #
        # @param canvas [Canvas] Where it draws.
        # @param file [String] The file.
        # @param x [Integer] The rectangle's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param look [Hash] See draw.
        # @return [Boolean] Whether the file could be read.
        def self.draw_file(canvas, file, x, y, width, height, look)
          if look[:fit] == :contain
            bitmap = UI.picture(file, look[:blur])
            draw_image(canvas, bitmap, x, y, width, height, :contain) if bitmap
            return bitmap ? true : false
          end

          sized = UI.picture(file, look[:blur], [width, height])
          canvas.blt(x, y, sized, sized.rect, look[:opacity] || Component::OPAQUE) if sized
          sized ? true : false
        end

        # Draws a picture filling a rectangle cut from its middle, or whole and centered with :contain.
        #
        # @param canvas [Canvas] Where it draws.
        # @param bitmap [Bitmap] The picture.
        # @param x [Integer] The rectangle's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param fit [Symbol, nil] :contain, else :cover.
        def self.draw_image(canvas, bitmap, x, y, width, height, fit)
          source = bitmap.rect
          return if source.width <= 0 || source.height <= 0

          across = width.to_f / source.width
          down = height.to_f / source.height
          if fit == :contain
            factor = [across, down].min
            drawn = [(source.width * factor).round, (source.height * factor).round]
            return canvas.picture(bitmap, x + (width - drawn[0]) / 2, y + (height - drawn[1]) / 2, drawn[0], drawn[1])
          end

          canvas.picture(bitmap, x, y, width, height, UI.cover_part(source, width, height))
        end

        # Draws the dim plate of a picture that has no image.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        def self.draw_plate(canvas, x, y, width, height)
          canvas.box(x, y, width, height, :fill => :well, :edge => :edge)
        end

        # Draws a badge: a small text on a dark plate as wide as it needs.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] Its left in the component.
        # @param y [Integer] Its top.
        # @param room [Integer] The widest it may be.
        # @param text [String, nil] Its text; nil or empty for none.
        # @param color [Symbol, nil] The text's color.
        def self.draw_badge(canvas, x, y, room, text, color)
          return if text.to_s.empty? || room <= 2 * BADGE_PAD

          width = [canvas.text_width(text.to_s, :small) + 2 * BADGE_PAD, room].min
          canvas.fill(x, y, width, BADGE_HEIGHT, plate)
          canvas.text(x + BADGE_PAD, y, width - 2 * BADGE_PAD, BADGE_HEIGHT, text.to_s, :size => :small, :color => color, :cut => true)
        end

        # Draws a label on a dark band across a picture's middle.
        #
        # @param canvas [Canvas] Where it draws.
        # @param x [Integer] The picture's left in the component.
        # @param y [Integer] Its top.
        # @param width [Integer] Its width.
        # @param height [Integer] Its height.
        # @param text [String, nil] The label; nil or empty for none.
        def self.draw_label(canvas, x, y, width, height, text)
          return if text.to_s.empty?

          band = [BAND_HEIGHT, height].min
          top = y + (height - band) / 2
          canvas.fill(x, top, width, band, plate)
          canvas.text(x, top, width, band, text.to_s, :size => :small, :align => :center, :cut => true)
        end

        # Tells the color of the plates behind a badge and a label.
        #
        # @return [Color] Black at PLATE_OPACITY.
        def self.plate
          @plate ||= Color.new(0, 0, 0, PLATE_OPACITY)
        end
      end
    end

    Engine::Container.adds(:icon) { |icon, *rest| Engine::Icon.new((rest[0] || {}).merge(:icon => icon)) }
    Engine::Container.adds(:picture) { |*args| Engine::Picture.new(args[0] || {}) }
  end
end
