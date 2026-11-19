// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a state's value lives: in the storage, or on the image the host carries
// once anything hands the state on.
// Design: docs/design/core/state.md#storage-and-box

extension State {
    /// Where the value lives, one level below the box: a fresh box adopts its
    /// predecessor's storage, so every box that stood for this state shares it.
    /// Internal, so the tests can hold its invariants.
    /// Design: docs/design/core/state.md#storage-and-box
    @usableFromInline
    @MainActor
    final class Storage: NamedState, AnyStateStorage, FollowedState {
        /// How many times this side wrote the value while it lived here.
        /// Design: docs/design/core/cycle.md#what-wakes-an-engine
        @usableFromInline var written = 0

        /// How many times the state was written, by this side or the host, equal values
        /// included - what an engine following it compares. A frame of where a journey
        /// stands is no write: it moves `presentation`.
        /// Design: docs/design/core/cycle.md#what-wakes-an-engine
        @usableFromInline var stamp: Int { written &+ (image?.stamp ?? 0) }

        /// How many times the host reported the state.
        var reports: Int { image?.reports ?? 0 }

        /// How many times the destination changed - a write this side cannot compare counted too - which is what
        /// a conversion of this state compares.
        /// Design: docs/design/core/journeys.md#conversions
        var targetRevision: Int { written &+ (image?.targetRevision ?? 0) }

        /// Where a run the hand or the core moves shows the value while it does, and
        /// which run: what the journey's value answers then, the state's own still the
        /// target named. Nothing carries it to the host, which walks the target.
        /// Design: docs/design/core/journeys.md#where-a-run-shows-it
        private(set) var shown: (value: Value, by: ObjectIdentifier)?

        /// The run `owner` shows the value at `value`, or - nil - shows it no longer:
        /// whoever follows where the state is shown hears of it, the state's own
        /// readers do not.
        func show(_ value: Value?, by owner: ObjectIdentifier) {
            if let value {
                shown = (value, owner)
            } else {
                guard shown?.by == owner else { return }
                shown = nil
            }
            presentationMoved()
        }

        /// What follows where the state is shown - a body that read its sample, an engine
        /// following its journey - made at the first such read; it is no image and opens
        /// no channel.
        /// Design: docs/design/core/journeys.md#two-reader-sets
        var presentation: PresentationWatch {
            if let made = madePresentation { return made }

            let made = PresentationWatch(of: self)
            madePresentation = made
            return made
        }

        private var madePresentation: PresentationWatch?

        /// The sample changed, came or went, or a run shows the value elsewhere: the bodies
        /// that read it are asked and the engines following the journey have a reason to run.
        func presentationMoved() {
            guard let watch = madePresentation else { return }

            watch.revision &+= 1
            if watch.readAtBuild { Renderer.shared.stateChanged(watch) }
        }

        /// The value, once anybody has wanted it; one optional deeper than `Value`, so a
        /// nil value is told from no value yet.
        @usableFromInline var held: Value?

        /// What the value would be, until something asks.
        /// Design: docs/design/core/state.md#the-initial-value-waits
        @usableFromInline var make: (() -> Value)?

        /// Where posts to this state wait for their job, made at the first binding.
        /// Design: docs/design/core/state.md#posting
        var mailroom: Mailroom {
            if let made = madeMailroom { return made }

            let made = Mailroom()
            madeMailroom = made
            return made
        }

        private var madeMailroom: Mailroom?

        /// The storage this one was given up for - a view's state adopted - while that one stands.
        private weak var adopted: Storage?
        private var givenUp = false

        /// Whether a box built later adopted this storage: the element keeps it from then on.
        private var kept = false

        /// Gives this storage up for `other`, which a box built later adopts: a conversion made from it stands for
        /// `other` from now on, and what a binding made before posts here goes to `other`'s mailroom, in one queue
        /// with its own posts. A storage the element keeps is given up for nothing - itself least of all: a view
        /// rendered again after another instance adopted its state holds that state still.
        /// Design: docs/design/core/state.md#storage-and-box
        func giveUp(for other: Storage) {
            other.kept = true
            guard other !== self, !kept else { return }

            givenUp = true
            adopted = other
            madeMailroom?.forward(to: other.mailroom)
        }

        /// The storage this one stands for: itself, or the one it was given up for while that stands - none once
        /// that is gone.
        var standsFor: Storage? {
            givenUp ? adopted?.standsFor : self
        }

        /// What the author calls this state (Builds.swift).
        var origin: String?

        /// Names this storage where nothing has yet.
        func name(once name: String) {
            if origin == nil { origin = name }
        }

        /// The image the host carries this state on, once anything asks; on the storage,
        /// because its number is issued against it.
        /// Design: docs/design/core/state.md#carried-state
        private(set) var image: HostStorage?

        /// How the value is read and written once carried, installed by `carry()` - only
        /// a `StateValue` has lanes.
        @usableFromInline var hostRead: (() -> Value)?
        @usableFromInline var hostWrite: ((Value) -> Void)?

        /// How a journey's value is put somewhere at once, standing still; nil where a
        /// write already is that.
        private var hostSnap: ((Value) -> Void)?

        /// How a destination sent another way than a write is made known to the host's
        /// hook.
        var noted: ((Value) -> Void)?

        /// Takes what the host carries as it stands, answering what puts it back whole.
        var hostHeld: (() -> () -> Void)?

        /// The value wearing the theme last written into a carried state - a color
        /// pair, the accent, a material holding either; the image holds its half in force.
        /// Design: docs/design/core/state.md#themed-colors-on-a-carried-state
        @usableFromInline var themed: Value?

        /// Whether a value turns with the theme or the accent (`ThemeWearing`).
        @usableFromInline
        static func wearsTheTheme(_ value: Value) -> Bool {
            (value as? any ThemeWearing)?.wearsTheTheme == true
        }

        /// Whether the image is a journey's rather than the value's own lanes.
        /// Design: docs/design/core/state.md#a-state-has-one-shape
        private(set) var journeyed = false

        /// Puts the value there - where it is, where it is going, standing still - and keeps it, as every road a
        /// value comes in by does; for a plain value, a write.
        func snap(_ newValue: Value) {
            if let hostSnap {
                themed = Self.wearsTheTheme(newValue) ? newValue : nil
                hostSnap(newValue)
                keep?(newValue)
            } else {
                write(newValue)
            }
        }

        /// Whether the host carries this state.
        var carried: Bool { image != nil }

        /// The value's own motion - `@State(motion:)`, else `.inherited`, or what `journey.setMotion(_:)`
        /// gave it - which a write that names none travels under.
        var law: Motion = .inherited

        /// Whether that motion is one a motion layout gave its parameters, which the layout may change.
        var lawIsTheLayouts = false

        /// The seat of the engine that animates this state, where it is declared `@State(animatedBy: .engine)`.
        /// Design: docs/design/core/journeys.md#an-engine-that-animates
        var animatorSeat: AnimatorSeat?

        /// Whether any build ever read this state - sticky, and what a write consults
        /// before asking for a render.
        /// Design: docs/design/core/invalidation.md#live-readers
        @usableFromInline var readAtBuild = false

        /// The conversion this storage is the derived side of, held weakly to break a
        /// ring (Conversion.swift).
        /// Design: docs/design/core/journeys.md#conversions
        weak var conversion: Conversion?

        /// The derived states worked out from this one, by the element and the line that
        /// wrote each conversion - known weakly: the element holds them.
        var derivations: [DerivationKey: Derivation] = [:]

        /// The derived state a conversion written at `site` keeps - made once for the
        /// element being built, then kept while the element holds it.
        /// Design: docs/design/core/journeys.md#conversions
        func derived<Out>(_: Out.Type, at site: PathNumber, make: @escaping () -> Out) -> State<Out>.Storage {
            let key = DerivationScope.key(site)

            if let kept = derivations[key]?.state as? State<Out>.Storage {
                DerivationScope.hold(kept)
                return kept
            }

            let made = State<Out>(making: make).storage
            let heldHere = !DerivationScope.hold(made)

            // Held by this state, it is worked out at once, so nothing it keeps holds this state.
            // Design: docs/design/core/journeys.md#conversions
            if heldHere { _ = made.value }

            derivations = derivations.filter { $0.value.state != nil }
            derivations[key] = Derivation(made, heldHere: heldHere)
            return made
        }

        /// What every read starts with: the renderer hears it, and the state keeps whether a build read it.
        @usableFromInline
        func noteRead() {
            if Renderer.shared.stateRead(self) { readAtBuild = true }
        }

        /// What every write ends with, this side's and the host's: the readers are asked,
        /// and nobody where no build read the state.
        /// Design: docs/design/core/invalidation.md#live-readers
        @usableFromInline
        func askForRender() {
            // No build ever read it: nobody to render for, and this costs one load.
            if readAtBuild {
                Renderer.shared.stateChanged(self)
            }
        }

        init(_ make: @escaping () -> Value) {
            self.make = make
        }

        /// The value, worked out the first time.
        @inlinable
        func settled() -> Value {
            if let make {
                held = make()
                self.make = nil
            }

            // Written just above where it was missing.
            return held!
        }

        /// The value, read or written whole.
        @inlinable
        var value: Value {
            get {
                if let hostRead { return themed ?? hostRead() }

                return settled()
            }
            set {
                if let hostWrite {
                    themed = Self.wearsTheTheme(newValue) ? newValue : nil
                    hostWrite(newValue)
                    return
                }

                held = newValue
                make = nil
                written &+= 1
            }
        }

        /// Whether a write of `value` may land: not from a superseded run, and not a value the state refuses.
        /// Design: docs/design/core/runs.md#a-superseded-run
        @usableFromInline
        func admitsWrite(_ value: Value) -> Bool {
            // A conversion's arithmetic writes nothing: it is worked out, and may be worked out again.
            // Design: docs/design/core/journeys.md#conversions
            guard !ConversionEvaluation.running else {
                complain("`\(origin ?? "a state")` was written inside a conversion's arithmetic, which reads its "
                    + "sources and writes nothing; the write is refused.")
                return false
            }
            #if DEBUG
            HandlerRun.noteWrite(of: self, named: "`\(origin ?? "a state")`")
            #endif
            return HandlerRun.admitsWrite(of: origin) && admits(value)
        }

        /// Whether the state takes `value` - asked on every road a value comes in by, before it lands: a value
        /// refused is said once and lands nowhere.
        /// Design: docs/design/core/state.md#kept-state
        @usableFromInline
        func admits(_ value: Value) -> Bool {
            guard let why = refuses?(value) else { return true }

            complain(why)
            return false
        }

        /// Takes the state as it stands and answers what puts it back so - the value, what the host carries of it
        /// whole and what waited to be published, every count - silently: nobody is asked, nothing is kept.
        /// Design: docs/design/core/journeys.md#the-way-back
        func stager() -> () -> Void {
            let (standing, themedStanding, writtenStanding, carried) = (value, themed, written, hostHeld?())
            return { [weak self] in
                guard let self else { return }
                if let carried {
                    carried()
                } else {
                    self.held = standing
                    self.make = nil
                }
                self.themed = themedStanding
                self.written = writtenStanding
            }
        }

        /// The program writes `value` into this state: where it is derived, by `conversion`'s way back, its sources
        /// taking what it goes back to whole or not at all - refused, and said, with no way back or where the value
        /// is not what the sources make of it. Answers whether the write may go on; a plain state's always may.
        /// Design: docs/design/core/journeys.md#the-way-back
        func writtenBack(_ value: Value, by conversion: Conversion?) -> Bool {
            guard let conversion else { return true }

            switch conversion.writeBack(value, origin: .program) {
            case .landed:
                return true
            case .refused(let why):
                complain(why)
            case .readOnly:
                complain("`\(origin ?? "a converted state")` is derived with no way back and was written: it is "
                    + "read-only. Write its source, or give the conversion `back:`.")
            }
            return false
        }

        /// Why a state refuses a value it is handed - said once, nothing lands - or nil; set once, as `keep` is.
        /// Design: docs/design/core/state.md#kept-state
        @usableFromInline var refuses: ((Value) -> String?)?

        /// What a state does with every value it takes, whoever writes it - the
        /// program, a binding, the host: a kept state marks its key for saving, a
        /// window's value retargets its window, the application's theme reaches the
        /// host. Set once, by whoever made the state.
        /// Design: docs/design/core/state.md#kept-state
        @usableFromInline var keep: ((Value) -> Void)?

        /// Writes the value and keeps it, so a kept state's save never comes apart
        /// from its write.
        /// Design: docs/design/core/state.md#the-ui-threads-state
        @inlinable
        func write(_ newValue: Value) {
            if let hostWrite {
                themed = Self.wearsTheTheme(newValue) ? newValue : nil
                hostWrite(newValue)
                keep?(newValue)
                return
            }

            held = newValue
            make = nil
            written &+= 1
            keep?(newValue)
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
        let made: HostStorage? = {
            if let image, journeyed { return image }

            // Refused where the host already has the value's own image by number; an image
            // it has no number for yet is reshaped below.
            if let image, image.number != nil { return nil }

            let initial = image.map { Self.lifted(from: $0) } ?? settled()
            let start = JourneyLanes(initial, motion: law)

            themed = Self.wearsTheTheme(initial) ? initial : nil
            let made: HostStorage

            if let image {
                Renderer.shared.board.reshape(image, to: StateImage.bytes(of: start.carried(in: .current)))
                made = image
            } else {
                made = HostStorage(StateImage.bytes(of: start.carried(in: .current)))
                made.origin = origin
                Renderer.shared.board.hold(made)
            }

            made.journeyWidth = Value.lanes
            made.presented = { [weak self] in self?.presentationMoved() }
            made.closed = { [weak self] in self?.animatorSeat?.end(.detached, afterPresentation: false) }
            image = made
            journeyed = true
            held = nil
            make = nil
            // The destination this side last knew: the host writes it back on landing, and
            // that asks for nothing.
            let known = Known(start.destination)

            hostRead = { Self.journey(on: made).destination }
            hostWrite = { [weak self] target in
                var journey = Self.journey(on: made)

                journey.destination = target

                // A move's own law ended with it: a write travels under the value's own.
                // Design: docs/design/core/journeys.md#moving-and-waiting
                let own = self?.law ?? journey.motion
                let lawful: [JourneyPart] = journey.motion == own ? [] : [.motion]
                journey.motion = own

                // An engine's state: a newer destination ends the movements handed to the engine before it.
                let engineAnimates = journey.motion.kind == .custom
                if engineAnimates { self?.animatorSeat?.end(.superseded, afterPresentation: false) }

                // Nobody animates it - no consumer, or an engine's state with no engine registered: the value
                // lands where it is sent.
                // Design: docs/design/core/state.md#a-state-nobody-wears
                if engineAnimates ? self?.animatorSeat?.isTaken != true : made.consumers == 0 {
                    journey.value = target
                    journey.velocity = JourneyLanes<Value>.still
                    known.destination = target
                    Self.lay([.value, .destination, .velocity] + lawful, of: journey, on: made)
                    return
                }

                known.destination = target
                Self.lay([.destination] + lawful, of: journey, on: made)
            }
            hostSnap = { [weak self] landed in
                var journey = Self.journey(on: made)

                self?.animatorSeat?.end(.superseded, afterPresentation: false)

                journey.value = landed
                journey.destination = landed
                journey.velocity = JourneyLanes<Value>.still

                known.destination = landed
                Self.lay([.value, .destination, .velocity], of: journey, on: made)
            }
            noted = { destination in known.destination = destination }
            hostHeld = {
                let (held, destination) = (Renderer.shared.board.held(made), known.destination)
                return {
                    known.destination = destination
                    Renderer.shared.board.restore(held, to: made)
                }
            }
            made.told = { [weak self, unowned made] mask, origin in
                let now = Self.journey(on: made)

                if mask & JourneyLanes<Value>.mask(of: .destination) != 0, !known.stands(at: now.destination) {
                    // The destination moved - a drag, a press: every reader is asked, and a
                    // kept state keeps where it is going. One the state refuses is put back where
                    // it stood, standing still, which the host hears as any write.
                    guard self?.admits(now.destination) ?? true else {
                        self?.hostSnap?(known.destination)
                        return
                    }
                    known.destination = now.destination
                    self?.themed = nil
                    if self?.reportedToConversion(now.destination, by: origin) == true { return }
                    self?.askForRender()
                    self?.keep?(now.destination)
                }
            }

            return made
        }()

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

    /// Writes `parts` of the journey and leaves every other lane as it lies; the board
    /// finds which moved, and `forcing` marks lanes a write means even unmoved.
    /// Design: docs/design/core/journeys.md#writing-the-parts
    func lay(_ parts: [JourneyPart], of lanes: JourneyLanes<Value>, forcing: UInt64 = 0) {
        guard journeyed, let image else { return }

        Self.lay(parts, of: lanes, on: image, forcing: forcing)
    }

    /// Tells the storage a destination sent by another road than a write, so the host
    /// writing it back on landing asks for nothing - and keeps the pair it wears, as a
    /// write does, or lets go of the one it kept.
    /// Design: docs/design/core/state.md#themed-colors-on-a-carried-state
    func noteDestination(_ destination: Value) {
        themed = Self.wearsTheTheme(destination) ? destination : nil
        noted?(destination)
    }

    /// Takes the destination a movement sent as the state's value, as a write does - the readers asked, a kept
    /// state keeping it - its journey laid already, on the movement's own law.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    func moved(to destination: Value) {
        noteDestination(destination)
        askForRender()
        keep?(destination)
    }

    /// Lets go of the pair a stopped value no longer stands for.
    /// Design: docs/design/core/state.md#themed-colors-on-a-carried-state
    func stoppedWhereItStands() {
        themed = nil
    }

    /// The destination this side last knew, shared by three closures.
    @MainActor
    private final class Known {
        var destination: Value

        init(_ destination: Value) { self.destination = destination }

        /// Whether a destination is the one already known, lane for lane.
        func stands(at other: Value) -> Bool {
            StateImage.bytes(of: destination.carried(in: .current)) == StateImage.bytes(of: other.carried(in: .current))
        }
    }

    /// The journey as its lanes stand, or one at nought where they stand for none.
    private static func journey(on image: HostStorage) -> JourneyLanes<Value> {
        JourneyLanes<Value>(
            carried: Renderer.shared.board.read(image, lanes: JourneyLanes<Value>.lanes))
            ?? JourneyLanes(nothing)
    }

    /// Writes `parts` of the journey, each in the theme in force, over the lanes as they
    /// lie: a value read back through its type - a color's eight bits a channel - is not
    /// always the lanes it was read from, and a lane rewritten so reads as moved.
    /// Design: docs/design/core/journeys.md#writing-the-parts
    private static func lay(
        _ parts: [JourneyPart], of journey: JourneyLanes<Value>, on image: HostStorage, forcing: UInt64 = 0
    ) {
        let board = Renderer.shared.board
        guard case .lanes(let written) = journey.carried(in: .current) else { return }
        // A write of the destination is a write of the state; any other part moves no stamp.
        let stamping = parts.contains(.destination)
        guard case .lanes(var lanes) = board.read(image, lanes: JourneyLanes<Value>.lanes),
              lanes.count == written.count
        else {
            board.write(StateImage.bytes(of: .lanes(written)), to: image, forcing: forcing, stamping: stamping)
            return
        }

        for part in parts {
            for lane in JourneyLanes<Value>.range(of: part) { lanes[lane] = written[lane] }
        }

        board.write(StateImage.bytes(of: .lanes(lanes)), to: image, forcing: forcing, stamping: stamping)
    }
}

extension State.Storage where Value: StateValue {
    /// Publishes a destination worked out for a derived state: written where it differs, lane for lane - a
    /// destination alone, so a host showing the state takes it there under the state's own motion - and the
    /// readers asked where `asking` says. An equal one is nothing: no revision, no movement begun again.
    /// Design: docs/design/core/journeys.md#conversions
    func publish(_ destination: Value, asking: Bool) {
        guard StateImage.bytes(of: destination.carried(in: .current)) != StateImage.bytes(of: value.carried(in: .current))
        else { return }

        write(destination)

        if asking { askForRender() }
    }

    /// The host wrote `value` into this state. A derived state hands the user's to its way back - the sources take
    /// it whole or not at all - and stands again at what its sources make; no other report goes back. Answers
    /// whether the state is a derived one.
    /// Design: docs/design/core/journeys.md#the-way-back
    func reportedToConversion(_ value: Value, by origin: WriteOrigin) -> Bool {
        guard let conversion else { return false }

        if origin == .user {
            switch conversion.writeBack(value, origin: .user) {
            case .landed: keep?(value)
            case .refused(let why): complain(why)
            case .readOnly: break
            }
        }
        // What the sources make of it, the round trip's value where the way back is no exact inverse.
        conversion.land()
        return true
    }

    /// The image the host carries this state on as its own lanes, made once from the
    /// value as it stands - or nothing, said out loud, where the image is a journey's.
    /// Design: docs/design/core/state.md#carried-state
    func carry() -> HostStorage? {
        let made: HostStorage? = {
            if let image { return journeyed ? nil : image }

            let initial = settled()
            let bytes = StateImage.bytes(of: initial.carried(in: .current))
            let made = HostStorage(bytes)

            themed = Self.wearsTheTheme(initial) ? initial : nil

            made.origin = origin
            Renderer.shared.board.hold(made)

            image = made
            held = nil
            make = nil

            // The bytes this side last knew: a host write putting them back asks nothing.
            // Design: docs/design/core/state.md#what-the-host-writes-back
            let known = KnownBytes(bytes)

            hostRead = { Self.lifted(from: made) }
            hostWrite = { value in
                let bytes = StateImage.bytes(of: value.carried(in: .current))
                known.bytes = bytes
                Renderer.shared.board.write(bytes, to: made)
            }
            hostHeld = {
                let (held, bytes) = (Renderer.shared.board.held(made), known.bytes)
                return {
                    known.bytes = bytes
                    Renderer.shared.board.restore(held, to: made)
                }
            }

            // A host write ends where this side's do, the storage deciding by its readers; a
            // value it refuses is put back, which the host hears as any write.
            made.told = { [weak self, unowned made] _, origin in
                let value = Self.lifted(from: made)
                let now = StateImage.bytes(of: value.carried(in: .current))

                guard now != known.bytes else { return }
                guard self?.admits(value) ?? true else {
                    return Renderer.shared.board.write(known.bytes, to: made)
                }

                known.bytes = now
                self?.themed = nil
                if self?.reportedToConversion(value, by: origin) == true { return }
                self?.askForRender()
                self?.keep?(value)
            }

            return made
        }()

        if made == nil {
            complain("`\(origin ?? "a state")` is carried as a journey - an animated "
                + "driven property's, a slider's, a stepper's or a scroller's - and was "
                + "handed to something that carries the value itself. One state has one "
                + "shape: declare a second state for the other.")
        }

        return made
    }

    /// The bytes this side last knew, shared by the writer and the host's hook.
    @MainActor
    private final class KnownBytes {
        var bytes: [UInt8]

        init(_ bytes: [UInt8]) { self.bytes = bytes }
    }

    /// Lays the half in force of a value wearing the theme and makes the element being built the
    /// theme's reader.
    /// Design: docs/design/core/state.md#themed-colors-on-a-carried-state
    func wearThemedPair() {
        guard let themed, let hostRead, let hostWrite else { return }

        // The reads that make this element the theme's reader, and the accent's.
        _ = StandardEnvironment.application.info.colorScheme
        _ = StandardEnvironment.application.info.accentColor

        guard StateImage.bytes(of: themed.carried(in: .current)) != StateImage.bytes(of: hostRead().carried(in: .current)) else { return }

        hostWrite(themed)
    }

    /// The value as the lanes stand, or `nothing` where they stand for none.
    static func lifted(from image: HostStorage) -> Value {
        Value(carried: Renderer.shared.board.read(image, lanes: Value.lanes))
            ?? nothing
    }

    /// What a value answers where its bytes stand for none of its type - every lane
    /// nought, or empty text. Only a faulty host causes it, and a frame frozen beats
    /// a trap.
    private static var nothing: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0))))
            ?? Value(carried: .string(""))!
    }
}
