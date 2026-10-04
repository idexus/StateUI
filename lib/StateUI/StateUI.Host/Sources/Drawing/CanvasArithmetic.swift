// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// The canvas's arcs as curves, the same on every host drawing in Swift.
/// Design: docs/design/types/drawing.md#settings-hold-until-changed
@_spi(Host) public enum CanvasArithmetic {
    /// The arc of the ellipse filling `rect` from `start` to `end` degrees - clockwise or not, a turn past the whole
    /// the ellipse whole - as curves: a wedge from the middle, or closed across, or open.
    public static func arc(
        in rect: Rect, start: Double, end: Double, clockwise: Bool, closed: Bool, wedge: Bool
    ) -> [HostCurveCommand] {
        let middle = Point(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
        let (radiusX, radiusY) = (abs(rect.width) / 2, abs(rect.height) / 2)
        let from = start * .pi / 180
        var to = end * .pi / 180
        if clockwise {
            while to < from { to += 2 * .pi }
        } else {
            while to > from { to -= 2 * .pi }
        }
        let whole = abs(end - start) >= 360
        if whole { to = from + (clockwise ? 2 : -2) * .pi }
        func point(_ angle: Double) -> Point {
            Point(x: middle.x + radiusX * cos(angle), y: middle.y + radiusY * sin(angle))
        }

        // An arc of a whole turn begins where it ends: it runs as two halves.
        let halfway = (from + to) / 2
        let steps = whole ? [(from, halfway), (halfway, to)] : [(from, to)]
        var curves: [HostCurveCommand] = wedge ? [.move(middle), .line(point(from))] : [.move(point(from))]
        for (a, b) in steps {
            curves += HostPath.arc(
                from: point(a), to: point(b), radiusX: radiusX, radiusY: radiusY, rotation: 0,
                largeArc: abs(b - a) > .pi, sweep: clockwise)
        }
        if closed || wedge { curves.append(.close) }
        return curves
    }
}
