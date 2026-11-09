//----------------------------------------------------------------
//  SiteDownloadTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-04: Checked the download and its refusals in one flow
//      Paulinchen  2026-10-30: Covered the install key sent with every request of a download
//                            - Moved into the Mod Framework
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using MGQParadox.ModFramework.Mods;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// Covers the rules a download of the website's mods follows: only the website, and only the file the list names.
/// </summary>
public sealed class SiteDownloadTests
{
    /// <summary>
    /// A package's address as the list names it.
    /// </summary>
    private const string PackageUrl = "https://mgqonline.org/mods/level-cap/1.5.2/download";

    /// <summary>
    /// Where the website stores the package.
    /// </summary>
    private const string StoredUrl = "https://mgqonline.org/files/level-cap-1.5.2.rb";

    /// <summary>
    /// The package.
    /// </summary>
    private static readonly byte[] Package = [1, 2, 3];

    /// <summary>
    /// Asserts that a redirect within the website is followed and the file taken when its hash is the
    /// list's, the install key sent as the bearer value of both requests, and that an address off the
    /// website, plain HTTP, a redirect elsewhere and a file whose hash is not the list's are refused
    /// before anything is taken from there.
    /// </summary>
    [Fact]
    public void Get_TakesOnlyTheListedFileFromTheWebsite()
    {
        var website = new FakeWebsite { [PackageUrl] = () => Redirect(StoredUrl), [StoredUrl] = () => File(Package) };
        var key = new string('a', 64);

        Assert.Equal(Package, SiteDownload.Get(PackageUrl, Sha256Of(Package), website.Client(), key));
        Assert.Equal([PackageUrl, StoredUrl], website.Requested);
        Assert.Equal([key, key], website.Calls.Select(call => call.Bearer));

        var elsewhere = new FakeWebsite { [PackageUrl] = () => Redirect("https://example.com/level-cap.rb") };
        var differing = new FakeWebsite { [PackageUrl] = () => File([9, 9]) };

        Assert.Throws<InvalidOperationException>(() => SiteDownload.Get("https://example.com/level-cap.rb", Sha256Of(Package), elsewhere.Client()));
        Assert.Throws<InvalidOperationException>(() => SiteDownload.Get("http://mgqonline.org/mods/level-cap/1.5.2/download", Sha256Of(Package), elsewhere.Client()));
        Assert.Contains("example.com", Assert.Throws<InvalidOperationException>(() => SiteDownload.Get(PackageUrl, Sha256Of(Package), elsewhere.Client())).Message);
        Assert.Equal([PackageUrl], elsewhere.Requested);
        Assert.Contains("differs", Assert.Throws<InvalidOperationException>(() => SiteDownload.Get(PackageUrl, Sha256Of(Package), differing.Client())).Message);
    }

    /// <summary>
    /// Hashes a file as the website's list does.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 of its raw bytes, lowercase hexadecimal.</returns>
    private static string Sha256Of(byte[] bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));

    /// <summary>
    /// Makes an answer that sends the download on.
    /// </summary>
    /// <param name="location">Where to.</param>
    /// <returns>The answer.</returns>
    private static HttpResponseMessage Redirect(string location)
    {
        var response = new HttpResponseMessage(HttpStatusCode.Found);
        response.Headers.Location = new Uri(location);
        return response;
    }

    /// <summary>
    /// Makes an answer that carries a file.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The answer.</returns>
    private static HttpResponseMessage File(byte[] bytes) => new(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) };
}
