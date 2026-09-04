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
    /// It appears in no signature - `lender` erases it to `AnyObject` - so
    /// nothing outside this file can name it either way.
    final class Storage: @unchecked Sendable, NamedState {
        private let guarded = DispatchQueue(label: "StateUI.State")

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

        /// The earliest moment this state may ask for a render again, where it
        /// asks on a cadence. Nothing until it has asked once.
        ///
        /// ON THE STORAGE and not on the box, because the box is remade on
        /// every render and adopts this one: a window kept on the box would
        /// start over every time the view was described.
        private var next: ContinuousClock.Instant?

        /// Whether an ask is already waiting for that moment.
        private var waiting = false

        /// What a write to a state on a cadence should do about the render it
        /// wants.
        enum Ask: Equatable {
            /// Ask now. The window starts again from this moment.
            case now

            /// Ask when this moment comes - nobody is waiting for it yet.
            case waitUntil(ContinuousClock.Instant)

            /// Ask for nothing: a wait is already standing and will cover this
            /// write too.
            case waiting
        }

        /// What this write should do, and the bookkeeping for it, under one
        /// hold.
        ///
        /// - Parameters:
        ///   - milliseconds: the shortest time between two asks.
        ///   - now: the moment the write happened. Stated so a test can hold
        ///     the clock still rather than sleep.
        /// - Returns: what the write should do.
        func asks(atMostEvery milliseconds: Int, at now: ContinuousClock.Instant = .now) -> Ask {
            guarded.sync {
                if waiting { return .waiting }

                guard let next, now < next else {
                    self.next = now + .milliseconds(milliseconds)
                    return .now
                }

                waiting = true
                return .waitUntil(next)
            }
        }

        /// Records that the ask that was waiting has been made, and starts the
        /// next window from here.
        ///
        /// - Parameters:
        ///   - milliseconds: the shortest time between two asks.
        ///   - now: the moment it was made.
        func asked(atMostEvery milliseconds: Int, at now: ContinuousClock.Instant = .now) {
            guarded.sync {
                waiting = false
                next = now + .milliseconds(milliseconds)
            }
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
            get { guarded.sync { settled() } }
            set { guarded.sync { held = newValue; make = nil } }
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
            guarded.sync {
                held = newValue
                make = nil
                then?(newValue)
            }
        }

        /// Reads, changes, writes and records under ONE hold - so two tasks
        /// counting at once both count, and the store hears them in the order
        /// they landed.
        func update(_ transform: (Value) -> Value, then: ((Value) -> Void)?) {
            guarded.sync {
                let settled = transform(settled())

                held = settled
                make = nil
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

    /// The shortest time between two renders this state asks for, where the
    /// declaration stated one - `@State(every: 100)`. Nothing is every write.
    private(set) var cadence: Int?

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
            Renderer.shared.stateRead(storage)
            return storage.value
        }
        set {
            storage.write(newValue, then: save)
            askForRender()
        }
    }

    /// Asks for the render this write wants - at once, or on the cadence the
    /// declaration stated.
    ///
    /// A CADENCE IS NOT A DELAY THE READER WAITS OUT. What it holds back is
    /// this state's own ask; a render somebody else asks for in the meantime
    /// happens on time and reads this value as it now stands, since the value
    /// itself was written before this line. And the last write inside a window
    /// still gets a render of its own when the window ends, which is what the
    /// waiting arm is for - without it, a value that stopped moving would be
    /// left showing whatever the previous window ended on.
    private func askForRender() {
        guard let window = cadence else {
            Renderer.shared.stateChanged(storage)
            return
        }

        switch storage.asks(atMostEvery: window) {
        case .now:
            Renderer.shared.stateChanged(storage)

        case .waiting:
            // One wait at a time: every write inside this window is already
            // covered by the ask that is standing.
            break

        case .waitUntil(let deadline):
            let storage = storage

            // `Task.sleep` and not a Foundation timer, for the reason
            // Core/Ticker.swift gives: nothing turns a RunLoop here.
            Task {
                try? await Task.sleep(until: deadline)

                storage.asked(atMostEvery: window)
                Renderer.shared.stateChanged(storage)
            }
        }
    }

    /// What `$counter` gives: this state, for something else to borrow.
    ///
    /// Hand it to a child that has to write the value (`@Binding`), to an
    /// input that shows it and writes it back (`Entry($name)`), or to a flight
    /// that walks it (`$fade.animateTo(…)`).
    public var projectedValue: Binding<Value> { Binding(self) }

    /// The object that IS this piece of state.
    ///
    /// The STORAGE rather than the box, deliberately: a box is remade on
    /// every render and adopts the elder one's storage, so this is the one
    /// thing that means "this state" across rebuilds - which is what a flight
    /// needs to still be aiming at the right property three renders later.
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
        Renderer.shared.stateRead(storage)
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

extension State {
    /// State the tree hears about at most once every `milliseconds`.
    ///
    ///     @State(every: 100) private var room = 0.0
    ///
    /// An ordinary described state in every way - read it in a view and that
    /// view is rebuilt when it moves - except for how often it ASKS. For a
    /// value that decides which views there ARE, rather than what one of them
    /// shows, and that still arrives faster than a reader can see: a
    /// measurement a page settles over is the case it is for, where eight
    /// passes a few milliseconds apart are eight renders and a reader can see
    /// no more of those than of two.
    ///
    /// A value merely SHOWN wants `@Bus` and a driven text instead,
    /// which costs no render at all.
    ///
    /// **THE WINDOW IS NOT A DELAY THE READER WAITS OUT.** The value is
    /// written where it is read at once; a render somebody else asks for
    /// happens on time and shows it; and the last write inside a window still
    /// gets one of its own when the window ends. What can be late is this one
    /// value on screen, by at most that long.
    ///
    /// - Parameters:
    ///   - wrappedValue: what the state holds before anything writes it.
    ///   - milliseconds: the shortest time between two renders this state asks
    ///     for. Nought or less is every write, which is a plain `@State`.
    public convenience init(
        wrappedValue: @autoclosure @escaping () -> Value,
        every milliseconds: Int
    ) {
        self.init(making: wrappedValue)

        cadence = milliseconds > 0 ? milliseconds : nil
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
    /// **THE LABEL IS THE ARGUMENT'S OWN TYPE, LOWERCASED** - the rule `every:`
    /// follows too, and both are labelled for one reason: WHAT KIND of state
    /// this is, the wrapper's own name says - `@State`, `@Bus`,
    /// `@Phase` - and the brackets say only what ELSE is true of one. A
    /// key is not a kind: a kept state IS a described one, with somewhere to be
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
/// **This is what a MODEL is lent with too.** A `@StateClass` class is a value
/// like any other as far as this is concerned: `@Binding var basket: Basket`
/// borrows it, `$basket.note` is a binding to one of its properties, and
/// `$app.basket.note` reaches through a model inside a model. There is no second
/// wrapper for the class case, because there is no second case.
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
    // It is here for one reason. `$fade` builds a NEW binding every time it
    // is written, so the one that ARMED a property with `.opacity($fade)` and
    // the one a handler flies with `$fade.animateTo(…)` are two different
    // values with no way to recognize each other. This is that way. A binding
    // made from closures has no lender, which is exactly the binding a flight
    // refuses - see `Core/Flight.swift`.
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

    /// The one the property subscripts and `Bus.projectedValue` use: the same
    /// closures they would have written, plus who the value came from.
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
    /// The escape hatch, for a value that is neither a `@State` nor a property
    /// of a `@StateClass` model - both of which have a shorter spelling. Whether
    /// a write asks for another render is then the setter's business: writing a
    /// `@State` or a tracked property does, and writing anything else does not.
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

    /// A binding to one property of a MODEL - `$basket.note`.
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
    /// four bars can be flown four different ways at once.
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

extension Binding: BorrowedState {}

/// `@unchecked Sendable` for the reason `State` is, and load-bearing for
/// flights: a handler that starts one with `async let` runs the child on the
/// cooperative pool, and the binding has to reach it.
///
/// The two closures are the whole of what crosses, and what they touch is a
/// `State` box - itself `@unchecked Sendable`, kept so by the lock its
/// storage holds, so a write through a binding is as safe from any thread as
/// a write to the box. A binding made with `Binding(get:set:)` over
/// something an author owns is as safe as that something, which is the same
/// promise `State<SomeClass>` makes.
extension Binding: @unchecked Sendable {}
