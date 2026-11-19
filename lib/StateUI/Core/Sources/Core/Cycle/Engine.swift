// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The engine: the application's arithmetic, run on the host's frames whenever a
// state it follows was written - the work-out step of the cycle.
// Design: docs/design/core/cycle.md#engines


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

/// What one run of an engine is handed, on the display's frame. This library's own.
public struct EngineCycle: Sendable {
    /// Seconds on the display's clock, as the host tells them; never before the last cycle's.
    public var nowSeconds: Double { now / 1000 }

    /// Seconds since this engine last ran - nought or more, never more than
    /// `mostElapsedSeconds`. Per engine: one that did not run is told the time it missed.
    public var elapsedSeconds: Double { elapsed / 1000 }

    /// The display's clock, in the host's milliseconds.
    let now: Double

    /// Milliseconds since this engine last ran.
    let elapsed: Double

    /// The most one cycle is told elapsed: a tenth of a second. A longer gap is an
    /// application that was asleep, and an animation interrupted that long arrives.
    public static let mostElapsedSeconds = mostElapsedMilliseconds / 1000

    /// The same, on the host's clock.
    static let mostElapsedMilliseconds = 100.0

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

    /// How many of those writes were the host's reports.
    var reports: Int { get }
}

/// An engine as the tree carries it, before the differ numbers it. Its closure
/// captured the view by value.
@MainActor
struct EngineDeclaration {
    /// The states whose being written is a reason to run it.
    let follows: [any FollowedState]

    /// The journeys it follows: each state's channel has it for a consumer while its element stands.
    var consumes: [JourneyConsumer] = []

    /// The state it animates, where it is a state's animator: what claims the seat as it is armed.
    var animates: AnimatorClaim? = nil

    /// Where it comes in the order, ascending.
    let priority: Double

    /// The arithmetic.
    let run: @MainActor (EngineCycle) -> EngineAnswer
}

/// A journey something mounted consumes with no property showing its state: an engine following it, a reading.
/// Design: docs/design/core/journeys.md#a-channels-life
@MainActor
struct JourneyConsumer {
    /// The image the host carries the state on as a journey, made as the consumer mounts; nil where the host
    /// carries the state as the value itself.
    let image: () -> HostStorage?

    /// What the host reads the value's lanes as.
    let laneKind: LaneKind

    /// The consumer of `journey`'s channel.
    init<Value: Walked>(of journey: Journey<Value>) {
        let storage = journey.storage
        image = { storage.carryAsJourney() }
        laneKind = Value.laneKind
    }
}

/// One registered engine and everything the board remembers about it: a value in
/// the board's book, its reasons to run read and written by the board alone.
/// Design: docs/design/core/cycle.md#the-board
@MainActor
struct EngineEntry {
    /// What the differ registered it under, which is also its tie-break.
    let id: Int

    /// Where it comes in the order, ascending; ties by `id` - the last render's.
    var priority: Double

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

    /// Whether it is a state's animator: animators run first, on the frame before, and are published together.
    /// Design: docs/design/core/cycle.md#engine-order
    var animates = false

    /// What lets go of what it claimed as it is forgotten.
    var released: (() -> Void)?

    /// When it last ran, on the board's own clock.
    var lastRan: Double = 0

    init(
        id: Int,
        priority: Double,
        follows: [any FollowedState],
        run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) {

        self.id = id
        self.priority = priority
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
        armed || awake || stirred
    }

    /// Whether it was armed or a state it follows was written since it last ran: a reason a turn answers at once,
    /// where one going on of its own waits for the display's frame.
    var asked: Bool {
        armed || stirred
    }

    /// Whether a state it follows was written since it last ran.
    private var stirred: Bool {
        follows.contains { seen[ObjectIdentifier($0)] != $0.stamp }
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
    ///     .engine(following: $scrolled) { _ in
    ///         backdrop = scrolled * 0.4      // the backdrop follows the scroll, slower
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
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, handed the instant and how long it has been.
    public func engine<First, each More>(
        following first: Binding<First>,
        _ more: repeat Binding<each More>,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> Void
    ) -> Modified {
        var follows = [first.followed]
        for storage in repeat (each more).followed { follows.append(storage) }

        return engine(follows, priority: priority) { cycle in
            run(cycle)
            return .wait
        }
    }

    /// An engine that keeps tracking: it answers on each cycle whether it has more to
    /// do.
    ///
    ///     .engine(tracking: $running) { cycle in
    ///         guard running else { return .wait }
    ///
    ///         elapsed += cycle.elapsedSeconds
    ///         reading = "\(Int(elapsed)) s"
    ///         return .again
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
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next cycle.
    public func engine<each Value>(
        tracking: repeat Binding<each Value>,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Modified {
        var follows: [any FollowedState] = []
        for storage in repeat (each tracking).followed { follows.append(storage) }

        return engine(follows, priority: priority, run)
    }

    /// Registers an engine woken by the writes of the states it `follows`, a consumer of the journeys it `consumes`.
    func engine(
        _ follows: [any FollowedState], consuming consumes: [JourneyConsumer] = [], priority: Double,
        _ run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Modified {
        modified {
            $0.engines.append(EngineDeclaration(follows: follows, consumes: consumes, priority: priority, run: run))
        }
    }
}

// MARK: - Following where a state is shown

extension ModifiableElement {
    /// Arithmetic the host runs on its own frames, whenever where it shows a
    /// state has changed: a frame of the value's movement, or the state coming
    /// to be shown or ceasing to be.
    ///
    ///     Text($caption)
    ///         .engine(following: $x.journey, $y.journey) { _ in
    ///             guard let x = $x.journey.sample, let y = $y.journey.sample else { return }
    ///             caption = "\(Int(x.value)), \(Int(y.value))"
    ///         }
    ///
    /// Following `$x` wakes it on a write of the destination; following
    /// `$x.journey` wakes it on a frame. While its view stands the engine is a
    /// consumer of each journey: the host carries the state for it though no
    /// property shows it. Every sample it reads in one run is of one frame. For
    /// a number that must match the sample, write `output.journey.snap(to:)`.
    ///
    /// - Parameters:
    ///   - first: a journey whose sample changing is a reason to run.
    ///   - more: any others.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, handed the instant and how long it has been.
    public func engine<First: Walked, each More: Walked>(
        following first: Journey<First>,
        _ more: repeat Journey<each More>,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> Void
    ) -> Modified {
        engine(tracking: first, repeat each more, priority: priority) { cycle in
            run(cycle)
            return .wait
        }
    }

    /// An engine following where states are shown that keeps tracking: it
    /// answers on each cycle whether it has more to do.
    ///
    /// - Parameters:
    ///   - first: a journey whose sample changing is a reason to run.
    ///   - more: any others.
    ///   - priority: where it comes in the order, ascending. 0 unless said.
    ///   - run: the arithmetic, answering whether to run again next cycle.
    public func engine<First: Walked, each More: Walked>(
        tracking first: Journey<First>,
        _ more: repeat Journey<each More>,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Modified {
        var follows: [any FollowedState] = [first.storage.presentation]
        var consumes = [JourneyConsumer(of: first)]
        for journey in repeat each more {
            follows.append(journey.storage.presentation)
            consumes.append(JourneyConsumer(of: journey))
        }

        return engine(follows, consuming: consumes, priority: priority, run)
    }
}
