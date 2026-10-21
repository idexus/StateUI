// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A host's realization of one element contract, member by member: the
/// properties its view takes, one at a time or the element whole, and the
/// events of its own the view raises. `Made` is the view the registration
/// makes, so every applier takes the host's own class for it.
@_spi(Host) public final class Registration<Realized: ElementContract, Made: AnyObject> {
    /// How each property registered alone reaches the view, by its key.
    var appliers: [Prop: (Made, HostValue?) -> Void] = [:]

    /// The appliers taking the element whole, each with the keys it reads.
    var wholes: [(keys: Set<Prop>, apply: (Made, ElementValues<Realized>) -> Void)] = []

    /// Every member registered.
    var members: Set<HostRealizedMember> = []

    /// How the children the view draws itself reach it, each with the node type it is registered for.
    var childAppliers: [(type: NodeType, apply: (Made, [HostChild]) -> Void)] = []

    /// Made by `Registry.add` alone.
    init() {}

    /// A property the view takes alone, handed over as the type its contract
    /// declares - nil where the value is no longer described. A member of the
    /// contract or of a tier it wears; any other is refused, and said once.
    ///
    ///     registration.property(TrafficLightContract.signal) { light, signal in
    ///         light.signal = signal ?? .stop
    ///     }
    ///
    /// A value that crosses as another kind is said once and leaves the view
    /// as it was.
    ///
    /// - Parameters:
    ///   - member: the property, written with its contract.
    ///   - apply: puts the value on the view.
    public func property<Owner: Contract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>,
        _ apply: @escaping (Made, Value?) -> Void
    ) {
        guard Self.wears(Owner.self, for: member.name) else { return }

        appliers[member.token] = { view, value in
            guard let value else { return apply(view, nil) }

            guard let typed = Value(propValue: value) else {
                complain("`\(member.name)` reached \(Realized.name) as "
                    + "\(MemberValues.describe([value])), and its contract declares "
                    + "\(Value.self): the view kept what it had.")
                return
            }

            apply(view, typed)
        }
        members.insert(HostRealizedMember(element: Realized.name, owner: Owner.name, member: member.name))
    }

    /// Applies the element's configuration whole, where its view takes
    /// several properties at once - a caption's attributes read its text, its
    /// font and its color together. Each is a property of the contract or of
    /// a tier it wears - any other is left out, and said once - and the view
    /// is applied once whenever any of them changes.
    ///
    ///     registration.applies(SwitchContract.isOn, VisualElementContract.isEnabled) { toggle, values in
    ///         toggle.apply(toggled: values[SwitchContract.isOn] ?? false,
    ///                      enabled: values[VisualElementContract.isEnabled] ?? true)
    ///     }
    ///
    /// A `PropertyList` hosts share stands among the properties as one.
    ///
    /// - Parameters:
    ///   - properties: the properties it reads, written with their contracts.
    ///   - apply: puts the element's values on the view.
    public func applies<each Applied: AppliedProperties>(
        _ properties: repeat each Applied,
        apply: @escaping (Made, ElementValues<Realized>) -> Void
    ) {
        var keys: Set<Prop> = []

        for applied in repeat each properties {
            for property in applied.applied.properties where Self.wears(property.ownerType, for: property.name) {
                keys.insert(property.key)
                members.insert(
                    HostRealizedMember(element: Realized.name, owner: property.ownerType.name, member: property.name))
            }
        }

        wholes.append((keys: keys, apply: apply))
    }

    /// The children of one contract the view draws itself - a map's markers - handed over whole, in the tree's order,
    /// whenever the element's children change: one being added, moved, taken away, or given another value. A child
    /// registered so has no view of its own. `properties` and `events` are what the view realizes of each child -
    /// members of the child's contract or of a tier it wears; any other is left out, and said once.
    ///
    ///     registration.children(MarkerContract.self, properties: MarkerContract.label, events: MarkerContract.selected) {
    ///         map, markers in
    ///         map.show(markers.map { ($0, $0.value(MarkerContract.label) ?? "") })
    ///     }
    ///
    /// - Parameters:
    ///   - contract: the children's contract.
    ///   - properties: the children's properties the view realizes, written with their contracts.
    ///   - events: the children's events the view raises, written with their contracts.
    ///   - apply: hands the view every child of the contract.
    public func children<
        Child: ElementContract, each PropertyOwner: Contract, each Value: HostRepresentable,
        each EventOwner: Contract, each Payload
    >(
        _ contract: Child.Type,
        properties: repeat ElementProperty<each PropertyOwner, each Value>,
        events: repeat ElementEvent<each EventOwner, each Payload>,
        apply: @escaping (Made, [ChildElement<Child>]) -> Void
    ) {
        for property in repeat each properties {
            realizes(property, of: contract)
        }
        for event in repeat each events {
            realizes(event, of: contract)
        }

        childAppliers.append((type: Child.nodeType, apply: { made, children in apply(made, children.map(ChildElement.init)) }))
    }

    /// A member the view realizes of each child of a contract - one the child wears; any other is said once.
    private func realizes<Child: ElementContract>(_ member: any OwnedMember, of child: Child.Type) {
        guard Child.wears(member.ownerType) else {
            return complain("\(Realized.name)'s children were registered with `\(member.ownerType.name).\(member.name)`, "
                + "and \(Child.name) wears no \(member.ownerType.name): it was left out.")
        }

        members.insert(HostRealizedMember(element: Child.name, owner: member.ownerType.name, member: member.name))
    }

    /// An event the view raises through its `Reports` - its own, or one a tier
    /// it wears declares, as a field's text change is. Recorded, so the core
    /// knows the host reports it; an event of a contract the element does not
    /// wear is refused, and said once.
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        guard Self.wears(Owner.self, for: event.name) else { return }

        members.insert(HostRealizedMember(element: Realized.name, owner: Owner.name, member: event.name))
    }

    /// Whether the element wears the contract a member was declared in - said
    /// once where it does not.
    private static func wears(_ owner: any Contract.Type, for member: String) -> Bool {
        guard Realized.wears(owner) else {
            complain("\(Realized.name) was registered with `\(owner.name).\(member)`, and "
                + "\(Realized.name) wears no \(owner.name): it was not registered.")
            return false
        }

        return true
    }
}

extension ElementContract {
    /// Whether this element wears `contract` - its own, or a tier it carries.
    /// A member of anything else is not this element's to realize, and the
    /// registration and the report both answer that question here.
    static func wears(_ contract: any Contract.Type) -> Bool {
        worn.contains { ObjectIdentifier($0) == ObjectIdentifier(contract) }
    }
}

/// A property or an event as a registration reads it out of a list: the contract declaring it.
protocol OwnedMember: ContractMember {
    /// The contract declaring it.
    var ownerType: any Contract.Type { get }
}

/// A property as a registration reads it out of a list: the contract declaring
/// it, and the key it crosses under.
protocol RegisteredProperty: OwnedMember {
    /// The key it crosses under.
    var key: Prop { get }
}

extension ElementProperty: RegisteredProperty {
    /// The contract declaring it.
    var ownerType: any Contract.Type { Owner.self }

    /// The key it crosses under.
    var key: Prop { token }
}

extension ElementEvent: OwnedMember {
    /// The contract declaring it.
    var ownerType: any Contract.Type { Owner.self }
}
