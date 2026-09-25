// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One member of the contract a case covers, on the element it covers it on.
public struct Covered: Hashable, Sendable, CustomStringConvertible {
    /// The member's name.
    public let member: String

    /// The element it is covered on.
    public let element: String

    /// The tier declaring it; nil for the element's own member.
    public let tier: String?

    /// An element's own property.
    public init<Owner: ElementContract, Value>(_ property: ElementProperty<Owner, Value>) {
        self.init(member: property.name, element: Owner.nodeType.name, tier: nil)
    }

    /// A tier's property, on an element wearing the tier.
    public init<Tier: Contract, Value, Element: ElementContract>(
        _ property: ElementProperty<Tier, Value>, on element: Element.Type
    ) {
        self.init(member: property.name, element: Element.nodeType.name, tier: Tier.name)
    }

    /// A tier's property, on the element named `element` - as a tier's case made for each element names it.
    public init<Tier: Contract, Value>(_ property: ElementProperty<Tier, Value>, on element: String) {
        self.init(member: property.name, element: element, tier: Tier.name)
    }

    /// An element's own event.
    public init<Owner: ElementContract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        self.init(member: event.name, element: Owner.nodeType.name, tier: nil)
    }

    /// A tier's event, on an element wearing the tier.
    public init<Tier: Contract, Payload, Element: ElementContract>(
        _ event: ElementEvent<Tier, Payload>, on element: Element.Type
    ) {
        self.init(member: event.name, element: Element.nodeType.name, tier: Tier.name)
    }

    init(member: String, element: String, tier: String?) {
        self.member = member
        self.element = element
        self.tier = tier
    }

    public var description: String { "\(element).\(member)" }
}
