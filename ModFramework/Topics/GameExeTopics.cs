//----------------------------------------------------------------
//  GameExeTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Logged a thread that cannot start
//                            - Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the game's own program.
/// </summary>
internal static class GameExeTopics
{
    /// <summary>
    /// The topic the scripts call once as the game starts, which lets the game's program use up to
    /// 4 GB from its next start on a thread, see <see cref="GameExe"/>; answers nil at once, and the
    /// log tells how it ended.
    /// </summary>
    public const string LargeAddressTopic = "game_exe.large_address";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context) =>
        context.Register(LargeAddressTopic, (_, _) =>
        {
            var gameFolder = ModFolder.GameRoot;
            Threads.TryStart("game exe", () => GameExe.AtBoot(gameFolder));
            return RubyNil.Value;
        });
}
