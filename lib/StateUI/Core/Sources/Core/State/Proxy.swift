// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `Proxy`: a value read and written through something else - a part of a
// state, or two closures.
// Design: docs/design/core/state.md#proxies

/// A value read and written through something else - one property or
/// element of a state, or a pair of closures. A two-way control takes one
/// beside a whole state, and a child borrows one with `@Proxy`.
///
///     struct NameRow: View {
///         @Proxy var name: String
///
///         var body: some View {
///             TextField($name)
///         }
///     }
///
///     NameRow(name: $profile.name)
///     NameRow(name: $name.proxy)
///
/// A child of its own initializer taking `some TwoWay` and making it
/// `Proxy(_:)` takes a whole state with no `.proxy`.
///
/// It promises reading and writing, never a notification: a part of a
/// state rebuilds what reads that state, while closures over a store of
/// another kind rebuild nothing when the store changes. The host carries
/// none, and none has a journey or wakes an engine - those take the whole
/// state, a `Binding`.
@propertyWrapper
@dynamicMemberLookup
@MainActor
public struct Proxy<Value>: TwoWay {
    private let read: () -> Value
    private let write: (Value) -> Void
    private let stand: () -> Value
    private let reach: () -> Bool

    // Who this borrows from - the storage and which part of it: a view's
    // inputs compare by it (`lends`), and a post waits under its part.
    // Design: docs/design/core/state.md#proxies
    let lender: AnyObject?
    nonisolated let lent: StatePart?

    /// Where a post to this waits for its job - the borrowed state's, or its own.
    /// Design: docs/design/core/state.md#posting
    nonisolated let mailroom: Mailroom

    /// The one every road to a proxy is written over, with who the value came from.
    init(
        read: @escaping () -> Value,
        write: @escaping (Value) -> Void,
        standing: @escaping () -> Value,
        reaches: @escaping () -> Bool,
        lender: AnyObject?,
        lent: StatePart?,
        mailroom: Mailroom
    ) {
        self.read = read
        self.write = write
        stand = standing
        reach = reaches
        self.lender = lender
        self.lent = lent
        self.mailroom = mailroom
    }

    /// A value this library does not own: read with `get`, written with
    /// `set`.
    ///
    ///     TextField(Proxy(get: { settings.name }, set: { settings.name = $0 }))
    ///
    /// Whether a write rebuilds anything is the setter's business: writing
    /// a `@State` does, a store of another kind does not.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.init(read: get, write: set, standing: get, reaches: { true }, lender: nil, lent: nil,
                  mailroom: Mailroom())
    }

    /// The value read and written through what this reaches.
    public var wrappedValue: Value {
        get { read() }

        // Nonmutating: what changes is what the owner holds.
        nonmutating set {
            guard reach() else {
                return complain("A write through a binding to an element its collection no longer has - the "
                    + "list shrank under it - was dropped. Hand the element's identity rather than its index.")
            }

            write(newValue)
        }
    }

    /// So a proxy can be lent on again, unchanged.
    public var projectedValue: Proxy { self }

    /// A proxy handed on as it is - which is what lets a closure handed one
    /// name its parameter `$id`, and read the value as `id`:
    ///
    ///     WindowGroup(.document) { $id in DocumentWindow(id: id) }
    ///
    /// - Parameter projectedValue: the proxy.
    public init(projectedValue: Proxy) {
        self = projectedValue
    }

    /// One property of what this reaches - `$row.title`: for a value, the
    /// whole is read, the property written, and the whole put back.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject> & Sendable
    ) -> Proxy<Subject> {
        let stand = stand
        return Proxy<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { newValue in
                var whole = stand()
                whole[keyPath: keyPath] = newValue
                wrappedValue = whole
            },
            standing: { stand()[keyPath: keyPath] },
            reaches: reach,
            lender: lender,
            lent: .step(keyPath, from: lent),
            mailroom: mailroom)
    }

    /// One property of a model, through the model: the write goes straight
    /// to the object, and nothing is put back.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject> & Sendable
    ) -> Proxy<Subject> {
        let stand = stand
        return Proxy<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { wrappedValue[keyPath: keyPath] = $0 },
            standing: { stand()[keyPath: keyPath] },
            reaches: reach,
            lender: lender,
            lent: .step(keyPath, from: lent),
            mailroom: mailroom)
    }
}

extension Proxy where Value: MutableCollection, Value.Index: Hashable & Sendable {
    /// One element of what this reaches - `$rows[2]`: the whole is read, the
    /// element written, and the whole put back.
    ///
    /// - Parameter index: which element, in the collection's own index space.
    public subscript(index: Value.Index) -> Proxy<Value.Element> {
        let stand = stand
        return Proxy<Value.Element>(
            read: { wrappedValue[index] },
            write: { newValue in
                var whole = stand()
                whole[index] = newValue
                wrappedValue = whole
            },
            standing: { stand()[index] },
            reaches: { [reach] in reach() && stand().indices.contains(index) },
            lender: lender,
            lent: .step(index, from: lent),
            mailroom: mailroom)
    }
}

extension Proxy {
    /// The value as it stands, without recording a read - what the machinery of a
    /// write reads.
    /// Design: docs/design/core/state.md#reading-without-recording
    var standing: Value { stand() }

    /// Whether what this reaches still stands - false for an element a list no longer has.
    func reaches() -> Bool { reach() }
}

extension Proxy {
    /// A proxy to whatever reads and writes `value` - a whole state, a part of
    /// one, or another proxy - so a view borrowing with `@Proxy` takes either
    /// through an initializer of its own:
    ///
    ///     init(name: some TwoWay<String>) { _name = Proxy(name) }
    ///
    /// A whole state keeps who it is borrowed from, so the view is carried
    /// while the state is the same; it is described, as every proxy is.
    ///
    /// - Parameter value: what the proxy reads and writes.
    public init(_ value: some TwoWay<Value>) {
        if let whole = value.whole {
            self = whole.proxy
        } else if let proxy = value as? Proxy<Value> {
            self = proxy
        } else {
            self.init(get: { value.wrappedValue }, set: { value.wrappedValue = $0 })
        }
    }
}

extension Proxy: PostTarget {}

extension Proxy: BorrowedState {
    var lends: (lender: AnyObject?, lent: AnyHashable?) { (lender, lent.map { AnyHashable($0) }) }
}
