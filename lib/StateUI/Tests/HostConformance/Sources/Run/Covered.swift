// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a case covers: one member of the contract on the element it covers it on, or the element itself - which
/// the host makes.
public struct Covered: Hashable, Sendable, CustomStringConvertible {
    /// The member's name; nil for the element itself.
    public let member: String?

    /// The element.
    public let element: String

    /// The tier declaring the member; nil for the element's own member, and for the element itself.
    public let tier: String?

    /// The element itself: the host makes it.
    public init<Element: ElementContract>(_ element: Element.Type) {
        self.init(member: nil, element: Element.nodeType.name, tier: nil)
    }

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

    /// A property on the element named `element` - a tier's, as a tier's case made for each element names it, or
    /// the element's own where its contract declares it.
    public init<Owner: Contract, Value>(_ property: ElementProperty<Owner, Value>, on element: String) {
        self.init(member: property.name, element: element, tier: Owner.name == element ? nil : Owner.name)
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

    /// An event on the element named `element` - a tier's, as a tier's case made for each element names it, or the
    /// element's own where its contract declares it.
    public init<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>, on element: String) {
        self.init(member: event.name, element: element, tier: Owner.name == element ? nil : Owner.name)
    }

    /// An element's own act.
    public init<Owner: ElementContract, Arguments, Answer>(_ act: ElementAct<Owner, Arguments, Answer>) {
        self.init(member: act.name, element: Owner.nodeType.name, tier: nil)
    }

    /// An act on the element named `element` - a tier's, as a tier's case made for each element names it, or the
    /// element's own where its contract declares it.
    public init<Owner: Contract, Arguments, Answer>(_ act: ElementAct<Owner, Arguments, Answer>, on element: String) {
        self.init(member: act.name, element: element, tier: Owner.name == element ? nil : Owner.name)
    }

    init(member: String?, element: String, tier: String?) {
        self.member = member
        self.element = element
        self.tier = tier
    }

    /// "Label.text", or "Label" for the element itself.
    public var description: String {
        member.map { "\(element).\($0)" } ?? element
    }

    /// What `register` says of it: nil where the host does not realize it.
    func judgement(in register: HostRegister) -> HostRecord.Judgement? {
        guard let member else { return register.judgement(ofElement: element) }
        return register.judgement(of: member, on: element, from: tier)
    }

    /// The verdict `mark` of it.
    func verdict(_ mark: HostVerdict.Mark) -> HostVerdict {
        HostVerdict(element: element, member: member, mark: mark)
    }
}
