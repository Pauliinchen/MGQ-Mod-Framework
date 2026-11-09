//----------------------------------------------------------------
//  DeviceInputTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the devices the input model reads: Windows' keyboard and mouse wheel, the guard that
/// keeps Alt from opening the window's menu while typing, and the input JoiPlay's scripts hand
/// over each tick.
/// </summary>
public sealed class DeviceInputTests
{
    /// <summary>
    /// Asserts that what is typed while typing is on comes out with the next take once, and that
    /// stopping the typing forgets what nobody took.
    /// </summary>
    [Fact]
    public void Keyboard_HandsWhatWasTypedOutOnce()
    {
        Keyboard.SetActive(true);
        Keyboard.TakeCharacter('a');
        Keyboard.TakeCharacter('b');
        var first = Keyboard.Take();
        var second = Keyboard.Take();
        Keyboard.TakeCharacter('c');
        Keyboard.SetActive(false);

        Assert.Equal(("ab", 0), first);
        Assert.Equal((string.Empty, 0), second);
        Assert.Equal((string.Empty, 0), Keyboard.Take());
    }

    /// <summary>
    /// Asserts that the notches turned either way add up, a take hands them out once, and parts of
    /// a notch, as a wheel without notches turns, wait until they make a whole one.
    /// </summary>
    [Fact]
    public void MouseWheel_HandsOutWholeNotchesOnce()
    {
        var wheel = new MouseWheel();

        wheel.Turn(MouseWheel.Notch);
        wheel.Turn(MouseWheel.Notch);
        wheel.Turn(-MouseWheel.Notch);
        Assert.Equal(1, wheel.Take());
        Assert.Equal(0, wheel.Take());

        wheel.Turn(MouseWheel.Notch / 2);
        Assert.Equal(0, wheel.Take());
        wheel.Turn(MouseWheel.Notch / 2 + 10);
        Assert.Equal(1, wheel.Take());
        wheel.Turn(-MouseWheel.Notch - 10);
        Assert.Equal(-1, wheel.Take());
    }

    /// <summary>
    /// Asserts that Alt pressed alone never opens the window's menu, that Alt with a letter opens it
    /// only while nothing types, and that an Alt press that began while typing keeps it closed once
    /// as it is released after the typing ended, even through its repeats.
    /// </summary>
    [Fact]
    public void AltMenu_StaysClosedWhileTyping()
    {
        const uint alt = 0x12;
        const nint repeat = 1 << 30;
        const nint alone = 0;
        const nint letter = 'f';
        var guard = new AltMenuGuard();

        Assert.True(guard.SwallowsKeyMenu(false, alone));
        Assert.True(guard.SwallowsKeyMenu(true, alone));
        Assert.True(guard.SwallowsKeyMenu(true, letter));
        Assert.False(guard.SwallowsKeyMenu(false, letter));

        guard.SystemKeyDown(true, alt, 0);
        guard.SystemKeyDown(false, alt, repeat);
        Assert.True(guard.SwallowsKeyMenu(false, letter));
        Assert.False(guard.SwallowsKeyMenu(false, letter));

        guard.SystemKeyDown(false, alt, 0);
        Assert.False(guard.SwallowsKeyMenu(false, letter));
    }

    /// <summary>
    /// Asserts that JoiPlay's pointer and keys are those of the last tick, kept through a tick
    /// without devices, that its wheel adds up until taken, and that typing comes out once with its
    /// count of characters only while a box takes it.
    /// </summary>
    [Fact]
    public void ScriptInput_TakesTheDevicesOfTheTick()
    {
        var input = new ScriptInput();

        input.Read(Tick(new RubyArray { 120, 80, 640, 480 }, [0x01, 0x41], 1, "early"));
        input.Read(Tick(new RubyArray { 130, 90, 640, 480 }, [0x41], 1));
        input.Read([]);
        Assert.Equal(new ClientPointer(130, 90, 640, 480), input.Pointer());
        Assert.Equal([false, true, false], new[] { input.KeyDown(0x01), input.KeyDown(0x41), input.KeyDown(0x42) });
        Assert.Equal(2, input.TakeWheel());
        Assert.Equal(0, input.TakeWheel());

        input.SetActive(true);
        input.Read(Tick(RubyNil.Value, [], 0, "hé"));
        input.Read(Tick(RubyNil.Value, [], 0, "\b"));
        Assert.Equal(("hé\b", 3), input.Take());
        Assert.Equal((string.Empty, 0), input.Take());
    }

    /// <summary>
    /// Builds the input model's part of a tick with JoiPlay's devices.
    /// </summary>
    /// <param name="mouse">The pointer, nil for none.</param>
    /// <param name="keys">The codes held.</param>
    /// <param name="wheel">The notches.</param>
    /// <param name="typed">What was typed, null for nothing.</param>
    /// <returns>The part.</returns>
    private static RubyHash Tick(RubyValue mouse, int[] keys, int wheel, string? typed = null)
    {
        var held = new RubyArray();
        foreach (int key in keys)
        {
            held.Add(key);
        }

        var device = new RubyHash { { "mouse", mouse }, { "keys", held }, { "wheel", wheel } };
        if (typed is not null)
        {
            device.Add("typed", typed);
        }

        return new RubyHash { { ScriptInput.DeviceKey, device } };
    }
}
