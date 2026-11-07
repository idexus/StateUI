// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Anything carrying property values in the tree, and so able to hear
/// events - which a `Style`, carrying values only, never can.
public protocol ModifiableElement: PropertyContainer, Element where Modified: Element {}

extension ModifiableElement {
    /// Hears one of this element's events, its values handed over as the types its contract declares, in its
    /// order; the handler runs whole inside the event.
    ///
    ///     onEvent(TrafficLightContract.closed) { shown = false }
    ///     onEvent(TrafficLightContract.lampTapped) { lamp in tapped = lamp }
    ///
    /// Runs beside any handler already there. A payload that is not what the contract says is reported once and
    /// does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs, given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ handler: @escaping @MainActor (repeat each Value) throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// Hears one of this element's events with a handler that awaits; its `policy` says what the event does when it
    /// comes again while a run is under way.
    ///
    ///     onEvent(TrafficLightContract.closed, policy: .ignoreWhileRunning) { try await save() }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs, given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }

    /// Adds a handler beside any already there, by token - on this tier, so
    /// nothing reachable from a `Style` can put one in a bag of values.
    /// Design: docs/design/views/modifiers.md#a-handler-runs-beside-the-one-before
    func addHandler(_ event: Event, gate: Gating, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }
}
