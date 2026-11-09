//----------------------------------------------------------------
//  ClipboardTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics that copy text to the Windows clipboard and paste it from there.
/// </summary>
internal static class ClipboardTopics
{
    /// <summary>
    /// The topic that answers the clipboard's text, empty when it holds none.
    /// </summary>
    public const string GetTopic = "clipboard.get";

    /// <summary>
    /// The topic that puts a String on the clipboard, answering whether it holds it.
    /// </summary>
    public const string SetTopic = "clipboard.set";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(GetTopic, (_, _) => Clipboard.GetText() ?? string.Empty);
        context.Register(SetTopic, (_, request) => Clipboard.SetText(GameWindowFinder.Find(), request.AsText()));
    }
}
