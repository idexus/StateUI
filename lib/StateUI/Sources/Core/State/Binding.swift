// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `Binding`: a state borrowed from whoever owns it. A write through it reaches
// the owner and asks the owner's readers for a render.
// Design: docs/design/core/state.md#bindings

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

extension Binding where Value: StateValue {
    /// The number the host quotes the borrowed state by, or nothing.
    var number: Int32? { image.map { Renderer.shared.number(for: $0) } }
}

extension Binding where Value: Walked {
    /// The image the host animates this state on as a journey - what a driven
    /// property takes from `$x`.
    var journeyImage: HostStorage? { described?.carryAsJourney() }

    /// The journey the borrowed state is on: where the value is this frame, where it
    /// is going, how fast, under what law - and `move(to:)` to send it and wait.
    public var journey: Journey<Value> { Journey(of: self) }
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
