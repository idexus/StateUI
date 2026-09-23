// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An action in the page's native navigation or toolbar surface.
public enum ToolbarItemContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarItem"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A toolbar item is an item a user chooses.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self]

    /// Whether it sits on the bar itself or behind the overflow menu.
    public static let placement = ElementProperty<Self, ToolbarItemPlacement>(
        "placement", layer: .adaptive, travels: false, cleared: false)

    /// Where it sorts among the items of its placement.
    public static let priority = ElementProperty<Self, Int>(
        "priority", layer: .adaptive, travels: false, cleared: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [placement, priority]
}
