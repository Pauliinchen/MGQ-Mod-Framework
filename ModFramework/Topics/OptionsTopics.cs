//----------------------------------------------------------------
//  OptionsTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Told the scripts which cancel keys leave a text field
//                            - Judged a key by the keys F1 binds now, as the press of a hotkey does
//      Paulinchen  2026-11-05: Judged a key by the keys F1 binds until the player changes them, the framework's keys refused
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Options;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics of the rows of Options > Mods: their groups, and the keys their key rows take.
/// </summary>
internal static class OptionsTopics
{
    /// <summary>
    /// The topic that sorts rows by mod: [names] answers [[group, [[place, name], ...]], ...], see
    /// <see cref="OptionGroups.Group"/>.
    /// </summary>
    public const string GroupsTopic = "options.groups";

    /// <summary>
    /// The topic that names keys: [codes] answers [names], see <see cref="KeyNames.Name"/>.
    /// </summary>
    public const string NamesTopic = "keys.names";

    /// <summary>
    /// The topic that answers the codes of the keys a key row takes, see <see cref="KeyNames.Bindable"/>.
    /// </summary>
    public const string BindableTopic = "keys.bindable";

    /// <summary>
    /// The topic that judges a key pressed for a waiting key row or kept for a hotkey, by the keys
    /// F1 binds now: code answers "ignored", "keep", "game", "framework" or "bind", see
    /// <see cref="KeyNames.Judge"/>.
    /// </summary>
    public const string JudgeTopic = "keys.judge";

    /// <summary>
    /// The topic that tells which cancel keys leave a text field that types: [takes, [codes]], takes
    /// the characters it types as a text field's "takes" names them or nil for every character,
    /// answers the codes that leave it, see <see cref="KeyNames.LeavesField"/>.
    /// </summary>
    public const string LeaveFieldTopic = "keys.leave_field";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="assignment">Reads the keys F1 binds now, the same the tree's key handling reads.</param>
    public static void Register(BridgeContext context, Func<ButtonAssignment> assignment)
    {
        context.Register(GroupsTopic, (_, request) => Groups(request.AsArray()));
        context.Register(NamesTopic, (_, request) => Names(request.AsArray()));
        context.Register(BindableTopic, (_, _) => Bindable());
        context.Register(JudgeTopic, (_, request) => KeyNames.Judge(request.AsInt(), assignment()).ToString().ToLowerInvariant());
        context.Register(LeaveFieldTopic, (_, request) => LeavingKeys(request.AsArray()));
    }

    /// <summary>
    /// Picks the cancel keys that leave a text field that types.
    /// </summary>
    /// <param name="request">The characters it types, nil for every character, and the keys.</param>
    /// <returns>The keys that leave it.</returns>
    internal static RubyValue LeavingKeys(RubyArray request)
    {
        string? takes = request[0].IsNil ? null : request[0].AsText();
        return new RubyArray(request[1].AsArray().Where(code => KeyNames.LeavesField(takes, code.AsInt())));
    }

    /// <summary>
    /// Sorts rows by mod.
    /// </summary>
    /// <param name="request">The rows' names.</param>
    /// <returns>The groups, each with its rows' places and names.</returns>
    internal static RubyValue Groups(RubyArray request)
    {
        var names = new List<string>();
        foreach (RubyValue name in request)
        {
            names.Add(name.AsText());
        }

        var reply = new RubyArray();
        foreach ((string group, List<(int Place, string Name)> rows) in OptionGroups.Group(names))
        {
            var entries = new RubyArray();
            foreach ((int place, string name) in rows)
            {
                entries.Add(new RubyArray { place, name });
            }

            reply.Add(new RubyArray { group, entries });
        }

        return reply;
    }

    /// <summary>
    /// Names keys.
    /// </summary>
    /// <param name="request">Windows' codes of the keys.</param>
    /// <returns>Their names in the same order.</returns>
    internal static RubyValue Names(RubyArray request)
    {
        var reply = new RubyArray();
        foreach (RubyValue code in request)
        {
            reply.Add(KeyNames.Name(code.AsInt()));
        }

        return reply;
    }

    /// <summary>
    /// Lists the keys a key row takes.
    /// </summary>
    /// <returns>Their codes.</returns>
    private static RubyValue Bindable()
    {
        var reply = new RubyArray();
        foreach (int code in KeyNames.Bindable)
        {
            reply.Add(code);
        }

        return reply;
    }
}
