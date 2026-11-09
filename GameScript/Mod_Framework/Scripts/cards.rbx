#----------------------------------------------------------------
#  cards.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The head of a card, as MudBlazor's card header: its :title, and its :subtitle under it in the
      # small dim text, left out while it has none.
      class CardHeader < Stack
        # Tells the defaults of the options: a column without gaps, no title and no subtitle.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 0, :title => "", :subtitle => nil)
        end

        options :title, :subtitle

        # Makes the column of its title and its subtitle.
        #
        # @param options [Hash] :title, :subtitle and the options of a container.
        def initialize(options = {})
          super
          @title = add(Label.new(:text => @options[:title].to_s))
          @subtitle = add(Label.new(:text => @options[:subtitle].to_s, :font_size => :small, :color => :dim, :visible => shows_subtitle?))
        end

        private

        # Follows a changed option: a new title or subtitle shows at once.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @subtitle

          @title.text = @options[:title].to_s if name == :title
          return unless name == :subtitle

          @subtitle.text = @options[:subtitle].to_s
          @subtitle.visible = shows_subtitle?
        end

        # Tells whether it has a subtitle to show.
        #
        # @return [Boolean] Whether it has.
        def shows_subtitle?
          !@options[:subtitle].to_s.empty?
        end
      end
    end
  end
end
