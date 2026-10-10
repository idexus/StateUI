// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a handler that awaits passes through: what an event that comes while a run is under way does. A policy
/// given as the gate is the handler's own; a `SharedGate` kept in a state or a model is shared by every handler and
/// task written with it.
///
///     Button("Refresh").onClicked(gate: .ignoreWhileRunning) { try await model.refresh() }
///
///     @State private var document = SharedGate(.ignoreWhileRunning)
///
///     Button("Save").isEnabled(!document.isBusy).onClicked(gate: document) { try await model.save() }
///
/// A handler with no `await` finishes inside its event and names none.
/// Design: docs/design/core/runs.md#a-gate
public protocol Gate: Sendable {
    /// What an event does while a run is under way through the gate.
    var policy: GatePolicy { get }
}

extension Gate {
    /// Where a run `owner` starts goes: a shared gate's runs, or the owner's own where the gate is a policy alone.
    @MainActor
    func runs(for owner: RunOwner) -> RunSlot {
        (self as? SharedGate)?.runs ?? owner.ownRuns
    }
}
