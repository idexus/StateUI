// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension [Prop: PropValue] {
    /// Writes one member's value into this map - a node's properties, or what
    /// a session keeps for the node it describes.
    mutating func write<Owner: WornContract, Held: HostRepresentable>(
        _ property: ElementProperty<Owner, Held>,
        _ value: Held
    ) {
        self[property.token] = value.propValue
    }

    /// Writes one member's value into this map, or leaves the member
    /// undescribed where there is none - a setting taken as optional, whose
    /// absence the host reads as its own default.
    mutating func describe<Owner: WornContract, Held: HostRepresentable>(
        _ property: ElementProperty<Owner, Held>,
        _ value: Held?
    ) {
        self[property.token] = value?.propValue
    }
}

extension Node {
    /// Writes one member's value into this node - what an element wearing no
    /// tier writes its members through, and a modifier setting several
    /// members at once, where `setValue` cannot chain.
    ///
    ///     node.write(TrafficLightContract.signal, .go)
    ///
    /// - Parameters:
    ///   - property: the member, written with its contract.
    ///   - value: what it holds.
    public mutating func write<Owner: WornContract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value
    ) {
        Wearing.takes(declaration, property)
        props.write(property, value)
    }

    /// Writes one member's value into this node, or leaves the member
    /// undescribed where there is none - a setting a modifier takes as
    /// optional, whose absence the host reads as its own default.
    mutating func describe<Owner: WornContract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value?
    ) {
        props.describe(property, value)
    }
}

extension Node {
    /// Writes the definition of a program the element runs, or - nil - takes it away: the one road a program has
    /// onto an element. A member the element's contract does not take is said once and written nowhere.
    /// Design: docs/design/core/contracts.md#a-program
    mutating func setProgram<Owner: WornContract, Definition>(
        _ member: ElementProgram<Owner, Definition>, definition: Definition?
    ) {
        guard Wearing.takes(declaration, member) else { return }
        programs[member.key] = definition
    }

    /// The definition of `member` the element was given; nil where it runs none.
    func program<Owner: WornContract, Definition>(_ member: ElementProgram<Owner, Definition>) -> Definition? {
        programs[member.key] as? Definition
    }
}
