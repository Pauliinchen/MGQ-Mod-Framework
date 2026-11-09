#----------------------------------------------------------------
#  game_lists_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Stood in for drawing one row anew
#      Paulinchen  2026-11-04: Dropped the horizontal list check, which no script asks
#      Paulinchen  2026-11-01: Stood in for the line sizes, the system color, Up and drawing all rows
#                            - Stood in for the cursor rect, set as the cursor moves
#      Paulinchen  2026-10-29: Created
#
#----------------------------------------------------------------

# The game's lists for the tests of adopt.rbx and game_mouse.rbx, as far as the framework reaches
# into them: Window_Selectable with its cursor, rows, handlers and gates, Window_Command and the
# title's command window with the five commands of the translated and the untranslated game, the
# equip screen's slot list, which defines process_handling again without super, the number input
# the mouse leaves alone, and a message window that reads Input itself.

require_relative "tree_support"

# Stands in for the cursor rect of RGSS's Window: empty, or set to a row's rectangle.
class CursorRect
  attr_reader :x, :y, :width, :height

  # Makes it empty.
  def initialize
    empty
  end

  # Empties it.
  #
  # @return [CursorRect] Itself.
  def empty
    @x = @y = @width = @height = 0
    self
  end

  # Sets it to a rectangle.
  #
  # @param rect [Rect] The rectangle.
  # @return [CursorRect] Itself.
  def set(rect)
    @x, @y, @width, @height = rect.x, rect.y, rect.width, rect.height
    self
  end

  # Tells whether it is empty.
  #
  # @return [Boolean] Whether it is.
  def empty?
    @width == 0 || @height == 0
  end

  # Tells its place and size.
  #
  # @return [Array<Integer>] x, y, width and height.
  def to_a
    [@x, @y, @width, @height]
  end
end

# The lists it defines, which a new session defines anew.
GAME_LISTS = [:Window_Selectable, :Window_Command, :Window_TitleCommand, :Window_EquipSlot, :Window_NumberInput, :Window_Message]

# Defines the game's lists over the Window_Base of game_support.rb, which new_session makes anew.
def define_game_lists
  GAME_LISTS.each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
  Object.class_eval <<-RUBY
    class Window_Base
      attr_accessor :active, :ox, :oy, :contents_opacity, :viewport, :padding_bottom
      attr_reader :icons, :drawn
      alias_method :plain_initialize, :initialize
      def initialize(*args)
        plain_initialize(*args)
        @active = true
        @ox = @oy = 0
        @contents_opacity = 255
        @padding_bottom = @padding
        @icons = []
        @drawn = []
      end
      def activate; @active = true; self; end
      def deactivate; @active = false; self; end
      def close; @closing = true; @openness = 0; self; end
      def create_contents; @contents = Bitmap.new([width - 2 * padding, 1].max, [height - 2 * padding, 1].max); end
      def standard_padding; 12; end
      def line_height; 24; end
      def fitting_height(lines); lines * line_height + standard_padding * 2; end
      def contents_width; width - standard_padding * 2; end
      def normal_color; Color.new(255, 255, 255); end
      def system_color; Color.new(132, 170, 255); end
      def change_color(color, enabled = true); @enabled_color = enabled; @color = color; end
      def draw_icon(icon, x, y, _enabled = true); @icons << [icon, x, y]; end
      def draw_text(*args)
        @drawn << [args[0].is_a?(Rect) ? args[1] : args[4], @color && @color.to_a]
        args[0].is_a?(Rect) ? contents.draw_text(args[0].x, args[0].y, args[0].width, args[0].height, args[1]) : contents.draw_text(*args[0, 5])
      end
    end

    class Window_Selectable < Window_Base
      attr_reader :index
      attr_accessor :cursor_fix, :cursor_all
      def initialize(x, y, width, height)
        super
        @index = -1
        @handler = {}
        @cursor_fix = @cursor_all = false
        deactivate
      end
      def col_max; 1; end
      def item_max; 0; end
      def item_height; 24; end
      def item_width; width - padding * 2; end
      def row_max; [(item_max + col_max - 1) / col_max, 1].max; end
      def page_row_max; (height - padding - padding_bottom) / item_height; end
      def top_row; oy / item_height; end
      def top_row=(row)
        row = row_max - 1 if row > row_max - 1
        row = 0 if row < 0
        self.oy = row * item_height
      end
      def bottom_row; top_row + page_row_max - 1; end
      def item_rect(index); Rect.new(index % col_max * item_width, index / col_max * item_height, item_width, item_height); end
      def item_rect_for_text(index); rect = item_rect(index); Rect.new(rect.x + 4, rect.y, rect.width - 8, rect.height); end
      def select(index)
        return unless index
        @index = index
        row = index / col_max
        self.top_row = row if row < top_row
        self.top_row = row - page_row_max + 1 if row > bottom_row
        update_cursor
      end
      def cursor_rect; @cursor_rect ||= CursorRect.new; end
      def update_cursor; @index < 0 ? cursor_rect.empty : cursor_rect.set(item_rect(@index)); end
      def set_handler(symbol, method); @handler[symbol] = method; end
      def handle?(symbol); @handler.include?(symbol); end
      def call_handler(symbol); @handler[symbol].call if handle?(symbol); end
      def open?; openness >= 255; end
      def cursor_movable?; active && open? && !@cursor_fix && !@cursor_all && item_max > 0; end
      def update
        super
        process_cursor_move
        process_handling
      end
      def process_cursor_move
        return unless cursor_movable?
        last = @index
        select((@index + 1) % item_max) if Input.repeat?(:DOWN)
        select((@index - 1) % item_max) if Input.repeat?(:UP)
        Sound.play_cursor if @index != last
      end
      def process_handling
        return unless open? && active
        return process_ok if ok_enabled? && Input.trigger?(:C)
        return process_cancel if cancel_enabled? && Input.trigger?(:B)
      end
      def ok_enabled?; handle?(:ok); end
      def cancel_enabled?; handle?(:cancel); end
      def current_item_enabled?; true; end
      def process_ok
        return Sound.play_buzzer unless current_item_enabled?
        Sound.play_ok
        Input.update
        deactivate
        call_ok_handler
      end
      def call_ok_handler; call_handler(:ok); end
      def process_cancel
        Sound.play_cancel
        Input.update
        deactivate
        call_handler(:cancel)
      end
      def refresh
        contents.clear
        draw_all_items
      end
      def draw_all_items; item_max.times { |row| draw_item(row) }; end
      def draw_item(_index); end
      def redraw_item(index); draw_item(index) if index >= 0; end
    end

    class Window_Command < Window_Selectable
      def initialize(x, y)
        clear_command_list
        make_command_list
        super(x, y, window_width, window_height)
        refresh
        select(0)
        activate
      end
      def window_width; 160; end
      def window_height; item_max * 24 + 24; end
      def item_max; @list.size; end
      def clear_command_list; @list = []; end
      def make_command_list; end
      def add_command(name, symbol, enabled = true, ext = nil); @list.push(:name => name, :symbol => symbol, :enabled => enabled, :ext => ext); end
      def command_enabled?(index); @list[index][:enabled]; end
      def current_data; index >= 0 ? @list[index] : nil; end
      def current_item_enabled?; current_data ? current_data[:enabled] : false; end
      def current_symbol; current_data ? current_data[:symbol] : nil; end
      def symbols; @list.map { |entry| entry[:symbol] }; end
      def draw_item(index)
        change_color(normal_color, command_enabled?(index))
        draw_text(item_rect_for_text(index), @list[index][:name], alignment)
      end
      def alignment; 0; end
      def ok_enabled?; true; end
      def call_ok_handler
        if handle?(current_symbol)
          call_handler(current_symbol)
        elsif handle?(:ok)
          super
        else
          activate
        end
      end
      def refresh
        clear_command_list
        make_command_list
        create_contents
        super
      end
    end

    class Window_TitleCommand < Window_Command
      def initialize
        super(0, 0)
        update_placement
        self.openness = 0
        open
      end
      def update_placement
        self.x = (640 - width) / 2
        self.y = (480 * 1.6 - height).to_i / 2
      end
      def make_command_list
        add_command("New Game", :new_game)
        add_command("Continue", :continue)
        add_command("Auto Continue", :auto_continue)
        add_command("Library", :call_library_h)
        add_command("Shutdown", :shutdown)
      end
    end

    class Window_EquipSlot < Window_Selectable
      def item_max; 5; end
      def process_handling
        return unless open? && active
        return process_ok if ok_enabled? && Input.trigger?(:C)
        return process_cancel if cancel_enabled? && Input.trigger?(:B)
      end
    end

    class Window_NumberInput < Window_Selectable
      def item_max; 8; end
      def process_handling
        return unless active
        return process_ok if Input.trigger?(:C)
      end
    end

    class Window_Message < Window_Base
      attr_accessor :choices
      attr_reader :answers
      def initialize
        super(0, 360, 640, 120)
        @answers = []
      end
      def update
        super
        choices.update if choices
        @answers << :C if Input.trigger?(:C)
        @answers << :B if Input.trigger?(:B)
      end
    end
  RUBY
end
