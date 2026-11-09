#----------------------------------------------------------------
#  collector.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Had the DLL let the game's program use up to 4 GB once the game runs on the PC
#                            - Collected and let go of pictures at once while the game runs low on memory, and let mods read the memory
#                            - Collected at most once a minute and counted a collection the game ran since the last frame
#      Paulinchen  2026-11-06: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Starts a garbage collection behind a scene change, while the screen stands still between two
      # scenes, so the collections the game's heap needs come there rather than while a screen is used.
      #
      # A collection of a late-game heap takes about 220 ms, so one that ran less than GAP seconds
      # before, the game's own or the framework's, makes the next scene change skip it; the game's
      # own one may have run since the last frame, such as during the autosave of a menu's opening.
      module Collector
        # The seconds after a collection in which a scene change starts none.
        GAP = 60

        # GC.count as the last frame ended, the last scene changed or the framework last collected;
        # nil before the first reading.
        @count = nil

        # The time GC.count was last seen to change or the framework last collected; nil before
        # either.
        @collected_at = nil

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "collector"

        # Notes a collection the game ran. Called after every Graphics.update and as a scene changes.
        def self.note_frame
          count = GC.count
          return if count == @count

          @collected_at = Time.now.to_f unless @count.nil?
          @count = count
        end

        # Collects behind a scene change unless a collection ran within GAP seconds or the game ends.
        # Called after every scene's main ends, before the next scene starts.
        #
        # @param scene [Object, nil] The scene that comes next, nil as the game ends.
        # @return [Boolean] Whether it collected.
        def self.scene_changed(scene)
          return false if scene.nil?

          note_frame
          started = Time.now.to_f
          return false if @collected_at && started - @collected_at < GAP

          GC.start
          @collected_at = Time.now.to_f
          @count = GC.count
          log(format("collected behind the change to %s in %.0f ms", scene.class.name, (@collected_at - started) * 1000.0))
          true
        end

        # Follows the scenes once the game runs: a collection after each scene's main.
        def self.install
          return unless defined?(::Scene_Base) && ::Scene_Base.method_defined?(:main)

          Hooks.after(::Scene_Base, :main, "Mod Framework collector") { Mod_Framework::UI::Engine::Collector.scene_changed(::SceneManager.scene) }
        end
      end

      # Collects at once and lets go of kept pictures while the game runs low on memory: every
      # CHECK_FRAMES the DLL reads the game's free address space and answers low below its floor,
      # at most once every 20 seconds (MemoryGuard in C#).
      #
      # A 32-bit game ends without a word once a picture finds no room in its address space.
      module MemoryGuard
        # The frames between two checks, 5 seconds at the game's 60 frames a second; counted in
        # frames, since a time read on every frame makes objects.
        CHECK_FRAMES = 300

        # The topic of a check, MemoryTopics.CheckTopic in C#.
        CHECK_TOPIC = "memory.check"

        # How many picture files and sized copies of its own the framework keeps while memory runs low.
        PICTURES_LEFT = 4

        # How many pictures the game's own cache keeps while memory runs low.
        GAME_PICTURES_LEFT = 20

        # The frames since the last check, which the first frame starts with.
        @frames = CHECK_FRAMES

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "memory"

        # Checks the memory every CHECK_FRAMES, and collects and lets go of pictures while it runs
        # low. Called after every Graphics.update.
        def self.check
          @frames += 1
          return if @frames < CHECK_FRAMES

          @frames = 0
          bridge = Mod_Framework.bridge
          return unless bridge.has?(CHECK_TOPIC)

          reading = bridge.call(CHECK_TOPIC)
          trim(reading) if reading.is_a?(Hash) && reading["low"]
        end

        # Lets go of the pictures kept least long ago, never one that shows, and collects.
        #
        # @param reading [Hash] The check's reading, see Mod_Framework.memory.
        def self.trim(reading)
          started = Time.now.to_f
          gone = UI.trim_pictures(PICTURES_LEFT) + GameMenus::PictureCache.forget(GAME_PICTURES_LEFT)
          GC.start
          after = Mod_Framework.memory
          log(format("the game ran low on memory, %d MB of address space free with %d MB used and %d MB private: let go of %d pictures and collected in %.0f ms, %s MB free now",
                     reading["free"], reading["used"], reading["private"], gone, (Time.now.to_f - started) * 1000.0, after ? after["free"].to_s : "?"))
        end
        private_class_method :trim
      end
    end

    # Once the game runs, a scene change starts a garbage collection.
    Run.on_start("collector") { Mod_Framework::UI::Engine::Collector.install }
  end

  # The topic that reads the game's memory, MemoryTopics.ReadTopic in C#.
  MEMORY_TOPIC = "memory.read"

  # Reads the game's memory now, which takes a few milliseconds, so a mod reads it at most every
  # few seconds, such as at a screen change.
  #
  # @return [Hash{String => Integer}, nil] The megabytes of address space "used" and "free", and the
  #   "private" bytes; nil without the DLL and on JoiPlay.
  def self.memory
    bridge.has?(MEMORY_TOPIC) ? bridge.call(MEMORY_TOPIC) : nil
  end

  # The topic that lets the game's program use up to 4 GB from its next start,
  # GameExeTopics.LargeAddressTopic in C#.
  LARGE_ADDRESS_TOPIC = "game_exe.large_address"

  # Once the game runs on the PC, the DLL lets its program use up to 4 GB from the next start;
  # JoiPlay runs no Game.exe.
  Run.on_start("game exe 4 GB", :dll => true) do
    bridge = Mod_Framework.bridge
    bridge.call(LARGE_ADDRESS_TOPIC) if Mod_Framework.platform != Mod_Framework::JOIPLAY && bridge.has?(LARGE_ADDRESS_TOPIC)
  end
end
