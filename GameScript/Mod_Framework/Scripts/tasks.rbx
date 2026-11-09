#----------------------------------------------------------------
#  tasks.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Made the handles plain objects
#                            - Answered is_a? and the other calls every object answers from TaskHandle, so a scene's variables may hold it
#      Paulinchen  2026-11-05: Read the seconds of real time from the clock that toasts and bubbles count by
#                            - Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # The waits UI.task started: each asks its poll once a frame until the poll answers, its
      # seconds of real time pass or the mod cancels it. The seconds count by the clock that times
      # toasts, which stands while the game is not in front.
      module Tasks
        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "tasks"

        # One wait: what it asks, what hears the answer, when it gives up and where it was started.
        class Task
          # @return [Proc] Asked once a frame; an answer other than nil ends the wait.
          attr_reader :poll

          # @return [Proc, nil] Hears the answer, or nil when the seconds passed.
          attr_reader :block

          # @return [Float, nil] The clock's seconds at which it gives up, nil for never.
          attr_reader :deadline

          # @return [String] Where the mod started it, such as "Bug_Report.rb:40".
          attr_reader :site

          # @return [Boolean] Whether it ended: answered, timed out or cancelled.
          attr_accessor :done

          # Makes a wait.
          #
          # @param poll [Proc] What it asks.
          # @param block [Proc, nil] What hears the answer.
          # @param deadline [Float, nil] When it gives up.
          # @param site [String] Where it was started.
          def initialize(poll, block, deadline, site)
            @poll = poll
            @block = block
            @deadline = deadline
            @site = site
            @done = false
          end
        end

        @tasks = []

        # Starts a wait, asked from the next frame on.
        #
        # @param poll [Proc] What it asks.
        # @param seconds [Numeric, nil] The seconds of real time it waits at most, nil for no end.
        # @param block [Proc, nil] What hears the answer.
        # @param site [String] Where the mod started it.
        # @return [Task] The wait.
        def self.start(poll, seconds, block, site)
          task = Task.new(poll, block, seconds.nil? ? nil : Clock.seconds + seconds.to_f, site)
          @tasks << task
          log("a task of #{site} started, #{seconds.nil? ? 'waiting without an end' : "waiting at most #{seconds} seconds"}")
          task
        end

        # Ends a wait without telling its block.
        #
        # @param task [Task] The wait.
        def self.cancel(task)
          return if task.done

          task.done = true
          @tasks.delete(task)
          log("a task of #{task.site} was cancelled")
        end

        # Asks every wait's poll once, before the frame is drawn, and ends those that answered or
        # whose seconds passed.
        def self.frame
          return if @tasks.empty?

          now = nil
          @tasks.dup.each do |task|
            next if task.done

            answer = ask(task)
            next if task.done

            if !answer.nil?
              log("a task of #{task.site} was answered: #{Logging.short(answer.inspect)}")
              finish(task, answer)
            elsif task.deadline && (now ||= Clock.seconds) >= task.deadline
              log("a task of #{task.site} gave up: its seconds passed")
              finish(task, nil)
            end
          end
        end

        # Forgets every wait without telling their blocks, as F12 starts the game anew.
        def self.reset
          @tasks.each { |task| task.done = true }
          @tasks = []
        end

        # Asks a wait's poll; one that raises ends the wait with nil, logged.
        #
        # @param task [Task] The wait.
        # @return [Object, nil] The answer.
        def self.ask(task)
          task.poll.call
        rescue StandardError => e
          Errors.report(e, "the poll of UI.task (#{task.site})")
          finish(task, nil)
          nil
        end
        private_class_method :ask

        # Ends a wait and tells its block the answer.
        #
        # @param task [Task] The wait.
        # @param answer [Object, nil] The answer, nil when it gave up.
        def self.finish(task, answer)
          task.done = true
          @tasks.delete(task)
          task.block.call(answer) if task.block
        rescue StandardError => e
          Errors.report(e, "the block of UI.task (#{task.site})")
        end
        private_class_method :finish
      end

      # What UI.task hands back: a handle that offers only its documented methods.
      class TaskHandle
        # Makes the handle of a wait.
        #
        # @param task [Tasks::Task] The wait.
        def initialize(task)
          @task = task
        end

        # Tells whether the wait goes on.
        #
        # @return [Boolean] Whether it does.
        def pending?
          !@task.done
        end

        # Ends the wait; its block is not told.
        #
        # @return [nil] Always.
        def cancel
          Tasks.cancel(@task)
          nil
        end

        # Lists what the handle offers.
        #
        # @return [String] The methods.
        def inspect
          "#<UI.task handle of #{@task.site}: pending?, cancel>"
        end
        alias_method :to_s, :inspect
      end
    end

    # The params UI.task takes.
    TASK_PARAMS = [:seconds]

    # Waits on work that ends later, such as a report the DLL sends: asks poll once a frame, before
    # the frame is drawn, until it answers something other than nil or seconds: of real time pass,
    # and then runs the block once with the answer, nil when the seconds passed. The seconds stand
    # while the game is not in front, as a toast's do.
    #
    #   UI.task(-> { Bug_Report.sent }, seconds: 30) { |sent| UI.message(sent ? "Report sent." : "No answer came.") }
    #
    # @param poll [Proc] A lambda without arguments; a poll that raises ends the wait with nil.
    # @param params [Hash] seconds: (the most it waits; no end unless told).
    # @yieldparam answer [Object, nil] The poll's answer, nil when the seconds passed.
    # @return [Object] The task (pending?, cancel).
    # @raise [Engine::MarkupError] poll is no lambda.
    def self.task(poll, params = {}, &block)
      unless poll.respond_to?(:call)
        raise Engine::MarkupError, Engine::Errors.placed("UI.task takes a lambda to ask, such as -> { work.done? }, not #{Engine::Declarations.show(poll)}", caller)
      end

      Engine::Services.check("UI.task", params, TASK_PARAMS, caller)
      Engine::TaskHandle.new(Engine::Tasks.start(poll, params[:seconds], block, Engine::Errors.site(caller).to_s))
    end

    Run.on_start("tasks") do
      Hooks.outermost(Graphics.singleton_class, :update, :before, "Mod Framework tasks") { Mod_Framework::UI::Engine::Tasks.frame }
    end
    Run.on_reset("tasks") { Mod_Framework::UI::Engine::Tasks.reset }
  end
end
