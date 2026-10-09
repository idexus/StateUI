// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One handler written for an event, and what a repeat of the event does while it runs.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
struct Handler {
    let run: EventHandler
    let repeated: RepeatedEvent
}

/// A handler a walk found, with its word on a repeat and its runs; none for a farewell.
struct Fired {
    let run: EventHandler
    let repeated: RepeatedEvent
    let slot: RunSlot?
}
