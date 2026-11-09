//----------------------------------------------------------------
//  ModInstallerTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Covered the updates of mods that run, which wait for the next start
//                            - Covered the deletion of the old DLL at the next session
//                            - Built the mods without the cut kind of an entry
//      Paulinchen  2026-11-06: Removed the check of the framework's files kept until its new version boots
//      Paulinchen  2026-11-04: Rewrote the checks as flow tests of installing, updating and refusing mods
//      Paulinchen  2026-10-30: Covered the framework's files kept until its new version boots
//                            - Moved into the Mod Framework
//                            - Covered a mod kept to its own script and folder in Patch
//      Paulinchen  2026-10-24: Covered a loaded DLL renamed out of the way
//      Paulinchen  2026-10-06: Covered failed writes, files of older versions and zips holding a file twice
//                            - Covered zips whose files sit in a Patch folder
//                            - Covered links to a zip of a release and zips written with backslashes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers installing and updating mods in the Patch folder, the framework's own update included, and
/// the refusals that keep an install to the catalog's files in the mod's own script and folder.
/// </summary>
public sealed class ModInstallerTests
{
    /// <summary>
    /// A script as the website serves it.
    /// </summary>
    private static readonly byte[] Script = Encoding.UTF8.GetBytes("# Level Cap\nputs 1\n");

    /// <summary>
    /// A file of a pack of characters.
    /// </summary>
    private static readonly byte[] Pack = Encoding.UTF8.GetBytes("LUKA pack");

    /// <summary>
    /// Asserts that a link mod's script replaces the old copy in Patch, that an upload's files land in
    /// its folder as Patch spells it already, and that a link to a release zip installs from a zip
    /// written with backslashes and from one whose files sit in a Patch folder.
    /// </summary>
    [Fact]
    public void Install_WritesLinkModsUploadsAndReleaseZipsIntoPatch()
    {
        using var game = new TempFolder();
        game.Put("Patch/Level_Cap.rb", Encoding.UTF8.GetBytes("old"));
        game.Put("Patch/luka_replacer/Heroes/old.luka", Pack);
        var files = new Dictionary<string, string> { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/cecil.luka"] = ModHash.Of("cecil.luka", Pack) };
        var release = new CatalogMod("lukareplacer", "Luka Replacer", "1.0", files, [], "https://mgqonline.org/files/Luka_Replacer.zip", Archive: true);

        var link = ModInstaller.Install([(LinkMod(ModHash.Of("Level_Cap.rb", Script)), "Level_Cap")], _ => Script, game.Path);
        var upload = ModInstaller.Install([(UploadMod(files), "Luka_Replacer")], _ => Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer/Heroes/cecil.luka", Pack)), game.Path);

        Assert.Equal([Path.Combine("Patch", "Level_Cap.rb")], link);
        Assert.Equal(Script, game.Read("Patch/Level_Cap.rb"));
        Assert.Equal([Path.Combine("Patch", "Luka_Replacer.rb"), Path.Combine("Patch", "luka_replacer", "Heroes", "cecil.luka")], upload);

        // A release zip into a game folder without the mod.
        using var other = new TempFolder();
        ModInstaller.Install([(release, "Luka_Replacer")], _ => Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer\\Heroes\\cecil.luka", Pack)), other.Path);
        Assert.Equal(Pack, other.Read("Patch/Luka_Replacer/Heroes/cecil.luka"));

        File.Delete(Path.Combine(other.Path, "Patch", "Luka_Replacer.rb"));
        ModInstaller.Install([(release, "Luka_Replacer")], _ => Zip(("Patch/Luka_Replacer.rb", Script), ("Patch/Luka_Replacer/Heroes/cecil.luka", Pack)), other.Path);
        Assert.Equal(Script, other.Read("Patch/Luka_Replacer.rb"));
        Assert.False(other.Has("Patch/Patch"));
    }

    /// <summary>
    /// Asserts that a newer version removes the files only an older version shipped, as long as they
    /// are that version's and lie in the mod's own places, and that a DLL the game has loaded, which
    /// Windows lets be renamed but not overwritten, is renamed out of the way and deleted by the
    /// first fetch of the next game session.
    /// </summary>
    [Fact]
    public void Install_Update_RemovesOldFilesAndRenamesALoadedDll()
    {
        using var game = new TempFolder();
        var core = Encoding.UTF8.GetBytes("# core\n");
        var library = Encoding.UTF8.GetBytes("new library");
        game.Put("Patch/Foo/core.rb", core);
        game.Put("Patch/Foo/notes.txt", Encoding.UTF8.GetBytes("the player's own"));
        game.Put("Patch/Foo_Core.rb", core);
        game.Put("Patch/Foo/Foo.dll", Encoding.UTF8.GetBytes("old library"));
        var dll = Path.Combine(game.Path, "Patch", "Foo", "Foo.dll");
        var current = new Dictionary<string, string> { ["Foo.rb"] = ModHash.Of("Foo.rb", Script), ["Foo/Foo.dll"] = ModHash.Of("Foo.dll", library) };
        var older = new Dictionary<string, string>
        {
            ["Foo.rb"] = "aa",
            ["Foo/core.rb"] = ModHash.Of("core.rb", core),
            ["Foo/notes.txt"] = ModHash.Of("notes.txt", Encoding.UTF8.GetBytes("notes")),
            ["Foo_Core.rb"] = ModHash.Of("Foo_Core.rb", core),
        };
        var mod = new CatalogMod("foo", "Foo", "2", current, [new ModVersion("2", current), new ModVersion("1", older)], string.Empty, Archive: true);

        using (new FileStream(dll, FileMode.Open, FileAccess.Read, FileShare.Read | FileShare.Delete))
        {
            ModInstaller.Install([(mod, "Foo")], _ => Zip(("Foo.rb", Script), ("Foo/Foo.dll", library)), game.Path);
        }

        Assert.Equal((true, false, true, true), (game.Has("Patch/Foo.rb"), game.Has("Patch/Foo/core.rb"), game.Has("Patch/Foo/notes.txt"), game.Has("Patch/Foo_Core.rb")));
        Assert.Equal(library, File.ReadAllBytes(dll));
        Assert.Equal("old library", File.ReadAllText(dll + ModInstaller.OldDllSuffix));

        new ModFetch(() => throw new SiteFeedException(SiteFeed.Unreachable)).Run(game.Path);
        Assert.Equal((true, false), (game.Has("Patch/Foo/Foo.dll"), game.Has("Patch/Foo/Foo.dll" + ModInstaller.OldDllSuffix)));
    }

    /// <summary>
    /// Asserts that the update of a mod that runs leaves its files as they are and waits in the
    /// waiting folder with the old files it drops, beside a mod that installs at once, and that a
    /// second update while the first waits is listed after it with the next numbers.
    /// </summary>
    [Fact]
    public void Install_ModThatRuns_WaitsForTheNextStart()
    {
        using var game = new TempFolder();
        var core = Encoding.UTF8.GetBytes("# core\n");
        var library = Encoding.UTF8.GetBytes("new library");
        game.Put("Patch/Foo.rb", Encoding.UTF8.GetBytes("old"));
        game.Put("Patch/Foo/core.rb", core);
        game.Put("Patch/Foo/Foo.dll", Encoding.UTF8.GetBytes("old library"));
        var current = new Dictionary<string, string> { ["Foo.rb"] = ModHash.Of("Foo.rb", Script), ["Foo/Foo.dll"] = ModHash.Of("Foo.dll", library) };
        var older = new Dictionary<string, string> { ["Foo.rb"] = "aa", ["Foo/core.rb"] = ModHash.Of("core.rb", core) };
        var foo = new CatalogMod("foo", "Foo", "2", current, [new ModVersion("2", current), new ModVersion("1", older)], string.Empty, Archive: true);

        var written = ModInstaller.Install([(foo, "Foo"), (LinkMod(ModHash.Of("Level_Cap.rb", Script)), "Level_Cap")], mod => mod.Archive ? Zip(("Foo.rb", Script), ("Foo/Foo.dll", library)) : Script, game.Path, ["foo"]);
        ModInstaller.Install([(LinkMod(ModHash.Of("Level_Cap.rb", Script)) with { Version = "1.4" }, "Level_Cap")], _ => Script, game.Path, ["Level_Cap"]);

        Assert.Equal(3, written.Count);
        Assert.Equal(("old", "old library", true), (Encoding.UTF8.GetString(game.Read("Patch/Foo.rb")), Encoding.UTF8.GetString(game.Read("Patch/Foo/Foo.dll")), game.Has("Patch/Foo/core.rb")));
        Assert.Equal(Script, game.Read("Patch/Level_Cap.rb"));
        Assert.Equal(
            "mod\tFoo\t2\nfile\t0\tPatch/Foo.rb\nfile\t1\tPatch/Foo/Foo.dll\nremove\tPatch/Foo/core.rb\nmod\tLevel Cap\t1.4\nfile\t2\tPatch/Level_Cap.rb\n",
            Encoding.UTF8.GetString(game.Read("Patch/Mod_Framework/Waiting/Waiting.txt")));
        Assert.Equal(Script, game.Read("Patch/Mod_Framework/Waiting/0"));
        Assert.Equal(library, game.Read("Patch/Mod_Framework/Waiting/1"));
    }

    /// <summary>
    /// Asserts that a download that differs from the catalog, a file outside the mod's own script and
    /// folder, a zip that lacks a file, holds another version or holds a file twice are refused, and
    /// that a file that cannot be written puts back the files written before it, so a refused install
    /// changes nothing.
    /// </summary>
    [Fact]
    public void Install_RefusesAnythingButTheCatalogsFilesInTheModsOwnPlaces()
    {
        using var game = new TempFolder();
        game.Put("Patch/Patch.rb", Encoding.UTF8.GetBytes("# loader\n"));
        game.Put("Patch/Level_Cap.rb", Encoding.UTF8.GetBytes("old"));
        var good = LinkMod(ModHash.Of("Level_Cap.rb", Script));
        var differing = LinkMod("00" + ModHash.Of("Level_Cap.rb", Script)[2..]) with { Key = "other", Name = "Other" };
        var escape = UploadMod(new() { ["../Escape.rb"] = ModHash.Of("x.rb", Script) });
        var other = UploadMod(new() { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Party_Sheet/sheet.txt"] = ModHash.Of("sheet.txt", Pack) });
        var loader = UploadMod(new() { ["Patch.rb"] = ModHash.Of("x.rb", Script) });
        var exe = good with { Files = new Dictionary<string, string> { ["Level_Cap.exe"] = ModHash.Of("Level_Cap.exe", Script) } };
        var luka = UploadMod(new() { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script), ["Luka_Replacer/Heroes/a.luka"] = ModHash.Of("a.luka", [1]) });
        var script = UploadMod(new() { ["Luka_Replacer.rb"] = ModHash.Of("x.rb", Script) });

        Assert.Contains("Other", Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(good, "Level_Cap"), (differing, "Level_Cap")], _ => Script, game.Path)).Message);
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(good, "Map_Display")], _ => Script, game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(escape, "Escape")], _ => Zip(("../Escape.rb", Script)), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(other, "Luka_Replacer")], _ => Zip(("Luka_Replacer.rb", Script), ("Party_Sheet/sheet.txt", Pack)), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(loader, "Patch")], _ => Zip(("Patch.rb", Script)), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(exe, "Level_Cap")], _ => Script, game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(luka, "Luka_Replacer")], _ => Zip(("Luka_Replacer.rb", Script)), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(luka, "Luka_Replacer")], _ => Zip(("Luka_Replacer.rb", Script), ("Luka_Replacer/Heroes/a.luka", [2])), game.Path));
        Assert.Throws<InvalidDataException>(() => ModInstaller.Install([(script, "Luka_Replacer")], _ => Zip(("Patch/Luka_Replacer.rb", Script), ("Luka_Replacer.rb", Script)), game.Path));

        // A folder in the place of a script makes the second mod's write fail after the first one's.
        Directory.CreateDirectory(Path.Combine(game.Path, "Patch", "Blocked.rb"));
        var blocked = new CatalogMod("blocked", "Blocked", "1.0", new Dictionary<string, string> { ["Blocked.rb"] = ModHash.Of("Blocked.rb", Script) }, [], "https://mgqonline.org/files/Blocked.rb");
        Assert.ThrowsAny<System.Exception>(() => ModInstaller.Install([(good, "Level_Cap"), (blocked, "Blocked")], _ => Script, game.Path));

        Assert.False(game.Has("Escape.rb") || game.Has("Patch/Map_Display.rb") || game.Has("Patch/Party_Sheet") || game.Has("Patch/Luka_Replacer.rb"));
        Assert.Equal("# loader\n", Encoding.UTF8.GetString(game.Read("Patch/Patch.rb")));
        Assert.Equal("old", Encoding.UTF8.GetString(game.Read("Patch/Level_Cap.rb")));
    }

    /// <summary>
    /// Zips files.
    /// </summary>
    /// <param name="files">Each file's path and bytes.</param>
    /// <returns>The zip.</returns>
    internal static byte[] Zip(params (string Path, byte[] Bytes)[] files)
    {
        using var stream = new MemoryStream();

        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            foreach (var (path, bytes) in files)
            {
                using var entry = archive.CreateEntry(path).Open();
                entry.Write(bytes);
            }
        }

        return stream.ToArray();
    }

    /// <summary>
    /// Makes a link mod of one script.
    /// </summary>
    /// <param name="hash">The script's hash in the catalog.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod LinkMod(string hash) =>
        new("levelcap", "Level Cap", "1.3.5", new Dictionary<string, string> { ["Level_Cap.rb"] = hash }, [], "https://mgqonline.org/files/Level_Cap.rb");

    /// <summary>
    /// Makes an uploaded mod.
    /// </summary>
    /// <param name="files">Its files' hashes by path.</param>
    /// <returns>The mod.</returns>
    private static CatalogMod UploadMod(Dictionary<string, string> files) => new("lukareplacer", "Luka Replacer", "1.0", files, [], string.Empty, Archive: true);
}
