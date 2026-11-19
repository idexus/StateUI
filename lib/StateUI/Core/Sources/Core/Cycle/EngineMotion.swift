// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An engine that animates a state: the one executor of a state declared `@State(animatedBy: .engine)`.
// Design: docs/design/core/journeys.md#an-engine-that-animates

/// What an engine animating a state reads and writes on one of its frames -
/// handed to the closure of `engine(animating:)`, and good for that call alone.
///
///     .engine(animating: $ball) { cycle, motion in
///         let seconds = cycle.elapsedSeconds
///         let pull = (motion.destination - motion.value) * 180 - motion.velocity * 24
///         let velocity = motion.velocity + pull * seconds
///         let value = motion.value + velocity * seconds
///         guard abs(motion.destination - value) > 0.5 || abs(velocity) > 1 else {
///             motion.finish()
///             return .wait
///         }
///         motion.update(value: value, velocity: velocity)
///         return .again
///     }
///
/// Kept past its call it writes nothing: a later frame has a token of its own.
@MainActor
public struct EngineMotion<Value: Walked> {
    let storage: State<Value>.Storage

    /// The call it is good for.
    let token: Int

    /// Where the engine last put the value.
    public var value: Value { storage.journeyLanes?.value ?? storage.value }

    /// Where the value is to go: the state's own value.
    public var destination: Value { storage.journeyLanes?.destination ?? storage.value }

    /// The speed the engine last gave it, per second, lane by lane.
    public var velocity: Value { storage.journeyLanes?.velocity ?? JourneyLanes<Value>.still }

    /// Puts the value where this frame shows it, at the speed it now has. It
    /// writes no destination. The host shows it on this frame, and whoever
    /// follows the journey reads it as the frame's sample.
    ///
    /// - Parameters:
    ///   - value: where the value stands on this frame.
    ///   - velocity: how fast it goes, per second.
    public func update(value: Value, velocity: Value) {
        guard let seat = storage.animatorSeat, seat.admits(token), var lanes = storage.journeyLanes else { return }

        lanes.value = value
        lanes.velocity = velocity
        storage.lay([.value, .velocity], of: lanes)
        storage.offerSample(of: lanes)
    }

    /// Ends the movement: the value stands at its destination, still, and
    /// whoever awaits a `move` of it hears `.reached(.animated)` once the host
    /// has shown that frame.
    public func finish() {
        finish(as: .animated)
    }

    /// Lands the value on its destination and answers the movements handed to the engine `outcome`.
    func finish(as outcome: HostMotionOutcome) {
        guard let seat = storage.animatorSeat, seat.admits(token), var lanes = storage.journeyLanes else { return }

        lanes.value = lanes.destination
        lanes.velocity = JourneyLanes<Value>.still
        storage.lay([.value, .velocity], of: lanes)
        storage.offerSample(of: lanes)
        seat.end(outcome, afterPresentation: true)
    }
}

/// What a state an engine animates keeps of its animator: who it is, the call under way, and the movements handed
/// to it that await their end.
/// Design: docs/design/core/journeys.md#an-engine-that-animates
@MainActor
final class AnimatorSeat {
    /// The engine registered as the animator, and where it is declared; nil while none is.
    private(set) var engine: (id: Int, place: String)?

    /// The call under way, or nil between calls: a token of another call writes nothing.
    private var live: Int?

    /// How many calls were made.
    private var calls = 0

    /// The waiters of the movements handed to the engine, by the ids they were booked under.
    private var runs: [Int] = []

    /// Whether an animator is registered.
    var isTaken: Bool { engine != nil }

    /// Registers the engine `id`, declared at `place`; answers why not where another holds the seat.
    func claim(_ id: Int, at place: String) -> String? {
        if let engine, engine.id != id {
            return "A state has one animator: `engine(animating:)` at \(place) was refused, as the one at "
                + "\(engine.place) animates it already."
        }
        engine = (id, place)
        return nil
    }

    /// The engine `id` left with its element: the movements handed to it end `.detached`.
    func release(_ id: Int) {
        guard engine?.id == id else { return }

        engine = nil
        end(.detached, afterPresentation: false)
    }

    /// Opens a call and answers its token.
    func open() -> Int {
        calls &+= 1
        live = calls
        return calls
    }

    /// Closes the call under way: its token is void from here.
    func close() {
        live = nil
    }

    /// Whether `token` is the call under way.
    func admits(_ token: Int) -> Bool { live == token }

    /// Books a movement handed to the engine, to be answered as the engine finishes.
    func book(_ run: MotionRun) {
        runs.append(Renderer.shared.book { run.land($0) })
    }

    /// Answers every movement handed to the engine `outcome`: once the host has shown the frame, or at once.
    func end(_ outcome: HostMotionOutcome, afterPresentation: Bool) {
        let ended = runs
        runs = []
        for id in ended {
            if afterPresentation {
                Renderer.shared.board.finished.append(HostFinishedMotion(completion: id, outcome: outcome))
            } else {
                HostBoundary.complete(id, as: outcome)
            }
        }
    }
}

/// What registers an engine as a state's animator, without the state's type.
@MainActor
struct AnimatorClaim {
    /// Registers the engine under `id`, declared at the place named; answers why not, or nil.
    let claim: (_ id: Int, _ place: String) -> String?

    /// Lets the seat go as the engine `id` leaves.
    let release: (_ id: Int) -> Void
}

extension State.Storage where Value: Walked {
    /// The seat of this state's animator, made as one is first asked for.
    var seat: AnimatorSeat {
        if let made = animatorSeat { return made }

        let made = AnimatorSeat()
        animatorSeat = made
        return made
    }

    /// What claims this state's animator's seat for an engine.
    var animatorClaim: AnimatorClaim {
        AnimatorClaim(
            claim: { [weak self] id, place in
                guard let self else { return nil }
                guard law.kind == .custom else {
                    return "`engine(animating:)` at \(place) was given `\(origin ?? "a state")`, which the host "
                        + "animates. Declare it `@State(animatedBy: .engine)`."
                }
                return seat.claim(id, at: place)
            },
            release: { [weak self] id in self?.animatorSeat?.release(id) })
    }

    /// One frame of the animator: `run` handed a token good for this call. Where the user asks for less motion the
    /// value is landed here and the author's arithmetic is not run.
    func animate(
        _ cycle: EngineCycle, _ run: @MainActor (EngineCycle, EngineMotion<Value>) -> EngineAnswer
    ) -> EngineAnswer {
        guard journeyed else { return .wait }

        let motion = EngineMotion(storage: self, token: seat.open())
        defer { seat.close() }

        if cycle.reducesMotion {
            motion.finish(as: .immediate(.reducedMotion))
            return .wait
        }
        return run(cycle, motion)
    }

    /// Offers where the engine put the value as this frame's sample: published with every animator's, once they
    /// have all run.
    func offerSample(of lanes: JourneyLanes<Value>) {
        guard let image, case .lanes(let numbers) = lanes.carried(in: .current) else { return }

        let width = Value.lanes
        let sample = HostSample(
            value: Array(numbers[0..<width]), destination: Array(numbers[width..<(width * 2)]),
            velocity: Array(numbers[(width * 2)..<(width * 3)]))
        Renderer.shared.board.offer { [weak image] in image?.took(sample) }
    }

    /// Hands a destination to the engine that animates this state, as `move(to:)` does: written, and the movement
    /// answered as the engine finishes. With no animator registered the host shows it at once, and says so.
    func hand(_ target: Value, toTheEngineOn image: HostStorage) -> MotionRun {
        guard seat.isTaken else {
            complain("`\(origin ?? "a state")` is animated by an engine - `@State(animatedBy: .engine)` - and no "
                + "`engine(animating:)` is registered for it: its destination is shown at once.")
            write(target)
            askForRender()
            return MotionRun(ended: .notStarted(.noAnimator))
        }

        // The destination first: a newer one ends the movements handed over before it.
        write(target)
        askForRender()
        let run = MotionRun()
        seat.book(run)
        return run
    }

    /// Stops the engine's movement where it stands: the destination is where the value is, and whoever waits
    /// hears `.stopped`.
    func stopTheEngine() {
        guard var lanes = journeyLanes else { return }

        animatorSeat?.end(.stopped, afterPresentation: false)
        lanes.destination = lanes.value
        lay([.destination], of: lanes)
        noteDestination(lanes.destination)
        askForRender()
    }
}

extension ModifiableElement {
    /// The engine that animates a state: on the host's frames it says where
    /// the value stands and how fast it goes, until it finishes.
    ///
    ///     @State(animatedBy: .engine) private var ball = 0.0
    ///
    ///     Rectangle()
    ///         .translationY($ball)
    ///         .engine(animating: $ball) { cycle, motion in
    ///             let step = (motion.destination - motion.value) * min(cycle.elapsedSeconds * 12, 1)
    ///             guard abs(motion.destination - motion.value) > 0.5 else {
    ///                 motion.finish()
    ///                 return .wait
    ///             }
    ///             motion.update(value: motion.value + step, velocity: step / max(cycle.elapsedSeconds, 0.001))
    ///             return .again
    ///         }
    ///
    /// The state is declared `@State(animatedBy: .engine)`, and has one
    /// animator: a second one is refused and said. It runs when the
    /// destination is written, and again each frame it answers `.again`;
    /// `.wait` waits for the next destination, it does not say the value
    /// arrived - `finish()` does. Where the user asks for less motion the
    /// value is put at its destination for it. While its view stands the
    /// engine is a consumer of the state's channel; leaving, it ends the
    /// movements handed to it `.detached`.
    ///
    /// - Parameters:
    ///   - state: the state it animates, `$x`.
    ///   - priority: where it comes among the animators, ascending. 0 unless said.
    ///   - run: one frame, handed the instant and the movement.
    public func engine<Value: Walked>(
        animating state: Binding<Value>,
        priority: Double = 0,
        _ run: @escaping @MainActor (EngineCycle, EngineMotion<Value>) -> EngineAnswer
    ) -> Modified {
        let storage = state.storage
        let consumer = JourneyConsumer(of: state.journey)

        return modified {
            $0.engines.append(EngineDeclaration(
                follows: [storage], consumes: [consumer], animates: storage.animatorClaim, priority: priority,
                run: { cycle in storage.animate(cycle, run) }))
        }
    }
}
