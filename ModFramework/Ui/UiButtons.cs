//----------------------------------------------------------------
//  UiButtons.cs
//
//  Changelog:
//      Paulinchen  2026-11-04: Told which extra buttons the game asked about in the frame before
//                            - Added the game's extra buttons A, X, Y and Z
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//                            - Added the game's L and R buttons
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

namespace MGQParadox.ModFramework.Ui;

/// <summary>
/// The game's buttons a model reads, in the order of their bits.
/// </summary>
public enum UiButton
{
    /// <summary>The game's confirm button, C.</summary>
    Confirm = 0,

    /// <summary>The game's cancel button, B.</summary>
    Cancel = 1,

    /// <summary>Up.</summary>
    Up = 2,

    /// <summary>Down.</summary>
    Down = 3,

    /// <summary>Left.</summary>
    Left = 4,

    /// <summary>Right.</summary>
    Right = 5,

    /// <summary>The game's L button, Page Up and Q on the keyboard.</summary>
    L = 6,

    /// <summary>The game's R button, Page Down and W on the keyboard.</summary>
    R = 7,
}

/// <summary>
/// The game's buttons of a frame as the scripts read them past the capture (Mod_Framework::UI::Tick.buttons):
/// a bit per button that went down, then one per button that went down or repeats, then one per
/// button held.
/// </summary>
/// <param name="Bits">The bits.</param>
public readonly record struct UiButtons(int Bits)
{
    /// <summary>
    /// The buttons in each group of bits.
    /// </summary>
    public const int Count = 8;

    /// <summary>
    /// Tells whether a button went down.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it did.</returns>
    public bool Triggered(UiButton button) => Bit((int)button);

    /// <summary>
    /// Tells whether a button went down or repeats while held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it does.</returns>
    public bool Repeated(UiButton button) => Bit(Count + (int)button);

    /// <summary>
    /// Tells whether a button is held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it is.</returns>
    public bool Pressed(UiButton button) => Bit(2 * Count + (int)button);

    /// <summary>
    /// Reads one bit.
    /// </summary>
    /// <param name="place">The bit's place.</param>
    /// <returns>Whether it is set.</returns>
    private bool Bit(int place) => (Bits & (1 << place)) != 0;
}

/// <summary>
/// The game's extra buttons a model reads, in the order of their bits.
/// </summary>
public enum UiExtraButton
{
    /// <summary>The game's A, Shift on the keyboard, which dashes on the map while held.</summary>
    A = 0,

    /// <summary>The game's X, the keyboard's A, which skips messages.</summary>
    X = 1,

    /// <summary>The game's Y, the keyboard's S.</summary>
    Y = 2,

    /// <summary>The game's Z, the keyboard's D.</summary>
    Z = 3,
}

/// <summary>
/// The game's extra buttons of a frame as the scripts read them past the capture
/// (Mod_Framework::UI::Tick.extra_buttons): a bit per button that went down, then one per button
/// that went down or repeats, then one per button held, then one per button the game itself asked
/// Input about in the frame before while the buttons reached it.
/// </summary>
/// <param name="Bits">The bits.</param>
public readonly record struct UiExtraButtons(int Bits)
{
    /// <summary>
    /// The buttons in each group of bits.
    /// </summary>
    public const int Count = 4;

    /// <summary>
    /// Tells whether a button went down.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it did.</returns>
    public bool Triggered(UiExtraButton button) => Bit((int)button);

    /// <summary>
    /// Tells whether a button is held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it is.</returns>
    public bool Pressed(UiExtraButton button) => Bit(2 * Count + (int)button);

    /// <summary>
    /// Tells whether the game itself asked Input about a button in the frame before, so a screen of
    /// the game uses it.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>Whether it did.</returns>
    public bool Asked(UiExtraButton button) => Bit(3 * Count + (int)button);

    /// <summary>
    /// Reads one bit.
    /// </summary>
    /// <param name="place">The bit's place.</param>
    /// <returns>Whether it is set.</returns>
    private bool Bit(int place) => (Bits & (1 << place)) != 0;
}
