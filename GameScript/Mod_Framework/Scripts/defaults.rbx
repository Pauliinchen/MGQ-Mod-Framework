#----------------------------------------------------------------
#  defaults.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Adopted through Adopt.adopt, since UI.adopt is gone
#      Paulinchen  2026-11-04: Moved the engine's classes and modules under UI::Engine
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # What the framework adopts itself: the message window, which reads Input itself, takes a
      # click as confirm and a right click as cancel, so the mouse moves a message on.
      module Defaults
        # The message window's adoption, nil in a game without one.
        MESSAGE = defined?(::Window_Message) ? Adopt.adopt(::Window_Message, :click => :C, :right_click => :B) : nil
      end
    end
  end
end
