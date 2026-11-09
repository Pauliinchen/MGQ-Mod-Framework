//----------------------------------------------------------------
//  UiHostTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Checked the inputs, the order and the buttons of a tick in one flow test
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Checked that the host keeps the tick's buttons for its models
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the frame's tick: each model gets its own input in the order put, with the buttons' bits
/// the host keeps for them, and a tick naming a model this build lacks is refused.
/// </summary>
public sealed class UiHostTests
{
    /// <summary>
    /// Asserts that a tick hands each model the input put under its name, in the order put, with
    /// the tick's buttons kept before the models run and through a tick that names none, and that
    /// the models' events come out of the frame's drain.
    /// </summary>
    [Fact]
    public void Tick_HandsEachModelItsInputInOrderWithTheButtons()
    {
        var ui = new UiContext();
        var host = new UiHost(ui.Context);
        var order = new List<string>();
        host.Add(new Recorder("first", order, host));
        host.Add(new Recorder("second", order, host));
        int confirm = 1 << (int)UiButton.Confirm;

        List<(string Topic, RubyValue Payload)> events = ui.Tick(new RubyHash { { "second", 2 }, { "first", 1 }, { UiHost.ButtonsKey, confirm } });
        ui.Tick(new RubyHash { { "first", 3 } });

        Assert.Equal(["second 2 True", "first 1 True", "first 3 True"], order);
        Assert.Equal([("ui.second", (RubyValue)2), ("ui.first", (RubyValue)1)], events);
    }

    /// <summary>
    /// Asserts that a tick naming a model this build lacks is refused before any model moves.
    /// </summary>
    [Fact]
    public void Tick_RefusesAnUnknownModelBeforeAnyMoves()
    {
        var ui = new UiContext();
        var host = new UiHost(ui.Context);
        var order = new List<string>();
        host.Add(new Recorder("first", order, host));

        RubyHash? answer = ui.Call(UiHost.TickTopic, new RubyHash { { "first", 1 }, { "nothing", 2 } });

        Assert.Equal(BridgeEnvelope.BadRequest, answer!["error"].AsText());
        Assert.Empty(order);
    }

    /// <summary>
    /// A model that notes its input and whether confirm went down, and posts the input back.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="order">Where it notes what it got.</param>
    /// <param name="host">The host it posts on and reads the buttons from.</param>
    private sealed class Recorder(string name, List<string> order, UiHost host) : IUiModel
    {
        /// <inheritdoc />
        public string Name => name;

        /// <inheritdoc />
        public void Tick(RubyValue input)
        {
            order.Add($"{name} {input} {host.Buttons.Triggered(UiButton.Confirm)}");
            host.Post($"ui.{name}", input);
        }
    }
}
