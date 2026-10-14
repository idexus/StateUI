// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between a menu's entries, grouping the ones before it apart from the ones after.
public enum MenuSeparatorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuSeparator"

    /// It carries structure, not a platform control of its own: the menu draws its own separator.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
