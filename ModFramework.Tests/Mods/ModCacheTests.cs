//----------------------------------------------------------------
//  ModCacheTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Checked that a fetch failing in every part ends its round without throwing
//                            - Checked that a fetch whose thread cannot start lets the next one start
//      Paulinchen  2026-11-06: Covered the website as the only source of mods
//                            - Kept the website's lists as plain JSON, without a signature
//      Paulinchen  2026-11-04: Checked the fetches into the cache in one flow and took over the check of the collections
//      Paulinchen  2026-10-30: Covered the collections and a second fetch
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the fetch of the website's list and its collections into the cache,
/// and reading them back.
/// </summary>
public sealed class ModCacheTests
{
    /// <summary>
    /// A website list of one mod.
    /// </summary>
    private static readonly byte[] SiteList = Encoding.UTF8.GetBytes("""
        {"schema":2,"mods":[{"slug":"level-cap","name":"Level Cap","author":"Someone","tag":"Regular","versions":[{"version":"1","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/level-cap/1/download"},"files":[{"path":"Level_Cap.rb","sha256":"aa"}]}]}]}
        """);

    /// <summary>
    /// The collections as the website's API sends them in schema 2.
    /// </summary>
    private static readonly byte[] Collections = Encoding.UTF8.GetBytes("""
        {"schema":2,"generatedAt":"2026-10-30T08:00:00+00:00","collections":[
         {"slug":"story-plus","name":"Story Plus","summary":"A second run.","author":"Someone","updatedAt":"2026-10-29T08:00:00+00:00","page":"https://mgqonline.org/collections/story-plus",
          "mods":[{"slug":"level-cap","version":null,"available":true},{"slug":"old-mod","version":"1.0","available":false}]},
         {"slug":"elsewhere","name":"Elsewhere","summary":"","author":"Someone","updatedAt":"2026-10-29T08:00:00+00:00","page":"https://example.org/x","mods":[]}]}
        """);

    /// <summary>
    /// Asserts that a fetch keeps each source that came and leaves the cache's copy of one that
    /// failed, that a second fetch counts as one more round and keeps what came then, that the
    /// collections read back with their mods in order, a version kept, a mod the website no longer
    /// offers marked and a page off the website dropped, and that a list broken on the disk counts
    /// as none.
    /// </summary>
    [Fact]
    public void Fetch_KeepsWhatCameAndTheOldCopyOfWhatFailed()
    {
        using var game = new TempFolder();
        ModCache.StoreSite(game.Path, SiteList);
        var reachable = false;
        var fetch = new ModFetch(
            () => reachable ? SiteList : throw new SiteFeedException(SiteFeed.Unreachable),
            () => reachable ? Collections : throw new SiteFeedException(SiteFeed.Unreachable));

        fetch.Run(game.Path);

        Assert.Equal((true, 1, false, false), (fetch.Done, fetch.Rounds, fetch.SiteKept, fetch.CollectionsKept));
        Assert.Equal(["level-cap"], ModCache.LoadSite(game.Path)!.Select(mod => mod.Slug));
        Assert.Null(ModCache.LoadCollections(game.Path));

        reachable = true;
        fetch.Run(game.Path);
        var collections = ModCache.LoadCollections(game.Path)!;

        Assert.Equal((2, true, true), (fetch.Rounds, fetch.SiteKept, fetch.CollectionsKept));
        Assert.Equal(["story-plus", "elsewhere"], collections.Select(collection => collection.Slug));
        Assert.Equal([new CollectionEntry("level-cap", string.Empty, true), new CollectionEntry("old-mod", "1.0", false)], collections[0].Mods);
        Assert.Equal(("Story Plus", "https://mgqonline.org/collections/story-plus", string.Empty), (collections[0].Name, collections[0].Page, collections[1].Page));

        var file = Path.Combine(ModCache.Folder, ModCache.SiteFile);
        game.Put(file, game.Read(file)[..^2]);
        Assert.Null(ModCache.LoadSite(game.Path));
    }

    /// <summary>
    /// Asserts that a fetch whose sources and votes all throw, memory running out among them, ends
    /// its round without throwing, and that a thread's work that throws ends only itself, since an
    /// exception escaping a thread ends the game.
    /// </summary>
    [Fact]
    public void Fetch_EveryPartThrowing_EndsTheRoundWithoutThrowing()
    {
        using var game = new TempFolder();
        var fetch = new ModFetch(
            () => throw new InvalidOperationException("site"),
            () => throw new OutOfMemoryException(),
            votes: _ => throw new InvalidOperationException("votes"));

        fetch.Run(game.Path);
        Threads.Run("mods test", () => throw new InvalidOperationException("thread"));

        Assert.Equal((true, 1, false, false), (fetch.Done, fetch.Rounds, fetch.SiteKept, fetch.CollectionsKept));
    }

    /// <summary>
    /// Asserts that a fetch whose thread cannot start, such as when no stack is left for it, leaves
    /// none running, so the next fetch starts and keeps the website's list.
    /// </summary>
    [Fact]
    public void Again_ThreadCannotStart_LetsTheNextFetchStart()
    {
        using var game = new TempFolder();
        var threadsLeft = false;
        var fetch = new ModFetch(() => SiteList, start: work =>
        {
            if (!threadsLeft)
            {
                return false;
            }

            work();
            return true;
        });

        var refused = fetch.Again(game.Path);
        var stuck = fetch.Running;
        threadsLeft = true;
        var again = fetch.Again(game.Path);

        Assert.Equal((false, false, true), (refused, stuck, again));
        Assert.Equal((true, 1, true), (fetch.Done, fetch.Rounds, fetch.SiteKept));
    }
}
