// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `Binding`: a whole state borrowed from whoever owns it. A write through it
// reaches the owner and asks the owner's readers for a render.
// Design: docs/design/core/state.md#bindings

/// A state a view borrows whole from whoever owns it.
///
///     struct ResetRow: View {
///         @Binding var counter: Int
///
///         var body: some View {
///             Button("Reset").onClicked { counter = 0 }
///         }
///     }
///
///     ResetRow(counter: $counter)
///
/// A write through it reaches the owner. It is the state itself: the host
/// carries it, so a control shows it with no view rebuilt, and it has a
/// journey. A model lent this way may be edited or replaced; to hand over
/// less, hand over the value or the object instead. One property or element
/// of it - `$profile.name`, `$hops[2]` - is a `Binding.Proxy`, which reads
/// and writes through the whole. A class of `@State` properties is lent the
/// same way: `@Binding var basket: Basket`, with `basket.$note` the note's own
/// state.
@propertyWrapper
@dynamicMemberLookup
@MainActor
public struct Binding<Value>: TwoWay {
    // Two closures: reading and writing is all a binding asks of what it borrows.
    private let read: () -> Value
    private let write: (Value) -> Void

    /// The borrowed state's storage - how two spellings of one state recognize
    /// each other, and what the host's image, the journey and an engine hang off.
    /// Design: docs/design/core/state.md#bindings
    let storage: State<Value>.Storage

    /// Where a post to this waits for its job - the borrowed state's, shared by every
    /// binding to it.
    /// Design: docs/design/core/state.md#posting
    nonisolated let mailroom: Mailroom

    /// A binding to state somebody else owns. `$counter` is the ordinary way to
    /// get one.
    public init(_ state: State<Value>) {
        read = { state.get() }
        write = { state.wrappedValue = $0 }
        storage = state.storage
        mailroom = state.storage.mailroom
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
            guard storage.admitsWrite() else { return }

            storage.write($0)
            storage.askForRender()
        }
        self.storage = storage
        mailroom = storage.mailroom
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
    /// name its parameter `$level`, and read the value as `level`.
    ///
    /// - Parameter projectedValue: the binding.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// The whole state lent as a proxy - what a child borrowing with
    /// `@Binding.Proxy` is handed where its parent lends all of a state:
    ///
    ///     NameRow(name: $name.proxy)
    ///
    /// The proxy reads and writes the state; the host does not carry it.
    public var proxy: Proxy {
        Proxy(read: read, write: write, standing: { [storage] in storage.value }, reaches: { true },
              lender: storage, lent: nil, mailroom: mailroom)
    }

    /// One property of the state - `$profile.name` - read and written through
    /// the whole.
    ///
    ///     TextField($profile.name)
    ///
    /// For a value: the whole is read, the property written, and the whole put back.
    /// A model takes the subscript below.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject> & Sendable
    ) -> Binding<Subject>.Proxy {
        proxy[dynamicMember: keyPath]
    }

    /// One property of a model, through the model - `$basket.note`.
    ///
    ///     TextField($basket.note)
    ///
    /// The write goes straight to the object, and nothing is put back. The
    /// property's own state is `basket.$note`, a `Binding` the host carries.
    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject> & Sendable
    ) -> Binding<Subject>.Proxy {
        proxy[dynamicMember: keyPath]
    }
}

extension Binding where Value: MutableCollection, Value.Index: Hashable & Sendable {
    /// One element of the state - `$hops[2]` - read and written through the
    /// whole.
    ///
    ///     ForEach(Array(hops.enumerated()), id: \.offset) { hop in
    ///         Stepper($hops[hop.offset])
    ///     }
    ///
    /// The whole is read, the element written, and the whole put back.
    ///
    /// - Parameter index: which element, in the collection's own index space.
    public subscript(index: Value.Index) -> Binding<Value.Element>.Proxy {
        proxy[index]
    }
}

extension Binding {
    /// The value as it stands, without recording a read - what the machinery of a
    /// write reads.
    /// Design: docs/design/core/state.md#reading-without-recording
    var standing: Value { storage.value }

    /// The storage an engine follows - the borrowed state's own.
    var followed: any FollowedState { storage }

    /// A whole state always stands.
    func reaches() -> Bool { true }

    /// A post through it writes the whole.
    nonisolated var lent: StatePart? { nil }
}

extension Binding where Value: StateValue {
    /// The image the host carries the borrowed state on, made the first time anything
    /// asks and kept for good - what every driven modifier and feed takes from
    /// `$state`. Nothing where the host carries it as a journey.
    var image: HostStorage? { storage.carry() }
}

extension Binding where Value: StateValue {
    /// The number the host quotes the borrowed state by, or nothing.
    var number: Int32? { image.map { Renderer.shared.number(for: $0) } }
}

extension Binding where Value: Walked {
    /// The image the host animates this state on as a journey - what a driven
    /// property takes from `$x`.
    var journeyImage: HostStorage? { storage.carryAsJourney() }

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
        storage.snap(value)
        storage.askForRender()
    }
}

extension Binding: PostTarget {}

extension Binding: BorrowedState {
    var lends: (lender: AnyObject?, lent: AnyHashable?) { (storage, nil) }
}
