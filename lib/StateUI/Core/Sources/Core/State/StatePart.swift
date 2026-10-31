// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `StatePart`: one property or element of a state, read and written through the
// whole.
// Design: docs/design/core/state.md#parts-of-a-state

/// One property or element of a state - `$profile.name`, `$hops[2]` - read and
/// written through the whole.
///
///     let name: StatePart<String> = $profile.name
///     name.wrappedValue = "Ada"
///
/// Nothing in the library takes one: a control, a driven modifier and an
/// engine take a whole state's `Binding`, which the host carries. A control
/// is handed one field as a state of its own - `profile.$name`, where a class
/// declares `@State var name` - or the value itself, with the user's change
/// written in its event:
///
///     CheckBox(todo.done).onToggled { done in todos[row].done = done }
///
/// A part rebuilds what reads its state, and a post to it waits under the
/// part it reaches.
@dynamicMemberLookup
@MainActor
public struct StatePart<Value> {
    private let read: () -> Value
    private let write: (Value) -> Void
    private let stand: () -> Value
    private let reach: () -> Bool

    // Who this borrows from - the storage and which part of it: a view's
    // inputs compare by it (`lends`), and a post waits under its part.
    // Design: docs/design/core/state.md#parts-of-a-state
    let lender: AnyObject?
    nonisolated let lent: PartPath?

    /// Where a post to this waits for its job - the borrowed state's, or its own.
    /// Design: docs/design/core/state.md#posting
    nonisolated let mailroom: Mailroom

    /// The one every road to a part is written over, with who the value came from.
    init(
        read: @escaping () -> Value,
        write: @escaping (Value) -> Void,
        standing: @escaping () -> Value,
        reaches: @escaping () -> Bool,
        lender: AnyObject?,
        lent: PartPath?,
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

    /// The value read and written through what this reaches.
    public var wrappedValue: Value {
        get { read() }

        // Nonmutating: what changes is what the owner holds.
        nonmutating set {
            guard reach() else {
                return complain("A write through a part of a state to an element its collection no longer has - "
                    + "the list shrank under it - was dropped. Hand the element's identity rather than its index.")
            }

            write(newValue)
        }
    }

    /// One property of what this reaches - `$row.title`: for a value, the
    /// whole is read, the property written, and the whole put back.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject> & Sendable
    ) -> StatePart<Subject> {
        let stand = stand
        return StatePart<Subject>(
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
    ) -> StatePart<Subject> {
        let stand = stand
        return StatePart<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { wrappedValue[keyPath: keyPath] = $0 },
            standing: { stand()[keyPath: keyPath] },
            reaches: reach,
            lender: lender,
            lent: .step(keyPath, from: lent),
            mailroom: mailroom)
    }
}

extension StatePart where Value: MutableCollection, Value.Index: Hashable & Sendable {
    /// One element of what this reaches - `$rows[2]`: the whole is read, the
    /// element written, and the whole put back.
    ///
    /// - Parameter index: which element, in the collection's own index space.
    public subscript(index: Value.Index) -> StatePart<Value.Element> {
        let stand = stand
        return StatePart<Value.Element>(
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

extension StatePart {
    /// The value as it stands, without recording a read - what the machinery of a
    /// write reads.
    /// Design: docs/design/core/state.md#reading-without-recording
    var standing: Value { stand() }

    /// Whether what this reaches still stands - false for an element a list no longer has.
    func reaches() -> Bool { reach() }
}

extension StatePart: PostTarget {}

extension StatePart: BorrowedState {
    var lends: (lender: AnyObject?, lent: AnyHashable?) { (lender, lent.map { AnyHashable($0) }) }
}
