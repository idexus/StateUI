// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One child placement delivered to a native layout host.
@_spi(Host) public struct HostPlacement: Equatable, Sendable {
    /// The child's rectangle in its layout's coordinates.
    public let bounds: Rect

    /// Horizontal drawing translation from the arranged rectangle.
    public let translationX: Double

    /// Vertical drawing translation from the arranged rectangle.
    public let translationY: Double

    /// Clockwise drawing rotation in degrees.
    public let rotation: Double

    /// Horizontal drawing scale.
    public let scaleX: Double

    /// Vertical drawing scale.
    public let scaleY: Double

    /// Drawing opacity from zero to one.
    public let opacity: Double

    /// Back-to-front rank among siblings.
    public let zIndex: Int

    /// Opacity of the optional shade drawn over the child.
    public let shade: Double
}

extension HostPlacement {
    /// How the placed child is drawn over its rectangle: moved, turned and
    /// sized about the rectangle's centre.
    public var drawing: HostDrawingTransform {
        HostDrawingTransform(
            translationX: translationX,
            translationY: translationY,
            rotation: rotation,
            scaleX: scaleX,
            scaleY: scaleY)
    }
}

/// A complete engine-authored arrangement for one native layout.
@_spi(Host) public struct HostPlacementRun: Equatable, Sendable {
    /// One placement for each child, in child order.
    public let placements: [HostPlacement]

    /// How a changed arrangement animates to its new positions.
    public let motion: Motion
}
