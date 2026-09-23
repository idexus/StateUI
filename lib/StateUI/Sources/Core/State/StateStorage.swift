// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a state's value lives: in the storage, or on the image the host carries
// once anything hands the state on.
// Design: docs/design/core/state.md#storage-and-box

import Synchronization

extension State {
    /// Where the value lives, one level below the box: a fresh box adopts its
    /// predecessor's storage, so every box that stood for this state shares it and
    /// its lock. Internal, so the tests can hold its invariants.
    /// Design: docs/design/core/state.md#storage-and-box
    final class Storage: @unchecked Sendable, NamedState, AnyStateStorage, FollowedState {
        private let guarded = Lock()

        /// How many times this side wrote the value while it lived here - read without
        /// the lock by an engine's `stirred()`.
        /// Design: docs/design/core/cycle.md#what-wakes-an-engine
        private let written = Atomic<Int>(0)

        /// How many times the state was written, by this side or the host - what an
        /// engine following it compares.
        var stamp: Int { written.load(ordering: .relaxed) &+ (image?.stamp ?? 0) }

        /// The value, once anybody has wanted it; one optional deeper than `Value`, so a
        /// nil value is told from no value yet.
        private var held: Value?

        /// What the value would be, until something asks.
        /// Design: docs/design/core/state.md#the-initial-value-waits
        private var make: (() -> Value)?

        /// What the author calls this state (Core/Render/Builds.swift). Outside the
        /// lock: every walk writes the same name.
        nonisolated(unsafe) var origin: String?

        /// Names this storage where nothing has yet - under the lock, since two first
        /// touches of a model may race.
        func name(once name: String) {
            guarded.withLock {
                if origin == nil { origin = name }
            }
        }

        /// The image the host carries this state on, once anything asks; on the storage,
        /// because its number is issued against it.
        /// Design: docs/design/core/state.md#carried-state
        nonisolated(unsafe) private(set) var image: HostStorage?

        /// How the value is read and written once carried, installed by `carry()` - only
        /// a `StateValue` has lanes.
        private var hostRead: (() -> Value)?
        private var hostWrite: ((Value) -> Void)?

        /// How a journey's value is put somewhere at once, standing still; nil where a
        /// write already is that.
        private var hostSnap: ((Value) -> Void)?

        /// How a destination sent another way than a write is made known to the host's
        /// hook.
        var noted: ((Value) -> Void)?

        /// The colour pair last written into a carried state; the image holds its half
        /// in force.
        /// Design: docs/design/core/state.md#themed-colours-on-a-carried-state
        nonisolated(unsafe) var pair: Value?

        /// Whether a value is a colour with a half for each theme.
        static func isPair(_ value: Value) -> Bool { (value as? Color)?.dark != nil }

        /// Whether the image is a journey's rather than the value's own lanes.
        /// Design: docs/design/core/state.md#a-state-has-one-shape
        nonisolated(unsafe) private(set) var journeyed = false

        /// Puts the value there - where it is, where it is going, standing still; for a
        /// plain value, a write.
        func snap(_ newValue: Value) {
            if let hostSnap {
                pair = Self.isPair(newValue) ? newValue : nil
                hostSnap(newValue)
            } else {
                value = newValue
            }
        }

        /// Whether the host carries this state.
        var carried: Bool { image != nil }

        /// The law `@State(motion:)` declared, or `.inherited`; read once, when the
        /// journey image is made.
        nonisolated(unsafe) var law: Motion = .inherited

        /// Whether any build ever read this state - sticky, and what a write consults
        /// before asking for a render.
        /// Design: docs/design/core/invalidation.md#live-readers
        nonisolated(unsafe) var readAtBuild = false

        /// The conversion this storage is the derived side of, held weakly to break a
        /// ring (Core/Journey/Conversion.swift).
        /// Design: docs/design/core/journeys.md#conversions
        nonisolated(unsafe) weak var conversion: Conversion?

        /// The derived states worked out from this one, by the line that wrote each
        /// conversion.
        nonisolated(unsafe) var derivations: [String: AnyObject] = [:]

        /// The derived state a conversion written at `key` keeps - made once, then kept.
        func derived<Out>(_: Out.Type, at key: String, make: @escaping () -> Out) -> State<Out>.Storage {
            if let kept = derivations[key] as? State<Out>.Storage { return kept }

            let made = State<Out>(making: make).storage

            derivations[key] = made
            return made
        }

        /// What every write ends with, this side's and the host's: the readers are asked,
        /// and nobody where no build read the state. A state has no cadence.
        /// Design: docs/design/core/journeys.md#readings
        func askForRender() {
            // No build ever read it: nobody to render for, and this costs one load.
            if readAtBuild {
                Renderer.shared.stateChanged(self)
            }

            // A moved destination is a moved journey too.
            askJourneyReaders()
        }

        /// Asks the bodies that read the journey - where the value is, how fast - and
        /// nobody else.
        /// Design: docs/design/core/journeys.md#two-reader-sets
        func askJourneyReaders() {
            guard let image, image.readAtBuild else { return }

            Renderer.shared.stateChanged(image)
        }


        init(_ make: @escaping () -> Value) {
            self.make = make
        }

        /// The value, worked out the first time; called under the lock only.
        private func settled() -> Value {
            if let make {
                held = make()
                self.make = nil
            }

            // Written just above where it was missing.
            return held!
        }

        /// The value, read or written whole under the lock.
        var value: Value {
            get {
                if let hostRead { return pair ?? hostRead() }

                return guarded.withLock { settled() }
            }
            set {
                if let hostWrite {
                    pair = Self.isPair(newValue) ? newValue : nil
                    hostWrite(newValue)
                    return
                }

                guarded.withLock {
                    held = newValue
                    make = nil
                    written.wrappingAdd(1, ordering: .relaxed)
                }
            }
        }

        /// Writes the value and hands it to `then` under one hold, so a kept state's save
        /// never comes apart from its write. `then` runs under the lock.
        /// Design: docs/design/core/state.md#writes-from-any-thread
        func write(_ newValue: Value, then: ((Value) -> Void)?) {
            if let hostWrite {
                // The board's hold serializes a carried write; the record comes after it.
                pair = Self.isPair(newValue) ? newValue : nil
                hostWrite(newValue)
                then?(newValue)
                return
            }

            guarded.withLock {
                held = newValue
                make = nil
                written.wrappingAdd(1, ordering: .relaxed)
                then?(newValue)
            }
        }

        /// Reads, changes, writes and records under one hold, so two tasks counting at
        /// once both count.
        func update(_ transform: (Value) -> Value, then: ((Value) -> Void)?) {
            if let hostRead, let hostWrite {
                // A read and then a write: the host rewrites the image on its own frames.
                let settled = transform(pair ?? hostRead())

                pair = Self.isPair(settled) ? settled : nil
                hostWrite(settled)
                then?(settled)
                return
            }

            guarded.withLock {
                let settled = transform(settled())

                held = settled
                make = nil
                written.wrappingAdd(1, ordering: .relaxed)
                then?(settled)
            }
        }
    }
}

extension State.Storage where Value: Walked {
    /// The image the host carries this state on as a journey - a slider's thumb, a
    /// driven property, a scroller's offset, and what `$x.journey` reads. A read
    /// answers the destination; a write moves the destination and the host animates
    /// the value there; a snap lands both. Nothing, said out loud, where the value's
    /// own image already has a number.
    /// Design: docs/design/core/state.md#a-state-has-one-shape
    func carryAsJourney() -> HostStorage? {
        let made: HostStorage? = guarded.withLock {
            if let image, journeyed { return image }

            // Refused where the host already has the value's own image by number; an image
            // it has no number for yet is reshaped below.
            if let image, image.number != nil { return nil }

            let initial = image.map { Self.lifted(from: $0) } ?? settled()
            let start = JourneyLanes(initial, motion: law)

            pair = Self.isPair(initial) ? initial : nil
            let made: HostStorage

            if let image {
                Renderer.shared.board(of: image).reshape(image, to: StateImage.bytes(of: start.carried))
                made = image
            } else {
                made = HostStorage(StateImage.bytes(of: start.carried))
                made.origin = origin
                Renderer.shared.board(of: made).hold(made)
            }

            image = made
            journeyed = true
            held = nil
            make = nil
            // The destination this side last knew: the host writes it back on landing, and
            // that asks for nothing.
            let known = Known(start.destination)

            hostRead = { Self.journey(on: made).destination }
            hostWrite = { target in
                var journey = Self.journey(on: made)

                journey.destination = target

                // Nobody animates it yet: the value lands where it is sent.
                // Design: docs/design/core/state.md#a-state-nobody-wears
                if made.number == nil, !journey.motion.isCustom {
                    journey.value = target
                    journey.velocity = JourneyLanes<Value>.still
                }

                known.destination = target
                Self.lay(journey, on: made)
            }
            hostSnap = { landed in
                var journey = Self.journey(on: made)

                journey.value = landed
                journey.destination = landed
                journey.velocity = JourneyLanes<Value>.still

                known.destination = landed
                Self.lay(journey, on: made)
            }
            noted = { destination in known.destination = destination }
            made.told = { [weak self] mask in
                let now = Self.journey(on: made)

                if mask & JourneyLanes<Value>.mask(of: .destination) != 0, !known.stands(at: now.destination) {
                    // The destination moved - a drag, a press: every reader is asked.
                    known.destination = now.destination
                    self?.pair = nil
                    self?.askForRender()
                } else if mask & (JourneyLanes<Value>.mask(of: .value) | JourneyLanes<Value>.mask(of: .velocity)) != 0 {
                    // A frame of the animation: only the journey's readers are asked.
                    self?.askJourneyReaders()
                }
            }

            return made
        }

        if made == nil {
            complain("`\(origin ?? "a state")` is carried as the value itself - a feed "
                + "or a driven property has it, and the host has its number - and "
                + "was handed to something that walks it, or its journey was read. "
                + "One state has one shape: declare a second state for the other.")
        }

        return made
    }

    /// The journey image, made now if nothing has yet - or nothing, quietly, where
    /// the value's own image has a number. What `Journey` reads through.
    func walkedImage() -> HostStorage? {
        if journeyed { return image }
        if let image, image.number != nil { return nil }

        return carryAsJourney()
    }

    /// The journey's lanes as they stand, read without recording.
    var journeyLanes: JourneyLanes<Value>? {
        guard journeyed, let image else { return nil }

        return Self.journey(on: image)
    }

    /// Writes the journey's lanes whole; the board finds which moved.
    func lay(_ lanes: JourneyLanes<Value>) {
        guard journeyed, let image else { return }

        Self.lay(lanes, on: image)
    }

    /// Tells the storage a destination sent by another road than a write, so the host
    /// writing it back on landing asks for nothing.
    func noteDestination(_ destination: Value) {
        noted?(destination)
    }

    /// The destination this side last knew, shared by three closures.
    private final class Known: @unchecked Sendable {
        nonisolated(unsafe) var destination: Value

        init(_ destination: Value) { self.destination = destination }

        /// Whether a destination is the one already known, lane for lane.
        func stands(at other: Value) -> Bool {
            StateImage.bytes(of: destination.carried) == StateImage.bytes(of: other.carried)
        }
    }

    /// The journey as its lanes stand, or one at nought where they stand for none.
    private static func journey(on image: HostStorage) -> JourneyLanes<Value> {
        JourneyLanes<Value>(
            carried: Renderer.shared.board(of: image).read(image, lanes: JourneyLanes<Value>.lanes))
            ?? JourneyLanes(nothing)
    }

    /// Writes the journey into the lanes, whole.
    private static func lay(_ journey: JourneyLanes<Value>, on image: HostStorage) {
        Renderer.shared.board(of: image).write(StateImage.bytes(of: journey.carried), to: image)
    }
}

extension State.Storage where Value: StateValue {
    /// Writes the value where it differs, lane for lane, asking the readers where
    /// `asking` says - what a conversion's engines do.
    func settle(_ newValue: Value, asking: Bool) {
        guard StateImage.bytes(of: newValue.carried) != StateImage.bytes(of: value.carried) else { return }

        write(newValue, then: nil)

        if asking { askForRender() }
    }

    /// The image the host carries this state on as its own lanes, made once from the
    /// value as it stands - or nothing, said out loud, where the image is a journey's.
    /// Design: docs/design/core/state.md#carried-state
    func carry() -> HostStorage? {
        let made: HostStorage? = guarded.withLock {
            if let image { return journeyed ? nil : image }

            let initial = settled()
            let bytes = StateImage.bytes(of: initial.carried)
            let made = HostStorage(bytes)

            pair = Self.isPair(initial) ? initial : nil

            made.origin = origin
            Renderer.shared.board(of: made).hold(made)

            image = made
            held = nil
            make = nil

            // The bytes this side last knew: a host write putting them back asks nothing.
            // Design: docs/design/core/state.md#what-the-host-writes-back
            let known = KnownBytes(bytes)

            hostRead = { Self.lifted(from: made) }
            hostWrite = { value in
                known.bytes = StateImage.bytes(of: value.carried)
                Self.lay(value, on: made)
            }

            // A host write ends where this side's do, the storage deciding by its readers.
            made.told = { [weak self] _ in
                let now = StateImage.bytes(of: Self.lifted(from: made).carried)

                guard now != known.bytes else { return }

                known.bytes = now
                self?.pair = nil
                self?.askForRender()
            }

            return made
        }

        if made == nil {
            complain("`\(origin ?? "a state")` is carried as a journey - a Slider's "
                + "or a Stepper's - and was handed to something that carries the "
                + "value itself. One state has one shape: declare a second state "
                + "for the other.")
        }

        return made
    }

    /// The bytes this side last knew, shared by the writer and the host's hook.
    private final class KnownBytes: @unchecked Sendable {
        nonisolated(unsafe) var bytes: [UInt8]

        init(_ bytes: [UInt8]) { self.bytes = bytes }
    }

    /// Lays a colour pair's half in force and makes the element being built the
    /// theme's reader.
    /// Design: docs/design/core/state.md#themed-colours-on-a-carried-state
    func wearThemedPair() {
        guard let pair, let hostRead, let hostWrite else { return }

        // The read that makes this element the theme's reader.
        _ = StandardEnvironment.app.requestedTheme

        guard StateImage.bytes(of: pair.carried) != StateImage.bytes(of: hostRead().carried) else { return }

        hostWrite(pair)
    }

    /// The value as the lanes stand, or `nothing` where they stand for none.
    static func lifted(from image: HostStorage) -> Value {
        Value(carried: Renderer.shared.board(of: image).read(image, lanes: Value.lanes))
            ?? nothing
    }

    /// The value written into the lanes, whole.
    static func lay(_ value: Value, on image: HostStorage) {
        Renderer.shared.board(of: image).write(StateImage.bytes(of: value.carried), to: image)
    }

    /// What a value answers where its bytes stand for none of its type - every lane
    /// nought, or empty text. Only a faulty host causes it, and a frame frozen beats
    /// a trap.
    private static var nothing: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0))))
            ?? Value(carried: .text(""))!
    }
}
