//----------------------------------------------------------------
//  BridgeContextTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Built the requests of the unknown topic and the batches in the tests instead of reading fixtures
//                            - Moved into the framework's project
//                            - Took a file as the example of a request
//      Paulinchen  2026-11-04: Checked the replies and errors of a call and the batches in one flow each
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Covered the batch topic and checked the unknown topic against its contract fixture
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Tests.Bridge;

/// <summary>
/// Covers the dispatcher: replies in their envelope, the errors it answers, the batch topic, and
/// replies parked when they do not fit the caller's buffer.
/// </summary>
public sealed class BridgeContextTests
{
    /// <summary>
    /// The log the context under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The context under test, with an "echo" topic that answers its request.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// Creates the context under test.
    /// </summary>
    public BridgeContextTests()
    {
        _context = new BridgeContext(1, _log);
        _context.Register("echo", (_, request) => request);
    }

    /// <summary>
    /// Asserts that a handler's value comes back in the envelope and the call is counted, that nil
    /// writes no reply, that a topic nobody registered answers unknown_topic, that a request that cannot cross and a handler naming what its request lacks answer
    /// bad_request, and that a handler that throws answers internal, logged once and counted each time.
    /// </summary>
    [Fact]
    public void Call_AnswersTheValueOrTheError()
    {
        _context.Register("file", (_, request) => request.AsHash()["file"].IsNil ? throw new BridgeRequestException("The file is missing.") : null);
        _context.Register("broken", (_, _) => throw new InvalidOperationException("The model is gone."));
        var request = new RubyHash { { "file", 2 } };
        byte[] dump = RubyMarshal.Write(request);

        RubyHash reply = Call("echo", dump);

        Assert.Equal(BridgeEnvelope.Ok(request), reply);
        Assert.Equal((1, dump.Length, RubyMarshal.Write(reply).Length), (_context.Counters["echo"].Calls, _context.Counters["echo"].BytesIn, _context.Counters["echo"].BytesOut));
        Assert.Empty(CallRaw("file", dump));

        // Ruby's dump of RPG::Item.new(1, "Herb").
        byte[] item = Convert.FromHexString("04086f3a0e5250473a3a4974656d073a0840696469063a0a406e616d6549220948657262063a064554");

        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.UnknownTopic, "There is no topic no.such.topic."), Call("no.such.topic", dump));
        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "RPG::Item cannot cross the bridge."), Call("echo", item));
        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "The file is missing."), Call("file", RubyMarshal.Write(new RubyHash())));

        RubyHash broken = Call("broken", []);
        Call("broken", []);

        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.Internal, "The model is gone."), broken);
        Assert.Single(_log.Lines, line => line.StartsWith("Bridge topic broken answered internal", StringComparison.Ordinal));
        Assert.Equal(2, _context.Counters["broken"].Errors);
    }

    /// <summary>
    /// Asserts that a batch runs its entries in order and, when all ran, answers nothing, that it
    /// runs the entries after one that failed and answers the failed ones, and that a batch with an entry that is no pair runs none of its entries.
    /// </summary>
    [Fact]
    public void Batch_RunsTheEntriesInOrderAndAnswersTheFailedOnes()
    {
        List<string> appended = [];
        _context.Register("test.append", (_, request) =>
        {
            appended.Add(request.AsText());
            return null;
        });

        var inOrder = new RubyArray { new RubyArray { "test.append", "a" }, new RubyArray { "test.append", "b" }, new RubyArray { "test.append", "c" } };
        var failing = new RubyArray
        {
            new RubyArray { "test.append", "a" },
            new RubyArray { "no.such.topic", RubyNil.Value },
            new RubyArray { "test.append", 1 },
            new RubyArray { "test.append", "d" },
        };

        Assert.Empty(CallRaw(BridgeContext.BatchTopic, RubyMarshal.Write(inOrder)));
        Assert.Equal(["a", "b", "c"], appended);
        Assert.Equal(3, _context.Counters["test.append"].Calls);

        appended.Clear();
        Assert.Equal(
            BridgeEnvelope.Ok(new RubyArray
            {
                new RubyHash { { "topic", "no.such.topic" }, { "error", BridgeEnvelope.UnknownTopic }, { "text", "There is no topic no.such.topic." } },
                new RubyHash { { "topic", "test.append" }, { "error", BridgeEnvelope.BadRequest }, { "text", "Expected a String, found an Integer." } },
            }),
            Call(BridgeContext.BatchTopic, RubyMarshal.Write(failing)));
        Assert.Equal(["a", "d"], appended);

        appended.Clear();
        var broken = new RubyArray { new RubyArray { "test.append", "a" }, "test.append" };
        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "Expected an Array, found a String."), Call(BridgeContext.BatchTopic, RubyMarshal.Write(broken)));
        Assert.Empty(appended);
    }

    /// <summary>
    /// Asserts that a reply too large for the buffer is parked, handed out once a large enough buffer
    /// comes, and that its handler ran once.
    /// </summary>
    [Fact]
    public void Call_ParksAReplyThatDoesNotFitAndRunsTheHandlerOnce()
    {
        int runs = 0;
        _context.Register("big", (_, _) =>
        {
            runs++;
            return new string('x', 1000);
        });

        int needed = -_context.Call("big"u8, [], new byte[16]);
        int stillParked = _context.TakeReply(new byte[16]);
        byte[] buffer = new byte[needed];
        int written = _context.TakeReply(buffer);

        Assert.True(needed > 1000);
        Assert.Equal(-needed, stillParked);
        Assert.Equal(needed, written);
        Assert.Equal(new string('x', 1000), RubyMarshal.Read(buffer).AsHash()["value"].AsText());
        Assert.Equal(0, _context.TakeReply(buffer));
        Assert.Equal(1, runs);
    }

    /// <summary>
    /// Calls a topic with a large buffer.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <returns>The reply.</returns>
    private RubyHash Call(string topic, byte[] request)
    {
        byte[] reply = CallRaw(topic, request);
        Assert.True(reply.Length > 0, $"{topic} wrote no reply");
        return RubyMarshal.Read(reply).AsHash();
    }

    /// <summary>
    /// Calls a topic with a large buffer and keeps the reply's bytes.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <returns>The reply's bytes, none for no reply.</returns>
    private byte[] CallRaw(string topic, byte[] request)
    {
        byte[] buffer = new byte[4096];
        int written = _context.Call(System.Text.Encoding.UTF8.GetBytes(topic), request, buffer);
        Assert.True(written >= 0, $"{topic} parked its reply ({written})");
        return buffer[..written];
    }
}
