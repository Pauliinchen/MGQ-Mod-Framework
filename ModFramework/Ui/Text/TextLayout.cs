//----------------------------------------------------------------
//  TextLayout.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Laid out rows of parts in lines by the rule of a text box, cut at the parts' boundaries
//      Paulinchen  2026-10-31: Started a new line at a line break of a wrapped text
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// A stretch of a text: its first code point and how many it holds.
/// </summary>
/// <param name="Start">The first code point.</param>
/// <param name="Length">How many code points.</param>
public readonly record struct TextSpan(int Start, int Length);

/// <summary>
/// A piece of a line of a row of parts: where it starts, which part it belongs to, its text and its
/// width.
/// </summary>
/// <param name="X">Its left edge in the line, in pixels.</param>
/// <param name="Part">The place of its part among the row's parts, from 0.</param>
/// <param name="Text">Its text.</param>
/// <param name="Width">Its width in pixels.</param>
public readonly record struct RowSegment(int X, int Part, string Text, int Width);

/// <summary>
/// Cutting and breaking texts to a width by their characters' widths, as text.rbx does with
/// <c>Bitmap#text_size</c> (<c>Mod_Framework::UI.cut_measured</c>, <c>wrap_measured</c> and
/// <c>wrap_spans</c>), counted by code point as Ruby counts a UTF-8 text.
/// </summary>
public static class TextLayout
{
    /// <summary>
    /// What ends a text cut to fit, ELLIPSIS in text.rbx.
    /// </summary>
    public const string Ellipsis = "...";

    /// <summary>
    /// Measures code points.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="points">The code points.</param>
    /// <returns>The sum of their widths.</returns>
    public static int Width(FontGlyphs glyphs, ReadOnlySpan<int> points)
    {
        ArgumentNullException.ThrowIfNull(glyphs);
        int width = 0;
        foreach (int point in points)
        {
            width += glyphs.Width(point);
        }

        return width;
    }

    /// <summary>
    /// Cuts a text at its end until it fits a width with <see cref="Ellipsis"/> and what follows it.
    /// </summary>
    /// <remarks>
    /// The lengths are halved as Ruby halves them, so a text whose shorter starts do not always fit
    /// better, past trailing spaces, cuts where Ruby cuts it.
    /// </remarks>
    /// <param name="glyphs">The font.</param>
    /// <param name="text">The text.</param>
    /// <param name="width">The width in pixels.</param>
    /// <param name="tail">What follows the text and stays whole, such as a count.</param>
    /// <returns>The text with the tail when they fit, else the text's start, the ellipsis and the tail.</returns>
    public static string Cut(FontGlyphs glyphs, string text, int width, string tail)
    {
        int[] points = CodePoints.Of(text);
        int[] after = CodePoints.Of(tail);
        int ending = Width(glyphs, CodePoints.Of(Ellipsis)) + Width(glyphs, after);
        if (Width(glyphs, points) + Width(glyphs, after) <= width)
        {
            return text + tail;
        }

        int fits = 0;
        int over = points.Length;
        while (over - fits > 1)
        {
            int length = (fits + over) / 2;
            if (Width(glyphs, CodePoints.RightStripped(points.AsSpan(0, length))) + ending <= width)
            {
                fits = length;
            }
            else
            {
                over = length;
            }
        }

        return CodePoints.Text(CodePoints.RightStripped(points.AsSpan(0, fits))) + Ellipsis + tail;
    }

    /// <summary>
    /// Breaks a text into lines that fit a width, at its white space, and inside a word longer than
    /// the width; the white space between words becomes one space, and a line break starts a new line.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="text">The text.</param>
    /// <param name="width">The width in pixels.</param>
    /// <returns>The lines, one empty line for a text without words.</returns>
    public static List<string> Wrap(FontGlyphs glyphs, string text, int width)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (text.Contains('\n', StringComparison.Ordinal))
        {
            var all = new List<string>();
            foreach (string part in text.Split('\n'))
            {
                all.AddRange(Wrap(glyphs, part, width));
            }

            return all;
        }

        int space = glyphs.Width(' ');
        var lines = new List<List<int>> { new() };
        var used = new List<int> { 0 };
        foreach (int[] word in CodePoints.Words(CodePoints.Of(text)))
        {
            int wordWidth = Width(glyphs, word);
            int last = lines.Count - 1;
            int candidate = lines[last].Count == 0 ? wordWidth : used[last] + space + wordWidth;
            if (candidate <= width)
            {
                if (lines[last].Count > 0)
                {
                    lines[last].Add(' ');
                }

                lines[last].AddRange(word);
                used[last] = candidate;
                continue;
            }

            if (lines[last].Count > 0)
            {
                lines.Add([]);
                used.Add(0);
            }

            foreach (int point in word)
            {
                last = lines.Count - 1;
                int pointWidth = glyphs.Width(point);
                if (used[last] + pointWidth > width && lines[last].Count > 0)
                {
                    lines.Add([]);
                    used.Add(0);
                    last++;
                }

                lines[last].Add(point);
                used[last] += pointWidth;
            }
        }

        return lines.ConvertAll(line => CodePoints.Text(line.ToArray()));
    }

    /// <summary>
    /// Breaks a text into lines that fit a width without changing a character of it, so a place in
    /// the text is a place in a line: each line breaks before a word, and inside a word longer than
    /// the width; a run of white space stays whole.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="text">The text.</param>
    /// <param name="width">The width in pixels, or in characters for a font of cells.</param>
    /// <returns>Each line's first code point and length, one empty line for an empty text.</returns>
    public static List<TextSpan> Spans(FontGlyphs glyphs, string text, int width) => Spans(glyphs, CodePoints.Of(text), width);

    /// <summary>
    /// Breaks code points into lines, see <see cref="Spans(FontGlyphs, string, int)"/>.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="points">The text's code points.</param>
    /// <param name="width">The width.</param>
    /// <returns>Each line's first code point and length.</returns>
    public static List<TextSpan> Spans(FontGlyphs glyphs, ReadOnlySpan<int> points, int width)
    {
        var spans = new List<TextSpan>();
        int start = 0;
        int at = 0;
        int used = 0;
        foreach ((int runStart, int runLength) in CodePoints.Runs(points))
        {
            ReadOnlySpan<int> run = points.Slice(runStart, runLength);
            bool word = !CodePoints.IsSpace(run[0]);
            int runWidth = Width(glyphs, run);
            if (word && used + runWidth > width && at > start)
            {
                spans.Add(new TextSpan(start, at - start));
                start = at;
                used = 0;
            }

            if (!(word && runWidth > width) || run.Length == 1)
            {
                used += runWidth;
                at += run.Length;
                continue;
            }

            foreach (int point in run)
            {
                int pointWidth = glyphs.Width(point);
                if (used + pointWidth > width && at > start)
                {
                    spans.Add(new TextSpan(start, at - start));
                    start = at;
                    used = 0;
                }

                used += pointWidth;
                at++;
            }
        }

        spans.Add(new TextSpan(start, points.Length - start));
        return spans;
    }

    /// <summary>
    /// Breaks rows of parts into lines that fit a width by <see cref="Spans(FontGlyphs, ReadOnlySpan{int}, int)"/>,
    /// each row's parts read as one text, so a word that runs across parts stays together, and cuts
    /// each line at the parts' boundaries.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="rows">Each row's parts' texts.</param>
    /// <param name="width">The width in pixels.</param>
    /// <returns>Per row its lines, each its pieces from the left; a row without text has one empty line.</returns>
    public static List<List<List<RowSegment>>> Rows(FontGlyphs glyphs, IReadOnlyList<IReadOnlyList<string>> rows, int width)
    {
        ArgumentNullException.ThrowIfNull(rows);
        var laid = new List<List<List<RowSegment>>>(rows.Count);
        foreach (IReadOnlyList<string> parts in rows)
        {
            var points = new List<int>();
            var starts = new List<int>(parts.Count);
            foreach (string part in parts)
            {
                starts.Add(points.Count);
                points.AddRange(CodePoints.Of(part));
            }

            int[] all = points.ToArray();
            var lines = new List<List<RowSegment>>();
            foreach (TextSpan span in Spans(glyphs, all, width))
            {
                lines.Add(Segments(glyphs, all, starts, span));
            }

            laid.Add(lines);
        }

        return laid;
    }

    /// <summary>
    /// Finds the line of <see cref="Spans(FontGlyphs, string, int)"/> a place in the text is on: the
    /// last one that starts at or before it.
    /// </summary>
    /// <param name="spans">The lines.</param>
    /// <param name="place">The code points before the place.</param>
    /// <returns>The line, 0 when none starts at or before it.</returns>
    public static int SpanOf(IReadOnlyList<TextSpan> spans, int place)
    {
        ArgumentNullException.ThrowIfNull(spans);
        for (int line = spans.Count - 1; line >= 0; line--)
        {
            if (spans[line].Start <= place)
            {
                return line;
            }
        }

        return 0;
    }

    /// <summary>
    /// Cuts a line of a row at its parts' boundaries.
    /// </summary>
    /// <param name="glyphs">The font.</param>
    /// <param name="points">The row's code points.</param>
    /// <param name="starts">Each part's first code point.</param>
    /// <param name="span">The line.</param>
    /// <returns>The line's pieces from the left, none for an empty line.</returns>
    private static List<RowSegment> Segments(FontGlyphs glyphs, int[] points, List<int> starts, TextSpan span)
    {
        var segments = new List<RowSegment>();
        int end = span.Start + span.Length;
        int x = 0;
        for (int part = 0; part < starts.Count; part++)
        {
            int from = Math.Max(starts[part], span.Start);
            int to = Math.Min(part + 1 < starts.Count ? starts[part + 1] : points.Length, end);
            if (to <= from)
            {
                continue;
            }

            ReadOnlySpan<int> piece = points.AsSpan(from, to - from);
            int pieceWidth = Width(glyphs, piece);
            segments.Add(new RowSegment(x, part, CodePoints.Text(piece), pieceWidth));
            x += pieceWidth;
        }

        return segments;
    }
}
