//----------------------------------------------------------------
//  ModFolder.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Let the DLL name the game folder itself
//      Paulinchen  2026-10-06: Removed PathOf
//      Paulinchen  2026-10-01: Built the game's paths from the folder two above the mod folder
//      Paulinchen  2026-09-30: Built paths the game script names relative to the game's folder
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// The mod folder, which holds the DLL and everything it reads or writes, and the game folder its scripts name paths relative to.
/// </summary>
public static class ModFolder
{
    /// <summary>
    /// Full path of the game folder named by <see cref="SetGameRoot"/>, <see langword="null"/> while it follows <see cref="Root"/>.
    /// </summary>
    private static string? _gameRoot;

    /// <summary>
    /// Full path of the mod folder, without a trailing separator.
    /// </summary>
    public static string Root { get; private set; } = WithoutTrailingSeparator(AppContext.BaseDirectory);

    /// <summary>
    /// Full path of the game folder, without a trailing separator: the one named by <see cref="SetGameRoot"/>, else two folders above
    /// the mod folder, where Patch\Mod_Framework sits.
    /// </summary>
    public static string GameRoot => _gameRoot ?? GameRootOf(Root);

    /// <summary>
    /// Points the mod folder somewhere else.
    /// </summary>
    /// <param name="root">Full path of the folder.</param>
    public static void SetRoot(string root) => Root = WithoutTrailingSeparator(root);

    /// <summary>
    /// Names the game folder, for a DLL whose folder does not sit two below it, such as a copy inside another mod's folder.
    /// </summary>
    /// <param name="root">Full path of the game folder.</param>
    public static void SetGameRoot(string root) => _gameRoot = WithoutTrailingSeparator(Path.GetFullPath(root));

    /// <summary>
    /// Builds the path of a file the game script names relative to the game's folder.
    /// </summary>
    /// <param name="path">The path, relative to the game's folder or full.</param>
    /// <returns>The full path.</returns>
    public static string GamePathOf(string path) => GamePathOf(path, GameRoot);

    /// <summary>
    /// Builds the path of a file the game script names relative to a game folder.
    /// </summary>
    /// <param name="path">The path, relative to the game's folder or full.</param>
    /// <param name="gameRoot">Full path of the game folder.</param>
    /// <returns>The full path.</returns>
    internal static string GamePathOf(string path, string gameRoot) => Path.GetFullPath(Path.Combine(gameRoot, path));

    /// <summary>
    /// Finds the game folder a mod folder sits in, two folders above it.
    /// </summary>
    /// <param name="modFolder">Full path of the mod folder, such as Patch\Mod_Framework in the game folder.</param>
    /// <returns>Full path of the game folder.</returns>
    public static string GameRootOf(string modFolder)
    {
        var patch = Path.GetDirectoryName(modFolder) ?? modFolder;
        return Path.GetDirectoryName(patch) ?? patch;
    }

    /// <summary>
    /// Removes a trailing separator from a folder path.
    /// </summary>
    /// <param name="path">The folder path.</param>
    /// <returns>The path without a trailing separator.</returns>
    private static string WithoutTrailingSeparator(string path) => path.TrimEnd('\\', '/');
}
