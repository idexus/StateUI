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

/// The values an element holds, as its registration reads them: each by its
/// member, as the type its contract declares - what the host presents, a
/// value in motion or carried by a state included - and which of them
/// changed.
@_spi(Host) public struct ElementValues<Realized: ElementContract> {
    /// The element's current value for a key, as the host presents it.
    private let read: (Prop) -> HostValue?

    /// The properties that changed.
    private let changes: Set<Prop>

    /// The element's values: those that changed, and each current value as
    /// `read` answers it.
    ///
    /// - Parameters:
    ///   - changed: the properties that changed.
    ///   - read: the element's current value for a key, as the host presents
    ///     it - nil where it is not described.
    public init(changed: Set<Prop>, reading read: @escaping (Prop) -> HostValue?) {
        self.read = read
        changes = changed
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

    /// An event of its own the view raises through its `Raise` - recorded, so
    /// the core knows the host reports it.
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Payload>(_ event: ElementEvent<Realized, Payload>) {
        members.insert(HostRealizedMember(element: Realized.name, owner: Realized.name, member: event.name))
    }

    /// Whether the element wears the contract a member was declared in - said
    /// once where it does not.
    private static func wears(_ owner: any Contract.Type, for member: String) -> Bool {
        guard Realized.worn.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(owner) }) else {
            complain("\(Realized.name) was registered with `\(owner.name).\(member)`, and "
                + "\(Realized.name) wears no \(owner.name): it was not registered.")
            return false
        }

        return true
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
        /// Makes the element's view, its events handed to the function given -
        /// nil where the registration made something that is no `View`.
        let make: (@escaping (Event, [HostValue]) -> Void) -> View?

        /// Puts the changed properties it takes on the view, each read through
        /// the function given, and answers them.
        let apply: (View, Set<Prop>, @escaping (Prop) -> HostValue?) -> Set<Prop>

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
    ///   - create: makes the view, once per element, handed the raise its
    ///     events leave through.
    ///   - members: registers the members the view realizes.
    public func add<Realized: ElementContract, Made: AnyObject>(
        _ contract: Realized.Type,
        create: @escaping (Raise<Realized>) -> Made,
        members: (Registration<Realized, Made>) -> Void = { _ in }
    ) {
        let registration = Registration<Realized, Made>()

        members(registration)

        let appliers = registration.appliers
        let wholes = registration.wholes

        entries[Realized.nodeType] = Entry(
            make: { send in
                let made = create(Raise(send))

                guard let view = made as? View else {
                    complain("\(Realized.name)'s registration made a \(type(of: made)), which is no "
                        + "\(View.self): no view stands for it.")
                    return nil
                }

                return view
            },
            apply: { view, changed, read in
                guard let made = view as? Made else { return [] }

                var applied: Set<Prop> = []

                for key in changed.sorted(by: { $0.name < $1.name }) {
                    guard let apply = appliers[key] else { continue }

                    apply(made, read(key))
                    applied.insert(key)
                }

                let values = ElementValues<Realized>(changed: changed, reading: read)

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

    /// A view for a node type, made by its registration, its events handed to
    /// `send` - nil where nothing registered the type.
    ///
    /// - Parameters:
    ///   - type: the node type.
    ///   - send: given each event the view raises, and what it carries.
    /// - Returns: the view, or nil.
    public func makeView(for type: NodeType, sending send: @escaping (Event, [HostValue]) -> Void) -> View? {
        entries[type].flatMap { $0.make(send) }
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
    /// - Returns: the properties a registration took.
    @discardableResult
    public func apply(
        _ changed: Set<Prop>,
        to view: View,
        of type: NodeType,
        reading read: @escaping (Prop) -> HostValue?
    ) -> Set<Prop> {
        entries[type]?.apply(view, changed, read) ?? []
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
