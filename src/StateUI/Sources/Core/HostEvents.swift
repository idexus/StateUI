// Events the HOST raises by name, with no element behind them.
//
// Every other event belongs to an element of the tree and is found by a
// handler id the differ issued. What the C# side pushes on its own -
// connectivity changing, the battery reporting - has no element to hang off,
// so the application registers the raise in C# (`StateUIEvents.Raise`) and
// subscribes here BY NAME, with the same `Event` token both sides of an
// element's event already share.
//
// The handlers run exactly as a control's do: queued on this library's
// executor, isolated to @MainThread, free to await - `Renderer.start` is the
// one place a handler is ever started, and this is one more caller of it.

// Dispatch and not Foundation, for the lock - the Renderer's own reasoning.
import Dispatch

/// One handler's subscription to a host event, made by `HostEvents.on`.
///
/// Keep it and `cancel()` when the listener leaves, the way a view's
/// `.onUnloaded` ends what `.onLoaded` started. A subscription nobody cancels
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

/// Events raised by the C# side by NAME - the push half of the interop
/// surface, sister to the acts an application registers.
///
///     extension Event {
///         static let batteryChanged = Event("Gallery.BatteryChanged")
///     }
///
///     let heard = HostEvents.on(.batteryChanged) { payload in
///         level = payload.value()?.number ?? level
///     }
///     // later, when the listener leaves:
///     heard.cancel()
///
/// The C# half registers the raise once, at startup:
///
///     Battery.Default.BatteryInfoChanged += (_, e) =>
///         StateUIEvents.Raise("Gallery.BatteryChanged",
///             SwiftWireValue.Of(e.ChargeLevel));
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

    /// Subscribes a handler to an event the host raises by name. Handlers
    /// run in the order they were subscribed, each queued on this library's
    /// executor exactly as a control's handler is - `@MainThread`-isolated,
    /// free to await, its thrown errors reported.
    ///
    /// - Parameters:
    ///   - event: the name the C# side raises - the application's own token,
    ///     e.g. `Event("Gallery.BatteryChanged")`.
    ///   - handler: given the raise's typed values, in the order the C# side
    ///     wrote them - read them with `payload.value()?.number` and its kin,
    ///     the `onEvent` shape.
    /// - Returns: the subscription, to `cancel()` when the listener leaves.
    @discardableResult
    public static func on(
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

    /// Takes one subscription out - `HostEventSubscription.cancel`'s half.
    static func remove(_ event: Event, _ id: Int) {
        guarded.sync {
            subscriptions[event]?.removeAll { $0.id == id }
        }
    }

    /// Runs every handler subscribed to a name and answers how many there
    /// were - called by the export, on the thread MAUI draws on. The
    /// handlers are taken under the lock and started outside it, the
    /// dispatch rule.
    static func dispatch(_ name: String, _ payload: [PropValue]) -> Int {
        let handlers = guarded.sync { subscriptions[Event(name)] ?? [] }

        for entry in handlers {
            Renderer.shared.start { try await entry.handler(payload) }
        }

        return handlers.count
    }
}
