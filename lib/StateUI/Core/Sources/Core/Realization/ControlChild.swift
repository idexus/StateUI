// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A child element as the view drawing it reads it: its values as the types its contract declares, and the reports
/// its events leave through. Two are equal when they are the same child.
public struct ControlChild<Child: ElementContract>: Hashable {
    /// The child, as the host keeps it.
    let source: HostChild

    /// The child the host keeps - the one a mounted element gives as a drawn child.
    @_spi(Host) public init(_ source: HostChild) {
        self.source = source
    }

    /// One of the child's values, as the type its contract declares - nil where it is not described, or where a
    /// member of a contract the child does not wear is asked for, which is said once.
    ///
    /// - Parameter property: the member, written with its contract.
    /// - Returns: the value, or nil.
    @MainActor
    public func value<Owner: WornContract, Value: HostRepresentable>(_ property: ElementProperty<Owner, Value>) -> Value? {
        guard Child.wears(Owner.self) else {
            complain("\(Child.name) was read for `\(Owner.name).\(property.name)`, and \(Child.name) wears no "
                + "\(Owner.name): nothing was read.")
            return nil
        }

        guard let value = source.read(property.token) else { return nil }
        return Value(propValue: value)
    }

    /// What the child's events and the user's values on it leave through.
    @MainActor
    public var reports: ControlReports<Child> {
        ControlReports(sending: source.send, reporting: source.carry)
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
