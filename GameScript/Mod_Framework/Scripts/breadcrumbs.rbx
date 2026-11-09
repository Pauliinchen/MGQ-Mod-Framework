#----------------------------------------------------------------
#  breadcrumbs.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Kept the room of a link around the place shown, so each separator has the same room on both sides
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The way to the place shown, as MudBreadcrumbs: a row of links between separators, each a
      # button with only its text that confirm or a click follows, and the last, the place shown,
      # as dim text that takes no focus, with the room a link keeps around its text, so every
      # separator has the same room on both sides.
      #
      # An item is a Hash of :text, :data (what a click tells, its text without it), :icon,
      # :disabled (true greys a link out) and :tooltip.
      #
      # Events: click (the data of the link followed).
      class Breadcrumbs < Stack
        # Tells the defaults of the options: a row of no items between slashes.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :row, :gap => Style::GAP, :items => [], :separator => "/")
        end

        options :items, :separator

        # Makes the row with a link for each item but the last.
        #
        # @param options [Hash] :items, :separator and the options of a container.
        def initialize(options = {})
          super
          build
        end

        private

        # Follows a changed option: new items or a new separator make the row anew.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          build if (name == :items || name == :separator) && @built
        end

        # Makes the links, the separators between them and the text of the place shown.
        def build
          @built = true
          clear
          items = Array(@options[:items])
          items.each_with_index do |item, place|
            add(Label.new(:text => @options[:separator].to_s, :color => :dim, :align => :center)) if place > 0
            text = item[:text].to_s
            if place == items.size - 1
              room = [Button::PAD_Y, Button::PAD_X, Button::PAD_Y, Button::PAD_X]
              add(Label.new(:text => text, :icon => item[:icon], :color => :dim, :align => :center, :tooltip => item[:tooltip], :padding => room))
            else
              add_link(text, item)
            end
          end
        end

        # Adds the link of an item, which tells its data as it is followed.
        #
        # @param text [String] Its text.
        # @param item [Hash] The item.
        def add_link(text, item)
          link = add(Button.new(:text => text, :icon => item[:icon], :variant => :text, :acts => true, :enabled => item[:disabled] != true,
                                :tooltip => item[:tooltip], :align => :center))
          data = item.key?(:data) ? item[:data] : text
          link.on(:click) { emit(:click, data) }
        end
      end
    end
  end
end
