// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a shape takes whole, the same on every host: its line, its fill where it encloses an area, and its corners
/// where it turns them.
@_spi(Host) public enum ShapeMembers {
    /// What every shape takes: its line - its brush, width, dashes and caps - how it fits its box, and how its
    /// geometry is turned.
    public static let members = PropertyList(
        ShapeContract.stroke, ShapeContract.lineWidth,
        ShapeContract.dash, ShapeContract.dashPhase,
        ShapeContract.lineCap,
        ShapeContract.contentMode, ShapeContract.geometryTransform)

    /// What a shape enclosing an area takes: its fill besides.
    public static let filledMembers = members + PropertyList(FilledShapeContract.fill)

    /// What a shape turning corners takes: how they join, and how far a sharp one reaches, besides.
    public static let corneredMembers = filledMembers
        + PropertyList(CorneredShapeContract.lineJoin, CorneredShapeContract.miterLimit)
}
