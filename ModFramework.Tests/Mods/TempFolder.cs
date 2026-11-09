//----------------------------------------------------------------
//  TempFolder.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.IO;

namespace MGQParadox.ModFramework.Tests.Mods;

/// <summary>
/// A game folder of a test's own below the temporary folder, deleted with everything in it once disposed.
/// </summary>
internal sealed class TempFolder : IDisposable
{
    /// <summary>
    /// The folder's full path.
    /// </summary>
    public string Path { get; } = Directory.CreateTempSubdirectory("mgqmf-test-").FullName;

    /// <summary>
    /// Writes a file into the folder, making the folders it lies in.
    /// </summary>
    /// <param name="relative">Its path relative to the folder.</param>
    /// <param name="bytes">Its bytes.</param>
    public void Put(string relative, byte[] bytes)
    {
        var full = System.IO.Path.Combine(Path, relative);
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(full)!);
        File.WriteAllBytes(full, bytes);
    }

    /// <summary>
    /// Tells whether a file or a folder exists in the folder.
    /// </summary>
    /// <param name="relative">Its path relative to the folder.</param>
    /// <returns>Whether it does.</returns>
    public bool Has(string relative)
    {
        var full = System.IO.Path.Combine(Path, relative);
        return File.Exists(full) || Directory.Exists(full);
    }

    /// <summary>
    /// Reads a file of the folder.
    /// </summary>
    /// <param name="relative">Its path relative to the folder.</param>
    /// <returns>Its bytes.</returns>
    public byte[] Read(string relative) => File.ReadAllBytes(System.IO.Path.Combine(Path, relative));

    /// <inheritdoc />
    public void Dispose()
    {
        try
        {
            Directory.Delete(Path, recursive: true);
        }
        catch (IOException)
        {
            // A file still open elsewhere keeps the folder; a leftover temporary folder must not fail
            // the test.
        }
    }
}
