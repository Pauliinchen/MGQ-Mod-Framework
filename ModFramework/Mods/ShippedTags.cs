//----------------------------------------------------------------
//  ShippedTags.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-01: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// The copy of the website's tags that ships inside the DLL, a <c>name=tag</c> line per mod, which
/// tags a mod no source tags, such as on a first start without a connection.
/// </summary>
internal static class ShippedTags
{
    /// <summary>
    /// The name the build embeds the copy under.
    /// </summary>
    public const string Resource = "ShippedTags.txt";

    /// <summary>
    /// The tags by the mod's name, read once.
    /// </summary>
    private static readonly Lazy<IReadOnlyDictionary<string, string>> Tags = new(Load);

    /// <summary>
    /// Tells the tag the copy gives a mod.
    /// </summary>
    /// <param name="name">The mod's name in Patch, in any case.</param>
    /// <returns>The tag as spelled in <see cref="ModTag"/>; <see langword="null"/> for none.</returns>
    public static string? Of(string name) => Tags.Value.GetValueOrDefault(name);

    /// <summary>
    /// Reads the copy's lines.
    /// </summary>
    /// <param name="text">The copy.</param>
    /// <returns>The tags by the mod's name in any case, a tag this version does not know left out.</returns>
    internal static IReadOnlyDictionary<string, string> Parse(string text)
    {
        var tags = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var line in text.Split('\n'))
        {
            var separator = line.IndexOf('=', StringComparison.Ordinal);

            if (separator > 0 && ModTag.Parse(line[(separator + 1)..]) is { } tag)
            {
                tags[line[..separator].Trim()] = tag;
            }
        }

        return tags;
    }

    /// <summary>
    /// Reads the copy the DLL holds.
    /// </summary>
    /// <returns>The tags by the mod's name; none when the DLL holds no copy.</returns>
    private static IReadOnlyDictionary<string, string> Load()
    {
        using var stream = typeof(ShippedTags).Assembly.GetManifestResourceStream(Resource);

        if (stream == null)
        {
            Log.Write("the DLL holds no copy of the website's tags");
            return Parse(string.Empty);
        }

        using var reader = new StreamReader(stream, Encoding.UTF8);
        return Parse(reader.ReadToEnd());
    }
}
