#----------------------------------------------------------------
#  layer_alert_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Gave the alert its close mark by on_close: alone
#      Paulinchen  2026-11-06: Checked that the bar's line stands in the middle of its height
#      Paulinchen  2026-11-05: Covered a notice whose text wraps into two lines at most
#                            - Covered a toast whose text keeps the plain color beside the bar of its severity, and the icon
#                              the mod gives each severity
#                            - Created
#
#----------------------------------------------------------------

# Covers alert of the UI layer (design v2 section 5.4) in a booted game against FakeTree, through a
# mod's restart bar: a warning with its Restart now button, its line in the middle of its height
# level with the button, which the player presses or closes; a
# toast under it whose text keeps the plain color beside its severity's bar; and the icon the mod
# gives its warnings, which its alerts and toasts show unless they name their own.

require_relative "layer_support"

RESTART_BAR = <<-RUBY
  module Camp_Restart
    UI = Mod_Framework::UI

    UI.defaults :severity_icons, warning: 56

    def self.warn(icon = nil)
      Mod_Framework.toast "Monsters ahead!", icon ? { severity: :warning, icon: icon } : { severity: :warning }
    end

    class Changes < UI::Component
      state :waiting, true
      state :restarted, false

      def render
        window "Mods" do
          list ["Map Display", "Level Cap"], bind: :mod
          alert "3 changes wait for the game to start again.", severity: :warning, visible: waiting,
                on_close: -> { self.waiting = false } do
            button "Restart now", id: :restart, on_click: -> { self.restarted = true }
          end
          alert "Level Cap was updated.", severity: :success, dense: true, text_color: :text, id: :toast
          alert "Alice joined the party, bringing the Holy Sword and three Medicinal Herbs.", severity: :info, most_lines: 2, id: :joined
        end
      end

      state :mod
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Restart.rb", RESTART_BAR)
    frame

    ui.open(Camp_Restart::Changes)
    frame
    Graphics.update
    changes = ui::Engine::Layer.tops.last.mount.component
    alert = ui::Engine::Tree.roots.last.children.find { |child| child.is_a?(ui::Engine::Alert) }

    # The bar warns in the warning color, its button after its text and the close mark at its end.
    check("the alert's text, its color and its accent", [alert.label.text, alert.label.color, alert.accent],
          ["3 changes wait for the game to start again.", :warning, :warning])
    check("its parts in order: text, Restart now, close mark", alert.children.map { |child| child.respond_to?(:text) ? child.text.to_s : child.class.name },
          ["3 changes wait for the game to start again.", "Restart now", "x"])

    # The bar's line stands in the middle of its height, level with Restart now and the close mark.
    line = alert.label
    surface = ui::Engine::Tree.roots.last.base_surface
    drawn = surface.bitmap.texts.find { |text| text[2] == line.text[0, 1] }
    check("the line's top in its place, against the middle of its height", drawn[1] + surface.y - line.rect.y, (line.rect.height - line.send(:line_height)) / 2)

    # The toast keeps its text in the plain color; only its bar shows its severity.
    toast = ui::Engine::Tree.roots.last.find(:toast)
    check("the toast's text color and its bar's", [toast.label.color, toast.accent], [:text, :success])

    # A long notice wraps into two lines at most and tells C# so; the others stay one line cut.
    joined = ui::Engine::Tree.roots.last.find(:joined)
    check("the lines C# keeps of the long notice's text and of the toast's", [tree.nodes[joined.label.node][:props]["most_lines"], tree.nodes[toast.label.node][:props]["most_lines"]],
          [2, 0])

    # The mod's warnings show its icon, the success none; a toast's own icon wins.
    toasts = []
    ui::Engine::Notices.define_singleton_method(:show) { |_text, options| toasts << options[:icon] }
    Camp_Restart.warn
    Camp_Restart.warn(191)
    check("the icons of the warning alert, the success alert and two warning toasts", [alert.icon, toast.icon] + toasts, [56, nil, 56, 191])

    # Restart now runs its handler; the close mark tells on_close, which hides the bar.
    tell(tree, [[ui::Engine::Tree.roots.last.find(:restart).node, "click"]])
    check("Restart now pressed", changes.restarted, true)
    tell(tree, [[alert.close_mark.node, "click"]])
    check("the close mark hid the bar through on_close", [changes.waiting, alert.visible?], [false, false])
  end
end
