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
        for owner in owners.dropFirst(written.count) { owner.orphan() }
        owners = Array(owners.prefix(written.count))
            + (owners.count..<max(written.count, owners.count)).map { _ in RunOwner() }
        handlers = written
    }

    /// Starts every handler for an event carrying `payload`, each through its gate.
    func start(payload: [PropValue]?) {
        for (handler, owner) in zip(handlers, owners) {
            handler.gate.runs(for: owner).start(handler.run, handler.gate.policy, payload: payload, owner: owner)
        }
    }

    /// The element no longer handles the event: every run of it is superseded.
    func orphan() {
        for owner in owners { owner.orphan() }
    }
}
