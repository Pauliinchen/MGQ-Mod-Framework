#----------------------------------------------------------------
#  layer_entry.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Took a shown component off the screen at once by hide(at_once: true)
#      Paulinchen  2026-11-07: Opened and showed a block of markup without a class of its own
#      Paulinchen  2026-11-06: Made the handles plain objects
#                            - Answered is_a? and the other calls every object answers from OpenHandle, ShowHandle, so a scene's variables may hold them
#      Paulinchen  2026-11-05: Closed a wheel by the hotkey its component class declares, and named it as what UI.open opens
#                            - Named a marker besides a hud as what UI.show shows
#      Paulinchen  2026-11-04: Opened or showed a component by the root its render describes, for UI.replace_window
#                            - Opened a component by the hotkey its class declares
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What a hotkey a component class declares opens: the component, with UI.open, while it is
      # not open. C#'s tree closes it by the same hotkey, so closing here does nothing.
      class HotkeyOpener
        # Makes the opener of a component class.
        #
        # @param klass [Class] The component class.
        def initialize(klass)
          @klass = klass
        end

        # Tells whether the component is open.
        #
        # @return [Boolean] Whether a top of its class is open.
        def open?
          Layer.tops.any? { |top| top.kind == :open && !top.closed && top.mount.component.instance_of?(@klass) }
        end

        # Tells why the component cannot open now.
        #
        # @return [String, nil] Why, nil when it may open.
        def refusal
          UI.busy? ? Root::BUSY_REASON : nil
        end

        # Opens the component; UI.open logs why when it does not.
        def open
          UI.open(@klass)
        end

        # Closes the component's wheel; C#'s tree closes a window or a dialog by its own hotkey
        # unless that is quiet.
        #
        # @param why [Symbol] Why it closes.
        def close(why)
          top = Layer.tops.find { |each| each.kind == :open && !each.closed && each.mount.component.instance_of?(@klass) }
          top.root.engine.close(why) if top && top.root && top.root.node.type == :wheel
          nil
        end

        # Names the component for the log.
        #
        # @return [String] Its class.
        def describe
          @klass.name.to_s
        end
      end

      # What UI.open hands back: a handle that offers only its documented methods.
      class OpenHandle
        # Makes the handle of a top.
        #
        # @param top [Layer::Top] The top.
        def initialize(top)
          @top = top
        end

        # Tells whether the window or dialog is still open.
        #
        # @return [Boolean] Whether it is.
        def open?
          !@top.closed
        end

        # Closes it; UI.open's block gets the value with the reason :script.
        #
        # @param value [Object] The result.
        # @return [nil] Always.
        def close(value = nil)
          Layer.close_top(@top, value)
          nil
        end

        # Tells its id: its id: param, or the mod and the component's class.
        #
        # @return [String] The id.
        def id
          @top.id
        end

        # Gives it the focus, as UI.open of the same id does.
        #
        # @return [nil] Always.
        def forward
          @top.root.engine.focus unless @top.closed
          nil
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.open handle #{@top.id}: open?, close(value), id, forward>"
        end
        alias_method :to_s, :inspect
      end

      # What UI.show hands back: a handle that offers only its documented methods.
      class ShowHandle
        # Makes the handle of a top.
        #
        # @param top [Layer::Top] The top.
        def initialize(top)
          @top = top
        end

        # Tells whether it is still shown.
        #
        # @return [Boolean] Whether it is.
        def shown?
          !@top.closed
        end

        # Takes it off the screen for good, after its leave motion; at_once: true takes it off in the
        # same frame, such as a box whose scene ends.
        #
        # @param options [Hash] :at_once.
        # @return [nil] Always.
        def hide(options = {})
          Layer.close_top(@top, nil, options[:at_once] == true)
          nil
        end

        # Tells its id: its id: param, or the mod and the component's class.
        #
        # @return [String] The id.
        def id
          @top.id
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.show handle #{@top.id}: shown?, hide(at_once: false), id>"
        end
        alias_method :to_s, :inspect
      end

      # The component of UI.open or UI.show given a block of markup instead of a class: the block is
      # its render, with the component as its self.
      #
      # A name the component lacks reaches the block's own self, so the mod's methods work inside as
      # they do in a UI.patch block.
      class BlockForm < UI::Component
        # The block, a param so that each call renders the block it was given.
        param :markup, content: true

        # The class of each place a block was written, by its file and line.
        @sites = {}

        # Hands out the class of the place a block was written, one per place, so the roots of two
        # places differ in their ids and the log names the place.
        #
        # @param block [Proc] The block.
        # @return [Class] The class, inside UI::Blocks.
        def self.at(block)
          file, line = block.source_location
          @sites["#{file}:#{line}"] ||= begin
            name = "At_#{File.basename(file.to_s, '.*')}_#{line}".gsub(/[^A-Za-z0-9_]/, "_")
            name = "#{name}_#{@sites.size}" if UI::Blocks.const_defined?(name, false)
            klass = UI::Blocks.const_set(name, Class.new(self))
            klass.send(:markup_name!)
            klass
          end
        end

        # Describes what the block writes.
        def render
          instance_exec(&markup)
        end

        # Hands a call the component does not know to the block's own self.
        #
        # @param name [Symbol] The method.
        # @param values [Array] Its values.
        # @return [Object] What the block's self answers.
        def method_missing(name, *values, &block)
          # Ruby asks for to_ary and to_str through method_missing, which the block's self must not
          # answer for the component.
          return super if name.to_s.start_with?("to_")

          block_self.__send__(name, *values, &block)
        end

        # Hands out a method of the block's own self for a name the component lacks, so a handler
        # named by a Symbol, such as on_click: :buy, gets as many values as that method takes.
        #
        # @param name [Symbol] The method.
        # @return [Method] The method.
        def method(name)
          super
        rescue NameError
          block_self.method(name)
        end

        private

        # Finds the block's own self, such as the mod's module whose method opened it.
        #
        # @return [Object] The block's self.
        def block_self
          @__block_self ||= markup.binding.eval("self")
        end
      end

      # The engine draws a frame after the layer rendered what changed in it.
      Tree.before_draw("ui layer") { Layer.frame }

      # F12 forgets every component of the layer.
      Run.on_reset("ui layer") { Mod_Framework::UI::Engine::Layer.reset }
    end

    # The classes of the blocks UI.open and UI.show were given, one per place in a mod's code.
    module Blocks
    end

    # Opens a component whose render describes a window, a dialog or a wheel at its top. When a root
    # of the same id is open, that one gets the focus instead.
    #
    # Without a class the block is the render instead, for a small window without state or methods
    # of its own.
    #
    # @param klass [Class, nil] The component's class, nil for a block that is the render.
    # @param params [Hash] Its params.
    # @yieldparam result [Object] What close gave, a wheel's choice taken, nil for any other close.
    # @yieldparam why [Symbol, String] Why it closed: :cancel, :button, :script, :scene, :outside or
    #   the gate's answer.
    # @return [Object, nil] Its handle (open?, close(value), id, forward), nil when it did not open;
    #   the log says why.
    def self.open(klass = nil, params = {}, &block)
      return start_component(:open, klass, params, block) unless klass.nil? && block

      start_component(:open, Engine::BlockForm.at(block), { :markup => block }, nil)
    end

    # Shows a component whose render describes a hud or a marker at its top; it never takes the keys.
    #
    # @param klass [Class, nil] The component's class, nil for a block that is the render.
    # @param params [Hash] Its params.
    # @yield The render, without a class: markup such as a hud.
    # @return [Object, nil] Its handle (shown?, hide(at_once:), id), nil when it did not show; the log says why.
    # @raise [Engine::MarkupError] It was given a class and a block.
    def self.show(klass = nil, params = {}, &block)
      return start_component(:show, Engine::BlockForm.at(block), { :markup => block }, nil) if klass.nil? && block
      raise Engine::MarkupError, Engine::Errors.placed("UI.show takes a class or a block of markup, not both", caller) if block

      start_component(:show, klass, params, nil)
    end

    # Opens or shows a component and hands out its handle.
    #
    # @param kind [Symbol] :open or :show, or :any for whichever its root needs.
    # @param klass [Class] The component's class.
    # @param params [Hash] Its params.
    # @param block [Proc, nil] UI.open's block.
    # @return [Object, nil] The handle, nil when it did not open.
    # @raise [Engine::MarkupError] It is no component class, or its params do not fit.
    def self.start_component(kind, klass, params, block)
      unless klass.is_a?(Class) && klass < Component
        raise Engine::MarkupError, Engine::Errors.placed("UI.#{kind} takes a class of UI::Component, not #{Engine::Declarations.show(klass)}", caller)
      end

      begin
        top = Engine::Layer.start(kind, klass, params, block)
      rescue Engine::MarkupError => e
        raise Engine::MarkupError, Engine::Errors.placed(e.message, caller)
      end
      return nil unless top

      top.handle ||= top.kind == :open ? Engine::OpenHandle.new(top) : Engine::ShowHandle.new(top)
    end
    private_class_method :start_component
  end
end
