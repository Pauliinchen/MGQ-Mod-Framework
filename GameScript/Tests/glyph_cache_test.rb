#----------------------------------------------------------------
#  glyph_cache_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Drew a cached text with the outline and opacity the cache now takes
#      Paulinchen  2026-11-06: Removed the check of the timing of both ways to draw a text
#                            - Called the engine's classes by their names under UI::Engine
#      Paulinchen  2026-11-05: Checked that a text needing more characters than a frame draws whole and builds them in a
#                              later frame
#      Paulinchen  2026-11-04: Checked the room for the outline of a text at the edge of a window
#                            - Kept a few flows of texts drawn from copies of their characters and checked each outcome on its own
#                            - Rewrote the checks as flow tests of texts drawn from copies of their characters
#                            - Checked each rule in one check
#                            - Covered the characters on shared sheets
#                            - Created
#
#----------------------------------------------------------------

# Covers glyph_cache.rbx in a booted game: a text built from copies of its characters where
# draw_text would put them, each character drawn once per look, Japanese characters drawn as a
# text first needs them, the texts left to draw_text, the cache kept within its budget on a few
# shared sheets, and the timing of draw_text against the copies.

require_relative "tree_support"

in_game_folder do
  tree = FakeTree.new
  boot_tree(tree_dll(tree)) do
    ui = Mod_Framework::UI
    cache = ui::Engine::GlyphCache
    cache.on = true
    picture = lambda do
      bitmap = Bitmap.new(200, 24)
      ui::Engine::Style.use_font(bitmap, 20, ui::Engine::Style::TEXT)
      bitmap
    end

    # A text is built from copies of its characters where draw_text puts it, outlines first and
    # letters over them, each character drawn once.
    bitmap = picture.call
    check("a text is built from copies of its characters", cache.draw(bitmap, 10, 0, 200, 24, "Ab"), true)
    check("outlines go first and letters over them where draw_text puts them", bitmap.texts, [[10, 0, "A"], [20, 0, "b"], [10, 0, "A"], [20, 0, "b"]])
    whole = ui::Engine::LabelCache.draw("é", 20, ui::Engine::Style::TEXT, nil, nil, 100, 24, 0, nil).bitmap
    ui::Engine::Key.next_frame
    window = ui::Engine::Window.new(:at => [0, 0], :size => [200, 100]).open
    window.add_label("Ab")
    frame
    frame
    Graphics.update
    contents = window.base_surface.bitmap.texts.find { |text| text[2] == "A" }
    check("a character's copy, a text draw_text draws whole and a text at the edge of a window keep room left of their first letter for its outline",
          [bitmap.rooms["A"] > 0, whole.rooms["é"] > 0, contents && contents[0] > 0], [true, true, true])
    window.close
    frame
    copied = cache.size[0]
    cache.draw(picture.call, 0, 0, 200, 24, "bAbA")
    ui::Engine::Key.next_frame
    japanese = picture.call
    check("Japanese characters are drawn as a text first needs them", cache.draw(japanese, 0, 0, 200, 24, "勇者ルカ"), true)
    cache.width(japanese, "勇者ルカ")

    # Texts left to draw_text: a combining mark, a text too wide for its box, every text while the
    # cache is off.
    check("a text with a combining mark is left to draw_text", cache.draw(picture.call, 0, 0, 200, 24, "é"), false)
    cache.draw(picture.call, 0, 0, 30, 24, "Wide")
    cache.on = false
    cache.draw(picture.call, 0, 0, 200, 24, "Ab")
    cache.on = true

    # Many different characters stay within the budget on the few shared sheets, none made anew as
    # full sheets are cleared (ddb8f1fa).
    made = []
    Bitmap.class_eval do
      alias_method :uncounted_initialize, :initialize
      define_method(:initialize) { |*args| uncounted_initialize(*args); made << self }
    end
    cache.clear
    many = picture.call
    made.clear
    3000.times do |index|
      ui::Engine::Key.next_frame
      cache.draw(many, 0, 0, 200, 24, [0x4E00 + index].pack("U"))
    end
    check("many characters stay within the budget", cache.size[1] <= cache::BUDGET, true)
    check("the characters lie on the few shared sheets and the picture that measures", made.size, cache::MOST_SHEETS + 1)
    first = picture.call
    count = made.size
    cache.draw(first, 0, 0, 200, 24, "一")
    cache.clear
    check("the cleared cache frees every picture it made", made.reject { |made_one| made_one.equal?(first) || made_one.disposed? }, [])
    Bitmap.class_eval { alias_method :initialize, :uncounted_initialize }

    # A font that sets a pair closer than its letters, and one whose copies look otherwise than
    # draw_text, are left to draw_text, each logged once.
    cache.clear
    Bitmap.class_eval do
      alias_method :whole_text_size, :text_size
      define_method(:text_size) { |text| size = whole_text_size(text); text.to_s.include?("AV") ? Rect.new(0, 0, size.width - 2, size.height) : size }
    end
    kerned = nil
    ui::Engine::Key.next_frame
    lines = logged_lines { kerned = cache.draw(picture.call, 0, 0, 200, 24, "Ab") }
    Bitmap.class_eval { alias_method :text_size, :whole_text_size }
    check("a font that kerns is left to draw_text, logged", [kerned, lines.grep(/sets "AV" closer than its letters/).size], [false, 1])
    cache.clear
    Bitmap.class_eval { define_method(:get_pixel) { |x, _y| Color.new(255, 255, 255, texts.any? { |left, _top, _text| left == x } ? 255 : 0) } }
    looked = nil
    ui::Engine::Key.next_frame
    lines = logged_lines { looked = cache.draw(picture.call, 0, 0, 200, 24, "Ab") }
    Bitmap.class_eval { remove_method :get_pixel }
    check("a font whose copies look otherwise is left to draw_text, logged", [looked, lines.grep(/of the sample's pixels differ/).size], [false, 1])

    # A frame builds the characters of its first text, but a later text of the same frame that needs
    # more than the frame has left draws whole and builds them in a later frame.
    cache.clear
    ui::Engine::Key.next_frame
    first_text = cache.draw(picture.call, 0, 0, 200, 24, "Attack")
    later_text = cache.draw(picture.call, 0, 0, 200, 24, "Defense")
    ui::Engine::Key.next_frame
    check("texts of one frame [the first built, a later one whole, the later one built a frame on]",
          [first_text, later_text, cache.draw(picture.call, 0, 0, 200, 24, "Defense")], [true, false, true])

  end
end
