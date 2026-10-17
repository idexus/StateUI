// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A press dragged with ⌥/Alt over a view two fingers move, read as two fingers: the press and its mirror about the
/// view's middle - round the middle a turn, toward or away from it a spread - so a mouse turns and spreads what a
/// trackpad or a touch screen would, every host alike.
/// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
@_spi(Host) public struct MirroredFingers: Sendable {
    private var fingers = TwoFingers()

    /// No press yet.
    public init() {}

    /// The press stands at `point`, the view's middle at `middle`, in points of a view whose y grows down: how far
    /// the two fingers spread - a scale - and turned, in degrees clockwise, since the last time; nil as they first
    /// stand, or with the press on the middle.
    public mutating func moved(_ point: Point, about middle: Point) -> (scale: Double, degrees: Double)? {
        fingers.moved(point, Point(2 * middle.x - point.x, 2 * middle.y - point.y))
    }

    /// The press lifted: the next begins afresh.
    public mutating func lifted() {
        fingers.lifted()
    }
}
