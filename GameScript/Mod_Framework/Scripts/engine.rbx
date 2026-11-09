#----------------------------------------------------------------
#  engine.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Removed what made the handles answer as any object, now that they are plain objects
#                            - Removed the names UI gave the engine's classes
#                            - Added what every handle of the framework answers as any object does, so code that walks a scene's variables passes over it
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    # The framework's own drawing engine: the components, roots, layout, input and theme classes
    # the new UI layer builds on. Mods write components of UI::Component instead.
    module Engine
    end
  end
end
