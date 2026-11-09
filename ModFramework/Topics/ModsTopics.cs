//----------------------------------------------------------------
//  ModsTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Started the game again from the game, without the helper
//                            - Installed the framework and the mods that run into the waiting folder
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Opened a mod's page only on the website and dropped the sources of mods
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//                            - Read the website's lists without a key
//                            - Installed a mod at the version asked, from the relay on its own too
//                            - Compared the mods a place needs with the installed ones
//      Paulinchen  2026-11-01: Refused every change of a tag, which only a mod's authors give, and told each mod's summary
//      Paulinchen  2026-10-31: Put a retagged mod at the end of its new tag and refused in plain words
//      Paulinchen  2026-10-30: Named the mods each mod needs in the plan
//                            - Told the mods each mod does not work with, its load order hints and its save safety
//                            - Opened a link of a website's mod beyond its page
//                            - Refused to install a mod without a package for the platform the game runs on and read the relay only on the PC
//                            - Listed the updates, told how a version a mod needs stands and had the helper install updates
//                            - Listed the mods and collections of the mod browser and removed mods
//                            - Told the end of every fetch with the collections
//                            - Told each mod's title, source, update, needs and the mods needing it, and opened a mod's
//                              page
//                            - Compared the mods of a save with the installed ones
//                            - Planned with each mod's version
//                            - Installed mods of the website and the relay, telling how far it came
//                            - Started the game again with an action for after the restart
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the mod management: the installed mods as the Mods screen shows them, the plan the
/// loader follows, the player's changes to Mods.ini, the install of mods, the check of a save's
/// mods, the restart that unloads mods, and the updates.
/// </summary>
/// <remarks>
/// The first of these requests in a game session starts the fetch of the website, so
/// the cache is fresh by the time the player opens a screen; every answer comes from the cache.
/// </remarks>
internal sealed partial class ModsTopics
{
    /// <summary>
    /// The topic that lists the installed mods: nil answers {"mods" => [mod, ...], "fetching" =>
    /// true or false, "site" => whether the cache holds the website's list, "ini" => whether
    /// Mods.ini can be read}, the mods in the order they load. Each mod is {"name", "title",
    /// "author", "summary", "source", "page", "place", "tag", "tag_from", "on", "version", "latest",
    /// "update", "id", "requires" => [[name, version], ...], "needs" => [[name, version, state,
    /// installed version, mod], ...], "needed_by" => [title, ...], "warnings" => [[kind, name,
    /// version], ...], "conflicts" => [[title, note, on, name], ...] (the installed mods it does not
    /// work with, either naming the other), "hints" => [[way ("after" or "before"), title, kept],
    /// ...] (its author's load order hints toward installed mods of its tag), "save" (the save
    /// safety of its version, see <see cref="VersionNotes"/>)}; a mod no source knows has "source", "latest" and "id" nil and "summary" empty, "page" tells whether
    /// <see cref="PageTopic"/> can open its page, "update" whether a newer version of a known version
    /// waits, "needs" each requirement as <see cref="ModNeed"/> tells it, "needed_by" the mods that are
    /// on and need it.
    /// </summary>
    public const string StateTopic = "mods.state";

    /// <summary>
    /// The topic that plans the loading: nil answers {"load" => [[name, tag, place, version, [the
    /// names of the mods that are on which it needs]], ...] of the mods that are on, in the order
    /// they load, "warnings" => [[mod, kind, name, version], ...] of the mods that are on}.
    /// </summary>
    public const string PlanTopic = "mods.plan";

    /// <summary>
    /// The topic that opens the page of a mod or a collection on the website in the player's
    /// browser: {"id", "link" => a kind of <see cref="SiteMeta.LinkKinds"/> to open that
    /// link of a website's mod instead, or nil} answers {"opened" => true or false}.
    /// </summary>
    public const string PageTopic = "mods.page";

    /// <summary>
    /// The topic that keeps the player's changes in Mods.ini: {"on" => {name => true or false},
    /// "order" => [name, ...]} answers the state of <see cref="StateTopic"/> with "written" =>
    /// whether Mods.ini holds the changes and "refused" => [[name, why], ...]. The names of "order"
    /// take the places those mods hold now, in the order given, and must share their tag. Each mod
    /// of a "tag" part is refused, since only a mod's authors tag it.
    /// </summary>
    public const string SetTopic = "mods.set";

    /// <summary>
    /// The event once a fetch ended: {"site", "collections"}, each true or false, whether
    /// that list was fetched and kept.
    /// </summary>
    public const string FetchedTopic = "mods.fetched";

    /// <summary>
    /// The topic that compares the mods a save was made with against the installed ones: {"mods" =>
    /// [[name, version, tag], ...]} as the save's header names them answers {"rows" => [{"kind",
    /// "name", "title", "saved", "installed", "target"}, ...]}, see <see cref="ModCheck"/> and
    /// <see cref="CheckRow"/>; no rows when no mod is off or missing.
    /// </summary>
    public const string CheckTopic = "mods.check";

    /// <summary>
    /// The topic that compares the mods a place needs with the installed ones: {"mods" =>
    /// [[name, version, differs], ...]} answers {"rows" => [{"kind", "name", "title", "have",
    /// "want", "target", "installed"}, ...]}, see <see cref="ModCheck.Needs"/> and
    /// <see cref="NeedRow"/>; no rows when every mod is on in the version needed.
    /// </summary>
    public const string NeedsTopic = "mods.needs";

    /// <summary>
    /// The topic that starts the game's own Game.exe again, the last thing the closing game does:
    /// {"action" => name or nil, "value" => text or nil} answers {"started" => true or false,
    /// "refused" => why, or nil}. The action reaches the game that starts again, see
    /// <see cref="GameRestart.ActionVariable"/>.
    /// </summary>
    public const string RestartTopic = "mods.restart";

    /// <summary>
    /// The topic that starts installing mods of the website into the Patch folder, each into its
    /// own script and folder: {"ids" => [id, ...], "versions" => {id => version} (the version to
    /// write of each, the latest when left out), "running" => [name, ...] (the mods that run in the
    /// game, which wait for the next start as the framework does)} answers {"started" => true or
    /// false, "refused" => why for the player, or nil}.
    /// <see cref="InstallingTopic"/> tells how far it came, <see cref="InstalledTopic"/> how it ended.
    /// </summary>
    public const string InstallTopic = "mods.install";

    /// <summary>
    /// The event, latest only, while an install runs: {"done" => mods downloaded, "total" => mods
    /// to install, "mod" => the name of the mod downloading now, nil while the files are written}.
    /// </summary>
    public const string InstallingTopic = "mods.installing";

    /// <summary>
    /// The event once an install ended: {"installed" => [name, ...] of the mods installed, none
    /// when it failed, "mod" => the name of the mod that failed or nil, "error" => why for the
    /// player or nil}.
    /// </summary>
    public const string InstalledTopic = "mods.installed";

    /// <summary>
    /// What "source" tells the scripts of a mod the website knows.
    /// </summary>
    private const string SiteSource = "site";

    /// <summary>
    /// The game's folder.
    /// </summary>
    private readonly string _game;

    /// <summary>
    /// Opens an address in the player's browser.
    /// </summary>
    private readonly Action<string> _openUrl;

    /// <summary>
    /// The fetch of the game session.
    /// </summary>
    private readonly ModFetch _fetch;


    /// <summary>
    /// The framework's version, which a mod may need at least.
    /// </summary>
    private readonly string _framework;

    /// <summary>
    /// Starts the game again with an action's text, or none, and tells whether it started.
    /// </summary>
    private readonly Func<string?, bool> _restart;

    /// <summary>
    /// Installs mods.
    /// </summary>
    private readonly ModInstall _install;

    /// <summary>
    /// The progress of the install last told the scripts.
    /// </summary>
    private InstallProgress _told = InstallProgress.None;

    /// <summary>
    /// The mods of the cache, made once per change of its files, and the website's mods without a
    /// package for the platform the game runs on.
    /// </summary>
    private (string Stamp, IReadOnlyList<BrowsedMod> Mods, bool Site, IReadOnlyList<SiteMod> Elsewhere)? _known;

    /// <summary>
    /// The fetch whose end was posted last, counted as <see cref="ModFetch.Rounds"/>.
    /// </summary>
    private int _postedRound;

    /// <summary>
    /// Creates the topics.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="fetch">The fetch of the game session.</param>
    /// <param name="frameworkVersion">The framework's version.</param>
    /// <param name="restart">Starts the game again with an action's text, or none, and tells whether it started.</param>
    /// <param name="install">Installs mods.</param>
    /// <param name="openUrl">Opens an address in the player's browser.</param>
    internal ModsTopics(string gameFolder, ModFetch fetch, string frameworkVersion, Func<string?, bool> restart, ModInstall install, Action<string> openUrl)
    {
        _install = install;
        _openUrl = openUrl;
        _game = gameFolder;
        _fetch = fetch;
        _framework = frameworkVersion;
        _restart = restart;
    }

    /// <summary>
    /// Registers the topics on a context, for the game's folder, the live sources, the game's own
    /// program and the install of the game session.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context) =>
        new ModsTopics(ModFolder.GameRoot, ModFetch.Live, FrameworkBridge.Build, action => GameRestart.StartAgain(GameRestart.GameExeOf(ModFolder.GameRoot), action), ModInstall.Live, OpenInBrowser)
            .RegisterOn(context);

    /// <summary>
    /// Opens an address in the player's browser, as Windows opens it; under Wine its browser.
    /// </summary>
    /// <param name="url">The address.</param>
    private static void OpenInBrowser(string url)
    {
        using var _ = Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
    }

    /// <summary>
    /// Registers the topics and the events of the ended fetch and of the install on a context.
    /// </summary>
    /// <param name="context">The context.</param>
    internal void RegisterOn(BridgeContext context)
    {
        context.Register(StateTopic, (_, _) => StateOf(Current()));
        context.Register(PlanTopic, (_, _) => LoadOf(Current().Plan));
        context.Register(SetTopic, (_, request) => Set(request.AsHash()));
        context.Register(RestartTopic, (_, request) => Restart(request.AsHash()));
        context.Register(InstallTopic, (_, request) => Install(request.AsHash()));
        context.Register(CheckTopic, (_, request) => Check(request.AsHash()));
        context.Register(NeedsTopic, (_, request) => Needs(request.AsHash()));
        context.Register(PageTopic, (_, request) => Page(request.AsHash()));
        context.Events.Coalesce(InstallingTopic);
        context.EveryFrame(PostFetched);
        context.EveryFrame(PostInstall);
        RegisterBrowse(context);
        RegisterUpdates(context);
    }

    /// <summary>
    /// Starts the game again, carrying the action.
    /// </summary>
    /// <param name="request">The action, see <see cref="RestartTopic"/>.</param>
    /// <returns>Whether the game started, and why the action was refused.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Restart(RubyHash request)
    {
        if (GameRestart.ActionText(TextOf(request, "action"), TextOf(request, "value"), out var action) is { } why)
        {
            Log.Write($"did not restart the game: {why}");
            return new RubyHash { { "started", false }, { "refused", why } };
        }

        return new RubyHash { { "started", _restart(action) }, { "refused", RubyNil.Value } };
    }

    /// <summary>
    /// Opens the page of a mod of the cache's lists, if it lies on the website, or a link of a
    /// website's mod the website named.
    /// </summary>
    /// <param name="request">The mod's id and the kind of the link, see <see cref="PageTopic"/>.</param>
    /// <returns>Whether it was opened.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Page(RubyHash request)
    {
        var id = TextOf(request, "id") ?? string.Empty;

        if (TextOf(request, "link") is { } kind)
        {
            var meta = Known().Mods.FirstOrDefault(mod => mod.Id == id)?.Meta ?? ElsewhereOf(id)?.Meta;
            return meta?.Links.FirstOrDefault(link => link.Kind == kind) is { } link ? Open(link.Url) : Refused(id, $"it has no {kind} link");
        }

        var page = Known().Mods.FirstOrDefault(mod => mod.Id == id)?.Page ?? ElsewhereOf(id)?.Page ?? CollectionPage(id);

        if (PageOf(page) is not { } url)
        {
            return Refused(id, page is { Length: > 0 } ? $"{page} is not on the website" : "it has none");
        }

        return Open(url);
    }

    /// <summary>
    /// Tells that a page was not opened, and why in the log.
    /// </summary>
    /// <param name="id">The mod's or the collection's id.</param>
    /// <param name="why">Why not.</param>
    /// <returns>{"opened" => false}.</returns>
    private static RubyHash Refused(string id, string why)
    {
        Log.Write($"did not open the page of {id}: {why}");
        return new RubyHash { { "opened", false } };
    }

    /// <summary>
    /// Opens an address in the player's browser.
    /// </summary>
    /// <param name="url">The address, checked before.</param>
    /// <returns>Whether it was opened.</returns>
    private RubyHash Open(string url)
    {

        try
        {
            _openUrl(url);
        }
        catch (Exception ex) when (ex is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            Log.Write($"could not open {url}: {ex.Message}");
            return new RubyHash { { "opened", false } };
        }

        Log.Write($"opened {url}");
        return new RubyHash { { "opened", true } };
    }

    /// <summary>
    /// Reads a mod's page as an address the player's browser may open.
    /// </summary>
    /// <param name="page">The page the source gives.</param>
    /// <returns>The address; <see langword="null"/> for none, or one not on the website over https.</returns>
    private static string? PageOf(string? page) =>
        Uri.TryCreate(page, UriKind.Absolute, out var url) && url.Scheme == Uri.UriSchemeHttps && string.Equals(url.Host, SiteDownload.Host, StringComparison.OrdinalIgnoreCase)
            ? url.AbsoluteUri
            : null;

    /// <summary>
    /// Compares the mods a save names with the installed ones.
    /// </summary>
    /// <param name="request">The save's mods, see <see cref="CheckTopic"/>.</param>
    /// <returns>The rows of the mods that differ.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Check(RubyHash request)
    {
        var saved = new List<SavedMod>();

        if (request.TryGetValue("mods", out var listed) && !listed.IsNil)
        {
            foreach (var entry in listed.AsArray())
            {
                var parts = entry.AsArray();
                var name = parts.Count > 0 && !parts[0].IsNil ? parts[0].AsText() : string.Empty;

                if (name.Length > 0)
                {
                    saved.Add(new SavedMod(name, PartText(parts, 1), PartText(parts, 2)));
                }
            }
        }

        var rows = ModCheck.Compare(saved, Current().Plan, Known().Mods);

        if (rows.Count > 0)
        {
            Log.Write($"a save names mods that differ: {string.Join(", ", rows.Select(row => $"{row.Name} ({row.Kind})"))}");
        }

        return new RubyHash
        {
            {
                "rows", new RubyArray(rows.Select(row => (RubyValue)new RubyHash
                {
                    { "kind", row.Kind }, { "name", row.Name }, { "title", row.Title }, { "saved", row.Saved }, { "installed", row.Installed }, { "target", row.Target },
                }))
            },
        };
    }

    /// <summary>
    /// Compares the mods a place needs with the installed ones.
    /// </summary>
    /// <param name="request">The mods needed, see <see cref="NeedsTopic"/>.</param>
    /// <returns>The rows of the mods that are not on in the version needed.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Needs(RubyHash request)
    {
        var needed = new List<NeededMod>();

        if (request.TryGetValue("mods", out var listed) && !listed.IsNil)
        {
            foreach (var entry in listed.AsArray())
            {
                var parts = entry.AsArray();
                var name = PartText(parts, 0);

                if (name.Length > 0)
                {
                    needed.Add(new NeededMod(name, PartText(parts, 1), parts.Count > 2 && parts[2] is RubyBool { Flag: true }));
                }
            }
        }

        var rows = ModCheck.Needs(needed, Current().Plan, Known().Mods);
        Log.Write(rows.Count == 0 ? $"a place needs {needed.Count} mods, all on" : $"a place needs mods that are not on: {string.Join(", ", rows.Select(row => $"{row.Name} ({row.Kind})"))}");

        return new RubyHash
        {
            {
                "rows", new RubyArray(rows.Select(row => (RubyValue)new RubyHash
                {
                    { "kind", row.Kind }, { "name", row.Name }, { "title", row.Title }, { "have", row.Have }, { "want", row.Want }, { "target", row.Target },
                    { "installed", row.Installed },
                }))
            },
        };
    }

    /// <summary>
    /// Reads a text of an entry's part.
    /// </summary>
    /// <param name="parts">The entry.</param>
    /// <param name="index">The part's place.</param>
    /// <returns>Its text; empty when the part is missing or nil.</returns>
    /// <exception cref="RubyValueException">The part is no text.</exception>
    private static string PartText(RubyArray parts, int index) => parts.Count > index && !parts[index].IsNil ? parts[index].AsText() : string.Empty;

    /// <summary>
    /// Starts installing mods of the cache's lists.
    /// </summary>
    /// <param name="request">The mods' ids, see <see cref="InstallTopic"/>.</param>
    /// <returns>Whether it started, and why not.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Install(RubyHash request)
    {
        var ids = request.TryGetValue("ids", out var listed) && !listed.IsNil ? listed.AsArray().Select(id => id.AsText()).Distinct(StringComparer.Ordinal).ToList() : [];
        var versions = Part(request, "versions").ToDictionary(pair => pair.Key.AsText(), pair => pair.Value.IsNil ? null : pair.Value.AsText(), StringComparer.Ordinal);
        var offers = ids.Select(id => (Id: id, Mod: OfferOf(id, versions.GetValueOrDefault(id)))).ToList();
        var missing = offers.Where(offer => offer.Mod == null).Select(offer => offer.Id).FirstOrDefault();
        var mods = missing == null ? offers.Select(offer => offer.Mod!).ToList() : [];
        var running = request.TryGetValue("running", out var loaded) && !loaded.IsNil ? loaded.AsArray().Select(name => name.AsText()).ToList() : [];
        var refused = missing != null && ElsewhereOf(missing) is { } elsewhere ? $"{elsewhere.Name} is not available on this platform."
            : missing != null ? $"{missing} is not available right now. Try again in a minute."
            : _install.Start(mods, _game, running);

        if (refused != null)
        {
            Log.Write($"did not install {string.Join(", ", ids)}: {refused}");
        }

        return new RubyHash { { "started", refused == null }, { "refused", refused } };
    }

    /// <summary>
    /// Reads a text of a request's part.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="name">The part's name.</param>
    /// <returns>Its text; <see langword="null"/> when the part is missing or nil.</returns>
    /// <exception cref="RubyValueException">The part is no text.</exception>
    private static string? TextOf(RubyHash request, string name) =>
        request.TryGetValue(name, out var part) && !part.IsNil ? part.AsText() : null;

    /// <summary>
    /// Keeps the player's changes in Mods.ini.
    /// </summary>
    /// <param name="request">The changes, see <see cref="SetTopic"/>.</param>
    /// <returns>The state after them, with what was written and refused.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Set(RubyHash request)
    {
        var snapshot = Current();
        var lines = snapshot.Plan.Ini.ToList();
        var refused = new RubyArray();
        var managed = snapshot.Plan.Mods.ToList();

        int? LineOf(string name)
        {
            if (managed.Exists(mod => Same(mod.Mod.Name, name)))
            {
                return lines.FindIndex(line => Same(line.Key, name));
            }

            refused.Add(new RubyArray { name, "This mod is no longer in the Patch folder." });
            return null;
        }

        foreach (var (name, on) in Part(request, "on"))
        {
            if (LineOf(name.AsText()) is { } index)
            {
                lines[index] = new(lines[index].Key, lines[index].Value with { On = on.AsBool() });
            }
        }

        foreach (var (name, _) in Part(request, "tag"))
        {
            refused.Add(new RubyArray { name, "Tags come from the mod's author." });
        }

        if (request.TryGetValue("order", out var order) && !order.IsNil)
        {
            Reorder(lines, managed, order.AsArray().Select(name => name.AsText()).ToList(), refused);
        }

        var plan = ModPlan.Build(snapshot.Installed, lines, _framework);
        var written = snapshot.IniReadable && ModsIni.Write(_game, plan.Ini);

        if (!snapshot.IniReadable)
        {
            Log.Write("did not keep the changes to the mods: Mods.ini cannot be read");
        }

        var state = StateOf(snapshot with { Plan = written ? plan : snapshot.Plan });
        state.Add("written", written);
        state.Add("refused", refused);
        return state;
    }

    /// <summary>
    /// Plans the mods from the cache, Mods.ini and the game folder, and keeps the plan's lines in
    /// Mods.ini, so a mod new to it gets its line.
    /// </summary>
    /// <returns>The installed mods, the plan, and the state of the sources.</returns>
    internal Snapshot Current()
    {
        _fetch.Start(_game);
        var (_, known, site, _) = Known();
        var ini = ModsIni.Load(_game);
        var installed = InstalledMods.Scan(_game, known);
        var plan = ModPlan.Build(installed, ini?.ToList() ?? [], _framework);

        if (ini != null)
        {
            ModsIni.Write(_game, plan.Ini);
        }
        else
        {
            Log.Write("Mods.ini cannot be read, so every mod counts as on and nothing is written");
        }

        return new Snapshot(installed, plan, site, ini != null);
    }

    /// <summary>
    /// Moves mods within their tag.
    /// </summary>
    /// <param name="lines">The lines of Mods.ini in the order the mods load.</param>
    /// <param name="managed">The mods as planned.</param>
    /// <param name="names">The mods in their new order, which take the places they hold now.</param>
    /// <param name="refused">Takes why the order was refused.</param>
    private static void Reorder(List<KeyValuePair<string, ModsIniEntry>> lines, List<PlannedMod> managed, List<string> names, RubyArray refused)
    {
        var mods = names.Select(name => managed.Find(mod => Same(mod.Mod.Name, name))).ToList();
        var why = mods.Contains(null) ? "Every mod of an order must be in Patch."
            : mods.Select(mod => mod!.Tag).Distinct().Count() > 1 ? "A mod moves only within its tag."
            : names.Distinct(StringComparer.OrdinalIgnoreCase).Count() != names.Count ? "An order names a mod once."
            : null;

        if (why != null)
        {
            foreach (var name in names)
            {
                refused.Add(new RubyArray { name, why });
            }

            return;
        }

        var places = names.Select(name => lines.FindIndex(line => Same(line.Key, name))).Order().ToList();
        var moved = names.Select(name => lines.First(line => Same(line.Key, name))).ToList();

        for (var index = 0; index < places.Count; index++)
        {
            lines[places[index]] = moved[index];
        }
    }

    /// <summary>
    /// Reads a Hash of a request's part.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="name">The part's name.</param>
    /// <returns>Its pairs; none when the part is missing or nil.</returns>
    /// <exception cref="RubyValueException">The part is no Hash.</exception>
    private static IEnumerable<KeyValuePair<RubyValue, RubyValue>> Part(RubyHash request, string name) =>
        request.TryGetValue(name, out var part) && !part.IsNil ? part.AsHash() : [];

    /// <summary>
    /// Tells whether two names of mods are one, as Windows names folders.
    /// </summary>
    /// <param name="one">One name.</param>
    /// <param name="other">The other name.</param>
    /// <returns>Whether they are the same but for case.</returns>
    private static bool Same(string one, string other) => string.Equals(one, other, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Writes the plan as the loader reads it.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <returns>See <see cref="PlanTopic"/>.</returns>
    private RubyHash LoadOf(PlanResult plan)
    {
        var load = new RubyArray();
        var warnings = new RubyArray();

        foreach (var mod in plan.Mods.Where(mod => mod.On))
        {
            var needs = ModPlan.NeedsOf(mod, plan.Mods, _framework).Where(need => need.Mod.Length > 0 && need.State != ModNeed.Off).Select(need => (RubyValue)need.Mod);
            load.Add(new RubyArray { mod.Mod.Name, mod.Tag, mod.Mod.Place, mod.Mod.Version, new RubyArray(needs) });

            foreach (var warning in mod.Warnings)
            {
                warnings.Add(new RubyArray { mod.Mod.Name, warning.Kind, warning.Name, warning.Version });
            }
        }

        return new RubyHash { { "load", load }, { "warnings", warnings } };
    }

    /// <summary>
    /// Writes the installed mods as the Mods screen reads them.
    /// </summary>
    /// <param name="snapshot">The plan and the state of the sources.</param>
    /// <returns>See <see cref="StateTopic"/>.</returns>
    private RubyHash StateOf(Snapshot snapshot)
    {
        var mods = new RubyArray();
        var plan = snapshot.Plan;

        foreach (var planned in plan.Mods)
        {
            var mod = planned.Mod;
            var update = mod.Known is { } known && mod.Version != InstalledMod.Unknown && ModMerge.CompareVersions(known.Latest, mod.Version) > 0;
            mods.Add(new RubyHash
            {
                { "name", mod.Name },
                { "title", mod.Title },
                { "author", mod.Known?.Author ?? string.Empty },
                { "summary", mod.Known?.Summary ?? string.Empty },
                { "source", mod.Known is null ? null : SiteSource },
                { "page", PageOf(mod.Known?.Page) != null },
                { "place", mod.Place },
                { "tag", planned.Tag },
                { "tag_from", planned.TagFrom },

                { "on", planned.On },
                { "version", mod.Version },
                { "latest", mod.Known?.Latest },
                { "update", update },
                { "id", mod.Known?.Id },
                { "requires", new RubyArray(mod.Requires.Select(requirement => (RubyValue)new RubyArray { requirement.Name, requirement.Version })) },
                { "needs", new RubyArray(ModPlan.NeedsOf(planned, plan.Mods, _framework).Select(need => (RubyValue)new RubyArray { need.Name, need.Version, need.State, need.Have, need.Mod })) },
                { "needed_by", new RubyArray(ModPlan.NeededBy(planned, plan.Mods).Select(title => (RubyValue)title)) },
                { "warnings", new RubyArray(planned.Warnings.Select(warning => (RubyValue)new RubyArray { warning.Kind, warning.Name, warning.Version })) },
                { "conflicts", ConflictsOf(planned, plan.Mods) },
                { "hints", new RubyArray(ModPlan.HintsOf(planned, plan.Mods).Select(hint => (RubyValue)new RubyArray { hint.Way, hint.Other.Mod.Title, hint.Kept })) },
                { "save", mod.Notes?.SaveSafety ?? VersionNotes.NotStated },
            });
        }

        return new RubyHash { { "mods", mods }, { "fetching", _fetch.Running }, { "site", snapshot.Site }, { "ini", snapshot.IniReadable } };
    }

    /// <summary>
    /// Lists the installed mods a mod does not work with.
    /// </summary>
    /// <param name="planned">The mod.</param>
    /// <param name="mods">Every planned mod.</param>
    /// <returns>See <see cref="StateTopic"/>.</returns>
    private static RubyArray ConflictsOf(PlannedMod planned, IReadOnlyList<PlannedMod> mods)
    {
        var conflicts = new RubyArray();

        foreach (var other in mods.Where(other => other != planned))
        {
            if (ModPlan.ConflictBetween(planned.Mod, other.Mod) is { } conflict)
            {
                conflicts.Add(new RubyArray { other.Mod.Title, conflict.Note, other.On, other.Mod.Name });
            }
        }

        return conflicts;
    }

    /// <summary>
    /// Makes the mods of the cache, again only once its file changed.
    /// </summary>
    /// <returns>The mods, whether the cache holds the website's list, and the website's mods without a package for the platform the game runs on.</returns>
    private (string Stamp, IReadOnlyList<BrowsedMod> Mods, bool Site, IReadOnlyList<SiteMod> Elsewhere) Known()
    {
        var stamp = StampOf(Path.Combine(_game, ModCache.Folder, ModCache.SiteFile));

        if (_known is { } known && known.Stamp == stamp)
        {
            return known;
        }

        var site = ModCache.LoadSite(_game);
        var made = (stamp, ModMerge.Merge(site), site != null, ModMerge.OnOtherPlatforms(site));
        _known = made;
        return made;
    }

    /// <summary>
    /// Finds a mod of the website without a package for the platform the game runs on.
    /// </summary>
    /// <param name="id">The mod's id, <c>site:</c> and its slug.</param>
    /// <returns>The mod; <see langword="null"/> for another id.</returns>
    private SiteMod? ElsewhereOf(string id) => Known().Elsewhere.FirstOrDefault(mod => SitePrefix + mod.Slug == id);


    /// <summary>
    /// Finds the mod an install writes: a mod of the website at its latest, or at a version the website keeps.
    /// </summary>
    /// <param name="id">The mod's id.</param>
    /// <param name="version">The version to write; <see langword="null"/> for the latest.</param>
    /// <returns>The mod as the install writes it; <see langword="null"/> when no source installs it at that version.</returns>
    private BrowsedMod? OfferOf(string id, string? version)
    {
        var mod = Known().Mods.FirstOrDefault(each => each.Id == id);

        if (mod == null || version == null || string.Equals(mod.Latest, version, StringComparison.OrdinalIgnoreCase))
        {
            return mod;
        }

        var site = ModCheck.Installs(mod, version) ? ModCache.LoadSite(_game) : null;
        var moved = site == null ? null : ModUpdates.AtVersion(site, ModUpdates.SlugOf(mod), version);
        return moved == null ? null : ModMerge.Merge(moved).FirstOrDefault(each => each.Id == id);
    }

    /// <summary>
    /// Stamps a file by its size and the time it was written.
    /// </summary>
    /// <param name="path">The file's full path.</param>
    /// <returns>The stamp; "-" for a missing file.</returns>
    private static string StampOf(string path)
    {
        var file = new FileInfo(path);
        return file.Exists ? $"{file.Length}@{file.LastWriteTimeUtc.Ticks}" : "-";
    }

    /// <summary>
    /// Posts how far the install came, once per change, and how it ended, once per install.
    /// </summary>
    /// <param name="context">The context.</param>
    private void PostInstall(BridgeContext context)
    {
        var progress = _install.Progress;

        if (progress == _told || progress.Round == 0)
        {
            return;
        }

        if (progress.Running)
        {
            context.Events.Post(InstallingTopic, new RubyHash { { "done", progress.Done }, { "total", progress.Total }, { "mod", progress.Mod } });
        }
        else if (_told.Round != progress.Round || _told.Running)
        {
            context.Events.Post(InstalledTopic, new RubyHash
            {
                { "installed", new RubyArray(progress.Installed.Select(name => (RubyValue)name)) },
                { "mod", progress.Mod },
                { "error", progress.Error },
            });
        }

        _told = progress;
    }

    /// <summary>
    /// Posts the event of the ended fetch once.
    /// </summary>
    /// <param name="context">The context.</param>
    private void PostFetched(BridgeContext context)
    {
        if (!_fetch.Done || _fetch.Rounds == _postedRound)
        {
            return;
        }

        _postedRound = _fetch.Rounds;
        context.Events.Post(FetchedTopic, new RubyHash { { "site", _fetch.SiteKept }, { "collections", _fetch.CollectionsKept } });
    }
}

/// <summary>
/// The installed mods and their plan at one moment.
/// </summary>
/// <param name="Installed">The installed mods.</param>
/// <param name="Plan">Their plan.</param>
/// <param name="Site">Whether the cache holds the website's list.</param>
/// <param name="IniReadable">Whether Mods.ini could be read, or is missing.</param>
internal sealed record Snapshot(IReadOnlyList<InstalledMod> Installed, PlanResult Plan, bool Site, bool IniReadable);
