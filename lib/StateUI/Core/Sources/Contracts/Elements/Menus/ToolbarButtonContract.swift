// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An action in the page's native navigation or toolbar surface.
public enum ToolbarButtonContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarButton"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A toolbar button is an item a user chooses, and it acts, opens a menu, or both.
    public static let tiers: [any Contract.Type] = [
        MenuItemElementContract.self, ActionElementContract.self, ButtonMenuElementContract.self,
        TextAndIconElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
