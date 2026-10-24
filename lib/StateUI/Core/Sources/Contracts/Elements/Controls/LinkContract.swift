// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Words that open an address - a page, a mail, a call - in the application the system gives it.
public enum LinkContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Link"

    /// The platform's own link where it has one, and a button drawn as one elsewhere.
    public static let layer: ElementLayer = .adaptive

    /// A link is a view of words the keyboard reaches.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextualElementContract.self, FocusElementContract.self,
    ]

    /// The user chose the link - a click, a tap, the keyboard - and its address went to the system.
    public static let clicked = ElementEvent<Self, Void>("clicked", layer: .native)

    /// The address it opens, handed to the system as `application.launch` hands one.
    public static let destination = ElementProperty<Self, String>("destination", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [clicked, destination]
}
