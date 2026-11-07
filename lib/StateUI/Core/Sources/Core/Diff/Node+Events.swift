// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Node {
    /// Hears one of this node's events beside any handler already there, its values handed over as the types its
    /// contract declares, in its order - what an element wearing no tier hears its events through; a view hears
    /// through `onEvent`. The handler runs whole inside the event.
    ///
    ///     node.addHandler(TrafficLightContract.closed) { shown = false }
    ///     node.addHandler(TrafficLightContract.signalChanged) { signal in shown = signal == .go }
    ///
    /// A payload that is not what the contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ handler: @escaping @MainActor (repeat each Value) throws -> Void
    ) {
        Wearing.takes(declaration, event)
        addHandler(event.token) {
            guard let values = MemberValues.carried(EventBuffer.current, by: event.name, as: repeat (each Value).self)
            else { return }

            try handler(repeat each values)
        }
    }

    /// Hears one of this node's events with a handler that awaits; its `policy` says what the event does when it
    /// comes again while a run is under way.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) {
        Wearing.takes(declaration, event)
        addHandler(event.token, gate: .own(policy)) {
            guard let values = MemberValues.carried(EventBuffer.current, by: event.name, as: repeat (each Value).self)
            else { return }

            try await handler(repeat each values)
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public mutating func addHandler<Owner: WornContract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) {
        Wearing.takes(declaration, event)
        addHandler(event.token, gate: .shared(gate)) {
            guard let values = MemberValues.carried(EventBuffer.current, by: event.name, as: repeat (each Value).self)
            else { return }

            try await handler(repeat each values)
        }
    }
}
