// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Events the host raises by name, with no element behind them.
// Design: docs/design/core/acts.md#host-events

/// One handler's subscription to a host event, made by `HostEvents.on`.
///
/// Keep it and `cancel()` when the listener leaves, the way a view's
/// `.onDestroying` ends what `.onCreated` started. A subscription nobody cancels
/// goes on hearing raises for as long as the process lives; cancelling twice
/// is harmless.
public final class HostEventSubscription: @unchecked Sendable {
    /// Which event, and which entry in its list.
    private let event: Event
    private let id: Int

    /// Made by `HostEvents.on` and nothing else.
    init(event: Event, id: Int) {
        self.event = event
        self.id = id
    }

    /// Stops the handler from hearing further raises. Idempotent.
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
/// battery reports whether a page is watching or not. Prefix event names with
/// the application's own (`"Gallery."`) so they can never meet an event this
/// library adds later.
public enum HostEvents {
    /// The subscriptions in the order made, which is the order handlers run in.
    nonisolated(unsafe) private static var subscriptions:
        [Event: [(id: Int, handler: ValueEventHandler<[PropValue]>)]] = [:]

    /// The next subscription's number - never reused.
    nonisolated(unsafe) private static var nextId = 1

    /// The lock: a subscription may be written while a raise arrives.
    private static let guarded = Lock()

    /// Subscribes a handler to what the host raises under an event's name, the values
    /// as they crossed; an event the host says it does not raise is said once.
    private static func subscribe(
        _ event: Event,
        owner: String,
        member: String,
        _ handler: @escaping ValueEventHandler<[PropValue]>
    ) -> HostEventSubscription {
        if let unraised = HostRealizations.unraised(owner: owner, event: member) {
            complain(unraised)
        }

        let id = guarded.withLock {
            let id = nextId
            nextId += 1
            subscriptions[event, default: []].append((id: id, handler: handler))
            return id
        }

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
    @discardableResult
    public static func on<Owner: ApplicationTier>(
        _ event: ElementEvent<Owner, Void>,
        _ handler: @escaping EventHandler
    ) -> HostEventSubscription {
        subscribe(event.token, owner: Owner.name, member: event.name) { payload in
            guard MemberValues.carried(payload, by: event.name) != nil else { return }

            try await handler()
        }
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
    @discardableResult
    public static func on<Owner: ApplicationTier, Value: HostRepresentable>(
        _ event: ElementEvent<Owner, Value>,
        _ handler: @escaping ValueEventHandler<Value>
    ) -> HostEventSubscription {
        subscribe(event.token, owner: Owner.name, member: event.name) { payload in
            guard let value = MemberValues.carried(payload, by: event.name, as: Value.self) else { return }

            try await handler(value)
        }
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
    @discardableResult
    public static func on<Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable>(
        _ event: ElementEvent<Owner, (First, Second)>,
        _ handler: @escaping ValueEventHandler<First, Second>
    ) -> HostEventSubscription {
        subscribe(event.token, owner: Owner.name, member: event.name) { payload in
            guard let (first, second) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self)
            else { return }

            try await handler(first, second)
        }
    }

    /// Subscribes a handler to an event of the application's that carries
    /// three values, handed over as the types its contract declares, in its
    /// order.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - handler: given the values.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    @discardableResult
    public static func on<
        Owner: ApplicationTier, First: HostRepresentable, Second: HostRepresentable, Third: HostRepresentable
    >(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping ValueEventHandler<First, Second, Third>
    ) -> HostEventSubscription {
        subscribe(event.token, owner: Owner.name, member: event.name) { payload in
            guard let (first, second, third) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }
    }

    /// Takes one subscription out - `HostEventSubscription.cancel`'s half.
    static func remove(_ event: Event, _ id: Int) {
        guarded.withLock {
            subscriptions[event]?.removeAll { $0.id == id }
        }
    }

    /// Runs every handler subscribed to a name and answers how many - taken under the
    /// lock, started outside it, each on `MainActor`.
    static func dispatch(_ name: String, _ payload: [PropValue]) -> Int {
        let handlers = guarded.withLock { subscriptions[Event(name)] ?? [] }

        for entry in handlers {
            Renderer.shared.start { try await entry.handler(payload) }
        }

        return handlers.count
    }
}
