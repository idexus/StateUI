// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Anything carrying property values in the tree, and so able to hear
/// events - which a `Style`, carrying values only, never can.
public protocol ModifiableElement: PropertyContainer, Element where Modified: Element {}

extension ModifiableElement {
    /// Hears one of this element's events that carries nothing.
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
        _ handler: @escaping EventHandler
    ) -> Modified {
        addHandler(event.token) {
            guard MemberValues.carried(EventBuffer.current, by: event.name) != nil else { return }

            try await handler()
        }
    }

    /// Hears one of this element's events, its value handed over as the type
    /// its contract declares.
    ///
    ///     func onLampTapped(_ handler: @escaping ValueEventHandler<Int>) -> Self {
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
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        addHandler(event.token) {
            guard let value = MemberValues.carried(EventBuffer.current, by: event.name, as: Value.self)
            else { return }

            try await handler(value)
        }
    }

    /// Hears one of this element's events that carries two values, handed
    /// over as the types its contract declares, in its order.
    ///
    ///     onEvent(GaugeContract.dimmed) { level, lit in … }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<Owner: Contract, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        addHandler(event.token) {
            guard let (first, second) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self)
            else { return }

            try await handler(first, second)
        }
    }

    /// Hears one of this element's events that carries three values, handed
    /// over as the types its contract declares, in its order.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the element, with the handler on it.
    public func onEvent<
        Owner: Contract, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        addHandler(event.token) {
            guard let (first, second, third) = MemberValues.carried(
                EventBuffer.current, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }
    }

    /// Adds a handler beside any already there, by token - on this tier, so
    /// nothing reachable from a `Style` can put one in a bag of values.
    /// Design: docs/design/views/modifiers.md#a-handler-runs-beside-the-one-before
    func addHandler(_ event: Event, _ handler: @escaping EventHandler) -> Modified {
        modified { $0.addHandler(event, handler) }
    }
}

extension ModifiableElement where Modified == Self {
    /// The node this control describes - itself, since a control has one.
    public var body: Node { node }
}
