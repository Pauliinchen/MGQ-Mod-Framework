#----------------------------------------------------------------
#  layer_builtins_hud.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Gave progress border:, a line of one pixel around it in a color of its own or a shade of its fill
#                            - Took a progress bar's border: from the params every built-in takes and removed framed:, which border: :theme,
#                              border_width: 2 draws
#                            - Took a marker's margin: from the params every built-in takes, each side its own
#      Paulinchen  2026-11-07: Wrote the plain text of a bubble in the plain text color unless it has contrast
#      Paulinchen  2026-11-06: Removed the params no mod gave: an arrow's angle: and triangle:, and follow_gap: of a bubble
#                            - Checked a progress bar's text as a text or an Array of ever shorter texts
#      Paulinchen  2026-11-05: Added bubble, a speech bubble that follows a map character and holds any parts
#                            - Added arrow, a triangle pointing along an angle, and marker, an arrow at the screen's edge
#                              toward a character or a tile off the screen
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The built-ins of the UI layer that HUDs over the map are made of: a bar of a live value, an
      # arrow, a marker at the screen's edge toward what lies off it, and a speech bubble over a
      # character. Like layer_builtins.rbx
      # this file loads without the game, so the tool writing docs/ui reads it too.
      module Builtins
        # The height of a progress bar without a text and the font of its texts, by its size:.
        PROGRESS_SIZES = { :small => [4, :tiny], :medium => [8, :small], :large => [12, :normal] }

        # Tells how full a progress bar is: its value between its min and its max.
        #
        # @param params [Hash] The params, live values read.
        # @return [Float] From 0 to 1.
        def self.progress_rate(params)
          low = (params[:min] || 0).to_f
          high = (params[:max] || 100).to_f
          return 0.0 if high <= low

          [[(params[:value].to_f - low) / (high - low), 0.0].max, 1.0].min
        end

        # Turns a progress bar's params into the engine's options: a gauge filled to its rate, its
        # colors, its texts in the font of its size and, without texts, the height of its size.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.progress(params)
          options = common(params).merge(:rate => progress_rate(params), :trail => params[:trail] == true, :vertical => params[:vertical] == true,
                                         :indeterminate => params[:indeterminate] == true)
          colors = params[:colors] || (params[:color] && [params[:color]])
          options[:colors] = colors.map { |each| color(each) } if colors
          options[:label] = params[:label].to_s unless params[:label].nil?
          options[:value] = params[:value_text].to_s unless params[:value_text].nil?
          text = params[:text]
          options[:text] = text.is_a?(Array) ? text.map { |each| each.to_s } : text.to_s unless text.nil?
          height, font = PROGRESS_SIZES[params[:size]]
          options[:font_size] = font if font
          texts = [params[:label], params[:value_text]] + Array(text)
          options[:height] = height if height && !options[:height] && texts.all? { |each| each.to_s.empty? }
          options
        end

        Declarations.define(:progress,
                            :summary => "A bar of a value between a least and a most, such as a character's HP, with a text at its left, its value " \
                                        "at its right and a text in its middle; what it just lost can drain away.",
                            :params => { :value => { :kind => :live, :doc => "how far it is, between min: and max:; its fill drains down as it falls, a rise shows at once" },
                                         :min => { :default => 0, :doc => "the value of an empty bar" },
                                         :max => { :default => 100, :doc => "the value of a full bar" },
                                         :color => { :kind => :live, :type => :color, :doc => "its fill's color; the theme's primary color by default" },
                                         :colors => { :type => :array, :doc => "two colors its fill runs between from left to right, or with vertical: true two or three from top to bottom" },
                                         :size => { :values => PROGRESS_SIZES.keys,
                                                    :doc => "the font of its texts, tiny, small or normal, and without texts its height, 4, 8 or 12 pixels; without size: 12 pixels and the small font" },
                                         :label => { :kind => :live, :type => :text, :doc => "a text inside it at its left, such as \"HP\"" },
                                         :value_text => { :kind => :live, :type => :text, :doc => "a text inside it at its right, such as \"189 / 252\"" },
                                         :text => { :kind => :live, :type => :texts, :doc => "a text in its middle, or an Array of ever shorter texts of which the first that fits shows" },
                                         :trail => { :type => :bool, :default => false,
                                                     :doc => "what the value lost in the last two seconds stays in a darker shade, then drains away; a rise shows at once" },
                                         :vertical => { :type => :bool, :default => false, :doc => "its colors: run from top to bottom" },
                                         :indeterminate => { :type => :bool, :default => false,
                                                             :doc => "a stripe sweeps along it in place of a value, for a wait whose length nobody knows" } },
                            :keys => "none", :mouse => "none; its tooltip: shows on hover",
                            :make => lambda { |options| Gauge.new(options) },
                            :options => lambda { |params| progress(params) })

        Declarations.define(:arrow,
                            :summary => "A filled triangle with a dark outline that points right.",
                            :params => { :color => { :kind => :live, :type => :color, :doc => "its fill's color; the theme's text color by default" } },
                            :keys => "none", :mouse => "none; its tooltip: shows on hover",
                            :make => lambda { |options| Arrow.new(options) },
                            :options => lambda { |params| common(params).merge(:color => color(params[:color]) || :text) })

        # The units of 4 px a marker keeps from the screen's edge unless its margin: says otherwise.
        MARGIN = 3.5

        Declarations.define(:marker,
                            :summary => "An arrow at the screen's edge that points at a map character or a tile while it lies off the screen, with a text " \
                                        "on a plate beside it, such as where a party member went; it fades out once that comes onto the screen. " \
                                        "UI.show shows a component whose top part is one.",
                            :root => :show,
                            :params => { :target => { :kind => :live, :type => :map_spot, :required => true,
                                                      :doc => "what it points at; it hides while that is gone, see-through or on another map" },
                                         :text => { :kind => :live, :type => :text, :doc => "on a plate inside the screen beside the arrow, such as \"Inn 12\"" },
                                         :color => { :kind => :live, :type => :color, :doc => "the arrow's color; the theme's text color by default" },
                                         :from => { :type => :character, :default => :player, :doc => "where the line toward the target starts, which the arrow follows" },
                                         :hide_while => { :type => :while, :doc => "asked every frame: while it answers true it fades out without closing; :top_message hides it while the game's message shows at the top of the screen" },
                                         :if => ROOT[:if],
                                         :z => { :type => :int, :doc => "which marker or hud lies above which under the game's windows, 0 by default, under the huds" } },
                            :events => ROOT_EVENTS, :keys => "none", :mouse => "none: the pointer passes through it",
                            :make => lambda { |options| Marker.new(options) },
                            :options => lambda do |params|
                              options = common(params).merge(:target => params[:target], :text => params[:text].to_s, :color => color(params[:color]) || :text,
                                                             :from => params[:from] || :player, :margin => sides(params[:margin] || MARGIN), :hide_while => hiding(params[:hide_while]),
                                                             :under_windows => true, :keep => true, :hidden_in => hud_scenes, :layer => true,
                                                             :z => UI.within(Z[:arrows] + params[:z].to_i, BANDS[:hud].first, BANDS[:hud].last))
                              options[:if] = params[:if] if params[:if]
                              options
                            end,
                            :wire => lambda { |part| wire_root(part) })

        # Turns a bubble's params into the engine's options: a speech bubble that follows its
        # character in the map's band, fading in and out, never taking the keys or the pointer.
        #
        # @param params [Hash] The params, live values read.
        # @return [Hash] The options.
        def self.bubble(params)
          options = common(params).merge(:follow => params[:follow], :side => FOLLOW_SIDES[params[:side] || :top],
                                         :flip => params[:flip] == true, :on_screen => params[:on_screen] == true,
                                         :seconds => params[:seconds].nil? ? nil : params[:seconds].to_f, :hide_while => hiding(params[:hide_while]),
                                         :keep => true, :hidden_in => hud_scenes, :layer => true, :aside => true, :at => [0, 0], :fade => true,
                                         :z => UI.within(Z[:bubbles] + params[:z].to_i, BANDS[:map].first, BANDS[:map].last))
          options[:if] = params[:if] if params[:if]
          options[:color] = color(params[:color]) if params[:color]
          options
        end

        Declarations.define(:bubble,
                            :summary => "A speech bubble that follows a map character and holds any parts, such as a line, a face or a bar. UI.show shows a component whose top part is one.",
                            :root => :show, :content => true,
                            :params => { :follow => { :type => :character, :required => true,
                                                      :doc => "the map character it lies beside, above the map's pictures; it hides while the character is gone, see-through or on another map, and shows over a CG; bubbles over one tile stack upward in the order they opened" },
                                         :side => FOLLOW[:side], :flip => FOLLOW[:flip], :on_screen => FOLLOW[:on_screen],
                                         :color => { :type => :color, :doc => "its fill; white by default" },
                                         :seconds => { :doc => "the seconds of real time it shows, counted while the game is in front; then it closes with :script; without it, it shows until hidden" },
                                         :hide_while => { :type => :while, :doc => "asked every frame: while it answers true it fades out without closing; :top_message hides it while the game's message shows at the top of the screen" },
                                         :if => ROOT[:if],
                                         :z => { :type => :int, :doc => "which bubble lies above which among the parts that follow characters, 0 by default" } },
                            :events => ROOT_EVENTS, :keys => "none", :mouse => "none: the pointer passes through it",
                            :make => lambda { |options| Bubble.new(options) },
                            :options => lambda { |params| bubble(params) },
                            :wire => lambda { |part| wire_root(part) })
      end
    end
  end
end
