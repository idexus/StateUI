// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `@State`, the one declaration of mutable state, and `Binding`, the way to
// borrow one. A write asks the views that read it for a render, from any thread.
// Design: docs/design/core/state.md#storage-and-box

import Synchronization

/// A mutable piece of state, owned by whoever declares it.
///
///     struct CounterPage: ContentView {
///         @State private var counter = 0
///         …
///     }
///
/// Writing asks the views that read it for a render, and a write nobody reads
/// asks for nothing. A view's state survives the view being rebuilt for as long
/// as the element keeps its key and its view type; leaving the tree ends it.
/// State on the application lives as long as the app does. It may be read and
/// written from any thread.
@propertyWrapper
public final class State<Value>: @unchecked Sendable {
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

        /// What the author calls this state (Core/Builds.swift). Outside the lock: every
        /// walk writes the same name.
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
        /// ring (Core/Conversion.swift).
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

    /// Where the value lives, across every render.
    private(set) var storage: Storage

    /// What a write does besides holding the value - marking a kept state's key for
    /// saving; a closure, because only a `PersistentValue` can make it.
    private var save: ((Value) -> Void)?

    /// What pairs this state with the scene it is built in - a `SceneKey` state only
    /// (Core/Scenes.swift).
    private var sceneClaim: ((SceneRecord) -> Void)?

    /// The one initializer the others go through, and the only place a storage is
    /// made.
    init(making value: @escaping () -> Value) {
        storage = Storage(value)
    }

    /// State holding `initialValue` - the way to declare it at file scope, where a
    /// property wrapper is not allowed: `let counter = State(0)`.
    ///
    /// The expression runs when the value is first wanted, and a state that adopts
    /// another's storage never wants it.
    public convenience init(_ initialValue: @autoclosure @escaping () -> Value) {
        self.init(making: initialValue)
    }

    /// What `@State private var counter = 0` calls. The expression runs when the
    /// value is first wanted.
    public convenience init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(making: wrappedValue)
    }

    /// State holding `value`, whatever it is - what Core/Observable.swift's
    /// initializers delegate to without resolving back to themselves.
    convenience init(holding value: @autoclosure @escaping () -> Value) {
        self.init(making: value)
    }

    /// The value. Writing asks the views that read it for a render; reading records
    /// a dependency while a view is built and costs nearly nothing elsewhere.
    ///
    /// Safe from any thread. `counter += 1` is a read and then a write; two tasks
    /// changing one state at once use `_counter.update { $0 + 1 }`.
    public var wrappedValue: Value {
        get {
            if Renderer.shared.stateRead(storage) { storage.readAtBuild = true }
            return storage.value
        }
        set {
            storage.write(newValue, then: save)
            askForRender()
            wakeForSave()
        }
    }

    /// Wakes the host to take the save a kept state's write recorded, whether or not
    /// the write asked for a render.
    /// Design: docs/design/core/state.md#kept-state
    private func wakeForSave() {
        if save != nil {
            UIThreadExecutor.shared.poke()
        }
    }

    /// Every write ends here (`Storage.askForRender()`).
    private func askForRender() { storage.askForRender() }

    /// What `$counter` gives: this state, for something else to borrow.
    ///
    /// Hand it to a child that writes it (`@Binding`), to a control that shows it
    /// and writes it back (`TextField($name)`), to a modifier the host carries it
    /// through (`.opacity($fade)`), or to an engine that follows it. Handing it over
    /// reads nothing, so it makes nobody a reader.
    public var projectedValue: Binding<Value> { Binding(self) }

    // Declared in the class body: the compiler passes over it in an extension.
    // Design: docs/design/core/state.md#model-state
    /// How a `@State` declared inside a class is read and written:
    ///
    ///     final class Profile {
    ///         @State var name = ""
    ///         @State var visits = 0
    ///     }
    ///
    /// Each property behaves as a `@State` in a view does: a read at build records
    /// that property and a write names it, so `profile.visits += 1` rebuilds the
    /// closures that read `visits` and none that read `name`. The model's own
    /// `$name` is the whole state; `$profile.name` is a part of the state holding
    /// the model.
    ///
    /// - Parameters:
    ///   - model: the object the property belongs to.
    ///   - wrappedKeyPath: the property, as the author declared it.
    ///   - storageKeyPath: this state, behind it.
    public static subscript<Model: AnyObject>(
        _enclosingInstance model: Model,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<Model, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Model, State<Value>>
    ) -> Value {
        get {
            let state = model[keyPath: storageKeyPath]
            state.name(within: model)
            return state.wrappedValue
        }
        set {
            let state = model[keyPath: storageKeyPath]
            state.name(within: model)
            state.wrappedValue = newValue
        }
    }

    /// The object that is this state: the storage, which every rebuilt box adopts.
    var lender: AnyObject { storage }

    /// Reads the value, recording the dependency exactly as the wrapper does.
    ///
    ///     let counter = State(0)          // at file scope
    ///     Label("Count: \(counter.get())")
    ///
    /// For state held WITHOUT the wrapper - at file scope, where Swift allows
    /// no property wrapper at all. On `@State private var counter = 0` the
    /// plain name reads the same value, and that is the spelling to use.
    public func get() -> Value {
        if Renderer.shared.stateRead(storage) { storage.readAtBuild = true }
        return storage.value
    }

    /// Writes the value computed from the one it holds, under one hold of the lock.
    ///
    ///     counter.update { $0 + 1 }
    ///
    /// For state held without the wrapper, and through the box (`_counter.update`)
    /// for two tasks changing one state at the same moment, where a read and a
    /// write from each would lose one of them.
    ///
    /// - Parameter transform: given the current value, answers the new one. It runs
    ///   under the lock, so it must not touch this state again.
    public func update(_ transform: (Value) -> Value) {
        storage.update(transform, then: save)
        askForRender()
        wakeForSave()
    }
}

extension Binding {
    /// The storage this binding borrows, where it is a whole `@State`'s; nothing for
    /// a part of a state or a binding made from closures.
    var described: State<Value>.Storage? {
        lent == nil ? lender as? State<Value>.Storage : nil
    }

    /// The value as it stands, without recording a read - what the machinery of a
    /// write reads.
    /// Design: docs/design/core/state.md#reading-without-recording
    var standing: Value { described.map { $0.value } ?? wrappedValue }

    /// The storage an engine follows - the borrowed state's own; nothing for a part
    /// of a state or a binding made from closures.
    public var followed: (any FollowedState)? { described }

}

extension Binding where Value: StateValue {
    /// The image the host carries the borrowed state on, made the first time anything
    /// asks and kept for good - what every driven modifier and feed takes from
    /// `$state`. Nothing for a part of a state or a binding made from closures.
    public var image: HostStorage? { described?.carry() }
}

extension Binding where Value: Walked {
    /// The image the host animates this state on as a journey - what a driven
    /// property takes from `$x`.
    var journeyImage: HostStorage? { described?.carryAsJourney() }

    /// The journey the borrowed state is on: where the value is this frame, where it
    /// is going, how fast, under what law - and `move(to:)` to send it and wait.
    public var journey: Journey<Value> { Journey(of: self) }
}

extension State where Value: StateValue {
    /// The image the host carries this state on, whichever shape - what a test
    /// reaches for where an application writes `$x`.
    var image: HostStorage { storage.image ?? storage.carry()! }

    /// The number the host quotes this state by; asking has the host carry it.
    var number: Int32 { Renderer.shared.number(for: image) }
}

extension Binding where Value: StateValue {
    /// The number the host quotes the borrowed state by, or nothing.
    var number: Int32? { image.map { Renderer.shared.number(for: $0) } }
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

extension State {
    /// Names every state the model holds by its property, once per model, on the
    /// first touch of any of them.
    /// Design: docs/design/core/state.md#model-state
    private func name(within model: AnyObject) {
        guard storage.origin == nil else { return }

        var mirror: Mirror? = Mirror(reflecting: model)

        while let level = mirror {
            for child in level.children {
                if let label = child.label, let box = child.value as? AnyModelState {
                    box.name(once: BuildScope.readable(label))
                }
            }

            mirror = level.superclassMirror
        }

        // Named by now; the fallback word stops the mirror being taken again.
        storage.name(once: "state")
    }
}

/// A `@State` of any value, as a model's naming reflection meets it.
protocol AnyModelState: AnyObject {
    /// Names the storage where nothing has yet.
    func name(once name: String)
}

extension State: AnyModelState {
    func name(once name: String) {
        storage.name(once: name)
    }
}

extension State: StateBox {
    /// Tells the storage what the author calls it, tidied from the walk's path.
    func named(_ path: String) {
        storage.origin = BuildScope.readable(path)
    }

    /// Takes over the other box's storage - how a view's `@State` survives the view
    /// being rebuilt. Shared, not copied, so a suspended handler's write lands.
    /// Design: docs/design/core/state.md#storage-and-box
    func adopt(from other: AnyObject) {
        guard let other = other as? State<Value>, other !== self else { return }

        storage = other.storage
    }
}

/// How often a reading is taken - the cadence of
/// `.samples($fade, into: $shown, .every(100))`. A state itself has no cadence;
/// two views may read one value at two rates.
public enum Asks: Equatable, Sendable {
    /// A reading on every frame the host writes.
    case always

    /// A reading at most once every so many milliseconds: the first frame in a
    /// window at once, the last when the window ends. The window is not a delay a
    /// render waits out. Nought or less is `.always`.
    case every(Int)

    /// How long a reading may be held back, in milliseconds.
    var window: Int {
        switch self {
        case .always: return 0
        case .every(let milliseconds): return max(0, milliseconds)
        }
    }
}

extension State where Value: Walked {
    /// State declared with its journey's law - how this value animates wherever it
    /// is shown, and who animates it.
    ///
    ///     @State(motion: .spring()) private var lift = 1.0    // a spring, wherever it is shown
    ///     @State(motion: .none) private var box = Rect.zero    // lands at once, wherever it is written
    ///     @State(motion: .custom) private var ball = 0.0       // an engine of your own animates it
    ///
    /// The value's own law comes ahead of the element's `.motion(_:)`, the
    /// application's and the library's. It can be changed later through
    /// `$x.journey.motion`, except `.custom`, which is settled here.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds, and where the journey starts.
    ///   - motion: the law the value animates under.
    public convenience init(wrappedValue: @autoclosure @escaping () -> Value, motion: Motion) {
        self.init(making: wrappedValue)

        storage.law = motion
    }
}

extension State where Value: PersistentValue {
    /// State the application keeps: the same state, under a name, still there on
    /// the next launch.
    ///
    ///     @State(persistentKey: .lastGroup) private var group = 0
    ///
    /// The value written here is what the state holds when the store has nothing
    /// under the name. Reading and writing are what they are on any `@State`:
    /// nothing is awaited, and a write reaches the store by itself. Two views
    /// declaring one key share the state. The application lists its keys in
    /// `persistentKeys`.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds when the store has nothing.
    ///   - persistentKey: the name it is kept under, and the kind of value it is.
    public convenience init(
        wrappedValue: @autoclosure @escaping () -> Value,
        persistentKey key: PersistentKey
    ) {
        self.init(making: wrappedValue)

        // A key declared for another type is said at once, rather than never saved.
        precondition(
            Value.persistentKind == key.kind,
            "'\(key.name)' was declared to keep a \(key.kind) and is written "
                + "on a \(Value.self), which is a \(Value.persistentKind)")

        // One claim, one hold: the key's standing storage, or this one adopted; the
        // stored value lands now or when the host's read arrives.
        // Design: docs/design/core/state.md#kept-state
        let own = storage

        if let shared = PersistentStore.shared.claim(
            key,
            orAdopt: own,
            landing: { held in
                if let value = Value(persisted: held) {
                    own.value = value
                }
            }) as? Storage {
            storage = shared
        }

        save = { PersistentStore.shared.record(key, $0.persistentValue) }
    }

    /// State a scene keeps: the same state, under a name, handed back with its scene
    /// when the system restores the application's windows.
    ///
    ///     @State(sceneKey: .section) private var section = 0
    ///
    /// Each scene has its own value under the name, and a new scene starts from the
    /// value written here. Declared outside every scene it is an ordinary state. A
    /// value every scene shares is `persistentKey:` instead.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds in a scene that kept nothing.
    ///   - sceneKey: the name it is kept under, and the kind of value it is.
    public convenience init(
        wrappedValue: @autoclosure @escaping () -> Value,
        sceneKey key: SceneKey
    ) {
        self.init(making: wrappedValue)

        precondition(
            Value.persistentKind == key.kind,
            "'\(key.name)' was declared to keep a \(key.kind) and is written "
                + "on a \(Value.self), which is a \(Value.persistentKind)")

        // Paired with its scene by the build that finds it there.
        // Design: docs/design/core/state.md#scene-kept-state
        sceneClaim = { [unowned self] record in self.claim(key, in: record) }

        // And at once where it is made inside a scene's build - a model's state.
        if let record = Scenes.shared.building {
            claim(key, in: record)
        }
    }

    /// Pairs this state with the scene it is built in: the scene's storage for the
    /// key, with what the platform kept landed, and the scene as where it is kept.
    private func claim(_ key: SceneKey, in record: SceneRecord) {
        let own = storage

        if let kept = record.claim(
            key.name,
            orAdopt: own,
            landing: { held in
                if let value = Value(persisted: held) {
                    own.value = value
                }
            }) as? Storage {
            storage = kept
        }

        save = { [weak record] in record?.record(key.name, $0.persistentValue) }
    }
}

extension State: SceneClaiming {
    func claimScene(_ record: SceneRecord) {
        sceneClaim?(record)
    }
}

/// A piece of state a view borrows from whoever owns it.
///
///     struct ResetRow: ContentView {
///         @Binding var counter: Int
///
///         var content: any View {
///             Button("Reset").onClicked { counter = 0 }
///         }
///     }
///
///     ResetRow(counter: $counter)
///
/// A write through it reaches the owner. `$` lends everything the owner can do:
/// a borrower may write the whole value or one property of it, and a model lent
/// this way may be edited or replaced; to hand over less, hand over the value or
/// the object instead. A class of `@State` properties is lent the same way:
/// `@Binding var basket: Basket`, with `basket.$note` the note's own state.
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
    // Two closures: reading and writing is all a binding asks of what it borrows.
    private let read: () -> Value
    private let write: (Value) -> Void

    // Who this borrows from - the storage and which part of it - so two spellings
    // of one state recognize each other. Only `described` reads it.
    // Design: docs/design/core/state.md#bindings
    let lender: AnyObject?
    let lent: AnyHashable?

    /// A binding to state somebody else owns. `$counter` is the ordinary way to
    /// get one.
    public init(_ state: State<Value>) {
        read = { state.get() }
        write = { state.wrappedValue = $0 }
        lender = state.lender
        lent = nil
    }

    /// A binding over a storage no box holds - a conversion's derived side: a read
    /// works the value out from its sources, a write lands as a control's report.
    init(over storage: State<Value>.Storage) {
        // Held here: the storage knows its conversion weakly.
        let conversion = storage.conversion

        read = {
            if let conversion = conversion {
                for source in conversion.sources where Renderer.shared.stateRead(source) {
                    source.readAtBuild = true
                }

                conversion.forward(false)
            }

            if Renderer.shared.stateRead(storage) { storage.readAtBuild = true }

            return storage.value
        }
        write = {
            storage.write($0, then: nil)
            storage.askForRender()
        }
        lender = storage
        lent = nil
    }

    /// The one the property subscripts use, with who the value came from.
    init(
        read: @escaping () -> Value,
        write: @escaping (Value) -> Void,
        lender: AnyObject?,
        lent: AnyHashable?
    ) {
        self.read = read
        self.write = write
        self.lender = lender
        self.lent = lent
    }

    /// A binding to something this library does not own: read it with `get`, write
    /// it with `set`.
    ///
    ///     TextField(Binding(get: { settings.name }, set: { settings.name = $0 }))
    ///
    /// Whether a write asks for a render is the setter's business: writing a
    /// `@State` does.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        read = get
        write = set
        lender = nil
        lent = nil
    }

    /// The value this borrows. Writing goes straight to the owner, and asks
    /// the owner's readers for a render as any other write does.
    public var wrappedValue: Value {
        get { read() }

        // Nonmutating: what changes is what the owner holds.
        nonmutating set { write(newValue) }
    }

    /// So a borrowed value can be lent on again, unchanged.
    public var projectedValue: Binding<Value> { self }

    /// A binding handed on as it is - which is what lets a closure handed one
    /// name its parameter `$id`, and read the value as `id`:
    ///
    ///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
    ///
    /// - Parameter projectedValue: the binding.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// A binding to one property of what this borrows - `$profile.name`.
    ///
    ///     TextField($profile.name)
    ///
    /// For a value: the whole is read, the property written, and the whole put back.
    /// A model takes the subscript below.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { newValue in
                var whole = wrappedValue
                whole[keyPath: keyPath] = newValue
                wrappedValue = whole
            },
            lender: lender,
            lent: keyPath)
    }

    /// A binding to one property of a model, through the model - `$basket.note`.
    ///
    ///     TextField($basket.note)
    ///
    /// The write goes straight to the object, and nothing is put back. It is a part
    /// of the state holding the model; the property's own state is `basket.$note`,
    /// which is what a control the host carries is handed.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { wrappedValue[keyPath: keyPath] = $0 },
            lender: lender,
            lent: keyPath)
    }
}

extension Binding where Value: MutableCollection, Value.Index: Hashable {
    /// A binding to one element of what this borrows - `$hops[2]`.
    ///
    ///     ForEach(Array(hops.enumerated()), id: \.offset) { hop in
    ///         Stepper($hops[hop.offset])
    ///     }
    ///
    /// The whole is read, the element written, and the whole put back. It is a part
    /// of the state, which a driven modifier refuses: values the host animates
    /// separately are separate states.
    ///
    /// - Parameter index: which element, in the collection's own index space.
    public subscript(index: Value.Index) -> Binding<Value.Element> {
        Binding<Value.Element>(
            read: { wrappedValue[index] },
            write: { newValue in
                var whole = wrappedValue
                whole[index] = newValue
                wrappedValue = whole
            },
            lender: lender,
            lent: index)
    }
}

// MARK: - A write that lands

extension Binding {
    /// Writes a report - a value the platform measured or the user moved - so it
    /// lands where it is: value, destination and a still speed together. A landed
    /// value is not saved.
    /// Design: docs/design/core/state.md#a-write-that-lands
    func land(_ value: Value) {
        if let storage = described {
            storage.snap(value)
            storage.askForRender()
        } else {
            wrappedValue = value
        }
    }
}

extension Binding: BorrowedState {
    var lends: (lender: AnyObject?, lent: AnyHashable?) { (lender, lent) }
}

/// `@unchecked Sendable` for the reason `State` is: a handler's `async let` child
/// writes through a binding from the pool.
/// Design: docs/design/core/state.md#sendable-promises
extension Binding: @unchecked Sendable {}
