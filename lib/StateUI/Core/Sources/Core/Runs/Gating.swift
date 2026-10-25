// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a handler that awaits passes through: a gate of its own, of a policy, or a gate it shares.
/// Design: docs/design/core/runs.md#a-gate
enum Gating: Sendable {
    /// A gate of the handler's own.
    case own(GatePolicy)

    /// A gate kept in a state, shared with every handler and task written with it.
    case shared(Gate)

    /// What an event does while a run is under way through the gate.
    var policy: GatePolicy {
        switch self {
        case .own(let policy): policy
        case .shared(let gate): gate.policy
        }
    }

    /// Where a run `owner` starts goes: the shared gate's runs, or the owner's own.
    @MainActor
    func runs(for owner: RunOwner) -> RunSlot {
        switch self {
        case .own: owner.ownRuns
        case .shared(let gate): gate.runs
        }
    }
}
