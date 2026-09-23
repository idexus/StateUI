// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a view is drawn over the rectangle its layout gave it.
///
/// Every host draws the same picture from it. Distances are points with y
/// growing down, angles are degrees, and a positive `rotation` turns
/// clockwise. Every part pivots about the anchor, a fraction of the view's
/// size, and the parts apply in one order: the scale, the turn in the plane
/// (`rotation`), the tip about the vertical axis (`rotationY`, which sends
/// the right edge away) and about the horizontal axis (`rotationX`, which
/// sends the top edge away), both seen from `perspectiveDistance`, and last
/// the translation. The drawing changes nothing about the layout: the view
/// keeps its rectangle and only what is drawn moves.
@_spi(Host) public struct HostDrawingTransform: Equatable, Sendable {
    /// Horizontal move, in points.
    public var translationX: Double

    /// Vertical move, in points, downward.
    public var translationY: Double

    /// Clockwise turn in the plane of the screen, in degrees.
    public var rotation: Double

    /// Tip about the horizontal axis, in degrees; positive sends the top away.
    public var rotationX: Double

    /// Turn about the vertical axis, in degrees; positive sends the right edge away.
    public var rotationY: Double

    /// Horizontal size factor.
    public var scaleX: Double

    /// Vertical size factor.
    public var scaleY: Double

    /// The pivot's horizontal position, from 0 at the left edge to 1 at the right.
    public var pivotX: Double

    /// The pivot's vertical position, from 0 at the top edge to 1 at the bottom.
    public var pivotY: Double

    /// A drawing transform; every part left out draws the view as laid out.
    public init(
        translationX: Double = 0,
        translationY: Double = 0,
        rotation: Double = 0,
        rotationX: Double = 0,
        rotationY: Double = 0,
        scaleX: Double = 1,
        scaleY: Double = 1,
        pivotX: Double = 0.5,
        pivotY: Double = 0.5
    ) {
        self.translationX = translationX
        self.translationY = translationY
        self.rotation = rotation
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.pivotX = pivotX
        self.pivotY = pivotY
    }

    /// The view drawn exactly where its layout put it.
    public static let identity = HostDrawingTransform()

    /// How far from the screen a tipped view is seen, in points.
    public static let perspectiveDistance = 400.0

    /// Whether the transform draws the view where it was laid out. The
    /// anchor alone moves nothing.
    public var isIdentity: Bool {
        translationX == 0 && translationY == 0
            && rotation == 0 && rotationX == 0 && rotationY == 0
            && scaleX == 1 && scaleY == 1
    }

    /// The transform as one matrix, for a view of the given size, in the
    /// view's own space: the origin at its top left corner.
    public func matrix(width: Double, height: Double) -> HostMatrix {
        let pivotX = pivotX * width
        let pivotY = pivotY * height
        let tips = rotationX != 0 || rotationY != 0

        return HostMatrix.translation(-pivotX, -pivotY)
            * HostMatrix.scale(scaleX, scaleY)
            * HostMatrix.rotation(degrees: rotation, about: .z)
            * HostMatrix.rotation(degrees: rotationY, about: .y)
            * HostMatrix.rotation(degrees: rotationX, about: .x)
            * (tips ? HostMatrix.perspective(Self.perspectiveDistance) : .identity)
            * HostMatrix.translation(pivotX + translationX, pivotY + translationY)
    }
}
