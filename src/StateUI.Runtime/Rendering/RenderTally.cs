// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics;
using StateUI.Runtime.Interop;

namespace StateUI.Runtime;

/// <summary>
/// What applying the interface actually costs, counted rather than assumed.
/// </summary>
/// <remarks>
/// <para>
/// Off unless <c>STATEUI_TALLY</c> is set in the environment, and when it is
/// off every counter here is a static field nobody writes and the check that
/// guards it is a read of a readonly bool. It exists because the one question
/// this renderer keeps being asked - is a control being BUILT or KEPT, and
/// what does that cost - can only be answered on a real platform, where a
/// control is a native view and a test host has none.
/// </para>
/// <para>
/// The totals are CUMULATIVE and a line is printed at most once a second, both
/// deliberately. Printing per apply was measured to move the very timing being
/// measured; cumulative totals mean a run is read as the difference between
/// the line before it and the line after, so nothing has to be reset from
/// anywhere.
/// </para>
/// <para>
/// <c>Console.Error</c> is the stream, being the one that arrives unbuffered on
/// every platform this runs on.
/// </para>
/// </remarks>
internal static class RenderTally
{
    /// <summary>Whether anything here is counted at all.</summary>
    internal static readonly bool Watching =
        !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("STATEUI_TALLY"));

    /// <summary>Messages applied.</summary>
    internal static long Applies;

    /// <summary>Nodes walked across all of them.</summary>
    internal static long Nodes;

    /// <summary>Controls that had to be BUILT - the expensive answer.</summary>
    internal static long Made;

    /// <summary>Controls the message found already standing where it describes them.</summary>
    internal static long Kept;

    /// <summary>Controls taken out of a parent's pool and re-stamped.</summary>
    internal static long Adopted;

    /// <summary>Controls put INTO a pool as their row left the described window.</summary>
    internal static long Pooled;

    /// <summary>Rows a pool was asked for and had no matching shape to answer with.</summary>
    internal static long Missed;

    /// <summary>How many controls every pool is holding between them, right now.</summary>
    /// <remarks>
    /// COUNTED when it is asked for, never tracked: a pool goes when the layout
    /// it hangs off goes - which is what a list emptied, refilled or turned
    /// does to it - and a running total would never get those back, so the one
    /// number a reader watches to answer "is the pool growing" would only ever
    /// climb. Answers nothing until the renderer has made a pool.
    /// </remarks>
    internal static long Held => Holding?.Invoke() ?? 0;

    /// <summary>
    /// What counts the pools that are still alive - set by the renderer, which
    /// is what owns them.
    /// </summary>
    internal static Func<long>? Holding;

    /// <summary>The most they have ever held at once - what says a pool is bounded.</summary>
    internal static long HeldMost;

    /// <summary>How long every apply took together, in stopwatch ticks.</summary>
    internal static long Ticks;

    /// <summary>How long Swift spent describing the interface, in ticks.</summary>
    /// <remarks>
    /// The other two thirds of what a change costs, and invisible from the
    /// apply alone: a report that renders spends time in the DIFFER before a
    /// single byte reaches this side, and time again reading those bytes.
    /// Three numbers is what tells "the tree is too big" from "the controls
    /// are too expensive".
    /// </remarks>
    internal static long Described;

    /// <summary>How long reading the message off the native buffer took, in ticks.</summary>
    internal static long ReadTicks;

    /// <summary>The longest single apply, in stopwatch ticks.</summary>
    internal static long Longest;

    /// <summary>Times one call and adds it to a counter.</summary>
    /// <typeparam name="T">What the call answers.</typeparam>
    /// <param name="counter">The total to add to.</param>
    /// <param name="call">The call to time.</param>
    /// <returns>Whatever the call answered.</returns>
    internal static T Time<T>(ref long counter, Func<T> call)
    {
        if (!Watching)
        {
            return call();
        }

        long began = Stopwatch.GetTimestamp();

        try
        {
            return call();
        }
        finally
        {
            counter += Stopwatch.GetTimestamp() - began;
        }
    }

    private static long _printedAt;

    /// <summary>
    /// Times one whole message and prints the running totals once a second.
    /// </summary>
    /// <param name="apply">Applying the message.</param>
    /// <returns>Whatever the apply answered.</returns>
    internal static bool Measure(Func<bool> apply)
    {
        if (!Watching)
        {
            return apply();
        }

        long began = Stopwatch.GetTimestamp();

        try
        {
            return apply();
        }
        finally
        {
            long took = Stopwatch.GetTimestamp() - began;

            Applies++;
            Ticks += took;
            Longest = Math.Max(Longest, took);

            if (began - _printedAt >= Stopwatch.Frequency)
            {
                _printedAt = began;
                Console.Error.WriteLine(Line);
            }
        }
    }

    /// <summary>The running totals, as one line.</summary>
    internal static string Line
    {
        get
        {
            double Ms(long ticks) => ticks * 1000.0 / Stopwatch.Frequency;

            double total = Ms(Ticks);

            // Asked of the Swift side, which is the one that knows whether a
            // message had anything in it. Answered as a dash where there is
            // no Swift side to ask - the headless tests.
            string renders;

            try
            {
                int made = NativeMethods.Renders(out int empty, out int refused);
                renders = $"renders {made}  empty {empty}  refused {refused}  ";
            }
            catch (DllNotFoundException)
            {
                renders = "renders -  empty -  refused -  ";
            }
            catch (EntryPointNotFoundException)
            {
                renders = "renders -  empty -  refused -  ";
            }

            return $"StateUI tally: applies {Applies}  nodes {Nodes}  " + renders +
                $"made {Made}  kept {Kept}  " +
                $"adopted {Adopted}  pooled {Pooled}  missed {Missed}  " +
                $"held {Held}/{HeldMost}  " +
                $"described {(Applies == 0 ? 0 : Ms(Described) / Applies):F2} + " +
                $"read {(Applies == 0 ? 0 : Ms(ReadTicks) / Applies):F2} + " +
                $"apply {(Applies == 0 ? 0 : total / Applies):F2} ms avg / " +
                $"{Ms(Longest):F2} ms worst apply / " +
                $"{Ms(Described) + Ms(ReadTicks) + total:F0} ms total";
        }
    }
}
