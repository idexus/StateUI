// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path; neither a line nor an ellipse.
public enum CorneredShapeContract: Contract {
    /// The tier's name.
    public static let name = "CorneredShape"

    /// A cornered shape is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// How two segments of the outline meet.
    public static let lineJoin = ElementProperty<Self, LineJoin>("lineJoin", layer: .stateUI)

    /// How far out a sharp corner may reach before it is cut off.
    public static let miterLimit = ElementProperty<Self, Double>("miterLimit", layer: .stateUI)

    /// The tier's own members.
    public static let members: [any ContractMember] = [lineJoin, miterLimit]
}
