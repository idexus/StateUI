// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a view whose root may change - an `if/else`, a composed view or a `Group` over one - stands while it shows
/// one branch or another: an element of no view of its own, holding what is written on the view to outlive its
/// branches - a watch, its lifetime, a sheet, a popover - and the view it builds, which stands in its place.
public enum AnchorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Anchor"

    /// It carries structure: the view it holds stands in its place.
    public static let layer: ElementLayer = .structure

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
