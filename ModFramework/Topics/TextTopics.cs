//----------------------------------------------------------------
//  TextTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Added the topic that finds a part in a text
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics that match a typed text against words and find a part in a text, by TextMatch's rule.
/// </summary>
internal static class TextTopics
{
    /// <summary>
    /// The topic that narrows words to a typed text: [typed, [words]] answers the words that match.
    /// </summary>
    public const string MatchTopic = "text.match";

    /// <summary>
    /// The topic that finds a part in a text: [text, part] answers [[start, length], ...].
    /// </summary>
    public const string FindTopic = "text.find";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(MatchTopic, (_, request) =>
        {
            RubyArray values = request.AsArray();
            return new RubyArray(TextMatch.Matches(values[0].AsText(), values[1].AsArray().Select(word => word.AsText())).Select(word => (RubyValue)word));
        });
        context.Register(FindTopic, (_, request) =>
        {
            RubyArray values = request.AsArray();
            return new RubyArray(TextMatch.Places(values[0].AsText(), values[1].AsText()).Select(place => (RubyValue)new RubyArray { place.Start, place.Length }));
        });
    }
}
