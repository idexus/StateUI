// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an event does when it comes again while a run of its handler is still under way - said by every handler
/// that awaits, where the event can come again.
///
///     Button("Save").onClicked(.ignoreWhileRunning) {
///         try await save()
///     }
///
/// A handler with no `await` finishes inside its event and says nothing. A run a later event or its element
/// leaving supersedes changes nothing from then on: its task is cancelled, and its writes, posts and acts are
/// refused.
public enum RepeatedEvent: Sendable {
    /// The event is let go while a run is under way - a save, an order, a sign-in.
    case ignoreWhileRunning

    /// The run under way is cancelled and this one starts - a search, a movement to a new place.
    case cancelPrevious

    /// This one runs after the runs under way and waiting, in the order the events came.
    case waitForPrevious

    /// Each event its own run beside the others - when runs do not touch each other's state.
    case overlap
}
