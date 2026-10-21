// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a view takes together: properties alone, so an event or an act never compiles among them.
// Design: docs/design/core/contracts.md#realizations

/// Properties a host's view takes together - one property of a contract, or
/// a list of them hosts share. No type of an application's own is one.
public protocol AppliedProperties {
    /// The properties, in their order.
    @_spi(Host) var applied: PropertyList { get }
}

extension AppliedProperties {
    /// What leaves a type of an application's own out.
    @available(*, unavailable, message: "a view takes the properties of a contract, one by one or in a list")
    @_spi(Host) public var applied: PropertyList { PropertyList() }
}

extension ElementProperty: AppliedProperties {
    /// The property, alone.
    @_spi(Host) public var applied: PropertyList { PropertyList(self) }
}
