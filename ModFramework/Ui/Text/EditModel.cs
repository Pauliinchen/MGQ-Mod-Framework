//----------------------------------------------------------------
//  EditModel.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Told a run of refused characters, such as the rest of a paste past the most, as one refusal
//      Paulinchen  2026-11-11: Moved the caret by no direction whose numpad digit typed in the same tick
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Opened a box that types a whole number by its rule, typed what came in one tick into it as one,
//                              and told the number it gives
//      Paulinchen  2026-10-31: Typed nothing of a key that left a text field, in its tick or the next few
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Took what is typed only while a box is open
//                            - Kept a locked box from changing its text by Delete or the game's letters
//                            - Showed an empty mask as the text itself
//                            - Refused an allowed pattern that matches otherwise than in Ruby
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// The text box being typed into, one at a time, joined with the keyboard: each tick its owner puts
/// in, it takes what was typed straight from the keyboard, types it, follows the keys that type
/// nothing, and posts the box's text, cursor and the part a box shows, with what typing did.
/// </summary>
/// <remarks>
/// Typing stops at Enter or Escape and keeps the rest for the next tick, after the owner acted on
/// them; closing the box drops it, as the scripts dropped what came after Enter. The keyboard takes
/// what is typed only while a box is open, so no key typed elsewhere waits for the next box.
/// </remarks>
internal sealed class EditModel : IUiModel
{
    /// <summary>
    /// Opens a box: {"text", "max_chars", "allowed" ([source, ignore case] of a Ruby pattern of one
    /// character), "allowed_check" ([characters, whether each matches the pattern in Ruby]), "mask"
    /// (the character shown for each), "echo" ([key, ticks]), "alt_codes" (ticks), "locked", "number"
    /// ([least, largest], each nil for none, for a box that types a whole number)}, each but the text
    /// optional; answers the box's id.
    /// </summary>
    public const string OpenTopic = "ui.edit.open";

    /// <summary>
    /// Closes the box of an id, dropping what was typed and not taken, and stops taking what is typed.
    /// </summary>
    public const string CloseTopic = "ui.edit.close";

    /// <summary>
    /// Changes the box of an id, staged by its owner: {"id"} with "text" and "cursor", "locked" or
    /// "echo".
    /// </summary>
    public const string SetTopic = "ui.edit.set";

    /// <summary>
    /// Tells the box where it is drawn and answers what it shows: {"id", "font", "width", "rows"},
    /// "rows" 0 for a box of one line.
    /// </summary>
    public const string ViewTopic = "ui.edit.view";

    /// <summary>
    /// Types characters into the box at once, for the game's letters a gamepad picks: {"id",
    /// "text"}, answering {"outcomes", "text", "cursor"}; a locked box refuses all but Escape.
    /// </summary>
    public const string TypeTopic = "ui.edit.type";

    /// <summary>
    /// The box's event: {"id", "text", "cursor", "shown", "outcomes", "keys", "chars", "view"}, and
    /// "number" in a box that types a whole number: the number its text gives, nil for none.
    /// </summary>
    public const string EventTopic = "ui.edit";

    /// <summary>
    /// Code point of Escape, which a locked box still takes.
    /// </summary>
    private const int EscapePoint = 0x1B;

    /// <summary>
    /// The game's four directions with the key of each that moves the caret.
    /// </summary>
    private static readonly (UiButton Direction, EditKeys Key)[] Directions =
        [(UiButton.Left, EditKeys.Left), (UiButton.Right, EditKeys.Right), (UiButton.Up, EditKeys.Up), (UiButton.Down, EditKeys.Down)];

    /// <summary>
    /// The host the box posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The fonts the box measures in.
    /// </summary>
    private readonly UiText _text;

    /// <summary>
    /// The keyboard.
    /// </summary>
    private readonly ITypedText _keyboard;

    /// <summary>
    /// The input model, which tells the numpad's digits that typed.
    /// </summary>
    private readonly InputModel _input;

    /// <summary>
    /// Characters typed and not typed into the box yet, since typing stopped at Enter or Escape.
    /// </summary>
    private readonly Queue<int> _pending = new();

    /// <summary>
    /// What the last event said of the box, so an unchanged box posts nothing.
    /// </summary>
    private string? _posted;

    /// <summary>
    /// The open box, null while none is.
    /// </summary>
    private Box? _box;

    /// <summary>
    /// The id the last box got.
    /// </summary>
    private int _lastId;

    /// <summary>
    /// The character of a key that left a text field, which no box types, and the frame it left in;
    /// null for none.
    /// </summary>
    private (int Character, long Frame)? _dropped;

    /// <summary>
    /// Creates the model and registers its topics.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    /// <param name="text">The fonts.</param>
    /// <param name="keyboard">What the player types.</param>
    /// <param name="input">The input model of the same host.</param>
    public EditModel(UiHost host, UiText text, ITypedText keyboard, InputModel input)
    {
        ArgumentNullException.ThrowIfNull(host);
        _host = host;
        _text = text;
        _keyboard = keyboard;
        _input = input;
        BridgeContext context = host.Context;
        context.Register(OpenTopic, (_, request) => Open(request.AsHash()));
        context.Register(CloseTopic, (_, request) =>
        {
            if (_box?.Id == request.AsInt())
            {
                _box = null;
                _pending.Clear();
                _keyboard.SetActive(false);
            }

            return null;
        });
        context.Register(SetTopic, (_, request) =>
        {
            Set(request.AsHash());
            return null;
        });
        context.Register(ViewTopic, (_, request) => View(request.AsHash()));
        context.Register(TypeTopic, (_, request) => TypeNow(request.AsHash()));
    }

    /// <inheritdoc />
    public string Name => "edit";

    /// <summary>
    /// Gets the open box's editor, null while none is open.
    /// </summary>
    public TextEditor? Editor => _box?.Editor;

    /// <summary>
    /// Gets the frames after a key left a text field in which its character still types nothing.
    /// </summary>
    public static int DropFrames => 3;

    /// <summary>
    /// Has no box type the character of a key that left a text field, such as the 0 of the numpad's 0,
    /// in this frame or the next <see cref="DropFrames"/>, into whichever box is open then.
    /// </summary>
    /// <param name="key">Windows' code of the key.</param>
    public void Drop(int key)
    {
        int? character = key switch
        {
            >= 0x41 and <= 0x5A or >= 0x30 and <= 0x39 => key,
            >= 0x60 and <= 0x69 => '0' + (key - 0x60),
            0x20 => ' ',
            _ => null,
        };
        _dropped = character is int known ? (known, _host.Now) : null;
    }

    /// <summary>
    /// Types what came from the keyboard, follows the keys and the wheel, and posts what changed:
    /// [id, keys or -1 for none, 1 to take what was typed, lines to scroll, 1 while the left Alt is held].
    /// </summary>
    /// <param name="input">The owner's input.</param>
    public void Tick(RubyValue input)
    {
        RubyArray values = input.AsArray();
        Box? box = _box;
        if (box is null || box.Id != values[0].AsInt())
        {
            return;
        }

        int keys = values[1].AsInt();
        bool alt = values.Count > 4 && values[4].AsInt() != 0;
        var outcomes = new RubyArray();
        int typedKeys = 0;
        int chars = 0;
        if (values[2].AsInt() != 0)
        {
            (string typed, typedKeys) = _keyboard.Take();
            chars = CodePoints.Of(typed).Length;
            foreach (int point in Filtered(box, typed, alt))
            {
                _pending.Enqueue(point);
            }

            TypePending(box, outcomes);
        }

        if (keys >= 0)
        {
            EditKeys follow = WithoutNumpad(box.Locked ? (EditKeys)keys & ~EditKeys.Delete : (EditKeys)keys);
            box.Editor.Follow(follow, box.Rows > 0 ? Spans(box) : null);
        }

        int scroll = values[3].AsInt();
        if (scroll != 0 && box.Rows > 0 && Spans(box) is { } spans)
        {
            box.Editor.ScrollLines(spans, box.Rows, scroll);
        }

        RubyHash state = State(box);
        string signature = state.ToString();
        if (outcomes.Count == 0 && typedKeys == 0 && chars == 0 && signature == _posted)
        {
            return;
        }

        _posted = signature;
        state["outcomes"] = outcomes;
        state["keys"] = typedKeys;
        state["chars"] = chars;
        _host.Post(EventTopic, state);
    }

    /// <summary>
    /// Builds the pattern a typed character must match from a Ruby pattern of one character.
    /// </summary>
    /// <remarks>
    /// ECMAScript's classes cover ASCII only, as Ruby's \d and \w do.
    /// </remarks>
    /// <param name="source">The pattern's source, such as \A\d\z.</param>
    /// <param name="ignoreCase">Whether it ignores case.</param>
    /// <returns>The pattern.</returns>
    public static Regex PatternOf(string source, bool ignoreCase) =>
        new(source, RegexOptions.ECMAScript | (ignoreCase ? RegexOptions.IgnoreCase : RegexOptions.None), TimeSpan.FromMilliseconds(50));

    /// <summary>
    /// Proves that a pattern takes the same characters as the Ruby pattern it was built from.
    /// </summary>
    /// <remarks>
    /// .NET reads Ruby syntax such as [[:alnum:]] or \h without an error and then matches nothing, so
    /// without the proof such a box would refuse every key and nothing would say why.
    /// </remarks>
    /// <param name="pattern">The pattern built from the Ruby pattern.</param>
    /// <param name="check">[characters, whether each matches in Ruby], nil for no proof.</param>
    /// <exception cref="BridgeRequestException">A character matches in one and not in the other.</exception>
    public static void Prove(Regex pattern, RubyValue check)
    {
        if (check.IsNil)
        {
            return;
        }

        RubyArray pair = check.AsArray();
        RubyArray inRuby = pair[1].AsArray();
        int index = 0;
        foreach (Rune character in pair[0].AsText().EnumerateRunes())
        {
            bool matches = pattern.IsMatch(character.ToString());
            bool rubyMatches = index < inRuby.Count && inRuby[index].AsBool();
            if (matches != rubyMatches)
            {
                string where = rubyMatches ? "in Ruby but not in the DLL" : "in the DLL but not in Ruby";
                throw new BridgeRequestException($"The :allowed pattern {pattern} matches '{character}' {where}.");
            }

            index++;
        }
    }

    /// <summary>
    /// Opens a box, closing the one open, and starts taking what is typed.
    /// </summary>
    /// <param name="request">The box, see <see cref="OpenTopic"/>.</param>
    /// <returns>Its id.</returns>
    private RubyValue Open(RubyHash request)
    {
        RubyValue allowed = request["allowed"];
        Regex? pattern = allowed.IsNil ? null : PatternOf(allowed.AsArray()[0].AsText(), allowed.AsArray()[1].AsBool());
        if (pattern is not null)
        {
            Prove(pattern, request["allowed_check"]);
        }

        RubyValue most = request["max_chars"];
        var editor = new TextEditor(request["text"].AsText(), most.IsNil ? null : most.AsInt(), pattern, NumberRuleOf(request["number"]));
        _box = new Box(++_lastId, editor)
        {
            Mask = MaskOf(request["mask"]),
            AltCodeTicks = request["alt_codes"].IsNil ? 0 : request["alt_codes"].AsInt(),
            Locked = request["locked"] is RubyBool { Flag: true },
        };
        SetEcho(_box, request["echo"]);
        _pending.Clear();
        _keyboard.SetActive(true);
        _posted = null;
        return _box.Id;
    }

    /// <summary>
    /// Changes the open box, if it is the one named.
    /// </summary>
    /// <param name="request">The change, see <see cref="SetTopic"/>.</param>
    private void Set(RubyHash request)
    {
        Box? box = _box;
        if (box is null || box.Id != request["id"].AsInt())
        {
            return;
        }

        if (request.ContainsKey("text"))
        {
            box.Editor.Edit(request["text"].AsText(), request["cursor"].AsInt());
        }

        if (request.ContainsKey("locked"))
        {
            box.Locked = request["locked"].AsBool();
        }

        if (request.ContainsKey("echo"))
        {
            SetEcho(box, request["echo"]);
        }
    }

    /// <summary>
    /// Keeps where the open box is drawn and tells what it shows.
    /// </summary>
    /// <param name="request">Where, see <see cref="ViewTopic"/>.</param>
    /// <returns>The box's state, nil when the box named is not open.</returns>
    private RubyValue? View(RubyHash request)
    {
        Box? box = _box;
        if (box is null || box.Id != request["id"].AsInt())
        {
            return null;
        }

        box.Font = _text.Font(request["font"].AsInt());
        box.Width = request["width"].AsInt();
        box.Rows = request["rows"].AsInt();
        RubyHash state = State(box);
        _posted = state.ToString();
        return state;
    }

    /// <summary>
    /// Types characters into the open box at once.
    /// </summary>
    /// <param name="request">The characters, see <see cref="TypeTopic"/>.</param>
    /// <returns>What typing did and the text after it, nil when the box named is not open.</returns>
    private RubyValue? TypeNow(RubyHash request)
    {
        Box? box = _box;
        if (box is null || box.Id != request["id"].AsInt())
        {
            return null;
        }

        var outcomes = new RubyArray();
        foreach (int point in CodePoints.Of(request["text"].AsText()))
        {
            outcomes.Add(NameOf(box.Locked && point != EscapePoint ? EditOutcome.Refused : box.Editor.Type(point)));
        }

        return new RubyHash { { "outcomes", outcomes }, { "text", box.Editor.Text }, { "cursor", box.Editor.Cursor } };
    }

    /// <summary>
    /// Types what waits until Enter or Escape, which the owner acts on before the rest is typed. A box
    /// that types a whole number types the characters that came together as one, so a paste goes in
    /// whole or not at all. Refused characters in a row tell one refusal.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="outcomes">Where what typing did goes.</param>
    private void TypePending(Box box, RubyArray outcomes)
    {
        EditOutcome told = EditOutcome.None;
        while (_pending.Count > 0)
        {
            int point = _pending.Dequeue();
            if (box.Locked && point != EscapePoint)
            {
                continue;
            }

            EditOutcome outcome;
            if (box.Editor.Number is not null && !CodePoints.IsControl(point))
            {
                var together = new List<int> { point };
                while (_pending.Count > 0 && !CodePoints.IsControl(_pending.Peek()))
                {
                    together.Add(_pending.Dequeue());
                }

                outcome = box.Editor.TypeAll(together);
            }
            else
            {
                outcome = box.Editor.Type(point);
            }

            if (outcome != EditOutcome.None && !(outcome == EditOutcome.Refused && told == EditOutcome.Refused))
            {
                outcomes.Add(NameOf(outcome));
                told = outcome;
            }

            if (outcome is EditOutcome.Enter or EditOutcome.Escape)
            {
                return;
            }
        }
    }

    /// <summary>
    /// Leaves out of what was typed the character of the key that opened the box, which arrives
    /// after it opened, and what was typed while the left Alt is held and just after, which the
    /// numpad types as an Alt code.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="typed">What was typed this tick.</param>
    /// <param name="alt">Whether the left Alt is held.</param>
    /// <returns>The code points to type.</returns>
    private ReadOnlySpan<int> Filtered(Box box, string typed, bool alt)
    {
        int[] points = Undropped(CodePoints.Of(typed));
        int from = 0;
        if (box.EchoKey is int key)
        {
            box.EchoTicks--;
            if (box.EchoTicks <= 0 || points.Length > 0)
            {
                box.EchoKey = null;
            }

            if (points.Length > 0 && AsciiUpper(points[0]) == key)
            {
                from = 1;
            }
        }

        if (box.AltCodeTicks > 0)
        {
            box.AltLeft = alt ? box.AltCodeTicks : Math.Max(box.AltLeft - 1, 0);
            if (box.AltLeft > 0 && points.Length > from)
            {
                _host.Context.Log.Write(string.Create(CultureInfo.InvariantCulture, $"ui: dropped {points.Length - from} characters typed with Alt"));
                return [];
            }
        }

        return points.AsSpan(from);
    }

    /// <summary>
    /// Leaves out of the keys the directions whose numpad digit typed this tick, which the game reads
    /// as the direction too.
    /// </summary>
    /// <param name="keys">The keys the scripts read.</param>
    /// <returns>The keys that move the caret.</returns>
    private EditKeys WithoutNumpad(EditKeys keys)
    {
        foreach ((UiButton direction, EditKeys key) in Directions)
        {
            if (_input.NumpadTyped(direction))
            {
                keys &= ~key;
            }
        }

        return keys;
    }

    /// <summary>
    /// Builds the open box's state for its event.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <returns>{"id", "text", "cursor", "shown", "view"}, the view nil until the box was drawn, and "number" in a box that types one.</returns>
    private static RubyHash State(Box box)
    {
        TextEditor editor = box.Editor;
        var state = new RubyHash { { "id", box.Id }, { "text", editor.Text }, { "cursor", editor.Cursor }, { "shown", editor.CursorShown }, { "view", ViewOf(box) } };
        if (editor.Number is not null)
        {
            state["number"] = editor.Settled is int number ? number : RubyNil.Value;
        }

        return state;
    }

    /// <summary>
    /// Reads the rule of a box that types a whole number.
    /// </summary>
    /// <param name="number">[least, largest] as the owner sent it, each nil for none; nil for a box of any text.</param>
    /// <returns>The rule, null for a box of any text.</returns>
    private static NumberRule? NumberRuleOf(RubyValue number)
    {
        if (number.IsNil)
        {
            return null;
        }

        RubyArray bounds = number.AsArray();
        return new NumberRule(bounds[0].IsNil ? null : bounds[0].AsInt(), bounds[1].IsNil ? null : bounds[1].AsInt());
    }

    /// <summary>
    /// Works out what a box shows: in a box of one line {"line" => [first, count, cursor x]}, in a
    /// box of several {"area" => [spans, first line, cursor's line, cursor x]}.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <returns>The view, nil until the box was drawn.</returns>
    private static RubyValue ViewOf(Box box)
    {
        if (box.Font is not { } font)
        {
            return RubyNil.Value;
        }

        TextEditor editor = box.Editor;
        int[] points = [.. editor.Points];
        if (box.Rows <= 0)
        {
            TextSpan shown = editor.Visible(font, box.Width, box.Mask);
            int[] display = box.Mask is int star ? Array.ConvertAll(points, _ => star) : points;
            int x = TextLayout.Width(font, display.AsSpan(shown.Start, editor.Cursor - shown.Start));
            return new RubyHash { { "line", new RubyArray { shown.Start, shown.Length, x } } };
        }

        List<TextSpan> spans = TextLayout.Spans(font, points, box.Width);
        int top = editor.FirstLine(spans, box.Rows);
        int line = TextLayout.SpanOf(spans, editor.Cursor);
        int cursorX = TextLayout.Width(font, points.AsSpan(spans[line].Start, editor.Cursor - spans[line].Start));
        return new RubyHash { { "area", new RubyArray { UiText.SpansValue(spans), top, line, cursorX } } };
    }

    /// <summary>
    /// Breaks the box's text into the lines it is drawn in.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <returns>The lines, null until the box was drawn.</returns>
    private static List<TextSpan>? Spans(Box box) => box.Font is { } font ? TextLayout.Spans(font, [.. box.Editor.Points], box.Width) : null;

    /// <summary>
    /// Reads the character a box shows for each of its text's.
    /// </summary>
    /// <param name="mask">The mask as the owner sent it, nil for none.</param>
    /// <returns>Its first character, null for nil and for an empty mask, which shows the text itself.</returns>
    private static int? MaskOf(RubyValue mask)
    {
        int[] points = mask.IsNil ? [] : CodePoints.Of(mask.AsText());
        return points.Length > 0 ? points[0] : null;
    }

    /// <summary>
    /// Sets or clears the key whose character the box leaves out once.
    /// </summary>
    /// <param name="box">The box.</param>
    /// <param name="echo">[key, ticks], nil for none.</param>
    private static void SetEcho(Box box, RubyValue echo)
    {
        box.EchoKey = echo.IsNil ? null : echo.AsArray()[0].AsInt();
        box.EchoTicks = echo.IsNil ? 0 : echo.AsArray()[1].AsInt();
    }

    /// <summary>
    /// Upper-cases an ASCII letter, as Ruby 1.9's upcase does; any other code point stays.
    /// </summary>
    /// <param name="point">The code point.</param>
    /// <returns>The code point upper-cased.</returns>
    private static int AsciiUpper(int point) => point is >= 'a' and <= 'z' ? point - ('a' - 'A') : point;

    /// <summary>
    /// Leaves out the first character of a key that left a text field, while it may still come.
    /// </summary>
    /// <param name="points">What was typed.</param>
    /// <returns>What was typed without it.</returns>
    private int[] Undropped(int[] points)
    {
        if (_dropped is not { } dropped || _host.Now - dropped.Frame > DropFrames)
        {
            _dropped = null;
            return points;
        }

        int at = Array.FindIndex(points, point => AsciiUpper(point) == dropped.Character);
        if (at < 0)
        {
            return points;
        }

        _dropped = null;
        return [.. points[..at], .. points[(at + 1)..]];
    }

    /// <summary>
    /// Names an outcome as the scripts read it.
    /// </summary>
    /// <param name="outcome">The outcome.</param>
    /// <returns>"enter", "escape", "tab", "typed", "erased", "refused" or "none".</returns>
    private static string NameOf(EditOutcome outcome) => outcome.ToString().ToLowerInvariant();

    /// <summary>
    /// The open box: its editor, what it shows its text as, how it filters what is typed, and where
    /// it is drawn.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="editor">Its editor.</param>
    private sealed class Box(int id, TextEditor editor)
    {
        /// <summary>Gets the box's id.</summary>
        public int Id { get; } = id;

        /// <summary>Gets the box's editor.</summary>
        public TextEditor Editor { get; } = editor;

        /// <summary>Gets or sets the character shown for each of the text's, null for the text itself.</summary>
        public int? Mask { get; set; }

        /// <summary>Gets or sets whether the box takes no typing but Escape, and no Delete.</summary>
        public bool Locked { get; set; }

        /// <summary>Gets or sets the Windows code of the key whose character the box leaves out once, null for none.</summary>
        public int? EchoKey { get; set; }

        /// <summary>Gets or sets the ticks the key's character may still arrive in.</summary>
        public int EchoTicks { get; set; }

        /// <summary>Gets or sets the ticks after Alt was let go in which what arrives is dropped, 0 for none.</summary>
        public int AltCodeTicks { get; set; }

        /// <summary>Gets or sets the ticks left in which what arrives is dropped.</summary>
        public int AltLeft { get; set; }

        /// <summary>Gets or sets the font the box is drawn in, null until it was drawn.</summary>
        public FontGlyphs? Font { get; set; }

        /// <summary>Gets or sets the width its text may take.</summary>
        public int Width { get; set; }

        /// <summary>Gets or sets the lines a box of several lines shows, 0 for a box of one line.</summary>
        public int Rows { get; set; }
    }
}
