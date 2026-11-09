#----------------------------------------------------------------
#  game_mouse_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-04: Kept a few flows of the mouse on the game's windows with a check per step that matters
#                            - Rewrote the checks as flow tests of the mouse on the game's windows
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# Covers game_mouse.rbx and the message window's adoption in defaults.rbx in a booted game: the
# player points at and clicks the title commands, clicks the equip slots, scrolls a long list and
# clicks windows that are left alone; no click passes a root, Alt or the setting turned off; and
# the message window takes a click without its choices taking it too.

require_relative "game_lists_support"

# The tick's bits of the left button held and gone down.
LEFT_CLICK = 1 | 4

# The tick's bits of the right button held and gone down.
RIGHT_CLICK = 2 | 8

# Runs one frame with the pointer at a place and mouse buttons gone down in it, then a window's update.
#
# @param window [Window] The window.
# @param at [Array<Integer>] The pointer on the game's screen.
# @param buttons [Integer] The tick's mouse bits.
# @param pressed [Array<Symbol>] The game's buttons pressed in the frame.
def mouse_frame(window, at, buttons = 0, pressed = [])
  $mouse_at = at
  $mouse_buttons = buttons
  frame(pressed)
  $mouse_buttons = 0
  window.update
end

# Tells the middle of a title row on the screen, the title at 240,312 with its padding of 12.
#
# @param row [Integer] The row.
# @return [Array<Integer>] The place.
def title_row(row)
  [300, 312 + 12 + row * 24 + 10]
end

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree), :game => lambda { define_game_lists }) do
    ui = Mod_Framework::UI
    frame

    # The player points at the title commands, clicks one and right-clicks to cancel.
    title = Window_TitleCommand.new
    title.openness = 255
    picked = []
    title.set_handler(:continue, lambda { picked << :continue; title.activate })
    title.set_handler(:cancel, lambda { picked << :cancel; title.activate })
    $sounds = []
    mouse_frame(title, title_row(2))
    pointed = [title.index, $sounds.size]
    frame([:DOWN])
    title.update
    check("a pointer that moved picks a row quietly and a resting one leaves the keys their cursor", [*pointed, title.index], [2, 0, 3])
    mouse_frame(title, title_row(1), LEFT_CLICK)
    check("a click confirms the row through its handler with the ok sound, not as the game's confirm",
          [title.index, *picked, $sounds.include?(:ok), Input.trigger?(:C)], [1, :continue, true, false])
    mouse_frame(title, [20, 20], RIGHT_CLICK)
    mouse_frame(title, [243, 316], LEFT_CLICK)
    check("a right click cancels and a click on the edge presses nothing", picked, [:continue, :cancel])

    # The equip slots, a long list under the wheel, and the windows left alone.
    slots = Window_EquipSlot.new(0, 0, 200, 144)
    slots.activate
    slots.select(0)
    $sounds = []
    mouse_frame(slots, [50, 12 + 3 * 24 + 5], LEFT_CLICK)
    unhandled = [slots.index, $sounds.size]
    equipped = []
    slots.set_handler(:ok, lambda { equipped << slots.index })
    mouse_frame(slots, [50, 12 + 4 * 24 + 5], LEFT_CLICK)
    check("a click on the equip slots picks the row and confirms it only with an ok handler", [*unhandled, *equipped], [3, 0, 4])
    slots.dispose
    long = Class.new(Window_Selectable) { def item_max; 20; end }.new(0, 0, 200, 5 * 24 + 24)
    long.activate
    mouse_frame(long, [50, 20])
    long.select(0)
    $wheel = -2
    mouse_frame(long, [50, 20])
    check("the wheel scrolls a list with its cursor in sight", [long.top_row, long.index], [2, 2])
    long.dispose
    number = Window_NumberInput.new(0, 0, 200, 48)
    number.activate
    $sounds = []
    mouse_frame(number, [50, 20], LEFT_CLICK)
    number.dispose
    title.cursor_fix = true
    mouse_frame(title, title_row(4))
    title.cursor_fix = false
    check("the number input and a fixed cursor are left alone", [$sounds.size, title.index], [0, 1])

    # Nothing reaches a game window under a root, while Alt arranges or with the setting off.
    window = ui::Engine::Window.new(:at => [0, 0]).open
    mouse_frame(title, title_row(1), LEFT_CLICK)
    window.close
    box = ui::Engine::Box.new(:at => [240, 312], :size => [160, 144]).open
    frame
    tree.post("over", box.node)
    mouse_frame(title, title_row(1), LEFT_CLICK)
    box.close
    tree.post("over", nil)
    $keys = { 0xA4 => 1 }
    mouse_frame(title, title_row(1), LEFT_CLICK)
    $keys = {}
    ui::Engine::GameMouse.turn(false)
    mouse_frame(title, title_row(1), LEFT_CLICK)
    check("no click reaches a game window while a root holds the buttons, the pointer is on a root, the left Alt arranges or the setting is off",
          [*picked, Mod_Framework::Settings.setting("ui_game_mouse")], [:continue, :cancel, "0"])
    ui::Engine::GameMouse.turn(true)

    # The message window and its choices.
    title.deactivate
    message = Window_Message.new
    mouse_frame(message, [100, 400], LEFT_CLICK)
    mouse_frame(message, [100, 400], RIGHT_CLICK)
    mouse_frame(message, [100, 100], LEFT_CLICK)
    choices = Window_TitleCommand.new
    choices.openness = 255
    chosen = []
    choices.set_handler(:new_game, lambda { chosen << :new_game })
    message.choices = choices
    mouse_frame(message, [100, 400], LEFT_CLICK)
    check("the message window takes a click on it as confirm and a right click as cancel, none elsewhere, and its choices do not take the click",
          [*message.answers, chosen.size], [:C, :B, :C, 0])
  end
end
