// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onHostEvent`: an event of the application's heard while the view stands.
// Design: docs/design/core/runs.md#an-element-hears-the-host

extension ModifiableElement {
    /// Hears an event of the application's - one no control raises - while this view stands, its values handed
    /// over as the types its contract declares: subscribed as the view is made, cancelled as it leaves, each raise
    /// run by the handler this render wrote.
    ///
    ///     VStack { … }
    ///         .onHostEvent(NotesContract.memoryLow) { cache.removeAll() }
    ///         .onHostEvent(NotesContract.connectivityChanged) { online in … }
    ///
    /// Where no view stands for the listener - an application's model - `HostEvents.on` subscribes, and its
    /// subscription is cancelled by hand.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs, given the values.
    public func onHostEvent<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ handler: @escaping @MainActor (repeat each Value) throws -> Void
    ) -> Modified {
        hearing(event.token, HostEvents.heard(event, handler))
    }

    /// The same, with a handler that awaits: its `policy` says what a raise does while a run is under way.
    public func onHostEvent<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        policy: GatePolicy,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) -> Modified {
        hearing(event.token, HostEvents.heard(event, gate: .own(policy), handler))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onHostEvent<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        gate: Gate,
        _ handler: @escaping ValueEventHandler<repeat each Value>
    ) -> Modified {
        hearing(event.token, HostEvents.heard(event, gate: .shared(gate), handler))
    }

    /// The view hearing `event` through `handler` while it stands.
    private func hearing(_ event: Event, _ handler: ValueHandler<[PropValue]>) -> Modified {
        modified { $0.hostEvents.append(HostEventListen(event: event, handler: handler)) }
    }
}
