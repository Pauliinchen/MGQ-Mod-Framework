//----------------------------------------------------------------
//  GamePlatform.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-30: Told JoiPlay by the runtime the library was built for, without asking Windows
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Runtime.InteropServices;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// Where the game runs.
/// </summary>
public enum GamePlatform
{
    /// <summary>
    /// Windows.
    /// </summary>
    Windows,

    /// <summary>
    /// Wine, as on Linux, or Proton, as on the Steam Deck.
    /// </summary>
    Wine,

    /// <summary>
    /// JoiPlay on Android.
    /// </summary>
    JoiPlay,
}

/// <summary>
/// Tells where the game runs, and which package of a mod fits there.
/// </summary>
public static class Platforms
{
    /// <summary>
    /// The package of a mod for the PC, which Windows and Wine run.
    /// </summary>
    public const string Pc = "pc";

    /// <summary>
    /// The package of a mod for Android, which JoiPlay runs.
    /// </summary>
    public const string Android = "android";

    /// <summary>
    /// The platform, found once.
    /// </summary>
    private static readonly Lazy<GamePlatform> Found = new(() => Detect(OnAndroid, OnAndroid ? null : NativeMethods.WineVersion()));

    /// <summary>
    /// Gets whether the library runs on Android, which only its JoiPlay build does.
    /// </summary>
    public static bool OnAndroid { get; } =
        OperatingSystem.IsAndroid() || RuntimeInformation.RuntimeIdentifier.StartsWith("linux-bionic", StringComparison.Ordinal);

    /// <summary>
    /// Gets where the game runs.
    /// </summary>
    public static GamePlatform Current => Found.Value;

    /// <summary>
    /// Gets the package of a mod that fits where the game runs.
    /// </summary>
    public static string Package => PackageOf(Current);

    /// <summary>
    /// Tells where the game runs from what the system shows.
    /// </summary>
    /// <param name="android">Whether the code runs on Android, as JoiPlay runs it.</param>
    /// <param name="wine">The Wine version the game runs under; <see langword="null"/> for none.</param>
    /// <returns>The platform.</returns>
    public static GamePlatform Detect(bool android, string? wine) =>
        android ? GamePlatform.JoiPlay : wine != null ? GamePlatform.Wine : GamePlatform.Windows;

    /// <summary>
    /// Tells the package of a mod that fits a platform.
    /// </summary>
    /// <param name="platform">The platform.</param>
    /// <returns><see cref="Android"/> for JoiPlay, else <see cref="Pc"/>.</returns>
    public static string PackageOf(GamePlatform platform) => platform == GamePlatform.JoiPlay ? Android : Pc;

    /// <summary>
    /// Names a platform as the game scripts name it.
    /// </summary>
    /// <param name="platform">The platform.</param>
    /// <returns><c>windows</c>, <c>wine</c> or <c>joiplay</c>.</returns>
    public static string NameOf(GamePlatform platform) => platform switch
    {
        GamePlatform.Wine => "wine",
        GamePlatform.JoiPlay => "joiplay",
        _ => "windows",
    };
}
