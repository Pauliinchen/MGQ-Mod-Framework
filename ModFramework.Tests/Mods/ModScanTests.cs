//----------------------------------------------------------------
//  ModScanTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Covered a release folder extracted into Patch, whose scripts lie in its own Patch folder
//      Paulinchen  2026-11-07: Covered a path through .. as no mod's own
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//                            - Left out the framework's old names, which no release had
//      Paulinchen  2026-11-04: Took over the scan of the installed mods and checked the scan and the removal in one flow
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers reading which mods the Patch folder holds and in which version, and removing an installed mod.
/// </summary>
public sealed class ModScanTests
{
    /// <summary>
    /// Asserts that a script at the top of Patch and the folder of its name make one mod, that a
    /// folder of scripts alone makes one too, that a mod is matched by its name and the version its
    /// files are, that a mod neither source knows has the version "?", and that the game's loader,
    /// the framework under each of its names, a folder without scripts, a release folder whose
    /// scripts lie only in its own Patch folder and a name Mods.ini cannot hold are left out.
    /// </summary>
    [Fact]
    public void Scan_FindsAndMatchesEachInstalledMod()
    {
        using var game = new TempFolder();
        var mine = Encoding.UTF8.GetBytes("# mine\n");
        game.Put("Patch/Patch.rb", Encoding.UTF8.GetBytes("# loader\n"));
        game.Put("Patch/!Mod_Framework.rb", Encoding.UTF8.GetBytes("# stub\n"));
        game.Put("Patch/Mod_Framework/Scripts/run.rbx", Encoding.UTF8.GetBytes("# run\n"));
        game.Put("Patch/Level_Cap.rb", ModMergeTests.Script);
        game.Put("Patch/Party_Sheet.rb", ModMergeTests.OldScript);
        game.Put("Patch/Luka_Replacer.rb", mine);
        game.Put("Patch/Luka_Replacer/Heroes/hero.rb", mine);
        game.Put("Patch/Extras/thing.rb", mine);
        game.Put("Patch/Notes/readme.txt", mine);
        game.Put("Patch/MGQ-Online-0.7/Patch/Online.rb", mine);
        game.Put("Patch/a=b.rb", mine);
        var known = ModMerge.Merge(
            [ModMergeTests.SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", ModMergeTests.Script)]);

        var mods = InstalledMods.Scan(game.Path, known);

        Assert.Equal(
            [
                ("Extras", null, "?"),
                ("Level_Cap", "site:level-cap", "1.5.2"),
                ("Luka_Replacer", null, "?"),
                ("Party_Sheet", null, "?"),
            ],
            mods.Select(mod => (mod.Name, mod.Known?.Id, mod.Version)));
    }

    /// <summary>
    /// Asserts that each known mod is found in Patch whatever the case of its file's name, a copy
    /// with Windows line ends counting as its version and one of no known version as changed, and
    /// that removing a mod deletes its files and the folders they leave empty, its own folder too but
    /// never Patch, while a file changed since the scan stays.
    /// </summary>
    [Fact]
    public void DetectThenRemove_TellsEachModsVersionAndRemovesOnlyItsFiles()
    {
        using var game = new TempFolder();
        var data = Encoding.UTF8.GetBytes("data");
        game.Put("Patch/Level_Cap.rb", Encoding.UTF8.GetBytes("# 1.5.2\r\nputs 2\r\n"));
        game.Put("Patch/Party_Sheet.rb", ModMergeTests.OldScript);
        game.Put("Patch/map_display.rb", ModMergeTests.Script);
        game.Put("Patch/Invasions.rb", Encoding.UTF8.GetBytes("# my own fix\n"));
        game.Put("Patch/Pack.rb", ModMergeTests.Script);
        game.Put("Patch/Pack/Data/data.txt", data);
        var mods = ModMerge.Merge(
            [
                ModMergeTests.SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", ModMergeTests.Script),
                ModMergeTests.SiteScript("party-sheet", "Party Sheet", "Party_Sheet.rb", "1.5.2", ModMergeTests.Script),
                ModMergeTests.SiteScript("map-display", "Map Display", "Map_Display.rb", "1.5.2", ModMergeTests.Script),
                ModMergeTests.SiteScript("invasions", "Invasions", "Invasions.rb", "1.5.2", ModMergeTests.Script),
                ModMergeTests.SiteUpload("pack", "Pack", new() { ["Pack.rb"] = ModMergeTests.Script, ["Pack/Data/data.txt"] = data }),
                ModMergeTests.SiteUpload("tool", "Tool", new() { ["Tool.rb"] = ModMergeTests.Script }),
            ]);

        var states = ModScan.Detect(mods, game.Path);

        Assert.Equal(
            new Dictionary<string, (string, string?)>
            {
                ["site:level-cap"] = (ModStatus.Current, "1.5.2"),
                ["site:party-sheet"] = (ModStatus.Changed, null),
                ["site:map-display"] = (ModStatus.Current, "1.5.2"),
                ["site:invasions"] = (ModStatus.Changed, null),
                ["site:pack"] = (ModStatus.Current, "1"),
                ["site:tool"] = (ModStatus.Available, null),
            },
            states.ToDictionary(state => state.Key, state => (state.Value.Status, state.Value.Installed?.Version)));

        var pack = mods.Single(mod => mod.Id == "site:pack");
        var cap = mods.Single(mod => mod.Id == "site:level-cap");
        game.Put("Patch/Pack.rb", Encoding.UTF8.GetBytes("# my own fix\n"));

        var (removed, failed) = ModScan.Remove(pack, states[pack.Id], game.Path);
        ModScan.Remove(cap, states[cap.Id], game.Path);

        Assert.Equal(["Pack/Data/data.txt"], removed);
        Assert.Empty(failed);
        Assert.Equal((true, false, false, true), (game.Has("Patch/Pack.rb"), game.Has("Patch/Pack"), game.Has("Patch/Level_Cap.rb"), game.Has("Patch")));
    }

    /// <summary>
    /// Asserts that a path through <c>..</c> is no mod's own, so removing a mod never reaches
    /// another mod's files.
    /// </summary>
    [Fact]
    public void Owns_RefusesAPathThatLeavesTheModsFolder()
    {
        Assert.Equal((true, false), (PatchFolder.Owns("Pack", "Pack/Data/data.txt"), PatchFolder.Owns("Pack", "Pack/../Level_Cap.rb")));
    }
}
