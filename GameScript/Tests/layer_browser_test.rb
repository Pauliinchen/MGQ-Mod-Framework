#----------------------------------------------------------------
#  layer_browser_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Covered a list of cards one line high by most_rows:
#      Paulinchen  2026-11-06: Checked that a card's last line ends with the ellipsis where more does not fit
#                            - Called the engine's classes by their names under UI::Engine
#                            - Covered cards a click picks at once
#      Paulinchen  2026-11-05: Covered the cards stepping from three across to two while the filters are open
#                            - Covered the mods as rows with their picture at the left that share the height of their box
#                            - Created
#
#----------------------------------------------------------------

# Covers the parts of a mod browser a mod writes with the UI layer (design v2 section 5) in a
# booted game against FakeTree: mods as cards three across that a click picks at once, a spoiler blurred, and a pick that
# hands back the mod, two across while the filters are open with the same mod picked; the mods as six rows with their picture at the left, which share the height
# of their box; the mods in a box the keys enter, which tells when they go in and come out; the
# filter panel as a drawer beside the cards, as a strip while shut, and over the cards, closed by
# cancel.

require_relative "layer_support"

BROWSER = <<-RUBY
  module Camp_Browser
    UI = Mod_Framework::UI

    Mod = Struct.new(:name, :author, :summary, :shot, :spoiler)

    def self.mods
      [Mod.new("Map Display", "Ana", "Shows the map's name.", "Graphics/Pictures/camp", false),
       Mod.new("Night Camp", "Mia", "A camp at night.", "Graphics/Pictures/night", true),
       Mod.new("Level Cap", "Ana", "Caps the level.", "Graphics/Pictures/camp", false),
       Mod.new("Wide Text", "Ida", "Wider text boxes.", "Graphics/Pictures/camp", false)]
    end

    class Browser < UI::Component
      state :mod
      state :filters_open, false
      state(:visits) { [] }

      def mods
        Camp_Browser.mods
      end

      def render
        window "Mods", width: 620 do
          paper enter: true, id: :mods_box, on_enter: -> { self.visits = visits + [:in] }, on_leave: -> { self.visits = visits + [:out] } do
            list mods, look: :cards, columns: filters_open ? 2 : 3, text: :name, bind: :mod, click_picks: true,
                       picture: ->(mod) { { file: mod.shot, blur: mod.spoiler } },
                       lines: ->(mod) { ["by \#{mod.author}", mod.summary] }
          end
        end
      end
    end

    class OneLine < UI::Component
      def render
        window "Mods", width: 620 do
          list Camp_Browser.mods, look: :cards, most_rows: 1, text: :name, bind: :mod, picture: ->(mod) { { file: mod.shot } }
        end
      end
    end

    class ListView < UI::Component
      state :mod

      def render
        window "Mods", width: 620 do
          list Camp_Browser.mods, rows_shown: 6, height: :fill, text: :name, bind: :mod,
                                  picture: ->(mod) { { file: mod.shot, blur: mod.spoiler } },
                                  lines: ->(mod) { ["by \#{mod.author}  \#{mod.summary}"] }
        end
      end
    end

    class Filters < UI::Component
      param :variant, :persistent
      state :filters_open, false
      state(:closes) { [] }

      def render
        window "Mods", width: 620 do
          stack row: true, id: :browser_row do
            drawer bind: :filters_open, variant: variant, width: 200, on_change: ->(open) { self.closes = closes + [open] } do
              drawer_header do
                button "Close", id: :close_filters, on_click: -> { self.filters_open = false }
              end
              text "Updates only"
            end
            stack grow: 1 do
              button "Filters", id: :filters, on_click: -> { self.filters_open = !filters_open }
              list mods, bind: :mod
            end
          end
        end
      end

      def mods
        ["Map Display", "Level Cap"]
      end
    end
  end
RUBY

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    load_mod("Patch/Camp_Browser.rb", BROWSER)
    frame

    # The mods show as cards three across and two lines down, each with its screenshot, the
    # spoiler blurred, and its lines on a plate.
    ui.open(Camp_Browser::Browser)
    frame
    Graphics.update
    node = nodes_of(tree, "list").last
    cards = ui::Engine::Tree.component(node)
    props = tree.nodes[node][:props]
    check("the cards' pictures, the spoiler blurred and marked", cards.rows.map { |row| row[:picture] }.values_at(0, 1),
          [{ :file => "Graphics/Pictures/camp", :blur => false }, { :file => "Graphics/Pictures/night", :blur => true, :label => "Spoiler" }])
    check("a card's lines on its plate", cards.rows[0].values_at(:text, :lines, :plate), ["Map Display", ["by Ana", "Shows the map's name."], true])
    check("the cards stand three across, as high as a card with a picture, a click picking any of them", props.values_at("row_cells", "row_height", "click_picks"), [3, 192, true])
    check("a card's last line where more does not fit ends with the ellipsis",
          cards.send(:card_lines, "Caps the party's level until the next story chapter opens.", 120, 2), ["Caps the", "party's leve..."])

    # A pick binds the mod, not its card.
    tell(tree, [[node, "change", 3]])
    browser = ui::Engine::Layer.tops.last.mount.component
    check("the card picked binds its mod", browser.mod.name, "Wide Text")

    # The filters open beside the cards: two stand across, the cursor stays on the mod.
    browser.filters_open = true
    frame
    Graphics.update
    check("two cards across, the cursor still on Wide Text", [props["row_cells"], cards.index, browser.mod.name], [2, 3, "Wide Text"])

    # most_rows: counts lines of cards: the four cards take two lines, of which one shows and the
    # other scrolls.
    one_line = ui.open(Camp_Browser::OneLine)
    frame
    Graphics.update
    one = ui::Engine::Tree.component(nodes_of(tree, "list").last)
    check("a list of cards with most_rows: 1 is one line high and scrolls the second", [one.send(:lines_of, one.rows.size), one.measure[1]], [2, one.line_height])
    one_line.close
    frame

    # The list view: each mod a row with its screenshot at the left, as high as the picture; the six
    # rows share the height the box gives the list once it is placed.
    handle = ui.open(Camp_Browser::ListView)
    frame
    Graphics.update
    node = nodes_of(tree, "list").last
    rows = ui::Engine::Tree.component(node)
    check("each row's picture lies at its left, its line under the name", rows.rows.values_at(0, 1).map { |row| row.values_at(:picture_at, :lines) },
          [[:left, ["by Ana  Shows the map's name."]], [:left, ["by Mia  A camp at night."]]])
    check("a row is as high as its picture, 96 wide at 16:9", tree.nodes[node][:props]["row_height"], 62)
    tree.rects[node] = [0, 0, 600, 420]
    frame
    Graphics.update
    check("six rows share the 420 pixels of the box", [rows.line_height, tree.nodes[node][:props]["row_height"]], [70, 70])
    handle.close
    frame

    # The box of mods tells when the keys go inside it and come out.
    box = ui::Engine::Tree.roots.last.find(:mods_box)
    tell(tree, [[box.node, "went_in"]])
    tell(tree, [[box.node, "came_out"]])
    check("the box told on_enter and on_leave", browser.visits, [:in, :out])

    # The filter panel beside the mods takes no room while shut; Filters opens it at its width.
    handle = ui.open(Camp_Browser::Filters)
    frame
    Graphics.update
    filters = ui::Engine::Layer.tops.last.mount.component
    drawer = ui::Engine::Tree.roots.last.children.first.children.first
    check("the shut drawer takes no room", drawer.visible?, false)
    filters.filters_open = true
    frame
    Graphics.update
    check("the open drawer shows its header and body at its width", [drawer.visible?, drawer.body.visible?, tree.nodes[drawer.node][:props]["size"][0]], [true, true, 200])
    handle.close
    frame

    # A mini drawer keeps a strip with its header while shut.
    handle = ui.open(Camp_Browser::Filters, variant: :mini)
    frame
    Graphics.update
    drawer = ui::Engine::Tree.roots.last.children.first.children.first
    check("the shut mini drawer keeps its header in a strip", [drawer.visible?, drawer.body.visible?, tree.nodes[drawer.node][:props]["size"][0]], [true, false, 44])
    handle.close
    frame

    # A drawer over the cards opens as a root inside the row's left edge and takes the keys;
    # cancel closes it, its bound state turns false and the focus goes back to Filters.
    ui.open(Camp_Browser::Filters, variant: :temporary)
    frame
    Graphics.update
    filters = ui::Engine::Layer.tops.last.mount.component
    button = ui::Engine::Tree.roots.last.find(:filters)
    tree.post("states", { button.node => ui::Engine::Tree::FOCUSED })
    frame
    filters.filters_open = true
    frame
    Graphics.update
    over = ui::Engine::Tree.roots.last
    row = ui::Engine::Tree.roots.find { |root| root.find(:browser_row) }.find(:browser_row)
    check("the drawer opens over the row, inside its left edge", [over.is_a?(ui::Engine::Drawer), tree.nodes[over.node][:props].values_at("beside", "side", "captures")],
          [true, [row.node, "inside_left", true]])
    tell(tree, [[over.node, "close", "cancel"]])
    check("cancel closed it: its state, on_change and the focus on Filters", [filters.filters_open, filters.closes, ui::Engine::Tree.focused.equal?(button)], [false, [false], true])
  end
end
