//----------------------------------------------------------------
//  FakeInput.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Handed out the key messages a test notes
//      Paulinchen  2026-11-04: Added the key settings of F1 with one key bound otherwise and a keyboard that types
//      Paulinchen  2026-10-31: Answered the key settings of F1 a test sets
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui.Text;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// The operating system's input as a test sets it.
/// </summary>
internal sealed class FakeInput : IInputSource
{
    /// <summary>
    /// Gets or sets whether the game's window is in front.
    /// </summary>
    public bool Front { get; set; } = true;

    /// <summary>
    /// Gets or sets where the pointer is.
    /// </summary>
    public ClientPointer? Pointer { get; set; } = new ClientPointer(0, 0, 640, 480);

    /// <summary>
    /// Gets the codes of the keys and physical buttons held.
    /// </summary>
    public HashSet<int> Down { get; } = [];

    /// <summary>
    /// Gets the keys that sent the game's window a key message, which the next take hands out.
    /// </summary>
    public KeyPresses Presses { get; } = new();

    /// <summary>
    /// Gets or sets whether the mouse buttons are swapped.
    /// </summary>
    public bool Swapped { get; set; }

    /// <summary>
    /// Gets or sets the notches the next take hands out.
    /// </summary>
    public int Notches { get; set; }

    /// <inheritdoc />
    /// <summary>
    /// Gets or sets the key settings of F1 the source answers, null for none.
    /// </summary>
    public byte[]? Assign { get; set; }

    /// <summary>
    /// Makes the key settings of F1 with one key bound to another button than the game binds it to.
    /// </summary>
    /// <param name="place">The key's place among the bytes, <see cref="ButtonAssignment.PadButtons"/> and the key's place among the keys.</param>
    /// <param name="button">The button's number: 12 for cancel, 13 for confirm.</param>
    /// <returns>The bytes.</returns>
    public static byte[] Bound(int place, byte button)
    {
        var bytes = (byte[])ButtonAssignment.DefaultBytes.Clone();
        bytes[place] = button;
        return bytes;
    }

    /// <inheritdoc />
    public bool GameInFront() => Front;

    /// <inheritdoc />
    ClientPointer? IInputSource.Pointer() => Pointer;

    /// <inheritdoc />
    public bool KeyDown(int code) => Down.Contains(code);

    /// <inheritdoc />
    public bool ButtonsSwapped() => Swapped;

    /// <inheritdoc />
    /// <inheritdoc />
    public byte[]? ButtonAssign() => Assign;

    /// <inheritdoc />
    public int TakeWheel()
    {
        var notches = Notches;
        Notches = 0;
        return notches;
    }

    /// <inheritdoc />
    public void TakeKeyPresses(Span<ulong> into) => Presses.Take(into);
}

/// <summary>
/// A keyboard that hands out what a test queued, one take each.
/// </summary>
internal sealed class FakeTyping : ITypedText
{
    /// <summary>
    /// Gets the takes to hand out.
    /// </summary>
    public Queue<(string Text, int Keys)> Typed { get; } = new();

    /// <summary>
    /// Gets whether the text box wants what is typed.
    /// </summary>
    public bool Active { get; private set; }

    /// <inheritdoc />
    public void SetActive(bool on) => Active = on;

    /// <inheritdoc />
    public (string Text, int Keys) Take() => Typed.Count > 0 ? Typed.Dequeue() : (string.Empty, 0);
}
