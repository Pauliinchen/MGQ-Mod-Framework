#----------------------------------------------------------------
#  expansion.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Panels under each other, each folded open and shut by its title, as MudExpansionPanels:
      # without :multi a panel that opens shuts the others.
      class ExpansionPanels < Stack
        # Tells the defaults of the options: a column of panels, several open at once.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => Style::GAP, :multi => true)
        end

        options :multi

        # Takes a panel the player opened: without :multi the others shut.
        #
        # @param panel [ExpansionPanel] The panel.
        def opened(panel)
          return if @options[:multi]

          @children.each { |child| child.shut if child.is_a?(ExpansionPanel) && !child.equal?(panel) && child.open }
        end
      end

      # One panel of ExpansionPanels: its title on a row that is a stop of the keys, a :note at the
      # title's right, and its body under it while :open. Confirm or a click on the title folds it.
      #
      # Events: fold (whether it is open now).
      class ExpansionPanel < Stack
        # What starts an open panel's title.
        OPEN_MARK = "▾ "

        # What starts a shut panel's title.
        CLOSED_MARK = "▸ "

        # Room between the title row's edge and its texts: top, right, bottom and left.
        HEAD_ROOM = [2, 4, 2, 4]

        # Room between the body's edge and its parts: top, right, bottom and left, in from the title.
        BODY_ROOM = [0, 4, 4, 16]

        # Tells the defaults of the options: shut, with no title and no note.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:layout => :column, :gap => 2, :title => "", :note => nil, :open => false)
        end

        options :title, :note, :open

        # @return [Stack] The title row.
        attr_reader :head

        # @return [Stack] The column of what it holds.
        attr_reader :body

        # Makes the panel with its title row and its body.
        #
        # @param options [Hash] :title, :note, :open and the options of a container.
        def initialize(options = {})
          super
          @head = add(Stack.new(:layout => :row, :clickable => true, :gap => Style::GAP, :padding => HEAD_ROOM))
          @title_label = @head.add(Label.new(:text => title_text, :color => :system, :shrink => true, :grow => 1))
          @note_label = @head.add(Label.new(:text => @options[:note].to_s, :font_size => :small, :color => :dim, :visible => !@options[:note].nil?))
          @head.on(:click) { fold }
          @body = add(Stack.new(:layout => :column, :gap => Style::GAP, :padding => BODY_ROOM, :visible => @options[:open] ? true : false))
        end

        # Folds it open or shut as the player did: fold tells whether it is open now, and its panels
        # shut the others as it opens.
        def fold
          self.open = !@options[:open]
          emit(:fold, @options[:open])
          parent.opened(self) if @options[:open] && parent.respond_to?(:opened)
        end

        # Shuts it as another panel opened: fold tells false.
        def shut
          self.open = false
          emit(:fold, false)
        end

        private

        # Follows a changed option: the title, its mark, the note and whether the body shows.
        #
        # @param name [Symbol] The option.
        def changed(name)
          super
          return unless @head

          case name
          when :title, :open
            @title_label.text = title_text
            @body.visible = @options[:open] ? true : false
          when :note
            @note_label.text = @options[:note].to_s
            @note_label.visible = !@options[:note].nil?
          end
        end

        # Tells the title's text: its mark, open or shut, then its title.
        #
        # @return [String] The text.
        def title_text
          (@options[:open] ? OPEN_MARK : CLOSED_MARK) + @options[:title].to_s
        end
      end
    end
  end
end
