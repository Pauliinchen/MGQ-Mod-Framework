//----------------------------------------------------------------
//  ReleaseVersion.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Removed the reading of a build stamp and the padding, which nothing called
//      Paulinchen  2026-10-30: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Reads the version a mod's requirement or an update names.
/// </summary>
internal static class ReleaseVersion
{
    /// <summary>
    /// The most parts of a release's version, like <c>0.6.7.7</c>.
    /// </summary>
    private const int MaxParts = 4;

    /// <summary>
    /// Reads a release's version as the updater names it: dotted numbers alone.
    /// </summary>
    /// <param name="text">The version, like <c>0.6.8</c>.</param>
    /// <returns>The version with every part it lacks as 0, or <see langword="null"/> for anything else.</returns>
    public static Version? Parse(string? text)
    {
        var parts = text?.Split('.') ?? [];

        if (parts.Length is 0 or > MaxParts || !parts.All(part => part.Length is > 0 and <= 9 && part.All(char.IsAsciiDigit)))
        {
            return null;
        }

        var numbers = parts.Select(int.Parse).Concat(Enumerable.Repeat(0, MaxParts - parts.Length)).ToArray();
        return new Version(numbers[0], numbers[1], numbers[2], numbers[3]);
    }
}
