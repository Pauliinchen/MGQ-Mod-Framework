//----------------------------------------------------------------
//  ModMergeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Dropped the source of a mod, which is always the website
//                            - Took a mod of no name as the example of a folder
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//      Paulinchen  2026-11-04: Checked the merge of one mod and of mods apart in one flow
//      Paulinchen  2026-10-31: Covered the notes of a version told as plain lines
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers making the mod browser's mods out of the website's list, and the
/// name each mod takes in Patch.
/// </summary>
public sealed class ModMergeTests
{
    /// <summary>
    /// When the website's versions were uploaded.
    /// </summary>
    internal static readonly DateTimeOffset Uploaded = new(2026, 10, 24, 0, 0, 0, TimeSpan.Zero);

    /// <summary>
    /// A script's latest version, as the website serves it.
    /// </summary>
    internal static readonly byte[] Script = Encoding.UTF8.GetBytes("# 1.5.2\nputs 2\n");

    /// <summary>
    /// The same script's older version.
    /// </summary>
    internal static readonly byte[] OldScript = Encoding.UTF8.GetBytes("# 1.5.0\nputs 1\n");

    /// <summary>
    /// Asserts that each mod of the website is a mod of its own, named after its script, that tells
    /// its notes as plain lines, and that two mods stay two when both ship a README of the same name,
    /// which neither installs, since only a mod's own script and folder go into Patch.
    /// </summary>
    [Fact]
    public void Merge_MakesEachModOfTheWebsite()
    {
        var site = SiteScript("party-sheet", "Party Sheet", "Party_Sheet.rb", "1.5.2", Script, "## Fixes\r\n- **Fixed** the sheet.\r\n- Added a `page`.");

        var mods = ModMerge.Merge([site, SiteZip("pack-a", "Pack A", "Pack_A.rb"), SiteZip("pack-b", "Pack B", "Pack_B.rb")]);
        var mod = mods.Single(mod => mod.Folder == "Party_Sheet");

        Assert.Equal(["Pack_A", "Pack_B", "Party_Sheet"], mods.Select(mod => mod.Folder).Order());
        Assert.Equal("site:party-sheet", mod.Id);
        Assert.Equal(["1.5.2"], mod.Known.Select(version => version.Version));
        Assert.Equal(["Fixes", "- Fixed the sheet.", "- Added a page."], mod.Notes);
        Assert.All(mods, mod => Assert.DoesNotContain("README.md", mod.Install.Files.Keys));
    }

    /// <summary>
    /// Asserts that a mod is named after its script with a folder of its name, else its only script,
    /// else its folder, and that a mod with a file outside Patch or a name no file takes is never
    /// offered.
    /// </summary>
    [Fact]
    public void Merge_NamesEachModAndLeavesOutWhatWouldEscape()
    {
        var site = new List<SiteMod>
        {
            SiteScript("level-cap", "Level Cap", "Level_Cap.rb", "1.5.2", Script),
            SiteUpload("luka-replacer", "Luka Replacer", new() { ["Patch/Luka_Replacer.rb"] = Script, ["Patch/Luka_Replacer/Heroes/a.luka"] = OldScript }),
            SiteUpload("heroes", "Heroes", new() { ["Heroes/a.luka"] = OldScript }),
            SiteUpload("online", "Online", new() { ["0_Config.rb"] = OldScript, ["Arena.rb"] = Script, ["Arena/data.txt"] = OldScript }),
            SiteUpload("escape", "Escape", new() { ["../Game.exe"] = Script }),
            SiteScript("device", "Device", "CON.rb", "1", Script),
        };

        var mods = ModMerge.Merge(site).ToDictionary(mod => mod.Id, mod => mod.Folder);

        Assert.Equal(new Dictionary<string, string> { ["site:level-cap"] = "Level_Cap", ["site:luka-replacer"] = "Luka_Replacer", ["site:heroes"] = "Heroes", ["site:online"] = "Arena" }, mods);
    }

    /// <summary>
    /// Makes a mod of the website that is one script.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="file">The script's name.</param>
    /// <param name="version">Its only version.</param>
    /// <param name="script">The script.</param>
    /// <param name="changelog">The version's changelog.</param>
    /// <returns>The mod.</returns>
    internal static SiteMod SiteScript(string slug, string name, string file, string version, byte[] script, string changelog = "") =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}",
            [new SiteVersion(version, changelog, Uploaded, new SitePackage(file, script.Length, Raw(script), $"https://mgqonline.org/mods/{slug}/{version}/download"), new Dictionary<string, string> { [file] = Raw(script) })]);

    /// <summary>
    /// Makes a mod of the website that is a zip of a script and a README.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="file">The script's name.</param>
    /// <returns>The mod.</returns>
    internal static SiteMod SiteZip(string slug, string name, string file) =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}",
            [new SiteVersion("1", string.Empty, Uploaded, new SitePackage($"{slug}.zip", 1, Raw(Script), $"https://mgqonline.org/mods/{slug}/1/download"),
                new Dictionary<string, string> { ["Patch/README.md"] = Raw(OldScript), [$"Patch/{file}"] = Raw(Script) })]);

    /// <summary>
    /// Makes a mod of the website in version 1 that is a zip of some files.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="files">Each file by its path.</param>
    /// <returns>The mod.</returns>
    internal static SiteMod SiteUpload(string slug, string name, Dictionary<string, byte[]> files) =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}",
            [new SiteVersion("1", string.Empty, Uploaded, new SitePackage($"{slug}.zip", 1, Raw(Script), $"https://mgqonline.org/mods/{slug}/1/download"),
                files.ToDictionary(file => file.Key, file => Raw(file.Value)))]);

    /// <summary>
    /// Hashes a file as the website does.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 of its raw bytes, lowercase hexadecimal.</returns>
    internal static string Raw(byte[] bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));
}
