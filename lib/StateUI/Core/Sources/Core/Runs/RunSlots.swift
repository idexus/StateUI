// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runs of what an element's walk finds to run - its watches, its visual states, its making - each under a
/// key its element keeps from one render to the next.
/// Design: docs/design/core/runs.md#what-a-walk-runs
@MainActor
final class RunSlots {
    private var owners: [(key: String, owner: RunOwner)] = []

    /// The events of the application's the element hears, by their place among its `.onHostEvent`s.
    private var relays: [HostEventRelay] = []

    /// Who starts the runs kept under `key`, made now if nobody does yet.
    func owner(_ key: String) -> RunOwner {
        if let kept = owners.first(where: { $0.key == key }) { return kept.owner }

        let owner = RunOwner()
        owners.append((key, owner))
        return owner
    }

    /// Hears `listens` while the element stands: each place's event subscribed once, as the element is made or
    /// the place first names it, its handler this render's; a place no longer written is cancelled.
    func listen(to listens: [HostEventListen]) {
        for (place, listen) in listens.enumerated() {
            if place < relays.count, relays[place].event == listen.event {
                relays[place].handler = listen.handler
            } else if place < relays.count {
                relays[place].cancel()
                relays[place] = HostEventRelay(listen)
            } else {
                relays.append(HostEventRelay(listen))
            }
        }
        while relays.count > listens.count { relays.removeLast().cancel() }
    }

    /// The element left: every run of it is superseded, in the order its key was first asked for, and every event
    /// it heard is heard no more.
    func orphan() {
        for entry in owners { entry.owner.orphan() }
        for relay in relays { relay.cancel() }
        relays = []
    }
}
