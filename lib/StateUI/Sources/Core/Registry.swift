// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A HOST'S REALIZATION, CONTRACT BY CONTRACT.
//
// A host registers each element contract it realizes: how the element's view
// is made, which of its members the view takes - one at a time, or the element
// whole where a view takes several at once - and which of its own events the
// view raises. The registration IS the record of what the host realizes: the
// core answers "does this host realize X" from it, and the host makes and
// updates its views through it. Generic over the platform's view type, so
// every Swift host takes the same machinery; a host across the Wire tells the
// core the same thing through the export.

// Dispatch and not Foundation, for the lock - the Renderer's own reasoning.

/// What one element tells the application: an event of its own, and a value
/// its reader changed. Handed to the view where the view is made, so the view
/// names members of its contract and never a handler - bound to the element,
/// as a C# control's raise is.
///
///     registry.add(TrafficLightContract.self, create: { reports in
///         let light = TrafficLightView()
///         light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
///         light.onSignalPicked = { signal in
///             reports.report(TrafficLightContract.signal, signal, as: TrafficLightContract.signalChanged)
///         }
///         return light
///     })
@_spi(Host) public struct Reports<Realized: ElementContract> {
    /// Hands an event and its encoded values on - to the element's handler.
    private let send: (Event, [HostValue]) -> Void

    /// Hands a value the reader changed on - to the state the element's value
    /// is carried in, and to the element's handler for the event.
    private let carry: (Prop, Event, HostValue) -> Void

    /// The reports of one element: `send` finds the element's handler for an
    /// event, `carry` writes a reader's value where the element carries it and
    /// raises the event with it.
    ///
    /// - Parameters:
    ///   - send: given the event's key and what it carries.
    ///   - carry: given the property's key, the event's key, and the value.
    public init(
        sending send: @escaping (Event, [HostValue]) -> Void,
        reporting carry: @escaping (Prop, Event, HostValue) -> Void
    ) {
        self.send = send
        self.carry = carry
    }

    /// Raises one of the element's own events with the values its contract
    /// declares - an event that carries no value of the element's own.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public func raise<each Value: HostRepresentable>(
        _ event: ElementEvent<Realized, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        send(event.token, MemberValues.encode(repeat each value))
    }

    /// A value the reader changed: it lands on the state the element's value is
    /// carried in - the one place a host-carried value lives - and the event is
    /// raised with it, so an application hears the change once whether it holds
    /// the value in a state or in a handler.
    ///
    ///     toggle.onToggled = { on in
    ///         reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
    ///     }
    ///
    /// The two members need not come from one contract: a field's words are
    /// `TextElementContract.text` and the change it reports is
    /// `InputViewContract.textChanged`, and the element wears both. A member of
    /// a contract it does not wear is refused, and said once.
    ///
    /// - Parameters:
    ///   - property: the value's member, written with its contract.
    ///   - value: what the reader made it.
    ///   - event: the member the element raises for that change.
    public func report<Owner: Contract, Raised: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value,
        as event: ElementEvent<Raised, Value>
    ) {
        guard Realized.wears(Owner.self) else {
            return complain("\(Realized.name) reported `\(Owner.name).\(property.name)`, and "
                + "\(Realized.name) wears no \(Owner.name): nothing was reported.")
        }

        guard Realized.wears(Raised.self) else {
            return complain("\(Realized.name) reported `\(property.name)` as "
                + "`\(Raised.name).\(event.name)`, and \(Realized.name) wears no \(Raised.name): "
                + "nothing was reported.")
        }

        carry(property.token, event.token, value.propValue)
    }
}

/// The values an element holds, as its registration reads them: each by its
/// member, as the type its contract declares - what the host presents, a
/// value in motion or carried by a state included - and which of them
/// changed.
@_spi(Host) public struct ElementValues<Realized: ElementContract> {
    /// The element's current value for a key, as the host presents it.
    private let read: (Prop) -> HostValue?

    /// Whether a key's value is carried IN - the host's to write.
    private let carried: (Prop) -> Bool

    /// The properties that changed.
    private let changes: Set<Prop>

    /// The element's values: those that changed, each current value as `read`
    /// answers it, and whose each value is.
    ///
    /// - Parameters:
    ///   - changed: the properties that changed.
    ///   - read: the element's current value for a key, as the host presents
    ///     it - nil where it is not described.
    ///   - carried: whether a key's value is carried in - written by the host
    ///     and only read back by this side. Nothing carried in by default.
    public init(
        changed: Set<Prop>,
        reading read: @escaping (Prop) -> HostValue?,
        carriedIn carried: @escaping (Prop) -> Bool = { _ in false }
    ) {
        self.read = read
        self.carried = carried
        changes = changed
    }

    /// Whether this member's value is the HOST'S to write - a field fed from
    /// the platform, a frame a layout reports. What the tree describes beside
    /// such a value is not put on the control: the control is the source.
    ///
    ///     let words = values.carriedIn(TextElementContract.text)
    ///         ? nil
    ///         : values[TextElementContract.text]
    ///
    /// - Parameter member: the property, written with its contract.
    public func carriedIn<Owner: Contract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>
    ) -> Bool {
        carried(member.token)
    }

    /// A member's current value as the type its contract declares - nil where
    /// it is not described, or crossed as another kind, which is said once.
    ///
    /// - Parameter member: the property, written with its contract.
    public subscript<Owner: Contract, Value: HostRepresentable>(_ member: ElementProperty<Owner, Value>) -> Value? {
        guard let value = read(member.token) else { return nil }

        guard let typed = Value(propValue: value) else {
            complain("`\(member.name)` reached \(Realized.name) as \(MemberValues.describe([value])), "
                + "and its contract declares \(Value.self): the view read no value for it.")
            return nil
        }

        return typed
    }

    /// Whether the patch changed a member - the gate for a value a view must
    /// not write unasked, a field's text under the reader's cursor.
    ///
    /// - Parameter member: the property, written with its contract.
    /// - Returns: whether the patch changed it.
    public func changed<Owner: Contract, Value: HostRepresentable>(_ member: ElementProperty<Owner, Value>) -> Bool {
        changes.contains(member.token)
    }
}

/// A host's realization of one element contract, member by member: the
/// properties its view takes, one at a time or the element whole, and the
/// events of its own the view raises. `Made` is the view the registration
/// makes, so every applier takes the host's own class for it.
@_spi(Host) public final class Registration<Realized: ElementContract, Made: AnyObject> {
    /// How each property registered alone reaches the view, by its key.
    fileprivate var appliers: [Prop: (Made, HostValue?) -> Void] = [:]

    /// The appliers taking the element whole, each with the keys it reads.
    fileprivate var wholes: [(keys: Set<Prop>, apply: (Made, ElementValues<Realized>) -> Void)] = []

    /// Every member registered.
    fileprivate var members: Set<HostRealizedMember> = []

    /// Made by `Registry.add` alone.
    fileprivate init() {}

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
    /// several members at once - a caption's attributes read its text, its
    /// font and its colour together. `members` are what it realizes - each a
    /// property of the contract or of a tier it wears; anything else is left
    /// out, and said once - and it runs once whenever any of them changes.
    ///
    ///     registration.applies([SwitchContract.isOn, VisualElementContract.isEnabled]) { toggle, values in
    ///         toggle.apply(toggled: values[SwitchContract.isOn] ?? false,
    ///                      enabled: values[VisualElementContract.isEnabled] ?? true)
    ///     }
    ///
    /// - Parameters:
    ///   - members: the properties it reads, written with their contracts.
    ///   - apply: puts the element's values on the view.
    public func applies(_ members: [any ContractMember], _ apply: @escaping (Made, ElementValues<Realized>) -> Void) {
        var keys: Set<Prop> = []

        for member in members {
            guard let property = member as? any RegisteredProperty else {
                complain("\(Realized.name) was registered to apply `\(member.name)`, which is no property: "
                    + "it was left out.")
                continue
            }

            guard Self.wears(property.ownerType, for: member.name) else { continue }

            keys.insert(property.key)
            self.members.insert(
                HostRealizedMember(element: Realized.name, owner: property.ownerType.name, member: member.name))
        }

        wholes.append((keys: keys, apply: apply))
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

/// A property as a registration reads it out of a list: the contract declaring
/// it, and the key it crosses under.
protocol RegisteredProperty: ContractMember {
    /// The contract declaring it.
    var ownerType: any Contract.Type { get }

    /// The key it crosses under.
    var key: Prop { get }
}

extension ElementProperty: RegisteredProperty {
    /// The contract declaring it.
    var ownerType: any Contract.Type { Owner.self }

    /// The key it crosses under.
    var key: Prop { token }
}

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

    /// Registers the realization of one element contract: how its view is
    /// made and - in `members` - which of its members the view takes and
    /// raises. A second registration of a contract replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the view, once per element, handed the reports its
    ///     events and its reader's values leave through.
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

    /// Registers the realization of one element contract whose VIEW THE HOST
    /// MAKES: the registration takes its members and records what it realizes,
    /// and the host goes on making the view itself.
    ///
    /// For an element whose making needs host machinery no contract describes -
    /// a scroll view reports through a reader transaction and asks the host for
    /// display frames, and neither is an event of its contract. `makeView`
    /// answers nothing for such a type, and says nothing about it: the host's
    /// own arm stands. Everything else is a registration like any other, and
    /// the realization claims the element and every member registered here.
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
            worn: Realized.worn.map { ObjectIdentifier($0) })
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

    /// An event of the application's - one no element raises - the host
    /// raises through `StateUIHost.raise` or the export: recorded on the
    /// application element, so the core knows the host reports it.
    ///
    ///     registry.raises(GalleryContract.batteryChanged)
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        applicationEvents.insert(
            HostRealizedMember(element: ApplicationContract.name, owner: Owner.name, member: event.name))
    }

    /// A view for a node type, made by its registration, its reports handed to
    /// `send` and `carry` - nil where nothing registered the type.
    ///
    /// - Parameters:
    ///   - type: the node type.
    ///   - send: given each event the view raises, and what it carries.
    ///   - carry: given each value the view's reader changed: the property, the
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

    /// What these registrations realize: every element they make a view for,
    /// every member they take or raise, and what the shared machinery realizes
    /// on each element that wears the member's contract.
    public var realization: HostRealization {
        var members = applicationEvents

        for (type, entry) in entries {
            members.formUnion(entry.members)

            for shared in everyElement where entry.worn.contains(ObjectIdentifier(shared.owner)) {
                members.insert(HostRealizedMember(element: type.name, owner: shared.owner.name, member: shared.member))
            }
        }

        return HostRealization(elements: Set(entries.keys.map(\.name)), members: members)
    }
}

/// One member a host realizes on one element: the element's name, the name of
/// the contract declaring the member - the element's own or a tier it wears -
/// and the member's own name.
@_spi(Host) public struct HostRealizedMember: Hashable, Sendable {
    /// The element realizing it.
    public let element: String

    /// The contract declaring it.
    public let owner: String

    /// Its own name.
    public let member: String

    /// One member on one element.
    ///
    /// - Parameters:
    ///   - element: the element realizing it.
    ///   - owner: the contract declaring it.
    ///   - member: its own name.
    public init(element: String, owner: String, member: String) {
        self.element = element
        self.owner = owner
        self.member = member
    }
}

/// What a host realizes: the elements it makes a view for, and the members it
/// realizes on each.
@_spi(Host) public struct HostRealization: Equatable, Sendable {
    /// The elements, by node type name.
    public var elements: Set<String>

    /// The members, each on its element.
    public var members: Set<HostRealizedMember>

    /// A realization - nothing, unless said.
    ///
    /// - Parameters:
    ///   - elements: the elements, by node type name.
    ///   - members: the members, each on its element.
    public init(elements: Set<String> = [], members: Set<HostRealizedMember> = []) {
        self.elements = elements
        self.members = members
    }
}

/// What a host DECLARES, read off its own runtime: the elements it makes a
/// view for and, on each, the members it takes and the events it raises.
///
/// A declaration says PRESENCE. It does not say who declares a member, because
/// a runtime does not hold the contracts - `borderColor` on a button is the
/// same call whether the button declares it or a tier it wears does.
/// `realization` is where that is answered, against the contracts themselves,
/// so an owner is never written by hand and cannot be written wrong.
@_spi(Host) public struct HostDeclaration: Equatable, Sendable {
    /// What one element's registration takes and raises.
    public struct Element: Equatable, Sendable {
        /// The members its view takes.
        public var members: Set<String>

        /// The events it raises.
        public var events: Set<String>

        /// An element declaring nothing, unless said.
        ///
        /// - Parameters:
        ///   - members: the members its view takes.
        ///   - events: the events it raises.
        public init(members: Set<String> = [], events: Set<String> = []) {
            self.members = members
            self.events = events
        }
    }

    /// Each element, by node type name.
    public var elements: [String: Element]

    /// What the host's SHARED machinery realizes on every element wearing the
    /// contract declaring it - margins, opacity, the gestures, the focus and
    /// frame reports - rather than one registration.
    ///
    /// Said apart because it is realized apart: a host applies these around
    /// every view it makes, so naming them under one element would be false
    /// and naming them under all of them would be a list nobody maintains.
    /// Which tier each belongs to is answered here, against the contracts,
    /// exactly as an element's own members are.
    public var shared: Element

    /// The acts this host performs, whichever element they are aimed at.
    ///
    /// Said whole rather than per element because that is how a host performs
    /// them: an act names the view it is aimed at and the session performs it
    /// against that identity, so nothing about the call says which element it
    /// belongs to. The contracts do - `focus` is declared by a tier every
    /// element wears, `goBack` by one element - so each act reaches whatever
    /// wears the contract declaring it, exactly as a shared member does.
    public var acts: Set<String>

    /// A declaration - nothing, unless said.
    ///
    /// - Parameters:
    ///   - elements: each element, by node type name.
    ///   - shared: what the shared machinery realizes on every wearer.
    ///   - acts: the acts the host performs.
    public init(
        elements: [String: Element] = [:],
        shared: Element = Element(),
        acts: Set<String> = []
    ) {
        self.elements = elements
        self.shared = shared
        self.acts = acts
    }

    /// What this declaration means against the contracts: the same members,
    /// each under the contract DECLARING it - the element's own, or the
    /// nearest tier it wears that declares a member of that name.
    ///
    /// A member no contract declares is left out rather than guessed at: it is
    /// a host and a contract that disagree, and the guard reading this says so
    /// by name. `Contract.worn` answers the element first and its tiers
    /// nearest-first, so a member an element redeclares belongs to the
    /// element.
    public var realization: HostRealization {
        var members: Set<HostRealizedMember> = []
        var elements: Set<String> = []
        let sharedNames = shared.members.union(shared.events).union(acts)

        for (name, declared) in self.elements {
            elements.insert(name)

            guard let contract = LibraryContracts.elements.first(where: { $0.nodeType.name == name })
            else { continue }

            // The element's own, and then everything the shared machinery
            // realizes on it - which is every shared member whose contract
            // this element wears. A host applies those around the view rather
            // than inside the registration, so they reach the element here.
            for member in declared.members.union(declared.events).union(sharedNames) {
                guard let owner = contract.worn.first(where: { owner in
                    owner.members.contains { $0.name == member }
                }) else { continue }

                members.insert(
                    HostRealizedMember(element: name, owner: owner.name, member: member))
            }
        }

        return HostRealization(elements: elements, members: members)
    }

    /// The shared members and the acts, each under the contract DECLARING it -
    /// the tier, or the one element whose contract declares the act.
    ///
    /// Answered from the contracts rather than through the elements, because
    /// that is what these are: a fact about a CONTRACT. A tier worn only by
    /// elements this host declares no registration for - `Layout`, worn by the
    /// layouts - is realized just as truly as one worn by a registered
    /// element, and going through the elements would lose exactly those.
    public var tierMembers: [(owner: String, member: String)] {
        var found: [(owner: String, member: String)] = []

        for member in shared.members.union(shared.events).union(acts).sorted() {
            guard let owner = LibraryContracts.all.first(where: { owner in
                owner.members.contains { $0.name == member }
            }) else { continue }

            found.append((owner: owner.name, member: member))
        }

        return found
    }

    /// What this declaration names that no contract declares: the element, and
    /// the member under it - a host and the contracts disagreeing, which is
    /// always a mistake on one side and never something to render.
    public var undeclared: [(element: String, member: String)] {
        var unknown: [(element: String, member: String)] = []

        // A shared member belongs to a TIER, so it is held to every contract
        // rather than to one element: one no contract declares at all is a
        // host and the contracts disagreeing, said under the empty element.
        // An ACT is held the same way and deliberately NOT listed here: a host
        // performs some of its own - a chooser, a prompt - that no contract
        // declares, and those are the host's business rather than a drift.
        for member in shared.members.union(shared.events).sorted()
        where !LibraryContracts.all.contains(where: { owner in
            owner.members.contains { $0.name == member }
        }) {
            unknown.append((element: "", member: member))
        }

        for (name, declared) in elements.sorted(by: { $0.key < $1.key }) {
            guard let contract = LibraryContracts.elements.first(where: { $0.nodeType.name == name })
            else {
                unknown.append((element: name, member: ""))
                continue
            }

            for member in declared.members.union(declared.events).sorted()
            where !contract.worn.contains(where: { owner in
                owner.members.contains { $0.name == member }
            }) {
                unknown.append((element: name, member: member))
            }
        }

        return unknown
    }
}

/// What the host told the core it realizes - nothing until it says.
enum HostRealizations {
    /// The realization, behind the lock: the host says it once at start-up,
    /// and an application may ask from any thread.
    nonisolated(unsafe) private static var told = HostRealization()

    /// The lock.
    private static let guarded = Lock()

    /// What the host said, replacing what it said before.
    static var current: HostRealization {
        get { guarded.withLock { told } }
        set { guarded.withLock { told = newValue } }
    }

    /// What to say about a node type described for the first time: nothing
    /// where the host realizes it, or has said nothing at all, and otherwise
    /// that it does not - with the realized elements nearest in name, the
    /// misspelling's likeliest meaning. The differ's placeholder never crosses
    /// and is never said.
    static func unrealized(_ type: NodeType) -> String? {
        let realization = current

        guard realization != HostRealization(), type != .composed,
              !realization.elements.contains(type.name)
        else { return nil }

        return "the host realizes no `\(type.name)`" + nearMisses(type.name, among: realization.elements) + "."
    }

    /// What to say about an event of the application's a handler listens for:
    /// nothing where the host raises it, or has said nothing at all, and
    /// otherwise that it does not - with the events it raises nearest in name.
    static func unraised(owner: String, event: String) -> String? {
        let realization = current

        guard realization != HostRealization(),
              !realization.members.contains(where: { $0.owner == owner && $0.member == event })
        else { return nil }

        let raised = Set(realization.members.filter { $0.element == ApplicationContract.name }.map(\.member))

        return "the host raises no `\(event)`" + nearMisses(event, among: raised) + ": the handler will not hear it."
    }

    /// " (nearest: `a`, `b`)" - the names at most a quarter of the name's
    /// length away, two edits at least, closest first, three at most - or
    /// nothing.
    private static func nearMisses(_ name: String, among names: Set<String>) -> String {
        let reach = max(2, name.count / 4)
        let near = names
            .map { (name: $0, edits: edits(from: name, to: $0)) }
            .filter { $0.edits <= reach }
            .sorted { ($0.edits, $0.name) < ($1.edits, $1.name) }
            .prefix(3)
            .map { "`\($0.name)`" }

        return near.isEmpty ? "" : " (nearest: " + near.joined(separator: ", ") + ")"
    }

    /// How many single-character edits turn one name into the other.
    private static func edits(from source: String, to target: String) -> Int {
        let from = Array(source)
        let to = Array(target)

        guard !from.isEmpty else { return to.count }
        guard !to.isEmpty else { return from.count }

        var row = Array(0...to.count)

        for i in 1...from.count {
            var diagonal = row[0]
            row[0] = i

            for j in 1...to.count {
                let above = row[j]
                row[j] = Swift.min(above + 1, row[j - 1] + 1, diagonal + (from[i - 1] == to[j - 1] ? 0 : 1))
                diagonal = above
            }
        }

        return row[to.count]
    }
}
