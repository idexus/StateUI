// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics;

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
    internal static long Held;

    /// <summary>The most they have ever held at once - what says a pool is bounded.</summary>
    internal static long HeldMost;

    /// <summary>How long every apply took together, in stopwatch ticks.</summary>
    internal static long Ticks;

    /// <summary>The longest single apply, in stopwatch ticks.</summary>
    internal static long Longest;

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

            return $"StateUI tally: applies {Applies}  nodes {Nodes}  " +
                $"made {Made}  kept {Kept}  " +
                $"adopted {Adopted}  pooled {Pooled}  missed {Missed}  " +
                $"held {Held}/{HeldMost}  " +
                $"apply {(Applies == 0 ? 0 : total / Applies):F2} ms avg / " +
                $"{Ms(Longest):F2} ms worst / {total:F0} ms total";
        }
    }
}
