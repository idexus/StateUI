// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A host's realization, contract by contract: how it makes each element's view,
// which members the view takes, and which events it raises.
// Design: docs/design/core/contracts.md#realizations

/// Every registration a host made: how it makes and updates the view of each
/// element it realizes, and what it realizes, contract by contract.
@_spi(Host) public final class Registry<View: AnyObject> {
    /// One registered contract.
    private struct Entry {
        /// Makes the element's view, its reports handed to the functions given
        /// - nil where the registration made something that is no `View`.
        let make: (@escaping (Event, [HostValue]) -> Void, @escaping (Prop, Event, HostValue) -> Void) -> View?

        /// Puts the changed properties it takes on the view, each read through
        /// the functions given, and answers them.
        let apply: (View, Set<Prop>, @escaping (Prop) -> HostValue?, @escaping (Prop) -> Bool) -> Set<Prop>

        /// Every member registered.
        let members: Set<HostRealizedMember>

        /// The contracts the element wears, itself first.
        let worn: [ObjectIdentifier]

        /// The children the view draws itself, by their node type, in registration order.
        let children: [(type: NodeType, apply: (View, [HostChild]) -> Void)]
    }

    /// The registrations, by node type.
    private var entries: [NodeType: Entry] = [:]

    /// The application's events these registrations raise - an element's own
    /// are its registration's.
    private var applicationEvents: Set<HostRealizedMember> = []

    /// What the host's shared element machinery realizes on every element
    /// wearing the member's contract, rather than one registration.
    private var everyElement: [(owner: any Contract.Type, member: String)] = []

    /// An empty registry.
    public init() {}

    /// Registers the realization of one element contract: how its view is made and -
    /// in `members` - which of its members the view takes and raises. A second
    /// registration of a contract replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the view, once per element, handed the reports its events
    ///     and the user's values leave through.
    ///   - members: registers the members the view realizes.
    public func add<Realized: ElementContract, Made: AnyObject>(
        _ contract: Realized.Type,
        create: @escaping (Reports<Realized>) -> Made,
        members: (Registration<Realized, Made>) -> Void = { _ in }
    ) {
        register(contract, members: members) { send, carry in
            let made = create(Reports(sending: send, reporting: carry))

            guard let view = made as? View else {
                complain("\(Realized.name)'s registration made a \(type(of: made)), which is no "
                    + "\(View.self): no view stands for it.")
                return nil
            }

            return view
        }
    }

    /// Registers the realization of one element contract whose view the host makes:
    /// the registration takes its members and records what it realizes, and the host
    /// goes on making the view itself.
    ///
    /// For an element whose making needs host machinery no contract describes - a
    /// scroll view reports the user's changes as one transaction and asks the host
    /// for display frames, and neither is an event of its contract. `makeView`
    /// answers nothing for such a type; the host's own code stands. Everything else is
    /// a registration like any other.
    ///
    ///     registry.add(TrafficLightContract.self, madeByHost: TrafficLightView.self) { light in
    ///         light.property(TrafficLightContract.signal) { view, signal in
    ///             view.signal = signal ?? .stop
    ///         }
    ///     }
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - view: the class the host makes for it, which every applier takes.
    ///   - members: registers the members this registration realizes.
    public func add<Realized: ElementContract, Made: AnyObject>(
        _ contract: Realized.Type,
        madeByHost view: Made.Type,
        members: (Registration<Realized, Made>) -> Void
    ) {
        register(contract, members: members) { _, _ in nil }
    }

    /// One contract's registration, entered under its node type: `members` says
    /// what it realizes, and `make` makes its view - answering nil, silently,
    /// where the host makes that view instead.
    private func register<Realized: ElementContract, Made: AnyObject>(
        _ contract: Realized.Type,
        members: (Registration<Realized, Made>) -> Void,
        making make: @escaping (
            @escaping (Event, [HostValue]) -> Void, @escaping (Prop, Event, HostValue) -> Void
        ) -> View?
    ) {
        let registration = Registration<Realized, Made>()

        members(registration)

        let appliers = registration.appliers
        let wholes = registration.wholes
        let children = registration.childAppliers.map { child in
            (type: child.type, apply: { (view: View, kept: [HostChild]) in
                guard let made = view as? Made else { return }

                child.apply(made, kept)
            })
        }

        entries[Realized.nodeType] = Entry(
            make: make,
            apply: { view, changed, read, carried in
                guard let made = view as? Made else { return [] }

                var applied: Set<Prop> = []

                for key in changed.sorted(by: { $0.name < $1.name }) {
                    guard let apply = appliers[key] else { continue }

                    apply(made, read(key))
                    applied.insert(key)
                }

                let values = ElementValues<Realized>(changed: changed, reading: read, carriedIn: carried)

                for whole in wholes where !whole.keys.isDisjoint(with: changed) {
                    whole.apply(made, values)
                    applied.formUnion(whole.keys.intersection(changed))
                }

                return applied
            },
            members: registration.members,
            worn: Realized.worn.map { ObjectIdentifier($0) },
            children: children)
    }

    /// A property the host's shared element machinery realizes on every
    /// element wearing its contract - a view's opacity, its margins, its
    /// visibility - rather than one registration.
    ///
    /// - Parameter member: the property, written with its contract.
    public func everyElementRealizes<Owner: Contract, Value>(_ member: ElementProperty<Owner, Value>) {
        everyElement.append((owner: Owner.self, member: member.name))
    }

    /// An event the host's shared element machinery raises on every element
    /// wearing its contract - a tap, a focus change - rather than one
    /// registration.
    ///
    /// - Parameter event: the event, written with its contract.
    public func everyElementRaises<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        everyElement.append((owner: Owner.self, member: event.name))
    }

    /// The names of the members the shared machinery realizes and raises, as they were registered.
    public var sharedNames: [String] {
        everyElement.map(\.member)
    }

    /// An event of the application's - one no element raises - the host
    /// raises through `HostBoundary.raise`: recorded on the
    /// application element, so the core knows the host reports it.
    ///
    ///     registry.raises(GalleryContract.batteryChanged)
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        applicationEvents.insert(
            HostRealizedMember(element: ApplicationContract.name, owner: Owner.name, member: event.name))
    }

    /// A view for a node type, made by its registration, its reports handed to `send`
    /// and `carry` - nil where nothing registered the type.
    ///
    /// - Parameters:
    ///   - type: the node type.
    ///   - send: given each event the view raises, and what it carries.
    ///   - carry: given each value the user changed in the view: the property, the
    ///     event to raise for it, and the value.
    /// - Returns: the view, or nil.
    public func makeView(
        for type: NodeType,
        sending send: @escaping (Event, [HostValue]) -> Void,
        reporting carry: @escaping (Prop, Event, HostValue) -> Void
    ) -> View? {
        entries[type].flatMap { $0.make(send, carry) }
    }

    /// Puts what changed - a patch's properties, or a display frame's moving
    /// ones - on the element's view, as its registration takes it: a property
    /// registered alone in name order, nil where it is no longer described,
    /// then each whole applier whose members changed. Every value is read
    /// through `read`, as the host presents it - a value in motion or carried
    /// by a state included, not only what the tree described. Answers which
    /// properties a registration took; the rest are the caller's.
    ///
    /// - Parameters:
    ///   - changed: the properties that changed.
    ///   - view: the element's view.
    ///   - type: the element's node type.
    ///   - read: the element's current value for a key, as the host presents
    ///     it.
    ///   - carried: whether a key's value is carried in - the host's to write.
    /// - Returns: the properties a registration took.
    @discardableResult
    public func apply(
        _ changed: Set<Prop>,
        to view: View,
        of type: NodeType,
        reading read: @escaping (Prop) -> HostValue?,
        carriedIn carried: @escaping (Prop) -> Bool = { _ in false }
    ) -> Set<Prop> {
        entries[type]?.apply(view, changed, read, carried) ?? []
    }

    /// The node types of the children the view of a `type` draws itself, in registration order - a child of one
    /// has no view of its own.
    ///
    /// - Parameter type: the parent's node type.
    /// - Returns: the children's node types.
    public func childTypes(of type: NodeType) -> [NodeType] {
        entries[type]?.children.map(\.type) ?? []
    }

    /// Hands the view of an element of `type` every child of each contract its registration draws itself, as
    /// `children` answers them for that contract's node type, in the tree's order.
    ///
    /// - Parameters:
    ///   - view: the element's view.
    ///   - type: the element's node type.
    ///   - children: the element's children of a node type, each the one the host keeps for it.
    public func applyChildren(to view: View, of type: NodeType, children: (NodeType) -> [HostChild]) {
        for child in entries[type]?.children ?? [] {
            child.apply(view, children(child.type))
        }
    }

    /// What these registrations realize: every element they make a view for
    /// or draw as another's children, every member they take or raise, and what the shared machinery realizes
    /// on each element that wears the member's contract.
    public var realization: HostRealization {
        var members = applicationEvents

        for (type, entry) in entries {
            members.formUnion(entry.members)

            for shared in everyElement where entry.worn.contains(ObjectIdentifier(shared.owner)) {
                members.insert(HostRealizedMember(element: type.name, owner: shared.owner.name, member: shared.member))
            }
        }

        let drawn = entries.values.flatMap { $0.children.map(\.type.name) }
        return HostRealization(elements: Set(entries.keys.map(\.name) + drawn), members: members)
    }
}
