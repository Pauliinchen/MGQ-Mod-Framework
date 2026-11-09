#----------------------------------------------------------------
#  avatars.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Kept the picture scaled at any factor with the part that draws it, by the picture's name
#                            - Scaled the picture to its square at any factor with :auto_scale, its pixels sharp or smooth, the square following the width it gets
#                            - Showed a face from a face file in a hue, and shrank a face in a square in one smooth stretch
#                            - Drew an avatar's plate in its background, none for false
#      Paulinchen  2026-11-08: Showed the plate alone for a picture file the game does not have
#                            - Drew an avatar into any box of a canvas, so a list cell draws one too
#                            - Showed the map sprite of a character known by its sprite alone
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A character's picture in a square of :side pixels, as MudBlazor's avatar: the face (:image
      # => :face) or the map sprite standing and facing down (:sprite), on a plate in the theme's
      # well color, cut to a circle (:shape => :circle) or a square (:box). A face fills the square, in
      # its :hue; a sprite scales by whole steps so its pixels stay sharp and stands on the plate's
      # middle. With :auto_scale its square follows the width it gets in C#'s tree and the picture
      # fills it at any factor, its pixels as :sampling tells (Scaled). A character without the picture
      # asked for, such as one known by the sprite alone asked for its face or one whose picture file
      # the game does not have, shows the plate alone.
      class Avatar < Component
        include StateBlind

        # The component's kind in C#'s tree.
        KIND = "picture"

        # The pictures it shows of a character.
        IMAGES = [:face, :sprite]

        # The shapes it is cut to.
        SHAPES = [:circle, :box]

        # A character known only by their map sprite, such as another player's leader.
        SpriteOnly = Struct.new(:character_name, :character_index)

        # A character known only by a face in a face file, such as a speaker of a battle line.
        FaceOnly = Struct.new(:face_name, :face_index)

        # The most faces kept blitted whole for the stretch into a square.
        FACES_KEPT = 8

        # Tells the defaults of the options: no character, a face in its own colors in a circle of 48
        # pixels.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:actor => nil, :image => :face, :shape => :circle, :side => 48, :hue => 0, :auto_scale => false, :sampling => nil)
        end

        # Tells which properties of C#'s tree each option sets: its side measures anew, and
        # :auto_scale keeps it square.
        #
        # @return [Hash{Symbol => Array<String>}] The properties by option.
        def self.node_keys
          super.merge(:side => ["measured"], :auto_scale => ["aspect"])
        end

        options :actor, :image, :shape, :side, :hue, :auto_scale, :sampling

        # Tells how the pixels of a picture scaled to its square at any factor scale: as given, else
        # sharp for a sprite and smooth for a face.
        #
        # @param image [Symbol] :face or :sprite.
        # @param given [Symbol, nil] The sampling asked for, nil for the default.
        # @return [Symbol] :sharp or :smooth.
        def self.sampling_for(image, given)
          return UI.choice(given, Scaled::SAMPLINGS, :smooth, "sampling").to_sym unless given.nil?

          image.to_s == "sprite" ? :sharp : :smooth
        end

        # Tells the spans of each row of a shape in a square: the whole row for a box, the part
        # inside the circle for a circle.
        #
        # @param shape [Symbol] :circle or :box.
        # @param side [Integer] The square's side.
        # @return [Array<Array<Integer>>] Each row's left and width.
        def self.rows(shape, side)
          return Array.new(side) { [0, side] } unless shape == :circle

          radius = side / 2.0
          Array.new(side) do |row|
            middle = row + 0.5 - radius
            left = (radius - Math.sqrt([radius * radius - middle * middle, 0].max)).round
            [left, side - 2 * left]
          end
        end

        # Draws a character's avatar in the middle of a box: its plate in its shape, a square of the
        # box's shorter side, and over it the character's picture cut to that shape; a face in a
        # square shrinks whole in one stretch, as the game's windows shrink a face. With a sampling the
        # picture fills the square at any factor instead.
        #
        # @param canvas [Canvas] Where it draws.
        # @param box [Array<Integer>] The box's left, top, width and height.
        # @param actor [Object, nil] The character: anything with a map sprite or a face, or both.
        # @param image [Symbol] :face or :sprite.
        # @param shape [Symbol] :circle or :box.
        # @param plate [Object] The plate's color, see Canvas#color; nil or false for none.
        # @param hue [Integer] The hue a face draws in, 0 for its own colors.
        # @param sampling [Symbol, nil] :sharp or :smooth to scale the picture at any factor, nil to
        #   scale a sprite by whole steps.
        # @param copies [Scaled::Copies, nil] Where the part that draws it keeps the picture scaled at
        #   any factor; needed with a sampling.
        def self.paint(canvas, box, actor, image, shape, plate = :well, hue = 0, sampling = nil, copies = nil)
          x, y, width, height = box
          side = [width, height].min
          return if side <= 0

          left = x + (width - side) / 2
          top = y + (height - side) / 2
          shape = UI.choice(shape, SHAPES, :circle, "shape").to_sym
          rows = Avatar.rows(shape, side)
          canvas.spans(left, top, rows.map { |span| [span] }, plate) if plate
          sprite = UI.choice(image, IMAGES, :face, "image").to_sym == :sprite
          found = picture(actor, sprite, hue)
          return unless found

          scaled = sampling && copies && copies.picture(Scaled.name_of(UI.actor(actor), sprite ? :figure : :face, hue), found, [side, side], :contain, sampling)
          return paint_scaled(canvas, scaled, shape == :box, rows, [left, top, side]) if scaled
          return canvas.picture(whole_face(found[0], found[1]), left, top, side, side) if shape == :box && !sprite

          draw_rows(canvas, found[0], found[1], spot(found, side), rows, left, top)
        end

        # Draws the picture scaled to fill the square at any factor, standing on its middle, whole in
        # a square and row by row in a circle.
        #
        # @param canvas [Canvas] Where it draws.
        # @param scaled [Bitmap] The picture scaled.
        # @param box [Boolean] Whether the shape is a square.
        # @param rows [Array<Array<Integer>>] The shape's span of each row.
        # @param square [Array<Integer>] The square's left, top and side on the canvas.
        def self.paint_scaled(canvas, scaled, box, rows, square)
          left, top, side = square
          x = (side - scaled.width) / 2
          y = (side - scaled.height) / 2
          if box
            canvas.picture(scaled, left + x, top + y, scaled.width, scaled.height)
          else
            draw_rows(canvas, scaled, scaled.rect, [x, y, scaled.width, scaled.height], rows, left, top)
          end
        end

        # Finds a character's picture: the face sheet and the face, or the sprite sheet and the
        # standing figure.
        #
        # A sprite another player's game names may be a mod's that this game does not have.
        #
        # @param actor [Object, Integer, nil] The character, or an actor's id.
        # @param sprite [Boolean] Whether the map sprite shows, else the face.
        # @param hue [Integer] The hue a face draws in.
        # @return [Array, nil] The sheet and the part of it; nil without a character or a picture,
        #   and for a picture file the game does not have, which is logged once per file.
        def self.picture(actor, sprite, hue)
          actor = UI.actor(actor)
          return nil unless actor

          begin
            return Figure.of(actor) if sprite

            actor.respond_to?(:face_name) ? Picture.face(actor, hue) : nil
          rescue Errno::ENOENT
            file = sprite ? "Graphics/Characters/#{actor.character_name}" : "Graphics/Faces/#{actor.face_name}"
            Tree.log_once([:avatar_file, file], "the avatar picture #{file} is not in the game; the avatar shows its plate alone")
            nil
          end
        end

        # Tells where the picture draws in the square: a face over all of it, a sprite scaled by
        # whole steps, standing on the middle.
        #
        # @param found [Array] The sheet and the part of it.
        # @param side [Integer] The square's side.
        # @return [Array<Integer>] Its left, top, width and height in the square.
        def self.spot(found, side)
          part = found[1]
          return [0, 0, side, side] if part.width == part.height

          factor = [side / part.width.to_f, side / part.height.to_f].min
          factor = factor.floor if factor >= 1
          width = (part.width * factor).round
          height = (part.height * factor).round
          [(side - width) / 2, (side - height) / 2, width, height]
        end

        # Draws the picture row by row, each row cut to the shape's span there.
        #
        # @param canvas [Canvas] Where it draws.
        # @param sheet [Bitmap] The picture's sheet.
        # @param part [Rect] The part of the sheet.
        # @param drawn [Array<Integer>] Where the picture draws in the square, as spot tells it.
        # @param rows [Array<Array<Integer>>] The shape's span of each row.
        # @param left [Integer] The square's left on the canvas.
        # @param top [Integer] Its top.
        def self.draw_rows(canvas, sheet, part, drawn, rows, left, top)
          x, y, width, height = drawn
          across = part.width / width.to_f
          down = part.height / height.to_f
          (y...(y + height)).each do |row|
            span_left, span_width = rows[row]
            from = [span_left, x].max
            to = [span_left + span_width, x + width].min
            next if to <= from

            cut = Rect.new(part.x + ((from - x) * across).floor, part.y + ((row - y) * down).floor, [((to - from) * across).round, 1].max, [down.round, 1].max)
            canvas.picture(sheet, left + from, top + row, to - from, 1, cut)
          end
        end

        # Hands out a face blitted whole onto a picture of its own, as the game's draw_face_hue draws
        # it, kept for the next draws.
        #
        # A stretch straight from the face sheet blends in pixels of the faces beside it at the edges.
        #
        # @param sheet [Bitmap] The face sheet.
        # @param part [Rect] The face's rectangle in it.
        # @return [Bitmap] The face alone.
        def self.whole_face(sheet, part)
          @faces ||= []
          kept = @faces.find { |each| each[0].equal?(sheet) && each[1] == [part.x, part.y] && !each[2].disposed? }
          return kept[2] if kept

          @faces.shift[2].dispose if @faces.size >= FACES_KEPT
          face = Bitmap.new(part.width, part.height)
          face.blt(0, 0, sheet, part)
          @faces << [sheet, [part.x, part.y], face]
          face
        end

        private_class_method :paint_scaled, :picture, :spot, :draw_rows, :whole_face

        # Tells its size: a square of its side.
        #
        # @return [Array<Integer>] Its width and height.
        def measure
          side = UI.whole(@options[:side])
          [side, side]
        end

        # Draws its plate in its shape, in its background, the theme's well by default, and over it the
        # character's picture cut to that shape, with :auto_scale filling it at any factor.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          sampling = @options[:auto_scale] ? Avatar.sampling_for(@options[:image], @options[:sampling]) : nil
          @copies ||= Scaled::Copies.new(true)
          Avatar.paint(canvas, [0, 0, canvas.width, canvas.height], @options[:actor], @options[:image], @options[:shape], plate_color, @options[:hue].to_i, sampling, @copies)
        end

        # Frees its pictures and its scaled copy.
        def release_surfaces
          super
          @copies.dispose if @copies
        end

        # Tells the properties of C#'s tree: with :auto_scale it keeps square.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          props["aspect"] = @options[:auto_scale] ? true : false
          props
        end

        private

        # Tells its plate's color: its background's, the theme's back for :theme, the theme's well
        # without a background; false for none.
        #
        # @return [Object] The color.
        def plate_color
          plate = @options[:background]
          plate = plate[:color] if plate.is_a?(Hash)
          return :well if plate.nil?

          plate == :theme ? :back : plate
        end

        # Tells that it draws its background itself, as its plate in its shape.
        #
        # @return [Boolean] Always true.
        def own_back?
          true
        end
      end
    end
  end
end
