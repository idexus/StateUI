// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Node {
    /// Hears one of this node's events that carries nothing beside any handler already there - what an element wearing no
    /// tier hears its events through; a view hears through `onEvent`. The handler runs whole inside the event.
    ///
    ///     node.addHandler(TrafficLightContract.closed) { shown = false }
    ///
    /// A payload that is not what the contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping @MainActor () throws -> Void
    ) {
        addHandler(event, gate: .none) { try handler() }
    }

    /// Hears one of this node's events with a handler that awaits; its `gate` says what the event does when it
    /// comes again while a run is under way.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - gate: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        gate: some Gate,
        _ handler: @escaping EventHandler
    ) {
        addHandler(event.token, gate: gate) {
            guard MemberValues.carried(EventBuffer.current, by: event.name) != nil else { return }

            try await handler()
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: node.addHandler(event, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public mutating func addHandler<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping EventHandler
    ) {
        fatalError("unavailable")
    }

    /// Hears one of this node's events its value handed over as the type its contract declares, beside any handler already there - what an element wearing no
    /// tier hears its events through; a view hears through `onEvent`. The handler runs whole inside the event.
    ///
    /// A payload that is not what the contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping @MainActor (Value) throws -> Void
    ) {
        addHandler(event, gate: .none) { (value) in try handler(value) }
    }

    /// Hears one of this node's events with a handler that awaits; its `gate` says what the event does when it
    /// comes again while a run is under way.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - gate: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<Value>
    ) {
        addHandler(event.token, gate: gate) {
            guard let value = MemberValues.carried(EventBuffer.current, by: event.name, as: Value.self) else { return }

            try await handler(value)
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: node.addHandler(event, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public mutating func addHandler<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping ValueEventHandler<Value>
    ) {
        fatalError("unavailable")
    }

    /// Hears one of this node's events that carries two values, handed over as the types its contract declares in its order, beside any handler already there - what an element wearing no
    /// tier hears its events through; a view hears through `onEvent`. The handler runs whole inside the event.
    ///
    /// A payload that is not what the contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping @MainActor (First, Second) throws -> Void
    ) {
        addHandler(event, gate: .none) { (first, second) in try handler(first, second) }
    }

    /// Hears one of this node's events with a handler that awaits; its `gate` says what the event does when it
    /// comes again while a run is under way.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - gate: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    public mutating func addHandler<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) {
        addHandler(event.token, gate: gate) {
            guard let (first, second) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self)
            else { return }

            try await handler(first, second)
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: node.addHandler(event, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public mutating func addHandler<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) {
        fatalError("unavailable")
    }

    /// Hears one of this node's events that carries three values, handed over as the types its contract declares in its order, beside any handler already there - what an element wearing no
    /// tier hears its events through; a view hears through `onEvent`. The handler runs whole inside the event.
    ///
    /// A payload that is not what the contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public mutating func addHandler<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @MainActor (First, Second, Third) throws -> Void
    ) {
        addHandler(event, gate: .none) { (first, second, third) in try handler(first, second, third) }
    }

    /// Hears one of this node's events with a handler that awaits; its `gate` says what the event does when it
    /// comes again while a run is under way.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - gate: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    public mutating func addHandler<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) {
        addHandler(event.token, gate: gate) {
            guard let (first, second, third) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: node.addHandler(event, gate: saving) { … } with @State var saving = SharedGate(.ignoreWhileRunning) - or gate: .none")
    public mutating func addHandler<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) {
        fatalError("unavailable")
    }
}
