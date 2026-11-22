// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How fast a rectangle a view is drawn in moves: its middle across and down, and its width and height, in points a
/// second - what a shared transition's partner takes over with the place.
/// Design: docs/design/host/motion.md#a-shared-presentation
struct RectSpeed: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// A rectangle standing still.
    static let still = RectSpeed(x: 0, y: 0, width: 0, height: 0)
}
