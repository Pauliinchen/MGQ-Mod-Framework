//----------------------------------------------------------------
//  ModUpdatesTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Ran the work in a start that tells whether it started
//      Paulinchen  2026-11-08: Covered a framework update that leaves the copy of a mod its zip brings as it is
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//      Paulinchen  2026-11-04: Checked the updates, the mod a name means, the needs and a version put first in one flow
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the rules every update shares: the updates of the installed mods, the framework's
/// included, the mod a name means, how a version a mod needs stands, a version put first, and
/// the framework's update beside the mod its zip brings a copy of.
/// </summary>
public sealed class ModUpdatesTests : IDisposable
{
    /// <summary>
    /// Level Cap 1.6.0, newer than the 1.5.2 installed.
    /// </summary>
    private static readonly byte[] Newer = Encoding.UTF8.GetBytes("# 1.6.0\n");

    /// <summary>
    /// The framework's stub in its version 0.1.0, which is installed.
    /// </summary>
    private static readonly byte[] OldStub = Encoding.UTF8.GetBytes("# stub 0.1.0\n");

    /// <summary>
    /// The framework's stub in its version 0.1.1.
    /// </summary>
    private static readonly byte[] NewStub = Encoding.UTF8.GetBytes("# stub 0.1.1\n");

    /// <summary>
    /// The Equipment Window 1.0, whose copy every zip of the framework brings.
    /// </summary>
    private static readonly byte[] BundledWindow = Encoding.UTF8.GetBytes("# Equipment Window 1.0\n");

    /// <summary>
    /// The Equipment Window 1.1, which the player updated to from the website.
    /// </summary>
    private static readonly byte[] NewerWindow = Encoding.UTF8.GetBytes("# Equipment Window 1.1\n");

    /// <summary>
    /// The game folder.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The website's mods: Level Cap and the framework with a version newer than the one installed,
    /// each zip of the framework with the Equipment Window's copy, the Equipment Window as a mod of
    /// its own, and Party Sheet, which is not installed.
    /// </summary>
    private readonly List<SiteMod> _site =
    [
        Mod("level-cap", "Level Cap", Version("1.6.0", 2, ("Level_Cap.rb", Newer)), Version("1.5.2", 1, ("Level_Cap.rb", ModMergeTests.Script))),
        Mod("mod-framework", "Mod Framework", Version("0.1.1", 2, ("Patch/!Mod_Framework.rb", NewStub), ("Patch/Mod_Framework/loader.rbx", NewStub), ("Patch/Equipment_Window.rb", BundledWindow)), Version("0.1.0", 1, ("Patch/!Mod_Framework.rb", OldStub), ("Patch/Mod_Framework/loader.rbx", OldStub), ("Patch/Equipment_Window.rb", BundledWindow))),
        Mod("equipment-window", "Equipment Window", Version("1.1", 3, ("Equipment_Window.rb", NewerWindow)), Version("1.0", 1, ("Equipment_Window.rb", BundledWindow))),
        ModMergeTests.SiteScript("party-sheet", "Party Sheet", "Party_Sheet.rb", "1.0", ModMergeTests.OldScript),
    ];

    /// <summary>
    /// Installs Level Cap 1.5.2, the framework's 0.1.0 and the Equipment Window 1.1.
    /// </summary>
    public ModUpdatesTests()
    {
        _game.Put("Patch/Level_Cap.rb", ModMergeTests.Script);
        _game.Put("Patch/Equipment_Window.rb", NewerWindow);
        _game.Put("Patch/!Mod_Framework.rb", OldStub);
        _game.Put("Patch/Mod_Framework/loader.rbx", OldStub);
    }

    /// <inheritdoc />
    public void Dispose() => _game.Dispose();

    /// <summary>
    /// Asserts that the installed mods with a newer version are the updates, the framework first,
    /// and a mod not installed is none; that a mod is found by its id, its slug or its name in Patch
    /// whatever their case, or by its title; that a need the installed version meets is current, one the lists
    /// meet is an update to the latest version, an exact older version comes from the website,
    /// the version the mod names counts first, and a need
    /// nobody meets is unavailable; and that a version of a website's mod is put first, so the merge
    /// installs it, while a version the website lacks finds nothing.
    /// </summary>
    [Fact]
    public void Updates_FindTheNewerVersionsAndWhatANeedTakes()
    {
        var known = ModMerge.Merge(_site);
        var states = ModScan.Detect(known, _game.Path, logged: false);
        var cap = ModUpdates.Named(known, "LEVEL_CAP");
        var state = states[cap!.Id];

        Assert.Equal(
            [("site:mod-framework", "0.1.0", "0.1.1", true), ("site:level-cap", "1.5.2", "1.6.0", false)],
            ModUpdates.Find(known, states).Select(update => (update.Mod.Id, update.Installed, update.Mod.Latest, ModUpdates.IsFramework(update.Mod))));
        Assert.Equal(["site:level-cap", "site:level-cap", "site:level-cap", null], new[] { "site:level-cap", "level-cap", "Level Cap", "nothing" }.Select(name => ModUpdates.Named(known, name)?.Id));

        RequiredVersion Need(string least, bool exact = false, string? have = null) => ModUpdates.Require(cap, state, least, exact, have);

        Assert.Equal((RequireState.Current, "1.5.2", (string?)null), Shown(Need("1.5")));
        Assert.Equal((RequireState.Update, "1.5.2", "1.6.0"), Shown(Need("1.5.3")));
        Assert.Equal((RequireState.Unavailable, "1.5.2", (string?)null), Shown(Need("2.0.0")));
        Assert.Equal((RequireState.Update, "1.6.0", "1.5.2"), Shown(Need("1.5.2", exact: true, have: "1.6.0")));
        Assert.Equal((RequireState.Current, "1.5.2", (string?)null), Shown(Need("1.5.2.0", exact: true)));
        Assert.Equal((RequireState.Unavailable, (string?)null, (string?)null), Shown(ModUpdates.Require(null, null, "1.0", false, null)));

        Assert.Equal("1.5.2", ModUpdates.Named(ModMerge.Merge(ModUpdates.AtVersion(_site, "level-cap", "1.5.2")), "level-cap")!.Latest);
        Assert.Null(ModUpdates.AtVersion(_site, "level-cap", "1.4"));
        Assert.Null(ModUpdates.AtVersion(_site, "nothing", "1.0"));
    }

    /// <summary>
    /// Asserts that the copy of the Equipment Window the framework's zips bring counts as no file of
    /// the framework: the framework holds its 0.1.0 whole beside the Equipment Window 1.1 the player
    /// updated to, the framework's update waits with its own files only and leaves that copy as it
    /// is, and the browser removes the Equipment Window like any mod.
    /// </summary>
    [Fact]
    public void FrameworkUpdate_LeavesTheModItsZipBringsACopyOfAsItIs()
    {
        var known = ModMerge.Merge(_site);
        var states = ModScan.Detect(known, _game.Path, logged: false);
        var framework = ModUpdates.Named(known, "mod-framework")!;
        var window = ModUpdates.Named(known, "equipment-window")!;
        var package = ModInstallerTests.Zip(("Patch/!Mod_Framework.rb", NewStub), ("Patch/Mod_Framework/loader.rbx", NewStub), ("Patch/Equipment_Window.rb", BundledWindow));

        Assert.Equal((ModStatus.Update, "0.1.0"), (states[framework.Id].Status, states[framework.Id].Installed?.Version));
        Assert.Equal((ModStatus.Current, "1.1"), (states[window.Id].Status, states[window.Id].Installed?.Version));

        var install = new ModInstall(_ => package, work => { work(); return true; });
        Assert.Null(install.Start([framework], _game.Path, []));

        Assert.Null(install.Progress.Error);
        Assert.Equal(
            "mod\tMod Framework\t0.1.1\nfile\t0\tPatch/!Mod_Framework.rb\nfile\t1\tPatch/Mod_Framework/loader.rbx\n",
            Encoding.UTF8.GetString(_game.Read("Patch/Mod_Framework/Waiting/Waiting.txt")));
        Assert.Equal(NewerWindow, _game.Read("Patch/Equipment_Window.rb"));

        Assert.Equal(["Equipment_Window.rb"], ModScan.Remove(window, states[window.Id], _game.Path).Removed);
        Assert.False(_game.Has("Patch/Equipment_Window.rb"));
    }

    /// <summary>
    /// Makes a mod of the website.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name.</param>
    /// <param name="versions">Its versions, the latest first.</param>
    /// <returns>The mod.</returns>
    internal static SiteMod Mod(string slug, string name, params Func<string, SiteVersion>[] versions) =>
        new(slug, name, $"{name} does things.", "Someone", $"https://mgqonline.org/mods/{slug}", versions.Select(version => version(slug)).ToList());

    /// <summary>
    /// Makes a version of a website's mod: one script, or a zip of several files.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <param name="day">The day of October it was uploaded on.</param>
    /// <param name="files">Each file's path and bytes.</param>
    /// <returns>The version for a mod's slug.</returns>
    internal static Func<string, SiteVersion> Version(string version, int day, params (string Path, byte[] Bytes)[] files) =>
        slug => new SiteVersion(
            version,
            $"- Changed in {version}",
            new DateTimeOffset(2026, 10, day, 0, 0, 0, TimeSpan.Zero),
            new SitePackage(files.Length == 1 ? files[0].Path : $"{slug}.zip", 1, ModMergeTests.Raw(files[0].Bytes), $"https://mgqonline.org/mods/{slug}/{version}/download"),
            files.ToDictionary(file => file.Path, file => ModMergeTests.Raw(file.Bytes)));

    /// <summary>
    /// Tells a need's state and versions.
    /// </summary>
    /// <param name="required">The need.</param>
    /// <returns>Its state, the version installed and the one offered.</returns>
    private static (string, string?, string?) Shown(RequiredVersion required) => (required.State, required.Installed, required.Offered);
}
