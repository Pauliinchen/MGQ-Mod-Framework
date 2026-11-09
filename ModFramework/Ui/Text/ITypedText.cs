//----------------------------------------------------------------
//  ITypedText.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Started and stopped taking what is typed
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQParadox.ModFramework.Ui.Text;

/// <summary>
/// What the player typed into the game's window, which the DLL's keyboard hands out.
/// </summary>
public interface ITypedText
{
    /// <summary>
    /// Starts or stops taking what is typed, forgetting what came before.
    /// </summary>
    /// <param name="on">Whether to take it.</param>
    void SetActive(bool on);

    /// <summary>
    /// Hands out what was typed since the last take.
    /// </summary>
    /// <returns>The characters, Enter, Backspace and Escape among them as \r, \b and \u001b, the
    /// clipboard's text in place of Ctrl+V; and how many keys went down.</returns>
    (string Text, int Keys) Take();
}
