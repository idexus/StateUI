// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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

    /// Whether the patch changed a member - the gate for a value a view must not write
    /// unasked, such as a field's text under the user's cursor.
    ///
    /// - Parameter member: the property, written with its contract.
    /// - Returns: whether the patch changed it.
    public func changed<Owner: Contract, Value: HostRepresentable>(_ member: ElementProperty<Owner, Value>) -> Bool {
        changes.contains(member.token)
    }
}
