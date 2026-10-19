// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One handler written for an event, and the gate it passes through.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
struct Handler {
    let run: EventHandler
    let gate: any Gate

    init(run: @escaping EventHandler, gate: any Gate) {
        self.run = run
        self.gate = gate
    }

    /// A step: a handler that does not await, which passes no gate.
    /// Design: docs/design/core/runs.md#a-step
    init(step: @escaping @MainActor () throws -> Void) {
        self.init(run: { try step() }, gate: GatePolicy.none)
    }
}

/// A handler a walk found, with its gate and who starts it; no owner for a farewell.
struct Fired {
    let run: EventHandler
    let gate: any Gate
    let owner: RunOwner?

    init(run: @escaping EventHandler, gate: any Gate, owner: RunOwner?) {
        self.run = run
        self.gate = gate
        self.owner = owner
    }

    /// A run that passes no gate: an element's arrival or farewell, which comes once.
    init(run: @escaping EventHandler, owner: RunOwner?) {
        self.init(run: run, gate: GatePolicy.none, owner: owner)
    }
}
