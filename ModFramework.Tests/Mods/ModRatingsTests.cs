//----------------------------------------------------------------
//  ModRatingsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Ran the work in a start that tells whether it started
//      Paulinchen  2026-11-04: Checked the install key and the votes in one flow from the first vote to ratings turned off
//      Paulinchen  2026-11-01: Kept the upvotes a vote answered alone
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the player's votes and the install key they go with: the key made once, the mods
/// downloaded with it, the counts a vote answered, and the key forgotten once ratings turn off.
/// </summary>
public sealed class ModRatingsTests
{
    /// <summary>
    /// Asserts that the key is made once, 64 hex characters, and kept; that a mod this install did
    /// not download is refused before the website is asked; that a vote's answer stands for the
    /// list's upvotes until the list is kept a minute later and the website's NotDownloaded forgets
    /// the mod as downloaded; that turning ratings off drops the key and the downloads, has the
    /// website forget the key once it can be reached, and that turning them on makes a new key.
    /// </summary>
    [Fact]
    public void Ratings_VoteThenTurnOff_ForgetsTheKey()
    {
        using var game = new TempFolder();
        List<(string Slug, string? Vote, string Key)> cast = [];
        List<string> forgotten = [];
        var reachable = false;
        var ratings = new ModRatings(
            _ => Encoding.UTF8.GetBytes("""{"votes":[]}"""),
            (slug, vote, key) =>
            {
                cast.Add((slug, vote, key));
                return slug == "invasions" ? throw new SiteVoteException(ModRatings.NotDownloaded) : new VoteAnswer(vote, 4);
            },
            key =>
            {
                if (!reachable)
                {
                    throw new SiteVoteException(SiteVotes.Unreachable);
                }

                forgotten.Add(key);
            },
            work => { work(); return true; });
        var key = InstallKey.Bearer(game.Path)!;

        Assert.True(InstallKey.IsKey(key));
        Assert.Equal(key, InstallKey.Bearer(game.Path));
        Assert.Equal(ModRatings.NotDownloaded, ratings.Start(game.Path, "level-cap", SiteVotes.Up));
        Assert.Empty(cast);

        // Votes on two downloaded mods, one of which the website says this install never downloaded.
        InstallKey.NoteDownloaded(game.Path, "level-cap");
        InstallKey.NoteDownloaded(game.Path, "invasions");

        Assert.Null(ratings.Start(game.Path, "level-cap", SiteVotes.Up));
        Assert.Null(ratings.Start(game.Path, "invasions", SiteVotes.Up));
        Assert.Equal([new VoteEnded("level-cap", "up", null), new VoteEnded("invasions", null, ModRatings.NotDownloaded)], ratings.TakeEnded());
        Assert.Equal(("level-cap", "up", key), cast[0]);
        Assert.Equal("up", ratings.VoteOf(game.Path, "level-cap"));
        Assert.Equal(4, ratings.UpvotesOf("level-cap", 3, DateTime.UtcNow));
        Assert.Equal(3, ratings.UpvotesOf("level-cap", 3, DateTime.UtcNow.AddMinutes(2)));
        Assert.Equal(["level-cap"], InstallKey.Downloaded(game.Path));

        // Ratings off while the website cannot be reached, then a fetch once it can.
        ratings.Turn(game.Path, false);

        Assert.Null(InstallKey.Bearer(game.Path));
        Assert.Empty(InstallKey.Downloaded(game.Path));
        Assert.Equal(key, InstallKey.ToForget(game.Path));
        Assert.Empty(forgotten);

        reachable = true;
        ratings.Refresh(game.Path);

        Assert.Equal([key], forgotten);
        Assert.Null(InstallKey.ToForget(game.Path));

        ratings.Turn(game.Path, true);

        Assert.NotEqual(key, InstallKey.Bearer(game.Path));
    }
}
