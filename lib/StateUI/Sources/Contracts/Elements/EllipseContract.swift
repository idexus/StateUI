// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An oval filling the room it is given - a circle when that room is square.
public enum EllipseContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .ellipse

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// An ellipse is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
