//----------------------------------------------------------------
//  AndroidTls.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// Readies .NET's crypto and HTTPS inside JoiPlay, which runs a mod DLL's code built for Android:
/// .NET finds the engine's OpenSSL through the libssl stand-in, and OpenSSL finds Android's root
/// certificates.
/// </summary>
/// <remarks>
/// It must run before the first crypto or HTTPS call: without the stand-in loaded, .NET aborts the
/// game at that call, since Android lets an app load no libssl of the system's.
/// </remarks>
public static partial class AndroidTls
{
    /// <summary>
    /// OpenSSL's variable naming the folder of root certificates.
    /// </summary>
    public const string CertificateFolderVariable = "SSL_CERT_DIR";

    /// <summary>
    /// The folders of root certificates Android may have, the one its updates keep current first.
    /// </summary>
    public static readonly string[] CertificateFolders =
    [
        "/apex/com.android.conscrypt/cacerts",
        "/system/etc/security/cacerts",
    ];

    /// <summary>
    /// Loads the stand-in and points OpenSSL at Android's root certificates, unless the variable
    /// is set already.
    /// </summary>
    /// <remarks>
    /// The engine's OpenSSL looks for certificates in a folder of JoiPlay's build machine, so without
    /// the variable every HTTPS call fails.
    /// </remarks>
    /// <param name="standIn">The stand-in's full path, named libssl.so, in the app's own folder.</param>
    /// <returns>What was done, for the log.</returns>
    /// <exception cref="System.DllNotFoundException">The stand-in or the engine it needs cannot be loaded.</exception>
    public static string Ready(string standIn)
    {
        NativeLibrary.Load(standIn);
        if (GetEnv(CertificateFolderVariable) is { } set)
        {
            return $"loaded {standIn}; {CertificateFolderVariable} stays {set}";
        }

        if (CertificateFolders.FirstOrDefault(HoldsFiles) is not { } folder)
        {
            return $"loaded {standIn}; none of {string.Join(", ", CertificateFolders)} holds certificates, so HTTPS fails";
        }

        return SetEnv(CertificateFolderVariable, folder, 1) == 0
            ? $"loaded {standIn}; {CertificateFolderVariable} is {folder}"
            : $"loaded {standIn}; {CertificateFolderVariable} could not be set to {folder}, so HTTPS fails";
    }

    /// <summary>
    /// Tells whether a folder holds any file.
    /// </summary>
    /// <param name="folder">The folder.</param>
    /// <returns>Whether it does; false when it cannot be read.</returns>
    private static bool HoldsFiles(string folder)
    {
        try
        {
            return Directory.Exists(folder) && Directory.EnumerateFiles(folder).Any();
        }
        catch (IOException)
        {
            return false;
        }
        catch (System.UnauthorizedAccessException)
        {
            return false;
        }
    }

    /// <summary>
    /// Sets a variable in the C runtime's environment, which OpenSSL reads and .NET's own copy does
    /// not reach.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <param name="value">The value.</param>
    /// <param name="overwrite">Non-zero to replace a value set already.</param>
    /// <returns>Zero on success.</returns>
    [LibraryImport("libc", EntryPoint = "setenv", StringMarshalling = StringMarshalling.Utf8)]
    private static partial int SetEnv(string name, string value, int overwrite);

    /// <summary>
    /// Reads a variable of the C runtime's environment.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The value; <see langword="null"/> when it is not set.</returns>
    private static string? GetEnv(string name) => Marshal.PtrToStringUTF8(GetEnvPointer(name));

    /// <summary>
    /// Reads a variable of the C runtime's environment as the C runtime keeps it.
    /// </summary>
    /// <remarks>
    /// It returns the pointer, since a returned string would be freed, and the memory is the C runtime's own.
    /// </remarks>
    /// <param name="name">The name.</param>
    /// <returns>The value, zero when it is not set.</returns>
    [LibraryImport("libc", EntryPoint = "getenv", StringMarshalling = StringMarshalling.Utf8)]
    private static partial nint GetEnvPointer(string name);
}
