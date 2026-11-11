//----------------------------------------------------------------
//  ModsTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Covered a collection turned on with the mods its mods need in turn, the needs an install brings and a mod
//                              found by a name the picks hide
//      Paulinchen  2026-11-09: Ran the work in a start that tells whether it started
//      Paulinchen  2026-11-08: Covered a Data mod, which the player installs and updates by hand only
//      Paulinchen  2026-11-07: Covered the update of a mod that runs, which waits for the next start
//                            - Covered a removed mod whose waiting update goes with it
//                            - Started the game again without the helper
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Dropped the source of a mod, which is always the website
//                            - Took a mod of no name as the example of an action
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//                            - Kept the website's lists in the cache as plain JSON
//                            - Covered a place that needs the relay's version and its install at that version
//                            - Covered the mods a place needs
//                            - Covered the browser's search by every word typed
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of the mods list, an install and removal, the updates
//                              and restart, a save's check, the state and the mod browser
//      Paulinchen  2026-11-01: Covered the mods in the order asked alone, by their upvotes, and a vote down refused
//                            - Covered the refusal of every tag change and each mod's summary in the state
//      Paulinchen  2026-10-31: Covered a retagged mod put at the end of its new tag and the plain refusals
//                            - Covered the player's retag of an installed mod in the browser
//      Paulinchen  2026-10-30: Covered the mods each mod needs in the plan
//                            - Covered a mod's conflict with an installed one, its links and a link opened
//                            - Covered the mod browser's list filtered and ordered by the player's picks
//                            - Covered the mods and versions without a package for the platform the game runs on
//                            - Covered the updates, a need and the update the helper installs
//                            - Covered the mod browser's list, a description and a removal
//                            - Covered the titles, updates and needs of the mods and a mod's page
//                            - Covered the check of a save's mods and the versions in the plan
//                            - Covered the install of a mod and of one that fails to download
//                            - Covered the restart and the refused action
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Tests.Mods;
using MGQParadox.ModFramework.Topics;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the mods.* topics as the scripts call them through the bridge, over a game folder of the
/// test's own: the mods list and Mods.ini, installs and removals, updates and restarts, a save's
/// check, the state of each mod and the mod browser.
/// </summary>
public sealed class ModsTopicsTests : IDisposable
{
    /// <summary>
    /// Level Cap's description on the website, in Markdown.
    /// </summary>
    private const string Description = "# Level Cap ##\r\n\r\nCaps the **levels** of\r\nyour _party_ at the `Level_Cap.rb` [boss](https://mgqonline.org/mods/level-cap).\r\n\r\n"
        + "![Screenshot](https://mgqonline.org/shot.png)\r\n\r\n- **Points:** spend them\r\n  on slots\r\n2. Second <b>item</b>\r\n\r\n```ruby\r\nputs 1\r\n```\r\n---\r\n> Quoted *line* of Level_Cap";

    /// <summary>
    /// A version of Level Cap newer than the one installed.
    /// </summary>
    private static readonly byte[] Newer = Encoding.UTF8.GetBytes("# newer\n");

    /// <summary>
    /// The game folder.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The bridge context with the topics registered.
    /// </summary>
    private readonly UiContext _ui = new();

    /// <summary>
    /// The actions the restart was asked to carry, in order.
    /// </summary>
    private readonly List<string?> _restarts = [];

    /// <summary>
    /// The mods the install downloads, by their ids, and why one fails: each id's bytes or failure.
    /// </summary>
    private readonly Dictionary<string, Func<byte[]>> _downloads = [];

    /// <summary>
    /// The addresses opened in the player's browser, in order.
    /// </summary>
    private readonly List<string> _opened = [];

    /// <summary>
    /// Fills the Patch folder with three mods and the cache with a website list that tags one of
    /// them Title, and registers the topics after a fetch that reached nothing.
    /// </summary>
    public ModsTopicsTests()
    {
        var list = Encoding.UTF8.GetBytes($$"""
            {"schema":2,"mods":[{"slug":"level-cap","name":"Level Cap","author":"Someone","tag":"Title","versions":[
             {"version":"1.5.2","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"{{ModMergeTests.Raw(ModMergeTests.Script)}}","url":"https://mgqonline.org/mods/level-cap/1/download"},
              "files":[{"path":"Level_Cap.rb","sha256":"{{ModMergeTests.Raw(ModMergeTests.Script)}}"}],"requires":[{"slug":"missing-thing","minVersion":""}]}]}]}
            """);
        ModCache.StoreSite(_game.Path, list);
        _game.Put("Patch/Level_Cap.rb", ModMergeTests.Script);
        _game.Put("Patch/Own.rb", Encoding.UTF8.GetBytes("# mine\n"));
        _game.Put("Patch/Zed/Zed.rb", Encoding.UTF8.GetBytes("# mine\n"));
        var fetch = new ModFetch(() => throw new SiteFeedException(SiteFeed.Unreachable));
        fetch.Run(_game.Path);
        new ModsTopics(_game.Path, fetch, "0.1.0", action => { _restarts.Add(action); return true; }, new ModInstall(mod => _downloads[mod.Id](), work => { work(); return true; }), _opened.Add)
        {
            Pictures = new ModPictures(_ => throw new InvalidOperationException("The test has no images."), work => { work(); return true; }),
            Descriptions = new ModDescriptions(slug => slug == "level-cap" ? Description : throw new SiteFeedException(SiteFeed.Unreachable), work => { work(); return true; }),
        }.RegisterOn(_ui.Context);
    }

    /// <inheritdoc />
    public void Dispose() => _game.Dispose();

    /// <summary>
    /// Asserts that the plan names the mods that are on in the order they load with their versions
    /// and warnings, that Mods.ini takes their lines and is not written again unchanged, and that the
    /// ended fetch is told once; then that a mod is turned off and moved within its tag, while a name
    /// of no mod, a move across tags and a change of any tag are refused and change no line.
    /// </summary>
    [Fact]
    public void PlanThenSet_KeepsModsIniAndRefusesWhatItMayNot()
    {
        var plan = _ui.Value(ModsTopics.PlanTopic).AsHash();

        Assert.Equal(
            new RubyArray
            {
                new RubyArray { "Level_Cap", ModTag.Title, "Patch", "1.5.2", new RubyArray() },
                new RubyArray { "Own", ModTag.Regular, "Patch", InstalledMod.Unknown, new RubyArray() },
                new RubyArray { "Zed", ModTag.Regular, "Patch", InstalledMod.Unknown, new RubyArray() },
            },
            plan["load"]);
        Assert.Equal(new RubyArray { new RubyArray { "Level_Cap", ModWarning.Missing, "missing-thing", string.Empty } }, plan["warnings"]);
        Assert.Equal("Level_Cap=on Title\nOwn=on Regular\nZed=on Regular\n", IniText());
        Assert.Equal([(ModsTopics.FetchedTopic, (RubyValue)new RubyHash { { "site", false }, { "collections", false } })], _ui.Drain());
        Assert.Empty(_ui.Drain());

        var ini = Path.Combine(_game.Path, ModsIni.FilePath);
        File.SetLastWriteTimeUtc(ini, new DateTime(2001, 1, 1, 0, 0, 0, DateTimeKind.Utc));
        _ui.Value(ModsTopics.PlanTopic);
        Assert.Equal(2001, File.GetLastWriteTimeUtc(ini).Year);

        // The player turns a mod off, moves mods and tries to retag them.
        var first = _ui.Value(ModsTopics.SetTopic, new RubyHash { { "on", new RubyHash { { "Own", false }, { "Nobody", false } } } }).AsHash();

        Assert.Equal(RubyBool.True, first["written"]);
        Assert.Equal(new RubyArray { new RubyArray { "Nobody", "This mod is no longer in the Patch folder." } }, first["refused"]);
        Assert.Equal("Level_Cap=on Title\nOwn=off Regular\nZed=on Regular\n", IniText());

        var moved = _ui.Value(ModsTopics.SetTopic, new RubyHash { { "order", new RubyArray { "Zed", "Own" } } }).AsHash();
        var across = _ui.Value(ModsTopics.SetTopic, new RubyHash { { "order", new RubyArray { "Level_Cap", "Zed" } } }).AsHash();

        Assert.Equal(["Level_Cap", "Zed", "Own"], moved["mods"].AsArray().Select(mod => mod.AsHash()["name"].AsText()));
        Assert.Equal(2, across["refused"].AsArray().Count);
        Assert.Equal("Level_Cap=on Title\nZed=on Regular\nOwn=off Regular\n", IniText());

        var retag = _ui.Value(ModsTopics.SetTopic, new RubyHash
        {
            { "on", new RubyHash { { "Zed", false } } },
            { "tag", new RubyHash { { "Level_Cap", ModTag.Data }, { "Own", ModTag.Title } } },
        }).AsHash();

        Assert.Equal(
            new RubyArray
            {
                new RubyArray { "Level_Cap", "Tags come from the mod's author." },
                new RubyArray { "Own", "Tags come from the mod's author." },
            },
            retag["refused"]);
        Assert.Equal("Level_Cap=on Title\nZed=off Regular\nOwn=off Regular\n", IniText());
    }

    /// <summary>
    /// Asserts that an install of a mod of the cache's list writes it into Patch and tells how it
    /// ended once, that a download that fails names the mod and why, that a mod no list names is
    /// refused, and that removing the installed mod deletes its script while removing it again is
    /// refused with why.
    /// </summary>
    [Fact]
    public void InstallThenRemove_WritesAndDeletesTheMod()
    {
        File.Delete(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"));
        _ui.Drain();
        _downloads["site:level-cap"] = () => ModMergeTests.Script;

        var started = _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } }).AsHash();

        Assert.Equal(new RubyHash { { "started", true }, { "refused", RubyNil.Value } }, started);
        Assert.True(_game.Has("Patch/Level_Cap.rb"));
        Assert.Equal(
            [(ModsTopics.InstalledTopic, (RubyValue)new RubyHash { { "installed", new RubyArray { "Level_Cap" } }, { "mod", RubyNil.Value }, { "error", RubyNil.Value } })],
            _ui.Drain());
        Assert.Empty(_ui.Drain());

        _downloads["site:level-cap"] = () => throw new InvalidOperationException("The website could not be reached.");
        _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } });
        var refused = _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:nothing" } } }).AsHash();

        Assert.Equal(
            [(ModsTopics.InstalledTopic, (RubyValue)new RubyHash { { "installed", new RubyArray() }, { "mod", "Level Cap" }, { "error", "The website could not be reached." } })],
            _ui.Drain());
        Assert.Equal(RubyBool.False, refused["started"]);

        var removed = _ui.Value(ModsTopics.RemoveTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } }).AsHash();
        var again = _ui.Value(ModsTopics.RemoveTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } }).AsHash();

        Assert.Equal((new RubyArray { "Level Cap" }, true), (removed["removed"], removed["refused"].IsNil));
        Assert.False(_game.Has("Patch/Level_Cap.rb"));
        Assert.Equal("Level Cap cannot be removed here. Delete its files from the Patch folder.", again["refused"].AsText());
    }

    /// <summary>
    /// Asserts that the updates list the installed mod with a newer version, that a need tells the
    /// version an update brings, that the update of the mod while it runs waits in the waiting
    /// folder and leaves its script as it was, and that the restart carries its action with its
    /// value while a name that is no action name restarts nothing.
    /// </summary>
    [Fact]
    public void UpdatesAndRestart_UpdateOfAModThatRunsWaitsForTheRestart()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap");
        _downloads["site:level-cap"] = () => Newer;

        var updates = _ui.Value(ModsTopics.UpdatesTopic).AsHash();
        var need = _ui.Value(ModsTopics.RequireTopic, new RubyHash { { "name", "Level_Cap" }, { "version", "1.6" } }).AsHash();
        var met = _ui.Value(ModsTopics.RequireTopic, new RubyHash { { "name", "level-cap" }, { "version", "1.5" } }).AsHash();
        var started = _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } }, { "running", new RubyArray { "level_cap", "Own" } } }).AsHash();

        Assert.Equal(
            new RubyArray { new RubyHash { { "id", "site:level-cap" }, { "name", "Level Cap" }, { "folder", "Level_Cap" }, { "installed", "1.5.2" }, { "latest", "1.6.0" }, { "framework", false } } },
            updates["updates"]);
        Assert.Equal((RequireState.Update, "site:level-cap", "1.5.2", "1.6.0"), (need["state"].AsText(), need["id"].AsText(), need["installed"].AsText(), need["offered"].AsText()));
        Assert.Equal(RequireState.Current, met["state"].AsText());
        Assert.Equal(new RubyHash { { "started", true }, { "refused", RubyNil.Value } }, started);
        Assert.Equal(ModMergeTests.Script, _game.Read("Patch/Level_Cap.rb"));
        Assert.Equal("mod\tLevel Cap\t1.6.0\nfile\t0\tPatch/Level_Cap.rb\n", Encoding.UTF8.GetString(_game.Read("Patch/Mod_Framework/Waiting/Waiting.txt")));
        Assert.Equal(Newer, _game.Read("Patch/Mod_Framework/Waiting/0"));

        var restarted = _ui.Value(ModsTopics.RestartTopic, new RubyHash { { "action", "load" }, { "value", "3" } }).AsHash();
        var plain = _ui.Value(ModsTopics.RestartTopic, new RubyHash()).AsHash();
        var refused = _ui.Value(ModsTopics.RestartTopic, new RubyHash { { "action", "Load Save" } }).AsHash();

        Assert.Equal(new RubyHash { { "started", true }, { "refused", RubyNil.Value } }, restarted);
        Assert.Equal(RubyBool.True, plain["started"]);
        Assert.Equal(new RubyHash { { "started", false }, { "refused", "Load Save is no action name." } }, refused);
        Assert.Equal(["load:3", null], _restarts);
    }

    /// <summary>
    /// Asserts that removing a mod whose update waits for the next start drops that update too, so
    /// the waiting folder lists nothing the next start would move back into place.
    /// </summary>
    [Fact]
    public void Remove_DropsTheUpdateThatWaits()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap");
        _downloads["site:level-cap"] = () => Newer;
        _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } }, { "running", new RubyArray { "level_cap" } } });
        var waited = _game.Has("Patch/Mod_Framework/Waiting/0");

        var removed = _ui.Value(ModsTopics.RemoveTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } }).AsHash();

        Assert.Equal((true, new RubyArray { "Level Cap" }), (waited, removed["removed"]));
        Assert.False(_game.Has("Patch/Level_Cap.rb"));
        Assert.Equal(string.Empty, Encoding.UTF8.GetString(_game.Read("Patch/Mod_Framework/Waiting/Waiting.txt")));
        Assert.False(_game.Has("Patch/Mod_Framework/Waiting/0"));
    }

    /// <summary>
    /// Asserts that a save's mod that is off, one missing that the website has and one no source
    /// knows are listed in the save's order, then one in another version, that a mod on now that the
    /// save lacks counts as nothing, and that another version alone lists nothing.
    /// </summary>
    [Fact]
    public void Check_ListsTheModsOffOrMissingThenOtherVersions()
    {
        _ui.Value(ModsTopics.SetTopic, new RubyHash { { "on", new RubyHash { { "Own", false } } } });

        var rows = Rows(Saved(["Level_Cap", "1.5.0", ModTag.Title], ["Own", "?", ModTag.Regular], ["Old_Script", "2.0", ModTag.Regular]));
        var versionOnly = Rows(Saved(["Level_Cap", "1.5.0", ModTag.Title], ["Zed", "?", ModTag.Regular]));
        File.Delete(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"));
        var missing = Rows(Saved(["Level_Cap", "1.5.0", ModTag.Title]));

        Assert.Equal(
            [
                [ModCheck.Off, "Own", "Own", "?", InstalledMod.Unknown, "Own"],
                [ModCheck.Unknown, "Old_Script", "Old_Script", "2.0", string.Empty, string.Empty],
                [ModCheck.OtherVersion, "Level_Cap", "Level Cap", "1.5.0", "1.5.2", "Level_Cap"],
            ],
            rows);
        Assert.Empty(versionOnly);
        Assert.Equal([[ModCheck.Install, "Level_Cap", "Level Cap", "1.5.0", "1.5.2", "site:level-cap"]], missing);
    }

/// <summary>
/// Asserts that of the mods a place needs, one on in the version needed lists nothing, one whose
/// copy the place says differs installs from the website, one that is off turns on, and one in a
/// version the lists do not offer and one nobody offers come from their authors only.
/// </summary>
[Fact]
public void Needs_ListsWhatInstallsTurnsOnOrComesFromItsAuthor()
{
    _ui.Value(ModsTopics.SetTopic, new RubyHash { { "on", new RubyHash { { "Own", false } } } });

    RubyHash Needed(params RubyValue[][] mods) => new() { { "mods", new RubyArray(mods.Select(mod => (RubyValue)new RubyArray(mod))) } };
    List<string[]> NeedRows(RubyHash request) =>
        _ui.Value(ModsTopics.NeedsTopic, request).AsHash()["rows"].AsArray()
            .Select(row => new[] { "kind", "name", "have", "want", "target" }.Select(key => row.AsHash()[key].AsText()).ToArray())
            .ToList();

    Assert.Empty(NeedRows(Needed(["Level_Cap", "1.5.2", false])));
    Assert.Equal(
        [
            [ModCheck.Install, "Level_Cap", "1.5.2", "1.5.2", "site:level-cap"],
            [ModCheck.Off, "Own", InstalledMod.Unknown, string.Empty, "Own"],
            [ModCheck.Author, "Old_Script", string.Empty, "2.0", string.Empty],
        ],
        NeedRows(Needed(["Level_Cap", "1.5.2", true], ["Own", "", false], ["Old_Script", "2.0", false])));
    Assert.Equal([[ModCheck.Author, "Level_Cap", "1.5.2", "1.5.0", string.Empty]], NeedRows(Needed(["Level_Cap", "1.5.0", false])));
}

    /// <summary>
    /// Asserts that each mod tells its title, author, summary and source, whether an update waits,
    /// how each of its requirements stands and the mods that are on and need it, so the plan names
    /// them for the loader, that no mod tells whether the player may tag it, and that a mod's page on
    /// the website opens in the player's browser while a page anywhere else does not.
    /// </summary>
    [Fact]
    public void State_TellsTitlesUpdatesNeedsAndOpensThePage()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap");

        var mods = _ui.Value(ModsTopics.StateTopic).AsHash()["mods"].AsArray().Select(mod => mod.AsHash()).ToDictionary(mod => mod["name"].AsText());
        var load = _ui.Value(ModsTopics.PlanTopic).AsHash()["load"].AsArray().Select(mod => mod.AsArray()).ToDictionary(mod => mod[0].AsText());
        var cap = mods["Level_Cap"];
        var own = mods["Own"];

        Assert.Equal(
            ("Level Cap", "Someone", "site", true, true, "1.6.0"),
            (cap["title"].AsText(), cap["author"].AsText(), cap["source"].AsText(), cap["page"].AsBool(), cap["update"].AsBool(), cap["latest"].AsText()));
        Assert.Equal(
            new RubyArray { new RubyArray { "Own", string.Empty, ModNeed.Met, InstalledMod.Unknown, "Own" }, new RubyArray { "missing-thing", "1.0", ModNeed.Missing, string.Empty, string.Empty } },
            cap["needs"]);
        Assert.Equal(new RubyArray { "Level Cap" }, own["needed_by"]);
        Assert.Equal(("Own", true, false, false), (own["title"].AsText(), own["source"].IsNil, own["update"].AsBool(), own["page"].AsBool()));
        Assert.Equal(("Caps the level.", string.Empty), (cap["summary"].AsText(), own["summary"].AsText()));
        Assert.All(mods.Values, mod => Assert.False(mod.ContainsKey("retag")));
        Assert.Equal((new RubyArray { "Own" }, new RubyArray()), (load["Level_Cap"][4], load["Own"][4]));

        var opened = _ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", "site:level-cap" } }).AsHash();
        StoreNewerList("https://example.org/level-cap");
        var elsewhere = _ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", "site:level-cap" } }).AsHash();

        Assert.Equal((true, false), (opened["opened"].AsBool(), elsewhere["opened"].AsBool()));
        Assert.Equal(["https://mgqonline.org/mods/level-cap"], _opened);
    }

    /// <summary>
    /// Asserts that the browser lists each mod with how it stands, a mod not installed with how its
    /// requirements stand and which mod meets them, its details with an installed mod it does not
    /// work with and its links, and the collections with how each of their mods stands and the
    /// version an install brings; that a link and a collection's page open while a link the mod has
    /// not is refused; and that a description is fetched only when asked to, as plain lines, its end
    /// told, while one that cannot be fetched stays unknown.
    /// </summary>
    [Fact]
    public void Browse_ListsTheModsTheirDetailsAndTheCollections()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap", """
            ,{"slug":"map-display","name":"Map Display","author":"Someone","tag":"Regular","links":{"source":"https://github.com/someone/map-display"},"versions":[
             {"version":"1.2.0","changelog":"- Shows the map","uploadedAt":"2026-10-20T10:00:00+00:00","saveSafety":"new-game","conflicts":[{"slug":"level-cap","note":"Both cap levels."}],
              "package":{"name":"Map_Display.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/map-display/1/download"},
              "files":[{"path":"Map_Display.rb","sha256":"aa"}],"requires":[{"slug":"level-cap","minVersion":"1.6.0"},{"slug":"mod-framework","minVersion":null}]}]}
            """);
        ModCache.StoreCollections(_game.Path, Encoding.UTF8.GetBytes("""
            {"schema":2,"collections":[{"slug":"story-plus","name":"Story Plus","summary":"","author":"Someone","page":"https://mgqonline.org/collections/story-plus",
             "mods":[{"slug":"level-cap","version":"1.5.0","available":true},{"slug":"map-display","version":null,"available":true},{"slug":"gone","version":"1.0","available":false}]}]}
            """));

        var browsed = _ui.Value(ModsTopics.BrowseTopic).AsHash();
        var mods = browsed["mods"].AsArray().Select(mod => mod.AsHash()).ToList();
        var details = mods[1]["details"].AsHash();
        var collection = browsed["collections"].AsArray()[0].AsHash();
        var inCollection = collection["mods"].AsArray().Select(mod => mod.AsHash()).ToList();

        Assert.Equal(
            [("site:level-cap", ModStatus.Update, "1.5.2", "Patch", true), ("site:map-display", ModStatus.Available, null, string.Empty, false)],
            mods.Select(mod => (mod["id"].AsText(), mod["status"].AsText(), mod["installed"].IsNil ? null : mod["installed"].AsText(), mod["place"].AsText(), !mod["on"].IsNil)));
        Assert.Equal(
            new RubyArray
            {
                new RubyArray { "Level Cap", "1.6.0", ModNeed.OlderVersion, "1.5.2", "Level_Cap", "site:level-cap" },
                new RubyArray { ModPlan.FrameworkTitle, string.Empty, ModNeed.Met, "0.1.0", string.Empty, RubyNil.Value },
            },
            mods[1]["needs"]);
        Assert.Equal(new RubyArray { new RubyArray { "Level Cap", "Both cap levels.", true, "Level_Cap" } }, details["conflicts"]);
        Assert.Equal((VersionNotes.NewGame, "https://github.com/someone/map-display"), (details["save"].AsText(), details["links"].AsArray()[0].AsArray()[1].AsText()));
        Assert.Equal(
            [("Level Cap", true, ModStatus.Current, "1.6.0"), ("Map Display", true, ModStatus.Available, "1.2.0"), ("gone", false, ModStatus.Available, "1.0")],
            inCollection.Select(mod => (mod["name"].AsText(), mod["available"].AsBool(), mod["status"].AsText(), mod["version"].AsText())));

        Assert.True(_ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", "site:map-display" }, { "link", "source" } }).AsHash()["opened"].AsBool());
        Assert.False(_ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", "site:map-display" }, { "link", "donation" } }).AsHash()["opened"].AsBool());
        Assert.True(_ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", collection["id"] } }).AsHash()["opened"].AsBool());
        Assert.Equal(["https://github.com/someone/map-display", "https://mgqonline.org/collections/story-plus"], _opened);

        // The details ask for the description.
        var unasked = _ui.Value(ModsTopics.DescribeTopic, new RubyHash { { "id", "site:level-cap" }, { "fetch", false } }).AsHash();
        var known = _ui.Value(ModsTopics.DescribeTopic, new RubyHash { { "id", "site:level-cap" } }).AsHash();
        var failed = _ui.Value(ModsTopics.DescribeTopic, new RubyHash { { "id", "site:other" } }).AsHash();

        Assert.True(unasked["lines"].IsNil);
        Assert.Equal(
            new RubyArray { "Level Cap", "Caps the levels of your party at the Level_Cap.rb boss.", "- Points: spend them on slots", "- Second item", "puts 1", "Quoted line of Level_Cap" },
            known["lines"]);
        Assert.True(failed["lines"].IsNil);
        Assert.Equal(
            [new RubyHash { { "id", "site:level-cap" } }, new RubyHash { { "id", "site:other" } }],
            _ui.Drain().Where(posted => posted.Topic == ModsTopics.DescribedTopic).Select(posted => posted.Payload));
    }

    /// <summary>
    /// Asserts that the browser's list keeps the mods with a category picked, ordered by their
    /// upvotes, while the updates and what the filters offer count every mod, the categories in the
    /// website's order and one no mod has left out; that without a pick an update comes where its
    /// upvotes put it, not first; that a newer version without a package for the platform the game
    /// runs on is named beside the latest one with a package, while a mod without any such version is
    /// listed for any platform but refused to install; and that a vote down is refused, since mods
    /// are only upvoted.
    /// </summary>
    [Fact]
    public void Browse_FiltersByThePicksAndThePlatform()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap", "," + Mod("party-sheet", "Party Sheet", "quality-of-life", 1, 0)
            + "," + Mod("map-display", "Map Display", "quality-of-life", 3, 1) + "," + Mod("invasions", "Invasions", "gameplay", 9, 0));
        ModCache.StoreFilters(_game.Path, Encoding.UTF8.GetBytes("""
            {"schema":3,"categories":[{"value":"gameplay","name":"Gameplay","mods":1},{"value":"visual","name":"Visual","mods":0},{"value":"quality-of-life","name":"Quality of Life","mods":2}],
             "keywords":[{"value":"map","name":null,"mods":1}],"languages":[],"platforms":["pc","android"],"games":["english"],"sorts":["updated"]}
            """));
        var request = new RubyHash { { "order", ModBrowse.Rating }, { "picks", new RubyHash { { "categories", new RubyArray { "quality-of-life" } } } } };

        var browsed = _ui.Value(ModsTopics.BrowseTopic, request).AsHash();
        var categories = browsed["filters"].AsHash()["categories"].AsArray().Select(category => category.AsArray()).ToList();
        var every = _ui.Value(ModsTopics.BrowseTopic, new RubyHash { { "order", ModBrowse.Rating } }).AsHash()["mods"].AsArray();

        Assert.Equal(["site:map-display", "site:party-sheet"], browsed["mods"].AsArray().Select(mod => mod.AsHash()["id"].AsText()));
        Assert.Equal(["site:level-cap"], browsed["updates"].AsArray().Select(mod => mod.AsHash()["id"].AsText()));
        Assert.Equal((4, 1), (browsed["total"].AsInt(), browsed["picks"].AsInt()));
        Assert.Equal([("gameplay", 1, false), ("quality-of-life", 2, true)], categories.Select(category => (category[0].AsText(), category[2].AsInt(), category[3].AsBool())));
        Assert.Equal(3, browsed["mods"].AsArray()[0].AsHash()["upvotes"].AsInt());
        Assert.Equal(["site:invasions", "site:map-display", "site:party-sheet", "site:level-cap"], every.Select(mod => mod.AsHash()["id"].AsText()));

        // A list of schema 3 whose newest versions are for Android alone.
        var script = ModMergeTests.Raw(ModMergeTests.Script);
        ModCache.StoreSite(_game.Path, Encoding.UTF8.GetBytes($$"""
            {"schema":3,"mods":[{"slug":"level-cap","name":"Level Cap","author":"Someone","tag":"Title","versions":[
             {"version":"1.7.0","changelog":"","uploadedAt":"2026-10-25T10:00:00+00:00",
              "packages":[{"platform":"android","name":"Level_Cap.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/level-cap/2/android","files":[{"path":"Level_Cap.rb","sha256":"aa"}]}]},
             {"version":"1.5.2","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00",
              "packages":[{"platform":"pc","name":"Level_Cap.rb","size":1,"sha256":"{{script}}","url":"https://mgqonline.org/mods/level-cap/1/pc","files":[{"path":"Level_Cap.rb","sha256":"{{script}}"}]}]}]},
             {"slug":"phone-only","name":"Phone Only","author":"Someone","tag":"Regular","page":"https://mgqonline.org/mods/phone-only","versions":[
             {"version":"2.0","changelog":"","uploadedAt":"2026-10-25T10:00:00+00:00",
              "packages":[{"platform":"android","name":"Phone_Only.rb","size":1,"sha256":"bb","url":"https://mgqonline.org/mods/phone-only/2/android","files":[{"path":"Phone_Only.rb","sha256":"bb"}]}]}]}]}
            """));

        var any = new RubyHash { { "picks", new RubyHash { { "platform", ModBrowse.AnyPlatform } } } };
        var mods = _ui.Value(ModsTopics.BrowseTopic, any).AsHash()["mods"].AsArray().Select(mod => mod.AsHash()).ToList();
        var phone = _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:phone-only" } } }).AsHash();
        var down = _ui.Value(ModsTopics.VoteTopic, new RubyHash { { "id", "site:level-cap" }, { "vote", "down" } }).AsHash();

        Assert.Equal(
            [("site:level-cap", ModStatus.Current, "1.5.2", "1.7.0"), ("site:phone-only", ModStatus.OtherPlatform, "2.0", null)],
            mods.Select(mod => (mod["id"].AsText(), mod["status"].AsText(), mod["latest"].AsText(), mod["newer_elsewhere"].IsNil ? null : mod["newer_elsewhere"].AsText())));
        Assert.Equal("Phone Only is not available on this platform.", phone["refused"].AsText());
        Assert.True(_ui.Value(ModsTopics.PageTopic, new RubyHash { { "id", "site:phone-only" } }).AsHash()["opened"].AsBool());
        Assert.Equal((false, "UnknownVote"), (down["started"].AsBool(), down["refused"].AsText()));
    }

    /// <summary>
    /// Asserts that the browser's search keeps the mods and the collections whose texts hold every
    /// word typed, whatever the case, beside the picks, while the totals count every one.
    /// </summary>
    [Fact]
    public void Browse_NarrowsToEveryWordOfTheSearch()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap", "," + Mod("party-sheet", "Party Sheet", "quality-of-life", 1, 0)
            + "," + Mod("map-display", "Map Display", "quality-of-life", 3, 1) + "," + Mod("invasions", "Invasions", "gameplay", 9, 0));
        ModCache.StoreCollections(_game.Path, Encoding.UTF8.GetBytes("""
            {"schema":2,"collections":[{"slug":"story-plus","name":"Story Plus","summary":"A second run.","author":"Someone","page":null,"mods":[{"slug":"level-cap","version":null,"available":true}]}]}
            """));
        RubyHash Searched(string search, RubyHash? picks = null) =>
            _ui.Value(ModsTopics.BrowseTopic, new RubyHash { { "order", ModBrowse.Name }, { "search", search }, { "picks", (RubyValue?)picks ?? RubyNil.Value } }).AsHash();
        IEnumerable<string> Ids(RubyHash browsed, string list) => browsed[list].AsArray().Select(item => item.AsHash()["id"].AsText());

        var map = Searched("DISPLAY map");
        var picked = Searched("INV", new RubyHash { { "categories", new RubyArray { "gameplay" } } });
        var none = Searched("map story");

        Assert.Equal(["site:map-display"], Ids(map, "mods"));
        Assert.Equal(["collection:story-plus"], Ids(Searched("SECOND run"), "collections"));
        Assert.Equal((4, 1), (map["total"].AsInt(), map["collections_total"].AsInt()));
        Assert.Equal(["site:invasions"], Ids(picked, "mods"));
        Assert.Equal((0, 0, 4), (none["mods"].AsArray().Count, none["collections"].AsArray().Count, none["total"].AsInt()));
    }

    /// <summary>
    /// Asserts that the framework never installs or updates a mod the website tags Data: the browser
    /// tells it is installed by hand and leaves its update out of Update all, the updates leave it
    /// out, a need of its newer version leaves it to the player, its install is refused with why and
    /// changes no file, and a save or a place that misses it tells the player to install it by hand.
    /// </summary>
    [Fact]
    public void DataMod_IsInstalledAndUpdatedByHandOnly()
    {
        StoreNewerList("https://mgqonline.org/mods/level-cap", tag: ModTag.Data);
        _downloads["site:level-cap"] = () => Newer;

        var browsed = _ui.Value(ModsTopics.BrowseTopic).AsHash();
        var cap = browsed["mods"].AsArray()[0].AsHash();
        var need = _ui.Value(ModsTopics.RequireTopic, new RubyHash { { "name", "Level_Cap" }, { "version", "1.6" } }).AsHash();
        var started = _ui.Value(ModsTopics.InstallTopic, new RubyHash { { "ids", new RubyArray { "site:level-cap" } } }).AsHash();

        Assert.Equal((ModStatus.Update, true), (cap["status"].AsText(), cap["by_hand"].AsBool()));
        Assert.Empty(browsed["updates"].AsArray());
        Assert.Empty(_ui.Value(ModsTopics.UpdatesTopic).AsHash()["updates"].AsArray());
        Assert.Equal((RequireState.ByHand, "1.6.0"), (need["state"].AsText(), need["offered"].AsText()));
        Assert.Equal(new RubyHash { { "started", false }, { "refused", "Level Cap is installed by hand from its page on the website." } }, started);
        Assert.Equal(ModMergeTests.Script, _game.Read("Patch/Level_Cap.rb"));

        File.Delete(Path.Combine(_game.Path, "Patch", "Level_Cap.rb"));
        var needed = _ui.Value(ModsTopics.NeedsTopic, new RubyHash { { "mods", new RubyArray { new RubyArray { "Level_Cap", "1.6.0", false } } } }).AsHash();

        Assert.Equal([[ModCheck.ByHand, "Level_Cap", "Level Cap", "1.5.0", "1.6.0", "site:level-cap"]], Rows(Saved(["Level_Cap", "1.5.0", ModTag.Data])));
        Assert.Equal((ModCheck.ByHand, "site:level-cap"), (needed["rows"].AsArray()[0].AsHash()["kind"].AsText(), needed["rows"].AsArray()[0].AsHash()["target"].AsText()));
    }

    /// <summary>
    /// Asserts that turning a collection on turns its installed mods on in its order in one change
    /// of Mods.ini and names as the other mods that are on only those neither it nor the mods it
    /// needs in turn need; that a mod not installed brings the website's mods it needs and those they
    /// need, but none installed; and that a name finds its mod while the picks hide it.
    /// </summary>
    [Fact]
    public void CollectionOn_KeepsTheModsItNeedsInTurn()
    {
        foreach (var name in new[] { "Alpha", "Beta", "Cee", "Wide_View", "Xeno" })
        {
            _game.Put($"Patch/{name}.rb", ScriptOf(name));
        }

        ModCache.StoreSite(_game.Path, Encoding.UTF8.GetBytes($$"""
            {"schema":2,"mods":[{{Needing("xeno", "Xeno", "alpha")}},{{Needing("alpha", "Alpha", "beta")}},{{Needing("beta", "Beta")}},{{Needing("cee", "Cee")}},{{Needing("wide-view", "Wide_View")}},
             {{Needing("gamma", "Gamma", "delta")}},{{Needing("delta", "Delta", "epsilon", "beta")}},{{Needing("epsilon", "Epsilon")}}]}
            """));
        ModCache.StoreCollections(_game.Path, Encoding.UTF8.GetBytes("""
            {"schema":2,"collections":[{"slug":"pack","name":"Pack","summary":"","author":"Someone","page":null,"mods":[{"slug":"xeno","version":null,"available":true},{"slug":"wide-view","version":null,"available":true}]}]}
            """));
        _ui.Value(ModsTopics.SetTopic, new RubyHash { { "on", new RubyHash { { "Xeno", false }, { "Wide_View", false } } } });

        var on = _ui.Value(ModsTopics.CollectionOnTopic, new RubyHash { { "id", "collection:pack" } }).AsHash();
        var hidden = _ui.Value(ModsTopics.BrowseTopic, new RubyHash { { "picks", new RubyHash { { "categories", new RubyArray { "visual" } } } }, { "find", "wide view" } }).AsHash();
        var gamma = _ui.Value(ModsTopics.BrowseTopic).AsHash()["mods"].AsArray().Select(mod => mod.AsHash()).First(mod => mod["id"].AsText() == "site:gamma");

        Assert.Equal(RubyBool.True, on["written"]);
        Assert.Equal("Beta=on Regular\nAlpha=on Regular\nCee=on Regular\nLevel_Cap=on Regular\nOwn=on Regular\nXeno=on Regular\nWide_View=on Regular\nZed=on Regular\n", IniText());
        Assert.Equal(new RubyArray { new RubyArray { "Cee", "Cee" }, new RubyArray { "Level_Cap", "Level_Cap" }, new RubyArray { "Own", "Own" }, new RubyArray { "Zed", "Zed" } }, on["others"]);
        Assert.Equal(new RubyArray { "site:delta", "site:epsilon" }, gamma["brings"]);
        Assert.Equal((0, "site:wide-view"), (hidden["mods"].AsArray().Count, hidden["found"].AsText()));
    }

    /// <summary>
    /// Writes a mod of schema 2 of the website's list with one version, whose script is
    /// <see cref="ScriptOf"/> its name.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name, which its script takes.</param>
    /// <param name="requires">The slugs of the mods it needs.</param>
    /// <returns>The mod as JSON.</returns>
    private static string Needing(string slug, string name, params string[] requires)
    {
        var hash = ModMergeTests.Raw(ScriptOf(name));
        var needs = string.Join(',', requires.Select(need => $$"""{"slug":"{{need}}","minVersion":""}"""));
        return $$"""
            {"slug":"{{slug}}","name":"{{name}}","author":"Someone","tag":"Regular","versions":[{"version":"1.0","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00",
             "package":{"name":"{{name}}.rb","size":1,"sha256":"{{hash}}","url":"https://mgqonline.org/mods/{{slug}}/1/download"},"files":[{"path":"{{name}}.rb","sha256":"{{hash}}"}],"requires":[{{needs}}]}]}
            """;
    }

    /// <summary>
    /// Makes the script of a mod of <see cref="Needing"/>.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>Its bytes.</returns>
    private static byte[] ScriptOf(string name) => Encoding.UTF8.GetBytes($"# {name}\n");

    /// <summary>
    /// Keeps a website list in the cache whose Level Cap has a version newer than the one installed,
    /// which needs Own and a mod nobody has.
    /// </summary>
    /// <param name="page">Level Cap's page.</param>
    /// <param name="more">More mods of the list, each after a comma.</param>
    /// <param name="tag">Level Cap's tag on the website.</param>
    private void StoreNewerList(string page, string more = "", string tag = ModTag.Title)
    {
        var list = Encoding.UTF8.GetBytes($$"""
            {"schema":2,"mods":[{"slug":"level-cap","name":"Level Cap","summary":"Caps the level.","author":"Someone","page":"{{page}}","tag":"{{tag}}","versions":[
             {"version":"1.6.0","changelog":"","uploadedAt":"2026-10-25T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"{{ModMergeTests.Raw(Newer)}}","url":"https://mgqonline.org/mods/level-cap/2/download"},
              "files":[{"path":"Level_Cap.rb","sha256":"{{ModMergeTests.Raw(Newer)}}"}],"requires":[]},
             {"version":"1.5.2","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"{{ModMergeTests.Raw(ModMergeTests.Script)}}","url":"https://mgqonline.org/mods/level-cap/1/download"},
              "files":[{"path":"Level_Cap.rb","sha256":"{{ModMergeTests.Raw(ModMergeTests.Script)}}"}],"requires":[{"slug":"own","minVersion":""},{"slug":"missing-thing","minVersion":"1.0"}]}]}{{more}}]}
            """);
        ModCache.StoreSite(_game.Path, list);
    }

    /// <summary>
    /// Writes a mod of schema 3 of the website's list, with one category and its votes.
    /// </summary>
    /// <param name="slug">Its slug.</param>
    /// <param name="name">Its name, which its script takes with underscores.</param>
    /// <param name="category">Its category's slug.</param>
    /// <param name="up">Its votes up.</param>
    /// <param name="down">Its votes down.</param>
    /// <returns>The mod as JSON.</returns>
    private static string Mod(string slug, string name, string category, int up, int down) => $$"""
        {"slug":"{{slug}}","name":"{{name}}","author":"Someone","tag":"regular","categories":[{"slug":"{{category}}","name":"{{category}}"}],"rating":{"up":{{up}},"down":{{down}},"score":0},"versions":[
         {"version":"1.0","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","packages":[{"platform":"pc","name":"{{name.Replace(' ', '_')}}.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/{{slug}}/1/pc","files":[{"path":"{{name.Replace(' ', '_')}}.rb","sha256":"aa"}]}]}]}
        """;

    /// <summary>
    /// Writes a save's mods as its header names them.
    /// </summary>
    /// <param name="mods">Each mod's name, version and tag.</param>
    /// <returns>The request of the check.</returns>
    private static RubyHash Saved(params RubyValue[][] mods) =>
        new() { { "mods", new RubyArray(mods.Select(mod => (RubyValue)new RubyArray(mod))) } };

    /// <summary>
    /// Asks the check and reads its rows.
    /// </summary>
    /// <param name="request">The save's mods.</param>
    /// <returns>Each row's kind, name, title, versions and target.</returns>
    private List<string[]> Rows(RubyHash request) =>
        _ui.Value(ModsTopics.CheckTopic, request).AsHash()["rows"].AsArray()
            .Select(row => new[] { "kind", "name", "title", "saved", "installed", "target" }.Select(key => row.AsHash()[key].AsText()).ToArray())
            .ToList();

    /// <summary>
    /// Reads Mods.ini.
    /// </summary>
    /// <returns>Its text.</returns>
    private string IniText() => Encoding.UTF8.GetString(_game.Read(ModsIni.FilePath));
}
