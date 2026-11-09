//----------------------------------------------------------------
//  ComponentTreeCapture.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Options;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The key capture of the component tree: a part that waits for the key the player presses to bind
/// a hotkey, such as a hotkey field or a key row of the options list.
/// </summary>
internal sealed partial class ComponentTree
{
    /// <summary>
    /// Windows' code of the left mouse button, whose click outside the part ends the wait.
    /// </summary>
    private const int CaptureMouse = 0x01;

    /// <summary>
    /// The part that waits for a key, null while none does.
    /// </summary>
    private Node? _capture;

    /// <summary>
    /// The key, or the mouse button, that ended the wait and is still held, which the wait swallows
    /// until it is let go; 0 while the wait goes on.
    /// </summary>
    private int _captureHeld;

    /// <summary>
    /// Whether the gamepad's cancel ended the wait and is still held.
    /// </summary>
    private bool _captureCancelHeld;

    /// <summary>
    /// The free key held down that binds once it is let go, 0 for none.
    /// </summary>
    private int _captureKey;

    /// <summary>
    /// Whether another key was held together with <see cref="_captureKey"/>, so that it binds nothing.
    /// </summary>
    private bool _captureChord;

    /// <summary>
    /// Finds the part that started to wait for a key in the scripts' changes, and watches every key
    /// a hotkey may take while it waits.
    /// </summary>
    private void FindCapture()
    {
        if (_capture is { } waiting && (!_nodes.ContainsKey(waiting.Id) || waiting.CaptureTaken is null))
        {
            _capture = null;
        }

        if (_capture is not null)
        {
            return;
        }

        _capture = _nodes.Values.FirstOrDefault(node => node.CaptureTaken is not null);
        if (_capture is null)
        {
            return;
        }

        (_captureHeld, _captureCancelHeld, _captureKey, _captureChord) = (0, false, 0, false);
        foreach (int code in KeyNames.Bindable)
        {
            _input.Watch(code);
        }
    }

    /// <summary>
    /// Takes the tick's input for the part that waits for a key, which holds every key and the
    /// pointer meanwhile: a free key binds as it is let go, with the confirm sound, unless another key
    /// was held with it; a cancel key, the gamepad's cancel or a click outside the part keep the old
    /// key, with the cancel sound; a key a game button, the game, the framework or another hotkey has
    /// is refused, with the buzzer, and the wait goes on. A key that kept the old one reaches nothing
    /// else until it is let go, when the wait ends.
    /// </summary>
    /// <param name="buttons">The game's buttons of the tick.</param>
    private void FollowCapture(UiButtons buttons)
    {
        Node part = _capture!;
        if (_captureHeld != 0 || _captureCancelHeld)
        {
            bool held = _captureCancelHeld ? buttons.Pressed(UiButton.Cancel) : _captureHeld == CaptureMouse ? _input.LeftDown : _input.KeyDown(_captureHeld);
            if (!held)
            {
                EndCapture(part);
            }

            return;
        }

        foreach (int code in KeyNames.Bindable.Where(_input.WentDown))
        {
            _taken.Add(code);
            if (TakeCapturedKey(part, code))
            {
                return;
            }
        }

        if (_captureKey != 0)
        {
            FollowHeldKey(part);
        }
        else if (buttons.Triggered(UiButton.Cancel))
        {
            KeepKey(part, null, "pad");
            _captureCancelHeld = true;
        }
        else if (_input.LeftWentDown && _input.Pointer is { } point && part.Rect is { } rect && !rect.Contains(point.X, point.Y))
        {
            KeepKey(part, null, "click");
            _captureHeld = CaptureMouse;
        }
    }

    /// <summary>
    /// Takes a key that went down for the part that waits: a cancel key keeps the old one, a key
    /// another has is refused, and a free key waits to be let go; any key going down while a free
    /// one is held makes a chord of them.
    /// </summary>
    /// <param name="part">The part that waits.</param>
    /// <param name="code">Windows' code of the key.</param>
    /// <returns>Whether the key ended the wait.</returns>
    private bool TakeCapturedKey(Node part, int code)
    {
        _captureChord |= _captureKey != 0 && code != _captureKey;
        switch (KeyNames.Judge(code, _input.Assignment))
        {
            case KeyNames.Verdict.Keep:
                KeepKey(part, code, "key");
                _captureHeld = code;
                return true;
            case KeyNames.Verdict.Game:
                Refuse(part, code, "game", null);
                break;
            case KeyNames.Verdict.Framework:
                Refuse(part, code, "framework", null);
                break;
            case KeyNames.Verdict.Bind when part.CaptureTaken!.TryGetValue(code, out string? owner):
                Refuse(part, code, "hotkey", owner);
                break;
            case KeyNames.Verdict.Bind when _captureKey == 0:
                _captureKey = code;
                _captureChord = KeyNames.Bindable.Any(other => other != code && _input.KeyDown(other));
                break;
        }

        return false;
    }

    /// <summary>
    /// Follows the free key held for the part that waits: let go alone, it binds and the wait ends;
    /// let go after another key was held with it, it is refused and the wait goes on.
    /// </summary>
    /// <param name="part">The part that waits.</param>
    private void FollowHeldKey(Node part)
    {
        int code = _captureKey;
        if (_input.KeyDown(code))
        {
            return;
        }

        bool chord = _captureChord;
        (_captureKey, _captureChord) = (0, false);
        if (chord)
        {
            Refuse(part, code, "chord", null);
            return;
        }

        Cue(UiCue.Ok);
        Event(part.Id, "captured", code);
        _captureHeld = code;
        EndCapture(part);
    }

    /// <summary>
    /// Tells the part that waits that the player kept the old key, with the cancel sound.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <param name="code">Windows' code of the cancel key pressed, null for the gamepad's cancel or a click.</param>
    /// <param name="how">"key", "pad" or "click".</param>
    private void KeepKey(Node part, int? code, string how)
    {
        Cue(UiCue.Cancel);
        _events.Add(new RubyArray { part.Id, "kept", code is int key ? key : RubyNil.Value, how });
    }

    /// <summary>
    /// Tells the part that waits that a key is refused, with the buzzer.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="owner">Whose the key is: "game", "framework", "hotkey" or "chord" for a key held with another.</param>
    /// <param name="hotkey">The name of the hotkey that has the key, null for any other owner.</param>
    private void Refuse(Node part, int code, string owner, string? hotkey)
    {
        Cue(UiCue.Buzzer);
        _events.Add(new RubyArray { part.Id, "refused", code, owner, hotkey is null ? RubyNil.Value : (RubyValue)hotkey });
    }

    /// <summary>
    /// Ends the wait once the key that ended it is let go, and tells the part.
    /// </summary>
    /// <param name="part">The part.</param>
    private void EndCapture(Node part)
    {
        part.CaptureTaken = null;
        _capture = null;
        (_captureKey, _captureChord) = (0, false);
        Event(part.Id, "released");
    }
}
