#----------------------------------------------------------------
#  game_menus_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Covered the cursor of a long item list as the wheel scrolls it
#                            - Created
#
#----------------------------------------------------------------

# Covers the fixes of game_menus.rbx in the menus: the party list opened again reads no face from
# its file, and turned off reads every face anew as the game does; the wheel scrolls a long item
# list with its cursor on the item it was on.

require_relative "support"
require_relative "game_support"

# Stands in for RGSS's Window: the offset its picture shows from and the cursor on its picture.
class Window
  attr_accessor :oy

  # Tells the cursor's rectangle on the picture.
  #
  # @return [Rect] The rectangle.
  def cursor_rect
    @cursor_rect ||= Rect.new(0, 0, 0, 0)
  end
end

# Stands in for the game's Window_Base as far as the menus' lists draw with it: a picture as tall as
# its contents_height, and Paradox's draw_face_hue, which disposes the face it drew in the cache.
class Window_Base < Window
  attr_reader :contents, :width, :height

  # Makes a window and its picture.
  #
  # @param _x [Integer] Its left.
  # @param _y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  def initialize(_x, _y, width, height)
    @width = width
    @height = height
    self.oy = 0
    create_contents
  end

  # Tells the game's padding.
  #
  # @return [Integer] The pixels.
  def standard_padding
    12
  end

  # Tells the height of its picture.
  #
  # @return [Integer] The pixels.
  def contents_height
    height - standard_padding * 2
  end

  # Makes its picture anew.
  def create_contents
    @contents = Bitmap.new(width - standard_padding * 2, [contents_height, 1].max)
  end

  # Tells the opacity of what draws disabled.
  #
  # @return [Integer] The opacity.
  def translucent_alpha
    160
  end

  # Draws a face as Paradox does, disposing its picture in the cache once drawn.
  #
  # @param face_name [String] The face sheet's file.
  # @param face_index [Integer] The face on the sheet.
  # @param face_hue [Integer] The hue.
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param enabled [Boolean] Whether it draws opaque.
  def draw_face_hue(face_name, face_index, face_hue, x, y, enabled = true)
    bitmap = Cache.face(face_name, face_hue)
    contents.blt(x, y, bitmap, Rect.new(face_index % 4 * 96, face_index / 4 * 96, 96, 96), enabled ? 255 : translucent_alpha)
    bitmap.dispose
  end

  # Draws a character's face as the game does.
  #
  # @param actor [Object] The character.
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param enabled [Boolean] Whether it draws opaque.
  def draw_actor_face(actor, x, y, enabled = true)
    draw_face_hue(actor.face_name, actor.face_index, 0, x, y, enabled)
  end
end

# Stands in for the game's Window_Selectable: its rows, scrolling and drawing as VX Ace has them.
class Window_Selectable < Window_Base
  attr_reader :index

  # Makes the window with no row picked.
  def initialize(x, y, width, height)
    super
    @index = -1
  end

  # Tells the columns.
  #
  # @return [Integer] One.
  def col_max
    1
  end

  # Tells the rows.
  #
  # @return [Integer] The rows.
  def row_max
    [(item_max + col_max - 1) / col_max, 1].max
  end

  # Tells the height of its picture: every row.
  #
  # @return [Integer] The pixels.
  def contents_height
    [super - super % item_height, row_max * item_height].max
  end

  # Tells the rows in view.
  #
  # @return [Integer] The rows.
  def page_row_max
    (height - standard_padding * 2) / item_height
  end

  # Tells the first row in view.
  #
  # @return [Integer] The row.
  def top_row
    oy / item_height
  end

  # Scrolls to a first row in view.
  #
  # @param row [Integer] The row.
  def top_row=(row)
    self.oy = [[row, row_max - 1].min, 0].max * item_height
  end

  # Tells where an item lies on its picture.
  #
  # @param index [Integer] The item.
  # @return [Rect] Its place.
  def item_rect(index)
    Rect.new(0, index / col_max * item_height, width - standard_padding * 2, item_height)
  end

  # Picks a row, scrolls it into view and puts the cursor on it.
  #
  # @param index [Integer] The row.
  def select(index)
    @index = index
    self.top_row = index if index < top_row
    self.top_row = index - page_row_max + 1 if index > top_row + page_row_max - 1
    rect = item_rect(index)
    cursor_rect.set(rect.x, rect.y, rect.width, rect.height)
  end

  # Draws every item.
  def draw_all_items
    item_max.times { |index| draw_item(index) }
  end

  # Draws an item anew.
  #
  # @param index [Integer] The item.
  def redraw_item(index)
    draw_item(index) if index >= 0
  end

  # Draws every item anew.
  def refresh
    contents.clear
    draw_all_items
  end
end

# Stands in for the game's menu status, the party list: four members a page, each with a face.
class Window_MenuStatus < Window_Selectable
  # Makes the list as the menu does and draws it.
  def initialize
    super(160, 0, 480, 480)
    refresh
  end

  # Tells the members.
  #
  # @return [Integer] The members.
  def item_max
    $game_party.members.size
  end

  # Tells a row's height: a quarter of the window.
  #
  # @return [Integer] The pixels.
  def item_height
    (height - standard_padding * 2) / 4
  end

  # Draws a member's face.
  #
  # @param index [Integer] The member.
  def draw_item(index)
    rect = item_rect(index)
    draw_actor_face($game_party.members[index], rect.x + 1, rect.y + 1)
  end
end

# Stands in for the game's item lists: a 24 pixel row per item, five rows in view.
class Window_ItemList < Window_Selectable
  attr_reader :drawn_at

  # Makes a list of items and draws it.
  #
  # @param items [Integer] The items.
  def initialize(items)
    @items = items
    @drawn_at = {}
    super(0, 0, 200, 5 * 24 + 24)
    refresh
  end

  # Tells the items.
  #
  # @return [Integer] The items.
  def item_max
    @items
  end

  # Tells a row's height.
  #
  # @return [Integer] The pixels.
  def item_height
    24
  end

  # Draws an item, noted by where it lies on the picture.
  #
  # @param index [Integer] The item.
  def draw_item(index)
    @drawn_at[item_rect(index).y] = index
  end
end

# Stands in for the game's cache of faces as Paradox has it: a face disposed in the cache is read
# from its file again, noted in $faces_read.
module Cache
  # Hands out a face sheet.
  #
  # @param name [String] The sheet's file.
  # @param _hue [Integer] The hue.
  # @return [Bitmap] The sheet.
  def self.face(name, _hue = 0)
    @faces ||= {}
    face = @faces[name]
    return face if face && !face.disposed?

    $faces_read << name
    @faces[name] = Bitmap.new(384, 384)
  end
end

load_scripts "logging", "hooks", "run", "bridge", "settings", "game_menus", "game_mouse"
Mod_Framework::Log.define_singleton_method(:write) { |_line| nil }
menus = Mod_Framework::UI::Engine::GameMenus
menus::LongLists.install
menus::PartyFaces.install
Actor = Struct.new(:name, :face_name, :face_index)
$game_party = Struct.new(:members).new((1..10).map { |number| Actor.new("Member #{number}", "Face#{number}", 0) })

# Opens the menu's party list, then closes it.
#
# @return [Array<String>] The faces read from their files.
def open_menu
  $faces_read = []
  Window_MenuStatus.new
  $faces_read
end

in_game_folder do
  open_menu
  check("opened again, the party list reads no face from its file", open_menu, [])

  menus.turn(:party, false)
  open_menu
  check("turned off, the list opened again reads every face anew, as the game does",
        open_menu, (1..10).map { |number| "Face#{number}" })

  list = Window_ItemList.new(40)
  list.select(3)
  2.times { Mod_Framework::UI::Engine::GameMouse.send(:scroll, list, -1) }
  check("the wheel scrolls a long item list and its cursor stays on the item picked",
        [list.top_row, list.index, list.drawn_at[list.cursor_rect.y]], [2, 3, 3])
end
