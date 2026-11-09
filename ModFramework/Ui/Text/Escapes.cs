//----------------------------------------------------------------
//  Escapes.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Read a color code's color name as well as its number
//      Paulinchen  2026-10-29: Broke lines at no-break spaces too
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// The color a color code gives: a game text color by its number, or a color name such as primary,
/// which the scripts look up in the theme.
/// </summary>
/// <param name="Number">The game's text color, null for a name.</param>
/// <param name="Name">The color name in small letters, null for a number.</param>
public readonly record struct TextColor(int? Number, string? Name);

/// <summary>
/// A stretch of a line drawn in one go: text in one color, or one icon.
/// </summary>
/// <param name="X">Where it starts, in pixels from the line's start.</param>
/// <param name="Text">The text, empty for an icon.</param>
/// <param name="Color">The color a code gave the text, null for the color the text starts in and
/// for an icon.</param>
/// <param name="Icon">The IconSet index of an icon, null for text.</param>
public readonly record struct TextRun(int X, string Text, TextColor? Color, int? Icon);

/// <summary>
/// A line of a text with the game's escape codes.
/// </summary>
/// <param name="Width">Its width in pixels, without the white space at its end.</param>
/// <param name="Runs">Its runs, left to right.</param>
public sealed record TextLine(int Width, List<TextRun> Runs);

/// <summary>
/// Lays out a text whose escape codes the game's own <c>convert_escape_characters</c> turned into
/// <c>\e</c> codes, as <c>Window_Base#draw_text_ex</c> draws it: <c>\eC[n]</c> or <c>\eC[name]</c>
/// changes the color, <c>\eI[n]</c> draws an icon, a line break starts a new line, and every other code is dropped,
/// font size changes and waits among them.
/// </summary>
public static class Escapes
{
    /// <summary>
    /// The width an icon takes, as the game's <c>process_draw_icon</c> moves on.
    /// </summary>
    public const int IconWidth = 24;

    /// <summary>
    /// The code that sets the text's color.
    /// </summary>
    private const string ColorCode = "C";

    /// <summary>
    /// The code that draws an icon.
    /// </summary>
    private const string IconCode = "I";

    /// <summary>
    /// The code point that starts an escape code.
    /// </summary>
    private const int EscapePoint = 0x1B;

    /// <summary>
    /// The code point of a line break.
    /// </summary>
    private const int NewLinePoint = '\n';

    /// <summary>
    /// The codes of one sign, as the game's <c>obtain_escape_code</c> reads them; any other code is
    /// a run of letters.
    /// </summary>
    private const string SignCodes = "$.|^!><{}\\";

    /// <summary>
    /// Lays a text out in lines.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="text">The text with its <c>\e</c> codes.</param>
    /// <param name="width">The width in pixels the lines break at, before a word and inside a word
    /// longer than it; null to break only at the text's line breaks.</param>
    /// <returns>The lines, one empty line for an empty text.</returns>
    public static List<TextLine> Lines(FontGlyphs glyphs, string text, int? width)
    {
        var lines = new List<TextLine>();
        foreach (List<Piece> paragraph in Paragraphs(glyphs, CodePoints.Of(text)))
        {
            Break(paragraph, width, lines);
        }

        return lines;
    }

    /// <summary>
    /// Writes lines as the scripts read them.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <returns>Per line {"width", "runs"}, each run {"x", "text"} with "color" (a number or a
    /// color name) when the text changed it, or {"x", "icon"}.</returns>
    public static RubyArray Value(IEnumerable<TextLine> lines)
    {
        var value = new RubyArray();
        foreach (TextLine line in lines)
        {
            var runs = new RubyArray();
            foreach (TextRun run in line.Runs)
            {
                var entry = new RubyHash { { "x", run.X } };
                if (run.Icon is int icon)
                {
                    entry["icon"] = icon;
                }
                else
                {
                    entry["text"] = run.Text;
                    if (run.Color is { Number: int number })
                    {
                        entry["color"] = number;
                    }
                    else if (run.Color is { Name: string name })
                    {
                        entry["color"] = name;
                    }
                }

                runs.Add(entry);
            }

            value.Add(new RubyHash { { "width", line.Width }, { "runs", runs } });
        }

        return value;
    }

    /// <summary>
    /// Reads a text into the pieces of its paragraphs, which its line breaks end: its characters
    /// and icons with their colors and widths.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="points">The text's code points.</param>
    /// <returns>The paragraphs.</returns>
    private static List<List<Piece>> Paragraphs(FontGlyphs glyphs, int[] points)
    {
        var paragraphs = new List<List<Piece>> { new() };
        TextColor? color = null;
        int at = 0;
        while (at < points.Length)
        {
            int point = points[at++];
            if (point == NewLinePoint)
            {
                paragraphs.Add([]);
            }
            else if (point == EscapePoint)
            {
                (string code, string? parameter, at) = CodeAt(points, at);
                if (code == ColorCode)
                {
                    color = ColorOf(parameter);
                }
                else if (code == IconCode)
                {
                    paragraphs[^1].Add(new Piece(0, NumberOf(parameter) ?? 0, null, IconWidth));
                }
            }
            else if (!CodePoints.IsControl(point))
            {
                paragraphs[^1].Add(new Piece(point, null, color, glyphs.Width(point)));
            }
        }

        return paragraphs;
    }

    /// <summary>
    /// Reads the escape code after a <c>\e</c>: one sign, or a run of letters with a number or a
    /// name in brackets when one follows, which a letter code the game knows takes and an unknown
    /// one drops.
    /// </summary>
    /// <param name="points">The text's code points.</param>
    /// <param name="at">The place after the <c>\e</c>.</param>
    /// <returns>The code upper-cased, empty when none follows; what its brackets hold, null without
    /// them; and the place after it.</returns>
    private static (string Code, string? Parameter, int Next) CodeAt(int[] points, int at)
    {
        if (at < points.Length && points[at] < 0x80 && SignCodes.Contains((char)points[at]))
        {
            return (((char)points[at]).ToString(), null, at + 1);
        }

        int end = at;
        var code = new StringBuilder();
        while (end < points.Length && IsAsciiLetter(points[end]))
        {
            code.Append(char.ToUpperInvariant((char)points[end++]));
        }

        if (code.Length == 0 || end >= points.Length || points[end] != '[')
        {
            return (code.ToString(), null, end);
        }

        int close = end + 1;
        bool named = close < points.Length && (IsAsciiLetter(points[close]) || points[close] == '_');
        while (close < points.Length && (points[close] is >= '0' and <= '9' || (named && (IsAsciiLetter(points[close]) || points[close] == '_'))))
        {
            close++;
        }

        if (close == end + 1 || close >= points.Length || points[close] != ']')
        {
            return (code.ToString(), null, end);
        }

        return (code.ToString(), CodePoints.Text(points.AsSpan(end + 1, close - end - 1)), close + 1);
    }

    /// <summary>
    /// Reads the color a color code's brackets hold: a number, or a color name.
    /// </summary>
    /// <param name="parameter">What the brackets hold, null without them.</param>
    /// <returns>The color; the game's color 0 without brackets.</returns>
    private static TextColor ColorOf(string? parameter) =>
        NumberOf(parameter) is int number ? new TextColor(number, null)
        : parameter is null ? new TextColor(0, null)
        : new TextColor(null, parameter.ToLowerInvariant());

    /// <summary>
    /// Reads the number a code's brackets hold.
    /// </summary>
    /// <param name="parameter">What the brackets hold, null without them.</param>
    /// <returns>The number, null when they hold none.</returns>
    private static int? NumberOf(string? parameter)
    {
        if (parameter is null || parameter.Length == 0 || !char.IsAsciiDigit(parameter[0]))
        {
            return null;
        }

        return int.TryParse(parameter, NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : 0;
    }

    /// <summary>
    /// Breaks a paragraph into lines that fit a width, before a word and inside a word longer than
    /// the width; the white space where a line breaks is left out.
    /// </summary>
    /// <param name="pieces">The paragraph's pieces.</param>
    /// <param name="width">The width, null for one line.</param>
    /// <param name="lines">Where the lines go.</param>
    private static void Break(List<Piece> pieces, int? width, List<TextLine> lines)
    {
        var line = new List<Piece>();
        int used = 0;
        bool broke = false;
        int start = 0;
        while (start < pieces.Count)
        {
            bool word = !pieces[start].IsSpace;
            int end = start;
            int runWidth = 0;
            while (end < pieces.Count && pieces[end].IsSpace != word)
            {
                runWidth += pieces[end++].Width;
            }

            if (width is int most)
            {
                if (word && used + runWidth > most && line.Count > 0)
                {
                    Close(line, lines);
                    used = 0;
                    broke = true;
                }

                if (!word && broke && line.Count == 0)
                {
                    start = end;
                    continue;
                }

                if (word && runWidth > most)
                {
                    for (int at = start; at < end; at++)
                    {
                        if (used + pieces[at].Width > most && line.Count > 0)
                        {
                            Close(line, lines);
                            used = 0;
                            broke = true;
                        }

                        line.Add(pieces[at]);
                        used += pieces[at].Width;
                    }

                    start = end;
                    continue;
                }
            }

            line.AddRange(pieces.GetRange(start, end - start));
            used += runWidth;
            start = end;
        }

        Close(line, lines);
    }

    /// <summary>
    /// Ends a line: leaves out its white space at the end, joins its characters of one color into
    /// runs, and starts the next line empty.
    /// </summary>
    /// <param name="line">The line's pieces, emptied.</param>
    /// <param name="lines">Where the line goes.</param>
    private static void Close(List<Piece> line, List<TextLine> lines)
    {
        int count = line.Count;
        while (count > 0 && line[count - 1].IsSpace)
        {
            count--;
        }

        var runs = new List<TextRun>();
        var text = new StringBuilder();
        int x = 0;
        int textX = 0;
        TextColor? textColor = null;
        for (int at = 0; at < count; at++)
        {
            Piece piece = line[at];
            if (piece.Icon is not null || (text.Length > 0 && piece.Color != textColor))
            {
                Flush(runs, text, textX, textColor);
            }

            if (piece.Icon is int icon)
            {
                runs.Add(new TextRun(x, string.Empty, null, icon));
            }
            else
            {
                if (text.Length == 0)
                {
                    textX = x;
                    textColor = piece.Color;
                }

                text.Append(new Rune(piece.Point).ToString());
            }

            x += piece.Width;
        }

        Flush(runs, text, textX, textColor);
        lines.Add(new TextLine(x, runs));
        line.Clear();
    }

    /// <summary>
    /// Adds the text gathered so far as a run and starts gathering again.
    /// </summary>
    /// <param name="runs">The line's runs.</param>
    /// <param name="text">The text gathered, emptied.</param>
    /// <param name="x">Where it starts.</param>
    /// <param name="color">Its color.</param>
    private static void Flush(List<TextRun> runs, StringBuilder text, int x, TextColor? color)
    {
        if (text.Length == 0)
        {
            return;
        }

        runs.Add(new TextRun(x, text.ToString(), color, null));
        text.Clear();
    }

    /// <summary>
    /// Tells whether a code point is an ASCII letter, which the game's escape codes are made of.
    /// </summary>
    /// <param name="point">The code point.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsAsciiLetter(int point) => point is (>= 'A' and <= 'Z') or (>= 'a' and <= 'z');

    /// <summary>
    /// A character or an icon of a text, with its color and width.
    /// </summary>
    /// <param name="Point">The character's code point, 0 for an icon.</param>
    /// <param name="Icon">The icon's IconSet index, null for a character.</param>
    /// <param name="Color">The character's color a code gave it, null for the color the text starts in.</param>
    /// <param name="Width">Its width in pixels.</param>
    private readonly record struct Piece(int Point, int? Icon, TextColor? Color, int Width)
    {
        /// <summary>
        /// The code point of the no-break space.
        /// </summary>
        private const int NoBreakSpace = 0xA0;

        /// <summary>
        /// Gets whether it is white space, where a line may break, a no-break space included.
        /// </summary>
        /// <remarks>
        /// The game's texts put no-break spaces where they mean plain ones, which would otherwise
        /// break a long line inside a word.
        /// </remarks>
        public bool IsSpace => Icon is null && (CodePoints.IsSpace(Point) || Point == NoBreakSpace);
    }
}
