//----------------------------------------------------------------
//  BridgeHostTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-11-04: Checked the refused, the first and the second handshake in one flow
//                            - Covered a call on the closed context, moved over from the exports tests
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Covered a second handshake closing the older context
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Tests.Bridge;

/// <summary>
/// Covers the handshake and the routing of calls to a context by its id.
/// </summary>
public sealed class BridgeHostTests
{
    /// <summary>
    /// The log the host under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The host under test, whose contexts have a "ping" topic.
    /// </summary>
    private readonly BridgeHost _host;

    /// <summary>
    /// Creates the host under test.
    /// </summary>
    public BridgeHostTests()
    {
        _host = new BridgeHost("0.6.9", _log, context => context.Register("ping", (_, _) => "pong"));
    }

    /// <summary>
    /// Asserts that a handshake of another version is refused and opens no context, that the
    /// handshake opens a context named by its id which then answers calls, and that a second
    /// handshake, as F12 makes the scripts send, closes the older context and refuses calls on it.
    /// </summary>
    [Fact]
    public void Open_OpensTheContextThatAnswersAndClosesTheOlderOnes()
    {
        RubyHash refused = Open(BridgeHost.Version + 1);

        Assert.Equal(BridgeEnvelope.BadRequest, refused["error"].AsText());
        Assert.Contains("bridge version 2", refused["text"].AsText(), StringComparison.Ordinal);
        Assert.Null(_host.Find(1));

        RubyHash value = Open(BridgeHost.Version)["value"].AsHash();
        int older = value["context"].AsInt();
        byte[] buffer = new byte[256];
        int written = _host.Call(older, "ping"u8, [], buffer);

        Assert.Equal(BridgeHost.Version, value["bridge"].AsInt());
        Assert.Equal("0.6.9", value["build"].AsText());
        Assert.Equal(new[] { BridgeContext.BatchTopic, "ping" }, value["topics"].AsArray().Select(topic => topic.AsText()));
        Assert.Equal("pong", RubyMarshal.Read(buffer.AsSpan(0, written)).AsHash()["value"].AsText());

        int newer = Open(BridgeHost.Version)["value"].AsHash()["context"].AsInt();
        written = _host.Call(older, "ping"u8, [], buffer);

        Assert.Null(_host.Find(older));
        Assert.NotNull(_host.Find(newer));
        Assert.Contains($"Bridge closed context {older}.", _log.Lines);
        Assert.Equal(BridgeEnvelope.BadRequest, RubyMarshal.Read(buffer.AsSpan(0, written)).AsHash()["error"].AsText());
    }

    /// <summary>
    /// Runs the handshake with a large buffer.
    /// </summary>
    /// <param name="version">The version the scripts speak.</param>
    /// <returns>The reply.</returns>
    private RubyHash Open(int version)
    {
        byte[] buffer = new byte[1024];
        int written = _host.Open(version, buffer);
        return RubyMarshal.Read(buffer.AsSpan(0, written)).AsHash();
    }
}
