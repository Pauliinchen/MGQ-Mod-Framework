//----------------------------------------------------------------
//  Threads.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Caught whatever a thread's work lets through, so it never ends the game
//                            - Told a caller when its thread cannot start, and gave the threads a smaller stack
//      Paulinchen  2026-11-07: Moved into the framework's project
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-07: Said once why every thread's work catches everything
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;

namespace MGQParadox.ModFramework.Runtime;

/// <summary>
/// The DLL's background threads, which work while the game runs on.
/// </summary>
public static class Threads
{
    /// <summary>
    /// The bytes of address space each thread reserves for its stack.
    /// </summary>
    /// <remarks>The game has only 2 to 4 GB of address space, and these threads need little stack.</remarks>
    private const int StackBytes = 512 * 1024;

    /// <summary>
    /// Runs work on a background thread, which ends with the game; an error the work lets through
    /// ends only the thread and goes to the log.
    /// </summary>
    /// <remarks>
    /// An exception escaping a thread would end the whole game. Only the log's writer starts its
    /// thread here, since <see cref="TryStart"/> writes to the log.
    /// </remarks>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work to run.</param>
    /// <exception cref="OutOfMemoryException">No stack could be reserved for the thread.</exception>
    public static void Start(string name, Action work) =>
        new Thread(() => Run(name, work), StackBytes) { IsBackground = true, Name = name }.Start();

    /// <summary>
    /// Runs work on a background thread as <see cref="Start"/> does, and logs it when the thread
    /// cannot start, such as when no stack can be reserved for it.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work to run.</param>
    /// <returns>Whether the thread started; when not, the work does not run.</returns>
    public static bool TryStart(string name, Action work)
    {
        try
        {
            Start(name, work);
            return true;
        }
        catch (Exception ex)
        {
            Log.Write($"could not start the thread {name}, so its work does not run: {ex.GetType().Name}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Runs a thread's work, catching whatever it lets through.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work to run.</param>
    internal static void Run(string name, Action work)
    {
        try
        {
            work();
        }
        catch (Exception ex)
        {
            try
            {
                Log.Write($"the thread {name} ended on an error, and the game runs on: {ex}");
            }
            catch
            {
                // Memory may have run out, and the line needs some.
            }
        }
    }
}
