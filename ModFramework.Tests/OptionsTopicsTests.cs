//----------------------------------------------------------------
//  OptionsTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Judged confirm's Enter as one of the framework's own keys
//                            - Covered the cancel keys that leave a field of digits and one of letters
//                            - Judged V as the framework's once F1 binds it to cancel
//      Paulinchen  2026-11-05: Checked that Insert keeps the old key and Tab is refused as the framework's
//      Paulinchen  2026-11-04: Called the topics through the bridge in one flow of the Mod Config rows
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Options;
using MGQParadox.ModFramework.Topics;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the topics of the rows of Options > Mods as the scripts call them: their groups by mod,
/// the keys a key row takes and their names, and what a key pressed for a key row does.
/// </summary>
public sealed class OptionsTopicsTests
{
    /// <summary>
    /// Windows' code of V, which F1 binds to no button until the player does.
    /// </summary>
    private const int KeyV = 0x56;

    /// <summary>
    /// Asserts that rows group by the mod their names start with, an indented row joining the group
    /// above it, a row of no mod going to Global first and a group named again adding to its rows;
    /// that a key row takes the free keys and the game's, read by their names with no key as None;
    /// and that Escape and the numpad's 0 in either Num Lock state keep the old key, the game's keys
    /// and the framework's, confirm's Enter among them, are refused, a free key binds and a mouse
    /// button is no key; that V binds until F1 binds it to cancel, from then on it keeps the old key;
    /// and that X bound to cancel leaves a field of digits but types in a field of letters, where the
    /// numpad's 0 leaves.
    /// </summary>
    [Fact]
    public void KeyRows_GroupByModAndJudgeTheKeysPressed()
    {
        var ui = new UiContext();
        ButtonAssignment assignment = ButtonAssignment.Default;
        OptionsTopics.Register(ui.Context, () => assignment);
        var names = new RubyArray { "[EXP Overlord] Settings", "     -> Base EXP", "Battle Speed", "[Level Cap] Level Cap", "[EXP Overlord] Gold" };

        Assert.Equal(
            new RubyArray
            {
                new RubyArray { "Global", new RubyArray { new RubyArray { 2, "Battle Speed" } } },
                new RubyArray { "EXP Overlord", new RubyArray { new RubyArray { 0, "Settings" }, new RubyArray { 1, "     -> Base EXP" }, new RubyArray { 4, "Gold" } } },
                new RubyArray { "Level Cap", new RubyArray { new RubyArray { 3, "Level Cap" } } },
            },
            ui.Value(OptionsTopics.GroupsTopic, names));

        var bindable = ui.Value(OptionsTopics.BindableTopic).AsArray();

        Assert.Contains((RubyValue)0x54, bindable);
        Assert.DoesNotContain((RubyValue)0x01, bindable);
        Assert.Equal(new RubyArray { "F5", "Num 0", "Left Shift", "T", "None" }, ui.Value(OptionsTopics.NamesTopic, new RubyArray { 0x74, 0x60, 0xA0, 0x54, 0 }));

        Assert.Equal(
            new RubyArray { "keep", "keep", "keep", "game", "framework", "framework", "bind", "ignored" },
            new RubyArray(new[] { KeyNames.Escape, KeyNames.NumpadZero, KeyNames.Insert, 0x74, 0x0D, 0x09, 0x54, 0x01 }.Select(code => ui.Value(OptionsTopics.JudgeTopic, code))));

        RubyValue before = ui.Value(OptionsTopics.JudgeTopic, KeyV);
        assignment = ButtonAssignment.Read(FakeInput.Bound(ButtonAssignment.PadButtons + 8, 12), out _);
        Assert.Equal(((RubyValue)"bind", (RubyValue)"keep"), (before, ui.Value(OptionsTopics.JudgeTopic, KeyV)));

        var cancels = new RubyArray { KeyNames.Escape, KeyNames.NumpadZero, 0x58 };
        Assert.Equal(
            (new RubyArray { KeyNames.Escape, 0x58 }, new RubyArray { KeyNames.Escape, KeyNames.NumpadZero }),
            (ui.Value(OptionsTopics.LeaveFieldTopic, new RubyArray { "0", cancels }), ui.Value(OptionsTopics.LeaveFieldTopic, new RubyArray { RubyNil.Value, cancels })));
    }
}
