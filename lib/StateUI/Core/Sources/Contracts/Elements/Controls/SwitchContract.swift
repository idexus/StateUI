// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An on/off toggle.
public enum SwitchContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Switch"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A switch is a view, tinted, with the words it says beside it.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextualElementContract.self, TintElementContract.self, FocusElementContract.self,
        ToggleElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
