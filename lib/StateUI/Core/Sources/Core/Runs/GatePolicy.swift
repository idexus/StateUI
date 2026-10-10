// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an event that comes to a gate does while a run is under way through it: `.ignoreWhileRunning`,
/// `.cancelPrevious`, `.waitForPrevious` or `.none`. Given as a handler's gate, a policy is the handler's own gate.
/// Design: docs/design/core/runs.md#a-gate
public struct GatePolicy: Gate, Equatable {
    enum Kind {
        case ignoreWhileRunning, cancelPrevious, waitForPrevious, none
    }

    let kind: Kind

    /// The policy itself: a handler's own gate is its policy alone.
    public var policy: GatePolicy { self }
}

extension Gate where Self == GatePolicy {
    /// The event is let go while a run is under way - a save, an order, a sign-in. As a handler's gate, its own.
    ///
    ///     Button("Save").onClicked(gate: .ignoreWhileRunning) { try await model.save() }
    public static var ignoreWhileRunning: GatePolicy { GatePolicy(kind: .ignoreWhileRunning) }

    /// The run under way is cancelled and this one starts - a search, a movement to a new place.
    public static var cancelPrevious: GatePolicy { GatePolicy(kind: .cancelPrevious) }

    /// This one runs after the runs under way and waiting, in the order the events came.
    public static var waitForPrevious: GatePolicy { GatePolicy(kind: .waitForPrevious) }

    /// Nothing is held back: each event its own run beside the others - when runs do not touch each other's state.
    ///
    ///     TextField($query).onChanged(query, gate: .none) { try await model.log(query) }
    public static var none: GatePolicy { GatePolicy(kind: .none) }
}
