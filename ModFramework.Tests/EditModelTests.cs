//----------------------------------------------------------------
//  EditModelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Handed the text box an input model
//      Paulinchen  2026-11-07: Replaced the replay of the scripts' editor with one flow of typing, moving and erasing
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Checked a box that types a whole number, a paste into it and the number it tells
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of typing, the view and the filters, and took over the
//                              replay of the scripts' editor from TextEditorTests.cs
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Covered the keyboard taking what is typed only while a box is open
//                            - Covered an allowed pattern that matches otherwise than in Ruby
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the text box: the editor typing, moving and erasing, and the box typed into through its
/// topics: typing from the keyboard,
/// stopping at Enter, what the box shows once drawn, the chat's filters, a locked box, the
/// patterns of allowed characters and a box that types a whole number.
/// </summary>
public sealed class EditModelTests
{
    /// <summary>
    /// The key bits of Home.
    /// </summary>
    private const int Home = (int)EditKeys.Home;

    /// <summary>
    /// What the player types.
    /// </summary>
    private readonly FakeTyping _keyboard = new();

    /// <summary>
    /// The bridge the box posts on.
    /// </summary>
    private readonly UiContext _ui = new();

    /// <summary>
    /// Adds the fonts and the text box, typing from the test's keyboard, to a host on the test's
    /// bridge, and defines font 1, in which every printable ASCII character is 10 pixels wide.
    /// </summary>
    public EditModelTests()
    {
        var host = new UiHost(_ui.Context);
        host.Add(new EditModel(host, new UiText(host), _keyboard, new InputModel(host, new FakeInput())));
        var widths = new RubyHash();
        for (int point = 32; point < 127; point++)
        {
            widths.Add(point, 10);
        }

        _ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "name", "test" }, { "size", 16 }, { "bold", false }, { "widths", widths } });
    }

    /// <summary>
    /// Asserts that the editor types at the cursor up to its most characters, that the arrows, Home
    /// and End move the cursor and Delete and Backspace erase around it, that Enter and Escape end
    /// typing without changing the text, and that the cursor blinks once nothing moved it.
    /// </summary>
    [Fact]
    public void Editor_TypesMovesAndErasesAroundTheCursor()
    {
        var editor = new TextEditor("world", 7);

        editor.Follow(EditKeys.Left);
        EditOutcome typed = editor.Type('X');
        editor.Follow(EditKeys.Home);
        editor.Follow(EditKeys.Delete);
        (string Text, int Cursor) afterDelete = (editor.Text, editor.Cursor);
        editor.Follow(EditKeys.End);
        EditOutcome[] filling = [.. "!?.".Select(letter => editor.Type(letter))];
        EditOutcome erased = editor.Type('\b');

        Assert.Equal((EditOutcome.Typed, ("orlXd", 0)), (typed, afterDelete));
        Assert.Equal([EditOutcome.Typed, EditOutcome.Typed, EditOutcome.Refused], filling);
        Assert.Equal((EditOutcome.Erased, "orlXd!", 6), (erased, editor.Text, editor.Cursor));
        Assert.Equal((EditOutcome.Enter, EditOutcome.Escape, "orlXd!"), (editor.Type('\r'), editor.Type(0x1B), editor.Text));

        Assert.True(editor.CursorShown);
        for (int tick = 0; tick < TextEditor.BlinkTicks; tick++)
        {
            editor.Follow(EditKeys.None);
        }

        Assert.False(editor.CursorShown);
    }

    /// <summary>
    /// Asserts that the keyboard takes typing only while a box is open, that a tick types what came
    /// from it and posts the text with what typing did, that Enter stops typing until the owner
    /// acted, the rest refused in the next tick, that a quiet box posts nothing, and that closing a
    /// box drops what waited, a tick of its id moving nothing in the next box, and closing a box no
    /// longer open leaves the keyboard on for the one that is.
    /// </summary>
    [Fact]
    public void Typing_TakesTheKeyboardWhileABoxIsOpenAndStopsAtEnter()
    {
        int id = Open(new RubyHash { { "text", "ab" }, { "max_chars", 4 } });
        bool opened = _keyboard.Active;
        _keyboard.Typed.Enqueue(("cd\rxyz", 6));
        RubyHash first = Event(_ui.Tick(Edit(id)));
        RubyHash second = Event(_ui.Tick(Edit(id)));
        List<(string Topic, RubyValue Payload)> quiet = _ui.Tick(new RubyHash { { "edit", new RubyArray { id, -1, 0, 0, 0 } } });

        Assert.True(opened);
        Assert.Equal(("abcd", 4, new RubyArray { "typed", "typed", "enter" }, 6, 6), (first["text"].AsText(), first["cursor"].AsInt(), first["outcomes"], first["keys"].AsInt(), first["chars"].AsInt()));
        Assert.Equal(("abcd", new RubyArray { "refused", "refused", "refused" }, 0), (second["text"].AsText(), second["outcomes"], second["keys"].AsInt()));
        Assert.Empty(quiet);

        _keyboard.Typed.Enqueue(("a\rb", 3));
        _ui.Tick(Edit(id));
        _ui.Value(EditModel.CloseTopic, id);
        int next = Open(new RubyHash { { "text", "" } });
        int third = Open(new RubyHash { { "text", "" } });
        List<(string Topic, RubyValue Payload)> stale = _ui.Tick(Edit(id));
        _ui.Value(EditModel.CloseTopic, next);
        bool afterStale = _keyboard.Active;
        RubyHash fresh = Event(_ui.Tick(Edit(third)));
        _ui.Value(EditModel.CloseTopic, third);

        Assert.Empty(stale);
        Assert.True(afterStale);
        Assert.Equal(("", new RubyArray()), (fresh["text"].AsText(), fresh["outcomes"]));
        Assert.False(_keyboard.Active);
    }

    /// <summary>
    /// Asserts that a box drawn on one line shows the part around the cursor with the cursor's place
    /// in pixels, a password as stars, an empty mask as the text itself, and follows the keys; and
    /// that a box of several lines shows its lines, the first in sight, the cursor's line and its
    /// place, and scrolls by the wheel.
    /// </summary>
    [Fact]
    public void View_ShowsThePartAroundTheCursorAndTheLines()
    {
        int masked = Open(new RubyHash { { "text", "abcdefgh" }, { "mask", "*" } });
        RubyHash drawn = View(masked, 35, 0);
        RubyHash home = Event(_ui.Tick(new RubyHash { { "edit", new RubyArray { masked, Home, 0, 0, 0 } } }));
        int plain = Open(new RubyHash { { "text", "abc" }, { "mask", "" } });

        Assert.Equal(new RubyArray { 5, 3, 30 }, drawn["view"].AsHash()["line"]);
        Assert.Equal(new RubyArray { 0, 3, 0 }, home["view"].AsHash()["line"]);
        Assert.Equal(new RubyArray { 0, 3, 30 }, View(plain, 100, 0)["view"].AsHash()["line"]);

        int lines = Open(new RubyHash { { "text", "aa bb cc dd" } });
        RubyArray area = View(lines, 30, 2)["view"].AsHash()["area"].AsArray();
        RubyArray scrolled = Event(_ui.Tick(new RubyHash { { "edit", new RubyArray { lines, -1, 0, -1, 0 } } }))["view"].AsHash()["area"].AsArray();

        Assert.Equal(new RubyArray { new RubyArray { 0, 3 }, new RubyArray { 3, 3 }, new RubyArray { 6, 3 }, new RubyArray { 9, 2 } }, area[0]);
        Assert.Equal(new RubyArray { 2, 3, 20 }, new RubyArray { area[1], area[2], area[3] });
        Assert.Equal(new RubyArray { 1, 2, 20 }, new RubyArray { scrolled[1], scrolled[2], scrolled[3] });
    }

    /// <summary>
    /// Asserts the chat's filters, the opening key's character left out once and what Alt types
    /// dropped; that a box locked by the owner keeps its text against typing, Delete and the game's
    /// letters while the cursor still moves and Escape still comes through; and that the game's
    /// letters type at once into an open box, answering what typing did.
    /// </summary>
    [Fact]
    public void Filters_AndALock_KeepWhatTheOwnerAskedFor()
    {
        int id = Open(new RubyHash { { "text", "" }, { "echo", new RubyArray { 'T', 3 } }, { "alt_codes", 2 } });
        _keyboard.Typed.Enqueue(("tt", 1));
        string echoed = Event(_ui.Tick(Edit(id)))["text"].AsText();
        _keyboard.Typed.Enqueue(("@", 1));
        string altHeld = Event(_ui.Tick(new RubyHash { { "edit", new RubyArray { id, -1, 1, 0, 1 } } }))["text"].AsText();
        _keyboard.Typed.Enqueue(("x", 1));
        string justAfter = Event(_ui.Tick(Edit(id)))["text"].AsText();
        _ui.Context.Call(System.Text.Encoding.UTF8.GetBytes(EditModel.SetTopic), RubyMarshal.Write(new RubyHash { { "id", id }, { "locked", true } }), new byte[256]);
        _keyboard.Typed.Enqueue(("y\r\u001b", 3));
        RubyHash locked = Event(_ui.Tick(Edit(id)));
        RubyHash home = Event(_ui.Tick(new RubyHash { { "edit", new RubyArray { id, Home, 0, 0, 0 } } }));
        List<(string Topic, RubyValue Payload)> deleted = _ui.Tick(new RubyHash { { "edit", new RubyArray { id, (int)EditKeys.Delete, 0, 0, 0 } } });
        RubyHash letters = _ui.Value(EditModel.TypeTopic, new RubyHash { { "id", id }, { "text", "x\u001b" } }).AsHash();

        Assert.Equal(("t", "t", "t"), (echoed, altHeld, justAfter));
        Assert.Equal(("t", new RubyArray { "escape" }), (locked["text"].AsText(), locked["outcomes"]));
        Assert.Equal(("t", 0), (home["text"].AsText(), home["cursor"].AsInt()));
        Assert.DoesNotContain(deleted, item => item.Topic == EditModel.EventTopic && item.Payload.AsHash()["text"].AsText() != "t");
        Assert.Equal(new RubyHash { { "outcomes", new RubyArray { "refused", "escape" } }, { "text", "t" }, { "cursor", 0 } }, letters);

        int digits = Open(new RubyHash { { "text", "1" }, { "allowed", new RubyArray { @"\A\d\z", false } } });
        RubyHash typed = _ui.Value(EditModel.TypeTopic, new RubyHash { { "id", digits }, { "text", "2a\b" } }).AsHash();

        Assert.Equal(new RubyHash { { "outcomes", new RubyArray { "typed", "refused", "erased" } }, { "text", "1" }, { "cursor", 1 } }, typed);
    }

    /// <summary>
    /// Asserts that a box that types a whole number refuses a letter and a minus behind digits but
    /// takes one in front while its least number lies below 0, that a paste goes in whole or, holding
    /// anything but digits, not at all, and that the box tells the number its text gives within its
    /// bounds, none for a lone minus; and that a box whose least number is 0 refuses the minus.
    /// </summary>
    [Fact]
    public void NumberBox_KeepsAWholeNumberAndTellsItWithinItsBounds()
    {
        int id = Open(new RubyHash { { "text", "12" }, { "number", new RubyArray { -50, 100 } } });
        _keyboard.Typed.Enqueue(("a", 1));
        RubyHash letter = Event(_ui.Tick(Edit(id)));
        _keyboard.Typed.Enqueue(("-", 1));
        RubyHash minusBehind = Event(_ui.Tick(Edit(id)));
        _ui.Tick(new RubyHash { { "edit", new RubyArray { id, Home, 0, 0, 0 } } });
        _keyboard.Typed.Enqueue(("-", 1));
        RubyHash minusInFront = Event(_ui.Tick(Edit(id)));
        _ui.Tick(new RubyHash { { "edit", new RubyArray { id, (int)EditKeys.End, 0, 0, 0 } } });
        _keyboard.Typed.Enqueue(("3x", 2));
        RubyHash badPaste = Event(_ui.Tick(Edit(id)));
        _keyboard.Typed.Enqueue(("345", 2));
        RubyHash paste = Event(_ui.Tick(Edit(id)));
        _keyboard.Typed.Enqueue(("\b\b\b\b\b", 5));
        RubyHash erased = Event(_ui.Tick(Edit(id)));

        Assert.Equal(("12", new RubyArray { "refused" }, 12), (letter["text"].AsText(), letter["outcomes"], letter["number"].AsInt()));
        Assert.Equal(("12", new RubyArray { "refused" }), (minusBehind["text"].AsText(), minusBehind["outcomes"]));
        Assert.Equal(("-12", -12), (minusInFront["text"].AsText(), minusInFront["number"].AsInt()));
        Assert.Equal(("-12", new RubyArray { "refused" }), (badPaste["text"].AsText(), badPaste["outcomes"]));
        Assert.Equal(("-12345", new RubyArray { "typed" }, -50), (paste["text"].AsText(), paste["outcomes"], paste["number"].AsInt()));
        Assert.Equal(("-", true), (erased["text"].AsText(), erased["number"].IsNil));

        int unsigned = Open(new RubyHash { { "text", "" }, { "number", new RubyArray { 0, RubyNil.Value } } });
        _keyboard.Typed.Enqueue(("-7", 2));
        RubyHash refused = Event(_ui.Tick(Edit(unsigned)));
        _keyboard.Typed.Enqueue(("7", 1));
        RubyHash seven = Event(_ui.Tick(Edit(unsigned)));

        Assert.Equal(("", new RubyArray { "refused" }), (refused["text"].AsText(), refused["outcomes"]));
        Assert.Equal(("7", 7), (seven["text"].AsText(), seven["number"].AsInt()));
    }

    /// <summary>
    /// Asserts that a Ruby pattern .NET reads otherwise, a POSIX bracket here, fails the open instead
    /// of opening a box that refuses every key, while a pattern read alike opens.
    /// </summary>
    [Fact]
    public void Open_RefusesAPatternThatMatchesOtherwiseThanInRuby()
    {
        var inRuby = new RubyArray { "a5é-", new RubyArray { true, true, true, false } };

        RubyHash? posix = _ui.Call(EditModel.OpenTopic, new RubyHash { { "text", "" }, { "allowed", new RubyArray { "[[:alnum:]]", false } }, { "allowed_check", inRuby } });
        RubyHash? alike = _ui.Call(EditModel.OpenTopic, new RubyHash { { "text", "" }, { "allowed", new RubyArray { "[a-z0-9é]", false } }, { "allowed_check", inRuby } });

        Assert.Equal(
            (BridgeEnvelope.BadRequest, "The :allowed pattern [[:alnum:]] matches 'a' in Ruby but not in the DLL."),
            (posix!["error"].AsText(), posix["text"].AsText()));
        Assert.True(alike!["ok"].AsBool());
    }

    /// <summary>
    /// Builds a box's input that takes what was typed, without keys.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <returns>The tick's input.</returns>
    private static RubyHash Edit(int id) => new() { { "edit", new RubyArray { id, -1, 1, 0, 0 } } };

    /// <summary>
    /// Finds the box's event among a frame's events.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The event.</returns>
    private static RubyHash Event(List<(string Topic, RubyValue Payload)> events) => events.Single(item => item.Topic == EditModel.EventTopic).Payload.AsHash();

    /// <summary>
    /// Opens a box.
    /// </summary>
    /// <param name="settings">Its text and settings.</param>
    /// <returns>Its id.</returns>
    private int Open(RubyHash settings) => _ui.Value(EditModel.OpenTopic, settings).AsInt();

    /// <summary>
    /// Asks what a box shows drawn in font 1.
    /// </summary>
    /// <param name="id">The box.</param>
    /// <param name="width">The width it is drawn in.</param>
    /// <param name="rows">Its rows, 0 for one line.</param>
    /// <returns>The answer.</returns>
    private RubyHash View(int id, int width, int rows) =>
        _ui.Value(EditModel.ViewTopic, new RubyHash { { "id", id }, { "font", 1 }, { "width", width }, { "rows", rows } }).AsHash();
}
