//----------------------------------------------------------------
//  ButtonAssignment.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQParadox.ModFramework.Input;

/// <summary>
/// The keyboard's keys the game reads as each of its buttons, as the player bound them in the
/// game's F1 settings, which RGSS3 keeps as ButtonAssign under HKCU\Software\Enterbrain\RGSS3.
/// </summary>
internal sealed class ButtonAssignment
{
    /// <summary>
    /// The bytes of ButtonAssign: ten for the gamepad's buttons, then one per keyboard key of
    /// <see cref="KeyboardKeys"/>.
    /// </summary>
    public const int Length = 25;

    /// <summary>
    /// The bytes before the keyboard's, those of the gamepad's ten buttons.
    /// </summary>
    public const int PadButtons = 10;

    /// <summary>
    /// The game's buttons by the number ButtonAssign holds for them, Input::A (11) to Input::R (18).
    /// </summary>
    public static readonly IReadOnlyDictionary<int, string> Buttons = new Dictionary<int, string>
    {
        [11] = "A", [12] = "B", [13] = "C", [14] = "X", [15] = "Y", [16] = "Z", [17] = "L", [18] = "R",
    };

    /// <summary>
    /// Windows' codes of the keyboard's keys in the order of ButtonAssign: Space, Enter, Esc, the
    /// numpad's 0 (with Num Lock on and off), Shift, Z, X, C, V, B, A, S, D, Q and W.
    /// </summary>
    public static readonly IReadOnlyList<int[]> KeyboardKeys =
    [
        [0x20], [0x0D], [0x1B], [0x60, 0x2D], [0x10], [0x5A], [0x58], [0x43], [0x56], [0x42], [0x41], [0x53], [0x44], [0x51], [0x57],
    ];

    /// <summary>
    /// What RGSS3 binds the keyboard's keys to until the player changes them.
    /// </summary>
    public static readonly byte[] DefaultBytes = [11, 12, 13, 14, 15, 16, 17, 18, 0, 0, 13, 13, 12, 12, 11, 13, 12, 0, 0, 0, 14, 15, 16, 17, 18];

    /// <summary>
    /// The keys no setting changes: Page Up is always the game's L and Page Down its R.
    /// </summary>
    private static readonly IReadOnlyDictionary<string, int[]> FixedKeys = new Dictionary<string, int[]> { ["L"] = [0x21], ["R"] = [0x22] };

    /// <summary>
    /// The keys of each button.
    /// </summary>
    private readonly Dictionary<string, int[]> _keys;

    /// <summary>
    /// Builds the assignment of ButtonAssign's bytes.
    /// </summary>
    /// <param name="bytes">The bytes, <see cref="Length"/> of them.</param>
    private ButtonAssignment(byte[] bytes)
    {
        _keys = Buttons.Values.ToDictionary(button => button, button =>
            KeyboardKeys.Where((_, place) => Buttons.TryGetValue(bytes[PadButtons + place], out var bound) && bound == button)
                .SelectMany(codes => codes).Concat(FixedKeys.GetValueOrDefault(button, [])).ToArray());
    }

    /// <summary>
    /// Gets the game's own assignment, which the game keeps until the player changes one in F1.
    /// </summary>
    public static ButtonAssignment Default { get; } = new(DefaultBytes);

    /// <summary>
    /// Reads ButtonAssign's bytes.
    /// </summary>
    /// <param name="bytes">The bytes, null when none could be read.</param>
    /// <param name="why">Why the game's defaults stand instead, null when the bytes were read.</param>
    /// <returns>The assignment, <see cref="Default"/> for bytes of another length or none.</returns>
    public static ButtonAssignment Read(byte[]? bytes, out string? why)
    {
        why = bytes is null ? "the game keeps no key settings of F1 on this PC" : bytes.Length != Length ? $"its key settings of F1 hold {bytes.Length} bytes, not {Length}" : null;
        return why is null ? new ButtonAssignment(bytes!) : Default;
    }

    /// <summary>
    /// Tells the keyboard's keys the game reads as one of its buttons.
    /// </summary>
    /// <param name="button">The button's name, such as "B".</param>
    /// <returns>Windows' codes of the keys, none for a button no key is bound to.</returns>
    public IReadOnlyList<int> KeysOf(string button) => _keys.TryGetValue(button, out var keys) ? keys : [];

    /// <summary>
    /// Tells whether two assignments bind every button to the same keys.
    /// </summary>
    /// <param name="other">The other assignment.</param>
    /// <returns>Whether they do.</returns>
    public bool SameAs(ButtonAssignment other)
    {
        ArgumentNullException.ThrowIfNull(other);
        return _keys.All(pair => pair.Value.SequenceEqual(other.KeysOf(pair.Key)));
    }

    /// <summary>
    /// Describes the assignment for the log.
    /// </summary>
    /// <returns>Each button with its keys' codes, such as "B: 1B 60 2D 58".</returns>
    public override string ToString() =>
        string.Join(", ", _keys.Select(pair => $"{pair.Key}: {(pair.Value.Length == 0 ? "none" : string.Join(" ", pair.Value.Select(code => code.ToString("X2"))))}"));
}
