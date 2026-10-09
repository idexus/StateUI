// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The engine: the application's arithmetic, run on the host's frames whenever a
// state it follows was written - the work-out step of the cycle.
// Design: docs/design/core/cycle.md#engines


/// What drives a cycle. This library's own: a host names the one it runs, and
/// the board behind it stays the library's.
public enum Sync: Sendable {
    /// The display's own frame - what every value on screen moves by.
    case display
}

/// What an engine answers about its next cycle. This library's own.
///
/// The words are about work, not movement: an engine with more to do answers
/// `.again` whether or not anything it touches is moving.
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

    /// Milliseconds on that clock, as the host tells them; never before the last cycle's.
    public let now: Double

    /// Milliseconds since this engine last ran - nought or more, never more than
    /// `mostElapsed`. Per engine: one that did not run is told the time it missed.
    public let elapsed: Double

    /// The most one cycle is told elapsed: a tenth of a second. A longer gap is an
    /// application that was asleep, and an animation interrupted that long arrives.
    public static let mostElapsed = 100.0

    /// How many cycles this board has run, this one included.
    public let count: UInt64

    /// Whether the user asked for less motion, which every engine that draws motion
    /// answers.
    public let reducesMotion: Bool
}

/// What an engine follows: a state's storage, asked how many times it was written -
/// this side's and the host's, equal bytes included.
@MainActor
protocol FollowedState: AnyObject {
    /// How many times the state has been written.
    var stamp: Int { get }
}

/// An engine as the tree carries it, before the differ numbers it. Its closure
/// captured the view by value.
@MainActor
struct EngineDeclaration {
    /// The states whose being written is a reason to run it.
    let follows: [any FollowedState]

    /// Which clock it runs on.
    let sync: Sync

    /// Where it comes in the order, ascending.
    let priority: Double

    /// The arithmetic.
    let run: @MainActor (EngineCycle) -> EngineAnswer
}

/// One registered engine and everything the board remembers about it: a value in
/// the board's book, its reasons to run read and written by the board alone.
/// Design: docs/design/core/cycle.md#the-board
@MainActor
struct EngineEntry {
    /// What the differ registered it under, which is also its tie-break.
    let id: Int

    /// Where it comes in the order, ascending; ties by `id`.
    let priority: Double

    /// Which clock it runs on.
    let sync: Sync

    /// The arithmetic - rewritten by each render that describes the view, with that
    /// render's captures.
    var run: @MainActor (EngineCycle) -> EngineAnswer

    /// The states it follows, as the last render that described the view named them.
    private(set) var follows: [any FollowedState]

    /// The stamps of everything it follows, as they stood when it last ran.
    private var seen: [ObjectIdentifier: Int] = [:]

    /// Whether a render described the view since it last ran.
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
        run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) {

        self.id = id
        self.priority = priority
        self.sync = sync
        self.follows = follows
        self.run = run
    }

    /// Takes the states a render named, forgetting every stamp where they differ from
    /// those followed.
    /// Design: docs/design/core/cycle.md#what-wakes-an-engine
    mutating func follow(_ named: [any FollowedState]) {
        guard named.count != follows.count
            || zip(named, follows).contains(where: { $0 !== $1 })
        else { return }

        follows = named
        seen.removeAll()
    }

    /// Whether it has a reason to run: a render armed it, its last answer was
    /// `.again`, or anything it follows has been written since it last ran.
    var due: Bool {
        armed || awake || follows.contains { seen[ObjectIdentifier($0)] != $0.stamp }
    }

    /// Notes that it ran at `now` and what it answered, and where everything it
    /// follows stands - after the run, so its own writes are no reason to run again.
    mutating func ran(at now: Double, answering answer: EngineAnswer) {
        for storage in follows {
            seen[ObjectIdentifier(storage)] = storage.stamp
        }

        lastRan = now
        armed = false
        awake = answer == .again
    }
}

// MARK: - Attaching one

extension ModifiableElement {
    /// Arithmetic the host runs on its own frames, whenever a state it follows has
    /// been written.
    ///
    ///     .engine(following: $scrolled, $room) { cycle in
    ///         run = PlacedRun(placements(at: scrolled / step, room))
    ///     }
    ///
    /// `following:` names why it runs, not what it may touch: the arithmetic reads
    /// whatever the view captured, and wakes only when a followed state is written,
    /// by anyone. It runs on the cycle after such a write and once after every
    /// render that describes this view. It reads and writes states; it may not
    /// await, ask the host for anything, or touch a control, because it runs inside
    /// the frame the platform draws. Anything it remembers between cycles lives in
    /// a `@State`.
    ///
    /// Engines run in ascending `priority`, ties in the order first registered. Each
    /// is paired with its predecessor by the order the modifiers appear in, so one
    /// under an `if` makes every engine of the view start over.
    ///
    /// - Parameters:
    ///   - first: a state whose being written is a reason to run.
    ///   - more: any others.
    ///   - sync: which clock it runs on. The display's own frame.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, handed the instant and how long it has been.
    public func engine<First, each More>(
        following first: Binding<First>,
        _ more: repeat Binding<each More>,
        sync: Sync = .display,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> Void
    ) -> Modified {
        var follows = [first.followed]
        for storage in repeat (each more).followed { follows.append(storage) }

        return engine(follows, sync: sync, priority: priority) { cycle in
            run(cycle)
            return .wait
        }
    }

    /// An engine that keeps tracking: it answers on each cycle whether it has more to
    /// do.
    ///
    ///     .engine { cycle in
    ///         body.step(cycle.elapsed / 1000) { _ in Point(0, 9.8) }
    ///         return body.isStill() ? .wait : .again
    ///     }
    ///
    /// `.again` holds the frame clock and runs next cycle; `.wait` lets it go until a
    /// tracked state is written - so `tracking:` may be left out, for a motion moved
    /// by time alone. Nothing bounds how long `.again` holds the clock. A sequence is
    /// a state the engine tracks and writes: a handler moving it wakes the engine,
    /// and the engine's own write wakes nothing.
    ///
    /// A `@State` the engine reads and does not track is recorded nowhere: writing
    /// it wakes nothing. Track it, or read it in the body and hand it over.
    ///
    /// - Parameters:
    ///   - tracking: the states whose being written is a reason to run. May be none.
    ///   - sync: which clock it runs on. The display's own frame.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next cycle.
    public func engine<each Value>(
        tracking: repeat Binding<each Value>,
        sync: Sync = .display,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Modified {
        var follows: [(any FollowedState)?] = []
        for storage in repeat (each tracking).followed { follows.append(storage) }

        return engine(follows, sync: sync, priority: priority, run)
    }

    /// Registers an engine woken by `named`'s writes; a part of a state or a binding made from closures is
    /// refused, said once.
    private func engine(
        _ named: [(any FollowedState)?], sync: Sync, priority: Double,
        _ run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Modified {
        let follows = named.compactMap { $0 }

        if follows.count < named.count {
            complain("An engine was handed a part of a state, or a binding made "
                + "from closures, which has no storage of its own to be woken by. "
                + "Follow the whole state.")
        }

        return modified {
            $0.engines.append(EngineDeclaration(follows: follows, sync: sync, priority: priority, run: run))
        }
    }
}
