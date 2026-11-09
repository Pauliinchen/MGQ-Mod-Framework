#----------------------------------------------------------------
#  layer_form_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Checked a chip of two icons side by side
#      Paulinchen  2026-11-07: Filtered the kinds by a toggle group that a click and the digits turn on, and showed the
#                              tags as chips that take no input
#      Paulinchen  2026-11-06: Took Remove in a chip's context menu in its menu of the UI layer
#                            - Checked that a form moves the focus into a field of a component of its own through its handle
#      Paulinchen  2026-11-05: Checked that the completions are the words that hold the word typed, that a select's
#                              menu lies above its dialog, and that a window under a dialog keeps its look
#                            - Checked that a completion taken goes into the field and its bound state
#                            - Checked that a disabled select opens nothing and shows no arrow, and an open one keeps its look
#      Paulinchen  2026-11-04: Created
#
#----------------------------------------------------------------

# Covers the form parts of the UI layer's dialogs (design v2 section 5.3) in a booted game against
# FakeTree, through a mod's item search: a search field under its label, bound to a state, that
# steers the list under it and offers the words that hold the word typed, one of which the
# search takes, kind toggles turned on by a click and by a digit, tag chips that take no input and
# a chip of two element icons side by side, a filter select whose menu turns a value on above the
# dialog, a sort select bound to one value, a disabled select that opens nothing, and a select in
# a window that keeps its look while its menu is open and while a dialog lies over the window;
# last, a form whose note field is a component of its own, into which the form moves the focus
# through the component's handle.

require_relative "layer_support"

SEARCH = <<-RUBY
  module Item_Search
    UI = Mod_Framework::UI

    class SearchDialog < UI::Component
      state :search, ""
      state(:kinds) { [] }
      state(:tags) { ["Rare", "Cursed"] }
      state(:filters) { [] }
      state :sort, :name
      state(:submitted) { [] }
      state(:completed) { [] }

      def render
        dialog "Pick an item", on_submit: ->(item) { self.submitted = submitted + [item] } do
          text_field "Item name", bind: :search, placeholder: "Search", steer: :items, completions: ["Herb", "Hermit Cloak", "Rope"],
                     on_complete: ->(word) { self.completed = completed + [[word, search]] }
          toggle_group bind: :kinds, multi: true, number_keys: true do
            toggle_item "Weapons", value: :weapon
            toggle_item "Armor", value: :armor
          end
          chip_set most: 5 do
            tags.each { |tag| chip tag, key: tag }
            chip icons: [96, 97], tooltip: "Fire, Ice", key: :elements
          end
          select placeholder: "Filter", bind: :filters, multi: true do
            select_item "Favorites", value: :favorite
            select_item "Usable", value: :usable
          end
          select "Sort by", bind: :sort do
            select_item "Name", value: :name
            select_item "Price", value: :price
          end
          select "Group by", disabled: true do
            select_item "Kind", value: :kind
          end
          list matching, id: :items
        end
      end

      def matching
        ["Herb", "Rope", "Hermit Cloak"].select { |name| name.downcase.include?(search.downcase) }
      end
    end

    class NoteField < UI::Component
      state :note, ""

      def render
        text_field "Note", bind: :note, id: :note_text
      end
    end

    class NoteForm < UI::Component
      def render
        window "Notes" do
          note_field id: :note_card
          button "Write a note", id: :write, on_click: -> { part(:note_card).focus }
        end
      end
    end

    class SortWindow < UI::Component
      state :sort, :name

      def render
        window "Sort" do
          select "Sort by", bind: :sort do
            select_item "Name", value: :name
            select_item "Price", value: :price
          end
        end
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  fake = tree_dll(tree)
  opened = []
  fake.answer("ui.edit.open") { |request| opened << request; opened.size }
  fake.answer("ui.edit.close") { |_id| nil }
  fake.answer("ui.edit.set") { |_request| nil }
  fake.answer("ui.edit.view") { |_request| { "id" => opened.size, "text" => "", "cursor" => 0, "shown" => true, "view" => { "line" => [0, 0, 0] } } }
  boot_tree(fake) do
    ui = Mod_Framework::UI
    load_mod("Patch/Item_Search.rb", SEARCH)
    frame

    # The search opens empty over the whole list, which its arrows steer.
    ui.open(Item_Search::SearchDialog)
    frame
    search = ui::Engine::Layer.tops.last.mount.component
    field = ui::Engine::Tree.component(nodes_of(tree, "text_field").last)
    list = ui::Engine::Tree.component(nodes_of(tree, "list").last)
    caption = field.parent.children.first
    check("the search shows its label above it and its placeholder, and steers the list written after it from the first frame",
          [caption.text, field.placeholder, field.instance_variable_get(:@steered).equal?(list), list.rows.size, layer_lines.grep(/steer/)],
          ["Item name", "Search", true, 3, []])

    # The player types "ER": the bound search narrows the list and the field offers completions.
    tell(tree, [[field.node, "focus"]])
    $dll.post("ui.edit", "id" => opened.size, "text" => "ER", "cursor" => 2, "shown" => true, "outcomes" => ["typed"], "keys" => 1, "chars" => 1)
    frame
    frame
    check("typing narrows the list through the bound search, and the completions are the words that hold it anywhere, ignoring case",
          [search.search, list.rows, field.completions], ["ER", ["Herb", "Hermit Cloak"], ["Herb", "Hermit Cloak"]])
    $dll.post("ui.edit", "id" => opened.size, "text" => "ER", "cursor" => 2, "shown" => true, "outcomes" => ["enter"], "keys" => 1, "chars" => 0)
    frame
    frame
    check("Enter puts the lit completion into the field, which the bound search keeps before on_complete hears it, and no completion is left",
          [search.search, field.text, list.rows, field.completions, search.completed], ["Herb", "Herb", ["Herb"], [], [["Herb", "Herb"]]])
    $dll.post("ui.edit", "id" => opened.size, "text" => "Herb", "cursor" => 4, "shown" => true, "outcomes" => ["enter"], "keys" => 1, "chars" => 0)
    frame
    check("Enter again picks the row of the list it steers", search.submitted, ["Herb"])

    # A click on the Armor toggle turns it on, and once the search stops typing the digit 1 turns
    # Weapons on beside it.
    find = lambda { |klass| ui::Engine::Tree.component(tree.nodes.keys.sort.find { |node| ui::Engine::Tree.component(node).is_a?(klass) }) }
    toggles = find.call(ui::Engine::ToggleGroup)
    tell(tree, [[toggles.children[1].node, "click"]])
    check("a click on a toggle turns its value on", search.kinds, [:armor])
    tell(tree, [[field.node, "blur"]])
    $keys = { 0x31 => 3 }
    frame
    Graphics.update
    $keys = nil
    frame
    Graphics.update
    check("the digit 1 turns the first toggle on too, the values in the toggles' order", search.kinds, [:weapon, :armor])

    # The tags only show: their chips take no focus and nothing answers a click.
    tags = find.call(ui::Engine::Chips)
    props = tree.nodes[tags.chip(0).node][:props]
    tell(tree, [[tags.chip(0).node, "click"]])
    check("a chip takes no focus and a click on it changes nothing [focusable, acts, tags]", [props["focusable"], props["acts"], search.tags],
          [false, false, ["Rare", "Cursed"]])

    # The chip of the elements draws both icons side by side in its middle, and C# sizes it to
    # them: two icons of 16 px with 2 px between them, and 3 px on either side.
    elements = tags.chip(2)
    Graphics.update
    place = elements.rect
    left = place.x - elements.surface.x
    top = place.y - elements.surface.y
    drawn = elements.surface.bitmap.copies.select { |x, y, _picture| x >= left && x < left + place.width && y >= top && y < top + place.height }.map { |x, _y, _picture| x - left }
    check("a chip of two icons draws them side by side in its middle and asks for their room [lefts, padding]",
          [drawn, tree.nodes[elements.node][:props]["padding"]], [[(place.width - 34) / 2, (place.width - 34) / 2 + 18], [2, 3, 2, 37]])

    # The filter's menu turns Usable on, and the sort select, bound to one value, picks Price.
    depths = []
    pick = lambda do |dropdown, row|
      tell(tree, [[dropdown.node, "click"]])
      menu = ui::Engine::Tree.component(tree.nodes.keys.sort.reverse.find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::DropdownMenu) })
      depths << [menu.z, dropdown.root.z]
      tell(tree, [[menu.instance_variable_get(:@list).node, "submit", row]])
    end
    filter, sort, group = nodes_of(tree, "button").map { |node| ui::Engine::Tree.component(node) }.select { |each| each.is_a?(ui::Engine::Dropdown) }
    pick.call(filter, 1)
    check("a value turned on in the filter's menu reaches the bound state", [search.filters, filter.values], [[:usable], [:usable]])
    check("the filter's menu lies above the dialog it was opened from", depths[0][0] > depths[0][1], true)
    check("the sort select shows its one bound value", sort.shown_text, "Name")
    pick.call(sort, 1)
    check("a pick in a select without multi: binds that one value", [search.sort, sort.shown_text], [:price, "Price"])

    # The disabled select opens nothing, by a click or by confirm, which C#'s tree also tells as a
    # click, and shows no arrow.
    tell(tree, [[group.node, "click"]])
    group.surface.bitmap.fills.clear
    [group, sort].each { |dropdown| dropdown.redraw }
    frame
    Graphics.update
    arrow = lambda do |dropdown|
      left = dropdown.rect.x - dropdown.surface.x
      top = dropdown.rect.y - dropdown.surface.y
      dropdown.surface.bitmap.fills.any? do |x, y, width, height|
        height == 1 && width == ui::Engine::Dropdown::ARROW && x >= left && x < left + dropdown.rect.width && y >= top && y < top + dropdown.rect.height
      end
    end
    check("a disabled select opens no menu and shows no arrow, the others theirs", [group.menu_open?, arrow.call(group), arrow.call(sort)], [false, false, true])

    # A select in a window waits under its open menu in its own look.
    ui::Engine::Layer.tops.last.handle.close
    ui.open(Item_Search::SortWindow)
    frame
    alone = ui::Engine::Tree.component(nodes_of(tree, "button").reverse.find { |node| ui::Engine::Tree.component(node).is_a?(ui::Engine::Dropdown) })
    tell(tree, [[alone.node, "click"]])
    frame
    check("a select whose menu is open only waits under it, in its own look", [alone.menu_open?, alone.root.held_under, alone.draws_enabled?], [true, true, true])

    # A dialog opens over the window: the window's select takes no input there but keeps its look.
    tell(tree, [[alone.node, "click"]])
    ui.open(Item_Search::SearchDialog)
    frame
    check("a select in a window under a dialog keeps its look", [alone.menu_open?, alone.root.held_under, alone.draws_enabled?], [false, true, true])

    # The form's button moves the focus into its note field, a component of its own.
    ui::Engine::Layer.tops.reverse_each { |top| top.handle.close unless top.closed }
    ui.open(Item_Search::NoteForm)
    frame
    form = ui::Engine::Layer.tops.last.root.engine
    tell(tree, [[form.find(:write).node, "click"]])
    asked = ui::Engine::Tree.component(tree.changes.map { |change| change["focus_in"] }.compact.last)
    check("the button asked C# to move the focus into the note field, the part that holds it and no more [holds the field, the whole window]",
          [asked.find(:note_text).equal?(form.find(:note_text)), asked.equal?(form)], [true, false])
  end
end
