//----------------------------------------------------------------
//  IniTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Checked the write, the refusals and a file that cannot be read in one flow
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Topics;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers reading and writing key=value files through the ini topics.
/// </summary>
public sealed class IniTopicsTests : IDisposable
{
    /// <summary>
    /// A folder of this test's own, deleted after it.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), "ModFramework.Tests " + Guid.NewGuid().ToString("N"));

    /// <inheritdoc />
    public void Dispose()
    {
        if (Directory.Exists(_folder))
        {
            Directory.Delete(_folder, true);
        }
    }

    /// <summary>
    /// Asserts that a write makes the missing folder, as the first store with only the embedded copy
    /// installed does, and the values read back in their order; that a value that is no String and a
    /// key that would not read back as itself are refused before anything is written; and that a file
    /// that exists but cannot be read answers nil and keeps what it holds when a write comes.
    /// </summary>
    [Fact]
    public void WriteThenRead_KeepsTheValuesAndNeverWritesOverWhatItCannotRead()
    {
        var path = Path.Combine(_folder, "Patch", "Mod_Framework", "Mod_Framework.ini");

        Assert.Equal(RubyBool.True, IniTopics.Write(path, new RubyHash { { "ui_preset", "Legacy" }, { "key_accept", "89" } }));
        Assert.Equal(new RubyHash { { "ui_preset", "Legacy" }, { "key_accept", "89" } }, IniTopics.Read(path));

        Assert.Throws<RubyValueException>(() => IniTopics.Write(path, new RubyHash { { "ui_x", 12L } }));
        Assert.Throws<BridgeRequestException>(() => IniTopics.Write(path, new RubyHash { { "ui_a=b", "1" } }));
        Assert.Equal("ui_preset=Legacy\nkey_accept=89\n", File.ReadAllText(path));

        using (new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.Null(IniTopics.Read(path));
            Assert.Equal(RubyBool.False, IniTopics.Write(path, new RubyHash { { "ui_preset", "Monarch" } }));
        }

        Assert.Equal("ui_preset=Legacy\nkey_accept=89\n", File.ReadAllText(path));
        Assert.False(File.Exists(path + ".tmp"));
    }
}
