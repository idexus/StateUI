// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// THE ENGINE: arithmetic the host runs on its own frames.
//
// An engine is a closure attached to a view with `.engine(following:)`, and it
// is the WORK OUT of the cycle beside this file - the only place in this
// library where arithmetic runs outside a render. What it may do is narrow on
// purpose: read states, write states, and say whether it has more to do. It
// may not await, ask the host for anything, or touch a control, because it
// runs INSIDE the frame the platform is drawing.
//
// Three things make one up, and they are what this file holds:
//
//   WHAT IT IS HANDED    `EngineCycle` - the instant, and how long since IT ran.
//   WHAT IT ANSWERS      `EngineAnswer` - run me again, or wait for a signal.
//   HOW IT IS DECLARED   `EngineDeclaration`, and `EngineEntry` once it is live.
//
// WHAT WAKES ONE IS A WRITE TO A STATE IT WAS TOLD TO FOLLOW, and nothing
// else. `following:` names the states, and a write to one of them is a signal
// whoever made it - a handler, a control reporting, the host's own frames,
// another engine. A state read inside the run and named nowhere is nobody's
// reason to run, and an engine's own write to a state it follows is no reason
// either: where everything it follows stands is written down AFTER the run,
// so what it changed itself is what it has already seen.
//
// An entry's bookkeeping is touched under the BOARD's hold - Core/Cycle.swift;
// nothing here locks.


/// What drives a cycle. This library's own.
///
/// No raw value: a board is an index the host is handed, never a number on the
/// wire.
public enum Sync: Sendable {
    /// The display's own frame - what every value on screen moves by.
    case display
}

/// What an engine answers about its next cycle. This library's own.
///
/// An ANSWER, not a state: what an engine keeps between cycles lives in a
/// `@State`, and this is one word said at the end of one run.
///
/// **THE WORDS ARE ABOUT WORK, NOT ABOUT MOVEMENT.** An engine with more to do
/// answers `.again` whether or not anything it touches is going anywhere: a
/// page counting how long its room has held still has more to do and moves
/// nothing, and an engine on a clock need not be driving a picture at all.
public enum EngineAnswer: Sendable {
    /// Run me again next cycle, whether or not anything I follow is written:
    /// there is more to do.
    case again

    /// Nothing more to do until a state I follow is written.
    case wait
}

/// What one run of an engine is handed. This library's own.
public struct EngineCycle: Sendable {
    /// Which clock this cycle belongs to.
    public let sync: Sync

    /// Milliseconds on that clock since its first cycle.
    public let now: Double

    /// Milliseconds since THIS ENGINE last ran - nought or more, and never more
    /// than `mostElapsed`.
    ///
    /// Per engine rather than per cycle, because an engine that follows a
    /// value nothing has moved does not run, and the one that does run then
    /// has to be told the whole of the time it missed.
    public let elapsed: Double

    /// The most one cycle is ever told elapsed: a tenth of a second.
    ///
    /// Longer than this is not a slow frame, it is an application that was
    /// asleep - and arithmetic handed a gap of minutes puts whatever it is
    /// moving through the wall. A motion that was interrupted for that long
    /// arrives instead.
    public static let mostElapsed = 100.0

    /// How many cycles this board has run, this one included.
    public let count: UInt64

    /// Whether the reader has asked for less movement, which every engine that
    /// draws a motion has to answer.
    public let reducesMotion: Bool
}

/// What an engine follows: a state's storage, asked one thing - how many
/// times it has been written. This library's own.
///
/// Every `@State` answers it, whatever it holds, so `following:` takes any
/// state at all: an enum naming a step, a rectangle held from the last pass,
/// a number the host walks. What is counted is every write - this side's and
/// the host's, equal bytes included - because an engine that follows a number
/// a finger is holding still is entitled to hear every report.
public protocol FollowedState: AnyObject {
    /// How many times the state has been written.
    var stamp: Int { get }
}

/// An engine as the TREE carries it, before the differ has given it a number.
///
/// The closure captures the view BY VALUE, which is what makes an engine safe
/// to run on the frame thread: everything it reads that can move is a state,
/// and everything else is a copy of what the render saw.
struct EngineDeclaration {
    /// The states whose being written is a reason to run it.
    let follows: [any FollowedState]

    /// Which clock it runs on.
    let sync: Sync

    /// Where it comes in the order, ascending.
    let priority: Double

    /// The arithmetic.
    let run: (EngineCycle) -> EngineAnswer
}

/// One registered engine and everything the board remembers about it.
final class EngineEntry {
    /// What the differ registered it under, which is also its tie-break.
    let id: Int

    /// Where it comes in the order, ascending; ties by `id`.
    let priority: Double

    /// Which clock it runs on.
    let sync: Sync

    /// The arithmetic itself.
    ///
    /// A VAR because a render REWRITES it: the closure captured the view by
    /// value, so the one a render just described is the one holding this
    /// render's captures. An engine under a memo token that held is not
    /// rewritten, and goes on running the captures it had - which is what the
    /// token said.
    var run: (EngineCycle) -> EngineAnswer

    /// The states it was told to follow - by the render that last described
    /// the view, since `following:` is an expression a render evaluates and a
    /// later one may name other states.
    private(set) var follows: [any FollowedState]

    /// The stamps of everything it follows, as they stood when it last ran.
    private var seen: [ObjectIdentifier: Int] = [:]

    /// Whether a render has described the view since it last ran, which is a
    /// reason to run whatever moved.
    var armed = true

    /// Whether its own last answer was `.again`.
    var awake = false

    /// When it last ran, on the board's own clock.
    var lastRan: Double = 0

    init(
        id: Int,
        priority: Double,
        sync: Sync,
        follows: [any FollowedState],
        run: @escaping (EngineCycle) -> EngineAnswer
    ) {

        self.id = id
        self.priority = priority
        self.sync = sync
        self.follows = follows
        self.run = run
    }

    /// Takes the states a fresh render named, where they are not the ones
    /// already followed - and forgets every stamp, so the next cycle runs over
    /// the new list whatever it stands at. A render that named the same states
    /// leaves the stamps alone, or every render would be a reason to run.
    func follow(_ named: [any FollowedState]) {
        guard named.count != follows.count
            || zip(named, follows).contains(where: { $0 !== $1 })
        else { return }

        follows = named
        seen.removeAll()
    }

    /// Whether anything it follows has been written since it last ran.
    func stirred() -> Bool {
        follows.contains { seen[ObjectIdentifier($0)] != $0.stamp }
    }

    /// Writes down where everything it follows stands, now that it has run -
    /// which is what makes its own writes no reason to run again.
    func noticed() {
        for storage in follows {
            seen[ObjectIdentifier(storage)] = storage.stamp
        }
    }
}

/// A state an engine can follow, as `.engine(following:)` takes any number of
/// them. This library's own.
///
/// `Binding` is the one thing that conforms - `$x` on any `@State`, whatever
/// it holds. The protocol exists because the engine's plain form has to take
/// states of DIFFERENT values in one list. A parameter pack says that too, and
/// the form that answers an `EngineAnswer` uses one - but Swift cannot rank two
/// pack overloads against each other for a multi-statement closure, and it
/// cannot rank two existential ones for a closure over two states (both
/// measured as "ambiguous use of 'engine'"). One of each is what it resolves,
/// every time.
public protocol Followable {
    /// The storage the state lives on, asked for its stamp alone - so
    /// following needs nothing about the value's shape, and a journey a slider
    /// walks is followed as readily as a step of a sequence. Nothing for a
    /// part of a state or a binding made from closures, which have no storage
    /// of their own.
    var followed: (any FollowedState)? { get }
}

extension Binding: Followable {}

// MARK: - Attaching one

extension BindableObject {
    /// Arithmetic the host runs on its own frames, whenever a state it follows
    /// has been written.
    ///
    /// **WHAT IS ATTACHED IS AN ENGINE**, and `following:` is a LABEL rather
    /// than part of the name because an engine need not follow anything: one
    /// moved by TIME alone is written `.engine { … }` and answers `.again`,
    /// which a name built around following could not say.
    ///
    /// **WHAT IS NAMED HERE IS WHY IT RUNS, NEVER WHAT IT MAY TOUCH.** The
    /// arithmetic reads whatever the view captured, states included that were
    /// never named here - it simply does not wake when those are written. So
    /// this is a list of reasons and not a scope, which is what a preposition
    /// of place would claim it was. What stands here is `$x` on any `@State`,
    /// whatever it holds - a number the host walks, a rectangle a feed writes,
    /// an enum naming which step a sequence is on - and a write to it is a
    /// signal whoever makes it: a handler, a control reporting, the host's own
    /// frames, another engine. A part of a state (`$room.width`) cannot be
    /// followed and is said out loud. This form takes them as `any Followable`
    /// and the form below as a parameter pack, for the reason `Followable`
    /// gives: Swift resolves one of each and neither two of a kind.
    ///
    ///     .engine(following: $scrolled, $room) { cycle in
    ///         run = PlacedRun(placements(at: scrolled / step, room))
    ///     }
    ///
    /// THE FRAME IS WHERE IT RUNS, not the render: nothing here describes the
    /// interface, so a value a finger is moving can be followed at the
    /// display's own rate. It runs on the cycle after any state it follows was
    /// written, and once after every render that described this view.
    ///
    /// It reads and writes states. A state it writes that a body reads renders,
    /// priced like any other render; one nobody reads costs nothing; one the
    /// host wears is written onto the control on this very frame. It may NOT
    /// await, ask the host to do anything, or touch a control: it runs INSIDE
    /// the frame the platform is drawing, and everything it needs has to be on
    /// a state already. The view is captured BY VALUE, so anything it must
    /// remember between cycles lives in a `@State`.
    ///
    /// Write it as often as there is arithmetic to run. Engines run in
    /// ascending `priority`, ties in the order they were first registered, so
    /// one that reads what another wrote in the same cycle says a higher
    /// number. Each is paired with its predecessor by the order the modifiers
    /// appear in - so a `.engine(following:)` under an `if` changes how many
    /// there are, and every one of them starts over.
    ///
    /// - Parameters:
    ///   - first: a state whose being written is a reason to run.
    ///   - more: any others.
    ///   - sync: which clock it runs on. The display's own frame today.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, handed the instant and how long it has been.
    public func engine(
        following first: any Followable,
        _ more: any Followable...,
        sync: Sync = .display,
        priority: Double = 0,
        _ run: @escaping (EngineCycle) -> Void
    ) -> Modified {
        let named = [first] + more
        let follows = named.compactMap(\.followed)

        if follows.count < named.count {
            complain("`following:` was handed a part of a state, or a binding made "
                + "from closures, which has no storage of its own to be woken by. "
                + "Follow the whole state.")
        }

        return modified {
            $0.engines.append(EngineDeclaration(
                follows: follows,
                sync: sync,
                priority: priority,
                run: { cycle in
                    run(cycle)
                    return .wait
                }))
        }
    }

    /// The same, answering whether it has more to do.
    ///
    ///     .engine { cycle in
    ///         body.step(cycle.elapsed / 1000) { _ in Point(0, 9.8) }
    ///         return body.isStill() ? .wait : .again
    ///     }
    ///
    /// `.again` holds the frame clock, so this runs again next cycle however
    /// still everything it follows is; `.wait` lets it go, until a state it
    /// follows is written. That is what a motion of its own needs - a body
    /// under gravity is moved by TIME rather than by anything being written -
    /// and it is why `following:` may be left out here and cannot be left out
    /// above: an engine that answers nothing and follows nothing would never
    /// run at all.
    ///
    /// NOTHING BOUNDS HOW LONG. An engine that goes on answering `.again`
    /// holds the frame clock until it answers `.wait`, and one that keeps the
    /// display awake for a picture that is not changing is a battery being
    /// spent on nothing.
    ///
    /// A SEQUENCE IS A STATE THIS ENGINE FOLLOWS AND WRITES: an enum naming
    /// the step, named in `following:` so a handler moving it wakes the
    /// engine, and written inside the run to move on - which wakes nothing,
    /// this engine having made the write itself.
    ///
    ///     enum Step { case waiting, counting, done }
    ///
    ///     @State private var step = Step.waiting
    ///     @State private var counted = 0.0
    ///
    ///     .engine(following: $step) { cycle in
    ///         switch step {
    ///         case .waiting: return .wait
    ///         case .counting where counted >= 400: step = .done
    ///         case .counting: counted += cycle.elapsed
    ///         case .done: return .wait
    ///         }
    ///         return .again
    ///     }
    ///
    /// A `@State` AN ENGINE READS AND DOES NOT FOLLOW IS RECORDED NOWHERE. The
    /// engine runs on the host's own frames, outside every render, so a state
    /// the arithmetic looks up inside here is a read no walk knows about:
    /// writing it rebuilds nothing, arms no engine, and leaves the picture as
    /// the last run left it. A value the arithmetic needs is either FOLLOWED -
    /// named in `following:`, which is what wakes the engine when it is
    /// written - or read in the BODY and handed over as a local, which is also
    /// what makes the closure this render's, with this render's values in it.
    ///
    /// - Parameters:
    ///   - following: the states whose being written is a reason to run. May
    ///     be none.
    ///   - sync: which clock it runs on. The display's own frame today.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next cycle.
    public func engine<each Value>(
        following: repeat Binding<each Value>,
        sync: Sync = .display,
        priority: Double = 0,
        _ run: @escaping (EngineCycle) -> EngineAnswer
    ) -> Modified {
        var follows: [any FollowedState] = []
        var named = 0

        for storage in repeat (each following).followed {
            named += 1

            if let storage { follows.append(storage) }
        }

        if follows.count < named {
            complain("`following:` was handed a part of a state, or a binding made "
                + "from closures, which has no storage of its own to be woken by. "
                + "Follow the whole state.")
        }

        return modified {
            $0.engines.append(EngineDeclaration(
                follows: follows,
                sync: sync,
                priority: priority,
                run: run))
        }
    }
}
