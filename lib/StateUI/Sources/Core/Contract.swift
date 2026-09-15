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
//         static let type: NodeType = "Gallery.TrafficLight"
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
public protocol Contract {
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
}

/// The contract of one node type: the element the tree describes, every member
/// it has, and which layer realizes it.
///
///     enum TrafficLightContract: ElementContract {
///         static let type: NodeType = "Gallery.TrafficLight"
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
    static var type: NodeType { get }

    /// Which layer realizes the element.
    static var layer: ElementLayer { get }
}

extension ElementContract {
    /// The node type's name.
    public static var name: String { type.name }

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

    /// Whether a change travels to the new value. False for what has no half
    /// way: a place, a count, a law a scroller obeys, a range, a placement.
    let travels: Bool

    /// Whether a value no longer described is put back to the control's own
    /// default. False where no default answers for it, and the element is
    /// built again instead.
    let cleared: Bool

    /// Which of a view's values it is, for `.motion(_:_:)`, where the value
    /// alone cannot say.
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
    /// says, or it is refused whole.
    /// - Parameters:
    ///   - payload: what crossed.
    ///   - type: the declared types, in order.
    /// - Returns: the values, or nil.
    public static func decode<each Value: HostRepresentable>(
        _ payload: [PropValue],
        as type: repeat (each Value).Type
    ) -> (repeat each Value)? {
        guard payload.count == count(repeat (each Value).self) else { return nil }

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

    /// The next value, as the next declared type - or the refusal.
    private static func take<Value: HostRepresentable>(
        _ type: Value.Type,
        from payload: [PropValue],
        at index: inout Int
    ) throws -> Value {
        defer { index += 1 }

        guard let value = Value(propValue: payload[index]) else { throw Refused() }

        return value
    }

    /// A value that is not the declared kind.
    private struct Refused: Error {}
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
