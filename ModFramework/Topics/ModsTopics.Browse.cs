//----------------------------------------------------------------
//  ModsTopics.Browse.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Turned a collection on in its order in one write and told which other mods are on, its needs kept
//                            - Told the mods of the website an install of a mod also brings, through the mods those need
//                            - Found a mod by a name whatever the picks of the filters
//      Paulinchen  2026-11-08: Told which mods the player installs and updates by hand and left them out of the updates
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Dropped the update of a removed mod that waited for the next start
//                            - Dropped the branches for mods not of the website
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//                            - Read the website's lists without a key
//                            - Narrowed the mods and the collections to those holding every word of the player's search
//      Paulinchen  2026-11-01: Listed the mods in the order asked alone, without lifting the updates and the installed mods
//                            - Told each mod's upvotes and took only an upvote or its taking back
//      Paulinchen  2026-10-31: Refused a removal in plain words
//                            - Named the tag an installed mod has now, the player's retag included
//      Paulinchen  2026-10-30: Told the save safety, conflicts with installed mods, load order, known issues, options,
//                              hotkeys, games, languages, categories, credits, license and links of each mod
//                            - Told this install's vote on each mod and whether it may vote, cast votes and turned the
//                              ratings on and off
//                            - Filtered and ordered the mods by the player's picks, with what the filters offer and each
//                              mod's votes
//                            - Listed the mods and the versions without a package for the platform the game runs on
//                            - Told the framework by the rules every update shares
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Options;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the mod browser: the mods of the website with how each stands in
/// the game folder, the website's collections, a mod's description, and the removal of mods.
/// </summary>
internal sealed partial class ModsTopics
{
    /// <summary>
    /// The topic that lists what the mod browser shows: nil, or {"fetch" => true to fetch the
    /// lists again first, "order" (see <see cref="ModBrowse.Orders"/>; by name without one),
    /// "search" (what the player typed: only the mods and the collections whose texts hold every
    /// word, whatever the case, see <see cref="ModBrowse.Matches"/>),
    /// "picks" => {"categories", "keywords", "languages", "games" => [value, ...], "platform" (see
    /// <see cref="ModBrowse.PlatformPicks"/>; the one the game runs on without one)}, "find" => a mod's id or a name a
    /// requirement names it by} answers
    /// {"fetching", "pictures" (whether images are being cached), "site" and
    /// "collections_kept" (whether the cache holds each list), "total" (every mod the lists have),
    /// "collections_total" (every collection the cache holds),
    /// "picks" (how many the filters button counts), "filters" => {"categories" => [[slug, name,
    /// count, picked], ...], "keywords", "languages" => [[value, name, count, picked], ...], "games"
    /// => [[value, count, picked], ...], "platform" (the one picked), "own_platform" (the one the
    /// game runs on), "platforms" => [value, ...]}, "mods" => [mod, ...] (those the picks let
    /// and the search let through), "updates" => [mod, ...] (every mod an update waits for,
    /// whatever the picks, but the mods installed by hand), "collections" => [collection, ...] (those the search lets through),
    /// "found" (with "find" only: the id of the mod it names among every mod of the lists, whatever the picks and the search, or nil)}. The mods come in the order asked, whatever they stand
    /// as in the game folder: {"id", "name", "author", "source", "page", "summary",
    /// "tag", "by_hand" (whether the player installs and updates it by hand from its page on the
    /// website, see <see cref="BrowsedMod.ByHand"/>), "brings" => [id, ...] (the mods of the website an install also needs, as
    /// <see cref="BringsOf"/> finds them), "status" (see <see cref="ModStatus"/>), "installed" (the known version installed or
    /// nil), "place" (where it lies: "Patch", or "" while not installed), "folder" (its name in
    /// Patch and in Mods.ini), "on" (nil while not installed), "latest",
    /// "bytes", "files", "notes" => [line, ...], "picture" (the cached image's path or nil),
    /// "spoiler", "picture_waits" (whether its image is on its way), "framework" (whether it is the
    /// framework itself), "needs" => [[name, version, state, installed version, folder, id], ...],
    /// "newer_elsewhere" (a version newer than "latest" without a package for the platform the game
    /// runs on, or nil), "upvotes" (nil for a mod not on the website, the count a vote answered
    /// until the list follows), "vote" ("up" or nil: this install's own upvote), "rate"
    /// (nil when this install may vote on it, else why not, see <see cref="ModRatings.Refusal"/>;
    /// nil too for a mod not on the website), "details" => {"save" (the save safety of the latest
    /// version, see <see cref="VersionNotes"/>), "conflicts" => [[name, note, on, folder], ...] (the
    /// installed mods it does not work with, either naming the other), "load_after", "load_before"
    /// => [name, ...], "known_issues" => [line, ...], "options" => [[name, help], ...], "hotkeys" =>
    /// [[name, key name], ...], "works_with" => [value, ...], "languages", "categories", "keywords"
    /// => [name, ...], "credits" => [[name, role], ...], "license" => [name, reuploads, edits] or
    /// nil, "links" => [[kind, address], ...]}, "search" (the name,
    /// summary, author, keywords and where it comes from, which a search looks through)}. A website's mod none of whose versions has a package for this platform
    /// comes among the others with the status <see cref="ModStatus.OtherPlatform"/>, its newest
    /// version as "latest" and nothing to install. A collection is {"slug", "name", "summary",
    /// "author", "page", "mods" => [{"slug", "id", "name", "version" (the version an install brings,
    /// the latest), "available", "other_platform" (whether it is not available only for want of a
    /// package for this platform), "by_hand", "status", "installed", "folder", "on"}, ...]}; a mod whose
    /// installed version is at least the version the collection names is current.
    /// </summary>
    /// <remarks>
    /// An install brings only a mod's latest version, so the version a collection names counts as
    /// the least it needs.
    /// </remarks>
    public const string BrowseTopic = "mods.browse";

    /// <summary>
    /// The topic that turns a collection on: {"id"} turns on its installed mods and puts each tag's
    /// of them in the collection's order, in one write of Mods.ini, and answers the state of
    /// <see cref="SetTopic"/> with "others" => [[name, title], ...]: the mods that are on beside the
    /// collection's and those they need, directly or through the mods those need.
    /// </summary>
    public const string CollectionOnTopic = "mods.collection_on";

    /// <summary>
    /// The topic that tells a mod's description: {"id", "fetch" => false to only read what is
    /// known} answers {"lines" => [line, ...] or nil while it is not known, "fetching" => true or
    /// false}, starting its fetch unless told not to; <see cref="DescribedTopic"/> tells once it
    /// ended.
    /// </summary>
    public const string DescribeTopic = "mods.describe";

    /// <summary>
    /// The topic that removes the installed versions of mods: {"ids" => [id, ...]} answers
    /// {"removed" => [name, ...], "refused" => why for the player, or nil}.
    /// </summary>
    public const string RemoveTopic = "mods.remove";

    /// <summary>
    /// The event once the images of the mods were cached: nil.
    /// </summary>
    public const string PicturesTopic = "mods.pictures";

    /// <summary>
    /// The topic that upvotes a mod of the website or takes this install's upvote back: {"id",
    /// "vote" => "up" or nil} answers {"started" => true or false, "refused" => why not, see
    /// <see cref="ModRatings.Start"/>, "UnknownVote" for any other vote, or nil};
    /// <see cref="VotedTopic"/> tells how it ended.
    /// </summary>
    public const string VoteTopic = "mods.vote";

    /// <summary>
    /// The event once a vote ended: {"id", "vote" (this install's upvote now, or nil), "error" (the
    /// website's name of a refusal, "Unreachable", or nil once counted)}.
    /// </summary>
    public const string VotedTopic = "mods.voted";

    /// <summary>
    /// The topic that tells whether the player rates mods, and turns it on or off: nil or {"on" =>
    /// true or false} answers {"on"}. Off asks the website to forget the install key with its votes.
    /// </summary>
    public const string RatingsTopic = "mods.ratings";

    /// <summary>
    /// The event once a description's fetch ended, well or not: {"id"}.
    /// </summary>
    public const string DescribedTopic = "mods.described";

    /// <summary>
    /// Why a vote other than an upvote or its taking back is refused.
    /// </summary>
    private const string UnknownVote = "UnknownVote";

    /// <summary>
    /// What the id of a mod of the website starts with, before its slug.
    /// </summary>
    private const string SitePrefix = "site:";

    /// <summary>
    /// What the id of a collection starts with, before its slug, as <see cref="PageTopic"/> takes it.
    /// </summary>
    private const string CollectionPrefix = "collection:";



    /// <summary>
    /// The website's collections of the cache, made once per change of its file.
    /// </summary>
    private (string Stamp, IReadOnlyList<SiteCollection>? Collections)? _collections;

    /// <summary>
    /// What the website's filters offer, from the cache, made once per change of its file.
    /// </summary>
    private (string Stamp, SiteFilterOptions? Options)? _filterOptions;

    /// <summary>
    /// Whether the player rates mods, the mods this install downloaded from the website and when the
    /// cache kept its list, read once per browse.
    /// </summary>
    private (bool On, IReadOnlySet<string> Downloaded, DateTime ListKept) _ratings = (true, new HashSet<string>(), DateTime.MinValue);

    /// <summary>
    /// The stamp of the lists whose images were last asked for.
    /// </summary>
    private string? _pictured;

    /// <summary>
    /// The run of the images whose end was posted last, counted as <see cref="ModPictures.Rounds"/>.
    /// </summary>
    private int _picturesPosted;

    /// <summary>
    /// Gets the cache of the mods' images.
    /// </summary>
    internal ModPictures Pictures { get; init; } = ModPictures.Live;

    /// <summary>
    /// Gets the descriptions of the website's mods.
    /// </summary>
    internal ModDescriptions Descriptions { get; init; } = ModDescriptions.Live;

    /// <summary>
    /// Gets the player's votes on the website's mods.
    /// </summary>
    internal ModRatings Ratings { get; init; } = ModRatings.Live;

    /// <summary>
    /// Registers the browser's topics and events on a context.
    /// </summary>
    /// <param name="context">The context.</param>
    private void RegisterBrowse(BridgeContext context)
    {
        context.Register(BrowseTopic, (_, request) => Browse(request.IsNil ? new RubyHash() : request.AsHash()));
        context.Register(CollectionOnTopic, (_, request) => CollectionOn(request.AsHash()));
        context.Register(DescribeTopic, (_, request) => Describe(request.AsHash()));
        context.Register(RemoveTopic, (_, request) => Remove(request.AsHash()));
        context.Register(VoteTopic, (_, request) => Vote(request.AsHash()));
        context.Register(RatingsTopic, (_, request) => RatingsOf(request.IsNil ? new RubyHash() : request.AsHash()));
        context.EveryFrame(PostPictures);
        context.EveryFrame(PostDescribed);
        context.EveryFrame(PostVoted);
    }

    /// <summary>
    /// Starts casting, changing or taking back this install's vote on a mod of the website.
    /// </summary>
    /// <param name="request">The mod and the vote, see <see cref="VoteTopic"/>.</param>
    /// <returns>Whether it started, and why not.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Vote(RubyHash request)
    {
        var id = TextOf(request, "id") ?? string.Empty;
        var cast = TextOf(request, "vote");
        if (cast is not (null or SiteVotes.Up))
        {
            Log.Write($"a vote \"{cast}\" on {id} was refused: mods are only upvoted");
        }

        var refused = !id.StartsWith(SitePrefix, StringComparison.Ordinal) || id.Length == SitePrefix.Length ? ModRatings.NotDownloaded
            : cast is not (null or SiteVotes.Up) ? UnknownVote
            : Ratings.Start(_game, id[SitePrefix.Length..], cast);
        return new RubyHash { { "started", refused == null }, { "refused", refused } };
    }

    /// <summary>
    /// Tells whether the player rates mods, turning it on or off first when asked.
    /// </summary>
    /// <param name="request">Whether to turn it on or off, see <see cref="RatingsTopic"/>.</param>
    /// <returns>Whether ratings are on.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash RatingsOf(RubyHash request)
    {
        if (request.TryGetValue("on", out var on) && !on.IsNil)
        {
            Ratings.Turn(_game, on.AsBool());
        }

        return new RubyHash { { "on", InstallKey.RatingsOn(_game) } };
    }

    /// <summary>
    /// Posts the end of each vote.
    /// </summary>
    /// <param name="context">The context.</param>
    private void PostVoted(BridgeContext context)
    {
        foreach (var ended in Ratings.TakeEnded())
        {
            context.Events.Post(VotedTopic, new RubyHash { { "id", SitePrefix + ended.Slug }, { "vote", ended.Vote }, { "error", ended.Error } });
        }
    }

    /// <summary>
    /// Lists what the mod browser shows for the player's picks, in the order asked, and starts caching
    /// the images of the lists kept now.
    /// </summary>
    /// <param name="request">Whether to fetch the lists again first, the order and the picks, see <see cref="BrowseTopic"/>.</param>
    /// <returns>The mods, what the filters offer and the collections.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Browse(RubyHash request)
    {
        if (request.TryGetValue("fetch", out var fetch) && !fetch.IsNil && fetch.AsBool())
        {
            _fetch.Again(_game);
        }

        var snapshot = Current();
        var (stamp, known, site, elsewhere) = Known();
        var states = ModScan.Detect(known, _game, logged: false);
        var collections = Collections();
        var picks = PicksOf(request);
        var search = TextOf(request, "search") ?? string.Empty;
        var order = TextOf(request, "order") is { } asked && ModBrowse.Orders.Contains(asked) ? asked : ModBrowse.Name;
        var listKept = File.GetLastWriteTimeUtc(Path.Combine(_game, ModCache.Folder, ModCache.SiteFile));
        _ratings = (InstallKey.RatingsOn(_game), InstallKey.Downloaded(_game), listKept);
        CachePictures(stamp, known.Select(mod => mod.Thumbnail).Concat(elsewhere.Select(mod => mod.Thumbnail)));

        var rows = known
            .Select(mod => (Key: (mod.Name, mod.Meta), mod.Id, Status: states[mod.Id].Status, Row: BrowsedOf(mod, states[mod.Id], snapshot.Plan, known)))
            .Concat(elsewhere.Select(mod => (Key: (mod.Name, (SiteMeta?)(mod.Meta ?? SiteMeta.None)), Id: SitePrefix + mod.Slug, Status: ModStatus.OtherPlatform, Row: ElsewhereRowOf(mod, snapshot.Plan, known))))
            .ToList();
        var mods = rows
            .Where(row => ModBrowse.Passes(row.Key.Item2, picks) && ModBrowse.Matches(row.Row["search"].AsText(), search))
            .OrderBy(row => row.Key, ModBrowse.Comparer(order))
            .ThenBy(row => row.Id, StringComparer.Ordinal)
            .Select(row => (RubyValue)row.Row)
            .ToList();
        var updates = rows.Where(row => row.Status == ModStatus.Update && !row.Row["by_hand"].AsBool()).OrderBy(row => row.Key.Item1, StringComparer.OrdinalIgnoreCase).Select(row => (RubyValue)row.Row);

        var answer = new RubyHash
        {
            { "fetching", _fetch.Running },
            { "pictures", Pictures.Running },
            { "site", site },
            { "collections_kept", collections != null },
            { "total", rows.Count },
            { "collections_total", collections?.Count ?? 0 },
            { "picks", picks.CountFor(Platforms.Package) },
            { "filters", FiltersOf(ModBrowse.Filters(rows.Select(row => row.Key.Item2).ToList(), FilterOptions(), picks), picks) },
            { "mods", new RubyArray(mods) },
            { "updates", new RubyArray(updates) },
            { "collections", new RubyArray((collections ?? []).Where(collection => ModBrowse.Matches(string.Join('\n', collection.Name, collection.Author, collection.Summary), search)).Select(collection => (RubyValue)CollectionOf(collection, known, elsewhere, states, snapshot.Plan))) },
        };

        if (TextOf(request, "find") is { } find)
        {
            answer.Add("found", FoundOf(find, known, elsewhere));
        }

        return answer;
    }

    /// <summary>
    /// Finds the mod of the lists a name means, a website's mod without a package for the platform
    /// the game runs on too.
    /// </summary>
    /// <param name="name">The mod's id, or a name a requirement names it by.</param>
    /// <param name="known">Every mod of the lists.</param>
    /// <param name="elsewhere">The website's mods without a package for the platform the game runs on.</param>
    /// <returns>Its id; <see langword="null"/> for none.</returns>
    private static string? FoundOf(string name, IReadOnlyList<BrowsedMod> known, IReadOnlyList<SiteMod> elsewhere)
    {
        if (ModUpdates.Named(known, name) is { } mod)
        {
            return mod.Id;
        }

        var key = ModRequirement.KeyOf(name);
        var other = elsewhere.FirstOrDefault(each => SitePrefix + each.Slug == name || (key.Length > 0 && (ModRequirement.KeyOf(each.Slug) == key || ModRequirement.KeyOf(each.Name) == key)));
        return other == null ? null : SitePrefix + other.Slug;
    }

    /// <summary>
    /// Turns a collection on: its installed mods on, each tag's of them in its order, in one write.
    /// </summary>
    /// <param name="request">The collection's id, see <see cref="CollectionOnTopic"/>.</param>
    /// <returns>The state after it, with the other mods that are on.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash CollectionOn(RubyHash request)
    {
        var id = TextOf(request, "id") ?? string.Empty;
        var snapshot = Current();
        var known = Known().Mods;
        var collection = id.StartsWith(CollectionPrefix, StringComparison.Ordinal) ? Collections()?.FirstOrDefault(each => each.Slug == id[CollectionPrefix.Length..]) : null;
        var members = (collection?.Mods ?? [])
            .Where(entry => entry.Available)
            .Select(entry => known.FirstOrDefault(mod => mod.Id == SitePrefix + entry.Slug))
            .OfType<BrowsedMod>()
            .Select(mod => InstalledOf(mod, snapshot.Plan))
            .OfType<PlannedMod>()
            .Distinct()
            .ToList();
        var lines = snapshot.Plan.Ini.ToList();
        var refused = new RubyArray();

        if (collection == null)
        {
            refused.Add(new RubyArray { id, "This collection is not in the lists." });
        }

        foreach (var member in members)
        {
            var index = lines.FindIndex(line => Same(line.Key, member.Mod.Name));
            lines[index] = new(lines[index].Key, lines[index].Value with { On = true });
        }

        foreach (var tagged in members.GroupBy(member => member.Tag).Where(tagged => tagged.Count() > 1))
        {
            Reorder(lines, snapshot.Plan.Mods.ToList(), tagged.Select(member => member.Mod.Name).ToList(), refused);
        }

        var (state, plan) = Keep(snapshot, lines, refused);
        var names = members.Select(member => member.Mod.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var needed = ModPlan.NeededClosure(plan.Mods.Where(planned => names.Contains(planned.Mod.Name)), plan.Mods);
        var others = plan.Mods.Where(planned => planned.On && !names.Contains(planned.Mod.Name) && !needed.Contains(planned)).ToList();
        Log.Write($"turned on {members.Count} mods of the collection {id} in its order; {others.Count} other mods are on");
        state.Add("others", new RubyArray(others.Select(planned => (RubyValue)new RubyArray { planned.Mod.Name, planned.Mod.Title })));
        return state;
    }

    /// <summary>
    /// Reads the player's picks of the filters.
    /// </summary>
    /// <param name="request">The request, see <see cref="BrowseTopic"/>.</param>
    /// <returns>The picks; none, on the platform the game runs on, without any.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    private static BrowsePicks PicksOf(RubyHash request)
    {
        if (!request.TryGetValue("picks", out var part) || part.IsNil)
        {
            return BrowsePicks.None(Platforms.Package);
        }

        var picks = part.AsHash();
        List<string> Listed(string name) =>
            picks.TryGetValue(name, out var listed) && !listed.IsNil ? listed.AsArray().Select(value => value.AsText()).Distinct(StringComparer.Ordinal).ToList() : [];
        var platform = TextOf(picks, "platform") is { } picked && ModBrowse.PlatformPicks.Contains(picked) ? picked : Platforms.Package;
        return new BrowsePicks(Listed("categories"), Listed("keywords"), Listed("languages"), Listed("games").Where(ModBrowse.Games.Contains).ToList(), platform);
    }

    /// <summary>
    /// Writes what the filters offer as the browser reads it.
    /// </summary>
    /// <param name="filters">What the filters offer.</param>
    /// <param name="picks">The player's picks.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private static RubyHash FiltersOf(BrowseFilters filters, BrowsePicks picks)
    {
        RubyArray Named(IEnumerable<BrowseCount> counts) =>
            new(counts.Select(count => (RubyValue)new RubyArray { count.Value, count.Name, count.Mods, count.Picked }));

        return new RubyHash
        {
            { "categories", Named(filters.Categories) },
            { "keywords", Named(filters.Keywords) },
            { "languages", Named(filters.Languages) },
            { "games", new RubyArray(filters.Games.Select(count => (RubyValue)new RubyArray { count.Value, count.Mods, count.Picked })) },
            { "platform", picks.Platform },
            { "own_platform", Platforms.Package },
            { "platforms", new RubyArray(ModBrowse.PlatformPicks.Select(platform => (RubyValue)platform)) },
        };
    }

    /// <summary>
    /// Reads what the website's filters offer from the cache, again only once its file changed.
    /// </summary>
    /// <returns>The filters; <see langword="null"/> while the cache holds none.</returns>
    private SiteFilterOptions? FilterOptions()
    {
        var stamp = StampOf(Path.Combine(_game, ModCache.Folder, ModCache.FiltersFile));

        if (_filterOptions is { } kept && kept.Stamp == stamp)
        {
            return kept.Options;
        }

        var read = ModCache.LoadFilters(_game);
        _filterOptions = (stamp, read);
        return read;
    }

    /// <summary>
    /// Tells the text a search of the browser looks through: the name, the summary, the author and
    /// the keywords, as the website's search does.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <param name="summary">Its summary.</param>
    /// <param name="author">Its author.</param>
    /// <param name="meta">What the website tells of it; <see langword="null"/> for none.</param>
    /// <returns>The texts, a line each.</returns>
    private static string SearchOf(string name, string summary, string author, SiteMeta? meta) =>
        string.Join('\n', new[] { name, summary, author }.Concat(meta?.Keywords ?? []).Where(text => text.Length > 0));

    /// <summary>
    /// Writes a mod's upvotes and this install's own as the browser reads them.
    /// </summary>
    /// <param name="row">The mod's row, which takes "upvotes", "vote" and "rate".</param>
    /// <param name="slug">The mod's slug on the website.</param>
    /// <param name="meta">What the website tells of the mod; <see langword="null"/> for a mod not on the website.</param>
    private void AddRating(RubyHash row, string slug, SiteMeta? meta)
    {
        if (meta == null)
        {
            row.Add("upvotes", RubyNil.Value);
            row.Add("vote", RubyNil.Value);
            row.Add("rate", RubyNil.Value);
            return;
        }

        var (on, downloaded, listKept) = _ratings;
        row.Add("upvotes", Ratings.UpvotesOf(slug, meta.Upvotes, listKept));
        row.Add("vote", Ratings.VoteOf(_game, slug));
        row.Add("rate", !on ? ModRatings.RatingsOff : downloaded.Contains(slug) ? null : ModRatings.NotDownloaded);
    }

    /// <summary>
    /// Tells a mod's description, starting its fetch.
    /// </summary>
    /// <param name="request">The mod's id, see <see cref="DescribeTopic"/>.</param>
    /// <returns>Its lines while known, and whether it is being fetched.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Describe(RubyHash request)
    {
        var id = TextOf(request, "id") ?? string.Empty;

        if (!id.StartsWith(SitePrefix, StringComparison.Ordinal) || id.Length == SitePrefix.Length)
        {
            return new RubyHash { { "lines", RubyNil.Value }, { "fetching", false } };
        }

        var fetch = !request.TryGetValue("fetch", out var asked) || asked.IsNil || asked.AsBool();
        var (lines, fetching) = Descriptions.Ask(id[SitePrefix.Length..], fetch);
        return new RubyHash { { "lines", lines == null ? RubyNil.Value : new RubyArray(lines.Select(line => (RubyValue)line)) }, { "fetching", fetching } };
    }

    /// <summary>
    /// Removes the installed versions of mods: their updates that wait for the next start, the files
    /// of their own scripts and folders still exactly theirs, and the folders that leaves empty.
    /// </summary>
    /// <param name="request">The mods' ids, see <see cref="RemoveTopic"/>.</param>
    /// <returns>The names of the mods removed, and why one could not be.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Remove(RubyHash request)
    {
        var ids = request.TryGetValue("ids", out var listed) && !listed.IsNil ? listed.AsArray().Select(id => id.AsText()).Distinct(StringComparer.Ordinal).ToList() : [];
        var known = Known().Mods;
        var states = ModScan.Detect(known, _game, logged: false);
        var removed = new RubyArray();
        string? refused = null;

        foreach (var id in ids)
        {
            var mod = known.FirstOrDefault(each => each.Id == id);

            if (mod == null || states[id].Installed == null)
            {
                refused ??= $"{(mod == null ? "This mod" : mod.Name)} cannot be removed here. Delete its files from the Patch folder.";
                continue;
            }

            if (ModUpdates.IsFramework(mod))
            {
                refused ??= "The Mod Framework cannot remove itself.";
                continue;
            }

            try
            {
                WaitingUpdate.Drop(_game, mod.Install.Name);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"the update of {mod.Name} that waits for the next start could not be dropped, so {mod.Name} stays installed: {ex.Message}");
                refused ??= $"The update of {mod.Name} that waits for the next start could not be dropped, so {mod.Name} stays installed.";
                continue;
            }

            var (gone, failed) = ModScan.Remove(mod, states[id], _game);
            Log.Write($"removed {gone.Count} files of {mod.Name} {states[id].Installed!.Version} in Patch{(failed.Count > 0 ? $", {failed.Count} could not be removed" : string.Empty)}");

            if (failed.Count > 0)
            {
                refused ??= $"Some files of {mod.Name} could not be removed.";
            }
            else
            {
                removed.Add(mod.Name);
            }
        }

        Current();
        return new RubyHash { { "removed", removed }, { "refused", refused } };
    }

    /// <summary>
    /// Writes a mod of the lists as the browser reads it.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="state">How it stands in the game folder.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <param name="known">Every mod of the lists, which a requirement may name.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private RubyHash BrowsedOf(BrowsedMod mod, ModState state, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var installed = InstalledOf(mod, plan);
        var picture = mod.Thumbnail is { } thumbnail ? ModPictures.PathOf(_game, thumbnail.Url) : null;

        var row = new RubyHash
        {
            { "id", mod.Id },
            { "name", mod.Name },
            { "author", mod.Author },
            { "source", SiteSource },
            { "page", PageOf(mod.Page) != null },
            { "summary", mod.Summary },
            { "tag", installed?.Tag ?? (mod.Tag.Length > 0 ? mod.Tag : ModTag.Regular) },
            { "by_hand", mod.ByHand },
            { "brings", BringsOf(mod, plan, known) },
            { "status", state.Status },
            { "installed", state.Installed?.Version },
            { "place", installed?.Mod.Place ?? (state.Installed != null ? PatchFolder.Name : string.Empty) },
            { "folder", installed?.Mod.Name ?? mod.Folder },
            { "on", installed == null ? RubyNil.Value : (RubyValue)installed.On },
            { "latest", mod.Latest },
            { "bytes", mod.Bytes },
            { "files", mod.Install.Files.Count },
            { "notes", new RubyArray(mod.Notes.Select(line => (RubyValue)line)) },
            { "picture", picture },
            { "spoiler", mod.Thumbnail?.Spoiler == true },
            { "picture_waits", mod.Thumbnail != null && picture == null && Pictures.Running },
            { "framework", ModUpdates.IsFramework(mod) },
            { "needs", NeedsOf(mod, plan, known) },
            { "newer_elsewhere", mod.NewerElsewhere.Length > 0 ? mod.NewerElsewhere : null },
            { "search", SearchOf(mod.Name, mod.Summary, mod.Author, mod.Meta) },
            { "details", DetailsOf(mod.Meta ?? SiteMeta.None, mod.Known[0].Notes ?? VersionNotes.None, new InstalledMod(mod.Folder, mod, mod.Latest, [], mod.Known[0].Notes), plan, known) },
        };

        AddRating(row, mod.Id[(mod.Id.IndexOf(':') + 1)..], mod.Meta);
        return row;
    }

    /// <summary>
    /// Writes what the website tells of a mod beside its versions and of its latest version beside
    /// its files, as the browser's pane reads it.
    /// </summary>
    /// <param name="meta">What the website tells of the mod.</param>
    /// <param name="notes">What its latest version tells.</param>
    /// <param name="self">The mod as it would be installed, which conflicts are told for.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <param name="known">Every mod of the lists, which name the mods its load order names.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private static RubyHash DetailsOf(SiteMeta meta, VersionNotes notes, InstalledMod self, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        RubyArray Texts(IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));
        RubyArray Pairs(IEnumerable<(string, string)> pairs) => new(pairs.Select(pair => (RubyValue)new RubyArray { pair.Item1, pair.Item2 }));
        string NameOf(string slug) => known.FirstOrDefault(mod => KeysOf(mod).Contains(ModRequirement.KeyOf(slug)))?.Name ?? slug;

        var conflicts = new RubyArray();

        foreach (var planned in plan.Mods.Where(planned => planned.Mod.Known?.Id != self.Known?.Id))
        {
            if (ModPlan.ConflictBetween(self, planned.Mod) is { } conflict)
            {
                conflicts.Add(new RubyArray { planned.Mod.Title, conflict.Note, planned.On, planned.Mod.Name });
            }
        }

        return new RubyHash
        {
            { "save", notes.SaveSafety },
            { "conflicts", conflicts },
            { "load_after", Texts(notes.LoadAfter.Select(NameOf)) },
            { "load_before", Texts(notes.LoadBefore.Select(NameOf)) },
            { "known_issues", Texts(notes.KnownIssues) },
            { "options", Pairs(notes.Options.Select(option => (option.Name, option.Help))) },
            { "hotkeys", Pairs(notes.Hotkeys.Select(hotkey => (hotkey.Name, hotkey.Key is { } code ? KeyNames.Name(code) : string.Empty))) },
            { "works_with", Texts(meta.WorksWith) },
            { "languages", Texts(meta.Languages.Select(ModBrowse.LanguageName)) },
            { "categories", Texts(meta.Categories.Select(category => category.Name.Length > 0 ? category.Name : category.Slug)) },
            { "keywords", Texts(meta.Keywords) },
            { "credits", Pairs(meta.Credits.Select(credit => (credit.Name, credit.Role))) },
            { "license", meta.License is { } license ? new RubyArray { license.Name, license.Reuploads, license.Edits } : RubyNil.Value },
            { "links", Pairs(meta.Links.Select(link => (link.Kind, link.Url))) },
        };
    }

    /// <summary>
    /// Writes a website's mod without a package for the platform the game runs on as the browser
    /// reads it: nothing to install, no files, its newest version as the latest.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <param name="known">Every mod of the lists.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private RubyHash ElsewhereRowOf(SiteMod mod, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var picture = mod.Thumbnail is { } thumbnail ? ModPictures.PathOf(_game, thumbnail.Url) : null;

        var row = new RubyHash
        {
            { "id", SitePrefix + mod.Slug },
            { "name", mod.Name },
            { "author", mod.Author },
            { "source", SiteSource },
            { "page", PageOf(mod.Page) != null },
            { "summary", mod.Summary },
            { "tag", mod.Tag.Length > 0 ? mod.Tag : ModTag.Regular },
            { "by_hand", ModTag.ByHand(mod.Tag) },
            { "brings", new RubyArray() },
            { "status", ModStatus.OtherPlatform },
            { "installed", RubyNil.Value },
            { "place", string.Empty },
            { "folder", mod.Slug },
            { "on", RubyNil.Value },
            { "latest", mod.Versions[0].Version },
            { "bytes", 0 },
            { "files", 0 },
            { "notes", new RubyArray() },
            { "picture", picture },
            { "spoiler", mod.Thumbnail?.Spoiler == true },
            { "picture_waits", mod.Thumbnail != null && picture == null && Pictures.Running },
            { "framework", false },
            { "needs", new RubyArray() },
            { "newer_elsewhere", RubyNil.Value },
            { "search", SearchOf(mod.Name, mod.Summary, mod.Author, mod.Meta) },
            { "details", DetailsOf(mod.Meta ?? SiteMeta.None, mod.Versions[0].Notes ?? VersionNotes.None, new InstalledMod(mod.Slug, null, mod.Versions[0].Version, [], mod.Versions[0].Notes), plan, known) },
        };

        AddRating(row, mod.Slug, mod.Meta ?? SiteMeta.None);
        return row;
    }

    /// <summary>
    /// Finds the installed mod a mod of the lists is.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <returns>The planned mod; <see langword="null"/> while it is not installed.</returns>
    private static PlannedMod? InstalledOf(BrowsedMod mod, PlanResult plan) =>
        plan.Mods.FirstOrDefault(planned => planned.Mod.Known?.Id == mod.Id);

    /// <summary>
    /// Tells how each requirement of a mod's latest version stands among the installed mods, as
    /// installing it would leave it.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <param name="known">Every mod of the lists, which a missing requirement is found among.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private RubyArray NeedsOf(BrowsedMod mod, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var latest = new InstalledMod(mod.Folder, mod, mod.Latest, mod.Known[0].Requires ?? []);
        var needs = ModPlan.NeedsOf(new PlannedMod(latest, mod.Tag, TagSource.Site, true, []), plan.Mods.Where(planned => planned.Mod.Known?.Id != mod.Id).ToList(), _framework);
        var rows = new RubyArray();

        foreach (var need in needs)
        {
            var key = ModRequirement.KeyOf(need.State == ModNeed.Missing ? need.Name : need.Mod);
            var source = need.State == ModNeed.Missing || need.Mod.Length > 0 ? known.FirstOrDefault(other => other != mod && KeysOf(other).Contains(key)) : null;
            var name = need.State == ModNeed.Missing && source != null ? source.Name : need.Name;
            rows.Add(new RubyArray { name, need.Version, need.State, need.Have, need.Mod, source?.Id });
        }

        return rows;
    }

    /// <summary>
    /// Lists the mods of the lists an install of a mod also needs: each requirement of its latest
    /// version no other installed mod meets, and those of their latest versions in turn.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <param name="known">Every mod of the lists, which a missing requirement is found among.</param>
    /// <returns>Their ids, each once, the mod's own needs first.</returns>
    private static RubyArray BringsOf(BrowsedMod mod, PlanResult plan, IReadOnlyList<BrowsedMod> known)
    {
        var brought = new List<BrowsedMod>();
        var waiting = new Queue<BrowsedMod>([mod]);

        while (waiting.TryDequeue(out var needing))
        {
            foreach (var requirement in needing.Known[0].Requires ?? [])
            {
                var key = ModRequirement.KeyOf(requirement.Name);

                if (key == ModRequirement.KeyOf(ModPlan.FrameworkName) || plan.Mods.Any(planned => planned.Mod.Known?.Id != needing.Id && planned.Mod.Keys.Contains(key)))
                {
                    continue;
                }

                if (known.FirstOrDefault(other => other != needing && KeysOf(other).Contains(key)) is { } source && source != mod && !brought.Contains(source))
                {
                    brought.Add(source);
                    waiting.Enqueue(source);
                }
            }
        }

        return new RubyArray(brought.Select(each => (RubyValue)each.Id));
    }

    /// <summary>
    /// Tells the keys a requirement names a mod of the lists by: its name in Patch and its slug's or key's.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The keys, see <see cref="ModRequirement.KeyOf"/>.</returns>
    private static HashSet<string> KeysOf(BrowsedMod mod) =>
        [ModRequirement.KeyOf(mod.Folder), ModRequirement.KeyOf(mod.Id[(mod.Id.IndexOf(':') + 1)..])];

    /// <summary>
    /// Writes a collection as the browser reads it.
    /// </summary>
    /// <param name="collection">The collection.</param>
    /// <param name="known">Every mod of the lists.</param>
    /// <param name="elsewhere">The website's mods without a package for the platform the game runs on.</param>
    /// <param name="states">How each stands, see <see cref="ModScan.Detect"/>.</param>
    /// <param name="plan">The plan of the installed mods.</param>
    /// <returns>See <see cref="BrowseTopic"/>.</returns>
    private static RubyHash CollectionOf(SiteCollection collection, IReadOnlyList<BrowsedMod> known, IReadOnlyList<SiteMod> elsewhere, IReadOnlyDictionary<string, ModState> states, PlanResult plan)
    {
        var mods = new RubyArray();

        foreach (var entry in collection.Mods)
        {
            var mod = known.FirstOrDefault(each => each.Id == SitePrefix + entry.Slug);
            var installed = mod == null ? null : InstalledOf(mod, plan);
            mods.Add(new RubyHash
            {
                { "slug", entry.Slug },
                { "id", mod?.Id },
                { "name", mod?.Name ?? entry.Slug },
                { "version", mod?.Latest ?? (entry.Version.Length > 0 ? entry.Version : null) },
                { "available", entry.Available && mod != null },
                { "other_platform", mod == null && elsewhere.Any(each => each.Slug == entry.Slug) },
                { "by_hand", mod?.ByHand ?? elsewhere.Any(each => each.Slug == entry.Slug && ModTag.ByHand(each.Tag)) },
                { "status", mod == null ? ModStatus.Available : StatusFor(states[mod.Id], entry.Version) },
                { "installed", mod == null ? null : states[mod.Id].Installed?.Version },
                { "folder", installed?.Mod.Name ?? mod?.Folder },
                { "on", installed == null ? RubyNil.Value : (RubyValue)installed.On },
            });
        }

        return new RubyHash
        {
            { "slug", collection.Slug },
            { "id", CollectionPrefix + collection.Slug },
            { "name", collection.Name },
            { "summary", collection.Summary },
            { "author", collection.Author },
            { "page", PageOf(collection.Page) != null },
            { "mods", mods },
        };
    }

    /// <summary>
    /// Tells how a mod of a collection stands: an update whose installed version is at least the
    /// version the collection names is current.
    /// </summary>
    /// <param name="state">How the mod stands, see <see cref="ModScan.Detect"/>.</param>
    /// <param name="least">The version the collection names; empty for the latest.</param>
    /// <returns>See <see cref="ModStatus"/>.</returns>
    private static string StatusFor(ModState state, string least) =>
        state.Status == ModStatus.Update && least.Length > 0 && state.Installed is { } installed && ModMerge.CompareVersions(installed.Version, least) >= 0
            ? ModStatus.Current
            : state.Status;

    /// <summary>
    /// Reads the website's collections of the cache, again only once its file changed.
    /// </summary>
    /// <returns>The collections; <see langword="null"/> while the cache holds none.</returns>
    private IReadOnlyList<SiteCollection>? Collections()
    {
        var stamp = StampOf(Path.Combine(_game, ModCache.Folder, ModCache.CollectionsFile));

        if (_collections is { } kept && kept.Stamp == stamp)
        {
            return kept.Collections;
        }

        var read = ModCache.LoadCollections(_game);
        _collections = (stamp, read);
        return read;
    }

    /// <summary>
    /// Finds the page of a collection of the cache.
    /// </summary>
    /// <param name="id">The collection's id, <see cref="CollectionPrefix"/> and its slug.</param>
    /// <returns>Its page; <see langword="null"/> for an id of no collection.</returns>
    private string? CollectionPage(string id) =>
        id.StartsWith(CollectionPrefix, StringComparison.Ordinal) ? Collections()?.FirstOrDefault(collection => collection.Slug == id[CollectionPrefix.Length..])?.Page : null;

    /// <summary>
    /// Starts caching the images of the lists kept now, once per change of the lists.
    /// </summary>
    /// <param name="stamp">The lists' stamp.</param>
    /// <param name="thumbnails">Their mods' thumbnails, <see langword="null"/> for a mod without one.</param>
    private void CachePictures(string stamp, IEnumerable<SiteThumbnail?> thumbnails)
    {
        if (_pictured == stamp)
        {
            return;
        }

        _pictured = stamp;
        Pictures.Cache(_game, thumbnails.Select(thumbnail => thumbnail?.Url).OfType<string>().ToList());
    }

    /// <summary>
    /// Posts the end of a run of the images, once per run.
    /// </summary>
    /// <param name="context">The context.</param>
    private void PostPictures(BridgeContext context)
    {
        var rounds = Pictures.Rounds;

        if (rounds != _picturesPosted && !Pictures.Running)
        {
            _picturesPosted = rounds;
            context.Events.Post(PicturesTopic, RubyNil.Value);
        }
    }

    /// <summary>
    /// Posts the end of each description's fetch.
    /// </summary>
    /// <param name="context">The context.</param>
    private void PostDescribed(BridgeContext context)
    {
        foreach (var slug in Descriptions.TakeEnded())
        {
            context.Events.Post(DescribedTopic, new RubyHash { { "id", SitePrefix + slug } });
        }
    }
}
