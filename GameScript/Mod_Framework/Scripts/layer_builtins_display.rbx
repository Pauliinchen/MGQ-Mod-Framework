#----------------------------------------------------------------
#  layer_builtins_display.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Gave an avatar scale: :auto, its square following its room and its picture filling it at any factor, and sampling:
#                            - Let an avatar show a face of a face file, in a hue
#      Paulinchen  2026-11-08: Let an avatar show a character known by their map sprite alone, and
#                              told how a list cell takes an avatar
#      Paulinchen  2026-11-07: Added drawn_part, the part a UI::Drawn renders
#                            - Added timeline and timeline_item, entries in the order things happened
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer that show the game's characters and what happened in it. Like
      # layer_builtins.rbx this file loads without the game, so the tool writing docs/ui
      # reads it too.
      module Builtins
        # The sides of an avatar by the names its size: takes.
        AVATAR_SIDES = { :small => 32, :medium => 48, :large => 96 }

        # The characters an avatar names by where they stand in the party.
        PARTY_PLACES = [:party_leader, :party_member]

        # Finds the character an avatar shows: an actor, the actor of an id, the party's leader, the
        # party's member at its index, or a character known by their map sprite or a face file alone.
        #
        # @param params [Hash] The avatar's params.
        # @return [Game_Actor, RPG::Actor, Avatar::SpriteOnly, Avatar::FaceOnly, nil] The character, nil for none.
        def self.avatar_actor(params)
          face = params[:face]
          return Avatar::FaceOnly.new(face[0].to_s, face[1].to_i) if face

          character = params[:character]
          case character
          when :party_leader then $game_party && $game_party.leader
          when :party_member then $game_party && $game_party.members[params[:index].to_i]
          when Hash then Avatar::SpriteOnly.new(character[:sprite].to_s, character[:index].to_i)
          else UI.actor(character)
          end
        end

        # Turns the avatar of a list cell into the engine's: its character, picture and shape as the
        # avatar part takes them, and its box, each side its width: or height: else its size:'s side.
        #
        # @param params [Hash] The cell's avatar: the params the avatar part takes.
        # @return [Hash] The engine's avatar: :actor, :image, :shape, :hue, :width, :height and
        #   :sampling, nil unless it scales at any factor.
        def self.cell_avatar(params)
          params = Declarations[:avatar].take([params])
          side = AVATAR_SIDES[params[:size] || :medium]
          image = params[:image] || :face
          { :actor => avatar_actor(params), :image => image, :shape => params[:shape] || :circle, :hue => params[:hue].to_i,
            :width => params[:width].is_a?(Integer) ? params[:width] : side, :height => params[:height].is_a?(Integer) ? params[:height] : side,
            :sampling => params[:scale] == :auto ? Avatar.sampling_for(image, params[:sampling]) : nil }
        end

        Declarations.define(:avatar,
                            :summary => "A character's picture in a circle or a square, as MudBlazor's avatar: the face or the map sprite of an actor, of the party's leader or of a member, or a face of a face file.",
                            :one_of => [[:character, :face]],
                            :params => { :character => { :doc => "who it shows: an actor, a database actor (RPG::Actor), an actor's id, :party_leader, :party_member with index:, " \
                                                                 "or a map sprite by its file and place, such as { sprite: \"Main01_cip\", index: 0 }; the party's places follow the party as it changes; it or face: is needed" },
                                         :face => { :type => :face_file,
                                                    :doc => "a face of a face file in Graphics/Faces instead of a character, by the file and its place in it, as a message names its speaker's face by $game_message.face_name and face_index" },
                                         :hue => { :type => :int, :default => 0, :doc => "the hue a face draws in, from 0 to 359, as the game draws a face in a hue; 0 its own colors" },
                                         :index => { :type => :int, :default => 0, :doc => "with character: :party_member, the member's place in the party, 0 the leader" },
                                         :image => { :values => [:face, :sprite], :default => :face,
                                                     :doc => ":face shows the face portrait, :sprite the map sprite standing and facing down; a character without that picture shows the plate alone" },
                                         :shape => { :values => [:circle, :box], :default => :circle,
                                                     :doc => "a circle or a square; in a square a face shrinks whole in one smooth stretch, as the game's windows shrink a face, in a circle row by row" },
                                         :size => { :values => AVATAR_SIDES.keys, :default => :medium, :doc => "its side: :small 32 px, :medium 48 px, :large 96 px, the face's own" },
                                         :scale => { :values => [:auto],
                                                     :doc => ":auto scales it to the room it gets: its square follows the width it gets, such as a grid item's, and its picture fills the square " \
                                                             "at any size, larger or smaller, keeping its proportions; without it a sprite scales by whole steps" },
                                         :sampling => { :values => [:sharp, :smooth],
                                                        :doc => "with scale: :auto, how its pixels scale: :sharp takes each pixel's nearest pixel, so pixel art stays crisp, :smooth blends them; " \
                                                                ":sharp for a sprite, :smooth for a face" } },
                            :events => { :click => "nothing; it was clicked" },
                            :keys => "none", :mouse => "a click tells on_click",
                            :make => lambda { |options| Avatar.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:actor => avatar_actor(params), :image => params[:image] || :face, :shape => params[:shape] || :circle,
                                                   :side => AVATAR_SIDES[params[:size] || :medium], :hue => params[:hue].to_i, :auto_scale => params[:scale] == :auto,
                                                   :sampling => params[:sampling])
                            end,
                            :reads => lambda do |params|
                              actor = avatar_actor(params)
                              (PARTY_PLACES.include?(params[:character]) ? [[:party, nil]] : []) + (actor ? [[:level, actor]] : [])
                            end,
                            :wire => lambda { |part| wire_click(part) })

        Declarations.define(:timeline,
                            :summary => "Entries under each other in the order things happened, as MudBlazor's timeline, such as the story's chapters or the jobs unlocked: each a dot on a line, a title and a text.",
                            :content => true,
                            :make => lambda { |options| Timeline.new(options) },
                            :options => lambda { |params| common(params) },
                            :synced => lambda { |part| part.engine.redraw_marks })

        Declarations.define(:timeline_item,
                            :summary => "One entry of a timeline: a dot, its title and a text under it.", :args => [:title], :inside => [:timeline],
                            :params => { :title => { :kind => :live, :type => :text, :doc => "what happened, such as \"Left Iliasville\"" },
                                         :text => { :kind => :live, :type => :text, :doc => "more about it, in small text under the title" },
                                         :color => { :type => :color, :doc => "the dot's color; the theme's primary color by default" } },
                            :keys => "none", :mouse => "none",
                            :make => lambda { |options| TimelineItem.new(options) },
                            :options => lambda do |params|
                              common(params).merge(:title => params[:title].to_s, :text => params[:text] && params[:text].to_s, :color => color(params[:color]) || :primary)
                            end,
                            :sync => lambda { |_part, _wanted| nil })

        # Tells the engine's options of the part a UI::Drawn renders: its role, and a :slider's
        # places and place, read from the component as it renders.
        #
        # @param params [Hash] The part's params.
        # @return [Hash] The options.
        def self.drawn_options(params)
          drawn = params[:drawn]
          role = drawn.role
          unless UI::Drawn::ROLES.include?(role)
            Errors.hint([:drawn_role, drawn.class], nil, "#{drawn.class} tells the role #{role.inspect}; it takes #{UI::Drawn::ROLES.map { |each| each.inspect }.join(', ')}, so it takes none")
            role = :none
          end
          slider = role == :slider
          common(params).merge(:drawn => drawn, :role => role, :places => slider ? drawn.places : 0, :place => slider ? drawn.place : 0)
        end

        # Runs a method of a UI::Drawn that C#'s tree asked for, logging one that fails once.
        #
        # @param drawn [UI::Drawn] The component.
        # @param name [Symbol] The method, :pressed or :moved.
        # @param values [Array] Its values.
        def self.call_drawn(drawn, name, *values)
          drawn.__send__(name, *values)
        rescue StandardError => e
          Errors.report(e, "the #{name} of #{drawn.class}")
        end

        Declarations.define(:drawn_part,
                            :summary => "The part a UI::Drawn renders, which measures and draws through it.", :hidden => true,
                            :params => { :drawn => { :required => true, :doc => "the component" } },
                            :make => lambda { |options| DrawnPart.new(options) },
                            :options => lambda { |params| drawn_options(params) },
                            :wire => lambda do |part|
                              part.engine.on(:click) { call_drawn(part.engine.drawn, :pressed) if part.engine.role == :button }
                              part.engine.on(:move) { |place| call_drawn(part.engine.drawn, :moved, place.to_i) if part.engine.role == :slider }
                            end,
                            :synced => lambda { |part| part.engine.refresh })
      end
    end
  end
end
