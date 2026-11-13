// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The platform's C maths library, for an arc's angles.
import StateUIFoundation

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

    /// A command's kind as a relay numbers it, ahead of its points.
    public enum Kind: Int32, Sendable {
        case move = 0, line = 1, cubic = 2, quadratic = 3, close = 4
    }

    /// The command as a relay reads it: its kind (`Kind`), then its points.
    public var numbers: [Double] {
        switch self {
        case .move(let point): [Self.number(.move), point.x, point.y]
        case .line(let point): [Self.number(.line), point.x, point.y]
        case .cubic(let first, let second, let end):
            [Self.number(.cubic), first.x, first.y, second.x, second.y, end.x, end.y]
        case .quadratic(let control, let end): [Self.number(.quadratic), control.x, control.y, end.x, end.y]
        case .close: [Self.number(.close)]
        }
    }

    private static func number(_ kind: Kind) -> Double {
        Double(kind.rawValue)
    }
}

extension HostCurveCommand.Kind {
    /// How many numbers - two a point - follow the kind.
    public var coordinates: Int {
        switch self {
        case .move, .line: 2
        case .cubic: 6
        case .quadratic: 4
        case .close: 0
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

        // Worked in the radii's own units, so no radius is squared: radii too small to reach are scaled up until
        // the arc just does - radii a double cannot tell from none beside the chord are none - and the short way
        // round an arc whose radii stand past a billion times its chord is the chord; the long way is the ellipse.
        // Design: docs/design/views/controls.md#canvas-and-path
        var rx = abs(radiusX)
        var ry = abs(radiusY)
        var (u, v) = (turnedX / rx, turnedY / ry)
        let reach = hypot(u, v)
        guard reach.isFinite else { return [.line(end)] }
        if reach > 1 {
            (rx, ry) = (rx * reach, ry * reach)
            (u, v) = (turnedX / rx, turnedY / ry)
        }
        let scaled = hypot(u, v)
        guard scaled > 0, largeArc || scaled >= 1e-9, rx.isFinite, ry.isFinite else { return [.line(end)] }

        // The center stands off the chord's middle along the chord's own direction turned, worked from the
        // direction rather than divided by a chord a double barely holds.
        let side = (largeArc == sweep ? -1 : 1) * max(0, 1 - scaled * scaled).squareRoot()
        let (alongU, alongV) = (u / scaled, v / scaled)
        let centerX = side * rx * alongV
        let centerY = side * -ry * alongU
        let center = Point(
            cosine * centerX - sine * centerY + (start.x + end.x) / 2,
            sine * centerX + cosine * centerY + (start.y + end.y) / 2)

        func turn(_ fromX: Double, _ fromY: Double, _ toX: Double, _ toY: Double) -> Double {
            atan2(fromX * toY - fromY * toX, fromX * toX + fromY * toY)
        }
        let first = (u - side * alongV, v + side * alongU)
        let last = (-u - side * alongV, -v + side * alongU)
        var from = turn(1, 0, first.0, first.1)
        var delta = turn(first.0, first.1, last.0, last.1)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }
        // The long way turns half a turn at least: ends a double cannot tell apart are the whole turn.
        if largeArc, abs(delta) < .pi / 2 { delta += sweep ? 2 * .pi : -2 * .pi }

        func point(_ at: Double) -> Point {
            Point(
                center.x + rx * cos(at) * cosine - ry * sin(at) * sine,
                center.y + rx * cos(at) * sine + ry * sin(at) * cosine)
        }
        func slope(_ at: Double) -> Point {
            Point(-rx * sin(at) * cosine - ry * cos(at) * sine, -rx * sin(at) * sine + ry * cos(at) * cosine)
        }

        let count = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / Double(count)
        let reachOut = 4 / 3 * tan(step / 4)
        guard delta.isFinite, center.x.isFinite, center.y.isFinite else { return [.line(end)] }
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
        // What a double cannot hold draws the chord rather than a curve that is no number.
        let numbers = segments.flatMap { segment -> [Double] in
            guard case .cubic(let a, let b, _) = segment else { return [] }
            return [a.x, a.y, b.x, b.y]
        }
        return numbers.allSatisfy(\.isFinite) ? segments : [.line(end)]
    }
}
