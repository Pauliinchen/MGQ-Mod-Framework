//----------------------------------------------------------------
//  ExportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Read the exports from the DLL alone, which holds the bridge's
//                            - Expected the bridge's exports by their mf_ names
//      Paulinchen  2026-11-04: Shared the repository folder with the bridge tests
//      Paulinchen  2026-10-30: Added mf_start_android, the start on JoiPlay
//      Paulinchen  2026-10-28: Named the publish folder for the test of Version.txt
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Runtime.InteropServices;

namespace MGQParadox.ModFramework.Tests;

/// <summary>
/// Covers the functions ModFramework.dll exports, as the scripts load them through Win32API.
/// </summary>
public sealed class ExportsTests
{
    /// <summary>
    /// Every export with its arguments in Win32API notation, as the scripts load them (mf_start_android
    /// through DL on JoiPlay) and as dumpbin lists the published DLL's exports.
    /// </summary>
    private static readonly Dictionary<string, string> Table = new()
    {
        ["mf_start"] = "v",
        ["mf_start_android"] = "pp",
        ["mf_bridge_open"] = "lpl",
        ["mf_call"] = "lpplpl",
        ["mf_drain"] = "llpl",
        ["mf_reply"] = "lpl",
    };

    /// <summary>
    /// The offset of NumberOfNames in a PE export directory, which AddressOfFunctions,
    /// AddressOfNames and AddressOfNameOrdinals follow.
    /// </summary>
    private const int ExportHeaderNameCountOffset = 24;

    /// <summary>
    /// Asserts that the DLL exports exactly the functions of the table, each taking the
    /// arguments the table names, so none comes near the 16 arguments the game's Win32API loads.
    /// </summary>
    [Fact]
    public void Exports_AreThoseOfTheTable()
    {
        var exported = typeof(Exports).Assembly.GetTypes()
            .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static))
            .Select(method => (Method: method, EntryPoint: method.GetCustomAttribute<UnmanagedCallersOnlyAttribute>()?.EntryPoint))
            .Where(export => export.EntryPoint != null)
            .ToDictionary(export => export.EntryPoint!, export => Notation(export.Method));

        Assert.Equal(Table.OrderBy(entry => entry.Key), exported.OrderBy(entry => entry.Key));
        Assert.All(exported.Values, arguments => Assert.True(arguments.Length <= 6));
    }

    /// <summary>
    /// Asserts that the published DLL's export table names exactly the functions of the table.
    /// </summary>
    [Fact]
    public void PublishedDll_ExportsTheFunctionsOfTheTable()
    {
        var dll = Path.Combine(PublishFolder(), "ModFramework.dll");
        Assert.True(File.Exists(dll), $"{dll} is missing: publish ModFramework before running these tests.");

        Assert.Equal(Table.Keys.Order(), ExportedFunctions(dll).Order());
    }

    /// <summary>
    /// Finds the folder the publish of ModFramework writes into.
    /// </summary>
    /// <returns>The folder.</returns>
    internal static string PublishFolder() =>
        Path.Combine(RepositoryRoot(), "ModFramework", "bin", "Release", "net10.0", "win-x86", "publish");

    /// <summary>
    /// Finds the repository's folder above the tests' output folder.
    /// </summary>
    /// <returns>The folder that holds MGQ-Mod-Framework.slnx.</returns>
    internal static string RepositoryRoot()
    {
        var folder = new DirectoryInfo(AppContext.BaseDirectory);
        while (!File.Exists(Path.Combine(folder.FullName, "MGQ-Mod-Framework.slnx")))
        {
            folder = folder.Parent ?? throw new DirectoryNotFoundException("The tests do not run below the repository.");
        }

        return folder.FullName;
    }

    /// <summary>
    /// Reads the names of the functions a native DLL exports.
    /// </summary>
    /// <remarks>
    /// Data exports such as NativeAOT's DotNetRuntimeDebugHeader are left out by their section, which
    /// holds no code.
    /// </remarks>
    /// <param name="dll">The DLL's path.</param>
    /// <returns>The names of the exports whose address lies in an executable section.</returns>
    private static List<string> ExportedFunctions(string dll)
    {
        using var pe = new PEReader(File.OpenRead(dll));
        var directory = pe.PEHeaders.PEHeader!.ExportTableDirectory;
        var header = pe.GetSectionData(directory.RelativeVirtualAddress).GetReader();
        header.Offset = ExportHeaderNameCountOffset;
        var nameCount = header.ReadInt32();
        var functions = pe.GetSectionData(header.ReadInt32()).GetReader();
        var names = pe.GetSectionData(header.ReadInt32()).GetReader();
        var ordinals = pe.GetSectionData(header.ReadInt32()).GetReader();

        var exported = new List<string>();
        for (var i = 0; i < nameCount; i++)
        {
            var nameReader = pe.GetSectionData(names.ReadInt32()).GetReader();
            var name = nameReader.ReadUTF8(nameReader.IndexOf(0));
            functions.Offset = ordinals.ReadUInt16() * sizeof(int);
            if (IsCode(pe, functions.ReadInt32()))
            {
                exported.Add(name);
            }
        }

        return exported;
    }

    /// <summary>
    /// Tells whether an address of a DLL lies in one of its executable sections.
    /// </summary>
    /// <param name="pe">The DLL.</param>
    /// <param name="rva">The relative virtual address.</param>
    /// <returns>True when the section holding the address may run.</returns>
    private static bool IsCode(PEReader pe, int rva) =>
        pe.PEHeaders.SectionHeaders.Any(section =>
            rva >= section.VirtualAddress && rva < section.VirtualAddress + section.VirtualSize
            && section.SectionCharacteristics.HasFlag(SectionCharacteristics.MemExecute));

    /// <summary>
    /// Writes a method's arguments in Win32API notation.
    /// </summary>
    /// <param name="method">The method.</param>
    /// <returns>"l" for each int, "p" for each pointer, "v" for none, "?" for anything else.</returns>
    private static string Notation(MethodInfo method)
    {
        var letters = string.Concat(method.GetParameters().Select(parameter => parameter.ParameterType == typeof(int) ? 'l' : parameter.ParameterType.IsPointer ? 'p' : '?'));
        return letters.Length == 0 ? "v" : letters;
    }
}
