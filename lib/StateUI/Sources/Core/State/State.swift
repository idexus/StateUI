// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `@State`, the one declaration of mutable state. A write asks the views that
// read it for a render, from any thread.
// Design: docs/design/core/state.md#storage-and-box

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
    /// Where the value lives, across every render.
    private(set) var storage: Storage

    /// What a write does besides holding the value - marking a kept state's key for
    /// saving; a closure, because only a `PersistentValue` can make it.
    private var save: ((Value) -> Void)?

    /// What pairs this state with the scene it is built in - a `SceneKey` state only
    /// (Core/Scenes/SceneRecord.swift).
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

    /// State holding `value`, whatever it is - what Core/State/Observable.swift's
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

extension State where Value: StateValue {
    /// The image the host carries this state on, whichever shape - what a test
    /// reaches for where an application writes `$x`.
    var image: HostStorage { storage.image ?? storage.carry()! }

    /// The number the host quotes this state by; asking has the host carry it.
    var number: Int32 { Renderer.shared.number(for: image) }
}
