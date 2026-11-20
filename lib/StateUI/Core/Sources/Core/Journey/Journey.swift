// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/journeys.md#who-animates-it
/// The journey of a state - reached as `$fade.journey`: a handle to how the
/// host shows the value between two destinations. This library's own.
///
///     @State(motion: .spring()) private var fade = 1.0
///
///     Rectangle().opacity($fade)
///
///     fade = 0.2                                              // the destination: the box animates there
///     $fade.journey.move(to: 0.2, .eased(.milliseconds(400)))  // the same, under a motion of its own
///     try await $fade.journey.move(to: 1).result()            // back, waiting for how it ends
///     $fade.journey.sample?.value                             // where it has got to this frame
///     $fade.journey.stop()                                    // leaves it where it is
///
/// The state's own value is the destination. The handle owns nothing and
/// starts nothing: a state handed to a driven modifier, a two-way control or a
/// scroller is shown by the host, which alone knows where it stands - `sample`;
/// a state nothing shows has no sample. A part of a state has no journey.
@MainActor
public struct Journey<Value: Walked> {
    /// The state this is the journey of.
    private let state: Binding<Value>

    /// The storage behind the state.
    var storage: State<Value>.Storage { state.storage }

    /// The storage as the state's binding reaches it when asked.
    var anyReach: () -> (any AnyStateStorage)? { state.anyReach }

    /// The journey of a state, reached as `$fade.journey`.
    init(of state: Binding<Value>) { self.state = state }

    /// The image the host shows the state on, where it has a channel there.
    private var shownImage: HostStorage? {
        guard storage.journeyed, let image = storage.image, image.hasChannel else { return nil }

        return image
    }

    /// Where the host shows the value on its last frame - its place, the
    /// destination it is taken to and its speed, all of that one frame - or
    /// nil where nothing shows the state.
    ///
    ///     Text($caption)
    ///         .engine(following: $fade.journey) { _ in
    ///             guard let sample = $fade.journey.sample else { return }
    ///             caption = "\(Int(sample.value * 100))%"
    ///         }
    ///
    /// Reading it starts nothing. Read in a body, it rebuilds the body on
    /// every frame the value moves, and as the state comes to be shown or
    /// stops being; an engine following the journey reads it with no build.
    /// Design: docs/design/core/journeys.md#the-sample
    public var sample: JourneySample<Value>? {
        let watch = storage.presentation
        if Renderer.shared.stateRead(watch) { watch.readAtBuild = true }

        return shownImage?.sample?.typed(
            Value.self, at: Renderer.shared.board.frameTime)
    }

    /// The motion this value animates under wherever it is shown -
    /// `@State(motion:)`'s, or the one `setMotion(_:)` gave; `.inherited` is the
    /// application's. Nil for a state an engine of the application animates,
    /// which takes none.
    public var motion: Motion? {
        storage.law.kind == .custom ? nil : storage.law
    }

    /// Gives the value the motion its next destination travels under.
    ///
    ///     try $rotation.journey.setMotion(.spring())
    ///
    /// It starts nothing and bends nothing under way: a movement begun keeps
    /// the motion it set out under.
    ///
    /// - Parameter motion: the motion, `.inherited` for the application's.
    /// - Throws: `StateUIError.notPerformed` for a state an engine of the
    ///   application animates - `@State(animatedBy: .engine)` - which is
    ///   settled where it is declared; nothing changes.
    public func setMotion(_ motion: Motion) throws {
        guard HandlerRun.admits("a journey's motion") else { return }
        guard storage.law.kind != .custom else {
            throw StateUIError.notPerformed(
                act: "setMotion",
                reason: "`\(storage.origin ?? "a state")` is animated by an engine - `@State(animatedBy: .engine)` - "
                    + "and takes no motion")
        }

        storage.law = motion
    }

    /// Puts the value there at once: shown there, going nowhere, standing still.
    ///
    ///     $box.journey.snap(to: measured)
    ///
    /// For a value worked out rather than chosen - a size from a measurement, a place
    /// from a report - which, animated as a destination, would crawl after what
    /// decided it. Synchronous: nothing is booked and nobody waits. On a state
    /// nothing shows it is a plain write.
    ///
    /// - Parameter value: where it now is, and stays.
    public func snap(to value: Value) {
        guard HandlerRun.admits("a snap") else { return }

        state.land(value)
    }

    /// Sends the value there under `motion` - now, before the next line runs - and
    /// answers the movement, whose `result()` waits for how it ends.
    ///
    ///     try await $fade.journey.move(to: 0.1, .eased(.milliseconds(400))).result()
    ///
    ///     let fading = $fade.journey.move(to: 0)       // both start now, in this order
    ///     let sliding = $offset.journey.move(to: .zero)
    ///     try await fading.result()
    ///     try await sliding.result()
    ///
    /// The destination is written wherever the state takes it. Where nothing
    /// shows the state the answer is `.notStarted(.noReceiver)`: written, and
    /// nothing moved. A motion given here is this move's alone: the next write
    /// that names none travels under the value's own.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the motion to travel under - `.none` to arrive at once.
    /// - Returns: the movement, to await its result or leave going.
    @discardableResult
    public func move(to target: Value, _ motion: Motion) -> MotionRun {
        send(to: target, under: motion)
    }

    /// Sends the value there under its own motion, as `move(to:_:)` does under one given.
    ///
    /// - Parameter target: where to send it.
    /// - Returns: the movement, to await its result or leave going.
    @discardableResult
    public func move(to target: Value) -> MotionRun {
        send(to: target, under: nil)
    }

    /// Sends the value there under `motion`, or its own where none is given: the two `move`s, each spelling
    /// one, so `.none` is always the motion that does not move.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    private func send(to target: Value, under motion: Motion?) -> MotionRun {
        guard HandlerRun.admits("a movement") else { return MotionRun(ended: .notStarted(.inactiveOwner)) }

        // An engine's state takes no motion: refused before anything is written.
        let engineAnimates = storage.law.kind == .custom
        if engineAnimates, motion != nil { return MotionRun(ended: .notStarted(.incompatibleAnimator)) }

        // A destination the state refuses is no journey.
        guard storage.admits(target) else { return MotionRun(ended: .notStarted(.invalidDestination)) }

        // A derived state goes back to its sources first, whole or not at all: then its own channel travels.
        // Design: docs/design/core/journeys.md#the-way-back
        let derived = storage.conversion != nil
        if let conversion = storage.conversion {
            switch conversion.writeBack(target, origin: .program) {
            case .landed:
                break
            case .readOnly:
                return MotionRun(ended: .notStarted(.readOnlyDerived))
            case .refused(let why):
                complain(why)
                return MotionRun(ended: .notStarted(.invalidDestination))
            }
        }

        // Nothing shows it: the destination is written, and nothing moves.
        guard let image = shownImage, let lanes = storage.journeyLanes else {
            if !derived { state.wrappedValue = target }
            let carriedWhole = storage.carried && !storage.journeyed
            return MotionRun(ended: .notStarted(carriedWhole ? .unsupportedValue : .noReceiver))
        }

        if engineAnimates { return storage.hand(target, toTheEngineOn: image) }

        let run = MotionRun()
        var traveling = lanes

        traveling.destination = target
        traveling.completion = Double(Renderer.shared.book { run.land($0) })

        // A motion given is this move's alone; without one the value travels under its own.
        traveling.motion = motion ?? storage.law

        // The waiter forces the destination only where no lane of it changes - a fresh journey even to where it is
        // going; otherwise the lanes it changes are the journey, and the others travel on.
        // Design: docs/design/core/journeys.md#moving-and-waiting
        let fresh = lanes.destination == target ? JourneyLanes<Value>.mask(of: .destination) : 0
        storage.lay(
            [.destination, .completion, .motion], of: traveling,
            forcing: fresh | JourneyLanes<Value>.mask(of: .completion))

        storage.moved(to: target)
        return run
    }

    /// Where the value comes to rest if `motion` carries it on from where it
    /// stands, at the speed it has, alone - what a throw reaches, to send it to
    /// the nearest place it may rest at. Nil where nothing shows the state.
    ///
    ///     let glide = Motion.glide(longest: .milliseconds(800))
    ///     if let reached = $offset.journey.reach(glide) {
    ///         $offset.journey.move(to: rows.nearest(to: reached), glide)
    ///     }
    ///
    /// A value goes as far as its speed for the motion's length over how
    /// steeply the motion sets out: an eased one on its curve, a glide and a
    /// spring as `cubicOut` does. Standing still, or under a motion that does
    /// not animate, it rests where it is; `.inherited` is the value's own.
    ///
    /// - Parameter motion: the motion that would carry it.
    /// - Returns: where it would come to rest.
    /// Design: docs/design/types/motion.md#where-a-throw-reaches
    public func reach(_ motion: Motion) -> Value? {
        guard let sample else { return nil }

        return reach(motion, from: sample.value, at: sample.velocity)
    }

    /// Where `motion` alone carries a value standing at `at`, going at `velocity`.
    func reach(_ motion: Motion, from at: Value, at velocity: Value) -> Value {
        let law = motion.kind == .inherited ? storage.law : motion
        guard case .lanes(let from) = at.carried(in: .current), case .lanes(let speed) = velocity.carried(in: .current),
              from.count == speed.count
        else { return at }

        let reached = zip(from, speed).map { $0 + HostMotionLaw.carried($1, under: law) }
        return Value(carried: .lanes(reached)) ?? at
    }

    /// Stops a movement where it stands; whoever waits on it hears `.stopped`.
    /// A value that was not moving, or that nothing shows, is unaffected.
    public func stop() {
        guard HandlerRun.admits("a stop"), shownImage != nil, let standing = storage.journeyLanes else { return }
        // An engine's movement is the engine's to stop: the host walks nothing of it.
        guard storage.law.kind != .custom else { return storage.stopTheEngine() }

        var stopping = standing

        // The waiter's id stays on the image: the host needs it to answer.
        stopping.stopped += 1

        storage.lay([.stopped], of: stopping, forcing: JourneyLanes<Value>.mask(of: .stopped))
        storage.stoppedWhereItStands()
    }
}
