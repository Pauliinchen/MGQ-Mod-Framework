//----------------------------------------------------------------
//  IBridgeLog.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQParadox.ModFramework.Bridge;

/// <summary>
/// Where the bridge's lines go: the framework's log in the game, a list in the tests.
/// </summary>
public interface IBridgeLog
{
    /// <summary>
    /// Writes one line.
    /// </summary>
    /// <param name="line">The line, a sentence without a time stamp.</param>
    void Write(string line);
}
