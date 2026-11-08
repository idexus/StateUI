// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A box that is ticked or not.
public enum CheckBoxContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "CheckBox"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A check box is a view, tinted, with the words it says beside its box.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextualElementContract.self, TintElementContract.self, FocusElementContract.self,
        ToggleElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
