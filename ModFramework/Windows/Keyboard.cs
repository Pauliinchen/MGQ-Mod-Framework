//----------------------------------------------------------------
//  Keyboard.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Cut a paste longer than 65,536 characters
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Dropped giving a take back, since the text box in C# takes it whole
//      Paulinchen  2026-10-07: Logged once when the keyboard's state could not be read
//      Paulinchen  2026-10-06: Kept a take the game script had no room for
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Windows;

/// <summary>
/// What the player types into the game's window while a text screen of the game script wants it,
/// with the keyboard's layout, Shift and AltGr, since RGSS itself only knows buttons.
/// </summary>
/// <remarks>
/// WM_CHAR arrives only when the message loop translates key presses, so until one does, the
/// characters are worked out from the key presses, which combines no accents typed as dead keys.
/// </remarks>
internal static partial class Keyboard
{
    /// <summary>
    /// The character Ctrl+V types, which pastes the clipboard.
    /// </summary>
    private const char Paste = '\u0016';

    /// <summary>
    /// The most UTF-16 characters a paste takes from the clipboard.
    /// </summary>
    /// <remarks>
    /// The game runs as a 32-bit process, and every copy on the way into a text box would otherwise
    /// be as large as whatever was copied, such as a log of tens of megabytes.
    /// </remarks>
    private const int PasteMost = 65_536;

    /// <summary>
    /// Asks ToUnicodeEx to leave the keyboard's state alone, so RGSS's own translating stays as it is.
    /// </summary>
    private const uint KeepKeyboardState = 0x4;

    /// <summary>
    /// Guards every field below.
    /// </summary>
    private static readonly object Gate = new();

    /// <summary>
    /// The characters from WM_CHAR since the last take.
    /// </summary>
    private static readonly StringBuilder FromMessages = new();

    /// <summary>
    /// The characters worked out from key presses since the last take.
    /// </summary>
    private static readonly StringBuilder FromKeys = new();

    /// <summary>
    /// Whether a text screen wants what is typed.
    /// </summary>
    private static bool active;

    /// <summary>
    /// Whether reading the keyboard's state failed once, which the log tells only the first time.
    /// </summary>
    private static bool stateFailed;

    /// <summary>
    /// Whether a WM_CHAR ever arrived, so RGSS translates key presses and those characters count.
    /// </summary>
    private static bool translated;

    /// <summary>
    /// How many keys went down since the last take, which tells a keyboard from a gamepad.
    /// </summary>
    private static int keys;

    /// <summary>
    /// Whether a text screen wants what is typed.
    /// </summary>
    public static bool Active => Volatile.Read(ref active);

    /// <summary>
    /// Starts or stops taking what is typed, forgetting what came before.
    /// </summary>
    /// <param name="on">Whether to take it.</param>
    public static void SetActive(bool on)
    {
        lock (Gate)
        {
            active = on;
            FromMessages.Clear();
            FromKeys.Clear();
            keys = 0;
        }
    }

    /// <summary>
    /// Takes a WM_CHAR's character.
    /// </summary>
    /// <param name="character">The character.</param>
    public static void TakeCharacter(char character)
    {
        lock (Gate)
        {
            if (!translated)
            {
                translated = true;
                Log.Write("keyboard: the game window gets typed characters");
            }

            FromMessages.Append(character);
        }
    }

    /// <summary>
    /// Takes a key press, working out its characters as long as no WM_CHAR arrived.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    public static void TakeKey(uint virtualKey, uint scanCode)
    {
        lock (Gate)
        {
            keys++;

            if (!translated)
            {
                FromKeys.Append(Characters(virtualKey, scanCode));
            }
        }
    }

    /// <summary>
    /// Hands out what was typed since the last take, the clipboard's text in place of Ctrl+V.
    /// </summary>
    /// <returns>The characters, Enter, Backspace and Escape among them as \r, \b and \u001b; and how many keys went down.</returns>
    public static (string Text, int Keys) Take()
    {
        string typed;
        int pressed;

        lock (Gate)
        {
            typed = (translated ? FromMessages : FromKeys).ToString();
            pressed = keys;
            FromMessages.Clear();
            FromKeys.Clear();
            keys = 0;
        }

        if (typed.Contains(Paste))
        {
            typed = typed.Replace(Paste.ToString(), Pasted());
        }

        return (typed, pressed);
    }

    /// <summary>
    /// Reads what a paste types: the clipboard's text, cut to <see cref="PasteMost"/>, without control characters.
    /// </summary>
    /// <returns>The text.</returns>
    private static string Pasted()
    {
        string clipboard = Clipboard.GetText() ?? string.Empty;
        if (clipboard.Length > PasteMost)
        {
            int end = char.IsHighSurrogate(clipboard[PasteMost - 1]) ? PasteMost - 1 : PasteMost;
            Log.Write($"keyboard: cut a paste of {clipboard.Length} characters to {end}");
            clipboard = clipboard[..end];
        }

        return new string(clipboard.Where(character => !char.IsControl(character)).ToArray());
    }

    /// <summary>
    /// Works out the characters a key press types with the keyboard's layout and the keys held.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    /// <returns>The characters, none for a key that types nothing.</returns>
    private static unsafe string Characters(uint virtualKey, uint scanCode)
    {
        var state = stackalloc byte[256];
        var buffer = stackalloc char[8];

        if (!GetKeyboardState(state))
        {
            if (!stateFailed)
            {
                stateFailed = true;
                Log.Write($"keyboard: its state could not be read, Windows error {Marshal.GetLastPInvokeError()}, so keys type nothing");
            }

            return string.Empty;
        }

        var count = ToUnicodeEx(virtualKey, scanCode, state, buffer, 8, KeepKeyboardState, GetKeyboardLayout(0));
        return count > 0 ? new string(buffer, 0, count) : string.Empty;
    }

    /// <summary>
    /// Reads which keys are down, as the thread's messages left them.
    /// </summary>
    /// <param name="state">256 bytes, one per virtual key.</param>
    /// <returns><see langword="true"/> when it was read.</returns>
    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool GetKeyboardState(byte* state);

    /// <summary>
    /// Works out the characters of a key with a keyboard layout.
    /// </summary>
    /// <param name="virtualKey">The key's virtual key code.</param>
    /// <param name="scanCode">The key's scan code.</param>
    /// <param name="state">Which keys are down.</param>
    /// <param name="buffer">Receives the characters.</param>
    /// <param name="size">The buffer's size in characters.</param>
    /// <param name="flags">How to work them out.</param>
    /// <param name="layout">The keyboard layout.</param>
    /// <returns>The number of characters, negative for a dead key, 0 for none.</returns>
    [LibraryImport("user32.dll")]
    private static unsafe partial int ToUnicodeEx(uint virtualKey, uint scanCode, byte* state, char* buffer, int size, uint flags, nint layout);

    /// <summary>
    /// Finds a thread's keyboard layout.
    /// </summary>
    /// <param name="thread">The thread, 0 for this one.</param>
    /// <returns>The layout.</returns>
    [LibraryImport("user32.dll")]
    private static partial nint GetKeyboardLayout(uint thread);
}
