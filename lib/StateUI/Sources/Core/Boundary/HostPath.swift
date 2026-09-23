// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One normalized command in an SVG path. Every point is absolute, and the
/// shorthand commands have already been expanded, so native hosts only need
/// to translate this small geometry vocabulary to their drawing API.
@_spi(Host) public enum HostPathCommand: Equatable, Sendable {
    /// Moves the current point without drawing.
    case move(Point)
    /// Draws a straight segment to the point.
    case line(Point)
    /// Draws a cubic Bézier segment with two control points.
    case cubic(control1: Point, control2: Point, end: Point)
    /// Draws a quadratic Bézier segment with one control point.
    case quadratic(control: Point, end: Point)
    /// Draws an elliptical arc using the normalized SVG arc parameters.
    case arc(
        radiusX: Double,
        radiusY: Double,
        rotation: Double,
        largeArc: Bool,
        sweep: Bool,
        end: Point)
    /// Closes the current subpath with a straight segment.
    case close
}

/// A validated, platform-neutral SVG path.
@_spi(Host) public struct HostPath: Equatable, Sendable {
    public let commands: [HostPathCommand]

    /// Parses SVG path data without locale or platform converters. Invalid and
    /// non-finite data is rejected as a whole rather than partially drawn.
    public init?(svg: String) {
        guard let tokens = HostPathTokenizer(svg).tokens() else { return nil }
        var parser = HostPathParser(tokens)
        guard let commands = parser.commands() else { return nil }
        self.commands = commands
    }
}

private enum HostPathToken {
    case command(Character)
    case number(Double)
}

private struct HostPathTokenizer {
    let characters: [Character]

    init(_ source: String) {
        characters = Array(source)
    }

    func tokens() -> [HostPathToken]? {
        var result: [HostPathToken] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace || character == "," {
                index += 1
                continue
            }

            if character.isLetter {
                result.append(.command(character))
                index += 1
                continue
            }

            let start = index
            if characters[index] == "+" || characters[index] == "-" { index += 1 }

            var digits = 0
            while index < characters.count, characters[index].isNumber {
                digits += 1
                index += 1
            }
            if index < characters.count, characters[index] == "." {
                index += 1
                while index < characters.count, characters[index].isNumber {
                    digits += 1
                    index += 1
                }
            }
            guard digits > 0 else { return nil }

            if index < characters.count,
               characters[index] == "e" || characters[index] == "E" {
                index += 1
                if index < characters.count,
                   characters[index] == "+" || characters[index] == "-" {
                    index += 1
                }
                var exponentDigits = 0
                while index < characters.count, characters[index].isNumber {
                    exponentDigits += 1
                    index += 1
                }
                guard exponentDigits > 0 else { return nil }
            }

            guard let value = Double(String(characters[start..<index])), value.isFinite else {
                return nil
            }
            result.append(.number(value))
        }

        return result
    }
}

private struct HostPathParser {
    let tokens: [HostPathToken]
    var index = 0
    var active: Character?
    var current = Point.zero
    var subpathStart = Point.zero
    var previousKind: Character?
    var cubicControl: Point?
    var quadraticControl: Point?
    var result: [HostPathCommand] = []

    init(_ tokens: [HostPathToken]) {
        self.tokens = tokens
    }

    mutating func commands() -> [HostPathCommand]? {
        while index < tokens.count {
            if case .command(let command) = tokens[index] {
                guard Self.allowed.contains(command) else { return nil }
                active = command
                index += 1

                if command == "Z" || command == "z" {
                    result.append(.close)
                    current = subpathStart
                    clearControls()
                    previousKind = "Z"
                    active = nil
                    continue
                }
            }

            guard let command = active,
                  case .number = tokens[index]
            else { return nil }
            guard consume(command) else { return nil }
        }

        return result
    }

    private static let allowed = Set("MmLlHhVvCcSsQqTtAaZz")

    private mutating func consume(_ command: Character) -> Bool {
        let relative = command.isLowercase
        switch command.uppercased() {
        case "M":
            guard let values = take(2) else { return false }
            let point = resolved(values[0], values[1], relative: relative)
            result.append(.move(point))
            current = point
            subpathStart = point
            clearControls()
            previousKind = "M"
            active = relative ? "l" : "L"

        case "L":
            guard let values = take(2) else { return false }
            let point = resolved(values[0], values[1], relative: relative)
            result.append(.line(point))
            current = point
            clearControls()
            previousKind = "L"

        case "H":
            guard let values = take(1) else { return false }
            let point = Point(relative ? current.x + values[0] : values[0], current.y)
            result.append(.line(point))
            current = point
            clearControls()
            previousKind = "H"

        case "V":
            guard let values = take(1) else { return false }
            let point = Point(current.x, relative ? current.y + values[0] : values[0])
            result.append(.line(point))
            current = point
            clearControls()
            previousKind = "V"

        case "C":
            guard let values = take(6) else { return false }
            let control1 = resolved(values[0], values[1], relative: relative)
            let control2 = resolved(values[2], values[3], relative: relative)
            let end = resolved(values[4], values[5], relative: relative)
            result.append(.cubic(control1: control1, control2: control2, end: end))
            current = end
            cubicControl = control2
            quadraticControl = nil
            previousKind = "C"

        case "S":
            guard let values = take(4) else { return false }
            let control1 = previousKind == "C" || previousKind == "S"
                ? reflected(cubicControl ?? current)
                : current
            let control2 = resolved(values[0], values[1], relative: relative)
            let end = resolved(values[2], values[3], relative: relative)
            result.append(.cubic(control1: control1, control2: control2, end: end))
            current = end
            cubicControl = control2
            quadraticControl = nil
            previousKind = "S"

        case "Q":
            guard let values = take(4) else { return false }
            let control = resolved(values[0], values[1], relative: relative)
            let end = resolved(values[2], values[3], relative: relative)
            result.append(.quadratic(control: control, end: end))
            current = end
            quadraticControl = control
            cubicControl = nil
            previousKind = "Q"

        case "T":
            guard let values = take(2) else { return false }
            let control = previousKind == "Q" || previousKind == "T"
                ? reflected(quadraticControl ?? current)
                : current
            let end = resolved(values[0], values[1], relative: relative)
            result.append(.quadratic(control: control, end: end))
            current = end
            quadraticControl = control
            cubicControl = nil
            previousKind = "T"

        case "A":
            guard let values = take(7),
                  values[3] == 0 || values[3] == 1,
                  values[4] == 0 || values[4] == 1
            else { return false }
            let end = resolved(values[5], values[6], relative: relative)
            let radiusX = abs(values[0])
            let radiusY = abs(values[1])
            if radiusX == 0 || radiusY == 0 {
                result.append(.line(end))
                previousKind = "L"
            } else {
                result.append(.arc(
                    radiusX: radiusX,
                    radiusY: radiusY,
                    rotation: values[2],
                    largeArc: values[3] == 1,
                    sweep: values[4] == 1,
                    end: end))
                previousKind = "A"
            }
            current = end
            clearControls()

        default:
            return false
        }
        return true
    }

    private mutating func take(_ count: Int) -> [Double]? {
        guard index + count <= tokens.count else { return nil }
        var values: [Double] = []
        values.reserveCapacity(count)
        for _ in 0..<count {
            guard case .number(let value) = tokens[index] else { return nil }
            values.append(value)
            index += 1
        }
        return values
    }

    private func resolved(_ x: Double, _ y: Double, relative: Bool) -> Point {
        relative ? Point(current.x + x, current.y + y) : Point(x, y)
    }

    private func reflected(_ point: Point) -> Point {
        Point(2 * current.x - point.x, 2 * current.y - point.y)
    }

    private mutating func clearControls() {
        cubicControl = nil
        quadraticControl = nil
    }
}
