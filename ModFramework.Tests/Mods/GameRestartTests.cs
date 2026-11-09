//----------------------------------------------------------------
//  GameRestartTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Started the game again without the helper
//                            - Dropped the update through the helper
//                            - Read the helper lines in the framework log
//                            - Took a mod of no name as the example of an action
//      Paulinchen  2026-11-04: Checked the refusals in one flow and left the arguments of the update to the helper's tests
//      Paulinchen  2026-10-30: Covered the mods named to the helper's update
//                            - Covered the action carried after the restart
//                            - Moved into the Mod Framework
//                            - Named the game folder to the helper and dropped the parked mods' watchdog
//      Paulinchen  2026-10-23: Covered the arguments the helper gets and the helper's restart in place of the Wine refusals
//                            - Made the parking without the deleted options dump check
//      Paulinchen  2026-10-22: Covered the release passed to the updater
//      Paulinchen  2026-10-09: Covered when the parked mods' watchdog does not start
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Threading;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the start of the game again: refused without its program or with a bad action, and the
/// game's program started with the action in its environment.
/// </summary>
public sealed class GameRestartTests : IDisposable
{
    /// <summary>
    /// A game folder of the test's own, which holds no Game.exe at first.
    /// </summary>
    private readonly string _game = Directory.CreateTempSubdirectory("mgqmf-restart-").FullName;

    /// <summary>
    /// The game's program in <see cref="_game"/>.
    /// </summary>
    private string GameExe => Path.Combine(_game, "Game.exe");

    /// <summary>
    /// Asserts that nothing starts without Game.exe or from a file that is no program and that no
    /// action stays behind then, and that an action is written as its name and value while a bad
    /// name, a value without a name and a value too long are refused.
    /// </summary>
    [Fact]
    public void Restart_IsRefusedWithoutItsProgramOrWithABadAction()
    {
        Assert.False(GameRestart.StartAgain(GameExe, null));

        File.WriteAllText(GameExe, string.Empty);
        Environment.SetEnvironmentVariable(GameRestart.ActionVariable, "old");
        Assert.False(GameRestart.StartAgain(GameExe, "load:3"));
        Assert.Null(Environment.GetEnvironmentVariable(GameRestart.ActionVariable));

        Assert.Null(GameRestart.ActionText("load", "01", out var load));
        Assert.Equal("load:01", load);
        Assert.Null(GameRestart.ActionText("camp-notes.open", null, out var plain));
        Assert.Equal("camp-notes.open", plain);
        Assert.NotNull(GameRestart.ActionText("_load", null, out _));
        Assert.NotNull(GameRestart.ActionText(null, "3", out _));
        Assert.NotNull(GameRestart.ActionText("load", new string('9', GameRestart.MaxActionValue + 1), out var tooLong));
        Assert.Null(tooLong);
    }

    /// <summary>
    /// Asserts that the restart starts the game's program and leaves the action in the environment
    /// it hands the program.
    /// </summary>
    [Fact]
    public void Restart_StartsTheGameWithTheAction()
    {
        // ping stands in for the game: without arguments it ends at once.
        File.Copy(Path.Combine(Environment.SystemDirectory, "PING.EXE"), GameExe);

        Assert.True(GameRestart.StartAgain(GameExe, "load:3"));
        Assert.Equal("load:3", Environment.GetEnvironmentVariable(GameRestart.ActionVariable));
        Environment.SetEnvironmentVariable(GameRestart.ActionVariable, null);
    }

    /// <inheritdoc />
    public void Dispose()
    {
        // The program the restart started may still be on its way out.
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                Directory.Delete(_game, true);
                return;
            }
            catch (UnauthorizedAccessException) when (attempt < 50)
            {
                Thread.Sleep(100);
            }
        }
    }
}
