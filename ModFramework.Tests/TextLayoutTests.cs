//----------------------------------------------------------------
//  TextLayoutTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Checked the rows of a log laid out through its topic
//      Paulinchen  2026-11-07: Wrote the cases of cutting and breaking a text in the tests instead of reading a fixture
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Checked a color code that names a color
//      Paulinchen  2026-11-04: Replayed each rule's golden cases in one test, checked the font topics in one flow test and
//                              took over the texts with escape codes from EscapesTests.cs
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Covered texts with the game's escape codes
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers cutting and breaking texts, laying out texts whose escape codes the game converted, and
/// the font topics the scripts measure and lay out through.
/// </summary>
public sealed class TextLayoutTests
{
    /// <summary>
    /// Asserts that a text that fits stays whole, that one too wide ends in an ellipsis, without the
    /// spaces before it and before a tail that always shows, and that a width too small for any
    /// letter leaves the ellipsis alone; a character twice as wide counts twice.
    /// </summary>
    [Fact]
    public void Cut_EndsATextTooWideWithAnEllipsis()
    {
        FontGlyphs font = AsciiFont();
        font.Learn(0x65E5, 20);

        Assert.Equal("Alice", TextLayout.Cut(font, "Alice", 50, string.Empty));
        Assert.Equal("Alice t...", TextLayout.Cut(font, "Alice the Monster Lord", 100, string.Empty));
        Assert.Equal("Ilia... (2F)", TextLayout.Cut(font, "Ilias Village", 120, " (2F)"));
        Assert.Equal("ab...", TextLayout.Cut(font, "ab   cdefgh", 80, string.Empty));
        Assert.Equal("...", TextLayout.Cut(font, "Alice", 20, string.Empty));
        Assert.Equal("\u65E5\u65E5...", TextLayout.Cut(font, "\u65E5\u65E5\u65E5\u65E5", 70, string.Empty));
    }

    /// <summary>
    /// Asserts that a text breaks at its words and its line breaks, its spaces collapsing, and that a
    /// word wider than a line breaks inside, starting a line of its own.
    /// </summary>
    [Fact]
    public void Wrap_BreaksAtWordsAndInsideAWordTooLong()
    {
        FontGlyphs font = AsciiFont();

        Assert.Equal(["Leave the", "party and", "go back"], TextLayout.Wrap(font, "Leave the party and go back", 100));
        Assert.Equal(["a", "Superca", "lifragi", "listic", "word"], TextLayout.Wrap(font, "a Supercalifragilistic word", 70));
        Assert.Equal(["Luka", "Alice"], TextLayout.Wrap(font, "  Luka\nAlice  ", 100));
    }

    /// <summary>
    /// Asserts that a text breaks into stretches that keep the spaces and the line break after a
    /// word, a word too long broken by the width with its rest joining the next word, and that a
    /// place in the text lies on the last stretch starting at or before it.
    /// </summary>
    [Fact]
    public void Spans_KeepTheSpacesWithTheWordBefore()
    {
        var cells = new FontGlyphs("cells", 1, false, cells: true);

        Assert.Equal([new TextSpan(0, 10), new TextSpan(10, 5)], TextLayout.Spans(cells, "Leave the party", 10));
        Assert.Equal([new TextSpan(0, 6), new TextSpan(6, 6)], TextLayout.Spans(cells, "first\nsecond", 10));
        Assert.Equal([new TextSpan(0, 5), new TextSpan(5, 5), new TextSpan(10, 5)], TextLayout.Spans(cells, "abcdefghijkl mn", 5));

        TextSpan[] lines = [new(0, 4), new(4, 3), new(7, 0)];
        Assert.Equal([0, 0, 1, 2, 2], new[] { 0, 3, 4, 7, 9 }.Select(place => TextLayout.SpanOf(lines, place)));
    }

    /// <summary>
    /// Asserts that a color code, by number or by a color name in small letters, colors the text
    /// after it until the next one, an icon is a run of
    /// its own as wide as the game draws it, every other code is dropped with its number, a lone
    /// escape at the end draws nothing, and a line break starts a new line, keeping an empty one,
    /// with the color carried over.
    /// </summary>
    [Fact]
    public void Escapes_ColorTheTextPlaceTheIconsAndDropTheRest()
    {
        TextLine colored = Assert.Single(Escapes.Lines(AsciiFont(), "a\eC[2]bc\eC[Legendary]d\eI[187]e", null));
        TextLine dropped = Assert.Single(Escapes.Lines(AsciiFont(), "\e{a\e}\e.b\eFS[20]c\e!\e", null));
        List<TextLine> broken = Escapes.Lines(AsciiFont(), "\eC[3]ab\n\ncd", null);
        TextLine empty = Assert.Single(Escapes.Lines(AsciiFont(), string.Empty, null));

        TextColor legendary = new(null, "legendary");
        Assert.Equal([new(0, "a", null, null), new(10, "bc", new TextColor(2, null), null), new(30, "d", legendary, null), new(40, string.Empty, null, 187), new(64, "e", legendary, null)], colored.Runs);
        Assert.Equal(74, colored.Width);
        Assert.Equal([new TextRun(0, "abc", null, null)], dropped.Runs);
        Assert.Equal([20, 0, 20], broken.ConvertAll(line => line.Width));
        Assert.Equal([new TextRun(0, "cd", new TextColor(3, null), null)], broken[2].Runs);
        Assert.Equal((0, 0), (empty.Width, empty.Runs.Count));
    }

    /// <summary>
    /// Asserts that a text with escape codes breaks before a word that does not fit, across a color
    /// change inside the word, leaves out the white space where it broke, breaks a word longer than
    /// the width inside it, and breaks at a no-break space as at a plain one.
    /// </summary>
    [Fact]
    public void Escapes_BreakAtTheWidth()
    {
        FontGlyphs font = AsciiFont();
        font.Learn(0xA0, 10);

        List<TextLine> lines = Escapes.Lines(font, "ab c\eC[1]de  fghijk", 40);
        List<TextLine> noBreak = Escapes.Lines(font, "ab cd", 30);
        TextColor one = new(1, null);

        Assert.Equal(
            [[new(0, "ab", null, null)], [new(0, "c", null, null), new(10, "de", one, null)], [new(0, "fghi", one, null)], [new(0, "jk", one, null)]],
            lines.ConvertAll(line => line.Runs));
        Assert.Equal([20, 30, 40, 20], lines.ConvertAll(line => line.Width));
        Assert.Equal([[new(0, "ab", null, null)], [new(0, "cd", null, null)]], noBreak.ConvertAll(line => line.Runs));
    }

    /// <summary>
    /// Asserts that the scripts define a font, cut, break and lay out by it with the new widths they
    /// hand over, that a character never measured counts as the font's size and is asked for once at
    /// the next drain, and that the font of cells breaks by characters without any widths.
    /// </summary>
    [Fact]
    public void Topics_LearnTheFontAndAskForWhatWasNeverMeasured()
    {
        var ui = new UiContext();
        _ = new UiText(new UiHost(ui.Context));
        var widths = new RubyHash();
        foreach (char letter in "abc. ")
        {
            widths.Add((long)letter, 6);
        }

        ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "name", "VL Gothic" }, { "size", 16 }, { "bold", false }, { "widths", widths } });
        RubyValue cut = ui.Value(UiText.CutTopic, new RubyArray { 1, 40, "abcabc日", "", new RubyHash { { (long)'日', 12 } } });
        RubyValue lines = ui.Value(UiText.WrapTopic, new RubyArray { 1, 30, "abc 本本", RubyNil.Value });
        RubyValue runs = ui.Value(UiText.RunsTopic, new RubyArray { 1, RubyNil.Value, "a\eC[2]日\eI[5]", RubyNil.Value });
        List<(string Topic, RubyValue Payload)> events = ui.Drain();
        RubyValue cells = ui.Value(UiText.SpansTopic, new RubyArray { UiText.CellsKey, 4, "ab cdefg", RubyNil.Value });

        Assert.Equal("abc...", cut.AsText());
        Assert.Equal(new RubyArray { "abc", "本", "本" }, lines);
        var expected = new RubyArray { new RubyHash { { "x", 0 }, { "text", "a" } }, new RubyHash { { "x", 6 }, { "text", "日" }, { "color", 2 } }, new RubyHash { { "x", 18 }, { "icon", 5 } } };
        Assert.Equal(new RubyArray { new RubyHash { { "width", 42 }, { "runs", expected } } }, runs);
        Assert.Equal([(UiText.WantedTopic, (RubyValue)new RubyHash { { "key", 1 }, { "points", new RubyArray { (long)'本' } } })], events);
        Assert.Empty(ui.Drain());
        Assert.Equal(new RubyArray { new RubyArray { 0, 3 }, new RubyArray { 3, 4 }, new RubyArray { 7, 1 } }, cells);
    }

    /// <summary>
    /// Asserts that the log topic lays out chat rows as a text box breaks its text: a name and its
    /// colon stay together across their parts, a line goes on in the part it broke in at x 0, and a
    /// word longer than the width starts a line of its own and breaks inside.
    /// </summary>
    [Fact]
    public void LogTopic_LaysOutRowsOfPartsAsATextBoxBreaksItsText()
    {
        var ui = new UiContext();
        _ = new UiText(new UiHost(ui.Context));
        var widths = new RubyHash();
        for (int point = 32; point < 127; point++)
        {
            widths.Add((long)point, 10);
        }

        ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "name", "VL Gothic" }, { "size", 16 }, { "bold", false }, { "widths", widths } });
        var rows = new RubyArray { new RubyArray { "Ana", ": wait at the inn" }, new RubyArray { "Mia", ": Supercalifragilistic" } };
        RubyValue lines = ui.Value(UiText.LogTopic, new RubyArray { 1, 100, rows, RubyNil.Value });

        var ana = new RubyArray
        {
            new RubyArray { new RubyArray { 0, 0, "Ana", 30 }, new RubyArray { 30, 1, ": wait ", 70 } },
            new RubyArray { new RubyArray { 0, 1, "at the inn", 100 } },
        };
        var mia = new RubyArray
        {
            new RubyArray { new RubyArray { 0, 0, "Mia", 30 }, new RubyArray { 30, 1, ": ", 20 } },
            new RubyArray { new RubyArray { 0, 1, "Supercalif", 100 } },
            new RubyArray { new RubyArray { 0, 1, "ragilistic", 100 } },
        };
        Assert.Equal(new RubyArray { ana, mia }, lines);
    }

    /// <summary>
    /// Builds a font in which every printable ASCII character is 10 pixels wide.
    /// </summary>
    /// <returns>The font.</returns>
    private static FontGlyphs AsciiFont()
    {
        var font = new FontGlyphs("test", 16, false);
        for (int point = 32; point < 127; point++)
        {
            font.Learn(point, 10);
        }

        return font;
    }
}
