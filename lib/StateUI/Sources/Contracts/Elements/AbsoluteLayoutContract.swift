// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Puts each child exactly where it is told, and nowhere else.
public enum AbsoluteLayoutContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "AbsoluteLayout"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// It is a layout; where each child sits is the child's own.
    public static let tiers: [any Contract.Type] = [LayoutContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
