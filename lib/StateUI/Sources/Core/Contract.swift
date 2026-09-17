// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT AN ELEMENT IS, DECLARED ONCE.
//
// Every node type - a Label, a VStack, a Window, a control an application
// registers with its hosts - has one CONTRACT: an enum naming its node type and
// every member it has, each with the type of its value. Swift writes through
// the members, so a property and its value meet in the compiler, and a host
// realizes the contract member by member.
//
//     enum TrafficLightContract: ElementContract {
//         static let nodeType: NodeType = "Gallery.TrafficLight"
//         static let tiers: [any Contract.Type] = [ViewContract.self]
//
//         static let signal = ElementProperty<Self, TrafficSignal>("signal")
//         static let lampTapped = ElementEvent<Self, Int>("lampTapped")
//         static let flash = ElementAct<Self, Int, Void>("flash")
//
//         static let members: [any ContractMember] = [signal, lampTapped, flash]
//     }
//
// A TIER is a contract with no node type of its own: members many elements
// share, declared once - every text control's font size is one member of one
// tier. An element names the tiers it wears, and a tier may wear tiers, as the
// Swift protocols behind them do.
//
// What happens with no control behind it - an alert, the clock, a battery
// reporting - belongs to the application. `ApplicationTier` is a tier the
// application element wears, and an application declares its own exactly as
// the library declares its.
//
// A MEMBER IS WRITTEN WITH ITS CONTRACT, always - `TrafficLightContract.signal`.
// A member found as a leading-dot member of its own type cannot be paired with
// a single-value payload by the compiler, so nothing here is declared for that
// spelling.

/// A named set of members: the contract of one node type, or a tier - members
/// many elements wear.
///
/// Declared as an enum, which holds the members and is never made:
///
///     public enum FontElementContract: Contract {
///         public static let name = "FontElement"
///         public static let fontSize = ElementProperty<Self, Double>("fontSize", layer: .native)
///         public static let members: [any ContractMember] = [fontSize]
///     }
public protocol Contract: Sendable {
    /// What the contract is called: the node type's name for an element, the
    /// tier's own for a tier.
    static var name: String { get }

    /// The tiers this contract wears. Their members are its members too, and so
    /// are the members of the tiers they wear.
    static var tiers: [any Contract.Type] { get }

    /// The members declared here, in the order a reader is told about them.
    static var members: [any ContractMember] { get }
}

extension Contract {
    /// Nothing worn, unless the contract says.
    public static var tiers: [any Contract.Type] { [] }

    /// This contract and every tier it wears, each once, nearest first - a
    /// tier reached twice, through two of the tiers worn, counted where it was
    /// first met.
    static var worn: [any Contract.Type] {
        var seen: Set<ObjectIdentifier> = []
        var order: [any Contract.Type] = []

        func visit(_ contract: any Contract.Type) {
            guard seen.insert(ObjectIdentifier(contract)).inserted else { return }

            order.append(contract)

            for tier in contract.tiers {
                visit(tier)
            }
        }

        visit(Self.self)
        return order
    }
}

/// The contract of one node type: the element the tree describes, every member
/// it has, and which layer realizes it.
///
///     enum TrafficLightContract: ElementContract {
///         static let nodeType: NodeType = "Gallery.TrafficLight"
///         static let tiers: [any Contract.Type] = [ViewContract.self]
///
///         static let signal = ElementProperty<Self, TrafficSignal>("signal")
///
///         static let members: [any ContractMember] = [signal]
///     }
///
///     struct TrafficLight: View {
///         var node = Node(contract: TrafficLightContract.self)
///
///         func signal(_ value: TrafficSignal) -> Self {
///             setValue(TrafficLightContract.signal, value)
///         }
///     }
///
/// Every element exists through its contract: its view builds its node from
/// it, its modifiers write its members, and a host realizes it member by
/// member.
public protocol ElementContract: Contract {
    /// The node type this contract declares.
    static var nodeType: NodeType { get }

    /// Which layer realizes the element.
    static var layer: ElementLayer { get }
}

extension ElementContract {
    /// The node type's name.
    public static var name: String { nodeType.name }

    /// An application's own element, realized by the application's hosts.
    public static var layer: ElementLayer { .provider }
}

/// A tier the application element wears: acts and events with no control
/// behind them - an alert, the clock, a battery that reports.
///
///     enum NotesContract: ApplicationTier {
///         static let name = "Notes"
///
///         static let readClipboard = ElementAct<Self, Void, String>("Notes.ReadClipboard")
///         static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Notes.BatteryChanged")
///
///         static let members: [any ContractMember] = [readClipboard, batteryChanged]
///     }
///
///     let text = try await stateUICall(NotesContract.readClipboard)
///
/// Its acts are called with `stateUICall` and `stateUISend` and its events
/// heard with `HostEvents.on`: none of them aims at a control. An act of an
/// element's own is called through the element's aim instead, `Aim.call`.
public protocol ApplicationTier: Contract {}

/// Which layer realizes an element or one of its members.
public enum ElementLayer: Sendable {
    /// Every base host presents it with its native toolkit.
    case native

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    case adaptive

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    case stateUI

    /// It carries structure or protocol data rather than configuring a visual
    /// platform object.
    case structure

    /// An optional provider supplies it: a package, or the application that
    /// registers it with its hosts.
    case provider
}

/// One member of a contract - a property, an event or an act - as a list of
/// members holds it.
public protocol ContractMember: Sendable {
    /// The member's name: what crosses the boundary.
    var name: String { get }
}

/// A property of an element: its name, and the type of the value it holds.
///
///     static let signal = ElementProperty<Self, TrafficSignal>("signal")
///
/// `Owner` is the contract it is declared in, written `Self` there. `Value` is
/// what it holds, and what a modifier hands it:
///
///     func signal(_ value: TrafficSignal) -> Self {
///         setValue(TrafficLightContract.signal, value)
///     }
public struct ElementProperty<Owner: Contract, Value: HostRepresentable>: ContractMember {
    /// The property's name: what crosses the boundary.
    public let name: String

    /// Which layer realizes it.
    let layer: ElementLayer

    /// Whether a change travels to the new value - the default. False where
    /// there is no half way, of four kinds:
    ///
    /// - a PLACE or a COUNT: which tab, which item, which row of a grid, how
    ///   many dots, where the caret is - nothing walks a whole number;
    /// - a LAW a scroller obeys - how far apart its stops are, how much of a
    ///   throw it keeps - read as a release is decided, which a law still
    ///   arriving would decide differently every frame;
    /// - a RANGE or a REGION - a slider's ends, where a map looks - answered by
    ///   a method or a redraw, not by a value shown on the way;
    /// - a PLACEMENT: where a child sits in an AbsoluteLayout, which the host
    ///   answers from what it measured; the layout's own motion carries a
    ///   child from one place to the next.
    ///
    /// A host still snaps a transition it cannot interpolate; this keeps the
    /// ones StateUI knows are invalid out of `HostPatch`.
    /// `testAPlaceOrACountNeverTravels` holds that the differ honours every
    /// member that says so, and cannot hold which members say it: set it back
    /// to true only for a property that should travel.
    let travels: Bool

    /// Whether a value no longer described is put back to the control's own
    /// default - the default. False where no default answers for it, and the
    /// element is built again instead: a gesture's settings, which belong to
    /// its recognizer; a list's items, which are data; where the host PUTS an
    /// item - a toolbar item's `order` and `priority`, a swipe's `side`; a
    /// CHOICE, which clearing would move - back to the first tab, the first
    /// item, the top of the list; and a window's kind, its value, whether it
    /// hides and whether it floats, which the host reads to keep the
    /// platform's windows. Every host agrees with the members that say so, or
    /// the difference is found only on a screen.
    let cleared: Bool

    /// Which of a view's values it is, for `.motion(_:_:)`, where the value
    /// alone cannot say: a size, a place, a transform, spacing, text. A colour
    /// says its own group through its value.
    let moves: MotionValues

    /// A property declared in `Owner`.
    ///
    /// - Parameters:
    ///   - name: its name - the name of the static member holding it.
    ///   - layer: which layer realizes it; an application's own unless said.
    ///   - travels: whether a change travels to the new value.
    ///   - cleared: whether a value no longer described is put back to the
    ///     control's default.
    ///   - moves: which of a view's values it is, where the value cannot say.
    public init(
        _ name: String,
        layer: ElementLayer = .provider,
        travels: Bool = true,
        cleared: Bool = true,
        moves: MotionValues = []
    ) {
        self.name = name
        self.layer = layer
        self.travels = travels
        self.cleared = cleared
        self.moves = moves
    }

    /// The key the property crosses the boundary under.
    @_spi(Host) public var token: Prop { Prop(name) }
}

/// An event an element reports: its name, and the types of what it carries.
///
///     static let lampTapped = ElementEvent<Self, Int>("lampTapped")
///     static let batteryChanged = ElementEvent<Self, (Double, Bool)>("batteryChanged")
///     static let closed = ElementEvent<Self, Void>("closed")
///
/// What it carries is positional - nothing, one value or a tuple of them, each
/// `HostRepresentable` - and a handler takes the values as its parameters:
///
///     onEvent(GalleryContract.batteryChanged) { level, charging in … }
public struct ElementEvent<Owner: Contract, Payload>: ContractMember {
    /// The event's name: what crosses the boundary.
    public let name: String

    /// Which layer reports it.
    let layer: ElementLayer

    /// An event declared in `Owner`.
    ///
    /// - Parameters:
    ///   - name: its name - the name of the static member holding it.
    ///   - layer: which layer reports it; an application's own unless said.
    public init(_ name: String, layer: ElementLayer = .provider) {
        self.name = name
        self.layer = layer
    }

    /// The key the event crosses the boundary under.
    @_spi(Host) public var token: Event { Event(name) }
}

/// An act a host performs: its name, and the types of its arguments and its
/// answer.
///
///     static let flash = ElementAct<Self, Int, Void>("flash")
///     static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("batteryLevel")
///
/// Declared in an element's contract, it is performed on one element of that
/// kind: `Aim.call` puts the aimed element first. Declared in an
/// `ApplicationTier`, it aims at nothing: `stateUICall`.
public struct ElementAct<Owner: Contract, Arguments, Answer>: ContractMember {
    /// The act's name: what crosses the boundary.
    public let name: String

    /// An act declared in `Owner`.
    ///
    /// - Parameter name: its name - the name of the static member holding it.
    public init(_ name: String) {
        self.name = name
    }

    /// The key the act crosses the boundary under.
    @_spi(Host) public var token: Act { Act(name) }
}

/// A value a member holds, and how it crosses the boundary and back.
///
/// `Bool`, `Int`, `Double` and `String` are ready, and so is an optional one,
/// whose nil crosses as nothing. An enum over `Int32` is one line, crossing as
/// its member's number:
///
///     enum TrafficSignal: Int32, HostRepresentable { case stop, caution, go }
public protocol HostRepresentable {
    /// The value, as it crosses.
    var propValue: PropValue { get }

    /// The value back from what crossed, or nil where that is another kind.
    /// - Parameter propValue: what the host sent.
    init?(propValue: PropValue)

    /// How a list of these crosses: as a list of values, unless the type has
    /// a leaner form - numbers cross as one run of numbers, text as one list
    /// of text.
    /// - Parameter list: the values, in order.
    static func propValue(of list: [Self]) -> PropValue

    /// A list of these back from what crossed, or nil where it is not one.
    /// - Parameter value: what the host sent.
    static func list(from value: PropValue) -> [Self]?
}

extension HostRepresentable {
    /// A list of values, each in its own form.
    /// - Parameter list: the values, in order.
    public static func propValue(of list: [Self]) -> PropValue {
        .values(list.map(\.propValue))
    }

    /// A list of values, each read back as this type - or nil where one is
    /// another kind.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Self]? {
        guard case .values(let values) = value else { return nil }

        var list: [Self] = []

        for item in values {
            guard let read = Self(propValue: item) else { return nil }
            list.append(read)
        }

        return list
    }
}

extension Array: HostRepresentable where Element: HostRepresentable {
    /// The list, in the form its values' type gives a list.
    public var propValue: PropValue { Element.propValue(of: self) }

    /// The list back, or nil where what crossed is not a list of these.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let list = Element.list(from: propValue) else { return nil }

        self = list
    }
}

extension Bool: HostRepresentable {
    /// True or false.
    public var propValue: PropValue { .bool(self) }

    /// True or false, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .bool(let value) = propValue else { return nil }

        self = value
    }
}

extension Int: HostRepresentable {
    /// A whole number, as every number crosses: a Double.
    public var propValue: PropValue { .number(Double(self)) }

    /// The whole part of a number, or nil for anything else - a number with no
    /// whole part, infinity or not a number, included.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .number(let value) = propValue, value.isFinite,
              let whole = Int(exactly: value.rounded(.towardZero))
        else { return nil }

        self = whole
    }
}

extension Double: HostRepresentable {
    /// The number.
    public var propValue: PropValue { .number(self) }

    /// The number, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .number(let value) = propValue else { return nil }

        self = value
    }

    /// Numbers cross as one run of numbers.
    /// - Parameter list: the numbers, in order.
    public static func propValue(of list: [Double]) -> PropValue { .numbers(list) }

    /// The run of numbers, or nil for anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Double]? { value.numbers }
}

extension String: HostRepresentable {
    /// Text.
    public var propValue: PropValue { .string(self) }

    /// The text, or nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .string(let value) = propValue else { return nil }

        self = value
    }

    /// Texts cross as one list of text.
    /// - Parameter list: the texts, in order.
    public static func propValue(of list: [String]) -> PropValue { .strings(list) }

    /// The list of text, or nil for anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [String]? { value.strings }
}

/// A value that may be left out of the END of a payload: saying nothing is
/// how a host says it has none - a pointer's position the platform does not
/// know.
protocol OmissibleValue {
    /// The value a left-out position stands for.
    static var omitted: Self { get }
}

extension Optional: OmissibleValue {
    /// Nil.
    static var omitted: Self { nil }
}

extension Optional: HostRepresentable where Wrapped: HostRepresentable {
    /// The value, or nothing.
    public var propValue: PropValue { self?.propValue ?? .nothing }

    /// Nil for nothing, the value for its own kind, and no value at all for
    /// any other kind.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        if case .nothing = propValue {
            self = .none
            return
        }

        guard let value = Wrapped(propValue: propValue) else { return nil }

        self = .some(value)
    }
}

extension PropValue: HostRepresentable {
    /// Itself: a member of this type holds any value the boundary carries.
    public var propValue: PropValue { self }

    /// Itself.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        self = propValue
    }
}

extension HostRepresentable where Self: RawRepresentable, RawValue == Int32 {
    /// The member's number: a closed vocabulary crosses as its member.
    public var propValue: PropValue { .enumeration(rawValue) }

    /// The member that number names, or nil for a number it names none of and
    /// for any other kind.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let number) = propValue else { return nil }

        self.init(rawValue: number)
    }
}

/// A member's positional values - what an event carries, what an act is handed
/// and what it answers - encoded and decoded against the types its contract
/// declares.
@_spi(Host) public enum MemberValues {
    /// The values, in order.
    /// - Parameter value: the values, as their Swift types.
    /// - Returns: what crosses.
    public static func encode<each Value: HostRepresentable>(_ value: repeat each Value) -> [PropValue] {
        var values: [PropValue] = []

        for item in repeat each value {
            values.append(item.propValue)
        }

        return values
    }

    /// The values a payload holds, as the declared types, or nil where their
    /// count or one kind differs: what crosses is exactly what the declaration
    /// says, or it is refused whole. The one leniency is at the END: an
    /// optional value there may be left out, and reads as nil.
    /// - Parameters:
    ///   - payload: what crossed.
    ///   - type: the declared types, in order.
    /// - Returns: the values, or nil.
    public static func decode<each Value: HostRepresentable>(
        _ payload: [PropValue],
        as type: repeat (each Value).Type
    ) -> (repeat each Value)? {
        guard payload.count <= count(repeat (each Value).self) else { return nil }

        var index = 0

        do {
            return (repeat try take((each Value).self, from: payload, at: &index))
        } catch {
            return nil
        }
    }

    /// How the declared types read - `()`, `Int`, `(Double, Bool)` - for the
    /// report that says a payload was refused.
    /// - Parameter type: the declared types, in order.
    /// - Returns: the declaration, as text.
    public static func describe<each Value>(_ type: repeat (each Value).Type) -> String {
        var names: [String] = []

        for kind in repeat each type {
            names.append(String(describing: kind))
        }

        return names.count == 1 ? names[0] : "(" + names.joined(separator: ", ") + ")"
    }

    /// How what crossed reads, kind by kind: `(number, bool)`.
    static func describe(_ payload: [PropValue]) -> String {
        "(" + payload.map(\.kindName).joined(separator: ", ") + ")"
    }

    /// What an event carried, as the types its contract declares - or nil,
    /// said once, where it carried anything else: a handler never runs on a
    /// guess.
    static func carried<each Value: HostRepresentable>(
        _ payload: [PropValue],
        by event: String,
        as type: repeat (each Value).Type
    ) -> (repeat each Value)? {
        guard let values = decode(payload, as: repeat (each Value).self) else {
            complain("`\(event)` carried \(describe(payload)), and its contract declares "
                + "\(describe(repeat (each Value).self)): the handler did not run.")
            return nil
        }

        return values
    }

    /// An act's answer as the declared types, or the failure a caller throws.
    static func answer<each Value: HostRepresentable>(
        _ reply: [PropValue],
        of act: String,
        as type: repeat (each Value).Type
    ) throws -> (repeat each Value) {
        guard let values = decode(reply, as: repeat (each Value).self) else {
            throw StateUIError(message: "`\(act)` answered \(describe(reply)), and its contract "
                + "declares \(describe(repeat (each Value).self))")
        }

        return values
    }

    /// How many types a declaration names.
    private static func count<each Value>(_ type: repeat (each Value).Type) -> Int {
        var count = 0

        for _ in repeat each type {
            count += 1
        }

        return count
    }

    /// The next value, as the next declared type - or the refusal. Past the
    /// end of the payload only an optional value is read, as nil.
    private static func take<Value: HostRepresentable>(
        _ type: Value.Type,
        from payload: [PropValue],
        at index: inout Int
    ) throws -> Value {
        defer { index += 1 }

        guard index < payload.count else {
            guard let omitted = (Value.self as? any OmissibleValue.Type)?.omitted as? Value else {
                throw Refused()
            }

            return omitted
        }

        guard let value = Value(propValue: payload[index]) else { throw Refused() }

        return value
    }

    /// A value that is not the declared kind.
    private struct Refused: Error {}
}

/// What a member says about itself - read by the tables the library derives
/// from its contracts and by the guards that hold those contracts.
struct MemberFacts: Equatable {
    /// A property, an event or an act.
    enum Kind: Equatable {
        case property
        case event
        case act
    }

    /// Which of the three it is.
    let kind: Kind

    /// Which layer realizes it; nil for an act.
    let layer: ElementLayer?

    /// Whether a change travels to the new value.
    let travels: Bool

    /// Whether a value no longer described is put back to the default.
    let cleared: Bool

    /// Which of a view's values it is, where the value cannot say.
    let moves: MotionValues

    /// What a property no library contract declares says of itself - an
    /// application's own: it travels, it is cleared, and it says nothing of
    /// motion.
    static let undeclared = MemberFacts(kind: .property, layer: nil, travels: true, cleared: true, moves: [])
}

/// A member whose facts the library can read out of a list of members.
protocol DeclaredMember: ContractMember {
    /// What it says about itself.
    var facts: MemberFacts { get }
}

/// A property, read as the type of the value it holds - for the guard that
/// holds every such type to its own round trip.
protocol PropertyMember: DeclaredMember {
    /// The type of the value the property holds.
    var valueType: any HostRepresentable.Type { get }
}

extension ElementProperty: PropertyMember {
    /// A property's facts.
    var facts: MemberFacts {
        MemberFacts(kind: .property, layer: layer, travels: travels, cleared: cleared, moves: moves)
    }

    /// The type of the value it holds.
    var valueType: any HostRepresentable.Type { Value.self }
}

extension ElementEvent: DeclaredMember {
    /// An event's facts: its layer, and nothing a property's value says.
    var facts: MemberFacts {
        MemberFacts(kind: .event, layer: layer, travels: true, cleared: true, moves: [])
    }
}

extension ElementAct: DeclaredMember {
    /// An act's facts: none a layer or a value says.
    var facts: MemberFacts {
        MemberFacts(kind: .act, layer: nil, travels: true, cleared: true, moves: [])
    }
}

extension [Prop: PropValue] {
    /// Writes one member's value into this map - a node's properties, or what
    /// a session keeps for the node it describes.
    mutating func write<Owner: Contract, Held: HostRepresentable>(
        _ property: ElementProperty<Owner, Held>,
        _ value: Held
    ) {
        self[property.token] = value.propValue
    }

    /// Writes one member's value into this map, or leaves the member
    /// undescribed where there is none - a setting taken as optional, whose
    /// absence the host reads as its own default.
    mutating func describe<Owner: Contract, Held: HostRepresentable>(
        _ property: ElementProperty<Owner, Held>,
        _ value: Held?
    ) {
        self[property.token] = value?.propValue
    }
}

extension Node {
    /// Writes one member's value into this node - what a modifier setting
    /// several members at once writes through, where `setValue` cannot chain.
    mutating func write<Owner: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value
    ) {
        props.write(property, value)
    }

    /// Writes one member's value into this node, or leaves the member
    /// undescribed where there is none - a setting a modifier takes as
    /// optional, whose absence the host reads as its own default.
    mutating func describe<Owner: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value?
    ) {
        props.describe(property, value)
    }
}

extension PropValue {
    /// Which kind of value this is, for a report that names what arrived.
    fileprivate var kindName: String {
        switch self {
        case .string: "string"
        case .enumeration: "enumeration"
        case .nothing: "nothing"
        case .name: "name"
        case .number: "number"
        case .bool: "bool"
        case .numbers: "numbers"
        case .strings: "strings"
        case .color: "color"
        case .values: "values"
        case .themed: "themed"
        }
    }
}
