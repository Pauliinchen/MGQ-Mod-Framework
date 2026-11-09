#----------------------------------------------------------------
#  layer_patch_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Renamed the mod's badge component, as badge is a built-in now
#      Paulinchen  2026-11-06: Added the text field without its add_ helper
#                            - Removed the check of UI.dump
#                            - Removed the checks of the log of ids two mods write
#                            - Called the engine's classes by their names under UI::Engine
#                            - Changed a shop of the old components for a screen of the old engine, as the mod browser moved
#                              to the UI layer
#                            - Changed the mod browser for a screen of the old engine, as the Mods screen moved to the UI layer
#      Paulinchen  2026-11-04: Covered a mod changing the parts another mod's patch added, and the log of a patch that
#                              reaches two mods' parts of one id
#                            - Created
#
#----------------------------------------------------------------

# Covers UI.patch (design v2 sections 7.1 to 7.5 and 7.7) in a booted game against FakeTree: a mod
# changes another mod's window with every operation and the window keeps the changes as it renders
# again; a mod loaded later changes the parts the first one added; a mod changes a screen of the old
# engine by its ids; and two mods that change the same part are logged, while a patch that fails
# is switched off and the window still opens.

require_relative "layer_support"

CAMP_NOTES = <<-RUBY
  module Camp_Notes
    UI = Mod_Framework::UI

    class NoteBadge < UI::Component
      param :label

      def render
        text label
      end
    end

    class NotesWindow < UI::Component
      state(:notes) { ["Buy herbs", "Rest"] }
      state :cleared, 0
      expose(:count) { notes.size }

      def render
        window "Camp notes", id: :camp_notes do
          text "Notes", id: :title
          list notes, id: :notes
          note_badge label: "new", id: :badge
          stack row: true, id: :buttons do
            button "Clear", id: :clear, on_click: -> { self.cleared = cleared + 1 }
            button "Close", id: :close, on_click: :close
          end
        end
      end
    end
  end
RUBY

CAMP_PLUS = <<-RUBY
  module Camp_Plus
    UI = Mod_Framework::UI

    class BigBadge < UI::Component
      param :label
      param :original, content: true

      def render
        stack id: :big_badge do
          text "Big"
          children :original
        end
      end
    end

    class Counter < UI::Component
      state :clicks, 0

      def render
        button "Count \#{clicks}", id: :counter, on_click: -> { self.clicks = clicks + 1 }
      end
    end

    def self.clear_allowed?
      $allow_clear
    end

    UI.patch "#camp_notes" do |t|
      t.set "#title", text: "Camp notes plus"
      t.after "#title" do
        text "Notes: \#{t.read(:count)}"
      end
      t.rows "#notes" do |rows|
        rows + ["From Camp Plus"]
      end
      t.replace "#badge", BigBadge
      t.before "#buttons" do
        text "Before the buttons"
      end
      t.prepend "#buttons" do
        button "First"
      end
      t.append "#buttons" do
        component Counter
      end
      t.hide "#close"
      t.on "#clear", :click do |original|
        original.call if clear_allowed?
      end
    end
  end
RUBY

# Forgets the modules mods of an earlier flow defined, whose components the framework booted again
# no longer knows.
#
# @param names [Array<Symbol>] The modules.
def forget_mods(*names)
  names.each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
end

# Lists what an engine part and the parts it holds show, in order: each visible text, button and
# list row.
#
# @param part [Mod_Framework::UI::Engine::Component] The part.
# @return [Array<String>] The texts.
def shown_texts(part)
  return [] unless part.visible?

  own = if part.is_a?(Mod_Framework::UI::Engine::List)
          part.rows.map { |row| row.is_a?(Hash) ? row[:text] : row.to_s }
        elsif !part.container? && part.respond_to?(:text)
          [part.text.to_s]
        else
          []
        end
  own + part.children.map { |child| shown_texts(child) }.flatten
end

# A mod changes another mod's window with every operation, and the changes stay as it renders again.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Notes.rb", CAMP_NOTES)
    load_mod("Patch/Camp_Plus.rb", CAMP_PLUS)
    frame
    ui.open(Camp_Notes::NotesWindow)
    frame
    top = ui::Engine::Layer.tops.last
    window = top.root.engine
    expected = ["Camp notes plus", "Notes: 2", "Buy herbs", "Rest", "From Camp Plus", "Big", "new", "Before the buttons", "First", "Clear", "Count 0"]
    check("the window shows every change: set, after, rows, replace keeping the original, before, prepend, append and hide",
          shown_texts(window), expected)

    clear = window.find(:clear)
    clear.emit(:click)
    frame
    notes = top.mount.component
    check("a wrapped handler that does not call the owner's refuses the click and says so",
          [notes.cleared, layer_lines.grep(/refused/).last], [0, "Camp Plus refused click of button #clear in Camp_Notes::NotesWindow (Camp_Plus.rb:47)"])

    window.find(:counter).emit(:click)
    frame
    $allow_clear = true
    clear.emit(:click)
    notes.notes = ["Buy herbs"]
    frame
    check("the owner's handler runs once allowed, and the window renders again with every change and the added part's state",
          [notes.cleared, shown_texts(window)],
          [1, ["Camp notes plus", "Notes: 1", "Buy herbs", "From Camp Plus", "Big", "new", "Before the buttons", "First", "Clear", "Count 1"]])

  end
end

CAMP_TIDY = <<-RUBY
  Mod_Framework::UI.patch "#camp_notes" do |t|
    t.hide "#Camp_Plus:6"
    t.set "#Camp_Plus/counter", text: "Tally"
  end
RUBY

# A mod loaded later changes the parts another mod's patch added: one without an id by the key it
# got, one by its id.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    forget_mods(:Camp_Notes, :Camp_Plus)
    load_mod("Patch/Camp_Notes.rb", CAMP_NOTES)
    load_mod("Patch/Camp_Plus.rb", CAMP_PLUS)
    load_mod("Patch/Camp_Tidy.rb", CAMP_TIDY)
    frame
    ui.open(Camp_Notes::NotesWindow)
    frame
    window = ui::Engine::Layer.tops.last.root.engine
    check("the later mod hides the button the first one prepended and renames the counter the first one appended",
          shown_texts(window), ["Camp notes plus", "Notes: 2", "Buy herbs", "Rest", "From Camp Plus", "Big", "new", "Before the buttons", "Clear", "Tally"])
  end
end

MOD_NOTES = <<-RUBY
  module Mod_Notes
    UI = Mod_Framework::UI

    UI.patch "#camp_shop" do |t|
      t.rows "#camp_shop_list" do |rows|
        rows.map { |row| row.is_a?(Hash) && row[:text] == "Rope" ? row.merge(:text => "Rope (noted)") : row }
      end
      t.hide "#camp_shop_sort"
      t.before "#camp_shop_search" do
        text "Mod Notes is on"
      end
      t.append "#camp_shop_bar" do
        button "Notes", id: :mod_notes_open, on_click: -> { $notes_opened = true }
      end
      t.replace "#camp_shop_buy" do |original|
        text "Buy, as noted:"
        original.place
      end
      t.on "#camp_shop_list", :submit do |original|
        original.call unless $notes_hold
      end
    end
  end
RUBY

# Opens a shop of the old components, as a mod's screens built before the layer are:
# a bar of buttons with a search, a list of wares and a page a pick shows.
#
# @param rows [Array<Hash>] The wares.
# @return [Mod_Framework::UI::Engine::Window] The shop.
def open_old_shop(rows)
  shop = Mod_Framework::UI::Engine::Window.new(:id => :camp_shop, :title => "Shop", :size => [400, 300])
  bar = shop.add_row(:id => :camp_shop_bar)
  bar.add_button("Sort", :id => :camp_shop_sort)
  bar.add_button("Buy all", :id => :camp_shop_buy)
  bar.add(Mod_Framework::UI::Engine::TextField.new(:id => :camp_shop_search))
  list = shop.add_list(:rows => rows, :id => :camp_shop_list)
  page = shop.add_box(:id => :camp_shop_page, :visible => false)
  list.on(:submit) { |_row, _place| page.visible = true }
  shop.open
  shop
end

# Tells the texts of the rows a list shows.
#
# @param list [Mod_Framework::UI::Engine::List] The list.
# @return [Array<String>] The texts.
def names_in(list)
  list.rows.map { |row| row.is_a?(Hash) ? row[:text] : row.to_s }
end

# A mod changes a screen of the old engine by its ids.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    load_mod("Patch/Mod_Notes.rb", MOD_NOTES)
    frame
    shop = open_old_shop([{ :text => "Herb" }, { :text => "Rope" }])
    frame
    list = shop.find(:camp_shop_list)
    check("the old screen shows a row the mod changed, the hidden button, the parts added before, after and in the place of others",
          [names_in(list), shop.find(:camp_shop_sort).visible?, shown_texts(shop).grep(/Mod Notes is on|Buy, as noted:|\ANotes\z/)],
          [["Herb", "Rope (noted)"], false, ["Buy, as noted:", "Mod Notes is on", "Notes"]])

    shop.find(:mod_notes_open).emit(:click)
    page = shop.find(:camp_shop_page)
    $notes_hold = true
    tree.post("events", [[list.node, "submit", 1]])
    frame
    held = page.visible?
    $notes_hold = false
    tree.post("events", [[list.node, "submit", 1]])
    frame
    check("the added button runs its handler, and a pick the mod holds back is refused and logged",
          [$notes_opened, held, page.visible?, layer_lines.grep(/refused/).last],
          [true, false, true, "Mod Notes refused submit of list #camp_shop_list in #camp_shop (Mod_Notes.rb:19)"])

    list.rows = [{ :text => "Herb" }, { :text => "Rope" }, { :text => "Torch" }]
    frame
    check("the owner's rows made anew keep the change", names_in(list), ["Herb", "Rope (noted)", "Torch"])
  end
end


BIG_TEXT = <<-RUBY
  Mod_Framework::UI.patch "#camp_notes" do |t|
    t.set "#title", text: "Big Text"
    t.replace "#badge" do
      text "Big badge"
    end
  end
RUBY

BOLD_TEXT = <<-RUBY
  Mod_Framework::UI.patch "#camp_notes" do |t|
    t.set "#title", text: "Bold Text"
    t.replace "#badge" do
      text "Bold badge"
    end
    t.hide "#clera"
  end
RUBY

BROKEN = <<-RUBY
  Mod_Framework::UI.patch "#camp_notes" do |t|
    t.set "#title", colr: :primary
  end
  Mod_Framework::UI.patch "#camp_notes" do |t|
    t.append "#buttons" do
      button "Broken"
    end
    raise "the notes are gone" if t.read(:count) > 1
  end
RUBY

# Two mods change the same part and a third one's patches fail: the last loaded wins and both are
# named, each failing patch is logged with its mod, file and line and switched off, and the window
# still opens with the rest.
in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Diary.rb", CAMP_NOTES.gsub("Camp_Notes", "Camp_Diary"))
    load_mod("Patch/Big_Text.rb", BIG_TEXT)
    load_mod("Patch/Bold_Text.rb", BOLD_TEXT)
    load_mod("Patch/Broken_Mod.rb", BROKEN)
    frame
    ui.open(Camp_Diary::NotesWindow)
    frame
    frame
    window = ui::Engine::Layer.tops.last.root.engine
    check("the window opens with the last loaded mod's changes and without the failing patches",
          shown_texts(window), ["Bold Text", "Buy herbs", "Rest", "Bold badge", "Clear", "Close"])
    check("the log names both mods of each conflict, each failure with its mod, file and line, and a selector that matches nothing",
          layer_lines.grep(/both (set|replace)|failed|matches nothing/).sort,
          ["Big Text and Bold Text both replace Camp_Diary::NoteBadge #badge; Bold Text loaded last, so its part shows",
           "Big Text and Bold Text both set text: of text #title; Bold Text loaded last, so its value is used",
           "Bold Text (Bold_Text.rb:6): hide \"#clera\" matches nothing inside window #camp_notes; did you mean #clear?; there: #title, #notes, #buttons, #clear, #close, text, list, stack, button",
           "Broken Mod (Broken_Mod.rb:2): the UI.patch of \"#camp_notes\" failed: text takes no colr:; did you mean color:?; Camp_Diary::NotesWindow shows without it for the rest of the session",
           "Broken Mod (Broken_Mod.rb:8): the UI.patch of \"#camp_notes\" failed: the notes are gone; Camp_Diary::NotesWindow shows without it for the rest of the session"])
  end
end

# The game's Ruby 1.9 refuses a private method called through self, which the tests' Ruby allows: UI.patch
# once looked up its candidates through self.index, so every patch failed in the game alone.
through_self = Dir[File.join(SCRIPTS_DIR, "*.rbx")].sort.map do |file|
  code = File.read(file)
  private_methods = code.scan(/private_class_method :(\w+[?!]?)/).flatten
  calls = code.scan(/(?<!def )(?<![\w.:])self\.(\w+[?!]?)(?!\s*=[^=])/).flatten
  (calls & private_methods).map { |name| "#{File.basename(file)}: self.#{name}" }
end.flatten
check("no script calls a private method of its module through self", through_self, [])
