// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Room that grows: in a stack it takes what the stack's other children leave, alike with any other spacer.
public enum SpacerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Spacer"

    /// StateUI decides its extent, in the stack's arithmetic of the shared host layer; a host stands an empty view
    /// there.
    public static let layer: ElementLayer = .stateUI

    /// A spacer is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The element's own members: none.
    public static let members: [any ContractMember] = []
}
