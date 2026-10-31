// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// State that outlives the process: `@State(persistentKey:)`, its keys, and the
// store that reads and saves them.
// Design: docs/design/core/state.md#kept-state

/// What kind of value a persistent key holds - what the host reads the store
/// with, a store being typed. Taken from the Swift type named at the key.
public enum PersistentKind: Int32, Sendable {
    /// True or false.
    case boolean = 0

    /// A whole number - exact to 2^53, every number a host is handed being a
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

    /// The value, as a host is handed it.
    var persistentValue: PropValue { get }

    /// The value back from the host, or nil when the store held something
    /// else - an entry written by an older version of the application under
    /// the same name. The state then keeps its declared value.
    /// - Parameter persisted: what the host read out of the store.
    init?(persisted: PropValue)
}

extension Bool: PersistentValue {
    /// True or false.
    public static var persistentKind: PersistentKind { .boolean }

    /// The value, as a host is handed it.
    public var persistentValue: PropValue { .bool(self) }

    /// The value back from the host, or nil for anything that is not a
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

    /// The value, as a host is handed it - a Double, as everything numeric
    /// here does.
    public var persistentValue: PropValue { .number(Double(self)) }

    /// The value back from the host, or nil for anything that is not a number an `Int` holds.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .number(let value) = persisted, let whole = Int(nearest: value) else { return nil }

        self = whole
    }
}

extension Double: PersistentValue {
    /// A number with a fraction.
    public static var persistentKind: PersistentKind { .number }

    /// The value, as a host is handed it.
    public var persistentValue: PropValue { .number(self) }

    /// The value back from the host, or nil for anything that is not a number.
    /// - Parameter persisted: what the host read out of the store.
    public init?(persisted: PropValue) {
        guard case .number(let value) = persisted else { return nil }

        self = value
    }
}

extension String: PersistentValue {
    /// Text.
    public static var persistentKind: PersistentKind { .text }

    /// The value, as a host is handed it.
    public var persistentValue: PropValue { .string(self) }

    /// The value back from the host, or nil for anything that is not text.
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

    /// The raw value, as a host is handed it.
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

/// The name a piece of state is kept under, typed by the value it keeps.
///
///     extension PersistentKey where Value == Int {
///         static let lastGroup = PersistentKey("com.example.lastGroup")
///     }
///
///     @State(persistentKey: .lastGroup) private var group = 0
///
/// The name sits in the platform's settings beside whatever else the app keeps
/// there, so a reverse-DNS prefix keeps it apart. A state of another type than
/// the key's does not compile.
public struct PersistentKey<Value: PersistentValue>: Hashable, Sendable, CustomStringConvertible {
    /// The name in the store - what the host reads and writes under.
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    let key: KeyName

    /// A key from its name in the platform's store, the application's own.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

/// Where kept state lives on this side: the host's reader of its store, the storage for each key, and the keys
/// waiting to be saved.
@MainActor
final class PersistentStore {
    /// The one store: a process has one host.
    static let shared = PersistentStore()

    /// What reads a key out of the platform's store as the host gave it - a key's name and kind to its value, nil
    /// where the store holds none; nil before the host gave one.
    private var reader: (@MainActor (String, PersistentKind) -> PropValue?)?

    /// The storage standing for each key, the type it keeps, and the typed write that lands a read value in it - the
    /// first state to claim a key puts its own here.
    private var storages: [KeyName: (storage: AnyObject, type: ObjectIdentifier, kind: PersistentKind,
                                     land: @MainActor (PropValue) -> Void)] = [:]

    /// The keys written since the last take, each with its last value.
    private var waiting: [KeyName: PropValue] = [:]

    /// The host's reader of its store came: each key claimed before it takes what the store holds now.
    /// Design: docs/design/core/state.md#kept-state
    func reads(_ reader: @escaping @MainActor (String, PersistentKind) -> PropValue?) {
        self.reader = reader
        for (key, standing) in storages.sorted(by: { $0.key < $1.key }) {
            if let held = reader(key.name, standing.kind) { standing.land(held) }
        }
    }

    /// The storage this key means: the one standing, or the offered one adopted, with what the store holds read
    /// into it now - or once the host's reader comes.
    /// Design: docs/design/core/state.md#kept-state
    func claim<Value>(
        _ key: PersistentKey<Value>,
        orAdopt storage: AnyObject,
        landing land: @escaping @MainActor (PropValue) -> Void
    ) -> AnyObject {
        if let standing = storages[key.key] {
            // Two keys of one name and two types would write each other's value.
            precondition(
                standing.type == ObjectIdentifier(Value.self),
                "'\(key.name)' is declared as a key of two types: one name, one value")
            return standing.storage
        }

        storages[key.key] = (storage, ObjectIdentifier(Value.self), Value.persistentKind, land)

        if let held = reader?(key.name, Value.persistentKind) {
            land(held)
        }

        return storage
    }

    /// Marks a key for saving with its value; the write wakes the host.
    func record<Value>(_ key: PersistentKey<Value>, _ value: PropValue) {
        waiting[key.key] = value
    }

    /// How many keys are waiting - work the host takes whether or not a render was
    /// asked for.
    var pending: Int { waiting.count }

    /// The keys waiting, sorted by name, taken.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        let taken = waiting.sorted { $0.key < $1.key }
        waiting.removeAll(keepingCapacity: true)
        return taken.map { (name: $0.key.name, value: $0.value) }
    }

    /// Forgets everything, for tests building many sessions in one process.
    func forgetAll() {
        reader = nil
        storages.removeAll()
        waiting.removeAll()
    }
}
