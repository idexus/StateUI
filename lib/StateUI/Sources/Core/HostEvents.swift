// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Events the HOST raises by name, with no element behind them.
//
// Every other event belongs to an element of the tree and is found by a
// handler id the differ issued. What the host pushes on its own -
// connectivity changing, the battery reporting - has no element to hang off,
// so the application declares it in its contract, registers the raise with
// the host, and subscribes here to the member: the name crosses, and the
// values arrive as the types the member declares.
//
// The handlers run exactly as a control's do: queued on this library's
// executor, isolated to @MainThread, free to await - `Renderer.start` is where
// an event's handler is started, `Renderer.queue` being the other road, for
// what a render's walk found - and this is one more caller of it.

// Dispatch and not Foundation, for the lock - the Renderer's own reasoning.
import Dispatch

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
    /// The subscriptions, in the order they were made - which is the order
    /// the handlers run in, the `addHandler` rule.
    nonisolated(unsafe) private static var subscriptions:
        [Event: [(id: Int, handler: ValueEventHandler<[PropValue]>)]] = [:]

    /// The next subscription's number - never reused, so a cancelled one
    /// cannot take a newer listener with it.
    nonisolated(unsafe) private static var nextId = 1

    /// The lock. A serial queue as a mutex, the Renderer's own pattern:
    /// a subscription may be written from a handler while a raise arrives on
    /// the UI thread.
    private static let guarded = DispatchQueue(label: "StateUI.HostEvents")

    /// Subscribes a handler to what the host raises under an event's name -
    /// what every `on` is written over, the values still as they crossed.
    /// Handlers run in the order they were subscribed, each queued on this
    /// library's executor exactly as a control's handler is -
    /// `@MainThread`-isolated, free to await, its thrown errors reported.
    ///
    /// - Parameters:
    ///   - event: the name the host raises.
    ///   - handler: given what the raise carried, in the order the host wrote it.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    private static func subscribe(
        _ event: Event,
        _ handler: @escaping ValueEventHandler<[PropValue]>
    ) -> HostEventSubscription {
        let id = guarded.sync {
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
        subscribe(event.token) { payload in
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
        subscribe(event.token) { payload in
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
        subscribe(event.token) { payload in
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
        subscribe(event.token) { payload in
            guard let (first, second, third) = MemberValues.carried(
                payload, by: event.name, as: First.self, Second.self, Third.self)
            else { return }

            try await handler(first, second, third)
        }
    }

    /// Takes one subscription out - `HostEventSubscription.cancel`'s half.
    static func remove(_ event: Event, _ id: Int) {
        guarded.sync {
            subscriptions[event]?.removeAll { $0.id == id }
        }
    }

    /// Runs every handler subscribed to a name and answers how many there
    /// were - called by the export and by `StateUIHost.raise`, on the host's
    /// UI thread. The handlers are taken under the lock and started outside
    /// it, the dispatch rule.
    static func dispatch(_ name: String, _ payload: [PropValue]) -> Int {
        let handlers = guarded.sync { subscriptions[Event(name)] ?? [] }

        for entry in handlers {
            Renderer.shared.start { try await entry.handler(payload) }
        }

        return handlers.count
    }
}
