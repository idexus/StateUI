// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// THE ENGINE: arithmetic the host runs on its own frames.
//
// An engine is a closure attached to a view with `.engine(following:)`, and it
// is the WORK OUT of the cycle beside this file - the only place in this
// library where arithmetic runs outside a render. What it may do is narrow on
// purpose: read states and its own memory, write states, and say whether it
// has more to do. It may not await, ask the host for anything, or touch a
// control, because it runs INSIDE the frame the platform is drawing.
//
// Four things make one up, and they are what this file holds:
//
//   WHAT IT IS HANDED    `EngineCycle` - the instant, and how long since IT ran.
//   WHAT IT ANSWERS      `EngineAnswer` - run me again, or let the clock go.
//   WHAT IT REMEMBERS    `@Memory` - memory across cycles, which an engine
//                        that READ one thereby follows.
//   HOW IT IS DECLARED   `EngineDeclaration`, and `EngineEntry` once it is live.
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
/// An ANSWER, not a state: `Memory` is the memory an engine keeps BETWEEN
/// cycles, which is a different thing and wears that name. This is one word
/// said at the end of one run.
///
/// **THE WORDS ARE ABOUT WORK, NOT ABOUT MOVEMENT.** An engine with more to do
/// answers `.running` whether or not anything it touches is going anywhere: a
/// page counting how long its room has held still is running and moving
/// nothing, and an engine on a clock need not be driving a picture at all.
/// `.still` would also be a second meaning for a word `AnimatedValue` already
/// uses for a speed of nought.
public enum EngineAnswer: Sendable {
    /// Run me again next cycle: there is more to do.
    case running

    /// Nothing more to do until something I follow moves.
    case idle
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

/// What is being run right now, so a read can say who read it.
///
/// An engine FOLLOWS whatever it read on its last run, and this is how that is
/// noticed: the run is bracketed, and every `@Memory` read inside the
/// bracket is recorded against it. A read outside one records nothing, which
/// is what a handler's read is. A `@State` read inside the bracket is recorded
/// nowhere either, whatever it asks - see Core/Memory.swift for why.
enum EngineScope {
    /// What is running, if anything is. One board runs one engine at a time,
    /// and there is one board today - a second one would run on a thread of
    /// its own, and this would have to move with it.
    nonisolated(unsafe) static var running: EngineEntry?

    /// Records that the engine now running read this state.
    static func read(_ storage: AnyMemoryStorage) {
        running?.read(storage)
    }
}

/// An engine as the TREE carries it, before the differ has given it a number.
///
/// The closure captures the view BY VALUE, which is what makes an engine safe
/// to run on the frame thread: everything it reads that can move is a state or a
/// `@Memory`, and everything else is a copy of what the render saw.
struct EngineDeclaration {
    /// The states whose movement is a reason to run it - by the images the
    /// host carries them on.
    let follows: [HostStorage]

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

    /// What the author calls the view that declared it, for a complaint that
    /// has to name one.
    let origin: String?

    /// The states it was told to follow, by their images.
    let follows: [HostStorage]

    /// The `@Memory`s it read on its last run, weakly - it follows those
    /// too, and a state nothing else holds is one the engine has let go of.
    private var states: [WeakMemory] = []

    /// Which of `states` this run has read so far - what `noticed()` keeps.
    /// A state read on an earlier run and not on this one is dropped there,
    /// so what the engine follows is what it read on its LAST run and nothing
    /// older: an arm not taken this time leaves nothing behind to wake it.
    private var readNow: Set<ObjectIdentifier> = []

    /// The stamps of everything it follows, as they stood when it last ran.
    private var seen: [ObjectIdentifier: Int] = [:]

    /// Whether a render has described the view since it last ran, which is a
    /// reason to run whatever moved.
    var armed = true

    /// Whether its own last answer was `.running`.
    var awake = false

    /// When it last ran, on the board's own clock.
    var lastRan: Double = 0

    init(
        id: Int,
        priority: Double,
        sync: Sync,
        follows: [HostStorage],
        origin: String?,
        run: @escaping (EngineCycle) -> EngineAnswer
    ) {

        self.id = id
        self.priority = priority
        self.sync = sync
        self.follows = follows
        self.origin = origin
        self.run = run
    }

    /// Records that this run read a `@Memory`.
    func read(_ storage: AnyMemoryStorage) {
        readNow.insert(ObjectIdentifier(storage))

        guard !states.contains(where: { $0.storage === storage }) else { return }

        states.append(WeakMemory(storage: storage))
    }

    /// Whether anything it follows has been written since it last ran.
    func stirred() -> Bool {
        for storage in follows where seen[ObjectIdentifier(storage)] != storage.stamp {
            return true
        }

        for state in states {
            guard let storage = state.storage else { continue }

            if seen[ObjectIdentifier(storage)] != storage.stamp { return true }
        }

        return false
    }

    /// Writes down where everything it follows stood, now that it has run.
    func noticed() {
        for storage in follows {
            seen[ObjectIdentifier(storage)] = storage.stamp
        }

        // Dead, or not read this run: either way nothing this engine should
        // be woken by any more.
        states.removeAll { read in
            guard let storage = read.storage else { return true }

            return !readNow.contains(ObjectIdentifier(storage))
        }
        readNow.removeAll(keepingCapacity: true)

        for state in states {
            guard let storage = state.storage else { continue }

            seen[ObjectIdentifier(storage)] = storage.stamp
        }
    }

    /// A `@Memory` an engine read, held weakly.
    private struct WeakMemory {
        weak var storage: AnyMemoryStorage?
    }
}

/// A state an engine can follow, as `.engine(following:)` takes any number of
/// them. This library's own.
///
/// `Binding` is the one thing that conforms - `$x` on any `@State` whose value
/// the host can hold - so "followable" and "carried by the host" are one set,
/// and following a state is what asks the host to carry it. The protocol
/// exists because the engine's plain form has to take states of DIFFERENT
/// values in one list. A parameter pack says that too, and the form that
/// answers an `EngineAnswer` uses one - but Swift cannot rank two pack
/// overloads against each other for a multi-statement closure, and it cannot
/// rank two existential ones for a closure over two states (both measured as
/// "ambiguous use of 'engine'"). One of each is what it resolves, every time.
public protocol Followable {
    /// The image the host carries the value on, WHATEVER ITS SHAPE - a
    /// journey's, where a slider or a stepper walks the state, or the value's
    /// own - since following needs the stamp and nothing about the lanes.
    /// Nothing for a part of a state or a binding made from closures, which
    /// the host cannot be handed whole.
    var followed: HostStorage? { get }
}

extension Binding: Followable where Value: StateValue {}

// MARK: - Attaching one

extension BindableObject {
    /// Arithmetic the host runs on its own frames, whenever a state it follows
    /// has been written.
    ///
    /// **WHAT IS ATTACHED IS AN ENGINE**, and `@Memory` is the memory it keeps
    /// between cycles. `following:` is a LABEL rather than part of the name
    /// because an engine need not follow anything: one moved by TIME alone is
    /// written `.engine { … }` and answers `.running`, which a name built around
    /// following could not say.
    ///
    /// **WHAT IS NAMED HERE IS WHY IT RUNS, NEVER WHAT IT MAY TOUCH.** The
    /// arithmetic reads whatever the view captured, states included that were
    /// never named here - it simply does not wake when those move. So this is a
    /// list of reasons and not a scope, which is what a preposition of place
    /// would claim it was. What stands here is `$x` on a `@State` whose value
    /// the host can hold, and naming it is what has the host carry it: from
    /// then on a write to it wakes this engine and, being read at no build,
    /// asks for no render. A part of a state (`$room.width`) cannot be
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
    /// display's own rate. It runs on the cycle after any state it follows or
    /// any `@Memory` it read was written, and once after every render that
    /// described this view.
    ///
    /// It reads and writes states and `@Memory`, and may write `@State` - a
    /// render then follows, priced like any other. It may NOT await, ask the
    /// host to do anything, or touch a control: it runs INSIDE the frame the
    /// platform is drawing, and everything it needs has to be on a state already.
    /// The view is captured BY VALUE, so anything it must remember between
    /// cycles lives in a followed `@State` or a `@Memory`.
    ///
    /// Write it as often as there is arithmetic to run. Engines run in
    /// ascending `priority`, ties in the order they were first registered, so
    /// one that reads what another wrote in the same cycle says a higher
    /// number. Each is paired with its predecessor by the order the modifiers
    /// appear in - so a `.engine(following:)` under an `if` changes how many there are,
    /// and every one of them starts over.
    ///
    /// - Parameters:
    ///   - first: a state whose movement is a reason to run.
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
            complain("`following:` was handed a state the host cannot carry - a part "
                + "of a state, or a binding made from closures - and cannot be "
                + "woken by it. Follow the whole state.")
        }

        return modified {
            $0.engines.append(EngineDeclaration(
                follows: follows,
                sync: sync,
                priority: priority,
                run: { cycle in
                    run(cycle)
                    return .idle
                }))
        }
    }

    /// The same, answering whether it has more to do.
    ///
    ///     .engine { cycle in
    ///         body.step(cycle.elapsed / 1000) { _ in Point(0, 9.8) }
    ///         return body.isStill() ? .idle : .running
    ///     }
    ///
    /// `.running` holds the frame clock, so this runs again next frame however
    /// still everything it follows is; `.idle` lets it go. That is what a
    /// motion of its own needs - a body under gravity is moved by TIME rather
    /// than by anything being written - and it is why `following:` may be left
    /// out here and cannot be left out above: an engine that answers nothing and
    /// follows nothing would never run at all.
    ///
    /// NOTHING BOUNDS HOW LONG. An engine that goes on answering `.running`
    /// holds the frame clock until it answers `.idle`, and one that keeps the
    /// display awake for a picture that is not changing is a battery being
    /// spent on nothing.
    ///
    /// A `@State` AN ENGINE READS AND DOES NOT FOLLOW IS RECORDED NOWHERE. The
    /// engine runs on the host's own frames, outside every render, so a state
    /// the arithmetic looks up inside here is a read no walk knows about:
    /// writing it rebuilds nothing, arms no engine, and leaves the picture as
    /// the last run left it. A value the arithmetic needs is either FOLLOWED -
    /// named in `following:`, which is what wakes the engine when it moves -
    /// or read in the BODY and handed over as a local, which is also what
    /// makes the closure this render's, with this render's values in it.
    ///
    /// - Parameters:
    ///   - following: the states whose movement is a reason to run. May be none.
    ///   - sync: which clock it runs on. The display's own frame today.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next frame.
    public func engine<each Value: StateValue>(
        following: repeat Binding<each Value>,
        sync: Sync = .display,
        priority: Double = 0,
        _ run: @escaping (EngineCycle) -> EngineAnswer
    ) -> Modified {
        var follows: [HostStorage] = []
        var named = 0

        for image in repeat (each following).followed {
            named += 1

            if let image { follows.append(image) }
        }

        if follows.count < named {
            complain("`following:` was handed a state the host cannot carry - a part "
                + "of a state, or a binding made from closures - and cannot be "
                + "woken by it. Follow the whole state.")
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
