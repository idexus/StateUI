// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onHostEvent`: an event of the application's an element hears while it stands.
// Design: docs/design/core/runs.md#an-element-hears-the-host

/// One `.onHostEvent` as a render wrote it.
struct HostEventListen {
    let event: Event
    let handler: ValueHandler<[PropValue]>
}

/// An element's subscription to one event, subscribed once and handing each raise to the last render's handler,
/// through that handler's gate - as an element's own event does.
@MainActor
final class HostEventRelay {
    let event: Event
    var handler: ValueHandler<[PropValue]> {
        didSet { subscription?.hand(relayed(through: handler.gate)) }
    }
    private var subscription: HostEventSubscription?

    init(_ listen: HostEventListen) {
        event = listen.event
        handler = listen.handler
        subscription = HostEvents.subscribe(listen.event, relayed(through: listen.handler.gate))
    }

    /// What the subscription runs: the last render's handler, through `gate`.
    private func relayed(through gate: Gating) -> ValueHandler<[PropValue]> {
        ValueHandler(run: { [weak self] payload in try await self?.handler.run(payload) }, gate: gate)
    }

    /// Stops hearing, and supersedes the runs under way.
    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
