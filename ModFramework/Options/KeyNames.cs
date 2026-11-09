//----------------------------------------------------------------
//  KeyNames.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Kept the one set of the framework's own keys, which binding and pressing a hotkey both ask
//                            - Decided which cancel keys leave a text field, for the tree and the scripts
//      Paulinchen  2026-11-05: Refused every key F1 binds, the keys the game and the framework read, and kept the cancel keys
//      Paulinchen  2026-11-04: Named Ctrl without a side
//      Paulinchen  2026-10-30: Asked Windows for a key's name only on Windows
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using MGQParadox.ModFramework.Input;

namespace MGQParadox.ModFramework.Options;

/// <summary>
/// The keys a key row of Options > Mods and a hotkey field take: their names, and which ones keep
/// the old key, belong to the game or the framework, or bind.
/// </summary>
internal static partial class KeyNames
{
    /// <summary>
    /// Windows' code of Escape.
    /// </summary>
    public const int Escape = 0x1B;

    /// <summary>
    /// Windows' code of the numpad's 0, the game's cancel.
    /// </summary>
    public const int NumpadZero = 0x60;

    /// <summary>
    /// Windows' code of Insert, the numpad's 0 while Num Lock is off.
    /// </summary>
    public const int Insert = 0x2D;

    /// <summary>
    /// What a key row says for no key.
    /// </summary>
    public const string None = "None";

    /// <summary>
    /// Windows' code of Enter, which submits a text field.
    /// </summary>
    private const int EnterKey = 0x0D;

    /// <summary>
    /// Windows' code of Shift without a side, which types capitals.
    /// </summary>
    private const int ShiftKey = 0x10;

    /// <summary>
    /// Windows' code of Space.
    /// </summary>
    private const int SpaceKey = 0x20;

    /// <summary>
    /// The letters a text field's "takes" may name.
    /// </summary>
    private const string Letters = "abcdefghijklmnopqrstuvwxyz";

    /// <summary>
    /// The keys a key row takes: the keyboard's, without the mouse buttons, the Windows keys, which
    /// leave the game, and Shift, Ctrl and Alt without a side, which Windows reports with the sided
    /// ones.
    /// </summary>
    public static readonly IReadOnlyList<int> Bindable =
    [
        0x08, 0x09, 0x0D, 0x13, 0x14, 0x1B, 0x5D, 0x90, 0x91, 0xE2,
        .. Enumerable.Range(0x20, 15), .. Enumerable.Range(0x30, 10), .. Enumerable.Range(0x41, 26), .. Enumerable.Range(0x60, 16),
        .. Enumerable.Range(0x70, 24), .. Enumerable.Range(0xA0, 6), .. Enumerable.Range(0xBA, 7), .. Enumerable.Range(0xDB, 5),
    ];

    /// <summary>
    /// The keys the game reads whatever F1 binds: Page Up and Down, the arrows and the numpad's 2, 4,
    /// 6 and 8, Shift and Ctrl, which skips messages, F1, F2 and F12 of RGSS, and F5 to F9.
    /// </summary>
    public static readonly IReadOnlySet<int> FixedGameKeys = new HashSet<int>
    {
        0x21, 0x22, 0x25, 0x26, 0x27, 0x28, 0x62, 0x64, 0x66, 0x68, 0xA0, 0xA1, 0xA2, 0xA3, 0x70, 0x71, 0x7B, 0x74, 0x75, 0x76, 0x77, 0x78,
    };

    /// <summary>
    /// The keys the framework reads itself on every root whatever F1 binds: Tab, Enter, Space, Esc,
    /// the numpad's 0 in either Num Lock state, Page Up and Down, the arrows, the left Alt, which
    /// arranges the boxes, the Menu key, Home and End.
    /// </summary>
    private static readonly IReadOnlySet<int> FrameworkKeys = new HashSet<int>
    {
        0x09, 0x0D, 0x20, 0x1B, 0x60, 0x2D, 0x21, 0x22, 0x25, 0x26, 0x27, 0x28, 0xA4, 0x5D, 0x24, 0x23,
    };

    /// <summary>
    /// The game's buttons whose keys, as F1 binds them, are the framework's too: confirm, cancel, L and R.
    /// </summary>
    private static readonly string[] FrameworkButtons = ["C", "B", "L", "R"];

    /// <summary>
    /// Windows' code of Shift without a side, which F1 binds, and the sided codes a key row reads.
    /// </summary>
    private static readonly (int Code, int[] Sided) Shift = (ShiftKey, [0xA0, 0xA1]);

    /// <summary>
    /// The names of the keys whose name is no character of the keyboard's layout.
    /// </summary>
    private static readonly Dictionary<int, string> Names = BuildNames();

    /// <summary>
    /// What a key pressed for a waiting key row does.
    /// </summary>
    public enum Verdict
    {
        /// <summary>A key a key row never takes, such as a mouse button; the row waits on.</summary>
        Ignored,

        /// <summary>A cancel key: Escape, the numpad's 0 in either Num Lock state or a key F1 binds to cancel; the row keeps its key.</summary>
        Keep,

        /// <summary>A key the game reads itself, as F1 binds it or whatever F1 binds: refused, the row waits on.</summary>
        Game,

        /// <summary>A key the framework reads itself: refused, the row waits on.</summary>
        Framework,

        /// <summary>A key the row takes.</summary>
        Bind,
    }

    /// <summary>
    /// Names a key: from the names of the keys that print no character, else by the character the
    /// keyboard's layout prints on it.
    /// </summary>
    /// <param name="code">Windows' code of the key, 0 or less for none.</param>
    /// <returns>The name, such as "F11", "Num 0" or "Ü".</returns>
    public static string Name(int code)
    {
        if (code <= 0)
        {
            return None;
        }

        return Names.TryGetValue(code, out string? name) ? name : (OperatingSystem.IsWindows() ? LayoutName(code) : null) ?? $"Key {code:X2}";
    }

    /// <summary>
    /// Judges a key pressed for a waiting key row or hotkey field: the cancel keys of the field rule
    /// keep the old key, and every key a game button, the game or the framework reads is refused.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="assignment">The keys F1 binds to the game's buttons.</param>
    /// <returns>What it does.</returns>
    public static Verdict Judge(int code, ButtonAssignment assignment)
    {
        ArgumentNullException.ThrowIfNull(assignment);
        if (!Bindable.Contains(code))
        {
            return Verdict.Ignored;
        }

        if (code is Escape or NumpadZero or Insert || Bound(assignment, "B", code))
        {
            return Verdict.Keep;
        }

        if (IsFrameworkKey(code, assignment))
        {
            return Verdict.Framework;
        }

        return FixedGameKeys.Contains(code) || ButtonAssignment.Buttons.Values.Any(button => Bound(assignment, button, code)) ? Verdict.Game : Verdict.Bind;
    }

    /// <summary>
    /// Tells whether a key is one of the framework's own, which no hotkey sits on and which the
    /// binding of a hotkey and its press both ask.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="assignment">The keys F1 binds to the game's buttons.</param>
    /// <returns>Whether it is: a key the framework reads itself, or one F1 binds to confirm, cancel, L or R.</returns>
    public static bool IsFrameworkKey(int code, ButtonAssignment assignment) =>
        FrameworkKeys.Contains(code) || FrameworkButtons.Any(button => Bound(assignment, button, code));

    /// <summary>
    /// Tells whether a cancel key leaves a text field that types: Escape and Insert always, the
    /// numpad's 0 unless the field takes digits but no letters, where it types its 0, and another
    /// key bound to the game's cancel only when it types nothing into the field. Enter submits and
    /// Shift types capitals, so neither leaves one.
    /// </summary>
    /// <param name="takes">The characters of the keys bound to the game's buttons that the field
    /// types, as a text field's "takes" names them; null for every character.</param>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>Whether it leaves the field.</returns>
    public static bool LeavesField(string? takes, int code) => code switch
    {
        Escape or Insert => true,
        EnterKey or ShiftKey => false,
        NumpadZero => !(Types(takes, '0') && !Letters.Any(letter => Types(takes, letter))),
        SpaceKey => !Types(takes, ' '),
        _ => !Types(takes, char.ToLowerInvariant((char)code)),
    };

    /// <summary>
    /// Tells whether a text field types a character of a key bound to the game's buttons.
    /// </summary>
    /// <param name="takes">The characters it types, null for every character.</param>
    /// <param name="character">The character, a letter in lower case.</param>
    /// <returns>Whether it does.</returns>
    private static bool Types(string? takes, char character) => takes is null || takes.Contains(character, StringComparison.Ordinal);

    /// <summary>
    /// Tells whether F1 binds a key to one of the game's buttons, Shift by either side.
    /// </summary>
    /// <param name="assignment">The keys F1 binds.</param>
    /// <param name="button">The button's name, such as "B".</param>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>Whether it does.</returns>
    private static bool Bound(ButtonAssignment assignment, string button, int code) =>
        assignment.KeysOf(button).Any(bound => bound == code || (bound == Shift.Code && Shift.Sided.Contains(code)));

    /// <summary>
    /// Builds the names of the keys that print no character, and of the letters, digits, numpad
    /// digits and F keys, which read the same on every layout.
    /// </summary>
    /// <returns>The names by code.</returns>
    private static Dictionary<int, string> BuildNames()
    {
        var names = new Dictionary<int, string>
        {
            [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x11] = "Ctrl", [0x13] = "Pause", [0x14] = "Caps Lock", [0x1B] = "Esc",
            [0x20] = "Space", [0x21] = "Page Up", [0x22] = "Page Down", [0x23] = "End", [0x24] = "Home", [0x25] = "Left",
            [0x26] = "Up", [0x27] = "Right", [0x28] = "Down", [0x29] = "Select", [0x2A] = "Print", [0x2B] = "Execute",
            [0x2C] = "Print Screen", [0x2D] = "Insert", [0x2E] = "Delete", [0x5D] = "Menu", [0x6A] = "Num *", [0x6B] = "Num +",
            [0x6C] = "Num Separator", [0x6D] = "Num -", [0x6E] = "Num .", [0x6F] = "Num /", [0x90] = "Num Lock",
            [0x91] = "Scroll Lock", [0xA0] = "Left Shift", [0xA1] = "Right Shift", [0xA2] = "Left Ctrl", [0xA3] = "Right Ctrl",
            [0xA4] = "Left Alt", [0xA5] = "Right Alt",
        };
        for (int code = 0x30; code <= 0x39; code++)
        {
            names[code] = ((char)code).ToString();
        }

        for (int code = 0x41; code <= 0x5A; code++)
        {
            names[code] = ((char)code).ToString();
        }

        for (int code = 0x60; code <= 0x69; code++)
        {
            names[code] = $"Num {code - 0x60}";
        }

        for (int code = 0x70; code <= 0x87; code++)
        {
            names[code] = $"F{code - 0x6F}";
        }

        return names;
    }

    /// <summary>
    /// Asks Windows for the character the keyboard's layout prints on a key.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>The name, null when Windows has none.</returns>
    private static unsafe string? LayoutName(int code)
    {
        uint scan = MapVirtualKeyW((uint)code, 0);
        if (scan == 0)
        {
            return null;
        }

        char* buffer = stackalloc char[32];
        int length = GetKeyNameTextW((int)(scan << 16), buffer, 32);
        return length > 0 ? new string(buffer, 0, length) : null;
    }

    /// <summary>
    /// Turns a key's code into its scan code.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="type">0, MAPVK_VK_TO_VSC.</param>
    /// <returns>The scan code, 0 for none.</returns>
    [LibraryImport("user32.dll")]
    private static partial uint MapVirtualKeyW(uint code, uint type);

    /// <summary>
    /// Names a key by its scan code in the keyboard's layout.
    /// </summary>
    /// <param name="parameter">The scan code in bits 16 to 23.</param>
    /// <param name="buffer">Where the name goes.</param>
    /// <param name="size">The buffer's room in characters.</param>
    /// <returns>The name's length, 0 for none.</returns>
    [LibraryImport("user32.dll")]
    private static unsafe partial int GetKeyNameTextW(int parameter, char* buffer, int size);
}
