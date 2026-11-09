//----------------------------------------------------------------
//  OptionGroups.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace MGQParadox.ModFramework.Options;

/// <summary>
/// Sorts the rows of Options > Mods by mod, as Mod Config Remake did: a row named "[Mod Name]
/// Option" starts or joins that mod's group, an indented row ("   Option" or "-> Option") joins the
/// group of the row above it, and any other row goes to <see cref="Global"/>.
/// </summary>
internal static partial class OptionGroups
{
    /// <summary>
    /// The group of the rows of no mod.
    /// </summary>
    public const string Global = "Global";

    /// <summary>
    /// Sorts rows by their names.
    /// </summary>
    /// <param name="names">The rows' names in their order.</param>
    /// <returns>Each group's name with its rows' places and names without the group, <see cref="Global"/> first while it has rows, the others in the order they first appear.</returns>
    public static List<(string Group, List<(int Place, string Name)> Rows)> Group(IReadOnlyList<string> names)
    {
        var groups = new List<(string Group, List<(int Place, string Name)> Rows)> { (Global, []) };
        string current = Global;
        for (int place = 0; place < names.Count; place++)
        {
            string name = names[place];
            Match named = ModName().Match(name);
            current = named.Success ? named.Groups[1].Value.Trim() : Indented().IsMatch(name) ? current : Global;
            int at = groups.FindIndex(group => group.Group == current);
            if (at < 0)
            {
                groups.Add((current, []));
                at = groups.Count - 1;
            }

            groups[at].Rows.Add((place, named.Success ? name[named.Length..] : name));
        }

        if (groups[0].Rows.Count == 0)
        {
            groups.RemoveAt(0);
        }

        return groups;
    }

    /// <summary>
    /// The mod's name at the start of a row's name, with the room around it.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A\s*\[([^\]]+)\]\s*")]
    private static partial Regex ModName();

    /// <summary>
    /// The start of a row's name that sits under the row above it.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A(\s|->)")]
    private static partial Regex Indented();
}
