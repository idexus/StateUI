// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State.
//
// The model is intentionally the simplest thing that works: state lives in
// observable boxes, and any write marks the tree dirty so the host re-renders.
//
// WHERE STATE MAY BE READ AND WRITTEN: anywhere. The value sits behind a lock,
// a write marks the tree and wakes the host from whatever thread made it, and
// a write that lands while a render is running is kept for the next one. So a
// handler writes it, a `Task.detached` that worked something out writes it,
// a child task started with `async let` writes it, and none of them has to
// hop first. What a handler may NOT do is move itself onto `@MainActor` or
// `DispatchQueue.main` to get there - nothing drains those on Android or
// Windows - and what nothing may do is read a value, think, and write it back
// from two tasks at once expecting both to count: that is `update(_:)`, which
// holds the lock across the three steps.
//
// Event handlers are closures written straight onto the node - see Node.swift.
// The ids C# quotes back are assigned in Diff.swift, where an element's identity
// is known, because an id has to belong to the element rather than to the tree
// that happened to mention it.

import Dispatch

/// A mutable piece of state, owned by whoever declares it.
///
///     struct CounterPage: ContentPage {
///         @State private var counter = 0
///         …
///     }
///
/// Writing marks the UI dirty, which is what triggers the next render - and
/// names this state as what changed, so the render rebuilds the views that read
/// it rather than everything (see Core/Invalidation.swift). Using a class
/// (reference type) means views can capture it without copying, so a closure
/// created during render still writes to the real value.
///
/// A view is a value rebuilt on every render, and its state survives that: the
/// differ hands the rebuilt view's boxes the storage their predecessors held,
/// for as long as the element keeps its identity and its view type - the same
/// rule that keeps a control. Leaving the tree is what ends the state. State on
/// the APPLICATION simply lives for as long as the app does, the application
/// being built once and kept.
///
/// `@unchecked Sendable` is a promise to the compiler that this type is safe to
/// reference across isolation boundaries. It is kept by a lock: the value is
/// read and written under one, so a box may be written from a handler on
/// `@MainThread`, read by the render on the host's UI thread, and written
/// again by a `Task.detached` that has an answer, all at once, and every
/// write is a whole one. `@unchecked` rather than `Sendable` because `Value`
/// itself need not be - a box may hold a class an author owns, and what the
/// lock guards is the box's HOLD on that value, not the value's insides.
///
/// Without it, Swift 6 rejects even declaring application state as a global
/// (`let counter = State(0)`), since a global of a non-Sendable type could in
/// principle be reached from anywhere.
@propertyWrapper
public final class State<Value>: @unchecked Sendable {
    /// Where the value actually lives.
    ///
    /// One indirection deeper than the box itself, and it is load-bearing: a
    /// view is rebuilt on every render, and a `@State` declared on one comes
    /// back as a NEW box holding the initial value. The differ then makes the
    /// new box ADOPT the old one's storage - see `adopt(from:)` - so every box
    /// that ever stood for this element's state points at the same storage, and
    /// a handler that captured last render's box writes where this render
    /// reads.
    ///
    /// The lock lives HERE and not on the box, because two boxes sharing a
    /// storage must share its lock too - a handler suspended across a render
    /// writes through last render's box. A serial `DispatchQueue` as the
    /// mutex, for the reason `MainThreadExecutor` gives: libdispatch is on
    /// every platform this targets and Foundation's locks bring ICU on
    /// Windows. Uncontended, a hold costs about the time of a function call.
    ///
    /// Internal rather than private so the tests can hold the invariant below
    /// directly: that a write and the record beside it happen under ONE hold.
    /// It appears in no public signature - `lender` erases it to `AnyObject` -
    /// so an application cannot name it.
    final class Storage: @unchecked Sendable, NamedState, AnyStateStorage, FollowedState {
        private let guarded = DispatchQueue(label: "StateUI.State")

        /// How many times this side has written the value while it lived
        /// here - bumped under the lock, beside the write it counts, and READ
        /// WITHOUT IT by an engine's `stirred()`: handlers and engines run on
        /// the one thread the host drains and draws on, so the read sees the
        /// write; a write from a detached task is seen a cycle late at worst,
        /// the count only ever growing. Not read under the lock on purpose -
        /// `carry()` takes the board's hold while holding this one, and
        /// `stirring` reads stamps under the board's, so a lock here would
        /// take the two in the other order.
        nonisolated(unsafe) private var written = 0

        /// How many times the state has been written, whoever wrote it - what
        /// an engine following it compares between two runs.
        ///
        /// TWO COUNTS ADDED, because a value has two homes in its life: this
        /// side's own writes while the value lives here, and every write to
        /// the image once the host carries it - this side's, which lay lanes
        /// on the image, and the host's own frames, which are told to it.
        /// Both count a write that put the same bytes back, so an engine
        /// following a number a finger is holding still hears every report.
        var stamp: Int { written &+ (image?.stamp ?? 0) }

        /// The value, once anybody has wanted it.
        ///
        /// OPTIONAL so that `make` below can stand in its place until then,
        /// and one level deeper than `Value` on purpose: a state holding an
        /// optional is ordinary, and `.some(nil)` is how this tells "the value
        /// is nil" from "there is no value yet".
        private var held: Value?

        /// What the value WOULD be, until something asks - then nothing.
        ///
        /// A `@State`'s initial value is written where the state is declared,
        /// and a view is a value rebuilt on every render: written eagerly, the
        /// expression beside every declaration would run on every render of
        /// every view that is described, and the result be thrown away by the
        /// adoption that hands this box its predecessor's storage. So it is
        /// held as the expression until a storage nobody adopted is read from,
        /// which is the one time the answer is kept.
        private var make: (() -> Value)?

        /// What the author calls this state - written by the reflection walk
        /// that finds the box, and read where a render is explained. See
        /// Core/Builds.swift.
        ///
        /// Outside the lock on purpose: it is a name, written to the same
        /// value by every walk that reaches the same property, and a render
        /// reading a torn one would say the wrong name at worst.
        nonisolated(unsafe) var origin: String?

        /// Names this storage where nothing has yet - the model road's
        /// half of `named(_:)`, under the lock because a model is written
        /// from any thread and two first touches may race to say the same
        /// thing. Where the reflection walk has named a view's state, or a
        /// first touch has named a model's, a second name is ignored.
        ///
        /// - Parameter name: what the author declared the property as.
        func name(once name: String) {
            guarded.sync {
                if origin == nil { origin = name }
            }
        }

        /// The image the HOST carries this state on, once anything has asked it
        /// to - a driven modifier, a feed, a two-way control. Nil until then,
        /// which is what most states are for their whole life; an engine
        /// following the state asks for none, following the storage itself.
        ///
        /// ON THE STORAGE, as everything that has to survive a rebuild is: a box
        /// is remade every render and adopts this, and the number the host
        /// quotes the value by is issued against the image - so an image kept on
        /// the box would be issued a new number every render while the host went
        /// on moving the old one.
        nonisolated(unsafe) private(set) var image: HostStorage?

        /// How the value is read and written once the host carries it - typed
        /// closures installed by `carry()`, because this class is generic over
        /// ANY value and only a `StateValue` has lanes to be read off an image.
        private var hostRead: (() -> Value)?
        private var hostWrite: ((Value) -> Void)?

        /// How a value the host walks as a JOURNEY is put somewhere at once -
        /// value and destination together, standing still - which is what a
        /// report written back means. Nil where a write already is that: a
        /// plain image has no destination apart from its value.
        private var hostSnap: ((Value) -> Void)?

        /// How a destination sent by another road than a write is made known
        /// to the host's hook - see `noteDestination(_:)`. Nil on a plain
        /// image, which compares bytes and needs no telling.
        var noted: ((Value) -> Void)?

        /// Whether the image is a JOURNEY's rather than the value's own lanes:
        /// made for a driven property, a `Slider`, a scroller - anything the
        /// host walks - or by the first read of `$x.journey`, and read back as
        /// where the value is GOING. One state has one shape, so a state
        /// handed to both a feed and a slider is said out loud and the second
        /// hand-over is refused.
        nonisolated(unsafe) private(set) var journeyed = false

        /// Puts the value THERE - where it is, where it is going, and standing
        /// still - which for a plain value is simply a write.
        func snap(_ newValue: Value) {
            if let hostSnap { hostSnap(newValue) } else { value = newValue }
        }

        /// Whether the host carries this state.
        var carried: Bool { image != nil }

        /// The law the value travels under wherever it is shown, as the
        /// declaration said it - `@State(motion:)` - or `.inherited` for the
        /// element's own. Read once, when the image is made: from then on
        /// the law lives in the journey's own lanes, and `Journey.motion`
        /// reads and writes it there. Meaningful for a `Walked` value alone,
        /// which is the only kind the initializer that writes it takes.
        nonisolated(unsafe) var law: Motion = .inherited

        /// Whether any BUILD has ever read this state - set by the first read
        /// that lands in an open scope, and never cleared.
        ///
        /// What a write consults before it asks for a render: a state no
        /// build ever read has no reader for the renderer to find, so asking
        /// would be a trip through its lock to be told no. STICKY on purpose -
        /// a state read once and then left by every reader goes on asking,
        /// and the renderer goes on refusing, which is the answer it always
        /// gave; what this makes cheap is the other case, a value the host
        /// carries that nobody ever prints, written forty times a second.
        ///
        /// Sound across a render: an element that read this state in the
        /// render under way set the flag as it read, before any write it or
        /// anything else could make; a read that comes AFTER the write sees
        /// the written value and needs no render for it.
        nonisolated(unsafe) var readAtBuild = false

        /// The conversion this storage is the DERIVED side of, if it is one -
        /// the arithmetic each way and the sources, for the differ to arm
        /// engines from. See Core/Conversion.swift.
        ///
        /// **WEAKLY, because a conversion belongs to the element that wrote
        /// it.** The arithmetic reads the sources, so it holds them; the
        /// derived state is kept on the first SOURCE so that one conversion is
        /// one state across renders. Held here strongly, those two make a ring
        /// - the source keeps the derived state, the derived state keeps the
        /// arithmetic, the arithmetic keeps the source - and no state of that
        /// view is ever freed. What owns it instead is the ENGINE the differ
        /// arms for it, which hands its number back when the element goes
        /// (`Diff.forget(_:)`), and the binding the conversion was made for,
        /// which carries it until the tree does.
        /// `ElementReleaseTests.testAMultiConversionGoesWithTheElement`.
        nonisolated(unsafe) weak var conversion: Conversion?

        /// The derived states worked out from this one, by the line that wrote
        /// each conversion - so a conversion written once is one state across
        /// every render, and the tie the host holds keeps its number.
        nonisolated(unsafe) var derivations: [String: AnyObject] = [:]

        /// The derived state a conversion written at `key` keeps, made the
        /// first time from `make` and the same object every time after.
        func derived<Out>(_: Out.Type, at key: String, make: @escaping () -> Out) -> State<Out>.Storage {
            if let kept = derivations[key] as? State<Out>.Storage { return kept }

            let made = State<Out>(making: make).storage

            derivations[key] = made
            return made
        }

        /// Asks for the render this write wants - at once, never, or on a cadence,
        /// as the storage's mode says. See `Asks`.
        ///
        /// A CADENCE IS NOT A DELAY THE READER WAITS OUT. What it holds back is
        /// this state's own ask; a render somebody else asks for in the meantime
        /// happens on time and reads this value as it now stands, since the value
        /// itself was written before this line. And the last write inside a window
        /// still gets a render of its own when the window ends, which is what the
        /// waiting arm is for - without it, a value that stopped moving would be
        /// left showing whatever the previous window ended on.
        ///
        /// A HOST write ends here too, through `HostStorage.told`: the host's
        /// frames are writes like any other, so the same rule and the same
        /// cadence answer them - nobody where no build read the state, and
        /// otherwise its readers, at most once a window.
        /// What every write ends with, this side's and the HOST's alike: the
        /// readers are asked, and nobody is asked where no build has read the
        /// state.
        ///
        /// THERE IS NO CADENCE HERE, and that is the whole shape of the
        /// design: a state is at its value the moment it is written - a
        /// journey stands at its DESTINATION from the first frame - so
        /// holding the ask back would show the same number again and again
        /// rather than a value sweeping. What sweeps is a SAMPLE, and
        /// `.samples(_:into:_:)` is what makes one. See Core/Sampling.swift.
        func askForRender() {
            // NO BUILD EVER READ IT, so there is nobody to render for and no
            // reason to ask: this is the whole of what a write to a value the
            // host carries costs on this side, and it is one load.
            if readAtBuild {
                Renderer.shared.stateChanged(self)
            }

            // A destination that moved is a journey that moved: whoever read
            // where the value IS is asked too.
            askJourneyReaders()
        }

        /// Asks the bodies that read the JOURNEY - where the value is, how
        /// fast - for a render, and nobody else.
        ///
        /// THE SECOND READER SET, keyed by the image rather than by this
        /// storage: a body that printed the destination is a reader of the
        /// state and is asked when the destination moves; a body that printed
        /// `$fade.journey.value` is a reader of the image and is asked on
        /// every frame the host writes. So a walk costs a build per frame
        /// exactly where somebody asked to see it move, and nothing where a
        /// body reads the state alone. `HostStorage.readAtBuild` is the
        /// flag, set by `Journey`'s reads.
        func askJourneyReaders() {
            guard let image, image.readAtBuild else { return }

            Renderer.shared.stateChanged(image)
        }


        init(_ make: @escaping () -> Value) {
            self.make = make
        }

        /// The value, worked out if this is the first time anybody wanted it.
        ///
        /// Called under the lock and nowhere else, so the expression runs
        /// once however many readers arrive at once.
        private func settled() -> Value {
            if let make {
                held = make()
                self.make = nil
            }

            // Written just above where it was not already there, so there is
            // always a value by this line.
            return held!
        }

        /// The value, read or written whole under the lock.
        var value: Value {
            get {
                if let hostRead { return hostRead() }

                return guarded.sync { settled() }
            }
            set {
                if let hostWrite {
                    hostWrite(newValue)
                    return
                }

                guarded.sync {
                    held = newValue
                    make = nil
                    written &+= 1
                }
            }
        }

        /// Writes the value and hands it to `then` under ONE hold.
        ///
        /// The two must not come apart. `then` is what puts the value where
        /// the next drain will save it, and both halves being separately
        /// thread-safe is not enough: two tasks writing at once can settle the
        /// VALUE in one order and reach the store in the other, leaving the
        /// state holding the newer value and the store holding the older -
        /// which is then what the next launch reads. Under one hold, whoever
        /// writes last records last, because it never let go in between.
        ///
        /// - Parameter then: runs under the lock, so it must be short and must
        ///   never touch this state again - `record` is a value converted and
        ///   put in a dictionary, which is the whole of what belongs here.
        func write(_ newValue: Value, then: ((Value) -> Void)?) {
            if let hostWrite {
                // The board's own hold is what serialises a carried write; the
                // record beside it is made after, outside that hold.
                hostWrite(newValue)
                then?(newValue)
                return
            }

            guarded.sync {
                held = newValue
                make = nil
                written &+= 1
                then?(newValue)
            }
        }

        /// Reads, changes, writes and records under ONE hold - so two tasks
        /// counting at once both count, and the store hears them in the order
        /// they landed.
        func update(_ transform: (Value) -> Value, then: ((Value) -> Void)?) {
            if let hostRead, let hostWrite {
                // A READ AND THEN A WRITE, not a hold: the host rewrites the
                // image on its own frames and nothing on this side can bracket
                // that, so what stands between the two is whatever the last
                // cycle left - the same pair `x += 1` is on a carried value.
                let settled = transform(hostRead())

                hostWrite(settled)
                then?(settled)
                return
            }

            guarded.sync {
                let settled = transform(settled())

                held = settled
                make = nil
                written &+= 1
                then?(settled)
            }
        }
    }

    /// Where the value lives, across every render.
    ///
    /// Readable inside the library rather than private, for the reason the
    /// lock inside it is: the tests hold this file's invariants directly, and
    /// what a write on a cadence decides is one of them.
    private(set) var storage: Storage

    /// What to do with a new value BESIDES holding it - present only on state
    /// declared with a `PersistentKey`, where it marks the key for saving.
    ///
    /// A closure rather than the key itself, because turning a value into what
    /// the wire carries needs `Value: PersistentValue` and this class is
    /// generic over every value. The constraint therefore lives at the
    /// initializer that makes the closure, and the setter below just calls it.
    private var save: ((Value) -> Void)?

    /// State that will hold whatever `value` answers - the one initializer the
    /// others go through, and the only place a storage is made.
    ///
    /// The value as a THUNK rather than a value: see `Storage.make`.
    init(making value: @escaping () -> Value) {
        storage = Storage(value)
    }

    /// State holding `initialValue`. The way to declare it at file scope, where
    /// a property wrapper is not allowed: `let counter = State(0)`.
    ///
    /// THE EXPRESSION IS NOT RUN UNTIL THE VALUE IS WANTED, and a state that
    /// adopts another's storage never wants it - so an initial value that
    /// costs something to work out costs it once, when this state is first
    /// read, rather than on every render that rebuilds the view declaring it.
    /// It is an ordinary Swift expression either way; what changes is when.
    public convenience init(_ initialValue: @autoclosure @escaping () -> Value) {
        self.init(making: initialValue)
    }

    /// What `@State private var counter = 0` calls.
    ///
    /// The expression beside the declaration is run when the value is first
    /// wanted, for the reason `init(_:)` gives.
    public convenience init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.init(making: wrappedValue)
    }

    /// State holding `value`, with nothing said about what kind of value it
    /// is - which is what the two warnings in Core/Observable.swift delegate
    /// to. Written there, `self.init(wrappedValue:)` would resolve back to the
    /// warning itself, both declarations having the same signature.
    convenience init(holding value: @autoclosure @escaping () -> Value) {
        self.init(making: value)
    }

    /// The value. Writing marks the tree dirty, naming this state as what
    /// changed; reading records a dependency while a view is being built, and
    /// costs nearly nothing anywhere else. The next render follows by itself,
    /// and rebuilds only what read this - see Core/Invalidation.swift.
    ///
    /// Safe from any thread, both ways. `counter += 1` through the wrapper is
    /// a read and then a write, two holds of the lock - right from a handler,
    /// where nothing runs between them, and right from one task at a time;
    /// two tasks incrementing the same state at once want `update(_:)` on
    /// the box (`_counter.update { $0 + 1 }`), which holds it across both.
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

    /// Wakes the host to take the save a kept state's write just recorded.
    ///
    /// Outside the storage's lock, which `record` ran under, and whether or
    /// not the write asked for a render: a kept state no view reads asks for
    /// none, and a save left to the render would wait for the next event
    /// instead. `Renderer.commandsPending` counts what is waiting as work, so
    /// the woken thread finds it. A wake is coalesced with the render's own,
    /// where there was one.
    private func wakeForSave() {
        if save != nil {
            MainThreadExecutor.shared.poke()
        }
    }

    /// What every write ends with: the storage decides whether anybody is
    /// rendered for it, and when. See `Storage.askForRender()`.
    private func askForRender() { storage.askForRender() }

    /// What `$counter` gives: this state, for something else to borrow.
    ///
    /// Hand it to a child that has to write the value (`@Binding`), to an
    /// input that shows it and writes it back (`Entry($name)`), or to a
    /// modifier that has the HOST carry it (`.opacity($fade)`,
    /// `following: $offset`) - which reads nothing at build, so handing it
    /// over makes nobody a reader: the value moving renders exactly the views
    /// that read it, and none where there are none.
    public var projectedValue: Binding<Value> { Binding(self) }

    /// The road a `@State` declared INSIDE A CLASS is read and written by:
    ///
    ///     final class Profile {
    ///         @State var name = ""
    ///         @State var visits = 0
    ///     }
    ///
    /// Swift routes such a property through the wrapper's TYPE with the
    /// instance in hand, where a state in a struct goes through `wrappedValue`
    /// directly. The value is the same storage's, read and written exactly as
    /// `wrappedValue` reads and writes it - a read at build records the
    /// property, a write names it, so `profile.visits += 1` rebuilds the
    /// closures that read `visits` and none that read `name`, as two
    /// `@State`s in a view would. What the instance buys is the NAME: nothing
    /// walks a class's stored properties - the reflection walk stops at a
    /// reference on purpose, Core/Stateful.swift - so a state in a model would
    /// have none, and `debugInfo()` would say `for Storage` where a state in a
    /// view says `for name`. The first access through any of a model's states
    /// reflects the instance ONCE and names every state it holds by the
    /// property it is declared as; every access after that is one nil check.
    ///
    /// The model's own `$name` is the whole state - `Entry(profile.$name)` is
    /// carried by the host and makes nobody a reader, `.opacity(profile.$fade)`
    /// is walked, `following: profile.$step` wakes an engine.
    /// `$profile.name` through a key path is a PART of the holding state and
    /// takes the described road, as `$room.width` does.
    ///
    /// DECLARED IN THE CLASS BODY AND NOT IN AN EXTENSION, and that is the
    /// one thing about it that is not a choice: the compiler looks this
    /// subscript up on the wrapper's own declaration, and one written in an
    /// extension is passed over in silence - the property then goes through
    /// `wrappedValue` directly, unnamed, with nothing said anywhere. Measured
    /// with a probe wrapper that answered through the subscript from its body
    /// and not from an extension. There is no such road for `profile.$name`:
    /// the projection is read-only, so no writable key path to it exists for
    /// the compiler to hand over - a state only ever handed on is named by
    /// the first read of it, and a state nobody reads is named nowhere it
    /// could be seen.
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

    /// The object that IS this piece of state.
    ///
    /// The STORAGE rather than the box, deliberately: a box is remade on
    /// every render and adopts the elder one's storage, so this is the one
    /// thing that means "this state" across rebuilds - which is what
    /// `Binding.described` needs to still name the right storage three
    /// renders later.
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

    /// Writes the value computed from the one it holds - the read, change and
    /// write the wrapper's `counter += 1` is, under ONE hold of the lock.
    ///
    ///     counter.update { $0 + 1 }
    ///
    /// For state held without the wrapper, as `get()` is - and, through the
    /// box (`_counter.update`), for the one case the wrapper's spelling cannot
    /// serve: two tasks changing the same state at the same moment, where a
    /// read-then-write from each would count one of them twice and the other
    /// not at all.
    ///
    /// - Parameter transform: given the current value, answers the new one.
    ///   Runs under the lock, so it must not touch this state again.
    public func update(_ transform: (Value) -> Value) {
        storage.update(transform, then: save)
        askForRender()
        wakeForSave()
    }
}

extension Binding {
    /// The storage this binding borrows, where it is a `@State`'s - what the
    /// host's image and the journey reach. Nothing for a closure binding or a
    /// PART of a state (`$room.width`), which has no image of its own.
    var described: State<Value>.Storage? {
        lent == nil ? lender as? State<Value>.Storage : nil
    }

    /// The value as it stands, WITHOUT recording a read.
    ///
    /// What the machinery of a write uses - `Journey`'s `move`, `stop`,
    /// `snap(to:)` and the lane setters all read the journey they are about
    /// to change - because a write reading what it is changing is not a view
    /// depending on the value. Recording it is worse than pointless: a completion answered
    /// while a render is running resumes the handler INSIDE that build, so the
    /// read lands in whatever element's scope is open and makes that element a
    /// reader of a state it never mentions. Measured on the gallery: one
    /// card's press animation made the window a reader of the card's own dip,
    /// and every example then opened at two builds instead of one.
    ///
    /// A part of a state, or a binding made from closures, has no storage to
    /// read - there the ordinary read is the only one there is.
    var standing: Value { described.map { $0.value } ?? wrappedValue }

    /// The storage an ENGINE follows - the borrowed state's own, whatever it
    /// holds and whichever shape the host carries it in, since following
    /// needs the stamp and nothing about the value. Nothing for a part of a
    /// state or a binding made from closures, which have no storage.
    public var followed: (any FollowedState)? { described }

}

extension Binding where Value: StateValue {
    /// The image the HOST carries the borrowed state on - made the first time
    /// anything asks for it, from the value as it stands, and kept for good.
    ///
    /// This is what every driven modifier and every feed take from a
    /// `$state`: NOT the value, which would be a read at build and therefore a
    /// reason to rebuild, but the image both sides rewrite between renders. A
    /// state reached this way and read nowhere costs no render however often
    /// it moves; one that IS read somewhere renders whenever it is written, by
    /// this side or by the host.
    ///
    /// Nothing for a part of a state (`$room.width`) or a binding made from
    /// closures: neither is a value the host can be handed whole.
    public var image: HostStorage? { described?.carry() }
}

extension Binding where Value: Walked {
    /// The image the host walks this state on as a journey - what a driven
    /// property takes from `$x`. Nothing for a part of a state, a binding
    /// made from closures, or a state the host already carries as the value
    /// itself and has the number of, the last of which is said out loud.
    var journeyImage: HostStorage? { described?.carryAsJourney() }

    /// The journey the borrowed state is on: where the value is this frame,
    /// where it is going, how fast, under what law - and the road to send it
    /// somewhere and wait, `$fade.journey.move(to:)`. See `Journey`.
    ///
    /// Every state over a value the host can walk has one, whether or not
    /// anything walks it yet; reading it is what first asks the host to.
    public var journey: Journey<Value> { Journey(of: self) }
}

extension State where Value: StateValue {
    /// The image the host carries this state on, made the first time anything
    /// asks - what a test reaches for where an application writes `$x`.
    ///
    /// Whichever shape it has: a state the host already walks as a journey
    /// answers that image, and one nothing has carried yet is carried now.
    var image: HostStorage { storage.image ?? storage.carry()! }

    /// The number the host quotes this state by, issued the first time
    /// anything asks. Asking has the host carry the state.
    var number: Int32 { Renderer.shared.number(for: image) }
}

extension Binding where Value: StateValue {
    /// The number the host quotes the borrowed state by, or nothing for a
    /// part of a state or a closure binding, which the host cannot carry.
    var number: Int32? { image.map { Renderer.shared.number(for: $0) } }
}

extension State.Storage where Value: Walked {
    /// The image the host carries this state on as a JOURNEY - what a driven
    /// property takes from the state: a `Slider`'s thumb, a label's font
    /// size, a border's colour, a scroller's offset, the host walking the
    /// property there rather than holding the value - and what
    /// `$x.journey` reads and writes. The same object every time after;
    /// nothing, said out loud, where the image already made is the value's
    /// own and the host has its number (`carry()`).
    ///
    /// The state goes on answering its plain type: a read is where the value
    /// is GOING, a write moves that destination alone and the host walks the
    /// value there under the value's law, and a snap - a report written back
    /// - lands value and destination together. So `volume = 1` on a
    /// `Slider($volume)` sends the thumb, and a drag arrives.
    ///
    /// **A STATE NOBODY WEARS LANDS WHERE IT IS WRITTEN.** Until an element
    /// registers the state the host has no number for it and nothing walks
    /// it, so a write puts the value at the destination as well - a value
    /// standing where it was sent, which is what a view described later
    /// shows from its first frame. Not under `.custom`, whose walker is an
    /// engine on this side.
    ///
    /// A HOST write asks the state's readers for a render only where the
    /// DESTINATION moved - a drag, a press - and never for a frame of a walk,
    /// which moves the value's lane alone and changes nothing this state
    /// answers; a frame asks the JOURNEY's readers, which is the second
    /// reader set (`askJourneyReaders()`).
    func carryAsJourney() -> HostStorage? {
        let made: HostStorage? = guarded.sync {
            if let image, journeyed { return image }

            // An image the host has never been told the number of - made by
            // a hand-over the differ has not yet registered, in the same body
            // that now hands `$v` to a slider - is RESHAPED here rather than
            // refused: nothing on the far side has a picture of it yet, and
            // the two hand-overs are one state. An image a registration has
            // crossed keeps its shape and the slider is refused, the host
            // being about to write one lane into a journey.
            if let image, image.number != nil { return nil }

            let start = JourneyLanes(image.map { Self.lifted(from: $0) } ?? settled(), motion: law)
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
            // WHERE THE VALUE IS GOING, as this side last knew it: what a host
            // write is compared against before it asks for a render, since
            // the host writes the destination back on landing - the same
            // number this side sent - and a reader printing it has nothing
            // to show for that.
            let known = Known(start.destination)

            hostRead = { Self.journey(on: made).destination }
            hostWrite = { target in
                var journey = Self.journey(on: made)

                journey.destination = target

                // NOBODY TO WALK IT: the value lands where it is sent.
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
                    // The destination moved - a drag, a press - and that is
                    // the state's own value: every reader is asked, the
                    // journey's included.
                    known.destination = now.destination
                    self?.askForRender()
                } else if mask & (JourneyLanes<Value>.mask(of: .value) | JourneyLanes<Value>.mask(of: .velocity)) != 0 {
                    // A frame of the walk: the state answers the same
                    // destination, and only whoever read the journey is asked.
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

    /// The image the host walks this state on, made now if nothing has yet -
    /// or nothing, quietly, where the host carries the state as the value
    /// itself and has its number. What `Journey` reads through: it complains
    /// nowhere, a read being no place for a complaint about a hand-over.
    func walkedImage() -> HostStorage? {
        if journeyed { return image }
        if let image, image.number != nil { return nil }

        return carryAsJourney()
    }

    /// The journey's lanes as they stand, read WITHOUT recording - what every
    /// write through `Journey` starts from, and what a reading or an engine
    /// takes. Nothing where the host walks the state in no journey's shape.
    var journeyLanes: JourneyLanes<Value>? {
        guard journeyed, let image else { return nil }

        return Self.journey(on: image)
    }

    /// Writes the journey's lanes whole; the board finds which of them moved.
    /// Nothing where the state is not a journey's.
    func lay(_ lanes: JourneyLanes<Value>) {
        guard journeyed, let image else { return }

        Self.lay(lanes, on: image)
    }

    /// Tells the storage a destination this side sent by another road than a
    /// write - `Journey.move(to:_:)` lays the lanes itself - so the host
    /// writing that same destination back on landing asks for nothing.
    func noteDestination(_ destination: Value) {
        noted?(destination)
    }

    /// The destination this side last knew, shared by the writers and the
    /// host's hook - a class, because the closures that keep it are three.
    private final class Known: @unchecked Sendable {
        nonisolated(unsafe) var destination: Value

        init(_ destination: Value) { self.destination = destination }

        /// Whether a destination is the one already known, lane for lane.
        func stands(at other: Value) -> Bool {
            StateImage.bytes(of: destination.carried) == StateImage.bytes(of: other.carried)
        }
    }

    /// The journey as its lanes stand, or one standing at nought where the
    /// bytes stand for none - which nothing on this side can bring about.
    private static func journey(on image: HostStorage) -> JourneyLanes<Value> {
        JourneyLanes<Value>(
            carried: Renderer.shared.board(of: image).read(image, lanes: JourneyLanes<Value>.lanes))
            ?? JourneyLanes(nothing)
    }

    /// The journey written into the lanes, whole - the board finds which of
    /// them moved.
    private static func lay(_ journey: JourneyLanes<Value>, on image: HostStorage) {
        Renderer.shared.board(of: image).write(StateImage.bytes(of: journey.carried), to: image)
    }
}

extension State.Storage where Value: StateValue {
    /// Writes the value where it differs from what stands, lane for lane, and
    /// asks the readers where `asking` says so - what a conversion's engines
    /// do on every cycle, and what a read at build does without asking.
    func settle(_ newValue: Value, asking: Bool) {
        guard StateImage.bytes(of: newValue.carried) != StateImage.bytes(of: value.carried) else { return }

        write(newValue, then: nil)

        if asking { askForRender() }
    }

    /// The image the host carries this state on, made the first time anything
    /// asks and the same object every time after - or nothing, said out loud,
    /// where the image already made is a journey's (`carryAsJourney()`).
    ///
    /// Made OF the value as it stands, so a state that was written before the
    /// host was asked to carry it starts where it was left. From here on the
    /// value lives on the image - reads decode its lanes, writes lay theirs -
    /// and the box's own hold is empty: two homes for one value would be two
    /// answers.
    func carry() -> HostStorage? {
        let made: HostStorage? = guarded.sync {
            if let image { return journeyed ? nil : image }

            let bytes = StateImage.bytes(of: settled().carried)
            let made = HostStorage(bytes)

            made.origin = origin
            Renderer.shared.board(of: made).hold(made)

            image = made
            held = nil
            make = nil

            // The bytes this side last knew, so a host write that puts the
            // same value back - a report of where a switch already stood -
            // asks for nothing.
            let known = KnownBytes(bytes)

            hostRead = { Self.lifted(from: made) }
            hostWrite = { value in
                known.bytes = StateImage.bytes(of: value.carried)
                Self.lay(value, on: made)
            }

            // A HOST write is a write: it ends where this side's do, and the
            // storage decides by its readers. Weak, because the image outlives
            // nothing - the board holds it for the state.
            made.told = { [weak self] _ in
                let now = StateImage.bytes(of: Self.lifted(from: made).carried)

                guard now != known.bytes else { return }

                known.bytes = now
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

    /// The bytes this side last knew a carried value by, shared by the writer
    /// and the host's hook.
    private final class KnownBytes: @unchecked Sendable {
        nonisolated(unsafe) var bytes: [UInt8]

        init(_ bytes: [UInt8]) { self.bytes = bytes }
    }

    /// The value as the lanes stand, or `nothing` where those bytes stand for
    /// no value of this type.
    static func lifted(from image: HostStorage) -> Value {
        Value(carried: Renderer.shared.board(of: image).read(image, lanes: Value.lanes))
            ?? nothing
    }

    /// The value written into the lanes, whole.
    static func lay(_ value: Value, on image: HostStorage) {
        Renderer.shared.board(of: image).write(StateImage.bytes(of: value.carried), to: image)
    }

    /// What a value answers where its bytes stand for none of this type -
    /// every lane at nought, or empty text.
    ///
    /// Nothing on this side can bring it about, the setter writing the type's
    /// own bytes; a HOST that wrote the wrong lane count could, and a picture
    /// frozen for a frame is the right answer to that where a trap would take
    /// the application down.
    private static var nothing: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0))))
            ?? Value(carried: .text(""))!
    }
}

extension State {
    /// Names this state, and every other one the model holds, by the property
    /// each is declared as - once per model, on the first touch of any of
    /// them. A stored property's label is the wrapper's storage, underscore
    /// and all, and `readable` takes that off. A superclass's properties are
    /// one mirror up.
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

        // Reflection listed every stored property, so this one is named by
        // now; the word `debugInfo()` falls back on is here for the case it
        // cannot be, so the mirror is never taken again.
        storage.name(once: "state")
    }
}

/// A `@State` of ANY value, seen by the naming reflection of the model that
/// holds it, which meets the boxes as `Any` and cannot name a generic type.
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
    /// Tells the storage what the author calls it, so a render explained in
    /// names has one for this state. The path is the reflection walk's - the
    /// property's own name, wrapper underscore and all - and the reading is
    /// tidied where it is shown.
    func named(_ path: String) {
        storage.origin = BuildScope.readable(path)
    }

    /// Takes over the other box's storage, so the two are one piece of state
    /// from here on.
    ///
    /// Called by the differ when a rebuilt view lands where the same KIND of
    /// view stood last render: the new box - freshly made, holding the initial
    /// value - adopts the storage the old one holds, which is how `@State` on a
    /// view survives the view being a value rebuilt every time. Sharing the
    /// storage rather than copying the value is deliberate: a handler suspended
    /// across a render still writes through LAST render's box, and a copy would
    /// quietly lose that write.
    func adopt(from other: AnyObject) {
        guard let other = other as? State<Value>, other !== self else { return }

        storage = other.storage
    }
}

/// How often a READING is taken - the cadence of
/// `.samples($fade, into: $shown, .every(100))`.
///
/// A STATE ITSELF HAS NO CADENCE: a write asks its readers at once, whoever
/// made it, because a state is at its value the moment it is written. What
/// this paces is a reading of where a walked value has GOT TO, copied into an
/// ordinary state that is then read under the ordinary rules - see
/// Core/Sampling.swift. Two views may read one value at two rates, each
/// reading being its own.
public enum Asks: Equatable, Sendable {
    /// A reading on every frame the host writes.
    case always

    /// A reading at most once every so many milliseconds: the first frame in
    /// a window at once, the last in it when the window ends, the ones between
    /// not at all. **THE WINDOW IS NOT A DELAY THE READER WAITS OUT** - a
    /// render somebody else asks for shows the value on time; what can be
    /// late is this one reading, by at most that long. Nought or less is
    /// `.always`.
    case every(Int)

    /// How long a reading may be held back, in milliseconds - nought for
    /// `.always`, which holds nothing back at all.
    var window: Int {
        switch self {
        case .always: return 0
        case .every(let milliseconds): return max(0, milliseconds)
        }
    }

    /// The shorter of two cadences.
    ///
    /// - Parameters:
    ///   - one: a cadence.
    ///   - other: another.
    /// - Returns: whichever holds a render back for less time.
    static func min(_ one: Asks, _ other: Asks) -> Asks {
        one.window <= other.window ? one : other
    }
}

extension State where Value: Walked {
    /// State declared with its journey's LAW - how this value travels wherever
    /// it is shown, and who walks it.
    ///
    ///     @State(motion: .spring()) private var lift = 1.0    // a spring, on every element that shows it
    ///     @State(motion: .none) private var box = Rect.zero    // lands at once, wherever it is written
    ///     @State(motion: .custom) private var ball = 0.0       // an engine of your own walks it
    ///
    /// The value's own law is the first the crossing asks - ahead of the
    /// element's `.motion(_:)`, the application's and the library's - and it
    /// is on the image from the first frame. Leaving it out means
    /// `.inherited`, the element's. It can be changed later through
    /// `$x.journey.motion`, except `.custom`, which says WHO walks the value
    /// and is settled here: the host is told at the first crossing and cannot
    /// be told again.
    ///
    /// **THE LABEL IS THE ARGUMENT'S OWN TYPE, LOWERCASED**, as `persistentKey:`
    /// is: there is ONE kind of state, and the brackets say only what ELSE is
    /// true of one - where it is kept, and how it travels.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds, and where the journey starts.
    ///   - motion: the law the value travels under.
    public convenience init(wrappedValue: @autoclosure @escaping () -> Value, motion: Motion) {
        self.init(making: wrappedValue)

        storage.law = motion
    }
}

extension State where Value: PersistentValue {
    /// State the application KEEPS - the same state, under a name, still there
    /// on the next launch.
    ///
    ///     @State(persistentKey: .lastGroup) private var group = 0
    ///
    /// The value written here is what the state holds when the store has
    /// nothing under that name - the first launch, or a value the reader never
    /// changed - so the default lives where it can be seen. Reading and
    /// writing are exactly what they are on any other `@State`: nothing is
    /// awaited, the value is in memory before the first view is built, and a
    /// write reaches the store by itself. See Core/Persistence.swift for how,
    /// and for why the application also lists its keys.
    ///
    /// **One key is one piece of state.** Two views declaring the same key
    /// share the storage, so a write in either rebuilds the readers in both.
    ///
    /// **THE LABEL IS THE ARGUMENT'S OWN TYPE, LOWERCASED** - the rule `motion:`
    /// follows too, and both are labelled for one reason: there is ONE kind
    /// of state, and the brackets say only what ELSE is true of one. A key is
    /// not a kind: a kept state IS an ordinary one, with somewhere to be
    /// written down as well. And the UNLABELLED position on this wrapper
    /// already means the initial value (`State(0)`), so an unlabelled key would
    /// read as a state holding `.lastGroup`.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds when the store has nothing.
    ///   - persistentKey: the name it is kept under, and the kind of value it
    ///     is. Declared on `PersistentKey`, and listed by the application.
    public convenience init(
        wrappedValue: @autoclosure @escaping () -> Value,
        persistentKey key: PersistentKey
    ) {
        self.init(making: wrappedValue)

        // The one thing an author can get wrong here, said at once rather
        // than by quietly never being saved: the key was declared with a
        // different type from the state written beside it.
        precondition(
            Value.persistentKind == key.kind,
            "'\(key.name)' was declared to keep a \(key.kind) and is written "
                + "on a \(Value.self), which is a \(Value.persistentKind)")

        // One claim, one hold: the key's standing storage when another state
        // got here first - this state is then that same state - or this one,
        // adopted. The landing is how the stored value arrives whether the
        // host's read is already here or still to come: an application's own
        // keyed state is built as the app registers, BEFORE the store is
        // pushed, and the landing then runs at `hydrate`, still ahead of the
        // first view.
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
}

/// A piece of state a view BORROWS from whoever owns it.
///
///     struct CounterPage: ContentPage {
///         @State private var counter = 0
///
///         var content: Element {
///             VStack {
///                 Button("Count: \(counter)").onClicked { counter += 1 }
///                 ResetRow(counter: $counter)
///             }
///         }
///     }
///
///     struct ResetRow: ContentView {
///         @Binding var counter: Int
///
///         var content: Element {
///             Button("Reset").onClicked { counter = 0 }
///         }
///     }
///
/// What it holds is a way to read the owner's value and a way to write it, so a
/// write through it reaches the owner - and the differ knows not to treat the
/// storage as the borrower's own when it carries state across a rebuild.
///
/// **`$` says: I LEND YOU THIS, DO WITH IT WHAT YOU WANT.** A borrower may write
/// the whole value, or one property of it - `$basket.note` - and a model lent
/// this way may be edited or replaced outright. That is the point rather than an
/// oversight: what a parent hands over is a capability, and the way to hand over
/// less is to hand over less. Give the child the value itself and it can only
/// read; give it the object and it can edit what the object holds; give it `$`
/// and it can do everything the owner can.
///
/// **This is what a MODEL is lent with too.** A class of `@State` properties is
/// a value like any other as far as this is concerned: `@Binding var basket:
/// Basket` borrows it, `basket.$note` is the note's own state and `$basket.note`
/// a binding to it through the model, and `$app.basket.note` reaches through a
/// model inside a model. There is no second wrapper for the class case, because
/// there is no second case.
///
/// The names come from the problem: a value type that describes a view cannot
/// hold the view's state by itself, and the split into owning and borrowing is
/// what says whose value each piece is.
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
    // A pair of closures rather than the `State` box itself: the box covers the
    // case an author writes most - `$counter` - and covers nothing else: a
    // property of a model, a value behind a function, one that has to be
    // checked on the way in. Reading and writing is all a binding ever asks of
    // what it borrows from, so that is what it holds.
    private let read: () -> Value
    private let write: (Value) -> Void

    // Who this borrows FROM, when there is anybody: the storage behind a
    // `@State`, and which of its properties when the binding is one of them.
    // Reading and writing still go through the two closures above and only
    // through them - this says nothing about the value and cannot reach it.
    //
    // It is here for one reason: `$counter` builds a NEW binding every time it
    // is written, so two spellings naming one piece of state are two values
    // with no way to recognize each other. This is that way, and ONE road reads
    // it: `described`, which answers the storage behind a whole `@State` and
    // nothing for a part of one or a binding made from closures - and is what
    // `asks`, `standing`, `followed` and the host's image all hang off.
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

    /// A binding over a storage no box holds - the derived side of a
    /// conversion. A read works the value out from the sources afresh and
    /// records a read of each of them, so the body is their reader; a write
    /// lands on the derived state as a control's report does, for the back
    /// engine to carry to the source.
    init(over storage: State<Value>.Storage) {
        // HELD HERE, because the storage knows it weakly: this binding is what
        // carries the conversion from the line that wrote it to the element
        // that ends up holding it.
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

    /// The one the property subscripts use: the
    /// same closures they would have written, plus who the value came from.
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

    /// A binding to something this library does not own: read it with `get`,
    /// write it with `set`.
    ///
    ///     Entry(Binding(get: { settings.name }, set: { settings.name = $0 }))
    ///
    /// The escape hatch, for a value that is not a `@State` - in a view or in
    /// a model, both of which have a shorter spelling, `$x` and `model.$x`.
    /// Whether a write asks for another render is then the setter's business:
    /// writing a `@State` does, and writing anything else does not.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        read = get
        write = set
        lender = nil
        lent = nil
    }

    /// The value this borrows. Writing goes straight to the owner, and marks
    /// the tree dirty as any other write does.
    public var wrappedValue: Value {
        get { read() }

        // Nonmutating: what changes is what the owner holds, not which binding
        // this is. That is what lets a view write to its state from a handler,
        // without being a mutating method it cannot be.
        nonmutating set { write(newValue) }
    }

    /// So a borrowed value can be lent on again, unchanged.
    public var projectedValue: Binding<Value> { self }

    /// A binding to one property of what this borrows - `$profile.name`.
    ///
    ///     @State private var profile = Profile()
    ///     …
    ///     Entry($profile.name)
    ///
    /// A key path, so a name that is not a property does not compile - this is
    /// dynamic in the spelling only.
    ///
    /// This one is for a VALUE, which cannot be written to in place from here:
    /// the whole is read, the property written, and the whole put back through
    /// this binding. A model takes the other subscript below.
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

    /// A binding to one property of a MODEL, through the model - `$basket.note`.
    ///
    ///     struct NoteRow: ContentView {
    ///         @Binding var basket: Basket
    ///
    ///         var content: Element {
    ///             Entry($basket.note)
    ///         }
    ///     }
    ///
    ///     NoteRow(basket: $basket)
    ///
    /// A `ReferenceWritableKeyPath`, which only a class has, so the write goes
    /// straight to the object both sides are already holding and nothing is put
    /// back. Swift prefers this to the one above wherever both would fit -
    /// measured - which is what keeps a model's own binding from being written
    /// to on every keystroke, and any setter behind it from firing for a change
    /// it did not make.
    ///
    /// It reaches the property THROUGH the state holding the model, so it is a
    /// part of that state and none of its own - read where a control shows it,
    /// as `$room.width` is. The property's own state is the model's `$`:
    /// `basket.$note`, which is what a control the host carries the value for
    /// is handed.
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
    /// A binding to ONE ELEMENT of what this borrows - `$hops[2]`.
    ///
    ///     @State private var hops = [0.0, 0.0, 0.0, 0.0]
    ///     …
    ///     ForEach(Array(hops.enumerated()), id: \.offset) { hop in
    ///         BoxView().translationY($hops[hop.offset])
    ///     }
    ///
    /// The whole is read, the element written, and the whole put back through
    /// this binding - the value subscript's shape, one step along. Each element
    /// is its OWN binding as far as anything that keys on one is concerned, so
    /// four bars are four pieces of state and not one.
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
    /// Writes a REPORT - a value the platform measured, or the reader moved -
    /// so that it lands where it is rather than travelling there.
    ///
    /// On a state the host walks as a journey the value, its destination and
    /// a speed of nought land together; on any other state it is an ordinary
    /// write. Either way the state's readers are asked for a render, as they
    /// are for every write, and a state nobody reads costs nothing. What is
    /// NOT done is a save: a measurement is not a setting, so a kept state
    /// (`persistentKey:`) landed here is not written to the store.
    ///
    /// INTERNAL: what the library's own write-backs use - `.width($w)`,
    /// `.height($h)` - where an author reaches for `.motion(.none)` on the
    /// view or, on a journey, `$x.snap(to:)`.
    ///
    /// - Parameter value: what landed.
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

/// `@unchecked Sendable` for the reason `State` is, and load-bearing for what a
/// handler does: one that writes state from an `async let` runs the child on the
/// cooperative pool, and the binding has to reach it.
///
/// The two closures are the whole of what crosses, and what they touch is a
/// `State` box - itself `@unchecked Sendable`, kept so by the lock its
/// storage holds, so a write through a binding is as safe from any thread as
/// a write to the box. A binding made with `Binding(get:set:)` over
/// something an author owns is as safe as that something, which is the same
/// promise `State<SomeClass>` makes.
extension Binding: @unchecked Sendable {}
