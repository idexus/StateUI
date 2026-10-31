// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What one element tells the application: an event, and a value the user
/// changed - each a member of its contract or of a tier it wears. Handed to the view where the view is made, so the view names
/// members of its contract and never a handler.
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

    /// Hands a value the user changed on - to the state the element's value is carried
    /// in, and to the element's handler for the event.
    private let carry: (Prop, Event, HostValue) -> Void

    /// What the element is made from - its first patch, with the children and the handlers it begins with - where
    /// a toolkit makes another control of what the element holds, as a button holding a menu; nil where unknown.
    public let made: HostPatch?

    /// The reports of one element: `send` finds the element's handler for an event,
    /// `carry` writes the user's value where the element carries it and raises the
    /// event with it.
    ///
    /// - Parameters:
    ///   - send: given the event's key and what it carries.
    ///   - carry: given the property's key, the event's key, and the value.
    ///   - made: the patch the element is made from.
    public init(
        sending send: @escaping (Event, [HostValue]) -> Void,
        reporting carry: @escaping (Prop, Event, HostValue) -> Void,
        made: HostPatch? = nil
    ) {
        self.send = send
        self.carry = carry
        self.made = made
    }

    /// Raises an event with the values its contract declares - one of the
    /// element's own, or one a tier it wears declares, as a key a control
    /// hears is `KeyboardElementContract.keyPressed`. An event of a contract
    /// the element does not wear is refused, and said once.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public func raise<Owner: Contract, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        guard Realized.wears(Owner.self) else {
            return complain("\(Realized.name) raised `\(Owner.name).\(event.name)`, and "
                + "\(Realized.name) wears no \(Owner.name): nothing was raised.")
        }

        send(event.token, MemberValues.encode(repeat each value))
    }

    /// A value the user changed: it lands on the state the element's value is carried
    /// in - the one place a host-carried value lives - and the event is raised with
    /// it, so an application hears the change once whether it holds the value in a
    /// state or in a handler.
    ///
    ///     toggle.onToggled = { on in
    ///         reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
    ///     }
    ///
    /// The two members need not come from one contract: a field's words are
    /// `TextualElementContract.text` and the change it reports is
    /// `TextInputContract.textChanged`, and the element wears both. A member of
    /// a contract it does not wear is refused, and said once.
    ///
    /// - Parameters:
    ///   - property: the value's member, written with its contract.
    ///   - value: what the user made it.
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
