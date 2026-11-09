//----------------------------------------------------------------
//  ModsTopics.Updates.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Removed the update the helper installed once the game closed, which the install does now
//                            - Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-06: Removed the relay's catalog and the GitHub releases as sources of mods; the website is the only one
//                            - Removed the topic of the framework's boot, which deleted the files its last update kept
//      Paulinchen  2026-10-31: Refused an update of a mod no list names in plain words
//      Paulinchen  2026-10-30: Read the cache with the mods without a package for the platform the game runs on
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the updates: the installed mods with a newer version, the framework included, and
/// a version a mod needs.
/// </summary>
internal sealed partial class ModsTopics
{
    /// <summary>
    /// The topic that lists the updates: nil, or {"fetch" => true} to fetch the lists again once the
    /// last fetch ended <see cref="FetchAgainAfter"/> ago, answers {"fetching", "site",
    /// "updates" => [{"id", "name", "folder", "installed", "latest", "framework"}, ...]}, the
    /// framework first, then by name.
    /// </summary>
    public const string UpdatesTopic = "mods.updates";

    /// <summary>
    /// The topic that tells how a version a mod needs stands: {"name" (an id, a slug, a name in
    /// Patch or a title), "version", "exact" (whether exactly that version is needed, an older one
    /// too), "have" (the version the mod knows it runs, or nil)} answers {"state" (see
    /// <see cref="RequireState"/>), "id", "name", "installed", "offered", "framework"}.
    /// </summary>
    public const string RequireTopic = "mods.require";

    /// <summary>
    /// How long ago the last fetch must have ended for the title to fetch the lists again.
    /// </summary>
    internal static readonly TimeSpan FetchAgainAfter = TimeSpan.FromMinutes(30);

    /// <summary>
    /// Registers the topics of the updates on a context.
    /// </summary>
    /// <param name="context">The context.</param>
    private void RegisterUpdates(BridgeContext context)
    {
        context.Register(UpdatesTopic, (_, request) => Updates(request.IsNil ? new RubyHash() : request.AsHash()));
        context.Register(RequireTopic, (_, request) => Require(request.AsHash()));
    }

    /// <summary>
    /// Lists the installed mods whose lists offer a newer version, the framework included.
    /// </summary>
    /// <param name="request">Whether to fetch the lists again, see <see cref="UpdatesTopic"/>.</param>
    /// <returns>The updates.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    internal RubyHash Updates(RubyHash request)
    {
        if (request.TryGetValue("fetch", out var fetch) && !fetch.IsNil && fetch.AsBool() && _fetch.AgainAfter(_game, FetchAgainAfter))
        {
            Log.Write("fetching the mod lists again for their updates");
        }

        _fetch.Start(_game);
        var (_, known, site, _) = Known();
        var updates = ModUpdates.Find(known, ModScan.Detect(known, _game, logged: false));

        return new RubyHash
        {
            { "fetching", _fetch.Running },
            { "site", site },
            {
                "updates", new RubyArray(updates.Select(update => (RubyValue)new RubyHash
                {
                    { "id", update.Mod.Id },
                    { "name", update.Mod.Name },
                    { "folder", update.Mod.Folder },
                    { "installed", update.Installed },
                    { "latest", update.Mod.Latest },
                    { "framework", ModUpdates.IsFramework(update.Mod) },
                }))
            },
        };
    }

    /// <summary>
    /// Tells how a version a mod needs stands; while the lists are being fetched, one they cannot
    /// meet yet is unknown, since the fetch may bring it.
    /// </summary>
    /// <param name="request">The mod and the version, see <see cref="RequireTopic"/>.</param>
    /// <returns>How it stands.</returns>
    /// <exception cref="RubyValueException">A part of the request has another kind.</exception>
    /// <exception cref="BridgeRequestException">The request names no mod or no version.</exception>
    internal RubyHash Require(RubyHash request)
    {
        var name = TextOf(request, "name") ?? string.Empty;
        var least = TextOf(request, "version") ?? string.Empty;
        var exact = request.TryGetValue("exact", out var flag) && !flag.IsNil && flag.AsBool();

        if (name.Length == 0 || ReleaseVersion.Parse(least) == null)
        {
            throw new BridgeRequestException("A need names a mod and a version such as 0.7.0.");
        }

        _fetch.Start(_game);
        var known = Known().Mods;
        var mod = ModUpdates.Named(known, name);
        var state = mod == null ? null : ModScan.Detect([mod], _game, logged: false)[mod.Id];
        var required = ModUpdates.Require(mod, state, least, exact, TextOf(request, "have"));
        var answer = required.State == RequireState.Unavailable && _fetch.Running ? RequireState.Unknown : required.State;
        Log.Write($"{name} needs {(exact ? "exactly " : string.Empty)}{least}: {answer}, {required.Installed ?? "an unknown version"} installed{(required.Offered != null ? $", {required.Offered} offered" : string.Empty)}");

        return new RubyHash
        {
            { "state", answer },
            { "id", mod?.Id },
            { "name", mod?.Name ?? name },
            { "installed", required.Installed },
            { "offered", required.Offered },
            { "framework", mod != null && ModUpdates.IsFramework(mod) },
        };
    }
}
