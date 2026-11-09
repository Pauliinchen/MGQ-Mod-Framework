#----------------------------------------------------------------
#  layer_selector.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed UI.dump, leaving the selectors under a name of their own
#      Paulinchen  2026-11-04: Handed out the lines of one part, which the UI Inspector shows
#                            - Named a part a UI.patch added without an id by the key it got
#                            - Named the mod and the line of a UI.patch that set a param, and dumped the parts as the patches
#                              change them
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The selectors that name parts of the new UI layer: a type, ids and classes, inside one
      # another with a space or directly with " > ", several paths parted by commas.
      module Selector
        # One step of a path: the type, ids and classes a part must have, and whether it lies
        # directly in the part the step before names.
        class Step
          # @return [String, nil] The markup name or the component's class name, nil for any.
          attr_reader :type

          # @return [Array<Array>] Each id as [owner mod, name], the owner nil for any mod.
          attr_reader :ids

          # @return [Array<String>] The classes.
          attr_reader :classes

          # @return [Boolean] Whether it lies directly in the part the step before names.
          attr_reader :child

          # Makes a step.
          #
          # @param type [String, nil] The type.
          # @param ids [Array<Array>] The ids.
          # @param classes [Array<String>] The classes.
          # @param child [Boolean] Whether it lies directly in the part before.
          def initialize(type, ids, classes, child)
            @type = type
            @ids = ids
            @classes = classes
            @child = child
          end
        end

        # The most steps of a path, so matching stays cheap.
        MOST_STEPS = 3

        # One step written out: a type, then ids and classes.
        STEP = /\A([A-Za-z_][\w:]*)?((?:[#.][\w\/:]+)*)\z/

        # Reads a selector.
        #
        # @param text [String] The selector, such as "#camp_notes list".
        # @return [Array<Array<Step>>] Each path's steps.
        # @raise [MarkupError] It is no selector.
        def self.parse(text)
          paths = text.to_s.split(",").map { |path| path_of(path.strip, text) }
          raise MarkupError, "#{text.inspect} names no part; write a type, an #id or a .class, such as \"#camp_notes list\"" if paths.empty?

          paths
        end

        # Lists the parts of the open and shown components a selector names, each once, in the
        # order they lie.
        #
        # @param paths [Array<Array<Step>>] The selector, read.
        # @return [Array] The parts and components.
        def self.find(paths)
          found = []
          Layer.tops.each { |top| collect(top.mount, paths, found) }
          found
        end

        # Tells whether a part or a component has what a step asks for.
        #
        # @param item [Layer::Part, Layer::Mount] The part or the component.
        # @param step [Step] The step.
        # @return [Boolean] Whether it has.
        def self.fits?(item, step)
          params = item.node ? item.node.params : {}
          return false if step.type && step.type != type_name(item)
          id = item.node ? Patches.id_of(item.node) : nil
          return false unless step.ids.all? { |owner, name| Patches.same_id?(id, name) && (owner.nil? || plain(owner) == plain(Layer.mod_of(item))) }

          classes = Array(params[:class]).map { |each| each.to_s }
          step.classes.all? { |name| classes.include?(name) }
        end

        # Tells the type a selector names a part or a component by.
        #
        # @param item [Layer::Part, Layer::Mount] The part or the component.
        # @return [String] The markup name of a built-in, the class name of a component.
        def self.type_name(item)
          item.is_a?(Layer::Mount) ? item.component.class.name.to_s : item.node.type.to_s
        end

        # Reads one path.
        #
        # @param path [String] The path.
        # @param text [String] The whole selector, for the message.
        # @return [Array<Step>] Its steps.
        # @raise [MarkupError] A step is no step, or there are too many.
        def self.path_of(path, text)
          words = path.split(/\s+/)
          steps = []
          child = false
          words.each do |word|
            if word == ">"
              child = true
              next
            end
            steps << step_of(word, text, child)
            child = false
          end
          raise MarkupError, "#{text.inspect} has a path of more than #{MOST_STEPS} steps; name a nearer part by its id" if steps.size > MOST_STEPS
          raise MarkupError, "#{text.inspect} has an empty path" if steps.empty?

          steps
        end
        private_class_method :path_of

        # Reads one step.
        #
        # @param word [String] The step.
        # @param text [String] The whole selector, for the message.
        # @param child [Boolean] Whether " > " came before it.
        # @return [Step] The step.
        # @raise [MarkupError] It is no step.
        def self.step_of(word, text, child)
          match = STEP.match(word)
          raise MarkupError, "#{text.inspect}: #{word.inspect} is no step; write a type, an #id or a .class, such as list#notes" unless match && !word.empty?

          ids = []
          classes = []
          match[2].scan(/([#.])([^#.]+)/) do |mark, name|
            if mark == "#"
              owner, own = name.include?("/") ? name.split("/", 2) : [nil, name]
              ids << [owner, own]
            else
              classes << name
            end
          end
          Step.new(match[1], ids, classes, child)
        end
        private_class_method :step_of

        # Adds the parts below a part that a selector names, the part itself first.
        #
        # @param item [Layer::Part, Layer::Mount] The part or the component.
        # @param paths [Array<Array<Step>>] The selector.
        # @param found [Array] Where they go.
        def self.collect(item, paths, found)
          found << item if paths.any? { |steps| matches?(item, steps) }
          item.children.each { |child| collect(child, paths, found) }
        end
        private_class_method :collect

        # Tells whether a part is the one a path names, the parts it lies in named by the steps
        # before.
        #
        # @param item [Layer::Part, Layer::Mount] The part.
        # @param steps [Array<Step>] The path.
        # @return [Boolean] Whether it is.
        def self.matches?(item, steps)
          return false unless fits?(item, steps.last)
          return true if steps.size == 1

          rest = steps[0...-1]
          above = item.parent
          until above.nil?
            return true if matches?(above, rest)
            return false if steps.last.child

            above = above.parent
          end
          false
        end
        private_class_method :matches?

        # Writes a mod's name as the log does, so "Camp_Notes" and "Camp Notes" name one mod.
        #
        # @param name [String, nil] The name.
        # @return [String] The name with spaces.
        def self.plain(name)
          name.to_s.tr("_", " ")
        end
        private_class_method :plain
      end
    end
  end
end
