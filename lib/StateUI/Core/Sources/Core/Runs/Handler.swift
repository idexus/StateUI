// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One handler written for an event, and the gate it passes through.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
struct Handler {
    let run: EventHandler
    let gate: any Gate
}

/// A handler a walk found, with its gate and who starts it; no owner for a farewell.
struct Fired {
    let run: EventHandler
    let gate: any Gate
    let owner: RunOwner?
}
