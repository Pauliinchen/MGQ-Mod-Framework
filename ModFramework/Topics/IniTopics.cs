//----------------------------------------------------------------
//  IniTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Used the bridge and the runtime under the framework's namespace
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Runtime;

namespace MGQParadox.ModFramework.Topics;

/// <summary>
/// The topics that read and write key=value files, such as the framework's
/// <c>Patch\Mod_Framework\Mod_Framework.ini</c>, by paths relative to the game folder.
/// </summary>
internal static class IniTopics
{
    /// <summary>
    /// The topic that reads a file: [path] answers {key => value} in the file's order, empty for a
    /// missing file, nil for one that exists but could not be read.
    /// </summary>
    public const string ReadTopic = "ini.read";

    /// <summary>
    /// The topic that writes a file: [path, {key => value}] answers whether it was written.
    /// </summary>
    public const string WriteTopic = "ini.write";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        context.Register(ReadTopic, (_, request) => Read(PathOf(request, 1)));
        context.Register(WriteTopic, (_, request) => Write(PathOf(request, 2), request.AsArray()[1].AsHash()));
    }

    /// <summary>
    /// Reads a file.
    /// </summary>
    /// <param name="path">The path relative to the game folder.</param>
    /// <returns>{key => value} in the file's order, empty when it is missing; <see langword="null"/> when it could not be read.</returns>
    internal static RubyValue? Read(string path)
    {
        if (IniFile.Load(ModFolder.GamePathOf(path), path, false) is not { } values)
        {
            return null;
        }

        var reply = new RubyHash();
        foreach (var (key, value) in values)
        {
            reply.Add(key, value);
        }

        return reply;
    }

    /// <summary>
    /// Writes a file in one step, making its folder when it is missing.
    /// </summary>
    /// <remarks>
    /// A file that exists but cannot be read keeps what it holds, since writing over it would lose
    /// every value the player stored.
    /// </remarks>
    /// <param name="path">The path relative to the game folder.</param>
    /// <param name="values">{key => value}, both Strings.</param>
    /// <returns>Whether the file was written.</returns>
    /// <exception cref="RubyValueException">A key or a value is no text String.</exception>
    /// <exception cref="BridgeRequestException">A key would not read back as itself.</exception>
    internal static RubyValue Write(string path, RubyHash values)
    {
        var lines = new List<KeyValuePair<string, string>>();
        foreach (var (key, value) in values)
        {
            lines.Add(new KeyValuePair<string, string>(KeyOf(key), value.AsText()));
        }

        var full = ModFolder.GamePathOf(path);
        if (IniFile.Load(full, path, true) is null)
        {
            Log.Write($"did not write {path}: it exists but could not be read, so it keeps what it holds");
            return false;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        return IniFile.Write(full, path, lines);
    }

    /// <summary>
    /// Reads the path a request names first.
    /// </summary>
    /// <param name="request">The request, an Array.</param>
    /// <param name="count">How many entries the request has.</param>
    /// <returns>The path relative to the game folder.</returns>
    /// <exception cref="BridgeRequestException">The request has another shape or names no path.</exception>
    private static string PathOf(RubyValue request, int count)
    {
        var entries = request.AsArray();
        if (entries.Count != count)
        {
            throw new BridgeRequestException(count == 1 ? "A read is [path]." : "A write is [path, {key => value}].");
        }

        return entries[0].AsText() is { Length: > 0 } path ? path : throw new BridgeRequestException("The path is empty.");
    }

    /// <summary>
    /// Reads a key to write.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Its text.</returns>
    /// <exception cref="RubyValueException">The key is no text String.</exception>
    /// <exception cref="BridgeRequestException">The key is empty or holds "=" or a line break, so it would not read back as itself.</exception>
    private static string KeyOf(RubyValue key)
    {
        var text = key.AsText();
        return text.Length > 0 && text.IndexOfAny(['=', '\r', '\n']) < 0 ? text : throw new BridgeRequestException($"The key {text} is empty or holds = or a line break.");
    }
}
