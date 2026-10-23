// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A region that takes the room it is given - in a stack what the other children leave, alike with any spacer -
/// made of the material its background is, or clear, in its box's shape and outlined where it says so.
public enum FillerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Filler"

    /// StateUI decides its extent, in the stack's arithmetic of the shared host layer; a host stands the view its
    /// layouts stand in, which draws its material.
    public static let layer: ElementLayer = .stateUI

    /// A filler is a view drawing its own box.
    public static let tiers: [any Contract.Type] = [ViewContract.self, BorderElementContract.self]

    /// The element's own members: none - what it is made of is the background every view has.
    public static let members: [any ContractMember] = []
}
