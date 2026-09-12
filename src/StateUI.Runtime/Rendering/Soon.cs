// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Work put off by one turn, that still happens while a window is being
/// dragged.
/// </summary>
/// <remarks>
/// <para>
/// A frame report must not be delivered inside the layout pass that raised it,
/// so it waits a turn - and on Apple a DRAGGED WINDOW DRAINS NO DISPATCHER:
/// macOS tracks a resize in a run loop mode that runs no queued work at all,
/// so that turn does not come round until the hand stops. Measured on the
/// gallery as ONE render for a 1.5 second drag, with the tree still reporting
/// the room it had before and the content drawn at its old width until the
/// mouse came up.
/// </para>
/// <para>
/// A perform on the main run loop in its COMMON modes runs in the tracking
/// mode too, which is the same reason the frame clock adds itself there. It is
/// still a turn later - the pass that raised the report unwinds first - so the
/// deferral that ended the resize hang is untouched.
/// </para>
/// </remarks>
internal static class Soon
{
    /// <summary>Runs work after the current pass, wherever the platform is.</summary>
    /// <param name="view">The view whose dispatcher answers where there is no run loop to ask.</param>
    /// <param name="work">What to run.</param>
    internal static void Run(VisualElement view, Action work)
    {
#if IOS || MACCATALYST
        Foundation.NSRunLoop.Main.Perform([Foundation.NSRunLoopMode.Common], work);
#else
        view.Dispatcher.Dispatch(work);
#endif
    }
}
