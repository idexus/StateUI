// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import StateUIFoundation

/// A line's gradient as a CSS gradient draws it over a box, the same for every host painting one with CSS: the
/// direction of its two points in the box's pixels, and each stop where its stripe meets CSS's own gradient line.
/// Design: docs/design/types/brushes.md#drawn-by-css
@_spi(Host) public struct CSSGradientLine: Equatable, Sendable {
    /// The direction from the first point to the second in the box's pixels, in degrees clockwise from up; nil
    /// where the points meet, for CSS's own line, straight down.
    public let angle: Double?

    /// Each stop's place on CSS's line, a fraction of it: 0 to 1 within the box, beyond for a stop outside it.
    public let places: [Double]

    /// The gradient of `stops` from `from` to `to`, fractions of a box `width` by `height` pixels.
    public init(from: Point, to: Point, stops: [HostBrush.Stop], width: Double, height: Double) {
        let (startX, startY) = (from.x * width, from.y * height)
        let (dx, dy) = (to.x * width - startX, to.y * height - startY)
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else {
            (angle, places) = (nil, stops.map(\.offset))
            return
        }
        let (ux, uy) = (dx / length, dy / length)
        // CSS's line runs through the box's middle, as long as the box is across that direction.
        let line = abs(width * ux) + abs(height * uy)
        angle = atan2(dx, -dy) * 180 / Double.pi
        places = stops.map { stop in
            let x = startX + stop.offset * dx - width / 2
            let y = startY + stop.offset * dy - height / 2
            return line > 0 ? (x * ux + y * uy) / line + 0.5 : stop.offset
        }
    }
}
