// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that outlives the process: `@State(persistentKey:)`, its keys, and the
// store that hydrates and saves them.
// Design: docs/design/core/state.md#kept-state

/// What kind of value a persistent key holds - what the host reads the store
/// with, a store being typed. Taken from the Swift type named at the key.
public enum PersistentKind: Int32, Sendable {
    /// True or false.
    case boolean = 0

    /// A whole number - exact to 2^53, every number on this wire being a
    /// Double.
    case integer = 1

    /// A number with a fraction.
    case number = 2

    /// Text.
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

/// The name a piece of state is kept under, and what kind of value it is.
///
///     extension PersistentKey {
///         static let lastGroup = PersistentKey("com.example.lastGroup", of: Int.self)
///     }
///
///     @State(persistentKey: .lastGroup) private var group = 0
///
/// The application lists its keys in `persistentKeys`. The name sits in the
/// platform's settings beside whatever else the app keeps there, so a reverse-DNS
/// prefix keeps it apart. A key declared for another type than the state written
/// with it stops the program the first time the view is built.
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

/// WHERE kept state is kept.
///
/// An application says nothing and gets `.preferences`, the platform's own
/// settings store. Naming any other store names one the host registered under
/// that name, which is how an application keeps its state somewhere of its
/// own without this side knowing what a file is. Written into the
/// application's session as it is made:
///
///     application.persistentStorage = PersistentStorage("Gallery.Json")
public struct PersistentStorage: Hashable, Sendable, CustomStringConvertible {
    /// The store's name - what the host resolves it by.
    public let name: String

    /// A store by name - one the application registered on the host side.
    /// - Parameter name: the name it was registered under.
    public init(_ name: String) {
        self.name = name
    }

    /// The platform's own settings store, and the answer an application that
    /// says nothing gets.
    public static let preferences = PersistentStorage("preferences")

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

/// Where kept state lives on this side: what the host hydrated, the storage for
/// each key, and the keys waiting to be saved. Behind its own lock.
final class PersistentStore: @unchecked Sendable {
    /// The one store: a process has one host.
    static let shared = PersistentStore()

    private let guarded = Lock()

    /// What the host read out of the store before the first render, by key name.
    private var hydrated: [String: PropValue] = [:]

    /// The storage standing for each key, with the typed write that lands a restored
    /// value in it - the first state to claim a key puts its own here.
    private var storages: [String: (storage: AnyObject, land: (PropValue) -> Void)] = [:]

    /// The keys written since the last take, each with its last value.
    private var waiting: [String: PropValue] = [:]

    /// Takes what the host read out of the store, before the first render; a storage
    /// claimed earlier takes its value now.
    func hydrate(_ values: [(name: String, value: PropValue)]) {
        let landings: [((PropValue) -> Void, PropValue)] = guarded.withLock {
            var landings: [((PropValue) -> Void, PropValue)] = []

            for pair in values {
                hydrated[pair.name] = pair.value

                if let standing = storages[pair.name] {
                    landings.append((standing.land, pair.value))
                }
            }

            return landings
        }

        // Outside the hold: the storage's lock always comes first.
        // Design: docs/design/core/state.md#kept-state
        for (land, value) in landings {
            land(value)
        }
    }

    /// The storage this key means, decided under one hold: the one standing, or the
    /// offered one adopted, with a value the host already read landed in it.
    /// Design: docs/design/core/state.md#kept-state
    func claim(
        _ key: PersistentKey,
        orAdopt storage: AnyObject,
        landing land: @escaping (PropValue) -> Void
    ) -> AnyObject {
        let (owner, held): (AnyObject, PropValue?) = guarded.withLock {
            if let standing = storages[key.name] {
                return (standing.storage, nil)
            }

            storages[key.name] = (storage, land)
            return (storage, hydrated[key.name])
        }

        if let held {
            land(held)
        }

        return owner
    }

    /// Marks a key for saving with its value. Runs under the state's lock, so it only
    /// records; the write wakes the host.
    func record(_ key: PersistentKey, _ value: PropValue) {
        guarded.withLock { waiting[key.name] = value }
    }

    /// How many keys are waiting - work the host takes whether or not a render was
    /// asked for.
    var pending: Int { guarded.withLock { waiting.count } }

    /// The keys waiting, sorted by name, taken.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        guarded.withLock {
            let taken = waiting.sorted { $0.key < $1.key }
            waiting.removeAll(keepingCapacity: true)
            return taken.map { (name: $0.key, value: $0.value) }
        }
    }

    /// Forgets everything, for tests building many sessions in one process.
    func forgetAll() {
        guarded.withLock {
            hydrated.removeAll()
            storages.removeAll()
            waiting.removeAll()
        }
    }
}
