// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Room that pushes: in a stack it takes what the stack's other children leave, alike with any other space - drawn,
/// where it says so, in its box's shape and outlined.
public enum SpaceContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Space"

    /// StateUI decides its extent, in the stack's arithmetic of the shared host layer; a host stands the view its
    /// layouts stand in, which draws what it is made of.
    public static let layer: ElementLayer = .stateUI

    /// A space is a view drawing its own box.
    public static let tiers: [any Contract.Type] = [ViewContract.self, BorderElementContract.self]

    /// The element's own members: none.
    public static let members: [any ContractMember] = []
}
