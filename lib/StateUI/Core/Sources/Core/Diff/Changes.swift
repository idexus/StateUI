// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onChanged`: runs a handler when a value is not what this view carried last
// render. Nothing about it crosses to the host.
// Design: docs/design/core/identity-and-diffing.md#watching-values

/// What `.onChanged` runs, the value's type erased - what a node stores: the old value and the new one.
typealias ErasedChangeHandler = @MainActor (Any, Any) async throws -> Void

/// One value a view watches and what to run when it moves; the comparison is
/// captured where the value's type was known.
struct Watch {
    /// The value as this render wrote it.
    let value: Any

    /// Whether a stored value equals this one, or nil where the types differ - a slot
    /// that changed hands, which starts over rather than firing.
    let matches: (Any) -> Bool?

    /// What to run, given the old value and the new one.
    let run: ErasedChangeHandler

    /// What a change does while a run is under way.
    let repeated: RepeatedEvent

    /// A watch on one value. Written by `.onChanged`, never by hand.
    init<Value: Equatable>(_ value: Value, _ repeated: RepeatedEvent, run: @escaping ErasedChangeHandler) {
        self.value = value
        self.matches = { stored in (stored as? Value).map { $0 == value } }
        self.repeated = repeated
        self.run = run
    }
}

extension ModifiableElement {
    /// Runs something when `value` is not what it was last render - all of it,
    /// inside the render's walk.
    ///
    ///     VStack { … }
    ///         .onChanged(step) { visits += 1 }
    ///
    /// The value is compared with the one this view carried last render. It does
    /// not fire when the view first appears - use `.onCreated` for that. What the
    /// handler writes is sent in the same render; a handler that moves the value
    /// it watches every time is a loop.
    ///
    /// Each `.onChanged` is paired with its predecessor by the order the modifiers
    /// appear in, so one written under an `if` makes the view start watching afresh.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - handler: What to run once the value has moved.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping @MainActor () throws -> Void
    ) -> Modified {
        onChanged(value, .overlap) { try handler() }
    }

    /// The same, with a handler that awaits: `repeated` says what another change
    /// does while a run is under way - a newer query cancelling the search for
    /// the older one, say.
    ///
    ///     VStack { … }
    ///         .onChanged(query, .cancelPrevious) { try await search() }
    ///
    /// What the handler writes before its first suspension is sent in the same
    /// render.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - repeated: what a change does while a run is under way.
    ///   - handler: What to run once the value has moved.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ repeated: RepeatedEvent,
        _ handler: @escaping EventHandler
    ) -> Modified {
        modified { $0.watches.append(Watch(value, repeated) { _, _ in try await handler() }) }
    }

    /// A handler that awaits says what a change does while it runs.
    @available(*, unavailable, message: "a handler that awaits says what a change does while it runs: .onChanged(value, .cancelPrevious) { … } - or .ignoreWhileRunning, .waitForPrevious, .overlap")
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping EventHandler
    ) -> Modified {
        fatalError("unavailable")
    }

    /// The same, handed the value it was and the value it now is.
    ///
    ///     Text(status)
    ///         .onChanged(step) { old, new in
    ///             direction = new > old ? "forward" : "back"
    ///         }
    ///
    /// Which of the two overloads a call means is decided by the closure: one
    /// written `{ … }` takes no arguments and gets the short form, one written
    /// `{ old, new in … }` gets this.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - handler: What to run, given the old value and the new one.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping @MainActor (Value, Value) throws -> Void
    ) -> Modified {
        onChanged(value, .overlap) { old, new in try handler(old, new) }
    }

    /// The same, with a handler that awaits, handed the value it was and the
    /// value it now is; `repeated` says what another change does while a run is
    /// under way.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - repeated: what a change does while a run is under way.
    ///   - handler: What to run, given the old value and the new one.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ repeated: RepeatedEvent,
        _ handler: @escaping ValueEventHandler<Value, Value>
    ) -> Modified {
        modified {
            $0.watches.append(Watch(value, repeated) { old, new in
                // Both casts hold by construction: a slot is written by one modifier.
                guard let old = old as? Value, let new = new as? Value else { return }

                try await handler(old, new)
            })
        }
    }

    /// A handler that awaits says what a change does while it runs.
    @available(*, unavailable, message: "a handler that awaits says what a change does while it runs: .onChanged(value, .cancelPrevious) { … } - or .ignoreWhileRunning, .waitForPrevious, .overlap")
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping ValueEventHandler<Value, Value>
    ) -> Modified {
        fatalError("unavailable")
    }
}
