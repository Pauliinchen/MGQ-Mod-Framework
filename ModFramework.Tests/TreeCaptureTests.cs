//----------------------------------------------------------------
//  TreeCaptureTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//                            - Refused confirm's Enter as one of the framework's own keys
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using static MGQParadox.ModFramework.Tests.TreeHarness;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the wait of the component tree for the key the player presses to bind a hotkey, as a
/// hotkey field and a key row of the options list wait.
/// </summary>
public sealed class TreeCaptureTests
{
    /// <summary>Windows' code of M, the key another hotkey has.</summary>
    private const int MKey = 0x4D;

    /// <summary>Windows' code of O, a free key.</summary>
    private const int OKey = 0x4F;

    /// <summary>Windows' code of P, another free key.</summary>
    private const int PKey = 0x50;

    /// <summary>Windows' code of C, which the test's F1 settings bind to the game's X button.</summary>
    private const int CKey = 0x43;

    /// <summary>Windows' code of Enter, a key the game reads itself.</summary>
    private const int EnterKey = 0x0D;

    /// <summary>Windows' code of the left Alt, which arranges the boxes.</summary>
    private const int LeftAltKey = 0xA4;

    /// <summary>Windows' code of Escape, which keeps the old key.</summary>
    private const int EscapeKey = 0x1B;

    /// <summary>Windows' code of X, which F1 binds to the game's cancel.</summary>
    private const int XKey = 0x58;

    /// <summary>Windows' code of Insert, the numpad's 0 with Num Lock off.</summary>
    private const int InsertKey = 0x2D;

    /// <summary>The place of C among the keys of F1's settings.</summary>
    private const int CPlace = ButtonAssignment.PadButtons + 7;

    /// <summary>F1's number of the game's X button.</summary>
    private const byte XButton = 14;

    /// <summary>
    /// The tree run tick by tick.
    /// </summary>
    private readonly TreeHarness _tree = new();

    /// <summary>
    /// Asserts a player binding a hotkey: the field waits with the other hotkeys' keys taken and
    /// holds every key meanwhile, so DOWN moves no focus; confirm's Enter, C that F1 binds to the
    /// game's X button, the left Alt that arranges the boxes and the key the Map hotkey has are
    /// refused with the buzzer while it waits on, the Map button staying unpressed; O and P let go
    /// together bind nothing; O binds as it is let go, with the confirm sound, and the wait ends.
    /// Then Escape, X bound to the game's cancel, Insert, the gamepad's cancel and a click outside
    /// each keep the old key.
    /// </summary>
    [Fact]
    public void Wait_BindsAFreeKeyAndRefusesTakenOnes()
    {
        _tree.Input.Assign = FakeInput.Bound(CPlace, XButton);
        RubyHash tree = Adds(
            Node(1, null, "window", ("layer", true)),
            Node(2, 1, "button", Measured(200, 24), ("acts", true)),
            Node(3, 1, "button", Measured(200, 24), ("acts", true), ("hotkey", "camp_map")));
        tree["hotkeys"] = Hotkeys(("camp_map", MKey))["hotkeys"];
        _tree.Frame(tree);
        _tree.Frame(new RubyHash { { "focus", 2 } });
        Wait();

        Assert.Empty(Events(_tree.Press(UiButton.Down)));
        RubyHash confirm = _tree.Key(EnterKey);
        Assert.Equal([$"2 refused {EnterKey} framework nil"], Events(confirm));
        Assert.Equal([UiCue.Buzzer], Cues(confirm));
        Assert.Equal([$"2 refused {CKey} game nil"], Events(_tree.Key(CKey)));
        Assert.Equal([$"2 refused {LeftAltKey} framework nil"], Events(_tree.Key(LeftAltKey)));
        Assert.Equal([$"2 refused {MKey} hotkey Map"], Events(_tree.Key(MKey)));

        _tree.Input.Down.Add(OKey);
        Assert.Empty(Events(_tree.Frame()));
        _tree.Input.Down.Add(PKey);
        _tree.Frame();
        _tree.Input.Down.Clear();
        RubyHash chord = _tree.Frame();
        Assert.Equal([$"2 refused {OKey} chord nil"], Events(chord));
        Assert.Equal([UiCue.Buzzer], Cues(chord));

        _tree.Input.Down.Add(OKey);
        Assert.Empty(Events(_tree.Frame()));
        _tree.Input.Down.Remove(OKey);
        RubyHash bound = _tree.Frame();
        Assert.Equal([$"2 captured {OKey}", "2 released"], Events(bound));
        Assert.Equal([UiCue.Ok], Cues(bound));
        Assert.Contains("3 focus", Events(_tree.Press(UiButton.Down)));

        _tree.Frame(new RubyHash { { "focus", 2 } });
        foreach (int cancel in new[] { EscapeKey, XKey, InsertKey })
        {
            Wait();
            RubyHash kept = _tree.Key(cancel);
            Assert.Equal([$"2 kept {cancel} key"], Events(kept));
            Assert.Equal([UiCue.Cancel], Cues(kept));
        }

        Wait();
        Assert.Equal(["2 kept nil pad"], Events(_tree.Frame(buttons: Triggered(UiButton.Cancel))));
        _tree.Frame();
        Wait();
        _tree.Point(300, 300);
        Assert.Equal(["2 kept nil click", "2 released"], Events(_tree.Click()).FindAll(text => !text.Contains("hover", System.StringComparison.Ordinal)));
    }

    /// <summary>
    /// Has the field wait for a key, M taken by the Map hotkey, and lets the wait start.
    /// </summary>
    private void Wait()
    {
        _tree.Frame(Set(2, "capture", new RubyHash { { MKey, "Map" } }));
        _tree.Frame();
    }
}
