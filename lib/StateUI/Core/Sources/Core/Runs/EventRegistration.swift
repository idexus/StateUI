// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What one event of one element runs - its handlers in written order - and each handler's runs, kept under the
/// event's id while the element handles it.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
@MainActor
final class EventRegistration {
    private(set) var handlers: [Handler]
    private var owners: [RunOwner]

    init(_ handlers: [Handler]) {
        self.handlers = handlers
        owners = handlers.map { _ in RunOwner() }
    }

    /// Takes the handlers a new render wrote; a handler no longer written has its runs superseded.
    func replace(_ written: [Handler]) {
        keep(written.count)
        handlers = written
    }

    /// Keeps the runs of the first `count` handlers, each by its place: what a composed view's render writes of an
    /// event it starts itself, before the event hands the handlers their values. A handler no longer written has its
    /// runs superseded then, with no event to come.
    func keep(_ count: Int) {
        for owner in owners.dropFirst(count) { owner.orphan() }
        owners = Array(owners.prefix(count)) + (owners.count..<max(count, owners.count)).map { _ in RunOwner() }
        handlers = Array(handlers.prefix(count))
    }

    /// Starts every handler for an event carrying `payload`, each through its gate - or those `chosen` picks by
    /// their place alone, each still through its own.
    func start(payload: [PropValue]?, chosen: (Int) -> Bool = { _ in true }) {
        for (place, (handler, owner)) in zip(handlers, owners).enumerated() {
            guard chosen(place) else { continue }

            handler.gate.runs(for: owner).start(handler.run, handler.gate.policy, payload: payload, owner: owner)
        }
    }

    /// The element no longer handles the event: every run of it is superseded.
    func orphan() {
        for owner in owners { owner.orphan() }
    }
}
