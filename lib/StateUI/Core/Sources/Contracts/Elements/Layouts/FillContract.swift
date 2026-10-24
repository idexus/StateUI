// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The room it is offered - a ZStack's, a grid's cell, a page, across a stack - made of the material its background
/// is, or clear, in its box's shape and outlined where it says so; along a stack, the length it states.
public enum FillContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Fill"

    /// StateUI decides its extent, as any child's in the arithmetic of the shared host layer; a host stands the view
    /// its layouts stand in, which draws its material.
    public static let layer: ElementLayer = .stateUI

    /// A fill is a view drawing its own box.
    public static let tiers: [any Contract.Type] = [ViewContract.self, BorderElementContract.self]

    /// The element's own members: none - what it is made of is the background every view has.
    public static let members: [any ContractMember] = []
}
