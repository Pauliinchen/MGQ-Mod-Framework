//----------------------------------------------------------------
//  FrameworkBridgeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Checked the build and the published Version.txt in one test
//                            - Checked every topic the scripts name against the DLL in place of the list of topics
//      Paulinchen  2026-10-31: Checked that a new context answers the topics of the markers
//      Paulinchen  2026-10-30: Checked that a new context answers the topics of the votes
//                            - Checked that a new context answers the topics of the updates
//                            - Checked that a new context answers the topics of the mod browser
//                            - Checked that a new context answers the page topic of the mods
//                            - Checked that a new context answers the topics of the Mod Config rows
//                            - Checked that a new context answers the check topic of a save's mods
//                            - Checked that a new context answers the install topic
//                            - Checked that a new context answers the restart topic
//                            - Checked that a new context answers the topics of the mod management
//      Paulinchen  2026-10-29: Checked that a new context answers the confirm and wheel topics
//      Paulinchen  2026-10-28: Checked that a new context answers the tree topics
//                            - Checked that a new context answers the layout topics
//                            - Checked that a new context answers the text topics
//                            - Checked that a new context answers the frame's tick
//                            - Checked that the published Version.txt names the build
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Ui;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the topics a handshake with ModFramework.dll opens and the build it names.
/// </summary>
public sealed class FrameworkBridgeTests
{
    /// <summary>
    /// Matches a quoted name of the shape of a topic, such as "mods.state".
    /// </summary>
    private static readonly Regex TopicName = new(@"""([a-z]+(?:\.[a-z_]+)+)""", RegexOptions.CultureInvariant);

    /// <summary>
    /// Matches a quoted file name, which has the shape of a topic too.
    /// </summary>
    private static readonly Regex FileName = new(@"\.(?:rbx|rb|dll|so)\z", RegexOptions.CultureInvariant);

    /// <summary>
    /// Asserts that every topic the scripts name is one a new context answers or an event the DLL posts.
    /// </summary>
    /// <remarks>
    /// The Ruby tests answer any topic with a stand-in, so only this check sees a topic renamed on one side.
    /// </remarks>
    [Fact]
    public void ScriptTopics_AreTopicsOrEventsOfTheDll()
    {
        var context = new BridgeContext(1, new NoLog());
        FrameworkBridge.RegisterTopics(context);
        var known = context.Topics.Concat(DllTopicNames()).ToHashSet(StringComparer.Ordinal);
        var folder = Path.Combine(ExportsTests.RepositoryRoot(), "GameScript", "Mod_Framework");

        var named = Directory.EnumerateFiles(folder, "*.rbx", SearchOption.AllDirectories)
            .SelectMany(file => TopicName.Matches(File.ReadAllText(file)).Select(match => match.Groups[1].Value))
            .Where(name => !FileName.IsMatch(name))
            .Distinct()
            .ToList();

        Assert.Contains(UiHost.TickTopic, named);
        Assert.Empty(named.Except(known));
    }

    /// <summary>
    /// Asserts that the build is the version alone and that the publish writes it to Version.txt
    /// beside the DLL, since the loader takes a DLL whose build differs from Version.txt for none.
    /// </summary>
    [Fact]
    public void PublishedVersionFile_NamesTheBuild()
    {
        var file = Path.Combine(ExportsTests.PublishFolder(), "Version.txt");
        Assert.True(File.Exists(file), $"{file} is missing: publish ModFramework before running these tests.");

        Assert.Matches(@"\A\d+\.\d+\.\d+(-dev)?\z", FrameworkBridge.Build);
        Assert.Equal(FrameworkBridge.Build, File.ReadAllText(file).Trim());
    }

    /// <summary>
    /// The names of every topic and event the DLL and its runtime declare as constants.
    /// </summary>
    /// <returns>The names.</returns>
    private static string[] DllTopicNames() =>
        [.. new[] { typeof(FrameworkBridge).Assembly, typeof(ScriptLog).Assembly }
            .SelectMany(assembly => assembly.GetTypes())
            .SelectMany(type => type.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly))
            .Where(field => field.IsLiteral && field.FieldType == typeof(string) && field.Name.EndsWith("Topic", StringComparison.Ordinal))
            .Select(field => (string)field.GetRawConstantValue()!)];

    /// <summary>
    /// A log that drops every line.
    /// </summary>
    private sealed class NoLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
