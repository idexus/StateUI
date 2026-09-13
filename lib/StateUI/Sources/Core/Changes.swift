// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Running something when a value is not what it was last render.
//
//     Label("\(count)")
//         .onChanged(count) { try await save() }
//         .onChanged(query) { old, new in print("\(old) -> \(new)") }
//
// MAUI has no such thing, so this is the library's own - the way `debugInfo()`
// beside it is, and named for what it does rather than for a MAUI member. The
// semantics are the name's: the value is compared against the one THIS view
// carried last render, and the handler runs only when the two differ.
//
// NOTHING ABOUT IT CROSSES THE BOUNDARY. The comparison is a Swift-side question
// with a Swift-side answer: the differ already visits every element with the
// element it continues in hand, so the previous value is right there. C# is
// never told, no property is sent, and no fixture changes - which is why this
// works for a value MAUI has no property for at all.
//
// FOUR RULES, and each of them is a decision:
//
// - **The first render never fires.** A view arriving is not a value changing,
//   and firing there would make `.onChanged` a second `.onCreated` that also
//   happens to fire later. Running something because a view ARRIVED in the
//   tree is what `.onCreated` is for.
// - **The values are kept in the order they were WRITTEN**, one slot per
//   modifier, not in a set. A set would need `Hashable` where `Equatable` is the
//   real requirement, and - worse - it could not say WHICH modifier a stored
//   value belonged to, so two `.onChanged` on one view would answer for each
//   other. Declaration order is what pairs a value with its predecessor, exactly
//   as it pairs a `@State` box with its predecessor in Core/Stateful.swift.
// - **A different NUMBER of them starts over rather than firing.** Writing
//   `.onChanged` under an `if` moves every slot after it, so the safe reading of
//   a changed count is "these are not the same watches", not "they all changed".
// - **The handlers run once the walk is done**, from `Renderer.renderWire`,
//   never from inside it. A handler is a handler: it may write `@State`, and a
//   write landing mid-walk is cleared by the bookkeeping at the end of that
//   walk - so firing from the differ would drop it silently, which is the one
//   failure this project keeps paying for. Run after the walk and BEFORE the
//   message leaves, what a handler writes is walked in turn and sent in the
//   same message - a value worked out from another changes in its render.

/// What `.onChanged` runs when the value it watches is not what it was.
///
///     .onChanged(step) { old, new in
///         direction = new > old ? "forward" : "back"
///     }
///
/// The two values are the OLD one and the NEW one, in that order - the one
/// that reads right at the call site.
///
/// `nonisolated(nonsending)` for the reason every handler here is: it runs on
/// its caller's executor, which is `@MainThread`, so it may read and write
/// `@State` as freely as a button's handler and may await without landing on
/// Swift's cooperative pool.
public typealias ChangeHandler<Value> = nonisolated(nonsending) (Value, Value) async throws -> Void

/// The same, once the value's type has been erased - what a Node stores.
///
/// The types are gone by then because a node holds watches of every value type
/// at once; the modifier casts them back, and can, because the slot a value
/// lands in is the slot its own modifier wrote.
typealias ErasedChangeHandler = nonisolated(nonsending) (Any, Any) async throws -> Void

/// One value a view is watching, and what to run when it moves.
///
/// The value is kept as `Any` and compared through a closure captured where its
/// type was still known, which is what lets one array hold watches of different
/// types without the node being generic over any of them.
struct Watch {
    /// The value as this render wrote it.
    let value: Any

    /// Whether a value the element stored is the same as this one - or nil
    /// when the two cannot be compared at all.
    ///
    /// Captured at the modifier, where `Value: Equatable` is known. Nil is not
    /// false: a stored value of another TYPE is a slot that changed hands - an
    /// `.onChanged` written under an `if`, or one rewritten to watch something
    /// else - and a slot changing hands starts over rather than firing, the
    /// same reading a changed count gets.
    let matches: (Any) -> Bool?

    /// What to run, given the old value and the new one.
    let run: ErasedChangeHandler

    /// A watch on one value. Written by `.onChanged`, never by hand.
    init<Value: Equatable>(_ value: Value, run: @escaping ErasedChangeHandler) {
        self.value = value
        self.matches = { stored in (stored as? Value).map { $0 == value } }
        self.run = run
    }
}

extension BindableObject {
    /// Runs something when `value` is not what it was last render.
    ///
    ///     VStack { … }
    ///         .onChanged(query) { try await search() }
    ///
    /// The value is whatever the view depends on - a `@State`, a property of a
    /// model, something computed from either. It is compared against the value
    /// THIS view carried last render, so it says "this changed since you last
    /// saw it" rather than "this is different from something else".
    ///
    /// It does not fire when the view first appears: a view arriving is not a
    /// value changing. Use `.onCreated` for that, and both together where
    /// something has to happen on the way in AND on every change after.
    ///
    /// The handler is a handler like any other - it may write `@State`, ask the
    /// host to do something, and `await` either. It runs once the render that
    /// noticed the change has walked the tree, and what it writes before its
    /// first suspension is walked too and sent in the same message - so a value
    /// worked out from the one watched changes in the same render. One
    /// consequence to own: a handler that moves the very value it watches is
    /// fired again by the walk of its own write, and a handler that moves it
    /// every time is a loop - walked into the message a few times, then a
    /// render per step.
    ///
    /// Write it as often as there are values to watch. Each watch is its own,
    /// paired with its predecessor by the order the modifiers appear in - so a
    /// `.onChanged` under an `if` changes how many there are, and the whole
    /// view starts watching afresh instead of firing.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - handler: What to run once the value has moved.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping EventHandler
    ) -> Modified {
        modified { $0.watches.append(Watch(value) { _, _ in try await handler() }) }
    }

    /// The same, handed the value it was and the value it now is.
    ///
    ///     Label(status)
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
        _ handler: @escaping ChangeHandler<Value>
    ) -> Modified {
        modified {
            $0.watches.append(Watch(value) { old, new in
                // Both casts hold by construction - a slot is written by one
                // modifier, whose Value never changes between renders. The
                // guard is for the case that cannot happen rather than a case
                // to handle: silence beats a crash on a boundary this side of
                // which nobody can look.
                guard let old = old as? Value, let new = new as? Value else { return }

                try await handler(old, new)
            })
        }
    }
}

extension PageElement {
    /// Runs something when `value` is not what it was last render. The same as
    /// a view's `onChanged`.
    ///
    ///     FlyoutPage($open) { … } detail: { … }
    ///         .onChanged(window.phase) { log(window.phase) }
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - handler: What to run once the value has moved.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping EventHandler
    ) -> Modified {
        modified { $0.watches.append(Watch(value) { _, _ in try await handler() }) }
    }

    /// The same, handed the value it was and the value it now is.
    ///
    /// - Parameters:
    ///   - value: What to watch. Anything `Equatable`.
    ///   - handler: What to run, given the old value and the new one.
    public func onChanged<Value: Equatable>(
        _ value: Value,
        _ handler: @escaping ChangeHandler<Value>
    ) -> Modified {
        modified {
            $0.watches.append(Watch(value) { old, new in
                guard let old = old as? Value, let new = new as? Value else { return }

                try await handler(old, new)
            })
        }
    }
}
