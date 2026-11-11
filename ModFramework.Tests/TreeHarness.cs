//----------------------------------------------------------------
//  TreeHarness.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Tapped a key whose key message comes while the key poll misses it
//                            - Handed the text box the input model and ran it in a frame's tick with what it posted
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-11-04: Added the text box on a keyboard, the layout's offers, held and repeated buttons, a key held
//                              for a frame, several properties set at once, measured sizes, the focus of a report, a font
//                              and hotkeys for the flow tests
//                            - Pressed a game button with a key for one frame, and put the game's extra buttons into a tick
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Text;
using MGQParadox.ModFramework.Ui.Tree;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// The component tree with the input model and the layout on a test's bridge, run tick by tick as
/// the scripts run it, with the writers of its input and the readers of its report.
/// </summary>
internal sealed class TreeHarness
{
    /// <summary>
    /// Windows' code of the left mouse button.
    /// </summary>
    public const int LeftButton = 0x01;

    /// <summary>
    /// Adds the input model, the layout and the tree to a host on a new bridge, and the text box
    /// when a keyboard types into it.
    /// </summary>
    /// <param name="keyboard">What the player types into the text box, null for no text box.</param>
    public TreeHarness(ITypedText? keyboard = null)
    {
        var host = new UiHost(Ui.Context);
        var input = new InputModel(host, Input);
        var layout = new LayoutModel(host, input);
        var text = new UiText(host);
        host.Add(input);
        host.Add(layout);
        EditModel? edit = null;
        if (keyboard is not null)
        {
            edit = new EditModel(host, text, keyboard, input);
            host.Add(edit);
        }

        host.Add(new ComponentTree(host, input, layout, text, edit));
    }

    /// <summary>
    /// Gets the bridge the models post on.
    /// </summary>
    public UiContext Ui { get; } = new();

    /// <summary>
    /// Gets the text box's event of the last frame that ran it, null when it posted none.
    /// </summary>
    public RubyHash? Edited { get; private set; }

    /// <summary>
    /// Gets what the input model reads.
    /// </summary>
    public FakeInput Input { get; } = new() { Pointer = null };

    /// <summary>
    /// Writes a component as the tick's "add" names it.
    /// </summary>
    /// <param name="id">Its id.</param>
    /// <param name="parent">Its parent's id, null for a root.</param>
    /// <param name="kind">Its kind.</param>
    /// <param name="props">Its properties, as names and values.</param>
    /// <returns>[id, parent, kind, index, props].</returns>
    public static RubyArray Node(int id, int? parent, string kind, params (string Name, RubyValue Value)[] props)
    {
        var hash = new RubyHash();
        foreach ((string name, RubyValue value) in props)
        {
            hash[name] = value;
        }

        return [id, parent is int known ? known : RubyNil.Value, kind, RubyNil.Value, hash];
    }

    /// <summary>
    /// Writes the tick's input that adds components.
    /// </summary>
    /// <param name="nodes">The components.</param>
    /// <returns>The input.</returns>
    public static RubyHash Adds(params RubyArray[] nodes) => new() { { "add", new RubyArray(nodes) } };

    /// <summary>
    /// Writes the tick's input that sets one property of a component.
    /// </summary>
    /// <param name="id">The component.</param>
    /// <param name="name">The property.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The input.</returns>
    public static RubyHash Set(int id, string name, RubyValue value) =>
        new() { { "set", new RubyArray { new RubyArray { id, new RubyHash { { name, value } } } } } };

    /// <summary>
    /// Writes the tick's input that sets several properties of a component.
    /// </summary>
    /// <param name="id">The component.</param>
    /// <param name="props">The properties, as names and values.</param>
    /// <returns>The input.</returns>
    public static RubyHash Set(int id, params (string Name, RubyValue Value)[] props)
    {
        var hash = new RubyHash();
        foreach ((string name, RubyValue value) in props)
        {
            hash[name] = value;
        }

        return new RubyHash { { "set", new RubyArray { new RubyArray { id, hash } } } };
    }

    /// <summary>
    /// Writes the size the scripts measured for a component, as a property.
    /// </summary>
    /// <param name="width">The width measured.</param>
    /// <param name="height">The height measured.</param>
    /// <returns>The property.</returns>
    public static (string Name, RubyValue Value) Measured(int width, int height) => ("measured", Pair(width, height));

    /// <summary>
    /// Writes a pair of numbers.
    /// </summary>
    /// <param name="first">The first.</param>
    /// <param name="second">The second.</param>
    /// <returns>[first, second].</returns>
    public static RubyArray Pair(int first, int second) => [first, second];

    /// <summary>
    /// Writes a game button's bit for one that went down.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>The bit.</returns>
    public static int Triggered(UiButton button) => 1 << (int)button;

    /// <summary>
    /// Writes a game button's bit for one that went down or repeats.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>The bit.</returns>
    public static int Repeated(UiButton button) => 1 << (UiButtons.Count + (int)button);

    /// <summary>
    /// Writes a game button's bit for one held.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>The bit.</returns>
    public static int Held(UiButton button) => 1 << ((2 * UiButtons.Count) + (int)button);

    /// <summary>
    /// Writes the tick's input that defines hotkeys, each on every scene.
    /// </summary>
    /// <param name="hotkeys">Each hotkey's name and Windows' code of its key.</param>
    /// <returns>The input.</returns>
    public static RubyHash Hotkeys(params (string Name, int Code)[] hotkeys)
    {
        var map = new RubyHash();
        foreach ((string name, int code) in hotkeys)
        {
            map[name] = new RubyArray { code, RubyNil.Value };
        }

        return new RubyHash { { "hotkeys", map } };
    }

    /// <summary>
    /// Reads which component a report gave the focus to last.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <returns>The component, null when the focus stayed.</returns>
    public static int? Focus(RubyHash report)
    {
        string? focus = Events(report).LastOrDefault(text => text.EndsWith(" focus", System.StringComparison.Ordinal));
        return focus is null ? null : int.Parse(focus.Split(' ')[0], System.Globalization.CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Reads a report's events as text, such as "2 close outside".
    /// </summary>
    /// <param name="report">The report.</param>
    /// <returns>The events.</returns>
    public static List<string> Events(RubyHash report) => report["events"].IsNil
        ? []
        : [.. report["events"].AsArray().Select(entry => $"{entry.AsArray()[0].AsInt()} {entry.AsArray()[1].AsText()}{string.Concat(entry.AsArray().Skip(2).Select(value => " " + (value is RubyString text ? text.Text : value.ToString())))}")];

    /// <summary>
    /// Reads a report's sounds.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <returns>The sounds.</returns>
    public static List<string> Cues(RubyHash report) => report["cues"].IsNil ? [] : [.. report["cues"].AsArray().Select(cue => cue.AsText())];

    /// <summary>
    /// Reads a component's place from a report.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <param name="id">The component.</param>
    /// <returns>[x, y, width, height].</returns>
    public static int[] Rect(RubyHash report, int id) => [.. report["rects"].AsHash()[id].AsArray().Select(value => value.AsInt())];

    /// <summary>
    /// Defines font 1, in which every small letter and the space are ten pixels wide.
    /// </summary>
    public void DefineFont()
    {
        var widths = new RubyHash();
        foreach (char point in "abcdefghijklmnopqrstuvwxyz ")
        {
            widths.Add(point, 10);
        }

        Ui.Value(UiText.GlyphsTopic, new RubyHash { { "key", 1 }, { "name", "VL Gothic" }, { "size", 20 }, { "bold", false }, { "widths", widths } });
    }

    /// <summary>
    /// Puts the pointer on the game's screen, whose client area is the screen's size.
    /// </summary>
    /// <param name="x">Its left.</param>
    /// <param name="y">Its top.</param>
    public void Point(int x, int y) => Input.Pointer = new ClientPointer(x, y, 640, 480);

    /// <summary>
    /// Clicks the left button where the pointer is: one frame down, one frame up.
    /// </summary>
    /// <returns>The reports of both frames, merged: the events and sounds of both.</returns>
    public RubyHash Click()
    {
        Input.Down.Add(LeftButton);
        RubyHash down = Frame();
        Input.Down.Remove(LeftButton);
        RubyHash up = Frame();
        var merged = new RubyHash();
        foreach (string part in new[] { "events", "cues" })
        {
            var all = new RubyArray();
            foreach (RubyHash report in new[] { down, up })
            {
                if (!report[part].IsNil)
                {
                    foreach (RubyValue item in report[part].AsArray())
                    {
                        all.Add(item);
                    }
                }
            }

            merged[part] = all;
        }

        return merged;
    }

    /// <summary>
    /// Presses a game button with a key in one frame and lets both go in the next.
    /// </summary>
    /// <param name="button">The game's button, null for none.</param>
    /// <param name="key">Windows' code of a key that goes down with it, null for none.</param>
    /// <returns>The report of the frame they went down in.</returns>
    public RubyHash Press(UiButton? button = null, int? key = null)
    {
        if (key is int code)
        {
            Input.Down.Add(code);
        }

        RubyHash report = Frame(buttons: button is UiButton pressed ? Triggered(pressed) | Repeated(pressed) : 0);
        Input.Down.Clear();
        Frame();
        return report;
    }

    /// <summary>
    /// Holds a key for one frame with the game's buttons it brings, and lets only it go in the next.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="buttons">The game's buttons of the frame, as bits.</param>
    /// <returns>The report of the frame it went down in.</returns>
    public RubyHash Key(int code, int buttons = 0)
    {
        Input.Down.Add(code);
        RubyHash report = Frame(buttons: buttons);
        Input.Down.Remove(code);
        Frame();
        return report;
    }

    /// <summary>
    /// Taps a key so briefly that the key poll misses it while its key message comes, with the game's
    /// buttons it brings, and runs the next frame with nothing pressed.
    /// </summary>
    /// <param name="code">Windows' code of the key.</param>
    /// <param name="buttons">The game's buttons of the frame, as bits.</param>
    /// <returns>The report of the frame it went down in.</returns>
    public RubyHash Tap(int code, int buttons = 0)
    {
        Input.Presses.Note(code);
        RubyHash report = Frame(buttons: buttons);
        Frame();
        return report;
    }

    /// <summary>
    /// Runs a frame in which a game button repeats, as a held arrow does, without going down.
    /// </summary>
    /// <param name="button">The button.</param>
    /// <returns>The tree's event, empty when it posted none.</returns>
    public RubyHash Repeat(UiButton button) => Frame(buttons: Repeated(button));

    /// <summary>
    /// Runs a frame's tick as the scripts do, the input model and the layout before the text box
    /// and the tree.
    /// </summary>
    /// <param name="tree">The tree's input, null for none.</param>
    /// <param name="buttons">The game's buttons.</param>
    /// <param name="extra">The game's extra buttons.</param>
    /// <param name="offers">The boxes offered to the layout, each [id, x, y, width, height, depth], null for none.</param>
    /// <param name="edit">The text box's input, see EditModel.Tick, null for none.</param>
    /// <returns>The tree's event, empty when it posted none.</returns>
    public RubyHash Frame(RubyHash? tree = null, int buttons = 0, int extra = 0, RubyArray? offers = null, RubyArray? edit = null)
    {
        var inputs = new RubyHash
        {
            { UiHost.ButtonsKey, buttons },
            { UiHost.ExtraButtonsKey, extra },
            { InputModel.ModelName, new RubyHash() },
            { LayoutModel.ModelName, offers ?? new RubyArray() },
        };
        if (edit is not null)
        {
            inputs.Add("edit", edit);
        }

        inputs.Add(ComponentTree.ModelName, tree ?? new RubyHash());
        Edited = null;
        RubyHash report = new();
        foreach ((string topic, RubyValue payload) in Ui.Tick(inputs))
        {
            if (topic == ComponentTree.EventTopic)
            {
                report = payload.AsHash();
            }
            else if (topic == EditModel.EventTopic)
            {
                Edited = payload.AsHash();
            }
        }

        return report;
    }
}
