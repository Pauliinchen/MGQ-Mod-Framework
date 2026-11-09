//----------------------------------------------------------------
//  TextMatchTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Checked the places a highlighted text marks
//                            - Created
//
//----------------------------------------------------------------

using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the rule by which a typed text matches a word, as a text field's completions and an
/// autocomplete's matches use it, and where a highlighted text marks it.
/// </summary>
public sealed class TextMatchTests
{
    /// <summary>
    /// Asserts, through a search over quest names, that a typed text matches the names that hold it
    /// anywhere, ignoring case beyond plain letters too; that the name typed whole is left out; and
    /// that an empty text matches nothing.
    /// </summary>
    [Fact]
    public void QuestSearch_MatchesAnywhereIgnoringCase()
    {
        string[] quests = ["Find the herbs", "The herbalist's request", "Rope bridge", "Ärger in Ilias Village"];
        Assert.Equal(["Find the herbs", "The herbalist's request"], TextMatch.Matches("HERB", quests));
        Assert.Equal(["Ärger in Ilias Village"], TextMatch.Matches("ärger", quests));
        Assert.Empty(TextMatch.Matches("rope BRIDGE", quests));
        Assert.Empty(TextMatch.Matches("", quests));
    }

    /// <summary>
    /// Asserts, through a quest name a search highlights, that every place of the text searched for
    /// is found, ignoring case, and that an empty search finds none.
    /// </summary>
    [Fact]
    public void Highlight_FindsEveryPlaceIgnoringCase()
    {
        Assert.Equal([(4, 4), (16, 4)], TextMatch.Places("The herbalist's herb tea", "HERB"));
        Assert.Empty(TextMatch.Places("The herbalist's herb tea", ""));
    }
}
