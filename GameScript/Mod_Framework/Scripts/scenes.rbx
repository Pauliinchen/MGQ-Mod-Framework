#----------------------------------------------------------------
#  scenes.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Removed the old replace_scene with a block; UI.replace_scene opens a component
#      Paulinchen  2026-11-06: Forgot a root waiting for its menu scene once it closes
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Told whether a root waits for its menu scene
#                            - Logged each component opened in place of a scene, with the character it opens for
#      Paulinchen  2026-11-04: Opened a component of the UI layer in place of a scene, with the params a lambda of the
#                              stand-in scene answers
#                            - Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-11-01: Closed a root waiting for its menu scene with :scene once another scene took that scene's place
#                            - Told close for a root whose menu scene failed to start or whose open failed there
#                            - Refused a root with :menu while another waited for its menu scene, and forgot the waiting one on F12
#                            - Told a mod whether the scene now is the menu scene of a mod's screen
#      Paulinchen  2026-10-31: Opened a root of a mod in a menu scene of its own outside a menu scene
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The game's scenes a mod replaces with a component of its own, such as its own equip window in
      # place of Scene_Equip: while a replacement's condition holds, SceneManager.call and goto of the
      # replaced scene go to a stand-in menu scene instead, which opens the mod's component over the
      # menu's background for the character the menu picked, and goes back where the replaced scene
      # would have gone once the component closes. Every caller of the scene is covered, the game's menu, its
      # events and other mods alike. One replacement per scene; a later one takes its place.
      module Scenes
        # Who wraps SceneManager, for the hooks.
        TAG = "Mod Framework scenes"

        # The replacements by the scene they replace: the condition, the component and its params,
        # the stand-in scene class and the mod's file.
        @replaced = {}

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "scenes"

        # A stand-in scene: the game's menu scene, which opens the replacement's component as it starts
        # and returns from the scene once it closes. A component that does not open returns at once.
        module StandIn
          # @return [Game_Actor, nil] The character the menu picked.
          attr_reader :actor

          # Starts the scene: the menu's background and character, then the replacement's component.
          # The scene keeps no handle of a component in a variable of its own, since the game walks
          # the scene's variables as windows and a handle answers nothing but its own calls.
          def start
            super
            handle = Scenes.open_for(self.class, @actor, self)
            return_scene unless handle && handle.open?
          end
        end

        # The framework's own menu scene for a root of a mod with :menu, opened outside a menu scene:
        # the game's blurred menu background with the map waiting behind it, the root over it, and
        # back to the scene before once the root closes. A root that does not open goes back at once.
        module MenuRoot
          # @return [Component, nil] The root it opened.
          attr_reader :menu_root

          # Starts the scene: the menu's background, then the root waiting for it.
          def start
            super
            @menu_root = Scenes.take_waiting
            Scenes.open_waiting(@menu_root) if @menu_root
            return_scene unless @menu_root && @menu_root.open?
          end
        end

        # Why a root waiting for its menu scene closes when its open fails there.
        OPEN_FAILED = "its open failed"

        # Why a root with :menu does not open while another waits for its menu scene.
        ANOTHER_WAITING = "another window waits for its menu scene"

        # The root waiting for the menu scene, nil for none.
        @waiting = nil

        # Opens a root in the framework's menu scene, which the game calls now.
        #
        # @param root [Component] The root.
        # @return [Component] The root, which opens as the scene starts.
        def self.open_in_menu(root)
          return root unless defined?(::SceneManager) && defined?(::Scene_MenuBase)
          return root if @waiting.equal?(root)
          return refuse_waiting(root) if @waiting

          @waiting = root
          @menu_scene ||= Class.new(::Scene_MenuBase) { include MenuRoot }
          ::SceneManager.call(@menu_scene)
          log("#{root.describe} opens in a menu scene of its own")
          root
        rescue => e
          @waiting = nil
          log("calling the menu scene of #{root.describe} FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          root.not_opened(OPEN_FAILED)
        end

        # Refuses a root with :menu while another waits for its menu scene, which takes that scene,
        # and tells it close with why.
        #
        # @param root [Component] The root refused.
        # @return [Component] The root.
        def self.refuse_waiting(root)
          log("#{root.describe} did not open: #{ANOTHER_WAITING}, #{@waiting.describe}")
          root.not_opened(ANOTHER_WAITING)
        end
        private_class_method :refuse_waiting

        # Forgets the root waiting for the menu scene as F12 starts the game's scenes again.
        #
        # @return [Array<Component>] The root that waited, for its close blocks; empty for none.
        def self.reset
          root = take_waiting
          root ? [root] : []
        end

        # Opens the root that waited for the menu scene, telling close when its open fails.
        #
        # @param root [Component] The root.
        def self.open_waiting(root)
          root.open
        rescue => e
          log("opening #{root.describe} in its menu scene FAILED: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          root.not_opened(OPEN_FAILED)
        end

        # Closes the root waiting for the menu scene with :scene once a scene ends and another scene
        # than that menu scene comes next, which took its place. Called after every Scene_Base#terminate.
        def self.scene_ended
          root = @waiting
          return unless root && !::SceneManager.scene.is_a?(@menu_scene)

          @waiting = nil
          log("#{::SceneManager.scene.class} took the place of the menu scene of #{root.describe}")
          root.not_opened(:scene)
        end

        # Tells whether a root waits for the menu scene the game calls for it.
        #
        # @param root [Component] The root.
        # @return [Boolean] Whether it does.
        def self.waiting?(root)
          !@waiting.nil? && @waiting.equal?(root)
        end

        # Forgets a root waiting for the menu scene as it closes before that scene starts, which then
        # goes back at once.
        #
        # @param root [Component] The root.
        # @return [Boolean] Whether it waited.
        def self.cancel_waiting(root)
          return false unless waiting?(root)

          @waiting = nil
          log("#{root.describe} closed before its menu scene started")
          true
        end

        # Hands out the root waiting for the menu scene, once.
        #
        # @return [Component, nil] The root.
        def self.take_waiting
          root = @waiting
          @waiting = nil
          root
        end

        # Goes back to the scene before once a root the menu scene opened closes.
        #
        # @param root [Component] The root.
        def self.root_closed(root)
          scene = defined?(::SceneManager) ? ::SceneManager.scene : nil
          scene.return_scene if UI.menu_screen?(scene) && scene.menu_root.equal?(root)
        end

        # Tells whether the scene now is a menu scene, where a root with :menu opens in place.
        #
        # @return [Boolean] Whether it is.
        def self.menu_scene?
          defined?(::Scene_MenuBase) && defined?(::SceneManager) && ::SceneManager.scene.is_a?(::Scene_MenuBase) ? true : false
        end

        # Replaces a game scene with a component of a mod, see the module.
        #
        # @param scene_class [Class] The scene, such as Scene_Equip.
        # @param options [Hash] :if (a lambda that tells whether the replacement holds now, such as
        #   by an option row; always without one), :component (the component UI.open opens) and
        #   :params (a lambda of the stand-in scene answering the component's params).
        # @return [Class, nil] The stand-in scene's class, nil without SceneManager.
        def self.replace(scene_class, options)
          return nil unless install

          mod = mod_file(caller)
          old = @replaced[scene_class]
          log("#{mod} replaces #{scene_class}, which #{old[:mod]} replaced before") if old
          stand_in = Class.new(::Scene_MenuBase) { include StandIn }
          @replaced[scene_class] = { :if => options[:if], :stand_in => stand_in, :mod => mod,
                                     :component => options[:component], :params => options[:params] }
          log("#{mod} replaces #{scene_class} with #{options[:component].name}")
          stand_in
        end

        # Tells the scene a call of a scene goes to: its replacement's stand-in while that holds, else
        # the scene itself.
        #
        # @param scene_class [Class] The scene called.
        # @return [Class] The scene that runs.
        def self.scene_for(scene_class)
          entry = @replaced[scene_class]
          entry && holds?(entry) ? entry[:stand_in] : scene_class
        end

        # Opens the component of the replacement a stand-in scene stands for, which returns from the
        # scene as it closes.
        #
        # @param stand_in [Class] The stand-in scene's class.
        # @param actor [Game_Actor, nil] The character the menu picked.
        # @param scene [Scene_Base] The stand-in scene.
        # @return [Object, nil] The component's handle, nil when it failed.
        def self.open_for(stand_in, actor, scene)
          entry = @replaced.values.find { |each| each[:stand_in].equal?(stand_in) }
          return nil unless entry

          params = entry[:params] ? UI.call_with(entry[:params], scene) : {}
          log("#{entry[:mod]} opens #{entry[:component].name} in place of #{@replaced.key(entry)} for #{actor ? Game.actor_ref(actor) : 'no character'}")
          UI.open(entry[:component], params) { |_value, _why| scene.return_scene if ::SceneManager.scene.equal?(scene) }
        rescue => e
          log("the window #{entry[:mod]} opens in place of a scene FAILED, so the scene returns: #{Logging.failure(e)} at #{Array(e.backtrace).first}")
          nil
        end

        # Tells whether a replacement holds now: its condition answers true, or it has none. A
        # condition that fails counts as false, so the game's own scene runs.
        #
        # @param entry [Hash] The replacement.
        # @return [Boolean] Whether it holds.
        def self.holds?(entry)
          condition = entry[:if]
          condition.nil? || condition.call ? true : false
        rescue => e
          log_once([:condition, entry[:mod], e.class], "the condition #{entry[:mod]} gave its scene FAILED, so the game's scene runs: #{Logging.failure(e)}")
          false
        end
        private_class_method :holds?

        # Wraps SceneManager.call and goto, once.
        #
        # @return [Boolean] Whether they are wrapped, false in a game without SceneManager.
        def self.install
          return true if @installed
          return false unless defined?(::SceneManager) && defined?(::Scene_MenuBase)

          [:call, :goto].each do |method|
            Hooks.around(::SceneManager.singleton_class, method, TAG) do |_manager, args, original|
              original.call(Mod_Framework::UI::Engine::Scenes.scene_for(args[0]), *args.drop(1))
            end
          end
          @installed = true
        end
        private_class_method :install

        # Finds the file of the mod that replaced a scene, for the log.
        #
        # @param lines [Array<String>] The calls, as caller lists them.
        # @return [String] The file, such as "Patch/Equipment_Window.rb".
        def self.mod_file(lines)
          line = lines.find { |entry| !entry.include?("Mod_Framework") } || lines.first
          line.to_s.split(/:\d+/).first.to_s
        end
        private_class_method :mod_file
      end
    end

    # Tells whether a scene is the framework's own menu scene of a mod's screen opened with :menu,
    # which cannot be left for another screen and come back, so a part of a mod waits it out.
    #
    # @param scene [Scene_Base, nil] The scene, the one now when left out.
    # @return [Boolean] Whether it is.
    def self.menu_screen?(scene = defined?(::SceneManager) ? ::SceneManager.scene : nil)
      scene.is_a?(Engine::Scenes::MenuRoot)
    end
  end
end
