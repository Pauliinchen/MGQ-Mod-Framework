//----------------------------------------------------------------
//  SiteFilters.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Asked the website MGQ_MODS_SITE names for the filters when it is set
//                            - Read the filters as plain JSON, without a signature
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;

namespace MGQParadox.ModFramework.Mods;

/// <summary>
/// Reads what the filters of the website's list offer, <c>GET /api/mods/filters</c>: the
/// categories in the staff's order and the keywords used most, as plain JSON.
/// </summary>
internal static class SiteFilters
{
    /// <summary>
    /// The address of the filters.
    /// </summary>
    public static readonly string Address = SiteFeed.Address + "/filters";

    /// <summary>
    /// What the filters are, for the log.
    /// </summary>
    private const string What = "filters";

    /// <summary>
    /// Fetches the filters and checks that they can be read, keeping them exactly as they came for the cache.
    /// </summary>
    /// <returns>The filters as they came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the filters could not be read.</exception>
    public static byte[] FetchList() => FetchList(SiteFeed.Http);

    /// <summary>
    /// Fetches the filters with a client of the caller's and checks that they can be read.
    /// </summary>
    /// <param name="http">The client.</param>
    /// <returns>The filters as they came.</returns>
    /// <exception cref="SiteFeedException">The website could not be reached, or the filters could not be read.</exception>
    internal static byte[] FetchList(HttpClient http)
    {
        var filters = SiteFeed.Fetched(Address, What, http);
        ReadList(filters);
        return filters;
    }

    /// <summary>
    /// Reads filters as they came, such as the cache's.
    /// </summary>
    /// <param name="filters">The filters.</param>
    /// <returns>The filters.</returns>
    /// <exception cref="SiteFeedException">The filters could not be read.</exception>
    public static SiteFilterOptions ReadList(byte[] filters) => SiteFeed.Read(filters, What, Parse);

    /// <summary>
    /// Reads the filters.
    /// </summary>
    /// <param name="body">The filters as JSON.</param>
    /// <returns>The categories and the keywords, each in the website's order.</returns>
    private static SiteFilterOptions Parse(byte[] body)
    {
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;
        var categories = SiteMeta.Objects(root, "categories")
            .Select(category => new SiteCategory(SiteMeta.Text(category, "value"), SiteMeta.Text(category, "name")))
            .Where(category => category.Slug.Length > 0)
            .ToList();
        var keywords = SiteMeta.Objects(root, "keywords").Select(keyword => SiteMeta.Text(keyword, "value")).Where(keyword => keyword.Length > 0).ToList();
        return new SiteFilterOptions(categories, keywords);
    }
}

/// <summary>
/// What the website's filters offer.
/// </summary>
/// <param name="Categories">Every category, in the staff's order.</param>
/// <param name="Keywords">The keywords used most, the most used first.</param>
internal sealed record SiteFilterOptions(IReadOnlyList<SiteCategory> Categories, IReadOnlyList<string> Keywords);
