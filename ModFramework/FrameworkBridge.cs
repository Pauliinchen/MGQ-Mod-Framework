//----------------------------------------------------------------
//  FrameworkBridge.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Noted an error while installing the bridge before building its log line
//                            - Registered the topic that lets the game's program use up to 4 GB
//                            - Registered the topics of the game's memory
//                            - Kept an error while installing the bridge from ending the game
//                            - Registered the topic that plans how a picture scales
//      Paulinchen  2026-11-07: Judged the keys of the options by the keys F1 binds now
//                            - Registered the topic that finds a part in a text
//                            - Registered the topic that matches a typed text against words
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Removed the topic of the garbage collector, which nothing asked
//                            - Left the log name to the log
//      Paulinchen  2026-11-06: Removed the registration of the old confirm model
//      Paulinchen  2026-11-05: Registered the topic of what the DLL's own garbage collector holds
//                            - Registered the toasts of the notice stack, timed while the game is in front
//      Paulinchen  2026-11-04: Registered the topics of the interface looks
//      Paulinchen  2026-10-31: Handed the tree the text box being typed into
//                            - Registered the markers' geometry
//      Paulinchen  2026-10-30: Took the input and the typing from the scripts on JoiPlay
//                            - Registered the topics of the Mod Config rows
//                            - Registered the topics of the mod management
//      Paulinchen  2026-10-29: Registered the confirm box and the wheels
//      Paulinchen  2026-10-28: Registered the tree of the components
//                            - Registered the layout of the boxes the player arranges
//                            - Registered the fonts and the text box being typed into
//                            - Registered the frame's tick with the input model
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using System.Runtime.CompilerServices;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Runtime;
using MGQParadox.ModFramework.Topics;
using MGQParadox.ModFramework.Ui;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Markers;
using MGQParadox.ModFramework.Ui.Notices;
using MGQParadox.ModFramework.Ui.Pictures;
using MGQParadox.ModFramework.Ui.Text;
using MGQParadox.ModFramework.Ui.Tree;
using MGQParadox.ModFramework.Ui.Wheels;
using MGQParadox.ModFramework.Windows;

namespace MGQParadox.ModFramework;

/// <summary>
/// The DLL's side of the bridge to the framework's scripts: the host the four bridge exports call,
/// with the framework's log and topics.
/// </summary>
internal static class FrameworkBridge
{
    /// <summary>
    /// Gets the build the handshake names, the DLL's version, such as "0.1.0" or "0.1.0-dev".
    /// </summary>
    public static string Build { get; } = typeof(FrameworkBridge).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "unknown";

    /// <summary>
    /// Installs the host before the scripts first call an export.
    /// </summary>
    [ModuleInitializer]
    [SuppressMessage("Usage", "CA2255:The 'ModuleInitializer' attribute should not be used in libraries", Justification = "The DLL is the application: NativeAOT runs it as the runtime starts, before any export runs.")]
    internal static void Install()
    {
        try
        {
            BridgeExports.Install(new BridgeHost(Build, new FileLog(), RegisterTopics));
        }
        catch (Exception ex)
        {
            // An error here would end the game as it loads the DLL; without a host the scripts stay
            // off. Building the line needs memory, which may be what ran out.
            ExportFaults.Note("the bridge's install", ex);

            try
            {
                Log.Write($"the bridge could not start: {ex}");
            }
            catch
            {
            }
        }
    }

    /// <summary>
    /// Registers the framework's topics and the frame's tick with its models on a new context; the
    /// wheels join as the scripts define them.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    internal static void RegisterTopics(BridgeContext context)
    {
        ScriptLog.Register(context);
        IniTopics.Register(context);
        ClipboardTopics.Register(context);
        TextTopics.Register(context);
        WindowTopics.Register(context);
        MemoryTopics.Register(context);
        GameExeTopics.Register(context);
        ModsTopics.Register(context);
        ThemeTopics.Register(context);
        var host = new UiHost(context);
        var scripted = Platforms.Current == GamePlatform.JoiPlay ? new ScriptInput() : null;
        var input = new InputModel(host, scripted ?? (IInputSource)new WindowsInput());
        host.Add(input);
        OptionsTopics.Register(context, () => input.Assignment);
        var layout = new LayoutModel(host, input);
        var text = new UiText(host);
        host.Add(layout);
        var edit = new EditModel(host, text, scripted ?? (ITypedText)new TypedText());
        host.Add(edit);
        host.Add(new ComponentTree(host, input, layout, text, edit));
        WheelModel.RegisterTopics(host, input);
        MarkerModel.Register(context);
        PictureScale.Register(context);
        NoticeQueue.Register(host, () => input.Front);
    }

    /// <summary>
    /// Hands the text box being typed into what the player types into the game's window.
    /// </summary>
    private sealed class TypedText : ITypedText
    {
        /// <inheritdoc />
        public void SetActive(bool on) => Keyboard.SetActive(on);

        /// <inheritdoc />
        public (string Text, int Keys) Take() => Keyboard.Take();
    }

    /// <summary>
    /// Writes the bridge's lines into the framework's log.
    /// </summary>
    private sealed class FileLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line) => Log.Write(line);
    }
}
