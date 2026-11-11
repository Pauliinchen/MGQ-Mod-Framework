//----------------------------------------------------------------
//  KeyPresses.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Created
//
//----------------------------------------------------------------

using System;

namespace MGQParadox.ModFramework.Windows;

/// <summary>
/// The keys that sent the game's window a key message since the last take, as a set of every key
/// code in <see cref="Words"/> words of 64 bits.
/// </summary>
/// <remarks>
/// A short tap can fall between two polls of the held keys, while its key message always arrives.
/// </remarks>
internal sealed class KeyPresses
{
    /// <summary>
    /// The 64-bit words a set of all 256 key codes takes.
    /// </summary>
    public const int Words = 4;

    /// <summary>
    /// Guards <see cref="noted"/>.
    /// </summary>
    private readonly object gate = new();

    /// <summary>
    /// The keys noted since the last take.
    /// </summary>
    private readonly ulong[] noted = new ulong[Words];

    /// <summary>
    /// Tells whether a set holds a key.
    /// </summary>
    /// <param name="set">The set, <see cref="Words"/> words.</param>
    /// <param name="code">Windows' code of the key, 0 to 255.</param>
    /// <returns>Whether it does.</returns>
    public static bool Holds(ReadOnlySpan<ulong> set, int code) => (set[code >> 6] & (1UL << (code & 63))) != 0;

    /// <summary>
    /// Notes a key that went down.
    /// </summary>
    /// <param name="code">Windows' code of the key, 0 to 255.</param>
    public void Note(int code)
    {
        lock (gate)
        {
            noted[code >> 6] |= 1UL << (code & 63);
        }
    }

    /// <summary>
    /// Hands out the keys noted since the last take and forgets them.
    /// </summary>
    /// <param name="into">Where the set goes, <see cref="Words"/> words.</param>
    public void Take(Span<ulong> into)
    {
        lock (gate)
        {
            noted.CopyTo(into);
            Array.Clear(noted);
        }
    }
}
