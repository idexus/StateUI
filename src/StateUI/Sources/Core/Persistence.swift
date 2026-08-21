// State that outlives the process.
//
// `@State(.key) var group = 0` is an ordinary piece of state with one addition:
// it is KEPT. The value the reader left behind is there on the next launch, and
// nothing about reading or writing it changes - no load to await, no save to
// remember.
//
// WHY THE KEYS ARE DECLARED UP FRONT. Reading a `@State` is synchronous, so the
// value has to be in memory before the first view is built; asking the host at
// read time would answer a render too late, and the reader would see the
// default flash past. The host therefore hydrates the whole store BEFORE the
// first render - and to read a store it has to know what to ask for, because
// MAUI's `Preferences` can be read key by key and never enumerated. So the
// application names its keys, in one list, and the three steps that follow all
// happen inside the same startup window:
//
//   1. the host asks Swift for the keys      (stateui_persistent_keys)
//   2. it reads exactly those from the store
//   3. it pushes what it found back          (stateui_set_persistent)
//
// A key the store has no value for is simply absent from the push, and the
// state keeps the value written beside it - which is what makes the default
// live at the declaration, where it can be seen.
//
// WRITING is the other direction and needs nothing awaited: the value lands in
// memory at once, so the read after the write is right, and the key is marked
// for saving. What actually goes out is one act per key per drain, sorted by
// name - see `Renderer.takeCommandsWire` - so a key written five times inside
// one handler is saved once. It is a collapse PER DRAIN and not a delay: an
// event drains, so an `Entry` bound to kept state does reach the store once a
// letter. A view that wants the store touched when the typing stops keeps the
// text in ordinary state and writes the kept one from `.onEvent(.completed)`.
//
// ONE KEY IS ONE PIECE OF STATE, everywhere in the application. Two views that
// declare the same key share the storage itself, not a copy of the value, so a
// write in one rebuilds the readers in the other - the ordinary invalidation,
// which already keys on storage identity. It is the one place in this library
// where two unrelated views share state without `$` being written, and it is
// what a key IS: a name for a value the whole application means.

// Dispatch and not Foundation, for the lock below - the Renderer's reason: it
// exists on every platform this targets, and Foundation on Windows links ICU.
import Dispatch

/// What kind of value a persistent key holds.
///
/// The host needs this before any state exists, because a store is typed: MAUI
/// reads a `Preferences` entry with the overload matching what was written, and
/// asking for the wrong one is an error rather than a conversion. It comes from
/// the Swift type named at the key's declaration - `of: Int.self` - so there is
/// no second vocabulary to keep in step.
///
/// THE NUMBERS ARE THIS LIBRARY'S OWN, the wire's rule: declaration order from
/// 0, mirrored by `SwiftPersistentKind` on the far side and checked member for
/// member by `WireEnumTests`.
public enum PersistentKind: Int32, Sendable {
    /// True or false. .NET: `bool`.
    case boolean = 0

    /// A whole number. .NET: `long` - and exact to 2^53, every number on this
    /// wire being a Double.
    case integer = 1

    /// A number with a fraction. .NET: `double`.
    case number = 2

    /// Text. .NET: `string`.
    case text = 3
}

/// A value a `@State` can be KEPT as.
///
/// Conformed to by `Bool`, `Int`, `Double` and `String` - what a platform's own
/// settings store holds, which is deliberately the whole list: kept state lives
/// where the rest of the application's settings live, so it can only be what
/// that store can hold.
///
/// An enum over one of those four is one line, the raw value carrying it:
///
///     enum Appearance: String, PersistentValue { case light, dark, system }
///
/// Anything larger belongs in a model the application saves itself. A struct
/// squeezed through this as text would be a format nobody versioned.
public protocol PersistentValue {
    /// Which of the four this is - what the host reads the store with.
    static var persistentKind: PersistentKind { get }

    /// The value, as the wire carries it.
    var persistentValue: PropValue { get }

    /// The value back from the wire, or nil when the store held something
    /// else - an entry written by an older version of the application under
    /// the same name. The state then keeps its declared value.
    /// - Parameter persisted: what the host read out of the store.
    init?(persisted: PropValue)
}

extension Bool: PersistentValue {
    /// True or false.
    public static var persistentKind: PersistentKind { .boolean }

    /// The value, as the wire carries it.
    public var persistentValue: PropValue { .bool(self) }

    /// The value back from the wire, or nil for anything that is not a
    /// boolean.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .bool(let value) = persisted else { return nil }

        self = value
    }
}

extension Int: PersistentValue {
    /// A whole number.
    public static var persistentKind: PersistentKind { .integer }

    /// The value, as the wire carries it - a Double, as everything numeric
    /// here does.
    public var persistentValue: PropValue { .number(Double(self)) }

    /// The value back from the wire, or nil for anything that is not a number.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .number(let value) = persisted else { return nil }

        self = Int(value)
    }
}

extension Double: PersistentValue {
    /// A number with a fraction.
    public static var persistentKind: PersistentKind { .number }

    /// The value, as the wire carries it.
    public var persistentValue: PropValue { .number(self) }

    /// The value back from the wire, or nil for anything that is not a number.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .number(let value) = persisted else { return nil }

        self = value
    }
}

extension String: PersistentValue {
    /// Text.
    public static var persistentKind: PersistentKind { .text }

    /// The value, as the wire carries it.
    public var persistentValue: PropValue { .string(self) }

    /// The value back from the wire, or nil for anything that is not text.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .string(let value) = persisted else { return nil }

        self = value
    }
}

extension PersistentValue where Self: RawRepresentable, Self.RawValue: PersistentValue {
    /// Whatever the raw value is - an enum is kept as the thing it is spelled
    /// with.
    public static var persistentKind: PersistentKind { RawValue.persistentKind }

    /// The raw value, as the wire carries it.
    public var persistentValue: PropValue { rawValue.persistentValue }

    /// The case the stored raw value names, or nil when it names none - a case
    /// removed since the value was written, which is the ordinary way an
    /// application's vocabulary changes between releases.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard let raw = RawValue(persisted: persisted) else { return nil }

        self.init(rawValue: raw)
    }
}

/// The name a piece of state is KEPT under, and what kind of value it is.
///
///     extension PersistentKey {
///         static let lastGroup = PersistentKey("com.example.lastGroup", of: Int.self)
///         static let appearance = PersistentKey("com.example.appearance", of: Appearance.self)
///     }
///
/// Declared the way every vocabulary in this library is - static members on an
/// extension - and used in two places: the application lists them in
/// `persistentKeys`, and a view writes one on the state it keeps.
///
///     @State(.lastGroup) private var group = 0
///
/// **The name is the application's and belongs to the whole platform**, not to
/// this library: it sits beside whatever else the app keeps in the platform's
/// settings, so a reverse-DNS prefix is what stops it from meeting another
/// application's `theme`.
///
/// The kind comes from the Swift type rather than a vocabulary of its own, so
/// `of: Int.self` and `var group = 0` are the same word twice and a mismatch
/// between them is caught the first time the view is built.
public struct PersistentKey: Hashable, Sendable, CustomStringConvertible {
    /// The name in the store - what the host reads and writes under.
    public let name: String

    /// What kind of value it holds, taken from the type it was declared with.
    public let kind: PersistentKind

    /// A key from its name and the type of the value it keeps.
    ///
    ///     static let lastGroup = PersistentKey("com.example.lastGroup", of: Int.self)
    ///
    /// - Parameters:
    ///   - name: the name in the platform's store, the application's own.
    ///   - type: the type of the state kept under it.
    public init<Value: PersistentValue>(_ name: String, of type: Value.Type) {
        self.name = name
        self.kind = Value.persistentKind
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

/// WHERE kept state is kept. MAUI: Preferences, for the one this library ships.
///
/// An application says nothing and gets `.preferences`, which is MAUI's own
/// store on every platform - `NSUserDefaults`, `SharedPreferences`,
/// `ApplicationDataContainer`. Naming any other store names one the host
/// registered under that name with `StateUIStores.Add`, which is how an
/// application keeps its state somewhere of its own without this side knowing
/// what a file is:
///
///     var persistentStorage: PersistentStorage { PersistentStorage("Gallery.Json") }
public struct PersistentStorage: Hashable, Sendable, CustomStringConvertible {
    /// The store's name - what the host resolves it by.
    public let name: String

    /// A store by name - one the application registered on the host side.
    /// - Parameter name: the name it was registered under.
    public init(_ name: String) {
        self.name = name
    }

    /// The platform's own settings store, and the answer an application that
    /// says nothing gets. MAUI: Preferences.
    public static let preferences = PersistentStorage("preferences")

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

/// Where kept state lives on this side: what the host hydrated, which storage
/// stands for each key, and which keys are waiting to be saved.
///
/// `@unchecked Sendable` over its own lock, the Renderer's arrangement: a write
/// can come from a child task a handler started, exactly as a queued act can.
final class PersistentStore: @unchecked Sendable {
    /// The one store. There is a single host per process, and the keys name
    /// values that whole process shares.
    static let shared = PersistentStore()

    private let guarded = DispatchQueue(label: "StateUI.PersistentStore")

    /// What the host read out of the store before the first render, by key
    /// name. Read once per key, as the first state declaring it is built.
    private var hydrated: [String: PropValue] = [:]

    /// The storage standing for each key - a `State.Storage`, held as the
    /// opaque object this file is allowed to know about. The FIRST state
    /// declaring a key puts its own here, and every later one takes it, which
    /// is what makes one key one piece of state.
    private var storages: [String: AnyObject] = [:]

    /// The keys written since the last drain, with the value to save. A key
    /// written five times is here once, holding the last value - which is what
    /// keeps a slider or an entry from saving on every report.
    private var waiting: [String: PropValue] = [:]

    /// Takes what the host read out of the store. Called once, before the
    /// first render, so a state built later finds its value already here.
    /// - Parameter values: name and value, for the keys the store had.
    func hydrate(_ values: [(name: String, value: PropValue)]) {
        guarded.sync {
            for pair in values {
                hydrated[pair.name] = pair.value
            }
        }
    }

    /// What the host read for a key, if anything.
    func hydrated(_ key: PersistentKey) -> PropValue? {
        guarded.sync { hydrated[key.name] }
    }

    /// The storage already standing for a key, or nil when this is the first
    /// state to declare it.
    func storage(for key: PersistentKey) -> AnyObject? {
        guarded.sync { storages[key.name] }
    }

    /// Makes a storage the one this key means, for every state that declares
    /// it from here on.
    func adopt(_ storage: AnyObject, for key: PersistentKey) {
        guarded.sync { storages[key.name] = storage }
    }

    /// Marks a key as needing a save, replacing whatever value was waiting.
    func record(_ key: PersistentKey, _ value: PropValue) {
        guarded.sync { waiting[key.name] = value }
    }

    /// The keys waiting to be saved, SORTED BY NAME, and forgets them - the
    /// determinism rule, so two runs of one session write the same bytes.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        guarded.sync {
            let taken = waiting.sorted { $0.key < $1.key }
            waiting.removeAll(keepingCapacity: true)
            return taken.map { (name: $0.key, value: $0.value) }
        }
    }

    /// Forgets everything - for tests, which build many sessions in one
    /// process and must not inherit the last one's keys.
    func forgetAll() {
        guarded.sync {
            hydrated.removeAll()
            storages.removeAll()
            waiting.removeAll()
        }
    }
}
