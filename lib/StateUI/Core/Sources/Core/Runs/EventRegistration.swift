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

    /// Starts every handler for an event carrying `payload`, each through its gate.
    func start(payload: [PropValue]?) {
        for (handler, owner) in zip(handlers, owners) {
            handler.gate.runs(for: owner).start(handler.run, handler.gate.policy, payload: payload, owner: owner)
        }
    }

    /// What starts `written` - a composed view's handlers, given the values of an event that came now - each
    /// through the owner kept at its place now, those `chosen` picks. Called after the frame, it starts nothing for a
    /// handler whose owner the registration no longer keeps by then: no longer written, or the view gone.
    /// Design: docs/design/core/runs.md#the-runs-of-a-handler
    func starting(_ written: [Handler], chosen: @escaping (Int) -> Bool = { _ in true }) -> @MainActor () -> Void {
        let kept = Array(zip(written, owners).enumerated().filter { chosen($0.offset) }.map(\.element))
        return { [weak self] in
            for (handler, owner) in kept {
                guard let self, self.owners.contains(where: { $0 === owner }) else { continue }

                handler.gate.runs(for: owner).start(handler.run, handler.gate.policy, payload: nil, owner: owner)
            }
        }
    }

    /// The element no longer handles the event: every run of it is superseded, and nothing it was told starts.
    func orphan() {
        for owner in owners { owner.orphan() }
        owners = []
        handlers = []
    }
}
