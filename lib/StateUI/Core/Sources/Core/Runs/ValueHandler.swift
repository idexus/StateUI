// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A handler for an event that hands it a value, and its gate: what a composed control keeps for an element it makes.
struct ValueHandler<Value> {
    let run: ValueEventHandler<Value>
    let gate: any Gate

    init(run: @escaping ValueEventHandler<Value>, gate: any Gate) {
        self.run = run
        self.gate = gate
    }

    /// A step: a handler that does not await, which passes no gate.
    /// Design: docs/design/core/runs.md#a-step
    init(step: @escaping @MainActor (Value) throws -> Void) {
        self.init(run: { try step($0) }, gate: GatePolicy.none)
    }
}
