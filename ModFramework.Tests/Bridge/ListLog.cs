//----------------------------------------------------------------
//  ListLog.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;

namespace MGQParadox.ModFramework.Tests.Bridge;

/// <summary>
/// A log that keeps its lines for the tests to read.
/// </summary>
internal sealed class ListLog : IBridgeLog
{
    /// <summary>
    /// Gets the lines written, in order.
    /// </summary>
    public List<string> Lines { get; } = [];

    /// <inheritdoc />
    public void Write(string line) => Lines.Add(line);
}
