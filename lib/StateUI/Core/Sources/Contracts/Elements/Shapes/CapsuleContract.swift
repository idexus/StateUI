// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle whose shorter sides round whole, filling the room it is given - a circle when that room is square.
public enum CapsuleContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Capsule"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// A capsule is a shape.
    public static let tiers: [any Contract.Type] = [FilledShapeContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
