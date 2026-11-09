//----------------------------------------------------------------
//  ScriptInput.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Input;

/// <summary>
/// The pointer, keys and typing as the scripts read them from the engine's Input at each tick, on
/// JoiPlay, where no Windows function reads them: the input model's tick carries them under
/// <see cref="DeviceKey"/>.
/// </summary>
internal sealed class ScriptInput : IInputSource, ITypedText
{
    /// <summary>
    /// The name of the devices in the input model's tick: a hash of "mouse" ([x, y, width, height],
    /// the pointer and the range it reports over the game's screen, nil for none), "keys" (Windows'
    /// codes of the keys and mouse buttons held), "wheel" (notches turned) and "typed" (the text
    /// typed, "\b" for each Backspace and "\r" for Enter).
    /// </summary>
    public const string DeviceKey = "device";

    /// <summary>
    /// The codes of the keys and buttons held at the last tick.
    /// </summary>
    private readonly HashSet<int> _held = [];

    /// <summary>
    /// What was typed since the last take, while typing is on.
    /// </summary>
    private readonly StringBuilder _typed = new();

    /// <summary>
    /// Where the pointer was at the last tick, null for nowhere.
    /// </summary>
    private ClientPointer? _pointer;

    /// <summary>
    /// The notches the wheel turned since the last take.
    /// </summary>
    private int _wheel;

    /// <summary>
    /// The characters typed since the last take.
    /// </summary>
    private int _keys;

    /// <summary>
    /// Whether a text box takes what is typed.
    /// </summary>
    private bool _active;

    /// <inheritdoc />
    public void Read(RubyHash input)
    {
        RubyValue value = input[DeviceKey];
        if (value.IsNil)
        {
            return;
        }

        RubyHash device = value.AsHash();
        _pointer = device["mouse"] is RubyArray { Count: 4 } mouse
            ? new ClientPointer(mouse[0].AsInt(), mouse[1].AsInt(), mouse[2].AsInt(), mouse[3].AsInt())
            : null;
        _held.Clear();
        if (device["keys"] is RubyArray keys)
        {
            foreach (RubyValue code in keys)
            {
                _held.Add(code.AsInt());
            }
        }

        _wheel += device["wheel"] is RubyInteger ? device["wheel"].AsInt() : 0;
        if (_active && device["typed"] is RubyString typed)
        {
            string text = Encoding.UTF8.GetString(typed.Bytes.Span);
            _typed.Append(text);
            _keys += text.Length;
        }
    }

    /// <inheritdoc />
    public bool GameInFront() => true;

    /// <inheritdoc />
    public ClientPointer? Pointer() => _pointer;

    /// <inheritdoc />
    public bool KeyDown(int code) => _held.Contains(code);

    /// <inheritdoc />
    public bool ButtonsSwapped() => false;

    /// <inheritdoc />
    public int TakeWheel()
    {
        int notches = _wheel;
        _wheel = 0;
        return notches;
    }

    /// <inheritdoc />
    public void SetActive(bool on)
    {
        _active = on;
        _typed.Clear();
        _keys = 0;
    }

    /// <inheritdoc />
    public (string Text, int Keys) Take()
    {
        var taken = (_typed.ToString(), _keys);
        _typed.Clear();
        _keys = 0;
        return taken;
    }
}
