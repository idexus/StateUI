// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A straight line between two points, in device units from the top left of the
/// space the line is given.
public enum LineContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Line"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// A line is a shape.
    public static let tiers: [any Tier.Type] = [ShapeContract.self]

    /// Where it starts.
    public static let from = ElementProperty<Self, Point>("from", layer: .stateUI)

    /// Where it ends.
    public static let to = ElementProperty<Self, Point>("to", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [from, to]
}
