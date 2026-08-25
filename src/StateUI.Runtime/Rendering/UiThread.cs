// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Checks the one thing everything below this boundary assumes and nothing else
/// verifies: that the host entered Swift from the thread MAUI draws on.
/// </summary>
/// <remarks>
/// <para>
/// The Swift side has no lock of its own, on purpose - see
/// <c>Core/MainThread.swift</c>. Its safety comes entirely from being entered
/// from one thread, and MAUI is the authority on which thread that is. If that
/// ever stopped being true - a platform handler raising an event off the UI
/// thread, a dispatcher that does not do what it says - the result would not be
/// a crash. It would be a state write landing beside a render, occasionally,
/// with nothing anywhere to say so.
/// </para>
/// <para>
/// So it is checked, and said out loud once. Said once because a wrong thread is
/// a standing condition rather than an incident: repeating it every event would
/// bury the first report, which is the one worth reading.
/// </para>
/// <para>
/// Nothing is refused on a failed check. Rendering nothing would turn a
/// diagnosable problem into a blank interface, and the crossing is very probably
/// still going to work - it is only no longer guaranteed to.
/// </para>
/// </remarks>
internal sealed class UiThread
{
    /// <summary>Where a complaint goes.</summary>
    private readonly Action<string> _report;

    /// <summary>Whether it has already been said.</summary>
    private bool _reported;

    /// <summary>A check that reports through the given channel.</summary>
    /// <param name="report">Called at most once, with what went wrong.</param>
    internal UiThread(Action<string> report)
    {
        _report = report;
    }

    /// <summary>
    /// Whether the calling thread is the one MAUI draws on, complaining the first
    /// time it is not.
    /// </summary>
    /// <param name="dispatcher">
    /// MAUI's dispatcher for the target's thread, or null where there is no
    /// platform underneath - a test, which has one thread and nothing to compare
    /// it against. Null passes.
    /// </param>
    /// <param name="crossing">
    /// What was about to happen, named the way the reader would name it - "an
    /// event from MAUI", "a render". It goes in the message.
    /// </param>
    internal bool Verify(IDispatcher? dispatcher, string crossing)
    {
        if (dispatcher is null || !dispatcher.IsDispatchRequired)
        {
            return true;
        }

        if (!_reported)
        {
            _reported = true;

            _report(
                $"{crossing} arrived on a thread that is not the one MAUI draws on. "
                + "Everything the Swift side does assumes otherwise - it holds no lock, "
                + "because until now it never needed one - so state written from here can "
                + "be lost against a render rather than reported. Nothing was refused; "
                + "this is said once, and it is the only sign this failure gives.");
        }

        return false;
    }
}
