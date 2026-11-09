//----------------------------------------------------------------
//  ModRatings.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Caught every error of fetching, forgetting and keeping votes, so none ends the game
//                            - Refused a vote whose thread could not start, so it may start again
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-01: Kept the upvotes a vote answered alone
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// The player's upvotes on the website's mods: casts them on a thread through the install key, keeps
/// this install's own upvotes as last fetched and the count a vote answered until the website's
/// list follows, and asks the website to forget the key once the player turns upvotes off.
/// </summary>
/// <param name="fetchVotes">Fetches the key's own votes as they come.</param>
/// <param name="vote">Upvotes or takes an upvote back: the slug, the vote or <see langword="null"/>, and the key.</param>
/// <param name="forget">Asks the website to forget a key.</param>
/// <param name="start">Runs work on a thread of its own and tells whether it started.</param>
internal sealed class ModRatings(Func<string, byte[]> fetchVotes, Func<string, string?, string, VoteAnswer> vote, Action<string> forget, Func<Action, bool> start)
{
    /// <summary>
    /// Why a vote is refused while the player turned ratings off.
    /// </summary>
    public const string RatingsOff = "RatingsOff";

    /// <summary>
    /// Why a vote is refused on a mod this install did not download from the website.
    /// </summary>
    public const string NotDownloaded = "NotDownloaded";

    /// <summary>
    /// Why a vote is refused while one on the same mod is on its way.
    /// </summary>
    public const string Voting = "Voting";

    /// <summary>
    /// Why a vote is refused when its thread could not start.
    /// </summary>
    public const string NotStarted = "NotStarted";

    /// <summary>
    /// How long the counts a vote answered stand for the website's list, which follows within a minute.
    /// </summary>
    private static readonly TimeSpan ListFollows = TimeSpan.FromMinutes(1);

    /// <summary>
    /// Keeps the votes to one thread at a time.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The upvotes each vote answered and when, by the mod's slug.
    /// </summary>
    private readonly Dictionary<string, (int Up, DateTime At)> _counts = new(StringComparer.Ordinal);

    /// <summary>
    /// The mods whose vote is on its way.
    /// </summary>
    private readonly HashSet<string> _voting = new(StringComparer.Ordinal);

    /// <summary>
    /// The votes that ended since the scripts were last told.
    /// </summary>
    private readonly List<VoteEnded> _ended = [];

    /// <summary>
    /// This install's own votes by the mod's slug, as last fetched or cast; <see langword="null"/> before they were read from the cache.
    /// </summary>
    private Dictionary<string, string>? _votes;

    /// <summary>
    /// Gets the votes of the game session, cast on the website.
    /// </summary>
    public static ModRatings Live { get; } = new(SiteVotes.FetchVotes, SiteVotes.Vote, SiteVotes.Forget, work => Threads.TryStart("mods vote", work));

    /// <summary>
    /// Asks the website to forget a key the player turned off, then fetches this install's own votes
    /// into the cache, as the fetch of the lists does; a key not made yet fetches nothing.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    public void Refresh(string gameFolder)
    {
        ForgetTurnedOff(gameFolder);

        try
        {
            if (InstallKey.Current(gameFolder) is not { } key)
            {
                return;
            }

            ModCache.StoreVotes(gameFolder, fetchVotes(key));

            lock (_gate)
            {
                _votes = null;
            }
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so whatever went wrong only keeps the votes kept before.
            Log.Write($"could not fetch this install's votes: {ex.Message}");
        }
    }

    /// <summary>
    /// Tells this install's own vote on a mod.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <returns><see cref="SiteVotes.Up"/>; <see langword="null"/> for none.</returns>
    public string? VoteOf(string gameFolder, string slug)
    {
        lock (_gate)
        {
            return Votes(gameFolder).GetValueOrDefault(slug);
        }
    }

    /// <summary>
    /// Tells a mod's upvotes: those a vote answered while the website's list has not followed yet,
    /// else the list's.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="listed">The upvotes the list names.</param>
    /// <param name="listKept">When the cache last kept the website's list.</param>
    /// <returns>The upvotes.</returns>
    public int UpvotesOf(string slug, int listed, DateTime listKept)
    {
        lock (_gate)
        {
            if (_counts.TryGetValue(slug, out var counted) && listKept < counted.At + ListFollows)
            {
                return counted.Up;
            }

            _counts.Remove(slug);
            return listed;
        }
    }

    /// <summary>
    /// Tells whether this install may vote on a mod, before the website is asked.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <returns>Why not, <see cref="RatingsOff"/> or <see cref="NotDownloaded"/>; <see langword="null"/> when it may.</returns>
    public static string? Refusal(string gameFolder, string slug) =>
        !InstallKey.RatingsOn(gameFolder) ? RatingsOff : InstallKey.Downloaded(gameFolder).Contains(slug) ? null : NotDownloaded;

    /// <summary>
    /// Starts upvoting a mod or taking this install's upvote back; <see cref="TakeEnded"/> tells how
    /// it ended.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="cast"><see cref="SiteVotes.Up"/>; <see langword="null"/> takes the upvote back.</param>
    /// <returns>Why it did not start, see <see cref="Refusal"/>, <see cref="Voting"/> and <see cref="NotStarted"/>; <see langword="null"/> when it started.</returns>
    public string? Start(string gameFolder, string slug, string? cast)
    {
        if (Refusal(gameFolder, slug) is { } why)
        {
            return why;
        }

        lock (_gate)
        {
            if (!_voting.Add(slug))
            {
                return Voting;
            }
        }

        var started = false;

        try
        {
            started = start(() => Run(gameFolder, slug, cast));
        }
        finally
        {
            if (!started)
            {
                lock (_gate)
                {
                    _voting.Remove(slug);
                }
            }
        }

        return started ? null : NotStarted;
    }

    /// <summary>
    /// Hands out the votes that ended since the last call.
    /// </summary>
    /// <returns>Each vote's mod, the vote now and why it failed.</returns>
    public IReadOnlyList<VoteEnded> TakeEnded()
    {
        lock (_gate)
        {
            var ended = _ended.ToArray();
            _ended.Clear();
            return ended;
        }
    }

    /// <summary>
    /// Turns the player's ratings on or off; off forgets the votes kept and asks the website, on a
    /// thread, to forget the key.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="on">Whether the player rates mods.</param>
    /// <returns>Whether the change is kept.</returns>
    public bool Turn(string gameFolder, bool on)
    {
        if (on == InstallKey.RatingsOn(gameFolder))
        {
            return true;
        }

        var kept = InstallKey.Turn(gameFolder, on);
        Log.Write($"the player turned the ratings {(on ? "on" : "off")}{(kept ? string.Empty : ", which Install.ini could not keep")}");

        if (!on && kept)
        {
            lock (_gate)
            {
                _votes = new Dictionary<string, string>(StringComparer.Ordinal);
                _counts.Clear();
            }

            ModCache.StoreVotes(gameFolder, VotesBody(new Dictionary<string, string>()));
            start(() => ForgetTurnedOff(gameFolder));
        }

        return kept;
    }

    /// <summary>
    /// Asks the website to forget the key the player turned off, keeping it to ask again the next
    /// time while the website cannot be reached.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    private void ForgetTurnedOff(string gameFolder)
    {
        try
        {
            if (InstallKey.ToForget(gameFolder) is not { } old)
            {
                return;
            }

            forget(old);
            InstallKey.Forgotten(gameFolder);
            Log.Write("the website forgot this install's old key and its votes");
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so the key stays to be forgotten the next time.
            Log.Write($"the website could not forget this install's old key yet: {ex.Message}");
        }
    }

    /// <summary>
    /// Casts a vote and notes how it ended.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="cast">The vote, <see langword="null"/> to take it back.</param>
    private void Run(string gameFolder, string slug, string? cast)
    {
        VoteAnswer? answer = null;
        string? error = null;

        try
        {
            answer = vote(slug, cast, InstallKey.Bearer(gameFolder) ?? throw new SiteVoteException(RatingsOff));
            Log.Write($"voted {cast ?? "nothing"} on {slug}: {answer.Up} upvotes");
        }
        catch (SiteVoteException ex)
        {
            error = ex.Error;
        }
        catch (Exception ex)
        {
            // A thread's exception would end the game, so whatever went wrong only fails the vote.
            Log.Write($"the vote on {slug} failed: {ex.GetBaseException().Message}");
            error = ex.GetType().Name;
        }

        try
        {
            if (error == NotDownloaded)
            {
                InstallKey.ForgetDownloaded(gameFolder, slug);
            }

            if (answer != null)
            {
                lock (_gate)
                {
                    _counts[slug] = (answer.Up, DateTime.UtcNow);
                    var votes = Votes(gameFolder);

                    if (answer.Vote == null)
                    {
                        votes.Remove(slug);
                    }
                    else
                    {
                        votes[slug] = answer.Vote;
                    }

                    ModCache.StoreVotes(gameFolder, VotesBody(votes));
                }
            }
        }
        catch (Exception ex)
        {
            Log.Write($"could not keep the vote on {slug}: {ex.GetType().Name}: {ex.Message}");
        }
        finally
        {
            lock (_gate)
            {
                _voting.Remove(slug);
                _ended.Add(new VoteEnded(slug, answer?.Vote, error));
            }
        }
    }

    /// <summary>
    /// Reads this install's own votes from the cache the first time they are needed.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <returns>The votes by the mod's slug.</returns>
    private Dictionary<string, string> Votes(string gameFolder) =>
        _votes ??= ModCache.LoadVotes(gameFolder) ?? new Dictionary<string, string>(StringComparer.Ordinal);

    /// <summary>
    /// Writes votes as <c>GET /api/votes</c> answers them, for the cache.
    /// </summary>
    /// <param name="votes">The votes by the mod's slug.</param>
    /// <returns>The JSON.</returns>
    private static byte[] VotesBody(IReadOnlyDictionary<string, string> votes)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            writer.WriteStartArray("votes");

            foreach (var (slug, cast) in votes)
            {
                writer.WriteStartObject();
                writer.WriteString("slug", slug);
                writer.WriteString("vote", cast);
                writer.WriteEndObject();
            }

            writer.WriteEndArray();
            writer.WriteEndObject();
        }

        return stream.ToArray();
    }
}

/// <summary>
/// A vote that ended.
/// </summary>
/// <param name="Slug">The mod's slug.</param>
/// <param name="Vote">This install's vote now; <see langword="null"/> for none or when it failed.</param>
/// <param name="Error">Why it failed, such as <c>RateLimited</c>; <see langword="null"/> when it was counted.</param>
internal sealed record VoteEnded(string Slug, string? Vote, string? Error);
