//----------------------------------------------------------------
//  ModFolderTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//                            - Took a mod of no name as the example folder
//      Paulinchen  2026-11-04: Checked the game folder and the paths in it in one test
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Checked the game folder found two above the mod folder
//      Paulinchen  2026-10-15: Checked the name of a day's log
//      Paulinchen  2026-10-07: Checked the name of a session's log
//      Paulinchen  2026-10-06: Checked that the DLL's log lands in the Logs folder
//      Paulinchen  2026-10-01: Created
//
//----------------------------------------------------------------

using System.IO;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Runtime;

/// <summary>
/// Covers the game folder a mod finds from its own folder and the paths the game script names relative to it.
/// </summary>
public sealed class ModFolderTests
{
    /// <summary>
    /// Asserts that the game folder is two folders above the mod folder, which a copy inside another mod's folder has to name itself,
    /// that a relative path starts at the game's folder, and that a full path stays as it is.
    /// </summary>
    [Fact]
    public void GamePathOf_StartsAtTheGameFolderTwoAboveTheMod()
    {
        var game = ModFolder.GameRootOf(@"C:\Games\MGQ\Patch\Camp_Notes");
        var full = Path.Combine(Path.GetTempPath(), "Save01.rvdata2");

        Assert.Equal(@"C:\Games\MGQ", game);
        Assert.Equal(@"C:\Games\MGQ\Patch", ModFolder.GameRootOf(@"C:\Games\MGQ\Patch\Camp_Notes\Mod_Framework"));
        Assert.Equal(@"C:\Games\MGQ\Patch\Camp_Notes\Notes\ab12", ModFolder.GamePathOf("Patch/Camp_Notes/Notes/ab12", game));
        Assert.Equal(full, ModFolder.GamePathOf(full, game));
    }
}
