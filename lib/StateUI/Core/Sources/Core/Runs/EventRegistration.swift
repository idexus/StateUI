// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What one event of one element runs - its handlers in written order - and each handler's runs, kept under the
/// event's id while the element handles it.
/// Design: docs/design/core/runs.md#the-runs-of-a-handler
@MainActor
final class EventRegistration {
    private(set) var handlers: [Handler]
    private var slots: [RunSlot]

    init(_ handlers: [Handler]) {
        self.handlers = handlers
        slots = handlers.map { _ in RunSlot() }
    }

    /// Takes the handlers a new render wrote; a handler no longer written has its runs superseded.
    func replace(_ written: [Handler]) {
        for slot in slots.dropFirst(written.count) { slot.orphan() }
        slots = Array(slots.prefix(written.count)) + (slots.count..<max(written.count, slots.count)).map { _ in RunSlot() }
        handlers = written
    }

    /// Starts every handler for an event carrying `payload`, each by its own word.
    func start(payload: [PropValue]?) {
        for (handler, slot) in zip(handlers, slots) {
            slot.start(handler.run, handler.repeated, payload: payload)
        }
    }

    /// The element no longer handles the event: every run of it is superseded.
    func orphan() {
        for slot in slots { slot.orphan() }
    }
}
