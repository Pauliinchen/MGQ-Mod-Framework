//----------------------------------------------------------------
//  TextMatch.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Found where a part occurs in a text, as a highlighted text shows it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// The one rule by which a typed text matches a word, ignoring case and anywhere in the word, as a
/// text field's completions, an autocomplete's matches and a highlighted text use it.
/// </summary>
internal static class TextMatch
{
    /// <summary>
    /// Narrows words to those that hold a typed text anywhere, ignoring case; nothing for an empty
    /// text, and the word that is the typed text itself is left out, since taking it changes nothing.
    /// </summary>
    /// <param name="typed">The text typed.</param>
    /// <param name="words">The words, in order.</param>
    /// <returns>The words that match, in order.</returns>
    public static List<string> Matches(string typed, IEnumerable<string> words)
    {
        var found = new List<string>();
        if (typed.Length == 0)
        {
            return found;
        }

        foreach (string word in words)
        {
            if (word.Contains(typed, StringComparison.OrdinalIgnoreCase) && !word.Equals(typed, StringComparison.OrdinalIgnoreCase))
            {
                found.Add(word);
            }
        }

        return found;
    }

    /// <summary>
    /// Finds where a part occurs in a text, ignoring case, each place after the one before.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="part">The part, which finds nothing when empty.</param>
    /// <returns>Each place's start and length in characters.</returns>
    public static List<(int Start, int Length)> Places(string text, string part)
    {
        var places = new List<(int Start, int Length)>();
        if (part.Length == 0)
        {
            return places;
        }

        for (int start = text.IndexOf(part, StringComparison.OrdinalIgnoreCase); start >= 0; start = text.IndexOf(part, start + part.Length, StringComparison.OrdinalIgnoreCase))
        {
            places.Add((start, part.Length));
        }

        return places;
    }
}
