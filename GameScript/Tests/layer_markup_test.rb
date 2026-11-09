#----------------------------------------------------------------
#  layer_markup_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Checked that compact_for: makes a part of hidden copies and refuses a copy of another id
#                            - Checked that compact: makes a part of the forms and refuses a form param the part lacks
#      Paulinchen  2026-11-06: Checked that a component's own param refuses a lambda with the way to give live data
#      Paulinchen  2026-11-04: Checked each refused markup on its own
#                            - Folded the checks of refused markup into fewer checks
#                            - Checked each rule in one check
#                            - Covered nil on a handler param as no handler
#                            - Covered where a first render notes the place of a part
#                            - Created
#
#----------------------------------------------------------------

# Covers the markup of the UI layer in a booted game: each markup call is checked against its
# built-in's declaration and a mistake raises at the call with the nearest name and the mod's file
# and line (design section 4.9), a part with compact: becomes a part of its forms, one with
# compact_for: a part of its hidden copies, and a first render notes where a part was written.

require_relative "layer_support"

# The mod file the markup below is written in.
GEAR_COMPARE = "Patch/Gear_Compare.rb"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    frame

    # Runs markup written at line 42 of a mod and tells the message it raised.
    #
    # @param code [String] The markup.
    # @return [String, nil] The message, nil when it raised nothing.
    mistake = lambda do |code|
      block = eval("lambda { #{code} }", TOPLEVEL_BINDING, GEAR_COMPARE, 42)
      begin
        ui::Engine::Builder.capture { ui::Engine::MarkupProxy.run(block) }
        nil
      rescue ui::Engine::MarkupError => e
        e.message
      end
    end

    # Each mistake a mod makes in its markup is refused with what to write instead.
    check("a misspelled param names the nearest one", mistake.call('button "Give", colour: :error'), "button takes no colour:; did you mean color:? (Gear_Compare.rb:42)")
    check("a wrong value names the nearest", mistake.call('text "Hi", typo: :subtitle'),
          "typo: :subtitle is not one of :h6, :subtitle1, :subtitle2, :body1, :body2, :caption, :overline; did you mean :subtitle1? (Gear_Compare.rb:42)")
    check("a param that takes no lambda refuses one", mistake.call('stack id: -> { :x }'), "id: takes no lambda (Gear_Compare.rb:42)")
    load_mod(GEAR_COMPARE, "module Gear_Compare
 class Score < Mod_Framework::UI::Component
 param :value
 def render; text value.to_s; end
 end
end")
    check("a component's own param refuses a lambda and tells how to give live data",
          mistake.call('component Gear_Compare::Score, value: -> { 3 }'),
          "value: takes no lambda#{ui::Engine::Declarations::OWN_LAMBDA} (Gear_Compare.rb:42)")
    check("a handler refuses what is no lambda, method name or nil", mistake.call('button "Go", on_click: 3'),
          "on_click: takes a lambda, a method name or nil, not 3 (Gear_Compare.rb:42)")
    check("nil on a handler is no handler, so the button takes no keys",
          ui::Engine::Declarations[:button].spec[:options].call(:text => "Go", :on_click => nil)[:acts], false)
    check("too many values are refused", mistake.call('button "Go", "Now"'), "button takes 1 value (text) before its params, not 2 (Gear_Compare.rb:42)")
    check("a block on a part that holds nothing is refused", mistake.call('text("Hi") { }'), "text takes no block of markup (Gear_Compare.rb:42)")
    check("a mistake inside a block is told at its own line", mistake.call("stack do\n button 'Go', on_clik: :close\n end"),
          "button takes no on_clik:; did you mean on_click:? (Gear_Compare.rb:43)")
    check("a root inside another part is refused", mistake.call("stack do\n window 'Inner' do\n end\n end"),
          "window is a root, so it goes at the top of a render, not inside stack (Gear_Compare.rb:43)")
    outside = begin
      ui::Engine::Builder.build(:text, ["Hi"], nil, nil)
    rescue ui::Engine::MarkupError => e
      e.message
    end
    check("markup outside a render is refused", outside[/\Atext is markup, which works only inside render or a block of markup/],
          "text is markup, which works only inside render or a block of markup")

    # A part with compact: becomes its forms: the part itself with its id, then a copy per form by its step.
    shrinking = eval("lambda { lines ['a', 'b'], id: :effects, grow: 1, compact: { 2 => { size: :tiny }, 1 => { most_rows: 1 } } }", TOPLEVEL_BINDING, GEAR_COMPARE, 42)
    forms = ui::Engine::Builder.capture { ui::Engine::MarkupProxy.run(shrinking) }.first
    check("a part with compact: holds itself and a copy per form in the order of their steps",
          [forms.type, forms.params[:steps], forms.params[:grow], forms.children.map { |node| [node.params[:id], node.params[:most_rows], node.params[:size]] }],
          [:forms, [0, 1, 2], 1, [[:effects, nil, nil], [nil, 1, nil], [nil, nil, :tiny]]])
    check("a compact form with a param the part lacks is refused", mistake.call("lines ['a'], compact: { 1 => { most_row: 1 } }"),
          "lines takes no most_row:; did you mean most_rows:? (Gear_Compare.rb:42)")
    check("a compact form cannot change the id", mistake.call("lines ['a'], compact: { 1 => { id: :small } }"), "compact: a form cannot change id: (Gear_Compare.rb:42)")

    # A part with compact_for: holds itself with its id, then a hidden copy per entry.
    sized = eval("lambda { text 'Short', id: :name, compact_for: [{ text: 'A much longer name' }] }", TOPLEVEL_BINDING, GEAR_COMPARE, 42)
    copies = ui::Engine::Builder.capture { ui::Engine::MarkupProxy.run(sized) }.first
    check("a part with compact_for: holds itself and a hidden copy per entry",
          [copies.type, copies.key, copies.children.map { |node| [node.params[:id], node.params[:text], node.params[:visible]] }],
          [:measures, :name, [[:name, "Short", nil], [nil, "A much longer name", false]]])
    check("a copy cannot change the id", mistake.call("text 'a', compact_for: [{ id: :b }]"), "compact_for: a copy cannot change id: (Gear_Compare.rb:42)")

    # A first render notes where a part was written once a sibling of its type came before without
    # key:.
    written = eval("lambda { stack do\n text 'A'\n button 'Go'\n text 'B', key: :b\n 3.times { |n| text n.to_s }\n end }", TOPLEVEL_BINDING, GEAR_COMPARE, 42)
    sites = ui::Engine::Builder.capture(true) { ui::Engine::MarkupProxy.run(written) }.first.children.map { |node| node.site }
    check("only the parts after a sibling of their type note their site", sites, [nil, nil, nil, "Gear_Compare.rb:46", "Gear_Compare.rb:46", "Gear_Compare.rb:46"])
  end
end
