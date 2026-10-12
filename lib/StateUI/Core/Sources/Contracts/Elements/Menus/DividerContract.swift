// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A line between entries, grouping the ones before it apart from the ones after: a menu's separator, or a
/// native line across a stack.
public enum DividerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Divider"

    /// Every base host draws it with its toolkit's own separator, in a menu and in a stack alike.
    public static let layer: ElementLayer = .native

    /// In a stack, a divider is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
