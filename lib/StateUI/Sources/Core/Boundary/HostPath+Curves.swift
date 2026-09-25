// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for an arc's angles.
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// One command of a path drawn without arcs: what a toolkit with no SVG arc draws.
@_spi(Host) public enum HostCurveCommand: Equatable, Sendable {
    /// Moves the current point without drawing.
    case move(Point)
    /// Draws a straight segment to the point.
    case line(Point)
    /// Draws a cubic Bézier segment with two control points.
    case cubic(control1: Point, control2: Point, end: Point)
    /// Draws a quadratic Bézier segment with one control point.
    case quadratic(control: Point, end: Point)
    /// Closes the current subpath with a straight segment.
    case close

    /// The command as a relay reads it: its kind - 0 move, 1 line, 2 cubic, 3 quadratic, 4 close - then its points.
    public var numbers: [Double] {
        switch self {
        case .move(let point): [0, point.x, point.y]
        case .line(let point): [1, point.x, point.y]
        case .cubic(let first, let second, let end): [2, first.x, first.y, second.x, second.y, end.x, end.y]
        case .quadratic(let control, let end): [3, control.x, control.y, end.x, end.y]
        case .close: [4]
        }
    }
}

extension HostPath {
    /// The path with every elliptical arc drawn as cubic Bézier segments, and every other command as it is.
    /// Design: docs/design/views/controls.md#canvas-and-path
    public var arcsAsCubics: [HostCurveCommand] {
        var drawn: [HostCurveCommand] = []
        var current = Point(0, 0)
        var start = Point(0, 0)

        for command in commands {
            switch command {
            case .move(let point):
                current = point
                start = point
                drawn.append(.move(point))
            case .line(let point):
                current = point
                drawn.append(.line(point))
            case .cubic(let control1, let control2, let end):
                current = end
                drawn.append(.cubic(control1: control1, control2: control2, end: end))
            case .quadratic(let control, let end):
                current = end
                drawn.append(.quadratic(control: control, end: end))
            case .arc(let radiusX, let radiusY, let rotation, let largeArc, let sweep, let end):
                drawn += Self.arc(
                    from: current, to: end, radiusX: radiusX, radiusY: radiusY, rotation: rotation,
                    largeArc: largeArc, sweep: sweep)
                current = end
            case .close:
                current = start
                drawn.append(.close)
            }
        }
        return drawn
    }

    /// An SVG elliptical arc from `start` to `end` as cubic Bézier segments of a quarter turn at most - a line
    /// where it has no radius or goes nowhere.
    public static func arc(
        from start: Point, to end: Point, radiusX: Double, radiusY: Double, rotation: Double,
        largeArc: Bool, sweep: Bool
    ) -> [HostCurveCommand] {
        guard start != end, radiusX != 0, radiusY != 0 else { return [.line(end)] }

        let angle = rotation * .pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        let halfX = (start.x - end.x) / 2
        let halfY = (start.y - end.y) / 2
        let turnedX = cosine * halfX + sine * halfY
        let turnedY = -sine * halfX + cosine * halfY

        // Radii too small to reach are scaled up until the arc just does.
        var rx = abs(radiusX)
        var ry = abs(radiusY)
        let reach = turnedX * turnedX / (rx * rx) + turnedY * turnedY / (ry * ry)
        if reach > 1 {
            rx *= reach.squareRoot()
            ry *= reach.squareRoot()
        }

        let numerator = max(0, rx * rx * ry * ry - rx * rx * turnedY * turnedY - ry * ry * turnedX * turnedX)
        let denominator = rx * rx * turnedY * turnedY + ry * ry * turnedX * turnedX
        let coefficient = denominator > 0 ? (largeArc == sweep ? -1 : 1) * (numerator / denominator).squareRoot() : 0
        let centreX = coefficient * rx * turnedY / ry
        let centreY = coefficient * -ry * turnedX / rx
        let centre = Point(
            cosine * centreX - sine * centreY + (start.x + end.x) / 2,
            sine * centreX + cosine * centreY + (start.y + end.y) / 2)

        func turn(_ fromX: Double, _ fromY: Double, _ toX: Double, _ toY: Double) -> Double {
            atan2(fromX * toY - fromY * toX, fromX * toX + fromY * toY)
        }
        let first = ((turnedX - centreX) / rx, (turnedY - centreY) / ry)
        let last = ((-turnedX - centreX) / rx, (-turnedY - centreY) / ry)
        var from = turn(1, 0, first.0, first.1)
        var delta = turn(first.0, first.1, last.0, last.1)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }

        func point(_ at: Double) -> Point {
            Point(
                centre.x + rx * cos(at) * cosine - ry * sin(at) * sine,
                centre.y + rx * cos(at) * sine + ry * sin(at) * cosine)
        }
        func slope(_ at: Double) -> Point {
            Point(-rx * sin(at) * cosine - ry * cos(at) * sine, -rx * sin(at) * sine + ry * cos(at) * cosine)
        }

        let count = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(count)
        let reachOut = 4 / 3 * tan(step / 4)
        var segments: [HostCurveCommand] = []
        for index in 0..<count {
            let to = from + step
            let a = point(from)
            let b = index == count - 1 ? end : point(to)
            let (outgoing, incoming) = (slope(from), slope(to))
            segments.append(.cubic(
                control1: Point(a.x + reachOut * outgoing.x, a.y + reachOut * outgoing.y),
                control2: Point(b.x - reachOut * incoming.x, b.y - reachOut * incoming.y),
                end: b))
            from = to
        }
        return segments
    }
}
