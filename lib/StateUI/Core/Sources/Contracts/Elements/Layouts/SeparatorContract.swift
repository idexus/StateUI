// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A native line across a stack, grouping the views before it apart from the ones after.
public enum SeparatorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Separator"

    /// Every base host draws it with its toolkit's own separator.
    public static let layer: ElementLayer = .native

    /// A separator is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
