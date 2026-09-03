// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Running something when a value is not what it was last render.
//
//     Label("\(count.get())")
//         .onChanged(count.get()) { try await save() }
//         .onChanged(query.get()) { old, new in print("\(old) -> \(new)") }
//
// MAUI has no such thing, so this is the library's own - the way `.memoized(by:)`
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
// - **The first render never fires.** A view appearing is not a value changing,
//   and firing there would make `.onChanged` a second `.onLoaded` that also
//   happens to fire later. Running something because a view APPEARED is what
//   `.onLoaded` is for.
// - **The values are kept in the order they were WRITTEN**, one slot per
//   modifier, not in a set. A set would need `Hashable` where `Equatable` is the
//   real requirement, and - worse - it could not say WHICH modifier a stored
//   value belonged to, so two `.onChanged` on one view would answer for each
//   other. Declaration order is what pairs a value with its predecessor, exactly
//   as it pairs a `@State` box with its predecessor in Core/Stateful.swift.
// - **A different NUMBER of them starts over rather than firing.** Writing
//   `.onChanged` under an `if` moves every slot after it, so the safe reading of
//   a changed count is "these are not the same watches", not "they all changed".
// - **The handlers run AFTER the message is built**, from `Renderer.renderWire`,
//   never from inside the walk. A handler is a handler: it may write `@State`,
//   and a write landing mid-render is cleared by the bookkeeping at the end of
//   that render - so firing from the differ would drop it silently, which is the
//   one failure this project keeps paying for. Run afterwards, a write asks for
//   the next render like any other.

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
    ///         .onChanged(query.get()) { try await search() }
    ///
    /// The value is whatever the view depends on - a `@State`, a property of a
    /// model, something computed from either. It is compared against the value
    /// THIS view carried last render, so it says "this changed since you last
    /// saw it" rather than "this is different from something else".
    ///
    /// It does not fire when the view first appears: a view arriving is not a
    /// value changing. Use `.onLoaded` for that, and both together where
    /// something has to happen on the way in AND on every change after.
    ///
    /// The handler is a handler like any other - it may write `@State`, ask the
    /// host to do something, and `await` either. It runs after the render that
    /// noticed the change has been packed up, so a state write it makes is the
    /// next render's business rather than being swallowed by this one. One
    /// consequence to own: a handler that moves the very value it watches makes
    /// that next render fire it again, and a handler that moves it every time
    /// is a loop.
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

    /// Arithmetic the host runs on its own frames, whenever a bus it follows
    /// has been written.
    ///
    ///     .engine(following: $scrolled, $room) { cycle in
    ///         run = PlacedRun(placements(at: scrolled.value / step, room))
    ///     }
    ///
    /// THE FRAME IS WHERE IT RUNS, not the render: nothing here describes the
    /// interface, so a value a finger is moving can be followed at the
    /// display's own rate. It runs on the cycle after any bus it follows or
    /// any `@BusState` it read was written, and once after every render that
    /// described this view.
    ///
    /// It reads and writes buses and `@BusState`, and may write `@State` - a
    /// render then follows, priced like any other. It may NOT await, ask the
    /// host to do anything, or touch a control: it runs INSIDE the frame the
    /// platform is drawing, and everything it needs has to be on a bus already.
    /// The view is captured BY VALUE, so anything it must remember between
    /// cycles lives in a `@Bus` or a `@BusState`.
    ///
    /// Write it as often as there is arithmetic to run. Engines run in
    /// ascending `priority`, ties in the order they were first registered, so
    /// one that reads what another wrote in the same cycle says a higher
    /// number. Each is paired with its predecessor by the order the modifiers
    /// appear in - so an `.engine` under an `if` changes how many there are,
    /// and every one of them starts over.
    ///
    /// - Parameters:
    ///   - first: a bus whose movement is a reason to run.
    ///   - more: any others.
    ///   - sync: which clock it runs on. The display's own frame today.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, handed the instant and how long it has been.
    public func engine(
        following first: HostBus,
        _ more: HostBus...,
        sync: BusSync = .vsync,
        priority: Double = 0,
        _ run: @escaping (EngineCycle) -> Void
    ) -> Modified {
        modified {
            $0.engines.append(EngineDeclaration(
                follows: [first] + more,
                sync: sync,
                priority: priority,
                run: { cycle in
                    run(cycle)
                    return .still
                }))
        }
    }

    /// The same, answering whether it has more to do.
    ///
    ///     .engine { cycle in
    ///         body.step(cycle.elapsed / 1000) { _ in Point(0, 9.8) }
    ///         return body.isStill() ? .still : .moving
    ///     }
    ///
    /// `.moving` holds the frame clock, so this runs again next frame however
    /// still everything it follows is; `.still` lets it go. That is what a
    /// motion of its own needs - a body under gravity is moved by TIME rather
    /// than by anything being written - and it is why `following:` may be left
    /// out here and cannot be left out above: an engine that answers nothing
    /// and follows nothing would never run at all.
    ///
    /// AWAKE AND WRITING NOTHING FOR TEN SECONDS IS PUT STILL, and named. An
    /// engine that keeps the display awake for a picture that is not changing
    /// is a battery being spent on nothing, and the bound is on what it WROTE
    /// rather than on what it read, so an oscillator that writes every cycle
    /// is never touched.
    ///
    /// WHAT AN ENGINE READS IS RECORDED NOWHERE. It runs on the host's own
    /// frames, outside every render, so a `@State` the arithmetic looks up
    /// inside here is a read no walk knows about: writing it rebuilds nothing,
    /// arms no engine, and leaves the picture as the last run left it. A value
    /// the arithmetic needs is read in the BODY and handed over as a local -
    /// which is also what makes the closure this render's, with this render's
    /// values in it.
    ///
    /// - Parameters:
    ///   - following: the buses whose movement is a reason to run. May be none.
    ///   - sync: which clock it runs on. The display's own frame today.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next frame.
    public func engine(
        following: HostBus...,
        sync: BusSync = .vsync,
        priority: Double = 0,
        _ run: @escaping (EngineCycle) -> EngineState
    ) -> Modified {
        modified {
            $0.engines.append(EngineDeclaration(
                follows: following,
                sync: sync,
                priority: priority,
                run: run))
        }
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
