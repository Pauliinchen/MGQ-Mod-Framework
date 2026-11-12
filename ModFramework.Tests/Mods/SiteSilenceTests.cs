//----------------------------------------------------------------
//  SiteSilenceTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MGQParadox.ModFramework.Mods;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the website going silent in the middle of an answer, as when the Wi-Fi drops or the
/// laptop sleeps during a download: the work ends with the website unreachable and the next one runs.
/// </summary>
public sealed class SiteSilenceTests
{
    /// <summary>
    /// How long the test's client waits for the website, before an answer and between two parts of it.
    /// </summary>
    private static readonly TimeSpan Silence = TimeSpan.FromSeconds(2);

    /// <summary>
    /// How long a test waits for work that must end long before.
    /// </summary>
    private static readonly TimeSpan Deadline = TimeSpan.FromSeconds(15);

    /// <summary>
    /// A website list of one mod.
    /// </summary>
    private static readonly byte[] SiteList = Encoding.UTF8.GetBytes("""
        {"schema":4,"mods":[{"slug":"level-cap","name":"Level Cap","author":"Someone","tag":"Regular","versions":[{"version":"1","changelog":"","uploadedAt":"2026-10-20T10:00:00+00:00","package":{"name":"Level_Cap.rb","size":1,"sha256":"aa","url":"https://mgqonline.org/mods/level-cap/1/download"},"files":[{"path":"Level_Cap.rb","sha256":"aa"}]}]}]}
        """);

    /// <summary>
    /// Asserts that an install whose download goes silent ends on its own as the website not being
    /// reached, and that the next install of the mod runs and takes a download that comes slowly,
    /// with every pause shorter than the client waits but all of it longer.
    /// </summary>
    [Fact]
    public void Install_WebsiteGoesSilent_EndsAndTheNextInstallTakesASlowDownload()
    {
        using var game = new TempFolder();
        using var website = new LoopbackWebsite();
        var script = Encoding.UTF8.GetBytes("# Level cap\n" + new string('#', 8000) + "\n");
        var mod = ModMerge.Merge([ModUpdatesTests.Mod("level-cap", "Level Cap", ModUpdatesTests.Version("1.0", 1, ("Level_Cap.rb", script)))]).Single();
        var http = website.Client(Silence);
        var install = new ModInstall(each => SiteDownload.Get(each.Install.FileUrl, each.PackageHash, http), work => Threads.TryStart("mods install", work));

        website.Stalls(script);
        Assert.Null(install.Start([mod], game.Path, []));
        Assert.True(SpinWait.SpinUntil(() => !install.Progress.Running, Deadline), "The install waits on the silent website for good.");
        Assert.Equal(("The website could not be reached.", false), (install.Progress.Error, game.Has("Patch/Level_Cap.rb")));

        website.Trickles(script, parts: 4, pause: Silence * 0.4);
        Assert.Null(install.Start([mod], game.Path, []));
        Assert.True(SpinWait.SpinUntil(() => !install.Progress.Running, Deadline), "The slow install never ended.");
        Assert.Null(install.Progress.Error);
        Assert.Equal(script, game.Read("Patch/Level_Cap.rb"));
    }

    /// <summary>
    /// Asserts that a fetch of the mod list whose answer goes silent ends on its own and keeps no
    /// list, and that the next fetch, as the browser asks for when it opens, keeps the list.
    /// </summary>
    [Fact]
    public void Fetch_WebsiteGoesSilent_EndsAndTheNextFetchKeepsTheList()
    {
        using var game = new TempFolder();
        using var website = new LoopbackWebsite();
        var http = website.Client(Silence);
        var fetch = new ModFetch(() => SiteFeed.FetchList(http));

        website.Stalls(SiteList);
        Assert.True(fetch.Again(game.Path));
        Assert.True(SpinWait.SpinUntil(() => !fetch.Running, Deadline), "The fetch waits on the silent website for good.");
        Assert.Equal((1, false), (fetch.Rounds, fetch.SiteKept));

        website.Trickles(SiteList, parts: 1, pause: TimeSpan.Zero);
        Assert.True(fetch.Again(game.Path));
        Assert.True(SpinWait.SpinUntil(() => !fetch.Running, Deadline), "The second fetch never ended.");
        Assert.Equal((2, true), (fetch.Rounds, fetch.SiteKept));
        Assert.Equal(["level-cap"], ModCache.LoadSite(game.Path)!.Select(each => each.Slug));
    }
}

/// <summary>
/// The website on a socket of this machine, answering each request with the next answer queued,
/// over plain HTTP; a client of it sends every request for the website here.
/// </summary>
internal sealed class LoopbackWebsite : IDisposable
{
    /// <summary>
    /// Takes the connections.
    /// </summary>
    private readonly TcpListener _listener = new(IPAddress.Loopback, 0);

    /// <summary>
    /// The answers not given yet, in order.
    /// </summary>
    private readonly BlockingCollection<Action<NetworkStream>> _answers = [];

    /// <summary>
    /// The connections taken, closed once disposed.
    /// </summary>
    private readonly List<TcpClient> _connections = [];

    /// <summary>
    /// Starts taking connections.
    /// </summary>
    public LoopbackWebsite()
    {
        _listener.Start();
        new Thread(Serve) { IsBackground = true, Name = "loopback website" }.Start();
    }

    /// <summary>
    /// Queues an answer that sends its headers and half of the body, then stays silent with the
    /// connection open.
    /// </summary>
    /// <param name="body">The whole body its headers announce.</param>
    public void Stalls(byte[] body) => _answers.Add(stream =>
    {
        stream.Write(Headers(body.Length));
        stream.Write(body, 0, body.Length / 2);
        stream.Flush();
    });

    /// <summary>
    /// Queues an answer that sends its body in parts with a pause before each, then closes.
    /// </summary>
    /// <param name="body">The body.</param>
    /// <param name="parts">How many parts.</param>
    /// <param name="pause">The pause before each part.</param>
    public void Trickles(byte[] body, int parts, TimeSpan pause) => _answers.Add(stream =>
    {
        stream.Write(Headers(body.Length));
        stream.Flush();
        var size = (body.Length + parts - 1) / parts;

        for (var start = 0; start < body.Length; start += size)
        {
            Thread.Sleep(pause);
            stream.Write(body, start, Math.Min(size, body.Length - start));
            stream.Flush();
        }

        stream.Socket.Shutdown(SocketShutdown.Send);
    });

    /// <summary>
    /// Makes a client that sends every request for the website to this one.
    /// </summary>
    /// <param name="timeout">How long it waits for the website.</param>
    /// <returns>The client, which follows no redirect by itself.</returns>
    public HttpClient Client(TimeSpan timeout) =>
        new(new ToLoopback(((IPEndPoint)_listener.LocalEndpoint).Port) { InnerHandler = new HttpClientHandler { AllowAutoRedirect = false } }) { Timeout = timeout };

    /// <inheritdoc />
    public void Dispose()
    {
        _listener.Stop();
        _answers.CompleteAdding();

        lock (_connections)
        {
            _connections.ForEach(connection => connection.Dispose());
        }
    }

    /// <summary>
    /// Makes the headers of an answer that closes its connection once sent.
    /// </summary>
    /// <param name="length">The body's length.</param>
    /// <returns>The headers.</returns>
    private static byte[] Headers(int length) =>
        Encoding.ASCII.GetBytes($"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {length}\r\nConnection: close\r\n\r\n");

    /// <summary>
    /// Answers each connection in turn until disposed.
    /// </summary>
    private void Serve()
    {
        try
        {
            while (true)
            {
                var connection = _listener.AcceptTcpClient();

                lock (_connections)
                {
                    _connections.Add(connection);
                }

                var stream = connection.GetStream();
                SkipRequest(stream);
                _answers.Take()(stream);
            }
        }
        catch (Exception ex) when (ex is SocketException or ObjectDisposedException or InvalidOperationException or System.IO.IOException)
        {
            // Disposing ends the wait for the next connection or answer.
        }
    }

    /// <summary>
    /// Reads a request up to the end of its headers, which is all a GET has.
    /// </summary>
    /// <param name="stream">The connection.</param>
    private static void SkipRequest(NetworkStream stream)
    {
        var seen = new StringBuilder();

        while (!seen.ToString().EndsWith("\r\n\r\n", StringComparison.Ordinal) && stream.ReadByte() is var next and >= 0)
        {
            seen.Append((char)next);
        }
    }

    /// <summary>
    /// Sends each request for the website to the website on this machine instead.
    /// </summary>
    /// <param name="port">The port of the website on this machine.</param>
    private sealed class ToLoopback(int port) : DelegatingHandler
    {
        /// <inheritdoc />
        protected override HttpResponseMessage Send(HttpRequestMessage request, CancellationToken cancellationToken) =>
            base.Send(Redirected(request), cancellationToken);

        /// <inheritdoc />
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            base.SendAsync(Redirected(request), cancellationToken);

        /// <summary>
        /// Points a request at the website on this machine.
        /// </summary>
        /// <param name="request">The request.</param>
        /// <returns>The request.</returns>
        private HttpRequestMessage Redirected(HttpRequestMessage request)
        {
            request.RequestUri = new UriBuilder(request.RequestUri!) { Scheme = Uri.UriSchemeHttp, Host = IPAddress.Loopback.ToString(), Port = port }.Uri;
            return request;
        }
    }
}
