//----------------------------------------------------------------
//  NumberRule.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// What a text typed as a whole number may hold, as a numeric field types it, the number it gives
/// within its bounds, and that number stepped.
/// </summary>
/// <param name="min">The least number, null for none.</param>
/// <param name="max">The largest number, null for none.</param>
public sealed class NumberRule(int? min, int? max)
{
    /// <summary>
    /// Gets the least number, null for none.
    /// </summary>
    public int? Min { get; } = min;

    /// <summary>
    /// Gets the largest number, null for none.
    /// </summary>
    public int? Max { get; } = max;

    /// <summary>
    /// Gets whether a minus may go in front, as the least number lies below 0 or there is none.
    /// </summary>
    public bool Negative => Min is not int least || least < 0;

    /// <summary>
    /// Tells whether a text may stand while it is typed: empty, a lone minus where <see cref="Negative"/>
    /// allows one, or digits behind it that a whole number of 32 bits holds.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it may.</returns>
    public bool Fits(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        int start = Negative && text.StartsWith('-') ? 1 : 0;
        for (int index = start; index < text.Length; index++)
        {
            if (text[index] is < '0' or > '9')
            {
                return false;
            }
        }

        return text.Length == start || Parse(text) is long value && value is >= int.MinValue and <= int.MaxValue;
    }

    /// <summary>
    /// Settles a typed text into the number it gives, clamped within the bounds as MudBlazor's numeric
    /// field clamps it once typing ends.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number, null for a text that gives none, such as an empty one or a lone minus.</returns>
    public int? Settle(string text)
    {
        if (Parse(text) is not long value)
        {
            return null;
        }

        return Clamp(value);
    }

    /// <summary>
    /// Steps a number once, kept within the bounds, as MudBlazor's numeric field steps by Up and Down:
    /// from the number a typed text gives, or from the number it had while the text gives none.
    /// </summary>
    /// <param name="text">The text typed, empty while it does not type.</param>
    /// <param name="number">The number it had.</param>
    /// <param name="by">1 for a step up, -1 for a step down.</param>
    /// <param name="step">What a step adds or takes away.</param>
    /// <returns>The number stepped, the same at a bound.</returns>
    public int Step(string text, int number, int by, int step) => Clamp((long)(Settle(text) ?? number) + ((long)by * step));

    /// <summary>
    /// Keeps a number within the bounds.
    /// </summary>
    /// <param name="value">The number.</param>
    /// <returns>The number, the nearest bound past one.</returns>
    private int Clamp(long value)
    {
        long least = Min ?? int.MinValue;
        return (int)Math.Clamp(value, least, Math.Max(Max ?? int.MaxValue, least));
    }

    /// <summary>
    /// Reads a text as a whole number with an optional minus in front.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number, null for none or one past what 64 bits hold.</returns>
    private static long? Parse(string text) =>
        long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long value) ? value : null;
}
