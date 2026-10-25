// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onHostEvent`: an event of the application's heard while the view stands.
// Design: docs/design/core/runs.md#an-element-hears-the-host

extension ModifiableElement {
    /// Hears an event of the application's - one no control raises - while this view stands: subscribed as it
    /// is made, cancelled as it leaves, each raise run by the handler this render wrote.
    ///
    ///     VStack { … }
    ///         .onHostEvent(NotesContract.memoryLow) { cache.removeAll() }
    ///
    /// Where no view stands for the listener - an application's model - `HostEvents.on` subscribes, and its
    /// subscription is cancelled by hand.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    public func onHostEvent<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping @MainActor () throws -> Void
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, handler))
    }

    /// The same, with a handler that awaits: its `policy` says what a raise does while a run is under way.
    public func onHostEvent<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        policy: GatePolicy,
        _ handler: @escaping EventHandler
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHostEvent<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        gate: Gate,
        _ handler: @escaping EventHandler
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .shared(gate), handler))
    }

    /// Hears an event of the application's that carries one value while this view stands, handed over as the
    /// type its contract declares.
    ///
    ///     .onHostEvent(NotesContract.connectivityChanged) { online in … }
    public func onHostEvent<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping @MainActor (Value) throws -> Void
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, handler))
    }

    /// The same, with a handler that awaits: its `policy` says what a raise does while a run is under way.
    public func onHostEvent<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHostEvent<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .shared(gate), handler))
    }

    /// Hears an event of the application's that carries two values while this view stands, handed over as the
    /// types its contract declares, in its order.
    ///
    ///     .onHostEvent(NotesContract.batteryChanged) { level, charging in battery = level }
    public func onHostEvent<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping @MainActor (First, Second) throws -> Void
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, handler))
    }

    /// The same, with a handler that awaits: its `policy` says what a raise does while a run is under way.
    public func onHostEvent<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHostEvent<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .shared(gate), handler))
    }

    /// Hears an event of the application's that carries three values while this view stands, handed over as
    /// the types its contract declares, in its order.
    public func onHostEvent<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @MainActor (First, Second, Third) throws -> Void
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, handler))
    }

    /// The same, with a handler that awaits: its `policy` says what a raise does while a run is under way.
    public func onHostEvent<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHostEvent<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> Modified {
        hearing(EventMember(event), HostEvents.heard(event, gate: .shared(gate), handler))
    }

    /// The view hearing `event` through `handler` while it stands.
    private func hearing(_ event: EventMember, _ handler: ValueHandler<[PropValue]>) -> Modified {
        modified { $0.hostEvents.append(HostEventListen(event: event, handler: handler)) }
    }
}
