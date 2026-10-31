// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Anything carrying property values in the tree, and so able to hear
/// events - which a `Style`, carrying values only, never can.
public protocol ModifiableElement: PropertyContainer, Element where Modified: Element {}

extension ModifiableElement {
    /// Hears one of this element's events that carries nothing; the handler runs whole inside the event.
    ///
    ///     onEvent(TrafficLightContract.closed) { shown = false }
    ///
    /// Runs beside any handler already there. An event that arrives carrying
    /// anything is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping @MainActor () throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// Hears one of this element's events with a handler that awaits; its `policy`
    /// says what the event does when it comes again while a run is under way.
    ///
    ///     onEvent(TrafficLightContract.closed, policy: .ignoreWhileRunning) { try await save() }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: what runs.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        policy: GatePolicy,
        _ handler: @escaping EventHandler
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<Owner: Contract>(
        _ event: ElementEvent<Owner, Void>,
        gate: Gate,
        _ handler: @escaping EventHandler
    ) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }

    /// Hears one of this element's events, its value handed over as the type
    /// its contract declares; the handler runs whole inside the event.
    ///
    ///     func onLampTapped(_ handler: @escaping @MainActor (Int) throws -> Void) -> Self {
    ///         onEvent(TrafficLightContract.lampTapped, handler)
    ///     }
    ///
    /// Runs beside any handler already there. A payload that is not what the
    /// contract says is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the value.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping @MainActor (Value) throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// Hears one of this element's events with a handler that awaits; its `policy`
    /// says what the event does when it comes again while a run is under way.
    ///
    ///     onEvent(TrafficLightContract.lampTapped, policy: .ignoreWhileRunning) { lamp in try await save(lamp) }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: given the value.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<Owner: Contract, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }

    /// Hears one of this element's events that carries two values, handed
    /// over as the types its contract declares, in its order; the handler runs
    /// whole inside the event.
    ///
    ///     onEvent(GaugeContract.dimmed) { level, lit in … }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping @MainActor (First, Second) throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// Hears one of this element's events with a handler that awaits; its `policy`
    /// says what the event does when it comes again while a run is under way.
    ///
    ///     onEvent(GaugeContract.dimmed, policy: .cancelPrevious) { level, lit in try await show(level, lit) }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }

    /// Hears one of this element's events that carries three values, handed
    /// over as the types its contract declares, in its order; the handler runs
    /// whole inside the event.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @MainActor (First, Second, Third) throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// Hears one of this element's events with a handler that awaits; its `policy`
    /// says what the event does when it comes again while a run is under way.
    ///
    ///     onEvent(event, policy: .waitForPrevious) { first, second, third in try await keep(first, second, third) }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - policy: what the handler passes through: what an event does while a run is under way.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        modified { $0.addHandler(event, gate: gate, handler) }
    }

    /// Hears one of this element's events that carries four values, handed over as the types its contract
    /// declares in its order. The handler runs whole inside the event.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable,
        Fourth: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third, Fourth)>,
        _ handler: @escaping @MainActor (First, Second, Third, Fourth) throws -> Void
    ) -> Modified {
        modified { $0.addHandler(event, handler) }
    }

    /// The same, with a handler that awaits; its `policy` says what the event does when it comes again while a
    /// run is under way.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable,
        Fourth: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third, Fourth)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<First, Second, Third, Fourth>
    ) -> Modified {
        modified { $0.addHandler(event, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable,
        Fourth: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third, Fourth)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third, Fourth>
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
