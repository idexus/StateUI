// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A HOST'S REALIZATION, CONTRACT BY CONTRACT.
//
// A host registers each element contract it realizes: how the element's view
// is made, which of its properties the view takes and which of its own events
// the view raises. The registration IS the record of what the host realizes -
// the core answers "does this host realize X" from it, and the host makes and
// updates its views through it. Generic over the platform's view type, so
// every Swift host takes the same machinery; a host across the Wire tells the
// core the same thing through the export.

// Dispatch and not Foundation, for the lock - the Renderer's own reasoning.
import Dispatch

/// How one element's own events leave the host: handed to its view where the
/// view is made, so the view raises a member of its contract and never names a
/// handler - bound to the element, as a C# control's raise is.
///
///     registry.add(TrafficLightContract.self, create: { raise in
///         let light = TrafficLightView()
///         light.onLampTapped = { index in raise(TrafficLightContract.lampTapped, index) }
///         return light
///     })
@_spi(Host) public struct Raise<Realized: ElementContract> {
    /// Hands an event and its encoded values on - to the element's handler.
    private let send: (Event, [HostValue]) -> Void

    /// A raise that hands each event, its values encoded, to `send`, which
    /// finds the element's handler for it.
    ///
    /// - Parameter send: given the event's key and what it carries.
    public init(_ send: @escaping (Event, [HostValue]) -> Void) {
        self.send = send
    }

    /// Raises one of the element's own events with the values its contract
    /// declares.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public func callAsFunction<each Value: HostRepresentable>(
        _ event: ElementEvent<Realized, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        send(event.token, MemberValues.encode(repeat each value))
    }
}

/// A host's realization of one element contract, member by member: the
/// properties its view takes and the events of its own the view raises.
@_spi(Host) public final class Registration<Realized: ElementContract, View: AnyObject> {
    /// How each registered property reaches the view, by its key.
    fileprivate var appliers: [Prop: (View, HostValue?) -> Void] = [:]

    /// Every member registered.
    fileprivate var members: Set<HostRealizedMember> = []

    /// Made by `Registry.add` alone.
    fileprivate init() {}

    /// A property the view takes, handed over as the type its contract
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
        _ apply: @escaping (View, Value?) -> Void
    ) {
        guard Realized.worn.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(Owner.self) }) else {
            complain("\(Realized.name) was registered with `\(Owner.name).\(member.name)`, and "
                + "\(Realized.name) wears no \(Owner.name): the property was not registered.")
            return
        }

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

    /// An event of its own the view raises through its `Raise` - recorded, so
    /// the core knows the host reports it.
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Payload>(_ event: ElementEvent<Realized, Payload>) {
        members.insert(HostRealizedMember(element: Realized.name, owner: Realized.name, member: event.name))
    }
}

/// Every registration a host made: how it makes and updates the view of each
/// element it realizes, and what it realizes, contract by contract.
@_spi(Host) public final class Registry<View: AnyObject> {
    /// One registered contract.
    private struct Entry {
        /// Makes the element's view, its events handed to the function given.
        let make: (@escaping (Event, [HostValue]) -> Void) -> View

        /// How each registered property reaches the view.
        let appliers: [Prop: (View, HostValue?) -> Void]

        /// Every member registered.
        let members: Set<HostRealizedMember>
    }

    /// The registrations, by node type.
    private var entries: [NodeType: Entry] = [:]

    /// An empty registry.
    public init() {}

    /// Registers the realization of one element contract: how its view is
    /// made and - in `members` - which of its members the view takes and
    /// raises. A second registration of a contract replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the view, once per element, handed the raise its
    ///     events leave through.
    ///   - members: registers the members the view realizes.
    public func add<Realized: ElementContract>(
        _ contract: Realized.Type,
        create: @escaping (Raise<Realized>) -> View,
        members: (Registration<Realized, View>) -> Void = { _ in }
    ) {
        let registration = Registration<Realized, View>()

        members(registration)
        entries[Realized.nodeType] = Entry(
            make: { send in create(Raise(send)) },
            appliers: registration.appliers,
            members: registration.members)
    }

    /// A view for a node type, made by its registration, its events handed to
    /// `send` - nil where nothing registered the type.
    ///
    /// - Parameters:
    ///   - type: the node type.
    ///   - send: given each event the view raises, and what it carries.
    /// - Returns: the view, or nil.
    public func makeView(for type: NodeType, sending send: @escaping (Event, [HostValue]) -> Void) -> View? {
        entries[type]?.make(send)
    }

    /// Puts the changed properties a registration takes on its view, in name
    /// order - nil where a property is no longer described - and answers which
    /// it put; the rest are the caller's.
    ///
    /// - Parameters:
    ///   - changes: the changed properties and their values.
    ///   - view: the element's view.
    ///   - type: the element's node type.
    /// - Returns: the properties a registration took.
    @discardableResult
    public func apply(_ changes: [Prop: HostValue?], to view: View, of type: NodeType) -> Set<Prop> {
        guard let entry = entries[type] else { return [] }

        var applied: Set<Prop> = []

        for (prop, value) in changes.sorted(by: { $0.key.name < $1.key.name }) {
            guard let apply = entry.appliers[prop] else { continue }

            apply(view, value)
            applied.insert(prop)
        }

        return applied
    }

    /// What these registrations realize: every element they make a view for,
    /// and every member they take or raise.
    public var realization: HostRealization {
        HostRealization(
            elements: Set(entries.keys.map(\.name)),
            members: entries.values.reduce(into: []) { $0.formUnion($1.members) })
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

/// What the host told the core it realizes - nothing until it says.
enum HostRealizations {
    /// The realization, behind the lock: the host says it once at start-up,
    /// and an application may ask from any thread.
    nonisolated(unsafe) private static var told = HostRealization()

    /// The lock, the Renderer's pattern.
    private static let guarded = DispatchQueue(label: "StateUI.HostRealizations")

    /// What the host said, replacing what it said before.
    static var current: HostRealization {
        get { guarded.sync { told } }
        set { guarded.sync { told = newValue } }
    }
}
