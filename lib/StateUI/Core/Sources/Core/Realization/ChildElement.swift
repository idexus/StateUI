// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One child element a registered view draws itself - a map's marker: what it is read and reported through. The host
/// keeps one for as long as the child lives, so a child is the same object every time its parent's view is handed it.
@_spi(Host) public final class HostChild {
    /// The child's current value for a key, as the host presents it.
    let read: (Prop) -> HostValue?

    /// Given each event the child raises, and what it carries.
    let send: (Event, [HostValue]) -> Void

    /// Given each value the user changed on the child: the property, the event to raise for it, and the value.
    let carry: (Prop, Event, HostValue) -> Void

    /// A child, read and reported through the functions given.
    ///
    /// - Parameters:
    ///   - read: the child's current value for a key.
    ///   - send: given each event the child raises.
    ///   - carry: given each value the user changed on the child.
    public init(
        reading read: @escaping (Prop) -> HostValue?,
        sending send: @escaping (Event, [HostValue]) -> Void,
        reporting carry: @escaping (Prop, Event, HostValue) -> Void
    ) {
        self.read = read
        self.send = send
        self.carry = carry
    }
}

/// A child element as the view drawing it reads it: its values as the types its contract declares, and the reports
/// its events leave through. Two are equal when they are the same child.
@_spi(Host) public struct ChildElement<Child: ElementContract>: Hashable {
    /// The child, as the host keeps it.
    let source: HostChild

    /// The child the host keeps - the one a mounted element gives as a drawn child.
    public init(_ source: HostChild) {
        self.source = source
    }

    /// One of the child's values, as the type its contract declares - nil where it is not described, or where a
    /// member of a contract the child does not wear is asked for, which is said once.
    ///
    /// - Parameter property: the member, written with its contract.
    /// - Returns: the value, or nil.
    public func value<Owner: Contract, Value: HostRepresentable>(_ property: ElementProperty<Owner, Value>) -> Value? {
        guard Child.wears(Owner.self) else {
            complain("\(Child.name) was read for `\(Owner.name).\(property.name)`, and \(Child.name) wears no "
                + "\(Owner.name): nothing was read.")
            return nil
        }

        return source.read(property.token).flatMap(Value.init(propValue:))
    }

    /// What the child's events and the user's values on it leave through.
    public var reports: Reports<Child> {
        Reports(sending: source.send, reporting: source.carry)
    }

    /// Whether the two are the same child.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source === rhs.source
    }

    /// The child's identity.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(source))
    }
}
