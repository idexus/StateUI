// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// GTK's integer pixels: signed coordinates and sizes in 32 bits, and a widget's margin in 16.
/// Design: docs/design/platforms/gtk/layout.md#whole-pixels
enum GTKPixels {
    /// A coordinate; one GTK cannot hold stands at zero.
    static func distance(_ points: Double, rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Int32 {
        GeometryArithmetic.pixels(GeometryArithmetic.distance(points), rounding: rounding) ?? 0
    }

    /// A size; a negative one or one GTK cannot hold is empty.
    static func size(_ points: Double, rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Int32 {
        max(0, distance(points, rounding: rounding))
    }

    /// A margin, which GTK keeps in 16 bits and refuses past them; one it cannot hold is none.
    static func margin(_ points: Double) -> Int32 {
        let pixels = size(points)
        return pixels <= Int32(Int16.max) ? pixels : 0
    }
}
