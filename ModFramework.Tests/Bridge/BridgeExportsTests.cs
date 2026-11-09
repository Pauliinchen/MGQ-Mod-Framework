//----------------------------------------------------------------
//  BridgeExportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-11-04: Checked the four exports in one flow
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Tests.Bridge;

/// <summary>
/// Covers the four exports as the scripts call them, through their unmanaged entry points, over a
/// host installed for each test.
/// </summary>
/// <remarks>
/// The exports share one host per process, so every test that installs one lives in this class,
/// whose tests run one at a time.
/// </remarks>
public sealed unsafe class BridgeExportsTests
{
    /// <summary>
    /// The size of the scripts' reply buffer in these tests.
    /// </summary>
    private const int ReplySize = 4096;

    /// <summary>
    /// mf_bridge_open as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, int, int> OpenExport = &BridgeExports.Open;

    /// <summary>
    /// mf_call as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, byte*, int, byte*, int, int> CallExport = &BridgeExports.Call;

    /// <summary>
    /// mf_reply as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, int, int> ReplyExport = &BridgeExports.Reply;

    /// <summary>
    /// mf_drain as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, int, byte*, int, int> DrainExport = &BridgeExports.Drain;

    /// <summary>
    /// The log the installed host writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// How often the "big" topic ran.
    /// </summary>
    private int _bigRuns;

    /// <summary>
    /// Installs a host whose contexts have "big", which answers more than the reply buffer holds,
    /// and a frame step that posts the frame it saw.
    /// </summary>
    public BridgeExportsTests()
    {
        BridgeExports.Install(new BridgeHost("0.6.9", _log, context =>
        {
            context.Register("big", (_, _) =>
            {
                _bigRuns++;
                return new string('x', ReplySize * 2);
            });
            context.EveryFrame(open => open.Events.Post("frame", open.Frame));
        }));
    }

    /// <summary>
    /// Asserts that mf_bridge_open opens a context, that a reply too large for the scripts' buffer is
    /// parked by mf_call and handed out by mf_reply into a larger one, its handler run once, and that
    /// mf_drain hands out the events of the frame the scripts passed.
    /// </summary>
    [Fact]
    public void Exports_OpenCallReplyAndDrainAsTheScriptsDo()
    {
        int context = Open();
        byte[] small = new byte[ReplySize];

        int needed = -Call(context, "big", [], small);
        byte[] large = new byte[needed];
        byte[] events = new byte[ReplySize];
        int written;
        int drained;
        fixed (byte* buffer = large)
        {
            written = ReplyExport(context, buffer, large.Length);
        }

        fixed (byte* buffer = events)
        {
            drained = DrainExport(context, 42, buffer, events.Length);
        }

        Assert.True(needed > ReplySize);
        Assert.Equal(needed, written);
        Assert.Equal(new string('x', ReplySize * 2), RubyMarshal.Read(large).AsHash()["value"].AsText());
        Assert.Equal(1, _bigRuns);
        Assert.Equal(new RubyArray { new RubyArray { "frame", 42 } }, RubyMarshal.Read(events.AsSpan(0, drained)));
    }

    /// <summary>
    /// Shakes hands through mf_bridge_open.
    /// </summary>
    /// <returns>The context's id.</returns>
    private static int Open()
    {
        byte[] reply = new byte[ReplySize];
        int written;
        fixed (byte* buffer = reply)
        {
            written = OpenExport(BridgeHost.Version, buffer, reply.Length);
        }

        return RubyMarshal.Read(reply.AsSpan(0, written)).AsHash()["value"].AsHash()["context"].AsInt();
    }

    /// <summary>
    /// Calls a topic through mf_call, its name null-terminated as the scripts pass it.
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <param name="reply">The reply buffer.</param>
    /// <returns>What mf_call returned.</returns>
    private static int Call(int context, string topic, byte[] request, byte[] reply)
    {
        byte[] name = System.Text.Encoding.UTF8.GetBytes(topic + "\0");
        fixed (byte* namePointer = name, requestPointer = request, replyPointer = reply)
        {
            return CallExport(context, namePointer, requestPointer, request.Length, replyPointer, reply.Length);
        }
    }
}
