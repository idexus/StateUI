// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Android's integer pixels: signed coordinates and sizes that View's measured-size field can hold.
/// Design: docs/design/platforms/android/layout.md#points-and-pixels
enum AndroidPixels {
    static let maximumSize: Int32 = 0x00FF_FFFF

    static func distance(
        _ points: Double, density: Double = 1, rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) -> Int32 {
        GeometryArithmetic.pixels(GeometryArithmetic.distance(points), density: density, rounding: rounding) ?? 0
    }

    static func size(
        _ points: Double, density: Double = 1, rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) -> Int32 {
        let pixels = distance(points, density: density, rounding: rounding)
        return pixels >= 0 && pixels <= maximumSize ? pixels : 0
    }

    static func frame(_ rectangle: Rect, density: Double) -> (left: Int32, top: Int32, right: Int32, bottom: Int32) {
        let across = axis(rectangle.x, rectangle.width, density: density)
        let down = axis(rectangle.y, rectangle.height, density: density)
        return (across.start, down.start, across.end, down.end)
    }

    private static func axis(_ origin: Double, _ length: Double, density: Double) -> (start: Int32, end: Int32) {
        guard density.isFinite, density > 0 else { return (0, 0) }
        let origin = GeometryArithmetic.distance(origin)
        let length = max(0, GeometryArithmetic.distance(length))
        guard let start = GeometryArithmetic.pixels(origin, density: density, rounding: .down) else { return (0, 0) }
        guard length > 0, let end = GeometryArithmetic.pixels(origin + length, density: density, rounding: .up) else {
            return (start, start)
        }
        let size = Int64(end) - Int64(start)
        return size >= 0 && size <= Int64(maximumSize) ? (start, end) : (start, start)
    }
}
