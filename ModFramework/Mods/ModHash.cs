//----------------------------------------------------------------
//  ModHash.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Removed the hash of a file on disk, which nothing called
//      Paulinchen  2026-10-30: Moved into the Mod Framework
//      Paulinchen  2026-10-24: Matched a file against the hash of its raw bytes too
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Hashes a mod's files, a script without its carriage returns, so a copy with Windows line ends
/// counts as the same.
/// </summary>
/// <remarks>
/// A script is hashed without its carriage returns, since Git checks scripts out with them on
/// Windows.
/// </remarks>
internal static class ModHash
{
    /// <summary>
    /// The byte a script's carriage returns are, which its hash leaves out.
    /// </summary>
    private const byte CarriageReturn = 13;

    /// <summary>
    /// Hashes a mod's file.
    /// </summary>
    /// <param name="name">The file's name or path, which tells a script from other files.</param>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 as 64 lowercase hexadecimal characters.</returns>
    public static string Of(string name, ReadOnlySpan<byte> bytes)
    {
        if (!IsScript(name))
        {
            return Convert.ToHexStringLower(SHA256.HashData(bytes));
        }

        var kept = new byte[bytes.Length];
        var length = 0;

        foreach (var value in bytes)
        {
            if (value != CarriageReturn)
            {
                kept[length++] = value;
            }
        }

        return Convert.ToHexStringLower(SHA256.HashData(kept.AsSpan(0, length)));
    }

    /// <summary>
    /// Tells whether a mod's file is the one a hash names, as the website hashes it or without its carriage returns.
    /// </summary>
    /// <remarks>
    /// The website hashes every file as it is, so a script it lists with carriage returns matches only its raw hash.
    /// </remarks>
    /// <param name="name">The file's name or path, which tells a script from other files.</param>
    /// <param name="bytes">The file.</param>
    /// <param name="hash">The hash, 64 hexadecimal characters.</param>
    /// <returns>Whether the SHA-256 of the raw bytes or <see cref="Of"/> equals the hash.</returns>
    public static bool Matches(string name, ReadOnlySpan<byte> bytes, string hash) =>
        string.Equals(Convert.ToHexStringLower(SHA256.HashData(bytes)), hash, StringComparison.OrdinalIgnoreCase)
        || string.Equals(Of(name, bytes), hash, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Tells a script from other files.
    /// </summary>
    /// <param name="name">The file's name or path.</param>
    /// <returns>Whether it is a Ruby script.</returns>
    private static bool IsScript(string name) => name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase);
}
