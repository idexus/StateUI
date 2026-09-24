// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Lays its children one over another, each in the whole room or in the area it names.
public enum ZStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ZStack"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// It is a layout; the area each child stands in is the child's own.
    public static let tiers: [any Contract.Type] = [LayoutContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
