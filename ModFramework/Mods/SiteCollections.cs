//----------------------------------------------------------------
//  SiteCollections.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Asked the website MGQ_MODS_SITE names for the collections when it is set
//                            - Read the collections as plain JSON, without a signature
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Reads the website's collections, <c>GET /api/collections</c>: named lists of its mods that
/// players install together, as plain JSON, as its mod list is.
/// </summary>
internal static class SiteCollections
{
    /// <summary>
    /// The list's address.
    /// </summary>
    public static readonly string Address = SiteFeed.Site + "/api/collections";

    /// <summary>
    /// What the list is, for the log.
    /// </summary>
    private const string What = "collections";

    /// <summary>
    /// Fetches the list and checks that it can be read, keeping it exactly as it came for the cache.
    /// </summary>
    /// <returns>The list as it came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be read.</exception>
    public static byte[] FetchList() => FetchList(SiteFeed.Http);

    /// <summary>
    /// Fetches the list with a client of the caller's and checks that it can be read.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <returns>The list as it came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the list could not be read.</exception>
    internal static byte[] FetchList(HttpClient http)
    {
        var list = SiteFeed.Fetched(Address, What, http);
        ReadList(list);
        return list;
    }

    /// <summary>
    /// Reads a list as it came, such as the cache's.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The collections.</returns>
    /// <exception cref="SiteFeedException">The list could not be read.</exception>
    public static IReadOnlyList<SiteCollection> ReadList(byte[] list) => SiteFeed.Read(list, What, Parse);

    /// <summary>
    /// Reads the list.
    /// </summary>
    /// <param name="body">The list as JSON.</param>
    /// <returns>The collections, each with its mods in the order they install.</returns>
    private static List<SiteCollection> Parse(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        var collections = new List<SiteCollection>();

        foreach (var collection in document.RootElement.GetProperty("collections").EnumerateArray())
        {
            var mods = new List<CollectionEntry>();

            foreach (var mod in collection.GetProperty("mods").EnumerateArray())
            {
                var slug = Text(mod, "slug");

                if (slug.Length > 0)
                {
                    mods.Add(new CollectionEntry(slug, Text(mod, "version"), mod.TryGetProperty("available", out var available) && available.ValueKind == JsonValueKind.True));
                }
            }

            var name = Text(collection, "slug");

            if (name.Length > 0)
            {
                collections.Add(new SiteCollection(name, Text(collection, "name"), Text(collection, "summary"), Text(collection, "author"), PageOf(collection), mods));
            }
        }

        return collections;
    }

    /// <summary>
    /// Reads a collection's page, taking it only on the website over HTTPS.
    /// </summary>
    /// <param name="collection">The collection as JSON.</param>
    /// <returns>The page; empty for none or one elsewhere.</returns>
    private static string PageOf(JsonElement collection) =>
        Uri.TryCreate(Text(collection, "page"), UriKind.Absolute, out var page) && SiteDownload.IsSite(page) ? page.AbsoluteUri : string.Empty;

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object holding it.</param>
    /// <param name="name">The field's name.</param>
    /// <returns>The text; empty when the field is missing, null or no text.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
}

/// <summary>
/// A collection of the website: mods players install together, in their order.
/// </summary>
/// <param name="Slug">Its id on the website.</param>
/// <param name="Name">Its name.</param>
/// <param name="Summary">What it is for, in a sentence.</param>
/// <param name="Author">Who made it.</param>
/// <param name="Page">Its page on the website; empty for none.</param>
/// <param name="Mods">Its mods in the order they install.</param>
internal sealed record SiteCollection(string Slug, string Name, string Summary, string Author, string Page, IReadOnlyList<CollectionEntry> Mods);

/// <summary>
/// A mod of a collection.
/// </summary>
/// <param name="Slug">The mod's slug, as the website's mod list names it.</param>
/// <param name="Version">The version the collection holds; empty for the newest.</param>
/// <param name="Available">Whether the website lists the mod and the version, so it can be installed.</param>
internal sealed record CollectionEntry(string Slug, string Version, bool Available);
