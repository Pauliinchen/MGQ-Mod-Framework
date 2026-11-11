//----------------------------------------------------------------
//  IInputSource.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Handed out the keys that sent the game's window a key message
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-31: Read the game's key settings of F1
//      Paulinchen  2026-10-30: Took what the scripts read of the devices, for JoiPlay
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Input;

/// <summary>
/// Where the pointer rests in the game window's client area, and that area's size, in the
/// window's own pixels.
/// </summary>
/// <param name="X">The pointer's left offset from the client area's left edge, negative left of it.</param>
/// <param name="Y">The pointer's offset from the client area's top edge, negative above it.</param>
/// <param name="Width">The client area's width.</param>
/// <param name="Height">The client area's height.</param>
internal readonly record struct ClientPointer(int X, int Y, int Width, int Height);

/// <summary>
/// What <see cref="InputModel"/> reads from the operating system, or from the scripts, once a tick.
/// </summary>
internal interface IInputSource
{
    /// <summary>
    /// Takes what the scripts read of the devices for this tick, before the tick reads the source;
    /// a source that reads the operating system itself ignores it.
    /// </summary>
    /// <param name="input">The input model's part of the tick.</param>
    void Read(RubyHash input)
    {
    }

    /// <summary>
    /// Tells whether the game's window is the one the player works in.
    /// </summary>
    /// <returns>Whether it is.</returns>
    bool GameInFront();

    /// <summary>
    /// Reads where the pointer is over the game window's client area.
    /// </summary>
    /// <returns>The place, null when it cannot be read.</returns>
    ClientPointer? Pointer();

    /// <summary>
    /// Tells whether a key or a physical mouse button is held, whichever window is in front.
    /// </summary>
    /// <param name="code">Windows' code of the key, such as 0x01 for the left mouse button.</param>
    /// <returns>Whether it is held.</returns>
    bool KeyDown(int code);

    /// <summary>
    /// Tells whether the player swapped the mouse buttons in Windows' settings.
    /// </summary>
    /// <returns>Whether they are swapped.</returns>
    bool ButtonsSwapped();

    /// <summary>
    /// Takes the mouse wheel's whole notches turned since the last take.
    /// </summary>
    /// <returns>The notches, positive away from the player.</returns>
    int TakeWheel();

    /// <summary>
    /// Takes the keys that sent the game's window a key message since the last take.
    /// </summary>
    /// <param name="into">Where the keys go as a set of every key code, see
    /// <see cref="Windows.KeyPresses"/>; a source without key messages leaves it empty.</param>
    void TakeKeyPresses(Span<ulong> into) => into.Clear();

    /// <summary>
    /// Reads the game's key settings of F1, RGSS3's ButtonAssign.
    /// </summary>
    /// <returns>Its bytes, null where none can be read.</returns>
    byte[]? ButtonAssign() => null;
}
