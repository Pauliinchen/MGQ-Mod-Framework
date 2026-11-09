#----------------------------------------------------------------
#  help_line.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed add_help of the old API
#      Paulinchen  2026-11-06: Kept the room of every line of a help line whatever its text, so the parts around it stay in place
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Kept a say made right after asking a part to take the focus until the focus leaves that part
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # A line that tells what a part does: what say said last, until the focus
      # moves (a say right after part.focus waits for the focus there and keeps until it leaves); else the :help of the part under the pointer; else the :help of the focused part or the
      # nearest part holding it. While a text field of its root types, the field's :typing_help shows.
      # A :help is a text or a block asked each frame. It wraps to at most :lines lines and keeps the
      # room of all of them whatever it tells.
      class HelpLine < Label
        # Tells the defaults of the options: two small dim lines.
        #
        # @return [Hash] The defaults.
        def self.defaults
          super.merge(:lines => 2, :wrap => true, :font_size => :small, :color => :dim)
        end

        options :lines

        # Makes the help line.
        #
        # @param options [Hash] Its options.
        def initialize(options = {})
          super(options.merge(:most_lines => options[:lines] || 2))
        end

        # Tells the properties C#'s tree lays it out by: never lower than all its lines.
        #
        # A line as high as its text moved the parts under it as the pointer crossed parts with
        # shorter help, so a button there slid away between press and release and never clicked.
        #
        # @return [Hash{String => Object}] The properties.
        def node_props
          props = super
          width, height = props["min"]
          top, _right, bottom, _left = padding_sides
          props["min"] = [width, [height.to_i, [@options[:most_lines].to_i, 1].max * line_height + top + bottom].max]
          props
        end

        # Says a text until the focus moves; after part.focus, until the focus leaves that part. nil
        # clears it.
        #
        # @param text [String, nil] The text.
        # @return [HelpLine] Itself.
        def say(text)
          @said = text
          @said_focus = Tree.asked || Tree.focused
          show(current)
          self
        end

        # Follows what it tells each frame while it shows.
        #
        # @return [Boolean] Always true, while it shows.
        def frame_tick
          show(current)
          true
        end

        # Draws its text, and follows what it tells from then on.
        #
        # @param canvas [Canvas] Where it draws.
        def draw(canvas)
          Tree.ticking(self, true)
          super
        end

        private

        # Tells what it tells now, see the class.
        #
        # @return [String] The text, empty for none.
        def current
          @said = nil if @said && !Tree.focused.equal?(@said_focus) && !(@said_focus && Tree.asked.equal?(@said_focus))
          return @said.to_s if @said

          typing = TextField.typing
          return help_of(typing, :typing_help).to_s if typing && typing.root.equal?(root) && !help_of(typing, :typing_help).nil?

          pointed = nearest_help(hovered_in(root))
          return pointed if pointed

          focused = Tree.focused
          focused && focused.root.equal?(root) ? nearest_help(focused).to_s : ""
        end

        # Shows a text, laid out anew when it changed.
        #
        # @param text [String] The text.
        def show(text)
          self.text = text unless text == @options[:text]
        end

        # Finds the part under the pointer in a component.
        #
        # @param component [Component] The component.
        # @return [Component, nil] The part, nil for none.
        def hovered_in(component)
          return component if component.hovered?

          component.children.each do |child|
            found = hovered_in(child)
            return found if found
          end
          nil
        end

        # Tells the :help of a part or of the nearest part holding it.
        #
        # @param component [Component, nil] The part.
        # @return [String, nil] The help, nil for none.
        def nearest_help(component)
          step = component
          while step
            help = help_of(step, :help)
            return help.to_s unless help.nil?

            step = step.parent
          end
          nil
        end

        # Reads a help option of a part: its text, or what its block answers.
        #
        # @param component [Component] The part.
        # @param name [Symbol] :help or :typing_help.
        # @return [String, nil] The help, nil for none.
        def help_of(component, name)
          value = component.respond_to?(name) ? component.send(name) : nil
          value.respond_to?(:call) ? value.call : value
        rescue => e
          mod_log("the #{name} of #{component.describe} failed: #{Logging.failure(e)}") if Logging.first_time?(Tree, [:help, component.class, e.class])
          nil
        end
      end
    end
  end
end
