// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Events the host raises by name, with no element behind them.
// Design: docs/design/core/acts.md#host-events

/// An application's event by its contract and its member: two tiers may name an event alike.
/// Design: docs/design/core/acts.md#host-events
struct EventMember: Hashable, Sendable {
    let owner: KeyName
    let member: KeyName

    init<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        owner = event.owner
        member = event.token.key
    }
}

/// One handler's subscription to a host event, made by `HostEvents.on`.
///
/// Keep it - one not kept is a warning - and `cancel()` when the listener
/// leaves, the way a view's `.onDestroying` ends what `.onCreated` started. A
/// subscription nobody cancels goes on hearing raises for as long as the
/// process lives; cancelling twice is harmless.
@MainActor
public final class HostEventSubscription {
    /// Which event, and which entry in its list.
    private let event: EventMember
    private let id: Int

    /// Made by `HostEvents.on` and nothing else.
    init(event: EventMember, id: Int) {
        self.event = event
        self.id = id
    }

    /// Stops the handler hearing further raises and supersedes its runs under way.
    /// Idempotent.
    public func cancel() {
        HostEvents.remove(event, id)
    }
}

/// Events the host raises by NAME - the push half of the interop surface,
/// sister to the acts an application registers - each a member of an
/// `ApplicationTier`, heard with the values it declares.
///
///     enum NotesContract: ApplicationTier {
///         static let name = "Notes"
///         static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Notes.BatteryChanged")
///         static let members: [any ContractMember] = [batteryChanged]
///     }
///
///     let heard = HostEvents.on(NotesContract.batteryChanged) { level, charging in
///         battery = level
///     }
///     // later, when the listener leaves:
///     heard.cancel()
///
/// The host half registers the raise once, at startup, and raises the same
/// name with the values whenever the platform reports a change.
///
/// A raise nobody subscribed to is an ordinary answer, not an error - the
/// battery reports whether a page is watching or not. An event is told apart by its
/// contract and its name together, so two tiers may name an event alike.
@MainActor
public enum HostEvents {
    /// The subscriptions in the order made, which is the order handlers run in.
    private static var subscriptions:
        [EventMember: [(id: Int, owner: RunOwner, handler: ValueHandler<[PropValue]>)]] = [:]

    /// The next subscription's number - never reused.
    private static var nextId = 1

    /// Subscribes a handler to what the host raises under an event's name, the values
    /// as they crossed; an event the host says it does not raise is said once.
    static func subscribe(
        _ event: EventMember,
        _ handler: ValueHandler<[PropValue]>
    ) -> HostEventSubscription {
        if let unraised = HostRealizations.unraised(owner: event.owner, event: event.member) {
            complain(unraised)
        }

        let id = nextId
        nextId += 1
        subscriptions[event, default: []].append((id: id, owner: RunOwner(), handler: handler))

        return HostEventSubscription(event: event, id: id)
    }

    /// Subscribes a handler to an event of the application's - one no control
    /// raises - that carries nothing.
    ///
    ///     let heard = HostEvents.on(NotesContract.memoryLow) { cache.removeAll() }
    ///
    /// A raise carrying anything is reported once and does not reach the
    /// handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: what runs.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    public static func on<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping @MainActor () throws -> Void
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, handler))
    }

    /// The same, with a handler that awaits: its `gate` says what a raise does while a run is under way.
    public static func on<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        gate: some Gate,
        _ handler: @escaping EventHandler
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, gate: gate, handler))
    }

    /// Subscribes a handler to an event of the application's that carries one
    /// value, handed over as the type its contract declares.
    ///
    ///     let heard = HostEvents.on(NotesContract.connectivityChanged) { online in … }
    ///
    /// A raise of another shape - the value missing, one too many, or one of
    /// another kind - is reported once and does not reach the handler.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the value.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    public static func on<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping @MainActor (Value) throws -> Void
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, handler))
    }

    /// The same, with a handler that awaits: its `gate` says what a raise does while a run is under way.
    public static func on<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, gate: gate, handler))
    }

    /// Subscribes a handler to an event of the application's that carries two
    /// values, handed over as the types its contract declares, in its order.
    ///
    ///     let heard = HostEvents.on(NotesContract.batteryChanged) { level, charging in
    ///         battery = "\(Int(level * 100))%" + (charging ? ", charging" : "")
    ///     }
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    public static func on<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping @MainActor (First, Second) throws -> Void
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, handler))
    }

    /// The same, with a handler that awaits: its `gate` says what a raise does while a run is under way.
    public static func on<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, gate: gate, handler))
    }

    /// Subscribes a handler to an event of the application's that carries
    /// three values, handed over as the types its contract declares, in its
    /// order.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    public static func on<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @MainActor (First, Second, Third) throws -> Void
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, handler))
    }

    /// The same, with a handler that awaits: its `gate` says what a raise does while a run is under way.
    public static func on<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> HostEventSubscription {
        subscribe(EventMember(event), heard(event, gate: gate, handler))
    }

    // MARK: - What a handler hears

    /// A handler of an event as every listener hears it: the raise's values read as the types its contract
    /// declares, a raise of another shape reported once and kept from the handler - what `on` subscribes and
    /// `.onHostEvent` relays.
    static func heard<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping @MainActor () throws -> Void
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(step: { payload in
            guard MemberValues.carried(payload, by: event.name) != nil else { return }

            try handler()
        })
    }

    static func heard<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        gate: some Gate,
        _ handler: @escaping EventHandler
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(run: { payload in
            guard MemberValues.carried(payload, by: event.name) != nil else { return }

            try await handler()
        }, gate: gate)
    }

    static func heard<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping @MainActor (Value) throws -> Void
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(step: { payload in
            guard let value = MemberValues.carried(payload, by: event.name, as: Value.self) else { return }

            try handler(value)
        })
    }

    static func heard<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(run: { payload in
            guard let value = MemberValues.carried(payload, by: event.name, as: Value.self) else { return }

            try await handler(value)
        }, gate: gate)
    }

    static func heard<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping @MainActor (First, Second) throws -> Void
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(step: { payload in
            guard let (first, second) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self)
            else { return }

            try handler(first, second)
        })
    }

    static func heard<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(run: { payload in
            guard let (first, second) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self)
            else { return }

            try await handler(first, second)
        }, gate: gate)
    }

    static func heard<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @MainActor (First, Second, Third) throws -> Void
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(step: { payload in
            guard let (first, second, third) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try handler(first, second, third)
        })
    }

    static func heard<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        gate: some Gate,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> ValueHandler<[PropValue]> {
        ValueHandler(run: { payload in
            guard let (first, second, third) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }, gate: gate)
    }

    /// Takes one subscription out - `HostEventSubscription.cancel`'s half.
    static func remove(_ event: EventMember, _ id: Int) {
        subscriptions[event]?.first { $0.id == id }?.owner.orphan()
        subscriptions[event]?.removeAll { $0.id == id }
    }

    /// Runs every handler subscribed to an event, each through its gate, and answers how many - the list as
    /// it stands when the raise is delivered on the UI thread, which may be after it was raised.
    @discardableResult
    static func dispatch(_ event: EventMember, _ payload: [PropValue]) -> Int {
        let handlers = subscriptions[event] ?? []

        for entry in handlers {
            let handler = entry.handler
            handler.gate.runs(for: entry.owner).start(
                { try await handler.run(payload) }, handler.gate.policy, payload: nil, owner: entry.owner)
        }

        return handlers.count
    }
}
