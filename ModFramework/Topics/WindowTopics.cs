//----------------------------------------------------------------
//  WindowTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the game's window.
/// </summary>
internal static class WindowTopics
{
    /// <summary>
    /// The topic that keeps the game running while another application is active (true) or lets it
    /// pause there again (false), answering whether it keeps running now.
    /// </summary>
    public const string KeepRunningTopic = "window.keep_running";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context) =>
        context.Register(KeepRunningTopic, (_, request) => GameWindow.KeepRunning(request.AsBool()));
}
