// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/journeys.md#who-animates-it
/// The journey a state is on: where the value is, where it is going, how fast,
/// and under what law - reached as `$fade.journey`. This library's own.
///
///     @State private var fade = 1.0
///
///     ColorBox().opacity($fade)
///
///     fade = 0.2                                         // the destination: the box animates there
///     try await $fade.journey.move(to: 0.2, .eased(400, .cubicOut))   // the same, awaited
///     $fade.journey.value                                // where it has got to this frame
///     $fade.journey.velocity                             // and how fast
///     $fade.journey.stop()                               // leaves it where it is
///
/// The state's own value is the destination: reading it answers where the value
/// is going, writing it sends it there. The host animates a state handed to a
/// driven modifier, a two-way control or a scroller; an engine of your own
/// animates one declared `@State(motion: .custom)`; a state nobody wears lands
/// where it is sent. A part of a state and a binding made from closures stand at
/// their value.
public struct Journey<Value: Walked> {
    /// The state this is the journey of.
    private let state: Binding<Value>

    /// The storage behind the state; nothing for a part of one or a closure binding.
    var storage: State<Value>.Storage? { state.described }

    /// The journey of a state, reached as `$fade.journey`.
    init(of state: Binding<Value>) { self.state = state }

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
        guard let storage, let image = storage.walkedImage(), let lanes = storage.journeyLanes else {
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
        get { lanes()?.value ?? state.wrappedValue }

        nonmutating set {
            guard let (storage, _, standing) = walking() else {
                state.wrappedValue = newValue
                return
            }

            var lanes = standing

            lanes.value = newValue
            storage.lay(lanes)
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
            guard let (storage, _, standing) = walking() else { return }

            var lanes = standing

            lanes.velocity = newValue
            storage.lay(lanes)
            storage.askJourneyReaders()
        }
    }

    /// The law this value animates under, wherever it is shown.
    ///
    ///     $rotation.journey.motion = .spring()
    ///
    /// On the value rather than the view: `.motion(_:)` says how an element animates,
    /// this says how this value does. `.inherited` is the element's own. `.custom` is
    /// not set here: who animates a value is settled at its declaration.
    public var motion: Motion {
        get { lanes()?.motion ?? storage?.law ?? .inherited }

        nonmutating set {
            guard let storage else { return }

            guard let (_, _, standing) = walking() else {
                storage.law = newValue
                return
            }

            var lanes = standing

            guard !newValue.isCustom, !lanes.motion.isCustom else {
                complain("`\(storage.origin ?? "a state")` was given a law after it was declared "
                    + "that would change who walks it. `.custom` is said at the declaration - "
                    + "`@State(motion: .custom)` - and a value declared so keeps it.")
                return
            }

            lanes.motion = newValue
            storage.lay(lanes)
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
        state.land(value)
    }

    /// Sends the value there under `motion`, and suspends until it arrives.
    ///
    ///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
    ///
    /// True means it got there; false means something else ended the journey - a
    /// newer destination, a value written over it, or `stop()`. With nothing to
    /// animate - already there, the user asked for less motion, or nothing wears the
    /// state yet - it answers true at once. A law given here stays on the value;
    /// without one, the value's own law stands.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the law to animate under, or nothing for the value's own.
    /// - Returns: whether it ran to the end.
    /// - Throws: whatever the host answers when it cannot carry the value at all.
    @discardableResult
    public nonisolated(nonsending) func move(to target: Value, _ motion: Motion? = nil) async throws -> Bool {
        guard let (storage, image, lanes) = walking() else {
            complain("`move` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it can "
                + "walk. Move the whole state, handed to something that walks it.")
            return false
        }

        // Nothing animates it, or an engine does: the destination is written through the
        // state and the answer is at once.
        // Design: docs/design/core/journeys.md#moving-and-waiting
        if image.number == nil || lanes.motion.isCustom {
            state.wrappedValue = target
            return true
        }

        let answer = try await Renderer.shared.answered { completion in
            let waiter = Renderer.shared.book(completion)
            var travelling = lanes

            travelling.destination = target
            travelling.completion = Double(waiter)

            if let motion { travelling.motion = motion }

            // The waiter forces the destination: a fresh journey even to where it is going.
            Renderer.shared.board(of: image).write(
                StateImage.bytes(of: travelling.carried),
                to: image,
                forcing: JourneyLanes<Value>.mask(of: .destination) | JourneyLanes<Value>.mask(of: .completion))

            storage.noteDestination(target)
        }

        return answer.first?.bool ?? true
    }

    /// Stops an animation where it stands; whoever waits on it hears it did not run
    /// to the end. A value that was not moving is unaffected.
    public func stop() {
        guard let (_, image, standing) = walking() else {
            complain("`stop` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it walks.")
            return
        }

        var stopping = standing

        // The waiter's id stays on the image: the host needs it to answer.
        stopping.stopped += 1

        Renderer.shared.board(of: image).write(
            StateImage.bytes(of: stopping.carried),
            to: image,
            forcing: JourneyLanes<Value>.mask(of: .stopped))
    }
}

/// `Sendable` for the reason `Binding` is.
/// Design: docs/design/core/state.md#sendable-promises
extension Journey: Sendable {}
