// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/journeys.md#who-animates-it
/// The journey a state is on: where the value is, where it is going, how fast,
/// and under what law - reached as `$fade.journey`. This library's own.
///
///     @State private var fade = 1.0
///
///     Rectangle().opacity($fade)
///
///     fade = 0.2                                         // the destination: the box animates there
///     $fade.journey.move(to: 0.2, .eased(.milliseconds(400)))           // the same, under a law of its own
///     try await $fade.journey.move(to: 1).arrived()      // back, waiting for the arrival
///     $fade.journey.value                                // where it has got to this frame
///     $fade.journey.velocity                             // and how fast
///     $fade.journey.stop()                               // leaves it where it is
///
/// The state's own value is the destination: reading it answers where the value
/// is going, writing it sends it there. The host animates a state handed to a
/// driven modifier, a two-way control or a scroller; an engine of your own
/// animates one declared `@State(motion: .custom)`; a state nobody wears lands
/// where it is sent. A part of a state has none: a journey is a whole state's.
@MainActor
public struct Journey<Value: Walked> {
    /// The state this is the journey of.
    private let state: Binding<Value>

    /// The storage behind the state.
    var storage: State<Value>.Storage { state.storage }

    /// The journey of a state, reached as `$fade.journey`.
    init(of state: Binding<Value>) { self.state = state }

    /// Where the host walks the value, whatever a run shows: what the run moving it
    /// works out its own place from.
    var walked: Value { lanes()?.value ?? state.wrappedValue }

    /// The run `owner` shows the value at `value` while it moves it; nil once it rests.
    /// Design: docs/design/core/journeys.md#where-a-run-shows-it
    func show(_ value: Value?, by owner: ObjectIdentifier) {
        storage.show(value, by: owner)
    }

    /// The lanes as they stand, with the read recorded against the image.
    /// Design: docs/design/core/journeys.md#two-reader-sets
    private func lanes() -> JourneyLanes<Value>? {
        guard let (_, image, lanes) = walking() else { return nil }

        if Renderer.shared.stateRead(image) { image.readAtBuild = true }

        return lanes
    }

    /// The storage, its journey image - made now if nothing has yet - and the lanes
    /// as they stand, read without recording: what every write starts from.
    private func walking() -> (State<Value>.Storage, HostStorage, JourneyLanes<Value>)? {
        guard let image = storage.walkedImage(), let lanes = storage.journeyLanes else {
            return nil
        }

        return (storage, image, lanes)
    }

    /// Where the value is - what the screen shows this frame.
    ///
    /// Read in a body, it rebuilds the body every frame the value moves; `.samples`
    /// reads it at a slower rate, and `convert(_:)` works words out on the host's
    /// frames with no render. Written, it moves only what is shown and leaves the
    /// destination, so the host goes straight back; `snap(to:)` sets all three.
    public var value: Value {
        get {
            let walked = lanes()?.value
            return storage.shown?.value ?? walked ?? state.wrappedValue
        }

        nonmutating set {
            guard HandlerRun.admits("a journey's value") else { return }
            guard let (storage, _, standing) = walking() else {
                state.wrappedValue = newValue
                return
            }

            var lanes = standing

            lanes.value = newValue
            storage.lay([.value], of: lanes)
            storage.askJourneyReaders()
        }
    }

    /// Where it is GOING - the state's own value, read and written here so a
    /// journey says both of its ends. `fade` and `$fade.journey.destination`
    /// are one thing.
    public var destination: Value {
        get { state.wrappedValue }

        nonmutating set { state.wrappedValue = newValue }
    }

    /// How fast it is going, per second, lane by lane - nought where nothing animates
    /// it. Written, it is a kick: it bends an animation under way, or takes a still
    /// value out and lets the law bring it back.
    public var velocity: Value {
        get { lanes()?.velocity ?? JourneyLanes<Value>.still }

        nonmutating set {
            guard HandlerRun.admits("a journey's velocity"), let (storage, _, standing) = walking() else { return }

            var lanes = standing

            lanes.velocity = newValue
            storage.lay([.velocity], of: lanes)
            storage.askJourneyReaders()
        }
    }

    /// The law this value animates under, wherever it is shown.
    ///
    ///     $rotation.journey.motion = .spring()
    ///
    /// On the value rather than the view: `.motion(_:)` says how an element animates,
    /// this says how this value does. `.inherited` is the element's own. `.custom` is
    /// not set here: who animates a value is settled at its declaration. A law given to
    /// `move(to:_:)` is that move's alone and leaves this one standing.
    public var motion: Motion {
        get {
            _ = lanes()
            return storage.law
        }

        nonmutating set {
            guard HandlerRun.admits("a journey's law") else { return }
            guard newValue.kind != .custom, storage.law.kind != .custom else {
                complain("`\(storage.origin ?? "a state")` was given a law after it was declared "
                    + "that would change who walks it. `.custom` is said at the declaration - "
                    + "`@State(motion: .custom)` - and a value declared so keeps it.")
                return
            }

            storage.law = newValue
            guard let (_, _, standing) = walking() else { return }

            var lanes = standing

            lanes.motion = newValue
            storage.lay([.motion], of: lanes)
            storage.askJourneyReaders()
        }
    }

    /// Puts the value there at once: shown there, going nowhere, standing still.
    ///
    ///     $box.journey.snap(to: measured)
    ///
    /// For a value worked out rather than chosen - a size from a measurement, a place
    /// from a report - which, animated as a destination, would crawl after what
    /// decided it. Synchronous: nothing is booked and nobody waits.
    ///
    /// - Parameter value: where it now is, and stays.
    public func snap(to value: Value) {
        guard HandlerRun.admits("a snap") else { return }

        state.land(value)
    }

    /// Sends the value there under `motion` - now, before the next line runs - and
    /// answers the movement, whose `arrived()` waits for its end.
    ///
    ///     try await $fade.journey.move(to: 0.1, .eased(.milliseconds(400), .cubicOut)).arrived()
    ///
    ///     let fading = $fade.journey.move(to: 0)       // both start now, in this order
    ///     let sliding = $offset.journey.move(to: .zero)
    ///     try await fading.arrived()
    ///     try await sliding.arrived()
    ///
    /// Where nothing wears the state yet, or an engine of the application's animates
    /// it (`.custom`), it arrives at once; already there, or where the user asked for
    /// less motion, it arrives on the host's next frame. A law given here is this move's
    /// alone: the next write that names none travels under the value's own.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the law to animate under - `.none` to travel under no motion.
    /// - Returns: the movement, to await its arrival or leave going.
    @discardableResult
    public func move(to target: Value, _ motion: Motion) -> Arrival {
        send(to: target, under: motion)
    }

    /// Sends the value there under its own law, as `move(to:_:)` does under one given.
    ///
    /// - Parameter target: where to send it.
    /// - Returns: the movement, to await its arrival or leave going.
    @discardableResult
    public func move(to target: Value) -> Arrival {
        send(to: target, under: nil)
    }

    /// Sends the value there under `motion`, or its own law where none is given: the two `move`s, each spelling
    /// one, so `.none` is always the law that does not move.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    private func send(to target: Value, under motion: Motion?) -> Arrival {
        guard HandlerRun.admits("a movement") else { return Arrival(at: false) }
        guard let (storage, image, lanes) = walking() else {
            complain("`move` was called on a state the host carries as the value itself, which it cannot "
                + "walk. Hand the state to something that walks it.")
            return Arrival(at: false)
        }

        // Nothing animates it, or an engine does: the destination is written through the
        // state and it arrives at once.
        // Design: docs/design/core/journeys.md#moving-and-waiting
        if image.ties == 0 || lanes.motion.kind == .custom {
            state.wrappedValue = target
            return Arrival(at: true)
        }

        let arrival = Arrival()
        var traveling = lanes

        traveling.destination = target
        traveling.completion = Double(Renderer.shared.book { arrival.land($0) })

        // A law given is this move's alone; without one the value travels under its own.
        traveling.motion = motion ?? storage.law

        // The waiter forces the destination only where no lane of it changes - a fresh journey even to where it is
        // going; otherwise the lanes it changes are the journey, and the others travel on.
        // Design: docs/design/core/journeys.md#moving-and-waiting
        let fresh = lanes.destination == target ? JourneyLanes<Value>.mask(of: .destination) : 0
        storage.lay(
            [.destination, .completion, .motion], of: traveling,
            forcing: fresh | JourneyLanes<Value>.mask(of: .completion))

        storage.moved(to: target)
        return arrival
    }

    /// Where the value comes to rest if `motion` carries it on from where it
    /// is, at the speed it has, alone - what a throw reaches, to send it to
    /// the nearest place it may rest at:
    ///
    ///     $offset.journey.velocity = pan.velocityY
    ///     let glide = Motion.glide(longest: .milliseconds(800))
    ///     $offset.journey.move(to: rows.nearest(to: $offset.journey.reach(glide)), glide)
    ///
    /// A value goes as far as its speed for the motion's length over how
    /// steeply the motion sets out: an eased one on its curve, a glide and a
    /// spring as `cubicOut` does. Standing still, or under a motion that does
    /// not animate, it rests where it is; `.inherited` is the value's own law.
    ///
    /// - Parameter motion: the law that would carry it.
    /// - Returns: where it would come to rest.
    /// Design: docs/design/types/motion.md#where-a-throw-reaches
    public func reach(_ motion: Motion) -> Value {
        let at = value
        let law = motion.kind == .inherited ? storage.law : motion
        guard case .lanes(let from) = at.carried(in: .current), case .lanes(let speed) = velocity.carried(in: .current),
              from.count == speed.count
        else { return at }

        let reached = zip(from, speed).map { $0 + HostMotionLaw.carried($1, under: law) }
        return Value(carried: .lanes(reached)) ?? at
    }

    /// Puts one part of the value there at once, as `snap(to:)` does the whole: the other lanes go on as they were.
    /// Design: docs/design/core/journeys.md#one-part-at-once
    func snap(_ part: WritableKeyPath<Value, Double>, to target: Double) {
        guard HandlerRun.admits("a snap") else { return }
        guard let (storage, _, standing) = walking() else {
            var landed = state.wrappedValue
            landed[keyPath: part] = target
            return state.land(landed)
        }

        var lanes = standing

        lanes.value[keyPath: part] = target
        lanes.destination[keyPath: part] = target
        lanes.velocity[keyPath: part] = 0
        storage.lay([.value, .destination, .velocity], of: lanes)
        storage.noteDestination(lanes.destination)
        storage.askForRender()
    }

    /// Stops an animation where it stands; whoever waits on it hears it did not run
    /// to the end. A value that was not moving is unaffected.
    public func stop() {
        guard HandlerRun.admits("a stop") else { return }
        guard let (storage, _, standing) = walking() else {
            complain("`stop` was called on a state the host carries as the value itself, which it does not "
                + "walk.")
            return
        }

        var stopping = standing

        // The waiter's id stays on the image: the host needs it to answer.
        stopping.stopped += 1

        storage.lay([.stopped], of: stopping, forcing: JourneyLanes<Value>.mask(of: .stopped))
        storage.stoppedWhereItStands()
    }
}
