// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
