// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a shape drawn through a list of points has: the points, and which parts of a self-crossing outline count as
/// inside it - a polygon's, joined last back to first, and a polyline's, left open.
public enum PointsShapeContract: Tier {
    /// The tier's own name.
    public static let name = "PointsShape"

    /// The points, in order.
    public static let points = ElementProperty<Self, [Point]>("points", layer: .stateUI, travels: false)

    /// Which parts of a self-crossing outline count as inside it.
    public static let fillRule = ElementProperty<Self, FillRule>("fillRule", layer: .stateUI)

    /// The tier's own members.
    public static let members: [any ContractMember] = [points, fillRule]
}
