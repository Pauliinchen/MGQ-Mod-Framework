//----------------------------------------------------------------
//  GamePlatformTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Runtime;

/// <summary>
/// Covers where the game runs and which package of a mod fits there.
/// </summary>
public sealed class GamePlatformTests
{
    /// <summary>
    /// Asserts that Android is JoiPlay with the Android package, a Wine version Wine with the PC
    /// package, and neither Windows with the PC package.
    /// </summary>
    [Fact]
    public void Detect_TellsThePlatformAndItsPackage()
    {
        var found = new[] { Platforms.Detect(true, null), Platforms.Detect(false, "10.0"), Platforms.Detect(false, null) };

        Assert.Equal([GamePlatform.JoiPlay, GamePlatform.Wine, GamePlatform.Windows], found);
        Assert.Equal([Platforms.Android, Platforms.Pc, Platforms.Pc], found.Select(Platforms.PackageOf));
        Assert.Equal(["joiplay", "wine", "windows"], found.Select(Platforms.NameOf));
    }
}
